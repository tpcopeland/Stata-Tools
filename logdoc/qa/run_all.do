* run_all.do - Run a logdoc QA lane
* Usage: cd logdoc/qa && stata-mp -b do run_all.do [quick|core|full]

clear all
set more off
capture log close _all

local qa_dir = regexr("`c(pwd)'", "/+$", "")
capture confirm file "`qa_dir'/test_logdoc.do"
if _rc {
    display as error "Run this script from logdoc/qa"
    exit 601
}
local pkg_dir = regexr("`qa_dir'", "/qa/?$", "")

local lane = lower(strtrim("`1'"))
if "`lane'" == "" local lane "full"
if !inlist("`lane'", "quick", "core", "full") {
    display as error "lane must be quick, core, or full"
    exit 198
}

local suites "test_logdoc test_logdoc_py"
if "`lane'" == "core" {
    local suites "`suites' validation_logdoc test_logdoc_phase78 test_documentation_examples test_logdoc_v114 test_logdoc_v115"
}
if "`lane'" == "full" {
    local suites "`suites' validation_logdoc test_logdoc_phase78 test_documentation_examples test_logdoc_v114 test_logdoc_v115"
    local suites "`suites' test_logdoc_refactor_guards test_logdoc_v111 test_logdoc_v112"
}

local pass = 0
local fail = 0
local total = 0

foreach f of local suites {
    local ++total
    capture ado uninstall logdoc
    capture noisily net install logdoc, from("`pkg_dir'") replace
    local install_rc = _rc
    if `install_rc' {
        local ++fail
        display as error "FAILED: install before `f'.do (rc=`install_rc')"
        continue
    }
    capture noisily do "`qa_dir'/`f'.do"
    local suite_rc = _rc
    if `suite_rc' {
        local ++fail
        display as error "FAILED: `f'.do (rc=`suite_rc')"
    }
    else {
        local ++pass
        display as result "PASSED: `f'.do"
    }
}

display ""
display as result "=== QA Summary (`lane'): `pass' passed, `fail' failed ==="
display as result "RESULT: run_all tests=`total' pass=`pass' fail=`fail'"
if `fail' > 0 exit 1
