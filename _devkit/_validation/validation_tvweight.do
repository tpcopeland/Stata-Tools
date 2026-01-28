/*******************************************************************************
* validation_tvweight.do
*
* Purpose: Deep validation tests for tvweight command using known-answer testing
*          These tests verify mathematical correctness, not just execution.
*
* Philosophy: Create minimal datasets where every output value can be
*             mathematically verified by hand.
*
* Run modes:
*   Standalone: do validation_tvweight.do
*   Via runner: do run_test.do validation_tvweight [testnumber] [quiet] [machine]
*
* Author: Timothy P Copeland
* Date: 2025-12-29
*******************************************************************************/

clear all
set more off
version 16.0

* =============================================================================
* CONFIGURATION
* =============================================================================
if "$RUN_TEST_QUIET" == "" {
    global RUN_TEST_QUIET = 0
}
if "$RUN_TEST_MACHINE" == "" {
    global RUN_TEST_MACHINE = 0
}
if "$RUN_TEST_NUMBER" == "" {
    global RUN_TEST_NUMBER = 0
}

local quiet = $RUN_TEST_QUIET
local machine = $RUN_TEST_MACHINE
local run_only = $RUN_TEST_NUMBER

* =============================================================================
* PATH CONFIGURATION
* =============================================================================
if "`c(os)'" == "MacOSX" {
    global STATA_TOOLS_PATH "/Users/tcopeland/Documents/GitHub/Stata-Tools"
}
else if "`c(os)'" == "Unix" {
    capture confirm file "_validation"
    if _rc == 0 {
        global STATA_TOOLS_PATH "`c(pwd)'"
    }
    else {
        capture confirm file "_testing"
        if _rc == 0 {
            global STATA_TOOLS_PATH "`c(pwd)'"
        }
        else {
            global STATA_TOOLS_PATH "/home/`c(username)'/Stata-Tools"
        }
    }
}
else {
    capture confirm file "_validation"
    if _rc == 0 {
        global STATA_TOOLS_PATH "`c(pwd)'"
    }
    else {
        capture confirm file "data"
        if _rc == 0 {
            global STATA_TOOLS_PATH "`c(pwd)'/.."
        }
        else {
            global STATA_TOOLS_PATH "`c(pwd)'/../.."
        }
    }
}

global VALIDATION_DIR "${STATA_TOOLS_PATH}/_validation"
global DATA_DIR "${VALIDATION_DIR}/data"

capture mkdir "${DATA_DIR}"

* Install tvtools package
capture net uninstall tvtools
quietly net install tvtools, from("${STATA_TOOLS_PATH}/tvtools")

* =============================================================================
* HEADER
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "TVWEIGHT DEEP VALIDATION TESTS"
    display as text "{hline 70}"
    display as text "These tests verify mathematical correctness, not just execution."
    display as text "{hline 70}"
}

* =============================================================================
* TEST COUNTERS
* =============================================================================
local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

* =============================================================================
* VALIDATION DATASETS
* =============================================================================
if `quiet' == 0 {
    display as text _n "Creating validation datasets..."
}

* Dataset 1: Simple known propensity scores
* Create data where we can verify IPTW calculation manually
* 100 observations: 50 with x=0 (all untreated), 50 with x=1 (all treated)
clear
set obs 100
gen id = _n
gen x = (_n > 50)
gen treatment = x
* All PS should be 1 for treated when x=1, 0 for treated when x=0
* Weight = 1/1 = 1 for all
save "${DATA_DIR}/val_perfect_sep.dta", replace

* Dataset 2: Known propensity scores from simple model
* Create balanced data with predictable PS
clear
set obs 200
gen id = _n
* Binary covariate
gen x = mod(_n, 2)
* Treatment pattern: P(T=1|x=0) = 0.25, P(T=1|x=1) = 0.75
gen treatment = 0
replace treatment = 1 if x == 0 & _n <= 25  // 25 treated of 100 with x=0
replace treatment = 1 if x == 1 & _n > 100 & _n <= 175  // 75 treated of 100 with x=1
save "${DATA_DIR}/val_known_ps.dta", replace

* Dataset 3: For ESS calculation
* Simple case where ESS can be calculated by hand
clear
set obs 10
gen id = _n
gen x = 1
gen treatment = (_n <= 5)
save "${DATA_DIR}/val_ess.dta", replace

if `quiet' == 0 {
    display as result "Validation datasets created in: ${DATA_DIR}"
}

* =============================================================================
* SECTION 1: WEIGHT CALCULATION CORRECTNESS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 1: Weight Calculation Correctness"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 1.1: Known IPTW for simple case
* Purpose: Verify IPTW = 1/PS for treated, 1/(1-PS) for untreated
* With known PS from logistic regression
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 1.1: Known IPTW calculation"
}

capture {
    use "${DATA_DIR}/val_known_ps.dta", clear

    * First, fit logit manually and calculate expected weights
    quietly logit treatment x
    quietly predict ps_manual, pr

    * Calculate expected IPTW
    gen expected_iptw = .
    replace expected_iptw = 1/ps_manual if treatment == 1
    replace expected_iptw = 1/(1-ps_manual) if treatment == 0

    * Now use tvweight
    tvweight treatment, covariates(x) nolog

    * Verify weights match expected
    gen diff = abs(iptw - expected_iptw)
    sum diff
    assert r(max) < 0.0001
}
if _rc == 0 {
    display as result "  PASS: IPTW matches manual calculation"
    local ++pass_count
}
else {
    display as error "  FAIL: IPTW calculation (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 1.1"
}

* -----------------------------------------------------------------------------
* Test 1.2: Stabilized weights calculation
* Purpose: Verify SW = marginal_prob / PS (for treated)
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 1.2: Stabilized weights calculation"
}

capture {
    use "${DATA_DIR}/val_known_ps.dta", clear

    * Calculate marginal probability of treatment
    sum treatment
    local marg_prob = r(mean)

    * Fit logit and get PS
    quietly logit treatment x
    quietly predict ps_manual, pr

    * Calculate expected stabilized weights
    gen expected_sw = .
    replace expected_sw = `marg_prob' / ps_manual if treatment == 1
    replace expected_sw = (1 - `marg_prob') / (1 - ps_manual) if treatment == 0

    * Use tvweight with stabilized
    tvweight treatment, covariates(x) stabilized nolog

    * Verify weights match expected
    gen diff = abs(iptw - expected_sw)
    sum diff
    assert r(max) < 0.0001
}
if _rc == 0 {
    display as result "  PASS: Stabilized weights match manual calculation"
    local ++pass_count
}
else {
    display as error "  FAIL: Stabilized weights (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 1.2"
}

* =============================================================================
* SECTION 2: EFFECTIVE SAMPLE SIZE
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 2: Effective Sample Size"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 2.1: ESS calculation
* Purpose: Verify ESS = (sum w)^2 / sum(w^2)
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 2.1: ESS calculation"
}

capture {
    use "${DATA_DIR}/val_known_ps.dta", clear

    tvweight treatment, covariates(x) nolog

    * Save ESS from tvweight before other commands overwrite r()
    local tvweight_ess = r(ess)

    * Calculate ESS manually
    sum iptw
    local sum_w = r(sum)
    gen w2 = iptw^2
    sum w2
    local sum_w2 = r(sum)
    local expected_ess = (`sum_w'^2) / `sum_w2'

    * Compare with returned ESS
    assert abs(`tvweight_ess' - `expected_ess') < 0.01
}
if _rc == 0 {
    display as result "  PASS: ESS matches manual calculation"
    local ++pass_count
}
else {
    display as error "  FAIL: ESS calculation (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 2.1"
}

* -----------------------------------------------------------------------------
* Test 2.2: ESS percentage
* Purpose: Verify ESS% = 100 * ESS / N
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 2.2: ESS percentage"
}

capture {
    use "${DATA_DIR}/val_known_ps.dta", clear

    tvweight treatment, covariates(x) nolog

    * Save all return values before any other commands
    local n = r(N)
    local ess = r(ess)
    local ess_pct = r(ess_pct)
    local expected_pct = 100 * `ess' / `n'

    assert abs(`ess_pct' - `expected_pct') < 0.01
}
if _rc == 0 {
    display as result "  PASS: ESS percentage correct"
    local ++pass_count
}
else {
    display as error "  FAIL: ESS percentage (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 2.2"
}

* =============================================================================
* SECTION 3: TRUNCATION
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 3: Truncation Validation"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 3.1: Truncation bounds
* Purpose: After truncation, no weights outside bounds
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.1: Truncation bounds enforced"
}

capture {
    use "${DATA_DIR}/val_known_ps.dta", clear

    * Calculate untrimmed weights first
    tvweight treatment, covariates(x) generate(iptw_raw) nolog

    * Get 5th and 95th percentiles
    _pctile iptw_raw, p(5 95)
    local p5 = r(r1)
    local p95 = r(r2)

    * Now with truncation
    tvweight treatment, covariates(x) truncate(5 95) replace nolog

    * Verify no weights outside bounds
    count if iptw < `p5' - 0.0001
    assert r(N) == 0
    count if iptw > `p95' + 0.0001
    assert r(N) == 0
}
if _rc == 0 {
    display as result "  PASS: Truncation bounds enforced"
    local ++pass_count
}
else {
    display as error "  FAIL: Truncation bounds (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.1"
}

* =============================================================================
* SECTION 4: INVARIANTS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 4: Invariant Tests"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Invariant 4.1: Weights always positive
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Invariant 4.1: Weights always positive"
}

capture {
    use "${DATA_DIR}/val_known_ps.dta", clear
    tvweight treatment, covariates(x) nolog

    count if iptw <= 0 | missing(iptw)
    assert r(N) == 0
}
if _rc == 0 {
    display as result "  PASS: All weights positive"
    local ++pass_count
}
else {
    display as error "  FAIL: Some weights non-positive (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' Inv4.1"
}

* -----------------------------------------------------------------------------
* Invariant 4.2: Propensity scores between 0 and 1
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Invariant 4.2: Propensity scores bounded"
}

capture {
    use "${DATA_DIR}/val_known_ps.dta", clear
    tvweight treatment, covariates(x) denominator(ps) nolog

    count if ps <= 0 | ps >= 1
    assert r(N) == 0
}
if _rc == 0 {
    display as result "  PASS: All PS between 0 and 1"
    local ++pass_count
}
else {
    display as error "  FAIL: PS out of bounds (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' Inv4.2"
}

* -----------------------------------------------------------------------------
* Invariant 4.3: ESS <= N
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Invariant 4.3: ESS <= N"
}

capture {
    use "${DATA_DIR}/val_known_ps.dta", clear
    tvweight treatment, covariates(x) nolog

    assert r(ess) <= r(N) + 0.01  // Small tolerance for floating point
}
if _rc == 0 {
    display as result "  PASS: ESS <= N"
    local ++pass_count
}
else {
    display as error "  FAIL: ESS > N (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' Inv4.3"
}

* -----------------------------------------------------------------------------
* Invariant 4.4: Stabilized weights have mean near 1
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Invariant 4.4: Stabilized weights mean ~ 1"
}

capture {
    use "${DATA_DIR}/val_known_ps.dta", clear
    tvweight treatment, covariates(x) stabilized nolog

    * Mean of stabilized weights should be close to 1
    sum iptw
    assert abs(r(mean) - 1) < 0.1
}
if _rc == 0 {
    display as result "  PASS: Stabilized weights have mean near 1"
    local ++pass_count
}
else {
    display as error "  FAIL: Stabilized weights mean not near 1 (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' Inv4.4"
}

* =============================================================================
* SECTION 5: MULTINOMIAL WEIGHTS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 5: Multinomial Weight Validation"
    display as text "{hline 70}"
}

* Create multinomial test data
clear
set obs 300
gen id = _n
gen x = mod(_n, 3)  // 0, 1, 2 pattern
gen treatment = x   // Perfect prediction for testing
save "${DATA_DIR}/val_mlogit.dta", replace

* -----------------------------------------------------------------------------
* Test 5.1: Multinomial IPTW
* Purpose: Verify weights = 1/P(A=a|X) for each level
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 5.1: Multinomial IPTW calculation"
}

capture {
    use "${DATA_DIR}/val_mlogit.dta", clear

    * Add noise to prevent perfect separation
    replace treatment = mod(treatment + 1, 3) if _n <= 30

    * Fit mlogit manually
    quietly mlogit treatment x, baseoutcome(0)

    * Predict probabilities for each outcome
    forvalues k = 0/2 {
        quietly predict ps`k', pr outcome(`k')
    }

    * Calculate expected weights
    gen expected_w = .
    replace expected_w = 1/ps0 if treatment == 0
    replace expected_w = 1/ps1 if treatment == 1
    replace expected_w = 1/ps2 if treatment == 2

    * Use tvweight
    tvweight treatment, covariates(x) model(mlogit) nolog

    * Compare
    gen diff = abs(iptw - expected_w)
    sum diff
    assert r(max) < 0.0001
}
if _rc == 0 {
    display as result "  PASS: Multinomial IPTW matches manual calculation"
    local ++pass_count
}
else {
    display as error "  FAIL: Multinomial IPTW (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 5.1"
}

* =============================================================================
* SUMMARY
* =============================================================================
display as text _n "{hline 70}"
display as text "TVWEIGHT VALIDATION SUMMARY"
display as text "{hline 70}"
display as text "Total tests:  `test_count'"
display as result "Passed:       `pass_count'"
if `fail_count' > 0 {
    display as error "Failed:       `fail_count'"
}
else {
    display as text "Failed:       `fail_count'"
}
display as text "{hline 70}"

if `fail_count' > 0 {
    display as error _n "FAILED TESTS:`failed_tests'"
    display as text "{hline 70}"
    display as error "Some validation tests FAILED."
    exit 1
}
else {
    display as result _n "ALL VALIDATION TESTS PASSED!"
}

display as text _n "Validation completed: `c(current_date)' `c(current_time)'"
display as text "{hline 70}"
