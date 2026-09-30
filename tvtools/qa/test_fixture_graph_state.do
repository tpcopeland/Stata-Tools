*! test_fixture_graph_state.do — cold/native/opaque graph macro boundary controls
*! Author: Timothy P Copeland, Karolinska Institutet
version 16.0
clear all
set more off
set varabbrev off
capture log close _all
log using "test_fixture_graph_state.log", replace text nomsg
local qa_dir "`c(pwd)'"
local pkg_dir=regexr("`qa_dir'","/qa$","")
adopath ++ "`pkg_dir'"
do "`qa_dir'/_qa_fx_a4.do"
do "`qa_dir'/_qa_state.do"
capture program drop _fx_graph_state
program define _fx_graph_state, rclass
    version 16.0
    args op
    replace stop=stop-1
    tempfile input
    save `input'
    local tests=0
    local pass=0
    local fail=0
    foreach status in absent present present_empty native {
        foreach route in success refusal {
            local ++tests
            capture noisily {
                use `input', clear
                capture macro drop T_gm_fix_span
                if "`status'"=="present" mata: st_global("T_gm_fix_span",char(36)+"OPAQUE"+char(34)+char(96)+"native"+char(39))
                if "`status'"=="present_empty" {
                    global T_gm_fix_span ""
                    mata: assert(sum(st_dir("global","macro","*"):=="T_gm_fix_span")==0)
                }
                if "`status'"=="native" {
                    twoway scatter stop start, name(native_before, replace)
                    mata: assert(sum(st_dir("global","macro","*"):=="T_gm_fix_span")==1)
                    mata: assert(st_global("T_gm_fix_span")=="0")
                    graph drop native_before
                }
                qa_state_snapshot, tag(graph_macro)
                if "`route'"=="success" {
                    tvdiagnose, id(id) start(start) stop(stop) exposure(category) swimlane maxids(1)
                    assert r(graph_created)==1 & r(graph_rc)==0 & r(graph_ids_total)==2 & r(graph_ids_plotted)==1 & r(graph_truncated)==1
                    qa_state_compare, tag(graph_macro)
                    graph drop tvd_swimlane
                }
                else {
                    capture noisily tvdiagnose, id(id) start(start) stop(stop) exposure(category) swimlane maxids(0)
                    local call_rc=_rc
                    assert `call_rc'==198
                    qa_state_compare, tag(graph_macro)
                }
                * Next explicit native graph has its own observed semantics:
                * create a graph and set its span flag to0 independently.
                twoway scatter stop start, name(native_after, replace)
                graph dir
                local graphs `"`r(list)'"'
                assert `: list posof "native_after" in graphs'>0
                mata: assert(st_global("T_gm_fix_span")=="0")
                graph drop native_after
                di "ORACLE graph state `op' `status' `route': exact caller bytes/presence and next native graph"
            }
            local rc=_rc
            if `rc'==0 local ++pass
            else {
                local ++fail
                di as error "FAIL graph state `op' `status' `route' rc=`rc'"
            }
        }
    }
    return scalar tests=`tests'
    return scalar pass=`pass'
    return scalar fail=`fail'
end
local tests=0
local pass=0
local fail=0
qa_fx_a4_spells, clear tier(micro)
_fx_graph_state friendly
local tests=`tests'+r(tests)
local pass=`pass'+r(pass)
local fail=`fail'+r(fail)
* expect: EXACT
qa_fx_a4_spells, clear tier(micro) perturb(unsorted)
_fx_graph_state unsorted
local tests=`tests'+r(tests)
local pass=`pass'+r(pass)
local fail=`fail'+r(fail)
di "RESULT: test_fixture_graph_state tests=`tests' pass=`pass' fail=`fail' skip=0"
log close _all
if `fail'>0 exit 1
