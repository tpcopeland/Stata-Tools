/*******************************************************************************
* test_balancetab.do
*
* Purpose: Functional tests for balancetab command - verifies the command runs
*          without errors across various scenarios and options.
*
* Prerequisites:
*   - balancetab.ado must be installed/accessible
*
* Run modes:
*   Standalone: do test_balancetab.do
*   Via runner: do run_test.do test_balancetab [testnumber] [quiet] [machine]
*
* Author: Claude (automated testing)
* Date: 2025-12-21
*******************************************************************************/

clear all
set more off
version 16.0

* =============================================================================
* CONFIGURATION
* =============================================================================
if "$RUN_TEST_QUIET" == "" global RUN_TEST_QUIET = 0
if "$RUN_TEST_MACHINE" == "" global RUN_TEST_MACHINE = 0
if "$RUN_TEST_NUMBER" == "" global RUN_TEST_NUMBER = 0

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
    global STATA_TOOLS_PATH "`c(pwd)'"
}

global TESTING_DIR "${STATA_TOOLS_PATH}/_testing"
global DATA_DIR "${TESTING_DIR}/data"
global FIGURES_DIR "${TESTING_DIR}/figures/balancetab"

capture mkdir "${DATA_DIR}"
capture mkdir "${TESTING_DIR}/figures"
capture mkdir "${FIGURES_DIR}"

* Install package
capture net uninstall balancetab
quietly net install balancetab, from("${STATA_TOOLS_PATH}/balancetab")

* =============================================================================
* HEADER
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "BALANCETAB FUNCTIONAL TESTING"
    display as text "{hline 70}"
}

* =============================================================================
* TEST COUNTERS
* =============================================================================
local test_count = 0
local pass_count = 0
local fail_count = 0
local skip_count = 0
local failed_tests ""

* =============================================================================
* SECTION 1: BASIC FUNCTIONALITY TESTS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 1: Basic Functionality Tests"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 1: Basic execution with sysuse auto data
* -----------------------------------------------------------------------------
local ++test_count
local test_desc "Basic execution - unadjusted SMD"

if `run_only' == 0 | `run_only' == `test_count' {
    if `quiet' == 0 display as text _n "Test `test_count': `test_desc'"

    capture {
        sysuse auto, clear
        balancetab price mpg weight, treatment(foreign)
        assert r(N) > 0
        assert r(N_treated) > 0
        assert r(N_control) > 0
    }
    if _rc == 0 {
        local ++pass_count
        if `quiet' == 0 display as result "  PASSED"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `quiet' == 0 display as error "  FAILED (error `=_rc')"
    }
}

* -----------------------------------------------------------------------------
* Test 2: With IPTW weights
* -----------------------------------------------------------------------------
local ++test_count
local test_desc "With IPTW weights"

if `run_only' == 0 | `run_only' == `test_count' {
    if `quiet' == 0 display as text _n "Test `test_count': `test_desc'"

    capture {
        sysuse auto, clear
        * Create simple propensity score and weights
        logit foreign price mpg
        predict ps, pr
        gen ipw = cond(foreign==1, 1/ps, 1/(1-ps))

        balancetab price mpg, treatment(foreign) wvar(ipw)
        assert r(N) > 0
        assert r(max_smd_raw) != .
        assert r(max_smd_adj) != .
    }
    if _rc == 0 {
        local ++pass_count
        if `quiet' == 0 display as result "  PASSED"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `quiet' == 0 display as error "  FAILED (error `=_rc')"
    }
}

* -----------------------------------------------------------------------------
* Test 3: With matched option
* -----------------------------------------------------------------------------
local ++test_count
local test_desc "With matched option"

if `run_only' == 0 | `run_only' == `test_count' {
    if `quiet' == 0 display as text _n "Test `test_count': `test_desc'"

    capture {
        sysuse auto, clear
        balancetab price mpg weight, treatment(foreign) matched
        assert r(N) > 0
        assert r(max_smd_adj) != .
    }
    if _rc == 0 {
        local ++pass_count
        if `quiet' == 0 display as result "  PASSED"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `quiet' == 0 display as error "  FAILED (error `=_rc')"
    }
}

* -----------------------------------------------------------------------------
* Test 4: Custom threshold
* -----------------------------------------------------------------------------
local ++test_count
local test_desc "Custom threshold option"

if `run_only' == 0 | `run_only' == `test_count' {
    if `quiet' == 0 display as text _n "Test `test_count': `test_desc'"

    capture {
        sysuse auto, clear
        balancetab price mpg, treatment(foreign) threshold(0.2)
        assert r(threshold) == 0.2
    }
    if _rc == 0 {
        local ++pass_count
        if `quiet' == 0 display as result "  PASSED"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `quiet' == 0 display as error "  FAILED (error `=_rc')"
    }
}

* -----------------------------------------------------------------------------
* Test 5: Custom title option
* -----------------------------------------------------------------------------
local ++test_count
local test_desc "Custom title option"

if `run_only' == 0 | `run_only' == `test_count' {
    if `quiet' == 0 display as text _n "Test `test_count': `test_desc'"

    capture {
        sysuse auto, clear
        balancetab price mpg, treatment(foreign) title("My Custom Title")
        assert r(N) > 0
    }
    if _rc == 0 {
        local ++pass_count
        if `quiet' == 0 display as result "  PASSED"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `quiet' == 0 display as error "  FAILED (error `=_rc')"
    }
}

* -----------------------------------------------------------------------------
* Test 6: Custom format option
* -----------------------------------------------------------------------------
local ++test_count
local test_desc "Custom format option"

if `run_only' == 0 | `run_only' == `test_count' {
    if `quiet' == 0 display as text _n "Test `test_count': `test_desc'"

    capture {
        sysuse auto, clear
        balancetab price mpg, treatment(foreign) format(%8.4f)
        assert r(N) > 0
    }
    if _rc == 0 {
        local ++pass_count
        if `quiet' == 0 display as result "  PASSED"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `quiet' == 0 display as error "  FAILED (error `=_rc')"
    }
}

* =============================================================================
* SECTION 2: OUTPUT TESTS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 2: Output Tests"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 7: Love plot generation
* -----------------------------------------------------------------------------
local ++test_count
local test_desc "Love plot generation"

if `run_only' == 0 | `run_only' == `test_count' {
    if `quiet' == 0 display as text _n "Test `test_count': `test_desc'"

    capture {
        sysuse auto, clear
        logit foreign price mpg
        predict ps, pr
        gen ipw = cond(foreign==1, 1/ps, 1/(1-ps))

        balancetab price mpg weight, treatment(foreign) wvar(ipw) ///
            loveplot saving("${FIGURES_DIR}/loveplot_test.png")

        confirm file "${FIGURES_DIR}/loveplot_test.png"
    }
    if _rc == 0 {
        local ++pass_count
        if `quiet' == 0 display as result "  PASSED"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `quiet' == 0 display as error "  FAILED (error `=_rc')"
    }
    capture erase "${FIGURES_DIR}/loveplot_test.png"
}

* -----------------------------------------------------------------------------
* Test 8: Excel export
* -----------------------------------------------------------------------------
local ++test_count
local test_desc "Excel export"

if `run_only' == 0 | `run_only' == `test_count' {
    if `quiet' == 0 display as text _n "Test `test_count': `test_desc'"

    capture {
        sysuse auto, clear
        balancetab price mpg weight, treatment(foreign) ///
            xlsx("${DATA_DIR}/balance_test.xlsx")

        confirm file "${DATA_DIR}/balance_test.xlsx"
    }
    if _rc == 0 {
        local ++pass_count
        if `quiet' == 0 display as result "  PASSED"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `quiet' == 0 display as error "  FAILED (error `=_rc')"
    }
    capture erase "${DATA_DIR}/balance_test.xlsx"
}

* -----------------------------------------------------------------------------
* Test 9: Excel export with custom sheet name
* -----------------------------------------------------------------------------
local ++test_count
local test_desc "Excel export with custom sheet"

if `run_only' == 0 | `run_only' == `test_count' {
    if `quiet' == 0 display as text _n "Test `test_count': `test_desc'"

    capture {
        sysuse auto, clear
        balancetab price mpg, treatment(foreign) ///
            xlsx("${DATA_DIR}/balance_sheet.xlsx") sheet("MyBalance")

        confirm file "${DATA_DIR}/balance_sheet.xlsx"
    }
    if _rc == 0 {
        local ++pass_count
        if `quiet' == 0 display as result "  PASSED"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `quiet' == 0 display as error "  FAILED (error `=_rc')"
    }
    capture erase "${DATA_DIR}/balance_sheet.xlsx"
}

* =============================================================================
* SECTION 3: RETURN VALUES TESTS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 3: Return Values Tests"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 10: Return scalars exist
* -----------------------------------------------------------------------------
local ++test_count
local test_desc "Return scalars exist"

if `run_only' == 0 | `run_only' == `test_count' {
    if `quiet' == 0 display as text _n "Test `test_count': `test_desc'"

    capture {
        sysuse auto, clear
        balancetab price mpg, treatment(foreign)

        assert r(N) != .
        assert r(N_treated) != .
        assert r(N_control) != .
        assert r(max_smd_raw) != .
        assert r(n_imbalanced) != .
        assert r(threshold) != .
    }
    if _rc == 0 {
        local ++pass_count
        if `quiet' == 0 display as result "  PASSED"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `quiet' == 0 display as error "  FAILED (error `=_rc')"
    }
}

* -----------------------------------------------------------------------------
* Test 11: Return locals exist
* -----------------------------------------------------------------------------
local ++test_count
local test_desc "Return locals exist"

if `run_only' == 0 | `run_only' == `test_count' {
    if `quiet' == 0 display as text _n "Test `test_count': `test_desc'"

    capture {
        sysuse auto, clear
        balancetab price mpg, treatment(foreign)

        assert "`r(treatment)'" != ""
        assert "`r(varlist)'" != ""
    }
    if _rc == 0 {
        local ++pass_count
        if `quiet' == 0 display as result "  PASSED"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `quiet' == 0 display as error "  FAILED (error `=_rc')"
    }
}

* -----------------------------------------------------------------------------
* Test 12: Return matrix exists
* -----------------------------------------------------------------------------
local ++test_count
local test_desc "Return matrix exists"

if `run_only' == 0 | `run_only' == `test_count' {
    if `quiet' == 0 display as text _n "Test `test_count': `test_desc'"

    capture {
        sysuse auto, clear
        balancetab price mpg weight, treatment(foreign)

        matrix M = r(balance)
        assert rowsof(M) == 3
        assert colsof(M) == 6
    }
    if _rc == 0 {
        local ++pass_count
        if `quiet' == 0 display as result "  PASSED"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `quiet' == 0 display as error "  FAILED (error `=_rc')"
    }
}

* =============================================================================
* SECTION 4: ERROR HANDLING TESTS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 4: Error Handling Tests"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 13: Error on non-binary treatment
* -----------------------------------------------------------------------------
local ++test_count
local test_desc "Error on non-binary treatment"

if `run_only' == 0 | `run_only' == `test_count' {
    if `quiet' == 0 display as text _n "Test `test_count': `test_desc'"

    capture {
        sysuse auto, clear
        capture balancetab price mpg, treatment(rep78)
        assert _rc == 198
    }
    if _rc == 0 {
        local ++pass_count
        if `quiet' == 0 display as result "  PASSED (correctly rejected)"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `quiet' == 0 display as error "  FAILED (error `=_rc')"
    }
}

* -----------------------------------------------------------------------------
* Test 14: Error on empty dataset
* -----------------------------------------------------------------------------
local ++test_count
local test_desc "Error on empty dataset"

if `run_only' == 0 | `run_only' == `test_count' {
    if `quiet' == 0 display as text _n "Test `test_count': `test_desc'"

    capture {
        clear
        set obs 0
        gen x = .
        gen treat = .
        capture balancetab x, treatment(treat)
        assert _rc == 2000
    }
    if _rc == 0 {
        local ++pass_count
        if `quiet' == 0 display as result "  PASSED (correctly rejected)"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `quiet' == 0 display as error "  FAILED (error `=_rc')"
    }
}

* -----------------------------------------------------------------------------
* Test 15: Error on negative weights
* -----------------------------------------------------------------------------
local ++test_count
local test_desc "Error on negative weights"

if `run_only' == 0 | `run_only' == `test_count' {
    if `quiet' == 0 display as text _n "Test `test_count': `test_desc'"

    capture {
        sysuse auto, clear
        gen negwgt = -1
        capture balancetab price mpg, treatment(foreign) wvar(negwgt)
        assert _rc == 198
    }
    if _rc == 0 {
        local ++pass_count
        if `quiet' == 0 display as result "  PASSED (correctly rejected)"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `quiet' == 0 display as error "  FAILED (error `=_rc')"
    }
}

* -----------------------------------------------------------------------------
* Test 16: Error on invalid threshold
* -----------------------------------------------------------------------------
local ++test_count
local test_desc "Error on invalid threshold"

if `run_only' == 0 | `run_only' == `test_count' {
    if `quiet' == 0 display as text _n "Test `test_count': `test_desc'"

    capture {
        sysuse auto, clear
        capture balancetab price mpg, treatment(foreign) threshold(-0.1)
        assert _rc == 198
    }
    if _rc == 0 {
        local ++pass_count
        if `quiet' == 0 display as result "  PASSED (correctly rejected)"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `quiet' == 0 display as error "  FAILED (error `=_rc')"
    }
}

* -----------------------------------------------------------------------------
* Test 17: Error on invalid xlsx filename
* -----------------------------------------------------------------------------
local ++test_count
local test_desc "Error on invalid xlsx filename"

if `run_only' == 0 | `run_only' == `test_count' {
    if `quiet' == 0 display as text _n "Test `test_count': `test_desc'"

    capture {
        sysuse auto, clear
        capture balancetab price mpg, treatment(foreign) xlsx("test.csv")
        assert _rc == 198
    }
    if _rc == 0 {
        local ++pass_count
        if `quiet' == 0 display as result "  PASSED (correctly rejected)"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `quiet' == 0 display as error "  FAILED (error `=_rc')"
    }
}

* =============================================================================
* SECTION 5: EDGE CASES
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 5: Edge Cases"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 18: Single covariate
* -----------------------------------------------------------------------------
local ++test_count
local test_desc "Single covariate"

if `run_only' == 0 | `run_only' == `test_count' {
    if `quiet' == 0 display as text _n "Test `test_count': `test_desc'"

    capture {
        sysuse auto, clear
        balancetab price, treatment(foreign)
        assert r(N) > 0
        matrix M = r(balance)
        assert rowsof(M) == 1
    }
    if _rc == 0 {
        local ++pass_count
        if `quiet' == 0 display as result "  PASSED"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `quiet' == 0 display as error "  FAILED (error `=_rc')"
    }
}

* -----------------------------------------------------------------------------
* Test 19: Many covariates
* -----------------------------------------------------------------------------
local ++test_count
local test_desc "Many covariates"

if `run_only' == 0 | `run_only' == `test_count' {
    if `quiet' == 0 display as text _n "Test `test_count': `test_desc'"

    capture {
        sysuse auto, clear
        balancetab price mpg weight length turn displacement gear_ratio headroom trunk, ///
            treatment(foreign)
        assert r(N) > 0
        matrix M = r(balance)
        assert rowsof(M) == 9
    }
    if _rc == 0 {
        local ++pass_count
        if `quiet' == 0 display as result "  PASSED"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `quiet' == 0 display as error "  FAILED (error `=_rc')"
    }
}

* -----------------------------------------------------------------------------
* Test 20: With if condition
* -----------------------------------------------------------------------------
local ++test_count
local test_desc "With if condition"

if `run_only' == 0 | `run_only' == `test_count' {
    if `quiet' == 0 display as text _n "Test `test_count': `test_desc'"

    capture {
        sysuse auto, clear
        balancetab price mpg if rep78 != ., treatment(foreign)
        assert r(N) == 69
    }
    if _rc == 0 {
        local ++pass_count
        if `quiet' == 0 display as result "  PASSED"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `quiet' == 0 display as error "  FAILED (error `=_rc')"
    }
}

* =============================================================================
* CLEANUP
* =============================================================================
capture erase "${DATA_DIR}/balance_test.xlsx"
capture erase "${DATA_DIR}/balance_sheet.xlsx"
capture erase "${FIGURES_DIR}/loveplot_test.png"

* =============================================================================
* SUMMARY
* =============================================================================
display as text _n "{hline 70}"
display as text "BALANCETAB FUNCTIONAL TEST SUMMARY"
display as text "{hline 70}"
display as text "Total tests:  `test_count'"
display as result "Passed:       `pass_count'"
if `fail_count' > 0 {
    display as error "Failed:       `fail_count'"
    display as error "Failed tests:`failed_tests'"
}
else {
    display as text "Failed:       `fail_count'"
}
display as text "{hline 70}"

if `fail_count' > 0 {
    display as error "Some tests FAILED."
    exit 1
}
else {
    display as result "All tests PASSED!"
}

display as text _n "Testing completed: `c(current_date)' `c(current_time)'"
