#!/usr/bin/env python3
"""Keep Android's historical highlights verbatim with the iPhone release list."""
import json
import re
from pathlib import Path
root = Path(__file__).resolve().parents[2]
source = (root / 'App/Taima/Onboarding.swift').read_text()
releases = []
for match in re.finditer(r'ReleaseHighlights\(build: (\d+), items: \[(.*?)\n        \]\)', source, re.S):
    items = []
    for item in re.finditer(r'title: String\(localized: ("(?:\\.|[^"\\])*")\), detail: String\(localized: ("(?:\\.|[^"\\])*")\)', match[2]):
        items.append({'title': json.loads(item[1]), 'detail': json.loads(item[2])})
    assert items, match[1]
    releases.append({'build': int(match[1]), 'items': items})
assert releases and len({r["build"] for r in releases}) == len(releases)
(root / 'android/app/src/main/assets/release-highlights.json').write_text(json.dumps(releases, ensure_ascii=False, indent=2) + '\n')
