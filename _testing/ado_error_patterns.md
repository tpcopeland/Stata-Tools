# Common .ado File Error Patterns

This reference document catalogs common errors in Stata .ado files, their symptoms, and how to detect them through static analysis. Use this alongside `audit_prompt.md` for comprehensive code review.

---

## 1. Macro Reference Errors

### 1.1 Missing Backticks

**Pattern**: Referencing a local macro without backticks

```stata
// WRONG - missing backticks
local myvar "price"
summarize myvar           // Tries to find variable named "myvar"

// CORRECT
summarize `myvar'
```

**Detection**: Search for patterns where a variable name matches a local macro name but lacks backtick delimiters.

**Symptoms at runtime**: "variable X not found" error when X is a macro name.

---

### 1.2 Spaces Inside Backticks

**Pattern**: Space between backtick and macro name

```stata
// WRONG - spaces not allowed
local varlist "price mpg"
foreach v of varlist ` varlist ' {    // Fails - spaces around macro name

// CORRECT
foreach v of varlist `varlist' {
```

**Detection**: Regex pattern `` ` \w`` or `` \w ' `` inside code blocks.

**Symptoms at runtime**: Syntax error or unexpected behavior.

---

### 1.3 Unclosed Macro References

**Pattern**: Missing closing single quote on macro reference

```stata
// WRONG - missing closing quote
display "`varname"

// CORRECT
display "`varname'"
```

**Detection**: Count backticks and single quotes - they should match in pairs.

**Symptoms at runtime**: Syntax error or macro expansion continues past intended boundary.

---

### 1.4 Wrong Quote Type for Compound Quotes

**Pattern**: Using simple quotes when compound quotes are needed for strings containing quotes

```stata
// WRONG - fails when string contains quotes
local text "This has "quoted" word"

// CORRECT - compound quotes
local text `"This has "quoted" word"'
```

**Detection**: Look for strings that contain embedded double quotes without using compound quote syntax.

---

## 2. Program Structure Errors

### 2.1 Missing Version Statement

**Pattern**: Program lacks version declaration

```stata
// WRONG
program define mycommand, rclass
    syntax varlist

// CORRECT
program define mycommand, rclass
    version 16.0
    syntax varlist
```

**Detection**: Check that `version X.0` appears within first 5 lines after `program define`.

**Symptoms at runtime**: May work but behavior varies across Stata versions.

---

### 2.2 Missing set varabbrev off

**Pattern**: Not disabling variable abbreviation

```stata
// WRONG - abbreviation can cause wrong variable selection
program define mycommand
    version 16.0
    syntax varlist

// CORRECT
program define mycommand
    version 16.0
    set varabbrev off
    syntax varlist
```

**Detection**: Search for `set varabbrev off` after version statement.

**Symptoms at runtime**: Works but may silently select wrong variable when names are similar.

---

### 2.3 Missing marksample

**Pattern**: Not using marksample after syntax with if/in

```stata
// WRONG - if/in not properly handled
program define mycommand
    syntax varlist [if] [in]
    summarize `varlist'           // Ignores if/in!

// CORRECT
program define mycommand
    syntax varlist [if] [in]
    marksample touse
    summarize `varlist' if `touse'
```

**Detection**: If syntax contains `[if]` or `[in]`, verify `marksample` follows.

**Symptoms at runtime**: Command ignores if/in conditions.

---

### 2.4 Missing Observation Count Check

**Pattern**: Not checking for empty sample after marksample

```stata
// WRONG - will fail mysteriously with empty sample
marksample touse
summarize `varlist' if `touse'

// CORRECT
marksample touse
quietly count if `touse'
if r(N) == 0 error 2000
```

**Detection**: After `marksample`, look for `count if \`touse'` followed by error check.

**Symptoms at runtime**: Cryptic error or wrong results with empty selection.

---

### 2.5 Missing markout for Option Variables

**Pattern**: Not using markout for variables specified in options

```stata
// WRONG - option variable missing values not handled
syntax varlist [if] [in], BY(varname)
marksample touse
summarize `varlist' if `touse'    // Still includes obs with missing by()

// CORRECT
syntax varlist [if] [in], BY(varname)
marksample touse
markout `touse' `by'
```

**Detection**: If syntax has options with `varname` or `varlist` type, verify `markout` follows marksample.

---

## 3. Return Value Errors

### 3.1 Missing Return Class Declaration

**Pattern**: Storing returns without declaring program class

```stata
// WRONG - returns won't be stored
program define mycommand
    return scalar N = _N

// CORRECT
program define mycommand, rclass
    return scalar N = _N
```

**Detection**: If `return scalar/local/matrix` appears, verify `, rclass` in program definition.

---

### 3.2 Using Wrong Return Type

**Pattern**: Using return in eclass program or ereturn in rclass program

```stata
// WRONG - eclass program using return
program define mycommand, eclass
    return scalar N = _N    // Should be ereturn

// CORRECT
program define mycommand, eclass
    ereturn scalar N = _N
```

**Detection**: Match program class to return statement type.

---

### 3.3 Return Statement After preserve/restore

**Pattern**: Returning values that were computed in preserved data

```stata
// WRONG - returns will have wrong values after restore
preserve
    collapse (mean) price
    local mean_price = price[1]
restore
return scalar mean = `mean_price'    // Works

// But this is WRONG:
preserve
    collapse (mean) price
    return scalar mean = price[1]    // Value is from preserved data!
restore
```

**Detection**: Verify return statements are after restore or use locals to carry values.

---

## 4. Temporary Object Errors

### 4.1 Missing tempvar Declaration

**Pattern**: Using undeclared temporary variables

```stata
// WRONG - __temp is a regular variable, will persist
gen __temp = price * 2
drop __temp

// CORRECT
tempvar temp
gen `temp' = price * 2
// No need to drop - automatically cleaned up
```

**Detection**: Variables starting with `_` or `__` that aren't declared as tempvar.

---

### 4.2 Referencing tempvar Without Backticks

**Pattern**: Using tempvar name directly instead of macro reference

```stata
// WRONG
tempvar mytemp
gen mytemp = price * 2    // Creates variable named "mytemp", not the tempvar

// CORRECT
tempvar mytemp
gen `mytemp' = price * 2
```

**Detection**: After `tempvar X`, all references should be `` `X' ``.

---

### 4.3 tempfile Not Saved Before Use

**Pattern**: Using tempfile path before saving data to it

```stata
// WRONG
tempfile mydata
use `mydata', clear    // File doesn't exist yet!

// CORRECT
tempfile mydata
save `mydata'
// ... other operations ...
use `mydata', clear
```

**Detection**: `use \`tempfile'` must be preceded by `save \`tempfile'`.

---

## 5. Frame Errors (Stata 16+)

### 5.1 Frame Not Cleaned Up After Error

**Pattern**: Creating frames without cleanup on error

```stata
// WRONG - frame persists on error
frame create myframe
frame myframe: use data.dta
// ... error occurs ...
// myframe still exists!

// CORRECT
tempname myframe
frame create `myframe'
local rc = 0
capture noisily {
    frame `myframe': use data.dta
    // ... operations ...
}
local rc = _rc
capture frame drop `myframe'
if `rc' exit `rc'
```

**Detection**: Look for `frame create` without corresponding cleanup pattern.

---

### 5.2 frlink/frget Without Frame Cleanup

**Pattern**: Using frame links without dropping the link variable

```stata
// Frame link variable persists - may cause issues
frlink m:1 id, frame(otherframe)
frget newvar, from(otherframe)
// Link variable "otherframe" still exists
```

**Detection**: Check if frlink variables are dropped when no longer needed.

---

## 6. Loop and Control Flow Errors

### 6.1 foreach/forvalues Without Proper Macro Reference

**Pattern**: Using loop variable incorrectly inside loop

```stata
// WRONG
foreach v in price mpg weight {
    display v    // Displays literal "v"
}

// CORRECT
foreach v in price mpg weight {
    display "`v'"
}
```

**Detection**: Inside foreach/forvalues blocks, loop variable should be referenced with backticks.

---

### 6.2 Modifying Loop Variable Inside Loop

**Pattern**: Changing the loop variable within the loop body

```stata
// WRONG - undefined behavior
forvalues i = 1/10 {
    local i = `i' + 1    // Don't do this!
}
```

**Detection**: Inside forvalues block, search for assignment to loop variable.

---

### 6.3 Missing Braces in Multi-Line Conditionals

**Pattern**: Using newline after if without braces

```stata
// WRONG - only first line executes conditionally
if `x' > 0
    display "positive"
    display "really positive"    // Always executes!

// CORRECT
if `x' > 0 {
    display "positive"
    display "really positive"
}
```

**Detection**: `if` statement followed by newline without `{` - check if next non-blank line continues conditional logic.

---

## 7. String and Expression Errors

### 7.1 String Variable in Numeric Expression

**Pattern**: Using string variable where numeric expected

```stata
// WRONG - str variables can't be used in arithmetic
if `strvar' > 0 {    // Error if strvar is string

// Must convert first
destring `strvar', gen(numvar)
if numvar > 0 {
```

**Detection**: Check variable types before arithmetic operations.

---

### 7.2 Missing Escape for Special Characters

**Pattern**: Not escaping special regex characters in string functions

```stata
// WRONG - $ is regex special character
local result = regexm("`string'", "price$total")

// CORRECT
local result = regexm("`string'", "price\$total")
```

**Detection**: Look for regex functions with unescaped special characters: `$`, `^`, `[`, `]`, `.`, `*`, `+`, `?`, `{`, `}`, `|`, `(`, `)`, `\`.

---

## 8. Date and Time Errors

### 8.1 Date Variable Comparison Without Conversion

**Pattern**: Comparing date variables to strings

```stata
// WRONG
keep if mydate > "2020-01-01"    // String comparison, not date!

// CORRECT
keep if mydate > date("2020-01-01", "YMD")
// or
keep if mydate > td(01jan2020)
```

**Detection**: Date variable compared to quoted string without date() or td().

---

### 8.2 Losing Precision with Date Operations

**Pattern**: Using float for datetime operations

```stata
// WRONG - float loses precision for datetime
gen float mytime = clock(timestr, "YMDhms")

// CORRECT
gen double mytime = clock(timestr, "YMDhms")
```

**Detection**: datetime variables should be declared as `double`, not `float` or unspecified.

---

## 9. File and Path Errors

### 9.1 Backslashes in File Paths

**Pattern**: Using Windows-style backslashes

```stata
// WRONG - only works on Windows
use "C:\data\myfile.dta"

// CORRECT - works everywhere
use "C:/data/myfile.dta"
```

**Detection**: File paths containing `\` instead of `/`.

---

### 9.2 Unquoted Paths with Spaces

**Pattern**: File paths with spaces not quoted

```stata
// WRONG - fails with spaces
use C:/My Data/file.dta

// CORRECT
use "C:/My Data/file.dta"
```

**Detection**: File operations where path isn't wrapped in quotes.

---

### 9.3 confirm file Without capture

**Pattern**: Using confirm without handling potential failure

```stata
// WRONG - stops execution if file doesn't exist
confirm file "myfile.dta"

// CORRECT
capture confirm file "myfile.dta"
if _rc {
    display as error "File not found"
    exit 601
}
```

**Detection**: `confirm` statement not preceded by `capture`.

---

## 10. Error Handling Errors

### 10.1 capture Without Checking _rc

**Pattern**: Using capture but not checking result

```stata
// WRONG - error is silently ignored
capture regress y x
predict yhat    // May fail if regression failed!

// CORRECT
capture regress y x
if _rc {
    display as error "Regression failed"
    exit _rc
}
predict yhat
```

**Detection**: `capture` not followed by `if _rc` or `local rc = _rc`.

---

### 10.2 Wrong Error Code Usage

**Pattern**: Using inappropriate or made-up error codes

```stata
// WRONG - error code 1234 doesn't exist
exit 1234

// CORRECT - use standard codes
exit 198    // Invalid syntax
exit 459    // Data inconsistency
exit 601    // File not found
```

**Detection**: Verify exit codes against standard Stata error codes (see CLAUDE.md).

---

### 10.3 Not Preserving _rc After capture noisily

**Pattern**: _rc gets overwritten before it can be checked

```stata
// WRONG
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

**Detection**: After `capture noisily`, if any command runs before `_rc` check, it's suspect.

---

## 11. Syntax Statement Errors

### 11.1 Missing Space After syntax Keyword

**Pattern**: No space between syntax and first element

```stata
// WRONG
syntax varlist[if] [in]

// CORRECT
syntax varlist [if] [in]
```

**Detection**: `syntax` followed by something other than space or newline.

---

### 11.2 Required Option Not Uppercase

**Pattern**: Required option first letter not uppercase

```stata
// WRONG - option appears optional
syntax varlist, myoption(string)

// CORRECT - required options have uppercase first letter
syntax varlist, MYoption(string)
```

**Detection**: Required options should have first letter uppercase or explicit marker.

---

### 11.3 Using = in Option Definition

**Pattern**: Using = instead of () in syntax options

```stata
// WRONG
syntax varlist, n=integer

// CORRECT
syntax varlist, n(integer)
```

**Detection**: Option definitions using `=` instead of `()`.

---

## 12. Cross-File Consistency Errors

### 12.1 Version Mismatch Across Files

**Pattern**: Different versions in .ado, .sthlp, .pkg, README.md

**Detection**: Extract version from each file and compare.

---

### 12.2 Help File Examples Don't Match Syntax

**Pattern**: Examples in .sthlp use options that don't exist in .ado

**Detection**: Parse syntax from .ado, verify all options in .sthlp examples are valid.

---

### 12.3 Missing Files in .pkg

**Pattern**: Files referenced in .pkg don't exist, or files exist but aren't in .pkg

**Detection**: Compare .pkg file list against actual directory contents.

---

## Quick Reference: Error Pattern Checklist

| Category | Pattern | Detection Method |
|----------|---------|------------------|
| Macros | Missing backticks | Macro name without `` ` ' `` |
| Macros | Unclosed quotes | Count backticks vs single quotes |
| Structure | No version | Check first 5 lines after program |
| Structure | No varabbrev off | Search after version |
| Structure | No marksample | syntax has if/in but no marksample |
| Structure | No obs check | marksample without count check |
| Returns | Wrong class | return type vs program declaration |
| Tempvars | No declaration | Variables starting with `_` |
| Tempvars | No backticks | tempvar X followed by plain X |
| Frames | No cleanup | frame create without frame drop |
| Loops | Plain variable | Loop var without backticks |
| Strings | Numeric on string | Arithmetic on string var |
| Dates | String comparison | Date var compared to string |
| Paths | Backslashes | `\` in file paths |
| Errors | Unchecked capture | capture without _rc check |
| Syntax | Missing space | syntax followed by non-space |
| Cross-file | Version mismatch | Compare ado/sthlp/pkg/README |

---

## Using This Reference

When auditing .ado files:

1. **Use as checklist**: Go through each pattern category systematically
2. **Search for patterns**: Use the detection methods to find potential issues
3. **Verify context**: Not every match is an error - verify the context
4. **Document findings**: Record line numbers and specific issues found
5. **Cross-reference CLAUDE.md**: For complete best practices

This document complements `audit_prompt.md` which provides the iterative audit workflow.
