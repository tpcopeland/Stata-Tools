clear all
set more off
version 16.0
set varabbrev off

capture log close _all
tempfile test_log
log using "`test_log'", replace nomsg

local qa_dir "`c(pwd)'"
local basename = substr("`qa_dir'", strrpos("`qa_dir'", "/") + 1, .)
if "`basename'" != "qa" {
    display as error "test_iivw_diagnostic_workflow.do must be run from iivw/qa"
    log close _all
    exit 198
}
* Sysdir sandbox + path resolution (Q3/Q8): the sandbox keeps this suite's
* net install out of the USER's real ado tree even when run standalone, and
* the "/qa" suffix is stripped by length, not by first-occurrence subinstr()
* (which mangles any path whose ancestors contain "qa").
do "`qa_dir'/_iivw_qa_common.do"
iivw_qa_sandbox
local pkg_dir  "`r(pkg_dir)'"
local repo_dir "`r(repo_dir)'"

ado dir
capture ado uninstall iivw
quietly net install iivw, from("`pkg_dir'") replace
discard

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

capture program drop _workflow_panel
program define _workflow_panel
    version 16.0
    clear
    set seed 20260524
    set obs 160
    gen long id = ceil(_n / 4)
    bysort id: gen byte visit = _n
    gen double months = 3 * (visit - 1) + runiform() * 0.05
    replace months = 0 if visit == 1
    gen byte female = mod(id, 2)
    gen double age0 = 24 + mod(id, 11)
    gen double severity0 = -0.6 + 0.06 * age0 + 0.25 * female + ///
        0.15 * sin(id)
    gen byte treat = severity0 + 0.10 * female + 0.03 * age0 > 2.10
    quietly count if treat == 0
    assert r(N) > 0
    quietly count if treat == 1
    assert r(N) > 0
    gen double marker = severity0 + 0.18 * visit + 0.05 * cos(id + visit)
    gen double visit_need = severity0 + 0.12 * marker + 0.04 * visit
    gen double y = 5 + 0.45 * months - 0.70 * treat + ///
        0.55 * severity0 + 0.15 * female + 0.20 * visit_need + ///
        0.03 * sin(id * visit)
    sort id months
end

capture program drop _assert_scalar_finite
program define _assert_scalar_finite
    version 16.0
    args scalar_name
    assert scalar(`scalar_name') < .
end

**# Tests

local ++test_count
capture noisily {
    which iivw
    which iivw_weight
    which iivw_balance
    which iivw_fit
    which iivw_exogtest
    which iivw_diagnose
    iivw
    assert r(n_commands) == 5
    assert "`r(commands)'" == "iivw_weight iivw_balance iivw_fit iivw_exogtest iivw_diagnose"
}
if _rc == 0 {
    display as result "  PASS: T1 - local install exposes public commands"
    local ++pass_count
}
else {
    display as error "  FAIL: T1 - local install exposes public commands (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T1"
}

local ++test_count
capture noisily {
    estimates clear
    _workflow_panel

    iivw_fit y treat, unweighted id(id) time(months) ///
        timespec(linear) nolog
    assert e(N) == _N
    assert "`e(iivw_cmd)'" == "iivw_fit"
    assert "`e(iivw_weighttype)'" == "unweighted"
    assert "`e(iivw_unweighted)'" == "1"
    assert "`e(iivw_id)'" == "id"
    assert "`e(iivw_time)'" == "months"
    assert "`e(iivw_timespec)'" == "linear"
    assert _b[treat] < .
    assert _se[treat] < .
    assert _b[months] < .
    assert _se[months] < .
    estimates store WF_unweighted

    iivw_weight, endatlastvisit baseline(event) id(id) time(months) visit_cov(marker visit_need female) ///
        treat(treat) treat_cov(age0 severity0 female) truncfinal(1 99) nolog
    assert r(N) == _N
    assert r(n_ids) == 40
    assert "`r(weighttype)'" == "fiptiw"
    assert "`r(weight_var)'" == "_iivw_weight"
    assert r(mean_weight) > 0
    assert r(min_weight) > 0
    assert r(max_weight) < .
    assert r(ess) > 0
    assert r(ess) <= r(N)
    assert r(n_truncated) >= 0
    confirm variable _iivw_iw
    confirm variable _iivw_tw
    confirm variable _iivw_weight
    quietly count if missing(_iivw_weight) | _iivw_weight <= 0 | _iivw_weight >= .
    assert r(N) == 0
    assert "`: char _dta[_iivw_weighted]'" == "1"
    assert "`: char _dta[_iivw_weighttype]'" == "fiptiw"
    assert "`: char _dta[_iivw_weight_var]'" == "_iivw_weight"

    iivw_fit y treat, vce(fixed) timespec(linear) nolog
    assert e(N) == _N
    assert "`e(iivw_cmd)'" == "iivw_fit"
    assert "`e(iivw_weighttype)'" == "fiptiw"
    assert "`e(iivw_unweighted)'" == "0"
    assert "`e(iivw_weight_var)'" == "_iivw_weight"
    assert _b[treat] < .
    assert _se[treat] < .
    assert _b[months] < .
    assert _se[months] < .
    estimates store WF_weighted

    iivw_fit y treat marker visit_need, vce(fixed) timespec(linear) nolog
    assert e(N) == _N
    assert "`e(iivw_weighttype)'" == "fiptiw"
    assert "`e(iivw_timespec)'" == "linear"
    assert _b[treat] < .
    assert _se[treat] < .
    assert _b[months] < .
    assert _se[months] < .
    assert _b[marker] < .
    estimates store WF_adjusted

    iivw_exogtest y marker, endatlastvisit id(id) time(months) adjust(age0 female treat) ///
        level(90) nolog
    assert r(N) == 120
    assert r(n_ids) == 40
    assert r(n_models) == 1
    assert r(n_skipped) == 0
    assert r(alpha) == 0.10
    assert inlist(r(endogenous_flag), 0, 1)
    assert "`r(id)'" == "id"
    assert "`r(time)'" == "months"
    assert "`r(testvars)'" == "y marker"
    matrix EX = r(results)
    assert rowsof(EX) == 2
    assert colsof(EX) == 11
    assert EX[1,6] >= 0 & EX[1,6] <= 1
    assert EX[2,6] >= 0 & EX[2,6] <= 1
    assert EX[1,7] > 0 & EX[1,7] < .
    assert EX[2,7] > 0 & EX[2,7] < .
    confirm variable _iivw_exog_y_lag1
    confirm variable _iivw_exog_marker_lag1

    iivw_diagnose months, unweighted(WF_unweighted) weighted(WF_weighted) ///
        adjusted(WF_adjusted) exogeneity(unknown)
    assert "`r(coefficient)'" == "months"
    assert "`r(unweighted)'" == "WF_unweighted"
    assert "`r(weighted)'" == "WF_weighted"
    assert "`r(adjusted)'" == "WF_adjusted"
    assert "`r(estimand)'" == "marginal"
    assert "`r(exogeneity)'" == "unknown"
    assert inlist("`r(conclusion)'", "descriptive", "unstable", ///
        "sign_inconsistent")
    matrix DIAG = r(estimates)
    matrix DDEC = r(decomp)
    assert rowsof(DIAG) == 3
    assert colsof(DIAG) == 4
    * estimate b (col 1) and se (col 2) finite for all three model rows
    forvalues i = 1/3 {
        scalar _check = DIAG[`i',1]
        _assert_scalar_finite _check
        scalar _check = DIAG[`i',2]
        _assert_scalar_finite _check
    }
    * sampling/artifact/total gaps finite (r(decomp) rows 1-3)
    forvalues i = 1/3 {
        scalar _check = DDEC[`i',1]
        _assert_scalar_finite _check
    }
}
if _rc == 0 {
    display as result "  PASS: T2 - installed-user diagnostic workflow"
    local ++pass_count
}
else {
    display as error "  FAIL: T2 - installed-user diagnostic workflow (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T2"
}

local ++test_count
capture noisily {
    _workflow_panel
    capture noisily iivw_fit y treat, vce(fixed) timespec(linear) nolog
    assert _rc == 198
    capture confirm variable _iivw_weight
    assert _rc == 111
}
if _rc == 0 {
    display as result "  PASS: T3 - weighted fit before weighting is rejected"
    local ++pass_count
}
else {
    display as error "  FAIL: T3 - weighted fit before weighting is rejected (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T3"
}

local ++test_count
capture noisily {
    _workflow_panel
    replace months = months[1] in 2
    capture noisily iivw_weight, endatlastvisit baseline(event) id(id) time(months) ///
        visit_cov(marker visit_need female) nolog
    assert _rc == 198
    capture confirm variable _iivw_weight
    assert _rc == 111
}
if _rc == 0 {
    display as result "  PASS: T4 - duplicate id-time workflow is rejected cleanly"
    local ++pass_count
}
else {
    display as error "  FAIL: T4 - duplicate id-time workflow is rejected cleanly (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T4"
}

**# Summary

display as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED: `failed_tests'"
    display "RESULT: test_iivw_diagnostic_workflow tests=`test_count' pass=`pass_count' fail=`fail_count'"
    log close _all
    exit 1
}

display as result "ALL TESTS PASSED"
display "RESULT: test_iivw_diagnostic_workflow tests=`test_count' pass=`pass_count' fail=`fail_count'"
log close _all
