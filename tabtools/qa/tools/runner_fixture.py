#!/usr/bin/env python3
# Version: 1.0.0 2026/10/01
# Author: Timothy P Copeland, Karolinska Institutet
"""Build a controlled child for the runner regression, never a source patch."""
import sys

def make_child(case, directory):
    from pathlib import Path
    if case == "restore":
        Path(directory).chmod(0o700)
        return
    receipts = {
        "good": ["RESULT: test_child tests=1 pass=1 fail=0"],
        "wrap": ["RESULT: test_child tests=12 pass=12 fail=0 skip=0"],
        "wrapnumber": ["RESULT: test_child tests=12345678901234567890 pass=12345678901234567890 fail=0"],
        "mismatch": ["RESULT: test_child tests=10 pass=1 fail=0"],
        "failed": ["RESULT: test_child tests=1 pass=0 fail=1"],
        "missing": [],
        "empty": ["RESULT: test_child tests=0 pass=0 fail=0"],
        "duplicate": ["RESULT: test_child tests=1 pass=1 fail=0"] * 2,
        "wrongname": ["RESULT: different_child tests=1 pass=1 fail=0"],
        "skipfull": ["RESULT: test_child tests=2 pass=1 fail=0 skip=1"],
        "skipquick": ["RESULT: test_child tests=2 pass=1 fail=0 skip=1"],
        "badrc": ["RESULT: test_child tests=1 pass=1 fail=0"],
        "screen": ["RESULT: test_child tests=1 pass=1 fail=0"],
        "core": ["RESULT: test_child tests=1 pass=1 fail=0"],
        "stale": [],
    }
    name = "test_review_2026_10_01_runner_receipt"
    lines = ['capture log close _child_fixture',
             f'log using "{name}.log", text replace name(_child_fixture)']
    if case in ("wrap", "wrapnumber"):
        lines.append("set linesize 40")
    lines += ['display "' + receipt.replace("test_child", name) + '"' for receipt in receipts[case]]
    lines += ['log close _child_fixture', 'set linesize 255']
    if case == "badrc":
        lines.append("exit 459")
    if case == "screen":
        lines = ['display "' + receipt.replace("test_child", name) + '"' for receipt in receipts[case]]
    if case == "stale":
        lines = ['local no_receipt = 1']
    child = Path(directory) / (name + ".do")
    child.write_text("\n".join(lines) + "\n")
    if case == "stale":
        child.with_suffix(".log").write_text(f"RESULT: {name} tests=1 pass=1 fail=0\n")
        Path(directory).chmod(0o500)


if __name__ == "__main__":
    make_child(*sys.argv[1:])
