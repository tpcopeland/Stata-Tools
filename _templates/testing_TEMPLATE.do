/*******************************************************************************
* testing_TEMPLATE.do
*
* Purpose: Functional tests for TEMPLATE command - verifies the command runs
*          without errors across various scenarios and options.
*
* Prerequisites:
*   - Run generate_test_data.do first to create synthetic datasets (if needed)
*   - TEMPLATE.ado must be installed/accessible
*
* Run modes:
*   Standalone: do testing_TEMPLATE.do
*   Via runner: do run_test.do testing_TEMPLATE [testnumber] [quiet] [machine]
*
* Test philosophy:
*   - Does the command RUN without errors?
*   - Does it produce expected output variables?
*   - Does it handle edge cases gracefully?
*   - Does NOT verify computational correctness (that's validation)
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
    capture confirm file "_testing"
    if _rc == 0 {
        * Running from repo root
        global STATA_TOOLS_PATH "`c(pwd)'"
    }
    else {
        capture confirm file "data"
        if _rc == 0 {
            * Running from _testing directory
            global STATA_TOOLS_PATH "`c(pwd)'/.."
        }
        else {
            * Assume running from _testing/data directory
            global STATA_TOOLS_PATH "`c(pwd)'/../.."
        }
    }
}

global TESTING_DIR "${STATA_TOOLS_PATH}/_testing"
global DATA_DIR "${TESTING_DIR}/data"

* Install package from local repository (adjust path as needed)
* capture net uninstall TEMPLATE
* quietly net install TEMPLATE, from("${STATA_TOOLS_PATH}/TEMPLATE")

* =============================================================================
* HEADER (skip in quiet/machine mode)
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "TEMPLATE COMMAND FUNCTIONAL TESTING"
    display as text "{hline 70}"
    display as text "Data directory: ${DATA_DIR}"
    display as text "{hline 70}"
}

* =============================================================================
* TEST COUNTERS AND FAILURE TRACKING
* =============================================================================
local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

* =============================================================================
* TEST EXECUTION HELPER
* =============================================================================
capture program drop _run_test
program define _run_test
    args test_num test_desc

    * Check if we should run this test
    if $RUN_TEST_NUMBER > 0 & $RUN_TEST_NUMBER != `test_num' {
        exit 0  // Skip this test
    }

    * Display header in verbose mode
    if $RUN_TEST_QUIET == 0 {
        display as text _n "TEST `test_num': `test_desc'"
        display as text "{hline 50}"
    }
end

* =============================================================================
* TEST 1: Basic command execution
* =============================================================================
local ++test_count
local test_desc "Basic command execution"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        * Load test data
        sysuse auto, clear

        * Run command with minimal required options
        * TEMPLATE varlist, required_option(varname)

        * Verify expected outputs exist
        * confirm variable expected_output
        * assert _N > 0
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "[OK] `test_count'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "[FAIL] `test_count'|`=_rc'|`test_desc'"
        }
        else {
            display as error "  FAILED: `test_desc' (error `=_rc')"
        }
    }
}

* =============================================================================
* TEST 2: Option 1 enabled
* =============================================================================
local ++test_count
local test_desc "Option 1 enabled"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        sysuse auto, clear

        * Run command with option1
        * TEMPLATE varlist, required_option(varname) option1

        * Verify option1 behavior
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "[OK] `test_count'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "[FAIL] `test_count'|`=_rc'|`test_desc'"
        }
        else {
            display as error "  FAILED: `test_desc' (error `=_rc')"
        }
    }
}

* =============================================================================
* TEST 3: Option 2 with numlist
* =============================================================================
local ++test_count
local test_desc "Option 2 with numlist"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        sysuse auto, clear

        * Run command with option2
        * TEMPLATE varlist, required_option(varname) option2(1 5 10)

        * Verify option2 behavior
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "[OK] `test_count'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "[FAIL] `test_count'|`=_rc'|`test_desc'"
        }
        else {
            display as error "  FAILED: `test_desc' (error `=_rc')"
        }
    }
}

* =============================================================================
* TEST 4: generate() option
* =============================================================================
local ++test_count
local test_desc "generate() option"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        sysuse auto, clear

        * Run command with generate
        * TEMPLATE varlist, required_option(varname) generate(myresult)

        * Verify generated variable exists
        * confirm variable myresult
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "[OK] `test_count'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "[FAIL] `test_count'|`=_rc'|`test_desc'"
        }
        else {
            display as error "  FAILED: `test_desc' (error `=_rc')"
        }
    }
}

* =============================================================================
* TEST 5: if/in conditions
* =============================================================================
local ++test_count
local test_desc "if/in conditions"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        sysuse auto, clear

        * Run with if condition
        * TEMPLATE varlist if foreign == 0, required_option(varname)

        * Run with in condition
        * TEMPLATE varlist in 1/50, required_option(varname)
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "[OK] `test_count'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "[FAIL] `test_count'|`=_rc'|`test_desc'"
        }
        else {
            display as error "  FAILED: `test_desc' (error `=_rc')"
        }
    }
}

* =============================================================================
* TEST 6: Combined options
* =============================================================================
local ++test_count
local test_desc "Combined options"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        sysuse auto, clear

        * Run with multiple options combined
        * TEMPLATE varlist, required_option(varname) option1 option2(1 5) generate(result)
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "[OK] `test_count'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "[FAIL] `test_count'|`=_rc'|`test_desc'"
        }
        else {
            display as error "  FAILED: `test_desc' (error `=_rc')"
        }
    }
}

* =============================================================================
* EDGE CASE TESTS
* =============================================================================

* TEST 7: Single observation
local ++test_count
local test_desc "Edge case: single observation"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        sysuse auto, clear
        keep if _n == 1

        * TEMPLATE varlist, required_option(varname)
        assert _N > 0
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "[OK] `test_count'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "[FAIL] `test_count'|`=_rc'|`test_desc'"
        }
        else {
            display as error "  FAILED: `test_desc' (error `=_rc')"
        }
    }
}

* TEST 8: Missing values
local ++test_count
local test_desc "Edge case: missing values"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        sysuse auto, clear
        replace price = . if _n <= 10

        * TEMPLATE varlist, required_option(varname)
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "[OK] `test_count'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "[FAIL] `test_count'|`=_rc'|`test_desc'"
        }
        else {
            display as error "  FAILED: `test_desc' (error `=_rc')"
        }
    }
}

* TEST 9: Empty dataset (should error gracefully)
local ++test_count
local test_desc "Edge case: empty dataset"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        clear
        set obs 0
        gen x = .
        gen y = .

        * Should fail with appropriate error
        capture TEMPLATE x, required_option(y)
        assert _rc != 0  // Should have failed
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "[OK] `test_count'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED (correctly rejected empty data)"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "[FAIL] `test_count'|`=_rc'|`test_desc'"
        }
        else {
            display as error "  FAILED: `test_desc' (error `=_rc')"
        }
    }
}

* TEST 10: Large dataset performance
local ++test_count
local test_desc "Performance: large dataset"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        clear
        set obs 100000
        gen id = _n
        gen x = rnormal()
        gen y = rnormal()

        * Time the command
        timer clear 1
        timer on 1
        * TEMPLATE x, required_option(y)
        timer off 1

        * Should complete in reasonable time (< 60 seconds)
        quietly timer list 1
        assert r(t1) < 60
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "[OK] `test_count'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "[FAIL] `test_count'|`=_rc'|`test_desc'"
        }
        else {
            display as error "  FAILED: `test_desc' (error `=_rc')"
        }
    }
}

* =============================================================================
* CLEANUP
* =============================================================================
if `quiet' == 0 & `run_only' == 0 {
    display as text _n "{hline 70}"
    display as text "Cleaning up temporary files..."
    display as text "{hline 70}"
}

* Clean up any temporary files created during testing
* capture erase "${DATA_DIR}/_test_*.dta"

* =============================================================================
* SUMMARY
* =============================================================================
if `machine' {
    display "[SUMMARY] `pass_count'/`test_count' passed"
    if `fail_count' > 0 {
        display "[FAILED]`failed_tests'"
    }
}
else {
    display as text _n "{hline 70}"
    display as text "TEMPLATE FUNCTIONAL TEST SUMMARY"
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
        display as error "Some tests FAILED. Review output above."
        exit 1
    }
    else {
        display as result "All tests PASSED!"
    }
}

* Clear global flags
global RUN_TEST_QUIET
global RUN_TEST_MACHINE
global RUN_TEST_NUMBER
