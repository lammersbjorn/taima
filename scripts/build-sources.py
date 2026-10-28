#!/usr/bin/env python3
"""Builds the strain source list the app shows, from the registry table in
docs/research/strain-sources.md. Run after editing that table; then
scripts/publish-library.py ships it with the library."""
import json, os, re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
doc = open(os.path.join(ROOT, "docs/research/strain-sources.md"), encoding="utf-8").read()
registry = doc.split("## Source reference registry", 1)[1]
row = re.compile(r"^\| `([^`]+)` \| ([^|]+?) \| \[[^\]]*\]\(([^)\s]+)\)", re.M)
sources = {}
for sid, record, link in row.findall(registry):
    # Links inside the document (Taima's own notes) have no web page to open.
    sources[sid] = {"record": record.strip(), **({"url": link} if link.startswith("https://") else {})}
out = os.path.join(ROOT, "App/Taima/Resources/strain-sources.json")
with open(out, "w", encoding="utf-8") as f:
    json.dump({"sources": dict(sorted(sources.items()))}, f, ensure_ascii=False, indent=1)
    f.write("\n")
print(f"{len(sources)} sources written to {os.path.relpath(out, ROOT)}")
