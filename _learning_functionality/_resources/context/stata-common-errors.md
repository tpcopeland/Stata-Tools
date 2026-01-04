# Stata Common Errors Reference

> **Purpose:** Document common Stata coding errors and their fixes. This file is updated each time a new package encounters errors during testing.

**Last Updated:** 2026-01-04
**Source:** Accumulated from package development

---

## 1. Batch Mode Incompatible Commands

### Error
```
command cls is unrecognized
r(199)
```

### Cause
Commands like `cls` (clear screen) only work in interactive Stata, not batch mode (`stata-mp -b do file.do`).

### Solution
```stata
* WRONG
cls

* CORRECT
* cls  // Not valid in batch mode
```

### Incompatible Commands
- `cls` - Clear screen
- `pause` - Interactive pause
- `window manage` - GUI commands
- `browse` - Data browser
- `edit` - Data editor

---

## 2. Function in bysort Sort Specification

### Error
```
coding operators not allowed
r(198)
```

### Cause
Stata's `bysort` does not allow functions in the sort specification parentheses.

### Solution
```stata
* WRONG
bysort id (abs(diff)): keep if _n == 1

* CORRECT
gen abs_diff = abs(diff)
bysort id (abs_diff): keep if _n == 1
drop abs_diff
```

---

## 3. String Repetition Syntax

### Error
```
-*60 invalid name
r(198)
```

### Cause
Stata does not support Python-style string multiplication.

### Solution
```stata
* WRONG
di "-" * 60
di "=" * 60

* CORRECT
di _dup(60) "-"
di _dup(60) "="
```

---

## 4. Merge with nogen Then Reference _merge

### Error
```
variable _merge not found
r(111)
```

### Cause
Using `nogen` option suppresses creation of `_merge` variable.

### Solution
```stata
* WRONG
merge 1:1 id using file, nogen
tab _merge  // FAILS - _merge doesn't exist

* CORRECT (if you need _merge)
merge 1:1 id using file, keep(1 3)
tab _merge
drop _merge

* CORRECT (if you don't need _merge)
merge 1:1 id using file, nogen keep(3)
// Don't reference _merge
```

---

## 5. Wildcard in use Command

### Error
```
file not found
r(601)
```

### Cause
Stata's `use` command does not support wildcards like `*.dta`.

### Solution
```stata
* WRONG
use "$source/rx_*.dta", clear

* CORRECT - Loop with append
clear
local first = 1
forvalues yr = $start_year/$end_year {
    capture confirm file "$source/rx_`yr'.dta"
    if _rc == 0 {
        if `first' == 1 {
            use "$source/rx_`yr'.dta", clear
            local first = 0
        }
        else {
            append using "$source/rx_`yr'.dta"
        }
    }
}
```

---

## 6. Correct Patterns Reference

### Character Repetition
```stata
di _dup(60) "-"
di _dup(60) "="
di _dup(40) "*"
```

### Function-Based Sorting
```stata
* For absolute value sorting
gen temp_abs = abs(var)
bysort id (temp_abs): keep if _n == 1
drop temp_abs

* For date difference sorting
gen temp_diff = abs(date1 - date2)
bysort id (temp_diff): keep if _n == 1
drop temp_diff
```

### Safe Merge Pattern
```stata
* When you need to check _merge
merge 1:1 id using file
tab _merge
keep if _merge == 3
drop _merge

* When you don't need _merge
merge 1:1 id using file, nogen keep(3)
```

### Multiple Year File Loading
```stata
clear
local first = 1
forvalues yr = 2005/2024 {
    capture confirm file "$source/data_`yr'.dta"
    if _rc == 0 {
        if `first' == 1 {
            use "$source/data_`yr'.dta", clear
            local first = 0
        }
        else {
            append using "$source/data_`yr'.dta"
        }
    }
}
if `first' == 1 {
    di as error "No data files found!"
    exit 1
}
```

---

## 7. Common Syntax Errors

### Missing Comma in Options

```stata
* WRONG
command varlist option1(x) option2(y)

* CORRECT
command varlist, option1(x) option2(y)
```

### Incorrect Quote Usage

```stata
* WRONG - mixing quotes
local x = "value'

* CORRECT
local x = "value"
local x = `"value"'
```

### Variable vs String in if

```stata
* WRONG - comparing variable to unquoted string
keep if status == active

* CORRECT
keep if status == "active"
```

---

## 8. Package-Specific Issues

### Program Already Defined (r(110))

```stata
* WRONG
program define mycommand
    ...
end
program define mycommand  // Running again without dropping
    ...
end

* CORRECT
capture program drop mycommand
program define mycommand
    ...
end
```

### Return Values in Programs

```stata
* WRONG - returning outside of program
return scalar N = 100

* CORRECT - inside program with rclass
program define mycommand, rclass
    ...
    return scalar N = 100
end
```

---

## Update Log

| Date | Package | Errors Added |
|------|---------|--------------|
| 2026-01-04 | Initial | Batch mode, bysort functions, string repetition, merge nogen, wildcards |

---

## Adding New Patterns

When you discover a new error pattern:

1. Add it to this file with:
   - Error message
   - Cause
   - Before/After code
   - Explanation

2. Update the Update Log at bottom

3. Consider updating skill files if the pattern is critical
