/*******************************************************************************
* validate_edge_cases.do
*
* Edge cases and tte_validate strict mode validation.
* Tests boundary conditions: small samples, few events, single trial period,
* all binary covariates, and tte_validate error detection.
*******************************************************************************/

version 16.0
set more off
set varabbrev off

* --- Setup (assumes working directory is tte/qa/) ---
capture ado uninstall tte
adopath ++ ".."
capture log close val_edge
log using "validate_edge_cases.log", replace nomsg name(val_edge)
* Test counters
local test_count = 0
local pass_count = 0
local fail_count = 0

display "VALIDATION 9: Edge Cases and Strict Validation"
display "Date: $S_DATE $S_TIME"
display ""

* =============================================================================
* Small DGP helper program
* =============================================================================
capture program drop _dgp_small
program define _dgp_small
    syntax, n(integer) periods(integer) seed(integer) [outcome_intercept(real -3.5)]

    clear
    set seed `seed'
    quietly set obs `n'

    generate long id = _n
    generate byte x = rbinomial(1, 0.4)

    expand `periods'
    bysort id: generate period = _n - 1
    sort id period

    generate byte treatment = 0
    generate byte outcome = 0
    generate byte eligible = 1

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
            invlogit(`outcome_intercept' + 0.3*x - 0.50*treatment)) ///
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
* TEST 1: Small N (N=50) — ITT pipeline completes
* =============================================================================
local ++test_count
display ""
display "Test `test_count': Small N (N=50) ITT pipeline"

capture noisily {
    _dgp_small, n(50) periods(8) seed(90001)

    tte_prepare, id(id) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) ///
        covariates(x) estimand(ITT)

    tte_validate

    tte_expand, maxfollowup(6)

    tte_fit, outcome_cov(x) ///
        followup_spec(linear) trial_period_spec(linear) nolog
}

if _rc == 0 {
    display as result "  PASS -- ITT pipeline completed with N=50"
    local ++pass_count
}
else {
    display as error "  FAIL -- ITT pipeline failed with N=50 (rc=" _rc ")"
    local ++fail_count
}

* =============================================================================
* TEST 2: Very few events (low event rate)
* =============================================================================
local ++test_count
display ""
display "Test `test_count': Very few events (low event rate)"

capture noisily {
    _dgp_small, n(200) periods(6) seed(90002) outcome_intercept(-6)

    quietly count if outcome == 1
    local n_events = r(N)
    display "  Events in data: `n_events'"

    tte_prepare, id(id) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) ///
        covariates(x) estimand(ITT)

    tte_expand, maxfollowup(4)

    tte_fit, outcome_cov(x) ///
        followup_spec(linear) trial_period_spec(linear) nolog
}

if _rc == 0 {
    display as result "  PASS -- ITT pipeline completed with few events"
    local ++pass_count
}
else {
    display as error "  FAIL -- ITT pipeline failed with few events (rc=" _rc ")"
    local ++fail_count
}

* =============================================================================
* TEST 3: Single eligible period
* =============================================================================
local ++test_count
display ""
display "Test `test_count': Single eligible period (all eligible at period 0 only)"

clear
set seed 90003
quietly set obs 500

generate long id = _n
generate byte x = rbinomial(1, 0.4)

* 6 periods but only period 0 is eligible
expand 6
bysort id: generate period = _n - 1
sort id period

generate byte treatment = 0
generate byte outcome = 0
generate byte eligible = (period == 0)

* Treatment at period 0 only
quietly replace treatment = rbinomial(1, invlogit(-2 + 0.3*x)) if period == 0

* Absorbing treatment
bysort id (period): replace treatment = treatment[_n-1] if _n > 1 & treatment[_n-1] == 1

* Outcome
forvalues t = 0/5 {
    quietly replace outcome = rbinomial(1, invlogit(-3.5 + 0.3*x - 0.50*treatment)) ///
        if period == `t' & outcome == 0
    if `t' > 0 {
        bysort id (period): replace outcome = 1 ///
            if period == `t' & outcome[_n-1] == 1
    }
}

* Remove post-outcome rows
bysort id (period): generate byte _first = (outcome == 1 & ///
    (period == 0 | outcome[_n-1] == 0))
bysort id (period): generate byte _cum = sum(_first)
drop if _cum > 1
drop _first _cum

capture noisily {
    tte_prepare, id(id) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) ///
        covariates(x) estimand(ITT)

    tte_expand, maxfollowup(5)
    local n_trials = r(n_trials)
}

* Guard: check if r(n_trials) was actually returned
if missing("`n_trials'") | "`n_trials'" == "" | "`n_trials'" == "." {
    display as error "  FAIL -- r(n_trials) not returned by tte_expand"
    local ++fail_count
}
else {
    display "  Number of trials created: `n_trials'"

    if _rc == 0 & `n_trials' == 1 {
        display as result "  PASS -- exactly 1 trial created from single eligible period"
        local ++pass_count
    }
    else if _rc == 0 {
        display as error "  FAIL -- expected 1 trial but got `n_trials'"
        local ++fail_count
    }
    else {
        display as error "  FAIL -- pipeline failed (rc=" _rc ")"
        local ++fail_count
    }
}

* =============================================================================
* TEST 4: All binary covariates — PP pipeline with non-degenerate weights
* =============================================================================
local ++test_count
display ""
display "Test `test_count': All binary covariates, PP pipeline"

clear
set seed 90004
quietly set obs 2000

generate long id = _n
generate byte x1 = rbinomial(1, 0.3)
generate byte x2 = rbinomial(1, 0.5)
generate byte x3 = rbinomial(1, 0.6)

expand 8
bysort id: generate period = _n - 1
sort id period

generate byte treatment = 0
generate byte outcome = 0
generate byte eligible = 1

forvalues t = 0/7 {
    if `t' > 0 {
        bysort id (period): replace treatment = treatment[_n-1] if period == `t'
        quietly replace treatment = 1 ///
            if period == `t' & treatment == 0 ///
            & rbinomial(1, invlogit(-2 + 0.3*x1 + 0.2*x2 + 0.1*x3)) == 1
    }
    else {
        quietly replace treatment = rbinomial(1, invlogit(-2 + 0.3*x1 + 0.2*x2 + 0.1*x3)) ///
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
        invlogit(-3.5 + 0.3*x1 + 0.2*x2 - 0.50*treatment)) ///
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

capture noisily {
    tte_prepare, id(id) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) ///
        covariates(x1 x2 x3) estimand(PP)

    tte_expand, maxfollowup(6)

    tte_weight, switch_d_cov(x1 x2 x3) stabilized truncate(1 99) nolog

    tte_fit, outcome_cov(x1 x2 x3) ///
        followup_spec(linear) trial_period_spec(linear) nolog
}

if _rc == 0 {
    quietly summarize _tte_weight
    local w_mean = r(mean)

    * Calculate ESS
    quietly {
        summarize _tte_weight
        local sum_w = r(sum)
        tempvar _w2
        generate double `_w2' = _tte_weight^2
        summarize `_w2'
        local sum_w2 = r(sum)
        drop `_w2'
    }
    local ess = (`sum_w'^2) / `sum_w2'

    display "  Mean weight: " %8.4f `w_mean'
    display "  ESS: " %10.1f `ess'

    if `w_mean' > 0 & `ess' > 10 {
        display as result "  PASS -- PP pipeline with all binary covariates works (ESS=" %10.1f `ess' ")"
        local ++pass_count
    }
    else {
        display as error "  FAIL -- degenerate weights (mean=" %8.4f `w_mean' ", ESS=" %10.1f `ess' ")"
        local ++fail_count
    }
}
else {
    display as error "  FAIL -- PP pipeline failed with binary covariates (rc=" _rc ")"
    local ++fail_count
}

* =============================================================================
* TEST 5: tte_validate strict — period gaps
* =============================================================================
local ++test_count
display ""
display "Test `test_count': tte_validate strict catches period gaps"

* Create data with gap in periods (0, 1, 3, 4 — missing period 2)
clear
quietly {
    set obs 100
    generate long id = _n
    generate byte x = rbinomial(1, 0.4)

    expand 4
    bysort id: generate period_seq = _n
    * Map: 1->0, 2->1, 3->3, 4->4 (skip period 2)
    generate period = cond(period_seq <= 2, period_seq - 1, period_seq)
    drop period_seq
    sort id period

    generate byte treatment = rbinomial(1, 0.15) if period == 0
    bysort id (period): replace treatment = treatment[_n-1] if _n > 1 & missing(treatment)
    bysort id (period): replace treatment = treatment[_n-1] if _n > 1 & treatment[_n-1] == 1
    replace treatment = 0 if missing(treatment)
    generate byte outcome = rbinomial(1, 0.02)
    generate byte eligible = 1
}

tte_prepare, id(id) period(period) treatment(treatment) ///
    outcome(outcome) eligible(eligible) ///
    covariates(x) estimand(ITT)

capture noisily tte_validate, strict

if _rc == 198 {
    display as result "  PASS -- tte_validate strict correctly rejects period gaps (rc=198)"
    local ++pass_count
}
else {
    display as error "  FAIL -- expected rc=198 but got rc=" _rc
    local ++fail_count
}

* =============================================================================
* TEST 6: tte_validate strict — post-outcome rows
* =============================================================================
local ++test_count
display ""
display "Test `test_count': tte_validate strict catches post-outcome rows"

* Create data where outcome=1 at period 3 but rows exist at period 4
clear
quietly {
    set obs 80
    generate long id = _n
    generate byte x = rbinomial(1, 0.4)

    expand 6
    bysort id: generate period = _n - 1
    sort id period

    generate byte treatment = rbinomial(1, 0.15) if period == 0
    bysort id (period): replace treatment = treatment[_n-1] if _n > 1 & missing(treatment)
    bysort id (period): replace treatment = treatment[_n-1] if _n > 1 & treatment[_n-1] == 1
    replace treatment = 0 if missing(treatment)

    generate byte outcome = 0
    generate byte eligible = 1

    * Set outcome=1 at period 3 for first 20 individuals
    * but keep rows at period 4 and 5 (this is the error)
    replace outcome = 1 if id <= 20 & period == 3
}

tte_prepare, id(id) period(period) treatment(treatment) ///
    outcome(outcome) eligible(eligible) ///
    covariates(x) estimand(ITT)

capture noisily tte_validate, strict

if _rc == 198 {
    display as result "  PASS -- tte_validate strict correctly rejects post-outcome rows (rc=198)"
    local ++pass_count
}
else {
    display as error "  FAIL -- expected rc=198 but got rc=" _rc
    local ++fail_count
}

* =============================================================================
* TEST 7: tte_validate strict — missing data
* =============================================================================
local ++test_count
display ""
display "Test `test_count': tte_validate strict catches missing data"

* Create data with missing values in treatment
clear
quietly {
    set obs 80
    generate long id = _n
    generate byte x = rbinomial(1, 0.4)

    expand 6
    bysort id: generate period = _n - 1
    sort id period

    generate byte treatment = rbinomial(1, 0.15) if period == 0
    bysort id (period): replace treatment = treatment[_n-1] if _n > 1 & missing(treatment)
    bysort id (period): replace treatment = treatment[_n-1] if _n > 1 & treatment[_n-1] == 1
    replace treatment = 0 if missing(treatment)

    generate byte outcome = rbinomial(1, 0.02)
    generate byte eligible = 1

    * Introduce missing values in treatment for some observations
    replace treatment = . if id <= 5 & period == 2
}

tte_prepare, id(id) period(period) treatment(treatment) ///
    outcome(outcome) eligible(eligible) ///
    covariates(x) estimand(ITT)

capture noisily tte_validate, strict

if _rc == 198 {
    display as result "  PASS -- tte_validate strict correctly rejects missing data (rc=198)"
    local ++pass_count
}
else {
    display as error "  FAIL -- expected rc=198 but got rc=" _rc
    local ++fail_count
}

* =============================================================================
* TEST 8: tte_validate (no strict) — gaps produce warnings, not errors
* =============================================================================
local ++test_count
display ""
display "Test `test_count': tte_validate (no strict) produces warnings for gaps"

* Recreate gaps data
clear
quietly {
    set obs 100
    generate long id = _n
    generate byte x = rbinomial(1, 0.4)

    expand 4
    bysort id: generate period_seq = _n
    generate period = cond(period_seq <= 2, period_seq - 1, period_seq)
    drop period_seq
    sort id period

    generate byte treatment = rbinomial(1, 0.15) if period == 0
    bysort id (period): replace treatment = treatment[_n-1] if _n > 1 & missing(treatment)
    bysort id (period): replace treatment = treatment[_n-1] if _n > 1 & treatment[_n-1] == 1
    replace treatment = 0 if missing(treatment)
    generate byte outcome = rbinomial(1, 0.02)
    generate byte eligible = 1
}

tte_prepare, id(id) period(period) treatment(treatment) ///
    outcome(outcome) eligible(eligible) ///
    covariates(x) estimand(ITT)

capture noisily tte_validate

local validate_rc = _rc
local n_warnings = r(n_warnings)

display "  Return code: `validate_rc'"
display "  Warnings: `n_warnings'"

if `validate_rc' == 0 & `n_warnings' > 0 {
    display as result "  PASS -- tte_validate (no strict) returns rc=0 with warnings"
    local ++pass_count
}
else if `validate_rc' == 0 & `n_warnings' == 0 {
    display as error "  FAIL -- no warnings generated for gaps data"
    local ++fail_count
}
else {
    display as error "  FAIL -- unexpected return code `validate_rc'"
    local ++fail_count
}

* =============================================================================
* SUMMARY
* =============================================================================
display ""
display "VALIDATION 9 SUMMARY: Edge Cases and Strict Validation"
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
display "RESULT: V9 tests=`test_count' pass=`pass_count' fail=`fail_count' status=`v_status'"

log close val_edge
