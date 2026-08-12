clear all
set varabbrev off
set more off
version 16.0

capture log close _all
log using "test_comorbidity_install.log", replace nomsg

local test_count = 0
local pass_count = 0
local fail_count = 0
local skip_count = 0

local qa_dir "`c(pwd)'"
local slash = strrpos("`qa_dir'", "/")
local pkg_dir = substr("`qa_dir'", 1, `slash' - 1)
capture ado uninstall comorbidity

**# Dependency smoke

local ++test_count
capture noisily {
    tempfile sysbase
    local plus "`sysbase'_dependency_plus"
    local personal "`sysbase'_dependency_personal"
    local site "`sysbase'_dependency_site"
    local oldplace "`sysbase'_dependency_oldplace"
    capture mkdir "`plus'"
    capture mkdir "`personal'"
    capture mkdir "`site'"
    capture mkdir "`oldplace'"
    sysdir set SITE "`site'"
    sysdir set PLUS "`plus'"
    sysdir set PERSONAL "`personal'"
    sysdir set OLDPLACE "`oldplace'"
    capture ado uninstall comorbidity
    quietly net install comorbidity, from("`pkg_dir'") replace
    discard
    capture which codescan
    assert _rc != 0
    clear
    input long pid str6 dx1
    1 "E119"
    end
    tempfile dependency_log
    log using "`dependency_log'", name(depmsg) text replace nomsg
    capture noisily comorbidity dx1, id(pid) charlson(original)
    local cmd_rc = _rc
    log close depmsg
    assert `cmd_rc' == 199
    assert strpos(fileread("`dependency_log'"), "net install codescan") > 0
    assert strpos(fileread("`dependency_log'"), ///
        "raw.githubusercontent.com/tpcopeland/Stata-") > 0
    assert strpos(fileread("`dependency_log'"), "Tools/main/codescan") > 0
    assert strpos(fileread("`dependency_log'"), "ssc install codescan") == 0
}
if _rc == 0 {
    display as result "  PASS: clean dependency failure when codescan absent"
    local ++pass_count
}
else {
    display as error "  FAIL: clean dependency failure (error `=_rc')"
    local ++fail_count
}

**# Summary

display as result "Results: `pass_count'/`test_count' passed, `fail_count' failed, `skip_count' skipped"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    display "RESULT: test_comorbidity_install tests=`test_count' pass=`pass_count' fail=`fail_count' skip=`skip_count'"
    exit 1
}
display as result "ALL TESTS PASSED"
display "RESULT: test_comorbidity_install tests=`test_count' pass=`pass_count' fail=`fail_count' skip=`skip_count'"
log close _all
