*! run_all.do - cstat_surv curated QA runner
version 16.0
clear all
set processors 1
set varabbrev off

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
local files "test_cstat_surv.do test_cstat_surv_errors.do test_cstat_surv_hostile.do test_cstat_surv_documentation_examples.do validation_cstat_surv.do crossval_cstat_surv.do crossval_cstat_surv_sksurv.do"
local pass = 0
local fail = 0
foreach file of local files {
    capture noisily do "`qa_dir'/`file'"
    if _rc local ++fail
    else local ++pass
}
local total = `pass' + `fail'
display "RESULT: run_all_cstat_surv tests=`total' pass=`pass' fail=`fail'"
if `fail' exit 9
