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
IPTW Weight Calculation
------------------------------------------------------------------------------
  exposure variable            : treat
  number of levels             :              2
  model type                   : logit
  weight type                  : iptw
  covariates                   : age female biomarker
  observations                 :          2,296
  panel structure              :            400  clusters
  obs per cluster              :            5.7  (range 1-6)
  time fixed effects           : i.period
------------------------------------------------------------------------------
Fitting propensity score model...
Calculating weights...
Calculating stabilized weights...
  Numerator model: treat on i.period
Fitting censoring model and computing IPCW...
  Censoring numerator model: censored on i.period
  Censoring weight ipcw and combined weight iptw_ipcw created.
Weight Diagnostics
------------------------------------------------------------------------------
Weight distribution
  mean                         :         1.0073
  SD                           :         0.4098
  min                          :         0.2361
  max                          :         3.7771
Percentiles
  1%                           :         0.3533
  5%                           :         0.5036
  25%                          :         0.7383
  50%                          :         0.9256
  75%                          :         1.1870
  95%                          :         1.7688
  99%                          :         2.4674
Effective sample size
  ESS                          :         1970.1  (of 2296 observations)
  ESS as % of N                :           85.8  %
Combined IPTW x IPCW weight:
  Mean:        1.0073
  Min/Max:     0.2361 /    3.7771
  99th pct:    2.4674
  ESS:         1970.1 (85.8% of 2296)
Positivity / overlap
  P(observed treatment) range  : 0.1331 to 0.8893
  near-violations (P<0.05)     :              0  (0.0% of obs)
  PS range, treated            : 0.1331 to 0.7042
  PS range, reference          : 0.1107 to 0.7195
  weight mass, top 1% of rows  :            2.8  %  (23 row(s))
Weights by exposure group
  reference (treat=0)          : N=1434  mean=1.000  SD=0.171
  exposed (treat!=0)           : N=862  mean=1.001  SD=0.294
------------------------------------------------------------------------------
Covariate balance (standardized mean differences)
------------------------------------------------------------------------------
  Weighted column uses the analysis weight: iptw_ipcw
  Covariate                                    SMD (unwtd)         SMD (wtd)
  age                                               0.2434            0.0254
  female                                           -0.0569           -0.0120
  biomarker                                         0.3557           -0.0026
------------------------------------------------------------------------------
------------------------------------------------------------------------------
  Analysis weight iptw_ipcw created (per-period weight iptw).
------------------------------------------------------------------------------
```

```stata
noisily display "combined-weight ESS: " as result %6.1f r(ess_combined)
```

```
>     "   positivity near-violations: " as result %4.1f r(pct_nonoverlap) "%"
combined-weight ESS: 1970.1   positivity near-violations:  0.0%
```
