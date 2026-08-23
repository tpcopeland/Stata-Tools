clear all
set varabbrev off
version 16.0

capture log close _all
capture file close swlog
file open swlog using "test_errors.log", write text replace
file close swlog
log using "test_errors.log", replace nomsg

do "_swimlane_qa_common.do"
_swimlane_qa_bootstrap

local test_count = 0
local pass_count = 0
local fail_count = 0

local ++test_count
capture noisily {
    _swimlane_make_wide
    capture noisily swimlane, id(id) duration(duration) events(response) ///
        state(arm) name(sw_err1, replace) nodraw
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: state plus events error"
    local ++pass_count
}
else {
    display as error "  FAIL: state plus events error (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    _swimlane_make_wide
    capture noisily swimlane, id(id) duration(duration) mode(state) ///
        name(sw_err_state, replace) nodraw
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: mode(state) requires state()"
    local ++pass_count
}
else {
    display as error "  FAIL: mode(state) requires state() (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    clear
    input id y
    1 1
    end
    capture noisily swimlane, id(id) name(sw_err2, replace) nodraw
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: no time info error"
    local ++pass_count
}
else {
    display as error "  FAIL: no time info error (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    _swimlane_make_wide
    capture noisily swimlane, id(id) duration(duration) ///
        events(response progression) eventlabels("Only one") ///
        name(sw_err3, replace) nodraw
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: eventlabels mismatch error"
    local ++pass_count
}
else {
    display as error "  FAIL: eventlabels mismatch error (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    clear
    set obs 13
    gen id = _n
    gen duration = 10
    gen grp = _n
    capture noisily swimlane, id(id) duration(duration) by(grp) ///
        name(sw_err4, replace) nodraw
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: by level cap error"
    local ++pass_count
}
else {
    display as error "  FAIL: by level cap error (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    clear
    input id start stop sortv
    1 0 1 1
    1 1 2 2
    2 0 2 1
    end
    capture noisily swimlane, id(id) start(start) stop(stop) ///
        sort(sortv) name(sw_err5, replace) nodraw
    assert _rc == 459
}
if _rc == 0 {
    display as result "  PASS: varying sort variable error"
    local ++pass_count
}
else {
    display as error "  FAIL: varying sort variable error (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    clear
    input id start stop
    1 5 2
    end
    capture noisily swimlane, id(id) start(start) stop(stop) ///
        name(sw_err6, replace) nodraw
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: inverted interval error"
    local ++pass_count
}
else {
    display as error "  FAIL: inverted interval error (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    _swimlane_make_wide
    capture noisily swimlane if id > 100, id(id) duration(duration) ///
        name(sw_err7, replace) nodraw
    assert _rc == 2000
}
if _rc == 0 {
    display as result "  PASS: empty sample error"
    local ++pass_count
}
else {
    display as error "  FAIL: empty sample error (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    _swimlane_make_wide
    capture noisily swimlane, id(id) duration(duration) maxids(0) ///
        name(sw_err_maxids, replace) nodraw
    assert _rc == 198
    capture noisily swimlane, id(id) duration(duration) barwidth(0) ///
        name(sw_err_barwidth, replace) nodraw
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: invalid numeric option errors"
    local ++pass_count
}
else {
    display as error "  FAIL: invalid numeric option errors (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    _swimlane_make_wide
    capture noisily swimlane, id(id) duration(duration) ///
        savedata("bad;name.csv") name(sw_err_path1, replace) nodraw
    assert _rc == 198
    capture noisily swimlane, id(id) duration(duration) ///
        export("bad|name.png") name(sw_err_path2, replace) nodraw
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: unsafe export paths rejected"
    local ++pass_count
}
else {
    display as error "  FAIL: unsafe export paths rejected (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    _swimlane_make_long_state
    capture noisily swimlane, id(id) start(start) stop(stop) ///
        eventtime(stop) name(sw_err_evtime, replace) nodraw
    assert _rc == 198
    capture noisily swimlane, id(id) start(start) stop(stop) ///
        eventtype(state) name(sw_err_evtype, replace) nodraw
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: eventtime/eventtype require eventvar"
    local ++pass_count
}
else {
    display as error "  FAIL: eventtime/eventtype require eventvar (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    _swimlane_make_wide
    capture noisily swimlane, id(id) duration(duration) eventvar(ongoing) ///
        name(sw_err_evvar, replace) nodraw
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: eventvar requires start()+stop()"
    local ++pass_count
}
else {
    display as error "  FAIL: eventvar requires start()+stop() (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    _swimlane_make_wide
    capture noisily swimlane, id(id) duration(duration) ///
        stateorder("A" "B") name(sw_err_so, replace) nodraw
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: stateorder requires state()"
    local ++pass_count
}
else {
    display as error "  FAIL: stateorder requires state() (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    _swimlane_make_wide
    capture noisily swimlane, id(id) duration(duration) censor ///
        name(sw_err_cen, replace) nodraw
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: censor requires stset data"
    local ++pass_count
}
else {
    display as error "  FAIL: censor requires stset data (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    _swimlane_make_wide
    capture noisily swimlane, id(id) duration(duration) nograph ///
        export("x.png") name(sw_err_ng1, replace) nodraw
    assert _rc == 198
    capture noisily swimlane, id(id) duration(duration) nograph ///
        saving("x.gph") name(sw_err_ng2, replace) nodraw
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: nograph rejects export()/saving()"
    local ++pass_count
}
else {
    display as error "  FAIL: nograph rejects export()/saving() (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    _swimlane_make_wide
    capture noisily swimlane, id(id) duration(duration) barlabel(foo) ///
        name(sw_err_bl1, replace) nodraw
    assert _rc == 198
    _swimlane_make_long_state
    capture noisily swimlane, id(id) start(start) stop(stop) state(state) ///
        barlabel(duration) name(sw_err_bl2, replace) nodraw
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: barlabel validation and mode guard"
    local ++pass_count
}
else {
    display as error "  FAIL: barlabel validation and mode guard (error `=_rc')"
    local ++fail_count
}

**# Display-label validation

local ++test_count
capture noisily {
    clear
    input id start stop str4 alias
    1 0 1 "A"
    1 1 2 "B"
    end
    capture noisily swimlane, id(id) idlabel(alias) ///
        start(start) stop(stop) nograph
    assert _rc == 459

    clear
    input id duration str4 alias
    1 10 "A"
    2 20 ""
    end
    capture noisily swimlane, id(id) idlabel(alias) duration(duration) nograph
    assert _rc == 459
}
if _rc == 0 {
    display as result "  PASS: idlabel() rejects varying and missing labels"
    local ++pass_count
}
else {
    display as error "  FAIL: idlabel() guards (error `=_rc')"
    local ++fail_count
}

**# External-event frame validation

local ++test_count
capture noisily {
    clear
    input id duration
    1 10
    2 20
    end
    capture frame drop sw_error_events
    frame create sw_error_events
    frame sw_error_events {
        input patient_id evtime str4 badtime
        1 4 "four"
        99 5 "five"
        end
    }
    capture noisily swimlane, id(id) duration(duration) eventid(id) nograph
    assert _rc == 198
    capture noisily swimlane, id(id) duration(duration) ///
        eventframe(sw_error_events) eventid(patient_id) nograph
    assert _rc == 198
    capture noisily swimlane, id(id) duration(duration) ///
        eventframe(sw_error_events) eventid(no_such_id) ///
        eventtime(evtime) nograph
    assert _rc == 111
    capture noisily swimlane, id(id) duration(duration) ///
        eventframe(sw_error_events) eventid(patient_id) ///
        eventtime(badtime) nograph
    assert _rc == 109
    capture noisily swimlane, id(id) duration(duration) ///
        eventframe(sw_error_events) eventid(patient_id) ///
        eventtime(evtime) nograph
    assert _rc == 459
    frame sw_error_events: assert _N == 2
    frame sw_error_events: assert patient_id[2] == 99 & evtime[2] == 5
    frame drop sw_error_events
}
if _rc == 0 {
    display as result ///
        "  PASS: eventframe() requirements, types, unknown IDs, and preservation"
    local ++pass_count
}
else {
    display as error "  FAIL: eventframe() guards (error `=_rc')"
    capture frame drop sw_error_events
    local ++fail_count
}

**# Interval-layer validation

local ++test_count
capture noisily {
    clear
    input id start stop layer_start layer_stop str4 layer_type
    1 0 10 2 5 "A"
    2 0 10 3 . "B"
    end
    capture noisily swimlane, id(id) start(start) stop(stop) ///
        intervalstart(layer_start) nograph
    assert _rc == 198
    capture noisily swimlane, id(id) start(start) stop(stop) ///
        intervaltype(layer_type) nograph
    assert _rc == 198
    capture noisily swimlane, id(id) start(start) stop(stop) ///
        intervalstart(layer_start) intervalstop(layer_stop) nograph
    assert _rc == 459
    replace layer_stop = 1 in 1
    replace layer_stop = 4 in 2
    capture noisily swimlane, id(id) start(start) stop(stop) ///
        intervalstart(layer_start) intervalstop(layer_stop) nograph
    assert _rc == 198

    clear
    input id duration layer_start layer_stop
    1 10 2 5
    end
    capture noisily swimlane, id(id) duration(duration) ///
        intervalstart(layer_start) intervalstop(layer_stop) nograph
    assert _rc == 198
}
if _rc == 0 {
    display as result ///
        "  PASS: interval layers reject incomplete, inverted, and non-long input"
    local ++pass_count
}
else {
    display as error "  FAIL: interval-layer guards (error `=_rc')"
    local ++fail_count
}

**# Facet, palette, and geometry-audit validation

local ++test_count
capture noisily {
    _swimlane_make_wide
    capture noisily swimlane, id(id) duration(duration) ///
        bylayout(compact) nograph
    assert _rc == 198
    capture noisily swimlane, id(id) duration(duration) by(arm) ///
        bylayout(stacked) nograph
    assert _rc == 198
    capture noisily swimlane, id(id) duration(duration) ///
        palette(rainbow) nograph
    assert _rc == 198
    capture noisily swimlane, id(id) duration(duration) ///
        intervalcheck(off) nograph
    assert _rc == 198

    _swimlane_make_geometry
    capture noisily swimlane, id(id) start(start) stop(stop) state(state) ///
        intervalcheck(repair) nograph
    assert _rc == 198
}
if _rc == 0 {
    display as result ///
        "  PASS: bylayout(), palette(), and intervalcheck() reject bad values"
    local ++pass_count
}
else {
    display as error "  FAIL: extension option guards (error `=_rc')"
    local ++fail_count
}

**# Preservation and late output-routing contracts

* An early incompatible option must not overwrite a pre-existing named graph.
local ++test_count
capture noisily {
    _swimlane_make_wide
    twoway scatter duration id, name(sw_errors_keep, replace)
    local orig_N = _N
    capture noisily swimlane, id(id) duration(duration) events(response) ///
        state(arm) name(sw_errors_keep, replace) nodraw
    local call_rc = _rc
    assert `call_rc' == 198
    assert _N == `orig_N'
    graph describe sw_errors_keep
    swimlane, id(id) duration(duration) events(response) ///
        name(sw_errors_legal, replace) nodraw
    assert r(N_subjects) == 4
    graph drop sw_errors_keep
    graph drop sw_errors_legal
}
if _rc == 0 {
    display as result "  PASS: early error preserves graph and data"
    local ++pass_count
}
else {
    display as error "  FAIL: early error graph preservation (error `=_rc')"
    capture graph drop sw_errors_keep
    local ++fail_count
}

* A pre-existing canonical-output frame is a late routing error, never an
* rc=0 replacement. The replace form is the legal inverse.
local ++test_count
capture noisily {
    _swimlane_make_wide
    local orig_N = _N
    capture frame drop sw_errors_output
    frame create sw_errors_output
    frame sw_errors_output: clear
    frame sw_errors_output: set obs 1
    frame sw_errors_output: gen byte sentinel = 1
    capture noisily swimlane, id(id) duration(duration) ///
        frame(sw_errors_output) nograph
    local call_rc = _rc
    assert `call_rc' == 110
    assert _N == `orig_N'
    frame sw_errors_output: assert _N == 1
    frame sw_errors_output: assert sentinel == 1
    swimlane, id(id) duration(duration) ///
        frame(sw_errors_output, replace) nograph
    frame sw_errors_output: assert _N == 4
    frame drop sw_errors_output
}
if _rc == 0 {
    display as result "  PASS: existing frame is not silently replaced"
    local ++pass_count
}
else {
    display as error "  FAIL: output frame collision preservation (error `=_rc')"
    capture frame drop sw_errors_output
    local ++fail_count
}

display as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"
display "RESULT: test_errors tests=`test_count' pass=`pass_count' fail=`fail_count'"
log close _all
if `fail_count' > 0 exit 1
