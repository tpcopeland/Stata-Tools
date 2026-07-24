#!/usr/bin/env python3
"""Independent audit of sharded FIPTIW interval-coverage results."""

from __future__ import annotations

import argparse
import json
import math
import re
from pathlib import Path

import pandas as pd


BLOCK_RE = re.compile(r"^fiptiw_(\d{5})_(\d{5})\.dta$")


def wilson(
    successes: int,
    total: int,
    z: float = 1.959963984540054,
) -> tuple[float, float]:
    """Return the Wilson score interval for a binomial proportion."""
    p = successes / total
    den = 1 + z * z / total
    center = (p + z * z / (2 * total)) / den
    half = (
        z
        * math.sqrt(
            p * (1 - p) / total + z * z / (4 * total * total)
        )
        / den
    )
    return center - half, center + half


def one_value(frame: pd.DataFrame, name: str, expected: float) -> None:
    """Require one exact configuration stamp across every raw row."""
    values = frame[name].drop_duplicates().tolist()
    if len(values) != 1 or not math.isclose(
        float(values[0]), expected, rel_tol=0, abs_tol=1e-12
    ):
        raise SystemExit(
            f"{name}: expected exactly {expected}, found {values}"
        )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("pool", type=Path)
    parser.add_argument("--sims", type=int, default=1000)
    parser.add_argument("--reps", type=int, default=999)
    parser.add_argument("--seed", type=int, default=20260715)
    parser.add_argument("--pscale", type=float, required=True)
    parser.add_argument("--truth", type=float, default=1.0)
    parser.add_argument("--block", type=int, default=25)
    args = parser.parse_args()

    files = sorted(args.pool.glob("fiptiw_*.dta"))
    expected_ranges = [
        (start, min(start + args.block - 1, args.sims))
        for start in range(1, args.sims + 1, args.block)
    ]
    observed_ranges: list[tuple[int, int]] = []
    frames: list[pd.DataFrame] = []
    for path in files:
        match = BLOCK_RE.match(path.name)
        if not match:
            raise SystemExit(f"unexpected block filename: {path.name}")
        observed_ranges.append(
            (int(match.group(1)), int(match.group(2)))
        )
        frames.append(pd.read_stata(path, convert_categoricals=False))
    if observed_ranges != expected_ranges:
        raise SystemExit(
            f"block ranges do not tile 1..{args.sims}:\n"
            f"expected={expected_ranges}\nobserved={observed_ranges}"
        )

    frame = pd.concat(frames, ignore_index=True)
    required = {
        "sim", "arm", "blk_reps", "blk_sims", "blk_nsub",
        "blk_seed", "blk_pscale", "b_refit", "se_refit",
        "cov_refit", "ci_wald_lo", "ci_wald_hi",
        "cov_pct", "ci_pct_lo", "ci_pct_hi",
        "cov_basic", "ci_basic_lo", "ci_basic_hi",
        "cov_bc", "ci_bc_lo", "ci_bc_hi",
        "cov_bca", "ci_bca_lo", "ci_bca_hi",
        "z0_refit", "accel_refit",
    }
    missing_columns = sorted(required.difference(frame.columns))
    if missing_columns:
        raise SystemExit(
            f"raw rows are from an incompatible schema; missing {missing_columns}"
        )
    if len(frame) != args.sims:
        raise SystemExit(f"expected {args.sims} rows, found {len(frame)}")
    if frame["sim"].isna().any() or frame["sim"].duplicated().any():
        raise SystemExit("sim keys contain missing values or duplicates")
    observed_sims = sorted(frame["sim"].astype(int).tolist())
    if observed_sims != list(range(1, args.sims + 1)):
        raise SystemExit("sim keys do not tile 1..SIMS exactly")

    one_value(frame, "arm", 3)
    one_value(frame, "blk_reps", args.reps)
    one_value(frame, "blk_sims", args.sims)
    one_value(frame, "blk_nsub", 0)
    one_value(frame, "blk_seed", args.seed)
    one_value(frame, "blk_pscale", args.pscale)
    if frame.isna().any().any():
        missing = frame.columns[frame.isna().any()].tolist()
        raise SystemExit(f"raw rows contain missing values: {missing}")

    b = frame["b_refit"]
    bias = float(b.mean() - args.truth)
    empirical_sd = float(b.std(ddof=1))
    result: dict[str, object] = {
        "integrity": {
            "files": len(files),
            "rows": len(frame),
            "sim_min": int(frame["sim"].min()),
            "sim_max": int(frame["sim"].max()),
            "reps": args.reps,
            "seed": args.seed,
            "pscale": args.pscale,
            "nsub_stamp": 0,
        },
        "point_estimator": {
            "mean": float(b.mean()),
            "bias": bias,
            "bias_mcse": empirical_sd / math.sqrt(len(frame)),
            "empirical_sd": empirical_sd,
            "mean_bootstrap_se": float(frame["se_refit"].mean()),
            "se_to_sd_ratio": float(
                frame["se_refit"].mean() / empirical_sd
            ),
            "standardized_mean": float(
                ((b - args.truth) / frame["se_refit"]).mean()
            ),
            "standardized_sd": float(
                ((b - args.truth) / frame["se_refit"]).std(ddof=1)
            ),
        },
        "intervals": {},
        "z0": {
            "mean": float(frame["z0_refit"].mean()),
            "median": float(frame["z0_refit"].median()),
            "p95": float(frame["z0_refit"].quantile(0.95)),
            "mean_abs": float(frame["z0_refit"].abs().mean()),
        },
        "acceleration": {
            "mean": float(frame["accel_refit"].mean()),
            "median": float(frame["accel_refit"].median()),
            "p95": float(frame["accel_refit"].quantile(0.95)),
            "mean_abs": float(frame["accel_refit"].abs().mean()),
        },
    }

    specs = {
        "wald": ("cov_refit", "ci_wald_lo", "ci_wald_hi"),
        "percentile": ("cov_pct", "ci_pct_lo", "ci_pct_hi"),
        "basic": ("cov_basic", "ci_basic_lo", "ci_basic_hi"),
        "bias_corrected": ("cov_bc", "ci_bc_lo", "ci_bc_hi"),
        "bca": ("cov_bca", "ci_bca_lo", "ci_bca_hi"),
    }
    for label, (cov_name, lo_name, hi_name) in specs.items():
        if (frame[hi_name] < frame[lo_name]).any():
            raise SystemExit(
                f"{label}: at least one upper endpoint is below its lower endpoint"
            )
        recomputed = (
            (args.truth >= frame[lo_name])
            & (args.truth <= frame[hi_name])
        ).astype(int)
        cov = frame[cov_name].astype(int)
        if not recomputed.equals(cov):
            bad = frame.loc[
                recomputed.ne(cov),
                ["sim", cov_name, lo_name, hi_name],
            ]
            raise SystemExit(
                f"{label}: stored coverage disagrees with endpoints:\n"
                f"{bad.head(10).to_string(index=False)}"
            )
        successes = int(cov.sum())
        lo, hi = wilson(successes, len(frame))
        lower_miss = int((args.truth < frame[lo_name]).sum())
        upper_miss = int((args.truth > frame[hi_name]).sum())
        coverage = successes / len(frame)
        result["intervals"][label] = {
            "covered": successes,
            "coverage": coverage,
            "wilson95": [lo, hi],
            "mean_length": float(
                (frame[hi_name] - frame[lo_name]).mean()
            ),
            "truth_below_interval": lower_miss,
            "truth_above_interval": upper_miss,
            "gate_pass": (
                coverage >= 0.92 and lo <= 0.95 <= hi
            ),
        }

    pct_len = frame["ci_pct_hi"] - frame["ci_pct_lo"]
    basic_len = frame["ci_basic_hi"] - frame["ci_basic_lo"]
    max_len_diff = float((pct_len - basic_len).abs().max())
    result["percentile_basic_max_abs_length_difference"] = max_len_diff
    if max_len_diff > 1e-10:
        raise SystemExit(
            "percentile and basic lengths are not algebraically identical"
        )

    print(json.dumps(result, indent=2, sort_keys=False))


if __name__ == "__main__":
    main()
