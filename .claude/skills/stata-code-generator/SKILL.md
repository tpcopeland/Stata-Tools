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

**Standard .sthlp Structure:**

```stata
{smcl}
{* *! version 1.0.0 [date]}{...}
{viewerjumpto "Syntax" "command_name##syntax"}{...}
{viewerjumpto "Description" "command_name##description"}{...}
{viewerjumpto "Options" "command_name##options"}{...}
{viewerjumpto "Examples" "command_name##examples"}{...}
{viewerjumpto "Stored results" "command_name##results"}{...}
{viewerjumpto "Author" "command_name##author"}{...}

{title:Title}

{phang}
{bf:command_name} {hline 2} [Brief description]


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmdab:command_name}
[{varlist}]
{ifin}
[{cmd:,} {it:options}]

{synoptset 20 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Main}
{synopt:{opt option1(string)}}description{p_end}
{synopt:{opt option2(numlist)}}description{p_end}
{synoptline}


{marker description}{...}
{title:Description}

{pstd}
{cmd:command_name} does something useful...


{marker options}{...}
{title:Options}

{dlgtab:Main}

{phang}
{opt option1(string)} specifies...


{marker examples}{...}
{title:Examples}

{pstd}Setup{p_end}
{phang2}{cmd:. sysuse auto}{p_end}

{pstd}Basic usage{p_end}
{phang2}{cmd:. command_name price mpg}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:command_name} stores the following in {cmd:r()}:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:r(N)}}number of observations{p_end}


{marker author}{...}
{title:Author}

{pstd}
[Author Name]{break}
[Institution]{break}
[Email]
```

### Step 4: Generate Test File

**Standard Test Structure:**

```stata
* test_command_name.do
* Test file for command_name
* Run with: stata-mp -b do test_command_name.do

clear all
set more off
capture log close
log using test_command_name.log, replace

* Load test data
sysuse auto, clear

* Test 1: Basic functionality
di _dup(60) "-"
di "Test 1: Basic functionality"
di _dup(60) "-"
command_name price mpg
assert r(N) > 0

* Test 2: With options
di _dup(60) "-"
di "Test 2: With options"
di _dup(60) "-"
command_name price mpg, option1("value")
assert r(N) > 0

* Test 3: Error handling
di _dup(60) "-"
di "Test 3: Error handling (expect error)"
di _dup(60) "-"
capture command_name  // Missing required argument
assert _rc != 0

* All tests passed
di _dup(60) "="
di "ALL TESTS PASSED"
di _dup(60) "="

log close
exit, clear
```

### Step 5: Validate Before Saving

Run through error pattern checklist:

```
BATCH MODE CHECK:
- No cls, pause, browse, edit commands?
- IF any found -> REMOVE or comment out

SYNTAX CHECK:
- All options correctly specified?
- Default values sensible?
- Required options enforced?

ERROR HANDLING CHECK:
- Invalid inputs produce clear errors?
- Exit codes appropriate?
- Temporary files cleaned up?

HELP FILE CHECK:
- All options documented?
- Examples work?
- Stored results documented?
```

---

## Code Patterns

### Syntax Parsing

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
```

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

| Check | Status | Notes |
|-------|--------|-------|
| Syntax parsing correct | Y/N | |
| Options handled | Y/N | |
| Error handling | Y/N | |
| Batch mode compatible | Y/N | |
| Help file complete | Y/N | |
| Test file created | Y/N | |

### NEXT STEPS

1. Run tests: `stata-mp -b do test_command_name.do`
2. Check log for errors: `cat test_command_name.log | grep "^r("`
3. Update package files (.pkg, stata.toc) if needed
```

---

## Version Synchronization (CRITICAL)

**When modifying ANY file in a package, you MUST update versions in ALL related files to stay synchronized:**

| File | What to Update |
|------|----------------|
| `.ado` | Version line: `*! command Version X.Y.Z  YYYY/MM/DD` |
| `.sthlp` | Version comment: `{* *! version X.Y.Z  DDmonYYYY}` |
| `.pkg` | `Distribution-Date: YYYYMMDD` (how Stata detects updates) |
| Package `README.md` | Version in footer |
| Root `README.md` | Version if command is listed |

**Version Rules:**
- Use semantic versioning: X.Y.Z (never X.Y)
- Increment PATCH (Z) for bug fixes and minor changes
- Increment MINOR (Y) for new features
- Increment MAJOR (X) for breaking changes
- All files MUST have matching version numbers
- `v 3` in .pkg/.toc is file format version - NEVER change

**Example - After modifying regtab.sthlp:**
```
1. Update regtab.ado version line to match
2. Update regtab.pkg Distribution-Date to today
3. Update regtab/README.md version
4. Check root README.md if applicable
```

---

## Anti-Patterns

```
DO NOT:
- Use cls, pause, browse, edit in .ado files
- Use "string" * n for character repetition
- Put functions in bysort sort specification
- Use wildcards in 'use' command
- Forget to document options in help file
- Skip error handling for invalid inputs
- Hard-code paths (use arguments or macros)
- Forget to clean up temp files on error
- Use macro names > 31 characters
- Modify one package file without updating versions in ALL related files
```

---

## Delegation Rules

```
USE code-reviewer skill WHEN:
- Validating generated code
- Checking for bug patterns
- Reviewing existing code

USE package-tester skill WHEN:
- Running tests
- Validating package structure
- Checking test coverage
```
