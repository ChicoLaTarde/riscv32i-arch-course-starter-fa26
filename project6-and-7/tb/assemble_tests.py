from pathlib import Path
import subprocess
import sys
import tempfile
import zipfile


ROOT = Path(__file__).resolve().parents[1]
prefix = sys.argv[1] if len(sys.argv) > 1 else 'riscv64-unknown-elf-'
count = 0
with tempfile.TemporaryDirectory(prefix='ece552-assembly-') as temporary:
    directory = Path(temporary)
    for path in sorted((ROOT / 'tests/asm').glob('*.zip')):
        with zipfile.ZipFile(path) as archive:
            for name in archive.namelist():
                if Path(name).suffix != '.asm':
                    continue
                source = directory / Path(name).name
                source.write_bytes(archive.read(name))
                subprocess.run([prefix + 'as', '-march=rv32i', '-mabi=ilp32',
                                source, '-o', source.with_suffix('.o')], check=True)
                subprocess.run([prefix + 'objcopy', '-O', 'binary', '-j', '.text',
                                source.with_suffix('.o'),
                                ROOT / 'tests/asm' / source.with_suffix('.hex').name], check=True)
                count += 1
print('Assembled %d official programs' % count)
