* run_all.do - Run the complete codescan QA suite
* Usage: cd codescan/qa && stata-mp -b do run_all.do

clear all
version 16.0

local qa_dir "`c(pwd)'"
local pass = 0
local fail = 0

foreach f in ///
    test_release_integrity ///
    test_codescan_install_docs ///
    test_codescan ///
    test_countrows ///
    test_codescan_regressions ///
    test_documentation_examples ///
    test_codescan_adversarial ///
    test_codescan_describe_adversarial ///
    test_codescan_stress_adversarial ///
    _test_known_answers ///
    _test_mata_opt ///
    validation_codescan ///
    validation_codescan_known_answers ///
    validation_builtin_codefiles ///
    validation_codescan_io ///
    validation_codescan_output ///
    validation_countrows ///
    validation_codescan_describe ///
    validation_codescan_describe_adversarial ///
    crossval_codescan {

    cd "`qa_dir'"
    clear all
    capture noisily do "`qa_dir'/`f'.do"
    local suite_rc = _rc
    cd "`qa_dir'"
    if `suite_rc' {
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
