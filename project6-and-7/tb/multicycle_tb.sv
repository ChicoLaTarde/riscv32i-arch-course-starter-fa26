`timescale 1ns/1ps
`default_nettype none

module multicycle_tb #(
    parameter RESET_ADDR = 0,
    parameter I_LATENCY = 4,
    parameter I_INTERVAL = 2,
    parameter D_LATENCY = 4,
    parameter D_INTERVAL = 2
);
    reg clk = 0;
    reg rst = 1;
    reg warming_up = 1;
    integer cycle = 0;
    integer terminal_cycle = -1;
    integer reset_after = 0;
    integer index, lane;
    string program_path;
    wire [31:0] imem_addr, imem_data, dmem_addr, dmem_wdata;
    wire imem_ren, imem_ready, imem_valid, dmem_ren, dmem_wen, dmem_ready, dmem_valid;
    wire [3:0] dmem_mask;
    wire i_model_ready, i_model_valid, d_model_ready, d_model_valid;
    wire [31:0] i_model_data, d_model_data, raw_dmem_data;
    reg [31:0] dmem_data;
    reg [3:0] pending_read_mask = 0;
    wire [3:0] read_mask;
    wire valid, trap, halt;
    wire [31:0] inst, pc, next_pc, rs1_data, rs2_data, rd_data;
    wire [4:0] rs1_addr, rs2_addr, rd_addr;
    wire [31:0] retire_addr, retire_wdata, retire_rdata;
    wire retire_ren, retire_wen;
    wire [3:0] retire_mask;

    always #5 clk = ~clk;

    memory #(.SIZE(16384), .LATENCY(I_LATENCY == 0 ? 2 : I_LATENCY), .INTERVAL(I_INTERVAL)) imem (
        .i_clk(clk), .i_rst(rst), .o_ready(i_model_ready), .i_addr(imem_addr),
        .i_ren(I_LATENCY == 0 ? 1'b0 : imem_ren), .i_wen(1'b0),
        .i_mask(4'b1111), .i_wdata(32'b0), .o_valid(i_model_valid),
        .o_rdata(i_model_data), .o_addr(), .o_wdone()
    );
    memory #(.SIZE(4096), .LATENCY(D_LATENCY == 0 ? 2 : D_LATENCY), .INTERVAL(D_INTERVAL)) dmem (
        .i_clk(clk), .i_rst(rst), .o_ready(d_model_ready), .i_addr(dmem_addr),
        .i_ren(D_LATENCY == 0 ? 1'b0 : dmem_ren),
        .i_wen(D_LATENCY == 0 ? 1'b0 : dmem_wen),
        .i_mask(dmem_mask), .i_wdata(dmem_wdata), .o_valid(d_model_valid),
        .o_rdata(d_model_data), .o_addr(), .o_wdone()
    );
    assign imem_ready = I_LATENCY == 0 ? (!rst && cycle % I_INTERVAL == 0) : i_model_ready;
    assign imem_valid = I_LATENCY == 0 ? imem_ren : i_model_valid;
    assign imem_data = I_LATENCY == 0 ?
        {imem.mem[imem_addr + 3], imem.mem[imem_addr + 2], imem.mem[imem_addr + 1], imem.mem[imem_addr]} : i_model_data;
    assign dmem_ready = D_LATENCY == 0 ? (!rst && cycle % D_INTERVAL == 0) : d_model_ready;
    assign dmem_valid = D_LATENCY == 0 ? dmem_ren : d_model_valid;
    assign raw_dmem_data = D_LATENCY == 0 ?
        {dmem.mem[dmem_addr + 3], dmem.mem[dmem_addr + 2], dmem.mem[dmem_addr + 1], dmem.mem[dmem_addr]} : d_model_data;
    assign read_mask = D_LATENCY == 0 ? dmem_mask : pending_read_mask;
    always @(*) begin
        dmem_data = 32'bx;
        if (dmem_valid) begin
            if (read_mask[0]) dmem_data[7:0] = raw_dmem_data[7:0];
            if (read_mask[1]) dmem_data[15:8] = raw_dmem_data[15:8];
            if (read_mask[2]) dmem_data[23:16] = raw_dmem_data[23:16];
            if (read_mask[3]) dmem_data[31:24] = raw_dmem_data[31:24];
        end
    end

    hart #(.RESET_ADDR(RESET_ADDR)) dut (
        .i_clk(clk), .i_rst(rst),
        .i_imem_ready(imem_ready), .o_imem_raddr(imem_addr), .o_imem_ren(imem_ren),
        .i_imem_valid(imem_valid), .i_imem_rdata(imem_data),
        .i_dmem_ready(dmem_ready), .o_dmem_addr(dmem_addr),
        .o_dmem_ren(dmem_ren), .o_dmem_wen(dmem_wen),
        .o_dmem_wdata(dmem_wdata), .o_dmem_mask(dmem_mask),
        .i_dmem_valid(dmem_valid), .i_dmem_rdata(dmem_data),
        .o_retire_valid(valid), .o_retire_inst(inst), .o_retire_trap(trap), .o_retire_halt(halt),
        .o_retire_rs1_raddr(rs1_addr), .o_retire_rs2_raddr(rs2_addr),
        .o_retire_rs1_rdata(rs1_data), .o_retire_rs2_rdata(rs2_data),
        .o_retire_rd_waddr(rd_addr), .o_retire_rd_wdata(rd_data),
        .o_retire_pc(pc), .o_retire_next_pc(next_pc),
        .o_retire_dmem_addr(retire_addr), .o_retire_dmem_ren(retire_ren),
        .o_retire_dmem_wen(retire_wen), .o_retire_dmem_mask(retire_mask),
        .o_retire_dmem_wdata(retire_wdata), .o_retire_dmem_rdata(retire_rdata)
    );

    always @(posedge clk) begin
        if (rst) begin
            pending_read_mask <= 0;
            if ({imem_ren, dmem_ren, dmem_wen, valid, retire_ren, retire_wen} !== 6'b0)
                $fatal(1, "architectural effect during reset");
        end else begin
            if ((^{imem_ren, dmem_ren, dmem_wen, valid}) === 1'bx)
                $fatal(1, "unknown request or retirement enable");
            if (imem_ren && !imem_ready)
                $fatal(1, "instruction request without ready");
            if ((dmem_ren || dmem_wen) && !dmem_ready)
                $fatal(1, "data request without ready");
            if (dmem_ren && dmem_wen)
                $fatal(1, "simultaneous data read/write");
            if ((dmem_ren || dmem_wen) && (dmem_addr >= 4096 || dmem_addr[1:0] != 0))
                $fatal(1, "bad data address");
            if (dmem_ren)
                pending_read_mask <= dmem_mask;
            if (D_LATENCY == 0 && dmem_wen)
                for (lane = 0; lane < 4; lane = lane + 1)
                    if (dmem_mask[lane])
                        dmem.mem[dmem_addr + lane] <= dmem_wdata[lane * 8 +: 8];
            if (!valid && (retire_ren !== 1'b0 || retire_wen !== 1'b0))
                $fatal(1, "retired memory effect during bubble");
            if (!warming_up) begin
                cycle = cycle + 1;
                if (dmem_ren || dmem_wen)
                    $display("BUS %h %h %h %h %h", dmem_ren, dmem_wen, dmem_addr, dmem_mask, dmem_wdata);
                if (valid) begin
                    if (terminal_cycle >= 0)
                        $fatal(1, "duplicate retirement after halt/trap");
                    $display("RET %0d %h %h %h %h %h %h %h %h %h %h %h", cycle,
                             pc, inst, trap, halt, rs1_addr, rs1_data, rs2_addr, rs2_data,
                             rd_addr, rd_data, next_pc);
                    $display("RET_MEM %h %h %h %h %h %h %h", pc,
                             retire_ren, retire_wen, retire_addr, retire_mask, retire_wdata, retire_rdata);
                    if (trap || halt)
                        terminal_cycle = cycle;
                end
                if (terminal_cycle >= 0 && (dmem_ren || dmem_wen))
                    $fatal(1, "new data request after halt/trap");
                if (terminal_cycle >= 0 && cycle == terminal_cycle + 40) begin
                    $display("DONE %d", cycle);
                    $finish;
                end
                if (cycle > 100000)
                    $fatal(1, "timeout");
            end
        end
    end

    initial begin
        for (index = 0; index < 16384; index = index + 1)
            imem.mem[index] = index % 4 == 0 ? 8'h13 : 8'h00;
        for (index = 0; index < 4096; index = index + 1)
            dmem.mem[index] = 0;
        if (!$value$plusargs("PROGRAM=%s", program_path))
            $fatal(1, "missing PROGRAM");
        $readmemh(program_path, imem.mem);
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
