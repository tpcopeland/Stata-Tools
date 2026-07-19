#!/usr/bin/env python3
"""Static package, version, and SMCL-width release checks for gcomp."""

from __future__ import annotations

import argparse
import csv
import json
import re
from pathlib import Path


AUTHOR = "Timothy P Copeland, Karolinska Institutet"
VIEWER_COLS = 80
DEFAULT_SYNOPTSET = 20
RX_SYNOPTSET = re.compile(r"\{synoptset\s+(\d+)")
RX_ABBREV = re.compile(r"\{(?:opth|opt|cmdab)[\s:]\s*([^{}]*)\}")
RX_LINK = re.compile(r"\{(?:helpb|help|browse|stata|view)\s+([^{}]*)\}")
RX_MANLINK = re.compile(r"\{manlink\s+\S+\s+([^{}]*)\}")
RX_STYLE = re.compile(
    r"\{(?:cmd|cmdab|it|bf|hi|res|text|err|error|input|ul|sf|sub|sup)\s*:\s*([^{}]*)\}"
)
RX_ENTITY = re.compile(r"\{(?:c\s+[^{}]*|&[A-Za-z]+)\}")
RX_DIRECTIVE = re.compile(r"\{[^{}]*\}")


def rendered_text(value: str) -> str:
    previous = None
    while value != previous:
        previous = value
        value = RX_ABBREV.sub(lambda match: match.group(1).replace(":", ""), value)
        value = RX_LINK.sub(
            lambda match: match.group(1).rsplit(":", 1)[-1].strip().strip('"'),
            value,
        )
        value = RX_MANLINK.sub(r"\1", value)
        value = RX_STYLE.sub(r"\1", value)
        value = RX_ENTITY.sub("x", value)
        value = RX_DIRECTIVE.sub("", value)
    return value


def synopt_description(line: str) -> str | None:
    stripped = line.lstrip()
    if not stripped.startswith("{synopt") or ":" not in stripped:
        return None
    rest = stripped.split(":", 1)[1]
    depth = 0
    for index, character in enumerate(rest):
        if character == "{":
            depth += 1
        elif character == "}":
            depth -= 1
            if depth < 0:
                return rest[index + 1 :].split("{p_end}", 1)[0]
    return ""


def help_width_problems(path: Path) -> list[str]:
    problems: list[str] = []
    synoptset = DEFAULT_SYNOPTSET
    for line_number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        match = RX_SYNOPTSET.search(line)
        if match:
            synoptset = int(match.group(1))
        description = synopt_description(line)
        if description is None:
            continue
        if "{p_end}" not in line:
            problems.append(f"{path.name}:{line_number}: synopt row lacks p_end")
        width = len(rendered_text(description).strip())
        cap = VIEWER_COLS - synoptset
        if width > cap:
            problems.append(
                f"{path.name}:{line_number}: rendered synopt width {width}>{cap}"
            )
    return problems


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("package_dir", type=Path)
    parser.add_argument("--result-file", type=Path)
    args = parser.parse_args()
    package_dir = args.package_dir.resolve()
    problems: list[str] = []

    pkg_text = (package_dir / "gcomp.pkg").read_text(encoding="utf-8")
    packaged = [line[2:].strip() for line in pkg_text.splitlines() if line.startswith("f ")]
    for filename in packaged:
        if not (package_dir / filename).is_file():
            problems.append(f"gcomp.pkg lists missing file {filename}")
    required = {
        "gcomp.ado",
        "gcomptab.ado",
        "gcomp.sthlp",
        "gcomptab.sthlp",
        "_gcomp_apply_rule.ado",
        "_gcomp_bootstrap_impl.ado",
        "_gcomp_refit_models.ado",
    }
    missing = sorted(required - set(packaged))
    if missing:
        problems.append(f"gcomp.pkg omits required files: {', '.join(missing)}")

    ado_header = (package_dir / "gcomp.ado").read_text(encoding="utf-8").splitlines()[0]
    version_match = re.search(r"Version\s+([0-9.]+)\s+(\d{4})/(\d{2})/(\d{2})", ado_header)
    if not version_match:
        problems.append("gcomp.ado has no parseable version header")
        version = ""
        iso_date = ""
        compact_date = ""
    else:
        version = version_match.group(1)
        iso_date = "-".join(version_match.groups()[1:])
        compact_date = "".join(version_match.groups()[1:])

    flagship = (package_dir / "gcomp.sthlp").read_text(encoding="utf-8")
    readme = (package_dir / "README.md").read_text(encoding="utf-8")
    toc = (package_dir / "stata.toc").read_text(encoding="utf-8")
    top_readme = (package_dir.parent / "README.md").read_text(encoding="utf-8")
    if version and f"version {version}" not in flagship.lower():
        problems.append("flagship help version differs from gcomp.ado")
    if version and f"**Version {version}** | {iso_date}" not in readme:
        problems.append("package README version/date differs from gcomp.ado")
    if compact_date and f"Distribution-Date: {compact_date}" not in pkg_text:
        problems.append("gcomp.pkg Distribution-Date differs from gcomp.ado")
    badge_date = iso_date.replace("-", "--")
    badge = f"version-{version}-blue"
    updated = f"updated-{badge_date}-brightgreen"
    gcomp_rows = [line for line in top_readme.splitlines() if "[gcomp](" in line]
    if len(gcomp_rows) != 1 or badge not in gcomp_rows[0] or updated not in gcomp_rows[0]:
        problems.append("top-level gcomp badges differ from package version/date")

    if AUTHOR not in pkg_text or AUTHOR not in toc or AUTHOR not in readme:
        problems.append("canonical author string is not synchronized")
    canonical_toc = (
        "v 3\n"
        "d Stata-Tools: gcomp\n"
        f"d {AUTHOR}\n"
        "d https://github.com/tpcopeland/Stata-Tools\n"
        "p gcomp\n"
    )
    if toc != canonical_toc:
        problems.append("stata.toc does not match the canonical format")

    shipped = [package_dir / name for name in packaged]
    shipped += [package_dir / "README.md", package_dir / "stata.toc", package_dir / "gcomp.pkg"]
    forbidden = (
        "/home/" + "tpcopeland/",
        "~/" + "Stata-Tools",
        "Stata" + "-Dev",
        "." + "claude/",
    )
    for path in shipped:
        text = path.read_text(encoding="utf-8", errors="replace")
        for token in forbidden:
            if token in text:
                problems.append(f"{path.name} contains forbidden development path {token}")

    helper_versions: set[str] = set()
    for path in package_dir.glob("*.ado"):
        first = path.read_text(encoding="utf-8").splitlines()[0]
        match = re.search(r"Version\s+([0-9.]+)", first)
        if not match:
            problems.append(f"{path.name} lacks a version header")
        else:
            helper_versions.add(match.group(1))
    if version and helper_versions != {version}:
        problems.append(f"ado versions are not synchronized: {sorted(helper_versions)}")

    problems.extend(help_width_problems(package_dir / "gcomp.sthlp"))
    problems.extend(help_width_problems(package_dir / "gcomptab.sthlp"))

    qa_dir = package_dir / "qa"
    visual_runner = qa_dir / "run_visual.py"
    visual_baselines = sorted((qa_dir / "baseline" / "render").glob("demo_gcomptab_page-*.png"))
    if not visual_runner.is_file():
        problems.append("developer visual regression runner is missing")
    expected_visual_names = [f"demo_gcomptab_page-{page}.png" for page in range(1, 4)]
    if [path.name for path in visual_baselines] != expected_visual_names:
        problems.append("visual baseline must contain exactly three canonical workbook pages")
    expected_features = {
        *(f"GCOMP-C{i:02d}" for i in range(1, 9)),
        *(f"GCOMP-H{i:02d}" for i in range(1, 16)),
        *(f"GCTAB-H{i:02d}" for i in range(1, 7)),
        *(f"GCOMP-D{i:02d}" for i in range(1, 8)),
        *(f"GCOMP-Q{i:02d}" for i in range(1, 10)),
        *(f"GCOMP-M{i:02d}" for i in range(1, 4)),
    }
    with (qa_dir / "feature_matrix.csv").open(newline="", encoding="utf-8") as handle:
        feature_rows = list(csv.DictReader(handle))
    observed_features = {row["feature_id"] for row in feature_rows}
    if observed_features != expected_features or len(feature_rows) != len(expected_features):
        problems.append(
            "feature_matrix.csv must map every unique audit requirement exactly once"
        )
    lanes = json.loads((qa_dir / "lanes.json").read_text(encoding="utf-8"))
    suite_inventory = {
        item["name"]
        for lane in ("quick", "core", "external", "slow", "release")
        for item in lanes["lanes"][lane]["suites"]
    }
    for row in feature_rows:
        suite = row["suite"]
        if suite.endswith(".py"):
            if not (qa_dir / suite).is_file():
                problems.append(f"feature {row['feature_id']} names missing {suite}")
        elif suite not in suite_inventory:
            problems.append(
                f"feature {row['feature_id']} names uninventoried suite {suite}"
            )

    status = "PASS" if not problems else "FAIL"
    if args.result_file:
        args.result_file.write_text(status + "\n", encoding="utf-8")
    for problem in problems:
        print(f"FAIL: {problem}")
    if not problems:
        print("PASS: package metadata, versions, distribution, and SMCL widths")
    return 0 if not problems else 1


if __name__ == "__main__":
    raise SystemExit(main())
