* test_msm_continuous_exposure.do - msm_fit exposure()/tvcov() regression tests (v1.2.0)
* Location: msm/qa/
*
* Covers the continuous / time-varying exposure outcome model added in 1.2.0:
*   - binary-treatment default path is unchanged
*   - continuous-exposure Cox: effect term, e()/char surface, e(effects)
*   - msm_predict fence and msm,status next-step in exposure/tvcov mode
*   - tvcov() model gating and term-overlap guards
*   - msm_sensitivity rendering an exposure fit

version 16.0
clear all
set more off
set varabbrev off

local qa_dir  "`c(pwd)'"
local pkg_dir "`qa_dir'/.."

do "`qa_dir'/_install_msm_isolated.do" "`pkg_dir'"

local pass_count = 0
local fail_count = 0
local test_count = 0
local failed_tests ""

* Build a weighted panel plus two deterministic functions of the binary
* treatment process: cumulative own-class exposure and cumulative comparator
* exposure. These are exactly the terms exposure()/tvcov() license.
capture program drop _setup_exposure
program define _setup_exposure
    version 16.0
    syntax [, NOLOG]

    local qa_dir "`c(pwd)'"
    local pkg_dir "`qa_dir'/.."

    use "`pkg_dir'/msm_example.dta", clear
    msm_prepare, id(id) period(period) treatment(treatment) ///
        outcome(outcome) censor(censored) ///
        covariates(biomarker comorbidity) ///
        baseline_covariates(age sex)
    msm_weight, treat_d_cov(biomarker comorbidity age sex) ///
        treat_n_cov(age sex) truncate(1 99) `nolog'

    bysort id (period): gen double cum_trt  = sum(treatment)
    bysort id (period): gen double cum_comp = sum(1 - treatment)
end

**# E1: binary-treatment default path is unchanged

local ++test_count
capture noisily {
    * Logistic baseline: the unchanged default whose downstream is msm_predict.
    _setup_exposure, nolog
    msm_fit, model(logistic) outcome_cov(age sex) nolog

    * No exposure mode: the new char surface must be empty / disabled-off.
    local pd : char _dta[_msm_predict_disabled]
    local ex : char _dta[_msm_exposure]
    local tv : char _dta[_msm_tvcov]
    assert "`pd'" == ""
    assert "`ex'" == ""
    assert "`tv'" == ""
    assert "`e(msm_exposure)'" == ""
    assert "`e(msm_tvcov)'" == ""

    * Primary effect term is still the mapped treatment, and e(effects) tracks it.
    matrix eff = e(effects)
    assert reldif(eff[1,1], _b[treatment]) < 1e-12

    * Default logistic fit still routes to msm_predict.
    msm, status
    assert "`r(next_step)'" == "msm_predict"
}
if _rc == 0 {
    display as result "  PASS E1: binary default path unchanged (no exposure surface)"
    local ++pass_count
}
else {
    display as error "  FAIL E1: binary default path (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' E1"
}

**# E2: continuous-exposure Cox surface

local ++test_count
capture noisily {
    _setup_exposure, nolog
    msm_fit, model(cox) exposure(cum_trt) tvcov(cum_comp) ///
        outcome_cov(age sex) vce(cluster id) nolog

    * eclass + char surface report the override.
    assert "`e(msm_exposure)'" == "cum_trt"
    assert "`e(msm_tvcov)'"    == "cum_comp"
    assert "`e(msm_treatment)'" == "treatment"
    local pd : char _dta[_msm_predict_disabled]
    local ex : char _dta[_msm_exposure]
    local tv : char _dta[_msm_tvcov]
    assert "`pd'" == "1"
    assert "`ex'" == "cum_trt"
    assert "`tv'" == "cum_comp"

    * The exposure term is the primary effect, not the binary treatment.
    matrix eff = e(effects)
    assert reldif(eff[1,1], _b[cum_trt]) < 1e-12

    * Both new terms entered the model; the binary treatment did not.
    * (`: list X in Y' treats X as a macro NAME, so hold each var in a macro.)
    matrix _eb = e(b)
    local cn : colnames _eb
    local v_exp "cum_trt"
    local v_tv  "cum_comp"
    local v_trt "treatment"
    assert `: list v_exp in cn'
    assert `: list v_tv in cn'
    assert !`: list v_trt in cn'
}
if _rc == 0 {
    display as result "  PASS E2: continuous-exposure Cox surface correct"
    local ++pass_count
}
else {
    display as error "  FAIL E2: continuous-exposure Cox surface (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' E2"
}

**# E3: msm_predict fence + status next-step in exposure mode

local ++test_count
capture noisily {
    _setup_exposure, nolog
    msm_fit, model(cox) exposure(cum_trt) outcome_cov(age sex) vce(cluster id) nolog

    * predict must refuse (rc 198), not silently standardize a continuous term.
    capture msm_predict, times(5)
    assert _rc == 198

    * status must not recommend msm_predict in this mode.
    msm, status
    assert "`r(next_step)'" != "msm_predict"
}
if _rc == 0 {
    display as result "  PASS E3: predict fenced + status reroutes off predict"
    local ++pass_count
}
else {
    display as error "  FAIL E3: predict fence / status next-step (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' E3"
}

**# E4: tvcov() rejected on model(linear)

local ++test_count
capture noisily {
    _setup_exposure, nolog
    capture msm_fit, model(linear) tvcov(cum_comp) outcome_cov(age sex) nolog
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS E4: tvcov() rejected for model(linear)"
    local ++pass_count
}
else {
    display as error "  FAIL E4: tvcov() linear gate (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' E4"
}

**# E5: term-overlap guards

local ++test_count
capture noisily {
    * exposure() also listed in outcome_cov()
    _setup_exposure, nolog
    capture msm_fit, model(cox) exposure(cum_trt) outcome_cov(cum_trt age) nolog
    assert _rc == 198

    * tvcov() sharing a variable with outcome_cov()
    _setup_exposure, nolog
    capture msm_fit, model(cox) tvcov(cum_comp) outcome_cov(cum_comp age) nolog
    assert _rc == 198

    * tvcov() containing the mapped treatment
    _setup_exposure, nolog
    capture msm_fit, model(cox) tvcov(treatment) outcome_cov(age) nolog
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS E5: overlap guards reject double-counted terms"
    local ++pass_count
}
else {
    display as error "  FAIL E5: overlap guards (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' E5"
}

**# E6: msm_sensitivity renders an exposure fit

local ++test_count
capture noisily {
    * baseline (treatment) sensitivity still works
    _setup_exposure, nolog
    msm_fit, model(cox) outcome_cov(age sex) vce(cluster id) nolog
    msm_sensitivity, evalue
    assert !missing(r(evalue_point))

    * exposure fit: sensitivity finds the exposure coefficient, not treatment
    _setup_exposure, nolog
    msm_fit, model(cox) exposure(cum_trt) tvcov(cum_comp) ///
        outcome_cov(age sex) vce(cluster id) nolog
    local fit_hr = exp(_b[cum_trt])
    msm_sensitivity, evalue
    assert reldif(r(effect), `fit_hr') < 1e-8
    assert !missing(r(evalue_point))
}
if _rc == 0 {
    display as result "  PASS E6: msm_sensitivity renders exposure fit"
    local ++pass_count
}
else {
    display as error "  FAIL E6: msm_sensitivity on exposure fit (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' E6"
}

**# E7: exposure on logistic also fences predict

local ++test_count
capture noisily {
    _setup_exposure, nolog
    msm_fit, model(logistic) exposure(cum_trt) outcome_cov(age sex) nolog
    local pd : char _dta[_msm_predict_disabled]
    assert "`pd'" == "1"
    capture msm_predict, times(3)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS E7: exposure() on logistic disables predict"
    local ++pass_count
}
else {
    display as error "  FAIL E7: logistic exposure predict fence (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' E7"
}

**# Summary

local qa_status = cond(`fail_count' > 0, "FAIL", "PASS")
display as text ""
display as text "RESULT: continuous exposure tests=`test_count' pass=`pass_count' fail=`fail_count' status=`qa_status'"
if `fail_count' > 0 {
    display as error "FAILED TESTS:`failed_tests'"
    exit 9
}
display as result "ALL TESTS PASSED"
