*! validation_fixture_contract.do — canonical F/U numerical contract for tvtools
*! Author: Timothy P Copeland, Karolinska Institutet
version 16.0
clear all
set more off
set varabbrev off
capture log close _all
log using "validation_fixture_contract.log", replace text nomsg
local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
adopath ++ "`pkg_dir'"
do "`qa_dir'/_qa_fx_a4.do"
do "`qa_dir'/_qa_state.do"
do "`qa_dir'/_qa_metamorphic.do"

capture program drop _fx_tvtools_2
program define _fx_tvtools_2, rclass
    version 16.0
    args op fixtureopts
    tempfile fx_input
    tempname fx_returns
    _return hold `fx_returns'
    quietly save `fx_input'
    local tests=0
    local pass=0
    local fail=0

    foreach route in elapsed age calendar split {
        local ++tests
        capture noisily {
            quietly use `fx_input', clear
                _return restore `fx_returns', hold
            tempname P
            matrix `P'=r(truth_panel)
            keep id
            duplicates drop
            gen double entry=`P'[1,2]
            gen double exit=entry+7
            gen double dob=mdy(2,28,2000)
            gen double origin=entry
            format entry exit dob origin %td
            if "`route'"=="elapsed" tvband, id(id) start(entry) stop(exit) type(elapsed) origin(origin) width(1) unit(day) generate(band) startgen(lo) stopgen(hi)
            if "`route'"=="age" tvage, id(id) dob(dob) entry(entry) exit(exit) generate(band) startgen(lo) stopgen(hi)
            if "`route'"=="calendar" tvband, id(id) start(entry) stop(exit) type(calendar) width(1) generate(band) startgen(lo) stopgen(hi)
            if "`route'"=="split" {
                rename entry lo
                rename exit hi
                tvsplit, id(id) start(lo) stop(hi) elapsed(origin, width(1) unit(day) generate(band))
            }
            local got_persons=r(n_persons)
            gen double duration=hi-lo+1
            bysort id: egen double total=total(duration)
            assert total==8
            assert `got_persons'==2
            if inlist("`route'","elapsed","split") {
                assert lo==`P'[1,2]+band & hi==lo
                assert _N==16
            }
            if "`route'"=="calendar" assert band==year(lo) & year(lo)==year(hi)
            if "`route'"=="age" {
                assert band==year(lo)-2000-(lo<mdy(2,28,year(lo)))
                assert band==year(hi)-2000-(hi<mdy(2,28,year(hi)))
            }
        }
        local case_rc=_rc
        capture restore
        if `case_rc'==0 local ++pass
        else {
            local ++fail
            di as error "FAIL tvtools `op' `route' rc=`case_rc'"
        }
    }

    capture _return restore `fx_returns'
    return scalar qa_tests=`tests'
    return scalar qa_pass=`pass'
    return scalar qa_fail=`fail'
end

capture program drop _fx_tvtools_1
program define _fx_tvtools_1, rclass
    version 16.0
    args op fixtureopts
    tempfile fx_input
    tempname fx_returns
    _return hold `fx_returns'
    quietly save `fx_input'
    
local tests=0
    local pass=0
    local fail=0

    foreach route in expose ever former panel build {
        local ++tests
        capture noisily {
            quietly use `fx_input', clear
                _return restore `fx_returns', hold
            tempname P W
            matrix `P'=r(truth_panel)
            scalar win=real("`: char _dta[qa_truth_window_start]'")
            * Existing exact half-open window is also recoverable from first day.
            scalar win=`P'[1,2]
            replace stop=scalar(win)+8 if missing(stop)
            replace stop=stop-1
            tempfile episodes cohort
            keep id start stop category dose
            format start stop %td
            save `episodes'
            * Brute-force day oracle handles overlap policy separately: priority1
            * for tvexpose/tvbuild; latest-start/larger-value for tvpanel.
            matrix `W'=`P'
            tempname C
            matrix `C'=J(16,2,0)
            forvalues i=1/16 {
                local ident=`P'[`i',1]
                scalar day=`P'[`i',2]
                scalar chosen=0
                scalar recent=-1e30
                scalar ever=0
                scalar before=0
                forvalues j=1/`=_N' {
                    if id[`j']==`ident' {
                        if start[`j']<=scalar(day) scalar ever=1
                        if stop[`j']<scalar(day) scalar before=1
                        if inrange(scalar(day),start[`j'],stop[`j']) {
                            if "`route'"=="panel" {
                                if start[`j']>scalar(recent) | (start[`j']==scalar(recent) & category[`j']>scalar(chosen)) {
                                    scalar chosen=category[`j']
                                    scalar recent=start[`j']
                                }
                            }
                            else if chosen==0 | category[`j']<chosen scalar chosen=category[`j']
                        }
                    }
                }
                if "`route'"=="ever" scalar chosen=scalar(ever)
                if "`route'"=="former" scalar chosen=cond(chosen>0,1,cond(before,2,0))
                matrix `W'[`i',3]=scalar(chosen)
                * Union of each class before the panel start, including days
                * prior to cohort entry; cumulative exposure is lifetime-to-date.
                forvalues cls=1/2 {
                    quietly summarize start if id==`ident', meanonly
                    local firstday=r(min)
                    local lastday=scalar(day)-1
                    if `firstday'<=`lastday' {
                        forvalues d=`firstday'/`lastday' {
                            quietly count if id==`ident' & category==`cls' & inrange(`d',start,stop)
                            if r(N)>0 matrix `C'[`i',`cls']=`C'[`i',`cls']+1
                        }
                    }
                }
            }
            keep id
            duplicates drop
            gen double entry=scalar(win)
            gen double exit=scalar(win)+7
            format entry exit %td
            save `cohort'
            if "`route'"=="panel" {
                tvpanel using `episodes', id(id) entry(entry) exit(exit) start(start) stop(stop) exposure(category) reference(0) width(1) cumulative(days) generate(got)
                assert r(n_observations)==16 & r(n_persons)==2
            }
            else if "`route'"=="build" {
                if inlist("`op'","overlap","dup_key") {
                    * expect: REFUSED
                    qa_option_effect, command(tvbuild, sourceusing(`episodes') id(id) entry(entry) exit(exit) start(start) stop(stop) exposure(category) reference(0) generate(got) frameout(@v@)) values("fx_built") returns("r(N)") refused cause("overlap")
                }
                else tvbuild, sourceusing(`episodes') id(id) entry(entry) exit(exit) start(start) stop(stop) exposure(category) reference(0) generate(got) frameout(fx_built)
                if !inlist("`op'","overlap","dup_key") frame change fx_built
            }
            else {
                local opts "priority(1 2)"
                if "`route'"=="ever" local opts "evertreated"
                if "`route'"=="former" local opts "currentformer"
                tvexpose using `episodes', id(id) start(start) stop(stop) exposure(category) reference(0) entry(entry) exit(exit) generate(got) `opts'
                assert r(total_time)==16
            }
            if !("`route'"=="build" & inlist("`op'","overlap","dup_key")) {
            expand stop-start+1
            bysort id start: gen double day=start+_n-1
            sort id day
            assert _N==16
            forvalues i=1/16 {
                assert id[`i']==`W'[`i',1] & day[`i']==`W'[`i',2] & got[`i']==`W'[`i',3]
            }
            if "`route'"=="panel" {
                forvalues i=1/16 {
                    assert cum_1[`i']==`C'[`i',1] & cum_2[`i']==`C'[`i',2]
                }
            }
            }
        }
        local case_rc=_rc
        capture frame change default
        capture frame drop fx_built
        capture restore
        if `case_rc'==0 local ++pass
        else {
            local ++fail
            di as error "FAIL tvtools `op' `route' rc=`case_rc'"
        }
    }

    capture _return restore `fx_returns'
    return scalar qa_tests=`tests'
    return scalar qa_pass=`pass'
    return scalar qa_fail=`fail'
end

local tests=0
local pass=0
local fail=0

**# Inclusive-day exposure tiling and panel; half-open fixture is adapted exactly
qa_fx_a4_spells, clear tier(micro)
_fx_tvtools_1 friendly ""
local tests=`tests'+r(qa_tests)
local pass=`pass'+r(qa_pass)
local fail=`fail'+r(qa_fail)
* expect: EXACT
qa_fx_a4_spells, clear tier(micro) perturb(overlap)
_fx_tvtools_1 overlap "perturb(overlap)"
local tests=`tests'+r(qa_tests)
local pass=`pass'+r(qa_pass)
local fail=`fail'+r(qa_fail)
* expect: EXACT
qa_fx_a4_spells, clear tier(micro) perturb(abut)
_fx_tvtools_1 abut "perturb(abut)"
local tests=`tests'+r(qa_tests)
local pass=`pass'+r(qa_pass)
local fail=`fail'+r(qa_fail)
* expect: EXACT
qa_fx_a4_spells, clear tier(micro) perturb(open_end)
_fx_tvtools_1 open_end "perturb(open_end)"
local tests=`tests'+r(qa_tests)
local pass=`pass'+r(qa_pass)
local fail=`fail'+r(qa_fail)
* expect: EXACT
qa_fx_a4_spells, clear tier(micro) perturb(unsorted)
_fx_tvtools_1 unsorted "perturb(unsorted)"
local tests=`tests'+r(qa_tests)
local pass=`pass'+r(qa_pass)
local fail=`fail'+r(qa_fail)
* expect: EXACT
qa_fx_a4_spells, clear tier(micro) perturb(dup_key)
_fx_tvtools_1 dup_key "perturb(dup_key)"
local tests=`tests'+r(qa_tests)
local pass=`pass'+r(qa_pass)
local fail=`fail'+r(qa_fail)
* expect: EXACT
qa_fx_a4_spells, clear tier(micro) perturb(boundary_values)
_fx_tvtools_1 boundary_values "perturb(boundary_values)"
local tests=`tests'+r(qa_tests)
local pass=`pass'+r(qa_pass)
local fail=`fail'+r(qa_fail)
**# Exact day splitting; age uses calendar birthdays, not365.25 approximation
qa_fx_a4_spells, clear tier(micro)
_fx_tvtools_2 friendly ""
local tests=`tests'+r(qa_tests)
local pass=`pass'+r(qa_pass)
local fail=`fail'+r(qa_fail)
* expect: EXACT
qa_fx_a4_spells, clear tier(micro) perturb(unsorted)
_fx_tvtools_2 unsorted "perturb(unsorted)"
local tests=`tests'+r(qa_tests)
local pass=`pass'+r(qa_pass)
local fail=`fail'+r(qa_fail)
* expect: EXACT
qa_fx_a4_spells, clear tier(micro) perturb(boundary_values)
_fx_tvtools_2 boundary_values "perturb(boundary_values)"
local tests=`tests'+r(qa_tests)
local pass=`pass'+r(qa_pass)
local fail=`fail'+r(qa_fail)
di "RESULT: validation_fixture_contract tests=`tests' pass=`pass' fail=`fail' skip=0"
log close _all
if `fail'>0 exit 1
