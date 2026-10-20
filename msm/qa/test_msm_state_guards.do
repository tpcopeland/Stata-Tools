* test_msm_state_guards.do
* Focused regressions for hard pipeline-state guards.

version 16.0
clear all
set more off
set varabbrev off

local qa_dir "`c(pwd)'"
local pkg_dir "`qa_dir'/.."

capture log close _all
log using "test_msm_state_guards.log", replace text nomsg

do "`qa_dir'/_install_msm_isolated.do" "`pkg_dir'"
do "`qa_dir'/_msm_qa_common.do"

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
**## Tampering with the estimation sample is refused before predicting
*
* CONTRACT CHANGE (Phase 1, audit A02). This probe used to empty the reference
* population by `replace _msm_esample = 0', and required msm_predict's
* empty-reference guard to fire with r(2000).
*
* The fit signature now covers the exact estimation sample -- the audit
* requires it ("fitting: weighting signature plus outcome-model inputs and
* exact e(sample)") -- so editing _msm_esample invalidates the fit and
* msm_predict refuses at r(459) BEFORE it ever computes a reference
* population. Editing e(sample) under a fitted model silently repoints every
* downstream prediction, which is the contamination class this rework exists
* to close; refusing earlier is the stronger behaviour.
*
* What this probe now asserts: the tamper is refused, and the failure commits
* no prediction state.
*
* COVERAGE GAP (recorded, not silent): msm_predict's own empty-reference guard
* (r 2000) is no longer reachable by tampering, and needs a data-driven
* trigger. Phase 4 owns fitted risk-set period support and must supply one.
local ++test_count
capture noisily {
    _guard_setup_fitted
    quietly summarize period, meanonly
    local min_period = r(min)

    replace _msm_esample = 0 if period == `min_period'
    matrix _msm_pred_matrix = J(1, 1, 1)
    char _dta[_msm_pred_saved] "1"

    set varabbrev on
    * nullcase: msm_predict
    capture msm_predict, times(`min_period') samples(10) seed(90210)
    local pred_rc = _rc

    assert `pred_rc' == 459
    assert c(varabbrev) == "on"
    assert "`: char _dta[_msm_pred_type]'" == ""
    assert "`: char _dta[_msm_pred_strategy]'" == ""
    assert "`: char _dta[_msm_pred_level]'" == ""
    set varabbrev off
}
if _rc == 0 {
    display as result "PASS SG1: msm_predict refuses a tampered estimation sample"
    local ++pass_count
}
else {
    display as error "FAIL SG1: msm_predict esample tamper guard (rc=`=_rc')"
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

    assert `weight_rc' == 459
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
**## No treatment variation is refused by msm_weight (formerly msm_validate)
local ++test_count
capture noisily {
    clear
    set obs 40
    gen long id = ceil(_n / 2)
    bysort id: gen byte period = _n - 1
    gen byte treatment = 1
    gen byte outcome = 0

    msm_prepare, id(id) period(period) treatment(treatment) outcome(outcome)

    gen double x = id
    msm_prepare, id(id) period(period) treatment(treatment) outcome(outcome) covariates(x)
    set varabbrev on
    capture noisily msm_weight, treat_d_cov(x) nolog
    local weight_rc = _rc

    assert `weight_rc' == 498
    assert c(varabbrev) == "on"
    assert "`: char _dta[_msm_weighted]'" == ""
    set varabbrev off
}
if _rc == 0 {
    display as result "PASS SG3: msm_weight refuses no treatment variation"
    local ++pass_count
}
else {
    display as error "FAIL SG3: no-variation refusal (rc=`=_rc')"
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

    * SG4 checks varabbrev restoration, so the guards below must SUCCEED --
    * their error paths are covered elsewhere. That needs genuine weighted and
    * fitted artifacts. Hand-setting char _dta[_msm_weighted] "1" and a bare
    * J(1,1,0) matrix (what this test used to do) produces state with no
    * identity, which the Phase 1 guards correctly refuse, so the guards would
    * error and the probe would test nothing.
    gen double _msm_weight = 1
    _msm_qa_register_weights

    tempname sg_b sg_V
    matrix `sg_b' = (0, 0)
    matrix colnames `sg_b' = treatment _cons
    matrix `sg_V' = J(2, 2, 0)
    _msm_qa_register_fit, b(`sg_b') v(`sg_V')
    char _dta[_msm_model] "logistic"
    char _dta[_msm_fit_level] "95"

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
        outcome_cov(age sex) ///
        period_spec(cubic) nolog
    local fit_rc = _rc
    set maxiter `old_maxiter'

    assert `fit_rc' == 430
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

**# State Inventory
**## Downstream commands write no dataset state (msm 2.0.0)
local ++test_count
capture noisily {
    _guard_setup_fitted
    msm_predict, times(1 3 5) difference samples(10) seed(90211)
    msm_diagnose, balance_covariates(biomarker comorbidity age sex) threshold(0.1)

    assert "`: char _dta[_msm_prepared]'" == "1"
    assert "`: char _dta[_msm_weighted]'" == "1"
    assert "`: char _dta[_msm_weight_var]'" == "_msm_weight"
    assert "`: char _dta[_msm_risk_var]'" == "_msm_decision_risk"
    assert "`: char _dta[_msm_contract_version]'" == "1.1"
    assert "`: char _dta[_msm_fitted]'" == "1"
    assert "`: char _dta[_msm_model]'" == "logistic"
    assert "`: char _dta[_msm_fit_level]'" == "95"
    * msm_predict and msm_diagnose are read-only on the dataset
    foreach c in _msm_pred_saved _msm_pred_type _msm_pred_uuid _msm_pred_mat_id ///
        _msm_bal_saved _msm_bal_threshold _msm_diag_saved _msm_diag_mean ///
        _msm_sens_saved {
        assert `"`: char _dta[`c']'"' == ""
    }
    foreach m in _msm_pred_matrix _msm_bal_matrix _msm_tbal_matrix ///
        _msm_support_matrix _msm_cbal_matrix {
        capture confirm matrix `m'
        assert _rc != 0
    }

    msm, status
    assert r(prepared) == 1
    assert r(weighted) == 1
    assert r(fitted) == 1
    assert "`r(next_step)'" == "msm_predict"
}
if _rc == 0 {
    display as result "PASS SG6: downstream commands write no dataset state"
    local ++pass_count
}
else {
    display as error "FAIL SG6: downstream state surface (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' SG6"
}

**# Summary
display as text "State-guard tests run: " as result `test_count'
display as text "Passed: " as result `pass_count'
display as text "Failed: " as result `fail_count'
do "`qa_dir'/_record_qa_result.do" test_msm_state_guards ///
    `test_count' `pass_count' `fail_count' 0
display as text "RESULT: test_msm_state_guards tests=`test_count' pass=`pass_count' fail=`fail_count' skip=0"
capture log close _all
if `fail_count' > 0 {
    display as error "Failed tests:`failed_tests'"
    exit 459
}
display as result "All msm state-guard tests passed"
