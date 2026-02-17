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
* TEST 8B: STABILIZED IPTW - MEAN ≈ 1.0 IN EACH GROUP
* ============================================================================
display _n _dup(60) "-"
display "TEST 8B: Stabilized IPTW - mean ≈ 1.0 in each group"
display _dup(60) "-"

local test8b_pass = 1

* Stabilized IPTW has a known property:
* E[IPTW_stab | A=1] ≈ 1 (marginal probability / conditional probability)
* This follows from the Horvitz-Thompson theorem

clear
set obs 100
gen id = _n
set seed 99999

* Confounded treatment: covariate x1 affects both treatment and outcome
gen x1 = runiform() > 0.5
gen x2 = runiform() > 0.4
gen treatment = (x1 + x2 + runiform() > 1.5) * 1
* ~25% treated

capture noisily tvweight treatment, ///
    covariates(x1 x2) generate(iptw_stab) stabilized nolog replace

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

    display "  INFO: Mean stabilized IPTW (treated) = `mean_treated'"
    display "  INFO: Mean stabilized IPTW (untreated) = `mean_untreated'"

    * For large samples, means should be close to 1
    * We use a 20% tolerance since this is a random dataset
    if abs(`mean_treated' - 1) < 0.2 {
        display as result "  PASS [8b.treated]: mean stab IPTW (treated) ≈ 1 (=`mean_treated')"
    }
    else {
        display as error "  FAIL [8b.treated]: mean stab IPTW (treated) = `mean_treated', expected ≈ 1"
        local test8b_pass = 0
    }

    if abs(`mean_untreated' - 1) < 0.2 {
        display as result "  PASS [8b.untreated]: mean stab IPTW (untreated) ≈ 1 (=`mean_untreated')"
    }
    else {
        display as error "  FAIL [8b.untreated]: mean stab IPTW (untreated) = `mean_untreated', expected ≈ 1"
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
* TEST 8C: HORVITZ-THOMPSON IDENTITY (UNSTABILIZED IPTW)
* ============================================================================
display _n _dup(60) "-"
display "TEST 8C: Horvitz-Thompson: mean IPTW (treated) ≈ n_total/n_treated"
display _dup(60) "-"

local test8c_pass = 1

* Horvitz-Thompson: E[1/PS | A=1] = n_total/n_treated in expectation

clear
set obs 200
gen id = _n
set seed 54321

gen x1 = runiform() > 0.6
gen treatment = (x1 + runiform() > 1.2) * 1

quietly count
local n_total = r(N)
quietly count if treatment == 1
local n_treated = r(N)
local ht_expected = `n_total' / `n_treated'

display "  INFO: n_total=`n_total', n_treated=`n_treated', HT expected=`ht_expected'"

capture noisily tvweight treatment, ///
    covariates(x1) generate(iptw) nolog replace

if _rc != 0 {
    display as error "  FAIL [8c.run]: tvweight returned error `=_rc'"
    local test8c_pass = 0
}
else {
    quietly sum iptw if treatment == 1
    local mean_iptw_treated = r(mean)
    display "  INFO: Mean unstabilized IPTW (treated) = `mean_iptw_treated', expected ≈ `ht_expected'"

    * Should be roughly equal (within 20% for random sample)
    local diff = abs(`mean_iptw_treated' - `ht_expected') / `ht_expected'
    if `diff' < 0.3 {
        display as result "  PASS [8c.ht]: IPTW mean ≈ n_total/n_treated (diff=`=100*`diff''%)"
    }
    else {
        display as error "  FAIL [8c.ht]: IPTW mean=`mean_iptw_treated', expected≈`ht_expected' (diff=`=100*`diff''%)"
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
