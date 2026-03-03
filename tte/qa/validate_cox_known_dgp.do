/*******************************************************************************
* validate_cox_known_dgp.do
*
* Validation 13: Cox Model Ground Truth
* Tests model(cox) against a known DGP with true log-OR = -0.50.
* The Cox model is only tested in V2 on NHEFS with no known true effect;
* this validation provides a definitive ground-truth test.
*
* Design:
*   - N=5,000 patients, 10 periods
*   - Known true treatment effect (log-OR = -0.50)
*   - Binary confounder x
*   - Seed 20260313
*
* Tests:
*   1. Cox ITT pipeline completes
*   2. Cox ITT coefficient negative
*   3. Cox ITT close to logistic ITT (within 0.3)
*   4. Cox PP pipeline completes
*   5. Cox PP coefficient negative
*   6. tte_predict after Cox errors correctly
*******************************************************************************/

version 16.0
set more off
set varabbrev off

* --- Setup (assumes working directory is tte/qa/) ---
capture ado uninstall tte
adopath ++ ".."
capture log close val_cox
log using "validate_cox_known_dgp.log", replace nomsg name(val_cox)
* Test counters
local test_count = 0
local pass_count = 0
local fail_count = 0

display "VALIDATION 13: Cox Model Ground Truth"
display "Date: $S_DATE $S_TIME"
display ""

* =============================================================================
* DGP PARAMETERS
* =============================================================================
local true_effect = -0.50
local n_patients  = 5000
local n_periods   = 10

display "DGP Parameters:"
display "  True treatment log-OR: `true_effect' (OR = " %5.3f exp(`true_effect') ")"
display "  N patients: " %8.0fc `n_patients'
display "  N periods: `n_periods'"
display ""

* =============================================================================
* DGP generator
* =============================================================================
capture program drop _dgp_cox
program define _dgp_cox
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

    forvalues t = 0/`=`periods'-1' {

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

        if `t' == 0 {
            replace eligible = 1 if period == 0
        }
        else {
            bysort id (period): replace eligible = ///
                (treatment[_n-1] == 0 & outcome[_n-1] == 0) if period == `t'
        }

        quietly replace outcome = rbinomial(1, ///
            invlogit(-3.5 + 0.3*x + `effect'*treatment)) ///
            if period == `t' & outcome == 0

        if `t' > 0 {
            bysort id (period): replace outcome = 1 ///
                if period == `t' & outcome[_n-1] == 1
        }
    }

    bysort id (period): generate byte _first = (outcome == 1 & ///
        (period == 0 | outcome[_n-1] == 0))
    bysort id (period): generate byte _cum = sum(_first)
    drop if _cum > 1
    drop _first _cum
end

* =============================================================================
* Generate dataset
* =============================================================================
display "Generating Cox validation dataset..."

_dgp_cox, n(`n_patients') periods(`n_periods') effect(`true_effect') seed(20260313)

local n_obs = _N
quietly count if outcome == 1
local n_events = r(N)

display "  Person-periods: " %12.0fc `n_obs'
display "  Events: `n_events'"

save "data/cox_dgp.dta", replace

* =============================================================================
* First, run logistic ITT for comparison
* =============================================================================
display ""
display "Running logistic ITT for comparison..."

tte_prepare, id(id) period(period) treatment(treatment) ///
    outcome(outcome) eligible(eligible) ///
    covariates(x) estimand(ITT)

tte_expand, maxfollowup(8)

tte_fit, outcome_cov(x) ///
    followup_spec(quadratic) trial_period_spec(linear) nolog

local logistic_coef = _b[_tte_arm]
local logistic_se   = _se[_tte_arm]

display "  Logistic ITT coefficient: " %8.4f `logistic_coef' ///
    "  (SE: " %8.4f `logistic_se' ")"

* =============================================================================
* TEST 1: Cox ITT pipeline completes
* =============================================================================
local ++test_count
display ""
display "Test `test_count': Cox ITT pipeline completes"

use "data/cox_dgp.dta", clear

local cox_itt_coef = .
local cox_itt_se = .

capture noisily {
    tte_prepare, id(id) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) ///
        covariates(x) estimand(ITT)

    tte_expand, maxfollowup(8)

    tte_fit, outcome_cov(x) model(cox) nolog

    local cox_itt_coef = _b[_tte_arm]
    local cox_itt_se   = _se[_tte_arm]
}

if _rc == 0 {
    display "  Cox ITT coefficient: " %8.4f `cox_itt_coef' ///
        "  (SE: " %8.4f `cox_itt_se' ")"
    display as result "  PASS -- Cox ITT pipeline completed"
    local ++pass_count
}
else {
    display as error "  FAIL -- Cox ITT pipeline failed (rc=" _rc ")"
    local ++fail_count
}

* =============================================================================
* TEST 2: Cox ITT coefficient negative
* =============================================================================
local ++test_count
display ""
display "Test `test_count': Cox ITT coefficient negative"

if `cox_itt_coef' < 0 {
    display "  Cox ITT coefficient: " %8.4f `cox_itt_coef'
    display as result "  PASS -- Cox ITT correctly shows protective effect"
    local ++pass_count
}
else {
    display as error "  FAIL -- Cox ITT coefficient is non-negative (" %8.4f `cox_itt_coef' ")"
    local ++fail_count
}

* =============================================================================
* TEST 3: Cox ITT close to logistic ITT (within 0.3)
* =============================================================================
local ++test_count
display ""
display "Test `test_count': Cox ITT close to logistic ITT"

local cox_logistic_diff = abs(`cox_itt_coef' - `logistic_coef')

display "  Logistic ITT: " %8.4f `logistic_coef'
display "  Cox ITT:      " %8.4f `cox_itt_coef'
display "  Difference:   " %8.4f `cox_logistic_diff'

if `cox_logistic_diff' < 0.3 {
    display as result "  PASS -- Cox and logistic ITT within 0.3"
    local ++pass_count
}
else {
    display as error "  FAIL -- Cox and logistic ITT differ by more than 0.3"
    local ++fail_count
}

* =============================================================================
* TEST 4: Cox PP pipeline completes
* =============================================================================
local ++test_count
display ""
display "Test `test_count': Cox PP pipeline completes"

use "data/cox_dgp.dta", clear

local cox_pp_coef = .
local cox_pp_se = .

capture noisily {
    tte_prepare, id(id) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) ///
        covariates(x) estimand(PP)

    tte_expand, maxfollowup(8)

    tte_weight, switch_d_cov(x) stabilized truncate(1 99) nolog

    tte_fit, outcome_cov(x) model(cox) nolog

    local cox_pp_coef = _b[_tte_arm]
    local cox_pp_se   = _se[_tte_arm]
}

if _rc == 0 {
    display "  Cox PP coefficient: " %8.4f `cox_pp_coef' ///
        "  (SE: " %8.4f `cox_pp_se' ")"
    display as result "  PASS -- Cox PP pipeline completed"
    local ++pass_count
}
else {
    display as error "  FAIL -- Cox PP pipeline failed (rc=" _rc ")"
    local ++fail_count
}

* =============================================================================
* TEST 5: Cox PP coefficient negative
* =============================================================================
local ++test_count
display ""
display "Test `test_count': Cox PP coefficient negative"

if `cox_pp_coef' < 0 {
    display "  Cox PP coefficient: " %8.4f `cox_pp_coef'
    display as result "  PASS -- Cox PP correctly shows protective effect"
    local ++pass_count
}
else {
    display as error "  FAIL -- Cox PP coefficient is non-negative (" %8.4f `cox_pp_coef' ")"
    local ++fail_count
}

* =============================================================================
* TEST 6: tte_predict after Cox errors correctly
* =============================================================================
local ++test_count
display ""
display "Test `test_count': tte_predict after Cox errors correctly"

* tte_predict only supports logistic — Cox should error
capture noisily tte_predict, times(0(2)8) type(cum_inc)

if _rc != 0 {
    display "  tte_predict returned rc=" _rc " (expected: non-zero)"
    display as result "  PASS -- tte_predict correctly rejects Cox model"
    local ++pass_count
}
else {
    display as error "  FAIL -- tte_predict should have failed after Cox model"
    local ++fail_count
}

* =============================================================================
* SUMMARY
* =============================================================================
display ""
display "VALIDATION 13 SUMMARY: Cox Model Ground Truth"
display "Tests run:  `test_count'"
display "Passed:     `pass_count'"
display "Failed:     `fail_count'"
display ""
display "Key findings:"
display "  True log-OR = `true_effect' (OR = " %5.3f exp(`true_effect') ")"
display "  Logistic ITT: " %8.4f `logistic_coef'
display "  Cox ITT:      " %8.4f `cox_itt_coef'
display "  Cox PP:       " %8.4f `cox_pp_coef'

if `fail_count' > 0 {
    display as error "VALIDATION FAILED"
}
else {
    display as result "VALIDATION PASSED"
}

local v_status = cond(`fail_count' > 0, "FAIL", "PASS")
display ""
display "RESULT: V13 tests=`test_count' pass=`pass_count' fail=`fail_count' status=`v_status'"

log close val_cox
