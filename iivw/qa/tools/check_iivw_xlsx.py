#!/usr/bin/env python3
"""Validate styled iivw reporting workbooks."""

from __future__ import annotations

import sys
from pathlib import Path

from openpyxl import load_workbook
from openpyxl.utils import get_column_letter


HEADERS = {
    "balance": [
        "Covariate",
        "Unweighted mean",
        "Weighted mean",
        "Unweighted SD",
        "SMD",
        "|SMD|",
        "N",
        "Missing",
        "Modeled",
    ],
    "diagnostics": [
        "Section",
        "Quantity",
        "Estimate",
        "SE",
        "Lower CI",
        "Upper CI",
        "Value",
    ],
}


def fail(message: str) -> None:
    print(f"FAIL: {message}", file=sys.stderr)
    raise SystemExit(1)


def nondefault_fill(cell) -> bool:
    fill = cell.fill
    if fill.patternType in (None, "none"):
        return False
    color = fill.fgColor.rgb or fill.fgColor.indexed or fill.fgColor.theme
    return color not in (None, "00000000", "FFFFFFFF")


def check(
    path: Path,
    sheet: str,
    mode: str,
    expected_rows: int | None,
    marker: Path | None,
) -> None:
    if mode not in HEADERS:
        fail("mode must be balance or diagnostics")
    if not path.exists():
        fail(f"workbook not found: {path}")

    wb = load_workbook(path)
    if sheet not in wb.sheetnames:
        fail(f"sheet not found: {sheet}")
    ws = wb[sheet]

    headers = HEADERS[mode]
    n_cols = len(headers)
    last_col = get_column_letter(n_cols)

    if ws["A1"].value in (None, ""):
        fail("missing title in A1")
    expected_merge = f"A1:{last_col}1"
    if expected_merge not in {str(rng) for rng in ws.merged_cells.ranges}:
        fail(f"title row is not merged across {expected_merge}")
    if not ws["A1"].font.bold:
        fail("title is not bold")
    if not nondefault_fill(ws["A1"]):
        fail("title has no fill")

    actual_headers = [ws.cell(3, col).value for col in range(1, n_cols + 1)]
    if actual_headers != headers:
        fail(f"header mismatch: {actual_headers!r}")
    for col in range(1, n_cols + 1):
        cell = ws.cell(3, col)
        if not cell.font.bold:
            fail(f"header col {col} is not bold")
        if not nondefault_fill(cell):
            fail(f"header col {col} has no fill")
        if cell.border.bottom.style is None:
            fail(f"header col {col} has no bottom border")
        width = ws.column_dimensions[get_column_letter(col)].width
        if width is None or width < 8:
            fail(f"column {col} width is too small")

    if expected_rows is not None:
        note_row = 4 + expected_rows + 1
        if ws.cell(note_row, 1).value in (None, ""):
            fail(f"missing footnote at row {note_row}")
        expected_note_merge = f"A{note_row}:{last_col}{note_row}"
        if expected_note_merge not in {str(rng) for rng in ws.merged_cells.ranges}:
            fail(f"footnote row is not merged across {expected_note_merge}")

    numeric_probe = ws["B4"] if mode == "balance" else ws["C4"]
    if numeric_probe.value is not None and numeric_probe.number_format != "0.0000":
        fail(f"unexpected numeric format: {numeric_probe.number_format!r}")

    if marker is not None:
        marker.write_text("ok\n", encoding="utf-8")
    print(f"PASS: {path.name}:{sheet} styled {mode} worksheet")


def main(argv: list[str]) -> int:
    if len(argv) not in (4, 5, 6):
        print(
            "usage: check_iivw_xlsx.py WORKBOOK SHEET {balance|diagnostics} [expected_rows] [marker]",
            file=sys.stderr,
        )
        return 2
    expected_rows = int(argv[4]) if len(argv) >= 5 else None
    marker = Path(argv[5]) if len(argv) == 6 else None
    check(Path(argv[1]), argv[2], argv[3], expected_rows, marker)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
