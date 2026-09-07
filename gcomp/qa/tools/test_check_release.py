#!/usr/bin/env python3
"""Regression checks for release metadata in full and isolated checkouts.

Run: python3 -m unittest discover -s qa/tools -p test_check_release.py
Author: Timothy P Copeland, Karolinska Institutet
Date: 2026-09-07
"""
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import unittest


class ReleaseMetadataTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="gcomp-release-test-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        source = Path(__file__).resolve().parents[2]
        self.package = self.root / "gcomp"
        shutil.copytree(source, self.package,
                        ignore=shutil.ignore_patterns("*.log", "*.smcl", "__pycache__"))
        self.result = self.root / "result.txt"

    def run_checker(self, *args):
        self.result.unlink(missing_ok=True)
        proc = subprocess.run(
            [sys.executable, str(self.package / "qa/tools/check_release.py"),
             str(self.package), "--result-file", str(self.result), *args],
            capture_output=True, text=True)
        self.assertTrue(self.result.is_file(), proc.stderr)
        self.assertEqual(self.result.read_text().strip(), "PASS" if proc.returncode == 0 else "FAIL")
        return proc

    def test_isolated_checkout_evaluates_package_contracts(self):
        proc = self.run_checker()
        self.assertEqual(proc.returncode, 0, proc.stdout + proc.stderr)
        self.assertIn("NOT APPLICABLE: repository badges", proc.stdout)
        toc = self.package / "stata.toc"
        toc.write_text(toc.read_text().replace("p gcomp", "p wrong"))
        proc = self.run_checker()
        self.assertEqual(proc.returncode, 1)
        self.assertIn("stata.toc does not match", proc.stdout)

    def test_full_checkout_checks_badges(self):
        header = (self.package / "gcomp.ado").read_text().splitlines()[0]
        version, year, month, day = re.search(
            r"Version\s+([0-9.]+)\s+(\d{4})/(\d{2})/(\d{2})", header).groups()
        readme = self.root / "README.md"
        readme.write_text(f"[gcomp](gcomp/) version-{version}-blue updated-{year}--{month}--{day}-brightgreen\n")
        proc = self.run_checker("--require-root-readme")
        self.assertEqual(proc.returncode, 0, proc.stdout)
        readme.write_text("[gcomp](gcomp/) version-0.0.0-blue\n")
        proc = self.run_checker()
        self.assertEqual(proc.returncode, 1)
        self.assertIn("top-level gcomp badges differ", proc.stdout)

    def test_full_release_requires_root_readme_when_requested(self):
        proc = self.run_checker("--require-root-readme")
        self.assertEqual(proc.returncode, 1)
        self.assertIn("repository-root README.md is required but missing", proc.stdout)


if __name__ == "__main__":
    unittest.main()
