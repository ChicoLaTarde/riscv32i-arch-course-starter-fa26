# Project 6: multi-cycle memory

The five-stage processor is adapted from Project 5. The Project 5 sources
remain separate. Production modules are flat under `rtl/` and the Makefile
lists them explicitly.

## Memory protocol

- A request is issued only when its corresponding `ready` input is high.
- Fetch permits one outstanding request. If its response arrives while
  F/D is held, a one-entry instruction buffer preserves both instruction
  and request PC. Redirects discard buffered instructions and drain any
  stale outstanding response before fetching the new target.
- A load is requested once, then X/M and the younger stages hold until
  `i_dmem_valid`. Writeback drains normally and receives bubbles while
  Memory waits, so an older instruction cannot retire repeatedly.
- Stores finish at request acceptance. The supplied `tb_memory.v` asserts
  `o_valid` for reads only; its separate `o_wdone` is not a hart input.
  Waiting for `i_dmem_valid` after a store would deadlock with that model.
  Actual memory transactions complete in order.
- Redirects and stop events take effect only when Execute can advance past
  the older Memory instruction. Forwarded operands are retained across a
  Memory stall even after their Writeback producer has drained.
- Memory request information travels through M/W alongside the instruction.
  Retirement reports the original aligned address, mask, positioned write
  data, and raw read data, rather than the current Memory-stage request.

No fixed latency is assumed. Zero-cycle read responses are also supported
to keep the ready/valid boundary compatible with a future cache.

## Validation

From the repository root:

```sh
make -C project6-and-7 compile test test-official check
```

`compile` elaborates the supplied official hart testbench. `test` uses the
existing Project 5 instruction-level reference model and program generator
from `project4-and-5/tb/run_pipeline_tests.py`. It checks seven independent
instruction/data latency and initiation-interval configurations, including
fast responses, long stalls, redirects, resets, forwarding, and all six
memory-retirement outputs. The supplied `tb_memory.v` is used unchanged for
nonzero latencies; zero-cycle configurations use a test-only fast-memory path.
The official model has a documented LATENCY=1 limitation, so nonzero tests
use LATENCY >= 2.

Tests automatically include any assembled `tests/asm/*.hex` programs.
The 25 supplied basic and advanced assembly programs are included as assembled
binary `.hex` fixtures. With these present, `test` runs 99 programs across
seven timing configurations (693 simulations). `test-official` runs all 25
with the unchanged official testbench and compares the complete printed traces.

To regenerate the binary fixtures from the original source archives, use an
installed GNU RISC-V assembler and objcopy:

```sh
make -C project6-and-7 assemble
make -C project6-and-7 assemble RISCV_PREFIX=/path/to/riscv32-esp-elf-
```

The independent regression test initializes data memory to zero. The official
testbench does not initialize data memory; a standalone assembly program must
initialize every data byte that it later reads.

`check` runs the course Verilog checker against production sources only.

## Submission

Submit the 16 Verilog files listed by `RTL` in the Makefile. Do not submit
`rtl/tb_memory.v`, either testbench, or generated simulation binaries.
`rtl/cache.v` is the untouched Project 7 starter and is not instantiated or
needed by this Project 6 implementation.
