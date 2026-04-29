---
title: "console_multigroup"
---

## Multi-Group Treatment Weighting

### Step 1: tvexpose with 3 treatment categories

```stata
use "`pkg_dir'/_cohort.dta", clear
```

```stata
noisily tvexpose using "`pkg_dir'/_episodes_antidep.dta",
id(id) start(rx_start) stop(rx_stop)
exposure(drug) reference(0)
entry(study_entry) exit(study_exit)
keepvars(age female) keepdates
```

```
Warning! Overlapping exposure categories detected for 3 IDs
  (specify verbose to list affected IDs)

Default behavior: Later exposures take precedence (layer-style resolution)
Consider using one of these options to resolve overlaps explicitly:
  priority(numlist) - Specify precedence order for exposure types
  layer - Later exposures take precedence, earlier resume after
  split - Create separate periods at all boundaries
  combine(newvar) - Encode overlaps as combined values

Gaps in Coverage
------------------------------------------------------------
No gaps found in coverage

Time-varying exposure dataset created
Exposure Operationalization: timevarying
--------------------------------------------------
    Persons:            200
    Time-varying periods:            929
    Total person-time (days):        219,007
    Exposed person-time:         60,167 (27.5%)
    Unexposed person-time:        158,840
    Note: Baseline periods included (complete person-time coverage)
--------------------------------------------------

```

### Step 2: tvweight with multinomial logit

```stata
noisily tvweight tv_exposure, covariates(age female)
generate(iptw_mg) model(mlogit) stabilized truncate(1 99) nolog
```

```
----------------------------------------------------------------------
IPTW Weight Calculation
----------------------------------------------------------------------

Exposure variable: tv_exposure
Number of levels:  3
Model type:        mlogit
Covariates:        age female
Observations:      929

Fitting propensity score model...

Calculating weights...
Calculating stabilized weights...
Truncating weights at 1th and 99th percentiles...
  Truncated 15 observations (6 low, 9 high)

----------------------------------------------------------------------
Weight Diagnostics
----------------------------------------------------------------------

Weight distribution:
  Mean:        0.9994
  SD:          0.0896
  Min:         0.7501
  Max:         1.3094

Percentiles:
  1%:          0.7501
  5%:          0.8555
  25%:         0.9432
  50%:         0.9925
  75%:         1.0464
  95%:         1.1091
  99%:         1.3094

Effective sample size:
  ESS:          921.6 (of 929 observations)
  ESS %:         99.2%

Weights by exposure group:
--------------------------------------------------
0 1 2
  Level 0: N=640, Mean=  1.000, SD=  0.052
  Level 1: N=152, Mean=  0.996, SD=  0.182
  Level 2: N=137, Mean=  1.000, SD=  0.073
----------------------------------------------------------------------

Weight variable iptw_mg created successfully.
----------------------------------------------------------------------

```
