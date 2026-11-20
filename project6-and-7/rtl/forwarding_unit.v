`default_nettype none

// Selects where Execute gets its rs1 and rs2 values from.
module forwarding_unit (
    input wire [4:0] i_x_rs1_raddr,
    input wire [4:0] i_x_rs2_raddr,

    input wire       i_m_writes_rd,
    input wire [4:0] i_m_rd_waddr,

    input wire       i_w_writes_rd,
    input wire [4:0] i_w_rd_waddr,

    output wire [1:0] o_rs1_source,
    output wire [1:0] o_rs2_source
);
    localparam [1:0] FROM_REGFILE   = 2'b00;
    localparam [1:0] FROM_WRITEBACK = 2'b01;
    localparam [1:0] FROM_MEMORY    = 2'b10;

    // Memory holds the newer instruction, so it takes priority.
    assign o_rs1_source =
        (i_m_writes_rd && i_m_rd_waddr != 5'd0 && i_m_rd_waddr == i_x_rs1_raddr) ? FROM_MEMORY :
        (i_w_writes_rd && i_w_rd_waddr != 5'd0 && i_w_rd_waddr == i_x_rs1_raddr) ? FROM_WRITEBACK :
                                                                                   FROM_REGFILE;

    assign o_rs2_source =
        (i_m_writes_rd && i_m_rd_waddr != 5'd0 && i_m_rd_waddr == i_x_rs2_raddr) ? FROM_MEMORY :
        (i_w_writes_rd && i_w_rd_waddr != 5'd0 && i_w_rd_waddr == i_x_rs2_raddr) ? FROM_WRITEBACK :
                                                                                   FROM_REGFILE;
endmodule

`default_nettype wire
