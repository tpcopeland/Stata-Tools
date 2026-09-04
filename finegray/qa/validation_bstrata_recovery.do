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
* Replication attrition in arm E; reported in the RESULT line.
local _drop_tot = 0
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
    syntax , n(integer) plist(numlist) ///
        [seed(integer 1) b1(real 0) b2(real 0) CMAX(real 4)]
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
    * Censoring ~ U(0, cmax).  cmax defaults to 4, which is what arms A-D were
    * measured with and must keep.  Arm E lowers it: the psi term exists BECAUSE
    * Ghat is estimated, so its size is driven by how much of Ghat's tail the
    * data have to estimate, and at cmax = 4 on this DGP psi moves the standard
    * error by well under a tenth of a percent -- too little for a calibration
    * arm to be evidence about it.
    gen double c = runiform() * `cmax'
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

* -----------------------------------------------------------------------------
**# E  SE CALIBRATION under bstrata(): eta-only vs eta+psi (2026-08-26)
* -----------------------------------------------------------------------------
* Arms A-D are about the POINT estimates.  The variance unification made `nuisance' legal with
* bstrata(), so the variance now needs an oracle of its own, and the one that
* does not depend on R is calibration against the sampling distribution the DGP
* actually has: across independent replicates the empirical SD of beta-hat IS
* the truth, and a correct standard error estimates it.
*
* WHY THIS IS THE RIGHT ARM AND NOT A DUPLICATE OF crossval_bstrata.do.  That
* file compares finegray's eta+psi variance to crrs's -- two implementations of
* one FORMULA.  If the formula were wrong they would agree with each other and
* both be wrong.  This arm has no formula in it: it measures whether the
* reported SE matches the spread that repeated sampling produces.
*
* THE CLAIM, from Zhou (2011) sec. 4.1 read together with Fine & Gray (1999)
* sec. 4: Ghat is ESTIMATED, and psi is the term that accounts for it.  So under
* estimated G the psi arm must be at least as well calibrated as the eta-only
* arm -- not merely different from it.  Both directions are asserted:
*   E1  the eta+psi SE/SD ratio is within Monte-Carlo tolerance of 1
*   E2  it is no FURTHER from 1 than the eta-only ratio (the plan's condition)
*   E3  eta+psi CI coverage is within Monte-Carlo tolerance of the nominal 0.95
*   E4  and not below the eta-only coverage by more than Monte-Carlo noise
* E2 and E4 are what a psi term with the wrong sign, or one that is simply
* noise, fails; E1 and E3 are what a missing one fails.
*
* Both fits use bstrata(ctr) strata(ctr) -- Zhou's regularly-stratified regime,
* where Ghat is the within-stratum KM (sec. 3.2) and the psi term is the one the
* paper defines.  noadjust on both, so the finite-sample N/(N-1) factor is not
* what either ratio is measuring.
local ++test_count
capture noisily {
    local REPS   = 300
    local NOBS   = 500
    local B1TRUE = 0.50
    local B2TRUE = -0.40
    * HOW BIG IS psi, AND WHAT THIS ARM CAN THEREFORE PROVE.
    *
    * Measured on 2026-08-26 at n = 4000, K = 3, sweeping the censoring
    * distribution: the psi term moves the reported SE by
    *
    *   U(0, cmax)      cmax = 0.5  1.0  1.5  2.0  3.0  4.0  8.0
    *                   rel move  0.4e-4 2e-4 6e-4 9e-4 7e-4 6e-4 1e-4
    *   Exponential     rate  0.3  0.6  1.0  2.0
    *                   rel move  4e-4 10e-4 9e-4 11e-4
    *
    * i.e. AT MOST about a tenth of one percent, on every design tried, and
    * smallest when there is very little censoring (nothing to estimate) or very
    * much (nothing left to be at risk).  psi is a genuinely small refinement on
    * well-behaved competing-risks data.
    *
    * That is a fact about the estimator, not a defect, but it has a consequence
    * this arm must be honest about: a calibration comparison at 300 replicates
    * has Monte-Carlo noise of order 10% in the SE/SD ratio, which is two orders
    * LARGER than the effect being looked for.  So E1-E4 below cannot detect a
    * subtly wrong psi term, and they are not claimed to.  What they do prove is
    * that the corrected variance is calibrated at all and is not made worse.
    *
    * The SHARP tests for psi are elsewhere and are pointed at deliberately:
    *   crossval_bstrata.do  eta+psi vs crrs ctype=1 -- 3.1e-08 with psi against
    *                        2.5e-03 without, five orders of separation
    *   BSPSI-5 (test_finegray_bstrata.do)  the duplicate-stratum identity,
    *                        which halves e(V) exactly only if every stratum's
    *                        psi block is present
    *
    * E0 below still refuses a psi term that returns exactly zero, so this arm
    * is not vacuous -- it is simply not the precision instrument.
    *
    * Exponential censoring at rate 2.0: the design where psi measured largest.
    local CRATE  = 2.0
    local PSIMIN = 0.0002

    tempname pf
    tempfile calib
    postfile `pf' int rep double(b1 b2 b1p b2p se1e se2e se1p se2p) ///
        using "`calib'", replace

    * Replication attrition, counted rather than absorbed.  Each `continue'
    * below silently discards a replication; a design or an estimator that
    * dropped most of them would still satisfy the >= 90% gate only by
    * accident, and nothing said how many had gone or why.
    local _drop_efit = 0
    local _drop_pfit = 0
    local _drop_moved = 0

    forvalues r = 1/`REPS' {
        _gen_fgs_dgp, n(`NOBS') plist(0.55 0.70 0.40) seed(`= 900000 + `r'') ///
            b1(`B1TRUE') b2(`B2TRUE')
        * re-censor exponentially; the generator's own U(0, cmax) is kept for
        * arms A-D, whose measured numbers are pinned to it
        quietly replace c = rexponential(1 / `CRATE')
        quietly replace time = min(tevent, c)
        quietly replace status = cond(tevent <= c, cause, 0)
        quietly replace anyevent = status > 0
        quietly stset time, failure(anyevent == 1) id(id)
        capture quietly finegray z1 z2, compete(status) cause(1) nolog ///
            bstrata(ctr) strata(ctr) noadjust
        if _rc | e(converged) != 1 {
            local ++_drop_efit
            continue
        }
        local _b1 = _b[z1]
        local _b2 = _b[z2]
        local _s1e = _se[z1]
        local _s2e = _se[z2]

        capture quietly finegray z1 z2, compete(status) cause(1) nolog ///
            bstrata(ctr) strata(ctr) nuisance noadjust
        if _rc | e(converged) != 1 {
            local ++_drop_pfit
            continue
        }
        * psi must not have moved the point estimate; if it did, this whole
        * arm is measuring two different estimators.  BOTH coefficients are
        * checked: guarding z1 alone left a z2 that had moved to be posted
        * beside the eta-only fit's b2, pairing one estimator's point estimate
        * with the other's standard error.
        if reldif(_b[z1], `_b1') > 1e-8 | reldif(_b[z2], `_b2') > 1e-8 {
            local ++_drop_moved
            continue
        }
        * The nuisance fit's own coefficients are posted alongside, so the
        * "psi did not move beta" claim is auditable from the saved data
        * rather than only from the guard that enforced it.
        post `pf' (`r') (`_b1') (`_b2') (_b[z1]) (_b[z2]) ///
            (`_s1e') (`_s2e') (_se[z1]) (_se[z2])
    }
    postclose `pf'
    local _drop_tot = `_drop_efit' + `_drop_pfit' + `_drop_moved'
    display as text "  E replications dropped: " as result `_drop_tot' ///
        as text " of `REPS' (eta-only fit " as result `_drop_efit' ///
        as text ", eta+psi fit " as result `_drop_pfit' ///
        as text ", beta moved " as result `_drop_moved' as text ")"

    use "`calib'", clear
    quietly count
    local NREP = r(N)
    assert !missing(`NREP')
    assert `NREP' >= 0.9 * `REPS'
    assert `NREP' + `_drop_tot' == `REPS'
    * the posted nuisance-fit coefficients are the eta-only ones, to the
    * tolerance the guard enforced
    assert !missing(b1, b2, b1p, b2p)
    assert reldif(b1, b1p) <= 1e-8 & reldif(b2, b2p) <= 1e-8

    * Monte-Carlo tolerances, computed from NREP rather than chosen.  The SD of
    * an SD estimate over m reps is about SD/sqrt(2m); three of those is the
    * band.  For 300 reps that is ~12%.
    local RTOL = 3 / sqrt(2 * `NREP')
    * coverage: 3 binomial SEs at p = 0.95
    local CTOL = 3 * sqrt(0.95 * 0.05 / `NREP')

    foreach v in 1 2 {
        if `v' == 1 local truth = `B1TRUE'
        else        local truth = `B2TRUE'
        quietly summarize b`v'
        local sd_emp = r(sd)
        local mean_b = r(mean)
        assert !missing(`sd_emp', `mean_b')
        assert `sd_emp' > 0

        quietly summarize se`v'e
        local se_eta = r(mean)
        quietly summarize se`v'p
        local se_psi = r(mean)
        assert !missing(`se_eta', `se_psi')
        assert `se_eta' > 0 & `se_psi' > 0

        local rat_eta = `se_eta' / `sd_emp'
        local rat_psi = `se_psi' / `sd_emp'
        local psi_size = abs(`se_psi' - `se_eta') / `se_eta'

        quietly count if abs(b`v' - `truth') <= 1.959963985 * se`v'e
        local cov_eta = r(N) / `NREP'
        quietly count if abs(b`v' - `truth') <= 1.959963985 * se`v'p
        local cov_psi = r(N) / `NREP'

        display as text "    z`v': empirical SD = " as result %8.5f `sd_emp' ///
            as text ", mean SE eta-only = " as result %8.5f `se_eta' ///
            as text " (ratio " as result %6.4f `rat_eta' as text ")" ///
            as text ", eta+psi = " as result %8.5f `se_psi' ///
            as text " (ratio " as result %6.4f `rat_psi' as text ")" ///
            as text "; psi moves the mean SE by " as result %6.4f `psi_size'
        display as text "    z`v': coverage eta-only = " as result %6.4f `cov_eta' ///
            as text ", eta+psi = " as result %6.4f `cov_psi' ///
            as text " (nominal 0.95, MC tol " as result %6.4f `CTOL' as text ")"

        * E0 -- the arm must actually be able to see psi.  Without this, a psi
        * term returning exactly zero passes E1-E4 by being identical to the
        * eta-only arm, which is calibrated.
        assert !missing(`psi_size')
        assert `psi_size' > `PSIMIN'
        * E1
        assert abs(`rat_psi' - 1) < `RTOL'
        * E2 -- psi must not be WORSE calibrated than eta-only.  A small slack
        * is allowed because both are estimates of the same ratio; what this
        * refuses is a psi term that moves the SE the wrong way.
        assert abs(`rat_psi' - 1) <= abs(`rat_eta' - 1) + `RTOL' / 3
        * E3
        assert abs(`cov_psi' - 0.95) < `CTOL'
        * E4
        assert `cov_psi' >= `cov_eta' - `CTOL'
    }
}
if _rc == 0 {
    display as result ///
        "  PASS: E eta+psi SEs under bstrata() are calibrated and no worse than eta-only"
    local ++pass_count
}
else {
    display as error "  FAIL: E bstrata() SE calibration (rc=`=_rc')"
    local ++fail_count
}

**# Summary
display as text _newline ///
    "RESULT: validation_bstrata_recovery tests=`test_count' pass=`pass_count' fail=`fail_count' repdrop=`_drop_tot'"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    log close _bsrec
    exit 1
}
display as result "ALL TESTS PASSED"
log close _bsrec
