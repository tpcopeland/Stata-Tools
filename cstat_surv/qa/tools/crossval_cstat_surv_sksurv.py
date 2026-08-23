#!/usr/bin/env python3
"""Compute ordinary Harrell's C from a Stata exchange dataset."""

import argparse

import pandas as pd
from sksurv.metrics import concordance_index_censored


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("input_dta")
    parser.add_argument("output_dta")
    args = parser.parse_args()

    data = pd.read_stata(args.input_dta)
    required = {"event", "time", "risk"}
    missing = required.difference(data.columns)
    if missing:
        raise ValueError(f"exchange data missing: {sorted(missing)}")
    if data.loc[:, ["event", "time", "risk"]].isna().any().any():
        raise ValueError("exchange data contain missing event, time, or risk")

    c_index, concordant, discordant, tied_risk, _ = concordance_index_censored(
        data["event"].astype(bool).to_numpy(),
        data["time"].to_numpy(),
        data["risk"].to_numpy(),
        tied_tol=0.0,
    )
    result = pd.DataFrame(
        {
            "py_c": [float(c_index)],
            "py_comparable": [int(concordant + discordant + tied_risk)],
            "py_concordant": [int(concordant)],
            "py_discordant": [int(discordant)],
            "py_tied": [int(tied_risk)],
        }
    )
    result.to_stata(args.output_dta, write_index=False, version=118)


if __name__ == "__main__":
    main()
