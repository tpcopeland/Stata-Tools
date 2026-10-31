#!/usr/bin/env python3
"""Check a tabtools LaTeX table export: structure, escaping, compile, text.

Package: tabtools
Purpose: QA support for latex() / tabtools set latex
Author: Timothy P Copeland, Karolinska Institutet

Usage:
    python3 check_latex.py FILE.tex [options]

Always checked, for every table in the file:
  * \\begin/\\end environments balance and nest;
  * each table is "% tabtools LaTeX table; ..." comment, \\begin{table},
    \\centering, optional \\caption + \\label, one tabular, optional note;
  * rule order inside the tabular: \\toprule first, at most one \\midrule
    (header rows above it), \\bottomrule last; \\cmidrule only under a header
    row and only over a column range that row spans with \\multicolumn;
    \\addlinespace only between body rows, never first, last or doubled;
  * every row has as many cells as the tabular column spec has columns
    (\\multicolumn{n} counts n); a header spanner is {c}; in the body a
    \\multicolumn{k}{l}{x} is the whole row (text in column 1 only) and
    reads as x followed by k-1 blank cells for --parity-csv;
  * no unescaped LaTeX special in any cell, caption or note paragraph;
  * a complete document (texdocument) is exactly the frame
    \\documentclass{article}, \\usepackage{booktabs}, \\begin{document},
    the tables, \\end{document} -- nothing else outside the tables.

Options:
  --compile             pdflatex -halt-on-error (twice) in a temporary
                        directory on the harness
                        \\documentclass{article}\\usepackage{booktabs}
                        \\begin{document}\\input{...}\\end{document} -- the
                        documented minimal preamble and nothing else. A
                        "Missing character" or "multiply defined" warning in
                        the log fails the check. A complete document is
                        compiled as it is, with no harness.
  --document yes|no     the file is (yes) or is not (no) a complete document.
  --layout KEY=VALUE    that table's texopts() layout: placement=<spec>,
                        centering|captionleft|fit|landscape=yes|no,
                        captionpos=above|below|none, size=<name>|none,
                        label=<key>. Always checked: a "% texopts() also
                        requires" line names exactly the packages the layout
                        needs, and a document's preamble loads them.
  --pdftext NEEDLE      the pdftotext output of the compiled PDF contains
                        NEEDLE (whitespace collapsed); implies --compile.
  --pdftext-absent S    ... does not contain S; implies --compile.
  --contains S          the .tex source contains S.
  --absent S            the .tex source does not contain S.
  --needles FILE        UTF-8 file, one "kind<TAB>text" line per needle,
                        kind = contains | absent | pdftext | pdftext-absent
                        (for text a Stata shell line cannot carry).
  --tables N            the file holds exactly N tables.
  --table I             table (1-based) that --cols, --spans, --header-rows,
                        --body-rows and --parity-csv inspect (default 1).
  --cols K              that table's tabular has K columns.
  --header-rows N       that table has N header rows (above \\midrule).
  --body-rows N         that table has N body rows (\\addlinespace excluded).
  --spans "r:c1-c2,..." the set of \\multicolumn spans in that table's
                        header rows is exactly this set (r = header row,
                        1-based within the header block); "none" = no spans.
                        Each span not in the last header row must carry
                        \\cmidrule(lr){c1-c2} under its row.
  --parity-csv FILE     de-escaped body cells equal the CSV's cells, row for
                        row. Rows blank in every cell are dropped on both
                        sides unless --keep-blank.
  --csv-rows A:B        CSV rows (1-based, inclusive) that are the body;
                        B may be empty (to the end) or negative (-1 = last).
  --keep-blank          keep all-blank rows in the parity comparison.
  --pdf-out FILE        keep the compiled PDF here; implies --compile.
  --text-out FILE       write the pdftotext output here; implies --compile.
  --result FILE         write "PASS" or "FAIL: <first problem>" here.

Exit status 0 on PASS, 1 on FAIL.
"""

from __future__ import annotations

import argparse
import csv
import re
import shutil
import subprocess
import sys
import tempfile
import unicodedata
from pathlib import Path

BS = "\\"
HEADER_COMMENT = "% tabtools LaTeX table; requires \\usepackage{booktabs}"
HARNESS = (
    "\\documentclass{article}\\usepackage{booktabs}\n"
    "\\begin{document}\n"
    "\\input{table.tex}\n"
    "\\end{document}\n"
)

# Inverse of the writer's escape map. One regex alternation, applied in a
# single left-to-right pass, so a replacement is never re-read.
SIMPLE = {
    "\\textbackslash{}": "\\",
    "\\{": "{",
    "\\}": "}",
    "\\$": "$",
    "\\&": "&",
    "\\#": "#",
    "\\%": "%",
    "\\_": "_",
    "\\textasciicircum{}": "^",
    "\\textasciitilde{}": "~",
    "\\textless{}": "<",
    "\\textgreater{}": ">",
    "\\textbar{}": "|",
    "\\ldots{}": "\u2026",
    "\\dag{}": "\u2020",
    "\\ddag{}": "\u2021",
    "\\S{}": "\u00a7",
    "\\textbullet{}": "\u2022",
    "\\textsuperscript{1}": "\u00b9",
    "\\textsuperscript{2}": "\u00b2",
    "\\textsuperscript{3}": "\u00b3",
    "\\ensuremath{-}": "\u2212",
    "\\ensuremath{^\\circ}": "\u00b0",
    "\\nobreakspace{}": "\u00a0",
    '\\texttt{"}': '"',
    "\\enspace{}": "\u2002",
    "\\quad{}": "\u2003",
    "\\,": "\u2009",
    "\\ensuremath{'}": "\u2032",
    "\\ensuremath{''}": "\u2033",
    "\\textperthousand{}": "\u2030",
    "\\textonehalf{}": "\u00bd",
    "\\textonequarter{}": "\u00bc",
    "\\textthreequarters{}": "\u00be",
    "\\textregistered{}": "\u00ae",
    "\\texttrademark{}": "\u2122",
    "\\textcopyright{}": "\u00a9",
    "\\P{}": "\u00b6",
    # empty group: the writer's ligature breaker ("-{}-", "?{}`", "'{}'")
    "{}": "",
}
MATH = {
    "pm": "\u00b1", "times": "\u00d7", "div": "\u00f7", "geq": "\u2265",
    "leq": "\u2264", "neq": "\u2260", "approx": "\u2248",
    "rightarrow": "\u2192", "leftarrow": "\u2190", "cdot": "\u00b7",
    "mu": "\u03bc",
    "alpha": "\u03b1", "beta": "\u03b2", "gamma": "\u03b3", "delta": "\u03b4",
    "varepsilon": "\u03b5", "zeta": "\u03b6", "eta": "\u03b7",
    "theta": "\u03b8", "iota": "\u03b9", "kappa": "\u03ba",
    "lambda": "\u03bb", "nu": "\u03bd", "xi": "\u03be", "pi": "\u03c0",
    "rho": "\u03c1", "varsigma": "\u03c2", "sigma": "\u03c3",
    "tau": "\u03c4", "upsilon": "\u03c5", "varphi": "\u03c6", "chi": "\u03c7",
    "psi": "\u03c8", "omega": "\u03c9", "vartheta": "\u03d1", "phi": "\u03d5",
    "varpi": "\u03d6", "varrho": "\u03f1", "epsilon": "\u03f5",
    "Gamma": "\u0393", "Delta": "\u0394", "Theta": "\u0398",
    "Lambda": "\u039b", "Xi": "\u039e", "Pi": "\u03a0", "Sigma": "\u03a3",
    "Upsilon": "\u03a5", "Phi": "\u03a6", "Psi": "\u03a8", "Omega": "\u03a9",
    "infty": "\u221e", "ast": "\u2217", "surd": "\u221a", "neg": "\u00ac",
    "Rightarrow": "\u21d2", "uparrow": "\u2191", "downarrow": "\u2193",
    "leftrightarrow": "\u2194", "mp": "\u2213", "equiv": "\u2261",
    "propto": "\u221d",
}
TOKEN_RE = re.compile(
    "|".join(re.escape(k) for k in sorted(SIMPLE, key=len, reverse=True))
    + r"|\\ensuremath\{\\([A-Za-z]+)\}"
)
# The CSV side of the parity comparison: the characters whose LaTeX form
# cannot be inverted unambiguously (a literal "--" and an en dash are both
# written "--"), plus the writer's whitespace rule.
CSV_NORMAL = {
    "\u2013": "--", "\u2014": "---", "\u2018": "`", "\u2019": "'",
    "\u201c": "``", "\u201d": "''", "\u00b5": "\u03bc",
    # one LaTeX spelling (\,) for three thin spaces; zero-width dropped
    "\u200a": "\u2009", "\u202f": "\u2009", "\u200b": "", "\ufeff": "",
    "\r\n": " ", "\r": " ", "\n": " ",
}
CSV_NORMAL_RE = re.compile("|".join(re.escape(k) for k in sorted(CSV_NORMAL, key=len, reverse=True)))
CTRL_RE = re.compile(r"[\x00-\x1f\x7f]")

# Every legal escape: the de-escape table itself, so the two cannot drift.
ESCAPE_OK_RE = re.compile(
    "|".join(re.escape(k) for k in sorted(SIMPLE, key=len, reverse=True))
    + r"|\\ensuremath\{\\(?:" + "|".join(MATH) + r")\}"
)
# ~ and " are specials too: the writer spells NBSP \nobreakspace{} and a
# double quote \texttt{"}, so a raw one never comes from it.
SPECIALS = set("\\{}$&#%_^<>|~\"")
MULTI_RE = re.compile(r"^\\multicolumn\{(\d+)\}\{([cl])\}\{(.*)\}$", re.S)
HSPACE_RE = re.compile(r"^\\hspace\*\{([0-9.]+)em\}")
BOLD_RE = re.compile(r"^\\textbf\{(.*)\}$", re.S)
CMID_RE = re.compile(r"\\cmidrule\(lr\)\{(\d+)-(\d+)\}")
ENV_RE = re.compile(r"\\(begin|end)\{([^}]*)\}")


class Fail(Exception):
    pass


def unwrap(cell: str) -> tuple[str, int, str]:
    """Strip the writer's wrappers: returns (inner text, span width, indent)."""
    width = 1
    indent = ""
    m = MULTI_RE.match(cell)
    if m:
        width = int(m.group(1))
        cell = m.group(3)
    m = HSPACE_RE.match(cell)
    if m:
        indent = " " * round(float(m.group(1)) * 2)
        cell = cell[m.end():]
    m = BOLD_RE.match(cell)
    if m:
        cell = m.group(1)
    return cell, width, indent


def bad_specials(text: str) -> str:
    """Return the unescaped specials left after removing every legal escape."""
    rest = ESCAPE_OK_RE.sub("", text)
    return "".join(ch for ch in rest if ch in SPECIALS)


def de_escape(text: str) -> str:
    def repl(m: re.Match) -> str:
        if m.group(1) is not None:
            name = m.group(1)
            if name not in MATH:
                raise Fail(f"unknown \\ensuremath command \\{name}")
            return MATH[name]
        return SIMPLE[m.group(0)]

    return TOKEN_RE.sub(repl, text)


def split_row(line: str) -> list[str]:
    """Split one tabular row on unescaped & at brace depth 0."""
    s = line.rstrip()
    if not s.endswith(BS + BS):
        raise Fail(f"row does not end with \\\\: {line!r}")
    body = s[:-2]
    if body.startswith("{}"):
        body = body[2:]
    cells: list[str] = []
    cur: list[str] = []
    depth = 0
    i = 0
    while i < len(body):
        ch = body[i]
        if ch == BS:
            j = i + 1
            if j < len(body) and body[j].isalpha():
                while j < len(body) and body[j].isalpha():
                    j += 1
                if j < len(body) and body[j] == "*":
                    j += 1
            else:
                j = i + 2
            cur.append(body[i:j])
            i = j
            continue
        if ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth < 0:
                raise Fail(f"unbalanced }} in row: {line!r}")
        elif ch == "&" and depth == 0:
            cells.append("".join(cur).strip())
            cur = []
            i += 1
            continue
        cur.append(ch)
        i += 1
    if depth != 0:
        raise Fail(f"unbalanced {{ in row: {line!r}")
    cells.append("".join(cur).strip())
    return cells


def braced(text: str, start: int) -> tuple[str, int]:
    """Content of the brace group opening at text[start] (escapes honoured)."""
    if start >= len(text) or text[start] != "{":
        raise Fail("expected {")
    depth = 0
    i = start
    while i < len(text):
        ch = text[i]
        if ch == BS:
            i += 2
            continue
        if ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                return text[start + 1:i], i + 1
        i += 1
    raise Fail("unterminated brace group")


def check_environments(text: str) -> None:
    stack: list[str] = []
    for line in text.splitlines():
        if line.lstrip().startswith("%"):
            continue
        for m in ENV_RE.finditer(line):
            if m.group(1) == "begin":
                stack.append(m.group(2))
            else:
                if not stack or stack[-1] != m.group(2):
                    raise Fail(f"\\end{{{m.group(2)}}} does not close {stack[-1:] or 'nothing'}")
                stack.pop()
    if stack:
        raise Fail(f"unclosed environment(s): {stack}")


def parse_table(lines: list[str], tno: int) -> dict:
    """Parse the lines from \\begin{table} to \\end{table} inclusive."""
    t = {"caption": None, "label": None, "header": [], "cmid": {}, "body": [],
         "ncols": None, "notes": [], "placement": None, "centering": "no",
         "captionleft": "no", "captionpos": "none", "size": "none", "fit": "no"}
    i = 0

    def need(cond: bool, msg: str) -> None:
        if not cond:
            raise Fail(f"table {tno}: {msg}")

    def caption_block(i: int) -> int:
        """Optional [\\captionsetup{...}] \\caption{..} \\label{..}; returns next i."""
        if lines[i] == CAPLEFT:
            t["captionleft"] = "yes"
            i += 1
            need(lines[i].startswith(BS + "caption{"), "\\captionsetup without \\caption")
        if not lines[i].startswith(BS + "caption{"):
            return i
        content, end = braced(lines[i], len(BS + "caption"))
        need(end == len(lines[i]), f"trailing text after caption: {lines[i]!r}")
        t["caption"] = content
        i += 1
        need(lines[i].startswith(BS + "label{") and lines[i].endswith("}"),
             f"\\caption without \\label{{...}}: {lines[i]!r}")
        t["label"] = lines[i][len(BS + "label{"):-1]
        need(re.fullmatch(r"[A-Za-z0-9_:.\-]+", t["label"]) is not None,
             f"label has characters outside [A-Za-z0-9_:.-]: {t['label']!r}")
        return i + 1

    m = re.fullmatch(r"\\begin\{table\}\[(H|[htbp!]*[htbp][htbp!]*)\]", lines[i])
    need(m is None or m.group(1).count("!") <= 1, f"more than one ! in {lines[i]!r}")
    need(m is not None, f"expected \\begin{{table}}[placement], got {lines[i]!r}")
    t["placement"] = m.group(1)
    i += 1
    if lines[i] == BS + "centering":
        t["centering"] = "yes"
        i += 1
    j = caption_block(i)
    if j != i:
        t["captionpos"] = "above"
    i = j
    need(not lines[i].startswith(BS + "label"), "\\label without \\caption")
    if lines[i] in SIZES:
        t["size"] = lines[i][1:]
        i += 1
    if lines[i] == FIT_OPEN:
        t["fit"] = "yes"
        i += 1
    m = re.fullmatch(r"\\begin\{tabular\}\{([lcr]+)\}", lines[i])
    need(m is not None, f"expected \\begin{{tabular}}{{spec}}, got {lines[i]!r}")
    spec = m.group(1)
    need(spec[0] == "l" and set(spec[1:]) <= {"c"}, f"column spec {spec!r} is not l followed by c's")
    t["ncols"] = len(spec)
    i += 1
    need(lines[i] == BS + "toprule", f"expected \\toprule after tabular, got {lines[i]!r}")
    i += 1

    rows: list[tuple[str, list[str]]] = []  # ("row", cells) | ("cmid", ranges) | ("mid",) | ("space",)
    while i < len(lines) and lines[i] != BS + "bottomrule":
        line = lines[i]
        if line == BS + "midrule":
            rows.append(("mid", []))
        elif line == BS + "addlinespace":
            rows.append(("space", []))
        elif line.startswith(BS + "cmidrule"):
            need(CMID_RE.sub("", line).strip() == "", f"malformed cmidrule line {line!r}")
            rows.append(("cmid", [f"{a}-{b}" for a, b in CMID_RE.findall(line)]))
        elif line.startswith(BS + "toprule") or line.startswith(BS + "bottomrule"):
            raise Fail(f"table {tno}: misplaced rule {line!r}")
        else:
            rows.append(("row", split_row(line)))
        i += 1
    need(i < len(lines), "no \\bottomrule")
    i += 1
    want_end = BS + "end{tabular}" + ("}" if t["fit"] == "yes" else "")
    need(lines[i] == want_end, f"expected {want_end} after \\bottomrule, got {lines[i]!r}")
    i += 1

    kinds = [k for k, _ in rows]
    need(kinds.count("mid") <= 1, "more than one \\midrule")
    if "mid" in kinds:
        cut = kinds.index("mid")
        head, body = rows[:cut], rows[cut + 1:]
        need(any(k == "row" for k, _ in head), "\\midrule with no header row above it")
    else:
        head, body = [], rows
    # header rows and their cmidrules
    for k, v in head:
        if k == "row":
            t["header"].append(v)
        elif k == "cmid":
            need(t["header"] != [], "\\cmidrule before any header row")
            t["cmid"].setdefault(len(t["header"]), []).extend(v)
        else:
            raise Fail(f"table {tno}: \\addlinespace in the header block")
    # body: no cmidrule; addlinespace only between rows, never doubled
    prev = None
    for k, v in body:
        need(k != "cmid", "\\cmidrule in the body")
        if k == "space":
            need(prev == "row", "\\addlinespace that is first in the body or doubled")
        else:
            t["body"].append(v)
        prev = k
    need(prev != "space", "\\addlinespace at the end of the body")

    # note block
    if i < len(lines) and lines[i] == BS + "par" + BS + "smallskip":
        i += 1
        need(lines[i] == "{" + BS + "footnotesize" + BS + "raggedright", f"malformed note block {lines[i]!r}")
        i += 1
        while True:
            need(i < len(lines) - 1, "unterminated note block")
            line = lines[i]
            if line.endswith(BS + "par}"):
                t["notes"].append(line[: -len(BS + "par}")])
                i += 1
                break
            need(line.endswith(BS + "par"), f"note paragraph without \\par: {line!r}")
            t["notes"].append(line[: -len(BS + "par")])
            i += 1
    if t["captionpos"] == "none":
        j = caption_block(i)
        if j != i:
            t["captionpos"] = "below"
        i = j
    need(i == len(lines) - 1 and lines[i] == BS + "end{table}", f"unexpected line {lines[i]!r} before \\end{{table}}")

    # cell counts and escaping
    spans: set[str] = set()
    for r, cells in enumerate(t["header"] + t["body"], start=1):
        total = 0
        inbody = r > len(t["header"])
        for c in cells:
            inner, width, indent = unwrap(c)
            m = MULTI_RE.match(c)
            if m and inbody:
                # a body row whose only text is in column 1: one
                # \multicolumn{k}{l} cell across the whole row
                need(m.group(2) == "l" and len(cells) == 1 and width == t["ncols"],
                     f"body row {r - len(t['header'])}: \\multicolumn must be the whole row as {{{t['ncols']}}}{{l}}: {c!r}")
            elif m:
                need(m.group(2) == "c", f"header row {r}: spanner must be centred: {c!r}")
                spans.add(f"{r}:{total + 1}-{total + width}")
            total += width
            bad = bad_specials(inner)
            need(bad == "", f"unescaped special(s) {bad!r} in cell {c!r}")
        need(total == t["ncols"], f"row {r} has {total} cells, tabular has {t['ncols']}: {cells!r}")
    for text, what in [(t["caption"], "caption")] + [(n, "note") for n in t["notes"]]:
        if text is not None:
            bad = bad_specials(text)
            need(bad == "", f"unescaped special(s) {bad!r} in {what} {text!r}")
    nh = len(t["header"])
    for r, ranges in t["cmid"].items():
        need(r < nh, f"\\cmidrule under the last header row {r}")
        for rng in ranges:
            need(f"{r}:{rng}" in spans, f"\\cmidrule(lr){{{rng}}} under header row {r} has no matching \\multicolumn")
    for s in spans:
        r, rng = s.split(":")
        if int(r) < nh:
            need(rng in t["cmid"].get(int(r), []), f"span {s} in a non-final header row has no \\cmidrule")
    t["spans"] = spans
    return t


DOC_TAIL = BS + "end{document}"
CAPLEFT = BS + "captionsetup{justification=raggedright,singlelinecheck=false}"
SIZES = {BS + s for s in ("tiny", "scriptsize", "footnotesize", "small", "normalsize", "large")}
FIT_OPEN = BS + "resizebox{" + BS + "ifdim" + BS + "width>" + BS + "linewidth" + BS + "linewidth" + BS + "else" + BS + "width" + BS + "fi}{!}{%"
ALSO_RE = re.compile(r"% texopts\(\) also requires ((?:\\usepackage\{[A-Za-z0-9]+\} ?)+)")
USEPKG_RE = re.compile(r"\\(?:usepackage|RequirePackage)\s*(?:\[[^\]]*\])?\s*\{([^}]*)\}")


LAYOUT_KEYS = ("placement", "centering", "captionleft", "captionpos", "size", "fit", "landscape", "label")


def is_document(text: str) -> bool:
    return BS + "documentclass" in text


def parse_file(text: str) -> list[dict]:
    check_environments(text)
    lines = text.splitlines()
    loaded = None
    if is_document(text):
        nb = [i for i, ln in enumerate(lines) if ln.strip()]
        if not re.fullmatch(r"\\documentclass(\[[A-Za-z0-9.=,-]+\])?\{[A-Za-z][A-Za-z0-9-]*\}", lines[nb[0]]):
            raise Fail(f"document frame: first line is not \\documentclass: {lines[nb[0]]!r}")
        beg = [i for i in nb if lines[i] == BS + "begin{document}"]
        if not beg:
            raise Fail("document frame: no \\begin{document} line")
        if lines[nb[1]] != BS + "usepackage{booktabs}":
            raise Fail("document frame: second line is not \\usepackage{booktabs}")
        loaded = set()
        for ln in lines[:beg[0]]:
            for m in USEPKG_RE.finditer(re.sub(r"(?<!\\)%.*$", "", ln)):
                loaded |= {x.strip() for x in m.group(1).split(",")}
        if lines[nb[-1]] != DOC_TAIL:
            raise Fail("document frame: last line is not \\end{document}")
        lines = lines[beg[0] + 1:nb[-1]]
    tables = []
    i = 0
    while i < len(lines):
        if lines[i] == HEADER_COMMENT:
            i += 1
            need_pk: list[str] = []
            if i < len(lines) and lines[i].startswith("% texopts()"):
                m = ALSO_RE.fullmatch(lines[i].strip())
                if m is None:
                    raise Fail(f"malformed texopts() package line {lines[i]!r}")
                need_pk = re.findall(r"\{([A-Za-z0-9]+)\}", m.group(1))
                i += 1
            land = i < len(lines) and lines[i] == BS + "begin{landscape}"
            if land:
                i += 1
            if i >= len(lines) or not lines[i].startswith(BS + "begin{table}"):
                raise Fail(f"table {len(tables) + 1}: comment line not followed by \\begin{{table}}")
            k = i
            while k < len(lines) and lines[k] != BS + "end{table}":
                k += 1
            if k == len(lines):
                raise Fail("\\begin{table} without \\end{table}")
            t = parse_table(lines[i:k + 1], len(tables) + 1)
            t["landscape"] = "yes" if land else "no"
            i = k + 1
            if land:
                if i >= len(lines) or lines[i] != BS + "end{landscape}":
                    raise Fail(f"table {len(tables) + 1}: \\begin{{landscape}} without \\end{{landscape}}")
                i += 1
            want = set()
            if t["captionleft"] == "yes":
                want.add("caption")
            if t["fit"] == "yes":
                want.add("graphicx")
            if land:
                want.add("pdflscape")
            if t["placement"] == "H":
                want.add("float")
            if set(need_pk) != want:
                raise Fail(f"table {len(tables) + 1}: package comment {sorted(need_pk)} != layout needs {sorted(want)}")
            if loaded is not None and not want <= loaded:
                raise Fail(f"table {len(tables) + 1}: document preamble lacks {sorted(want - loaded)}")
            tables.append(t)
            continue
        if lines[i].startswith(BS + "begin{table}"):
            raise Fail(f"table {len(tables) + 1}: missing the booktabs comment line")
        if lines[i].strip() != "":
            raise Fail(f"text outside any table: {lines[i]!r}")
        i += 1
    if not tables:
        raise Fail("no table found")
    return tables


def compile_tex(path: Path, pdf_out: str | None) -> str:
    """Compile on the minimal harness (a complete document as it is);
    return the pdftotext output."""
    with tempfile.TemporaryDirectory(prefix="check_latex_") as tmp:
        tmpd = Path(tmp)
        text = path.read_text(encoding="utf-8")
        if is_document(text):
            shutil.copyfile(path, tmpd / "main.tex")
        else:
            # the harness loads booktabs plus exactly the packages the
            # tables' "% texopts() also requires" lines name
            extra = sorted({p for m in ALSO_RE.finditer(text)
                            for p in re.findall(r"\{([A-Za-z0-9]+)\}", m.group(1))})
            harness = HARNESS.replace("\\usepackage{booktabs}",
                                      "\\usepackage{booktabs}" + "".join(f"\\usepackage{{{p}}}" for p in extra))
            shutil.copyfile(path, tmpd / "table.tex")
            (tmpd / "main.tex").write_text(harness, encoding="utf-8")
        for _ in range(2):
            proc = subprocess.run(
                ["pdflatex", "-interaction=nonstopmode", "-halt-on-error",
                 "-no-shell-escape", "main.tex"],
                cwd=tmpd, capture_output=True, timeout=180,
            )
            if proc.returncode != 0:
                log = (tmpd / "main.log").read_text(encoding="utf-8", errors="replace")
                err = [ln for ln in log.splitlines() if ln.startswith("!")]
                raise Fail(f"pdflatex failed: {' | '.join(err[:3]) or proc.returncode}")
        log = (tmpd / "main.log").read_text(encoding="utf-8", errors="replace")
        for bad in ("Missing character", "multiply defined"):
            if bad in log:
                hit = [ln for ln in log.splitlines() if bad in ln][:2]
                raise Fail(f"pdflatex log: {' | '.join(hit)}")
        if pdf_out:
            shutil.copyfile(tmpd / "main.pdf", pdf_out)
        proc = subprocess.run(
            ["pdftotext", "-enc", "UTF-8", "main.pdf", "main.txt"],
            cwd=tmpd, capture_output=True, timeout=60,
        )
        if proc.returncode != 0:
            raise Fail(f"pdftotext failed: {proc.stderr.decode(errors='replace')}")
        return (tmpd / "main.txt").read_text(encoding="utf-8")


def squash(s: str) -> str:
    for lig, rep in (("\ufb01", "fi"), ("\ufb02", "fl"), ("\ufb00", "ff"),
                     ("\ufb03", "ffi"), ("\ufb04", "ffl")):
        s = s.replace(lig, rep)
    # pdftotext writes accented letters decomposed (base + combining mark)
    return re.sub(r"\s+", " ", unicodedata.normalize("NFC", s)).strip()


def csv_rows(path: str, sel: str | None) -> list[list[str]]:
    with open(path, newline="", encoding="utf-8-sig") as fh:
        rows = list(csv.reader(fh))
    if sel:
        a, _, b = sel.partition(":")
        start = int(a) - 1 if a else 0
        if b == "":
            stop = len(rows)
        else:
            bi = int(b)
            stop = len(rows) + bi + 1 if bi < 0 else bi
        rows = rows[start:stop]
    return rows


def norm_csv(cell: str, first: bool) -> str:
    cell = CSV_NORMAL_RE.sub(lambda m: CSV_NORMAL[m.group(0)], cell)
    cell = CTRL_RE.sub(" ", cell)
    return cell.rstrip(" ") if first else cell.strip(" ")


def check_parity(table: dict, path: str, sel: str | None, keep_blank: bool) -> None:
    got = []
    for cells in table["body"]:
        row = []
        for j, c in enumerate(cells):
            inner, width, indent = unwrap(c)
            text = de_escape(inner)
            row.append((indent + text).rstrip(" ") if j == 0 else text.strip(" "))
            # \multicolumn{n}{l}{x}: x followed by n - 1 blank cells
            row.extend([""] * (width - 1))
        got.append(row)
    want = [[norm_csv(c, j == 0) for j, c in enumerate(r)] for r in csv_rows(path, sel)]
    if not keep_blank:
        got = [r for r in got if any(c.strip() for c in r)]
        want = [r for r in want if any(c.strip() for c in r)]
    if len(got) != len(want):
        raise Fail(f"parity: {len(got)} LaTeX body rows, {len(want)} CSV rows")
    for n, (g, w) in enumerate(zip(got, want), start=1):
        if g != w:
            raise Fail(f"parity: body row {n} differs: LaTeX {g!r} vs CSV {w!r}")


def run(args: argparse.Namespace) -> str:
    path = Path(args.path)
    if not path.is_file():
        raise Fail(f"missing file: {path}")
    text = path.read_text(encoding="utf-8")
    tables = parse_file(text)

    needles = {"contains": list(args.contains), "absent": list(args.absent),
               "pdftext": list(args.pdftext), "pdftext-absent": list(args.pdftext_absent)}
    for nf in args.needles:
        for ln in Path(nf).read_text(encoding="utf-8").splitlines():
            if not ln:
                continue
            kind, sep, val = ln.partition("\t")
            if not sep or kind not in needles:
                raise Fail(f"bad needle line {ln!r}")
            needles[kind].append(val)

    if args.document is not None and is_document(text) != (args.document == "yes"):
        raise Fail(f"expected document={args.document}, file is "
                   f"{'a complete document' if is_document(text) else 'a table fragment'}")
    if args.tables is not None and len(tables) != args.tables:
        raise Fail(f"expected {args.tables} table(s), found {len(tables)}")
    if not 1 <= args.table <= len(tables):
        raise Fail(f"--table {args.table} but the file has {len(tables)} table(s)")
    t = tables[args.table - 1]
    if args.cols is not None and t["ncols"] != args.cols:
        raise Fail(f"expected {args.cols} columns, tabular has {t['ncols']}")
    if args.header_rows is not None and len(t["header"]) != args.header_rows:
        raise Fail(f"expected {args.header_rows} header row(s), found {len(t['header'])}")
    if args.body_rows is not None and len(t["body"]) != args.body_rows:
        raise Fail(f"expected {args.body_rows} body row(s), found {len(t['body'])}")
    if args.spans is not None:
        want = set()
        for chunk in args.spans:
            for item in chunk.split(","):
                item = item.strip()
                if item and item != "none":
                    want.add(item)
        if want != t["spans"]:
            raise Fail(f"spans {sorted(t['spans'])} != expected {sorted(want)}")
    for s in needles["contains"]:
        if s not in text:
            raise Fail(f"missing expected text: {s!r}")
    for s in needles["absent"]:
        if s in text:
            raise Fail(f"unexpected text present: {s!r}")
    for kv in args.layout:
        key, sep, val = kv.partition("=")
        if not sep or key not in LAYOUT_KEYS:
            raise Fail(f"bad --layout {kv!r}; keys: {', '.join(LAYOUT_KEYS)}")
        got = t.get(key)
        if str(got) != val:
            raise Fail(f"layout {key}={got!r}, expected {val!r}")
    if args.parity_csv:
        check_parity(t, args.parity_csv, args.csv_rows, args.keep_blank)

    if args.compile or needles["pdftext"] or needles["pdftext-absent"] or args.text_out or args.pdf_out:
        pdf_text = compile_tex(path, args.pdf_out)
        if args.text_out:
            Path(args.text_out).write_text(pdf_text, encoding="utf-8")
        flat = squash(pdf_text)
        for s in needles["pdftext"]:
            if squash(s) not in flat:
                raise Fail(f"compiled PDF text lacks {s!r}")
        for s in needles["pdftext-absent"]:
            if squash(s) in flat:
                raise Fail(f"compiled PDF text contains {s!r}")
    return f"PASS tables={len(tables)} cols={t['ncols']} header={len(t['header'])} body={len(t['body'])}"


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("path")
    p.add_argument("--compile", action="store_true")
    p.add_argument("--pdftext", action="append", default=[])
    p.add_argument("--pdftext-absent", action="append", default=[])
    p.add_argument("--contains", action="append", default=[])
    p.add_argument("--absent", action="append", default=[])
    p.add_argument("--needles", action="append", default=[])
    p.add_argument("--document", choices=["yes", "no"])
    p.add_argument("--layout", action="append", default=[])
    p.add_argument("--tables", type=int)
    p.add_argument("--table", type=int, default=1)
    p.add_argument("--cols", type=int)
    p.add_argument("--header-rows", type=int)
    p.add_argument("--body-rows", type=int)
    p.add_argument("--spans", action="append")
    p.add_argument("--parity-csv")
    p.add_argument("--csv-rows")
    p.add_argument("--keep-blank", action="store_true")
    p.add_argument("--pdf-out")
    p.add_argument("--text-out")
    p.add_argument("--result")
    args = p.parse_args()
    try:
        verdict = run(args)
        status = 0
    except Fail as exc:
        verdict = f"FAIL: {exc}"
        status = 1
    except Exception as exc:  # a crash is a failure, never a pass
        verdict = f"FAIL: {type(exc).__name__}: {exc}"
        status = 1
    print(verdict)
    if args.result:
        Path(args.result).write_text(verdict + "\n", encoding="utf-8")
    return status


if __name__ == "__main__":
    sys.exit(main())
