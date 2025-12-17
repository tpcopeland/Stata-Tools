/*******************************************************************************
* validation_mvp.do
*
* Purpose: Validation tests for mvp (missing value patterns) command
*
* Author: Claude Code
* Date: 2025-12-14
*******************************************************************************/

clear all
set more off
version 16.0

* =============================================================================
* PATH CONFIGURATION
* =============================================================================
local pwd "`c(pwd)'"
if regexm("`pwd'", "_validation$") {
    local base_path ".."
}
else {
    local base_path "."
}

adopath ++ "`base_path'/mvp"

* =============================================================================
* HEADER
* =============================================================================
display as text _n "{hline 70}"
display as text "MVP VALIDATION TESTS"
display as text "{hline 70}"

local test_count = 0
local pass_count = 0
local fail_count = 0

* =============================================================================
* SECTION 1: BASIC EXECUTION
* =============================================================================
display as text _n "SECTION 1: Basic Execution" _n

* Test 1.1: Basic execution
local ++test_count
display as text "Test 1.1: Basic execution with sysuse auto"
capture {
    sysuse auto, clear
    mvp
}
if _rc == 0 {
    display as result "  PASS: mvp executes without error"
    local ++pass_count
}
else {
    display as error "  FAIL: mvp failed with error `=_rc'"
    local ++fail_count
}

* =============================================================================
* SECTION 2: RETURN VALUES
* =============================================================================
display as text _n "SECTION 2: Return Values" _n

* Test 2.1: r(N) returned
local ++test_count
display as text "Test 2.1: r(N) returned"
sysuse auto, clear
mvp
if r(N) != . & r(N) > 0 {
    display as result "  PASS: r(N) = `r(N)'"
    local ++pass_count
}
else {
    display as error "  FAIL: r(N) not returned"
    local ++fail_count
}

* Test 2.2: r(N_complete) returned
local ++test_count
display as text "Test 2.2: r(N_complete) returned"
if r(N_complete) != . {
    display as result "  PASS: r(N_complete) = `r(N_complete)'"
    local ++pass_count
}
else {
    display as error "  FAIL: r(N_complete) not returned"
    local ++fail_count
}

* Test 2.3: r(N_incomplete) returned
local ++test_count
display as text "Test 2.3: r(N_incomplete) returned"
if r(N_incomplete) != . {
    display as result "  PASS: r(N_incomplete) = `r(N_incomplete)'"
    local ++pass_count
}
else {
    display as error "  FAIL: r(N_incomplete) not returned"
    local ++fail_count
}

* Test 2.4: r(N_patterns) returned
local ++test_count
display as text "Test 2.4: r(N_patterns) returned"
if r(N_patterns) != . & r(N_patterns) >= 1 {
    display as result "  PASS: r(N_patterns) = `r(N_patterns)'"
    local ++pass_count
}
else {
    display as error "  FAIL: r(N_patterns) not returned"
    local ++fail_count
}

* =============================================================================
* SECTION 3: INVARIANT TESTS
* =============================================================================
display as text _n "SECTION 3: Invariant Tests" _n

* Test 3.1: N = N_complete + N_incomplete
local ++test_count
display as text "Test 3.1: N = N_complete + N_incomplete"
sysuse auto, clear
mvp
if r(N) == r(N_complete) + r(N_incomplete) {
    display as result "  PASS: `=r(N)' = `=r(N_complete)' + `=r(N_incomplete)'"
    local ++pass_count
}
else {
    display as error "  FAIL: Invariant violated"
    local ++fail_count
}

* =============================================================================
* SECTION 4: KNOWN-ANSWER TESTS
* =============================================================================
display as text _n "SECTION 4: Known-Answer Tests" _n

* Test 4.1: Complete data (no missing)
local ++test_count
display as text "Test 4.1: Complete data has N_incomplete = 0"
clear
set obs 10
gen x = _n
gen y = _n * 2
mvp
if r(N_incomplete) == 0 & r(N_complete) == 10 {
    display as result "  PASS: N_complete=10, N_incomplete=0"
    local ++pass_count
}
else {
    display as error "  FAIL: Expected N_complete=10, N_incomplete=0"
    local ++fail_count
}

* Test 4.2: All missing variable
local ++test_count
display as text "Test 4.2: Variable with all missing"
clear
set obs 5
gen x = _n
gen y = .
mvp y
if r(N_incomplete) == 5 & r(N_complete) == 0 {
    display as result "  PASS: All observations incomplete"
    local ++pass_count
}
else {
    display as error "  FAIL: Expected all incomplete"
    local ++fail_count
}

* =============================================================================
* SECTION 5: OPTIONS
* =============================================================================
display as text _n "SECTION 5: Options" _n

* Test 5.1: percent option
local ++test_count
display as text "Test 5.1: percent option"
capture {
    sysuse auto, clear
    mvp, percent
}
if _rc == 0 {
    display as result "  PASS: percent option accepted"
    local ++pass_count
}
else {
    display as error "  FAIL: percent option failed"
    local ++fail_count
}

* Test 5.2: notable option
local ++test_count
display as text "Test 5.2: notable option"
capture {
    sysuse auto, clear
    mvp, notable
}
if _rc == 0 {
    display as result "  PASS: notable option accepted"
    local ++pass_count
}
else {
    display as error "  FAIL: notable option failed"
    local ++fail_count
}

* Test 5.3: nosummary option
local ++test_count
display as text "Test 5.3: nosummary option"
capture {
    sysuse auto, clear
    mvp, nosummary
}
if _rc == 0 {
    display as result "  PASS: nosummary option accepted"
    local ++pass_count
}
else {
    display as error "  FAIL: nosummary option failed"
    local ++fail_count
}

* =============================================================================
* SUMMARY
* =============================================================================
display as text _n "{hline 70}"
display as text "MVP VALIDATION SUMMARY"
display as text "{hline 70}"
display as text "Total tests:  `test_count'"
display as result "Passed:       `pass_count'"
if `fail_count' > 0 {
    display as error "Failed:       `fail_count'"
    display as error "Some validation tests FAILED."
    exit 1
}
else {
    display as text "Failed:       `fail_count'"
    display as result "ALL VALIDATION TESTS PASSED!"
}
display as text "{hline 70}"
