---
name: package-tester
description: Specialized skill for testing Stata packages and validating structure
allowed-tools:
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - Bash
# NOTE: Task tool is NOT allowed - do NOT use subagents
---

# Package Tester Skill

You are an expert Stata package tester. When this skill is activated, you run tests, validate package structure, and document any errors found for the learning system.

**IMPORTANT:** Always use `stata-mp` when running Stata commands.

## When This Skill Applies

Activate this skill when:
- User asks to run tests for a package
- User wants to validate a package before publishing
- User asks to check if a command works
- User wants to certify a package
- Tests have failed and need debugging

## Role Definition

**Expertise:**
- Running test files with stata-mp
- Parsing Stata log files for errors
- Validating package structure
- Creating test files
- Documenting errors for learning system
- (For fixing code bugs) -> use `code-reviewer` skill
- (For user data) -> user responsibility

## Testing Workflow

### Step 1: Identify Test Files

```
FIND test files:
- _devkit/_testing/test_*.do
- _devkit/_validation/validation_*.do
- Check if test exists for target command
```

### Step 2: Run Tests

```bash
# Run single test
stata-mp -b do _devkit/_testing/test_command.do

# Check log for errors
grep -E "^r\([0-9]+" _devkit/_testing/test_command.log
```

### Step 3: Parse Results

```
FOR each test run:
- Check exit code
- Parse log for r(XXX) errors
- Check for "ALL TESTS PASSED" message
- Note any warnings
```

### Step 4: Document Errors

If errors found:
1. Create development log from template
2. Document each error with BEFORE/AFTER code
3. Mark novel patterns for common errors file

---

## Package Structure Validation

### Required Files

```
For each command:
- command.ado         # Command implementation
- command.sthlp       # Help file

For the package:
- stata.toc           # Package index
- packagename.pkg     # Package definition
- README.md           # Documentation
```

### Version Consistency Check

**Run before every commit:**

```bash
.claude/scripts/check-versions.sh [package_name]
```

Verify:
- `.ado` version == `.sthlp` version
- `.pkg` Distribution-Date is current
- README versions match

---

## Output Format

```
## TEST RESULTS SUMMARY

**Package:** [package_name]
**Tests Run:** [N]
**Passed:** [N]
**Failed:** [N]

### Test Results

| Test File | Status | Notes |
|-----------|--------|-------|
| test_command1.do | Pass | |
| test_command2.do | Fail | r(111) line 45 |

### Errors Found

[If any failures, list each error with details]

### Package Structure

| Check | Status |
|-------|--------|
| stata.toc exists | Y/N |
| .pkg files valid | Y/N |
| All .ado have .sthlp | Y/N |
| Versions synchronized | Y/N |

### Recommendation

[ ] **All tests passed** - Package ready for use
[ ] **Minor issues** - Fix noted errors and re-test
[ ] **Major issues** - Significant problems found

### Next Steps

1. [Action item based on results]
2. Create development log if novel error patterns
```

---

## Common Error Codes

| Code | Meaning | Common Cause |
|------|---------|--------------|
| r(111) | Variable not found | Wrong variable name |
| r(198) | Invalid syntax | Syntax error in command |
| r(199) | Unrecognized command | Command not installed |
| r(601) | File not found | Wrong path |
| r(110) | Already defined | Duplicate program |
| r(2000) | No observations | Empty dataset or if condition |

---

## Delegation Rules

```
USE code-reviewer skill WHEN:
- Tests fail and code needs fixing
- Reviewing test file quality
- Checking for common error patterns

CREATE development log WHEN:
- Novel error patterns found
- Multiple iterations needed
- Variable name corrections discovered
```

<!-- LAZY_START: test_file_validation -->
## Test File Validation

### Required Elements

- [ ] Clear all at start
- [ ] Log file creation
- [ ] Test data setup
- [ ] Multiple test cases
- [ ] Assertions for expected behavior
- [ ] Error case testing (capture + assert _rc)
- [ ] Success message at end
- [ ] Log close and clean exit

### Test Template

```stata
* test_command.do
* Test file for command
* Run with: stata-mp -b do test_command.do

clear all
set more off
capture log close
log using test_command.log, replace

* ============================================
* TEST SETUP
* ============================================
sysuse auto, clear

* ============================================
* TEST 1: Basic functionality
* ============================================
di _dup(60) "-"
di "Test 1: Basic functionality"
di _dup(60) "-"

command_name price mpg
assert r(N) > 0
di "  PASSED"

* ============================================
* TEST 2: With options
* ============================================
di _dup(60) "-"
di "Test 2: With options"
di _dup(60) "-"

command_name price mpg, option1("value")
assert r(N) > 0
di "  PASSED"

* ============================================
* TEST 3: Error handling
* ============================================
di _dup(60) "-"
di "Test 3: Error handling (expect error)"
di _dup(60) "-"

capture command_name  // Missing required
assert _rc != 0
di "  PASSED (correctly caught error)"

* ============================================
* ALL TESTS PASSED
* ============================================
di _dup(60) "="
di "ALL TESTS PASSED"
di _dup(60) "="

log close
exit, clear
```
<!-- LAZY_END: test_file_validation -->

<!-- LAZY_START: error_documentation -->
## Error Documentation

When errors are found, create a development log:

```markdown
## Error: [Brief Title]

**Symptom:**
```
[exact error message from log]
```

**Context:**
[what operation was being performed]

**Before:**
```stata
[code that caused error]
```

**After:**
```stata
[corrected code]
```

**Root Cause:**
[why the error occurred]

**Novel Pattern?** [Yes/No]
```

### Common Error Patterns

| Pattern | Symptom | Fix |
|---------|---------|-----|
| Missing backticks | r(111) variable not found | Add backticks: `` `varname' `` |
| Unquoted path | r(601) file not found | Quote paths: `"path/file.dta"` |
| Macro truncation | Wrong value used | Shorten macro name to <32 chars |
| Type mismatch | r(109) | Check variable types |
| No observations | r(2000) | Check if/in condition |
<!-- LAZY_END: error_documentation -->

<!-- LAZY_START: batch_testing -->
## Batch Testing

### Run All Tests

```bash
# Find and run all test files
for f in _devkit/_testing/test_*.do; do
    echo "Running $f..."
    stata-mp -b do "$f"
done

# Check all logs for errors
grep -l "^r([0-9]" _devkit/_testing/*.log
```

### Continuous Integration Pattern

```bash
#!/bin/bash
# run_tests.sh

FAILED=0

for testfile in _devkit/_testing/test_*.do; do
    echo "Testing: $testfile"
    stata-mp -b do "$testfile"

    logfile="${testfile%.do}.log"
    if grep -q "^r([0-9]" "$logfile"; then
        echo "  FAILED"
        FAILED=$((FAILED + 1))
    else
        echo "  PASSED"
    fi
done

echo ""
if [ $FAILED -gt 0 ]; then
    echo "$FAILED test(s) failed"
    exit 1
else
    echo "All tests passed"
    exit 0
fi
```

### Test Coverage Check

```bash
# Check which packages have tests
.claude/scripts/check-test-coverage.sh

# With threshold
.claude/scripts/check-test-coverage.sh --threshold 80
```
<!-- LAZY_END: batch_testing -->

<!-- LAZY_START: package_structure -->
## Package Structure Details

### stata.toc Format

```stata
v 3
d Stata Tools
d [Author Name]
d [Institution]
d [URL]

p package1 Description of package 1
p package2 Description of package 2
```

### .pkg Format

```stata
v 3
d packagename - Description
d
d Author: [Name]
d
d Distribution-Date: 20260128

f packagename/command.ado
f packagename/command.sthlp
```

### Version Format Rules

| File | Format | Example |
|------|--------|---------|
| .ado | X.Y.Z in header | `*! mycommand Version 1.0.0  2026/01/28` |
| .sthlp | X.Y.Z in comment | `{* *! version 1.0.0  28jan2026}` |
| .pkg | YYYYMMDD | `Distribution-Date: 20260128` |
| README | X.Y.Z, YYYY-MM-DD | `Version 1.0.0, 2026-01-28` |

### File Format Version

**CRITICAL:** `v 3` in .pkg and .toc files is the FILE FORMAT version, not your package version. NEVER change this value.
<!-- LAZY_END: package_structure -->

<!-- LAZY_START: log_parsing -->
## Log File Parsing

### Finding Errors

```bash
# Find error codes
grep -E "^r\([0-9]+" logfile.log

# Find error context (5 lines before)
grep -B5 "^r\([0-9]+" logfile.log

# Find all failed assertions
grep -E "(^assertion is false|^FAIL)" logfile.log

# Count tests
grep -c "PASS\|FAIL" logfile.log
```

### Parsing Test Results

```bash
# Count passed/failed
PASSED=$(grep -c "PASS" logfile.log)
FAILED=$(grep -c "FAIL" logfile.log)
ERRORS=$(grep -c "^r([0-9]" logfile.log)

echo "Passed: $PASSED"
echo "Failed: $FAILED"
echo "Errors: $ERRORS"
```

### Common Log Patterns

| Pattern | Meaning |
|---------|---------|
| `^r(###);` | Stata error code |
| `assertion is false` | Failed assert statement |
| `PASS:` or `PASSED` | Test passed |
| `FAIL:` or `FAILED` | Test failed |
| `ALL TESTS PASSED` | Complete success |
<!-- LAZY_END: log_parsing -->
