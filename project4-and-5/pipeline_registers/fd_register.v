// Fetch to Decode Pipeline Register, needs to check whether we are flushing information or stalling

module fd_register (
    input wire i_clk,
    input wire i_rst,
    input wire i_flush,
    input wire i_stall,

    // Instructions from Fetch Stage
    input wire [31:0] i_inst,
    input wire [31:0] i_pc,


    // Output going to Decode Stage
    output wire [31:0] o_pc,
    output wire [31:0] o_inst,
);

    always @(posedge i_clk or posedge i_rst) begin
        if (i_rst or i_flush) begin
            // Load a nop
            o_pc <= 32'b0;
            o_inst <= 32'h00000013; // nop instruction, adds 0 to x0 so it doesn't matter

        end else if (!i_stall) begin
            // If not a stall, pass on the input pc and the input instruction to Decode
            o_pc <= i_pc;
            o_inst <= i_inst;
        end
        // if it is a stall then just keep the current values by doing nothing
    end

endmodule