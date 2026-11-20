// Decode to Execute pipeline register.
`default_nettype none

module dx_register (
    input wire i_clk,
    input wire i_rst,
    input wire i_flush,
    input wire i_stall,

    // Instruction and operands from Decode.
    input wire i_valid,
    input wire [31:0] i_inst,
    input wire [31:0] i_pc,
    input wire [4:0] i_rs1_raddr,
    input wire [4:0] i_rs2_raddr,
    input wire [4:0] i_rd_waddr,
    input wire [31:0] i_rs1_rdata,
    input wire [31:0] i_rs2_rdata,
    input wire [31:0] i_imm_value,

    // Execute controls from decoder.v.
    input wire [2:0] i_alu_opsel,
    input wire i_alu_sub,
    input wire i_alu_unsigned,
    input wire i_alu_arith,
    input wire [1:0] i_op1_sel,
    input wire [1:0] i_op2_sel,
    input wire i_is_branch,
    input wire i_is_jal,
    input wire i_is_jalr,
    input wire i_illegal_inst,

    // Controls for Memory and Writeback.
    input wire i_mem_ren,
    input wire i_mem_wen,
    input wire [1:0] i_wb_sel,
    input wire i_reg_wen,

    output reg o_valid,
    output reg [31:0] o_inst,
    output reg [31:0] o_pc,
    output reg [4:0] o_rs1_raddr,
    output reg [4:0] o_rs2_raddr,
    output reg [4:0] o_rd_waddr,
    output reg [31:0] o_rs1_rdata,
    output reg [31:0] o_rs2_rdata,
    output reg [31:0] o_imm_value,

    output reg [2:0] o_alu_opsel,
    output reg o_alu_sub,
    output reg o_alu_unsigned,
    output reg o_alu_arith,
    output reg [1:0] o_op1_sel,
    output reg [1:0] o_op2_sel,
    output reg o_is_branch,
    output reg o_is_jal,
    output reg o_is_jalr,
    output reg o_illegal_inst,

    output reg o_mem_ren,
    output reg o_mem_wen,
    output reg [1:0] o_wb_sel,
    output reg o_reg_wen
);
    // NOP and control values for a bubble.
    localparam [31:0] NOP_INST = 32'h00000013;
    localparam [2:0] ALU_ADD_SUB = 3'b000;
    localparam [1:0] OP1_REGISTER = 2'b00;
    localparam [1:0] OP2_REGISTER = 2'b00;
    localparam [1:0] WB_ALU = 2'b00;

    always @(posedge i_clk) begin
        // Reset/flush has priority over stall.
        if (i_rst || i_flush) begin
            o_valid        <= 1'b0;
            o_inst         <= NOP_INST;
            o_pc           <= 32'b0;
            o_rs1_raddr    <= 5'b0;
            o_rs2_raddr    <= 5'b0;
            o_rd_waddr     <= 5'b0;
            o_rs1_rdata    <= 32'b0;
            o_rs2_rdata    <= 32'b0;
            o_imm_value    <= 32'b0;

            o_alu_opsel    <= ALU_ADD_SUB;
            o_alu_sub      <= 1'b0;
            o_alu_unsigned <= 1'b0;
            o_alu_arith    <= 1'b0;
            o_op1_sel      <= OP1_REGISTER;
            o_op2_sel      <= OP2_REGISTER;
            o_is_branch    <= 1'b0;
            o_is_jal       <= 1'b0;
            o_is_jalr      <= 1'b0;
            o_illegal_inst <= 1'b0;

            o_mem_ren      <= 1'b0;
            o_mem_wen      <= 1'b0;
            o_wb_sel       <= WB_ALU;
            o_reg_wen      <= 1'b0;
        end else if (!i_stall) begin
            // Save all fields for the next stage.
            o_valid        <= i_valid;
            o_inst         <= i_inst;
            o_pc           <= i_pc;
            o_rs1_raddr    <= i_rs1_raddr;
            o_rs2_raddr    <= i_rs2_raddr;
            o_rd_waddr     <= i_rd_waddr;
            o_rs1_rdata    <= i_rs1_rdata;
            o_rs2_rdata    <= i_rs2_rdata;
            o_imm_value    <= i_imm_value;

            o_alu_opsel    <= i_alu_opsel;
            o_alu_sub      <= i_alu_sub;
            o_alu_unsigned <= i_alu_unsigned;
            o_alu_arith    <= i_alu_arith;
            o_op1_sel      <= i_op1_sel;
            o_op2_sel      <= i_op2_sel;
            o_is_branch    <= i_is_branch;
            o_is_jal       <= i_is_jal;
            o_is_jalr      <= i_is_jalr;
            o_illegal_inst <= i_illegal_inst;

            o_mem_ren      <= i_mem_ren;
            o_mem_wen      <= i_mem_wen;
            o_wb_sel       <= i_wb_sel;
            o_reg_wen      <= i_reg_wen;
        end
        // On a stall, keep the current values.
    end

endmodule

`default_nettype wire
