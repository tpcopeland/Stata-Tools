* Deterministic hostile-input contract tests for codescan.
clear all
version 16.0
set seed 303002
set varabbrev off
capture log close _all
log using "test_codescan_hostile.log", text replace nomsg

local test_count = 0
local pass_count = 0
local fail_count = 0
local qa_dir "`c(pwd)'"
quietly do "`qa_dir'/_codescan_qa_common.do"
_codescan_qa_bootstrap

* A user variable matching the helper naming pattern cannot be overwritten.
local ++test_count
capture noisily {
    clear
    input str8 dx1 byte _codescan_tmp byte dm2 byte sentinel
    "E110" 41 51 1
    "Z00"  42 52 2
    end
    capture noisily codescan dx1, define(dm2 "E11")
    local call_rc = _rc
    assert `call_rc' == 110
    assert _codescan_tmp[1] == 41
    assert _codescan_tmp[2] == 42
    assert dm2[1] == 51
    assert dm2[2] == 52
    assert sentinel[1] == 1
}
if _rc == 0 local ++pass_count
else local ++fail_count

* Empty data and malformed definitions error without adding partial output.
local ++test_count
capture noisily {
    clear
    set obs 0
    generate str8 dx1 = ""
    capture noisily codescan dx1, define(dm2 "E11")
    local empty_rc = _rc
    assert `empty_rc' != 0
    assert _N == 0
    clear
    input str8 dx1 byte sentinel
    "E110" 9
    end
    capture noisily codescan dx1, define(dm2 "[")
    local regex_rc = _rc
    assert `regex_rc' != 0
    capture confirm variable dm2
    assert _rc != 0
    assert sentinel == 9
}
if _rc == 0 local ++pass_count
else local ++fail_count

* A repeated replacement is deterministic and preserves the source variables.
local ++test_count
capture noisily {
    clear
    input str8 dx1 str8 dx2 byte sentinel
    "E110" "Z00" 3
    "Z00"  "E119" 4
    end
    generate str8 before1 = dx1
    generate str8 before2 = dx2
    codescan dx1 dx2, define(dm2 "E11")
    assert dm2[1] == 1
    assert dm2[2] == 1
    codescan dx1 dx2, define(dm2 "E11") replace
    assert dm2[1] == 1
    assert dm2[2] == 1
    assert dx1 == before1
    assert dx2 == before2
    assert sentinel[1] == 3
    assert sentinel[2] == 4
}
if _rc == 0 local ++pass_count
else local ++fail_count

_codescan_qa_publish "test_codescan_hostile" `test_count' `pass_count' `fail_count'
display "RESULT: test_codescan_hostile tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 {
    capture log close _all
    exit 1
}
capture log close _all
