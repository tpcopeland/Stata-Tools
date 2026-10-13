*! crossval_msm_predict.do
*! External R oracle for msm_predict: standardized risks, risk difference,
*! fitted risk set, clustered covariance, and Monte Carlo percentile intervals

version 16.0
clear all
set varabbrev off

capture log close _all
log using "crossval_msm_predict.log", replace text nomsg

local qa_dir "`c(pwd)'"
local pkg_dir "`qa_dir'/.."
local r_script "`qa_dir'/crossval_msm_predict.R"
local haart_file "`qa_dir'/data/haartdat.dta"

do "`qa_dir'/_install_msm_isolated.do" "`pkg_dir'"

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

* Point risks and RDs are deterministic given the weights: 1e-6 absolute.
* Monte Carlo limits use different RNGs: |Stata - R| must be under 10% of the
* interval half-width (about 7 Monte Carlo SDs at samples(20000)).
local tol_point = 1e-6
local mc_samples = 20000

capture program drop _cv_predict_compare
program define _cv_predict_compare
    syntax , rscript(string) spec(string) covs(string) history(string) ///
        times(numlist) samples(integer) tolpoint(real) [knots(string)]

    * Exported analysis rows: the R side re-derives the risk set itself.
    local _id : char _dta[_msm_id]
    local _period : char _dta[_msm_period]
    local _treat : char _dta[_msm_treatment]
    local _out : char _dta[_msm_outcome]
    local _cens : char _dta[_msm_censor]
    if "`knots'" == "" local knots "none"

    msm_predict, times(`times') difference samples(`samples') seed(20261013)
    tempname P
    matrix `P' = r(predictions)
    local n_ref = r(n_ref)

    tempfile exp_dta ref_dta
    local exp_dta "`exp_dta'.dta"
    local ref_dta "`ref_dta'.dta"
    local rows_dta : subinstr local ref_dta ".dta" "_rows.dta"
    local covkeep = cond("`covs'" == "none", "", "`covs'")
    preserve
    keep `_id' `_period' `_treat' `_out' `_cens' `covkeep' _msm_weight _msm_esample
    rename (`_id' `_period' `_treat' `_out') (id period treatment outcome)
    if "`_cens'" != "" rename `_cens' censor
    rename _msm_weight weight
    quietly save "`exp_dta'", replace
    restore

    local seed_r = 20261013
    shell Rscript "`rscript'" "`exp_dta'" "`ref_dta'" "`spec'" "`covs'" ///
        "`history'" "`knots'" "`times'" "`samples'" "`seed_r'"
    confirm file "`ref_dta'"

    * The R-derived fitted risk set equals _msm_esample row for row.
    preserve
    keep `_id' `_period' _msm_esample
    rename (`_id' `_period') (id period)
    quietly merge 1:1 id period using "`rows_dta'", assert(match) nogen
    quietly count if _msm_esample != r_fit
    display as text "  fitted risk set: " r(N) " row(s) differ between msm and R"
    if r(N) list id period _msm_esample r_fit if _msm_esample != r_fit in 1/50, noobs
    assert _msm_esample == r_fit
    restore

    local tse = _se[`_treat']
    local tb = _b[`_treat']
    preserve
    quietly use "`ref_dta'", clear
    display as text "  n_ref Stata `n_ref' R " r_n_ref[1] "; b " %12.9f `tb' " vs " %12.9f r_b_treat[1] ///
        "; se " %12.9f `tse' " vs " %12.9f r_se_treat[1]
    assert r_n_ref[1] == `n_ref'
    * Stata glm stops at its default ML convergence tolerance; R is run to
    * 1e-12. Coefficients therefore agree to the fit tolerance, not to 1e-12.
    assert reldif(r_b_treat[1], `tb') < 1e-5
    assert reldif(r_se_treat[1], `tse') < 1e-4
    local k = 0
    foreach t of local times {
        local ++k
        assert time[`k'] == `P'[`k', 1]
        foreach pair in "never 2 3 4" "always 5 6 7" "rd 8 9 10" {
            gettoken nm cols : pair
            gettoken ce cols : cols
            gettoken cl ch : cols
            local d = abs(r_`nm'[`k'] - `P'[`k', `ce'])
            display as text "  t=`t' `nm': Stata " %10.7f `P'[`k', `ce'] ///
                "  R " %10.7f r_`nm'[`k'] "  |diff| " %9.2e `d'
            assert `d' < `tolpoint'
            local hw = (`P'[`k', `ch'] - `P'[`k', `cl']) / 2
            local dlo = abs(r_lo_`nm'[`k'] - `P'[`k', `cl'])
            local dhi = abs(r_hi_`nm'[`k'] - `P'[`k', `ch'])
            display as text "         MC limits |diff| " %9.2e `dlo' ///
                " / " %9.2e `dhi' "  half-width " %9.2e `hw'
            assert `hw' > 0
            assert `dlo' < 0.10 * `hw'
            assert `dhi' < 0.10 * `hw'
        }
    }
    restore
end

**# msm_example.dta

**## P1: demo specification (IPTW x IPCW, truncation, quadratic period)
local ++test_count
capture noisily {
    use "`pkg_dir'/msm_example.dta", clear
    msm_prepare, id(id) period(period) treatment(treatment) ///
        outcome(outcome) censor(censored) ///
        covariates(biomarker comorbidity) baseline_covariates(age sex)
    msm_weight, treat_d_cov(biomarker comorbidity age sex) ///
        treat_n_cov(age sex) censor_d_cov(biomarker comorbidity age sex) ///
        censor_n_cov(age sex) truncate(1 99) nolog
    msm_fit, model(logistic) outcome_cov(age sex) period_spec(quadratic) nolog
    _cv_predict_compare, rscript("`r_script'") spec(quadratic) ///
        covs("age sex") history(none) times(1 3 5 7 9) ///
        samples(`mc_samples') tolpoint(`tol_point')
}
if _rc == 0 {
    display as result "PASS P1: msm_example quadratic predictions match R"
    local ++pass_count
}
else {
    display as error "FAIL P1: msm_example quadratic (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' P1"
}

**## P2: natural-spline period basis and treatment-history terms
local ++test_count
capture noisily {
    use "`pkg_dir'/msm_example.dta", clear
    msm_prepare, id(id) period(period) treatment(treatment) ///
        outcome(outcome) censor(censored) ///
        covariates(biomarker comorbidity) baseline_covariates(age sex)
    msm_weight, treat_d_cov(biomarker comorbidity age sex) ///
        treat_n_cov(age sex) censor_d_cov(biomarker comorbidity age sex) ///
        censor_n_cov(age sex) nolog
    msm_fit, model(logistic) outcome_cov(age sex) period_spec(ns(3)) ///
        history(lag1 cumulative) nolog
    local knots : char _dta[_msm_per_ns_knots]
    assert wordcount("`knots'") == 4
    _cv_predict_compare, rscript("`r_script'") spec(ns) ///
        covs("age sex") history("lag1 cumulative") knots("`knots'") ///
        times(0 2 4 6 8 9) samples(`mc_samples') tolpoint(`tol_point')
}
if _rc == 0 {
    display as result "PASS P2: spline basis and history terms match R"
    local ++pass_count
}
else {
    display as error "FAIL P2: msm_example ns(3) + history (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' P2"
}

**# Public HAART data (van der Wal and Geskus 2011)

**## P3: joint weights, linear period, baseline covariates
local ++test_count
capture noisily {
    use "`haart_file'", clear
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
    msm_fit, model(logistic) outcome_cov(sex age) period_spec(linear) nolog
    _cv_predict_compare, rscript("`r_script'") spec(linear) ///
        covs("sex age") history(none) times(5 10 20 30) ///
        samples(`mc_samples') tolpoint(`tol_point')
}
if _rc == 0 {
    display as result "PASS P3: HAART predictions match R"
    local ++pass_count
}
else {
    display as error "FAIL P3: HAART (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' P3"
}

**# Summary

if `fail_count' > 0 display as error "Failed tests:`failed_tests'"
do "`qa_dir'/_record_qa_result.do" crossval_msm_predict ///
    `test_count' `pass_count' `fail_count' 0
display as text "RESULT: crossval_msm_predict tests=`test_count' pass=`pass_count' fail=`fail_count' skip=0"
capture log close _all
if `fail_count' > 0 exit 1
