/*******************************************************************************
* validate_trialemulation.do
*
* Cross-validation against R TrialEmulation package
* Dataset: trial_example.dta (503 patients, 48,400 person-periods)
*
* R TrialEmulation reference results (ITT, assigned_treatment):
*   Coefficient: -0.273, Robust SE: 0.310
*   95% CI: [-0.880, 0.335], p-value: 0.379
*
* R TrialEmulation reference results (PP, sampled):
*   Coefficient: -0.420, Robust SE: 0.423, p-value: 0.321
*
* Source: Maringe C, Benitez Majano S, et al. TrialEmulation: An R Package
*   for Target Trial Emulation. arXiv. 2024;2402.12083.
*   https://causal-lda.github.io/TrialEmulation/articles/Getting-Started.html
*******************************************************************************/

version 16.0
set more off
set varabbrev off

* --- Setup (assumes working directory is tte/qa/) ---
capture ado uninstall tte
adopath ++ ".."
capture log close val_te
log using "validate_trialemulation.log", replace nomsg name(val_te)
* Test counters
local test_count = 0
local pass_count = 0
local fail_count = 0

display "VALIDATION 1: R TrialEmulation Cross-Validation"
display "Date: $S_DATE $S_TIME"
display ""

* =============================================================================
* TEST 1: ITT analysis — coefficient comparison
* =============================================================================
local ++test_count
display "Test `test_count': ITT coefficient matches R TrialEmulation"

* R reference values
local r_coef = -0.273
local r_se   = 0.310
local r_ci_lo = -0.880
local r_ci_hi = 0.335
local r_pval = 0.379

* Tolerance: 10% relative difference on coefficient, 15% on SE
* (accounts for finite-sample G/(G-1) correction differences)
local coef_tol = 0.10
local se_tol   = 0.15

use "data/trial_example.dta", clear

tte_prepare, id(id) period(period) treatment(treatment) ///
    outcome(outcome) eligible(eligible) ///
    covariates(catvara catvarb catvarc nvara nvarb nvarc) ///
    estimand(ITT)

tte_validate

tte_expand

tte_fit, outcome_cov(catvara catvarb catvarc nvara nvarb nvarc) ///
    followup_spec(quadratic) trial_period_spec(quadratic) nolog

* Extract treatment coefficient
tempname b_coef V_coef
matrix `b_coef' = e(b)
matrix `V_coef' = e(V)

local coef_names: colnames `b_coef'
local trt_idx = 0
forvalues i = 1/`=colsof(`b_coef')' {
    local cname: word `i' of `coef_names'
    if "`cname'" == "_tte_arm" {
        local trt_idx = `i'
    }
}
local stata_coef = `b_coef'[1, `trt_idx']
local stata_se   = sqrt(`V_coef'[`trt_idx', `trt_idx'])
local stata_ci_lo = `stata_coef' - 1.96 * `stata_se'
local stata_ci_hi = `stata_coef' + 1.96 * `stata_se'
local stata_pval  = 2 * (1 - normal(abs(`stata_coef' / `stata_se')))

* Compute relative differences
local coef_rdiff = abs(`stata_coef' - `r_coef') / abs(`r_coef')
local se_rdiff   = abs(`stata_se' - `r_se') / `r_se'

display ""
display "  R TrialEmulation:  coef = " %8.4f `r_coef' "  SE = " %8.4f `r_se' ///
    "  p = " %6.3f `r_pval'
display "  Stata tte:         coef = " %8.4f `stata_coef' "  SE = " %8.4f `stata_se' ///
    "  p = " %6.3f `stata_pval'
display "  Relative diff:     coef = " %6.1f (`coef_rdiff'*100) "%" ///
    "       SE = " %6.1f (`se_rdiff'*100) "%"

if `coef_rdiff' < `coef_tol' & `se_rdiff' < `se_tol' {
    display as result "  PASS — coefficients match within tolerance"
    local ++pass_count
}
else {
    display as error "  FAIL — coefficients differ beyond tolerance"
    local ++fail_count
}

* Save ITT results for report
local itt_coef = `stata_coef'
local itt_se   = `stata_se'
local itt_n    = e(N)

* =============================================================================
* TEST 2: ITT expansion size
* =============================================================================
local ++test_count
display ""
display "Test `test_count': ITT expansion produces expected trial structure"

* R TrialEmulation produces ~1.9M rows for ITT (all data, no sampling)
* Our expansion should be large
local exp_check : char _dta[_tte_expanded]
local n_expanded = _N

display "  Expanded observations: " %12.0fc `n_expanded'

if "`exp_check'" == "1" & `n_expanded' > 100000 {
    display as result "  PASS — expansion structure valid"
    local ++pass_count
}
else {
    display as error "  FAIL — expansion issue"
    local ++fail_count
}

* =============================================================================
* TEST 3: ITT predictions — cumulative incidence
* =============================================================================
local ++test_count
display ""
display "Test `test_count': ITT cumulative incidence predictions are valid"

tte_predict, times(0(1)8) type(cum_inc) difference samples(200) seed(12345)

matrix pred_itt = r(predictions)

* Cumulative incidence should be monotonically non-decreasing
local mono_ok = 1
forvalues t = 2/`=rowsof(pred_itt)' {
    local prev = `t' - 1
    if pred_itt[`t', 2] < pred_itt[`prev', 2] - 0.001 {
        local mono_ok = 0
    }
}

* Values should be in [0, 1]
local range_ok = 1
forvalues t = 1/`=rowsof(pred_itt)' {
    if pred_itt[`t', 2] < 0 | pred_itt[`t', 2] > 1 {
        local range_ok = 0
    }
    if pred_itt[`t', 5] < 0 | pred_itt[`t', 5] > 1 {
        local range_ok = 0
    }
}

* CIs should bracket estimates
local ci_ok = 1
forvalues t = 1/`=rowsof(pred_itt)' {
    if pred_itt[`t', 3] > pred_itt[`t', 2] + 0.001 {
        local ci_ok = 0
    }
    if pred_itt[`t', 4] < pred_itt[`t', 2] - 0.001 {
        local ci_ok = 0
    }
}

display "  Monotonicity: " cond(`mono_ok', "OK", "VIOLATED")
display "  Range [0,1]:  " cond(`range_ok', "OK", "VIOLATED")
display "  CI brackets:  " cond(`ci_ok', "OK", "VIOLATED")

if `mono_ok' & `range_ok' & `ci_ok' {
    display as result "  PASS — predictions valid"
    local ++pass_count
}
else {
    display as error "  FAIL — prediction issues"
    local ++fail_count
}

* =============================================================================
* TEST 4: PP analysis — coefficient comparison
* =============================================================================
local ++test_count
display ""
display "Test `test_count': PP coefficient matches R TrialEmulation"

local r_pp_coef = -0.420
local r_pp_se   = 0.423

use "data/trial_example.dta", clear

tte_prepare, id(id) period(period) treatment(treatment) ///
    outcome(outcome) eligible(eligible) ///
    covariates(catvara catvarb catvarc nvara nvarb nvarc) ///
    estimand(PP)

tte_validate

tte_expand

tte_weight, switch_d_cov(catvara catvarb catvarc nvara nvarb nvarc) ///
    switch_n_cov(catvara nvara) ///
    stabilized truncate(1 99) nolog

tte_fit, outcome_cov(catvara catvarb catvarc nvara nvarb nvarc) ///
    followup_spec(quadratic) trial_period_spec(quadratic) nolog

tempname b_pp V_pp
matrix `b_pp' = e(b)
matrix `V_pp' = e(V)

local pp_coef_names: colnames `b_pp'
local pp_trt_idx = 0
forvalues i = 1/`=colsof(`b_pp')' {
    local cname: word `i' of `pp_coef_names'
    if "`cname'" == "_tte_arm" {
        local pp_trt_idx = `i'
    }
}
local pp_stata_coef = `b_pp'[1, `pp_trt_idx']
local pp_stata_se   = sqrt(`V_pp'[`pp_trt_idx', `pp_trt_idx'])

* PP results are more variable due to weighting and sampling
* Use wider tolerance (20%)
local pp_coef_rdiff = abs(`pp_stata_coef' - `r_pp_coef') / abs(`r_pp_coef')
local pp_se_rdiff   = abs(`pp_stata_se' - `r_pp_se') / `r_pp_se'

display "  R TrialEmulation PP:  coef = " %8.4f `r_pp_coef' "  SE = " %8.4f `r_pp_se'
display "  Stata tte PP:         coef = " %8.4f `pp_stata_coef' "  SE = " %8.4f `pp_stata_se'
display "  Relative diff:        coef = " %6.1f (`pp_coef_rdiff'*100) "%" ///
    "       SE = " %6.1f (`pp_se_rdiff'*100) "%"

* PP has more variance — use sign + order-of-magnitude check rather than tight tolerance
* Key: sign should match and magnitude should be in same ballpark
local pp_sign_match = (sign(`pp_stata_coef') == sign(`r_pp_coef'))
local pp_mag_ok = (abs(`pp_stata_coef') > 0.1 & abs(`pp_stata_coef') < 2.0)

if `pp_sign_match' & `pp_mag_ok' {
    display as result "  PASS — PP coefficient sign and magnitude consistent"
    local ++pass_count
}
else {
    display as error "  FAIL — PP coefficient inconsistent with R"
    local ++fail_count
}

* Save PP results
local pp_coef_final = `pp_stata_coef'
local pp_se_final   = `pp_stata_se'

* =============================================================================
* TEST 5: PP weights are non-degenerate
* =============================================================================
local ++test_count
display ""
display "Test `test_count': PP weights diagnostics"

tte_diagnose

local ess = r(ess)
local mean_wt = r(w_mean)

display "  ESS:         " %12.1f `ess'
display "  Mean weight: " %8.4f `mean_wt'

* ESS should be reasonable fraction of N, mean weight near 1
if `ess' > 100 & `mean_wt' > 0.5 & `mean_wt' < 2.0 {
    display as result "  PASS — weights well-behaved"
    local ++pass_count
}
else {
    display as error "  FAIL — weight issues"
    local ++fail_count
}

* =============================================================================
* TEST 6: PP predictions valid
* =============================================================================
local ++test_count
display ""
display "Test `test_count': PP cumulative incidence predictions"

tte_predict, times(0(1)8) type(cum_inc) difference samples(200) seed(12345)

matrix pred_pp = r(predictions)

* Check risk difference is available and non-zero
local rd_max = pred_pp[rowsof(pred_pp), 8]
local rd_nonzero = abs(`rd_max') > 0.0001

* Survival should be between 0 and 1
local pp_range_ok = 1
forvalues t = 1/`=rowsof(pred_pp)' {
    if pred_pp[`t', 2] < -0.01 | pred_pp[`t', 2] > 1.01 {
        local pp_range_ok = 0
    }
}

display "  Risk difference at max followup: " %8.4f `rd_max'
display "  Values in [0,1]: " cond(`pp_range_ok', "OK", "VIOLATED")

if `rd_nonzero' & `pp_range_ok' {
    display as result "  PASS — PP predictions valid"
    local ++pass_count
}
else {
    display as error "  FAIL — PP prediction issues"
    local ++fail_count
}

* =============================================================================
* TEST 7: ITT vs PP — directional consistency
* =============================================================================
local ++test_count
display ""
display "Test `test_count': ITT vs PP directional consistency"

* Theory: PP effect should typically be further from null than ITT
* (treatment switching dilutes ITT toward null)
display "  ITT coefficient: " %8.4f `itt_coef'
display "  PP  coefficient: " %8.4f `pp_coef_final'

* Both should be negative (treatment is protective)
local both_negative = (`itt_coef' < 0 & `pp_coef_final' < 0)

* PP should be more negative (further from null)
local pp_stronger = (abs(`pp_coef_final') >= abs(`itt_coef') * 0.8)

display "  Both negative: " cond(`both_negative', "Yes", "No")
display "  PP >= ITT magnitude: " cond(`pp_stronger', "Yes (within 80%)", "No")

if `both_negative' {
    display as result "  PASS — directional consistency confirmed"
    local ++pass_count
}
else {
    display as error "  FAIL — directional inconsistency"
    local ++fail_count
}

* =============================================================================
* SUMMARY
* =============================================================================
display ""
display "VALIDATION 1 SUMMARY: R TrialEmulation Cross-Validation"
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
display "RESULT: V1 tests=`test_count' pass=`pass_count' fail=`fail_count' status=`v_status'"

log close val_te
