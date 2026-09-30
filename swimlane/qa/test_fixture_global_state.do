*! test_fixture_global_state.do -- opaque legacy globals and exact caller preservation
* Timothy P Copeland, Karolinska Institutet
version 16.0
clear all
set processors 1
set more off
set graphics off
capture log close _all
log using "test_fixture_global_state.log",text replace
args source_override
local pkgdir=regexr("`c(pwd)'","/qa$","")
adopath ++ "`pkgdir'"
if `"`source_override'"'!="" adopath ++ `"`source_override'"'
quietly do "_qa_fx_a4.do"
quietly do "_qa_state.do"
local tests=0
local pass=0
local fail=0
foreach initial in missing opaque {
    foreach setting in on off {
        foreach route in success early late {
            local ++tests
            capture noisily {
                if "`route'"=="late" {
                    * expect: REFUSED
                    qa_fx_a4_spells,clear tier(micro) perturb(overlap)
                }
                else qa_fx_a4_spells,clear tier(micro)
                if "`initial'"=="missing" {
                    capture macro drop S_1 S_2
                }
                else {
                    mata: st_global("S_1","caller "+char(96)+"tick'+"+char(36)+"NAME "+char(34)+"quote"+char(34)+char(10)+"line")
                    mata: st_global("S_2","  "+char(96)+char(34)+"compound"+char(34)+char(39)+" "+char(36)+"S_1  ")
                }
                set varabbrev `setting'
                local original_frame "`c(frame)'"
                quietly summarize start,meanonly
                local wanted_mean : display %21x r(mean)
                local wanted_N=r(N)
                quietly levelsof id,local(wanted_ids)
                local wanted_subjects : word count `wanted_ids'
                tempfile refusal
                log using "`refusal'",text replace name(refusal)
                qa_state_snapshot,tag(globals)
                if "`route'"=="success" {
                    capture noisily swimlane, id(id) start(start) stop(stop) state(category) maxids(all) intervalcheck(off) nograph frame(fxglobals,replace)
                }
                else if "`route'"=="early" {
                    capture noisily swimlane, id(id) start(start) nograph
                }
                else {
                    capture noisily swimlane, id(id) start(start) stop(stop) state(category) maxids(all) intervalcheck(error) nograph
                }
                local candidate_rc=_rc
                local candidate_subjects=r(N_subjects)
                local candidate_segments=r(N_segments)
                log close refusal
                if "`route'"=="success" {
                    assert `candidate_rc'==0 & `candidate_subjects'==`wanted_subjects' & `candidate_segments'==_N
                    qa_state_compare,tag(globals) allow(frame)
                    assert "`c(frame)'"=="`original_frame'"
                    frame fxglobals:assert rowtype=="bar" & duration==stop-start & !missing(start,stop)
                    frame drop fxglobals
                }
                else {
                    if "`route'"=="early" {
                        assert `candidate_rc'==198
                        mata: st_local("named",strofreal(any(strpos(cat(st_local("refusal")),"start() requires stop()"))))
                    }
                    else {
                        assert `candidate_rc'==459
                        mata: st_local("named",strofreal(any(strpos(cat(st_local("refusal")),"state intervals contain"))))
                    }
                    assert `named'==1
                    qa_state_compare,tag(globals)
                }
                quietly summarize start,meanonly
                assert r(mean)==`wanted_mean' & r(N)==`wanted_N'
                display "GLOBAL `initial' varabbrev(`setting') `route': rc=`candidate_rc'; opaque globals/non-r caller state and next native summary exact"
            }
            if _rc local ++fail
            else local ++pass
        }
    }
}
display "RESULT: test_fixture_global_state tests=`tests' pass=`pass' fail=`fail' skip=0"
log close
if `fail' exit 9
