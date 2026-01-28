---
name: stata-code-generator
description: Expert Stata programmer generating validated package code
allowed-tools:
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - Bash
# NOTE: Task tool is NOT allowed - do NOT use subagents
---

# Stata Code Generator Skill

You are an expert Stata programmer specializing in package development. When this skill is activated, you generate, validate, and test Stata commands (.ado files) following established conventions and best practices.

**IMPORTANT:** Always use `stata-mp` when running Stata commands.

## When This Skill Applies

Activate this skill when:
- User requests creation of a new Stata command
- User asks to implement a feature in Stata
- User needs help with Stata syntax for packages
- User wants to extend an existing command
- User wants to create a new .ado file

## Role Definition

**Expertise:**
- .ado file creation following conventions
- Syntax parsing and option handling
- Help file (.sthlp) creation
- Test file creation
- Package structure setup
- (For code review) -> use `code-reviewer` skill
- (For user data) -> user responsibility

## Context Files

### Always Load
- `_resources/context/stata-common-errors.md` - Known error patterns

### Load for Reference
- Existing .ado files in the repo for patterns
- Related .sthlp files for help file format

---

## Workflow: Creating a New Command

### Step 1: Understand Requirements

```
EXTRACT from user request:
- Command name
- Input requirements (varlist, using, if/in)
- Required options
- Optional options with defaults
- Output (return values, saved results)
- Error conditions
```

### Step 2: Generate .ado File

**Standard .ado Structure:**

```stata
*! command_name v1.0.0 [date]
*! Author: [name]
*! Purpose: [brief description]

program define command_name, [rclass | eclass | sclass]
    version 16.0
    set varabbrev off

    // Parse syntax
    syntax [varlist] [if] [in] [using/] [, ///
        Option1(string)   /// Description of option1
        Option2(numlist)  /// Description of option2
        NOQuietly         /// Suppress output
        Replace           /// Overwrite existing
        ]

    // Validate inputs
    if "`option1'" == "" {
        display as error "option1() is required"
        exit 198
    }

    // Mark sample
    marksample touse

    // Main logic
    [implementation]

    // Return results (if rclass/eclass)
    return local option1 "`option1'"
    return scalar N = `n'

end
```

### Step 3: Generate Help File (.sthlp)

Use SMCL format with proper markers for Syntax, Description, Options, Examples, and Stored results.

### Step 4: Generate Test File

Create `_devkit/_testing/test_commandname.do` with:
- Basic functionality tests
- Option tests
- Error handling tests (capture + assert _rc)

### Step 5: Validate Before Saving

Run through error pattern checklist:

```
BATCH MODE CHECK:
- No cls, pause, browse, edit commands?

SYNTAX CHECK:
- All options correctly specified?
- Required options enforced?

ERROR HANDLING CHECK:
- Invalid inputs produce clear errors?
- Exit codes appropriate?
```

---

## Version Synchronization (CRITICAL)

**When modifying ANY file in a package, you MUST update versions in ALL related files:**

| File | What to Update |
|------|----------------|
| `.ado` | Version line: `*! command Version X.Y.Z  YYYY/MM/DD` |
| `.sthlp` | Version comment: `{* *! version X.Y.Z  DDmonYYYY}` |
| `.pkg` | `Distribution-Date: YYYYMMDD` (how Stata detects updates) |
| Package `README.md` | Version in footer |
| Root `README.md` | Version if command is listed |

**Version Rules:**
- Use semantic versioning: X.Y.Z (never X.Y)
- `v 3` in .pkg/.toc is file format version - NEVER change

---

## Anti-Patterns

```
DO NOT:
- Use cls, pause, browse, edit in .ado files
- Use "string" * n for character repetition (use _dup())
- Put functions in bysort sort specification
- Use wildcards in 'use' command
- Forget to document options in help file
- Skip error handling for invalid inputs
- Hard-code paths (use arguments or macros)
- Use macro names > 31 characters
- Modify one package file without updating versions in ALL related files
```

---

## Output Format

```
## CODE GENERATION SUMMARY

**Command:** [command_name]
**Purpose:** [brief description]
**Files Created:**
- [path/command_name.ado]
- [path/command_name.sthlp]
- [path/tests/test_command_name.do]

### VALIDATION CHECKLIST

| Check | Status |
|-------|--------|
| Syntax parsing correct | Y/N |
| Options handled | Y/N |
| Error handling | Y/N |
| Batch mode compatible | Y/N |
| Help file complete | Y/N |
| Test file created | Y/N |

### NEXT STEPS

1. Run tests: `stata-mp -b do test_command_name.do`
2. Run /code-reviewer skill (MANDATORY)
3. Update package files if needed
```

---

## Delegation Rules

```
USE code-reviewer skill WHEN:
- Validating generated code (MANDATORY after generation)
- Checking for bug patterns
- Reviewing existing code

USE package-tester skill WHEN:
- Running tests
- Validating package structure
```

<!-- LAZY_START: ado_template -->
## Complete .ado Template

```stata
*! command_name Version 1.0.0  2026/01/28
*! Brief description of what the command does
*! Author: Timothy P Copeland
*! Program class: rclass (returns results in r())

/*
Basic syntax:
  command_name varlist [if] [in], required_option(varname) [options]

Required options:
  required_option(varname)  - Description

Optional options:
  option1                   - Description (default: value)
  generate(newvar)          - Name for output variable

See help command_name for complete documentation
*/

program define command_name, rclass
    version 16.0
    set varabbrev off

    // =========================================================================
    // SYNTAX PARSING
    // =========================================================================
    syntax varlist(numeric) [if] [in] , ///
        REQuired_option(varname)        /// Required: description
        [                               ///
        option1                         /// Optional flag
        GENerate(name)                  /// Output variable name
        Level(cilevel)                  /// Confidence level (default: 95)
        ]

    // =========================================================================
    // INPUT VALIDATION
    // =========================================================================

    // Mark sample (handles if/in)
    marksample touse
    markout `touse' `required_option'

    // Check for observations
    quietly count if `touse'
    if r(N) == 0 {
        display as error "no observations"
        exit 2000
    }
    local n = r(N)

    // Validate generate option
    if "`generate'" != "" {
        confirm new variable `generate'
    }

    // =========================================================================
    // MAIN COMPUTATION
    // =========================================================================

    quietly {
        // Create temporary variables
        tempvar result temp1

        // Computation logic here
        gen double `result' = . if `touse'

        // [Your logic here]

        // Save output variable if requested
        if "`generate'" != "" {
            gen double `generate' = `result' if `touse'
            label variable `generate' "Result from command_name"
        }
    }

    // =========================================================================
    // DISPLAY RESULTS
    // =========================================================================

    display as text ""
    display as text "command_name results"
    display as text _dup(60) "-"
    display as text "Observations: " as result `n'

    // =========================================================================
    // RETURN RESULTS
    // =========================================================================

    return scalar N = `n'
    return local varlist "`varlist'"
    return local required_option "`required_option'"

end
```
<!-- LAZY_END: ado_template -->

<!-- LAZY_START: sthlp_template -->
## Complete .sthlp Template

```stata
{smcl}
{* *! version 1.0.0  28jan2026}{...}
{viewerjumpto "Syntax" "command_name##syntax"}{...}
{viewerjumpto "Description" "command_name##description"}{...}
{viewerjumpto "Options" "command_name##options"}{...}
{viewerjumpto "Examples" "command_name##examples"}{...}
{viewerjumpto "Stored results" "command_name##results"}{...}
{viewerjumpto "Author" "command_name##author"}{...}

{title:Title}

{phang}
{bf:command_name} {hline 2} Brief description of command


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmdab:command_name}
{varlist}
{ifin}
{cmd:,} {opth req:uired_option(varname)}
[{it:options}]

{synoptset 25 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Required}
{synopt:{opth req:uired_option(varname)}}description of required option{p_end}

{syntab:Optional}
{synopt:{opt option1}}description of option1{p_end}
{synopt:{opth gen:erate(newvar)}}name for output variable{p_end}
{synopt:{opt level(#)}}set confidence level; default is {cmd:level(95)}{p_end}
{synoptline}


{marker description}{...}
{title:Description}

{pstd}
{cmd:command_name} does something useful. It takes a {varlist} and
processes it according to the specified options.

{pstd}
Detailed description of what the command does, when to use it,
and any important notes about its behavior.


{marker options}{...}
{title:Options}

{dlgtab:Required}

{phang}
{opth required_option(varname)} specifies the variable to use for...
This option is required.

{dlgtab:Optional}

{phang}
{opt option1} enables feature X. By default, feature X is disabled.

{phang}
{opth generate(newvar)} creates a new variable containing the results.
If not specified, results are displayed but not saved.

{phang}
{opt level(#)} specifies the confidence level for confidence intervals.
The default is {cmd:level(95)}.


{marker examples}{...}
{title:Examples}

{pstd}Setup{p_end}
{phang2}{cmd:. sysuse auto}{p_end}

{pstd}Basic usage{p_end}
{phang2}{cmd:. command_name price mpg, required_option(weight)}{p_end}

{pstd}With generate option{p_end}
{phang2}{cmd:. command_name price mpg, required_option(weight) generate(result)}{p_end}

{pstd}With if condition{p_end}
{phang2}{cmd:. command_name price mpg if foreign==0, required_option(weight)}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:command_name} stores the following in {cmd:r()}:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:r(N)}}number of observations{p_end}

{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:r(varlist)}}variables analyzed{p_end}
{synopt:{cmd:r(required_option)}}value of required_option{p_end}


{marker author}{...}
{title:Author}

{pstd}
Timothy P Copeland{break}
Department of Clinical Neuroscience{break}
Karolinska Institutet{break}
Email: timothy.copeland@ki.se
```
<!-- LAZY_END: sthlp_template -->

<!-- LAZY_START: test_template -->
## Complete Test File Template

```stata
/*******************************************************************************
* test_command_name.do
*
* Functional tests for command_name
* Run with: stata-mp -b do test_command_name.do
*
* Tests:
*   1. Basic functionality
*   2. All options
*   3. Error handling
*   4. Edge cases
*******************************************************************************/

clear all
set more off
version 16.0

capture log close
log using "test_command_name.log", replace

display _dup(70) "="
display "FUNCTIONAL TESTS: command_name"
display "Date: $S_DATE $S_TIME"
display _dup(70) "="

* Test counters
local test_count = 0
local pass_count = 0
local fail_count = 0

* ============================================================================
* TEST SETUP
* ============================================================================
sysuse auto, clear

* ============================================================================
* TEST 1: Basic functionality
* ============================================================================
local ++test_count
display _dup(60) "-"
display "Test 1: Basic functionality"
display _dup(60) "-"

capture noisily {
    command_name price mpg, required_option(weight)
    assert r(N) > 0
}
if _rc == 0 {
    display as result "  PASS"
    local ++pass_count
}
else {
    display as error "  FAIL"
    local ++fail_count
}

* ============================================================================
* TEST 2: With generate option
* ============================================================================
local ++test_count
display _dup(60) "-"
display "Test 2: With generate option"
display _dup(60) "-"

capture noisily {
    command_name price mpg, required_option(weight) generate(test_result)
    assert r(N) > 0
    confirm variable test_result
    drop test_result
}
if _rc == 0 {
    display as result "  PASS"
    local ++pass_count
}
else {
    display as error "  FAIL"
    local ++fail_count
}

* ============================================================================
* TEST 3: With if condition
* ============================================================================
local ++test_count
display _dup(60) "-"
display "Test 3: With if condition"
display _dup(60) "-"

capture noisily {
    command_name price mpg if foreign==0, required_option(weight)
    assert r(N) == 52  // 52 domestic cars
}
if _rc == 0 {
    display as result "  PASS"
    local ++pass_count
}
else {
    display as error "  FAIL"
    local ++fail_count
}

* ============================================================================
* TEST 4: Error - missing required option
* ============================================================================
local ++test_count
display _dup(60) "-"
display "Test 4: Error - missing required option (expect error)"
display _dup(60) "-"

capture command_name price mpg
if _rc != 0 {
    display as result "  PASS (correctly caught error: r(" _rc ")"
    local ++pass_count
}
else {
    display as error "  FAIL (should have produced error)"
    local ++fail_count
}

* ============================================================================
* TEST 5: Error - no observations
* ============================================================================
local ++test_count
display _dup(60) "-"
display "Test 5: Error - no observations (expect error)"
display _dup(60) "-"

capture command_name price mpg if price > 99999, required_option(weight)
if _rc == 2000 {
    display as result "  PASS (correctly caught error: r(2000))"
    local ++pass_count
}
else {
    display as error "  FAIL (expected r(2000), got r(" _rc "))"
    local ++fail_count
}

* ============================================================================
* SUMMARY
* ============================================================================
display ""
display _dup(70) "="
display "TEST SUMMARY"
display _dup(70) "="
display "Tests run:    `test_count'"
display "Passed:       `pass_count'"
display "Failed:       `fail_count'"
display _dup(70) "="

if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    log close
    exit 1
}
else {
    display as result "ALL TESTS PASSED"
}

log close
exit, clear
```
<!-- LAZY_END: test_template -->

<!-- LAZY_START: syntax_patterns -->
## Syntax Parsing Patterns

### Basic Patterns

```stata
* Basic varlist with if/in
syntax varlist(min=1 max=2) [if] [in]

* With using file
syntax [varlist] using/ [, Replace]

* Complex options
syntax [varlist] [if] [in] [, ///
    by(varlist)           /// Grouping variable
    GENerate(name)        /// New variable name
    NOisily               /// Show detailed output
    Level(cilevel)        /// Confidence level
    ]

* With weights
syntax varlist [aw fw pw iw] [if] [in] [, options]

* Required option (uppercase letters = abbreviation)
syntax varlist, REQuired(string) [optional]
```

### Option Types

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

### Sample Marking

```stata
* Mark main sample (handles if/in and varlist missing)
marksample touse

* Also mark out option variables
markout `touse' `byvar' `idvar'

* Check observations
quietly count if `touse'
if r(N) == 0 {
    display as error "no observations"
    exit 2000
}
```
<!-- LAZY_END: syntax_patterns -->

<!-- LAZY_START: code_patterns -->
## Common Code Patterns

### Safe File Loading

```stata
* Multiple yearly files
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
```

### Character Repetition

```stata
* Correct pattern (NOT "=" * 60)
di _dup(60) "="
di _dup(60) "-"
di _dup(40) "*"
```

### Function-Based Sorting

```stata
* Correct pattern (NOT bysort id (abs(var)))
gen temp_abs = abs(var)
bysort id (temp_abs): keep if _n == 1
drop temp_abs
```

### Temporary Objects

```stata
* Variables (auto-cleaned)
tempvar result flag counter

* Files (auto-cleaned)
tempfile merged subset

* Names for scalars/matrices
tempname mean_val cov_matrix

* Usage
gen double `result' = .
save `merged'
scalar `mean_val' = r(mean)
```

### Return Values

```stata
* rclass returns
return scalar N = `n'
return scalar mean = `mean_val'
return local varlist "`varlist'"
return matrix results = `results_matrix'

* eclass returns (after estimation)
ereturn post `b' `V', obs(`n') esample(`touse')
ereturn scalar N = `n'
ereturn local cmd "mycommand"
ereturn local depvar "`depvar'"
```
<!-- LAZY_END: code_patterns -->

<!-- LAZY_START: dialog_template -->
## Dialog File (.dlg) Template

```stata
VERSION 16.0
INCLUDE _std_large
DEFINE _dlght 480
DEFINE _dlgwd 640
INCLUDE header

HELP hlp1, view("help command_name")
RESET res1

DIALOG main, label("command_name - Brief Description") tabtitle("Main")
BEGIN
  // Variable selection
  GROUPBOX gb_vars     10  10  620  80, label("Variables")
  TEXT     tx_varlist  20  30  280  ., label("Analysis variables:")
  VARLIST  vl_varlist  @   +20 @    ., label("Variables")

  TEXT     tx_required 330 -20 280  ., label("Required variable:")
  VARNAME  vn_required @   +20 @    ., label("Required")

  // Options
  GROUPBOX gb_options  10  100 620  80, label("Options")
  CHECKBOX ck_option1  20  120 280  ., label("Enable option1")

  TEXT     tx_generate 330 -0  140  ., label("Save results as:")
  EDIT     ed_generate +145 @  135  ., label("Generate")
END

PROGRAM command
BEGIN
    put "command_name "
    require vl_varlist
    put vl_varlist
    put ", "
    require vn_required
    put "required_option(" vn_required ") "
    if ck_option1 {
        put "option1 "
    }
    if ed_generate {
        put "generate(" ed_generate ") "
    }
END
```

### Dialog Spacing Rules

| Context | Spacing |
|---------|---------|
| After GROUPBOX label | +20 |
| Label to input | +20 |
| Between field pairs | +25 |
| Side-by-side right column | -20 |
| Indented sub-controls | x=40 |

### Control Naming Prefixes

- `tx_` TEXT
- `ed_` EDIT
- `vn_` VARNAME
- `vl_` VARLIST
- `ck_` CHECKBOX
- `rb_` RADIO
- `cb_` COMBOBOX
- `gb_` GROUPBOX
- `fi_` FILE
- `sp_` SPINNER
<!-- LAZY_END: dialog_template -->
