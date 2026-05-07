#!/usr/bin/env python3
"""Generate extended mediation plug-in references for gcomp QA.

The references are external to Stata/gcomp. Statsmodels fits the same
parametric models used by the QA commands, then closed-form plug-in g-formula
calculations compute the mediation estimands. Standard errors and selected
covariances are nonparametric bootstrap SD/covariance estimates from the same
plug-in oracle.
"""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Callable

import numpy as np
import pandas as pd
import statsmodels.api as sm


OUT_DIR = Path(__file__).resolve().parent
BOOT_REPS = 300
STATA_BOOT_REPS = 100
STATA_MC_SIMS = 9000

EFFECTS = ("tce", "nde", "nie", "pm", "cde")
COVARIANCE_PAIRS = (
    ("tce", "nde"),
    ("tce", "cde"),
    ("nde", "cde"),
    ("nde", "pm"),
    ("pm", "cde"),
)


@dataclass(frozen=True)
class Tolerance:
    point_abs: float
    se_abs: float
    se_rel: float
    cov_floor: float
    cov_rel: float


TOLERANCES = {
    "oce_mlogit_logit": Tolerance(0.035, 0.022, 0.40, 0.0030, 1.20),
    "specific_mlogit_logit": Tolerance(0.032, 0.022, 0.40, 0.0030, 1.20),
    "linexp_linear_linear": Tolerance(0.050, 0.024, 0.34, 0.0040, 1.00),
}


def _invlogit(x: np.ndarray) -> np.ndarray:
    return 1.0 / (1.0 + np.exp(-x))


def _softmax(logits: np.ndarray) -> np.ndarray:
    shifted = logits - logits.max(axis=1, keepdims=True)
    expv = np.exp(shifted)
    return expv / expv.sum(axis=1, keepdims=True)


def _add_constant(data: pd.DataFrame) -> pd.DataFrame:
    return sm.add_constant(data, has_constant="add")


def _fit_logit(y: pd.Series, x: pd.DataFrame):
    return sm.GLM(y, _add_constant(x), family=sm.families.Binomial()).fit(
        maxiter=200, tol=1e-12
    )


def _fit_ols(y: pd.Series, x: pd.DataFrame):
    return sm.OLS(y, _add_constant(x)).fit()


def _fit_mlogit(y: pd.Series, x: pd.DataFrame):
    return sm.MNLogit(y, _add_constant(x)).fit(
        method="newton", maxiter=200, tol=1e-10, disp=False
    )


def _predict(model, x: pd.DataFrame) -> np.ndarray:
    return np.asarray(model.predict(_add_constant(x)))


def _write_csv(data: pd.DataFrame, name: str) -> None:
    data.to_csv(OUT_DIR / name, index=False, float_format="%.17g")


def _x_design(x: np.ndarray, c1: np.ndarray, c2: np.ndarray) -> pd.DataFrame:
    return pd.DataFrame(
        {
            "x_1": (x == 1).astype(float),
            "x_2": (x == 2).astype(float),
            "c1": c1,
            "c2": c2,
        }
    )


def _y_design(
    m: np.ndarray, x: np.ndarray, c1: np.ndarray, c2: np.ndarray
) -> pd.DataFrame:
    return pd.DataFrame(
        {
            "m_1": (m == 1).astype(float),
            "m_2": (m == 2).astype(float),
            "x_1": (x == 1).astype(float),
            "x_2": (x == 2).astype(float),
            "c1": c1,
            "c2": c2,
        }
    )


def _linear_scale(e0: float, e1: float, e2: float, e3: float, e4: float) -> dict[str, float]:
    tce = e0 - e2
    nde = e1 - e2
    nie = tce - nde
    pm = nie / tce if abs(tce) > 1e-10 else np.nan
    cde = e3 - e4
    return {
        "tce": float(tce),
        "nde": float(nde),
        "nie": float(nie),
        "pm": float(pm),
        "cde": float(cde),
    }


def _categorical_outcome_mean(
    outcome_model,
    mediator_probs: np.ndarray,
    x_value: int,
    c1: np.ndarray,
    c2: np.ndarray,
) -> float:
    x = np.full(len(c1), x_value)
    mean = np.zeros(len(c1))
    for m_value in range(mediator_probs.shape[1]):
        m = np.full(len(c1), m_value)
        pred = _predict(outcome_model, _y_design(m, x, c1, c2))
        mean += mediator_probs[:, m_value] * pred
    return float(mean.mean())


def categorical_effects(
    data: pd.DataFrame, baseline: int = 0, alternatives: tuple[int, ...] = (1, 2)
) -> dict[str, float]:
    c1 = data["c1"].to_numpy()
    c2 = data["c2"].to_numpy()

    med = _fit_mlogit(data["m"], _x_design(data["x"].to_numpy(), c1, c2))
    out = _fit_logit(data["y"], _y_design(data["m"].to_numpy(), data["x"].to_numpy(), c1, c2))

    probs = {
        x_value: _predict(med, _x_design(np.full(len(data), x_value), c1, c2))
        for x_value in (baseline, *alternatives)
    }

    y_base_m_base = _categorical_outcome_mean(out, probs[baseline], baseline, c1, c2)
    y_base_control = float(
        _predict(
            out,
            _y_design(
                np.zeros(len(data), dtype=int),
                np.full(len(data), baseline),
                c1,
                c2,
            ),
        ).mean()
    )

    rows: dict[str, float] = {}
    for x_value in alternatives:
        y_alt_m_alt = _categorical_outcome_mean(out, probs[x_value], x_value, c1, c2)
        y_alt_m_base = _categorical_outcome_mean(out, probs[baseline], x_value, c1, c2)
        y_alt_control = float(
            _predict(
                out,
                _y_design(
                    np.zeros(len(data), dtype=int),
                    np.full(len(data), x_value),
                    c1,
                    c2,
                ),
            ).mean()
        )
        scaled = _linear_scale(
            y_alt_m_alt,
            y_alt_m_base,
            y_base_m_base,
            y_alt_control,
            y_base_control,
        )
        for effect, value in scaled.items():
            rows[f"{effect}_{x_value}"] = value
    return rows


def specific_effects(data: pd.DataFrame) -> dict[str, float]:
    return {
        effect: value
        for key, value in categorical_effects(data, baseline=0, alternatives=(2,)).items()
        for effect in (key.rsplit("_", 1)[0],)
    }


def linexp_effects(data: pd.DataFrame) -> dict[str, float]:
    c1 = data["c1"].to_numpy()
    c2 = data["c2"].to_numpy()
    x = data["x"].to_numpy()

    med = _fit_ols(data["m"], data[["x", "c1", "c2"]])
    out = _fit_ols(data["y"], data[["m", "x", "c1", "c2"]])

    x_plus = x + 1.0
    m_x = _predict(med, pd.DataFrame({"x": x, "c1": c1, "c2": c2}))
    m_xplus = _predict(med, pd.DataFrame({"x": x_plus, "c1": c1, "c2": c2}))

    y_xplus_m_xplus = _predict(out, pd.DataFrame({"m": m_xplus, "x": x_plus, "c1": c1, "c2": c2}))
    y_xplus_m_x = _predict(out, pd.DataFrame({"m": m_x, "x": x_plus, "c1": c1, "c2": c2}))
    y_x_m_x = _predict(out, pd.DataFrame({"m": m_x, "x": x, "c1": c1, "c2": c2}))
    y_xplus_control = _predict(out, pd.DataFrame({"m": np.zeros(len(data)), "x": x_plus, "c1": c1, "c2": c2}))
    y_x_control = _predict(out, pd.DataFrame({"m": np.zeros(len(data)), "x": x, "c1": c1, "c2": c2}))

    return _linear_scale(
        float(y_xplus_m_xplus.mean()),
        float(y_xplus_m_x.mean()),
        float(y_x_m_x.mean()),
        float(y_xplus_control.mean()),
        float(y_x_control.mean()),
    )


def bootstrap_draws(
    data: pd.DataFrame,
    effect_fn: Callable[[pd.DataFrame], dict[str, float]],
    seed: int,
) -> pd.DataFrame:
    rng = np.random.default_rng(seed)
    n = len(data)
    draws: list[dict[str, float]] = []

    for _ in range(BOOT_REPS):
        sample = data.iloc[rng.integers(0, n, n)].reset_index(drop=True)
        draws.append(effect_fn(sample))

    return pd.DataFrame.from_records(draws)


def build_categorical_data() -> pd.DataFrame:
    rng = np.random.default_rng(202605071)
    n = 620
    c1 = rng.normal(0.0, 1.0, n)
    c2 = rng.binomial(1, 0.40, n)

    x_logits = np.column_stack(
        [
            np.zeros(n),
            -0.15 + 0.45 * c1 - 0.25 * c2,
            -0.35 - 0.30 * c1 + 0.55 * c2,
        ]
    )
    x = np.array([rng.choice(3, p=p) for p in _softmax(x_logits)])
    x1 = (x == 1).astype(float)
    x2 = (x == 2).astype(float)

    m_logits = np.column_stack(
        [
            np.zeros(n),
            -0.45 + 0.55 * x1 + 0.25 * x2 + 0.35 * c1 - 0.20 * c2,
            -0.75 + 0.15 * x1 + 0.70 * x2 - 0.25 * c1 + 0.35 * c2,
        ]
    )
    m = np.array([rng.choice(3, p=p) for p in _softmax(m_logits)])
    m1 = (m == 1).astype(float)
    m2 = (m == 2).astype(float)

    y_prob = _invlogit(
        -1.05
        + 0.52 * m1
        + 0.88 * m2
        + 0.42 * x1
        + 0.72 * x2
        + 0.28 * c1
        - 0.18 * c2
    )
    y = rng.binomial(1, y_prob)

    return pd.DataFrame({"y": y, "m": m, "x": x, "c1": c1, "c2": c2})


def build_linexp_data() -> pd.DataFrame:
    rng = np.random.default_rng(202605072)
    n = 560
    c1 = rng.normal(0.0, 1.0, n)
    c2 = rng.normal(0.0, 1.0, n)
    x = 0.15 + 0.45 * c1 - 0.25 * c2 + rng.normal(0.0, 0.90, n)
    m = 0.20 + 0.72 * x + 0.35 * c1 - 0.28 * c2 + rng.normal(0.0, 0.75, n)
    y = 0.35 + 0.62 * m + 0.48 * x + 0.32 * c1 + 0.18 * c2 + rng.normal(0.0, 0.70, n)
    return pd.DataFrame({"y": y, "m": m, "x": x, "c1": c1, "c2": c2})


def add_reference_rows(
    rows: list[dict[str, object]],
    scenario: str,
    point: dict[str, float],
    draws: pd.DataFrame,
    note: str,
) -> None:
    tol = TOLERANCES[scenario]
    for effect_name, point_value in point.items():
        base_effect = effect_name.rsplit("_", 1)[0] if scenario == "oce_mlogit_logit" else effect_name
        level = effect_name.rsplit("_", 1)[1] if scenario == "oce_mlogit_logit" else ""
        point_abs_tol = tol.point_abs
        se_abs_tol = tol.se_abs
        se_rel_tol = tol.se_rel
        if base_effect == "pm":
            point_abs_tol = max(point_abs_tol, 0.060)
            se_abs_tol = max(se_abs_tol, 0.020)
            se_rel_tol = max(se_rel_tol, 0.32)
        rows.append(
            {
                "scenario": scenario,
                "scale": "rd",
                "level": level,
                "effect": base_effect,
                "stata_effect": effect_name,
                "point": point_value,
                "se": float(draws[effect_name].std(ddof=1)),
                "point_abs_tol": point_abs_tol,
                "se_abs_tol": se_abs_tol,
                "se_rel_tol": se_rel_tol,
                "python_boot_reps": BOOT_REPS,
                "stata_boot_reps": STATA_BOOT_REPS,
                "stata_mc_sims": STATA_MC_SIMS,
                "source": "statsmodels_plugin_bootstrap",
                "notes": note,
            }
        )


def add_covariance_rows(
    rows: list[dict[str, object]],
    scenario: str,
    draws: pd.DataFrame,
    note: str,
) -> None:
    tol = TOLERANCES[scenario]
    cov = draws.cov(ddof=1)
    corr = draws.corr()

    if scenario == "oce_mlogit_logit":
        levels = ("1", "2")
    else:
        levels = ("",)

    for level in levels:
        suffix = f"_{level}" if level else ""
        for effect1, effect2 in COVARIANCE_PAIRS:
            col1 = f"{effect1}{suffix}"
            col2 = f"{effect2}{suffix}"
            cov_value = float(cov.loc[col1, col2])
            rows.append(
                {
                    "scenario": scenario,
                    "scale": "rd",
                    "level": level,
                    "effect1": effect1,
                    "effect2": effect2,
                    "stata_effect1": col1,
                    "stata_effect2": col2,
                    "covariance": cov_value,
                    "correlation": float(corr.loc[col1, col2]),
                    "cov_abs_tol": max(tol.cov_floor, abs(cov_value) * tol.cov_rel),
                    "python_boot_reps": BOOT_REPS,
                    "stata_boot_reps": STATA_BOOT_REPS,
                    "stata_mc_sims": STATA_MC_SIMS,
                    "source": "statsmodels_plugin_bootstrap",
                    "notes": note,
                }
            )


def main() -> None:
    categorical = build_categorical_data()
    linexp = build_linexp_data()

    _write_csv(categorical, "mediation_extended_categorical.csv")
    _write_csv(linexp, "mediation_extended_linexp.csv")

    rows: list[dict[str, object]] = []
    covariance_rows: list[dict[str, object]] = []

    oce_point = categorical_effects(categorical, baseline=0, alternatives=(1, 2))
    oce_draws = bootstrap_draws(
        categorical,
        lambda data: categorical_effects(data, baseline=0, alternatives=(1, 2)),
        seed=202605171,
    )
    add_reference_rows(
        rows,
        "oce_mlogit_logit",
        oce_point,
        oce_draws,
        "OCE categorical exposure; multinomial mediator; binary outcome; baseline x=0; control m=0",
    )
    add_covariance_rows(
        covariance_rows,
        "oce_mlogit_logit",
        oce_draws,
        "OCE categorical exposure; multinomial mediator; binary outcome; baseline x=0; control m=0",
    )

    specific_point = specific_effects(categorical)
    specific_draws = bootstrap_draws(categorical, specific_effects, seed=202605172)
    add_reference_rows(
        rows,
        "specific_mlogit_logit",
        specific_point,
        specific_draws,
        "specific comparison x=2 versus x=0; multinomial mediator; binary outcome; control m=0",
    )
    add_covariance_rows(
        covariance_rows,
        "specific_mlogit_logit",
        specific_draws,
        "specific comparison x=2 versus x=0; multinomial mediator; binary outcome; control m=0",
    )

    linexp_point = linexp_effects(linexp)
    linexp_draws = bootstrap_draws(linexp, linexp_effects, seed=202605173)
    add_reference_rows(
        rows,
        "linexp_linear_linear",
        linexp_point,
        linexp_draws,
        "continuous exposure one-unit shift; linear mediator/outcome; control m=0",
    )
    add_covariance_rows(
        covariance_rows,
        "linexp_linear_linear",
        linexp_draws,
        "continuous exposure one-unit shift; linear mediator/outcome; control m=0",
    )

    _write_csv(pd.DataFrame(rows), "mediation_extended_reference.csv")
    _write_csv(pd.DataFrame(covariance_rows), "mediation_extended_covariance.csv")


if __name__ == "__main__":
    main()
