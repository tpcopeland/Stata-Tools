#!/usr/bin/env python3
"""Validate a tabtools permanent profile across two serial Stata processes."""

from __future__ import annotations

import argparse
import shutil
import subprocess
from pathlib import Path


def stata_quote(value: str) -> str:
    return value.replace('"', '""')


def run_stata(stata: str, cwd: Path, do_file: Path) -> subprocess.CompletedProcess[bytes]:
    return subprocess.run(
        [stata, "-b", "do", do_file.name],
        cwd=cwd,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.STDOUT,
        timeout=240,
        check=False,
    )


def log_has(path: Path, marker: str) -> bool:
    if not path.exists():
        return False
    return marker in path.read_text(encoding="utf-8", errors="replace")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--package-dir", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--stata", default="stata-mp")
    args = parser.parse_args()

    if shutil.which(args.stata) is None:
        print(f"Stata executable not found: {args.stata}")
        return 127

    package_dir = args.package_dir.resolve()
    output_dir = args.output_dir.resolve()
    plus_dir = output_dir / "plus"
    personal_dir = output_dir / "personal"
    output_dir.mkdir(parents=True, exist_ok=True)
    plus_dir.mkdir(exist_ok=True)
    personal_dir.mkdir(exist_ok=True)

    phase1 = output_dir / "profile_phase1.do"
    phase2 = output_dir / "profile_phase2.do"
    phase1_marker = output_dir / "phase1.ok"
    phase2_marker = output_dir / "phase2.ok"

    phase1.write_text(
        f"""clear all
set more off
set varabbrev off
version 17.0
sysdir set PLUS "{stata_quote(str(plus_dir))}"
sysdir set PERSONAL "{stata_quote(str(personal_dir))}"
discard
quietly net install tabtools, from("{stata_quote(str(package_dir))}") replace
tabtools set clear
tabtools set theme custom, font("Times New Roman") fontsize(11) headercolor("200 220 240") zebracolor("245 245 245") borderstyle(academic) permanent
tabtools set digits 3, permanent
tabtools set boldp 0.025, permanent
confirm file "{stata_quote(str(personal_dir / "tabtools_profile.do"))}"
file open m using "{stata_quote(str(phase1_marker))}", write text replace
file write m "created" _n
file close m
display "RESULT: profile_phase1 tests=1 pass=1 fail=0"
exit 0
""",
        encoding="utf-8",
    )

    phase2.write_text(
        f"""clear all
set more off
set varabbrev off
version 17.0
sysdir set PLUS "{stata_quote(str(plus_dir))}"
sysdir set PERSONAL "{stata_quote(str(personal_dir))}"
discard
tabtools use
assert "$TABTOOLS_THEME" == "custom"
assert "$TABTOOLS_FONT" == "Times New Roman"
assert "$TABTOOLS_FONTSIZE" == "11"
assert "$TABTOOLS_HEADERCOLOR" == "200 220 240"
assert "$TABTOOLS_ZEBRACOLOR" == "245 245 245"
assert "$TABTOOLS_BORDER" == "academic"
assert "$TABTOOLS_DIGITS" == "3"
assert "$TABTOOLS_BOLDP" == "0.025"
file open m using "{stata_quote(str(phase2_marker))}", write text replace
file write m "loaded" _n
file close m
display "RESULT: profile_phase2 tests=1 pass=1 fail=0"
exit 0
""",
        encoding="utf-8",
    )

    phase1_run = run_stata(args.stata, output_dir, phase1)
    phase1_ok = (
        phase1_run.returncode == 0
        and phase1_marker.exists()
        and log_has(output_dir / "profile_phase1.log", "RESULT: profile_phase1 tests=1 pass=1 fail=0")
    )
    if not phase1_ok:
        print("RESULT: tabtools_profile_restart tests=1 pass=0 fail=1 phase=1")
        return 1

    phase2_run = run_stata(args.stata, output_dir, phase2)
    phase2_ok = (
        phase2_run.returncode == 0
        and phase2_marker.exists()
        and log_has(output_dir / "profile_phase2.log", "RESULT: profile_phase2 tests=1 pass=1 fail=0")
    )
    if not phase2_ok:
        print("RESULT: tabtools_profile_restart tests=1 pass=0 fail=1 phase=2")
        return 1

    print("RESULT: tabtools_profile_restart tests=1 pass=1 fail=0")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
