#!/usr/bin/env python3
"""Derive Android static core UI resources from the maintained iOS catalogues.

Plural counts are structured API data and use hand-maintained Android plurals.
Party written cards are bilingual domain content, not localized UI templates.
"""
from pathlib import Path
import hashlib
import html
import json

root = Path(__file__).resolve().parents[2]
entries = {}
for source in ['Packages/TaimaCore/Sources/TaimaCore/Resources/Localizable.xcstrings', 'App/Taima/Localizable.xcstrings']:
    for key, value in json.loads((root / source).read_text())['strings'].items():
        if '%' not in key:
            entries[key] = value.get('localizations', {}).get('nl', {}).get('stringUnit', {}).get('value', key)
for language in ['', '-nl']:
    lines = ['<resources>']
    for key, dutch in sorted(entries.items()):
        name = 'core_' + hashlib.sha256(key.encode()).hexdigest()[:16]
        text = html.escape(dutch if language else key, quote=False).replace("'", "\\'").replace('"', '\\"').replace('\n', '\\n')
        lines.append(f'<string name="{name}" formatted="false">{text}</string>')
    lines.append('</resources>')
    (root / f'android/app/src/main/res/values{language}/core_strings.xml').write_text('\n'.join(lines) + '\n')
