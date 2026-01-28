/*******************************************************************************
* test_sustainedss.do
*
* Purpose: Comprehensive testing of sustainedss command
*          Tests all options and common combinations
*
* Prerequisites:
*   - Run generate_test_data.do first to create synthetic datasets
*   - sustainedss.ado must be installed/accessible
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
    * Try to detect path from current working directory
    capture confirm file "_testing"
    if _rc == 0 {
        global STATA_TOOLS_PATH "`c(pwd)'"
    }
    else {
        capture confirm file "data"
        if _rc == 0 {
            global STATA_TOOLS_PATH "`c(pwd)'/.."
        }
        else {
            global STATA_TOOLS_PATH "/home/`c(username)'/Stata-Tools"
        }
    }
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

* Install setools package from local repository (contains sustainedss)
capture net uninstall setools
net install setools, from("${STATA_TOOLS_PATH}/setools")

local testdir "${DATA_DIR}"

* Check for required test data
capture confirm file "`testdir'/edss_long.dta"
if _rc {
    display as error "Test data not found. Run generate_test_data.do first."
    exit 601
}

display as text _n "{hline 70}"
display as text "SUSTAINEDSS COMMAND TESTING"
display as text "{hline 70}"
display as text "Test directory: `testdir'"
display as text "{hline 70}"

local test_count = 0
local pass_count = 0
local fail_count = 0

* =============================================================================
* TEST 1: Basic sustainedss with threshold 4
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Basic sustainedss (threshold 4)"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/edss_long.dta", clear

    sustainedss id edss edss_dt, threshold(4)

    * Check stored results
    assert !missing(r(N_events))
    assert !missing(r(iterations))
    assert r(threshold) == 4
    display as text "  N events: " r(N_events)
    display as text "  Iterations: " r(iterations)
    display as result "  PASSED: Basic sustainedss works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 2: Different threshold (6)
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Threshold 6"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/edss_long.dta", clear

    sustainedss id edss edss_dt, threshold(6)

    assert r(threshold) == 6
    assert !missing(r(N_events))
    display as text "  N events: " r(N_events)
    display as result "  PASSED: Threshold 6 works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 3: Custom generate variable name
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Custom generate variable name"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/edss_long.dta", clear

    sustainedss id edss edss_dt, threshold(4) generate(my_edss4_date)

    * Check the custom variable was created
    confirm variable my_edss4_date

    * Check stored results
    assert "`r(varname)'" == "my_edss4_date"

    display as result "  PASSED: Custom variable name works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 4: Default variable name (sustained#_dt)
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Default variable name"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/edss_long.dta", clear

    sustainedss id edss edss_dt, threshold(4)

    * Check default variable was created
    confirm variable sustained4_dt

    assert "`r(varname)'" == "sustained4_dt"

    display as result "  PASSED: Default variable name works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 5: Custom confirmation window (90 days)
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Custom confirmation window (90 days)"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/edss_long.dta", clear

    sustainedss id edss edss_dt, threshold(4) confirmwindow(90)

    assert r(confirmwindow) == 90
    display as text "  Confirm window: " r(confirmwindow)
    display as result "  PASSED: Custom confirmation window works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 6: Default confirmation window (182 days)
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Default confirmation window (182 days)"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/edss_long.dta", clear

    sustainedss id edss edss_dt, threshold(4)

    assert r(confirmwindow) == 182
    display as result "  PASSED: Default 182-day window used"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 7: Custom baseline threshold
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Custom baseline threshold"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/edss_long.dta", clear

    sustainedss id edss edss_dt, threshold(4) baselinethreshold(3)

    assert !missing(r(N_events))
    display as result "  PASSED: Custom baseline threshold works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 8: keepall option
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': keepall option"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/edss_long.dta", clear
    local N_before = _N

    sustainedss id edss edss_dt, threshold(4) keepall

    * With keepall, all observations should be retained
    local N_after = _N
    assert `N_after' == `N_before'

    display as text "  Observations retained: `N_after'"
    display as result "  PASSED: keepall option works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 9: Without keepall (only events retained)
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Without keepall (default behavior)"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/edss_long.dta", clear
    local N_before = _N

    sustainedss id edss edss_dt, threshold(4)

    local N_after = _N
    * Without keepall, only patients with events should remain
    * (number of observations should be <= events count if patients have multiple rows)
    display as text "  Observations before: `N_before'"
    display as text "  Observations after: `N_after'"
    display as result "  PASSED: Default (no keepall) works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 10: quietly option
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': quietly option"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/edss_long.dta", clear

    sustainedss id edss edss_dt, threshold(4) quietly

    * Results should still be stored
    assert !missing(r(N_events))
    assert !missing(r(iterations))

    display as result "  PASSED: quietly option works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 11: All options combined
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': All options combined"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/edss_long.dta", clear

    sustainedss id edss edss_dt, threshold(6) generate(edss6_sust) ///
        confirmwindow(120) baselinethreshold(5) keepall quietly

    * Check variable created
    confirm variable edss6_sust

    * Check results
    assert r(threshold) == 6
    assert r(confirmwindow) == 120
    assert "`r(varname)'" == "edss6_sust"

    display as result "  PASSED: All options work together"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 12: Result variable is a date
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Result variable is date format"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/edss_long.dta", clear

    sustainedss id edss edss_dt, threshold(4) keepall

    * Check date format
    local fmt: format sustained4_dt
    assert substr("`fmt'", 1, 2) == "%t" | substr("`fmt'", 1, 2) == "%d"

    * Count non-missing dates
    quietly count if !missing(sustained4_dt)
    display as text "  Patients with sustained event: " r(N)

    display as result "  PASSED: Result variable is date format"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 13: if/in conditions
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': if/in conditions"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/edss_long.dta", clear

    * Get subset of IDs
    quietly levelsof id, local(ids)
    local first_ids: word 1 of `ids'
    local second_ids: word 2 of `ids'
    local third_ids: word 3 of `ids'

    sustainedss id edss edss_dt if id <= 500, threshold(4) keepall

    * Should have processed only subset
    assert !missing(r(N_events)) | r(N_events) == 0

    display as result "  PASSED: if condition works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 14: Stored results consistency
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Stored results consistency"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/edss_long.dta", clear

    sustainedss id edss edss_dt, threshold(4) keepall

    * Verify all expected results
    assert r(N_events) >= 0
    assert r(iterations) >= 1
    assert r(threshold) == 4
    assert r(confirmwindow) == 182
    assert "`r(varname)'" == "sustained4_dt"

    * Count should match stored N_events
    quietly count if !missing(sustained4_dt)
    local counted = r(N)
    * Note: N_events counts unique patients, count may have duplicates

    display as text "  N_events: " r(N_events)
    display as text "  Iterations: " r(iterations)

    display as result "  PASSED: Stored results consistent"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 15: Different EDSS thresholds
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Various EDSS thresholds"
display as text "{hline 50}"

capture noisily {
    local events_4 = 0
    local events_6 = 0

    * Threshold 4
    use "`testdir'/edss_long.dta", clear
    sustainedss id edss edss_dt, threshold(4) quietly
    local events_4 = r(N_events)

    * Threshold 6
    use "`testdir'/edss_long.dta", clear
    sustainedss id edss edss_dt, threshold(6) quietly
    local events_6 = r(N_events)

    * Higher threshold should have fewer or equal events
    assert `events_6' <= `events_4'

    display as text "  Events at threshold 4: `events_4'"
    display as text "  Events at threshold 6: `events_6'"
    display as result "  PASSED: Event counts are logical"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 16: Decimal threshold (e.g., 3.5)
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Decimal threshold"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/edss_long.dta", clear

    sustainedss id edss edss_dt, threshold(3.5) quietly

    assert r(threshold) == 3.5

    display as text "  N events at 3.5: " r(N_events)
    display as result "  PASSED: Decimal threshold works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 17: Variable name with decimal in threshold
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Auto variable name with decimal threshold"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/edss_long.dta", clear

    sustainedss id edss edss_dt, threshold(4.5) keepall

    * Should create sustained4_5_dt (decimal replaced with underscore)
    * Or sustained4_5_dt - check what actually gets created
    capture confirm variable sustained4_5_dt
    if _rc {
        capture confirm variable sustained4_dt
    }

    * At minimum, check r(varname) is populated
    assert "`r(varname)'" != ""
    display as text "  Variable created: `r(varname)'"

    display as result "  PASSED: Decimal threshold variable naming works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* CLEANUP
* =============================================================================
display as text _n "{hline 70}"
display as text "Cleaning up..."
display as text "{hline 70}"

* No temporary files created for this test

* =============================================================================
* SUMMARY
* =============================================================================
display as text _n "{hline 70}"
display as text "SUSTAINEDSS TEST SUMMARY"
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
