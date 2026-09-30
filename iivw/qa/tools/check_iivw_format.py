#!/usr/bin/env python3
"""Check font identity and decimal text against a numerical reporting payload.

Reuses check_iivw_xlsx.check for the existing workbook layout contract.
"""
from __future__ import annotations
import math
from pathlib import Path
import sys
from check_iivw_xlsx import check, load_workbook


def main() -> None:
    if len(sys.argv) != 9:
        raise SystemExit('usage: workbook sheet mode decimals font value marker cell')
    workbook, sheet, mode, decimals, font, value, marker, cell = sys.argv[1:]
    if font.startswith("@"):
        font = Path(font[1:]).read_text().rstrip("\n")
    precision = int(decimals)
    number = float(value)
    if not 0 <= precision <= 6 or not math.isfinite(number):
        raise SystemExit('invalid finite formatting oracle input')
    check(Path(workbook), sheet, mode, None, None)
    ws = load_workbook(workbook)[sheet]
    actual = ws[cell].value
    expected = f'{number:.{precision}f}'
    if actual != expected:
        raise SystemExit(f'format/value mismatch {cell}: {actual!r} != {expected!r}')
    for address in ('A1', 'B3', cell):
        if ws[address].font.name != font:
            raise SystemExit(f'font mismatch {address}: {ws[address].font.name!r} != {font!r}')
    Path(marker).write_text('ok\n')
    print(f'PASS: {mode} decimal{precision} font={font!r} payload={actual!r}')


if __name__ == '__main__':
    main()
