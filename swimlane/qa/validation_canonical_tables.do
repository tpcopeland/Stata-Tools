clear all
set varabbrev off
version 16.0

capture log close _all
capture file close swlog
file open swlog using "validation_canonical_tables.log", write text replace
file close swlog
log using "validation_canonical_tables.log", replace nomsg

do "_swimlane_qa_common.do"
_swimlane_qa_bootstrap

local test_count = 0
local pass_count = 0
local fail_count = 0

local ++test_count
capture noisily {
    tempfile widecsv
    local widecsv "`widecsv'.csv"
    _swimlane_make_wide
    swimlane, id(id) duration(duration) events(response progression) ///
        eventlabels("Response" "Progression") ongoing(ongoing) ///
        origin(origin) savedata("`widecsv'") name(sw_val_wide, replace) nodraw
    import delimited using "`widecsv'", clear varnames(1)
    assert _N == 10
    count if rowtype == "bar"
    assert r(N) == 4
    count if rowtype == "event"
    assert r(N) == 6
    assert lane == 4 if id == 4 & rowtype == "bar"
    assert lane == 1 if id == 3 & rowtype == "bar"
    assert xpoint == 40 if id == 1 & series == "Response"
    assert xpoint == 30 if id == 3 & series == "Progression"
    assert ongoing == 1 if id == 1 & rowtype == "bar"
}
if _rc == 0 {
    display as result "  PASS: wide canonical table"
    local ++pass_count
}
else {
    display as error "  FAIL: wide canonical table (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    tempfile abscsv
    local abscsv "`abscsv'.csv"
    _swimlane_make_wide
    swimlane, id(id) duration(duration) events(response) origin(origin) ///
        eventsabsolute savedata("`abscsv'") name(sw_val_abs, replace) nodraw
    import delimited using "`abscsv'", clear varnames(1)
    assert xpoint == 30 if id == 1 & rowtype == "event"
}
if _rc == 0 {
    display as result "  PASS: eventsabsolute canonical table"
    local ++pass_count
}
else {
    display as error "  FAIL: eventsabsolute canonical table (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    tempfile statecsv
    local statecsv "`statecsv'.csv"
    _swimlane_make_long_state
    swimlane, id(id) start(start) stop(stop) state(state) ///
        savedata("`statecsv'") name(sw_val_state, replace) nodraw
    import delimited using "`statecsv'", clear varnames(1)
    assert _N == 4
    assert rowtype == "bar"
    assert series == "A" if id == 1 & seg == 1
    assert series == "B" if id == 1 & seg == 2
    assert duration == stop - start
}
if _rc == 0 {
    display as result "  PASS: state canonical table"
    local ++pass_count
}
else {
    display as error "  FAIL: state canonical table (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    tempfile maxcsv
    local maxcsv "`maxcsv'.csv"
    _swimlane_make_wide
    swimlane, id(id) duration(duration) maxids(2) ///
        savedata("`maxcsv'") name(sw_val_max, replace) nodraw
    assert r(N_subjects) == 2
    assert r(N_subjects_total) == 4
    assert r(truncated) == 1
    import delimited using "`maxcsv'", clear varnames(1)
    assert _N == 2
    assert inlist(id, 1, 4)
}
if _rc == 0 {
    display as result "  PASS: maxids canonical table"
    local ++pass_count
}
else {
    display as error "  FAIL: maxids canonical table (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    _swimlane_make_intervals
    swimlane, id(id) start(start) stop(stop) ///
        intervalstart(layer_start) intervalstop(layer_stop) ///
        intervaltype(layer_type) frame(sw_val_intervals, replace) ///
        name(sw_val_intervals_graph, replace) nodraw
    local _interval_cmd `"`r(cmdline)'"'
    assert r(N_subjects) == 2
    assert r(N_segments) == 2
    assert r(N_intervals) == 2
    assert r(N_series) == 2
    assert strpos(`"`_interval_cmd'"', "pcspike") > 0
    frame sw_val_intervals: quietly count if rowtype == "interval"
    assert r(N) == 2
    frame sw_val_intervals: quietly count if id == 1 & ///
        rowtype == "interval" & start == 2 & stop == 5 & ///
        duration == 3 & series == "Response"
    assert r(N) == 1
    frame sw_val_intervals: quietly count if id == 2 & ///
        rowtype == "interval" & start == 1 & stop == 7 & ///
        duration == 6 & series == "Stable"
    assert r(N) == 1
    graph describe sw_val_intervals_graph
    graph drop sw_val_intervals_graph
    frame drop sw_val_intervals
}
if _rc == 0 {
    display as result "  PASS: exact interval-layer canonical rows and plot layer"
    local ++pass_count
}
else {
    display as error "  FAIL: interval-layer canonical table (error `=_rc')"
    capture graph drop sw_val_intervals_graph
    capture frame drop sw_val_intervals
    local ++fail_count
}

local ++test_count
capture noisily {
    _swimlane_make_geometry
    swimlane, id(id) start(start) stop(stop) state(state) ///
        intervalcheck(off) nograph frame(sw_val_geometry, replace)
    assert r(N_overlaps) == 2
    assert r(N_gaps) == 1
    frame sw_val_geometry: quietly count if rowtype == "bar" & ///
        ((start == 0 & stop == 10) | (start == 2 & stop == 3) | ///
        (start == 4 & stop == 5) | (start == 12 & stop == 13))
    assert r(N) == 4
    _swimlane_make_geometry
    swimlane, id(id) start(start) stop(stop) state(state) nograph
    assert r(N_overlaps) == 2
    assert r(N_gaps) == 1
    _swimlane_make_geometry
    capture noisily swimlane, id(id) start(start) stop(stop) state(state) ///
        intervalcheck(error) nograph
    assert _rc == 459
    frame drop sw_val_geometry
}
if _rc == 0 {
    display as result ///
        "  PASS: geometry audit counts nested overlaps/gaps without repair"
    local ++pass_count
}
else {
    display as error "  FAIL: geometry audit (error `=_rc')"
    capture frame drop sw_val_geometry
    local ++fail_count
}

local ++test_count
capture noisily {
    clear
    input id duration event_before event_after
    1 10 -1 11
    2  8  .  4
    end
    swimlane, id(id) duration(duration) ///
        events(event_before event_after) eventsabsolute ///
        eventlabels("Before" "After") nograph ///
        frame(sw_val_outspan, replace)
    assert r(N_events) == 3
    assert r(N_events_outside) == 2
    assert r(N_series) == 2
    frame sw_val_outspan: quietly count if id == 1 & ///
        rowtype == "event" & inlist(xpoint, -1, 11)
    assert r(N) == 2
    frame sw_val_outspan: quietly count if id == 2 & ///
        rowtype == "event" & xpoint == 4
    assert r(N) == 1
    frame drop sw_val_outspan
}
if _rc == 0 {
    display as result "  PASS: out-of-span events are retained and counted"
    local ++pass_count
}
else {
    display as error "  FAIL: out-of-span event audit (error `=_rc')"
    capture frame drop sw_val_outspan
    local ++fail_count
}

display as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"
display "RESULT: validation_canonical_tables tests=`test_count' pass=`pass_count' fail=`fail_count'"
log close _all
if `fail_count' > 0 exit 1
