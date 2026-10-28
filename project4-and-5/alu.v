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
    reg [31:0] result;
    wire [31:0] left_1, left_2, left_4, left_8, left_16;
    wire [31:0] right_1, right_2, right_4, right_8, right_16;
    wire right_fill;

    // Each mux optionally shifts by a fixed amount, for a total of 0-31 bits.
    assign left_1  = i_op2[0] ? {i_op1[30:0], 1'b0} : i_op1;
    assign left_2  = i_op2[1] ? {left_1[29:0], 2'b0} : left_1;
    assign left_4  = i_op2[2] ? {left_2[27:0], 4'b0} : left_2;
    assign left_8  = i_op2[3] ? {left_4[23:0], 8'b0} : left_4;
    assign left_16 = i_op2[4] ? {left_8[15:0], 16'b0} : left_8;

    // Arithmetic shifts copy the original sign bit; logical shifts insert zero.
    assign right_fill = i_arith & i_op1[31];
    assign right_1  = i_op2[0] ? {right_fill, i_op1[31:1]} : i_op1;
    assign right_2  = i_op2[1] ? {{2{right_fill}}, right_1[31:2]} : right_1;
    assign right_4  = i_op2[2] ? {{4{right_fill}}, right_2[31:4]} : right_2;
    assign right_8  = i_op2[3] ? {{8{right_fill}}, right_4[31:8]} : right_4;
    assign right_16 = i_op2[4] ? {{16{right_fill}}, right_8[31:16]} : right_8;

    always @(*) begin
    result = 32'b0; // Default assignment

    // 3'b001: shift left logical
    // 3'b010,
    // 3'b011: set less than/unsigned if `i_unsigned` asserted
    // 3'b100: exclusive or
    // 3'b101: shift right logical/arithmetic if `i_arith` asserted
    // 3'b110: or
    // 3'b111: and
    case (i_opsel)
        3'b000: begin // addition / sub
            result = i_sub ? (i_op1 - i_op2) : (i_op1 + i_op2);
        end

        3'b001: begin
            result = left_16;
        end

        3'b010,
        3'b011: begin
            result = {31'b0, o_slt};
        end

        3'b100: begin
            result = i_op1 ^ i_op2;
        end

        3'b101: begin
            result = right_16;
        end

        3'b110: begin
            result = i_op1 | i_op2;
        end

        3'b111: begin
            result = i_op1 & i_op2;
        end

        default: begin
            result = 32'b0;
        end
    endcase
end


    assign o_result = result; 

    assign o_eq = (i_op1 == i_op2);
    // Unsigned ordering also works for signed operands with matching signs.
    // With different signs, the negative operand is the smaller signed value.
    assign o_slt = (~i_unsigned & (i_op1[31] ^ i_op2[31]))
        ? i_op1[31]
        : (i_op1 < i_op2);
endmodule

`default_nettype wire
