`timescale 1ns/1ps
`default_nettype none

// Run from the repository root:
// iverilog -g2012 -s dx_register_tb -o /tmp/dx_register_tb \
//   project4-and-5/pipeline_registers/dx_register.v project4-and-5/tb/dx_register_tb.sv
// vvp /tmp/dx_register_tb
module dx_register_tb;
    typedef struct packed {
        logic        valid;
        logic [31:0] inst, pc;
        logic [4:0]  rs1_raddr, rs2_raddr, rd_waddr;
        logic [31:0] rs1_rdata, rs2_rdata, imm_value;
        logic [2:0]  alu_opsel;
        logic        alu_sub, alu_unsigned, alu_arith;
        logic [1:0]  op1_sel, op2_sel;
        logic        is_branch, is_jal, is_jalr, illegal_inst;
        logic        mem_ren, mem_wen;
        logic [1:0]  wb_sel;
        logic        reg_wen;
    } instruction_t;

    logic clk = 0;
    logic rst = 1;
    logic flush = 0;
    logic stall = 0;
    instruction_t d, sample_a, sample_b, bubble;
    wire instruction_t q;

    always #5 clk = ~clk;

    dx_register dut (
        .i_clk(clk), .i_rst(rst), .i_flush(flush), .i_stall(stall),
        .i_valid(d.valid), .i_inst(d.inst), .i_pc(d.pc),
        .i_rs1_raddr(d.rs1_raddr), .i_rs2_raddr(d.rs2_raddr),
        .i_rd_waddr(d.rd_waddr), .i_rs1_rdata(d.rs1_rdata),
        .i_rs2_rdata(d.rs2_rdata), .i_imm_value(d.imm_value),
        .i_alu_opsel(d.alu_opsel), .i_alu_sub(d.alu_sub),
        .i_alu_unsigned(d.alu_unsigned), .i_alu_arith(d.alu_arith),
        .i_op1_sel(d.op1_sel), .i_op2_sel(d.op2_sel),
        .i_is_branch(d.is_branch), .i_is_jal(d.is_jal),
        .i_is_jalr(d.is_jalr), .i_illegal_inst(d.illegal_inst),
        .i_mem_ren(d.mem_ren), .i_mem_wen(d.mem_wen),
        .i_wb_sel(d.wb_sel), .i_reg_wen(d.reg_wen),
        .o_valid(q.valid), .o_inst(q.inst), .o_pc(q.pc),
        .o_rs1_raddr(q.rs1_raddr), .o_rs2_raddr(q.rs2_raddr),
        .o_rd_waddr(q.rd_waddr), .o_rs1_rdata(q.rs1_rdata),
        .o_rs2_rdata(q.rs2_rdata), .o_imm_value(q.imm_value),
        .o_alu_opsel(q.alu_opsel), .o_alu_sub(q.alu_sub),
        .o_alu_unsigned(q.alu_unsigned), .o_alu_arith(q.alu_arith),
        .o_op1_sel(q.op1_sel), .o_op2_sel(q.op2_sel),
        .o_is_branch(q.is_branch), .o_is_jal(q.is_jal),
        .o_is_jalr(q.is_jalr), .o_illegal_inst(q.illegal_inst),
        .o_mem_ren(q.mem_ren), .o_mem_wen(q.mem_wen),
        .o_wb_sel(q.wb_sel), .o_reg_wen(q.reg_wen)
    );

    task automatic expect_bundle(input instruction_t expected,
                                 input string scenario);
        if (q !== expected)
            $fatal(1, "%s: expected %h, got %h", scenario, expected, q);
    endtask

    task automatic expect_next_edge(input instruction_t expected,
                                    input string scenario);
        @(posedge clk);
        #1; // Observe the nonblocking assignments after the active edge.
        expect_bundle(expected, scenario);
    endtask

    initial begin
        bubble = '0;
        bubble.inst = 32'h00000013;
        d = '0;

        // Distinct payloads expose crossed wires. Enabled controls make a
        // later flush prove that all side effects and redirects are cleared.
        sample_a = '1;
        sample_a.inst = 32'h87654321;
        sample_a.pc = 32'h10203040;
        sample_a.rs1_raddr = 5'd3;
        sample_a.rs2_raddr = 5'd17;
        sample_a.rd_waddr = 5'd29;
        sample_a.rs1_rdata = 32'ha5c319e7;
        sample_a.rs2_rdata = 32'h2468ace0;
        sample_a.imm_value = 32'hfffff85c;
        sample_a.alu_opsel = 3'b101;
        sample_a.op1_sel = 2'b10;
        sample_a.op2_sel = 2'b01;
        sample_a.wb_sel = 2'b10;
        sample_b = ~sample_a;

        expect_next_edge(bubble, "initial reset");
        @(negedge clk);
        rst = 0;
        d = sample_a;
        expect_next_edge(sample_a, "capture every payload and control field");

        @(negedge clk);
        d = sample_b;
        #2;
        expect_bundle(sample_a, "input changes cannot affect output between edges");
        expect_next_edge(sample_b, "capture complementary fields, including valid=0");

        @(negedge clk);
        d = sample_a;
        expect_next_edge(sample_a, "replace the previous instruction");
        @(negedge clk);
        stall = 1;
        d = sample_b;
        repeat (3) begin
            expect_next_edge(sample_a, "stall retains the entire instruction");
            @(negedge clk);
            d = ~d;
            #1;
            expect_bundle(sample_a, "changing inputs during stall remains harmless");
        end

        flush = 1;
        #1;
        expect_bundle(sample_a, "flush takes effect only on the clock edge");
        expect_next_edge(bubble, "flush overrides stall and clears all enables");
        @(negedge clk);
        flush = 0;
        d = sample_a;
        expect_next_edge(bubble, "stall retains the flushed bubble");

        @(negedge clk);
        stall = 0;
        expect_next_edge(sample_a, "resume after flush and stall");
        @(negedge clk);
        rst = 1;
        stall = 1;
        d = sample_b;
        #2;
        expect_bundle(sample_a, "synchronous reset must wait for the clock edge");
        expect_next_edge(bubble, "reset overrides stall");

        @(negedge clk);
        rst = 0;
        stall = 0;
        d = bubble;
        d.valid = 1;
        expect_next_edge(d, "a real NOP retains valid=1");
        @(negedge clk);
        flush = 1;
        expect_next_edge(bubble, "a flushed NOP is an invalid bubble");

        $display("PASS: dx_register capture, stability, stall, flush, reset, and NOP validity");
        $finish;
    end

    initial begin
        #1000;
        $fatal(1, "test timed out");
    end
endmodule

`default_nettype wire
