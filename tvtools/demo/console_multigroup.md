---
title: "console_multigroup"
---

## Multi-Group Weighting and Age Bands

### tvweight with multinomial logit (3 treatment categories)

```stata
use "`pkg_dir'/_cohort.dta", clear
```

```stata
quietly tvexpose using "`pkg_dir'/_episodes_antidep.dta",
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
Observations:      891

Fitting propensity score model...

Calculating weights...
Calculating stabilized weights...
Truncating weights at 1th and 99th percentiles...
  Truncated 17 observations (5 low, 12 high)

----------------------------------------------------------------------
Weight Diagnostics
----------------------------------------------------------------------

Weight distribution:
  Mean:        1.0001
  SD:          0.0851
  Min:         0.8267
  Max:         1.2746

Percentiles:
  1%:          0.8267
  5%:          0.8592
  25%:         0.9446
  50%:         0.9918
  75%:         1.0502
  95%:         1.1578
  99%:         1.2746

Effective sample size:
  ESS:          884.6 (of 891 observations)
  ESS %:         99.3%

Positivity / overlap:
  P(observed treatment) range: 0.1156 to 0.7642
  Near-violations (P<0.05):    0 ( 0.0% of obs)
  Weight mass in top 1% of rows:   1.7%

Weights by exposure group:
--------------------------------------------------
0 1 2
  Level 0: N=627, Mean=  1.000, SD=  0.051
  Level 1: N=133, Mean=  1.000, SD=  0.157
  Level 2: N=131, Mean=  1.001, SD=  0.109
----------------------------------------------------------------------

Weight variable iptw_mg created successfully.
----------------------------------------------------------------------

```

### tvage with harmonized option names (id/dob/entry/exit)

```stata
use "`pkg_dir'/_cohort.dta", clear
```

```stata
noisily tvage, id(id) dob(dob) entry(study_entry) exit(study_exit)
groupwidth(5) minage(40) maxage(80)
```
