#!/usr/bin/env python3
"""External-dataset reference calculations for psdash QA."""

from __future__ import annotations

import csv
import math
import sys
from pathlib import Path

try:
    import numpy as np
    import pandas as pd
    import statsmodels.api as sm
    from sklearn.datasets import load_iris
    from sklearn.linear_model import LogisticRegression
except Exception as exc:  # pragma: no cover - exercised by Stata dependency skip
    print(f"SKIP dependency unavailable: {exc}", file=sys.stderr)
    raise SystemExit(77)


def sample_var(values: np.ndarray) -> float:
    return float(np.var(values.astype(float), ddof=1))


def sample_sd(values: np.ndarray) -> float:
    return math.sqrt(sample_var(values))


def weighted_mean(values: np.ndarray, weights: np.ndarray) -> float:
    return float(np.sum(values * weights) / np.sum(weights))


def ess(weights: np.ndarray) -> float:
    return float(np.sum(weights) ** 2 / np.sum(weights**2))


def ks_2sample(left: np.ndarray, right: np.ndarray) -> float:
    points = np.unique(np.concatenate([left, right]))
    max_diff = 0.0
    for point in points:
        fl = np.mean(left <= point)
        fr = np.mean(right <= point)
        max_diff = max(max_diff, abs(float(fl - fr)))
    return max_diff


def auc_pairwise(treated_ps: np.ndarray, control_ps: np.ndarray) -> float:
    score = 0.0
    for tp in treated_ps:
        score += float(np.sum(tp > control_ps))
        score += 0.5 * float(np.sum(tp == control_ps))
    return score / (len(treated_ps) * len(control_ps))


def binary_weights(treat: np.ndarray, ps: np.ndarray, estimand: str) -> np.ndarray:
    if estimand == "ate":
        return np.where(treat == 1, 1.0 / ps, 1.0 / (1.0 - ps))
    if estimand == "att":
        return np.where(treat == 1, 1.0, ps / (1.0 - ps))
    if estimand == "atc":
        return np.where(treat == 1, (1.0 - ps) / ps, 1.0)
    raise ValueError(f"unknown estimand: {estimand}")


def add_metric(rows: list[tuple[str, float]], key: str, value: float) -> None:
    rows.append((key, float(value)))


def add_weight_metrics(
    rows: list[tuple[str, float]], prefix: str, treat: np.ndarray, weights: np.ndarray
) -> None:
    tmask = treat == 1
    cmask = treat == 0
    add_metric(rows, f"{prefix}_w_mean", float(np.mean(weights)))
    add_metric(rows, f"{prefix}_w_sd", sample_sd(weights))
    add_metric(rows, f"{prefix}_w_min", float(np.min(weights)))
    add_metric(rows, f"{prefix}_w_max", float(np.max(weights)))
    add_metric(rows, f"{prefix}_w_cv", sample_sd(weights) / float(np.mean(weights)))
    add_metric(rows, f"{prefix}_w_ess", ess(weights))
    add_metric(rows, f"{prefix}_w_esspct", 100.0 * ess(weights) / len(weights))
    add_metric(rows, f"{prefix}_w_esst", ess(weights[tmask]))
    add_metric(rows, f"{prefix}_w_essc", ess(weights[cmask]))
    add_metric(rows, f"{prefix}_w_next", float(np.sum(weights > 10)))


def binary_reference(
    rows: list[tuple[str, float]],
    prefix: str,
    data: pd.DataFrame,
    treat_col: str,
    ps_col: str,
    covars: list[tuple[str, str]],
    estimand: str = "ate",
    threshold: float = 0.1,
    trim_threshold: float = 0.1,
) -> None:
    treat = data[treat_col].to_numpy(dtype=int)
    ps = data[ps_col].to_numpy(dtype=float)
    weights = binary_weights(treat, ps, estimand)
    tmask = treat == 1
    cmask = treat == 0

    add_metric(rows, f"{prefix}_N", len(data))
    add_metric(rows, f"{prefix}_Nt", int(np.sum(tmask)))
    add_metric(rows, f"{prefix}_Nc", int(np.sum(cmask)))

    t_ps = ps[tmask]
    c_ps = ps[cmask]
    lower = max(float(np.min(t_ps)), float(np.min(c_ps)))
    upper = min(float(np.max(t_ps)), float(np.max(c_ps)))
    outside = (ps < lower) | (ps > upper)
    add_metric(rows, f"{prefix}_ol_mt", float(np.mean(t_ps)))
    add_metric(rows, f"{prefix}_ol_mc", float(np.mean(c_ps)))
    add_metric(rows, f"{prefix}_ol_mint", float(np.min(t_ps)))
    add_metric(rows, f"{prefix}_ol_maxt", float(np.max(t_ps)))
    add_metric(rows, f"{prefix}_ol_minc", float(np.min(c_ps)))
    add_metric(rows, f"{prefix}_ol_maxc", float(np.max(c_ps)))
    add_metric(rows, f"{prefix}_ol_lo", lower)
    add_metric(rows, f"{prefix}_ol_hi", upper)
    add_metric(rows, f"{prefix}_ol_nout", int(np.sum(outside)))
    add_metric(rows, f"{prefix}_ol_pct", 100.0 * float(np.mean(outside)))
    add_metric(rows, f"{prefix}_auc", auc_pairwise(t_ps, c_ps))

    trimmed = (ps < trim_threshold) | (ps > 1.0 - trim_threshold)
    add_metric(rows, f"{prefix}_sup_lo", lower)
    add_metric(rows, f"{prefix}_sup_hi", upper)
    add_metric(rows, f"{prefix}_sup_nout", int(np.sum(outside)))
    add_metric(rows, f"{prefix}_sup_noutt", int(np.sum(outside & tmask)))
    add_metric(rows, f"{prefix}_sup_noutc", int(np.sum(outside & cmask)))
    add_metric(rows, f"{prefix}_sup_pct", 100.0 * float(np.mean(outside)))
    add_metric(rows, f"{prefix}_tr_lo", trim_threshold)
    add_metric(rows, f"{prefix}_tr_hi", 1.0 - trim_threshold)
    add_metric(rows, f"{prefix}_tr_n", int(np.sum(trimmed)))
    add_metric(rows, f"{prefix}_tr_pct", 100.0 * float(np.mean(trimmed)))

    add_weight_metrics(rows, prefix, treat, weights)
    add_metric(rows, f"{prefix}_w1", weights[0])
    add_metric(rows, f"{prefix}_wlast", weights[-1])

    max_smd_raw = 0.0
    max_smd_adj = 0.0
    max_ks = 0.0
    n_imbalanced = 0

    for covar, cov_key in covars:
        values = data[covar].to_numpy(dtype=float)
        t_values = values[tmask]
        c_values = values[cmask]
        t_weights = weights[tmask]
        c_weights = weights[cmask]

        mean_t = float(np.mean(t_values))
        mean_c = float(np.mean(c_values))
        var_t = sample_var(t_values)
        var_c = sample_var(c_values)
        pooled_sd = math.sqrt((var_t + var_c) / 2.0)
        if pooled_sd > 0:
            smd_raw = (mean_t - mean_c) / pooled_sd
        elif mean_t == mean_c:
            smd_raw = 0.0
        else:
            smd_raw = math.nan

        mean_t_adj = weighted_mean(t_values, t_weights)
        mean_c_adj = weighted_mean(c_values, c_weights)
        if pooled_sd > 0:
            smd_adj = (mean_t_adj - mean_c_adj) / pooled_sd
        elif mean_t_adj == mean_c_adj:
            smd_adj = 0.0
        else:
            smd_adj = math.nan

        vr_raw = var_t / var_c if var_t > 0 and var_c > 0 else math.nan
        ks_raw = ks_2sample(t_values, c_values)

        add_metric(rows, f"{prefix}_b_{cov_key}_mt", mean_t)
        add_metric(rows, f"{prefix}_b_{cov_key}_mc", mean_c)
        add_metric(rows, f"{prefix}_b_{cov_key}_smd", smd_raw)
        add_metric(rows, f"{prefix}_b_{cov_key}_vr", vr_raw)
        add_metric(rows, f"{prefix}_b_{cov_key}_ks", ks_raw)
        add_metric(rows, f"{prefix}_b_{cov_key}_mta", mean_t_adj)
        add_metric(rows, f"{prefix}_b_{cov_key}_mca", mean_c_adj)
        add_metric(rows, f"{prefix}_b_{cov_key}_smda", smd_adj)

        max_smd_raw = max(max_smd_raw, abs(smd_raw))
        max_smd_adj = max(max_smd_adj, abs(smd_adj))
        max_ks = max(max_ks, ks_raw)
        if math.isnan(smd_adj) or abs(smd_adj) > threshold:
            n_imbalanced += 1

    add_metric(rows, f"{prefix}_b_maxsmd", max_smd_raw)
    add_metric(rows, f"{prefix}_b_maxsmda", max_smd_adj)
    add_metric(rows, f"{prefix}_b_maxks", max_ks)
    add_metric(rows, f"{prefix}_b_nimb", n_imbalanced)


def multigroup_reference(
    rows: list[tuple[str, float]],
    prefix: str,
    data: pd.DataFrame,
    treat_col: str,
    ps_cols: dict[int, str],
    covars: list[tuple[str, str]],
    reference: int = 0,
    threshold: float = 0.1,
    trim_threshold: float = 0.1,
) -> None:
    treat = data[treat_col].to_numpy(dtype=int)
    levels = sorted(ps_cols)
    obs_ps = np.empty(len(data), dtype=float)
    for level in levels:
        obs_ps[treat == level] = data.loc[treat == level, ps_cols[level]].to_numpy(dtype=float)
    weights = 1.0 / obs_ps

    add_metric(rows, f"{prefix}_N", len(data))
    add_metric(rows, f"{prefix}_K", len(levels))

    mins: dict[int, float] = {}
    maxs: dict[int, float] = {}
    for level in levels:
        mask = treat == level
        own_ps = data.loc[mask, ps_cols[level]].to_numpy(dtype=float)
        mins[level] = float(np.min(own_ps))
        maxs[level] = float(np.max(own_ps))
        add_metric(rows, f"{prefix}_Ng{level}", int(np.sum(mask)))
        add_metric(rows, f"{prefix}_ol_mean{level}", float(np.mean(own_ps)))
        add_metric(rows, f"{prefix}_ol_min{level}", mins[level])
        add_metric(rows, f"{prefix}_ol_max{level}", maxs[level])

    lower = max(mins.values())
    upper = min(maxs.values())
    outside = (obs_ps < lower) | (obs_ps > upper)
    add_metric(rows, f"{prefix}_ol_lo", lower)
    add_metric(rows, f"{prefix}_ol_hi", upper)
    add_metric(rows, f"{prefix}_ol_nout", int(np.sum(outside)))
    add_metric(rows, f"{prefix}_ol_pct", 100.0 * float(np.mean(outside)))

    add_metric(rows, f"{prefix}_sup_lo", lower)
    add_metric(rows, f"{prefix}_sup_hi", upper)
    add_metric(rows, f"{prefix}_sup_nout", int(np.sum(outside)))
    for level in levels:
        add_metric(rows, f"{prefix}_sup_nout{level}", int(np.sum(outside & (treat == level))))
    trimmed = (obs_ps < trim_threshold) | (obs_ps > 1.0 - trim_threshold)
    add_metric(rows, f"{prefix}_sup_pct", 100.0 * float(np.mean(outside)))
    add_metric(rows, f"{prefix}_tr_lo", trim_threshold)
    add_metric(rows, f"{prefix}_tr_hi", 1.0 - trim_threshold)
    add_metric(rows, f"{prefix}_tr_n", int(np.sum(trimmed)))
    add_metric(rows, f"{prefix}_tr_pct", 100.0 * float(np.mean(trimmed)))

    add_metric(rows, f"{prefix}_w_mean", float(np.mean(weights)))
    add_metric(rows, f"{prefix}_w_sd", sample_sd(weights))
    add_metric(rows, f"{prefix}_w_min", float(np.min(weights)))
    add_metric(rows, f"{prefix}_w_max", float(np.max(weights)))
    add_metric(rows, f"{prefix}_w_cv", sample_sd(weights) / float(np.mean(weights)))
    add_metric(rows, f"{prefix}_w_ess", ess(weights))
    add_metric(rows, f"{prefix}_w_esspct", 100.0 * ess(weights) / len(weights))
    add_metric(rows, f"{prefix}_w_next", int(np.sum(weights > 10)))
    for level in levels:
        lw = weights[treat == level]
        add_metric(rows, f"{prefix}_w_ess{level}", ess(lw))
        add_metric(rows, f"{prefix}_w_essp{level}", 100.0 * ess(lw) / len(lw))
    add_metric(rows, f"{prefix}_w1", weights[0])
    add_metric(rows, f"{prefix}_w60", weights[59])
    add_metric(rows, f"{prefix}_w120", weights[119])

    ref_mask = treat == reference
    max_smd_raw = 0.0
    max_smd_adj = 0.0
    max_ks = 0.0
    n_imbalanced = 0

    for covar, cov_key in covars:
        values = data[covar].to_numpy(dtype=float)
        ref_values = values[ref_mask]
        ref_weights = weights[ref_mask]
        mean_ref = float(np.mean(ref_values))
        var_ref = sample_var(ref_values)
        mean_ref_adj = weighted_mean(ref_values, ref_weights)
        cov_imbalanced = False

        for level in levels:
            if level == reference:
                continue
            mask = treat == level
            lev_values = values[mask]
            lev_weights = weights[mask]
            mean_lev = float(np.mean(lev_values))
            var_lev = sample_var(lev_values)
            pooled_sd = math.sqrt((var_lev + var_ref) / 2.0)
            smd_raw = (mean_lev - mean_ref) / pooled_sd if pooled_sd > 0 else 0.0
            mean_lev_adj = weighted_mean(lev_values, lev_weights)
            smd_adj = (mean_lev_adj - mean_ref_adj) / pooled_sd if pooled_sd > 0 else 0.0
            vr_raw = var_lev / var_ref if var_lev > 0 and var_ref > 0 else math.nan
            ks_raw = ks_2sample(lev_values, ref_values)

            add_metric(rows, f"{prefix}_b_{cov_key}_smd{level}0", smd_raw)
            add_metric(rows, f"{prefix}_b_{cov_key}_vr{level}0", vr_raw)
            add_metric(rows, f"{prefix}_b_{cov_key}_ks{level}0", ks_raw)
            add_metric(rows, f"{prefix}_b_{cov_key}_smda{level}0", smd_adj)

            max_smd_raw = max(max_smd_raw, abs(smd_raw))
            max_smd_adj = max(max_smd_adj, abs(smd_adj))
            max_ks = max(max_ks, ks_raw)
            if abs(smd_adj) > threshold:
                cov_imbalanced = True

        if cov_imbalanced:
            n_imbalanced += 1

    add_metric(rows, f"{prefix}_b_maxsmd", max_smd_raw)
    add_metric(rows, f"{prefix}_b_maxsmda", max_smd_adj)
    add_metric(rows, f"{prefix}_b_maxks", max_ks)
    add_metric(rows, f"{prefix}_b_nimb", n_imbalanced)


def build_spector(outdir: Path, rows: list[tuple[str, float]]) -> None:
    data = sm.datasets.spector.load_pandas().data.copy()
    data = data.rename(columns={"GPA": "gpa", "TUCE": "tuce", "PSI": "psi", "GRADE": "grade"})
    x = sm.add_constant(data[["gpa", "tuce", "psi"]], has_constant="add")
    y = data["grade"]
    data["ps_logit"] = sm.Logit(y, x).fit(disp=0, maxiter=200).predict(x)
    data["ps_probit"] = sm.Probit(y, x).fit(disp=0, maxiter=200).predict(x)
    data["grade"] = data["grade"].astype(int)
    data.to_csv(outdir / "_external_reference_spector.csv", index=False, float_format="%.17g")

    covars = [("gpa", "gpa"), ("tuce", "tuce"), ("psi", "psi")]
    binary_reference(rows, "spl", data, "grade", "ps_logit", covars)
    binary_reference(rows, "spp", data, "grade", "ps_probit", covars)


def build_fair(outdir: Path, rows: list[tuple[str, float]]) -> None:
    data = sm.datasets.fair.load_pandas().data.copy()
    data["had_affair"] = (data["affairs"] > 0).astype(int)
    covar_names = [
        "age",
        "yrs_married",
        "children",
        "religious",
        "educ",
        "occupation",
        "occupation_husb",
    ]
    x = sm.add_constant(data[covar_names], has_constant="add")
    y = data["had_affair"]
    data["ps_ref"] = sm.Logit(y, x).fit(disp=0, maxiter=200).predict(x)
    keep = ["rate_marriage", "had_affair", *covar_names, "ps_ref"]
    data[keep].to_csv(outdir / "_external_reference_fair.csv", index=False, float_format="%.17g")

    covars = [
        ("age", "age"),
        ("yrs_married", "yrsm"),
        ("children", "child"),
        ("religious", "relig"),
        ("educ", "educ"),
        ("occupation", "occ"),
        ("occupation_husb", "occh"),
    ]
    binary_reference(rows, "fr", data, "had_affair", "ps_ref", covars)


def build_iris(outdir: Path, rows: list[tuple[str, float]]) -> None:
    iris = load_iris(as_frame=True)
    data = iris.frame.rename(
        columns={
            "sepal length (cm)": "sepal_length",
            "sepal width (cm)": "sepal_width",
            "petal length (cm)": "petal_length",
            "petal width (cm)": "petal_width",
            "target": "species",
        }
    )
    covar_names = ["sepal_length", "sepal_width", "petal_length", "petal_width"]
    model = LogisticRegression(solver="lbfgs", max_iter=1000, C=1.0)
    probs = model.fit(data[covar_names], data["species"]).predict_proba(data[covar_names])
    for index, cls in enumerate(model.classes_):
        data[f"gps{int(cls)}"] = probs[:, index]
    data["species"] = data["species"].astype(int)
    data.to_csv(outdir / "_external_reference_iris.csv", index=False, float_format="%.17g")

    covars = [
        ("sepal_length", "sl"),
        ("sepal_width", "sw"),
        ("petal_length", "pl"),
        ("petal_width", "pw"),
    ]
    multigroup_reference(rows, "ir", data, "species", {0: "gps0", 1: "gps1", 2: "gps2"}, covars)


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: _external_reference_psdash.py OUTDIR", file=sys.stderr)
        return 2

    outdir = Path(sys.argv[1]).resolve()
    outdir.mkdir(parents=True, exist_ok=True)
    rows: list[tuple[str, float]] = []

    build_spector(outdir, rows)
    build_fair(outdir, rows)
    build_iris(outdir, rows)

    with (outdir / "_external_reference_metrics.csv").open("w", newline="", encoding="utf-8") as handle:
        writer = csv.writer(handle)
        writer.writerow(["key", "value"])
        for key, value in rows:
            writer.writerow([key, f"{value:.17g}"])

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
