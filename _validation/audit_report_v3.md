# Validation Audit Report v3

**Date:** 2025-12-13
**Auditor:** Claude Code
**Branch:** fix/cross-platform-test-paths

## Summary

All 6 validation test files pass after fixing issues in validation .do files and one bug in tvexpose.ado.

| File | Tests | Status | Issues Found | Fix Location |
|------|-------|--------|--------------|--------------|
| validation_check.do | 15 | PASS | None | N/A |
| validation_cstat_surv.do | 9 | PASS | None | N/A |
| validation_datefix.do | 12 | PASS | None | N/A |
| validation_tvevent.do | 31 | PASS | Wrong test expectation | validation file |
| validation_tvexpose.do | 50 | PASS | Invalid merge(0) param, list range bug | validation file + tvexpose.ado |
| validation_tvmerge.do | 27 | PASS | Macro assertion with embedded quotes | validation file |

**Total Tests:** 144
**All Passing:** Yes

---

## Issues Found and Fixed

### 1. validation_tvevent.do - Test 4.18.2 (Test File Fix)

**Issue:** Test expected `compete()` with `type(recurring)` to produce an error, but the actual behavior is to display a note and ignore the option.

**Error in Tests:** Assertion failed because `_rc` was 0 (success) when test expected non-zero.

**Root Cause:** The tvevent.ado design choice is to gracefully ignore the `compete()` option for recurring events rather than error. This is documented behavior.

**Fix:** Updated test to verify the command succeeds and that compete() is effectively ignored (no outcome=2 competing risk values):
```stata
* Old: assert _rc != 0
* New: Command should succeed, verify compete() was ignored
tvevent ... type(recurring) compete(hosp2) ...
quietly count if outcome == 2
assert r(N) == 0  // No competing risk outcomes
```

**Files Modified:**
- `_validation/validation_tvevent.do` - Updated test 4.18.2

---

### 2. validation_tvexpose.do - Test 3.12.2 (Test File Fix)

**Issue:** Test used `merge(0)` but the tvexpose.ado requires merge() to be positive (>=1).

**Error in Tests:** Error 198 (invalid syntax) because `merge() must be positive (days)`.

**Root Cause:** The test was designed to compare "no merging" vs "merging" but incorrectly used merge(0). The API doesn't allow merge(0).

**Fix:** Changed test to use `merge(1)` (minimal merging) vs `merge(30)` (more aggressive merging):
```stata
* Old: merge(0) generate(tv_no_merge)
* New: merge(1) generate(tv_no_merge)
```

**Files Modified:**
- `_validation/validation_tvexpose.do` - Updated test 3.12.2

---

### 3. tvexpose.ado - check Option Bug (ADO File Fix)

**Issue:** The `check` option's coverage diagnostics code tried to list `in 1/20` without checking if there were at least 20 observations.

**Error in Tests:** Error 198 "observation numbers out of range" when running with single-person test datasets.

**Root Cause:** Line 4036 used a hardcoded range `in 1/20` which fails when fewer than 20 observations exist.

**Fix:** Limited the range to actual number of observations:
```stata
* Old: noisily list id pct_covered n_periods n_gaps in 1/20, clean noobs
* New: noisily list id pct_covered n_periods n_gaps in 1/`=min(_N,20)', clean noobs
```

**Files Modified:**
- `tvtools/tvexpose.ado` - v1.1.2 -> v1.1.3 (fixed check option)
- `tvtools/tvexpose.sthlp` - Updated version to match

---

### 4. validation_tvmerge.do - Test 5.10.2 (Test File Fix)

**Issue:** Assertion using `r(datasets)` macro failed because the macro contains embedded quotes (multiple file paths).

**Error in Tests:** Error 111 "home not found" - Stata was misinterpreting the expanded macro value containing paths like `"/home/ubuntu/..."`.

**Root Cause:** When `r(datasets)` = `"file1.dta" "file2.dta"` is expanded in `assert "`r(datasets)'" != ""`, the nested quotes break parsing.

**Fix:** Used word count instead of direct string comparison:
```stata
* Old: assert "`r(datasets)'" != ""
* New: local ds_count : word count `r(datasets)'
*      assert `ds_count' >= 1
```

**Files Modified:**
- `_validation/validation_tvmerge.do` - Updated test 5.10.2

---

## Test Coverage Summary

### check (15 tests)
- Observation Count: 1 test
- Central Tendency (Mean, Median): 2 tests
- Dispersion (SD): 1 test
- Range (Min, Max): 2 tests
- Percentiles (p25, p75): 2 tests
- Missing Values: 2 tests
- Unique Values: 1 test
- Error Handling: 1 test
- Invariants: 3 tests

### cstat_surv (9 tests)
- Perfect Prediction: 1 test
- Random/Null Prediction: 1 test
- Inverse Prediction: 1 test
- Known Value: 1 test
- Error Handling: 2 tests
- Invariants: 3 tests

### datefix (12 tests)
- YMD Format: 2 tests
- MDY Format: 1 test
- DMY Format: 1 test
- Leap Year: 2 tests
- Date Arithmetic: 2 tests
- Error Handling: 2 tests
- Invariants: 2 tests

### tvevent (31 tests)
- Event Integration: 2 tests
- Interval Splitting: 1 test
- Competing Risks: 2 tests
- Single vs Recurring: 1 test
- Boundary Conditions: 3 tests
- Edge Cases: 3 tests
- Error Handling: 2 tests
- timegen/timeunit: 2 tests
- Invariants: 3 tests
- Additional tests: 12 tests

### tvexpose (50 tests)
- Core Transformation: 3 tests
- Cumulative Exposure: 2 tests
- Current/Former Status: 2 tests
- Grace Period: 2 tests
- Duration Categories: 1 test
- Lag and Washout: 2 tests
- Overlapping Exposures: 1 test
- evertreated: 2 tests
- Error Handling: 2 tests
- Date Format Preservation: 1 test
- Invariants: 2 tests
- Additional options tests: 30 tests

### tvmerge (27 tests)
- Cartesian Product: 2 tests
- Person-Time: 2 tests
- Continuous Variables: 1 test
- ID Matching: 2 tests
- Three-Way Merge: 2 tests
- Error Handling: 2 tests
- Invariants: 3 tests
- Additional tests: 13 tests

---

## Validation Commands

To re-run all validation tests:

```stata
do _validation/validation_check.do
do _validation/validation_cstat_surv.do
do _validation/validation_datefix.do
do _validation/validation_tvevent.do
do _validation/validation_tvexpose.do
do _validation/validation_tvmerge.do
```

All tests should display "ALL VALIDATION TESTS PASSED!" at completion.

---

## Files Modified in This Audit

```
tvtools/tvexpose.ado              - v1.1.2 -> v1.1.3 (fixed check option range bug)
tvtools/tvexpose.sthlp            - Updated version to 1.1.3
_validation/validation_tvevent.do - Fixed test 4.18.2 expectation
_validation/validation_tvexpose.do - Fixed test 3.12.2 merge() param
_validation/validation_tvmerge.do - Fixed test 5.10.2 macro assertion
_validation/audit_report_v3.md    - Created this report
```

---

## Conclusion

All 144 validation tests now pass. The issues found were:

1. **validation_tvevent.do (Test 4.18.2)**: Test expected error for compete()+recurring, but documented behavior is to ignore with a note
2. **validation_tvexpose.do (Test 3.12.2)**: Test used invalid merge(0), changed to merge(1)
3. **tvexpose.ado (check option)**: Bug with hardcoded list range `in 1/20` - fixed to use min(_N,20)
4. **validation_tvmerge.do (Test 5.10.2)**: Macro assertion broke with embedded quotes - fixed to use word count

One actual bug was found and fixed in tvexpose.ado (the check option). The other three were test expectation issues that didn't match actual (correct) behavior.
