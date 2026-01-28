# Stata Coding Guide for Claude

**Purpose**: Quick reference for developing Stata packages, auditing .do files, and writing Stata commands.

---

## Stata Executable

**Always use `stata-mp`** when running Stata commands or do-files. This is the multiprocessor version installed on this machine.

---

## Critical Rules (Always Follow)

1. **Always set**: `version 16.0` (compatibility), `set varabbrev off`, `set more off`
2. **Use `marksample touse`** for if/in conditions in programs
3. **Return results** via `return` (rclass) or `ereturn` (eclass)
4. **Use temp objects**: `tempvar`, `tempfile`, `tempname`
5. **Validate inputs** before processing, provide clear error messages
6. **Never abbreviate** variable names in production code
7. **Read before editing**: ALWAYS use Read tool before modifying any files
8. **Check syntax twice**: Verify backticks, quotes, and macro references before implementing
9. **Macro name limit**: Local and global macro names must be ≤31 characters (Stata silently truncated)
10. **Use `double` precision**: Always use `gen double` for new numeric variables to prevent precision loss
11. **Avoid SSC dependencies**: Minimize external dependencies; if SSC commands are needed, check with `capture which command`

**Version targeting**: Use `version 16.0` for maximum compatibility unless Stata 18 features (frames, Python integration) are specifically required.

---

## Development Resources

All development resources are consolidated in the `_devkit/` directory:

| Directory | Contents |
|-----------|----------|
| `_devkit/_templates/` | Templates for new Stata commands (.ado, .sthlp, .pkg, .dlg, test files) |
| `_devkit/_testing/` | Functional test suites (`test_*.do`) and test data generation |
| `_devkit/_validation/` | Validation tests (`validation_*.do`) with hand-calculated expected values |
| `_devkit/_resources/` | Development support materials (error patterns, log templates) |

### Reference Files

| File | Contains |
|------|----------|
| `_devkit/_testing/notes/ado_error_patterns.md` | Comprehensive catalog of common .ado errors with detection methods |
| `_devkit/_testing/TESTING_INSTRUCTIONS.md` | Repository-specific test data and command coverage |
| `_devkit/_templates/README.md` | Template usage instructions |
| `_devkit/README.md` | Development kit overview |

### Skills (Slash Commands)

This repository includes skills in `.claude/skills/` that provide contextual guidance. All can be invoked with `/skill-name`:

| Skill | Purpose |
|-------|---------|
| `/stata-develop` | Development guidance for creating/modifying commands |
| `/stata-test` | Functional testing workflow |
| `/stata-validate` | Known-answer validation guidance |
| `/stata-audit` | Code review and error detection |
| `/code-reviewer` | Detailed code review with scoring |
| `/stata-code-generator` | Generate code from requirements |
| `/package-tester` | Run tests and validate packages |

### Automation Infrastructure

Full documentation: `.claude/README.md`

**Scripts** (`.claude/scripts/`):

| Script | Purpose | Usage |
|--------|---------|-------|
| `scaffold-command.sh` | Create complete package structure | `.claude/scripts/scaffold-command.sh COMMAND "Description"` |
| `check-versions.sh` | Verify version consistency across files | `.claude/scripts/check-versions.sh [PACKAGE]` |
| `check-test-coverage.sh` | Report test/validation coverage | `.claude/scripts/check-test-coverage.sh [--threshold N]` |

**Validators** (`.claude/validators/`):

| Script | Purpose | Usage |
|--------|---------|-------|
| `validate-ado.sh` | Static analysis (no Stata required) | `.claude/validators/validate-ado.sh mycommand.ado` |
| `run-stata-check.sh` | Syntax check with Stata runtime | `.claude/validators/run-stata-check.sh mycommand.ado` |

**Libraries** (`.claude/lib/`):

| Library | Purpose |
|---------|---------|
| `common.sh` | Shared functions: colors, output, validation, temp files |
| `config.sh` | Centralized configuration with env var overrides |

**Pre-commit hook**: Automatically runs `validate-ado.sh` on staged `.ado` files and `check-versions.sh` on modified packages. Skip with `git commit --no-verify` or `SKIP_ADO_VALIDATION=1`.

**Integration tests**: Run `.claude/tests/run-tests.sh` to verify all automation scripts work correctly.

**Requirements**: Bash 4.0+ (macOS: `brew install bash`), Git, Stata (optional for static analysis).

### Testing vs Validation

| Testing | Validation |
|---------|------------|
| Does the command **run** without errors? | Does the command produce **correct** results? |
| Uses realistic datasets | Uses minimal hand-crafted datasets |
| Checks return codes, variable existence | Checks specific computed values |
| Location: `_devkit/_testing/test_*.do` | Location: `_devkit/_validation/validation_*.do` |

**Both are required** for production-ready commands.

---

## Package Structure

```
mypackage/
├── mypackage.ado       # Main command
├── mypackage.sthlp     # Help file
├── mypackage.pkg       # Package metadata
├── stata.toc           # Table of contents
├── mypackage.dlg       # Dialog file (optional)
└── README.md           # Documentation
```

**Note**: All packages use MIT license. Do NOT create separate LICENSE files.

---

## Package File Templates

### mycommand.ado

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

program define mycommand, rclass
    version 18.0
    set varabbrev off

    syntax varlist(numeric) [if] [in] , REQuired_option(varname) [option1 GENerate(name)]

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

**Header Requirements**: Version line (X.Y.Z format), description, author, program class, block comment with syntax.

### mycommand.sthlp

```smcl
{smcl}
{* *! version 1.0.0  15jan2025}
{title:Title}

{p2colset 5 18 20 2}{...}
{p2col:{cmd:mycommand} {hline 2}}Brief description{p_end}
{p2colreset}{...}

{marker syntax}{title:Syntax}

{p 8 16 2}
{cmd:mycommand} {varlist} {ifin} [{cmd:,} {it:options}]

{synoptset 20 tabbed}{...}
{synopthdr}
{synoptline}
{synopt:{opt option1}}description{p_end}
{synoptline}

{marker description}{title:Description}

{pstd}{cmd:mycommand} does...

{marker examples}{title:Examples}

{phang2}{cmd:. sysuse auto}{p_end}
{phang2}{cmd:. mycommand price mpg}{p_end}

{marker results}{title:Stored results}

{synoptset 15 tabbed}{...}
{p2col 5 15 19 2: Scalars}{p_end}
{synopt:{cmd:r(N)}}number of observations{p_end}

{marker author}{title:Author}

{pstd}Your Name{break}Institution{break}Email: your@email.com
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
d
f mycommand.ado
f mycommand.sthlp
```

**CRITICAL**: `v 3` is the file format version (NEVER change). `Distribution-Date` is how Stata detects updates (ALWAYS update with each release).

### stata.toc

```stata
v 3
d Stata-Tools: mycommand
d Your Name, Institution
d https://github.com/username/repository
p mycommand
```

### README.md Template

```markdown
# mycommand

![Stata 16+](https://img.shields.io/badge/Stata-16%2B-brightgreen) ![MIT License](https://img.shields.io/badge/License-MIT-blue)

Brief description.

## Installation

```stata
net install mycommand, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/mycommand")
```

---

## Syntax

```stata
mycommand varlist [if] [in] [, options]
```

## Examples

```stata
sysuse auto, clear
mycommand price mpg
```

## Author

Timothy P Copeland<br>
Department of Clinical Neuroscience<br>
Karolinska Institutet

## License

MIT License

## Version

Version 1.0.0, 2025-01-15
```

**README Requirements**: Use `<br>` in Author section, single-line `net install` with quotes, badges for Stata version and license.

---

## Dialog File (.dlg) Development

### Basic Template

```stata
VERSION 16.0
INCLUDE _std_large
DEFINE _dlght 480
DEFINE _dlgwd 640
INCLUDE header

HELP hlp1, view("help mycommand")
RESET res1

DIALOG main, label("mycommand - Description") tabtitle("Main")
BEGIN
  GROUPBOX gb_required   10  60  620  115, label("Required variables")
  TEXT     tx_id         20  +15 280  ., label("ID variable:")
  VARNAME  vn_id         @   +20 @    ., label("ID")

  TEXT     tx_date       330 -20 280  ., label("Date variable:")
  EDIT     ed_date       @   +20 @    ., label("Date")
END

PROGRAM command
BEGIN
    put "mycommand "
    require vn_id
    put vn_id
    if ck_option {
        put ", option"
    }
END
```

### Position Syntax

| Symbol | Meaning |
|--------|---------|
| `@` | Same as previous |
| `+N` | Relative offset (pixels below) |
| `-N` | Negative offset (pixels above) |
| `.` | Default/auto |

### Dialog Spacing Rules

| Context | Spacing |
|---------|---------|
| After GROUPBOX (required vars) | +15 |
| After GROUPBOX (standard) | +20 |
| After GROUPBOX (FILE in save) | +25 |
| Label to input (within pair) | +20 |
| Between field pairs | +25 |
| Side-by-side right column | -20 |
| Indented sub-controls | x=40 |

### Control Naming Prefixes

`tx_` TEXT, `ed_` EDIT, `vn_` VARNAME, `vl_` VARLIST, `ck_` CHECKBOX, `rb_` RADIO, `cb_` COMBOBOX, `gb_` GROUPBOX, `fi_` FILE, `sp_` SPINNER

---

## Stata Syntax Essentials

### Macro References

```stata
local varname "price"
display "`varname'"              // Correct: backtick + quote

local a = 1
local b1 "test"
display "`b`a''"                 // Nested: evaluates inside-out → "test"

if `condition' {                 // Correct: no spaces inside backticks
}
```

**CRITICAL: 31-character limit** - Macro names longer than 31 characters are silently truncated. This causes subtle bugs where two differently-named macros become the same:

```stata
// WRONG - both truncate to same 31-char name!
local very_long_descriptive_name_one = 1
local very_long_descriptive_name_two = 2
display `very_long_descriptive_name_one'  // Shows 2, not 1!

// CORRECT - use shorter names
local desc_name_one = 1
local desc_name_two = 2
```

**WRONG**: Spaces in macros (`` `var list' ``), missing backticks (`if condition`), macro names >31 chars

### Common Syntax Patterns

```stata
syntax varlist [if] [in] [, options]           // Basic
syntax varlist(numeric min=2 max=2) [if] [in]  // Constrained
syntax using/ [, options]                       // With file
syntax varlist [, REQuired optional]           // Required option (uppercase)
syntax varlist [aweight fweight] [if] [in]     // Weights
```

### Sample Marking

```stata
marksample touse                    // Main varlist + if/in + weights
markout `touse' `byvar'             // Option variables (use AFTER marksample)

quietly count if `touse'
if r(N) == 0 error 2000
```

### Extended Macro Functions

```stata
local n: word count `varlist'              // Count words
local first: word 1 of `varlist'           // Get first word
local type: type `varname'                 // Variable type
local exists: list var in varlist          // Check membership
```

### gettoken Parsing

```stata
local mylist "apple banana cherry"
gettoken first rest : mylist               // first="apple", rest="banana cherry"

while "`mylist'" != "" {
    gettoken element mylist : mylist
    display "`element'"
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

### byable and sortpreserve

```stata
program define mycommand, rclass byable(recall) sortpreserve
    // byable(recall): re-called for each by-group
    // sortpreserve: restores original sort order on exit
```

---

## Error Handling

### capture Patterns

```stata
capture regress y x1 x2
if _rc != 0 {
    display as error "Failed with error `_rc'"
    exit _rc
}

capture noisily regress y x1 x2   // Show output, don't stop on error
```

### Validation with confirm

```stata
capture confirm variable myvar
if _rc != 0 exit 111              // variable not found

capture confirm numeric variable myvar
if _rc != 0 exit 109              // type mismatch

capture confirm file "data.dta"
if _rc != 0 exit 601              // file not found
```

### Common Error Codes

| Code | Meaning |
|------|---------|
| 100 | varlist required |
| 109 | type mismatch |
| 111 | variable not found |
| 198 | invalid syntax |
| 601 | file not found |
| 2000 | no observations |

---

## preserve and restore

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

**Key**: Parse before preserve (catch errors early). Cannot nest preserves.

**CRITICAL WARNING**: Variables created inside `preserve`/`restore` are **lost** when `restore` runs!

```stata
// WRONG - variable disappears after restore!
preserve
gen double result = x * 2
restore    // result is gone!

// CORRECT - don't use preserve when generating variables
gen double result = x * 2 if `touse'
```

**When to use preserve**: Only for estimation/reporting commands that need to temporarily modify data structure (e.g., `collapse`, `reshape`) but don't create user-visible variables.

---

## Testing

```stata
clear all
set seed 12345

sysuse auto
mycommand price mpg
assert r(N) == 74

clear
set obs 0
capture mycommand price
assert _rc != 0                           // Should error on empty data
```

**Edge cases to test**: Empty data, single obs, all missing, zero variance, invalid options.

---

## Debugging

```stata
set trace on
mycommand args
set trace off

// Options: set tracedepth 2, set traceexpand off
```

---

## CRITICAL: Package Updates

**When modifying any package, you MUST update:**

1. **Distribution-Date in .pkg** (YYYYMMDD) - How Stata detects updates
2. **Semantic version in .ado** (X.Y.Z format, never X.Y)
3. **Version in .sthlp** to match .ado
4. **Both README.md files** (package and repository root)

**Version number rules:**
- `v 3` in .pkg/.toc = file format version (NEVER change)
- `1.0.0` in .ado/.sthlp/README = semantic version (increment with changes)

---

## Distribution Checklist

- [ ] .ado: X.Y.Z version, 4-line header, block comment
- [ ] .sthlp: version matches .ado
- [ ] .pkg: `v 3`, current Distribution-Date, MIT license
- [ ] stata.toc: `v 3`
- [ ] Both READMEs: version matches .ado, single-line install, badges, `<br>` in Author
- [ ] All tests pass
- [ ] Works with `set varabbrev off`
- [ ] Dialog spacing follows rules

---

## Common Pitfalls

1. Not setting `varabbrev off`
2. Backslashes in paths (use `/` everywhere)
3. Not quoting paths with spaces
4. Wrong version format (use X.Y.Z, not X.Y)
5. Not updating Distribution-Date in .pkg
6. Changing `v 3` in .pkg or .toc (NEVER change)
7. Missing backticks in macros
8. Spaces in macro references
9. Not testing edge cases
10. Creating LICENSE files (use MIT in .pkg and README only)
11. Forgetting to update both READMEs
12. **Macro names >31 characters** (silently truncated, causes collision bugs)
13. **Using `preserve`/`restore` when generating variables** - generated vars are lost on `restore`! Only use preserve for estimation/reporting commands that don't create user-visible variables.
14. **Using `float` instead of `double`** - causes precision loss; always use `gen double`
15. **Testing only with single-observation per person data** - Bugs in row-level calculations (e.g., cumulative time) only manifest with multi-observation data; always test with multi-interval data
16. **Validating aggregates instead of row-level values** - Checking `assert abs(r(mean) - expected) < 0.01` can pass even if individual row calculations are wrong; validate each row matches expected

---

## Quick Reference

| Task | Command |
|------|---------|
| Mark sample | `marksample touse` |
| Mark option vars | `markout `touse' varname` |
| Validate variable | `confirm variable var` |
| Temp objects | `tempvar/tempfile/tempname` |
| Debug | `set trace on` |
| Test assertion | `assert condition` |
| Error handling | `capture noisily command` |
| Word count | `local n: word count `list'` |
| Parse tokens | `gettoken first rest : list` |

---

**End of Stata Coding Guide**
