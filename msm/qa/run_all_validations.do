* run_all_validations.do
*
* Master runner for msm package QA suite.
* Runs test_msm.do (functional tests) and validation_msm.do (validation suites).
*
* Usage:
*   stata-mp -b do run_all_validations.do              // runs all
*   stata-mp -b do run_all_validations.do tests         // runs tests only
*   stata-mp -b do run_all_validations.do validations   // runs validations only

version 16.0
set more off
set varabbrev off

local qa_dir "/home/tpcopeland/Stata-Tools/msm/qa"

capture log close _all
log using "`qa_dir'/run_all_validations.log", replace name(master)

timer clear
timer on 99

* Determine what to run
local run_list "`0'"

local do_tests = 0
local do_validations = 0

if "`run_list'" == "" {
    local do_tests = 1
    local do_validations = 1
}
else if "`run_list'" == "tests" {
    local do_tests = 1
}
else if "`run_list'" == "validations" {
    local do_validations = 1
}
else {
    local do_tests = 1
    local do_validations = 1
}

* Run functional tests
if `do_tests' {
    timer on 1
    do "`qa_dir'/test_msm.do"
    timer off 1
}

* Run validation suites
if `do_validations' {
    timer on 2
    do "`qa_dir'/validation_msm.do"
    timer off 2
}

timer off 99
quietly timer list

log close master
