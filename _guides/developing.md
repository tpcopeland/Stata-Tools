# Guide: Developing Stata Commands

**Purpose**: Step-by-step process for creating new Stata commands (`.ado` files) in this repository.

---

## Overview

Developing a Stata command involves four phases:
1. **Design** - Define what the command does and its syntax
2. **Implementation** - Write the `.ado` file
3. **Documentation** - Create help file (`.sthlp`) and package files
4. **Integration** - Add to repository and create tests

---

## Phase 1: Design

### 1.1 Define the Command Purpose

Before writing any code, clearly answer:
- What problem does this command solve?
- What are the required inputs?
- What are the outputs (returned values, new variables, files)?
- What options should be available?

### 1.2 Design the Syntax

Follow Stata conventions for syntax design:

```stata
* Basic pattern
command varlist [if] [in] [, options]

* With required options (use uppercase for required portion)
command varlist, REQuired_option(value) [optional_option]

* With using clause
command using filename [, options]
```

**Syntax design rules:**
- Required elements come before optional elements
- Use parentheses for options that take values: `option(value)`
- Use uppercase letters to show minimum abbreviation: `REQuired` = req/requ/requi/requir/require/required
- Group related options logically

### 1.3 Plan Return Values

Decide what the command will return:

| Class | Use Case | Return Command |
|-------|----------|----------------|
| `rclass` | General commands (statistics, transformations) | `return scalar/local/matrix` |
| `eclass` | Estimation commands (regression results) | `ereturn post/scalar/local` |
| `sclass` | String parsing utilities | `sreturn local` |
| `nclass` | Commands with no return values | Nothing |

---

## Phase 2: Implementation

### 2.1 Standard Header

Every `.ado` file must start with:

```stata
*! mycommand Version 1.0.0  2025/01/15
*! Brief description of what the command does
*! Author: Your Name
*! Program class: rclass (returns results in r())

/*
Basic syntax:
  mycommand varlist [if] [in], required_option(varname) [options]

Required options:
  required_option(varname)  - Description

Optional options:
  option1                   - Description (default: value)
  generate(newvar)          - Name for output variable

See help mycommand for complete documentation
*/
```

### 2.2 Program Definition

```stata
program define mycommand, rclass
    version 16.0
    set varabbrev off

    * Parse syntax
    syntax varlist(numeric) [if] [in], REQuired(varname) [OPTional(string)]

    * Mark sample
    marksample touse
    markout `touse' `required'  // Add option variables after marksample

    * Validate observations
    quietly count if `touse'
    if r(N) == 0 {
        display as error "no observations"
        exit 2000
    }

    * Main logic here...

    * Return results
    return scalar N = r(N)
    return local varlist "`varlist'"
end
```

### 2.3 Input Validation

**Always validate inputs before processing:**

```stata
* Check variable exists
capture confirm variable `varname'
if _rc {
    display as error "variable `varname' not found"
    exit 111
}

* Check variable is numeric
capture confirm numeric variable `varname'
if _rc {
    display as error "`varname' must be numeric"
    exit 109
}

* Check file exists
capture confirm file "`filename'"
if _rc {
    display as error "file not found: `filename'"
    exit 601
}

* Check option value is valid
if !inlist("`option'", "value1", "value2", "value3") {
    display as error "option() must be value1, value2, or value3"
    exit 198
}
```

### 2.4 Using Temporary Objects

**Always use temp objects for intermediate calculations:**

```stata
* Temporary variables (automatically dropped)
tempvar temp_sum temp_flag
gen double `temp_sum' = 0
gen byte `temp_flag' = 1

* Temporary files (automatically deleted)
tempfile results_temp
save `results_temp', replace

* Temporary names for scalars/matrices
tempname result_matrix
matrix `result_matrix' = J(3, 3, 0)
```

### 2.5 Preserve and Restore

**Use preserve when modifying data:**

```stata
program define mycommand, rclass
    * Parse and validate BEFORE preserve (catch errors early)
    syntax varlist [if] [in]
    marksample touse

    quietly count if `touse'
    if r(N) == 0 error 2000

    preserve  // Save current data state

    * Now safe to modify data
    keep if `touse'
    collapse (mean) `varlist'

    * Store results before restore
    local result = `varlist'[1]

    restore  // Automatic at program end, but explicit is clearer

    return scalar mean = `result'
end
```

### 2.6 Error Handling

```stata
* Capture and check return code
capture noisily regress y x1 x2
if _rc {
    display as error "regression failed"
    exit _rc
}

* Custom error messages
if `value' < 0 {
    display as error "value must be non-negative"
    exit 198
}

* Common error codes:
*   100 - varlist required
*   109 - type mismatch
*   111 - variable not found
*   198 - invalid syntax
*   601 - file not found
*   2000 - no observations
```

### 2.7 Output Display

```stata
* Text output (informational)
display as text "Processing `n' observations..."

* Result output (highlighted)
display as result "Mean: " %9.4f `mean'

* Error output
display as error "Error: invalid value"

* Formatted table
display _n "{hline 60}"
display as text "Variable" _col(30) "Mean" _col(45) "SD"
display "{hline 60}"
foreach v of local varlist {
    display as text "`v'" _col(30) %9.3f `mean_`v'' _col(45) %9.3f `sd_`v''
}
display "{hline 60}"
```

---

## Phase 3: Documentation

### 3.1 Help File (.sthlp)

Create `mycommand.sthlp`:

```smcl
{smcl}
{* *! version 1.0.0  15jan2025}
{title:Title}

{p2colset 5 18 20 2}{...}
{p2col:{cmd:mycommand} {hline 2}}Brief description{p_end}
{p2colreset}{...}

{marker syntax}{title:Syntax}

{p 8 16 2}
{cmd:mycommand} {varlist} {ifin} {cmd:,} {opt req:uired(varname)} [{it:options}]

{synoptset 20 tabbed}{...}
{synopthdr}
{synoptline}
{p2coldent:* {opt req:uired(varname)}}required option description{p_end}
{synopt:{opt opt:ional(string)}}optional option description{p_end}
{synoptline}
{p 4 6 2}* {opt required()} is required.{p_end}

{marker description}{title:Description}

{pstd}
{cmd:mycommand} does something useful...

{marker options}{title:Options}

{phang}
{opt required(varname)} specifies the variable to use for...

{phang}
{opt optional(string)} optionally specifies...

{marker examples}{title:Examples}

{phang2}{cmd:. sysuse auto, clear}{p_end}
{phang2}{cmd:. mycommand price mpg, required(weight)}{p_end}

{marker results}{title:Stored results}

{pstd}
{cmd:mycommand} stores the following in {cmd:r()}:

{synoptset 15 tabbed}{...}
{p2col 5 15 19 2: Scalars}{p_end}
{synopt:{cmd:r(N)}}number of observations{p_end}

{marker author}{title:Author}

{pstd}
Your Name{break}
Institution{break}
Email: your@email.com
```

### 3.2 Package File (.pkg)

Create `mycommand.pkg`:

```stata
v 3
d 'MYCOMMAND': Brief description of the command
d
d Requires: Stata version 16+
d
d Distribution-Date: 20250115
d License: MIT
d
d Author: Your Name
d
f mycommand.ado
f mycommand.sthlp
```

**Critical rules:**
- `v 3` is the file format version - NEVER change this
- `Distribution-Date` is how Stata detects updates - ALWAYS update with releases

### 3.3 Table of Contents (stata.toc)

Create `stata.toc`:

```stata
v 3
d Stata-Tools: mycommand
d Your Name, Institution
d https://github.com/username/repository
p mycommand
```

### 3.4 README.md

Create `mycommand/README.md`:

```markdown
# mycommand

![Stata 16+](https://img.shields.io/badge/Stata-16%2B-brightgreen) ![MIT License](https://img.shields.io/badge/License-MIT-blue)

Brief description of what the command does.

## Installation

```stata
net install mycommand, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/mycommand")
```

## Syntax

```stata
mycommand varlist [if] [in], required(varname) [optional(string)]
```

## Options

| Option | Description |
|--------|-------------|
| `required(varname)` | Required. Specifies... |
| `optional(string)` | Optional. Specifies... |

## Examples

```stata
sysuse auto, clear
mycommand price mpg, required(weight)
```

## Stored Results

| Result | Description |
|--------|-------------|
| `r(N)` | Number of observations |

## Author

Timothy P Copeland<br>
Department of Clinical Neuroscience<br>
Karolinska Institutet

## License

MIT License

## Version

Version 1.0.0, 2025-01-15
```

---

## Phase 4: Integration

### 4.1 Directory Structure

```
mycommand/
├── mycommand.ado       # Main command
├── mycommand.sthlp     # Help file
├── mycommand.pkg       # Package metadata
├── stata.toc           # Table of contents
└── README.md           # Documentation
```

### 4.2 Version Management

When updating a command:

1. Update version in `.ado` header: `*! mycommand Version 1.1.0  2025/02/15`
2. Update version in `.sthlp`: `{* *! version 1.1.0  15feb2025}`
3. Update `Distribution-Date` in `.pkg`: `d Distribution-Date: 20250215`
4. Update version in both README.md files

**Version numbering:**
- `X.0.0` - Major version (breaking changes)
- `X.Y.0` - Minor version (new features)
- `X.Y.Z` - Patch version (bug fixes)

### 4.3 Create Test File

Create `_testing/test_mycommand.do` - see the Testing Guide for details.

### 4.4 Create Validation File

Create `_validation/validation_mycommand.do` - see the Validation Guide for details.

---

## Common Patterns

### Pattern: Processing Multiple Variables

```stata
foreach var of varlist `varlist' {
    quietly summarize `var' if `touse'
    return scalar mean_`var' = r(mean)
}
```

### Pattern: By-Group Processing

```stata
program define mycommand, rclass byable(recall)
    * byable(recall) means program is re-called for each by-group

    syntax varlist [if] [in]
    marksample touse

    * _byvars contains by-group variables when called with by:
    if "`_byvars'" != "" {
        display "Processing by group: `_byvars'"
    }
end
```

### Pattern: Mata Integration

```stata
program define mycommand, rclass
    syntax varlist [if] [in]
    marksample touse

    * Call Mata function
    mata: _mycommand_calc("`varlist'", "`touse'")

    * Retrieve results from Mata
    return scalar result = r(result)
end

mata:
void _mycommand_calc(string scalar varlist, string scalar touse)
{
    real matrix X
    st_view(X, ., varlist, touse)

    // Calculation here...
    real scalar result
    result = mean(X)

    // Return to Stata
    st_numscalar("r(result)", result)
}
end
```

### Pattern: Dialog File Integration

If adding a dialog file, see the main CLAUDE.md for dialog file development guidelines.

---

## Common Mistakes to Avoid

A comprehensive catalog of common .ado file errors is available in `_testing/notes/ado_error_patterns.md`. Here are the most critical issues:

### Quick Error Checklist

| Category | Pattern | Detection |
|----------|---------|-----------|
| **Macros** | Missing backticks | Macro name without `` `name' `` |
| **Macros** | Unclosed quotes | Count backticks vs single quotes |
| **Macros** | Name >31 chars | Count characters; silently truncated |
| **Structure** | No version | Check first 5 lines after program |
| **Structure** | No varabbrev off | Search after version statement |
| **Structure** | No marksample | syntax has if/in but no marksample |
| **Structure** | No obs check | marksample without count check |
| **Returns** | Wrong class | return type vs program declaration |
| **Tempvars** | No declaration | Variables starting with `_` |
| **Tempvars** | No backticks | tempvar X followed by plain X |
| **Frames** | No cleanup | frame create without frame drop |
| **Loops** | Plain variable | Loop var without backticks |
| **Errors** | Unchecked capture | capture without _rc check |
| **Cross-file** | Version mismatch | Compare ado/sthlp/pkg/README |

### Macro Reference Errors

```stata
// WRONG - missing backticks
local myvar "price"
summarize myvar           // Tries to find variable named "myvar"

// CORRECT
summarize `myvar'

// WRONG - spaces inside backticks
foreach v of varlist ` varlist ' {    // Fails

// CORRECT
foreach v of varlist `varlist' {

// WRONG - unclosed macro reference
display "`varname"

// CORRECT
display "`varname'"
```

### Macro Name Length Errors (31-character limit)

**CRITICAL**: Stata macro names are limited to 31 characters. Names longer than 31 characters are **silently truncated**, which causes subtle bugs when two macros collide:

```stata
// WRONG - both names truncate to the same 31-character string!
local very_long_descriptive_variable_name_one = 1
local very_long_descriptive_variable_name_two = 2
display `very_long_descriptive_variable_name_one'  // Shows 2, not 1!

// The truncation happens silently - both become:
// "very_long_descriptive_variable_" (31 chars)

// CORRECT - keep macro names ≤31 characters
local desc_var_name_one = 1
local desc_var_name_two = 2
```

**This also applies to:**
- `tempvar` names (the user-specified prefix must be ≤31 chars)
- `tempname` names
- `global` macro names
- Loop variable names in `foreach`/`forvalues`

**Detection**: Count characters in macro names. Names with common prefixes are high-risk for collision after truncation.

### Program Structure Errors

```stata
// WRONG - marksample but no observation check
marksample touse
summarize `varlist' if `touse'    // May fail mysteriously with empty sample

// CORRECT
marksample touse
quietly count if `touse'
if r(N) == 0 error 2000
summarize `varlist' if `touse'

// WRONG - option variables not marked out
syntax varlist [if] [in], BY(varname)
marksample touse
// Missing: markout `touse' `by'
```

### Temporary Object Errors

```stata
// WRONG - tempvar referenced without backticks
tempvar mytemp
gen mytemp = price * 2    // Creates variable named "mytemp", not the tempvar!

// CORRECT
tempvar mytemp
gen `mytemp' = price * 2

// WRONG - tempfile used before save
tempfile mydata
use `mydata', clear    // File doesn't exist yet!

// CORRECT
tempfile mydata
save `mydata'
// ... other operations ...
use `mydata', clear
```

### Error Handling Errors

```stata
// WRONG - capture without checking _rc
capture regress y x
predict yhat    // May fail if regression failed!

// CORRECT
capture regress y x
if _rc {
    display as error "Regression failed"
    exit _rc
}
predict yhat

// WRONG - _rc gets overwritten
capture noisily mycommand
display "Command finished"    // This succeeds, _rc becomes 0!
if _rc {                      // Always false now
    handle_error
}

// CORRECT
capture noisily mycommand
local rc = _rc
display "Command finished"
if `rc' {
    handle_error
}
```

For the complete error pattern catalog with detection methods, see `_testing/notes/ado_error_patterns.md`.

---

## Checklist Before Commit

- [ ] `.ado` has version line with X.Y.Z format
- [ ] `.ado` has 4-line header with description and author
- [ ] `.ado` has block comment with syntax documentation
- [ ] `.ado` uses `version 16.0` and `set varabbrev off`
- [ ] `.sthlp` version matches `.ado` version
- [ ] `.pkg` has current `Distribution-Date`
- [ ] Both READMEs updated with matching version
- [ ] Test file created in `_testing/`
- [ ] All tests pass
- [ ] Code works with `set varabbrev off`
- [ ] No common error patterns (see checklist above)

---

*Last updated: 2025-12-14*
