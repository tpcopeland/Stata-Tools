*! test_fixture_routes.do — canonical interval routes and exact public returns
*! Author: Timothy P Copeland, Karolinska Institutet
version 16.0
clear all
set more off
set varabbrev off
capture log close _all
log using "test_fixture_routes.log", replace text nomsg
local qa_dir "`c(pwd)'"
local pkg_dir=regexr("`qa_dir'","/qa$","")
adopath ++ "`pkg_dir'"
do "`qa_dir'/_qa_fx_a4.do"
do "`qa_dir'/_qa_state.do"
program define _fx_tv_routes, rclass
    args op
    tempname P rh
    matrix `P'=r(truth_panel)
    _return hold `rh'
    tempfile source episodes baseline events
    save `source'
    local tests=0
    local pass=0
    local fail=0
    foreach route in catalog diagnose merge spec single recurring {
        local ++tests
        capture noisily {
            use `source', clear
            scalar win=`P'[1,2]
            replace stop=scalar(win)+8 if missing(stop)
            replace stop=stop-1
            replace start=max(start,scalar(win))
            replace stop=min(stop,scalar(win)+7)
            keep if start<=stop
            keep id start stop category
            format start stop %td
            save `episodes', replace
            if "`route'"=="diagnose" {
                gen double entry=scalar(win)
                gen double exit=scalar(win)+7
                quietly summarize stop, meanonly
                gen double raw=stop-start+1
                quietly summarize raw, meanonly
                scalar rawtime=r(sum)
                scalar uniontime=0
                forvalues i=1/16 {
                    if `P'[`i',3]!=0 scalar uniontime=uniontime+1
                }
                tvdiagnose, id(id) start(start) stop(stop) exposure(category) entry(entry) exit(exit) all
                assert r(n_persons)==2
                assert r(total_person_time)==scalar(uniontime)
                assert r(raw_interval_person_time)==scalar(rawtime)
                assert r(overlap_excess_person_time)==scalar(rawtime)-scalar(uniontime)
                assert r(mean_coverage)==100*scalar(uniontime)/16
            }
            else if "`route'"=="catalog" {
                qa_state_snapshot, tag(tv_catalog)
                tvtools, list detail
                qa_state_compare, tag(tv_catalog)
                local cmds `"`r(commands)'"'
                assert r(n_commands)==11
                foreach cmd in tvage tvband tvbuild tvdiagnose tvevent tvexpose tvmerge tvpanel tvspec tvsplit tvweight {
                    assert `: list cmd in cmds'
                }
            }
            else if "`route'"=="spec" {
                tvspec create fx_spec, replace
                frame fx_spec: assert _N==0
                tvspec add fx_spec, name(rx) using(`episodes') start(start) stop(stop) exposure(category) generate(got) reference(0)
                assert r(n_sources)==1 & "`r(source_name)'"=="rx"
                frame fx_spec: assert source_name=="rx" & source_kind=="episodes" & start_var=="start" & stop_var=="stop" & input_vars=="category" & output_vars=="got" & reference==0
                tvspec list fx_spec
                assert r(n_sources)==1 & "`r(source_names)'"=="rx"
                frame drop fx_spec
            }
            else {
                keep id
                duplicates drop
                gen double start=scalar(win)
                gen double stop=scalar(win)+7
                gen byte base=0
                format start stop %td
                save `baseline', replace
                if "`route'"=="merge" {
                    tvmerge "`baseline'" "`episodes'", id(id) start(start start) stop(stop stop) exposure(base category) generate(b0 got) startname(start) stopname(stop)
                    assert r(N_persons)==2 & r(N_datasets)==2
                    expand stop-start+1
                    bysort id start: gen double day=start+_n-1
                    sort id day
                    assert b0==0
                    local selected=0
                    forvalues i=1/16 {
                        if `P'[`i',3]!=0 {
                            local ++selected
                            assert id[`selected']==`P'[`i',1] & day[`selected']==`P'[`i',2] & got[`selected']==`P'[`i',3]
                        }
                    }
                    * tvmerge constructs intersections, as documented; source
                    * gaps are excluded, rather than imputed to zero exposure.
                    assert _N==`selected' 
                }
                else {
                    drop start stop base
                    gen double eventdate=scalar(win)+4
                    format eventdate %td
                    if "`route'"=="recurring" rename eventdate eventdate1
                    tvevent using `baseline', id(id) date(eventdate) type(`route') generate(failure)
                    assert r(N_events)==2
                    assert failure==1 if stop==scalar(win)+4
                    quietly count if failure==1
                    assert r(N)==2
                    gen double duration=stop-start+1
                    bysort id: egen double total=total(duration)
                    assert total==cond("`route'"=="single",5,8)
                    assert stop<=scalar(win)+cond("`route'"=="single",4,7)
                }
            }
        }
        local case_rc=_rc
        capture restore
        capture frame drop fx_spec
        if `case_rc'==0 local ++pass
        else {
            local ++fail
            di as error "FAIL tv route `op' `route' rc=`case_rc'"
        }
    }
    capture _return restore `rh'
    return scalar tests=`tests'
    return scalar pass=`pass'
    return scalar fail=`fail'
end
local tests=0
local pass=0
local fail=0
qa_fx_a4_spells, clear tier(micro)
_fx_tv_routes friendly
local tests=`tests'+r(tests)
local pass=`pass'+r(pass)
local fail=`fail'+r(fail)
* expect: EXACT
qa_fx_a4_spells, clear tier(micro) perturb(unsorted)
_fx_tv_routes unsorted
local tests=`tests'+r(tests)
local pass=`pass'+r(pass)
local fail=`fail'+r(fail)
* expect: EXACT
qa_fx_a4_spells, clear tier(micro) perturb(boundary_values)
_fx_tv_routes boundary_values
local tests=`tests'+r(tests)
local pass=`pass'+r(pass)
local fail=`fail'+r(fail)
di "RESULT: test_fixture_routes tests=`tests' pass=`pass' fail=`fail' skip=0"
log close _all
if `fail'>0 exit 1
