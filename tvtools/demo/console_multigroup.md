---
title: "tvtools: Multi-Group Weighting and Age Bands"
---

## Multi-Group Weighting and Age Bands

### tvweight with multinomial logit (3 treatment categories)

```stata
use "`cohort'", clear
```

```stata
quietly tvexpose using "`episodes_antidep'",
id(id) start(rx_start) stop(rx_stop)
exposure(drug) reference(0)
entry(study_entry) exit(study_exit)
keepvars(age female) keepdates
```

```stata
noisily tvweight tv_drug, covariates(age female)
generate(iptw_mg) model(mlogit) stabilized truncate(1 99) nolog
```

```
IPTW Weight Calculation
------------------------------------------------------------------------------
  exposure variable            : tv_drug
  number of levels             :              3
  model type                   : mlogit
  weight type                  : iptw
  covariates                   : age female
  observations                 :            589
------------------------------------------------------------------------------
Fitting propensity score model...
Calculating weights...
Calculating stabilized weights...
Truncating weights at 1st and 99th percentiles...
  Truncated 7 observations (5 low, 2 high)
Weight Diagnostics
------------------------------------------------------------------------------
Weight distribution
  mean                         :         1.0000
  SD                           :         0.0454
  min                          :         0.9351
  max                          :         1.1032
Percentiles
  1%                           :         0.9351
  5%                           :         0.9383
  25%                          :         0.9611
  50%                          :         0.9986
  75%                          :         1.0331
  95%                          :         1.0916
  99%                          :         1.1032
Effective sample size
  ESS                          :          587.8  (of 589 observations)
  ESS as % of N                :           99.8  %
Positivity / overlap
  P(observed treatment) range  : 0.2045 to 0.5832
  near-violations (P<0.05)     :              0  (0.0% of obs)
  weight mass, top 1% of rows  :            1.1  %  (6 row(s))
Weights by exposure group
  level 0                      : N=325  mean=1.000  SD=0.033
  level 1                      : N=133  mean=1.000  SD=0.074
  level 2                      : N=131  mean=1.000  SD=0.032
------------------------------------------------------------------------------
------------------------------------------------------------------------------
  Weight variable iptw_mg created.
------------------------------------------------------------------------------
```

### tvage with harmonized option names (id/dob/entry/exit)

```stata
use "`cohort'", clear
```

```stata
noisily tvage, id(id) dob(dob) entry(study_entry) exit(study_exit)
groupwidth(5) minage(40) maxage(80)
```
