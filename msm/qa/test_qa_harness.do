* test_qa_harness.do
* Negative and positive controls for the run_all.do child-result handshake.

version 16.0
clear all
set more off
set varabbrev off

capture log close _all
log using "test_qa_harness.log", replace text nomsg

local qa_dir "`c(pwd)'"
local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

* H1: impossible arithmetic must fail closed.
local ++test_count
capture noisily {
    capture quietly do "`qa_dir'/_record_qa_result.do" _probe_bad 4 3 0 0
    assert _rc == 459
}
if _rc == 0 {
    display as result "PASS H1: mismatched result arithmetic is refused"
    local ++pass_count
}
else {
    display as error "FAIL H1: mismatched result arithmetic was accepted"
    local ++fail_count
    local failed_tests "`failed_tests' H1"
}

* H2: negative and non-integer counts must fail as malformed input.
local ++test_count
capture noisily {
    capture quietly do "`qa_dir'/_record_qa_result.do" _probe_negative 1 1 -1 1
    assert _rc == 198
    capture quietly do "`qa_dir'/_record_qa_result.do" _probe_fraction 1.5 1 0 0.5
    assert _rc == 198
}
if _rc == 0 {
    display as result "PASS H2: malformed result counts are refused"
    local ++pass_count
}
else {
    display as error "FAIL H2: malformed result counts were accepted"
    local ++fail_count
    local failed_tests "`failed_tests' H2"
}

* H3: a reconciled result, including an explicit skip, is published exactly.
local ++test_count
capture noisily {
    do "`qa_dir'/_record_qa_result.do" _probe_good 4 2 1 1
    assert "${msm_qa_result_name}" == "_probe_good"
    assert real("${msm_qa_result_tests}") == 4
    assert real("${msm_qa_result_pass}") == 2
    assert real("${msm_qa_result_fail}") == 1
    assert real("${msm_qa_result_skip}") == 1
}
if _rc == 0 {
    display as result "PASS H3: reconciled result counts are published exactly"
    local ++pass_count
}
else {
    display as error "FAIL H3: valid result publication failed"
    local ++fail_count
    local failed_tests "`failed_tests' H3"
}

if `fail_count' > 0 {
    display as error "Failed tests:`failed_tests'"
}
do "`qa_dir'/_record_qa_result.do" test_qa_harness ///
    `test_count' `pass_count' `fail_count' 0
display as text "RESULT: test_qa_harness tests=`test_count' pass=`pass_count' fail=`fail_count' skip=0"
capture log close _all
if `fail_count' > 0 exit 1
