* test_msm_phase3.do
* Phase 3 regressions: history MSMs, positivity policy, and longitudinal balance.

version 16.0
clear all
set more off
set varabbrev off

capture log close _all
log using "test_msm_phase3.log", replace text nomsg

local qa_dir  "`c(pwd)'"
local pkg_dir "`qa_dir'/.."

do "`qa_dir'/_install_msm_isolated.do" "`pkg_dir'"
do "`qa_dir'/_msm_qa_common.do"

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

capture program drop _p3_history_panel
program define _p3_history_panel
    version 16.0
    clear
    set seed 31701
    set obs 1600
    gen long id = ceil(_n / 4)
    bysort id: gen int period = _n - 1
    gen double L = rnormal()
    gen byte treatment = runiform() < invlogit(-0.2 + 0.5 * L)
    gen byte outcome = runiform() < invlogit(-3 + 0.4 * treatment + ///
        0.8 * cond(period == 0, 0, treatment[_n-1]) + 0.1 * period)

    msm_prepare, id(id) period(period) treatment(treatment) ///
        outcome(outcome) covariates(L)
    gen double _msm_weight = 1
    gen double _msm_tw_weight = 1
    gen double _msm_ps = 0.5
    _msm_qa_register_weights
end

capture program drop _p3_separation_data
program define _p3_separation_data
    version 16.0
    clear
    set seed 31702
    set obs 600
    gen long id = _n
    gen int period = 0
    gen double L = rnormal()
    gen byte treatment = runiform() < invlogit(-0.1 + 0.4 * L)
    gen byte separator = treatment == 1 & mod(id, 5) == 0
    gen byte outcome = runiform() < invlogit(-2.8 + 0.4 * treatment)
    msm_prepare, id(id) period(period) treatment(treatment) ///
        outcome(outcome) covariates(L separator)
end

capture program drop _p3_missing_history_panel
program define _p3_missing_history_panel
    version 16.0
    clear
    set seed 31704
    set obs 800
    gen long id = ceil(_n / 4)
    bysort id: gen int period = _n - 1
    gen double L = rnormal()
    gen byte treatment = runiform() < invlogit(-0.2 + 0.5 * L)
    gen byte outcome = runiform() < invlogit(-3 + 0.4 * treatment + 0.1 * period)
    replace treatment = . if id == 1 & period == 1

    msm_prepare, id(id) period(period) treatment(treatment) ///
        outcome(outcome) covariates(L)
    gen double _msm_weight = 1
    gen double _msm_tw_weight = 1
    gen double _msm_ps = 0.5
    _msm_qa_register_weights
end

capture program drop _p3_balance_panel
program define _p3_balance_panel
    version 16.0
    clear
    set seed 31703
    set obs 1600
    gen long id = ceil(_n / 2)
    bysort id: gen int period = _n - 1
    bysort id (period): gen byte treatment = runiform() < 0.5
    bysort id (period): gen byte lag_a = treatment[_n-1]
    replace lag_a = 0 if period == 0
    gen double noise = rnormal(0, 0.15)
    gen double L = cond(period == 0, 2 * treatment - 1, ///
        -(2 * treatment - 1)) + noise
    gen byte censored = runiform() < invlogit(-2.2 + 0.7 * L)
    gen byte outcome = 0

    msm_prepare, id(id) period(period) treatment(treatment) ///
        outcome(outcome) censor(censored) covariates(L)
    gen double _msm_weight = 1
    gen double _msm_tw_weight = 1
    gen double _msm_cw_weight = 1
    gen double _msm_ps = 0.5
    _msm_qa_register_weights
end

* P3.1: built-in treatment-history terms are fitted and prediction-compatible.
local ++test_count
capture noisily {
    _p3_history_panel
    msm_fit, model(logistic) period_spec(linear) ///
        history(lag1 cumulative duration interaction) nolog

    assert "`e(msm_history_spec)'" == "lag1 cumulative duration interaction"
    assert "`e(msm_history_assumption)'" == "explicit_history"
    foreach v in _msm_hist_lag1 _msm_hist_cum _msm_hist_dur _msm_hist_int {
        confirm variable `v'
    }

    tempvar lag_oracle cum_oracle dur_oracle
    bysort id (period): gen byte `lag_oracle' = treatment[_n-1]
    replace `lag_oracle' = 0 if period == 0
    bysort id (period): gen int `cum_oracle' = sum(treatment[_n-1]) if _n > 1
    replace `cum_oracle' = 0 if period == 0
    bysort id (period): gen int `dur_oracle' = 0
    bysort id (period): replace `dur_oracle' = ///
        cond(treatment[_n-1] == 1, `dur_oracle'[_n-1] + 1, 0) if _n > 1

    assert _msm_hist_lag1 == `lag_oracle'
    assert _msm_hist_cum == `cum_oracle'
    assert _msm_hist_dur == `dur_oracle'
    assert _msm_hist_int == treatment * `lag_oracle'

    msm_predict, times(3) difference samples(10) seed(31701)
    assert "`r(history_spec)'" == "lag1 cumulative duration interaction"
    matrix P = r(predictions)
    assert !missing(P[1, 2], P[1, 5], P[1, 8])

    * Exact prediction oracle: this detects a helper that fits history terms
    * but silently evaluates them as zero under the static regimes.
    _p3_history_panel
    gen byte _msm_hist_lag1 = 0
    gen double _msm_hist_cum = 0
    gen double _msm_hist_dur = 0
    gen byte _msm_hist_int = 0
    char _dta[_msm_model] "logistic"
    char _dta[_msm_period_spec] "none"
    char _dta[_msm_history_spec] "lag1 cumulative duration interaction"
    char _dta[_msm_history_vars] ///
        "_msm_hist_lag1 _msm_hist_cum _msm_hist_dur _msm_hist_int"
    char _dta[_msm_history_assumption] "explicit_history"
    matrix b_oracle = (-4, .2, .6, .1, .15, .25)
    matrix colnames b_oracle = _cons treatment _msm_hist_lag1 ///
        _msm_hist_cum _msm_hist_dur _msm_hist_int
    matrix V_oracle = J(6, 6, 0)
    _msm_qa_register_fit, b(b_oracle) v(V_oracle)
    msm_predict, times(2) difference samples(10) seed(31701)
    assert "`r(history_spec)'" == "lag1 cumulative duration interaction"
    matrix P_oracle = r(predictions)
    local never = 1 - (1 - invlogit(-4))^3
    local always = 1 - (1 - invlogit(-3.8)) * ///
        (1 - invlogit(-2.7)) * (1 - invlogit(-2.45))
    assert abs(P_oracle[1, 2] - `never') < 1e-12
    assert abs(P_oracle[1, 5] - `always') < 1e-12
    assert abs(P_oracle[1, 8] - (`always' - `never')) < 1e-12

    * Unknown prior treatment must remain unknown; silently resetting the
    * consecutive-duration term to zero fabricates a treatment history.
    _p3_missing_history_panel
    msm_fit, model(logistic) period_spec(linear) history(duration) nolog
    assert missing(_msm_hist_dur) if id == 1 & period == 2
}
if _rc == 0 {
    display as result "PASS P3.1: explicit history terms fit and predict"
    local ++pass_count
}
else {
    display as error "FAIL P3.1: history-term contract (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' P3.1"
}

* P3.2: default weighting refuses partial separation instead of repairing it.
local ++test_count
capture noisily {
    _p3_separation_data
    capture msm_weight, treat_d_cov(L separator) nolog
    local rc = _rc
    assert `rc' == 459
    capture confirm variable _msm_weight
    assert _rc != 0
    assert "`: char _dta[_msm_weighted]'" == ""
}
if _rc == 0 {
    display as result "PASS P3.2: structural support failure is an error by default"
    local ++pass_count
}
else {
    display as error "FAIL P3.2: default positivity policy (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' P3.2"
}

* P3.3: clipping is explicit, configurable, and model-by-cell repairs are returned.
local ++test_count
capture noisily {
    _p3_separation_data
    msm_weight, treat_d_cov(L separator) probpolicy(clip) clip(0.01) nolog

    assert "`r(probability_policy)'" == "clip"
    assert strpos("`r(probability_models)'", "1=treatment_denominator") > 0
    assert strpos("`r(probability_models)'", "2=treatment_numerator") > 0
    assert abs(r(clip_threshold) - 0.01) < 1e-12
    assert r(n_probability_repairs) > 0
    matrix R = r(probability_repairs)
    local rcols : colnames R
    assert "`rcols'" == "model period cell N n_missing n_low n_high raw_min raw_max repaired_min repaired_max"
    assert rowsof(R) >= 4
    assert colsof(R) == 11
    local repairs_from_rows = 0
    forvalues rr = 1/`=rowsof(R)' {
        local repairs_from_rows = `repairs_from_rows' + ///
            R[`rr', 5] + R[`rr', 6] + R[`rr', 7]
    }
    assert `repairs_from_rows' == r(n_probability_repairs)

    foreach v in _msm_treat_den_raw _msm_treat_den_p ///
        _msm_treat_num_raw _msm_treat_num_p _msm_decision_risk {
        confirm variable `v'
    }
    quietly summarize _msm_treat_den_p if _msm_decision_risk, meanonly
    assert r(min) >= 0.01
    assert r(max) <= 0.99
    quietly count if _msm_decision_risk & missing(_msm_treat_den_raw)
    assert r(N) == 58
    quietly count if _msm_decision_risk & missing(_msm_treat_den_p)
    assert r(N) == 0
    assert "`: char _dta[_msm_probability_policy]'" == "clip"
    assert "`: char _dta[_msm_probability_clip]'" == "0.01"
    _msm_verify weight

    replace _msm_treat_den_p = 0.5 in 1
    _msm_verify weight
    assert r(ok) == 0
    assert "`r(why)'" == "edited"
}
if _rc == 0 {
    display as result "PASS P3.3: explicit clipping is disclosed and signed"
    local ++pass_count
}
else {
    display as error "FAIL P3.3: clipping metadata contract (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' P3.3"
}

* P3.4: period/history-specific balance exposes pooled cancellation.
local ++test_count
capture noisily {
    _p3_balance_panel
    msm_diagnose, balance_covariates(L)

    matrix Bpool = r(balance)
    matrix Bt = r(treatment_balance)
    matrix S = r(support)
    assert abs(Bpool[1, 2]) < 0.10
    assert rowsof(Bt) == 3
    assert colsof(Bt) == 9
    assert Bt[1, 1] == 0 & Bt[1, 2] == -1
    assert Bt[2, 1] == 1 & Bt[2, 2] == 0
    assert Bt[3, 1] == 1 & Bt[3, 2] == 1
    assert abs(Bt[1, 4]) > 5
    assert abs(Bt[2, 4]) > 5
    assert abs(Bt[3, 4]) > 5
    assert sign(Bt[1, 4]) != sign(Bt[2, 4])
    assert rowsof(S) == 2
    assert colsof(S) == 10
    assert S[1, 2] == 800 & S[2, 2] == 800
    assert S[1, 3] + S[1, 4] == S[1, 2]
    assert S[2, 3] + S[2, 4] == S[2, 2]
}
if _rc == 0 {
    display as result "PASS P3.4: longitudinal balance prevents pooled cancellation"
    local ++pass_count
}
else {
    display as error "FAIL P3.4: treatment-balance diagnostic (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' P3.4"
}

* P3.5: censoring balance is a separate risk-set diagnostic surface.
local ++test_count
capture noisily {
    _p3_balance_panel
    msm_diagnose, balance_covariates(L)
    matrix C = r(censor_balance)
    local ccols : colnames C
    assert "`ccols'" == "period covariate raw_smd weighted_smd n_censored n_uncensored ess"
    assert rowsof(C) == 2
    assert colsof(C) == 7
    assert C[1, 5] > 0
    assert C[1, 6] > 0
}
if _rc == 0 {
    display as result "PASS P3.5: censoring balance is reported separately"
    local ++pass_count
}
else {
    display as error "FAIL P3.5: censor-balance diagnostic (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' P3.5"
}

* P3.6: censoring balance uses the observed censor-decision weight.
local ++test_count
capture noisily {
    clear
    set seed 31724
    set obs 12000
    gen long id = _n
    gen int period = 0
    gen double L = rnormal()
    gen byte treatment = runiform() < 0.5
    gen byte censored = runiform() < invlogit(-0.4 + 1.4 * L)
    gen byte outcome = runiform() < invlogit(-3 + 0.2 * treatment)
    * Censor-first convention (the timing msm_weight/msm_fit use): a censored
    * subject has no observed outcome that period, so an event/censor tie is
    * contradictory data. Enforce it here -- the censor-balance oracle below
    * does not depend on the current-period outcome, so this leaves it exact.
    replace outcome = 0 if censored == 1

    msm_prepare, id(id) period(period) treatment(treatment) ///
        outcome(outcome) censor(censored) covariates(L)
    msm_weight, treat_d_cov(L) censor_d_cov(L) nolog
    msm_diagnose, balance_covariates(L)

    matrix C = r(censor_balance)
    tempvar observed_censor_weight diag_use weight_sq
    gen double `observed_censor_weight' = cond(censored == 1, ///
        _msm_cens_num_p / _msm_cens_den_p, ///
        (1 - _msm_cens_num_p) / (1 - _msm_cens_den_p)) ///
        if _msm_decision_risk
    gen byte `diag_use' = _msm_decision_risk & !missing(censored)
    _msm_smd L, treatment(censored) weight(`observed_censor_weight') ///
        touse(`diag_use')
    local oracle_smd = `_msm_smd_value'

    gen double `weight_sq' = `observed_censor_weight'^2 if `diag_use'
    quietly summarize `observed_censor_weight' if `diag_use', meanonly
    local sum_w = r(sum)
    quietly summarize `weight_sq' if `diag_use', meanonly
    local oracle_ess = `sum_w'^2 / r(sum)

    assert abs(C[1, 3]) > 1
    assert abs(`oracle_smd') < 0.05
    assert reldif(C[1, 4], `oracle_smd') < 1e-10
    assert reldif(C[1, 7], `oracle_ess') < 1e-10
}
if _rc == 0 {
    display as result "PASS P3.6: censoring balance uses observed-decision weights"
    local ++pass_count
}
else {
    display as error "FAIL P3.6: censor-decision weighting oracle (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' P3.6"
}

* P3.7: later censor decisions carry forward prior uncensoring factors.
local ++test_count
capture noisily {
    clear
    set seed 31725
    set obs 8000
    gen long id = ceil(_n / 2)
    bysort id: gen int period = _n - 1
    gen double L = rnormal() + 0.3 * period
    gen byte treatment = runiform() < 0.5
    bysort id (period): gen byte censored = ///
        runiform() < invlogit(-0.8 + 1.2 * L + 0.4 * period)
    bysort id (period): replace censored = 0 if _n > 1 & censored[_n-1] == 1
    gen byte outcome = period == 1 & ///
        runiform() < invlogit(-3 + 0.2 * treatment)
    * Censor-first: a censored period has no observed event (see P3.6).
    replace outcome = 0 if censored == 1

    msm_prepare, id(id) period(period) treatment(treatment) ///
        outcome(outcome) censor(censored) covariates(L)
    msm_weight, treat_d_cov(L) censor_d_cov(L) nolog
    msm_diagnose, balance_covariates(L)

    matrix C = r(censor_balance)
    assert rowsof(C) == 2
    tempvar observed_factor log_factor cum_log oracle_weight
    gen double `observed_factor' = cond(censored == 1, ///
        _msm_cens_num_p / _msm_cens_den_p, ///
        (1 - _msm_cens_num_p) / (1 - _msm_cens_den_p)) ///
        if _msm_decision_risk
    gen double `log_factor' = ln(`observed_factor') if _msm_decision_risk
    replace `log_factor' = 0 if !_msm_decision_risk
    bysort id (period): gen double `cum_log' = sum(`log_factor')
    gen double `oracle_weight' = exp(`cum_log') if _msm_decision_risk

    forvalues row = 1/2 {
        local p = C[`row', 1]
        tempvar diag_use weight_sq
        gen byte `diag_use' = _msm_decision_risk & period == `p' & ///
            !missing(censored)
        _msm_smd L, treatment(censored) weight(`oracle_weight') ///
            touse(`diag_use')
        local oracle_smd = `_msm_smd_value'

        gen double `weight_sq' = `oracle_weight'^2 if `diag_use'
        quietly summarize `oracle_weight' if `diag_use', meanonly
        local sum_w = r(sum)
        quietly summarize `weight_sq' if `diag_use', meanonly
        local oracle_ess = `sum_w'^2 / r(sum)

        assert abs(`oracle_smd') < 0.08
        assert reldif(C[`row', 4], `oracle_smd') < 1e-10
        assert reldif(C[`row', 7], `oracle_ess') < 1e-10
        drop `diag_use' `weight_sq'
    }
}
if _rc == 0 {
    display as result "PASS P3.7: censoring balance carries prior factors"
    local ++pass_count
}
else {
    display as error "FAIL P3.7: longitudinal censor-weight oracle (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' P3.7"
}

display as text "RESULT: test_msm_phase3 tests=`test_count' pass=`pass_count' fail=`fail_count'"
capture log close _all
if `fail_count' > 0 exit 1
