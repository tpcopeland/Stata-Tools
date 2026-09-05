#!/usr/bin/env python3
"""Validate that every QA suite emits a parser-readable RESULT: sentinel.

The CLI result parser anchors on a digit immediately after ``tests=``,
``pass=`` and ``fail=``.  A suite that formats its counts through a Stata
display format (``%2.0f``) emits ``fail= 0``; the parser then drops the whole
suite from the manifest, and a standalone run of that suite misreads an
ordinary display line as a failure.  A suite that splits the machine fields
across several display arguments is unreadable the same way.

RB12's own shape was subtler than either: the RESULT line looked clean because
the padding was applied where the counter local was built
(``local n : display %2.0f ...``), so only the emitted text carried the extra
space.  This checker therefore refuses four idioms - a padded RESULT string, a
RESULT string whose fields are split across display arguments, a display format
left inside the string, and a RESULT line that interpolates a macro built
through one - so the padded form cannot come back unnoticed.
"""

# Package: psdash
# Purpose: QA-only static validation of RESULT: sentinel emission.
# Author: Timothy P Copeland, Karolinska Institutet

from __future__ import annotations

import argparse
import re
import tempfile
from pathlib import Path

# Mirrors _RESULT_LINE_RE in _devkit/stata_dev_cli/commands/qa/_shared.py.
PARSER_RE = re.compile(
    r"RESULT:\s+(?P<name>\S+)\s+tests=(?P<tests>\d+)\s+pass=(?P<pass>\d+)"
    r"\s+fail=(?P<fail>\d+)(?P<rest>.*)$",
    re.IGNORECASE,
)

TAG = "RESULT: "

#: ``local n : display %2.0f (...)`` and ``local n = string(x, "%2.0f")`` both
#: bake padding into the macro's value, leaving the RESULT line itself clean.
_FORMATTED_LOCAL_RE = re.compile(
    r"^\s*(?:local|global)\s+(?P<name>\w+)\s*[:=].*%-?\d*\.?\d*[a-z]",
    re.IGNORECASE,
)


def formatted_macros(text: str) -> set[str]:
    """Names of macros whose value is built through a display format."""
    return {
        m.group("name")
        for line in text.splitlines()
        for m in [_FORMATTED_LOCAL_RE.match(line)]
        if m
    }


def interpolated_macros(seg: str) -> set[str]:
    """Macro names referenced inside one sentinel string."""
    names = set(re.findall(r"`(\w+)'", seg))
    names |= set(re.findall(r"\$(\w+)", seg))
    return names


def check_line(line: str) -> str | None:
    """Return a failure reason for one sentinel-emitting source line."""
    pos = line.index(TAG)
    rest = line[pos:]
    close = rest.find('"')
    if close < 1:
        return "sentinel is not inside a closed double-quoted string"
    seg = rest[:close]
    for field in ("tests=", "pass=", "fail="):
        if field not in seg:
            return (
                f"{field!r} is emitted outside the sentinel string "
                "(split across display arguments)"
            )
    if "%" in seg:
        return "sentinel applies a display format, which pads its counts"
    if "= " in seg:
        return "sentinel has whitespace between a field and its value"
    return None


def check_file(path: Path) -> tuple[int, list[str]]:
    found = 0
    problems: list[str] = []
    text = path.read_text(encoding="utf-8", errors="replace")
    padded = formatted_macros(text)
    for lineno, line in enumerate(text.splitlines(), start=1):
        if TAG not in line or "display" not in line:
            continue
        found += 1
        reason = check_line(line)
        if reason:
            problems.append(f"{path.name}:{lineno}: {reason}")
            continue
        seg = line[line.index(TAG):]
        seg = seg[: seg.find('"')]
        via_format = sorted(interpolated_macros(seg) & padded)
        if via_format:
            problems.append(
                f"{path.name}:{lineno}: sentinel interpolates "
                f"{', '.join(via_format)}, built through a display format "
                "that pads the emitted value"
            )
    return found, problems


#: The three idioms that have produced an unreadable sentinel, each paired with
#: the fragment of the failure reason that must name it.  ``--selftest`` proves
#: the checker still refuses all three, so a green scan means something.
_SELFTEST_BAD = [
    (
        "padded value",
        'display as text "RESULT: test_probe tests=16 pass=16 fail= 0"\n',
        "whitespace between a field and its value",
    ),
    (
        "split across display arguments",
        'display as text "RESULT: test_probe tests=" %2.0f 16 " pass=" %2.0f 16\n',
        "split across display arguments",
    ),
    (
        "display format left inside the sentinel string",
        'display as text "RESULT: test_probe tests=16 pass=16 fail=%2.0f"\n',
        "applies a display format",
    ),
    (
        "count built through a display format (RB12)",
        "local n_fail : display %2.0f 0\n"
        "display as text \"RESULT: test_probe tests=16 pass=16 fail=`n_fail'\"\n",
        "built through a display format",
    ),
]

_SELFTEST_GOOD = 'display as text "RESULT: test_probe tests=16 pass=16 fail=0 skip=0"\n'


def selftest(tmp: Path) -> list[str]:
    """Return the selftest failures; empty means the checker has teeth."""
    failures: list[str] = []
    probe = tmp / "test_probe.do"
    for label, source, expected in _SELFTEST_BAD:
        probe.write_text(source, encoding="utf-8")
        found, problems = check_file(probe)
        if found < 1:
            failures.append(f"{label}: no sentinel line was even detected")
        elif not problems:
            failures.append(f"{label}: accepted, but must be refused")
        elif not any(expected in p for p in problems):
            failures.append(
                f"{label}: refused for the wrong reason ({problems[0]})"
            )
    probe.write_text(_SELFTEST_GOOD, encoding="utf-8")
    found, problems = check_file(probe)
    if found != 1 or problems:
        failures.append(
            f"well-formed sentinel was rejected ({problems or 'not detected'})"
        )
    # Finally, pin the parser this checker exists to protect: the emitted text
    # of the accepted form must match it, and RB12's emitted text must not.
    # (Only these two forms are text a suite actually emits; the other probes
    # are source idioms whose emitted text is not their source.)
    if PARSER_RE.search("RESULT: test_probe tests=16 pass=16 fail=0 skip=0") is None:
        failures.append("the CLI parser regex rejects a well-formed sentinel")
    if PARSER_RE.search("RESULT: test_probe tests=16 pass=16 fail= 0") is not None:
        failures.append("the CLI parser regex accepts a padded sentinel")
    return failures


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("qa_dir", type=Path)
    parser.add_argument("--min-sentinels", type=int, default=1)
    parser.add_argument(
        "--selftest",
        action="store_true",
        help="also prove the checker refuses the three known-bad idioms",
    )
    parser.add_argument("--result-file", type=Path, required=True)
    args = parser.parse_args()

    problems: list[str] = []
    total = 0
    try:
        if args.selftest:
            with tempfile.TemporaryDirectory() as tmp:
                problems.extend(
                    f"selftest: {f}" for f in selftest(Path(tmp))
                )
        do_files = sorted(args.qa_dir.glob("*.do"))
        if not do_files:
            raise ValueError(f"no .do files under {args.qa_dir}")
        for path in do_files:
            if path.name == "_psdash_bootstrap.do":
                continue
            found, file_problems = check_file(path)
            total += found
            problems.extend(file_problems)
        if total < args.min_sentinels:
            problems.append(
                f"found {total} sentinel lines, expected at least "
                f"{args.min_sentinels}"
            )
    except (OSError, ValueError) as exc:
        args.result_file.write_text(f"FAIL: {exc}\n", encoding="utf-8")
        return 1

    if problems:
        args.result_file.write_text(
            "FAIL: " + "; ".join(problems) + "\n", encoding="utf-8"
        )
        return 1

    args.result_file.write_text("PASS\n", encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
