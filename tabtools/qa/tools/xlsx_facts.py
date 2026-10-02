"""Dump layout facts of one worksheet, one fact per line, for Stata to read.

Usage:
    python3 xlsx_facts.py BOOK.xlsx SHEET RESULT.txt

RESULT.txt receives, in this order:
    merge <range>                   every merged range, e.g. "merge B6:C6"
    width <col> <width>             every column with an explicit width
    bottom <cell> <style>           every cell with a bottom border
    value <cell> <text>             every non-empty cell (newlines as \\n)
    top|left|right <cell> <style>   every cell with that border side
    bold <cell>                     every cell whose font is bold
The top/left/right facts are read from the sheet XML itself: on load,
openpyxl reformats every merged range and can report a border on the
anchor cell that the file does not contain (a merged B9:E9 whose E9 has a
right border read back as "right B9").
A Stata suite then asserts presence or absence of exact lines. Reading the
workbook back with openpyxl keeps the oracle independent of the Mata xl()
writer that produced it.
"""

import sys
import zipfile
import xml.etree.ElementTree as ET

from openpyxl import load_workbook

_NS = {
    "m": "http://schemas.openxmlformats.org/spreadsheetml/2006/main",
    "r": "http://schemas.openxmlformats.org/officeDocument/2006/relationships",
}


def _raw_sides(book, sheet):
    """[(side, cell, style)] for top/left/right borders, from the raw XML."""
    with zipfile.ZipFile(book) as z:
        wb = ET.fromstring(z.read("xl/workbook.xml"))
        rels = ET.fromstring(z.read("xl/_rels/workbook.xml.rels"))
        rid = next(s.get(f"{{{_NS['r']}}}id") for s in wb.find("m:sheets", _NS)
                   if s.get("name") == sheet)
        target = next(r.get("Target") for r in rels if r.get("Id") == rid)
        path = target.lstrip("/") if target.startswith("/") else "xl/" + target
        sh = ET.fromstring(z.read(path))
        st = ET.fromstring(z.read("xl/styles.xml"))
    xfs = st.find("m:cellXfs", _NS).findall("m:xf", _NS)
    borders = st.find("m:borders", _NS).findall("m:border", _NS)
    out = []
    for side in ("top", "left", "right"):
        for c in sh.iter(f"{{{_NS['m']}}}c"):
            sid = int(c.get("s", "0"))
            border = borders[int(xfs[sid].get("borderId", "0"))]
            el = border.find(f"m:{side}", _NS)
            if el is not None and el.get("style"):
                out.append((side, c.get("r"), el.get("style")))
    return out


def main(argv):
    if len(argv) != 4:
        print(__doc__)
        return 2
    book, sheet, result = argv[1:]
    ws = load_workbook(book)[sheet]
    lines = []
    for rng in sorted(str(r) for r in ws.merged_cells.ranges):
        lines.append(f"merge {rng}")
    for col, dim in sorted(ws.column_dimensions.items()):
        if dim.width is not None and dim.customWidth:
            lines.append(f"width {col} {round(float(dim.width), 2):g}")
    for row in ws.iter_rows():
        for cell in row:
            style = cell.border.bottom.style if cell.border is not None else None
            if style:
                lines.append(f"bottom {cell.coordinate} {style}")
    for row in ws.iter_rows():
        for cell in row:
            if cell.value is not None and str(cell.value) != "":
                text = str(cell.value).replace("\n", "\\n")
                lines.append(f"value {cell.coordinate} {text}")
    # Appended after the original facts so existing suites that read the
    # lines above see an unchanged prefix.
    for side, ref, style in _raw_sides(book, sheet):
        lines.append(f"{side} {ref} {style}")
    for row in ws.iter_rows():
        for cell in row:
            if cell.font is not None and cell.font.b:
                lines.append(f"bold {cell.coordinate}")
    with open(result, "w", encoding="utf-8") as fh:
        fh.write("\n".join(lines) + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
