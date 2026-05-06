#!/usr/bin/env python3
"""Python references for external msm model validation."""

import os
import sys

import pandas as pd
import statsmodels.api as sm


def main() -> int:
    if len(sys.argv) != 2:
        raise SystemExit("usage: crossval_external_models.py RESULTS_DIR")

    results_dir = sys.argv[1]

    lpm = pd.read_csv(os.path.join(results_dir, "external_lpm_modeldata.csv"))
    lpm_x = sm.add_constant(lpm[["treatment", "iq"]])
    lpm_fit = sm.WLS(lpm["outcome"], lpm_x, weights=lpm["weight"]).fit()
    lpm_b = float(lpm_fit.params["treatment"])
    lpm_se = float(lpm_fit.bse["treatment"])

    out = pd.DataFrame(
        {
            "model": ["lpm"],
            "source": ["Python_statsmodels_WLS"],
            "coef": [lpm_b],
            "se": [lpm_se],
            "or_hr": [float("nan")],
        }
    )
    out.to_csv(os.path.join(results_dir, "external_py_results.csv"), index=False)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
