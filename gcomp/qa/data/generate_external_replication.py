#!/usr/bin/env python3
"""Generate deterministic external replication fixtures for gcomp QA.

The Stata cross-validation consumes only the generated CSV files. This script
is retained to make the fixtures reproducible and documents the external
Python/statsmodels reference workflow used to compute expected values.
"""

from __future__ import annotations

from pathlib import Path

import numpy as np
import pandas as pd
import statsmodels.api as sm


OUT_DIR = Path(__file__).resolve().parent


def _add_constant(data: pd.DataFrame) -> pd.DataFrame:
    return sm.add_constant(data, has_constant="add")


def fit_logit(y: pd.Series, x: pd.DataFrame):
    return sm.GLM(y, _add_constant(x), family=sm.families.Binomial()).fit(
        maxiter=200, tol=1e-12
    )


def fit_ols(y: pd.Series, x: pd.DataFrame):
    return sm.OLS(y, _add_constant(x)).fit()


def predict(model, x: pd.DataFrame) -> np.ndarray:
    return np.asarray(model.predict(_add_constant(x)))


def write_csv(df: pd.DataFrame, name: str) -> None:
    df.to_csv(OUT_DIR / name, index=False, float_format="%.15g")


def add_ref(rows, analysis: str, metric: str, value: float, tolerance: float, note: str):
    rows.append(
        {
            "analysis": analysis,
            "metric": metric,
            "value": float(value),
            "tolerance": float(tolerance),
            "source": "python_statsmodels",
            "notes": note,
        }
    )


def mediation_binary(rows) -> None:
    rng = np.random.default_rng(20260506)
    n = 900
    c = rng.normal(0, 1, n)
    x = rng.binomial(1, 1 / (1 + np.exp(-(-0.25 + 0.55 * c))))
    m = rng.binomial(1, 1 / (1 + np.exp(-(-0.80 + 0.95 * x + 0.45 * c))))
    y = rng.binomial(1, 1 / (1 + np.exp(-(-1.35 + 0.75 * m + 0.55 * x + 0.35 * c))))

    df = pd.DataFrame({"c": c, "x": x, "m": m, "y": y})
    write_csv(df, "external_mediation_binary.csv")

    med = fit_logit(df["m"], df[["x", "c"]])
    out = fit_logit(df["y"], df[["m", "x", "c"]])

    p_m1 = predict(med, pd.DataFrame({"x": np.ones(n), "c": c}))
    p_m0 = predict(med, pd.DataFrame({"x": np.zeros(n), "c": c}))

    y_11 = predict(out, pd.DataFrame({"m": np.ones(n), "x": np.ones(n), "c": c}))
    y_10 = predict(out, pd.DataFrame({"m": np.zeros(n), "x": np.ones(n), "c": c}))
    y_01 = predict(out, pd.DataFrame({"m": np.ones(n), "x": np.zeros(n), "c": c}))
    y_00 = predict(out, pd.DataFrame({"m": np.zeros(n), "x": np.zeros(n), "c": c}))

    ey_1_m1 = np.mean(y_11 * p_m1 + y_10 * (1 - p_m1))
    ey_0_m0 = np.mean(y_01 * p_m0 + y_00 * (1 - p_m0))
    ey_1_m0 = np.mean(y_11 * p_m0 + y_10 * (1 - p_m0))
    tce = ey_1_m1 - ey_0_m0
    nde = ey_1_m0 - ey_0_m0
    nie = tce - nde
    pm = nie / tce
    cde = np.mean(y_10 - y_00)

    note = "binary mediator and binary outcome; plug-in parametric g-formula"
    add_ref(rows, "mediation_binary", "tce", tce, 0.005, note)
    add_ref(rows, "mediation_binary", "nde", nde, 0.005, note)
    add_ref(rows, "mediation_binary", "nie", nie, 0.005, note)
    add_ref(rows, "mediation_binary", "pm", pm, 0.020, note)
    add_ref(rows, "mediation_binary", "cde", cde, 0.001, note)


def mediation_continuous(rows) -> None:
    rng = np.random.default_rng(20260507)
    n = 800
    c = rng.normal(0, 1, n)
    x = rng.binomial(1, 1 / (1 + np.exp(-(-0.15 + 0.45 * c))))
    m = rng.binomial(1, 1 / (1 + np.exp(-(-0.65 + 0.85 * x + 0.40 * c))))
    y = 0.70 + 0.65 * m + 0.45 * x + 0.35 * c + rng.normal(0, 0.55, n)

    df = pd.DataFrame({"c": c, "x": x, "m": m, "y": y})
    write_csv(df, "external_mediation_continuous.csv")

    med = fit_logit(df["m"], df[["x", "c"]])
    out = fit_ols(df["y"], df[["m", "x", "c"]])

    p_m1 = predict(med, pd.DataFrame({"x": np.ones(n), "c": c}))
    p_m0 = predict(med, pd.DataFrame({"x": np.zeros(n), "c": c}))

    y_11 = predict(out, pd.DataFrame({"m": np.ones(n), "x": np.ones(n), "c": c}))
    y_10 = predict(out, pd.DataFrame({"m": np.zeros(n), "x": np.ones(n), "c": c}))
    y_01 = predict(out, pd.DataFrame({"m": np.ones(n), "x": np.zeros(n), "c": c}))
    y_00 = predict(out, pd.DataFrame({"m": np.zeros(n), "x": np.zeros(n), "c": c}))

    ey_1_m1 = np.mean(y_11 * p_m1 + y_10 * (1 - p_m1))
    ey_0_m0 = np.mean(y_01 * p_m0 + y_00 * (1 - p_m0))
    ey_1_m0 = np.mean(y_11 * p_m0 + y_10 * (1 - p_m0))
    tce = ey_1_m1 - ey_0_m0
    nde = ey_1_m0 - ey_0_m0
    nie = tce - nde
    pm = nie / tce
    cde = np.mean(y_10 - y_00)

    note = "binary mediator and continuous outcome; GLM logit plus OLS g-formula"
    add_ref(rows, "mediation_continuous", "tce", tce, 0.015, note)
    add_ref(rows, "mediation_continuous", "nde", nde, 0.010, note)
    add_ref(rows, "mediation_continuous", "nie", nie, 0.015, note)
    add_ref(rows, "mediation_continuous", "pm", pm, 0.030, note)
    add_ref(rows, "mediation_continuous", "cde", cde, 0.001, note)


def timevarying(rows) -> None:
    rng = np.random.default_rng(20260508)
    n_subjects = 450

    l0 = rng.normal(0, 1, n_subjects)
    l1 = 0.20 + 0.55 * l0
    p_a1 = 1 / (1 + np.exp(-(-0.25 + 0.65 * l1 + 0.25 * l0)))
    a1 = rng.binomial(1, p_a1)

    l2 = 0.10 + 0.62 * l1 - 0.50 * a1 + 0.20 * l0
    p_a2 = 1 / (1 + np.exp(-(-0.15 + 0.60 * l2 + 0.22 * l0)))
    a2 = rng.binomial(1, p_a2)

    l3 = 0.05 + 0.58 * l2 - 0.45 * a2 + 0.15 * l0
    p_a3 = 1 / (1 + np.exp(-(-0.05 + 0.55 * l3 + 0.20 * l0)))
    a3 = rng.binomial(1, p_a3)

    p_y = 1 / (1 + np.exp(-(-1.10 - 0.80 * a2 + 0.65 * l2 + 0.25 * l0)))
    y = rng.binomial(1, p_y)
    yc = 0.50 - 0.70 * a2 + 0.80 * l2 + 0.30 * l0 + rng.normal(0, 0.45, n_subjects)

    records = []
    for i in range(n_subjects):
        avals = [a1[i], a2[i], a3[i]]
        lvals = [l1[i], l2[i], l3[i]]
        for time in (1, 2, 3):
            records.append(
                {
                    "id": i + 1,
                    "time": time,
                    "l0": l0[i],
                    "a": avals[time - 1],
                    "l": lvals[time - 1],
                    "alag": 0 if time == 1 else avals[time - 2],
                    "llag": 0 if time == 1 else lvals[time - 2],
                    "y": y[i] if time == 3 else 0,
                    "yc": yc[i] if time == 3 else 0.0,
                }
            )

    df = pd.DataFrame(records)
    write_csv(df, "external_timevarying.csv")

    visits = {time: df[df["time"] == time].copy() for time in (1, 2, 3)}
    l2_model = fit_ols(visits[2]["l"], visits[2][["alag", "llag", "l0"]])
    y_model = fit_logit(visits[3]["y"], visits[3][["alag", "llag", "l0"]])
    yc_model = fit_ols(visits[3]["yc"], visits[3][["alag", "llag", "l0"]])

    def po(aval: int, y_model_ref) -> float:
        a1_fixed = np.full(n_subjects, aval)
        l2_hat = predict(l2_model, pd.DataFrame({"alag": a1_fixed, "llag": l1, "l0": l0}))
        a2_fixed = np.full(n_subjects, aval)
        y_hat = predict(y_model_ref, pd.DataFrame({"alag": a2_fixed, "llag": l2_hat, "l0": l0}))
        return float(np.mean(y_hat))

    po_bin_a1 = po(1, y_model)
    po_bin_a0 = po(0, y_model)
    po_cont_a1 = po(1, yc_model)
    po_cont_a0 = po(0, yc_model)

    note = "3-visit sequential g-formula; deterministic L transitions; A fixed at all visits"
    add_ref(rows, "timevarying_binary", "po_a1", po_bin_a1, 0.00001, note)
    add_ref(rows, "timevarying_binary", "po_a0", po_bin_a0, 0.00001, note)
    add_ref(rows, "timevarying_binary", "rd_a1_a0", po_bin_a1 - po_bin_a0, 0.00001, note)
    add_ref(rows, "timevarying_continuous", "po_a1", po_cont_a1, 0.00001, note)
    add_ref(rows, "timevarying_continuous", "po_a0", po_cont_a0, 0.00001, note)
    add_ref(rows, "timevarying_continuous", "rd_a1_a0", po_cont_a1 - po_cont_a0, 0.00001, note)


def main() -> None:
    rows = []
    mediation_binary(rows)
    mediation_continuous(rows)
    timevarying(rows)
    write_csv(pd.DataFrame(rows), "external_reference.csv")


if __name__ == "__main__":
    main()
