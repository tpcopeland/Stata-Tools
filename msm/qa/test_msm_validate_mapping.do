* test_msm_validate_mapping.do
* msm 2.0.0 removed msm_validate. Each of its ten checks now lives in a core
* command (see the mapping table in qa/README.md). One test per check proves
* the core command still catches what msm_validate reported.

version 16.0
clear all
set more off
set varabbrev off

local qa_dir  "`c(pwd)'"
local pkg_dir "`qa_dir'/.."

capture log close _all
log using "test_msm_validate_mapping.log", replace text nomsg

do "`qa_dir'/_install_msm_isolated.do" "`pkg_dir'"

local pass_count = 0
local fail_count = 0
local test_count = 0
local failed_tests ""
local d "`pkg_dir'/msm_example.dta"

capture program drop _vm_prep
program define _vm_prep
    msm_prepare, id(id) period(period) treatment(treatment) outcome(outcome) ///
        censor(censored) covariates(biomarker comorbidity) baseline_covariates(age sex)
end
capture program drop _vm_weight
program define _vm_weight
    msm_weight, treat_d_cov(biomarker comorbidity age sex) treat_n_cov(age sex) ///
        censor_d_cov(biomarker comorbidity age sex) censor_n_cov(age sex) nolog
end

**# V1 (check 1): duplicate id-period rows are refused by msm_prepare
local ++test_count
capture noisily {
    use "`d'", clear
    expand 2 in 5
    capture noisily _vm_prep
    assert _rc == 198
    assert "`: char _dta[_msm_prepared]'" == ""
}
if _rc == 0 {
    display as result "PASS V1: duplicates refused"
    local ++pass_count
}
else {
    display as error "FAIL V1 (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' V1"
}

**# V2 (check 2): gaps are reported by msm_prepare and refused by msm_weight
local ++test_count
capture noisily {
    use "`d'", clear
    * interior gaps in the first two ids followed beyond period 5
    bysort id: egen _maxp = max(period)
    quietly levelsof id if _maxp >= 5, local(_long)
    local _g1 : word 1 of `_long'
    local _g2 : word 2 of `_long'
    drop if inlist(id, `_g1', `_g2') & period == 4
    drop _maxp
    _vm_prep
    assert r(n_gap_ids) == 2
    capture noisily _vm_weight
    assert _rc == 459
    use "`d'", clear
    _vm_prep
    assert r(n_gap_ids) == 0
}
if _rc == 0 {
    display as result "PASS V2: gaps reported and refused"
    local ++pass_count
}
else {
    display as error "FAIL V2 (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' V2"
}

**# V3 (checks 3 and 9): post-event and post-censoring rows leave the risk set
local ++test_count
capture noisily {
    use "`d'", clear
    quietly {
        bysort id (period): gen byte _ev = sum(outcome)
        by id: gen byte _f = outcome == 1 & _ev == 1
        expand 3 if _f, generate(_dup)
        bysort id (period _dup): replace period = period[_n-1] + 1 if _dup
        replace outcome = 1 if _dup
        drop _ev _f _dup
    }
    quietly count
    local n_all = r(N)
    _vm_prep
    _vm_weight
    quietly count if !_msm_decision_risk
    assert r(N) > 0
    * 1.4.12 reference: 4,586 decision-risk rows in msm_example.dta
    quietly count if _msm_decision_risk
    assert r(N) == 4586
}
if _rc == 0 {
    display as result "PASS V3: post-event rows excluded by _msm_decision_risk"
    local ++pass_count
}
else {
    display as error "FAIL V3 (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' V3"
}

**# V4 (check 4): no treatment variation is refused by msm_weight
local ++test_count
capture noisily {
    use "`d'", clear
    replace treatment = 0
    _vm_prep
    capture noisily _vm_weight
    assert _rc == 498
    assert "`: char _dta[_msm_weighted]'" == ""
}
if _rc == 0 {
    display as result "PASS V4: no treatment variation refused"
    local ++pass_count
}
else {
    display as error "FAIL V4 (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' V4"
}

**# V5 (check 5): missing values are reported, refused for model inputs
local ++test_count
capture noisily {
    foreach v in treatment censored biomarker {
        use "`d'", clear
        replace `v' = . in 7
        _vm_prep
        assert "`r(missing_vars)'" == "`v'"
        capture noisily _vm_weight
        assert _rc == 459
    }
    * missing id and period are refused at preparation
    foreach v in id period {
        use "`d'", clear
        replace `v' = . in 7
        capture noisily _vm_prep
        assert _rc == 198
    }
    * a missing outcome is reported and kept out of the fitted risk set
    use "`d'", clear
    replace outcome = . in 7
    _vm_prep
    assert "`r(missing_vars)'" == "outcome"
    _vm_weight
    quietly msm_fit, model(logistic) outcome_cov(age sex) nolog
    assert _msm_esample == 0 in 7
}
if _rc == 0 {
    display as result "PASS V5: missing values reported and refused"
    local ++pass_count
}
else {
    display as error "FAIL V5 (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' V5"
}

**# V6 (check 6): a sparse period is reported by msm_prepare
local ++test_count
capture noisily {
    use "`d'", clear
    quietly count if period == 9 & id <= 5
    local _left = r(N)
    assert `_left' > 0 & `_left' < 10
    drop if period == 9 & id > 5
    _vm_prep
    assert r(min_period_n) == `_left'
    use "`d'", clear
    _vm_prep
    assert r(min_period_n) >= 10
}
if _rc == 0 {
    display as result "PASS V6: sparse period reported"
    local ++pass_count
}
else {
    display as error "FAIL V6 (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' V6"
}

**# V7 (check 7): constant and all-missing covariates
local ++test_count
capture noisily {
    use "`d'", clear
    replace comorbidity = 1
    _vm_prep
    assert "`r(constant_covariates)'" == "comorbidity"
    use "`d'", clear
    replace comorbidity = .
    _vm_prep
    assert "`r(missing_vars)'" == "comorbidity"
    capture noisily _vm_weight
    assert _rc == 459
}
if _rc == 0 {
    display as result "PASS V7: constant and empty covariates"
    local ++pass_count
}
else {
    display as error "FAIL V7 (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' V7"
}

**# V8 (check 10): a period with no treated row is flagged by msm_diagnose
local ++test_count
capture noisily {
    use "`d'", clear
    replace treatment = 0 if period == 4
    _vm_prep
    _vm_weight
    msm_diagnose
    assert r(n_support_violations) == 1
    assert "`r(support_violation_periods)'" == "4"
    * the observed-decision floor alone does not see it
    assert r(n_positivity_violations) == 0
    use "`d'", clear
    _vm_prep
    _vm_weight
    msm_diagnose
    assert r(n_support_violations) == 0
    assert "`r(support_violation_periods)'" == ""
}
if _rc == 0 {
    display as result "PASS V8: no-contrast period flagged"
    local ++pass_count
}
else {
    display as error "FAIL V8 (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' V8"
}

**# V9: non-binary treatment and non-integer periods are refused (pre-checks)
local ++test_count
capture noisily {
    use "`d'", clear
    replace treatment = 2 in 3
    capture noisily _vm_prep
    assert _rc == 198
    use "`d'", clear
    replace period = period + 0.5 if id == 2
    capture noisily _vm_prep
    assert _rc == 198
}
if _rc == 0 {
    display as result "PASS V9: value refusals"
    local ++pass_count
}
else {
    display as error "FAIL V9 (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' V9"
}

**# Summary
if `fail_count' > 0 display as error "Failed tests:`failed_tests'"
do "`qa_dir'/_record_qa_result.do" test_msm_validate_mapping ///
    `test_count' `pass_count' `fail_count' 0
display as text "RESULT: test_msm_validate_mapping tests=`test_count' pass=`pass_count' fail=`fail_count' skip=0"
capture log close _all
if `fail_count' > 0 exit 1
