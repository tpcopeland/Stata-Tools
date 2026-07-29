#!/usr/bin/env python3
"""Fail-closed PNG signature and dimension checker for msm QA."""

from __future__ import annotations

import argparse
import struct
from pathlib import Path


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("file", type=Path)
    parser.add_argument("--width", type=int, required=True)
    parser.add_argument("--height", type=int, required=True)
    parser.add_argument("--result-file", type=Path, required=True)
    args = parser.parse_args()

    status = "FAIL"
    try:
        raw = args.file.read_bytes()
        if len(raw) < 24 or raw[:8] != b"\x89PNG\r\n\x1a\n":
            raise ValueError("not a PNG file")
        if raw[12:16] != b"IHDR":
            raise ValueError("PNG does not begin with IHDR")
        width, height = struct.unpack(">II", raw[16:24])
        if (width, height) != (args.width, args.height):
            raise ValueError(
                f"dimensions are {width}x{height}, expected "
                f"{args.width}x{args.height}"
            )
        status = "PASS"
    except (OSError, ValueError, struct.error) as exc:
        print(f"FAIL: {args.file}: {exc}")

    args.result_file.write_text(status + "\n", encoding="utf-8")
    return 0 if status == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
