#!/usr/bin/env python3
"""Publishes the strain library for in-app updates.

Copies the bundled library files into catalog/v1/ with a manifest of
SHA-256 checksums, and bumps the version both there and in the app bundle
(App/Taima/Resources/catalog-version.json) so new builds ship it too.

Usage: scripts/publish-library.py [--minimum-build N]
Run scripts/validate-strains.py first when it exists.
"""
import argparse, datetime, hashlib, json, os, shutil, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RESOURCES = os.path.join(ROOT, "App/Taima/Resources")
OUT = os.path.join(ROOT, "catalog/v1")
FILES = ["strains-curated.json", "strains.json"]

parser = argparse.ArgumentParser()
parser.add_argument("--minimum-build", type=int, default=7, help="oldest app build that reads this data")
args = parser.parse_args()

version_file = os.path.join(RESOURCES, "catalog-version.json")
version = json.load(open(version_file))["version"] + 1
os.makedirs(OUT, exist_ok=True)
entries, strains = [], 0
for name in FILES:
    data = open(os.path.join(RESOURCES, name), "rb").read()
    json.loads(data)  # refuse to publish broken JSON
    if name == "strains-curated.json" or name == "strains.json":
        strains += len(json.loads(data)["strains"])
    shutil.copyfile(os.path.join(RESOURCES, name), os.path.join(OUT, name))
    entries.append({"name": name, "sha256": hashlib.sha256(data).hexdigest(), "size": len(data)})

manifest = {
    "version": version,
    "generated": datetime.date.today().isoformat(),
    "minimumBuild": args.minimum_build,
    "strainCount": strains,
    "files": entries,
}
json.dump(manifest, open(os.path.join(OUT, "manifest.json"), "w"), indent=2)
json.dump({"version": version}, open(version_file, "w"))
print(f"Published library version {version}: {strains} entries in {OUT}")
