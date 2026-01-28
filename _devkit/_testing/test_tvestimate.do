/*******************************************************************************
* test_tvestimate.do
*
* Purpose: Functional tests for tvestimate (G-estimation) command
*
* Run modes:
*   Standalone: do test_tvestimate.do
*   Via runner: do run_test.do test_tvestimate [testnumber] [quiet] [machine]
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
    capture confirm file "_testing"
    if _rc == 0 {
        global STATA_TOOLS_PATH "`c(pwd)'"
    }
    else {
        global STATA_TOOLS_PATH "/home/`c(username)'/Stata-Tools"
    }
}
else {
    capture confirm file "_testing"
    if _rc == 0 {
        global STATA_TOOLS_PATH "`c(pwd)'"
    }
    else {
        global STATA_TOOLS_PATH "`c(pwd)'/.."
    }
}

global TESTING_DIR "${STATA_TOOLS_PATH}/_testing"
global DATA_DIR "${TESTING_DIR}/data"

capture mkdir "${DATA_DIR}"

* Install tvtools package
capture net uninstall tvtools
quietly net install tvtools, from("${STATA_TOOLS_PATH}/tvtools")

* =============================================================================
* HEADER
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "TVESTIMATE (G-ESTIMATION) TEST SUITE"
    display as text "{hline 70}"
    display as text "Testing G-estimation for structural nested mean models"
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
* CREATE TEST DATA
* =============================================================================
if `quiet' == 0 {
    display as text _n "Creating test datasets..."
}

* Simple dataset with known causal effect
clear
set seed 12345
set obs 1000

* Confounders
gen age = 50 + rnormal(0, 10)
gen sex = runiform() > 0.5
gen confounder = rnormal()

* Treatment depends on confounders
gen pr_treat = invlogit(-1 + 0.02*age + 0.5*sex + 0.3*confounder)
gen treatment = runiform() < pr_treat

* Outcome with TRUE causal effect = 2
gen outcome = 50 + 2*treatment + 0.5*age + 1*sex + 2*confounder + rnormal(0, 5)

* Create ID for clustering tests
gen id = _n

save "${DATA_DIR}/test_gestim.dta", replace

if `quiet' == 0 {
    display as result "Test data created"
}

* =============================================================================
* SECTION 1: BASIC FUNCTIONALITY
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 1: Basic Functionality"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 1.1: Basic G-estimation
* -----------------------------------------------------------------------------
local ++test_count
if `run_only' == 0 | `run_only' == 1 {
    if `quiet' == 0 {
        display as text _n "Test 1.1: Basic G-estimation"
    }

    capture {
        use "${DATA_DIR}/test_gestim.dta", clear
        tvestimate outcome treatment, confounders(age sex confounder)

        * Verify results stored
        assert e(N) == 1000
        assert e(psi) != .
        assert e(se_psi) > 0
    }
    if _rc == 0 {
        display as result "  PASS: Basic G-estimation works"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Basic G-estimation (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' 1.1"
    }
}

* -----------------------------------------------------------------------------
* Test 1.2: Effect estimate near true value
* -----------------------------------------------------------------------------
local ++test_count
if `run_only' == 0 | `run_only' == 2 {
    if `quiet' == 0 {
        display as text _n "Test 1.2: Effect estimate near true value (psi=2)"
    }

    capture {
        use "${DATA_DIR}/test_gestim.dta", clear
        tvestimate outcome treatment, confounders(age sex confounder)

        * True effect is 2, estimate should be within 0.5
        assert abs(e(psi) - 2) < 0.5
    }
    if _rc == 0 {
        display as result "  PASS: Effect estimate reasonable (within 0.5 of true value)"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Effect estimate off (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' 1.2"
    }
}

* =============================================================================
* SECTION 2: STANDARD ERROR OPTIONS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 2: Standard Error Options"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 2.1: Robust standard errors
* -----------------------------------------------------------------------------
local ++test_count
if `run_only' == 0 | `run_only' == 3 {
    if `quiet' == 0 {
        display as text _n "Test 2.1: Robust standard errors"
    }

    capture {
        use "${DATA_DIR}/test_gestim.dta", clear
        tvestimate outcome treatment, confounders(age sex confounder) robust

        * Verify vcetype is Robust
        assert "`e(vcetype)'" == "Robust"
        assert e(se_psi) > 0
    }
    if _rc == 0 {
        display as result "  PASS: Robust SE works"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Robust SE (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' 2.1"
    }
}

* -----------------------------------------------------------------------------
* Test 2.2: Clustered standard errors
* -----------------------------------------------------------------------------
local ++test_count
if `run_only' == 0 | `run_only' == 4 {
    if `quiet' == 0 {
        display as text _n "Test 2.2: Clustered standard errors"
    }

    capture {
        use "${DATA_DIR}/test_gestim.dta", clear

        * Create cluster structure (100 clusters of 10)
        gen cluster_id = ceil(_n / 10)

        tvestimate outcome treatment, confounders(age sex confounder) cluster(cluster_id)

        * Verify vcetype is Clustered
        assert "`e(vcetype)'" == "Clustered"
        assert e(se_psi) > 0
    }
    if _rc == 0 {
        display as result "  PASS: Clustered SE works"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Clustered SE (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' 2.2"
    }
}

* -----------------------------------------------------------------------------
* Test 2.3: Bootstrap standard errors
* -----------------------------------------------------------------------------
local ++test_count
if `run_only' == 0 | `run_only' == 5 {
    if `quiet' == 0 {
        display as text _n "Test 2.3: Bootstrap standard errors"
    }

    capture {
        use "${DATA_DIR}/test_gestim.dta", clear
        tvestimate outcome treatment, confounders(age sex confounder) ///
            bootstrap reps(50) seed(12345)

        * Verify vcetype is Bootstrap
        assert "`e(vcetype)'" == "Bootstrap"
        assert e(reps) == 50
        assert e(se_psi) > 0
    }
    if _rc == 0 {
        display as result "  PASS: Bootstrap SE works"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Bootstrap SE (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' 2.3"
    }
}

* =============================================================================
* SECTION 3: PROPENSITY SCORE DIAGNOSTICS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 3: Propensity Score Diagnostics"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 3.1: Propensity score statistics stored
* -----------------------------------------------------------------------------
local ++test_count
if `run_only' == 0 | `run_only' == 6 {
    if `quiet' == 0 {
        display as text _n "Test 3.1: Propensity score statistics stored"
    }

    capture {
        use "${DATA_DIR}/test_gestim.dta", clear
        tvestimate outcome treatment, confounders(age sex confounder)

        * Verify PS statistics
        assert e(ps_mean) > 0 & e(ps_mean) < 1
        assert e(ps_min) >= 0
        assert e(ps_max) <= 1
        assert e(ps_min) <= e(ps_mean)
        assert e(ps_max) >= e(ps_mean)
    }
    if _rc == 0 {
        display as result "  PASS: PS statistics stored correctly"
        local ++pass_count
    }
    else {
        display as error "  FAIL: PS statistics (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' 3.1"
    }
}

* =============================================================================
* SECTION 4: INFERENCE
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 4: Inference"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 4.1: Confidence interval
* -----------------------------------------------------------------------------
local ++test_count
if `run_only' == 0 | `run_only' == 7 {
    if `quiet' == 0 {
        display as text _n "Test 4.1: Confidence interval contains true value"
    }

    capture {
        use "${DATA_DIR}/test_gestim.dta", clear
        tvestimate outcome treatment, confounders(age sex confounder) level(95)

        * True effect (2) should be in 95% CI
        assert 2 > e(ci_lo) & 2 < e(ci_hi)
        assert e(level) == 95
    }
    if _rc == 0 {
        display as result "  PASS: 95% CI contains true value"
        local ++pass_count
    }
    else {
        display as error "  FAIL: CI test (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' 4.1"
    }
}

* -----------------------------------------------------------------------------
* Test 4.2: Custom confidence level
* -----------------------------------------------------------------------------
local ++test_count
if `run_only' == 0 | `run_only' == 8 {
    if `quiet' == 0 {
        display as text _n "Test 4.2: Custom confidence level (90%)"
    }

    capture {
        use "${DATA_DIR}/test_gestim.dta", clear
        tvestimate outcome treatment, confounders(age sex confounder) level(90)

        * Check level is stored correctly
        assert e(level) == 90

        * 90% CI should be narrower than 95%
        local ci_width_90 = e(ci_hi) - e(ci_lo)

        tvestimate outcome treatment, confounders(age sex confounder) level(95)
        local ci_width_95 = e(ci_hi) - e(ci_lo)

        assert `ci_width_90' < `ci_width_95'
    }
    if _rc == 0 {
        display as result "  PASS: Custom confidence level works"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Custom level (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' 4.2"
    }
}

* =============================================================================
* SECTION 5: ERROR HANDLING
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 5: Error Handling"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 5.1: Non-binary treatment error
* -----------------------------------------------------------------------------
local ++test_count
if `run_only' == 0 | `run_only' == 9 {
    if `quiet' == 0 {
        display as text _n "Test 5.1: Non-binary treatment error"
    }

    capture {
        use "${DATA_DIR}/test_gestim.dta", clear
        gen multi_treat = ceil(runiform() * 3)  // Values 1, 2, 3

        tvestimate outcome multi_treat, confounders(age sex)
    }
    if _rc != 0 {
        display as result "  PASS: Correctly errors on non-binary treatment"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Should error on non-binary treatment"
        local ++fail_count
        local failed_tests "`failed_tests' 5.1"
    }
}

* -----------------------------------------------------------------------------
* Test 5.2: Invalid model type error
* -----------------------------------------------------------------------------
local ++test_count
if `run_only' == 0 | `run_only' == 10 {
    if `quiet' == 0 {
        display as text _n "Test 5.2: Invalid model type error"
    }

    capture {
        use "${DATA_DIR}/test_gestim.dta", clear
        tvestimate outcome treatment, confounders(age sex) model(invalid)
    }
    if _rc != 0 {
        display as result "  PASS: Correctly errors on invalid model type"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Should error on invalid model"
        local ++fail_count
        local failed_tests "`failed_tests' 5.2"
    }
}

* -----------------------------------------------------------------------------
* Test 5.3: Missing confounders error
* -----------------------------------------------------------------------------
local ++test_count
if `run_only' == 0 | `run_only' == 11 {
    if `quiet' == 0 {
        display as text _n "Test 5.3: Missing confounders error"
    }

    capture {
        use "${DATA_DIR}/test_gestim.dta", clear
        tvestimate outcome treatment
    }
    if _rc != 0 {
        display as result "  PASS: Correctly errors on missing confounders"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Should error on missing confounders"
        local ++fail_count
        local failed_tests "`failed_tests' 5.3"
    }
}

* =============================================================================
* SECTION 6: IF/IN CONDITIONS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 6: If/In Conditions"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 6.1: If condition
* -----------------------------------------------------------------------------
local ++test_count
if `run_only' == 0 | `run_only' == 12 {
    if `quiet' == 0 {
        display as text _n "Test 6.1: If condition"
    }

    capture {
        use "${DATA_DIR}/test_gestim.dta", clear
        tvestimate outcome treatment if age > 50, confounders(sex confounder)

        * Should use subset
        assert e(N) < 1000
    }
    if _rc == 0 {
        display as result "  PASS: If condition works"
        local ++pass_count
    }
    else {
        display as error "  FAIL: If condition (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' 6.1"
    }
}

* -----------------------------------------------------------------------------
* Test 6.2: In condition
* -----------------------------------------------------------------------------
local ++test_count
if `run_only' == 0 | `run_only' == 13 {
    if `quiet' == 0 {
        display as text _n "Test 6.2: In condition"
    }

    capture {
        use "${DATA_DIR}/test_gestim.dta", clear
        tvestimate outcome treatment in 1/500, confounders(age sex confounder)

        * Should use first 500 obs
        assert e(N) == 500
    }
    if _rc == 0 {
        display as result "  PASS: In condition works"
        local ++pass_count
    }
    else {
        display as error "  FAIL: In condition (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' 6.2"
    }
}

* =============================================================================
* CLEANUP
* =============================================================================
capture erase "${DATA_DIR}/test_gestim.dta"

* =============================================================================
* SUMMARY
* =============================================================================
display as text _n "{hline 70}"
display as text "TVESTIMATE TEST SUMMARY"
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
    display as error "Some tests FAILED."
    exit 1
}
else {
    display as result _n "ALL TESTS PASSED!"
}

display as text _n "Testing completed: `c(current_date)' `c(current_time)'"
display as text "{hline 70}"
