*! test_fixture_files.do -- real native graph transport and complete owned-tree bytes
* Timothy P Copeland, Karolinska Institutet
version 16.0
clear all
set processors 1
set more off
set varabbrev off
set graphics off
capture log close _all
log using "test_fixture_files.log",text replace
local pkgdir=regexr("`c(pwd)'","/qa$","")
adopath ++ "`pkgdir'"
quietly do "_qa_fx_a7.do"
quietly do "_qa_state.do"
qa_fx_a7_labelled,clear tier(micro)
quietly raincloud x,nocloud norain name(fxwarm,replace)
graph drop fxwarm
python:
from pathlib import Path
from sfi import Macro
import sys,types
mod=types.ModuleType('_qa_rain_file')
def before():
    root=Path(Macro.getLocal('root'))
    mod.before_state={str(p.relative_to(root)):p.read_bytes() for p in root.rglob('*') if p.is_file()}
def after():
    root=Path(Macro.getLocal('root'))
    target=Path(Macro.getLocal('filename'))
    now={str(p.relative_to(root)):p.read_bytes() for p in root.rglob('*') if p.is_file()}
    assert all(now.get(k)==v for k,v in mod.before_state.items()), 'an original owned artifact changed'
    assert set(now)-set(mod.before_state)=={str(target.relative_to(root))}, 'exactly the requested graph artifact must be added'
    assert len(now[str(target.relative_to(root))])>0
mod.before=before;mod.after=after
sys.modules['_qa_rain_file']=mod
end
capture program drop _qa_rain_writer
program define _qa_rain_writer
    version 16.0
    args root target variant
    mata: st_local("filename",st_local("target")+(st_local("variant")=="path_noext" ? ".gph" : ""))
    python: __import__("_qa_rain_file").before()
    qa_state_snapshot,tag(writer)
    quietly raincloud x,nocloud norain name(fxfile,replace) saving(`"`macval(target)'"',replace)
    qa_state_compare,tag(writer)
    assert r(N)==40 & r(n_groups)==1
    matrix stats=r(stats)
    assert stats[1,1]==40 & stats[1,2]==20.5 & stats[1,3]==sqrt(410/3) & stats[1,4]==20.5 & stats[1,5]==10.5 & stats[1,6]==30.5 & stats[1,7]==20 & missing(stats[1,8])
    graph use `"`macval(filename)'"',name(fxread,replace)
    graph describe fxread
    assert "`r(ft)'"=="live" & "`r(family)'"=="twoway"
    python: __import__("_qa_rain_file").after()
    graph drop fxread fxfile
end
local tests=0
local pass=0
local fail=0
local ++tests
qa_fx_a7_files,clear tier(micro)
local root `"`r(root)'"'
local target `"`r(path_active)'"'
qa_fx_a7_labelled,clear tier(micro)
capture noisily _qa_rain_writer `"`macval(root)'"' `"`macval(target)'"' friendly
local rc=_rc
if `rc' local ++fail
else local ++pass
qa_fx_a7_cleanup,root(`"`macval(root)'"')
local ++tests
* expect: EXACT
qa_fx_a7_files,clear tier(micro) perturb(path_hostile)
local root `"`r(root)'"'
local target `"`r(path_active)'"'
qa_fx_a7_labelled,clear tier(micro)
capture noisily _qa_rain_writer `"`macval(root)'"' `"`macval(target)'"' path_hostile
local rc=_rc
if `rc' local ++fail
else local ++pass
qa_fx_a7_cleanup,root(`"`macval(root)'"')
local ++tests
* expect: EXACT
qa_fx_a7_files,clear tier(micro) perturb(path_noext)
local root `"`r(root)'"'
local target `"`r(path_active)'"'
qa_fx_a7_labelled,clear tier(micro)
capture noisily _qa_rain_writer `"`macval(root)'"' `"`macval(target)'"' path_noext
local rc=_rc
if `rc' local ++fail
else local ++pass
qa_fx_a7_cleanup,root(`"`macval(root)'"')
display "RESULT: test_fixture_files tests=`tests' pass=`pass' fail=`fail' skip=0"
log close
if `fail' exit 9
