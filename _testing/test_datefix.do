/*******************************************************************************
* test_datefix.do
*
* Purpose: Comprehensive testing of datefix command
*          Tests all options and common combinations
*
* Prerequisites:
*   - datefix.ado must be installed/accessible
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

* Install datefix package from local repository
capture net uninstall datefix
net install datefix, from("${STATA_TOOLS_PATH}/datefix")

local testdir "${DATA_DIR}"

display as text _n "{hline 70}"
display as text "DATEFIX COMMAND TESTING"
display as text "{hline 70}"
display as text "Test directory: `testdir'"
display as text "{hline 70}"

local test_count = 0
local pass_count = 0
local fail_count = 0

* =============================================================================
* SETUP: Create test dataset with various date formats
* =============================================================================
display as text _n "Setting up test data with string dates..."

clear
set obs 100

* Generate IDs
gen id = _n

* Various date string formats
gen str_ymd = string(2020 + floor(runiform() * 4)) + "-" + ///
    string(1 + floor(runiform() * 12), "%02.0f") + "-" + ///
    string(1 + floor(runiform() * 28), "%02.0f")

gen str_dmy = string(1 + floor(runiform() * 28), "%02.0f") + "/" + ///
    string(1 + floor(runiform() * 12), "%02.0f") + "/" + ///
    string(2020 + floor(runiform() * 4))

gen str_mdy = string(1 + floor(runiform() * 12), "%02.0f") + "/" + ///
    string(1 + floor(runiform() * 28), "%02.0f") + "/" + ///
    string(2020 + floor(runiform() * 4))

* Text month format
local months "Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec"
gen byte month_n = 1 + floor(runiform() * 12)
gen str3 month_txt = word("`months'", month_n)
gen str_dmony = string(1 + floor(runiform() * 28), "%02.0f") + " " + ///
    month_txt + " " + string(2020 + floor(runiform() * 4))
drop month_n month_txt

* Two-digit year
gen str_ymd_2digit = string(mod(2020 + floor(runiform() * 4), 100), "%02.0f") + "-" + ///
    string(1 + floor(runiform() * 12), "%02.0f") + "-" + ///
    string(1 + floor(runiform() * 28), "%02.0f")

* Copy for testing multiple variables
gen str_date1 = str_ymd
gen str_date2 = str_dmy

save "`testdir'/_test_dates.dta", replace
display as text "  Test date data created"

* =============================================================================
* TEST 1: Basic conversion (auto-detect order)
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Basic conversion (auto-detect)"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/_test_dates.dta", clear

    datefix str_ymd

    * Check that variable is now numeric date
    confirm numeric variable str_ymd
    sum str_ymd
    assert r(N) > 0
    display as result "  PASSED: Basic conversion works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 2: newvar option
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': newvar option"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/_test_dates.dta", clear

    datefix str_ymd, newvar(date_ymd)

    * Check that new variable exists and original is preserved
    confirm string variable str_ymd
    confirm numeric variable date_ymd
    display as result "  PASSED: newvar option works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 3: drop option with newvar
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': drop option"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/_test_dates.dta", clear

    datefix str_ymd, newvar(date_ymd) drop

    * Check that original is dropped
    capture confirm variable str_ymd
    assert _rc != 0
    confirm numeric variable date_ymd
    display as result "  PASSED: drop option works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 4: Explicit YMD order
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Explicit YMD order"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/_test_dates.dta", clear

    datefix str_ymd, order(YMD) newvar(date_ymd)

    confirm numeric variable date_ymd
    sum date_ymd
    assert r(N) > 0
    display as result "  PASSED: YMD order works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 5: Explicit DMY order
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Explicit DMY order"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/_test_dates.dta", clear

    datefix str_dmy, order(DMY) newvar(date_dmy)

    confirm numeric variable date_dmy
    sum date_dmy
    assert r(N) > 0
    display as result "  PASSED: DMY order works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 6: Explicit MDY order
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Explicit MDY order"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/_test_dates.dta", clear

    datefix str_mdy, order(MDY) newvar(date_mdy)

    confirm numeric variable date_mdy
    sum date_mdy
    assert r(N) > 0
    display as result "  PASSED: MDY order works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 7: Custom date format
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Custom date format"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/_test_dates.dta", clear

    datefix str_ymd, newvar(date_ymd) df(%tdDD/NN/CCYY)

    confirm numeric variable date_ymd
    * Check format
    local fmt: format date_ymd
    assert "`fmt'" == "%tdDD/NN/CCYY"
    display as result "  PASSED: Custom date format works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 8: Multiple variables at once
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Multiple variables"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/_test_dates.dta", clear

    datefix str_date1 str_date2

    confirm numeric variable str_date1
    confirm numeric variable str_date2
    display as result "  PASSED: Multiple variables work"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 9: Two-digit year with topyear
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Two-digit year with topyear"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/_test_dates.dta", clear

    datefix str_ymd_2digit, order(YMD) topyear(2050) newvar(date_2digit)

    confirm numeric variable date_2digit
    sum date_2digit
    * Years should be interpreted correctly
    display as result "  PASSED: Two-digit year works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 10: Text month format (DD Mon YYYY)
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Text month format"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/_test_dates.dta", clear

    datefix str_dmony, newvar(date_dmony)

    confirm numeric variable date_dmony
    sum date_dmony
    assert r(N) > 0
    display as result "  PASSED: Text month format works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 11: Month DD, CCYY format output
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Month DD, CCYY format"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/_test_dates.dta", clear

    datefix str_ymd, newvar(date_ymd) df(%tdMonth_DD,_CCYY)

    confirm numeric variable date_ymd
    local fmt: format date_ymd
    assert "`fmt'" == "%tdMonth_DD,_CCYY"
    display as result "  PASSED: Month DD, CCYY format works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 12: Handle missing values
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Handle missing values"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/_test_dates.dta", clear

    * Set some to missing
    replace str_ymd = "" in 1/10

    datefix str_ymd, newvar(date_ymd)

    confirm numeric variable date_ymd
    count if missing(date_ymd)
    assert r(N) >= 10
    display as result "  PASSED: Missing values handled"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 13: Invalid date strings
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Invalid date strings"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/_test_dates.dta", clear

    * Add some invalid dates
    replace str_ymd = "not a date" in 1/5
    replace str_ymd = "13/45/9999" in 6/10

    datefix str_ymd, newvar(date_ymd)

    * Invalid dates should become missing
    count if missing(date_ymd) & _n <= 10
    assert r(N) >= 5
    display as result "  PASSED: Invalid dates handled"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 14: Default format (CCYY/MM/DD)
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Default format (CCYY/MM/DD)"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/_test_dates.dta", clear

    datefix str_ymd, newvar(date_ymd)

    * Default format should be %tdCCYY/NN/DD
    local fmt: format date_ymd
    assert "`fmt'" == "%tdCCYY/NN/DD"
    display as result "  PASSED: Default format correct"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* CLEANUP: Remove temporary files
* =============================================================================
display as text _n "{hline 70}"
display as text "Cleaning up temporary files..."
display as text "{hline 70}"

capture erase "`testdir'/_test_dates.dta"

* =============================================================================
* SUMMARY
* =============================================================================
display as text _n "{hline 70}"
display as text "DATEFIX TEST SUMMARY"
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
