module xm_register (
    input wire clk,
    input wire rst_n,
    input wire [31:0] i_alu_result,
    input wire [31:0] mem_data_in,
    input wire [31:0] pc_p4_in, // jalr store in dr {pass to next stage}
    
    output reg [31:0] o_alu_out

);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            data_out <= 32'b0;
        end else begin
            data_out <= data_in;
        end
    end

endmodule