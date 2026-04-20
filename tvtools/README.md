# tvtools - Time-varying exposure workflow for survival analysis

**Version 1.0.0** | 2026-04-08

`tvtools` is a workflow package for building analysis-ready time-varying survival data in Stata. It starts from person-level follow-up plus episode-format exposure records and helps you derive exposure intervals, align multiple time-varying sources, add outcomes and competing risks, diagnose gaps and overlaps, estimate IPTW weights, and create age-band intervals.

> Version note: the package `.pkg`, help files, and command headers are version 1.0.0 dated 2026-04-08. The current `tvtools.ado` also returns `r(version) = "1.5.3"`, so the README follows the shipped package metadata.

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

| Command | Description |
|---------|-------------|
| `tvtools` | Package index and workflow guide |
| `tvexpose` | Create time-varying exposure intervals from episode data |
| `tvmerge` | Merge multiple time-varying datasets into aligned person-time intervals |
| `tvevent` | Add outcomes and competing risks to an interval dataset |
| `tvdiagnose` | Check coverage, gaps, overlaps, and exposure summaries |
| `tvweight` | Estimate inverse probability of treatment weights for interval data |
| `tvage` | Create time-varying age intervals from dates of birth and follow-up dates |

## How It Works

- Keep the cohort or event data in memory and use `tvexpose` with a `using` file of exposure episodes.
- If you need multiple exposure streams, first build each one with `tvexpose`, then combine them with `tvmerge` and use `generate()` or `prefix()` if the source exposure variables share the default name `tv_exposure`.
- Load event data as the master dataset and use `tvevent using <interval-file>` to split intervals at outcomes and competing risks.
- Run `tvdiagnose` after `tvexpose` or `tvmerge` to verify coverage and identify gaps or overlaps.
- Use `tvweight` once the interval data are ready for causal weighting.
- Use `tvage` when age itself needs the same interval structure as the exposure data.

## Worked Examples

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

## Command Notes

- `tvexpose` supports default time-varying coding plus `evertreated`, `currentformer`, `duration()`, `continuousunit()`, `recency()`, and `dose`.
- `tvmerge` merges `tvexpose` outputs. It does not work directly on raw episode files.
- `tvevent` supports single events, recurring events in wide format, competing risks, and proportional adjustment of continuous interval variables when an event splits a period.
- `tvdiagnose` is most useful right after `tvexpose` or `tvmerge`, especially with `coverage`, `gaps`, `overlaps`, and `all`.
- `tvweight` supports both binary and multinomial treatment models and can add stabilized or truncated weights.
- `tvage` expects one record per person and daily date variables rather than `%tc` datetimes.

## Version History

- **1.0.0** (2026-04-08): Initial Stata-Tools release

## Author

Timothy P Copeland, Karolinska Institutet
