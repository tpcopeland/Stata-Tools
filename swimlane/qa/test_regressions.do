clear all
set varabbrev off
version 16.0

capture log close _all
capture file close swlog
file open swlog using "test_regressions.log", write text replace
file close swlog
log using "test_regressions.log", replace nomsg

do "_swimlane_qa_common.do"
_swimlane_qa_bootstrap

local test_count = 0
local pass_count = 0
local fail_count = 0

**# String and role-name handling

local ++test_count
capture noisily {
    clear
    set obs 2
    gen strL sid = "B"
    replace sid = `"A "quoted" xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"' in 1
    gen double duration = 10 * _n
    swimlane, id(sid) duration(duration) frame(sw_reg_sid, replace) ///
        name(sw_reg_sid_graph, replace) nodraw
    assert r(N_subjects) == 2
    frame sw_reg_sid {
        assert label == id if rowtype == "bar"
    }
    graph describe sw_reg_sid_graph
    graph drop sw_reg_sid_graph
    frame drop sw_reg_sid
}
if _rc == 0 {
    display as result "  PASS: string identifiers survive sampling and canonicalization"
    local ++pass_count
}
else {
    display as error "  FAIL: string identifiers survive sampling and canonicalization (error `=_rc')"
    capture graph drop sw_reg_sid_graph
    capture frame drop sw_reg_sid
    local ++fail_count
}

local ++test_count
capture noisily {
    clear
    input id start stop str120 series
    1 0 1 `"Induct "quoted" xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"'
    1 1 2 "Maintain"
    2 0 2 `"Induct "quoted" xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"'
    end
    swimlane, id(id) start(start) stop(stop) state(series) ///
        frame(sw_reg_series, replace) name(sw_reg_series_graph, replace) nodraw
    assert r(N_segments) == 3
    frame sw_reg_series {
        quietly count if series == `"Induct "quoted" xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"'
        assert r(N) == 2
        quietly count if series == "Maintain"
        assert r(N) == 1
    }
    graph describe sw_reg_series_graph
    graph drop sw_reg_series_graph
    frame drop sw_reg_series
}
if _rc == 0 {
    display as result "  PASS: string state variable may use canonical name series"
    local ++pass_count
}
else {
    display as error "  FAIL: string state variable may use canonical name series (error `=_rc')"
    capture graph drop sw_reg_series_graph
    capture frame drop sw_reg_series
    local ++fail_count
}

local ++test_count
capture noisily {
    clear
    input id duration strL group
    1 10 "Control xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
    2 20 "Active"
    end
    swimlane, id(id) duration(duration) by(group) ///
        frame(sw_reg_group, replace) name(sw_reg_group_graph, replace) nodraw
    assert r(N_subjects) == 2
    frame sw_reg_group {
        assert grouplab == group if rowtype == "bar"
        quietly count if strpos(grouplab, "Control") == 1
        assert r(N) == 1
        quietly count if grouplab == "Active"
        assert r(N) == 1
    }
    graph describe sw_reg_group_graph
    graph drop sw_reg_group_graph
    frame drop sw_reg_group
}
if _rc == 0 {
    display as result "  PASS: string grouping variable may use canonical name group"
    local ++pass_count
}
else {
    display as error "  FAIL: string grouping variable may use canonical name group (error `=_rc')"
    capture graph drop sw_reg_group_graph
    capture frame drop sw_reg_group
    local ++fail_count
}

local ++test_count
capture noisily {
    clear
    input subject id label series group
    1 0 1 1 10
    1 1 2 2 10
    2 0 2 1 20
    end
    swimlane, id(subject) start(id) stop(label) state(series) by(group) ///
        nograph frame(sw_reg_roles, replace)
    assert r(N_subjects) == 2
    assert r(N_segments) == 3
    frame sw_reg_roles: assert !missing(id, start, stop, series, group)
    frame drop sw_reg_roles
}
if _rc == 0 {
    display as result "  PASS: input roles may use canonical output names"
    local ++pass_count
}
else {
    display as error "  FAIL: input roles may use canonical output names (error `=_rc')"
    capture frame drop sw_reg_roles
    local ++fail_count
}

**# Input-shape and subject contracts

local ++test_count
capture noisily {
    clear
    input id duration
    1 10
    1 20
    2 5
    end
    capture noisily swimlane, id(id) duration(duration) nograph ///
        frame(sw_reg_dup)
    assert _rc == 459
    capture confirm frame sw_reg_dup
    assert _rc == 111
}
if _rc == 0 {
    display as result "  PASS: wide input rejects duplicate subject identifiers"
    local ++pass_count
}
else {
    display as error "  FAIL: wide input rejects duplicate subject identifiers (error `=_rc')"
    capture frame drop sw_reg_dup
    local ++fail_count
}

local ++test_count
capture noisily {
    clear
    input id _t0 _t _d _st
    1 0 5 0 1
    2 0 8 1 1
    end
    capture noisily swimlane, id(id) nograph
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: survival variable names alone do not impersonate stset data"
    local ++pass_count
}
else {
    display as error "  FAIL: survival variable names alone do not impersonate stset data (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    clear
    input id start stop arm
    1 0 1 1
    1 1 2 2
    2 0 2 1
    end
    capture noisily swimlane, id(id) start(start) stop(stop) by(arm) nograph
    assert _rc == 459
    capture noisily swimlane, id(id) start(start) stop(stop) colorby(arm) nograph
    assert _rc == 459
}
if _rc == 0 {
    display as result "  PASS: grouping variables must be constant within subject"
    local ++pass_count
}
else {
    display as error "  FAIL: grouping variables must be constant within subject (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    clear
    input id duration ongoing
    1 10 0
    2 20 .
    3 30 1
    end
    swimlane, id(id) duration(duration) ongoing(ongoing) ///
        nograph frame(sw_reg_ongoing, replace)
    assert r(N_subjects) == 3
    assert r(N_ongoing) == 1
    frame sw_reg_ongoing {
        quietly count if id == 2 & rowtype == "bar" & ongoing == 0
        assert r(N) == 1
    }
    frame drop sw_reg_ongoing
}
if _rc == 0 {
    display as result "  PASS: missing ongoing values mean not ongoing without dropping subjects"
    local ++pass_count
}
else {
    display as error "  FAIL: missing ongoing values mean not ongoing without dropping subjects (error `=_rc')"
    capture frame drop sw_reg_ongoing
    local ++fail_count
}

local ++test_count
capture noisily {
    clear
    input id start stop ev etype
    1 0 10 1 1
    2 0 10 1 .
    end
    label define sw_reg_evt 1 "Known"
    label values etype sw_reg_evt
    swimlane, id(id) start(start) stop(stop) eventvar(ev) eventtype(etype) ///
        nograph frame(sw_reg_etype, replace)
    assert r(N_events) == 2
    frame sw_reg_etype {
        quietly count if rowtype == "event" & id == 2 & series == "Event"
        assert r(N) == 1
        assert !missing(series_k) if rowtype == "event"
    }
    frame drop sw_reg_etype
}
if _rc == 0 {
    display as result "  PASS: missing event categories remain visible as Event"
    local ++pass_count
}
else {
    display as error "  FAIL: missing event categories remain visible as Event (error `=_rc')"
    capture frame drop sw_reg_etype
    local ++fail_count
}

local ++test_count
capture noisily {
    _swimlane_make_stset
    gen byte manual_ongoing = 0
    swimlane, id(id) ongoing(manual_ongoing) nograph
    assert r(N_ongoing) == 0
}
if _rc == 0 {
    display as result "  PASS: ongoing option is honored for stset input"
    local ++pass_count
}
else {
    display as error "  FAIL: ongoing option is honored for stset input (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    clear
    input id start stop duration ev origin
    1 0 10 10 5 0
    2 0 20 20 8 0
    end
    capture noisily swimlane, id(id) start(start) stop(stop) ///
        duration(duration) nograph
    assert _rc == 198
    capture noisily swimlane, id(id) start(start) stop(stop) origin(origin) nograph
    assert _rc == 198
    capture noisily swimlane, id(id) duration(duration) eventsabsolute nograph
    assert _rc == 198
    _swimlane_make_stset
    gen double origin = 0
    capture noisily swimlane, id(id) origin(origin) nograph
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: mutually exclusive input-shape options are rejected"
    local ++pass_count
}
else {
    display as error "  FAIL: mutually exclusive input-shape options are rejected (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    clear
    input id start stop
    1 0 20
    1 10 5
    end
    capture noisily swimlane, id(id) start(start) stop(stop) nograph
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: every long interval must have start <= stop"
    local ++pass_count
}
else {
    display as error "  FAIL: masked inverted long interval (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    clear
    input id t d eligible group
    1 1 0 0 9
    1 2 1 1 1
    2 2 0 1 1
    end
    stset t if eligible, failure(d) id(id)
    swimlane, id(id) by(group) nograph frame(sw_reg_stsample, replace)
    assert r(N_subjects) == 2
    assert r(N_groups) == 1
    frame sw_reg_stsample: assert group == 1 if rowtype == "bar"
    frame drop sw_reg_stsample

    clear
    set obs 15
    generate id = _n
    generate t = 1
    generate d = 0
    generate eligible = _n <= 2
    generate group = cond(eligible, 1, _n)
    stset t if eligible, failure(d) id(id)
    swimlane, id(id) by(group) nograph frame(sw_reg_stlevels, replace)
    assert r(N_subjects) == 2
    assert r(N_groups) == 1
    frame drop sw_reg_stlevels
}
if _rc == 0 {
    display as result "  PASS: stset contracts use only the _st analysis sample"
    local ++pass_count
}
else {
    display as error "  FAIL: stset analysis-sample filtering (error `=_rc')"
    capture frame drop sw_reg_stsample sw_reg_stlevels
    local ++fail_count
}

local ++test_count
capture noisily {
    clear
    input id t d sortv
    1 1 0 1
    1 2 1 2
    2 2 0 0
    end
    stset t, failure(d) id(id)
    capture noisily swimlane, id(id) sort(sortv) nograph
    assert _rc == 459
}
if _rc == 0 {
    display as result "  PASS: stset sort variables must be constant within subject"
    local ++pass_count
}
else {
    display as error "  FAIL: varying stset sort variable (error `=_rc')"
    local ++fail_count
}

**# Strict option parsing and destructive-output guards

local ++test_count
capture noisily {
    clear
    set obs 1
    gen sentinel = 42
    frame put _all, into(sw_reg_keep)
    clear
    input id duration
    1 10
    2 20
    end
    capture noisily swimlane, id(id) duration(duration) nograph ///
        frame(sw_reg_keep, notreplace)
    assert _rc == 198
    frame sw_reg_keep: confirm variable sentinel
    frame sw_reg_keep: assert sentinel == 42
    frame drop sw_reg_keep
}
if _rc == 0 {
    display as result "  PASS: invalid frame options cannot replace an existing frame"
    local ++pass_count
}
else {
    display as error "  FAIL: invalid frame options cannot replace an existing frame (error `=_rc')"
    capture frame drop sw_reg_keep
    local ++fail_count
}

local ++test_count
capture noisily {
    tempname existing_stub
    local existing_savedata ///
        "`c(tmpdir)'/`existing_stub'_swimlane_existing.csv"
    capture erase "`existing_savedata'"
    clear
    set obs 1
    generate sentinel = 42
    frame put _all, into(sw_reg_existing)
    clear
    input id duration
    1 10
    2 20
    end
    capture noisily swimlane, id(id) duration(duration) nograph ///
        savedata("`existing_savedata'") frame(sw_reg_existing)
    local existing_rc = _rc
    capture confirm file "`existing_savedata'"
    local existing_file_rc = _rc
    capture frame sw_reg_existing: confirm variable sentinel
    local existing_sentinel_rc = _rc
    assert `existing_rc' == 110
    assert `existing_file_rc' == 601
    assert `existing_sentinel_rc' == 0
    frame drop sw_reg_existing
}
if _rc == 0 {
    display as result ///
        "  PASS: an existing frame rejection creates no partial savedata"
    local ++pass_count
}
else {
    display as error ///
        "  FAIL: existing-frame side-effect order (error `=_rc')"
    capture erase "`existing_savedata'"
    capture frame drop sw_reg_existing
    local ++fail_count
}

local ++test_count
capture noisily {
    tempname protected_stub
    local protected_savedata ///
        "`c(tmpdir)'/`protected_stub'_swimlane_protected.csv"
    capture erase "`protected_savedata'"
    clear
    input id duration sentinel
    1 10 99
    2 20 99
    end
    capture noisily swimlane, id(id) duration(duration) nograph ///
        savedata("`protected_savedata'") frame(default, replace)
    local active_rc = _rc
    capture confirm variable sentinel
    local sentinel_rc = _rc
    local active_n = _N
    capture confirm file "`protected_savedata'"
    local savedata_rc = _rc
    assert `active_rc' == 198
    assert `sentinel_rc' == 0
    assert `active_n' == 2
    assert sentinel == 99
    assert `savedata_rc' == 601
}
if _rc == 0 {
    display as result ///
        "  PASS: frame() cannot replace active data or create partial output"
    local ++pass_count
}
else {
    display as error "  FAIL: active-frame replacement guard (error `=_rc')"
    capture erase "`protected_savedata'"
    local ++fail_count
}

local ++test_count
capture noisily {
    clear
    input id duration
    1 10
    2 20
    end
    capture frame drop sw_reg_event_source
    frame create sw_reg_event_source
    frame sw_reg_event_source {
        input patient_id evtime
        1 5
        2 7
        end
    }
    capture noisily swimlane, id(id) duration(duration) ///
        eventframe(sw_reg_event_source) eventid(patient_id) ///
        eventtime(evtime) nograph frame(sw_reg_event_source, replace)
    local eventframe_rc = _rc
    capture frame sw_reg_event_source: confirm variable patient_id
    local eventid_rc = _rc
    capture frame sw_reg_event_source: confirm variable evtime
    local eventtime_rc = _rc
    frame sw_reg_event_source: quietly count
    local event_n = r(N)
    assert `eventframe_rc' == 198
    assert `eventid_rc' == 0
    assert `eventtime_rc' == 0
    assert `event_n' == 2
    frame drop sw_reg_event_source
}
if _rc == 0 {
    display as result "  PASS: frame() cannot replace the event source frame"
    local ++pass_count
}
else {
    display as error "  FAIL: event-frame replacement guard (error `=_rc')"
    capture frame drop sw_reg_event_source
    local ++fail_count
}

local ++test_count
capture noisily {
    clear
    input id duration
    1 10
    2 20
    end
    capture graph drop sw_reg_protect
    twoway scatter duration id, name(sw_reg_protect)
    capture noisily swimlane, id(id) duration(duration) ///
        name(sw_reg_protect) nodraw
    assert _rc == 110
    swimlane, id(id) duration(duration) name(sw_reg_protect, replace) nodraw
    graph describe sw_reg_protect
    graph drop sw_reg_protect
}
if _rc == 0 {
    display as result "  PASS: name replace must be explicit for an existing graph"
    local ++pass_count
}
else {
    display as error "  FAIL: name replace must be explicit for an existing graph (error `=_rc')"
    capture graph drop sw_reg_protect
    local ++fail_count
}

local ++test_count
capture noisily {
    clear
    input id duration
    1 10
    2 20
    end
    capture noisily swimlane, id(id) duration(duration) ///
        sort(duration sideways) nograph
    assert _rc == 198
    capture noisily swimlane, id(id) duration(duration) ///
        sort(duration ascending descending) nograph
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: sort accepts only one documented direction"
    local ++pass_count
}
else {
    display as error "  FAIL: sort accepts only one documented direction (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    tempfile invalid_savedata
    local invalid_savedata "`invalid_savedata'.csv"
    capture erase "`invalid_savedata'"
    clear
    input id duration
    1 10
    2 20
    end
    capture noisily swimlane, id(id) duration(duration) ///
        savedata("`invalid_savedata'", bogus) nograph
    assert _rc == 198
    capture confirm file "`invalid_savedata'"
    assert _rc == 601
}
if _rc == 0 {
    display as result "  PASS: savedata rejects undocumented trailing options"
    local ++pass_count
}
else {
    display as error "  FAIL: savedata rejects undocumented trailing options (error `=_rc')"
    capture erase "`invalid_savedata'"
    local ++fail_count
}

**# Event-coordinate and state-order contracts

local ++test_count
capture noisily {
    clear
    input id start stop ev
    1 0 10 0
    1 5  . 1
    end
    swimlane, id(id) start(start) stop(stop) eventvar(ev) ///
        nograph frame(sw_reg_event_fallback, replace)
    assert r(N_subjects) == 1
    assert r(N_segments) == 1
    assert r(N_events) == 1
    frame sw_reg_event_fallback: quietly count if ///
        rowtype == "event" & xpoint == 5
    assert r(N) == 1
    frame drop sw_reg_event_fallback
}
if _rc == 0 {
    display as result "  PASS: missing event-row stop falls back to start"
    local ++pass_count
}
else {
    display as error ///
        "  FAIL: missing event-row stop fallback (error `=_rc')"
    capture frame drop sw_reg_event_fallback
    local ++fail_count
}

local ++test_count
capture noisily {
    clear
    input id start stop state ev
    1 0 10 1 0
    1 5  . . 1
    end
    label define sw_reg_event_state 1 "A"
    label values state sw_reg_event_state
    swimlane, id(id) start(start) stop(stop) state(state) eventvar(ev) ///
        nograph frame(sw_reg_state_event, replace)
    assert r(N_subjects) == 1
    assert r(N_segments) == 1
    assert r(N_events) == 1
    frame sw_reg_state_event: quietly count if ///
        rowtype == "event" & xpoint == 5 & series == "Event"
    assert r(N) == 1
    frame drop sw_reg_state_event
}
if _rc == 0 {
    display as result "  PASS: state input retains event-only long rows"
    local ++pass_count
}
else {
    display as error "  FAIL: state event-only row retention (error `=_rc')"
    capture frame drop sw_reg_state_event
    local ++fail_count
}

local ++test_count
capture noisily {
    clear
    input id start stop state
    1 0 1 1
    1 1 2 2
    end
    label define sw_reg_order 1 "A" 2 "B"
    label values state sw_reg_order

    capture noisily swimlane, id(id) start(start) stop(stop) state(state) ///
        stateorder("TYPO" "A") nograph
    assert _rc == 198

    capture noisily swimlane, id(id) start(start) stop(stop) state(state) ///
        stateorder("A" "A") nograph
    assert _rc == 198

    label define sw_reg_order_amb 1 "Same" 2 "Same"
    label values state sw_reg_order_amb
    capture noisily swimlane, id(id) start(start) stop(stop) state(state) ///
        stateorder("Same") nograph
    assert _rc == 198
}
if _rc == 0 {
    display as result ///
        "  PASS: stateorder rejects unknown, duplicate, and ambiguous labels"
    local ++pass_count
}
else {
    display as error "  FAIL: stateorder exact mapping (error `=_rc')"
    local ++fail_count
}

**# Installed-help ancillary-data contract

local ++test_count
capture noisily {
    local qa_dir "`c(pwd)'"
    local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
    tempname hfh
    file open `hfh' using "`pkg_dir'/swimlane.sthlp", read text
    local stale_ancillary = 0
    local stale_event_example = 0
    local stale_cmdline_claim = 0
    file read `hfh' line
    while r(eof) == 0 {
        if strpos(`"`line'"', ///
            "Stata-Tools/main/_data/swimlane") local stale_ancillary = 1
        if strpos(`"`line'"', ///
            "eventvar(evflag) nograph frame(lanes") local stale_event_example = 1
        if strpos(`"`line'"', ///
            "be inspected or run by hand") local stale_cmdline_claim = 1
        file read `hfh' line
    }
    file close `hfh'
    assert `stale_ancillary' == 0
    assert `stale_event_example' == 0
    assert `stale_cmdline_claim' == 0

    clear
    input id start stop
    1 0 100
    2 0 150
    end
    capture frame drop events lanes
    frame create events
    frame events {
        input id evtime str12 evtype
        1 40 "Response"
        2 60 "Progression"
        end
    }
    swimlane, id(id) start(start) stop(stop) eventframe(events) ///
        eventtime(evtime) eventtype(evtype) nograph frame(lanes, replace)
    assert r(N_events) == 2
    frame events: assert _N == 2
    frame events: confirm variable id evtime evtype
    frame lanes: quietly count if rowtype == "event"
    assert r(N) == 2
    frame drop events lanes
}
if _rc == 0 {
    display as result ///
        "  PASS: installed-help workflows and claims match runtime behavior"
    local ++pass_count
}
else {
    display as error ///
        "  FAIL: installed-help workflow contract (error `=_rc')"
    capture file close `hfh'
    capture frame drop events lanes
    local ++fail_count
}

**# Summary

display as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"
display "RESULT: test_regressions tests=`test_count' pass=`pass_count' fail=`fail_count'"
log close _all
if `fail_count' > 0 exit 1
