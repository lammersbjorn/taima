#!/usr/bin/env python3
"""Cheap structural checks. Does not claim Kotlin or Swift compilation."""
from pathlib import Path
import ast
import re
import subprocess
import xml.etree.ElementTree as ET

root = Path(__file__).resolve().parents[2]
main = root / 'android/app/src/main'
names = set()
for file in main.glob('res/**/*.xml'):
    assert not re.search(r"@(?:android:)?(?:string|plurals|drawable|xml)\.", file.read_text()), file
    tree = ET.parse(file)
    if file.parent.name == 'values':
        names.update((child.tag, child.attrib['name']) for child in tree.getroot())
for folder in ['values', 'values-nl']:
    seen = set()
    for file in (main / 'res' / folder).glob('*.xml'):
        for child in ET.parse(file).getroot():
            item = (child.tag, child.attrib['name'])
            assert item not in seen, (file, item)
            seen.add(item)
for file in main.glob('java/**/*.kt'):
    for kind, name in re.findall(r'R\.(string|plurals)\.(\w+)', file.read_text()):
        assert (kind, name) in names, (file, kind, name)
    assert 'import nl.taima.core' not in file.read_text(), file
ast.parse((root / 'scripts/release.py').read_text())
subprocess.run(['bash', '-n', 'scripts/build-apk.sh', 'scripts/android/swift-build.sh', 'scripts/android/package-jni.sh', 'scripts/android/verify-local.sh'], cwd=root, check=True)
subprocess.run(['git', 'diff', '--check'], cwd=root, check=True)
print('XML, resource identifiers, shipping dependency imports, release syntax and diff whitespace passed.')
