// Fetch to Decode pipeline register.
`default_nettype none

module fd_register (
    input wire i_clk,
    input wire i_rst,
    input wire i_flush,
    input wire i_stall,

    // Inputs from Fetch.
    input wire i_valid,
    input wire [31:0] i_inst,
    input wire [31:0] i_pc,

    // Outputs to Decode.
    output reg o_valid,
    output reg [31:0] o_pc,
    output reg [31:0] o_inst
);

    // NOP instruction.
    localparam [31:0] NOP_INST = 32'h00000013;

    // Reset/flush clears the register. Stall keeps the current values.
    always @(posedge i_clk) begin
        // Reset/flush has priority over stall.
        if (i_rst || i_flush) begin
            // Insert a bubble.
            o_valid <= 1'b0;
            o_pc    <= 32'b0;
            o_inst  <= NOP_INST;

        end else if (!i_stall) begin
            // Save the new instruction and its PC.
            o_valid <= i_valid;
            o_pc    <= i_pc;
            o_inst  <= i_inst;
        end
        // On a stall, keep the current values.
    end

endmodule

`default_nettype wire
