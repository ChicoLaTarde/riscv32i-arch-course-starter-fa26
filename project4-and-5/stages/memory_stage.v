`default_nettype none

// Align load/store data and extend load results.
module memory_stage (
    // Instruction and controls from XM.
    input wire i_rst,
    input wire i_valid,
    input wire [31:0] i_inst,
    input wire [31:0] i_alu_result,
    input wire [31:0] i_rs2_rdata,
    input wire i_mem_ren,
    input wire i_mem_wen,
    input wire i_trap,
    input wire i_halt,

    // Data memory interface.
    input wire [31:0] i_dmem_rdata,
    output wire [31:0] o_dmem_addr,
    output wire o_dmem_ren,
    output wire o_dmem_wen,
    output wire [31:0] o_dmem_wdata,
    output reg [3:0] o_dmem_mask,

    // Load result for MW.
    output reg [31:0] o_load_data
);
    // Access sizes from funct3.
    localparam [2:0] ACCESS_BYTE = 3'b000;
    localparam [2:0] ACCESS_HALFWORD = 3'b001;
    localparam [2:0] ACCESS_WORD = 3'b010;
    localparam [2:0] ACCESS_BYTE_UNSIGNED = 3'b100;
    localparam [2:0] ACCESS_HALFWORD_UNSIGNED = 3'b101;

    wire [1:0] byte_offset;
    wire [2:0] funct3;
    wire access_allowed;
    reg [3:0] byte_mask, half_mask;
    reg [31:0] shifted_store_data;
    reg [7:0] load_byte;
    wire [15:0] load_halfword;
    wire [31:0] signed_byte, signed_halfword;

    // Save the offset and align the memory address to a word.
    assign byte_offset = i_alu_result[1:0];
    assign funct3 = i_inst[14:12];
    assign o_dmem_addr = {i_alu_result[31:2], 2'b00};

    // Only valid instructions without a trap can access memory.
    assign access_allowed = i_valid && !i_trap && !i_halt && !i_rst;
    assign o_dmem_ren = access_allowed && i_mem_ren;
    assign o_dmem_wen = access_allowed && i_mem_wen;

    // Select byte lanes. Offset 3 uses mask 1000; an upper halfword uses 1100.
    always @(*) begin
        case (byte_offset)
            2'b00:   byte_mask = 4'b0001;
            2'b01:   byte_mask = 4'b0010;
            2'b10:   byte_mask = 4'b0100;
            2'b11:   byte_mask = 4'b1000;
            default: byte_mask = 4'b0000;
        endcase
    end

    always @(*) begin
        case (byte_offset)
            2'b00:   half_mask = 4'b0011;
            2'b10:   half_mask = 4'b1100;
            default: half_mask = 4'b0000;
        endcase
    end

    always @(*) begin
        case (funct3)
            ACCESS_BYTE,
            ACCESS_BYTE_UNSIGNED:     o_dmem_mask = byte_mask;
            ACCESS_HALFWORD,
            ACCESS_HALFWORD_UNSIGNED: o_dmem_mask = half_mask;
            ACCESS_WORD:              o_dmem_mask = 4'b1111;
            default:                  o_dmem_mask = 4'b0000;
        endcase
    end

    // Shift store data into the selected lanes. Memory ignores the other lanes.
    always @(*) begin
        case (byte_offset)
            2'b00:   shifted_store_data = i_rs2_rdata;
            2'b01:   shifted_store_data = i_rs2_rdata << 8;
            2'b10:   shifted_store_data = i_rs2_rdata << 16;
            2'b11:   shifted_store_data = i_rs2_rdata << 24;
            default: shifted_store_data = 32'b0;
        endcase
    end
    assign o_dmem_wdata = (funct3 == ACCESS_WORD) ? i_rs2_rdata : shifted_store_data;

    // Pick the requested byte or halfword.
    always @(*) begin
        case (byte_offset)
            2'b00:   load_byte = i_dmem_rdata[7:0];
            2'b01:   load_byte = i_dmem_rdata[15:8];
            2'b10:   load_byte = i_dmem_rdata[23:16];
            2'b11:   load_byte = i_dmem_rdata[31:24];
            default: load_byte = 8'b0;
        endcase
    end
    assign load_halfword =
        (byte_offset == 2'b00) ? i_dmem_rdata[15:0] : i_dmem_rdata[31:16];

    // Sign extend LB/LH. Zero extend LBU/LHU.
    assign signed_byte = {{24{load_byte[7]}}, load_byte};
    assign signed_halfword = {{16{load_halfword[15]}}, load_halfword};
    always @(*) begin
        case (funct3)
            ACCESS_BYTE:              o_load_data = signed_byte;           // LB
            ACCESS_HALFWORD:          o_load_data = signed_halfword;       // LH
            ACCESS_WORD:              o_load_data = i_dmem_rdata;          // LW
            ACCESS_BYTE_UNSIGNED:     o_load_data = {24'b0, load_byte};     // LBU
            ACCESS_HALFWORD_UNSIGNED: o_load_data = {16'b0, load_halfword}; // LHU
            default:                  o_load_data = 32'b0;
        endcase
    end
endmodule

`default_nettype wire
