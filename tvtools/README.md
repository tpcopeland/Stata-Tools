# tvtools - Time-varying exposure workflow for survival analysis

**Version 1.0.0** | 2026-04-08

`tvtools` is a package-level workflow for building analysis-ready time-varying survival datasets in Stata. It starts from episode-format exposure records, turns them into person-period data, optionally merges multiple time-varying exposure streams, adds outcomes and competing risks, diagnoses coverage problems, and estimates inverse-probability weights.

The package is aimed at observational survival studies where exposure status changes over time and the analysis dataset needs to be constructed carefully before `stset`, `stcox`, or `stcrreg`.

## Requirements

- Stata 16 or later

## Installation

```stata
capture ado uninstall tvtools
net install tvtools, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/tvtools") replace
```

If you want the optional menu-setup script, download the ancillary files separately:

```stata
net get tvtools, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/tvtools")
do tvtools_menu_setup.do
```

`net install` installs the commands and help files. `net get` downloads extra files such as `tvtools_menu_setup.do` into the current working directory.

## Commands

| Command | Description |
|---------|-------------|
| `tvtools` | Display the package index and workflow guide |
| `tvexpose` | Create time-varying exposure intervals from episode-format exposure data |
| `tvmerge` | Merge multiple time-varying datasets into aligned person-time intervals |
| `tvevent` | Add outcomes and competing risks to an interval dataset |
| `tvdiagnose` | Check coverage, gaps, overlaps, and summary diagnostics |
| `tvweight` | Estimate inverse probability of treatment weights for interval data |
| `tvage` | Create time-varying age bands from dates of birth and follow-up dates |

## How It Works

The package is designed around a standard workflow:

1. Start with a cohort or event dataset in memory.
2. Use `tvexpose` with a `using` dataset of exposure episodes to create time-varying intervals.
3. If you have more than one time-varying exposure source, use `tvmerge` to align them.
4. Use `tvevent` to split intervals at event dates and code primary and competing outcomes.
5. Run `tvdiagnose` to verify coverage and identify gaps or overlaps.
6. Optionally use `tvweight` for IPTW and `tvage` for age-based time-varying covariates.
7. Fit your survival model with ordinary Stata commands such as `stcox` or `stcrreg`.

The examples below use the synthetic datasets shipped in the repository-wide `_data/` directory and load them directly from GitHub raw URLs so they remain runnable after a normal `net install`.

## Worked Examples

### 1. Build a single time-varying exposure dataset

In this pattern, the cohort is in memory and the antidepressant episode file is the `using` dataset.

```stata
use "https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/_data/cohort.dta", clear

tvexpose using "https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/_data/tv_antidep_episodes.dta", ///
    id(id) start(rx_start) stop(rx_stop) ///
    exposure(drug_class) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    keepvars(index_age female education) ///
    saveas(tv_antidep.dta) replace

use tv_antidep.dta, clear
tvdiagnose, id(id) start(rx_start) stop(rx_stop) ///
    exposure(tv_exposure) entry(study_entry) exit(study_exit) all
```

`tvexpose` creates one row per person-time segment where exposure status is constant. `tvdiagnose` is the first quality check: it tells you whether the derived intervals cover follow-up as expected and whether there are gaps or overlaps that need attention.

### 2. Add outcomes and estimate a competing-risks model

For `tvevent`, the event file is in memory and the interval file created by `tvexpose` is the `using` dataset.

```stata
use "https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/_data/tv_events.dta", clear

tvevent using tv_antidep.dta, id(id) ///
    date(cv_event_date) compete(death_date) ///
    generate(outcome) startvar(rx_start) stopvar(rx_stop)

stset rx_stop, id(id) failure(outcome==1) enter(rx_start)
stcrreg i.tv_exposure, compete(outcome==2)
```

This workflow produces an event indicator where `0` means censored, `1` is the primary event, and `2` is the competing event. Once that variable is in place, the dataset is ready for standard survival modeling.

### 3. Merge two time-varying exposure streams, then weight

`tvmerge` expects unique exposure-variable names in each input dataset. The example below creates antidepressant and benzodiazepine interval files, renames the generated exposure variables, merges them, and then estimates multinomial IPTW weights.

```stata
use "https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/_data/cohort.dta", clear

tvexpose using "https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/_data/tv_antidep_episodes.dta", ///
    id(id) start(rx_start) stop(rx_stop) ///
    exposure(drug_class) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    keepvars(index_age female education) ///
    saveas(tv_antidep.dta) replace

use tv_antidep.dta, clear
rename tv_exposure antidep_class
save tv_antidep.dta, replace

use "https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/_data/cohort.dta", clear

tvexpose using "https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/_data/tv_benzo_episodes.dta", ///
    id(id) start(rx_start) stop(rx_stop) ///
    exposure(benzo_use) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    saveas(tv_benzo.dta) replace

use tv_benzo.dta, clear
rename tv_exposure benzo
save tv_benzo.dta, replace

tvmerge tv_antidep.dta tv_benzo.dta, id(id) ///
    start(rx_start rx_start) stop(rx_stop rx_stop) ///
    exposure(antidep_class benzo) ///
    keep(index_age female education)

tvweight antidep_class, ///
    covariates(index_age_ds1 female_ds1 education_ds1) ///
    model(mlogit) generate(iptw)
```

The `keep()` option in `tvmerge` carries selected covariates forward into the merged dataset and adds `_ds#` suffixes so their source dataset stays clear. That is why the weighting example refers to `index_age_ds1`, `female_ds1`, and `education_ds1`.

### 4. Create time-varying age bands

`tvage` is a helper for building an age-based interval dataset from dates of birth and follow-up dates. It is especially useful when age needs to be aligned with the same person-time structure as your exposures.

```stata
use "https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/_data/cohort.dta", clear

tvage, idvar(id) dobvar(dob) entryvar(study_entry) exitvar(study_exit) ///
    groupwidth(5) minage(40) maxage(80) ///
    saveas(age_tv.dta) replace
```

## Command-Specific Notes

### `tvexpose`

- Supports basic time-varying exposures, ever-treated coding, current/former coding, duration categories, recency categories, dose tracking, and continuous cumulative exposure.
- The cohort stays in memory. Exposure episodes are supplied through `using`.

### `tvmerge`

- Requires at least two input time-varying datasets.
- Exposure variable names should be unique across the inputs before merging.
- `keep()` carries additional variables through the merge and suffixes them with `_ds#`.

### `tvevent`

- The event dataset stays in memory. The interval dataset is the `using` file.
- Supports primary events, competing risks, recurring events, and continuous interval variables that need proportional adjustment when an event splits a period.

### `tvdiagnose`

- Use it early and often after `tvexpose` or `tvmerge`.
- The most common checks are `coverage`, `gaps`, `overlaps`, and `all`.

### `tvweight`

- Supports both binary and multinomial treatment models through `model(logit)` and `model(mlogit)`.
- `stabilized`, `truncate()`, and `denominator()` are the main options to reach for in applied workflows.

## Demo Output

### Console output

![Console output](demo/console_output.png)

### Swimlane view of person-time exposure

![Swimlane plot](demo/swimlane_plot.png)

### Person-time plot

![Person-time plot](demo/persontime_plot.png)

## Version History

- **1.0.0** (2026-04-08): Current Stata-Tools release
