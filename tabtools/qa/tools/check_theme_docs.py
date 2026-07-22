#!/usr/bin/env python3
"""Assert the documented journal themes match the ones the code actually defines.

The theme presets live in _tabtools_apply_theme (_tabtools_common.ado). Three
help files restate them in prose, and they had drifted: nejm was documented at
Arial 10pt (code: 9pt), cell at 10pt (code: 8pt), and annals as zebra-striped
(code: no zebra). Nothing caught it because prose is not executable.

This checker re-derives the table from the ado source on every run and compares
each help file's claims against it, so the docs cannot silently go stale again.

Usage: check_theme_docs.py PKG_DIR [--result-file FILE]
Exit 0 when every documented value matches the source, 1 otherwise.
"""
import argparse
import pathlib
import re
import sys

THEMES = ["lancet", "nejm", "bmj", "apa", "jama", "plos", "nature", "cell", "annals"]


def parse_source(pkg_dir):
    """Extract {theme: {font, fontsize, zebra}} from _tabtools_apply_theme."""
    src = (pkg_dir / "_tabtools_common.ado").read_text()
    start = src.index("_tabtools_apply_theme:")
    end = src.index("_tabtools_resolve_format: Resolve")
    block = src[start:end]

    out, cur = {}, None
    for line in block.split("\n"):
        m = re.search(r'"`theme\'" == "(\w+)"', line)
        if m:
            cur = m.group(1)
            out[cur] = {}
            continue
        if cur is None:
            continue
        for key in ("font", "fontsize", "zebra"):
            m = re.search(r'c_local _theme_%s\s+"([^"]*)"' % key, line)
            if m and key not in out[cur]:
                out[cur][key] = m.group(1).strip()
    return {t: v for t, v in out.items() if t in THEMES}


def check_doc(path, source, pattern_for):
    """Compare one help file's claims against the source table."""
    if not path.exists():
        return []
    text = path.read_text()
    problems = []
    for theme, truth in sorted(source.items()):
        m = pattern_for(text, theme)
        if m is None:
            continue  # this file does not document that theme
        claim = m.group(0)

        size = re.search(r"(\d+)\s*pt", claim)
        if size and size.group(1) != truth.get("fontsize"):
            problems.append(
                "%s: %s documented as %spt, source says %spt"
                % (path.name, theme, size.group(1), truth.get("fontsize"))
            )

        font = "Times New Roman" if "Times New Roman" in claim else (
            "Arial" if "Arial" in claim else None)
        if font and font != truth.get("font"):
            problems.append(
                "%s: %s documented with font %s, source says %s"
                % (path.name, theme, font, truth.get("font"))
            )

        claims_zebra = "zebra" in claim.lower()
        truth_zebra = truth.get("zebra") == "1"
        if claims_zebra != truth_zebra:
            problems.append(
                "%s: %s documented zebra=%s, source says zebra=%s"
                % (path.name, theme, claims_zebra, truth_zebra)
            )
    return problems


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("pkg_dir")
    ap.add_argument("--result-file")
    args = ap.parse_args()

    pkg_dir = pathlib.Path(args.pkg_dir)
    source = parse_source(pkg_dir)

    missing = [t for t in THEMES if t not in source]
    problems = []
    if missing:
        problems.append("source parse incomplete, themes not found: %s" % ", ".join(missing))

    # tabtools.sthlp: {synopt:{cmd:name}}Arial 9pt, ...{p_end}
    problems += check_doc(
        pkg_dir / "tabtools.sthlp", source,
        lambda t, th: re.search(r"\{synopt:\{cmd:%s\}\}([^\n]*?)\{p_end\}" % th, t),
    )
    # comptab.sthlp: {cmd:name} (Arial 9pt, academic borders)
    problems += check_doc(
        pkg_dir / "comptab.sthlp", source,
        lambda t, th: re.search(r"\{cmd:%s\}\s*\(([^)]*)\)" % th, t),
    )
    # table1_tc.sthlp: {cmd:name} - Arial 9pt, ...{p_end}
    problems += check_doc(
        pkg_dir / "table1_tc.sthlp", source,
        lambda t, th: re.search(r"\{cmd:%s\}\s*-\s*([^\n]*?)\{p_end\}" % th, t),
    )

    for p in problems:
        print("THEME DOC DRIFT: %s" % p)
    status = "FAIL" if problems else "PASS"
    print("%s: theme documentation matches _tabtools_apply_theme (%d themes checked)"
          % (status, len(source)))

    if args.result_file:
        pathlib.Path(args.result_file).write_text(status + "\n")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
