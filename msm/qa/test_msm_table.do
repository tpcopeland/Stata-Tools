* test_msm_table.do - msm_table workbook export tests (T2) (split from test_msm.do per audit Q01, preserving every assertion)
*
* Location: msm/qa/

version 16.0
clear all
set more off
set varabbrev off


* === Bootstrap ===
local qa_dir  "`c(pwd)'"
local pkg_dir "`qa_dir'/.."

do "`qa_dir'/_install_msm_isolated.do" "`pkg_dir'"

local pass_count = 0
local fail_count = 0
local test_count = 0
local failed_tests ""

* =============================================================================
* T2: TABLE EXPORT TESTS
* =============================================================================

* Load example data and run full pipeline for table tests
use "`pkg_dir'/msm_example.dta", clear

* Step 1: Prepare
msm_prepare, id(id) period(period) treatment(treatment) ///
    outcome(outcome) covariates(biomarker comorbidity) ///
    baseline(age sex) censor(censored)

* Step 2: Weight
msm_weight, treat_d_cov(biomarker comorbidity age sex) ///
    treat_n_cov(age sex) truncate(1 99)

* Step 3: Fit
msm_fit, outcome_cov(age sex) model(logistic) period_spec(quadratic) nolog

* Step 4: Predict
msm_predict, times(3 5 7) difference seed(12345)

* Step 5: Diagnose
msm_diagnose, balance_covariates(biomarker comorbidity age sex)

* Step 6: Sensitivity
msm_sensitivity, evalue

* --- Table Test 1: All tables with eform ---
local ++test_count

capture erase "/tmp/test_msm_all.xlsx"
capture noisily msm_table, xlsx("/tmp/test_msm_all.xlsx") all eform replace

if _rc == 0 {
    capture confirm file "/tmp/test_msm_all.xlsx"
    if _rc == 0 {
        local _all_sheets_ok 1
        preserve
        foreach _sheet in Coefficients Predictions Balance Weights Sensitivity {
            capture import excel "/tmp/test_msm_all.xlsx", sheet("`_sheet'") clear
            if _rc local _all_sheets_ok 0
        }
        restore

        if `_all_sheets_ok' {
            display as result "  PASS: all tables exported"
            local ++pass_count
        }
        else {
            display as error "  FAIL: all-workbook missing expected sheets"
            local ++fail_count
            local failed_tests "`failed_tests' Table1"
        }
    }
    else {
        display as error "  FAIL: file not created (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' Table1"
    }
}
else {
    display as error "  FAIL: msm_table returned error (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' Table1"
}

* --- Table Test 2: Coefficients only ---
local ++test_count

capture erase "/tmp/test_msm_coef.xlsx"
capture noisily msm_table, xlsx("/tmp/test_msm_coef.xlsx") coefficients eform replace

if _rc == 0 {
    display as result "  PASS: coefficients table exported"
    local ++pass_count
}
else {
    display as error "  FAIL: coefficients export error (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' Table2"
}

* --- Table Test 3: Predictions only ---
local ++test_count

capture erase "/tmp/test_msm_pred.xlsx"
capture noisily msm_table, xlsx("/tmp/test_msm_pred.xlsx") predictions replace

if _rc == 0 {
    display as result "  PASS: predictions table exported"
    local ++pass_count
}
else {
    display as error "  FAIL: predictions export error (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' Table3"
}

* --- Table Test 4: Balance and weights ---
local ++test_count

capture erase "/tmp/test_msm_bal.xlsx"
capture noisily msm_table, xlsx("/tmp/test_msm_bal.xlsx") balance weights replace

if _rc == 0 {
    display as result "  PASS: balance + weights exported"
    local ++pass_count
}
else {
    display as error "  FAIL: balance/weights export error (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' Table4"
}

* --- Table Test 5: Sensitivity only ---
local ++test_count

capture erase "/tmp/test_msm_sens.xlsx"
capture noisily msm_table, xlsx("/tmp/test_msm_sens.xlsx") sensitivity replace

if _rc == 0 {
    display as result "  PASS: sensitivity table exported"
    local ++pass_count
}
else {
    display as error "  FAIL: sensitivity export error (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' Table5"
}

* --- Table Test 6: Verify coefficients values via re-import ---
local ++test_count

preserve
import excel "/tmp/test_msm_coef.xlsx", sheet("Coefficients") clear
* Row 1 = title, Row 2 = headers, Row 3+ = data
local _expected_or = exp(_msm_fit_b[1, 1])
* Check that row 3 reflects the fitted treatment effect, not row indices
capture assert A[3] != "" & abs(real(B[3]) - `_expected_or') < 0.01 & ///
    strpos(C[3], "(") > 0 & D[3] != "3"
if _rc == 0 {
    display as result "  PASS: coefficients data verified"
    local ++pass_count
}
else {
    display as error "  FAIL: coefficients re-import check (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' Table6"
}
restore

* --- Table Test 7: Verify predictions via re-import ---
local ++test_count

preserve
import excel "/tmp/test_msm_pred.xlsx", sheet("Predictions") clear
* Row 4 = first data row (title + group header + column header)
* Should have period values
capture assert A[4] != ""
if _rc == 0 {
    display as result "  PASS: predictions data verified"
    local ++pass_count
}
else {
    display as error "  FAIL: predictions re-import check (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' Table7"
}
restore

* --- Table Test 8: Verify balance via re-import ---
local ++test_count

preserve
import excel "/tmp/test_msm_bal.xlsx", sheet("Balance") clear
* Row 3+ = data, should have covariate names
capture assert A[3] != "" & B[3] != ""
if _rc == 0 {
    display as result "  PASS: balance data verified"
    local ++pass_count
}
else {
    display as error "  FAIL: balance re-import check (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' Table8"
}
restore

* --- Table Test 9: Error - no .xlsx extension ---
local ++test_count

capture noisily msm_table, xlsx("/tmp/test.csv") replace
if _rc == 198 {
    display as result "  PASS: rejected non-xlsx extension"
    local ++pass_count
}
else {
    display as error "  FAIL: expected error 198, got `=_rc'"
    local ++fail_count
    local failed_tests "`failed_tests' Table9"
}

* --- Table Test 10: Error - file exists without replace ---
local ++test_count

capture noisily msm_table, xlsx("/tmp/test_msm_all.xlsx") all eform
if _rc == 602 {
    display as result "  PASS: rejected existing file without replace"
    local ++pass_count
}
else {
    display as error "  FAIL: expected error 602, got `=_rc'"
    local ++fail_count
    local failed_tests "`failed_tests' Table10"
}

* --- Table Test 11: Custom formatting options ---
local ++test_count

capture erase "/tmp/test_msm_custom.xlsx"
capture noisily msm_table, xlsx("/tmp/test_msm_custom.xlsx") coefficients ///
    eform decimals(2) title("Table 1: Treatment Effects") replace

if _rc == 0 {
    display as result "  PASS: custom formatting options"
    local ++pass_count
}
else {
    display as error "  FAIL: custom formatting error (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' Table11"
}

* --- Table Test 12: Verify persistence - matrices exist ---
local ++test_count

capture matrix list _msm_pred_matrix
local rc1 = _rc
capture matrix list _msm_bal_matrix
local rc2 = _rc

if `rc1' == 0 & `rc2' == 0 {
    display as result "  PASS: persisted matrices exist"
    local ++pass_count
}
else {
    display as error "  FAIL: missing matrices (pred=`rc1' bal=`rc2')"
    local ++fail_count
    local failed_tests "`failed_tests' Table12"
}

* --- Table Test 13: Verify persistence - chars exist ---
local ++test_count

local chk1 : char _dta[_msm_pred_saved]
local chk2 : char _dta[_msm_bal_saved]
local chk3 : char _dta[_msm_diag_saved]
local chk4 : char _dta[_msm_sens_saved]

if "`chk1'" == "1" & "`chk2'" == "1" & "`chk3'" == "1" & "`chk4'" == "1" {
    display as result "  PASS: all persistence chars set"
    local ++pass_count
}
else {
    display as error "  FAIL: missing chars (pred=`chk1' bal=`chk2' diag=`chk3' sens=`chk4')"
    local ++fail_count
    local failed_tests "`failed_tests' Table13"
}

* T2 cleanup
capture erase "/tmp/test_msm_all.xlsx"
capture erase "/tmp/test_msm_coef.xlsx"
capture erase "/tmp/test_msm_pred.xlsx"
capture erase "/tmp/test_msm_bal.xlsx"
capture erase "/tmp/test_msm_sens.xlsx"
capture erase "/tmp/test_msm_custom.xlsx"

* =============================================================================
* T3: OPTION PATH COVERAGE
* =============================================================================


* Summary
display as result "Test Results: `pass_count'/`test_count' passed, `fail_count' failed"
display "RESULT: test_msm_table tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    display as error "Failed:`failed_tests'"
    exit 1
}
else {
    display as result "ALL TESTS PASSED"
}
