/*******************************************************************************
* test_consort_edge_cases.do
*
* Purpose: Additional edge case tests for consort command to ensure robustness.
*
* Tests:
*   - Path with spaces
*   - Very large numbers (millions)
*   - PDF output format
*   - Math verification with known dataset
*   - State persistence verification
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
global FIGURES_DIR "${TESTING_DIR}/figures"

* Install package
capture net uninstall consort
quietly net install consort, from("${STATA_TOOLS_PATH}/consort")

display as text _n "{hline 70}"
display as text "CONSORT EDGE CASE TESTING"
display as text "{hline 70}"

* =============================================================================
* HELPER: Clear consort state
* =============================================================================
capture program drop _clear_consort_state
program define _clear_consort_state
    capture consort clear, quiet
    global CONSORT_FILE ""
    global CONSORT_N ""
    global CONSORT_ACTIVE ""
    global CONSORT_STEPS ""
    global CONSORT_TEMPFILE ""
    global CONSORT_SCRIPT_PATH ""
end

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

* =============================================================================
* TEST 1: Path with spaces
* =============================================================================
local ++test_count
display as text _n "Test `test_count': Path with spaces"

capture {
    _clear_consort_state
    capture mkdir "${FIGURES_DIR}/path with spaces"

    sysuse auto, clear
    consort init, initial("All vehicles")
    consort exclude if rep78 == ., label("Missing repair")
    consort save, output("${FIGURES_DIR}/path with spaces/test_spaces.png") final("Final")

    * Verify file exists
    capture confirm file "${FIGURES_DIR}/path with spaces/test_spaces.png"
    assert _rc == 0
}
if _rc == 0 {
    display as result "  PASSED: Path with spaces works"
    local ++pass_count
}
else {
    display as error "  FAILED: Path with spaces (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}
_clear_consort_state

* =============================================================================
* TEST 2: Very large numbers (millions)
* =============================================================================
local ++test_count
display as text _n "Test `test_count': Very large numbers (1 million observations)"

capture {
    _clear_consort_state
    clear
    set obs 1000000  // 1 million
    gen id = _n
    gen flag1 = (_n <= 50000)       // 50,000
    gen flag2 = (_n > 950000)        // 50,000

    consort init, initial("One million records")
    assert r(N) == 1000000

    consort exclude if flag1 == 1, label("First 50K")
    assert r(n_excluded) == 50000
    assert r(n_remaining) == 950000

    consort exclude if flag2 == 1, label("Last 50K")
    assert r(n_excluded) == 50000
    assert r(n_remaining) == 900000

    consort save, output("${FIGURES_DIR}/consort/large_numbers.png") final("900K remaining")

    * Verify math
    assert _N == 900000
}
if _rc == 0 {
    display as result "  PASSED: Large numbers work correctly"
    local ++pass_count
}
else {
    display as error "  FAILED: Large numbers (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}
_clear_consort_state

* =============================================================================
* TEST 3: Math verification with deterministic dataset
* =============================================================================
local ++test_count
display as text _n "Test `test_count': Mathematical verification"

capture {
    _clear_consort_state

    * Create deterministic dataset
    clear
    set obs 1000
    gen id = _n
    gen exclude_step1 = (_n <= 100)    // Exactly 100
    gen exclude_step2 = (_n > 100 & _n <= 300)  // Exactly 200
    gen exclude_step3 = (_n > 300 & _n <= 400)  // Exactly 100

    consort init, initial("1000 subjects")
    assert r(N) == 1000

    consort exclude if exclude_step1 == 1, label("Step 1")
    assert r(n_excluded) == 100
    assert r(n_remaining) == 900

    consort exclude if exclude_step2 == 1, label("Step 2")
    assert r(n_excluded) == 200
    assert r(n_remaining) == 700

    consort exclude if exclude_step3 == 1, label("Step 3")
    assert r(n_excluded) == 100
    assert r(n_remaining) == 600

    consort save, output("${FIGURES_DIR}/consort/math_verify.png") final("Final 600")

    * Final verification
    assert _N == 600

    * Verify remaining IDs are correct (401-1000)
    sum id
    assert r(min) == 401
    assert r(max) == 1000
}
if _rc == 0 {
    display as result "  PASSED: Math verification correct"
    local ++pass_count
}
else {
    display as error "  FAILED: Math verification (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}
_clear_consort_state

* =============================================================================
* TEST 4: PDF output format
* =============================================================================
local ++test_count
display as text _n "Test `test_count': PDF output format"

capture {
    _clear_consort_state
    sysuse auto, clear
    consort init, initial("All cars")
    consort exclude if rep78 == ., label("Missing")
    consort save, output("${FIGURES_DIR}/consort/test_output.pdf") final("Final")

    capture confirm file "${FIGURES_DIR}/consort/test_output.pdf"
    assert _rc == 0
}
if _rc == 0 {
    display as result "  PASSED: PDF output works"
    local ++pass_count
}
else {
    display as error "  FAILED: PDF output (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}
_clear_consort_state

* =============================================================================
* TEST 5: SVG output format
* =============================================================================
local ++test_count
display as text _n "Test `test_count': SVG output format"

capture {
    _clear_consort_state
    sysuse auto, clear
    consort init, initial("All cars")
    consort exclude if rep78 == ., label("Missing")
    consort save, output("${FIGURES_DIR}/consort/test_output.svg") final("Final")

    capture confirm file "${FIGURES_DIR}/consort/test_output.svg"
    assert _rc == 0
}
if _rc == 0 {
    display as result "  PASSED: SVG output works"
    local ++pass_count
}
else {
    display as error "  FAILED: SVG output (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}
_clear_consort_state

* =============================================================================
* TEST 6: State isolation (clear properly resets)
* =============================================================================
local ++test_count
display as text _n "Test `test_count': State isolation after clear"

capture {
    _clear_consort_state
    sysuse auto, clear

    * First diagram
    consort init, initial("First diagram")
    consort exclude if rep78 == ., label("Missing")
    * After exclusion, we have 69 obs
    local n_after_exclude = _N
    consort clear

    * Verify state is cleared
    assert "${CONSORT_ACTIVE}" == ""
    assert "${CONSORT_N}" == ""
    assert "${CONSORT_STEPS}" == ""

    * Load fresh data for second diagram
    sysuse auto, clear

    * Second diagram should work independently
    consort init, initial("Second diagram")
    assert "${CONSORT_ACTIVE}" == "1"
    assert "${CONSORT_N}" == "74"
    assert "${CONSORT_STEPS}" == "0"

    consort exclude if foreign == 1, label("Foreign")
    assert ${CONSORT_STEPS} == 1
}
if _rc == 0 {
    display as result "  PASSED: State isolation works"
    local ++pass_count
}
else {
    display as error "  FAILED: State isolation (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}
_clear_consort_state

* =============================================================================
* TEST 7: Repeated exclusions on same variable
* =============================================================================
local ++test_count
display as text _n "Test `test_count': Sequential exclusions on related conditions"

capture {
    _clear_consort_state
    sysuse auto, clear
    consort init, initial("All cars")

    * Exclude based on price thresholds
    consort exclude if price < 4000, label("Price < 4000")
    local after1 = r(n_remaining)

    consort exclude if price < 5000, label("Price < 5000")
    local after2 = r(n_remaining)

    consort exclude if price < 6000, label("Price < 6000")
    local after3 = r(n_remaining)

    * Verify monotonic decrease
    assert `after1' >= `after2'
    assert `after2' >= `after3'
    assert ${CONSORT_STEPS} == 3

    consort save, output("${FIGURES_DIR}/consort/sequential_price.png") final("Remaining")
}
if _rc == 0 {
    display as result "  PASSED: Sequential related exclusions work"
    local ++pass_count
}
else {
    display as error "  FAILED: Sequential exclusions (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}
_clear_consort_state

* =============================================================================
* TEST 8: Exclusion that removes ALL remaining observations
* =============================================================================
local ++test_count
display as text _n "Test `test_count': Exclusion removing all remaining obs"

capture {
    _clear_consort_state
    clear
    set obs 10
    gen id = _n
    gen flag = 1  // All have flag=1

    consort init, initial("10 subjects")

    * Exclude first 5
    consort exclude if id <= 5, label("First 5")
    assert r(n_remaining) == 5

    * This should exclude all remaining - interesting edge case
    * Note: This leaves 0 observations, which is valid
    consort exclude if flag == 1, label("All flagged")
    assert r(n_excluded) == 5
    assert r(n_remaining) == 0
    assert _N == 0
}
if _rc == 0 {
    display as result "  PASSED: Exclusion to zero observations handled"
    local ++pass_count
}
else {
    display as error "  FAILED: Exclusion to zero (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}
_clear_consort_state

* =============================================================================
* CLEANUP
* =============================================================================
capture erase "${FIGURES_DIR}/path with spaces/test_spaces.png"
capture rmdir "${FIGURES_DIR}/path with spaces"
capture erase "${FIGURES_DIR}/consort/large_numbers.png"
capture erase "${FIGURES_DIR}/consort/math_verify.png"
capture erase "${FIGURES_DIR}/consort/test_output.pdf"
capture erase "${FIGURES_DIR}/consort/test_output.svg"
capture erase "${FIGURES_DIR}/consort/sequential_price.png"

* =============================================================================
* SUMMARY
* =============================================================================
display as text _n "{hline 70}"
display as text "EDGE CASE TEST SUMMARY"
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
    display as error _n "Some edge case tests FAILED."
    exit 1
}
else {
    display as result _n "ALL EDGE CASE TESTS PASSED!"
}

display as text _n "Edge case testing completed: `c(current_date)' `c(current_time)'"
display as text "{hline 70}"
