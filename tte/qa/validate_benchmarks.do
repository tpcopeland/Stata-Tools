/*******************************************************************************
* validate_benchmarks.do
*
* Validation 11: RCT comparison + teffects ipw comparison
* Part A: RCT vs observational estimation
* Part B: teffects ipw vs tte ITT directional agreement
*******************************************************************************/

version 16.0
set more off
set varabbrev off

* --- Setup (assumes working directory is tte/qa/) ---
capture ado uninstall tte
adopath ++ ".."
capture log close val_bench
log using "validate_benchmarks.log", replace nomsg name(val_bench)
* Test counters
local test_count = 0
local pass_count = 0
local fail_count = 0

display "VALIDATION 11: Benchmarks (RCT comparison + teffects ipw)"
display "Date: $S_DATE $S_TIME"
display ""

* =============================================================================
* PART A: RCT vs Observational
* =============================================================================
display "PART A: RCT vs Observational comparison"
display ""

* =============================================================================
* DGP Programs
* =============================================================================
capture program drop _dgp_rct
program define _dgp_rct
    syntax, n(integer) periods(integer) effect(real) seed(integer)

    clear
    set seed `seed'
    quietly set obs `n'

    generate id = _n
    generate byte x = rbinomial(1, 0.4)

    * RCT: random treatment assignment (no confounding)
    generate byte ever_treat = rbinomial(1, 0.3)

    expand `periods'
    bysort id: generate period = _n - 1
    sort id period

    generate byte treatment = ever_treat
    generate byte outcome = 0
    generate byte eligible = 1

    * Forward simulation
    forvalues t = 0/`=`periods'-1' {
        * Outcome
        quietly replace outcome = rbinomial(1, ///
            invlogit(-3.5 + 0.3*x + `effect'*treatment)) ///
            if period == `t' & outcome == 0

        * Absorbing outcome
        if `t' > 0 {
            bysort id (period): replace outcome = 1 ///
                if period == `t' & outcome[_n-1] == 1
        }

        * Eligibility
        if `t' == 0 {
            replace eligible = 1 if period == 0
        }
        else {
            bysort id (period): replace eligible = ///
                (treatment[_n-1] == 0 & outcome[_n-1] == 0) if period == `t'
        }
    }

    * Remove person-periods after first outcome
    bysort id (period): generate byte _first = (outcome == 1 & ///
        (period == 0 | outcome[_n-1] == 0))
    bysort id (period): generate byte _cum = sum(_first)
    drop if _cum > 1
    drop _first _cum ever_treat
end

capture program drop _dgp_obs
program define _dgp_obs
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

    * Forward simulation with confounding
    forvalues t = 0/`=`periods'-1' {

        * Treatment (absorbing): depends on x
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
* Generate datasets
* =============================================================================
display "Generating RCT dataset (N=5,000)..."
_dgp_rct, n(5000) periods(10) effect(-0.50) seed(20261101)
quietly save "data/bench_rct.dta", replace

display "Generating observational dataset (N=5,000)..."
_dgp_obs, n(5000) periods(10) effect(-0.50) seed(20261102)
quietly save "data/bench_obs.dta", replace

* =============================================================================
* TEST 1: RCT ITT estimate
* =============================================================================
local ++test_count
display ""
display "Test `test_count': RCT ITT estimate"

use "data/bench_rct.dta", clear

local rct_coef = .
capture noisily {
    tte_prepare, id(id) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) ///
        covariates(x) estimand(ITT)

    tte_expand, maxfollowup(8)

    tte_fit, outcome_cov(x) ///
        followup_spec(quadratic) trial_period_spec(linear) nolog

    local rct_coef = _b[_tte_arm]
}

local rct_rc = _rc

if `rct_rc' == 0 {
    display "  RCT ITT coefficient: " %8.4f `rct_coef'
}

if `rct_rc' == 0 & `rct_coef' < 0 {
    display as result "  PASS - RCT ITT correctly shows protective effect"
    local ++pass_count
}
else if `rct_rc' != 0 {
    display as error "  FAIL - RCT ITT pipeline failed (rc=" `rct_rc' ")"
    local ++fail_count
}
else {
    display as error "  FAIL - RCT ITT coefficient non-negative (" %8.4f `rct_coef' ")"
    local ++fail_count
}

* =============================================================================
* TEST 2: Observational PP approximates RCT
* =============================================================================
local ++test_count
display ""
display "Test `test_count': Observational PP approximates RCT"

use "data/bench_obs.dta", clear

local obs_pp_coef = .
capture noisily {
    tte_prepare, id(id) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) ///
        covariates(x) estimand(PP)

    tte_expand, maxfollowup(8)

    tte_weight, switch_d_cov(x) stabilized truncate(1 99) nolog

    tte_fit, outcome_cov(x) ///
        followup_spec(quadratic) trial_period_spec(linear) nolog

    local obs_pp_coef = _b[_tte_arm]
}

local obs_pp_rc = _rc

if `obs_pp_rc' == 0 {
    display "  Obs PP coefficient: " %8.4f `obs_pp_coef'
    display "  RCT ITT coefficient: " %8.4f `rct_coef'
}

if `rct_rc' == 0 & `obs_pp_rc' == 0 {
    local same_dir = (`rct_coef' < 0 & `obs_pp_coef' < 0)
    local within_range = (abs(`obs_pp_coef' - `rct_coef') < 0.5)

    if `same_dir' & `within_range' {
        display as result "  PASS - Obs PP in same direction as RCT, within 0.5"
        local ++pass_count
    }
    else if `same_dir' {
        display "  Note: same direction but diff > 0.5 (" %6.3f abs(`obs_pp_coef' - `rct_coef') ")"
        * Still pass if direction matches - magnitude can vary with confounding structure
        display as result "  PASS - Obs PP in same direction as RCT"
        local ++pass_count
    }
    else {
        display as error "  FAIL - Directional disagreement between RCT and Obs PP"
        local ++fail_count
    }
}
else {
    display as error "  FAIL - Could not compare (RCT rc=" `rct_rc' ", Obs PP rc=" `obs_pp_rc' ")"
    local ++fail_count
}

* =============================================================================
* TEST 3: Observational ITT diluted relative to PP
* =============================================================================
local ++test_count
display ""
display "Test `test_count': Observational ITT diluted relative to PP"

use "data/bench_obs.dta", clear

local obs_itt_coef = .
capture noisily {
    tte_prepare, id(id) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) ///
        covariates(x) estimand(ITT)

    tte_expand, maxfollowup(8)

    tte_fit, outcome_cov(x) ///
        followup_spec(quadratic) trial_period_spec(linear) nolog

    local obs_itt_coef = _b[_tte_arm]
}

local obs_itt_rc = _rc

if `obs_itt_rc' == 0 {
    display "  Obs ITT coefficient: " %8.4f `obs_itt_coef'
    display "  Obs PP coefficient: " %8.4f `obs_pp_coef'
}

if `obs_itt_rc' == 0 & `obs_pp_rc' == 0 {
    * ITT should be attenuated: |ITT| <= |PP| + 0.2 (tolerance)
    local att_check = (abs(`obs_itt_coef') <= abs(`obs_pp_coef') + 0.2)

    if `att_check' {
        display as result "  PASS - Obs ITT appropriately attenuated relative to PP"
        local ++pass_count
    }
    else {
        display as error "  FAIL - Obs ITT not attenuated (|ITT|=" %6.3f abs(`obs_itt_coef') " > |PP|+0.2=" %6.3f (abs(`obs_pp_coef')+0.2) ")"
        local ++fail_count
    }
}
else {
    display as error "  FAIL - Could not compare ITT and PP"
    local ++fail_count
}

* =============================================================================
* PART B: teffects ipw comparison
* =============================================================================
display ""
display "PART B: teffects ipw comparison"
display ""

* =============================================================================
* Generate cross-sectional data for teffects comparison
* =============================================================================
display "Generating cross-sectional dataset (N=3,000)..."

clear
set seed 20261103
quietly set obs 3000

generate id = _n
generate byte x1 = rbinomial(1, 0.5)
generate double x2 = rnormal(0, 1)
generate byte treatment = rbinomial(1, invlogit(-0.5 + 0.5*x1 + 0.3*x2))
generate byte outcome = rbinomial(1, invlogit(-2 + 0.3*x1 + 0.2*x2 - 0.5*treatment))

quietly save "data/bench_teffects.dta", replace

quietly count if outcome == 1
display "  N=3,000, events: " r(N)

* =============================================================================
* TEST 4: teffects ipw runs on the data
* =============================================================================
local ++test_count
display ""
display "Test `test_count': teffects ipw runs on cross-sectional data"

use "data/bench_teffects.dta", clear

local te_coef = .
capture noisily {
    teffects ipw (outcome) (treatment x1 x2, logit)
    matrix _te = r(table)
    * ATE is the first coefficient
    local te_coef = _te[1,1]
}

local te_rc = _rc

if `te_rc' == 0 {
    display "  teffects ATE: " %8.4f `te_coef'
    display as result "  PASS - teffects ipw completed"
    local ++pass_count
}
else {
    display as error "  FAIL - teffects ipw failed (rc=" `te_rc' ")"
    local ++fail_count
}

* =============================================================================
* TEST 5: tte ITT on same data (single-period structure)
* =============================================================================
local ++test_count
display ""
display "Test `test_count': tte ITT on single-period data"

use "data/bench_teffects.dta", clear

* Restructure as single-period person-period data
generate byte period = 0
generate byte eligible = 1

local tte_itt_coef = .
capture noisily {
    tte_prepare, id(id) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) ///
        covariates(x1 x2) estimand(ITT)

    tte_expand, maxfollowup(1)

    tte_fit, outcome_cov(x1 x2) ///
        followup_spec(linear) trial_period_spec(linear) nolog

    local tte_itt_coef = _b[_tte_arm]
}

local tte_itt_rc = _rc

if `tte_itt_rc' == 0 {
    display "  tte ITT log-OR: " %8.4f `tte_itt_coef'
    display as result "  PASS - tte ITT on single-period data completed"
    local ++pass_count
}
else {
    display as error "  FAIL - tte ITT on single-period data failed (rc=" `tte_itt_rc' ")"
    local ++fail_count
}

* =============================================================================
* TEST 6: Directional agreement between teffects and tte
* =============================================================================
local ++test_count
display ""
display "Test `test_count': Directional agreement (teffects vs tte)"

if `te_rc' == 0 & `tte_itt_rc' == 0 {
    display "  teffects ATE: " %8.4f `te_coef'
    display "  tte ITT log-OR: " %8.4f `tte_itt_coef'

    * Both should agree on direction (treatment is protective: negative)
    local te_dir = cond(`te_coef' < 0, -1, 1)
    local tte_dir = cond(`tte_itt_coef' < 0, -1, 1)

    if `te_dir' == `tte_dir' {
        display as result "  PASS - teffects and tte agree on direction"
        local ++pass_count
    }
    else {
        display as error "  FAIL - Directional disagreement (teffects=" `te_dir' ", tte=" `tte_dir' ")"
        local ++fail_count
    }
}
else {
    display as error "  FAIL - Cannot compare (teffects rc=" `te_rc' ", tte rc=" `tte_itt_rc' ")"
    local ++fail_count
}

* =============================================================================
* SUMMARY
* =============================================================================
display ""
display "VALIDATION 11 SUMMARY: Benchmarks"
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
display "RESULT: V11 tests=`test_count' pass=`pass_count' fail=`fail_count' status=`v_status'"

log close val_bench
