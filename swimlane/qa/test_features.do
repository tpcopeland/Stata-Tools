clear all
set varabbrev off
version 16.0

capture log close _all
capture file close swlog
file open swlog using "test_features.log", write text replace
file close swlog
log using "test_features.log", replace nomsg

do "_swimlane_qa_common.do"
_swimlane_qa_bootstrap

local test_count = 0
local pass_count = 0
local fail_count = 0

**# 1. Long-format event input (eventvar/eventtime/eventtype)

local ++test_count
capture noisily {
    _swimlane_make_long_events
    swimlane, id(id) start(start) stop(stop) eventvar(evflag) ///
        eventtime(evtime) eventtype(evtype) nograph frame(sw_le, replace)
    assert "`r(mode)'" == "swimmer"
    assert "`r(shape)'" == "long"
    assert r(N_subjects) == 3
    assert r(N_segments) == 3
    assert r(N_events) == 3
    frame sw_le {
        quietly count if rowtype == "event"
        assert r(N) == 3
        * event types carry value labels
        quietly count if rowtype == "event" & series == "Response"
        assert r(N) == 2
        quietly count if rowtype == "event" & series == "Progression"
        assert r(N) == 1
        * explicit event time honored (id 1 fires at 40)
        quietly levelsof xpoint if id == 1 & rowtype == "event", local(_xp)
        assert "`_xp'" == "40"
    }
}
if _rc == 0 {
    display as result "  PASS: long-format events with type/time"
    local ++pass_count
}
else {
    display as error "  FAIL: long-format events with type/time (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    * eventtime() omitted -> marker defaults to the row stop
    _swimlane_make_long_events
    swimlane, id(id) start(start) stop(stop) eventvar(evflag) ///
        nograph frame(sw_le2, replace)
    assert r(N_events) == 3
    frame sw_le2 {
        * id 1 event defaults to its stop (100); single "Event" series
        quietly levelsof xpoint if id == 1 & rowtype == "event", local(_xp)
        assert "`_xp'" == "100"
        quietly count if rowtype == "event" & series == "Event"
        assert r(N) == 3
    }
}
if _rc == 0 {
    display as result "  PASS: long events default time = stop"
    local ++pass_count
}
else {
    display as error "  FAIL: long events default time = stop (error `=_rc')"
    local ++fail_count
}

**# 2. Date-aware time axis (r(timefmt) + carried format)

local ++test_count
capture noisily {
    _swimlane_make_dates
    swimlane, id(id) start(start) stop(stop) nograph frame(sw_dt, replace)
    assert "`r(timefmt)'" == "%td"
    local _date_cmd `"`r(cmdline)'"'
    assert strpos(`"`_date_cmd'"', "angle(45)") > 0
    assert strpos(`"`_date_cmd'"', "labsize(small)") > 0
    frame sw_dt {
        assert "`: format start'" == "%td"
        assert "`: format stop'" == "%td"
        assert "`: format xpoint'" == "%td"
        * duration stays an unformatted elapsed difference
        assert substr("`: format duration'", 1, 2) != "%t"
    }
}
if _rc == 0 {
    display as result "  PASS: date format carried to canonical table"
    local ++pass_count
}
else {
    display as error "  FAIL: date format carried (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    clear
    input id duration ev
    1 10 21915
    2 20 21916
    end
    format ev %td
    swimlane, id(id) duration(duration) events(ev) eventsabsolute ///
        nograph frame(sw_abs_date, replace)
    assert "`r(timefmt)'" == "%td"
    frame sw_abs_date {
        assert "`: format start'" == "%td"
        assert "`: format stop'" == "%td"
        assert "`: format xpoint'" == "%td"
        quietly levelsof xpoint if rowtype == "event", local(_event_dates)
        assert "`_event_dates'" == "21915 21916"
    }
    frame drop sw_abs_date
}
if _rc == 0 {
    display as result "  PASS: absolute wide events carry their %t format"
    local ++pass_count
}
else {
    display as error "  FAIL: absolute wide event format (error `=_rc')"
    capture frame drop sw_abs_date
    local ++fail_count
}

**# 3. r(cmdline)

local ++test_count
capture noisily {
    _swimlane_make_wide
    swimlane, id(id) duration(duration) events(response progression) ///
        name(sw_cmd, replace) nodraw
    assert `"`r(cmdline)'"' != ""
    assert substr(`"`r(cmdline)'"', 1, 6) == "twoway"
}
if _rc == 0 {
    display as result "  PASS: r(cmdline) returns twoway string"
    local ++pass_count
}
else {
    display as error "  FAIL: r(cmdline) (error `=_rc')"
    local ++fail_count
}

**# 4. nograph data-only mode

local ++test_count
capture noisily {
    graph drop _all
    _swimlane_make_wide
    swimlane, id(id) duration(duration) events(response progression) ///
        nograph frame(sw_ng, replace)
    * capture the return surface before any graph command clobbers r()
    local _gn "`r(graphname)'"
    local _cl `"`r(cmdline)'"'
    local _ns = r(N_subjects)
    assert "`_gn'" == ""
    assert `"`_cl'"' != ""
    assert `_ns' == 4
    * no graph was produced
    capture graph describe swimlane
    assert _rc != 0
    frame sw_ng: quietly count
    assert r(N) > 0
}
if _rc == 0 {
    display as result "  PASS: nograph builds data, skips plot"
    local ++pass_count
}
else {
    display as error "  FAIL: nograph (error `=_rc')"
    local ++fail_count
}

**# 5. stateorder()

local ++test_count
capture noisily {
    _swimlane_make_long_state
    * default state labels are A,B,C; request reverse order
    swimlane, id(id) start(start) stop(stop) state(state) ///
        stateorder("C" "B" "A") nograph frame(sw_so, replace)
    frame sw_so {
        quietly levelsof series_k if series == "C", local(_kc)
        quietly levelsof series_k if series == "A", local(_ka)
        assert "`_kc'" == "1"
        assert "`_ka'" == "3"
    }
    * partial order: only "C" listed, A and B follow after it
    _swimlane_make_long_state
    swimlane, id(id) start(start) stop(stop) state(state) ///
        stateorder("C") nograph frame(sw_so2, replace)
    frame sw_so2 {
        quietly levelsof series_k if series == "C", local(_kc2)
        assert "`_kc2'" == "1"
    }
}
if _rc == 0 {
    display as result "  PASS: stateorder controls series order"
    local ++pass_count
}
else {
    display as error "  FAIL: stateorder (error `=_rc')"
    local ++fail_count
}

**# 7. censor glyph (stset)

local ++test_count
capture noisily {
    _swimlane_make_stset
    swimlane, id(id) censor nograph frame(sw_cn, replace)
    * subjects 1 and 3 are censored (d==0); subject 2 fails
    assert r(N_censored) == 2
    frame sw_cn {
        quietly count if rowtype == "censor"
        assert r(N) == 2
        quietly count if rowtype == "event"
        assert r(N) == 1
        * censor markers are not folded into r(states)/series colors
        quietly count if rowtype == "censor" & series == "Censored"
        assert r(N) == 2
    }
    * without censor, no censor rows
    _swimlane_make_stset
    swimlane, id(id) nograph frame(sw_cn0, replace)
    assert r(N_censored) == 0
}
if _rc == 0 {
    display as result "  PASS: censor adds distinct censoring markers"
    local ++pass_count
}
else {
    display as error "  FAIL: censor (error `=_rc')"
    local ++fail_count
}

**# 8. zero-width-bar guard

local ++test_count
capture noisily {
    * events-only wide input (no duration/origin) -> zero-width spans
    clear
    input id ev
    1 10
    2 20
    end
    swimlane, id(id) events(ev) nograph frame(sw_zw, replace)
    assert r(N_subjects) == 2
    frame sw_zw {
        * lanes still exist for each subject
        quietly levelsof lane, local(_lanes)
        assert "`_lanes'" == "1 2"
        * zero-width bars: start == stop
        quietly count if rowtype == "bar" & start == stop
        assert r(N) == 2
    }
}
if _rc == 0 {
    display as result "  PASS: zero-width guard keeps lanes"
    local ++pass_count
}
else {
    display as error "  FAIL: zero-width guard (error `=_rc')"
    local ++fail_count
}

**# 9. barlabel(duration) renders

local ++test_count
capture noisily {
    _swimlane_make_wide
    swimlane, id(id) duration(duration) barlabel(duration) ///
        name(sw_bl, replace) nodraw
    assert r(N_subjects) == 4
    graph describe sw_bl
}
if _rc == 0 {
    display as result "  PASS: barlabel(duration) renders"
    local ++pass_count
}
else {
    display as error "  FAIL: barlabel(duration) (error `=_rc')"
    local ++fail_count
}

**# Regression: frame(name, replace) forwarding (comma-bearing option)

local ++test_count
capture noisily {
    _swimlane_make_wide
    swimlane, id(id) duration(duration) nograph frame(sw_reg, replace)
    frame sw_reg: quietly count
    local _n1 = r(N)
    * second call with replace must succeed (was broken: rc 198)
    swimlane, id(id) duration(duration) nograph frame(sw_reg, replace)
    capture confirm frame sw_reg
    assert _rc == 0
}
if _rc == 0 {
    display as result "  PASS: frame(name, replace) forwarding"
    local ++pass_count
}
else {
    display as error "  FAIL: frame(name, replace) forwarding (error `=_rc')"
    local ++fail_count
}

**# Regression: user legend() merges with generated label order

local ++test_count
capture noisily {
    _swimlane_make_wide
    * positioning the legend must not discard the event-series labels
    swimlane, id(id) duration(duration) events(response progression) ///
        eventlabels("Response" "Progression") legend(pos(6) rows(1)) ///
        nograph
    local _cl `"`r(cmdline)'"'
    assert strpos(`"`_cl'"', "order(") > 0
    assert strpos(`"`_cl'"', "Response") > 0
    assert strpos(`"`_cl'"', "pos(6)") > 0
    * an explicit legend(off) is respected, no order injected
    swimlane, id(id) duration(duration) events(response) legend(off) nograph
    assert strpos(`"`r(cmdline)'"', "order(") == 0
}
if _rc == 0 {
    display as result "  PASS: legend() merges with generated order"
    local ++pass_count
}
else {
    display as error "  FAIL: legend() merges with generated order (error `=_rc')"
    local ++fail_count
}

**# Compact facets, display labels, and addplot()

local ++test_count
capture noisily {
    clear
    input id duration group str24 display_id
    1 10 1 "P-001"
    2  9 1 "P-002"
    3  8 2 "P-003"
    4  7 2 "P-004"
    5  6 2 "P-005"
    end
    swimlane, id(id) idlabel(display_id) duration(duration) by(group) ///
        nograph frame(sw_aligned, replace)
    frame sw_aligned: quietly summarize lane if group == 1, meanonly
    assert r(min) == 4 & r(max) == 5

    swimlane, id(id) idlabel(display_id) duration(duration) by(group) ///
        bylayout(compact) palette(colorblind) ///
        addplot((scatter lane stop if rowtype == "bar", ///
            msymbol(Oh) mcolor(red))) ///
        title("One global facet title") subtitle("Compact lanes") ///
        note("QA note") frame(sw_compact, replace) ///
        name(sw_compact_graph, replace) nodraw
    local _cl `"`r(cmdline)'"'
    assert r(N_groups) == 2
    assert strpos(`"`_cl'"', " yrescale") > 0
    * Compact-facet subject labels sit outside the bar start. Placing them
    * inside the bar can collide with early event markers.
    assert strpos(`"`_cl'"', "mlabel(label)") > 0
    assert strpos(`"`_cl'"', "mlabposition(9)") > 0
    assert strpos(`"`_cl'"', "mlabposition(3)") == 0
    assert strpos(`"`_cl'"', "plotregion(margin(l+10))") > 0
    assert strpos(`"`_cl'"', "msymbol(Oh)") > 0
    local _bypos = strpos(`"`_cl'"', " by(group,")
    local _titlepos = strpos(`"`_cl'"', " title(")
    assert `_bypos' > 0 & `_titlepos' > `_bypos'
    frame sw_compact: quietly summarize lane if group == 1, meanonly
    assert r(min) == 1 & r(max) == 2
    frame sw_compact: quietly summarize lane if group == 2, meanonly
    assert r(min) == 1 & r(max) == 3
    frame sw_compact: assert label == "P-001" if id == 1
    frame sw_compact: assert label == "P-005" if id == 5
    graph describe sw_compact_graph
    graph drop sw_compact_graph

    replace display_id = "STANDARD-PATIENT-0001" if id == 1
    replace display_id = "EXPERIMENT-PATIENT-05" if id == 5
    swimlane, id(id) idlabel(display_id) duration(duration) by(group) ///
        bylayout(compact) nograph
    local _long_cl `"`r(cmdline)'"'
    assert strpos(`"`_long_cl'"', "plotregion(margin(l+30))") > 0

    swimlane, id(id) idlabel(display_id) duration(duration) by(group) ///
        bylayout(compact) noylabels nograph
    local _noy_cl `"`r(cmdline)'"'
    assert strpos(`"`_noy_cl'"', "mlabel(label)") == 0
    assert strpos(`"`_noy_cl'"', "plotregion(margin(l+") == 0
    frame drop sw_aligned sw_compact
}
if _rc == 0 {
    display as result ///
        "  PASS: aligned/compact facets, idlabel(), global title, and addplot()"
    local ++pass_count
}
else {
    display as error ///
        "  FAIL: compact facet extensions (error `=_rc')"
    capture graph drop sw_compact_graph
    capture frame drop sw_aligned sw_compact
    local ++fail_count
}

**# Named palettes and colors() precedence

local ++test_count
capture noisily {
    foreach _pal in default colorblind mono scheme {
        _swimlane_make_wide
        swimlane, id(id) duration(duration) events(response progression) ///
            palette(`_pal') name(sw_palette_`_pal', replace) nodraw
        graph describe sw_palette_`_pal'
        graph drop sw_palette_`_pal'
    }
    _swimlane_make_wide
    swimlane, id(id) duration(duration) events(response) ///
        palette(mono) colors(red blue) nograph
    assert strpos(`"`r(cmdline)'"', "color(red%65)") > 0
    assert strpos(`"`r(cmdline)'"', "mcolor(blue)") > 0
}
if _rc == 0 {
    display as result "  PASS: palette presets render and colors() overrides them"
    local ++pass_count
}
else {
    display as error "  FAIL: palette presets (error `=_rc')"
    capture graph drop sw_palette_default sw_palette_colorblind ///
        sw_palette_mono sw_palette_scheme
    local ++fail_count
}

**# Events in a separate frame, including if/in selection

local ++test_count
capture noisily {
    clear
    input id duration arm
    1 10 1
    2 12 2
    end
    capture frame drop sw_external_events
    frame create sw_external_events
    frame sw_external_events {
        input patient_id evtime str12 evtype
        1 4 "Response"
        2 5 "Progression"
        end
    }
    swimlane if arm == 1, id(id) duration(duration) ///
        eventframe(sw_external_events) eventid(patient_id) ///
        eventtime(evtime) eventtype(evtype) nograph ///
        frame(sw_external_result, replace)
    assert r(N_subjects) == 1
    assert r(N_events) == 1
    frame sw_external_result: quietly count if ///
        rowtype == "event" & id == 1 & xpoint == 4 & series == "Response"
    assert r(N) == 1
    frame sw_external_result: quietly count if id == 2
    assert r(N) == 0
    frame sw_external_events: assert _N == 2
    frame sw_external_events: assert patient_id[1] == 1 & patient_id[2] == 2
    frame sw_external_events: assert evtime[1] == 4 & evtime[2] == 5
    frame drop sw_external_events sw_external_result
}
if _rc == 0 {
    display as result ///
        "  PASS: eventframe() custom ID, type labels, selection, and preservation"
    local ++pass_count
}
else {
    display as error "  FAIL: eventframe() behavior (error `=_rc')"
    capture frame drop sw_external_events sw_external_result
    local ++fail_count
}

**# Summary

display as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    display "RESULT: test_features tests=`test_count' pass=`pass_count' fail=`fail_count'"
    log close _all
    exit 1
}
display as result "ALL TESTS PASSED"
display "RESULT: test_features tests=`test_count' pass=`pass_count' fail=`fail_count'"
log close _all
