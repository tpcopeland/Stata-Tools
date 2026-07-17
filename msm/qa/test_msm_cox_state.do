* test_msm_cox_state.do - Cox stset state preservation regression tests
* Location: msm/qa/

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

capture program drop _setup_pipeline
program define _setup_pipeline
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
end

* --- TEST 1: clean dataset remains unstset after Cox fit ---
local ++test_count
capture noisily {
    _setup_pipeline, nolog
    msm_fit, model(cox) outcome_cov(age sex) nolog

    local dataset_tag : char _dta[_dta]
    assert `"`dataset_tag'"' == ""

    foreach c in st_ver st_id st_bt st_bd st_o st_s st_bs ///
        st_enter st_enexp st_w st_wv st_wt st_ifexp st_d st_t0 st_t {
        local current : char _dta[`c']
        assert `"`current'"' == ""
    }

    foreach v in _st _d _t _t0 {
        capture confirm variable `v'
        assert _rc != 0
    }

    tempvar esample
    gen byte `esample' = e(sample)
    assert _msm_esample == `esample'
    quietly count if `esample'
    assert r(N) > 0
}
if _rc == 0 {
    display as result "  PASS C1: Cox fit leaves previously unstset data unstset"
    local ++pass_count
}
else {
    display as error "  FAIL C1: clean-state Cox preservation (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' C1"
}

* --- TEST 2: pre-existing stset is restored exactly after Cox fit ---
local ++test_count
capture noisily {
    _setup_pipeline, nolog

    bysort id (period): gen double prior_enter = period
    gen double prior_exit = period + 1
    bysort id (period): gen byte prior_fail = (_n == _N)
    bysort id: gen double prior_w = 1 + id[1] / 1000000

    stset prior_exit [pw=prior_w], ///
        enter(prior_enter) failure(prior_fail) id(id)

    local before_dataset_tag : char _dta[_dta]
    foreach c in st_ver st_id st_bt st_bd st_o st_s st_bs ///
        st_enter st_enexp st_w st_wv st_wt st_ifexp st_d st_t0 st_t {
        local before_`c' : char _dta[`c']
    }

    gen double prior_t_before = _t
    gen double prior_t0_before = _t0
    gen byte prior_d_before = _d
    gen byte prior_st_before = _st

    msm_fit, model(cox) outcome_cov(age sex) nolog

    local after_dataset_tag : char _dta[_dta]
    assert `"`after_dataset_tag'"' == `"`before_dataset_tag'"'
    foreach c in st_ver st_id st_bt st_bd st_o st_s st_bs ///
        st_enter st_enexp st_w st_wv st_wt st_ifexp st_d st_t0 st_t {
        local after : char _dta[`c']
        local expected `"`before_`c''"'
        assert `"`after'"' == `"`expected'"'
    }

    assert _t == prior_t_before
    assert _t0 == prior_t0_before
    assert _d == prior_d_before
    assert _st == prior_st_before

    tempvar esample
    gen byte `esample' = e(sample)
    assert _msm_esample == `esample'
    quietly count if `esample'
    assert r(N) > 0
}
if _rc == 0 {
    display as result "  PASS C2: Cox fit restores caller-owned stset state"
    local ++pass_count
}
else {
    display as error "  FAIL C2: pre-existing stset restoration (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' C2"
}

local qa_status = cond(`fail_count' > 0, "FAIL", "PASS")
display as text ""
display as text "RESULT: test_msm_cox_state tests=`test_count' pass=`pass_count' fail=`fail_count' status=`qa_status'"
if `fail_count' > 0 {
    display as error "FAILED TESTS:`failed_tests'"
    exit 9
}
