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
tempfile table_anchor
local work_dir "`table_anchor'_dir"
capture mkdir "`work_dir'"
local all_xlsx    "`work_dir'/all.xlsx"
local coef_xlsx   "`work_dir'/coefficients.xlsx"
local pred_xlsx   "`work_dir'/predictions.xlsx"
local bal_xlsx    "`work_dir'/balance.xlsx"
local sens_xlsx   "`work_dir'/sensitivity.xlsx"
local sens_bound_xlsx "`work_dir'/sensitivity_bounds.xlsx"
local custom_xlsx "`work_dir'/custom.xlsx"

capture log close _all
log using "test_msm_table.log", replace text nomsg

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

capture erase "`all_xlsx'"
capture noisily msm_table, xlsx("`all_xlsx'") all eform replace

if _rc == 0 {
    capture confirm file "`all_xlsx'"
    if _rc == 0 {
        local _all_sheets_ok 1
        preserve
        foreach _sheet in Coefficients Predictions Balance Weights Sensitivity {
            capture import excel "`all_xlsx'", sheet("`_sheet'") clear
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

capture erase "`coef_xlsx'"
capture noisily msm_table, xlsx("`coef_xlsx'") coefficients eform replace

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

capture erase "`pred_xlsx'"
capture noisily msm_table, xlsx("`pred_xlsx'") predictions replace

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

capture erase "`bal_xlsx'"
capture noisily msm_table, xlsx("`bal_xlsx'") balance weights replace

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

capture erase "`sens_xlsx'"
capture noisily msm_table, xlsx("`sens_xlsx'") sensitivity replace

if _rc == 0 {
    display as result "  PASS: sensitivity table exported"
    local ++pass_count
}
else {
    display as error "  FAIL: sensitivity export error (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' Table5"
}

* --- Table Test 5b: Confounding-strength content is actually exported ---
local ++test_count
capture noisily {
    msm_sensitivity, confounding_strength(2 3)
    local expected_bias = r(bias_factor)
    local expected_bound = r(bound)
    capture erase "`sens_bound_xlsx'"
    msm_table, xlsx("`sens_bound_xlsx'") sensitivity decimals(4) replace

    preserve
    import excel "`sens_bound_xlsx'", sheet("Sensitivity") allstring clear
    local found_ud 0
    local found_uy 0
    local found_bias 0
    local found_bound 0
    forvalues i = 1/`=_N' {
        if A[`i'] == "RR(U,D)" {
            assert abs(real(B[`i']) - 2) < 0.00011
            local found_ud 1
        }
        if A[`i'] == "RR(U,Y)" {
            assert abs(real(B[`i']) - 3) < 0.00011
            local found_uy 1
        }
        if A[`i'] == "Bias factor" {
            assert abs(real(B[`i']) - `expected_bias') < 0.00011
            local found_bias 1
        }
        if A[`i'] == "Bias-adjusted RR bound" {
            assert abs(real(B[`i']) - `expected_bound') < 0.00011
            local found_bound 1
        }
    }
    restore
    assert `found_ud' == 1
    assert `found_uy' == 1
    assert `found_bias' == 1
    assert `found_bound' == 1
}
if _rc == 0 {
    display as result "  PASS: confounding-strength values exported"
    local ++pass_count
}
else {
    display as error "  FAIL: sensitivity workbook omitted confounding-strength content (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' Table5b"
    capture restore
}

* --- Table Test 6: Verify coefficients values via re-import ---
local ++test_count

preserve
import excel "`coef_xlsx'", sheet("Coefficients") clear
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
import excel "`pred_xlsx'", sheet("Predictions") clear
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
import excel "`bal_xlsx'", sheet("Balance") clear
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

capture noisily msm_table, xlsx("`work_dir'/test.csv") replace
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

capture noisily msm_table, xlsx("`all_xlsx'") all eform
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

capture erase "`custom_xlsx'"
capture noisily msm_table, xlsx("`custom_xlsx'") coefficients ///
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
capture erase "`all_xlsx'"
capture erase "`coef_xlsx'"
capture erase "`pred_xlsx'"
capture erase "`bal_xlsx'"
capture erase "`sens_xlsx'"
capture erase "`sens_bound_xlsx'"
capture erase "`custom_xlsx'"
capture rmdir "`work_dir'"

* =============================================================================
* T3: OPTION PATH COVERAGE
* =============================================================================


* Summary
display as result "Test Results: `pass_count'/`test_count' passed, `fail_count' failed"
do "`qa_dir'/_record_qa_result.do" test_msm_table ///
    `test_count' `pass_count' `fail_count' 0
display "RESULT: test_msm_table tests=`test_count' pass=`pass_count' fail=`fail_count' skip=0"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    display as error "Failed:`failed_tests'"
    capture log close _all
    exit 1
}
else {
    display as result "ALL TESTS PASSED"
}
capture log close _all
