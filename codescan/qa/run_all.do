* run_all.do - Run the complete codescan QA suite
* Usage: cd codescan/qa && stata-mp -b do run_all.do

clear all
set more off
version 16.0

local qa_dir "`c(pwd)'"
local pass = 0
local fail = 0

foreach f in ///
    test_codescan ///
    test_countrows ///
    test_codescan_v101 ///
    test_documentation_examples ///
    validation_codescan ///
    validation_countrows ///
    validation_codescan_describe ///
    crossval_codescan {

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
