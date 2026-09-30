*! test_fixture_names.do — canonical F/U long-name invariance via shared primitive
*! Author: Timothy P Copeland, Karolinska Institutet
version 16.0
clear all
set more off
set varabbrev off
capture log close _all
log using "test_fixture_names.log", replace text nomsg
local qa_dir "`c(pwd)'"
local pkg_dir=regexr("`qa_dir'","/qa$","")
adopath ++ "`pkg_dir'"
do "`qa_dir'/_codescan_qa_common.do"
quietly _codescan_qa_bootstrap
local qa_owner=r(owner)
do "`qa_dir'/_qa_fx_a5.do"
do "`qa_dir'/_qa_state.do"
do "`qa_dir'/_qa_metamorphic.do"
local tests=0
local pass=0
local fail=0
local ++tests
capture noisily {
    qa_fx_a5_wide, clear
    
    * expect: INVARIANT
    qa_metamorphic long_names, command(codescan @var@ dx2-dx4, define(mi I21 | dm E11 | renal N18 | meta C78) id(id) mode(prefix) nocase nodots) returns(var:mi var:dm var:renal var:meta) var(dx1)
}
if _rc==0 local ++pass
else local ++fail
local ++tests
capture noisily {
    qa_fx_a5_wide, clear
    
    * expect: INVARIANT
    qa_metamorphic long_names, command(codescan_describe @var@ dx2-dx4, top(100)) returns(r(n_unique) r(n_entries) r(top_codes)) var(dx1)
}
if _rc==0 local ++pass
else local ++fail
capture graph drop fx_names
_codescan_qa_restore "`qa_owner'"
_codescan_qa_publish "test_fixture_names" `tests' `pass' `fail'
di "RESULT: test_fixture_names tests=`tests' pass=`pass' fail=`fail' skip=0"
log close _all
if `fail'>0 exit 1
