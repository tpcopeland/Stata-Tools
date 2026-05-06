#!/usr/bin/env python3
"""Generate statsmodels references for gcomp time-varying EOFU SE QA."""

from __future__ import annotations

from pathlib import Path

import numpy as np
import pandas as pd
import statsmodels.api as sm


OUT_DIR = Path(__file__).resolve().parent
N_SUBJECTS = 360
BOOT_REPS = 700
DATA_SEED = 20260513
BOOT_SEED = 20260514


def expit(x: np.ndarray) -> np.ndarray:
    return 1.0 / (1.0 + np.exp(-x))


def add_constant(data: pd.DataFrame) -> pd.DataFrame:
    return sm.add_constant(data, has_constant="add")


def fit_logit(y: pd.Series, x: pd.DataFrame):
    return sm.GLM(y, add_constant(x), family=sm.families.Binomial()).fit(
        maxiter=200, tol=1e-12
    )


def fit_ols(y: pd.Series, x: pd.DataFrame):
    return sm.OLS(y, add_constant(x)).fit()


def predict(model, x: pd.DataFrame) -> np.ndarray:
    return np.asarray(model.predict(add_constant(x)), dtype=float)


def make_wide_data() -> pd.DataFrame:
    rng = np.random.default_rng(DATA_SEED)
    l0 = rng.normal(0.0, 1.0, N_SUBJECTS)

    l1 = 0.20 + 0.55 * l0 + rng.normal(0.0, 0.50, N_SUBJECTS)
    a1 = rng.binomial(1, expit(-0.25 + 0.62 * l1 + 0.22 * l0))

    l2 = 0.10 + 0.58 * l1 - 0.42 * a1 + 0.16 * l0
    a2 = rng.binomial(1, expit(-0.15 + 0.58 * l2 + 0.20 * l0))

    l3 = 0.05 + 0.55 * l2 - 0.38 * a2 + 0.14 * l0
    a3 = rng.binomial(1, expit(-0.05 + 0.54 * l3 + 0.18 * l0))

    py = expit(-1.15 - 0.74 * a3 + 0.68 * l3 + 0.18 * l0)
    y = rng.binomial(1, py)
    yc = 0.35 - 0.66 * a3 + 0.78 * l3 + 0.24 * l0 + rng.normal(
        0.0, 0.50, N_SUBJECTS
    )

    return pd.DataFrame(
        {
            "id": np.arange(1, N_SUBJECTS + 1),
            "l0": l0,
            "l1": l1,
            "a1": a1,
            "l2": l2,
            "a2": a2,
            "l3": l3,
            "a3": a3,
            "y": y,
            "yc": yc,
        }
    )


def wide_to_long(wide: pd.DataFrame) -> pd.DataFrame:
    records: list[dict[str, float]] = []
    for row in wide.itertuples(index=False):
        avals = [row.a1, row.a2, row.a3]
        lvals = [row.l1, row.l2, row.l3]
        for time in (1, 2, 3):
            records.append(
                {
                    "id": int(row.id),
                    "time": time,
                    "l0": row.l0,
                    "a": avals[time - 1],
                    "l": lvals[time - 1],
                    "alag": 0 if time == 1 else avals[time - 2],
                    "llag": 0.0 if time == 1 else lvals[time - 2],
                    "y": row.y if time == 3 else 0,
                    "yc": row.yc if time == 3 else 0.0,
                }
            )
    return pd.DataFrame.from_records(records)


def fit_models(wide: pd.DataFrame, outcome: str, outcome_kind: str):
    models = {
        "a1": fit_logit(wide["a1"], wide[["l0", "l1"]].rename(columns={"l1": "l"})),
        "a2": fit_logit(wide["a2"], wide[["l0", "l2"]].rename(columns={"l2": "l"})),
        "a3": fit_logit(wide["a3"], wide[["l0", "l3"]].rename(columns={"l3": "l"})),
        "l2": fit_ols(
            wide["l2"],
            pd.DataFrame(
                {"alag": wide["a1"], "llag": wide["l1"], "l0": wide["l0"]}
            ),
        ),
        "l3": fit_ols(
            wide["l3"],
            pd.DataFrame(
                {"alag": wide["a2"], "llag": wide["l2"], "l0": wide["l0"]}
            ),
        ),
    }
    x_out = pd.DataFrame({"a": wide["a3"], "l": wide["l3"], "l0": wide["l0"]})
    if outcome_kind == "binary":
        models["outcome"] = fit_logit(wide[outcome], x_out)
    else:
        models["outcome"] = fit_ols(wide[outcome], x_out)
    return models


def estimate(wide: pd.DataFrame, outcome: str, outcome_kind: str) -> dict[str, float]:
    models = fit_models(wide, outcome, outcome_kind)
    l0 = wide["l0"].to_numpy()
    l1 = wide["l1"].to_numpy()

    po: dict[int, float] = {}
    for aval in (1, 0):
        avec = np.full(len(wide), aval)
        l2_hat = predict(
            models["l2"], pd.DataFrame({"alag": avec, "llag": l1, "l0": l0})
        )
        l3_hat = predict(
            models["l3"], pd.DataFrame({"alag": avec, "llag": l2_hat, "l0": l0})
        )
        y_hat = predict(
            models["outcome"], pd.DataFrame({"a": avec, "l": l3_hat, "l0": l0})
        )
        po[aval] = float(np.mean(y_hat))

    return {
        "po_a1": po[1],
        "po_a0": po[0],
        "rd_a1_a0": po[1] - po[0],
    }


def bootstrap(
    wide: pd.DataFrame, outcome: str, outcome_kind: str, analysis: str
) -> tuple[dict[str, float], pd.DataFrame]:
    rng = np.random.default_rng(BOOT_SEED + (0 if outcome_kind == "binary" else 1000))
    rows = []
    estimates = []

    for rep in range(1, BOOT_REPS + 1):
        idx = rng.integers(0, len(wide), len(wide))
        sample = wide.iloc[idx].reset_index(drop=True).copy()
        sample["id"] = np.arange(1, len(sample) + 1)
        est = estimate(sample, outcome, outcome_kind)
        estimates.append(est)
        rows.append({"analysis": analysis, "rep": rep, **est})

    boot = pd.DataFrame(rows)
    se = {
        metric: float(boot[metric].std(ddof=1))
        for metric in ("po_a1", "po_a0", "rd_a1_a0")
    }
    return se, boot


def add_reference_rows(
    rows: list[dict[str, object]],
    analysis: str,
    estimate_values: dict[str, float],
    se_values: dict[str, float],
) -> None:
    if analysis == "binary":
        tol_est = {"po_a1": 0.015, "po_a0": 0.015, "rd_a1_a0": 0.020}
        tol_se = {"po_a1": 0.012, "po_a0": 0.012, "rd_a1_a0": 0.014}
        note = "statsmodels GLM Binomial; subject bootstrap over 3-visit EOFU panel"
    else:
        tol_est = {"po_a1": 0.020, "po_a0": 0.020, "rd_a1_a0": 0.030}
        tol_se = {"po_a1": 0.015, "po_a0": 0.015, "rd_a1_a0": 0.018}
        note = "statsmodels OLS; subject bootstrap over 3-visit EOFU panel"

    for metric in ("po_a1", "po_a0", "rd_a1_a0"):
        rows.append(
            {
                "analysis": analysis,
                "metric": metric,
                "estimate": estimate_values[metric],
                "se": se_values[metric],
                "tolerance_estimate": tol_est[metric],
                "tolerance_se": tol_se[metric],
                "source": "python_statsmodels",
                "n_subjects": N_SUBJECTS,
                "bootstrap_reps": BOOT_REPS,
                "data_seed": DATA_SEED,
                "bootstrap_seed": BOOT_SEED,
                "notes": note,
            }
        )


def add_covariance_rows(
    rows: list[dict[str, object]], analysis: str, boot: pd.DataFrame
) -> None:
    cov = boot[["po_a1", "po_a0", "rd_a1_a0"]].cov()
    corr = boot[["po_a1", "po_a0", "rd_a1_a0"]].corr()
    cov_value = float(cov.loc["po_a1", "po_a0"])
    rows.append(
        {
            "analysis": analysis,
            "metric1": "po_a1",
            "metric2": "po_a0",
            "covariance": cov_value,
            "correlation": float(corr.loc["po_a1", "po_a0"]),
            "cov_abs_tol": max(0.00035, abs(cov_value) * 0.70),
            "source": "python_statsmodels_subject_bootstrap",
            "n_subjects": N_SUBJECTS,
            "bootstrap_reps": BOOT_REPS,
            "data_seed": DATA_SEED,
            "bootstrap_seed": BOOT_SEED,
            "notes": "off-diagonal covariance of static-intervention potential outcomes",
        }
    )


def write_csv(df: pd.DataFrame, filename: str) -> None:
    df.to_csv(OUT_DIR / filename, index=False, float_format="%.15g")


def main() -> None:
    wide = make_wide_data()
    write_csv(wide_to_long(wide), "timevarying_se_data.csv")

    ref_rows: list[dict[str, object]] = []
    covariance_rows: list[dict[str, object]] = []
    boot_tables = []

    binary_est = estimate(wide, "y", "binary")
    binary_se, binary_boot = bootstrap(wide, "y", "binary", "binary")
    add_reference_rows(ref_rows, "binary", binary_est, binary_se)
    add_covariance_rows(covariance_rows, "binary", binary_boot)
    boot_tables.append(binary_boot)

    continuous_est = estimate(wide, "yc", "continuous")
    continuous_se, continuous_boot = bootstrap(wide, "yc", "continuous", "continuous")
    add_reference_rows(ref_rows, "continuous", continuous_est, continuous_se)
    add_covariance_rows(covariance_rows, "continuous", continuous_boot)
    boot_tables.append(continuous_boot)

    write_csv(pd.DataFrame(ref_rows), "timevarying_se_reference.csv")
    write_csv(pd.DataFrame(covariance_rows), "timevarying_se_covariance.csv")
    write_csv(pd.concat(boot_tables, ignore_index=True), "timevarying_se_bootstrap.csv")


if __name__ == "__main__":
    main()
