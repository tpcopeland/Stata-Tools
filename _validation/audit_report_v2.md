# Validation Audit Report v2

**Date:** 2025-12-13
**Auditor:** Claude Code
**Branch:** fix/cross-platform-test-paths

## Summary

All 6 validation test files now pass after fixing issues in both .ado files and validation .do files.

| File | Tests | Status | Issues Found | Fix Location |
|------|-------|--------|--------------|--------------|
| validation_check.do | 15 | PASS | Missing return values | check.ado |
| validation_cstat_surv.do | 9 | PASS | Wrong return value names | validation file |
| validation_datefix.do | 12 | PASS | Incorrect expected date value | validation file |
| validation_tvevent.do | 19 | PASS | None | N/A |
| validation_tvexpose.do | 20 | PASS | None | N/A |
| validation_tvmerge.do | 14 | PASS | None | N/A |

**Total Tests:** 89
**All Passing:** Yes

---

## Issues Found and Fixed

### 1. check.ado (v1.0.2 -> v1.0.3)

**Issue:** The `check` command calculated statistics internally but did not expose them via return values for programmatic use.

**Error in Tests:** Error 9 ("not found") when tests tried to access `r(N)`, `r(mean)`, `r(sd)`, `r(min)`, `r(max)`, `r(p25)`, `r(p50)`, `r(p75)`, `r(nmissing)`, and `r(unique)`.

**Root Cause:** The command only returned `varlist`, `nvars`, and `mode` but not the calculated statistics.

**Fix:** Added return statements to expose all calculated statistics:
```stata
* Return statistics for the last variable processed
quietly summarize `last_var', detail
return scalar N = r(N)
return scalar mean = r(mean)
return scalar sd = r(sd)
return scalar min = r(min)
return scalar max = r(max)
return scalar p25 = r(p25)
return scalar p50 = r(p50)
return scalar p75 = r(p75)

quietly mdesc `last_var'
return scalar nmissing = r(miss)

quietly unique `last_var' if !missing(`last_var')
return scalar unique = r(unique)
```

**Files Modified:**
- `check/check.ado` - Added return values
- `check/check.pkg` - Updated Distribution-Date to 20251213

---

### 2. validation_cstat_surv.do (Test File Fix)

**Issue:** The validation test used incorrect return value names that didn't match the actual `cstat_surv` command output.

**Error in Tests:** Error 9 ("not found") when tests tried to access `e(cstat)`, `e(se_cstat)`, `e(lb_cstat)`, `e(ub_cstat)`.

**Root Cause:** The validation tests were written with assumed return value names that differed from the actual implementation.

**Actual Return Values:**
- `e(c)` not `e(cstat)`
- `e(se)` not `e(se_cstat)`
- `e(ci_lo)` not `e(lb_cstat)`
- `e(ci_hi)` not `e(ub_cstat)`

**Fix:** Updated all assertions in validation_cstat_surv.do to use correct return value names:
- `e(cstat)` -> `e(c)`
- `e(se_cstat)` -> `e(se)`
- `e(lb_cstat)` -> `e(ci_lo)`
- `e(ub_cstat)` -> `e(ci_hi)`

**Files Modified:**
- `_validation/validation_cstat_surv.do` - Fixed 6 occurrences

---

### 3. validation_datefix.do (Test File Fix)

**Issue:** The expected Stata date value for June 15, 2020 was incorrect in the test dataset.

**Error in Tests:** Assertion failed because parsed date (22081) didn't match expected value (22082).

**Root Cause:** Off-by-one error in the expected value. The correct value is:
```stata
mdy(6,15,2020) = 22081  // NOT 22082
```

**Fix:** Updated the expected value in the validation dataset and assertion:
- Line 115: Changed `22082` to `22081`
- Line 549: Updated comment from "22082" to "22081"
- Line 552: Updated assertion from `22082` to `22081`

**Files Modified:**
- `_validation/validation_datefix.do` - Fixed 3 occurrences

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

### tvevent (19 tests)
- Event Integration: 2 tests
- Interval Splitting: 1 test
- Competing Risks: 2 tests
- Single vs Recurring: 1 test
- Boundary Conditions: 3 tests
- Edge Cases: 3 tests
- Error Handling: 2 tests
- timegen/timeunit: 2 tests
- Invariants: 3 tests

### tvexpose (20 tests)
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

### tvmerge (14 tests)
- Cartesian Product: 2 tests
- Person-Time: 2 tests
- Continuous Variables: 1 test
- ID Matching: 2 tests
- Three-Way Merge: 2 tests
- Error Handling: 2 tests
- Invariants: 3 tests

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
check/check.ado              - v1.0.2 -> v1.0.3 (added return values)
check/check.pkg              - Updated Distribution-Date
_validation/validation_cstat_surv.do - Fixed return value names
_validation/validation_datefix.do    - Fixed expected date value
_validation/audit_report_v2.md       - Created this report
```

---

## Conclusion

All 89 validation tests now pass. The issues found were:
1. A design gap in check.ado (statistics not returned for programmatic use)
2. A documentation mismatch in cstat_surv validation tests (wrong return value names)
3. A data entry error in datefix validation tests (off-by-one date value)

The tvtools package (tvevent, tvexpose, tvmerge) required no fixes - all tests passed on first run.
