#!/usr/bin/env python3
"""Check logdoc help-table descriptions against Stata Viewer width limits."""

from __future__ import annotations

import argparse
import re
from pathlib import Path


DEFAULT_SYNOPTSET = 20
SYNOPT_DESC_INDENT = 6
SYNOPT_LAST_COL = 77

RX_SYNOPTSET = re.compile(r"\{synoptset\s+(\d+)")
RX_SYNOPT_OPEN = re.compile(r"^\{synopt\s*:")
RX_ABBREV = re.compile(r"\{(?:opth|opt|cmdab)[\s:]\s*([^{}]*)\}")
RX_LINK = re.compile(r"\{(?:helpb|help|browse|stata|view)\s+([^{}]*)\}")
RX_MANLINK = re.compile(r"\{manlink\s+\S+\s+([^{}]*)\}")
RX_STYLE = re.compile(
    r"\{(?:cmd|cmdab|it|bf|hi|res|text|err|error|input|ul|sf|sub|sup)\s*:\s*([^{}]*)\}"
)
RX_ENTITY = re.compile(r"\{(?:c\s+[^{}]*|&[A-Za-z]+)\}")
RX_DIRECTIVE = re.compile(r"\{[^{}]*\}")


def rendered_text(text: str) -> str:
    """Approximate the characters a synopt description renders in Viewer."""
    previous = None
    while previous != text:
        previous = text
        text = RX_ABBREV.sub(lambda match: match.group(1).replace(":", ""), text)
        text = RX_LINK.sub(
            lambda match: match.group(1).rsplit(":", 1)[-1].strip().strip('"'),
            text,
        )
        text = RX_MANLINK.sub(r"\1", text)
        text = RX_STYLE.sub(r"\1", text)
        text = RX_ENTITY.sub("x", text)
        text = RX_DIRECTIVE.sub("", text)
    return text


def synopt_description(line: str) -> str | None:
    stripped = line.lstrip()
    opened = RX_SYNOPT_OPEN.match(stripped)
    if opened is None:
        return None
    rest = stripped[opened.end() :]
    depth = 0
    for index, character in enumerate(rest):
        if character == "{":
            depth += 1
        elif character == "}":
            depth -= 1
            if depth < 0:
                return rest[index + 1 :].split("{p_end}")[0]
    return ""


def synopt_rows(lines: list[str]) -> list[tuple[int, str]]:
    rows: list[tuple[int, str]] = []
    index = 0
    while index < len(lines):
        description = synopt_description(lines[index])
        if description is None:
            index += 1
            continue
        start = index
        has_end = "{p_end}" in lines[index]
        parts = [description]
        following = index + 1
        while not has_end and following < len(lines):
            next_line = lines[following]
            if not next_line.strip() or next_line.lstrip().startswith("{"):
                break
            if "{p_end}" in next_line:
                parts.append(next_line.split("{p_end}")[0])
                has_end = True
            else:
                parts.append(next_line)
            following += 1
        rows.append((start + 1, " ".join(part.strip() for part in parts).strip()))
        index = following if following > index else index + 1
    return rows


def check_file(path: Path) -> list[str]:
    lines = path.read_text(encoding="utf-8").splitlines()
    synoptset = DEFAULT_SYNOPTSET
    synoptset_at: list[int] = []
    for line in lines:
        match = RX_SYNOPTSET.search(line)
        if match:
            synoptset = int(match.group(1))
        synoptset_at.append(synoptset)

    failures = []
    for line_number, description in synopt_rows(lines):
        cap = SYNOPT_LAST_COL - (
            synoptset_at[line_number - 1] + SYNOPT_DESC_INDENT
        )
        width = len(rendered_text(description).strip())
        if width > cap:
            failures.append(f"{path.name}:{line_number}: {width}>{cap}")
    return failures


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("files", nargs="+", type=Path)
    parser.add_argument("--result-file", required=True, type=Path)
    args = parser.parse_args()

    failures = [failure for path in args.files for failure in check_file(path)]
    status = "PASS" if not failures else "FAIL " + "; ".join(failures)
    args.result_file.write_text(status + "\n", encoding="utf-8")
    print(status)
    return 0 if not failures else 1


if __name__ == "__main__":
    raise SystemExit(main())
