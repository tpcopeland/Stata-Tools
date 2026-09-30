*! test_fixture_intervention_numeric.do 2026/09/30
*! Author: Timothy P Copeland, Karolinska Institutet
*! S1/S3 canonical A3TRAJ rules vs unchanged native replacement and exact class means.
*! Deferred S4: e(interventions) literal macro-byte transport; no metadata-byte assertion here.
version 16.0
clear all
set processors 1
set more off
capture log close _all
local qa_dir "`c(pwd)'"
log using "`qa_dir'/test_fixture_intervention_numeric.log",replace text name(main)
do "`qa_dir'/_qa_bootstrap.do"
do "`qa_dir'/_qa_fx_a3.do"
do "`qa_dir'/_qa_state.do"
local tests 0
local pass 0
local fail 0
foreach grammar in cond nested quoted bracket compound alias_literal dollar backtick qualifier_literal {
 local ++tests
 capture noisily {
  qa_fx_a3_traj, clear n(1200) k(3) model(poisson) seed(9281)
  sort id period
  quietly summarize y if group==1 & period==2,meanonly
  scalar target1=r(mean)
  quietly summarize y if group==2 & period==2,meanonly
  scalar target2=r(mean)
  assert !missing(target1,target2) & abs(target2-target1)>.1
  replace y=. if period<2
  local rule "group=cond(period==2,1,2)"
  if "`grammar'"=="nested" local rule "group=cond(inrange(period,0,2),min(1,2),2)"
  if "`grammar'"=="quoted" mata: st_local("rule", "group=cond("+char(34)+"a,b"+char(34)+"=="+char(34)+"a,b"+char(34)+",1,2)")
  if "`grammar'"=="bracket" local rule "group=cond(group[1]>=1,1,2)"
  if "`grammar'"=="compound" mata: st_local("rule", "group=cond("+char(96)+char(34)+"a,b"+char(34)+char(39)+"=="+char(96)+char(34)+"a,b"+char(34)+char(39)+",1,2)")
  if "`grammar'"=="alias_literal" mata: st_local("rule", "group=cond(substr("+char(34)+"group,aux"+char(34)+",1,5)=="+char(34)+"group"+char(34)+",1,2)")
  global BAIT POISON
  local bait POISON
  if "`grammar'"=="dollar" mata: st_local("rule", "group=cond(strpos("+char(34)+char(36)+"BAIT"+char(34)+","+char(34)+"BAIT"+char(34)+")>0,1,2)")
  if "`grammar'"=="backtick" mata: st_local("rule", "group=cond(strpos("+char(34)+char(96)+"bait"+char(39)+char(34)+","+char(34)+"bait"+char(34)+")>0,1,2)")
  if "`grammar'"=="qualifier_literal" mata: st_local("rule", "group=cond(strpos("+char(34)+"x if y"+char(34)+","+char(34)+"if"+char(34)+")>0,1,2) if period==2")
  preserve
  replace `macval(rule)' 
  quietly summarize group if period==2,meanonly
  local native_class=r(mean)
  assert inlist(`native_class',1,2)
  restore
  local rules `"group=1, group=2, `macval(rule)'"'
  _gcomp_split_interventions, text(`"`macval(rules)'"') prefix(parsed)
  assert `parsedn'==3
  mata: assert(st_local("parsed3")==st_local("rule"))
  quietly gcomp y group aux, outcome(y) idvar(id) tvar(period) eofu fixedcovariates(aux) intvars(group) interventions(`macval(rules)') commands(group:mlogit,y:poisson) equations(group:aux,y:i.group) sim(1000) samples(2) seed(9282) minsim
  assert !missing(el(e(b),1,1),el(e(b),1,2),el(e(b),1,3))
  assert abs(el(e(b),1,1)-target1)<1e-7
  assert abs(el(e(b),1,2)-target2)<1e-7
  assert abs(el(e(b),1,3)-target`native_class')<1e-7
 }
 if !_rc {
  local ++pass
  display "PASS: parser `grammar' native rule and exact means"
 }
 else {
  local ++fail
  display "FAIL: parser `grammar' rc=" _rc
 }
}
if `fail'>0 {
 display "RESULT: test_fixture_intervention_numeric tests=`tests' pass=`pass' fail=`fail' status=FAIL"
 capture log close _all
 exit 1
}
else {
 display "RESULT: test_fixture_intervention_numeric tests=`tests' pass=`pass' fail=`fail' status=PASS"
 capture log close _all
}
