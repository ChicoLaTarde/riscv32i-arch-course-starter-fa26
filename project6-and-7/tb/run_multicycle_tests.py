from pathlib import Path
import importlib.util
import os
import subprocess
import tempfile


ROOT = Path(__file__).resolve().parents[1]
REFERENCE = Path(os.environ.get('ECE552_REFERENCE_ROOT', ROOT.parent / 'project4-and-5'))
spec = importlib.util.spec_from_file_location('rv32_reference', REFERENCE / 'tb/run_pipeline_tests.py')
model = importlib.util.module_from_spec(spec)
spec.loader.exec_module(model)
RTL_NAMES = (
    'hart.v', 'PC_reg.v', 'rf.v', 'decoder.v', 'imm.v', 'alu.v', 'forwarding_unit.v',
    'fetch_stage.v', 'decode_stage.v', 'execute_stage.v', 'memory_stage.v',
    'writeback_stage.v', 'fd_register.v', 'dx_register.v', 'xm_register.v', 'mw_register.v',
)
CONFIGURATIONS = ((2, 1, 2, 1), (4, 2, 4, 2), (9, 5, 3, 2),
                  (2, 1, 13, 5), (0, 1, 0, 1), (0, 1, 9, 3), (5, 3, 0, 2))


def run(command):
    result = subprocess.run([str(value) for value in command], text=True, capture_output=True, timeout=60)
    if result.returncode:
        raise AssertionError(' '.join(map(str, command)) + '\n' + result.stdout + result.stderr)
    return result.stdout


def cases():
    yield from model.cases()
    yield 'wb-operand-survives-stall', [model.ri(1, 0, 7), model.ri(2, 0, 0, 2, 3),
                                       model.rr(3, 1, 1), model.HALT], 0, 0
    yield 'blocked-branch', [model.ri(1, 0, 7), model.store(1, 0),
                             model.branch(1, 0, 12, 1), model.store(0, 0, 4),
                             0xFFFFFFFF, model.HALT], 0, 0
    yield 'halt-behind-load', [model.ri(1, 0, 0, 2, 3), model.HALT,
                              model.store(0, 0, 4)], 0, 0
    yield 'newest-forwarding-wins', [model.ri(1, 0, 7), model.ri(1, 0, 9),
                                    model.rr(2, 1, 1), model.HALT], 0, 0
    for reset_after in (3, 7, 19):
        yield 'reset-request-%d' % reset_after, [model.ri(1, 0, 0, 2, 3),
                                               model.rr(2, 1, 1), model.HALT], 0, reset_after
    for path in sorted((ROOT / 'tests/asm').glob('*.hex')):
        data = path.read_bytes()
        yield 'official-' + path.stem, [int.from_bytes(data[index:index + 4], 'little')
                                       for index in range(0, len(data), 4)], 0, 0


def check_memory(traces, accesses, observed):
    assert len(observed) == len(traces), 'missing retirement memory metadata'
    memory = bytearray(4096)
    access_index = 0
    for trace, fields in zip(traces, observed):
        pc, instruction, trap = trace[:3]
        observed_pc, read_enable, write_enable = [int(value, 16) for value in fields[:3]]
        assert observed_pc == pc
        if trap or instruction & 127 not in (3, 0x23):
            assert (read_enable, write_enable) == (0, 0)
            continue
        wanted = accesses[access_index]
        access_index += 1
        address, mask = int(fields[3], 16), int(fields[4], 16)
        assert (read_enable, write_enable, address, mask) == wanted[:4]
        for lane in range(4):
            if not mask & (1 << lane):
                continue
            first = (3 - lane) * 2
            if write_enable:
                wanted_byte = (wanted[4] >> (lane * 8)) & 255
                assert int(fields[5][first:first + 2], 16) == wanted_byte
                memory[address + lane] = wanted_byte
            else:
                assert int(fields[6][first:first + 2], 16) == memory[address + lane]
    assert access_index == len(accesses)


def main():
    total = retired = 0
    sources = [ROOT / 'rtl' / name for name in RTL_NAMES]
    with tempfile.TemporaryDirectory(prefix='ece552-multicycle-') as temporary:
        directory = Path(temporary)
        for configuration in CONFIGURATIONS:
            binaries = {}
            count = 0
            for name, program, reset_address, reset_after in cases():
                context = '%s %s' % (configuration, name)
                if reset_address not in binaries:
                    binary = directory / ('simulation-%s-%d' % ('-'.join(map(str, configuration)), reset_address))
                    parameters = dict(zip(('I_LATENCY', 'I_INTERVAL', 'D_LATENCY', 'D_INTERVAL'), configuration))
                    parameters['RESET_ADDR'] = reset_address
                    run(['iverilog', '-g2012', '-s', 'multicycle_tb', '-o', binary,
                         *['-Pmulticycle_tb.%s=%d' % pair for pair in parameters.items()],
                         *sources, ROOT / 'rtl/tb_memory.v', ROOT / 'tb/multicycle_tb.sv'])
                    binaries[reset_address] = binary
                words = [model.NOP] * (reset_address // 4) + program
                words += [model.NOP] * (4096 - len(words))
                expected, expected_bus, registers = model.reference(words, reset_address)
                program_path = directory / 'program.mem'
                data = b''.join(word.to_bytes(4, 'little') for word in words)
                program_path.write_text('\n'.join('%02x' % byte for byte in data) + '\n')
                output = run(['vvp', binaries[reset_address], '+PROGRAM=' + str(program_path),
                              '+RESET_AFTER=%d' % reset_after])
                actual, bus, memory_records = [], [], []
                for line in output.splitlines():
                    fields = line.split()
                    if not fields:
                        continue
                    if fields[0] == 'RET':
                        actual.append(tuple(model.parse_word(value) for value in fields[2:]))
                    elif fields[0] == 'BUS':
                        bus.append(tuple(model.parse_word(value) for value in fields[1:]))
                    elif fields[0] == 'RET_MEM':
                        memory_records.append(fields[1:])
                assert 'DONE ' in output, context + ': did not drain'
                assert len(actual) == len(expected), (context, len(actual), len(expected))
                for index, (observed, wanted) in enumerate(zip(actual, expected)):
                    for field, (got, want) in enumerate(zip(observed, wanted)):
                        assert want is None or got == want, (context, index, field, got, want)
                assert len(bus) == len(expected_bus), (context, 'duplicate or missing requests')
                for observed, wanted in zip(bus, expected_bus):
                    assert observed[:4] == wanted[:4], (context, observed, wanted)
                    if wanted[1]:
                        mask = sum(255 << (8 * lane) for lane in range(4) if wanted[3] & (1 << lane))
                        assert observed[4] & mask == wanted[4] & mask, context
                try:
                    check_memory(expected, expected_bus, memory_records)
                except (AssertionError, ValueError) as error:
                    raise AssertionError(context + ': memory retirement mismatch') from error
                if name.startswith('assembly-') or name.startswith('official-') and name[9:11].isdigit():
                    assert registers[10] == 1, context + ': assembly fail path'
                if name == 'official-factorial_2':
                    assert registers[10] == 2, context
                if name == 'official-factorial_5':
                    assert registers[10] == 120, context
                total += 1
                count += 1
                retired += len(actual)
            print('PASS: latencies/intervals %s: %d programs' % (configuration, count), flush=True)
    print('PASS: %d runs, %d retired instructions; requests and retirement matched the reference' % (total, retired))


if __name__ == '__main__':
    main()
