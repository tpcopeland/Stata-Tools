#!/usr/bin/env python3
"""Assert the border/shade/zebra styling of an iivw reporting worksheet.

usage: check_iivw_style.py WORKBOOK SHEET {thin|medium|academic} SHADE ZEBRA [marker]

  SHADE / ZEBRA are 0 or 1.

Layout assumptions (the tabtools layout used by every iivw reporting command):
  row 1        merged title
  row 2        group spanners
  row 3        column headers
  rows 4..     data
Column A is a width-1 gutter; the table proper starts at column B (=2).
"""

from __future__ import annotations

import sys
from pathlib import Path

from openpyxl import load_workbook


def fail(message: str) -> None:
    print(f"FAIL: {message}", file=sys.stderr)
    raise SystemExit(1)


def has_fill(cell) -> bool:
    return cell.fill is not None and cell.fill.patternType == "solid"


def check(path: Path, sheet: str, mode: str, shade: bool, zebra: bool,
          marker: Path | None) -> None:
    if mode not in ("thin", "medium", "academic"):
        fail("border mode must be thin, medium, or academic")
    if not path.exists():
        fail(f"workbook not found: {path}")
    wb = load_workbook(path)
    if sheet not in wb.sheetnames:
        fail(f"sheet not found: {sheet}")
    ws = wb[sheet]

    header = ws.cell(3, 2)        # B3
    data = ws.cell(5, 3)          # C5, an interior data cell

    # Header always carries a bottom rule in every supported scheme.
    if header.border.bottom.style is None:
        fail("header row has no bottom border")

    if mode in ("thin", "medium"):
        expected = mode
        for side in ("top", "bottom", "left", "right"):
            got = getattr(data.border, side).style
            if got != expected:
                fail(f"data cell C5 {side} border is {got!r}, expected {expected!r}"
                     " (full grid)")
    else:  # academic: horizontal rules only, no interior verticals
        for side in ("left", "right"):
            got = getattr(data.border, side).style
            if got is not None:
                fail(f"academic data cell C5 has a {side} border ({got!r});"
                     " academic must have no vertical rules")
        if data.border.bottom.style is not None:
            fail("academic interior data row has a horizontal rule;"
                 " academic rules only the header and last row")

    # Header shading.
    if shade and not has_fill(header):
        fail("headershade requested but header has no fill")
    if not shade and has_fill(header):
        fail("header is shaded but headershade was not requested")

    # Zebra striping: row 5 (the second data row) is the first shaded stripe.
    stripe = ws.cell(5, 3)
    if zebra and not has_fill(stripe):
        fail("zebra requested but no stripe fill on the alternating data row")
    if not zebra and not shade and has_fill(stripe):
        fail("data row is shaded but neither zebra nor headershade was requested")

    if marker is not None:
        marker.write_text("ok\n", encoding="utf-8")
    print(f"PASS: {path.name}:{sheet} style {mode} shade={int(shade)} zebra={int(zebra)}")


def main(argv: list[str]) -> int:
    if len(argv) not in (6, 7):
        print(
            "usage: check_iivw_style.py WORKBOOK SHEET "
            "{thin|medium|academic} SHADE ZEBRA [marker]",
            file=sys.stderr,
        )
        return 2
    marker = Path(argv[6]) if len(argv) == 7 else None
    check(Path(argv[1]), argv[2], argv[3], bool(int(argv[4])),
          bool(int(argv[5])), marker)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
