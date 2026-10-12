/**
* adder.v (takes in two 32-bit inputs and outputs their sum)
*/

module adder_32b (
    input wire [31:0] i_a,
    input wire [31:0] i_b,
    output wire [31:0] o_sum
);

     assign o_sum = i_a + i_b;
endmodule