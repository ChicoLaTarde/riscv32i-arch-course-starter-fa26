// Execute to Memory pipeline register.
`default_nettype none

module xm_register (
    input wire i_clk,
    input wire i_rst,
    input wire i_flush,
    input wire i_stall,

    // Instruction details for retirement.
    input wire i_valid,
    input wire [31:0] i_inst,
    input wire [31:0] i_pc,
    input wire [31:0] i_next_pc,
    input wire [4:0] i_rs1_raddr,
    input wire [4:0] i_rs2_raddr,
    input wire [4:0] i_rd_waddr,
    input wire [31:0] i_rs1_rdata,
    input wire [31:0] i_rs2_rdata,

    // Keep the low address bits for byte/halfword accesses.
    input wire [31:0] i_alu_result,
    input wire [31:0] i_pc_plus4,
    input wire i_mem_ren,
    input wire i_mem_wen,
    input wire [1:0] i_wb_sel,
    input wire i_reg_wen,
    input wire i_trap,
    input wire i_halt,

    output reg o_valid,
    output reg [31:0] o_inst,
    output reg [31:0] o_pc,
    output reg [31:0] o_next_pc,
    output reg [4:0] o_rs1_raddr,
    output reg [4:0] o_rs2_raddr,
    output reg [4:0] o_rd_waddr,
    output reg [31:0] o_rs1_rdata,
    output reg [31:0] o_rs2_rdata,

    output reg [31:0] o_alu_result,
    output reg [31:0] o_pc_plus4,
    output reg o_mem_ren,
    output reg o_mem_wen,
    output reg [1:0] o_wb_sel,
    output reg o_reg_wen,
    output reg o_trap,
    output reg o_halt
);
    localparam [31:0] NOP_INST = 32'h00000013;
    localparam [1:0] WB_ALU = 2'b00;

    // Memory uses rs2 for store data and funct3 for the access size.
    always @(posedge i_clk) begin
        // Reset/flush has priority over stall.
        if (i_rst || i_flush) begin
            o_valid      <= 1'b0;
            o_inst       <= NOP_INST;
            o_pc         <= 32'b0;
            o_next_pc    <= 32'b0;
            o_rs1_raddr  <= 5'b0;
            o_rs2_raddr  <= 5'b0;
            o_rd_waddr   <= 5'b0;
            o_rs1_rdata  <= 32'b0;
            o_rs2_rdata  <= 32'b0;
            o_alu_result <= 32'b0;
            o_pc_plus4   <= 32'b0;
            o_mem_ren    <= 1'b0;
            o_mem_wen    <= 1'b0;
            o_wb_sel     <= WB_ALU;
            o_reg_wen    <= 1'b0;
            o_trap       <= 1'b0;
            o_halt       <= 1'b0;
        end else if (!i_stall) begin
            o_valid      <= i_valid;
            o_inst       <= i_inst;
            o_pc         <= i_pc;
            o_next_pc    <= i_next_pc;
            o_rs1_raddr  <= i_rs1_raddr;
            o_rs2_raddr  <= i_rs2_raddr;
            o_rd_waddr   <= i_rd_waddr;
            o_rs1_rdata  <= i_rs1_rdata;
            o_rs2_rdata  <= i_rs2_rdata;
            o_alu_result <= i_alu_result;
            o_pc_plus4   <= i_pc_plus4;
            o_mem_ren    <= i_mem_ren;
            o_mem_wen    <= i_mem_wen;
            o_wb_sel     <= i_wb_sel;
            o_reg_wen    <= i_reg_wen;
            o_trap       <= i_trap;
            o_halt       <= i_halt;
        end
        // On a stall, keep the current values.
    end

endmodule

`default_nettype wire
