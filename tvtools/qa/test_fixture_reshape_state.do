*! test_fixture_reshape_state.do — cold/native/opaque initialization macro boundary controls
*! Author: Timothy P Copeland, Karolinska Institutet
version 16.0
clear all
set more off
set varabbrev off
capture log close _all
log using "test_fixture_reshape_state.log", replace text nomsg
local pkg=regexr("`c(pwd)'","/qa$","")
adopath ++ "`pkg'"
do _qa_fx_a4.do
do _qa_state.do
args strict
if "`strict'"=="" local strict off
mata: mata set matastrict `strict'
* Narrow memory-replacement comparison, as in rangematch's interval oracle:
* only the native filename aliases belong to the intentionally replaced data.
* Every other caller global remains in the exact shared state comparison.
capture mata: mata drop _fx_tv_replacement_diff()
mata:
void _fx_tv_replacement_diff()
{
    pointer(transmorphic scalar) scalar pw, pn
    pw=findexternal("__qa_state_cold_tv")
    pn=findexternal("__qa_statework")
    asarray_remove(*pw,"global|S_FN")
    asarray_remove(*pw,"global|S_FNDATE")
    asarray_remove(*pn,"global|S_FN")
    asarray_remove(*pn,"global|S_FNDATE")
    asarray_remove(*pw,"label|failure_lbl")
    asarray_remove(*pn,"label|failure_lbl")
    _qa_st_diff("__qa_state_cold_tv","__qa_statework","cold_tv","data sort")
}
end
capture program drop _fx_tv_replacement_compare
program define _fx_tv_replacement_compare
    version 16.0
    _qa_st_collect __qa_statework "" "" ""
    mata: _fx_tv_replacement_diff()
    local differences=`ndiff'
    mata: rmexternal("__qa_statework")
    qa_state_drop, tag(cold_tv)
    assert `differences'==0
end
capture program drop _fx_cold_tv
program define _fx_cold_tv, rclass
    version 16.0
    args op
    tempfile episodes cohort events
    quietly summarize start, meanonly
    local origin=r(min)
    replace stop=stop-1
    replace category=1
    keep id start stop category
    save `episodes'
    keep id
    duplicates drop
    generate double entry=`origin'
    generate double exit=entry+10
    format entry exit %td
    save `cohort'
    keep id
    generate double eventdate=`origin'+4
    generate double eventdate1=eventdate
    format eventdate eventdate1 %td
    save `events'
    local pass=0
    local fail=0
    foreach cmd in tvevent tvbuild {
        foreach status in absent present present_empty native {
            foreach route in success refusal {
                capture noisily {
                    if "`cmd'"=="tvevent" use `events', clear
                    else use `cohort', clear
                    capture frame drop fx_cold fx_cold_manifest
                    capture macro drop ReS_Call ReS_jv2 S_1 S_2
                    if "`status'"=="present" {
                        foreach key in ReS_Call ReS_jv2 S_1 S_2 S_FN S_FNDATE {
                            mata: st_global(st_local("key"),char(36)+"OPAQUE"+char(34)+char(96)+"native"+char(39))
                        }
                    }
                    if "`status'"=="absent" capture macro drop S_FN S_FNDATE
                    if "`status'"=="present_empty" {
                        foreach key in ReS_Call ReS_jv2 S_1 S_2 S_FN S_FNDATE {
                            mata: st_global(st_local("key"),"")
                        }
                        mata: assert(sum(st_dir("global","macro","*"):=="ReS_Call")==0)
                    }
                    if "`status'"=="native" {
                        preserve
                        keep id
                        expand 2
                        bysort id: generate byte wave=_n
                        generate double x=wave
                        reshape wide x, i(id) j(wave)
                        mata: assert(st_global("ReS_Call")=="version 16:")
                        restore
                        if "`cmd'"=="tvevent" ttest eventdate==0
                        else ttest entry==0
                        assert $S_1==2
                    }
                    qa_state_snapshot, tag(cold_tv)
                    if "`route'"=="success" {
                        if "`cmd'"=="tvevent" {
                            tvevent using `episodes', id(id) date(eventdate) type(recurring) generate(failure)
                            assert r(N_events)==2
                            assert c(filename)==""
                            mata: assert(st_global("S_FN")=="" & st_global("S_FNDATE")=="")
                            _fx_tv_replacement_compare
                            * Exact owned output schema, dates, sort and label semantics.
                            assert "`: sortedby'"=="id start stop"
                            assert "`: value label failure'"=="failure_lbl"
                            assert "`: label failure_lbl 0'"=="Censored"
                            assert "`: label failure_lbl 1'"=="Event: eventdate"
                            assert !missing(id,start,stop,category,failure) & category==1
                            assert inlist(start-`origin',0,3,6) & inlist(stop-`origin',1,4,7)
                            generate double span=stop-start+1
                            bysort id: egen double total=total(span)
                            assert total==6
                            assert failure==(stop==`origin'+4)
                        }
                        else {
                            tvbuild, id(id) entry(entry) exit(exit) sourceusing(`episodes') start(start) stop(stop) exposure(category) generate(got) reference(0) frameout(fx_cold) eventusing(`events') eventdate(eventdate) eventtype(recurring) eventgenerate(failure)
                            frame fx_cold {
                                generate double span=stop-start+1
                                bysort id: egen double total=total(span)
                                assert total==11
                                assert failure==(stop==`origin'+4)
                                quietly count if failure
                                assert r(N)==2
                            }
                            frame drop fx_cold fx_cold_manifest
                            qa_state_compare, tag(cold_tv)
                        }
                    }
                    else {
                        if "`cmd'"=="tvevent" capture noisily tvevent using `episodes', id(id) date(eventdate) type(bad) generate(failure)
                        else capture noisily tvbuild, id(id) entry(entry) exit(exit) sourceusing(`episodes') start(start) stop(stop) exposure(category) generate(got) reference(0) frameout(fx_cold) eventusing(`events') eventdate(eventdate) eventtype(bad)
                        local call_rc=_rc
                        assert `call_rc'==198
                        qa_state_compare, tag(cold_tv)
                    }
                    * Next native reshape must still perform its actual operation.
                    preserve
                    keep id
                    duplicates drop
                    expand 2
                    bysort id: generate byte wave=_n
                    generate double x=wave
                    reshape wide x, i(id) j(wave)
                    assert x1==1 & x2==2 & _N==2
                    mata: assert(st_global("ReS_Call")=="version 16:")
                    restore
                    use `cohort', clear
                    assert _N==2 & entry==`origin' & exit==`origin'+10
                    assert c(filename)=="`cohort'"
                    mata: assert(st_global("S_FN")==st_local("cohort"))
                    di "ORACLE TV cold reshape `op' `cmd' `status' `route': exact native bytes/presence and next reshape"
                }
                local rc=_rc
                if `rc'==0 local ++pass
                else {
                    local ++fail
                    di as error "FAIL TV cold reshape `op' `cmd' `status' `route' rc=`rc'"
                }
            }
        }
    }
    return scalar tests=16
    return scalar pass=`pass'
    return scalar fail=`fail'
end
local tests=0
local pass=0
local fail=0
qa_fx_a4_spells, clear tier(micro)
_fx_cold_tv friendly
local tests=`tests'+r(tests)
local pass=`pass'+r(pass)
local fail=`fail'+r(fail)
qa_fx_a4_spells, clear tier(micro) perturb(unsorted)
_fx_cold_tv unsorted
local tests=`tests'+r(tests)
local pass=`pass'+r(pass)
local fail=`fail'+r(fail)
di "RESULT: test_fixture_reshape_state tests=`tests' pass=`pass' fail=`fail' skip=0"
log close _all
if `fail'>0 exit 1
