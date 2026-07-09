* Regression tests for logdoc v1.1.2 fixes
* Covers shell-bound argument validation and compound-quote forwarding.

clear all
set varabbrev off
capture log close _all

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

local outdir "`c(tmpdir)'/logdoc_v112_tests"
capture mkdir "`outdir'"
local smcl_fixture "`outdir'/v112_input.smcl"
tempname fh
quietly file open `fh' using "`smcl_fixture'", write text replace
file write `fh' "{smcl}" _n
file write `fh' "{com}. display 2+2" _n
file write `fh' "{res}4" _n
file close `fh'

* V112-T1: shell substitution in an output path is rejected before execution.
local ++test_total
local dollar = char(36)
local marker "`outdir'/v112_output_marker"
local dangerous_output "`outdir'/blocked`dollar'(touch `marker').html"
capture erase "`marker'"
capture logdoc using "`smcl_fixture'", output(`"`dangerous_output'"') replace quiet
local t1_rc = _rc
capture confirm file "`marker'"
local t1_marker = (_rc == 0)
if `t1_rc' == 198 & !`t1_marker' {
    display as result "V112-T1 PASS: unsafe output path rejected before shell execution"
    local ++test_pass
}
else {
    display as error "V112-T1 FAIL: rc=`t1_rc' (want 198), marker=`t1_marker' (want 0)"
    local ++test_fail
}

* V112-T2: the Python setup command applies the same shell-argument guard.
local ++test_total
local py_marker "`outdir'/v112_python_marker"
local dangerous_python "`dollar'(touch `py_marker')"
capture erase "`py_marker'"
capture logdoc_py, python(`"`dangerous_python'"') quiet
local t2_rc = _rc
capture confirm file "`py_marker'"
local t2_marker = (_rc == 0)
if `t2_rc' == 198 & !`t2_marker' {
    display as result "V112-T2 PASS: unsafe python() rejected before shell execution"
    local ++test_pass
}
else {
    display as error "V112-T2 FAIL: rc=`t2_rc' (want 198), marker=`t2_marker' (want 0)"
    local ++test_fail
}

* V112-T3: batch forwarding preserves embedded double quotes in title().
local ++test_total
local smcl_fixture2 "`outdir'/v112_input2.smcl"
copy "`smcl_fixture'" "`smcl_fixture2'", replace
local batchdir "`outdir'/batch"
capture mkdir "`batchdir'"
local quoted_title `"Batch "quoted" report"'
capture noisily {
    logdoc batch, input("`outdir'/v112_input*.smcl") outdir("`batchdir'") ///
        title(`"`quoted_title'"') replace quiet
    assert r(n_files) == 2
    assert r(n_failed) == 0
    confirm file "`batchdir'/v112_input.html"
    confirm file "`batchdir'/v112_input2.html"
}
if _rc == 0 {
    display as result "V112-T3 PASS: batch preserves quoted title()"
    local ++test_pass
}
else {
    display as error "V112-T3 FAIL: batch quote forwarding (rc=`_rc')"
    local ++test_fail
}

* V112-T4: replay preserves embedded double quotes in remembered options.
local ++test_total
local replay_out "`outdir'/replay.html"
capture noisily {
    logdoc using "`smcl_fixture'", output("`replay_out'") ///
        title(`"`quoted_title'"') replace quiet
    logdoc replay
    confirm file "`replay_out'"
}
if _rc == 0 {
    display as result "V112-T4 PASS: replay preserves quoted title()"
    local ++test_pass
}
else {
    display as error "V112-T4 FAIL: replay quote forwarding (rc=`_rc')"
    local ++test_fail
}

display as result "v1.1.2 Regression Test Results: `test_pass'/`test_total' passed, `test_fail' failed"
if `test_fail' > 0 {
    display as error "SOME TESTS FAILED"
    exit 1
}
display as result "ALL TESTS PASSED"
display "RESULT: test_logdoc_v112 tests=`test_total' pass=`test_pass' fail=`test_fail'"
