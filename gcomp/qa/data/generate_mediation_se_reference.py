#!/usr/bin/env python3
"""Generate statsmodels mediation point/SE references for gcomp QA.

The reference uses the same finite samples consumed by Stata, but computes the
static mediation estimands from direct plug-in g-formula formulas rather than
calling gcomp. Standard errors are ordinary nonparametric bootstrap SDs.
"""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Callable

import numpy as np
import pandas as pd
import statsmodels.api as sm


OUT_DIR = Path(__file__).resolve().parent
BOOT_REPS = 1000
STATA_BOOT_REPS = 180
STATA_MC_SIMS = 10000


@dataclass(frozen=True)
class Tolerance:
    point_abs: float
    se_abs: float
    se_rel: float


TOLERANCES = {
    ("binary_logit_logit", "rd"): Tolerance(0.015, 0.006, 0.16),
    ("binary_logit_logit", "logor"): Tolerance(0.070, 0.025, 0.16),
    ("binary_logit_logit", "logrr"): Tolerance(0.050, 0.015, 0.16),
    ("continuous_linear_linear", "rd"): Tolerance(0.040, 0.010, 0.16),
}

COVARIANCE_PAIRS = (
    ("tce", "nde"),
    ("tce", "cde"),
    ("nde", "cde"),
    ("nde", "pm"),
    ("pm", "cde"),
)


def _add_constant(data: pd.DataFrame) -> pd.DataFrame:
    return sm.add_constant(data, has_constant="add")


def _fit_logit(y: pd.Series, x: pd.DataFrame):
    return sm.GLM(y, _add_constant(x), family=sm.families.Binomial()).fit(
        maxiter=200, tol=1e-12
    )


def _fit_ols(y: pd.Series, x: pd.DataFrame):
    return sm.OLS(y, _add_constant(x)).fit()


def _predict(model, x: pd.DataFrame) -> np.ndarray:
    return np.asarray(model.predict(_add_constant(x)))


def _write_csv(data: pd.DataFrame, name: str) -> None:
    data.to_csv(OUT_DIR / name, index=False, float_format="%.17g")


def _invlogit(x: np.ndarray) -> np.ndarray:
    return 1.0 / (1.0 + np.exp(-x))


def _scale(e0: float, e1: float, e2: float, e3: float, e4: float, scale: str) -> dict[str, float]:
    if scale == "rd":
        tce = e0 - e2
        nde = e1 - e2
        cde = e3 - e4
    elif scale == "logor":
        logit = lambda p: np.log(p / (1.0 - p))
        tce = logit(e0) - logit(e2)
        nde = logit(e1) - logit(e2)
        cde = logit(e3) - logit(e4)
    elif scale == "logrr":
        tce = np.log(e0) - np.log(e2)
        nde = np.log(e1) - np.log(e2)
        cde = np.log(e3) - np.log(e4)
    else:
        raise ValueError(f"unknown scale: {scale}")

    nie = tce - nde
    pm = nie / tce
    return {
        "tce": float(tce),
        "nde": float(nde),
        "nie": float(nie),
        "pm": float(pm),
        "cde": float(cde),
    }


def binary_effects(data: pd.DataFrame, scale: str) -> dict[str, float]:
    med = _fit_logit(data["m"], data[["x", "c1", "c2"]])
    out = _fit_logit(data["y"], data[["m", "x", "c1", "c2"]])

    n = len(data)
    ones = np.ones(n)
    zeros = np.zeros(n)
    c1 = data["c1"].to_numpy()
    c2 = data["c2"].to_numpy()

    p_m1 = _predict(med, pd.DataFrame({"x": ones, "c1": c1, "c2": c2}))
    p_m0 = _predict(med, pd.DataFrame({"x": zeros, "c1": c1, "c2": c2}))

    y_11 = _predict(out, pd.DataFrame({"m": ones, "x": ones, "c1": c1, "c2": c2}))
    y_10 = _predict(out, pd.DataFrame({"m": zeros, "x": ones, "c1": c1, "c2": c2}))
    y_01 = _predict(out, pd.DataFrame({"m": ones, "x": zeros, "c1": c1, "c2": c2}))
    y_00 = _predict(out, pd.DataFrame({"m": zeros, "x": zeros, "c1": c1, "c2": c2}))

    e0 = np.mean(p_m1 * y_11 + (1.0 - p_m1) * y_10)
    e1 = np.mean(p_m0 * y_11 + (1.0 - p_m0) * y_10)
    e2 = np.mean(p_m0 * y_01 + (1.0 - p_m0) * y_00)
    e3 = np.mean(y_10)
    e4 = np.mean(y_00)

    return _scale(float(e0), float(e1), float(e2), float(e3), float(e4), scale)


def continuous_effects(data: pd.DataFrame, scale: str) -> dict[str, float]:
    if scale != "rd":
        raise ValueError("continuous outcome reference is defined on RD scale only")

    med = _fit_ols(data["m"], data[["x", "c1", "c2"]])
    out = _fit_ols(data["y"], data[["m", "x", "c1", "c2"]])

    n = len(data)
    ones = np.ones(n)
    zeros = np.zeros(n)
    c1 = data["c1"].to_numpy()
    c2 = data["c2"].to_numpy()

    m1 = _predict(med, pd.DataFrame({"x": ones, "c1": c1, "c2": c2}))
    m0 = _predict(med, pd.DataFrame({"x": zeros, "c1": c1, "c2": c2}))

    y_1_m1 = _predict(out, pd.DataFrame({"m": m1, "x": ones, "c1": c1, "c2": c2}))
    y_1_m0 = _predict(out, pd.DataFrame({"m": m0, "x": ones, "c1": c1, "c2": c2}))
    y_0_m0 = _predict(out, pd.DataFrame({"m": m0, "x": zeros, "c1": c1, "c2": c2}))
    y_1_c0 = _predict(out, pd.DataFrame({"m": zeros, "x": ones, "c1": c1, "c2": c2}))
    y_0_c0 = _predict(out, pd.DataFrame({"m": zeros, "x": zeros, "c1": c1, "c2": c2}))

    e0 = np.mean(y_1_m1)
    e1 = np.mean(y_1_m0)
    e2 = np.mean(y_0_m0)
    e3 = np.mean(y_1_c0)
    e4 = np.mean(y_0_c0)

    return _scale(float(e0), float(e1), float(e2), float(e3), float(e4), scale)


def bootstrap_draws(
    data: pd.DataFrame,
    scale: str,
    effect_fn: Callable[[pd.DataFrame, str], dict[str, float]],
    seed: int,
) -> pd.DataFrame:
    rng = np.random.default_rng(seed)
    n = len(data)
    draws: list[dict[str, float]] = []

    for _ in range(BOOT_REPS):
        sample = data.iloc[rng.integers(0, n, n)].reset_index(drop=True)
        draws.append(effect_fn(sample, scale))

    return pd.DataFrame.from_records(draws)


def build_binary_data() -> pd.DataFrame:
    rng = np.random.default_rng(202605061)
    n = 500
    c1 = rng.normal(0.0, 1.0, n)
    c2 = rng.binomial(1, 0.42, n)
    x = rng.binomial(1, _invlogit(-0.15 + 0.55 * c1 - 0.30 * c2))
    m = rng.binomial(1, _invlogit(-0.65 + 0.90 * x + 0.40 * c1 + 0.25 * c2))
    y = rng.binomial(1, _invlogit(-1.05 + 0.70 * m + 0.55 * x + 0.30 * c1 - 0.20 * c2))
    return pd.DataFrame({"y": y, "m": m, "x": x, "c1": c1, "c2": c2})


def build_continuous_data() -> pd.DataFrame:
    rng = np.random.default_rng(202605062)
    n = 500
    c1 = rng.normal(0.0, 1.0, n)
    c2 = rng.normal(0.0, 1.0, n)
    x = rng.binomial(1, _invlogit(-0.10 + 0.45 * c1 - 0.20 * c2))
    m = 0.20 + 0.75 * x + 0.40 * c1 - 0.30 * c2 + rng.normal(0.0, 0.80, n)
    y = 0.40 + 0.65 * m + 0.45 * x + 0.30 * c1 + 0.20 * c2 + rng.normal(0.0, 0.70, n)
    return pd.DataFrame({"y": y, "m": m, "x": x, "c1": c1, "c2": c2})


def add_reference_rows(
    rows: list[dict[str, object]],
    scenario: str,
    scale: str,
    point: dict[str, float],
    se: dict[str, float],
    note: str,
) -> None:
    tol = TOLERANCES[(scenario, scale)]
    for effect in ("tce", "nde", "nie", "pm", "cde"):
        point_abs_tol = tol.point_abs
        se_abs_tol = tol.se_abs
        se_rel_tol = tol.se_rel
        if effect == "pm":
            point_abs_tol = max(point_abs_tol, 0.05)
            se_abs_tol = max(se_abs_tol, 0.012)
            se_rel_tol = max(se_rel_tol, 0.20)
        rows.append(
            {
                "scenario": scenario,
                "scale": scale,
                "effect": effect,
                "point": point[effect],
                "se": se[effect],
                "point_abs_tol": point_abs_tol,
                "se_abs_tol": se_abs_tol,
                "se_rel_tol": se_rel_tol,
                "python_boot_reps": BOOT_REPS,
                "stata_boot_reps": STATA_BOOT_REPS,
                "stata_mc_sims": STATA_MC_SIMS,
                "source": "statsmodels_glm_ols_plugin_bootstrap",
                "notes": note,
            }
        )


def add_covariance_rows(
    rows: list[dict[str, object]],
    scenario: str,
    scale: str,
    draws: pd.DataFrame,
    note: str,
) -> None:
    cov = draws.cov(ddof=1)
    corr = draws.corr()
    for effect1, effect2 in COVARIANCE_PAIRS:
        cov_value = float(cov.loc[effect1, effect2])
        rows.append(
            {
                "scenario": scenario,
                "scale": scale,
                "effect1": effect1,
                "effect2": effect2,
                "covariance": cov_value,
                "correlation": float(corr.loc[effect1, effect2]),
                "cov_abs_tol": max(0.0007, abs(cov_value) * 0.70),
                "python_boot_reps": BOOT_REPS,
                "stata_boot_reps": STATA_BOOT_REPS,
                "stata_mc_sims": STATA_MC_SIMS,
                "source": "statsmodels_glm_ols_plugin_bootstrap",
                "notes": note,
            }
        )


def main() -> None:
    binary = build_binary_data()
    continuous = build_continuous_data()

    _write_csv(binary, "mediation_se_binary.csv")
    _write_csv(continuous, "mediation_se_continuous.csv")

    rows: list[dict[str, object]] = []
    covariance_rows: list[dict[str, object]] = []
    for scale in ("rd", "logor", "logrr"):
        point = binary_effects(binary, scale)
        draws = bootstrap_draws(binary, scale, binary_effects, seed=202605160 + len(rows))
        se = {effect: float(draws[effect].std(ddof=1)) for effect in draws.columns}
        add_reference_rows(
            rows,
            "binary_logit_logit",
            scale,
            point,
            se,
            "binary mediator/outcome; exact plug-in g-formula, control mediator set to 0",
        )
        add_covariance_rows(
            covariance_rows,
            "binary_logit_logit",
            scale,
            draws,
            "binary mediator/outcome; exact plug-in g-formula, control mediator set to 0",
        )

    point = continuous_effects(continuous, "rd")
    draws = bootstrap_draws(continuous, "rd", continuous_effects, seed=202605260)
    se = {effect: float(draws[effect].std(ddof=1)) for effect in draws.columns}
    add_reference_rows(
        rows,
        "continuous_linear_linear",
        "rd",
        point,
        se,
        "continuous mediator/outcome; exact linear plug-in g-formula, control mediator set to 0",
    )
    add_covariance_rows(
        covariance_rows,
        "continuous_linear_linear",
        "rd",
        draws,
        "continuous mediator/outcome; exact linear plug-in g-formula, control mediator set to 0",
    )

    _write_csv(pd.DataFrame(rows), "mediation_se_reference.csv")
    _write_csv(pd.DataFrame(covariance_rows), "mediation_se_covariance.csv")


if __name__ == "__main__":
    main()
