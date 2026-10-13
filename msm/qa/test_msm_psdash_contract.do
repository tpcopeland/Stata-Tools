* test_msm_psdash_contract.do
* Verifies msm_weight persists the per-period treatment propensity score
* (_msm_ps) and the psdash contract chars, and that re-prepare clears them.
* msm 2.0.0 raises the contract to 1.1: _msm_risk_var names the decision risk
* set (TEST 5-7). psdash's side of the contract is exercised end to end in
* test_msm_companion_smoke.do.
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
do "`qa_dir'/_msm_qa_common.do"

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
    assert !missing(r(N))
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

* --- TEST 5: contract 1.1 names the decision risk set ---
local ++test_count
capture noisily {
    _mp_weight_example
    assert "`: char _dta[_msm_contract_version]'" == "1.1"
    local rv : char _dta[_msm_risk_var]
    assert "`rv'" == "_msm_decision_risk"
    confirm numeric variable `rv'
    assert inlist(`rv', 0, 1)
    * the signed weight contract covers the new field
    _msm_contract weight
    assert strpos(`"`r(contract)'"', "|_msm_risk_var=_msm_decision_risk") > 0
    quietly msm_prepare, id(id) period(period) treatment(treatment) ///
        outcome(outcome) covariates(biomarker comorbidity age sex)
    assert "`: char _dta[_msm_risk_var]'" == ""
}
if _rc {
    display as error "FAIL: contract_1_1_risk_var (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' contract_1_1_risk_var"
}
else {
    display as result "PASS: contract_1_1_risk_var"
    local ++pass_count
}

* --- TEST 6: editing _msm_risk_var breaks the weighting contract ---
local ++test_count
capture noisily {
    _mp_weight_example
    _msm_check_weighted
    char _dta[_msm_risk_var] "treatment"
    capture noisily _msm_check_weighted
    assert _rc != 0
    * positive control: restoring the value restores verification
    char _dta[_msm_risk_var] "_msm_decision_risk"
    _msm_check_weighted
}
if _rc {
    display as error "FAIL: risk_var_is_signed (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' risk_var_is_signed"
}
else {
    display as result "PASS: risk_var_is_signed"
    local ++pass_count
}

* --- TEST 7: a contract-1.0 weighting (msm 1.4.x dataset) still verifies ---
local ++test_count
capture noisily {
    use "`pkg_dir'/msm_example.dta", clear
    quietly msm_prepare, id(id) period(period) treatment(treatment) ///
        outcome(outcome) covariates(biomarker comorbidity age sex)
    gen double _msm_weight = 1
    gen double _msm_tw_weight = 1
    gen double _msm_ps = 0.5
    * _msm_qa_register_weights stamps contract 1.0 with no _msm_risk_var,
    * exactly as msm 1.4.12 did.
    _msm_qa_register_weights
    assert "`: char _dta[_msm_contract_version]'" == "1.0"
    assert "`: char _dta[_msm_risk_var]'" == ""
    _msm_contract weight
    assert strpos(`"`r(contract)'"', "_msm_risk_var") == 0
    _msm_check_weighted
}
if _rc {
    display as error "FAIL: contract_1_0_still_verifies (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' contract_1_0_still_verifies"
}
else {
    display as result "PASS: contract_1_0_still_verifies"
    local ++pass_count
}

display as text _n "=== msm psdash-contract summary: " ///
    as result `pass_count' as text " passed, " ///
    as error `fail_count' as text " failed ==="

capture log close _all

do "`qa_dir'/_record_qa_result.do" test_msm_psdash_contract ///
    `test_count' `pass_count' `fail_count' 0
display as text "RESULT: test_msm_psdash_contract tests=`test_count' pass=`pass_count' fail=`fail_count' skip=0"
if `fail_count' > 0 {
    display as error "Failed tests:`failed_tests'"
    exit 9
}
