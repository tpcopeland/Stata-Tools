#!/usr/bin/env python3
"""Fail-closed lane runner for gcomp's Stata QA suites."""

from __future__ import annotations

import argparse
import json
import os
import random
import re
import shutil
import subprocess
import sys
import tempfile
import time
from dataclasses import dataclass
from pathlib import Path


QA_DIR = Path(__file__).resolve().parent
MANIFEST = QA_DIR / "lanes.json"
SENTINEL_RE = re.compile(
    r"^RESULT:\s+(?P<name>[A-Za-z0-9_]+)\s+tests=(?P<tests>\d+)\s+"
    r"pass=(?P<passed>\d+)\s+fail=(?P<failed>\d+)\s+status=(?P<status>PASS|FAIL)\s*$",
    re.MULTILINE,
)
PROGRESS_HEADER_RE = re.compile(r"^(Bootstrap|Jackknife) replications \(\d+\)\s*$")
PROGRESS_LINE_RE = re.compile(r"^\s*([.xe]+)(?:\s+\d+)?\s*$")


@dataclass(frozen=True)
class Suite:
    name: str
    timeout_seconds: int
    expected_resampling_failures_min: int = 0
    expected_resampling_failures_max: int = 0


def load_manifest() -> dict:
    with MANIFEST.open(encoding="utf-8") as handle:
        return json.load(handle)


def lane_suites(manifest: dict, lane: str) -> tuple[list[Suite], int]:
    lanes = manifest["lanes"]
    if lane in lanes:
        spec = lanes[lane]
        raw = spec["suites"]
        budget = int(spec["budget_seconds"])
    elif lane in manifest.get("aggregate_lanes", {}):
        raw = []
        budget = 0
        seen: set[str] = set()
        for member in manifest["aggregate_lanes"][lane]:
            budget += int(lanes[member]["budget_seconds"])
            for item in lanes[member]["suites"]:
                if item["name"] not in seen:
                    raw.append(item)
                    seen.add(item["name"])
    else:
        raise KeyError(lane)
    return [Suite(**item) for item in raw], budget


def validate_manifest(manifest: dict) -> None:
    """Fail if the canonical inventory, sentinels, or source hygiene drift."""
    canonical = ("quick", "core", "external", "slow", "release")
    inventoried = {
        item["name"]
        for lane in canonical
        for item in manifest["lanes"][lane]["suites"]
    }
    discovered = {
        path.stem
        for pattern in ("test_*.do", "validation_*.do", "crossval_*.do")
        for path in QA_DIR.glob(pattern)
    }
    if inventoried != discovered:
        missing = sorted(discovered - inventoried)
        stale = sorted(inventoried - discovered)
        raise ValueError(f"lane inventory drift; missing={missing}, stale={stale}")
    for name in sorted(discovered):
        text = (QA_DIR / f"{name}.do").read_text(encoding="utf-8")
        if f"RESULT: {name} tests=" not in text or "status=PASS" not in text:
            raise ValueError(f"{name}.do lacks an explicit terminal PASS sentinel")
        if "net install gcomp" in text and name != "test_install_smoke":
            raise ValueError(f"{name}.do performs a noncanonical package install")
        if re.search(r'^\s*log using\s+"[^`]', text, re.MULTILINE):
            raise ValueError(f"{name}.do opens a fixed package-local log")
        source_exempt = {
            "test_install_smoke",
            "test_package_release",
            "crossval_fixture_provenance",
            "test_audit_remediation",
        }
        if name not in source_exempt and "_qa_bootstrap.do" not in text:
            raise ValueError(f"{name}.do does not enforce package-source resolution")
    for path in sorted((QA_DIR / "audit").glob("*.do")):
        text = path.read_text(encoding="utf-8")
        if "_qa_bootstrap.do" not in text:
            raise ValueError(f"audit/{path.name} does not enforce package-source resolution")


def resampling_failures(log_text: str) -> list[str]:
    """Return bootstrap/jackknife progress lines containing x/e markers."""
    failures: list[str] = []
    in_progress = False
    for raw_line in log_text.splitlines():
        line = raw_line.rstrip()
        if PROGRESS_HEADER_RE.match(line.strip()):
            in_progress = True
            continue
        if not in_progress:
            continue
        if line.startswith("----+"):
            continue
        match = PROGRESS_LINE_RE.match(line)
        if match:
            marks = match.group(1)
            if "x" in marks or "e" in marks:
                failures.append(line.strip())
            continue
        if line.strip():
            in_progress = False
    return failures


def validate_log(suite: Suite, log_text: str) -> list[str]:
    problems: list[str] = []
    logical_lines: list[str] = []
    current = ""
    for line in log_text.splitlines():
        if current and line.lstrip().startswith("> "):
            current += line.lstrip()[2:]
            continue
        if current:
            logical_lines.append(current)
        current = line
    if current:
        logical_lines.append(current)
    matches = list(SENTINEL_RE.finditer("\n".join(logical_lines)))
    if not matches:
        problems.append("missing terminal RESULT sentinel")
    else:
        result = matches[-1].groupdict()
        if result["name"] != suite.name:
            problems.append(f"terminal sentinel names {result['name']}, expected {suite.name}")
        tests = int(result["tests"])
        passed = int(result["passed"])
        failed = int(result["failed"])
        if result["status"] != "PASS" or failed != 0 or passed != tests:
            problems.append(
                f"terminal sentinel is not green: tests={tests} pass={passed} "
                f"fail={failed} status={result['status']}"
            )
    markers = resampling_failures(log_text)
    marker_count = sum(line.count("x") + line.count("e") for line in markers)
    if marker_count < suite.expected_resampling_failures_min:
        problems.append(
            f"expected at least {suite.expected_resampling_failures_min} resampling "
            f"failure marker(s), observed {marker_count}"
        )
    if marker_count > suite.expected_resampling_failures_max:
        preview = ", ".join(markers[:5])
        problems.append(
            f"resampling failure markers {marker_count} exceed declared maximum "
            f"{suite.expected_resampling_failures_max}: {preview}"
        )
    return problems


def parser_self_test() -> None:
    clean = "Bootstrap replications (4)\n----+--- 1\n....\n"
    dirty = "Jackknife replications (6)\n----+--- 1\n..e.x.     6\n"
    wrapped = "Bootstrap replications (3)\n----+--- 1\n...\nSome output\nexample\n"
    assert resampling_failures(clean) == []
    assert resampling_failures(dirty) == ["..e.x.     6"]
    assert resampling_failures(wrapped) == []
    valid = "RESULT: alpha tests=2 pass=2 fail=0 status=PASS\n"
    assert validate_log(Suite("alpha", 1), valid) == []
    assert validate_log(Suite("alpha", 1, 2, 2), valid + dirty) == []
    assert "missing terminal" in validate_log(Suite("alpha", 1), "stale PASS\n")[0]
    terminal_fail = "RESULT: alpha tests=2 pass=1 fail=1 status=FAIL\n"
    assert "not green" in validate_log(Suite("alpha", 1), terminal_fail)[0]
    wrong_name = "RESULT: beta tests=2 pass=2 fail=0 status=PASS\n"
    assert "expected alpha" in validate_log(Suite("alpha", 1), wrong_name)[0]
    assert "exceed" in validate_log(Suite("alpha", 1), valid + dirty)[0]
    assert "not green" in validate_log(Suite("alpha", 1), valid + terminal_fail)[0]


def run_suite(suite: Suite, artifact_dir: Path) -> tuple[bool, float, list[str]]:
    source = QA_DIR / f"{suite.name}.do"
    if not source.is_file():
        return False, 0.0, [f"suite file does not exist: {source.name}"]
    qa_log = QA_DIR / f"{suite.name}.log"
    qa_smcl = QA_DIR / f"{suite.name}.smcl"
    qa_log.unlink(missing_ok=True)
    qa_smcl.unlink(missing_ok=True)
    started = time.monotonic()
    problems: list[str] = []
    try:
        proc = subprocess.run(
            [os.environ.get("STATA_BIN", "stata-mp"), "-b", "do", source.name],
            cwd=QA_DIR,
            timeout=suite.timeout_seconds,
            check=False,
        )
    except subprocess.TimeoutExpired:
        elapsed = time.monotonic() - started
        if qa_log.exists():
            shutil.move(str(qa_log), artifact_dir / qa_log.name)
        qa_smcl.unlink(missing_ok=True)
        return False, elapsed, [f"timeout after {suite.timeout_seconds}s"]
    elapsed = time.monotonic() - started
    if proc.returncode != 0:
        problems.append(f"Stata exited {proc.returncode}")
    if not qa_log.is_file():
        problems.append("Stata did not create a fresh batch log")
        return False, elapsed, problems
    log_text = qa_log.read_text(encoding="utf-8", errors="replace")
    problems.extend(validate_log(suite, log_text))
    shutil.move(str(qa_log), artifact_dir / qa_log.name)
    qa_smcl.unlink(missing_ok=True)
    return not problems, elapsed, problems


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--lane", default="quick")
    parser.add_argument("--suite", action="append", default=[])
    parser.add_argument("--shuffle", action="store_true")
    parser.add_argument("--seed", type=int, default=20260713)
    parser.add_argument("--list", action="store_true")
    parser.add_argument("--self-test-parser", action="store_true")
    args = parser.parse_args()

    parser_self_test()
    if args.self_test_parser:
        print("RESULT: run_qa_parser tests=10 pass=10 fail=0 status=PASS")
        return 0

    manifest = load_manifest()
    try:
        validate_manifest(manifest)
    except ValueError as error:
        print(f"RESULT: run_qa_manifest tests=1 pass=0 fail=1 status=FAIL")
        print(f"FAIL: {error}")
        return 1
    try:
        suites, lane_budget = lane_suites(manifest, args.lane)
    except KeyError:
        choices = sorted(set(manifest["lanes"]) | set(manifest.get("aggregate_lanes", {})))
        parser.error(f"unknown lane {args.lane!r}; choose from {', '.join(choices)}")
    if args.shuffle:
        random.Random(args.seed).shuffle(suites)
    if args.suite:
        requested = set(args.suite)
        suites = [suite for suite in suites if suite.name in requested]
        missing = requested - {suite.name for suite in suites}
        if missing:
            parser.error(f"suite(s) not in lane {args.lane}: {', '.join(sorted(missing))}")
    if args.list:
        for suite in suites:
            print(f"{suite.name}\t{suite.timeout_seconds}s")
        return 0

    artifact_dir = Path(tempfile.mkdtemp(prefix=f"gcomp-qa-{args.lane}-"))
    started = time.monotonic()
    passed = 0
    failures: list[str] = []
    print(
        f"QA lane={args.lane} suites={len(suites)} budget={lane_budget}s "
        f"shuffle={args.shuffle} seed={args.seed}"
    )
    for index, suite in enumerate(suites, 1):
        elapsed_lane = time.monotonic() - started
        if elapsed_lane >= lane_budget:
            failures.append(f"lane budget exceeded before {suite.name}")
            print(f"FAIL {suite.name}: lane budget exceeded")
            break
        print(f"[{index}/{len(suites)}] {suite.name}", flush=True)
        ok, elapsed, problems = run_suite(suite, artifact_dir)
        if ok:
            passed += 1
            print(f"PASS {suite.name} ({elapsed:.1f}s)", flush=True)
        else:
            detail = "; ".join(problems)
            failures.append(f"{suite.name}: {detail}")
            print(f"FAIL {suite.name} ({elapsed:.1f}s): {detail}", flush=True)

    elapsed_total = time.monotonic() - started
    if elapsed_total > lane_budget:
        failures.append(f"lane runtime {elapsed_total:.1f}s exceeded budget {lane_budget}s")
    failed = len(suites) - passed
    status = "PASS" if not failures and passed == len(suites) else "FAIL"
    print(f"QA artifacts: {artifact_dir}")
    for failure in failures:
        print(f"  - {failure}")
    print(
        f"RESULT: run_qa_{args.lane} tests={len(suites)} pass={passed} "
        f"fail={failed} status={status}"
    )
    return 0 if status == "PASS" else 1


if __name__ == "__main__":
    sys.exit(main())
