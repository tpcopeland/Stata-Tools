*! test_fixture_global_state.do -- actual native KDE globals, opaque caller state and named errors
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
quietly do "_qa_fx_a7.do"
quietly do "_qa_state.do"
qa_fx_a7_labelled,clear tier(micro)
quietly raincloud x,nocloud norain name(fxwarm,replace)
graph drop fxwarm
python:
from pathlib import Path
from sfi import Macro
import sys,types
state=types.ModuleType('_qa_rain_global_file')
def before():
    sys.modules['_qa_rain_global_file'].old_bytes=Path(Macro.getLocal('graph_path')).read_bytes()
def after():
    assert Path(Macro.getLocal('graph_path')).read_bytes()==sys.modules['_qa_rain_global_file'].old_bytes
state.before=before;state.after=after
sys.modules['_qa_rain_global_file']=state
end
local tests=0
local pass=0
local fail=0
foreach initial in missing opaque {
    foreach setting in on off {
        foreach route in success early late {
            local ++tests
            capture noisily {
                qa_fx_a7_labelled,clear tier(micro)
                tempfile refusal oldgraph
                local graph_path "`oldgraph'.gph"
                quietly twoway scatter x id,name(fxold,replace) saving("`graph_path'",replace)
                quietly checksum "`graph_path'"
                local old_crc : display %21x r(checksum)
                local old_size : display %21x r(filelen)
                python: __import__("_qa_rain_global_file").before()
                foreach j in 1 2 3 4 {
                    if "`initial'"=="missing" {
                        capture macro drop S_`j'
                    }
                    else {
                        mata: st_global("S_"+st_local("j"),"caller"+st_local("j")+" "+char(96)+"tick' "+char(36)+"S_1 "+char(34)+char(39)+" literal"+char(10)+"line")
                    }
                }
                mata: st_global("S_5","OUTSIDE "+char(96)+"token "+char(36)+"NAME")
                set varabbrev `setting'
                capture log close refusal
                log using "`refusal'",text replace name(refusal)
                qa_state_snapshot,tag(legacy)
                if "`route'"=="success" {
                    capture noisily raincloud x,seed(1701) name(fxcaller,replace)
                    local candidate_rc=_rc
                    local candidate_N=r(N)
                }
                else if "`route'"=="early" {
                    * expect: REFUSED
                    capture noisily raincloud x,jitter(-1)
                    local candidate_rc=_rc
                }
                else {
                    * expect: REFUSED
                    capture noisily raincloud x,seed(1701) saving("`graph_path'") name(fxcaller,replace)
                    local candidate_rc=_rc
                    local candidate_N=r(N)
                }
                capture noisily qa_state_compare,tag(legacy)
                local fp_rc=_rc
                if "`route'"!="early" matrix stats=r(stats)
                log close refusal
                if "`route'"=="success" {
                    assert `candidate_rc'==0 & `candidate_N'==40
                }
                else {
                    if "`route'"=="early" {
                        assert `candidate_rc'==198
                        mata: st_local("named",strofreal(any(strpos(cat(st_local("refusal")),"jitter() must be between 0 and 1"))))
                    }
                    else {
                        assert `candidate_rc'==602 & `candidate_N'==40
                        mata: st_local("named",strofreal(any(strpos(strlower(cat(st_local("refusal"))),"already exists"))))
                    }
                    assert `named'==1
                }
                if "`route'"!="early" {
                    assert stats[1,1]==40 & stats[1,2]==20.5 & stats[1,3]==sqrt(410/3) & stats[1,4]==20.5 & stats[1,5]==10.5 & stats[1,6]==30.5 & stats[1,7]==20
                    assert abs(stats[1,8]-.9*min(sqrt(410/3),20/1.349)*40^(-1/5))<1e-12
                }
                assert `fp_rc'==0
                python: __import__("_qa_rain_global_file").after()
                quietly checksum "`graph_path'"
                assert r(checksum)==`old_crc' & r(filelen)==`old_size'
                quietly summarize x,meanonly
                assert r(N)==40 & r(mean)==20.5 & r(min)==1 & r(max)==40
                erase "`graph_path'"
                capture graph drop fxcaller
                graph drop fxold
                display "LEGACY `initial' varabbrev(`setting') `route': rc=`candidate_rc'; original S_1..S_4/S_5/data/settings/RNG retained; old graph bytes and next native summary exact"
            }
            if _rc local ++fail
            else local ++pass
        }
    }
}
display "RESULT: test_fixture_global_state tests=`tests' pass=`pass' fail=`fail' skip=0"
log close
if `fail' exit 9
