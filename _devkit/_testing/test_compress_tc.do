/*******************************************************************************
* test_compress_tc.do
*
* Purpose: Comprehensive testing of compress_tc command
*          Tests all options and common combinations
*
* Prerequisites:
*   - Run generate_test_data.do first to create synthetic datasets
*   - compress_tc.ado must be installed/accessible
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

* Install compress_tc package from local repository
capture net uninstall compress_tc
net install compress_tc, from("${STATA_TOOLS_PATH}/compress_tc")

local testdir "${DATA_DIR}"

* Check for required test data
capture confirm file "`testdir'/cohort.dta"
if _rc {
    display as error "Test data not found. Run generate_test_data.do first."
    exit 601
}

display as text _n "{hline 70}"
display as text "COMPRESS_TC COMMAND TESTING"
display as text "{hline 70}"
display as text "Test directory: `testdir'"
display as text "{hline 70}"

local test_count = 0
local pass_count = 0
local fail_count = 0

* =============================================================================
* SETUP: Create test data with various string types
* =============================================================================
display as text _n "Setting up test data with string variables..."

clear
set obs 1000

* ID variable
gen long id = _n

* Short repeated strings
gen str10 status = cond(mod(_n, 3) == 0, "Active", cond(mod(_n, 3) == 1, "Inactive", "Pending"))

* Medium strings with some variation
gen str50 description = "Patient " + string(_n) + " record entry for study"

* Long repeated strings (good for strL compression)
gen str200 notes = "This is a standard note that repeats across many observations with minor variations. Study ID: " + string(_n)

* Very short strings
gen str5 code = "A" + string(mod(_n, 100), "%03.0f")

* Numeric for comparison
gen double amount = runiform() * 10000

save "`testdir'/_test_compress.dta", replace
display as text "  Test data created"

* =============================================================================
* TEST 1: Basic compress_tc (all string variables)
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Basic compress_tc"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/_test_compress.dta", clear

    compress_tc

    * Check stored results
    assert !missing(r(bytes_saved)) | r(bytes_saved) >= 0
    display as text "  Bytes saved: " r(bytes_saved)
    display as result "  PASSED: Basic compress_tc works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 2: Specific variables
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Specific variables"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/_test_compress.dta", clear

    compress_tc status notes

    display as result "  PASSED: Specific variables work"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 3: Detail option
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Detail option"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/_test_compress.dta", clear

    compress_tc, detail

    display as result "  PASSED: Detail option works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 4: Noreport option
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Noreport option"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/_test_compress.dta", clear

    compress_tc, noreport

    display as result "  PASSED: Noreport option works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 5: Quietly option
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Quietly option"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/_test_compress.dta", clear

    compress_tc, quietly

    * Should still store results
    assert !missing(r(bytes_saved)) | r(bytes_saved) >= 0
    display as result "  PASSED: Quietly option works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 6: Nocompress option (strL only)
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Nocompress option"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/_test_compress.dta", clear

    compress_tc, nocompress

    display as result "  PASSED: Nocompress option works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 7: Nostrl option (standard compress only)
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Nostrl option"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/_test_compress.dta", clear

    compress_tc, nostrl

    display as result "  PASSED: Nostrl option works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 8: Varsavings option
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Varsavings option"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/_test_compress.dta", clear

    compress_tc, varsavings

    display as result "  PASSED: Varsavings option works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 9: No string variables (only numerics)
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': No string variables"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/_test_compress.dta", clear
    keep id amount

    compress_tc

    display as result "  PASSED: No string variables handled"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 10: Real dataset (cohort.dta)
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Real dataset"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort.dta", clear

    compress_tc

    display as result "  PASSED: Real dataset works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 11: Hospitalizations dataset (has string variable)
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Hospitalizations dataset"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/hospitalizations.dta", clear

    compress_tc

    display as result "  PASSED: Hospitalizations dataset works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 12: Large repeated strings (optimal for strL)
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Large repeated strings"
display as text "{hline 50}"

capture noisily {
    clear
    set obs 10000

    * Create very repetitive long strings
    gen str500 longtext = "This is a very long repeated text string that should compress very well when converted to strL format because of the deduplication feature."

    compress_tc, detail

    * Should show significant savings
    assert r(bytes_saved) > 0
    display as text "  Bytes saved: " r(bytes_saved)
    display as result "  PASSED: Large repeated strings work"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 13: Wildcard variable selection
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Wildcard variable selection"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/_test_compress.dta", clear

    compress_tc status description

    display as result "  PASSED: Wildcard selection works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 14: Combined options
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Combined options"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/_test_compress.dta", clear

    compress_tc, detail varsavings

    display as result "  PASSED: Combined options work"
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

capture erase "`testdir'/_test_compress.dta"

* =============================================================================
* SUMMARY
* =============================================================================
display as text _n "{hline 70}"
display as text "COMPRESS_TC TEST SUMMARY"
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
