/*******************************************************************************
* validate_expand_options.do
*
* Validation 14: tte_expand Options
* Tests the trials(), save()/replace, and maxfollowup() options that have
* zero test coverage in V1-V12.
*
* DGP: Inline, N=3,000, 10 periods, true log-OR = -0.50.
*
* Tests:
*   1. trials(0 2 4 6 8) selects 5 trials
*   2. trials(0) produces single trial
*   3. Selective trials same direction as full
*   4. save(tempfile.dta) replace creates file
*   5. save() without replace on existing file errors
*   6. maxfollowup(3) produces fewer rows than maxfollowup(0)
*******************************************************************************/

version 16.0
set more off
set varabbrev off

* --- Setup (assumes working directory is tte/qa/) ---
capture ado uninstall tte
adopath ++ ".."
capture log close val_expand
log using "validate_expand_options.log", replace nomsg name(val_expand)
* Test counters
local test_count = 0
local pass_count = 0
local fail_count = 0

display "VALIDATION 14: tte_expand Options"
display "Date: $S_DATE $S_TIME"
display ""

* =============================================================================
* DGP generator
* =============================================================================
capture program drop _dgp_expand
program define _dgp_expand
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
* Generate base dataset
* =============================================================================
display "Generating dataset (N=3,000, 10 periods)..."
_dgp_expand, n(3000) periods(10) effect(-0.50) seed(20260314)

* First run full expansion and fit to get reference coefficient
tte_prepare, id(id) period(period) treatment(treatment) ///
    outcome(outcome) eligible(eligible) ///
    covariates(x) estimand(ITT)

tte_expand, maxfollowup(8)

local full_n_trials = r(n_trials)
local full_n_expanded = r(n_expanded)

tte_fit, outcome_cov(x) ///
    followup_spec(quadratic) trial_period_spec(linear) nolog

local full_coef = _b[_tte_arm]

display "  Full expansion: `full_n_trials' trials, " %12.0fc `full_n_expanded' " rows"
display "  Full ITT coefficient: " %8.4f `full_coef'

* =============================================================================
* TEST 1: trials(0 2 4 6 8) selects 5 trials
* =============================================================================
local ++test_count
display ""
display "Test `test_count': trials(0 2 4 6 8) selects 5 trials"

_dgp_expand, n(3000) periods(10) effect(-0.50) seed(20260314)

tte_prepare, id(id) period(period) treatment(treatment) ///
    outcome(outcome) eligible(eligible) ///
    covariates(x) estimand(ITT)

tte_expand, maxfollowup(8) trials(0 2 4 6 8)

local selective_n_trials = r(n_trials)
local selective_n_expanded = r(n_expanded)

display "  Selective trials: `selective_n_trials'"
display "  Selective rows: " %12.0fc `selective_n_expanded'

if `selective_n_trials' == 5 {
    display as result "  PASS -- trials(0 2 4 6 8) created exactly 5 trials"
    local ++pass_count
}
else {
    display as error "  FAIL -- expected 5 trials but got `selective_n_trials'"
    local ++fail_count
}

* =============================================================================
* TEST 2: trials(0) produces single trial
* =============================================================================
local ++test_count
display ""
display "Test `test_count': trials(0) produces single trial"

_dgp_expand, n(3000) periods(10) effect(-0.50) seed(20260314)

tte_prepare, id(id) period(period) treatment(treatment) ///
    outcome(outcome) eligible(eligible) ///
    covariates(x) estimand(ITT)

tte_expand, maxfollowup(8) trials(0)

local single_n_trials = r(n_trials)

display "  Trials created: `single_n_trials'"

if `single_n_trials' == 1 {
    display as result "  PASS -- trials(0) created exactly 1 trial"
    local ++pass_count
}
else {
    display as error "  FAIL -- expected 1 trial but got `single_n_trials'"
    local ++fail_count
}

* =============================================================================
* TEST 3: Selective trials same direction as full
* =============================================================================
local ++test_count
display ""
display "Test `test_count': Selective trials same direction as full"

_dgp_expand, n(3000) periods(10) effect(-0.50) seed(20260314)

tte_prepare, id(id) period(period) treatment(treatment) ///
    outcome(outcome) eligible(eligible) ///
    covariates(x) estimand(ITT)

tte_expand, maxfollowup(8) trials(0 2 4 6 8)

tte_fit, outcome_cov(x) ///
    followup_spec(quadratic) trial_period_spec(linear) nolog

local selective_coef = _b[_tte_arm]

display "  Full coefficient:      " %8.4f `full_coef'
display "  Selective coefficient: " %8.4f `selective_coef'

if `full_coef' < 0 & `selective_coef' < 0 {
    display as result "  PASS -- both coefficients negative"
    local ++pass_count
}
else {
    display as error "  FAIL -- direction mismatch (full=" %8.4f `full_coef' ///
        ", selective=" %8.4f `selective_coef' ")"
    local ++fail_count
}

* =============================================================================
* TEST 4: save(tempfile.dta) replace creates file
* =============================================================================
local ++test_count
display ""
display "Test `test_count': save() replace creates file with expected variables"

_dgp_expand, n(3000) periods(10) effect(-0.50) seed(20260314)

tte_prepare, id(id) period(period) treatment(treatment) ///
    outcome(outcome) eligible(eligible) ///
    covariates(x) estimand(ITT)

tempfile save_test
tte_expand, maxfollowup(8) save("`save_test'") replace

* Check file exists and has _tte_trial variable
local file_ok = 0
capture {
    confirm file "`save_test'"
    preserve
    use "`save_test'", clear
    confirm variable _tte_trial
    local file_ok = 1
    restore
}

if `file_ok' == 1 {
    display as result "  PASS -- save() created file with _tte_trial variable"
    local ++pass_count
}
else {
    display as error "  FAIL -- save() did not create expected file"
    local ++fail_count
}

* =============================================================================
* TEST 5: save() without replace on existing file errors
* =============================================================================
local ++test_count
display ""
display "Test `test_count': save() without replace on existing file errors"

_dgp_expand, n(3000) periods(10) effect(-0.50) seed(20260314)

tte_prepare, id(id) period(period) treatment(treatment) ///
    outcome(outcome) eligible(eligible) ///
    covariates(x) estimand(ITT)

* File already exists from test 4
capture noisily tte_expand, maxfollowup(8) save("`save_test'")

local save_rc = _rc

display "  Return code: `save_rc'"

if `save_rc' == 602 {
    display as result "  PASS -- save() without replace correctly returned rc=602"
    local ++pass_count
}
else if `save_rc' != 0 {
    * Any error is acceptable — the exact code may vary
    display as result "  PASS -- save() without replace returned error (rc=`save_rc')"
    local ++pass_count
}
else {
    display as error "  FAIL -- save() without replace should have errored"
    local ++fail_count
}

* =============================================================================
* TEST 6: maxfollowup(3) produces fewer rows than maxfollowup(0)
* =============================================================================
local ++test_count
display ""
display "Test `test_count': maxfollowup(3) produces fewer rows than maxfollowup(0)"

_dgp_expand, n(3000) periods(10) effect(-0.50) seed(20260314)

tte_prepare, id(id) period(period) treatment(treatment) ///
    outcome(outcome) eligible(eligible) ///
    covariates(x) estimand(ITT)

tte_expand, maxfollowup(0)
local rows_fu0 = r(n_expanded)

_dgp_expand, n(3000) periods(10) effect(-0.50) seed(20260314)

tte_prepare, id(id) period(period) treatment(treatment) ///
    outcome(outcome) eligible(eligible) ///
    covariates(x) estimand(ITT)

tte_expand, maxfollowup(3)
local rows_fu3 = r(n_expanded)

display "  maxfollowup(0) rows: " %12.0fc `rows_fu0'
display "  maxfollowup(3) rows: " %12.0fc `rows_fu3'

if `rows_fu3' < `rows_fu0' {
    display as result "  PASS -- maxfollowup(3) produces fewer rows than maxfollowup(0)"
    local ++pass_count
}
else {
    display as error "  FAIL -- maxfollowup(3) did not reduce row count"
    local ++fail_count
}

* =============================================================================
* SUMMARY
* =============================================================================
display ""
display "VALIDATION 14 SUMMARY: tte_expand Options"
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
display "RESULT: V14 tests=`test_count' pass=`pass_count' fail=`fail_count' status=`v_status'"

log close val_expand
