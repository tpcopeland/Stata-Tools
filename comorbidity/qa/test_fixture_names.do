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
tempfile sandbox
capture mkdir "`sandbox'_plus"
capture mkdir "`sandbox'_personal"
sysdir set PLUS "`sandbox'_plus"
sysdir set PERSONAL "`sandbox'_personal"
quietly net install codescan, from("`pkg_dir'/../codescan") replace
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
    qa_metamorphic long_names, command(comorbidity @var@ dx2-dx4, id(id) charlson(original) merge) returns(var:charlson) var(dx1)
}
if _rc==0 local ++pass
else local ++fail
capture graph drop fx_names
di "RESULT: test_fixture_names tests=`tests' pass=`pass' fail=`fail' skip=0"
log close _all
if `fail'>0 exit 1
