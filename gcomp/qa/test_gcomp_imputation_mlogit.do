* test_gcomp_imputation_mlogit.do - Categorical (mlogit/ologit) imputation & component models
* Regression coverage for the v1.3.1 fixes:
*   1. Stray macro-quote in the longitudinal imputation predict varlist range
*      (_gcomp_bootstrap_impl.ado ~389) -> r(198) "' invalid name" on any
*      imp_cmd(mlogit)/imp_cmd(ologit) run in a time-varying model.
*   2. Internal mlogit refit under the bootstrap prefix demanded baseoutcome().
*      Affected BOTH the imputation fits and the time-varying component-model
*      fits (the simulation-phase fits never applied the baseoutcome opts).
* Plus a self-contained validation that gcomp's multinomial inverse-CDF
* imputation sampler reproduces the fitted model's predicted category marginals.
*
* Manual run from this qa/ directory:  stata-mp -b do test_gcomp_imputation_mlogit.do

clear all
set more off
version 16.0

local test_count = 0
local pass_count = 0
local fail_count = 0

* === Bootstrap (sandboxed local install) ===
local qa_dir  "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
capture ado uninstall gcomp
quietly net install gcomp, from("`pkg_dir'") replace
discard

**# Helper: build a mediation dataset with a 3-category mediator (some missing)
capture program drop _gcimp_make_mediation
program define _gcimp_make_mediation
    version 16.0
    args n seed pmiss
    clear
    set seed `seed'
    set obs `n'
    gen double c = rnormal()
    gen double x = rbinomial(1, invlogit(-0.5 + 0.2*c))
    gen double _xb1 = -0.5 + 0.6*x + 0.3*c
    gen double _xb2 =  0.2 + 0.4*x - 0.2*c
    gen double _den = 1 + exp(_xb1) + exp(_xb2)
    gen double _p1 = 1/_den
    gen double _p2 = exp(_xb1)/_den
    gen double _u = runiform()
    gen byte m = 1 + (_u > _p1) + (_u > _p1 + _p2)
    gen double y = rbinomial(1, invlogit(-1.5 + 0.3*(m==2) + 0.5*(m==3) + 0.3*x + 0.2*c))
    if `pmiss' > 0 replace m = . if runiform() < `pmiss'
    drop _xb1 _xb2 _den _p1 _p2 _u
end

**# Helper: build a longitudinal dataset with a 3-category time-varying covariate
capture program drop _gcimp_make_longitudinal
program define _gcimp_make_longitudinal
    version 16.0
    args n seed pmiss
    clear
    set seed `seed'
    set obs `n'
    gen id = _n
    gen double L0 = rnormal()
    expand 3
    bysort id: gen time = _n
    gen double L = 0
    gen byte A = 0
    gen byte Alag = 0
    gen double Llag = 0
    bysort id (time): replace L = 0.15 + 0.65*L0 + rnormal(0,0.35) if time==1
    bysort id (time): replace A = rbinomial(1, invlogit(-0.35+0.70*L+0.20*L0)) if time==1
    bysort id (time): replace L = 0.10 + 0.60*L[_n-1] - 0.55*A[_n-1] + 0.15*L0 + rnormal(0,0.35) if time==2
    bysort id (time): replace A = rbinomial(1, invlogit(-0.25+0.60*L+0.20*L0)) if time==2
    bysort id (time): replace L = 0.05 + 0.55*L[_n-1] - 0.55*A[_n-1] + 0.10*L0 + rnormal(0,0.35) if time==3
    bysort id (time): replace A = rbinomial(1, invlogit(-0.15+0.55*L+0.20*L0)) if time==3
    gen double _u = runiform()
    gen byte M = 1 + (_u > invlogit(-0.3+0.5*L)) + (_u > invlogit(0.6+0.5*L))
    if `pmiss' > 0 replace M = . if runiform() < `pmiss'
    drop _u
    bysort id (time): replace Alag = A[_n-1] if _n>1
    bysort id (time): replace Llag = L[_n-1] if _n>1
    gen byte Y = 0
    bysort id (time): replace Y = rbinomial(1, invlogit(-1.35 - 0.90*A[_n-1] + 0.75*L[_n-1] + 0.30*(M[_n-1]==3) + 0.20*L0)) if time==3
end

**# Test 1: mediation imputation with imp_cmd(mlogit) (regression: baseoutcome under bootstrap)
local ++test_count
capture noisily {
    _gcimp_make_mediation 600 88888 0.12
    gcomp y m x c, outcome(y) mediation obe ///
        exposure(x) mediator(m) ///
        commands(m: mlogit, y: logit) ///
        equations(m: x c, y: i.m x c) ///
        base_confs(c) sim(100) samples(5) seed(1) ///
        impute(m) imp_cmd(m: mlogit) imp_eq(m: x c) imp_cycles(5)
    confirm scalar e(tce)
    assert e(tce) < .
}
if _rc == 0 {
    display as result "  PASS: mediation imp_cmd(mlogit) runs and returns finite e(tce)"
    local ++pass_count
}
else {
    display as error "  FAIL: mediation imp_cmd(mlogit) (error `=_rc')"
    local ++fail_count
}

**# Test 2: mediation imputation with imp_cmd(ologit)
local ++test_count
capture noisily {
    _gcimp_make_mediation 600 88888 0.12
    gcomp y m x c, outcome(y) mediation obe ///
        exposure(x) mediator(m) ///
        commands(m: mlogit, y: logit) ///
        equations(m: x c, y: i.m x c) ///
        base_confs(c) sim(100) samples(5) seed(1) ///
        impute(m) imp_cmd(m: ologit) imp_eq(m: x c) imp_cycles(5)
    confirm scalar e(tce)
    assert e(tce) < .
}
if _rc == 0 {
    display as result "  PASS: mediation imp_cmd(ologit) runs and returns finite e(tce)"
    local ++pass_count
}
else {
    display as error "  FAIL: mediation imp_cmd(ologit) (error `=_rc')"
    local ++fail_count
}

**# Test 3: time-varying imputation with imp_cmd(mlogit) (regression: stray-quote predict + baseoutcome)
local ++test_count
capture noisily {
    _gcimp_make_longitudinal 800 4321 0.10
    gcomp Y L0 A L M Alag Llag id time, outcome(Y) idvar(id) tvar(time) ///
        varyingcovariates(L M) fixedcovariates(L0) ///
        laggedvars(Alag Llag) lagrules(Alag: A 1, Llag: L 1) ///
        commands(A: logit, Y: logit, L: regress, M: regress) ///
        equations(A: L0 L, Y: Alag Llag L0, L: Alag Llag L0, M: L L0) ///
        intvars(A) interventions(A=1, A=0) ///
        impute(M) imp_cmd(M: mlogit) imp_eq(M: L L0) imp_cycles(3) ///
        eofu sim(100) samples(3) seed(1)
    assert "`e(analysis_type)'" == "time_varying"
    confirm matrix e(b)
}
if _rc == 0 {
    display as result "  PASS: time-varying imp_cmd(mlogit) runs (stray-quote predict path)"
    local ++pass_count
}
else {
    display as error "  FAIL: time-varying imp_cmd(mlogit) (error `=_rc')"
    local ++fail_count
}

**# Test 4: time-varying mlogit component model (regression: simulation-phase baseoutcome)
local ++test_count
capture noisily {
    _gcimp_make_longitudinal 800 4321 0
    gcomp Y L0 A L M Alag Llag id time, outcome(Y) idvar(id) tvar(time) ///
        varyingcovariates(L M) fixedcovariates(L0) ///
        laggedvars(Alag Llag) lagrules(Alag: A 1, Llag: L 1) ///
        commands(A: logit, Y: logit, L: regress, M: mlogit) ///
        equations(A: L0 L, Y: Alag Llag L0, L: Alag Llag L0, M: L L0) ///
        intvars(A) interventions(A=1, A=0) eofu sim(100) samples(3) seed(1)
    assert "`e(analysis_type)'" == "time_varying"
    confirm matrix e(b)
}
if _rc == 0 {
    display as result "  PASS: time-varying commands(M: mlogit) component model runs"
    local ++pass_count
}
else {
    display as error "  FAIL: time-varying mlogit component model (error `=_rc')"
    local ++fail_count
}

**# Test 5: time-varying ologit component model
local ++test_count
capture noisily {
    _gcimp_make_longitudinal 800 4321 0
    gcomp Y L0 A L M Alag Llag id time, outcome(Y) idvar(id) tvar(time) ///
        varyingcovariates(L M) fixedcovariates(L0) ///
        laggedvars(Alag Llag) lagrules(Alag: A 1, Llag: L 1) ///
        commands(A: logit, Y: logit, L: regress, M: ologit) ///
        equations(A: L0 L, Y: Alag Llag L0, L: Alag Llag L0, M: L L0) ///
        intvars(A) interventions(A=1, A=0) eofu sim(100) samples(3) seed(1)
    assert "`e(analysis_type)'" == "time_varying"
    confirm matrix e(b)
}
if _rc == 0 {
    display as result "  PASS: time-varying commands(M: ologit) component model runs"
    local ++pass_count
}
else {
    display as error "  FAIL: time-varying ologit component model (error `=_rc')"
    local ++fail_count
}

**# Test 6: VALIDATION - gcomp's multinomial inverse-CDF imputation sampler reproduces
**#          the fitted mlogit predicted category marginals (oracle = mlogit predict).
**#          Replicates _gcomp_bootstrap_impl lines ~386-409 exactly.
local ++test_count
capture noisily {
    _gcimp_make_mediation 4000 20260616 0
    * Fit mlogit exactly as gcomp does (baseoutcome = smallest observed category)
    quietly summarize m, meanonly
    local base = r(min)
    quietly mlogit m x c, baseoutcome(`base')
    local maxl = e(k_out)
    matrix out_m = e(out)
    capture drop _pp*
    quietly predict double _pp1-_pp`maxl'
    * Oracle: mean predicted probability per category
    forvalues l = 1/`maxl' {
        quietly summarize _pp`l', meanonly
        local meanpred`l' = r(mean)
        local catval`l' = out_m[1, `l']
    }
    * gcomp's sampler: inverse-CDF draw from the per-row predicted probabilities
    set seed 13579
    capture drop _imp _u _cum
    gen double _u = runiform()
    gen double _cum = 0
    gen _imp = .
    forvalues l = 1/`maxl' {
        quietly replace _imp = `catval`l'' if _u >= _cum & _u < (_cum + _pp`l') & _imp == .
        quietly replace _cum = _cum + _pp`l'
    }
    quietly count if _imp == .
    assert r(N) == 0
    * Each sampled category's marginal proportion must match its mean predicted prob
    forvalues l = 1/`maxl' {
        quietly count if _imp == `catval`l''
        local prop`l' = r(N) / _N
        local gap = abs(`prop`l'' - `meanpred`l'')
        display as text "    cat `catval`l'': sampled=" %6.4f `prop`l'' ///
            "  predicted=" %6.4f `meanpred`l'' "  gap=" %6.4f `gap'
        assert `gap' < 0.03
    }
}
if _rc == 0 {
    display as result "  PASS: multinomial sampler reproduces mlogit predicted marginals (gap < 0.03)"
    local ++pass_count
}
else {
    display as error "  FAIL: sampler vs predicted marginals (error `=_rc')"
    local ++fail_count
}

**# Summary
display _n as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    display "RESULT: test_gcomp_imputation_mlogit tests=`test_count' pass=`pass_count' fail=`fail_count'"
    exit 1
}
display as result "ALL TESTS PASSED"
display "RESULT: test_gcomp_imputation_mlogit tests=`test_count' pass=`pass_count' fail=`fail_count'"
