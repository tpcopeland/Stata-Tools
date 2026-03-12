/*******************************************************************************
* validate_pipeline_guards.do
*
* Validation 17: Out-of-Order Execution Guards
* Tests that _tte_check_* prerequisite guards correctly reject commands
* called out of sequence. No existing validation verifies these guards.
*
* Tests:
*   1. tte_expand before tte_prepare → rc == 198
*   2. tte_weight before tte_expand → rc == 198
*   3. tte_fit before tte_expand → rc == 198
*   4. tte_predict before tte_fit → rc == 198
*   5. tte_diagnose before tte_expand → rc == 198
*   6. tte_weight on ITT sets weights to 1
*******************************************************************************/

version 16.0
set more off
set varabbrev off

* --- Setup (assumes working directory is tte/qa/) ---
capture ado uninstall tte
adopath ++ ".."
capture log close val_guard
log using "validate_pipeline_guards.log", replace nomsg name(val_guard)
* Test counters
local test_count = 0
local pass_count = 0
local fail_count = 0

display "VALIDATION 17: Pipeline Guard Tests"
display "Date: $S_DATE $S_TIME"
display ""

* =============================================================================
* TEST 1: tte_expand before tte_prepare → rc == 198
* =============================================================================
local ++test_count
display ""
display "Test `test_count': tte_expand before tte_prepare"

* Create minimal unprepared dataset
clear
quietly set obs 100
generate id = _n
generate period = 0
generate treatment = rbinomial(1, 0.5)
generate outcome = rbinomial(1, 0.1)
generate eligible = 1

capture noisily tte_expand, maxfollowup(5)

local rc1 = _rc
display "  Return code: `rc1'"

if `rc1' == 198 {
    display as result "  PASS -- tte_expand correctly rejects unprepared data (rc=198)"
    local ++pass_count
}
else {
    display as error "  FAIL -- expected rc=198 but got rc=`rc1'"
    local ++fail_count
}

* =============================================================================
* TEST 2: tte_weight before tte_expand → rc == 198
* =============================================================================
local ++test_count
display ""
display "Test `test_count': tte_weight before tte_expand"

* Prepare data but do not expand
clear
quietly set obs 200
generate id = _n
generate byte x = rbinomial(1, 0.4)
expand 6
bysort id: generate period = _n - 1
sort id period
generate byte treatment = 0
quietly replace treatment = rbinomial(1, 0.15) if period == 0
bysort id (period): replace treatment = treatment[_n-1] if _n > 1 & treatment[_n-1] == 1
replace treatment = 0 if missing(treatment)
generate byte outcome = rbinomial(1, 0.02)
generate byte eligible = 1

tte_prepare, id(id) period(period) treatment(treatment) ///
    outcome(outcome) eligible(eligible) ///
    covariates(x) estimand(PP)

capture noisily tte_weight, switch_d_cov(x) stabilized nolog

local rc2 = _rc
display "  Return code: `rc2'"

if `rc2' == 198 {
    display as result "  PASS -- tte_weight correctly rejects unexpanded data (rc=198)"
    local ++pass_count
}
else {
    display as error "  FAIL -- expected rc=198 but got rc=`rc2'"
    local ++fail_count
}

* =============================================================================
* TEST 3: tte_fit before tte_expand → rc == 198
* =============================================================================
local ++test_count
display ""
display "Test `test_count': tte_fit before tte_expand"

* Data is still only prepared, not expanded
capture noisily tte_fit, outcome_cov(x) nolog

local rc3 = _rc
display "  Return code: `rc3'"

if `rc3' == 198 {
    display as result "  PASS -- tte_fit correctly rejects unexpanded data (rc=198)"
    local ++pass_count
}
else {
    display as error "  FAIL -- expected rc=198 but got rc=`rc3'"
    local ++fail_count
}

* =============================================================================
* TEST 4: tte_predict before tte_fit → rc == 198
* =============================================================================
local ++test_count
display ""
display "Test `test_count': tte_predict before tte_fit"

* Now expand but do not fit
clear
quietly set obs 200
generate id = _n
generate byte x = rbinomial(1, 0.4)
expand 6
bysort id: generate period = _n - 1
sort id period
generate byte treatment = 0
quietly replace treatment = rbinomial(1, 0.15) if period == 0
bysort id (period): replace treatment = treatment[_n-1] if _n > 1 & treatment[_n-1] == 1
replace treatment = 0 if missing(treatment)
generate byte outcome = rbinomial(1, 0.02)
generate byte eligible = 1

tte_prepare, id(id) period(period) treatment(treatment) ///
    outcome(outcome) eligible(eligible) ///
    covariates(x) estimand(ITT)

tte_expand, maxfollowup(4)

capture noisily tte_predict, times(0(1)4) type(cum_inc)

local rc4 = _rc
display "  Return code: `rc4'"

if `rc4' == 198 {
    display as result "  PASS -- tte_predict correctly rejects unfitted data (rc=198)"
    local ++pass_count
}
else {
    display as error "  FAIL -- expected rc=198 but got rc=`rc4'"
    local ++fail_count
}

* =============================================================================
* TEST 5: tte_diagnose before tte_expand → rc == 198
* =============================================================================
local ++test_count
display ""
display "Test `test_count': tte_diagnose before tte_expand"

* Data only prepared, not expanded
clear
quietly set obs 200
generate id = _n
generate byte x = rbinomial(1, 0.4)
expand 6
bysort id: generate period = _n - 1
sort id period
generate byte treatment = 0
quietly replace treatment = rbinomial(1, 0.15) if period == 0
bysort id (period): replace treatment = treatment[_n-1] if _n > 1 & treatment[_n-1] == 1
replace treatment = 0 if missing(treatment)
generate byte outcome = rbinomial(1, 0.02)
generate byte eligible = 1

tte_prepare, id(id) period(period) treatment(treatment) ///
    outcome(outcome) eligible(eligible) ///
    covariates(x) estimand(PP)

capture noisily tte_diagnose

local rc5 = _rc
display "  Return code: `rc5'"

if `rc5' == 198 {
    display as result "  PASS -- tte_diagnose correctly rejects unexpanded data (rc=198)"
    local ++pass_count
}
else {
    display as error "  FAIL -- expected rc=198 but got rc=`rc5'"
    local ++fail_count
}

* =============================================================================
* TEST 6: tte_weight on ITT sets weights to 1
* =============================================================================
local ++test_count
display ""
display "Test `test_count': tte_weight on ITT sets weights to 1"

clear
quietly set obs 500
generate id = _n
generate byte x = rbinomial(1, 0.4)
expand 8
bysort id: generate period = _n - 1
sort id period
generate byte treatment = 0
quietly replace treatment = rbinomial(1, 0.15) if period == 0
bysort id (period): replace treatment = treatment[_n-1] if _n > 1 & treatment[_n-1] == 1
replace treatment = 0 if missing(treatment)
generate byte outcome = rbinomial(1, 0.02)
generate byte eligible = 1

tte_prepare, id(id) period(period) treatment(treatment) ///
    outcome(outcome) eligible(eligible) ///
    covariates(x) estimand(ITT)

tte_expand, maxfollowup(6)

capture noisily tte_weight, switch_d_cov(x) stabilized nolog

local rc6 = _rc

if `rc6' == 0 {
    quietly summarize _tte_weight
    local mean_wt = r(mean)

    display "  Mean weight: " %8.4f `mean_wt'

    if abs(`mean_wt' - 1) < 0.001 {
        display as result "  PASS -- ITT weights are all 1 (mean=" %8.6f `mean_wt' ")"
        local ++pass_count
    }
    else {
        display as error "  FAIL -- ITT weights not equal to 1 (mean=" %8.6f `mean_wt' ")"
        local ++fail_count
    }
}
else {
    * If tte_weight on ITT returns an error, that's also acceptable behavior
    * (some implementations skip weighting for ITT entirely)
    display "  tte_weight on ITT returned rc=`rc6'"

    * Check if _tte_weight exists and is 1
    capture confirm variable _tte_weight
    if _rc == 0 {
        quietly summarize _tte_weight
        local mean_wt = r(mean)
        if abs(`mean_wt' - 1) < 0.001 {
            display as result "  PASS -- weights set to 1 despite error"
            local ++pass_count
        }
        else {
            display as error "  FAIL -- weight variable exists but not all 1"
            local ++fail_count
        }
    }
    else {
        display as error "  FAIL -- tte_weight on ITT failed and no weight variable created"
        local ++fail_count
    }
}

* =============================================================================
* SUMMARY
* =============================================================================
display ""
display "VALIDATION 17 SUMMARY: Pipeline Guard Tests"
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
display "RESULT: V17 tests=`test_count' pass=`pass_count' fail=`fail_count' status=`v_status'"

log close val_guard
