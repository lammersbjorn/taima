#!/usr/bin/env python3
"""Retain the ELF dependency closure of the trial JNI entry points."""
from pathlib import Path
import re
import subprocess
import sys

folder = Path(sys.argv[1])
reader = Path.home() / 'Library/Android/sdk/ndk/28.2.13676358/toolchains/llvm/prebuilt/darwin-x86_64/bin/llvm-readelf'
roots = ['libtaimajni.so', 'libTaimaGenerated.so', 'libSwiftJava.so']
needed = set()
pending = [name for name in roots if (folder / name).exists()]
while pending:
    name = pending.pop()
    if name in needed:
        continue
    needed.add(name)
    output = subprocess.check_output([str(reader), '-d', str(folder / name)], text=True)
    pending += [dep for dep in re.findall(r'\(NEEDED\).*?\[(.*?)\]', output)
                if dep not in needed and (folder / dep).exists()]
for library in folder.glob('*.so'):
    if library.name not in needed:
        library.unlink()
print(f'{folder.name}: {len(needed)} libraries, {sum((folder / n).stat().st_size for n in needed)} bytes')
