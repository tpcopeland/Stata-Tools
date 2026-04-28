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

## Worked Examples

The examples below use synthetic datasets from `_data/` modeling an SSRI vs SNRI antidepressant study.

### 1. Create a single time-varying exposure dataset and diagnose it

In this pattern, the cohort is in memory and the exposure episodes are supplied through `using`.

```stata
use "https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/_data/cohort.dta", clear

tvexpose using "https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/_data/tv_antidep_episodes.dta", ///
    id(id) start(rx_start) stop(rx_stop) ///
    exposure(drug_class) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    keepvars(index_age female education) keepdates ///
    saveas(tv_antidep.dta) replace

use tv_antidep.dta, clear
tvdiagnose, id(id) start(rx_start) stop(rx_stop) ///
    exposure(tv_exposure) entry(study_entry) exit(study_exit) all
```

`tvexpose` creates one row per person-time segment where exposure status is constant. `tvdiagnose` is the first quality check for coverage, gaps, overlaps, and exposure distribution.

### 2. Merge two exposure streams and estimate IPTW

`tvmerge` expects interval files, not raw episode data. When those files still use the default `tv_exposure` variable name, assign distinct output names during the merge with `generate()`.

```stata
use "https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/_data/cohort.dta", clear
tvexpose using "https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/_data/tv_benzo_episodes.dta", ///
    id(id) start(rx_start) stop(rx_stop) ///
    exposure(benzo_use) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    saveas(tv_benzo.dta) replace

tvmerge tv_antidep.dta tv_benzo.dta, id(id) ///
    start(rx_start rx_start) stop(rx_stop rx_stop) ///
    exposure(tv_exposure tv_exposure) ///
    generate(antidep_class benzo) ///
    keep(index_age female education)

tvweight antidep_class, ///
    covariates(index_age_ds1 female_ds1 education_ds1) ///
    model(mlogit) generate(iptw)
```

The `keep()` option carries selected covariates through the merge and suffixes them with `_ds#` so their source dataset stays explicit.

### 3. Add events and fit a competing-risks model

For `tvevent`, the event data stay in memory and the interval dataset is the `using` file.

```stata
use "https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/_data/tv_events.dta", clear

tvevent using tv_antidep.dta, id(id) ///
    date(cv_event_date) compete(death_date) ///
    generate(outcome) startvar(rx_start) stopvar(rx_stop)

stset rx_stop, id(id) failure(outcome==1) enter(rx_start)
stcrreg i.tv_exposure, compete(outcome==2)
```

The resulting outcome variable uses `0` for censoring, `1` for the primary event, and `2` for the competing event.

### 4. Create age bands on the same follow-up scale

`tvage` is a helper when age needs to be represented as its own time-varying interval dataset.

```stata
use "https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/_data/cohort.dta", clear

tvage, idvar(id) dobvar(dob) entryvar(study_entry) exitvar(study_exit) ///
    groupwidth(5) minage(40) maxage(80) ///
    saveas(age_tv.dta) replace
```

The output has the same id/start/stop structure as `tvexpose`, so you can merge it with exposure intervals using `tvmerge`:

```stata
tvmerge tv_antidep.dta age_tv.dta, id(id) ///
    start(rx_start age_start) stop(rx_stop age_stop) ///
    exposure(drug_class age_tv)
```

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
