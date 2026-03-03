/*******************************************************************************
* validate_ipcw.do
*
* IPCW (inverse probability of censoring weighting) validation.
* Tests that informative censoring is properly handled by censoring weights,
* comparing weighted vs unweighted estimates and pooled vs stratified models.
*******************************************************************************/

version 16.0
set more off
set varabbrev off

* --- Setup (assumes working directory is tte/qa/) ---
capture ado uninstall tte
adopath ++ ".."
capture log close val_ipcw
log using "validate_ipcw.log", replace nomsg name(val_ipcw)
* Test counters
local test_count = 0
local pass_count = 0
local fail_count = 0

display "VALIDATION 7: IPCW / Informative Censoring"
display "Date: $S_DATE $S_TIME"
display ""

local true_effect = -0.60

* =============================================================================
* DGP: Informative censoring
* =============================================================================
capture program drop _dgp_ipcw
program define _dgp_ipcw
    syntax, n(integer) periods(integer) effect(real) seed(integer)

    clear
    set seed `seed'
    quietly set obs `n'

    generate id = _n
    generate byte x = rbinomial(1, 0.4)
    generate double z = rnormal(0, 1)

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
                & rbinomial(1, invlogit(-2 + 0.3*x + 0.2*z)) == 1
        }
        else {
            quietly replace treatment = rbinomial(1, invlogit(-2 + 0.3*x + 0.2*z)) ///
                if period == 0
        }

        * Informative censoring: sicker patients more likely censored
        quietly replace censored = rbinomial(1, invlogit(-3 + 0.5*x + 0.4*z)) ///
            if period == `t' & censored == 0 & outcome == 0

        * Eligibility: not yet treated, not yet censored, not yet had outcome
        if `t' == 0 {
            replace eligible = 1 if period == 0
        }
        else {
            bysort id (period): replace eligible = ///
                (treatment[_n-1] == 0 & outcome[_n-1] == 0 & censored[_n-1] == 0) ///
                if period == `t'
        }

        * Outcome
        quietly replace outcome = rbinomial(1, ///
            invlogit(-3.5 + 0.3*x + 0.2*z + `effect'*treatment)) ///
            if period == `t' & outcome == 0 & censored == 0

        * Absorbing outcome
        if `t' > 0 {
            bysort id (period): replace outcome = 1 ///
                if period == `t' & outcome[_n-1] == 1
        }

        * Absorbing censoring
        if `t' > 0 {
            bysort id (period): replace censored = 1 ///
                if period == `t' & censored[_n-1] == 1
        }
    }

    * Remove person-periods after first outcome or first censoring
    bysort id (period): generate byte _first_out = (outcome == 1 & ///
        (period == 0 | outcome[_n-1] == 0))
    bysort id (period): generate byte _cum_out = sum(_first_out)
    drop if _cum_out > 1

    bysort id (period): generate byte _first_cens = (censored == 1 & ///
        (period == 0 | censored[_n-1] == 0))
    bysort id (period): generate byte _cum_cens = sum(_first_cens)
    drop if _cum_cens > 1

    drop _first_out _cum_out _first_cens _cum_cens
end

* =============================================================================
* Generate dataset and save
* =============================================================================
display "Generating IPCW validation dataset..."
_dgp_ipcw, n(5000) periods(10) effect(`true_effect') seed(70001)

quietly count
display "  Person-periods: " %10.0fc r(N)
quietly count if outcome == 1
display "  Events: " r(N)
quietly count if censored == 1
display "  Censored: " r(N)

save "data/ipcw_dgp.dta", replace

* =============================================================================
* TEST 1: PP without IPCW (switch weights only)
* =============================================================================
local ++test_count
display ""
display "Test `test_count': PP without IPCW (switch weights only)"

use "data/ipcw_dgp.dta", clear

tte_prepare, id(id) period(period) treatment(treatment) ///
    outcome(outcome) eligible(eligible) ///
    censor(censored) covariates(x z) estimand(PP)

tte_expand, maxfollowup(8)

tte_weight, switch_d_cov(x z) stabilized truncate(1 99) nolog

tte_fit, outcome_cov(x z) ///
    followup_spec(quadratic) trial_period_spec(linear) nolog

local no_ipcw_coef = _b[_tte_arm]
local no_ipcw_se   = _se[_tte_arm]

display "  PP (no IPCW) coefficient: " %8.4f `no_ipcw_coef'
display "  True effect:              " %8.4f `true_effect'

if `no_ipcw_coef' < 0 {
    display as result "  PASS -- PP (no IPCW) coefficient is negative"
    local ++pass_count
}
else {
    display as error "  FAIL -- PP (no IPCW) coefficient is not negative"
    local ++fail_count
}

* =============================================================================
* TEST 2: PP with IPCW
* =============================================================================
local ++test_count
display ""
display "Test `test_count': PP with IPCW (switch + censor weights)"

use "data/ipcw_dgp.dta", clear

tte_prepare, id(id) period(period) treatment(treatment) ///
    outcome(outcome) eligible(eligible) ///
    censor(censored) covariates(x z) estimand(PP)

tte_expand, maxfollowup(8)

tte_weight, switch_d_cov(x z) censor_d_cov(x z) censor_n_cov(x) ///
    stabilized truncate(1 99) nolog

tte_fit, outcome_cov(x z) ///
    followup_spec(quadratic) trial_period_spec(linear) nolog

local ipcw_coef = _b[_tte_arm]
local ipcw_se   = _se[_tte_arm]

display "  PP (with IPCW) coefficient: " %8.4f `ipcw_coef'
display "  True effect:                " %8.4f `true_effect'

if `ipcw_coef' < 0 {
    display as result "  PASS -- PP (with IPCW) coefficient is negative"
    local ++pass_count
}
else {
    display as error "  FAIL -- PP (with IPCW) coefficient is not negative"
    local ++fail_count
}

* =============================================================================
* TEST 3: IPCW moves estimate toward truth (or both close)
* =============================================================================
local ++test_count
display ""
display "Test `test_count': IPCW moves estimate toward truth (with tolerance)"

local dist_no_ipcw = abs(`no_ipcw_coef' - `true_effect')
local dist_ipcw    = abs(`ipcw_coef' - `true_effect')

display "  Distance without IPCW: " %8.4f `dist_no_ipcw'
display "  Distance with IPCW:    " %8.4f `dist_ipcw'

* IPCW should be closer to truth, or within 0.2 tolerance
if `dist_ipcw' <= `dist_no_ipcw' + 0.2 {
    display as result "  PASS -- IPCW estimate at least as close to truth (within tolerance)"
    local ++pass_count
}
else {
    display as error "  FAIL -- IPCW estimate substantially farther from truth"
    local ++fail_count
}

* =============================================================================
* TEST 4: IPCW weights non-degenerate
* =============================================================================
local ++test_count
display ""
display "Test `test_count': IPCW weights non-degenerate"

quietly summarize _tte_weight
local w_mean = r(mean)
local w_min  = r(min)
local w_max  = r(max)

display "  Weight mean: " %8.4f `w_mean'
display "  Weight min:  " %8.4f `w_min'
display "  Weight max:  " %8.4f `w_max'

if `w_mean' >= 0.5 & `w_mean' <= 2.0 {
    display as result "  PASS -- mean weight between 0.5 and 2.0"
    local ++pass_count
}
else {
    display as error "  FAIL -- mean weight outside [0.5, 2.0] range"
    local ++fail_count
}

* =============================================================================
* TEST 5: Pooled censor model runs and gives negative coefficient
* =============================================================================
local ++test_count
display ""
display "Test `test_count': Pooled censor model"

use "data/ipcw_dgp.dta", clear

tte_prepare, id(id) period(period) treatment(treatment) ///
    outcome(outcome) eligible(eligible) ///
    censor(censored) covariates(x z) estimand(PP)

tte_expand, maxfollowup(8)

tte_weight, switch_d_cov(x z) censor_d_cov(x z) pool_censor ///
    stabilized truncate(1 99) nolog

tte_fit, outcome_cov(x z) ///
    followup_spec(quadratic) trial_period_spec(linear) nolog

local pooled_coef = _b[_tte_arm]

display "  Pooled censor coefficient: " %8.4f `pooled_coef'

if `pooled_coef' < 0 {
    display as result "  PASS -- pooled censor model coefficient is negative"
    local ++pass_count
}
else {
    display as error "  FAIL -- pooled censor model coefficient is not negative"
    local ++fail_count
}

* =============================================================================
* TEST 6: Stratified vs pooled censor — same direction, close magnitude
* =============================================================================
local ++test_count
display ""
display "Test `test_count': Stratified vs pooled censor comparison"

display "  Stratified (IPCW) coefficient: " %8.4f `ipcw_coef'
display "  Pooled censor coefficient:     " %8.4f `pooled_coef'

local same_direction = (`ipcw_coef' < 0 & `pooled_coef' < 0)
local magnitude_diff = abs(`ipcw_coef' - `pooled_coef')

display "  Same direction: " cond(`same_direction', "Yes", "No")
display "  Magnitude difference: " %8.4f `magnitude_diff'

if `same_direction' & `magnitude_diff' < 1.0 {
    display as result "  PASS -- stratified and pooled censor in same direction, close magnitude"
    local ++pass_count
}
else {
    display as error "  FAIL -- stratified and pooled censor differ too much"
    local ++fail_count
}

* =============================================================================
* SUMMARY
* =============================================================================
display ""
display "VALIDATION 7 SUMMARY: IPCW / Informative Censoring"
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
display "RESULT: V7 tests=`test_count' pass=`pass_count' fail=`fail_count' status=`v_status'"

log close val_ipcw
