# Five-stage hart

`hart.v` connects the five stage modules and four pipeline registers:

```text
Fetch -> FD -> Decode -> DX -> Execute -> XM -> Memory -> MW -> Writeback
                 ^                                               |
                 +------------- register-file write -------------+
```

| Module | Responsibility |
| --- | --- |
| `stages/fetch_stage.v` | PC register, sequential fetch, stalls, and redirects |
| `stages/decode_stage.v` | Decoder, immediate generator, register file, and source-use flags |
| `stages/execute_stage.v` | ALU, branch/jump decision, next PC, and fault detection |
| `stages/memory_stage.v` | Memory request qualification, byte masks, store alignment, and load extension |
| `stages/writeback_stage.v` | Register-file write qualification and instruction retirement |

The FD/DX/XM/MW registers remain separate modules in `pipeline_registers/`.
Each holds the information belonging to the next stage's instruction. The
existing MW interface selects ALU/load/PC+4 data before registering it, so
Writeback receives an already selected result. Data paths use `[31:0]`;
register numbers use `[4:0]`.

`hart.v` coordinates dependencies and flushing across stages. With forwarding
and RF bypass disabled, a dependent instruction holds Fetch and FD until its
source registers have been written. DX receives a bubble while older
instructions continue. Dependencies on x0 and unused instruction fields do
not stall execution. Independent instructions can retire every cycle after
the pipeline fills.

Branches and jumps resolve in Execute, redirect Fetch, and flush FD/DX. A
halt or trap flushes younger instructions, allows older instructions to
finish, and stops execution until reset. Faulting memory instructions issue
no memory request. Valid bits exclude bubbles from architectural effects
and retirement. Reset is synchronous and active high.

The memory interface retains the supplied combinational-read,
clocked-write behavior; there is no memory-ready handshake.

## Reading the code

Read `hart.v` in pipeline order. Each section contains a stage
followed by the pipeline register that saves its outputs. The logic before
these sections decides when to stall, flush, or stop execution.

Signal names tell you where an instruction currently lives:

| Prefix | Meaning | Example |
| --- | --- | --- |
| `f_` | Fetch | `f_pc`: address being fetched |
| `d_` | Decode | `d_rs1_rdata`: first operand read from the register file |
| `x_` | Execute | `x_rs1_rdata`: first operand saved in DX |
| `m_` | Memory | `m_alu_result`: address/result saved in XM |
| `w_` | Writeback | `w_rd_wdata`: final value saved in MW |
| `wb_` | Writeback's return path to the register file | `wb_reg_wen`: qualified write enable |

Within a module, `i_` means an input and `o_` means an output. `rs1`/`rs2`
are source registers; `rd` is the destination. `raddr`/`waddr` are register
numbers, while `rdata`/`wdata` are the values in those registers. `wen`/`ren`
mean write/read enable, and `sel` selects a mux input.

For example, trace the first operand of `add x5, x1, x2`:

```text
Decode reads x1 -> d_rs1_rdata -> DX input
                                  |
                           rising clock edge
                                  |
Execute uses x_rs1_rdata <- DX output
```

In `.i_rs1_rdata (x_rs1_rdata)`, the name on the left is the child module's
input port. The name in parentheses is the wire in `hart.v` connected to it.
At that same clock edge other instructions advance in the other stages.

The controls have different purposes:

| Event | Fetch PC | FD | DX | Older instructions |
| --- | --- | --- | --- | --- |
| Normal cycle | Advance by 4 | Capture Fetch | Capture Decode | Advance |
| Source register still pending | Hold | Hold | Insert a bubble | Advance |
| Taken branch or jump | Redirect to target | Flush | Flush | Advance |
| Trap or halt in Execute | Hold until reset | Flush | Flush | Finish; trap/halt retires once |
| Reset | Set to `RESET_ADDR` | Clear | Clear | Clear XM/MW too |

A stall preserves an instruction so it can try again. A flush discards an
instruction. The per-stage files explain operand selection, alignment, and
write qualification beside the logic that performs each operation. Named
`localparam` constants identify control encodings and are not overridable.

The decoder sets `o_uses_rs1` and `o_uses_rs2` in its existing opcode case,
alongside the other instruction controls. Register ALU operations, stores,
and branches read both sources; immediate ALU operations, loads, and JALR
read only rs1. LUI, AUIPC, JAL, and the supported SYSTEM instruction read
neither. `decode_stage.v` simply connects these flags to the hazard logic.

Multiway selections use `case` inside `always @(*)`, with a `default` in
every case to assign a value for every selector and avoid latches. These
blocks use blocking `=` assignments for combinational logic. Their `reg`
declarations allow procedural assignments; they do not add clocked storage.
Pipeline registers use `always @(posedge i_clk)` with nonblocking `<=`.

## Parameters and named constants

Use `parameter` for settings a parent module may change, such as
`RESET_ADDR`. Use `localparam` for fixed meanings, such as `OPCODE_LOAD`,
`ALU_ADD_SUB`, `WB_LOAD`, `NOP_INST`, and `EBREAK_INST`.

For example, the decoder now reads `OPCODE_LOAD: begin` rather than
`7'b0000011: begin`. Constants are declared beside the module's logic, and
matching names carry the same encoding in the decoder, stages, and pipeline
registers. Data ports retain explicit `[31:0]` widths.

## Validation

From the repository root, with Icarus Verilog and Python 3 installed:

```sh
make -C project4-and-5 test
```

This compiles the hart, runs the existing pipeline-register tests, and checks
instruction retirement and memory requests against a sequential reference
model. Coverage includes dependencies, x0, pipeline throughput, load/store
byte lanes, branch conditions, JAL/JALR, flushing, halt/trap draining,
reset during execution, a nonzero reset address, deterministic randomized
programs, and the supplied assembled `.hex` programs.

Decoder checks sweep every funct3/funct7 combination for register and
immediate ALU instructions, plus load/store/branch/JALR encodings. Expected
results come from a separate mask/match table based on the official
[base instruction encodings](https://github.com/riscv/riscv-opcodes/blob/master/extensions/rv_i)
and [RV32 shift encodings](https://github.com/riscv/riscv-opcodes/blob/master/extensions/rv32_i).
Rejected instructions must disable writes, memory requests, redirects, and
source-use flags. Pipeline tests also verify that they retire as traps and
discard younger instructions.

With the repository's `ece552` checker installed:

```sh
make -C project4-and-5 check
```

The Makefile lists the implemented RTL explicitly. The separate `rtl/hart.v`
is an unimplemented starter with the same module name and is excluded.
