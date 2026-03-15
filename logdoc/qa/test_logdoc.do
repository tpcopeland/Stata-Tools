* test_logdoc.do — Functional tests for logdoc package
* Location: ~/Stata-Dev/_devkit/_testing/
* Run: stata-mp -e do test_logdoc.do

clear all
set more off

capture ado uninstall logdoc
net install logdoc, from("/home/tpcopeland/Stata-Dev/logdoc/") replace

local test_pass = 0
local test_fail = 0
local test_total = 0

* Test fixture: use iivw demo SMCL
local smcl_fixture "/home/tpcopeland/Stata-Tools/iivw/demo/console_output.smcl"
local outdir "/tmp/logdoc_tests"
capture mkdir "`outdir'"

* Clean up any prior test outputs
capture erase "`outdir'/test_basic.html"
capture erase "`outdir'/test_md.md"
capture erase "`outdir'/test_dark.html"
capture erase "`outdir'/test_pre.html"
capture erase "`outdir'/test_nofold.html"
capture erase "`outdir'/test_both.html"
capture erase "`outdir'/test_both.md"
capture erase "`outdir'/test_title.html"
capture erase "`outdir'/test_replace.html"

* -----------------------------------------------------------------------
* T1: Basic HTML generation
* -----------------------------------------------------------------------
local test_total = `test_total' + 1
capture noisily {
    logdoc using "`smcl_fixture'", output("`outdir'/test_basic.html") replace
    confirm file "`outdir'/test_basic.html"
    assert "`r(format)'" == "html"
    assert "`r(theme)'" == "light"
    assert "`r(output)'" == "`outdir'/test_basic.html"
}
if _rc == 0 {
    display as result "PASS: T1 - Basic HTML generation"
    local test_pass = `test_pass' + 1
}
else {
    display as error "FAIL: T1 - Basic HTML generation (rc = " _rc ")"
    local test_fail = `test_fail' + 1
}

* -----------------------------------------------------------------------
* T2: Markdown generation
* -----------------------------------------------------------------------
local test_total = `test_total' + 1
capture noisily {
    logdoc using "`smcl_fixture'", output("`outdir'/test_md.md") ///
        format(md) replace
    confirm file "`outdir'/test_md.md"
    assert "`r(format)'" == "md"
}
if _rc == 0 {
    display as result "PASS: T2 - Markdown generation"
    local test_pass = `test_pass' + 1
}
else {
    display as error "FAIL: T2 - Markdown generation (rc = " _rc ")"
    local test_fail = `test_fail' + 1
}

* -----------------------------------------------------------------------
* T3: Dark theme
* -----------------------------------------------------------------------
local test_total = `test_total' + 1
capture noisily {
    logdoc using "`smcl_fixture'", output("`outdir'/test_dark.html") ///
        theme(dark) replace
    confirm file "`outdir'/test_dark.html"
    assert "`r(theme)'" == "dark"
}
if _rc == 0 {
    display as result "PASS: T3 - Dark theme"
    local test_pass = `test_pass' + 1
}
else {
    display as error "FAIL: T3 - Dark theme (rc = " _rc ")"
    local test_fail = `test_fail' + 1
}

* -----------------------------------------------------------------------
* T4: Preformatted option
* -----------------------------------------------------------------------
local test_total = `test_total' + 1
capture noisily {
    logdoc using "`smcl_fixture'", output("`outdir'/test_pre.html") ///
        preformatted replace
    confirm file "`outdir'/test_pre.html"
}
if _rc == 0 {
    display as result "PASS: T4 - Preformatted option"
    local test_pass = `test_pass' + 1
}
else {
    display as error "FAIL: T4 - Preformatted option (rc = " _rc ")"
    local test_fail = `test_fail' + 1
}

* -----------------------------------------------------------------------
* T5: Nofold option
* -----------------------------------------------------------------------
local test_total = `test_total' + 1
capture noisily {
    logdoc using "`smcl_fixture'", output("`outdir'/test_nofold.html") ///
        nofold replace
    confirm file "`outdir'/test_nofold.html"
}
if _rc == 0 {
    display as result "PASS: T5 - Nofold option"
    local test_pass = `test_pass' + 1
}
else {
    display as error "FAIL: T5 - Nofold option (rc = " _rc ")"
    local test_fail = `test_fail' + 1
}

* -----------------------------------------------------------------------
* T6: Format both
* -----------------------------------------------------------------------
local test_total = `test_total' + 1
capture noisily {
    logdoc using "`smcl_fixture'", output("`outdir'/test_both.html") ///
        format(both) replace
    confirm file "`outdir'/test_both.html"
    confirm file "`outdir'/test_both.md"
}
if _rc == 0 {
    display as result "PASS: T6 - Format both (HTML + MD)"
    local test_pass = `test_pass' + 1
}
else {
    display as error "FAIL: T6 - Format both (rc = " _rc ")"
    local test_fail = `test_fail' + 1
}

* -----------------------------------------------------------------------
* T7: Custom title
* -----------------------------------------------------------------------
local test_total = `test_total' + 1
capture noisily {
    logdoc using "`smcl_fixture'", output("`outdir'/test_title.html") ///
        title("My Custom Title") replace
    confirm file "`outdir'/test_title.html"
}
if _rc == 0 {
    display as result "PASS: T7 - Custom title"
    local test_pass = `test_pass' + 1
}
else {
    display as error "FAIL: T7 - Custom title (rc = " _rc ")"
    local test_fail = `test_fail' + 1
}

* -----------------------------------------------------------------------
* T8: Replace option required
* -----------------------------------------------------------------------
local test_total = `test_total' + 1
capture noisily {
    * File already exists from T1
    logdoc using "`smcl_fixture'", output("`outdir'/test_basic.html")
}
if _rc == 602 {
    display as result "PASS: T8 - Replace option required (rc=602)"
    local test_pass = `test_pass' + 1
}
else {
    display as error "FAIL: T8 - Replace option required (got rc = " _rc ", expected 602)"
    local test_fail = `test_fail' + 1
}

* -----------------------------------------------------------------------
* T9: Replace option works
* -----------------------------------------------------------------------
local test_total = `test_total' + 1
capture noisily {
    logdoc using "`smcl_fixture'", output("`outdir'/test_replace.html") replace
    * Run again with replace
    logdoc using "`smcl_fixture'", output("`outdir'/test_replace.html") replace
    confirm file "`outdir'/test_replace.html"
}
if _rc == 0 {
    display as result "PASS: T9 - Replace option works"
    local test_pass = `test_pass' + 1
}
else {
    display as error "FAIL: T9 - Replace option works (rc = " _rc ")"
    local test_fail = `test_fail' + 1
}

* -----------------------------------------------------------------------
* T10: Invalid format
* -----------------------------------------------------------------------
local test_total = `test_total' + 1
capture noisily {
    logdoc using "`smcl_fixture'", output("`outdir'/bad.pdf") format(pdf) replace
}
if _rc == 198 {
    display as result "PASS: T10 - Invalid format rejected (rc=198)"
    local test_pass = `test_pass' + 1
}
else {
    display as error "FAIL: T10 - Invalid format (got rc = " _rc ", expected 198)"
    local test_fail = `test_fail' + 1
}

* -----------------------------------------------------------------------
* T11: Invalid theme
* -----------------------------------------------------------------------
local test_total = `test_total' + 1
capture noisily {
    logdoc using "`smcl_fixture'", output("`outdir'/bad.html") theme(blue) replace
}
if _rc == 198 {
    display as result "PASS: T11 - Invalid theme rejected (rc=198)"
    local test_pass = `test_pass' + 1
}
else {
    display as error "FAIL: T11 - Invalid theme (got rc = " _rc ", expected 198)"
    local test_fail = `test_fail' + 1
}

* -----------------------------------------------------------------------
* T12: File not found
* -----------------------------------------------------------------------
local test_total = `test_total' + 1
capture noisily {
    logdoc using "/nonexistent/file.smcl", output("`outdir'/bad.html") replace
}
if _rc == 601 {
    display as result "PASS: T12 - File not found (rc=601)"
    local test_pass = `test_pass' + 1
}
else {
    display as error "FAIL: T12 - File not found (got rc = " _rc ", expected 601)"
    local test_fail = `test_fail' + 1
}

* -----------------------------------------------------------------------
* T13: Run option rejects non-.do file
* -----------------------------------------------------------------------
local test_total = `test_total' + 1
capture noisily {
    logdoc using "`smcl_fixture'", output("`outdir'/bad.html") run replace
}
if _rc == 198 {
    display as result "PASS: T13 - Run rejects non-.do file (rc=198)"
    local test_pass = `test_pass' + 1
}
else {
    display as error "FAIL: T13 - Run rejects non-.do (got rc = " _rc ", expected 198)"
    local test_fail = `test_fail' + 1
}

* -----------------------------------------------------------------------
* T14: Run option with actual .do file
* -----------------------------------------------------------------------
local test_total = `test_total' + 1
capture noisily {
    * Create a simple .do file
    tempfile dofile
    local dofile "`outdir'/test_run.do"
    capture erase "`dofile'"
    capture erase "`outdir'/test_run.smcl"
    file open fh using "`dofile'", write replace
    file write fh `"log using "`outdir'/test_run.smcl", replace"' _n
    file write fh "sysuse auto, clear" _n
    file write fh "summarize price mpg" _n
    file write fh "log close" _n
    file close fh

    logdoc using "`dofile'", output("`outdir'/test_run.html") run replace
    confirm file "`outdir'/test_run.html"
}
if _rc == 0 {
    display as result "PASS: T14 - Run option with .do file"
    local test_pass = `test_pass' + 1
}
else {
    display as error "FAIL: T14 - Run option with .do file (rc = " _rc ")"
    local test_fail = `test_fail' + 1
}

* -----------------------------------------------------------------------
* T15: Log file output
* -----------------------------------------------------------------------
local test_total = `test_total' + 1
capture noisily {
    * Test with a .log file (plain text)
    local logfile "`outdir'/test_plain.log"
    capture erase "`logfile'"
    file open fh using "`logfile'", write replace
    file write fh ". sysuse auto, clear" _n
    file write fh "(1978 automobile data)" _n
    file write fh "" _n
    file write fh ". summarize price" _n
    file write fh "    Variable |        Obs        Mean    Std. dev." _n
    file write fh "    price    |         74    6165.257    2949.496" _n
    file close fh

    logdoc using "`logfile'", output("`outdir'/test_plain.html") replace
    confirm file "`outdir'/test_plain.html"
}
if _rc == 0 {
    display as result "PASS: T15 - Plain .log file input"
    local test_pass = `test_pass' + 1
}
else {
    display as error "FAIL: T15 - Plain .log file input (rc = " _rc ")"
    local test_fail = `test_fail' + 1
}

* -----------------------------------------------------------------------
* T16: Return values
* -----------------------------------------------------------------------
local test_total = `test_total' + 1
capture noisily {
    logdoc using "`smcl_fixture'", output("`outdir'/test_returns.html") ///
        format(html) theme(dark) replace
    assert "`r(output)'" == "`outdir'/test_returns.html"
    assert "`r(input)'" == "`smcl_fixture'"
    assert "`r(format)'" == "html"
    assert "`r(theme)'" == "dark"
}
if _rc == 0 {
    display as result "PASS: T16 - Return values correct"
    local test_pass = `test_pass' + 1
}
else {
    display as error "FAIL: T16 - Return values (rc = " _rc ")"
    local test_fail = `test_fail' + 1
}

* -----------------------------------------------------------------------
* T17: Preformatted + nofold combined
* -----------------------------------------------------------------------
local test_total = `test_total' + 1
capture noisily {
    logdoc using "`smcl_fixture'", output("`outdir'/test_prenofold.html") ///
        preformatted nofold replace
    confirm file "`outdir'/test_prenofold.html"
}
if _rc == 0 {
    display as result "PASS: T17 - Preformatted + nofold combined"
    local test_pass = `test_pass' + 1
}
else {
    display as error "FAIL: T17 - Preformatted + nofold (rc = " _rc ")"
    local test_fail = `test_fail' + 1
}

* -----------------------------------------------------------------------
* T18: Raincloud SMCL (different structure)
* -----------------------------------------------------------------------
local test_total = `test_total' + 1
local rc_fixture "/home/tpcopeland/Stata-Tools/raincloud/demo/console_output.smcl"
capture confirm file "`rc_fixture'"
if _rc == 0 {
    capture noisily {
        logdoc using "`rc_fixture'", output("`outdir'/test_raincloud.html") replace
        confirm file "`outdir'/test_raincloud.html"
    }
    if _rc == 0 {
        display as result "PASS: T18 - Raincloud SMCL conversion"
        local test_pass = `test_pass' + 1
    }
    else {
        display as error "FAIL: T18 - Raincloud SMCL (rc = " _rc ")"
        local test_fail = `test_fail' + 1
    }
}
else {
    display as text "SKIP: T18 - Raincloud fixture not found"
    local test_total = `test_total' - 1
}

* -----------------------------------------------------------------------
* T19: Nodots option
* -----------------------------------------------------------------------
local test_total = `test_total' + 1
capture noisily {
    logdoc using "`smcl_fixture'", output("`outdir'/test_nodots.html") ///
        nodots replace
    confirm file "`outdir'/test_nodots.html"
}
if _rc == 0 {
    display as result "PASS: T19 - Nodots option"
    local test_pass = `test_pass' + 1
}
else {
    display as error "FAIL: T19 - Nodots option (rc = " _rc ")"
    local test_fail = `test_fail' + 1
}

* -----------------------------------------------------------------------
* T20: Date option
* -----------------------------------------------------------------------
local test_total = `test_total' + 1
capture noisily {
    logdoc using "`smcl_fixture'", output("`outdir'/test_date.html") ///
        date("March 2026") replace
    confirm file "`outdir'/test_date.html"
}
if _rc == 0 {
    display as result "PASS: T20 - Date option"
    local test_pass = `test_pass' + 1
}
else {
    display as error "FAIL: T20 - Date option (rc = " _rc ")"
    local test_fail = `test_fail' + 1
}

* -----------------------------------------------------------------------
* T21: Nodots + date + dark combined
* -----------------------------------------------------------------------
local test_total = `test_total' + 1
capture noisily {
    logdoc using "`smcl_fixture'", output("`outdir'/test_combo.html") ///
        nodots date("2026-03-15") theme(dark) replace
    confirm file "`outdir'/test_combo.html"
    assert "`r(theme)'" == "dark"
}
if _rc == 0 {
    display as result "PASS: T21 - Nodots + date + dark combined"
    local test_pass = `test_pass' + 1
}
else {
    display as error "FAIL: T21 - Nodots + date + dark (rc = " _rc ")"
    local test_fail = `test_fail' + 1
}

* -----------------------------------------------------------------------
* T22: Nodots with Markdown
* -----------------------------------------------------------------------
local test_total = `test_total' + 1
capture noisily {
    logdoc using "`smcl_fixture'", output("`outdir'/test_nodots.md") ///
        format(md) nodots date("Test Date") replace
    confirm file "`outdir'/test_nodots.md"
    assert "`r(format)'" == "md"
}
if _rc == 0 {
    display as result "PASS: T22 - Nodots with Markdown"
    local test_pass = `test_pass' + 1
}
else {
    display as error "FAIL: T22 - Nodots + Markdown (rc = " _rc ")"
    local test_fail = `test_fail' + 1
}

* =======================================================================
* RESULTS
* =======================================================================
display ""
display as text "RESULT: `test_pass'/`test_total' tests passed, `test_fail' failed"
if `test_fail' > 0 {
    display as error "SOME TESTS FAILED"
    exit 9
}
else {
    display as result "ALL TESTS PASSED"
}
