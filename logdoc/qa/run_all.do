* run_all.do — Run the full logdoc QA suite
* Usage: cd logdoc/qa && stata-mp -b do run_all.do

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

local pass = 0
local fail = 0

foreach f in test_logdoc test_logdoc_py validation_logdoc test_logdoc_phase78 test_logdoc_refactor_guards test_logdoc_v111 {
    capture ado uninstall logdoc
    quietly net install logdoc, from("`pkg_dir'") replace
    capture noisily do "`qa_dir'/`f'.do"
    if _rc {
        local ++fail
        display as error "FAILED: `f'.do"
    }
    else {
        local ++pass
        display as result "PASSED: `f'.do"
    }
}

display ""
display as result "=== QA Summary: `pass' passed, `fail' failed ==="
if `fail' > 0 exit 1
