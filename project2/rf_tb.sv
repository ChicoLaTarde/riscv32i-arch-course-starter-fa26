`default_nettype none

module rf_tb;

    // ================================================================
    // INPUTS
    // ================================================================

    logic        i_clk;
    logic        i_rst;

    logic [4:0]  i_rs1_raddr;
    logic [4:0]  i_rs2_raddr;

    logic        i_rd_wen;
    logic [4:0]  i_rd_waddr;
    logic [31:0] i_rd_wdata;


    // ================================================================
    // OUTPUTS
    // ================================================================

    wire [31:0] rs1_no_bypass;
    wire [31:0] rs2_no_bypass;

    wire [31:0] rs1_bypass;
    wire [31:0] rs2_bypass;


    integer tests_run;
    integer tests_failed;


    // ================================================================
    // DUT: BYPASS DISABLED
    // ================================================================

    rf #(
        .BYPASS_EN(0)
    ) dut_no_bypass (
        .i_clk       (i_clk),
        .i_rst       (i_rst),

        .i_rs1_raddr (i_rs1_raddr),
        .o_rs1_rdata (rs1_no_bypass),

        .i_rs2_raddr (i_rs2_raddr),
        .o_rs2_rdata (rs2_no_bypass),

        .i_rd_wen    (i_rd_wen),
        .i_rd_waddr  (i_rd_waddr),
        .i_rd_wdata  (i_rd_wdata)
    );


    // ================================================================
    // DUT: BYPASS ENABLED
    // ================================================================

    rf #(
        .BYPASS_EN(1)
    ) dut_bypass (
        .i_clk       (i_clk),
        .i_rst       (i_rst),

        .i_rs1_raddr (i_rs1_raddr),
        .o_rs1_rdata (rs1_bypass),

        .i_rs2_raddr (i_rs2_raddr),
        .o_rs2_rdata (rs2_bypass),

        .i_rd_wen    (i_rd_wen),
        .i_rd_waddr  (i_rd_waddr),
        .i_rd_wdata  (i_rd_wdata)
    );


    // ================================================================
    // CLOCK
    // 10 ns period
    // ================================================================

    initial begin
        i_clk = 0;

        forever #5 i_clk = ~i_clk;
    end


    // ================================================================
    // CHECK TASK
    // ================================================================

    task automatic check_outputs (
        input string       test_name,
        input logic [31:0] expected_rs1_no_bypass,
        input logic [31:0] expected_rs2_no_bypass,
        input logic [31:0] expected_rs1_bypass,
        input logic [31:0] expected_rs2_bypass
    );

        begin
            #1;

            tests_run = tests_run + 1;

            if ((rs1_no_bypass !== expected_rs1_no_bypass) ||
                (rs2_no_bypass !== expected_rs2_no_bypass) ||
                (rs1_bypass    !== expected_rs1_bypass) ||
                (rs2_bypass    !== expected_rs2_bypass)) begin

                tests_failed = tests_failed + 1;

                $error(
                    "[FAIL] %s\nNO BYPASS: rs1=%h expected=%h | rs2=%h expected=%h\nBYPASS:    rs1=%h expected=%h | rs2=%h expected=%h",
                    test_name,

                    rs1_no_bypass,
                    expected_rs1_no_bypass,

                    rs2_no_bypass,
                    expected_rs2_no_bypass,

                    rs1_bypass,
                    expected_rs1_bypass,

                    rs2_bypass,
                    expected_rs2_bypass
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

        i_rst       = 0;

        i_rs1_raddr = 0;
        i_rs2_raddr = 0;

        i_rd_wen    = 0;
        i_rd_waddr  = 0;
        i_rd_wdata  = 0;


        // ============================================================
        // TEST 1: RESET
        // ============================================================

        i_rst = 1;

        @(posedge i_clk);
        #1;

        i_rst = 0;

        i_rs1_raddr = 5'd1;
        i_rs2_raddr = 5'd31;

        check_outputs(
            "RESET: registers cleared",
            32'b0,
            32'b0,
            32'b0,
            32'b0
        );


        // ============================================================
        // TEST 2: X0 ALWAYS ZERO
        // ============================================================

        i_rs1_raddr = 5'd0;
        i_rs2_raddr = 5'd0;

        check_outputs(
            "X0 reads zero",
            32'b0,
            32'b0,
            32'b0,
            32'b0
        );


        // ============================================================
        // TEST 3: ATTEMPT WRITE TO X0
        // ============================================================

        i_rd_wen   = 1;
        i_rd_waddr = 5'd0;
        i_rd_wdata = 32'hDEAD_BEEF;

        @(posedge i_clk);
        #1;

        i_rd_wen = 0;

        i_rs1_raddr = 5'd0;
        i_rs2_raddr = 5'd0;

        check_outputs(
            "Write to X0 ignored",
            32'b0,
            32'b0,
            32'b0,
            32'b0
        );


        // ============================================================
        // TEST 4: WRITE X5
        // ============================================================

        i_rd_wen   = 1;
        i_rd_waddr = 5'd5;
        i_rd_wdata = 32'h1234_5678;

        @(posedge i_clk);
        #1;

        i_rd_wen = 0;

        i_rs1_raddr = 5'd5;
        i_rs2_raddr = 5'd0;

        check_outputs(
            "Write and read X5",
            32'h1234_5678,
            32'b0,
            32'h1234_5678,
            32'b0
        );


        // ============================================================
        // TEST 5: WRITE X10
        // ============================================================

        i_rd_wen   = 1;
        i_rd_waddr = 5'd10;
        i_rd_wdata = 32'hCAFE_BABE;

        @(posedge i_clk);
        #1;

        i_rd_wen = 0;

        i_rs1_raddr = 5'd10;
        i_rs2_raddr = 5'd5;

        check_outputs(
            "Two independent read ports",
            32'hCAFE_BABE,
            32'h1234_5678,
            32'hCAFE_BABE,
            32'h1234_5678
        );


        // ============================================================
        // TEST 6: ASYNCHRONOUS READ
        //
        // No clock edge occurs between changing the address and checking
        // the output.
        // ============================================================

        i_rs1_raddr = 5'd5;
        i_rs2_raddr = 5'd10;

        check_outputs(
            "Asynchronous reads",
            32'h1234_5678,
            32'hCAFE_BABE,
            32'h1234_5678,
            32'hCAFE_BABE
        );


        // ============================================================
        // TEST 7: BYPASS
        //
        // Current value:
        //      X5 = 12345678
        //
        // We are about to write:
        //      X5 = AABBCCDD
        //
        // BEFORE the clock edge:
        //
        // BYPASS_EN=0 -> old value
        // BYPASS_EN=1 -> new write data
        // ============================================================

        i_rs1_raddr = 5'd5;
        i_rs2_raddr = 5'd10;

        i_rd_wen    = 1;
        i_rd_waddr  = 5'd5;
        i_rd_wdata  = 32'hAABB_CCDD;

        check_outputs(
            "Bypass before clock edge",
            32'h1234_5678,       // normal RF sees old X5
            32'hCAFE_BABE,
            32'hAABB_CCDD,       // bypass RF sees new data
            32'hCAFE_BABE
        );


        // ============================================================
        // TEST 8: AFTER CLOCK EDGE
        //
        // Both register files should now contain AABBCCDD.
        // ============================================================

        @(posedge i_clk);
        #1;

        i_rd_wen = 0;

        check_outputs(
            "Write visible after clock edge",
            32'hAABB_CCDD,
            32'hCAFE_BABE,
            32'hAABB_CCDD,
            32'hCAFE_BABE
        );


        // ============================================================
        // TEST 9: BYPASS ON RS2
        // ============================================================

        i_rs1_raddr = 5'd5;
        i_rs2_raddr = 5'd10;

        i_rd_wen    = 1;
        i_rd_waddr  = 5'd10;
        i_rd_wdata  = 32'h1111_2222;

        check_outputs(
            "Bypass on RS2",
            32'hAABB_CCDD,
            32'hCAFE_BABE,
            32'hAABB_CCDD,
            32'h1111_2222
        );


        // Commit X10 write
        @(posedge i_clk);
        #1;

        i_rd_wen = 0;


        // ============================================================
        // TEST 10: BYPASS BOTH READ PORTS
        //
        // Both ports read X20 while X20 is being written.
        // ============================================================

        i_rs1_raddr = 5'd20;
        i_rs2_raddr = 5'd20;

        i_rd_wen    = 1;
        i_rd_waddr  = 5'd20;
        i_rd_wdata  = 32'hFACE_CAFE;

        check_outputs(
            "Bypass both read ports",
            32'b0,
            32'b0,
            32'hFACE_CAFE,
            32'hFACE_CAFE
        );


        // Commit X20
        @(posedge i_clk);
        #1;

        i_rd_wen = 0;


        // ============================================================
        // TEST 11: BYPASS MUST NOT BREAK X0
        // ============================================================

        i_rs1_raddr = 5'd0;
        i_rs2_raddr = 5'd0;

        i_rd_wen    = 1;
        i_rd_waddr  = 5'd0;
        i_rd_wdata  = 32'hFFFF_FFFF;

        check_outputs(
            "X0 protected during bypass",
            32'b0,
            32'b0,
            32'b0,
            32'b0
        );

        i_rd_wen = 0;


        // ============================================================
        // TEST 12: VERIFY STORED VALUES
        // ============================================================

        i_rs1_raddr = 5'd10;
        i_rs2_raddr = 5'd20;

        check_outputs(
            "Verify stored registers",
            32'h1111_2222,
            32'hFACE_CAFE,
            32'h1111_2222,
            32'hFACE_CAFE
        );


        // ============================================================
        // SUMMARY
        // ============================================================

        $display("");
        $display("========================================");
        $display(" REGISTER FILE TEST SUMMARY");
        $display("========================================");
        $display(" Tests run    : %0d", tests_run);
        $display(" Tests passed : %0d", tests_run - tests_failed);
        $display(" Tests failed : %0d", tests_failed);
        $display("========================================");

        if (tests_failed == 0) begin
            $display("ALL REGISTER FILE TESTS PASSED");
        end
        else begin
            $fatal(1, "REGISTER FILE TEST FAILED");
        end

        $finish;
    end

endmodule

`default_nettype wire