#!/usr/bin/env python3
"""Per-command OPTION coverage for tabtools.

Self-contained (no external deps, no Stata-Dev CLI): it parses each public
command's `.ado` syntax block to recover the option surface, then scans
qa/*.do for REAL invocations of each command and checks which of *that
command's* options appear in the option-portion (after the first comma).

An option counts as exercised only inside an actual invocation of its own
command -- a bare token appearing in some other command's test does not count.
This is the metric reported in qa/README.md (## Option coverage).

Usage:
    python3 qa/tools/option_coverage.py [--pkg-dir DIR] [--json]

Exit status is 0 when every testable option is exercised (the `open` option is
excluded by design -- it launches a GUI viewer and is not driven in batch).
"""
from __future__ import annotations

import argparse
import glob
import json
import os
import re
import sys

# Public commands ship a same-named .ado; helpers are _tabtools_*.
HELPER_PREFIX = "_tabtools"
# Options excluded from the testable surface (cannot be exercised in batch).
EXCLUDED = {"open"}


def public_commands(pkg_dir):
    out = []
    for f in sorted(glob.glob(os.path.join(pkg_dir, "*.ado"))):
        base = os.path.basename(f)[:-4]
        if base.startswith(HELPER_PREFIX) or base.startswith("_"):
            continue
        out.append(base)
    return out


def _join_continuations(text):
    """Collapse Stata /// line continuations into single logical lines."""
    out, buf = [], ""
    for ln in text.split("\n"):
        if "///" in ln:
            buf += " " + ln.split("///")[0]
        else:
            buf += " " + ln
            out.append(buf)
            buf = ""
    if buf:
        out.append(buf)
    return out


def _strip_comments(text):
    """Remove /* */ block comments and *|// line comments (so `syntax` in the
    header prose is not mistaken for the syntax statement)."""
    text = re.sub(r"/\*.*?\*/", " ", text, flags=re.S)
    out = []
    for ln in text.split("\n"):
        s = ln.lstrip()
        if s.startswith("*") or s.startswith("//"):
            continue
        out.append(ln)
    return "\n".join(out)


def parse_options(ado_path, cmd):
    """Return {option_name: min_abbrev} parsed from the command's syntax block."""
    text = _strip_comments(open(ado_path, encoding="utf-8", errors="replace").read())
    lines = _join_continuations(text)
    # first logical line whose statement is `syntax`
    synt = None
    for ll in lines:
        if re.match(r"\s*syntax\b", ll):
            synt = ll
            break
    if synt is None:
        return {}
    # keep only the bracketed option list(s): everything after the first comma
    ci = synt.find(",")
    if ci < 0:
        return {}
    optblob = synt[ci + 1:]
    # strip option argument specifications: NAME(...) -> NAME, but remember which
    # had parens (informational only). Tokenize on whitespace, handling (...).
    opts = {}
    i = 0
    n = len(optblob)
    token = ""
    depth = 0
    tokens = []
    for ch in optblob:
        if ch == "(":
            depth += 1
            token += ch
        elif ch == ")":
            depth -= 1
            token += ch
        elif ch in " \t[]" and depth == 0:
            if token:
                tokens.append(token)
                token = ""
        else:
            token += ch
    if token:
        tokens.append(token)
    for tok in tokens:
        m = re.match(r"^([A-Za-z][A-Za-z0-9_]*)(\(.*\))?$", tok)
        if not m:
            continue
        raw = m.group(1)
        # min-abbrev = leading uppercase run (lowercased); if none, full word
        upper = re.match(r"^[A-Z]+", raw)
        name = raw.lower()
        if upper:
            ab = upper.group(0).lower()
        else:
            ab = name
        # skip pure positional keywords (not options); `using` IS counted as
        # part of the surface (it is always exercised) to match the CLI.
        if name in ("if", "in", "weight"):
            continue
        opts[name] = ab
    return opts


def invocation_blobs(cmd, qa_lines):
    """All option-portion texts from real invocations of `cmd`."""
    tok = re.compile(r"(?<![\w.`])" + re.escape(cmd) + r"(?![\w])")
    bad_head = re.compile(
        r"\b(program|local|global|scalar|matrix|confirm|which|di|display|"
        r"assert|help|capture\s+program)\b\s*$"
    )
    blobs = []
    for ll in qa_lines:
        for m in tok.finditer(ll):
            head = ll[: m.start()]
            tail = ll[m.end():]
            if bad_head.search(head):
                continue
            if re.match(r"\s*=", tail):  # cmd = ...
                continue
            ci = tail.find(",")
            blobs.append(tail[ci + 1:] if ci >= 0 else "")
    return blobs


def option_forms(name, ab):
    forms = set()
    for L in range(len(ab), len(name) + 1):
        forms.add(name[:L].lower())
    forms.add(name.lower())
    return forms


def exercised(name, ab, blob):
    for fm in option_forms(name, ab):
        if re.search(r"(?<![\w])" + re.escape(fm) + r"\s*\(", blob):   # name(
            return True
        if re.search(r"(?<![\w])" + re.escape(fm) + r"(?![\w(])", blob):  # bare toggle
            return True
    return False


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--pkg-dir", default=None,
                    help="package root (defaults to parent of qa/ holding this tool)")
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args()

    tool_dir = os.path.dirname(os.path.abspath(__file__))       # qa/tools
    qa_dir = os.path.dirname(tool_dir)                           # qa
    pkg_dir = args.pkg_dir or os.path.dirname(qa_dir)            # package root

    qa_files = sorted(
        glob.glob(os.path.join(qa_dir, "test_*.do"))
        + glob.glob(os.path.join(qa_dir, "validation_*.do"))
    )
    qa_lines = []
    for f in qa_files:
        qa_lines.extend(_join_continuations(open(f, encoding="utf-8", errors="replace").read()))

    report = {}
    tot = cov = tot_testable = cov_testable = 0
    for cmd in public_commands(pkg_dir):
        opts = parse_options(os.path.join(pkg_dir, cmd + ".ado"), cmd)
        if not opts:
            continue
        blob = " ".join(invocation_blobs(cmd, qa_lines)).lower()
        used, missing, excluded_missing = set(), [], []
        for name, ab in opts.items():
            if exercised(name, ab, blob):
                used.add(name)
            elif name in EXCLUDED:
                excluded_missing.append(name)
            else:
                missing.append(name)
        n = len(opts)
        testable = [o for o in opts if o not in EXCLUDED]
        nt = len(testable)
        ct = sum(1 for o in testable if o in used)
        tot += n
        cov += len(used)
        tot_testable += nt
        cov_testable += ct
        report[cmd] = {
            "options": n,
            "exercised": len(used),
            "testable": nt,
            "testable_exercised": ct,
            "testable_pct": round(100 * ct / nt, 1) if nt else 100.0,
            "missing": sorted(missing),
            "excluded": sorted(excluded_missing),
        }

    overall = {
        "options": tot,
        "exercised": cov,
        "raw_pct": round(100 * cov / tot, 1) if tot else 100.0,
        "testable_options": tot_testable,
        "testable_exercised": cov_testable,
        "testable_pct": round(100 * cov_testable / tot_testable, 1) if tot_testable else 100.0,
    }

    if args.json:
        print(json.dumps({"per_command": report, "overall": overall}, indent=1))
    else:
        print(f"{'command':<14}{'opts':>5}{'testable':>9}{'exer':>6}{'pct':>7}  missing")
        for cmd, v in sorted(report.items()):
            miss = ",".join(v["missing"]) if v["missing"] else ("(open)" if v["excluded"] else "")
            print(f"{cmd:<14}{v['options']:>5}{v['testable']:>9}{v['testable_exercised']:>6}"
                  f"{v['testable_pct']:>6}%  {miss}")
        print(f"\nTestable option coverage: {cov_testable}/{tot_testable} "
              f"= {overall['testable_pct']}%  (raw incl. open: {overall['raw_pct']}%)")

    gaps = sum(len(v["missing"]) for v in report.values())
    return 0 if gaps == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
