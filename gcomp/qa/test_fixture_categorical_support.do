*! test_fixture_categorical_support.do  2026/09/30
*! Author: Timothy P Copeland, Karolinska Institutet
*! Canonical A3TRAJ: absent categorical arms, actual future histories, fitted-domain loss.
*! Each U cell expects REFUSED198 and exact full caller state; each has real supported-class controls.
*! Future-history adapter: bounded observed aux[-1,1], native regress can generate >1.
*! Fitted-loss adapter: class3 observed, every class3 EOFU outcome missing.
*! Marginal category identity checks; no inference/conditional-positivity claim.
version 16.0
clear all
set more off
set varabbrev off
set processors 1
capture log close _all
local qa_dir "`c(pwd)'"
do "`qa_dir'/_qa_bootstrap.do"
do "`qa_dir'/_qa_fx_a3.do"
do "`qa_dir'/_qa_state.do"
capture program drop _fx_caller_r
program define _fx_caller_r, rclass
    tempname payload
    matrix `payload'=(1,2\3,4)
    return matrix payload=`payload'
    return scalar fxscalar=17/120
    mata: st_local("bait", "literal " + char(36) + "bait " + char(96) + "tick" + char(39) + char(34))
    return local fxbait `"`macval(bait)'"'
end
local tests 0
local pass 0
local fail 0
foreach categorical in mlogit ologit {
 foreach policy in literal expression qualifier dynamic future fitloss {
  foreach context in empty full {
   local ++tests
   capture noisily {
    * expect: REFUSED because the forced category has no observed support
    local perturb "perturb(empty_group)"
    if "`policy'"=="fitloss" local perturb ""
    local fixture_seed 9205
    if "`policy'"=="future" local fixture_seed 9211
    qa_fx_a3_traj, clear n(1200) k(3) model(poisson) seed(`fixture_seed') `perturb'
    if "`policy'"!="fitloss" assert group!=3
    local covariates "fixedcovariates(aux)"
    local commands "group: `categorical', y: poisson"
    local equations "group: aux, y: i.group"
    if "`policy'"=="future" {
        sort id period
        set seed 9212
        replace aux=2*runiform()-1
        assert aux<=1
        local covariates "varyingcovariates(aux)"
        local commands "aux: regress, group: `categorical', y: poisson"
        local equations "aux: period, group: aux, y: i.group"
    }
    forvalues g=1/2 {
     quietly summarize y if group==`g' & period==2, meanonly
     scalar fx_mean`g'=r(mean)
    }
    replace y=. if period<2
    * Same categorical model and terminal law succeed at both observed categories.
    quietly gcomp y group aux, outcome(y) idvar(id) tvar(period) eofu `covariates' intvars(group) interventions(group=1, group=2) commands(`commands') equations(`equations') sim(1000) samples(2) seed(9206) minsim
    assert !missing(el(e(b),1,1),el(e(b),1,2))
    assert abs(el(e(b),1,1)-fx_mean1)<1e-7
    assert abs(el(e(b),1,2)-fx_mean2)<1e-7
    if "`policy'"=="fitloss" replace y=. if group==3
    quietly regress y group if period==2
    if "`context'"=="empty" set varabbrev on
    else set varabbrev off
    local rule "group=3"
    if "`policy'"=="expression" local rule "group=3+0"
    if "`policy'"=="qualifier" local rule "group=3 if period==2"
    if "`policy'"=="dynamic" local rule "group=group*(period!=2)+3*(period==2)"
    if "`policy'"=="future" local rule "group=1+2*(aux>1 & aux<.)"
    tempfile refusal
    capture log close fxref
    log using "`refusal'", text name(fxref)
    if "`context'"=="empty" return clear
    else _fx_caller_r
    qa_state_snapshot, tag(categoryref) rreturn predict(xb stdp)
    capture noisily gcomp y group aux, outcome(y) idvar(id) tvar(period) eofu `covariates' intvars(group) interventions(group=1, group=2, `rule') commands(`commands') equations(`equations') sim(1000) samples(2) seed(9213) minsim
    local command_rc=_rc
    display "CATEGORY_BOUNDARY `categorical'/`policy'/`context' rc=`command_rc'"
    if `command_rc'==0 display "SILENT_UNKNOWN_CLASS: PO3=" el(e(b),1,3) " known_supported_class1_mean=" fx_mean1
    qa_state_compare, tag(categoryref)
    log close fxref
    assert `command_rc'==198
    python: assert 'outside observed categorical support' in __import__('re').sub(r'\n> ?', '', open(__import__('sfi').Macro.getLocal('refusal'),encoding='utf-8').read())
   }
   if !_rc {
    local ++pass
    display "PASS: `categorical'/`policy'/`context' unsupported-category refusal"
   }
   else {
    local ++fail
    display "FAIL: `categorical'/`policy'/`context' (rc=`=_rc')"
    capture log close fxref
   }
  }
 }
}
if `fail'>0 {
    display "RESULT: test_fixture_categorical_support tests=`tests' pass=`pass' fail=`fail' status=FAIL"
    capture log close _all
    exit 1
}
else {
    display "RESULT: test_fixture_categorical_support tests=`tests' pass=`pass' fail=`fail' status=PASS"
    capture log close _all
}
