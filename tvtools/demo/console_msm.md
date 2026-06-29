---
title: "console_msm"
---

## MSM Weighting: IPTW x IPCW + Positivity

### Combined treatment + censoring weights

<!-- * tvweight fits a propensity model and (with ipcw()) a censoring model, then -->

<!-- * forms the cumulative IPTW x IPCW weight that a marginal structural model needs. -->

<!-- * A positivity / overlap block reports near-violations and weight concentration. -->

```stata
use "`pkg_dir'/_panel.dta", clear
```

```stata
noisily tvweight treat, covariates(age female biomarker)
id(id) time(period) ipcw(censored) censorcovariates(age biomarker)
stabilized generate(iptw) balance nolog
```

```
----------------------------------------------------------------------
IPTW Weight Calculation
----------------------------------------------------------------------

Exposure variable: treat
Number of levels:  2
Model type:        logit
Weight type:       iptw
Covariates:        age female biomarker
Observations:      2296
Panel structure:   400 clusters
Obs per cluster:    5.7 (range: 1-6)
Time FE:           i.period

Fitting propensity score model...

Calculating weights...
Calculating stabilized weights...

Fitting censoring model and computing IPCW...
  Censoring weight ipcw and combined weight iptw_ipcw created.

----------------------------------------------------------------------
Weight Diagnostics
----------------------------------------------------------------------

Weight distribution:
  Mean:        1.0005
  SD:          0.2349
  Min:         0.5331
  Max:         2.8214

Percentiles:
  1%:          0.6121
  5%:          0.7148
  25%:         0.8512
  50%:         0.9494
  75%:         1.0955
  95%:         1.4476
  99%:         1.7644

Effective sample size:
  ESS:         2176.1 (of 2296 observations)
  ESS %:         94.8%

Combined IPTW x IPCW weight:
  Mean:        1.0291
  Min/Max:     0.2124 /    3.9174
  99th pct:    2.7079
  ESS:         1948.2 (84.9% of 2296)

Positivity / overlap:
  P(observed treatment) range: 0.1331 to 0.8893
  Near-violations (P<0.05):    0 ( 0.0% of obs)
  PS range, treated:           0.1331 to 0.7042
  PS range, reference:         0.1107 to 0.7195
  Weight mass in top 1% of rows:   2.9%

Weights by exposure group:
--------------------------------------------------
  Reference (treat=0): N=1434, Mean=  1.000, SD=  0.180
  Exposed (treat!=0):  N=862, Mean=  1.001, SD=  0.305
----------------------------------------------------------------------

----------------------------------------------------------------------
Covariate balance (standardized mean differences)
----------------------------------------------------------------------
Covariate                        SMD (unwtd)     SMD (wtd)
age                                   0.2434        0.0000
female                               -0.0569        0.0059
biomarker                             0.3557       -0.0102
----------------------------------------------------------------------

Weight variable iptw created successfully.
----------------------------------------------------------------------

```

```stata
noisily display "combined-weight ESS: " as result %6.1f r(ess_combined)
```

```
>     "   positivity near-violations: " as result %4.1f r(pct_nonoverlap) "%"
combined-weight ESS: 1948.2   positivity near-violations:  0.0%

```
