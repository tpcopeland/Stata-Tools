# Synthdata Package Audit

**Date:** 2025-12-03
**Version Audited:** 1.0.1
**Auditor:** Claude (automated code review)

---

## Executive Summary

A comprehensive audit of the `synthdata` package identified **one critical bug** that causes errors when using the parametric synthesis method with multiple continuous variables. The bug prevents the Mata function from storing generated data because the target variables don't exist in the dataset.

---

## Bug Identified

### BUG 1: Missing Variable Creation Before Mata `st_store()` Call

**Severity:** Critical
**Location:** `synthdata.ado`, lines 595-597 (`_synthdata_parametric` program)
**Impact:** Parametric method fails with error when dataset has 2+ continuous variables

#### Problem Description

The `_synthdata_parametric` program generates multivariate normal data using the Mata function `_synthdata_genmvn()`. This Mata function uses `st_store()` to write the generated data back to Stata variables. However, **`st_store()` requires that the target variables already exist in the dataset**.

When there is only one continuous variable, the code correctly creates the variable with `gen`:
```stata
qui gen double `v' = rnormal(...)
```

When there are multiple continuous variables, the code calls the Mata function **without first creating the variables**, causing `st_store()` to fail.

#### Root Cause Analysis

**Reasoning:** The Mata function `st_store(., varname, data)` stores values into an **existing** Stata variable. To create new variables from Mata, you must either:
1. Use `st_addvar()` to create the variable first, then `st_store()` to populate it
2. Create the variables in Stata before calling the Mata function

The code handles this correctly for categorical variables (line 605: `qui gen double `v' = .` before calling Mata), but omits this step for multivariate continuous variables.

---

## Code Changes

### BEFORE (Lines 588-599)

```stata
    // Generate continuous variables
    if `ncont' > 0 {
        if `ncont' == 1 {
            // Single variable: simple normal
            local v: word 1 of `contvars'
            qui gen double `v' = rnormal(`=`means'[1,1]', `=`sds'[1,1]')
        }
        else {
            // Multivariate normal via Cholesky
            mata: _synthdata_genmvn("`contvars'", st_matrix("`means'"), st_matrix("`covmat'"), `n')
        }
    }
```

### AFTER (Lines 588-604)

```stata
    // Generate continuous variables
    if `ncont' > 0 {
        if `ncont' == 1 {
            // Single variable: simple normal
            local v: word 1 of `contvars'
            qui gen double `v' = rnormal(`=`means'[1,1]', `=`sds'[1,1]')
        }
        else {
            // Create variables first (st_store requires existing variables)
            foreach v of local contvars {
                qui gen double `v' = .
            }
            // Multivariate normal via Cholesky
            mata: _synthdata_genmvn("`contvars'", st_matrix("`means'"), st_matrix("`covmat'"), `n')
        }
    }
```

---

## Verification of Recent Fixes

The audit also verified that two previously identified bugs were correctly fixed in recent commits:

### Fix 1: Undefined `use_reg` Macro (Commit 011481c)

**Status:** Verified Fixed

The `_synthdata_sequential` program now correctly initializes `use_reg = 0` at line 888 before attempting to check its value, preventing undefined macro errors.

### Fix 2: Merge Order with Prefix Option (Commit eba6104)

**Status:** Verified Fixed

The `_synthdata_validate` program now correctly removes the prefix from synthetic variable names **before** merging with original statistics, ensuring proper matching.

---

## Additional Observations

### Code Quality

1. **Good Practice:** All helper programs properly use `version 16.0` and follow Stata coding conventions
2. **Good Practice:** Mata functions are well-structured with clear parameter names
3. **Good Practice:** Error handling for empty datasets, invalid options, and file path injection

### Potential Edge Cases (Not Bugs)

1. **Prefix length:** Very long prefixes combined with variable names could exceed Stata's 32-character limit. The code uses `cap rename` which silently fails, which is acceptable behavior.

2. **Large datasets:** The parametric method stores the full covariance matrix, which could be memory-intensive with many variables. This is documented in the help file limitations section.

---

## Test Recommendations

To verify the fix works correctly, run these test cases:

```stata
* Test 1: Parametric with multiple continuous variables (the bug case)
sysuse auto, clear
synthdata price mpg weight, parametric n(100) replace
assert _N == 100
assert !missing(price[1])

* Test 2: Parametric with single continuous variable (should still work)
sysuse auto, clear
synthdata price, parametric n(100) replace
assert _N == 100

* Test 3: Sequential method (should not be affected)
sysuse auto, clear
synthdata price mpg, sequential n(100) replace
assert _N == 100

* Test 4: Bootstrap method (should not be affected)
sysuse auto, clear
synthdata price mpg, bootstrap n(100) replace
assert _N == 100
```

---

## Version Update Summary

| File | Field | Before | After |
|------|-------|--------|-------|
| synthdata.ado | Version header | 1.0.1 | 1.0.2 |
| synthdata.sthlp | Version | 1.0.1 | 1.0.2 |
| synthdata.pkg | Distribution-Date | 20251203 | 20251203 |
| README.md | Version | 1.0.1 | 1.0.2 |

---

## Conclusion

The audit identified one critical bug that would cause the parametric synthesis method to fail when processing datasets with multiple continuous variables. The fix is straightforward: create the variables before calling the Mata function that populates them.

The fix has been implemented and all version numbers updated accordingly.
