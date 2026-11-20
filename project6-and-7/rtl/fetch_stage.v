`default_nettype none

module fetch_stage #(
    parameter RESET_ADDR = 32'h00000000
) (
    input wire i_clk,
    input wire i_rst,
    input wire i_stall,
    input wire i_stop,
    input wire i_redirect,
    input wire [31:0] i_redirect_pc,
    input wire i_imem_ready,
    input wire i_imem_valid,
    input wire [31:0] i_imem_rdata,
    output wire [31:0] o_imem_raddr,
    output wire o_imem_ren,
    output wire o_valid,
    output wire [31:0] o_pc,
    output wire [31:0] o_inst
);
    wire [31:0] request_pc, next_request_pc;
    wire response;
    reg pending, discard_response, buffered;
    reg [31:0] pending_pc, buffered_pc, buffered_inst;

    assign o_imem_raddr = request_pc;
    assign o_imem_ren = !i_rst && !i_stop && !i_redirect &&
                       !pending && !buffered && i_imem_ready;
    assign response = i_imem_valid && (pending || o_imem_ren);
    assign next_request_pc = (i_redirect && !i_stop) ? i_redirect_pc :
                             o_imem_ren ? request_pc + 32'd4 : request_pc;
    assign o_valid = !i_rst && !i_stop && !i_redirect &&
                     (buffered || (response && !discard_response));
    assign o_pc = buffered ? buffered_pc : pending ? pending_pc : request_pc;
    assign o_inst = buffered ? buffered_inst : i_imem_rdata;

    PC_reg #(.RESET_ADDR(RESET_ADDR)) pc_reg (
        .i_clk(i_clk),
        .i_rst(i_rst),
        .i_next_pc(next_request_pc),
        .o_pc(request_pc)
    );

    always @(posedge i_clk) begin
        if (i_rst) begin
            pending <= 1'b0;
            discard_response <= 1'b0;
            buffered <= 1'b0;
            pending_pc <= RESET_ADDR;
            buffered_pc <= RESET_ADDR;
            buffered_inst <= 32'h00000013;
        end else begin
            if (o_imem_ren) begin
                pending <= 1'b1;
                pending_pc <= request_pc;
            end
            if (response) begin
                pending <= 1'b0;
                discard_response <= 1'b0;
            end
            if (i_stop || i_redirect) begin
                buffered <= 1'b0;
                discard_response <= pending && !response;
            end else begin
                if (buffered && !i_stall)
                    buffered <= 1'b0;
                if (response && !discard_response && i_stall) begin
                    buffered <= 1'b1;
                    buffered_pc <= pending ? pending_pc : request_pc;
                    buffered_inst <= i_imem_rdata;
                end
            end
        end
    end
endmodule

`default_nettype wire
