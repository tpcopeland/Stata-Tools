/*
    File:    run_all.do
    Purpose: Run the quick, core, or full pkgtransfer QA lane
    Author:  Timothy P Copeland, Karolinska Institutet
    Date:    2026-08-11
*/

version 16.0
clear all
set more off
capture log close _all

args mode extra
local mode = lower(trim("`mode'"))
if "`mode'" == "" local mode "full"

if "`extra'" != "" | !inlist("`mode'", "quick", "core", "full") {
    display as error "Usage: do run_all.do [quick|core|full]"
    display as error ///
        "RESULT: run_all tests=1 pass=0 fail=1 skip=0"
    exit 198
}

local qa_dir "`c(pwd)'"
quietly ado dir
capture ado uninstall pkgtransfer
global RUN_TEST_QUIET 1
global RUN_TEST_MACHINE 0
global RUN_TEST_NUMBER 0

local suite_count 0
local suite_pass 0
local suite_fail 0

capture noisily do "`qa_dir'/test_pkgtransfer.do"
local functional_rc = _rc
local ++suite_count
if `functional_rc' == 0 local ++suite_pass
else local ++suite_fail

capture noisily do "`qa_dir'/test_pkgtransfer_v104.do"
local regression_rc = _rc
local ++suite_count
if `regression_rc' == 0 local ++suite_pass
else local ++suite_fail

capture noisily do "`qa_dir'/test_pkgtransfer_installed.do"
local installed_rc = _rc
local ++suite_count
if `installed_rc' == 0 local ++suite_pass
else local ++suite_fail

local validation_rc .
if inlist("`mode'", "core", "full") {
    capture noisily do "`qa_dir'/validation_pkgtransfer.do"
    local validation_rc = _rc
    local ++suite_count
    if `validation_rc' == 0 local ++suite_pass
    else local ++suite_fail
}

macro drop RUN_TEST_QUIET RUN_TEST_MACHINE RUN_TEST_NUMBER
capture log close _all

display _n as text "pkgtransfer `mode' QA lane"
display as text "  functional rc = `functional_rc'"
display as text "  regression rc = `regression_rc'"
display as text "  installed rc = `installed_rc'"
if inlist("`mode'", "core", "full") {
    display as text "  validation rc = `validation_rc'"
}

if `suite_fail' > 0 {
    display as error ///
        "RESULT: run_all tests=`suite_count' pass=`suite_pass' fail=`suite_fail' skip=0"
    exit 9
}

display as result ///
    "RESULT: run_all tests=`suite_count' pass=`suite_pass' fail=0 skip=0"
