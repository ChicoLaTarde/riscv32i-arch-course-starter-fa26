`default_nettype none

// Fetch the instruction at PC. Memory returns it in the same cycle.
module fetch_stage #(
    parameter RESET_ADDR = 32'h00000000
) (
    // Clock and synchronous reset.
    input wire i_clk,
    input wire i_rst,

    // Stall/stop controls and the branch target from Execute.
    input wire i_stall,
    input wire i_stop,
    input wire i_redirect,
    input wire [31:0] i_redirect_pc,

    // Instruction memory.
    input wire [31:0] i_imem_rdata,
    output wire [31:0] o_imem_raddr,

    // Instruction and PC going into FD.
    output wire o_valid,
    output wire [31:0] o_pc,
    output wire [31:0] o_inst
);
    wire [31:0] pc_plus4;
    wire [31:0] next_pc;

    // Stop first, then redirect, then stall. Otherwise fetch PC + 4.
    assign pc_plus4 = o_pc + 32'd4;
    assign next_pc = i_stop     ? o_pc          :
                     i_redirect ? i_redirect_pc :
                    i_stall    ? o_pc          : pc_plus4;

    PC_reg #(
        .RESET_ADDR(RESET_ADDR)
    ) pc_reg (
        .i_clk(i_clk),
        .i_rst(i_rst),
        .i_next_pc(next_pc),
        .o_pc(o_pc)
    );

    assign o_imem_raddr = o_pc;
    assign o_inst       = i_imem_rdata;
    assign o_valid      = !i_rst && !i_stop;
endmodule

`default_nettype wire
