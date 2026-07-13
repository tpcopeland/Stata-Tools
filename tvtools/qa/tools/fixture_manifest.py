#!/usr/bin/env python3
"""Build or verify the authoritative tvtools QA fixture manifest."""

from __future__ import annotations

import argparse
import csv
import hashlib
import sys
from pathlib import Path

import pyreadstat


FIELDS = (
    "fixture",
    "sha256",
    "bytes",
    "rows",
    "columns",
    "schema",
    "producer",
    "consumers",
    "classification",
)


def digest(path: Path) -> str:
    hasher = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            hasher.update(block)
    return hasher.hexdigest()


def relative(path: Path, qa_dir: Path) -> str:
    return path.relative_to(qa_dir).as_posix()


def source_inventory(qa_dir: Path) -> tuple[dict[Path, list[str]], list[Path]]:
    sources: dict[Path, list[str]] = {}
    for path in sorted(qa_dir.rglob("*.do")):
        sources[path] = path.read_text(encoding="utf-8", errors="replace").splitlines()
    root_suites = sorted(qa_dir.glob("*.do"))
    return sources, root_suites


def provenance(
    fixture: Path,
    qa_dir: Path,
    sources: dict[Path, list[str]],
    root_suites: list[Path],
) -> tuple[str, str]:
    name = fixture.name
    producers: list[str] = []
    for source, lines in sources.items():
        for line in lines:
            before, found, _ = line.partition(name)
            if found and "save" in before.lower():
                producers.append(relative(source, qa_dir))
                break
    if not producers:
        producers = ["source-control/manual"]

    consumers = [
        relative(source, qa_dir)
        for source in root_suites
        if name in "\n".join(sources[source])
    ]
    if not consumers:
        consumers = ["source-control/retained-canonical"]

    return ";".join(sorted(set(producers))), ";".join(consumers)


def describe_fixture(
    fixture: Path,
    qa_dir: Path,
    sources: dict[Path, list[str]],
    root_suites: list[Path],
) -> dict[str, str]:
    _, metadata = pyreadstat.read_dta(str(fixture), metadataonly=True)
    variable_types = metadata.readstat_variable_types
    display_formats = metadata.original_variable_types
    schema = "|".join(
        f"{name}:{variable_types.get(name, '')}:{display_formats.get(name, '')}"
        for name in metadata.column_names
    )
    producer, consumers = provenance(fixture, qa_dir, sources, root_suites)
    return {
        "fixture": fixture.name,
        "sha256": digest(fixture),
        "bytes": str(fixture.stat().st_size),
        "rows": str(metadata.number_rows),
        "columns": str(metadata.number_columns),
        "schema": schema,
        "producer": producer,
        "consumers": consumers,
        "classification": "canonical",
    }


def build_rows(qa_dir: Path) -> list[dict[str, str]]:
    data_dir = qa_dir / "data"
    sources, root_suites = source_inventory(qa_dir)
    return [
        describe_fixture(path, qa_dir, sources, root_suites)
        for path in sorted(data_dir.glob("*.dta"))
    ]


def write_manifest(manifest: Path, rows: list[dict[str, str]]) -> None:
    with manifest.open("w", encoding="utf-8", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=FIELDS, delimiter="\t")
        writer.writeheader()
        writer.writerows(rows)


def read_manifest(manifest: Path) -> tuple[list[str], list[dict[str, str]]]:
    with manifest.open("r", encoding="utf-8", newline="") as stream:
        reader = csv.DictReader(stream, delimiter="\t")
        fields = reader.fieldnames or []
        rows = list(reader)
    return fields, rows


def verify(manifest: Path, expected: list[dict[str, str]]) -> list[str]:
    errors: list[str] = []
    if not manifest.is_file():
        return [f"manifest missing: {manifest}"]
    fields, actual = read_manifest(manifest)
    if fields != list(FIELDS):
        errors.append(f"columns differ: got {fields!r}")

    actual_names = [row.get("fixture", "") for row in actual]
    if len(actual_names) != len(set(actual_names)):
        errors.append("fixture names are not unique")

    expected_by_name = {row["fixture"]: row for row in expected}
    actual_by_name = {row.get("fixture", ""): row for row in actual}
    missing = sorted(set(expected_by_name) - set(actual_by_name))
    extra = sorted(set(actual_by_name) - set(expected_by_name))
    if missing:
        errors.append("missing fixtures: " + ", ".join(missing))
    if extra:
        errors.append("untracked fixtures: " + ", ".join(extra))

    for name in sorted(set(expected_by_name) & set(actual_by_name)):
        expected_row = expected_by_name[name]
        actual_row = actual_by_name[name]
        for field in FIELDS:
            if actual_row.get(field, "") != expected_row[field]:
                errors.append(f"{name}: {field} differs")
    return errors


def write_status(path: Path | None, status: str) -> None:
    if path is not None:
        path.write_text(status + "\n", encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--qa-dir",
        type=Path,
        default=Path(__file__).resolve().parents[1],
    )
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--write", action="store_true")
    mode.add_argument("--check", action="store_true")
    parser.add_argument("--status", type=Path)
    args = parser.parse_args()

    qa_dir = args.qa_dir.resolve()
    manifest = qa_dir / "fixtures_manifest.tsv"
    try:
        expected = build_rows(qa_dir)
        if args.write:
            write_manifest(manifest, expected)
            print(f"wrote {len(expected)} fixtures to {manifest}")
            return 0

        errors = verify(manifest, expected)
        if errors:
            status = "FAIL " + " | ".join(errors)
            write_status(args.status, status)
            print(status, file=sys.stderr)
            return 1
        status = f"OK fixtures={len(expected)}"
        write_status(args.status, status)
        print(status)
        return 0
    except Exception as error:  # surface every oracle/setup failure
        status = f"FAIL {type(error).__name__}: {error}"
        write_status(args.status, status)
        print(status, file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
