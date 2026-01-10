---
name: stata-test
description: Stata Functional Testing - writing and running test files that verify commands execute without errors
allowed-tools:
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - Bash
# NOTE: Task tool is NOT allowed - do NOT use subagents
---

# Stata Functional Testing

Use this when writing or running test files (`test_*.do`) that verify commands execute without errors.

---

## Testing vs Validation

| Testing (This Skill) | Validation (Use /stata-validate) |
|---------------------|--------------------------------|
| Does the command **run** without errors? | Does it produce **correct** results? |
| Uses realistic datasets | Uses minimal hand-crafted datasets |
| Checks return codes, variable existence | Checks specific computed values |
| Location: `_testing/test_*.do` | Location: `_validation/validation_*.do` |

---

## Quick Start

### Create Test File

1. Copy template: `cp _templates/testing_TEMPLATE.do _testing/test_mycommand.do`
2. Replace all `TEMPLATE` with `mycommand`
3. Uncomment and customize the command calls

### Run Tests

```stata
* Run all tests
do _testing/run_all_tests.do

* Run single command's tests
do _testing/run_test.do mycommand

* Run specific test number only
do _testing/run_test.do mycommand 3

* Run in quiet mode (CI/CD)
do _testing/run_test.do mycommand 0 1

* Machine-parseable output
do _testing/run_test.do mycommand 0 1 1
```

---

## Test File Structure

```stata
/*******************************************************************************
* test_mycommand.do
*
* Purpose: Functional tests for mycommand
*******************************************************************************/

clear all
set more off
version 16.0

* Configuration for test runner
if "$RUN_TEST_QUIET" == "" global RUN_TEST_QUIET = 0
if "$RUN_TEST_MACHINE" == "" global RUN_TEST_MACHINE = 0
if "$RUN_TEST_NUMBER" == "" global RUN_TEST_NUMBER = 0

local quiet = $RUN_TEST_QUIET
local machine = $RUN_TEST_MACHINE
local run_only = $RUN_TEST_NUMBER

* Path configuration - CUSTOMIZE THESE PATHS FOR YOUR SYSTEM
* Option 1: Set environment variable STATA_TOOLS_PATH before running Stata
* Option 2: Modify the paths below for your system
if "`c(STATA_TOOLS_PATH)'" != "" {
    global STATA_TOOLS_PATH "`c(STATA_TOOLS_PATH)'"
}
else if "`c(os)'" == "MacOSX" {
    global STATA_TOOLS_PATH "~/Documents/GitHub/Stata-Tools"  // Customize this
}
else if "`c(os)'" == "Unix" {
    global STATA_TOOLS_PATH "~/Stata-Tools"  // Customize this
}
else {
    global STATA_TOOLS_PATH "`c(pwd)'"  // Fallback to current directory
}

* Install package
capture net uninstall mycommand
quietly net install mycommand, from("${STATA_TOOLS_PATH}/mycommand")

* Test counters
local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

* SECTION 1: Basic Functionality
* Test 1.1: Basic execution
local ++test_count
if `run_only' == 0 | `run_only' == 1 {
    capture {
        sysuse auto, clear
        mycommand price mpg, required(weight)
    }
    if _rc == 0 {
        display as result "  PASS: Basic execution"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Basic execution (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' 1.1"
    }
}

* ... more tests ...

* Summary
if `fail_count' > 0 {
    exit 1
}
```

---

## Required Test Categories

### 1. Basic Functionality
- Minimal required arguments
- With if/in conditions
- Single variable
- Multiple variables

### 2. Option Tests (One per Option)
```stata
* Test each option individually
mycommand varlist, required(val) option1
mycommand varlist, required(val) option2(value)

* Common combinations
mycommand varlist, required(val) option1 option2(value)
```

### 3. Error Handling (Expected Failures)
```stata
* Missing required option
capture mycommand varlist
assert _rc != 0

* Invalid variable
capture mycommand varlist, required(nonexistent)
assert _rc == 111

* Empty data
clear
set obs 0
gen x = .
capture mycommand x
assert _rc == 2000
```

### 4. Return Value Tests
```stata
mycommand varlist, required(val)
assert r(N) != .
assert "`r(varlist)'" != ""
```

### 5. Edge Cases
```stata
* Single observation
sysuse auto, clear
keep if _n == 1
mycommand price, required(weight)

* Missing values
replace price = . in 1/10
mycommand price, required(weight)

* All missing (should error)
replace price = .
capture mycommand price, required(weight)
assert _rc == 2000
```

### 6. Data Preservation
```stata
sysuse auto, clear
local orig_N = _N
mycommand price mpg, required(weight)
assert _N == `orig_N'
```

---

## Debugging Workflow

### 1. Discovery Run (Find Failures)
```stata
do run_test.do mycommand . quiet
* Output: [SUMMARY] 16/18 passed; [FAILED] 15 16
```

### 2. Diagnose Single Failure
```stata
do run_test.do mycommand 15
* Shows full output for test 15 only
```

### 3. Deep Debug with Trace
```stata
set trace on
sysuse auto, clear
mycommand price mpg, option(value)
set trace off
```

### 4. Fix and Verify
```stata
* After fixing, re-run single test
do run_test.do mycommand 15 quiet

* Then verify no regressions
do run_test.do mycommand . quiet
```

---

## Test Pattern Template

```stata
* -----------------------------------------------------------------------------
* Test N.M: Description
* -----------------------------------------------------------------------------
local ++test_count
if `run_only' == 0 | `run_only' == N {
    if `quiet' == 0 {
        display as text _n "Test N.M: Description"
    }

    capture {
        sysuse auto, clear
        mycommand price mpg, required(weight)
        assert r(N) > 0
    }
    if _rc == 0 {
        display as result "  PASS: Description"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Description (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' N.M"
    }
}
```

---

## Common Test Globals

| Global | Purpose | Values |
|--------|---------|--------|
| `$RUN_TEST_QUIET` | Suppress verbose output | 0=verbose, 1=quiet |
| `$RUN_TEST_MACHINE` | Machine-parseable output | 0=human, 1=machine |
| `$RUN_TEST_NUMBER` | Run specific test only | 0=all, N=test N |

---

## Checklist for Test Files

- [ ] File named `test_COMMANDNAME.do`
- [ ] Standard header with purpose and run modes
- [ ] Configuration block for runner globals
- [ ] Path configuration for MacOSX, Unix, fallback
- [ ] Package installation at start
- [ ] Test counters initialized
- [ ] Each test wrapped in `capture {}` block
- [ ] Tests check `run_only` for selective execution
- [ ] Display statements respect `quiet` mode
- [ ] PASS/FAIL messages always shown
- [ ] Summary section at end
- [ ] Exit code reflects pass/fail status
- [ ] Edge cases covered (empty, single obs, missing)

---

## Check Coverage

Run `.claude/scripts/check-test-coverage.sh` to see which packages are missing functional or validation tests.

---

## Delegation to Other Skills

```
USE stata-validate skill WHEN:
- Testing correctness of computed values
- Known-answer testing
- Verifying mathematical accuracy

USE code-reviewer skill WHEN:
- Reviewing test file quality
- Checking test coverage

USE package-tester skill WHEN:
- Running tests and parsing results
- Validating package structure
```

---

*Template location: `_templates/testing_TEMPLATE.do`*
*Full testing guide: `_guides/testing.md`*
