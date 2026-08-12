clear all
set varabbrev off
version 16.0

capture log close _all
capture file close swlog
file open swlog using "test_return_values.log", write text replace
file close swlog
log using "test_return_values.log", replace nomsg

do "_swimlane_qa_common.do"
_swimlane_qa_bootstrap

local test_count = 0
local pass_count = 0
local fail_count = 0

local ++test_count
capture noisily {
    _swimlane_make_wide
    swimlane, id(id) duration(duration) events(response progression) ///
        ongoing(ongoing) name(sw_returns, replace) nodraw
    assert "`r(mode)'" == "swimmer"
    assert "`r(shape)'" == "wide"
    assert "`r(graphname)'" == "sw_returns"
    assert r(N_subjects) == 4
    assert r(N_subjects_total) == 4
    assert r(N_segments) == 4
    assert r(N_events) == 6
    assert r(N_ongoing) == 2
    assert r(min_duration) == 30
    assert r(max_duration) == 200
    assert r(median_duration) == 100
    assert r(maxids) == 60
    assert r(N_censored) == 0
    assert r(N_groups) == 0
    assert r(N_series) == 2
    assert r(N_events_outside) == 0
    assert r(N_overlaps) == 0
    assert r(N_gaps) == 0
    assert r(N_intervals) == 0
    assert r(N_panels) == 1
    assert r(N_blocks) == 0
    assert r(truncated) == 0
    assert "`r(timefmt)'" == ""
    assert "`r(blockby)'" == ""
    assert `"`r(cmdline)'"' != ""
    assert substr(`"`r(cmdline)'"', 1, 6) == "twoway"
    matrix S = r(states)
    assert colsof(S) == 2
}
if _rc == 0 {
    display as result "  PASS: return surface"
    local ++pass_count
}
else {
    display as error "  FAIL: return surface (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    _swimlane_make_stset
    swimlane, id(id) censor name(sw_returns_cen, replace) nodraw
    assert "`r(mode)'" == "swimmer"
    assert "`r(shape)'" == "stset"
    assert r(N_censored) == 2
    assert r(N_events) == 1
    assert r(N_groups) == 0
    assert r(N_series) == 1
    assert r(N_events_outside) == 0
    assert r(N_overlaps) == 0
    assert r(N_gaps) == 0
    assert r(N_intervals) == 0
    assert r(truncated) == 0
    assert `"`r(cmdline)'"' != ""
}
if _rc == 0 {
    display as result "  PASS: stset censor return surface"
    local ++pass_count
}
else {
    display as error "  FAIL: stset censor return surface (error `=_rc')"
    local ++fail_count
}

display as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"
display "RESULT: test_return_values tests=`test_count' pass=`pass_count' fail=`fail_count'"
log close _all
if `fail_count' > 0 exit 1
