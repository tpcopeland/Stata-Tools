# tvtools Functionality Reference for LLM Consumption

**Purpose:** This document provides a comprehensive technical reference for the tvtools package, optimized for LLM parsing and technical writing. It is designed to help generate accurate technical appendices and methods sections based on .do files that use tvtools commands.

**Package:** tvtools - Time-varying exposure analysis for survival studies
**Version:** 1.0.0
**Date:** November 2025

---

## Overview

tvtools is a suite of three Stata commands for creating and managing time-varying exposure variables in survival analysis:

1. **tvexpose** - Creates time-varying exposure datasets from period-based exposure data
2. **tvmerge** - Merges multiple time-varying datasets with temporal alignment
3. **tvevent** - Integrates outcome events and competing risks into time-varying data

**Typical Workflow:**
```
Cohort data → tvexpose → [tvmerge (optional)] → tvevent → stset → Cox/Poisson regression
```

---

## Command 1: tvexpose

### Purpose
`tvexpose` transforms period-based exposure data (e.g., medication dispensing records) into time-varying exposure variables suitable for survival analysis. It creates one row per person-time period where exposure status changes.

### Required Parameters (No Defaults)

These parameters MUST be specified - the command will not run without them:

| Parameter | Purpose | Example |
|-----------|---------|---------|
| `using filename` | Path to exposure dataset containing exposure periods | `using hrt_prescriptions` |
| `id(varname)` | Person identifier linking master and exposure datasets | `id(patient_id)` |
| `start(varname)` | Variable in exposure dataset with period start dates | `start(rx_start)` |
| `exposure(varname)` | Categorical variable indicating exposure type/status | `exposure(drug_type)` |
| `reference(#)` | Value indicating unexposed/reference state | `reference(0)` |
| `entry(varname)` | Study entry date from master dataset | `entry(study_entry)` |
| `exit(varname)` | Study exit date from master dataset | `exit(study_exit)` |

**Note:** Either `stop(varname)` OR `pointtime` must also be specified (see Core Options below).

### Core Options

| Option | Choices | **DEFAULT** | Description |
|--------|---------|-------------|-------------|
| `stop(varname)` | any variable name | **REQUIRED unless pointtime specified** | End date of exposure period in using dataset. If not specified, `pointtime` must be used. |
| `pointtime` | flag (on/off) | **DEFAULT: off** | Indicates exposure data are point-in-time events rather than periods. When specified, `stop()` is not required. If not specified, `stop()` is required. |

### Exposure Definition Options

These options determine HOW the exposure variable is constructed. **If none are specified, DEFAULT behavior is basic time-varying exposure**.

| Option | Choices | **DEFAULT** | Description |
|--------|---------|-------------|-------------|
| `evertreated` | flag | **DEFAULT: off** | Creates binary 0/1 variable that switches permanently at first exposure. If not specified, creates standard categorical time-varying exposure. |
| `currentformer` | flag | **DEFAULT: off** | Creates trichotomous variable: 0=never, 1=current, 2=former. If not specified, exposure reflects actual periods only. |
| `duration(numlist)` | list of cutpoints | **DEFAULT: not used** | Creates categorical variable based on cumulative duration. Values define category boundaries in units specified by `continuousunit()` (defaults to years). If not specified, duration categories are not created. Example: `duration(1 5)` creates categories <1 year, 1-<5 years, ≥5 years. |
| `continuousunit(unit)` | days, weeks, months, quarters, years | **DEFAULT: years** | Unit for cumulative exposure calculation. Only used with `duration()`, `expandunit()`, or `bytype`. If not specified and duration/continuous exposure requested, years are used. |
| `expandunit(unit)` | days, weeks, months, quarters, years | **DEFAULT: not used** | Splits person-time into rows at regular calendar intervals. If not specified, rows span entire exposure periods without splitting. |
| `bytype` | flag | **DEFAULT: off** | Creates separate variables for each exposure type instead of single variable. If not specified, one variable contains all exposure types. |
| `recency(numlist)` | list of cutpoints in years | **DEFAULT: not used** | Creates categories based on time since last exposure. If not specified, recency is not tracked. |

**Technical note:** Only ONE exposure definition option should typically be used. Combining multiple options (e.g., `evertreated` with `duration()`) may produce unexpected results.

### Data Handling Options

| Option | Choices | **DEFAULT** | Description |
|--------|---------|-------------|-------------|
| `grace(#)` or `grace(exp=#...)` | number of days OR exposure-specific days | **DEFAULT: 0** | Days to merge small gaps between periods. Single number applies to all exposures. Exposure-specific syntax: `grace(1=30 2=60)` applies 30 days to type 1, 60 to type 2. If not specified, gaps are not filled. |
| `merge(#)` | number of days | **DEFAULT: 120** | Days within which same-type periods are merged. If not specified, uses 120-day window. |
| `fillgaps(#)` | number of days | **DEFAULT: not used** | Assumes exposure continues # days beyond last stop date. If not specified, exposure ends at recorded stop date. |
| `carryforward(#)` | number of days | **DEFAULT: not used** | Carries last exposure forward through gaps up to # days. If not specified, gaps show reference exposure. |

### Competing Exposures Options

When multiple exposures overlap, these options control which takes precedence. **DEFAULT is layer behavior**.

| Option | Choices | **DEFAULT** | Description |
|--------|---------|-------------|-------------|
| `layer` | flag | **DEFAULT: active** | Later exposures take precedence; earlier resume after. This is the default behavior if no competing exposure option specified. |
| `priority(numlist)` | ordered list of exposure values | **DEFAULT: not used** | Specifies priority order (highest first). Example: `priority(2 1 0)` gives type 2 highest priority. If not specified, layer behavior is used. |
| `split` | flag | **DEFAULT: off** | Creates separate rows for each combination when periods overlap. If not specified, layer or priority rules apply. |
| `combine(newvar)` | variable name | **DEFAULT: not used** | Creates additional variable showing combined exposure during overlaps. If not specified, no combined variable created. |

**Technical note:** `layer`, `priority()`, and `split` are mutually exclusive. Only one should be specified.

### Lag and Washout Options

| Option | Choices | **DEFAULT** | Description |
|--------|---------|-------------|-------------|
| `lag(#)` | number of days | **DEFAULT: 0** | Days before exposure becomes active after start date. If not specified, exposure begins immediately at start date. |
| `washout(#)` | number of days | **DEFAULT: 0** | Days exposure persists after stop date. If not specified, exposure ends at stop date. |
| `window(# #)` | min and max days | **DEFAULT: not used** | Only counts exposures lasting between min and max days. If not specified, all exposure durations included. |

### Output Options

| Option | Choices | **DEFAULT** | Description |
|--------|---------|-------------|-------------|
| `generate(newvar)` | variable name | **DEFAULT: tv_exposure** | Name for output exposure variable. If not specified, creates variable named `tv_exposure`. |
| `referencelabel(text)` | any text | **DEFAULT: "Unexposed"** | Label for reference category. If not specified, uses "Unexposed". |
| `label(text)` | any text | **DEFAULT: from original variable** | Custom variable label. If not specified, uses label from original exposure variable. For `currentformer` without custom label, defaults to "Never/current/former exposure". |
| `saveas(filename)` | .dta filename | **DEFAULT: not saved** | Saves output to file. If not specified, data remains in memory only. |
| `replace` | flag | **DEFAULT: off** | Allows overwriting existing file with `saveas()`. If not specified, error if file exists. |
| `keepvars(varlist)` | list of variables | **DEFAULT: only id, dates, exposure** | Additional variables from master dataset to keep. If not specified, only essential variables retained. |
| `keepdates` | flag | **DEFAULT: off** | Retains entry and exit dates in output. If not specified, these dates are dropped. |

### Common Usage Patterns

**Pattern 1: Basic time-varying exposure**
```stata
tvexpose using medications, id(id) start(rx_start) stop(rx_stop) ///
    exposure(drug_type) reference(0) ///
    entry(study_entry) exit(study_exit)
// Creates: tv_exposure variable with drug_type values during exposure periods, 0 during unexposed periods
```

**Pattern 2: Ever-treated analysis**
```stata
tvexpose using medications, id(id) start(rx_start) stop(rx_stop) ///
    exposure(drug_type) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    evertreated generate(ever_treated)
// Creates: ever_treated = 0 before first exposure, 1 from first exposure onward (permanent switch)
```

**Pattern 3: Duration categories**
```stata
tvexpose using medications, id(id) start(rx_start) stop(rx_stop) ///
    exposure(drug_type) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    duration(1 5) continuousunit(years)
// Creates: Categories based on cumulative years: 0=unexposed, 1=<1yr, 2=1-<5yr, 3=≥5yr
// DEFAULT unit is years, explicitly specified here for clarity
```

---

## Command 2: tvmerge

### Purpose
`tvmerge` merges multiple time-varying datasets created by `tvexpose`, creating all possible combinations of overlapping exposure periods (Cartesian product). Used when analyzing multiple exposures simultaneously.

### Required Parameters (No Defaults)

| Parameter | Purpose | Example |
|-----------|---------|---------|
| `dataset1 dataset2 [dataset3...]` | Names of tvexpose output files to merge | `tvmerge tv_hrt tv_dmt` |
| `id(varname)` | Person identifier present in all datasets | `id(patient_id)` |
| `start(namelist)` | Start variables (one per dataset, in order) | `start(rx_start dmt_start)` |
| `stop(namelist)` | Stop variables (one per dataset, in order) | `stop(rx_stop dmt_stop)` |
| `exposure(namelist)` | Exposure variables (one per dataset, in order) | `exposure(tv_exposure tv_exposure)` |

**Technical note:** The number of names in `start()`, `stop()`, and `exposure()` must match the number of datasets specified.

### Exposure Type Options

| Option | Choices | **DEFAULT** | Description |
|--------|---------|-------------|-------------|
| `continuous(namelist)` | variable names or positions (1,2,3) | **DEFAULT: all categorical** | Specifies which exposures are continuous (rates per day). If not specified, all exposures treated as categorical. For continuous exposures, creates two variables: `varname` (rate) and `varname_period` (amount in that period). |

### Output Naming Options

| Option | Choices | **DEFAULT** | Description |
|--------|---------|-------------|-------------|
| `generate(namelist)` | new variable names (one per dataset) | **DEFAULT: exp1, exp2, exp3...** | Custom names for output exposure variables. If not specified, creates exp1, exp2, etc. Mutually exclusive with `prefix()`. |
| `prefix(string)` | text prefix | **DEFAULT: not used** | Prefix for all output variables (e.g., `prefix(tx_)` creates tx_1, tx_2). If not specified and `generate()` not specified, uses exp1, exp2, etc. Mutually exclusive with `generate()`. |
| `startname(string)` | variable name | **DEFAULT: start** | Name for output start date variable. If not specified, uses "start". |
| `stopname(string)` | variable name | **DEFAULT: stop** | Name for output stop date variable. If not specified, uses "stop". |
| `dateformat(fmt)` | Stata date format | **DEFAULT: %tdCCYY/NN/DD** | Date format for output dates. If not specified, uses YYYY/MM/DD format. |

### Data Management Options

| Option | Choices | **DEFAULT** | Description |
|--------|---------|-------------|-------------|
| `saveas(filename)` | .dta filename | **DEFAULT: not saved** | Saves merged dataset to file. If not specified, data remains in memory only. |
| `replace` | flag | **DEFAULT: off** | Allows overwriting with `saveas()`. If not specified, error if file exists. |
| `keep(varlist)` | variable names | **DEFAULT: only id, dates, exposures** | Additional variables from source datasets (suffixed with _ds#). If not specified, only essential variables retained. |

### Performance Options

| Option | Choices | **DEFAULT** | Description |
|--------|---------|-------------|-------------|
| `batch(#)` | 1-100 (percentage) | **DEFAULT: 20** | Percentage of unique IDs processed per batch. If not specified, processes 20% at a time. Larger values (e.g., 50) are faster but use more memory. Smaller values (e.g., 10) use less memory but are slower. |

**Technical note:** For a dataset with 10,000 IDs, `batch(20)` processes 2,000 IDs per batch (5 batches total), dramatically reducing I/O operations compared to processing one ID at a time.

### Common Usage Patterns

**Pattern 1: Basic two-dataset merge**
```stata
tvmerge tv_hrt tv_dmt, id(id) ///
    start(rx_start dmt_start) stop(rx_stop dmt_stop) ///
    exposure(tv_exposure tv_exposure) ///
    generate(hrt dmt_type)
// Creates: Dataset with all combinations of overlapping HRT and DMT periods
// Variables: id, start, stop, hrt, dmt_type
// DEFAULT: Both exposures treated as categorical
```

**Pattern 2: Merge with continuous exposure**
```stata
tvmerge tv_drug tv_dosage, id(id) ///
    start(start start) stop(stop stop) ///
    exposure(drug dosage_rate) ///
    continuous(dosage_rate) ///
    generate(drug_type dosage)
// Creates: drug_type (categorical), dosage (rate per day), dosage_period (total in period)
// If continuous() not specified, dosage_rate would be treated as categorical
```

---

## Command 3: tvevent

### Purpose
`tvevent` integrates outcome events and competing risks into time-varying datasets created by `tvexpose` or `tvmerge`. It splits intervals when events occur mid-period and flags event status.

### Required Parameters (No Defaults)

| Parameter | Purpose | Example |
|-----------|---------|---------|
| `using filename` | Dataset containing event dates | `using cohort` |
| `id(varname)` | Person identifier | `id(patient_id)` |
| `date(varname)` | Primary event date variable in using dataset | `date(outcome_date)` |

**Critical requirement:** Master dataset (in memory) MUST contain variables named `start` and `stop` (created by `tvexpose` or `tvmerge`).

### Competing Risks Options

| Option | Choices | **DEFAULT** | Description |
|--------|---------|-------------|-------------|
| `compete(varlist)` | list of date variables | **DEFAULT: no competing risks** | Date variables for competing risks in using dataset. If not specified, only primary event considered. Order matters: first variable = status 2, second = status 3, etc. |

**Technical note:** Competing risk dates are compared with primary `date()`. Earliest occurring date determines event status for that person.

### Event Definition Options

| Option | Choices | **DEFAULT** | Description |
|--------|---------|-------------|-------------|
| `type(string)` | single, recurring | **DEFAULT: single** | Event logic. If not specified, uses "single" (first event is terminal, drops all follow-up after). "recurring" allows multiple events and retains all follow-up. |
| `generate(newvar)` | variable name | **DEFAULT: _failure** | Name for event status variable. If not specified, creates `_failure`. Coded as: 0=censored, 1=primary event, 2+=competing events. |
| `continuous(varlist)` | variable names | **DEFAULT: no adjustment** | Cumulative variables to adjust proportionally when splitting intervals. If not specified, continuous variables are not adjusted when intervals split. Example: total dose variables. |
| `eventlabel(string)` | value-label pairs | **DEFAULT: from variable labels** | Custom labels for event categories. If not specified, uses: 0="Censored", 1=label of `date()` variable, 2+=labels of `compete()` variables. Syntax: `eventlabel(0 "Alive" 1 "Heart Failure" 2 "Death")`. |

### Time Generation Options

| Option | Choices | **DEFAULT** | Description |
|--------|---------|-------------|-------------|
| `timegen(newvar)` | variable name | **DEFAULT: not created** | Creates variable with interval duration. If not specified, no duration variable created. |
| `timeunit(string)` | days, months, years | **DEFAULT: days** | Unit for `timegen()`. If not specified and `timegen()` used, duration in days. |

### Data Handling Options

| Option | Choices | **DEFAULT** | Description |
|--------|---------|-------------|-------------|
| `keepvars(varlist)` | variable names | **DEFAULT: only event indicator** | Additional variables from using dataset to keep. If not specified, only event status variable added. These populate only on rows where event occurred. |
| `replace` | flag | **DEFAULT: off** | Replace output variables if exist. If not specified, error if variables exist. |

**Technical note:** All variables from master dataset (in memory before `tvevent`) are kept automatically. `keepvars()` specifies ADDITIONAL variables from the using (event) dataset.

### How tvevent Works

1. **Event date resolution:** Compares `date()` and all `compete()` dates; earliest becomes effective event date
2. **Interval splitting:** If event occurs during an interval (start < event < stop), splits into pre-event and post-event periods
3. **Continuous adjustment:** If `continuous()` specified, adjusts cumulative variables by ratio (new duration / old duration)
4. **Status flagging:** Creates `generate()` variable coded as 0=censored, 1=primary, 2+=competing
5. **Post-event handling:** If `type(single)`, drops all data after first event; if `type(recurring)`, retains all data

### Common Usage Patterns

**Pattern 1: Single outcome with competing risk**
```stata
tvevent using cohort, id(id) date(outcome_dt) compete(death_dt)
// Creates: _failure = 0 (censored), 1 (outcome), 2 (death)
// DEFAULT: type(single) - drops all follow-up after first event
// DEFAULT: generate(_failure) - creates variable named _failure
```

**Pattern 2: Custom labels and variable name**
```stata
tvevent using cohort, id(id) date(edss4_dt) compete(death_dt) ///
    generate(outcome) ///
    eventlabel(0 "Alive" 1 "EDSS 4" 2 "Death")
// Creates: outcome variable with custom labels
// If eventlabel() not specified, would use variable labels from cohort dataset
```

**Pattern 3: Continuous variable adjustment**
```stata
tvevent using cohort, id(id) date(outcome_dt) ///
    continuous(cumulative_dose cumulative_years)
// Adjusts cumulative variables when intervals split
// If continuous() not specified, these variables would not be adjusted
```

---

## Complete Workflow Example

```stata
* Step 1: Create time-varying HRT dataset
use cohort, clear
tvexpose using hrt, id(id) start(rx_start) stop(rx_stop) ///
    exposure(hrt_type) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    saveas(tv_hrt.dta) replace
// Creates: tv_hrt.dta with variables: id, start, stop, tv_exposure
// DEFAULT exposure definition: basic time-varying (no evertreated, duration, etc.)

* Step 2: Create time-varying DMT dataset
use cohort, clear
tvexpose using dmt, id(id) start(dmt_start) stop(dmt_stop) ///
    exposure(dmt) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    saveas(tv_dmt.dta) replace
// Creates: tv_dmt.dta with same structure

* Step 3: Merge the two time-varying datasets
tvmerge tv_hrt tv_dmt, id(id) ///
    start(rx_start dmt_start) stop(rx_stop dmt_stop) ///
    exposure(tv_exposure tv_exposure) ///
    generate(hrt dmt_type)
// Creates: All combinations of overlapping HRT and DMT periods
// DEFAULT: batch(20) - processes 20% of IDs per batch
// DEFAULT: Both exposures categorical (continuous() not specified)

* Step 4: Integrate event data
tvevent using cohort, id(id) date(edss4_dt) compete(death_dt) ///
    generate(outcome)
// Creates: outcome = 0 (censored), 1 (EDSS4), 2 (death)
// DEFAULT: type(single) - drops follow-up after event
// Splits intervals if event occurs mid-period

* Step 5: Declare survival data and analyze
stset stop, id(id) failure(outcome==1) enter(start)
stcrreg i.hrt i.dmt_type, compete(outcome==2)
```

---

## Decision Tree for Option Selection

### tvexpose exposure definition:
- **Research question: Ever vs never exposed?** → Use `evertreated`
- **Research question: Current vs former vs never?** → Use `currentformer`
- **Research question: Dose-response by duration?** → Use `duration()` with cutpoints
- **Research question: Continuous duration effect?** → Use `continuousunit()` alone
- **Research question: Time since exposure?** → Use `recency()`
- **Research question: Basic time-varying exposure?** → Use no exposure definition option (DEFAULT)

### tvmerge exposure types:
- **Exposure is a rate or amount per day?** → Specify in `continuous()`
- **Exposure is categorical?** → Do not use `continuous()` (DEFAULT)

### tvevent event type:
- **Event can only occur once?** → Use `type(single)` or omit (DEFAULT)
- **Event can recur?** → Use `type(recurring)`

### tvevent competing risks:
- **Only one type of outcome?** → Only specify `date()`, omit `compete()`
- **Multiple competing outcomes?** → Specify all in `compete()`, earliest wins

---

## Technical Notes

### Performance Considerations
- `tvexpose` with `expandunit()` can dramatically increase dataset size
- `tvmerge` creates Cartesian products; N rows can become N×M×P for multiple exposures
- `tvmerge batch()` option significantly improves performance for large datasets
- **Rule of thumb:** batch(50) for <10,000 IDs, batch(20) for 10,000-50,000, batch(10) for >50,000

### Data Requirements
- All date variables must be Stata numeric dates (not strings)
- `tvexpose` requires: start < stop for valid periods
- `tvmerge` requires: master data already processed by `tvexpose`
- `tvevent` requires: variables named `start` and `stop` in memory

### Common Pitfalls
1. **Using tvmerge on raw data:** Must use tvexpose first
2. **Forgetting reference():** Required parameter in tvexpose
3. **Wrong batch size:** Too small = slow, too large = memory issues
4. **Combining incompatible options:** e.g., `evertreated` with `duration()`

### Variable Naming Conventions
- tvexpose DEFAULT output: `tv_exposure`
- tvmerge DEFAULT output: `exp1`, `exp2`, etc. OR use `generate()` for custom names
- tvevent DEFAULT output: `_failure`
- All defaults can be overridden with `generate()` option

---

**Document Version:** 1.0
**Last Updated:** November 2025
**For:** Technical appendix generation and methods section writing based on tvtools usage
