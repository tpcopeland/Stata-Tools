# Stata Package Development Guide (LLM-Optimized)

**Purpose**: Complete reference for developing Stata packages. Optimized for minimal token usage while maintaining comprehensive coverage.

---

## 1. Package Structure

### Minimal Package
```
mypackage/
├── mypackage.ado       # Main command
├── mypackage.sthlp     # Help file
└── mypackage.pkg       # Package metadata
```

### Complete Package
```
mypackage/
├── *.ado               # Ado files (main + helpers)
├── *.sthlp            # Help files
├── *.dlg              # Dialog files (optional)
├── *.pkg              # Package description
├── stata.toc          # Table of contents
├── README.md          # Documentation
├── LICENSE            # License file
└── test_*.do          # Test scripts
```

### Complete Minimal Working Example

Here's a tiny but complete package you can copy-paste:

**mysum.ado**:
```stata
*! version 1.0.0  15jan2024
program define mysum, rclass
    version 18.0
    syntax varlist(numeric) [if] [in]

    marksample touse
    quietly count if `touse'
    if r(N) == 0 error 2000

    quietly summarize `varlist' if `touse'
    return scalar mean = r(mean)
    return scalar N = r(N)
end
```

**mysum.sthlp**:
```smcl
{smcl}
{title:Title}
{p2colset 5 14 16 2}{p2col:{cmd:mysum}}Simple mean calculator{p_end}{p2colreset}

{title:Syntax}
{p 8 13 2}{cmd:mysum} {varlist} {ifin}

{title:Description}
{pstd}{cmd:mysum} calculates the mean of numeric variables.

{title:Examples}
{phang2}{cmd:. sysuse auto}{p_end}
{phang2}{cmd:. mysum price mpg}{p_end}

{title:Author}
{pstd}Your Name{p_end}
```

**mysum.pkg**:
```stata
v 3
d mysum: Simple mean calculator
d Author: Your Name
f mysum.ado
f mysum.sthlp
```

**To test**: Place all three files in a folder, then:
```stata
net install mysum, from("C:/path/to/folder") replace
sysuse auto
mysum price
return list
```

---

## 2. Ado File Essentials

### Template
```stata
*! version 1.0.0  15jan2024
*! Author: Name

program define mycommand, rclass
    version 18.0
    syntax varlist [if] [in] [, Option1 Option2(string)]

    marksample touse

    * Validate
    quietly count if `touse'
    if r(N) == 0 error 2000

    * Execute
    quietly {
        // computation
    }

    * Return
    return scalar N = r(N)
    return local varlist "`varlist'"
end
```

### Program Classes

| Class | Use Case | Declaration | Returns |
|-------|----------|-------------|---------|
| `rclass` | General commands | `program define cmd, rclass` | `return scalar/local/matrix` |
| `eclass` | Estimation commands | `program define cmd, eclass` | `ereturn post/scalar/local` |
| `sclass` | String parsing | `program define cmd, sclass` | `sreturn local` |
| `nclass` | No returns | `program define cmd` | Nothing stored |

### Extended Syntax Patterns

```stata
* Using file
syntax using/ [, options]

* Exact variable count
syntax varlist(min=2 max=2) [if] [in]

* Numeric variables only
syntax varlist(numeric) [if] [in]

* Multiple weight types
syntax varlist [aweight fweight pweight] [if] [in]

* Anything (unparsed arguments)
syntax anything [, options]

* Name list
syntax namelist [, options]
```

### Critical Rules
- Always set `version 18.0`
- Use `marksample touse` for if/in
- Return results via `return` (rclass) or `ereturn` (eclass)
- Use `tempvar`/`tempfile`/`tempname` for temporary objects
- Validate all inputs before processing
- Provide informative error messages

### Common Error Codes
- 100: varlist required
- 109: type mismatch
- 111: variable not found
- 198: invalid syntax
- 601: file not found
- 2000: no observations

---

## 3. Help File (.sthlp) Structure

### Minimal Template
```smcl
{smcl}
{* *! version 1.0.0  15jan2024}
{title:Title}

{p2colset 5 18 20 2}{...}
{p2col :{cmd:mycommand} {hline 2}}Brief description{p_end}
{p2colreset}{...}

{marker syntax}
{title:Syntax}

{p 8 16 2}
{cmd:mycommand} {varlist} {ifin} [{cmd:,} {it:options}]

{synoptset 20 tabbed}{...}
{synopthdr}
{synoptline}
{synopt :{opt option1}}description{p_end}
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

{title:Author}

{pstd}Your Name{break}
Email: your@email.com
```

### SMCL Quick Reference
- `{cmd:text}` - Command format
- `{it:text}` - Italic
- `{bf:text}` - Bold
- `{help command}` - Help link
- `{p 8 16 2}` - Paragraph (left, indent, right)
- `{synopt:}` - Syntax option
- `{marker name}` - Section marker

---

## 4. Dialog Programming (.dlg)

### Minimal Dialog
```stata
VERSION 18.0
POSITION . . 400 250

DIALOG main, label("My Command") tabtitle("Main")
BEGIN
    TEXT     tx_var    10  10  100  ., label("Variable:")
    VARNAME  vn_var    120 10  200  ., label("varname")
    CHECKBOX ck_option 10  40  200  ., label("Option") default(0)
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

### Standard Spacing (Critical for Visual Consistency)

| Context | Spacing | Usage |
|---------|---------|-------|
| After GROUPBOX label | +15 | First element inside groupbox |
| Between field pairs | +25 | Vertical rhythm |
| Between groupboxes | +25 | Section separation |
| Label to input | +20 | Within a field pair |
| Radio/checkbox lists | +20 | Consecutive items |

### Common Controls
- `TEXT` - Static label
- `EDIT` - Text input
- `VARNAME` - Single variable
- `VARLIST` - Multiple variables
- `CHECKBOX` - Boolean option
- `RADIO` - Radio button (use `first`/`last`)
- `COMBOBOX` - Dropdown
- `SPINNER` - Numeric spinner
- `FILE` - File browser
- `GROUPBOX` - Visual grouping

### Pattern: Groupbox with Fields
```stata
GROUPBOX gb_name  10  +25 620  HEIGHT, label("Section")
TEXT     tx_field 20  +15 280  ., label("Field:")
EDIT     ed_field @   +20 @    ., label("input")

TEXT     tx_next  20  +25 280  ., label("Next:")
EDIT     ed_next  @   +20 @    ., label("input")
```

**Key**: +15 for first element, +25 between pairs, +20 within pairs

### Pattern: Side-by-Side Fields
```stata
TEXT     tx_left   20  +15 280  ., label("Left field:")
EDIT     ed_left   @   +20 @    ., label("Left")

TEXT     tx_right  330 -20 280  ., label("Right field:")
EDIT     ed_right  @   +20 @    ., label("Right")
```

**Key**: Right column uses `-20` to align with left column's label

### Common Spacing Issues (Before/After)

**Issue: Inconsistent groupbox spacing**
```stata
* BEFORE (bad - mixed +30, +40)
GROUPBOX gb_one   10  10  620  100, label("Section 1")
GROUPBOX gb_two   10  +40 620  100, label("Section 2")
GROUPBOX gb_three 10  +30 620  100, label("Section 3")

* AFTER (good - consistent +25)
GROUPBOX gb_one   10  10  620  100, label("Section 1")
GROUPBOX gb_two   10  +25 620  100, label("Section 2")
GROUPBOX gb_three 10  +25 620  100, label("Section 3")
```

**Issue: Wrong internal padding**
```stata
* BEFORE (bad - +20 after groupbox)
GROUPBOX gb_opts  10  10  620  120, label("Options")
TEXT     tx_opt1  20  +20 280  ., label("Option:")

* AFTER (good - +15 after groupbox)
GROUPBOX gb_opts  10  10  620  120, label("Options")
TEXT     tx_opt1  20  +15 280  ., label("Option:")
```

### Special Cases

**Radio buttons** (consecutive items use +20):
```stata
RADIO rb_opt1  20  +15 590  ., label("Option 1") first
RADIO rb_opt2  @   +20 @    ., label("Option 2")
RADIO rb_opt3  @   +20 @    ., label("Option 3") last
```

**Inline help text** (uses `@` for same-line positioning):
```stata
TEXT tx_days     20  +15 240  ., label("Days:")
EDIT ed_days     @   +20 120  ., label("Days")
TEXT tx_help     150 @   460  ., label("(0-365)")
```

### PROGRAM Command Basics

The PROGRAM section builds the Stata command from dialog inputs:

```stata
PROGRAM command
BEGIN
    put "mycommand "           // Start command
    require vn_varname         // Error if empty
    put vn_varname             // Add variable

    if ck_option {             // Conditional option
        put ", option"
    }

    put " " ed_value           // Add value with space
END
```

**Key commands**: `put` (add text), `require` (validate), conditional `if`/`else`

---

## 5. Testing Framework

### Basic Test Structure
```stata
clear all
set seed 12345

* Test 1: Basic functionality
assert condition1
assert condition2

* Test 2: Error handling
capture mycommand invalid_input
assert _rc != 0

* Test 3: Results validation
mycommand y x
assert abs(r(result) - expected) < 1e-8
```

### Test Patterns
```stata
* Assert with tolerance
assert abs(actual - expected) < 1e-8

* Test should fail
capture command
assert _rc != 0

* Validate return values
mycommand y x
assert r(N) == expected_n
assert !missing(r(result))
```

### Running Tests

**Single test file**:
```stata
do test_mycommand.do
```

**Multiple test files** (recommended structure):
```
tests/
├── test_basic.do        # Basic functionality
├── test_edge_cases.do   # Edge cases
├── test_errors.do       # Error handling
└── run_all_tests.do     # Master test runner
```

**run_all_tests.do** pattern:
```stata
clear all
set more off

local test_files "test_basic test_edge_cases test_errors"

foreach test of local test_files {
    display _n as result "Running `test'.do..."
    quietly do `test'.do
    display as result "`test'.do: PASSED"
}

display _n as result "All tests passed!"
```

### Test Organization Best Practices

- **One test file per feature**: `test_varname_validation.do`, `test_option_parsing.do`
- **Name pattern**: `test_*.do` for easy globbing
- **Self-contained**: Each test clears data, sets seed, loads fixtures
- **Fast**: Keep tests under 1 second each when possible
- **Informative failures**: Use `assert` with clear variable names

---

## 6. Package Metadata (.pkg)

```stata
v 3
d mypackage: Brief description
d
d Author: Your Name, Institution
d Support: email@domain.com
d
d Requires: Stata version 18
d Distribution-Date: 20240115
d
d KW: keyword1
d KW: keyword2
d
f mypackage.ado
f mypackage.sthlp
```

---

## 7. Synthetic Data Generation

### Basic Patterns
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

* Correlated
generate z1 = rnormal()
generate z2 = rnormal()
local rho = 0.7
generate x = z1
generate y = `rho'*z1 + sqrt(1-`rho'^2)*z2
```

### Panel Data
```stata
clear
set obs 500
set seed 12345

generate id = _n
generate ability = rnormal()

expand 10
bysort id: generate time = _n

generate outcome = 2.5 + 0.05*time + ability + rnormal(0, 0.2)

xtset id time
```

---

## 8. Mata Integration

### Basic Pattern
```stata
program define mycommand
    version 18.0
    syntax varlist

    mata: do_computation("`varlist'")
end

mata
void do_computation(string scalar varlist) {
    real matrix X

    // Read data (view = efficient)
    st_view(X, ., tokens(varlist))

    // Compute
    result = mean(X)

    // Return
    st_numscalar("r(mean)", result)
}
end
```

### Key Functions
- `st_view()` - View data (efficient, no copy)
- `st_data()` - Copy data
- `st_store()` - Write data
- `st_matrix()` - Transfer matrix
- `st_numscalar()` - Transfer scalar
- `st_local()` - Transfer local macro

### When NOT to Use Mata

**Use Stata instead for**:
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

**Performance break-even**: Mata helps when >10,000 observations with complex operations or loops. Below that, Stata's simplicity often wins.

---

## 9. Performance Optimization

### Rules
1. Vectorize: `generate y = x^2` not loops
2. Single pass: Calculate multiple stats together
3. Use Mata for: matrix ops, loops, algorithms
4. Use Stata for: data management, standard estimation
5. Profile: `timer on/off`, identify bottlenecks
6. Compress: Minimize storage types

### Example
```stata
* SLOW
forvalues i = 1/`=_N' {
    replace y = x[`i']^2 in `i'
}

* FAST
generate y = x^2

* FASTEST (Mata for complex operations)
mata: st_store(., "y", st_data(., "x"):^2)
```

---

## 10. Project Organization

```
project/
├── README.md
├── code/
│   ├── 00_master.do
│   ├── 01_data_cleaning.do
│   ├── 02_analysis.do
│   └── functions/
│       ├── myfunction.ado
│       └── myfunction.sthlp
├── data/
│   ├── raw/
│   ├── processed/
│   └── final/
└── output/
    ├── tables/
    ├── figures/
    └── logs/
```

### Master Script Pattern
```stata
clear all
set more off
set varabbrev off

global project_dir "`c(pwd)'"
global data_dir "${project_dir}/data"
global output_dir "${project_dir}/output"

adopath ++ "${project_dir}/code/functions"

log using "${output_dir}/logs/analysis_`c(current_date)'.log", replace

do "${project_dir}/code/01_data_cleaning.do"
do "${project_dir}/code/02_analysis.do"

log close
```

---

## 11. Coding Standards

### Essential Settings
```stata
clear all
set more off
set varabbrev off    # Critical!
set linesize 120
version 18.0
```

### Naming Conventions
- Variables: `snake_case`
- Temporary: `tempvar name` or `temp_prefix`
- Locals: descriptive names
- No abbreviations in production code

### Error Handling
```stata
* Validate
capture confirm variable varname
if _rc {
    display as error "variable varname not found"
    exit 111
}

* Check conditions
if condition_fails {
    display as error "Clear error message"
    display as error "What user should do"
    exit 198
}
```

---

## 12. Common Pitfalls

| Issue | Problem | Solution |
|-------|---------|----------|
| varabbrev | Variable abbreviation | `set varabbrev off` |
| Random seed | Non-reproducible | `set seed 12345` |
| File paths | Backslashes fail | Use forward slashes |
| Missing values | Ignored | Use `marksample touse` |
| Global pollution | Persistent state | Use locals, not globals |
| No version | Breaking changes | `version 18.0` |

### Debugging Workflow

**Step 1: Enable trace**
```stata
set trace on
mycommand args     // Watch execution line by line
set trace off
```

**Step 2: Add strategic pauses**
```stata
program define mycommand
    version 18.0
    syntax varlist

    marksample touse
    pause on           // Enable pausing
    pause              // Execution stops here

    * Check state
    display "touse contains: " `touse'
    list if `touse' in 1/5

    * Continue...
end
```
Type `q` in pause mode to continue, `BREAK` to stop.

**Step 3: Display intermediate values**
```stata
display as result "Debug: varlist = `varlist'"
display as error "Debug: N = " _N
display as text "Debug: touse sum = " sum(`touse')
```

**Step 4: Inspect return values**
```stata
mycommand y x
return list        // See all r() values
ereturn list       // See all e() values (after estimation)
```

### Common Error Messages

| Error | Meaning | Fix |
|-------|---------|-----|
| "varlist required" | Missing required varlist | Check syntax statement |
| "invalid syntax" | Bad option/argument | Verify syntax, check spelling |
| "type mismatch" | String vs numeric | Use `confirm variable`, check types |
| "no observations" | Empty sample | Check if/in, missing data |
| "matrix not found" | Undefined matrix | Check tempname, matrix creation |

**Pro tip**: When stuck, add `set trace on` and `pause` right before the error. Watch local macros populate to find the issue.

---

## 13. Distribution Checklist

### Before Release
- [ ] Version in header
- [ ] Help file exists and complete
- [ ] Examples in help file work
- [ ] Tests pass
- [ ] Works with `set varabbrev off`
- [ ] Error messages informative
- [ ] No hardcoded paths
- [ ] Handles missing data
- [ ] README with installation
- [ ] License file

### SSC Submission
```stata
* Test locally
net install mypackage, from("C:/mypackage") replace

* Create zip
zip mypackage.zip mypackage.ado mypackage.sthlp mypackage.pkg

* Email to: kit.baum@bc.edu
* Subject: SSC submission: mypackage
```

### GitHub Distribution
```stata
* Users install via:
net install mypackage, ///
    from("https://raw.githubusercontent.com/user/repo/main/")
```

---

## 14. Quick Reference Tables

### syntax Command Elements
| Element | Code | Meaning |
|---------|------|---------|
| Required varlist | `syntax varlist` | 1+ variables |
| Optional varlist | `syntax [varlist]` | 0+ variables |
| Specific count | `syntax varlist(min=2 max=3)` | 2-3 variables |
| If/in | `[if] [in]` | Conditions |
| Weights | `[weight]` | All weights |
| Required option | `OPTion` | Capital = required |
| Optional option | `option` | Lowercase = optional |
| Option with arg | `option(string)` | Takes argument |

### Return Value Types
| Class | Use | Storage | Access |
|-------|-----|---------|--------|
| rclass | Regular commands | r() | `return scalar/local` |
| eclass | Estimation | e() | `ereturn post/scalar/local` |
| sclass | String parsing | s() | `sreturn local` |

### Temporary Objects
```stata
tempvar varname      # Temporary variable
tempname matrix      # Temporary matrix/scalar
tempfile filename    # Temporary file
```

---

## 15. Advanced Patterns

### Custom Predict
```stata
program define mycommand, eclass
    regress `varlist'
    ereturn local cmd "mycommand"
    ereturn local predict "mycommand_p"
end

program define mycommand_p
    syntax newvarname [if] [in], [xb Residuals]

    if "`xb'" != "" {
        _predict `typlist' `varlist' if `touse', xb
    }
    else if "`residuals'" != "" {
        _predict `typlist' `varlist' if `touse', residuals
    }
end
```

### Subcommands
```stata
program define mycommand
    gettoken subcmd 0 : 0

    if "`subcmd'" == "summarize" {
        mycommand_summarize `0'
    }
    else if "`subcmd'" == "graph" {
        mycommand_graph `0'
    }
    else {
        display as error "unknown subcommand: `subcmd'"
        exit 198
    }
end
```

---

## 16. Mata Quick Reference

```stata
mata
    // Read Stata data (view = efficient)
    st_view(X, ., "varlist")

    // Compute
    means = mean(X)
    XtX = quadcross(X, X)
    XtXinv = invsym(XtX)

    // Write back
    st_matrix("result", means)
    st_numscalar("r(scalar)", sum)
end
```

**When to use Mata**: Matrix operations, intensive loops, custom algorithms
**When to use Stata**: Data management, standard estimation, graphics

**When NOT to use Mata**: Simple `generate` transformations, standard regressions, merges, graphics (use Stata's vectorized commands instead - they're faster and clearer for these tasks).

---

## 17. Documentation Template

```stata
*! version 1.0.0  15jan2024
*! mycommand: One-line description
*! Author: Name (email)
*! Depends: package1, package2

/*
Purpose: What this command does

Syntax:
    mycommand varlist [if] [in] [, options]

Options:
    option1(#)  - Description, default: #
    option2     - Description

Examples:
    sysuse auto
    mycommand price mpg, option1(5)

Returns:
    r(N)      - Number of observations
    r(result) - Main result
*/

program define mycommand, rclass
    version 18.0
    // Implementation
end
```

---

## 18. Testing Patterns

### Unit Test
```stata
program define test_basic
    clear
    set obs 100
    set seed 12345
    generate x = rnormal()

    mycommand x
    assert r(N) == 100
    assert abs(r(mean)) < 0.5
end
```

### Edge Cases
```stata
* Empty dataset
clear
set obs 0
capture mycommand x
assert _rc != 0

* All missing
clear
set obs 100
generate x = .
capture mycommand x
assert _rc != 0

* Single observation
clear
set obs 1
generate x = 1
capture mycommand x
// Document expected behavior
```

---

## 19. Git Best Practices

### .gitignore
```gitignore
*.log
*.smcl
*.dta
!data/examples/*.dta
output/
.DS_Store
```

### Commit Messages
```
Good: "Add robust standard errors option"
Bad:  "update"
```

---

## 20. Essential Commands Summary

| Task | Command |
|------|---------|
| Load data efficiently | `st_view()` in Mata |
| Mark sample | `marksample touse` |
| Validate variable | `confirm variable var` |
| Check file exists | `confirm file "path"` |
| Temporary objects | `tempvar/tempfile/tempname` |
| Profile performance | `timer on/off` |
| Debug | `set trace on`, `pause` |
| Test assertion | `assert condition` |

---

## Summary: Critical Success Factors

1. **Always use**: `version 18.0`, `set varabbrev off`, `marksample touse`
2. **Test**: Edge cases, error handling, reproducibility
3. **Document**: Help file, examples, return values
4. **Validate**: All inputs, provide clear error messages
5. **Optimize**: Vectorize, use Mata for intensive operations
6. **Organize**: Clear project structure, version control
7. **Distribute**: SSC and/or GitHub with proper metadata

**Token-saving tip**: Use this guide as reference. Most patterns are templates you can adapt directly.
