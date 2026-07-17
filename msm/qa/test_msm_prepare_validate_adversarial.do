* test_msm_prepare_validate_adversarial.do
* Focused adversarial QA for msm dispatcher, prepare, validate, and state helpers.

version 16.0
clear all
set more off
set varabbrev off

local qa_dir "`c(pwd)'"
local pkg_dir "`qa_dir'/.."

do "`qa_dir'/_install_msm_isolated.do" "`pkg_dir'"
do "`qa_dir'/_msm_qa_common.do"

local pass_count = 0
local fail_count = 0
local test_count = 0
local failed_tests ""

capture program drop _adv_make_clean_panel
program define _adv_make_clean_panel
    version 16.0
    syntax [, NIDS(integer 12) PERIODS(integer 3)]

    clear
    set obs `=`nids' * `periods''
    gen long id = ceil(_n / `periods')
    bysort id: gen int period = _n - 1
    gen byte treatment = mod(id + period, 2)
    gen byte outcome = 0
    gen byte censored = 0
    gen double x = id + period / 10
    gen double bl = id
end

**# Prepare And Validate Preservation
**## PV1: msm_prepare preserves physical observation order and return contract
local ++test_count
capture noisily {
    _adv_make_clean_panel
    set seed 91001
    gen double shuffle = runiform()
    sort shuffle
    gen long row_before = _n

    set varabbrev on
    msm_prepare, id(id) period(period) treatment(treatment) ///
        outcome(outcome) censor(censored) covariates(x) ///
        baseline_covariates(bl)

    assert c(varabbrev) == "on"
    assert row_before == _n
    assert r(N) == _N
    assert r(n_ids) == 12
    assert r(n_periods) == 3
    assert "`r(censor)'" == "censored"
    assert "`r(covariates)'" == "x"
    assert "`r(baseline_covariates)'" == "bl"
    set varabbrev off
}
if _rc == 0 {
    display as result "PASS PV1: msm_prepare preserves order and returns mappings"
    local ++pass_count
}
else {
    display as error "FAIL PV1: msm_prepare order/returns (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' PV1"
    set varabbrev off
}

**## PV2: msm_validate preserves physical observation order
local ++test_count
capture noisily {
    _adv_make_clean_panel
    set seed 91002
    gen double shuffle = runiform()
    sort shuffle
    gen long row_before = _n

    msm_prepare, id(id) period(period) treatment(treatment) ///
        outcome(outcome) censor(censored) covariates(x) ///
        baseline_covariates(bl)

    set varabbrev on
    msm_validate, strict

    assert c(varabbrev) == "on"
    assert row_before == _n
    assert r(n_checks) == 10
    assert r(n_errors) == 0
    assert r(n_warnings) == 0
    assert "`r(validation)'" == "passed"
    set varabbrev off
}
if _rc == 0 {
    display as result "PASS PV2: msm_validate preserves order on clean data"
    local ++pass_count
}
else {
    display as error "FAIL PV2: msm_validate order preservation (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' PV2"
    set varabbrev off
}

**# Validation Adversarial Cases
**## PV3: msm_validate rejects post-prepare non-binary treatment mutations
local ++test_count
capture noisily {
    _adv_make_clean_panel
    msm_prepare, id(id) period(period) treatment(treatment) ///
        outcome(outcome) censor(censored) covariates(x) ///
        baseline_covariates(bl)

    replace treatment = 2 in 1
    set varabbrev on
    capture msm_validate
    local validate_rc = _rc

    assert `validate_rc' == 198
    assert c(varabbrev) == "on"
    assert r(n_errors) >= 1
    set varabbrev off
}
if _rc == 0 {
    display as result "PASS PV3: msm_validate rejects stale non-binary treatment"
    local ++pass_count
}
else {
    display as error "FAIL PV3: non-binary treatment after prepare (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' PV3"
    set varabbrev off
}

**## PV4: missing key variables warn in non-strict and fail in strict
local ++test_count
capture noisily {
    _adv_make_clean_panel
    msm_prepare, id(id) period(period) treatment(treatment) ///
        outcome(outcome) censor(censored) covariates(x) ///
        baseline_covariates(bl)

    replace outcome = . in 1
    msm_validate
    assert r(n_errors) == 0
    assert r(n_warnings) == 1

    capture msm_validate, strict
    local strict_rc = _rc
    assert `strict_rc' == 198
    assert r(n_errors) >= 1
}
if _rc == 0 {
    display as result "PASS PV4: missingness warning/error semantics hold"
    local ++pass_count
}
else {
    display as error "FAIL PV4: missingness semantics (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' PV4"
}

**## PV5: strict validation rejects non-terminal censoring
local ++test_count
capture noisily {
    _adv_make_clean_panel
    replace censored = 1 if id == 1 & period == 1
    msm_prepare, id(id) period(period) treatment(treatment) ///
        outcome(outcome) censor(censored) covariates(x) ///
        baseline_covariates(bl)

    capture msm_validate, strict
    local validate_rc = _rc

    assert `validate_rc' == 198
    assert r(n_errors) == 1
}
if _rc == 0 {
    display as result "PASS PV5: strict validation rejects post-censor rows"
    local ++pass_count
}
else {
    display as error "FAIL PV5: censoring terminality (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' PV5"
}

**# Prepared State Integrity
**## PV6: stale prepared mappings fail guards and degrade dispatcher status
local ++test_count
capture noisily {
    _adv_make_clean_panel
    msm_prepare, id(id) period(period) treatment(treatment) ///
        outcome(outcome) censor(censored) covariates(x) ///
        baseline_covariates(bl)

    drop treatment
    set varabbrev on

    capture _msm_check_prepared
    local check_rc = _rc
    assert `check_rc' == 111
    assert c(varabbrev) == "on"

    capture msm_validate
    local validate_rc = _rc
    assert `validate_rc' == 111
    assert c(varabbrev) == "on"

    msm, status
    assert r(prepared) == 0
    assert r(weighted) == 0
    assert r(fitted) == 0
    assert "`r(stage)'" == "not_prepared"
    assert "`r(next_step)'" == "msm_prepare"

    set varabbrev off
}
if _rc == 0 {
    display as result "PASS PV6: stale prepared mappings are not trusted"
    local ++pass_count
}
else {
    display as error "FAIL PV6: stale prepared mapping guard/status (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' PV6"
    set varabbrev off
}

**## PV7: duplicate id-period prepare failures do not create prepared state
local ++test_count
capture noisily {
    _adv_make_clean_panel
    expand 2 in 1

    set varabbrev on
    capture msm_prepare, id(id) period(period) treatment(treatment) ///
        outcome(outcome) censor(censored) covariates(x) ///
        baseline_covariates(bl)
    local prepare_rc = _rc

    assert `prepare_rc' == 198
    assert c(varabbrev) == "on"
    assert "`: char _dta[_msm_prepared]'" == ""
    set varabbrev off
}
if _rc == 0 {
    display as result "PASS PV7: duplicate panels fail without prepared state"
    local ++pass_count
}
else {
    display as error "FAIL PV7: duplicate panel rejection/state (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' PV7"
    set varabbrev off
}

**## PV8: re-prepare clears stale downstream variables, matrices, and flags
local ++test_count
capture noisily {
    _adv_make_clean_panel
    msm_prepare, id(id) period(period) treatment(treatment) ///
        outcome(outcome) censor(censored) covariates(x) ///
        baseline_covariates(bl)

    * Build genuinely PACKAGE-OWNED downstream artifacts.
    *
    * This test used to create them with a bare `gen', which makes them USER
    * variables, and then required msm_prepare to delete them. That is audit
    * A05 -- msm_prepare destroying data it never created -- and
    * test_msm_state_identity S11/S12 assert the exact opposite. Both cannot
    * be right. Ownership is what separates them: msm_prepare must clear the
    * artifacts IT created and leave identically-named user variables alone.
    * This probe covers the first half; S11/S12 cover the second.
    gen double _msm_weight = 1
    gen double _msm_tw_weight = 1
    gen double _msm_cw_weight = 1
    _msm_qa_register_weights

    tempname pv_b pv_V
    matrix `pv_b' = (0, 0)
    matrix colnames `pv_b' = treatment _cons
    matrix `pv_V' = J(2, 2, 0)
    _msm_qa_register_fit, b(`pv_b') v(`pv_V')

    gen double _msm_period_sq = period^2
    gen double _msm_period_cu = period^3
    gen double _msm_per_ns1 = period
    gen double _msm_per_ns2 = period^2
    local pv8_fit_uuid : char _dta[_msm_fit_uuid]
    _msm_own claim _msm_period_sq _msm_period_cu _msm_per_ns1 _msm_per_ns2, ///
        token(`pv8_fit_uuid')

    matrix _msm_pred_matrix = J(1, 1, 1)
    matrix _msm_bal_matrix = J(1, 1, 1)

    char _dta[_msm_model] "logistic"
    char _dta[_msm_period_spec] "spline"
    char _dta[_msm_outcome_cov] "bl"
    char _dta[_msm_per_ns_knots] "0 1 2"
    char _dta[_msm_per_ns_df] "2"
    char _dta[_msm_fit_level] "95"
    char _dta[_msm_weight_var] "_msm_weight"
    char _dta[_msm_pred_saved] "1"
    char _dta[_msm_bal_saved] "1"
    char _dta[_msm_diag_saved] "1"
    char _dta[_msm_diag_mean] "1"
    char _dta[_msm_sens_saved] "1"
    char _dta[_msm_sens_effect] "0.5"

    msm_prepare, id(id) period(period) treatment(treatment) ///
        outcome(outcome) censor(censored) covariates(x) ///
        baseline_covariates(bl)

    foreach var in _msm_weight _msm_tw_weight _msm_cw_weight ///
        _msm_esample _msm_period_sq _msm_period_cu ///
        _msm_per_ns1 _msm_per_ns2 {
        capture confirm variable `var'
        assert _rc != 0
    }

    foreach mat in _msm_fit_b _msm_fit_V _msm_pred_matrix _msm_bal_matrix {
        capture matrix list `mat'
        assert _rc != 0
    }

    foreach ch in _msm_weighted _msm_fitted _msm_model _msm_period_spec ///
        _msm_outcome_cov _msm_per_ns_knots _msm_per_ns_df ///
        _msm_fit_level _msm_weight_var _msm_pred_saved ///
        _msm_bal_saved _msm_diag_saved _msm_diag_mean ///
        _msm_sens_saved _msm_sens_effect {
        assert "`: char _dta[`ch']'" == ""
    }

    msm, status
    assert r(prepared) == 1
    assert r(weighted) == 0
    assert r(fitted) == 0
    assert r(prediction_saved) == 0
    assert r(balance_saved) == 0
    assert r(diagnostics_saved) == 0
    assert r(sensitivity_saved) == 0
    assert "`r(stage)'" == "prepared"
}
if _rc == 0 {
    display as result "PASS PV8: re-prepare clears downstream state fully"
    local ++pass_count
}
else {
    display as error "FAIL PV8: downstream state clearing (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' PV8"
}

**## PV9: msm_fit refuses every model after post-prepare data mutation
local ++test_count
capture noisily {
    clear
    set seed 20260506
    set obs 600
    gen long id = ceil(_n / 3)
    bysort id: gen int period = _n - 1
    gen double bl = rnormal()
    bysort id: replace bl = bl[1]
    gen double x = rnormal() + 0.2 * period
    gen byte treatment = runiform() < invlogit(-0.2 + 0.25 * bl + 0.20 * x)
    gen byte outcome = 0
    replace outcome = 1 if period == 2 & runiform() < invlogit(-4 + 0.4 * treatment + 0.2 * bl)
    gen byte censored = 0

    msm_prepare, id(id) period(period) treatment(treatment) ///
        outcome(outcome) censor(censored) covariates(x) ///
        baseline_covariates(bl)
    msm_weight, treat_d_cov(x bl) treat_n_cov(bl) nolog

    replace outcome = 0.25 in 1
    set varabbrev on
    capture msm_fit, outcome_cov(bl) model(linear) period_spec(linear) nolog
    local linear_rc = _rc

    capture msm_fit, outcome_cov(bl) model(logistic) period_spec(linear) nolog
    local logistic_rc = _rc

    capture msm_fit, outcome_cov(bl) model(cox) period_spec(linear) nolog
    local cox_rc = _rc

    local _orig_treatment = treatment[2]
    replace treatment = 0.25 in 2
    capture msm_fit, outcome_cov(bl) model(linear) period_spec(linear) nolog
    local treatment_rc = _rc
    replace treatment = `_orig_treatment' in 2

    replace censored = 0.25 in 3
    capture msm_fit, outcome_cov(bl) model(linear) period_spec(linear) nolog
    local censor_rc = _rc

    * Every model refuses, including model(linear).
    *
    * This is the Q10 regression.  msm 1.2.3 returned linear_rc == 0 here: the
    * outcome had been mutated to a non-binary value AFTER msm_prepare validated
    * and mapped it, and model(linear) accepted it because its binary guard was
    * model-specific.  That tolerance is precisely the hole the continuous-outcome
    * recovery tests drove through -- map a dummy binary outcome, replace it with
    * a continuous one, fit.  Phase 1 closes it structurally rather than by adding
    * another model-specific guard: the per-stage input signature no longer
    * matches, so the data are not the data msm_prepare validated, and every model
    * exits 459 before any model-specific check is reached.
    *
    * 459 (not 198) is the point.  The refusal is now about data identity, not
    * about the value 0.25 being non-binary, so it fires uniformly for outcome,
    * treatment and censor mutations alike.
    assert `linear_rc' == 459
    assert `logistic_rc' == 459
    assert `cox_rc' == 459
    assert `treatment_rc' == 459
    assert `censor_rc' == 459
    assert c(varabbrev) == "on"
    set varabbrev off
}
if _rc == 0 {
    display as result "PASS PV9: msm_fit refuses every model after data mutation"
    local ++pass_count
}
else {
    display as error "FAIL PV9: post-prepare mutation guard (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' PV9"
    set varabbrev off
}

**## PV10: the shared order helper restores order and removes its marker
local ++test_count
capture noisily {
    clear
    set obs 12
    gen long expected_order = _n
    gen long order_marker = _n
    gsort -expected_order

    * Positive control: the helper does its job on a valid marker.  Without this
    * the 198 assertion below could pass on any unrelated syntax failure.
    _msm_restore_order order_marker
    assert expected_order == _n
    capture confirm variable order_marker
    assert _rc != 0

    * A missing marker is a deliberate no-op, not a failure: callers invoke the
    * helper in footer cleanup, where a preserved dataset may have been restored.
    capture _msm_restore_order order_marker
    assert _rc == 0

    * An empty argument is a caller bug and must be refused.
    capture _msm_restore_order
    assert _rc == 198
}
if _rc == 0 {
    display as result "PASS PV10: order-restoration helper contract"
    local ++pass_count
}
else {
    display as error "FAIL PV10: order-restoration helper contract (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' PV10"
}

**# Summary
display as text "Prepare/validate adversarial tests run: " as result `test_count'
display as text "Passed: " as result `pass_count'
display as text "Failed: " as result `fail_count'
if `fail_count' > 0 {
    display as error "Failed tests:`failed_tests'"
    exit 459
}
display as result "All msm prepare/validate adversarial tests passed"
