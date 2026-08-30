*! crossval_msm_haart.do
*! Public HAART longitudinal IPTW/IPCW parity and JSS worked-example anchors

version 16.0
clear all
set varabbrev off

capture log close _all
log using "crossval_msm_haart.log", replace text nomsg

local qa_dir "`c(pwd)'"
local pkg_dir "`qa_dir'/.."
local data_file "`qa_dir'/data/haartdat.dta"
local r_script "`qa_dir'/crossval_msm_haart.R"

do "`qa_dir'/_install_msm_isolated.do" "`pkg_dir'"

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

tempfile r_result
local r_result "`r_result'.dta"

**# Published R example

**## R reproduces the JSS HAART worked example
local ++test_count
capture noisily {
    shell Rscript "`r_script'" "`data_file'" "`r_result'"
    confirm file "`r_result'"
    use "`r_result'", clear
    assert _N == 19175
    isid patient tstart
    assert !missing(r_tw_weight, r_cw_weight, r_weight)
    assert r_tw_weight > 0 & r_cw_weight > 0 & r_weight > 0

    * van der Wal and Geskus (2011), JSS 43(13), pp. 14-16.
    assert abs(paper_treat_mean[1] - 1.0390) < 0.0001
    assert abs(paper_treat_max[1] - 7.1260) < 0.001
    assert abs(paper_b[1] - (-0.9378)) < 0.0002
    assert abs(paper_hr[1] - 0.3915) < 0.0002
    assert abs(paper_se[1] - 0.4524) < 0.0002
}
if _rc == 0 {
    display as result "PASS H1: R reproduces the published HAART worked example"
    local ++pass_count
}
else {
    display as error "FAIL H1: published HAART reproduction (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' H1"
}

**# Package-aligned parity

**## Joint treatment and censoring weights match independent pooled logits
local ++test_count
capture noisily {
    use "`data_file'", clear
    sort patient tstart
    by patient: gen int period = _n - 1
    gen long id = patient
    gen byte treatment = haartind
    gen byte outcome = event
    gen byte censor = dropout

    msm_prepare, id(id) period(period) treatment(treatment) outcome(outcome) ///
        censor(censor) covariates(cd4_sqrt) baseline_covariates(sex age)
    msm_weight, treat_d_cov(cd4_sqrt sex age) treat_n_cov(sex age) ///
        censor_d_cov(cd4_sqrt sex age) censor_n_cov(sex age) ///
        period_d_spec(linear) period_n_spec(linear) ///
        probpolicy(clip) clip(0.001) nolog

    merge 1:1 patient tstart using "`r_result'", assert(match) nogen
    gen double diff_tw = abs(_msm_tw_weight - r_tw_weight)
    gen double diff_cw = abs(_msm_cw_weight - r_cw_weight)
    gen double diff_joint = abs(_msm_weight - r_weight)
    summarize diff_tw, meanonly
    assert !missing(r(max))
    assert r(max) < 2e-5
    summarize diff_cw, meanonly
    assert !missing(r(max))
    assert r(max) < 2e-5
    summarize diff_joint, meanonly
    assert !missing(r(max))
    assert r(max) < 5e-5

    gen double product_diff = abs(_msm_weight - _msm_tw_weight * _msm_cw_weight)
    summarize product_diff, meanonly
    assert r(max) < 1e-12
    assert !missing(_msm_cw_weight) if dropout == 1
}
if _rc == 0 {
    display as result "PASS H2: msm joint weights match independent pooled-logit weights"
    local ++pass_count
}
else {
    display as error "FAIL H2: HAART row-level joint weights (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' H2"
}

**## Weighted Cox MSM matches survival::coxph on the same joint weights
local ++test_count
capture noisily {
    use "`data_file'", clear
    sort patient tstart
    by patient: gen int period = _n - 1
    gen long id = patient
    gen byte treatment = haartind
    gen byte outcome = event
    gen byte censor = dropout

    msm_prepare, id(id) period(period) treatment(treatment) outcome(outcome) ///
        censor(censor) covariates(cd4_sqrt) baseline_covariates(sex age)
    msm_weight, treat_d_cov(cd4_sqrt sex age) treat_n_cov(sex age) ///
        censor_d_cov(cd4_sqrt sex age) censor_n_cov(sex age) ///
        period_d_spec(linear) period_n_spec(linear) ///
        probpolicy(clip) clip(0.001) nolog
    msm_fit, model(cox) outcome_cov(sex age) nolog
    local stata_b = _b[treatment]
    local stata_se = _se[treatment]

    frame create r_reference
    frame r_reference: use "`r_result'", clear
    frame r_reference: local r_b = aligned_b[1]
    frame r_reference: local r_se = aligned_se[1]
    frame drop r_reference

    assert abs(`stata_b' - `r_b') < 2e-5
    assert abs(`stata_se' - `r_se') < 0.005
    assert `stata_b' < 0
}
if _rc == 0 {
    display as result "PASS H3: HAART weighted Cox model matches survival::coxph"
    local ++pass_count
}
else {
    display as error "FAIL H3: HAART Cox parity (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' H3"
}

**## Study and package specifications agree on direction and interval scale
local ++test_count
capture noisily {
    use "`r_result'", clear
    assert paper_b[1] < 0
    assert paper_hr[1] > 0 & paper_hr[1] < 1
    assert aligned_b[1] < 0
    assert exp(aligned_b[1]) > 0 & exp(aligned_b[1]) < 1
    * The allocation models differ (paper: Cox initiation; package: pooled
    * logistic), so exact point parity is not the contract. The published
    * log-HR must lie inside the package-aligned model's 95% interval.
    assert paper_b[1] > aligned_b[1] - invnormal(0.975) * aligned_se[1]
    assert paper_b[1] < aligned_b[1] + invnormal(0.975) * aligned_se[1]
}
if _rc == 0 {
    display as result "PASS H4: HAART direction and confidence-interval scale agree"
    local ++pass_count
}
else {
    display as error "FAIL H4: HAART direction and interval scale (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' H4"
}

**# Summary

if `fail_count' > 0 display as error "Failed tests:`failed_tests'"
do "`qa_dir'/_record_qa_result.do" crossval_msm_haart ///
    `test_count' `pass_count' `fail_count' 0
display as text "RESULT: crossval_msm_haart tests=`test_count' pass=`pass_count' fail=`fail_count' skip=0"
capture log close _all
if `fail_count' > 0 exit 1
