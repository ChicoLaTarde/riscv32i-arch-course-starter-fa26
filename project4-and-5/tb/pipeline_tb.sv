`timescale 1ns/1ps
`default_nettype none

// External-interface harness used by run_pipeline_tests.py.
module pipeline_tb #(
    parameter RESET_ADDR = 32'h00000000
);
    reg clk = 0;
    reg rst = 1;
    wire [31:0] imem_addr, imem_data, dmem_addr, dmem_wdata;
    reg [31:0] dmem_rdata;
    wire dmem_ren, dmem_wen;
    wire [3:0] dmem_mask;
    wire valid, trap, halt;
    wire [31:0] inst, pc, next_pc, rs1_data, rs2_data, rd_data;
    wire [4:0] rs1_addr, rs2_addr, rd_addr;
    reg [31:0] imem [0:4095];
    reg [7:0] dmem [0:4095];
    string program_path;
    integer index, lane;
    integer cycle = 0;
    integer terminal_cycle = -1;
    integer reset_after = 0;
    reg warming_up = 1;

    hart #(.RESET_ADDR(RESET_ADDR)) dut (
        .i_clk(clk), .i_rst(rst),
        .o_imem_raddr(imem_addr), .i_imem_rdata(imem_data),
        .o_dmem_addr(dmem_addr), .o_dmem_ren(dmem_ren), .o_dmem_wen(dmem_wen),
        .o_dmem_wdata(dmem_wdata), .o_dmem_mask(dmem_mask), .i_dmem_rdata(dmem_rdata),
        .o_retire_valid(valid), .o_retire_inst(inst),
        .o_retire_trap(trap), .o_retire_halt(halt),
        .o_retire_rs1_raddr(rs1_addr), .o_retire_rs2_raddr(rs2_addr),
        .o_retire_rs1_rdata(rs1_data), .o_retire_rs2_rdata(rs2_data),
        .o_retire_rd_waddr(rd_addr), .o_retire_rd_wdata(rd_data),
        .o_retire_pc(pc), .o_retire_next_pc(next_pc)
    );

    always #5 clk = ~clk;
    assign imem_data = (imem_addr < 16384) ? imem[imem_addr[13:2]] : 32'h00000013;

    // Disabled/masked read lanes deliberately contain X, matching the port
    // contract and exposing incorrect load-byte extraction.
    always @(*) begin
        dmem_rdata = 32'bx;
        if (dmem_ren && dmem_addr < 4096) begin
            if (dmem_mask[0]) dmem_rdata[7:0] = dmem[dmem_addr];
            if (dmem_mask[1]) dmem_rdata[15:8] = dmem[dmem_addr + 1];
            if (dmem_mask[2]) dmem_rdata[23:16] = dmem[dmem_addr + 2];
            if (dmem_mask[3]) dmem_rdata[31:24] = dmem[dmem_addr + 3];
        end
    end

    // Sample before nonblocking updates: this is the instruction retiring
    // and the store committing on this edge.
    always @(posedge clk) begin
        if (rst) begin
            if (valid !== 1'b0 || dmem_ren !== 1'b0 || dmem_wen !== 1'b0)
                $fatal(1, "architectural effect during reset");
        end else begin
            if ((^{valid, dmem_ren, dmem_wen}) === 1'bx)
                $fatal(1, "unknown valid/memory enable");
            if (dmem_ren && dmem_wen)
                $fatal(1, "simultaneous memory read and write");
            if (dmem_ren || dmem_wen) begin
                if (dmem_addr >= 4096 || dmem_addr[1:0] != 0)
                    $fatal(1, "invalid memory address %h", dmem_addr);
                if (!warming_up)
                    $display("BUS %h %h %h %h %h", dmem_ren, dmem_wen,
                             dmem_addr, dmem_mask, dmem_wdata);
                for (lane = 0; lane < 4; lane = lane + 1)
                    if (dmem_wen && dmem_mask[lane])
                        dmem[dmem_addr + lane] <= dmem_wdata[lane * 8 +: 8];
            end
            if (!warming_up) begin
                cycle = cycle + 1;
                if (valid) begin
                    $display("RET %0d %h %h %h %h %h %h %h %h %h %h %h",
                             cycle, pc, inst, trap, halt,
                             rs1_addr, rs1_data, rs2_addr, rs2_data,
                             rd_addr, rd_data, next_pc);
                    if (terminal_cycle >= 0)
                        $fatal(1, "instruction retired after halt/trap");
                    if (trap || halt) terminal_cycle = cycle;
                end
                if (terminal_cycle >= 0 && (dmem_ren || dmem_wen))
                    $fatal(1, "memory access after halt/trap");
                if (terminal_cycle >= 0 && cycle == terminal_cycle + 8) begin
                    $display("DONE %0d", cycle);
                    $finish;
                end
                if (cycle > 20000) $fatal(1, "pipeline timed out");
            end
        end
    end

    initial begin
        for (index = 0; index < 4096; index = index + 1) begin
            imem[index] = 32'h00000013;
            dmem[index] = 0;
        end
        if (!$value$plusargs("PROGRAM=%s", program_path))
            $fatal(1, "missing PROGRAM file");
        $readmemh(program_path, imem);
        if ($value$plusargs("RESET_AFTER=%d", reset_after)) begin end
        repeat (2) @(negedge clk);
        rst = 0;
        if (reset_after > 0) begin
            repeat (reset_after) @(negedge clk);
            rst = 1;
            repeat (2) @(negedge clk);
            rst = 0;
        end
        warming_up = 0;
    end
endmodule

`default_nettype wire
