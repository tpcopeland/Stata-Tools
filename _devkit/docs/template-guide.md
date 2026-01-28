# Stata Package Template Guide

Complete templates for all package files with detailed annotations.

---

## Package Structure

```
mypackage/
├── mypackage.ado       # Main command implementation
├── mypackage.sthlp     # SMCL help file
├── mypackage.pkg       # Package metadata for net install
├── stata.toc           # Table of contents
├── mypackage.dlg       # Dialog file (optional)
└── README.md           # Documentation
```

**Notes:**
- All packages use MIT license (specified in .pkg and README)
- Do NOT create separate LICENSE files
- Dialog files are optional but enhance usability

---

## .ado File Template

```stata
*! mycommand Version 1.0.0  2026/01/28
*! Brief description of what the command does
*! Author: Timothy P Copeland
*! Program class: rclass (returns results in r())

/*
Basic syntax:
  mycommand varlist [if] [in], required_option(varname) [options]

Required options:
  required_option(varname)  - Description of required option

Optional options:
  option1                   - Description (default: value)
  generate(newvar)          - Name for output variable

See help mycommand for complete documentation
*/

program define mycommand, rclass
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
            label variable `generate' "Result from mycommand"
        }
    }

    // =========================================================================
    // DISPLAY RESULTS
    // =========================================================================

    display as text ""
    display as text "mycommand results"
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

### Header Requirements

1. **Version line**: `*! name Version X.Y.Z  YYYY/MM/DD`
   - Use semantic versioning (X.Y.Z, never X.Y)
   - Date format: YYYY/MM/DD

2. **Description**: Brief one-line description

3. **Author**: Your name

4. **Program class**: rclass, eclass, sclass, or nclass

5. **Block comment**: Syntax summary with options

---

## .sthlp File Template

```stata
{smcl}
{* *! version 1.0.0  28jan2026}{...}
{viewerjumpto "Syntax" "mycommand##syntax"}{...}
{viewerjumpto "Description" "mycommand##description"}{...}
{viewerjumpto "Options" "mycommand##options"}{...}
{viewerjumpto "Examples" "mycommand##examples"}{...}
{viewerjumpto "Stored results" "mycommand##results"}{...}
{viewerjumpto "Author" "mycommand##author"}{...}

{title:Title}

{phang}
{bf:mycommand} {hline 2} Brief description of command


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmdab:mycommand}
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
{cmd:mycommand} does something useful. It takes a {varlist} and
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
{phang2}{cmd:. mycommand price mpg, required_option(weight)}{p_end}

{pstd}With generate option{p_end}
{phang2}{cmd:. mycommand price mpg, required_option(weight) generate(result)}{p_end}

{pstd}With if condition{p_end}
{phang2}{cmd:. mycommand price mpg if foreign==0, required_option(weight)}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:mycommand} stores the following in {cmd:r()}:

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

### SMCL Formatting Reference

| Element | Syntax |
|---------|--------|
| Bold | `{bf:text}` |
| Command | `{cmd:command}` |
| Option | `{opt option}` |
| Option with arg | `{opth option(type)}` |
| Variable | `{var:varname}` |
| Italic | `{it:text}` |
| Line break | `{break}` |
| Horizontal line | `{hline 2}` |
| Paragraph | `{pstd}` |
| Hanging indent | `{phang}` |
| Example indent | `{phang2}` |

---

## .pkg File Template

```stata
v 3
d 'MYCOMMAND': Brief description of the package
d
d Requires: Stata version 16+
d
d Distribution-Date: 20260128
d License: MIT
d
d Author: Timothy P Copeland
d Support: timothy.copeland@ki.se
d
f mycommand/mycommand.ado
f mycommand/mycommand.sthlp
```

### CRITICAL Notes

- `v 3` is the FILE FORMAT version - **NEVER change this**
- `Distribution-Date` (YYYYMMDD) is how Stata detects updates - **ALWAYS update with each release**
- List all files with `f` prefix
- Include author email with `Support:` line

---

## stata.toc File Template

```stata
v 3
d Stata-Tools: mycommand
d Timothy P Copeland, Karolinska Institutet
d https://github.com/tpcopeland/Stata-Tools
p mycommand
```

### Notes

- `v 3` is the FILE FORMAT version - **NEVER change this**
- One `p` line per package
- URL should point to repository root

---

## README.md Template

```markdown
# mycommand

![Stata 16+](https://img.shields.io/badge/Stata-16%2B-brightgreen) ![MIT License](https://img.shields.io/badge/License-MIT-blue)

Brief description of what the command does.

## Installation

```stata
net install mycommand, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/mycommand")
```

---

## Syntax

```stata
mycommand varlist [if] [in], required_option(varname) [options]
```

### Required Options

| Option | Description |
|--------|-------------|
| `required_option(varname)` | Description of required option |

### Optional Options

| Option | Description |
|--------|-------------|
| `option1` | Description (default: value) |
| `generate(newvar)` | Name for output variable |

## Examples

```stata
sysuse auto, clear
mycommand price mpg, required_option(weight)
mycommand price mpg if foreign==0, required_option(weight) generate(result)
```

## Stored Results

`mycommand` stores the following in `r()`:

**Scalars:**
- `r(N)` - number of observations

**Macros:**
- `r(varlist)` - variables analyzed

## Author

Timothy P Copeland<br>
Department of Clinical Neuroscience<br>
Karolinska Institutet

## License

MIT License

## Version

Version 1.0.0, 2026-01-28
```

### README Requirements

- Use `<br>` for line breaks in Author section (not `\n`)
- Single-line `net install` command with quotes around URL
- Include Stata version and license badges
- Version format: `Version X.Y.Z, YYYY-MM-DD`

---

## Test File Template

```stata
/*******************************************************************************
* test_mycommand.do
*
* Functional tests for mycommand
* Run with: stata-mp -b do test_mycommand.do
*******************************************************************************/

clear all
set more off
version 16.0

capture log close
log using "test_mycommand.log", replace

display _dup(70) "="
display "FUNCTIONAL TESTS: mycommand"
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
    mycommand price mpg, required_option(weight)
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

---

## Version Synchronization Checklist

When updating any file, ensure all versions match:

| File | Location | Format |
|------|----------|--------|
| .ado | Header line | `*! name Version X.Y.Z  YYYY/MM/DD` |
| .sthlp | Version comment | `{* *! version X.Y.Z  DDmonYYYY}` |
| .pkg | Distribution-Date | `Distribution-Date: YYYYMMDD` |
| README.md | Version section | `Version X.Y.Z, YYYY-MM-DD` |

**Always run:** `.claude/scripts/check-versions.sh [package]`

---

*See also: `_devkit/docs/dialog-guide.md` for dialog file development*
