/*******************************************************************************
* validate_grace_period.do
*
* Grace period correctness validation.
* Tests that increasing the grace period monotonically decreases artificial
* censoring, and that a large grace period approximates the ITT estimate.
*******************************************************************************/

version 16.0
set more off
set varabbrev off

* --- Setup (assumes working directory is tte/qa/) ---
capture ado uninstall tte
adopath ++ ".."
capture log close val_grace
log using "validate_grace_period.log", replace nomsg name(val_grace)
* Test counters
local test_count = 0
local pass_count = 0
local fail_count = 0

display "VALIDATION 8: Grace Period Correctness"
display "Date: $S_DATE $S_TIME"
display ""

* =============================================================================
* DGP: Deterministic switching patterns for grace period testing
* =============================================================================
capture program drop _dgp_grace
program define _dgp_grace
    syntax, n(integer) periods(integer) seed(integer)

    clear
    set seed `seed'
    quietly set obs `n'

    generate long id = _n
    generate byte x = rbinomial(1, 0.4)

    * Assign treatment groups:
    *   30% start treatment at period 0 (some stop at period 3-5)
    *   70% never treated
    generate double _u = runiform()
    generate byte treat_group = 0
    replace treat_group = 1 if _u < 0.15   // start, stop at period 3
    replace treat_group = 2 if _u >= 0.15 & _u < 0.25  // start, stop at period 5
    replace treat_group = 3 if _u >= 0.25 & _u < 0.30  // start, never stop
    drop _u

    expand `periods'
    bysort id: generate period = _n - 1
    sort id period

    * Deterministic treatment assignment
    generate byte treatment = 0

    * Group 1: treated periods 0-2, stops at period 3
    replace treatment = 1 if treat_group == 1 & period <= 2

    * Group 2: treated periods 0-4, stops at period 5
    replace treatment = 1 if treat_group == 2 & period <= 4

    * Group 3: treated all periods
    replace treatment = 1 if treat_group == 3

    * Outcome: P(Y=1) = invlogit(-3.5 + 0.3*x - 0.50*treatment)
    generate byte outcome = 0
    forvalues t = 0/`=`periods'-1' {
        quietly replace outcome = rbinomial(1, ///
            invlogit(-3.5 + 0.3*x - 0.50*treatment)) ///
            if period == `t' & outcome == 0

        if `t' > 0 {
            bysort id (period): replace outcome = 1 ///
                if period == `t' & outcome[_n-1] == 1
        }
    }

    * Eligibility: not yet treated at start of period
    generate byte eligible = 1
    forvalues t = 1/`=`periods'-1' {
        bysort id (period): replace eligible = ///
            (treatment[_n-1] == 0 & outcome[_n-1] == 0) if period == `t'
    }

    * Remove person-periods after first outcome
    bysort id (period): generate byte _first = (outcome == 1 & ///
        (period == 0 | outcome[_n-1] == 0))
    bysort id (period): generate byte _cum = sum(_first)
    drop if _cum > 1
    drop _first _cum

    drop treat_group
end

* =============================================================================
* Generate base dataset
* =============================================================================
display "Generating grace period validation dataset..."
_dgp_grace, n(3000) periods(12) seed(80001)

quietly count
display "  Person-periods: " r(N)

save "data/grace_dgp.dta", replace

* =============================================================================
* Run ITT for reference
* =============================================================================
display ""
display "Running ITT reference..."

use "data/grace_dgp.dta", clear

tte_prepare, id(id) period(period) treatment(treatment) ///
    outcome(outcome) eligible(eligible) ///
    covariates(x) estimand(ITT)

tte_expand, maxfollowup(10)

tte_fit, outcome_cov(x) ///
    followup_spec(quadratic) trial_period_spec(linear) nolog

local itt_coef = _b[_tte_arm]
display "  ITT coefficient: " %8.4f `itt_coef'

* =============================================================================
* Run PP with different grace periods and store results
* =============================================================================

* grace(0)
display ""
display "Running PP with grace(0)..."

use "data/grace_dgp.dta", clear

tte_prepare, id(id) period(period) treatment(treatment) ///
    outcome(outcome) eligible(eligible) ///
    covariates(x) estimand(PP)

tte_expand, maxfollowup(10) grace(0)

quietly count if _tte_censored == 1
local cens_g0 = r(N)

tte_weight, switch_d_cov(x) stabilized truncate(1 99) nolog

tte_fit, outcome_cov(x) ///
    followup_spec(quadratic) trial_period_spec(linear) nolog

local coef_g0 = _b[_tte_arm]

display "  Grace(0): censored = `cens_g0', coef = " %8.4f `coef_g0'

* grace(1)
display ""
display "Running PP with grace(1)..."

use "data/grace_dgp.dta", clear

tte_prepare, id(id) period(period) treatment(treatment) ///
    outcome(outcome) eligible(eligible) ///
    covariates(x) estimand(PP)

tte_expand, maxfollowup(10) grace(1)

quietly count if _tte_censored == 1
local cens_g1 = r(N)

tte_weight, switch_d_cov(x) stabilized truncate(1 99) nolog

tte_fit, outcome_cov(x) ///
    followup_spec(quadratic) trial_period_spec(linear) nolog

local coef_g1 = _b[_tte_arm]

display "  Grace(1): censored = `cens_g1', coef = " %8.4f `coef_g1'

* grace(2)
display ""
display "Running PP with grace(2)..."

use "data/grace_dgp.dta", clear

tte_prepare, id(id) period(period) treatment(treatment) ///
    outcome(outcome) eligible(eligible) ///
    covariates(x) estimand(PP)

tte_expand, maxfollowup(10) grace(2)

quietly count if _tte_censored == 1
local cens_g2 = r(N)

tte_weight, switch_d_cov(x) stabilized truncate(1 99) nolog

tte_fit, outcome_cov(x) ///
    followup_spec(quadratic) trial_period_spec(linear) nolog

local coef_g2 = _b[_tte_arm]

display "  Grace(2): censored = `cens_g2', coef = " %8.4f `coef_g2'

* grace(3)
display ""
display "Running PP with grace(3)..."

use "data/grace_dgp.dta", clear

tte_prepare, id(id) period(period) treatment(treatment) ///
    outcome(outcome) eligible(eligible) ///
    covariates(x) estimand(PP)

tte_expand, maxfollowup(10) grace(3)

quietly count if _tte_censored == 1
local cens_g3 = r(N)

tte_weight, switch_d_cov(x) stabilized truncate(1 99) nolog

tte_fit, outcome_cov(x) ///
    followup_spec(quadratic) trial_period_spec(linear) nolog

local coef_g3 = _b[_tte_arm]

display "  Grace(3): censored = `cens_g3', coef = " %8.4f `coef_g3'

* grace(11) — near ITT
display ""
display "Running PP with grace(11) (near ITT)..."

use "data/grace_dgp.dta", clear

tte_prepare, id(id) period(period) treatment(treatment) ///
    outcome(outcome) eligible(eligible) ///
    covariates(x) estimand(PP)

tte_expand, maxfollowup(10) grace(11)

quietly count if _tte_censored == 1
local cens_g11 = r(N)

tte_weight, switch_d_cov(x) stabilized truncate(1 99) nolog

tte_fit, outcome_cov(x) ///
    followup_spec(quadratic) trial_period_spec(linear) nolog

local coef_g11 = _b[_tte_arm]

display "  Grace(11): censored = `cens_g11', coef = " %8.4f `coef_g11'

* =============================================================================
* Display summary of grace period results
* =============================================================================
display ""
display "Grace period results summary:"
display "  Grace(0):  censored = `cens_g0',  coef = " %8.4f `coef_g0'
display "  Grace(1):  censored = `cens_g1',  coef = " %8.4f `coef_g1'
display "  Grace(2):  censored = `cens_g2',  coef = " %8.4f `coef_g2'
display "  Grace(3):  censored = `cens_g3',  coef = " %8.4f `coef_g3'
display "  Grace(11): censored = `cens_g11', coef = " %8.4f `coef_g11'
display "  ITT:                              coef = " %8.4f `itt_coef'

* =============================================================================
* TEST 1: grace(0) produces censored observations
* =============================================================================
local ++test_count
display ""
display "Test `test_count': grace(0) produces censored observations"

if `cens_g0' > 0 {
    display as result "  PASS -- grace(0) censored count = `cens_g0'"
    local ++pass_count
}
else {
    display as error "  FAIL -- grace(0) produced no censored observations"
    local ++fail_count
}

* =============================================================================
* TEST 2: grace(1) has fewer censored than grace(0)
* =============================================================================
local ++test_count
display ""
display "Test `test_count': grace(1) fewer censored than grace(0)"

display "  grace(0) censored: `cens_g0'"
display "  grace(1) censored: `cens_g1'"

if `cens_g1' < `cens_g0' {
    display as result "  PASS -- grace(1) censored < grace(0) censored"
    local ++pass_count
}
else {
    display as error "  FAIL -- grace(1) censored >= grace(0) censored"
    local ++fail_count
}

* =============================================================================
* TEST 3: Monotonic decrease in censored count
* =============================================================================
local ++test_count
display ""
display "Test `test_count': Monotonic decrease in censored count (grace 0-3)"

display "  g0=`cens_g0' >= g1=`cens_g1' >= g2=`cens_g2' >= g3=`cens_g3'"

if `cens_g0' >= `cens_g1' & `cens_g1' >= `cens_g2' & `cens_g2' >= `cens_g3' {
    display as result "  PASS -- monotonically decreasing censored counts"
    local ++pass_count
}
else {
    display as error "  FAIL -- censored counts not monotonically decreasing"
    local ++fail_count
}

* =============================================================================
* TEST 4: grace(11) approximates ITT
* =============================================================================
local ++test_count
display ""
display "Test `test_count': grace(11) coefficient close to ITT"

local grace_itt_diff = abs(`coef_g11' - `itt_coef')

display "  grace(11) coefficient: " %8.4f `coef_g11'
display "  ITT coefficient:       " %8.4f `itt_coef'
display "  Difference:            " %8.4f `grace_itt_diff'

if `grace_itt_diff' < 0.3 {
    display as result "  PASS -- grace(11) is within 0.3 of ITT"
    local ++pass_count
}
else {
    display as error "  FAIL -- grace(11) is too far from ITT (diff = " %8.4f `grace_itt_diff' ")"
    local ++fail_count
}

* =============================================================================
* TEST 5: Spot-check individual censoring timing
* =============================================================================
local ++test_count
display ""
display "Test `test_count': Spot-check individual censoring timing"

* Reload data and expand with grace(0)
use "data/grace_dgp.dta", clear

tte_prepare, id(id) period(period) treatment(treatment) ///
    outcome(outcome) eligible(eligible) ///
    covariates(x) estimand(PP)

tte_expand, maxfollowup(10) grace(0)

* Find a person in the control arm who was censored (started treatment)
* Look at trial 0, control arm
quietly {
    * Find an individual who was censored in control arm at trial 0
    generate byte _spot = (_tte_trial == 0 & _tte_arm == 0 & _tte_censored == 1)
    summarize id if _spot == 1
    local spot_id = r(min)
}

local spot_found = (!missing(`spot_id') & `spot_id' > 0)

if `spot_found' {
    * Check that this person was censored when they started treatment
    quietly {
        * Get the follow-up period where censored
        summarize _tte_followup if id == `spot_id' & _tte_trial == 0 & _tte_arm == 0 & _tte_censored == 1
        local cens_fu = r(mean)

        * Check that treatment == 1 at the censoring time
        summarize treatment if id == `spot_id' & _tte_trial == 0 & _tte_arm == 0 & _tte_followup == `cens_fu'
        local treat_at_cens = r(mean)
    }

    display "  Individual `spot_id': censored at follow-up `cens_fu'"
    display "  Treatment at censoring: `treat_at_cens'"

    if `treat_at_cens' == 1 {
        display as result "  PASS -- individual correctly censored when starting treatment"
        local ++pass_count
    }
    else {
        display as error "  FAIL -- censoring not aligned with treatment switch"
        local ++fail_count
    }
    drop _spot
}
else {
    * No censored individuals found in control arm trial 0 - check if data valid
    display "  No censored control-arm individual found at trial 0"
    display "  Checking alternative: any censored individual in control arm"

    quietly {
        summarize id if _tte_arm == 0 & _tte_censored == 1
        local alt_id = r(min)
    }

    if !missing(`alt_id') & `alt_id' > 0 {
        quietly {
            summarize _tte_trial if id == `alt_id' & _tte_arm == 0 & _tte_censored == 1
            local alt_trial = r(min)
            summarize _tte_followup if id == `alt_id' & _tte_trial == `alt_trial' & _tte_arm == 0 & _tte_censored == 1
            local alt_fu = r(mean)
            summarize treatment if id == `alt_id' & _tte_trial == `alt_trial' & _tte_arm == 0 & _tte_followup == `alt_fu'
            local alt_treat = r(mean)
        }
        display "  Individual `alt_id' (trial `alt_trial'): censored at follow-up `alt_fu', treatment=`alt_treat'"
        if `alt_treat' == 1 {
            display as result "  PASS -- individual correctly censored when starting treatment"
            local ++pass_count
        }
        else {
            display as error "  FAIL -- censoring not aligned with treatment switch"
            local ++fail_count
        }
    }
    else {
        display as error "  FAIL -- no censored control-arm individuals found"
        local ++fail_count
    }
}

* =============================================================================
* TEST 6: All grace values produce coefficients that are negative or near zero
* =============================================================================
local ++test_count
display ""
display "Test `test_count': All grace period coefficients negative or near zero"

display "  g0=" %8.4f `coef_g0' "  g1=" %8.4f `coef_g1' "  g2=" %8.4f `coef_g2' "  g3=" %8.4f `coef_g3' "  g11=" %8.4f `coef_g11'

* With large grace periods the PP estimate converges to ITT (near zero)
* so allow coefficients that are negative OR within 0.10 of zero
local all_ok = (`coef_g0' < 0.10 & `coef_g1' < 0.10 & `coef_g2' < 0.10 & `coef_g3' < 0.10 & `coef_g11' < 0.10)

if `all_ok' {
    display as result "  PASS -- all grace period coefficients are negative or near zero"
    local ++pass_count
}
else {
    display as error "  FAIL -- at least one grace period coefficient is substantially positive"
    local ++fail_count
}

* =============================================================================
* SUMMARY
* =============================================================================
display ""
display "VALIDATION 8 SUMMARY: Grace Period Correctness"
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
display "RESULT: V8 tests=`test_count' pass=`pass_count' fail=`fail_count' status=`v_status'"

log close val_grace
