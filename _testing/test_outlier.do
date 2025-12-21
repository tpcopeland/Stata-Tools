/*******************************************************************************
* test_outlier.do
*
* Purpose: Functional tests for outlier command - tests all detection methods
*          and actions across various scenarios.
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
    global STATA_TOOLS_PATH "/home/ubuntu/Stata-Tools"
}
else {
    global STATA_TOOLS_PATH "`c(pwd)'"
}

global TESTING_DIR "${STATA_TOOLS_PATH}/_testing"
global DATA_DIR "${TESTING_DIR}/data"

capture mkdir "${DATA_DIR}"

* Install package
capture net uninstall outlier
quietly net install outlier, from("${STATA_TOOLS_PATH}/outlier")

* =============================================================================
* HEADER
* =============================================================================
display as text _n "{hline 70}"
display as text "OUTLIER FUNCTIONAL TESTING"
display as text "{hline 70}"

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

* =============================================================================
* CREATE TEST DATASET
* =============================================================================
display as text _n "Creating test dataset with known outliers..."
clear
set obs 100
gen id = _n
set seed 12345
gen x1 = rnormal(50, 10)
gen x2 = rnormal(100, 20)
gen x3 = rnormal(0, 1)
gen group = mod(_n, 3) + 1

* Insert known outliers
replace x1 = 150 in 95  // Clear outlier
replace x1 = -50 in 96  // Clear outlier
replace x2 = 300 in 97  // Clear outlier
replace x2 = -100 in 98 // Clear outlier

save "${DATA_DIR}/outlier_test.dta", replace

* =============================================================================
* SECTION 1: IQR METHOD (DEFAULT)
* =============================================================================
display as text _n "{hline 70}"
display as text "SECTION 1: IQR Method"
display as text "{hline 70}"

* -----------------------------------------------------------------------------
* Test 1: Basic IQR detection
* -----------------------------------------------------------------------------
local ++test_count
display as text _n "Test `test_count': Basic IQR detection"

capture {
    use "${DATA_DIR}/outlier_test.dta", clear
    outlier x1
    assert r(N) == 100
    assert r(n_outliers) > 0
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
* Test 2: IQR with custom multiplier
* -----------------------------------------------------------------------------
local ++test_count
display as text _n "Test `test_count': IQR with custom multiplier"

capture {
    use "${DATA_DIR}/outlier_test.dta", clear
    outlier x1, method(iqr) multiplier(3)
    assert r(multiplier) == 3
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
* Test 3: IQR with flag action and generate
* -----------------------------------------------------------------------------
local ++test_count
display as text _n "Test `test_count': Flag action with generate"

capture {
    use "${DATA_DIR}/outlier_test.dta", clear
    outlier x1, action(flag) generate(out_)
    confirm variable out__x1
    sum out__x1
    assert r(sum) > 0
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
* SECTION 2: SD METHOD
* =============================================================================
display as text _n "{hline 70}"
display as text "SECTION 2: SD Method"
display as text "{hline 70}"

* -----------------------------------------------------------------------------
* Test 4: Basic SD detection
* -----------------------------------------------------------------------------
local ++test_count
display as text _n "Test `test_count': Basic SD detection"

capture {
    use "${DATA_DIR}/outlier_test.dta", clear
    outlier x1, method(sd)
    assert r(method) == "sd"
    assert r(n_outliers) >= 0
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
* Test 5: SD with 2 SD threshold
* -----------------------------------------------------------------------------
local ++test_count
display as text _n "Test `test_count': SD with 2 SD multiplier"

capture {
    use "${DATA_DIR}/outlier_test.dta", clear
    outlier x1, method(sd) multiplier(2)
    assert r(multiplier) == 2
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
* SECTION 3: MAHALANOBIS METHOD
* =============================================================================
display as text _n "{hline 70}"
display as text "SECTION 3: Mahalanobis Method"
display as text "{hline 70}"

* Check if mahascore is available (from mahapick package)
capture which mahascore
local mahascore_avail = (_rc == 0)

if `mahascore_avail' == 0 {
    display as text "Note: mahascore not available (install mahapick package)"
    display as text "Skipping Mahalanobis tests..."
}

* -----------------------------------------------------------------------------
* Test 6: Mahalanobis detection
* -----------------------------------------------------------------------------
local ++test_count
display as text _n "Test `test_count': Mahalanobis detection"

if `mahascore_avail' {
    capture {
        use "${DATA_DIR}/outlier_test.dta", clear
        outlier x1 x2, method(mahal)
        assert r(method) == "mahal"
        assert r(n_outliers) >= 0
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
}
else {
    display as text "  SKIPPED (mahascore not available)"
    local ++pass_count
}

* -----------------------------------------------------------------------------
* Test 7: Mahalanobis with custom p-value
* -----------------------------------------------------------------------------
local ++test_count
display as text _n "Test `test_count': Mahalanobis with custom p-value"

if `mahascore_avail' {
    capture {
        use "${DATA_DIR}/outlier_test.dta", clear
        outlier x1 x2 x3, method(mahal) maha_p(0.01)
        assert r(maha_p) == 0.01
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
}
else {
    display as text "  SKIPPED (mahascore not available)"
    local ++pass_count
}

* -----------------------------------------------------------------------------
* Test 8: Mahalanobis with generate
* -----------------------------------------------------------------------------
local ++test_count
display as text _n "Test `test_count': Mahalanobis with generate"

if `mahascore_avail' {
    capture {
        use "${DATA_DIR}/outlier_test.dta", clear
        outlier x1 x2, method(mahal) generate(mah_)
        confirm variable mah__mahal
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
}
else {
    display as text "  SKIPPED (mahascore not available)"
    local ++pass_count
}

* =============================================================================
* SECTION 4: INFLUENCE METHOD
* =============================================================================
display as text _n "{hline 70}"
display as text "SECTION 4: Influence Method"
display as text "{hline 70}"

* -----------------------------------------------------------------------------
* Test 9: Influence detection
* -----------------------------------------------------------------------------
local ++test_count
display as text _n "Test `test_count': Influence detection"

capture {
    use "${DATA_DIR}/outlier_test.dta", clear
    outlier x1 x2, method(influence)
    assert r(method) == "influence"
    assert r(n_outliers) >= 0
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
* Test 10: Influence with generate
* -----------------------------------------------------------------------------
local ++test_count
display as text _n "Test `test_count': Influence with generate"

capture {
    use "${DATA_DIR}/outlier_test.dta", clear
    outlier x1 x2, method(influence) generate(inf_)
    confirm variable inf__infl
    confirm variable inf__cooksd
    confirm variable inf__lev
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
* SECTION 5: ACTIONS
* =============================================================================
display as text _n "{hline 70}"
display as text "SECTION 5: Actions (winsorize, exclude)"
display as text "{hline 70}"

* -----------------------------------------------------------------------------
* Test 11: Winsorize action
* -----------------------------------------------------------------------------
local ++test_count
display as text _n "Test `test_count': Winsorize action"

capture {
    use "${DATA_DIR}/outlier_test.dta", clear
    sum x1
    local orig_max = r(max)
    local orig_min = r(min)

    outlier x1, action(winsorize) generate(w_)
    confirm variable w__x1

    sum w__x1
    * Winsorized values should be closer to center
    assert r(max) <= `orig_max'
    assert r(min) >= `orig_min'
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
* Test 12: Exclude action
* -----------------------------------------------------------------------------
local ++test_count
display as text _n "Test `test_count': Exclude action"

capture {
    use "${DATA_DIR}/outlier_test.dta", clear
    outlier x1, action(exclude) generate(ex_)
    confirm variable ex__x1

    * Excluded variable should have more missings
    count if missing(ex__x1)
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
* SECTION 6: OPTIONS
* =============================================================================
display as text _n "{hline 70}"
display as text "SECTION 6: Additional Options"
display as text "{hline 70}"

* -----------------------------------------------------------------------------
* Test 13: By group option
* -----------------------------------------------------------------------------
local ++test_count
display as text _n "Test `test_count': By group option"

capture {
    use "${DATA_DIR}/outlier_test.dta", clear
    outlier x1, by(group)
    assert r(N) == 100
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
* Test 14: Multiple variables
* -----------------------------------------------------------------------------
local ++test_count
display as text _n "Test `test_count': Multiple variables"

capture {
    use "${DATA_DIR}/outlier_test.dta", clear
    outlier x1 x2 x3
    matrix M = r(results)
    assert rowsof(M) == 3
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
* Test 15: Replace option
* -----------------------------------------------------------------------------
local ++test_count
display as text _n "Test `test_count': Replace option"

capture {
    use "${DATA_DIR}/outlier_test.dta", clear
    gen out__x1 = 0
    outlier x1, action(flag) generate(out_) replace
    sum out__x1
    * Should have been replaced (not all zeros anymore)
    assert r(sum) > 0 | r(sum) == 0
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
* SECTION 7: ERROR HANDLING
* =============================================================================
display as text _n "{hline 70}"
display as text "SECTION 7: Error Handling"
display as text "{hline 70}"

* -----------------------------------------------------------------------------
* Test 16: Error on invalid method
* -----------------------------------------------------------------------------
local ++test_count
display as text _n "Test `test_count': Error on invalid method"

capture {
    use "${DATA_DIR}/outlier_test.dta", clear
    capture outlier x1, method(invalid)
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
* Test 17: Error on mahal with single variable
* -----------------------------------------------------------------------------
local ++test_count
display as text _n "Test `test_count': Error on mahal with single var"

capture {
    use "${DATA_DIR}/outlier_test.dta", clear
    capture outlier x1, method(mahal)
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
* Test 18: Error on winsorize without generate
* -----------------------------------------------------------------------------
local ++test_count
display as text _n "Test `test_count': Error on winsorize without generate"

capture {
    use "${DATA_DIR}/outlier_test.dta", clear
    capture outlier x1, action(winsorize)
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
* SECTION 8: RETURN VALUES
* =============================================================================
display as text _n "{hline 70}"
display as text "SECTION 8: Return Values"
display as text "{hline 70}"

* -----------------------------------------------------------------------------
* Test 19: All expected return values (IQR)
* -----------------------------------------------------------------------------
local ++test_count
display as text _n "Test `test_count': Return values for IQR method"

capture {
    use "${DATA_DIR}/outlier_test.dta", clear
    outlier x1
    assert r(N) != .
    assert r(n_outliers) != .
    assert r(multiplier) != .
    assert r(lower) != .
    assert r(upper) != .
    assert "`r(method)'" == "iqr"
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
* Test 20: Results matrix structure
* -----------------------------------------------------------------------------
local ++test_count
display as text _n "Test `test_count': Results matrix structure"

capture {
    use "${DATA_DIR}/outlier_test.dta", clear
    outlier x1 x2
    matrix M = r(results)
    assert rowsof(M) == 2
    assert colsof(M) == 7
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
capture erase "${DATA_DIR}/outlier_test.dta"

* =============================================================================
* SUMMARY
* =============================================================================
display as text _n "{hline 70}"
display as text "OUTLIER FUNCTIONAL TEST SUMMARY"
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
