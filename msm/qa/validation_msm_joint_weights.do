*! validation_msm_joint_weights.do
*! Exact two-period IPTW x IPCW answers under changing censoring risk sets

version 16.0
clear all
set varabbrev off

capture log close _all
log using "validation_msm_joint_weights.log", replace text nomsg

local qa_dir "`c(pwd)'"
local pkg_dir "`qa_dir'/.."

do "`qa_dir'/_install_msm_isolated.do" "`pkg_dir'"

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""
local tol = 2e-6

**# Fixture builder

capture program drop _joint_weight_panel
program define _joint_weight_panel
    version 16.0
    syntax [, EVENTS]

    * Initial risk set: x=0 has 800 subjects and x=1 has 1,280. Censoring
    * probabilities of 0.20 and 0.50 leave 640 subjects in each x stratum for
    * period 1. The fivefold replication makes every treatment/censoring cell
    * an integer while retaining exact fitted probabilities.
    clear
    set obs 2080
    gen long id = _n
    gen byte x = id > 800
    bysort x (id): gen long x_rank = _n
    by x: gen long x_n = _N
    gen byte z = x_rank > x_n / 2

    bysort x z (id): gen long cell_rank = _n
    by x z: gen long cell_n = _N
    gen byte a0 = cell_rank <= cell_n * cond(z == 1, 0.75, 0.25)

    drop cell_rank cell_n
    bysort x z a0 (id): gen long cell_rank = _n
    by x z a0: gen long cell_n = _N
    gen byte c0 = cell_rank <= cell_n * cond(x == 1, 0.50, 0.20)

    gen byte n_rows = 2 - c0
    expand n_rows
    bysort id: gen byte period = _n - 1

    drop cell_rank cell_n
    bysort x z a0 period (id): gen long cell_rank = _n
    by x z a0 period: gen long cell_n = _N
    gen byte a1 = .
    replace a1 = cell_rank <= cell_n * cond(z == 1, 0.75, 0.25) ///
        if period == 1
    gen byte treatment = cond(period == 0, a0, a1)

    drop cell_rank cell_n
    bysort x z a0 a1 period (id): gen long cell_rank = _n
    by x z a0 a1 period: gen long cell_n = _N
    gen byte c1 = .
    replace c1 = cell_rank <= cell_n * cond(x == 1, 0.80, 0.50) ///
        if period == 1
    gen byte censor = cond(period == 0, c0, c1)
    gen byte outcome = 0
    if "`events'" != "" {
        replace outcome = mod(id, 17) == 0 if period == 1 & censor == 0
    }

    drop x_rank x_n cell_rank cell_n n_rows a1 c1
    sort id period
end

capture program drop _joint_weight_oracle
program define _joint_weight_oracle
    version 16.0

    * Treatment denominator is P(A=1|z) = 0.25/0.75. The stabilized
    * numerator is 0.50 at baseline and 0.375/0.625 at period 1 according to
    * lagged treatment. These are independent table probabilities, not values
    * read back from the package's fitted logits.
    gen double oracle_td = cond(z == 1, 0.75, 0.25)
    gen double oracle_tn = 0.50 if period == 0
    replace oracle_tn = cond(a0 == 1, 0.625, 0.375) if period == 1
    gen double oracle_tw_factor = cond(treatment == 1, ///
        oracle_tn / oracle_td, (1 - oracle_tn) / (1 - oracle_td))
    gen double oracle_log_tw = ln(oracle_tw_factor)
    bysort id (period): gen double oracle_tw = exp(sum(oracle_log_tw))

    * Censoring denominator probabilities follow an exact additive logit:
    * period 0: 0.20/0.50 for x=0/1; period 1: 0.50/0.80.
    * Unequal baseline x strata give marginal P(C0=1)=5/13; the balanced
    * period-1 risk set gives P(C1=1)=13/20.
    gen double oracle_cd = cond(period == 0, ///
        cond(x == 1, 0.50, 0.20), cond(x == 1, 0.80, 0.50))
    gen double oracle_cn = cond(period == 0, 5/13, 13/20)
    gen double oracle_cw_factor = (1 - oracle_cn) / (1 - oracle_cd)
    gen double oracle_log_cw = ln(oracle_cw_factor)
    bysort id (period): gen double oracle_cw = exp(sum(oracle_log_cw))
    gen double oracle_joint = oracle_tw * oracle_cw
end

**# Exact joint weights

**## Two-period treatment and censoring products match hand-derived values
local ++test_count
capture noisily {
    _joint_weight_panel
    msm_prepare, id(id) period(period) treatment(treatment) outcome(outcome) ///
        censor(censor) covariates(x z)
    msm_weight, treat_d_cov(z) censor_d_cov(x) ///
        period_d_spec(linear) period_n_spec(linear) nolog
    local returned_mean = r(mean_weight)
    local returned_ess = r(ess)

    _joint_weight_oracle
    gen double diff_tw = abs(_msm_tw_weight - oracle_tw)
    gen double diff_cw = abs(_msm_cw_weight - oracle_cw)
    gen double diff_joint = abs(_msm_weight - oracle_joint)
    summarize diff_tw, meanonly
    assert r(max) < `tol'
    summarize diff_cw, meanonly
    assert r(max) < `tol'
    summarize diff_joint, meanonly
    assert r(max) < `tol'

    summarize oracle_joint, meanonly
    assert abs(`returned_mean' - r(mean)) < `tol'
    tempvar oracle_sq
    gen double `oracle_sq' = oracle_joint^2
    summarize oracle_joint, meanonly
    local sum_w = r(sum)
    summarize `oracle_sq', meanonly
    local oracle_ess = (`sum_w'^2) / r(sum)
    assert abs(`returned_ess' - `oracle_ess') < 1e-4

    assert abs(_msm_cw_weight - (10/13)) < `tol' ///
        if period == 0 & x == 0
    assert abs(_msm_cw_weight - (16/13)) < `tol' ///
        if period == 0 & x == 1
    assert abs(_msm_cw_weight - (7/13)) < `tol' ///
        if period == 1 & x == 0
    assert abs(_msm_cw_weight - (28/13)) < `tol' ///
        if period == 1 & x == 1
}
if _rc == 0 {
    display as result "PASS J1: exact joint IPTW and IPCW products"
    local ++pass_count
}
else {
    display as error "FAIL J1: exact joint weights (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' J1"
}

**## Current-period terminal events retain the inclusive censoring factor
local ++test_count
capture noisily {
    _joint_weight_panel, events
    count if outcome == 1
    local n_events = r(N)
    assert `n_events' > 0

    msm_prepare, id(id) period(period) treatment(treatment) outcome(outcome) ///
        censor(censor) covariates(x z)
    msm_weight, treat_d_cov(z) censor_d_cov(x) ///
        period_d_spec(linear) period_n_spec(linear) nolog
    _joint_weight_oracle

    gen double event_cw_diff = abs(_msm_cw_weight - oracle_cw) if outcome == 1
    summarize event_cw_diff, meanonly
    assert !missing(r(max))
    assert r(max) < `tol'
    assert !missing(_msm_cw_weight) if outcome == 1

    msm_fit, model(logistic) period_spec(none) nolog
    count if _msm_decision_risk == 1 & censor == 0
    assert e(N) == r(N)
}
if _rc == 0 {
    display as result "PASS J2: event rows carry the current censoring factor"
    local ++pass_count
}
else {
    display as error "FAIL J2: inclusive event-row censoring weight (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' J2"
}

**# Summary

if `fail_count' > 0 display as error "Failed tests:`failed_tests'"
do "`qa_dir'/_record_qa_result.do" validation_msm_joint_weights ///
    `test_count' `pass_count' `fail_count' 0
display as text "RESULT: validation_msm_joint_weights tests=`test_count' pass=`pass_count' fail=`fail_count' skip=0"
capture log close _all
if `fail_count' > 0 exit 1
