* Error contracts for massdesas public-option and filesystem failures.

version 14.0
clear all
set varabbrev off

local qa_dir "`c(pwd)'"
do "`qa_dir'/_massdesas_qa_common.do"
quietly _massdesas_qa_bootstrap

local test_count = 0
local pass_count = 0
local fail_count = 0

**# Early parser failure preserves data, order, and session setting
local ++test_count
capture noisily {
    clear
    input double protected
    5
    .a
    end
    gen long order_before = _n
    set varabbrev on
    capture noisily massdesas, unsupported
    local call_rc = _rc
    assert `call_rc' == 198
    assert protected[1] == 5
    assert protected[2] == .a
    assert order_before == _n
    assert "`c(varabbrev)'" == "on"
}
if _rc == 0 local ++pass_count
else local ++fail_count

**# Missing directory fails before changing caller data or working directory
local ++test_count
capture noisily {
    clear
    input double protected
    8
    .a
    end
    gen long order_before = _n
    local pwd_before `"`c(pwd)'"'
    tempfile absent
    set varabbrev on
    capture noisily massdesas, directory("`absent'_absent") erase lower
    local call_rc = _rc
    assert `call_rc' == 601
    assert protected[1] == 8
    assert protected[2] == .a
    assert order_before == _n
    assert `"`c(pwd)'"' == `"`pwd_before'"'
    assert "`c(varabbrev)'" == "on"
}
if _rc == 0 local ++pass_count
else local ++fail_count

**# Empty directory rejects the late file-discovery failure and restores state
local ++test_count
capture noisily {
    clear
    input double protected
    13
    .a
    end
    gen long order_before = _n
    tempfile anchor
    local empty_dir "`anchor'_empty"
    capture mkdir "`empty_dir'"
    local pwd_before `"`c(pwd)'"'
    set varabbrev on
    capture noisily massdesas, directory("`empty_dir'")
    local call_rc = _rc
    assert `call_rc' == 601
    assert protected[1] == 13
    assert protected[2] == .a
    assert order_before == _n
    assert `"`c(pwd)'"' == `"`pwd_before'"'
    assert "`c(varabbrev)'" == "on"
}
if _rc == 0 local ++pass_count
else local ++fail_count

display "RESULT: test_massdesas_errors tests=`test_count' pass=`pass_count' fail=`fail_count' skip=0"
_massdesas_qa_cleanup
if `fail_count' > 0 exit 1
