/*******************************************************************************
* validation_TEMPLATE.do
*
* Purpose: Deep validation tests for TEMPLATE command using known-answer testing.
*          These tests verify computed values match expected results, not just
*          that commands execute without error.
*
* Philosophy: Create minimal datasets where every output value can be
*             mathematically verified by hand.
*
* Run modes:
*   Standalone: do validation_TEMPLATE.do
*   Via runner: do run_test.do validation_TEMPLATE [testnumber] [quiet] [machine]
*
* Prerequisites:
*   - TEMPLATE.ado must be installed/accessible
*
* Author: Your Name
* Date: YYYY-MM-DD
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
* Cross-platform path detection
if "`c(os)'" == "MacOSX" {
    global STATA_TOOLS_PATH "/Users/tcopeland/Documents/GitHub/Stata-Tools"
}
else if "`c(os)'" == "Unix" {
    global STATA_TOOLS_PATH "/home/ubuntu/Stata-Tools"
}
else {
    * Windows or other - try to detect from current directory
    capture confirm file "_validation"
    if _rc == 0 {
        * Running from repo root
        global STATA_TOOLS_PATH "`c(pwd)'"
    }
    else {
        capture confirm file "data"
        if _rc == 0 {
            * Running from _validation directory
            global STATA_TOOLS_PATH "`c(pwd)'/.."
        }
        else {
            * Assume running from _validation/data directory
            global STATA_TOOLS_PATH "`c(pwd)'/../.."
        }
    }
}

global VALIDATION_DIR "${STATA_TOOLS_PATH}/_validation"
global DATA_DIR "${VALIDATION_DIR}/data"

* Create data directory if needed
capture mkdir "${DATA_DIR}"

* Install package (adjust path as needed)
* capture net uninstall TEMPLATE
* quietly net install TEMPLATE, from("${STATA_TOOLS_PATH}/TEMPLATE")

* =============================================================================
* HEADER (skip in quiet/machine mode)
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "TEMPLATE DEEP VALIDATION TESTS"
    display as text "{hline 70}"
    display as text "These tests verify mathematical correctness, not just execution."
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
* HELPER PROGRAMS
* =============================================================================

* Program to check floating point equality with tolerance
capture program drop _assert_equal
program define _assert_equal
    args actual expected tolerance
    if "`tolerance'" == "" local tolerance = 0.0001
    local diff = abs(`actual' - `expected')
    local rel_diff = `diff' / max(abs(`expected'), 1)
    if `rel_diff' > `tolerance' {
        display as error "  Expected: `expected', Got: `actual' (diff: `diff')"
        exit 9
    }
end

* =============================================================================
* CREATE VALIDATION DATA
* =============================================================================
if `quiet' == 0 {
    display as text _n "Creating validation datasets..."
}

* Dataset 1: Simple known values
* Create a minimal dataset where all computations can be verified by hand
clear
input long id double x double y double expected_result
    1  10  2  5.0
    2  20  4  5.0
    3  30  6  5.0
    4  40  8  5.0
    5  50 10  5.0
end
label data "Simple validation data: x/y = expected_result"
save "${DATA_DIR}/valid_simple.dta", replace

* Dataset 2: Edge cases
clear
input long id double x double y
    1  0    1
    2  1    1
    3  100  100
    4  -10  2
    5  .    1
end
label data "Edge case validation data"
save "${DATA_DIR}/valid_edge.dta", replace

* Dataset 3: Known statistical properties
* Create data with known mean, variance, etc.
clear
set obs 5
gen id = _n
gen x = _n * 10  // 10, 20, 30, 40, 50 - mean = 30
gen y = 1
label data "Data with known mean = 30"
save "${DATA_DIR}/valid_stats.dta", replace

if `quiet' == 0 {
    display as result "Validation datasets created in: ${DATA_DIR}"
}

* =============================================================================
* SECTION 1: BASIC COMPUTATION VALIDATION
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 1: Basic Computation Validation"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 1.1: Simple division produces expected values
* Purpose: Verify x/y = expected_result for all rows
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 1.1: Simple Division Computation"
}

capture {
    use "${DATA_DIR}/valid_simple.dta", clear

    * Run command (adjust to your actual command)
    * TEMPLATE x, required_option(y) generate(result)

    * For this template, simulate the expected behavior
    gen result = x / y

    * Verify each row matches expected value
    forvalues i = 1/5 {
        local actual = result[`i']
        local expected = expected_result[`i']
        _assert_equal `actual' `expected' 0.0001
    }
}
if _rc == 0 {
    display as result "  PASS: All computed values match expected"
    local ++pass_count
}
else {
    display as error "  FAIL: Computation mismatch (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 1.1"
}

* -----------------------------------------------------------------------------
* Test 1.2: Output is non-negative (if applicable)
* Purpose: Verify output values have expected properties
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 1.2: Output Properties"
}

capture {
    use "${DATA_DIR}/valid_simple.dta", clear

    * Run command
    gen result = x / y

    * Verify property: all results >= 0 (for this example data)
    quietly count if result < 0
    assert r(N) == 0
}
if _rc == 0 {
    display as result "  PASS: Output has expected properties"
    local ++pass_count
}
else {
    display as error "  FAIL: Output property check (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 1.2"
}

* =============================================================================
* SECTION 2: BOUNDARY CONDITION VALIDATION
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 2: Boundary Condition Validation"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 2.1: Zero input handling
* Purpose: Verify correct behavior when input contains zero
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 2.1: Zero Input Handling"
}

capture {
    use "${DATA_DIR}/valid_edge.dta", clear

    * Test with x = 0
    keep if x == 0
    gen result = x / y

    * Expected: 0/1 = 0
    assert result[1] == 0
}
if _rc == 0 {
    display as result "  PASS: Zero input handled correctly"
    local ++pass_count
}
else {
    display as error "  FAIL: Zero input handling (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 2.1"
}

* -----------------------------------------------------------------------------
* Test 2.2: Negative input handling
* Purpose: Verify correct behavior with negative values
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 2.2: Negative Input Handling"
}

capture {
    use "${DATA_DIR}/valid_edge.dta", clear

    * Test with negative x
    keep if x == -10
    gen result = x / y

    * Expected: -10/2 = -5
    _assert_equal result[1] -5 0.0001
}
if _rc == 0 {
    display as result "  PASS: Negative input handled correctly"
    local ++pass_count
}
else {
    display as error "  FAIL: Negative input handling (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 2.2"
}

* -----------------------------------------------------------------------------
* Test 2.3: Missing value handling
* Purpose: Verify missing values propagate correctly
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 2.3: Missing Value Handling"
}

capture {
    use "${DATA_DIR}/valid_edge.dta", clear

    * Test with missing x
    keep if missing(x)
    gen result = x / y

    * Expected: ./1 = .
    assert missing(result[1])
}
if _rc == 0 {
    display as result "  PASS: Missing values handled correctly"
    local ++pass_count
}
else {
    display as error "  FAIL: Missing value handling (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 2.3"
}

* =============================================================================
* SECTION 3: STATISTICAL ACCURACY VALIDATION
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 3: Statistical Accuracy Validation"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 3.1: Aggregate statistics match expected
* Purpose: Verify summary statistics are computed correctly
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.1: Aggregate Statistics"
}

capture {
    use "${DATA_DIR}/valid_stats.dta", clear

    * Data: x = 10, 20, 30, 40, 50
    * Expected mean = 30
    * Expected sum = 150

    quietly sum x
    _assert_equal r(mean) 30 0.0001
    _assert_equal r(sum) 150 0.0001
}
if _rc == 0 {
    display as result "  PASS: Aggregate statistics match expected"
    local ++pass_count
}
else {
    display as error "  FAIL: Aggregate statistics (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.1"
}

* =============================================================================
* SECTION 4: RETURN VALUES VALIDATION
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 4: Return Values Validation"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 4.1: r(N) returns correct count
* Purpose: Verify observation count is returned correctly
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.1: r(N) Return Value"
}

capture {
    use "${DATA_DIR}/valid_simple.dta", clear

    * Run command that returns r(N)
    * TEMPLATE x, required_option(y)

    * For template, use count to simulate
    count
    local actual_N = r(N)

    * Expected: 5 observations
    assert `actual_N' == 5
}
if _rc == 0 {
    display as result "  PASS: r(N) returns correct value"
    local ++pass_count
}
else {
    display as error "  FAIL: r(N) return value (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.1"
}

* =============================================================================
* SECTION 5: INVARIANT TESTS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 5: Invariant Tests (Properties That Must Always Hold)"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 5.1: Idempotency (if applicable)
* Purpose: Running twice produces same result
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 5.1: Idempotency Check"
}

capture {
    use "${DATA_DIR}/valid_simple.dta", clear

    * Run once
    gen result1 = x / y

    * Run again on result
    gen result2 = result1

    * Results should be identical
    assert result1 == result2
}
if _rc == 0 {
    display as result "  PASS: Idempotency holds"
    local ++pass_count
}
else {
    display as error "  FAIL: Idempotency check (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 5.1"
}

* -----------------------------------------------------------------------------
* Test 5.2: Monotonicity (if applicable)
* Purpose: Larger inputs produce larger outputs
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 5.2: Monotonicity Check"
}

capture {
    use "${DATA_DIR}/valid_simple.dta", clear

    * Generate results
    gen result = x / y

    * Sort by input and check output ordering
    sort x
    gen is_monotonic = (result >= result[_n-1]) if _n > 1
    quietly count if is_monotonic == 0
    assert r(N) == 0
}
if _rc == 0 {
    display as result "  PASS: Monotonicity holds"
    local ++pass_count
}
else {
    display as error "  FAIL: Monotonicity check (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 5.2"
}

* =============================================================================
* SECTION 6: ERROR HANDLING VALIDATION
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 6: Error Handling Validation"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 6.1: Invalid input type produces appropriate error
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 6.1: Invalid Input Type Error"
}

capture {
    clear
    input str10 x double y
        "text" 1
    end

    * Attempting to run on string variable should fail
    * capture TEMPLATE x, required_option(y)
    * For template, simulate type check
    capture confirm numeric variable x
    assert _rc != 0  // Should have failed
}
if _rc == 0 {
    display as result "  PASS: Invalid input type produces error"
    local ++pass_count
}
else {
    display as error "  FAIL: Invalid input type handling (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 6.1"
}

* =============================================================================
* CLEANUP
* =============================================================================
* Remove temporary validation datasets
capture erase "${DATA_DIR}/valid_simple.dta"
capture erase "${DATA_DIR}/valid_edge.dta"
capture erase "${DATA_DIR}/valid_stats.dta"

* =============================================================================
* SUMMARY
* =============================================================================
display as text _n "{hline 70}"
display as text "TEMPLATE VALIDATION SUMMARY"
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
    display as error "Some validation tests FAILED."
    exit 1
}
else {
    display as result _n "ALL VALIDATION TESTS PASSED!"
}

display as text _n "Validation completed: `c(current_date)' `c(current_time)'"
display as text "{hline 70}"
