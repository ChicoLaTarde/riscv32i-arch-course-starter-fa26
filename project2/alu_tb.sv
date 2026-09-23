`timescale 1ns/1ps
`default_nettype none

module alu_tb;

    logic [2:0]  i_opsel;
    logic        i_sub;
    logic        i_unsigned;
    logic        i_arith;
    logic [31:0] i_op1;
    logic [31:0] i_op2;

    wire [31:0] o_result;
    wire        o_eq;
    wire        o_slt;

    integer tests_run;
    integer tests_failed;


    // ================================================================
    // DUT
    // ================================================================

    alu dut (
        .i_opsel    (i_opsel),
        .i_sub      (i_sub),
        .i_unsigned (i_unsigned),
        .i_arith    (i_arith),
        .i_op1      (i_op1),
        .i_op2      (i_op2),
        .o_result   (o_result),
        .o_eq       (o_eq),
        .o_slt      (o_slt)
    );


    // ================================================================
    // TEST TASK
    // ================================================================

    task automatic check_alu (
        input string       test_name,
        input logic [2:0]  opsel,
        input logic        sub,
        input logic        unsign,
        input logic        arith,
        input logic [31:0] op1,
        input logic [31:0] op2,
        input logic [31:0] expected_result,
        input logic        expected_eq,
        input logic        expected_slt
    );

        begin
            i_opsel    = opsel;
            i_sub      = sub;
            i_unsigned = unsign;
            i_arith    = arith;
            i_op1      = op1;
            i_op2      = op2;

            #10;

            tests_run = tests_run + 1;

            if ((o_result !== expected_result) ||
                (o_eq     !== expected_eq)     ||
                (o_slt    !== expected_slt)) begin

                tests_failed = tests_failed + 1;

                $error(
                    "[FAIL] %s\n  op1=%h op2=%h\n  result=%h expected=%h\n  eq=%b expected=%b\n  slt=%b expected=%b",
                    test_name,
                    op1,
                    op2,
                    o_result,
                    expected_result,
                    o_eq,
                    expected_eq,
                    o_slt,
                    expected_slt
                );

            end
            else begin
                $display("[PASS] %s", test_name);
            end
        end

    endtask


    // ================================================================
    // TESTS
    // ================================================================

    initial begin

        tests_run    = 0;
        tests_failed = 0;

        i_opsel    = 3'b000;
        i_sub      = 0;
        i_unsigned = 0;
        i_arith    = 0;
        i_op1      = 0;
        i_op2      = 0;

        #10;


        // ============================================================
        // ADD
        // ============================================================

        check_alu(
            "ADD: 10 + 5",
            3'b000, 0, 0, 0,
            32'd10,
            32'd5,
            32'd15,
            0,
            0
        );

        check_alu(
            "ADD: zero + zero",
            3'b000, 0, 0, 0,
            32'd0,
            32'd0,
            32'd0,
            1,
            0
        );

        check_alu(
            "ADD: overflow lower 32 bits",
            3'b000, 0, 0, 0,
            32'hFFFF_FFFF,
            32'h0000_0001,
            32'h0000_0000,
            0,
            1
        );


        // ============================================================
        // SUB
        // ============================================================

        check_alu(
            "SUB: 10 - 5",
            3'b000, 1, 0, 0,
            32'd10,
            32'd5,
            32'd5,
            0,
            0
        );

        check_alu(
            "SUB: 5 - 10",
            3'b000, 1, 0, 0,
            32'd5,
            32'd10,
            32'hFFFF_FFFB,
            0,
            1
        );

        check_alu(
            "SUB: equal operands",
            3'b000, 1, 0, 0,
            32'd100,
            32'd100,
            32'd0,
            1,
            0
        );


        // ============================================================
        // SHIFT LEFT LOGICAL
        // ============================================================

        check_alu(
            "SLL: 1 << 4",
            3'b001, 0, 0, 0,
            32'h0000_0001,
            32'd4,
            32'h0000_0010,
            0,
            1
        );

        check_alu(
            "SLL: shift by 31",
            3'b001, 0, 0, 0,
            32'h0000_0001,
            32'd31,
            32'h8000_0000,
            0,
            1
        );


        // ============================================================
        // SET LESS THAN - SIGNED
        // ============================================================

        check_alu(
            "SLT signed: 5 < 10",
            3'b010, 0, 0, 0,
            32'd5,
            32'd10,
            32'd1,
            0,
            1
        );

        check_alu(
            "SLT signed: 10 < 5",
            3'b010, 0, 0, 0,
            32'd10,
            32'd5,
            32'd0,
            0,
            0
        );

        check_alu(
            "SLT signed: -1 < 1",
            3'b010, 0, 0, 0,
            32'hFFFF_FFFF,
            32'h0000_0001,
            32'd1,
            0,
            1
        );


        // ============================================================
        // SET LESS THAN - UNSIGNED
        // ============================================================

        check_alu(
            "SLTU: FFFFFFFF < 1",
            3'b011, 0, 1, 0,
            32'hFFFF_FFFF,
            32'h0000_0001,
            32'd0,
            0,
            0
        );

        check_alu(
            "SLTU: 1 < FFFFFFFF",
            3'b011, 0, 1, 0,
            32'h0000_0001,
            32'hFFFF_FFFF,
            32'd1,
            0,
            1
        );


        // ============================================================
        // XOR
        // ============================================================

        check_alu(
            "XOR",
            3'b100, 0, 0, 0,
            32'hAAAA_AAAA,
            32'h5555_5555,
            32'hFFFF_FFFF,
            0,
            1
        );


        // ============================================================
        // SHIFT RIGHT LOGICAL
        // ============================================================

        check_alu(
            "SRL",
            3'b101, 0, 1, 0,
            32'h8000_0000,
            32'd4,
            32'h0800_0000,
            0,
            0
        );


        // ============================================================
        // SHIFT RIGHT ARITHMETIC
        // ============================================================

        check_alu(
            "SRA",
            3'b101, 0, 0, 1,
            32'h8000_0000,
            32'd4,
            32'hF800_0000,
            0,
            1
        );

        check_alu(
            "SRA: -1 >> 31",
            3'b101, 0, 0, 1,
            32'hFFFF_FFFF,
            32'd31,
            32'hFFFF_FFFF,
            0,
            1
        );


        // ============================================================
        // OR
        // ============================================================

        check_alu(
            "OR",
            3'b110, 0, 0, 0,
            32'hAAAA_0000,
            32'h0000_5555,
            32'hAAAA_5555,
            0,
            1
        );


        // ============================================================
        // AND
        // ============================================================

        check_alu(
            "AND",
            3'b111, 0, 0, 0,
            32'hFFFF_0000,
            32'hAAAA_5555,
            32'hAAAA_0000,
            0,
            0
        );


        // ============================================================
        // EQUALITY
        // ============================================================

        check_alu(
            "EQ: identical values",
            3'b100, 0, 0, 0,
            32'h1234_5678,
            32'h1234_5678,
            32'h0000_0000,
            1,
            0
        );


        // ============================================================
        // SUMMARY
        // ============================================================

        $display("");
        $display("========================================");
        $display(" ALU TEST SUMMARY");
        $display("========================================");
        $display(" Tests run    : %0d", tests_run);
        $display(" Tests passed : %0d", tests_run - tests_failed);
        $display(" Tests failed : %0d", tests_failed);
        $display("========================================");

        if (tests_failed == 0) begin
            $display("ALL TESTS PASSED");
        end
        else begin
            $fatal(1, "ALU TEST FAILED");
        end

        $finish;
    end

endmodule

`default_nettype wire