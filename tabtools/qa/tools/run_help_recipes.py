#!/usr/bin/env python3
"""Execute every numbered tabtools_tips recipe in a fresh Stata process."""

from __future__ import annotations

import argparse
import re
import shutil
import subprocess
import sys
from pathlib import Path


TITLE_RE = re.compile(r"^\{title:(\d+)\.\s*(.+)\}$")
CMD_RE = re.compile(r"\{cmd:([^{}]*)\}")


def extract_recipes(help_path: Path) -> list[tuple[int, str, list[str]]]:
    lines = help_path.read_text(encoding="utf-8").splitlines()
    try:
        start = next(i for i, line in enumerate(lines) if "{marker recipes}" in line)
    except StopIteration as exc:
        raise RuntimeError("tabtools_tips help has no recipes marker") from exc

    recipes: list[tuple[int, str, list[str]]] = []
    number: int | None = None
    title = ""
    commands: list[str] = []
    current: list[str] = []

    def finish_command() -> None:
        nonlocal current
        if current:
            commands.append(" ".join(current).strip())
            current = []

    def finish_recipe() -> None:
        nonlocal commands
        finish_command()
        if number is not None:
            recipes.append((number, title, commands))
        commands = []

    for line in lines[start + 1 :]:
        if line == "{title:Also see}":
            break
        match = TITLE_RE.match(line)
        if match:
            finish_recipe()
            number = int(match.group(1))
            title = match.group(2)
            continue
        if number is None:
            continue
        fragments = CMD_RE.findall(line)
        if not fragments:
            continue
        if "{phang2}" in line:
            finish_command()
        current.extend(fragment.strip() for fragment in fragments)

    finish_recipe()
    expected = list(range(1, len(recipes) + 1))
    actual = [number for number, _title, _commands in recipes]
    if actual != expected or len(recipes) != 21:
        raise RuntimeError(f"expected recipes 1-21, found {actual}")
    empty = [number for number, _title, cmds in recipes if not cmds]
    if empty:
        raise RuntimeError(f"recipes contain no commands: {empty}")
    return recipes


def stata_quote(value: str) -> str:
    return value.replace('"', '""')


def build_do(number: int, package_dir: Path, commands: list[str]) -> str:
    body = "\n".join(commands)
    return f"""* Generated from tabtools_tips.sthlp recipe {number}
clear all
set more off
set varabbrev off
version 17.0
adopath ++ "{stata_quote(str(package_dir))}"
capture noisily {{
{body}
}}
local recipe_rc = _rc
if `recipe_rc' {{
    display as error "RESULT: tips_recipe recipe={number} pass=0 fail=1 rc=`recipe_rc'"
    exit `recipe_rc'
}}
display "RESULT: tips_recipe recipe={number} pass=1 fail=0 rc=0"
exit 0
"""


def run_recipe(
    stata: str,
    output_root: Path,
    package_dir: Path,
    number: int,
    title: str,
    commands: list[str],
) -> tuple[bool, str]:
    recipe_dir = output_root / f"recipe_{number:02d}"
    recipe_dir.mkdir(parents=True, exist_ok=True)
    do_path = recipe_dir / f"recipe_{number:02d}.do"
    do_path.write_text(build_do(number, package_dir, commands), encoding="utf-8")
    completed = subprocess.run(
        [stata, "-b", "do", do_path.name],
        cwd=recipe_dir,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.STDOUT,
        timeout=240,
        check=False,
    )
    log_path = recipe_dir / f"recipe_{number:02d}.log"
    log_text = log_path.read_text(encoding="utf-8", errors="replace") if log_path.exists() else ""
    marker = f"RESULT: tips_recipe recipe={number} pass=1 fail=0 rc=0"
    passed = completed.returncode == 0 and marker in log_text
    if passed:
        return True, f"PASS recipe {number}: {title}"
    tail = "\n".join(log_text.splitlines()[-25:])
    return False, (
        f"FAIL recipe {number}: {title} (process rc={completed.returncode})\n{tail}"
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--help-file", type=Path, required=True)
    parser.add_argument("--package-dir", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--stata", default="stata-mp")
    args = parser.parse_args()

    if shutil.which(args.stata) is None:
        print(f"Stata executable not found: {args.stata}", file=sys.stderr)
        return 127
    recipes = extract_recipes(args.help_file)
    args.output_dir.mkdir(parents=True, exist_ok=True)

    failures = 0
    for number, title, commands in recipes:
        passed, detail = run_recipe(
            args.stata,
            args.output_dir,
            args.package_dir.resolve(),
            number,
            title,
            commands,
        )
        print(detail)
        failures += int(not passed)

    print(
        f"RESULT: tabtools_tips_recipes tests={len(recipes)} "
        f"pass={len(recipes) - failures} fail={failures}"
    )
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
