*! validation_fixture_calendar.do — explicit A4 cohort calendar routes
*! Author: Timothy P Copeland, Karolinska Institutet
version 16.0
clear all
set more off
set varabbrev off
capture log close _all
log using "validation_fixture_calendar.log", replace text nomsg
local qa_dir "`c(pwd)'"
local pkg_dir=regexr("`qa_dir'","/qa$","")
adopath ++ "`pkg_dir'"
do "`qa_dir'/_qa_fx_a4.do"
do "`qa_dir'/_qa_state.do"
do "`qa_dir'/_qa_metamorphic.do"
capture program drop _fx_calprep
program define _fx_calprep
    version 16.0
    args source win op
    use `source', clear
    keep id
    duplicates drop
    generate double entry=`win'
    generate double exit=entry+7
    generate double dob=mdy(2,28,2000)
    generate double origin=entry
    format entry exit dob origin %td
    if "`op'"=="unsorted" {
        gsort -id
        assert id[1]==2 & id[_N]==1
    }
end
capture program drop _fx_caloracle
program define _fx_caloracle
    version 16.0
    args route win
    local persons=r(n_persons)
    assert `persons'==2
    generate double duration=hi-lo+1
    bysort id: egen double total=total(duration)
    assert total==8
    if inlist("`route'","elapsed","split") {
        assert lo==`win'+band & hi==lo
        assert _N==16
    }
    if "`route'"=="calendar" assert band==year(lo) & year(lo)==year(hi)
    if "`route'"=="age" {
        assert band==year(lo)-2000-(lo<mdy(2,28,year(lo)))
        assert band==year(hi)-2000-(hi<mdy(2,28,year(hi)))
    }
end
capture program drop _fx_calendar
program define _fx_calendar, rclass
    version 16.0
    args op
    tempfile source
    tempname win
    scalar `win'=r(truth_window_start)
    quietly save `source'
    local tests=0
    local pass=0
    local fail=0
    local ++tests
    capture noisily {
        _fx_calprep `source' `win' `op'
        qa_state_snapshot, tag(cal_state)
        tvage, id(id) dob(dob) entry(entry) exit(exit) generate(band) startgen(lo) stopgen(hi)
        qa_state_compare, tag(cal_state) allow(data sort label)
        _fx_caloracle age `win'
        di "ORACLE TV age `op': every interval and8days exact"
    }
    if _rc==0 local ++pass
    else {
        local ++fail
        di as error "FAIL TV age `op' rc=`=_rc'"
    }
    local ++tests
    capture noisily {
        _fx_calprep `source' `win' `op'
        qa_state_snapshot, tag(cal_state)
        tvband, id(id) start(entry) stop(exit) type(calendar) width(1) generate(band) startgen(lo) stopgen(hi)
        qa_state_compare, tag(cal_state) allow(data sort label)
        _fx_caloracle calendar `win'
        di "ORACLE TV calendar `op': every interval and8days exact"
    }
    if _rc==0 local ++pass
    else {
        local ++fail
        di as error "FAIL TV calendar `op' rc=`=_rc'"
    }
    local ++tests
    capture noisily {
        _fx_calprep `source' `win' `op'
        qa_state_snapshot, tag(cal_state)
        tvband, id(id) start(entry) stop(exit) type(elapsed) origin(origin) width(1) unit(day) generate(band) startgen(lo) stopgen(hi)
        qa_state_compare, tag(cal_state) allow(data sort label)
        _fx_caloracle elapsed `win'
        di "ORACLE TV elapsed `op': every interval and8days exact"
    }
    if _rc==0 local ++pass
    else {
        local ++fail
        di as error "FAIL TV elapsed `op' rc=`=_rc'"
    }
    local ++tests
    capture noisily {
        _fx_calprep `source' `win' `op'
        rename entry lo
        rename exit hi
        qa_state_snapshot, tag(cal_state)
        tvsplit, id(id) start(lo) stop(hi) elapsed(origin, width(1) unit(day) generate(band))
        qa_state_compare, tag(cal_state) allow(data sort label)
        _fx_caloracle split `win'
        di "ORACLE TV split `op': every interval and8days exact"
    }
    if _rc==0 local ++pass
    else {
        local ++fail
        di as error "FAIL TV split `op' rc=`=_rc'"
    }
    local ++tests
    capture noisily {
        _fx_calprep `source' `win' `op'
        * expect: EXACT
        qa_option_domain, command(tvage, id(id) dob(dob) entry(entry) exit(exit) generate(band) startgen(lo) stopgen(hi) groupwidth(@v@)) inside(1;50) outside(0;51)
    }
    if _rc==0 local ++pass
    else local ++fail
    local ++tests
    capture noisily {
        _fx_calprep `source' `win' `op'
        * expect: EXACT
        qa_option_domain, command(tvband, id(id) start(entry) stop(exit) type(calendar) width(@v@) generate(band) startgen(lo) stopgen(hi)) inside(1;2) outside(0;0.5)
    }
    if _rc==0 local ++pass
    else local ++fail
    local ++tests
    capture noisily {
        _fx_calprep `source' `win' `op'
        * expect: EXACT
        qa_option_domain, command(tvband, id(id) start(entry) stop(exit) type(elapsed) origin(origin) width(1) unit(@v@) generate(band) startgen(lo) stopgen(hi)) inside(day;year) outside(bad)
    }
    if _rc==0 local ++pass
    else local ++fail
    return scalar tests=`tests'
    return scalar pass=`pass'
    return scalar fail=`fail'
end
local tests=0
local pass=0
local fail=0
qa_fx_a4_spells, clear tier(micro)
_fx_calendar friendly
local tests=`tests'+r(tests)
local pass=`pass'+r(pass)
local fail=`fail'+r(fail)
* expect: EXACT
qa_fx_a4_spells, clear tier(micro) perturb(unsorted)
_fx_calendar unsorted
local tests=`tests'+r(tests)
local pass=`pass'+r(pass)
local fail=`fail'+r(fail)
* expect: EXACT
qa_fx_a4_spells, clear tier(micro) perturb(boundary_values)
_fx_calendar boundary_values
local tests=`tests'+r(tests)
local pass=`pass'+r(pass)
local fail=`fail'+r(fail)
di "RESULT: validation_fixture_calendar tests=`tests' pass=`pass' fail=`fail' skip=0"
log close _all
if `fail'>0 exit 1
