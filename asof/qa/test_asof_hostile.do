* Deterministic hostile-input contract tests for asof.
version 16.0
set seed 303001
set varabbrev off

capture log close _all
log using "test_asof_hostile.log", replace text nomsg
global ASOF_QA_STATUS "fail"
do "_asof_qa_common.do"
quietly _asof_qa_bootstrap

local test_count = 0
local pass_count = 0
local fail_count = 0
tempfile events
clear
input long pid double event_date score
1 90 9
1 110 11
end
generate double abcdefghijklmnopqrstuvwxyzabcde = score
format event_date %td
save `events'

* A default generated name over 32 characters must error before touching data.
local ++test_count
capture noisily {
    clear
    set obs 1
    generate long pid = 1
    generate double anchor = 100
    format anchor %td
    generate byte sentinel = 73
    capture noisily asof abcdefghijklmnopqrstuvwxyzabcde using `events', ///
        id(pid) date(event_date) anchor(anchor) direction(both) select(nearest)
    local call_rc = _rc
    assert `call_rc' == 198
    assert sentinel == 73
    assert _N == 1
}
if _rc == 0 local ++pass_count
else local ++fail_count

* Structural output collisions and an empty restriction must error cleanly.
local ++test_count
capture noisily {
    clear
    input long pid double anchor byte sentinel
    1 100 74
    end
    format anchor %td
    capture noisily asof score using `events', id(pid) date(event_date) anchor(anchor) ///
        direction(both) select(nearest) generate(anchor)
    local collision_rc = _rc
    assert `collision_rc' == 198
    assert sentinel == 74
    capture noisily asof score if pid == 99 using `events', id(pid) date(event_date) ///
        anchor(anchor) direction(both) select(nearest)
    local empty_rc = _rc
    assert `empty_rc' == 2000
    assert sentinel == 74
}
if _rc == 0 local ++pass_count
else local ++fail_count

* Repeated calls with an unsorted master select the independent nearest event.
local ++test_count
capture noisily {
    clear
    input long pid double anchor byte sentinel byte expected
    1 109 75 11
    1 91  76 9
    end
    format anchor %td
    asof score using `events', id(pid) date(event_date) anchor(anchor) ///
        direction(both) select(nearest) generate(chosen)
    assert chosen[1] == expected[1]
    assert chosen[2] == expected[2]
    assert sentinel[1] == 75
    assert sentinel[2] == 76
    drop chosen
    asof score using `events', id(pid) date(event_date) anchor(anchor) ///
        direction(both) select(nearest) generate(chosen)
    assert chosen[1] == expected[1]
    assert chosen[2] == expected[2]
}
if _rc == 0 local ++pass_count
else local ++fail_count

display "RESULT: test_asof_hostile tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 {
    capture log close _all
    exit 1
}
global ASOF_QA_STATUS "pass"
capture log close _all
