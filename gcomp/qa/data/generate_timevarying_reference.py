#!/usr/bin/env python3
"""Generate the simple three-visit time-varying Monte Carlo oracle."""

from __future__ import annotations

from pathlib import Path

import numpy as np
import pandas as pd


OUT_DIR = Path(__file__).resolve().parent
SEED = 20260421
MC_SUBJECTS = 3_000_000


def invlogit(value: np.ndarray) -> np.ndarray:
    return 1.0 / (1.0 + np.exp(-value))


def main() -> None:
    rng = np.random.default_rng(SEED)
    l0 = rng.normal(size=MC_SUBJECTS)
    l1 = 0.15 + 0.65 * l0 + rng.normal(0.0, 0.35, MC_SUBJECTS)

    potential: dict[int, float] = {}
    for regime in (1, 0):
        l2 = (
            0.10
            + 0.60 * l1
            - 0.55 * regime
            + 0.15 * l0
            + rng.normal(0.0, 0.35, MC_SUBJECTS)
        )
        potential[regime] = float(
            invlogit(-1.35 - 0.90 * regime + 0.75 * l2 + 0.20 * l0).mean()
        )

    a1 = rng.binomial(1, invlogit(-0.35 + 0.70 * l1 + 0.20 * l0))
    l2 = (
        0.10
        + 0.60 * l1
        - 0.55 * a1
        + 0.15 * l0
        + rng.normal(0.0, 0.35, MC_SUBJECTS)
    )
    a2 = rng.binomial(1, invlogit(-0.25 + 0.60 * l2 + 0.20 * l0))
    natural = float(invlogit(-1.35 - 0.90 * a2 + 0.75 * l2 + 0.20 * l0).mean())

    note = f"seed={SEED}; MC subjects={MC_SUBJECTS}; NumPy={np.__version__}"
    rows = [
        {
            "metric": "po_all1",
            "value": potential[1],
            "source": "python_numpy_forward_mc",
            "notes": f"Always-treat mean; {note}",
        },
        {
            "metric": "po_all0",
            "value": potential[0],
            "source": "python_numpy_forward_mc",
            "notes": f"Never-treat mean; {note}",
        },
        {
            "metric": "po_natural",
            "value": natural,
            "source": "python_numpy_forward_mc",
            "notes": f"Natural-regime mean; {note}",
        },
        {
            "metric": "risk_difference",
            "value": potential[1] - potential[0],
            "source": "python_numpy_forward_mc",
            "notes": f"Always-treat minus never-treat; {note}",
        },
    ]
    pd.DataFrame(rows).to_csv(
        OUT_DIR / "timevarying_python_benchmark.csv",
        index=False,
        float_format="%.17g",
    )


if __name__ == "__main__":
    main()
