*! validation_fixture_count_means.do  2026/09/30
*! Author: Timothy P Copeland, Karolinska Institutet
*! Named A3-TRAJ exogenous-class terminal-count adapter; Poisson and NB2 laws.
*! Conditional targets exp(b0+2*b1+4*b2) and independent sample-mean score oracles.
*! Fixed-class saturated Poisson/NB2 means equal direct within-class means.
*! Known conditional DGP mean-SE = sqrt((lambda+alpha*lambda^2)/n_class).
*! Six known-law reference scales check generated conditional means; no estimator/inference calibration claim.
*! Exogenous observed class becomes an intervenable group; no feedback/confounding claim.
*! Gamma(2,.5) multipliers define the separate NB2 count law (Stata nbreg manual p6).
*! Simulation mean uses 1000 subjects; fixed-class mean has no conditional MC noise.
version 16.0
clear all
set more off
set varabbrev off
set processors 1
capture log close _all
local qa_dir "`c(pwd)'"
do "`qa_dir'/_qa_bootstrap.do"
do "`qa_dir'/_qa_fx_a3.do"
do "`qa_dir'/_qa_metamorphic.do"
do "`qa_dir'/_qa_state.do"
capture program drop _fx_count_fit
program define _fx_count_fit, eclass
    local original_varabbrev=c(varabbrev)
    set varabbrev off
    capture noisily {
    args family categorical
    quietly levelsof group, local(levels)
    local g1 : word 1 of `levels'
    local g2 : word 2 of `levels'
    local g3 : word 3 of `levels'
    assert `: word count `levels''==3
    quietly gcomp y group aux, outcome(y) idvar(id) tvar(period) eofu fixedcovariates(aux) intvars(group) interventions(group=`g1', group=`g2', group=`g3') commands(group: `categorical', y: `family') equations(group: aux, y: i.group) sim(1000) samples(3) seed(9202) minsim
    }
    local rc=_rc
    set varabbrev `original_varabbrev'
    if `rc' exit `rc'
end
mata:
_fx_count_globals=asarray_create("string",1)
void _fx_count_global_snapshot() {
    external transmorphic scalar _fx_count_globals
    string colvector names
    real scalar i
    _fx_count_globals=asarray_create("string",1)
    names=st_dir("global","macro","*")
    for(i=1;i<=rows(names);i++) {
        if (!st_isname(names[i]) | names[i]=="S_E_cmd" | names[i]=="S_E_depv") continue
        asarray(_fx_count_globals,names[i],st_global(names[i]))
    }
}
void _fx_count_global_compare() {
    external transmorphic scalar _fx_count_globals
    string colvector names,actual
    real scalar i
    names=st_dir("global","macro","*");actual=J(0,1,"")
    for(i=1;i<=rows(names);i++) {
        if (!st_isname(names[i]) | names[i]=="S_E_cmd" | names[i]=="S_E_depv") continue
        actual=actual\names[i]
        assert(asarray_contains(_fx_count_globals,names[i]))
        assert(asarray(_fx_count_globals,names[i])==st_global(names[i]))
    }
    assert(rows(actual)==rows(asarray_keys(_fx_count_globals)))
}
end
local test_count 0
local pass_count 0
local fail_count 0
foreach family in poisson nbreg {
 foreach categorical in mlogit ologit {
  foreach scale in small upper_bound {
   if "`scale'"=="upper_bound" & "`categorical'"=="ologit" continue
   local seeds "9201 9203"
   local n 2400
   if "`scale'"=="upper_bound" {
    local seeds "9241"
    local n 10000
   }
  foreach seed of local seeds {
   local ++test_count
   capture noisily {
    qa_fx_a3_traj, clear n(`n') k(3) model(poisson) seed(`seed')
    matrix fx_truth_B=r(truth_coefficients)
    sort id period
    if "`family'"=="nbreg" {
     * Named gamma-Poisson adapter: E(G)=1, Var(G)=.5; E(Y)=lambda, Var(Y)=lambda+.5lambda^2.
     local nbseed=`seed'+1000
     set seed `nbseed'
     generate double fx_G=rgamma(2,.5)
     replace y=rpoisson(exp(eta)*fx_G)
     drop fx_G
    }
    forvalues g=1/3 {
     quietly summarize y if group==`g' & period==2, meanonly
     scalar fx_mean`g'=r(mean)
     scalar fx_n`g'=r(N)
     scalar fx_target`g'=exp(fx_truth_B[`g',1]+2*fx_truth_B[`g',2]+4*fx_truth_B[`g',3])
     scalar fx_sampling`g'=sqrt((fx_target`g'+("`family'"=="nbreg")*.5*fx_target`g'^2)/fx_n`g')
    }
    replace y=. if period<2
    char _dta[qa_fixture_adapter] "exogenous_class_terminal_count"
    quietly regress y group if period==2
    set varabbrev on
    mata: st_global("S_15","opaque count global " + char(36) + "bait " + char(96) + "tick" + char(39))
    mata: _fx_count_global_snapshot()
    qa_state_snapshot, tag(countfit) rreturn
    _fx_count_fit `family' `categorical'
    qa_state_compare, tag(countfit) allow(e r rng global)
    mata: _fx_count_global_compare()
    assert "`c(varabbrev)'"=="on"
    assert e(N_subjects)==`n'
    forvalues g=1/3 {
     assert !missing(el(e(b),1,`g'),fx_mean`g',fx_target`g',fx_sampling`g')
     display "COUNT_ORACLE `family'/`categorical'/`scale'/`seed'/`g': fitted difference=" el(e(b),1,`g')-fx_mean`g' " population residual=" el(e(b),1,`g')-fx_target`g' " samplingSE=" fx_sampling`g'
     assert abs(el(e(b),1,`g')-fx_mean`g')<1e-7
     assert abs(el(e(b),1,`g')-fx_target`g')<6*fx_sampling`g'
    }
    if "`scale'"=="small" & `seed'==9201 {
     * expect: INVARIANT for fixed-class conditional means and seeded natural-regime simulation
     qa_metamorphic unsorted, var(group) command(_fx_count_fit `family' `categorical') returns(e(b)) tol(1e-8)
     qa_metamorphic codes_sparse, var(group) command(_fx_count_fit `family' `categorical') returns(e(b)) tol(1e-8)
     qa_metamorphic codes_multidigit, var(group) command(_fx_count_fit `family' `categorical') returns(e(b)) tol(1e-8)
    }
   }
   if !_rc {
    local ++pass_count
    display "PASS: `family'/`categorical'/`scale'/`seed' fitted/sample/known-law conditional count means"
   }
   else {
    local ++fail_count
    display "FAIL: `family'/`categorical'/`scale'/`seed' (rc=`=_rc')"
   }
  }
 }
 }
}
if `fail_count'>0 {
    display "RESULT: validation_fixture_count_means tests=`test_count' pass=`pass_count' fail=`fail_count' status=FAIL"
    capture log close _all
    exit 1
}
else {
    display "RESULT: validation_fixture_count_means tests=`test_count' pass=`pass_count' fail=`fail_count' status=PASS"
    capture log close _all
}
