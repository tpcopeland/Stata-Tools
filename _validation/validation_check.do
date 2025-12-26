/*******************************************************************************
* validation_check.do
*
* Purpose: Deep validation tests for check command using known-answer testing
*          These tests verify summary statistics are calculated correctly.
*
* Philosophy: Create minimal datasets where every statistic can be
*             mathematically verified by hand.
*
* Run modes:
*   Standalone: do validation_check.do
*   Via runner: do run_test.do validation_check [testnumber] [quiet] [machine]
*
* Author: Auto-generated from validation plan
* Date: 2025-12-13
*******************************************************************************/

clear all
set more off
version 16.0

* =============================================================================
* CONFIGURATION
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
    * Try to detect path from current working directory
    capture confirm file "_validation"
    if _rc == 0 {
        global STATA_TOOLS_PATH "`c(pwd)'"
    }
    else {
        capture confirm file "_testing"
        if _rc == 0 {
            global STATA_TOOLS_PATH "`c(pwd)'"
        }
        else {
            global STATA_TOOLS_PATH "/home/`c(username)'/Stata-Tools"
        }
    }
}
else {
    capture confirm file "_validation"
    if _rc == 0 {
        global STATA_TOOLS_PATH "`c(pwd)'"
    }
    else {
        capture confirm file "data"
        if _rc == 0 {
            global STATA_TOOLS_PATH "`c(pwd)'/.."
        }
        else {
            global STATA_TOOLS_PATH "`c(pwd)'/../.."
        }
    }
}

global VALIDATION_DIR "${STATA_TOOLS_PATH}/_validation"
global DATA_DIR "${VALIDATION_DIR}/data"

capture mkdir "${DATA_DIR}"

* Install check and dependencies
capture net uninstall check
quietly net install check, from("${STATA_TOOLS_PATH}/check")
capture quietly ssc install mdesc
capture quietly ssc install unique

* =============================================================================
* HEADER
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "CHECK DEEP VALIDATION TESTS"
    display as text "{hline 70}"
    display as text "These tests verify statistics calculations are correct."
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
* CREATE VALIDATION DATASETS
* =============================================================================
if `quiet' == 0 {
    display as text _n "Creating validation datasets..."
}

* Dataset: Simple known values
* x = 1, 2, 3, 4, 5
* Mean = 3, Variance = 2.5, SD = 1.581, Min = 1, Max = 5
clear
input double x
    1
    2
    3
    4
    5
end
label data "Simple 1-5 sequence for statistics validation"
save "${DATA_DIR}/check_simple.dta", replace

* Dataset: With missing values
* y = 1, 2, ., 4, 5 (3 is missing)
* Mean of non-missing = 3, N non-missing = 4
clear
input double y
    1
    2
    .
    4
    5
end
label data "Data with one missing value"
save "${DATA_DIR}/check_missing.dta", replace

* Dataset: Unique values test
* z has 3 unique values: 1, 1, 2, 2, 3
clear
input double z
    1
    1
    2
    2
    3
end
label data "Data with 3 unique values"
save "${DATA_DIR}/check_unique.dta", replace

if `quiet' == 0 {
    display as result "Validation datasets created in: ${DATA_DIR}"
}

* =============================================================================
* SECTION 1: OBSERVATION COUNT TESTS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 1: Observation Count Tests"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 1.1: Correct Observation Count
* Purpose: Verify N is reported correctly
* Known answer: 5 observations
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 1.1: Observation Count"
}

capture {
    use "${DATA_DIR}/check_simple.dta", clear
    check x
    assert r(N) == 5
}
if _rc == 0 {
    display as result "  PASS: Observation count correct (5)"
    local ++pass_count
}
else {
    display as error "  FAIL: Observation count (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 1.1"
}

* =============================================================================
* SECTION 2: CENTRAL TENDENCY TESTS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 2: Central Tendency Tests"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 2.1: Mean Calculation
* Purpose: Verify mean is calculated correctly
* Known answer: mean of 1,2,3,4,5 = 15/5 = 3.0
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 2.1: Mean Calculation"
}

capture {
    use "${DATA_DIR}/check_simple.dta", clear
    check x
    assert abs(r(mean) - 3.0) < 0.001
}
if _rc == 0 {
    display as result "  PASS: Mean calculation correct (3.0)"
    local ++pass_count
}
else {
    display as error "  FAIL: Mean calculation (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 2.1"
}

* -----------------------------------------------------------------------------
* Test 2.2: Median Calculation
* Purpose: Verify median is calculated correctly
* Known answer: median of 1,2,3,4,5 = 3.0
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 2.2: Median Calculation"
}

capture {
    use "${DATA_DIR}/check_simple.dta", clear
    check x
    assert abs(r(p50) - 3.0) < 0.001
}
if _rc == 0 {
    display as result "  PASS: Median calculation correct (3.0)"
    local ++pass_count
}
else {
    display as error "  FAIL: Median calculation (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 2.2"
}

* =============================================================================
* SECTION 3: DISPERSION TESTS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 3: Dispersion Tests"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 3.1: Standard Deviation Calculation
* Purpose: Verify SD is calculated correctly
* Known answer: SD of 1,2,3,4,5 = sqrt(2.5) ≈ 1.581
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.1: Standard Deviation"
}

capture {
    use "${DATA_DIR}/check_simple.dta", clear
    check x

    * Expected SD = sqrt(10/4) = sqrt(2.5) ≈ 1.5811
    local expected_sd = sqrt(2.5)
    assert abs(r(sd) - `expected_sd') < 0.01
}
if _rc == 0 {
    display as result "  PASS: SD calculation correct (~1.581)"
    local ++pass_count
}
else {
    display as error "  FAIL: SD calculation (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.1"
}

* =============================================================================
* SECTION 4: RANGE TESTS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 4: Range Tests"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 4.1: Minimum Value
* Purpose: Verify min is calculated correctly
* Known answer: min of 1,2,3,4,5 = 1
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.1: Minimum Value"
}

capture {
    use "${DATA_DIR}/check_simple.dta", clear
    check x
    assert r(min) == 1
}
if _rc == 0 {
    display as result "  PASS: Minimum correct (1)"
    local ++pass_count
}
else {
    display as error "  FAIL: Minimum (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.1"
}

* -----------------------------------------------------------------------------
* Test 4.2: Maximum Value
* Purpose: Verify max is calculated correctly
* Known answer: max of 1,2,3,4,5 = 5
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.2: Maximum Value"
}

capture {
    use "${DATA_DIR}/check_simple.dta", clear
    check x
    assert r(max) == 5
}
if _rc == 0 {
    display as result "  PASS: Maximum correct (5)"
    local ++pass_count
}
else {
    display as error "  FAIL: Maximum (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.2"
}

* =============================================================================
* SECTION 5: PERCENTILE TESTS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 5: Percentile Tests"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 5.1: 25th Percentile
* Purpose: Verify p25 is calculated correctly
* Known answer: p25 of 1,2,3,4,5 = 2 (or interpolated)
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 5.1: 25th Percentile"
}

capture {
    use "${DATA_DIR}/check_simple.dta", clear
    check x

    * p25 should be around 2 (exact value depends on interpolation method)
    assert r(p25) >= 1.5 & r(p25) <= 2.5
}
if _rc == 0 {
    display as result "  PASS: p25 in expected range"
    local ++pass_count
}
else {
    display as error "  FAIL: p25 (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 5.1"
}

* -----------------------------------------------------------------------------
* Test 5.2: 75th Percentile
* Purpose: Verify p75 is calculated correctly
* Known answer: p75 of 1,2,3,4,5 = 4 (or interpolated)
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 5.2: 75th Percentile"
}

capture {
    use "${DATA_DIR}/check_simple.dta", clear
    check x

    * p75 should be around 4 (exact value depends on interpolation method)
    assert r(p75) >= 3.5 & r(p75) <= 4.5
}
if _rc == 0 {
    display as result "  PASS: p75 in expected range"
    local ++pass_count
}
else {
    display as error "  FAIL: p75 (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 5.2"
}

* =============================================================================
* SECTION 6: MISSING VALUE TESTS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 6: Missing Value Tests"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 6.1: Missing Count
* Purpose: Verify missing count is correct
* Known answer: 1 missing value
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 6.1: Missing Value Count"
}

capture {
    use "${DATA_DIR}/check_missing.dta", clear
    check y
    assert r(nmissing) == 1
}
if _rc == 0 {
    display as result "  PASS: Missing count correct (1)"
    local ++pass_count
}
else {
    display as error "  FAIL: Missing count (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 6.1"
}

* -----------------------------------------------------------------------------
* Test 6.2: Mean with Missing Values
* Purpose: Verify mean excludes missing values
* Known answer: mean of 1,2,4,5 = 12/4 = 3.0
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 6.2: Mean Excludes Missing"
}

capture {
    use "${DATA_DIR}/check_missing.dta", clear
    check y
    assert abs(r(mean) - 3.0) < 0.001
}
if _rc == 0 {
    display as result "  PASS: Mean correctly excludes missing (3.0)"
    local ++pass_count
}
else {
    display as error "  FAIL: Mean with missing (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 6.2"
}

* =============================================================================
* SECTION 7: UNIQUE VALUE TESTS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 7: Unique Value Tests"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 7.1: Unique Value Count
* Purpose: Verify unique count is correct
* Known answer: 3 unique values (1, 2, 3)
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 7.1: Unique Value Count"
}

capture {
    use "${DATA_DIR}/check_unique.dta", clear
    check z
    assert r(unique) == 3
}
if _rc == 0 {
    display as result "  PASS: Unique count correct (3)"
    local ++pass_count
}
else {
    display as error "  FAIL: Unique count (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 7.1"
}

* =============================================================================
* ERROR HANDLING TESTS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "ERROR HANDLING TESTS"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test: Empty Data Error
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test: Empty Data Error"
}

capture {
    clear
    set obs 0
    gen x = .
    capture check x
    assert _rc == 2000
}
if _rc == 0 {
    display as result "  PASS: Empty data produces error"
    local ++pass_count
}
else {
    display as error "  FAIL: Empty data handling (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' ErrEmpty"
}

* =============================================================================
* INVARIANT TESTS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "INVARIANT TESTS: Universal Properties"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Invariant 1: Min <= Mean <= Max
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Invariant 1: Min <= Mean <= Max"
}

capture {
    use "${DATA_DIR}/check_simple.dta", clear
    check x
    assert r(min) <= r(mean)
    assert r(mean) <= r(max)
}
if _rc == 0 {
    display as result "  PASS: Min <= Mean <= Max"
    local ++pass_count
}
else {
    display as error "  FAIL: Ordering invariant"
    local ++fail_count
    local failed_tests "`failed_tests' Inv1"
}

* -----------------------------------------------------------------------------
* Invariant 2: SD >= 0
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Invariant 2: SD >= 0"
}

capture {
    use "${DATA_DIR}/check_simple.dta", clear
    check x
    assert r(sd) >= 0
}
if _rc == 0 {
    display as result "  PASS: SD is non-negative"
    local ++pass_count
}
else {
    display as error "  FAIL: SD non-negative invariant"
    local ++fail_count
    local failed_tests "`failed_tests' Inv2"
}

* -----------------------------------------------------------------------------
* Invariant 3: N = N_nonmissing + N_missing
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Invariant 3: N = N_nonmissing + N_missing"
}

capture {
    use "${DATA_DIR}/check_missing.dta", clear
    local total_obs = _N
    check y

    * N (non-missing) + missing should equal total obs
    assert r(N) + r(nmissing) == `total_obs'
}
if _rc == 0 {
    display as result "  PASS: N + missing = total observations"
    local ++pass_count
}
else {
    display as error "  FAIL: Observation count invariant"
    local ++fail_count
    local failed_tests "`failed_tests' Inv3"
}

* =============================================================================
* SUMMARY
* =============================================================================
display as text _n "{hline 70}"
display as text "CHECK VALIDATION SUMMARY"
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
