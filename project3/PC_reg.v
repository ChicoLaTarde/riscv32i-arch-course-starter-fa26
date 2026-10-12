
/**
* Program counter that keeps track of the memory pointer for RV32I 32-bit architecture.
*/

module PC_reg_v (
    input  wire        clk,
    input  wire        rst,
    input  wire [31:0] pc_next,
    output reg  [31:0] pc
);

    always @(posedge clk or posedge rst) begin
        if (rst)
            pc <= 32'h00000000;
        else
            pc <= pc_next;
    end

endmodule
