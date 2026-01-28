/*******************************************************************************
* validation_table1_tc.do
*
* Purpose: Validation tests for table1_tc command
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

adopath ++ "`base_path'/table1_tc"

* =============================================================================
* HEADER
* =============================================================================
display as text _n "{hline 70}"
display as text "TABLE1_TC VALIDATION TESTS"
display as text "{hline 70}"

local test_count = 0
local pass_count = 0
local fail_count = 0

* =============================================================================
* SECTION 1: BASIC EXECUTION
* =============================================================================
display as text _n "SECTION 1: Basic Execution" _n

* Test 1.1: Basic execution with continuous variable
local ++test_count
display as text "Test 1.1: Basic execution - continuous variable"
capture {
    sysuse auto, clear
    table1_tc, vars(price contn) by(foreign)
}
if _rc == 0 {
    display as result "  PASS: table1_tc executes with contn"
    local ++pass_count
}
else {
    display as error "  FAIL: table1_tc failed with error `=_rc'"
    local ++fail_count
}

* Test 1.2: Binary variable
local ++test_count
display as text "Test 1.2: Binary variable type"
capture {
    sysuse auto, clear
    gen highmpg = (mpg > 20)
    table1_tc, vars(highmpg bin) by(foreign)
}
if _rc == 0 {
    display as result "  PASS: table1_tc works with bin type"
    local ++pass_count
}
else {
    display as error "  FAIL: bin type failed"
    local ++fail_count
}

* Test 1.3: Categorical variable
local ++test_count
display as text "Test 1.3: Categorical variable type"
capture {
    sysuse auto, clear
    table1_tc, vars(rep78 cat) by(foreign)
}
if _rc == 0 {
    display as result "  PASS: table1_tc works with cat type"
    local ++pass_count
}
else {
    display as error "  FAIL: cat type failed"
    local ++fail_count
}

* =============================================================================
* SECTION 2: VARIABLE TYPES
* =============================================================================
display as text _n "SECTION 2: Variable Types" _n

* Test 2.1: conts (continuous with SD)
local ++test_count
display as text "Test 2.1: conts type (mean SD)"
capture {
    sysuse auto, clear
    table1_tc, vars(price conts) by(foreign)
}
if _rc == 0 {
    display as result "  PASS: conts type works"
    local ++pass_count
}
else {
    display as error "  FAIL: conts type failed"
    local ++fail_count
}

* Test 2.2: contln (log-transformed)
local ++test_count
display as text "Test 2.2: contln type (log-normal)"
capture {
    sysuse auto, clear
    table1_tc, vars(price contln) by(foreign)
}
if _rc == 0 {
    display as result "  PASS: contln type works"
    local ++pass_count
}
else {
    display as error "  FAIL: contln type failed"
    local ++fail_count
}

* =============================================================================
* SECTION 3: OPTIONS
* =============================================================================
display as text _n "SECTION 3: Options" _n

* Test 3.1: percent option
local ++test_count
display as text "Test 3.1: percent option"
capture {
    sysuse auto, clear
    table1_tc, vars(rep78 cat) by(foreign) percent
}
if _rc == 0 {
    display as result "  PASS: percent option works"
    local ++pass_count
}
else {
    display as error "  FAIL: percent option failed"
    local ++fail_count
}

* Test 3.2: onecol option
local ++test_count
display as text "Test 3.2: onecol option"
capture {
    sysuse auto, clear
    table1_tc, vars(price contn) by(foreign) onecol
}
if _rc == 0 {
    display as result "  PASS: onecol option works"
    local ++pass_count
}
else {
    display as error "  FAIL: onecol option failed"
    local ++fail_count
}

* Test 3.3: test option (statistical tests)
local ++test_count
display as text "Test 3.3: test option"
capture {
    sysuse auto, clear
    table1_tc, vars(price contn) by(foreign) test
}
if _rc == 0 {
    display as result "  PASS: test option works"
    local ++pass_count
}
else {
    display as error "  FAIL: test option failed"
    local ++fail_count
}

* Test 3.4: clear option
local ++test_count
display as text "Test 3.4: clear option"
capture {
    sysuse auto, clear
    table1_tc, vars(price contn) by(foreign) clear
}
if _rc == 0 {
    display as result "  PASS: clear option works"
    local ++pass_count
}
else {
    display as error "  FAIL: clear option failed"
    local ++fail_count
}

* =============================================================================
* SECTION 4: MULTIPLE VARIABLES
* =============================================================================
display as text _n "SECTION 4: Multiple Variables" _n

* Test 4.1: Multiple variables
local ++test_count
display as text "Test 4.1: Multiple variables"
capture {
    sysuse auto, clear
    gen highmpg = (mpg > 20)
    table1_tc, vars(price contn mpg contn weight conts highmpg bin rep78 cat) by(foreign)
}
if _rc == 0 {
    display as result "  PASS: Multiple variables work"
    local ++pass_count
}
else {
    display as error "  FAIL: Multiple variables failed"
    local ++fail_count
}

* =============================================================================
* SECTION 5: ERROR CONDITIONS
* =============================================================================
display as text _n "SECTION 5: Error Conditions" _n

* Test 5.1: Error when vars() not specified
local ++test_count
display as text "Test 5.1: Error when vars() missing"
capture noisily {
    sysuse auto, clear
    table1_tc, by(foreign)
}
if _rc != 0 {
    display as result "  PASS: Correctly errors when vars() missing"
    local ++pass_count
}
else {
    display as error "  FAIL: Should have errored"
    local ++fail_count
}

* =============================================================================
* SUMMARY
* =============================================================================
display as text _n "{hline 70}"
display as text "TABLE1_TC VALIDATION SUMMARY"
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
