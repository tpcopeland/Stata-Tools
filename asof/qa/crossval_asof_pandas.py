#!/usr/bin/env python3
"""Generate independent pandas.merge_asof parity fixtures for asof QA."""

from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
import pandas as pd


def main(output_dir: str) -> None:
    out = Path(output_dir)
    out.mkdir(parents=True, exist_ok=True)

    n_people = 5_000
    visits_per_person = 20
    ids = np.repeat(np.arange(1, n_people + 1, dtype=np.int32), visits_per_person)
    offsets = np.tile(np.arange(-95, 105, 10, dtype=np.int32), n_people)
    visits = ids.astype(np.int64) * 1_000 + offsets
    events = pd.DataFrame(
        {
            "id": ids,
            "visit": visits,
            "event_row": np.arange(1, ids.size + 1, dtype=np.int32),
        }
    )

    rng = np.random.default_rng(20260812)
    master = pd.DataFrame(
        {
            "id": np.arange(1, n_people + 1, dtype=np.int32),
            "anchor": np.arange(1, n_people + 1, dtype=np.int64) * 1_000
            + rng.integers(-30, 31, size=n_people, dtype=np.int64),
        }
    )

    left = master.sort_values("anchor", kind="mergesort")
    right = events.sort_values("visit", kind="mergesort")
    for direction in ("backward", "forward"):
        oracle = pd.merge_asof(
            left,
            right,
            left_on="anchor",
            right_on="visit",
            by="id",
            direction=direction,
            tolerance=35,
            allow_exact_matches=True,
        )
        oracle = oracle.sort_values("id", kind="mergesort").rename(
            columns={"event_row": "expected_row", "visit": "expected_date"}
        )
        oracle[["id", "expected_row", "expected_date"]].to_stata(
            out / f"oracle_{direction}.dta", write_index=False, version=118
        )

    master.to_stata(out / "master.dta", write_index=False, version=118)
    events.to_stata(out / "events.dta", write_index=False, version=118)
    print(f"pandas={pd.__version__} people={n_people} events={len(events)}")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit("usage: crossval_asof_pandas.py OUTPUT_DIR")
    main(sys.argv[1])
