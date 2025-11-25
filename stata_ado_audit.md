# Stata .ado File Audit Report

## table1_tc.ado

### Issue 1: Using `by' variable when it may be empty
**Location:** Lines 230, 283

**Problem:** When no `by()` variable is specified, referencing `` `by' `` in drop statements causes errors.

**Current Code (Line 230):**
```stata
qui drop if missing(`by')  // Drop observations with missing by() values
```

**Current Code (Line 283):**
```stata
qui drop if missing(`by')  // Drop observations with missing by() values
```

**Corrected Code:**
```stata
qui drop if missing(`groupnum')  // Drop observations with missing group values
```

---

### Issue 2: Same `by' reference issue in contln section
**Location:** Line 393-394

**Current Code:**
```stata
qui drop if missing(`by')  // Drop observations with missing by() values
```

**Corrected Code:**
```stata
qui drop if missing(`groupnum')  // Drop observations with missing group values
```

---

### Issue 3: Undefined variable reference in single-group formatting
**Location:** Lines 1398-1401

**Problem:** When `groupcount==1`, the code references `Total` as if it were a variable, but `Total` is only the variable name after renaming occurs at line 1125.

**Current Code:**
```stata
if `groupcount'==1 {
    // Format for single group
    qui replace N_1 = Total if factor == " "
    qui replace m_1 = Total if factor == " "
    qui replace _columna_1 = Total if factor == " "
    qui replace _columnb_1 = Total if factor == " "
}
```

**Corrected Code:**
```stata
if `groupcount'==1 {
    // Format for single group - reference the renamed variable
    qui replace N_1 = "Total" if factor == " "
    qui replace m_1 = "Total" if factor == " "
    qui replace _columna_1 = "Total" if factor == " "
    qui replace _columnb_1 = "Total" if factor == " "
}
```

---

## stratetab.ado

### Issue 1: Massive code duplication
**Location:** Lines 196-338

**Problem:** The same code block for detecting categorical variables, converting to string, and formatting data is repeated 4 times within the file. This creates maintenance issues and bloats the file.

**Current Code Pattern (repeated 4 times):**
```stata
* Get categorical variable
unab allvars : *
local catvar ""
foreach v of local allvars {
    if "`v'" != "_D" & "`v'" != "_Y" & "`v'" != "_Rate" & "`v'" != "_Lower" & "`v'" != "_Upper" {
        local catvar "`v'"
        continue, break
    }
}

* Convert categorical to string if needed
cap confirm string var `catvar'
if _rc {
    decode `catvar', gen(catvar_str)
}
else {
    gen catvar_str = `catvar'
}

* Format data
if `eventdigits' == 0 {
    gen ev = string(_D, "%11.0fc")
}
else {
    gen ev = string(_D, "%11.`eventdigits'fc")
}
// ... etc
```

**Suggested Refactoring:** Create a helper program or move common logic outside the loop, processing all formatting once per file load.

---

### Issue 2: Commented-out column width setting
**Location:** Line 416

**Problem:** Column A width setting is commented out, making it inconsistent with other columns.

**Current Code:**
```stata
*mata: b.set_column_width(1,1,`col_a_width')
```

**Corrected Code (if intentional, remove entirely; if needed, uncomment):**
```stata
mata: b.set_column_width(1,1,`col_a_width')
```

---

## regtab.ado

### Issue 1: Empty else blocks
**Location:** Lines 92-94, 98-100

**Problem:** Empty `else` blocks serve no purpose and reduce readability.

**Current Code:**
```stata
if !missing(`noint') {
    drop if inlist(strlower(strtrim(A)), "intercept", "_cons", "constant", "Intercept")
}
else {

}
if !missing(`nore'){
drop if strpos(A,"var(")
}
else {

}
```

**Corrected Code:**
```stata
if !missing(`noint') {
    drop if inlist(strlower(strtrim(A)), "intercept", "_cons", "constant", "Intercept")
}

if !missing(`nore') {
    drop if strpos(A,"var(")
}
```

---

## datefix.ado

### Issue 1: Observation-level vs variable-level missing check
**Location:** Lines 184-188

**Problem:** The condition `if missing(new) & !missing(`var')` operates on the entire variable, not per-observation. This check occurs outside a loop/count context.

**Current Code:**
```stata
if missing(new) & !missing(`var'){
    di in re "Optimal ordering of Year, Month, and Day producing missing values."
    di in re "Check ordering, number of year digits, and for non-date strings."
    di in re "If year is in two digit format, use topyear() option."
    quietly drop new
    exit 198
}
```

**Corrected Code:**
```stata
qui count if missing(new) & !missing(`var')
if r(N) > 0 {
    di in re "Optimal ordering of Year, Month, and Day produced `r(N)' missing values."
    di in re "Check ordering, number of year digits, and for non-date strings."
    di in re "If year is in two digit format, use topyear() option."
    quietly drop new
    exit 198
}
```

---

### Issue 2: Reference to potentially non-existent variable
**Location:** Line 193

**Problem:** `tmp_orig` is created inside the `else` block (line 147) but cleaned up at lines 175-177, so this reference may fail.

**Current Code:**
```stata
*Retrieve original variable if original variable was a date
quietly capture replace new = tmp_orig if new == .
```

**Corrected Code:** Remove this line entirely as it references a variable that no longer exists after cleanup:
```stata
* (Line removed - tmp_orig is dropped earlier in the block)
```

---

### Issue 3: Incorrect order of capture and quietly
**Location:** Line 251

**Problem:** `capture` inside `quietly` means errors are suppressed but the quiet state may break on error.

**Current Code:**
```stata
quietly capture drop new
```

**Corrected Code:**
```stata
capture quietly drop new
```

---

## check.ado

### Issue 1: Overly restrictive version requirement
**Location:** Line 10

**Problem:** Requiring version 18.0 unnecessarily restricts users on older Stata versions when the code likely works on 14+.

**Current Code:**
```stata
version 18.0
```

**Corrected Code:**
```stata
version 14.0
```

---

### Issue 2: Incorrect comment
**Location:** Line 46

**Problem:** Comment says "At least 4 characters due to 'Varname'" but 'Varname' is 7 characters.

**Current Code:**
```stata
local maxlen = max(`max',4)  // At least 4 characters due to "Varname" 
```

**Corrected Code:**
```stata
local maxlen = max(`max',7)  // At least 7 characters due to "Varname"
```

---

## cstat_surv.ado

### Issue 1: Unusual syntax declaration
**Location:** Line 8

**Problem:** `syntax ,` with trailing comma and no options is unusual and could cause parsing issues.

**Current Code:**
```stata
syntax ,
```

**Corrected Code:**
```stata
syntax
```

---

## today.ado

No significant issues found. Code is well-structured with proper validation.

---

## Summary

| File | Issues Found | Severity |
|------|--------------|----------|
| table1_tc.ado | 3 | Medium-High |
| stratetab.ado | 2 | Low-Medium |
| regtab.ado | 2 | Low |
| datefix.ado | 3 | Medium |
| check.ado | 2 | Low |
| cstat_surv.ado | 1 | Low |
| today.ado | 0 | None |
