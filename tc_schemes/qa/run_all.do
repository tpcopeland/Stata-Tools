* Curated QA runner for tc_schemes.

version 16.0
clear all

args mode extra
if "`mode'" == "" local mode "full"
if "`extra'" != "" | !inlist("`mode'", "quick", "core", "full") {
    display as error "mode must be quick, core, or full"
    exit 198
}

local qa_dir "`c(pwd)'"
capture ado uninstall tc_schemes
local quick_suites "test_tc_schemes test_tc_schemes_errors test_tc_schemes_documentation_examples test_tc_schemes_hostile"
local core_suites "`quick_suites' validation_tc_schemes"
if "`mode'" == "quick" local suites "`quick_suites'"
else local suites "`core_suites'"

local tests = 0
local pass = 0
local fail = 0
foreach suite of local suites {
    local ++tests
    capture noisily do "`qa_dir'/`suite'.do"
    local suite_rc = _rc
    if `suite_rc' == 0 local ++pass
    else local ++fail
}

display "RESULT: run_all tests=`tests' pass=`pass' fail=`fail' skip=0"
if `fail' > 0 exit 1
