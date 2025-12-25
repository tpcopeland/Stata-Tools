# TVTOOLS COMPREHENSIVE TESTING PROMPT

**Target Audience**: Claude Opus agent performing official package validation
**Expected Execution Time**: 45-90 minutes
**Stata Version Required**: 16.0+ (use `stata-mp` executable)

---

## MISSION STATEMENT

You are a senior Stata Corps programmer conducting a **complete quality assurance audit** of the `tvtools` package before official release. This package implements time-varying exposure analysis for pharmacoepidemiology and survival analysis research. Your job is to execute exhaustive testing that would satisfy FDA/EMA regulatory review standards.

The tvtools suite consists of three interdependent commands:
1. **tvexpose** - Creates time-varying exposure variables from prescription/treatment records
2. **tvmerge** - Merges multiple time-varying exposure datasets into unified analysis structure
3. **tvevent** - Integrates outcome events and competing risks into time-varying datasets

These commands form a pipeline: `tvexpose → tvmerge → tvevent → stset → stcox/stcrreg`

---

## CRITICAL CONTEXT

### Why This Testing Matters

Time-varying exposure analysis is used in studies that inform clinical decisions (e.g., "Does long-term HRT use increase breast cancer risk?"). Bugs in these commands can lead to:
- Misclassified exposure status → biased hazard ratios
- Lost person-time → underpowered studies
- Boundary handling errors → events attributed to wrong exposure period
- Continuous variable errors → incorrect cumulative dose calculations

**The v1.3.4 Boundary Bug** (fixed in v1.3.5) is an example: events occurring exactly at interval boundaries (`event_date == stop`) were incorrectly filtered out, causing systematic under-counting of events.

### Package Architecture

```
Raw Cohort Data (master)
      │
      ▼
   tvexpose ─────────────────────────────────────────────────────────┐
      │ Creates time-varying exposure intervals                      │
      │ Input:  cohort.dta + exposure_records.dta                   │
      │ Output: intervals with (id, start, stop, exposure_category) │
      ▼                                                              │
   tvmerge ◄─────────────────────────────────────────────────────────┘
      │ Merges multiple exposure datasets
      │ Input:  tv_dataset_1.dta + tv_dataset_2.dta + ...
      │ Output: unified intervals with all exposure variables
      ▼
   tvevent
      │ Integrates events and competing risks
      │ Input:  cohort.dta (master with events) + intervals.dta (using)
      │ Output: analysis-ready dataset with outcome variable
      ▼
   stset + stcox/stcrreg
```

---

## PHASE 1: ENVIRONMENT SETUP AND PREREQUISITES

### 1.1 Verify Environment

```stata
version 16.0
set more off
set varabbrev off

* Display Stata version for audit trail
display "Stata version: `c(stata_version)'"
display "MP cores: `c(processors)'"
display "Memory: `c(max_memory)'"
display "Date: `c(current_date)' `c(current_time)'"
```

### 1.2 Install Package

```stata
cd "/path/to/Stata-Tools"
capture net uninstall tvtools
net install tvtools, from("./tvtools")

* Verify installation
which tvexpose
which tvmerge
which tvevent
```

### 1.3 Generate Test Data

```stata
cd "_testing"
do generate_test_data.do
```

**Required test datasets:**
| File | Purpose | Observations |
|------|---------|--------------|
| `cohort.dta` | Base cohort with demographics, entry/exit dates, outcomes | 1,000 patients |
| `cohort_large.dta` | Stress testing cohort | 5,000 patients |
| `cohort_stress.dta` | Memory/performance limits | 10,000 patients |
| `hrt.dta` / `hrt_large.dta` | HRT prescription records | Variable |
| `dmt.dta` / `dmt_large.dta` | DMT (disease-modifying therapy) records | Variable |
| `hospitalizations.dta` | Event records (recurring) | Variable |

---

## PHASE 2: INDIVIDUAL COMMAND TESTING

### 2.1 TVEXPOSE TESTING

Execute the full tvexpose test suite:

```stata
global RUN_TEST_QUIET = 0
global RUN_TEST_MACHINE = 0
global RUN_TEST_NUMBER = 0
do test_tvexpose.do
```

#### Required Test Coverage (51 tests minimum):

**A. Core Functionality (Tests 1-10)**
- [ ] Basic execution with minimal required arguments
- [ ] `if` and `in` conditions
- [ ] Required options validation (error on missing id/start/stop/exposure/reference/entry/exit)
- [ ] Invalid variable names produce error 111
- [ ] Empty data produces error 2000
- [ ] Return values populated: `r(N_persons)`, `r(N_periods)`, `r(total_time)`, `r(exposed_time)`

**B. Exposure Types (Tests 11-20)**
- [ ] Default time-varying exposure (no modifier)
- [ ] `evertreated` option (binary ever/never)
- [ ] `currentformer` option (0=never, 1=current, 2=former)
- [ ] `duration(numlist)` cumulative exposure duration categories
- [ ] `recency(numlist)` time since last exposure categories
- [ ] `dose` with `dosecuts(numlist)` cumulative dose tracking
- [ ] `bytype` separate variables for each exposure type

**C. Handling Options (Tests 21-35)**
- [ ] `grace(#)` merges gaps ≤ # days
- [ ] `merge(#)` merges same-type periods ≤ # days apart
- [ ] `pointtime` for point-in-time data (start only)
- [ ] `fillgaps(#)` assumes exposure continues # days beyond last record
- [ ] `carryforward(#)` carries exposure through gaps
- [ ] `lag(#)` delays exposure activation
- [ ] `washout(#)` persists exposure after stopping
- [ ] `window(# #)` acute exposure window
- [ ] `continuousunit(days|weeks|months|quarters|years)`
- [ ] `expandunit()` temporal expansion

**D. Overlap Handling (Tests 36-45)**
- [ ] `priority(numlist)` resolves overlapping exposures
- [ ] `layer` later exposures take precedence
- [ ] `split` creates all boundary combinations
- [ ] `combine(newvar)` creates combined exposure indicator
- [ ] Overlapping exposures without resolution → error

**E. Output Options (Tests 46-51)**
- [ ] `generate(newvar)` custom output variable name
- [ ] `saveas(filename)` saves output to file
- [ ] `replace` overwrites existing output
- [ ] `keepvars(varlist)` retains specified variables
- [ ] `keepdates` preserves original entry/exit dates
- [ ] `referencelabel(text)` custom label for reference category

---

### 2.2 TVMERGE TESTING

Execute the full tvmerge test suite:

```stata
do test_tvmerge.do
```

#### Required Test Coverage (27 tests minimum):

**A. Basic Merge Operations (Tests 1-8)**
- [ ] Two-dataset merge
- [ ] Three-dataset merge
- [ ] `generate(namelist)` custom output names
- [ ] `prefix(string)` prefix for exposure variables
- [ ] `startname(string)` / `stopname(string)` custom output names
- [ ] `saveas(filename)` with `replace`
- [ ] ID mismatch between datasets → error (unless `force`)

**B. Continuous Exposure Handling (Tests 9-14)**
- [ ] `continuous(namelist)` proportions continuous variables at splits
- [ ] `continuous(positions)` by position (1, 2, 3)
- [ ] Verify proportioning formula: `(intersection_length + 1) / (original_length + 1)`
- [ ] Continuous + categorical mixing
- [ ] Zero-duration intersection handling
- [ ] Missing continuous values remain missing

**C. Validation and Diagnostics (Tests 15-20)**
- [ ] `check` option displays merge diagnostics
- [ ] `validatecoverage` checks for gaps in coverage
- [ ] `validateoverlap` checks for overlapping intervals
- [ ] `summarize` displays merge summary statistics
- [ ] Return values: `r(N)`, `r(N_persons)`, `r(N_datasets)`, `r(exposure_vars)`

**D. Advanced Options (Tests 21-27)**
- [ ] `keep(varlist)` retains additional variables (suffixed with _ds#)
- [ ] `batch(#)` processes IDs in batches for large datasets
- [ ] `force` allows merging non-matching ID sets
- [ ] `dateformat(fmt)` applies custom date format
- [ ] Person-time conservation across merge
- [ ] Large dataset stress test (5,000+ patients)

---

### 2.3 TVEVENT TESTING

Execute the full tvevent test suite:

```stata
do test_tvevent.do
```

#### Required Test Coverage (26 tests minimum):

**A. Core Event Integration (Tests 1-8)**
- [ ] Single event (primary outcome)
- [ ] Single event with one competing risk
- [ ] Single event with multiple competing risks
- [ ] Custom event labels via `eventlabel()`
- [ ] `type(single)` censors post-event time (default)
- [ ] `type(recurring)` for repeated events (wide format: date1, date2, ...)
- [ ] Return values: `r(N)`, `r(N_events)`

**B. Time Generation (Tests 9-12)**
- [ ] `timegen(newvar)` creates interval duration variable
- [ ] `timeunit(days)` / `timeunit(months)` / `timeunit(years)`
- [ ] Verify duration calculations match manual computation

**C. Variable Handling (Tests 13-18)**
- [ ] `continuous(varlist)` proportionally adjusts at splits
- [ ] `keepvars(varlist)` retains variables from master
- [ ] `startvar(varname)` / `stopvar(varname)` custom input names
- [ ] `replace` overwrites existing generate variable
- [ ] Value labels created automatically for outcome variable

**D. Boundary Conditions (Tests 19-22) ⚠️ CRITICAL**
- [ ] Event exactly at interval stop (`event_dt == stop`) → MUST be flagged
- [ ] Event at boundary between intervals → flagged at END of first interval
- [ ] Event at interval start (`event_dt == start`) → NOT flagged (survival convention)
- [ ] Event outside all intervals → NOT flagged

**E. Diagnostics (Tests 23-26)**
- [ ] `validate` option displays diagnostic information
- [ ] Return values: `r(v_outside_bounds)`, `r(v_multiple_events)`, `r(v_same_date_compete)`

---

## PHASE 3: VALIDATION TESTING (Correctness Verification)

### 3.1 Comprehensive Pipeline Validation

```stata
cd "_validation"
do validation_tvtools_comprehensive.do
```

#### Required Validation Tests (15 tests):

**A. End-to-End Pipeline (2 tests)**
- [ ] Single person complete pipeline with known dates → verify all transformations
- [ ] Pipeline with tvmerge → verify exposure combinations correct

**B. Continuous Variable Conservation (4 tests)**
- [ ] Single split: 100mg over 100 days, event at day 50 → 50mg in event interval
- [ ] Multiple splits: sum preserved across all segments
- [ ] tvmerge continuous: proportioning formula verified
- [ ] End-to-end: tvmerge + tvevent continuous through pipeline

**C. Person-Time Conservation (2 tests)**
- [ ] tvexpose: output person-time = input person-time (within tolerance)
- [ ] tvevent type(single): post-event time correctly removed

**D. Zero-Duration Intervals (2 tests)**
- [ ] Zero-duration `[X, X]` preserved by tvevent
- [ ] Zero-duration handled by tvmerge

**E. Events at Interval Boundaries (2 tests)**
- [ ] Event at start: NOT flagged (risk begins at start, not before)
- [ ] Event at boundary between intervals: flagged at END of first only

**F. Missing Value Handling (2 tests)**
- [ ] Missing event date → no events flagged, intervals preserved
- [ ] Missing continuous value → remains missing after proportioning

**G. Label Preservation (1 test)**
- [ ] Variable labels survive tvexpose → tvmerge → tvevent

---

### 3.2 Boundary Condition Validation

```stata
do validation_tvtools_boundary.do
```

#### Required Boundary Tests (14 tests) ⚠️ CRITICAL:

**A. Event at Exact Stop Boundary (3 tests)**
- [ ] Event at `stop` with single interval → 1 event flagged
- [ ] Event at boundary with multiple intervals → flagged at first interval end
- [ ] Multiple people with boundary events → all events captured

**B. Person-Time Conservation (2 tests)**
- [ ] No events: 365 days input = 365 days output
- [ ] With event at day 185: person-time = 185 days (censored at event)

**C. Interval Integrity Invariants (3 tests)**
- [ ] No overlapping intervals within person
- [ ] All intervals have `start < stop`
- [ ] Continuous coverage (no gaps before event)

**D. Comparison with Manual Method (1 test)**
- [ ] tvevent matches conceptual behavior of manual `inrange()` coding

**E. Competing Risks at Boundaries (1 test)**
- [ ] Competing event at boundary correctly flagged as type 2

**F. tvexpose Boundaries (2 tests)**
- [ ] Exposure ending at study_exit → full exposure captured
- [ ] Exposure starting at study_entry → interval starts exactly at entry

---

## PHASE 4: INTEGRATION TESTING

### 4.1 Full Pipeline Workflow

Test the complete analysis pipeline that epidemiologists actually use:

```stata
* Step 1: Create HRT exposure
use "${DATA_DIR}/cohort.dta", clear
tvexpose using "${DATA_DIR}/hrt.dta", ///
    id(id) start(rx_start) stop(rx_stop) ///
    exposure(hrt_type) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    evertreated keepvars(age female mstype) ///
    generate(ever_hrt) saveas("_tv_hrt.dta") replace

* Step 2: Create DMT exposure
use "${DATA_DIR}/cohort.dta", clear
tvexpose using "${DATA_DIR}/dmt.dta", ///
    id(id) start(dmt_start) stop(dmt_stop) ///
    exposure(dmt) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    evertreated keepvars(age female) ///
    generate(ever_dmt) saveas("_tv_dmt.dta") replace

* Step 3: Merge exposures
tvmerge "_tv_hrt.dta" "_tv_dmt.dta", ///
    id(id) start(rx_start dmt_start) stop(rx_stop dmt_stop) ///
    exposure(ever_hrt ever_dmt) ///
    keep(age female mstype) ///
    saveas("_merged.dta") replace

* Step 4: Integrate events with competing risks
use "${DATA_DIR}/cohort.dta", clear
tvevent using "_merged.dta", ///
    id(id) date(edss4_dt) ///
    compete(death_dt) ///
    type(single) generate(outcome)

* Step 5: Survival analysis
stset stop, id(id) failure(outcome==1) enter(start) scale(365.25)

* Step 6: Cox regression
stcox ever_hrt ever_dmt age i.female i.mstype

* Verify model ran successfully
assert e(N) > 0
assert e(N_fail) > 0
```

### 4.2 Fine-Gray Competing Risks

```stata
* Fine-Gray subdistribution hazard model
stcrreg i.ever_hrt i.ever_dmt age i.female, compete(outcome==2)
assert e(N) > 0
```

---

## PHASE 5: STRESS AND PERFORMANCE TESTING

### 5.1 Large Dataset Tests (5,000 patients)

```stata
* Full pipeline with large datasets
timer on 1
use "${DATA_DIR}/cohort_large.dta", clear
tvexpose using "${DATA_DIR}/hrt_large.dta", ///
    id(id) start(rx_start) stop(rx_stop) ///
    exposure(hrt_type) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    evertreated generate(ever_hrt) ///
    saveas("_large_hrt.dta") replace
timer off 1
timer list 1
```

**Performance Benchmarks:**
- tvexpose (5K patients): < 30 seconds
- tvmerge (5K patients, 2 datasets): < 60 seconds
- tvevent (5K patients): < 30 seconds
- Full pipeline (5K patients): < 3 minutes

### 5.2 Stress Test (10,000 patients)

```stata
timer on 2
use "${DATA_DIR}/cohort_stress.dta", clear
* ... full pipeline ...
timer off 2
timer list 2
```

**Stress Benchmarks:**
- Full pipeline (10K patients): < 10 minutes
- Memory usage: < 4GB

---

## PHASE 6: EDGE CASE TESTING

### 6.1 Data Anomalies

Test each command handles these gracefully:

| Scenario | Expected Behavior |
|----------|-------------------|
| Single observation per person | Completes without error |
| Person with no exposure records | Unexposed for entire follow-up |
| All events missing | No events flagged, intervals preserved |
| Zero-duration exposure `[X, X]` | Preserved, treated as instant exposure |
| Exposure outside study period | Truncated to study period |
| Overlapping exposures (no resolution) | Error with informative message |
| Duplicate IDs in exposure data | Handled per overlap option |
| Missing dates in exposure records | Error or excluded (per option) |

### 6.2 Known Limitations

Document behavior for currently unsupported scenarios:

| Scenario | Current Status |
|----------|----------------|
| Recurring events (type=recurring) | Wide format required (date1, date2, ...) |
| All-censored cohort (no events) | tvevent may produce empty result |
| Exposure gaps with imputation | Requires explicit `fillgaps()` or `carryforward()` |

---

## PHASE 7: INVARIANT VERIFICATION

For every test, verify these universal properties:

### 7.1 Data Integrity

```stata
* After any command, verify:
assert !missing(id)                    // No missing IDs
assert stop > start                    // Valid intervals
sort id start
by id: assert start == stop[_n-1] if _n > 1  // No gaps
by id: assert start >= stop[_n-1] if _n > 1  // No overlaps
```

### 7.2 Person-Time Conservation

```stata
* Before command
gen double input_pt = exit - entry
sum input_pt
local input_total = r(sum)

* After command
gen double output_pt = stop - start
sum output_pt
local output_total = r(sum)

* Verify (with tolerance for boundary handling)
assert abs(`output_total' - `input_total') < `input_total' * 0.001
```

### 7.3 Event Counts

```stata
* Source event count
count if !missing(event_dt)
local source_events = r(N)

* After tvevent
count if outcome == 1
local output_events = r(N)

* Events should not INCREASE (some may be outside study period)
assert `output_events' <= `source_events'
```

### 7.4 Continuous Variable Conservation

```stata
* Before split
sum cumulative_dose
local before_total = r(sum)

* After split
sum cumulative_dose
local after_total = r(sum)

* Sum preserved (with floating-point tolerance)
assert abs(`after_total' - `before_total') < 0.01
```

---

## PHASE 8: REPORTING

### 8.1 Test Summary Format

After completing all tests, provide a summary in this format:

```
========================================================================
TVTOOLS PACKAGE VALIDATION REPORT
========================================================================
Date: [current date]
Stata Version: [version]
Package Version: [tvevent.ado version line]

PHASE 2: INDIVIDUAL COMMAND TESTING
------------------------------------
tvexpose tests:     [passed]/[total] (XX%)
tvmerge tests:      [passed]/[total] (XX%)
tvevent tests:      [passed]/[total] (XX%)

PHASE 3: VALIDATION TESTING
------------------------------------
Comprehensive:      [passed]/[total] (XX%)
Boundary:           [passed]/[total] (XX%)

PHASE 4: INTEGRATION TESTING
------------------------------------
Full pipeline:      PASS/FAIL
Cox regression:     PASS/FAIL
Fine-Gray:          PASS/FAIL

PHASE 5: PERFORMANCE TESTING
------------------------------------
Large dataset (5K): [time] seconds
Stress test (10K):  [time] seconds

OVERALL RESULT: PASS / FAIL (with list of failures)
========================================================================
```

### 8.2 Failure Documentation

For any failure, document:
1. Test name and number
2. Command that failed
3. Error code and message
4. Data state at failure (N obs, key variables)
5. Expected vs actual behavior
6. Potential root cause

---

## EXECUTION CHECKLIST

- [ ] Environment verified (Stata 16+, stata-mp)
- [ ] Package installed from local repository
- [ ] Test data generated
- [ ] test_tvexpose.do completed: ___/51 tests
- [ ] test_tvmerge.do completed: ___/27 tests
- [ ] test_tvevent.do completed: ___/26 tests
- [ ] validation_tvtools_comprehensive.do completed: ___/15 tests
- [ ] validation_tvtools_boundary.do completed: ___/14 tests
- [ ] Full pipeline integration test completed
- [ ] Cox regression executed successfully
- [ ] Fine-Gray model executed successfully
- [ ] Large dataset (5K) completed in < 3 minutes
- [ ] Stress test (10K) completed in < 10 minutes
- [ ] All invariants verified
- [ ] Report generated

---

## COMMON FAILURE MODES TO WATCH

1. **Boundary Bug Pattern**: Events at exact interval boundaries not captured
2. **Person-Time Leakage**: Intervals created outside study period
3. **Continuous Proportion Error**: Sum not preserved after splits
4. **Label Corruption**: Variable/value labels lost through pipeline
5. **Memory Exhaustion**: Large datasets cause Stata to hang
6. **Frame Cleanup Failure**: Orphaned frames from interrupted execution
7. **Macro Name Truncation**: Local names > 31 characters silently truncated

---

## VERSION HISTORY

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2025-12-25 | Initial comprehensive testing prompt |

---

**END OF TESTING PROMPT**
