#!/usr/bin/env python3
"""Adds a built IPA to the SideStore source and prepares a GitHub release.

Usage: scripts/release.py build/Taima-<version>-<sha>.ipa
Reads the version and build from project.yml and the release notes from
the What's New entry for that build (App/Taima/Onboarding.swift). Writes
sidestore/source.json and prints the `gh release create` command; it
does not push or publish anything itself.
"""
import datetime, json, os, re, subprocess, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REPO = "lammersbjorn/taima"
ipa = os.path.abspath(sys.argv[1])
project = open(os.path.join(ROOT, "project.yml")).read()
version = re.search(r'MARKETING_VERSION: "([^"]+)"', project).group(1)
build = re.search(r'CURRENT_PROJECT_VERSION: "([^"]+)"', project).group(1)

onboarding = open(os.path.join(ROOT, "App/Taima/Onboarding.swift")).read()
block = re.search(r"ReleaseHighlights\(build: %s, items: \[(.*?)\]\)" % build, onboarding, re.S)
notes = []
if block:
    # Items are written as plain strings or as String(localized: "…").
    item = r'title: (?:String\(localized: )?"([^"]+)"\)?, detail: (?:String\(localized: )?"((?:[^"\\]|\\.)+)"\)?'
    for title, detail in re.findall(item, block.group(1)):
        detail = detail.replace('\\"', '"')
        notes.append(f"• {title}: {detail}")
description = "\n".join(notes) or f"Taima {version}"

tag = f"v{version}"
asset = f"Taima-{version}.ipa"
source_path = os.path.join(ROOT, "sidestore/source.json")
source = json.load(open(source_path))
app = source["apps"][0]
app["versions"] = [v for v in app["versions"] if v["buildVersion"] != build]
app["versions"].insert(0, {
    "version": version,
    "buildVersion": build,
    "date": datetime.date.today().isoformat(),
    "localizedDescription": description,
    "downloadURL": f"https://github.com/{REPO}/releases/download/{tag}/{asset}",
    "size": os.path.getsize(ipa),
    "minOSVersion": "26.0",
})
# Older SideStore and AltStore builds read the newest version from these
# top-level fields instead of the versions list.
latest = app["versions"][0]
app.update({
    "version": latest["version"],
    "buildVersion": latest["buildVersion"],
    "versionDate": latest["date"],
    "versionDescription": latest["localizedDescription"],
    "downloadURL": latest["downloadURL"],
    "size": latest["size"],
})
json.dump(source, open(source_path, "w"), indent=2, ensure_ascii=False)
notes_path = os.path.join(ROOT, "build", f"release-notes-{version}.md")
open(notes_path, "w").write(description + "\n\nInstall with SideStore (add the source) or iloader. Install over the existing app; your data stays.\n")
print(f"Updated sidestore/source.json for {version} ({build}).")
print("Next, after committing source.json and pushing:")
print(f'  cp "{ipa}" "build/{asset}"')
print(f'  gh release create {tag} "build/{asset}" --title "Taima {version}" --notes-file "{notes_path}"')
