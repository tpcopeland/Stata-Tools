* validate_edge_cases.do — V8: Pipeline Guards & Edge Cases
* Tests prerequisite failures, input validation, and weight replace behavior
* No external data dependencies

version 16.0
set more off
set varabbrev off

local qa_dir "/home/tpcopeland/Stata-Dev/msm/qa"
adopath ++ "/home/tpcopeland/Stata-Dev/msm"

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

display "V8: PIPELINE GUARDS & EDGE CASES"
display "Date: $S_DATE $S_TIME"
display ""

* =========================================================================
* Create minimal test dataset
* =========================================================================
capture program drop _v8_make_data
program define _v8_make_data
    version 16.0
    clear
    set obs 500
    gen long id = ceil(_n / 10)
    bysort id: gen int period = _n - 1
    set seed 80801
    gen double age = rnormal(50, 10)
    gen byte sex = runiform() < 0.5
    gen double xb = -2 + 0.02 * age - 0.3 * sex
    gen byte treatment = runiform() < invlogit(xb)
    gen double yxb = -3 + 0.5 * treatment + 0.01 * age
    gen byte outcome = runiform() < invlogit(yxb)
    gen byte censored = runiform() < 0.03
    drop xb yxb
end

* =========================================================================
* Test 8.1: msm_validate fails without msm_prepare
* =========================================================================
local ++test_count
capture {
    _v8_make_data
    capture msm_validate
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS 8.1: validate fails without prepare"
    local ++pass_count
}
else {
    display as error "  FAIL 8.1: validate should fail without prepare (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 8.1"
}

* =========================================================================
* Test 8.2: msm_weight fails without msm_prepare
* =========================================================================
local ++test_count
capture {
    _v8_make_data
    capture msm_weight, treat_d_cov(age sex) nolog
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS 8.2: weight fails without prepare"
    local ++pass_count
}
else {
    display as error "  FAIL 8.2: weight should fail without prepare (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 8.2"
}

* =========================================================================
* Test 8.3: msm_fit fails without msm_weight
* =========================================================================
local ++test_count
capture {
    _v8_make_data
    msm_prepare, id(id) period(period) treatment(treatment) outcome(outcome)
    capture msm_fit, model(logistic) nolog
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS 8.3: fit fails without weight"
    local ++pass_count
}
else {
    display as error "  FAIL 8.3: fit should fail without weight (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 8.3"
}

* =========================================================================
* Test 8.4: msm_predict fails without msm_fit
* =========================================================================
local ++test_count
capture {
    _v8_make_data
    msm_prepare, id(id) period(period) treatment(treatment) outcome(outcome) ///
        covariates(age)
    msm_weight, treat_d_cov(age) nolog
    capture msm_predict, times(5) samples(10) seed(1)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS 8.4: predict fails without fit"
    local ++pass_count
}
else {
    display as error "  FAIL 8.4: predict should fail without fit (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 8.4"
}

* =========================================================================
* Test 8.5: msm_prepare rejects non-binary treatment
* =========================================================================
local ++test_count
capture {
    _v8_make_data
    replace treatment = 2 in 1
    capture msm_prepare, id(id) period(period) treatment(treatment) outcome(outcome)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS 8.5: rejects non-binary treatment"
    local ++pass_count
}
else {
    display as error "  FAIL 8.5: should reject non-binary treatment (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 8.5"
}

* =========================================================================
* Test 8.6: msm_prepare rejects duplicate id-period
* =========================================================================
local ++test_count
capture {
    _v8_make_data
    * Create a duplicate row
    local N = _N
    set obs `=`N'+1'
    replace id = id[1] in `=`N'+1'
    replace period = period[1] in `=`N'+1'
    replace treatment = 0 in `=`N'+1'
    replace outcome = 0 in `=`N'+1'
    replace age = 50 in `=`N'+1'
    replace sex = 0 in `=`N'+1'

    capture msm_prepare, id(id) period(period) treatment(treatment) outcome(outcome)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS 8.6: rejects duplicate id-period"
    local ++pass_count
}
else {
    display as error "  FAIL 8.6: should reject duplicate id-period (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 8.6"
}

* =========================================================================
* Test 8.7: msm_weight replace option
* =========================================================================
local ++test_count
capture {
    _v8_make_data
    msm_prepare, id(id) period(period) treatment(treatment) outcome(outcome) ///
        covariates(age) baseline_covariates(sex)
    msm_weight, treat_d_cov(age sex) treat_n_cov(sex) nolog

    * Second call without replace should fail
    capture msm_weight, treat_d_cov(age sex) treat_n_cov(sex) nolog
    local rc_no_replace = _rc
    assert `rc_no_replace' == 110

    * Second call with replace should succeed
    msm_weight, treat_d_cov(age sex) treat_n_cov(sex) nolog replace
    confirm variable _msm_weight
}
if _rc == 0 {
    display as result "  PASS 8.7: weight replace option works"
    local ++pass_count
}
else {
    display as error "  FAIL 8.7: weight replace behavior (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 8.7"
}

* =========================================================================
* Test 8.8: msm_diagnose fails without weights
* =========================================================================
local ++test_count
capture {
    _v8_make_data
    msm_prepare, id(id) period(period) treatment(treatment) outcome(outcome)
    capture msm_diagnose
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS 8.8: diagnose fails without weights"
    local ++pass_count
}
else {
    display as error "  FAIL 8.8: diagnose should fail without weights (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 8.8"
}

* =========================================================================
* SUMMARY
* =========================================================================
display ""
display "V8: EDGE CASES SUMMARY"
display "Total tests:  `test_count'"
display "Passed:       `pass_count'"
if `fail_count' > 0 {
    display as error "Failed:       `fail_count'"
    display as error "Failed tests:`failed_tests'"
}
else {
    display "Failed:       `fail_count'"
}

local v_status = cond(`fail_count' > 0, "FAIL", "PASS")
display ""
display "RESULT: V8 tests=`test_count' pass=`pass_count' fail=`fail_count' status=`v_status'"
display ""
display "Completed: $S_DATE $S_TIME"

if `fail_count' > 0 {
    exit 1
}
