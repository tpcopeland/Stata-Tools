#!/usr/bin/env python3
"""Validate psdash raster/PDF artifacts beyond mere file existence."""

# Package: psdash
# Purpose: QA-only structural validation of generated image and PDF artifacts.
# Author: Timothy P Copeland, Karolinska Institutet

from __future__ import annotations

import argparse
import re
import struct
from pathlib import Path


def check_png(payload: bytes, min_width: int, min_height: int) -> None:
    if not payload.startswith(b"\x89PNG\r\n\x1a\n"):
        raise ValueError("missing PNG signature")
    if len(payload) < 33 or payload[12:16] != b"IHDR":
        raise ValueError("missing PNG IHDR")
    width, height = struct.unpack(">II", payload[16:24])
    if width < min_width or height < min_height:
        raise ValueError(f"PNG dimensions {width}x{height} are too small")
    if len(payload) < 12 or payload[-12:-4] != b"\x00\x00\x00\x00IEND":
        raise ValueError("missing PNG IEND")


def check_pdf(payload: bytes, min_bytes: int) -> None:
    if not payload.startswith(b"%PDF-"):
        raise ValueError("missing PDF signature")
    if len(payload) < min_bytes:
        raise ValueError(f"PDF has only {len(payload)} bytes")
    if b"%%EOF" not in payload[-1024:]:
        raise ValueError("missing PDF EOF marker")
    if re.search(rb"/Type\s*/Page(?!s)\b", payload) is None:
        raise ValueError("PDF contains no page object")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("path", type=Path)
    parser.add_argument("--type", choices=("png", "pdf"))
    parser.add_argument("--min-width", type=int, default=100)
    parser.add_argument("--min-height", type=int, default=100)
    parser.add_argument("--min-bytes", type=int, default=1000)
    parser.add_argument("--result-file", type=Path, required=True)
    args = parser.parse_args()

    try:
        payload = args.path.read_bytes()
        kind = args.type or args.path.suffix.lower().lstrip(".")
        if kind == "png":
            check_png(payload, args.min_width, args.min_height)
        elif kind == "pdf":
            check_pdf(payload, args.min_bytes)
        else:
            raise ValueError(f"unsupported artifact type: {kind}")
    except (OSError, ValueError) as exc:
        args.result_file.write_text(f"FAIL: {exc}\n", encoding="utf-8")
        return 1

    args.result_file.write_text("PASS\n", encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
