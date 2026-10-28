#!/usr/bin/env python3
"""Builds App/Taima/Resources/strains.json from the Kushy cannabis dataset.

Source: https://github.com/kushyapp/cannabis-dataset (MIT, 2017-11-14 export).
Usage: scripts/build-strain-db.py <strains-kushy_api.csv>

Kept: name, type, breeder, effects, flavours and terpenes. Dropped:
descriptions (unclear provenance), ailments (medical claims), cannabinoid
numbers (inconsistent units) and crosses: the export's cross ids point at
the wrong strains (Super Silver Haze resolves to "Nuggetry OG x Skydog"), so
lineage and aliases come from the curated strains-curated.json instead.
"""
import csv, json, re, sys

NEGATIVE = {"dry mouth", "dry eyes", "paranoid", "anxious", "dizzy", "headache"}

def clean(value):
    value = (value or "").strip()
    return "" if value in ("", "NULL", "0") else value

def tags(value):
    out = []
    for tag in clean(value).split(","):
        tag = tag.strip()
        if tag and tag.lower() not in (t.lower() for t in out):
            out.append(tag)
    return out

def key(name):
    return " ".join(re.sub(r"[^a-z0-9]+", " ", name.lower()).split())

rows = list(csv.DictReader(open(sys.argv[1], encoding="utf-8", errors="replace")))
by_id = {r["id"]: r for r in rows}
strains = {}
for r in rows:
    name = clean(r["name"])
    if not name or len(name) > 60:
        continue
    kind = clean(r["type"])
    kind = kind if kind in ("Indica", "Sativa", "Hybrid") else None
    effects = tags(r["effects"])
    entry = {
        "n": name,
        "t": kind,
        "b": clean(r["breeder"]) if clean(r["breeder"]).lower() not in ("unknown breeder", "unknown") else "",
        "e": [e for e in effects if e.lower() not in NEGATIVE],
        "d": [e for e in effects if e.lower() in NEGATIVE],
        "f": tags(r["flavor"]),
        "tp": tags(r["terpenes"]),
    }
    entry = {k: v for k, v in entry.items() if v}
    k = key(name)
    # Duplicate names: keep the record with the most data.
    if k not in strains or len(json.dumps(entry)) > len(json.dumps(strains[k])):
        strains[k] = entry

out = sorted(strains.values(), key=lambda s: s["n"].lower())
json.dump({"source": "Kushy cannabis dataset (MIT), export 2017-11-14", "strains": out},
          open("App/Taima/Resources/strains.json", "w"), ensure_ascii=False, separators=(",", ":"))
print(len(out), "strains")
