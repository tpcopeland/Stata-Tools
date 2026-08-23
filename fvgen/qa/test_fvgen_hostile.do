* Deterministic hostile-input tests for fvgen. Seed: 303101.
clear all
version 16.0
set seed 303101
set varabbrev off
capture log close _all
log using "test_fvgen_hostile.log", replace text nomsg
do _fvgen_qa_common.do
_fvgen_qa_bootstrap
local test_count = 0
local pass_count = 0
local fail_count = 0
local ++test_count
capture noisily {
    clear
    input byte group double x byte sentinel
    1 1 31
    2 2 32
    end
    generate byte fv_group_1 = 77
    capture noisily fvgen i.group, prefix(fv_) alllevels
    local call_rc = _rc
    assert `call_rc' != 0
    assert fv_group_1 == 77
    assert sentinel[1] == 31
}
if _rc == 0 local ++pass_count
else local ++fail_count
local ++test_count
capture noisily {
    clear
    set obs 0
    generate byte group = .
    capture noisily fvgen i.group
    assert _rc != 0
    assert _N == 0
}
if _rc == 0 local ++pass_count
else local ++fail_count
display "RESULT: test_fvgen_hostile tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 {
    capture log close _all
    exit 1
}
capture log close _all
