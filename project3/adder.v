/**
* adder.v (takes in two 32-bit inputs and outputs their sum)
*/

module adder (
    input wire [31:0] a,
    input wire [31:0] b,
    output wire [31:0] c;
);

    c = a + b;
endmodule