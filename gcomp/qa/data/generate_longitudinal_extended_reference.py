#!/usr/bin/env python3
"""Generate external references for extended longitudinal gcomp QA.

The fixture targets non-EOFU time-varying output: survival-style log incidence
rates, cumulative outcome/death incidence, and a simple logit MSM fitted to
the simulated intervention risk sets.
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


def fit_visit_models(data: pd.DataFrame) -> dict[tuple[str, int], object]:
    models: dict[tuple[str, int], object] = {}
    for time in range(1, N_VISITS + 1):
        visit = data.loc[data["time"] == time].copy()
        if visit.empty:
            raise RuntimeError(f"no rows available at visit {time}")

        models[("d", time)] = fit_logit(visit["d"], visit[["a", "c"]])
        models[("l", time)] = sm.OLS(visit["l"], add_constant(visit[["c"]])).fit()
        models[("a", time)] = fit_logit(visit["a"], visit[["c", "l"]])
        models[("y", time)] = fit_logit(visit["y"], visit[["a", "c"]])

    return models


def intervention_summary(
    subjects: pd.DataFrame,
    models: dict[tuple[str, int], object],
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
        p_d = predict(models[("d", time)], x)
        p_y = predict(models[("y", time)], x)

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
    models = fit_visit_models(data)

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
    tol_est = {
        "po_a1": 0.18,
        "po_a0": 0.16,
        "out_a1": 0.055,
        "out_a0": 0.060,
        "death_a1": 0.055,
        "death_a0": 0.055,
        "out_diff_a1_a0": 0.075,
        "death_diff_a1_a0": 0.075,
        "msm_a": 0.40,
        "msm_cons": 0.28,
    }
    tol_se = {
        "po_a1": 0.12,
        "po_a0": 0.12,
        "out_a1": 0.055,
        "out_a0": 0.055,
        "death_a1": 0.055,
        "death_a0": 0.055,
        "out_diff_a1_a0": 0.070,
        "death_diff_a1_a0": 0.070,
        "msm_a": 0.24,
        "msm_cons": 0.16,
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
                "source": "python_statsmodels_plugin_subject_bootstrap",
                "n_subjects": N_SUBJECTS,
                "n_visits": N_VISITS,
                "bootstrap_reps": len(boot),
                "data_seed": DATA_SEED,
                "bootstrap_seed": BOOT_SEED,
                "notes": "visit-specific GLM Binomial nuisance models; deterministic plug-in intervention summaries",
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
        rows.append(
            {
                "analysis": "survival_death_msm",
                "metric1": metric1,
                "metric2": metric2,
                "covariance": cov_value,
                "correlation": float(corr.loc[metric1, metric2]),
                "tolerance_covariance": max(abs(cov_value) * 1.25, 0.006),
                "source": "python_statsmodels_plugin_subject_bootstrap",
                "n_subjects": N_SUBJECTS,
                "bootstrap_reps": len(boot),
                "notes": "subject-bootstrap off-diagonal covariance for selected longitudinal outputs",
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
