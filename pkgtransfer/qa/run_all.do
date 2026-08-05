/*
    File:    run_all.do
    Purpose: Run the complete pkgtransfer QA lane
    Author:  Timothy P Copeland, Karolinska Institutet
    Date:    2026-08-05
*/

version 16.0
clear all
set more off
capture log close _all

local qa_dir "`c(pwd)'"
global RUN_TEST_QUIET 1
global RUN_TEST_MACHINE 1
global RUN_TEST_NUMBER 0

capture noisily do "`qa_dir'/test_pkgtransfer.do"
local functional_rc = _rc

capture noisily do "`qa_dir'/validation_pkgtransfer.do"
local validation_rc = _rc

macro drop RUN_TEST_QUIET RUN_TEST_MACHINE RUN_TEST_NUMBER
capture log close _all

display _n as text "pkgtransfer full QA lane"
display as text "  functional rc = `functional_rc'"
display as text "  validation rc = `validation_rc'"

if `functional_rc' != 0 | `validation_rc' != 0 {
    display as error "RESULT: FAIL"
    exit 9
}

display as result "RESULT: PASS"
