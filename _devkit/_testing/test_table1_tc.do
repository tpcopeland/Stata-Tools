/*******************************************************************************
* test_table1_tc.do
*
* Purpose: Comprehensive testing of table1_tc command
*          Tests all options and common combinations
*
* Prerequisites:
*   - Run generate_test_data.do first to create synthetic datasets
*   - table1_tc.ado must be installed/accessible
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

* Install table1_tc package from local repository
capture net uninstall table1_tc
net install table1_tc, from("${STATA_TOOLS_PATH}/table1_tc")

local testdir "${DATA_DIR}"

* Check for required test data
capture confirm file "`testdir'/cohort.dta"
if _rc {
    display as error "Test data not found. Run generate_test_data.do first."
    exit 601
}

display as text _n "{hline 70}"
display as text "TABLE1_TC COMMAND TESTING"
display as text "{hline 70}"
display as text "Test directory: `testdir'"
display as text "{hline 70}"

local test_count = 0
local pass_count = 0
local fail_count = 0

* =============================================================================
* TEST 1: Basic table without grouping
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Basic table without grouping"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort.dta", clear

    table1_tc, vars(age contn \ female bin \ mstype cat \ edss_baseline conts)

    display as result "  PASSED: Basic table works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 2: Table with grouping (by sex)
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Table with grouping"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort.dta", clear

    table1_tc, by(female) vars(age contn \ mstype cat \ edss_baseline conts \ region cat)

    display as result "  PASSED: Grouped table works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 3: Total column option
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Total column before"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort.dta", clear

    table1_tc, by(female) vars(age contn \ mstype cat) total(before)

    display as result "  PASSED: Total before works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 4: Total column after
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Total column after"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort.dta", clear

    table1_tc, by(female) vars(age contn \ mstype cat) total(after)

    display as result "  PASSED: Total after works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 5: One column format
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': One column format"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort.dta", clear

    table1_tc, by(female) vars(age contn \ mstype cat \ region cat) onecol

    display as result "  PASSED: One column format works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 6: Test statistic column
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Test statistic column"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort.dta", clear

    table1_tc, by(female) vars(age contn \ mstype cat \ edss_baseline conts) test statistic

    display as result "  PASSED: Test statistic column works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 7: Excel export
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Excel export"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort.dta", clear

    table1_tc, by(female) vars(age contn \ mstype cat \ bmi contn) ///
        excel("`testdir'/_test_table1.xlsx") sheet("Table 1") ///
        title("Table 1. Baseline Characteristics")

    * Check file was created
    confirm file "`testdir'/_test_table1.xlsx"
    display as result "  PASSED: Excel export works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 8: Custom format for continuous variables
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Custom format"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort.dta", clear

    table1_tc, by(female) vars(age contn %5.1f \ bmi contn %5.2f \ edss_baseline conts %4.1f) format(%5.2f)

    display as result "  PASSED: Custom format works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 9: Binary with exact test
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Binary with exact test"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort.dta", clear

    * Create a binary variable
    gen high_edss = edss_baseline >= 4

    table1_tc, by(female) vars(high_edss bine) test

    display as result "  PASSED: Binary exact test works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 10: Categorical with exact test
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Categorical with exact test"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort.dta", clear

    table1_tc, by(female) vars(mstype cate \ education cate) test

    display as result "  PASSED: Categorical exact test works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 11: Log-normal continuous
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Log-normal continuous"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort.dta", clear

    * BMI is somewhat log-normal
    table1_tc, by(female) vars(bmi contln) test

    display as result "  PASSED: Log-normal continuous works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 12: Missing category option
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Missing category option"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort_miss.dta", clear

    table1_tc, by(female) vars(education cat \ smoking cat) missing

    display as result "  PASSED: Missing category option works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 13: Header percentage option
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Header percentage option"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort.dta", clear

    table1_tc, by(female) vars(age contn \ mstype cat) headerperc

    display as result "  PASSED: Header percentage works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 14: Percent only (no n)
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Percent only"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort.dta", clear

    table1_tc, by(female) vars(mstype cat \ region cat) percent

    display as result "  PASSED: Percent only works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 15: Percent (n) format
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Percent (n) format"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort.dta", clear

    table1_tc, by(female) vars(mstype cat \ region cat) percent_n

    display as result "  PASSED: Percent (n) format works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 16: n/N format
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': n/N format"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort.dta", clear

    table1_tc, by(female) vars(mstype cat \ education cat) slashN

    display as result "  PASSED: n/N format works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 17: Custom IQR separator
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Custom IQR separator"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort.dta", clear

    table1_tc, by(female) vars(edss_baseline conts \ bmi conts) iqrmiddle(", ")

    display as result "  PASSED: Custom IQR separator works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 18: Custom SD format
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Custom SD format"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort.dta", clear

    table1_tc, by(female) vars(age contn \ bmi contn) sdleft(" [") sdright("]")

    display as result "  PASSED: Custom SD format works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 19: If condition
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': If condition"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort.dta", clear

    table1_tc if mstype == 1, by(female) vars(age contn \ edss_baseline conts)

    display as result "  PASSED: If condition works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 20: Clear option (replace data with table)
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Clear option"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort.dta", clear

    table1_tc, by(female) vars(age contn \ mstype cat) clear

    * Data should now be the table
    assert _N > 0
    display as result "  PASSED: Clear option works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 21: Pairwise comparisons
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Pairwise comparisons"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort.dta", clear

    * Create 3 groups for pairwise
    gen group3 = cond(region <= 2, 1, cond(region <= 4, 2, 3))
    label define grp3_lbl 1 "North" 2 "Central" 3 "South"
    label values group3 grp3_lbl

    table1_tc, by(group3) vars(age contn \ edss_baseline conts \ female bin) pairwise123 test

    display as result "  PASSED: Pairwise comparisons work"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 22: Row percentages
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Row percentages"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort.dta", clear

    table1_tc, by(female) vars(mstype cat \ region cat) catrowperc

    display as result "  PASSED: Row percentages work"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 23: Gurmeet style
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Gurmeet style"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort.dta", clear

    table1_tc, by(female) vars(age contn \ edss_baseline conts \ mstype cat) gurmeet

    display as result "  PASSED: Gurmeet style works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 24: Thin border style
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Thin border style Excel"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort.dta", clear

    table1_tc, by(female) vars(age contn \ mstype cat) ///
        excel("`testdir'/_test_table1_thin.xlsx") sheet("Table 1") ///
        title("Table 1") borderstyle(thin)

    confirm file "`testdir'/_test_table1_thin.xlsx"
    display as result "  PASSED: Thin border style works"
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

capture erase "`testdir'/_test_table1.xlsx"
capture erase "`testdir'/_test_table1_thin.xlsx"

* =============================================================================
* SUMMARY
* =============================================================================
display as text _n "{hline 70}"
display as text "TABLE1_TC TEST SUMMARY"
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
