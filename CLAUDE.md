# Stata Coding Guide for Claude

**Purpose**: Quick reference for developing Stata packages, auditing .do files, and writing Stata commands. Optimized for Claude Opus 4.

---

## Critical Rules (Always Follow)

1. **Always set**: `version X.0`, `set varabbrev off`, `set more off`
   - Use `version 16.0` for maximum compatibility (recommended for packages)
   - Use `version 18.0` when using Stata 18-specific features
   - Use `version 18.5` for StataNow-specific features
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
└── test_*.do           # Test scripts
```

**Note**: All packages use MIT license. Do NOT create separate LICENSE or LICENSE.md files.

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
v 3
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

**Note**: The `v 3` is the **.pkg file format version** (the current Stata specification), NOT a package version. This line should always be `v 3` and does NOT need to be incremented with updates. Package updates are tracked via the `Distribution-Date` field (see "CRITICAL: Always Update .pkg Files" section below).

### stata.toc

```stata
v 3
d Stata-Tools: mycommand
d Your Name, Institution, Location
d https://github.com/username/repository
p mycommand
```

**Note**: The `v 3` is the **TOC format version** (the current Stata specification), NOT a package version. This line should always be `v 3` and does NOT need to be incremented with updates.

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

MIT License

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
POSITION . . 640 250

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

### Complete Dialog Structure (tvtools pattern)

```stata
VERSION 16.0
INCLUDE _std_large
DEFINE _dlght 480
DEFINE _dlgwd 640
INCLUDE header

HELP hlp1, view("help mycommand")
RESET res1

SCRIPT PREINIT
BEGIN
    program parseMessage
    script max_setOptionalOn
END

SCRIPT POSTINIT
BEGIN
    script max_setDefaultWidth
END

DIALOG main, label("mycommand - Description") tabtitle("Main")
BEGIN
  TEXT     tx_using      20  10  620  ., label("Input dataset:")
  FILE     fi_using      20  +20 610  ., error("Input dataset") ///
           label("Browse...") filter("Stata datasets|*.dta|All files|*.*")

  GROUPBOX gb_required   10  60  620  115, label("Required variables")
  TEXT     tx_id         20  +15 280  ., label("Person ID variable:")
  VARNAME  vn_id         @   +20 @    ., label("ID variable")

  TEXT     tx_date       330 -20 280  ., label("Date variable:")
  EDIT     ed_date       @   +20 @    ., label("Date")
END

DIALOG options, tabtitle("Options")
BEGIN
  GROUPBOX gb_type       10  10  620  80, label("Type selection")
  RADIO    rb_opt1       20  +20 590  ., label("Option 1") first
  RADIO    rb_opt2       @   +20 @    ., label("Option 2") last
END

DIALOG output, tabtitle("Output")
BEGIN
  GROUPBOX gb_save       10  10  620  60,  label("Save output")
  FILE     fi_saveas     20  +25 480  ., error("Save as") save ///
           label("Browse...") filter("Stata datasets|*.dta|All files|*.*") ///
           option(saveas)
  CHECKBOX ck_replace    510 @ 110    ., label("Replace") option(replace)
END

LIST units
BEGIN
    days
    months
    years
END

SCRIPT enable_something
BEGIN
    main.ed_field.enable
    main.tx_field.enable
END

SCRIPT disable_something
BEGIN
    main.ed_field.disable
    main.tx_field.disable
END

PROGRAM command
BEGIN
    put "mycommand using "
    put `"""'
    require main.fi_using
    put main.fi_using
    put `"""'
    put ", "

    require main.vn_id
    put "id(" main.vn_id ") "

    if main.rb_opt1 {
        put "type(opt1) "
    }
    if main.rb_opt2 {
        put "type(opt2) "
    }

    if output.fi_saveas {
        put " saveas("
        put `"""'
        put output.fi_saveas
        put `"""'
        put ")"
        option output.ck_replace
    }
END
```

### Dialog File Components

| Component | Purpose | Example |
|-----------|---------|---------|
| `VERSION` | Stata version requirement | `VERSION 16.0` |
| `INCLUDE _std_large` | Standard large dialog size | Provides consistent sizing |
| `DEFINE _dlght` | Custom dialog height | `DEFINE _dlght 480` |
| `DEFINE _dlgwd` | Custom dialog width | `DEFINE _dlgwd 640` |
| `INCLUDE header` | Standard dialog header | Required for proper display |
| `HELP hlp1` | Link to help file | `view("help mycommand")` |
| `RESET res1` | Reset button definition | Clears all fields |
| `SCRIPT PREINIT` | Pre-initialization script | `program parseMessage` |
| `SCRIPT POSTINIT` | Post-initialization script | `script max_setDefaultWidth` |
| `DIALOG name` | Tab definition | `tabtitle("Main")` |
| `LIST name` | Dropdown contents | Used with COMBOBOX |
| `SCRIPT name` | Enable/disable logic | For toggle controls |
| `PROGRAM command` | Command builder | Constructs Stata command |

### Position Syntax

Controls use: `CONTROL name x y width height, options`

| Symbol | Meaning | Example |
|--------|---------|---------|
| `@` | Same as previous | `@ +20 @` = same x, +20 y, same width |
| `+N` | Relative offset | `+20` = 20 pixels below previous |
| `-N` | Negative offset | `-20` = 20 pixels above previous |
| `.` | Default/auto | `.` for height = auto-size |
| Number | Absolute position | `330` = 330 pixels from left |

### CRITICAL: Dialog Spacing Standards

**Context-Aware Spacing Rules**:

| Context | Spacing | When to Use |
|---------|---------|-------------|
| **After GROUPBOX** | +15 | "Required variables" section in Main tab (label→input pairs) |
| **After GROUPBOX** | +20 | Standard elements: TEXT, RADIO, CHECKBOX (including toggles), most content |
| **After GROUPBOX** | +25 | FILE controls in save/output sections only |
| **Between field pairs** | +25 | Vertical separation between different variable fields |
| **Label to input** | +20 | Within a single TEXT→input pair |
| **Radio/checkbox lists** | +20 | Consecutive RADIO or CHECKBOX items |
| **Side-by-side columns** | -20 | Right column TEXT aligns with left label row |
| **Indented sub-controls** | x=40 | Controls belonging to a RADIO option (instead of x=20) |

### Dialog Spacing Examples

```stata
# Example 1: Required variables section - use +15 (Main tab only)
GROUPBOX gb_required   10  60  620  115, label("Required variables")
TEXT     tx_id         20  +15 280  ., label("Person ID variable:")
VARNAME  vn_id         @   +20 @    ., label("ID variable")

# Example 2: Standard TEXT/EDIT section - use +20
GROUPBOX gb_options    10  10  620  100, label("Options")
TEXT     tx_opt1       20  +20 280  ., label("First option:")
EDIT     ed_opt1       @   +20 @    ., label("Option value")

# Example 3: Radio button group - use +20 for all radios
GROUPBOX gb_type       10  185 620  70, label("Event type")
RADIO    rb_single     20  +20 590  ., label("Single event") first
RADIO    rb_recur      @   +20 @    ., label("Recurring event") last

# Example 4: FILE control in save section - use +25
GROUPBOX gb_save       10  255 620  60,  label("Save output")
FILE     fi_saveas     20  +25 480  ., error("Save as") save ///
         label("Browse...") filter("Stata datasets|*.dta|All files|*.*") ///
         option(saveas)
CHECKBOX ck_replace    510 @ 110    ., label("Replace") option(replace)

# Example 5: Toggle CHECKBOX - use +20 (same as regular CHECKBOX)
GROUPBOX gb_stopopt    10  225 620  70,  label("Stop date options")
CHECKBOX ck_pointtime  20  +20 280  ., label("Point-in-time data") ///
         onclickon(script stop_disable) onclickoff(script stop_enable)
TEXT     tx_stop       330 @ 280    ., label("Stop date variable:")
VARNAME  vn_stop       @   +20 @    ., label("Stop") option(stop)

# Example 6: Side-by-side fields with @ alignment
TEXT     tx_id         20  +15 280  ., label("Person ID variable:")
VARNAME  vn_id         @   +20 @    ., label("ID variable")

TEXT     tx_date       330 -20 280  ., label("Event date variable:")
EDIT     ed_date       @   +20 @    ., label("Event date")

# Example 7: Indented sub-controls under RADIO option
RADIO    rb_duration   20  +20 590  ., label("Duration categories:") ///
         onclickon(script duration_selected)
EDIT     ed_duration   40  +20 280  ., label("Duration cutpoints") ///
         option(duration)

# Example 8: Vertical field progression with +25 between pairs
TEXT     tx_start      20  +25 590  ., label("Start date variables:")
EDIT     ed_start      @   +20 @    ., label("Start variables")

TEXT     tx_stop       20  +25 590  ., label("Stop date variables:")
EDIT     ed_stop       @   +20 @    ., label("Stop variables")
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

# CORRECT: Nested macros (inside-out evaluation)
local a = 1
local b1 "test"
display "`b`a''"              // Evaluates `a' first → b1 → "test"

# CORRECT: Indirect macro reference
local varname "price"
local which "varname"
display "``which''"           // Evaluates `which' → varname → price

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

### Extended Macro Functions

Essential functions for working with macros programmatically:

```stata
* Word count and extraction
local n: word count `varlist'              // Count words in list
local first: word 1 of `varlist'           // Get first word
local last: word `n' of `varlist'          // Get last word

* Variable properties
local type: type `varname'                 // Get storage type (byte, int, float, etc.)
local label: variable label `varname'      // Get variable label
local fmt: format `varname'                // Get display format
local vallbl: value label `varname'        // Get value label name

* List operations
local exists: list var in varlist          // Check if var is in list (returns 0/1)
local unique: list uniq mylist             // Remove duplicates
local sorted: list sort mylist             // Sort alphabetically
local combined: list list1 | list2         // Union of two lists
local common: list list1 & list2           // Intersection
local diff: list list1 - list2             // Elements in list1 not in list2

* String operations
local len: length local mystring           // String length
local upper: upper local mystring          // Convert to uppercase
local lower: lower local mystring          // Convert to lowercase
local piece: piece 1 50 of `longstring'    // First 50 chars
```

### gettoken: Advanced Parsing

Use `gettoken` for complex option parsing and tokenizing strings:

```stata
* Basic tokenization - extract first element
local mylist "apple banana cherry"
gettoken first rest : mylist
// first = "apple", rest = "banana cherry"

* Parse with custom delimiter
local options "opt1, opt2, opt3"
gettoken opt1 rest : options, parse(",")
gettoken comma rest : rest, parse(",")     // Remove the comma
// opt1 = "opt1", rest = "opt2, opt3"

* Loop through all elements
local mylist "a b c d e"
while "`mylist'" != "" {
    gettoken element mylist : mylist
    display "Processing: `element'"
}

* Parse key=value pairs
local opts "name=test size=large color=blue"
while "`opts'" != "" {
    gettoken pair opts : opts
    gettoken key value : pair, parse("=")
    gettoken eq value : value, parse("=")  // Remove the =
    display "`key' -> `value'"
}

* Handle quoted strings
local input `"first "second item" third"'
gettoken item1 rest : input, qed(hasquote)
// item1 = "first", hasquote = 0
gettoken item2 rest : rest, qed(hasquote)
// item2 = "second item", hasquote = 1
```

### tokenize Command

```stata
* Split string into numbered macros
tokenize "`varlist'"
display "First var: `1'"
display "Second var: `2'"

* With custom delimiter
tokenize "`options'", parse(",")
display "First option: `1'"

* Process all tokens
tokenize "`varlist'"
local i = 1
while "``i''" != "" {
    display "Variable `i': ``i''"
    local ++i
}
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

## Program Options: byable and sortpreserve

### Overview

| Option | Purpose | When to Use |
|--------|---------|-------------|
| `byable(recall)` | Allow `by varlist:` prefix | Commands that report results |
| `byable(onecall)` | Advanced by-processing | Commands that create variables |
| `sortpreserve` | Restore original sort order | When program re-sorts data |

### byable(recall) - Most Common

Use for commands that report results and can be repeated for each by-group:

```stata
program define mycommand, rclass byable(recall)
    version 16.0
    syntax varlist [if] [in]

    marksample touse

    // Command is automatically re-called for each by-group
    // _byvars contains the by-variables if specified
    if "`_byvars'" != "" {
        display "Processing by-group: `_byvars'"
    }

    // ... computation
end
```

Usage: `by foreign: mycommand price mpg`

### sortpreserve - Restore Sort Order

Use when your program changes the sort order and you want to restore it:

```stata
program define mycommand, rclass sortpreserve
    version 16.0
    syntax varlist [if] [in]

    marksample touse

    // This sort will be undone when program ends
    sort `varlist'

    // ... computation that requires sorted data
end
```

**Note**: `sortpreserve` uses O(n) time to restore order, not O(n ln n).

### Combined Usage

For byable commands that sort internally:

```stata
program define mycommand, rclass sortpreserve byable(recall)
    version 16.0
    syntax varlist [if] [in]

    marksample touse

    // Safe to sort - will be restored
    bysort `_byvars' (`varlist'): /* computation */
end
```

### When NOT to Use

- **Don't use sortpreserve** if your program doesn't change sort order (adds overhead)
- **Don't use byable** if command logically can't work with by-groups
- **Check for by: usage** when command is incompatible:

```stata
if "`_byvars'" != "" {
    display as error "mycommand cannot be used with by:"
    exit 190
}
```

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

## Sample Marking: marksample and markout

### marksample Basics

`marksample` creates a byte indicator variable (conventionally named `touse`) that is 1 for observations to include and 0 for observations to exclude. It handles:
- `if` and `in` conditions
- Missing values in the varlist
- Weight variables

```stata
program define mycommand, rclass
    version 16.0
    syntax varlist [if] [in] [fweight aweight]

    marksample touse                    // Standard usage

    quietly count if `touse'
    if r(N) == 0 error 2000

    // ... rest of program uses `if `touse''
end
```

### marksample Options

| Option | Use When |
|--------|----------|
| `marksample touse` | Standard - excludes obs with missing values in varlist |
| `marksample touse, novarlist` | Allow string variables or don't exclude missing |
| `marksample touse, strok` | Allow string variables (alternative to novarlist) |

```stata
* When varlist may contain strings
syntax varlist [if] [in]
marksample touse, strok           // Don't error on string vars

* When you handle missing values yourself
syntax varlist [if] [in]
marksample touse, novarlist       // Don't auto-exclude missing
```

### markout: Handle Additional Variables

`markout` further restricts the sample for variables NOT in the main varlist (like those in options). **Always use after marksample**.

```stata
program define mycommand, rclass
    version 16.0
    syntax varlist [if] [in], BYvar(varname) [ADJust(varlist)]

    marksample touse                    // Handles main varlist, if/in
    markout `touse' `byvar'             // Also exclude if byvar is missing
    markout `touse' `adjust'            // Also exclude if adjust vars missing

    quietly count if `touse'
    if r(N) == 0 error 2000
end
```

### Key Differences

| Feature | marksample | markout |
|---------|------------|---------|
| Creates touse variable | Yes | No (modifies existing) |
| Handles if/in | Yes | No |
| Handles weights | Yes | No |
| Handles main varlist missings | Yes | N/A |
| Use for option variables | No | Yes |
| Order of use | First | After marksample |

### Common Pattern

```stata
* Complete sample marking pattern
syntax varlist(numeric) [if] [in] [fweight], BY(varname) [Cluster(varname)]

marksample touse                    // Main varlist + if/in + weights
markout `touse' `by'                // Option variable
if "`cluster'" != "" {
    markout `touse' `cluster'       // Optional option variable
}

quietly count if `touse'
if r(N) == 0 {
    display as error "no observations"
    exit 2000
}
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

## Certification Scripts (cscript)

For formal package testing, use Stata's certification script framework:

```stata
* certification_mycommand.do
cscript mycommand adofile mycommand

* Test against known/verified values
sysuse auto, clear
mycommand price mpg
assert abs(r(mean) - 6165.257) < 0.001
assert r(N) == 74

* Test error conditions
rcof "mycommand" == 100                    // varlist required
rcof "mycommand stringvar" == 109          // type mismatch

* Log certification results
cscript log using cert_mycommand.log, replace
```

**Key principles:**
- Run certification script after every code change
- Test against values from trusted sources (other Stata commands, hand calculations)
- Include both success and failure cases
- Protects against introducing bugs during "improvements"

---

## preserve and restore

### Basic Usage

`preserve` saves a copy of the data; `restore` brings it back. Essential when programs modify data temporarily.

```stata
program define mycommand, rclass
    version 16.0
    syntax varlist [if] [in]

    // Parse and validate BEFORE preserve (catch errors early)
    marksample touse
    local varcount: word count `varlist'
    if `varcount' < 2 {
        display as error "need at least 2 variables"
        exit 198
    }

    preserve                              // Now safe to modify data

    keep if `touse'
    // ... modify data, compute results ...

    restore                               // Automatically called at program end
end
```

### Advanced Patterns

```stata
* restore, preserve - Restore but keep preserved copy for reuse
preserve
collapse (mean) price, by(foreign)
// ... use collapsed data ...
restore, preserve                        // Restore but keep copy
collapse (sum) price, by(rep78)
// ... use differently collapsed data ...
restore

* restore, not - Keep modified data (cancel the restore)
preserve
// ... modify data ...
if "`replace'" != "" {
    restore, not                         // Keep changes, don't restore
}
else {
    restore                              // Discard changes
}
```

### Memory Considerations

- Stata/MP stores preserved data in frames (memory) by default
- Falls back to disk when memory is low
- Control with: `set max_preservemem #` (default: 1GB)
- `query memory` shows current settings

### Best Practices

1. **Parse before preserve** - Catch syntax errors before copying data
2. **Use `restore, preserve`** for multiple restores to same state (avoid disk thrashing)
3. **Cannot nest preserves** - Use tempfiles for nested preservation:
   ```stata
   tempfile outer
   save `outer'
   preserve
   // ... inner operations ...
   restore
   use `outer', clear
   ```
4. **Automatic restore on error** - If program errors after preserve, data is restored

---

## Common Error Codes

| Code | Meaning | Common Causes |
|------|---------|---------------|
| 1 | error in expression | Invalid expression syntax |
| 100 | varlist required | Missing variable list in syntax |
| 101 | varlist not allowed | Passed variables when none expected |
| 102 | too few variables | Need more variables than provided |
| 103 | too many variables | Passed more variables than allowed |
| 109 | type mismatch | String vs numeric, wrong variable type |
| 110 | already defined | Variable/program already exists |
| 111 | variable not found | Typo, variable doesn't exist |
| 119 | by may not be combined | Command doesn't support by: prefix |
| 190 | request may not be combined with by | Specific option conflicts with by: |
| 198 | invalid syntax | Bad option, missing comma, wrong format |
| 199 | unrecognized command | Typo in command name, ado not installed |
| 301 | last estimates not found | No estimation results stored |
| 303 | equation not found | Reference to non-existent equation |
| 459 | data inconsistency | Data validation failed (good for custom checks) |
| 601 | file not found | Wrong path, file doesn't exist |
| 602 | file already exists | Use replace option |
| 603 | file could not be opened | Permissions, locked file |
| 610 | file not Stata format | Wrong file type, corrupted file |
| 900 | out of memory | Dataset too large, need more RAM |
| 2000 | no observations | Empty sample, if/in excluded all data |
| 2001 | insufficient observations | Need more obs for computation |

**Custom Error Codes**: Use codes 459 (data inconsistency) or 198 (invalid syntax) for custom validation errors. Avoid codes 1-99 (reserved for system).

**Look up any code**: In Stata, type `search rc ###` to see documentation for error code ###.

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

### Memory Management

```stata
* Always compress after data creation/manipulation
compress                              // Reduces storage types to minimum needed

* Check memory usage
memory                                // Shows current memory allocation
query memory                          // Shows memory settings

* For large datasets, use these patterns:
* 1. Compress early and often
* 2. Drop unneeded variables early: keep var1 var2 var3
* 3. Use frames instead of merging (Stata 16+)
* 4. Work with random subsample during development:
     sample 10                         // Keep random 10%
* 5. Use tempfiles for intermediate results
```

**Large Dataset Workflow**:
```stata
* Step 1: Load and immediately compress
use bigdata.dta, clear
compress
describe, short                       // Check size reduction

* Step 2: Keep only needed variables
keep id year outcome treatment covariates

* Step 3: Use frames for lookups instead of merge
frame create lookup
frame lookup: use lookup_table.dta
frlink m:1 id, frame(lookup)
frget needed_var, from(lookup)
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

## Error Handling Patterns

### Basic capture

```stata
* Suppress error and check return code
capture regress y x1 x2
if _rc != 0 {
    display as error "Regression failed with error `_rc'"
    exit _rc
}
```

### capture noisily - Show Output But Don't Stop

```stata
* Run command, show output, but don't stop on error
capture noisily regress y x1 x2
local rc = _rc
if `rc' != 0 {
    display as error "Regression failed, continuing..."
}

* Useful for batch processing
foreach var in `varlist' {
    capture noisily regress y `var'
    if _rc == 0 {
        estimates store model_`var'
    }
}
```

### capture with Block

```stata
* Capture multiple commands as a block
capture noisily {
    generate newvar = oldvar * 2
    label variable newvar "Doubled value"
    compress newvar
}
if _rc != 0 {
    display as error "Variable creation failed"
    exit _rc
}
```

### Graceful Error Recovery

```stata
program define robust_command
    version 16.0
    syntax varlist [if] [in]

    marksample touse

    * Try preferred method
    capture noisily regress `varlist' if `touse', robust
    if _rc == 0 {
        exit                           // Success
    }

    * Fall back to simpler method
    display as text "Robust failed, trying OLS..."
    capture noisily regress `varlist' if `touse'
    if _rc != 0 {
        display as error "All methods failed"
        exit _rc
    }
end
```

### confirm Commands for Validation

```stata
* Check existence before using
capture confirm variable myvar
if _rc != 0 {
    display as error "Variable myvar not found"
    exit 111
}

capture confirm file "data.dta"
if _rc != 0 {
    display as error "File data.dta not found"
    exit 601
}

capture confirm numeric variable myvar
if _rc != 0 {
    display as error "myvar must be numeric"
    exit 109
}
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

## CRITICAL: Always Update .pkg Files

**IMPORTANT**: When modifying any package in this repository, you MUST update the .pkg file to ensure users get the latest version when they check for updates.

### Required Updates for Every Change:

1. **Update Distribution-Date in .pkg file** - This is how Stata detects package updates:
   ```stata
   v 3
   d 'MYCOMMAND': Brief description
   d
   d Distribution-Date: 20251201
   ```
   **CRITICAL**: Stata's `adoupdate` command compares the `Distribution-Date` string in the local .pkg file against the remote .pkg file. You MUST update this date with each package update or users will not be notified of the update.

   Use format: YYYYMMDD (e.g., 20251201 for December 1, 2025)

   **Note**: The `v 3` line is the .pkg file format version and should ALWAYS be `v 3`. Do NOT increment this number.

2. **Update semantic version in .ado file header** if making code changes (use X.Y.Z format):
   ```stata
   *! commandname Version 1.2.3  15jan2025
   ```
   **IMPORTANT**: Always use three-part format (X.Y.Z), never X.Y or X alone.

3. **Update semantic version in .sthlp file** to match .ado:
   ```smcl
   {* *! version 1.2.3  15jan2025}{...}
   ```

4. **Update README.md files** to match .ado semantic version (X.Y.Z format):
   - Update the package-specific README.md in the package directory
   - Update the main repository README.md in the root directory
   - Both files must reflect the new version number

### CRITICAL: Understanding Version Numbering Systems

There are **two separate version numbering systems** in Stata packages:

1. **File format version (`v 3`)** - Fixed format specification for both .toc and .pkg files:
   - Format: Always `v 3` (the current Stata format specification)
   - Location: First line of BOTH stata.toc and .pkg files
   - Purpose: Tells Stata which file format specification to use when parsing these files
   - Rule: **ALWAYS `v 3`** - this should NEVER change or be incremented
   - **DO NOT increment with package updates** - this is a format version, not a package version
   - Background: `v 3` is the current standard that supports SMCL formatting and the Distribution-Date field. Older formats (`v 1`, `v 2`) are obsolete.

2. **Semantic version number (X.Y.Z)** - Three-part version numbers for your package:
   - Format: **ALWAYS X.Y.Z** (e.g., 1.0.0, 1.2.3, 2.0.1)
   - **NEVER use X.Y or X format** (e.g., NOT 1.0 or 1)
   - Location: .ado headers, .sthlp files, README.md, and text descriptions in .pkg
   - Purpose: Semantic versioning for tracking feature changes
   - Rule: Follow semantic versioning (major.minor.patch)
   - Example: `*! commandname Version 1.2.3  15jan2025`

**Package Update Detection**: Stata's `adoupdate` command detects new versions by comparing the `Distribution-Date` field in .pkg files, NOT by checking version numbers. You must update the Distribution-Date field in the .pkg file whenever you release an update.

**Example files**:

stata.toc (format version - never changes):
```stata
v 3                                     // Format version - ALWAYS v 3
d Stata-Tools: mycommand
d Your Name, Institution
d https://github.com/username/repository
p mycommand
```

mycommand.pkg (format version - never changes; updates tracked by Distribution-Date):
```stata
v 3                                     // Format version - ALWAYS v 3
d 'MYCOMMAND': Version 1.2.3            // Semantic version in description
d
d Distribution-Date: 20251202           // THIS is how Stata detects updates
d License: MIT
d
f mycommand.ado
f mycommand.sthlp
```

### Why This Matters:

- Users run `net from URL` followed by `net install packagename`
- Stata uses the `Distribution-Date` field in the .pkg file to determine if an update is available
- If the `Distribution-Date` is not updated, existing installations will NOT recognize the update
- The stata.toc file is required for the `net from` command to work properly (it lists available packages)
- Both stata.toc and .pkg files use `v 3` as the file format version - do NOT change this

### Workflow:

```stata
* User checks for updates:
net from https://raw.githubusercontent.com/username/repository/main/packagename
net install packagename, replace

* Stata's adoupdate command compares Distribution-Date in .pkg with installed version
* If the remote Distribution-Date is newer, prompts user to update
```

**ALWAYS update Distribution-Date in .pkg file when:**
- Fixing bugs in .ado files
- Updating .sthlp documentation
- Modifying dialog files (.dlg)
- Changing any package functionality
- Updating README or examples
- Making ANY changes that users should receive

**ALWAYS update BOTH README.md files when updating .ado and .pkg files:**
- Update the package-specific README.md in the package directory (e.g., mycommand/README.md)
- Update the main repository README.md in the root directory (e.g., README.md)
- Both files must reflect the current semantic version (X.Y.Z format) from the .ado file

---

## Distribution Checklist

**Before releasing a package:**

- [ ] Semantic version in .ado header uses X.Y.Z format (`*! version 1.0.0`), never X.Y or X
- [ ] Semantic version in .sthlp matches .ado (X.Y.Z format)
- [ ] Semantic version in package README.md matches .ado (X.Y.Z format)
- [ ] Semantic version in main repository README.md matches .ado (X.Y.Z format)
- [ ] .pkg file starts with `v 3` (file format version - NEVER change this)
- [ ] stata.toc starts with `v 3` (file format version - NEVER change this)
- [ ] Distribution-Date in .pkg is CURRENT (YYYYMMDD format) - this is how updates are detected
- [ ] Help file exists and complete
- [ ] Examples in help file work
- [ ] All tests pass
- [ ] Works with `set varabbrev off`
- [ ] Error messages informative
- [ ] No hardcoded paths
- [ ] Handles missing data properly
- [ ] README with single-line installation
- [ ] README follows tvtools format (badges, <br> in Author)
- [ ] MIT License specified in .pkg file and README.md (no separate LICENSE file)
- [ ] Dialog spacing follows +15/+20/+25 rules
- [ ] All Stata syntax verified (backticks, quotes, macros)

### GitHub Distribution

**stata.toc** format (note: `v 3` is the TOC format version, not a package version):
```stata
v 3
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
12. **Wrong version format** - Use X.Y.Z (1.0.0), never X.Y (1.0) or X (1) for semantic versions
13. **Not updating Distribution-Date** - MUST update Distribution-Date in .pkg file with each update for users to see updates
14. **Changing v 3 in .pkg or .toc** - NEVER change `v 3` - it's a file format version, not a package version
15. **Wrong dialog spacing** - Use context-aware +15/+20/+25
16. **Missing backticks in macros** - `` `macroname' `` not `macroname`
17. **Spaces in macro references** - `` `var' `` not `` `var ' ``
18. **Not testing edge cases** - Empty data, missing values, single obs
19. **Creating LICENSE files** - NEVER create LICENSE or LICENSE.md files; use MIT in .pkg and README
20. **Forgetting README updates** - ALWAYS update both package and main README.md when updating .ado/.pkg

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
| Mark additional vars | `markout `touse' varname` |
| Validate variable | `confirm variable var` |
| Validate numeric | `confirm numeric variable var` |
| Check file exists | `confirm file "path"` |
| Temporary objects | `tempvar/tempfile/tempname` |
| Profile performance | `timer on/off` |
| Debug | `set trace on`, `pause` |
| Test assertion | `assert condition` |
| Safe error handling | `capture noisily command` |
| Compress data | `compress` |
| Check memory | `memory`, `query memory` |
| Switch frame | `frame change framename` |
| List frames | `frames dir` |
| Word count | `local n: word count `list'` |
| Get first word | `local first: word 1 of `list'` |
| Parse tokens | `gettoken first rest : list` |
| Export table | `collect export "file.docx"` |
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
| Wrong groupbox start spacing | Visual inconsistency | Use +15 (required vars Main tab), +20 (standard), +25 (FILE in save sections) |
| Using +25 for toggle CHECKBOX | Excessive spacing | Toggle CHECKBOXes use +20 like regular CHECKBOXes |
| Wrong field pair spacing | Cramped/loose layout | Use +25 between pairs, +20 within |
| Side-by-side misalignment | Poor readability | Use -20 for right column TEXT, @ for same row |
| Missing @ for same-row | Elements misaligned | Use @ to maintain row alignment |
| Wrong indentation for sub-controls | Confusing hierarchy | Use x=40 for controls under RADIO options |

### Common Ado Syntax Errors

| Error | Impact | Fix |
|-------|--------|-----|
| Missing marksample | Wrong subset processed | Add `marksample touse` after syntax |
| No observation check | Error on empty data | Add `quietly count if `touse'; if r(N)==0 error 2000` |
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

### Frames: Multiple Datasets in Memory (Stata 16+)

Frames allow working with multiple datasets simultaneously without saving/loading.

```stata
* Basic frame operations
frame create analysis                      // Create new frame
frame change analysis                      // Switch to frame (or: cwf analysis)
frame change default                       // Switch back
frames dir                                 // List all frames

* Copy data between frames
frame copy default analysis                // Copy current data to new frame

* Work across frames without switching
frame analysis: summarize income           // Run command in another frame
frame analysis: local n = _N               // Get values from another frame

* Drop frames when done
frame drop analysis
```

### Linking Frames (Memory-Efficient Alternative to Merge)

```stata
* Instead of merging, link frames
frame create counties
frame counties: use county_data.dta

* Create link from person data to county data
frlink m:1 county_id, frame(counties)

* Get variables from linked frame (like merge, but no duplication)
frget median_income population, from(counties)

* Alias variables (reference without copying - minimal memory)
fralias add med_income = median_income, from(counties)
```

**Memory benefits**: Linked frames avoid duplicating data. For 100k persons linked to 1k counties, you save ~99% of memory vs. a merge.

### Framesets (Stata 18+)

```stata
* Save multiple related frames together
frames save myproject.dtas, frames(main analysis results)

* Load a frameset
frames use myproject.dtas

* Modify frameset on disk without loading (Stata 19+)
frames drop results using myproject.dtas
```

### Customizable Tables: collect, table, and etable (Stata 17+), dtable (Stata 18+)

The `collect` system creates publication-ready tables exportable to Word, Excel, LaTeX, etc.

```stata
* Basic regression table
table () (result), command(regress y x1 x2 x3)
collect export "results.docx", replace

* Multiple models side-by-side
collect clear
quietly regress y x1 x2
collect _r_b _r_se, name(m1) tag(model[1])
quietly regress y x1 x2 x3
collect _r_b _r_se, name(m1) tag(model[2])
collect layout (colname) (model)
collect export "comparison.xlsx", replace

* Descriptive statistics table (Table 1) - Stata 18+ only
dtable age income education, by(treatment) export("table1.docx", replace)

* Estimation table with common styling
etable, column(dvlabel) export("regression.docx", replace)
```

### Table Customization

```stata
* Number formatting
collect style cell result[_r_b], nformat(%9.3f)
collect style cell result[_r_se], nformat(%9.3f) sformat("(%s)")

* Headers and titles
collect style header result, level(hide)
collect title "Table 1: Regression Results"

* Export to multiple formats
collect export "results.docx", replace
collect export "results.xlsx", replace
collect export "results.tex", replace
collect export "results.html", replace
```

---

## Summary: Critical Success Factors

1. **Always use**: `version 16.0` (or 18.0), `set varabbrev off`, `marksample touse`, `set seed`
2. **Read before editing**: NEVER modify files without reading them first
3. **Verify syntax**: Double-check backticks, quotes, macro references, nested expansions
4. **Use marksample + markout**: Handle if/in/weights with marksample, options with markout
5. **Dialog spacing**: Use context-aware +15/+20/+25 spacing rules
6. **Test thoroughly**: Edge cases, error handling, certification scripts
7. **Document completely**: Help file, examples, return values, README with <br>
8. **Validate inputs**: All inputs, sanitize file paths, check ranges with confirm commands
9. **Error handling**: Use capture noisily for graceful failures, proper error codes
10. **Memory efficiency**: compress data, use frames (16+) over merges, keep minimal variables
11. **Modern features**: collect/table for export (17+), frames for multi-dataset work (16+)
12. **Single-line install**: README must have one-line net install command
13. **Version numbers**: Use X.Y.Z format for semantic versions; ALWAYS use `v 3` in .pkg and .toc files (file format version); update Distribution-Date in .pkg for each release
14. **Follow templates**: Use tvtools format for README, proper .pkg format
15. **License handling**: All packages use MIT license; NEVER create separate LICENSE or LICENSE.md files
16. **README updates**: ALWAYS update BOTH package README.md and main repository README.md when updating .ado/.pkg files

---

**End of Stata Coding Guide for Claude**
