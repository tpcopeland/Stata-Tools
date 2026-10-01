#!/usr/bin/env python3
# Version: 1.0.0 2026/10/01
# Author: Timothy P Copeland, Karolinska Institutet
"""Build controlled children and isolate their intentional runner failures."""
import sys


def execute_runner(directory, arguments, binary):
    from pathlib import Path
    import re
    import subprocess
    import tempfile
    from sfi import Macro

    if arguments not in {"full", "quick", "core", "unknown", "full unexpected"}:
        raise ValueError("unexpected runner fixture arguments")
    qa = Path(directory).resolve()
    work = Path(tempfile.mkdtemp(prefix="runner-", dir=qa.parent))
    status = work / "driver_status.txt"
    initial_plus = work / "initial_plus"
    initial_personal = work / "initial_personal"
    initial_plus.mkdir()
    initial_personal.mkdir()
    # Batch output stays in this private directory. The real runner changes
    # to the fixture QA directory, including its deliberately read-only case.
    (work / "profile.do").write_text("set processors 1\n")
    driver = work / "fixture_driver.do"
    driver.write_text("\n".join([
        "version 17.0",
        "set more off",
        "set processors 1",
        f'cd "{qa}"',
        f'sysdir set PLUS "{initial_plus}"',
        f'sysdir set PERSONAL "{initial_personal}"',
        'local original_plus "`c(sysdir_plus)\'"',
        'local original_personal "`c(sysdir_personal)\'"',
        f"capture noisily do run_all.do {arguments}",
        "local actual_rc = _rc",
        'local dirs_restored = ("`c(sysdir_plus)\'" == "`original_plus\'" & "`c(sysdir_personal)\'" == "`original_personal\'")',
        "tempname status_handle",
        f'file open `status_handle\' using "{status}", write text replace',
        'file write `status_handle\' "RC `actual_rc\' DIRS `dirs_restored\'" _n',
        "file close `status_handle'",
        "exit 0",
    ]) + "\n")
    try:
        result = subprocess.run(
            [binary, "-b", "do", str(driver)], cwd=work,
            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=45,
        )
        (work / "driver_stdout.txt").write_bytes(result.stdout)
        if result.returncode:
            raise RuntimeError(f"fixture Stata process failed: {result.returncode}; {work}")
        receipt = re.fullmatch(r"RC (\d+) DIRS ([01])\s*", status.read_text())
        if receipt is None:
            raise RuntimeError(f"missing or malformed native fixture receipt: {work}")
        Macro.setLocal("actual_rc", receipt.group(1))
        Macro.setLocal("dirs_restored", receipt.group(2))
    finally:
        qa.chmod(0o700)


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
    if sys.argv[1] == "execute":
        execute_runner(*sys.argv[2:])
    else:
        make_child(*sys.argv[1:])
