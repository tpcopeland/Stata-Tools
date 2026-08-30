*! test_asof_errors.do - Error-path and recovery contracts for asof
*! Author: Timothy P Copeland, Karolinska Institutet
*! Requires: Stata 16.0+

clear all
set processors 1
set varabbrev off
version 16.0

capture log close _all
log using "test_asof_errors.log", replace text nomsg
global ASOF_QA_STATUS "fail"

do "_asof_qa_common.do"
quietly _asof_qa_bootstrap

local test_count = 0
local pass_count = 0
local fail_count = 0

* Shared using data for error-contract probes
tempfile events
clear
input long id double visit score
1 90 9
1 110 11
end
save `events'

* Incompatible prefix/suffix errors without altering master data
local ++test_count
capture noisily {
    clear
    input long id double anchor marker
    1 100 77
    end
    local before = marker[1]
    capture noisily asof score using `events', id(id) date(visit) anchor(anchor) ///
        direction(both) select(nearest) prefix(x_) suffix(_y)
    local call_rc = _rc
    assert `call_rc' == 198
    assert marker[1] == `before'
    asof score using `events', id(id) date(visit) anchor(anchor) ///
        direction(both) select(nearest) generate(chosen)
    assert chosen == 9
}
if _rc == 0 local ++pass_count
else local ++fail_count

* Invalid direction errors exactly and the nearest legal direction succeeds
local ++test_count
capture noisily {
    clear
    input long id double anchor marker
    1 100 88
    end
    local before = marker[1]
    capture noisily asof score using `events', id(id) date(visit) anchor(anchor) ///
        direction(sideways) select(nearest)
    local call_rc = _rc
    assert `call_rc' == 198
    assert marker[1] == `before'
    asof score using `events', id(id) date(visit) anchor(anchor) ///
        direction(onorbefore) select(nearest) generate(chosen)
    assert chosen == 9
}
if _rc == 0 local ++pass_count
else local ++fail_count

* No selected master observations errors and preserves the zero-row dataset
local ++test_count
capture noisily {
    clear
    set obs 0
    generate long id = .
    generate double anchor = .
    capture noisily asof score using `events', id(id) date(visit) anchor(anchor) ///
        direction(both) select(nearest)
    local call_rc = _rc
    assert `call_rc' == 2000
    assert _N == 0
}
if _rc == 0 local ++pass_count
else local ++fail_count

* Reversed window bounds error before matching and a legal window succeeds
local ++test_count
capture noisily {
    clear
    input long id double anchor marker
    1 100 99
    end
    local before = marker[1]
    capture noisily asof score using `events', id(id) date(visit) anchor(anchor) ///
        direction(both) select(nearest) window(10 -10)
    local call_rc = _rc
    assert `call_rc' == 198
    assert marker[1] == `before'
    asof score using `events', id(id) date(visit) anchor(anchor) ///
        direction(both) select(nearest) window(-10 10) generate(chosen)
    assert chosen == 9
}
if _rc == 0 local ++pass_count
else local ++fail_count

display "RESULT: test_asof_errors tests=`test_count' pass=`pass_count' fail=`fail_count' skip=0"
if `fail_count' > 0 {
    capture log close _all
    exit 1
}
global ASOF_QA_STATUS "pass"
capture log close _all
