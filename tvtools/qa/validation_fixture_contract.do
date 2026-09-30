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
local tests=0
local pass=0
local fail=0

**# Inclusive-day exposure tiling and panel; half-open fixture is adapted exactly
foreach op in friendly overlap abut open_end unsorted dup_key boundary_values {
    foreach route in expose ever former panel build {
        local ++tests
        capture noisily {
            if "`op'"=="friendly" qa_fx_a4_spells, clear tier(micro)
            else {
                * expect: EXACT
                qa_fx_a4_spells, clear tier(micro) perturb(`op')
            }
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
                tvbuild, sourceusing(`episodes') id(id) entry(entry) exit(exit) start(start) stop(stop) exposure(category) reference(0) generate(got) frameout(fx_built)
                frame change fx_built
            }
            else {
                local opts "priority(1 2)"
                if "`route'"=="ever" local opts "evertreated"
                if "`route'"=="former" local opts "currentformer"
                tvexpose using `episodes', id(id) start(start) stop(stop) exposure(category) reference(0) entry(entry) exit(exit) generate(got) `opts'
                assert r(total_time)==16
            }
            expand stop-start+1
            bysort id start: gen double day=start+_n-1
            sort id day
            assert _N==16
            forvalues i=1/16 {
                assert id[`i']==`W'[`i',1] & day[`i']==`W'[`i',2] & got[`i']==`W'[`i',3]
            }
            if "`route'"=="panel" {
                by id (day): gen double c1=sum(inlist(`P'[8*(id-1)+_n,3],1,-1))
                by id (day): gen double c2=sum(inlist(`P'[8*(id-1)+_n,3],2,-1))
                assert cum_1==c1 & cum_2==c2
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
}
**# Exact day splitting; age uses calendar birthdays, not365.25 approximation
foreach op in friendly unsorted boundary_values {
    foreach route in elapsed age calendar split {
        local ++tests
        capture noisily {
            if "`op'"=="friendly" qa_fx_a4_spells, clear tier(micro)
            else {
                * expect: EXACT
                qa_fx_a4_spells, clear tier(micro) perturb(`op')
            }
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
            gen double duration=hi-lo+1
            bysort id: egen double total=total(duration)
            assert total==8
            assert r(n_persons)==2
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
}
di "RESULT: validation_fixture_contract tests=`tests' pass=`pass' fail=`fail' skip=0"
log close _all
if `fail'>0 exit 1
