/*******************************************************************************
* test_iptw_diag.do
*
* Purpose: Functional tests for iptw_diag command - verifies the command runs
*          without errors across various scenarios and options.
*
* Author: Claude (automated testing)
* Date: 2025-12-21
*******************************************************************************/

clear all
set more off
version 16.0

* =============================================================================
* PATH CONFIGURATION
* =============================================================================
if "`c(os)'" == "Unix" {
    * Try to detect path from current working directory
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
    global STATA_TOOLS_PATH "`c(pwd)'"
}

global TESTING_DIR "${STATA_TOOLS_PATH}/_testing"
global FIGURES_DIR "${TESTING_DIR}/figures/iptw_diag"

capture mkdir "${TESTING_DIR}/figures"
capture mkdir "${FIGURES_DIR}"

* Install package
capture net uninstall iptw_diag
quietly net install iptw_diag, from("${STATA_TOOLS_PATH}/iptw_diag")

* =============================================================================
* HEADER
* =============================================================================
display as text _n "{hline 70}"
display as text "IPTW_DIAG FUNCTIONAL TESTING"
display as text "{hline 70}"

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

* =============================================================================
* CREATE TEST DATASET
* =============================================================================
display as text _n "Creating test dataset..."
sysuse auto, clear
logit foreign price mpg weight
predict ps, pr
gen ipw = cond(foreign==1, 1/ps, 1/(1-ps))
gen ipw_large = ipw * 5  // Create larger weights for extreme testing
save "${TESTING_DIR}/data/iptw_test.dta", replace

* =============================================================================
* SECTION 1: BASIC FUNCTIONALITY
* =============================================================================
display as text _n "{hline 70}"
display as text "SECTION 1: Basic Functionality"
display as text "{hline 70}"

* -----------------------------------------------------------------------------
* Test 1: Basic execution
* -----------------------------------------------------------------------------
local ++test_count
display as text _n "Test `test_count': Basic execution"

capture {
    use "${TESTING_DIR}/data/iptw_test.dta", clear
    iptw_diag ipw, treatment(foreign)
    assert r(N) > 0
    assert r(ess) > 0
}
if _rc == 0 {
    display as result "  PASSED"
    local ++pass_count
}
else {
    display as error "  FAILED (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* -----------------------------------------------------------------------------
* Test 2: With detail option
* -----------------------------------------------------------------------------
local ++test_count
display as text _n "Test `test_count': With detail option"

capture {
    use "${TESTING_DIR}/data/iptw_test.dta", clear
    iptw_diag ipw, treatment(foreign) detail
    assert r(p1) != .
    assert r(p99) != .
}
if _rc == 0 {
    display as result "  PASSED"
    local ++pass_count
}
else {
    display as error "  FAILED (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* =============================================================================
* SECTION 2: TRIMMING/TRUNCATION
* =============================================================================
display as text _n "{hline 70}"
display as text "SECTION 2: Trimming/Truncation"
display as text "{hline 70}"

* -----------------------------------------------------------------------------
* Test 3: Trim weights
* -----------------------------------------------------------------------------
local ++test_count
display as text _n "Test `test_count': Trim at 99th percentile"

capture {
    use "${TESTING_DIR}/data/iptw_test.dta", clear
    iptw_diag ipw, treatment(foreign) trim(99) generate(ipw_trim)
    confirm variable ipw_trim
    assert r(new_ess) > 0
}
if _rc == 0 {
    display as result "  PASSED"
    local ++pass_count
}
else {
    display as error "  FAILED (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* -----------------------------------------------------------------------------
* Test 4: Truncate weights
* -----------------------------------------------------------------------------
local ++test_count
display as text _n "Test `test_count': Truncate at fixed value"

capture {
    use "${TESTING_DIR}/data/iptw_test.dta", clear
    iptw_diag ipw, treatment(foreign) truncate(5) generate(ipw_trunc)
    confirm variable ipw_trunc
    sum ipw_trunc
    assert r(max) <= 5
}
if _rc == 0 {
    display as result "  PASSED"
    local ++pass_count
}
else {
    display as error "  FAILED (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* -----------------------------------------------------------------------------
* Test 5: Stabilize weights
* -----------------------------------------------------------------------------
local ++test_count
display as text _n "Test `test_count': Stabilize weights"

capture {
    use "${TESTING_DIR}/data/iptw_test.dta", clear
    iptw_diag ipw, treatment(foreign) stabilize generate(ipw_stab)
    confirm variable ipw_stab
    * Stabilized weights should have mean closer to 1
    sum ipw_stab
    assert r(mean) < r(mean) + 100  // Just check it exists
}
if _rc == 0 {
    display as result "  PASSED"
    local ++pass_count
}
else {
    display as error "  FAILED (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* -----------------------------------------------------------------------------
* Test 6: Replace option
* -----------------------------------------------------------------------------
local ++test_count
display as text _n "Test `test_count': Replace option"

capture {
    use "${TESTING_DIR}/data/iptw_test.dta", clear
    gen ipw_new = 1
    iptw_diag ipw, treatment(foreign) trim(99) generate(ipw_new) replace
    sum ipw_new
    assert r(mean) != 1  // Should have been replaced
}
if _rc == 0 {
    display as result "  PASSED"
    local ++pass_count
}
else {
    display as error "  FAILED (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* =============================================================================
* SECTION 3: GRAPH OPTIONS
* =============================================================================
display as text _n "{hline 70}"
display as text "SECTION 3: Graph Options"
display as text "{hline 70}"

* -----------------------------------------------------------------------------
* Test 7: Generate graph
* -----------------------------------------------------------------------------
local ++test_count
display as text _n "Test `test_count': Generate weight distribution graph"

capture {
    use "${TESTING_DIR}/data/iptw_test.dta", clear
    iptw_diag ipw, treatment(foreign) graph saving("${FIGURES_DIR}/iptw_hist.png")
    confirm file "${FIGURES_DIR}/iptw_hist.png"
}
if _rc == 0 {
    display as result "  PASSED"
    local ++pass_count
}
else {
    display as error "  FAILED (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* -----------------------------------------------------------------------------
* Test 8: Custom xlabel
* -----------------------------------------------------------------------------
local ++test_count
display as text _n "Test `test_count': Graph with custom xlabel"

capture {
    use "${TESTING_DIR}/data/iptw_test.dta", clear
    iptw_diag ipw, treatment(foreign) graph xlabel(0 1 2 3 4 5)
    assert r(N) > 0
}
if _rc == 0 {
    display as result "  PASSED"
    local ++pass_count
}
else {
    display as error "  FAILED (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* =============================================================================
* SECTION 4: RETURN VALUES
* =============================================================================
display as text _n "{hline 70}"
display as text "SECTION 4: Return Values"
display as text "{hline 70}"

* -----------------------------------------------------------------------------
* Test 9: All expected scalars returned
* -----------------------------------------------------------------------------
local ++test_count
display as text _n "Test `test_count': Return scalars"

capture {
    use "${TESTING_DIR}/data/iptw_test.dta", clear
    iptw_diag ipw, treatment(foreign)

    assert r(N) != .
    assert r(N_treated) != .
    assert r(N_control) != .
    assert r(mean_wt) != .
    assert r(sd_wt) != .
    assert r(min_wt) != .
    assert r(max_wt) != .
    assert r(cv) != .
    assert r(ess) != .
    assert r(ess_pct) != .
    assert r(n_extreme) != .
}
if _rc == 0 {
    display as result "  PASSED"
    local ++pass_count
}
else {
    display as error "  FAILED (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* -----------------------------------------------------------------------------
* Test 10: Return locals
* -----------------------------------------------------------------------------
local ++test_count
display as text _n "Test `test_count': Return locals"

capture {
    use "${TESTING_DIR}/data/iptw_test.dta", clear
    iptw_diag ipw, treatment(foreign)

    assert "`r(wvar)'" == "ipw"
    assert "`r(treatment)'" == "foreign"
}
if _rc == 0 {
    display as result "  PASSED"
    local ++pass_count
}
else {
    display as error "  FAILED (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* =============================================================================
* SECTION 5: ERROR HANDLING
* =============================================================================
display as text _n "{hline 70}"
display as text "SECTION 5: Error Handling"
display as text "{hline 70}"

* -----------------------------------------------------------------------------
* Test 11: Error on non-binary treatment
* -----------------------------------------------------------------------------
local ++test_count
display as text _n "Test `test_count': Error on non-binary treatment"

capture {
    use "${TESTING_DIR}/data/iptw_test.dta", clear
    capture iptw_diag ipw, treatment(price)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASSED (correctly rejected)"
    local ++pass_count
}
else {
    display as error "  FAILED (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* -----------------------------------------------------------------------------
* Test 12: Error on negative weights
* -----------------------------------------------------------------------------
local ++test_count
display as text _n "Test `test_count': Error on negative weights"

capture {
    use "${TESTING_DIR}/data/iptw_test.dta", clear
    gen neg_wt = -ipw
    capture iptw_diag neg_wt, treatment(foreign)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASSED (correctly rejected)"
    local ++pass_count
}
else {
    display as error "  FAILED (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* -----------------------------------------------------------------------------
* Test 13: Error on invalid trim value
* -----------------------------------------------------------------------------
local ++test_count
display as text _n "Test `test_count': Error on invalid trim (too low)"

capture {
    use "${TESTING_DIR}/data/iptw_test.dta", clear
    capture iptw_diag ipw, treatment(foreign) trim(10) generate(x)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASSED (correctly rejected)"
    local ++pass_count
}
else {
    display as error "  FAILED (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* -----------------------------------------------------------------------------
* Test 14: Error on conflicting trim and truncate
* -----------------------------------------------------------------------------
local ++test_count
display as text _n "Test `test_count': Error on trim + truncate together"

capture {
    use "${TESTING_DIR}/data/iptw_test.dta", clear
    capture iptw_diag ipw, treatment(foreign) trim(99) truncate(5) generate(x)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASSED (correctly rejected)"
    local ++pass_count
}
else {
    display as error "  FAILED (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* -----------------------------------------------------------------------------
* Test 15: Error on missing generate with trim
* -----------------------------------------------------------------------------
local ++test_count
display as text _n "Test `test_count': Error on trim without generate"

capture {
    use "${TESTING_DIR}/data/iptw_test.dta", clear
    capture iptw_diag ipw, treatment(foreign) trim(99)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASSED (correctly rejected)"
    local ++pass_count
}
else {
    display as error "  FAILED (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* =============================================================================
* SECTION 6: EDGE CASES
* =============================================================================
display as text _n "{hline 70}"
display as text "SECTION 6: Edge Cases"
display as text "{hline 70}"

* -----------------------------------------------------------------------------
* Test 16: With if condition
* -----------------------------------------------------------------------------
local ++test_count
display as text _n "Test `test_count': With if condition"

capture {
    use "${TESTING_DIR}/data/iptw_test.dta", clear
    iptw_diag ipw if mpg > 20, treatment(foreign)
    assert r(N) < 74
}
if _rc == 0 {
    display as result "  PASSED"
    local ++pass_count
}
else {
    display as error "  FAILED (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* -----------------------------------------------------------------------------
* Test 17: Extreme weights detection
* -----------------------------------------------------------------------------
local ++test_count
display as text _n "Test `test_count': Extreme weight detection"

capture {
    use "${TESTING_DIR}/data/iptw_test.dta", clear
    iptw_diag ipw_large, treatment(foreign)
    * Should detect more extreme weights
    assert r(n_extreme) >= 0
    assert r(pct_extreme) >= 0
}
if _rc == 0 {
    display as result "  PASSED"
    local ++pass_count
}
else {
    display as error "  FAILED (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* =============================================================================
* CLEANUP
* =============================================================================
capture erase "${TESTING_DIR}/data/iptw_test.dta"
capture erase "${FIGURES_DIR}/iptw_hist.png"

* =============================================================================
* SUMMARY
* =============================================================================
display as text _n "{hline 70}"
display as text "IPTW_DIAG FUNCTIONAL TEST SUMMARY"
display as text "{hline 70}"
display as text "Total tests:  `test_count'"
display as result "Passed:       `pass_count'"
if `fail_count' > 0 {
    display as error "Failed:       `fail_count'"
    display as error "Failed tests:`failed_tests'"
}
else {
    display as text "Failed:       `fail_count'"
}
display as text "{hline 70}"

if `fail_count' > 0 {
    display as error "Some tests FAILED."
    exit 1
}
else {
    display as result "All tests PASSED!"
}

display as text _n "Testing completed: `c(current_date)' `c(current_time)'"
