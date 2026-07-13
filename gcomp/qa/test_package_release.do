* test_package_release.do - package-local static/document/XLSX release gate

clear all
set more off
version 16.0

local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
local workbook "`pkg_dir'/demo/demo_gcomptab.xlsx"
local checker "`qa_dir'/tools/check_xlsx.py"
local release_checker "`qa_dir'/tools/check_release.py"

local test_count = 0
local pass_count = 0
local fail_count = 0

* R1: distribution, version, author, path, and SMCL rendered-width contract.
local ++test_count
tempfile static_result
capture noisily shell python3 "`release_checker'" "`pkg_dir'" --result-file "`static_result'"
local static_rc = _rc
tempname fh
file open `fh' using "`static_result'", read text
file read `fh' static_status
file close `fh'
if `static_rc' == 0 & "`static_status'" == "PASS" {
    local ++pass_count
}
else {
    local ++fail_count
}

* R2: exact workbook sheet identity/order and package-level content.
local ++test_count
tempfile book_result
capture noisily shell python3 "`checker'" "`workbook'" ///
    --sheet-count 3 --sheet-order "Normal CI" "Percentile CI" "Component models" ///
    --contains "Total Causal Effect" ///
    --result-file "`book_result'"
local book_rc = _rc
file open `fh' using "`book_result'", read text
file read `fh' book_status
file close `fh'
if `book_rc' == 0 & "`book_status'" == "PASS" {
    local ++pass_count
}
else {
    local ++fail_count
}

* R3-R5: dimensions, numeric/text content, merges, borders, fonts, and widths.
foreach sheet in "Normal CI" "Percentile CI" {
    local ++test_count
    tempfile sheet_result
    capture noisily shell python3 "`checker'" "`workbook'" --sheet "`sheet'" ///
        --exact-rows 7 --exact-cols 5 --header-exact 2 "" Effect Estimate "95% CI" SE ///
        --bold-row-all 2 --min-merges 1 --has-borders --font Arial ///
        --all-col-widths-fit 2 2 --result-file "`sheet_result'"
    local sheet_rc = _rc
    file open `fh' using "`sheet_result'", read text
    file read `fh' sheet_status
    file close `fh'
    if `sheet_rc' == 0 & "`sheet_status'" == "PASS" {
        local ++pass_count
    }
    else {
        local ++fail_count
    }
}

local ++test_count
tempfile models_result
capture noisily shell python3 "`checker'" "`workbook'" --sheet "Component models" ///
    --exact-rows 8 --exact-cols 7 --header-exact 3 Term Coef. "95% CI" p Coef. "95% CI" p ///
    --cell A1 "Table 3. Fitted component models (coefficients)" ///
    --cell B2 "Mediator (m)" ///
    --has-borders --font Arial --min-merges 2 --all-col-widths-fit 2 2 ///
    --result-file "`models_result'"
local models_rc = _rc
file open `fh' using "`models_result'", read text
file read `fh' models_status
file close `fh'
if `models_rc' == 0 & "`models_status'" == "PASS" {
    local ++pass_count
}
else {
    local ++fail_count
}

if `fail_count' > 0 {
    display "RESULT: test_package_release tests=`test_count' pass=`pass_count' fail=`fail_count' status=FAIL"
    exit 1
}
display "RESULT: test_package_release tests=`test_count' pass=`pass_count' fail=`fail_count' status=PASS"
