/*******************************************************************************
* test_cstat_surv.do
*
* Purpose: Comprehensive testing of cstat_surv command
*          Tests all options and common combinations
*
* Prerequisites:
*   - Run generate_test_data.do first to create synthetic datasets
*   - cstat_surv.ado must be installed/accessible
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

* Install cstat_surv package from local repository
capture net uninstall cstat_surv
net install cstat_surv, from("${STATA_TOOLS_PATH}/cstat_surv")

local testdir "${DATA_DIR}"

* Check for required test data
capture confirm file "`testdir'/cohort.dta"
if _rc {
    display as error "Test data not found. Run generate_test_data.do first."
    exit 601
}

display as text _n "{hline 70}"
display as text "CSTAT_SURV COMMAND TESTING"
display as text "{hline 70}"
display as text "Test directory: `testdir'"
display as text "{hline 70}"

local test_count = 0
local pass_count = 0
local fail_count = 0

* =============================================================================
* SETUP: Prepare survival dataset
* =============================================================================
display as text _n "Setting up survival analysis data..."

use "`testdir'/cohort.dta", clear

* Create follow-up time and event indicator
gen follow_time = study_exit - study_entry
gen event = !missing(edss4_dt) & edss4_dt <= study_exit

* Adjust follow-up for events
replace follow_time = edss4_dt - study_entry if event == 1

* Ensure positive follow-up
keep if follow_time > 0

label variable follow_time "Follow-up time (days)"
label variable event "EDSS 4 event"

* Set up survival data
stset follow_time, failure(event)

save "`testdir'/_surv_cohort.dta", replace
display as text "  Survival dataset ready: " _N " observations"

* =============================================================================
* TEST 1: Basic C-statistic after stcox
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Basic C-statistic"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/_surv_cohort.dta", clear

    stcox age female

    cstat_surv

    * Check stored results
    assert !missing(e(c))
    assert e(c) >= 0 & e(c) <= 1
    display as text "  C-statistic: " %6.4f e(c) " (SE: " %6.4f e(se) ")"
    display as result "  PASSED: Basic C-statistic works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 2: Multiple covariates
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Multiple covariates"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/_surv_cohort.dta", clear

    stcox age female i.mstype

    cstat_surv

    assert !missing(e(c))
    display as text "  C-statistic: " %6.4f e(c)
    display as result "  PASSED: Multiple covariates work"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 3: Model with categorical variable
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Categorical variable"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/_surv_cohort.dta", clear

    stcox i.female i.mstype 

    cstat_surv

    assert !missing(e(c))
    display as text "  C-statistic: " %6.4f e(c)
    display as result "  PASSED: Categorical variables work"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 4: Single predictor
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Single predictor"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/_surv_cohort.dta", clear

    stcox female

    cstat_surv

    assert !missing(e(c))
    display as text "  C-statistic: " %6.4f e(c)
    display as result "  PASSED: Single predictor works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 5: Check confidence interval
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Confidence interval"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/_surv_cohort.dta", clear

    stcox age female 

    cstat_surv

    * Check CI bounds
    assert e(ci_lo) < e(c)
    assert e(ci_hi) > e(c)
    assert e(ci_lo) >= 0
    assert e(ci_hi) <= 1
    display as text "  95% CI: (" %6.4f e(ci_lo) ", " %6.4f e(ci_hi) ")"
    display as result "  PASSED: Confidence interval is valid"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 6: Check pair counts
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Pair counts"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/_surv_cohort.dta", clear

    stcox age female

    cstat_surv

    * Check pair counts are reasonable
    assert e(N_comparable) > 0
    assert e(N_concordant) >= 0
    assert e(N_discordant) >= 0
    assert e(N_tied) >= 0
    display as text "  Comparable pairs: " e(N_comparable)
    display as text "  Concordant: " e(N_concordant)
    display as text "  Discordant: " e(N_discordant)
    display as result "  PASSED: Pair counts are valid"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 7: Stratified Cox model
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Stratified Cox model"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/_surv_cohort.dta", clear

    stcox age female, strata(mstype)

    cstat_surv

    assert !missing(e(c))
    display as text "  C-statistic: " %6.4f e(c)
    display as result "  PASSED: Stratified model works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 8: Model with interaction
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Model with interaction"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/_surv_cohort.dta", clear

    stcox age c.age#i.female 

    cstat_surv

    assert !missing(e(c))
    display as text "  C-statistic: " %6.4f e(c)
    display as result "  PASSED: Interaction terms work"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 9: Compare simple vs complex model
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Compare simple vs complex model"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/_surv_cohort.dta", clear

    * Simple model
    stcox age
    cstat_surv
    local c_simple = e(c)

    * Complex model
    stcox age female i.mstype bmi
    cstat_surv
    local c_complex = e(c)

    display as text "  Simple model C: " %6.4f `c_simple'
    display as text "  Complex model C: " %6.4f `c_complex'


    * Complex should generally be >= simple (more information)
    display as result "  PASSED: Model comparison completed"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 10: Subset of data
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Subset of data"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/_surv_cohort.dta", clear

    * Females only
    keep if female == 1

    stset follow_time, failure(event)
    stcox age i.mstype

    cstat_surv

    assert !missing(e(c))
    display as text "  C-statistic (females only): " %6.4f e(c)
    display as result "  PASSED: Subset analysis works"
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

capture erase "`testdir'/_surv_cohort.dta"

* =============================================================================
* SUMMARY
* =============================================================================
display as text _n "{hline 70}"
display as text "CSTAT_SURV TEST SUMMARY"
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
