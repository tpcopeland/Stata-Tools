* run_all.do
*
* Curated full QA runner for massdesas
*
* Author: Timothy P Copeland, Karolinska Institutet
* Date: 2026-08-05

version 14.0
clear all

args mode
if "`mode'" == "" local mode "full"
if "`mode'" != "full" {
    display as error "mode must be full"
    exit 198
}

local qa_dir `"`c(pwd)'"'
local suites "test_massdesas.do validation_massdesas.do test_documentation_examples.do"
local suite_count = 0
local pass_count = 0
local fail_count = 0
local failed_suites ""

**# Full lane

foreach suite of local suites {
    local ++suite_count
    capture noisily do "`qa_dir'/`suite'"
    local suite_rc = _rc
    if `suite_rc' == 0 {
        display as result "PASS: `suite'"
        local ++pass_count
    }
    else {
        display as error "FAIL: `suite' (rc=`suite_rc')"
        local ++fail_count
        local failed_suites "`failed_suites' `suite'"
    }
}

**# Summary

display as text "Suites: `suite_count'"
display as result "Passed: `pass_count'"
display as text "Failed: `fail_count'"
if `fail_count' > 0 display as error "Failed suites:`failed_suites'"
display as text "RESULT: run_all tests=`suite_count' pass=`pass_count' fail=`fail_count' skip=0"

if `fail_count' > 0 exit 1
