*! run_all.do — curated QA runner for asof
*! Usage: stata-mp -b do run_all.do [quick|core|crossval|full|benchmark]

version 16.0
set varabbrev off

args mode extra
local mode = lower(strtrim("`mode'"))
if "`mode'" == "" local mode "full"
if "`extra'" != "" {
    display as error "run_all.do accepts at most one lane"
    exit 198
}
if !inlist("`mode'", "quick", "core", "crossval", "full", "benchmark") {
    display as error "unknown lane `mode'; use quick, core, crossval, full, or benchmark"
    exit 198
}

do "_asof_qa_common.do"
quietly _asof_qa_bootstrap

local quick_suites test_asof_syntax test_asof_selection test_asof_windows ///
    test_asof_ties test_asof_edge_cases test_asof_types test_asof_install ///
    test_asof_examples
local core_suites `quick_suites' validation_asof_known_truth ///
    validation_asof_mogad
local crossval_suites crossval_asof_pandas
local full_suites `core_suites' `crossval_suites'
local benchmark_suites benchmark_asof_scaling
local suites ``mode'_suites'

local qa_dir "`c(pwd)'"
local pass_count = 0
local fail_count = 0

foreach suite of local suites {
    global ASOF_QA_STATUS "missing"
    capture noisily do "`qa_dir'/`suite'.do"
    local suite_rc = _rc
    if `suite_rc' == 0 & "$ASOF_QA_STATUS" == "pass" {
        local ++pass_count
        display as result "PASSED: `suite'.do"
    }
    else {
        local ++fail_count
        display as error "FAILED: `suite'.do (rc=`suite_rc', status=$ASOF_QA_STATUS)"
    }
}

display "RESULT: run_all_`mode' tests=`=`pass_count'+`fail_count'' pass=`pass_count' fail=`fail_count' skip=0"
if `fail_count' > 0 exit 1
