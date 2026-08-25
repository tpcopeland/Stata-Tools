* validation_bstrata_recovery.do
* Known-truth parameter recovery for bstrata(): stratified Fine-Gray.
*
* The cross-validation against crrSC::crrs (crossval_bstrata.do) can check the
* COEFFICIENTS and nothing else -- crrs returns no baseline in either of its
* asymptotic regimes, which is exactly the quantity bstrata() adds.  This file
* is the oracle for the other half.
*
* DGP.  The Fine-Gray subdistribution model with a STRATUM-SPECIFIC mass:
*
*   F1k(t; z) = 1 - (1 - p_k * (1 - exp(-t)))^exp(z'b)
*
* so within stratum k the baseline cumulative subdistribution hazard is
*
*   L10k(t) = -ln(1 - p_k * (1 - exp(-t)))
*
* and b is SHARED across strata.  That is precisely the model of Zhou, Latouche,
* Rocha & Fine (2011): unconstrained baseline per stratum, common covariate
* effect.  Both halves are known in closed form, so both are asserted:
*
*   A  b is recovered at large N.
*   B  each stratum's cumulative baseline is recovered on a grid of times.
*   C  the POOLED fit's single baseline cannot be right for every stratum --
*      it must miss the truth by far more than the stratified fit does.  Without
*      this arm a build in which bstrata() were parsed and ignored would pass
*      A and B on nothing but the fact that b is nearly common anyway.
*   D  K = 1 recovers what the unstratified estimator recovers, bit for bit.

clear all
set varabbrev off
version 16.0

capture log close _all
log using "validation_bstrata_recovery.log", replace name(_bsrec)

local test_count = 0
local pass_count = 0
local fail_count = 0

* Recovery tolerance for b.  Same basis as validation_finegray_recovery.do: the
* Monte-Carlo SE of each coefficient is ~0.01 at these N and stratum sizes, so
* 0.04 is ~4x the SE and well below the 0.2-0.9 signal the arms carry.
local TOL = 0.04
* Baseline tolerance.  L10k(t) is O(0.3-1.0) here; 0.05 absolute is ~5-15% and
* is far tighter than the 0.3-0.8 gap between the strata's own curves, which is
* what arm C measures against.
local BTOL = 0.05

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
capture ado uninstall finegray
quietly net install finegray, from("`pkg_dir'") replace

* Stratified Fine-Gray DGP.  plist gives p_k for k = 1..K in order; every
* subject is assigned a stratum by round-robin so the strata are balanced and
* the covariates are independent of stratum (a confounded assignment would make
* arm C's contrast about confounding rather than about the baseline).
capture program drop _gen_fgs_dgp
program define _gen_fgs_dgp
    version 16.0
    syntax , n(integer) plist(numlist) [seed(integer 1) b1(real 0) b2(real 0)]
    local K : word count `plist'
    clear
    set seed `seed'
    quietly set obs `n'
    gen long id = _n
    gen byte ctr = 1 + mod(_n - 1, `K')
    gen double pk = .
    local k = 0
    foreach p of local plist {
        local ++k
        quietly replace pk = `p' if ctr == `k'
    }
    gen double z1 = rnormal()
    gen double z2 = rnormal()
    gen double lp = `b1' * z1 + `b2' * z2
    gen double pz = 1 - (1 - pk)^exp(lp)
    gen double u  = runiform()
    gen byte cause = cond(runiform() < pz, 1, 2)
    gen double t1 = -ln(1 - (1 - (1 - u * pz)^exp(-lp)) / pk)
    gen double t2 = -ln(runiform())
    gen double tevent = cond(cause == 1, t1, t2)
    gen double c = runiform() * 4
    gen double time = min(tevent, c)
    gen byte status = cond(tevent <= c, cause, 0)
    gen byte anyevent = status > 0
    quietly stset time, failure(anyevent == 1) id(id)
end

* Read the fitted cumulative baseline for stratum `lev' at time `at' out of a
* K x 3 e(basehaz) matrix (or a K x 2 one, when lev is missing).  A step
* function: the last row at or before `at'.
capture program drop _bsrec_h0
program define _bsrec_h0, rclass
    version 16.0
    syntax , matrix(name) at(real) [lev(string)]
    tempname H
    matrix `H' = `matrix'
    local n = rowsof(`H')
    local tcol = cond("`lev'" == "", 1, 2)
    local ccol = cond("`lev'" == "", 2, 3)
    local val = 0
    forvalues r = 1/`n' {
        if "`lev'" != "" {
            if `H'[`r', 1] != `lev' continue
        }
        if `H'[`r', `tcol'] <= `at' local val = `H'[`r', `ccol']
    }
    return scalar h0 = `val'
end

* -----------------------------------------------------------------------------
**# A: the shared coefficient vector is recovered
* -----------------------------------------------------------------------------
local ++test_count
capture noisily {
    _gen_fgs_dgp, n(60000) plist(0.25 0.45 0.65) b1(0.5) b2(-0.4) seed(20260824)
    quietly finegray z1 z2, compete(status) cause(1) nolog bstrata(ctr) basehaz
    assert e(converged) == 1
    assert e(k_bstrata) == 3
    local _A1 = _b[z1]
    local _A2 = _b[z2]
    assert abs(`_A1' - 0.5) < `TOL'
    assert abs(`_A2' + 0.4) < `TOL'
    matrix _Abh = e(basehaz)
}
if _rc == 0 {
    display as result "  PASS: A shared b recovered (z1=`=string(`_A1',"%6.4f")', z2=`=string(`_A2',"%6.4f")')"
    local ++pass_count
}
else {
    display as error "  FAIL: A shared b recovery (rc=`=_rc')"
    local ++fail_count
}

* -----------------------------------------------------------------------------
**# B: every stratum's cumulative baseline is recovered
* -----------------------------------------------------------------------------
* L10k(t) = -ln(1 - p_k*(1 - exp(-t))).  This is the quantity no reference
* implementation supplies, and the one a "runs the scan once, pooled" build gets
* wrong while still returning a plausible b.
local ++test_count
capture noisily {
    local _Bmaxerr = 0
    local _k = 0
    foreach p in 0.25 0.45 0.65 {
        local ++_k
        foreach at in 0.25 0.5 1.0 2.0 {
            local truth = -ln(1 - `p' * (1 - exp(-`at')))
            _bsrec_h0, matrix(_Abh) at(`at') lev(`_k')
            local got = r(h0)
            local err = abs(`got' - `truth')
            if `err' > `_Bmaxerr' local _Bmaxerr = `err'
            assert `err' < `BTOL'
        }
    }
}
if _rc == 0 {
    display as result "  PASS: B per-stratum baseline recovered (max |err| = `=string(`_Bmaxerr',"%7.5f")')"
    local ++pass_count
}
else {
    display as error "  FAIL: B per-stratum baseline recovery (rc=`=_rc')"
    local ++fail_count
}

* -----------------------------------------------------------------------------
**# C: the pooled fit's one baseline cannot be right for every stratum
* -----------------------------------------------------------------------------
* The discriminating arm.  A build that parsed bstrata() and ignored it would
* pass A (b is shared, so the pooled fit still estimates it reasonably) and
* would pass B only if the pooled curve happened to sit on all three truths --
* which it cannot, because the three truths differ by 0.3-0.8 at t = 2.
local ++test_count
capture noisily {
    quietly finegray z1 z2, compete(status) cause(1) nolog basehaz
    matrix _Cbh = e(basehaz)
    assert colsof(_Cbh) == 2

    local _Cworst_pool = 0
    local _Cworst_strat = 0
    local _k = 0
    foreach p in 0.25 0.45 0.65 {
        local ++_k
        local at = 2.0
        local truth = -ln(1 - `p' * (1 - exp(-`at')))
        _bsrec_h0, matrix(_Cbh) at(`at')
        local errp = abs(r(h0) - `truth')
        _bsrec_h0, matrix(_Abh) at(`at') lev(`_k')
        local errs = abs(r(h0) - `truth')
        if `errp' > `_Cworst_pool'  local _Cworst_pool = `errp'
        if `errs' > `_Cworst_strat' local _Cworst_strat = `errs'
    }
    * The pooled curve must be badly wrong SOMEWHERE, and the stratified one
    * right everywhere.  Both halves are asserted: "pooled is worse on average"
    * would be satisfied by a stratified fit that is merely noisier.
    assert `_Cworst_pool' > 10 * `_Cworst_strat'
    assert `_Cworst_pool' > 0.15
}
if _rc == 0 {
    display as result ///
        "  PASS: C pooled baseline misses by `=string(`_Cworst_pool',"%6.4f")', stratified by `=string(`_Cworst_strat',"%6.4f")'"
    local ++pass_count
}
else {
    display as error "  FAIL: C pooled-vs-stratified baseline contrast (rc=`=_rc')"
    local ++fail_count
}

* -----------------------------------------------------------------------------
**# D: K = 1 is the unstratified estimator, bit for bit
* -----------------------------------------------------------------------------
* Repeated from test_finegray_bstrata.do on purpose: this file runs at N =
* 20,000 on a different DGP, and the identity has to hold for the DATA, not for
* one fixture.
local ++test_count
capture noisily {
    _gen_fgs_dgp, n(20000) plist(0.4) b1(0.5) b2(-0.4) seed(20260824)
    quietly finegray z1 z2, compete(status) cause(1) nolog basehaz
    matrix _Db = e(b)
    matrix _DV = e(V)
    matrix _Dh = e(basehaz)
    scalar _Dll = e(ll)
    quietly finegray z1 z2, compete(status) cause(1) nolog basehaz bstrata(ctr)
    assert e(k_bstrata) == 1
    assert e(ll) == _Dll
    mata: st_numscalar("_Ddb", max(abs(st_matrix("e(b)") - st_matrix("_Db"))))
    mata: st_numscalar("_DdV", max(abs(st_matrix("e(V)") - st_matrix("_DV"))))
    mata: st_numscalar("_Ddh", max(abs(st_matrix("e(basehaz)") - st_matrix("_Dh"))))
    assert _Ddb == 0
    assert _DdV == 0
    assert _Ddh == 0
}
if _rc == 0 {
    display as result "  PASS: D K=1 reproduces the unstratified fit bit-identically"
    local ++pass_count
}
else {
    display as error "  FAIL: D K=1 bit-identity (rc=`=_rc')"
    local ++fail_count
}

**# Summary
display as text _newline ///
    "RESULT: validation_bstrata_recovery tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    log close _bsrec
    exit 1
}
display as result "ALL TESTS PASSED"
log close _bsrec
