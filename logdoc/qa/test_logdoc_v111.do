* Regression tests for logdoc v1.1.1 fixes
* Tests: V111-T1 through V111-T8
* Covers: renderer-failure detection with pre-existing output, replay of
* run conversions, combine format guards, stataexe()/run pairing,
* UTF-8 output under a non-UTF-8 locale, session-log preservation on
* failed stop, and ~/.logdocrc resolution in logdoc_py.
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

capture ado uninstall logdoc
quietly net install logdoc, from("`pkgdir'") replace

local test_pass = 0
local test_fail = 0
local test_total = 0

local outdir "`c(tmpdir)'/logdoc_v111_tests"
capture mkdir "`outdir'"

* Minimal SMCL fixture (includes a table so the output contains
* box-drawing characters, which is what the UTF-8 test needs)
local smcl_fixture "`outdir'/v111_input.smcl"
tempname fh
quietly file open `fh' using "`smcl_fixture'", write text replace
file write `fh' "{smcl}" _n
file write `fh' "{com}. display 2+2" _n
file write `fh' "{res}4" _n
file write `fh' "{com}. summarize price" _n
file write `fh' "{txt}" _n
file write `fh' "    Variable {c |}        Obs        Mean" _n
file write `fh' "{hline 13}{c +}{hline 25}" _n
file write `fh' "       price {c |}         74    6165.257" _n
file write `fh' "{hline 13}{c BT}{hline 25}" _n
file write `fh' "{com}. * end of fixture" _n
file close `fh'

local smcl_fixture2 "`outdir'/v111_input2.smcl"
capture erase "`smcl_fixture2'"
copy "`smcl_fixture'" "`smcl_fixture2'"

* =========================================================================
* V111-T1: renderer failure with pre-existing output + replace must fail
* (previously reported success and left the stale file in place)
* =========================================================================
local test_total = `test_total' + 1
local t1_out "`outdir'/t1_stale.html"
capture erase "`t1_out'"
quietly logdoc using "`smcl_fixture'", output("`t1_out'") replace quiet
quietly checksum "`t1_out'"
local t1_sum1 = r(checksum)
* Invalid keep() regex makes the renderer exit with an error
capture logdoc using "`smcl_fixture'", output("`t1_out'") replace quiet ///
    keep("[unclosed")
local t1_rc = _rc
quietly checksum "`t1_out'"
local t1_unchanged = (r(checksum) == `t1_sum1')
if `t1_rc' != 0 & `t1_unchanged' {
    display as result "V111-T1 PASS: renderer failure reported (rc=`t1_rc'), stale file untouched"
    local test_pass = `test_pass' + 1
}
else {
    display as error "V111-T1 FAIL: rc=`t1_rc' (want !=0), unchanged=`t1_unchanged' (want 1)"
    local test_fail = `test_fail' + 1
}

* =========================================================================
* V111-T2: same false-success class for combine
* =========================================================================
local test_total = `test_total' + 1
local t2_out "`outdir'/t2_combined.html"
capture erase "`t2_out'"
quietly logdoc combine using "`smcl_fixture'" "`smcl_fixture2'", ///
    output("`t2_out'") replace quiet
capture logdoc combine using "`smcl_fixture'" "`smcl_fixture2'", ///
    output("`t2_out'") replace quiet keep("[unclosed")
local t2_rc = _rc
if `t2_rc' != 0 {
    display as result "V111-T2 PASS: combine renderer failure reported (rc=`t2_rc')"
    local test_pass = `test_pass' + 1
}
else {
    display as error "V111-T2 FAIL: combine reported success despite renderer failure"
    local test_fail = `test_fail' + 1
}

* =========================================================================
* V111-T3: logdoc replay after a run conversion re-executes the .do file
* (previously replay rendered the .do source; executed output vanished)
* =========================================================================
local test_total = `test_total' + 1
local t3_do "`outdir'/t3_child.do"
tempname fh3
quietly file open `fh3' using "`t3_do'", write text replace
file write `fh3' `"display "HELLO_RUN_V111""' _n
file close `fh3'
local t3_out "`outdir'/t3_run.html"
capture erase "`t3_out'"
capture noisily logdoc using "`t3_do'", run output("`t3_out'") quiet
local t3_rc = _rc
local t3_ok = 0
if `t3_rc' == 0 {
    * Erase and replay: the output must be regenerated with executed
    * results, not a source listing
    capture erase "`t3_out'"
    capture noisily logdoc replay
    local t3_rc = _rc
    if `t3_rc' == 0 {
        capture confirm file "`t3_out'"
        if !_rc {
            tempfile grepout
            shell grep -c "res.>HELLO_RUN_V111" "`t3_out'" > "`grepout'" 2>&1
            tempname gfh
            file open `gfh' using "`grepout'", read text
            file read `gfh' _gline
            file close `gfh'
            if real("`_gline'") > 0 & !missing(real("`_gline'")) local t3_ok = 1
        }
    }
}
if `t3_ok' {
    display as result "V111-T3 PASS: replay re-executed the run conversion"
    local test_pass = `test_pass' + 1
}
else {
    display as error "V111-T3 FAIL: rc=`t3_rc'; executed output missing after replay"
    local test_fail = `test_fail' + 1
}

* =========================================================================
* V111-T4: combine with a .pdf/.docx output name is rejected
* (previously wrote HTML bytes into report.pdf)
* =========================================================================
local test_total = `test_total' + 1
capture logdoc combine using "`smcl_fixture'" "`smcl_fixture2'", ///
    output("`outdir'/t4_bad.pdf") replace quiet
local t4_rc1 = _rc
capture logdoc combine using "`smcl_fixture'" "`smcl_fixture2'", ///
    output("`outdir'/t4_bad.docx") replace quiet
local t4_rc2 = _rc
if `t4_rc1' == 198 & `t4_rc2' == 198 {
    display as result "V111-T4 PASS: combine rejects .pdf and .docx outputs (rc=198)"
    local test_pass = `test_pass' + 1
}
else {
    display as error "V111-T4 FAIL: rc pdf=`t4_rc1' docx=`t4_rc2' (want 198/198)"
    local test_fail = `test_fail' + 1
}

* =========================================================================
* V111-T5: stataexe() without run is an error
* =========================================================================
local test_total = `test_total' + 1
capture logdoc using "`smcl_fixture'", output("`outdir'/t5.html") ///
    replace quiet stataexe("stata-mp")
local t5_rc = _rc
if `t5_rc' == 198 {
    display as result "V111-T5 PASS: stataexe() without run rejected (rc=198)"
    local test_pass = `test_pass' + 1
}
else {
    display as error "V111-T5 FAIL: rc=`t5_rc' (want 198)"
    local test_fail = `test_fail' + 1
}

* =========================================================================
* V111-T6: renderer writes UTF-8 output under a non-UTF-8 locale
* (previously used the locale default encoding and crashed on the
* box-drawing characters every Stata table produces)
* =========================================================================
local test_total = `test_total' + 1
quietly logdoc_py, quiet
local t6_python `"`r(python)'"'
local t6_renderer `"`r(renderer)'"'
local t6_out "`outdir'/t6_clocale.md"
capture erase "`t6_out'"
local t6_ok = 0
if `"`t6_python'"' != "" & `"`t6_renderer'"' != "" {
    shell LC_ALL=C "`t6_python'" "`t6_renderer'" "`smcl_fixture'" ///
        "`t6_out'" --format md > /dev/null 2>&1
    capture confirm file "`t6_out'"
    if !_rc {
        * Appending re-reads the file, exercising the read side too
        shell LC_ALL=C "`t6_python'" "`t6_renderer'" "`smcl_fixture'" ///
            "`t6_out'" --format md --append > /dev/null 2>&1
        tempfile grepout6
        shell grep -c "HELLO\|price" "`t6_out'" > "`grepout6'" 2>&1
        local t6_ok = 1
    }
}
if `t6_ok' {
    display as result "V111-T6 PASS: renderer wrote and appended output under LC_ALL=C"
    local test_pass = `test_pass' + 1
}
else {
    display as error "V111-T6 FAIL: renderer failed under a non-UTF-8 locale"
    local test_fail = `test_fail' + 1
}

* =========================================================================
* V111-T7: failed logdoc stop preserves the captured session log
* (previously the only copy of the session transcript was erased)
* =========================================================================
local test_total = `test_total' + 1
capture logdoc stop
quietly logdoc start, output("`outdir'/t7_session.html") replace quiet ///
    python("/nonexistent/logdoc_v111_python3")
display "V111_T7_SESSION_MARKER"
local t7_tmplog `"$LOGDOC_TMPLOG"'
capture logdoc stop
local t7_rc = _rc
capture confirm file "`t7_tmplog'"
local t7_preserved = (_rc == 0)
if `t7_rc' != 0 & `t7_preserved' {
    display as result "V111-T7 PASS: failed stop preserved the session log (rc=`t7_rc')"
    local test_pass = `test_pass' + 1
}
else {
    display as error "V111-T7 FAIL: rc=`t7_rc' (want !=0), preserved=`t7_preserved' (want 1)"
    local test_fail = `test_fail' + 1
}
capture erase "`t7_tmplog'"

* =========================================================================
* V111-T8: logdoc_py reads python= from ~/.logdocrc
* (previously only the project .logdocrc was read; run in a child Stata
* with HOME pointed at a fixture directory)
* =========================================================================
local test_total = `test_total' + 1
local t8_home "`outdir'/t8_home"
local t8_cwd "`outdir'/t8_cwd"
capture mkdir "`t8_home'"
capture mkdir "`t8_cwd'"
tempname fh8
quietly file open `fh8' using "`t8_home'/.logdocrc", write text replace
file write `fh8' "python=/logdoc/v111/home/marker" _n
file close `fh8'
tempname fh8b
quietly file open `fh8b' using "`t8_cwd'/t8_child.do", write text replace
file write `fh8b' `"adopath ++ "`pkgdir'""' _n
file write `fh8b' `"run "`pkgdir'/logdoc_py.ado""' _n
file write `fh8b' "local v" _n
file write `fh8b' "local p" _n
file write `fh8b' "local r" _n
file write `fh8b' "_logdoc_py_read_config, result(v) path(p) read(r)" _n
file write `fh8b' "tempname rfh" _n
file write `fh8b' `"quietly file open \`rfh' using "`t8_cwd'/t8_result.txt", write text replace"' _n
file write `fh8b' `"file write \`rfh' "\`v'" _n"' _n
file write `fh8b' "file close \`rfh'" _n
file close `fh8b'
capture erase "`t8_cwd'/t8_result.txt"
shell cd "`t8_cwd'" && HOME="`t8_home'" stata-mp -b do "`t8_cwd'/t8_child.do" > /dev/null 2>&1
local t8_value ""
capture {
    tempname rfh8
    file open `rfh8' using "`t8_cwd'/t8_result.txt", read text
    file read `rfh8' t8_value
    file close `rfh8'
}
if `"`t8_value'"' == "/logdoc/v111/home/marker" {
    display as result "V111-T8 PASS: logdoc_py resolves python= from ~/.logdocrc"
    local test_pass = `test_pass' + 1
}
else {
    display as error `"V111-T8 FAIL: got "`t8_value'" (want /logdoc/v111/home/marker)"'
    local test_fail = `test_fail' + 1
}

* =========================================================================
* Summary
* =========================================================================
display as result "v1.1.1 Regression Test Results: `test_pass'/`test_total' passed, `test_fail' failed"

if `test_fail' > 0 {
    display as error "SOME TESTS FAILED"
    exit 1
}
else {
    display as result "ALL TESTS PASSED"
}
