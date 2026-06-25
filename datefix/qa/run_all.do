*! run_all.do — canonical QA runner for datefix
*! Usage: cd datefix/qa && stata-mp -b do run_all.do [quick|full]

version 16.0
set more off
set varabbrev off

args mode extra

local qa_dir "`c(pwd)'"
do "`qa_dir'/_datefix_qa_common.do"
quietly _datefix_qa_bootstrap
local pass = 0
local fail = 0

local mode = lower(trim("`mode'"))
if "`mode'" == "" local mode "full"

if "`extra'" != "" {
    display as error "run_all.do accepts at most one mode argument."
    exit 198
}

if !inlist("`mode'", "quick", "full") {
    display as error "Unknown QA mode: `mode'"
    display as error "Supported modes: quick, full"
    exit 198
}

* _datefix_qa_bootstrap owns isolated sysdir setup and local package install.
* Each suite also self-bootstraps, so its net install lands in the same sandbox.

* Fast functional lane: core conversion behavior plus the diagnose option.
local quick_suites test_datefix test_diagnose

* Default release gate: quick lane plus expanded functional coverage and
* known-answer validation.
local full_suites `quick_suites' test_datefix_expanded validation_datefix

local suite_list ``mode'_suites'

display as text "datefix QA mode: `mode'"
foreach f in `suite_list' {
    clear all
    set more off
    set varabbrev off
    capture noisily do "`qa_dir'/`f'.do"
    if _rc {
        local ++fail
        display as error "FAILED: `f'.do"
    }
    else {
        local ++pass
        display as result "PASSED: `f'.do"
    }
}

display _n as result "=== QA Summary (`mode'): `pass' passed, `fail' failed ==="
if `fail' > 0 exit 1
