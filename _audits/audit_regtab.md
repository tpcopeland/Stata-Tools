# Audit Report: regtab.ado

**Date:** 2025-12-03
**Auditor:** Claude (Automated Code Review)
**File:** /home/user/Stata-Tools/regtab/regtab.ado
**Version Audited:** 1.0.0

---

## Executive Summary

The regtab.ado file was audited against Stata coding standards documented in CLAUDE.md. The audit identified **3 critical issues**, **4 high-severity issues**, **3 medium-severity issues**, and **2 low-severity issues**.

The most critical findings are:
1. Missing `version` declaration in helper program `col_to_letter`
2. Missing `set varabbrev off` in helper program `col_to_letter`
3. Incomplete version declaration in main program (should be `17.0` not `17`)

All critical and high-severity issues should be addressed immediately. Medium and low-severity issues are recommended improvements.

---

## Critical Issues

### Issue 1: Missing version declaration in col_to_letter program
**Line:** 25
**Severity:** Critical
**Category:** Missing version declaration

**Description:**
The helper program `col_to_letter` does not include a `version` statement. According to CLAUDE.md Critical Rules, ALL programs must set a version.

**Current Code:**
```stata
program col_to_letter
	args col_num
	local col_letter = ""
```

**Proposed Fix:**
```stata
program col_to_letter
	version 17.0
	args col_num
	local col_letter = ""
```

**Necessity:** Required - This ensures the program behavior is locked to a specific Stata version and prevents future compatibility issues.

---

### Issue 2: Missing set varabbrev off in col_to_letter program
**Line:** 25
**Severity:** Critical
**Category:** Missing varabbrev setting

**Description:**
The helper program `col_to_letter` does not include `set varabbrev off`. According to CLAUDE.md Critical Rules, this should always be set.

**Current Code:**
```stata
program col_to_letter
	args col_num
	local col_letter = ""
```

**Proposed Fix:**
```stata
program col_to_letter
	version 17.0
	set varabbrev off
	args col_num
	local col_letter = ""
```

**Necessity:** Required - While this program doesn't use variable names, maintaining consistency across all programs is critical for maintainability.

---

### Issue 3: Incomplete version declaration in main program
**Line:** 38
**Severity:** Critical
**Category:** Version declaration format

**Description:**
The main program uses `version 17` instead of `version 17.0`. Per CLAUDE.md standards, version should always include the minor version.

**Current Code:**
```stata
program define regtab, rclass
version 17
set varabbrev off
```

**Proposed Fix:**
```stata
program define regtab, rclass
	version 17.0
	set varabbrev off
```

**Necessity:** Required - Ensures maximum compatibility and follows Stata best practices.

---

## High-Severity Issues

### Issue 4: No validation of collect table structure
**Lines:** 79-86
**Severity:** High
**Category:** Input validation

**Description:**
The code assumes the collect table contains the required dimensions (cmdset, colname) and results (_r_b, _r_ci, _r_p) but does not validate this before attempting to use them.

**Current Code:**
```stata
collect label levels result _r_b "`coef'", modify
collect style cell result[_r_b], warn nformat(%4.2fc) halign(center) valign(center)
collect style cell result[_r_ci], warn nformat(%4.2fc) sformat("(%s)") cidelimiter("`sep'") halign(center) valign(center)
```

**Proposed Fix:**
```stata
* Validate collect table has required items
capture collect query result
if _rc {
	noisily display as error "Collect table missing result dimension"
	exit 119
}

local has_rb = 0
local has_rci = 0
local has_rp = 0
foreach item in _r_b _r_ci _r_p {
	capture collect query levels result
	if !_rc {
		if strpos("`r(levels)'", "`item'") > 0 {
			if "`item'" == "_r_b" local has_rb = 1
			if "`item'" == "_r_ci" local has_rci = 1
			if "`item'" == "_r_p" local has_rp = 1
		}
	}
}
if !`has_rb' | !`has_rci' | !`has_rp' {
	noisily display as error "Collect table must contain _r_b, _r_ci, and _r_p"
	noisily display as error "Run regression with: collect: regress ..."
	exit 119
}

collect label levels result _r_b "`coef'", modify
```

**Necessity:** Recommended - Would provide better error messages but adds complexity. The current approach will fail with a Stata error if items are missing, which may be acceptable.

---

### Issue 5: No error handling for import excel
**Line:** 88
**Severity:** High
**Category:** Error handling

**Description:**
The `import excel` command is not wrapped in error handling. If the import fails, the program will error without cleanup.

**Current Code:**
```stata
collect export "`temp_xlsx'", sheet(temp,replace) modify

import excel "`temp_xlsx'", sheet(temp) clear
if "`noint'" != "" {
```

**Proposed Fix:**
```stata
collect export "`temp_xlsx'", sheet(temp,replace) modify

capture import excel "`temp_xlsx'", sheet(temp) clear
if _rc {
	noisily display as error "Failed to import temporary Excel file"
	capture erase "`temp_xlsx'"
	exit _rc
}

if "`noint'" != "" {
```

**Necessity:** Recommended - Improves error handling and cleanup, but import excel rarely fails if export succeeded.

---

### Issue 6: No error handling for collect export
**Line:** 86
**Severity:** High
**Category:** Error handling

**Description:**
The `collect export` command is not wrapped in error handling. If the export fails, the program will error without cleanup.

**Current Code:**
```stata
collect layout (colname) (cmdset#result[_r_b _r_ci _r_p]) ()
collect export "`temp_xlsx'", sheet(temp,replace) modify
```

**Proposed Fix:**
```stata
collect layout (colname) (cmdset#result[_r_b _r_ci _r_p]) ()

capture collect export "`temp_xlsx'", sheet(temp,replace) modify
if _rc {
	noisily display as error "Failed to export collect table to temporary Excel file"
	noisily display as error "Check that collect table is properly structured"
	exit _rc
}
```

**Necessity:** Recommended - Provides clearer error messages if the export fails.

---

### Issue 7: No error handling for final export excel
**Line:** 168
**Severity:** High
**Category:** Error handling

**Description:**
The final `export excel` command is not wrapped in error handling.

**Current Code:**
```stata
replace title = "`title'" if _n == 1
export excel using "`xlsx'", sheet("`sheet'") sheetreplace

local num_rows = _N
```

**Proposed Fix:**
```stata
replace title = "`title'" if _n == 1

capture export excel using "`xlsx'", sheet("`sheet'") sheetreplace
if _rc {
	noisily display as error "Failed to export to `xlsx', sheet `sheet'"
	noisily display as error "Check file permissions and that file is not open in Excel"
	capture erase "`temp_xlsx'"
	exit _rc
}

local num_rows = _N
```

**Necessity:** Recommended - Excel export can fail if file is open or permissions issues. Better error message helps users.

---

## Medium-Severity Issues

### Issue 8: Inconsistent date format in version header
**Line:** 1
**Severity:** Medium
**Category:** Style/Convention

**Description:**
The version header uses "2025/12/02" format instead of Stata's conventional "02dec2025" format.

**Current Code:**
```stata
*! regtab Version 1.0.0  2025/12/02
```

**Proposed Fix:**
```stata
*! regtab Version 1.0.1  03dec2025
```

**Necessity:** Optional - Style preference. Current format is readable but non-standard for Stata.

---

### Issue 9: No file path sanitization
**Lines:** 64-68
**Severity:** Medium
**Category:** Security

**Description:**
While the code checks for `.xlsx` extension, it doesn't sanitize the file path for dangerous characters that could cause injection issues.

**Current Code:**
```stata
* Validation: Check if file name has .xlsx extension
if !strmatch("`xlsx'", "*.xlsx") {
	noisily display as error "Excel filename must have .xlsx extension"
	exit 198
}
```

**Proposed Fix:**
```stata
* Validation: Check if file name has .xlsx extension
if !strmatch("`xlsx'", "*.xlsx") {
	noisily display as error "Excel filename must have .xlsx extension"
	exit 198
}

* Validation: Check for dangerous characters in file path
if regexm("`xlsx'", "[;&|><\$\`]") {
	noisily display as error "Excel filename contains invalid characters"
	exit 198
}
if regexm("`sheet'", "[;&|><\$\`]") {
	noisily display as error "Sheet name contains invalid characters"
	exit 198
}
```

**Necessity:** Recommended - Adds security layer against potential injection, though risk is low in this context.

---

### Issue 10: Fixed-width string declaration may be too short
**Line:** 144
**Severity:** Medium
**Category:** Data handling

**Description:**
The string variable for formatted p-values is declared as `str20` which should be sufficient, but using dynamic string type would be more robust.

**Current Code:**
```stata
destring c`i', gen(c`i'z) force
gen str20 c`i'_fmt = ""
* Handle very small p-values
```

**Proposed Fix:**
```stata
destring c`i', gen(c`i'z) force
gen c`i'_fmt = ""
* Handle very small p-values
```

**Necessity:** Optional - str20 is sufficient for p-value formatting. Modern Stata defaults to appropriate string type.

---

## Low-Severity Issues

### Issue 11: Redundant required option validation
**Lines:** 52-62
**Severity:** Low
**Category:** Code efficiency

**Description:**
The code explicitly checks if `xlsx()` and `sheet()` are provided, but these are already enforced as required by the `syntax` statement.

**Current Code:**
```stata
* Validation: Check if xlsx option is provided (should be enforced by syntax)
if "`xlsx'" == "" {
	noisily display as error "xlsx() option required"
	exit 198
}

* Validation: Check if sheet option is provided (should be enforced by syntax)
if "`sheet'" == "" {
	noisily display as error "sheet() option required"
	exit 198
}
```

**Proposed Fix:**
```stata
* Remove these redundant checks - syntax already enforces required options
```

**Necessity:** Optional - The checks are redundant but harmless. Could be removed for cleaner code.

---

### Issue 12: No tempvar for reference row variables
**Lines:** 201-210
**Severity:** Low
**Category:** Code style

**Description:**
Variables `ref1`, `ref3`, etc. are created to track reference rows but aren't declared as tempvars. While they're cleaned up by the `clear` command, using tempvar would be more explicit.

**Current Code:**
```stata
forvalues i = 1(3)`last'{
gen ref`i' = _n if c`i' == "Reference"
order ref`i', after(c`i')
levelsof ref`i', local(ref`i'_levels)
}
```

**Proposed Fix:**
```stata
forvalues i = 1(3)`last'{
tempvar ref`i'
gen `ref`i'' = _n if c`i' == "Reference"
levelsof `ref`i'', local(ref`i'_levels)
}
```

**Necessity:** Optional - Current code works fine since data is cleared anyway. Using tempvar would be more formally correct but adds minimal value here.

---

## Summary of Required Fixes

**Must Fix (Critical):**
1. Add `version 17.0` to col_to_letter program
2. Add `set varabbrev off` to col_to_letter program
3. Change `version 17` to `version 17.0` in main program

**Recommended (High):**
4. Add error handling for collect export (line 86)
5. Add error handling for import excel (line 88)
6. Add error handling for final export excel (line 168)

**Optional (Medium/Low):**
7. Update date format to Stata convention
8. Add file path sanitization
9. Remove redundant option checks
10. Change str20 to dynamic string type

---

## Testing Recommendations

After implementing fixes:

1. Test with a simple collect table:
```stata
sysuse auto, clear
collect clear
collect: regress price mpg weight
regtab, xlsx(test.xlsx) sheet(Test)
```

2. Test error conditions:
```stata
* Test with no collect table
collect clear
capture noisily regtab, xlsx(test.xlsx) sheet(Test)
assert _rc != 0

* Test with invalid filename
collect: regress price mpg
capture noisily regtab, xlsx(test.txt) sheet(Test)
assert _rc == 198
```

3. Test with multiple models and options:
```stata
collect clear
collect: regress price mpg
collect: regress price mpg weight
regtab, xlsx(test.xlsx) sheet(Models) models(Model 1 \ Model 2) ///
    coef(Coef) title(Test Table) noint
```

---

## Conclusion

The regtab.ado file is generally well-written with good error handling in the Excel formatting sections. The critical issues are straightforward to fix and involve adding standard declarations to the helper program. The high-severity issues would improve error messages and user experience but the current code will still fail safely in most cases.

**Recommended Action:** Implement all Critical fixes and the High-severity error handling improvements.
