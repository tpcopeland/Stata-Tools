clear all
set varabbrev off
set more off
version 16.0

args mode
if "`mode'" == "" {
    local mode "full"
}
if !inlist("`mode'", "quick", "core", "full") {
    display as error "mode must be quick, core, or full"
    exit 198
}

capture ado uninstall comorbidity

local quick "test_dictionary.do test_weights.do test_hierarchy.do test_comorbidity.do test_comorbidity_errors.do test_comorbidity_oracle.do"
local core "`quick' test_regressions.do test_documentation_examples.do validation_comorbidity.do validation_dictionary_quan2005.do test_comorbidity_adversarial.do test_comorbidity_hostile.do"
local full "`core' test_comorbidity_install.do crossval_comorbidity_r.do"
local suites "``mode''"

local suite_count = 0
local suite_pass = 0
local suite_fail = 0

foreach suite of local suites {
    local ++suite_count
    display as text _n "Running `suite'"
    capture noisily do "`suite'"
    if _rc == 0 {
        local ++suite_pass
        display as result "  PASS: `suite'"
    }
    else {
        local ++suite_fail
        display as error "  FAIL: `suite' (error `=_rc')"
    }
}

display as result _n "QA suites: `suite_pass'/`suite_count' passed, `suite_fail' failed"
display "RESULT: run_all tests=`suite_count' pass=`suite_pass' fail=`suite_fail'"
if `suite_fail' > 0 {
    exit 1
}
