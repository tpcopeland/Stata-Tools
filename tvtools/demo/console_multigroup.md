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
----------------------------------------------------------------------
IPTW Weight Calculation
----------------------------------------------------------------------

Exposure variable: tv_drug
Number of levels:  3
Model type:        mlogit
Weight type:       iptw
Covariates:        age female
Observations:      589

Fitting propensity score model...

Calculating weights...
Calculating stabilized weights...
Truncating weights at 1th and 99th percentiles...
  Truncated 7 observations (5 low, 2 high)

----------------------------------------------------------------------
Weight Diagnostics
----------------------------------------------------------------------

Weight distribution:
  Mean:        1.0000
  SD:          0.0454
  Min:         0.9351
  Max:         1.1032

Percentiles:
  1%:          0.9351
  5%:          0.9383
  25%:         0.9611
  50%:         0.9986
  75%:         1.0331
  95%:         1.0916
  99%:         1.1032

Effective sample size:
  ESS:          587.8 (of 589 observations)
  ESS %:         99.8%

Positivity / overlap:
  P(observed treatment) range: 0.2045 to 0.5832
  Near-violations (P<0.05):    0 ( 0.0% of obs)
  Weight mass in top 1% of rows (6 row(s)):   1.1%

Weights by exposure group:
--------------------------------------------------
0 1 2
  Level 0: N=325, Mean=  1.000, SD=  0.033
  Level 1: N=133, Mean=  1.000, SD=  0.074
  Level 2: N=131, Mean=  1.000, SD=  0.032
----------------------------------------------------------------------

Weight variable iptw_mg created successfully.
----------------------------------------------------------------------
```

### tvage with harmonized option names (id/dob/entry/exit)

```stata
use "`cohort'", clear
```

```stata
noisily tvage, id(id) dob(dob) entry(study_entry) exit(study_exit)
groupwidth(5) minage(40) maxage(80)
```
