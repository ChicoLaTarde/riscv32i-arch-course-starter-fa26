
/**
* Program counter that keeps track of the memory pointer for RV32I 32-bit architecture.
*/

module PC_reg
#(
    // The reset address of the program counter. This is the address that the
    // program counter will be set to when the reset signal is asserted.
    parameter RESET_ADDR =  32'd0 // Default reset address is 0x00000000
)(
    input  wire        i_clk,
    input  wire        i_rst,
    input  wire [31:0] i_next_pc,
    output reg  [31:0] o_pc
);

    always @(posedge i_clk or posedge i_rst) begin
        if (i_rst)
            o_pc <= RESET_ADDR;
        else
            o_pc <= i_next_pc;
    end

endmodule
