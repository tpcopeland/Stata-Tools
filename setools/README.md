# setools

![Stata 18+](https://img.shields.io/badge/Stata-18%2B-brightgreen) ![MIT License](https://img.shields.io/badge/License-MIT-blue) ![Status](https://img.shields.io/badge/Status-Active-success)

Toolkit for managing Swedish registry data in epidemiological cohort studies.

## Package Overview

**setools** provides commands for processing Swedish registry data, with a focus on migration handling and disability outcome computation for multiple sclerosis research:

1. **migrations** - Process Swedish migration registry data for cohort studies
2. **sustainedss** - Compute sustained EDSS progression dates for MS research

---

## migrations - Process Swedish Migration Registry Data

**migrations** processes Swedish migration registry data to identify exclusions and censoring dates for cohort studies. It handles the complex logic of determining residency status at study entry and identifying emigration events for survival analysis censoring.

## Installation

```stata
net install setools, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/setools")
```

## Syntax

```stata
migrations, migfile(filename) [options]
```

### Required Options

| Option | Description |
|--------|-------------|
| `migfile(filename)` | Path to migrations_wide.dta file |

### Optional Options

| Option | Description | Default |
|--------|-------------|---------|
| `idvar(varname)` | ID variable | id |
| `startvar(varname)` | Study start date variable | study_start |
| `saveexclude(filename)` | Save excluded observations to file | - |
| `savecensor(filename)` | Save emigration censoring dates to file | - |
| `replace` | Replace existing files | - |
| `verbose` | Display processing messages | - |

### How It Works

The command expects a master dataset in memory containing individual IDs and study start dates. It merges with the Swedish migration registry (migrations_wide.dta format) and applies the following logic:

**Exclusion Criteria:**

1. **Type 1 - Emigrated before study start**: Last emigration occurred before study start AND last immigration occurred before last emigration (person left Sweden and never returned)

2. **Type 2 - Not in Sweden at baseline**: Only migration record is an immigration after study start (person was not in Sweden at study entry)

**Censoring Logic:**

For individuals not excluded, the command identifies the first emigration date after study start as `migration_out_dt`, representing when the person left Sweden and should be censored from follow-up.

### Examples

#### Example 1: Basic Usage

```stata
use cohort_data, clear
migrations, migfile("$source/migrations_wide.dta")
```

#### Example 2: Custom Variable Names

```stata
use my_cohort, clear
migrations, migfile("K:/data/migrations_wide.dta") ///
   idvar(lopnr) startvar(baseline_date) ///
   saveexclude(excluded_migrations) savecensor(emigration_dates) replace
```

#### Example 3: Full Workflow

```stata
* Define cohort with study start dates
use basdata, clear
gen study_start = onset_date
replace study_start = mdy(1,1,2006) if study_start < mdy(1,1,2006)

* Apply migration exclusions and get censoring dates
migrations, migfile("$source/migrations_wide.dta") verbose

* Use migration_out_dt in survival analysis
gen end_date = min(death_date, migration_out_dt, mdy(12,31,2023))
stset end_date, failure(outcome) origin(study_start)
```

### Migration File Format

The migration file must be in wide format with:
- ID variable matching master data
- Immigration dates: `in_1`, `in_2`, `in_3`, ...
- Emigration dates: `out_1`, `out_2`, `out_3`, ...

### Stored Results

| Scalar | Description |
|--------|-------------|
| `r(N_excluded_emigrated)` | Number excluded due to emigration before study start |
| `r(N_excluded_inmigration)` | Number excluded due to immigration after study start |
| `r(N_excluded_total)` | Total number excluded |
| `r(N_censored)` | Number with emigration censoring dates |
| `r(N_final)` | Final sample size after exclusions |

---

## sustainedss - Compute Sustained EDSS Progression

**sustainedss** computes sustained EDSS (Expanded Disability Status Scale) progression dates for multiple sclerosis research. An EDSS progression event is considered "sustained" if the disability level is maintained within a confirmation window.

### Syntax

```stata
sustainedss idvar edssvar datevar [if] [in], threshold(#) [options]
```

### Required Options

| Option | Description |
|--------|-------------|
| `threshold(#)` | EDSS threshold for progression (e.g., 4 or 6) |

### Optional Options

| Option | Description | Default |
|--------|-------------|---------|
| `generate(newvar)` | Name for generated date variable | sustained#_dt |
| `confirmwindow(#)` | Confirmation window in days | 182 |
| `baselinethreshold(#)` | EDSS level for reversal check | 4 |
| `keepall` | Retain all observations | Keep only patients with events |
| `quietly` | Suppress iteration messages | - |

### Algorithm

The command implements an iterative algorithm:

1. Identifies the first date when EDSS reaches or exceeds the threshold
2. Examines EDSS measurements within the confirmation window
3. Rejects events where the lowest subsequent EDSS falls below baseline threshold AND the last EDSS in the window is below target threshold
4. For rejected events, replaces the EDSS value with the last observed value and repeats
5. Continues until all remaining events are confirmed as sustained

### Examples

#### Example 1: Basic Usage

```stata
use edss_long, clear
sustainedss id edss edss_dt, threshold(4)
```

#### Example 2: Sustained EDSS 6 with Custom Variable Name

```stata
sustainedss id edss edss_dt, threshold(6) generate(edss6_sustained)
```

#### Example 3: 3-Month Confirmation Window

```stata
sustainedss id edss edss_dt, threshold(4) confirmwindow(90)
```

#### Example 4: Keep All Patients

```stata
sustainedss id edss edss_dt, threshold(4) keepall
```

#### Example 5: Full MS Disability Workflow

```stata
use edss_long, clear

* Exclude patients with baseline EDSS >= 4
merge m:1 id using edss_baseline, nogen
drop if edss_baseline >= 4

* Compute sustained EDSS 4
sustainedss id edss edss_dt, threshold(4) keepall

* Keep one row per patient
duplicates drop id, force
keep id sustained4_dt
```

#### Example 6: Synthetic Data Example (Runnable)

```stata
clear
set seed 12345
set obs 500
gen id = ceil(_n/5)
bysort id: gen visit = _n
gen edss_dt = mdy(1,1,2020) + visit*90 + floor(runiform()*30)
gen edss = floor(runiform()*10)
format edss_dt %tdCCYY/NN/DD
sustainedss id edss edss_dt, threshold(4)
return list
```

### Remarks

**Data Requirements:**
- `idvar`: Patient identifier (numeric or string)
- `edssvar`: EDSS score (numeric)
- `datevar`: Date of measurement (numeric, Stata date format)

**Edge Cases:**
- If a patient reaches the threshold but has no subsequent measurements within the confirmation window, the event is considered sustained (cannot be disproven)
- Patients with baseline EDSS already at/above threshold should be excluded before running

### Stored Results

| Scalar | Description |
|--------|-------------|
| `r(N_events)` | Number of sustained events identified |
| `r(iterations)` | Number of iterations required |
| `r(threshold)` | EDSS threshold used |
| `r(confirmwindow)` | Confirmation window in days |

| Macro | Description |
|-------|-------------|
| `r(varname)` | Name of generated variable |

---

## Installation

Install directly from GitHub:

```stata
net from https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/setools
net install setools
```

## Requirements

- Stata 18.0 or higher
- No additional dependencies

## Documentation

Command help:
```stata
help migrations
help sustainedss
```

## Author

Timothy P Copeland<br>
Department of Clinical Neuroscience<br>
Karolinska Institutet

## License

MIT License

## Version

Version 1.0.1, 2025-12-03

Individual command versions:
- migrations: 1.0.1
- sustainedss: 1.0.1

## References

Kappos L, et al. Inclusion of brain volume loss in a revised measure of 'no evidence of disease activity' (NEDA-4) in relapsing-remitting multiple sclerosis. *Multiple Sclerosis Journal*. 2016;22(10):1297-1305.

Confavreux C, Vukusic S. Natural history of multiple sclerosis: a unifying concept. *Brain*. 2006;129(3):606-616.

## See Also

- Stata help: `help stset`, `help stcox`, `help merge`
- Related package: [tvtools](../tvtools/) - Time-varying exposure analysis
