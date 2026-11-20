from pathlib import Path
import sys
import tempfile
import run_multicycle_tests as suite


ROOT = Path(__file__).resolve().parents[1]
binary = Path(sys.argv[1]).resolve()
model = suite.model
programs = sorted((ROOT / 'tests/asm').glob('*.hex'))
if not programs:
    raise SystemExit('Run make assemble first')
for path in programs:
    data = path.read_bytes()
    words = [int.from_bytes(data[index:index + 4], 'little') for index in range(0, len(data), 4)]
    traces, accesses, registers = model.reference(words + [model.NOP] * 4096, 0)
    with tempfile.TemporaryDirectory(prefix='ece552-official-p6-') as temporary:
        directory = Path(temporary)
        (directory / 'program.mem').write_text('\n'.join('%02x' % byte for byte in data) + '\n')
        result = suite.subprocess.run(['vvp', str(binary)], cwd=directory, text=True,
                                      capture_output=True, timeout=60, check=True)
        output = result.stdout
        assert 'Program did not halt' not in output, path.name
        observed = [line for line in output.splitlines() if line.startswith('[')]
        assert len(observed) == len(traces), (path.name, len(observed), len(traces))
        memory = bytearray(4096)
        access_index = 0
        for line, trace in zip(observed, traces):
            pc, instruction, trap, halt, rs1, first, rs2, second, rd, value, next_pc = trace
            opcode = instruction & 127
            wanted = '[%08x] %08x' % (pc, instruction)
            if instruction & 15 == 7 or opcode in (0x73, 0x6F):
                wanted += ' r[--]=-------- r[--]=--------'
            elif opcode in (0x13, 3, 0x67):
                wanted += ' r[%2d]=%08x r[--]=--------' % (rs1, first)
            else:
                wanted += ' r[%2d]=%08x r[%2d]=%08x' % (rs1, first, rs2, second)
            if rd:
                wanted += ' w[%2d]=%08x' % (rd, value)
            if opcode in (3, 0x23) and not trap:
                ren, wen, address, mask, wdata = accesses[access_index]
                access_index += 1
                if wen:
                    wanted += ' s[%08x,%s]=%08x' % (address, format(mask, '04b'), wdata)
                    for lane in range(4):
                        if mask & (1 << lane):
                            memory[address + lane] = (wdata >> (lane * 8)) & 255
                else:
                    value = ''.join('%02x' % memory[address + lane] if mask & (1 << lane) else '--'
                                    for lane in (3, 2, 1, 0))
                    wanted += ' l[%08x,%s]=%s' % (address, format(mask, '04b'), value)
            if trap:
                wanted += ' TRAP'
            assert line == wanted, (path.name, line, wanted)
    print('PASS: official testbench %s (%d retired)' % (path.stem, len(traces)), flush=True)
print('PASS: all %d official programs matched complete reference traces' % len(programs))
