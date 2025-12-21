/*******************************************************************************
* test_validate.do
*
* Purpose: Functional tests for validate command - tests all validation rules
*          and options across various scenarios.
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
capture net uninstall validate
quietly net install validate, from("${STATA_TOOLS_PATH}/validate")

* =============================================================================
* HEADER
* =============================================================================
display as text _n "{hline 70}"
display as text "VALIDATE FUNCTIONAL TESTING"
display as text "{hline 70}"

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

* =============================================================================
* CREATE TEST DATASET
* =============================================================================
display as text _n "Creating test dataset..."
clear
set obs 100
gen id = _n
gen age = 20 + int(60*runiform())
replace age = -5 in 95      // Invalid age
replace age = 150 in 96     // Invalid age
replace age = . in 97       // Missing

gen sex = cond(runiform() > 0.5, 1, 0)
replace sex = 2 in 98       // Invalid sex

gen patient_id = "P" + string(100000 + _n, "%06.0f")
replace patient_id = "INVALID" in 99  // Invalid pattern

gen start_date = date("2020-01-01", "YMD") + int(365*runiform())
gen end_date = start_date + int(100*runiform())
replace end_date = start_date - 10 in 100  // end < start

format start_date end_date %td
save "${DATA_DIR}/validate_test.dta", replace

* =============================================================================
* SECTION 1: BASIC VALIDATIONS
* =============================================================================
display as text _n "{hline 70}"
display as text "SECTION 1: Basic Validations"
display as text "{hline 70}"

* -----------------------------------------------------------------------------
* Test 1: Basic execution
* -----------------------------------------------------------------------------
local ++test_count
display as text _n "Test `test_count': Basic execution"

capture {
    use "${DATA_DIR}/validate_test.dta", clear
    validate age
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
* Test 2: Range validation
* -----------------------------------------------------------------------------
local ++test_count
display as text _n "Test `test_count': Range validation"

capture {
    use "${DATA_DIR}/validate_test.dta", clear
    validate age, range(0 120)
    assert r(rules_failed) > 0  // Should fail (age=-5 and age=150)
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
* Test 3: No missing validation
* -----------------------------------------------------------------------------
local ++test_count
display as text _n "Test `test_count': No missing validation"

capture {
    use "${DATA_DIR}/validate_test.dta", clear
    validate age, nomiss
    assert r(rules_failed) > 0  // Should fail (age has missing)
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
* Test 4: Values validation (numeric)
* -----------------------------------------------------------------------------
local ++test_count
display as text _n "Test `test_count': Values validation (numeric)"

capture {
    use "${DATA_DIR}/validate_test.dta", clear
    validate sex, values(0 1)
    assert r(rules_failed) > 0  // Should fail (sex=2 exists)
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
* Test 5: Pattern validation
* -----------------------------------------------------------------------------
local ++test_count
display as text _n "Test `test_count': Pattern validation"

capture {
    use "${DATA_DIR}/validate_test.dta", clear
    validate patient_id, pattern("^P[0-9]{6}$")
    assert r(rules_failed) > 0  // Should fail (INVALID doesn't match)
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
* Test 6: Unique validation
* -----------------------------------------------------------------------------
local ++test_count
display as text _n "Test `test_count': Unique validation"

capture {
    use "${DATA_DIR}/validate_test.dta", clear
    validate id, unique
    assert r(rules_passed) > 0  // Should pass (id is unique)
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
* Test 7: Type validation
* -----------------------------------------------------------------------------
local ++test_count
display as text _n "Test `test_count': Type validation"

capture {
    use "${DATA_DIR}/validate_test.dta", clear
    validate age, type(numeric)
    assert r(rules_passed) > 0
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
* SECTION 2: CROSS-VARIABLE VALIDATION
* =============================================================================
display as text _n "{hline 70}"
display as text "SECTION 2: Cross-Variable Validation"
display as text "{hline 70}"

* -----------------------------------------------------------------------------
* Test 8: Cross-variable check
* -----------------------------------------------------------------------------
local ++test_count
display as text _n "Test `test_count': Cross-variable validation"

capture {
    use "${DATA_DIR}/validate_test.dta", clear
    validate start_date end_date, cross(start_date <= end_date)
    assert r(rules_failed) > 0  // Should fail (one end < start)
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
* SECTION 3: OPTIONS
* =============================================================================
display as text _n "{hline 70}"
display as text "SECTION 3: Options"
display as text "{hline 70}"

* -----------------------------------------------------------------------------
* Test 9: Generate validation indicator
* -----------------------------------------------------------------------------
local ++test_count
display as text _n "Test `test_count': Generate validation indicator"

capture {
    use "${DATA_DIR}/validate_test.dta", clear
    validate age, range(0 120) generate(valid_age)
    confirm variable valid_age
    sum valid_age
    assert r(mean) < 1  // Not all valid
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
* Test 10: Replace option
* -----------------------------------------------------------------------------
local ++test_count
display as text _n "Test `test_count': Replace option"

capture {
    use "${DATA_DIR}/validate_test.dta", clear
    gen valid_age = 0
    validate age, range(0 120) generate(valid_age) replace
    sum valid_age
    assert r(sum) > 0  // Should have some valid
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
* Test 11: Custom title
* -----------------------------------------------------------------------------
local ++test_count
display as text _n "Test `test_count': Custom title"

capture {
    use "${DATA_DIR}/validate_test.dta", clear
    validate age, range(0 120) title("Age Validation Report")
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
* Test 12: Excel export
* -----------------------------------------------------------------------------
local ++test_count
display as text _n "Test `test_count': Excel export"

capture {
    use "${DATA_DIR}/validate_test.dta", clear
    validate age sex, nomiss xlsx("${DATA_DIR}/validation_report.xlsx")
    confirm file "${DATA_DIR}/validation_report.xlsx"
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
capture erase "${DATA_DIR}/validation_report.xlsx"

* =============================================================================
* SECTION 4: RETURN VALUES
* =============================================================================
display as text _n "{hline 70}"
display as text "SECTION 4: Return Values"
display as text "{hline 70}"

* -----------------------------------------------------------------------------
* Test 13: Return scalars
* -----------------------------------------------------------------------------
local ++test_count
display as text _n "Test `test_count': Return scalars"

capture {
    use "${DATA_DIR}/validate_test.dta", clear
    validate age, range(0 120) nomiss
    assert r(N) != .
    assert r(n_rules) != .
    assert r(rules_passed) != .
    assert r(rules_failed) != .
    assert r(pct_passed) != .
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
* Test 14: Return matrix
* -----------------------------------------------------------------------------
local ++test_count
display as text _n "Test `test_count': Return matrix"

capture {
    use "${DATA_DIR}/validate_test.dta", clear
    validate age sex, nomiss
    matrix M = r(results)
    assert rowsof(M) == 2
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
* Test 15: Assert stops on failure
* -----------------------------------------------------------------------------
local ++test_count
display as text _n "Test `test_count': Assert option stops on failure"

capture {
    use "${DATA_DIR}/validate_test.dta", clear
    capture validate age, range(0 120) assert
    assert _rc == 9  // Should exit with error 9
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
* Test 16: Error on invalid xlsx extension
* -----------------------------------------------------------------------------
local ++test_count
display as text _n "Test `test_count': Error on invalid xlsx extension"

capture {
    use "${DATA_DIR}/validate_test.dta", clear
    capture validate age, nomiss xlsx("report.csv")
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
* SECTION 6: MULTIPLE RULES
* =============================================================================
display as text _n "{hline 70}"
display as text "SECTION 6: Multiple Rules"
display as text "{hline 70}"

* -----------------------------------------------------------------------------
* Test 17: Multiple rules on same variable
* -----------------------------------------------------------------------------
local ++test_count
display as text _n "Test `test_count': Multiple rules on same variable"

capture {
    use "${DATA_DIR}/validate_test.dta", clear
    validate age, range(0 120) nomiss
    assert r(n_rules) == 2
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
* Test 18: Multiple variables with same rules
* -----------------------------------------------------------------------------
local ++test_count
display as text _n "Test `test_count': Multiple variables"

capture {
    use "${DATA_DIR}/validate_test.dta", clear
    validate age sex id, nomiss
    assert r(n_rules) == 3
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
* SECTION 7: EDGE CASES
* =============================================================================
display as text _n "{hline 70}"
display as text "SECTION 7: Edge Cases"
display as text "{hline 70}"

* -----------------------------------------------------------------------------
* Test 19: All passing validation
* -----------------------------------------------------------------------------
local ++test_count
display as text _n "Test `test_count': All passing validation"

capture {
    use "${DATA_DIR}/validate_test.dta", clear
    validate id, unique  // id should be unique
    assert r(rules_failed) == 0
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
* Test 20: With if condition
* -----------------------------------------------------------------------------
local ++test_count
display as text _n "Test `test_count': With if condition"

capture {
    use "${DATA_DIR}/validate_test.dta", clear
    validate age if id <= 90, range(0 120)  // Exclude bad records
    assert r(rules_failed) == 0  // Should pass when excluding bad records
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
capture erase "${DATA_DIR}/validate_test.dta"
capture erase "${DATA_DIR}/validation_report.xlsx"

* =============================================================================
* SUMMARY
* =============================================================================
display as text _n "{hline 70}"
display as text "VALIDATE FUNCTIONAL TEST SUMMARY"
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
