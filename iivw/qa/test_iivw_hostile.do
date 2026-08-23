* Deterministic hostile-input contracts for iivw. Seed: 303104.
clear all
version 16.0
set seed 303104
set varabbrev off
capture log close _all
log using "test_iivw_hostile.log", replace text nomsg
local pkg_dir = subinstr("`c(pwd)'", "/qa", "", 1)
adopath ++ "`pkg_dir'"
local test_count = 0
local pass_count = 0
local fail_count = 0
local ++test_count
capture noisily {
    clear
    input long id double time byte sentinel
    1 1 61
    end
    capture noisily iivw_weight, id(id) time(time) visit_cov(not_a_variable)
    assert _rc != 0
    assert sentinel == 61
}
if _rc == 0 local ++pass_count
else local ++fail_count
local ++test_count
capture noisily {
    clear
    set obs 0
    generate long id = .
    generate double time = .
    generate byte y = .
    capture noisily iivw_exogtest y, id(id) time(time)
    assert _rc != 0
    assert _N == 0
}
if _rc == 0 local ++pass_count
else local ++fail_count
display "RESULT: test_iivw_hostile tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 {
    capture log close _all
    exit 1
}
capture log close _all
