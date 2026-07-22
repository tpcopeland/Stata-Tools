#!/usr/bin/env python3
"""Compare regenerated demo artifacts with the tracked documentation assets.

Covers every tracked demo artifact, not just workbooks (finding I11):

  demo_*.xlsx  full canonical cell/format digest
  *.md         normalized Markdown comparison -- trailing whitespace and blank
               runs collapsed, but table cell CONTENT compared exactly. Without
               this, a stale generated report could drift from the code that
               produced it and no gate would notice; that is exactly how the
               README Table 1 excerpt came to show "58.3 (13.4)" while the
               tracked asset said "58.3+/-13.4".
  *.png        dimensions and colour mode, plus a payload digest. A pixel-exact
               hash is not portable across Stata graph-export builds, so the
               digest is reported as a NOTE rather than enforced, while a
               changed size or mode -- which does indicate a real layout
               change -- is a hard failure.
"""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

from openpyxl import load_workbook


def normalize_markdown(path: Path) -> list[str]:
    """Content-preserving Markdown normalization.

    Strips trailing whitespace and collapses blank-line runs so cosmetic
    reflow does not fail the gate, while leaving every table cell, heading,
    and numeric value byte-exact.
    """
    lines = path.read_text(encoding="utf-8").split("\n")
    out: list[str] = []
    blank = False
    for raw in lines:
        line = raw.rstrip()
        if not line:
            if not blank and out:
                out.append("")
            blank = True
            continue
        blank = False
        if line.lstrip().startswith("|"):
            # normalize only the padding between pipes, never the cell text
            cells = [c.strip() for c in line.strip().strip("|").split("|")]
            line = "| " + " | ".join(cells) + " |"
        out.append(line)
    while out and not out[-1]:
        out.pop()
    return out


def png_geometry(path: Path) -> tuple[int, int, str] | None:
    """Return (width, height, mode) for a PNG, or None if unreadable."""
    try:
        from PIL import Image
    except ImportError:
        return None
    with Image.open(path) as im:
        return (im.width, im.height, im.mode)


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

    # ---- Markdown parity (normalized, content-exact) ----
    # Scope note: the caller regenerates ONE demo into actual_dir, while
    # expected_dir holds every tracked demo asset. demo_tabtools.do owns the
    # workbooks and the Markdown report; demo_tabtools_eplot.do owns the forest
    # PNGs. So an artifact class the regeneration did not produce is out of
    # scope for this run and is reported as a NOTE, not a failure -- comparing
    # 2 tracked PNGs against 0 regenerated ones is a scoping error, not drift.
    # Within a class the regeneration DID produce, the inventory is strict.
    scope_notes: list[str] = []

    exp_md = {p.name: p for p in args.expected_dir.glob("*.md")}
    act_md = {p.name: p for p in args.actual_dir.glob("*.md")}
    if not act_md and exp_md:
        scope_notes.append(
            f"markdown not regenerated by this demo; {len(exp_md)} tracked file(s) not compared"
        )
        exp_md = {}
    else:
        # A TRACKED artifact that was not regenerated is drift and fails. An
        # EXTRA file in the regenerated tree is not: the demo also writes
        # runtime debris that is deliberately gitignored and therefore absent
        # from the tracked tree (demo/console_output.md is in .gitignore).
        # Comparing the two inventories for equality wrongly failed on that.
        missing = sorted(set(exp_md) - set(act_md))
        extra = sorted(set(act_md) - set(exp_md))
        if missing:
            failures.append(f"tracked markdown not regenerated: {missing}")
        if extra:
            scope_notes.append(f"untracked markdown produced by the demo, ignored: {extra}")
    for name in sorted(set(exp_md) & set(act_md)):
        e = normalize_markdown(exp_md[name])
        a = normalize_markdown(act_md[name])
        if e != a:
            diff = next(
                (
                    f"line {i + 1}: expected {e[i]!r} actual {a[i]!r}"
                    for i in range(min(len(e), len(a)))
                    if e[i] != a[i]
                ),
                f"length differs: expected {len(e)} lines, actual {len(a)} lines",
            )
            failures.append(f"markdown content differs: {name} ({diff})")

    # ---- PNG policy: geometry enforced, pixel digest reported ----
    exp_png = {p.name: p for p in args.expected_dir.glob("*.png")}
    act_png = {p.name: p for p in args.actual_dir.glob("*.png")}
    if not act_png and exp_png:
        scope_notes.append(
            f"png not regenerated by this demo; {len(exp_png)} tracked file(s) not compared"
        )
        exp_png = {}
    else:
        missing_png = sorted(set(exp_png) - set(act_png))
        extra_png = sorted(set(act_png) - set(exp_png))
        if missing_png:
            failures.append(f"tracked png not regenerated: {missing_png}")
        if extra_png:
            scope_notes.append(f"untracked png produced by the demo, ignored: {extra_png}")
    png_notes: list[str] = []
    for name in sorted(set(exp_png) & set(act_png)):
        eg = png_geometry(exp_png[name])
        ag = png_geometry(act_png[name])
        if eg is None or ag is None:
            png_notes.append(f"{name}: Pillow unavailable, geometry not checked")
            continue
        if eg != ag:
            failures.append(f"png geometry differs: {name} expected={eg} actual={ag}")
            continue
        ed = hashlib.sha256(exp_png[name].read_bytes()).hexdigest()[:16]
        ad = hashlib.sha256(act_png[name].read_bytes()).hexdigest()[:16]
        if ed != ad:
            png_notes.append(f"{name}: geometry {eg} matches, pixel digest differs ({ed} vs {ad})")

    args.status_file.parent.mkdir(parents=True, exist_ok=True)
    if failures:
        args.status_file.write_text("FAIL\n" + "\n".join(failures) + "\n", encoding="utf-8")
        raise SystemExit(1)
    summary = (
        f"PASS {len(expected)} workbooks, {len(set(exp_md) & set(act_md))} markdown, "
        f"{len(set(exp_png) & set(act_png))} png"
    )
    for note in scope_notes + png_notes:
        summary += "\nNOTE " + note
    args.status_file.write_text(summary + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
