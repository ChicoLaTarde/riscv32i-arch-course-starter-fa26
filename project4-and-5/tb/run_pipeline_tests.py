#!/usr/bin/env python3
"""Compare pipeline retirement and memory requests with a sequential RV32I model.

Run from any directory: python3 project4-and-5/tb/run_pipeline_tests.py
Requires iverilog and vvp. All generated files stay in a temporary directory.
"""

from pathlib import Path
import random
import shutil
import subprocess
import tempfile


ROOT = Path(__file__).resolve().parents[1]
MASK = 0xFFFFFFFF
NOP = 0x00000013
HALT = 0x00100073

# Mask/match pairs for the instructions implemented by this core. These
# independently describe the fixed instruction bits, not pipeline controls.
# Source: github.com/riscv/riscv-opcodes, extensions/rv_i and rv32_i.
SUPPORTED_ENCODINGS = (
    # Register arithmetic: funct7, funct3, and opcode are fixed.
    (0xFE00707F, 0x00000033),  # ADD
    (0xFE00707F, 0x40000033),  # SUB
    (0xFE00707F, 0x00001033),  # SLL
    (0xFE00707F, 0x00002033),  # SLT
    (0xFE00707F, 0x00003033),  # SLTU
    (0xFE00707F, 0x00004033),  # XOR
    (0xFE00707F, 0x00005033),  # SRL
    (0xFE00707F, 0x40005033),  # SRA
    (0xFE00707F, 0x00006033),  # OR
    (0xFE00707F, 0x00007033),  # AND
    # Immediate arithmetic: only shifts restrict the upper immediate bits.
    (0x0000707F, 0x00000013),  # ADDI
    (0xFE00707F, 0x00001013),  # SLLI
    (0x0000707F, 0x00002013),  # SLTI
    (0x0000707F, 0x00003013),  # SLTIU
    (0x0000707F, 0x00004013),  # XORI
    (0xFE00707F, 0x00005013),  # SRLI
    (0xFE00707F, 0x40005013),  # SRAI
    (0x0000707F, 0x00006013),  # ORI
    (0x0000707F, 0x00007013),  # ANDI
    (0x0000707F, 0x00000003),  # LB
    (0x0000707F, 0x00001003),  # LH
    (0x0000707F, 0x00002003),  # LW
    (0x0000707F, 0x00004003),  # LBU
    (0x0000707F, 0x00005003),  # LHU
    (0x0000707F, 0x00000023),  # SB
    (0x0000707F, 0x00001023),  # SH
    (0x0000707F, 0x00002023),  # SW
    (0x0000707F, 0x00000063),  # BEQ
    (0x0000707F, 0x00001063),  # BNE
    (0x0000707F, 0x00004063),  # BLT
    (0x0000707F, 0x00005063),  # BGE
    (0x0000707F, 0x00006063),  # BLTU
    (0x0000707F, 0x00007063),  # BGEU
    (0x0000007F, 0x00000037),  # LUI
    (0x0000007F, 0x00000017),  # AUIPC
    (0x0000007F, 0x0000006F),  # JAL
    (0x0000707F, 0x00000067),  # JALR
    (0xFFFFFFFF, HALT),        # EBREAK; ECALL/other SYSTEM encodings trap.
)


def supported(inst):
    return any(inst & mask == match for mask, match in SUPPORTED_ENCODINGS)


def signed(value, bits=32):
    value &= (1 << bits) - 1
    return value - (1 << bits) if value & (1 << (bits - 1)) else value


def ri(rd, rs1, immediate, funct3=0, opcode=0x13):
    return ((immediate & 0xFFF) << 20) | rs1 << 15 | funct3 << 12 | rd << 7 | opcode


def rr(rd, rs1, rs2, funct3=0, funct7=0):
    return funct7 << 25 | rs2 << 20 | rs1 << 15 | funct3 << 12 | rd << 7 | 0x33


def store(rs2, rs1, immediate=0, funct3=2):
    immediate &= 0xFFF
    return ((immediate >> 5) << 25 | rs2 << 20 | rs1 << 15 |
            funct3 << 12 | (immediate & 31) << 7 | 0x23)


def branch(rs1, rs2, offset, funct3=0):
    offset &= 0x1FFF
    return ((offset >> 12) << 31 | ((offset >> 5) & 63) << 25 |
            rs2 << 20 | rs1 << 15 | funct3 << 12 |
            ((offset >> 1) & 15) << 8 | ((offset >> 11) & 1) << 7 | 0x63)


def jump(rd, offset):
    offset &= 0x1FFFFF
    return ((offset >> 20) << 31 | ((offset >> 1) & 1023) << 21 |
            ((offset >> 11) & 1) << 20 | ((offset >> 12) & 255) << 12 | rd << 7 | 0x6F)


def upper(rd, immediate, opcode=0x37):
    return (immediate & 0xFFFFF) << 12 | rd << 7 | opcode


def reference(words, start_pc):
    """Instruction-level execution has no knowledge of pipeline stages."""
    registers = [0] * 32
    memory = bytearray(4096)
    traces, accesses = [], []
    pc = start_pc
    for _ in range(20000):
        inst = words[pc // 4]
        opcode, f3, f7 = inst & 127, (inst >> 12) & 7, inst >> 25
        rd, rs1, rs2 = (inst >> 7) & 31, (inst >> 15) & 31, (inst >> 20) & 31
        a, b = registers[rs1], registers[rs2]
        imm = signed(inst >> 20, 12)
        next_pc, result = (pc + 4) & MASK, None
        use1 = use2 = False
        trap, halt = bool(pc & 3), inst == HALT
        if not supported(inst):
            trap = True
        elif opcode in (0x13, 0x33):
            use1, use2 = True, opcode == 0x33
            rhs = b if use2 else imm & MASK
            shift = rhs & 31
            subtract = use2 and f7 == 0x20
            arithmetic = bool(inst & (1 << 30))
            if f3 == 0: result = a - rhs if subtract else a + rhs
            elif f3 == 1: result = a << shift
            elif f3 == 2: result = int(signed(a) < signed(rhs))
            elif f3 == 3: result = int(a < rhs)
            elif f3 == 4: result = a ^ rhs
            elif f3 == 5: result = signed(a) >> shift if arithmetic else a >> shift
            elif f3 == 6: result = a | rhs
            elif f3 == 7: result = a & rhs
        elif opcode in (0x37, 0x17):
            result = (inst & 0xFFFFF000) + (pc if opcode == 0x17 else 0)
        elif opcode in (0x03, 0x23):
            use1, use2 = True, opcode == 0x23
            if use2: imm = signed(((inst >> 25) << 5) | ((inst >> 7) & 31), 12)
            address = (a + imm) & MASK
            size = {0: 1, 1: 2, 2: 4, 4: 1, 5: 2}[f3]
            trap |= bool(address % size)
            if not trap:
                offset = address & 3
                mask = ((1 << size) - 1) << offset
                data = (b << (offset * 8)) & MASK
                accesses.append((int(not use2), int(use2), address & ~3, mask, data))
                if use2:
                    memory[address:address + size] = (b & ((1 << (size * 8)) - 1)).to_bytes(size, 'little')
                else:
                    result = int.from_bytes(memory[address:address + size], 'little')
                    if f3 < 4: result = signed(result, size * 8)
        elif opcode == 0x63:
            use1 = use2 = True
            offset = signed(((inst >> 31) << 12) | (((inst >> 7) & 1) << 11) |
                            (((inst >> 25) & 63) << 5) | (((inst >> 8) & 15) << 1), 13)
            taken = {0: a == b, 1: a != b, 4: signed(a) < signed(b),
                     5: signed(a) >= signed(b), 6: a < b, 7: a >= b}[f3]
            if taken:
                next_pc = (pc + offset) & MASK
                trap |= bool(next_pc & 3)
        elif opcode == 0x6F:
            offset = signed(((inst >> 31) << 20) | (((inst >> 12) & 255) << 12) |
                            (((inst >> 20) & 1) << 11) | (((inst >> 21) & 1023) << 1), 21)
            result, next_pc = next_pc, (pc + offset) & MASK
            trap |= bool(next_pc & 3)
        elif opcode == 0x67:
            use1 = True
            result, next_pc = next_pc, ((a + imm) & MASK) & ~1
            trap |= bool(next_pc & 3)
        elif not halt:
            trap = True
        write_rd = rd if result is not None and not trap and rd != 0 else 0
        result = result & MASK if result is not None else 0
        traces.append((pc, inst, int(trap), int(halt),
                       rs1 if use1 else None, a if use1 else None,
                       rs2 if use2 else None, b if use2 else None,
                       write_rd, result if write_rd else None, next_pc))
        if write_rd: registers[write_rd] = result
        if trap or halt: return traces, accesses, registers
        pc = next_pc
    raise AssertionError('reference program did not terminate')


def cases():
    yield 'independent-throughput', [ri(1, 0, 1), ri(2, 0, 1), upper(3, 0x12345),
                                      upper(4, 1, 0x17), ri(0, 0, 7), NOP, HALT], 0, 0
    yield 'raw-both-operands', [ri(1, 0, 7), ri(2, 1, 5), rr(3, 1, 2),
                              ri(3, 3, -1), rr(4, 3, 3), ri(0, 4, 99),
                              ri(5, 0, 0), HALT], 0, 0
    memory = [ri(20, 0, 256), upper(1, 0x89ABD), ri(1, 1, -0x211), store(1, 20)]
    for f3, offsets in [(2, [0]), (0, range(4)), (4, range(4)), (1, [0, 2]), (5, [0, 2])]:
        memory += [ri(2, 20, offset, f3, 0x03) for offset in offsets]
    memory += [store(1, 20, 5, 0), store(1, 20, 6, 1), ri(3, 20, 4, 2, 0x03),
               store(3, 20, 8), ri(4, 20, 8, 2, 0x03), rr(5, 4, 3), HALT]
    yield 'loads-stores-and-load-use', memory, 0, 0
    conditions = [ri(1, 0, -1), ri(2, 0, 1), ri(3, 0, -1)]
    for f3 in (0, 1, 4, 5, 6, 7):
        for a, b in ((1, 2), (2, 1), (1, 3)):
            conditions += [branch(a, b, 12, f3), store(1, 0, 0), ri(4, 4, 1)]
    yield 'all-branch-conditions', conditions + [HALT], 0, 0
    yield 'backward-branch', [ri(1, 0, 4), ri(1, 1, -1), branch(1, 0, -4, 1), HALT], 0, 0
    yield 'redirect-overrides-stall', [ri(5, 0, 1), branch(0, 0, 12),
                                      ri(6, 5, 1), store(5, 0), HALT], 0, 0
    yield 'flush-wrong-path-trap', [branch(0, 0, 12), 0xFFFFFFFF, store(0, 0), HALT], 0, 0
    yield 'jal-jalr-links-and-odd-target', [ri(5, 0, 0), jump(1, 12), ri(5, 5, 10),
                                          jump(0, 16), ri(5, 5, 1), ri(6, 1, 1, 0, 0x67),
                                          0xFFFFFFFF, upper(7, 1, 0x17), HALT], 0, 0
    yield 'halt-drains-older-instructions', [ri(1, 0, 7), store(0, 0), HALT,
                                           store(1, 0, 4), ri(1, 0, 99)], 0, 0
    faults = [('illegal-opcode', 0xFFFFFFFF), ('ecall', 0x00000073),
              ('unsupported-mul', rr(2, 0, 0, 0, 1)),
              ('invalid-register-funct7', rr(2, 0, 0, 1, 0x20)),
              ('invalid-slli-upper-bits', ri(2, 0, 0x400, 1)),
              ('invalid-srli-upper-bits', ri(2, 0, 0x020, 5)),
              ('rv64-slli-shamt32', ri(2, 0, 32, 1)),
              ('rv64-srli-shamt32', ri(2, 0, 32, 5)),
              ('invalid-ebreak-rd', HALT | (2 << 7)),
              ('invalid-ebreak-rs1', HALT | (1 << 15)),
              ('misaligned-lw', ri(2, 0, 2, 2, 0x03)),
              ('misaligned-lh', ri(2, 0, 1, 1, 0x03)),
              ('misaligned-sw', store(1, 0, 2)), ('misaligned-sh', store(1, 0, 1, 1)),
              ('misaligned-jal', jump(1, 2)), ('misaligned-jalr', ri(2, 0, 2, 0, 0x67)),
              ('misaligned-taken-branch', branch(0, 0, 2))]
    faults += [('reserved-load-%d' % f3, ri(2, 0, 0, f3, 0x03)) for f3 in (3, 6, 7)]
    faults += [('reserved-store-%d' % f3, store(1, 0, 0, f3)) for f3 in (3, 4, 5, 6, 7)]
    faults += [('reserved-branch-%d' % f3, branch(0, 0, 8, f3)) for f3 in (2, 3)]
    faults += [('reserved-jalr-%d' % f3, ri(2, 0, 16, f3, 0x67)) for f3 in range(1, 8)]
    for name, fault in faults:
        yield name, [ri(1, 0, 17), store(0, 0), fault, store(1, 0, 4), HALT], 0, 0
    yield 'untaken-misaligned-branch', [ri(1, 0, 1), branch(1, 0, 2), HALT], 0, 0
    yield 'nonzero-reset-address', [upper(1, 1, 0x17), jump(2, 8), 0xFFFFFFFF, HALT], 64, 0
    for reset_after in (1, 2, 3, 4, 12):
        yield 'reset-in-flight-%d' % reset_after, [ri(1, 0, 17), store(0, 0),
                                                  ri(2, 0, 29), ri(3, 0, 35), HALT], 0, reset_after
    for seed in range(8):
        rng = random.Random(seed)
        program = [ri(20, 0, 256)] + [ri(rd, 0, rng.randrange(-2048, 2048)) for rd in range(1, 16)]
        for _ in range(180):
            rd, a, b = (rng.randrange(1, 16) for _ in range(3))
            f3 = rng.randrange(8)
            kind = rng.randrange(6)
            if kind == 0:
                f7 = rng.choice((0, 0x20)) if f3 in (0, 5) else 0
                program.append(rr(rd, a, b, f3, f7))
            elif kind == 1:
                imm = rng.randrange(-2048, 2048)
                if f3 in (1, 5):
                    imm = rng.randrange(32) | (rng.choice((0, 0x400)) if f3 == 5 else 0)
                program.append(ri(rd, a, imm, f3))
            elif kind == 2:
                program.append(upper(rd, rng.randrange(0x100000), rng.choice((0x37, 0x17))))
            elif kind == 3:
                f3 = rng.choice((0, 1, 2))
                program.append(store(b, 20, rng.randrange(16) * (1 << f3), f3))
            elif kind == 4:
                f3 = rng.choice((0, 1, 2, 4, 5))
                program.append(ri(rd, 20, rng.randrange(16) * (1 << (f3 & 3)), f3, 0x03))
            else:
                program += [branch(a, b, 8, rng.choice((0, 1, 4, 5, 6, 7))), ri(rd, a, 1)]
        yield 'random-%d' % seed, program + [HALT], 0, 0
    for path in sorted((ROOT / 'tests/asm').glob('*.hex')):
        data = path.read_bytes()
        words = [int.from_bytes(data[n:n + 4], 'little') for n in range(0, len(data), 4)]
        yield 'assembly-' + path.stem, words, 0, 0


def run(command):
    result = subprocess.run([str(arg) for arg in command], text=True, capture_output=True, timeout=60)
    if result.returncode:
        raise AssertionError('%s\n%s%s' % (' '.join(map(str, command)), result.stdout, result.stderr))
    return result.stdout


def parse_word(value):
    # Unused retirement fields (for example a faulting load's result) may
    # contain X. Required fields must still compare equal to a known value.
    return None if any(char in value.lower() for char in 'xz') else int(value, 16)


def check_decoder(directory):
    vectors = []
    # Sweep every funct7/funct3 combination, including non-shift immediates
    # whose upper bits are data and must never be mistaken for funct7.
    for f7 in range(128):
        for f3 in range(8):
            vectors += [rr(5, 1, 2, f3, f7), ri(5, 1, (f7 << 5) | 31, f3)]
    for f3 in range(8):
        vectors += [ri(5, 1, 0, f3, 0x03), store(2, 1, 0, f3),
                    branch(1, 2, 8, f3), ri(5, 1, 0, f3, 0x67)]
    vectors += list(range(128))
    vectors += [0x00000073, HALT, HALT | (1 << 7), HALT | (1 << 15)]
    vectors += [ri(5, 1, -1), ri(5, 1, -2048), upper(5, 0xFFFFF),
                upper(5, 0xFFFFF, 0x17), jump(5, -4)]
    vector_file = directory / 'decoder-vectors.mem'
    vector_file.write_text(''.join('%09x\n' % ((int(not supported(inst)) << 32) | inst)
                                   for inst in vectors))
    binary = directory / 'decoder_tb'
    run(['iverilog', '-g2012', '-s', 'decoder_tb', '-o', binary,
         ROOT / 'decoder.v', ROOT / 'tb/decoder_tb.sv'])
    output = run(['vvp', binary, '+VECTORS=' + str(vector_file), '+COUNT=%d' % len(vectors)])
    assert 'PASS:' in output, 'decoder sweep did not finish'
    print(output.splitlines()[0])


def main():
    if not all(shutil.which(tool) for tool in ('iverilog', 'vvp')):
        raise SystemExit('Install Icarus Verilog (iverilog and vvp) to run these tests.')
    sources = [ROOT / name for name in ('hart.v', 'PC_reg.v', 'rf.v', 'decoder.v', 'imm.v', 'alu.v')]
    sources += sorted((ROOT / 'pipeline_registers').glob('*.v'))
    sources += sorted((ROOT / 'stages').glob('*.v'))
    total = retired = 0
    with tempfile.TemporaryDirectory(prefix='riscvcpu-pipeline-') as directory:
        directory = Path(directory)
        check_decoder(directory)
        binaries = {}
        for name, program, reset_addr, reset_after in cases():
            if reset_addr not in binaries:
                binary = directory / ('pipeline-%d' % reset_addr)
                run(['iverilog', '-g2012', '-s', 'pipeline_tb',
                     '-Ppipeline_tb.RESET_ADDR=%d' % reset_addr,
                     '-o', binary, *sources, ROOT / 'tb/pipeline_tb.sv'])
                binaries[reset_addr] = binary
            words = [NOP] * (reset_addr // 4) + program
            words += [NOP] * (4096 - len(words))
            expected, expected_bus, registers = reference(words, reset_addr)
            path = directory / (name + '.mem')
            path.write_text(''.join('%08x\n' % word for word in words))
            output = run(['vvp', binaries[reset_addr], '+PROGRAM=' + str(path),
                          '+RESET_AFTER=%d' % reset_after])
            actual, bus, cycles = [], [], []
            for line in output.splitlines():
                fields = line.split()
                if fields[0] == 'RET':
                    cycles.append(int(fields[1]))
                    actual.append(tuple(parse_word(value) for value in fields[2:]))
                elif fields[0] == 'BUS':
                    bus.append(tuple(parse_word(value) for value in fields[1:]))
            assert 'DONE ' in output, name + ': did not drain after halt/trap'
            assert len(actual) == len(expected), '%s: retired %d, expected %d' % (name, len(actual), len(expected))
            labels = ('pc', 'inst', 'trap', 'halt', 'rs1_addr', 'rs1_data',
                      'rs2_addr', 'rs2_data', 'rd_addr', 'rd_data', 'next_pc')
            for index, (observed, wanted) in enumerate(zip(actual, expected)):
                for label, got, want in zip(labels, observed, wanted):
                    assert want is None or got == want, (
                        '%s instruction %d pc=%08x: %s=%s, expected %08x' %
                        (name, index, wanted[0], label, hex(got) if got is not None else 'X', want))
            assert len(bus) == len(expected_bus), name + ': incorrect memory access count'
            for observed, wanted in zip(bus, expected_bus):
                assert observed[:4] == wanted[:4], name + ': incorrect memory request'
                if wanted[1]:
                    mask = sum(255 << (lane * 8) for lane in range(4) if wanted[3] & (1 << lane))
                    assert observed[4] & mask == wanted[4] & mask, name + ': incorrect store data'
            if name == 'independent-throughput':
                assert cycles[0] == 5, 'incorrect pipeline fill latency'
                assert all(b == a + 1 for a, b in zip(cycles, cycles[1:])), 'unnecessary stalls'
            if name.startswith('assembly-'):
                assert registers[10] == 1, name + ': assembly program reached fail label'
            print('PASS: %s (%d retired)' % (name, len(actual)))
            total += 1
            retired += len(actual)
    print('PASS: %d programs, %d retired instructions matched the reference model' % (total, retired))


if __name__ == '__main__':
    main()
