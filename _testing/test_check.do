/*******************************************************************************
* test_check.do
*
* Purpose: Comprehensive testing of check command
*          Tests all options and common combinations
*
* Prerequisites:
*   - Run generate_test_data.do first to create synthetic datasets
*   - check.ado must be installed/accessible
*
* Author: Timothy P Copeland
* Date: 2025-12-05
*******************************************************************************/

clear all
set more off
version 16.0

* =============================================================================
* SETUP: Change to data directory and install package from local repository
* =============================================================================

* Data directory for test datasets
cd "/Users/tcopeland/Documents/GitHub/Stata-Tools/_testing/data/"

* Install check package from local repository
local basedir "/Users/tcopeland/Documents/GitHub/Stata-Tools"
capture net uninstall check
net install check, from("`basedir'/check")

local testdir "`c(pwd)'"

* Check for required test data
capture confirm file "`testdir'/cohort.dta"
if _rc {
    display as error "Test data not found. Run generate_test_data.do first."
    exit 601
}

display as text _n "{hline 70}"
display as text "CHECK COMMAND TESTING"
display as text "{hline 70}"
display as text "Test directory: `testdir'"
display as text "{hline 70}"

local test_count = 0
local pass_count = 0
local fail_count = 0

* =============================================================================
* TEST 1: Check single variable
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Check single variable"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort.dta", clear

    check age

    * Verify stored results
    assert r(nvars) == 1
    display as result "  PASSED: Single variable check works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 2: Check multiple variables
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Check multiple variables"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort.dta", clear

    check age female mstype edss_baseline region

    assert r(nvars) == 5
    display as result "  PASSED: Multiple variables check works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 3: Check all variables
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Check all variables"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort.dta", clear

    check _all

    display as result "  PASSED: All variables check works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 4: Short option
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Short option"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort.dta", clear

    check age female mstype, short

    assert r(mode) == "short"
    display as result "  PASSED: Short option works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 5: Variable with missing values
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Variable with missing values"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort_miss.dta", clear

    check age education bmi

    display as result "  PASSED: Missing values handled"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 6: Numeric variable types
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Different numeric types"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort.dta", clear

    check age female edss_baseline bmi

    display as result "  PASSED: Different numeric types handled"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 7: Date variables
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Date variables"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort.dta", clear

    check study_entry study_exit edss4_dt

    display as result "  PASSED: Date variables handled"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 8: Variable with wildcard pattern
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Wildcard pattern"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort.dta", clear

    check edss*

    display as result "  PASSED: Wildcard pattern works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 9: HRT dataset
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': HRT dataset"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/hrt.dta", clear

    check _all

    display as result "  PASSED: HRT dataset check works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 10: DMT dataset
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': DMT dataset"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/dmt.dta", clear

    check _all

    display as result "  PASSED: DMT dataset check works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 11: All missing variable
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': All missing variable"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort.dta", clear

    gen all_missing = .

    check all_missing age

    drop all_missing
    display as result "  PASSED: All missing variable handled"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 12: Zero variance variable
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Zero variance variable"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort.dta", clear

    gen constant = 5

    check constant age

    drop constant
    display as result "  PASSED: Zero variance variable handled"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 13: String variable (should show limited stats)
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': String variable"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/hospitalizations.dta", clear

    check icd_code

    display as result "  PASSED: String variable handled"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 14: Labeled variable
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Labeled variable"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort.dta", clear

    check mstype female region

    display as result "  PASSED: Labeled variables handled"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 15: Large dataset performance
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Performance check"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort.dta", clear

    timer clear 1
    timer on 1

    check _all

    timer off 1
    quietly timer list 1
    local elapsed = r(t1)

    display as text "  Checked all variables in " %5.2f `elapsed' " seconds"
    display as result "  PASSED: Performance is acceptable"
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
display as text "CHECK TEST SUMMARY"
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
