#!/usr/bin/env python3
"""Audit shipped Stata program declarations and varabbrev wrappers.

Package: tabtools
Purpose: Release-contract QA support
Author: Timothy P Copeland, Karolinska Institutet
"""

from __future__ import annotations

import argparse
import re
from pathlib import Path


PROGRAM_RE = re.compile(
    r"^program\s+(?:define\s+)?(?P<name>[A-Za-z_][A-Za-z0-9_]*)"
    r"(?P<suffix>\s*,.*)?$",
    re.IGNORECASE,
)
CLASS_RE = re.compile(r",\s*(?:rclass|eclass|nclass)\b", re.IGNORECASE)
RC_SAVE_RE = re.compile(
    r"\blocal\s+[A-Za-z_][A-Za-z0-9_]*\s*=\s*_rc\b", re.IGNORECASE
)


def program_blocks(path: Path) -> list[tuple[str, str, str]]:
    """Return (name, declaration, source segment) for each Stata program."""
    lines = path.read_text(encoding="utf-8").splitlines()
    starts: list[tuple[int, str, str]] = []
    for index, line in enumerate(lines):
        declaration = line.strip()
        match = PROGRAM_RE.fullmatch(declaration)
        if match:
            starts.append((index, match.group("name"), declaration))

    blocks: list[tuple[str, str, str]] = []
    for position, (start, name, declaration) in enumerate(starts):
        stop = starts[position + 1][0] if position + 1 < len(starts) else len(lines)
        blocks.append((name, declaration, "\n".join(lines[start:stop])))
    return blocks


def audit(pkg_dir: Path) -> tuple[int, list[str], list[str]]:
    class_missing: list[str] = []
    wrapper_missing: list[str] = []
    program_count = 0

    for ado_path in sorted(pkg_dir.glob("*.ado")):
        for name, declaration, block in program_blocks(ado_path):
            program_count += 1
            identity = f"{ado_path.name}:{name}"
            lower_block = block.lower()

            if not CLASS_RE.search(declaration):
                class_missing.append(identity)

            has_save = "c(varabbrev)" in lower_block
            has_off = "set varabbrev off" in lower_block
            has_capture = "capture noisily {" in lower_block
            has_rc = RC_SAVE_RE.search(block) is not None
            has_restore = any(
                "set varabbrev " in line.lower()
                and "set varabbrev off" not in line.lower()
                for line in block.splitlines()
            )
            has_conditional_rc = any(
                line.strip().lower().startswith("if ") and "rc" in line.lower()
                for line in block.splitlines()
            )
            has_rc_exit = any(
                re.search(r"\b(?:exit|error)\b", line, re.IGNORECASE)
                and "rc" in line.lower()
                for line in block.splitlines()
            )
            has_exit = has_conditional_rc and has_rc_exit
            block_lines = block.splitlines()
            has_unguarded_success_exit = False
            for line_number, line in enumerate(block_lines):
                stripped = line.strip()
                if stripped.startswith(("*", "//")):
                    continue
                if not re.search(r"\bexit\s*(?://.*)?$", stripped, re.IGNORECASE):
                    continue
                prior = "\n".join(block_lines[max(0, line_number - 3) : line_number]).lower()
                if "set varabbrev " not in prior:
                    has_unguarded_success_exit = True
                    break

            if not all((has_save, has_off, has_capture, has_rc, has_restore, has_exit)) or has_unguarded_success_exit:
                wrapper_missing.append(identity)

    return program_count, class_missing, wrapper_missing


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("pkg_dir", type=Path)
    parser.add_argument("--status-file", required=True, type=Path)
    args = parser.parse_args()

    program_count, class_missing, wrapper_missing = audit(args.pkg_dir)
    passed = program_count == 73 and not class_missing and not wrapper_missing
    verdict = "PASS" if passed else "FAIL"
    summary = (
        f"{verdict} programs={program_count} class_missing={len(class_missing)} "
        f"wrapper_missing={len(wrapper_missing)}"
    )
    args.status_file.write_text(summary + "\n", encoding="utf-8")
    print(summary)
    for identity in class_missing:
        print(f"CLASS MISSING: {identity}")
    for identity in wrapper_missing:
        print(f"VARABBREV WRAPPER MISSING: {identity}")
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
