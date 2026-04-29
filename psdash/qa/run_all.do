* run_all.do — runs complete QA suite for psdash
* Usage: cd psdash/qa && stata-mp -b do run_all.do

local qa_dir "`c(pwd)'"
local pass = 0
local fail = 0
local skip = 0

local suite_files test_psdash.do validation_psdash.do validation_known_answers.do ///
    crossval_psdash.do crossval_python_psdash.do ///
    test_multigroup_detect.do test_multigroup_overlap_support.do ///
    test_multigroup_balance_weights.do ///
    test_adversarial.do

foreach f of local suite_files {
    capture noisily do "`qa_dir'/`f'"
    local rc = _rc
    if `rc' == 77 {
        local ++skip
        display as text "SKIPPED: `f' (dependency unavailable)"
    }
    else if `rc' {
        local ++fail
        display as error "FAILED: `f' (rc=`rc')"
    }
    else {
        local ++pass
        display as result "PASSED: `f'"
    }
}

display ""
display as text "=== QA Summary: `pass' passed, `fail' failed, `skip' skipped ==="
if `fail' > 0 exit 1
