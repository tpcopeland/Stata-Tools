/*******************************************************************************
* validation_tvweight_mathematical.do
*
* Purpose: Mathematical correctness validation for tvweight (IPTW).
*          Verifies IPTW formula against known propensity scores.
*
* Key formulas (from tvweight.ado):
*   Unstabilized: IPTW_treated = 1/PS, IPTW_untreated = 1/(1-PS)
*   Stabilized:   IPTW_treated = marg_prob/PS, IPTW_untreated = (1-marg_prob)/(1-PS)
*
* Tests:
*   8a. IPTW formula with known propensity scores (perfect predictor)
*   8b. Stabilized IPTW - mean in each group ≈ 1.0
*   8c. Weight distribution sanity checks (all positive)
*
* Run: stata-mp -b do validation_tvweight_mathematical.do
* Log: validation_tvweight_mathematical.log
*
* Author: Claude Code
* Date: 2026-02-17
*******************************************************************************/

clear all
set more off
version 16.0
set varabbrev off

local pass_count = 0
local fail_count = 0
local failed_tests ""

display _n _dup(70) "="
display "TVWEIGHT MATHEMATICAL VALIDATION"
display _dup(70) "="
display "Date: $S_DATE $S_TIME"
display ""

quietly adopath ++ "/home/tpcopeland/Stata-Tools/tvtools"

* ============================================================================
* TEST 8A: IPTW FORMULA WITH KNOWN PROPENSITY SCORES
* ============================================================================
display _n _dup(60) "-"
display "TEST 8A: IPTW formula - exact check with known propensity scores"
display _dup(60) "-"

local test8a_pass = 1

* Create a simple dataset where treatment is perfectly predicted by a covariate
* This allows us to verify: PS(treated) = 1, PS(untreated) = 0
* But with perfect separation, logit won't converge. Use an imperfect but strong predictor.
*
* Strategy: 2 groups (treated/untreated) with strong covariate signal
* After logit, PS for treated group ≈ high, for untreated ≈ low
* We verify: IPTW_i = 1/PS_i for treated, 1/(1-PS_i) for untreated

* Create a simple 40-person dataset with clear treatment groups
clear
set obs 40
gen id = _n
set seed 12345

* Perfect predictor: x1 determines treatment
gen x1 = (_n <= 20)    // 1 for persons 1-20, 0 for 21-40
gen treatment = x1 * 1    // treatment = 1 iff x1=1 (perfectly correlated)
* Add a tiny bit of noise to avoid perfect separation
replace treatment = 0 if id == 5    // one treated person in untreated group (per x1)
replace treatment = 1 if id == 25   // one untreated person in treated group

* Run tvweight
capture noisily tvweight treatment, ///
    covariates(x1) generate(iptw) denominator(ps_score) nolog replace

if _rc != 0 {
    display as error "  FAIL [8a.run]: tvweight returned error `=_rc'"
    local test8a_pass = 0
}
else {
    display "  INFO: Checking IPTW formula for each observation"

    * For each treated person: iptw should equal 1/ps_score
    quietly gen iptw_check = .
    quietly replace iptw_check = 1/ps_score if treatment == 1
    quietly replace iptw_check = 1/(1-ps_score) if treatment == 0

    quietly gen diff_iptw = abs(iptw - iptw_check)
    quietly sum diff_iptw
    local max_diff = r(max)
    local mean_diff = r(mean)

    if `max_diff' < 0.0001 {
        display as result "  PASS [8a.formula]: IPTW = 1/PS (treated) or 1/(1-PS) (untreated), max_diff=`max_diff'"
    }
    else {
        display as error "  FAIL [8a.formula]: max_diff=`max_diff', mean_diff=`mean_diff'"
        list treatment ps_score iptw iptw_check diff_iptw if diff_iptw > 0.001, noobs
        local test8a_pass = 0
    }

    * All IPTW should be positive
    quietly count if iptw <= 0 | missing(iptw)
    if r(N) == 0 {
        display as result "  PASS [8a.positive]: all IPTW weights > 0"
    }
    else {
        display as error "  FAIL [8a.positive]: `=r(N)' non-positive IPTW values"
        local test8a_pass = 0
    }
}

if `test8a_pass' == 1 {
    local pass_count = `pass_count' + 1
    display as result "TEST 8A: PASSED"
}
else {
    local fail_count = `fail_count' + 1
    local failed_tests "`failed_tests' 8a"
    display as error "TEST 8A: FAILED"
}

* ============================================================================
* TEST 8B: STABILIZED IPTW - MEAN = 1.0 EXACTLY (DETERMINISTIC)
* ============================================================================
display _n _dup(60) "-"
display "TEST 8B: Stabilized IPTW - mean = 1.0 in each group (deterministic)"
display _dup(60) "-"

local test8b_pass = 1

* Deterministic 4-cell balanced design (no random data → no convergence issues)
* 70 obs: 25 (x1=1,trt=1), 10 (x1=1,trt=0), 10 (x1=0,trt=1), 25 (x1=0,trt=0)
*
* Logit model: logit(P) = alpha + beta*x1
*   P(A=1|x1=1) = 25/35 = 5/7 ≈ 0.7143
*   P(A=1|x1=0) = 10/35 = 2/7 ≈ 0.2857
*   Marginal P(A=1) = 35/70 = 0.5
*
* Expected stabilized IPTW:
*   x1=1, treated:   0.5 / (5/7) = 0.7
*   x1=0, treated:   0.5 / (2/7) = 1.75
*   x1=1, untreated: 0.5 / (2/7) = 1.75
*   x1=0, untreated: 0.5 / (5/7) = 0.7
*
* Mean stab IPTW (treated)   = (25×0.7 + 10×1.75) / 35 = 35/35 = 1.0 exactly
* Mean stab IPTW (untreated) = (10×1.75 + 25×0.7) / 35 = 35/35 = 1.0 exactly

clear
set obs 70
gen id = _n
gen x1 = (_n <= 35)
gen treatment = 0
replace treatment = 1 if _n <= 25               // 25 with x1=1, treated
replace treatment = 1 if _n > 35 & _n <= 45    // 10 with x1=0, treated

* Verify cell counts
quietly count if treatment == 1
display "  INFO: n_treated = `r(N)' (expected 35)"
quietly count if treatment == 0
display "  INFO: n_untreated = `r(N)' (expected 35)"

capture noisily tvweight treatment, ///
    covariates(x1) generate(iptw_stab) stabilized nolog replace

if _rc != 0 {
    display as error "  FAIL [8b.run]: tvweight returned error `=_rc'"
    local test8b_pass = 0
}
else {
    * Check mean stabilized weight in each group
    quietly sum iptw_stab if treatment == 1
    local mean_treated = r(mean)
    quietly sum iptw_stab if treatment == 0
    local mean_untreated = r(mean)

    display "  INFO: Mean stabilized IPTW (treated) = `mean_treated' (expected 1.0)"
    display "  INFO: Mean stabilized IPTW (untreated) = `mean_untreated' (expected 1.0)"

    * With deterministic data and balanced design, mean should be ≈1.0 (within 0.01)
    if abs(`mean_treated' - 1) < 0.01 {
        display as result "  PASS [8b.treated]: mean stab IPTW (treated) = `mean_treated' ≈ 1.0"
    }
    else {
        display as error "  FAIL [8b.treated]: mean stab IPTW (treated) = `mean_treated', expected 1.0"
        local test8b_pass = 0
    }

    if abs(`mean_untreated' - 1) < 0.01 {
        display as result "  PASS [8b.untreated]: mean stab IPTW (untreated) = `mean_untreated' ≈ 1.0"
    }
    else {
        display as error "  FAIL [8b.untreated]: mean stab IPTW (untreated) = `mean_untreated', expected 1.0"
        local test8b_pass = 0
    }

    * All weights should be positive
    quietly count if iptw_stab <= 0 | missing(iptw_stab)
    if r(N) == 0 {
        display as result "  PASS [8b.positive]: all stabilized IPTW > 0"
    }
    else {
        display as error "  FAIL [8b.positive]: `=r(N)' non-positive stabilized IPTW"
        local test8b_pass = 0
    }
}

if `test8b_pass' == 1 {
    local pass_count = `pass_count' + 1
    display as result "TEST 8B: PASSED"
}
else {
    local fail_count = `fail_count' + 1
    local failed_tests "`failed_tests' 8b"
    display as error "TEST 8B: FAILED"
}

* ============================================================================
* TEST 8C: HORVITZ-THOMPSON IDENTITY (UNSTABILIZED IPTW) - EXACT VALUE
* ============================================================================
display _n _dup(60) "-"
display "TEST 8C: Horvitz-Thompson: mean IPTW (treated) = n_total/n_treated (exact)"
display _dup(60) "-"

local test8c_pass = 1

* Reuse same 4-cell deterministic dataset as 8B:
* n_total=70, n_treated=35, expected mean IPTW (treated) = 70/35 = 2.0 exactly
*
* Expected unstabilized IPTW:
*   x1=1, treated (25 obs):   1 / (5/7) = 7/5 = 1.4
*   x1=0, treated (10 obs):   1 / (2/7) = 7/2 = 3.5
*   Mean IPTW (treated) = (25×1.4 + 10×3.5) / 35 = 70/35 = 2.0 exactly
*   This equals n_total/n_treated = 70/35 = 2.0 (Horvitz-Thompson)

clear
set obs 70
gen id = _n
gen x1 = (_n <= 35)
gen treatment = 0
replace treatment = 1 if _n <= 25
replace treatment = 1 if _n > 35 & _n <= 45

quietly count
local n_total = r(N)
quietly count if treatment == 1
local n_treated = r(N)
local ht_expected = `n_total' / `n_treated'

display "  INFO: n_total=`n_total', n_treated=`n_treated', HT expected=`ht_expected' (expected 2.0)"

capture noisily tvweight treatment, ///
    covariates(x1) generate(iptw) nolog replace

if _rc != 0 {
    display as error "  FAIL [8c.run]: tvweight returned error `=_rc'"
    local test8c_pass = 0
}
else {
    quietly sum iptw if treatment == 1
    local mean_iptw_treated = r(mean)
    display "  INFO: Mean unstabilized IPTW (treated) = `mean_iptw_treated', expected = `ht_expected'"

    * With deterministic data, should match within 0.01
    local diff = abs(`mean_iptw_treated' - `ht_expected') / `ht_expected'
    if `diff' < 0.01 {
        display as result "  PASS [8c.ht]: IPTW mean = `mean_iptw_treated' = n_total/n_treated (diff=`=100*`diff''%)"
    }
    else {
        display as error "  FAIL [8c.ht]: IPTW mean=`mean_iptw_treated', expected=`ht_expected' (diff=`=100*`diff''%)"
        local test8c_pass = 0
    }
}

if `test8c_pass' == 1 {
    local pass_count = `pass_count' + 1
    display as result "TEST 8C: PASSED"
}
else {
    local fail_count = `fail_count' + 1
    local failed_tests "`failed_tests' 8c"
    display as error "TEST 8C: FAILED"
}

* ============================================================================
* FINAL SUMMARY
* ============================================================================
local total_tests = `pass_count' + `fail_count'
display _n _dup(70) "="
display "TVWEIGHT MATHEMATICAL VALIDATION SUMMARY"
display _dup(70) "="
display "Tests run:    `total_tests'"
display "Tests passed: `pass_count'"
display "Tests failed: `fail_count'"
if "`failed_tests'" != "" {
    display as error "Failed tests: `failed_tests'"
}
display _dup(70) "="

if `fail_count' == 0 {
    display as result _n "ALL TVWEIGHT MATHEMATICAL TESTS PASSED"
}
else {
    display as error _n "`fail_count' TVWEIGHT MATHEMATICAL TESTS FAILED"
    exit 1
}
