# .ado File Audit Prompt

Use this prompt to conduct a comprehensive audit of Stata .ado files without access to Stata runtime. The audit uses iterative checking with multiple passes until **two consecutive clean passes** are achieved.

---

## Instructions for Claude

You are auditing Stata .ado files for errors. Since you cannot run Stata, you must rely on static analysis, pattern matching, and mental execution to identify issues.

**Critical Rule**: Continue auditing until you achieve **TWO CONSECUTIVE CLEAN PASSES** with no new findings. A single clean pass is not sufficient.

### Mode of Operation

When asked to audit .ado files, you should:
1. **Report-only mode (default)**: Document findings but do not make changes. User reviews and approves fixes.
2. **Fix mode**: If explicitly authorized, apply fixes directly to files.

Ask the user which mode to use if not specified.

---

## Quick Start: Essential Checks

For rapid audits when time is limited, run these high-yield checks first:

```
QUICK AUDIT CHECKLIST
---------------------
[ ] Line 1 has version header: *! commandname Version X.Y.Z  DDmonYYYY
[ ] program define has rclass/eclass if returns are stored
[ ] version 16.0 (or higher) appears after program define
[ ] set varabbrev off appears after version
[ ] syntax [if] [in] -> marksample touse follows
[ ] marksample -> quietly count if `touse' + error check follows
[ ] Every tempvar/tempfile/tempname is declared before use
[ ] Every temp object reference uses `backticks'
[ ] Every capture has _rc check
[ ] frame create has frame drop cleanup
[ ] All local macros are referenced with `backticks'
```

If all quick checks pass, proceed to full audit. If any fail, fix before continuing.

---

## Mitigating No Stata Runtime

Since you cannot execute Stata code, use these techniques:

### 1. Pattern Matching with Grep

Use these search patterns to find common issues:

```bash
# Find macro declarations
grep -n "local " file.ado

# Then verify each macro has backtick references
grep -n "macroname" file.ado  # Should see `macroname' not plain macroname

# Find tempvar declarations without backtick references
grep -n "tempvar" file.ado
# Then search for plain variable names that should have backticks

# Find capture without _rc check
grep -n "capture" file.ado
# Then check following lines for _rc

# Find frame create without cleanup
grep -n "frame create" file.ado
grep -n "frame drop" file.ado  # Should have matching drops
```

### 2. Leverage Existing Test Files

Check `_testing/test_[commandname].do` for:
- What inputs the command expects
- Edge cases already tested
- Known working syntax patterns

### 3. Compare to Working Code

When uncertain, compare patterns to known-working .ado files in the repository.

### 4. Mental Execution Traces

Document your mental execution like this:

```
MENTAL EXECUTION TRACE
----------------------
Command: mycommand price mpg, option(value)

Step 1: syntax varlist, Option(string)
  - varlist = "price mpg"
  - option = "value"

Step 2: marksample touse
  - touse created, marks valid obs in price and mpg

Step 3: quietly count if `touse'
  - Assume 74 obs (from sysuse auto)
  - r(N) = 74, passes check

Step 4: foreach v of varlist `varlist' {
  - Iteration 1: v = "price"
  - Iteration 2: v = "mpg"

[Continue tracing...]

RESULT: Execution completes successfully
```

---

## Phase 0: Pre-Audit Setup

Before beginning the audit:

### 0.1 Required Reading

1. **Read the target .ado file(s) completely** - Never audit without reading first
2. **Read CLAUDE.md** at `/home/user/Stata-Tools/CLAUDE.md` for repository standards
3. **Read ado_error_patterns.md** at `/home/user/Stata-Tools/_testing/ado_error_patterns.md` for common errors
4. **Read related files**: .sthlp, .pkg, .dlg, README.md for the same package

### 0.2 Document Scope

Record what you're auditing:
```
AUDIT SCOPE
-----------
Package: [package_name]
Files:
  - [package_name].ado
  - [package_name].sthlp
  - [package_name].pkg
  - [package_name].dlg (if exists)
  - README.md
Date: [current_date]
```

---

## Phase 1: Structural Validation

Check the foundational structure of the .ado file.

### 1.1 Header Format

- [ ] Version comment on line 1: `*! commandname Version X.Y.Z  DDmonYYYY`
- [ ] Version uses three-part semantic versioning (X.Y.Z), NOT X.Y or X
- [ ] Author information present
- [ ] Description comment block (if complex command)

### 1.2 Program Definition

- [ ] `program define commandname, [class]` present
- [ ] Class matches return statements (rclass/eclass/sclass/nclass)
- [ ] `end` statement closes program

### 1.3 Essential Statements (must appear in order)

- [ ] `version X.0` statement (16.0 minimum for compatibility)
- [ ] `set varabbrev off` statement
- [ ] `syntax` statement with proper format

### 1.4 Sample Marking (if syntax includes [if] or [in])

- [ ] `marksample touse` after syntax
- [ ] `markout \`touse' [option_vars]` for variables in options
- [ ] Observation count check: `quietly count if \`touse'` followed by `if r(N) == 0 error 2000`

---

## Phase 2: Syntax Validation

Verify Stata syntax is correct throughout the file.

### 2.1 Macro References

For each local macro defined, verify ALL references use proper syntax:

- [ ] Opening backtick (`) and closing single quote (') present
- [ ] No spaces inside backticks: `` `varname' `` NOT `` ` varname ' ``
- [ ] Nested macros evaluated correctly (inside-out)
- [ ] Compound quotes used for strings containing quotes: `` `"string"' ``

**Method**: List all `local` declarations, then search for each macro name and verify every reference has backticks.

### 2.2 Quote Matching

- [ ] All double quotes balanced
- [ ] All compound quotes (`` `" "' ``) properly paired
- [ ] String expressions properly quoted

### 2.3 Brace Matching

- [ ] All `{` have matching `}`
- [ ] Multi-line conditionals use braces
- [ ] Loop constructs properly closed

### 2.4 Syntax Statement Validation

Parse the `syntax` statement and verify:
- [ ] Space after `syntax` keyword
- [ ] Required options have uppercase first letter
- [ ] Option types are valid (string, varname, varlist, integer, real, name, numlist, etc.)
- [ ] Optional elements in square brackets

---

## Phase 3: Logic Validation

Trace the logical flow of the program.

### 3.1 Variable Usage

For each variable referenced:
- [ ] Verify it exists (created earlier, in varlist, or validated)
- [ ] Numeric operations only on numeric variables
- [ ] String operations only on string variables

### 3.2 Temporary Objects

- [ ] All `tempvar` declarations before use
- [ ] All `tempfile` declarations before save/use
- [ ] All `tempname` declarations before matrix/scalar use
- [ ] All temp object references use backticks

### 3.3 Frame Operations (Stata 16+)

If frames are used:
- [ ] `frame create` has corresponding cleanup
- [ ] Error handling includes frame cleanup with `capture frame drop`
- [ ] frlink variables dropped when no longer needed

### 3.4 preserve/restore

- [ ] Every `preserve` has matching `restore` (or `restore, not`)
- [ ] Return statements after restore, not inside preserved section
- [ ] Values needed after restore are stored in locals

### 3.5 Error Handling

- [ ] `capture` statements followed by `_rc` check
- [ ] Error codes are standard Stata codes (see ado_error_patterns.md)
- [ ] `capture noisily` followed by `local rc = _rc` before other commands
- [ ] Appropriate error messages with `display as error`

### 3.6 Control Flow

- [ ] All `if` conditions properly formed
- [ ] Loop variables referenced with backticks inside loops
- [ ] No modification of loop variables inside loops
- [ ] Break/continue logic correct

---

## Phase 4: Best Practices Validation

Check compliance with CLAUDE.md standards.

### 4.1 Required Practices

- [ ] No variable name abbreviation
- [ ] No hardcoded paths
- [ ] Full variable names used throughout
- [ ] Clear error messages for validation failures
- [ ] Input validation before processing

### 4.2 Return Values

If rclass:
- [ ] `return scalar` for numeric values
- [ ] `return local` for string values
- [ ] `return matrix` for matrices
- [ ] All documented returns are actually stored

If eclass:
- [ ] `ereturn post` called before other ereturns
- [ ] `ereturn scalar/local/matrix` used appropriately

### 4.3 Documentation

- [ ] Complex logic has comments explaining purpose
- [ ] Option handling is clear
- [ ] No commented-out code blocks (remove or implement)

---

## Phase 5: Mental Execution (No Stata Required)

This phase compensates for lack of Stata runtime by mentally tracing execution.

### 5.1 Normal Path Execution

Trace through the program with these scenarios:
1. **Minimal valid input**: Simplest possible usage
2. **All options specified**: Every option provided
3. **Typical usage**: Common real-world usage pattern

For each scenario, trace:
- What values do macros hold at each step?
- What variables are created/modified?
- What is the expected output?

**Example Mental Execution** (using `check` command pattern):

```
SCENARIO: check price mpg, short

INPUT STATE:
- sysuse auto loaded (74 obs)
- Variables: price (numeric), mpg (numeric)

EXECUTION TRACE:

Line 12: syntax varlist(numeric), [SHORT]
  => varlist = "price mpg"
  => short = "short"

Line 15-19: quietly count / if r(N) == 0
  => r(N) = 74 (passes)

Line 36: if "`short'" == ""
  => short = "short", so condition FALSE
  => Jump to else block at line 108

Line 112-118: Compute max variable name length
  => Loop through "price", "mpg"
  => max = 5 (length of "price")

Line 143-155: Loop through varlist, display each
  => Iteration 1: v = "price", display stats
  => Iteration 2: v = "mpg", display stats

Line 161-163: Return values
  => return local varlist "price mpg"
  => return scalar nvars = 2
  => return local mode "short"

EXPECTED OUTPUT:
- Column headers displayed
- 2 rows of variable statistics
- Return values populated

POTENTIAL ISSUES CHECKED:
- [OK] varlist referenced with backticks throughout
- [OK] short option checked correctly
- [OK] Loop variable v referenced with backticks
- [OK] Return statements at end, outside any preserve block
```

### 5.2 Edge Case Execution

Mentally execute with these edge cases:

| Scenario | Expected Behavior | Verify |
|----------|-------------------|--------|
| Empty dataset (0 obs) | Error 2000 with clear message | [ ] |
| Single observation | Completes successfully | [ ] |
| All missing values | Handles gracefully or errors clearly | [ ] |
| Varlist with 1 variable | Works correctly | [ ] |
| Varlist with many variables | No overflow issues | [ ] |
| Invalid option value | Clear error message | [ ] |
| File not found (if applicable) | Error 601 with path info | [ ] |

### 5.3 Error Path Execution

For each validation/error check in the code:
- What triggers this error?
- Is the error message helpful?
- Is the error code appropriate?
- Does the program exit cleanly?

### 5.4 State Verification

At program end, verify:
- [ ] No temp variables left in dataset
- [ ] No temp files left on disk
- [ ] No frames left (except original)
- [ ] Return values are populated
- [ ] Original data state preserved (if no output)

---

## Phase 6: Cross-File Consistency

Verify consistency across all package files.

### 6.1 Version Numbers

Extract and compare version from:
- [ ] .ado file header: `*! commandname Version X.Y.Z`
- [ ] .sthlp file: `{* *! version X.Y.Z ...}`
- [ ] .pkg file: Distribution-Date updated, version in description
- [ ] README.md: Version section matches
- [ ] Main repository README.md (if package listed)

### 6.2 Syntax Consistency

- [ ] .sthlp syntax section matches .ado `syntax` statement
- [ ] All options documented in .sthlp exist in .ado
- [ ] All options in .ado documented in .sthlp
- [ ] Examples in .sthlp use valid syntax

### 6.3 Help File Examples

For each example in .sthlp:
- [ ] Dataset used exists or is created (sysuse auto, etc.)
- [ ] Variables referenced exist in dataset
- [ ] Options used are valid
- [ ] Expected output is plausible

### 6.4 Package File

- [ ] All .ado files listed in .pkg `f` lines
- [ ] All .sthlp files listed
- [ ] .dlg files listed (if exist)
- [ ] Distribution-Date is current (YYYYMMDD format)
- [ ] `v 3` is first line (format version, never changes)

### 6.5 Dialog File (if exists)

- [ ] VERSION matches .ado version requirement
- [ ] PROGRAM command section builds valid syntax
- [ ] All options in .dlg match .ado syntax
- [ ] Spacing follows +15/+20/+25 context rules

---

## Findings Documentation

Document all findings using this format:

```
================================================================================
AUDIT FINDINGS - Pass N
================================================================================

FILE: [filename]
LINE: [line_number]
SEVERITY: [CRITICAL | HIGH | MEDIUM | LOW]
CATEGORY: [Structure | Syntax | Logic | Best Practice | Consistency]
DESCRIPTION: [Clear description of the issue]
CODE: [The problematic code snippet]
FIX: [Recommended fix]

--------------------------------------------------------------------------------
```

### Severity Guidelines

| Severity | Definition | Example |
|----------|------------|---------|
| CRITICAL | Will cause runtime error | Missing backticks on macro |
| HIGH | May cause wrong results | Missing marksample |
| MEDIUM | Violates best practices | No varabbrev off |
| LOW | Style/documentation issue | Inconsistent formatting |

---

## Iteration Rules

### Pass Determination

A pass is **CLEAN** if:
- No CRITICAL findings
- No HIGH findings
- No new MEDIUM or LOW findings (existing documented ones are acceptable)

A pass is **FAILED** if:
- Any CRITICAL finding
- Any HIGH finding
- Any new MEDIUM or LOW finding

### Iteration Protocol

```
AUDIT ITERATION LOG
-------------------
Pass 1: [CLEAN/FAILED] - [N] findings
  - Applied fixes: [list fixes made]
Pass 2: [CLEAN/FAILED] - [N] findings
  - Applied fixes: [list fixes made]
...
Pass N: CLEAN - 0 new findings
Pass N+1: CLEAN - 0 new findings
AUDIT COMPLETE - Two consecutive clean passes achieved
```

### Between Passes

After a FAILED pass:
1. Document all findings
2. Apply fixes (if authorized to edit)
3. Re-read the file
4. Restart from Phase 1
5. Pay special attention to areas where fixes were made

### Audit Complete Criteria

**The audit is complete ONLY when you have achieved TWO CONSECUTIVE CLEAN PASSES.**

This ensures:
- Fixes didn't introduce new issues
- No errors were missed on first clean pass
- The file is truly ready for use

---

## Final Report Format

```
================================================================================
.ADO FILE AUDIT REPORT
================================================================================

PACKAGE: [name]
FILES AUDITED: [list]
DATE: [date]
AUDITOR: Claude

SUMMARY
-------
Total Passes: [N]
Final Status: [PASS / FAIL]
Two Consecutive Clean Passes: [YES / NO]

FINDINGS SUMMARY
----------------
CRITICAL: [N] (all resolved: [YES/NO])
HIGH: [N] (all resolved: [YES/NO])
MEDIUM: [N]
LOW: [N]

KEY ISSUES FOUND AND RESOLVED
-----------------------------
1. [Issue] - [Resolution]
2. [Issue] - [Resolution]
...

REMAINING RECOMMENDATIONS
-------------------------
(Items that are suggestions, not errors)

VERIFICATION NOTES
------------------
- Mental execution scenarios tested: [list]
- Edge cases verified: [list]
- Cross-file consistency confirmed: [YES/NO]

================================================================================
```

---

## Quick Reference: High-Priority Checks

When time is limited, prioritize these checks:

1. **Macro references** - Every local must have `` `backticks' ``
2. **marksample usage** - Required if syntax has [if] [in]
3. **Observation count** - After marksample, check r(N) != 0
4. **tempvar declarations** - Before any gen/replace using temp var
5. **Error handling** - capture followed by _rc check
6. **Frame cleanup** - frame create must have frame drop
7. **Version consistency** - ado/sthlp/pkg/README must match

---

## Comparison Against Working Examples

When uncertain about a pattern, compare against these known-working .ado files in the repository:

| File | Good Example Of |
|------|-----------------|
| `check/check.ado` | Simple rclass program, validation |
| `today/today.ado` | Option parsing, timezone handling |
| `tvtools/tvevent.ado` | Complex program, frames, tempfiles |
| `datamap/datamap.ado` | File operations, SMCL output |
| `synthdata/synthdata.ado` | Data generation, many options |

Use these as reference patterns when verifying your audit findings.

---

## Addendum: Common False Positives

Avoid flagging these as errors:

1. **Extended macro functions** - `local n: word count \`list'` is valid
2. **Display format strings** - `%10.2f` is not unbalanced quotes
3. **SMCL in strings** - `{cmd:text}` is valid in help file references
4. **Stata comments** - `*` at line start, `//` inline, `/* */` block
5. **Matrix subscripts** - `matrix[1,2]` is not unbalanced brackets

---

## Advanced Detection Techniques

### Systematic Macro Verification

For thorough macro checking, follow this process:

1. **Extract all local declarations**:
   ```
   Search pattern: ^[[:space:]]*local[[:space:]]+(\w+)
   ```

2. **For each macro name found, verify references**:
   - Count occurrences of plain name (without backticks)
   - Count occurrences with backticks (`` `name' ``)
   - Plain occurrences after declaration = potential bug

3. **Check macro scope**:
   - Macro defined inside loop but used outside?
   - Macro defined inside conditional but used unconditionally?

### Variable Lifecycle Tracking

Track each variable from creation to last use:

```
VARIABLE LIFECYCLE: _mytemp

Created:  Line 45: tempvar mytemp
          Line 46: gen `mytemp' = price * 2

Used:     Line 50: replace outcome = `mytemp' if condition
          Line 55: drop `mytemp'  <-- ERROR: tempvars auto-drop!

Status:   ERROR - Unnecessary drop of tempvar
```

### Control Flow Graph (Mental)

For complex programs, sketch the control flow:

```
START
  |
  v
[syntax parsing]
  |
  v
[validation] --error--> [exit 198]
  |
  |ok
  v
[if option1?]--yes--> [path A]
  |                      |
  |no                    |
  v                      v
[path B] <---------------+
  |
  v
[return values]
  |
  v
END
```

This helps identify:
- Unreachable code
- Missing error paths
- Variables used before definition in some paths

### Cross-Reference Verification

When checking .sthlp against .ado:

1. **Extract syntax from .ado**:
   ```stata
   syntax varlist [if] [in], Option1(string) [Option2]
   ```

2. **Convert to expected help format**:
   ```
   commandname varlist [if] [in], option1(string) [option2]
   ```

3. **Compare to .sthlp syntax section** - should match exactly

4. **Verify every option in .sthlp has handling code in .ado**

### Test File Cross-Reference

When `_testing/test_[command].do` exists:

1. Read test file to understand expected behavior
2. Verify .ado handles all tested scenarios
3. Check for edge cases in tests that reveal expected error handling
4. Use test assertions to verify your mental execution

---

## Audit Session Template

Use this template for each audit session:

```
================================================================================
AUDIT SESSION: [package_name]
================================================================================
DATE: [date]
MODE: [Report-only / Fix]
FILES: [list files]

PRE-AUDIT READING:
- [ ] CLAUDE.md reviewed
- [ ] ado_error_patterns.md reviewed
- [ ] Test file reviewed (if exists)
- [ ] All package files read

QUICK CHECKS:
- [ ] Version header (line 1)
- [ ] program define with class
- [ ] version statement
- [ ] set varabbrev off
- [ ] marksample (if applicable)
- [ ] obs count check
- [ ] temp declarations
- [ ] capture/_rc handling
- [ ] frame cleanup

PASS 1: [timestamp]
- Findings: [count]
- Details: [...]
- Fixes applied: [...]

PASS 2: [timestamp]
- Findings: [count]
- Details: [...]
- Fixes applied: [...]

[Continue until two consecutive clean passes]

PASS N: CLEAN
PASS N+1: CLEAN

AUDIT COMPLETE: [timestamp]
================================================================================
```

---

## Audit Invocation Examples

### Full Audit of Single Package

```
Please audit the tvtools/tvevent.ado file using the audit prompt in
_testing/audit_prompt.md. Use fix mode - apply corrections as needed.
```

### Quick Audit (Essential Checks Only)

```
Please run a quick audit of check/check.ado using only the Quick Start
checklist from _testing/audit_prompt.md. Report-only mode.
```

### Multi-File Package Audit

```
Please audit all files in the consort package (consort.ado, consortq.ado,
help files, pkg, README) for consistency and errors. Use fix mode.
```

### Cross-File Consistency Check

```
Please check version consistency across all .ado, .sthlp, .pkg, and README
files in the synthdata package. Report any mismatches.
```

---

**Remember**: The goal is TWO CONSECUTIVE CLEAN PASSES. Do not stop after one clean pass.

---

## Changelog

| Date | Change |
|------|--------|
| 2025-12-10 | Initial version with iterative checking |
