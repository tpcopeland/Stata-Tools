# Code Audit: datamap.ado

## Issue 1: Unsupported Format Options Accepted

**Location:** Lines 102-108

**Problem:** The syntax accepts `json` and `markdown` formats, but these are never implemented - only `text` format is actually used throughout the code.

**Current Code:**
```stata
if !inlist("`format'", "text", "json", "markdown", "md") {
    noisily di as error "format must be text, json, or markdown"
    exit 198
}
// Normalize markdown format
if "`format'" == "md" local format "markdown"
```

**Corrected Code:**
```stata
if !inlist("`format'", "text") {
    noisily di as error "format() currently only supports 'text'"
    exit 198
}
```

---

## Issue 2: Invalid `datasignature using` Syntax

**Location:** Lines 562-565

**Problem:** `datasignature` does not accept a `using` clause. Must load the data first, then compute signature.

**Current Code:**
```stata
// Add datasignature for versioning
capture datasignature using "`filepath'"
if _rc == 0 {
    file write `fh' "Data Signature: `r(datasignature)'" _n
}
```

**Corrected Code:**
```stata
// Add datasignature for versioning
// Note: datasignature requires data to be loaded (done in GenerateDatasetSummary)
quietly {
    preserve
    use "`filepath'", clear
    capture datasignature
    if _rc == 0 {
        local dsig "`r(datasignature)'"
        restore
        file write `fh' "Data Signature: `dsig'" _n
    }
    else {
        restore
    }
}
```

---

## Issue 3: Potential Division by Zero in Skewness Calculation

**Location:** Lines 1086-1087

**Problem:** If standard deviation is zero (constant variable), division by zero occurs.

**Current Code:**
```stata
// Check for skewness
local skew = (`mean' - `p50') / `sd'
if abs(`skew') > 1 {
```

**Corrected Code:**
```stata
// Check for skewness
if `sd' > 0 {
    local skew = (`mean' - `p50') / `sd'
    if abs(`skew') > 1 {
        file write `fh' "Distribution appears skewed - consider transformation. "
    }
}
```

---

## Issue 4: Variable Name Collision in ProcessBinary

**Location:** Lines 1429, 1445, 1466

**Problem:** `vlab` is used for both variable label and later as the value label text, causing potential confusion and incorrect output.

**Current Code:**
```stata
local vlab = varlabel[`i']
...
file write `fh' "`vname'"
if `"`vlab'"' != "" file write `fh' ": `vlab'"
...
capture local vlab : label (`vname') `val'
if _rc == 0 & "`vlab'" != "" {
    file write `fh' "    `val' (`vlab'): `freq' (`pct'%)" _n
```

**Corrected Code:**
```stata
local vlab = varlabel[`i']
...
file write `fh' "`vname'"
if `"`vlab'"' != "" file write `fh' ": `vlab'"
...
capture local vallabtext : label (`vname') `val'
if _rc == 0 & "`vallabtext'" != "" {
    file write `fh' "    `val' (`vallabtext'): `freq' (`pct'%)" _n
```

---

## Issue 5: ProcessSamples References Wrong Dataset

**Location:** Lines 1527-1531

**Problem:** After loading `filepath`, code tries to access `varname[`i']` which is a variable from `varinfo` dataset, not the user's data.

**Current Code:**
```stata
use "`filepath'", clear
...
quietly describe
local allvars ""
forvalues i = 1/`r(k)' {
    local vn = varname[`i']
    local allvars "`allvars' `vn'"
}
```

**Corrected Code:**
```stata
use "`filepath'", clear
...
quietly describe, varlist
local allvars `r(varlist)'
```

---

## Issue 6: Missing Check for Empty Sort Order

**Location:** Line 569

**Problem:** `r(sortlist)` is accessed without checking if it exists or is empty first.

**Current Code:**
```stata
capture describe using "`filepath'", short
if r(sortlist) != "" {
    file write `fh' "Sort Order: `r(sortlist)'" _n
}
```

**Corrected Code:**
```stata
capture describe using "`filepath'", short
if _rc == 0 & "`r(sortlist)'" != "" {
    file write `fh' "Sort Order: `r(sortlist)'" _n
}
```

---

## Issue 7: Redundant File Loads in ProcessCategorical

**Location:** Lines 957-981

**Problem:** Dataset is loaded inside the loop, which resets to `catdata` at end of each iteration. This is correct but inefficient - could batch process.

**Observation (Minor):** This is a performance issue, not a bug. Consider loading once and using `preserve`/`restore` for efficiency.

---

## Issue 8: IQR Edge Case Not Handled

**Location:** Lines 1092-1099

**Problem:** If IQR is exactly 0 (all values at same quartile), the outlier bounds calculation is meaningless.

**Current Code:**
```stata
local iqr = `p75' - `p25'
if `iqr' > 0 {
    local lower = `p25' - 3*`iqr'
    local upper = `p75' + 3*`iqr'
```

**Assessment:** Current code correctly handles this with `if `iqr' > 0`. No change needed.

---

## Summary

| Issue | Severity | Type |
|-------|----------|------|
| 1. Unsupported formats | Medium | Logic error |
| 2. Invalid datasignature syntax | High | Runtime error |
| 3. Division by zero | High | Runtime error |
| 4. Variable name collision | Medium | Logic error |
| 5. Wrong dataset reference | High | Runtime error |
| 6. Missing empty check | Low | Defensive coding |
