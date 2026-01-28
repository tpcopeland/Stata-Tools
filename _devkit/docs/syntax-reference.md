# Stata Syntax Reference

Comprehensive syntax patterns and extended macro functions for Stata package development.

---

## Macro References

### Basic Syntax

```stata
local varname "price"
display "`varname'"              // Correct: backtick + quote

local a = 1
local b1 "test"
display "`b`a''"                 // Nested: evaluates inside-out → "test"

if `condition' {                 // Correct: no spaces inside backticks
}
```

### CRITICAL: 31-Character Limit

Macro names longer than 31 characters are silently truncated. This causes subtle bugs where two differently-named macros become the same:

```stata
// WRONG - both truncate to same 31-char name!
local very_long_descriptive_name_one = 1
local very_long_descriptive_name_two = 2
display `very_long_descriptive_name_one'  // Shows 2, not 1!

// CORRECT - use shorter names
local desc_name_one = 1
local desc_name_two = 2
```

**Common mistakes:**
- Spaces in macros (`` `var list' ``)
- Missing backticks (`if condition`)
- Macro names >31 chars

---

## Syntax Statement Patterns

### Basic Patterns

```stata
// Basic varlist with if/in
syntax varlist [if] [in] [, options]

// Constrained varlist
syntax varlist(numeric min=2 max=2) [if] [in]

// With using file
syntax using/ [, options]

// With optional varlist and using
syntax [varlist] using/ [, Replace]

// Required option (uppercase = abbreviation)
syntax varlist [, REQuired optional]

// With weights
syntax varlist [aw fw pw iw] [if] [in] [, options]
```

### Complex Options

```stata
syntax [varlist] [if] [in] [, ///
    by(varlist)           /// Grouping variable
    GENerate(name)        /// New variable name
    NOisily               /// Show detailed output
    Level(cilevel)        /// Confidence level
    Format(string)        /// Display format
    SAVing(string)        /// Output filename
    Replace               /// Overwrite existing
    ]
```

### Option Types

| Type | Syntax | Usage |
|------|--------|-------|
| `string` | `name(string)` | Any text |
| `name` | `generate(name)` | Valid Stata name |
| `varname` | `by(varname)` | Existing variable |
| `varlist` | `vars(varlist)` | Multiple variables |
| `numlist` | `cuts(numlist)` | List of numbers |
| `integer` | `n(integer 1)` | Integer with default |
| `real` | `tol(real 0.001)` | Real with default |
| `cilevel` | `level(cilevel)` | Confidence level (default: 95) |
| `passthru` | `options(string asis)` | Pass through verbatim |

---

## Sample Marking

### marksample and markout

```stata
// Mark main sample (handles if/in and varlist missing)
marksample touse

// Also mark out option variables (use AFTER marksample)
markout `touse' `byvar' `idvar'

// Check observations
quietly count if `touse'
if r(N) == 0 {
    display as error "no observations"
    exit 2000
}
local n = r(N)
```

### When to Use markout

Use `markout` for variables specified in options, not in the main varlist:

```stata
syntax varlist [if] [in], by(varname) [idvar(varname)]

marksample touse           // Handles varlist + if/in
markout `touse' `by'       // Required option - must be non-missing
if "`idvar'" != "" {
    markout `touse' `idvar'  // Optional - only if specified
}
```

---

## Extended Macro Functions

### Word Functions

```stata
local n: word count `varlist'              // Count words
local first: word 1 of `varlist'           // Get first word
local last: word `n' of `varlist'          // Get last word
```

### Type Functions

```stata
local type: type `varname'                 // Variable type (byte, int, float, double, str#)
local format: format `varname'             // Display format
local label: variable label `varname'      // Variable label
local vallabel: value label `varname'      // Value label name
```

### List Functions

```stata
local exists: list var in varlist          // Check membership (1 or 0)
local unique: list uniq mylist             // Remove duplicates
local count: list sizeof mylist            // Count elements
local sorted: list sort mylist             // Sort alphabetically
local combined: list list1 | list2         // Union
local common: list list1 & list2           // Intersection
local diff: list list1 - list2             // Difference
```

### Directory Functions

```stata
local files: dir "." files "*.dta"         // List .dta files
local subdirs: dir "." dirs "*"            // List subdirectories
```

---

## gettoken Parsing

### Basic Usage

```stata
local mylist "apple banana cherry"
gettoken first rest : mylist               // first="apple", rest="banana cherry"
```

### Loop Through List

```stata
local mylist "a b c d e"
while "`mylist'" != "" {
    gettoken element mylist : mylist
    display "`element'"
}
```

### Parse with Delimiter

```stata
local opts "name=value, option2=test"
gettoken part1 part2 : opts, parse(",")
// part1 = "name=value", part2 = ", option2=test"
```

### Parse Option Pairs

```stata
local input "var1=label1 var2=label2"
while "`input'" != "" {
    gettoken pair input : input
    gettoken varname label : pair, parse("=")
    gettoken eq label : label, parse("=")
    display "Variable: `varname', Label: `label'"
}
```

---

## Program Classes

| Class | Use Case | Returns |
|-------|----------|---------|
| `rclass` | General commands | `return scalar/local/matrix` |
| `eclass` | Estimation commands | `ereturn post/scalar/local` |
| `sclass` | String parsing | `sreturn local` |
| `nclass` | No returns | Nothing stored |

### rclass Returns

```stata
program define mycommand, rclass
    // ... computation ...

    return scalar N = `n'
    return scalar mean = `mean_val'
    return local varlist "`varlist'"
    return matrix results = `results_matrix'
end
```

### eclass Returns

```stata
program define myestimate, eclass
    // ... estimation ...

    ereturn post `b' `V', obs(`n') esample(`touse')
    ereturn scalar N = `n'
    ereturn local cmd "myestimate"
    ereturn local depvar "`depvar'"
end
```

### byable and sortpreserve

```stata
program define mycommand, rclass byable(recall) sortpreserve
    // byable(recall): re-called for each by-group
    // sortpreserve: restores original sort order on exit

    if _by() {
        local byvar "`_byvars'"
    }
end
```

---

## Error Handling

### capture Patterns

```stata
// Capture and check return code
capture regress y x1 x2
if _rc != 0 {
    display as error "Failed with error `_rc'"
    exit _rc
}

// Show output but don't stop on error
capture noisily regress y x1 x2

// Capture specific error
capture confirm variable myvar
if _rc == 111 {
    display as error "Variable myvar not found"
    exit 111
}
```

### Validation with confirm

```stata
// Confirm variable exists
capture confirm variable myvar
if _rc != 0 exit 111

// Confirm numeric variable
capture confirm numeric variable myvar
if _rc != 0 exit 109

// Confirm file exists
capture confirm file "data.dta"
if _rc != 0 exit 601

// Confirm new variable name is available
capture confirm new variable myvar
if _rc != 0 {
    display as error "Variable myvar already exists"
    exit 110
}
```

### Common Error Codes

| Code | Meaning | Typical Cause |
|------|---------|---------------|
| 100 | varlist required | Missing required varlist |
| 101 | varlist not allowed | varlist provided when not expected |
| 109 | type mismatch | Wrong variable type |
| 110 | already defined | Variable/program exists |
| 111 | not found | Variable/file doesn't exist |
| 198 | invalid syntax | Syntax error |
| 199 | unrecognized command | Command not installed |
| 601 | file not found | Path incorrect |
| 602 | file already exists | Missing replace option |
| 2000 | no observations | Empty data or if condition excludes all |
| 2001 | insufficient observations | Not enough obs for operation |

---

## preserve and restore

### Basic Usage

```stata
program define mycommand, rclass
    // Parse and validate BEFORE preserve
    marksample touse

    preserve                              // Save data state
    keep if `touse'
    // ... modify data ...
    restore                               // Automatic at program end
end
```

### CRITICAL WARNING

Variables created inside `preserve`/`restore` are **lost** when `restore` runs!

```stata
// WRONG - variable disappears after restore!
preserve
gen double result = x * 2
restore    // result is gone!

// CORRECT - don't use preserve when generating variables
gen double result = x * 2 if `touse'
```

**When to use preserve:**
- Estimation/reporting commands that need to temporarily modify data structure
- Operations like `collapse`, `reshape` that you need to undo
- Commands that don't create user-visible variables

**When NOT to use preserve:**
- Commands with `generate()` option
- Any command creating permanent output variables

---

## Temporary Objects

### tempvar - Temporary Variables

```stata
tempvar result flag counter

gen double `result' = .
gen byte `flag' = 0
gen long `counter' = _n

// Variables automatically dropped at program end
```

### tempfile - Temporary Files

```stata
tempfile merged subset original

save `original'
// ... process ...
use `merged', clear

// Files automatically deleted at program end
```

### tempname - Temporary Scalars/Matrices

```stata
tempname mean_val cov_matrix b V

scalar `mean_val' = r(mean)
matrix `cov_matrix' = e(V)
matrix `b' = e(b)
matrix `V' = e(V)

// Names automatically cleared at program end
```

---

## Loops and Control Flow

### forvalues

```stata
forvalues i = 1/10 {
    display `i'
}

forvalues yr = 2000(5)2020 {    // 2000, 2005, 2010, 2015, 2020
    use "data_`yr'.dta"
}
```

### foreach

```stata
// Over varlist
foreach var of varlist price mpg weight {
    summarize `var'
}

// Over local list
local vars "a b c"
foreach v of local vars {
    display "`v'"
}

// Over numlist
foreach n of numlist 1 2 5 10 20 {
    display `n'
}

// Generic list (space-separated)
foreach word in apple banana cherry {
    display "`word'"
}
```

### while

```stata
local i = 1
while `i' <= 10 {
    display `i'
    local ++i
}
```

---

*See also: `_devkit/docs/template-guide.md` for complete file templates*
