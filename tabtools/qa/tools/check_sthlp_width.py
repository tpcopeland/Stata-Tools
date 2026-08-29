#!/usr/bin/env python3
"""Check tabtools help-table descriptions against Stata Viewer width limits."""

from __future__ import annotations

import argparse
import re
from pathlib import Path


VIEWER_LAST_COL = 77
SYNOPT_DESCRIPTION_INDENT = 6
DEFAULT_SYNOPTSET = 20
SYNOPTSET_RE = re.compile(r"\{synoptset\s+(\d+)")
SYNOPT_OPEN_RE = re.compile(r"^\{synopt\s*:")

ABBREV_RE = re.compile(r"\{(?:opth|opt|cmdab)[\s:]\s*([^{}]*)\}")
LINK_RE = re.compile(r"\{(?:helpb|help|browse|stata|view)\s+([^{}]*)\}")
MANLINK_RE = re.compile(r"\{manlink\s+\S+\s+([^{}]*)\}")
STYLE_RE = re.compile(
    r"\{(?:cmd|cmdab|it|bf|hi|res|text|err|error|input|ul|sf|sub|sup)\s*:\s*([^{}]*)\}"
)
ENTITY_RE = re.compile(r"\{(?:c\s+[^{}]*|&[A-Za-z]+)\}")
DIRECTIVE_RE = re.compile(r"\{[^{}]*\}")


def rendered_text(fragment: str) -> str:
    """Approximate the characters a synopt description displays."""
    previous = None
    while previous != fragment:
        previous = fragment
        fragment = ABBREV_RE.sub(lambda m: m.group(1).replace(":", ""), fragment)
        fragment = LINK_RE.sub(
            lambda m: m.group(1).rsplit(":", 1)[-1].strip().strip('"'), fragment
        )
        fragment = MANLINK_RE.sub(r"\1", fragment)
        fragment = STYLE_RE.sub(r"\1", fragment)
        fragment = ENTITY_RE.sub("x", fragment)
        fragment = DIRECTIVE_RE.sub("", fragment)
    return fragment


def synopt_description(line: str) -> str | None:
    stripped = line.lstrip()
    opened = SYNOPT_OPEN_RE.match(stripped)
    if opened is None:
        return None
    rest = stripped[opened.end() :]
    depth = 0
    for index, char in enumerate(rest):
        if char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
            if depth < 0:
                return rest[index + 1 :].split("{p_end}")[0]
    return ""


def synopt_rows(lines: list[str]) -> list[tuple[int, str, bool]]:
    """Return logical synopt descriptions, joining source continuations."""
    rows: list[tuple[int, str, bool]] = []
    index = 0
    while index < len(lines):
        description = synopt_description(lines[index])
        if description is None:
            index += 1
            continue
        start = index
        has_p_end = "{p_end}" in lines[index]
        parts = [description]
        cursor = index + 1
        while not has_p_end and cursor < len(lines):
            next_line = lines[cursor]
            if not next_line.strip() or next_line.lstrip().startswith("{"):
                break
            if "{p_end}" in next_line:
                parts.append(next_line.split("{p_end}")[0])
                has_p_end = True
            else:
                parts.append(next_line)
            cursor += 1
        joined = " ".join(part.strip() for part in parts).strip()
        rows.append((start + 1, joined, has_p_end))
        index = cursor if cursor > index else index + 1
    return rows


def check_file(path: Path) -> list[str]:
    lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
    synoptset = DEFAULT_SYNOPTSET
    synoptset_at: list[int] = []
    for line in lines:
        match = SYNOPTSET_RE.search(line)
        if match:
            synoptset = int(match.group(1))
        synoptset_at.append(synoptset)

    issues: list[str] = []
    for line_number, description, has_p_end in synopt_rows(lines):
        if not has_p_end:
            issues.append(f"{path.name}:{line_number}: missing {{p_end}}")
            continue
        cap = VIEWER_LAST_COL - (
            synoptset_at[line_number - 1] + SYNOPT_DESCRIPTION_INDENT
        )
        width = len(rendered_text(description).strip())
        if width > cap:
            issues.append(f"{path.name}:{line_number}: description {width}>{cap}")
    return issues


def resolve_paths(targets: list[str]) -> list[Path]:
    paths: list[Path] = []
    for target in targets:
        path = Path(target)
        if path.is_dir():
            paths.extend(sorted(path.glob("*.sthlp")))
        else:
            paths.append(path)
    return paths


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("targets", nargs="+")
    parser.add_argument("--result-file")
    args = parser.parse_args()

    paths = resolve_paths(args.targets)
    issues: list[str] = []
    if not paths:
        issues.append("no .sthlp files found")
    for path in paths:
        if not path.is_file():
            issues.append(f"missing file: {path}")
        else:
            issues.extend(check_file(path))

    result = "PASS" if not issues else "FAIL"
    if args.result_file:
        Path(args.result_file).write_text(result + "\n", encoding="utf-8")
    for issue in issues:
        print(issue)
    print(f"RESULT: {result} ({len(paths)} files, {len(issues)} issues)")
    return 0 if not issues else 1


if __name__ == "__main__":
    raise SystemExit(main())
