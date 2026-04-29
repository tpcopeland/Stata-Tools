---
title: "console_output"
---

## tvtools: Time-Varying Exposure Analysis

### Package overview

```stata
use "`pkg_dir'/_cohort.dta", clear
```

```stata
noisily tvtools
```

```
----------------------------------------------------------------------
tvtools - Time-Varying Exposure Analysis Suite
----------------------------------------------------------------------

Data Preparation
  tvexpose   - Create time-varying exposure variables
  tvmerge    - Merge multiple time-varying datasets
  tvevent    - Integrate events and competing risks
  tvage      - Add time-varying age to stset data

Diagnostics
  tvdiagnose - Diagnostic tools for TV datasets

Weighting
  tvweight   - Calculate IPTW weights

----------------------------------------------------------------------
Total commands: 6

Help: help tvtools for workflow guide
      help <command> for individual command help

```

### Step 1: Create exposure intervals with tvexpose

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

```stata
save "`pkg_dir'/_tv_antidep.dta", replace
```

```
(file tvtools/demo/_tv_antidep.dta not found)
file tvtools/demo/_tv_antidep.dta saved

```

### Step 2: Diagnose the interval dataset

```stata
noisily tvdiagnose, id(id) start(rx_start) stop(rx_stop)
entry(study_entry) exit(study_exit) all
```

```
----------------------------------------------------------------------
Time-Varying Data Diagnostics
----------------------------------------------------------------------
Dataset summary:
  Observations:          929
  Persons:          200
  Periods/person:      4.6

----------------------------------------------------------------------
Coverage Diagnostics
----------------------------------------------------------------------
----------------------------------------------------------------------
Coverage Summary:
  Mean coverage: 100.0%
  Min coverage:  100.0%
  Max coverage:  100.0%
  Persons with gaps: 0 ( 0.0%)
----------------------------------------------------------------------

----------------------------------------------------------------------
Gap Analysis
----------------------------------------------------------------------
No gaps found in coverage

----------------------------------------------------------------------
Overlap Analysis
----------------------------------------------------------------------
No overlapping periods found

----------------------------------------------------------------------
Diagnostic Complete
----------------------------------------------------------------------

```

### Step 3: Merge two exposure streams

```stata
use "`pkg_dir'/_cohort.dta", clear
```

```stata
quietly tvexpose using "`pkg_dir'/_episodes_benzo.dta",
id(id) start(rx_start) stop(rx_stop)
exposure(benzo_use) reference(0)
entry(study_entry) exit(study_exit)
keepvars(age female) keepdates
```

```stata
save "`pkg_dir'/_tv_benzo.dta", replace
```

```
(file tvtools/demo/_tv_benzo.dta not found)
file tvtools/demo/_tv_benzo.dta saved

```

```stata
noisily tvmerge "`pkg_dir'/_tv_antidep.dta" "`pkg_dir'/_tv_benzo.dta",
id(id)
start(rx_start rx_start) stop(rx_stop rx_stop)
exposure(tv_exposure tv_exposure)
generate(antidep benzo)
keep(age female)
```

```
Processing 200 unique IDs in 5 batches (batch size: 40 IDs = 20%)...
  Batch 1/5...
  Batch 2/5...
  Batch 3/5...
  Batch 4/5...
  Batch 5/5...

Merged time-varying dataset successfully created
--------------------------------------------------
    Observations:          1,522
    Persons:            200
    Exposure variables:  antidep benzo
--------------------------------------------------

```

### Step 4: Add events and competing risks

```stata
use "`pkg_dir'/_events.dta", clear
```

```stata
noisily tvevent using "`pkg_dir'/_tv_antidep.dta", id(id)
date(cv_event_date) compete(death_date)
generate(outcome) startvar(rx_start) stopvar(rx_stop)
```

```
Splitting intervals for 24 internal events...
Single event type: Censored person-time after first event.


--------------------------------------------------
Event integration complete
  Observations: 897
  Events flagged (outcome): 24
  Variable outcome labels:
0 1 2
    0 = Censored
    1 = Event: cv_event_date
    2 = Competing: death_date
--------------------------------------------------

```

### Step 5: Estimate IPTW weights (binary)

```stata
use "`pkg_dir'/_tv_antidep.dta", clear
```

```
(tvtools/demo/_episodes_antidep.dta)

```

```stata
gen byte any_drug = (tv_exposure != 0) if !missing(tv_exposure)
```

```stata
noisily tvweight any_drug, covariates(age female)
generate(iptw) stabilized nolog
```

```
----------------------------------------------------------------------
IPTW Weight Calculation
----------------------------------------------------------------------

Exposure variable: any_drug
Number of levels:  2
Model type:        logit
Covariates:        age female
Observations:      929

Fitting propensity score model...

Calculating weights...
Calculating stabilized weights...

----------------------------------------------------------------------
Weight Diagnostics
----------------------------------------------------------------------

Weight distribution:
  Mean:        0.9999
  SD:          0.0764
  Min:         0.8245
  Max:         1.2455

Percentiles:
  1%:          0.8323
  5%:          0.8732
  25%:         0.9517
  50%:         0.9928
  75%:         1.0424
  95%:         1.1267
  99%:         1.2315

Effective sample size:
  ESS:          923.6 (of 929 observations)
  ESS %:         99.4%

Weights by exposure group:
--------------------------------------------------
  Reference (any_drug=0): N=640, Mean=  1.000, SD=  0.052
  Exposed (any_drug!=0):  N=289, Mean=  1.000, SD=  0.113
----------------------------------------------------------------------

Weight variable iptw created successfully.
----------------------------------------------------------------------

```

### Step 6: Create age-band intervals

```stata
use "`pkg_dir'/_cohort.dta", clear
```

```stata
noisily tvage, idvar(id) dobvar(dob) entryvar(study_entry) exitvar(study_exit)
groupwidth(5) minage(40) maxage(80)
saveas("`pkg_dir'/_age_tv.dta") replace
```

```
(file tvtools/demo/_age_tv.dta not found)
file tvtools/demo/_age_tv.dta saved

```
