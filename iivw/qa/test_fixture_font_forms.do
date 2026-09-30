*! test_fixture_font_forms.do — canonical reporting font/decimal payload checks
*! Author: Timothy P Copeland, Karolinska Institutet
version 16.0
clear all
set more off
set varabbrev off
local qa_dir "`c(pwd)'"
do _iivw_qa_common.do
iivw_qa_bootstrap
do _qa_fx_a3.do
do _qa_state.do
do _iivw_fixture_excel.do
global QAFONT_OPAQUE_BYTE EXPANSION_RED

local tests=0
local pass=0
local fail=0
qa_fx_a3_visit, clear tier(unit) n(100) seed(931)
_fx_visit_excel friendly deep
local tests=`tests'+r(tests)
local pass=`pass'+r(pass)
local fail=`fail'+r(fail)
* expect: EXACT
qa_fx_a3_visit, clear tier(unit) n(100) seed(931) perturb(unsorted)
_fx_visit_excel unsorted deep
local tests=`tests'+r(tests)
local pass=`pass'+r(pass)
local fail=`fail'+r(fail)
display "RESULT: test_fixture_font_forms tests=`tests' pass=`pass' fail=`fail' skip=0"
macro drop QAFONT_OPAQUE_BYTE
iivw_qa_sandbox_restore
if `fail'>0 exit 1
