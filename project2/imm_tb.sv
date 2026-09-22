`timescale 1ns/1ps
`default_nettype none

module imm_tb;

    // ------------------------------------------------------------------------
    // DUT interface
    // ------------------------------------------------------------------------
    logic [31:0] i_inst;
    logic [5:0]  i_format;
    wire  [31:0] o_immediate;

    imm dut (
        .i_inst      (i_inst),
        .i_format    (i_format),
        .o_immediate (o_immediate)
    );

    // ------------------------------------------------------------------------
    // Format encoding
    // ------------------------------------------------------------------------
    localparam logic [5:0] FMT_R = 6'b000001;
    localparam logic [5:0] FMT_I = 6'b000010;
    localparam logic [5:0] FMT_S = 6'b000100;
    localparam logic [5:0] FMT_B = 6'b001000;
    localparam logic [5:0] FMT_U = 6'b010000;
    localparam logic [5:0] FMT_J = 6'b100000;

    int unsigned tests_run;
    int unsigned tests_failed;

    // ------------------------------------------------------------------------
    // Generic checker
    // ------------------------------------------------------------------------
    task automatic check_imm(
        input string       test_name,
        input logic [31:0] inst,
        input logic [5:0]  format,
        input logic [31:0] expected
    );
        begin
            i_inst   = inst;
            i_format = format;

            // DUT is combinational. Allow propagation through the DUT.
            #1;

            tests_run++;

            if (o_immediate !== expected) begin
                tests_failed++;

                $error(
                    "[FAIL] %-24s inst=%08h format=%06b expected=%08h actual=%08h",
                    test_name,
                    inst,
                    format,
                    expected,
                    o_immediate
                );
            end
            else begin
                $display(
                    "[PASS] %-24s expected=%08h actual=%08h",
                    test_name,
                    expected,
                    o_immediate
                );
            end
        end
    endtask


    // ------------------------------------------------------------------------
    // Test sequence
    // ------------------------------------------------------------------------
    initial begin

        tests_run    = 0;
        tests_failed = 0;

        i_inst   = '0;
        i_format = '0;

        // ================================================================
        // I-TYPE
        //
        // immediate = sign_extend(inst[31:20])
        // ================================================================

        // +1
        check_imm(
            "I: +1",
            32'h0010_0013,
            FMT_I,
            32'h0000_0001
        );

        // Largest positive 12-bit signed immediate: +2047
        check_imm(
            "I: max positive",
            32'h7FF0_0013,
            FMT_I,
            32'h0000_07FF
        );

        // -1
        check_imm(
            "I: -1",
            32'hFFF0_0013,
            FMT_I,
            32'hFFFF_FFFF
        );

        // Most negative 12-bit immediate: -2048
        check_imm(
            "I: min negative",
            32'h8000_0013,
            FMT_I,
            32'hFFFF_F800
        );


        // ================================================================
        // S-TYPE
        //
        // imm[11:5] = inst[31:25]
        // imm[4:0]  = inst[11:7]
        // ================================================================

        // Immediate = 4
        check_imm(
            "S: +4",
            32'h0000_2223,
            FMT_S,
            32'h0000_0004
        );

        // Immediate = -1
        check_imm(
            "S: -1",
            32'hFE00_2FA3,
            FMT_S,
            32'hFFFF_FFFF
        );


        // ================================================================
        // B-TYPE
        //
        // imm[12]   = inst[31]
        // imm[11]   = inst[7]
        // imm[10:5] = inst[30:25]
        // imm[4:1]  = inst[11:8]
        // imm[0]    = 0
        // ================================================================

        // +8 branch displacement
        check_imm(
            "B: +8",
            32'h0000_0463,
            FMT_B,
            32'h0000_0008
        );

        // -4 branch displacement
        check_imm(
            "B: -4",
            32'hFE00_0EE3,
            FMT_B,
            32'hFFFF_FFFC
        );


        // ================================================================
        // U-TYPE
        //
        // immediate = inst[31:12] << 12
        // ================================================================

        check_imm(
            "U: pattern",
            32'h1234_50B7,
            FMT_U,
            32'h1234_5000
        );

        check_imm(
            "U: upper all ones",
            32'hFFFF_F0B7,
            FMT_U,
            32'hFFFF_F000
        );


        // ================================================================
        // J-TYPE
        //
        // imm[20]    = inst[31]
        // imm[19:12] = inst[19:12]
        // imm[11]    = inst[20]
        // imm[10:1]  = inst[30:21]
        // imm[0]     = 0
        // ================================================================

        // jal x0, +8
        check_imm(
            "J: +8",
            32'h0080_006F,
            FMT_J,
            32'h0000_0008
        );

        // jal x0, -4
        check_imm(
            "J: -4",
            32'hFFDFF06F,
            FMT_J,
            32'hFFFF_FFFC
        );

        // ================================================================
        // R-TYPE
        //
        // R-type instructions do not contain an immediate.
        // The immediate generator should therefore output don't-care (X).
        // ================================================================

        // add x5, x6, x7
        check_imm(
            "R: ADD no immediate",
            32'h007302B3,
            FMT_R,
            32'hxxxxxxxx
        );


        // ================================================================
        // Invalid / no format selected
        // ================================================================

        check_imm(
            "Invalid format",
            32'h1234_5678,
            6'b000000,
            32'h0000_0000
        );


        // ================================================================
        // Summary
        // ================================================================

        $display("");
        $display("========================================");
        $display(" IMM UNIT TEST SUMMARY");
        $display("========================================");
        $display(" Tests run    : %0d", tests_run);
        $display(" Tests passed : %0d", tests_run - tests_failed);
        $display(" Tests failed : %0d", tests_failed);
        $display("========================================");

        if (tests_failed != 0) begin
            $fatal(1, "IMM verification FAILED");
        end

        $display("IMM verification PASSED");

        $finish;
    end

endmodule

`default_nettype wire