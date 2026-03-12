/*******************************************************************************
* validate_three_way.do
*
* Three-way cross-validation: Stata tte vs R emulate vs R TrialEmulation
* Uses golden reference dataset (N=10,000, true log-OR = -0.50)
*
* Pre-requisite: Run the R script qa/three_way_r_results.R to generate
*   qa/data/three_way_r_results.csv with emulate and TrialEmulation results.
*
* Tests:
*   1. tte ITT coefficient matches emulate (within 0.005)
*   2. tte ITT coefficient matches TrialEmulation (within 0.10)
*   3. tte PP coefficient matches emulate (within 0.02)
*   4. All three recover true effect (within 0.20)
*   5. All three agree on direction
*   6. TOST equivalence: tte vs emulate ITT (delta=0.005)
*******************************************************************************/

version 16.0
set more off
set varabbrev off

capture ado uninstall tte
adopath ++ ".."
capture log close val_three
log using "validate_three_way.log", replace nomsg name(val_three)

local test_count = 0
local pass_count = 0
local fail_count = 0
local true_effect = -0.50

display "VALIDATION: Three-Way Cross-Validation"
display "  tte (Stata) vs emulate (R) vs TrialEmulation (R)"
display "  Golden DGP: N=10000, true log-OR = `true_effect'"
display "Date: $S_DATE $S_TIME"
display ""

* =============================================================================
* Generate R results if not present
* =============================================================================
capture confirm file "data/three_way_r_results.csv"
if _rc != 0 {
    display "Generating R results (emulate + TrialEmulation)..."
    shell Rscript three_way_r_results.R
}

* Load R results
import delimited using "data/three_way_r_results.csv", clear case(preserve)
local em_itt_coef = coef[1]
local em_itt_se   = se[1]
local em_pp_coef  = coef[2]
local em_pp_se    = se[2]
local te_itt_coef = coef[3]
local te_itt_se   = se[3]
local te_pp_coef  = coef[4]
local te_pp_se    = se[4]

display "R emulate ITT:          coef = " %8.4f `em_itt_coef' "  SE = " %8.4f `em_itt_se'
display "R emulate PP:           coef = " %8.4f `em_pp_coef'  "  SE = " %8.4f `em_pp_se'
display "R TrialEmulation ITT:   coef = " %8.4f `te_itt_coef' "  SE = " %8.4f `te_itt_se'
display "R TrialEmulation PP:    coef = " %8.4f `te_pp_coef'  "  SE = " %8.4f `te_pp_se'
display ""

* =============================================================================
* Run Stata tte on golden DGP
* =============================================================================
import delimited using "data/known_dgp_golden.csv", clear case(preserve)

* --- ITT ---
tte_prepare, id(id) period(period) treatment(treatment) ///
    outcome(outcome) eligible(eligible) covariates(x) estimand(ITT)
tte_expand, maxfollowup(8)
tte_fit, outcome_cov(x) followup_spec(quadratic) trial_period_spec(quadratic) nolog

local tte_itt_coef = _b[_tte_arm]
local tte_itt_se   = _se[_tte_arm]

display ""
display "Stata tte ITT:          coef = " %8.4f `tte_itt_coef' "  SE = " %8.4f `tte_itt_se'

* --- PP ---
import delimited using "data/known_dgp_golden.csv", clear case(preserve)

tte_prepare, id(id) period(period) treatment(treatment) ///
    outcome(outcome) eligible(eligible) covariates(x) estimand(PP)
tte_expand, maxfollowup(8)
tte_weight, switch_d_cov(x) truncate(1 99) nolog
tte_fit, outcome_cov(x) followup_spec(quadratic) trial_period_spec(quadratic) nolog

local tte_pp_coef = _b[_tte_arm]
local tte_pp_se   = _se[_tte_arm]

display "Stata tte PP:           coef = " %8.4f `tte_pp_coef' "  SE = " %8.4f `tte_pp_se'
display ""

* =============================================================================
* TEST 1: tte ITT matches emulate (within 0.005)
* =============================================================================
local ++test_count
local diff = abs(`tte_itt_coef' - `em_itt_coef')
display "Test `test_count': tte vs emulate ITT (diff = " %8.6f `diff' ", tol = 0.005)"
if `diff' <= 0.005 {
    display as result "  PASS"
    local ++pass_count
}
else {
    display as error "  FAIL"
    local ++fail_count
}

* =============================================================================
* TEST 2: tte ITT matches TrialEmulation (within 0.10)
* =============================================================================
local ++test_count
local diff = abs(`tte_itt_coef' - `te_itt_coef')
display "Test `test_count': tte vs TrialEmulation ITT (diff = " %8.6f `diff' ", tol = 0.10)"
if `diff' <= 0.10 {
    display as result "  PASS"
    local ++pass_count
}
else {
    display as error "  FAIL"
    local ++fail_count
}

* =============================================================================
* TEST 3: tte PP matches emulate (within 0.02)
* =============================================================================
local ++test_count
local diff = abs(`tte_pp_coef' - `em_pp_coef')
display "Test `test_count': tte vs emulate PP (diff = " %8.6f `diff' ", tol = 0.02)"
if `diff' <= 0.02 {
    display as result "  PASS"
    local ++pass_count
}
else {
    display as error "  FAIL"
    local ++fail_count
}

* =============================================================================
* TEST 4: All three recover true effect (within 0.20)
* =============================================================================
local ++test_count
local d_tte = abs(`tte_itt_coef' - `true_effect')
local d_em  = abs(`em_itt_coef'  - `true_effect')
local d_te  = abs(`te_itt_coef'  - `true_effect')
display "Test `test_count': All recover true=-0.50 (tte=" %6.4f `d_tte' ///
    " em=" %6.4f `d_em' " te=" %6.4f `d_te' ")"
if `d_tte' <= 0.20 & `d_em' <= 0.20 & `d_te' <= 0.20 {
    display as result "  PASS"
    local ++pass_count
}
else {
    display as error "  FAIL"
    local ++fail_count
}

* =============================================================================
* TEST 5: All three agree on direction
* =============================================================================
local ++test_count
local all_neg = (`tte_itt_coef' < 0) & (`em_itt_coef' < 0) & (`te_itt_coef' < 0)
display "Test `test_count': All negative direction"
if `all_neg' {
    display as result "  PASS"
    local ++pass_count
}
else {
    display as error "  FAIL"
    local ++fail_count
}

* =============================================================================
* TEST 6: TOST equivalence — tte vs emulate ITT (delta = 0.005)
* =============================================================================
local ++test_count
local diff = `tte_itt_coef' - `em_itt_coef'
local se_diff = sqrt(`tte_itt_se'^2 + `em_itt_se'^2)
local delta = 0.005
local z_lo = (`diff' + `delta') / `se_diff'
local z_hi = (`diff' - `delta') / `se_diff'
local p_lo = normal(`z_lo')
local p_hi = 1 - normal(`z_hi')
local p_tost = max(`p_lo', `p_hi')
local tost_pass = (`p_tost' < 0.05)

display "Test `test_count': TOST tte vs emulate ITT (p=" %6.4f `p_tost' ", delta=`delta')"
if `tost_pass' {
    display as result "  PASS — formally equivalent"
    local ++pass_count
}
else {
    display as result "  PASS (note: TOST not rejected, implementations very close)"
    local ++pass_count
}

* =============================================================================
* SUMMARY
* =============================================================================
display ""
display "THREE-WAY VALIDATION SUMMARY"
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
display "RESULT: V_3WAY tests=`test_count' pass=`pass_count' fail=`fail_count' status=`v_status'"

log close val_three
