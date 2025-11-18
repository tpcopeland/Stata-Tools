# Comprehensive Audit Report: cstat_surv.ado

**Package**: cstat_surv
**Review Date**: 2025-11-18
**Reviewer**: Claude (AI Assistant)
**Framework Version**: 1.0.0

---

## Executive Summary

- **Overall Status**: NEEDS REVISION
- **Critical Issues**: 3
- **Non-Critical Issues**: 5
- **Recommendations**: 8

**Overview**: cstat_surv is a lightweight 39-line wrapper program that calculates the C-statistic for survival models by leveraging the external `somersd` command. While functionally correct, the program has several important issues related to program class declaration, error handling, and variable namespace management.

---

## Files Reviewed

- [x] cstat_surv.ado (39 lines)
- [x] cstat_surv.sthlp (122 lines)
- [x] cstat_surv.pkg
- [x] README.md

---

## 1. VERSION CONTROL AND HEADER

### Line 1: Version Declaration
```stata
*! cstat_cox Version 1.0.0  17November2025
```

**ISSUE**: Filename mismatch
- Header says "cstat_cox" but filename is "cstat_surv.ado"
- Creates confusion about program name
- **Severity**: MINOR

**Recommendation**:
```stata
*! cstat_surv Version 1.0.0  17November2025
```

### Lines 3-4: Author Information ✓
```stata
*! Original Author: Tim Copeland
*! Created on  17 November 2025
```

**Status**: GOOD - Clear authorship

---

## 2. PROGRAM DECLARATION

### Line 7: Program Class Declaration
```stata
program define cstat_surv, nclass
```

**CRITICAL ISSUE**: Incorrect program class
- Declared as `nclass` (n-class)
- `nclass` is **NOT a valid Stata program class**
- Valid classes: `rclass`, `eclass`, `sclass`, or no class
- This will cause errors in Stata
- **Severity**: CRITICAL

**Impact**:
- May not run in some Stata versions
- Cannot store or retrieve results properly
- Violates Stata programming standards

**Recommendation**:
```stata
program define cstat_surv, rclass
    // ... program code ...

    // At end, return somersd results
    return add  // Promotes r() results from somersd to this program's r()
end
```

**Alternative** (if not returning results):
```stata
program define cstat_surv
    // No class needed since somersd displays its own results
end
```

---

## 3. SYNTAX AND INPUT VALIDATION

### Line 8: Syntax Statement
```stata
syntax ,
```

**Status**: CORRECT but UNUSUAL
- Program takes no arguments (empty syntax)
- Works entirely on existing e() results and _st variables
- This design choice is intentional and documented

**Strengths**:
- Simple user interface (just type `cstat_surv`)
- No complex option parsing needed

**Limitation**:
- Cannot be used with multiple models without re-running
- Cannot specify confidence level (uses somersd default)
- Cannot suppress output or control formatting

**Enhancement Opportunity**:
```stata
syntax [, Level(cilevel) NODISplay REPLACE]

// Allow user to:
// - Control confidence level (default 95%)
// - Suppress display
// - Replace existing temporary variables if conflicts exist
```

---

## 4. INPUT VALIDATION

### Lines 10-15: Estimation Check ✓
```stata
* Validation: Check if last estimates found (Cox model fitted)
if "`e(cmd)'" == "" {
    display as error "last estimates not found"
    display as error "Run stcox before using cstat_surv"
    exit 301
}
```

**Status**: GOOD - Validates estimation exists

**Enhancement**:
```stata
// Also validate it's actually a Cox model
if "`e(cmd)'" != "stcox" {
    display as error "last estimation was `e(cmd)', not stcox"
    display as error "cstat_surv requires stcox estimation"
    exit 301
}
```

### Lines 17-23: stset Validation ✓
```stata
* Validation: Check if data is stset
capture assert _st == 1
if _rc {
    display as error "data not st; use stset"
    display as error "Data must be stset before running cstat_surv"
    exit 119
}
```

**Status**: EXCELLENT - Proper validation
- Uses correct error code (119 = not st data)
- Clear error messages
- Tests _st system variable

### Lines 25-30: Dependency Check ✓
```stata
* Validation: Check if somersd command is available
capture which somersd
if _rc {
    display as error "somersd command not found; install with: ssc install somersd"
    exit 199
}
```

**Status**: EXCELLENT - Validates external dependency
- Prevents cryptic errors downstream
- Provides installation instructions
- Uses appropriate error code (199 = command not found)

---

## 5. CORE FUNCTIONALITY

### Lines 32-36: Variable Creation
```stata
quietly{
predict hrs
gen invhr=1/hrs
generate censind=1-_d if _st==1
}
```

**CRITICAL ISSUE**: No temporary variable usage
- Creates `hrs`, `invhr`, `censind` in user's dataset
- **No `tempvar` declarations**
- Namespace pollution
- Risk of overwriting user variables
- **Severity**: CRITICAL

**Problems**:
1. If user has variables named `hrs`, `invhr`, or `censind`, they will be overwritten without warning
2. Line 38 tries to drop them, but if somersd fails, they remain in dataset
3. Violates Stata best practices

**Correct Implementation**:
```stata
// Declare temporary variables
tempvar hrs invhr censind

quietly {
    predict double `hrs'
    gen double `invhr' = 1/`hrs'
    generate `censind' = 1 - _d if _st==1
}

// No need to drop at end - automatic cleanup
```

### Line 33: Predict Statement
```stata
predict hrs
```

**ISSUES**:
1. No storage type specified (should use `double` for precision)
2. No check if prediction succeeds
3. No restriction to estimation sample

**Recommendation**:
```stata
tempvar hrs
quietly predict double `hrs' if e(sample), xb
if _rc {
    display as error "Failed to predict from Cox model"
    exit 322
}
```

**Note**: Using `xb` (linear predictor) may be more stable than default hazard ratio

### Line 34: Inverse Hazard Ratio
```stata
gen invhr=1/hrs
```

**ISSUES**:
1. No handling of division by zero (if hrs=0)
2. No storage type specified
3. No check for missing values

**Enhancement**:
```stata
tempvar invhr
quietly gen double `invhr' = 1/`hrs' if !missing(`hrs') & `hrs' != 0

// Validate no missing values created
quietly count if missing(`invhr') & `hrs' != .
if r(N) > 0 {
    display as text "Warning: `r(N)' observations have invalid hazard ratios"
}
```

### Line 35: Censoring Indicator
```stata
generate censind=1-_d if _st==1
```

**Status**: CORRECT
- `_d` is failure indicator (1 if event, 0 if censored)
- `1-_d` creates censoring indicator (1 if censored, 0 if event)
- Condition `if _st==1` restricts to stset observations

**Minor Enhancement**:
```stata
tempvar censind
quietly generate `censind' = 1 - _d if _st == 1 & e(sample)
// Also restrict to estimation sample
```

---

## 6. SOMERSD CALL

### Line 37: Main Computation
```stata
somersd _t invhr if _st==1, cenind(censind) tdist transf(c)
```

**Analysis**:

**Correct Elements**:
- `_t`: Survival time variable (from stset)
- `invhr`: Inverse hazard ratio (higher = better predicted survival)
- `if _st==1`: Restricts to survival-time observations
- `cenind(censind)`: Specifies censoring indicator variable
- `tdist`: Uses t-distribution for confidence intervals
- `transf(c)`: Transforms Somers' D to C-statistic (concordance)

**Issues**:

1. **Uses global variable names** instead of temp variables (see above)

2. **No sample restriction to e(sample)**:
```stata
// Should be:
somersd _t `invhr' if _st==1 & e(sample), cenind(`censind') tdist transf(c)
```

3. **No capture block** - if somersd fails, error is not gracefully handled

4. **Output not controlled** - always displays to screen

**Enhanced Implementation**:
```stata
// Allow user to suppress display
if "`nodisplay'" == "" {
    somersd _t `invhr' if _st==1 & e(sample), cenind(`censind') tdist transf(c) level(`level')
}
else {
    quietly somersd _t `invhr' if _st==1 & e(sample), cenind(`censind') tdist transf(c) level(`level')
}

// Check if somersd succeeded
if _rc {
    display as error "somersd calculation failed with error `_rc'"
    exit _rc
}
```

---

## 7. CLEANUP

### Line 38: Variable Cleanup
```stata
quietly drop hrs invhr censind
```

**CRITICAL ISSUE**: Unsafe cleanup
- Drops variables directly from dataset
- If variables don't exist, will error
- If somersd failed (line 37), these variables remain in dataset
- **Should use tempvar instead** (automatic cleanup)

**If keeping current approach** (not recommended):
```stata
// Safer cleanup
capture drop hrs invhr censind
```

**Best Practice** (using tempvar):
```stata
// No cleanup needed - automatic when program ends
```

---

## 8. RETURN VALUES

### Current: No return statement

The program relies on `somersd` to populate `r()` results. This works because:
- somersd is an rclass program
- Its r() results remain after it finishes
- User can access r(c), r(se), r(lb), r(ub), etc.

**Issue**: Program is declared `nclass` (invalid) not `rclass`

**Recommendation**:
```stata
program define cstat_surv, rclass
    // ... all code ...

    // Promote somersd results to this program's r()
    return add

    // Or explicitly return key values:
    return scalar cstat = r(c)
    return scalar se = r(se)
    return scalar lb = r(lb)
    return scalar ub = r(ub)
    return scalar p = r(p)
    return scalar N = e(N)
    return local cmd "cstat_surv"
end
```

---

## 9. ERROR HANDLING

### Current State: Minimal

**Missing Error Handling**:

1. **No check if prediction produces valid values**
```stata
// Add after predict:
quietly count if missing(`hrs') & e(sample)
if r(N) > 0 {
    display as error "Prediction failed for `r(N)' observations"
    exit 322
}
```

2. **No check if somersd succeeds**
```stata
capture noisily somersd ...
if _rc {
    display as error "Somers' D calculation failed"
    exit _rc
}
```

3. **No validation that e(sample) has sufficient observations**
```stata
quietly count if e(sample) & _st==1
if r(N) < 10 {
    display as error "Insufficient observations (`r(N)') for C-statistic calculation"
    exit 2001
}
```

---

## 10. DOCUMENTATION CONSISTENCY

### Help File vs Code

**Matches**:
- Command name: `cstat_surv` ✓
- No syntax arguments ✓
- Dependencies: somersd, stcox, stset ✓
- Return values: via somersd r() ✓

**Discrepancies**:
- Help file line 1 says version 1.0.0 17nov2025 ✓
- Code line 1 says cstat_**cox** (wrong!) ✗
- Help file line 111 says "Version 1.0.0 - 15 May 2022" (inconsistent date)

---

## 11. CODE QUALITY ASSESSMENT

### Strengths
1. ✓ Simple, focused design
2. ✓ Comprehensive input validation (stset, estimation, dependency)
3. ✓ Clear error messages with solutions
4. ✓ Well-documented help file
5. ✓ Correct statistical methodology (somersd for censored data)

### Weaknesses
1. ✗ Invalid program class declaration (`nclass`)
2. ✗ No temporary variable usage (namespace pollution)
3. ✗ Unsafe cleanup (drops user variables)
4. ✗ No error handling for core operations
5. ✗ Filename/header mismatch
6. ✗ No precision specification (should use `double`)
7. ✗ No sample restriction to e(sample)
8. ✗ No user control over output or confidence level

---

## 12. STATA PROGRAMMING STANDARDS COMPLIANCE

### Framework Checklist

#### Header Requirements
- [x] Version declaration present
- [ ] **FAIL**: Correct program name in header (says cstat_cox)
- [x] Author information present

#### Program Declaration
- [ ] **FAIL**: Valid program class (`nclass` is invalid)
- [ ] **FAIL**: Should be `rclass` if returning values

#### Syntax Statement
- [x] Syntax statement present and valid
- [x] No required arguments (by design)

#### Data Handling
- [ ] **FAIL**: Does not use `tempvar` for temporary variables
- [x] Uses `quietly` appropriately
- [ ] **FAIL**: No `preserve` (not needed, but modifies data unsafely)

#### Temporary Objects
- [ ] **FAIL**: Should use `tempvar` but doesn't
- [ ] **FAIL**: Manual cleanup instead of automatic

#### Return Values
- [ ] **FAIL**: Program class doesn't match return behavior
- [x] Returns values via somersd (indirect)

---

## PRIORITY RECOMMENDATIONS

### CRITICAL (Must Fix Before Production):

1. **Fix program class declaration** (Line 7)
   ```stata
   program define cstat_surv, rclass
       // ... code ...
       return add  // Promote somersd results
   end
   ```
   **Impact**: Prevents errors, allows proper result storage

2. **Use temporary variables** (Lines 33-35)
   ```stata
   tempvar hrs invhr censind
   quietly {
       predict double `hrs' if e(sample)
       gen double `invhr' = 1/`hrs'
       generate `censind' = 1 - _d if _st==1 & e(sample)
   }
   // Automatic cleanup - no drop needed
   ```
   **Impact**: Prevents overwriting user data, safer execution

3. **Fix header filename** (Line 1)
   ```stata
   *! cstat_surv Version 1.0.0  17November2025
   ```
   **Impact**: Documentation consistency

### HIGH PRIORITY (Correctness):

4. **Restrict to estimation sample** (Line 37)
   ```stata
   somersd _t `invhr' if _st==1 & e(sample), ...
   ```
   **Impact**: Ensures C-statistic matches fitted model

5. **Add error handling for prediction**
   ```stata
   quietly predict double `hrs' if e(sample)
   if _rc {
       display as error "Prediction failed"
       exit 322
   }
   ```
   **Impact**: Graceful failure with informative errors

6. **Validate estimation command** (Line 11)
   ```stata
   if "`e(cmd)'" != "stcox" {
       display as error "last estimation was `e(cmd)', not stcox"
       exit 301
   }
   ```
   **Impact**: Prevents misuse with non-Cox models

### MEDIUM PRIORITY (Usability):

7. **Add user options**
   ```stata
   syntax [, Level(cilevel) NODISplay REPLACE]
   ```
   **Impact**: Better control over output and conflicts

8. **Use double precision**
   ```stata
   predict double `hrs'
   gen double `invhr' = 1/`hrs'
   ```
   **Impact**: Better numerical stability

### LOW PRIORITY (Enhancements):

9. **Add validation of sufficient observations**
10. **Add option to store results in e() after estimation**
11. **Add option to export results to Excel/CSV**
12. **Add support for other survival models (streg, stpm2)**

---

## TESTING RECOMMENDATIONS

### Test Cases:

1. **Basic Functionality**:
   ```stata
   webuse drugtr, clear
   stset studytime, failure(died)
   stcox age drug
   cstat_surv
   assert r(c) > 0.5 & r(c) < 1
   ```

2. **Error Handling**:
   ```stata
   // Test: No estimation
   clear all
   set obs 100
   capture cstat_surv
   assert _rc == 301

   // Test: Not stset
   clear all
   set obs 100
   gen y = 1
   regress y
   capture cstat_surv
   assert _rc == 119

   // Test: somersd not installed
   // (manually test by renaming somersd.ado temporarily)
   ```

3. **Edge Cases**:
   ```stata
   // Test: All events (no censoring)
   // Test: All censored (no events)
   // Test: Single covariate
   // Test: Many covariates
   // Test: Small sample (N<20)
   // Test: Large sample (N>10000)
   ```

4. **Namespace Conflicts**:
   ```stata
   // Test: Variable name conflicts
   webuse drugtr, clear
   stset studytime, failure(died)
   gen hrs = 1
   gen invhr = 2
   gen censind = 3
   stcox age drug

   // This WILL fail with current implementation
   // Should NOT fail with tempvar implementation
   capture cstat_surv
   ```

---

## STATISTICAL CORRECTNESS

### Methodology ✓

The statistical approach is **CORRECT**:

1. **Harrell's C-statistic** for survival data requires accounting for censoring
2. **Somers' D** is the appropriate rank correlation for censored data
3. **Transformation**: C = (D + 1) / 2 converts Somers' D to C-statistic
4. **Inverse hazard ratio** used because somersd expects higher values = better outcome

### Implementation ✓

The somersd call is correct:
- `_t` = survival time (correct)
- `invhr` = 1/HR (correct - higher is better)
- `cenind()` = censoring indicator (correct)
- `tdist` = t-distribution CIs (appropriate)
- `transf(c)` = transform to C-statistic (correct)

---

## PERFORMANCE CONSIDERATIONS

### Current Performance: EXCELLENT

- Delegates computation to compiled somersd command
- Minimal data manipulation
- Only creates 3 variables
- Linear complexity O(n)

### No optimization needed for performance

---

## OVERALL ASSESSMENT

### Summary

| Category | Rating | Notes |
|----------|--------|-------|
| Statistical Correctness | ✓ EXCELLENT | Proper methodology |
| Functionality | ✓ GOOD | Works as intended |
| Code Quality | ✗ NEEDS WORK | Several critical issues |
| Documentation | ✓ GOOD | Help file is comprehensive |
| Error Handling | ~ MODERATE | Good validation, poor error handling |
| Stata Compliance | ✗ POOR | Invalid program class, no tempvar |
| User Experience | ✓ GOOD | Simple interface, clear messages |

### Approval Status

- [ ] Ready for optimization implementation
- [x] **Needs minor revisions first** ← CURRENT STATUS
- [ ] Needs major revisions first
- [ ] Requires complete rewrite

### Critical Actions Required

**Before deployment:**
1. Fix program class declaration (nclass → rclass)
2. Implement tempvar for all temporary variables
3. Fix header filename mismatch
4. Add e(sample) restriction to somersd call

**After critical fixes:**
- Add remaining error handling
- Implement user options
- Conduct comprehensive testing

---

## ESTIMATED EFFORT

- **Critical fixes**: 30 minutes
- **High-priority fixes**: 1 hour
- **Medium-priority additions**: 2 hours
- **Comprehensive testing**: 2 hours
- **Total**: ~5.5 hours

---

## CONCLUSION

cstat_surv is a **statistically sound and functionally correct** wrapper program that successfully calculates the C-statistic for Cox models using the established somersd methodology.

However, it **violates several Stata programming best practices** (invalid program class, no tempvar usage, unsafe cleanup) that must be addressed before production use. These are **easily fixable** issues that do not affect the statistical validity but pose risks to users' data integrity.

**Recommendation**: Implement critical fixes (est. 30 min) and proceed with optimization. The core logic is sound and should not be changed.

**Risk Assessment**: LOW - Issues are isolated and well-understood. Fixes are straightforward.

---

**Reviewer Notes**: This audit accurately reflects the actual 39-line wrapper implementation that uses somersd. The previous audit report described an entirely different program (complex Mata implementation with bootstrap) that does not exist and has been corrected.
