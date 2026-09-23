`default_nettype none

// The arithmetic logic unit (ALU) is responsible for performing the core
// calculations of the processor. It takes two 32-bit operands and outputs
// a 32 bit result based on the selection operation - addition, comparison,
// shift, or logical operation. This ALU is a purely combinational block, so
// you should not attempt to add any registers or pipeline it.
module alu (
    // NOTE: Both 3'b010 and 3'b011 are used for set less than operations and
    // your implementation should output the same result for both codes. The
    // reason for this will become clear in project 3.
    //
    // Major operation selection.
    // 3'b000: addition/subtraction if `i_sub` asserted
    // 3'b001: shift left logical
    // 3'b010,
    // 3'b011: set less than/unsigned if `i_unsigned` asserted
    // 3'b100: exclusive or
    // 3'b101: shift right logical/arithmetic if `i_arith` asserted
    // 3'b110: or
    // 3'b111: and
    input  wire [ 2:0] i_opsel,
    // When asserted, addition operations should subtract instead.
    // This is only used for `i_opsel == 3'b000` (addition/subtraction).
    input  wire        i_sub,
    // When asserted, comparison operations should be treated as unsigned.
    // This is used for branch comparisons and set less than unsigned. For
    // b ranch operations, the ALU result is not used, only the comparison
    // results.
    input  wire        i_unsigned,
    // When asserted, right shifts should be treated as arithmetic instead of
    // logical. This is only used for `i_opsel == 3'b101` (shift right).
    input  wire        i_arith,
    // First 32-bit input operand.
    input  wire [31:0] i_op1,
    // Second 32-bit input operand.
    input  wire [31:0] i_op2,
    // 32-bit output result. Any carry out should be ignored.
    output wire [31:0] o_result,
    // Equality result. This is used externally to determine if a branch
    // should be taken.
    output wire        o_eq,
    // Set less than result. This is used externally to determine if a branch
    // should be taken.
    output wire        o_slt
);
    wire [31:0] add_result;

    // ===============================================================
    // ADD / SUB LOGIC
    // ===============================================================
    kogge_stone_32 adder (
        .i_a(i_op1),
        .i_b(i_op2),
        .i_sub(i_sub),
        .o_result(add_result),
        .o_cout()
    );

    // ===============================================================
    // SHIFT LOGIC
    // ===============================================================
    wire [31:0] srl_result;
    wire [31:0] sra_result;

    assign srl_result = i_op1 >> i_op2[4:0];
    assign sra_result = i_op1[31]
                      ? ~((~i_op1) >> i_op2[4:0])
                      :  (i_op1 >> i_op2[4:0]);
    // ===============================================================
    // COMPARISON LOGIC
    // ===============================================================
    wire unsigned_less;
    wire signed_less;
    assign o_eq = (i_op1 == i_op2);
    // Normal unsigned comparison
    assign unsigned_less = (i_op1 < i_op2);
    // Signed comparison is a bit more complicated. If the signs are different, then
    // the negative number is less than the positive number. 
    assign signed_less = (i_op1[31] != i_op2[31])
                       ? i_op1[31]
                       : unsigned_less;
    assign o_slt = i_unsigned
                 ? unsigned_less
                 : signed_less;
    // ===============================================================
    // ALU RESULT
    // ===============================================================
    assign o_result = (i_opsel == 3'b000) ? add_result
                    : (i_opsel == 3'b001) ? (i_op1 << i_op2[4:0])
                    : ((i_opsel == 3'b010) ||
                       (i_opsel == 3'b011)) ? {31'b0, o_slt}
                    : (i_opsel == 3'b100) ? (i_op1 ^ i_op2)
                    : (i_opsel == 3'b101) ?
                        (i_arith ? sra_result : srl_result)
                    : (i_opsel == 3'b110) ? (i_op1 | i_op2)
                    : (i_opsel == 3'b111) ? (i_op1 & i_op2)
                    : 32'b0;
endmodule

// The Kogge-Stone adder is a parallel prefix form of carry lookahead adder. It
// is a purely combinational block that takes two 32-bit operands and outputs
// a 32-bit result and a carry out. It is used in the ALU for addition and subtraction operations.
// The Kogge-Stone adder is known for its logarithmic depth and high speed, making it suitable for high-performance applications.
// The adder can also be configured to perform subtraction by inverting the second operand and adding one (two's complement).
//https://www.scribd.com/document/173821525/Adder-Kogge-Stone-32bit-With-Test-Bench
module kogge_stone_32 (
    input  wire [31:0] i_a,
    input  wire [31:0] i_b,
    input wire         i_sub,
    output wire [31:0] o_result,
    output wire        o_cout
);
    // Original propagate and generate signals
    wire [31:0] p0;
    wire [31:0] g0;
    // Prefix tree levels
    wire [31:0] p1, g1;
    wire [31:0] p2, g2;
    wire [31:0] p3, g3;
    wire [31:0] p4, g4;
    wire [31:0] p5, g5;
    wire [32:0] carry;
    wire [31:0] b_in;
    assign b_in = i_b ^ {32{i_sub}};
    assign p0 = i_a ^ b_in;
    assign g0 = i_a & b_in;
    assign carry[0] = i_sub;
    // ================================================================
    // LEVEL 1
    // Distance = 1
    // ================================================================
    genvar i;
    generate
        for (i = 0; i < 32; i = i + 1) begin : LEVEL1
            if (i >= 1) begin
                assign g1[i] = g0[i] | (p0[i] & g0[i-1]);
                assign p1[i] = p0[i] & p0[i-1];
            end
            else begin
                assign g1[i] = g0[i];
                assign p1[i] = p0[i];
            end
        end
    endgenerate
    // ================================================================
    // LEVEL 2
    // Distance = 2
    // ================================================================
    generate
        for (i = 0; i < 32; i = i + 1) begin : LEVEL2
            if (i >= 2) begin
                assign g2[i] = g1[i] | (p1[i] & g1[i-2]);
                assign p2[i] = p1[i] & p1[i-2];
            end
            else begin
                assign g2[i] = g1[i];
                assign p2[i] = p1[i];
            end
        end
    endgenerate
    // ================================================================
    // LEVEL 3
    // Distance = 4
    // ================================================================
    generate
        for (i = 0; i < 32; i = i + 1) begin : LEVEL3
            if (i >= 4) begin
                assign g3[i] = g2[i] | (p2[i] & g2[i-4]);
                assign p3[i] = p2[i] & p2[i-4];
            end
            else begin
                assign g3[i] = g2[i];
                assign p3[i] = p2[i];
            end       
             end
    endgenerate
    // ================================================================
    // LEVEL 4
    // Distance = 8
    // ================================================================
    generate
        for (i = 0; i < 32; i = i + 1) begin : LEVEL4
            if (i >= 8) begin
                assign g4[i] = g3[i] | (p3[i] & g3[i-8]);

                assign p4[i] = p3[i] & p3[i-8];
            end
            else begin

                assign g4[i] = g3[i];
                assign p4[i] = p3[i];
            end
        end
    endgenerate
    // ================================================================
    // LEVEL 5
    // Distance = 16
    // ================================================================
    generate
        for (i = 0; i < 32; i = i + 1) begin : LEVEL5
            if (i >= 16) begin
                assign g5[i] = g4[i] | (p4[i] & g4[i-16]);
                assign p5[i] = p4[i] & p4[i-16];
            end
            else begin
                assign g5[i] = g4[i];
                assign p5[i] = p4[i];
            end
        end

    endgenerate
    // ================================================================
    // CARRY GENERATION
    //
    // g5[i] = generate for bits [i:0]
    // p5[i] = propagate for bits [i:0]
    //
    // C[i+1] = G[i:0] | (P[i:0] & Cin)
    // ================================================================
    generate
        for (i = 0; i < 32; i = i + 1) begin : CARRY_GEN
            assign carry[i+1] = g5[i] | (p5[i] & i_sub);
        end
    endgenerate
    // ===============================================================
    // SUM
    //
    // Important: use the ORIGINAL propagate signal here.
    // ================================================================
    assign o_result = p0 ^ carry[31:0];
    assign o_cout = carry[32];
endmodule

`default_nettype wire
