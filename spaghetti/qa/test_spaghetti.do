/*******************************************************************************
* test_spaghetti.do
*
* Purpose: Functional tests for spaghetti v1.0.0 -- verifies all options run
*          without errors across various scenarios and edge cases.
*
* Commands tested: spaghetti
*
* Author: Timothy P Copeland
* Date: 2026-03-15
*******************************************************************************/

clear all
set more off
set seed 20260315
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

* Path config
global STATA_TOOLS_PATH "/home/tpcopeland/Stata-Dev"

* Install package
capture ado uninstall spaghetti
quietly net install spaghetti, from("${STATA_TOOLS_PATH}/spaghetti")

* =============================================================================
* HEADER
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "spaghetti PACKAGE FUNCTIONAL TESTING"
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
* HELPER: Generate test panel data
* =============================================================================
capture program drop _make_panel_data
program define _make_panel_data
    args n_ids n_times seed
    clear
    set seed `seed'
    local N = `n_ids' * `n_times'
    quietly set obs `N'
    quietly gen patid = ceil(_n / `n_times')
    bysort patid: gen months = _n - 1
    quietly gen treatment = (patid > `n_ids' / 2)
    quietly gen double sdmt = 50 + 2*months - 3*treatment*months + rnormal(0, 5)
    quietly gen center = mod(patid, 3) + 1
    quietly gen double bl_sdmt = .
    bysort patid (months): replace bl_sdmt = sdmt[1]

    label variable sdmt "SDMT Score"
    label variable months "Months"
    label define _tx_lbl 0 "Control" 1 "Treated", replace
    label values treatment _tx_lbl
end

* =============================================================================
* TEST 1: Minimal call
* =============================================================================
local ++test_count
local test_desc "Minimal call (outcome, id, time)"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    _make_panel_data 50 10 12345
    capture {
        spaghetti sdmt, id(patid) time(months)
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "RESULT: pass `test_count' `test_desc'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "RESULT: fail `test_count' `test_desc' rc=`=_rc'"
        }
        else {
            display as error "  FAILED (rc=`=_rc')"
        }
    }
}

* =============================================================================
* TEST 2: Return values
* =============================================================================
local ++test_count
local test_desc "Return values match data"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    _make_panel_data 50 10 12345
    capture {
        spaghetti sdmt, id(patid) time(months)
        assert r(N) == 500
        assert r(n_ids) == 50
        assert r(n_groups) == 1
        assert "`r(outcome)'" == "sdmt"
        assert "`r(id)'" == "patid"
        assert "`r(time)'" == "months"
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "RESULT: pass `test_count' `test_desc'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "RESULT: fail `test_count' `test_desc' rc=`=_rc'"
        }
        else {
            display as error "  FAILED (rc=`=_rc')"
        }
    }
}

* =============================================================================
* TEST 3: by() with binary variable
* =============================================================================
local ++test_count
local test_desc "by() with binary variable"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    _make_panel_data 50 10 12345
    capture {
        spaghetti sdmt, id(patid) time(months) by(treatment)
        assert r(n_groups) == 2
        assert "`r(by)'" == "treatment"
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "RESULT: pass `test_count' `test_desc'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "RESULT: fail `test_count' `test_desc' rc=`=_rc'"
        }
        else {
            display as error "  FAILED (rc=`=_rc')"
        }
    }
}

* =============================================================================
* TEST 4: by() with 3 levels
* =============================================================================
local ++test_count
local test_desc "by() with 3 levels"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    _make_panel_data 50 10 12345
    capture {
        spaghetti sdmt, id(patid) time(months) by(center)
        assert r(n_groups) == 3
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "RESULT: pass `test_count' `test_desc'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "RESULT: fail `test_count' `test_desc' rc=`=_rc'"
        }
        else {
            display as error "  FAILED (rc=`=_rc')"
        }
    }
}

* =============================================================================
* TEST 5: mean(bold)
* =============================================================================
local ++test_count
local test_desc "mean(bold)"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    _make_panel_data 50 10 12345
    capture {
        spaghetti sdmt, id(patid) time(months) mean(bold)
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "RESULT: pass `test_count' `test_desc'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "RESULT: fail `test_count' `test_desc' rc=`=_rc'"
        }
        else {
            display as error "  FAILED (rc=`=_rc')"
        }
    }
}

* =============================================================================
* TEST 6: mean(bold ci)
* =============================================================================
local ++test_count
local test_desc "mean(bold ci)"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    _make_panel_data 50 10 12345
    capture {
        spaghetti sdmt, id(patid) time(months) mean(bold ci)
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "RESULT: pass `test_count' `test_desc'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "RESULT: fail `test_count' `test_desc' rc=`=_rc'"
        }
        else {
            display as error "  FAILED (rc=`=_rc')"
        }
    }
}

* =============================================================================
* TEST 7: mean(bold ci) with by()
* =============================================================================
local ++test_count
local test_desc "mean(bold ci) with by()"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    _make_panel_data 50 10 12345
    capture {
        spaghetti sdmt, id(patid) time(months) by(treatment) mean(bold ci)
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "RESULT: pass `test_count' `test_desc'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "RESULT: fail `test_count' `test_desc' rc=`=_rc'"
        }
        else {
            display as error "  FAILED (rc=`=_rc')"
        }
    }
}

* =============================================================================
* TEST 8: mean(bold smooth(lowess))
* =============================================================================
local ++test_count
local test_desc "mean with lowess smoothing"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    _make_panel_data 50 10 12345
    capture {
        spaghetti sdmt, id(patid) time(months) mean(bold smooth(lowess))
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "RESULT: pass `test_count' `test_desc'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "RESULT: fail `test_count' `test_desc' rc=`=_rc'"
        }
        else {
            display as error "  FAILED (rc=`=_rc')"
        }
    }
}

* =============================================================================
* TEST 9: mean(bold smooth(linear)) with by()
* =============================================================================
local ++test_count
local test_desc "mean with linear smoothing and by()"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    _make_panel_data 50 10 12345
    capture {
        spaghetti sdmt, id(patid) time(months) by(treatment) ///
            mean(bold smooth(linear))
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "RESULT: pass `test_count' `test_desc'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "RESULT: fail `test_count' `test_desc' rc=`=_rc'"
        }
        else {
            display as error "  FAILED (rc=`=_rc')"
        }
    }
}

* =============================================================================
* TEST 10: sample()
* =============================================================================
local ++test_count
local test_desc "sample(20) returns correct n_sampled"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    _make_panel_data 50 10 12345
    capture {
        spaghetti sdmt, id(patid) time(months) sample(20) seed(42)
        assert r(n_sampled) == 20
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "RESULT: pass `test_count' `test_desc'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "RESULT: fail `test_count' `test_desc' rc=`=_rc'"
        }
        else {
            display as error "  FAILED (rc=`=_rc')"
        }
    }
}

* =============================================================================
* TEST 11: sample() + by()
* =============================================================================
local ++test_count
local test_desc "sample() with by()"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    _make_panel_data 50 10 12345
    capture {
        spaghetti sdmt, id(patid) time(months) by(treatment) ///
            sample(30) seed(42)
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "RESULT: pass `test_count' `test_desc'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "RESULT: fail `test_count' `test_desc' rc=`=_rc'"
        }
        else {
            display as error "  FAILED (rc=`=_rc')"
        }
    }
}

* =============================================================================
* TEST 12: sample >= n_ids keeps all
* =============================================================================
local ++test_count
local test_desc "sample() >= n_ids keeps all"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    _make_panel_data 50 10 12345
    capture {
        spaghetti sdmt, id(patid) time(months) sample(100)
        assert r(n_sampled) == 50
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "RESULT: pass `test_count' `test_desc'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "RESULT: fail `test_count' `test_desc' rc=`=_rc'"
        }
        else {
            display as error "  FAILED (rc=`=_rc')"
        }
    }
}

* =============================================================================
* TEST 13: seed() reproducibility
* =============================================================================
local ++test_count
local test_desc "seed() produces reproducible results"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    _make_panel_data 50 10 12345
    capture {
        spaghetti sdmt, id(patid) time(months) sample(10) seed(99999)
        local cmd1 `"`r(cmd)'"'
        spaghetti sdmt, id(patid) time(months) sample(10) seed(99999)
        local cmd2 `"`r(cmd)'"'
        assert `"`cmd1'"' == `"`cmd2'"'
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "RESULT: pass `test_count' `test_desc'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "RESULT: fail `test_count' `test_desc' rc=`=_rc'"
        }
        else {
            display as error "  FAILED (rc=`=_rc')"
        }
    }
}

* =============================================================================
* TEST 14: highlight with single condition
* =============================================================================
local ++test_count
local test_desc "highlight(patid==1)"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    _make_panel_data 50 10 12345
    capture {
        spaghetti sdmt, id(patid) time(months) highlight(patid==1)
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "RESULT: pass `test_count' `test_desc'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "RESULT: fail `test_count' `test_desc' rc=`=_rc'"
        }
        else {
            display as error "  FAILED (rc=`=_rc')"
        }
    }
}

* =============================================================================
* TEST 15: highlight with OR condition
* =============================================================================
local ++test_count
local test_desc "highlight with OR expression"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    _make_panel_data 50 10 12345
    capture {
        spaghetti sdmt, id(patid) time(months) ///
            highlight(patid==1 | patid==5)
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "RESULT: pass `test_count' `test_desc'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "RESULT: fail `test_count' `test_desc' rc=`=_rc'"
        }
        else {
            display as error "  FAILED (rc=`=_rc')"
        }
    }
}

* =============================================================================
* TEST 16: highlight with inequality
* =============================================================================
local ++test_count
local test_desc "highlight with inequality"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    _make_panel_data 50 10 12345
    capture {
        spaghetti sdmt, id(patid) time(months) highlight(bl_sdmt < 45)
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "RESULT: pass `test_count' `test_desc'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "RESULT: fail `test_count' `test_desc' rc=`=_rc'"
        }
        else {
            display as error "  FAILED (rc=`=_rc')"
        }
    }
}

* =============================================================================
* TEST 17: highlight + by()
* =============================================================================
local ++test_count
local test_desc "highlight + by()"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    _make_panel_data 50 10 12345
    capture {
        spaghetti sdmt, id(patid) time(months) by(treatment) ///
            highlight(patid==1 | patid==26)
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "RESULT: pass `test_count' `test_desc'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "RESULT: fail `test_count' `test_desc' rc=`=_rc'"
        }
        else {
            display as error "  FAILED (rc=`=_rc')"
        }
    }
}

* =============================================================================
* TEST 18: colorby continuous (quintiles)
* =============================================================================
local ++test_count
local test_desc "colorby() continuous (quintiles)"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    _make_panel_data 50 10 12345
    capture {
        spaghetti sdmt, id(patid) time(months) colorby(bl_sdmt)
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "RESULT: pass `test_count' `test_desc'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "RESULT: fail `test_count' `test_desc' rc=`=_rc'"
        }
        else {
            display as error "  FAILED (rc=`=_rc')"
        }
    }
}

* =============================================================================
* TEST 19: colorby categorical
* =============================================================================
local ++test_count
local test_desc "colorby(, categorical)"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    _make_panel_data 50 10 12345
    capture {
        spaghetti sdmt, id(patid) time(months) colorby(center, categorical)
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "RESULT: pass `test_count' `test_desc'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "RESULT: fail `test_count' `test_desc' rc=`=_rc'"
        }
        else {
            display as error "  FAILED (rc=`=_rc')"
        }
    }
}

* =============================================================================
* TEST 20: refline basic
* =============================================================================
local ++test_count
local test_desc "refline(5)"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    _make_panel_data 50 10 12345
    capture {
        spaghetti sdmt, id(patid) time(months) refline(5)
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "RESULT: pass `test_count' `test_desc'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "RESULT: fail `test_count' `test_desc' rc=`=_rc'"
        }
        else {
            display as error "  FAILED (rc=`=_rc')"
        }
    }
}

* =============================================================================
* TEST 21: refline with label and style
* =============================================================================
local ++test_count
local test_desc "refline with label and style"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    _make_panel_data 50 10 12345
    capture {
        spaghetti sdmt, id(patid) time(months) ///
            refline(5, label("Midpoint") style(dash))
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "RESULT: pass `test_count' `test_desc'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "RESULT: fail `test_count' `test_desc' rc=`=_rc'"
        }
        else {
            display as error "  FAILED (rc=`=_rc')"
        }
    }
}

* =============================================================================
* TEST 22: export to PNG
* =============================================================================
local ++test_count
local test_desc "export() to PNG file"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    _make_panel_data 50 10 12345
    local export_file "/tmp/spaghetti_test_export.png"
    capture erase "`export_file'"
    capture {
        spaghetti sdmt, id(patid) time(months) ///
            export(`export_file', replace)
        confirm file "`export_file'"
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "RESULT: pass `test_count' `test_desc'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "RESULT: fail `test_count' `test_desc' rc=`=_rc'"
        }
        else {
            display as error "  FAILED (rc=`=_rc')"
        }
    }
    capture erase "`export_file'"
}

* =============================================================================
* TEST 23: custom colors
* =============================================================================
local ++test_count
local test_desc "colors() override"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    _make_panel_data 50 10 12345
    capture {
        spaghetti sdmt, id(patid) time(months) by(treatment) ///
            colors(red blue)
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "RESULT: pass `test_count' `test_desc'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "RESULT: fail `test_count' `test_desc' rc=`=_rc'"
        }
        else {
            display as error "  FAILED (rc=`=_rc')"
        }
    }
}

* =============================================================================
* TEST 24: individual() styling
* =============================================================================
local ++test_count
local test_desc "individual() styling options"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    _make_panel_data 50 10 12345
    capture {
        spaghetti sdmt, id(patid) time(months) ///
            individual(color(gs10) opacity(20) lwidth(thin))
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "RESULT: pass `test_count' `test_desc'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "RESULT: fail `test_count' `test_desc' rc=`=_rc'"
        }
        else {
            display as error "  FAILED (rc=`=_rc')"
        }
    }
}

* =============================================================================
* TEST 25: title, subtitle, note, scheme
* =============================================================================
local ++test_count
local test_desc "Graph options passthrough"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    _make_panel_data 50 10 12345
    capture {
        spaghetti sdmt, id(patid) time(months) ///
            title("Test Title") subtitle("Test Subtitle") ///
            note("Test Note") scheme(s2color)
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "RESULT: pass `test_count' `test_desc'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "RESULT: fail `test_count' `test_desc' rc=`=_rc'"
        }
        else {
            display as error "  FAILED (rc=`=_rc')"
        }
    }
}

* =============================================================================
* TEST 26: ytitle() and xtitle()
* =============================================================================
local ++test_count
local test_desc "ytitle() and xtitle() custom"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    _make_panel_data 50 10 12345
    capture {
        spaghetti sdmt, id(patid) time(months) ///
            ytitle("Custom Y") xtitle("Custom X")
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "RESULT: pass `test_count' `test_desc'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "RESULT: fail `test_count' `test_desc' rc=`=_rc'"
        }
        else {
            display as error "  FAILED (rc=`=_rc')"
        }
    }
}

* =============================================================================
* TEST 27: sample + mean + by combined
* =============================================================================
local ++test_count
local test_desc "sample + mean + by combined"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    _make_panel_data 50 10 12345
    capture {
        spaghetti sdmt, id(patid) time(months) by(treatment) ///
            sample(20) seed(42) mean(bold ci)
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "RESULT: pass `test_count' `test_desc'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "RESULT: fail `test_count' `test_desc' rc=`=_rc'"
        }
        else {
            display as error "  FAILED (rc=`=_rc')"
        }
    }
}

* =============================================================================
* TEST 28: highlight + mean
* =============================================================================
local ++test_count
local test_desc "highlight + mean combined"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    _make_panel_data 50 10 12345
    capture {
        spaghetti sdmt, id(patid) time(months) ///
            highlight(patid<=5) mean(bold ci)
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "RESULT: pass `test_count' `test_desc'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "RESULT: fail `test_count' `test_desc' rc=`=_rc'"
        }
        else {
            display as error "  FAILED (rc=`=_rc')"
        }
    }
}

* =============================================================================
* TEST 29: Error - no observations
* =============================================================================
local ++test_count
local test_desc "Error: no observations (rc=2000)"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    _make_panel_data 50 10 12345
    capture {
        capture noisily spaghetti sdmt if patid > 999, id(patid) time(months)
        assert _rc == 2000
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "RESULT: pass `test_count' `test_desc'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "RESULT: fail `test_count' `test_desc' rc=`=_rc'"
        }
        else {
            display as error "  FAILED (rc=`=_rc')"
        }
    }
}

* =============================================================================
* TEST 30: Error - too many by levels
* =============================================================================
local ++test_count
local test_desc "Error: by() > 8 levels (rc=198)"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    _make_panel_data 50 10 12345
    capture {
        capture noisily spaghetti sdmt, id(patid) time(months) by(patid)
        assert _rc == 198
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "RESULT: pass `test_count' `test_desc'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "RESULT: fail `test_count' `test_desc' rc=`=_rc'"
        }
        else {
            display as error "  FAILED (rc=`=_rc')"
        }
    }
}

* =============================================================================
* TEST 31: Error - colorby + by mutual exclusion
* =============================================================================
local ++test_count
local test_desc "Error: colorby() + by() (rc=198)"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    _make_panel_data 50 10 12345
    capture {
        capture noisily spaghetti sdmt, id(patid) time(months) ///
            by(treatment) colorby(center)
        assert _rc == 198
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "RESULT: pass `test_count' `test_desc'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "RESULT: fail `test_count' `test_desc' rc=`=_rc'"
        }
        else {
            display as error "  FAILED (rc=`=_rc')"
        }
    }
}

* =============================================================================
* TEST 32: Error - colorby + highlight
* =============================================================================
local ++test_count
local test_desc "Error: colorby() + highlight() (rc=198)"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    _make_panel_data 50 10 12345
    capture {
        capture noisily spaghetti sdmt, id(patid) time(months) ///
            colorby(center) highlight(patid==1)
        assert _rc == 198
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "RESULT: pass `test_count' `test_desc'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "RESULT: fail `test_count' `test_desc' rc=`=_rc'"
        }
        else {
            display as error "  FAILED (rc=`=_rc')"
        }
    }
}

* =============================================================================
* TEST 33: Error - invalid smooth
* =============================================================================
local ++test_count
local test_desc "Error: invalid smooth option (rc=198)"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    _make_panel_data 50 10 12345
    capture {
        capture noisily spaghetti sdmt, id(patid) time(months) ///
            mean(bold smooth(cubic))
        assert _rc == 198
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "RESULT: pass `test_count' `test_desc'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "RESULT: fail `test_count' `test_desc' rc=`=_rc'"
        }
        else {
            display as error "  FAILED (rc=`=_rc')"
        }
    }
}

* =============================================================================
* TEST 34: Edge - single individual
* =============================================================================
local ++test_count
local test_desc "Edge: single individual"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    _make_panel_data 50 10 12345
    quietly keep if patid == 1
    capture {
        spaghetti sdmt, id(patid) time(months)
        assert r(n_ids) == 1
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "RESULT: pass `test_count' `test_desc'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "RESULT: fail `test_count' `test_desc' rc=`=_rc'"
        }
        else {
            display as error "  FAILED (rc=`=_rc')"
        }
    }
}

* =============================================================================
* TEST 35: Edge - single timepoint
* =============================================================================
local ++test_count
local test_desc "Edge: single timepoint"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    _make_panel_data 50 10 12345
    quietly keep if months == 0
    capture {
        spaghetti sdmt, id(patid) time(months) by(treatment)
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "RESULT: pass `test_count' `test_desc'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "RESULT: fail `test_count' `test_desc' rc=`=_rc'"
        }
        else {
            display as error "  FAILED (rc=`=_rc')"
        }
    }
}

* =============================================================================
* TEST 36: if/in subsetting
* =============================================================================
local ++test_count
local test_desc "if/in subsetting"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    _make_panel_data 50 10 12345
    capture {
        spaghetti sdmt if treatment == 0, id(patid) time(months)
        assert r(n_ids) == 25
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "RESULT: pass `test_count' `test_desc'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "RESULT: fail `test_count' `test_desc' rc=`=_rc'"
        }
        else {
            display as error "  FAILED (rc=`=_rc')"
        }
    }
}

* =============================================================================
* TEST 37: Data preservation
* =============================================================================
local ++test_count
local test_desc "Data preserved after full pipeline"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    _make_panel_data 50 10 12345
    local N_before = _N
    capture {
        spaghetti sdmt, id(patid) time(months) by(treatment) ///
            mean(bold ci) sample(20) seed(42)
        assert _N == `N_before'
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "RESULT: pass `test_count' `test_desc'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "RESULT: fail `test_count' `test_desc' rc=`=_rc'"
        }
        else {
            display as error "  FAILED (rc=`=_rc')"
        }
    }
}

* =============================================================================
* TEST 38: varabbrev restored after error
* =============================================================================
local ++test_count
local test_desc "varabbrev restored after error"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    _make_panel_data 50 10 12345
    local va_before = c(varabbrev)
    capture noisily spaghetti sdmt if patid > 999, id(patid) time(months)
    capture {
        assert "`va_before'" == c(varabbrev)
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "RESULT: pass `test_count' `test_desc'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "RESULT: fail `test_count' `test_desc' rc=`=_rc'"
        }
        else {
            display as error "  FAILED (rc=`=_rc')"
        }
    }
}

* =============================================================================
* TEST 39: No variables left behind
* =============================================================================
local ++test_count
local test_desc "No variables left behind"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    _make_panel_data 50 10 12345
    describe, short
    local pre_vars = r(k)
    capture {
        spaghetti sdmt, id(patid) time(months) by(treatment) mean(bold ci)
        describe, short
        assert r(k) == `pre_vars'
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "RESULT: pass `test_count' `test_desc'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "RESULT: fail `test_count' `test_desc' rc=`=_rc'"
        }
        else {
            display as error "  FAILED (rc=`=_rc')"
        }
    }
}

* =============================================================================
* TEST 40: highlight + mean + by combined
* =============================================================================
local ++test_count
local test_desc "highlight + mean + by combined"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    _make_panel_data 50 10 12345
    capture {
        spaghetti sdmt, id(patid) time(months) by(treatment) ///
            highlight(patid==1 | patid==26) mean(bold ci)
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "RESULT: pass `test_count' `test_desc'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "RESULT: fail `test_count' `test_desc' rc=`=_rc'"
        }
        else {
            display as error "  FAILED (rc=`=_rc')"
        }
    }
}

* =============================================================================
* TEST 41: plotregion()
* =============================================================================
local ++test_count
local test_desc "plotregion() option"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    _make_panel_data 50 10 12345
    capture {
        spaghetti sdmt, id(patid) time(months) ///
            plotregion(margin(small))
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "RESULT: pass `test_count' `test_desc'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "RESULT: fail `test_count' `test_desc' rc=`=_rc'"
        }
        else {
            display as error "  FAILED (rc=`=_rc')"
        }
    }
}

* =============================================================================
* TEST 42: graphregion()
* =============================================================================
local ++test_count
local test_desc "graphregion() option"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    _make_panel_data 50 10 12345
    capture {
        spaghetti sdmt, id(patid) time(months) ///
            graphregion(color(white))
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "RESULT: pass `test_count' `test_desc'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "RESULT: fail `test_count' `test_desc' rc=`=_rc'"
        }
        else {
            display as error "  FAILED (rc=`=_rc')"
        }
    }
}

* =============================================================================
* TEST 43: name()
* =============================================================================
local ++test_count
local test_desc "name() option"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    _make_panel_data 50 10 12345
    capture {
        spaghetti sdmt, id(patid) time(months) name(test_graph)
        graph drop test_graph
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "RESULT: pass `test_count' `test_desc'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "RESULT: fail `test_count' `test_desc' rc=`=_rc'"
        }
        else {
            display as error "  FAILED (rc=`=_rc')"
        }
    }
}

* =============================================================================
* TEST 44: saving()
* =============================================================================
local ++test_count
local test_desc "saving() option"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    _make_panel_data 50 10 12345
    local save_file "/tmp/spaghetti_test_save.gph"
    capture erase "`save_file'"
    capture {
        spaghetti sdmt, id(patid) time(months) ///
            saving(`save_file', replace)
        confirm file "`save_file'"
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "RESULT: pass `test_count' `test_desc'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "RESULT: fail `test_count' `test_desc' rc=`=_rc'"
        }
        else {
            display as error "  FAILED (rc=`=_rc')"
        }
    }
    capture erase "`save_file'"
}

* =============================================================================
* TEST 45: name(, replace) passthrough
* =============================================================================
local ++test_count
local test_desc "name(, replace) does not double-replace"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    _make_panel_data 50 10 12345
    capture {
        spaghetti sdmt, id(patid) time(months) name(test_gr2, replace)
        spaghetti sdmt, id(patid) time(months) name(test_gr2, replace)
        graph drop test_gr2
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "RESULT: pass `test_count' `test_desc'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "RESULT: fail `test_count' `test_desc' rc=`=_rc'"
        }
        else {
            display as error "  FAILED (rc=`=_rc')"
        }
    }
}

* =============================================================================
* TEST 46: highlight with bgopacity()
* =============================================================================
local ++test_count
local test_desc "highlight bgopacity() sub-option"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    _make_panel_data 50 10 12345
    capture {
        spaghetti sdmt, id(patid) time(months) ///
            highlight(patid==1 | patid==5 bgopacity(10))
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "RESULT: pass `test_count' `test_desc'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "RESULT: fail `test_count' `test_desc' rc=`=_rc'"
        }
        else {
            display as error "  FAILED (rc=`=_rc')"
        }
    }
}

* =============================================================================
* TEST 47: mean(ci) without bold
* =============================================================================
local ++test_count
local test_desc "mean(ci) without bold"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    _make_panel_data 50 10 12345
    capture {
        spaghetti sdmt, id(patid) time(months) mean(ci)
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "RESULT: pass `test_count' `test_desc'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "RESULT: fail `test_count' `test_desc' rc=`=_rc'"
        }
        else {
            display as error "  FAILED (rc=`=_rc')"
        }
    }
}

* =============================================================================
* TEST 48: full pipeline (all major options combined)
* =============================================================================
local ++test_count
local test_desc "Full pipeline: sample + mean + by + highlight + refline"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    _make_panel_data 50 10 12345
    capture {
        spaghetti sdmt, id(patid) time(months) by(treatment) ///
            sample(30) seed(42) mean(bold ci) ///
            highlight(patid==1 | patid==26 bgopacity(15)) ///
            refline(5, label("Midpoint") style(dash)) ///
            individual(color(gs10) opacity(20) lwidth(vthin)) ///
            title("Full Pipeline Test") ///
            ytitle("Score") xtitle("Time")
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "RESULT: pass `test_count' `test_desc'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "RESULT: fail `test_count' `test_desc' rc=`=_rc'"
        }
        else {
            display as error "  FAILED (rc=`=_rc')"
        }
    }
}

* =============================================================================
* TEST 49: colorby with few unique values (edge case)
* =============================================================================
local ++test_count
local test_desc "Edge: colorby with < 5 unique values"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    _make_panel_data 50 10 12345
    * treatment has only 2 unique values
    capture {
        spaghetti sdmt, id(patid) time(months) colorby(treatment)
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "RESULT: pass `test_count' `test_desc'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "RESULT: fail `test_count' `test_desc' rc=`=_rc'"
        }
        else {
            display as error "  FAILED (rc=`=_rc')"
        }
    }
}

* =============================================================================
* TEST 50: passthrough twoway options
* =============================================================================
local ++test_count
local test_desc "Passthrough twoway options (ylabel, xlabel)"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    _make_panel_data 50 10 12345
    capture {
        spaghetti sdmt, id(patid) time(months) ///
            ylabel(30(10)70) xlabel(0(2)10)
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "RESULT: pass `test_count' `test_desc'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "RESULT: fail `test_count' `test_desc' rc=`=_rc'"
        }
        else {
            display as error "  FAILED (rc=`=_rc')"
        }
    }
}

* =============================================================================
* SUMMARY
* =============================================================================
display as text _n "{hline 70}"
display as text "RESULTS: " ///
    as result "`pass_count'" as text " passed, " ///
    as result "`fail_count'" as text " failed, " ///
    as result "`test_count'" as text " total"

if `fail_count' > 0 {
    display as error "FAILED TESTS:`failed_tests'"
}
else {
    display as result "ALL TESTS PASSED"
}
display as text "{hline 70}"

if `fail_count' > 0 {
    exit 9
}
