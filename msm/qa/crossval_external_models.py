#!/usr/bin/env python3
"""Python references for external msm model validation."""

import os
import sys
from math import sqrt

import pandas as pd
import statsmodels.api as sm


def main() -> int:
    if len(sys.argv) != 2:
        raise SystemExit("usage: crossval_external_models.py RESULTS_DIR")

    results_dir = sys.argv[1]

    lpm = pd.read_csv(os.path.join(results_dir, "external_lpm_modeldata.csv"))
    lpm_x = sm.add_constant(lpm[["treatment", "iq"]])
    lpm_robust = sm.WLS(lpm["outcome"], lpm_x, weights=lpm["weight"]).fit(cov_type="HC1")
    lpm_cluster = sm.WLS(lpm["outcome"], lpm_x, weights=lpm["weight"]).fit(
        cov_type="cluster",
        cov_kwds={"groups": lpm["iqgrp"], "use_correction": True},
    )
    lpm_b = float(lpm_robust.params["treatment"])

    logit = sm.GLM(
        lpm["outcome"],
        lpm_x,
        family=sm.families.Binomial(),
        var_weights=lpm["weight"],
    )
    logit_robust = logit.fit(cov_type="HC1")
    logit_cluster = logit.fit(
        cov_type="cluster",
        cov_kwds={"groups": lpm["iqgrp"], "use_correction": False},
    )
    logit_b = float(logit_robust.params["treatment"])
    logit_n = len(lpm)
    logit_g = lpm["iqgrp"].nunique()
    logit_robust_se = float(logit_robust.bse["treatment"]) * sqrt(logit_n / (logit_n - 1))
    logit_cluster_se = float(logit_cluster.bse["treatment"]) * sqrt(logit_g / (logit_g - 1))

    out = pd.DataFrame(
        {
            "model": ["lpm_robust", "lpm_cluster", "logit_robust", "logit_cluster"],
            "source": [
                "Python_statsmodels_WLS_HC1",
                "Python_statsmodels_WLS_cluster",
                "Python_statsmodels_GLM_HC0_stata_adj",
                "Python_statsmodels_GLM_cluster_stata_adj",
            ],
            "coef": [lpm_b, lpm_b, logit_b, logit_b],
            "se": [
                float(lpm_robust.bse["treatment"]),
                float(lpm_cluster.bse["treatment"]),
                logit_robust_se,
                logit_cluster_se,
            ],
            "or_hr": [float("nan"), float("nan"), float("nan"), float("nan")],
        }
    )
    out.to_csv(os.path.join(results_dir, "external_py_results.csv"), index=False)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
