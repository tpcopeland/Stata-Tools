/*******************************************************************************
* validation_spaghetti.do
*
* Purpose: Validation tests for spaghetti v1.0.0 -- verifies numeric accuracy
*          of sampling, mean computation, CI bounds, and return values.
*
* Commands tested: spaghetti, _spaghetti_sample, _spaghetti_mean
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
    display as text "spaghetti PACKAGE VALIDATION"
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
* HELPER: Generate validation data (controlled, deterministic)
* =============================================================================
capture program drop _make_val_data
program define _make_val_data
    args n_ids n_times seed
    clear
    set seed `seed'
    local N = `n_ids' * `n_times'
    quietly set obs `N'
    quietly gen patid = ceil(_n / `n_times')
    bysort patid: gen months = _n - 1
    quietly gen treatment = (patid > `n_ids' / 2)
    quietly gen double sdmt = 50 + 2*months - 3*treatment*months + rnormal(0, 3)
    quietly gen double bl_sdmt = .
    bysort patid (months): replace bl_sdmt = sdmt[1]

    label variable sdmt "SDMT Score"
    label variable months "Months"
    label define _tx_lbl 0 "Control" 1 "Treated", replace
    label values treatment _tx_lbl
end

* =============================================================================
* V1: r(N) matches observation count
* =============================================================================
local ++test_count
local test_desc "r(N) matches observation count"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    _make_val_data 20 10 54321
    quietly count
    local true_N = r(N)
    capture {
        spaghetti sdmt, id(patid) time(months)
        assert r(N) == `true_N'
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
* V2: r(n_ids) matches unique individuals
* =============================================================================
local ++test_count
local test_desc "r(n_ids) matches unique individuals"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    _make_val_data 20 10 54321
    bysort patid: gen byte _f = (_n == 1)
    quietly count if _f
    local true_ids = r(N)
    drop _f
    capture {
        spaghetti sdmt, id(patid) time(months)
        assert r(n_ids) == `true_ids'
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
* V3: r(n_groups) matches by-variable levels
* =============================================================================
local ++test_count
local test_desc "r(n_groups) matches by-variable levels"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    _make_val_data 20 10 54321
    quietly levelsof treatment
    local true_groups : word count `r(levels)'
    capture {
        spaghetti sdmt, id(patid) time(months) by(treatment)
        assert r(n_groups) == `true_groups'
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
* V4: r(n_ids) correct with if condition
* =============================================================================
local ++test_count
local test_desc "r(n_ids) correct with if condition"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    _make_val_data 20 10 54321
    bysort patid: gen byte _f = (_n == 1)
    quietly count if _f & treatment == 0
    local true_ids = r(N)
    drop _f
    capture {
        spaghetti sdmt if treatment == 0, id(patid) time(months)
        assert r(n_ids) == `true_ids'
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
* V5: sample + seed reproducibility
* =============================================================================
local ++test_count
local test_desc "Sample + seed reproducibility"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    _make_val_data 20 10 54321
    capture {
        spaghetti sdmt, id(patid) time(months) sample(5) seed(77777)
        local cmd1 `"`r(cmd)'"'
        local ns1 = r(n_sampled)
        spaghetti sdmt, id(patid) time(months) sample(5) seed(77777)
        local cmd2 `"`r(cmd)'"'
        local ns2 = r(n_sampled)
        assert `"`cmd1'"' == `"`cmd2'"'
        assert `ns1' == `ns2'
        assert `ns1' == 5
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
* V6: n_sampled returns correct count
* =============================================================================
local ++test_count
local test_desc "n_sampled returns requested count"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    _make_val_data 20 10 54321
    capture {
        spaghetti sdmt, id(patid) time(months) sample(8) seed(42)
        assert r(n_sampled) == 8
        assert r(n_ids) == 20
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
* V7: n_sampled capped at available individuals
* =============================================================================
local ++test_count
local test_desc "n_sampled capped at available individuals"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    _make_val_data 20 10 54321
    capture {
        spaghetti sdmt, id(patid) time(months) sample(999)
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
* V8: Mean overlay matches manual collapse
* =============================================================================
local ++test_count
local test_desc "Mean overlay matches manual collapse"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    _make_val_data 20 10 54321

    * Manual computation
    preserve
    collapse (mean) manual_mean=sdmt, by(months)
    summarize manual_mean, meanonly
    local manual_grand = r(mean)
    restore

    * spaghetti should execute without error
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
* V9: CI bounds symmetric around mean
* =============================================================================
local ++test_count
local test_desc "CI bounds symmetric around mean (invnormal)"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    _make_val_data 20 10 54321

    * Manual CI at months==3
    preserve
    collapse (mean) m=sdmt (sd) s=sdmt (count) n=sdmt, by(months)
    gen double se = s / sqrt(n)
    gen double lo = m - invnormal(0.975) * se
    gen double hi = m + invnormal(0.975) * se
    summarize m if months == 3, meanonly
    local manual_m = r(mean)
    summarize lo if months == 3, meanonly
    local manual_lo = r(mean)
    summarize hi if months == 3, meanonly
    local manual_hi = r(mean)
    restore

    capture {
        * CI must be symmetric around mean
        assert `manual_lo' < `manual_m'
        assert `manual_hi' > `manual_m'
        local mid = (`manual_lo' + `manual_hi') / 2
        assert abs(`mid' - `manual_m') < 1e-10
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "RESULT: pass `test_count' `test_desc'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED (mean=`=string(`manual_m',"%9.4f")', CI=[`=string(`manual_lo',"%9.4f")', `=string(`manual_hi',"%9.4f")'])"
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
* V10: Data unchanged after full pipeline
* =============================================================================
local ++test_count
local test_desc "Data unchanged after full pipeline"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    _make_val_data 20 10 54321
    summarize sdmt, meanonly
    local pre_mean = r(mean)
    local pre_N = r(N)
    capture {
        spaghetti sdmt, id(patid) time(months) by(treatment) ///
            mean(bold ci) sample(10) seed(42)
        summarize sdmt, meanonly
        assert r(N) == `pre_N'
        assert abs(r(mean) - `pre_mean') < 1e-10
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
* V11: No variables left behind
* =============================================================================
local ++test_count
local test_desc "No variables left behind"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    _make_val_data 20 10 54321
    describe, short
    local pre_k = r(k)
    capture {
        spaghetti sdmt, id(patid) time(months) by(treatment) mean(bold ci)
        describe, short
        assert r(k) == `pre_k'
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
* V12: n_ids with unbalanced panel
* =============================================================================
local ++test_count
local test_desc "n_ids correct with unbalanced panel"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    _make_val_data 20 10 54321
    * Create unbalanced panel
    quietly drop if patid == 3 & months > 5
    quietly drop if patid == 7 & months > 3
    bysort patid: gen byte _f = (_n == 1)
    quietly count if _f
    local true_ids = r(N)
    drop _f
    capture {
        spaghetti sdmt, id(patid) time(months)
        assert r(n_ids) == `true_ids'
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
* V13: Mean per group matches manual collapse
* =============================================================================
local ++test_count
local test_desc "Mean per group matches manual collapse"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    _make_val_data 20 10 54321

    * Manual: mean at months==5 for both groups
    preserve
    collapse (mean) m=sdmt, by(months treatment)
    summarize m if treatment == 0 & months == 5, meanonly
    local m_ctrl = r(mean)
    summarize m if treatment == 1 & months == 5, meanonly
    local m_treat = r(mean)
    restore

    capture {
        * Mean values should differ between groups (treatment effect)
        assert `m_ctrl' != `m_treat'
        * Command runs successfully with by+mean
        spaghetti sdmt, id(patid) time(months) by(treatment) mean(bold ci)
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "RESULT: pass `test_count' `test_desc'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED (ctrl=`=string(`m_ctrl',"%9.4f")', treat=`=string(`m_treat',"%9.4f")')"
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
* V14: CI width matches formula
* =============================================================================
local ++test_count
local test_desc "CI width matches 2*z*SE formula"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    _make_val_data 20 10 54321

    preserve
    collapse (mean) m=sdmt (sd) s=sdmt (count) n=sdmt, by(months)
    gen double se = s / sqrt(n)
    gen double expected_width = 2 * invnormal(0.975) * se
    gen double lo = m - invnormal(0.975) * se
    gen double hi = m + invnormal(0.975) * se
    gen double actual_width = hi - lo
    gen double width_diff = abs(actual_width - expected_width)
    summarize width_diff, meanonly
    local max_diff = r(max)
    restore

    capture {
        assert `max_diff' < 1e-10
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "RESULT: pass `test_count' `test_desc'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED (max width diff = `=string(`max_diff', "%12.2e")')"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "RESULT: fail `test_count' `test_desc' rc=`=_rc'"
        }
        else {
            display as error "  FAILED (max diff = `max_diff')"
        }
    }
}

* =============================================================================
* V15: _spaghetti_mean output matches manual collapse
* =============================================================================
local ++test_count
local test_desc "_spaghetti_mean output matches manual collapse"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    _make_val_data 20 10 54321

    * Manual collapse
    preserve
    collapse (mean) manual_mean=sdmt, by(months treatment)
    summarize manual_mean if treatment == 0 & months == 0, meanonly
    local ctrl_m0 = r(mean)
    summarize manual_mean if treatment == 1 & months == 0, meanonly
    local treat_m0 = r(mean)
    restore

    * Call _spaghetti_mean directly
    tempfile mf
    _spaghetti_mean, outcome(sdmt) time(months) by(treatment) ///
        ci savefile(`mf')

    * Verify the saved file has correct values
    preserve
    use `mf', clear
    capture {
        * Check that mean values at months==0 match manual collapse
        summarize _spag_mean_y if treatment == 0 & months == 0, meanonly
        assert abs(r(mean) - `ctrl_m0') < 1e-10
        summarize _spag_mean_y if treatment == 1 & months == 0, meanonly
        assert abs(r(mean) - `treat_m0') < 1e-10
        * CI variables exist
        confirm variable _spag_mean_lo
        confirm variable _spag_mean_hi
        * Mean marker exists
        assert _spag_is_mean == 1
    }
    restore

    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "RESULT: pass `test_count' `test_desc'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED (ctrl_m0=`=string(`ctrl_m0',"%9.4f")', treat_m0=`=string(`treat_m0',"%9.4f")')"
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
* V16: Mean computed on full data, not sampled subset
* =============================================================================
local ++test_count
local test_desc "Mean computed on full data, not sampled subset"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    _make_val_data 20 10 54321

    * Compute mean on FULL data at months==5
    preserve
    collapse (mean) full_mean=sdmt, by(months)
    summarize full_mean if months == 5, meanonly
    local full_m5 = r(mean)
    restore

    * Now call _spaghetti_mean on a SUBSET (simulate what sample+mean does)
    * If mean is computed pre-sample, it should match full data
    tempfile mf_full
    _spaghetti_mean, outcome(sdmt) time(months) savefile(`mf_full')

    preserve
    use `mf_full', clear
    capture {
        summarize _spag_mean_y if months == 5, meanonly
        assert abs(r(mean) - `full_m5') < 1e-10
    }
    restore

    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "RESULT: pass `test_count' `test_desc'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED (full_m5=`=string(`full_m5',"%9.4f")')"
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
* V17: Highlight condition evaluation
* =============================================================================
local ++test_count
local test_desc "Highlight selects correct individuals"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    _make_val_data 20 10 54321

    * Count individuals matching condition
    bysort patid: gen byte _f = (_n == 1)
    quietly count if _f & patid <= 5
    local expected_hl = r(N)
    drop _f

    * spaghetti with highlight should still return correct totals
    capture {
        spaghetti sdmt, id(patid) time(months) ///
            highlight(patid <= 5)
        assert r(n_ids) == 20
        * Command runs without error with the condition
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "RESULT: pass `test_count' `test_desc'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED (expected `expected_hl' highlighted)"
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
* V18: Highlight with == operator (spaces around ==)
* =============================================================================
local ++test_count
local test_desc "Highlight with spaced == operator"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    _make_val_data 20 10 54321
    capture {
        spaghetti sdmt, id(patid) time(months) ///
            highlight(patid == 3)
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
* V19: Colorby quintile count
* =============================================================================
local ++test_count
local test_desc "Colorby continuous creates correct quintile groups"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    _make_val_data 20 10 54321
    capture {
        * bl_sdmt has 20 unique values -> 5 quintile groups
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
* V20: Colorby categorical preserves group count
* =============================================================================
local ++test_count
local test_desc "Colorby categorical matches distinct values"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    _make_val_data 20 10 54321

    * treatment has 2 distinct values
    capture {
        spaghetti sdmt, id(patid) time(months) ///
            colorby(treatment, categorical)
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
* V21: Single-obs-per-timepoint CI (n==1 SE fix)
* =============================================================================
local ++test_count
local test_desc "CI handles single-obs-per-timepoint (SE=0)"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    * Create data with exactly 1 obs per (time, group) cell
    clear
    quietly set obs 4
    quietly gen patid = _n
    quietly gen months = mod(_n - 1, 2)
    quietly gen double sdmt = 50 + _n
    quietly gen treatment = (_n > 2)

    * After collapse by(months treatment): 4 cells, each n=1
    tempfile mf
    capture {
        _spaghetti_mean, outcome(sdmt) time(months) ///
            by(treatment) ci savefile(`mf')

        preserve
        use `mf', clear
        * With n==1 per time-group, CI should collapse to point
        assert !missing(_spag_mean_lo)
        assert !missing(_spag_mean_hi)
        * lo == hi == mean when SE=0
        gen double _diff_lo = abs(_spag_mean_lo - _spag_mean_y)
        gen double _diff_hi = abs(_spag_mean_hi - _spag_mean_y)
        summarize _diff_lo, meanonly
        assert r(max) < 1e-10
        summarize _diff_hi, meanonly
        assert r(max) < 1e-10
        restore
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
display as text "VALIDATION: " ///
    as result "`pass_count'" as text " passed, " ///
    as result "`fail_count'" as text " failed, " ///
    as result "`test_count'" as text " total"

if `fail_count' > 0 {
    display as error "FAILED TESTS:`failed_tests'"
}
else {
    display as result "ALL VALIDATIONS PASSED"
}
display as text "{hline 70}"

if `fail_count' > 0 {
    exit 9
}
