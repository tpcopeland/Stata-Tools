clear all
set varabbrev off
version 16.0

capture log close _all
capture file close swlog
file open swlog using "test_basic.log", write text replace
file close swlog
log using "test_basic.log", replace nomsg

do "_swimlane_qa_common.do"
_swimlane_qa_bootstrap

local test_count = 0
local pass_count = 0
local fail_count = 0

local ++test_count
capture noisily {
    _swimlane_make_wide
    swimlane, id(id) duration(duration) events(response progression) ///
        eventlabels("Response" "Progression") ongoing(ongoing) ///
        colorby(arm) name(sw_basic_wide, replace) nodraw
    assert r(N_subjects) == 4
    assert r(N_events) == 6
    assert r(N_ongoing) == 2
    assert "`r(mode)'" == "swimmer"
    assert "`r(shape)'" == "wide"
    graph describe sw_basic_wide
}
if _rc == 0 {
    display as result "  PASS: wide swimmer render"
    local ++pass_count
}
else {
    display as error "  FAIL: wide swimmer render (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    _swimlane_make_long_state
    swimlane, id(id) start(start) stop(stop) state(state) ///
        name(sw_basic_state, replace) nodraw
    assert r(N_subjects) == 3
    assert r(N_segments) == 4
    assert "`r(mode)'" == "state"
    assert "`r(shape)'" == "long"
    graph describe sw_basic_state
}
if _rc == 0 {
    display as result "  PASS: long state render"
    local ++pass_count
}
else {
    display as error "  FAIL: long state render (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    _swimlane_make_stset
    swimlane, id(id) name(sw_basic_stset, replace) nodraw
    assert r(N_subjects) == 3
    assert r(N_events) == 1
    assert "`r(shape)'" == "stset"
    graph describe sw_basic_stset
}
if _rc == 0 {
    display as result "  PASS: stset render"
    local ++pass_count
}
else {
    display as error "  FAIL: stset render (error `=_rc')"
    local ++fail_count
}

display as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"
display "RESULT: test_basic tests=`test_count' pass=`pass_count' fail=`fail_count'"
log close _all
if `fail_count' > 0 exit 1
