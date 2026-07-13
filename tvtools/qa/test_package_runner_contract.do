*! test_package_runner_contract.do
*! Meta-regressions for the pinned RESULT contract used by run_all.do.

clear all
set varabbrev off
version 16.0

capture log close _all
quietly log using "test_package_runner_contract.log", replace nomsg

do "`c(pwd)'/_tvtools_qa_common.do"
_tvtools_qa_bootstrap

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

capture program drop _write_result_fixture
program define _write_result_fixture
    args path line1 line2
    tempname fh
    capture file close `fh'
    file open `fh' using `"`path'"', write text replace
    file write `fh' `"`line1'"' _n
    if `"`line2'"' != "" file write `fh' `"`line2'"' _n
    file close `fh'
end

**# Valid contracts

local ++test_count
capture noisily {
    clear
    tempfile f1
    _write_result_fixture "`f1'" "RESULT: fixture tests=2 pass=2 fail=0"
    _tvtools_qa_validate_result, logfile("`f1'") suite(fixture) expected(2)
    assert r(valid) == 1
    assert r(tests) == 2 & r(pass) == 2 & r(fail) == 0 & r(skip) == 0
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' valid"
}

local ++test_count
capture noisily {
    clear
    tempfile f2
    _write_result_fixture "`f2'" "RESULT: fixture tests=2 pass=1 fail=0 skip=1"
    _tvtools_qa_validate_result, logfile("`f2'") suite(fixture) expected(2) allowskip
    assert r(valid) == 1
    assert r(skip) == 1
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' allowed_skip"
}

**# Rejected contracts

local ++test_count
capture noisily {
    clear
    tempfile f3
    _write_result_fixture "`f3'" "suite ended before its sentinel"
    _tvtools_qa_validate_result, logfile("`f3'") suite(fixture) expected(2)
    assert r(valid) == 0
    assert strpos("`r(reason)'", "expected one RESULT line") > 0
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' missing"
}

local ++test_count
capture noisily {
    clear
    tempfile f4
    _write_result_fixture "`f4'" "RESULT: fixture pass=2 fail=0"
    _tvtools_qa_validate_result, logfile("`f4'") suite(fixture) expected(2)
    assert r(valid) == 0
    assert "`r(reason)'" == "RESULT line is malformed"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' malformed"
}

* This is the C-12 counterexample: an injected mid-suite error used to shrink
* test_options from 87 to 41 checks while run_all still returned success.
local ++test_count
capture noisily {
    clear
    tempfile f5
    _write_result_fixture "`f5'" "RESULT: test_options tests=41 pass=41 fail=0"
    _tvtools_qa_validate_result, logfile("`f5'") suite(test_options) expected(87)
    assert r(valid) == 0
    assert strpos("`r(reason)'", "test-count mismatch") > 0
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' truncated"
}

local ++test_count
capture noisily {
    clear
    tempfile f6
    _write_result_fixture "`f6'" ///
        "RESULT: fixture tests=2 pass=2 fail=0" ///
        "RESULT: fixture tests=2 pass=2 fail=0"
    _tvtools_qa_validate_result, logfile("`f6'") suite(fixture) expected(2)
    assert r(valid) == 0
    assert strpos("`r(reason)'", "found 2") > 0
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' duplicate"
}

local ++test_count
capture noisily {
    clear
    tempfile f7
    _write_result_fixture "`f7'" "RESULT: fixture tests=3 pass=2 fail=0"
    _tvtools_qa_validate_result, logfile("`f7'") suite(fixture) expected(3)
    assert r(valid) == 0
    assert "`r(reason)'" == "tests != pass + fail + skip"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' arithmetic"
}

local ++test_count
capture noisily {
    clear
    tempfile f8
    _write_result_fixture "`f8'" "RESULT: fixture tests=2 pass=1 fail=1"
    _tvtools_qa_validate_result, logfile("`f8'") suite(fixture) expected(2)
    assert r(valid) == 0
    assert strpos("`r(reason)'", "reported 1 failed") > 0
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' oracle_failure"
}

local ++test_count
capture noisily {
    clear
    tempfile f9
    _write_result_fixture "`f9'" "RESULT: fixture tests=2 pass=1 fail=0 skip=1"
    _tvtools_qa_validate_result, logfile("`f9'") suite(fixture) expected(2)
    assert r(valid) == 0
    assert "`r(reason)'" == "suite reported disallowed skips"
    _tvtools_qa_validate_result, logfile("`f9'") suite(fixture) expected(2) ///
        allowskip requirezeroskip
    assert r(valid) == 0
    assert "`r(reason)'" == "full/release lane requires zero skips"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' skip_policy"
}

**# Bootstrap and cleanup contracts

local ++test_count
capture noisily {
    local run_before "$TVTOOLS_QA_RUN_DIR"
    local plus_before "$TVTOOLS_QA_PLUS"
    _tvtools_qa_bootstrap
    _tvtools_qa_bootstrap
    assert "$TVTOOLS_QA_BOOTSTRAP_COUNT" == "1"
    assert "$TVTOOLS_QA_RUN_DIR" == "`run_before'"
    assert "$TVTOOLS_QA_PLUS" == "`plus_before'"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' bootstrap_once"
}

local ++test_count
capture noisily {
    local run_before "$TVTOOLS_QA_RUN_DIR"
    local data_before "$TVTOOLS_QA_DATA"
    local plus_before "$TVTOOLS_QA_PLUS"
    local personal_before "$TVTOOLS_QA_PERSONAL"
    tempfile cleanup_base
    local cleanup_root "`cleanup_base'_tree"
    capture mkdir "`cleanup_root'"
    capture mkdir "`cleanup_root'/data"
    capture mkdir "`cleanup_root'/plus"
    capture mkdir "`cleanup_root'/plus/t"
    capture mkdir "`cleanup_root'/personal"
    tempname cleanup_fh
    file open `cleanup_fh' using "`cleanup_root'/plus/t/artifact.txt", ///
        write text replace
    file write `cleanup_fh' "artifact" _n
    file close `cleanup_fh'
    global TVTOOLS_QA_RUN_DIR "`cleanup_root'"
    global TVTOOLS_QA_DATA "`cleanup_root'/data"
    global TVTOOLS_QA_PLUS "`cleanup_root'/plus"
    global TVTOOLS_QA_PERSONAL "`cleanup_root'/personal"
    _tvtools_qa_cleanup
    global TVTOOLS_QA_RUN_DIR "`run_before'"
    global TVTOOLS_QA_DATA "`data_before'"
    global TVTOOLS_QA_PLUS "`plus_before'"
    global TVTOOLS_QA_PERSONAL "`personal_before'"
    capture mkdir "`cleanup_root'"
    assert _rc == 0
    capture rmdir "`cleanup_root'"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' recursive_cleanup"
}

**# Summary

display "RESULT: test_package_runner_contract tests=`test_count' pass=`pass_count' fail=`fail_count'"
capture log close _all
if `fail_count' > 0 {
    display as error "runner-contract failures:`failed_tests'"
    exit 1
}
