`default_nettype wire

module hart #(
    // After reset, the program counter (PC) should be initialized to this
    // address and start executing instructions from there.
    parameter RESET_ADDR = 32'h00000000
) (
    // Global clock.
    input  wire        i_clk,
    // Synchronous active-high reset.
    input  wire        i_rst,
    // Instruction fetch goes through a read only instruction memory (imem)
    // port. The port accepts a 32-bit address (e.g. from the program counter)
    // per cycle and combinationally returns a 32-bit instruction word. This
    // is not representative of a realistic memory interface; it has been
    // modeled as more similar to a DFF or SRAM to simplify phase 3. In
    // later phases, you will replace this with a more realistic memory.
    //
    // 32-bit read address for the instruction memory. This is expected to be
    // 4 byte aligned - that is, the two LSBs should be zero.
    output wire [31:0] o_imem_raddr,
    // Instruction word fetched from memory, available on the same cycle.
    input  wire [31:0] i_imem_rdata,
    // Data memory accesses go through a separate read/write data memory (dmem)
    // that is shared between read (load) and write (stored). The port accepts
    // a 32-bit address, read or write enable, and mask (explained below) each
    // cycle. Reads are combinational - values are available immediately after
    // updating the address and asserting read enable. Writes occur on (and
    // are visible at) the next clock edge.
    //
    // Read/write address for the data memory. This should be 32-bit aligned
    // (i.e. the two LSB should be zero). See `o_dmem_mask` for how to perform
    // half-word and byte accesses at unaligned addresses.
    output wire [31:0] o_dmem_addr,
    // When asserted, the memory will perform a read at the aligned address
    // specified by `i_addr` and return the 32-bit word at that address
    // immediately (i.e. combinationally). It is illegal to assert this and
    // `o_dmem_wen` on the same cycle.
    output wire        o_dmem_ren,
    // When asserted, the memory will perform a write to the aligned address
    // `o_dmem_addr`. When asserted, the memory will write the bytes in
    // `o_dmem_wdata` (specified by the mask) to memory at the specified
    // address on the next rising clock edge. It is illegal to assert this and
    // `o_dmem_ren` on the same cycle.
    output wire        o_dmem_wen,
    // The 32-bit word to write to memory when `o_dmem_wen` is asserted. When
    // write enable is asserted, the byte lanes specified by the mask will be
    // written to the memory word at the aligned address at the next rising
    // clock edge. The other byte lanes of the word will be unaffected.
    output wire [31:0] o_dmem_wdata,
    // The dmem interface expects word (32 bit) aligned addresses. However,
    // the processor supports byte and half-word loads and stores at unaligned and
    // 16-bit aligned addresses, respectively. To support this, the access
    // mask specifies which bytes within the 32-bit word are actually read
    // from or written to memory.
    //
    // To perform a half-word read at address 0x00001002, align `o_dmem_addr`
    // to 0x00001000, assert `o_dmem_ren`, and set the mask to 0b1100 to
    // indicate that only the upper two bytes should be read. Only the upper
    // two bytes of `i_dmem_rdata` can be assumed to have valid data; to
    // calculate the final value of the `lh[u]` instruction, shift the rdata
    // word right by 16 bits and sign/zero extend as appropriate.
    //
    // To perform a byte write at address 0x00002003, align `o_dmem_addr` to
    // `0x00002000`, assert `o_dmem_wen`, and set the mask to 0b1000 to
    // indicate that only the upper byte should be written. On the next clock
    // cycle, the upper byte of `o_dmem_wdata` will be written to memory, with
    // the other three bytes of the aligned word unaffected. Remember to shift
    // the value of the `sb` instruction left by 24 bits to place it in the
    // appropriate byte lane.
    output wire [ 3:0] o_dmem_mask,
    // The 32-bit word read from data memory. When `o_dmem_ren` is asserted,
    // this will immediately reflect the contents of memory at the specified
    // address, for the bytes enabled by the mask. When read enable is not
    // asserted, or for bytes not set in the mask, the value is undefined.
    input  wire [31:0] i_dmem_rdata,
	// The output `retire` interface is used to signal to the testbench that
    // the CPU has completed and retired an instruction. A single cycle
    // implementation will assert this every cycle; however, a pipelined
    // implementation that needs to stall (due to internal hazards or waiting
    // on memory accesses) will not assert the signal on cycles where the
    // instruction in the writeback stage is not retiring.
    //
    // Asserted when an instruction is being retired this cycle. If this is
    // not asserted, the other retire signals are ignored and may be left invalid.
    output wire        o_retire_valid,
    // The 32 bit instruction word of the instrution being retired. This
    // should be the unmodified instruction word fetched from instruction
    // memory.
    output wire [31:0] o_retire_inst,
    // Asserted if the instruction produced a trap, due to an illegal
    // instruction, unaligned data memory access, or unaligned instruction
    // address on a taken branch or jump.
    output wire        o_retire_trap,
    // Asserted if the instruction is an `ebreak` instruction used to halt the
    // processor. This is used for debugging and testing purposes to end
    // a program.
    output wire        o_retire_halt,
    // The first register address read by the instruction being retired. If
    // the instruction does not read from a register (like `lui`), this is
    // don't-care -- the grading testbench doesn't look at it in that case.
    output wire [ 4:0] o_retire_rs1_raddr,
    // The second register address read by the instruction being retired. If
    // the instruction does not read from a second register (like `addi`),
    // this is don't-care -- the grading testbench doesn't look at it in that
    // case.
    output wire [ 4:0] o_retire_rs2_raddr,
    // The first source register data read from the register file (in the
    // decode stage) for the instruction being retired. If rs1 is 5'd0, this
    // should also be 32'd0.
    output wire [31:0] o_retire_rs1_rdata,
    // The second source register data read from the register file (in the
    // decode stage) for the instruction being retired. If rs2 is 5'd0, this
    // should also be 32'd0.
    output wire [31:0] o_retire_rs2_rdata,
    // The destination register address written by the instruction being
    // retired. If the instruction does not write to a register (like `sw`),
    // this should be 5'd0.
    output wire [ 4:0] o_retire_rd_waddr,
    // The destination register data written to the register file in the
    // writeback stage by this instruction. If rd is 5'd0, this field is
    // ignored and can be treated as a don't care.
    output wire [31:0] o_retire_rd_wdata,
    // The current program counter of the instruction being retired - i.e.
    // the instruction memory address that the instruction was fetched from.
    output wire [31:0] o_retire_pc,
    // the next program counter after the instruction is retired. For most
    // instructions, this is `o_retire_pc + 4`, but must be the branch or jump
    // target for *taken* branches and jumps.
    output wire [31:0] o_retire_next_pc

`ifdef RISCV_FORMAL
    ,`RVFI_OUTPUTS,
`endif
);


    // ============================================================
    // Internal signals
    // ============================================================
    wire [31:0] pc;
    wire [31:0] pc_next;
    wire [31:0] pc_plus4;
    wire [31:0] pc_imm_target;
    wire [31:0] inst;
    wire [31:0] imm_value;
    wire [4:0]  rs1_raddr;
    wire [4:0]  rs2_raddr;
    wire [4:0]  rd_waddr;
    wire [31:0] rs1_rdata;
    wire [31:0] rs2_rdata;
    wire [31:0] rd_wdata;
    wire [31:0] alu_op1;
    wire [31:0] alu_op2;
    wire [31:0] alu_result;
    wire        alu_eq;
    wire        alu_slt;

    // ============================================================
    // Deoder and control signals
    // ============================================================

    wire [1:0] op1_sel;
    wire [1:0] op2_sel;
    wire [1:0] wb_sel;
    wire [1:0] pc_sel;
    wire [2:0] alu_opsel;
    wire       alu_sub;
    wire       alu_unsigned;
    wire       alu_arith;
    wire [5:0] imm_format;
    wire       reg_wen;
    wire       mem_ren;
    wire       mem_wen;
    wire       is_branch;
    wire       is_jal;
    wire       is_jalr;


    // ============================================================
    // Instruction
    // ============================================================
    assign inst = i_imem_rdata;
    assign rs1_raddr = inst[19:15];
    assign rs2_raddr = inst[24:20];
    assign rd_waddr  = inst[11:7];

    // ============================================================
    // PC register
    // ============================================================

    PC_reg #(
        .RESET_ADDR(RESET_ADDR)
    ) pc_reg (
        .i_clk     (i_clk),
        .i_rst     (i_rst),
        .i_next_pc (pc_next),
        .o_pc      (pc)
    );

    // PC directly addresses instruction memory.
    assign o_imem_raddr = pc;

    // ============================================================
    // PC + 4
    // ============================================================

    adder_32b pc_adder (
        .i_a   (pc),
        .i_b   (32'd4),
        .o_sum (pc_plus4)
    );

    // ============================================================
    // Immediate generator
    // ============================================================

    imm imm_gen (
        .i_inst      (inst),
        .i_format    (imm_format),
        .o_immediate (imm_value)
    );

    // ============================================================
    // PC + immediate
    //
    // Used by:
    //   B-type taken branches
    //   JAL
    // ============================================================

    adder_32b pc_branch_adder (
        .i_a   (pc),
        .i_b   (imm_value),
        .o_sum (pc_imm_target)
    );

    // ============================================================
    // Register file
    // ============================================================

    rf register_file (
        .i_clk       (i_clk),
        .i_rst       (i_rst),

        .i_rs1_raddr (rs1_raddr),
        .i_rs2_raddr (rs2_raddr),

        .o_rs1_rdata (rs1_rdata),
        .o_rs2_rdata (rs2_rdata),

        .i_rd_wen    (reg_wen),
        .i_rd_waddr  (rd_waddr),
        .i_rd_wdata  (rd_wdata)
    );

    // ============================================================
    // ALU operand 1 mux
    //
    // 00 = rs1
    // 01 = PC
    // 10 = 0
    //
    // R/I/S/B/JALR : rs1
    // AUIPC        : PC
    // LUI          : 0
    // ============================================================

    assign alu_op1 =
        (op1_sel == 2'b00) ? rs1_rdata :
        (op1_sel == 2'b01) ? pc :
        (op1_sel == 2'b10) ? 32'b0 :
                             32'bx; //don't care

    // ============================================================
    // ALU operand 2 mux
    //
    // 0 = rs2
    // 1 = immediate
    // 2 = 4 (for PC+4)
    // ============================================================

    assign alu_op2 =
        (op2_sel == 2'b00) ? rs2_rdata :
        (op2_sel == 2'b01) ? imm_value :
        (op2_sel == 2'b10) ? 32'd4 :
                             32'bx; //don't care

    // ============================================================
    // ALU
    // ============================================================

    alu alu_unit (
        .i_opsel    (alu_opsel),
        .i_sub      (alu_sub),
        .i_unsigned (alu_unsigned),
        .i_arith    (alu_arith),

        .i_op1      (alu_op1),
        .i_op2      (alu_op2),

        .o_result   (alu_result),
        .o_eq       (alu_eq),
        .o_slt      (alu_slt)
    );

    // ============================================================
    // Branch decision
    // ============================================================

    wire branch_taken;

    wire [2:0] funct3;
    assign funct3 = inst[14:12];

    assign branch_taken =
        !is_branch ? 1'b0 :

        (funct3 == 3'b000) ?  alu_eq  : // BEQ
        (funct3 == 3'b001) ? !alu_eq  : // BNE
        (funct3 == 3'b100) ?  alu_slt : // BLT
        (funct3 == 3'b101) ? !alu_slt : // BGE
        (funct3 == 3'b110) ?  alu_slt : // BLTU
        (funct3 == 3'b111) ? !alu_slt : // BGEU
                              1'b0;

    // ============================================================
    // Next PC
    //
    // Your schematic:
    //
    // PC+4 -------------------------\
    // PC+IMM ------------------------> PC mux -> PC
    // JALR {ALU[31:1],1'b0} -------/
    // ============================================================

    wire [31:0] jalr_target;

    assign jalr_target = {
        alu_result[31:1],
        1'b0
    };

    assign pc_next =
        is_jalr ? jalr_target :
        is_jal  ? pc_imm_target :
        (is_branch && branch_taken)
            ? pc_imm_target
            : pc_plus4;

    // ============================================================
    // DATA MEMORY ADDRESS
    //
    // ALU computes the effective byte address.
    //
    // External dmem expects aligned 32-bit addresses.
    // ============================================================

    wire [1:0] byte_offset;

    assign byte_offset = alu_result[1:0];

    assign o_dmem_addr = {
        alu_result[31:2],
        2'b00
    };

    // ============================================================
    // Memory instruction decoding
    // ============================================================

    wire [6:0] opcode;

    assign opcode = inst[6:0];

    wire is_load;
    wire is_store;

    assign is_load  = (opcode == 7'b0000011);
    assign is_store = (opcode == 7'b0100011);

    assign o_dmem_ren = is_load;
    assign o_dmem_wen = is_store;

    // ============================================================
    // DATA MEMORY MASK
    //
    // LB/LBU/SB  -> one byte
    // LH/LHU/SH  -> two bytes
    // LW/SW      -> four bytes
    // ============================================================

    wire [3:0] byte_mask;
    wire [3:0] half_mask;

    assign byte_mask =
        (byte_offset == 2'b00) ? 4'b0001 :
        (byte_offset == 2'b01) ? 4'b0010 :
        (byte_offset == 2'b10) ? 4'b0100 :
                                4'b1000;

    assign half_mask =
        (byte_offset == 2'b00) ? 4'b0011 :
        (byte_offset == 2'b10) ? 4'b1100 :
                                4'b0000;

    assign o_dmem_mask =
        (funct3 == 3'b000) ? byte_mask :
        (funct3 == 3'b001) ? half_mask :
        (funct3 == 3'b010) ? 4'b1111 :
        (funct3 == 3'b100) ? byte_mask :
        (funct3 == 3'b101) ? half_mask :
                             4'b0000;

    // ============================================================
    // STORE DATA ALIGNMENT
    //
    // SB / SH must move the data into the selected byte lanes.
    //
    // Constant shifts only.
    // ============================================================

    wire [31:0] store_byte_data;
    wire [31:0] store_half_data;

    assign store_byte_data =
        (byte_offset == 2'b00)
            ? {24'b0, rs2_rdata[7:0]} :
        (byte_offset == 2'b01)
            ? {16'b0, rs2_rdata[7:0], 8'b0} :
        (byte_offset == 2'b10)
            ? {8'b0, rs2_rdata[7:0], 16'b0} :
              {rs2_rdata[7:0], 24'b0};

    assign store_half_data =
        (byte_offset == 2'b00)
            ? {16'b0, rs2_rdata[15:0]} :
        (byte_offset == 2'b10)
            ? {rs2_rdata[15:0], 16'b0} :
              32'b0;

    assign o_dmem_wdata =
        (funct3 == 3'b000) ? store_byte_data :
        (funct3 == 3'b001) ? store_half_data :
        (funct3 == 3'b010) ? rs2_rdata :
                             32'b0;

    // ============================================================
    // LOAD DATA ALIGNMENT
    // ============================================================

    wire [7:0] load_byte;
    wire [15:0] load_half;

    assign load_byte =
        (byte_offset == 2'b00) ? i_dmem_rdata[7:0]   :
        (byte_offset == 2'b01) ? i_dmem_rdata[15:8]  :
        (byte_offset == 2'b10) ? i_dmem_rdata[23:16] :
                                 i_dmem_rdata[31:24];

    assign load_half =
        (byte_offset == 2'b00)
            ? i_dmem_rdata[15:0]
            : i_dmem_rdata[31:16];

    wire [31:0] load_data;

    assign load_data =
        // LB
        (funct3 == 3'b000)
            ? {{24{load_byte[7]}}, load_byte} :

        // LH
        (funct3 == 3'b001)
            ? {{16{load_half[15]}}, load_half} :

        // LW
        (funct3 == 3'b010)
            ? i_dmem_rdata :

        // LBU
        (funct3 == 3'b100)
            ? {24'b0, load_byte} :

        // LHU
        (funct3 == 3'b101)
            ? {16'b0, load_half} :

              32'b0;

    // ============================================================
    // Writeback MUX
    //
    // 00 = ALU
    // 01 = memory
    // 10 = PC+4
    //
    // R/I/LUI/AUIPC -> ALU
    // loads          -> memory
    // JAL/JALR       -> PC+4
    // ============================================================

    assign rd_wdata =
        (wb_sel == 2'b00) ? alu_result :
        (wb_sel == 2'b01) ? load_data :
        (wb_sel == 2'b10) ? pc_plus4 :
                            32'b0;

    // ============================================================
    // Decoder
    // ============================================================

    decoder decoder_unit (
        .i_inst        (inst),

        .o_opsel       (alu_opsel),
        .o_sub         (alu_sub),
        .o_unsigned    (alu_unsigned),
        .o_arith       (alu_arith),

        .o_op1_sel     (op1_sel),
        .o_op2_sel     (op2_sel),

        .o_wb_sel      (wb_sel),

        .o_i_format    (imm_format),  // one hot encoding of the immediate format

        .o_reg_wen     (reg_wen),

        .o_is_branch   (is_branch),
        .o_is_jal      (is_jal),
        .o_is_jalr     (is_jalr)
    );

    // ============================================================
    // Retire interface
    // ============================================================

    assign o_retire_valid     = 1'b1;

    assign o_retire_inst      = inst;

    assign o_retire_rs1_raddr = rs1_raddr;
    assign o_retire_rs2_raddr = rs2_raddr;

    assign o_retire_rs1_rdata = rs1_rdata;
    assign o_retire_rs2_rdata = rs2_rdata;

    assign o_retire_rd_waddr =
        reg_wen ? rd_waddr : 5'b0;

    assign o_retire_rd_wdata = rd_wdata;

    assign o_retire_pc       = pc;
    assign o_retire_next_pc  = pc_next;

    // ============================================================
    // Halt / trap
    // ============================================================

    // EBREAK:
    // 000000000001 00000 000 00000 1110011
    assign o_retire_halt =
        (inst == 32'h00100073);

    // ------------------------------------------------------------
    // Alignment checks
    // ------------------------------------------------------------

    wire load_misaligned;
    wire store_misaligned;
    wire inst_misaligned;

    assign load_misaligned =
        is_load &&
        (
            ((funct3 == 3'b001) ||
             (funct3 == 3'b101))
                ? byte_offset[0] :

            (funct3 == 3'b010)
                ? (byte_offset != 2'b00) :

              1'b0
        );

    assign store_misaligned =
        is_store &&
        (
            (funct3 == 3'b001)
                ? byte_offset[0] :

            (funct3 == 3'b010)
                ? (byte_offset != 2'b00) :

              1'b0
        );

    assign inst_misaligned =
        (pc_next[1:0] != 2'b00);

    /*
     * This currently covers alignment traps.
     *
     * Add decoder illegal-instruction output here once your decoder
     * implements illegal instruction detection:
     *
     *     illegal_inst |
     *
     */
    assign o_retire_trap =
        load_misaligned  |
        store_misaligned |
        inst_misaligned;

endmodule

`default_nettype wire

