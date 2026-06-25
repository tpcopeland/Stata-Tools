clear all
version 16.0
set varabbrev off

local mode "`1'"
if "`mode'" == "" {
    local mode "full"
}
if !inlist("`mode'", "quick", "core", "full") {
    display as error "mode must be quick, core, or full"
    exit 198
}

local quick_suites "test_kmplot.do"
local core_suites "`quick_suites' validation_kmplot.do"
local full_suites "`core_suites'"
local suites "``mode'_suites'"

local qa_dir "`c(pwd)'"
do "`qa_dir'/_kmplot_qa_common.do"
_kmplot_qa_bootstrap

local suite_count = 0
local pass_count = 0
local fail_count = 0

foreach suite of local suites {
    local ++suite_count
    display as text "Running `suite'"
    capture noisily do "`suite'"
    local suite_rc = _rc
    if `suite_rc' == 0 {
        local ++pass_count
        display as result "  PASS: `suite'"
    }
    else {
        local ++fail_count
        display as error "  FAIL: `suite' (rc=`suite_rc')"
    }
}

display as text "kmplot QA suites: `pass_count'/`suite_count' passed"
display "RESULT: run_all tests=`suite_count' pass=`pass_count' fail=`fail_count'"

if `fail_count' > 0 {
    exit 1
}
