"""Regression checks for validation failures that would break catalogue identity.

Run: python3 -m unittest discover -s scripts -p 'test_validate_strains.py'
"""

from contextlib import redirect_stdout, redirect_stderr
from copy import deepcopy
import importlib.util
from io import StringIO
from pathlib import Path
import unittest

SPEC = importlib.util.spec_from_file_location("validate_strains", Path(__file__).with_name("validate-strains.py"))
validator = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(validator)


class ValidationTests(unittest.TestCase):
    def setUp(self):
        self.curated = {"source": "test", "strains": [
            {"n": "Snow White", "t": "Hybrid", "a": ["Sneeuwwitje"], "p": ["Unresolved parent", "Old Name"], "src": ["breeder"]},
            {"n": "Other", "t": "Indica", "a": ["Old Name"], "src": ["breeder"]},
        ]}
        self.community = {"source": "MIT test", "strains": [{"n": "Sneeuwwitje", "t": "Hybrid"}]}
        self.sources = "| `breeder` | Breeder | https://example.com |\n"
        self.catalog = 'static let generic: Set<String> = ["kush", "amnesia"]'

    def check(self):
        output = StringIO()
        with redirect_stdout(output), redirect_stderr(output):
            passed = validator.validate(self.curated, self.community, self.sources, self.catalog)
        return passed, output.getvalue()

    def test_alias_can_replace_community_and_unresolved_parent_is_informational(self):
        passed, output = self.check()
        self.assertTrue(passed, output)
        self.assertIn("1/2 (50.0%)", output)

    def test_normalized_alias_collides_with_another_curated_name(self):
        self.curated["strains"][1]["a"] = ["SNÓW-WHITE"]
        self.assertFalse(self.check()[0])

    def test_same_normalized_name_on_distinct_entries_is_rejected(self):
        self.curated["strains"].append(deepcopy(self.curated["strains"][0]))
        self.assertFalse(self.check()[0])

    def test_generic_alias_is_rejected(self):
        self.curated["strains"][0]["a"] = ["Küsh"]
        self.assertFalse(self.check()[0])

    def test_undefined_source_is_rejected(self):
        self.curated["strains"][0]["src"] = ["missing"]
        self.assertFalse(self.check()[0])

    def test_schema_errors_fail_without_crashing(self):
        for field, value in [("src", "breeder"), ("p", [12]), ("a", None), ("r", 1), ("t", "Mixed"), ("n", []), ("src", [])]:
            with self.subTest(field=field, value=value):
                entry = deepcopy(self.curated["strains"][0])
                self.curated["strains"][0][field] = value
                self.assertFalse(self.check()[0])
                self.curated["strains"][0] = entry

    def test_missing_source_and_unknown_fields_are_rejected(self):
        del self.curated["strains"][0]["src"]
        self.curated["strains"][0]["description"] = "Not permitted"
        self.assertFalse(self.check()[0])

    def test_unreadable_generic_registry_is_rejected(self):
        self.catalog = "changed format"
        self.assertFalse(self.check()[0])

    def test_duplicate_sources_and_self_parent_are_rejected(self):
        self.sources *= 2
        self.curated["strains"][0]["p"] = ["Sneeuwwitje"]
        self.assertFalse(self.check()[0])


if __name__ == "__main__":
    unittest.main()
