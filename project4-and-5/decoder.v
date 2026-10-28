/**
 * RV32I combinational instruction decoder.
 *
 * All outputs are functions of i_inst; no clock or state is required.
 * Illegal encodings disable architectural register/memory writes.
 *
 * Encoding assumptions (must match hart.v and alu.v):
 *   ALU opsel = funct3 for valid R-type and OP-IMM instructions.
 *   ALU operand 1: 00=rs1, 01=PC, 10=zero.
 *   ALU operand 2: 0=rs2, 1=immediate.
 *   Writeback: 00=ALU, 01=load result, 10=PC+4.
 *   Immediate format: {J,U,B,S,I,R} (one-hot).
 */
module decoder (
    // Raw 32-bit instruction from instruction memory. opcode, funct3,
    // funct7, and (for SYSTEM) the remaining instruction bits determine
    // which operation is legal and how the datapath should be configured.
    input      [31:0] i_inst,

    // ALU operation selector. For R-type and arithmetic I-type operations,
    // use funct3: 000=ADD/SUB, 001=SLL, 010=SLT, 011=SLTU,
    // 100=XOR, 101=SRL/SRA, 110=OR, 111=AND.
    // Other instructions use ADD (000) for effective-address calculation
    // or pass-through addition; branch comparisons use ALU comparison flags.
    output reg [2:0]  o_opsel,

    // Assert for the SUB encoding (R-type, funct3=000, funct7=0100000).
    // Zero for ADD, address calculations, and all other instructions.
    output reg        o_sub,

    // Select unsigned less-than comparison. Used for SLTU, SLTIU,
    // BLTU and BGEU. Otherwise comparison is signed.
    output reg        o_unsigned,

    // Select arithmetic right shift (sign-fill) for SRA and SRAI.
    // Zero selects logical right shift for SRL and SRLI.
    output reg        o_arith,

    // First ALU operand mux: 00=register rs1; 01=current PC (AUIPC);
    // 10=zero (LUI). All other supported ALU users select rs1.
    output reg [1:0]  o_op1_sel,

    // Second ALU operand mux: 0=register rs2 (R-type and branches),
    // 1=sign/zero-extended immediate (I-type, loads, stores, U-type,
    // JALR). This is one bit because only two sources are needed.
    output reg [1:0]       o_op2_sel,

    // Register writeback mux: 00=ALU result (R, OP-IMM, LUI, AUIPC),
    // 01=processed load data (LB/LH/LW/LBU/LHU), 10=PC+4 (JAL/JALR).
    // Meaningful only when o_reg_wen is asserted.
    output reg [1:0]  o_wb_sel,

    // Register file write enable. High for instructions that write rd;
    // low for branches, stores, system instructions, and illegal encodings.
    // The register file must independently prevent writes to x0.
    output reg        o_reg_wen,

    // One-hot immediate-format selector for imm.v: {J,U,B,S,I,R}.
    // JAL=100000, LUI/AUIPC=010000, branches=001000,
    // stores=000100, OP-IMM/loads/JALR=000010, R-type=000001.
    // For instructions without an immediate, all bits may be zero.
    output reg [5:0]  o_i_format,

    // Data-memory read enable: asserted for legal LB/LH/LW/LBU/LHU.
    // hart.v must supply the aligned address, byte mask, and load
    // extraction/sign-extension; trap logic must suppress faulting access.
    output reg        o_mem_ren,

    // Data-memory write enable: asserted for legal SB/SH/SW.
    // hart.v must supply aligned address, byte mask, and positioned data;
    // trap logic must suppress writes for misaligned/faulting accesses.
    output reg        o_mem_wen,

    // Identifies a legal conditional branch (BEQ/BNE/BLT/BGE/BLTU/BGEU).
    // hart.v uses funct3 and the ALU's eq/lt flags to decide if taken;
    // the decoder cannot determine taken/not-taken from i_inst alone.
    output reg        o_is_branch,

    // Identifies JAL. The target is PC + J-immediate; writeback is PC+4.
    output reg        o_is_jal,

    // Identifies legal JALR (funct3=000). The ALU computes rs1+I-imm;
    // hart.v clears target bit 0, checks instruction alignment, and
    // writes PC+4 to rd.
    output reg        o_is_jalr,

    // Assert for unsupported or reserved instruction encodings, including
    // invalid opcode/funct3/funct7 combinations. Side-effect enables are
    // suppressed when this is high; hart.v must report the trap.
    // ECALL and EBREAK are recognized separately as valid SYSTEM encodings:
    // hart.v must handle ECALL as a trap and EBREAK as halt/trap per spec.
    output reg        o_illegal
);

    wire [6:0] opcode = i_inst[6:0];
    wire [2:0] funct3 = i_inst[14:12];

    localparam [1:0] OP1_RS1  = 2'b00,
                     OP1_PC   = 2'b01,
                     OP1_ZERO = 2'b10;
    localparam [1:0] OP2_RS2 = 2'b00,
                     OP2_IMM = 2'b01;
    localparam [1:0] WB_ALU  = 2'b00,
                     WB_LOAD = 2'b01,
                     WB_PC4  = 2'b10;

    // Bit order: {J, U, B, S, I, R}, matching imm.v.
    localparam [5:0] FORMAT_R = 6'b000001,
                     FORMAT_I = 6'b000010,
                     FORMAT_S = 6'b000100,
                     FORMAT_B = 6'b001000,
                     FORMAT_U = 6'b010000,
                     FORMAT_J = 6'b100000;

    always @(*) begin
        // Defaults: add rs1 and rs2, with no register write or jump.
        // Every output has a default so this block stays combinational.
        o_opsel     = 3'b000;
        o_sub       = 1'b0;
        o_unsigned  = 1'b0;
        o_arith     = 1'b0;
        o_op1_sel   = OP1_RS1;
        o_op2_sel   = OP2_RS2;
        o_wb_sel    = WB_ALU;
        o_i_format  = 6'b000000;
        o_reg_wen   = 1'b0;
        o_mem_ren   = 1'b0;
        o_mem_wen   = 1'b0;
        o_is_branch = 1'b0;
        o_is_jal    = 1'b0;
        o_is_jalr   = 1'b0;
        o_illegal   = 1'b0;

        case (opcode)
            7'b0110011: begin // R-type register arithmetic
                o_i_format = FORMAT_R;
                o_opsel    = funct3;
                o_sub      = (funct3 == 3'b000) & i_inst[30];
                o_arith    = (funct3 == 3'b101) & i_inst[30];
                o_unsigned = (funct3 == 3'b011);
                o_reg_wen  = 1'b1;
            end

            7'b0010011: begin // I-type immediate arithmetic
                o_i_format = FORMAT_I;
                o_opsel    = funct3;
                o_arith    = (funct3 == 3'b101) & i_inst[30];
                o_unsigned = (funct3 == 3'b011);
                o_op2_sel  = OP2_IMM;
                o_reg_wen  = 1'b1;
            end

            7'b0000011: begin // Load: address = rs1 + immediate
                o_i_format = FORMAT_I;
                o_op2_sel  = OP2_IMM;
                o_wb_sel   = WB_LOAD;
                o_reg_wen  = 1'b1;
                o_mem_ren  = 1'b1;
            end

            7'b0100011: begin // Store: address = rs1 + immediate
                o_i_format = FORMAT_S;
                o_op2_sel  = OP2_IMM;
                o_mem_wen  = 1'b1;
            end

            7'b1100011: begin // Branch: compare registers
                // Hart's separate adder forms PC + immediate.
                o_i_format  = FORMAT_B;
                o_unsigned  = funct3[1];
                o_is_branch = 1'b1;
            end

            7'b0110111: begin // LUI: result = zero + immediate
                o_i_format = FORMAT_U;
                o_op1_sel  = OP1_ZERO;
                o_op2_sel  = OP2_IMM;
                o_reg_wen  = 1'b1;
            end

            7'b0010111: begin // AUIPC: result = PC + immediate
                o_i_format = FORMAT_U;
                o_op1_sel  = OP1_PC;
                o_op2_sel  = OP2_IMM;
                o_reg_wen  = 1'b1;
            end

            7'b1101111: begin // JAL: write PC + 4
                // Hart's separate adder forms the jump target.
                o_i_format = FORMAT_J;
                o_wb_sel   = WB_PC4;
                o_reg_wen  = 1'b1;
                o_is_jal   = 1'b1;
            end

            7'b1100111: begin // JALR: target = rs1 + immediate
                o_i_format = FORMAT_I;
                o_op2_sel  = OP2_IMM;
                o_wb_sel   = WB_PC4;
                o_reg_wen  = 1'b1;
                o_is_jalr  = 1'b1;
            end

            7'b1110011: begin // Preserve EBREAK as hart's halt instruction.
                o_illegal = (i_inst != 32'h00100073);
            end

            default: begin
                o_illegal = 1'b1;
            end
        endcase
    end

endmodule

`default_nettype wire
