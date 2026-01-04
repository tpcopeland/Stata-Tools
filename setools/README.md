# setools

![Stata 16+](https://img.shields.io/badge/Stata-16%2B-brightgreen) ![MIT License](https://img.shields.io/badge/License-MIT-blue) ![Status](https://img.shields.io/badge/Status-Active-success)

Toolkit for managing Swedish registry data in epidemiological cohort studies.

## Package Overview

**setools** provides commands for processing Swedish registry data, with a focus on ICD code utilities, migration handling, and MS research:

| Command | Description |
|---------|-------------|
| **icdexpand** | ICD-10 code utilities (expand wildcards, validate, match in data) |
| **dateparse** | Date parsing and window calculations for cohort studies |
| **migrations** | Process Swedish migration registry data for cohort studies |
| **procmatch** | KVÅ procedure code matching for Swedish registries |
| **sustainedss** | Compute sustained EDSS threshold dates (e.g., EDSS 4, EDSS 6) |
| **cdp** | Confirmed Disability Progression from baseline EDSS |
| **pira** | Progression Independent of Relapse Activity |
| **tvage** | Generate time-varying age intervals for survival analysis |
| **covarclose** | Extract covariate values closest to index date from longitudinal data |

---

## icdexpand - ICD-10 Code Utilities

**icdexpand** provides utilities for working with ICD-10 diagnosis codes in Swedish health registries. It supports wildcard expansion, range expansion, code validation, and direct matching against diagnosis variables.

### Subcommands

| Subcommand | Description |
|------------|-------------|
| `expand` | Expand ICD code patterns (wildcards, ranges) to full code list |
| `validate` | Validate ICD-10 code format |
| `match` | Create binary indicator for ICD code matches in diagnosis variables |

### Syntax

```stata
* Expand patterns
icdexpand expand, pattern(string) [maxcodes(#) noisily]

* Validate codes
icdexpand validate, pattern(string) [noisily]

* Match in data
icdexpand match, codes(string) dxvars(varlist) [generate(name) replace casesensitive noisily]
```

### Pattern Syntax

| Pattern | Description | Example |
|---------|-------------|---------|
| `I63*` | Wildcard - expands to all subcodes | I63, I63.0-I63.9, I630-I639, I63.00-I63.99 |
| `E10-E14` | Range - all codes in range | E10, E11, E12, E13, E14 (+ subcodes) |
| `I63*, G35` | Multiple patterns | Combine with commas or spaces |

### Examples

```stata
* Expand stroke codes
icdexpand expand, pattern("I63* I64*") noisily
local stroke_codes "`r(codes)'"

* Match in inpatient data
use inpatient, clear
icdexpand match, codes("I63* I64*") dxvars(dx1-dx30) generate(stroke) noisily

* Find MS diagnoses
use out_2020, clear
icdexpand match, codes("G35") dxvars(dx1-dx30) generate(ms_dx) replace
keep if ms_dx == 1
bysort id (visitdt): keep if _n == 1  // First MS visit

* Cancer cohort (excluding non-melanoma skin)
use inpatient, clear
icdexpand match, codes("C00-C43* C45-C97*") dxvars(dx1-dx30) generate(cancer)
```

### Stored Results

| Return | Description |
|--------|-------------|
| `r(codes)` | Space-separated list of expanded codes |
| `r(n_codes)` | Number of codes after expansion |
| `r(varname)` | Name of generated indicator variable (match) |
| `r(n_matches)` | Number of observations matching (match) |

---

## dateparse - Date Utilities for Cohort Studies

**dateparse** provides utilities for date manipulation in Swedish registry-based cohort studies. It handles date parsing, window calculations, validation, and file range determination for year-split registry files.

### Subcommands

| Subcommand | Description |
|------------|-------------|
| `parse` | Parse date strings to Stata date format |
| `window` | Calculate lookback or followup windows from index dates |
| `validate` | Validate date ranges and calculate time spans |
| `inwindow` | Create binary indicators for dates within specified windows |
| `filerange` | Determine which year files are needed for a date range |

### Syntax

```stata
* Parse date strings
dateparse parse, datestring(string) [format(string)]

* Calculate windows
dateparse window varname, lookback(#) | followup(#) [generate(names) replace]

* Validate date range
dateparse validate, start(string) end(string) [format(string)]

* Check if dates in window
dateparse inwindow varname, start(string) end(string) generate(name) [replace]

* Determine file range
dateparse filerange, index_start(string) index_end(string) [lookback(#) followup(#)]
```

### Examples

```stata
* Calculate 1-year lookback window for comorbidity assessment
dateparse window indexdate, lookback(365) generate(comorb_start comorb_end)

* Determine which outpatient files to load
dateparse filerange, index_start("2015-01-01") index_end("2018-12-31") lookback(730)
display "Load files from " r(file_start_year) " to " r(file_end_year)
```

---

## migrations - Process Swedish Migration Registry Data

**migrations** processes Swedish migration registry data to identify exclusions and censoring dates for cohort studies. It handles the complex logic of determining residency status at study entry and identifying emigration events for survival analysis censoring.

### Syntax

```stata
migrations, migfile(filename) [options]
```

### Options

| Option | Description | Default |
|--------|-------------|---------|
| `migfile(filename)` | Path to migrations_wide.dta file | Required |
| `idvar(varname)` | ID variable | id |
| `startvar(varname)` | Study start date variable | study_start |
| `saveexclude(filename)` | Save excluded observations to file | - |
| `savecensor(filename)` | Save emigration censoring dates to file | - |
| `replace` | Replace existing files | - |
| `verbose` | Display processing messages | - |

### How It Works

**Exclusion Criteria:**

1. **Type 1 - Emigrated before study start**: Last emigration occurred before study start AND last immigration occurred before last emigration (person left Sweden and never returned)

2. **Type 2 - Not in Sweden at baseline**: Only migration record is an immigration after study start (person was not in Sweden at study entry)

**Censoring Logic:**

For individuals not excluded, the command identifies the first emigration date after study start as `migration_out_dt`, representing when the person left Sweden and should be censored from follow-up.

### Example

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

### Stored Results

| Scalar | Description |
|--------|-------------|
| `r(N_excluded_emigrated)` | Number excluded due to emigration before study start |
| `r(N_excluded_inmigration)` | Number excluded due to immigration after study start |
| `r(N_excluded_total)` | Total number excluded |
| `r(N_censored)` | Number with emigration censoring dates |
| `r(N_final)` | Final sample size after exclusions |

---

## procmatch - KVÅ Procedure Code Matching

**procmatch** provides utilities for working with KVÅ (Klassifikation av vårdåtgärder) procedure codes in Swedish health registries. It supports pattern matching against multiple procedure variables and extraction of first occurrence dates.

### Subcommands

| Subcommand | Description |
|------------|-------------|
| `match` | Create binary indicator for procedure code matches |
| `first` | Extract first occurrence date of matching procedures |

### Syntax

```stata
* Match procedures
procmatch match, codes(string) procvars(varlist) [generate(name) replace prefix noisily]

* Get first occurrence
procmatch first, codes(string) procvars(varlist) datevar(varname) idvar(varname) ///
    [generate(name) gendatevar(name) replace prefix noisily]
```

### Example

```stata
* Match bilateral oophorectomy procedures
use inpatient, clear
procmatch first, codes("LAE2 LAF1 LAF3") procvars(proc1-proc30) datevar(admitdt) ///
    idvar(id) generate(bilat_ooph) gendatevar(bilat_ooph_dt) prefix noisily
```

---

## sustainedss - Compute Sustained EDSS Progression

**sustainedss** computes sustained EDSS (Expanded Disability Status Scale) progression dates for multiple sclerosis research. An EDSS progression event is considered "sustained" if the disability level is maintained within a confirmation window.

### Syntax

```stata
sustainedss idvar edssvar datevar [if] [in], threshold(#) [options]
```

### Options

| Option | Description | Default |
|--------|-------------|---------|
| `threshold(#)` | EDSS threshold for progression | Required |
| `generate(newvar)` | Name for generated date variable | sustained#_dt |
| `confirmwindow(#)` | Confirmation window in days | 182 |
| `baselinethreshold(#)` | EDSS level for reversal check | 4 |
| `keepall` | Retain all observations | Keep only patients with events |
| `quietly` | Suppress iteration messages | - |

### Algorithm

1. Identifies the first date when EDSS reaches or exceeds the threshold
2. Examines EDSS measurements within the confirmation window
3. Rejects events where the lowest subsequent EDSS falls below baseline threshold AND the last EDSS in the window is below target threshold
4. For rejected events, replaces the EDSS value with the last observed value and repeats
5. Continues until all remaining events are confirmed as sustained

### Examples

```stata
* Basic usage
use edss_long, clear
sustainedss id edss edss_dt, threshold(4)

* Sustained EDSS 6 with custom variable name
sustainedss id edss edss_dt, threshold(6) generate(edss6_sustained)

* 3-month confirmation window
sustainedss id edss edss_dt, threshold(4) confirmwindow(90)
```

### Stored Results

| Scalar | Description |
|--------|-------------|
| `r(N_events)` | Number of sustained events identified |
| `r(iterations)` | Number of iterations required |
| `r(threshold)` | EDSS threshold used |
| `r(confirmwindow)` | Confirmation window in days |

---

## cdp - Confirmed Disability Progression

**cdp** computes confirmed disability progression (CDP) dates from longitudinal EDSS measurements. CDP is a standard outcome in MS clinical trials and observational studies.

### Definition

- **Baseline EDSS**: First measurement within 24 months of diagnosis (or earliest available)
- **Progression threshold**:
  - Baseline EDSS ≤5.5: requires ≥1.0 point increase
  - Baseline EDSS >5.5: requires ≥0.5 point increase
- **Confirmation**: Sustained at subsequent measurement ≥6 months later

### Syntax

```stata
cdp idvar edssvar datevar [if] [in], dxdate(varname) [options]
```

### Options

| Option | Description | Default |
|--------|-------------|---------|
| `dxdate(varname)` | Diagnosis date variable | Required |
| `generate(name)` | Name for CDP date variable | cdp_date |
| `confirmdays(#)` | Days for confirmation | 180 |
| `baselinewindow(#)` | Days from diagnosis for baseline | 730 |
| `roving` | Reset baseline after each progression | - |
| `allevents` | Track all CDP events (requires roving) | - |
| `keepall` | Retain all observations | - |

### Examples

```stata
* Basic CDP with 6-month confirmation
use edss_long, clear
cdp id edss edss_date, dxdate(ms_diagnosis_date)

* Track multiple progressions with roving baseline
cdp id edss edss_date, dxdate(dx_date) roving allevents keepall
```

---

## pira - Progression Independent of Relapse Activity

**pira** identifies confirmed disability progression events that occur outside of a window around relapses, indicating progression not attributable to acute relapse activity.

### Definition

- Runs CDP algorithm to identify confirmed progression
- Checks if progression falls within relapse window (default: 90 days before to 30 days after)
- **PIRA**: Progression outside relapse window
- **RAW**: Relapse-Associated Worsening (progression within relapse window)

### Syntax

```stata
pira idvar edssvar datevar [if] [in], dxdate(varname) relapses(filename) [options]
```

### Options

| Option | Description | Default |
|--------|-------------|---------|
| `dxdate(varname)` | Diagnosis date variable | Required |
| `relapses(filename)` | Path to relapse dataset | Required |
| `windowbefore(#)` | Days before relapse to exclude | 90 |
| `windowafter(#)` | Days after relapse to exclude | 30 |
| `generate(name)` | Name for PIRA date variable | pira_date |
| `rawgenerate(name)` | Name for RAW date variable | raw_date |
| `rebaselinerelapse` | Reset baseline after relapses | - |
| `confirmdays(#)` | Days for CDP confirmation | 180 |
| `keepall` | Retain all observations | - |

### Examples

```stata
* Basic PIRA analysis
pira id edss edss_date, dxdate(dx_date) relapses(relapses.dta)

* Lublin 2014 definition (30 days after relapse only)
pira id edss edss_date, dxdate(dx_date) relapses(relapses.dta) ///
    windowbefore(0) windowafter(30)

* Compare PIRA vs RAW
pira id edss edss_date, dxdate(dx_date) relapses(relapses.dta) keepall
gen progression_type = cond(!missing(pira_date), "PIRA", ///
    cond(!missing(raw_date), "RAW", "None"))
tab progression_type
```

### Stored Results

| Scalar | Description |
|--------|-------------|
| `r(N_cdp)` | Total CDP events |
| `r(N_pira)` | PIRA events |
| `r(N_raw)` | RAW events |

---

## tvage - Time-Varying Age Intervals

**tvage** creates a long-format dataset with time-varying age intervals for survival analysis. Each observation represents a period where an individual was at a specific age (or age group), enabling age-adjusted Cox models with time-varying age.

### Syntax

```stata
tvage, idvar(varname) dobvar(varname) entryvar(varname) exitvar(varname) ///
    [generate(name) startgen(name) stopgen(name) groupwidth(#) ///
     minage(#) maxage(#) saveas(filename) replace noisily]
```

### Example

```stata
* Create 5-year age groups for survival analysis
use cohort, clear
tvage, idvar(id) dobvar(dob) entryvar(study_entry) exitvar(study_exit) ///
    groupwidth(5) minage(40) maxage(80) saveas(age_tv) replace noisily
```

### Output

The command creates a dataset with:
- `age_tv` - Time-varying age or age group
- `age_start` - Start date of age interval
- `age_stop` - Stop date of age interval

---

## covarclose - Extract Closest Covariate Values

**covarclose** extracts covariate values from longitudinal/panel data at the observation closest to an index date. This is commonly needed when working with Swedish registries like LISA or RTB.

### Syntax

```stata
covarclose using filename, idvar(varname) indexdate(varname) ///
    datevar(string) vars(varlist) ///
    [yearformat impute prefer(string) missing(numlist) noisily]
```

### Options

| Option | Description |
|--------|-------------|
| `yearformat` | Date variable contains year values (not Stata dates) |
| `impute` | Fill missing values from adjacent observations |
| `prefer(before/after/closest)` | Which observation to prefer |
| `missing(numlist)` | Values to treat as missing (e.g., 99) |

### Example

```stata
* Extract education from LISA at study entry
use cohort, clear
covarclose using lisa, idvar(id) indexdate(study_start) ///
    datevar(year) vars(educ_lev_old) ///
    yearformat impute missing(99) prefer(closest) noisily
```

---

## Installation

Install directly from GitHub:

```stata
net from https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/setools
net install setools
```

## Requirements

- Stata 16.0 or higher
- No additional dependencies

## Related Packages

For comorbidity indices, consider:
- `charlson` from SSC (`ssc install charlson`)
- `elixhauser` from SSC

## Author

Timothy P Copeland
Department of Clinical Neuroscience
Karolinska Institutet

## License

MIT License

## Version

Version 1.3.0, 2025-12-17
