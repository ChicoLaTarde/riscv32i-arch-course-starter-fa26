`timescale 1ns/1ps
`default_nettype none

// Run from the repository root:
// iverilog -g2012 -s xm_mw_register_tb -o /tmp/xm_mw_register_tb \
//   project4-and-5/pipeline_registers/{xm,mw}_register.v project4-and-5/tb/xm_mw_register_tb.sv
// vvp /tmp/xm_mw_register_tb
module xm_mw_register_tb;
    typedef struct packed {
        logic valid;
        logic [31:0] inst, pc, next_pc;
        logic [4:0] rs1_raddr, rs2_raddr, rd_waddr;
        logic [31:0] rs1_rdata, rs2_rdata, alu_result, pc_plus4;
        logic mem_ren, mem_wen;
        logic [1:0] wb_sel;
        logic reg_wen, trap, halt;
    } execute_t;

    typedef struct packed {
        logic valid;
        logic [31:0] inst, pc, next_pc;
        logic [4:0] rs1_raddr, rs2_raddr, rd_waddr;
        logic [31:0] rs1_rdata, rs2_rdata, rd_wdata;
        logic reg_wen, trap, halt;
    } writeback_t;

    logic clk = 0, rst = 1;
    logic xm_flush = 0, mw_flush = 0, xm_stall = 0, mw_stall = 0;
    logic [31:0] load_data = 0;
    execute_t e, bubble, nop_insn, add_insn, load_insn, jump_insn, store_insn, flags_insn, reserved;
    wire execute_t m;
    wire writeback_t w;

    always #5 clk = ~clk;

    xm_register xm (
        .i_clk(clk), .i_rst(rst), .i_flush(xm_flush), .i_stall(xm_stall),
        .i_valid(e.valid), .i_inst(e.inst), .i_pc(e.pc), .i_next_pc(e.next_pc),
        .i_rs1_raddr(e.rs1_raddr), .i_rs2_raddr(e.rs2_raddr), .i_rd_waddr(e.rd_waddr),
        .i_rs1_rdata(e.rs1_rdata), .i_rs2_rdata(e.rs2_rdata),
        .i_alu_result(e.alu_result), .i_pc_plus4(e.pc_plus4),
        .i_mem_ren(e.mem_ren), .i_mem_wen(e.mem_wen), .i_wb_sel(e.wb_sel),
        .i_reg_wen(e.reg_wen), .i_trap(e.trap), .i_halt(e.halt),
        .o_valid(m.valid), .o_inst(m.inst), .o_pc(m.pc), .o_next_pc(m.next_pc),
        .o_rs1_raddr(m.rs1_raddr), .o_rs2_raddr(m.rs2_raddr), .o_rd_waddr(m.rd_waddr),
        .o_rs1_rdata(m.rs1_rdata), .o_rs2_rdata(m.rs2_rdata),
        .o_alu_result(m.alu_result), .o_pc_plus4(m.pc_plus4),
        .o_mem_ren(m.mem_ren), .o_mem_wen(m.mem_wen), .o_wb_sel(m.wb_sel),
        .o_reg_wen(m.reg_wen), .o_trap(m.trap), .o_halt(m.halt)
    );

    mw_register mw (
        .i_clk(clk), .i_rst(rst), .i_flush(mw_flush), .i_stall(mw_stall),
        .i_valid(m.valid), .i_inst(m.inst), .i_pc(m.pc), .i_next_pc(m.next_pc),
        .i_rs1_raddr(m.rs1_raddr), .i_rs2_raddr(m.rs2_raddr), .i_rd_waddr(m.rd_waddr),
        .i_rs1_rdata(m.rs1_rdata), .i_rs2_rdata(m.rs2_rdata),
        .i_alu_result(m.alu_result), .i_mem_data(load_data), .i_pc_plus4(m.pc_plus4),
        .i_wb_sel(m.wb_sel), .i_reg_wen(m.reg_wen), .i_trap(m.trap), .i_halt(m.halt),
        .o_valid(w.valid), .o_inst(w.inst), .o_pc(w.pc), .o_next_pc(w.next_pc),
        .o_rs1_raddr(w.rs1_raddr), .o_rs2_raddr(w.rs2_raddr), .o_rd_waddr(w.rd_waddr),
        .o_rs1_rdata(w.rs1_rdata), .o_rs2_rdata(w.rs2_rdata),
        .o_rd_wdata(w.rd_wdata), .o_reg_wen(w.reg_wen), .o_trap(w.trap), .o_halt(w.halt)
    );

    // The expected result is supplied explicitly by each scenario. Check that
    // all retirement metadata still belongs to the instruction that produced it.
    task automatic check_stages(input execute_t expected_m,
                                input execute_t owner_w,
                                input logic [31:0] result_w,
                                input string scenario);
        writeback_t expected_w;
        expected_w = {owner_w.valid, owner_w.inst, owner_w.pc, owner_w.next_pc,
                      owner_w.rs1_raddr, owner_w.rs2_raddr, owner_w.rd_waddr,
                      owner_w.rs1_rdata, owner_w.rs2_rdata, result_w,
                      owner_w.reg_wen, owner_w.trap, owner_w.halt};
        if (m !== expected_m)
            $fatal(1, "%s: XM expected %h, got %h", scenario, expected_m, m);
        if (w !== expected_w)
            $fatal(1, "%s: MW expected %h, got %h", scenario, expected_w, w);
    endtask

    task automatic step(input execute_t expected_m,
                        input execute_t owner_w,
                        input logic [31:0] result_w,
                        input string scenario);
        @(posedge clk);
        #1;
        check_stages(expected_m, owner_w, result_w, scenario);
    endtask

    initial begin
        bubble = '0;
        bubble.inst = 32'h00000013;
        nop_insn = bubble;
        nop_insn.valid = 1;
        e = bubble;

        add_insn = bubble;
        add_insn.valid = 1;
        add_insn.inst = 32'h002082b3; // add x5, x1, x2
        add_insn.pc = 32'h100;
        add_insn.next_pc = 32'h104;
        add_insn.pc_plus4 = 32'h104;
        add_insn.rs1_raddr = 1;
        add_insn.rs2_raddr = 2;
        add_insn.rd_waddr = 5;
        add_insn.rs1_rdata = 10;
        add_insn.rs2_rdata = 20;
        add_insn.alu_result = 30;
        add_insn.reg_wen = 1;

        load_insn = add_insn;
        load_insn.inst = 32'h00318303; // lb x6, 3(x3)
        load_insn.pc = 32'h104;
        load_insn.next_pc = 32'h108;
        load_insn.pc_plus4 = 32'h108;
        load_insn.rs1_raddr = 3;
        load_insn.rs2_raddr = 0;
        load_insn.rd_waddr = 6;
        load_insn.rs1_rdata = 32'h2000;
        load_insn.rs2_rdata = 0;
        load_insn.alu_result = 32'h2003; // Low address bits must survive XM.
        load_insn.mem_ren = 1;
        load_insn.wb_sel = 1;

        jump_insn = bubble;
        jump_insn.valid = 1;
        jump_insn.inst = 32'h020003ef; // jal x7, +32
        jump_insn.pc = 32'h108;
        jump_insn.pc_plus4 = 32'h10c;
        jump_insn.next_pc = 32'h128;
        jump_insn.rd_waddr = 7;
        jump_insn.alu_result = 32'h55aa55aa;
        jump_insn.reg_wen = 1;
        jump_insn.wb_sel = 2;

        store_insn = bubble;
        store_insn.valid = 1;
        store_insn.inst = 32'h00519123; // sh x5, 2(x3)
        store_insn.pc = 32'h128;
        store_insn.next_pc = 32'h12c;
        store_insn.pc_plus4 = 32'h12c;
        store_insn.rs1_raddr = 3;
        store_insn.rs2_raddr = 5;
        store_insn.rs1_rdata = 32'h2000;
        store_insn.rs2_rdata = 32'haabbccdd;
        store_insn.alu_result = 32'h2002;
        store_insn.mem_wen = 1;

        step(bubble, bubble, 0, "reset");
        @(negedge clk);
        rst = 0;
        e = add_insn;
        step(add_insn, bubble, 0, "first instruction enters Memory only");
        @(negedge clk);
        e = load_insn;
        #2;
        check_stages(add_insn, bubble, 0, "inputs cannot change stored outputs");
        step(load_insn, add_insn, 30, "ALU result stays with x5 while load enters Memory");
        @(negedge clk);
        e = jump_insn;
        load_data = 32'hffffff80; // Memory has extracted and sign-extended the byte.
        step(jump_insn, load_insn, 32'hffffff80, "processed load result stays with x6");
        @(negedge clk);
        e = store_insn;
        load_data = 32'hdeadbeef;
        step(store_insn, jump_insn, 32'h10c, "JAL writes PC+4, not target or ALU result");

        @(negedge clk);
        xm_stall = 1;
        mw_stall = 1;
        e = ~store_insn;
        load_data = 32'h12345678;
        repeat (2)
            step(store_insn, jump_insn, 32'h10c, "stall retains each stage's own instruction");
        @(negedge clk);
        xm_flush = 1;
        mw_flush = 1;
        #2;
        check_stages(store_insn, jump_insn, 32'h10c, "flush is synchronous");
        step(bubble, bubble, 0, "flush overrides stall and clears store/write enables");

        @(negedge clk);
        xm_flush = 0;
        mw_flush = 0;
        xm_stall = 0;
        mw_stall = 0;
        e = add_insn;
        step(add_insn, bubble, 0, "resume after flush");
        @(negedge clk);
        xm_flush = 1;
        step(bubble, add_insn, 30, "XM-only flush preserves older instruction entering MW");
        @(negedge clk);
        xm_flush = 0;
        mw_flush = 1;
        e = load_insn;
        step(load_insn, bubble, 0, "MW-only flush does not clear XM");

        @(negedge clk);
        mw_flush = 0;
        mw_stall = 1;
        e = jump_insn;
        step(jump_insn, bubble, 0, "MW can hold while XM changes");
        @(negedge clk);
        mw_stall = 0;
        xm_stall = 1;
        step(jump_insn, jump_insn, 32'h10c, "XM can hold while MW captures");

        @(negedge clk);
        xm_stall = 0;
        flags_insn = add_insn;
        flags_insn.inst = 32'h00100073;
        flags_insn.trap = 1;
        flags_insn.halt = 1;
        e = flags_insn;
        step(flags_insn, jump_insn, 32'h10c, "capture trap and halt metadata");
        @(negedge clk);
        e = bubble;
        step(bubble, flags_insn, 30, "trap and halt remain attached at retirement");

        @(negedge clk);
        reserved = add_insn;
        reserved.wb_sel = 3;
        reserved.reg_wen = 0;
        e = reserved;
        step(reserved, bubble, 0, "capture unused mux encoding");
        @(negedge clk);
        e = nop_insn;
        step(e, reserved, 0, "unused mux encoding selects zero");
        @(negedge clk);
        e = add_insn;
        step(add_insn, nop_insn, 0, "real NOP keeps valid set in Writeback");

        @(negedge clk);
        rst = 1;
        xm_stall = 1;
        mw_stall = 1;
        #2;
        // The held Writeback slot is a real NOP until the reset edge.
        if (!m.valid || !w.valid)
            $fatal(1, "reset acted before the rising clock edge");
        step(bubble, bubble, 0, "reset overrides stall synchronously");

        $display("PASS: XM/MW instruction flow, writeback selection, stalls, flushes, reset, and validity");
        $finish;
    end

    initial begin
        #1000;
        $fatal(1, "test timed out");
    end
endmodule

`default_nettype wire
