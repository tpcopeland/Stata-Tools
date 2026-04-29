#!/usr/bin/env python3
"""Python reference calculations for psdash cross-validation QA."""

from __future__ import annotations

import csv
import math
import sys
from statistics import mean


TREAT = [1, 1, 1, 1, 0, 0, 0, 0]
PS = [0.20, 0.35, 0.55, 0.85, 0.10, 0.30, 0.60, 0.75]
X1 = [2.0, 4.0, 7.0, 9.0, 1.0, 5.0, 6.0, 8.0]
X2 = [0.0, 0.0, 1.0, 1.0, 0.0, 1.0, 1.0, 1.0]
WT = [1.0, 2.0, 1.0, 3.0, 2.0, 1.0, 2.0, 1.0]


def sample_variance(values: list[float]) -> float:
    m = mean(values)
    return sum((x - m) ** 2 for x in values) / (len(values) - 1)


def weighted_mean(values: list[float], weights: list[float]) -> float:
    return sum(x * w for x, w in zip(values, weights)) / sum(weights)


def ks_2sample(t_values: list[float], c_values: list[float]) -> float:
    points = sorted(set(t_values + c_values))
    n_t = len(t_values)
    n_c = len(c_values)
    max_diff = 0.0
    for point in points:
        ft = sum(x <= point for x in t_values) / n_t
        fc = sum(x <= point for x in c_values) / n_c
        max_diff = max(max_diff, abs(ft - fc))
    return max_diff


def balance_metrics(values: list[float], weights: list[float]) -> dict[str, float]:
    t_values = [x for x, treat in zip(values, TREAT) if treat == 1]
    c_values = [x for x, treat in zip(values, TREAT) if treat == 0]
    t_weights = [w for w, treat in zip(weights, TREAT) if treat == 1]
    c_weights = [w for w, treat in zip(weights, TREAT) if treat == 0]

    mean_t = mean(t_values)
    mean_c = mean(c_values)
    var_t = sample_variance(t_values)
    var_c = sample_variance(c_values)
    pooled_sd = math.sqrt((var_t + var_c) / 2.0)
    smd_raw = (mean_t - mean_c) / pooled_sd

    mean_t_adj = weighted_mean(t_values, t_weights)
    mean_c_adj = weighted_mean(c_values, c_weights)
    smd_adj = (mean_t_adj - mean_c_adj) / pooled_sd

    return {
        "mean_t": mean_t,
        "mean_c": mean_c,
        "smd_raw": smd_raw,
        "vr_raw": var_t / var_c,
        "ks_raw": ks_2sample(t_values, c_values),
        "mean_t_adj": mean_t_adj,
        "mean_c_adj": mean_c_adj,
        "smd_adj": smd_adj,
    }


def sd(values: list[float]) -> float:
    return math.sqrt(sample_variance(values))


def ess(weights: list[float]) -> float:
    return sum(weights) ** 2 / sum(w * w for w in weights)


def auto_weights(estimand: str) -> list[float]:
    weights = []
    for treat, ps in zip(TREAT, PS):
        if estimand == "ate":
            weights.append(1.0 / ps if treat == 1 else 1.0 / (1.0 - ps))
        elif estimand == "att":
            weights.append(1.0 if treat == 1 else ps / (1.0 - ps))
        elif estimand == "atc":
            weights.append((1.0 - ps) / ps if treat == 1 else 1.0)
        else:
            raise ValueError(f"unknown estimand: {estimand}")
    return weights


def auc_pairwise() -> float:
    t_ps = [p for p, treat in zip(PS, TREAT) if treat == 1]
    c_ps = [p for p, treat in zip(PS, TREAT) if treat == 0]
    score = 0.0
    for tp in t_ps:
        for cp in c_ps:
            if tp > cp:
                score += 1.0
            elif tp == cp:
                score += 0.5
    return score / (len(t_ps) * len(c_ps))


def main() -> int:
    if len(sys.argv) != 2:
        raise SystemExit("usage: _psdash_python_reference.py output.csv")

    rows: list[tuple[str, float]] = []

    x1 = balance_metrics(X1, WT)
    x2 = balance_metrics(X2, WT)
    for prefix, metrics in (("x1", x1), ("x2", x2)):
        for name, value in metrics.items():
            rows.append((f"{prefix}_{name}", value))

    max_smd_raw = max(abs(x1["smd_raw"]), abs(x2["smd_raw"]))
    max_smd_adj = max(abs(x1["smd_adj"]), abs(x2["smd_adj"]))
    max_ks_raw = max(x1["ks_raw"], x2["ks_raw"])
    rows.extend(
        [
            ("balance_max_smd_raw", max_smd_raw),
            ("balance_max_smd_adj", max_smd_adj),
            ("balance_max_ks_raw", max_ks_raw),
            ("balance_n_imbalanced", sum(abs(x["smd_adj"]) > 0.1 for x in (x1, x2))),
        ]
    )

    t_ps = [p for p, treat in zip(PS, TREAT) if treat == 1]
    c_ps = [p for p, treat in zip(PS, TREAT) if treat == 0]
    lower = max(min(t_ps), min(c_ps))
    upper = min(max(t_ps), max(c_ps))
    outside = [(p < lower) or (p > upper) for p in PS]
    rows.extend(
        [
            ("overlap_lower", lower),
            ("overlap_upper", upper),
            ("overlap_n_outside", sum(outside)),
            ("overlap_pct_outside", 100.0 * sum(outside) / len(PS)),
            ("overlap_auc", auc_pairwise()),
        ]
    )

    threshold = 0.25
    trimmed = [(p < threshold) or (p > 1.0 - threshold) for p in PS]
    rows.extend(
        [
            ("support_lower", lower),
            ("support_upper", upper),
            ("support_n_outside", sum(outside)),
            ("support_n_outside_treated", sum(o and t == 1 for o, t in zip(outside, TREAT))),
            ("support_n_outside_control", sum(o and t == 0 for o, t in zip(outside, TREAT))),
            ("support_pct_outside", 100.0 * sum(outside) / len(PS)),
            ("support_trim_lower", threshold),
            ("support_trim_upper", 1.0 - threshold),
            ("support_n_trimmed", sum(trimmed)),
            ("support_pct_trimmed", 100.0 * sum(trimmed) / len(PS)),
        ]
    )

    t_wt = [w for w, treat in zip(WT, TREAT) if treat == 1]
    c_wt = [w for w, treat in zip(WT, TREAT) if treat == 0]
    rows.extend(
        [
            ("weights_mean", mean(WT)),
            ("weights_sd", sd(WT)),
            ("weights_min", min(WT)),
            ("weights_max", max(WT)),
            ("weights_cv", sd(WT) / mean(WT)),
            ("weights_ess", ess(WT)),
            ("weights_ess_pct", 100.0 * ess(WT) / len(WT)),
            ("weights_ess_treated", ess(t_wt)),
            ("weights_ess_control", ess(c_wt)),
            ("weights_extreme", sum(w > 10 for w in WT)),
        ]
    )

    for estimand in ("ate", "att", "atc"):
        weights = auto_weights(estimand)
        t_weights = [w for w, treat in zip(weights, TREAT) if treat == 1]
        c_weights = [w for w, treat in zip(weights, TREAT) if treat == 0]
        for index, weight in enumerate(weights, start=1):
            rows.append((f"auto_{estimand}_w_{index}", weight))
        rows.extend(
            [
                (f"auto_{estimand}_mean", mean(weights)),
                (f"auto_{estimand}_ess", ess(weights)),
                (f"auto_{estimand}_ess_treated", ess(t_weights)),
                (f"auto_{estimand}_ess_control", ess(c_weights)),
            ]
        )

    with open(sys.argv[1], "w", newline="", encoding="utf-8") as handle:
        writer = csv.writer(handle)
        writer.writerow(["metric", "value"])
        for metric, value in rows:
            writer.writerow([metric, f"{float(value):.17g}"])

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
