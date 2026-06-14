* test_logdoc.do — Functional tests for logdoc package v1.4.2
* Location: logdoc/qa/
* Run: stata-mp -e do test_logdoc.do

clear all
set more off

local qadir = regexr("`c(pwd)'", "/+$", "")
capture confirm file "`qadir'/logdoc.pkg"
if _rc == 0 {
    local pkgdir "`qadir'"
    local qadir "`pkgdir'/qa"
}
else {
    local pkgdir = regexr("`qadir'", "/qa/?$", "")
}
capture confirm file "`pkgdir'/logdoc.pkg"
if _rc {
    display as error "Could not locate logdoc package root from c(pwd)=`c(pwd)'"
    exit 601
}
local repo_root = regexr("`pkgdir'", "/[^/]+$", "")
local workspace_root = regexr("`repo_root'", "/[^/]+$", "")

capture ado uninstall logdoc
net install logdoc, from("`pkgdir'") replace

local test_pass = 0
local test_fail = 0
local test_total = 0
local stata_python ""
local has_stata_python 0
capture quietly python: from sfi import Macro; import sys; Macro.setLocal("stata_python", sys.executable)
if _rc == 0 & `"`stata_python'"' != "" local has_stata_python 1

* Test fixture: generate a minimal SMCL log for testing
tempfile smcl_fixture_file
local smcl_fixture "`smcl_fixture_file'"
capture log close _logdoc_fixture
log using "`smcl_fixture'", replace smcl name(_logdoc_fixture) nomsg
sysuse auto, clear
summarize price mpg weight
regress price mpg weight i.foreign
log close _logdoc_fixture

local rc_fixture ""
tempfile rc_fixture_file
local rc_fixture "`rc_fixture_file'"
capture log close _logdoc_fixture2
log using "`rc_fixture'", replace smcl name(_logdoc_fixture2) nomsg
sysuse auto, clear
tabulate foreign rep78
log close _logdoc_fixture2

local outdir "`c(tmpdir)'/logdoc_tests"
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
capture erase "`outdir'/test_qmd.qmd"

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
    if `has_stata_python' {
        assert `"$LOGDOC_LAST_PYTHON"' == "`stata_python'"
    }
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
capture {
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
* T10: PDF generation
* -----------------------------------------------------------------------
local test_total = `test_total' + 1
tempfile wkcheck
shell which wkhtmltopdf > "`wkcheck'" 2>/dev/null
local has_wkhtmltopdf = 0
capture {
    file open wkfh using "`wkcheck'", read text
    file read wkfh wkline
    file close wkfh
    if regexm("`wkline'", "wkhtmltopdf") {
        local has_wkhtmltopdf = 1
    }
}
capture noisily {
    capture erase "`outdir'/test_pdf.pdf"
    logdoc using "`smcl_fixture'", output("`outdir'/test_pdf.pdf") ///
        format(pdf) replace
    confirm file "`outdir'/test_pdf.pdf"
    if `has_wkhtmltopdf' {
        tempname pdfh
        file open `pdfh' using "`outdir'/test_pdf.pdf", read text
        file read `pdfh' pdfsig
        file close `pdfh'
        assert strpos("`pdfsig'", "%PDF") == 1
    }
}
if `has_wkhtmltopdf' & _rc == 0 {
    display as result "PASS: T10 - PDF generation"
    local test_pass = `test_pass' + 1
}
else if !`has_wkhtmltopdf' & inlist(_rc, 198, 601) {
    display as result "PASS: T10 - PDF dependency correctly enforced"
    local test_pass = `test_pass' + 1
}
else {
    display as error "FAIL: T10 - PDF generation (rc = " _rc ")"
    local test_fail = `test_fail' + 1
}

* -----------------------------------------------------------------------
* T11: Invalid theme
* -----------------------------------------------------------------------
local test_total = `test_total' + 1
capture {
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
* T12: Missing input file
* -----------------------------------------------------------------------
local test_total = `test_total' + 1
capture {
    logdoc using "/nonexistent/file.smcl", output("`outdir'/bad.html") replace
}
if _rc == 601 {
    display as result "PASS: T12 - Missing input rejected (rc=601)"
    local test_pass = `test_pass' + 1
}
else {
    display as error "FAIL: T12 - Missing input (got rc = " _rc ", expected 601)"
    local test_fail = `test_fail' + 1
}

* -----------------------------------------------------------------------
* T13: Run option rejects non-.do file
* -----------------------------------------------------------------------
local test_total = `test_total' + 1
capture {
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
* T14b: Run option sets child Stata linesize to maximum
* -----------------------------------------------------------------------
local test_total = `test_total' + 1
local _old_linesize = c(linesize)
capture noisily {
    local dofile "`outdir'/test_run_linesize.do"
    local smclfile "`outdir'/test_run_linesize.smcl"
    local grepout "`outdir'/test_run_linesize_grep.txt"
    capture erase "`dofile'"
    capture erase "`smclfile'"
    capture erase "`grepout'"

    tempname lsfh
    file open `lsfh' using "`dofile'", write text replace
    file write `lsfh' `"log using "`smclfile'", replace smcl name(linesize) nomsg"' _n
    file write `lsfh' "display c(linesize)" _n
    file write `lsfh' "log close linesize" _n
    file close `lsfh'

    set linesize 90
    logdoc using "`dofile'", output("`outdir'/test_run_linesize.html") ///
        run replace quiet
    confirm file "`outdir'/test_run_linesize.html"
    assert c(linesize) == 90

    shell grep -c "{res}255" "`smclfile'" > "`grepout'" 2>&1
    tempname grfh
    file open `grfh' using "`grepout'", read text
    file read `grfh' _gline
    file close `grfh'
    assert real("`_gline'") > 0
}
local _t14b_rc = _rc
capture set linesize `_old_linesize'
if `_t14b_rc' == 0 {
    display as result "PASS: T14b - Run option uses linesize 255"
    local test_pass = `test_pass' + 1
}
else {
    display as error "FAIL: T14b - Run linesize max (rc = `_t14b_rc')"
    local test_fail = `test_fail' + 1
}

* -----------------------------------------------------------------------
* T14c: Run option still works when .do file relies on batch log
* -----------------------------------------------------------------------
local test_total = `test_total' + 1
local _old_linesize = c(linesize)
capture noisily {
    local dofile "`outdir'/test_run_autolog.do"
    local grepout "`outdir'/test_run_autolog_grep.txt"
    capture erase "`dofile'"
    capture erase "`outdir'/test_run_autolog.html"
    capture erase "`grepout'"

    tempname autofh
    file open `autofh' using "`dofile'", write text replace
    file write `autofh' "version 16.0" _n
    file write `autofh' "display c(linesize)" _n
    file close `autofh'

    set linesize 90
    logdoc using "`dofile'", output("`outdir'/test_run_autolog.html") ///
        run replace quiet
    confirm file "`outdir'/test_run_autolog.html"
    assert c(linesize) == 90

    shell grep -c "255" "`outdir'/test_run_autolog.html" > "`grepout'" 2>&1
    tempname autogrfh
    file open `autogrfh' using "`grepout'", read text
    file read `autogrfh' _gline
    file close `autogrfh'
    assert real("`_gline'") > 0
}
local _t14c_rc = _rc
capture set linesize `_old_linesize'
if `_t14c_rc' == 0 {
    display as result "PASS: T14c - Run option captures wrapper batch log"
    local test_pass = `test_pass' + 1
}
else {
    display as error "FAIL: T14c - Run batch-log fallback (rc = `_t14c_rc')"
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

* -----------------------------------------------------------------------
* T23: varabbrev restore — preserved when OFF (v1.2.1 fix)
* -----------------------------------------------------------------------
local test_total = `test_total' + 1
capture noisily {
    set varabbrev off
    logdoc using "`smcl_fixture'", output("`outdir'/test_va_off.html") replace
    assert "`c(varabbrev)'" == "off"
    set varabbrev on
}
if _rc == 0 {
    display as result "PASS: T23 - varabbrev restored when OFF"
    local test_pass = `test_pass' + 1
}
else {
    set varabbrev on
    display as error "FAIL: T23 - varabbrev restore OFF (rc = " _rc ")"
    local test_fail = `test_fail' + 1
}

* -----------------------------------------------------------------------
* T24: varabbrev restore — preserved when ON
* -----------------------------------------------------------------------
local test_total = `test_total' + 1
capture noisily {
    set varabbrev on
    logdoc using "`smcl_fixture'", output("`outdir'/test_va_on.html") replace
    assert "`c(varabbrev)'" == "on"
}
if _rc == 0 {
    display as result "PASS: T24 - varabbrev restored when ON"
    local test_pass = `test_pass' + 1
}
else {
    display as error "FAIL: T24 - varabbrev restore ON (rc = " _rc ")"
    local test_fail = `test_fail' + 1
}

* -----------------------------------------------------------------------
* T25: varabbrev restore on error path
* -----------------------------------------------------------------------
local test_total = `test_total' + 1
capture noisily {
    set varabbrev off
    capture logdoc using "/nonexistent/file.smcl", output("`outdir'/bad.html") replace
    assert "`c(varabbrev)'" == "off"
    set varabbrev on
}
if _rc == 0 {
    display as result "PASS: T25 - varabbrev restored on error"
    local test_pass = `test_pass' + 1
}
else {
    set varabbrev on
    display as error "FAIL: T25 - varabbrev restore error (rc = " _rc ")"
    local test_fail = `test_fail' + 1
}

* -----------------------------------------------------------------------
* T26: format(both) with no-extension output (v1.2.1 fix)
* -----------------------------------------------------------------------
local test_total = `test_total' + 1
capture noisily {
    capture erase "`outdir'/test_noext.html"
    capture erase "`outdir'/test_noext.md"
    logdoc using "`smcl_fixture'", output("`outdir'/test_noext") ///
        format(both) replace
    confirm file "`outdir'/test_noext.html"
    confirm file "`outdir'/test_noext.md"
}
if _rc == 0 {
    display as result "PASS: T26 - format(both) no-extension output"
    local test_pass = `test_pass' + 1
}
else {
    display as error "FAIL: T26 - format(both) no-extension (rc = " _rc ")"
    local test_fail = `test_fail' + 1
}

* -----------------------------------------------------------------------
* T27: format(both) with .md extension
* -----------------------------------------------------------------------
local test_total = `test_total' + 1
capture noisily {
    capture erase "`outdir'/test_both_md.html"
    capture erase "`outdir'/test_both_md.md"
    logdoc using "`smcl_fixture'", output("`outdir'/test_both_md.md") ///
        format(both) replace
    confirm file "`outdir'/test_both_md.html"
    confirm file "`outdir'/test_both_md.md"
}
if _rc == 0 {
    display as result "PASS: T27 - format(both) with .md extension"
    local test_pass = `test_pass' + 1
}
else {
    display as error "FAIL: T27 - format(both) .md ext (rc = " _rc ")"
    local test_fail = `test_fail' + 1
}

* -----------------------------------------------------------------------
* T28: output() abbreviation — out() works (v1.2.1 fix)
* -----------------------------------------------------------------------
local test_total = `test_total' + 1
capture noisily {
    logdoc using "`smcl_fixture'", out("`outdir'/test_abbrev.html") replace
    confirm file "`outdir'/test_abbrev.html"
}
if _rc == 0 {
    display as result "PASS: T28 - out() abbreviation works"
    local test_pass = `test_pass' + 1
}
else {
    display as error "FAIL: T28 - out() abbreviation (rc = " _rc ")"
    local test_fail = `test_fail' + 1
}

* -----------------------------------------------------------------------
* T29: replace abbreviation — rep works
* -----------------------------------------------------------------------
local test_total = `test_total' + 1
capture noisily {
    logdoc using "`smcl_fixture'", output("`outdir'/test_reabbrev.html") replace
    logdoc using "`smcl_fixture'", output("`outdir'/test_reabbrev.html") rep
    confirm file "`outdir'/test_reabbrev.html"
}
if _rc == 0 {
    display as result "PASS: T29 - rep (replace abbreviation) works"
    local test_pass = `test_pass' + 1
}
else {
    display as error "FAIL: T29 - rep abbreviation (rc = " _rc ")"
    local test_fail = `test_fail' + 1
}

* -----------------------------------------------------------------------
* T30: Package installation — core files discoverable
* -----------------------------------------------------------------------
local test_total = `test_total' + 1
capture noisily {
    which logdoc
    capture findfile logdoc_render.py
    assert _rc == 0
    * CSS files are not installed by net install (Stata doesn't place .css);
    * the Python script has embedded CSS fallback, so this is expected.
}
if _rc == 0 {
    display as result "PASS: T30 - Package files discoverable"
    local test_pass = `test_pass' + 1
}
else {
    display as error "FAIL: T30 - Package files (rc = " _rc ")"
    local test_fail = `test_fail' + 1
}

* -----------------------------------------------------------------------
* T31: Quarto Markdown generation
* -----------------------------------------------------------------------
local test_total = `test_total' + 1
capture noisily {
    logdoc using "`smcl_fixture'", output("`outdir'/test_qmd.qmd") replace
    confirm file "`outdir'/test_qmd.qmd"
    assert "`r(format)'" == "qmd"
}
if _rc == 0 {
    display as result "PASS: T31 - Quarto Markdown generation"
    local test_pass = `test_pass' + 1
}
else {
    display as error "FAIL: T31 - Quarto Markdown generation (rc = " _rc ")"
    local test_fail = `test_fail' + 1
}

* -----------------------------------------------------------------------
* T32: Stata Python default beats stale .logdocrc python path
* -----------------------------------------------------------------------
local test_total = `test_total' + 1
capture noisily {
    local t32_dir "`outdir'/t32_stata_first"
    capture mkdir "`t32_dir'"
    cd "`t32_dir'"
    quietly file open t32cfg using ".logdocrc", write text replace
    file write t32cfg "python=/definitely/not/logdoc/config-python" _n
    file close t32cfg

    if `has_stata_python' {
        logdoc using "`smcl_fixture'", ///
            output("`outdir'/test_stata_first_config.html") replace quiet
        confirm file "`outdir'/test_stata_first_config.html"
        assert `"$LOGDOC_LAST_PYTHON"' == "`stata_python'"
    }
    else {
        display as result "SKIP: T32 - Stata Python is not configured"
    }
    cd "`qadir'"
}
if _rc == 0 {
    display as result "PASS: T32 - Stata Python default precedes .logdocrc python"
    local test_pass = `test_pass' + 1
}
else {
    display as error "FAIL: T32 - Stata-first .logdocrc precedence (rc = " _rc ")"
    capture cd "`qadir'"
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
