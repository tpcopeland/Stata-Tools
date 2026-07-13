#!/usr/bin/env python3
"""Compare regenerated demo workbooks with the tracked documentation assets."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

from openpyxl import load_workbook


def _color(color: object) -> tuple[object, ...]:
    return tuple(getattr(color, name, None) for name in ("type", "rgb", "indexed", "theme", "tint"))


def _side(side: object) -> tuple[object, ...]:
    return (getattr(side, "style", None), _color(getattr(side, "color", None)))


def _cell_payload(cell: object) -> dict[str, object]:
    font = cell.font
    fill = cell.fill
    border = cell.border
    alignment = cell.alignment
    return {
        "coordinate": cell.coordinate,
        "value": cell.value,
        "data_type": cell.data_type,
        "number_format": cell.number_format,
        "font": (font.name, font.sz, font.bold, font.italic, font.underline, _color(font.color)),
        "fill": (fill.fill_type, _color(fill.fgColor), _color(fill.bgColor)),
        "border": tuple(_side(getattr(border, name)) for name in ("left", "right", "top", "bottom")),
        "alignment": (
            alignment.horizontal,
            alignment.vertical,
            alignment.text_rotation,
            alignment.wrap_text,
            alignment.shrink_to_fit,
            alignment.indent,
        ),
    }


def workbook_digest(path: Path) -> str:
    workbook = load_workbook(path, data_only=False)
    sheets: list[dict[str, object]] = []
    for worksheet in workbook.worksheets:
        cells = [
            _cell_payload(cell)
            for cell in sorted(worksheet._cells.values(), key=lambda item: item.coordinate)
        ]
        columns = sorted(
            (key, dim.width, dim.hidden, dim.outlineLevel)
            for key, dim in worksheet.column_dimensions.items()
        )
        rows = sorted(
            (key, dim.height, dim.hidden, dim.outlineLevel)
            for key, dim in worksheet.row_dimensions.items()
        )
        sheets.append(
            {
                "title": worksheet.title,
                "cells": cells,
                "columns": columns,
                "rows": rows,
                "merged": sorted(str(item) for item in worksheet.merged_cells.ranges),
                "freeze_panes": str(worksheet.freeze_panes or ""),
            }
        )
    workbook.close()
    encoded = json.dumps(sheets, ensure_ascii=False, sort_keys=True, default=str).encode("utf-8")
    return hashlib.sha256(encoded).hexdigest()


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("expected_dir", type=Path)
    parser.add_argument("actual_dir", type=Path)
    parser.add_argument("--status-file", required=True, type=Path)
    args = parser.parse_args()

    expected = {path.name: path for path in args.expected_dir.glob("demo_*.xlsx")}
    actual = {path.name: path for path in args.actual_dir.glob("demo_*.xlsx")}
    failures: list[str] = []
    if set(expected) != set(actual):
        failures.append(
            f"workbook inventory differs: expected={sorted(expected)} actual={sorted(actual)}"
        )
    for name in sorted(set(expected) & set(actual)):
        if workbook_digest(expected[name]) != workbook_digest(actual[name]):
            failures.append(f"canonical workbook content differs: {name}")

    args.status_file.parent.mkdir(parents=True, exist_ok=True)
    if failures:
        args.status_file.write_text("FAIL\n" + "\n".join(failures) + "\n", encoding="utf-8")
        raise SystemExit(1)
    args.status_file.write_text(f"PASS {len(expected)} workbooks\n", encoding="utf-8")


if __name__ == "__main__":
    main()
