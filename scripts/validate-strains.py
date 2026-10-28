#!/usr/bin/env python3
"""Validate bundled strain data without dependencies or network access.

Usage: python3 scripts/validate-strains.py [--curated PATH] [--community PATH]
                                        [--sources PATH] [--catalog PATH]
Errors exit 1. Unresolved parents are informational, not errors. Curated aliases
may replace community records, just as StrainCatalog.init does.
"""

import argparse
import json
from pathlib import Path
import re
import sys
import unicodedata

ROOT = Path(__file__).resolve().parents[1]


def key(value):
    """Mirror StrainGroup.key: lowercase, fold accents, space punctuation."""
    folded = unicodedata.normalize("NFD", value.lower())
    folded = "".join(c for c in folded if unicodedata.category(c) != "Mn")
    return " ".join("".join(c if c.isalnum() else " " for c in folded).split())


def read_json(path):
    def unique_pairs(pairs):
        result = {}
        for name, value in pairs:
            if name in result:
                raise ValueError(f"duplicate JSON property {name!r}")
            result[name] = value
        return result

    return json.loads(path.read_text(encoding="utf-8"), object_pairs_hook=unique_pairs)


def validate(curated, community, source_text, catalog_text):
    errors = []
    # These are explicit reference definitions in the research document.
    source_ids = re.findall(r"^\| `([a-z0-9-]+)` \|", source_text, re.MULTILINE)
    defined = set(source_ids)
    if not defined:
        errors.append("sources: no source definitions found")
    if len(defined) != len(source_ids):
        errors.append("sources: duplicate source definitions")
    generic_match = re.search(r"static let generic: Set<String> = \[(.*?)\]", catalog_text, re.DOTALL)
    if generic_match is None:
        errors.append("catalog: cannot read StrainCatalog.generic")
        generic = set()
    else:
        generic = set(re.findall(r'"([^"\\]+)"', generic_match[1]))
        if not generic:
            errors.append("catalog: empty generic word list")

    def valid_text(value):
        return isinstance(value, str) and bool(value.strip()) and value == value.strip()

    def entries(data, label, curated_file):
        if not isinstance(data, dict) or set(data) != {"source", "strains"}:
            errors.append(f"{label}: root must contain only source and strains")
            return []
        if not valid_text(data["source"]):
            errors.append(f"{label}: source must be nonempty text")
        if not isinstance(data["strains"], list) or not data["strains"]:
            errors.append(f"{label}: strains must be a nonempty array")
            return []
        allowed = {"n", "a", "t", "lean", "p", "r", "b", "src"} if curated_file else {"n", "t", "b", "e", "d", "f", "tp"}
        required = {"n", "t", "src"} if curated_file else {"n"}
        valid = []
        for index, entry in enumerate(data["strains"]):
            at = f"{label}[{index}]"
            if not isinstance(entry, dict):
                errors.append(f"{at}: expected an object")
                continue
            if entry.keys() - allowed or required - entry.keys():
                errors.append(f"{at}: missing {sorted(required - entry.keys())}, unknown {sorted(entry.keys() - allowed)}")
            for field in ("n", "lean", "b"):
                if field in entry and not valid_text(entry[field]):
                    errors.append(f"{at}.{field}: expected nonempty trimmed text")
            if "t" in entry and entry["t"] not in ("Indica", "Sativa", "Hybrid"):
                errors.append(f"{at}.t: expected Indica, Sativa or Hybrid")
            if "r" in entry and type(entry["r"]) is not bool:
                errors.append(f"{at}.r: expected a boolean")
            for field in ("a", "p", "src", "e", "d", "f", "tp"):
                if field not in entry:
                    continue
                values = entry[field]
                if not isinstance(values, list) or not values or not all(valid_text(v) for v in values):
                    errors.append(f"{at}.{field}: expected a nonempty array of trimmed strings")
                elif len(set(values)) != len(values):
                    errors.append(f"{at}.{field}: duplicate values")
            if not valid_text(entry.get("n")) or not key(entry["n"]):
                errors.append(f"{at}.n: name must contain a letter or number")
                continue
            # Keep malformed optional fields out of subsequent identity checks.
            if any(field in entry and (not isinstance(entry[field], list) or not all(valid_text(v) for v in entry[field])) for field in ("a", "p", "src")):
                continue
            valid.append(entry)
        return valid

    curated_entries = entries(curated, "curated", True)
    community_entries = entries(community, "community", False)
    identities = {}
    for index, entry in enumerate(curated_entries):
        name = entry["n"]
        for value in [name] + entry.get("a", []):
            normalized = key(value)
            if not normalized:
                errors.append(f"{name}: empty normalized name/alias {value!r}")
            if normalized in identities and identities[normalized][0] != index:
                errors.append(f"identity collision: {value!r} in {name!r} and {identities[normalized][1]!r}")
            identities[normalized] = (index, name)
        for alias in entry.get("a", []):
            if key(alias) in generic:
                errors.append(f"{name}: alias {alias!r} collides with StrainCatalog.generic")
        for source in entry.get("src", []):
            if source not in defined:
                errors.append(f"{name}: undefined src {source!r}")
        if any(key(p) in {key(name), *(key(a) for a in entry.get('a', []))} for p in entry.get("p", [])):
            errors.append(f"{name}: cannot be its own parent")

    community_keys = {}
    for entry in community_entries:
        normalized = key(entry["n"])
        if normalized in community_keys:
            errors.append(f"community name collision: {entry['n']!r} and {community_keys[normalized]!r}")
        community_keys[normalized] = entry["n"]
    library_keys = set(identities) | set(community_keys)
    parents = [(e["n"], p) for e in curated_entries for p in e.get("p", [])]
    unresolved = [(n, p) for n, p in parents if key(p) not in library_keys]
    resolved = len(parents) - len(unresolved)
    percent = 100 * resolved / len(parents) if parents else 0
    print(f"Curated: {len(curated_entries)} strains; community: {len(community_entries)} strains; defined sources: {len(defined)}")
    print(f"Parents resolving in bundled library (names or aliases): {resolved}/{len(parents)} ({percent:.1f}%)")
    if unresolved:
        print("Unresolved parents (informational):")
        for name, parent in unresolved:
            print(f"  {name}: {parent}")
    for error in errors:
        print(f"ERROR: {error}", file=sys.stderr)
    print(f"Validation {'FAILED' if errors else 'passed'}: {len(errors)} errors")
    return not errors


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--curated", type=Path, default=ROOT / "App/Taima/Resources/strains-curated.json")
    parser.add_argument("--community", type=Path, default=ROOT / "App/Taima/Resources/strains.json")
    parser.add_argument("--sources", type=Path, default=ROOT / "docs/research/strain-sources.md")
    parser.add_argument("--catalog", type=Path, default=ROOT / "Packages/TaimaCore/Sources/TaimaCore/StrainCatalog.swift")
    args = parser.parse_args()
    try:
        passed = validate(read_json(args.curated), read_json(args.community), args.sources.read_text(encoding="utf-8"), args.catalog.read_text(encoding="utf-8"))
    except (OSError, ValueError) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return 1
    return 0 if passed else 1


if __name__ == "__main__":
    sys.exit(main())
