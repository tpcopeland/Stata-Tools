/*******************************************************************************
* test_tvweight.do
*
* Purpose: Functional tests for tvweight command
*          Tests that all options execute without errors.
*
* Run modes:
*   Standalone: do test_tvweight.do
*   Via runner: do run_test.do test_tvweight [testnumber] [quiet] [machine]
*
* Author: Timothy P Copeland
* Date: 2025-12-29
*******************************************************************************/

clear all
set more off
version 16.0

* =============================================================================
* CONFIGURATION: Check for runner globals or set defaults
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
        capture confirm file "data"
        if _rc == 0 {
            global STATA_TOOLS_PATH "`c(pwd)'/.."
        }
        else {
            global STATA_TOOLS_PATH "/home/`c(username)'/Stata-Tools"
        }
    }
}
else {
    capture confirm file "_testing"
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

global TESTING_DIR "${STATA_TOOLS_PATH}/_testing"
global DATA_DIR "${TESTING_DIR}/data"

* Install tvtools package
capture net uninstall tvtools
quietly net install tvtools, from("${STATA_TOOLS_PATH}/tvtools")

* =============================================================================
* HEADER
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "TVWEIGHT FUNCTIONAL TESTS"
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
    display as text _n "Creating test data..."
}

* Create a simple dataset with binary treatment and confounders
clear
set seed 12345
set obs 500

* Person ID
gen id = _n

* Time periods (simulate person-time data)
expand 4
bysort id: gen period = _n
bysort id: gen start = period * 90
bysort id: gen stop = start + 89

* Confounders
gen age = 40 + 20 * runiform()
gen sex = runiform() > 0.5
gen comorbidity = runiform() > 0.7

* Binary treatment influenced by confounders
gen ps_true = invlogit(-2 + 0.03*age + 0.5*sex + 0.8*comorbidity)
gen treatment = runiform() < ps_true

* Outcome (not needed for weight calculation, but useful)
gen outcome = runiform() < 0.1

tempfile testdata
save `testdata', replace

* Create categorical treatment version
use `testdata', clear
gen drug_type = 0
replace drug_type = 1 if treatment == 1 & runiform() < 0.6
replace drug_type = 2 if treatment == 1 & drug_type == 0

tempfile testdata_cat
save `testdata_cat', replace

if `quiet' == 0 {
    display as result "Test data created: 500 persons, 4 periods each"
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
* Test 1.1: Basic IPTW calculation
* -----------------------------------------------------------------------------
local ++test_count
if `run_only' == 0 | `run_only' == 1 {
    if `quiet' == 0 {
        display as text _n "Test 1.1: Basic IPTW calculation"
    }

    capture {
        use `testdata', clear
        tvweight treatment, covariates(age sex) nolog
        * Verify weight variable exists
        confirm variable iptw
        * Verify weights are positive
        assert iptw > 0
        * Verify return values exist
        assert r(N) > 0
        assert r(ess) > 0
    }
    if _rc == 0 {
        display as result "  PASS: Basic IPTW calculation works"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Basic IPTW calculation (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' 1.1"
    }
}

* -----------------------------------------------------------------------------
* Test 1.2: Custom variable name
* -----------------------------------------------------------------------------
local ++test_count
if `run_only' == 0 | `run_only' == 2 {
    if `quiet' == 0 {
        display as text _n "Test 1.2: Custom variable name"
    }

    capture {
        use `testdata', clear
        tvweight treatment, covariates(age sex) generate(myweights) nolog
        confirm variable myweights
        assert myweights > 0
    }
    if _rc == 0 {
        display as result "  PASS: Custom variable name works"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Custom variable name (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' 1.2"
    }
}

* -----------------------------------------------------------------------------
* Test 1.3: Multiple covariates
* -----------------------------------------------------------------------------
local ++test_count
if `run_only' == 0 | `run_only' == 3 {
    if `quiet' == 0 {
        display as text _n "Test 1.3: Multiple covariates"
    }

    capture {
        use `testdata', clear
        tvweight treatment, covariates(age sex comorbidity) nolog
        confirm variable iptw
        assert iptw > 0
    }
    if _rc == 0 {
        display as result "  PASS: Multiple covariates works"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Multiple covariates (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' 1.3"
    }
}

* =============================================================================
* SECTION 2: STABILIZED WEIGHTS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 2: Stabilized Weights"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 2.1: Stabilized weights
* -----------------------------------------------------------------------------
local ++test_count
if `run_only' == 0 | `run_only' == 4 {
    if `quiet' == 0 {
        display as text _n "Test 2.1: Stabilized weights"
    }

    capture {
        use `testdata', clear
        tvweight treatment, covariates(age sex) stabilized nolog
        confirm variable iptw
        assert iptw > 0
        * Stabilized weights should have mean closer to 1
        sum iptw
        assert abs(r(mean) - 1) < 0.5
    }
    if _rc == 0 {
        display as result "  PASS: Stabilized weights works"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Stabilized weights (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' 2.1"
    }
}

* =============================================================================
* SECTION 3: TRUNCATION
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 3: Truncation"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 3.1: Truncation at percentiles
* -----------------------------------------------------------------------------
local ++test_count
if `run_only' == 0 | `run_only' == 5 {
    if `quiet' == 0 {
        display as text _n "Test 3.1: Truncation at percentiles"
    }

    capture {
        use `testdata', clear
        tvweight treatment, covariates(age sex) truncate(1 99) nolog
        confirm variable iptw
        assert iptw > 0
        * Verify truncation was applied
        assert r(n_truncated) != .
    }
    if _rc == 0 {
        display as result "  PASS: Truncation works"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Truncation (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' 3.1"
    }
}

* -----------------------------------------------------------------------------
* Test 3.2: Truncation with stabilized
* -----------------------------------------------------------------------------
local ++test_count
if `run_only' == 0 | `run_only' == 6 {
    if `quiet' == 0 {
        display as text _n "Test 3.2: Truncation with stabilized"
    }

    capture {
        use `testdata', clear
        tvweight treatment, covariates(age sex) stabilized truncate(5 95) nolog
        confirm variable iptw
        assert iptw > 0
    }
    if _rc == 0 {
        display as result "  PASS: Truncation with stabilized works"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Truncation with stabilized (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' 3.2"
    }
}

* =============================================================================
* SECTION 4: MULTINOMIAL TREATMENT
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 4: Multinomial Treatment"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 4.1: Multinomial treatment (3 levels)
* -----------------------------------------------------------------------------
local ++test_count
if `run_only' == 0 | `run_only' == 7 {
    if `quiet' == 0 {
        display as text _n "Test 4.1: Multinomial treatment"
    }

    capture {
        use `testdata_cat', clear
        tvweight drug_type, covariates(age sex) model(mlogit) nolog
        confirm variable iptw
        assert iptw > 0
        assert r(n_levels) == 3
    }
    if _rc == 0 {
        display as result "  PASS: Multinomial treatment works"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Multinomial treatment (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' 4.1"
    }
}

* =============================================================================
* SECTION 5: DENOMINATOR OUTPUT
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 5: Denominator Output"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 5.1: Propensity score output
* -----------------------------------------------------------------------------
local ++test_count
if `run_only' == 0 | `run_only' == 8 {
    if `quiet' == 0 {
        display as text _n "Test 5.1: Propensity score output"
    }

    capture {
        use `testdata', clear
        tvweight treatment, covariates(age sex) denominator(ps) nolog
        confirm variable iptw
        confirm variable ps
        * PS should be between 0 and 1
        assert ps > 0 & ps < 1
    }
    if _rc == 0 {
        display as result "  PASS: Propensity score output works"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Propensity score output (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' 5.1"
    }
}

* =============================================================================
* SECTION 6: REPLACE OPTION
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 6: Replace Option"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 6.1: Replace existing variable
* -----------------------------------------------------------------------------
local ++test_count
if `run_only' == 0 | `run_only' == 9 {
    if `quiet' == 0 {
        display as text _n "Test 6.1: Replace existing variable"
    }

    capture {
        use `testdata', clear
        tvweight treatment, covariates(age) nolog
        * Run again with replace
        tvweight treatment, covariates(age sex) replace nolog
        confirm variable iptw
    }
    if _rc == 0 {
        display as result "  PASS: Replace option works"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Replace option (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' 6.1"
    }
}

* -----------------------------------------------------------------------------
* Test 6.2: Error without replace when variable exists
* -----------------------------------------------------------------------------
local ++test_count
if `run_only' == 0 | `run_only' == 10 {
    if `quiet' == 0 {
        display as text _n "Test 6.2: Error without replace"
    }

    capture {
        use `testdata', clear
        tvweight treatment, covariates(age) nolog
        * Should fail without replace
        capture tvweight treatment, covariates(age sex) nolog
        assert _rc == 110
    }
    if _rc == 0 {
        display as result "  PASS: Error without replace works"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Error without replace (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' 6.2"
    }
}

* =============================================================================
* SECTION 7: ERROR HANDLING
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 7: Error Handling"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 7.1: Missing covariates option
* -----------------------------------------------------------------------------
local ++test_count
if `run_only' == 0 | `run_only' == 11 {
    if `quiet' == 0 {
        display as text _n "Test 7.1: Missing covariates option"
    }

    capture {
        use `testdata', clear
        capture tvweight treatment
        assert _rc != 0
    }
    if _rc == 0 {
        display as result "  PASS: Missing covariates produces error"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Missing covariates not caught"
        local ++fail_count
        local failed_tests "`failed_tests' 7.1"
    }
}

* -----------------------------------------------------------------------------
* Test 7.2: Invalid truncation values
* -----------------------------------------------------------------------------
local ++test_count
if `run_only' == 0 | `run_only' == 12 {
    if `quiet' == 0 {
        display as text _n "Test 7.2: Invalid truncation values"
    }

    capture {
        use `testdata', clear
        capture tvweight treatment, covariates(age) truncate(99 1)
        assert _rc == 198
    }
    if _rc == 0 {
        display as result "  PASS: Invalid truncation produces error"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Invalid truncation not caught"
        local ++fail_count
        local failed_tests "`failed_tests' 7.2"
    }
}

* -----------------------------------------------------------------------------
* Test 7.3: Constant exposure (1 level)
* -----------------------------------------------------------------------------
local ++test_count
if `run_only' == 0 | `run_only' == 13 {
    if `quiet' == 0 {
        display as text _n "Test 7.3: Constant exposure"
    }

    capture {
        use `testdata', clear
        replace treatment = 1
        capture tvweight treatment, covariates(age) nolog
        assert _rc == 198
    }
    if _rc == 0 {
        display as result "  PASS: Constant exposure produces error"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Constant exposure not caught"
        local ++fail_count
        local failed_tests "`failed_tests' 7.3"
    }
}

* =============================================================================
* SECTION 8: RETURN VALUES
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 8: Return Values"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 8.1: All return values present
* -----------------------------------------------------------------------------
local ++test_count
if `run_only' == 0 | `run_only' == 14 {
    if `quiet' == 0 {
        display as text _n "Test 8.1: Return values"
    }

    capture {
        use `testdata', clear
        tvweight treatment, covariates(age sex) nolog
        * Check all expected return values
        assert r(N) > 0
        assert r(n_levels) == 2
        assert r(ess) > 0
        assert r(ess_pct) > 0 & r(ess_pct) <= 100
        assert r(w_mean) > 0
        assert r(w_sd) >= 0
        assert r(w_min) > 0
        assert r(w_max) > 0
        assert r(w_p50) > 0
        assert "`r(exposure)'" == "treatment"
        assert "`r(model)'" == "logit"
        assert "`r(generate)'" == "iptw"
    }
    if _rc == 0 {
        display as result "  PASS: All return values present"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Return values (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' 8.1"
    }
}

* =============================================================================
* SUMMARY
* =============================================================================
display as text _n "{hline 70}"
display as text "TVWEIGHT TEST SUMMARY"
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
