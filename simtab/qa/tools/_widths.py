"""Effective column width, the one reader every xlsx tool shares.

Self-contained (duck-typed worksheet, no openpyxl import) so it can be deployed
next to the standalone check_xlsx.py / excel_analyzer.py copies.

Two openpyxl traps this exists to avoid:

* ``ws.column_dimensions["D"].width`` returns 13.0 for a column the file never
  sized (openpyxl's ColumnDimension default) and silently creates the entry.
* A grouped ``<col min="3" max="5" width="25">`` is stored under its first
  letter only, so ``column_dimensions["D"]`` does not see the range.

Units are the file's own ``<col width>`` units (what an explicit width is
measured in). An unset column takes, in order, the sheet's
``<sheetFormatPr defaultColWidth>`` and then the width Excel gives
``baseColWidth`` (default 8) characters: ECMA-376 18.3.1.81 defines that as
base characters plus 5 px of padding/gridline at the maximum glyph width
(7 px, Calibri 11), and Excel rounds the pixel width up to a multiple of 8
(61 -> 64 px). 64 px is stored as 64/7 truncated to 1/256 = 9.140625 (the value
in the ``<col>`` element of a default-width column; the Excel UI shows the same
column as 8.43 because it omits the 5 px of padding).
"""
from __future__ import annotations

_MAX_GLYPH_PX = 7
_PADDING_PX = 5


def _default_from_base(base_col_width: float = 8) -> float:
    pixels = int(base_col_width * _MAX_GLYPH_PX + _PADDING_PX)
    pixels = -(-pixels // 8) * 8  # Excel rounds up to a multiple of 8 px
    return int(pixels / _MAX_GLYPH_PX * 256) / 256


DEFAULT_COLUMN_WIDTH = _default_from_base(8)  # 9.140625


def sheet_default_width(ws) -> float:
    """Width of a column no ``<col>`` element covers, per the sheet's own format."""
    fmt = getattr(ws, "sheet_format", None)
    default = getattr(fmt, "defaultColWidth", None)
    if default:
        return float(default)
    base = getattr(fmt, "baseColWidth", None)
    if base and base != 8:
        return _default_from_base(base)
    return DEFAULT_COLUMN_WIDTH


def effective_column_width(ws, idx: int) -> float:
    """Width of 1-based column ``idx``, honouring grouped ``<col min max>`` ranges."""
    dims = getattr(ws, "column_dimensions", {})
    # Read without indexing: indexing creates an entry and fabricates width 13.0.
    for dim in list(dims.values()):
        lo = getattr(dim, "min", None)
        hi = getattr(dim, "max", None)
        width = getattr(dim, "width", None)
        if lo is None or hi is None or not width:
            continue
        if lo <= idx <= hi:
            return float(width)
    return sheet_default_width(ws)
