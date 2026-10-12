`default_nettype none

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
    input  wire [31:0] i_inst,

    // ALU operation selector. For R-type and arithmetic I-type operations,
    // use funct3: 000=ADD/SUB, 001=SLL, 010=SLT, 011=SLTU,
    // 100=XOR, 101=SRL/SRA, 110=OR, 111=AND.
    // Other instructions use ADD (000) for effective-address calculation
    // or pass-through addition; branch comparisons use ALU comparison flags.
    output wire [2:0]  o_opsel,

    // Assert for the SUB encoding (R-type, funct3=000, funct7=0100000).
    // Zero for ADD, address calculations, and all other instructions.
    output wire        o_sub,

    // Select unsigned less-than comparison. Used for SLTU, SLTIU,
    // BLTU and BGEU. Otherwise comparison is signed.
    output wire        o_unsigned,

    // Select arithmetic right shift (sign-fill) for SRA and SRAI.
    // Zero selects logical right shift for SRL and SRLI.
    output wire        o_arith,

    // First ALU operand mux: 00=register rs1; 01=current PC (AUIPC);
    // 10=zero (LUI). All other supported ALU users select rs1.
    output wire [1:0]  o_op1_sel,

    // Second ALU operand mux: 0=register rs2 (R-type and branches),
    // 1=sign/zero-extended immediate (I-type, loads, stores, U-type,
    // JALR). This is one bit because only two sources are needed.
    output wire        o_op2_sel,

    // Register writeback mux: 00=ALU result (R, OP-IMM, LUI, AUIPC),
    // 01=processed load data (LB/LH/LW/LBU/LHU), 10=PC+4 (JAL/JALR).
    // Meaningful only when o_reg_wen is asserted.
    output wire [1:0]  o_wb_sel,

    // Register file write enable. High for instructions that write rd;
    // low for branches, stores, system instructions, and illegal encodings.
    // The register file must independently prevent writes to x0.
    output wire        o_reg_wen,

    // One-hot immediate-format selector for imm.v: {J,U,B,S,I,R}.
    // JAL=100000, LUI/AUIPC=010000, branches=001000,
    // stores=000100, OP-IMM/loads/JALR=000010, R-type=000001.
    // For instructions without an immediate, all bits may be zero.
    output wire [5:0]  o_i_format,

    // Data-memory read enable: asserted for legal LB/LH/LW/LBU/LHU.
    // hart.v must supply the aligned address, byte mask, and load
    // extraction/sign-extension; trap logic must suppress faulting access.
    output wire        o_mem_ren,

    // Data-memory write enable: asserted for legal SB/SH/SW.
    // hart.v must supply aligned address, byte mask, and positioned data;
    // trap logic must suppress writes for misaligned/faulting accesses.
    output wire        o_mem_wen,

    // Identifies a legal conditional branch (BEQ/BNE/BLT/BGE/BLTU/BGEU).
    // hart.v uses funct3 and the ALU's eq/lt flags to decide if taken;
    // the decoder cannot determine taken/not-taken from i_inst alone.
    output wire        o_is_branch,

    // Identifies JAL. The target is PC + J-immediate; writeback is PC+4.
    output wire        o_is_jal,

    // Identifies legal JALR (funct3=000). The ALU computes rs1+I-imm;
    // hart.v clears target bit 0, checks instruction alignment, and
    // writes PC+4 to rd.
    output wire        o_is_jalr,

    // Assert for unsupported or reserved instruction encodings, including
    // invalid opcode/funct3/funct7 combinations. Side-effect enables are
    // suppressed when this is high; hart.v must report the trap.
    // ECALL and EBREAK are recognized separately as valid SYSTEM encodings:
    // hart.v must handle ECALL as a trap and EBREAK as halt/trap per spec.
    output wire        o_illegal
);

    wire [6:0] opcode = i_inst[6:0];
    wire [2:0] funct3 = i_inst[14:12];

    wire is_r     = (opcode == 7'b0110011);
    wire is_imm   = (opcode == 7'b0010011);
    wire is_load  = (opcode == 7'b0000011);
    wire is_store = (opcode == 7'b0100011);
    wire is_lui   = (opcode == 7'b0110111);
    wire is_auipc = (opcode == 7'b0010111);

    assign o_is_branch = (opcode == 7'b1100011);
    assign o_is_jal    = (opcode == 7'b1101111);
    assign o_is_jalr   = (opcode == 7'b1100111);

    // Bit order: {J, U, B, S, I, R}, matching imm.v.
    assign o_i_format = {
        o_is_jal,
        is_lui | is_auipc,
        o_is_branch,
        is_store,
        is_imm | is_load | o_is_jalr,
        is_r
    };

    // Register and immediate arithmetic use funct3 directly. Address
    // calculations and upper-immediate instructions use addition.
    assign o_opsel = (is_r | is_imm) ? funct3 : 3'b000;
    assign o_sub = is_r & (funct3 == 3'b000) & i_inst[30];
    assign o_arith = (is_r | is_imm) &
                     (funct3 == 3'b101) & i_inst[30];
    assign o_unsigned = ((is_r | is_imm) & (funct3 == 3'b011)) |
                        (o_is_branch & funct3[1]);

    // Operand 1: 00 = rs1, 01 = PC, 10 = zero.
    assign o_op1_sel = is_lui   ? 2'b10 :
                      is_auipc ? 2'b01 : 2'b00;

    // Operand 2: 00 = rs2, 01 = immediate.
    // Branches compare registers; hart's separate adder forms the target.
    assign o_op2_sel = (is_imm | is_load | is_store |
                       is_lui | is_auipc | o_is_jalr)
                      ? 2'b01 : 2'b00;

    // Writeback: 00 = ALU, 01 = load data, 10 = PC+4.
    assign o_wb_sel = is_load ? 2'b01 :
                     (o_is_jal | o_is_jalr) ? 2'b10 : 2'b00;

    assign o_reg_wen = is_r | is_imm | is_load | is_lui | is_auipc |
                       o_is_jal | o_is_jalr;

endmodule

`default_nettype wire


