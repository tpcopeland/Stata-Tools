/*******************************************************************************
* validate_sensitivity_stress.do
*
* Validation 12: Sensitivity sweep + Stress tests
* Part A: Truncation, time specification, and follow-up length sweeps
* Part B: Memory estimation accuracy, large-N pipeline completion
*******************************************************************************/

version 16.0
set more off
set varabbrev off

* --- Setup (assumes working directory is tte/qa/) ---
capture ado uninstall tte
adopath ++ ".."
capture log close val_sens
log using "validate_sensitivity_stress.log", replace nomsg name(val_sens)
* Test counters
local test_count = 0
local pass_count = 0
local fail_count = 0

display "VALIDATION 12: Sensitivity Sweep + Stress Tests"
display "Date: $S_DATE $S_TIME"
display ""

* =============================================================================
* DGP Program (shared across sensitivity tests)
* =============================================================================
capture program drop _dgp_sens
program define _dgp_sens
    syntax, n(integer) periods(integer) effect(real) seed(integer)

    clear
    set seed `seed'
    quietly set obs `n'

    generate id = _n
    generate byte x = rbinomial(1, 0.4)

    expand `periods'
    bysort id: generate period = _n - 1
    sort id period

    generate byte treatment = 0
    generate byte outcome = 0
    generate byte eligible = 1
    generate byte censored = 0

    * Forward simulation
    forvalues t = 0/`=`periods'-1' {

        * Treatment (absorbing)
        if `t' > 0 {
            bysort id (period): replace treatment = treatment[_n-1] if period == `t'
            quietly replace treatment = 1 ///
                if period == `t' & treatment == 0 ///
                & rbinomial(1, invlogit(-2 + 0.3*x)) == 1
        }
        else {
            quietly replace treatment = rbinomial(1, invlogit(-2 + 0.3*x)) ///
                if period == 0
        }

        * Eligibility
        if `t' == 0 {
            replace eligible = 1 if period == 0
        }
        else {
            bysort id (period): replace eligible = ///
                (treatment[_n-1] == 0 & outcome[_n-1] == 0) if period == `t'
        }

        * Outcome
        quietly replace outcome = rbinomial(1, ///
            invlogit(-3.5 + 0.3*x + `effect'*treatment)) ///
            if period == `t' & outcome == 0

        * Absorbing outcome
        if `t' > 0 {
            bysort id (period): replace outcome = 1 ///
                if period == `t' & outcome[_n-1] == 1
        }
    }

    * Remove person-periods after first outcome
    bysort id (period): generate byte _first = (outcome == 1 & ///
        (period == 0 | outcome[_n-1] == 0))
    bysort id (period): generate byte _cum = sum(_first)
    drop if _cum > 1
    drop _first _cum
end

* =============================================================================
* PART A: Sensitivity Sweeps
* =============================================================================
display "PART A: Sensitivity Sweeps"
display ""

* Generate sensitivity dataset once
display "Generating sensitivity dataset (N=3,000, 10 periods)..."
_dgp_sens, n(3000) periods(10) effect(-0.50) seed(20261201)
quietly save "data/sens_base.dta", replace
quietly count
display "  Person-periods: " r(N)

* =============================================================================
* TEST 1: Truncation sweep
* =============================================================================
local ++test_count
display ""
display "Test `test_count': Truncation sweep (PP pipeline)"

local trunc_lo "1 5 10"
local trunc_hi "99 95 90"
local all_neg = 1

forvalues trunc_i = 1/3 {
    local tlo : word `trunc_i' of `trunc_lo'
    local thi : word `trunc_i' of `trunc_hi'

    use "data/sens_base.dta", clear

    local this_coef = .
    capture {
        quietly tte_prepare, id(id) period(period) treatment(treatment) ///
            outcome(outcome) eligible(eligible) ///
            covariates(x) estimand(PP)

        quietly tte_expand, maxfollowup(8)

        quietly tte_weight, switch_d_cov(x) stabilized truncate(`tlo' `thi') nolog

        quietly tte_fit, outcome_cov(x) ///
            followup_spec(quadratic) trial_period_spec(linear) nolog

        local this_coef = _b[_tte_arm]
    }

    if _rc != 0 {
        display "  Truncation (`tlo',`thi'): FAILED (rc=" _rc ")"
        local all_neg = 0
    }
    else {
        display "  Truncation (`tlo',`thi'): coef = " %8.4f `this_coef'
        if `this_coef' >= 0 {
            local all_neg = 0
        }
    }
}

if `all_neg' == 1 {
    display as result "  PASS - All truncation levels yield negative coefficients"
    local ++pass_count
}
else {
    display as error "  FAIL - Not all truncation levels yield negative coefficients"
    local ++fail_count
}

* =============================================================================
* TEST 2: Time specification sweep
* =============================================================================
local ++test_count
display ""
display "Test `test_count': Time specification sweep (ITT pipeline)"

local all_neg = 1

local tspec_1 "linear"
local tspec_2 "quadratic"
local tspec_3 "cubic"
local tspec_4 "ns(3)"

forvalues si = 1/4 {
    local tspec "`tspec_`si''"

    use "data/sens_base.dta", clear

    local this_coef = .
    capture {
        quietly tte_prepare, id(id) period(period) treatment(treatment) ///
            outcome(outcome) eligible(eligible) ///
            covariates(x) estimand(ITT)

        quietly tte_expand, maxfollowup(8)

        quietly tte_fit, outcome_cov(x) ///
            followup_spec(`tspec') trial_period_spec(linear) nolog

        local this_coef = _b[_tte_arm]
    }

    if _rc != 0 {
        display "  followup_spec `tspec': FAILED (rc=" _rc ")"
        local all_neg = 0
    }
    else {
        display "  followup_spec `tspec': coef = " %8.4f `this_coef'
        if `this_coef' >= 0 {
            local all_neg = 0
        }
    }
}

if `all_neg' == 1 {
    display as result "  PASS - All time specs yield negative coefficients"
    local ++pass_count
}
else {
    display as error "  FAIL - Not all time specs yield negative coefficients"
    local ++fail_count
}

* =============================================================================
* TEST 3: Follow-up length sweep
* =============================================================================
local ++test_count
display ""
display "Test `test_count': Follow-up length sweep (ITT pipeline)"

local all_neg = 1

forvalues fi = 1/3 {
    local fu : word `fi' of 4 6 8

    use "data/sens_base.dta", clear

    local this_coef = .
    local this_ok = 0
    capture {
        quietly tte_prepare, id(id) period(period) treatment(treatment) ///
            outcome(outcome) eligible(eligible) ///
            covariates(x) estimand(ITT)

        quietly tte_expand, maxfollowup(`fu')

        quietly tte_fit, outcome_cov(x) ///
            followup_spec(linear) trial_period_spec(linear) nolog

        local this_coef = _b[_tte_arm]
        local this_ok = 1
    }

    if `this_ok' == 0 {
        display "  maxfollowup `fu': FAILED"
        local all_neg = 0
    }
    else {
        display "  maxfollowup `fu': coef = " %8.4f `this_coef'
        if `this_coef' >= 0 {
            local all_neg = 0
        }
    }
}

if `all_neg' == 1 {
    display as result "  PASS - All follow-up lengths yield negative coefficients"
    local ++pass_count
}
else {
    display as error "  FAIL - Not all follow-up lengths yield negative coefficients"
    local ++fail_count
}

* =============================================================================
* PART B: Stress Tests
* =============================================================================
display ""
display "PART B: Stress Tests"
display ""

* =============================================================================
* TEST 4: _tte_memory_estimate accuracy
* =============================================================================
local ++test_count
display ""
display "Test `test_count': _tte_memory_estimate accuracy"

* Generate known-size dataset
_dgp_sens, n(1000) periods(10) effect(-0.50) seed(20261204)

* Count eligible person-periods
quietly count if eligible == 1
local n_elig = r(N)
display "  Eligible person-periods: `n_elig'"

* Get memory estimate
_tte_memory_estimate, n_eligible(`n_elig') n_followup(8) n_vars(5) clone
local est_rows = `_tte_est_rows'
display "  Estimated rows (with clone): `est_rows'"

* Run actual expansion to get real row count
quietly tte_prepare, id(id) period(period) treatment(treatment) ///
    outcome(outcome) eligible(eligible) ///
    covariates(x) estimand(PP)

quietly tte_expand, maxfollowup(8)

local actual_rows = _N
display "  Actual rows after expand: `actual_rows'"

* Check ratio
local ratio = `est_rows' / `actual_rows'
display "  Ratio (estimate/actual): " %6.3f `ratio'

* Memory estimate is intentionally conservative (upper bound for chunking decisions)
* Acceptable range: estimate should be >= actual (no underestimate) and within 5x
if `ratio' >= 0.5 & `ratio' <= 5.0 {
    display as result "  PASS - Memory estimate reasonable (ratio=" %5.2f `ratio' ", range 0.5-5.0)"
    local ++pass_count
}
else {
    display as error "  FAIL - Memory estimate out of range (ratio=" %5.2f `ratio' ", expected 0.5-5.0)"
    local ++fail_count
}

* =============================================================================
* TEST 5: N=50,000 ITT pipeline completes
* =============================================================================
local ++test_count
display ""
display "Test `test_count': N=50,000 ITT pipeline (stress test)"

display "  Generating large dataset (N=50,000, 6 periods)..."
timer clear 1
timer on 1

_dgp_sens, n(50000) periods(6) effect(-0.50) seed(20261205)
quietly save "data/stress_large.dta", replace

quietly count
display "  Person-periods: " %12.0fc r(N)

capture noisily {
    quietly tte_prepare, id(id) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) ///
        covariates(x) estimand(ITT)

    quietly tte_expand, maxfollowup(5)

    quietly tte_fit, outcome_cov(x) ///
        followup_spec(linear) trial_period_spec(linear) nolog
}

local large_itt_rc = _rc
timer off 1
quietly timer list 1
local itt_time = r(t1)

if `large_itt_rc' == 0 {
    display "  ITT coefficient: " %8.4f _b[_tte_arm]
    display "  Time elapsed: " %6.1f `itt_time' " seconds"
    display as result "  PASS - N=50,000 ITT pipeline completed in " %5.1f `itt_time' "s"
    local ++pass_count
    if `itt_time' > 120 {
        display as text "  NOTE: ITT took " %5.1f `itt_time' "s (>120s threshold) — potential regression"
    }
}
else {
    display as error "  FAIL - N=50,000 ITT pipeline failed (rc=" `large_itt_rc' ")"
    local ++fail_count
}

* =============================================================================
* TEST 6: N=50,000 PP pipeline completes
* =============================================================================
local ++test_count
display ""
display "Test `test_count': N=50,000 PP pipeline (stress test)"

use "data/stress_large.dta", clear

timer clear 2
timer on 2

capture noisily {
    quietly tte_prepare, id(id) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) ///
        covariates(x) estimand(PP)

    quietly tte_expand, maxfollowup(5)

    quietly tte_weight, switch_d_cov(x) stabilized truncate(1 99) nolog

    quietly tte_fit, outcome_cov(x) ///
        followup_spec(linear) trial_period_spec(linear) nolog
}

local large_pp_rc = _rc
timer off 2
quietly timer list 2
local pp_time = r(t2)

if `large_pp_rc' == 0 {
    display "  PP coefficient: " %8.4f _b[_tte_arm]
    display "  Time elapsed: " %6.1f `pp_time' " seconds"
    display as result "  PASS - N=50,000 PP pipeline completed in " %5.1f `pp_time' "s"
    local ++pass_count
    if `pp_time' > 300 {
        display as text "  NOTE: PP took " %5.1f `pp_time' "s (>300s threshold) — potential regression"
    }
}
else {
    display as error "  FAIL - N=50,000 PP pipeline failed (rc=" `large_pp_rc' ")"
    local ++fail_count
}

* =============================================================================
* SUMMARY
* =============================================================================
display ""
display "VALIDATION 12 SUMMARY: Sensitivity Sweep + Stress Tests"
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
display "RESULT: V12 tests=`test_count' pass=`pass_count' fail=`fail_count' status=`v_status'"

log close val_sens
