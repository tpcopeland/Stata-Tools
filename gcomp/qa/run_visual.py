#!/usr/bin/env python3
"""Regenerate, semantically inspect, and visually diff gcomp's demo workbook."""

from __future__ import annotations

import argparse
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path


QA_DIR = Path(__file__).resolve().parent
PACKAGE_DIR = QA_DIR.parent
BASELINE_DIR = QA_DIR / "baseline" / "render"
CHECKER = QA_DIR / "tools" / "check_xlsx.py"
EXPECTED_PAGES = tuple(f"demo_gcomptab_page-{page}.png" for page in range(1, 4))


def run(command: list[str], *, cwd: Path, timeout: int) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        command,
        cwd=cwd,
        timeout=timeout,
        check=False,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
    )


def render_workbook(
    workbook: Path,
    render_dir: Path,
    work: Path,
    *,
    against: Path | None,
    tolerance: float,
) -> tuple[tuple[str, ...], list[str]]:
    """Render with isolated LibreOffice, audit pixels, and optionally diff."""
    try:
        import numpy as np
        from PIL import Image
    except ImportError as error:
        raise RuntimeError("Pillow and numpy are required for the visual gate") from error

    libreoffice = shutil.which("libreoffice") or shutil.which("soffice")
    pdftoppm = shutil.which("pdftoppm")
    if not libreoffice or not pdftoppm:
        raise RuntimeError("LibreOffice and pdftoppm are required for the visual gate")

    profile = work / "libreoffice-profile"
    pdf_dir = work / "pdf"
    profile.mkdir()
    pdf_dir.mkdir()
    render_dir.mkdir()
    converted = run(
        [
            libreoffice,
            "--headless",
            f"-env:UserInstallation={profile.as_uri()}",
            "--convert-to",
            "pdf",
            "--outdir",
            str(pdf_dir),
            str(workbook),
        ],
        cwd=work,
        timeout=180,
    )
    pdf = pdf_dir / f"{workbook.stem}.pdf"
    if converted.returncode != 0 or not pdf.is_file():
        raise RuntimeError(f"LibreOffice conversion failed: {converted.stdout.strip()}")

    page_prefix = f"{workbook.stem}_page"
    rasterized = run(
        [pdftoppm, "-png", "-r", "150", str(pdf), str(render_dir / page_prefix)],
        cwd=work,
        timeout=120,
    )
    if rasterized.returncode != 0:
        raise RuntimeError(f"pdftoppm failed: {rasterized.stdout.strip()}")

    produced = tuple(sorted(path.name for path in render_dir.glob(f"{page_prefix}-[0-9].png")))
    failures: list[str] = []
    for index, name in enumerate(produced, 1):
        candidate = render_dir / name
        with Image.open(candidate) as image:
            rgb = np.asarray(image.convert("RGB"), dtype=np.int16)
            gray = rgb.mean(axis=2)
        ink = gray < 200
        density = float(ink.mean()) if ink.size else 0.0
        edge_width = min(8, ink.shape[1]) if ink.ndim == 2 else 0
        right_edge = float(ink[:, -edge_width:].mean()) if edge_width else 0.0
        if density < 0.002:
            failures.append(f"page {index} is blank or nearly blank (density={density:.6f})")
        if right_edge > 0:
            failures.append(f"page {index} touches the right edge (ratio={right_edge:.6f})")

        diff_ratio: float | None = None
        if against is not None:
            golden = against / name
            if not golden.is_file():
                failures.append(f"golden page is missing: {name}")
            else:
                with Image.open(golden) as image:
                    golden_rgb = np.asarray(image.convert("RGB"), dtype=np.int16)
                if rgb.shape != golden_rgb.shape:
                    diff_ratio = 1.0
                else:
                    changed = np.any(np.abs(rgb - golden_rgb) > 10, axis=2)
                    diff_ratio = float(changed.mean()) if changed.size else 0.0
                if diff_ratio > tolerance:
                    failures.append(
                        f"page {index} visual drift {diff_ratio:.6f} exceeds {tolerance:.6f}"
                    )
        diff_text = "n/a" if diff_ratio is None else f"{diff_ratio:.6f}"
        print(
            f"render page={index} density={density:.6f} "
            f"right_edge={right_edge:.6f} diff={diff_text}"
        )
    return produced, failures


def semantic_commands(workbook: Path) -> list[list[str]]:
    base = [sys.executable, str(CHECKER), str(workbook)]
    return [
        base
        + [
            "--sheet-count", "3",
            "--sheet-order", "Normal CI", "Percentile CI", "Component models",
            "--contains", "Total Causal Effect",
        ],
        base
        + [
            "--sheet", "Normal CI",
            "--exact-rows", "7",
            "--exact-cols", "5",
            "--header-exact", "2", "", "Effect", "Estimate", "95% CI", "SE",
            "--bold-row-all", "2",
            "--min-merges", "1",
            "--has-borders",
            "--font", "Arial",
            "--all-col-widths-fit", "2", "2",
        ],
        base
        + [
            "--sheet", "Percentile CI",
            "--exact-rows", "7",
            "--exact-cols", "5",
            "--header-exact", "2", "", "Effect", "Estimate", "95% CI", "SE",
            "--bold-row-all", "2",
            "--min-merges", "1",
            "--has-borders",
            "--font", "Arial",
            "--all-col-widths-fit", "2", "2",
        ],
        base
        + [
            "--sheet", "Component models",
            "--exact-rows", "8",
            "--exact-cols", "7",
            "--header-exact", "3", "Term", "Coef.", "95% CI", "p", "Coef.", "95% CI", "p",
            "--cell", "A1", "Table 3. Fitted component models (coefficients)",
            "--cell", "B2", "Mediator (m)",
            "--has-borders",
            "--font", "Arial",
            "--min-merges", "2",
            "--all-col-widths-fit", "2", "2",
        ],
    ]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--update-baseline",
        action="store_true",
        help="replace golden PNGs after all generation, semantic, and pixel checks pass",
    )
    parser.add_argument("--tolerance", type=float, default=0.002)
    args = parser.parse_args()

    tests = 6
    passed = 0
    failures: list[str] = []
    with tempfile.TemporaryDirectory(prefix="gcomp-visual-work-") as raw_work:
        work = Path(raw_work)
        copied_package = work / "gcomp"
        shutil.copytree(
            PACKAGE_DIR,
            copied_package,
            ignore=shutil.ignore_patterns("*.log", "*.smcl", "qa"),
        )
        demo = copied_package / "demo" / "demo_gcomp.do"
        demo_run = run(
            [os.environ.get("STATA_BIN", "stata-mp"), "-b", "do", demo.name],
            cwd=demo.parent,
            timeout=1200,
        )
        demo_log = demo.with_suffix(".log")
        demo_text = demo_log.read_text(encoding="utf-8", errors="replace") if demo_log.is_file() else ""
        if demo_run.returncode == 0 and "RESULT: demo_gcomp sheets=3 status=PASS" in demo_text:
            passed += 1
        else:
            failures.append(
                f"demo regeneration failed (rc={demo_run.returncode}, sentinel={bool(demo_text)})"
            )
            if demo_run.stdout:
                print(demo_run.stdout)

        workbook = copied_package / "demo" / "demo_gcomptab.xlsx"
        if not workbook.is_file():
            failures.append("demo regeneration did not create demo_gcomptab.xlsx")
        else:
            for index, command in enumerate(semantic_commands(workbook), 1):
                checked = run(command, cwd=QA_DIR, timeout=120)
                if checked.returncode == 0:
                    passed += 1
                else:
                    failures.append(f"semantic workbook check {index} failed")
                    print(checked.stdout)

        render_dir = work / "render"
        try:
            produced, render_failures = render_workbook(
                workbook,
                render_dir,
                work,
                against=None if args.update_baseline else BASELINE_DIR,
                tolerance=args.tolerance,
            )
            render_ok = produced == EXPECTED_PAGES and not render_failures
            if render_ok:
                if args.update_baseline and passed == tests - 1 and not failures:
                    BASELINE_DIR.mkdir(parents=True, exist_ok=True)
                    for stale in BASELINE_DIR.glob("demo_gcomptab_page-*.png"):
                        stale.unlink()
                    for name in EXPECTED_PAGES:
                        shutil.copy2(render_dir / name, BASELINE_DIR / name)
                passed += 1
            else:
                failures.extend(render_failures)
                if produced != EXPECTED_PAGES:
                    failures.append(f"expected pages {EXPECTED_PAGES}, found {produced}")
        except Exception as error:
            failures.append(f"pixel/render gate failed: {error}")

    failed = tests - passed
    status = "PASS" if not failures and failed == 0 else "FAIL"
    for failure in failures:
        print(f"FAIL: {failure}")
    print(f"RESULT: run_visual tests={tests} pass={passed} fail={failed} status={status}")
    return 0 if status == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
