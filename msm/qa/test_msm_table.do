* test_msm_table.do - Test msm_table Excel export
* Tests the full MSM pipeline followed by table export
* Location: msm/qa/

clear all
set more off

capture ado uninstall msm
net install msm, from("/home/tpcopeland/Stata-Dev/msm") replace

* Load example data
use "/home/tpcopeland/Stata-Dev/msm/msm_example.dta", clear

local n_pass = 0
local n_fail = 0
local n_tests = 0

* =========================================================================
* Run full MSM pipeline
* =========================================================================

* Step 1: Prepare
msm_prepare, id(id) period(period) treatment(treatment) ///
    outcome(outcome) covariates(biomarker comorbidity) ///
    baseline(age sex) censor(censored)

* Step 2: Weight
msm_weight, treat_d_cov(biomarker comorbidity age sex) ///
    treat_n_cov(age sex) truncate(1 99)

* Step 3: Fit
msm_fit, model(logistic) period_spec(quadratic) nolog

* Step 4: Predict
msm_predict, times(3 5 7) difference seed(12345)

* Step 5: Diagnose
msm_diagnose, balance_covariates(biomarker comorbidity age sex)

* Step 6: Sensitivity
msm_sensitivity, evalue

* =========================================================================
* Test 1: All tables with eform
* =========================================================================
local ++n_tests

capture erase "/tmp/test_msm_all.xlsx"
capture noisily msm_table, xlsx("/tmp/test_msm_all.xlsx") all eform replace

if _rc == 0 {
    capture confirm file "/tmp/test_msm_all.xlsx"
    if _rc == 0 {
        display "RESULT: Test 1 PASSED - all tables exported"
        local ++n_pass
    }
    else {
        display "RESULT: Test 1 FAILED - file not created"
        local ++n_fail
    }
}
else {
    display "RESULT: Test 1 FAILED - msm_table returned error " _rc
    local ++n_fail
}

* =========================================================================
* Test 2: Coefficients only
* =========================================================================
local ++n_tests

capture erase "/tmp/test_msm_coef.xlsx"
capture noisily msm_table, xlsx("/tmp/test_msm_coef.xlsx") coefficients eform replace

if _rc == 0 {
    display "RESULT: Test 2 PASSED - coefficients table exported"
    local ++n_pass
}
else {
    display "RESULT: Test 2 FAILED - coefficients export error " _rc
    local ++n_fail
}

* =========================================================================
* Test 3: Predictions only
* =========================================================================
local ++n_tests

capture erase "/tmp/test_msm_pred.xlsx"
capture noisily msm_table, xlsx("/tmp/test_msm_pred.xlsx") predictions replace

if _rc == 0 {
    display "RESULT: Test 3 PASSED - predictions table exported"
    local ++n_pass
}
else {
    display "RESULT: Test 3 FAILED - predictions export error " _rc
    local ++n_fail
}

* =========================================================================
* Test 4: Balance and weights
* =========================================================================
local ++n_tests

capture erase "/tmp/test_msm_bal.xlsx"
capture noisily msm_table, xlsx("/tmp/test_msm_bal.xlsx") balance weights replace

if _rc == 0 {
    display "RESULT: Test 4 PASSED - balance + weights exported"
    local ++n_pass
}
else {
    display "RESULT: Test 4 FAILED - balance/weights export error " _rc
    local ++n_fail
}

* =========================================================================
* Test 5: Sensitivity only
* =========================================================================
local ++n_tests

capture erase "/tmp/test_msm_sens.xlsx"
capture noisily msm_table, xlsx("/tmp/test_msm_sens.xlsx") sensitivity replace

if _rc == 0 {
    display "RESULT: Test 5 PASSED - sensitivity table exported"
    local ++n_pass
}
else {
    display "RESULT: Test 5 FAILED - sensitivity export error " _rc
    local ++n_fail
}

* =========================================================================
* Test 6: Verify coefficients values via re-import
* =========================================================================
local ++n_tests

preserve
import excel "/tmp/test_msm_coef.xlsx", sheet("Coefficients") clear
* Row 1 = title, Row 2 = headers, Row 3+ = data
* Check that row 3 (first data row) has content
capture assert A[3] != "" & B[3] != ""
if _rc == 0 {
    display "RESULT: Test 6 PASSED - coefficients data verified"
    local ++n_pass
}
else {
    display "RESULT: Test 6 FAILED - coefficients re-import check"
    local ++n_fail
}
restore

* =========================================================================
* Test 7: Verify predictions via re-import
* =========================================================================
local ++n_tests

preserve
import excel "/tmp/test_msm_pred.xlsx", sheet("Predictions") clear
* Row 4 = first data row (title + group header + column header)
* Should have period values
capture assert A[4] != ""
if _rc == 0 {
    display "RESULT: Test 7 PASSED - predictions data verified"
    local ++n_pass
}
else {
    display "RESULT: Test 7 FAILED - predictions re-import check"
    local ++n_fail
}
restore

* =========================================================================
* Test 8: Verify balance via re-import
* =========================================================================
local ++n_tests

preserve
import excel "/tmp/test_msm_bal.xlsx", sheet("Balance") clear
* Row 3+ = data, should have covariate names
capture assert A[3] != "" & B[3] != ""
if _rc == 0 {
    display "RESULT: Test 8 PASSED - balance data verified"
    local ++n_pass
}
else {
    display "RESULT: Test 8 FAILED - balance re-import check"
    local ++n_fail
}
restore

* =========================================================================
* Test 9: Error - no .xlsx extension
* =========================================================================
local ++n_tests

capture noisily msm_table, xlsx("/tmp/test.csv") replace
if _rc == 198 {
    display "RESULT: Test 9 PASSED - rejected non-xlsx extension"
    local ++n_pass
}
else {
    display "RESULT: Test 9 FAILED - expected error 198, got " _rc
    local ++n_fail
}

* =========================================================================
* Test 10: Error - file exists without replace
* =========================================================================
local ++n_tests

capture noisily msm_table, xlsx("/tmp/test_msm_all.xlsx") all eform
if _rc == 602 {
    display "RESULT: Test 10 PASSED - rejected existing file without replace"
    local ++n_pass
}
else {
    display "RESULT: Test 10 FAILED - expected error 602, got " _rc
    local ++n_fail
}

* =========================================================================
* Test 11: Custom formatting options
* =========================================================================
local ++n_tests

capture erase "/tmp/test_msm_custom.xlsx"
capture noisily msm_table, xlsx("/tmp/test_msm_custom.xlsx") coefficients ///
    eform decimals(2) title("Table 1: Treatment Effects") replace

if _rc == 0 {
    display "RESULT: Test 11 PASSED - custom formatting options"
    local ++n_pass
}
else {
    display "RESULT: Test 11 FAILED - custom formatting error " _rc
    local ++n_fail
}

* =========================================================================
* Test 12: Verify persistence - matrices exist
* =========================================================================
local ++n_tests

capture matrix list _msm_pred_matrix
local rc1 = _rc
capture matrix list _msm_bal_matrix
local rc2 = _rc

if `rc1' == 0 & `rc2' == 0 {
    display "RESULT: Test 12 PASSED - persisted matrices exist"
    local ++n_pass
}
else {
    display "RESULT: Test 12 FAILED - missing matrices (pred=" `rc1' " bal=" `rc2' ")"
    local ++n_fail
}

* =========================================================================
* Test 13: Verify persistence - chars exist
* =========================================================================
local ++n_tests

local chk1 : char _dta[_msm_pred_saved]
local chk2 : char _dta[_msm_bal_saved]
local chk3 : char _dta[_msm_diag_saved]
local chk4 : char _dta[_msm_sens_saved]

if "`chk1'" == "1" & "`chk2'" == "1" & "`chk3'" == "1" & "`chk4'" == "1" {
    display "RESULT: Test 13 PASSED - all persistence chars set"
    local ++n_pass
}
else {
    display "RESULT: Test 13 FAILED - missing chars (pred=`chk1' bal=`chk2' diag=`chk3' sens=`chk4')"
    local ++n_fail
}

* =========================================================================
* Summary
* =========================================================================

display ""
display "============================================="
display "msm_table test summary: `n_pass'/`n_tests' passed, `n_fail' failed"
display "============================================="

* Cleanup
capture erase "/tmp/test_msm_all.xlsx"
capture erase "/tmp/test_msm_coef.xlsx"
capture erase "/tmp/test_msm_pred.xlsx"
capture erase "/tmp/test_msm_bal.xlsx"
capture erase "/tmp/test_msm_sens.xlsx"
capture erase "/tmp/test_msm_custom.xlsx"
