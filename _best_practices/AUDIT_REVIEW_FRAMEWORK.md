# Audit Review Framework for Stata Package Development

**Purpose**: Systematic framework for reviewing and validating Stata package code, dialogs, and documentation to minimize errors before implementation.

**Version**: 1.0.0
**Date**: 2025-11-18

---

## Overview

This framework provides a structured approach to double-checking all Stata package development work, with special emphasis on:
- Stata programming syntax correctness
- Dialog file standards compliance
- Help file accuracy
- Code optimization opportunities
- Error prevention strategies

---

## 1. Dialog File (.dlg) Audit Checklist

### 1.1 Structural Requirements

- [ ] **VERSION statement on line 1**
  - Must be: `VERSION 18.0` (or appropriate version)
  - Common error: VERSION not on first line

- [ ] **POSITION statement on line 2**
  - Format: `POSITION . . WIDTH HEIGHT`
  - Typical: `POSITION . . 400 250` (adjust as needed)

- [ ] **DIALOG blocks properly defined**
  - Each dialog has: `DIALOG name, label("Label") tabtitle("Title")`
  - BEGIN/END properly paired
  - No unclosed blocks

- [ ] **Standard buttons defined**
  - OK button: `OK ok1, label("OK")`
  - CANCEL button: `CANCEL can1, label("Cancel")`
  - HELP button: `HELP hlp1, view("help commandname")`
  - Submit button (if applicable): `SUBMIT sub1, label("Submit")`

- [ ] **PROGRAM command section exists**
  - Properly constructs Stata command
  - Uses `put`, `require`, conditional logic correctly

### 1.2 Spacing Standards (CRITICAL)

These standards from the Stata Development Guide must be followed consistently:

| Context | Spacing | Check |
|---------|---------|-------|
| After GROUPBOX label | +15 | First element inside groupbox |
| Between field pairs | +25 | Vertical rhythm between label/input pairs |
| Between groupboxes | +25 | Section separation |
| Label to input (same field) | +20 | Within a single field pair |
| Radio/checkbox lists | +20 | Consecutive related items |
| Side-by-side alignment | -20 | Right column aligns with left label |

**Common Spacing Errors to Check:**

```stata
# ERROR: Wrong spacing after groupbox
GROUPBOX gb_opts  10  10  620  120, label("Options")
TEXT     tx_opt1  20  +20 280  ., label("Option:")  # Should be +15!

# CORRECT:
GROUPBOX gb_opts  10  10  620  120, label("Options")
TEXT     tx_opt1  20  +15 280  ., label("Option:")

# ERROR: Inconsistent groupbox spacing
GROUPBOX gb_one   10  10  620  100, label("Section 1")
GROUPBOX gb_two   10  +30 620  100, label("Section 2")  # Should be +25!

# CORRECT:
GROUPBOX gb_one   10  10  620  100, label("Section 1")
GROUPBOX gb_two   10  +25 620  100, label("Section 2")

# ERROR: Wrong spacing in field pairs
TEXT tx_field1  20  +15 280  ., label("Field 1:")
EDIT ed_field1  @   +20 @    ., label("input")
TEXT tx_field2  20  +20 280  ., label("Field 2:")  # Should be +25!

# CORRECT:
TEXT tx_field1  20  +15 280  ., label("Field 1:")
EDIT ed_field1  @   +20 @    ., label("input")
TEXT tx_field2  20  +25 280  ., label("Field 2:")
```

### 1.3 Control Validation

- [ ] **Naming conventions followed**
  - TEXT: `tx_name`
  - EDIT: `ed_name`
  - VARNAME: `vn_name`
  - VARLIST: `vl_name`
  - CHECKBOX: `ck_name`
  - RADIO: `rb_name`
  - COMBOBOX: `cb_name`
  - GROUPBOX: `gb_name`
  - BUTTON: `bu_name`

- [ ] **Control properties correct**
  - Widths appropriate for content
  - Heights consistent (typically `.` for single-line)
  - Labels descriptive and clear
  - Default values set appropriately

- [ ] **Radio button groups properly defined**
  - First radio has `first` option
  - Last radio has `last` option
  - All in same group have same spacing

### 1.4 PROGRAM Section Validation

- [ ] **Command construction logical**
  - Base command name correct
  - Variable names properly referenced
  - Options properly conditional
  - Syntax matches ado file expectations

- [ ] **Required fields validated**
  - Uses `require fieldname` for mandatory inputs
  - Provides clear field names in error messages

- [ ] **Conditional logic correct**
  - if/else blocks properly structured
  - Boolean conditions properly evaluated
  - Nested conditions properly indented

- [ ] **String concatenation proper**
  - Spaces added where needed
  - Commas placed correctly for options
  - Quotes handled correctly for string arguments

**Example PROGRAM patterns to verify:**

```stata
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

# Conditional options
if rb_opt1 {
    put ", method(method1)"
}
else if rb_opt2 {
    put ", method(method2)"
}
```

---

## 2. Ado File (.ado) Audit Checklist

### 2.1 Header Requirements

- [ ] **Version declaration line 1**
  - Format: `*! version X.Y.Z  DDmonYYYY`
  - Example: `*! version 1.0.0  18nov2025`

- [ ] **Author information**
  - Optional but recommended: `*! Author: Name`

- [ ] **Program declaration correct**
  - Format: `program define commandname, rclass` (or eclass/sclass)
  - Class matches return type usage

### 2.2 Syntax Statement Validation

- [ ] **Version statement present**
  - Must be: `version 18.0` (or appropriate version)
  - Placed immediately after program define

- [ ] **Syntax statement correct**
  - Variable requirements match documentation
  - Options properly specified (required vs optional)
  - if/in handled if needed
  - Weight types specified if supported

**Common syntax patterns to verify:**

```stata
# Basic varlist with options
syntax varlist [if] [in] [, Option1 Option2(string)]

# Specific variable count
syntax varlist(min=2 max=2) [if] [in]

# Numeric variables only
syntax varlist(numeric) [if] [in]

# Using file
syntax using/ [, options]

# Anything (unparsed)
syntax anything [, options]
```

### 2.3 Data Handling

- [ ] **marksample used correctly**
  - `marksample touse` called after syntax
  - `touse` variable used in all data operations
  - Handles if/in/missing properly

- [ ] **Observation count checked**
  ```stata
  quietly count if `touse'
  if r(N) == 0 error 2000
  ```

- [ ] **Temporary objects properly declared**
  - `tempvar` for temporary variables
  - `tempfile` for temporary files
  - `tempname` for temporary scalars/matrices

### 2.4 Logic and Computation

- [ ] **Quiet execution where appropriate**
  - Use `quietly` for non-informational commands
  - Allow informative output for user feedback

- [ ] **Error handling implemented**
  - Input validation before computation
  - Clear error messages with appropriate codes
  - Edge cases handled (empty data, all missing, etc.)

- [ ] **Vectorization used**
  - Avoid loops when `generate` can be used
  - Use matrix operations for efficiency
  - Consider Mata for intensive computations (>10k obs)

### 2.5 Return Values

- [ ] **Return class matches program declaration**
  - rclass: uses `return scalar/local/matrix`
  - eclass: uses `ereturn post/scalar/local`
  - sclass: uses `sreturn local`

- [ ] **Documented return values provided**
  - All promised returns are set
  - Return names descriptive
  - Values properly formatted

**Example return patterns:**

```stata
# rclass
return scalar N = r(N)
return scalar mean = `mean_value'
return local varlist "`varlist'"

# eclass (after estimation)
ereturn post `b' `V', depname(`depvar') obs(`N')
ereturn scalar N = `N'
ereturn local cmd "mycommand"
```

### 2.6 Stata Syntax Verification

**Critical Stata-specific patterns to check:**

- [ ] **Local macro references**
  - Single quotes used correctly: `` `macroname' ``
  - Nested macros: ``` ``nested'' ``` (for macros containing macros)

- [ ] **String vs numeric handling**
  - String comparisons use `==` or `!=`
  - Numeric comparisons properly typed
  - Missing values handled (`.` is treated as large positive)

- [ ] **Backtick placement**
  - Opening: `` ` `` (backtick)
  - Closing: `'` (single quote)
  - No spaces between backtick/quote and macro name

- [ ] **Variable name handling**
  - Variable lists passed as local macros
  - `varlist` keyword used correctly
  - No abbreviated variable names (set varabbrev off)

- [ ] **Conditional syntax**
  ```stata
  # CORRECT:
  if `condition' {
      // code
  }
  else {
      // code
  }

  # ERROR: No spaces in macro
  if ` condition ' {  # WRONG - spaces inside backticks
  ```

- [ ] **Loop syntax**
  ```stata
  # foreach with local
  foreach var of local varlist {
      // code
  }

  # forvalues
  forvalues i = 1/10 {
      // code
  }
  ```

---

## 3. Help File (.sthlp) Audit Checklist

### 3.1 Structure Requirements

- [ ] **SMCL format correct**
  - Starts with `{smcl}`
  - Version line: `{* *! version X.Y.Z  DDmonYYYY}`

- [ ] **Required sections present**
  - Title
  - Syntax
  - Description
  - Options (if applicable)
  - Examples
  - Stored results (if applicable)
  - Author/References

### 3.2 Syntax Documentation

- [ ] **Syntax matches ado file**
  - All options documented
  - Required vs optional clear
  - if/in documented if supported
  - Weights documented if supported

- [ ] **Syntax formatting correct**
  ```smcl
  {p 8 16 2}
  {cmd:commandname} {varlist} {ifin} [{cmd:,} {it:options}]
  ```

### 3.3 Examples Validation

- [ ] **Examples are executable**
  - Use standard datasets (sysuse auto, etc.)
  - Commands shown will actually run
  - Output expectations clear

- [ ] **Examples cover main use cases**
  - Basic usage shown
  - Common options demonstrated
  - Edge cases illustrated if relevant

### 3.4 SMCL Markup Correct

- [ ] **Command formatting**: `{cmd:text}`
- [ ] **Italic (placeholders)**: `{it:text}`
- [ ] **Bold (emphasis)**: `{bf:text}`
- [ ] **Help links**: `{help commandname}`
- [ ] **Markers**: `{marker sectionname}`
- [ ] **Paragraph formatting**: `{p 8 16 2}` (left, indent, right)

---

## 4. Package-Level Checks

### 4.1 File Consistency

- [ ] **Naming consistency**
  - ado, dlg, sthlp, pkg files share base name
  - Example: `mycommand.ado`, `mycommand.dlg`, `mycommand.sthlp`, `mycommand.pkg`

- [ ] **Version consistency**
  - Same version number across all files
  - Date stamps consistent

### 4.2 Package Metadata (.pkg)

- [ ] **Package file exists**
- [ ] **Correct format**
  ```stata
  v 3
  d packagename: Brief description
  d Author: Name
  f filename.ado
  f filename.sthlp
  f filename.dlg
  ```

- [ ] **All files listed**
  - Every distributed file appears in .pkg

### 4.3 README Documentation

- [ ] **Installation instructions clear**
- [ ] **Basic usage examples provided**
- [ ] **Dependencies documented**
- [ ] **Known issues/limitations noted**

---

## 5. Testing and Validation

### 5.1 Syntax Testing

```stata
# Test basic command
clear all
sysuse auto
commandname varlist

# Test with options
commandname varlist, option1 option2(value)

# Test error handling
capture commandname  // Should error (no varlist)
assert _rc != 0

# Test return values
commandname price mpg
return list
assert r(N) == _N
```

### 5.2 Edge Case Testing

- [ ] **Empty dataset**: `clear all; set obs 0`
- [ ] **All missing**: `generate x = .`
- [ ] **Single observation**: `set obs 1`
- [ ] **Large dataset**: Performance with >100k observations
- [ ] **Variable name conflicts**: Common names (id, time, etc.)

### 5.3 Dialog Testing

- [ ] **Dialog opens**: `db commandname`
- [ ] **All controls visible**
- [ ] **Required fields validated**
- [ ] **Generated command correct**
- [ ] **Help button works**

---

## 6. Common Errors Reference

### 6.1 Dialog Spacing Errors

| Error | Impact | Fix |
|-------|--------|-----|
| Wrong groupbox start spacing | Visual inconsistency | Use +15 after groupbox |
| Inconsistent groupbox gaps | Unprofessional appearance | Use +25 between groupboxes |
| Wrong field pair spacing | Cramped/loose layout | Use +25 between pairs, +20 within |
| Side-by-side misalignment | Poor readability | Use -20 for right column alignment |

### 6.2 Ado Syntax Errors

| Error | Impact | Fix |
|-------|--------|-----|
| Missing marksample | Wrong subset processed | Add `marksample touse` after syntax |
| No observation check | Error on empty data | Add `quietly count if touse; if r(N)==0 error 2000` |
| Abbreviated variables | Breaks with varabbrev off | Use full variable names |
| Wrong return class | Return values not stored | Match program class to return type |
| Missing version | Compatibility issues | Add `version 18.0` after program define |

### 6.3 Stata-Specific Syntax Errors

| Error | Impact | Fix |
|-------|--------|-----|
| `` `var list' `` (space) | Macro expansion fails | `` `varlist' `` (no space) |
| `if condition` | Won't execute | `if `condition'` (backticks for macro) |
| `"string"` in macro | Quote handling issues | Proper quote escaping |
| Missing tempvar | Variable name collision | Use `tempvar name` before generation |

---

## 7. Review Documentation Template

For each package reviewed, create a file: `PACKAGE_AUDIT_REVIEW.md`

### Template Structure:

```markdown
# [Package Name] - Audit Review

**Package**: [packagename]
**Review Date**: YYYY-MM-DD
**Reviewer**: Claude (AI Assistant)
**Framework Version**: 1.0.0

---

## Executive Summary

- **Overall Status**: [PASS / NEEDS REVISION / FAIL]
- **Critical Issues**: [count]
- **Non-Critical Issues**: [count]
- **Recommendations**: [count]

---

## Files Reviewed

- [ ] packagename.ado
- [ ] packagename.dlg
- [ ] packagename.sthlp
- [ ] packagename.pkg
- [ ] README.md

---

## Dialog File (.dlg) Review

### Structure
- [ ] VERSION on line 1
- [ ] POSITION statement correct
- [ ] DIALOG blocks properly formed
- [ ] Buttons defined correctly
- [ ] PROGRAM section present

### Spacing Compliance
[Document any spacing issues found with line numbers]

### Issues Found
1. **[Severity]** [Line XX]: [Description]
   - Current: [code]
   - Expected: [code]
   - Impact: [description]

### Recommendations
1. [Recommendation with rationale]

---

## Ado File (.ado) Review

### Header and Structure
- [ ] Version declaration present
- [ ] Program class correct
- [ ] Version statement after program define

### Syntax Validation
- [ ] Syntax statement matches documentation
- [ ] marksample used correctly
- [ ] Temporary objects properly declared

### Logic and Computation
- [ ] Vectorization used where appropriate
- [ ] Error handling implemented
- [ ] Edge cases handled

### Return Values
- [ ] Return class matches program type
- [ ] All documented returns provided
- [ ] Return values properly formatted

### Stata Syntax Verification
[Document any Stata-specific syntax issues]

### Issues Found
1. **[Severity]** [Line XX]: [Description]

### Recommendations
1. [Recommendation with rationale]

---

## Help File (.sthlp) Review

### Structure
- [ ] SMCL format correct
- [ ] All required sections present
- [ ] Syntax matches ado file

### Examples
- [ ] Examples executable
- [ ] Main use cases covered
- [ ] Output expectations clear

### Issues Found
1. **[Severity]** [Line XX]: [Description]

---

## Testing Results

### Syntax Tests
- [ ] Basic command execution
- [ ] Options handling
- [ ] Error handling

### Edge Case Tests
- [ ] Empty dataset
- [ ] All missing values
- [ ] Single observation

### Dialog Tests
- [ ] Dialog opens correctly
- [ ] All controls functional
- [ ] Generated command correct

---

## Optimization Opportunities

1. **[Category]** [Description]
   - Current approach: [description]
   - Suggested improvement: [description]
   - Expected benefit: [description]

---

## Overall Assessment

### Strengths
1. [List positive aspects]

### Areas for Improvement
1. [List areas needing work]

### Critical Actions Required
1. [List must-fix items before deployment]

### Nice-to-Have Improvements
1. [List optional enhancements]

---

## Approval Status

- [ ] Ready for optimization implementation
- [ ] Needs minor revisions first
- [ ] Needs major revisions first
- [ ] Requires complete rewrite

**Reviewer Notes**: [Any additional context or notes]
```

---

## 8. Review Process Workflow

### Phase 1: Preparation
1. Read package README and documentation
2. Understand package purpose and features
3. Review git history for recent changes
4. Note any known issues or TODOs

### Phase 2: File-by-File Audit
1. **Dialog file** (.dlg)
   - Structure compliance
   - Spacing standards
   - PROGRAM logic
   - Control naming and properties

2. **Ado file** (.ado)
   - Header correctness
   - Syntax validation
   - Logic verification
   - Stata-specific syntax
   - Return value handling

3. **Help file** (.sthlp)
   - Structure and formatting
   - Content accuracy
   - Example validity
   - SMCL markup

4. **Package metadata** (.pkg)
   - File listing completeness
   - Version consistency

### Phase 3: Integration Testing
1. Load files in Stata
2. Run dialog: `db commandname`
3. Execute basic commands
4. Test edge cases
5. Verify return values

### Phase 4: Documentation
1. Create PACKAGE_AUDIT_REVIEW.md
2. Document all findings
3. Prioritize issues (critical, important, minor)
4. Provide specific recommendations
5. Note optimization opportunities

### Phase 5: Approval Decision
1. Assess overall readiness
2. Determine if ready for optimization
3. List prerequisites if not ready
4. Document next steps

---

## 9. Severity Classification

### CRITICAL
- Breaks functionality
- Causes data corruption
- Prevents command execution
- Security vulnerabilities

### IMPORTANT
- Violates standards significantly
- Causes confusing behavior
- Performance issues
- Poor user experience

### MINOR
- Style inconsistencies
- Documentation gaps
- Minor spacing issues
- Cosmetic problems

### ENHANCEMENT
- Optimization opportunities
- Feature suggestions
- Code improvements
- Documentation enhancements

---

## 10. Best Practices for Error-Free Implementation

### Pre-Implementation Checklist

Before implementing any optimizations:

1. **Understand the current code completely**
   - Read all files thoroughly
   - Trace execution flow
   - Identify dependencies
   - Note all edge cases

2. **Verify Stata syntax thoroughly**
   - Double-check backtick usage
   - Verify macro references
   - Confirm conditional syntax
   - Validate loop structures

3. **Plan changes systematically**
   - One file at a time
   - One section at a time
   - Test after each change
   - Document reasoning

4. **Use reference materials**
   - Stata Development Guide
   - Official Stata documentation
   - Package-specific documentation
   - Previous working examples

5. **Verify against standards**
   - Dialog spacing standards
   - Ado file patterns
   - Help file structure
   - Package conventions

### Implementation Safety Measures

1. **Test incrementally**
   - Don't batch multiple changes
   - Verify each change works
   - Keep working backup

2. **Follow established patterns**
   - Match existing code style
   - Use proven templates
   - Maintain consistency

3. **Document changes**
   - Comment complex logic
   - Update version numbers
   - Note in commit messages

4. **Validate thoroughly**
   - Run all tests
   - Check edge cases
   - Verify dialog functionality
   - Confirm help file accuracy

---

## 11. Framework Maintenance

This framework should be updated when:
- New standards are established
- Common errors are identified
- Best practices evolve
- Stata versions change

**Current Framework Status**: Active
**Next Review**: 2026-01-18
**Maintained By**: Project Lead

---

## Appendix A: Quick Reference Checklist

### 30-Second Dialog Check
- [ ] VERSION on line 1
- [ ] +15 after groupbox
- [ ] +25 between groupboxes
- [ ] +25 between field pairs
- [ ] +20 label to input
- [ ] PROGRAM section builds valid command

### 30-Second Ado Check
- [ ] *! version line 1
- [ ] version 18.0 after program define
- [ ] marksample touse after syntax
- [ ] return class matches program class
- [ ] Backticks correct on all macros

### 30-Second Help Check
- [ ] {smcl} at top
- [ ] Syntax matches ado
- [ ] Examples use sysuse datasets
- [ ] All options documented

---

**End of Audit Review Framework**

This framework should be used for every package review to ensure consistency, accuracy, and error minimization.
