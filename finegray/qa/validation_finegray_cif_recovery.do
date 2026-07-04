* validation_finegray_cif_recovery.do
* Known-truth recovery for the predicted cumulative incidence function
* (finegray_cif) against a closed-form analytic oracle from the DGP.
*
* DGP (Fine & Gray 1999): F1(t; z) = 1 - (1 - p*(1 - exp(-t)))^exp(z'b).
* At the reference profile z = 0 this collapses to the exact, estimator-free
* oracle  F1(t; 0) = p*(1 - exp(-t)),  with plateau F1(inf; 0) = p, and at a
* general profile the CIF is 1 - (1 - p*(1 - exp(-t)))^exp(z'b). finegray_cif
* estimates F1 by inverting the fitted baseline subdistribution hazard through
* the IPCW risk sets; at large N it must reproduce the analytic curve.
clear all
set varabbrev off
version 16.0

capture log close _all
log using "validation_finegray_cif_recovery.log", replace name(_cifr)

local test_count = 0
local pass_count = 0
local fail_count = 0

* CIF tolerance: F1 estimate SE at N=120k is ~0.002 in the body of the curve;
* the IPCW baseline is noisier near the last event time, so late horizons get
* a slightly looser bound. Values below are ~5-10x the observed pointwise SE.
local TOL  = 0.012
local TOLT = 0.020

local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
capture ado uninstall finegray
quietly net install finegray, from("`pkg_dir'") replace

* Build a single-covariate Fine-Gray sample with baseline incidence p and
* log-SHR b on z1. cmax large so risk sets stay populated across the horizons.
capture program drop _fg_cif_dgp
program define _fg_cif_dgp
    syntax , n(integer) p(real) b(real) [seed(integer 1) cmax(real 8)]
    clear
    set seed `seed'
    set obs `n'
    gen double z1 = rnormal()
    gen double lp = `b'*z1
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
end

**# Scenario A: CIF at reference profile z1=0 vs F1(t;0) = p*(1-exp(-t))

local ++test_count
capture noisily {
    _fg_cif_dgp, n(120000) p(0.4) b(0.5) seed(301)
    quietly stset time, failure(anyevent==1) id(id)
    quietly finegray z1, compete(status) cause(1)
    quietly finegray_cif, at(z1=0) attime(0.5 1 2 3)
    matrix _T = r(table)
    local maxerr = 0
    forvalues r = 1/4 {
        local tt    = _T[`r', 1]
        local cif   = _T[`r', 2]
        local truth = 0.4*(1 - exp(-`tt'))
        local e = abs(`cif' - `truth')
        if `e' > `maxerr' local maxerr = `e'
        assert `e' < `TOL'
    }
}
if _rc == 0 {
    display as result "  PASS: A CIF(z=0)=p(1-e^-t) (max abs err=`=string(`maxerr',"%6.4f")')"
    local ++pass_count
}
else {
    display as error "  FAIL: A CIF at z=0 (rc=`=_rc')"
    local ++fail_count
}

**# Scenario B: CIF at profile z1=1 vs 1-(1-p*(1-exp(-t)))^exp(b)

local ++test_count
capture noisily {
    _fg_cif_dgp, n(120000) p(0.4) b(0.5) seed(302)
    quietly stset time, failure(anyevent==1) id(id)
    quietly finegray z1, compete(status) cause(1)
    quietly finegray_cif, at(z1=1) attime(1 2 3)
    matrix _T = r(table)
    local maxerr = 0
    forvalues r = 1/3 {
        local tt    = _T[`r', 1]
        local cif   = _T[`r', 2]
        local truth = 1 - (1 - 0.4*(1 - exp(-`tt')))^exp(0.5)
        local e = abs(`cif' - `truth')
        if `e' > `maxerr' local maxerr = `e'
        assert `e' < `TOLT'
    }
}
if _rc == 0 {
    display as result "  PASS: B CIF(z=1) vs analytic (max abs err=`=string(`maxerr',"%6.4f")')"
    local ++pass_count
}
else {
    display as error "  FAIL: B CIF at z=1 (rc=`=_rc')"
    local ++fail_count
}

**# Scenario C: plateau F1(large t; z=0) approaches p

local ++test_count
capture noisily {
    _fg_cif_dgp, n(120000) p(0.4) b(0.5) seed(303)
    quietly stset time, failure(anyevent==1) id(id)
    quietly finegray z1, compete(status) cause(1)
    quietly finegray_cif, at(z1=0) attime(5)
    matrix _T = r(table)
    * F1(5;0) = 0.4*(1-e^-5) = 0.39730; asserting against the analytic value
    * (not the raw plateau p) keeps this an exact oracle.
    local cif = _T[1, 2]
    local truth = 0.4*(1 - exp(-5))
    assert abs(`cif' - `truth') < `TOLT'
}
if _rc == 0 {
    display as result "  PASS: C plateau CIF(5;0) (cif=`=string(`cif',"%6.4f")', truth=`=string(`truth',"%6.4f")')"
    local ++pass_count
}
else {
    display as error "  FAIL: C plateau (rc=`=_rc')"
    local ++fail_count
}

**# Scenario D: CIF curve is monotone nondecreasing and within [0,1]

local ++test_count
capture noisily {
    _fg_cif_dgp, n(60000) p(0.4) b(0.5) seed(304)
    quietly stset time, failure(anyevent==1) id(id)
    quietly finegray z1, compete(status) cause(1)
    quietly finegray_cif, at(z1=0) attime(0.25 0.5 1 1.5 2 3 4)
    matrix _T = r(table)
    local nr = rowsof(_T)
    local prev = -1
    forvalues r = 1/`nr' {
        local cif = _T[`r', 2]
        assert `cif' >= -1e-9 & `cif' <= 1 + 1e-9
        assert `cif' >= `prev' - 1e-6
        local prev = `cif'
    }
}
if _rc == 0 {
    display as result "  PASS: D CIF monotone in [0,1]"
    local ++pass_count
}
else {
    display as error "  FAIL: D monotone/bounds (rc=`=_rc')"
    local ++fail_count
}

**# Scenario E: higher baseline incidence p=0.6, CIF at z=0

local ++test_count
capture noisily {
    _fg_cif_dgp, n(120000) p(0.6) b(0.4) seed(305)
    quietly stset time, failure(anyevent==1) id(id)
    quietly finegray z1, compete(status) cause(1)
    quietly finegray_cif, at(z1=0) attime(0.5 1 2)
    matrix _T = r(table)
    local maxerr = 0
    forvalues r = 1/3 {
        local tt    = _T[`r', 1]
        local cif   = _T[`r', 2]
        local truth = 0.6*(1 - exp(-`tt'))
        local e = abs(`cif' - `truth')
        if `e' > `maxerr' local maxerr = `e'
        assert `e' < `TOLT'
    }
}
if _rc == 0 {
    display as result "  PASS: E CIF(z=0) p=0.6 (max abs err=`=string(`maxerr',"%6.4f")')"
    local ++pass_count
}
else {
    display as error "  FAIL: E CIF p=0.6 (rc=`=_rc')"
    local ++fail_count
}

**# Summary

display as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    display "RESULT: validation_finegray_cif_recovery tests=`test_count' pass=`pass_count' fail=`fail_count'"
    log close _cifr
    exit 1
}
display as result "ALL TESTS PASSED"
display "RESULT: validation_finegray_cif_recovery tests=`test_count' pass=`pass_count' fail=`fail_count'"
log close _cifr
