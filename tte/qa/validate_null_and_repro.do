/*******************************************************************************
* validate_null_and_repro.do
*
* Negative control (true effect = 0) and reproducibility validation.
* Tests that the estimator correctly fails to reject when there is no effect,
* and that results are deterministic given the same seed.
*******************************************************************************/

version 16.0
set more off
set varabbrev off

* --- Setup (assumes working directory is tte/qa/) ---
capture ado uninstall tte
adopath ++ ".."
capture log close val_null
log using "validate_null_and_repro.log", replace nomsg name(val_null)
* Test counters
local test_count = 0
local pass_count = 0
local fail_count = 0

display "VALIDATION 6: Null Effect and Reproducibility"
display "Date: $S_DATE $S_TIME"
display ""

* =============================================================================
* DGP: Null effect (true treatment log-OR = 0)
* =============================================================================
capture program drop _dgp_null
program define _dgp_null
    syntax, n(integer) periods(integer) seed(integer)

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

    * Forward simulation
    forvalues t = 0/`=`periods'-1' {

        * Treatment (absorbing): carry forward, new initiators
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

        * Eligibility: not yet treated at start of period
        if `t' == 0 {
            replace eligible = 1 if period == 0
        }
        else {
            bysort id (period): replace eligible = ///
                (treatment[_n-1] == 0 & outcome[_n-1] == 0) if period == `t'
        }

        * Outcome: NO treatment effect (0 * treatment)
        quietly replace outcome = rbinomial(1, ///
            invlogit(-3.5 + 0.3*x + 0*treatment)) ///
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
* TEST 1: PP 95% CI covers 0
* =============================================================================
local ++test_count
display ""
display "Test `test_count': PP 95% CI covers 0 (null effect)"

_dgp_null, n(5000) periods(8) seed(60001)

tte_prepare, id(id) period(period) treatment(treatment) ///
    outcome(outcome) eligible(eligible) ///
    covariates(x) estimand(PP)

tte_expand, maxfollowup(6)

tte_weight, switch_d_cov(x) stabilized truncate(1 99) nolog

tte_fit, outcome_cov(x) ///
    followup_spec(quadratic) trial_period_spec(linear) nolog

local pp_coef = _b[_tte_arm]
local pp_se   = _se[_tte_arm]
local pp_ci_lo = `pp_coef' - 1.96 * `pp_se'
local pp_ci_hi = `pp_coef' + 1.96 * `pp_se'

display "  PP coefficient: " %8.4f `pp_coef' "  (SE: " %8.4f `pp_se' ")"
display "  95% CI: [" %8.4f `pp_ci_lo' ", " %8.4f `pp_ci_hi' "]"

if `pp_ci_lo' <= 0 & `pp_ci_hi' >= 0 {
    display as result "  PASS -- PP 95% CI covers 0"
    local ++pass_count
}
else {
    display as error "  FAIL -- PP 95% CI does not cover 0"
    local ++fail_count
}

* =============================================================================
* TEST 2: ITT 95% CI covers 0
* =============================================================================
local ++test_count
display ""
display "Test `test_count': ITT 95% CI covers 0 (null effect)"

_dgp_null, n(5000) periods(8) seed(60001)

tte_prepare, id(id) period(period) treatment(treatment) ///
    outcome(outcome) eligible(eligible) ///
    covariates(x) estimand(ITT)

tte_expand, maxfollowup(6)

tte_fit, outcome_cov(x) ///
    followup_spec(quadratic) trial_period_spec(linear) nolog

local itt_coef = _b[_tte_arm]
local itt_se   = _se[_tte_arm]
local itt_ci_lo = `itt_coef' - 1.96 * `itt_se'
local itt_ci_hi = `itt_coef' + 1.96 * `itt_se'

display "  ITT coefficient: " %8.4f `itt_coef' "  (SE: " %8.4f `itt_se' ")"
display "  95% CI: [" %8.4f `itt_ci_lo' ", " %8.4f `itt_ci_hi' "]"

if `itt_ci_lo' <= 0 & `itt_ci_hi' >= 0 {
    display as result "  PASS -- ITT 95% CI covers 0"
    local ++pass_count
}
else {
    display as error "  FAIL -- ITT 95% CI does not cover 0"
    local ++fail_count
}

* =============================================================================
* TEST 3: MC type-I error rate (100 reps)
* =============================================================================
local ++test_count
display ""
display "Test `test_count': MC type-I error rate (100 reps, N=1000)"

local n_reps = 100
local n_reject = 0
local n_success = 0

forvalues rep = 1/`n_reps' {
    if mod(`rep', 20) == 0 {
        display "  Replication `rep' of `n_reps'..."
    }

    local rep_seed = 60100 + `rep'

    capture {
        quietly {
            _dgp_null, n(1000) periods(8) seed(`rep_seed')

            tte_prepare, id(id) period(period) treatment(treatment) ///
                outcome(outcome) eligible(eligible) ///
                covariates(x) estimand(PP)

            tte_expand, maxfollowup(5)

            tte_weight, switch_d_cov(x) stabilized truncate(1 99) nolog

            tte_fit, outcome_cov(x) ///
                followup_spec(linear) trial_period_spec(linear) nolog

            local this_coef = _b[_tte_arm]
            local this_se   = _se[_tte_arm]
        }

        local this_z = abs(`this_coef' / `this_se')
        if `this_z' > 1.96 {
            local ++n_reject
        }
        local ++n_success
    }
}

display "  Successful reps: `n_success' of `n_reps'"
display "  Rejections at p<0.05: `n_reject'"

* Allow up to 15 rejections (15% tolerance for 100 reps)
* At 100 reps, P(X >= 15 | n=100, p=0.05) < 0.01
if `n_reject' <= 15 & `n_success' >= 60 {
    display as result "  PASS -- type-I error rate acceptable (`n_reject'/`n_success' rejected)"
    local ++pass_count
}
else {
    display as error "  FAIL -- type-I error rate too high (`n_reject'/`n_success' rejected)"
    local ++fail_count
}

* =============================================================================
* TEST 4: Same seed produces identical coefficients
* =============================================================================
local ++test_count
display ""
display "Test `test_count': Same seed produces identical coefficients"

* Run 1
_dgp_null, n(3000) periods(8) seed(12345)

tte_prepare, id(id) period(period) treatment(treatment) ///
    outcome(outcome) eligible(eligible) ///
    covariates(x) estimand(PP)

tte_expand, maxfollowup(6)

tte_weight, switch_d_cov(x) stabilized truncate(1 99) nolog

tte_fit, outcome_cov(x) ///
    followup_spec(linear) trial_period_spec(linear) nolog

local coef_run1 = _b[_tte_arm]
local se_run1   = _se[_tte_arm]

* Run 2 (same seed)
_dgp_null, n(3000) periods(8) seed(12345)

tte_prepare, id(id) period(period) treatment(treatment) ///
    outcome(outcome) eligible(eligible) ///
    covariates(x) estimand(PP)

tte_expand, maxfollowup(6)

tte_weight, switch_d_cov(x) stabilized truncate(1 99) nolog

tte_fit, outcome_cov(x) ///
    followup_spec(linear) trial_period_spec(linear) nolog

local coef_run2 = _b[_tte_arm]
local se_run2   = _se[_tte_arm]

display "  Run 1 coefficient: " %12.8f `coef_run1'
display "  Run 2 coefficient: " %12.8f `coef_run2'

if `coef_run1' == `coef_run2' & `se_run1' == `se_run2' {
    display as result "  PASS -- identical coefficients with same seed"
    local ++pass_count
}
else {
    display as error "  FAIL -- coefficients differ with same seed"
    local ++fail_count
}

* =============================================================================
* TEST 5: Different seed produces different coefficients
* =============================================================================
local ++test_count
display ""
display "Test `test_count': Different seed produces different coefficients"

* Run 3 (different seed)
_dgp_null, n(3000) periods(8) seed(67890)

tte_prepare, id(id) period(period) treatment(treatment) ///
    outcome(outcome) eligible(eligible) ///
    covariates(x) estimand(PP)

tte_expand, maxfollowup(6)

tte_weight, switch_d_cov(x) stabilized truncate(1 99) nolog

tte_fit, outcome_cov(x) ///
    followup_spec(linear) trial_period_spec(linear) nolog

local coef_run3 = _b[_tte_arm]

display "  Seed 12345 coefficient: " %12.8f `coef_run1'
display "  Seed 67890 coefficient: " %12.8f `coef_run3'

if `coef_run1' != `coef_run3' {
    display as result "  PASS -- different seeds produce different coefficients"
    local ++pass_count
}
else {
    display as error "  FAIL -- different seeds produce identical coefficients"
    local ++fail_count
}

* =============================================================================
* SUMMARY
* =============================================================================
display ""
display "VALIDATION 6 SUMMARY: Null Effect and Reproducibility"
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
display "RESULT: V6 tests=`test_count' pass=`pass_count' fail=`fail_count' status=`v_status'"

log close val_null
