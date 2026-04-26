* test_msm_state_guards.do
* Focused regressions for hard pipeline-state guards.

version 16.0
clear all
set more off
set varabbrev off

local qa_dir "`c(pwd)'"
local pkg_dir "`qa_dir'/.."

do "`qa_dir'/_install_msm_isolated.do" "`pkg_dir'"

local pass_count = 0
local fail_count = 0
local test_count = 0
local failed_tests ""

capture program drop _guard_setup_weighted
program define _guard_setup_weighted
    version 16.0

    local qa_dir "`c(pwd)'"
    local pkg_dir "`qa_dir'/.."

    use "`pkg_dir'/msm_example.dta", clear
    msm_prepare, id(id) period(period) treatment(treatment) ///
        outcome(outcome) censor(censored) ///
        covariates(biomarker comorbidity) ///
        baseline_covariates(age sex)
    msm_weight, treat_d_cov(biomarker comorbidity age sex) ///
        treat_n_cov(age sex) nolog
end

capture program drop _guard_setup_fitted
program define _guard_setup_fitted
    version 16.0

    _guard_setup_weighted
    msm_fit, model(logistic) outcome_cov(age sex) nolog
end

**# Prediction Guards
**## Empty fitted reference population fails before saving predictions
local ++test_count
capture noisily {
    _guard_setup_fitted
    quietly summarize period, meanonly
    local min_period = r(min)

    replace _msm_esample = 0 if period == `min_period'
    matrix _msm_pred_matrix = J(1, 1, 1)
    char _dta[_msm_pred_saved] "1"

    set varabbrev on
    capture msm_predict, times(`min_period') samples(10) seed(90210)
    local pred_rc = _rc

    assert `pred_rc' == 2000
    assert c(varabbrev) == "on"
    assert "`: char _dta[_msm_pred_saved]'" == ""
    capture matrix list _msm_pred_matrix
    assert _rc != 0
    set varabbrev off
}
if _rc == 0 {
    display as result "PASS SG1: msm_predict rejects empty reference population"
    local ++pass_count
}
else {
    display as error "FAIL SG1: msm_predict empty reference guard (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' SG1"
    set varabbrev off
}

**# Weight Guards
**## All-missing model probabilities fail before weighted state is set
local ++test_count
capture noisily {
    clear
    set obs 80
    gen long id = ceil(_n / 4)
    bysort id: gen byte period = _n - 1
    gen byte treatment = mod(id + period, 2)
    gen byte outcome = 0
    gen double L = .

    msm_prepare, id(id) period(period) treatment(treatment) ///
        outcome(outcome) covariates(L)

    capture msm_weight, treat_d_cov(L) fitfailure(marginal) nolog
    local weight_rc = _rc

    assert `weight_rc' == 2000
    assert "`: char _dta[_msm_weighted]'" == ""
    capture confirm variable _msm_weight
    assert _rc != 0
    capture confirm variable _msm_tw_weight
    assert _rc != 0
}
if _rc == 0 {
    display as result "PASS SG2: msm_weight rejects all-missing weights"
    local ++pass_count
}
else {
    display as error "FAIL SG2: msm_weight missing-probability guard (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' SG2"
}

**# Validation Guards
**## Hard validation errors fail without strict
local ++test_count
capture noisily {
    clear
    set obs 40
    gen long id = ceil(_n / 2)
    bysort id: gen byte period = _n - 1
    gen byte treatment = 1
    gen byte outcome = 0

    msm_prepare, id(id) period(period) treatment(treatment) outcome(outcome)

    set varabbrev on
    capture msm_validate
    local validate_rc = _rc

    assert `validate_rc' == 198
    assert c(varabbrev) == "on"
    set varabbrev off
}
if _rc == 0 {
    display as result "PASS SG3: msm_validate errors fail without strict"
    local ++pass_count
}
else {
    display as error "FAIL SG3: msm_validate hard-error return code (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' SG3"
    set varabbrev off
}

**# Helper State
**## Direct helper calls restore varabbrev
local ++test_count
capture noisily {
    clear
    set obs 20
    gen long id = ceil(_n / 2)
    bysort id: gen byte period = _n - 1
    gen byte treatment = mod(id, 2)
    gen byte outcome = 0
    gen double x = _n

    msm_prepare, id(id) period(period) treatment(treatment) ///
        outcome(outcome) covariates(x)

    gen double _msm_weight = 1
    char _dta[_msm_weighted] "1"
    matrix _msm_fit_b = J(1, 1, 0)
    char _dta[_msm_fitted] "1"

    set varabbrev on
    _msm_check_prepared
    assert c(varabbrev) == "on"
    _msm_get_settings
    assert c(varabbrev) == "on"
    _msm_check_weighted
    assert c(varabbrev) == "on"
    _msm_check_fitted
    assert c(varabbrev) == "on"
    _msm_natural_spline x, df(1) prefix(_sg_ns)
    assert c(varabbrev) == "on"
    _msm_smd x, treatment(treatment)
    assert c(varabbrev) == "on"
    _msm_col_letter 28
    assert c(varabbrev) == "on"
    assert "`result'" == "AB"
    set varabbrev off
}
if _rc == 0 {
    display as result "PASS SG4: direct helpers restore varabbrev"
    local ++pass_count
}
else {
    display as error "FAIL SG4: helper varabbrev restoration (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' SG4"
    set varabbrev off
}

**# Fit Guards
**## Nonconverged outcome fit does not persist fitted state
local ++test_count
capture noisily {
    _guard_setup_weighted

    local old_maxiter = c(maxiter)
    set maxiter 1
    capture msm_fit, model(logistic) ///
        outcome_cov(age sex biomarker comorbidity) ///
        period_spec(cubic) nolog
    local fit_rc = _rc
    set maxiter `old_maxiter'

    assert `fit_rc' != 0
    assert "`: char _dta[_msm_fitted]'" == ""
    capture confirm variable _msm_esample
    assert _rc != 0
}
if _rc == 0 {
    display as result "PASS SG5: nonconverged msm_fit leaves no fitted state"
    local ++pass_count
}
else {
    display as error "FAIL SG5: msm_fit nonconvergence state guard (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' SG5"
    capture set maxiter 16000
}

**# Summary
display as text "State-guard tests run: " as result `test_count'
display as text "Passed: " as result `pass_count'
display as text "Failed: " as result `fail_count'
if `fail_count' > 0 {
    display as error "Failed tests:`failed_tests'"
    exit 459
}
display as result "All msm state-guard tests passed"
