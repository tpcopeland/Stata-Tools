# Synthdata Package Audit Report

**Date:** 2025-12-03
**Auditor:** Claude
**Package Version:** 1.0.1

---

## Executive Summary

This audit identified **6 issues** in the synthdata package:
- **3 Critical bugs** in the .ado file that cause runtime errors or incorrect results
- **2 Documentation issues** in the .sthlp and README files
- **1 Minor issue** (version mismatch between files)

All issues have been fixed as part of this audit.

---

## Issue 1: CRITICAL - `_synthdata_noextreme` Program Logic Error

**Severity:** Critical
**Location:** `synthdata.ado` lines 1123-1145
**Impact:** The `noextreme` option fails at runtime when there are multiple variables to bound.

### Problem Analysis

The `_synthdata_noextreme` program attempts to apply bounds from a stored file to synthetic data. However, the logic has a fundamental flaw:

1. It `preserve`s the current (synthetic) data
2. Loads the bounds file (losing access to synthetic data)
3. Iterates through bounds file records
4. After the first iteration, it does `restore, preserve` which restores the synthetic data
5. **Bug:** On subsequent iterations, it tries to read `varname[`i']` but `varname` doesn't exist in the synthetic data - it was a variable in the bounds file!

### Before (Buggy Code)

```stata
program define _synthdata_noextreme
    version 16.0
    syntax varlist, boundsfile(string)

    preserve
    qui use `boundsfile', clear
    local nbounds = _N

    forvalues i = 1/`nbounds' {
        local vn = varname[`i']           // FAILS after first iteration!
        local vmin = vmin[`i']
        local vmax = vmax[`i']

        restore, preserve
        cap confirm variable `vn'
        if !_rc {
            qui replace `vn' = `vmin' if `vn' < `vmin' & !missing(`vn')
            qui replace `vn' = `vmax' if `vn' > `vmax' & !missing(`vn')
        }
    }

    restore, not
end
```

### After (Fixed Code)

```stata
program define _synthdata_noextreme
    version 16.0
    syntax varlist, boundsfile(string)

    // Load bounds into locals FIRST, before modifying data
    preserve
    qui use `boundsfile', clear
    local nbounds = _N

    forvalues i = 1/`nbounds' {
        local vn_`i' = varname[`i']
        local vmin_`i' = vmin[`i']
        local vmax_`i' = vmax[`i']
    }
    restore

    // Now apply bounds to synthetic data
    forvalues i = 1/`nbounds' {
        cap confirm variable `vn_`i''
        if !_rc {
            qui replace `vn_`i'' = `vmin_`i'' if `vn_`i'' < `vmin_`i'' & !missing(`vn_`i'')
            qui replace `vn_`i'' = `vmax_`i'' if `vn_`i'' > `vmax_`i'' & !missing(`vn_`i'')
        }
    }
end
```

### Reasoning

The fix loads all bounds information into indexed locals (`vn_1`, `vmin_1`, etc.) while the bounds file is loaded, then restores back to synthetic data once, and applies all bounds using the stored locals. This avoids the context-switching problem.

---

## Issue 2: CRITICAL - Skip Variable Type Detection Bug

**Severity:** Critical
**Location:** `synthdata.ado` lines 141-158 (main program) and lines 268-287 (multiple datasets loop)
**Impact:** Skip variables are always created as numeric (missing) even if originals were strings.

### Problem Analysis

When handling `skip()` variables, the code attempts to check whether each variable is a string or numeric type before recreating it in the synthetic dataset. However:

1. The synthesis methods (`_synthdata_parametric`, etc.) call `drop _all` and rebuild the dataset from scratch
2. Skip variables are excluded from synthesis, so they don't exist in the new dataset
3. The `confirm string variable` check always fails because the variable doesn't exist
4. Result: All skip variables become numeric (missing) regardless of original type

### Before (Buggy Code)

```stata
if "`skip'" != "" {
    foreach v of local skip {
        // Check type before dropping
        local is_string = 0
        cap confirm string variable `v'   // ALWAYS FAILS - variable doesn't exist!
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

### After (Fixed Code)

```stata
if "`skip'" != "" {
    foreach v of local skip {
        // Check type in ORIGINAL data (before synthesis modified dataset)
        preserve
        qui use `origdata', clear
        local is_string = 0
        cap confirm string variable `v'
        if !_rc {
            local is_string = 1
        }
        restore

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

### Reasoning

The fix loads the original data from the tempfile to check the variable's type, then restores back to the synthetic data before creating the placeholder variable. This correctly preserves the original variable type (string vs numeric) in the synthetic dataset.

---

## Issue 3: CRITICAL - `_synthdata_validate` Merge Order Bug

**Severity:** Critical
**Location:** `synthdata.ado` lines 1282-1298 (in `_synthdata_validate` program)
**Impact:** The `validate()` option fails to match variables when `prefix()` is used, resulting in empty or missing validation statistics.

### Problem Analysis

The `_synthdata_validate` program attempts to merge original statistics with synthetic statistics for comparison. However, when `prefix()` is specified, the merge fails because:

1. Synthetic variable names in `synthstats` include the prefix (e.g., `synth_price`)
2. Original variable names in `origstats` do not have the prefix (e.g., `price`)
3. The merge is performed on `varname` BEFORE removing the prefix
4. Result: No matches found, validation statistics are empty/incorrect

The correct implementation exists in `_synthdata_compare` which removes the prefix BEFORE merging.

### Before (Buggy Code)

```stata
preserve
qui use `origstats', clear
rename (mean sd min max p25 p50 p75 N) =_orig

qui merge 1:1 varname using `synthstats', nogen  // Merge BEFORE prefix removed!

// Remove prefix for matching
if "`prefix'" != "" {
    qui replace varname = subinstr(varname, "`prefix'", "", 1)  // Too late!
}

rename (mean sd min max p25 p50 p75 N) =_synth
```

### After (Fixed Code)

```stata
preserve

// Load origstats and save to tempfile
qui use `origstats', clear
rename (mean sd min max p25 p50 p75 N) =_orig
tempfile orig
qui save `orig'

// Load synthstats and remove prefix BEFORE merging
qui use `synthstats', clear
if "`prefix'" != "" {
    qui replace varname = subinstr(varname, "`prefix'", "", 1)
}
rename (mean sd min max p25 p50 p75 N) =_synth

// Now merge with matching varnames
qui merge 1:1 varname using `orig', nogen
```

### Reasoning

The fix follows the same pattern as the correct implementation in `_synthdata_compare`:
1. Load original stats, rename columns, save to tempfile
2. Load synthetic stats, remove prefix from varnames
3. Rename synthetic columns
4. THEN merge - now the varnames match

---

## Issue 4: SMCL Syntax Error in Help File

**Severity:** Medium
**Location:** `synthdata.sthlp` line 2
**Impact:** Help file may display incorrectly or cause SMCL parsing errors.

### Problem

The version comment line has corrupted SMCL syntax with an extra `*{*`:

### Before

```smcl
{* *{* *! version 1.0.0  2025/12/02}{...}
```

### After

```smcl
{* *! version 1.0.1  03dec2025}{...}
```

### Reasoning

1. Removed the erroneous `*{*` sequence that breaks SMCL parsing
2. Updated version to 1.0.1 to match .ado file
3. Changed date format to standard Stata format (03dec2025)

---

## Issue 5: Version Mismatch Between Files

**Severity:** Low
**Location:** `synthdata.sthlp` line 2
**Impact:** Inconsistent version reporting; user confusion.

### Problem

| File | Version | Date |
|------|---------|------|
| synthdata.ado | 1.0.1 | 03dec2025 |
| synthdata.sthlp | 1.0.0 | 2025/12/02 |
| synthdata.pkg | (uses Distribution-Date) | 20251203 |
| README.md | 1.0.1 | 2025-12-03 |

### Fix

Updated .sthlp to version 1.0.1 with date 03dec2025 to match .ado.

---

## Issue 6: README LICENSE Reference

**Severity:** Low
**Location:** `synthdata/README.md` line 497
**Impact:** References non-existent LICENSE file.

### Before

```markdown
MIT License - see LICENSE file for details
```

### After

```markdown
MIT License
```

### Reasoning

Per repository standards (CLAUDE.md), packages should not have separate LICENSE files. The MIT license is specified in the .pkg file and README, which is sufficient.

---

## Summary of Changes

| File | Changes Made |
|------|--------------|
| `synthdata.ado` | Fixed `_synthdata_noextreme` logic; Fixed skip variable type detection (2 locations); Fixed `_synthdata_validate` merge order bug |
| `synthdata.sthlp` | Fixed SMCL syntax error; Updated version to 1.0.1 |
| `README.md` | Removed LICENSE file reference |

---

## Testing Recommendations

After applying these fixes, test the following scenarios:

1. **noextreme option with multiple continuous variables:**
   ```stata
   sysuse auto, clear
   synthdata price mpg weight, noextreme replace seed(123)
   ```

2. **skip option with string variables:**
   ```stata
   sysuse auto, clear
   tostring make, replace
   synthdata price mpg, skip(make) replace seed(123)
   describe make   // Should be str1
   ```

3. **Multiple synthetic datasets with skip:**
   ```stata
   sysuse auto, clear
   synthdata price mpg, skip(make) multiple(3) saving(test_synth) seed(123)
   ```

4. **Help file display:**
   ```stata
   help synthdata   // Should display without SMCL errors
   ```

5. **Validate with prefix option:**
   ```stata
   sysuse auto, clear
   synthdata price mpg, prefix(s_) saving(synth) validate(validation) seed(123)
   use validation, clear
   list varname mean_orig mean_synth   // Should show matched variables
   ```

---

## Audit Complete

All identified issues have been documented and fixed. The package version remains at 1.0.1 as these are bug fixes rather than feature changes. The Distribution-Date in the .pkg file has been updated to 20251203 to ensure users receive the update.
