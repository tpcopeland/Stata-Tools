* test_msm.do - core functional tests across all commands (T1) (split from test_msm.do per audit Q01, preserving every assertion)
*
* Location: msm/qa/

version 16.0
clear all
set more off
set varabbrev off


* === Bootstrap ===
local qa_dir  "`c(pwd)'"
local pkg_dir "`qa_dir'/.."

do "`qa_dir'/_install_msm_isolated.do" "`pkg_dir'"

local pass_count = 0
local fail_count = 0
local test_count = 0
local failed_tests ""

* =============================================================================
* T1: FUNCTIONAL TESTS
* =============================================================================

* --- TEST 1: msm_prepare - basic functionality ---

use "`pkg_dir'/msm_example.dta", clear
msm_prepare, id(id) period(period) treatment(treatment) ///
    outcome(outcome) censor(censored) ///
    covariates(biomarker comorbidity) ///
    baseline_covariates(age sex)

local ++test_count
capture noisily {
    assert r(n_ids) == 500
}
if _rc == 0 {
    display as result "  PASS: n_ids is 500"
    local ++pass_count
}
else {
    display as error "  FAIL: n_ids is 500 (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T1.1"
}

local ++test_count
capture noisily {
    assert r(N) > 4000
}
if _rc == 0 {
    display as result "  PASS: N > 4000"
    local ++pass_count
}
else {
    display as error "  FAIL: N > 4000 (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T1.2"
}

local _chk : char _dta[_msm_prepared]
local ++test_count
capture noisily {
    assert "`_chk'" == "1"
}
if _rc == 0 {
    display as result "  PASS: prepared flag set"
    local ++pass_count
}
else {
    display as error "  FAIL: prepared flag set (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T1.3"
}

local _chk : char _dta[_msm_treatment]
local ++test_count
capture noisily {
    assert "`_chk'" == "treatment"
}
if _rc == 0 {
    display as result "  PASS: treatment var stored"
    local ++pass_count
}
else {
    display as error "  FAIL: treatment var stored (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T1.4"
}

* --- TEST 2: msm_prepare - error handling ---

use "`pkg_dir'/msm_example.dta", clear
tempvar bad_treat
gen double `bad_treat' = treatment * 2

local ++test_count
capture noisily {
    capture msm_prepare, id(id) period(period) treatment(`bad_treat') outcome(outcome)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: rejects non-binary treatment"
    local ++pass_count
}
else {
    display as error "  FAIL: rejects non-binary treatment (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T2.1"
}

* --- TEST 3: msm_validate ---

use "`pkg_dir'/msm_example.dta", clear
msm_prepare, id(id) period(period) treatment(treatment) ///
    outcome(outcome) censor(censored) ///
    covariates(biomarker comorbidity) ///
    baseline_covariates(age sex)

msm_validate, strict

local ++test_count
capture noisily {
    assert r(n_errors) == 0
}
if _rc == 0 {
    display as result "  PASS: validation passes"
    local ++pass_count
}
else {
    display as error "  FAIL: validation passes (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T3.1"
}

local ++test_count
capture noisily {
    assert r(n_checks) == 10
}
if _rc == 0 {
    display as result "  PASS: 10 checks run"
    local ++pass_count
}
else {
    display as error "  FAIL: 10 checks run (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T3.2"
}

* --- TEST 4: msm_validate prerequisite ---

use "`pkg_dir'/msm_example.dta", clear

local ++test_count
capture noisily {
    capture msm_validate
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: validate fails without prepare"
    local ++pass_count
}
else {
    display as error "  FAIL: validate fails without prepare (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T4.1"
}

* --- TEST 5: msm_weight - IPTW only ---

use "`pkg_dir'/msm_example.dta", clear
msm_prepare, id(id) period(period) treatment(treatment) ///
    outcome(outcome) covariates(biomarker comorbidity) ///
    baseline_covariates(age sex)

msm_weight, treat_d_cov(biomarker comorbidity age sex) ///
    treat_n_cov(age sex) nolog

local ++test_count
capture noisily {
    assert abs(r(mean_weight) - 1) < 0.15
}
if _rc == 0 {
    display as result "  PASS: mean weight near 1 (" r(mean_weight) ")"
    local ++pass_count
}
else {
    display as error "  FAIL: mean weight near 1 (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T5.1"
}

local ++test_count
capture noisily {
    confirm variable _msm_weight
}
if _rc == 0 {
    display as result "  PASS: _msm_weight exists"
    local ++pass_count
}
else {
    display as error "  FAIL: _msm_weight exists (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T5.2"
}

local ++test_count
capture noisily {
    confirm variable _msm_tw_weight
}
if _rc == 0 {
    display as result "  PASS: _msm_tw_weight exists"
    local ++pass_count
}
else {
    display as error "  FAIL: _msm_tw_weight exists (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T5.3"
}

local ++test_count
capture noisily {
    assert r(ess) < _N
}
if _rc == 0 {
    display as result "  PASS: ESS < N"
    local ++pass_count
}
else {
    display as error "  FAIL: ESS < N (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T5.4"
}

* --- TEST 6: msm_weight - IPTW + IPCW + truncation ---

use "`pkg_dir'/msm_example.dta", clear
msm_prepare, id(id) period(period) treatment(treatment) ///
    outcome(outcome) censor(censored) ///
    covariates(biomarker comorbidity) ///
    baseline_covariates(age sex)

msm_weight, treat_d_cov(biomarker comorbidity age sex) ///
    treat_n_cov(age sex) ///
    censor_d_cov(age sex biomarker) ///
    truncate(1 99) nolog

local ++test_count
capture noisily {
    assert r(n_truncated) > 0
}
if _rc == 0 {
    display as result "  PASS: truncation occurred (" r(n_truncated) " obs)"
    local ++pass_count
}
else {
    display as error "  FAIL: truncation occurred (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T6.1"
}

local ++test_count
capture noisily {
    confirm variable _msm_cw_weight
}
if _rc == 0 {
    display as result "  PASS: _msm_cw_weight exists"
    local ++pass_count
}
else {
    display as error "  FAIL: _msm_cw_weight exists (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T6.2"
}

* --- TEST 7: msm_weight prerequisite ---

use "`pkg_dir'/msm_example.dta", clear

local ++test_count
capture noisily {
    capture msm_weight, treat_d_cov(age sex) nolog
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: weight fails without prepare"
    local ++pass_count
}
else {
    display as error "  FAIL: weight fails without prepare (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T7.1"
}

* --- TEST 8: msm_fit - pooled logistic (known-answer test) ---

use "`pkg_dir'/msm_example.dta", clear
msm_prepare, id(id) period(period) treatment(treatment) ///
    outcome(outcome) censor(censored) ///
    covariates(biomarker comorbidity) ///
    baseline_covariates(age sex)
msm_weight, treat_d_cov(biomarker comorbidity age sex) ///
    treat_n_cov(age sex) truncate(1 99) nolog

msm_fit, model(logistic) outcome_cov(age sex) ///
    period_spec(quadratic) nolog

local or = exp(_b[treatment])

local ++test_count
capture noisily {
    assert `or' > 0.3 & `or' < 1.5
}
if _rc == 0 {
    display as result "  PASS: OR in reasonable range"
    local ++pass_count
}
else {
    display as error "  FAIL: OR in reasonable range (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T8.1"
}

local ++test_count
capture noisily {
    assert abs(`or' - 0.7) < 0.3
}
if _rc == 0 {
    display as result "  PASS: OR near true 0.7"
    local ++pass_count
}
else {
    display as error "  FAIL: OR near true 0.7 (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T8.2"
}

local _chk : char _dta[_msm_fitted]
local ++test_count
capture noisily {
    assert "`_chk'" == "1"
}
if _rc == 0 {
    display as result "  PASS: fitted flag set"
    local ++pass_count
}
else {
    display as error "  FAIL: fitted flag set (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T8.3"
}

* --- TEST 9: msm_predict ---

msm_predict, times(3 5 9) type(cum_inc) ///
    samples(30) seed(42) difference

local ++test_count
capture noisily {
    assert r(n_times) == 3
}
if _rc == 0 {
    display as result "  PASS: n_times = 3"
    local ++pass_count
}
else {
    display as error "  FAIL: n_times = 3 (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T9.1"
}

local ++test_count
capture noisily {
    assert r(n_ref) == 500
}
if _rc == 0 {
    display as result "  PASS: n_ref = 500"
    local ++pass_count
}
else {
    display as error "  FAIL: n_ref = 500 (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T9.2"
}

* Risk difference at t=9 should be negative (treatment is protective)
tempname _pred
matrix `_pred' = r(predictions)
local rd_9 = `_pred'[3, 8]

local ++test_count
capture noisily {
    assert `rd_9' < 0
}
if _rc == 0 {
    display as result "  PASS: risk diff at t=9 is negative (" `rd_9' ")"
    local ++pass_count
}
else {
    display as error "  FAIL: risk diff at t=9 is negative (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T9.3"
}

* --- TEST 10: msm_diagnose ---

msm_diagnose, by_period threshold(0.1)

local ++test_count
capture noisily {
    assert r(ess) > 0
}
if _rc == 0 {
    display as result "  PASS: ESS returned (" r(ess) ")"
    local ++pass_count
}
else {
    display as error "  FAIL: ESS returned (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T10.1"
}

local ++test_count
capture noisily {
    assert r(ess_pct) > 0 & r(ess_pct) <= 100
}
if _rc == 0 {
    display as result "  PASS: ESS% valid (" r(ess_pct) "%)"
    local ++pass_count
}
else {
    display as error "  FAIL: ESS% valid (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T10.2"
}

* --- TEST 11: msm_report ---

local ++test_count
capture noisily {
    capture msm_report, eform
    assert _rc == 0
}
if _rc == 0 {
    display as result "  PASS: report display runs"
    local ++pass_count
}
else {
    display as error "  FAIL: report display runs (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T11.1"
}

local ++test_count
capture noisily {
    capture msm_report, export("/tmp/_test_report.csv") format(csv) eform replace
    assert _rc == 0
}
if _rc == 0 {
    display as result "  PASS: CSV export runs"
    local ++pass_count
}
else {
    display as error "  FAIL: CSV export runs (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T11.2"
}
capture erase "/tmp/_test_report.csv"

* --- TEST 12: msm_protocol ---

local ++test_count
capture noisily {
    capture msm_protocol, ///
        population("Adults") treatment("Drug A vs none") ///
        confounders("biomarker, comorbidity") outcome("Mortality") ///
        causal_contrast("Always vs never") weight_spec("Stabilized IPTW") ///
        analysis("Pooled logistic MSM")
    assert _rc == 0
}
if _rc == 0 {
    display as result "  PASS: protocol runs"
    local ++pass_count
}
else {
    display as error "  FAIL: protocol runs (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T12.1"
}

* --- TEST 13: msm_sensitivity ---

local ++test_count
capture noisily {
    capture msm_sensitivity, evalue
    assert _rc == 0
}
if _rc == 0 {
    display as result "  PASS: evalue runs"
    local ++pass_count
}
else {
    display as error "  FAIL: evalue runs (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T13.1"
}

local ++test_count
capture noisily {
    assert r(evalue_point) > 1
}
if _rc == 0 {
    display as result "  PASS: evalue_point > 1 (" r(evalue_point) ")"
    local ++pass_count
}
else {
    display as error "  FAIL: evalue_point > 1 (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T13.2"
}

local ++test_count
capture noisily {
    capture msm_sensitivity, confounding_strength(1.5 2.0)
    assert _rc == 0
}
if _rc == 0 {
    display as result "  PASS: confounding_strength runs"
    local ++pass_count
}
else {
    display as error "  FAIL: confounding_strength runs (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T13.3"
}

* --- TEST 14: msm_plot ---

local ++test_count
capture noisily {
    capture msm_plot, type(weights)
    assert _rc == 0
}
if _rc == 0 {
    display as result "  PASS: weights plot runs"
    local ++pass_count
}
else {
    display as error "  FAIL: weights plot runs (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T14.1"
}
graph close _all

local ++test_count
capture noisily {
    capture msm_plot, type(positivity)
    assert _rc == 0
}
if _rc == 0 {
    display as result "  PASS: positivity plot runs"
    local ++pass_count
}
else {
    display as error "  FAIL: positivity plot runs (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T14.2"
}
graph close _all

* --- TEST 15: msm router ---

local ++test_count
capture noisily {
    capture msm
    assert _rc == 0
}
if _rc == 0 {
    display as result "  PASS: router runs"
    local ++pass_count
}
else {
    display as error "  FAIL: router runs (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T15.1"
}

local ++test_count
capture noisily {
    assert r(n_commands) == 12
}
if _rc == 0 {
    display as result "  PASS: n_commands = 12"
    local ++pass_count
}
else {
    display as error "  FAIL: n_commands != 12 (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T15.2"
}

* --- TEST 16: msm_fit linear model ---

use "`pkg_dir'/msm_example.dta", clear
msm_prepare, id(id) period(period) treatment(treatment) ///
    outcome(outcome) covariates(biomarker comorbidity) ///
    baseline_covariates(age sex)
msm_weight, treat_d_cov(biomarker comorbidity age sex) ///
    treat_n_cov(age sex) truncate(1 99) nolog

local ++test_count
capture noisily {
    capture msm_fit, model(linear) outcome_cov(age sex) period_spec(linear)
    assert _rc == 0
}
if _rc == 0 {
    display as result "  PASS: linear model runs"
    local ++pass_count
}
else {
    display as error "  FAIL: linear model runs (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T16.1"
}

local b_lin = _b[treatment]
local ++test_count
capture noisily {
    assert `b_lin' < 0
}
if _rc == 0 {
    display as result "  PASS: linear coeff negative (" `b_lin' ")"
    local ++pass_count
}
else {
    display as error "  FAIL: linear coeff negative (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T16.2"
}

* --- TEST 17: Helper functions ---

_msm_col_letter 1
local ++test_count
capture noisily {
    assert "`result'" == "A"
}
if _rc == 0 {
    display as result "  PASS: col_letter(1) = A"
    local ++pass_count
}
else {
    display as error "  FAIL: col_letter(1) = A (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T17.1"
}

_msm_col_letter 27
local ++test_count
capture noisily {
    assert "`result'" == "AA"
}
if _rc == 0 {
    display as result "  PASS: col_letter(27) = AA"
    local ++pass_count
}
else {
    display as error "  FAIL: col_letter(27) = AA (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T17.2"
}

use "`pkg_dir'/msm_example.dta", clear
_msm_smd age, treatment(treatment)
local ++test_count
capture noisily {
    assert "`_msm_smd_value'" != ""
}
if _rc == 0 {
    display as result "  PASS: SMD computed (" `_msm_smd_value' ")"
    local ++pass_count
}
else {
    display as error "  FAIL: SMD computed (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T17.3"
}


* Summary
display as result "Test Results: `pass_count'/`test_count' passed, `fail_count' failed"
display "RESULT: test_msm tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    display as error "Failed:`failed_tests'"
    exit 1
}
else {
    display as result "ALL TESTS PASSED"
}
