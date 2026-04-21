* test_export_surface.do
* Workbook-level QA for msm_report/msm_table export formatting and cleanup safety.

version 16.0
clear all
set more off
set varabbrev off

local qa_dir "`c(pwd)'"
local pkg_dir "`qa_dir'/.."
local tools_dir "`qa_dir'/tools"

capture ado uninstall msm
quietly net install msm, from("`pkg_dir'") replace

local pass_count = 0
local fail_count = 0
local test_count = 0
local failed_tests ""

local work_dir "`c(tmpdir)'/msm_export_surface"
capture mkdir "`work_dir'"

local report_xlsx "`work_dir'/report_surface.xlsx"
local table_all_xlsx "`work_dir'/table_surface_all.xlsx"
local table_coef_xlsx "`work_dir'/table_surface_coef.xlsx"

capture program drop _setup_export_surface
program define _setup_export_surface
    version 16.0
    local qa_dir "`c(pwd)'"
    local pkg_dir "`qa_dir'/.."

    use "`pkg_dir'/msm_example.dta", clear
    msm_prepare, id(id) period(period) treatment(treatment) ///
        outcome(outcome) covariates(biomarker comorbidity) ///
        baseline_covariates(age sex)
    msm_weight, treat_d_cov(biomarker comorbidity age sex) ///
        treat_n_cov(age sex) truncate(1 99) nolog
    msm_fit, model(logistic) outcome_cov(age) period_spec(linear) nolog
    msm_predict, times(1 3 5) difference samples(20) seed(4242)
    msm_diagnose, balance_covariates(biomarker comorbidity age sex) threshold(0.1)
    msm_sensitivity, evalue
end

capture program drop _read_check_status
program define _read_check_status, rclass
    version 16.0
    args status_file

    local status "FAIL"
    capture confirm file "`status_file'"
    if _rc == 0 {
        tempname fh
        file open `fh' using "`status_file'", read text
        file read `fh' status
        file close `fh'
    }

    return local status "`status'"
end

capture noisily _setup_export_surface
if _rc {
    display as error "Export-surface setup failed (rc=`=_rc')"
    exit _rc
}

capture erase "`report_xlsx'"
local ++test_count
capture noisily msm_report, export("`report_xlsx'") format(excel) eform ///
    title("Export Surface Report") font("Times New Roman") fontsize(12) ///
    borderstyle(academic) zebra ///
    footnote("Report QA footnote for export surface") open replace
if _rc == 0 {
    capture confirm file "`report_xlsx'"
}
if _rc == 0 {
    display as result "  PASS X1: msm_report custom Excel export"
    local ++pass_count
}
else {
    display as error "  FAIL X1: msm_report custom Excel export (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' X1"
}

local ++test_count
tempfile x2_status
capture noisily shell python3 "`tools_dir'/check_xlsx.py" "`report_xlsx'" ///
    --sheet Summary ///
    --exact-rows 12 ///
    --exact-cols 2 ///
    --cell A1 "Export Surface Report" ///
    --header-row 2 Metric Value ///
    --merged-row 1 ///
    --bold-row-all 2 ///
    --fill-color 2 "219 229 241" ///
    --fill-color 3 "237 242 249" ///
    --font "Times New Roman" ///
    --fontsize 12 ///
    --border-row 2 top medium ///
    --border-row 2 bottom medium ///
    --cell A12 "Report QA footnote for export surface" ///
    --italic-row 12 ///
    --result-file "`x2_status'"
quietly _read_check_status "`x2_status'"
if "`r(status)'" == "PASS" {
    display as result "  PASS X2: msm_report Summary sheet formatting"
    local ++pass_count
}
else {
    display as error "  FAIL X2: msm_report Summary sheet formatting"
    local ++fail_count
    local failed_tests "`failed_tests' X2"
}

local ++test_count
tempfile x3_status
capture noisily shell python3 "`tools_dir'/check_xlsx.py" "`report_xlsx'" ///
    --sheet Coefficients ///
    --exact-rows 7 ///
    --exact-cols 4 ///
    --cell A1 "Outcome Model (logistic)" ///
    --header-row 2 Variable OR "95% CI" p-value ///
    --merged-row 1 ///
    --fill-color 2 "219 229 241" ///
    --fill-color 3 "237 242 249" ///
    --font "Times New Roman" ///
    --fontsize 12 ///
    --border-row 2 top medium ///
    --cell-not-empty B3 C3 D3 ///
    --number-format B3 "0.0000" ///
    --cell A7 "Report QA footnote for export surface" ///
    --italic-row 7 ///
    --has-pattern ci p-values ///
    --result-file "`x3_status'"
quietly _read_check_status "`x3_status'"
if "`r(status)'" == "PASS" {
    display as result "  PASS X3: msm_report Coefficients sheet formatting"
    local ++pass_count
}
else {
    display as error "  FAIL X3: msm_report Coefficients sheet formatting"
    local ++fail_count
    local failed_tests "`failed_tests' X3"
}

capture erase "`table_all_xlsx'"
local ++test_count
capture noisily msm_table, xlsx("`table_all_xlsx'") all replace open ///
    title("Export Surface Table") font("Calibri") fontsize(11) ///
    borderstyle(medium) nformat("0.000") zebra ///
    footnote("Table QA footnote for export surface")
if _rc == 0 {
    capture confirm file "`table_all_xlsx'"
}
if _rc == 0 {
    display as result "  PASS X4: msm_table all-sheets export"
    local ++pass_count
}
else {
    display as error "  FAIL X4: msm_table all-sheets export (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' X4"
}

local ++test_count
tempfile x5_status
capture noisily shell python3 "`tools_dir'/check_xlsx.py" "`table_all_xlsx'" ///
    --sheet Predictions ///
    --exact-rows 7 ///
    --exact-cols 7 ///
    --cell A1 "Export Surface Table" ///
    --merged-row 1 ///
    --merged-row 2 ///
    --header-row 3 Period Estimate "95% CI" ///
    --fill-color 3 "219 229 241" ///
    --fill-color 4 "237 242 249" ///
    --font "Calibri" ///
    --fontsize 11 ///
    --border-row 2 top medium ///
    --number-format B4 "0.000" ///
    --cell A7 "Table QA footnote for export surface" ///
    --italic-row 7 ///
    --result-file "`x5_status'"
quietly _read_check_status "`x5_status'"
if "`r(status)'" == "PASS" {
    display as result "  PASS X5: msm_table Predictions sheet formatting"
    local ++pass_count
}
else {
    display as error "  FAIL X5: msm_table Predictions sheet formatting"
    local ++fail_count
    local failed_tests "`failed_tests' X5"
}

local ++test_count
tempfile x6_status
capture noisily shell python3 "`tools_dir'/check_xlsx.py" "`table_all_xlsx'" ///
    --sheet Balance ///
    --exact-rows 8 ///
    --exact-cols 5 ///
    --cell A1 "Export Surface Table" ///
    --header-row 2 Covariate "Raw SMD" "Weighted SMD" "% Change" Balanced ///
    --fill-color 2 "219 229 241" ///
    --fill-color 3 "237 242 249" ///
    --font "Calibri" ///
    --fontsize 11 ///
    --border-row 2 top medium ///
    --number-format B3 "0.000" ///
    --number-format C3 "0.000" ///
    --row-contains 7 "Balanced:" ///
    --italic-row 7 ///
    --cell A8 "Table QA footnote for export surface" ///
    --italic-row 8 ///
    --result-file "`x6_status'"
quietly _read_check_status "`x6_status'"
if "`r(status)'" == "PASS" {
    display as result "  PASS X6: msm_table Balance sheet formatting"
    local ++pass_count
}
else {
    display as error "  FAIL X6: msm_table Balance sheet formatting"
    local ++fail_count
    local failed_tests "`failed_tests' X6"
}

local ++test_count
tempfile x7_status
capture noisily shell python3 "`tools_dir'/check_xlsx.py" "`table_all_xlsx'" ///
    --sheet Weights ///
    --exact-rows 12 ///
    --exact-cols 2 ///
    --cell A1 "Export Surface Table" ///
    --header-row 2 Statistic Value ///
    --fill-color 2 "219 229 241" ///
    --fill-color 3 "237 242 249" ///
    --font "Calibri" ///
    --fontsize 11 ///
    --border-row 2 top medium ///
    --number-format B3 "0.000" ///
    --cell A12 "Table QA footnote for export surface" ///
    --italic-row 12 ///
    --result-file "`x7_status'"
quietly _read_check_status "`x7_status'"
if "`r(status)'" == "PASS" {
    display as result "  PASS X7: msm_table Weights sheet formatting"
    local ++pass_count
}
else {
    display as error "  FAIL X7: msm_table Weights sheet formatting"
    local ++fail_count
    local failed_tests "`failed_tests' X7"
}

local ++test_count
tempfile x8_status
capture noisily shell python3 "`tools_dir'/check_xlsx.py" "`table_all_xlsx'" ///
    --sheet Sensitivity ///
    --exact-rows 7 ///
    --exact-cols 2 ///
    --cell A1 "Export Surface Table" ///
    --header-row 2 Parameter Value ///
    --contains "E-value (point estimate)" ///
    --fill-color 2 "219 229 241" ///
    --fill-color 3 "237 242 249" ///
    --font "Calibri" ///
    --fontsize 11 ///
    --border-row 2 top medium ///
    --number-format B3 "0.000" ///
    --cell A7 "Table QA footnote for export surface" ///
    --italic-row 7 ///
    --result-file "`x8_status'"
quietly _read_check_status "`x8_status'"
if "`r(status)'" == "PASS" {
    display as result "  PASS X8: msm_table Sensitivity sheet formatting"
    local ++pass_count
}
else {
    display as error "  FAIL X8: msm_table Sensitivity sheet formatting"
    local ++fail_count
    local failed_tests "`failed_tests' X8"
}

capture erase "`table_coef_xlsx'"
local ++test_count
capture noisily msm_table, xlsx("`table_coef_xlsx'") coefficients eform ///
    decimals(2) sep(" to ") replace open ///
    title("Coefficient Surface Table") font("Courier New") fontsize(10) ///
    borderstyle(thin) nformat("0.00") zebra boldp(1) highlight(1) ///
    footnote("Coefficient sheet QA footnote")
if _rc == 0 {
    capture confirm file "`table_coef_xlsx'"
}
if _rc == 0 {
    display as result "  PASS X9: msm_table coefficient-surface export"
    local ++pass_count
}
else {
    display as error "  FAIL X9: msm_table coefficient-surface export (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' X9"
}

local ++test_count
tempfile x10_status
capture noisily shell python3 "`tools_dir'/check_xlsx.py" "`table_coef_xlsx'" ///
    --sheet Coefficients ///
    --exact-rows 7 ///
    --exact-cols 4 ///
    --cell A1 "Coefficient Surface Table" ///
    --header-row 2 Variable OR "95% CI" p-value ///
    --fill-color 2 "219 229 241" ///
    --font "Courier New" ///
    --fontsize 10 ///
    --border-row 2 top thin ///
    --number-format B3 "0.00" ///
    --cell-contains C3 " to " ///
    --row-bold-contains Treatment ///
    --row-fill-contains Treatment "255 255 204" ///
    --cell A7 "Coefficient sheet QA footnote" ///
    --italic-row 7 ///
    --result-file "`x10_status'"
quietly _read_check_status "`x10_status'"
if "`r(status)'" == "PASS" {
    display as result "  PASS X10: msm_table coefficient-specific formatting"
    local ++pass_count
}
else {
    display as error "  FAIL X10: msm_table coefficient-specific formatting"
    local ++fail_count
    local failed_tests "`failed_tests' X10"
}

display as text ""
display as text "========================================"
display as text "EXPORT SURFACE QA SUMMARY"
display as text "========================================"
display as text "Tests run: " as result `test_count'
display as text "Passed:    " as result `pass_count'
display as text "Failed:    " as result `fail_count'

if `fail_count' > 0 {
    display as error "Failed tests:`failed_tests'"
}

capture erase "`report_xlsx'"
capture erase "`table_all_xlsx'"
capture erase "`table_coef_xlsx'"

if `fail_count' > 0 exit 1
