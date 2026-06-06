#!/usr/bin/env python3
"""Small Markdown artifact checker for tabtools QA."""

from __future__ import annotations

import argparse
from pathlib import Path


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("path")
    parser.add_argument("--contains", action="append", default=[])
    parser.add_argument("--tables", type=int, default=1)
    parser.add_argument("--escaped-pipe", action="store_true")
    args = parser.parse_args()

    path = Path(args.path)
    if not path.exists():
        raise SystemExit(f"missing file: {path}")
    text = path.read_text(encoding="utf-8")
    if "| --- |" not in text:
        raise SystemExit("missing GFM separator row")
    for needle in args.contains:
        if needle not in text:
            raise SystemExit(f"missing expected text: {needle}")
    table_count = text.count("| ---")
    if table_count < args.tables:
        raise SystemExit(f"expected at least {args.tables} table(s), found {table_count}")
    if args.escaped_pipe and r"\|" not in text:
        raise SystemExit("expected escaped pipe not found")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
