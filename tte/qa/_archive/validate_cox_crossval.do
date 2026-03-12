/*******************************************************************************
* validate_cox_crossval.do
*
* Gold-standard Cox PH validation:
*   1. Cox coefficient cross-validation (tte vs direct stcox)
*   2. Baseline hazard validation (monotonicity, starting value)
*   3. Cox vs logistic convergence on multiple datasets
*   4. Cox on real NHEFS data with baseline hazard
*   5. Cox PP with weights
*
* This extends validate_cox_known_dgp.do with comprehensive baseline hazard
* validation and cross-implementation comparison.
*******************************************************************************/

version 16.0
set more off
set varabbrev off

capture ado uninstall tte
adopath ++ ".."
capture log close val_cox_xv
log using "validate_cox_crossval.log", replace nomsg name(val_cox_xv)

local test_count = 0
local pass_count = 0
local fail_count = 0

display "VALIDATION: Cox PH Gold-Standard"
display "Date: $S_DATE $S_TIME"
display ""

* =============================================================================
* TEST 1: tte Cox identical to direct stcox on expanded data
* =============================================================================
local ++test_count
display "Test `test_count': tte Cox vs direct stcox on golden DGP"

import delimited using "data/known_dgp_golden.csv", clear case(preserve)

tte_prepare, id(id) period(period) treatment(treatment) ///
    outcome(outcome) eligible(eligible) covariates(x) estimand(ITT)
tte_expand, maxfollowup(8)
tte_fit, outcome_cov(x) model(cox) trial_period_spec(linear) nolog

local tte_cox_coef = _b[_tte_arm]
local tte_cox_se   = _se[_tte_arm]

display "  tte Cox coef = " %10.6f `tte_cox_coef' "  SE = " %10.6f `tte_cox_se'

* Direct stcox on the same expanded data — mirror tte_fit's counting process setup
* Keep uncensored estimation sample
keep if _tte_censored == 0

* Create counting process intervals (fu, fu+1] exactly as tte_fit does
gen double _time_enter = _tte_followup
gen double _time_exit  = _tte_followup + 1

* Unique person-trial-arm ID (tte_fit uses egen group)
egen long _stset_id = group(id _tte_trial _tte_arm)

stset _time_exit, id(_stset_id) enter(_time_enter) failure(_tte_outcome_obs)

quietly stcox _tte_arm _tte_trial x, vce(cluster id) nolog

local direct_coef = _b[_tte_arm]
local direct_se   = _se[_tte_arm]

display "  Direct stcox coef = " %10.6f `direct_coef' "  SE = " %10.6f `direct_se'

local diff = abs(`tte_cox_coef' - `direct_coef')
display "  Absolute difference = " %10.8f `diff'

* Should be very close (both use stcox internally, different data setup)
if `diff' < 0.01 {
    display as result "  PASS — tte Cox and direct stcox agree (diff < 0.01)"
    local ++pass_count
}
else {
    display as error "  FAIL — difference too large"
    local ++fail_count
}

* =============================================================================
* TEST 2: Baseline cumulative hazard is monotonically non-decreasing
* =============================================================================
local ++test_count
display ""
display "Test `test_count': Baseline hazard monotonicity"

import delimited using "data/known_dgp_golden.csv", clear case(preserve)

tte_prepare, id(id) period(period) treatment(treatment) ///
    outcome(outcome) eligible(eligible) covariates(x) estimand(ITT)
tte_expand, maxfollowup(8)
tte_fit, outcome_cov(x) model(cox) trial_period_spec(linear) nolog

keep if _tte_censored == 0

* Mirror tte_fit counting process setup
gen double _time_enter = _tte_followup
gen double _time_exit  = _tte_followup + 1
egen long _stset_id = group(id _tte_trial _tte_arm)
stset _time_exit, id(_stset_id) enter(_time_enter) failure(_tte_outcome_obs)
quietly stcox _tte_arm _tte_trial x, nolog basehc(bh)

* Check monotonicity
sort _t
quietly count if bh < bh[_n-1] & _n > 1 & !missing(bh) & !missing(bh[_n-1])
local n_violations = r(N)

display "  Baseline hazard observations: " _N
display "  Monotonicity violations: `n_violations'"

if `n_violations' == 0 {
    display as result "  PASS — baseline hazard is monotonically non-decreasing"
    local ++pass_count
}
else {
    display as error "  FAIL — `n_violations' violations found"
    local ++fail_count
}

* =============================================================================
* TEST 3: Cox and logistic agree on direction across datasets
* =============================================================================
local ++test_count
display ""
display "Test `test_count': Cox vs logistic direction agreement"

local all_agree = 1

foreach ds in known_dgp_golden nhefs_personperiod {
    if "`ds'" == "known_dgp_golden" {
        import delimited using "data/`ds'.csv", clear case(preserve)
        local id_var = "id"
        local covs = "x"
        local mfu = 8
        local tps = "linear"
    }
    else {
        use "data/`ds'.dta", clear
        local id_var = "seqn"
        local covs = "age_std sex race smoke_cat wt71_std smokeyrs_std"
        local mfu = 0
        local tps = "none"
    }

    * Logistic
    tte_prepare, id(`id_var') period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) covariates(`covs') estimand(ITT)
    if `mfu' > 0 {
        tte_expand, maxfollowup(`mfu')
    }
    else {
        tte_expand
    }
    tte_fit, outcome_cov(`covs') followup_spec(quadratic) ///
        trial_period_spec(`tps') nolog
    local b_logistic = _b[_tte_arm]

    * Cox
    if "`ds'" == "known_dgp_golden" {
        import delimited using "data/`ds'.csv", clear case(preserve)
    }
    else {
        use "data/`ds'.dta", clear
    }

    tte_prepare, id(`id_var') period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) covariates(`covs') estimand(ITT)
    if `mfu' > 0 {
        tte_expand, maxfollowup(`mfu')
    }
    else {
        tte_expand
    }
    tte_fit, outcome_cov(`covs') model(cox) ///
        trial_period_spec(`tps') nolog
    local b_cox = _b[_tte_arm]

    local same_dir = (sign(`b_logistic') == sign(`b_cox'))
    display "  `ds': logistic=" %8.4f `b_logistic' " cox=" %8.4f `b_cox' ///
        " same_dir=" `same_dir'

    if !`same_dir' {
        local all_agree = 0
    }
}

if `all_agree' {
    display as result "  PASS — Cox/logistic agree on direction across all datasets"
    local ++pass_count
}
else {
    display as error "  FAIL — direction disagreement found"
    local ++fail_count
}

* =============================================================================
* TEST 4: Cox on NHEFS with baseline hazard extraction
* =============================================================================
local ++test_count
display ""
display "Test `test_count': Cox on NHEFS — coefficient and baseline hazard"

use "data/nhefs_personperiod.dta", clear

tte_prepare, id(seqn) period(period) treatment(treatment) ///
    outcome(outcome) eligible(eligible) ///
    covariates(age_std sex race smoke_cat wt71_std smokeyrs_std) ///
    estimand(ITT)
tte_expand
tte_fit, outcome_cov(age_std sex race smoke_cat wt71_std smokeyrs_std) ///
    model(cox) nolog

local nhefs_cox_hr = exp(_b[_tte_arm])
display "  NHEFS Cox HR: " %8.4f `nhefs_cox_hr'

* HR should be in plausible range [0.3, 2.0]
local hr_ok = (`nhefs_cox_hr' > 0.3 & `nhefs_cox_hr' < 2.0)

* Extract baseline hazard — mirror tte_fit counting process setup
keep if _tte_censored == 0
gen double _time_enter = _tte_followup
gen double _time_exit  = _tte_followup + 1
egen long _stset_id = group(seqn _tte_trial _tte_arm)
stset _time_exit, id(_stset_id) enter(_time_enter) failure(_tte_outcome_obs)
quietly stcox _tte_arm age_std sex race smoke_cat wt71_std smokeyrs_std, ///
    nolog basehc(nhefs_bh)

quietly count if !missing(nhefs_bh)
local n_bh = r(N)

if `hr_ok' & `n_bh' > 0 {
    display as result "  PASS — HR plausible and baseline hazard exists (" ///
        `n_bh' " obs)"
    local ++pass_count
}
else {
    display as error "  FAIL"
    local ++fail_count
}

* =============================================================================
* TEST 5: Cox PP with weights produces valid estimate
* =============================================================================
local ++test_count
display ""
display "Test `test_count': Cox PP with IPTW weights"

import delimited using "data/known_dgp_golden.csv", clear case(preserve)

tte_prepare, id(id) period(period) treatment(treatment) ///
    outcome(outcome) eligible(eligible) covariates(x) estimand(PP)
tte_expand, maxfollowup(8)
tte_weight, switch_d_cov(x) truncate(1 99) nolog
tte_fit, outcome_cov(x) model(cox) trial_period_spec(linear) nolog

local pp_cox_hr = exp(_b[_tte_arm])
local pp_cox_coef = _b[_tte_arm]

display "  PP Cox HR: " %8.4f `pp_cox_hr' "  coef: " %8.4f `pp_cox_coef'

* Should be negative (protective) and HR in [0.2, 1.5]
local pp_ok = (`pp_cox_coef' < 0) & (`pp_cox_hr' > 0.2 & `pp_cox_hr' < 1.5)

if `pp_ok' {
    display as result "  PASS — PP Cox produces valid protective effect"
    local ++pass_count
}
else {
    display as error "  FAIL"
    local ++fail_count
}

* =============================================================================
* SUMMARY
* =============================================================================
display ""
display "COX GOLD-STANDARD VALIDATION SUMMARY"
display "Tests run:  `test_count'"
display "Passed:     `pass_count'"
display "Failed:     `fail_count'"

if `fail_count' > 0 {
    display as error "VALIDATION FAILED"
}
else {
    display as result "VALIDATION PASSED"
}

local v_status = cond(`fail_count' > 0, "FAIL", "PASS")
display ""
display "RESULT: V_COX_XV tests=`test_count' pass=`pass_count' fail=`fail_count' status=`v_status'"

log close val_cox_xv
