`default_nettype none

// Write the selected MW result to the register file and report retirement.
module writeback_stage (
    // Instruction and result from MW.
    input wire i_rst,
    input wire i_valid,
    input wire [31:0] i_inst,
    input wire [31:0] i_pc,
    input wire [31:0] i_next_pc,
    input wire [4:0] i_rs1_raddr,
    input wire [4:0] i_rs2_raddr,
    input wire [31:0] i_rs1_rdata,
    input wire [31:0] i_rs2_rdata,
    input wire [4:0] i_rd_waddr,
    input wire [31:0] i_rd_wdata,
    input wire [31:0] i_dmem_addr,
    input wire i_dmem_ren,
    input wire i_dmem_wen,
    input wire [3:0] i_dmem_mask,
    input wire [31:0] i_dmem_wdata,
    input wire [31:0] i_dmem_rdata,
    input wire i_reg_wen,
    input wire i_trap,
    input wire i_halt,

    // Write port of the register file in Decode.
    output wire o_rf_wen,
    output wire [4:0] o_rf_waddr,
    output wire [31:0] o_rf_wdata,

    // Retire interface.
    output wire o_retire_valid,
    output wire [31:0] o_retire_inst,
    output wire o_retire_trap,
    output wire o_retire_halt,
    output wire [4:0] o_retire_rs1_raddr,
    output wire [4:0] o_retire_rs2_raddr,
    output wire [31:0] o_retire_rs1_rdata,
    output wire [31:0] o_retire_rs2_rdata,
    output wire [4:0] o_retire_rd_waddr,
    output wire [31:0] o_retire_rd_wdata,
    output wire [31:0] o_retire_pc,
    output wire [31:0] o_retire_next_pc,
    output wire [31:0] o_retire_dmem_addr,
    output wire o_retire_dmem_ren,
    output wire o_retire_dmem_wen,
    output wire [3:0] o_retire_dmem_mask,
    output wire [31:0] o_retire_dmem_wdata,
    output wire [31:0] o_retire_dmem_rdata
);
    // Write only valid results. Never write x0 or a faulting instruction.
    assign o_rf_wen = i_valid && i_reg_wen && !i_trap && !i_halt &&
                      (i_rd_waddr != 5'b0) && !i_rst;
    assign o_rf_waddr = i_rd_waddr;
    assign o_rf_wdata = i_rd_wdata;

    // Traps and EBREAK still retire. Bubbles do not.
    assign o_retire_valid = i_valid && !i_rst;
    assign o_retire_inst = i_inst;
    assign o_retire_trap = i_trap;
    assign o_retire_halt = i_halt;
    assign o_retire_rs1_raddr = i_rs1_raddr;
    assign o_retire_rs2_raddr = i_rs2_raddr;
    assign o_retire_rs1_rdata = i_rs1_rdata;
    assign o_retire_rs2_rdata = i_rs2_rdata;
    assign o_retire_rd_waddr = o_rf_wen ? i_rd_waddr : 5'b0;
    assign o_retire_rd_wdata = i_rd_wdata;
    assign o_retire_pc = i_pc;
    assign o_retire_next_pc = i_next_pc;
    assign o_retire_dmem_addr = i_dmem_addr;
    assign o_retire_dmem_ren = o_retire_valid && !i_trap && !i_halt && i_dmem_ren;
    assign o_retire_dmem_wen = o_retire_valid && !i_trap && !i_halt && i_dmem_wen;
    assign o_retire_dmem_mask = i_dmem_mask;
    assign o_retire_dmem_wdata = i_dmem_wdata;
    assign o_retire_dmem_rdata = i_dmem_rdata;
endmodule

`default_nettype wire
