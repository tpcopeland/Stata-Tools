/*******************************************************************************
* test_mvp.do
*
* Purpose: Comprehensive testing of mvp (Missing Value Patterns) command
*          Tests all options and common combinations
*
* Prerequisites:
*   - Run generate_test_data.do first to create synthetic datasets
*   - mvp.ado must be installed/accessible
*
* Author: Timothy P Copeland
* Date: 2025-12-05
*******************************************************************************/

clear all
set more off
version 16.0

* Get directory of this do file
local testdir = c(pwd)

* Check for required test data
capture confirm file "`testdir'/cohort_miss.dta"
if _rc {
    display as error "Test data not found. Run generate_test_data.do first."
    exit 601
}

display as text _n "{hline 70}"
display as text "MVP COMMAND TESTING"
display as text "{hline 70}"
display as text "Test directory: `testdir'"
display as text "{hline 70}"

local test_count = 0
local pass_count = 0
local fail_count = 0

* =============================================================================
* TEST 1: Basic missing value pattern analysis
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Basic missing value pattern analysis"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort_miss.dta", clear

    mvp age education bmi income_q comorbidity smoking

    * Check stored results
    assert !missing(r(nvars))
    assert r(nvars) == 6
    display as result "  PASSED: Basic pattern analysis works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 2: All variables
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': All variables"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort_miss.dta", clear

    mvp _all

    display as result "  PASSED: All variables analysis works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 3: Pattern count option
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Pattern count option"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort_miss.dta", clear

    mvp age education bmi income_q, patterns(10)

    display as result "  PASSED: Pattern count option works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 4: Sort by frequency
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Sort by frequency"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort_miss.dta", clear

    mvp age education bmi income_q, sort(freq)

    display as result "  PASSED: Sort by frequency works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 5: Sort by variable name
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Sort by variable name"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort_miss.dta", clear

    mvp age education bmi income_q, sort(varname)

    display as result "  PASSED: Sort by varname works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 6: Minimum frequency threshold
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Minimum frequency threshold"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort_miss.dta", clear

    mvp age education bmi income_q comorbidity smoking, minfreq(5)

    display as result "  PASSED: Minimum frequency threshold works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 7: Matrix output
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Matrix output"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort_miss.dta", clear

    mvp age education bmi income_q, matrix(mvp_patterns)

    * Check that matrix was created
    matrix list mvp_patterns
    display as result "  PASSED: Matrix output works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 8: Generate pattern variable
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Generate pattern variable"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort_miss.dta", clear

    mvp age education bmi income_q, gen(miss_pattern)

    * Check that variable was created
    confirm variable miss_pattern
    tab miss_pattern
    display as result "  PASSED: Generate pattern variable works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 9: Detail option
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Detail option"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort_miss.dta", clear

    mvp age education bmi income_q comorbidity smoking, detail

    display as result "  PASSED: Detail option works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 10: Variable summary statistics
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Variable summary statistics"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort_miss.dta", clear

    mvp age education bmi income_q, varsummary

    display as result "  PASSED: Variable summary works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 11: No missing values scenario
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': No missing values scenario"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort.dta", clear  // Complete dataset

    * Variables without missing
    mvp female mstype region

    display as result "  PASSED: No missing values scenario handled"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 12: All missing in one variable
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': All missing in one variable"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort_miss.dta", clear

    * Create a variable with all missing
    gen all_missing = .

    mvp age all_missing education

    drop all_missing
    display as result "  PASSED: All missing variable handled"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 13: Correlation between missingness
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Correlation analysis"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort_miss.dta", clear

    mvp age education bmi income_q comorbidity smoking, corr

    display as result "  PASSED: Correlation analysis works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 14: If condition
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': If condition"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort_miss.dta", clear

    mvp age education bmi income_q if female == 1

    display as result "  PASSED: If condition works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 15: In range
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': In range"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort_miss.dta", clear

    mvp age education bmi income_q in 1/500

    display as result "  PASSED: In range works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 16: HRT dataset with missingness
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': HRT dataset missingness"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/hrt_miss.dta", clear

    mvp hrt_type dose

    display as result "  PASSED: HRT dataset missingness works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 17: DMT dataset with missingness
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': DMT dataset missingness"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/dmt_miss.dta", clear

    mvp dmt efficacy

    display as result "  PASSED: DMT dataset missingness works"
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
display as text "MVP TEST SUMMARY"
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
