/*******************************************************************************
* test_regtab.do
*
* Purpose: Comprehensive testing of regtab command
*          Tests all options and common combinations
*
* Prerequisites:
*   - Run generate_test_data.do first to create synthetic datasets
*   - regtab.ado must be installed/accessible
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

* Install regtab package from local repository
capture net uninstall regtab
net install regtab, from("${STATA_TOOLS_PATH}/regtab")

local testdir "${DATA_DIR}"

* Check for required test data
capture confirm file "`testdir'/cohort.dta"
if _rc {
    display as error "Test data not found. Run generate_test_data.do first."
    exit 601
}

display as text _n "{hline 70}"
display as text "REGTAB COMMAND TESTING"
display as text "{hline 70}"
display as text "Test directory: `testdir'"
display as text "{hline 70}"

local test_count = 0
local pass_count = 0
local fail_count = 0

* =============================================================================
* SETUP: Load data and prepare for regression
* =============================================================================
display as text _n "Setting up regression data..."

use "`testdir'/cohort.dta", clear

* Create outcome variable
gen outcome = !missing(edss4_dt)

* Create exposure variable
gen high_edss = edss_baseline >= 3

display as text "  Regression data ready"

* =============================================================================
* TEST 1: Basic single model
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Basic single model"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort.dta", clear
    gen outcome = !missing(edss4_dt)

    collect clear
    collect: logit outcome age female i.mstype

    regtab, xlsx("`testdir'/_test_regtab.xlsx") sheet("Table 1") coef("OR")

    confirm file "`testdir'/_test_regtab.xlsx"
    display as result "  PASSED: Basic single model works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 2: With title
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': With title"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort.dta", clear
    gen outcome = !missing(edss4_dt)

    collect clear
    collect: logit outcome age female i.mstype

    regtab, xlsx("`testdir'/_test_regtab_title.xlsx") sheet("Table 1") ///
        coef("OR") title("Table 1. Logistic Regression Results")

    confirm file "`testdir'/_test_regtab_title.xlsx"
    display as result "  PASSED: Title option works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 3: Multiple models
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Multiple models"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort.dta", clear
    gen outcome = !missing(edss4_dt)

    collect clear
    collect: logit outcome age female
    collect: logit outcome age female i.mstype
    collect: logit outcome age female i.mstype bmi

    regtab, xlsx("`testdir'/_test_regtab_multi.xlsx") sheet("Table 2") ///
        coef("OR") models("Crude \ Adjusted \ Full")

    confirm file "`testdir'/_test_regtab_multi.xlsx"
    display as result "  PASSED: Multiple models work"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 4: Drop intercept
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Drop intercept (noint)"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort.dta", clear
    gen outcome = !missing(edss4_dt)

    collect clear
    collect: logit outcome age female i.mstype

    regtab, xlsx("`testdir'/_test_regtab_noint.xlsx") sheet("Table 1") ///
        coef("OR") noint

    confirm file "`testdir'/_test_regtab_noint.xlsx"
    display as result "  PASSED: noint option works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 5: Custom CI separator
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Custom CI separator"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort.dta", clear
    gen outcome = !missing(edss4_dt)

    collect clear
    collect: logit outcome age female i.mstype

    regtab, xlsx("`testdir'/_test_regtab_sep.xlsx") sheet("Table 1") ///
        coef("OR") sep("; ")

    confirm file "`testdir'/_test_regtab_sep.xlsx"
    display as result "  PASSED: Custom separator works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 6: Linear regression (coefficient)
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Linear regression"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort.dta", clear

    collect clear
    collect: regress bmi age female i.mstype

    regtab, xlsx("`testdir'/_test_regtab_linear.xlsx") sheet("Table 1") ///
        coef("Coef.") title("Table 1. Linear Regression")

    confirm file "`testdir'/_test_regtab_linear.xlsx"
    display as result "  PASSED: Linear regression works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 7: Cox regression (HR)
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Cox regression"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort.dta", clear

    * Set up survival data
    gen follow_time = study_exit - study_entry
    gen event = !missing(edss4_dt) & edss4_dt <= study_exit
    replace follow_time = edss4_dt - study_entry if event == 1
    keep if follow_time > 0

    stset follow_time, failure(event)

    collect clear
    collect: stcox age female i.mstype

    regtab, xlsx("`testdir'/_test_regtab_cox.xlsx") sheet("Table 1") ///
        coef("HR") title("Table 1. Hazard Ratios")

    confirm file "`testdir'/_test_regtab_cox.xlsx"
    display as result "  PASSED: Cox regression works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 8: Poisson regression (RR)
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Poisson regression"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort.dta", clear

    * Create count outcome
    gen n_events = ceil(runiform() * 5)

    collect clear
    collect: poisson n_events age female i.mstype, irr

    regtab, xlsx("`testdir'/_test_regtab_poisson.xlsx") sheet("Table 1") ///
        coef("IRR") title("Table 1. Incidence Rate Ratios")

    confirm file "`testdir'/_test_regtab_poisson.xlsx"
    display as result "  PASSED: Poisson regression works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 9: Multiple models with different adjustments
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Progressive adjustment"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort.dta", clear
    gen outcome = !missing(edss4_dt)

    collect clear
    collect: logit outcome i.mstype
    collect: logit outcome i.mstype age
    collect: logit outcome i.mstype age female
    collect: logit outcome i.mstype age female i.region

    regtab, xlsx("`testdir'/_test_regtab_prog.xlsx") sheet("Table 1") ///
        coef("OR") models("Unadj \ +Age \ +Sex \ +Region") ///
        title("Table 1. Progressive Adjustment") noint

    confirm file "`testdir'/_test_regtab_prog.xlsx"
    display as result "  PASSED: Progressive adjustment works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 10: Full options combination
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Full options combination"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort.dta", clear
    gen outcome = !missing(edss4_dt)

    collect clear
    collect: logit outcome age female i.mstype
    collect: logit outcome age female i.mstype bmi i.smoking

    regtab, xlsx("`testdir'/_test_regtab_full.xlsx") sheet("Results") ///
        coef("OR") models("Basic \ Extended") ///
        title("Table 3. Odds Ratios for EDSS 4 Progression") ///
        sep(", ") noint

    confirm file "`testdir'/_test_regtab_full.xlsx"
    display as result "  PASSED: Full options work"
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

local output_files "_test_regtab _test_regtab_title _test_regtab_multi _test_regtab_noint _test_regtab_sep _test_regtab_linear _test_regtab_cox _test_regtab_poisson _test_regtab_prog _test_regtab_full"
foreach f of local output_files {
    capture erase "`testdir'/`f'.xlsx"
}

* =============================================================================
* SUMMARY
* =============================================================================
display as text _n "{hline 70}"
display as text "REGTAB TEST SUMMARY"
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
