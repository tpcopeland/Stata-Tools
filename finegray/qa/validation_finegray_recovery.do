* validation_finegray_recovery.do
* Known-truth parameter recovery for finegray.
* Lead correctness oracle (run before cross-validation): simulate competing
* risks from the Fine-Gray subdistribution model with a true log-SHR set by us,
* then assert finegray recovers it at large N.
*
* DGP (Fine & Gray 1999; Beyersmann et al.): the cause-1 subdistribution is
*   F1(t; z) = 1 - (1 - p*(1 - exp(-t)))^exp(z'b)
* so P(cause 1 | z) = 1 - (1-p)^exp(z'b), and the conditional event-time CDF is
* inverted in closed form. Cause-2 times are exponential(1); censoring is
* independent uniform. finegray cause(1) is the correctly specified estimator
* and must return b; a cause-specific Cox model (competing events censored)
* targets a different parameter and misses it.
clear all
set varabbrev off
version 16.0

capture log close _rec
log using "validation_finegray_recovery.log", replace name(_rec)

local test_count = 0
local pass_count = 0
local fail_count = 0

* Recovery tolerance: deterministic at the fixed seeds below. The Monte-Carlo
* SE of each coefficient is ~0.008 at these N; a 6-seed mini-MC gave a spread of
* |resid| <= 0.016, so 0.03 is ~2x the worst observed MC error and ~4x the SE.
local TOL = 0.03

local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
capture ado uninstall finegray
quietly net install finegray, from("`pkg_dir'") replace

* Fine-Gray DGP: 0=censored, 1=cause of interest, 2=competing event.
* anyevent is the stset failure indicator (any cause); compete() distinguishes.
program define _gen_fg_dgp
    syntax , n(integer) p(real) [seed(integer 1) b1(real 0) b2(real 0)]
    clear
    set seed `seed'
    set obs `n'
    gen double z1 = rnormal()
    gen double z2 = rnormal()
    gen double lp = `b1'*z1 + `b2'*z2
    gen double pz = 1 - (1-`p')^exp(lp)
    gen double u  = runiform()
    gen byte cause = cond(runiform() < pz, 1, 2)
    gen double t1 = -ln(1 - (1 - (1 - u*pz)^exp(-lp))/`p')
    gen double t2 = -ln(runiform())
    gen double tevent = cond(cause==1, t1, t2)
    gen double c = runiform()*4
    gen double time = min(tevent, c)
    gen byte status = cond(tevent <= c, cause, 0)
    gen byte anyevent = status > 0
    gen long id = _n
end

**# Scenario A: recover a positive log-SHR; naive Cox must miss

local ++test_count
capture noisily {
    _gen_fg_dgp, n(50000) p(0.4) b1(0.5) seed(101)
    quietly stset time, failure(anyevent==1) id(id)
    quietly finegray z1, compete(status) cause(1)
    local b_fg = _b[z1]
    * Naive cause-specific Cox (competing events censored) targets a different
    * estimand and must miss the true subdistribution log-SHR.
    quietly stset time, failure(status==1) id(id)
    quietly stcox z1
    local b_cox = _b[z1]
    assert abs(`b_fg' - 0.5) < `TOL'
    assert abs(`b_cox' - 0.5) > 0.04
}
if _rc == 0 {
    display as result "  PASS: A recover b=0.5 (fg=`=string(`b_fg',"%6.4f")', cox-misses)"
    local ++pass_count
}
else {
    display as error "  FAIL: A recover b=0.5 (rc=`=_rc')"
    local ++fail_count
}

**# Scenario B: recover a negative log-SHR

local ++test_count
capture noisily {
    _gen_fg_dgp, n(50000) p(0.4) b1(-0.7) seed(101)
    quietly stset time, failure(anyevent==1) id(id)
    quietly finegray z1, compete(status) cause(1)
    assert abs(_b[z1] - (-0.7)) < `TOL'
}
if _rc == 0 {
    display as result "  PASS: B recover b=-0.7"
    local ++pass_count
}
else {
    display as error "  FAIL: B recover b=-0.7 (rc=`=_rc')"
    local ++fail_count
}

**# Scenario C: recover both coefficients in a two-covariate model

local ++test_count
capture noisily {
    _gen_fg_dgp, n(60000) p(0.4) b1(0.5) b2(-0.4) seed(707)
    quietly stset time, failure(anyevent==1) id(id)
    quietly finegray z1 z2, compete(status) cause(1)
    assert abs(_b[z1] - 0.5) < `TOL'
    assert abs(_b[z2] - (-0.4)) < `TOL'
}
if _rc == 0 {
    display as result "  PASS: C recover (b1=0.5, b2=-0.4)"
    local ++pass_count
}
else {
    display as error "  FAIL: C recover two covariates (rc=`=_rc')"
    local ++fail_count
}

**# Scenario D: recover under group-dependent censoring with strata()

local ++test_count
capture noisily {
    _gen_fg_dgp, n(60000) p(0.4) b1(0.6) seed(909)
    * Make censoring depend on a group; strata() estimates the censoring KM
    * within group, which is the case the option exists for.
    gen byte grp = mod(id, 2)
    quietly replace time = min(tevent, cond(grp==1, runiform()*1.5, runiform()*6))
    quietly replace status = cond(tevent <= time, cause, 0)
    quietly replace anyevent = status > 0
    quietly stset time, failure(anyevent==1) id(id)
    quietly finegray z1, compete(status) cause(1) strata(grp)
    assert abs(_b[z1] - 0.6) < `TOL'
}
if _rc == 0 {
    display as result "  PASS: D recover b=0.6 with strata() under group-dependent censoring"
    local ++pass_count
}
else {
    display as error "  FAIL: D recover with strata() (rc=`=_rc')"
    local ++fail_count
}

**# Summary

display as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    display "RESULT: validation_finegray_recovery tests=`test_count' pass=`pass_count' fail=`fail_count'"
    log close _rec
    exit 1
}
display as result "ALL TESTS PASSED"
display "RESULT: validation_finegray_recovery tests=`test_count' pass=`pass_count' fail=`fail_count'"
log close _rec
