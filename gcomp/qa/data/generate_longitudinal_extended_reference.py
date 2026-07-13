#!/usr/bin/env python3
"""Generate external references for extended longitudinal gcomp QA.

The fixture targets non-EOFU time-varying output under a pooled simulation
model: survival-style log incidence rates, cumulative outcome/death incidence,
and a logit MSM fitted to the pooled intervention risk sets.
"""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

import numpy as np
import pandas as pd
import statsmodels.api as sm


OUT_DIR = Path(__file__).resolve().parent
N_SUBJECTS = 720
N_VISITS = 4
DATA_SEED = 20260517
BOOT_SEED = 20260518
BOOT_REPS = 220


@dataclass
class InterventionSummary:
    log_ir: float
    out: float
    death: float
    person_time: float
    event_period_rate: float


def expit(x: np.ndarray | float) -> np.ndarray | float:
    return 1.0 / (1.0 + np.exp(-x))


def logit(p: float) -> float:
    clipped = min(max(p, 1e-10), 1.0 - 1e-10)
    return float(np.log(clipped / (1.0 - clipped)))


def add_constant(data: pd.DataFrame) -> pd.DataFrame:
    return sm.add_constant(data, has_constant="add")


def fit_logit(y: pd.Series, x: pd.DataFrame):
    return sm.GLM(y, add_constant(x), family=sm.families.Binomial()).fit(
        maxiter=200, tol=1e-12
    )


def predict(model, x: pd.DataFrame) -> np.ndarray:
    return np.asarray(model.predict(add_constant(x)), dtype=float)


def write_csv(df: pd.DataFrame, name: str) -> None:
    df.to_csv(OUT_DIR / name, index=False, float_format="%.15g")


def make_data() -> pd.DataFrame:
    rng = np.random.default_rng(DATA_SEED)
    rows: list[dict[str, float | int]] = []

    for subject_id in range(1, N_SUBJECTS + 1):
        c = float(rng.normal(0.0, 1.0))
        for time in range(1, N_VISITS + 1):
            l = float(0.15 + 0.52 * c + 0.12 * time + rng.normal(0.0, 0.45))
            p_a = expit(-0.20 + 0.42 * c + 0.10 * (time - 2.0))
            a = int(rng.binomial(1, p_a))

            p_d = expit(-3.25 + 0.18 * a + 0.30 * c + 0.20 * (time - 1.0))
            d = int(rng.binomial(1, p_d))

            if d == 1:
                y = 0
            else:
                p_y = expit(-2.80 - 0.62 * a + 0.36 * c + 0.24 * (time - 1.0))
                y = int(rng.binomial(1, p_y))

            rows.append(
                {
                    "id": subject_id,
                    "time": time,
                    "c": c,
                    "l": l,
                    "a": a,
                    "d": d,
                    "y": y,
                }
            )

            if d == 1 or y == 1:
                break

    return pd.DataFrame.from_records(rows)


def subject_frame(data: pd.DataFrame) -> pd.DataFrame:
    return (
        data.sort_values(["id", "time"])
        .drop_duplicates("id")[["id", "c"]]
        .reset_index(drop=True)
    )


def fit_pooled_models(data: pd.DataFrame) -> dict[str, object]:
    models: dict[str, object] = {}
    models["d"] = fit_logit(data["d"], data[["a", "c"]])
    models["l"] = sm.OLS(data["l"], add_constant(data[["c"]])).fit()
    models["a"] = fit_logit(data["a"], data[["c", "l"]])
    models["y"] = fit_logit(data["y"], data[["a", "c"]])
    return models


def intervention_summary(
    subjects: pd.DataFrame,
    models: dict[str, object],
    a_value: int,
) -> InterventionSummary:
    c = subjects["c"].to_numpy(dtype=float)
    n = float(len(subjects))
    alive = np.ones(len(subjects), dtype=float)
    out_events = 0.0
    death_events = 0.0
    person_time = 0.0

    for time in range(1, N_VISITS + 1):
        x = pd.DataFrame({"a": np.full(len(subjects), a_value), "c": c})
        p_d = predict(models["d"], x)
        p_y = predict(models["y"], x)

        person_time += float(np.sum(alive))
        death_events += float(np.sum(alive * p_d))
        out_events += float(np.sum(alive * (1.0 - p_d) * p_y))
        alive = alive * (1.0 - p_d) * (1.0 - p_y)

    cumulative_out = out_events / n
    cumulative_death = death_events / n
    event_period_rate = out_events / person_time
    return InterventionSummary(
        log_ir=float(np.log(event_period_rate)),
        out=float(cumulative_out),
        death=float(cumulative_death),
        person_time=float(person_time),
        event_period_rate=float(event_period_rate),
    )


def estimate(data: pd.DataFrame) -> dict[str, float]:
    subjects = subject_frame(data)
    models = fit_pooled_models(data)

    treated = intervention_summary(subjects, models, 1)
    untreated = intervention_summary(subjects, models, 0)

    msm_cons = logit(untreated.event_period_rate)
    msm_a = logit(treated.event_period_rate) - msm_cons

    return {
        "po_a1": treated.log_ir,
        "po_a0": untreated.log_ir,
        "out_a1": treated.out,
        "out_a0": untreated.out,
        "death_a1": treated.death,
        "death_a0": untreated.death,
        "out_diff_a1_a0": treated.out - untreated.out,
        "death_diff_a1_a0": treated.death - untreated.death,
        "msm_a": msm_a,
        "msm_cons": msm_cons,
    }


def resample_subjects(data: pd.DataFrame, rng: np.random.Generator) -> pd.DataFrame:
    ids = np.asarray(sorted(data["id"].unique()))
    sampled_ids = rng.choice(ids, size=len(ids), replace=True)
    parts = []
    for new_id, old_id in enumerate(sampled_ids, start=1):
        part = data.loc[data["id"] == old_id].copy()
        part["id"] = new_id
        parts.append(part)
    return pd.concat(parts, ignore_index=True)


def bootstrap(data: pd.DataFrame) -> pd.DataFrame:
    rng = np.random.default_rng(BOOT_SEED)
    rows = []
    for rep in range(1, BOOT_REPS + 1):
        sample = resample_subjects(data, rng)
        try:
            est = estimate(sample)
        except Exception:
            continue
        rows.append({"rep": rep, **est})
    boot = pd.DataFrame(rows)
    if len(boot) < int(0.95 * BOOT_REPS):
        raise RuntimeError("too many failed bootstrap fits")
    return boot


def reference_rows(est: dict[str, float], boot: pd.DataFrame) -> list[dict[str, object]]:
    se = boot.drop(columns=["rep"]).std(ddof=1).to_dict()
    # The Python oracle integrates the fitted event law exactly, whereas gcomp's
    # non-EOFU point run draws one Monte Carlo population of N_SUBJECTS. A fixed
    # absolute tolerance below one MC standard deviation is therefore a false
    # precision gate. Derive a 2.5-SD bound from the oracle's expected event
    # counts/person-time and retain the original software-agreement floors.
    event_rate_a1 = float(np.exp(est["po_a1"]))
    event_rate_a0 = float(np.exp(est["po_a0"]))
    event_count_a1 = N_SUBJECTS * est["out_a1"]
    event_count_a0 = N_SUBJECTS * est["out_a0"]
    person_time_a1 = event_count_a1 / event_rate_a1
    person_time_a0 = event_count_a0 / event_rate_a0
    mc_se_log_rate_a1 = 1.0 / np.sqrt(event_count_a1)
    mc_se_log_rate_a0 = 1.0 / np.sqrt(event_count_a0)
    mc_se_logit_a1 = np.sqrt(
        1.0 / (person_time_a1 * event_rate_a1 * (1.0 - event_rate_a1))
    )
    mc_se_logit_a0 = np.sqrt(
        1.0 / (person_time_a0 * event_rate_a0 * (1.0 - event_rate_a0))
    )
    mc_bound = {
        "po_a1": 2.5 * mc_se_log_rate_a1,
        "po_a0": 2.5 * mc_se_log_rate_a0,
        "msm_a": 2.5 * np.sqrt(mc_se_logit_a1**2 + mc_se_logit_a0**2),
        "msm_cons": 2.5 * mc_se_logit_a0,
    }
    tol_est = {
        "po_a1": max(0.08, mc_bound["po_a1"]),
        "po_a0": max(0.08, mc_bound["po_a0"]),
        "out_a1": 0.03,
        "out_a0": 0.03,
        "death_a1": 0.03,
        "death_a0": 0.03,
        "out_diff_a1_a0": 0.04,
        "death_diff_a1_a0": 0.04,
        "msm_a": max(0.12, mc_bound["msm_a"]),
        "msm_cons": max(0.05, mc_bound["msm_cons"]),
    }
    tol_se = {
        "po_a1": 0.08,
        "po_a0": 0.06,
        "out_a1": 0.025,
        "out_a0": 0.025,
        "death_a1": 0.025,
        "death_a0": 0.025,
        "out_diff_a1_a0": 0.035,
        "death_diff_a1_a0": 0.035,
        "msm_a": 0.12,
        "msm_cons": 0.06,
    }
    rows: list[dict[str, object]] = []
    for metric, value in est.items():
        rows.append(
            {
                "analysis": "survival_death_msm",
                "metric": metric,
                "estimate": value,
                "se": se[metric],
                "tolerance_estimate": tol_est[metric],
                "tolerance_se": tol_se[metric],
                "source": "python_statsmodels_pooled_plugin_subject_bootstrap",
                "n_subjects": N_SUBJECTS,
                "n_visits": N_VISITS,
                "bootstrap_reps": len(boot),
                "data_seed": DATA_SEED,
                "bootstrap_seed": BOOT_SEED,
                "notes": "pooled GLM Binomial nuisance models; deterministic plug-in oracle; point tolerance includes 2.5-SD stochastic Stata MC bound",
            }
        )
    return rows


def covariance_rows(boot: pd.DataFrame) -> list[dict[str, object]]:
    pairs = [
        ("out_a1", "out_a0"),
        ("death_a1", "death_a0"),
        ("msm_a", "msm_cons"),
    ]
    cov = boot.drop(columns=["rep"]).cov()
    corr = boot.drop(columns=["rep"]).corr()
    rows: list[dict[str, object]] = []
    for metric1, metric2 in pairs:
        cov_value = float(cov.loc[metric1, metric2])
        if metric1.startswith("msm_") or metric2.startswith("msm_"):
            tolerance_covariance = max(abs(cov_value) * 2.5, 0.015)
        else:
            tolerance_covariance = max(abs(cov_value) * 1.25, 0.001)
        rows.append(
            {
                "analysis": "survival_death_msm",
                "metric1": metric1,
                "metric2": metric2,
                "covariance": cov_value,
                "correlation": float(corr.loc[metric1, metric2]),
                "tolerance_covariance": tolerance_covariance,
                "source": "python_statsmodels_pooled_plugin_subject_bootstrap",
                "n_subjects": N_SUBJECTS,
                "bootstrap_reps": len(boot),
                "notes": "pooled subject-bootstrap off-diagonal covariance for selected longitudinal outputs",
            }
        )
    return rows


def main() -> None:
    data = make_data()
    est = estimate(data)
    boot = bootstrap(data)

    write_csv(data, "longitudinal_extended_survival.csv")
    write_csv(pd.DataFrame(reference_rows(est, boot)), "longitudinal_extended_reference.csv")
    write_csv(pd.DataFrame(covariance_rows(boot)), "longitudinal_extended_covariance.csv")


if __name__ == "__main__":
    main()
