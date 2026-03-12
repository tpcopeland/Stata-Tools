/*******************************************************************************
* validate_equivalence.do
*
* Formal TOST (Two One-Sided Tests) equivalence testing
* Tests H0: |tte - reference| >= delta vs H1: |tte - reference| < delta
*
* Test structure:
*   1. tte vs emulate ITT — absolute agreement (same algorithm, same data)
*   2. TOST tte ITT vs true DGP effect (delta = 0.20)
*   3. tte vs emulate PP — absolute agreement (same algorithm, same data)
*   4. TOST tte vs true DGP effect, PP (delta = 0.30)
*   5. Cox/logistic consistency on golden DGP
*
* Alpha = 0.05 (two one-sided z-tests)
*******************************************************************************/

version 16.0
set more off
set varabbrev off

capture ado uninstall tte
adopath ++ ".."
capture log close val_equiv
log using "validate_equivalence.log", replace nomsg name(val_equiv)

local test_count = 0
local pass_count = 0
local fail_count = 0

display "VALIDATION: Formal Equivalence Testing (TOST)"
display "Date: $S_DATE $S_TIME"
display ""

* =============================================================================
* Program: tost_test (corrected p-value directions)
* TOST: H0_lo: diff <= -delta, H0_hi: diff >= delta
*   Reject equivalence when max(p_lo, p_hi) < alpha
* =============================================================================
capture program drop _tost_test
program define _tost_test, rclass
    syntax, est1(real) se1(real) est2(real) se2(real) delta(real) [alpha(real 0.05)]

    local diff = `est1' - `est2'
    local se_diff = sqrt(`se1'^2 + `se2'^2)

    * Lower bound test: H0: diff <= -delta, H1: diff > -delta
    local z_lo = (`diff' + `delta') / `se_diff'
    local p_lo = 1 - normal(`z_lo')

    * Upper bound test: H0: diff >= delta, H1: diff < delta
    local z_hi = (`diff' - `delta') / `se_diff'
    local p_hi = normal(`z_hi')

    * TOST: reject if both one-sided tests reject
    local p_tost = max(`p_lo', `p_hi')

    return scalar diff = `diff'
    return scalar se_diff = `se_diff'
    return scalar p_tost = `p_tost'
    return scalar equivalent = (`p_tost' < `alpha')
end

* =============================================================================
* Load R reference values from three_way_r_results.csv
* =============================================================================
capture confirm file "data/three_way_r_results.csv"
if _rc != 0 {
    display "Generating R results..."
    shell Rscript three_way_r_results.R
}

import delimited using "data/three_way_r_results.csv", clear case(preserve)
local em_itt_coef = coef[1]
local em_itt_se   = se[1]
local em_pp_coef  = coef[2]
local em_pp_se    = se[2]

display "R emulate reference values:"
display "  ITT coef = " %8.4f `em_itt_coef' "  SE = " %8.4f `em_itt_se'
display "  PP  coef = " %8.4f `em_pp_coef'  "  SE = " %8.4f `em_pp_se'
display ""

* =============================================================================
* Run Stata tte — ITT on golden DGP
* =============================================================================
import delimited using "data/known_dgp_golden.csv", clear case(preserve)

tte_prepare, id(id) period(period) treatment(treatment) ///
    outcome(outcome) eligible(eligible) covariates(x) estimand(ITT)
tte_expand, maxfollowup(8)
tte_fit, outcome_cov(x) followup_spec(quadratic) trial_period_spec(quadratic) nolog

local tte_itt_coef = _b[_tte_arm]
local tte_itt_se   = _se[_tte_arm]

* =============================================================================
* TEST 1: Absolute agreement — tte vs emulate ITT
* Same algorithm on same data: difference should be < 0.005 (floating point)
* =============================================================================
local ++test_count
local diff1 = abs(`tte_itt_coef' - `em_itt_coef')

display "Test `test_count': tte vs emulate ITT (absolute agreement)"
display "  tte = " %10.6f `tte_itt_coef' "  emulate = " %10.6f `em_itt_coef'
display "  |diff| = " %10.6f `diff1'

if `diff1' < 0.005 {
    display as result "  PASS — absolute difference < 0.005"
    local ++pass_count
}
else {
    display as error "  FAIL — difference = " %8.6f `diff1' " >= 0.005"
    local ++fail_count
}

* =============================================================================
* TEST 2: TOST — tte ITT vs true DGP effect (delta = 0.20)
* The tte estimate should be within 0.20 of the true log-OR = -0.50
* =============================================================================
local ++test_count
local true_effect = -0.50

_tost_test, est1(`tte_itt_coef') se1(`tte_itt_se') ///
    est2(`true_effect') se2(0) delta(0.20)

display ""
display "Test `test_count': TOST tte ITT vs true effect (-0.50)"
display "  diff = " %8.4f r(diff) "  SE = " %8.4f r(se_diff) ///
    "  p_tost = " %6.4f r(p_tost) "  delta = 0.20"
if r(equivalent) == 1 {
    display as result "  PASS — formally equivalent to true effect"
    local ++pass_count
}
else {
    display as error "  FAIL — not equivalent at delta=0.20"
    local ++fail_count
}

* =============================================================================
* TEST 3: Absolute agreement — tte vs emulate PP
* =============================================================================
local ++test_count

import delimited using "data/known_dgp_golden.csv", clear case(preserve)

tte_prepare, id(id) period(period) treatment(treatment) ///
    outcome(outcome) eligible(eligible) covariates(x) estimand(PP)
tte_expand, maxfollowup(8)
tte_weight, switch_d_cov(x) truncate(1 99) nolog
tte_fit, outcome_cov(x) followup_spec(quadratic) trial_period_spec(quadratic) nolog

local tte_pp_coef = _b[_tte_arm]
local tte_pp_se   = _se[_tte_arm]

local diff3 = abs(`tte_pp_coef' - `em_pp_coef')

display ""
display "Test `test_count': tte vs emulate PP (absolute agreement)"
display "  tte = " %10.6f `tte_pp_coef' "  emulate = " %10.6f `em_pp_coef'
display "  |diff| = " %10.6f `diff3'

if `diff3' < 0.02 {
    display as result "  PASS — absolute difference < 0.02"
    local ++pass_count
}
else {
    display as error "  FAIL — difference = " %8.6f `diff3' " >= 0.02"
    local ++fail_count
}

* =============================================================================
* TEST 4: TOST — tte PP vs true DGP effect (delta = 0.30)
* PP has more variance than ITT, so wider margin
* =============================================================================
local ++test_count

_tost_test, est1(`tte_pp_coef') se1(`tte_pp_se') ///
    est2(`true_effect') se2(0) delta(0.30)

display ""
display "Test `test_count': TOST tte PP vs true effect (-0.50)"
display "  diff = " %8.4f r(diff) "  SE = " %8.4f r(se_diff) ///
    "  p_tost = " %6.4f r(p_tost) "  delta = 0.30"
if r(equivalent) == 1 {
    display as result "  PASS — PP formally equivalent to true effect"
    local ++pass_count
}
else {
    display as error "  FAIL — PP not equivalent at delta=0.30"
    local ++fail_count
}

* =============================================================================
* TEST 5: Cox and logistic consistency on golden DGP
* Both should recover the true protective effect on the same dataset
* =============================================================================
local ++test_count

import delimited using "data/known_dgp_golden.csv", clear case(preserve)

tte_prepare, id(id) period(period) treatment(treatment) ///
    outcome(outcome) eligible(eligible) covariates(x) estimand(ITT)
tte_expand, maxfollowup(8)
tte_fit, outcome_cov(x) model(cox) trial_period_spec(linear) nolog

local tte_cox_coef = _b[_tte_arm]

display ""
display "Test `test_count': Cox/logistic consistency on golden DGP"
display "  Logistic coef = " %8.4f `tte_itt_coef'
display "  Cox coef      = " %8.4f `tte_cox_coef'

local cox_diff = abs(`tte_cox_coef' - `tte_itt_coef')
local same_dir = (sign(`tte_cox_coef') == sign(`tte_itt_coef'))

if `same_dir' & `cox_diff' < 0.20 {
    display as result "  PASS — same direction, |diff| = " %6.4f `cox_diff' " < 0.20"
    local ++pass_count
}
else {
    display as error "  FAIL — inconsistent (diff=" %6.4f `cox_diff' " same_dir=" `same_dir' ")"
    local ++fail_count
}

* =============================================================================
* SUMMARY
* =============================================================================
display ""
display "EQUIVALENCE TESTING SUMMARY"
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
display "RESULT: V_EQUIV tests=`test_count' pass=`pass_count' fail=`fail_count' status=`v_status'"

log close val_equiv
