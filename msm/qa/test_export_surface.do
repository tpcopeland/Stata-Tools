* test_export_surface.do
* Workbook-level QA for msm_report/msm_table export formatting and cleanup safety.

version 16.0
clear all
set more off
set varabbrev off

local qa_dir "`c(pwd)'"
local pkg_dir "`qa_dir'/.."
local tools_dir "`qa_dir'/tools"

do "`qa_dir'/_install_msm_isolated.do" "`pkg_dir'"

local pass_count = 0
local fail_count = 0
local test_count = 0
local failed_tests ""

local work_dir "`c(tmpdir)'/msm_export_surface"
capture mkdir "`work_dir'"

local report_xlsx "`work_dir'/report_surface.xlsx"
local table_all_xlsx "`work_dir'/table_surface_all.xlsx"
local table_coef_xlsx "`work_dir'/table_surface_coef.xlsx"
local table_default_xlsx "`work_dir'/table_surface_default.xlsx"
local table_pred_xlsx "`work_dir'/table_surface_pred.xlsx"
local table_bal_wt_xlsx "`work_dir'/table_surface_bal_wt.xlsx"
local table_sens_xlsx "`work_dir'/table_surface_sens.xlsx"
local table_nclass_xlsx "`work_dir'/table_surface_nclass.xlsx"
local table_preserve_xlsx "`work_dir'/table_surface_preserve.xlsx"

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
    msm_fit, model(logistic) outcome_cov(age sex) period_spec(linear) nolog
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
putexcel set "`report_xlsx'", sheet("Keep") replace
putexcel A1 = "sentinel"
putexcel clear
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
tempfile x1b_status
local checker "`pkg_dir'/qa/tools/check_xlsx.py"
capture noisily shell python3 "`checker'" "`report_xlsx'" ///
    --sheet Keep ///
    --cell A1 sentinel ///
    --result-file "`x1b_status'"
quietly _read_check_status "`x1b_status'"
if "`r(status)'" == "PASS" {
    display as result "  PASS X1b: msm_report replace preserves unrelated sheet"
    local ++pass_count
}
else {
    display as error "  FAIL X1b: msm_report sheet preservation"
    local ++fail_count
    local failed_tests "`failed_tests' X1b"
}

local ++test_count
tempfile x2_status
capture noisily shell python3 "`checker'" "`report_xlsx'" ///
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
capture noisily shell python3 "`checker'" "`report_xlsx'" ///
    --sheet Coefficients ///
    --exact-rows 8 ///
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
    --cell A8 "Report QA footnote for export surface" ///
    --italic-row 8 ///
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
tempfile x4b_status
capture noisily shell python3 "`checker'" "`table_all_xlsx'" ///
    --sheet-order Coefficients Predictions Balance Weights Sensitivity ///
    --result-file "`x4b_status'"
quietly _read_check_status "`x4b_status'"
if "`r(status)'" == "PASS" {
    display as result "  PASS X4b: msm_table all sheet order"
    local ++pass_count
}
else {
    display as error "  FAIL X4b: msm_table all sheet order"
    local ++fail_count
    local failed_tests "`failed_tests' X4b"
}

local ++test_count
tempfile x5_status
capture noisily shell python3 "`checker'" "`table_all_xlsx'" ///
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
capture noisily shell python3 "`checker'" "`table_all_xlsx'" ///
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
capture noisily shell python3 "`checker'" "`table_all_xlsx'" ///
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
capture noisily shell python3 "`checker'" "`table_all_xlsx'" ///
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
* The fitted model has five reported terms, including _cons: title + header +
* five coefficient rows + footnote = eight workbook rows.
capture noisily shell python3 "`checker'" "`table_coef_xlsx'" ///
    --sheet Coefficients ///
    --exact-rows 8 ///
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
    --cell A8 "Coefficient sheet QA footnote" ///
    --italic-row 8 ///
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

local ++test_count
tempfile x10b_status
capture noisily shell python3 "`checker'" "`table_coef_xlsx'" ///
    --sheet-order Coefficients ///
    --result-file "`x10b_status'"
quietly _read_check_status "`x10b_status'"
if "`r(status)'" == "PASS" {
    display as result "  PASS X10b: msm_table coefficients-only sheet order"
    local ++pass_count
}
else {
    display as error "  FAIL X10b: msm_table coefficients-only sheet order"
    local ++fail_count
    local failed_tests "`failed_tests' X10b"
}

capture erase "`table_default_xlsx'"
local ++test_count
capture noisily msm_table, xlsx("`table_default_xlsx'") replace
if _rc == 0 {
    capture confirm file "`table_default_xlsx'"
}
if _rc == 0 {
    display as result "  PASS X10c: msm_table default auto export"
    local ++pass_count
}
else {
    display as error "  FAIL X10c: msm_table default auto export (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' X10c"
}

local ++test_count
tempfile x10d_status
capture noisily shell python3 "`checker'" "`table_default_xlsx'" ///
    --sheet-order Coefficients Predictions Balance Weights Sensitivity ///
    --result-file "`x10d_status'"
quietly _read_check_status "`x10d_status'"
if "`r(status)'" == "PASS" {
    display as result "  PASS X10d: msm_table default sheet order"
    local ++pass_count
}
else {
    display as error "  FAIL X10d: msm_table default sheet order"
    local ++fail_count
    local failed_tests "`failed_tests' X10d"
}

capture erase "`table_pred_xlsx'"
local ++test_count
capture noisily msm_table, xlsx("`table_pred_xlsx'") predictions replace
if _rc == 0 {
    capture confirm file "`table_pred_xlsx'"
}
if _rc == 0 {
    display as result "  PASS X10e: msm_table predictions-only export"
    local ++pass_count
}
else {
    display as error "  FAIL X10e: msm_table predictions-only export (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' X10e"
}

local ++test_count
tempfile x10f_status
capture noisily shell python3 "`checker'" "`table_pred_xlsx'" ///
    --sheet-order Predictions ///
    --result-file "`x10f_status'"
quietly _read_check_status "`x10f_status'"
if "`r(status)'" == "PASS" {
    display as result "  PASS X10f: msm_table predictions-only sheet order"
    local ++pass_count
}
else {
    display as error "  FAIL X10f: msm_table predictions-only sheet order"
    local ++fail_count
    local failed_tests "`failed_tests' X10f"
}

capture erase "`table_bal_wt_xlsx'"
local ++test_count
capture noisily msm_table, xlsx("`table_bal_wt_xlsx'") balance weights replace
if _rc == 0 {
    capture confirm file "`table_bal_wt_xlsx'"
}
if _rc == 0 {
    display as result "  PASS X10g: msm_table balance+weights export"
    local ++pass_count
}
else {
    display as error "  FAIL X10g: msm_table balance+weights export (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' X10g"
}

local ++test_count
tempfile x10h_status
capture noisily shell python3 "`checker'" "`table_bal_wt_xlsx'" ///
    --sheet-order Balance Weights ///
    --result-file "`x10h_status'"
quietly _read_check_status "`x10h_status'"
if "`r(status)'" == "PASS" {
    display as result "  PASS X10h: msm_table balance+weights sheet order"
    local ++pass_count
}
else {
    display as error "  FAIL X10h: msm_table balance+weights sheet order"
    local ++fail_count
    local failed_tests "`failed_tests' X10h"
}

capture erase "`table_sens_xlsx'"
local ++test_count
capture noisily msm_table, xlsx("`table_sens_xlsx'") sensitivity replace
if _rc == 0 {
    capture confirm file "`table_sens_xlsx'"
}
if _rc == 0 {
    display as result "  PASS X10i: msm_table sensitivity-only export"
    local ++pass_count
}
else {
    display as error "  FAIL X10i: msm_table sensitivity-only export (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' X10i"
}

local ++test_count
tempfile x10j_status
capture noisily shell python3 "`checker'" "`table_sens_xlsx'" ///
    --sheet-order Sensitivity ///
    --result-file "`x10j_status'"
quietly _read_check_status "`x10j_status'"
if "`r(status)'" == "PASS" {
    display as result "  PASS X10j: msm_table sensitivity-only sheet order"
    local ++pass_count
}
else {
    display as error "  FAIL X10j: msm_table sensitivity-only sheet order"
    local ++fail_count
    local failed_tests "`failed_tests' X10j"
}

capture erase "`table_nclass_xlsx'"
local ++test_count
capture noisily {
    return clear
    msm_table, xlsx("`table_nclass_xlsx'") coefficients replace
    mata: st_local("r_n_scalars", strofreal(rows(st_dir("r()", "numscalar", "*"))))
    mata: st_local("r_n_macros", strofreal(rows(st_dir("r()", "macro", "*"))))
    mata: st_local("r_n_matrices", strofreal(rows(st_dir("r()", "matrix", "*"))))
    assert `r_n_scalars' == 0
    assert `r_n_macros' == 0
    assert `r_n_matrices' == 0
}
if _rc == 0 {
    display as result "  PASS X10k: msm_table leaves no r() return surface"
    local ++pass_count
}
else {
    display as error "  FAIL X10k: msm_table r() return surface (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' X10k"
}

capture erase "`table_preserve_xlsx'"
putexcel set "`table_preserve_xlsx'", sheet("Keep") replace
putexcel A1 = "sentinel"
putexcel clear
local ++test_count
local _x10l_ok = 0
capture noisily msm_table, xlsx("`table_preserve_xlsx'") coefficients replace
if _rc == 0 {
    tempfile x10l_status
    capture noisily shell python3 "`checker'" "`table_preserve_xlsx'" ///
        --sheet Keep ///
        --cell A1 sentinel ///
        --result-file "`x10l_status'"
    quietly _read_check_status "`x10l_status'"
    if "`r(status)'" == "PASS" local _x10l_ok = 1
}
if `_x10l_ok' {
    display as result "  PASS X10l: msm_table replace preserves unrelated sheet"
    local ++pass_count
}
else {
    display as error "  FAIL X10l: msm_table sheet preservation"
    local ++fail_count
    local failed_tests "`failed_tests' X10l"
}

local protocol_csv "`work_dir'/protocol_surface.csv"
local protocol_xlsx "`work_dir'/protocol_surface.xlsx"
local protocol_tex "`work_dir'/protocol_surface.tex"
local protocol_tail ""
forvalues i = 1/12 {
    local protocol_tail `"`protocol_tail' Long protocol prose remains intact."'
}
local protocol_text `"Complex, "quoted" population with 50% eligible & subgroup_A #1. `protocol_tail'"'

capture erase "`protocol_csv'"
local ++test_count
capture noisily {
    msm_protocol, ///
        population(`"`protocol_text'"') ///
        treatment("Treat, no treat, and quoted strategy") ///
        confounders("biomarker_TV, age & sex") ///
        outcome("Outcome includes 10% threshold") ///
        causal_contrast("ATE #1") ///
        weight_spec("IPTW, 1/99 truncation") ///
        analysis("Pooled logistic with robust SE") ///
        format(csv) export("`protocol_csv'") replace

    import delimited using "`protocol_csv'", clear varnames(1) stringcols(_all)
    assert _N == 7
    assert component[1] == "Population"
    assert description[1] == `"`protocol_text'"'
}
if _rc == 0 {
    display as result "  PASS X11: msm_protocol CSV escapes commas and quotes"
    local ++pass_count
}
else {
    display as error "  FAIL X11: msm_protocol CSV escaping (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' X11"
}

capture erase "`protocol_xlsx'"
putexcel set "`protocol_xlsx'", sheet("Keep") replace
putexcel A1 = "sentinel"
putexcel clear
local ++test_count
capture noisily {
    msm_protocol, ///
        population(`"`protocol_text'"') ///
        treatment("Treat, no treat, and quoted strategy") ///
        confounders("biomarker_TV, age & sex") ///
        outcome("Outcome includes 10% threshold") ///
        causal_contrast("ATE #1") ///
        weight_spec("IPTW, 1/99 truncation") ///
        analysis("Pooled logistic with robust SE") ///
        format(excel) export("`protocol_xlsx'") replace

    import excel using "`protocol_xlsx'", sheet("Protocol") firstrow clear allstring
    assert _N == 7
    assert component[1] == "1. Population"
    assert description[1] == `"`protocol_text'"'
    assert strlen(description[1]) > 244
}
if _rc == 0 {
    display as result "  PASS X12: msm_protocol Excel keeps long descriptions"
    local ++pass_count
}
else {
    display as error "  FAIL X12: msm_protocol Excel long text (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' X12"
}

local ++test_count
tempfile x12b_status
capture noisily shell python3 "`checker'" "`protocol_xlsx'" ///
    --sheet Keep ///
    --cell A1 sentinel ///
    --result-file "`x12b_status'"
quietly _read_check_status "`x12b_status'"
if "`r(status)'" == "PASS" {
    display as result "  PASS X12b: msm_protocol replace preserves unrelated sheet"
    local ++pass_count
}
else {
    display as error "  FAIL X12b: msm_protocol sheet preservation"
    local ++fail_count
    local failed_tests "`failed_tests' X12b"
}

capture erase "`protocol_tex'"
local ++test_count
capture noisily {
    msm_protocol, ///
        population(`"`protocol_text'"') ///
        treatment("Treat, no treat, and quoted strategy") ///
        confounders("biomarker_TV, age & sex") ///
        outcome("Outcome includes 10% threshold") ///
        causal_contrast("ATE #1") ///
        weight_spec("IPTW, 1/99 truncation") ///
        analysis("Pooled logistic with robust SE") ///
        format(latex) export("`protocol_tex'") replace

    tempname fh
    local tex_text ""
    file open `fh' using "`protocol_tex'", read text
    file read `fh' line
    while r(eof) == 0 {
        local tex_text `"`tex_text' `macval(line)'"'
        file read `fh' line
    }
    file close `fh'

    assert strpos(`"`tex_text'"', "\%") > 0
    assert strpos(`"`tex_text'"', "\_") > 0
    assert strpos(`"`tex_text'"', "\&") > 0
    assert strpos(`"`tex_text'"', "\#") > 0
}
if _rc == 0 {
    display as result "  PASS X13: msm_protocol LaTeX escapes special characters"
    local ++pass_count
}
else {
    display as error "  FAIL X13: msm_protocol LaTeX escaping (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' X13"
}

local ++test_count
capture noisily {
    local root_logs : dir "`pkg_dir'" files "*.log"
    local root_smcl : dir "`pkg_dir'" files "*.smcl"
    local root_xlsx : dir "`pkg_dir'" files "*.xlsx"
    local n_root_artifacts = wordcount(`"`root_logs' `root_smcl' `root_xlsx'"')
    assert `n_root_artifacts' == 0
}
if _rc == 0 {
    display as result "  PASS X14: export QA leaves no root logs or workbooks"
    local ++pass_count
}
else {
    display as error "  FAIL X14: root artifact hygiene (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' X14"
}

* --- X15: quoted titles survive intact to the workbook title cell ---
local ++test_count
local table_title_xlsx "`work_dir'/table_surface_title.xlsx"
local report_title_xlsx "`work_dir'/report_surface_title.xlsx"
capture erase "`table_title_xlsx'"
capture erase "`report_title_xlsx'"
capture noisily {
    _setup_export_surface
    msm_table, xlsx("`table_title_xlsx'") coefficients replace ///
        title(`"Effect of "high" dose"')
    msm_report, format(excel) export("`report_title_xlsx'") replace ///
        title(`"Report for "special" cohort"')
}
if _rc == 0 {
    tempfile x15_status
    capture noisily shell python3 "`checker'" "`table_title_xlsx'" --sheet Coefficients --cell A1 'Effect of "high" dose' --result-file "`x15_status'"
    quietly _read_check_status "`x15_status'"
    if "`r(status)'" == "PASS" {
        tempfile x15b_status
        capture noisily shell python3 "`checker'" "`report_title_xlsx'" --sheet Summary --cell A1 'Report for "special" cohort' --result-file "`x15b_status'"
        quietly _read_check_status "`x15b_status'"
    }
}
if _rc == 0 & "`r(status)'" == "PASS" {
    display as result "  PASS X15: quoted titles reach the title cell intact"
    local ++pass_count
}
else {
    display as error "  FAIL X15: quoted title handling (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' X15"
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
capture erase "`table_default_xlsx'"
capture erase "`table_pred_xlsx'"
capture erase "`table_bal_wt_xlsx'"
capture erase "`table_sens_xlsx'"
capture erase "`table_nclass_xlsx'"
capture erase "`table_preserve_xlsx'"
capture erase "`table_title_xlsx'"
capture erase "`report_title_xlsx'"
capture erase "`protocol_csv'"
capture erase "`protocol_xlsx'"
capture erase "`protocol_tex'"

if `fail_count' > 0 exit 1
