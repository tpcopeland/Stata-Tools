* test_package_release.do - package-local static/document/XLSX release gate
* qa-hygiene: no-package-code -- shells python xlsx checkers over committed demo artifacts; no gcomp command runs here

clear all
set more off
version 16.0

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
local workbook "`pkg_dir'/demo/demo_gcomptab.xlsx"
local checker "`qa_dir'/tools/check_xlsx.py"
local release_checker "`qa_dir'/tools/check_release.py"

local test_count = 0
local pass_count = 0
local fail_count = 0

* the Stata shell reports rc 0 for a child that failed, exited nonzero, or does
* not even exist, so every local *_rc = _rc below read 0 unconditionally and
* contributed nothing to the verdicts (proved in
* iivw/qa/test_iivw_v200_qagate.do, T1). The checker --result-file is the real
* sentinel: it exists only if the child ran far enough to write it. Opening it
* unguarded turned an absent python3 into an uncaught r(603) that aborted the
* do-file before any RESULT line was emitted -- which the QA parser reports as
* status=unknown, not a failure. _gc_status reads it defensively instead.
capture program drop _gc_status
program define _gc_status, rclass
    gettoken path 0 : 0
    local status ""
    capture confirm file "`path'"
    if _rc == 0 {
        tempname fh
        file open `fh' using "`path'", read text
        file read `fh' status
        file close `fh'
    }
    return local status "`status'"
end

* R1: distribution, version, author, path, and SMCL rendered-width contract.
local ++test_count
tempfile static_result
capture noisily shell python3 "`release_checker'" "`pkg_dir'" --result-file "`static_result'"
_gc_status "`static_result'"
local static_status "`r(status)'"
if "`static_status'" == "PASS" {
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
_gc_status "`book_result'"
local book_status "`r(status)'"
if "`book_status'" == "PASS" {
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
    _gc_status "`sheet_result'"
    local sheet_status "`r(status)'"
    if "`sheet_status'" == "PASS" {
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
_gc_status "`models_result'"
local models_status "`r(status)'"
if "`models_status'" == "PASS" {
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
