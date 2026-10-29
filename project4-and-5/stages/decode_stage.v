`default_nettype none

// Decode the instruction, read registers, and build the immediate.
module decode_stage (
    // Instruction from FD.
    input wire i_clk,
    input wire i_rst,
    input wire [31:0] i_inst,

    // Writeback writes to the register file through these inputs.
    input wire i_wb_wen,
    input wire [4:0] i_wb_waddr,
    input wire [31:0] i_wb_wdata,

    // Source registers, destination, and immediate.
    output wire [4:0] o_rs1_raddr,
    output wire [4:0] o_rs2_raddr,
    output wire [4:0] o_rd_waddr,
    output wire [31:0] o_rs1_rdata,
    output wire [31:0] o_rs2_rdata,
    output wire [31:0] o_imm_value,

    // Execute controls.
    output wire [2:0] o_alu_opsel,
    output wire o_alu_sub,
    output wire o_alu_unsigned,
    output wire o_alu_arith,
    output wire [1:0] o_op1_sel,
    output wire [1:0] o_op2_sel,
    output wire o_is_branch,
    output wire o_is_jal,
    output wire o_is_jalr,
    output wire o_illegal_inst,

    // Memory and Writeback controls.
    output wire o_mem_ren,
    output wire o_mem_wen,
    output wire [1:0] o_wb_sel,
    output wire o_reg_wen,

    // Source-use flags for hazard detection.
    output wire o_uses_rs1,
    output wire o_uses_rs2
);
    wire [5:0] imm_format;

    // Register fields in the instruction.
    assign o_rs1_raddr = i_inst[19:15];
    assign o_rs2_raddr = i_inst[24:20];
    assign o_rd_waddr = i_inst[11:7];

    // Decoder controls the immediate format.

    decoder decoder_unit (
        .i_inst(i_inst),
        .o_opsel(o_alu_opsel),
        .o_sub(o_alu_sub),
        .o_unsigned(o_alu_unsigned),
        .o_arith(o_alu_arith),
        .o_op1_sel(o_op1_sel),
        .o_op2_sel(o_op2_sel),
        .o_wb_sel(o_wb_sel),
        .o_i_format(imm_format),
        .o_reg_wen(o_reg_wen),
        .o_mem_ren(o_mem_ren),
        .o_mem_wen(o_mem_wen),
        .o_is_branch(o_is_branch),
        .o_is_jal(o_is_jal),
        .o_is_jalr(o_is_jalr),
        .o_uses_rs1(o_uses_rs1),
        .o_uses_rs2(o_uses_rs2),
        .o_illegal(o_illegal_inst)
    );

    imm imm_gen (
        .i_inst(i_inst),
        .i_format(imm_format),
        .o_immediate(o_imm_value)
    );

    // Bypass is off, so Decode waits until Writeback finishes.
    rf #(
        .BYPASS_EN(0)
    ) register_file (
        .i_clk(i_clk),
        .i_rst(i_rst),
        .i_rs1_raddr(o_rs1_raddr),
        .i_rs2_raddr(o_rs2_raddr),
        .o_rs1_rdata(o_rs1_rdata),
        .o_rs2_rdata(o_rs2_rdata),
        .i_rd_wen(i_wb_wen),
        .i_rd_waddr(i_wb_waddr),
        .i_rd_wdata(i_wb_wdata)
    );

endmodule

`default_nettype wire
