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
* Author: Timothy Copeland
* Date: 2026-03-13
*******************************************************************************/

clear all
set more off
set seed 12345
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
    global STATA_TOOLS_PATH "/home/tpcopeland/Stata-Tools"
}
else {
    global STATA_TOOLS_PATH "`c(pwd)'"
}

global QA_DIR "${STATA_TOOLS_PATH}/balancetab/qa"
global OUTPUT_DIR "${QA_DIR}/output"

capture mkdir "${OUTPUT_DIR}"

adopath ++ "${STATA_TOOLS_PATH}/balancetab"

* Reload to pick up latest changes
capture program drop balancetab
run "${STATA_TOOLS_PATH}/balancetab/balancetab.ado"

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
local failed_tests ""

capture program drop _run_test
program define _run_test
    args test_num test_desc
    if $RUN_TEST_NUMBER > 0 & $RUN_TEST_NUMBER != `test_num' {
        exit 0
    }
    if $RUN_TEST_QUIET == 0 {
        display as text _n "TEST `test_num': `test_desc'"
        display as text "{hline 50}"
    }
end

* =============================================================================
* SECTION 1: BASIC FUNCTIONALITY
* =============================================================================

* TEST 1: Basic execution - unadjusted SMD
local ++test_count
local test_desc "Basic execution - unadjusted SMD"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        sysuse auto, clear
        balancetab price mpg weight, treatment(foreign)
        assert r(N) > 0
        assert r(N_treated) > 0
        assert r(N_control) > 0
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' display "[OK] `test_count'"
        else if `quiet' == 0 display as result "  PASSED"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' display "[FAIL] `test_count'|`=_rc'|`test_desc'"
        else display as error "  FAILED: `test_desc' (error `=_rc')"
    }
}

* TEST 2: With IPTW weights
local ++test_count
local test_desc "With IPTW weights"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        sysuse auto, clear
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
        if `machine' display "[OK] `test_count'"
        else if `quiet' == 0 display as result "  PASSED"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' display "[FAIL] `test_count'|`=_rc'|`test_desc'"
        else display as error "  FAILED: `test_desc' (error `=_rc')"
    }
}

* TEST 3: With matched option
local ++test_count
local test_desc "With matched option"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        sysuse auto, clear
        balancetab price mpg weight, treatment(foreign) matched
        assert r(N) > 0
        assert r(max_smd_raw) != .
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' display "[OK] `test_count'"
        else if `quiet' == 0 display as result "  PASSED"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' display "[FAIL] `test_count'|`=_rc'|`test_desc'"
        else display as error "  FAILED: `test_desc' (error `=_rc')"
    }
}

* TEST 4: Custom threshold
local ++test_count
local test_desc "Custom threshold option"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        sysuse auto, clear
        balancetab price mpg, treatment(foreign) threshold(0.2)
        assert r(threshold) == 0.2
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' display "[OK] `test_count'"
        else if `quiet' == 0 display as result "  PASSED"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' display "[FAIL] `test_count'|`=_rc'|`test_desc'"
        else display as error "  FAILED: `test_desc' (error `=_rc')"
    }
}

* TEST 5: Custom title
local ++test_count
local test_desc "Custom title option"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        sysuse auto, clear
        balancetab price mpg, treatment(foreign) title("My Custom Title")
        assert r(N) > 0
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' display "[OK] `test_count'"
        else if `quiet' == 0 display as result "  PASSED"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' display "[FAIL] `test_count'|`=_rc'|`test_desc'"
        else display as error "  FAILED: `test_desc' (error `=_rc')"
    }
}

* TEST 6: Custom format
local ++test_count
local test_desc "Custom format option"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        sysuse auto, clear
        balancetab price mpg, treatment(foreign) format(%8.4f)
        assert r(N) > 0
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' display "[OK] `test_count'"
        else if `quiet' == 0 display as result "  PASSED"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' display "[FAIL] `test_count'|`=_rc'|`test_desc'"
        else display as error "  FAILED: `test_desc' (error `=_rc')"
    }
}

* =============================================================================
* SECTION 2: OUTPUT TESTS
* =============================================================================

* TEST 7: Love plot (weighted, with saving)
local ++test_count
local test_desc "Love plot with weights and saving"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        sysuse auto, clear
        logit foreign price mpg
        predict ps, pr
        gen ipw = cond(foreign==1, 1/ps, 1/(1-ps))
        balancetab price mpg weight, treatment(foreign) wvar(ipw) ///
            loveplot saving("${OUTPUT_DIR}/loveplot_test.png")
        confirm file "${OUTPUT_DIR}/loveplot_test.png"
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' display "[OK] `test_count'"
        else if `quiet' == 0 display as result "  PASSED"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' display "[FAIL] `test_count'|`=_rc'|`test_desc'"
        else display as error "  FAILED: `test_desc' (error `=_rc')"
    }
    capture erase "${OUTPUT_DIR}/loveplot_test.png"
}

* TEST 8: Love plot (unadjusted, no weights)
local ++test_count
local test_desc "Love plot unadjusted"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        sysuse auto, clear
        balancetab price mpg weight, treatment(foreign) loveplot
        assert r(N) > 0
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' display "[OK] `test_count'"
        else if `quiet' == 0 display as result "  PASSED"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' display "[FAIL] `test_count'|`=_rc'|`test_desc'"
        else display as error "  FAILED: `test_desc' (error `=_rc')"
    }
}

* TEST 9: Love plot with scheme()
local ++test_count
local test_desc "Love plot with scheme option"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        sysuse auto, clear
        balancetab price mpg, treatment(foreign) ///
            loveplot scheme(plotplainblind)
        assert r(N) > 0
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' display "[OK] `test_count'"
        else if `quiet' == 0 display as result "  PASSED"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' display "[FAIL] `test_count'|`=_rc'|`test_desc'"
        else display as error "  FAILED: `test_desc' (error `=_rc')"
    }
}

* TEST 10: Love plot with graphoptions()
local ++test_count
local test_desc "Love plot with graphoptions"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        sysuse auto, clear
        balancetab price mpg, treatment(foreign) ///
            loveplot graphoptions(note("Test note"))
        assert r(N) > 0
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' display "[OK] `test_count'"
        else if `quiet' == 0 display as result "  PASSED"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' display "[FAIL] `test_count'|`=_rc'|`test_desc'"
        else display as error "  FAILED: `test_desc' (error `=_rc')"
    }
}

* TEST 11: Excel export
local ++test_count
local test_desc "Excel export"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        sysuse auto, clear
        balancetab price mpg weight, treatment(foreign) ///
            xlsx("${OUTPUT_DIR}/balance_test.xlsx")
        confirm file "${OUTPUT_DIR}/balance_test.xlsx"
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' display "[OK] `test_count'"
        else if `quiet' == 0 display as result "  PASSED"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' display "[FAIL] `test_count'|`=_rc'|`test_desc'"
        else display as error "  FAILED: `test_desc' (error `=_rc')"
    }
    capture erase "${OUTPUT_DIR}/balance_test.xlsx"
}

* TEST 12: Excel export with custom sheet
local ++test_count
local test_desc "Excel export with custom sheet"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        sysuse auto, clear
        balancetab price mpg, treatment(foreign) ///
            xlsx("${OUTPUT_DIR}/balance_sheet.xlsx") sheet("MyBalance")
        confirm file "${OUTPUT_DIR}/balance_sheet.xlsx"
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' display "[OK] `test_count'"
        else if `quiet' == 0 display as result "  PASSED"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' display "[FAIL] `test_count'|`=_rc'|`test_desc'"
        else display as error "  FAILED: `test_desc' (error `=_rc')"
    }
    capture erase "${OUTPUT_DIR}/balance_sheet.xlsx"
}

* TEST 13: Excel export with weights (7-column output)
local ++test_count
local test_desc "Excel export with weighted columns"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        sysuse auto, clear
        gen wgt = 1 + uniform()
        balancetab price mpg, treatment(foreign) wvar(wgt) ///
            xlsx("${OUTPUT_DIR}/balance_wgt.xlsx")
        confirm file "${OUTPUT_DIR}/balance_wgt.xlsx"
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' display "[OK] `test_count'"
        else if `quiet' == 0 display as result "  PASSED"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' display "[FAIL] `test_count'|`=_rc'|`test_desc'"
        else display as error "  FAILED: `test_desc' (error `=_rc')"
    }
    capture erase "${OUTPUT_DIR}/balance_wgt.xlsx"
}

* =============================================================================
* SECTION 3: RETURN VALUES
* =============================================================================

* TEST 14: Return scalars exist
local ++test_count
local test_desc "Return scalars exist"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
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
        if `machine' display "[OK] `test_count'"
        else if `quiet' == 0 display as result "  PASSED"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' display "[FAIL] `test_count'|`=_rc'|`test_desc'"
        else display as error "  FAILED: `test_desc' (error `=_rc')"
    }
}

* TEST 15: Return macros exist
local ++test_count
local test_desc "Return macros exist"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        sysuse auto, clear
        balancetab price mpg, treatment(foreign)
        assert "`r(treatment)'" != ""
        assert "`r(varlist)'" != ""
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' display "[OK] `test_count'"
        else if `quiet' == 0 display as result "  PASSED"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' display "[FAIL] `test_count'|`=_rc'|`test_desc'"
        else display as error "  FAILED: `test_desc' (error `=_rc')"
    }
}

* TEST 16: Return matrix exists with correct dimensions
local ++test_count
local test_desc "Return matrix 3x6"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        sysuse auto, clear
        balancetab price mpg weight, treatment(foreign)
        matrix M = r(balance)
        assert rowsof(M) == 3
        assert colsof(M) == 6
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' display "[OK] `test_count'"
        else if `quiet' == 0 display as result "  PASSED"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' display "[FAIL] `test_count'|`=_rc'|`test_desc'"
        else display as error "  FAILED: `test_desc' (error `=_rc')"
    }
}

* TEST 17: r(wvar) returned when weights specified
local ++test_count
local test_desc "r(wvar) returned with weights"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        sysuse auto, clear
        gen wgt = 1 + uniform()
        balancetab price mpg, treatment(foreign) wvar(wgt)
        assert "`r(wvar)'" == "wgt"
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' display "[OK] `test_count'"
        else if `quiet' == 0 display as result "  PASSED"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' display "[FAIL] `test_count'|`=_rc'|`test_desc'"
        else display as error "  FAILED: `test_desc' (error `=_rc')"
    }
}

* =============================================================================
* SECTION 4: ERROR HANDLING
* =============================================================================

* TEST 18: Error on non-binary treatment
local ++test_count
local test_desc "Error on non-binary treatment"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        sysuse auto, clear
        capture balancetab price mpg, treatment(rep78)
        assert _rc == 198
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' display "[OK] `test_count'"
        else if `quiet' == 0 display as result "  PASSED (correctly rejected)"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' display "[FAIL] `test_count'|`=_rc'|`test_desc'"
        else display as error "  FAILED: `test_desc' (error `=_rc')"
    }
}

* TEST 19: Error on empty dataset
local ++test_count
local test_desc "Error on empty dataset"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
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
        if `machine' display "[OK] `test_count'"
        else if `quiet' == 0 display as result "  PASSED (correctly rejected)"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' display "[FAIL] `test_count'|`=_rc'|`test_desc'"
        else display as error "  FAILED: `test_desc' (error `=_rc')"
    }
}

* TEST 20: Error on negative weights
local ++test_count
local test_desc "Error on negative weights"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        sysuse auto, clear
        gen negwgt = -1
        capture balancetab price mpg, treatment(foreign) wvar(negwgt)
        assert _rc == 198
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' display "[OK] `test_count'"
        else if `quiet' == 0 display as result "  PASSED (correctly rejected)"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' display "[FAIL] `test_count'|`=_rc'|`test_desc'"
        else display as error "  FAILED: `test_desc' (error `=_rc')"
    }
}

* TEST 21: Error on invalid threshold
local ++test_count
local test_desc "Error on invalid threshold"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        sysuse auto, clear
        capture balancetab price mpg, treatment(foreign) threshold(-0.1)
        assert _rc == 198
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' display "[OK] `test_count'"
        else if `quiet' == 0 display as result "  PASSED (correctly rejected)"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' display "[FAIL] `test_count'|`=_rc'|`test_desc'"
        else display as error "  FAILED: `test_desc' (error `=_rc')"
    }
}

* TEST 22: Error on invalid xlsx filename
local ++test_count
local test_desc "Error on invalid xlsx filename"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        sysuse auto, clear
        capture balancetab price mpg, treatment(foreign) xlsx("test.csv")
        assert _rc == 198
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' display "[OK] `test_count'"
        else if `quiet' == 0 display as result "  PASSED (correctly rejected)"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' display "[FAIL] `test_count'|`=_rc'|`test_desc'"
        else display as error "  FAILED: `test_desc' (error `=_rc')"
    }
}

* TEST 23: wvar() and matched mutually exclusive
local ++test_count
local test_desc "wvar() and matched mutually exclusive"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        sysuse auto, clear
        gen double w = abs(1 + 0.5*rnormal())
        capture balancetab price mpg, treatment(foreign) wvar(w) matched
        assert _rc == 198
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' display "[OK] `test_count'"
        else if `quiet' == 0 display as result "  PASSED (correctly rejected)"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' display "[FAIL] `test_count'|`=_rc'|`test_desc'"
        else display as error "  FAILED: `test_desc' (error `=_rc')"
    }
}

* TEST 24: strata() option rejected
local ++test_count
local test_desc "strata() option no longer accepted"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        sysuse auto, clear
        gen byte strat = (_n > 37)
        capture balancetab price mpg, treatment(foreign) strata(strat)
        assert _rc != 0
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' display "[OK] `test_count'"
        else if `quiet' == 0 display as result "  PASSED (correctly rejected)"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' display "[FAIL] `test_count'|`=_rc'|`test_desc'"
        else display as error "  FAILED: `test_desc' (error `=_rc')"
    }
}

* =============================================================================
* SECTION 5: EDGE CASES
* =============================================================================

* TEST 25: Single covariate
local ++test_count
local test_desc "Single covariate"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        sysuse auto, clear
        balancetab price, treatment(foreign)
        assert r(N) > 0
        matrix M = r(balance)
        assert rowsof(M) == 1
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' display "[OK] `test_count'"
        else if `quiet' == 0 display as result "  PASSED"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' display "[FAIL] `test_count'|`=_rc'|`test_desc'"
        else display as error "  FAILED: `test_desc' (error `=_rc')"
    }
}

* TEST 26: Many covariates
local ++test_count
local test_desc "Many covariates (9)"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
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
        if `machine' display "[OK] `test_count'"
        else if `quiet' == 0 display as result "  PASSED"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' display "[FAIL] `test_count'|`=_rc'|`test_desc'"
        else display as error "  FAILED: `test_desc' (error `=_rc')"
    }
}

* TEST 27: if condition
local ++test_count
local test_desc "if condition restricts sample"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        sysuse auto, clear
        balancetab price mpg if rep78 != ., treatment(foreign)
        assert r(N) == 69
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' display "[OK] `test_count'"
        else if `quiet' == 0 display as result "  PASSED"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' display "[FAIL] `test_count'|`=_rc'|`test_desc'"
        else display as error "  FAILED: `test_desc' (error `=_rc')"
    }
}

* TEST 28: in condition
local ++test_count
local test_desc "in condition restricts sample"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        clear
        set obs 100
        gen byte treat = (_n > 50)
        gen double x = rnormal()
        balancetab x in 1/80, treatment(treat)
        assert r(N) == 80
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' display "[OK] `test_count'"
        else if `quiet' == 0 display as result "  PASSED"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' display "[FAIL] `test_count'|`=_rc'|`test_desc'"
        else display as error "  FAILED: `test_desc' (error `=_rc')"
    }
}

* TEST 29: Missing values in covariates (excluded via markout)
local ++test_count
local test_desc "Missing values in covariates handled"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        clear
        set obs 100
        gen byte treat = (_n > 50)
        gen double x1 = rnormal()
        replace x1 = . in 1/5
        balancetab x1, treatment(treat)
        assert r(N) == 95
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' display "[OK] `test_count'"
        else if `quiet' == 0 display as result "  PASSED"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' display "[FAIL] `test_count'|`=_rc'|`test_desc'"
        else display as error "  FAILED: `test_desc' (error `=_rc')"
    }
}

* TEST 30: Zero-variance equal means -> SMD = 0
local ++test_count
local test_desc "Zero-variance equal means gives SMD = 0"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        clear
        set obs 100
        gen byte treat = (_n > 50)
        gen double constant_var = 5
        balancetab constant_var, treatment(treat)
        matrix B = r(balance)
        assert B[1,3] == 0
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' display "[OK] `test_count'"
        else if `quiet' == 0 display as result "  PASSED"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' display "[FAIL] `test_count'|`=_rc'|`test_desc'"
        else display as error "  FAILED: `test_desc' (error `=_rc')"
    }
}

* TEST 31: Zero-variance different means -> SMD = .
local ++test_count
local test_desc "Zero-variance different means gives SMD = ."
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        clear
        set obs 100
        gen byte treat = (_n > 50)
        gen double diff_const = cond(treat == 1, 5, 3)
        balancetab diff_const, treatment(treat)
        matrix B = r(balance)
        assert missing(B[1,3])
        assert r(n_imbalanced) == 1
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' display "[OK] `test_count'"
        else if `quiet' == 0 display as result "  PASSED"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' display "[FAIL] `test_count'|`=_rc'|`test_desc'"
        else display as error "  FAILED: `test_desc' (error `=_rc')"
    }
}

* TEST 32: Mixed normal + zero-variance covariates
local ++test_count
local test_desc "Mixed normal and zero-variance covariates"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        clear
        set obs 100
        gen byte treat = (_n > 50)
        gen double age = 40 + 5*rnormal() + 3*treat
        gen double diff_const = cond(treat == 1, 5, 3)
        gen double same_const = 7
        balancetab age diff_const same_const, treatment(treat)
        matrix B = r(balance)
        assert !missing(B[1,3])
        assert missing(B[2,3])
        assert B[3,3] == 0
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' display "[OK] `test_count'"
        else if `quiet' == 0 display as result "  PASSED"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' display "[FAIL] `test_count'|`=_rc'|`test_desc'"
        else display as error "  FAILED: `test_desc' (error `=_rc')"
    }
}

* =============================================================================
* SECTION 6: REGRESSION TESTS
* =============================================================================

* TEST 33: matched does NOT return r(max_smd_adj)
local ++test_count
local test_desc "matched does not return r(max_smd_adj)"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        sysuse auto, clear
        balancetab price mpg, treatment(foreign) matched
        capture confirm scalar r(max_smd_adj)
        assert _rc != 0
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' display "[OK] `test_count'"
        else if `quiet' == 0 display as result "  PASSED"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' display "[FAIL] `test_count'|`=_rc'|`test_desc'"
        else display as error "  FAILED: `test_desc' (error `=_rc')"
    }
}

* TEST 34: wvar returns r(max_smd_adj)
local ++test_count
local test_desc "wvar returns r(max_smd_adj)"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        sysuse auto, clear
        logit foreign price mpg
        predict ps, pr
        gen double ipw2 = cond(foreign==1, 1/ps, 1/(1-ps))
        balancetab price mpg, treatment(foreign) wvar(ipw2)
        assert r(max_smd_adj) != .
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' display "[OK] `test_count'"
        else if `quiet' == 0 display as result "  PASSED"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' display "[FAIL] `test_count'|`=_rc'|`test_desc'"
        else display as error "  FAILED: `test_desc' (error `=_rc')"
    }
}

* TEST 35: Data preserved after command
local ++test_count
local test_desc "Data preserved after command"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        sysuse auto, clear
        local orig_N = _N
        balancetab price mpg, treatment(foreign)
        assert _N == `orig_N'
        confirm variable price mpg foreign make
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' display "[OK] `test_count'"
        else if `quiet' == 0 display as result "  PASSED"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' display "[FAIL] `test_count'|`=_rc'|`test_desc'"
        else display as error "  FAILED: `test_desc' (error `=_rc')"
    }
}

* TEST 36: Large dataset performance
local ++test_count
local test_desc "Performance: large dataset (100k obs)"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        clear
        set obs 100000
        gen byte treat = (_n > 50000)
        gen double x1 = rnormal() + 0.5*treat
        gen double x2 = rnormal() + 0.3*treat
        gen double x3 = rnormal()

        timer clear 1
        timer on 1
        balancetab x1 x2 x3, treatment(treat)
        timer off 1

        quietly timer list 1
        assert r(t1) < 60
        assert r(N) == 100000
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' display "[OK] `test_count'"
        else if `quiet' == 0 display as result "  PASSED"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' display "[FAIL] `test_count'|`=_rc'|`test_desc'"
        else display as error "  FAILED: `test_desc' (error `=_rc')"
    }
}

* TEST 37: All options combined
local ++test_count
local test_desc "All options combined"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        sysuse auto, clear
        logit foreign price mpg weight
        predict ps, pr
        gen double ipw = cond(foreign==1, 1/ps, 1/(1-ps))
        replace ipw = min(ipw, 10)

        balancetab price mpg weight, treatment(foreign) wvar(ipw) ///
            threshold(0.15) format(%8.4f) title("Full Options Test") ///
            loveplot saving("${OUTPUT_DIR}/full_test.png") ///
            scheme(plotplainblind) ///
            xlsx("${OUTPUT_DIR}/full_test.xlsx") sheet("FullTest")

        confirm file "${OUTPUT_DIR}/full_test.png"
        confirm file "${OUTPUT_DIR}/full_test.xlsx"
        assert r(N) > 0
        assert r(threshold) == 0.15
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' display "[OK] `test_count'"
        else if `quiet' == 0 display as result "  PASSED"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' display "[FAIL] `test_count'|`=_rc'|`test_desc'"
        else display as error "  FAILED: `test_desc' (error `=_rc')"
    }
    capture erase "${OUTPUT_DIR}/full_test.png"
    capture erase "${OUTPUT_DIR}/full_test.xlsx"
}

* =============================================================================
* CLEANUP
* =============================================================================
capture graph drop _all

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
        display as error "Some tests FAILED. Review output above."
        exit 1
    }
    else {
        display as result "ALL TESTS PASSED!"
    }
}

* Clear global flags
global RUN_TEST_QUIET
global RUN_TEST_MACHINE
global RUN_TEST_NUMBER
