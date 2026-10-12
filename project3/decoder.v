`default_nettype none

/**
* Instruction Decoder for RISC-V CPU
*/
module decoder (
    input wire [31:0] i_inst,
    
    output wire [2:0] o_opsel,
    output wire o_sub,
    output wire o_unsigned,
    output wire o_arith,

    output [1:0] o_op1_sel,
    output [1:0] o_op2_sel,

    output wire [1:0] o_wb_sel,

    output wire [5:0] o_i_format, // one hot encoding of instruction format

    output wire o_reg_wen,

    output wire o_is_branch,
    output wire o_is_jal,
    output wire o_is_jalr
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


