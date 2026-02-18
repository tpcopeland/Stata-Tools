# Syntax Patterns Reference

## Basic Patterns

```stata
// Basic varlist with if/in
syntax varlist(min=1 max=2) [if] [in]

// With using file
syntax [varlist] using/ [, Replace]

// Complex options
syntax [varlist] [if] [in] [, ///
    by(varlist)           /// Grouping variable
    GENerate(name)        /// New variable name
    NOisily               /// Show detailed output
    Level(cilevel)        /// Confidence level
    ]

// With weights
syntax varlist [aw fw pw iw] [if] [in] [, options]

// Required option (uppercase letters = abbreviation)
syntax varlist, REQuired(string) [optional]
```

## Option Types

| Type | Example | Usage |
|------|---------|-------|
| `string` | `name(string)` | Any text |
| `name` | `generate(name)` | Valid Stata name |
| `varname` | `by(varname)` | Existing variable |
| `varlist` | `vars(varlist)` | Multiple variables |
| `numlist` | `cuts(numlist)` | List of numbers |
| `integer` | `n(integer 1)` | Integer with default |
| `real` | `tol(real 0.001)` | Real with default |
| `cilevel` | `level(cilevel)` | Confidence level |

## Sample Marking

```stata
marksample touse
markout `touse' `byvar' `idvar'
quietly count if `touse'
if r(N) == 0 {
    display as error "no observations"
    exit 2000
}
```

## Common Code Patterns

```stata
// Safe file loading (multiple yearly files)
clear
local first = 1
forvalues yr = 2005/2024 {
    capture confirm file "`source'/data_`yr'.dta"
    if _rc == 0 {
        if `first' == 1 {
            use "`source'/data_`yr'.dta", clear
            local first = 0
        }
        else {
            append using "`source'/data_`yr'.dta"
        }
    }
}

// Character repetition (NOT "=" * 60)
di _dup(60) "="

// Function-based sorting (NOT bysort id (abs(var)))
gen temp_abs = abs(var)
bysort id (temp_abs): keep if _n == 1
drop temp_abs

// Return values
return scalar N = `n'
return local varlist "`varlist'"
return matrix results = `results_matrix'
```
