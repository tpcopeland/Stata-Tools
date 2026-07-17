* validation_msm_phase3_recovery.do
* Known-truth recovery for a prediction-compatible treatment-history MSM.

version 16.0
clear all
set more off
set varabbrev off

capture log close _all
log using "validation_msm_phase3_recovery.log", replace text nomsg

local qa_dir  "`c(pwd)'"
local pkg_dir "`qa_dir'/.."

do "`qa_dir'/_install_msm_isolated.do" "`pkg_dir'"

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

* H1: lagged treatment has a real outcome effect beyond current treatment.
local ++test_count
capture noisily {
    clear
    set seed 31711
    set obs 300000
    gen long id = ceil(_n / 3)
    bysort id: gen int period = _n - 1
    gen double L = rnormal()
    gen double u_a = runiform()
    gen byte treatment = .
    gen byte lag_a = 0
    gen double p_a = .
    replace p_a = invlogit(-0.2 + 0.6 * L) if period == 0
    replace treatment = u_a < p_a if period == 0
    forvalues t = 1/2 {
        bysort id (period): replace lag_a = treatment[_n-1] if period == `t'
        replace p_a = invlogit(-0.2 + 1.2 * lag_a + 0.6 * L) if period == `t'
        replace treatment = u_a < p_a if period == `t'
    }

    gen double p_y = invlogit(-3.2 + 0.35 * treatment + ///
        1.10 * lag_a + 0.15 * period)
    gen byte event_raw = runiform() < p_y
    bysort id (period): gen int prior_events = sum(event_raw[_n-1]) if _n > 1
    replace prior_events = 0 if period == 0
    gen byte outcome = event_raw == 1 & prior_events == 0

    local surv0 = 1
    local surv1 = 1
    forvalues t = 0/2 {
        local p0 = invlogit(-3.2 + 0.15 * `t')
        local lag1 = (`t' > 0)
        local p1 = invlogit(-3.2 + 0.35 + 1.10 * `lag1' + 0.15 * `t')
        local surv0 = `surv0' * (1 - `p0')
        local surv1 = `surv1' * (1 - `p1')
    }
    local truth = (1 - `surv1') - (1 - `surv0')

    msm_prepare, id(id) period(period) treatment(treatment) ///
        outcome(outcome) covariates(L)
    msm_weight, treat_d_cov(L) nolog

    msm_fit, model(logistic) period_spec(linear) nolog
    msm_predict, times(2) difference samples(10) seed(31711)
    local naive = r(rd_2)

    msm_fit, model(logistic) period_spec(linear) history(lag1) nolog
    local b_current = _b[treatment]
    local b_lag = _b[_msm_hist_lag1]
    msm_predict, times(2) difference samples(10) seed(31711)
    local recovered = r(rd_2)

    display as text "H1 truth=" %8.5f `truth' ///
        " current-only=" %8.5f `naive' " history MSM=" %8.5f `recovered'
    assert abs(`naive' - `truth') > 0.02
    assert abs(`recovered' - `truth') < 0.015
    assert abs(`b_current' - 0.35) < 0.08
    assert abs(`b_lag' - 1.10) < 0.08
}
if _rc == 0 {
    display as result "PASS H1: lag-history MSM recovers the static-regime contrast"
    local ++pass_count
}
else {
    display as error "FAIL H1: treatment-history recovery (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' H1"
}

display as text "RESULT: validation_msm_phase3_recovery tests=`test_count' pass=`pass_count' fail=`fail_count'"
capture log close _all
if `fail_count' > 0 exit 1
