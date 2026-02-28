/*******************************************************************************
* test_eplot.do
*
* Purpose: Functional tests for eplot command - verifies the command runs
*          without errors across data mode, estimates mode, and all options.
*
* Prerequisites:
*   - eplot.ado must be installed/accessible
*
* Run modes:
*   Standalone: do test_eplot.do
*   Via runner: do run_test.do test_eplot [testnumber] [quiet] [machine]
*
* Author: Timothy Copeland
* Date: 2026-02-25
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
    global STATA_TOOLS_PATH "/Users/tcopeland/Documents/GitHub/Stata-Dev"
}
else if "`c(os)'" == "Unix" {
    global STATA_TOOLS_PATH "/home/tpcopeland/Stata-Dev"
}
else {
    global STATA_TOOLS_PATH "`c(pwd)'"
}

adopath ++ "${STATA_TOOLS_PATH}/eplot"

* Reload to pick up latest changes
capture program drop eplot
capture program drop _eplot_parse_mode
capture program drop _eplot_data
capture program drop _eplot_estimates
capture program drop _eplot_matrix
capture program drop _eplot_apply_coeflabels
capture program drop _eplot_apply_keep
capture program drop _eplot_apply_drop
capture program drop _eplot_apply_rename
capture program drop _eplot_process_groups
capture program drop _eplot_process_headers
run "${STATA_TOOLS_PATH}/eplot/eplot.ado"

* =============================================================================
* HEADER
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "EPLOT COMMAND FUNCTIONAL TESTING"
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
* HELPER: Create forest plot test data
* =============================================================================
capture program drop _make_forest_data
program define _make_forest_data
    clear
    quietly set obs 5
    gen str20 study = ""
    gen double es = .
    gen double lci = .
    gen double uci = .
    gen double weight = .
    quietly {
        replace study = "Smith 2020" in 1
        replace es = -0.16 in 1
        replace lci = -0.36 in 1
        replace uci = 0.03 in 1
        replace weight = 15.2 in 1
        replace study = "Jones 2021" in 2
        replace es = -0.33 in 2
        replace lci = -0.54 in 2
        replace uci = -0.12 in 2
        replace weight = 18.4 in 2
        replace study = "Brown 2022" in 3
        replace es = -0.09 in 3
        replace lci = -0.25 in 3
        replace uci = 0.06 in 3
        replace weight = 22.1 in 3
        replace study = "Wilson 2023" in 4
        replace es = -0.39 in 4
        replace lci = -0.65 in 4
        replace uci = -0.12 in 4
        replace weight = 12.8 in 4
        replace study = "Overall" in 5
        replace es = -0.24 in 5
        replace lci = -0.34 in 5
        replace uci = -0.13 in 5
    }
    gen byte type = cond(study == "Overall", 5, 1)
end

* =============================================================================
* DATA MODE TESTS
* =============================================================================

* TEST 1: Basic data mode (3 variables)
local ++test_count
local test_desc "Data mode: basic 3-variable input"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        _make_forest_data
        eplot es lci uci
        assert r(N) == 5
        assert `"`r(cmd)'"' != ""
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

* TEST 2: Data mode with labels
local ++test_count
local test_desc "Data mode: labels() option"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        _make_forest_data
        eplot es lci uci, labels(study)
        assert r(N) == 5
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

* TEST 3: Data mode with weights
local ++test_count
local test_desc "Data mode: weights() option"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        _make_forest_data
        eplot es lci uci, labels(study) weights(weight)
        assert r(N) == 5
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

* TEST 4: Data mode with type variable
local ++test_count
local test_desc "Data mode: type() with diamond for overall"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        _make_forest_data
        eplot es lci uci, labels(study) weights(weight) type(type)
        assert r(N) == 5
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

* TEST 5: Data mode with eform
local ++test_count
local test_desc "Data mode: eform transformation"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        _make_forest_data
        eplot es lci uci, labels(study) eform
        assert r(N) == 5
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

* TEST 6: Data mode with if/in
local ++test_count
local test_desc "Data mode: if/in conditions"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        _make_forest_data
        eplot es lci uci in 1/4, labels(study)
        assert r(N) == 4
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

* TEST 7: Data mode vertical layout
local ++test_count
local test_desc "Data mode: vertical layout"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        _make_forest_data
        eplot es lci uci, labels(study) vertical
        assert r(N) == 5
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

* TEST 8: Data mode noci + nonull + nodiamonds
local ++test_count
local test_desc "Data mode: noci, nonull, nodiamonds"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        _make_forest_data
        eplot es lci uci, labels(study) type(type) noci nonull nodiamonds
        assert r(N) == 5
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

* TEST 9: Data mode with xline + rescale + title/subtitle/note
local ++test_count
local test_desc "Data mode: xline, rescale, title/subtitle/note"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        _make_forest_data
        eplot es lci uci, labels(study) rescale(100) xline(-10 -30) ///
            title("Test Title") subtitle("Test Sub") note("Test Note")
        assert r(N) == 5
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

* TEST 10: Data mode with scheme override + passthrough
local ++test_count
local test_desc "Data mode: scheme() and twoway passthrough"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        _make_forest_data
        eplot es lci uci, labels(study) scheme(s2color) plotregion(margin(medium))
        assert r(N) == 5
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
* ESTIMATES MODE TESTS
* =============================================================================

* TEST 11: Estimates mode basic
local ++test_count
local test_desc "Estimates mode: basic with current estimates"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        sysuse auto, clear
        regress price mpg weight length foreign
        eplot ., drop(_cons)
        assert r(N) == 4
        assert `"`r(cmd)'"' != ""
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

* TEST 12: Estimates mode with eform
local ++test_count
local test_desc "Estimates mode: eform transformation"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        sysuse auto, clear
        logit foreign mpg weight
        eplot ., drop(_cons) eform
        assert r(N) == 2
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

* TEST 13: Estimates mode with coeflabels
local ++test_count
local test_desc "Estimates mode: coeflabels()"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        sysuse auto, clear
        regress price mpg weight foreign
        eplot ., drop(_cons) ///
            coeflabels(mpg = "Miles/Gallon" weight = "Weight" foreign = "Foreign")
        assert r(N) == 3
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

* TEST 14: Estimates mode with keep
local ++test_count
local test_desc "Estimates mode: keep() filter"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        sysuse auto, clear
        regress price mpg weight length foreign
        eplot ., keep(mpg foreign)
        assert r(N) == 2
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

* TEST 15: Estimates mode auto-drops base factor levels
local ++test_count
local test_desc "Estimates mode: auto-drop base factor levels"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        sysuse cancer, clear
        stset studytime, failure(died)
        stcox i.drug age
        * 2.drug 3.drug age = 3 (1b.drug auto-dropped)
        eplot ., drop(_cons) eform
        assert r(N) == 3
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

* TEST 16: Estimates mode auto-drops omitted coefficients
local ++test_count
local test_desc "Estimates mode: auto-drop omitted coefficients"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        sysuse auto, clear
        logit foreign mpg i.rep78
        * mpg + 3.rep78 + 4.rep78 = 3 estimable
        eplot ., drop(_cons) eform
        assert r(N) == 3
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

* TEST 17: Estimates mode with rename
local ++test_count
local test_desc "Estimates mode: rename()"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        sysuse auto, clear
        regress price mpg weight
        eplot ., drop(_cons) rename(mpg = "Fuel Economy" weight = "Mass")
        assert r(N) == 2
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

* TEST 18: Estimates mode with groups
local ++test_count
local test_desc "Estimates mode: groups()"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        sysuse auto, clear
        regress price mpg weight length turn foreign
        eplot ., drop(_cons) ///
            groups(mpg weight length turn = "Vehicle" foreign = "Origin")
        * 5 coefs + 2 group headers = 7
        assert r(N) == 7
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

* TEST 19: Estimates mode with level
local ++test_count
local test_desc "Estimates mode: level(99)"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        sysuse auto, clear
        regress price mpg weight
        eplot ., drop(_cons) level(99)
        assert r(N) == 2
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
* ERROR HANDLING TESTS
* =============================================================================

* TEST 20: Error - no observations
local ++test_count
local test_desc "Error: no observations (rc 2000)"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        _make_forest_data
        capture eplot es lci uci if es > 999
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

* TEST 21: Error - no estimation results
local ++test_count
local test_desc "Error: no estimation results (rc 301)"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        clear
        ereturn clear
        set obs 10
        gen double x = rnormal()
        capture eplot .
        assert _rc == 301
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

* TEST 22: Error - all coefficients dropped
local ++test_count
local test_desc "Error: all coefficients dropped (rc 2000)"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        sysuse auto, clear
        regress price mpg
        capture eplot ., drop(mpg _cons)
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

* =============================================================================
* DATA PRESERVATION TESTS
* =============================================================================

* TEST 23: Data mode preserves original data
local ++test_count
local test_desc "Data preservation: data mode"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        _make_forest_data
        local orig_n = _N
        local orig_es1 = es[1]
        eplot es lci uci, labels(study)
        assert _N == `orig_n'
        assert es[1] == `orig_es1'
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

* TEST 24: Estimates mode preserves data
local ++test_count
local test_desc "Data preservation: estimates mode"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        sysuse auto, clear
        local orig_n = _N
        regress price mpg weight
        eplot ., drop(_cons)
        assert _N == `orig_n'
        confirm variable price mpg weight
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
* EDGE CASE TESTS
* =============================================================================

* TEST 25: Single observation
local ++test_count
local test_desc "Edge case: single observation"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        clear
        quietly set obs 1
        gen double es = 0.5
        gen double lci = 0.2
        gen double uci = 0.8
        eplot es lci uci
        assert r(N) == 1
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

* TEST 26: String type variable
local ++test_count
local test_desc "Edge case: string type variable"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        clear
        quietly set obs 3
        gen str20 study = cond(_n == 1, "Study A", cond(_n == 2, "Study B", "Overall"))
        gen double es = cond(_n == 1, 0.5, cond(_n == 2, 0.3, 0.4))
        gen double lci = cond(_n == 1, 0.2, cond(_n == 2, 0.1, 0.25))
        gen double uci = cond(_n == 1, 0.8, cond(_n == 2, 0.5, 0.55))
        gen str10 rowtype = cond(_n == 3, "overall", "effect")
        eplot es lci uci, labels(study) type(rowtype)
        assert r(N) == 3
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
* CLEANUP
* =============================================================================
if `quiet' == 0 & `run_only' == 0 {
    display as text _n "{hline 70}"
    display as text "Cleaning up..."
    display as text "{hline 70}"
}

graph drop _all

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
    display as text "EPLOT FUNCTIONAL TEST SUMMARY"
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
