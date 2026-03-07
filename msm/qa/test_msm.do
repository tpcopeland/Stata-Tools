* test_msm.do - Comprehensive functional test for msm package
* Tests: full pipeline, known-answer test, weight properties,
*        balance check, error handling, all commands

clear all
set more off

capture ado uninstall msm
net install msm, from("/home/tpcopeland/Stata-Tools/msm") replace

local n_pass = 0
local n_fail = 0
local n_tests = 0

* =========================================================================
* TEST 1: msm_prepare - basic functionality
* =========================================================================
display _newline "TEST 1: msm_prepare"

use "/home/tpcopeland/Stata-Tools/msm/msm_example.dta", clear
msm_prepare, id(id) period(period) treatment(treatment) ///
    outcome(outcome) censor(censored) ///
    covariates(biomarker comorbidity) ///
    baseline_covariates(age sex)

local ++n_tests
assert r(n_ids) == 500
display as result "  PASS: n_ids is 500"
local ++n_pass

local ++n_tests
assert r(N) > 4000
display as result "  PASS: N > 4000"
local ++n_pass

local ++n_tests
local _chk : char _dta[_msm_prepared]
assert "`_chk'" == "1"
display as result "  PASS: prepared flag set"
local ++n_pass

local ++n_tests
local _chk : char _dta[_msm_treatment]
assert "`_chk'" == "treatment"
display as result "  PASS: treatment var stored"
local ++n_pass

* =========================================================================
* TEST 2: msm_prepare - error handling
* =========================================================================
display _newline "TEST 2: msm_prepare error handling"

use "/home/tpcopeland/Stata-Tools/msm/msm_example.dta", clear
tempvar bad_treat
gen double `bad_treat' = treatment * 2

local ++n_tests
capture msm_prepare, id(id) period(period) treatment(`bad_treat') outcome(outcome)
assert _rc == 198
display as result "  PASS: rejects non-binary treatment"
local ++n_pass

* =========================================================================
* TEST 3: msm_validate
* =========================================================================
display _newline "TEST 3: msm_validate"

use "/home/tpcopeland/Stata-Tools/msm/msm_example.dta", clear
msm_prepare, id(id) period(period) treatment(treatment) ///
    outcome(outcome) censor(censored) ///
    covariates(biomarker comorbidity) ///
    baseline_covariates(age sex)

msm_validate, strict

local ++n_tests
assert r(n_errors) == 0
display as result "  PASS: validation passes"
local ++n_pass

local ++n_tests
assert r(n_checks) == 10
display as result "  PASS: 10 checks run"
local ++n_pass

* =========================================================================
* TEST 4: msm_validate prerequisite
* =========================================================================
display _newline "TEST 4: msm_validate prerequisite"

use "/home/tpcopeland/Stata-Tools/msm/msm_example.dta", clear

local ++n_tests
capture msm_validate
assert _rc == 198
display as result "  PASS: validate fails without prepare"
local ++n_pass

* =========================================================================
* TEST 5: msm_weight - IPTW only
* =========================================================================
display _newline "TEST 5: msm_weight (IPTW only)"

use "/home/tpcopeland/Stata-Tools/msm/msm_example.dta", clear
msm_prepare, id(id) period(period) treatment(treatment) ///
    outcome(outcome) covariates(biomarker comorbidity) ///
    baseline_covariates(age sex)

msm_weight, treat_d_cov(biomarker comorbidity age sex) ///
    treat_n_cov(age sex) nolog

local ++n_tests
assert abs(r(mean_weight) - 1) < 0.15
display as result "  PASS: mean weight near 1 (" r(mean_weight) ")"
local ++n_pass

local ++n_tests
confirm variable _msm_weight
display as result "  PASS: _msm_weight exists"
local ++n_pass

local ++n_tests
confirm variable _msm_tw_weight
display as result "  PASS: _msm_tw_weight exists"
local ++n_pass

local ++n_tests
assert r(ess) < _N
display as result "  PASS: ESS < N"
local ++n_pass

* =========================================================================
* TEST 6: msm_weight - IPTW + IPCW + truncation
* =========================================================================
display _newline "TEST 6: msm_weight (IPTW + IPCW + truncation)"

use "/home/tpcopeland/Stata-Tools/msm/msm_example.dta", clear
msm_prepare, id(id) period(period) treatment(treatment) ///
    outcome(outcome) censor(censored) ///
    covariates(biomarker comorbidity) ///
    baseline_covariates(age sex)

msm_weight, treat_d_cov(biomarker comorbidity age sex) ///
    treat_n_cov(age sex) ///
    censor_d_cov(age sex biomarker) ///
    truncate(1 99) nolog

local ++n_tests
assert r(n_truncated) > 0
display as result "  PASS: truncation occurred (" r(n_truncated) " obs)"
local ++n_pass

local ++n_tests
capture confirm variable _msm_cw_weight
assert _rc == 0
display as result "  PASS: _msm_cw_weight exists"
local ++n_pass

* =========================================================================
* TEST 7: msm_weight prerequisite
* =========================================================================
display _newline "TEST 7: msm_weight prerequisite"

use "/home/tpcopeland/Stata-Tools/msm/msm_example.dta", clear

local ++n_tests
capture msm_weight, treat_d_cov(age sex) nolog
assert _rc == 198
display as result "  PASS: weight fails without prepare"
local ++n_pass

* =========================================================================
* TEST 8: msm_fit - pooled logistic (known-answer test)
* =========================================================================
display _newline "TEST 8: msm_fit (pooled logistic, known-answer)"

use "/home/tpcopeland/Stata-Tools/msm/msm_example.dta", clear
msm_prepare, id(id) period(period) treatment(treatment) ///
    outcome(outcome) censor(censored) ///
    covariates(biomarker comorbidity) ///
    baseline_covariates(age sex)
msm_weight, treat_d_cov(biomarker comorbidity age sex) ///
    treat_n_cov(age sex) truncate(1 99) nolog

msm_fit, model(logistic) outcome_cov(age sex) ///
    period_spec(quadratic) nolog

local or = exp(_b[treatment])
display "  Estimated OR: " `or' " (true: 0.7)"

local ++n_tests
assert `or' > 0.3 & `or' < 1.5
display as result "  PASS: OR in reasonable range"
local ++n_pass

local ++n_tests
assert abs(`or' - 0.7) < 0.3
display as result "  PASS: OR near true 0.7"
local ++n_pass

local ++n_tests
local _chk : char _dta[_msm_fitted]
assert "`_chk'" == "1"
display as result "  PASS: fitted flag set"
local ++n_pass

* =========================================================================
* TEST 9: msm_predict
* =========================================================================
display _newline "TEST 9: msm_predict"

msm_predict, times(3 5 9) type(cum_inc) ///
    samples(30) seed(42) difference

local ++n_tests
assert r(n_times) == 3
display as result "  PASS: n_times = 3"
local ++n_pass

local ++n_tests
assert r(n_ref) == 500
display as result "  PASS: n_ref = 500"
local ++n_pass

* Risk difference at t=9 should be negative (treatment is protective)
tempname _pred
matrix `_pred' = r(predictions)
local rd_9 = `_pred'[3, 8]

local ++n_tests
assert `rd_9' < 0
display as result "  PASS: risk diff at t=9 is negative (" `rd_9' ")"
local ++n_pass

* =========================================================================
* TEST 10: msm_diagnose
* =========================================================================
display _newline "TEST 10: msm_diagnose"

msm_diagnose, by_period threshold(0.1)

local ++n_tests
assert r(ess) > 0
display as result "  PASS: ESS returned (" r(ess) ")"
local ++n_pass

local ++n_tests
assert r(ess_pct) > 0 & r(ess_pct) <= 100
display as result "  PASS: ESS% valid (" r(ess_pct) "%)"
local ++n_pass

* =========================================================================
* TEST 11: msm_report
* =========================================================================
display _newline "TEST 11: msm_report"

local ++n_tests
capture msm_report, eform
assert _rc == 0
display as result "  PASS: report display runs"
local ++n_pass

local ++n_tests
capture msm_report, export("/tmp/_test_report.csv") format(csv) eform replace
assert _rc == 0
display as result "  PASS: CSV export runs"
local ++n_pass
capture erase "/tmp/_test_report.csv"

* =========================================================================
* TEST 12: msm_protocol
* =========================================================================
display _newline "TEST 12: msm_protocol"

local ++n_tests
capture msm_protocol, ///
    population("Adults") treatment("Drug A vs none") ///
    confounders("biomarker, comorbidity") outcome("Mortality") ///
    causal_contrast("Always vs never") weight_spec("Stabilized IPTW") ///
    analysis("Pooled logistic MSM")
assert _rc == 0
display as result "  PASS: protocol runs"
local ++n_pass

* =========================================================================
* TEST 13: msm_sensitivity
* =========================================================================
display _newline "TEST 13: msm_sensitivity"

local ++n_tests
capture msm_sensitivity, evalue
assert _rc == 0
display as result "  PASS: evalue runs"
local ++n_pass

local ++n_tests
assert r(evalue_point) > 1
display as result "  PASS: evalue_point > 1 (" r(evalue_point) ")"
local ++n_pass

local ++n_tests
capture msm_sensitivity, confounding_strength(1.5 2.0)
assert _rc == 0
display as result "  PASS: confounding_strength runs"
local ++n_pass

* =========================================================================
* TEST 14: msm_plot
* =========================================================================
display _newline "TEST 14: msm_plot"

local ++n_tests
capture msm_plot, type(weights)
assert _rc == 0
display as result "  PASS: weights plot runs"
local ++n_pass
graph close _all

local ++n_tests
capture msm_plot, type(positivity)
assert _rc == 0
display as result "  PASS: positivity plot runs"
local ++n_pass
graph close _all

* =========================================================================
* TEST 15: msm router
* =========================================================================
display _newline "TEST 15: msm router"

local ++n_tests
capture msm
assert _rc == 0
display as result "  PASS: router runs"
local ++n_pass

local ++n_tests
assert r(n_commands) == 10
display as result "  PASS: n_commands = 10"
local ++n_pass

* =========================================================================
* TEST 16: msm_fit linear model
* =========================================================================
display _newline "TEST 16: msm_fit (linear model)"

use "/home/tpcopeland/Stata-Tools/msm/msm_example.dta", clear
msm_prepare, id(id) period(period) treatment(treatment) ///
    outcome(outcome) covariates(biomarker comorbidity) ///
    baseline_covariates(age sex)
msm_weight, treat_d_cov(biomarker comorbidity age sex) ///
    treat_n_cov(age sex) truncate(1 99) nolog

local ++n_tests
capture msm_fit, model(linear) outcome_cov(age sex) period_spec(linear)
assert _rc == 0
display as result "  PASS: linear model runs"
local ++n_pass

local b_lin = _b[treatment]
local ++n_tests
assert `b_lin' < 0
display as result "  PASS: linear coeff negative (" `b_lin' ")"
local ++n_pass

* =========================================================================
* TEST 17: Helper functions
* =========================================================================
display _newline "TEST 17: Helper functions"

_msm_col_letter 1
local ++n_tests
assert "`result'" == "A"
display as result "  PASS: col_letter(1) = A"
local ++n_pass

_msm_col_letter 27
local ++n_tests
assert "`result'" == "AA"
display as result "  PASS: col_letter(27) = AA"
local ++n_pass

use "/home/tpcopeland/Stata-Tools/msm/msm_example.dta", clear
_msm_smd age, treatment(treatment)
local ++n_tests
assert "`_msm_smd_value'" != ""
display as result "  PASS: SMD computed (" `_msm_smd_value' ")"
local ++n_pass

* =========================================================================
* SUMMARY
* =========================================================================
display _newline _dup(70) "="
display "TEST SUMMARY"
display _dup(70) "="
display "  Tests run:  " as result `n_tests'
display "  Passed:     " as result `n_pass'
if `n_fail' > 0 {
    display "  Failed:     " as error `n_fail'
}
else {
    display "  Failed:     " as result `n_fail'
}
display _dup(70) "="

if `n_fail' == 0 {
    display as result _newline "ALL TESTS PASSED"
}
else {
    display as error _newline "`n_fail' TEST(S) FAILED"
    exit 198
}
