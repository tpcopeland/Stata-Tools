#!/usr/bin/env python3
"""Verify freshly generated R cross-validation fixtures against tracked data."""

from __future__ import annotations

import argparse
from pathlib import Path


FILES = (
    "crossval_smd_data.csv",
    "crossval_cat_smd_data.csv",
    "crossval_ess_data.csv",
    "crossval_tabtools_r_results.csv",
)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("tracked", type=Path)
    parser.add_argument("generated", type=Path)
    parser.add_argument("--status-file", required=True, type=Path)
    args = parser.parse_args()

    failures: list[str] = []
    for name in FILES:
        tracked = args.tracked / name
        generated = args.generated / name
        if not tracked.is_file() or not generated.is_file():
            failures.append(f"missing {name}")
        elif tracked.read_bytes() != generated.read_bytes():
            failures.append(f"byte mismatch {name}")

    args.status_file.parent.mkdir(parents=True, exist_ok=True)
    if failures:
        args.status_file.write_text("FAIL\n" + "\n".join(failures) + "\n", encoding="utf-8")
        raise SystemExit(1)
    args.status_file.write_text("PASS 4 fixtures\n", encoding="utf-8")


if __name__ == "__main__":
    main()
