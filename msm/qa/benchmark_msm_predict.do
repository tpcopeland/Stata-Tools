* benchmark_msm_predict.do
* Same-session vectorized-versus-scalar timing guard for msm_predict.

version 16.0
clear all
set more off
set varabbrev off
set processors 1

capture log close _all
log using "benchmark_msm_predict.log", replace text nomsg

local qa_dir  "`c(pwd)'"
local pkg_dir "`qa_dir'/.."
do "`qa_dir'/_install_msm_isolated.do" "`pkg_dir'"
do "`qa_dir'/_msm_qa_common.do"

local test_count = 0
local pass_count = 0
local fail_count = 0

local ++test_count
capture noisily {
    set seed 20260828
    set obs 5000
    gen long id = _n
    gen double age = 40 + 15*rnormal()
    gen byte sex = runiform() < .5
    expand 20
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

    timer clear
    timer on 1
    msm_predict, times(5 10 15 20) samples(500) seed(20260828)
    timer off 1
    matrix VECTORIZED = r(predictions)
    local min_support = r(min_support)
    quietly timer list 1
    local vector_seconds = r(t1)

    preserve
    keep if period == `min_support'
    keep if _msm_esample == 1
    bysort id: keep if _n == 1
    matrix SCALAR = J(4, 2, .)

    timer on 2
    forvalues sim = 1/500 {
        foreach treat_val in 0 1 {
            tempvar surv prob
            gen double `surv' = 1
            gen double `prob' = .
            forvalues s = `min_support'/20 {
                _msm_qa_predict_xb, time(`s') treat_val(`treat_val') ///
                    treatment(treatment) period(period) ///
                    period_spec(quadratic) baseline(`min_support') ///
                    b_hat(_msm_fit_b) probvar(`prob')
                replace `surv' = `surv' * (1 - `prob')
                local row = 0
                foreach t in 5 10 15 20 {
                    local ++row
                    if `s' == `t' {
                        summarize `surv', meanonly
                        if `sim' == 1 {
                            local col = `treat_val' + 1
                            matrix SCALAR[`row', `col'] = 1 - r(mean)
                        }
                    }
                }
            }
            drop `surv' `prob'
        }
    }
    timer off 2
    restore

    quietly timer list 2
    local scalar_seconds = r(t2)
    local speedup = `scalar_seconds' / `vector_seconds'
    forvalues row = 1/4 {
        assert reldif(SCALAR[`row', 1], VECTORIZED[`row', 2]) < 1e-12
        assert reldif(SCALAR[`row', 2], VECTORIZED[`row', 5]) < 1e-12
    }
    assert `vector_seconds' > 0
    assert `scalar_seconds' > `vector_seconds'
    assert `speedup' >= 5
    display as result "BENCH: vector_seconds=" %9.3f `vector_seconds' ///
        " scalar_seconds=" %9.3f `scalar_seconds' ///
        " speedup=" %7.2f `speedup' "x"
}
if _rc == 0 {
    display as result "PASS B01: vectorized prediction is at least 5x faster than the retained scalar specification"
    local ++pass_count
}
else {
    display as error "FAIL B01: vectorized timing/equivalence gate (rc=`=_rc')"
    local ++fail_count
}

do "`qa_dir'/_record_qa_result.do" benchmark_msm_predict ///
    `test_count' `pass_count' `fail_count' 0
display as text "RESULT: benchmark_msm_predict tests=`test_count' pass=`pass_count' fail=`fail_count' skip=0"
capture log close _all
if `fail_count' > 0 exit 1
