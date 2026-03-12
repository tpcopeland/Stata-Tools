/*******************************************************************************
* validate_predict_options.do
*
* Validation 15: tte_predict Options
* Tests type(survival), difference values, seed() reproducibility, and level()
* — none of which are validated in V1-V12.
*
* Uses data/known_dgp.dta (true log-OR = -0.50).
*
* Tests:
*   1. type(survival) values valid — all in [0, 1]
*   2. survival + cum_inc are complementary — sum ~1.0
*   3. difference stores r(rd_T) scalars
*   4. Risk difference sign correct — r(rd_T) < 0
*   5. seed() reproducibility — identical predictions with same seed
*   6. level(90) narrower CIs than level(99)
*   7. samples(10) minimum runs
*******************************************************************************/

version 16.0
set more off
set varabbrev off

* --- Setup (assumes working directory is tte/qa/) ---
capture ado uninstall tte
adopath ++ ".."
capture log close val_pred
log using "validate_predict_options.log", replace nomsg name(val_pred)
* Test counters
local test_count = 0
local pass_count = 0
local fail_count = 0

display "VALIDATION 15: tte_predict Options"
display "Date: $S_DATE $S_TIME"
display ""

* =============================================================================
* Setup: Run full ITT pipeline on known_dgp data
* =============================================================================
display "Setting up ITT pipeline on known_dgp data..."

use "data/known_dgp.dta", clear

tte_prepare, id(id) period(period) treatment(treatment) ///
    outcome(outcome) eligible(eligible) ///
    covariates(x) estimand(ITT)

tte_expand, maxfollowup(8)

tte_fit, outcome_cov(x) ///
    followup_spec(quadratic) trial_period_spec(linear) nolog

local itt_coef = _b[_tte_arm]
display "  ITT coefficient: " %8.4f `itt_coef'
display ""

* =============================================================================
* TEST 1: type(survival) values valid
* =============================================================================
local ++test_count
display ""
display "Test `test_count': type(survival) values in [0, 1]"

tte_predict, times(0(1)8) type(survival) samples(50) seed(42)

matrix surv_mat = r(predictions)
local surv_rows = rowsof(surv_mat)
local surv_cols = colsof(surv_mat)

local all_valid = 1
forvalues i = 1/`surv_rows' {
    forvalues j = 2/`surv_cols' {
        local val = surv_mat[`i', `j']
        if `val' < 0 | `val' > 1 {
            local all_valid = 0
        }
    }
}

display "  Survival matrix: `surv_rows' rows x `surv_cols' cols"
display "  All values in [0,1]: " cond(`all_valid', "Yes", "No")

if `all_valid' == 1 {
    display as result "  PASS -- all survival estimates in [0, 1]"
    local ++pass_count
}
else {
    display as error "  FAIL -- survival estimates outside [0, 1]"
    local ++fail_count
}

* =============================================================================
* TEST 2: survival + cum_inc are complementary
* =============================================================================
local ++test_count
display ""
display "Test `test_count': survival + cum_inc complementary (sum ~1.0)"

tte_predict, times(0(1)8) type(cum_inc) samples(50) seed(42)

matrix ci_mat = r(predictions)

* Compare point estimates: surv_mat col 2 (arm0 est) + ci_mat col 2 should ~ 1
local all_complementary = 1
forvalues i = 1/`surv_rows' {
    local surv_0 = surv_mat[`i', 2]
    local ci_0   = ci_mat[`i', 2]
    local sum_0  = `surv_0' + `ci_0'

    if abs(`sum_0' - 1.0) > 0.01 {
        local all_complementary = 0
        display "  Time `i': survival=" %6.4f `surv_0' " + cum_inc=" %6.4f `ci_0' " = " %6.4f `sum_0'
    }
}

* Also check arm 1
forvalues i = 1/`surv_rows' {
    local surv_1 = surv_mat[`i', 5]
    local ci_1   = ci_mat[`i', 5]
    local sum_1  = `surv_1' + `ci_1'

    if abs(`sum_1' - 1.0) > 0.01 {
        local all_complementary = 0
        display "  Time `i' (arm1): survival=" %6.4f `surv_1' " + cum_inc=" %6.4f `ci_1' " = " %6.4f `sum_1'
    }
}

if `all_complementary' == 1 {
    display as result "  PASS -- survival + cumulative incidence sum to ~1.0 at all time points"
    local ++pass_count
}
else {
    display as error "  FAIL -- survival + cumulative incidence do not sum to ~1.0"
    local ++fail_count
}

* =============================================================================
* TEST 3: difference stores r(rd_T) scalars
* =============================================================================
local ++test_count
display ""
display "Test `test_count': difference stores r(rd_T) scalars"

tte_predict, times(0(1)8) type(cum_inc) difference samples(50) seed(42)

local all_rd_exist = 1
forvalues t = 0/8 {
    capture local rd_val = r(rd_`t')
    if _rc != 0 | missing(`rd_val') {
        local all_rd_exist = 0
        display "  r(rd_`t') missing"
    }
    else {
        display "  r(rd_`t') = " %8.4f `rd_val'
    }
}

if `all_rd_exist' == 1 {
    display as result "  PASS -- r(rd_0) through r(rd_8) all non-missing"
    local ++pass_count
}
else {
    display as error "  FAIL -- some r(rd_T) scalars missing"
    local ++fail_count
}

* =============================================================================
* TEST 4: Risk difference sign correct
* =============================================================================
local ++test_count
display ""
display "Test `test_count': Risk difference sign correct"

* At the last time point, risk difference should be negative (treatment protective)
local rd_last = r(rd_8)

display "  r(rd_8) = " %8.4f `rd_last'

if `rd_last' < 0 {
    display as result "  PASS -- risk difference at T=8 is negative (protective treatment)"
    local ++pass_count
}
else {
    display as error "  FAIL -- risk difference at T=8 is non-negative"
    local ++fail_count
}

* =============================================================================
* TEST 5: seed() reproducibility
* =============================================================================
local ++test_count
display ""
display "Test `test_count': seed() reproducibility"

tte_predict, times(0(1)8) type(cum_inc) samples(50) seed(42)
matrix pred_run1 = r(predictions)

tte_predict, times(0(1)8) type(cum_inc) samples(50) seed(42)
matrix pred_run2 = r(predictions)

* Compare all elements
local identical = 1
forvalues i = 1/`=rowsof(pred_run1)' {
    forvalues j = 1/`=colsof(pred_run1)' {
        if pred_run1[`i', `j'] != pred_run2[`i', `j'] {
            local identical = 0
        }
    }
}

if `identical' == 1 {
    display as result "  PASS -- identical predictions with seed(42) across two runs"
    local ++pass_count
}
else {
    display as error "  FAIL -- predictions differ with same seed"
    local ++fail_count
}

* =============================================================================
* TEST 6: level(90) narrower CIs than level(99)
* =============================================================================
local ++test_count
display ""
display "Test `test_count': level(90) narrower CIs than level(99)"

tte_predict, times(0(1)8) type(cum_inc) samples(50) seed(42) level(90)
matrix pred_90 = r(predictions)

tte_predict, times(0(1)8) type(cum_inc) samples(50) seed(42) level(99)
matrix pred_99 = r(predictions)

* Compare CI widths: cols 3-2 = CI width for arm 0 at level 90 vs 99
local narrower_count = 0
local total_compare = 0

forvalues i = 1/`=rowsof(pred_90)' {
    * Arm 0 CI width: col 4 (hi) - col 3 (lo)
    local w90_0 = pred_90[`i', 4] - pred_90[`i', 3]
    local w99_0 = pred_99[`i', 4] - pred_99[`i', 3]

    if `w90_0' > 0 & `w99_0' > 0 {
        local ++total_compare
        if `w90_0' < `w99_0' {
            local ++narrower_count
        }
    }
}

display "  Time points where level(90) CI narrower than level(99): `narrower_count'/`total_compare'"

if `narrower_count' >= `total_compare' / 2 & `total_compare' > 0 {
    display as result "  PASS -- level(90) produces narrower CIs than level(99)"
    local ++pass_count
}
else {
    display as error "  FAIL -- level(90) CIs not consistently narrower"
    local ++fail_count
}

* =============================================================================
* TEST 7: samples(10) minimum runs
* =============================================================================
local ++test_count
display ""
display "Test `test_count': samples(10) minimum runs"

capture noisily tte_predict, times(0(2)8) type(cum_inc) samples(10) seed(42)

if _rc == 0 {
    display as result "  PASS -- samples(10) completed without error"
    local ++pass_count
}
else {
    display as error "  FAIL -- samples(10) failed (rc=" _rc ")"
    local ++fail_count
}

* =============================================================================
* SUMMARY
* =============================================================================
display ""
display "VALIDATION 15 SUMMARY: tte_predict Options"
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
display "RESULT: V15 tests=`test_count' pass=`pass_count' fail=`fail_count' status=`v_status'"

log close val_pred
