`default_nettype none

module hart #(
    // After reset, the program counter (PC) should be initialized to this
    // address and start executing instructions from there.
    parameter RESET_ADDR = 32'h00000000
) (
    // Global clock.
    input wire i_clk,
    // Synchronous active-high reset.
    input wire i_rst,
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
    input wire [31:0] i_imem_rdata,
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
    output wire o_dmem_ren,
    // When asserted, the memory will perform a write to the aligned address
    // `o_dmem_addr`. When asserted, the memory will write the bytes in
    // `o_dmem_wdata` (specified by the mask) to memory at the specified
    // address on the next rising clock edge. It is illegal to assert this and
    // `o_dmem_ren` on the same cycle.
    output wire o_dmem_wen,
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
    input wire [31:0] i_dmem_rdata,
    // The output `retire` interface is used to signal to the testbench that
    // the CPU has completed and retired an instruction. A single cycle
    // implementation will assert this every cycle; however, a pipelined
    // implementation that needs to stall (due to internal hazards or waiting
    // on memory accesses) will not assert the signal on cycles where the
    // instruction in the writeback stage is not retiring.
    //
    // Asserted when an instruction is being retired this cycle. If this is
    // not asserted, the other retire signals are ignored and may be left invalid.
    output wire o_retire_valid,
    // The 32 bit instruction word of the instruction being retired. This
    // should be the unmodified instruction word fetched from instruction
    // memory.
    output wire [31:0] o_retire_inst,
    // Asserted if the instruction produced a trap, due to an illegal
    // instruction, unaligned data memory access, or unaligned instruction
    // address on a taken branch or jump.
    output wire o_retire_trap,
    // Asserted if the instruction is an `ebreak` instruction used to halt the
    // processor. This is used for debugging and testing purposes to end
    // a program.
    output wire o_retire_halt,
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
    output wire [31:0] o_retire_next_pc,
    output wire [31:0] o_retire_dmem_addr,
    output wire o_retire_dmem_ren,
    output wire o_retire_dmem_wen,
    output wire [3:0] o_retire_dmem_mask,
    output wire [31:0] o_retire_dmem_wdata,
    output wire [31:0] o_retire_dmem_rdata

`ifdef RISCV_FORMAL
    ,`RVFI_OUTPUTS,
`endif
);

    // Fetch -> FD -> Decode -> DX -> Execute -> XM -> Memory -> MW -> Writeback
    // f/d/x/m/w mark each stage. wb_ is the write path back to the register file.
    // valid = 0 means the stage contains a bubble.

    // Fetch signals.
    wire f_valid;
    wire [31:0] f_pc;
    wire [31:0] f_inst;

    // Decode signals.
    wire d_valid;
    wire [31:0] d_inst, d_pc;
    wire [4:0] d_rs1_raddr, d_rs2_raddr, d_rd_waddr;
    wire [31:0] d_rs1_rdata, d_rs2_rdata, d_imm_value;
    wire [2:0] d_alu_opsel;
    wire d_alu_sub, d_alu_unsigned, d_alu_arith;
    wire [1:0] d_op1_sel, d_op2_sel, d_wb_sel;
    wire d_reg_wen, d_mem_ren, d_mem_wen;
    wire d_is_branch, d_is_jal, d_is_jalr, d_illegal_inst;
    wire d_uses_rs1, d_uses_rs2;

    // Execute signals.
    wire x_valid;
    wire [31:0] x_inst, x_pc;
    wire [4:0] x_rs1_raddr, x_rs2_raddr, x_rd_waddr;
    wire [31:0] x_rs1_rdata, x_rs2_rdata, x_imm_value;
    wire [2:0] x_alu_opsel;
    wire x_alu_sub, x_alu_unsigned, x_alu_arith;
    wire [1:0] x_op1_sel, x_op2_sel, x_wb_sel;
    wire x_reg_wen, x_mem_ren, x_mem_wen;
    wire x_is_branch, x_is_jal, x_is_jalr, x_illegal_inst;
    wire [31:0] x_alu_result, x_pc_plus4, x_next_pc;
    wire x_trap, x_halt, x_stop, x_redirect;

    // Memory signals.
    wire m_valid;
    wire [31:0] m_inst, m_pc, m_next_pc;
    wire [4:0] m_rs1_raddr, m_rs2_raddr, m_rd_waddr;
    wire [31:0] m_rs1_rdata, m_rs2_rdata;
    wire [31:0] m_alu_result, m_pc_plus4, m_load_data;
    wire m_mem_ren, m_mem_wen, m_reg_wen, m_trap, m_halt;
    wire [1:0] m_wb_sel;

    // Writeback signals.
    wire w_valid, w_reg_wen, w_trap, w_halt;
    wire [31:0] w_inst, w_pc, w_next_pc;
    wire [4:0] w_rs1_raddr, w_rs2_raddr, w_rd_waddr;
    wire [31:0] w_rs1_rdata, w_rs2_rdata, w_rd_wdata;
    wire [31:0] w_dmem_addr, w_dmem_wdata, w_dmem_rdata;
    wire w_dmem_ren, w_dmem_wen;
    wire [3:0] w_dmem_mask;
    wire wb_reg_wen;
    wire [4:0] wb_rd_waddr;
    wire [31:0] wb_rd_wdata;

    // Pipeline control signals.
    wire x_writes_rd, m_writes_rd;
    wire d_rs1_pending, d_rs2_pending;
    wire stall_decode;
    wire stop_fetch;
    wire flush_fetch_decode;
    wire flush_decode_execute;
    reg execution_stopped;

    // Pipeline control.

    // After a trap or halt, stop Fetch and let the older instructions finish.
    always @(posedge i_clk) begin
        if (i_rst)
            execution_stopped <= 1'b0;
        else if (x_stop)
            execution_stopped <= 1'b1;
    end

    // Flush younger instructions on a branch, jump, trap, or halt.
    assign stop_fetch = execution_stopped || x_stop;
    assign flush_fetch_decode = stop_fetch || x_redirect;
    assign flush_decode_execute = flush_fetch_decode || stall_decode;

    // Check whether an older instruction still needs to write a register.
    assign x_writes_rd = x_valid && x_reg_wen && !x_trap && !x_halt &&
                         (x_rd_waddr != 5'd0);
    assign m_writes_rd = m_valid && m_reg_wen && !m_trap && !m_halt &&
                         (m_rd_waddr != 5'd0);

    assign d_rs1_pending = d_uses_rs1 && (d_rs1_raddr != 5'd0) &&
        ((x_writes_rd && (d_rs1_raddr == x_rd_waddr)) ||
         (m_writes_rd && (d_rs1_raddr == m_rd_waddr)) ||
         (wb_reg_wen  && (d_rs1_raddr == w_rd_waddr)));

    assign d_rs2_pending = d_uses_rs2 && (d_rs2_raddr != 5'd0) &&
        ((x_writes_rd && (d_rs2_raddr == x_rd_waddr)) ||
         (m_writes_rd && (d_rs2_raddr == m_rd_waddr)) ||
         (wb_reg_wen  && (d_rs2_raddr == w_rd_waddr)));

    // Wait through Writeback because RF bypass is off.
    // Hold Fetch/FD and insert a bubble in DX while XM/MW keep moving.
    assign stall_decode = d_valid && (d_rs1_pending || d_rs2_pending);

    // Fetch.

    fetch_stage #(
        .RESET_ADDR(RESET_ADDR)
    ) fetch (
        .i_clk(i_clk),
        .i_rst(i_rst),
        .i_stall(stall_decode),
        .i_stop(stop_fetch),
        .i_redirect(x_redirect),
        .i_redirect_pc(x_next_pc),
        .i_imem_rdata(i_imem_rdata),
        .o_imem_raddr(o_imem_raddr),
        .o_valid(f_valid),
        .o_pc(f_pc),
        .o_inst(f_inst)
    );

    // Save Fetch outputs for Decode.
    fd_register fd (
        .i_clk(i_clk),
        .i_rst(i_rst),
        .i_flush(flush_fetch_decode),
        .i_stall(stall_decode),
        .i_valid(f_valid),
        .i_inst(f_inst),
        .i_pc(f_pc),
        .o_valid(d_valid),
        .o_inst(d_inst),
        .o_pc(d_pc)
    );

    // Decode.

    decode_stage decode (
        .i_clk(i_clk),
        .i_rst(i_rst),
        .i_inst(d_inst),
        .i_wb_wen(wb_reg_wen),
        .i_wb_waddr(wb_rd_waddr),
        .i_wb_wdata(wb_rd_wdata),
        .o_rs1_raddr(d_rs1_raddr),
        .o_rs2_raddr(d_rs2_raddr),
        .o_rd_waddr(d_rd_waddr),
        .o_rs1_rdata(d_rs1_rdata),
        .o_rs2_rdata(d_rs2_rdata),
        .o_imm_value(d_imm_value),
        .o_alu_opsel(d_alu_opsel),
        .o_alu_sub(d_alu_sub),
        .o_alu_unsigned(d_alu_unsigned),
        .o_alu_arith(d_alu_arith),
        .o_op1_sel(d_op1_sel),
        .o_op2_sel(d_op2_sel),
        .o_is_branch(d_is_branch),
        .o_is_jal(d_is_jal),
        .o_is_jalr(d_is_jalr),
        .o_illegal_inst(d_illegal_inst),
        .o_mem_ren(d_mem_ren),
        .o_mem_wen(d_mem_wen),
        .o_wb_sel(d_wb_sel),
        .o_reg_wen(d_reg_wen),
        .o_uses_rs1(d_uses_rs1),
        .o_uses_rs2(d_uses_rs2)
    );

    // Save Decode outputs. A dependency stall inserts a bubble here.
    dx_register dx (
        .i_clk(i_clk),
        .i_rst(i_rst),
        .i_flush(flush_decode_execute),
        .i_stall(1'b0),
        .i_valid(d_valid),
        .i_inst(d_inst),
        .i_pc(d_pc),
        .i_rs1_raddr(d_rs1_raddr),
        .i_rs2_raddr(d_rs2_raddr),
        .i_rd_waddr(d_rd_waddr),
        .i_rs1_rdata(d_rs1_rdata),
        .i_rs2_rdata(d_rs2_rdata),
        .i_imm_value(d_imm_value),
        .i_alu_opsel(d_alu_opsel),
        .i_alu_sub(d_alu_sub),
        .i_alu_unsigned(d_alu_unsigned),
        .i_alu_arith(d_alu_arith),
        .i_op1_sel(d_op1_sel),
        .i_op2_sel(d_op2_sel),
        .i_is_branch(d_is_branch),
        .i_is_jal(d_is_jal),
        .i_is_jalr(d_is_jalr),
        .i_illegal_inst(d_illegal_inst),
        .i_mem_ren(d_mem_ren),
        .i_mem_wen(d_mem_wen),
        .i_wb_sel(d_wb_sel),
        .i_reg_wen(d_reg_wen),
        .o_valid(x_valid),
        .o_inst(x_inst),
        .o_pc(x_pc),
        .o_rs1_raddr(x_rs1_raddr),
        .o_rs2_raddr(x_rs2_raddr),
        .o_rd_waddr(x_rd_waddr),
        .o_rs1_rdata(x_rs1_rdata),
        .o_rs2_rdata(x_rs2_rdata),
        .o_imm_value(x_imm_value),
        .o_alu_opsel(x_alu_opsel),
        .o_alu_sub(x_alu_sub),
        .o_alu_unsigned(x_alu_unsigned),
        .o_alu_arith(x_alu_arith),
        .o_op1_sel(x_op1_sel),
        .o_op2_sel(x_op2_sel),
        .o_is_branch(x_is_branch),
        .o_is_jal(x_is_jal),
        .o_is_jalr(x_is_jalr),
        .o_illegal_inst(x_illegal_inst),
        .o_mem_ren(x_mem_ren),
        .o_mem_wen(x_mem_wen),
        .o_wb_sel(x_wb_sel),
        .o_reg_wen(x_reg_wen)
    );

    // Execute.

    execute_stage execute (
        .i_valid(x_valid),
        .i_inst(x_inst),
        .i_pc(x_pc),
        .i_rs1_rdata(x_rs1_rdata),
        .i_rs2_rdata(x_rs2_rdata),
        .i_imm_value(x_imm_value),
        .i_alu_opsel(x_alu_opsel),
        .i_alu_sub(x_alu_sub),
        .i_alu_unsigned(x_alu_unsigned),
        .i_alu_arith(x_alu_arith),
        .i_op1_sel(x_op1_sel),
        .i_op2_sel(x_op2_sel),
        .i_is_branch(x_is_branch),
        .i_is_jal(x_is_jal),
        .i_is_jalr(x_is_jalr),
        .i_illegal_inst(x_illegal_inst),
        .i_mem_ren(x_mem_ren),
        .i_mem_wen(x_mem_wen),
        .o_alu_result(x_alu_result),
        .o_pc_plus4(x_pc_plus4),
        .o_next_pc(x_next_pc),
        .o_trap(x_trap),
        .o_halt(x_halt),
        .o_stop(x_stop),
        .o_redirect(x_redirect)
    );

    // Save Execute outputs for Memory.
    xm_register xm (
        .i_clk(i_clk),
        .i_rst(i_rst),
        .i_flush(1'b0),
        .i_stall(1'b0),
        .i_valid(x_valid),
        .i_inst(x_inst),
        .i_pc(x_pc),
        .i_next_pc(x_next_pc),
        .i_rs1_raddr(x_rs1_raddr),
        .i_rs2_raddr(x_rs2_raddr),
        .i_rd_waddr(x_rd_waddr),
        .i_rs1_rdata(x_rs1_rdata),
        .i_rs2_rdata(x_rs2_rdata),
        .i_alu_result(x_alu_result),
        .i_pc_plus4(x_pc_plus4),
        .i_mem_ren(x_mem_ren),
        .i_mem_wen(x_mem_wen),
        .i_wb_sel(x_wb_sel),
        .i_reg_wen(x_reg_wen),
        .i_trap(x_trap),
        .i_halt(x_halt),
        .o_valid(m_valid),
        .o_inst(m_inst),
        .o_pc(m_pc),
        .o_next_pc(m_next_pc),
        .o_rs1_raddr(m_rs1_raddr),
        .o_rs2_raddr(m_rs2_raddr),
        .o_rd_waddr(m_rd_waddr),
        .o_rs1_rdata(m_rs1_rdata),
        .o_rs2_rdata(m_rs2_rdata),
        .o_alu_result(m_alu_result),
        .o_pc_plus4(m_pc_plus4),
        .o_mem_ren(m_mem_ren),
        .o_mem_wen(m_mem_wen),
        .o_wb_sel(m_wb_sel),
        .o_reg_wen(m_reg_wen),
        .o_trap(m_trap),
        .o_halt(m_halt)
    );

    // Memory.

    memory_stage memory (
        .i_rst(i_rst),
        .i_valid(m_valid),
        .i_inst(m_inst),
        .i_alu_result(m_alu_result),
        .i_rs2_rdata(m_rs2_rdata),
        .i_mem_ren(m_mem_ren),
        .i_mem_wen(m_mem_wen),
        .i_trap(m_trap),
        .i_halt(m_halt),
        .i_dmem_rdata(i_dmem_rdata),
        .o_dmem_addr(o_dmem_addr),
        .o_dmem_ren(o_dmem_ren),
        .o_dmem_wen(o_dmem_wen),
        .o_dmem_wdata(o_dmem_wdata),
        .o_dmem_mask(o_dmem_mask),
        .o_load_data(m_load_data)
    );

    // Select and save the result for Writeback.
    mw_register mw (
        .i_clk(i_clk),
        .i_rst(i_rst),
        .i_flush(1'b0),
        .i_stall(1'b0),
        .i_valid(m_valid),
        .i_inst(m_inst),
        .i_pc(m_pc),
        .i_next_pc(m_next_pc),
        .i_rs1_raddr(m_rs1_raddr),
        .i_rs2_raddr(m_rs2_raddr),
        .i_rd_waddr(m_rd_waddr),
        .i_rs1_rdata(m_rs1_rdata),
        .i_rs2_rdata(m_rs2_rdata),
        .i_alu_result(m_alu_result),
        .i_mem_data(m_load_data),
        .i_dmem_addr(o_dmem_addr),
        .i_dmem_ren(o_dmem_ren),
        .i_dmem_wen(o_dmem_wen),
        .i_dmem_mask(o_dmem_mask),
        .i_dmem_wdata(o_dmem_wdata),
        .i_dmem_rdata(i_dmem_rdata),
        .i_pc_plus4(m_pc_plus4),
        .i_wb_sel(m_wb_sel),
        .i_reg_wen(m_reg_wen),
        .i_trap(m_trap),
        .i_halt(m_halt),
        .o_valid(w_valid),
        .o_inst(w_inst),
        .o_pc(w_pc),
        .o_next_pc(w_next_pc),
        .o_rs1_raddr(w_rs1_raddr),
        .o_rs2_raddr(w_rs2_raddr),
        .o_rd_waddr(w_rd_waddr),
        .o_rs1_rdata(w_rs1_rdata),
        .o_rs2_rdata(w_rs2_rdata),
        .o_rd_wdata(w_rd_wdata),
        .o_dmem_addr(w_dmem_addr),
        .o_dmem_ren(w_dmem_ren),
        .o_dmem_wen(w_dmem_wen),
        .o_dmem_mask(w_dmem_mask),
        .o_dmem_wdata(w_dmem_wdata),
        .o_dmem_rdata(w_dmem_rdata),
        .o_reg_wen(w_reg_wen),
        .o_trap(w_trap),
        .o_halt(w_halt)
    );

    // Writeback.

    writeback_stage writeback (
        .i_rst(i_rst),
        .i_valid(w_valid),
        .i_inst(w_inst),
        .i_pc(w_pc),
        .i_next_pc(w_next_pc),
        .i_rs1_raddr(w_rs1_raddr),
        .i_rs2_raddr(w_rs2_raddr),
        .i_rs1_rdata(w_rs1_rdata),
        .i_rs2_rdata(w_rs2_rdata),
        .i_rd_waddr(w_rd_waddr),
        .i_rd_wdata(w_rd_wdata),
        .i_dmem_addr(w_dmem_addr),
        .i_dmem_ren(w_dmem_ren),
        .i_dmem_wen(w_dmem_wen),
        .i_dmem_mask(w_dmem_mask),
        .i_dmem_wdata(w_dmem_wdata),
        .i_dmem_rdata(w_dmem_rdata),
        .i_reg_wen(w_reg_wen),
        .i_trap(w_trap),
        .i_halt(w_halt),
        .o_rf_wen(wb_reg_wen),
        .o_rf_waddr(wb_rd_waddr),
        .o_rf_wdata(wb_rd_wdata),
        .o_retire_valid(o_retire_valid),
        .o_retire_inst(o_retire_inst),
        .o_retire_trap(o_retire_trap),
        .o_retire_halt(o_retire_halt),
        .o_retire_rs1_raddr(o_retire_rs1_raddr),
        .o_retire_rs2_raddr(o_retire_rs2_raddr),
        .o_retire_rs1_rdata(o_retire_rs1_rdata),
        .o_retire_rs2_rdata(o_retire_rs2_rdata),
        .o_retire_rd_waddr(o_retire_rd_waddr),
        .o_retire_rd_wdata(o_retire_rd_wdata),
        .o_retire_pc(o_retire_pc),
        .o_retire_next_pc(o_retire_next_pc),
        .o_retire_dmem_addr(o_retire_dmem_addr),
        .o_retire_dmem_ren(o_retire_dmem_ren),
        .o_retire_dmem_wen(o_retire_dmem_wen),
        .o_retire_dmem_mask(o_retire_dmem_mask),
        .o_retire_dmem_wdata(o_retire_dmem_wdata),
        .o_retire_dmem_rdata(o_retire_dmem_rdata)
    );

endmodule

`default_nettype wire
