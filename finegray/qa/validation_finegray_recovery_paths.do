* validation_finegray_recovery_paths.do
* Known-truth parameter recovery for finegray across option, coding, and
* estimand code paths. Companion to validation_finegray_recovery.do (which
* covers the core positive/negative/two-covariate/strata cases): this suite
* varies the DGP and the invocation so each scenario exercises a DIFFERENT
* branch of finegray (null effect, strong effect, binary/factor/interaction
* covariates, non-default cause()/censvalue() codes, cluster/norobust VCE,
* heavy censoring, high/low baseline incidence, level(), and the
* multiple-record reduction) while the true log-SHR is set by us.
*
* DGP (Fine & Gray 1999; Beyersmann et al.): cause-1 subdistribution is
*   F1(t; z) = 1 - (1 - p*(1 - exp(-t)))^exp(lp),  lp = z'b
* so the subdistribution hazard is proportional with log-SHR = b, and
* finegray cause(1) is correctly specified and must return b. Cause-2 times
* are exponential(1); censoring is independent uniform(0, cmax).
clear all
set varabbrev off
version 16.0

capture log close _all
log using "validation_finegray_recovery_paths.log", replace name(_recp)

local test_count = 0
local pass_count = 0
local fail_count = 0

* Recovery tolerance. Continuous single/low-dim covariates at N>=40k recover
* to within ~2x the coefficient SE; TOL is set from a multi-seed exploration
* (worst |resid| observed ~0.02). Binary/factor covariates carry less
* information per obs, so those scenarios use larger N to stay inside TOL.
local TOL = 0.035

local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
capture ado uninstall finegray
quietly net install finegray, from("`pkg_dir'") replace

* Generate cause/time/status from an existing linear predictor `lp'.
* 0=censored, 1=cause of interest, 2=competing event; anyevent is the stset
* failure indicator (any cause), compete() distinguishes.
capture program drop _fg_events
program define _fg_events
    syntax , p(real) [cmax(real 4)]
    quietly {
        gen double _pz = 1 - (1-`p')^exp(lp)
        gen double _u  = runiform()
        gen byte cause = cond(runiform() < _pz, 1, 2)
        gen double _t1 = -ln(1 - (1 - (1 - _u*_pz)^exp(-lp))/`p')
        gen double _t2 = -ln(runiform())
        gen double tevent = cond(cause==1, _t1, _t2)
        gen double c = runiform()*`cmax'
        gen double time = min(tevent, c)
        gen byte status = cond(tevent <= c, cause, 0)
        gen byte anyevent = status > 0
        gen long id = _n
        drop _pz _u _t1 _t2
    }
end

**# Scenario 1: null effect (true log-SHR = 0, SHR = 1)

local ++test_count
capture noisily {
    clear
    set obs 40000
    set seed 201
    gen double z1 = rnormal()
    gen double lp = 0*z1
    _fg_events, p(0.4)
    quietly stset time, failure(anyevent==1) id(id)
    quietly finegray z1, compete(status) cause(1)
    assert abs(_b[z1] - 0) < `TOL'
}
if _rc == 0 {
    display as result "  PASS: 1 null effect b=0 (b=`=string(_b[z1],"%6.4f")')"
    local ++pass_count
}
else {
    display as error "  FAIL: 1 null effect (rc=`=_rc')"
    local ++fail_count
}

**# Scenario 2: strong positive effect + cause-specific Cox must miss

local ++test_count
capture noisily {
    clear
    set obs 60000
    set seed 202
    gen double z1 = rnormal()
    gen double lp = 1.0*z1
    _fg_events, p(0.4)
    quietly stset time, failure(anyevent==1) id(id)
    quietly finegray z1, compete(status) cause(1)
    local b_fg = _b[z1]
    quietly stset time, failure(status==1) id(id)
    quietly stcox z1
    local b_cox = _b[z1]
    assert abs(`b_fg' - 1.0) < `TOL'
    assert abs(`b_cox' - 1.0) > 0.05
}
if _rc == 0 {
    display as result "  PASS: 2 strong b=1.0 (fg=`=string(`b_fg',"%6.4f")', cox-misses at `=string(`b_cox',"%6.4f")')"
    local ++pass_count
}
else {
    display as error "  FAIL: 2 strong b=1.0 (rc=`=_rc')"
    local ++fail_count
}

**# Scenario 3: binary (0/1) covariate

local ++test_count
capture noisily {
    clear
    set obs 80000
    set seed 203
    gen byte z1 = runiform() < 0.5
    gen double lp = 0.6*z1
    _fg_events, p(0.4)
    quietly stset time, failure(anyevent==1) id(id)
    quietly finegray z1, compete(status) cause(1)
    assert abs(_b[z1] - 0.6) < `TOL'
}
if _rc == 0 {
    display as result "  PASS: 3 binary covariate b=0.6 (b=`=string(_b[z1],"%6.4f")')"
    local ++pass_count
}
else {
    display as error "  FAIL: 3 binary covariate (rc=`=_rc')"
    local ++fail_count
}

**# Scenario 4: three continuous covariates

local ++test_count
capture noisily {
    clear
    set obs 60000
    set seed 204
    gen double z1 = rnormal()
    gen double z2 = rnormal()
    gen double z3 = rnormal()
    gen double lp = 0.5*z1 - 0.4*z2 + 0.3*z3
    _fg_events, p(0.4)
    quietly stset time, failure(anyevent==1) id(id)
    quietly finegray z1 z2 z3, compete(status) cause(1)
    assert abs(_b[z1] - 0.5) < `TOL'
    assert abs(_b[z2] - (-0.4)) < `TOL'
    assert abs(_b[z3] - 0.3) < `TOL'
}
if _rc == 0 {
    display as result "  PASS: 4 three covariates (0.5,-0.4,0.3)"
    local ++pass_count
}
else {
    display as error "  FAIL: 4 three covariates (rc=`=_rc')"
    local ++fail_count
}

**# Scenario 5: cluster() VCE — point estimate recovers, e(vce)==cluster

local ++test_count
capture noisily {
    clear
    set obs 60000
    set seed 205
    gen double z1 = rnormal()
    gen double lp = 0.5*z1
    _fg_events, p(0.4)
    gen long clid = ceil(id/3)
    quietly stset time, failure(anyevent==1) id(id)
    quietly finegray z1, compete(status) cause(1) cluster(clid)
    assert abs(_b[z1] - 0.5) < `TOL'
    assert "`e(vce)'" == "cluster"
}
if _rc == 0 {
    display as result "  PASS: 5 cluster() recover (b=`=string(_b[z1],"%6.4f")', vce=cluster)"
    local ++pass_count
}
else {
    display as error "  FAIL: 5 cluster() (rc=`=_rc')"
    local ++fail_count
}

**# Scenario 6: norobust (model-based/oim VCE) — point estimate recovers

local ++test_count
capture noisily {
    clear
    set obs 60000
    set seed 206
    gen double z1 = rnormal()
    gen double lp = 0.5*z1
    _fg_events, p(0.4)
    quietly stset time, failure(anyevent==1) id(id)
    quietly finegray z1, compete(status) cause(1) norobust
    assert abs(_b[z1] - 0.5) < `TOL'
    assert "`e(vce)'" == "oim"
}
if _rc == 0 {
    display as result "  PASS: 6 norobust recover (b=`=string(_b[z1],"%6.4f")', vce=oim)"
    local ++pass_count
}
else {
    display as error "  FAIL: 6 norobust (rc=`=_rc')"
    local ++fail_count
}

**# Scenario 7: non-default censvalue()

local ++test_count
capture noisily {
    clear
    set obs 60000
    set seed 207
    gen double z1 = rnormal()
    gen double lp = 0.5*z1
    _fg_events, p(0.4)
    * Recode censored 0 -> 9; stset failure indicator (anyevent) is unchanged.
    gen byte status9 = cond(status==0, 9, status)
    quietly stset time, failure(anyevent==1) id(id)
    quietly finegray z1, compete(status9) cause(1) censvalue(9)
    assert abs(_b[z1] - 0.5) < `TOL'
    assert e(censvalue) == 9
}
if _rc == 0 {
    display as result "  PASS: 7 censvalue(9) recover (b=`=string(_b[z1],"%6.4f")')"
    local ++pass_count
}
else {
    display as error "  FAIL: 7 censvalue(9) (rc=`=_rc')"
    local ++fail_count
}

**# Scenario 8: non-default cause() value (z-dependent cause relabelled 2)

local ++test_count
capture noisily {
    clear
    set obs 60000
    set seed 208
    gen double z1 = rnormal()
    gen double lp = 0.5*z1
    _fg_events, p(0.4)
    * Swap event codes so the z-dependent cause is labelled 2, the competing 1.
    gen byte status2 = cond(status==1, 2, cond(status==2, 1, 0))
    quietly stset time, failure(anyevent==1) id(id)
    quietly finegray z1, compete(status2) cause(2)
    assert abs(_b[z1] - 0.5) < `TOL'
    assert e(cause) == 2
}
if _rc == 0 {
    display as result "  PASS: 8 cause(2) recover (b=`=string(_b[z1],"%6.4f")')"
    local ++pass_count
}
else {
    display as error "  FAIL: 8 cause(2) (rc=`=_rc')"
    local ++fail_count
}

**# Scenario 9: factor-variable covariate i.grp

local ++test_count
capture noisily {
    clear
    set obs 80000
    set seed 209
    gen byte grp = runiform() < 0.5
    gen double lp = 0.6*grp
    _fg_events, p(0.4)
    quietly stset time, failure(anyevent==1) id(id)
    quietly finegray i.grp, compete(status) cause(1)
    matrix _bb = e(b)
    assert abs(_bb[1,1] - 0.6) < `TOL'
}
if _rc == 0 {
    display as result "  PASS: 9 i.grp recover (b=`=string(_bb[1,1],"%6.4f")')"
    local ++pass_count
}
else {
    display as error "  FAIL: 9 i.grp (rc=`=_rc')"
    local ++fail_count
}

**# Scenario 10: heavy independent censoring (IPCW stress)

local ++test_count
capture noisily {
    clear
    set obs 80000
    set seed 210
    gen double z1 = rnormal()
    gen double lp = 0.5*z1
    * cmax=0.6 censors the large majority of subjects.
    _fg_events, p(0.4) cmax(0.6)
    quietly stset time, failure(anyevent==1) id(id)
    quietly count if status == 0
    local pcens = r(N)/_N
    quietly finegray z1, compete(status) cause(1)
    assert abs(_b[z1] - 0.5) < `TOL'
}
if _rc == 0 {
    display as result "  PASS: 10 heavy censoring recover (b=`=string(_b[z1],"%6.4f")', cens frac=`=string(`pcens',"%4.2f")')"
    local ++pass_count
}
else {
    display as error "  FAIL: 10 heavy censoring (rc=`=_rc')"
    local ++fail_count
}

**# Scenario 11: high baseline incidence (p=0.6)

local ++test_count
capture noisily {
    clear
    set obs 60000
    set seed 211
    gen double z1 = rnormal()
    gen double lp = 0.5*z1
    _fg_events, p(0.6)
    quietly stset time, failure(anyevent==1) id(id)
    quietly finegray z1, compete(status) cause(1)
    assert abs(_b[z1] - 0.5) < `TOL'
}
if _rc == 0 {
    display as result "  PASS: 11 high incidence p=0.6 (b=`=string(_b[z1],"%6.4f")')"
    local ++pass_count
}
else {
    display as error "  FAIL: 11 high incidence (rc=`=_rc')"
    local ++fail_count
}

**# Scenario 12: low baseline incidence (p=0.2)

local ++test_count
capture noisily {
    clear
    set obs 80000
    set seed 212
    gen double z1 = rnormal()
    gen double lp = 0.5*z1
    _fg_events, p(0.2)
    quietly stset time, failure(anyevent==1) id(id)
    quietly finegray z1, compete(status) cause(1)
    assert abs(_b[z1] - 0.5) < `TOL'
}
if _rc == 0 {
    display as result "  PASS: 12 low incidence p=0.2 (b=`=string(_b[z1],"%6.4f")')"
    local ++pass_count
}
else {
    display as error "  FAIL: 12 low incidence (rc=`=_rc')"
    local ++fail_count
}

**# Scenario 13: factor interaction i.grp##c.z1

local ++test_count
capture noisily {
    clear
    set obs 80000
    set seed 213
    gen byte grp = runiform() < 0.5
    gen double z1 = rnormal()
    gen double lp = 0.5*grp + 0.4*z1 + 0.3*grp*z1
    _fg_events, p(0.4)
    quietly stset time, failure(anyevent==1) id(id)
    quietly finegray i.grp##c.z1, compete(status) cause(1)
    * Column order after fvexpand: 1.grp, z1, 1.grp#c.z1
    matrix _bb = e(b)
    assert abs(_bb[1,1] - 0.5) < `TOL'
    assert abs(_bb[1,2] - 0.4) < `TOL'
    assert abs(_bb[1,3] - 0.3) < `TOL'
}
if _rc == 0 {
    display as result "  PASS: 13 i.grp##c.z1 recover (0.5,0.4,0.3)"
    local ++pass_count
}
else {
    display as error "  FAIL: 13 i.grp##c.z1 (rc=`=_rc')"
    local ++fail_count
}

**# Scenario 14: level() does not move the point estimate; e(level) stored

local ++test_count
capture noisily {
    clear
    set obs 60000
    set seed 214
    gen double z1 = rnormal()
    gen double lp = 0.5*z1
    _fg_events, p(0.4)
    quietly stset time, failure(anyevent==1) id(id)
    quietly finegray z1, compete(status) cause(1) level(90)
    assert abs(_b[z1] - 0.5) < `TOL'
    assert e(level) == 90
}
if _rc == 0 {
    display as result "  PASS: 14 level(90) recover (b=`=string(_b[z1],"%6.4f")', level=90)"
    local ++pass_count
}
else {
    display as error "  FAIL: 14 level(90) (rc=`=_rc')"
    local ++fail_count
}

**# Scenario 15: multiple-record reduction recovers = single-record fit

local ++test_count
capture noisily {
    clear
    set obs 60000
    set seed 215
    gen double z1 = rnormal()
    gen double lp = 0.5*z1
    _fg_events, p(0.4)
    quietly stset time, failure(anyevent==1) id(id)
    quietly finegray z1, compete(status) cause(1)
    local b_single = _b[z1]
    * Split each subject into contiguous intervals; only the interval holding
    * the failure keeps a nonzero event code (consistent with stset _d).
    quietly stsplit part, at(0.5 1 1.5 2 3)
    quietly gen byte fgstatus = cond(_d==1, status, 0)
    quietly finegray z1, compete(fgstatus) cause(1)
    local b_multi = _b[z1]
    assert abs(`b_multi' - 0.5) < `TOL'
    assert reldif(`b_multi', `b_single') < 1e-4
}
if _rc == 0 {
    display as result "  PASS: 15 multi-record reduction (single=`=string(`b_single',"%6.4f")', multi=`=string(`b_multi',"%6.4f")')"
    local ++pass_count
}
else {
    display as error "  FAIL: 15 multi-record reduction (rc=`=_rc')"
    local ++fail_count
}

**# Summary

display as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    display "RESULT: validation_finegray_recovery_paths tests=`test_count' pass=`pass_count' fail=`fail_count'"
    log close _recp
    exit 1
}
display as result "ALL TESTS PASSED"
display "RESULT: validation_finegray_recovery_paths tests=`test_count' pass=`pass_count' fail=`fail_count'"
log close _recp
