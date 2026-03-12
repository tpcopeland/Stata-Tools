/*******************************************************************************
* validate_at_estimand.do
*
* Validation 10: As-Treated (AT) estimand pipeline
* Tests AT-specific functionality including weights, predictions,
* and comparison with PP under absorbing treatment.
*******************************************************************************/

version 16.0
set more off
set varabbrev off

* --- Setup (assumes working directory is tte/qa/) ---
capture ado uninstall tte
adopath ++ ".."
capture log close val_at
log using "validate_at_estimand.log", replace nomsg name(val_at)
* Test counters
local test_count = 0
local pass_count = 0
local fail_count = 0

display "VALIDATION 10: As-Treated (AT) Estimand"
display "Date: $S_DATE $S_TIME"
display ""

* =============================================================================
* DGP Program
* =============================================================================
* AT DGP: absorbing treatment, binary covariate x
* N=5,000, 10 periods, true log-OR = -0.50

capture program drop _dgp_at
program define _dgp_at
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

        * Treatment (absorbing): carry forward, new initiators
        if `t' > 0 {
            bysort id (period): replace treatment = treatment[_n-1] if period == `t'

            * New starts among untreated
            quietly replace treatment = 1 ///
                if period == `t' & treatment == 0 ///
                & rbinomial(1, invlogit(-2 + 0.3*x)) == 1
        }
        else {
            * Period 0: some start treatment
            quietly replace treatment = rbinomial(1, invlogit(-2 + 0.3*x)) ///
                if period == 0
        }

        * Eligibility: not yet treated at start of period
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
* Generate AT dataset
* =============================================================================
display "Generating AT validation dataset (N=5,000, 10 periods)..."

_dgp_at, n(5000) periods(10) effect(-0.50) seed(20261001)

quietly count
local n_obs = r(N)
quietly count if outcome == 1
local n_events = r(N)
display "  Person-periods: `n_obs'"
display "  Events: `n_events'"

quietly save "data/at_estimand.dta", replace

* =============================================================================
* TEST 1: AT pipeline runs without error
* =============================================================================
local ++test_count
display ""
display "Test `test_count': AT pipeline runs without error"

use "data/at_estimand.dta", clear

capture noisily {
    tte_prepare, id(id) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) ///
        covariates(x) estimand(AT)

    tte_validate

    tte_expand, maxfollowup(8)

    tte_weight, switch_d_cov(x) stabilized truncate(1 99) nolog

    tte_fit, outcome_cov(x) ///
        followup_spec(quadratic) trial_period_spec(linear) nolog
}

local at_rc = _rc

if `at_rc' == 0 {
    display as result "  PASS - AT pipeline completed without error"
    local ++pass_count
}
else {
    display as error "  FAIL - AT pipeline returned rc=" `at_rc'
    local ++fail_count
}

* Store AT coefficient for later tests
local at_coef = .
local at_se = .
if `at_rc' == 0 {
    local at_coef = _b[_tte_arm]
    local at_se = _se[_tte_arm]
    display "  AT coefficient: " %8.4f `at_coef' "  (SE: " %8.4f `at_se' ")"
}

* =============================================================================
* TEST 2: AT coefficient in correct direction, plausible magnitude
* =============================================================================
local ++test_count
display ""
display "Test `test_count': AT coefficient direction and magnitude"

if `at_rc' == 0 & `at_coef' < 0 & abs(`at_coef') < 3 {
    display as result "  PASS - AT coefficient is negative (" %8.4f `at_coef' ") and plausible (|coef| < 3)"
    local ++pass_count
}
else if `at_rc' != 0 {
    display as error "  FAIL - AT pipeline did not complete, cannot check coefficient"
    local ++fail_count
}
else if `at_coef' >= 0 {
    display as error "  FAIL - AT coefficient is non-negative (" %8.4f `at_coef' ")"
    local ++fail_count
}
else {
    display as error "  FAIL - AT coefficient magnitude too large (|" %8.4f `at_coef' "| >= 3)"
    local ++fail_count
}

* =============================================================================
* TEST 3: AT weights non-degenerate
* =============================================================================
local ++test_count
display ""
display "Test `test_count': AT weights non-degenerate"

if `at_rc' == 0 {
    quietly summarize _tte_weight
    local wt_mean = r(mean)
    local wt_min = r(min)
    local wt_max = r(max)
    local wt_miss = r(N) < _N

    display "  Weight mean: " %8.4f `wt_mean'
    display "  Weight range: [" %8.4f `wt_min' ", " %8.4f `wt_max' "]"

    quietly count if missing(_tte_weight)
    local wt_nmiss = r(N)

    if `wt_mean' > 0.1 & `wt_mean' < 10 & `wt_nmiss' == 0 {
        display as result "  PASS - Weights non-degenerate (mean=" %6.3f `wt_mean' ", no missing)"
        local ++pass_count
    }
    else {
        display as error "  FAIL - Weights degenerate (mean=" %6.3f `wt_mean' ", missing=" `wt_nmiss' ")"
        local ++fail_count
    }
}
else {
    display as error "  FAIL - AT pipeline did not complete, cannot check weights"
    local ++fail_count
}

* =============================================================================
* TEST 4: AT approximates PP for absorbing treatment
* =============================================================================
local ++test_count
display ""
display "Test `test_count': AT approximates PP for absorbing treatment"

* Run PP pipeline on same data
use "data/at_estimand.dta", clear

local pp_coef = .
capture {
    quietly tte_prepare, id(id) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) ///
        covariates(x) estimand(PP)

    quietly tte_expand, maxfollowup(8)

    quietly tte_weight, switch_d_cov(x) stabilized truncate(1 99) nolog

    quietly tte_fit, outcome_cov(x) ///
        followup_spec(quadratic) trial_period_spec(linear) nolog

    local pp_coef = _b[_tte_arm]
}

if `at_rc' == 0 & `pp_coef' != . {
    local diff = abs(`at_coef' - `pp_coef')
    display "  AT coefficient: " %8.4f `at_coef'
    display "  PP coefficient: " %8.4f `pp_coef'
    display "  Absolute difference: " %8.4f `diff'

    if `diff' < 0.5 {
        display as result "  PASS - AT and PP within 0.5 for absorbing treatment (diff=" %6.3f `diff' ")"
        local ++pass_count
    }
    else {
        display as error "  FAIL - AT and PP differ by " %6.3f `diff' " (expected < 0.5)"
        local ++fail_count
    }
}
else {
    display as error "  FAIL - Could not run both AT and PP pipelines"
    local ++fail_count
}

* =============================================================================
* TEST 5: AT with pool_switch option
* =============================================================================
local ++test_count
display ""
display "Test `test_count': AT with pool_switch option"

use "data/at_estimand.dta", clear

local pool_coef = .
capture noisily {
    tte_prepare, id(id) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) ///
        covariates(x) estimand(AT)

    tte_expand, maxfollowup(8)

    tte_weight, switch_d_cov(x) pool_switch stabilized truncate(1 99) nolog

    tte_fit, outcome_cov(x) ///
        followup_spec(quadratic) trial_period_spec(linear) nolog

    local pool_coef = _b[_tte_arm]
}

local pool_rc = _rc

if `pool_rc' == 0 & `pool_coef' < 0 {
    display "  Pooled AT coefficient: " %8.4f `pool_coef'
    display as result "  PASS - AT with pool_switch runs, coefficient negative"
    local ++pass_count
}
else if `pool_rc' != 0 {
    display as error "  FAIL - AT with pool_switch failed (rc=" `pool_rc' ")"
    local ++fail_count
}
else {
    display as error "  FAIL - AT with pool_switch coefficient non-negative (" %8.4f `pool_coef' ")"
    local ++fail_count
}

* =============================================================================
* TEST 6: AT predictions valid
* =============================================================================
local ++test_count
display ""
display "Test `test_count': AT predictions valid"

use "data/at_estimand.dta", clear

local pred_ok = 0
capture noisily {
    quietly tte_prepare, id(id) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) ///
        covariates(x) estimand(AT)

    quietly tte_expand, maxfollowup(8)

    quietly tte_weight, switch_d_cov(x) stabilized truncate(1 99) nolog

    quietly tte_fit, outcome_cov(x) ///
        followup_spec(quadratic) trial_period_spec(linear) nolog

    tte_predict, times(0(2)8) type(cum_inc) difference samples(50) seed(42)

    * Check predictions matrix exists
    matrix list r(predictions)
    local pred_rows = rowsof(r(predictions))
    local pred_cols = colsof(r(predictions))

    * Extract cumulative incidence values and check they are in [0,1]
    matrix predmat = r(predictions)
    local all_valid = 1
    forvalues i = 1/`pred_rows' {
        * Columns with cumulative incidence: arm0 and arm1 (typically cols 2 and 3)
        forvalues j = 2/3 {
            if `j' <= `pred_cols' {
                local val = predmat[`i', `j']
                if `val' < 0 | `val' > 1 {
                    local all_valid = 0
                }
            }
        }
    }

    if `all_valid' == 1 & `pred_rows' > 0 {
        local pred_ok = 1
    }
}

local pred_rc = _rc

if `pred_rc' == 0 & `pred_ok' == 1 {
    display "  Predictions matrix: `pred_rows' rows x `pred_cols' cols"
    display as result "  PASS - Predictions valid, cumulative incidence in [0,1]"
    local ++pass_count
}
else if `pred_rc' != 0 {
    display as error "  FAIL - Prediction pipeline failed (rc=" `pred_rc' ")"
    local ++fail_count
}
else {
    display as error "  FAIL - Predictions invalid (values outside [0,1] or empty matrix)"
    local ++fail_count
}

* =============================================================================
* SUMMARY
* =============================================================================
display ""
display "VALIDATION 10 SUMMARY: As-Treated (AT) Estimand"
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
display "RESULT: V10 tests=`test_count' pass=`pass_count' fail=`fail_count' status=`v_status'"

log close val_at
