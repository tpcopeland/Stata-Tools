*! test_fixture_names.do — canonical F/U long-name invariance via shared primitive
*! Author: Timothy P Copeland, Karolinska Institutet
version 16.0
clear all
set more off
set varabbrev off
local qa_dir "`c(pwd)'"
local pkg_dir=regexr("`qa_dir'","/qa$","")
do "`qa_dir'/_iivw_qa_common.do"
iivw_qa_bootstrap
do "`qa_dir'/_qa_fx_a3.do"
do "`qa_dir'/_qa_state.do"
do "`qa_dir'/_qa_metamorphic.do"
local tests=0
local pass=0
local fail=0
local ++tests
capture noisily {
    qa_fx_a3_visit, clear tier(unit)
    drop if !visit
    * expect: INVARIANT
    qa_metamorphic long_names, command(iivw_fit @var@, unweighted id(id) time(time) timespec(linear) nolog) returns(e(b) e(V) e(N)) var(y)
}
if _rc==0 local ++pass
else local ++fail
capture graph drop fx_names
display "RESULT: test_fixture_names tests=`tests' pass=`pass' fail=`fail' skip=0"
iivw_qa_sandbox_restore
if `fail'>0 exit 1
