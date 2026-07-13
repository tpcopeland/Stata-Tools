*! validation_dgp_known_answers2.do
*! Known-answer DGP validation for tvtools -- companion to
*! validation_dgp_known_answers.do (S1-S20). Every scenario builds data from a
*! generating process whose exact output is derived analytically from the DGP --
*! never from the package -- and asserts recovery. This file exercises the option
*! surfaces the first file did not reach: tvexpose exposure-definition and
*! data-handling options (evertreated, currentformer, lag, washout, grace, dose),
*! tvmerge simultaneous overlap, tvevent event logic (single censoring, competing
*! risks, recurring PWP enum/gaptime, timegen, continuous proration), tvweight
*! estimand identities (ATO/matching balance, saturated ESS, multinomial mean,
*! truncation percentile identity), tvpanel active-class and multi-class
*! cumulative accrual, tvage age clamping, and tvsplit/tvdiagnose extra axes.
*!
*! Every oracle below was confirmed against the documented option semantics in an
*! independent exploration run before being pinned (the "watch it work" step): the
*! numbers are the analytic truth, and the assertions gate the package against
*! drifting away from that truth.
*!
*! Run standalone:  cd tvtools/qa && stata-mp -b do validation_dgp_known_answers2.do

clear all
set varabbrev off
version 16.0

capture log close
log using "validation_dgp_known_answers2.log", replace nomsg

* Bootstrap: sandboxed install from the package root (qa/..).
local qa_dir "`c(pwd)'"
do "`qa_dir'/_tvtools_qa_common.do"
quietly _tvtools_qa_bootstrap

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

* Shared study window used by the tvexpose/tvevent scenarios below.
local Y0 = td(01jan2015)
local Y1 = td(31dec2015)

**# =========================================================================
**# S21: tvexpose evertreated -- monotone switch, stays 1 after first exposure
**# =========================================================================
* DGP: 1 person, study [01jan2015, 31dec2015] (365 days). One episode
* [01apr2015, 30jun2015]. evertreated switches 0 -> 1 at the first exposure and
* NEVER returns to 0, so the exposed window runs 01apr..31dec = 275 days and the
* pre-exposure window is 01jan..31mar = 90 days. Total person-time conserved.
local ++test_count
local t_pass = 1
capture noisily {
    clear
    set obs 1
    gen long id = 1
    gen double study_entry = `Y0'
    gen double study_exit  = `Y1'
    format %td study_entry study_exit
    tempfile coh
    save `coh'
    clear
    set obs 1
    gen long id = 1
    gen double start = td(01apr2015)
    gen double stop  = td(30jun2015)
    gen byte drug = 1
    format %td start stop
    tempfile ep
    save `ep'

    use `coh', clear
    tvexpose using `ep', id(id) start(start) stop(stop) exposure(drug) ///
        reference(0) entry(study_entry) exit(study_exit) evertreated generate(ev)

    gen double pt = stop - start + 1
    quietly summarize pt if ev == 1
    if r(sum) != 275 {
        di as error "  FAIL [S21.ever]: ever-exposed PT=`r(sum)' expected=275"
        local t_pass = 0
    }
    else di as result "  PASS [S21.ever]: ever-exposed PT = 275 (monotone)"

    quietly summarize pt
    if r(sum) != 365 {
        di as error "  FAIL [S21.pt]: total PT=`r(sum)' expected=365"
        local t_pass = 0
    }
    else di as result "  PASS [S21.pt]: total person-time = 365 conserved"

    * Monotone: no exposed row precedes an unexposed row for the same person.
    sort id start
    quietly gen byte back = (ev == 0 & ev[_n-1] == 1) if _n > 1 & id == id[_n-1]
    quietly count if back == 1
    if r(N) != 0 {
        di as error "  FAIL [S21.mono]: `r(N)' reversals to unexposed"
        local t_pass = 0
    }
    else di as result "  PASS [S21.mono]: exposure never reverts to 0"
}
if _rc & `t_pass' {
    di as error "  FAIL [S21.run]: rc=`=_rc'"
    local t_pass = 0
}
if `t_pass' local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' S21"
}

**# =========================================================================
**# S22: tvexpose currentformer -- never/current/former person-time split
**# =========================================================================
* Same DGP as S21. currentformer codes 0=never, 1=current, 2=former. The single
* episode [01apr,30jun] splits follow-up into never=[01jan,31mar]=90 days,
* current=[01apr,30jun]=91 days, former=[01jul,31dec]=184 days. Exact integer
* oracle; total conserved = 365.
local ++test_count
local t_pass = 1
capture noisily {
    clear
    set obs 1
    gen long id = 1
    gen double study_entry = `Y0'
    gen double study_exit  = `Y1'
    format %td study_entry study_exit
    tempfile coh
    save `coh'
    clear
    set obs 1
    gen long id = 1
    gen double start = td(01apr2015)
    gen double stop  = td(30jun2015)
    gen byte drug = 1
    format %td start stop
    tempfile ep
    save `ep'

    use `coh', clear
    tvexpose using `ep', id(id) start(start) stop(stop) exposure(drug) ///
        reference(0) entry(study_entry) exit(study_exit) currentformer generate(cf)

    gen double pt = stop - start + 1
    foreach pair in 0=90 1=91 2=184 {
        local k  : word 1 of `=subinstr("`pair'","="," ",1)'
        local ex : word 2 of `=subinstr("`pair'","="," ",1)'
        quietly summarize pt if cf == `k'
        if r(sum) != `ex' {
            di as error "  FAIL [S22.cf`k']: PT=`r(sum)' expected=`ex'"
            local t_pass = 0
        }
        else di as result "  PASS [S22.cf`k']: state `k' person-time = `ex'"
    }
    quietly summarize pt
    if r(sum) != 365 {
        di as error "  FAIL [S22.pt]: total PT=`r(sum)' expected=365"
        local t_pass = 0
    }
    else di as result "  PASS [S22.pt]: total person-time = 365 conserved"
}
if _rc & `t_pass' {
    di as error "  FAIL [S22.run]: rc=`=_rc'"
    local t_pass = 0
}
if `t_pass' local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' S22"
}

**# =========================================================================
**# S23: tvexpose lag(30) -- exposure onset delayed by 30 days
**# =========================================================================
* Same DGP. lag(30) delays the exposure onset 30 days: the [01apr,30jun] episode
* becomes active only on 01may (01apr+30), so exposed PT = 01may..30jun =
* 31+30 = 61 days. Total conserved = 365.
local ++test_count
local t_pass = 1
capture noisily {
    clear
    set obs 1
    gen long id = 1
    gen double study_entry = `Y0'
    gen double study_exit  = `Y1'
    format %td study_entry study_exit
    tempfile coh
    save `coh'
    clear
    set obs 1
    gen long id = 1
    gen double start = td(01apr2015)
    gen double stop  = td(30jun2015)
    gen byte drug = 1
    format %td start stop
    tempfile ep
    save `ep'

    use `coh', clear
    tvexpose using `ep', id(id) start(start) stop(stop) exposure(drug) ///
        reference(0) entry(study_entry) exit(study_exit) lag(30) generate(lg)

    gen double pt = stop - start + 1
    quietly summarize pt if lg == 1
    if r(sum) != 61 {
        di as error "  FAIL [S23.exp]: lagged exposed PT=`r(sum)' expected=61"
        local t_pass = 0
    }
    else di as result "  PASS [S23.exp]: lagged exposed PT = 61 days"
    quietly summarize pt
    if r(sum) != 365 {
        di as error "  FAIL [S23.pt]: total PT=`r(sum)' expected=365"
        local t_pass = 0
    }
    else di as result "  PASS [S23.pt]: total person-time = 365 conserved"
}
if _rc & `t_pass' {
    di as error "  FAIL [S23.run]: rc=`=_rc'"
    local t_pass = 0
}
if `t_pass' local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' S23"
}

**# =========================================================================
**# S24: tvexpose washout(30) -- exposure persists 30 days past stop
**# =========================================================================
* Same DGP. washout(30) keeps exposure active 30 days after the episode ends:
* [01apr,30jun] extends to 30jul (30jun+30), so exposed PT = 01apr..30jul =
* 91+30 = 121 days. Total conserved = 365.
local ++test_count
local t_pass = 1
capture noisily {
    clear
    set obs 1
    gen long id = 1
    gen double study_entry = `Y0'
    gen double study_exit  = `Y1'
    format %td study_entry study_exit
    tempfile coh
    save `coh'
    clear
    set obs 1
    gen long id = 1
    gen double start = td(01apr2015)
    gen double stop  = td(30jun2015)
    gen byte drug = 1
    format %td start stop
    tempfile ep
    save `ep'

    use `coh', clear
    tvexpose using `ep', id(id) start(start) stop(stop) exposure(drug) ///
        reference(0) entry(study_entry) exit(study_exit) washout(30) generate(wo)

    gen double pt = stop - start + 1
    quietly summarize pt if wo == 1
    if r(sum) != 121 {
        di as error "  FAIL [S24.exp]: washout exposed PT=`r(sum)' expected=121"
        local t_pass = 0
    }
    else di as result "  PASS [S24.exp]: washout exposed PT = 121 days"
    quietly summarize pt
    if r(sum) != 365 {
        di as error "  FAIL [S24.pt]: total PT=`r(sum)' expected=365"
        local t_pass = 0
    }
    else di as result "  PASS [S24.pt]: total person-time = 365 conserved"
}
if _rc & `t_pass' {
    di as error "  FAIL [S24.run]: rc=`=_rc'"
    local t_pass = 0
}
if `t_pass' local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' S24"
}

**# =========================================================================
**# S25: tvexpose grace() -- gap bridged iff gap <= grace
**# =========================================================================
* DGP: two same-type episodes [01apr,30apr] and [01jun,30jun], separated by the
* 31-day gap 01may..31may. grace(31) bridges a gap of <= 31 days, so the two
* episodes merge into one exposed span 01apr..30jun = 91 days. grace(30) leaves
* the 31-day gap open, so the exposed PT is only the two episodes' own days,
* 30+30 = 60. This pins the grace boundary from BOTH sides on one DGP.
local ++test_count
local t_pass = 1
capture noisily {
    clear
    set obs 1
    gen long id = 1
    gen double study_entry = `Y0'
    gen double study_exit  = `Y1'
    format %td study_entry study_exit
    tempfile coh
    save `coh'
    clear
    set obs 2
    gen long id = 1
    gen double start = td(01apr2015) in 1
    replace   start = td(01jun2015) in 2
    gen double stop  = td(30apr2015) in 1
    replace   stop   = td(30jun2015) in 2
    gen byte drug = 1
    format %td start stop
    tempfile ep2
    save `ep2'

    use `coh', clear
    tvexpose using `ep2', id(id) start(start) stop(stop) exposure(drug) ///
        reference(0) entry(study_entry) exit(study_exit) grace(31) generate(g31)
    gen double pt = stop - start + 1
    quietly summarize pt if g31 == 1
    if r(sum) != 91 {
        di as error "  FAIL [S25.merge]: grace(31) exposed PT=`r(sum)' expected=91"
        local t_pass = 0
    }
    else di as result "  PASS [S25.merge]: grace(31) bridges gap -> 91 days"

    use `coh', clear
    tvexpose using `ep2', id(id) start(start) stop(stop) exposure(drug) ///
        reference(0) entry(study_entry) exit(study_exit) grace(30) generate(g30)
    gen double pt = stop - start + 1
    quietly summarize pt if g30 == 1
    if r(sum) != 60 {
        di as error "  FAIL [S25.nomerge]: grace(30) exposed PT=`r(sum)' expected=60"
        local t_pass = 0
    }
    else di as result "  PASS [S25.nomerge]: grace(30) leaves 31-day gap -> 60 days"
}
if _rc & `t_pass' {
    di as error "  FAIL [S25.run]: rc=`=_rc'"
    local t_pass = 0
}
if `t_pass' local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' S25"
}

**# =========================================================================
**# S26: tvexpose dose -- cumulative dose accrues at the daily rate
**# =========================================================================
* DGP: 1 person, study [01jan2015, 31dec2015]. One episode [01apr,30jun] = 91
* days carrying a total dose of 91 units in exposure(ddd), i.e. a daily rate of
* exactly 1 unit/day. Cumulative dose therefore accrues to 91 by the end of the
* episode and holds. The oracle max cumulative dose = 91.
local ++test_count
local t_pass = 1
capture noisily {
    clear
    set obs 1
    gen long id = 1
    gen double study_entry = `Y0'
    gen double study_exit  = `Y1'
    format %td study_entry study_exit
    tempfile coh
    save `coh'
    clear
    set obs 1
    gen long id = 1
    gen double start = td(01apr2015)
    gen double stop  = td(30jun2015)
    gen double ddd = 91
    format %td start stop
    tempfile epd
    save `epd'

    use `coh', clear
    tvexpose using `epd', id(id) start(start) stop(stop) exposure(ddd) ///
        entry(study_entry) exit(study_exit) dose generate(cumddd)

    quietly summarize cumddd
    if abs(r(max) - 91) > 1e-6 {
        di as error "  FAIL [S26.dose]: max cumulative dose=`r(max)' expected=91"
        local t_pass = 0
    }
    else di as result "  PASS [S26.dose]: cumulative dose accrues to 91 (rate 1/day)"

    * Cumulative dose is non-decreasing within person.
    sort id start
    quietly gen byte drop = (cumddd < cumddd[_n-1] - 1e-9) if _n > 1 & id == id[_n-1]
    quietly count if drop == 1
    if r(N) != 0 {
        di as error "  FAIL [S26.mono]: `r(N)' decreases in cumulative dose"
        local t_pass = 0
    }
    else di as result "  PASS [S26.mono]: cumulative dose non-decreasing"
}
if _rc & `t_pass' {
    di as error "  FAIL [S26.run]: rc=`=_rc'"
    local t_pass = 0
}
if `t_pass' local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' S26"
}

**# =========================================================================
**# S27: tvmerge simultaneous overlap -- both-exposed lattice cell
**# =========================================================================
* Complements S16 (disjoint exposures). DGP: 1 person, two tvexpose-style inputs.
*   A: [01apr,30sep] A=1, [01oct,31dec] A=0   (A-coverage 01apr..31dec)
*   B: [01jan,30jun] B=0, [01jul,31dec] B=1   (B-coverage 01jan..31dec)
* tvmerge intersects on the OVERLAP of the two coverage spans, 01apr..31dec =
* 275 days. Both exposures are on simultaneously over 01jul..30sep = 92 days.
local ++test_count
local t_pass = 1
capture noisily {
    clear
    set obs 2
    gen long id = 1
    gen double start = td(01apr2015) in 1
    replace   start = td(01oct2015) in 2
    gen double stop  = td(30sep2015) in 1
    replace   stop   = td(31dec2015) in 2
    gen byte tv_a = 1 in 1
    replace   tv_a = 0 in 2
    format %td start stop
    tempfile ma
    save `ma'
    clear
    set obs 2
    gen long id = 1
    gen double start = td(01jan2015) in 1
    replace   start = td(01jul2015) in 2
    gen double stop  = td(30jun2015) in 1
    replace   stop   = td(31dec2015) in 2
    gen byte tv_b = 0 in 1
    replace   tv_b = 1 in 2
    format %td start stop
    tempfile mb
    save `mb'

    tvmerge "`ma'" "`mb'", id(id) start(start start) stop(stop stop) ///
        exposure(tv_a tv_b) generate(drug_a drug_b)

    sort id start
    gen double pt = stop - start + 1
    quietly summarize pt
    if r(sum) != 275 {
        di as error "  FAIL [S27.pt]: merged PT=`r(sum)' expected=275 (coverage overlap)"
        local t_pass = 0
    }
    else di as result "  PASS [S27.pt]: merged person-time = 275 (coverage intersection)"

    quietly summarize pt if drug_a == 1 & drug_b == 1
    if r(sum) != 92 {
        di as error "  FAIL [S27.both]: both-exposed PT=`r(sum)' expected=92"
        local t_pass = 0
    }
    else di as result "  PASS [S27.both]: simultaneous A&B exposure = 92 days"

    * No row carries a stop < start (valid lattice).
    quietly count if stop < start
    if r(N) != 0 {
        di as error "  FAIL [S27.valid]: `r(N)' rows with stop < start"
        local t_pass = 0
    }
    else di as result "  PASS [S27.valid]: all merged intervals well-formed"
}
if _rc & `t_pass' {
    di as error "  FAIL [S27.run]: rc=`=_rc'"
    local t_pass = 0
}
if `t_pass' local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' S27"
}

**# =========================================================================
**# S28: tvevent type(single) -- terminal event censors post-event time
**# =========================================================================
* DGP: 1 person, interval [01jan2015, 31dec2015]. One primary event 01jul2015.
* type(single) treats the first event as terminal: it splits the interval at the
* event and DROPS all follow-up after it, leaving person-time 01jan..01jul = 182
* days and exactly 1 flagged event.
local ++test_count
local t_pass = 1
capture noisily {
    clear
    set obs 1
    gen long id = 1
    gen double start = `Y0'
    gen double stop  = `Y1'
    format %td start stop
    tempfile iv
    save `iv'
    clear
    set obs 1
    gen long id = 1
    gen double evdate = td(01jul2015)
    format %td evdate

    tvevent using `iv', id(id) start(start) stop(stop) date(evdate) ///
        generate(fail) type(single)
    local nev = r(N_events)

    gen double pt = stop - start + 1
    quietly summarize pt
    if r(sum) != 182 {
        di as error "  FAIL [S28.pt]: post-censoring PT=`r(sum)' expected=182"
        local t_pass = 0
    }
    else di as result "  PASS [S28.pt]: follow-up censored at event -> 182 days"

    if `nev' != 1 {
        di as error "  FAIL [S28.nev]: N_events=`nev' expected=1"
        local t_pass = 0
    }
    else di as result "  PASS [S28.nev]: 1 event flagged"

    quietly summarize fail
    if r(max) != 1 {
        di as error "  FAIL [S28.code]: max status=`r(max)' expected=1"
        local t_pass = 0
    }
    else di as result "  PASS [S28.code]: primary-event status = 1"
}
if _rc & `t_pass' {
    di as error "  FAIL [S28.run]: rc=`=_rc'"
    local t_pass = 0
}
if `t_pass' local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' S28"
}

**# =========================================================================
**# S29: tvevent competing risk -- earlier competing date wins, status = 2
**# =========================================================================
* DGP: 1 person, interval [01jan2015, 31dec2015]. Primary event 01oct2015 but a
* competing death 01jul2015 occurs EARLIER. tvevent resolves to the earliest
* date, so the effective event is the competing one: status = 2, follow-up ends
* at 01jul (182 days), and the later primary date is never reached.
local ++test_count
local t_pass = 1
capture noisily {
    clear
    set obs 1
    gen long id = 1
    gen double start = `Y0'
    gen double stop  = `Y1'
    format %td start stop
    tempfile iv
    save `iv'
    clear
    set obs 1
    gen long id = 1
    gen double evdate = td(01oct2015)
    gen double death  = td(01jul2015)
    format %td evdate death

    tvevent using `iv', id(id) start(start) stop(stop) date(evdate) ///
        compete(death) generate(fail) type(single)
    local nev = r(N_events)

    gen double pt = stop - start + 1
    quietly summarize pt
    if r(sum) != 182 {
        di as error "  FAIL [S29.pt]: PT=`r(sum)' expected=182 (censored at death)"
        local t_pass = 0
    }
    else di as result "  PASS [S29.pt]: follow-up ends at earlier competing date"

    quietly summarize fail
    if r(max) != 2 {
        di as error "  FAIL [S29.code]: status=`r(max)' expected=2 (competing)"
        local t_pass = 0
    }
    else di as result "  PASS [S29.code]: competing-event status = 2"

    if `nev' != 1 {
        di as error "  FAIL [S29.nev]: N_events=`nev' expected=1"
        local t_pass = 0
    }
    else di as result "  PASS [S29.nev]: 1 (competing) event flagged"
}
if _rc & `t_pass' {
    di as error "  FAIL [S29.run]: rc=`=_rc'"
    local t_pass = 0
}
if `t_pass' local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' S29"
}

**# =========================================================================
**# S30: tvevent recurring PWP -- enum stratum + gap-time clock
**# =========================================================================
* DGP: 1 person, interval [01jan2015, 31dec2015]. Two recurring events (wide
* format) ev1=01apr2015, ev2=01sep2015. type(recurring) retains all person-time
* and splits at each event, giving 3 rows:
*   [01jan,01apr] enum=1  gap t=[0,90]
*   [02apr,01sep] enum=2  gap t=[0,152]
*   [02sep,31dec] enum=3  gap t=[0,120]  (censored tail)
* enum is the PWP stratum (increments after each event); the gap clock resets to
* 0 at each stratum start and its stop equals the elapsed days within stratum.
local ++test_count
local t_pass = 1
capture noisily {
    clear
    set obs 1
    gen long id = 1
    gen double start = `Y0'
    gen double stop  = `Y1'
    format %td start stop
    tempfile iv2
    save `iv2'
    clear
    set obs 1
    gen long id = 1
    gen double ev1 = td(01apr2015)
    gen double ev2 = td(01sep2015)
    format %td ev1 ev2

    tvevent using `iv2', id(id) start(start) stop(stop) date(ev) ///
        generate(fail) type(recurring) enum(seq) gaptime gapstart(t0) gapstop(t1)
    local nev = r(N_events)
    local nobs = r(N)

    if `nobs' != 3 {
        di as error "  FAIL [S30.rows]: N=`nobs' expected=3"
        local t_pass = 0
    }
    else di as result "  PASS [S30.rows]: 3 recurrent-event intervals"

    if `nev' != 2 {
        di as error "  FAIL [S30.nev]: N_events=`nev' expected=2"
        local t_pass = 0
    }
    else di as result "  PASS [S30.nev]: 2 events flagged (no censoring)"

    sort id start
    * enum strata 1,2,3 in order.
    quietly gen byte badseq = (seq != _n)
    quietly count if badseq == 1
    if r(N) != 0 {
        di as error "  FAIL [S30.enum]: enum not 1..3 in order"
        local t_pass = 0
    }
    else di as result "  PASS [S30.enum]: PWP stratum = 1,2,3"

    * Gap clock resets to 0 each stratum and stop = elapsed days within stratum.
    quietly count if t0 != 0
    if r(N) != 0 {
        di as error "  FAIL [S30.t0]: `r(N)' rows with gap-start != 0"
        local t_pass = 0
    }
    else di as result "  PASS [S30.t0]: gap-time start resets to 0"

    if t1[1] != 90 | t1[2] != 152 | t1[3] != 120 {
        di as error "  FAIL [S30.t1]: gap stops [`=t1[1]',`=t1[2]',`=t1[3]'] expected [90,152,120]"
        local t_pass = 0
    }
    else di as result "  PASS [S30.t1]: gap-time stops = 90,152,120"

    * Total person-time is retained (recurring does not censor): 365.
    gen double pt = stop - start + 1
    quietly summarize pt
    if r(sum) != 365 {
        di as error "  FAIL [S30.pt]: total PT=`r(sum)' expected=365"
        local t_pass = 0
    }
    else di as result "  PASS [S30.pt]: person-time = 365 retained"
}
if _rc & `t_pass' {
    di as error "  FAIL [S30.run]: rc=`=_rc'"
    local t_pass = 0
}
if `t_pass' local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' S30"
}

**# =========================================================================
**# S31: tvevent timegen -- elapsed time from study entry to interval stop
**# =========================================================================
* DGP: 1 person, interval [01jan2015, 31dec2015], primary event 01jul2015,
* type(single). After censoring, the single retained row is [01jan,01jul];
* timegen(days) = stop - first_start = 01jul - 01jan = 181 elapsed days.
local ++test_count
local t_pass = 1
capture noisily {
    clear
    set obs 1
    gen long id = 1
    gen double start = `Y0'
    gen double stop  = `Y1'
    format %td start stop
    tempfile iv
    save `iv'
    clear
    set obs 1
    gen long id = 1
    gen double evdate = td(01jul2015)
    format %td evdate

    tvevent using `iv', id(id) start(start) stop(stop) date(evdate) ///
        generate(fail) type(single) timegen(tt) timeunit(days)

    sort id start
    if tt[_N] != 181 {
        di as error "  FAIL [S31.tg]: timegen=`=tt[_N]' expected=181"
        local t_pass = 0
    }
    else di as result "  PASS [S31.tg]: elapsed time = 181 days (stop - entry)"
}
if _rc & `t_pass' {
    di as error "  FAIL [S31.run]: rc=`=_rc'"
    local t_pass = 0
}
if `t_pass' local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' S31"
}

**# =========================================================================
**# S32: tvevent continuous() -- proportional split preserves the total
**# =========================================================================
* DGP: 1 person, interval [01jan2015, 31dec2015] carrying a cumulative-exposure
* variable = 365 (a rate of 1 unit/day over the interval). A recurring event
* 01jul2015 splits the interval into two rows; continuous() re-allocates the 365
* by the new/old duration ratio, so the two rows' values SUM back to 365 exactly
* (conservation) while each is strictly between 0 and 365 (a genuine split).
local ++test_count
local t_pass = 1
capture noisily {
    clear
    set obs 1
    gen long id = 1
    gen double start = `Y0'
    gen double stop  = `Y1'
    gen double cumexp = 365
    format %td start stop
    tempfile ivc
    save `ivc'
    clear
    set obs 1
    gen long id = 1
    gen double ev1 = td(01jul2015)
    format %td ev1

    tvevent using `ivc', id(id) start(start) stop(stop) date(ev) ///
        generate(fail) type(recurring) continuous(cumexp)
    local nobs = r(N)

    if `nobs' != 2 {
        di as error "  FAIL [S32.rows]: N=`nobs' expected=2 (event split)"
        local t_pass = 0
    }
    else di as result "  PASS [S32.rows]: interval split into 2 rows at event"

    quietly summarize cumexp
    if abs(r(sum) - 365) > 1e-4 {
        di as error "  FAIL [S32.sum]: sum continuous=`r(sum)' expected=365"
        local t_pass = 0
    }
    else di as result "  PASS [S32.sum]: proportional split conserves total = 365"

    quietly count if cumexp <= 0 | cumexp >= 365
    if r(N) != 0 {
        di as error "  FAIL [S32.split]: `r(N)' rows not strictly between 0 and 365"
        local t_pass = 0
    }
    else di as result "  PASS [S32.split]: each split share in (0,365)"
}
if _rc & `t_pass' {
    di as error "  FAIL [S32.run]: rc=`=_rc'"
    local t_pass = 0
}
if `t_pass' local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' S32"
}

**# =========================================================================
**# S33: tvweight wtype(ato) -- overlap weights balance the confounder exactly
**# =========================================================================
* DGP identical to S18 (saturated single binary confounder x, N=4000, cells with
* P(A=1|x=0)=0.30 and P(A=1|x=1)=0.80). With a logistic (here saturated) PS,
* overlap (ATO) weights yield EXACTLY zero weighted SMD: the weighted mean of x
* is identical across arms (Li, Morgan & Zaslavsky 2018). This is an analytic
* property of the estimand, independent of the fitting code.
local ++test_count
local t_pass = 1
capture noisily {
    clear
    set obs 4000
    gen byte x = _n > 3000
    gen byte a = 0
    replace a = 1 if x == 0 & _n <= 900
    replace a = 1 if x == 1 & _n <= 3800

    tvweight a, covariates(x) generate(w_ato) wtype(ato) nolog

    quietly summarize x [aweight=w_ato] if a == 1, meanonly
    local e1 = r(mean)
    quietly summarize x [aweight=w_ato] if a == 0, meanonly
    local e0 = r(mean)
    if abs(`e1' - `e0') > 1e-6 {
        di as error "  FAIL [S33.balance]: ATO arms differ (`e1' vs `e0')"
        local t_pass = 0
    }
    else di as result "  PASS [S33.balance]: ATO weighted E[x] equal across arms"
}
if _rc & `t_pass' {
    di as error "  FAIL [S33.run]: rc=`=_rc'"
    local t_pass = 0
}
if `t_pass' local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' S33"
}

**# =========================================================================
**# S34: tvweight wtype(matching) -- matched pseudo-population size is analytic
**# =========================================================================
* Same saturated DGP. Matching weight = min(e,1-e)/P(observed treatment). Per
* cell the total matching weight is:
*   x=0 (e=0.30): 900 treated * (0.3/0.3=1) + 2100 untreated * (0.3/0.7)
*   x=1 (e=0.80): 800 treated * (0.2/0.8=0.25) + 200 untreated * (0.2/0.2=1)
* Sum = 900 + 2100*(3/7) + 200 + 200 = 2200 exactly. Matching weights also
* balance the confounder across arms (weighted E[x] equal).
local ++test_count
local t_pass = 1
capture noisily {
    clear
    set obs 4000
    gen byte x = _n > 3000
    gen byte a = 0
    replace a = 1 if x == 0 & _n <= 900
    replace a = 1 if x == 1 & _n <= 3800
    local anal = 900*1 + 2100*(0.3/0.7) + 800*0.25 + 200*1

    tvweight a, covariates(x) generate(w_m) wtype(matching) nolog

    quietly summarize w_m
    if abs(r(sum) - `anal') > 1e-3 {
        di as error "  FAIL [S34.sum]: matched size=`r(sum)' expected=`anal'"
        local t_pass = 0
    }
    else di as result "  PASS [S34.sum]: matched pseudo-population = 2200 (analytic)"

    quietly summarize x [aweight=w_m] if a == 1, meanonly
    local m1 = r(mean)
    quietly summarize x [aweight=w_m] if a == 0, meanonly
    local m0 = r(mean)
    if abs(`m1' - `m0') > 1e-6 {
        di as error "  FAIL [S34.balance]: matching arms differ (`m1' vs `m0')"
        local t_pass = 0
    }
    else di as result "  PASS [S34.balance]: matching weighted E[x] equal across arms"
}
if _rc & `t_pass' {
    di as error "  FAIL [S34.run]: rc=`=_rc'"
    local t_pass = 0
}
if `t_pass' local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' S34"
}

**# =========================================================================
**# S35: tvweight stabilized ESS -- effective sample size matches the DGP
**# =========================================================================
* Same saturated DGP. Because the PS is a saturated cell mean, the stabilized
* weights are known EXACTLY per cell (marginal P(A=1)=1700/4000=0.425):
*   x=0: treated 900*(.425/.30), untreated 2100*(.575/.70)
*   x=1: treated 800*(.425/.80), untreated  200*(.575/.20)
* ESS = (sum w)^2 / sum w^2, computed here from those analytic weights, must
* equal r(ess). Also sum(stabilized w) = N = 4000. Independent of the fitter.
local ++test_count
local t_pass = 1
capture noisily {
    clear
    set obs 4000
    gen byte x = _n > 3000
    gen byte a = 0
    replace a = 1 if x == 0 & _n <= 900
    replace a = 1 if x == 1 & _n <= 3800

    * Analytic stabilized weights from the saturated cell propensities.
    local sumw  = 900*(0.425/0.30) + 2100*(0.575/0.70) + 800*(0.425/0.80) + 200*(0.575/0.20)
    local sumw2 = 900*(0.425/0.30)^2 + 2100*(0.575/0.70)^2 + 800*(0.425/0.80)^2 + 200*(0.575/0.20)^2
    local ess_anal = (`sumw')^2 / `sumw2'

    tvweight a, covariates(x) generate(sw) stabilized nolog
    local ess_pkg = r(ess)
    local wmean   = r(w_mean)

    if abs(`ess_pkg' - `ess_anal') > 0.5 {
        di as error "  FAIL [S35.ess]: r(ess)=`ess_pkg' analytic=`ess_anal'"
        local t_pass = 0
    }
    else di as result "  PASS [S35.ess]: ESS matches analytic (`ess_pkg' ~ `ess_anal')"

    * Stabilized weights sum to N (mean 1) to machine precision.
    if abs(`wmean' - 1) > 1e-5 {
        di as error "  FAIL [S35.mean]: mean stabilized=`wmean' expected=1"
        local t_pass = 0
    }
    else di as result "  PASS [S35.mean]: mean stabilized weight = 1"
}
if _rc & `t_pass' {
    di as error "  FAIL [S35.run]: rc=`=_rc'"
    local t_pass = 0
}
if `t_pass' local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' S35"
}

**# =========================================================================
**# S36: tvweight multinomial IPTW -- mean unstabilized weight = #levels
**# =========================================================================
* DGP: 3-level treatment a in {0,1,2}, saturated on a binary confounder x
* (N=6000). For a saturated multinomial PS the predicted P(A=a|x) equals the
* cell proportion, so within each x-cell the weights 1/P sum to n*K (K=3 levels):
* Sum_a n_a * (1/p_a) = n*(p0/p0 + p1/p1 + p2/p2) = n*3. Hence the overall mean
* unstabilized multinomial weight = K = 3, generalizing S18's binary "mean = 2".
local ++test_count
local t_pass = 1
capture noisily {
    clear
    set obs 6000
    gen byte x = .
    replace x = 0 in 1/3000
    replace x = 1 in 3001/6000
    gen byte a = .
    replace a = 0 if x == 0 & _n <= 1500
    replace a = 1 if x == 0 & _n >  1500 & _n <= 2400
    replace a = 2 if x == 0 & _n >  2400 & _n <= 3000
    replace a = 0 if x == 1 & _n >  3000 & _n <= 4000
    replace a = 1 if x == 1 & _n >  4000 & _n <= 5000
    replace a = 2 if x == 1 & _n >  5000

    tvweight a, covariates(x) generate(mw) nolog
    local wmean = r(w_mean)
    local nlev  = r(n_levels)

    if abs(`wmean' - 3) > 1e-4 {
        di as error "  FAIL [S36.mean]: mean multinomial weight=`wmean' expected=3"
        local t_pass = 0
    }
    else di as result "  PASS [S36.mean]: mean unstabilized weight = 3 = #levels"

    if `nlev' != 3 {
        di as error "  FAIL [S36.lev]: n_levels=`nlev' expected=3"
        local t_pass = 0
    }
    else di as result "  PASS [S36.lev]: 3 exposure levels detected"
}
if _rc & `t_pass' {
    di as error "  FAIL [S36.run]: rc=`=_rc'"
    local t_pass = 0
}
if `t_pass' local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' S36"
}

**# =========================================================================
**# S37: tvweight truncate() -- percentile-clamp identity + exact trim count
**# =========================================================================
* DGP: continuous confounder x ~ N(0,1), N=10000, so the fitted weights are all
* distinct. truncate(1 99) is defined to clamp weights at the 1st and 99th
* percentiles, so after truncation the new maximum EQUALS the untruncated 99th
* percentile and the new minimum EQUALS the untruncated 1st percentile (an exact
* identity), and exactly 2% * 10000 = 200 rows are trimmed. Seeded for
* reproducibility.
local ++test_count
local t_pass = 1
capture noisily {
    clear
    set obs 10000
    set seed 777
    gen double x = rnormal()
    gen byte a = runiform() < invlogit(0.5*x)

    tvweight a, covariates(x) generate(w0) nolog
    local p1  = r(w_p1)
    local p99 = r(w_p99)

    tvweight a, covariates(x) generate(w1) truncate(1 99) nolog
    local wmin = r(w_min)
    local wmax = r(w_max)
    local ntr  = r(n_truncated)

    if abs(`wmax' - `p99') > 1e-6 {
        di as error "  FAIL [S37.hi]: post max=`wmax' != untrunc p99=`p99'"
        local t_pass = 0
    }
    else di as result "  PASS [S37.hi]: truncated max == untruncated 99th pctile"

    if abs(`wmin' - `p1') > 1e-6 {
        di as error "  FAIL [S37.lo]: post min=`wmin' != untrunc p1=`p1'"
        local t_pass = 0
    }
    else di as result "  PASS [S37.lo]: truncated min == untruncated 1st pctile"

    if `ntr' != 200 {
        di as error "  FAIL [S37.n]: n_truncated=`ntr' expected=200 (2% of 10000)"
        local t_pass = 0
    }
    else di as result "  PASS [S37.n]: exactly 200 rows truncated"
}
if _rc & `t_pass' {
    di as error "  FAIL [S37.run]: rc=`=_rc'"
    local t_pass = 0
}
if `t_pass' local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' S37"
}

**# =========================================================================
**# S38: tvpanel active class -- latest covering episode at each period start
**# =========================================================================
* DGP: 1 person, entry 01jan2015, exit +364 (365 days), width 91 -> periods 0..4.
* One class-2 episode [entry+100, entry+200]. The active class at a period start
* is the covering episode (else reference 0). Period starts fall at entry+91*k =
* {0,91,182,273,364}; only period 2's start (entry+182) lies inside [100,200], so
* the active-class vector is exactly [0,0,2,0,0].
local ++test_count
local t_pass = 1
capture noisily {
    clear
    set obs 1
    gen long id = 1
    gen double entry = `Y0'
    gen double exit  = `Y0' + 364
    format %td entry exit
    tempfile mstr
    save `mstr'
    clear
    set obs 1
    gen long id = 1
    gen double estart = `Y0' + 100
    gen double estop  = `Y0' + 200
    gen byte eclass = 2
    format %td estart estop
    tempfile pep
    save `pep'

    use `mstr', clear
    tvpanel using `pep', id(id) entry(entry) exit(exit) exposure(eclass) ///
        start(estart) stop(estop) width(91) generate(cls) period(per)

    sort id per
    if _N != 5 {
        di as error "  FAIL [S38.rows]: `=_N' periods expected 5"
        local t_pass = 0
    }
    else di as result "  PASS [S38.rows]: 5 fixed-width periods"

    local ok = 1
    foreach pk in 0=0 1=0 2=2 3=0 4=0 {
        local p  : word 1 of `=subinstr("`pk'","="," ",1)'
        local ec : word 2 of `=subinstr("`pk'","="," ",1)'
        quietly summarize cls if per == `p', meanonly
        if r(mean) != `ec' local ok = 0
    }
    if !`ok' {
        di as error "  FAIL [S38.class]: active-class vector != [0,0,2,0,0]"
        local t_pass = 0
    }
    else di as result "  PASS [S38.class]: active class = [0,0,2,0,0]"
}
if _rc & `t_pass' {
    di as error "  FAIL [S38.run]: rc=`=_rc'"
    local t_pass = 0
}
if `t_pass' local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' S38"
}

**# =========================================================================
**# S39: tvpanel cumulative(days) -- per-class accrual strictly before period
**# =========================================================================
* DGP: 1 person, entry 01jan2015, exit +364, width 91. Two episodes:
*   class 1 [entry+10, entry+40]  = 31 days
*   class 2 [entry+120, entry+150] = 31 days
* cumulative(days) reports, per class, exposure accrued STRICTLY before each
* period start (entry+91*k). class-1 (ends +40) is fully in the past by period 1
* start (+91); class-2 (ends +150) is fully in the past by period 2 start (+182).
* Oracle: cum_1 = [0,31,31,31,31], cum_2 = [0,0,31,31,31].
local ++test_count
local t_pass = 1
capture noisily {
    clear
    set obs 1
    gen long id = 1
    gen double entry = `Y0'
    gen double exit  = `Y0' + 364
    format %td entry exit
    tempfile mstr
    save `mstr'
    clear
    set obs 2
    gen long id = 1
    gen double estart = `Y0'+10  in 1
    replace   estart = `Y0'+120 in 2
    gen double estop  = `Y0'+40  in 1
    replace   estop   = `Y0'+150 in 2
    gen byte eclass = 1 in 1
    replace   eclass = 2 in 2
    format %td estart estop
    tempfile pep2
    save `pep2'

    use `mstr', clear
    tvpanel using `pep2', id(id) entry(entry) exit(exit) exposure(eclass) ///
        start(estart) stop(estop) width(91) generate(cls) period(per) cumulative(days)

    sort id per
    local ok1 = 1
    local ok2 = 1
    foreach pk in 0=0 1=31 2=31 3=31 4=31 {
        local p  : word 1 of `=subinstr("`pk'","="," ",1)'
        local v  : word 2 of `=subinstr("`pk'","="," ",1)'
        quietly summarize cum_1 if per == `p', meanonly
        if r(mean) != `v' local ok1 = 0
    }
    foreach pk in 0=0 1=0 2=31 3=31 4=31 {
        local p  : word 1 of `=subinstr("`pk'","="," ",1)'
        local v  : word 2 of `=subinstr("`pk'","="," ",1)'
        quietly summarize cum_2 if per == `p', meanonly
        if r(mean) != `v' local ok2 = 0
    }
    if !`ok1' {
        di as error "  FAIL [S39.c1]: cum_1 != [0,31,31,31,31]"
        local t_pass = 0
    }
    else di as result "  PASS [S39.c1]: cum_1 accrual = [0,31,31,31,31]"
    if !`ok2' {
        di as error "  FAIL [S39.c2]: cum_2 != [0,0,31,31,31]"
        local t_pass = 0
    }
    else di as result "  PASS [S39.c2]: cum_2 accrual = [0,0,31,31,31]"
}
if _rc & `t_pass' {
    di as error "  FAIL [S39.run]: rc=`=_rc'"
    local t_pass = 0
}
if `t_pass' local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' S39"
}

**# =========================================================================
**# S40: tvage minage/maxage -- age axis clamped to the requested window
**# =========================================================================
* DGP: dob 15jun1970, entry 01mar2003 (age ~32), exit 31dec2013 (age ~43).
* minage(35) maxage(40) clamps the emitted continuous age bands to [35,40], so
* the output contains exactly the 6 integer ages 35,36,37,38,39,40 and none
* outside that window.
local ++test_count
local t_pass = 1
capture noisily {
    clear
    set obs 1
    gen long id = 1
    gen double dob   = td(15jun1970)
    gen double entry = td(01mar2003)
    gen double exit  = td(31dec2013)
    format %td dob entry exit

    tvage, id(id) dob(dob) entry(entry) exit(exit) generate(age) ///
        startgen(a_start) stopgen(a_stop) minage(35) maxage(40)

    quietly summarize age
    if r(min) != 35 | r(max) != 40 {
        di as error "  FAIL [S40.range]: age range [`r(min)',`r(max)'] expected [35,40]"
        local t_pass = 0
    }
    else di as result "  PASS [S40.range]: age clamped to [35,40]"

    quietly count
    if r(N) != 6 {
        di as error "  FAIL [S40.rows]: `r(N)' bands expected 6"
        local t_pass = 0
    }
    else di as result "  PASS [S40.rows]: 6 integer age bands"

    quietly count if age < 35 | age > 40
    if r(N) != 0 {
        di as error "  FAIL [S40.out]: `r(N)' bands outside [35,40]"
        local t_pass = 0
    }
    else di as result "  PASS [S40.out]: no bands outside the window"
}
if _rc & `t_pass' {
    di as error "  FAIL [S40.run]: rc=`=_rc'"
    local t_pass = 0
}
if `t_pass' local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' S40"
}

**# =========================================================================
**# S41: tvsplit elapsed(day) single axis -- exact band count + conservation
**# =========================================================================
* DGP: 1 person, interval [BASE, BASE+99] (100 days), single elapsed-day axis
* from BASE with width 30. Bands b0..b3 (floor(99/30)=3), i.e. [0,29],[30,59],
* [60,89],[90,99] -> 4 rows, n_axes=1. Person-time conserved = 100 and intervals
* abut with no gaps/overlaps.
local ++test_count
local t_pass = 1
capture noisily {
    clear
    set obs 1
    gen long id = 1
    gen double start  = `Y0'
    gen double stop   = `Y0' + 99
    gen double origin = `Y0'
    format %td start stop origin

    tvsplit, id(id) start(start) stop(stop) elapsed(origin, width(30) unit(day))
    local nax = r(n_axes)

    quietly count
    if r(N) != 4 {
        di as error "  FAIL [S41.rows]: `r(N)' bands expected 4"
        local t_pass = 0
    }
    else di as result "  PASS [S41.rows]: 4 elapsed-day bands"

    if `nax' != 1 {
        di as error "  FAIL [S41.axes]: n_axes=`nax' expected 1"
        local t_pass = 0
    }
    else di as result "  PASS [S41.axes]: single split axis"

    gen double pt = stop - start + 1
    quietly summarize pt
    if r(sum) != 100 {
        di as error "  FAIL [S41.pt]: PT=`r(sum)' expected=100"
        local t_pass = 0
    }
    else di as result "  PASS [S41.pt]: person-time = 100 conserved"

    sort id start
    quietly gen byte bad = (start != stop[_n-1] + 1) if _n > 1 & id == id[_n-1]
    quietly count if bad == 1
    if r(N) != 0 {
        di as error "  FAIL [S41.abut]: `r(N)' non-abutting joins"
        local t_pass = 0
    }
    else di as result "  PASS [S41.abut]: bands abut, no gaps/overlaps"
}
if _rc & `t_pass' {
    di as error "  FAIL [S41.run]: rc=`=_rc'"
    local t_pass = 0
}
if `t_pass' local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' S41"
}

**# =========================================================================
**# S42: tvsplit three simultaneous axes -- n_axes=3, coverage invariants
**# =========================================================================
* DGP: 1 person, dob 15jun1975, interval [01mar2015, 01aug2016]. Exact cuts are
* 15jun2015 and 15jun2016 (age), 01jan2016 (calendar), and 01mar2016 (elapsed),
* yielding five cells while conserving 520 days.
local ++test_count
local t_pass = 1
capture noisily {
    clear
    set obs 1
    gen long id = 1
    gen double dob    = td(15jun1975)
    gen double start  = td(01mar2015)
    gen double stop   = td(01aug2016)
    gen double origin = td(01mar2015)
    format %td dob start stop origin
    local exp_pt = td(01aug2016) - td(01mar2015) + 1

    tvsplit, id(id) start(start) stop(stop) age(dob, width(1)) ///
        calendar(, width(1)) elapsed(origin, width(1) unit(year))
    local nax = r(n_axes)

    if `nax' != 3 {
        di as error "  FAIL [S42.axes]: n_axes=`nax' expected 3"
        local t_pass = 0
    }
    else di as result "  PASS [S42.axes]: n_axes = 3"

    gen double pt = stop - start + 1
    quietly summarize pt
    if r(sum) != `exp_pt' {
        di as error "  FAIL [S42.pt]: PT=`r(sum)' expected=`exp_pt'"
        local t_pass = 0
    }
    else di as result "  PASS [S42.pt]: person-time = `exp_pt' conserved"

    sort id start
    quietly gen byte bad = (start != stop[_n-1] + 1) if _n > 1 & id == id[_n-1]
    quietly count if bad == 1
    if r(N) != 0 {
        di as error "  FAIL [S42.cover]: `r(N)' non-abutting joins"
        local t_pass = 0
    }
    else di as result "  PASS [S42.cover]: full coverage, no gaps/overlaps"

    if _N != 5 {
        di as error "  FAIL [S42.cells]: cells=`=_N', expected 5 exact cells"
        local t_pass = 0
    }
    else di as result "  PASS [S42.cells]: 5 exact Lexis cells"
}
if _rc & `t_pass' {
    di as error "  FAIL [S42.run]: rc=`=_rc'"
    local t_pass = 0
}
if `t_pass' local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' S42"
}

**# =========================================================================
**# S43: tvdiagnose overlaps -- three mutually overlapping periods
**# =========================================================================
* DGP: 1 person, three periods [0,49],[30,79],[60,99] (offsets from BASE). The
* consecutive pairs (1,2) and (2,3) each overlap (start <= prior stop), so there
* are exactly 2 overlapping periods, affecting 1 person.
local ++test_count
local t_pass = 1
capture noisily {
    clear
    input long id double(start stop)
        1 0 49
        1 30 79
        1 60 99
    end
    replace start = start + `Y0'
    replace stop  = stop  + `Y0'
    format %td start stop

    tvdiagnose, id(id) start(start) stop(stop) overlaps

    if r(n_overlaps) != 2 {
        di as error "  FAIL [S43.n]: n_overlaps=`r(n_overlaps)' expected=2"
        local t_pass = 0
    }
    else di as result "  PASS [S43.n]: 2 overlapping periods"
    if r(n_ids_affected) != 1 {
        di as error "  FAIL [S43.ids]: n_ids_affected=`r(n_ids_affected)' expected=1"
        local t_pass = 0
    }
    else di as result "  PASS [S43.ids]: 1 ID affected"
}
if _rc & `t_pass' {
    di as error "  FAIL [S43.run]: rc=`=_rc'"
    local t_pass = 0
}
if `t_pass' local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' S43"
}

**# =========================================================================
**# S44: tvdiagnose gaps -- large-gap threshold is EXCLUSIVE at the boundary
**# =========================================================================
* Regression guard for the threshold boundary. DGP: 1 person, periods [0,9] and
* [40,49] -> a gap over days 10..39 = exactly 30 days. With threshold(30), a
* "large" gap must EXCEED 30, so n_large_gaps must be 0 (not 1). n_gaps=1,
* mean_gap=max_gap=30. A regression to a >= comparison would flag this gap.
local ++test_count
local t_pass = 1
capture noisily {
    clear
    input long id double(start stop)
        1 0 9
        1 40 49
    end
    replace start = start + `Y0'
    replace stop  = stop  + `Y0'
    format %td start stop

    tvdiagnose, id(id) start(start) stop(stop) gaps threshold(30)

    if r(n_gaps) != 1 {
        di as error "  FAIL [S44.n]: n_gaps=`r(n_gaps)' expected=1"
        local t_pass = 0
    }
    else di as result "  PASS [S44.n]: 1 gap"
    if r(max_gap) != 30 {
        di as error "  FAIL [S44.max]: max_gap=`r(max_gap)' expected=30"
        local t_pass = 0
    }
    else di as result "  PASS [S44.max]: gap = 30 days"
    if r(n_large_gaps) != 0 {
        di as error "  FAIL [S44.large]: n_large_gaps=`r(n_large_gaps)' expected=0 (exclusive)"
        local t_pass = 0
    }
    else di as result "  PASS [S44.large]: 30-day gap does NOT exceed threshold(30)"
}
if _rc & `t_pass' {
    di as error "  FAIL [S44.run]: rc=`=_rc'"
    local t_pass = 0
}
if `t_pass' local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' S44"
}

**# =========================================================================
**# S45: tvexpose exposed/unexposed person-time returns match the DGP
**# =========================================================================
* DGP: 1 person, study [01jan2015, 31dec2015] (365 days). One episode
* [01apr2015, 30jun2015] = 91 exposed days. tvexpose's stored results must
* reconcile with the DGP exactly: r(exposed_time)=91, r(unexposed_time)=274,
* r(total_time)=365, r(pct_exposed)=91/365*100, and r(N_persons)=1. This gates
* the returned summary scalars against the person-time they describe.
local ++test_count
local t_pass = 1
capture noisily {
    clear
    set obs 1
    gen long id = 1
    gen double study_entry = `Y0'
    gen double study_exit  = `Y1'
    format %td study_entry study_exit
    tempfile coh
    save `coh'
    clear
    set obs 1
    gen long id = 1
    gen double start = td(01apr2015)
    gen double stop  = td(30jun2015)
    gen byte drug = 1
    format %td start stop
    tempfile ep
    save `ep'

    use `coh', clear
    tvexpose using `ep', id(id) start(start) stop(stop) exposure(drug) ///
        reference(0) entry(study_entry) exit(study_exit) generate(tv_drug)
    local rexp = r(exposed_time)
    local rune = r(unexposed_time)
    local rtot = r(total_time)
    local rpct = r(pct_exposed)
    local rnp  = r(N_persons)

    if `rexp' != 91 {
        di as error "  FAIL [S45.exp]: r(exposed_time)=`rexp' expected=91"
        local t_pass = 0
    }
    else di as result "  PASS [S45.exp]: r(exposed_time) = 91"
    if `rune' != 274 {
        di as error "  FAIL [S45.une]: r(unexposed_time)=`rune' expected=274"
        local t_pass = 0
    }
    else di as result "  PASS [S45.une]: r(unexposed_time) = 274"
    if `rtot' != 365 {
        di as error "  FAIL [S45.tot]: r(total_time)=`rtot' expected=365"
        local t_pass = 0
    }
    else di as result "  PASS [S45.tot]: r(total_time) = 365"
    if abs(`rpct' - 91/365*100) > 1e-4 {
        di as error "  FAIL [S45.pct]: r(pct_exposed)=`rpct' expected=`=91/365*100'"
        local t_pass = 0
    }
    else di as result "  PASS [S45.pct]: r(pct_exposed) = 91/365"
    if `rnp' != 1 {
        di as error "  FAIL [S45.np]: r(N_persons)=`rnp' expected=1"
        local t_pass = 0
    }
    else di as result "  PASS [S45.np]: r(N_persons) = 1"
}
if _rc & `t_pass' {
    di as error "  FAIL [S45.run]: rc=`=_rc'"
    local t_pass = 0
}
if `t_pass' local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' S45"
}

**# =========================================================================
**# Summary
**# =========================================================================
display _newline as result "validation_dgp_known_answers2: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "FAILED SCENARIOS:`failed_tests'"
    display "RESULT: validation_dgp_known_answers2 tests=`test_count' pass=`pass_count' fail=`fail_count'"
    log close
    exit 1
}
display as result "ALL KNOWN-ANSWER DGP SCENARIOS PASSED"
display "RESULT: validation_dgp_known_answers2 tests=`test_count' pass=`pass_count' fail=`fail_count'"
log close
