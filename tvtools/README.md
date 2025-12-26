# tvtools

![Stata 16+](https://img.shields.io/badge/Stata-16%2B-brightgreen) ![MIT License](https://img.shields.io/badge/License-MIT-blue) ![Status](https://img.shields.io/badge/Status-Active-success)

Comprehensive toolkit for time-varying exposure analysis in survival studies.

## Package Overview

**tvtools** provides three integrated commands for creating and analyzing time-varying exposure data in survival analysis:

1. **tvexpose** - Create time-varying exposure variables from period-based exposure data
2. **tvmerge** - Merge multiple time-varying exposure datasets with temporal alignment
3. **tvevent** - Integrate events and competing risks into time-varying datasets

### Typical Workflow

```
Raw exposure data
        ↓
    tvexpose  ←──────────── Create time-varying exposure variables
        ↓
   [tvmerge]  ←──────────── Merge multiple exposures (optional)
        ↓
    tvevent   ←──────────── Integrate events and competing risks
        ↓
     stset    ←──────────── Declare survival-time data
        ↓
  stcox/streg ←──────────── Survival analysis
```

### Key Features

- **Comprehensive exposure definitions**: Basic time-varying, ever-treated, current/former, duration categories, continuous cumulative, recency, dose tracking
- **Advanced data handling**: Grace periods, gap filling, overlap resolution, lag/washout periods
- **Flexible merging**: Cartesian product temporal matching, continuous vs categorical exposures, batch processing
- **Competing risks support**: Multiple competing events, automatic interval splitting, custom event labels
- **Validation tools**: Coverage diagnostics, gap detection, overlap checking, summary statistics
- **Performance optimized**: Batch processing for large datasets, efficient memory management

---

## Installation

```stata
net install tvtools, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/tvtools")
```

### Optional: Menu Setup Script

To get the menu setup script (adds tvtools to Stata's User menu):

```stata
net get tvtools, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/tvtools")
do tvtools_menu_setup.do
```

Note: `net install` installs program files (.ado, .sthlp, .dlg). Use `net get` to download ancillary files like .do scripts to your current working directory.

---

## tvexpose - Create Time-Varying Exposure Variables

**tvexpose** creates time-varying exposure variables suitable for survival analysis from a dataset containing exposure periods. It merges exposure data with a master cohort dataset, creating periods where exposure status changes over time.

### Syntax

```stata
tvexpose using filename,
    id(varname)
    start(varname)
    exposure(varname)
    reference(#)
    entry(varname)
    exit(varname)
    [options]
```

### Required Options

| Option | Description |
|--------|-------------|
| `using filename` | Dataset containing exposure periods |
| `id(varname)` | Person identifier linking to master dataset |
| `start(varname)` | Start date of exposure period in using dataset |
| `exposure(varname)` | Categorical exposure status variable |
| `reference(#)` | Value indicating unexposed/reference status (typically 0) |
| `entry(varname)` | Study entry date from master dataset |
| `exit(varname)` | Study exit date from master dataset |

### Core Options

| Option | Description | Default |
|--------|-------------|---------|
| `stop(varname)` | End date of exposure period | Required unless `pointtime` specified |
| `pointtime` | Data are point-in-time (start only, no stop date) | — |

### Exposure Definition Options

| Option | Description | Default |
|--------|-------------|---------|
| *[none specified]* | Basic time-varying implementation of exposures | Default |
| `evertreated` | Binary ever/never exposed (switches at first exposure) | — |
| `currentformer` | Trichotomous: 0=never, 1=current, 2=former | — |
| `duration(numlist)` | Cumulative duration categories (cutpoints) | Years if `continuousunit` not specified |
| `continuousunit(unit)` | Continuous cumulative exposure in: days, weeks, months, quarters, years | — |
| `expandunit(unit)` | Row expansion granularity: days, weeks, months, quarters, years | — |
| `bytype` | Create separate variables for each exposure type | Single variable |
| `recency(numlist)` | Time since last exposure categories (cutpoints in years) | — |
| `dose` | Cumulative dose tracking (exposure contains dose amounts) | — |
| `dosecuts(numlist)` | Cutpoints for dose categorization (use with `dose`) | — |

### Data Handling Options

| Option | Description | Default |
|--------|-------------|---------|
| `grace(#)` | Days grace period to merge gaps | 0 (no merging) |
| `grace(exp=# exp=# ...)` | Different grace periods by exposure category | — |
| `merge(#)` | Days within which to merge same-type periods | 120 |
| `fillgaps(#)` | Assume exposure continues # days beyond last record | — |
| `carryforward(#)` | Carry forward last exposure # days through gaps | — |

### Competing Exposures Options

| Option | Description | Default |
|--------|-------------|---------|
| `layer` | Later exposures take precedence; earlier resume after | Default |
| `priority(numlist)` | Priority order when periods overlap (highest first) | — |
| `split` | Split overlapping periods at all boundaries | — |
| `combine(newvar)` | Create combined exposure variable for overlaps | — |

### Lag and Washout Options

| Option | Description | Default |
|--------|-------------|---------|
| `lag(#)` | Days lag before exposure becomes active | 0 |
| `washout(#)` | Days exposure persists after stopping | 0 |
| `window(# #)` | Minimum and maximum days for acute exposure window | — |

### Pattern Tracking Options

| Option | Description | Default |
|--------|-------------|---------|
| `switching` | Create binary indicator for any exposure switching | — |
| `switchingdetail` | Create string variable showing switching pattern | — |
| `statetime` | Create cumulative time in current exposure state | — |

### Output Options

| Option | Description | Default |
|--------|-------------|---------|
| `generate(newvar)` | Name for output exposure variable | tv_exposure |
| `referencelabel(text)` | Label for reference category | "Unexposed" |
| `label(text)` | Custom variable label for output exposure variable | Derived from source |
| `saveas(filename)` | Save time-varying dataset to file | — |
| `replace` | Overwrite existing output file | — |
| `keepvars(varlist)` | Additional variables from master dataset | — |
| `keepdates` | Keep entry and exit dates in output | Drop dates |

### Diagnostic Options

| Option | Description |
|--------|-------------|
| `check` | Display coverage diagnostics by person |
| `gaps` | Show persons with gaps in coverage |
| `overlaps` | Show overlapping exposure periods |
| `summarize` | Display exposure distribution summary |
| `validate` | Create validation dataset with coverage metrics |

### Examples

#### Example 1: Basic Time-Varying Exposure

Create categorical time-varying HRT exposure:

```stata
use cohort, clear

tvexpose using hrt, id(id) start(rx_start) stop(rx_stop) ///
    exposure(hrt_type) reference(0) ///
    entry(study_entry) exit(study_exit)
```

Creates `tv_exposure` showing HRT type (0=unexposed, 1-3=HRT types) during each time period.

#### Example 2: Ever-Treated Analysis

Create binary indicator that switches permanently at first exposure:

```stata
use cohort, clear

tvexpose using hrt, id(id) start(rx_start) stop(rx_stop) ///
    exposure(hrt_type) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    evertreated generate(ever_hrt)
```

Variable `ever_hrt` = 0 before first exposure, = 1 from first exposure onward. Useful for correcting immortal time bias.

#### Example 3: Current vs Former Exposure

Distinguish between current and former DMT exposure:

```stata
use cohort, clear

tvexpose using dmt, id(id) start(dmt_start) stop(dmt_stop) ///
    exposure(dmt) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    currentformer generate(dmt_status)
```

Variable `dmt_status`: 0=never exposed, 1=currently on DMT, 2=formerly on DMT.

#### Example 4: Duration Categories

Create exposure categories based on cumulative years of HRT use:

```stata
use cohort, clear

tvexpose using hrt, id(id) start(rx_start) stop(rx_stop) ///
    exposure(hrt_type) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    duration(1 5 10) continuousunit(years)
```

Creates categories: 0=unexposed, 1=<1 year, 2=1 to <5 years, 3=5 to <10 years, 4=≥10 years.

#### Example 5: Continuous Cumulative Exposure

Track cumulative months of DMT exposure as a continuous variable:

```stata
use cohort, clear

tvexpose using dmt, id(id) start(dmt_start) stop(dmt_stop) ///
    exposure(dmt) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    continuousunit(months) generate(cumul_dmt_months)
```

Use in regression models as a continuous predictor.

#### Example 6: Grace Period for Gaps

Treat gaps ≤30 days as continuous HRT exposure:

```stata
use cohort, clear

tvexpose using hrt, id(id) start(rx_start) stop(rx_stop) ///
    exposure(hrt_type) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    grace(30) currentformer
```

Useful when short gaps represent prescription refill delays rather than true cessation.

#### Example 7: Separate Variables by Type

Create separate time-varying variables for each DMT type:

```stata
use cohort, clear

tvexpose using dmt, id(id) start(dmt_start) stop(dmt_stop) ///
    exposure(dmt) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    continuousunit(years) bytype
```

Creates `tv_exp1` through `tv_exp6` showing cumulative years on each specific DMT type.

#### Example 8: Cumulative Dose Tracking

Track cumulative medication dose for dose-response analysis:

```stata
use cohort, clear

tvexpose using hrt, id(id) start(rx_start) stop(rx_stop) ///
    exposure(dose) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    dose generate(cumul_dose)
```

Creates `cumul_dose` showing cumulative dose at each time point. When prescriptions overlap, dose is allocated proportionally based on daily dose rates.

#### Example 9: Categorical Dose for Dose-Response

Create categorical cumulative dose for dose-response analysis:

```stata
use cohort, clear

tvexpose using hrt, id(id) start(rx_start) stop(rx_stop) ///
    exposure(dose) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    dose dosecuts(5 10 20) generate(dose_cat)
```

Creates `dose_cat` with categories: 0=no dose, 1=<5, 2=5-<10, 3=10-<20, 4=20+.

#### Example 10: Complete Workflow for Survival Analysis

Full analysis pipeline from time-varying exposure to Cox regression:

```stata
use cohort, clear

tvexpose using dmt, id(id) start(dmt_start) stop(dmt_stop) ///
    exposure(dmt) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    currentformer generate(dmt_status) ///
    keepvars(age female mstype edss_baseline)

* Define failure event
gen failure = (!missing(edss4_dt) & edss4_dt <= rx_stop)

* Declare survival-time data
stset rx_stop, failure(failure) entry(rx_start) id(id) scale(365.25)

* Estimate hazard ratios
stcox i.dmt_status age i.female i.mstype edss_baseline
```

### Remarks

**Choice of Exposure Definition:**

- **[No option specified]**: For basic time-varying implementation of exposures
- **evertreated**: For intent-to-treat analyses or immortal time bias correction
- **currentformer**: For distinguishing active vs past exposure effects
- **duration()**: For dose-response by cumulative duration
- **continuousunit()**: For continuous dose-response models
- **recency()**: For time-since-exposure effects

**Performance Considerations:**

For very large cohorts or complex exposure patterns, `tvexpose` may take several minutes. The `expandunit()` option can dramatically increase output size when splitting into fine time units. Consider using coarser units (months instead of days) when fine granularity is not needed.

**Important Notes:**

- `tvexpose` modifies the data in memory and changes the sort order to id-start-stop
- Always preserve your data or work with copies
- The output is long-format with one row per person-time period
- Compatible with `stset` and `stcox` for survival analysis

### Stored Results

`tvexpose` stores the following in `r()`:

| Scalar | Description |
|--------|-------------|
| `r(N_persons)` | Number of unique persons |
| `r(N_periods)` | Number of time-varying periods |
| `r(total_time)` | Total person-time in days |
| `r(exposed_time)` | Exposed person-time in days |
| `r(unexposed_time)` | Unexposed person-time in days |
| `r(pct_exposed)` | Percentage of time exposed |

---

## tvmerge - Merge Multiple Time-Varying Datasets

**tvmerge** merges multiple time-varying exposure datasets created by `tvexpose`. Unlike standard Stata `merge`, it performs time-interval matching and creates new time intervals representing the intersections of exposure periods.

### Syntax

```stata
tvmerge dataset1 dataset2 [dataset3 ...],
    id(varname)
    start(namelist)
    stop(namelist)
    exposure(namelist)
    [options]
```

### Required Options

| Option | Description |
|--------|-------------|
| `id(varname)` | Person identifier variable present in all datasets |
| `start(namelist)` | Start date variables (one per dataset, in order) |
| `stop(namelist)` | Stop date variables (one per dataset, in order) |
| `exposure(namelist)` | Exposure variables (one per dataset, in order) |

### Exposure Type Options

| Option | Description | Default |
|--------|-------------|---------|
| `continuous(namelist)` | Specify which exposures are continuous (rates per day) | Categorical |

**Note:** For continuous exposures, two variables are created: one for the rate per day and one (`_period` suffix) for the period-specific exposure amount.

### Output Naming Options

| Option | Description | Default |
|--------|-------------|---------|
| `generate(namelist)` | New names for exposure variables (one per dataset) | exp1, exp2, ... |
| `prefix(string)` | Prefix for all exposure variable names | — |
| `startname(string)` | Name for output start date variable | start |
| `stopname(string)` | Name for output stop date variable | stop |
| `dateformat(fmt)` | Stata date format for output dates | %tdCCYY/NN/DD |

**Note:** `generate()` and `prefix()` are mutually exclusive.

### Data Management Options

| Option | Description | Default |
|--------|-------------|---------|
| `saveas(filename)` | Save merged dataset to file | — |
| `replace` | Overwrite existing file | — |
| `keep(varlist)` | Additional variables to keep from source datasets (suffixed with _ds#) | — |

### Diagnostic Options

| Option | Description |
|--------|-------------|
| `check` | Display coverage diagnostics |
| `validatecoverage` | Verify all person-time accounted for (check for gaps) |
| `validateoverlap` | Verify overlapping periods make sense |
| `summarize` | Display summary statistics of start/stop dates |

### Performance Options

| Option | Description | Default |
|--------|-------------|---------|
| `batch(#)` | Process IDs in batches (percentage of total IDs per batch: 1-100) | 20 |

**Batch Processing:**
- **Larger batches** (e.g., 50): Faster but uses more memory. Good for <10,000 IDs.
- **Smaller batches** (e.g., 10): Slower but uses less memory. Good for >50,000 IDs.
- **Default (20)**: Good balance for most use cases.

For a dataset with 10,000 unique IDs, batch processing reduces I/O operations from 10,000 to 5 batches, resulting in 10-50x faster execution.

### Examples

#### Example 1: Basic Two-Dataset Merge

**CRITICAL PREREQUISITE:** First create time-varying datasets using `tvexpose`:

```stata
* Step 1: Create time-varying HRT dataset
use cohort, clear
tvexpose using hrt, id(id) start(rx_start) stop(rx_stop) ///
    exposure(hrt_type) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    saveas(tv_hrt.dta) replace

* Step 2: Create time-varying DMT dataset
use cohort, clear
tvexpose using dmt, id(id) start(dmt_start) stop(dmt_stop) ///
    exposure(dmt) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    saveas(tv_dmt.dta) replace

* Step 3: Merge the two time-varying datasets
tvmerge tv_hrt tv_dmt, id(id) ///
    start(rx_start dmt_start) stop(rx_stop dmt_stop) ///
    exposure(tv_exposure tv_exposure)
```

Output contains one row for each unique combination of overlapping HRT and DMT periods. Variables `exp1` (HRT type) and `exp2` (DMT type) show exposure status during each interval.

#### Example 2: Merge with Custom Variable Names

```stata
* Create time-varying datasets (same as Example 1)
use cohort, clear
tvexpose using hrt, id(id) start(rx_start) stop(rx_stop) ///
    exposure(hrt_type) reference(0) ///
    entry(study_entry) exit(study_exit) saveas(tv_hrt.dta) replace

use cohort, clear
tvexpose using dmt, id(id) start(dmt_start) stop(dmt_stop) ///
    exposure(dmt) reference(0) ///
    entry(study_entry) exit(study_exit) saveas(tv_dmt.dta) replace

* Merge with meaningful variable names
tvmerge tv_hrt tv_dmt, id(id) ///
    start(rx_start dmt_start) stop(rx_stop dmt_stop) ///
    exposure(tv_exposure tv_exposure) ///
    generate(hrt dmt_type) ///
    startname(period_start) stopname(period_end)
```

Output variables are named `hrt`, `dmt_type`, `period_start`, and `period_end`.

#### Example 3: Keep Additional Covariates

When running `tvexpose`, use `keepvars()` to bring covariates into the time-varying datasets:

```stata
use cohort, clear
tvexpose using hrt, id(id) start(rx_start) stop(rx_stop) ///
    exposure(hrt_type) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    keepvars(age female) saveas(tv_hrt.dta) replace

use cohort, clear
tvexpose using dmt, id(id) start(dmt_start) stop(dmt_stop) ///
    exposure(dmt) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    keepvars(mstype edss_baseline) saveas(tv_dmt.dta) replace

* Merge and keep the covariates from both datasets
tvmerge tv_hrt tv_dmt, id(id) ///
    start(rx_start dmt_start) stop(rx_stop dmt_stop) ///
    exposure(tv_exposure tv_exposure) ///
    keep(age female mstype edss_baseline) ///
    generate(hrt dmt_type)
```

Output includes `age_ds1`, `female_ds1` (from HRT), `mstype_ds2`, `edss_baseline_ds2` (from DMT), plus `id`, `start`, `stop`, `hrt`, and `dmt_type`.

#### Example 4: Diagnostics and Validation

```stata
tvmerge tv_hrt tv_dmt, id(id) ///
    start(rx_start dmt_start) stop(rx_stop dmt_stop) ///
    exposure(tv_exposure tv_exposure) ///
    check validatecoverage validateoverlap summarize
```

- `check`: Shows persons merged, average periods per person, maximum periods
- `validatecoverage`: Identifies gaps in merged timeline
- `validateoverlap`: Flags unexpected overlapping periods
- `summarize`: Shows date range statistics

#### Example 5: Three-Dataset Merge

```stata
* Create three time-varying datasets
use cohort, clear
tvexpose using hrt, id(id) start(rx_start) stop(rx_stop) ///
    exposure(hrt_type) reference(0) ///
    entry(study_entry) exit(study_exit) saveas(tv_hrt.dta) replace

use cohort, clear
tvexpose using dmt, id(id) start(dmt_start) stop(dmt_stop) ///
    exposure(dmt) reference(0) ///
    entry(study_entry) exit(study_exit) saveas(tv_dmt.dta) replace

use cohort, clear
tvexpose using hrt, id(id) start(rx_start) stop(rx_stop) ///
    exposure(hrt_type) reference(0) ///
    entry(study_entry) exit(study_exit) saveas(tv_hrt2.dta) replace

* Merge all three
tvmerge tv_hrt tv_dmt tv_hrt2, id(id) ///
    start(rx_start dmt_start rx_start) ///
    stop(rx_stop dmt_stop rx_stop) ///
    exposure(tv_exposure tv_exposure tv_exposure) ///
    generate(hrt dmt_type hrt2)
```

#### Example 6: Performance Optimization with Batch Processing

```stata
* Default batch processing (20% per batch)
tvmerge tv_hrt tv_dmt, id(id) ///
    start(rx_start dmt_start) stop(rx_stop dmt_stop) ///
    exposure(tv_exposure tv_exposure) ///
    generate(hrt dmt_type)

* Larger batches for faster processing (50% per batch)
tvmerge tv_hrt tv_dmt, id(id) ///
    start(rx_start dmt_start) stop(rx_stop dmt_stop) ///
    exposure(tv_exposure tv_exposure) ///
    generate(hrt dmt_type) batch(50)

* Smaller batches for memory-constrained systems (10% per batch)
tvmerge tv_hrt tv_dmt, id(id) ///
    start(rx_start dmt_start) stop(rx_stop dmt_stop) ///
    exposure(tv_exposure tv_exposure) ///
    generate(hrt dmt_type) batch(10)
```

Progress messages show batch processing status during execution.

### Remarks

**Understanding Merge Strategies:**

The merge creates all possible combinations of overlapping periods (Cartesian product). For example, if person 1 has two HRT periods that overlap with three DMT periods, the merge produces six output records representing all combinations.

**Time Period Validity:**

All input datasets must have valid time periods where start < stop. Records with invalid periods (start >= stop) are automatically excluded with a warning. Point-in-time observations (start = stop) are valid.

**Variable Naming:**

When using `keep()`, additional variables from different source datasets receive `_ds#` suffixes (where # is 1, 2, 3, etc., corresponding to dataset order). This prevents naming conflicts when the same variable name appears in multiple datasets.

**Performance Considerations:**

Cartesian merges with multiple datasets can produce very large output datasets. The command uses batch processing to optimize performance by processing groups of IDs together instead of one at a time. Execution time varies from seconds for small datasets to several minutes for very large datasets.

**Important:**

`tvmerge` replaces the dataset currently in memory with the merged result. Use `saveas()` to save results or load your original data from a saved file before running.

### Stored Results

`tvmerge` stores the following in `r()`:

| Scalar/Macro | Description |
|--------------|-------------|
| `r(N)` | Number of observations in merged dataset |
| `r(N_persons)` | Number of unique persons |
| `r(mean_periods)` | Mean periods per person |
| `r(max_periods)` | Maximum periods for any person |
| `r(N_datasets)` | Number of datasets merged |
| `r(n_continuous)` | Number of continuous exposures |
| `r(n_categorical)` | Number of categorical exposures |
| `r(datasets)` | List of datasets merged |
| `r(exposure_vars)` | Names of exposure variables in output |

---

## tvevent - Integrate Events and Competing Risks

**tvevent** is the third step in the tvtools workflow. It processes time-varying datasets (created by `tvexpose` and `tvmerge`) to integrate outcomes and competing risks, preparing data for survival analysis.

### Syntax

```stata
tvevent using filename,
    id(varname)
    date(varname)
    [options]
```

### Required Options

| Option | Description |
|--------|-------------|
| `using filename` | Dataset containing event dates |
| `id(varname)` | Person identifier matching the master dataset |
| `date(varname)` | Variable in using file containing primary event date |

**Important:** The master dataset (currently in memory) must contain variables named `start` and `stop` representing interval boundaries. These are created automatically by `tvexpose` and `tvmerge`.

### Competing Risks Options

| Option | Description | Default |
|--------|-------------|---------|
| `compete(varlist)` | Date variables in using file representing competing risks | — |

### Event Definition Options

| Option | Description | Default |
|--------|-------------|---------|
| `type(string)` | Event type: **single** or **recurring** (see below for wide format requirement) | single |
| `generate(newvar)` | Name for event indicator variable | _failure |
| `continuous(varlist)` | Cumulative exposure variables to adjust proportionally when splitting intervals | — |
| `eventlabel(string)` | Custom value labels for the generated event variable | Derived from variable labels |

### Time Generation Options

| Option | Description | Default |
|--------|-------------|---------|
| `timegen(newvar)` | Create a variable representing duration of each interval | — |
| `timeunit(string)` | Unit for timegen: **days**, **months**, or **years** | days |

### Data Handling Options

| Option | Description | Default |
|--------|-------------|---------|
| `keepvars(varlist)` | Additional variables to keep from event dataset | — |
| `replace` | Replace output variables if they already exist | — |

### How tvevent Works

`tvevent` performs the following key tasks:

1. **Resolves Event Dates:** Compares the primary `date()` and any variables in `compete()`. The earliest occurring date becomes the effective event date for that person.

2. **Splitting:** If the event occurs in the middle of an existing exposure interval (start < event < stop), the interval is automatically split into two parts: pre-event and post-event.

3. **Continuous Adjustment:** If `continuous()` is specified, cumulative variables (like total dose) are proportionally reduced for split rows based on the new interval duration.

4. **Flagging:** Creates a status variable (default `_failure`) coded as:
   - 0 = Censored (No event)
   - 1 = Primary Event (from `date()`)
   - 2+ = Competing Events (corresponding to the order in `compete()`)

5. **Type Handling:**
   - `type(single)`: All data after the first occurring event is dropped (standard survival analysis)
   - `type(recurring)`: Retains all follow-up time for multiple events per person

### Examples

#### Example 1: Primary Outcome with Competing Risk (Death)

Study EDSS progression (disability worsening) with death as a competing risk:

```stata
use cohort, clear

tvexpose using dmt, id(id) start(dmt_start) stop(dmt_stop) ///
    exposure(dmt) reference(0) ///
    entry(study_entry) exit(study_exit)

tvevent using cohort, id(id) date(edss4_dt) compete(death_dt) generate(outcome)

stset stop, id(id) failure(outcome==1) enter(start)

stcrreg i.tv_exposure, compete(outcome==2)
```

The `outcome` variable is coded: 0=Censored, 1=EDSS progression, 2=Death.

#### Example 2: Custom Event Labels

Explicitly label censored, primary, and competing events:

```stata
use cohort, clear

tvexpose using hrt, id(id) start(rx_start) stop(rx_stop) ///
    exposure(hrt_type) reference(0) ///
    entry(study_entry) exit(study_exit)

tvevent using cohort, id(id) date(edss4_dt) ///
    compete(death_dt emigration_dt) ///
    eventlabel(0 "Censored" 1 "EDSS Progression" 2 "Death" 3 "Emigration") ///
    generate(status)
```

The `eventlabel()` option overrides default labels derived from variable labels.

#### Example 3: Continuous Dose Adjustment

When intervals contain cumulative exposure amounts, these should be proportionally reduced if an event splits the interval:

```stata
use cohort, clear

tvexpose using hrt, id(id) start(rx_start) stop(rx_stop) ///
    exposure(hrt_type) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    continuousunit(years)

tvevent using cohort, id(id) date(death_dt) type(single) continuous(tv_exposure)
```

If death occurs mid-interval, the continuous variable is adjusted by the ratio (new duration / original duration).

#### Example 4: Recurring Events (Wide Format)

For events that can occur multiple times (e.g., hospitalizations), use `type(recurring)`. The event dataset must have dates in **wide format** with numbered suffixes:

```stata
* Event dataset structure (one row per person, multiple date columns):
* id  hosp1       hosp2       hosp3
* 1   2020-01-15  2020-06-20  .
* 2   2020-04-01  .           .

use cohort, clear

tvexpose using dmt, id(id) start(dmt_start) stop(dmt_stop) ///
    exposure(dmt) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    saveas(tv_intervals.dta) replace

* Load event data with wide-format recurring events
use hospitalizations, clear

* date(hosp) finds hosp1, hosp2, hosp3, etc.
tvevent using tv_intervals, id(id) date(hosp) ///
    type(recurring) generate(hospitalized)
```

The command automatically detects hosp1, hosp2, hosp3, etc. and processes all events. Unlike `type(single)`, recurring events do not truncate follow-up after the first event. Note that `compete()` is not supported with recurring events.

#### Example 5: Generate Time Duration Variable

Create a variable for interval duration, useful for Poisson regression offsets:

```stata
use cohort, clear

tvexpose using dmt, id(id) start(dmt_start) stop(dmt_stop) ///
    exposure(dmt) reference(0) ///
    entry(study_entry) exit(study_exit)

tvevent using cohort, id(id) date(edss4_dt) ///
    timegen(interval_years) timeunit(years)
```

The `timegen()` option creates a variable showing the duration of each interval in the specified unit.

#### Example 6: Complete Workflow with All Three Commands

Full pipeline showing `tvexpose` → `tvmerge` → `tvevent` integration:

```stata
* Step 1: Create time-varying HRT dataset
use cohort, clear
tvexpose using hrt, id(id) start(rx_start) stop(rx_stop) ///
    exposure(hrt_type) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    saveas(tv_hrt.dta) replace

* Step 2: Create time-varying DMT dataset
use cohort, clear
tvexpose using dmt, id(id) start(dmt_start) stop(dmt_stop) ///
    exposure(dmt) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    saveas(tv_dmt.dta) replace

* Step 3: Merge the two time-varying datasets
tvmerge tv_hrt tv_dmt, id(id) ///
    start(rx_start dmt_start) stop(rx_stop dmt_stop) ///
    exposure(tv_exposure tv_exposure) ///
    generate(hrt dmt_type)

* Step 4: Integrate event data
tvevent using cohort, id(id) date(edss4_dt) compete(death_dt) ///
    generate(outcome) type(single)

* Step 5: Set up for survival analysis
stset stop, id(id) failure(outcome==1) enter(start)

* Step 6: Analyze with competing risks regression
stcrreg i.hrt i.dmt_type, compete(outcome==2)
```

This complete workflow demonstrates:
- Creating time-varying exposures from raw data
- Merging multiple time-varying exposures
- Integrating competing risks
- Preparing for survival analysis
- Estimating subdistribution hazard ratios with competing risks

### Remarks

**Event Type Selection:**

- **type(single)**: Use for terminal events (death, study outcomes). All follow-up after the first event is dropped. This is the most common scenario for survival analysis.
- **type(recurring)**: Use for events that can occur multiple times per person (hospitalizations, disease relapses). Retains all follow-up time. **Important:** Requires wide-format event data where `date()` specifies a stubname (e.g., `date(hosp)` expects variables `hosp1`, `hosp2`, etc.). The `compete()` option is not supported with recurring events.

**Continuous Variable Adjustment:**

When using `continuous()`, variables representing cumulative amounts (total dose, cumulative duration) are automatically adjusted when intervals are split by events. The adjustment preserves the rate: new_value = old_value × (new_duration / old_duration).

**Competing Risks:**

The command identifies the earliest occurring event among `date()` and `compete()` variables. The status variable indicates which event occurred first:
- 0 = Censored
- 1 = Primary event
- 2 = First competing risk
- 3 = Second competing risk
- etc.

**Important Notes:**

- By default, `tvevent` keeps all variables from the master dataset
- Variables are merged back based on id, start, and stop
- The master dataset must contain `start` and `stop` variables

### Stored Results

`tvevent` stores the following in `r()`:

| Scalar | Description |
|--------|-------------|
| `r(N)` | Total number of observations in output |
| `r(N_events)` | Total number of events/failures flagged |

---

## Requirements

- Stata 16.0 or higher
- No additional dependencies (uses only built-in Stata commands)

## Dialog Interfaces

Access the graphical interfaces:

```stata
db tvexpose
db tvmerge
db tvevent
```

Optional menu integration (requires `net get`, see Installation above):

```stata
do tvtools_menu_setup.do
```

After menu setup, access via: **User > Time-varying exposures**

## Quick Start Example

This example demonstrates the complete workflow with all three commands:

```stata
* Load main cohort data
use cohort, clear

* Step 1: Create time-varying medication exposure
tvexpose using medication_periods, ///
    id(patient_id) ///
    start(rx_start) ///
    stop(rx_end) ///
    exposure(med_type) ///
    entry(study_entry) ///
    exit(study_exit) ///
    generate(tv_medication) ///
    saveas(tv_meds.dta) replace

* Step 2: Create time-varying comorbidity exposure
use cohort, clear
tvexpose using comorbidity_periods, ///
    id(patient_id) ///
    start(comorb_start) ///
    stop(comorb_end) ///
    exposure(comorb_type) ///
    entry(study_entry) ///
    exit(study_exit) ///
    generate(tv_comorbidity) ///
    saveas(tv_comorb.dta) replace

* Step 3: Merge both exposures
tvmerge tv_meds tv_comorb, ///
    id(patient_id) ///
    start(rx_start comorb_start) ///
    stop(rx_end comorb_end) ///
    exposure(tv_medication tv_comorbidity) ///
    generate(medication comorbidity)

* Step 4: Integrate outcomes
tvevent using cohort, ///
    id(patient_id) ///
    date(outcome_date) ///
    compete(death_date) ///
    generate(status)

* Step 5: Set up survival data
stset stop, id(patient_id) failure(status==1) enter(start)

* Step 6: Analyze
stcox i.medication i.comorbidity
```

## Documentation

- Command help: `help tvexpose`, `help tvmerge`, `help tvevent`

## Author

Timothy P Copeland<br>
Department of Clinical Neuroscience<br>
Karolinska Institutet

## License

MIT License

## Version

| Command | Version | Date |
|---------|---------|------|
| tvexpose | 1.2.0 | 2025-12-14 |
| tvmerge | 1.0.5 | 2025-12-18 |
| tvevent | 1.4.0 | 2025-12-18 |

Package Distribution-Date: 20251226

### Checking Installed Version

```stata
which tvexpose
which tvmerge
which tvevent
```

## See Also

- Stata help: `help stset`, `help stcox`, `help stcrreg`, `help stsplit`
- Manual: [ST] stset, [ST] stcox, [ST] stcrreg
