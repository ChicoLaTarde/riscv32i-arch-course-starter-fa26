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
    input wire [31:0] i_inst,

    output reg [2:0] o_opsel,
    output reg o_sub,
    output reg o_unsigned,
    output reg o_arith,

    output reg [1:0] o_op1_sel,
    output reg [1:0] o_op2_sel,
    output reg [1:0] o_wb_sel,

    output reg [5:0] o_i_format, // one hot encoding of instruction format
    output reg o_reg_wen,

    output reg o_is_branch,
    output reg o_is_jal,
    output reg o_is_jalr,
    output reg o_illegal
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
            end

            7'b0100011: begin // Store: address = rs1 + immediate
                o_i_format = FORMAT_S;
                o_op2_sel  = OP2_IMM;
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
