#!/usr/bin/env python3
"""Independently compare exported cci_se results with the pinned fixture."""

from __future__ import annotations

import argparse
import csv
from pathlib import Path


COMPONENTS = (
    "mi", "chf", "pvd", "cevd", "copd", "pulm", "rheum", "dem",
    "plegia", "diab", "diabcomp", "renal", "livmild", "livsev",
    "pud", "cancer", "mets", "aids",
)


def read_unique(path: Path, required: set[str]) -> dict[int, dict[str, str]]:
    if not path.is_file() or path.stat().st_size == 0:
        raise ValueError(f"missing or empty CSV: {path}")
    with path.open(encoding="utf-8", newline="") as handle:
        reader = csv.DictReader(handle)
        if reader.fieldnames is None or not required.issubset(reader.fieldnames):
            missing = sorted(required.difference(reader.fieldnames or []))
            raise ValueError(f"schema missing columns {missing}: {path}")
        rows: dict[int, dict[str, str]] = {}
        for row in reader:
            case_id = int(row["case_id"])
            if case_id in rows:
                raise ValueError(f"duplicate case_id {case_id}: {path}")
            rows[case_id] = row
    if not rows:
        raise ValueError(f"zero comparison rows: {path}")
    return rows


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--expected", type=Path, required=True)
    parser.add_argument("--actual", type=Path, required=True)
    parser.add_argument("--report", type=Path, required=True)
    args = parser.parse_args()

    expected_columns = {"case_id", "expected_score"} | {
        f"expected_{name}" for name in COMPONENTS
    }
    actual_columns = {"case_id", "actual_score"} | {
        f"actual_{name}" for name in COMPONENTS
    }
    expected = read_unique(args.expected, expected_columns)
    actual = read_unique(args.actual, actual_columns)

    if expected.keys() != actual.keys():
        missing = sorted(expected.keys() - actual.keys())[:10]
        extra = sorted(actual.keys() - expected.keys())[:10]
        raise ValueError(f"incomplete merge: missing={missing}, extra={extra}")

    mismatches: list[str] = []
    for case_id in sorted(expected):
        pairs = [("score", "expected_score", "actual_score")]
        pairs.extend(
            (name, f"expected_{name}", f"actual_{name}")
            for name in COMPONENTS
        )
        for label, expected_name, actual_name in pairs:
            expected_value = int(float(expected[case_id][expected_name]))
            actual_value = int(float(actual[case_id][actual_name]))
            if expected_value != actual_value:
                mismatches.append(
                    f"case_id={case_id} field={label} "
                    f"expected={expected_value} actual={actual_value}"
                )
                if len(mismatches) >= 20:
                    break
        if len(mismatches) >= 20:
            break
    if mismatches:
        raise ValueError("CCI mismatch: " + "; ".join(mismatches))

    args.report.write_text(
        f"RESULT: cci_python_crossval matched={len(expected)} mismatches=0\n",
        encoding="utf-8",
    )


if __name__ == "__main__":
    main()
