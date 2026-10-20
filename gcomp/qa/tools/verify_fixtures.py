#!/usr/bin/env python3
"""Regenerate gcomp external fixtures in a temporary copy and fail on drift."""

from __future__ import annotations

import argparse
import csv
import json
import math
import os
import shutil
import subprocess
import sys
import tempfile
from importlib import metadata
from pathlib import Path


DATA_DIR = Path(__file__).resolve().parents[1] / "data"


def version_tuple() -> dict[str, str]:
    return {
        "python": ".".join(map(str, sys.version_info[:3])),
        "numpy": metadata.version("numpy"),
        "pandas": metadata.version("pandas"),
        "statsmodels": metadata.version("statsmodels"),
    }


def r_versions() -> dict[str, str]:
    code = (
        'cat(paste(R.version$major, R.version$minor, sep="."), "\\n"); '
        'cat(as.character(packageVersion("mediation")), "\\n")'
    )
    proc = subprocess.run(
        ["Rscript", "-e", code], check=True, text=True, capture_output=True
    )
    lines = [line.strip() for line in proc.stdout.splitlines() if line.strip()]
    return {"R": lines[0], "mediation": lines[1]}


def as_number(value: str) -> float | None:
    try:
        return float(value)
    except ValueError:
        return None


def compare_csv(expected: Path, actual: Path, tolerance: float) -> list[str]:
    if not actual.is_file():
        return [f"generator did not create {actual.name}"]
    with expected.open(newline="", encoding="utf-8-sig") as left_handle:
        left = list(csv.reader(left_handle))
    with actual.open(newline="", encoding="utf-8-sig") as right_handle:
        right = list(csv.reader(right_handle))
    if not left or not right:
        return [] if left == right else [f"{expected.name}: empty/nonempty mismatch"]
    problems: list[str] = []
    if left[0] != right[0]:
        problems.append(f"{expected.name}: header drift {right[0]!r} != {left[0]!r}")
        return problems
    if len(left) != len(right):
        problems.append(f"{expected.name}: row count {len(right)-1} != {len(left)-1}")
        return problems
    for row_index, (left_row, right_row) in enumerate(zip(left[1:], right[1:]), 2):
        if len(left_row) != len(right_row):
            problems.append(f"{expected.name}:{row_index}: column-count drift")
            continue
        for column_index, (left_value, right_value) in enumerate(
            zip(left_row, right_row), 1
        ):
            left_number = as_number(left_value)
            right_number = as_number(right_value)
            if left_number is not None and right_number is not None:
                equal = (
                    math.isnan(left_number)
                    and math.isnan(right_number)
                    or math.isclose(
                        left_number,
                        right_number,
                        rel_tol=tolerance,
                        abs_tol=tolerance,
                    )
                )
            else:
                equal = left_value == right_value
            if not equal:
                problems.append(
                    f"{expected.name}:{row_index}:{column_index}: "
                    f"{right_value!r} != {left_value!r}"
                )
                if len(problems) >= 20:
                    return problems
    return problems


REEXEC_ENV = "GCOMP_FIXTURE_PINNED_REEXEC"


def pinned_interpreter(want: str) -> str | None:
    """Return an interpreter whose version is exactly the manifest's pin.

    The running one if it matches; otherwise whatever ``uv python find``
    resolves for that exact version. None when neither exists, in which case
    the runtime check below reports the mismatch and the run fails closed.
    """
    if ".".join(map(str, sys.version_info[:3])) == want:
        return sys.executable
    uv = shutil.which("uv")
    if uv is None:
        return None
    proc = subprocess.run(
        [uv, "python", "find", f"=={want}"],
        check=False, text=True, capture_output=True,
    )
    found = proc.stdout.strip()
    if proc.returncode != 0 or not found or not Path(found).is_file():
        return None
    return found


def generator_command(command: str) -> list[str]:
    """Run Python generators on this (pinned) interpreter, not PATH python3."""
    parts = command.split()
    if parts and parts[0] in {"python", "python3"}:
        parts[0] = sys.executable
    return parts


def write_result(path: Path | None, status: str) -> None:
    if path is not None:
        path.write_text(status + "\n", encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--result-file", type=Path)
    parser.add_argument("--generator", action="append", default=[])
    args = parser.parse_args()

    manifest = json.loads((DATA_DIR / "fixture_manifest.json").read_text())
    # The fixtures were generated under a pinned Python stack. Re-run under an
    # interpreter of exactly that version when the caller's python3 differs
    # (the OS interpreter drifts with system upgrades); the package pins are
    # still checked below, and an absent interpreter fails closed.
    want_python = manifest["environment"].get("python")
    if want_python and not os.environ.get(REEXEC_ENV):
        pinned = pinned_interpreter(want_python)
        if pinned is not None and Path(pinned).resolve() != Path(sys.executable).resolve():
            print(f"PINNED-PYTHON: {want_python} -> {pinned}", flush=True)
            env = dict(os.environ, **{REEXEC_ENV: "1"})
            os.execve(pinned, [pinned, str(Path(__file__).resolve()), *sys.argv[1:]], env)
    observed = version_tuple()
    observed.update(r_versions())
    problems = [
        f"runtime {key}={observed.get(key)}; expected {expected}"
        for key, expected in manifest["environment"].items()
        if observed.get(key) != expected
    ]
    selected = set(args.generator)
    with tempfile.TemporaryDirectory(prefix="gcomp-fixtures-") as temp:
        work = Path(temp) / "data"
        shutil.copytree(DATA_DIR, work)
        for spec in manifest["generators"]:
            if selected and spec["script"] not in selected:
                continue
            command = generator_command(spec["command"])
            print(f"GENERATE: {spec['command']}", flush=True)
            proc = subprocess.run(command, cwd=work, check=False)
            if proc.returncode != 0:
                problems.append(
                    f"{spec['script']}: generator exited {proc.returncode}"
                )
                continue
            for output in spec["outputs"]:
                problems.extend(
                    compare_csv(
                        DATA_DIR / output,
                        work / output,
                        float(spec["numeric_tolerance"]),
                    )
                )

    if problems:
        for problem in problems:
            print(f"FAIL: {problem}")
        write_result(args.result_file, "FAIL")
        return 1
    write_result(args.result_file, "PASS")
    print("PASS: all generated fixtures match committed fixtures")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
