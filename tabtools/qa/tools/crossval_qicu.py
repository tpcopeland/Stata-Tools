#!/usr/bin/env python3
"""Independent statsmodels oracle for regtab's fixed-scale GEE QICu."""

from __future__ import annotations

import argparse
import csv
from pathlib import Path

import numpy as np
import statsmodels.api as sm
from statsmodels.genmod.cov_struct import Exchangeable
from statsmodels.genmod.families import Binomial
from statsmodels.genmod.generalized_estimating_equations import GEE


def read_columns(path: Path) -> dict[str, np.ndarray]:
    with path.open(newline="", encoding="utf-8") as handle:
        rows = list(csv.DictReader(handle))
    required = {"_id", "_y", "_x", "_t", "_z"}
    missing = required.difference(rows[0] if rows else {})
    if missing:
        raise ValueError(f"missing input columns: {', '.join(sorted(missing))}")
    return {
        name: np.asarray([float(row[name]) for row in rows], dtype=float)
        for name in required
    }


def fit_qicu(
    columns: dict[str, np.ndarray], predictors: tuple[str, ...]
) -> float:
    exog = sm.add_constant(
        np.column_stack([columns[name] for name in predictors]),
        has_constant="add",
    )
    model = GEE(
        columns["_y"],
        exog,
        groups=columns["_id"],
        family=Binomial(),
        cov_struct=Exchangeable(),
    )
    result = model.fit(scale=1.0, maxiter=200)
    if not result.converged:
        raise RuntimeError(f"GEE did not converge for predictors {predictors}")
    _, qicu = result.qic(scale=1.0, n_step=5000)
    if not np.isfinite(qicu):
        raise RuntimeError(f"nonfinite QICu for predictors {predictors}")
    return float(qicu)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("input_csv", type=Path)
    parser.add_argument("output_csv", type=Path)
    args = parser.parse_args()

    columns = read_columns(args.input_csv)
    qicu_1 = fit_qicu(columns, ("_x", "_t"))
    qicu_2 = fit_qicu(columns, ("_x", "_t", "_z"))

    args.output_csv.parent.mkdir(parents=True, exist_ok=True)
    with args.output_csv.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.writer(handle)
        writer.writerow(("metric", "value"))
        writer.writerow(("qicu_1", format(qicu_1, ".17g")))
        writer.writerow(("qicu_2", format(qicu_2, ".17g")))
        writer.writerow(("qicu_delta", format(qicu_1 - qicu_2, ".17g")))


if __name__ == "__main__":
    main()
