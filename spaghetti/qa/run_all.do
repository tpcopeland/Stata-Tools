version 16.0
clear all

args mode extra
if "`mode'" == "" local mode "full"
if "`extra'" != "" | !inlist("`mode'", "quick", "core", "full") {
    display as error "mode must be quick, core, or full"
    exit 198
}

local qa_dir "`c(pwd)'"
capture ado uninstall spaghetti
local quick "test_spaghetti test_spaghetti_documentation_examples test_spaghetti_errors test_spaghetti_hostile"
if "`mode'" == "quick" local suites "`quick'"
else local suites "`quick' validation_spaghetti"
local tests = 0
local pass = 0
local fail = 0
foreach suite of local suites {
    local ++tests
    capture noisily do "`qa_dir'/`suite'.do"
    if _rc == 0 local ++pass
    else local ++fail
}
display "RESULT: run_all tests=`tests' pass=`pass' fail=`fail' skip=0"
if `fail' > 0 exit 1
