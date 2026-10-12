
/**
* Program counter that keeps track of the memory pointer for RV32I 32-bit architecture.
*/

module PC_reg_v
#(
    // The reset address of the program counter. This is the address that the
    // program counter will be set to when the reset signal is asserted.
    parameter RESET_ADDR =  32'd0 // Default reset address is 0x00000000
);(
    input  wire        clk,
    input  wire        rst,
    input  wire [31:0] pc_next,
    output reg  [31:0] pc
);

    always @(posedge clk or posedge rst) begin
        if (rst)
            pc <= RESET_ADDR;
        else
            pc <= pc_next;
    end

endmodule
