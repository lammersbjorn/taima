#!/usr/bin/env python3
"""Check catalog completeness and typed placeholders. Run locally; Taima has no CI."""
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parent.parent
CATALOGS = [
    ROOT / "App/Taima/Localizable.xcstrings",
    ROOT / "App/Taima/InfoPlist.xcstrings",
    ROOT / "App/Taima/AppShortcuts.xcstrings",
    ROOT / "App/TaimaWidgets/Localizable.xcstrings",
    ROOT / "Packages/TaimaCore/Sources/TaimaCore/Resources/Localizable.xcstrings",
]
FORMAT = re.compile(r"%%|%(?:(\d+)\$)?(@|lld|ld|d|llu|lu|u|lf|f)")


def arguments(value):
    result = {}
    index = 0
    for match in FORMAT.finditer(value):
        if match[0] == "%%":
            continue
        index += 1
        result[int(match[1] or index)] = match[2]
    return result


def check_localization(localization, expected, label):
    substitutions = localization.get("substitutions", {})
    if not substitutions:
        value = localization["stringUnit"]
        assert value["state"] == "translated", f"Untranslated: {label}"
        assert arguments(value["value"]) == expected, f"Placeholder mismatch: {label}"
        return
    for substitution in substitutions.values():
        count = substitution["argNum"]
        assert expected[count] == substitution["formatSpecifier"], f"Wrong plural argument: {label}"
        variants = substitution["variations"]["plural"]
        assert {"one", "other"} <= variants.keys(), f"Missing plural variant: {label}"
        for category, variant in variants.items():
            unit = variant["stringUnit"]
            assert unit["state"] == "translated", f"Untranslated plural: {label}"
            actual = arguments(unit["value"])
            # 'Once' and the unit below a visible count intentionally omit its digits.
            fragment_matches = len(substitutions) > 1 and all(
                expected.get(k) == v for k, v in actual.items()
            )
            without_count = {k: v for k, v in expected.items() if k != count}
            assert fragment_matches or actual == expected or actual == without_count, (
                f"Plural placeholder mismatch ({category}): {label}"
            )


def main():
    total = 0
    for path in CATALOGS:
        catalog = json.loads(path.read_text())
        assert catalog["sourceLanguage"] == "en", f"Development language: {path}"
        for key, entry in catalog["strings"].items():
            label = f"{path.relative_to(ROOT)}: {key}"
            assert entry.get("extractionState") != "stale", f"Stale: {label}"
            localizations = entry["localizations"]
            assert {"en", "nl"} <= localizations.keys(), f"Missing language: {label}"
            english = localizations["en"]
            source = english["stringUnit"]["value"] if "substitutions" not in english else key
            expected = {1: "lld"} if key == "break.days.unit" else arguments(source)
            for language in ("en", "nl"):
                check_localization(localizations[language], expected, f"{label} [{language}]")
                if path.stem == "AppShortcuts":
                    value = localizations[language]["stringUnit"]["value"]
                    assert value.count("${applicationName}") == 1, f"Siri app placeholder: {label}"
        total += len(catalog["strings"])
        print(f"{path.relative_to(ROOT)}: {len(catalog['strings'])} entries OK")
    print(f"{total} entries checked in English and Dutch.")


if __name__ == "__main__":
    main()
