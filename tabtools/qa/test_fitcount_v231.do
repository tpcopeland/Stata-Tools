* test_fitcount_v231.do - tabtools 2.3.1: tabtools fitcount stores the number
* of people with an event (tt_people_ev, r(people_ev)), which regtab reads
* through stats(e(tt_people_ev)="label")
*
* The oracle counts distinct people() values with an event by egen tag(),
* not by the code under test. The fixture gives most people several events,
* so a count of events or of all people cannot pass.

clear all
set more off
set varabbrev off
version 17.0

capture log close _fc231
log using "test_fitcount_v231.log", replace text name(_fc231)

local test_count = 0
local pass_count = 0
local fail_count = 0

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace
discard
tabtools set clear

**# r(people_ev) and the collected tt_people_ev
local ++test_count
capture noisily {
    sysuse auto, clear
    * Oracle on the same rows: distinct headroom values with foreign == 1.
    egen byte _tg_ev = tag(headroom) if foreign == 1
    quietly count if _tg_ev == 1
    local want_ev = r(N)
    egen byte _tg_all = tag(headroom)
    quietly count if _tg_all == 1
    local want_all = r(N)
    quietly count if foreign == 1
    local want_events = r(N)
    assert `want_ev' == 5 & `want_all' == 8 & `want_events' == 22
    collect clear
    collect: poisson foreign mpg
    tabtools fitcount, events(foreign) people(headroom)
    assert r(people_ev) == `want_ev'
    assert r(people) == `want_all'
    assert r(events) == `want_events'
    regtab, stats(N e(tt_people_ev)="People with an event") noint frame(_fc1, replace)
    assert r(e_tt_people_ev_1) == `want_ev'
}
if _rc == 0 {
    display as result "  PASS: F1 people with an event: r(people_ev) and regtab stats(e(tt_people_ev))"
    local ++pass_count
}
else {
    display as error "  FAIL: F1 people with an event (rc=`=_rc')"
    local ++fail_count
}
capture frame drop _fc1

**# Without people() nothing is stored
local ++test_count
capture noisily {
    sysuse auto, clear
    collect clear
    collect: poisson foreign mpg
    tabtools fitcount, events(foreign)
    assert missing(r(people_ev))
    capture regtab, stats(e(tt_people_ev)) noint
    assert _rc == 111
}
if _rc == 0 {
    display as result "  PASS: F2 no people(): no tt_people_ev, regtab refuses r(111)"
    local ++pass_count
}
else {
    display as error "  FAIL: F2 no people() (rc=`=_rc')"
    local ++fail_count
}

**# Summary
display as result "RESULT: test_fitcount_v231 tests=`test_count' pass=`pass_count' fail=`fail_count'"
log close _fc231
if `fail_count' > 0 exit 1
