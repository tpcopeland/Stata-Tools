clear all
set varabbrev off
version 16.0

capture log close
log using "`c(tmpdir)'/validation_cdp_roving_exit_`c(processid)'.log", replace nomsg

* validation_cdp_roving_exit.do
* Known-answer coverage for the cdp EVENT-LEVEL exit() censoring branch
* (cdp.ado ~443-453), which is DISTINCT code from the one-row-per-person exit
* path and was previously untested: no suite combined roving + allevents +
* exit(). This verifies that a post-exit CDP event is censored at the event
* level (its date wiped, its eventvar 0), earlier events are retained, and the
* recomputed r(N_events)/r(N_persons)/r(N_censored_exit) reflect the censoring.
*
* Oracle (two roving progressions for one person; two-tier, confirmdays 180):
*   baseline 1.0 @2010-01-01
*   event1: EDSS 2.0 @2010-07-01 (+1.0), confirmed by 2.0 @2011-01-15
*   rebaseline to 2.0
*   event2: EDSS 3.0 @2012-01-01 (+1.0), confirmed by 3.0 @2012-07-15
* Run from setools/qa:
*   stata-mp -b do validation_cdp_roving_exit.do

local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
do "`qa_dir'/_setools_qa_common.do" setup "`pkg_dir'"

capture program drop runval
program define runval
    args name result
    scalar gs_ntest = scalar(gs_ntest) + 1
    if `result' {
        display as result "  PASS: `name'"
        scalar gs_npass = scalar(gs_npass) + 1
    }
    else {
        display as error "  FAIL: `name'"
        scalar gs_nfail = scalar(gs_nfail) + 1
    }
end
scalar gs_ntest = 0
scalar gs_npass = 0
scalar gs_nfail = 0

**# Build the two-progression trajectory
clear
input id edss str10 dstr
1 1.0 "2010-01-01"
1 2.0 "2010-07-01"
1 2.0 "2011-01-15"
1 3.0 "2012-01-01"
1 3.0 "2012-07-15"
end
gen date = daily(dstr, "YMD")
format date %td
gen dx = daily("2010-01-01", "YMD")
format dx %td
drop dstr
tempfile base
save `base'

**# Precondition: roving+allevents finds exactly 2 events (no exit)
use `base', clear
cdp id edss date, dxdate(dx) roving allevents keepall quietly
local ok = (r(N_events) == 2 & r(N_persons) == 1)
runval "precondition: 2 roving events found" `ok'
quietly count if cdp_date == td(01jul2010) & event_num == 1
local ok = (r(N) == 1)
runval "precondition: event1 date == 2010-07-01" `ok'
quietly count if cdp_date == td(01jan2012) & event_num == 2
local ok = (r(N) == 1)
runval "precondition: event2 date == 2012-01-01" `ok'

**# exit() between the two events censors event2 only
use `base', clear
gen exitd = daily("2011-06-01", "YMD")
format exitd %td
cdp id edss date, dxdate(dx) roving allevents keepall quietly ///
    exit(exitd) eventvar(ev)
local ncens = r(N_censored_exit)
local nev   = r(N_events)
local npers = r(N_persons)

local ok = (`ncens' == 1)
runval "r(N_censored_exit) == 1" `ok'
local ok = (`nev' == 1)
runval "r(N_events) recomputed to 1 (event1 only)" `ok'
local ok = (`npers' == 1)
runval "r(N_persons) == 1 (person retains >=1 event)" `ok'

* event1 kept: date intact, eventvar 1
quietly count if event_num == 1 & cdp_date == td(01jul2010) & ev == 1
local ok = (r(N) == 1)
runval "event1 retained (date + ev==1)" `ok'

* event2 censored: date wiped, eventvar 0, ROW retained (event-level layout)
quietly count if event_num == 2 & missing(cdp_date) & ev == 0
local ok = (r(N) == 1)
runval "event2 censored (date wiped, ev==0, row kept)" `ok'

* Both event rows still present (allevents keeps event-level rows)
quietly count if id == 1
local ok = (r(N) == 2)
runval "both event rows retained under allevents+keepall" `ok'

**# Symmetry check: an exit AFTER both events censors nothing
use `base', clear
gen exitd = daily("2020-01-01", "YMD")
format exitd %td
cdp id edss date, dxdate(dx) roving allevents keepall quietly exit(exitd)
local ok = (r(N_events) == 2 & r(N_censored_exit) == 0)
runval "late exit censors nothing (N_events==2)" `ok'

**# Summary
display as text _n "{hline 60}"
display "RESULT: validation_cdp_roving_exit tests=" scalar(gs_ntest) ///
    " pass=" scalar(gs_npass) " fail=" scalar(gs_nfail)
if scalar(gs_nfail) > 0 {
    display as error "SOME TESTS FAILED"
    log close _all
    exit 1
}
display as result "ALL TESTS PASSED"
scalar drop gs_ntest gs_npass gs_nfail
log close _all

do "`qa_dir'/_setools_qa_common.do" teardown
