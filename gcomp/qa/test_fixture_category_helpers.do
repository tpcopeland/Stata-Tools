*! test_fixture_category_helpers.do 2026/09/30
*! Author: Timothy P Copeland, Karolinska Institutet
*! Reviewed canonical boundary controls; intentional e/r/RNG publication scoped separately.
version 16.0
clear all
set processors 1
set varabbrev on
capture log close _all
local qa_dir "`c(pwd)'"
do "`qa_dir'/_qa_bootstrap.do"
do "`qa_dir'/_qa_fx_a3.do"
do "`qa_dir'/_qa_state.do"
local tests 0
local pass 0
local fail 0
foreach route in continuous mixed base ts hex stage_random stage_random_error {
 local ++tests
 capture noisily {
  qa_fx_a3_traj, clear n(1200) k(3) model(poisson) seed(9251)
  sort id period
  set seed 9252
  recast double aux
  replace aux=rnormal()
  generate double other=rnormal()
  if "`route'"=="continuous" {
   quietly poisson y c.aux#c.other if period==2
   replace aux=aux+100 if period==0
   replace other=other-100 if period==0
  }
  if "`route'"=="mixed" quietly poisson y i.group#c.aux if period==2 & group!=3
  if "`route'"=="base" quietly poisson y ib1.group c.aux#c.other if period==2
  if "`route'"=="ts" {
   quietly xtset id period
   quietly poisson y L.i.group if period==2
  }
  if inlist("`route'","hex","stage_random","stage_random_error") quietly regress y group aux if period==2
  local drawif "period==0"
  if "`route'"=="ts" local drawif "period==1"
  local expected=cond(inlist("`route'","mixed","hex","stage_random_error"),198,0)
  if "`route'"=="hex" {
   generate double code=cond(_n==1,.1,.10000000000001)
   quietly levelsof code, hexadecimal local(levels)
   replace code=.10000000000002 in 2
  }
  qa_state_snapshot, tag(helper) rreturn predict(xb stdp)
  if inlist("`route'","continuous","mixed","base","ts") {
   capture noisily _gcomp_check_fit_levels, drawif("`drawif'") context("native helper `route'")
  }
  if "`route'"=="hex" capture noisily _gcomp_check_categorical code, levels("`levels'") context("hex identity")
  if "`route'"=="stage_random" capture noisily _gcomp_check_interventions, categorical(group) rules(group=1+(runiform()>.5)) context("supported stochastic expression")
  if "`route'"=="stage_random_error" capture noisily _gcomp_check_interventions, categorical(group) rules(group=4+(runiform()>.5)) context("unsupported stochastic expression")
  local rc=_rc
  display "NATIVE_HELPER_BOUNDARY `route' actualrc=`rc' expectedrc=`expected'"
  qa_state_compare, tag(helper)
  assert `rc'==`expected'
 }
 if !_rc {
  local ++pass
  display "PASS: `route' helper domain/state"
 }
 else {
  local ++fail
  display "FAIL: `route' helper domain/state (rc=`=_rc')"
 }
}
if `fail'>0 {
    display "RESULT: test_fixture_category_helpers tests=`tests' pass=`pass' fail=`fail' status=FAIL"
    capture log close _all
    exit 1
}
else {
    display "RESULT: test_fixture_category_helpers tests=`tests' pass=`pass' fail=`fail' status=PASS"
    capture log close _all
}
