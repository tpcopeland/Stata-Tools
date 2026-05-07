#!/usr/bin/env python3
"""Generate external references for gcomp intervention/imputation QA."""

from __future__ import annotations

from pathlib import Path

import numpy as np
import pandas as pd
import statsmodels.api as sm


OUT_DIR = Path(__file__).resolve().parent

DYNAMIC_N = 320
IMPUTATION_N = 320
BOOT_REPS = 700
DYNAMIC_DATA_SEED = 20260521
IMPUTATION_DATA_SEED = 20260522
DYNAMIC_BOOT_SEED = 20260523
IMPUTATION_BOOT_SEED = 20260524
STOCHASTIC_BOOT_SEED = 20260527
DYNAMIC_THRESHOLD = 0.15
STOCHASTIC_PROB = 0.70


def expit(x: np.ndarray) -> np.ndarray:
    return 1.0 / (1.0 + np.exp(-x))


def add_constant(data: pd.DataFrame) -> pd.DataFrame:
    return sm.add_constant(data, has_constant="add")


def fit_ols(y: pd.Series, x: pd.DataFrame):
    return sm.OLS(y, add_constant(x)).fit()


def predict(model, x: pd.DataFrame) -> np.ndarray:
    return np.asarray(model.predict(add_constant(x)), dtype=float)


def write_csv(data: pd.DataFrame, filename: str) -> None:
    data.to_csv(OUT_DIR / filename, index=False, float_format="%.15g")


def make_dynamic_wide() -> pd.DataFrame:
    rng = np.random.default_rng(DYNAMIC_DATA_SEED)
    l0 = rng.normal(0.0, 1.0, DYNAMIC_N)
    l1 = -0.10 + 0.50 * l0 + rng.normal(0.0, 0.45, DYNAMIC_N)
    a1 = rng.binomial(1, expit(-0.25 + 0.58 * l1 + 0.18 * l0))

    l2 = 0.12 + 0.62 * l1 - 0.36 * a1 + 0.17 * l0
    a2 = rng.binomial(1, expit(-0.18 + 0.53 * l2 + 0.20 * l0))

    l3 = 0.08 + 0.58 * l2 - 0.31 * a2 + 0.14 * l0
    a3 = rng.binomial(1, expit(-0.12 + 0.49 * l3 + 0.16 * l0))

    y = 0.20 + 0.68 * l3 - 0.52 * a3 + 0.22 * l0

    return pd.DataFrame(
        {
            "id": np.arange(1, DYNAMIC_N + 1),
            "l0": l0,
            "l1": l1,
            "a1": a1,
            "l2": l2,
            "a2": a2,
            "l3": l3,
            "a3": a3,
            "y": y,
        }
    )


def dynamic_wide_to_long(wide: pd.DataFrame) -> pd.DataFrame:
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
                    "y": row.y if time == 3 else 0.0,
                }
            )
    return pd.DataFrame.from_records(records)


def fit_dynamic_models(wide: pd.DataFrame) -> dict[str, object]:
    return {
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
        "y": fit_ols(
            wide["y"], pd.DataFrame({"a": wide["a3"], "l": wide["l3"], "l0": wide["l0"]})
        ),
    }


def dynamic_a(l_value: np.ndarray) -> np.ndarray:
    return (l_value > DYNAMIC_THRESHOLD).astype(float)


def estimate_dynamic(wide: pd.DataFrame) -> dict[str, float]:
    models = fit_dynamic_models(wide)
    l0 = wide["l0"].to_numpy()
    l1 = wide["l1"].to_numpy()

    po: dict[str, float] = {}
    for regime in ("dynamic", "static1", "static0"):
        if regime == "dynamic":
            a1 = dynamic_a(l1)
        elif regime == "static1":
            a1 = np.ones(len(wide))
        else:
            a1 = np.zeros(len(wide))

        l2 = predict(models["l2"], pd.DataFrame({"alag": a1, "llag": l1, "l0": l0}))
        if regime == "dynamic":
            a2 = dynamic_a(l2)
        elif regime == "static1":
            a2 = np.ones(len(wide))
        else:
            a2 = np.zeros(len(wide))

        l3 = predict(models["l3"], pd.DataFrame({"alag": a2, "llag": l2, "l0": l0}))
        if regime == "dynamic":
            a3 = dynamic_a(l3)
        elif regime == "static1":
            a3 = np.ones(len(wide))
        else:
            a3 = np.zeros(len(wide))

        y_hat = predict(models["y"], pd.DataFrame({"a": a3, "l": l3, "l0": l0}))
        key = {"dynamic": "pody", "static1": "po1", "static0": "po0"}[regime]
        po[key] = float(np.mean(y_hat))

    po["rddy0"] = po["pody"] - po["po0"]
    po["rd10"] = po["po1"] - po["po0"]
    return po


def estimate_stochastic(wide: pd.DataFrame) -> dict[str, float]:
    models = fit_dynamic_models(wide)
    l0 = wide["l0"].to_numpy()
    l1 = wide["l1"].to_numpy()
    p = np.full(len(wide), STOCHASTIC_PROB)

    po: dict[str, float] = {}
    for regime in ("stochastic", "static1", "static0"):
        if regime == "stochastic":
            a1 = p
        elif regime == "static1":
            a1 = np.ones(len(wide))
        else:
            a1 = np.zeros(len(wide))

        l2 = predict(models["l2"], pd.DataFrame({"alag": a1, "llag": l1, "l0": l0}))
        if regime == "stochastic":
            a2 = p
        elif regime == "static1":
            a2 = np.ones(len(wide))
        else:
            a2 = np.zeros(len(wide))

        l3 = predict(models["l3"], pd.DataFrame({"alag": a2, "llag": l2, "l0": l0}))
        if regime == "stochastic":
            a3 = p
        elif regime == "static1":
            a3 = np.ones(len(wide))
        else:
            a3 = np.zeros(len(wide))

        y_hat = predict(models["y"], pd.DataFrame({"a": a3, "l": l3, "l0": l0}))
        key = {"stochastic": "postoch", "static1": "po1", "static0": "po0"}[regime]
        po[key] = float(np.mean(y_hat))

    po["rdstoch0"] = po["postoch"] - po["po0"]
    po["rd10"] = po["po1"] - po["po0"]
    return po


def make_imputation_data() -> pd.DataFrame:
    rng = np.random.default_rng(IMPUTATION_DATA_SEED)
    c = rng.normal(0.0, 1.0, IMPUTATION_N)
    z = rng.normal(0.0, 1.0, IMPUTATION_N)
    x = rng.binomial(1, expit(-0.15 + 0.45 * c))
    m_true = 0.35 + 0.70 * x + 0.45 * c + 0.55 * z
    y = 0.20 + 1.15 * x + 0.85 * m_true + 0.30 * c + rng.normal(
        0.0, 0.55, IMPUTATION_N
    )

    row = np.arange(1, IMPUTATION_N + 1)
    missing_m = (row % 6 == 0) | ((c > 0.65) & (x == 1) & (row % 2 == 0))
    m = m_true.copy()
    m[missing_m] = np.nan

    return pd.DataFrame({"y": y, "m": m, "x": x, "c": c, "z": z})


def impute_m(data: pd.DataFrame) -> pd.DataFrame:
    imputed = data.copy()
    observed = imputed["m"].notna()
    model = fit_ols(
        imputed.loc[observed, "m"], imputed.loc[observed, ["x", "c", "z"]]
    )
    imputed.loc[~observed, "m"] = predict(
        model, imputed.loc[~observed, ["x", "c", "z"]]
    )
    return imputed


def estimate_imputation(data: pd.DataFrame) -> dict[str, float]:
    imputed = impute_m(data)
    n = len(imputed)
    ones = np.ones(n)
    zeros = np.zeros(n)
    c = imputed["c"].to_numpy()

    med = fit_ols(imputed["m"], imputed[["x", "c"]])
    out = fit_ols(imputed["y"], imputed[["m", "x", "c"]])

    m1 = predict(med, pd.DataFrame({"x": ones, "c": c}))
    m0 = predict(med, pd.DataFrame({"x": zeros, "c": c}))

    y_1_m1 = predict(out, pd.DataFrame({"m": m1, "x": ones, "c": c}))
    y_1_m0 = predict(out, pd.DataFrame({"m": m0, "x": ones, "c": c}))
    y_0_m0 = predict(out, pd.DataFrame({"m": m0, "x": zeros, "c": c}))
    y_1_c0 = predict(out, pd.DataFrame({"m": zeros, "x": ones, "c": c}))
    y_0_c0 = predict(out, pd.DataFrame({"m": zeros, "x": zeros, "c": c}))

    tce = float(np.mean(y_1_m1) - np.mean(y_0_m0))
    nde = float(np.mean(y_1_m0) - np.mean(y_0_m0))
    nie = tce - nde
    pm = nie / tce
    cde = float(np.mean(y_1_c0) - np.mean(y_0_c0))

    return {"tce": tce, "nde": nde, "nie": nie, "pm": pm, "cde": cde}


def bootstrap(
    data: pd.DataFrame,
    estimator,
    seed: int,
) -> pd.DataFrame:
    rng = np.random.default_rng(seed)
    n = len(data)
    rows = []
    for rep in range(1, BOOT_REPS + 1):
        sample = data.iloc[rng.integers(0, n, n)].reset_index(drop=True)
        rows.append({"rep": rep, **estimator(sample)})
    return pd.DataFrame(rows)


def add_reference_rows(
    rows: list[dict[str, object]],
    scenario: str,
    estimates: dict[str, float],
    boot: pd.DataFrame,
) -> None:
    if scenario == "dyn":
        point_tol = {
            "pody": 0.015,
            "po1": 0.015,
            "po0": 0.015,
            "rddy0": 0.020,
            "rd10": 0.020,
        }
        se_abs_tol = {
            "pody": 0.012,
            "po1": 0.012,
            "po0": 0.012,
            "rddy0": 0.014,
            "rd10": 0.014,
        }
        note = (
            "conditional intervention uses Stata replacement-rule grammar; "
            "no explicit stochastic-intervention probability syntax is documented"
        )
    elif scenario == "stoch":
        point_tol = {
            "postoch": 0.035,
            "po1": 0.020,
            "po0": 0.020,
            "rdstoch0": 0.045,
            "rd10": 0.030,
        }
        se_abs_tol = {
            "postoch": 0.025,
            "po1": 0.018,
            "po0": 0.018,
            "rdstoch0": 0.030,
            "rd10": 0.025,
        }
        note = (
            "stochastic intervention uses Stata replacement rule "
            "a=(runiform()<0.70); Python reference integrates over Bernoulli "
            "probability, so Stata MC noise is allowed by tolerance"
        )
    else:
        point_tol = {"tce": 0.040, "nde": 0.040, "nie": 0.040, "pm": 0.080, "cde": 0.040}
        se_abs_tol = {"tce": 0.025, "nde": 0.025, "nie": 0.025, "pm": 0.040, "cde": 0.025}
        note = "deterministic regress imputation of missing mediator followed by linear mediation"

    for metric, estimate in estimates.items():
        rows.append(
            {
                "scenario": scenario,
                "metric": metric,
                "estimate": estimate,
                "se": float(boot[metric].std(ddof=1)),
                "tolerance_estimate": point_tol[metric],
                "tolerance_se_abs": se_abs_tol[metric],
                "tolerance_se_rel": 0.25 if scenario == "imp" else 0.20,
                "source": "python_statsmodels_plugin_bootstrap",
                "n": len(boot),
                "python_boot_reps": BOOT_REPS,
                "notes": note,
            }
        )


def add_covariance_rows(
    rows: list[dict[str, object]],
    scenario: str,
    boot: pd.DataFrame,
    pairs: list[tuple[str, str]],
) -> None:
    cov = boot.cov(ddof=1)
    corr = boot.corr()
    for metric1, metric2 in pairs:
        value = float(cov.loc[metric1, metric2])
        rows.append(
            {
                "scenario": scenario,
                "metric1": metric1,
                "metric2": metric2,
                "covariance": value,
                "correlation": float(corr.loc[metric1, metric2]),
                "cov_abs_tol": max(0.00035, abs(value) * 0.75),
                "source": "python_statsmodels_plugin_bootstrap",
                "python_boot_reps": BOOT_REPS,
            }
        )


def main() -> None:
    dynamic_wide = make_dynamic_wide()
    dynamic_long = dynamic_wide_to_long(dynamic_wide)
    write_csv(dynamic_long, "intervention_imputation_dynamic_data.csv")

    imputation_data = make_imputation_data()
    write_csv(imputation_data, "intervention_imputation_mediation_data.csv")

    dynamic_est = estimate_dynamic(dynamic_wide)
    dynamic_boot = bootstrap(dynamic_wide, estimate_dynamic, DYNAMIC_BOOT_SEED)

    stochastic_est = estimate_stochastic(dynamic_wide)
    stochastic_boot = bootstrap(
        dynamic_wide, estimate_stochastic, STOCHASTIC_BOOT_SEED
    )

    imputation_est = estimate_imputation(imputation_data)
    imputation_boot = bootstrap(
        imputation_data, estimate_imputation, IMPUTATION_BOOT_SEED
    )

    reference_rows: list[dict[str, object]] = []
    covariance_rows: list[dict[str, object]] = []

    add_reference_rows(reference_rows, "dyn", dynamic_est, dynamic_boot)
    add_covariance_rows(
        covariance_rows,
        "dyn",
        dynamic_boot,
        [("pody", "po0"), ("po1", "po0")],
    )

    add_reference_rows(reference_rows, "stoch", stochastic_est, stochastic_boot)
    add_covariance_rows(
        covariance_rows,
        "stoch",
        stochastic_boot,
        [("postoch", "po0"), ("po1", "po0")],
    )

    add_reference_rows(reference_rows, "imp", imputation_est, imputation_boot)
    add_covariance_rows(
        covariance_rows,
        "imp",
        imputation_boot,
        [("tce", "nde"), ("tce", "cde"), ("nde", "cde")],
    )

    write_csv(pd.DataFrame(reference_rows), "intervention_imputation_reference.csv")
    write_csv(pd.DataFrame(covariance_rows), "intervention_imputation_covariance.csv")


if __name__ == "__main__":
    main()
