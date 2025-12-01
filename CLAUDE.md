# Stata Coding Guide for Claude

**Purpose**: Quick reference for developing Stata packages, auditing .do files, and writing Stata commands. Optimized for Claude Sonnet 4.5.

---

## Critical Rules (Always Follow)

1. **Always set**: `version 18.0`, `set varabbrev off`, `set more off`
2. **Use `marksample touse`** for if/in conditions in programs
3. **Return results** via `return` (rclass) or `ereturn` (eclass)
4. **Use temp objects**: `tempvar`, `tempfile`, `tempname` for temporary variables/files/matrices
5. **Validate inputs** before processing, provide clear error messages
6. **Never abbreviate** variable names in production code
7. **Read before editing**: ALWAYS use Read tool before modifying any files
8. **Check syntax twice**: Verify backticks, quotes, and macro references before implementing

---

## Package Structure

### Minimal Package
```
mypackage/
├── mypackage.ado       # Main command
├── mypackage.sthlp     # Help file
├── mypackage.pkg       # Package metadata
├── stata.toc           # Table of contents
└── README.md           # Documentation
```

### Complete Package
```
mypackage/
├── *.ado               # Ado files (main + helpers)
├── *.sthlp             # Help files
├── *.dlg               # Dialog files (optional)
├── *.pkg               # Package description
├── stata.toc           # Table of contents
├── README.md           # Installation & examples
├── LICENSE             # License file (MIT recommended)
└── test_*.do           # Test scripts
```

---

## Complete Package Templates

### mycommand.ado

```stata
*! version 1.0.0  15jan2025
*! Author: Your Name
program define mycommand, rclass
    version 18.0
    syntax varlist(numeric) [if] [in] [, Option1 Option2(string)]

    marksample touse
    quietly count if `touse'
    if r(N) == 0 error 2000

    quietly {
        // computation
    }

    return scalar N = r(N)
    return local varlist "`varlist'"
end
```

### mycommand.sthlp

```smcl
{smcl}
{* *! version 1.0.0  15jan2025}
{title:Title}

{p2colset 5 18 20 2}{...}
{p2col:{cmd:mycommand} {hline 2}}Brief description{p_end}
{p2colreset}{...}

{marker syntax}
{title:Syntax}

{p 8 16 2}
{cmd:mycommand} {varlist} {ifin} [{cmd:,} {it:options}]

{synoptset 20 tabbed}{...}
{synopthdr}
{synoptline}
{synopt:{opt option1}}description{p_end}
{synoptline}
{p2colreset}{...}

{marker description}
{title:Description}

{pstd}
{cmd:mycommand} does...

{marker examples}
{title:Examples}

{pstd}Setup{p_end}
{phang2}{cmd:. sysuse auto}{p_end}

{pstd}Basic usage{p_end}
{phang2}{cmd:. mycommand price mpg}{p_end}

{marker results}
{title:Stored results}

{pstd}
{cmd:mycommand} stores the following in {cmd:r()}:

{synoptset 15 tabbed}{...}
{p2col 5 15 19 2: Scalars}{p_end}
{synopt:{cmd:r(N)}}number of observations{p_end}

{marker author}
{title:Author}

{pstd}Your Name{break}
Institution{break}
Email: your@email.com
```

### mycommand.pkg

```stata
v 1
d 'MYCOMMAND': Brief description
d
d Requires: Stata version 16+
d
d Distribution-Date: 20250115
d License: MIT
d
d Author: Your Name
d Institution, Location
d Email: your@email.com
d
d KW: keyword1
d KW: keyword2
d
f mycommand.ado
f mycommand.sthlp
```

### stata.toc

```stata
v 1
d Stata-Tools: mycommand
d Your Name, Institution, Location
d https://github.com/username/repository
p mycommand
```

### README.md Template

```markdown
# mycommand

![Stata 16+](https://img.shields.io/badge/Stata-16%2B-brightgreen) ![MIT License](https://img.shields.io/badge/License-MIT-blue) ![Status](https://img.shields.io/badge/Status-Active-success)

Brief description of what the command does.

## Installation

Install directly from GitHub:

```stata
net install mycommand, from(https://raw.githubusercontent.com/username/repository/main/mycommand)
```

## Quick Start

```stata
sysuse auto, clear
mycommand price mpg
```

## Syntax

```stata
mycommand varlist [if] [in] [, options]
```

## Examples

### Example 1: Basic Usage

```stata
sysuse auto, clear
mycommand price mpg
```

## Author

Your Name<br>
Institution<br>
Location

## License

MIT License - see LICENSE file for details

## Version

Version 1.0.0, 2025-01-15
```

**Critical README Requirements**:
- Use `<br>` at end of each Author line
- Single-line `net install` command
- Include badges for Stata version, license, status
- Follow tvtools/README.md format exactly

---

## Dialog File (.dlg) Development

### Minimal Dialog Template

```stata
VERSION 18.0
POSITION . . 400 250

DIALOG main, label("My Command") tabtitle("Main")
BEGIN
    GROUPBOX gb_required  10  10  620  80,  label("Required variables")
    TEXT     tx_var       20  +15 280  .,   label("Variable:")
    VARNAME  vn_var       @   +20 @    .,   label("varname")

    GROUPBOX gb_options   10  +25 620  80,  label("Options")
    CHECKBOX ck_option    20  +20 590  .,   label("Option") default(0)
END

OK ok1,      label("OK")
CANCEL can1, label("Cancel")
HELP hlp1,   view("help mycommand")

PROGRAM command
BEGIN
    put "mycommand "
    require vn_var
    put vn_var
    if ck_option {
        put ", option"
    }
END
```

### CRITICAL: Dialog Spacing Standards

**Context-Aware Spacing Rules**:

| Context | Spacing | When to Use |
|---------|---------|-------------|
| **After GROUPBOX** | +15 | Required variable sections with simple label→input pairs |
| **After GROUPBOX** | +20 | Standard elements (TEXT, RADIO groups, CHECKBOX lists) |
| **After GROUPBOX** | +25 | FILE controls, toggle CHECKBOXes with onclickon/onclickoff |
| **Between groupboxes** | +25 | Always use for section separation |
| **Between field pairs** | +25 | Vertical rhythm between different fields |
| **Label to input** | +20 | Within a single field pair |
| **Radio/checkbox lists** | +20 | Consecutive related items |
| **Side-by-side columns** | -20 | Right column aligns with left label |

### Dialog Spacing Examples

```stata
# Example 1: Required variables section - use +15
GROUPBOX gb_required   10  60  620  120, label("Required variables")
TEXT     tx_id         20  +15 280  ., label("Person ID variable:")
VARNAME  vn_id         @   +20 @    ., label("ID variable")

# Example 2: Standard options - use +20
GROUPBOX gb_options    10  10  620  100, label("Options")
TEXT     tx_opt1       20  +20 280  ., label("First option:")
EDIT     ed_opt1       @   +20 @    ., label("Option value")

# Example 3: Radio button group - use +20
GROUPBOX gb_type       10  185 620  80, label("Event type")
RADIO    rb_single     20  +20 590  ., label("Single event") first
RADIO    rb_recur      @   +20 @    ., label("Recurring event") last

# Example 4: FILE control - use +25
GROUPBOX gb_save       10  10  620  60,  label("Save output")
FILE     fi_saveas     20  +25 480  ., error("Save as") save ///
         label("Browse...")

# Example 5: Toggle CHECKBOX - use +25
GROUPBOX gb_stopopt    10  225 620  75,  label("Stop date options")
CHECKBOX ck_pointtime  20  +25 280  ., label("Point-in-time data") ///
         onclickon(script stop_disable) onclickoff(script stop_enable)

# Example 6: Between groupboxes - always +25
GROUPBOX gb_one   10  10  620  100, label("Section 1")
...
GROUPBOX gb_two   10  +25 620  100, label("Section 2")

# Example 7: Side-by-side fields
TEXT     tx_left   20  +15 280  ., label("Left field:")
EDIT     ed_left   @   +20 @    ., label("Left")

TEXT     tx_right  330 -20 280  ., label("Right field:")
EDIT     ed_right  @   +20 @    ., label("Right")
```

### Control Naming Conventions

| Control Type | Prefix | Example |
|--------------|--------|---------|
| TEXT | tx_ | tx_varname |
| EDIT | ed_ | ed_value |
| VARNAME | vn_ | vn_id |
| VARLIST | vl_ | vl_vars |
| CHECKBOX | ck_ | ck_option |
| RADIO | rb_ | rb_method |
| COMBOBOX | cb_ | cb_type |
| GROUPBOX | gb_ | gb_options |
| BUTTON | bu_ | bu_browse |
| FILE | fi_ | fi_saveas |
| SPINNER | sp_ | sp_count |

### PROGRAM Command Patterns

```stata
PROGRAM command
BEGIN
    # Simple command with required variable
    put "commandname "
    require vn_varname
    put vn_varname

    # Optional checkbox option
    if ck_option {
        put ", option"
    }

    # Option with value
    if ed_value {
        put " value(" ed_value ")"
    }

    # Conditional radio options
    if rb_opt1 {
        put ", method(method1)"
    }
    else if rb_opt2 {
        put ", method(method2)"
    }

    # Multiple options with comma handling
    beginoptions
        option ck_robust
        option radio(rb_method1 "fe" rb_method2 "re")
    endoptions
END
```

---

## Stata Syntax Verification (CRITICAL)

### Common Stata-Specific Errors

**Always verify these patterns before implementing:**

| Error Pattern | Problem | Correct Pattern |
|---------------|---------|-----------------|
| `` `var list' `` | Space in macro name | `` `varlist' `` |
| `if condition` | Missing backticks | `if `condition'` |
| `` `"string"' `` | Quote handling | Use compound quotes properly |
| Missing tempvar | Variable collision | `tempvar name` before generate |
| `varname` abbreviation | Breaks with varabbrev off | Use full variable names |

### Backtick and Quote Rules

```stata
# CORRECT: Local macro references
local varname "price"
display "`varname'"           // Displays: price

# CORRECT: Nested macros
local var1 "price"
local myvar "`var1'"
display "``myvar''"           // Double backtick for nested

# WRONG: Spaces inside backticks
if ` condition ' {            // ERROR - spaces not allowed
}

# CORRECT: No spaces
if `condition' {              // Correct
}

# CORRECT: Compound quotes for strings with quotes
local text `"This is a "quoted" word"'
display `"`text'"'

# CORRECT: Macro in string
display "The variable is `varname'"

# WRONG: Missing backticks
display "The variable is varname"  // Displays literal text
```

---

## Pre-Implementation Safety Checklist

**Before modifying any files, ALWAYS:**

1. **Read the file first** using Read tool - NEVER edit without reading
2. **Understand the current code** - trace execution flow, identify dependencies
3. **Verify Stata syntax** - double-check backticks, macro references, conditionals
4. **Check dialog spacing** - ensure +15/+20/+25 context-appropriate spacing
5. **Plan changes systematically** - one file at a time, test after each change
6. **Use reference materials** - consult this guide, official docs, working examples

---

## Program Classes

| Class | Use Case | Declaration | Returns |
|-------|----------|-------------|---------|
| `rclass` | General commands | `program define cmd, rclass` | `return scalar/local/matrix` |
| `eclass` | Estimation commands | `program define cmd, eclass` | `ereturn post/scalar/local` |
| `sclass` | String parsing | `program define cmd, sclass` | `sreturn local` |
| `nclass` | No returns | `program define cmd` | Nothing stored |

---

## Essential Syntax Patterns

```stata
* Basic
syntax varlist [if] [in] [, options]

* Numeric only
syntax varlist(numeric) [if] [in]

* Exact variable count
syntax varlist(min=2 max=2) [if] [in]

* With file
syntax using/ [, options]

* Required option (uppercase first letter)
syntax varlist [, REQuired optional]

* Option with argument
syntax varlist [, option(string)]

* Multiple weight types
syntax varlist [aweight fweight pweight] [if] [in]

* Anything (unparsed)
syntax anything [, options]
```

---

## Testing Framework

### Basic Test Structure

```stata
clear all
set seed 12345

* Test 1: Basic functionality
sysuse auto
mycommand price mpg
assert r(N) == 74
assert !missing(r(mean))

* Test 2: Error handling
clear
set obs 0
capture mycommand price
assert _rc != 0

* Test 3: Tolerance check
assert abs(actual - expected) < 1e-8
```

### Edge Cases to Test

**ALWAYS test these scenarios:**

- Empty dataset (0 observations)
- Single observation
- All missing values
- Perfect collinearity
- Zero variance
- Extreme values
- Variable name conflicts
- Invalid if/in conditions
- Missing required options

### Test Organization

```
tests/
├── test_basic.do           # Basic functionality
├── test_edge_cases.do      # Edge cases
├── test_errors.do          # Error handling
├── test_options.do         # Option combinations
└── run_all_tests.do        # Master test runner
```

**run_all_tests.do pattern**:
```stata
clear all
set more off

local test_files "test_basic test_edge_cases test_errors test_options"

foreach test of local test_files {
    display _n as result "Running `test'.do..."
    quietly do `test'.do
    display as result "`test'.do: PASSED"
}

display _n as result "All tests passed!"
```

---

## Common Error Codes

| Code | Meaning | Common Causes |
|------|---------|---------------|
| 100 | varlist required | Missing variable list in syntax |
| 109 | type mismatch | String vs numeric, wrong variable type |
| 111 | variable not found | Typo, variable doesn't exist |
| 198 | invalid syntax | Bad option, missing comma, wrong format |
| 601 | file not found | Wrong path, file doesn't exist |
| 2000 | no observations | Empty sample, if/in excluded all data |

---

## Synthetic Data Generation

```stata
clear all
set seed 12345
set obs 1000

* Binary
generate treated = runiform() < 0.3

* Categorical with probabilities
generate temp = runiform()
generate edu = cond(temp<.2, 1, cond(temp<.5, 2, cond(temp<.8, 3, 4)))
drop temp

* Continuous
generate age = 18 + runiform() * 62
generate income = exp(rnormal(10.5, 0.7))

* Correlated variables (rho=0.7)
generate z1 = rnormal()
generate z2 = rnormal()
local rho = 0.7
generate x = z1
generate y = `rho'*z1 + sqrt(1-`rho'^2)*z2
```

### Panel Data Generation

```stata
clear
set seed 12345
set obs 500  // individuals

generate id = _n
generate ability = rnormal()  // individual effect

expand 10  // 10 time periods
bysort id: generate time = _n

* Time-varying with individual effects
bysort id: generate experience = time - 1
generate outcome = 2.5 + 0.05*experience + ability + rnormal(0, 0.2)

xtset id time
```

---

## Performance Rules

1. **Vectorize**: Use `generate y = x^2` not loops
2. **Single pass**: Calculate multiple stats together
3. **Use Mata for**: matrix ops, intensive loops (>10k obs), custom algorithms
4. **Use Stata for**: data management, standard estimation, graphics
5. **Profile**: `timer on/off` to identify bottlenecks

**When NOT to use Mata**:
```stata
* Simple transformations (Stata is clearer)
generate y = log(x + 1)              // NOT: mata: st_store(...)

* Standard estimation (built-in commands)
regress y x1 x2                      // NOT: mata: invsym(...)

* Data management (Stata excels here)
merge 1:1 id using other.dta         // NOT: mata custom merge

* Graphics (no Mata equivalent)
scatter y x                          // Use Stata graphics
```

---

## Mata Quick Reference

```stata
program define mycommand
    version 18.0
    syntax varlist
    mata: do_computation("`varlist'")
end

mata
void do_computation(string scalar varlist) {
    real matrix X
    st_view(X, ., tokens(varlist))  // View data (efficient)

    result = mean(X)

    st_numscalar("r(mean)", result)  // Return to Stata
}
end
```

**Key functions**: `st_view()`, `st_data()`, `st_store()`, `st_matrix()`, `st_numscalar()`, `st_local()`

---

## Debugging Workflow

```stata
* Step 1: Enable trace
set trace on
mycommand args
set trace off

* Step 2: Add pauses
program define mycommand
    pause on
    pause              // Execution stops here
    display "Debug: varlist = `varlist'"
end

* Step 3: Inspect returns
mycommand y x
return list

* Step 4: Timer for bottlenecks
timer clear
timer on 1
// slow code section
timer off 1
timer list
```

---

## Project Structure

```
project/
├── code/
│   ├── 00_master.do
│   ├── 01_cleaning.do
│   ├── 02_analysis.do
│   └── functions/
│       ├── myfunction.ado
│       └── myfunction.sthlp
├── data/
│   ├── raw/              # NEVER modify
│   ├── processed/
│   └── final/
├── output/
│   ├── tables/
│   ├── figures/
│   └── logs/
└── tests/
    └── test_*.do
```

**Master script**:
```stata
clear all
set more off
set varabbrev off

global project_dir "`c(pwd)'"
global data_dir "${project_dir}/data"
global output_dir "${project_dir}/output"

adopath ++ "${project_dir}/code/functions"

log using "${output_dir}/logs/analysis.log", replace

do "${project_dir}/code/01_cleaning.do"
do "${project_dir}/code/02_analysis.do"

log close
```

---

## Input Validation & Security

```stata
* Validate numeric ranges
if `threshold' < 0 | `threshold' > 1 {
    display as error "threshold() must be between 0 and 1"
    exit 198
}

* Sanitize file paths - prevent injection
if regexm("`filename'", "[;&|><\$\`]") {
    display as error "filename() contains invalid characters"
    exit 198
}

* Check file existence before operations
confirm file "`using'"

* Validate variable types
capture confirm numeric variable `var'
if _rc {
    display as error "`var' must be numeric"
    exit 109
}
```

**Security Rules**:
- NEVER execute user input directly
- Validate ALL file paths before shell commands
- Check numeric ranges to prevent overflow
- Don't expose sensitive info in error messages
- Use `confirm` for existence checks

---

## Distribution Checklist

**Before releasing a package:**

- [ ] Version in header (`*! version 1.0.0`)
- [ ] Help file exists and complete
- [ ] Examples in help file work
- [ ] All tests pass
- [ ] Works with `set varabbrev off`
- [ ] Error messages informative
- [ ] No hardcoded paths
- [ ] Handles missing data properly
- [ ] README with single-line installation
- [ ] README follows tvtools format (badges, <br> in Author)
- [ ] stata.toc file present
- [ ] .pkg file with complete metadata
- [ ] License file (MIT recommended)
- [ ] Dialog spacing follows +15/+20/+25 rules
- [ ] All Stata syntax verified (backticks, quotes, macros)

### GitHub Distribution

**stata.toc** format:
```stata
v 1
d Stata-Tools: mycommand
d Your Name, Institution, Location
d https://github.com/username/repository
p mycommand
```

**Installation command for README.md**:
```stata
net install mycommand, from(https://raw.githubusercontent.com/username/repository/main/mycommand)
```

**Single line - no line breaks!**

---

## Common Pitfalls to Avoid

1. **Not setting `varabbrev off`** - Variables get abbreviated ambiguously
2. **Not setting seed** - Non-reproducible random results
3. **Backslashes in paths** - Use `/` not `\` (works all OS)
4. **Not quoting paths with spaces** - Always quote: `"my file.dta"`
5. **Forgetting `clear`** - Data in memory warning
6. **Modifying raw data** - NEVER save over raw data files
7. **Ignoring missing values** - Use `if !missing(var)`
8. **Assuming sorted** - Use `bysort` not `by`
9. **String vs numeric** - Check with `describe`, use `destring`
10. **Global pollution** - Use `local` not `global` when possible
11. **Editing without reading** - ALWAYS read files before modifying
12. **Wrong dialog spacing** - Use context-aware +15/+20/+25
13. **Missing backticks in macros** - `` `macroname' `` not `macroname`
14. **Spaces in macro references** - `` `var' `` not `` `var ' ``
15. **Not testing edge cases** - Empty data, missing values, single obs

---

## File Path Rules

```stata
* ALWAYS use forward slashes (works everywhere)
use "C:/data/file.dta", clear  // Good
use "C:\data\file.dta", clear  // Bad (Windows only)

* ALWAYS quote paths
use "my data/file.dta", clear   // Good
use my data/file.dta, clear     // Bad (fails)

* Use globals for projects
global data_dir "${project_dir}/data"
use "${data_dir}/analysis.dta", clear
```

---

## Quick Command Reference

| Task | Command |
|------|---------|
| Mark sample | `marksample touse` |
| Validate variable | `confirm variable var` |
| Check file exists | `confirm file "path"` |
| Temporary objects | `tempvar/tempfile/tempname` |
| Profile performance | `timer on/off` |
| Debug | `set trace on`, `pause` |
| Test assertion | `assert condition` |
| Read before edit | ALWAYS use Read tool first |

---

## Audit Review Process

**When reviewing or modifying existing code:**

1. **Read all related files** - ado, dlg, sthlp, pkg, README
2. **Verify structure** - VERSION on line 1, POSITION on line 2 for dialogs
3. **Check spacing** - Dialog spacing follows +15/+20/+25 context rules
4. **Validate syntax** - Backticks correct, no spaces in macros
5. **Test incrementally** - One change at a time, test after each
6. **Document changes** - Update version numbers, comments
7. **Run all tests** - Ensure nothing breaks

### Common Dialog Spacing Errors

| Error | Impact | Fix |
|-------|--------|-----|
| Wrong groupbox start spacing | Visual inconsistency | Use +15 (required), +20 (standard), +25 (FILE/toggles) |
| Inconsistent groupbox gaps | Unprofessional appearance | Always use +25 between groupboxes |
| Wrong field pair spacing | Cramped/loose layout | Use +25 between pairs, +20 within |
| Side-by-side misalignment | Poor readability | Use -20 for right column alignment |

### Common Ado Syntax Errors

| Error | Impact | Fix |
|-------|--------|-----|
| Missing marksample | Wrong subset processed | Add `marksample touse` after syntax |
| No observation check | Error on empty data | Add `quietly count if touse; if r(N)==0 error 2000` |
| Abbreviated variables | Breaks with varabbrev off | Use full variable names |
| Wrong return class | Return values not stored | Match program class to return type |
| Missing version | Compatibility issues | Add `version 18.0` after program define |
| Spaces in macros | Macro expansion fails | `` `varlist' `` not `` `var list' `` |

---

## Advanced Features

### Factor Variables

```stata
* i. = indicator (dummy) variables
regress y i.treatment              // treatment dummies

* c. = continuous (explicit)
regress y c.age

* # = interaction only
regress y i.treatment#c.age        // interaction only

* ## = full factorial (main + interaction)
regress y i.treatment##c.age       // treatment + age + treatment*age

* ib. = set base level
regress y ib2.treatment            // treatment==2 is reference

* ibn. = no base (all levels, no constant)
regress y ibn.treatment, noconstant
```

### Time Series Operators

```stata
tsset time_var                     // or tsset panel_var time_var

* L. = lag
generate lag1 = L.varname
generate lag2 = L2.varname

* F. = forward/lead
generate lead1 = F.varname

* D. = difference
generate diff = D.varname          // varname - L.varname

* S. = seasonal difference
generate sdiff = S12.varname       // varname - L12.varname

* In regressions
regress y L.y L(0/4).x             // AR(1) with distributed lags
```

### Panel Data

```stata
* Setup panel structure
xtset id time

* Fixed effects
xtreg y x1 x2, fe
xtreg y x1 x2, fe robust

* Random effects
xtreg y x1 x2, re

* Hausman test (FE vs RE)
quietly xtreg y x1 x2, fe
estimates store fe
quietly xtreg y x1 x2, re
estimates store re
hausman fe re
```

---

## Summary: Critical Success Factors

1. **Always use**: `version 18.0`, `set varabbrev off`, `marksample touse`, `set seed`
2. **Read before editing**: NEVER modify files without reading them first
3. **Verify syntax**: Double-check backticks, quotes, macro references
4. **Dialog spacing**: Use context-aware +15/+20/+25 spacing rules
5. **Test thoroughly**: Edge cases, error handling, reproducibility
6. **Document completely**: Help file, examples, return values, README with <br>
7. **Validate inputs**: All inputs, sanitize file paths, check ranges
8. **Organize properly**: Clear structure, stata.toc, .pkg with metadata
9. **Single-line install**: README must have one-line net install command
10. **Follow templates**: Use tvtools format for README, proper .pkg format

---

**End of Stata Coding Guide for Claude**
