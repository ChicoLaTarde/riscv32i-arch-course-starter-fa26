`timescale 1ns/1ps
`default_nettype none

// Expected legality comes from the mask/match table in run_pipeline_tests.py.
module decoder_tb;
    reg [31:0] inst;
    wire illegal, reg_wen, mem_ren, mem_wen;
    wire is_branch, is_jal, is_jalr, uses_rs1, uses_rs2;
    reg [32:0] vectors [0:4095];
    string vector_path;
    integer count, index;

    decoder dut (
        .i_inst(inst),
        .o_illegal(illegal),
        .o_reg_wen(reg_wen),
        .o_mem_ren(mem_ren),
        .o_mem_wen(mem_wen),
        .o_is_branch(is_branch),
        .o_is_jal(is_jal),
        .o_is_jalr(is_jalr),
        .o_uses_rs1(uses_rs1),
        .o_uses_rs2(uses_rs2)
    );

    initial begin
        if (!$value$plusargs("VECTORS=%s", vector_path) ||
            !$value$plusargs("COUNT=%d", count))
            $fatal(1, "missing decoder vectors/count");
        $readmemh(vector_path, vectors, 0, count - 1);
        for (index = 0; index < count; index = index + 1) begin
            // Start with a legal instruction that writes a register, so an
            // invalid instruction must actively clear the previous controls.
            inst = 32'h00100093; // ADDI x1, x0, 1.
            #1;
            inst = vectors[index][31:0];
            #1;
            if (illegal !== vectors[index][32])
                $fatal(1, "inst=%h illegal=%b, expected %b", inst, illegal, vectors[index][32]);
            if (illegal && {reg_wen, mem_ren, mem_wen, is_branch, is_jal,
                            is_jalr, uses_rs1, uses_rs2} !== 8'b0)
                $fatal(1, "illegal instruction %h leaves controls enabled", inst);
        end
        $display("PASS: decoder legality and disabled controls (%0d encodings)", count);
        $finish;
    end
endmodule

`default_nettype wire
