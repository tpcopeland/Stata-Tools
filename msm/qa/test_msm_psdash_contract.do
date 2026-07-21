* test_msm_psdash_contract.do
* Verifies msm_weight persists the per-period treatment propensity score
* (_msm_ps) and the psdash contract chars, and that re-prepare clears them.
* Usage: cd msm/qa && stata-mp -b do test_msm_psdash_contract.do

version 16.0
clear all
set more off
set varabbrev off

capture log close _all
log using "test_msm_psdash_contract.log", replace nomsg

local qa_dir  "`c(pwd)'"
local pkg_dir "`qa_dir'/.."

do "`qa_dir'/_install_msm_isolated.do" "`pkg_dir'"

local pass_count = 0
local fail_count = 0
local test_count = 0
local failed_tests ""

capture program drop _mp_weight_example
program define _mp_weight_example
    version 16.0
    local pkg_dir "`c(pwd)'/.."
    use "`pkg_dir'/msm_example.dta", clear
    quietly msm_prepare, id(id) period(period) treatment(treatment) ///
        outcome(outcome) covariates(biomarker comorbidity age sex)
    quietly msm_weight, treat_d_cov(biomarker comorbidity age sex) ///
        treat_n_cov(age sex) nolog
end

* --- TEST 1: _msm_ps persists and is a valid probability on at-risk rows ---
local ++test_count
capture noisily {
    _mp_weight_example
    confirm variable _msm_ps
    quietly count if !missing(_msm_ps)
    assert r(N) > 0
    quietly count if !missing(_msm_ps) & (_msm_ps < 0 | _msm_ps > 1)
    assert r(N) == 0
}
if _rc {
    display as error "FAIL: msm_ps_persists_valid_probability (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' msm_ps_persists_valid_probability"
}
else {
    display as result "PASS: msm_ps_persists_valid_probability"
    local ++pass_count
}

* --- TEST 2: psdash contract chars are populated ---
local ++test_count
capture noisily {
    _mp_weight_example
    assert "`: char _dta[_msm_ps_var]'" == "_msm_ps"
    assert "`: char _dta[_msm_tw_var]'" == "_msm_tw_weight"
    assert "`: char _dta[_msm_estimand]'" == "ate"
    assert "`: char _dta[_msm_contract_version]'" != ""
    assert "`: char _dta[_msm_weighted]'" == "1"
}
if _rc {
    display as error "FAIL: msm_psdash_contract_chars_set (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' msm_psdash_contract_chars_set"
}
else {
    display as result "PASS: msm_psdash_contract_chars_set"
    local ++pass_count
}

* --- TEST 3: re-prepare clears _msm_ps variable and its chars ---
local ++test_count
capture noisily {
    _mp_weight_example
    quietly msm_prepare, id(id) period(period) treatment(treatment) ///
        outcome(outcome) covariates(biomarker comorbidity age sex)
    capture confirm variable _msm_ps
    assert _rc != 0
    assert "`: char _dta[_msm_ps_var]'" == ""
    assert "`: char _dta[_msm_estimand]'" == ""
    assert "`: char _dta[_msm_contract_version]'" == ""
}
if _rc {
    display as error "FAIL: reprepare_clears_msm_ps (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' reprepare_clears_msm_ps"
}
else {
    display as result "PASS: reprepare_clears_msm_ps"
    local ++pass_count
}

* --- TEST 4: rerun without replace is refused once _msm_ps exists ---
local ++test_count
capture noisily {
    _mp_weight_example
    capture msm_weight, treat_d_cov(biomarker comorbidity age sex) ///
        treat_n_cov(age sex) nolog
    assert _rc == 110
    * with replace it succeeds and _msm_ps is regenerated
    quietly msm_weight, treat_d_cov(biomarker comorbidity age sex) ///
        treat_n_cov(age sex) nolog replace
    confirm variable _msm_ps
}
if _rc {
    display as error "FAIL: msm_ps_replace_guard (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' msm_ps_replace_guard"
}
else {
    display as result "PASS: msm_ps_replace_guard"
    local ++pass_count
}

display as text _n "=== msm psdash-contract summary: " ///
    as result `pass_count' as text " passed, " ///
    as error `fail_count' as text " failed ==="

capture log close _all

display as text "RESULT: test_msm_psdash_contract tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 {
    display as error "Failed tests:`failed_tests'"
    exit 9
}
