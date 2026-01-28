/*******************************************************************************
* validation_datefix.do
*
* Purpose: Deep validation tests for datefix command using known-answer testing
*          These tests verify date parsing produces mathematically correct
*          Stata date values.
*
* Philosophy: Create minimal datasets where every output date value can be
*             verified against known Stata date calculations.
*
* Run modes:
*   Standalone: do validation_datefix.do
*   Via runner: do run_test.do validation_datefix [testnumber] [quiet] [machine]
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

* Install datefix
capture net uninstall datefix
quietly net install datefix, from("${STATA_TOOLS_PATH}/datefix")

* =============================================================================
* HEADER
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "DATEFIX DEEP VALIDATION TESTS"
    display as text "{hline 70}"
    display as text "These tests verify date parsing produces correct Stata date values."
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
* KNOWN DATE VALUES REFERENCE
* =============================================================================
* Stata dates are days since January 1, 1960
* Key reference dates:
*   Jan 1, 1960 = 0
*   Jan 1, 2000 = 14610
*   Jan 1, 2020 = 21915
*   Dec 31, 2020 = 22280
*   Jan 1, 2021 = 22281

* =============================================================================
* CREATE VALIDATION DATASETS
* =============================================================================
if `quiet' == 0 {
    display as text _n "Creating validation datasets..."
}

* Dataset: Known date strings in various formats
clear
input str20 date_ymd str20 date_mdy str20 date_dmy double expected_stata
    "2020-01-01" "01/01/2020" "01/01/2020" 21915
    "2020-06-15" "06/15/2020" "15/06/2020" 22081
    "2020-12-31" "12/31/2020" "31/12/2020" 22280
    "2000-01-01" "01/01/2000" "01/01/2000" 14610
    "1960-01-01" "01/01/1960" "01/01/1960" 0
end
label data "Known date strings with expected Stata values"
save "${DATA_DIR}/datefix_known.dta", replace

* Dataset: Leap year dates
clear
input str20 datestr double expected_stata
    "2020-02-29" 21974  // Feb 29 in leap year 2020
    "2000-02-29" 14669  // Feb 29 in leap year 2000
    "2024-02-29" 23435  // Feb 29 in leap year 2024
end
label data "Leap year February 29 dates"
save "${DATA_DIR}/datefix_leapyear.dta", replace

* Dataset: Two-digit year dates
clear
input str10 datestr double expected_stata
    "01/15/20" 21929   // Jan 15, 2020
    "06/15/99" 14410   // Jun 15, 1999
    "12/31/00" 14975   // Dec 31, 2000
end
label data "Two-digit year dates"
save "${DATA_DIR}/datefix_twodigit.dta", replace

if `quiet' == 0 {
    display as result "Validation datasets created in: ${DATA_DIR}"
}

* =============================================================================
* SECTION 1: YMD FORMAT TESTS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 1: YMD Format Tests"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 1.1: YMD Format Basic Parsing
* Purpose: Verify YYYY-MM-DD format produces correct Stata dates
* Known answer: 2020-01-01 = 21915
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 1.1: YMD Format Basic Parsing"
}

capture {
    use "${DATA_DIR}/datefix_known.dta", clear
    gen date_parsed = date_ymd
    datefix date_parsed, order(YMD)

    * Verify all dates match expected
    gen diff = abs(date_parsed - expected_stata)
    sum diff
    assert r(max) == 0
}
if _rc == 0 {
    display as result "  PASS: YMD format parsing correct"
    local ++pass_count
}
else {
    display as error "  FAIL: YMD format parsing (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 1.1"
}

* -----------------------------------------------------------------------------
* Test 1.2: Jan 1, 2020 Specific Value
* Purpose: Verify specific known date value
* Known answer: 2020-01-01 = 21915
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 1.2: Jan 1, 2020 = 21915"
}

capture {
    clear
    set obs 1
    gen datestr = "2020-01-01"
    datefix datestr, order(YMD)
    assert datestr == 21915
}
if _rc == 0 {
    display as result "  PASS: Jan 1, 2020 correctly parsed as 21915"
    local ++pass_count
}
else {
    display as error "  FAIL: Jan 1, 2020 value (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 1.2"
}

* =============================================================================
* SECTION 2: MDY FORMAT TESTS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 2: MDY Format Tests"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 2.1: MDY Format Basic Parsing
* Purpose: Verify MM/DD/YYYY format produces correct Stata dates
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 2.1: MDY Format Basic Parsing"
}

capture {
    use "${DATA_DIR}/datefix_known.dta", clear
    gen date_parsed = date_mdy
    datefix date_parsed, order(MDY)

    * Verify all dates match expected
    gen diff = abs(date_parsed - expected_stata)
    sum diff
    assert r(max) == 0
}
if _rc == 0 {
    display as result "  PASS: MDY format parsing correct"
    local ++pass_count
}
else {
    display as error "  FAIL: MDY format parsing (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 2.1"
}

* =============================================================================
* SECTION 3: DMY FORMAT TESTS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 3: DMY Format Tests"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 3.1: DMY Format Basic Parsing
* Purpose: Verify DD/MM/YYYY format produces correct Stata dates
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.1: DMY Format Basic Parsing"
}

capture {
    use "${DATA_DIR}/datefix_known.dta", clear
    gen date_parsed = date_dmy
    datefix date_parsed, order(DMY)

    * Verify all dates match expected
    gen diff = abs(date_parsed - expected_stata)
    sum diff
    assert r(max) == 0
}
if _rc == 0 {
    display as result "  PASS: DMY format parsing correct"
    local ++pass_count
}
else {
    display as error "  FAIL: DMY format parsing (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.1"
}

* =============================================================================
* SECTION 4: LEAP YEAR TESTS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 4: Leap Year Tests"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 4.1: Feb 29 Leap Year Parsing
* Purpose: Verify Feb 29 in leap years is parsed correctly
* Known answer: Feb 29, 2020 = 21974
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.1: Feb 29 Leap Year Parsing"
}

capture {
    use "${DATA_DIR}/datefix_leapyear.dta", clear
    datefix datestr, order(YMD)

    * Verify all leap year dates match expected
    gen diff = abs(datestr - expected_stata)
    sum diff
    assert r(max) == 0
}
if _rc == 0 {
    display as result "  PASS: Leap year Feb 29 dates correct"
    local ++pass_count
}
else {
    display as error "  FAIL: Leap year parsing (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.1"
}

* -----------------------------------------------------------------------------
* Test 4.2: Feb 29, 2020 Specific Value
* Purpose: Verify specific leap year date
* Known answer: 2020-02-29 = 21974
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.2: Feb 29, 2020 = 21974"
}

capture {
    clear
    set obs 1
    gen datestr = "2020-02-29"
    datefix datestr, order(YMD)
    assert datestr == 21974
}
if _rc == 0 {
    display as result "  PASS: Feb 29, 2020 correctly parsed as 21974"
    local ++pass_count
}
else {
    display as error "  FAIL: Feb 29, 2020 value (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.2"
}

* =============================================================================
* SECTION 5: DATE ARITHMETIC VALIDATION
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 5: Date Arithmetic Validation"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 5.1: Year Duration Calculation
* Purpose: Verify date difference equals known duration
* Known answer: Jan 1 2020 to Dec 31 2020 = 365 days (366 days in leap year)
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 5.1: Year Duration (Leap Year)"
}

capture {
    clear
    set obs 2
    gen datestr = "2020-01-01" in 1
    replace datestr = "2020-12-31" in 2
    datefix datestr, order(YMD)

    * Calculate difference
    local start = datestr[1]
    local stop = datestr[2]
    local dur = `stop' - `start'

    * 2020 is leap year: Dec 31 - Jan 1 = 365 days (0-indexed)
    assert `dur' == 365
}
if _rc == 0 {
    display as result "  PASS: 2020 year duration = 365 days"
    local ++pass_count
}
else {
    display as error "  FAIL: Year duration (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 5.1"
}

* -----------------------------------------------------------------------------
* Test 5.2: Month Duration
* Purpose: Verify January has 31 days
* Known answer: Jan 1 to Feb 1 = 31 days
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 5.2: January Duration = 31 days"
}

capture {
    clear
    set obs 2
    gen datestr = "2020-01-01" in 1
    replace datestr = "2020-02-01" in 2
    datefix datestr, order(YMD)

    local start = datestr[1]
    local stop = datestr[2]
    local dur = `stop' - `start'

    assert `dur' == 31
}
if _rc == 0 {
    display as result "  PASS: January duration = 31 days"
    local ++pass_count
}
else {
    display as error "  FAIL: January duration (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 5.2"
}

* =============================================================================
* SECTION 6: ERROR HANDLING TESTS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 6: Error Handling"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 6.1: Invalid Date Format Rejection
* Purpose: Verify invalid order() value is rejected
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 6.1: Invalid Order Option"
}

capture {
    clear
    set obs 1
    gen datestr = "2020-01-01"
    capture datefix datestr, order(INVALID)
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: Invalid order() correctly rejected"
    local ++pass_count
}
else {
    display as error "  FAIL: Invalid order not rejected"
    local ++fail_count
    local failed_tests "`failed_tests' 6.1"
}

* -----------------------------------------------------------------------------
* Test 6.2: Empty Data Handling
* Purpose: Verify error on empty dataset
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 6.2: Empty Data Handling"
}

capture {
    clear
    set obs 0
    gen datestr = ""
    capture datefix datestr, order(YMD)
    assert _rc == 2000
}
if _rc == 0 {
    display as result "  PASS: Empty data produces error 2000"
    local ++pass_count
}
else {
    display as error "  FAIL: Empty data handling (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 6.2"
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
* Invariant 1: Parsed date should be numeric
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Invariant 1: Output is Numeric"
}

capture {
    clear
    set obs 1
    gen datestr = "2020-01-01"
    datefix datestr, order(YMD)

    * Check it's now numeric
    capture confirm numeric variable datestr
    assert _rc == 0
}
if _rc == 0 {
    display as result "  PASS: Output is numeric"
    local ++pass_count
}
else {
    display as error "  FAIL: Output not numeric"
    local ++fail_count
    local failed_tests "`failed_tests' Inv1"
}

* -----------------------------------------------------------------------------
* Invariant 2: Same date, different formats should give same result
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Invariant 2: Format Consistency"
}

capture {
    * Parse same date in three formats
    clear
    set obs 1
    gen ymd = "2020-06-15"
    gen mdy = "06/15/2020"
    gen dmy = "15/06/2020"

    datefix ymd, order(YMD)
    datefix mdy, order(MDY)
    datefix dmy, order(DMY)

    * All should equal 22081
    assert ymd == mdy
    assert mdy == dmy
    assert ymd == 22081
}
if _rc == 0 {
    display as result "  PASS: All formats produce same result"
    local ++pass_count
}
else {
    display as error "  FAIL: Format inconsistency"
    local ++fail_count
    local failed_tests "`failed_tests' Inv2"
}

* =============================================================================
* SUMMARY
* =============================================================================
display as text _n "{hline 70}"
display as text "DATEFIX VALIDATION SUMMARY"
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
