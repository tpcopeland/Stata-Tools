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

    * Lagged treatment: a deterministic function of the same binary treatment
    * process msm_weight balances (the documented licence for tvcov()), and the
    * standard companion to a cumulative-exposure term in MSM practice. Unlike
    * cum_comp it is not a linear function of follow-up time, so the exposure
    * effect stays identified -- see the E8 note below.
    bysort id (period): gen byte lag_trt = cond(_n == 1, 0, treatment[_n - 1])
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
*
* SPEC CHANGE (Phase 1, finding N01). This probe used to fit
*     exposure(cum_trt) tvcov(cum_comp)
* which is not an identified model in ANY dataset msm accepts. msm_prepare
* requires treatment in {0,1}, so there is no "on neither" state and
*     cum_trt + cum_comp == period + 1
* holds exactly. Cox compares subjects within a risk set at one failure time,
* where period is constant, so cum_comp is a perfect linear function of cum_trt
* inside every comparison. Stata resolves the rank deficiency by omitting one
* term -- and under this estimation sample it omits cum_trt, the exposure
* itself, reporting b = -.01410812 with se = 0 exactly: HR 0.986, CI
* [0.986, 0.986], p = . The old probe asserted only the point estimate, so it
* passed on that. Note the coefficient is NOT zero, so the output does not read
* as a null -- it reads as a precise finding, which is worse.
*
* The companion term is now lag_trt, which honours the same tvcov() contract
* (a deterministic function of the treatment process) without collapsing the
* design. E8 pins the refusal of the old spec.

local ++test_count
capture noisily {
    _setup_exposure, nolog
    msm_fit, model(cox) exposure(cum_trt) tvcov(lag_trt) ///
        outcome_cov(age sex) vce(cluster id) nolog

    * eclass + char surface report the override.
    assert "`e(msm_exposure)'" == "cum_trt"
    assert "`e(msm_tvcov)'"    == "lag_trt"
    assert "`e(msm_treatment)'" == "treatment"
    local pd : char _dta[_msm_predict_disabled]
    local ex : char _dta[_msm_exposure]
    local tv : char _dta[_msm_tvcov]
    assert "`pd'" == "1"
    assert "`ex'" == "cum_trt"
    assert "`tv'" == "lag_trt"

    * The exposure term is the primary effect, not the binary treatment.
    matrix eff = e(effects)
    assert reldif(eff[1,1], _b[cum_trt]) < 1e-12
    local eff_rows : rownames eff
    assert "`eff_rows'" == "cum_trt"

    * The exposure effect is actually estimated, not omitted as collinear.
    * Asserting the point estimate alone is what let the degenerate cum_comp
    * spec pass: an omitted term reports b = 0 with a zero-width CI, and
    * eff[1,1] == _b[cum_trt] holds trivially when both are 0.
    matrix _eV = e(V)
    assert _eV[1,1] > 0 & !missing(_eV[1,1])
    assert _se[cum_trt] > 0 & !missing(_se[cum_trt])
    assert eff[1,3] > eff[1,2]
    assert !missing(eff[1,4])

    * Both new terms entered the model; the binary treatment did not.
    * (`: list X in Y' treats X as a macro NAME, so hold each var in a macro.)
    matrix _eb = e(b)
    local cn : colnames _eb
    local v_exp "cum_trt"
    local v_tv  "lag_trt"
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
    capture msm_fit, model(cox) exposure(cum_trt) outcome_cov(cum_trt age sex) nolog
    assert _rc == 198

    * tvcov() sharing a variable with outcome_cov()
    _setup_exposure, nolog
    capture msm_fit, model(cox) tvcov(cum_comp) outcome_cov(cum_comp age sex) nolog
    assert _rc == 198

    * tvcov() containing the mapped treatment
    _setup_exposure, nolog
    capture msm_fit, model(cox) tvcov(treatment) outcome_cov(age sex) nolog
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
    * (tvcov is lag_trt, not cum_comp -- see the E2 and E8 notes on N01)
    _setup_exposure, nolog
    msm_fit, model(cox) exposure(cum_trt) tvcov(lag_trt) ///
        outcome_cov(age sex) vce(cluster id) nolog
    local fit_hr = exp(_b[cum_trt])
    msm_sensitivity, evalue
    assert reldif(r(effect), `fit_hr') < 1e-8
    assert !missing(r(evalue_point))

    * The rendered effect is a real one. Under the old degenerate spec the
    * exposure was omitted, so fit_hr was exp(0) == 1 and the E-value was 1:
    * this assertion is what distinguishes "sensitivity found the exposure"
    * from "sensitivity faithfully rendered a hole".
    assert abs(`fit_hr' - 1) > 1e-6
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

**# E8: an unidentified exposure is refused, not reported as a precise finding
*
* Regression for finding N01. msm 1.2.3 accepted exposure(cum_trt)
* tvcov(cum_comp), stored fitted state, and reported the exposure at
* b = -.01410812 with se = 0 exactly -- HR 0.986, CI [0.986, 0.986], p = . --
* because Stata had omitted the term as collinear and nothing checked. The
* zero-width CI is the tell, not the point estimate: the coefficient is not
* zero, so the result reads as a precisely measured small effect rather than
* as the hole it is. This probe fails on 1.2.3 (which returns rc=0) and passes
* once msm_fit verifies the exposure coefficient is estimable before committing
* any state.
*
* Note this spec is not merely degenerate in this fixture: msm_prepare
* requires binary treatment, so cum_trt + cum_comp == period + 1 in EVERY
* dataset msm accepts, and the pairing can never be identified in a Cox model.

local ++test_count
capture noisily {
    _setup_exposure, nolog

    * The trap is exact and structural, not a numerical near-miss.
    gen double _chk = cum_trt + cum_comp - (period + 1)
    quietly summarize _chk
    assert r(min) == 0 & r(max) == 0
    drop _chk

    capture msm_fit, model(cox) exposure(cum_trt) tvcov(cum_comp) ///
        outcome_cov(age sex) vce(cluster id) nolog
    local fit_rc = _rc
    assert `fit_rc' != 0

    * The refusal commits no fitted state.
    assert "`: char _dta[_msm_fitted]'" == ""
    assert "`: char _dta[_msm_fit_uuid]'" == ""
    capture confirm variable _msm_esample
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS E8: unidentified exposure refused, no state committed"
    local ++pass_count
}
else {
    display as error "  FAIL E8: unidentified exposure guard (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' E8"
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
