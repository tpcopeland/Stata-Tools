clear all
set varabbrev off
version 16.0

capture log close _all
log using "run_all.log", replace nomsg

* run_all.do - curated compact-package QA gate for raincloud
* Usage: stata-mp -b do run_all.do [quick|full]

args mode extra
if "`mode'" == "" local mode "full"
if "`extra'" != "" {
    display as error "run_all.do accepts at most one mode argument"
    capture log close _all
    exit 198
}
if !inlist("`mode'", "quick", "full") {
    display as error "mode must be quick or full"
    capture log close _all
    exit 198
}

local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
do "`qa_dir'/_raincloud_qa_common.do"
_raincloud_qa_bootstrap "`pkg_dir'"

* Explicit membership: both lanes are the same compact release gate.
local suites "test_raincloud.do validation_raincloud.do"
local suite_count 0
local suite_pass 0
local suite_fail 0
local failed ""

foreach suite of local suites {
    local ++suite_count
    capture noisily do "`qa_dir'/`suite'"
    local suite_rc = _rc
    if `suite_rc' == 0 {
        local ++suite_pass
        display as result "RUNNER PASS: `suite'"
    }
    else {
        local ++suite_fail
        local failed "`failed' `suite'"
        display as error "RUNNER FAIL: `suite' (rc `suite_rc')"
    }
    capture log close _all
    log using "run_all.log", append nomsg
}

local runner_rc = cond(`suite_fail' > 0, 1, 0)
if `runner_rc' == 0 {
    display as result "ALL RUNNER SUITES PASSED"
}
else {
    display as error "RUNNER FAILED: `failed'"
}
display "RESULT: run_all tests=`suite_count' pass=`suite_pass' fail=`suite_fail'"

file open _raincloud_status using "run_all_status.txt", write replace text
file write _raincloud_status "mode=`mode'" _n
file write _raincloud_status "suites=`suite_count' pass=`suite_pass' fail=`suite_fail'" _n
file write _raincloud_status "RESULT: run_all tests=`suite_count' pass=`suite_pass' fail=`suite_fail'" _n
file close _raincloud_status

capture log close _all
exit `runner_rc'
