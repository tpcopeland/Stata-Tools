# tvtools - Time-varying exposure workflow for survival analysis

**Version 1.0.0** | 2026-04-08

`tvtools` is a workflow package for building analysis-ready time-varying survival data in Stata. It starts from person-level follow-up plus episode-format exposure records and helps you derive exposure intervals, align multiple time-varying sources, add outcomes and competing risks, diagnose gaps and overlaps, estimate IPTW weights, and create age-band intervals.

## Requirements

- Stata 16 or later
- Internet access if you want to run the public `_data/` examples directly from GitHub

## Installation

```stata
capture ado uninstall tvtools
net install tvtools, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/tvtools") replace
```

If you want the optional menu-setup helper that ships with the package, download the ancillary files separately:

```stata
net get tvtools, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/tvtools")
do tvtools_menu_setup.do
```

## Commands

| Command | Purpose | Help |
|---------|---------|------|
| `tvtools` | Package index: lists all commands and their categories | `help tvtools` |
| `tvexpose` | Create time-varying exposure intervals from episode data | `help tvexpose` |
| `tvmerge` | Merge multiple time-varying datasets into aligned person-time intervals | `help tvmerge` |
| `tvevent` | Add outcomes and competing risks to an interval dataset | `help tvevent` |
| `tvdiagnose` | Check coverage, gaps, overlaps, and exposure summaries | `help tvdiagnose` |
| `tvweight` | Estimate inverse probability of treatment weights for interval data | `help tvweight` |
| `tvage` | Create time-varying age intervals from dates of birth and follow-up dates | `help tvage` |

## How It Works

The package follows a pipeline where each command produces output in a consistent id/start/stop format:

```
cohort.dta + episodes.dta
        |
     tvexpose  -->  person-period intervals (one exposure)
        |
     tvmerge   -->  aligned intervals (multiple exposures)
        |
     tvevent   -->  intervals with outcome/competing-risk flags
        |
     tvdiagnose -->  quality report (coverage, gaps, overlaps)
        |
     tvweight  -->  IPTW weights for causal inference
```

**Key conventions:**

- The **cohort or event data stay in memory**; exposure episodes are supplied through `using` files.
- All date variables must be **Stata daily dates** (integer days, `%td` format). Datetime variables (`%tc`/`%tC`) are rejected with a clear error.
- Intervals use a **closed [start, stop] convention** where both endpoints are inclusive.
- `tvmerge` operates on **tvexpose output**, not raw episode files.
- For `tvevent`, the **event data** is the master (in memory) and the **interval data** is the using file.

## Demo Output

Output below is generated from `tvtools/demo/demo_tvtools.do` (200-patient synthetic cohort, SSRI/SNRI antidepressant study design). Rendered with [logdoc](../logdoc/).

### Binary treatment pipeline

<details>
<summary>Package overview (click to expand)</summary>

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

</details>

<details>
<summary>Step 1: tvexpose — create exposure intervals (click to expand)</summary>

```stata
tvexpose using episodes_antidep.dta, ///
    id(id) start(rx_start) stop(rx_stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
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

</details>

<details>
<summary>Step 2: tvdiagnose — coverage and gap diagnostics (click to expand)</summary>

```stata
tvdiagnose, id(id) start(rx_start) stop(rx_stop) ///
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

</details>

<details>
<summary>Step 3: tvmerge — merge two exposure streams (click to expand)</summary>

```stata
tvmerge tv_antidep.dta tv_benzo.dta, id(id) ///
    start(rx_start rx_start) stop(rx_stop rx_stop) ///
    exposure(tv_exposure tv_exposure) ///
    generate(antidep benzo) ///
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

</details>

<details>
<summary>Step 4: tvevent — add outcomes and competing risks (click to expand)</summary>

```stata
tvevent using tv_antidep.dta, id(id) ///
    date(cv_event_date) compete(death_date) ///
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
    0 = Censored
    1 = Event: cv_event_date
    2 = Competing: death_date
--------------------------------------------------
```

</details>

<details>
<summary>Step 5: tvweight — estimate IPTW weights, binary (click to expand)</summary>

```stata
gen byte any_drug = (tv_exposure != 0) if !missing(tv_exposure)
tvweight any_drug, covariates(age female) ///
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

</details>

### Step 6: tvage — create age-band intervals

```stata
tvage, idvar(id) dobvar(dob) entryvar(study_entry) exitvar(study_exit) ///
    groupwidth(5) minage(40) maxage(80) ///
    saveas(age_tv.dta) replace
```

The output has the same id/start/stop structure as `tvexpose`, so you can merge age bands with exposure intervals using `tvmerge`:

```stata
tvmerge tv_antidep.dta age_tv.dta, id(id) ///
    start(rx_start age_start) stop(rx_stop age_stop) ///
    exposure(tv_exposure age_tv)
```

### Multi-group treatment weighting

When the exposure has 3+ categories, `tvweight` automatically switches to multinomial logit (`mlogit`). This example uses the full drug variable (0=Unexposed, 1=SSRI, 2=SNRI) with stabilized weights and percentile truncation.

<details>
<summary>tvexpose — 3 treatment categories (click to expand)</summary>

```stata
tvexpose using episodes_antidep.dta, ///
    id(id) start(rx_start) stop(rx_stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
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

</details>

<details>
<summary>tvweight — multinomial logit with stabilization and truncation (click to expand)</summary>

```stata
tvweight tv_exposure, covariates(age female) ///
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
  Level 0: N=640, Mean=  1.000, SD=  0.052
  Level 1: N=152, Mean=  0.996, SD=  0.182
  Level 2: N=137, Mean=  1.000, SD=  0.073
----------------------------------------------------------------------

Weight variable iptw_mg created successfully.
----------------------------------------------------------------------
```

</details>

## Worked Examples

### Fitting a competing-risks model after the pipeline

After running Steps 1 and 4, the interval dataset is ready for `stset` and analysis:

```stata
stset rx_stop, id(id) failure(outcome==1) enter(rx_start)
stcrreg i.tv_exposure, compete(outcome==2)
```

The outcome variable uses `0` for censoring, `1` for the primary event, and `2` for the competing event.

## Command Reference

### tvexpose

Transforms episode-format exposure records into person-period intervals. Supports:

- **Default**: categorical time-varying exposure
- **evertreated**: binary ever/never (corrects immortal time bias)
- **currentformer**: three-level never/current/former
- **duration()**: cumulative duration categories
- **continuousunit()**: continuous cumulative exposure (days, weeks, months, quarters, years)
- **recency()**: time since last exposure
- **dose**: cumulative dose tracking with proportional overlap allocation
- **grace()**, **lag()**, **washout()**: exposure timing adjustments
- **priority()**, **layer**, **split**, **combine()**: overlap resolution

### tvmerge

Merges two or more `tvexpose` outputs into a single dataset with synchronized time periods. Uses Cartesian interval intersection. Continuous exposures are pro-rated when intervals are split. The `force` option handles non-matching IDs across datasets.

### tvevent

Integrates outcomes and competing risks into interval data. Splits intervals at event dates, adjusts continuous variables proportionally, and flags events (0=censored, 1=primary, 2+=competing). Supports `type(single)` (terminal first event) and `type(recurring)` (wide-format repeated events).

### tvdiagnose

Quality-control tool for interval datasets. Four reports: `coverage` (fraction of follow-up covered), `gaps` (unexposed intervals), `overlaps` (concurrent records), and `summarize` (exposure frequency and person-time). Use `all` to run everything. The `verbose` option shows individual records.

### tvweight

Estimates inverse probability of treatment weights (IPTW) for causal inference. Supports binary (`logit`) and multinomial (`mlogit`) propensity score models, stabilized weights, percentile truncation, and panel-aware weighting with cluster-robust SEs. Reports weight distribution, percentiles, and effective sample size (ESS).

### tvage

Creates time-varying age intervals from dates of birth and follow-up dates. Expands one-record-per-person data into one row per age (or age group). Output is compatible with `tvmerge` for merging age bands with other time-varying covariates.

## Version History

- **1.0.0** (2026-04-08): Initial Stata-Tools release

## Author

Timothy P Copeland, Karolinska Institutet
