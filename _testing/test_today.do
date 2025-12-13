/*******************************************************************************
* test_today.do
*
* Purpose: Comprehensive testing of today command
*          Tests all options and common combinations
*
* Prerequisites:
*   - today.ado must be installed/accessible
*
* Author: Timothy P Copeland
* Date: 2025-12-05
*******************************************************************************/

clear all
set more off
version 16.0

* =============================================================================
* PATH CONFIGURATION
* =============================================================================
* Cross-platform path detection
if "`c(os)'" == "MacOSX" {
    global STATA_TOOLS_PATH "/Users/tcopeland/Documents/GitHub/Stata-Tools"
}
else if "`c(os)'" == "Unix" {
    global STATA_TOOLS_PATH "/home/ubuntu/Stata-Tools"
}
else {
    * Windows or other - try to detect from current directory
    capture confirm file "_testing"
    if _rc == 0 {
        * Running from repo root
        global STATA_TOOLS_PATH "`c(pwd)'"
    }
    else {
        capture confirm file "data"
        if _rc == 0 {
            * Running from _testing directory
            global STATA_TOOLS_PATH "`c(pwd)'/.."
        }
        else {
            * Assume running from _testing/data directory
            global STATA_TOOLS_PATH "`c(pwd)'/../.."
        }
    }
}

* Directory structure
global TESTING_DIR "${STATA_TOOLS_PATH}/_testing"
global DATA_DIR "${TESTING_DIR}/data"

* =============================================================================
* SETUP: Change to data directory and install package from local repository
* =============================================================================

* Change to data directory
cd "${DATA_DIR}"

* Install today package from local repository
capture net uninstall today
net install today, from("${STATA_TOOLS_PATH}/today")

local testdir "${DATA_DIR}"

display as text _n "{hline 70}"
display as text "TODAY COMMAND TESTING"
display as text "{hline 70}"

local test_count = 0
local pass_count = 0
local fail_count = 0

* =============================================================================
* TEST 1: Basic usage (default format)
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Basic usage (default format)"
display as text "{hline 50}"

capture noisily {
    today

    * Check that globals are set
    assert !missing("$today")
    assert !missing("$today_time")
    display as text "  today: $today"
    display as text "  today_time: $today_time"
    display as result "  PASSED: Basic usage works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 2: DMY format
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': DMY format"
display as text "{hline 50}"

capture noisily {
    today, df(dmy)

    display as text "  today: $today"
    display as text "  today_time: $today_time"
    display as result "  PASSED: DMY format works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 3: MDY format
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': MDY format"
display as text "{hline 50}"

capture noisily {
    today, df(mdy)

    display as text "  today: $today"
    display as text "  today_time: $today_time"
    display as result "  PASSED: MDY format works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 4: DMONY format
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': DMONY format"
display as text "{hline 50}"

capture noisily {
    today, df(dmony)

    display as text "  today: $today"
    display as text "  today_time: $today_time"
    display as result "  PASSED: DMONY format works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 5: Custom time separator (period)
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Custom time separator (period)"
display as text "{hline 50}"

capture noisily {
    today, tsep(.)

    display as text "  today: $today"
    display as text "  today_time: $today_time"
    display as result "  PASSED: Period separator works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 6: Custom time separator (hyphen)
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Custom time separator (hyphen)"
display as text "{hline 50}"

capture noisily {
    today, tsep(-)

    display as text "  today: $today"
    display as text "  today_time: $today_time"
    display as result "  PASSED: Hyphen separator works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 7: Hours and minutes only (no seconds)
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Hours and minutes only"
display as text "{hline 50}"

capture noisily {
    today, hm

    display as text "  today: $today"
    display as text "  today_time: $today_time"
    display as result "  PASSED: HM option works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 8: Combined options (MDY + period + hm)
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Combined options"
display as text "{hline 50}"

capture noisily {
    today, df(mdy) tsep(.) hm

    display as text "  today: $today"
    display as text "  today_time: $today_time"
    display as result "  PASSED: Combined options work"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 9: YMD format (default)
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': YMD format explicit"
display as text "{hline 50}"

capture noisily {
    today, df(ymd)

    display as text "  today: $today"
    display as text "  today_time: $today_time"
    * YMD should have underscores: YYYY_MM_DD
    assert strpos("$today", "_") > 0
    display as result "  PASSED: YMD format works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 10: Timezone conversion (if supported)
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Timezone conversion"
display as text "{hline 50}"

capture noisily {
    today, from(UTC+1) to(UTC-5)

    display as text "  today: $today"
    display as text "  today_time: $today_time"
    display as result "  PASSED: Timezone conversion works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 11: Use in filename
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Use in filename"
display as text "{hline 50}"

capture noisily {
    today

    * Create a filename using today
    local testfile "test_$today.txt"
    display as text "  Generated filename: `testfile'"
    display as result "  PASSED: Can be used in filename"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 12: Use in log file name
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Use in log file name"
display as text "{hline 50}"

capture noisily {
    local testdir = c(pwd)
    today

    * This would be used like:
    * log using "analysis_$today.log", replace
    display as text "  Would create log: analysis_$today.log"
    display as result "  PASSED: Suitable for log naming"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 13: Multiple calls (verify updates)
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Multiple calls"
display as text "{hline 50}"

capture noisily {
    today, df(ymd)
    local first_today = "$today"

    sleep 1000  // Wait 1 second

    today, df(ymd)
    local second_today = "$today"

    * Date should be the same (we didn't cross midnight)
    assert "`first_today'" == "`second_today'"
    display as text "  First: `first_today'"
    display as text "  Second: `second_today'"
    display as result "  PASSED: Multiple calls consistent"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* SUMMARY
* =============================================================================
display as text _n "{hline 70}"
display as text "TODAY TEST SUMMARY"
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
    display as error "Some tests FAILED. Review output above."
    exit 1
}
else {
    display as result "All tests PASSED!"
}
