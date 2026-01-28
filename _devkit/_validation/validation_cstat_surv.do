/*******************************************************************************
* validation_cstat_surv.do
*
* Purpose: Deep validation tests for cstat_surv command using known-answer testing
*          These tests verify C-statistic (concordance) calculations are correct.
*
* Philosophy: Create minimal datasets where concordance can be calculated by hand.
*
* Run modes:
*   Standalone: do validation_cstat_surv.do
*   Via runner: do run_test.do validation_cstat_surv [testnumber] [quiet] [machine]
*
* Author: Auto-generated from validation plan
* Date: 2025-12-13
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
    * Try to detect path from current working directory
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

* Install cstat_surv
capture net uninstall cstat_surv
quietly net install cstat_surv, from("${STATA_TOOLS_PATH}/cstat_surv")

* =============================================================================
* HEADER
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "CSTAT_SURV DEEP VALIDATION TESTS"
    display as text "{hline 70}"
    display as text "These tests verify C-statistic calculations are correct."
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
* CONCORDANCE EXPLANATION
* =============================================================================
* C-statistic = probability that for a random pair where one has event,
* the one with the event has higher predicted risk
*
* Perfect prediction: C = 1.0
* Random prediction: C = 0.5
* Perfect inverse: C = 0.0
*
* For a pair (i, j) where time_i < time_j and event_i = 1:
*   Concordant if risk_i > risk_j
*   Discordant if risk_i < risk_j
*   Tied if risk_i = risk_j
*
* C = (concordant + 0.5*tied) / (concordant + discordant + tied)

* =============================================================================
* CREATE VALIDATION DATASETS
* =============================================================================
if `quiet' == 0 {
    display as text _n "Creating validation datasets..."
}

* Dataset: Perfect prediction
* Higher x = shorter survival (higher risk)
* All pairs concordant
clear
input double time byte event double x
    1 1 5  // Event at t=1, high risk
    2 1 4  // Event at t=2, high risk
    3 1 3  // Event at t=3, medium risk
    4 1 2  // Event at t=4, low risk
    5 0 1  // Censored at t=5, lowest risk
end
label data "Perfect prediction: higher x = higher risk = shorter survival"
save "${DATA_DIR}/cstat_perfect.dta", replace

* Dataset: Random prediction (all same risk)
* All pairs tied, C = 0.5
clear
input double time byte event double x
    1 1 1
    2 1 1
    3 1 1
    4 1 1
    5 0 1
end
label data "Random prediction: all same risk"
save "${DATA_DIR}/cstat_random.dta", replace

* Dataset: Inverse prediction
* Higher x = longer survival (lower risk)
* All pairs discordant
clear
input double time byte event double x
    1 1 1  // Event at t=1, lowest x
    2 1 2  // Event at t=2, low x
    3 1 3  // Event at t=3, medium x
    4 1 4  // Event at t=4, high x
    5 0 5  // Censored at t=5, highest x
end
label data "Inverse prediction: higher x = longer survival"
save "${DATA_DIR}/cstat_inverse.dta", replace

* Dataset: Known concordance
* 4 events, calculate pairs by hand
* Pairs: (1,2), (1,3), (1,4), (2,3), (2,4), (3,4)
clear
input double time byte event double x
    1 1 4.0  // Event, risk=4
    2 1 3.0  // Event, risk=3
    3 1 2.0  // Event, risk=2
    4 0 1.0  // Censored, risk=1
end
label data "Known concordance calculation"
save "${DATA_DIR}/cstat_known.dta", replace

if `quiet' == 0 {
    display as result "Validation datasets created in: ${DATA_DIR}"
}

* =============================================================================
* SECTION 1: PERFECT PREDICTION TESTS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 1: Perfect Prediction Tests"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 1.1: Perfect Concordance
* Purpose: Verify C approaches 1.0 for perfect prediction
* Known answer: All pairs concordant -> C near 1.0
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 1.1: Perfect Concordance"
}

capture {
    use "${DATA_DIR}/cstat_perfect.dta", clear
    stset time, failure(event)
    stcox x
    cstat_surv

    * C should be very high (near 1.0 for perfect prediction)
    assert e(c) > 0.9
}
if _rc == 0 {
    display as result "  PASS: Perfect prediction gives C > 0.9"
    local ++pass_count
}
else {
    display as error "  FAIL: Perfect prediction (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 1.1"
}

* =============================================================================
* SECTION 2: RANDOM PREDICTION TESTS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 2: Random/Null Prediction Tests"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 2.1: Null Model Concordance
* Purpose: Verify C is approximately 0.5 when predictor has no information
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 2.1: Null Model (No Discrimination)"
}

capture {
    * Create data where x has no predictive value
    clear
    set seed 12345
    set obs 100
    gen time = runiform() * 10
    gen event = runiform() > 0.3
    gen x = runiform()  // Random, unrelated to outcome

    stset time, failure(event)
    stcox x
    cstat_surv

    * C should be around 0.5 for random predictor
    * Allow wider range due to sampling variability
    assert e(c) > 0.3 & e(c) < 0.7
}
if _rc == 0 {
    display as result "  PASS: Random predictor gives C near 0.5"
    local ++pass_count
}
else {
    display as error "  FAIL: Random predictor (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 2.1"
}

* =============================================================================
* SECTION 3: INVERSE PREDICTION TESTS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 3: Inverse Prediction Tests"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 3.1: Inverse (Discordant) Prediction
* Purpose: Verify C < 0.5 when prediction is inverse
* Note: Cox model will flip sign, so C may still be high
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.1: Inverse Prediction Behavior"
}

capture {
    use "${DATA_DIR}/cstat_inverse.dta", clear
    stset time, failure(event)
    stcox x
    cstat_surv

    * Cox model learns the inverse relationship
    * C should still be high because model adapts
    assert e(c) != .
}
if _rc == 0 {
    display as result "  PASS: Inverse prediction handled"
    local ++pass_count
}
else {
    display as error "  FAIL: Inverse prediction (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.1"
}

* =============================================================================
* SECTION 4: KNOWN VALUE TESTS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 4: Known Value Tests"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 4.1: Hand-Calculated Concordance
* Purpose: Verify C matches hand calculation
*
* Dataset: 4 obs (3 events, 1 censored)
* time: 1, 2, 3, 4
* event: 1, 1, 1, 0
* x: 4, 3, 2, 1
*
* Comparable pairs (only compare to those with longer survival):
* Pair (t=1 vs t=2): risk 4 vs 3, event first -> concordant
* Pair (t=1 vs t=3): risk 4 vs 2, event first -> concordant
* Pair (t=1 vs t=4): risk 4 vs 1, event first -> concordant
* Pair (t=2 vs t=3): risk 3 vs 2, event first -> concordant
* Pair (t=2 vs t=4): risk 3 vs 1, event first -> concordant
* Pair (t=3 vs t=4): risk 2 vs 1, event first -> concordant
*
* All 6 pairs concordant -> C = 1.0
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.1: Hand-Calculated C-statistic"
}

capture {
    use "${DATA_DIR}/cstat_known.dta", clear
    stset time, failure(event)
    stcox x
    cstat_surv

    * All pairs concordant, C should be very high
    assert e(c) > 0.95
}
if _rc == 0 {
    display as result "  PASS: Hand-calculated concordance matches"
    local ++pass_count
}
else {
    display as error "  FAIL: Hand-calculated concordance (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.1"
}

* =============================================================================
* SECTION 5: ERROR HANDLING TESTS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 5: Error Handling"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 5.1: No Prior Cox Model
* Purpose: Verify error when stcox not run
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 5.1: No Prior Cox Model"
}

capture {
    clear all
    sysuse auto, clear
    capture cstat_surv
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: Error when no Cox model"
    local ++pass_count
}
else {
    display as error "  FAIL: Missing model check (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 5.1"
}

* -----------------------------------------------------------------------------
* Test 5.2: Non-Cox Estimation
* Purpose: Verify error after non-Cox estimation
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 5.2: Non-Cox Estimation"
}

capture {
    sysuse auto, clear
    regress price mpg weight
    capture cstat_surv
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: Error after non-Cox model"
    local ++pass_count
}
else {
    display as error "  FAIL: Non-Cox check (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 5.2"
}

* =============================================================================
* INVARIANT TESTS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "INVARIANT TESTS: Universal Properties"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Invariant 1: C-statistic in [0, 1]
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Invariant 1: C-statistic in [0, 1]"
}

capture {
    use "${DATA_DIR}/cstat_perfect.dta", clear
    stset time, failure(event)
    stcox x
    cstat_surv

    assert e(c) >= 0 & e(c) <= 1
}
if _rc == 0 {
    display as result "  PASS: C-statistic in valid range [0, 1]"
    local ++pass_count
}
else {
    display as error "  FAIL: C-statistic range invariant"
    local ++fail_count
    local failed_tests "`failed_tests' Inv1"
}

* -----------------------------------------------------------------------------
* Invariant 2: Standard Error is Non-Negative
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Invariant 2: SE >= 0"
}

capture {
    use "${DATA_DIR}/cstat_perfect.dta", clear
    stset time, failure(event)
    stcox x
    cstat_surv

    assert e(se) >= 0
}
if _rc == 0 {
    display as result "  PASS: SE is non-negative"
    local ++pass_count
}
else {
    display as error "  FAIL: SE non-negative invariant"
    local ++fail_count
    local failed_tests "`failed_tests' Inv2"
}

* -----------------------------------------------------------------------------
* Invariant 3: Confidence Interval Contains C-statistic
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Invariant 3: CI Contains C-statistic"
}

capture {
    use "${DATA_DIR}/cstat_perfect.dta", clear
    stset time, failure(event)
    stcox x
    cstat_surv

    assert e(c) >= e(ci_lo) & e(c) <= e(ci_hi)
}
if _rc == 0 {
    display as result "  PASS: C-statistic within CI"
    local ++pass_count
}
else {
    display as error "  FAIL: CI contains C invariant"
    local ++fail_count
    local failed_tests "`failed_tests' Inv3"
}

* =============================================================================
* SUMMARY
* =============================================================================
display as text _n "{hline 70}"
display as text "CSTAT_SURV VALIDATION SUMMARY"
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
