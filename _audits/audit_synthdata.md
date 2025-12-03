# Audit Report: synthdata.ado

**Audit Date:** 2025-12-03
**Package:** synthdata
**Current Version:** 1.0.0
**Auditor:** Claude (Stata Coding Standards)

---

## Executive Summary

This audit identified **19 issues** requiring fixes:
- **13 Critical** - Missing version statements in all helper programs
- **3 High** - File path security issues, logic errors
- **2 Medium** - Error handling improvements
- **1 Low** - Code style improvement

All critical and high-severity issues must be fixed. Medium and low issues are recommended improvements.

---

## Critical Issues (Must Fix)

### Issue 1: Missing version statement in _synthdata_classify
**Line:** 305
**Severity:** Critical
**Description:** Helper program `_synthdata_classify` missing `version 16.0` statement

**Current Code:**
```stata
program define _synthdata_classify, rclass
    syntax varlist, [categorical(varlist) continuous(varlist) dates(varlist)]
```

**Fixed Code:**
```stata
program define _synthdata_classify, rclass
    version 16.0
    syntax varlist, [categorical(varlist) continuous(varlist) dates(varlist)]
```

**Reason:** All Stata programs must declare version for compatibility (CLAUDE.md Critical Rule #1)

---

### Issue 2: Missing version statement in _synthdata_storebounds
**Line:** 356
**Severity:** Critical
**Description:** Helper program missing `version 16.0` statement

**Current Code:**
```stata
program define _synthdata_storebounds
    syntax varlist, saving(string)
```

**Fixed Code:**
```stata
program define _synthdata_storebounds
    version 16.0
    syntax varlist, saving(string)
```

---

### Issue 3: Missing version statement in _synthdata_stats
**Line:** 371
**Severity:** Critical
**Description:** Helper program missing `version 16.0` statement

**Current Code:**
```stata
program define _synthdata_stats
    syntax varlist, saving(string)
```

**Fixed Code:**
```stata
program define _synthdata_stats
    version 16.0
    syntax varlist, saving(string)
```

---

### Issue 4: Missing version statement in _synthdata_parametric
**Line:** 391
**Severity:** Critical
**Description:** Helper program missing `version 16.0` statement

**Current Code:**
```stata
program define _synthdata_parametric
    syntax, n(integer) [catvars(varlist) contvars(varlist) datevars(varlist) ///
```

**Fixed Code:**
```stata
program define _synthdata_parametric
    version 16.0
    syntax, n(integer) [catvars(varlist) contvars(varlist) datevars(varlist) ///
```

---

### Issue 5: Missing version statement in _synthdata_bootstrap
**Line:** 607
**Severity:** Critical
**Description:** Helper program missing `version 16.0` statement

**Current Code:**
```stata
program define _synthdata_bootstrap
    syntax, n(integer) noise(real) [catvars(varlist) contvars(varlist) ///
```

**Fixed Code:**
```stata
program define _synthdata_bootstrap
    version 16.0
    syntax, n(integer) noise(real) [catvars(varlist) contvars(varlist) ///
```

---

### Issue 6: Missing version statement in _synthdata_permute
**Line:** 688
**Severity:** Critical
**Description:** Helper program missing `version 16.0` statement

**Current Code:**
```stata
program define _synthdata_permute
    syntax varlist, n(integer) origdata(string)
```

**Fixed Code:**
```stata
program define _synthdata_permute
    version 16.0
    syntax varlist, n(integer) origdata(string)
```

---

### Issue 7: Missing version statement in _synthdata_sequential
**Line:** 724
**Severity:** Critical
**Description:** Helper program missing `version 16.0` statement

**Current Code:**
```stata
program define _synthdata_sequential
    syntax, n(integer) [catvars(varlist) contvars(varlist) ///
```

**Fixed Code:**
```stata
program define _synthdata_sequential
    version 16.0
    syntax, n(integer) [catvars(varlist) contvars(varlist) ///
```

---

### Issue 8: Missing version statement in _synthdata_constraints
**Line:** 909
**Severity:** Critical
**Description:** Helper program missing `version 16.0` statement

**Current Code:**
```stata
program define _synthdata_constraints
    syntax, constraints(string asis) iterate(integer)
```

**Fixed Code:**
```stata
program define _synthdata_constraints
    version 16.0
    syntax, constraints(string asis) iterate(integer)
```

---

### Issue 9: Missing version statement in _synthdata_autoconstraints
**Line:** 1007
**Severity:** Critical
**Description:** Helper program missing `version 16.0` statement

**Current Code:**
```stata
program define _synthdata_autoconstraints
    syntax varlist, iterate(integer) origdata(string)
```

**Fixed Code:**
```stata
program define _synthdata_autoconstraints
    version 16.0
    syntax varlist, iterate(integer) origdata(string)
```

---

### Issue 10: Missing version statement in _synthdata_bounds
**Line:** 1034
**Severity:** Critical
**Description:** Helper program missing `version 16.0` statement

**Current Code:**
```stata
program define _synthdata_bounds
    syntax, bounds(string asis)
```

**Fixed Code:**
```stata
program define _synthdata_bounds
    version 16.0
    syntax, bounds(string asis)
```

---

### Issue 11: Missing version statement in _synthdata_noextreme
**Line:** 1066
**Severity:** Critical
**Description:** Helper program missing `version 16.0` statement

**Current Code:**
```stata
program define _synthdata_noextreme
    syntax varlist, boundsfile(string)
```

**Fixed Code:**
```stata
program define _synthdata_noextreme
    version 16.0
    syntax varlist, boundsfile(string)
```

---

### Issue 12: Missing version statement in _synthdata_panel
**Line:** 1090
**Severity:** Critical
**Description:** Helper program missing `version 16.0` statement

**Current Code:**
```stata
program define _synthdata_panel
    syntax, panelid(string) paneltime(string) [preserve(varlist) autocorr(integer 0) n(integer) origdata(string)]
```

**Fixed Code:**
```stata
program define _synthdata_panel
    version 16.0
    syntax, panelid(string) paneltime(string) [preserve(varlist) autocorr(integer 0) n(integer) origdata(string)]
```

---

### Issue 13: Missing version statement in _synthdata_compare
**Line:** 1123
**Severity:** Critical
**Description:** Helper program missing `version 16.0` statement

**Current Code:**
```stata
program define _synthdata_compare
    syntax varlist, origstats(string) [prefix(string)]
```

**Fixed Code:**
```stata
program define _synthdata_compare
    version 16.0
    syntax varlist, origstats(string) [prefix(string)]
```

---

### Issue 14: Missing version statement in _synthdata_validate
**Line:** 1196
**Severity:** Critical
**Description:** Helper program missing `version 16.0` statement

**Current Code:**
```stata
program define _synthdata_validate
    syntax varlist, origstats(string) saving(string) [prefix(string)]
```

**Fixed Code:**
```stata
program define _synthdata_validate
    version 16.0
    syntax varlist, origstats(string) saving(string) [prefix(string)]
```

---

### Issue 15: Missing version statement in _synthdata_utility
**Line:** 1239
**Severity:** Critical
**Description:** Helper program missing `version 16.0` statement

**Current Code:**
```stata
program define _synthdata_utility
    syntax varlist, origstats(string)
```

**Fixed Code:**
```stata
program define _synthdata_utility
    version 16.0
    syntax varlist, origstats(string)
```

---

### Issue 16: Missing version statement in _synthdata_graph
**Line:** 1248
**Severity:** Critical
**Description:** Helper program missing `version 16.0` statement

**Current Code:**
```stata
program define _synthdata_graph
    syntax varlist, origdata(string) [prefix(string)]
```

**Fixed Code:**
```stata
program define _synthdata_graph
    version 16.0
    syntax varlist, origdata(string) [prefix(string)]
```

---

## High Severity Issues

### Issue 17: Logic error - checking variable type after dropping
**Lines:** 140-151, 246-250
**Severity:** High
**Description:** Code checks if variable is string AFTER dropping it, which always fails

**Current Code (lines 140-151):**
```stata
// Handle skip variables - set to missing in synthetic data
if "`skip'" != "" {
    foreach v of local skip {
        cap drop `v'
        cap confirm string variable `v'
        if !_rc {
            qui gen str1 `v' = ""
        }
        else {
            qui gen `v' = .
        }
    }
}
```

**Fixed Code:**
```stata
// Handle skip variables - set to missing in synthetic data
if "`skip'" != "" {
    foreach v of local skip {
        // Check type before dropping
        local is_string = 0
        cap confirm string variable `v'
        if !_rc {
            local is_string = 1
        }

        cap drop `v'

        // Recreate based on original type
        if `is_string' {
            qui gen str1 `v' = ""
        }
        else {
            qui gen `v' = .
        }
    }
}
```

**Same fix needed at lines 246-250 in multiple datasets section**

---

### Issue 18: File path sanitization missing
**Lines:** 214, 279, 1231
**Severity:** High
**Description:** File paths not validated for dangerous characters before use

**Current Code (line 214):**
```stata
local savename = subinstr("`saving'", ".dta", "", .)
qui save "`savename'_1.dta", replace
```

**Fixed Code:**
```stata
// Sanitize filename
if regexm("`saving'", "[;&|><\$\`]") {
    di as error "saving() contains invalid characters"
    exit 198
}
local savename = subinstr("`saving'", ".dta", "", .)
qui save "`savename'_1.dta", replace
```

**Same fix needed at lines 279 and 1231**

---

### Issue 19: File path validation in _synthdata_validate
**Line:** 1231
**Severity:** High
**Description:** validate() option file path not sanitized

**Current Code:**
```stata
local savename = subinstr("`validate'", ".dta", "", .)
qui save "`savename'.dta", replace
```

**Fixed Code:**
```stata
// Sanitize filename
if regexm("`validate'", "[;&|><\$\`]") {
    di as error "validate() contains invalid characters"
    exit 198
}
local savename = subinstr("`validate'", ".dta", "", .)
qui save "`savename'.dta", replace
```

---

## Medium Severity Issues

### Issue 20: Missing value handling in levelsof
**Line:** 336
**Severity:** Medium
**Description:** levelsof may fail if all values are missing

**Current Code:**
```stata
qui levelsof `v', local(levels)
local nuniq: word count `levels'
```

**Fixed Code:**
```stata
qui count if !missing(`v')
if r(N) > 0 {
    qui levelsof `v', local(levels)
    local nuniq: word count `levels'
}
else {
    local nuniq = 0
}
```

---

### Issue 21: Error handling improvement in _synthdata_classify
**Line:** 336-347
**Severity:** Medium
**Description:** Better handling of edge cases in variable classification

**Recommendation:** Add explicit handling for variables with zero non-missing observations

---

## Low Severity Issues

### Issue 22: Code clarity in display statements
**Lines:** 291-301
**Severity:** Low
**Description:** Display statements could use consistent formatting

**Recommendation:** Use consistent tab alignment in summary output (optional improvement)

---

## Items Checked (No Issues Found)

✓ Main program has `version 16.0` (line 3)
✓ Main program has `set varabbrev off` (line 4)
✓ Uses `marksample` correctly with `novarlist` (line 21)
✓ Checks for empty observations (lines 24-28)
✓ Uses `preserve` before modifying data (line 17)
✓ Proper use of `tempvar`, `tempfile`, `tempname` throughout
✓ Backtick and quote usage correct throughout
✓ No variable name abbreviation issues
✓ Mata functions well-structured (lines 1310-1430)
✓ Helper programs use proper `rclass` where needed
✓ Error codes appropriate (2000 for no observations, 198 for invalid syntax)

---

## Summary of Required Fixes

### Must Fix (Critical + High):
1. Add `version 16.0` to all 13 helper programs
2. Fix logic error for skip variables (2 locations)
3. Add file path sanitization (3 locations)

### Should Fix (Medium):
1. Improve levelsof error handling
2. Add edge case handling in _synthdata_classify

### Optional (Low):
1. Improve display formatting consistency

---

## Implementation Priority

1. **First:** Add version statements to all helper programs (Issues 1-16)
2. **Second:** Fix skip variable logic error (Issue 17)
3. **Third:** Add file path sanitization (Issues 18-19)
4. **Fourth:** Improve error handling (Issues 20-21)

---

## Post-Audit Actions Required

1. Implement all critical and high-severity fixes
2. Update version to 1.0.1 in:
   - synthdata.ado header
   - synthdata/README.md
   - Main repository README.md
3. Update .pkg Distribution-Date to 20251203
4. Test all synthesis methods after fixes
5. Verify error handling with edge cases

---

## Auditor Notes

The synthdata package is well-structured overall with good use of Mata for performance-critical operations. The main issues are:
- Systematic omission of version statements in helper programs (critical)
- Logic error in skip variable handling (high)
- Security vulnerability in file path handling (high)

These are straightforward fixes that will significantly improve code quality and security.
