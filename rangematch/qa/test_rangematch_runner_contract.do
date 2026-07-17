*! test_rangematch_runner_contract.do
*! RM-I20 regression: run_all must reject missing, nested, wrong-name,
*! duplicate, and internally inconsistent suite sentinels.

clear all
version 16.1

quietly do "`c(pwd)'/_rangematch_qa_common.do"
_rm_qa_bootstrap

local test_count = 0
local pass_count = 0
local fail_count = 0

capture program drop _rm_runner_fixture
program define _rm_runner_fixture
    version 16.1
    args path mode
    tempname fh
    file open `fh' using "`path'", write text
    file write `fh' "Running test_alpha.do" _n
    if "`mode'" == "valid" {
        file write `fh' "RESULT: test_alpha tests=2 pass=2 fail=0" _n
    }
    else if "`mode'" == "nested" {
        file write `fh' "RESULT: bench_rangematch scenarios=6 ok=6 error=0" _n
    }
    else if "`mode'" == "wrongname" {
        file write `fh' "RESULT: test_beta tests=2 pass=2 fail=0" _n
    }
    else if "`mode'" == "duplicate" {
        file write `fh' "RESULT: test_alpha tests=2 pass=2 fail=0" _n
        file write `fh' "RESULT: test_alpha tests=2 pass=2 fail=0" _n
    }
    else if "`mode'" == "badcounts" {
        file write `fh' "RESULT: test_alpha tests=2 pass=1 fail=0" _n
    }
    else if "`mode'" == "reportedfail" {
        file write `fh' "RESULT: test_alpha tests=2 pass=1 fail=1" _n
    }
    file close `fh'
end

foreach mode in valid nested wrongname duplicate badcounts reportedfail {
    local ++test_count
    tempfile fixture
    capture noisily {
        _rm_runner_fixture "`fixture'" "`mode'"
        _rm_qa_scan_sentinels using "`fixture'"
        local issues `"`r(issues)'"'
        if "`mode'" == "valid" assert `"`issues'"' == ""
        else assert `"`issues'"' == "test_alpha.do"
    }
    if _rc {
        local ++fail_count
        display as error "FAIL: runner sentinel fixture `mode'"
    }
    else {
        local ++pass_count
        display as result "PASS: runner sentinel fixture `mode'"
    }
}

display "RESULT: test_rangematch_runner_contract tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 exit 9
