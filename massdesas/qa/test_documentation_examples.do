* test_documentation_examples.do
*
* Runnable README workflow checks for massdesas v1.0.1
*
* Author: Timothy P Copeland, Karolinska Institutet
* Date: 2026-08-05

clear all
version 14.0

local qa_dir `"`c(pwd)'"'
do "`qa_dir'/_massdesas_qa_common.do"
capture noisily _massdesas_qa_bootstrap
local bootstrap_rc = _rc
if `bootstrap_rc' {
    display as error "QA bootstrap failed (rc=`bootstrap_rc')"
    display as text "RESULT: test_documentation_examples tests=0 pass=0 fail=1 skip=0"
    exit `bootstrap_rc'
}

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""
local original_cwd `"`c(pwd)'"'

tempfile qa_token
local explicit_dir "`qa_token'_explicit"
local current_dir "`qa_token'_current"
local erase_dir "`qa_token'_erase"
capture mkdir "`explicit_dir'"
capture mkdir "`current_dir'"
capture mkdir "`erase_dir'"

shell Rscript -e "suppressWarnings(library(haven)); write_sas(data.frame(ID=1:3, MixedCase=c(2,4,6)), '`explicit_dir'/example.sas7bdat')" 2>/dev/null
shell Rscript -e "suppressWarnings(library(haven)); write_sas(data.frame(X=c(10L,20L)), '`current_dir'/current.sas7bdat')" 2>/dev/null
shell Rscript -e "suppressWarnings(library(haven)); write_sas(data.frame(X=c(5L,6L)), '`erase_dir'/erase_me.sas7bdat')" 2>/dev/null

capture confirm file "`explicit_dir'/example.sas7bdat"
local fixture_rc = _rc
capture confirm file "`current_dir'/current.sas7bdat"
if _rc local fixture_rc = _rc
capture confirm file "`erase_dir'/erase_me.sas7bdat"
if _rc local fixture_rc = _rc
if `fixture_rc' {
    capture cd `"`original_cwd'"'
    capture shell rm -rf "`explicit_dir'" "`current_dir'" "`erase_dir'"
    _massdesas_qa_cleanup
    display as text "RESULT: test_documentation_examples tests=0 pass=0 fail=1 skip=0"
    exit 499
}

**# Explicit directory and lower option

local ++test_count
capture noisily {
    massdesas, directory("`explicit_dir'") lower
    assert r(n_converted) == 1
    assert r(n_failed) == 0
    assert `"`r(directory)'"' == `"`explicit_dir'"'
    use "`explicit_dir'/example.dta", clear
    confirm variable id mixedcase
    assert _N == 3
}
if _rc == 0 {
    display as result "PASS: explicit directory and lower"
    local ++pass_count
}
else {
    display as error "FAIL: explicit directory and lower (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 1"
}

**# Current-directory default

local ++test_count
capture noisily {
    cd "`current_dir'"
    massdesas
    assert r(n_converted) == 1
    assert r(n_failed) == 0
    confirm file "`current_dir'/current.dta"
}
local current_rc = _rc
capture cd `"`original_cwd'"'
if `current_rc' == 0 {
    display as result "PASS: current-directory default"
    local ++pass_count
}
else {
    display as error "FAIL: current-directory default (rc=`current_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 2"
}

**# Erase only after successful conversion

local ++test_count
capture noisily {
    massdesas, directory("`erase_dir'") erase
    assert r(n_converted) == 1
    assert r(n_failed) == 0
    confirm file "`erase_dir'/erase_me.dta"
    capture confirm file "`erase_dir'/erase_me.sas7bdat"
    assert _rc != 0
}
if _rc == 0 {
    display as result "PASS: erase after conversion"
    local ++pass_count
}
else {
    display as error "FAIL: erase after conversion (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3"
}

**# Cleanup and summary

capture cd `"`original_cwd'"'
capture shell rm -rf "`explicit_dir'" "`current_dir'" "`erase_dir'"
_massdesas_qa_cleanup

display as text "Tests: `test_count'"
display as result "Passed: `pass_count'"
display as text "Failed: `fail_count'"
if `fail_count' > 0 display as error "Failed tests:`failed_tests'"

if `fail_count' > 0 {
    display as text "RESULT: test_documentation_examples tests=`test_count' pass=`pass_count' fail=`fail_count' skip=0"
    exit 1
}
display as text "RESULT: test_documentation_examples tests=`test_count' pass=`pass_count' fail=`fail_count' skip=0"
