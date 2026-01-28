/*******************************************************************************
* test_stratetab.do
*
* Purpose: Comprehensive testing of stratetab command
*          Tests all options and common combinations
*
* Prerequisites:
*   - Run generate_test_data.do first to create synthetic datasets
*   - stratetab.ado must be installed/accessible
*   - Requires strate output files (this test creates synthetic ones)
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

* Install stratetab package from local repository
capture net uninstall stratetab
net install stratetab, from("${STATA_TOOLS_PATH}/stratetab")

local testdir "${DATA_DIR}"

* Check for required test data
capture confirm file "`testdir'/cohort.dta"
if _rc {
    display as error "Test data not found. Run generate_test_data.do first."
    exit 601
}

display as text _n "{hline 70}"
display as text "STRATETAB COMMAND TESTING"
display as text "{hline 70}"
display as text "Test directory: `testdir'"
display as text "{hline 70}"

local test_count = 0
local pass_count = 0
local fail_count = 0

* =============================================================================
* SETUP: Create synthetic strate output files
* =============================================================================
display as text _n "Creating synthetic strate output files..."

* Create strate-like output for testing
* Each file needs: _D (events), _Y (person-years), _Rate, _Lower, _Upper, and grouping variable

* Outcome 1, Exposure type 1
clear
set obs 3
gen exposure = _n - 1
gen _D = 10 + floor(runiform() * 50)
gen _Y = 1000 + floor(runiform() * 5000)
gen _Rate = _D / _Y
gen _Lower = _Rate * 0.7
gen _Upper = _Rate * 1.3
label variable exposure "HRT Exposure"
label define exp_lbl 0 "Never" 1 "Former" 2 "Current"
label values exposure exp_lbl
save "`testdir'/_strate_out1_exp1.dta", replace

* Outcome 2, Exposure type 1
clear
set obs 3
gen exposure = _n - 1
gen _D = 5 + floor(runiform() * 30)
gen _Y = 1000 + floor(runiform() * 5000)
gen _Rate = _D / _Y
gen _Lower = _Rate * 0.7
gen _Upper = _Rate * 1.3
label define exp_lbl 0 "Never" 1 "Former" 2 "Current", replace
label values exposure exp_lbl
save "`testdir'/_strate_out2_exp1.dta", replace

* Outcome 3, Exposure type 1
clear
set obs 3
gen exposure = _n - 1
gen _D = 15 + floor(runiform() * 40)
gen _Y = 1000 + floor(runiform() * 5000)
gen _Rate = _D / _Y
gen _Lower = _Rate * 0.7
gen _Upper = _Rate * 1.3
label define exp_lbl 0 "Never" 1 "Former" 2 "Current", replace
label values exposure exp_lbl
save "`testdir'/_strate_out3_exp1.dta", replace

* Outcome 1, Exposure type 2 (different exposure variable)
clear
set obs 4
gen duration_cat = _n
gen _D = 8 + floor(runiform() * 40)
gen _Y = 800 + floor(runiform() * 4000)
gen _Rate = _D / _Y
gen _Lower = _Rate * 0.7
gen _Upper = _Rate * 1.3
label variable duration_cat "HRT Duration"
label define dur_lbl 1 "Never" 2 "<1 year" 3 "1-5 years" 4 ">5 years"
label values duration_cat dur_lbl
save "`testdir'/_strate_out1_exp2.dta", replace

* Outcome 2, Exposure type 2
clear
set obs 4
gen duration_cat = _n
gen _D = 4 + floor(runiform() * 25)
gen _Y = 800 + floor(runiform() * 4000)
gen _Rate = _D / _Y
gen _Lower = _Rate * 0.7
gen _Upper = _Rate * 1.3
label variable duration_cat "HRT Duration"
label define dur_lbl 1 "Never" 2 "<1 year" 3 "1-5 years" 4 ">5 years", replace
label values duration_cat dur_lbl
save "`testdir'/_strate_out2_exp2.dta", replace

* Outcome 3, Exposure type 2
clear
set obs 4
gen duration_cat = _n
gen _D = 12 + floor(runiform() * 35)
gen _Y = 800 + floor(runiform() * 4000)
gen _Rate = _D / _Y
gen _Lower = _Rate * 0.7
gen _Upper = _Rate * 1.3
label variable duration_cat "HRT Duration"
label define dur_lbl 1 "Never" 2 "<1 year" 3 "1-5 years" 4 ">5 years", replace
label values duration_cat dur_lbl
save "`testdir'/_strate_out3_exp2.dta", replace

display as text "  Synthetic strate output files created"

* =============================================================================
* TEST 1: Basic stratetab with single exposure type
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Basic stratetab (single exposure)"
display as text "{hline 50}"

capture noisily {
    stratetab, using("`testdir'/_strate_out1_exp1" "`testdir'/_strate_out2_exp1" "`testdir'/_strate_out3_exp1") ///
        xlsx("`testdir'/_test_stratetab.xlsx") outcomes(3)

    * Check output file exists
    confirm file "`testdir'/_test_stratetab.xlsx"
    display as result "  PASSED: Basic stratetab works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 2: Custom outcome labels
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Custom outcome labels"
display as text "{hline 50}"

capture noisily {
    stratetab, using("`testdir'/_strate_out1_exp1" "`testdir'/_strate_out2_exp1" "`testdir'/_strate_out3_exp1") ///
        xlsx("`testdir'/_test_stratetab_labels.xlsx") outcomes(3) ///
        outlabels("EDSS 4 \ EDSS 6 \ Relapse")

    confirm file "`testdir'/_test_stratetab_labels.xlsx"
    display as result "  PASSED: Custom outcome labels work"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 3: Custom exposure labels
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Custom exposure labels"
display as text "{hline 50}"

capture noisily {
    stratetab, using("`testdir'/_strate_out1_exp1" "`testdir'/_strate_out2_exp1" "`testdir'/_strate_out3_exp1") ///
        xlsx("`testdir'/_test_stratetab_exp.xlsx") outcomes(3) ///
        explabels("Time-Varying HRT")

    confirm file "`testdir'/_test_stratetab_exp.xlsx"
    display as result "  PASSED: Custom exposure labels work"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 4: Multiple exposure types
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Multiple exposure types"
display as text "{hline 50}"

capture noisily {
    stratetab, using("`testdir'/_strate_out1_exp1" "`testdir'/_strate_out2_exp1" "`testdir'/_strate_out3_exp1" "`testdir'/_strate_out1_exp2" "`testdir'/_strate_out2_exp2" "`testdir'/_strate_out3_exp2") ///
        xlsx("`testdir'/_test_stratetab_multi.xlsx") outcomes(3) ///
        outlabels("EDSS 4 \ EDSS 6 \ Relapse") ///
        explabels("Time-Varying \ Duration")

    confirm file "`testdir'/_test_stratetab_multi.xlsx"
    display as result "  PASSED: Multiple exposure types work"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 5: Custom sheet name
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Custom sheet name"
display as text "{hline 50}"

capture noisily {
    stratetab, using("`testdir'/_strate_out1_exp1" "`testdir'/_strate_out2_exp1" "`testdir'/_strate_out3_exp1") ///
        xlsx("`testdir'/_test_stratetab_sheet.xlsx") outcomes(3) ///
        sheet("Table 2")

    confirm file "`testdir'/_test_stratetab_sheet.xlsx"
    display as result "  PASSED: Custom sheet name works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 6: Title option
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Title option"
display as text "{hline 50}"

capture noisily {
    stratetab, using("`testdir'/_strate_out1_exp1" "`testdir'/_strate_out2_exp1" "`testdir'/_strate_out3_exp1") ///
        xlsx("`testdir'/_test_stratetab_title.xlsx") outcomes(3) ///
        title("Table 2. Unadjusted incidence rates by HRT exposure")

    confirm file "`testdir'/_test_stratetab_title.xlsx"
    display as result "  PASSED: Title option works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 7: Custom digits
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Custom digits"
display as text "{hline 50}"

capture noisily {
    stratetab, using("`testdir'/_strate_out1_exp1" "`testdir'/_strate_out2_exp1" "`testdir'/_strate_out3_exp1") ///
        xlsx("`testdir'/_test_stratetab_digits.xlsx") outcomes(3) ///
        digits(2)

    confirm file "`testdir'/_test_stratetab_digits.xlsx"
    display as result "  PASSED: Custom digits work"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 8: Event digits option
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Event digits option"
display as text "{hline 50}"

capture noisily {
    stratetab, using("`testdir'/_strate_out1_exp1" "`testdir'/_strate_out2_exp1" "`testdir'/_strate_out3_exp1") ///
        xlsx("`testdir'/_test_stratetab_evtdig.xlsx") outcomes(3) ///
        eventdigits(1)

    confirm file "`testdir'/_test_stratetab_evtdig.xlsx"
    display as result "  PASSED: Event digits work"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 9: Person-years digits
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Person-years digits"
display as text "{hline 50}"

capture noisily {
    stratetab, using("`testdir'/_strate_out1_exp1" "`testdir'/_strate_out2_exp1" "`testdir'/_strate_out3_exp1") ///
        xlsx("`testdir'/_test_stratetab_pydig.xlsx") outcomes(3) ///
        pydigits(1)

    confirm file "`testdir'/_test_stratetab_pydig.xlsx"
    display as result "  PASSED: Person-years digits work"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 10: Custom rate scale
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Custom rate scale"
display as text "{hline 50}"

capture noisily {
    stratetab, using("`testdir'/_strate_out1_exp1" "`testdir'/_strate_out2_exp1" "`testdir'/_strate_out3_exp1") ///
        xlsx("`testdir'/_test_stratetab_scale.xlsx") outcomes(3) ///
        ratescale(100) unitlabel("100")

    confirm file "`testdir'/_test_stratetab_scale.xlsx"
    display as result "  PASSED: Custom rate scale works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 11: PY scale option
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': PY scale option"
display as text "{hline 50}"

capture noisily {
    stratetab, using("`testdir'/_strate_out1_exp1" "`testdir'/_strate_out2_exp1" "`testdir'/_strate_out3_exp1") ///
        xlsx("`testdir'/_test_stratetab_pyscale.xlsx") outcomes(3) ///
        pyscale(1000)

    confirm file "`testdir'/_test_stratetab_pyscale.xlsx"
    display as result "  PASSED: PY scale works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 12: Full options combination
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Full options combination"
display as text "{hline 50}"

capture noisily {
    stratetab, using("`testdir'/_strate_out1_exp1" "`testdir'/_strate_out2_exp1" "`testdir'/_strate_out3_exp1" "`testdir'/_strate_out1_exp2" "`testdir'/_strate_out2_exp2" "`testdir'/_strate_out3_exp2") ///
        xlsx("`testdir'/_test_stratetab_full.xlsx") outcomes(3) ///
        sheet("Table 2") title("Table 2. Rates by Exposure") ///
        outlabels("EDSS 4 \ EDSS 6 \ Relapse") ///
        explabels("Time-Varying \ Duration") ///
        digits(2) eventdigits(0) pydigits(0)

    confirm file "`testdir'/_test_stratetab_full.xlsx"
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

* Remove strate files
local strate_files "_strate_out1_exp1 _strate_out2_exp1 _strate_out3_exp1 _strate_out1_exp2 _strate_out2_exp2 _strate_out3_exp2"
foreach f of local strate_files {
    capture erase "`testdir'/`f'.dta"
}

* Remove output files
local output_files "_test_stratetab _test_stratetab_labels _test_stratetab_exp _test_stratetab_multi _test_stratetab_sheet _test_stratetab_title _test_stratetab_digits _test_stratetab_evtdig _test_stratetab_pydig _test_stratetab_scale _test_stratetab_pyscale _test_stratetab_full"
foreach f of local output_files {
    capture erase "`testdir'/`f'.xlsx"
}

* =============================================================================
* SUMMARY
* =============================================================================
display as text _n "{hline 70}"
display as text "STRATETAB TEST SUMMARY"
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
