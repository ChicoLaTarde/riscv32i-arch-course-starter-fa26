// Memory to Writeback pipeline register.
`default_nettype none

module mw_register (
    input wire i_clk,
    input wire i_rst,
    input wire i_flush,
    input wire i_stall,

    // Instruction details saved with the result.
    input wire i_valid,
    input wire [31:0] i_inst,
    input wire [31:0] i_pc,
    input wire [31:0] i_next_pc,
    input wire [4:0] i_rs1_raddr,
    input wire [4:0] i_rs2_raddr,
    input wire [4:0] i_rd_waddr,
    input wire [31:0] i_rs1_rdata,
    input wire [31:0] i_rs2_rdata,

    input wire [31:0] i_alu_result,
    // Load data is already aligned and extended.
    input wire [31:0] i_mem_data,
    input wire [31:0] i_dmem_addr,
    input wire i_dmem_ren,
    input wire i_dmem_wen,
    input wire [3:0] i_dmem_mask,
    input wire [31:0] i_dmem_wdata,
    input wire [31:0] i_dmem_rdata,
    input wire [31:0] i_pc_plus4,
    input wire [1:0] i_wb_sel,
    input wire i_reg_wen,
    // Trap and halt flags.
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
    output reg [31:0] o_rd_wdata,
    output reg [31:0] o_dmem_addr,
    output reg o_dmem_ren,
    output reg o_dmem_wen,
    output reg [3:0] o_dmem_mask,
    output reg [31:0] o_dmem_wdata,
    output reg [31:0] o_dmem_rdata,
    output reg o_reg_wen,
    output reg o_trap,
    output reg o_halt
);
    localparam [31:0] NOP_INST = 32'h00000013;

    // Same decoder encoding as hart.v: 00=ALU, 01=load, 10=PC+4.
    localparam [1:0] WB_ALU = 2'b00;
    localparam [1:0] WB_LOAD = 2'b01;
    localparam [1:0] WB_PC4 = 2'b10;

    reg [31:0] wb_data;

    // Pick the result before saving it.
    always @(*) begin
        case (i_wb_sel)
            WB_ALU:  wb_data = i_alu_result;
            WB_LOAD: wb_data = i_mem_data;
            WB_PC4:  wb_data = i_pc_plus4;
            default: wb_data = 32'b0;
        endcase
    end

    // Writeback checks valid and trap before writing the result.
    always @(posedge i_clk) begin
        if (i_rst || i_flush) begin
            o_valid     <= 1'b0;
            o_inst      <= NOP_INST;
            o_pc        <= 32'b0;
            o_next_pc   <= 32'b0;
            o_rs1_raddr <= 5'b0;
            o_rs2_raddr <= 5'b0;
            o_rd_waddr  <= 5'b0;
            o_rs1_rdata <= 32'b0;
            o_rs2_rdata <= 32'b0;
            o_rd_wdata  <= 32'b0;
            o_dmem_addr <= 32'b0;
            o_dmem_ren  <= 1'b0;
            o_dmem_wen  <= 1'b0;
            o_dmem_mask <= 4'b0;
            o_dmem_wdata <= 32'b0;
            o_dmem_rdata <= 32'b0;
            o_reg_wen   <= 1'b0;
            o_trap      <= 1'b0;
            o_halt      <= 1'b0;
        end else if (!i_stall) begin
            o_valid     <= i_valid;
            o_inst      <= i_inst;
            o_pc        <= i_pc;
            o_next_pc   <= i_next_pc;
            o_rs1_raddr <= i_rs1_raddr;
            o_rs2_raddr <= i_rs2_raddr;
            o_rd_waddr  <= i_rd_waddr;
            o_rs1_rdata <= i_rs1_rdata;
            o_rs2_rdata <= i_rs2_rdata;
            o_rd_wdata  <= wb_data;
            o_dmem_addr <= i_dmem_addr;
            o_dmem_ren  <= i_dmem_ren;
            o_dmem_wen  <= i_dmem_wen;
            o_dmem_mask <= i_dmem_mask;
            o_dmem_wdata <= i_dmem_wdata;
            o_dmem_rdata <= i_dmem_rdata;
            o_reg_wen   <= i_reg_wen;
            o_trap      <= i_trap;
            o_halt      <= i_halt;
        end
        // On a stall, keep the current values.
    end

endmodule

`default_nettype wire
