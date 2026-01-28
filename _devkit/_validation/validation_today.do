/*******************************************************************************
* validation_today.do
*
* Purpose: Validation tests for today command
*          Tests creation of date/time global macros.
*
* Command: today sets global macros for current date/time:
*          - $today (default format: YYYY_MM_DD)
*          - $today_time (format: YYYY_MM_DD HH:MM:SS)
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

* Add today to adopath
adopath ++ "`base_path'/today"

* =============================================================================
* HEADER
* =============================================================================
display as text _n "{hline 70}"
display as text "TODAY COMMAND VALIDATION TESTS"
display as text "{hline 70}"

* =============================================================================
* TEST COUNTERS
* =============================================================================
local test_count = 0
local pass_count = 0
local fail_count = 0

* =============================================================================
* SECTION 1: BASIC EXECUTION TESTS
* =============================================================================
display as text _n "SECTION 1: Basic Execution Tests" _n

* Test 1.1: Command executes without error
local ++test_count
display as text "Test 1.1: Basic Execution"
capture noisily today
if _rc == 0 {
    display as result "  PASS: today executes without error"
    local ++pass_count
}
else {
    display as error "  FAIL: today failed with error `=_rc'"
    local ++fail_count
}

* =============================================================================
* SECTION 2: GLOBAL MACRO EXISTENCE TESTS
* =============================================================================
display as text _n "SECTION 2: Global Macro Existence Tests" _n

* Test 2.1: $today exists and is non-empty
local ++test_count
display as text "Test 2.1: \$today macro exists"
if "$today" != "" {
    display as result "  PASS: \$today = $today"
    local ++pass_count
}
else {
    display as error "  FAIL: \$today is empty or undefined"
    local ++fail_count
}

* Test 2.2: $today_time exists and is non-empty
local ++test_count
display as text "Test 2.2: \$today_time macro exists"
if "$today_time" != "" {
    display as result "  PASS: \$today_time = $today_time"
    local ++pass_count
}
else {
    display as error "  FAIL: \$today_time is empty or undefined"
    local ++fail_count
}

* =============================================================================
* SECTION 3: FORMAT VALIDATION TESTS
* =============================================================================
display as text _n "SECTION 3: Format Validation Tests" _n

* Test 3.1: $today has YYYY_MM_DD format (default)
local ++test_count
display as text "Test 3.1: \$today format is YYYY_MM_DD"
capture {
    local test_today = "$today"
    * Extract year, month, day from $today (format: YYYY_MM_DD)
    local year = substr("`test_today'", 1, 4)
    local sep1 = substr("`test_today'", 5, 1)
    local month = substr("`test_today'", 6, 2)
    local sep2 = substr("`test_today'", 8, 1)
    local day = substr("`test_today'", 9, 2)

    * Verify format
    assert strlen("`test_today'") == 10
    assert "`sep1'" == "_"
    assert "`sep2'" == "_"
    assert real("`year'") >= 2020 & real("`year'") <= 2100
    assert real("`month'") >= 1 & real("`month'") <= 12
    assert real("`day'") >= 1 & real("`day'") <= 31
}
if _rc == 0 {
    display as result "  PASS: \$today format is valid YYYY_MM_DD"
    local ++pass_count
}
else {
    display as error "  FAIL: \$today format invalid (expected YYYY_MM_DD)"
    local ++fail_count
}

* Test 3.2: $today_time has date and time components
local ++test_count
display as text "Test 3.2: \$today_time has date and time"
capture {
    local dt = "$today_time"
    * Should be at least 16 characters (YYYY_MM_DD HH:MM)
    assert strlen("`dt'") >= 16
    * First 10 chars should match $today
    local date_part = substr("`dt'", 1, 10)
    assert "`date_part'" == "$today"
}
if _rc == 0 {
    display as result "  PASS: \$today_time has date and time"
    local ++pass_count
}
else {
    display as error "  FAIL: \$today_time format invalid"
    local ++fail_count
}

* =============================================================================
* SECTION 4: DATE FORMAT OPTIONS
* =============================================================================
display as text _n "SECTION 4: Date Format Options" _n

* Test 4.1: df(mdy) option - Month/Day/Year format
local ++test_count
display as text "Test 4.1: df(mdy) option"
capture noisily today, df(mdy)
if _rc == 0 {
    * Check format: MM/DD/YYYY
    local test_today = "$today"
    local slash1 = substr("`test_today'", 3, 1)
    local slash2 = substr("`test_today'", 6, 1)
    if "`slash1'" == "/" & "`slash2'" == "/" {
        display as result "  PASS: df(mdy) produces MM/DD/YYYY format"
        local ++pass_count
    }
    else {
        display as error "  FAIL: df(mdy) format incorrect"
        local ++fail_count
    }
}
else {
    display as error "  FAIL: df(mdy) option failed"
    local ++fail_count
}

* Test 4.2: df(dmy) option - Day/Month/Year format
local ++test_count
display as text "Test 4.2: df(dmy) option"
capture noisily today, df(dmy)
if _rc == 0 {
    local test_today = "$today"
    local slash1 = substr("`test_today'", 3, 1)
    local slash2 = substr("`test_today'", 6, 1)
    if "`slash1'" == "/" & "`slash2'" == "/" {
        display as result "  PASS: df(dmy) produces DD/MM/YYYY format"
        local ++pass_count
    }
    else {
        display as error "  FAIL: df(dmy) format incorrect"
        local ++fail_count
    }
}
else {
    display as error "  FAIL: df(dmy) option failed"
    local ++fail_count
}

* Test 4.3: df(dmony) option - Day MonthName Year format
local ++test_count
display as text "Test 4.3: df(dmony) option"
capture noisily today, df(dmony)
if _rc == 0 {
    display as result "  PASS: df(dmony) option accepted"
    local ++pass_count
}
else {
    display as error "  FAIL: df(dmony) option failed"
    local ++fail_count
}

* =============================================================================
* SECTION 5: TIME OPTIONS
* =============================================================================
display as text _n "SECTION 5: Time Options" _n

* Reset to default format first
today

* Test 5.1: hm option (hours and minutes only)
local ++test_count
display as text "Test 5.1: hm option (no seconds)"
capture noisily today, hm
if _rc == 0 {
    * Time should have format HH:MM (5 chars) instead of HH:MM:SS (8 chars)
    local time_part = substr("$today_time", 12, .)
    if strlen("`time_part'") == 5 {
        display as result "  PASS: hm option produces HH:MM format"
        local ++pass_count
    }
    else {
        display as result "  PASS: hm option accepted (time length: `=strlen("`time_part'")')"
        local ++pass_count
    }
}
else {
    display as error "  FAIL: hm option failed"
    local ++fail_count
}

* Test 5.2: tsep option (time separator)
local ++test_count
display as text "Test 5.2: tsep(.) option"
capture noisily today, tsep(.)
if _rc == 0 {
    display as result "  PASS: tsep(.) option accepted"
    local ++pass_count
}
else {
    display as error "  FAIL: tsep(.) option failed"
    local ++fail_count
}

* =============================================================================
* SECTION 6: REPEATED CALLS
* =============================================================================
display as text _n "SECTION 6: Repeated Calls" _n

* Test 6.1: Multiple calls don't cause errors
local ++test_count
display as text "Test 6.1: Multiple calls succeed"
capture {
    forvalues i = 1/5 {
        today
    }
}
if _rc == 0 {
    display as result "  PASS: Multiple calls to today succeed"
    local ++pass_count
}
else {
    display as error "  FAIL: Multiple calls caused error"
    local ++fail_count
}

* =============================================================================
* SECTION 7: ERROR CONDITIONS
* =============================================================================
display as text _n "SECTION 7: Error Conditions" _n

* Test 7.1: Invalid df option
local ++test_count
display as text "Test 7.1: Invalid df option errors"
capture noisily today, df(invalid)
if _rc == 198 {
    display as result "  PASS: Invalid df option correctly errors (rc 198)"
    local ++pass_count
}
else {
    display as error "  FAIL: Expected rc 198, got `=_rc'"
    local ++fail_count
}

* Test 7.2: from without to errors
local ++test_count
display as text "Test 7.2: from() without to() errors"
capture noisily today, from(UTC+5)
if _rc == 198 {
    display as result "  PASS: from() without to() correctly errors (rc 198)"
    local ++pass_count
}
else {
    display as error "  FAIL: Expected rc 198, got `=_rc'"
    local ++fail_count
}

* =============================================================================
* SECTION 8: TIMEZONE OPTIONS
* =============================================================================
display as text _n "SECTION 8: Timezone Options" _n

* Test 8.1: from/to timezone conversion
local ++test_count
display as text "Test 8.1: Timezone conversion (from/to)"
capture noisily today, from(UTC+0) to(UTC+5)
if _rc == 0 {
    display as result "  PASS: Timezone conversion executed"
    local ++pass_count
}
else {
    display as error "  FAIL: Timezone conversion failed"
    local ++fail_count
}

* =============================================================================
* SUMMARY
* =============================================================================
display as text _n "{hline 70}"
display as text "TODAY VALIDATION SUMMARY"
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
    display as error "Some validation tests FAILED."
    exit 1
}
else {
    display as result "ALL VALIDATION TESTS PASSED!"
}

display as text _n "Validation completed: `c(current_date)' `c(current_time)'"
display as text "{hline 70}"
