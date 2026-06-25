/*******************************************************************************
* validation_datefix.do
*
* Purpose: Deep validation tests for datefix using known-answer testing
*          Verifies date parsing produces correct Stata date values
*
* Known reference dates (days since Jan 1, 1960):
*   Jan 1, 1960 = 0
*   Jan 1, 2000 = 14610
*   Jan 1, 2020 = 21915
*   Dec 31, 2020 = 22280
*
* Author: Timothy P Copeland
* Date: 2026-03-19
*******************************************************************************/

clear all
set more off
version 16.0

* Path configuration

* Install datefix

* === Bootstrap ===
local qa_dir  "`c(pwd)'"
local pkg_dir "`qa_dir'/.."  

capture ado uninstall datefix
quietly net install datefix, from("`pkg_dir'") replace

display as text _n "DATEFIX DEEP VALIDATION TESTS"

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

* ===========================================================================
* SECTION 1: YMD FORMAT TESTS
* ===========================================================================
display as text _n "SECTION 1: YMD Format Tests"

* Test 1.1: YMD basic parsing — known values
local ++test_count
capture {
    clear
    input str20 datestr double expected
        "2020-01-01" 21915
        "2020-06-15" 22081
        "2020-12-31" 22280
        "2000-01-01" 14610
        "1960-01-01" 0
    end
    gen parsed = datestr
    datefix parsed, order(YMD)
    gen diff = abs(parsed - expected)
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

* Test 1.2: Jan 1, 2020 = 21915
local ++test_count
capture {
    clear
    set obs 1
    gen datestr = "2020-01-01"
    datefix datestr, order(YMD)
    assert datestr == 21915
}
if _rc == 0 {
    display as result "  PASS: Jan 1, 2020 = 21915"
    local ++pass_count
}
else {
    display as error "  FAIL: Jan 1, 2020 value (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 1.2"
}

* ===========================================================================
* SECTION 2: MDY FORMAT TESTS
* ===========================================================================
display as text _n "SECTION 2: MDY Format Tests"

* Test 2.1: MDY basic parsing
local ++test_count
capture {
    clear
    input str20 datestr double expected
        "01/01/2020" 21915
        "06/15/2020" 22081
        "12/31/2020" 22280
        "01/01/2000" 14610
        "01/01/1960" 0
    end
    gen parsed = datestr
    datefix parsed, order(MDY)
    gen diff = abs(parsed - expected)
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

* ===========================================================================
* SECTION 3: DMY FORMAT TESTS
* ===========================================================================
display as text _n "SECTION 3: DMY Format Tests"

* Test 3.1: DMY basic parsing
local ++test_count
capture {
    clear
    input str20 datestr double expected
        "01/01/2020" 21915
        "15/06/2020" 22081
        "31/12/2020" 22280
        "01/01/2000" 14610
        "01/01/1960" 0
    end
    gen parsed = datestr
    datefix parsed, order(DMY)
    gen diff = abs(parsed - expected)
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

* ===========================================================================
* SECTION 4: LEAP YEAR TESTS
* ===========================================================================
display as text _n "SECTION 4: Leap Year Tests"

* Test 4.1: Feb 29 in leap years
local ++test_count
capture {
    clear
    input str20 datestr double expected
        "2020-02-29" 21974
        "2000-02-29" 14669
        "2024-02-29" 23435
    end
    datefix datestr, order(YMD)
    gen diff = abs(datestr - expected)
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

* Test 4.2: Feb 29, 2020 = 21974
local ++test_count
capture {
    clear
    set obs 1
    gen datestr = "2020-02-29"
    datefix datestr, order(YMD)
    assert datestr == 21974
}
if _rc == 0 {
    display as result "  PASS: Feb 29, 2020 = 21974"
    local ++pass_count
}
else {
    display as error "  FAIL: Feb 29, 2020 value (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.2"
}

* ===========================================================================
* SECTION 5: DATE ARITHMETIC
* ===========================================================================
display as text _n "SECTION 5: Date Arithmetic Validation"

* Test 5.1: 2020 leap year = 365 days between Jan 1 and Dec 31
local ++test_count
capture {
    clear
    set obs 2
    gen datestr = "2020-01-01" in 1
    replace datestr = "2020-12-31" in 2
    datefix datestr, order(YMD)
    local dur = datestr[2] - datestr[1]
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

* Test 5.2: January = 31 days
local ++test_count
capture {
    clear
    set obs 2
    gen datestr = "2020-01-01" in 1
    replace datestr = "2020-02-01" in 2
    datefix datestr, order(YMD)
    local dur = datestr[2] - datestr[1]
    assert `dur' == 31
}
if _rc == 0 {
    display as result "  PASS: January = 31 days"
    local ++pass_count
}
else {
    display as error "  FAIL: January duration (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 5.2"
}

* Test 5.3: Feb 2020 (leap year) = 29 days
local ++test_count
capture {
    clear
    set obs 2
    gen datestr = "2020-02-01" in 1
    replace datestr = "2020-03-01" in 2
    datefix datestr, order(YMD)
    local dur = datestr[2] - datestr[1]
    assert `dur' == 29
}
if _rc == 0 {
    display as result "  PASS: Feb 2020 (leap) = 29 days"
    local ++pass_count
}
else {
    display as error "  FAIL: Feb leap duration (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 5.3"
}

* ===========================================================================
* SECTION 6: ERROR HANDLING
* ===========================================================================
display as text _n "SECTION 6: Error Handling"

* Test 6.1: Invalid order rejected
local ++test_count
capture {
    clear
    set obs 1
    gen datestr = "2020-01-01"
    capture datefix datestr, order(INVALID)
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: Invalid order() rejected"
    local ++pass_count
}
else {
    display as error "  FAIL: Invalid order not rejected"
    local ++fail_count
    local failed_tests "`failed_tests' 6.1"
}

* Test 6.2: Empty dataset = rc 2000
local ++test_count
capture {
    clear
    set obs 0
    gen datestr = ""
    capture datefix datestr, order(YMD)
    assert _rc == 2000
}
if _rc == 0 {
    display as result "  PASS: Empty data = rc 2000"
    local ++pass_count
}
else {
    display as error "  FAIL: Empty data handling (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 6.2"
}

* ===========================================================================
* INVARIANT TESTS
* ===========================================================================
display as text _n "INVARIANT TESTS"

* Invariant 1: Output is numeric
local ++test_count
capture {
    clear
    set obs 1
    gen datestr = "2020-01-01"
    datefix datestr, order(YMD)
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

* Invariant 2: Same date in 3 formats gives same Stata value
local ++test_count
capture {
    clear
    set obs 1
    gen ymd = "2020-06-15"
    gen mdy = "06/15/2020"
    gen dmy = "15/06/2020"
    datefix ymd, order(YMD)
    datefix mdy, order(MDY)
    datefix dmy, order(DMY)
    assert ymd == mdy
    assert mdy == dmy
    assert ymd == 22081
}
if _rc == 0 {
    display as result "  PASS: All formats produce same result (22081)"
    local ++pass_count
}
else {
    display as error "  FAIL: Format inconsistency"
    local ++fail_count
    local failed_tests "`failed_tests' Inv2"
}

* Invariant 3: Parsed date matches Stata's date() function
local ++test_count
capture {
    clear
    set obs 1
    gen datestr = "2020-07-04"
    gen double expected = date("2020-07-04", "YMD")
    datefix datestr, order(YMD)
    assert datestr == expected
}
if _rc == 0 {
    display as result "  PASS: Matches Stata date() function"
    local ++pass_count
}
else {
    display as error "  FAIL: date() function mismatch"
    local ++fail_count
    local failed_tests "`failed_tests' Inv3"
}

* Invariant 4: Missing in = missing out
local ++test_count
capture {
    clear
    set obs 5
    gen datestr = "2020-01-01" in 1
    replace datestr = "" in 2
    replace datestr = "2020-03-01" in 3
    replace datestr = "" in 4
    replace datestr = "2020-05-01" in 5
    datefix datestr, order(YMD)
    assert missing(datestr[2])
    assert missing(datestr[4])
    assert !missing(datestr[1])
    assert !missing(datestr[3])
    assert !missing(datestr[5])
}
if _rc == 0 {
    display as result "  PASS: Missing in = missing out"
    local ++pass_count
}
else {
    display as error "  FAIL: Missing value invariant"
    local ++fail_count
    local failed_tests "`failed_tests' Inv4"
}

* ===========================================================================
* SUMMARY
* ===========================================================================
display as text _n "DATEFIX VALIDATION SUMMARY"
display as text "Total tests:  `test_count'"
display as result "Passed:       `pass_count'"
if `fail_count' > 0 {
    display as error "Failed:       `fail_count'"
    display as error "Failed tests:`failed_tests'"
}
else {
    display as text "Failed:       `fail_count'"
}

if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    display "RESULT: validation_datefix tests=`test_count' pass=`pass_count' fail=`fail_count'"
    exit 1
}
display as result "ALL TESTS PASSED"
display "RESULT: validation_datefix tests=`test_count' pass=`pass_count' fail=`fail_count'"
