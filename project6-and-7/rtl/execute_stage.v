`default_nettype none

// ALU results, branch targets, and alignment checks.
module execute_stage (
    // Instruction and operands from DX.
    input wire i_valid,
    input wire [31:0] i_inst,
    input wire [31:0] i_pc,
    input wire [31:0] i_rs1_rdata,
    input wire [31:0] i_rs2_rdata,
    input wire [31:0] i_imm_value,

    // Controls from DX.
    input wire [2:0] i_alu_opsel,
    input wire i_alu_sub,
    input wire i_alu_unsigned,
    input wire i_alu_arith,
    input wire [1:0] i_op1_sel,
    input wire [1:0] i_op2_sel,
    input wire i_is_branch,
    input wire i_is_jal,
    input wire i_is_jalr,
    input wire i_illegal_inst,

    // Check memory alignment before issuing the access.
    input wire i_mem_ren,
    input wire i_mem_wen,

    // Results for XM and control signals for Fetch.
    output wire [31:0] o_alu_result,
    output wire [31:0] o_pc_plus4,
    output reg [31:0] o_next_pc,
    output wire o_trap,
    output wire o_halt,
    output wire o_stop,
    output wire o_redirect
);
    // Operand selections from decoder.v.
    localparam [1:0] OP1_REGISTER = 2'b00;
    localparam [1:0] OP1_PC = 2'b01;
    localparam [1:0] OP1_ZERO = 2'b10;
    localparam [1:0] OP2_REGISTER = 2'b00;
    localparam [1:0] OP2_IMMEDIATE = 2'b01;
    localparam [1:0] OP2_FOUR = 2'b10;

    localparam [2:0] BRANCH_EQ = 3'b000;
    localparam [2:0] BRANCH_NE = 3'b001;
    localparam [2:0] BRANCH_LT = 3'b100;
    localparam [2:0] BRANCH_GE = 3'b101;
    localparam [2:0] BRANCH_LTU = 3'b110;
    localparam [2:0] BRANCH_GEU = 3'b111;

    localparam [2:0] ACCESS_HALFWORD = 3'b001;
    localparam [2:0] ACCESS_WORD = 3'b010;
    localparam [2:0] ACCESS_HALFWORD_UNSIGNED = 3'b101;
    localparam [31:0] EBREAK_INST = 32'h00100073;

    wire [2:0] funct3;

    // ALU inputs and comparison results.
    reg [31:0] alu_op1;
    reg [31:0] alu_op2;
    wire alu_eq;
    wire alu_slt;

    // Branch condition and jump targets.
    reg branch_condition_met;
    wire branch_taken;
    wire branch_or_jump_taken;
    wire [31:0] pc_relative_target;
    wire [31:0] jalr_target;

    // Alignment faults.
    reg data_address_misaligned;
    wire memory_fault;
    wire pc_misaligned;
    wire target_misaligned;

    assign funct3 = i_inst[14:12];

    // ALU.
    // LUI uses zero; AUIPC uses this instruction's PC.
    always @(*) begin
        case (i_op1_sel)
            OP1_REGISTER: alu_op1 = i_rs1_rdata;
            OP1_PC:       alu_op1 = i_pc;
            OP1_ZERO:     alu_op1 = 32'b0;
            default:      alu_op1 = 32'b0;
        endcase
    end

    always @(*) begin
        case (i_op2_sel)
            OP2_REGISTER:  alu_op2 = i_rs2_rdata;
            OP2_IMMEDIATE: alu_op2 = i_imm_value;
            OP2_FOUR:      alu_op2 = 32'd4;
            default:       alu_op2 = 32'd4;
        endcase
    end

    alu alu_unit (
        .i_opsel(i_alu_opsel),
        .i_sub(i_alu_sub),
        .i_unsigned(i_alu_unsigned),
        .i_arith(i_alu_arith),
        .i_op1(alu_op1),
        .i_op2(alu_op2),
        .o_result(o_alu_result),
        .o_eq(alu_eq),
        .o_slt(alu_slt)
    );

    // Branch condition.
    // Decode already selected signed or unsigned comparison in the ALU.
    // Therefore LT/LTU share alu_slt, and GE/GEU share its inverse.
    always @(*) begin
        case (funct3)
            BRANCH_EQ:  branch_condition_met =  alu_eq;
            BRANCH_NE:  branch_condition_met = !alu_eq;
            BRANCH_LT,
            BRANCH_LTU: branch_condition_met =  alu_slt;
            BRANCH_GE,
            BRANCH_GEU: branch_condition_met = !alu_slt;
            default:    branch_condition_met = 1'b0;
        endcase
    end
    assign branch_taken = i_is_branch && branch_condition_met;

    // Next PC.
    assign o_pc_plus4 = i_pc + 32'd4;
    assign pc_relative_target = i_pc + i_imm_value;
    assign jalr_target = {o_alu_result[31:1], 1'b0}; // JALR clears bit 0.
    assign branch_or_jump_taken = branch_taken || i_is_jal || i_is_jalr;

    // Use the first control that is high. Otherwise continue at PC + 4.
    always @(*) begin
        case (1'b1)
            i_is_jalr:    o_next_pc = jalr_target;
            i_is_jal:     o_next_pc = pc_relative_target;
            branch_taken: o_next_pc = pc_relative_target;
            default:      o_next_pc = o_pc_plus4;
        endcase
    end

    // Address alignment.
    // Bytes may use any address. Halfwords require bit 0 clear, while
    // words require both low bits clear. Only loads/stores use this check.
    always @(*) begin
        case (funct3)
            ACCESS_HALFWORD,
            ACCESS_HALFWORD_UNSIGNED: data_address_misaligned = o_alu_result[0];
            ACCESS_WORD:              data_address_misaligned = (o_alu_result[1:0] != 2'b00);
            default:                  data_address_misaligned = 1'b0;
        endcase
    end
    assign memory_fault = (i_mem_ren || i_mem_wen) && data_address_misaligned;
    assign pc_misaligned = (i_pc[1:0] != 2'b00);

    // Only check the target if the branch or jump is taken.
    assign target_misaligned = branch_or_jump_taken && (o_next_pc[1:0] != 2'b00);
    assign o_trap = i_illegal_inst || memory_fault || pc_misaligned || target_misaligned;
    assign o_halt = (i_inst == EBREAK_INST);

    // Stop and redirect.
    // Bubbles must never stop or redirect the front end.
    assign o_stop = i_valid && (o_trap || o_halt);
    assign o_redirect = i_valid && branch_or_jump_taken && !o_trap && !o_halt;
endmodule

`default_nettype wire
