# Guide: Testing Stata Commands

**Purpose**: How to write functional tests that verify Stata commands execute correctly without errors.

---

## Testing vs Validation

| Testing | Validation |
|---------|------------|
| Does the command **run** without errors? | Does the command produce **correct** results? |
| Are all options accepted? | Are computed values mathematically correct? |
| Do error conditions trigger proper errors? | Are invariants maintained? |
| Focus: **Execution** | Focus: **Correctness** |

This guide covers **Testing**. See the Validation Guide for mathematical correctness verification.

---

## Test File Location and Naming

All test files go in `_testing/`:

```
_testing/
├── run_all_tests.do      # Master test runner
├── run_test.do           # Single test runner with options
├── test_mycommand.do     # Test file for mycommand
├── test_anothercommand.do
└── data/                 # Test data files
```

Naming convention: `test_COMMANDNAME.do`

---

## Test File Structure

### Standard Template

```stata
/*******************************************************************************
* test_mycommand.do
*
* Purpose: Functional tests for mycommand
*          Tests that all options execute without errors.
*
* Run modes:
*   Standalone: do test_mycommand.do
*   Via runner: do run_test.do mycommand [testnumber] [quiet] [machine]
*
* Author: Your Name
* Date: 2025-01-15
*******************************************************************************/

clear all
set more off
version 16.0

* =============================================================================
* CONFIGURATION: Check for runner globals or set defaults
* =============================================================================
if "$RUN_TEST_QUIET" == "" {
    global RUN_TEST_QUIET = 0
}
if "$RUN_TEST_MACHINE" == "" {
    global RUN_TEST_MACHINE = 0
}
if "$RUN_TEST_NUMBER" == "" {
    global RUN_TEST_NUMBER = 0
}

local quiet = $RUN_TEST_QUIET
local machine = $RUN_TEST_MACHINE
local run_only = $RUN_TEST_NUMBER

* =============================================================================
* PATH CONFIGURATION
* =============================================================================
if "`c(os)'" == "MacOSX" {
    global STATA_TOOLS_PATH "/Users/tcopeland/Documents/GitHub/Stata-Tools"
}
else if "`c(os)'" == "Unix" {
    global STATA_TOOLS_PATH "/home/ubuntu/Stata-Tools"
}
else {
    * Windows or other - try current directory
    global STATA_TOOLS_PATH "`c(pwd)'"
}

global TESTING_DIR "${STATA_TOOLS_PATH}/_testing"
global DATA_DIR "${TESTING_DIR}/data"

* Create data directory if needed
capture mkdir "${DATA_DIR}"

* Install the package being tested
capture net uninstall mycommand
quietly net install mycommand, from("${STATA_TOOLS_PATH}/mycommand")

* =============================================================================
* HEADER
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "MYCOMMAND FUNCTIONAL TESTS"
    display as text "{hline 70}"
}

* =============================================================================
* TEST COUNTERS
* =============================================================================
local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

* =============================================================================
* TEST DATA SETUP
* =============================================================================
if `quiet' == 0 {
    display as text _n "Setting up test data..."
}

* Use built-in data or create test data
sysuse auto, clear

* =============================================================================
* SECTION 1: BASIC FUNCTIONALITY
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 1: Basic Functionality"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 1.1: Basic execution
* -----------------------------------------------------------------------------
local ++test_count
if `run_only' == 0 | `run_only' == 1 {
    if `quiet' == 0 {
        display as text _n "Test 1.1: Basic execution"
    }

    capture {
        sysuse auto, clear
        mycommand price mpg, required(weight)
    }
    if _rc == 0 {
        display as result "  PASS: Basic execution works"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Basic execution (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' 1.1"
    }
}

* -----------------------------------------------------------------------------
* Test 1.2: With if condition
* -----------------------------------------------------------------------------
local ++test_count
if `run_only' == 0 | `run_only' == 2 {
    if `quiet' == 0 {
        display as text _n "Test 1.2: With if condition"
    }

    capture {
        sysuse auto, clear
        mycommand price mpg if foreign == 1, required(weight)
    }
    if _rc == 0 {
        display as result "  PASS: if condition works"
        local ++pass_count
    }
    else {
        display as error "  FAIL: if condition (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' 1.2"
    }
}

* =============================================================================
* SECTION 2: OPTIONS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 2: Option Tests"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 2.1: Optional option
* -----------------------------------------------------------------------------
local ++test_count
if `run_only' == 0 | `run_only' == 3 {
    if `quiet' == 0 {
        display as text _n "Test 2.1: Optional option"
    }

    capture {
        sysuse auto, clear
        mycommand price mpg, required(weight) optional("value")
    }
    if _rc == 0 {
        display as result "  PASS: Optional option works"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Optional option (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' 2.1"
    }
}

* =============================================================================
* SECTION 3: ERROR HANDLING
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 3: Error Handling"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 3.1: Missing required option should error
* -----------------------------------------------------------------------------
local ++test_count
if `run_only' == 0 | `run_only' == 4 {
    if `quiet' == 0 {
        display as text _n "Test 3.1: Missing required option"
    }

    capture {
        sysuse auto, clear
        capture mycommand price mpg  // Missing required()
        assert _rc != 0
    }
    if _rc == 0 {
        display as result "  PASS: Missing required option produces error"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Missing required option not caught"
        local ++fail_count
        local failed_tests "`failed_tests' 3.1"
    }
}

* -----------------------------------------------------------------------------
* Test 3.2: Invalid variable should error
* -----------------------------------------------------------------------------
local ++test_count
if `run_only' == 0 | `run_only' == 5 {
    if `quiet' == 0 {
        display as text _n "Test 3.2: Invalid variable"
    }

    capture {
        sysuse auto, clear
        capture mycommand price mpg, required(nonexistent_var)
        assert _rc != 0
    }
    if _rc == 0 {
        display as result "  PASS: Invalid variable produces error"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Invalid variable not caught"
        local ++fail_count
        local failed_tests "`failed_tests' 3.2"
    }
}

* -----------------------------------------------------------------------------
* Test 3.3: Empty data should error
* -----------------------------------------------------------------------------
local ++test_count
if `run_only' == 0 | `run_only' == 6 {
    if `quiet' == 0 {
        display as text _n "Test 3.3: Empty data"
    }

    capture {
        clear
        set obs 0
        gen price = .
        gen mpg = .
        gen weight = .
        capture mycommand price mpg, required(weight)
        assert _rc == 2000  // No observations error
    }
    if _rc == 0 {
        display as result "  PASS: Empty data produces error 2000"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Empty data handling (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' 3.3"
    }
}

* =============================================================================
* SECTION 4: RETURN VALUES
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 4: Return Values"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 4.1: Returns expected scalars
* -----------------------------------------------------------------------------
local ++test_count
if `run_only' == 0 | `run_only' == 7 {
    if `quiet' == 0 {
        display as text _n "Test 4.1: Return values"
    }

    capture {
        sysuse auto, clear
        mycommand price mpg, required(weight)
        assert r(N) != .
    }
    if _rc == 0 {
        display as result "  PASS: Returns expected scalars"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Return values missing"
        local ++fail_count
        local failed_tests "`failed_tests' 4.1"
    }
}

* =============================================================================
* SUMMARY
* =============================================================================
display as text _n "{hline 70}"
display as text "MYCOMMAND TEST SUMMARY"
display as text "{hline 70}"
display as text "Total tests:  `test_count'"
display as result "Passed:       `pass_count'"
if `fail_count' > 0 {
    display as error "Failed:       `fail_count'"
}
else {
    display as text "Failed:       `fail_count'"
}
display as text "{hline 70}"

if `fail_count' > 0 {
    display as error _n "FAILED TESTS:`failed_tests'"
    display as text "{hline 70}"
    display as error "Some tests FAILED."
    exit 1
}
else {
    display as result _n "ALL TESTS PASSED!"
}

display as text _n "Testing completed: `c(current_date)' `c(current_time)'"
display as text "{hline 70}"
```

---

## Test Categories

### 1. Basic Functionality Tests

Verify the command runs in its simplest form:

```stata
* Minimal required arguments
mycommand varlist, required_option(value)

* With if/in conditions
mycommand varlist if condition, required_option(value)
mycommand varlist in 1/50, required_option(value)
```

### 2. Option Tests

Test each option individually and in combination:

```stata
* Each option alone
mycommand varlist, required(val) option1
mycommand varlist, required(val) option2(value)

* Common combinations
mycommand varlist, required(val) option1 option2(value)
```

### 3. Error Handling Tests

Verify proper error messages for invalid inputs:

```stata
* Missing required options
capture mycommand varlist
assert _rc != 0

* Invalid option values
capture mycommand varlist, required(val) option2(invalid)
assert _rc == 198

* Invalid variable names
capture mycommand varlist, required(nonexistent)
assert _rc == 111

* Empty data
clear
set obs 0
capture mycommand price, required(weight)
assert _rc == 2000
```

### 4. Return Value Tests

Verify expected values are returned:

```stata
mycommand varlist, required(val)

* Check scalars exist
assert r(N) != .
assert r(mean) != .

* Check locals exist
assert "`r(varlist)'" != ""

* Check reasonable ranges
assert r(N) > 0
assert r(N) == _N
```

### 5. Edge Case Tests

Test boundary conditions:

```stata
* Single observation
clear
set obs 1
gen x = 1
mycommand x, required(x)

* Missing values
clear
set obs 10
gen x = _n
replace x = . in 5
mycommand x, required(x)

* All missing
clear
set obs 10
gen x = .
capture mycommand x, required(x)
assert _rc == 2000
```

### 6. Data Preservation Tests

Verify original data is not modified:

```stata
sysuse auto, clear
local orig_N = _N
local orig_vars: char _dta[__varlist]

mycommand price mpg, required(weight)

* Verify data unchanged
assert _N == `orig_N'
describe, varlist
assert "`r(varlist)'" == "`orig_vars'"
```

---

## Running Tests

### Run All Tests

```stata
do _testing/run_all_tests.do
```

### Run Single Test File

```stata
do _testing/run_test.do mycommand
```

### Run Specific Test Number

```stata
do _testing/run_test.do mycommand 3  // Run only test 3
```

### Run in Quiet Mode (CI/CD)

```stata
do _testing/run_test.do mycommand 0 1  // All tests, quiet mode
```

### Run in Machine Mode (VM automation)

```stata
global RUN_TEST_QUIET = 1
global RUN_TEST_MACHINE = 1
do _testing/test_mycommand.do
```

---

## Context-Optimized Testing Workflow

When running tests repeatedly (especially during debugging), verbose output can consume significant resources. Use output modes strategically:

### Output Modes

| Mode | Usage | Output Reduction |
|------|-------|------------------|
| **verbose** (default) | Full output with separators | 0% |
| **quiet** | Only failures + summary | ~80% |
| **machine** | Parseable format for automation | ~85% |

### Recommended Workflow

#### 1. Discovery Run (First Time)

```stata
* Run in quiet mode to identify failures
do run_test.do test_mycommand . quiet
```

Output example (quiet mode):
```
[SUMMARY] 16/18 passed
[FAILED] 15 16
```

#### 2. Diagnose Single Failure

```stata
* Run only the failing test to see error details
do run_test.do test_mycommand 15
```

This shows full output for just test 15, not all 18 tests.

#### 3. Fix and Verify

```stata
* After fixing the .ado file, re-run just that test
do run_test.do test_mycommand 15 quiet

* If it passes, verify no regressions
do run_test.do test_mycommand . quiet
```

#### 4. Machine Mode (for parsing)

```stata
do run_test.do test_mycommand . machine
```

Output:
```
[OK] 1
[OK] 2
[FAIL] 15|198|option validation
[FAIL] 16|198|another option
[SUMMARY] 16/18 passed
[FAILED] 15 16
[DONE] test_mycommand FAILED|1
```

---

## Debugging Techniques

### Deep Debugging with set trace

When you can't figure out what's causing an error, use Stata's trace mode to see every line of code as it executes:

```stata
* Enable tracing
set trace on

* Run the failing command
mycommand args

* Disable tracing after diagnosing
set trace off
```

**Trace options:**
- `set trace on` - Shows every macro expansion, program call, and line execution
- `set tracedepth 2` - Limits trace depth for less verbose output
- `set traceexpand off` - Hides macro expansion details
- `set trace on, noindent` - Flat output without indentation

**When to use trace:**
- Error messages are unclear (e.g., "invalid syntax" with no details)
- `capture noisily` doesn't show enough information
- Need to see macro expansion or conditional evaluation
- Debugging complex nested program calls

### Isolating Failures

```stata
* Run just the failing test
do run_test.do test_mycommand 15

* Or manually run the failing command with trace
set trace on
sysuse auto, clear
mycommand price mpg, option(value)
set trace off
```

### Data Validation During Debugging

When a test fails, validate the data state:

```stata
* Check observations
count
describe

* Check specific variables
codebook varname
tab varname, missing

* Check for data issues
count if missing(varname)
assert stop > start
```

---

## Test Runner Globals

Tests should check for these globals:

| Global | Purpose | Values |
|--------|---------|--------|
| `$RUN_TEST_QUIET` | Suppress verbose output | 0=verbose, 1=quiet |
| `$RUN_TEST_MACHINE` | Running in automation | 0=interactive, 1=automated |
| `$RUN_TEST_NUMBER` | Run specific test | 0=all, N=test N only |

```stata
* Standard configuration block
if "$RUN_TEST_QUIET" == "" {
    global RUN_TEST_QUIET = 0
}
local quiet = $RUN_TEST_QUIET

* Use in tests
if `quiet' == 0 {
    display as text "Running test..."
}
```

---

## Best Practices

### 1. Test Independence

Each test should be independent - don't rely on state from previous tests:

```stata
* GOOD: Load fresh data each test
capture {
    sysuse auto, clear
    mycommand price mpg
}

* BAD: Assume data from previous test
capture {
    mycommand price mpg  // What data?
}
```

### 2. Clear Error Messages

Make it obvious which test failed and why:

```stata
if _rc != 0 {
    display as error "  FAIL: Test 1.1 - Basic execution"
    display as error "        Expected: successful execution"
    display as error "        Got: error code `=_rc'"
    local ++fail_count
}
```

### 3. Test Negative Cases

Verify errors occur when they should:

```stata
* Test that invalid input IS rejected
capture mycommand price, required(nonexistent)
if _rc == 0 {
    display as error "  FAIL: Should have rejected invalid variable"
}
else {
    display as result "  PASS: Invalid variable correctly rejected"
}
```

### 4. Use capture Blocks

Wrap each test in capture to prevent test failure cascade:

```stata
capture {
    // Test code that might fail
    mycommand args
    assert condition
}
if _rc == 0 {
    // Pass
}
else {
    // Fail - but continue to next test
}
```

### 5. Clean Up

Remove temporary files and restore state:

```stata
* At end of test file
capture erase "${DATA_DIR}/temp_test.dta"
clear all
```

---

## Integrating with CI/CD

### Exit Codes

Tests should exit with appropriate codes:

```stata
if `fail_count' > 0 {
    exit 1  // Signal failure to CI
}
else {
    exit 0  // Signal success
}
```

### Machine-Readable Output

In machine mode, output parseable results:

```stata
if `machine' == 1 {
    display "RESULT:PASS:`pass_count'"
    display "RESULT:FAIL:`fail_count'"
    display "RESULT:TOTAL:`test_count'"
}
```

---

## Checklist for Test Files

- [ ] File named `test_COMMANDNAME.do`
- [ ] Standard header with purpose and run modes
- [ ] Configuration block checks for runner globals
- [ ] Path configuration for MacOSX, Unix, and fallback
- [ ] Package installation at start
- [ ] Test counters initialized
- [ ] Each test wrapped in capture block
- [ ] Tests check `run_only` for selective execution
- [ ] Display statements check `quiet` mode
- [ ] PASS/FAIL messages always shown
- [ ] Summary section at end
- [ ] Exit code reflects pass/fail status

---

*Last updated: 2025-12-14*
