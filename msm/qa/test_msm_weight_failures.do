* test_msm_weight_failures.do
* Focused QA for msm_weight model-fit failure handling.
*
* Location: msm/qa/

version 16.0
clear all
set more off
set varabbrev off

local qa_dir  "`c(pwd)'"
local pkg_dir "`qa_dir'/.."

capture ado uninstall msm
quietly net install msm, from("`pkg_dir'") replace
adopath ++ "`pkg_dir'"

local pass_count = 0
local fail_count = 0
local test_count = 0
local failed_tests ""

capture program drop _mw_make_treat_fail_data
program define _mw_make_treat_fail_data
    version 16.0

    clear
    set seed 13579
    set obs 320
    gen long id = ceil(_n / 4)
    bysort id: gen byte period = _n - 1

    gen double age = 40 + mod(id, 12)
    gen byte sex = mod(id, 2)
    gen double L = rnormal() + 0.30 * period + 0.50 * sex

    * Baseline treatment varies, but post-baseline treatment is constant.
    gen double p_base = invlogit(-0.6 + 0.35 * sex - 0.02 * age + 0.30 * L)
    gen byte treatment = .
    replace treatment = runiform() < p_base if period == 0
    replace treatment = 0 if period > 0
    drop p_base
    gen byte outcome = 0

    msm_prepare, id(id) period(period) treatment(treatment) outcome(outcome) ///
        covariates(L) baseline_covariates(age sex)
end

capture program drop _mw_make_censor_fail_data
program define _mw_make_censor_fail_data
    version 16.0

    clear
    set seed 24680
    set obs 360
    gen long id = ceil(_n / 6)
    bysort id: gen byte period = _n - 1

    gen double age = 35 + mod(id, 15)
    gen byte sex = mod(id, 2)
    gen double L = rnormal() + 0.20 * period + 0.40 * sex
    gen double p_treat = invlogit(-0.8 + 0.5 * sex + 0.25 * period + 0.4 * L)
    gen byte treatment = runiform() < p_treat
    drop p_treat

    * No censoring events forces censoring models to fail.
    gen byte censor = 0
    gen byte outcome = 0

    msm_prepare, id(id) period(period) treatment(treatment) outcome(outcome) ///
        censor(censor) covariates(L) baseline_covariates(age sex)
end

display as text ""
display as text "{hline 72}"
display as result "msm_weight failure-policy QA"
display as text "{hline 72}"

* --- WFAIL1: default policy hard-fails on treatment model failure ---
local ++test_count
capture noisily {
    _mw_make_treat_fail_data

    capture msm_weight, treat_d_cov(L age sex) treat_n_cov(age sex) nolog
    local rc = _rc

    assert `rc' == 498
    capture confirm variable _msm_weight
    assert _rc != 0
    capture confirm variable _msm_tw_weight
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS WFAIL1: default policy rejects treatment-model failure"
    local ++pass_count
}
else {
    display as error "  FAIL WFAIL1: default treatment failure policy (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' WFAIL1"
}

* --- WFAIL2: fitfailure(marginal) explicitly enables treatment fallback ---
local ++test_count
capture noisily {
    _mw_make_treat_fail_data

    msm_weight, treat_d_cov(L age sex) treat_n_cov(age sex) ///
        fitfailure(marginal) nolog

    assert r(fitfailure_fallback) == 1
    assert r(n_fitfail_fallback) == 2
    assert "`r(fitfailure_policy)'" == "marginal"

    local models " `r(fitfailure_models)' "
    assert strpos("`models'", " treatment_denominator ") > 0
    assert strpos("`models'", " treatment_numerator ") > 0

    confirm variable _msm_weight
    confirm variable _msm_tw_weight
    quietly count if missing(_msm_weight)
    assert r(N) == 0
    quietly summarize _msm_weight
    assert r(min) > 0
}
if _rc == 0 {
    display as result "  PASS WFAIL2: explicit treatment fallback succeeds and reports usage"
    local ++pass_count
}
else {
    display as error "  FAIL WFAIL2: explicit treatment fallback (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' WFAIL2"
}

* --- WFAIL3: default policy hard-fails on censoring model failure ---
local ++test_count
capture noisily {
    _mw_make_censor_fail_data

    capture msm_weight, treat_d_cov(L age sex) treat_n_cov(age sex) ///
        censor_d_cov(L age sex) censor_n_cov(age sex) nolog
    local rc = _rc

    assert `rc' == 498
    capture confirm variable _msm_weight
    assert _rc != 0
    capture confirm variable _msm_cw_weight
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS WFAIL3: default policy rejects censoring-model failure"
    local ++pass_count
}
else {
    display as error "  FAIL WFAIL3: default censor failure policy (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' WFAIL3"
}

* --- WFAIL4: fitfailure(marginal) explicitly enables censor fallback ---
local ++test_count
capture noisily {
    _mw_make_censor_fail_data

    msm_weight, treat_d_cov(L age sex) treat_n_cov(age sex) ///
        censor_d_cov(L age sex) censor_n_cov(age sex) ///
        fitfailure(marginal) nolog

    assert r(fitfailure_fallback) == 1
    assert r(n_fitfail_fallback) == 2
    assert "`r(fitfailure_policy)'" == "marginal"

    local models " `r(fitfailure_models)' "
    assert strpos("`models'", " censor_denominator ") > 0
    assert strpos("`models'", " censor_numerator ") > 0

    confirm variable _msm_weight
    confirm variable _msm_cw_weight
    quietly count if missing(_msm_cw_weight)
    assert r(N) == 0
    quietly summarize _msm_cw_weight
    assert r(min) > 0
}
if _rc == 0 {
    display as result "  PASS WFAIL4: explicit censor fallback succeeds and reports usage"
    local ++pass_count
}
else {
    display as error "  FAIL WFAIL4: explicit censor fallback (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' WFAIL4"
}

display as text ""
display as text "{hline 72}"
display as text "Tests run: " as result `test_count'
display as text "Passed:    " as result `pass_count'
display as text "Failed:    " as result `fail_count'
if `fail_count' > 0 {
    display as error "Failed tests:`failed_tests'"
    display as text "{hline 72}"
    exit 459
}
display as result "All msm_weight failure-policy tests passed"
display as text "{hline 72}"
