* validation_msm_predict_vectorized.do
* Seeded equivalence and arithmetic validation for vectorized msm_predict.

version 16.0
clear all
set more off
set varabbrev off

capture log close _all
log using "validation_msm_predict_vectorized.log", replace text nomsg

local qa_dir  "`c(pwd)'"
local pkg_dir "`qa_dir'/.."
do "`qa_dir'/_install_msm_isolated.do" "`pkg_dir'"
do "`qa_dir'/_msm_qa_common.do"

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

capture program drop _mvp_panel
program define _mvp_panel
    version 16.0
    syntax [, NIDS(integer 1200) TPER(integer 8) SEED(integer 20260828)]
    clear
    set seed `seed'
    set obs `nids'
    gen long id = _n
    gen double age = 40 + 15*rnormal()
    gen byte sex = runiform() < .5
    gen double L0 = rnormal()
    expand `tper'
    bysort id: gen int period = _n
    gen double L = L0 + .25*rnormal() + .1*period
    gen byte treatment = runiform() < invlogit(-.6 + .35*L - .01*age)
    gen byte outcome = runiform() < invlogit(-3.4 + .4*treatment + .01*age)
    gen byte censor = (runiform() < .015) & outcome == 0
    bysort id (period): gen int _cum = sum(outcome[_n-1])
    drop if _cum > 0
    drop _cum L0
end

**# Seeded HEAD equivalence
local ++test_count
capture noisily {
    clear
    set seed 20260828
    set obs 5000
    gen long id = _n
    gen double age = 40 + 15*rnormal()
    gen byte sex = runiform() < .5
    expand 10
    bysort id: gen int period = _n
    gen double biomarker = 50 + 10*rnormal() + 2*period
    gen byte comorbidity = runiform() < .3
    bysort id (period): gen byte treatment = ///
        runiform() < invlogit(-1 + .02*biomarker - .01*age)
    bysort id (period): gen byte outcome = ///
        runiform() < invlogit(-4 + .3*treatment + .01*age)
    gen byte censor = (runiform() < .02) & outcome == 0
    bysort id (period): gen int _cum = sum(outcome[_n-1])
    drop if _cum > 0
    drop _cum

    msm_prepare, id(id) period(period) treatment(treatment) outcome(outcome) ///
        censor(censor) covariates(biomarker comorbidity) ///
        baseline_covariates(age sex)
    msm_weight, treat_d_cov(biomarker comorbidity age sex) ///
        censor_d_cov(biomarker age sex)
    msm_fit, model(logistic)
    msm_predict, times(3 6 9) samples(100) seed(20260828)
    matrix P = r(predictions)
    matrix EXPECTED = ///
        (3, .0846742087837042, .076384, .092699, ///
            .1044739298546231, .0917735, .113228 \ ///
         6, .16433056029043819, .1529238, .1783863, ///
            .20059164571162241, .1823772, .2150299 \ ///
         9, .23659248840817451, .2212818, .2518798, ///
            .28585564563286742, .2631492, .3025179)
    mata: st_numscalar("_mvp_maxdiff", ///
        max(abs(st_matrix("P") - st_matrix("EXPECTED"))))
    assert _mvp_maxdiff < 1e-12
    assert "`r(seed)'" == "20260828"
    assert "`r(seed_source)'" == "seed()"
    assert r(n_ref) == 4900
    assert r(samples) == 100
}
if _rc == 0 {
    display as result "PASS P01: seeded full prediction matrix matches the 1.4.6 HEAD baseline"
    local ++pass_count
}
else {
    display as error "FAIL P01: seeded HEAD equivalence (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' P01"
}

**# Scalar-term parity against the retained ado specification
local ++test_count
capture noisily {
    _mvp_panel
    msm_prepare, id(id) period(period) treatment(treatment) outcome(outcome) ///
        censor(censor) covariates(L) baseline_covariates(age sex)
    msm_weight, treat_d_cov(L age sex) censor_d_cov(L age sex)
    msm_fit, model(logistic) outcome_cov(age sex) period_spec(ns(3)) ///
        history(lag1 cumulative duration interaction)
    msm_predict, times(3 6 8) samples(30) seed(314159)
    matrix VECTORIZED = r(predictions)
    local min_support = r(min_support)

    preserve
    keep if period == `min_support'
    keep if _msm_esample == 1
    bysort id: keep if _n == 1
    local row = 0
    foreach treat_val in 0 1 {
        tempvar surv prob
        gen double `surv' = 1
        gen double `prob' = .
        forvalues s = `min_support'/8 {
            _msm_qa_predict_xb, time(`s') treat_val(`treat_val') ///
                treatment(treatment) period(period) period_spec(ns(3)) ///
                baseline(`min_support') outcome_cov(age sex) ///
                b_hat(_msm_fit_b) probvar(`prob')
            replace `surv' = `surv' * (1 - `prob')
            local row = 0
            foreach t in 3 6 8 {
                local ++row
                if `s' == `t' {
                    summarize `surv', meanonly
                    local expected = 1 - r(mean)
                    local col = cond(`treat_val' == 0, 2, 5)
                    assert reldif(`expected', VECTORIZED[`row', `col']) < 1e-12
                }
            }
        }
        drop `surv' `prob'
    }
    restore
}
if _rc == 0 {
    display as result "PASS P02: covariate, history, and natural-spline terms match the scalar ado oracle"
    local ++pass_count
}
else {
    display as error "FAIL P02: scalar-term parity (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' P02"
}

**# Fully degenerate covariance
local ++test_count
capture noisily {
    _mvp_panel, nids(700) tper(6) seed(271828)
    msm_prepare, id(id) period(period) treatment(treatment) outcome(outcome) ///
        censor(censor) covariates(L) baseline_covariates(age sex)
    msm_weight, treat_d_cov(L age sex) censor_d_cov(L age sex)
    msm_fit, model(logistic) outcome_cov(age sex)

    local k = colsof(_msm_fit_V)
    local bnames : colnames _msm_fit_V
    local beq : coleq _msm_fit_b
    matrix _msm_fit_V = J(`k', `k', 0)
    matrix colnames _msm_fit_V = `bnames'
    matrix rownames _msm_fit_V = `bnames'
    matrix coleq _msm_fit_V = `beq'
    matrix roweq _msm_fit_V = `beq'
    local fit_uuid : char _dta[_msm_fit_uuid]
    _msm_mat_save _msm_fit_V, key(_msm_fit_V) token(`fit_uuid')

    msm_predict, times(3 5) samples(30) seed(161803)
    matrix D = r(predictions)
    assert r(draw_method) == "degenerate"
    forvalues row = 1/2 {
        assert reldif(D[`row', 2], D[`row', 3]) < 1e-6
        assert reldif(D[`row', 2], D[`row', 4]) < 1e-6
        assert reldif(D[`row', 5], D[`row', 6]) < 1e-6
        assert reldif(D[`row', 5], D[`row', 7]) < 1e-6
    }
}
if _rc == 0 {
    display as result "PASS P03: degenerate covariance repeats point predictions without consuming draws"
    local ++pass_count
}
else {
    display as error "FAIL P03: degenerate covariance (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' P03"
}

if `fail_count' > 0 display as error "Failed tests:`failed_tests'"
do "`qa_dir'/_record_qa_result.do" validation_msm_predict_vectorized ///
    `test_count' `pass_count' `fail_count' 0
display as text "RESULT: validation_msm_predict_vectorized tests=`test_count' pass=`pass_count' fail=`fail_count' skip=0"
capture log close _all
if `fail_count' > 0 exit 1
