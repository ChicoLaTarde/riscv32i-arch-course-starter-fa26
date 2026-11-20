# Project 6 and 7 CPI Comparison

The Project 6 processor without instruction or data caches is the baseline.
Record Project 7 results below to compare performance on the same programs.

## Performance results

Baseline measured November 19, 2026, using `tb/tb.v` and the programs in
`tests/asm/`. CPI is cycles per retired instruction; lower is better.

| Program | Retired instructions | No-cache cycles | No-cache CPI | Cached cycles | Cached CPI | Speedup |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| add (`01add`) | 121 | 609 | 5.033 | — | — | — |
| memory (`06memory`) | 47 | 279 | 5.936 | — | — | — |
| sort | 1,914 | 12,064 | 6.303 | — | — | — |

Cached results have not been measured yet. Retired instruction counts should
match the baseline when running the same program.

## Baseline testbench settings

| Setting | Instruction memory | Data memory |
| --- | ---: | ---: |
| Cache | None | None |
| Memory size | 1,024 bytes | 1,024 bytes |
| `LATENCY` | 4 cycles | 4 cycles |
| `INTERVAL` | 2 cycles | 2 cycles |

The testbench counts cycles after reset is released through retirement of the
halting instruction. The totals include pipeline fill and stalls, and the
retired instruction count includes the halting instruction.

## Comparing the cache implementation

Use the same program binaries, backing-memory settings, reset sequence, and
cycle-counting method. Reset the caches to empty before each run and include
the initial cache misses. Record the cache sizes, line sizes, associativity,
and write policy with the cached results.

```text
CPI = total cycles / retired instructions
Speedup at the same clock frequency = no-cache cycles / cached cycles
Execution time = total cycles / clock frequency
```

Use the exact cycle counts to calculate speedup rather than the rounded CPI
values. If the designs run at different clock frequencies, compare execution
times instead. The testbench uses a 10 ns clock period for simulation; actual
achievable hardware frequency requires synthesis and timing analysis.

The terminal's elapsed time measures how long the simulator runs on the Mac.
Use simulated cycles and CPI for this comparison.
