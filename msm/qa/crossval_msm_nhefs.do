*! crossval_msm_nhefs.do
*! Public NHEFS point-treatment parity against R ipw::ipwpoint and survey

version 16.0
clear all
set varabbrev off

capture log close _all
log using "crossval_msm_nhefs.log", replace text nomsg

local qa_dir "`c(pwd)'"
local pkg_dir "`qa_dir'/.."
local data_file "`qa_dir'/data/nhefs.dta"
local r_script "`qa_dir'/crossval_msm_nhefs.R"

do "`qa_dir'/_install_msm_isolated.do" "`pkg_dir'"

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

tempfile r_result
local r_result "`r_result'.dta"

**# External reference

**## R computes the reference from the tracked public NHEFS extract
local ++test_count
capture noisily {
    shell Rscript "`r_script'" "`data_file'" "`r_result'"
    confirm file "`r_result'"
    use "`r_result'", clear
    assert _N == 1566
    isid seqn
    assert !missing(r_weight, r_gain, r_gain_se, r_death_b, r_death_se)
    assert r_weight > 0 & r_weight < .
    assert r_gain_se > 0 & r_death_se > 0
}
if _rc == 0 {
    display as result "PASS N1: R produced a complete NHEFS reference"
    local ++pass_count
}
else {
    display as error "FAIL N1: R NHEFS reference (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' N1"
}

**# Package parity

**## Row-level stabilized weights match ipwpoint
local ++test_count
capture noisily {
    use "`data_file'", clear
    drop if missing(wt82_71)
    gen long id = seqn
    gen byte period = 0
    gen double age_sq = age^2
    gen double smokeintensity_sq = smokeintensity^2
    gen double smokeyrs_sq = smokeyrs^2
    gen double wt71_sq = wt71^2

    msm_prepare, id(id) period(period) treatment(qsmk) outcome(death) ///
        baseline_covariates(sex race age age_sq smokeintensity ///
            smokeintensity_sq smokeyrs smokeyrs_sq exercise active wt71 wt71_sq)
    msm_weight, treat_d_cov(sex race age age_sq smokeintensity ///
        smokeintensity_sq smokeyrs smokeyrs_sq exercise active wt71 wt71_sq) nolog

    merge 1:1 seqn using "`r_result'", assert(match) nogen
    gen double abs_weight_diff = abs(_msm_weight - r_weight)
    summarize abs_weight_diff, meanonly
    assert !missing(r(max))
    assert r(max) < 2e-6

    summarize _msm_weight, meanonly
    local stata_mean = r(mean)
    summarize r_weight_mean, meanonly
    assert abs(`stata_mean' - r(mean)) < 2e-8

    * Hernan and Robins, What If, Chapter 12: stabilized weights are centered
    * at 1.00. Program 12.3 reports SD approximately 0.288 for this model.
    assert abs(`stata_mean' - 1) < 0.01
    summarize _msm_weight
    assert abs(r(sd) - 0.288) < 0.03
}
if _rc == 0 {
    display as result "PASS N2: msm_weight matches ipwpoint row by row"
    local ++pass_count
}
else {
    display as error "FAIL N2: row-level NHEFS weights (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' N2"
}

**## Weighted smoking-cessation effect matches R and the published example
local ++test_count
capture noisily {
    use "`data_file'", clear
    drop if missing(wt82_71)
    gen long id = seqn
    gen byte period = 0
    gen double age_sq = age^2
    gen double smokeintensity_sq = smokeintensity^2
    gen double smokeyrs_sq = smokeyrs^2
    gen double wt71_sq = wt71^2

    msm_prepare, id(id) period(period) treatment(qsmk) outcome(death) ///
        baseline_covariates(sex race age age_sq smokeintensity ///
            smokeintensity_sq smokeyrs smokeyrs_sq exercise active wt71 wt71_sq)
    msm_weight, treat_d_cov(sex race age age_sq smokeintensity ///
        smokeintensity_sq smokeyrs smokeyrs_sq exercise active wt71 wt71_sq) nolog
    regress wt82_71 qsmk [pw=_msm_weight], vce(robust)
    local stata_gain = _b[qsmk]
    local stata_gain_se = _se[qsmk]

    frame create r_reference
    frame r_reference: use "`r_result'", clear
    frame r_reference: local r_gain = r_gain[1]
    frame r_reference: local r_gain_se = r_gain_se[1]
    frame drop r_reference

    assert abs(`stata_gain' - `r_gain') < 2e-6
    assert abs(`stata_gain_se' - `r_gain_se') < 2e-5
    assert abs(`stata_gain' - 3.44) < 0.05
    assert abs((`stata_gain' - invnormal(0.975) * `stata_gain_se') - 2.41) < 0.05
    assert abs((`stata_gain' + invnormal(0.975) * `stata_gain_se') - 4.47) < 0.05
}
if _rc == 0 {
    display as result "PASS N3: NHEFS weight-gain estimate matches R and the published answer"
    local ++pass_count
}
else {
    display as error "FAIL N3: NHEFS published effect (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' N3"
}

**## Package mortality MSM matches survey::svyglm
local ++test_count
capture noisily {
    use "`data_file'", clear
    drop if missing(wt82_71)
    gen long id = seqn
    gen byte period = 0
    gen double age_sq = age^2
    gen double smokeintensity_sq = smokeintensity^2
    gen double smokeyrs_sq = smokeyrs^2
    gen double wt71_sq = wt71^2

    msm_prepare, id(id) period(period) treatment(qsmk) outcome(death) ///
        baseline_covariates(sex race age age_sq smokeintensity ///
            smokeintensity_sq smokeyrs smokeyrs_sq exercise active wt71 wt71_sq)
    msm_weight, treat_d_cov(sex race age age_sq smokeintensity ///
        smokeintensity_sq smokeyrs smokeyrs_sq exercise active wt71 wt71_sq) nolog
    msm_fit, model(logistic) period_spec(none) nolog
    local stata_b = _b[qsmk]
    local stata_se = _se[qsmk]

    frame create r_reference
    frame r_reference: use "`r_result'", clear
    frame r_reference: local r_b = r_death_b[1]
    frame r_reference: local r_se = r_death_se[1]
    frame drop r_reference

    assert abs(`stata_b' - `r_b') < 2e-6
    assert abs(`stata_se' - `r_se') < 0.005
}
if _rc == 0 {
    display as result "PASS N4: mortality MSM matches the independent R survey fit"
    local ++pass_count
}
else {
    display as error "FAIL N4: NHEFS mortality parity (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' N4"
}

**# Summary

if `fail_count' > 0 display as error "Failed tests:`failed_tests'"
do "`qa_dir'/_record_qa_result.do" crossval_msm_nhefs ///
    `test_count' `pass_count' `fail_count' 0
display as text "RESULT: crossval_msm_nhefs tests=`test_count' pass=`pass_count' fail=`fail_count' skip=0"
capture log close _all
if `fail_count' > 0 exit 1
