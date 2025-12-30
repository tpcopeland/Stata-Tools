/*******************************************************************************
* validation_tvestimate.do
*
* Purpose: Deep validation tests for tvestimate (G-estimation) command
*          Verifies mathematical correctness of G-estimation procedure
*
* Run modes:
*   Standalone: do validation_tvestimate.do
*   Via runner: do run_test.do validation_tvestimate [testnumber] [quiet] [machine]
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
        global STATA_TOOLS_PATH "`c(pwd)'/.."
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
    display as text "TVESTIMATE DEEP VALIDATION TESTS"
    display as text "{hline 70}"
    display as text "Validating G-estimation mathematical correctness"
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
* SECTION 1: KNOWN-ANSWER TESTING
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 1: Known-Answer Testing"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 1.1: Randomized experiment (treatment independent of confounders)
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 1.1: Randomized experiment"
}

capture {
    clear
    set seed 99999
    set obs 2000

    * In randomized experiment, treatment is independent of confounders
    gen confounder = rnormal()
    gen treatment = runiform() > 0.5  // Random assignment

    * Outcome with true effect = 3
    gen outcome = 10 + 3*treatment + 2*confounder + rnormal(0, 1)

    * G-estimation should recover true effect even though confounders
    * don't predict treatment
    tvestimate outcome treatment, confounders(confounder)

    * Effect should be close to 3 (within 0.3 for large N)
    assert abs(e(psi) - 3) < 0.3
}
if _rc == 0 {
    display as result "  PASS: Recovers effect in randomized experiment"
    local ++pass_count
}
else {
    display as error "  FAIL: Randomized experiment (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 1.1"
}

* -----------------------------------------------------------------------------
* Test 1.2: No confounding case matches OLS
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 1.2: No confounding matches OLS"
}

capture {
    clear
    set seed 88888
    set obs 1000

    * No confounding - treatment is random, confounder doesn't affect outcome
    gen x = rnormal()
    gen treatment = runiform() > 0.5

    * Outcome with true effect = 5
    gen outcome = 20 + 5*treatment + rnormal(0, 2)

    * G-estimation
    tvestimate outcome treatment, confounders(x)
    local psi_g = e(psi)

    * OLS
    regress outcome treatment
    local beta_ols = _b[treatment]

    * Should be very close since no confounding
    assert abs(`psi_g' - `beta_ols') < 0.5
}
if _rc == 0 {
    display as result "  PASS: No confounding matches OLS"
    local ++pass_count
}
else {
    display as error "  FAIL: No confounding test (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 1.2"
}

* -----------------------------------------------------------------------------
* Test 1.3: G-estimation corrects confounding bias
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 1.3: G-estimation corrects confounding bias"
}

capture {
    clear
    set seed 77777
    set obs 2000

    * Strong confounding
    gen confounder = rnormal()
    gen pr_treat = invlogit(-0.5 + 1.5*confounder)  // Strong confounding
    gen treatment = runiform() < pr_treat

    * True effect = 2, but confounder has strong effect on both
    gen outcome = 10 + 2*treatment + 3*confounder + rnormal(0, 1)

    * Naive OLS is biased
    regress outcome treatment
    local beta_naive = _b[treatment]

    * G-estimation should be closer to true value
    tvestimate outcome treatment, confounders(confounder)
    local psi_g = e(psi)

    * OLS should be biased away from 2 due to confounding
    * G-estimation should be closer to true value
    assert abs(`psi_g' - 2) < abs(`beta_naive' - 2)
}
if _rc == 0 {
    display as result "  PASS: G-estimation corrects confounding bias"
    local ++pass_count
}
else {
    display as error "  FAIL: Bias correction (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 1.3"
}

* =============================================================================
* SECTION 2: ESTIMATION EQUATION VERIFICATION
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 2: Estimation Equation Verification"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 2.1: Estimating equation equals zero at estimate
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 2.1: Estimating equation equals zero"
}

capture {
    clear
    set seed 66666
    set obs 500

    gen confounder = rnormal()
    gen pr_treat = invlogit(-0.5 + 0.5*confounder)
    gen treatment = runiform() < pr_treat
    gen outcome = 5 + 1.5*treatment + confounder + rnormal(0, 1)

    * Get G-estimate
    tvestimate outcome treatment, confounders(confounder)
    local psi = e(psi)

    * Manually compute propensity score
    logit treatment confounder
    predict pscore, pr

    * Blipped-down outcome
    gen y_blipped = outcome - `psi' * treatment

    * Residual
    gen resid = treatment - pscore

    * Estimating equation should sum to ~0
    gen ee = y_blipped * resid
    summarize ee
    local ee_sum = r(sum)

    * Sum should be very close to zero (numerical tolerance)
    assert abs(`ee_sum') < 1
}
if _rc == 0 {
    display as result "  PASS: Estimating equation sums to ~0"
    local ++pass_count
}
else {
    display as error "  FAIL: Estimating equation (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 2.1"
}

* =============================================================================
* SECTION 3: BLIPPED-DOWN OUTCOME
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 3: Blipped-Down Outcome Properties"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 3.1: Blipped-down outcome mean stored
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.1: Mean potential outcome under no treatment"
}

capture {
    clear
    set seed 55555
    set obs 500

    gen confounder = rnormal()
    gen pr_treat = invlogit(-0.5 + 0.5*confounder)
    gen treatment = runiform() < pr_treat
    gen outcome = 10 + 2*treatment + confounder + rnormal(0, 1)

    tvestimate outcome treatment, confounders(confounder)

    * Mean Y(0) should be stored
    assert e(mean_y0) != .

    * Mean Y(0) should be roughly equal to mean outcome for untreated
    * (under correct model specification)
    summarize outcome if treatment == 0
    local mean_untreated = r(mean)

    * Should be in similar ballpark (within 2 SD)
    assert abs(e(mean_y0) - `mean_untreated') < 2
}
if _rc == 0 {
    display as result "  PASS: Mean Y(0) stored correctly"
    local ++pass_count
}
else {
    display as error "  FAIL: Mean Y(0) (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.1"
}

* =============================================================================
* SECTION 4: BOOTSTRAP VALIDATION
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 4: Bootstrap Validation"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 4.1: Bootstrap reproducibility with seed
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.1: Bootstrap reproducibility"
}

capture {
    clear
    set seed 44444
    set obs 300

    gen confounder = rnormal()
    gen pr_treat = invlogit(-0.5 + 0.5*confounder)
    gen treatment = runiform() < pr_treat
    gen outcome = 5 + 2*treatment + confounder + rnormal(0, 1)

    * First run with seed
    tvestimate outcome treatment, confounders(confounder) bootstrap reps(50) seed(12345)
    local se1 = e(se_psi)

    * Second run with same seed
    tvestimate outcome treatment, confounders(confounder) bootstrap reps(50) seed(12345)
    local se2 = e(se_psi)

    * Should be identical
    assert abs(`se1' - `se2') < 0.0001
}
if _rc == 0 {
    display as result "  PASS: Bootstrap reproducible with seed"
    local ++pass_count
}
else {
    display as error "  FAIL: Bootstrap reproducibility (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.1"
}

* =============================================================================
* SECTION 5: INVARIANTS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 5: Invariants"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 5.1: Location shift invariance
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 5.1: Location shift invariance"
}

capture {
    clear
    set seed 33333
    set obs 500

    gen confounder = rnormal()
    gen pr_treat = invlogit(-0.5 + 0.5*confounder)
    gen treatment = runiform() < pr_treat
    gen outcome = 5 + 2*treatment + confounder + rnormal(0, 1)

    * Original estimate
    tvestimate outcome treatment, confounders(confounder)
    local psi_orig = e(psi)

    * Shift outcome by constant
    replace outcome = outcome + 100

    * Re-estimate
    tvestimate outcome treatment, confounders(confounder)
    local psi_shifted = e(psi)

    * Causal effect should be unchanged
    assert abs(`psi_orig' - `psi_shifted') < 0.001
}
if _rc == 0 {
    display as result "  PASS: Invariant to outcome location shift"
    local ++pass_count
}
else {
    display as error "  FAIL: Location shift invariance (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 5.1"
}

* -----------------------------------------------------------------------------
* Test 5.2: Scale invariance
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 5.2: Scale transformation"
}

capture {
    clear
    set seed 22222
    set obs 500

    gen confounder = rnormal()
    gen pr_treat = invlogit(-0.5 + 0.5*confounder)
    gen treatment = runiform() < pr_treat
    gen outcome = 5 + 2*treatment + confounder + rnormal(0, 1)

    * Original estimate
    tvestimate outcome treatment, confounders(confounder)
    local psi_orig = e(psi)

    * Scale outcome
    replace outcome = outcome * 10

    * Re-estimate
    tvestimate outcome treatment, confounders(confounder)
    local psi_scaled = e(psi)

    * Causal effect should scale by same factor
    assert abs(`psi_scaled' - 10 * `psi_orig') < 0.01
}
if _rc == 0 {
    display as result "  PASS: Scale transformation correct"
    local ++pass_count
}
else {
    display as error "  FAIL: Scale transformation (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 5.2"
}

* =============================================================================
* CLEANUP
* =============================================================================

* =============================================================================
* SUMMARY
* =============================================================================
display as text _n "{hline 70}"
display as text "TVESTIMATE VALIDATION SUMMARY"
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
