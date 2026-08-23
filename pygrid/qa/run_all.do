version 16.0
args mode extra

if "`extra'" != "" {
    display as error "run_all.do accepts one lane argument"
    exit 198
}
if "`mode'" == "" local mode "full"
if !inlist("`mode'", "quick", "core", "crossval", "full", "benchmark") {
    display as error "lane must be quick, core, crossval, full, or benchmark"
    exit 198
}

local quick "test_pygrid.do test_pyattach.do test_package_contracts.do test_doc_examples.do test_pygrid_errors.do test_pygrid_hostile.do"
local core "`quick' validation_pygrid_known_truth.do validation_pyattach_known_truth.do validation_pyattach_reference.do validation_mogad_section4d.do"
local crossval "crossval_pygrid.do"
local full "`core' `crossval'"
local benchmark "benchmark_pygrid.do"
local suites "``mode''"

local suite_count = 0
local pass_count = 0
local fail_count = 0

foreach suite of local suites {
    local ++suite_count
    capture noisily do "`suite'"
    local suite_rc = _rc
    if `suite_rc' == 0 local ++pass_count
    else {
        local ++fail_count
        display as error "suite failed: `suite' (rc=`suite_rc')"
    }
}

display "RESULT: run_all_`mode' tests=`suite_count' pass=`pass_count' fail=`fail_count' skip=0"
if `fail_count' > 0 exit 1
