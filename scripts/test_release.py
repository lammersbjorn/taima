#!/usr/bin/env python3
"""Exercise release preparation in an isolated synthetic checkout, without gh."""
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]

class ReleaseTest(unittest.TestCase):
    def test_both_assets_and_android_notes(self):
        with tempfile.TemporaryDirectory(prefix='taima-release-test-') as tmp:
            work = Path(tmp)
            for relative in ['scripts/release.py', 'project.yml', 'App/Taima/Onboarding.swift', 'sidestore/source.json']:
                destination = work / relative
                destination.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(ROOT / relative, destination)
            ipa = work / 'synthetic.ipa'
            apk = work / 'synthetic.apk'
            ipa.write_bytes(b'synthetic-ipa')
            apk.write_bytes(b'synthetic-apk')
            run = subprocess.run([sys.executable, str(work / 'scripts/release.py'), str(ipa), '--apk', str(apk)], capture_output=True, text=True, check=True)
            command = run.stdout.splitlines()[-1]
            self.assertIn('.ipa', command)
            self.assertIn('.apk', command)
            self.assertIn('gh release create', command)
            notes = next((work / 'build').glob('release-notes-*.md')).read_text()
            self.assertIn('Android:', notes)
            self.assertIn('Obtainium', notes)
            source = json.loads((work / 'sidestore/source.json').read_text())
            self.assertTrue(source['apps'][0]['downloadURL'].endswith('.ipa'))
            self.assertEqual(source['apps'][0]['size'], len(b'synthetic-ipa'))

if __name__ == '__main__':
    unittest.main()
