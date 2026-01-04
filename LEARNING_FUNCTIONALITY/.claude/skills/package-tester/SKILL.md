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
- ✓ Running test files with stata-mp
- ✓ Parsing Stata log files for errors
- ✓ Validating package structure
- ✓ Creating test files
- ✓ Documenting errors for learning system
- ⚠️ Fixing code bugs → use `code-reviewer` skill
- ❌ Running on user data → user responsibility

## Testing Workflow

### Step 1: Identify Test Files

```
FIND test files:
├─ tests/test_*.do
├─ **/test_*.do
└─ Check if test exists for target command
```

### Step 2: Run Tests

```bash
# Run single test
stata-mp -b do tests/test_command.do

# Check log for errors
grep -E "^r\([0-9]+" tests/test_command.log
```

### Step 3: Parse Results

```
FOR each test run:
├─ Check exit code
├─ Parse log for r(XXX) errors
├─ Check for "ALL TESTS PASSED" message
└─ Note any warnings
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
├─ command.ado         # Command implementation
├─ command.sthlp       # Help file
└─ tests/test_command.do  # Test file (recommended)

For the package:
├─ stata.toc           # Package index
├─ packagename.pkg     # Package definition
└─ README.md           # Documentation
```

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
d Distribution-Date: 20260104

f packagename/command.ado
f packagename/command.sthlp
```

---

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

---

## Error Handling

### Common Error Codes

| Code | Meaning | Common Cause |
|------|---------|--------------|
| r(111) | Variable not found | Wrong variable name |
| r(198) | Invalid syntax | Syntax error in command |
| r(199) | Unrecognized command | Command not installed |
| r(601) | File not found | Wrong path |
| r(110) | Already defined | Duplicate program |

### Error Documentation

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
| test_command1.do | ✓ Pass | |
| test_command2.do | ✗ Fail | r(111) line 45 |

### Errors Found

[If any failures, list each error with details]

#### Error 1: [test_command2.do, line 45]

**Error:** r(111) variable not found
**Code:** `gen x = wrongvar`
**Fix:** Check variable name in data

### Package Structure

| Check | Status |
|-------|--------|
| stata.toc exists | ✓/✗ |
| .pkg files valid | ✓/✗ |
| All .ado have .sthlp | ✓/✗ |
| All commands have tests | ✓/✗ |

### Recommendation

[ ] **All tests passed** - Package ready for use
[ ] **Minor issues** - Fix noted errors and re-test
[ ] **Major issues** - Significant problems found

### Next Steps

1. [Action item based on results]
2. Create development log if novel error patterns
3. Update stata-common-errors.md if needed
```

---

## Batch Testing

### Run All Tests

```bash
# Find and run all test files
for f in tests/test_*.do; do
    echo "Running $f..."
    stata-mp -b do "$f"
done

# Check all logs for errors
grep -l "^r([0-9]" tests/*.log
```

### Continuous Integration Pattern

```bash
#!/bin/bash
# run_tests.sh

FAILED=0

for testfile in tests/test_*.do; do
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

---

## Delegation Rules

```
USE code-reviewer skill WHEN:
├─ Tests fail and code needs fixing
├─ Reviewing test file quality
└─ Checking for common error patterns

CREATE development log WHEN:
├─ Novel error patterns found
├─ Multiple iterations needed
└─ Variable name corrections discovered
```
