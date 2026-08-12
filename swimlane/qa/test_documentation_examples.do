* test_documentation_examples.do - Runnable README and help examples
* Package: swimlane
* Stata: 16+

clear all
set varabbrev off
version 16.0

capture log close _all
capture file close swlog
file open swlog using "test_documentation_examples.log", write text replace
file close swlog
log using "test_documentation_examples.log", replace nomsg

do "_swimlane_qa_common.do"
_swimlane_qa_bootstrap

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

**# D1: README Quick Start and help wide-input example

local ++test_count
capture noisily {
    clear
    input id duration response progression ongoing
    1 140 30 120 1
    2  60 20   . 0
    3  30  .  25 0
    4 200 80 150 1
    end

    swimlane, id(id) duration(duration) events(response progression) ///
        eventlabels("Response" "Progression") ongoing(ongoing)
    assert r(N_subjects) == 4
    assert r(N_events) == 6
    assert r(N_ongoing) == 2
}
if _rc == 0 {
    display as result "  PASS: D1 README Quick Start and help wide example"
    local ++pass_count
}
else {
    display as error "  FAIL: D1 README Quick Start and help wide example (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' D1"
}
capture graph drop _all

**# D2: Help and README long-state examples

local ++test_count
capture noisily {
    clear
    input id start stop state
    1 0 2 1
    1 2 4 2
    2 0 5 1
    3 1 3 3
    end
    label define st 1 "Treatment A" 2 "Treatment B" 3 "Off treatment"
    label values state st
    swimlane, id(id) start(start) stop(stop) state(state)
    assert r(N_subjects) == 3
    assert r(N_segments) == 4
    assert "`r(mode)'" == "state"

    clear
    input id start stop state
    1 0 2 1
    1 2 4 2
    2 0 5 1
    3 1 3 3
    end
    label define state_lbl 1 "Treatment A" 2 "Treatment B" 3 "Off treatment"
    label values state state_lbl
    swimlane, id(id) start(start) stop(stop) state(state) ///
        stateorder("Treatment A" "Treatment B" "Off treatment") ///
        intervalcheck(warn)
    assert r(N_subjects) == 3
    assert r(N_segments) == 4
}
if _rc == 0 {
    display as result "  PASS: D2 help and README long-state examples"
    local ++pass_count
}
else {
    display as error "  FAIL: D2 help and README long-state examples (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' D2"
}
capture graph drop _all

**# D3: README compact-facet example

local ++test_count
capture noisily {
    clear
    input subject_id str5 display_id duration response progression death ongoing str9 arm
    101 "P-101" 140 30 120  . 1 "Control"
    102 "P-102"  60 20   .  . 0 "Control"
    103 "P-103"  90 25  80 90 0 "Treatment"
    104 "P-104" 200 80 150  . 1 "Treatment"
    end
    swimlane, id(subject_id) idlabel(display_id) duration(duration) ///
        events(response progression death) ///
        eventlabels("Response" "Progression" "Death") ongoing(ongoing) ///
        by(arm) bylayout(compact) palette(colorblind)
    assert r(N_subjects) == 4
    assert r(N_events) == 8
    assert r(N_groups) == 2
    assert r(N_panels) == 2
}
if _rc == 0 {
    display as result "  PASS: D3 README compact-facet example"
    local ++pass_count
}
else {
    display as error "  FAIL: D3 README compact-facet example (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' D3"
}
capture graph drop _all

**# D4: Help long-event and exact-interval continuation examples

local ++test_count
capture noisily {
    clear
    input id start stop evflag evtime evtype
    1 0 100 1 40 1
    1 100 200 0 . .
    2 0 150 1 60 2
    end
    label define evt 1 "Response" 2 "Progression"
    label values evtype evt
    swimlane, id(id) start(start) stop(stop) eventvar(evflag) ///
        eventtime(evtime) eventtype(evtype)
    assert r(N_subjects) == 2
    assert r(N_events) == 2

    generate response_start = 20 if evflag
    generate response_stop = evtime if evflag
    generate str8 response_type = "Response" if evflag
    swimlane, id(id) start(start) stop(stop) ///
        intervalstart(response_start) intervalstop(response_stop) ///
        intervaltype(response_type) ///
        addplot((scatter lane stop if rowtype == "bar", msymbol(none)))
    assert r(N_intervals) == 2
}
if _rc == 0 {
    display as result "  PASS: D4 help long-event and exact-interval examples"
    local ++pass_count
}
else {
    display as error "  FAIL: D4 help long-event and exact-interval examples (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' D4"
}
capture graph drop _all

**# D5: Help separate-event-frame and data-only examples

local ++test_count
capture noisily {
    clear
    input id start stop
    1 0 100
    2 0 150
    end
    capture frame drop events
    frame create events
    frame change events
    input id evtime str12 evtype
    1 40 "Response"
    2 60 "Progression"
    end
    frame change default
    swimlane, id(id) start(start) stop(stop) eventframe(events) ///
        eventtime(evtime) eventtype(evtype)
    assert r(N_events) == 2

    swimlane, id(id) start(start) stop(stop) eventframe(events) ///
        eventtime(evtime) eventtype(evtype) nograph frame(lanes, replace)
    assert r(N_events) == 2
    assert `"`r(cmdline)'"' != ""
    frame lanes: quietly count if rowtype == "event"
    assert r(N) == 2
    frame drop lanes
    frame drop events
}
if _rc == 0 {
    display as result "  PASS: D5 help event-frame and data-only examples"
    local ++pass_count
}
else {
    display as error "  FAIL: D5 help event-frame and data-only examples (rc=`=_rc')"
    capture frame change default
    capture frame drop lanes
    capture frame drop events
    local ++fail_count
    local failed_tests "`failed_tests' D5"
}
capture graph drop _all

**# D6: README separate-frame and exact-interval examples

local ++test_count
capture noisily {
    clear
    input id start stop
    1 0 200
    2 0 150
    end

    capture frame drop trial_events
    frame create trial_events
    frame change trial_events
    input id evtime str12 evtype
    1 40 "Response"
    1 120 "Progression"
    2 60 "Response"
    end
    frame change default

    swimlane, id(id) start(start) stop(stop) ///
        eventframe(trial_events) eventtime(evtime) eventtype(evtype)
    assert r(N_events) == 3
    frame drop trial_events

    clear
    input id start stop response_start response_stop str12 response_type
    1 0 200 40 120 "Response"
    2 0 150 30  90 "Response"
    end

    swimlane, id(id) start(start) stop(stop) ///
        intervalstart(response_start) intervalstop(response_stop) ///
        intervaltype(response_type) ///
        addplot((scatter lane stop if rowtype == "interval", ///
            msymbol(none) mlabel(series) mlabposition(3)))
    assert r(N_intervals) == 2
}
if _rc == 0 {
    display as result "  PASS: D6 README event-frame and interval examples"
    local ++pass_count
}
else {
    display as error "  FAIL: D6 README event-frame and interval examples (rc=`=_rc')"
    capture frame change default
    capture frame drop trial_events
    local ++fail_count
    local failed_tests "`failed_tests' D6"
}
capture graph drop _all

**# D7: README censoring and help canonical-table export examples

local ++test_count
capture noisily {
    clear
    input id t d
    1 5 0
    2 8 1
    3 3 0
    end
    stset t, failure(d) id(id)
    swimlane, id(id) censor
    assert r(N_subjects) == 3
    assert r(N_censored) == 2

    capture erase "swimlane_table.csv"
    swimlane, id(id) savedata(swimlane_table.csv)
    confirm file "swimlane_table.csv"
    preserve
    import delimited using "swimlane_table.csv", clear varnames(1)
    quietly count if rowtype == "bar"
    assert r(N) == 3
    restore
    erase "swimlane_table.csv"
}
if _rc == 0 {
    display as result "  PASS: D7 censoring and canonical-table export examples"
    local ++pass_count
}
else {
    display as error "  FAIL: D7 censoring and canonical-table export examples (rc=`=_rc')"
    capture restore
    capture erase "swimlane_table.csv"
    local ++fail_count
    local failed_tests "`failed_tests' D7"
}
capture graph drop _all

**# D8: README and help high-density plus wrapped-panel examples

local ++test_count
capture noisily {
    clear
    set obs 1000
    generate long id = _n
    generate double duration = 20 + mod(37 * id, 181)
    generate byte stage_group = 1 + mod(id - 1, 4)
    generate byte arm = 1 + mod(floor((id - 1) / 4), 3)
    label define stage_group 1 "Stage I" 2 "Stage II" 3 "Stage III" 4 "Stage IV"
    label values stage_group stage_group
    label define treatment 1 "Standard" 2 "Targeted" 3 "Combination"
    label values arm treatment
    generate byte highlight = mod(id, 97) == 0

    capture erase "swimlane_250.pdf"
    capture erase "swimlane_1000.pdf"
    swimlane if id <= 60, id(id) duration(duration) density(standard)
    assert r(N_subjects) == 60
    assert "`r(render_mode)'" == "standard"

    swimlane if id <= 250, id(id) duration(duration) ///
        density(dense) laneheight(5pt) idlabels(every 25) ///
        export(swimlane_250.pdf, replace)
    assert r(N_subjects) == 250
    assert "`r(render_mode)'" == "dense"
    confirm file "swimlane_250.pdf"

    swimlane, id(id) duration(duration) density(dense) ///
        sort(+stage_group -duration +id missing(last)) ///
        blockby(stage_group) colorby(arm) ///
        idlabels(every 100) labelif(highlight) ///
        export(swimlane_1000.pdf, replace)
    assert r(N_subjects) == 1000
    assert r(N_blocks) == 4
    confirm file "swimlane_1000.pdf"

    * Help uses the same recipe with the default missing-value policy.
    swimlane, id(id) duration(duration) density(dense) ///
        sort(+stage_group -duration +id) ///
        blockby(stage_group) colorby(arm) ///
        idlabels(every 100) labelif(highlight) ///
        export(swimlane_1000.pdf, replace)
    assert r(N_subjects) == 1000
    assert r(N_blocks) == 4
    confirm file "swimlane_1000.pdf"

    generate int page = ceil(id / 50)
    swimlane if id <= 250, id(id) duration(duration) density(dense) ///
        sort(+page -duration +id missing(last)) ///
        by(page) bylayout(compact) idlabels(none) ysize(12)
    assert r(N_subjects) == 250
    assert r(N_panels) == 5

    * Help uses the same wrapped-panel recipe with the default missing policy.
    swimlane if id <= 250, id(id) duration(duration) density(dense) ///
        sort(+page -duration +id) by(page) bylayout(compact) ///
        idlabels(none) ysize(12)
    assert r(N_subjects) == 250
    assert r(N_panels) == 5

    erase "swimlane_250.pdf"
    erase "swimlane_1000.pdf"
}
if _rc == 0 {
    display as result "  PASS: D8 high-density and wrapped-panel examples"
    local ++pass_count
}
else {
    display as error "  FAIL: D8 high-density and wrapped-panel examples (rc=`=_rc')"
    capture erase "swimlane_250.pdf"
    capture erase "swimlane_1000.pdf"
    local ++fail_count
    local failed_tests "`failed_tests' D8"
}
capture graph drop _all

**# D9: README and help overview, inspection, drill-down, and pagination

local ++test_count
capture noisily {
    clear
    set obs 1000
    generate long id = _n
    generate double duration = 20 + mod(37 * id, 181)
    generate byte stage_group = 1 + mod(id - 1, 4)
    generate byte arm = 1 + mod(floor((id - 1) / 4), 3)
    label define doc_stage_group 1 "Stage I" 2 "Stage II" 3 "Stage III" 4 "Stage IV"
    label values stage_group doc_stage_group
    label define doc_treatment 1 "Standard" 2 "Targeted" 3 "Combination"
    label values arm doc_treatment

    swimlane, id(id) duration(duration) density(dense) ///
        sort(+stage_group -duration +id missing(last)) ///
        blockby(stage_group) colorby(arm) ///
        frame(all_lanes, replace)

    frame all_lanes: keep if rowtype == "bar" & seg == 1
    frame all_lanes: keep id rank
    frame all_lanes: isid id
    frlink 1:1 id, frame(all_lanes)
    frget rank, from(all_lanes)

    summarize duration if inrange(rank, 101, 125), detail
    assert r(N) == 25
    swimlane if inrange(rank, 101, 125), id(id) duration(duration) ///
        sort(+rank +id missing(last)) maxids(all) ///
        idlabels(all) laneheight(12pt)
    assert r(N_subjects) == 25

    forvalues p = 1/20 {
        local lo = 50 * (`p' - 1) + 1
        local hi = 50 * `p'
        capture erase "swimlane_page_`p'.pdf"
        swimlane if inrange(rank, `lo', `hi'), id(id) duration(duration) ///
            sort(+rank +id missing(last)) maxids(all) ///
            idlabels(all) laneheight(12pt) ///
            export(swimlane_page_`p'.pdf, replace)
        assert r(N_subjects) == 50
        confirm file "swimlane_page_`p'.pdf"
        erase "swimlane_page_`p'.pdf"
    }
    frame drop all_lanes
}
if _rc == 0 {
    display as result "  PASS: D9 overview, drill-down, and pagination examples"
    local ++pass_count
}
else {
    display as error "  FAIL: D9 overview, drill-down, and pagination examples (rc=`=_rc')"
    capture frame drop all_lanes
    forvalues p = 1/20 {
        capture erase "swimlane_page_`p'.pdf"
    }
    local ++fail_count
    local failed_tests "`failed_tests' D9"
}
capture graph drop _all

**# D10: Documented sorting recipes

local ++test_count
capture noisily {
    clear
    input id duration progression arm site review_order
    1 10  . 2 20 4
    2 40 30 1 10 1
    3 20 10 2 10 3
    4 30 20 1 20 2
    end
    assert !missing(review_order)
    swimlane, id(id) duration(duration) ///
        sort(duration descending missing(last)) nograph frame(doc_sort, replace)
    frame doc_sort: quietly count if id == 2 & rank == 1 & rowtype == "bar"
    assert r(N) == 1
    frame doc_sort: quietly count if id == 1 & rank == 4 & rowtype == "bar"
    assert r(N) == 1
    frame drop doc_sort

    swimlane, id(id) duration(duration) ///
        sort(id ascending missing(last)) nograph frame(doc_sort, replace)
    frame doc_sort: quietly count if id == 1 & rank == 1 & rowtype == "bar"
    assert r(N) == 1
    frame doc_sort: quietly count if id == 4 & rank == 4 & rowtype == "bar"
    assert r(N) == 1
    frame drop doc_sort

    swimlane, id(id) duration(duration) ///
        sort(site ascending missing(last)) nograph frame(doc_sort, replace)
    frame doc_sort: quietly count if id == 2 & rank == 1 & rowtype == "bar"
    assert r(N) == 1
    frame doc_sort: quietly count if id == 3 & rank == 2 & rowtype == "bar"
    assert r(N) == 1
    frame drop doc_sort

    swimlane, id(id) duration(duration) ///
        sort(progression ascending missing(last)) nograph frame(doc_sort, replace)
    frame doc_sort: quietly count if id == 3 & rank == 1 & rowtype == "bar"
    assert r(N) == 1
    frame doc_sort: quietly count if id == 1 & rank == 4 & rowtype == "bar"
    assert r(N) == 1
    frame drop doc_sort

    swimlane, id(id) duration(duration) ///
        sort(+arm -duration +id missing(last)) nograph frame(doc_sort, replace)
    frame doc_sort: quietly count if id == 2 & rank == 1 & rowtype == "bar"
    assert r(N) == 1
    frame drop doc_sort

    swimlane, id(id) duration(duration) ///
        sort(+review_order +id missing(last)) nograph frame(doc_sort, replace)
    frame doc_sort: quietly count if id == 2 & rank == 1 & rowtype == "bar"
    assert r(N) == 1
    frame drop doc_sort

    clear
    input id start stop event event_time state
    1 0 2 0 . 1
    1 2 5 1 4 2
    2 0 3 1 1 2
    2 3 6 0 . 2
    3 1 4 0 . 1
    end
    bysort id: egen first_progression = min(cond(event == 1, event_time, .))
    bysort id: egen time_in_state = total(cond(state == 2, stop - start, 0))

    swimlane, id(id) start(start) stop(stop) state(state) ///
        sort(start ascending missing(last)) nograph frame(doc_sort, replace)
    frame doc_sort: assert rank == 1 if id == 1
    frame doc_sort: assert rank == 2 if id == 2
    frame doc_sort: assert rank == 3 if id == 3
    frame drop doc_sort

    swimlane, id(id) start(start) stop(stop) state(state) ///
        sort(+first_progression +id missing(last)) ///
        nograph frame(doc_sort, replace)
    frame doc_sort: assert rank == 1 if id == 2
    frame doc_sort: assert rank == 2 if id == 1
    frame doc_sort: assert rank == 3 if id == 3
    frame drop doc_sort

    swimlane, id(id) start(start) stop(stop) state(state) ///
        sort(-time_in_state +id missing(last)) ///
        nograph frame(doc_sort, replace)
    frame doc_sort: assert rank == 1 if id == 2
    frame doc_sort: assert rank == 2 if id == 1
    frame doc_sort: assert rank == 3 if id == 3
    frame drop doc_sort
}
if _rc == 0 {
    display as result "  PASS: D10 documented sorting recipes"
    local ++pass_count
}
else {
    display as error "  FAIL: D10 documented sorting recipes (rc=`=_rc')"
    capture frame drop doc_sort
    local ++fail_count
    local failed_tests "`failed_tests' D10"
}

**# Summary

display as result ///
    "Documentation examples: `pass_count'/`test_count' passed, `fail_count' failed"
display "RESULT: test_documentation_examples tests=`test_count' pass=`pass_count' fail=`fail_count' skip=0"
log close _all

if `fail_count' > 0 {
    display as error "Failed tests:`failed_tests'"
    exit 1
}
