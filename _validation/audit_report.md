# Validation Audit Report

**Date:** 2025-12-13
**Auditor:** Claude Code
**Branch:** fix/cross-platform-test-paths

## Summary

All validation tests pass after fixes were applied to three .ado files in the tvtools package.

| File | Tests | Status | Fixes Applied |
|------|-------|--------|---------------|
| validation_tvevent.do | 19 | PASS | 3 bugs fixed |
| validation_tvexpose.do | 20 | PASS | 2 bugs fixed |
| validation_tvmerge.do | 14 | PASS | 3 bugs fixed |

---

## Issues Found and Fixed

### 1. tvevent.ado (v1.3.0 -> v1.3.1)

#### Issue 1.1: `duplicates drop` fails with 0 observations
**Location:** Lines 349, 386
**Error:** `no observations r(2000)`
**Cause:** When event dates are exactly at interval boundaries or outside the study period, the split identification step could result in 0 observations. The subsequent `duplicates drop` command fails on empty datasets.

**Fix:** Added `if _N > 0` checks before `duplicates drop` calls:
```stata
if _N > 0 {
    duplicates drop `id' `date', force
}
```

#### Issue 1.2: Events at exact boundaries incorrectly captured
**Location:** Line 500 (frlink match logic)
**Error:** Test 4.6.2 failed - event at exact interval stop was being flagged
**Cause:** The frlink matches events when `stop == event_dt`, but this incorrectly captured events that were at the original interval boundary (not caused by a split).

**Fix:** Added `_orig_stop` tracking variable and boundary check:
```stata
gen double _orig_stop = `stopvar'  // Before splitting
...
replace `generate' = 0 if `generate' > 0 & `stopvar' == _orig_stop  // After frlink
```

### 2. tvexpose.ado (v1.1.1 -> v1.1.2)

#### Issue 2.1: Off-by-one error in baseline period creation
**Location:** Line 1816
**Error:** Person-time loss of 1 day at start of follow-up
**Cause:** Baseline period stop was set to `earliest_exp - 1` instead of `earliest_exp`, creating a 1-day gap.

**Fix:** Changed from:
```stata
quietly generate double exp_stop = earliest_exp - 1 if !missing(earliest_exp)
```
To:
```stata
quietly generate double exp_stop = earliest_exp if !missing(earliest_exp)
```

#### Issue 2.2: Off-by-one error in post-exposure period creation
**Location:** Line 1848
**Error:** Person-time loss of 1 day at end of follow-up
**Cause:** Post-exposure period start was set to `last_exp_stop + 1` instead of `last_exp_stop`, creating a 1-day gap.

**Fix:** Changed from:
```stata
quietly generate double exp_start = last_exp_stop + 1
```
To:
```stata
quietly generate double exp_start = last_exp_stop
```

### 3. tvmerge.ado (v1.0.2 -> v1.0.3)

#### Issue 3.1: Commands fail on empty datasets
**Location:** Lines 917, 938-955, 1041-1053
**Error:** `no observations r(2000)` and `variable __XXXXX not found`
**Cause:** Various commands (`duplicates drop`, `egen tag()`, `by: generate`) fail when there are 0 observations after a merge produces no valid intersections.

**Fix:** Added `if _N > 0` guards around affected code blocks:
```stata
if `n_before_dedup' > 0 {
    duplicates drop `dupvars', force
    ...
}
```

#### Issue 3.2: ID intersection not filtered before batch processing
**Location:** Lines 761-771
**Error:** `variable __XXXXX not found` during batch processing with force option
**Cause:** When force option was used with mismatched IDs, the warning was displayed but IDs weren't actually filtered from merged_data before batch processing began.

**Fix:** Added ID filtering after mismatch detection:
```stata
keep if _merge_check == 3  // Keep only matching IDs
keep id
tempfile valid_ids
save `valid_ids', replace
use `merged_data', clear
merge m:1 id using `valid_ids', keep(match) nogenerate
save `merged_data', replace
```

---

## Test Coverage

### tvevent (19 tests)
- Event Integration: 2 tests
- Interval Splitting: 1 test
- Competing Risks: 2 tests
- Single vs Recurring: 1 test
- Boundary Conditions: 3 tests (critical)
- Edge Cases: 3 tests
- Error Handling: 2 tests
- timegen/timeunit: 2 tests
- Invariants: 3 tests

### tvexpose (20 tests)
- Basic Transformation: 3 tests
- Person-Time Conservation: 1 test (failed before fix)
- Interval Integrity: 2 tests
- Gap Handling: 3 tests
- Exposure Transitions: 2 tests
- Edge Cases: 4 tests
- Error Handling: 2 tests
- Invariants: 3 tests

### tvmerge (14 tests)
- Basic Merge: 2 tests
- Person-Time: 1 test
- Continuous Variables: 1 test
- ID Handling: 3 tests (2 failed before fix)
- Multi-dataset: 2 tests
- Error Handling: 2 tests
- Invariants: 3 tests (1 failed before fix)

---

## Files Modified

```
tvtools/tvevent.ado   - v1.3.0 -> v1.3.1
tvtools/tvexpose.ado  - v1.1.1 -> v1.1.2
tvtools/tvmerge.ado   - v1.0.2 -> v1.0.3
```

---

## Validation Command

To re-run all validation tests:

```stata
do _validation/validation_tvevent.do
do _validation/validation_tvexpose.do
do _validation/validation_tvmerge.do
```

All tests should display "ALL VALIDATION TESTS PASSED!" at completion.
