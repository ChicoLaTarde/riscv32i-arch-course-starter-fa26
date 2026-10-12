/**
 * 4-to-1 Multiplexor:
 * if      (sel = 00) out = a
 * else if (sel = 01) out = b
 * else if (sel = 10) out = c
 * else              out = d
 */
module mux4 (
    input wire [31:0] a,
    input wire [31:0] b,
    input wire [31:0] c,
    input wire [31:0] d,
    input wire [1:0] sel,
    output wire [31:0] out
);

    wire [31:0] ab;
    wire [31:0] cd;

    mux m0 (.a(a),  .b(b),  .sel(sel[0]), .out(ab));
    mux m1 (.a(c),  .b(d),  .sel(sel[0]), .out(cd));
    mux m2 (.a(ab), .b(cd), .sel(sel[1]), .out(out));

endmodule