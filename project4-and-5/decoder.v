// Decode RV32I instructions into control signals.
module decoder (
    // Raw 32-bit instruction from instruction memory. opcode, funct3,
    // funct7, and (for SYSTEM) the remaining instruction bits determine
    // which operation is legal and how the datapath should be configured.
    input [31:0] i_inst,

    // ALU operation selector. For R-type and arithmetic I-type operations,
    // use funct3: 000=ADD/SUB, 001=SLL, 010=SLT, 011=SLTU,
    // 100=XOR, 101=SRL/SRA, 110=OR, 111=AND.
    // Other instructions use ADD (000) for effective-address calculation
    // or pass-through addition; branch comparisons use ALU comparison flags.
    output reg [2:0] o_opsel,

    // Assert for the SUB encoding (R-type, funct3=000, funct7=0100000).
    // Zero for ADD, address calculations, and all other instructions.
    output reg o_sub,

    // Select unsigned less-than comparison. Used for SLTU, SLTIU,
    // BLTU and BGEU. Otherwise comparison is signed.
    output reg o_unsigned,

    // Select arithmetic right shift (sign-fill) for SRA and SRAI.
    // Zero selects logical right shift for SRL and SRLI.
    output reg o_arith,

    // First ALU operand mux: 00=register rs1; 01=current PC (AUIPC);
    // 10=zero (LUI). All other supported ALU users select rs1.
    output reg [1:0] o_op1_sel,

    // Second ALU operand mux: 0=register rs2 (R-type and branches),
    // 1=sign/zero-extended immediate (I-type, loads, stores, U-type,
    // JALR). The two-bit encoding matches the Execute operand mux.
    output reg [1:0] o_op2_sel,

    // Register writeback mux: 00=ALU result (R, OP-IMM, LUI, AUIPC),
    // 01=processed load data (LB/LH/LW/LBU/LHU), 10=PC+4 (JAL/JALR).
    // Meaningful only when o_reg_wen is asserted.
    output reg [1:0] o_wb_sel,

    // Register file write enable. High for instructions that write rd;
    // low for branches, stores, system instructions, and illegal encodings.
    // The register file must independently prevent writes to x0.
    output reg o_reg_wen,

    // One-hot immediate-format selector for imm.v: {J,U,B,S,I,R}.
    // JAL=100000, LUI/AUIPC=010000, branches=001000,
    // stores=000100, OP-IMM/loads/JALR=000010, R-type=000001.
    // For instructions without an immediate, all bits may be zero.
    output reg [5:0] o_i_format,

    // Data-memory read enable: asserted for legal LB/LH/LW/LBU/LHU.
    // hart.v must supply the aligned address, byte mask, and load
    // extraction/sign-extension; trap logic must suppress faulting access.
    output reg o_mem_ren,

    // Data-memory write enable: asserted for legal SB/SH/SW.
    // hart.v must supply aligned address, byte mask, and positioned data;
    // trap logic must suppress writes for misaligned/faulting accesses.
    output reg o_mem_wen,

    // Identifies a legal conditional branch (BEQ/BNE/BLT/BGE/BLTU/BGEU).
    // hart.v uses funct3 and the ALU's eq/lt flags to decide if taken;
    // the decoder cannot determine taken/not-taken from i_inst alone.
    output reg o_is_branch,

    // Identifies JAL. The target is PC + J-immediate; writeback is PC+4.
    output reg o_is_jal,

    // Identifies legal JALR (funct3=000). The ALU computes rs1+I-imm;
    // hart.v clears target bit 0, checks instruction alignment, and
    // writes PC+4 to rd.
    output reg o_is_jalr,

    // Tell pipeline hazard logic which source registers this instruction
    // actually reads. Immediate bits must not be mistaken for rs2.
    output reg o_uses_rs1,
    output reg o_uses_rs2,

    // Assert for unsupported or reserved instruction encodings, including
    // invalid opcode/funct3/funct7 combinations. Side-effect enables are
    // suppressed when this is high; hart.v must report the trap.
    // This core uses EBREAK to halt. ECALL and other unsupported SYSTEM
    // instructions take the trap path.
    output reg o_illegal
);

    wire [6:0] opcode = i_inst[6:0];
    wire [2:0] funct3 = i_inst[14:12];
    wire [6:0] funct7 = i_inst[31:25];

    // Instruction opcodes.
    localparam [6:0] OPCODE_REGISTER_ALU = 7'b0110011;
    localparam [6:0] OPCODE_IMMEDIATE_ALU = 7'b0010011;
    localparam [6:0] OPCODE_LOAD = 7'b0000011;
    localparam [6:0] OPCODE_STORE = 7'b0100011;
    localparam [6:0] OPCODE_BRANCH = 7'b1100011;
    localparam [6:0] OPCODE_LUI = 7'b0110111;
    localparam [6:0] OPCODE_AUIPC = 7'b0010111;
    localparam [6:0] OPCODE_JAL = 7'b1101111;
    localparam [6:0] OPCODE_JALR = 7'b1100111;
    localparam [6:0] OPCODE_SYSTEM = 7'b1110011;

    // ALU operations used by the decoder.
    localparam [2:0] ALU_ADD_SUB = 3'b000;
    localparam [2:0] ALU_SLL = 3'b001;
    localparam [2:0] ALU_SLTU = 3'b011;
    localparam [2:0] ALU_SRL_SRA = 3'b101;

    localparam [6:0] FUNCT7_BASE = 7'b0000000;
    localparam [6:0] FUNCT7_SUB_SRA = 7'b0100000;

    localparam [2:0] ACCESS_BYTE = 3'b000;
    localparam [2:0] ACCESS_HALFWORD = 3'b001;
    localparam [2:0] ACCESS_WORD = 3'b010;
    localparam [2:0] ACCESS_BYTE_UNSIGNED = 3'b100;
    localparam [2:0] ACCESS_HALFWORD_UNSIGNED = 3'b101;

    localparam [2:0] BRANCH_EQ = 3'b000;
    localparam [2:0] BRANCH_NE = 3'b001;
    localparam [2:0] BRANCH_LT = 3'b100;
    localparam [2:0] BRANCH_GE = 3'b101;
    localparam [2:0] BRANCH_LTU = 3'b110;
    localparam [2:0] BRANCH_GEU = 3'b111;
    localparam [2:0] JALR_FUNCT3 = 3'b000;

    // Operand selections used by Execute.
    localparam [1:0] OP1_REGISTER = 2'b00;
    localparam [1:0] OP1_PC = 2'b01;
    localparam [1:0] OP1_ZERO = 2'b10;
    localparam [1:0] OP2_REGISTER = 2'b00;
    localparam [1:0] OP2_IMMEDIATE = 2'b01;

    // Result selections used by MW.
    localparam [1:0] WB_ALU = 2'b00;
    localparam [1:0] WB_LOAD = 2'b01;
    localparam [1:0] WB_PC4 = 2'b10;

    // Bit order: {J, U, B, S, I, R}, matching imm.v.
    localparam [5:0] FORMAT_NONE = 6'b000000;
    localparam [5:0] FORMAT_R = 6'b000001;
    localparam [5:0] FORMAT_I = 6'b000010;
    localparam [5:0] FORMAT_S = 6'b000100;
    localparam [5:0] FORMAT_B = 6'b001000;
    localparam [5:0] FORMAT_U = 6'b010000;
    localparam [5:0] FORMAT_J = 6'b100000;

    localparam [31:0] EBREAK_INST = 32'h00100073;

    always @(*) begin
        // Default controls. Keep writes and jumps off unless the instruction enables them.
        o_opsel     = ALU_ADD_SUB;
        o_sub       = 1'b0;
        o_unsigned  = 1'b0;
        o_arith     = 1'b0;
        o_op1_sel   = OP1_REGISTER;
        o_op2_sel   = OP2_REGISTER;
        o_wb_sel    = WB_ALU;
        o_i_format  = FORMAT_NONE;
        o_reg_wen   = 1'b0;
        o_mem_ren   = 1'b0;
        o_mem_wen   = 1'b0;
        o_is_branch = 1'b0;
        o_is_jal    = 1'b0;
        o_is_jalr   = 1'b0;
        o_uses_rs1  = 1'b0;
        o_uses_rs2  = 1'b0;
        o_illegal   = 1'b0;

        case (opcode)
            OPCODE_REGISTER_ALU: begin // R-type register arithmetic
                // Only SUB and SRA use the alternate funct7 encoding.
                case (funct7)
                    FUNCT7_BASE: o_illegal = 1'b0;
                    FUNCT7_SUB_SRA: begin
                        case (funct3)
                            ALU_ADD_SUB,
                            ALU_SRL_SRA: o_illegal = 1'b0;
                            default:     o_illegal = 1'b1;
                        endcase
                    end
                    default: o_illegal = 1'b1;
                endcase

                o_uses_rs1 = !o_illegal;
                o_uses_rs2 = !o_illegal;
                o_i_format = FORMAT_R;
                o_opsel    = funct3;
                o_sub      = (funct3 == ALU_ADD_SUB) & i_inst[30];
                o_arith    = (funct3 == ALU_SRL_SRA) & i_inst[30];
                o_unsigned = (funct3 == ALU_SLTU);
                o_reg_wen  = !o_illegal;
            end

            OPCODE_IMMEDIATE_ALU: begin // I-type immediate arithmetic
                // Check the upper bits for shifts. Other immediates can use all 12 bits.
                case (funct3)
                    ALU_SLL: o_illegal = (funct7 != FUNCT7_BASE);
                    ALU_SRL_SRA: begin
                        case (funct7)
                            FUNCT7_BASE,
                            FUNCT7_SUB_SRA: o_illegal = 1'b0;
                            default:       o_illegal = 1'b1;
                        endcase
                    end
                    default: o_illegal = 1'b0;
                endcase

                o_uses_rs1 = !o_illegal;
                o_i_format = FORMAT_I;
                o_opsel    = funct3;
                o_arith    = (funct3 == ALU_SRL_SRA) & i_inst[30];
                o_unsigned = (funct3 == ALU_SLTU);
                o_op2_sel  = OP2_IMMEDIATE;
                o_reg_wen  = !o_illegal;
            end

            OPCODE_LOAD: begin // Load: address = rs1 + immediate
                case (funct3)
                    ACCESS_BYTE,
                    ACCESS_HALFWORD,
                    ACCESS_WORD,
                    ACCESS_BYTE_UNSIGNED,
                    ACCESS_HALFWORD_UNSIGNED: o_illegal = 1'b0;
                    default:                  o_illegal = 1'b1;
                endcase

                o_uses_rs1 = !o_illegal;
                o_i_format = FORMAT_I;
                o_op2_sel  = OP2_IMMEDIATE;
                o_wb_sel   = WB_LOAD;
                o_reg_wen  = !o_illegal;
                o_mem_ren  = !o_illegal;
            end

            OPCODE_STORE: begin // Store: address = rs1 + immediate
                case (funct3)
                    ACCESS_BYTE,
                    ACCESS_HALFWORD,
                    ACCESS_WORD: o_illegal = 1'b0;
                    default:     o_illegal = 1'b1;
                endcase

                o_uses_rs1 = !o_illegal; // Address base.
                o_uses_rs2 = !o_illegal; // Value to store.
                o_i_format = FORMAT_S;
                o_op2_sel  = OP2_IMMEDIATE;
                o_mem_wen  = !o_illegal;
            end

            OPCODE_BRANCH: begin // Branch: compare registers
                case (funct3)
                    BRANCH_EQ,
                    BRANCH_NE,
                    BRANCH_LT,
                    BRANCH_GE,
                    BRANCH_LTU,
                    BRANCH_GEU: o_illegal = 1'b0;
                    default:    o_illegal = 1'b1;
                endcase

                o_uses_rs1 = !o_illegal;
                o_uses_rs2 = !o_illegal;
                // Hart's separate adder forms PC + immediate.
                o_i_format  = FORMAT_B;
                o_unsigned  = funct3[1];
                o_is_branch = !o_illegal;
            end

            OPCODE_LUI: begin // LUI: result = zero + immediate
                o_i_format = FORMAT_U;
                o_op1_sel  = OP1_ZERO;
                o_op2_sel  = OP2_IMMEDIATE;
                o_reg_wen  = 1'b1;
            end

            OPCODE_AUIPC: begin // AUIPC: result = PC + immediate
                o_i_format = FORMAT_U;
                o_op1_sel  = OP1_PC;
                o_op2_sel  = OP2_IMMEDIATE;
                o_reg_wen  = 1'b1;
            end

            OPCODE_JAL: begin // JAL: write PC + 4
                // Hart's separate adder forms the jump target.
                o_i_format = FORMAT_J;
                o_wb_sel   = WB_PC4;
                o_reg_wen  = 1'b1;
                o_is_jal   = 1'b1;
            end

            OPCODE_JALR: begin // JALR: target = rs1 + immediate
                o_illegal  = (funct3 != JALR_FUNCT3);
                o_uses_rs1 = !o_illegal;
                o_i_format = FORMAT_I;
                o_op2_sel  = OP2_IMMEDIATE;
                o_wb_sel   = WB_PC4;
                o_reg_wen  = !o_illegal;
                o_is_jalr  = !o_illegal;
            end

            OPCODE_SYSTEM: begin // Preserve EBREAK as hart's halt instruction.
                o_illegal = (i_inst != EBREAK_INST);
            end

            default: begin
                o_illegal = 1'b1;
            end
        endcase
    end

endmodule

`default_nettype wire
