
`default_nettype none

module mw_register (


    // Inputs
    input wire i_clk,
    input wire i_rst_n,
    input reg [31:0] alu_result_in,
    input reg [31:0] mem_data_in,
    input reg [31:0] pc_p4_in, // jalr store in dr

    //control signals
    input wire [1:0]    reg_mux_sel_in,
    
    // Mux is included inside this register to select between ALU result and memory data
    output reg [31:0] data_out
);


    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            data_out <= 32'b0;
        end else begin
            case (reg_mux_sel_in)
                2'b00: data_out <= alu_result_in;
                2'b01: data_out <= mem_data_in;
                2'b10: data_out <= pc_p4_in;
                default: data_out <= 32'b0; // Default case to handle unexpected values
            endcase
        end
    end


endmodule

`default_nettype none