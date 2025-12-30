# Comprehensive Catalog of .ado File Error Patterns

**Purpose**: Reference for detecting and fixing common errors in Stata .ado files, particularly useful when auditing code without Stata runtime.

---

## Quick Detection Checklist

Use this checklist for rapid error scanning:

| Category | Pattern | Detection Method | Severity |
|----------|---------|------------------|----------|
| Macros | Missing backticks | Variable name after `local` without `` `name' `` | High |
| Macros | Unclosed quote | Count backticks ≠ single quotes | High |
| Macros | Name >31 chars | Regex: `local\s+\w{32,}` | High |
| Macros | Spaces in reference | `` ` varname ' `` pattern | High |
| Structure | No version | First 10 lines lack `version 1[678]\.0` | Medium |
| Structure | No varabbrev off | Missing after version statement | Medium |
| Structure | No marksample | Has `[if] [in]` but no `marksample` | High |
| Structure | No obs check | Has marksample but no `count if` | Medium |
| Tempvars | No declaration | Variables like `_tempvar` without `tempvar` | High |
| Tempvars | No backticks | `tempvar X` followed by plain `X` | High |
| Returns | Wrong class | `return` in eclass or `ereturn` in rclass | High |
| Errors | Unchecked capture | `capture` without subsequent `_rc` check | Medium |
| Errors | Stale _rc | Commands between `capture` and `if _rc` | High |
| Cross-file | Version mismatch | Compare .ado/.sthlp/.pkg/README versions | Medium |

---

## Category 1: Macro Errors

### 1.1 Missing Backticks

**Description**: Local macro referenced without backtick-quote delimiters.

**Example - WRONG**:
```stata
local myvar "price"
summarize myvar           // Tries to find literal variable "myvar"
```

**Example - CORRECT**:
```stata
local myvar "price"
summarize `myvar'         // Correctly expands to "price"
```

**Detection**:
```bash
# Find local definitions and check subsequent usage
grep -E 'local\s+(\w+)\s*=' file.ado
# Then search for usage without backticks
```

**Common locations**: Inside loops, after `gettoken`, in conditional expressions.

---

### 1.2 Unclosed Macro Reference

**Description**: Opening backtick without closing single quote.

**Example - WRONG**:
```stata
display "`varname"        // Missing closing '
if "`option' == "value"   // Nesting error
```

**Example - CORRECT**:
```stata
display "`varname'"
if "`option'" == "value"
```

**Detection**:
```bash
# Count backticks and single quotes per line
grep -n '`' file.ado | while read line; do
    bt=$(echo "$line" | tr -cd '`' | wc -c)
    sq=$(echo "$line" | tr -cd "'" | wc -c)
    if [ "$bt" != "$sq" ]; then echo "$line"; fi
done
```

---

### 1.3 Macro Name Exceeds 31 Characters

**Description**: Stata silently truncates macro names longer than 31 characters, causing collision bugs.

**Example - WRONG**:
```stata
// Both names truncate to "very_long_descriptive_variable_" (31 chars)
local very_long_descriptive_variable_name_one = 1
local very_long_descriptive_variable_name_two = 2
display `very_long_descriptive_variable_name_one'  // Shows 2, not 1!
```

**Example - CORRECT**:
```stata
local desc_var_name_one = 1
local desc_var_name_two = 2
```

**Detection**:
```bash
# Find macro names >= 32 characters
grep -oE 'local\s+[a-zA-Z_][a-zA-Z0-9_]{31,}' file.ado
grep -oE 'tempvar\s+[a-zA-Z_][a-zA-Z0-9_]{31,}' file.ado
grep -oE 'tempname\s+[a-zA-Z_][a-zA-Z0-9_]{31,}' file.ado
```

**Risk factors**:
- Macro names with common prefixes (e.g., `analysis_result_`, `validation_check_`)
- Auto-generated names from loops
- Concatenated names: `` local `prefix'_`suffix' ``

---

### 1.4 Spaces Inside Macro Reference

**Description**: Spaces between backtick and macro name or between name and closing quote.

**Example - WRONG**:
```stata
foreach v of varlist ` varlist ' {    // Spaces cause failure
    display "` v '"                    // Also wrong
}
```

**Example - CORRECT**:
```stata
foreach v of varlist `varlist' {
    display "`v'"
}
```

**Detection**:
```bash
grep -E '`\s+\w|`\w+\s+' file.ado
```

---

### 1.5 Nested Macro Reference Error

**Description**: Complex nested macro references evaluated incorrectly.

**Example**:
```stata
local a = 1
local b1 "test"
display "`b`a''"          // Evaluates to `b1` = "test" - correct
display "``b`a'''"        // Double evaluation - usually wrong
```

**Detection**: Manual review of patterns with multiple backticks.

---

## Category 2: Program Structure Errors

### 2.1 Missing Version Statement

**Description**: Program lacks `version 16.0` (or 18.0) statement.

**Example - WRONG**:
```stata
program define mycommand, rclass
    set varabbrev off
    syntax varlist
```

**Example - CORRECT**:
```stata
program define mycommand, rclass
    version 16.0
    set varabbrev off
    syntax varlist
```

**Detection**:
```bash
# Check first 15 lines after program define
grep -A15 'program define' file.ado | grep -q 'version 1[678]\.0' || echo "Missing version"
```

---

### 2.2 Missing varabbrev off

**Description**: Program allows variable abbreviation, which can cause silent bugs.

**Example - WRONG**:
```stata
program define mycommand, rclass
    version 16.0
    // Missing: set varabbrev off
    syntax varlist
    summarize pr   // Might match "price" or "profit" or error
```

**Example - CORRECT**:
```stata
program define mycommand, rclass
    version 16.0
    set varabbrev off
    syntax varlist
```

**Detection**:
```bash
grep -q 'set varabbrev off' file.ado || echo "Missing varabbrev off"
```

---

### 2.3 Missing marksample

**Description**: Syntax accepts `[if] [in]` but sample not marked.

**Example - WRONG**:
```stata
syntax varlist [if] [in]
// Missing marksample - if/in conditions ignored!
summarize `varlist'
```

**Example - CORRECT**:
```stata
syntax varlist [if] [in]
marksample touse
summarize `varlist' if `touse'
```

**Detection**:
```bash
if grep -q '\[if\].*\[in\]' file.ado && ! grep -q 'marksample' file.ado; then
    echo "Has [if][in] without marksample"
fi
```

---

### 2.4 Missing markout for Option Variables

**Description**: Option variables not included in sample marking.

**Example - WRONG**:
```stata
syntax varlist [if] [in], BY(varname)
marksample touse
// Missing: markout `touse' `by'
// Observations with missing `by' still included!
```

**Example - CORRECT**:
```stata
syntax varlist [if] [in], BY(varname)
marksample touse
markout `touse' `by'
```

**Detection**: Manual review - check all varname options are in markout.

---

### 2.5 Missing Observation Count Check

**Description**: marksample used but no check for empty sample.

**Example - WRONG**:
```stata
marksample touse
// No check - may fail cryptically with 0 obs
summarize `varlist' if `touse'
```

**Example - CORRECT**:
```stata
marksample touse
quietly count if `touse'
if r(N) == 0 {
    display as error "no observations"
    exit 2000
}
```

**Detection**:
```bash
if grep -q 'marksample' file.ado && ! grep -q 'count if.*touse' file.ado; then
    echo "marksample without observation count check"
fi
```

---

### 2.6 Version Line Format Error

**Description**: First line doesn't follow standard version format.

**Required format**:
```stata
*! commandname Version X.Y.Z  YYYY/MM/DD
```

**Detection**:
```bash
head -1 file.ado | grep -qE '^\*! \w+ Version [0-9]+\.[0-9]+\.[0-9]+\s+[0-9]{4}/[0-9]{2}/[0-9]{2}' || \
    echo "Invalid version line format"
```

---

## Category 3: Temporary Object Errors

### 3.1 Tempvar Without Backticks

**Description**: Tempvar declared but used without backtick quotes.

**Example - WRONG**:
```stata
tempvar mytemp
gen mytemp = price * 2    // Creates permanent variable "mytemp"!
summarize mytemp          // Uses permanent variable, not tempvar
```

**Example - CORRECT**:
```stata
tempvar mytemp
gen `mytemp' = price * 2
summarize `mytemp'
```

**Detection**:
```bash
# Extract tempvar names and check for usage without backticks
for tv in $(grep -oE 'tempvar\s+(\w+)' file.ado | awk '{print $2}'); do
    grep -E "(gen|replace|summarize|regress)\s+${tv}\b" file.ado | grep -v "\`${tv}'" && \
        echo "Tempvar $tv may be used without backticks"
done
```

---

### 3.2 Tempfile Used Before Created

**Description**: Attempting to use tempfile before saving to it.

**Example - WRONG**:
```stata
tempfile mydata
use `mydata', clear    // File doesn't exist yet!
```

**Example - CORRECT**:
```stata
tempfile mydata
save `mydata'
// ... other operations ...
use `mydata', clear
```

**Detection**: Manual review - ensure `save` precedes `use` for tempfiles.

---

### 3.3 Unnecessary Tempvar Drop

**Description**: Explicitly dropping tempvar (they're auto-dropped).

**Example - WRONG**:
```stata
tempvar mytemp
gen `mytemp' = 1
// ... use it ...
drop `mytemp'           // Unnecessary - auto-dropped at program end
```

**Example - CORRECT**:
```stata
tempvar mytemp
gen `mytemp' = 1
// ... use it ...
// No drop needed
```

**Detection**:
```bash
grep -E 'drop\s+`\w+' file.ado
```

---

## Category 4: Error Handling Errors

### 4.1 Capture Without _rc Check

**Description**: Using capture but not checking return code.

**Example - WRONG**:
```stata
capture regress y x
predict yhat              // May fail if regression failed!
```

**Example - CORRECT**:
```stata
capture regress y x
if _rc {
    display as error "Regression failed"
    exit _rc
}
predict yhat
```

**Detection**:
```bash
# Find capture not followed by _rc check within 2 lines
grep -n 'capture ' file.ado | while read line; do
    linenum=$(echo "$line" | cut -d: -f1)
    next1=$((linenum + 1))
    next2=$((linenum + 2))
    if ! sed -n "${next1}p;${next2}p" file.ado | grep -q '_rc'; then
        echo "Line $linenum: capture without _rc check"
    fi
done
```

---

### 4.2 Stale _rc Value

**Description**: _rc overwritten by intervening commands.

**Example - WRONG**:
```stata
capture noisily mycommand
display "Command finished"    // _rc now 0 from display!
if _rc {                      // Always false
    handle_error
}
```

**Example - CORRECT**:
```stata
capture noisily mycommand
local rc = _rc                // Save immediately
display "Command finished"
if `rc' {
    handle_error
}
```

**Detection**: Manual review - check for commands between capture and if _rc.

---

### 4.3 Wrong Error Code

**Description**: Using non-standard error codes.

**Standard Stata error codes**:
| Code | Meaning |
|------|---------|
| 100 | varlist required |
| 109 | type mismatch |
| 110 | variable already defined |
| 111 | variable not found |
| 198 | invalid syntax |
| 601 | file not found |
| 2000 | no observations |

**Detection**:
```bash
grep -E 'exit\s+[0-9]+' file.ado | grep -vE 'exit\s+(100|109|110|111|198|601|2000|_rc)'
```

---

## Category 5: Return Value Errors

### 5.1 Wrong Return Type for Program Class

**Description**: Using `return` in eclass program or `ereturn` in rclass.

**Example - WRONG**:
```stata
program define mycommand, rclass
    // ...
    ereturn scalar N = 100    // Wrong! rclass should use return
```

**Example - CORRECT**:
```stata
program define mycommand, rclass
    // ...
    return scalar N = 100
```

**Detection**:
```bash
# Check for ereturn in rclass
if grep -q 'rclass' file.ado && grep -q 'ereturn ' file.ado; then
    echo "rclass program using ereturn"
fi

# Check for return in eclass
if grep -q 'eclass' file.ado && grep 'return ' file.ado | grep -v 'ereturn\|restore'; then
    echo "eclass program may be using return instead of ereturn"
fi
```

---

### 5.2 Documented Returns Not Set

**Description**: Help file documents returns that program doesn't set.

**Detection**: Compare .sthlp stored results section with actual return statements in .ado.

---

## Category 6: Frame and Resource Errors

### 6.1 Frame Created Without Cleanup

**Description**: Frame created but not dropped on exit/error.

**Example - WRONG**:
```stata
frame create myframe
// ... operations ...
// Missing: frame drop myframe (leaks if error occurs)
```

**Example - CORRECT**:
```stata
tempname myframe
frame create `myframe'
// ... operations ...
frame drop `myframe'
```

**Detection**:
```bash
grep -c 'frame create' file.ado
grep -c 'frame drop' file.ado
# Numbers should match
```

---

### 6.2 File Handle Not Closed

**Description**: File opened but not closed on all paths.

**Example - WRONG**:
```stata
file open myfile using "output.txt", write
file write myfile "data"
if condition {
    error 198              // myfile not closed!
}
file close myfile
```

**Example - CORRECT**:
```stata
tempname myfile
file open `myfile' using "output.txt", write
capture {
    file write `myfile' "data"
    // ... operations ...
}
local rc = _rc
file close `myfile'
if `rc' exit `rc'
```

**Detection**:
```bash
# Check file open/close balance
grep -c 'file open' file.ado
grep -c 'file close' file.ado
```

---

## Category 7: Loop Errors

### 7.1 Loop Variable Without Backticks

**Description**: Loop iteration variable used without backticks.

**Example - WRONG**:
```stata
foreach v of varlist `varlist' {
    summarize v           // Wrong - uses literal "v"
}
```

**Example - CORRECT**:
```stata
foreach v of varlist `varlist' {
    summarize `v'
}
```

**Detection**:
```bash
# Find foreach/forvalues and check loop variable usage
grep -A10 'foreach\s+\(\w+\)' file.ado
```

---

### 7.2 Modifying Loop Variable

**Description**: Changing loop iteration variable inside loop.

**Example - WRONG**:
```stata
foreach v of varlist `varlist' {
    local v = "`v'_new"   // Modifying loop variable
}
```

**Detection**: Manual review - check for `local loopvar =` inside loops.

---

## Category 8: Cross-File Consistency Errors

### 8.1 Version Number Mismatch

**Files to compare**: .ado, .sthlp, .pkg, README.md

**Expected formats**:
| File | Format | Example |
|------|--------|---------|
| .ado (line 1) | `Version X.Y.Z  YYYY/MM/DD` | `Version 1.0.0  2025/01/15` |
| .sthlp (line 2) | `version X.Y.Z  DDmonYYYY` | `version 1.0.0  15jan2025` |
| .pkg | `Distribution-Date: YYYYMMDD` | `Distribution-Date: 20250115` |
| README.md | `Version X.Y.Z` | `Version 1.0.0` |

**Detection**:
```bash
grep -h 'version\|Version' command.ado command.sthlp command.pkg README.md
```

---

### 8.2 Syntax Documentation Mismatch

**Description**: Syntax in .sthlp doesn't match .ado syntax statement.

**Detection**: Manual comparison of `syntax` line in .ado with Syntax section in .sthlp.

---

### 8.3 Options Not Documented

**Description**: Options in syntax but not in help file.

**Detection**: Extract options from syntax, compare with synoptset entries in .sthlp.

---

### 8.4 Returns Not Documented

**Description**: Return statements in .ado not listed in .sthlp Stored results.

**Detection**:
```bash
# Extract returns from .ado
grep -E 'return (scalar|local|matrix)' command.ado

# Compare with documented returns in .sthlp
grep -E 'r\(\w+\)' command.sthlp
```

---

## Automated Validation Script

Use `.claude/hooks/validate-ado.sh` for automated checking:

```bash
.claude/hooks/validate-ado.sh mycommand.ado
```

**Checks performed**:
1. Version line format
2. Program class declaration
3. Version statement (16.0/18.0)
4. varabbrev off present
5. marksample when [if] [in] present
6. Observation count check
7. Macro name lengths (<32 chars)
8. Tempvar backtick usage
9. Capture with _rc check
10. Return type matching program class

---

## Mental Execution Trace Template

For complex issues not caught by automated checks, trace execution manually:

```
MENTAL EXECUTION TRACE
======================
File: command.ado
Command: mycommand price mpg, option(value)
Context: [describe data state]

LINE  CODE                            STATE/RESULT
----  ----                            ------------
12    syntax varlist, Option(string)  varlist="price mpg", option="value"
14    marksample touse                touse=1 for all obs
15    markout `touse' `option'        ERROR: option is string, not varname!

FINDING: Line 15 attempts markout on string option (should be varname type)
SEVERITY: High - program will error
FIX: Change option type to varname, or remove markout
```

---

## Audit Report Template

```markdown
# Audit Report: command.ado

**Date:** YYYY-MM-DD
**Version Audited:** X.Y.Z
**Auditor:** [name]

## Summary

| Category | Issues | Severity |
|----------|--------|----------|
| Macros | N | High/Medium/Low |
| Structure | N | High/Medium/Low |
| Tempvars | N | High/Medium/Low |
| Error Handling | N | High/Medium/Low |
| Cross-file | N | High/Medium/Low |

## Findings

### Finding 1: [Title]
- **Location:** line N
- **Category:** [Macro/Structure/Tempvar/Error/Cross-file]
- **Severity:** High/Medium/Low
- **Description:** ...
- **Code:** `[problematic code]`
- **Fix:** `[corrected code]`

## Verification Checklist

- [ ] All findings addressed
- [ ] Tests pass after fixes
- [ ] Version updated in all files
- [ ] Cross-file versions synchronized
```

---

*Last updated: 2025-12-30*
