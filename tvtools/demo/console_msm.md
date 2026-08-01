---
title: "tvtools: MSM Weighting with IPCW"
---

## MSM Weighting: IPTW x IPCW + Positivity

### Combined treatment + censoring weights

<!-- * tvweight fits a propensity model and (with ipcw()) a censoring model, then -->

<!-- * forms the cumulative IPTW x IPCW weight that a marginal structural model needs. -->

<!-- * A positivity / overlap block reports near-violations and weight concentration. -->

```stata
use "`panel'", clear
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
  Numerator model: treat on i.period

Fitting censoring model and computing IPCW...
  Censoring numerator model: censored on i.period
  Censoring weight ipcw and combined weight iptw_ipcw created.

----------------------------------------------------------------------
Weight Diagnostics
----------------------------------------------------------------------

Weight distribution:
  Mean:        1.0006
  SD:          0.2254
  Min:         0.5231
  Max:         2.7574

Percentiles:
  1%:          0.6218
  5%:          0.7172
  25%:         0.8585
  50%:         0.9560
  75%:         1.0915
  95%:         1.4296
  99%:         1.7545

Effective sample size:
  ESS:         2185.2 (of 2296 observations)
  ESS %:         95.2%

Combined IPTW x IPCW weight:
  Mean:        1.0073
  Min/Max:     0.2361 /    3.7771
  99th pct:    2.4674
  ESS:         1970.1 (85.8% of 2296)

Positivity / overlap:
  P(observed treatment) range: 0.1331 to 0.8893
  Near-violations (P<0.05):    0 ( 0.0% of obs)
  PS range, treated:           0.1331 to 0.7042
  PS range, reference:         0.1107 to 0.7195
  Weight mass in top 1% of rows (23 row(s)):   2.8%

Weights by exposure group:
--------------------------------------------------
  Reference (treat=0): N=1434, Mean=  1.000, SD=  0.171
  Exposed (treat!=0):  N=862, Mean=  1.001, SD=  0.294
----------------------------------------------------------------------

----------------------------------------------------------------------
Covariate balance (standardized mean differences)
Weighted column uses the analysis weight: iptw_ipcw
----------------------------------------------------------------------
Covariate                        SMD (unwtd)     SMD (wtd)
age                                   0.2434        0.0254
female                               -0.0569       -0.0120
biomarker                             0.3557       -0.0026
----------------------------------------------------------------------

Weight variable iptw created successfully.
----------------------------------------------------------------------
```

```stata
noisily display "combined-weight ESS: " as result %6.1f r(ess_combined)
```

```
>     "   positivity near-violations: " as result %4.1f r(pct_nonoverlap) "%"
combined-weight ESS: 1970.1   positivity near-violations:  0.0%
```
