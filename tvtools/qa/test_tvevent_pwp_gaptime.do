*! test_tvevent_pwp_gaptime.do
*! PWP gap-time clock of tvevent/tvbuild, gaptime: the documented PWP-GT
*! stset declaration keeps every event (entry-day and consecutive-day events
*! included), the default names do not collide with stset's _t0/_t, and the
*! clock is time since the previous event on the closed-day grid
*! (Prentice, Williams & Peterson 1981, sec. 2): a row [start, stop] in a
*! stratum whose previous event (or entry) ends at origin - 1 is the gap
*! interval (start - origin, stop - origin + 1].
*! Author: Timothy P Copeland, Karolinska Institutet
version 16.0
clear all
set more off
capture log close _all
quietly log using "test_tvevent_pwp_gaptime.log", replace text nomsg
do "`c(pwd)'/_tvtools_qa_common.do"
_tvtools_qa_bootstrap
local tests = 0
local pass = 0
local fail = 0

* Fixture: person 1 has an event on the entry day (100); person 2 has events
* on consecutive days (150, 151); person 3 has an observation gap
* (121-130 unobserved) and events on 110 and 140; person 4 has no event.
clear
input long id double(start stop)
1 100 200
2 100 200
3 100 120
3 131 160
4 100 200
end
tempfile iv
save `iv'
clear
input long id double(hosp1 hosp2)
1 100 .
2 150 151
3 110 140
4 . .
end
tempfile evdata
save `evdata'

* Hand oracle: (id start stop event stratum gapstart gapstop)
clear
input long id double(start stop) byte(ev_h k_h) double(g0_h g1_h)
1 100 100 1 1  0   1
1 101 200 0 2  0 100
2 100 150 1 1  0  51
2 151 151 1 2  0   1
2 152 200 0 3  0  49
3 100 110 1 1  0  11
3 111 120 0 2  0  10
3 131 140 1 2 20  30
3 141 160 0 3  0  20
4 100 200 0 1  0 101
end
tempfile oracle
save `oracle'

**# Documented PWP-GT recipe keeps every event
* The tvevent.sthlp recipe, verbatim with the help example's names: egen the
* person-stratum id, then stset gapstop, time0(gapstart). Before the fix the
* clock ended entry-day and consecutive-day rows at 0, stset excluded them
* ("end on or before enter()"), and only 3 of 5 events survived.
local ++tests
capture noisily {
    use `evdata', clear
    tvevent using `iv', id(id) date(hosp) type(recurring) generate(ev) ///
        enum(k) gaptime gapstart(gap0) gapstop(gap1)
    quietly count if ev == 1
    assert r(N) == 5
    egen long id_stratum = group(id k)
    stset gap1, id(id_stratum) failure(ev) time0(gap0)
    * every row is in the analysis sample and every event is a failure
    assert _st == 1
    quietly count if _d == 1
    assert r(N) == 5
    assert _d == (ev == 1)
    * gap-time at risk equals the closed-day person-time of each row
    assert _t - _t0 == stop - start + 1
}
if _rc == 0 local ++pass
else {
    local ++fail
    display as error "FAIL: PWP-GT recipe event retention"
}

**# Gap clock matches the hand oracle row for row
local ++tests
capture noisily {
    use `evdata', clear
    tvevent using `iv', id(id) date(hosp) type(recurring) generate(ev) ///
        enum(k) gaptime gapstart(g0) gapstop(g1)
    merge 1:1 id start stop using `oracle'
    assert _merge == 3
    assert ev == ev_h
    assert k == k_h
    assert g0 == g0_h
    assert g1 == g1_h
    * the clock restarts at 0 on the first row of every stratum
    bysort id (start): assert g0 == 0 if _n == 1 | k != k[_n-1]
}
if _rc == 0 local ++pass
else {
    local ++fail
    display as error "FAIL: gap clock hand oracle"
}

**# Stratum-1 gap stop equals closed-day timegen()
* Both clocks measure elapsed closed days from entry in stratum 1.
local ++tests
capture noisily {
    use `evdata', clear
    tvevent using `iv', id(id) date(hosp) type(recurring) generate(ev) ///
        enum(k) gaptime timegen(tt) timeunit(days)
    assert _gapstop == tt if k == 1
}
if _rc == 0 local ++pass
else {
    local ++fail
    display as error "FAIL: stratum-1 gap stop vs timegen"
}

**# Default names avoid stset's _t0/_t and declare directly
* Before the fix the defaults were _t0/_t, and stset _t, time0(...) exited
* with r(110) "variable _t already defined".
local ++tests
capture noisily {
    use `evdata', clear
    tvevent using `iv', id(id) date(hosp) type(recurring) generate(ev) ///
        enum(k) gaptime
    assert "`r(gapstart)'" == "_gapstart"
    assert "`r(gapstop)'" == "_gapstop"
    capture confirm variable _t, exact
    assert _rc == 111
    capture confirm variable _t0, exact
    assert _rc == 111
    confirm variable _gapstart _gapstop, exact
    egen long id_stratum = group(id k)
    stset _gapstop, time0(_gapstart) failure(ev) id(id_stratum)
    quietly count if _d == 1
    assert r(N) == 5
}
if _rc == 0 local ++pass
else {
    local ++fail
    display as error "FAIL: default gap names"
}

**# tvbuild gaptime: same defaults, same clock, recipe keeps every event
local ++tests
capture noisily {
    clear
    input long id double(study_entry study_exit)
    1 100 200
    2 100 200
    end
    tempfile cohort
    save `cohort'
    clear
    input long id double(rx_start rx_stop) byte rx
    1 120 130 1
    2 160 170 1
    end
    tempfile episodes
    save `episodes'
    capture frame drop ev_frame
    frame create ev_frame
    frame ev_frame {
        input long id double(ev1 ev2)
        1 100 .
        2 150 151
        end
    }
    capture frame drop analysis
    use `cohort', clear
    tvbuild, sourceusing(`"`episodes'"') id(id) entry(study_entry) ///
        exit(study_exit) start(rx_start) stop(rx_stop) exposure(rx) ///
        reference(0) generate(tv_rx) frameout(analysis) replace nomanifest ///
        eventframe(ev_frame) eventdate(ev) eventtype(recurring) ///
        enum(_enum) gaptime
    local fv "`r(eventvar)'"
    local sv "`r(startvar)'"
    local tv "`r(stopvar)'"
    assert "`r(gapstartvar)'" == "_gapstart"
    assert "`r(gapstopvar)'" == "_gapstop"
    frame change analysis
    quietly count if `fv' == 1
    assert r(N) == 3
    egen long id_stratum = group(id _enum)
    stset _gapstop, time0(_gapstart) failure(`fv') id(id_stratum)
    assert _st == 1
    quietly count if _d == 1
    assert r(N) == 3
    assert _t - _t0 == `tv' - `sv' + 1
    frame change default
    frame drop analysis
    frame drop ev_frame
}
if _rc == 0 local ++pass
else {
    local ++fail
    display as error "FAIL: tvbuild gaptime recipe"
    capture frame change default
}

display "RESULT: test_tvevent_pwp_gaptime tests=`tests' pass=`pass' fail=`fail' skip=0"
capture log close _all
if `fail' exit 1
