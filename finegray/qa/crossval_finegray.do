* crossval_finegray.do - Cross-validation suite for finegray package
* Tests: systematic vs stcrreg, strata, robust/cluster SEs, CIF, DGP, R oracles
* Package: finegray v1.2.0

clear all
set more off
set varabbrev off
version 16.0

local test_count = 0
local pass_count = 0
local fail_count = 0
local skip_count = 0

local pkgroot "`c(pwd)'"
capture confirm file "`pkgroot'/finegray.pkg"
if _rc {
    capture confirm file "`pkgroot'/../finegray.pkg"
    if _rc {
        display as error "could not locate finegray package root"
        exit 601
    }
    local pkgroot "`pkgroot'/.."
}
local qadir "`pkgroot'/qa"
* Generated R cross-check CSVs are transient: write them to a temp directory so
* nothing lands in (or churns) the tracked qa/ tree, and so a failed/absent R
* run cannot silently validate against a stale committed copy (matches
* crossval_cif.do, which already uses c(tmpdir)).
* Run-unique output directory.  A fixed directory let an old R CSV survive a
* failed Rscript call and satisfy the later file-exists check.
tempfile _cv_anchor
local datadir "`_cv_anchor'_dir"
capture mkdir "`datadir'"

capture log close _all
log using "`qadir'/crossval_finegray.log", ///
    replace text name(_crossval_finegray)

* {smcl}
* {* SETUP}{...}
* The install goes into an ISOLATED PLUS, not the user's.  A crossval that
* runs `net install finegray, replace' into the default PLUS replaces whatever
* build the user has installed -- and, worse, a concurrent reinstall from
* another lane swaps the build under test mid-run (observed 2026-08-29).
* `_finegray_qa_bootstrap' points sysdir PLUS/PERSONAL at a process-unique
* temporary directory first, which is what every test_*.do here already does.
do "`qadir'/_finegray_qa_common.do"
quietly _finegray_qa_bootstrap

program define _finegray_use_hypoxia
    local cache "`c(tmpdir)'/finegray_hypoxia_cache.dta"
    capture confirm file "`cache'"
    if _rc {
        webuse hypoxia, clear
        quietly save "`cache'", replace
    }
    else {
        use "`cache'", clear
    }
end

program define _setup_hypoxia
    _finegray_use_hypoxia
    gen byte status = failtype
    stset dftime, failure(dfcens==1) id(stnum)
end

* finegray follows stcrreg's public convention of posting the last iterate with
* rc=0 when it does not converge.  Every fit in this cross-validation file is
* expected to converge, so make that condition part of every comparison rather
* than allowing a partial estimate to count as parity.
program define _finegray_xv
    finegray `0'
    assert e(converged) == 1
    assert e(ll) < . & e(ll_0) < .
    mata: assert(!hasmissing(st_matrix("e(b)")))
    mata: assert(!hasmissing(st_matrix("e(V)")))
end

* TOLERANCE 2e-6 for C1-C5 (was 1e-4, which could not fail).  finegray and
* stcrreg solve the SAME estimating equation on these data, so the only source
* of disagreement is where the two solvers stop.  MEASURED 2026-09-02 on the
* hypoxia fixture and echoed by each test below: C1 1.657e-08, C2 2.853e-10,
* C3 2.201e-12, C4 1.202e-08, C5 1.588e-07.  2e-6 is about 13x the largest of
* them; 1e-4 was 600x it and would have accepted a coefficient wrong in its
* fourth decimal on a comparison that agrees in its seventh.
local tol = 2e-6

* {smcl}
* {* SECTION 1: finegray vs stcrreg — covariate combinations}{...}

* C1: 2-cov cause 1
local ++test_count
capture noisily {
    _setup_hypoxia
    preserve
    stset dftime, failure(status==1) id(stnum)
    stcrreg ifp tumsize, compete(status == 2)
    matrix b_ref = e(b)
    restore
    _finegray_xv ifp tumsize, compete(status) cause(1) nolog
    matrix b_fg = e(b)
    local _c1d = max(abs(b_fg[1,1] - b_ref[1,1]), abs(b_fg[1,2] - b_ref[1,2]))
    display as text "  C1 max|b_fg - b_stcrreg| = " %10.3e `_c1d'
    assert `_c1d' < `tol'
}
if _rc == 0 {
    display as result "  PASS: C1 2-cov cause 1 vs stcrreg"
    local ++pass_count
}
else {
    display as error "  FAIL: C1 2-cov cause 1 (rc=`=_rc')"
    local ++fail_count
}

* C2: 1-cov cause 2
local ++test_count
capture noisily {
    _setup_hypoxia
    preserve
    stset dftime, failure(status==2) id(stnum)
    stcrreg ifp, compete(status == 1)
    local b_ref = e(b)[1,1]
    restore
    _finegray_xv ifp, compete(status) cause(2) nolog
    local b_fg = e(b)[1,1]
    local _c2d = abs(`b_fg' - `b_ref')
    display as text "  C2 |b_fg - b_stcrreg| = " %10.3e `_c2d'
    assert `_c2d' < `tol'
}
if _rc == 0 {
    display as result "  PASS: C2 1-cov cause 2 vs stcrreg"
    local ++pass_count
}
else {
    display as error "  FAIL: C2 1-cov cause 2 (rc=`=_rc')"
    local ++fail_count
}

* C3: 3-cov cause 2
local ++test_count
capture noisily {
    _setup_hypoxia
    preserve
    stset dftime, failure(status==2) id(stnum)
    stcrreg ifp tumsize pelnode, compete(status == 1)
    matrix b_ref = e(b)
    restore
    _finegray_xv ifp tumsize pelnode, compete(status) cause(2) nolog
    matrix b_fg = e(b)
    local _c3d = 0
    forvalues i = 1/3 {
        local _c3d = max(`_c3d', abs(b_fg[1,`i'] - b_ref[1,`i']))
    }
    display as text "  C3 max|b_fg - b_stcrreg| = " %10.3e `_c3d'
    assert `_c3d' < `tol'
}
if _rc == 0 {
    display as result "  PASS: C3 3-cov cause 2 vs stcrreg"
    local ++pass_count
}
else {
    display as error "  FAIL: C3 3-cov cause 2 (rc=`=_rc')"
    local ++fail_count
}

* C4: 1-cov cause 1 (tumsize only)
local ++test_count
capture noisily {
    _setup_hypoxia
    preserve
    stset dftime, failure(status==1) id(stnum)
    stcrreg tumsize, compete(status == 2)
    local b_ref = e(b)[1,1]
    restore
    _finegray_xv tumsize, compete(status) cause(1) nolog
    local b_fg = e(b)[1,1]
    local _c4d = abs(`b_fg' - `b_ref')
    display as text "  C4 |b_fg - b_stcrreg| = " %10.3e `_c4d'
    assert `_c4d' < `tol'
}
if _rc == 0 {
    display as result "  PASS: C4 1-cov cause 1 (tumsize) vs stcrreg"
    local ++pass_count
}
else {
    display as error "  FAIL: C4 1-cov tumsize (rc=`=_rc')"
    local ++fail_count
}

* C5: 2-cov cause 2 (ifp pelnode)
local ++test_count
capture noisily {
    _setup_hypoxia
    preserve
    stset dftime, failure(status==2) id(stnum)
    stcrreg ifp pelnode, compete(status == 1)
    matrix b_ref = e(b)
    restore
    _finegray_xv ifp pelnode, compete(status) cause(2) nolog
    matrix b_fg = e(b)
    local _c5d = max(abs(b_fg[1,1] - b_ref[1,1]), abs(b_fg[1,2] - b_ref[1,2]))
    display as text "  C5 max|b_fg - b_stcrreg| = " %10.3e `_c5d'
    assert `_c5d' < `tol'
}
if _rc == 0 {
    display as result "  PASS: C5 2-cov cause 2 (ifp pelnode) vs stcrreg"
    local ++pass_count
}
else {
    display as error "  FAIL: C5 2-cov cause 2 (rc=`=_rc')"
    local ++fail_count
}

* {smcl}
* {* SECTION 2: SE cross-validation against stcrreg}{...}

* C6: Robust SEs vs stcrreg (3-cov cause 1)
* Note: Both use the sandwich estimator but different computational approaches
* (IPCW forward-backward scan vs data expansion).
* TOLERANCE 0.01.  The "Max observed diff ~13%" note this comment used to carry
* was wrong and had been for at least a release: MEASURED 2026-09-02 the three
* relative differences are 1.824e-04, 1.635e-04 and 8.099e-04 (echoed below).
* 0.01 is about 12x the largest.  The 0.15 that stood here was 185x it -- a gate
* that would have accepted an SE wrong by a seventh.
local ++test_count
capture noisily {
    _setup_hypoxia
    preserve
    stset dftime, failure(status==1) id(stnum)
    stcrreg ifp tumsize pelnode, compete(status == 2)
    matrix V_ref = e(V)
    restore
    _finegray_xv ifp tumsize pelnode, compete(status) cause(1) nolog
    matrix V_fg = e(V)
    forvalues i = 1/3 {
        local se_ref = sqrt(V_ref[`i',`i'])
        local se_fg = sqrt(V_fg[`i',`i'])
        local rel_diff = abs(`se_fg' - `se_ref') / `se_ref'
        display as text "  SE var `i': fg=" %8.5f `se_fg' " ref=" %8.5f `se_ref' ///
            " rel_diff=" %10.3e `rel_diff'
        assert `rel_diff' < 0.01
    }
}
if _rc == 0 {
    display as result "  PASS: C6 SEs vs stcrreg (< 1% rel diff)"
    local ++pass_count
}
else {
    display as error "  FAIL: C6 SEs vs stcrreg (rc=`=_rc')"
    local ++fail_count
}

* C7: SEs vs stcrreg (1-cov cause 2)
local ++test_count
capture noisily {
    _setup_hypoxia
    preserve
    stset dftime, failure(status==2) id(stnum)
    stcrreg ifp, compete(status == 1)
    local se_ref = sqrt(e(V)[1,1])
    restore
    _finegray_xv ifp, compete(status) cause(2) nolog
    local se_fg = sqrt(e(V)[1,1])
    local rel_diff = abs(`se_fg' - `se_ref') / `se_ref'
    display as text "  SE cause 2: fg=" %8.5f `se_fg' " ref=" %8.5f `se_ref' ///
        " rel_diff=" %10.3e `rel_diff'
    * TOLERANCE 0.005.  MEASURED 2026-09-02: 3.001e-04 (echoed above), so this
    * is about 17x the measurement.  The 0.25 that stood here could not fail.
    assert `rel_diff' < 0.005
}
if _rc == 0 {
    display as result "  PASS: C7 SE cause 2 vs stcrreg (< 0.5%)"
    local ++pass_count
}
else {
    display as error "  FAIL: C7 SE cause 2 (rc=`=_rc')"
    local ++fail_count
}

* {smcl}
* {* SECTION 3: Log-likelihood and chi2 cross-validation}{...}

* C8: LL matches stcrreg
local ++test_count
capture noisily {
    _setup_hypoxia
    preserve
    stset dftime, failure(status==1) id(stnum)
    stcrreg ifp tumsize pelnode, compete(status == 2)
    local ll_ref = e(ll)
    restore
    _finegray_xv ifp tumsize pelnode, compete(status) cause(1) nolog
    local ll_fg = e(ll)
    local rel_diff = abs(`ll_fg' - `ll_ref') / abs(`ll_ref')
    assert `rel_diff' < 0.001
}
if _rc == 0 {
    display as result "  PASS: C8 LL matches stcrreg"
    local ++pass_count
}
else {
    display as error "  FAIL: C8 LL (rc=`=_rc')"
    local ++fail_count
}

* C9: ll > ll_0 (model improves on null)
local ++test_count
capture noisily {
    _setup_hypoxia
    _finegray_xv ifp tumsize pelnode, compete(status) cause(1) nolog
    assert !missing(e(ll))
    assert e(ll) > e(ll_0)
}
if _rc == 0 {
    display as result "  PASS: C9 ll > ll_0"
    local ++pass_count
}
else {
    display as error "  FAIL: C9 ll > ll_0 (rc=`=_rc')"
    local ++fail_count
}

* {smcl}
* {* SECTION 4: Robust SE cross-validation}{...}

* C10: Robust SEs vs stcrreg robust
local ++test_count
capture noisily {
    _setup_hypoxia
    preserve
    stset dftime, failure(status==1) id(stnum)
    stcrreg ifp tumsize, compete(status == 2)
    matrix V_ref = e(V)
    restore
    _finegray_xv ifp tumsize, compete(status) cause(1) nolog
    matrix V_fg = e(V)
    forvalues i = 1/2 {
        local se_ref = sqrt(V_ref[`i',`i'])
        local se_fg = sqrt(V_fg[`i',`i'])
        local ratio = `se_fg' / `se_ref'
        display as text "  robust SE ratio var `i': " %6.3f `ratio'
        assert `ratio' > 0.95 & `ratio' < 1.05
    }
}
if _rc == 0 {
    display as result "  PASS: C10 robust SEs vs stcrreg (ratio 0.95-1.05)"
    local ++pass_count
}
else {
    display as error "  FAIL: C10 robust SEs (rc=`=_rc')"
    local ++fail_count
}

* {smcl}
* {* SECTION 5: strata cross-validation}{...}

* C11: strata() moves the estimate, and only a little
* The numbers themselves are cross-validated against crr(cengroup=) in C51/C52.
* What is left for this test is the DISCRIMINATING claim its name makes: that
* strata() is not a no-op.  The old form asserted only an upper bound of 50%
* relative divergence, which two unrelated numbers satisfy -- a strata() that
* silently fell back to the pooled censoring KM passed it.  Both bounds are
* now tied to the measured fixture: on hypoxia with strata(pelnode) the shift
* is 2.2e-4 (ifp) and 2.1e-3 (tumsize), the same .002 on tumsize that C51's
* header records as the pooled-accumulator regression.  The floor sits four
* orders above the 1e-8 convergence tolerance, so it cannot be met by
* optimizer noise; the ceiling keeps a 6x margin over the observed 0.8%.
local ++test_count
capture noisily {
    _setup_hypoxia
    _finegray_xv ifp tumsize, compete(status) cause(1) nolog
    matrix b_nostrata = e(b)
    _finegray_xv ifp tumsize, compete(status) cause(1) nolog strata(pelnode)
    matrix b_strata = e(b)
    * Both should be non-zero (model ran)
    assert b_strata[1,1] != 0
    assert b_strata[1,2] != 0
    local c11_moved = 0
    forvalues j = 1/2 {
        local c11_ad = abs(b_strata[1,`j'] - b_nostrata[1,`j'])
        local c11_rd = `c11_ad' / abs(b_nostrata[1,`j'])
        display as text "  C11 col `j': absdiff=" %10.3e `c11_ad' ///
            "  reldiff=" %10.3e `c11_rd'
        * ceiling: a different censoring model, not a different model
        assert `c11_rd' < 0.05
        if `c11_ad' > 1e-5 local c11_moved = 1
    }
    * floor: at least one coefficient actually moved -- fails if strata() is
    * ignored and the pooled censoring KM is used for both fits
    assert `c11_moved' == 1
}
if _rc == 0 {
    display as result "  PASS: C11 strata() moves the estimate (>1e-5), by < 5%"
    local ++pass_count
}
else {
    display as error "  FAIL: C11 strata vs no strata (rc=`=_rc')"
    local ++fail_count
}

* C12: strata with CIF prediction
local ++test_count
capture noisily {
    _setup_hypoxia
    _finegray_xv ifp tumsize, compete(status) cause(1) nolog strata(pelnode)
    finegray_predict cif_strata, cif
    summ cif_strata, meanonly
    assert !missing(r(min))
    assert r(min) >= 0 & r(max) <= 1
    drop cif_strata
}
if _rc == 0 {
    display as result "  PASS: C12 strata CIF in [0,1]"
    local ++pass_count
}
else {
    display as error "  FAIL: C12 strata CIF (rc=`=_rc')"
    local ++fail_count
}

* {smcl}
* {* SECTION 6: Predict cross-validation}{...}

* C13: xb + basehaz → CIF consistency
local ++test_count
capture noisily {
    _setup_hypoxia
    _finegray_xv ifp tumsize pelnode, compete(status) cause(1) nolog basehaz
    finegray_predict xb_hat, xb
    finegray_predict cif_hat, cif
    matrix bh = e(basehaz)
    local nr = rowsof(bh)
    * Check that xb and cif are correlated (same direction)
    * and CIF is in valid range — precision of step function lookup in
    * Stata locals vs Mata binary search can differ, so avoid pointwise
    * comparison
    summ cif_hat, meanonly
    assert !missing(r(min))
    assert r(min) >= 0 & r(max) <= 1
    * CIF depends on both xb and _t, so correlation with xb alone is moderate
    spearman xb_hat cif_hat
    display as text "  xb-CIF Spearman rho = " %6.4f r(rho)
    assert !missing(r(rho))
    assert r(rho) > 0.5 & r(rho) < .
    drop xb_hat cif_hat
}
if _rc == 0 {
    display as result "  PASS: C13 xb+basehaz → CIF consistency"
    local ++pass_count
}
else {
    display as error "  FAIL: C13 CIF consistency (rc=`=_rc')"
    local ++fail_count
}

* {smcl}
* {* SECTION 7: Simulated DGP cross-validation}{...}

* C14: Simulated data — known beta, recover direction
local ++test_count
capture noisily {
    clear
    set seed 42
    set obs 1000
    gen id = _n
    gen double x1 = rnormal()
    gen double x2 = rbinomial(1, 0.5)
    * True beta: x1=0.5, x2=-0.3
    gen double h = exp(0.5*x1 - 0.3*x2)
    gen double u = runiform()
    gen double t_event = -ln(u) / h
    gen double t_censor = runiform() * 5
    gen double t = min(t_event, t_censor)
    gen byte d = (t_event <= t_censor)
    * Competing risk: 30% of events become competing
    gen byte status = 0
    replace status = 1 if d == 1 & runiform() > 0.3
    replace status = 2 if d == 1 & status == 0
    stset t, failure(d) id(id)
    _finegray_xv x1 x2, compete(status) cause(1) nolog
    * Coefficients should have correct signs
    assert e(b)[1,1] > 0
    assert e(b)[1,2] < 0
    assert e(converged) == 1
}
if _rc == 0 {
    display as result "  PASS: C14 simulated DGP — correct sign recovery"
    local ++pass_count
}
else {
    display as error "  FAIL: C14 simulated DGP (rc=`=_rc')"
    local ++fail_count
}

* C15: Simulated data — finegray vs stcrreg on same DGP
local ++test_count
capture noisily {
    clear
    set seed 777
    set obs 500
    gen id = _n
    gen double x1 = rnormal()
    gen double u = runiform()
    gen double t_event = -ln(u) / exp(0.3*x1)
    gen double t_censor = runiform() * 4
    gen double t = min(t_event, t_censor)
    gen byte d = (t_event <= t_censor)
    gen byte status = 0
    replace status = 1 if d == 1 & runiform() > 0.4
    replace status = 2 if d == 1 & status == 0
    * finegray
    stset t, failure(d) id(id)
    _finegray_xv x1, compete(status) cause(1) nolog
    local b_fg = e(b)[1,1]
    * stcrreg
    stset t, failure(status==1) id(id)
    stcrreg x1, compete(status == 2)
    local b_ref = e(b)[1,1]
    local _c15d = abs(`b_fg' - `b_ref')
    display as text "  C15 |b_fg - b_stcrreg| = " %10.3e `_c15d'
    * TOLERANCE 1e-8.  Same estimating equation, seeded fixture; MEASURED
    * 2026-09-02: 1.446e-10.  The 0.001 that stood here was seven orders above
    * the measurement.
    assert `_c15d' < 1e-8
}
if _rc == 0 {
    display as result "  PASS: C15 simulated finegray vs stcrreg"
    local ++pass_count
}
else {
    display as error "  FAIL: C15 simulated vs stcrreg (rc=`=_rc')"
    local ++fail_count
}

* {smcl}
* {* SECTION 8: CIF mathematical properties}{...}

* C16: CIF at t=0 is 0 for all covariate patterns
local ++test_count
capture noisily {
    _setup_hypoxia
    _finegray_xv ifp tumsize pelnode, compete(status) cause(1) nolog
    gen double t_zero = 0
    finegray_predict cif_zero, cif timevar(t_zero)
    summ cif_zero, meanonly
    assert r(max) < 1e-10
    drop t_zero cif_zero
}
if _rc == 0 {
    display as result "  PASS: C16 CIF(0) = 0"
    local ++pass_count
}
else {
    display as error "  FAIL: C16 CIF(0) (rc=`=_rc')"
    local ++fail_count
}

* C17: CIF increases with time
local ++test_count
capture noisily {
    _setup_hypoxia
    _finegray_xv ifp tumsize pelnode, compete(status) cause(1) nolog
    gen double t_early = 2
    gen double t_late = 10
    finegray_predict cif_early, cif timevar(t_early)
    finegray_predict cif_late, cif timevar(t_late)
    * CIF at later time should be >= CIF at earlier time
    gen double diff = cif_late - cif_early
    summ diff, meanonly
    assert !missing(r(N))
    assert r(N) > 0 & r(min) >= -1e-10 & r(min) < .
    drop t_early t_late cif_early cif_late diff
}
if _rc == 0 {
    display as result "  PASS: C17 CIF increases with time"
    local ++pass_count
}
else {
    display as error "  FAIL: C17 CIF time monotone (rc=`=_rc')"
    local ++fail_count
}

* C18: Higher positive xb → higher CIF (at fixed time)
local ++test_count
capture noisily {
    _setup_hypoxia
    _finegray_xv ifp tumsize pelnode, compete(status) cause(1) nolog
    finegray_predict xb_hat, xb
    gen double t_fixed = 5
    finegray_predict cif_hat, cif timevar(t_fixed)
    * Rank correlation between xb and CIF should be positive
    spearman xb_hat cif_hat
    assert !missing(r(rho))
    assert r(rho) > 0.9 & r(rho) < .
    drop xb_hat t_fixed cif_hat
}
if _rc == 0 {
    display as result "  PASS: C18 higher xb → higher CIF"
    local ++pass_count
}
else {
    display as error "  FAIL: C18 xb-CIF correlation (rc=`=_rc')"
    local ++fail_count
}

* {smcl}
* {* SECTION 9: Extreme censoring stress test}{...}

* C19: High censoring (80%) — finegray vs stcrreg
local ++test_count
capture noisily {
    clear
    set seed 99
    set obs 500
    gen id = _n
    gen double x1 = rnormal()
    gen double u = runiform()
    gen double t_event = -ln(u) / exp(0.4*x1)
    * Heavy censoring
    gen double t_censor = runiform() * 1.5
    gen double t = min(t_event, t_censor)
    gen byte d = (t_event <= t_censor)
    gen byte status = 0
    replace status = 1 if d == 1 & runiform() > 0.5
    replace status = 2 if d == 1 & status == 0
    * finegray
    stset t, failure(d) id(id)
    _finegray_xv x1, compete(status) cause(1) nolog
    local b_fg = e(b)[1,1]
    * stcrreg
    stset t, failure(status==1) id(id)
    stcrreg x1, compete(status == 2)
    local b_ref = e(b)[1,1]
    * TOLERANCE 1e-7.  finegray and stcrreg solve the SAME estimating equation,
    * so the only source of disagreement is where the two solvers stop.
    * MEASURED 2026-09-01 on this seeded fixture: |b_fg - b_stcrreg| = 1.904e-09
    * (echoed below, so the next tightening has a number to read).  1e-7 is
    * about 50x that.  The 0.01 that stood here was a decision threshold, not a
    * numerical one: it would have accepted a coefficient wrong in its second
    * decimal on a comparison that agrees in its eighth.
    local c19_ad = abs(`b_fg' - `b_ref')
    display as text "  C19 |b_fg - b_stcrreg| = " %10.3e `c19_ad'
    assert `c19_ad' < 1e-7
}
if _rc == 0 {
    display as result "  PASS: C19 high censoring finegray vs stcrreg"
    local ++pass_count
}
else {
    display as error "  FAIL: C19 high censoring (rc=`=_rc')"
    local ++fail_count
}

* {smcl}
* {* SECTION 10: Cluster SE cross-validation}{...}

* C20: Cluster SEs — positive AND larger than model SEs under intra-cluster
* correlation.  The point of a cluster-robust SE is that it inflates when
* observations within a cluster are correlated; asserting only that it is
* positive (QA-H03) is vacuous -- it passes even when clustering makes NO
* difference.  The old DGP had essentially no within-cluster correlation, so the
* cluster SE was actually SMALLER than the model SE (0.06474 vs 0.06546), which
* is exactly why the assertion had been weakened to `> 0' and the pass message
* quietly renamed.  Fix the DGP, not the assertion: a shared cluster frailty now
* drives both x1 and the hazard, so the independence SE genuinely understates and
* the contrast the test is named for actually holds (ratio ~1.15).
local ++test_count
capture noisily {
    clear
    set seed 20260715
    set obs 60
    gen clid = _n
    gen double u_cl = rnormal()            // cluster random effect
    expand 20
    bysort clid: gen id = _n + 1000*clid
    gen double x1 = u_cl + 0.3*rnormal()   // x1 shares the cluster effect
    gen double frail = exp(1.2*u_cl)       // frailty on the hazard, same effect
    gen double u = runiform()
    gen double t_event = -ln(u) / (exp(0.3*x1) * frail)
    gen double t_censor = runiform() * 4
    gen double t = min(t_event, t_censor)
    gen byte d = (t_event <= t_censor)
    gen byte status = 0
    replace status = 1 if d == 1 & runiform() > 0.4
    replace status = 2 if d == 1 & status == 0
    stset t, failure(d) id(id)
    _finegray_xv x1, compete(status) cause(1) nolog
    local se_model = sqrt(e(V)[1,1])
    _finegray_xv x1, compete(status) cause(1) nolog cluster(clid)
    local se_cluster = sqrt(e(V)[1,1])
    assert `se_model' > 0 & `se_model' < .
    assert `se_cluster' > 0 & `se_cluster' < .
    display as text "  model SE=" %8.5f `se_model' " cluster SE=" %8.5f `se_cluster' ///
        " ratio=" %6.3f `se_cluster'/`se_model'
    * the contrast the test is named for: clustering inflates the SE here
    assert `se_cluster' > `se_model'
}
if _rc == 0 {
    display as result "  PASS: C20 cluster SE > model SE under intra-cluster correlation"
    local ++pass_count
}
else {
    display as error "  FAIL: C20 cluster SEs (rc=`=_rc')"
    local ++fail_count
}

* {smcl}
* {* SECTION 11: (moved out) Performance benchmarks}{...}
*
* MOVED 2026-09-02 to qa/benchmark_finegray_crossval.do.  C21-C25 were five
* WALL-CLOCK benchmarks (N = 500, 2000, 5000, 10000, 50000) counted as five
* CORRECTNESS tests in this suite's RESULT line, on a lane that runs on a shared
* machine.  qa/README.md's own convention says benchmark_* files "measure
* performance and are never correctness gates", and benchmarks are not lane
* members (run_all.do's explicit lists).  Five tests whose verdict is a stopwatch
* inflated this suite's pass count without cross-validating anything -- the only
* actual cross-validation in the block was C21's coefficient comparison against
* stcrreg at N=500, which moved with it and is now asserted at 1e-8 instead of
* 0.001.  Run the benchmark by hand:
*     stata-mp -b do benchmark_finegray_crossval.do

* {smcl}
* {* SECTION 12: norobust cross-validation vs stcrreg}{...}

* C26: norobust SEs vs stcrreg — simulated data
local ++test_count
capture noisily {
    clear
    set seed 55
    set obs 800
    gen id = _n
    gen double x1 = rnormal()
    gen double x2 = rbinomial(1, 0.4)
    gen double u = runiform()
    gen double t_event = -ln(u) / exp(0.5*x1 - 0.2*x2)
    gen double t_censor = runiform() * 4
    gen double t = min(t_event, t_censor)
    gen byte d = (t_event <= t_censor)
    gen byte status = 0
    replace status = 1 if d == 1 & runiform() > 0.35
    replace status = 2 if d == 1 & status == 0
    * finegray norobust
    stset t, failure(d) id(id)
    _finegray_xv x1 x2, compete(status) cause(1) nolog norobust
    matrix V_fg = e(V)
    matrix b_fg = e(b)
    * stcrreg
    stset t, failure(status==1) id(id)
    stcrreg x1 x2, compete(status == 2)
    matrix V_ref = e(V)
    matrix b_ref = e(b)
    * Coefficients should match
    local _c26d = max(abs(b_fg[1,1] - b_ref[1,1]), abs(b_fg[1,2] - b_ref[1,2]))
    display as text "  C26 max|b_fg - b_stcrreg| = " %10.3e `_c26d'
    * TOLERANCE 2e-6.  MEASURED 2026-09-02 on this seeded fixture: 1.449e-07.
    assert `_c26d' < 2e-6
    * SEs should be in the same range
    forvalues i = 1/2 {
        local se_fg = sqrt(V_fg[`i',`i'])
        local se_ref = sqrt(V_ref[`i',`i'])
        local ratio = `se_fg' / `se_ref'
        display as text "  norobust SE ratio var `i': " %10.6f `ratio'
        * BAND (0.8, 1.25).  finegray's model-based SE and stcrreg's are two
        * different variance estimators, so this is a sanity band rather than an
        * identity; but the band has to be able to fail.  MEASURED 2026-09-02 on
        * this seeded fixture (set seed 55, deterministic): 0.958964 and
        * 1.001726, i.e. a largest deviation from 1 of 4.1%.  The band is about
        * 5x that.  The (0.5, 2) that stood here was 12x it and would have
        * accepted an SE off by half.
        assert `ratio' > 0.8 & `ratio' < 1.25
    }
}
if _rc == 0 {
    display as result "  PASS: C26 norobust SEs vs stcrreg (simulated)"
    local ++pass_count
}
else {
    display as error "  FAIL: C26 norobust SEs (rc=`=_rc')"
    local ++fail_count
}

* {smcl}
* {* SECTION 13: Factor variable cross-validation}{...}

* C27: Factor variable vs stcrreg — simulated data
local ++test_count
capture noisily {
    clear
    set seed 88
    set obs 600
    gen id = _n
    gen byte grp = mod(_n-1, 3)
    gen double x1 = rnormal()
    gen double u = runiform()
    * True model: grp==1 SHR=1.5 (beta=0.4), grp==2 SHR=0.7 (beta=-0.36)
    gen double h = exp(0.4*(grp==1) - 0.36*(grp==2) + 0.3*x1)
    gen double t_event = -ln(u) / h
    gen double t_censor = runiform() * 3
    gen double t = min(t_event, t_censor)
    gen byte d = (t_event <= t_censor)
    gen byte status = 0
    replace status = 1 if d == 1 & runiform() > 0.3
    replace status = 2 if d == 1 & status == 0
    * finegray with factor
    stset t, failure(d) id(id)
    _finegray_xv i.grp x1, compete(status) cause(1) nolog
    * the non-base vector: e(b) leads with the base column 0b.grp (= 0)
    _finegray_bnb, b(b_fg)
    * stcrreg with manual indicators (drop factor-created vars first)
    capture drop grp_1
    capture drop grp_2
    gen byte grp_1 = (grp == 1)
    gen byte grp_2 = (grp == 2)
    stset t, failure(status==1) id(id)
    stcrreg grp_1 grp_2 x1, compete(status == 2)
    matrix b_ref = e(b)
    * Coefficients must match
    local _c27d = 0
    forvalues i = 1/3 {
        local _c27d = max(`_c27d', abs(b_fg[1,`i'] - b_ref[1,`i']))
    }
    display as text "  C27 max|b_fg - b_stcrreg| = " %10.3e `_c27d'
    * TOLERANCE 1e-8.  MEASURED 2026-09-02 on this seeded fixture: 8.004e-11.
    assert `_c27d' < 1e-8
}
if _rc == 0 {
    display as result "  PASS: C27 factor variable vs stcrreg (simulated)"
    local ++pass_count
}
else {
    display as error "  FAIL: C27 factor vs stcrreg (rc=`=_rc')"
    local ++fail_count
}

* {smcl}
* {* SECTION 14: in restriction cross-validation}{...}

* C28: in restriction — coefficients match if restriction on same data
local ++test_count
capture noisily {
    _setup_hypoxia
    * Sort deterministically to make in predictable
    sort stnum
    local N_half = int(_N / 2)
    _finegray_xv ifp tumsize pelnode if _n <= `N_half', compete(status) cause(1) nolog
    matrix b_if = e(b)
    local N_if = e(N)
    _finegray_xv ifp tumsize pelnode in 1/`N_half', compete(status) cause(1) nolog
    matrix b_in = e(b)
    local N_in = e(N)
    * Same observations — coefficients should match within float precision
    assert `N_if' == `N_in'
    forvalues i = 1/3 {
        assert abs(b_if[1,`i'] - b_in[1,`i']) < 1e-6
    }
}
if _rc == 0 {
    display as result "  PASS: C28 if vs in restriction equivalence"
    local ++pass_count
}
else {
    display as error "  FAIL: C28 if vs in (rc=`=_rc')"
    local ++fail_count
}

* {smcl}
* {* SECTION 15: Non-default censvalue cross-validation}{...}

* C29: censvalue cross-validation — simulated data with non-zero censor code
local ++test_count
capture noisily {
    clear
    set seed 123
    set obs 500
    gen id = _n
    gen double x1 = rnormal()
    gen double u = runiform()
    gen double t_event = -ln(u) / exp(0.4*x1)
    gen double t_censor = runiform() * 3
    gen double t = min(t_event, t_censor)
    gen byte d = (t_event <= t_censor)
    * Code: 5=censored, 1=cause, 2=competing
    gen byte status = 5
    replace status = 1 if d == 1 & runiform() > 0.4
    replace status = 2 if d == 1 & status == 5
    * finegray with censvalue(5)
    stset t, failure(d) id(id)
    _finegray_xv x1, compete(status) cause(1) censvalue(5) nolog
    local b_fg = e(b)[1,1]
    assert !missing(e(N_cens))
    assert e(N_cens) > 0 & e(N_cens) < .
    * stcrreg (standard setup)
    stset t, failure(status==1) id(id)
    stcrreg x1, compete(status == 2)
    local b_ref = e(b)[1,1]
    local _c29d = abs(`b_fg' - `b_ref')
    display as text "  C29 |b_fg - b_stcrreg| = " %10.3e `_c29d'
    * TOLERANCE 1e-8.  MEASURED 2026-09-02 on this seeded fixture: 2.132e-12.
    assert `_c29d' < 1e-8
}
if _rc == 0 {
    display as result "  PASS: C29 censvalue(5) vs stcrreg (simulated)"
    local ++pass_count
}
else {
    display as error "  FAIL: C29 censvalue(5) (rc=`=_rc')"
    local ++fail_count
}

* {smcl}
* {* SECTION 16: Multiple strata cross-validation}{...}

* C30: Multiple strata variables — CIF valid and matches manual egen
local ++test_count
capture noisily {
    clear
    set seed 77
    set obs 600
    gen id = _n
    gen byte site = mod(_n-1, 3) + 1
    gen byte arm = mod(_n-1, 2)
    gen double x1 = rnormal()
    gen double u = runiform()
    gen double t_event = -ln(u) / exp(0.3*x1)
    gen double t_censor = runiform() * 4
    gen double t = min(t_event, t_censor)
    gen byte d = (t_event <= t_censor)
    gen byte status = 0
    replace status = 1 if d == 1 & runiform() > 0.4
    replace status = 2 if d == 1 & status == 0
    stset t, failure(d) id(id)
    * Multiple strata variables (auto-combined)
    _finegray_xv x1, compete(status) cause(1) nolog strata(site arm)
    assert e(converged) == 1
    local b_multi = e(b)[1,1]
    finegray_predict cif_multi, cif
    summ cif_multi, meanonly
    assert !missing(r(min))
    assert r(min) >= 0 & r(max) <= 1
    * Compare against manual egen group
    egen int strata_combo = group(site arm)
    _finegray_xv x1, compete(status) cause(1) nolog strata(strata_combo)
    local b_manual = e(b)[1,1]
    assert abs(`b_multi' - `b_manual') < 1e-8
    drop cif_multi strata_combo
}
if _rc == 0 {
    display as result "  PASS: C30 multiple strata — valid CIF and matches manual"
    local ++pass_count
}
else {
    display as error "  FAIL: C30 multiple strata (rc=`=_rc')"
    local ++fail_count
}

* {smcl}
* {* SECTION 17: phtest cross-validation}{...}

* C31: phtest detects known PH violation (time-varying effect)
local ++test_count
capture noisily {
    clear
    set seed 314
    set obs 2000
    gen id = _n
    gen double x1 = rnormal()
    gen double u = runiform()
    * Time-varying effect: x1 effect changes with time
    * At early times beta=0.8, at later times beta=-0.2
    * This creates a strong PH violation
    gen double t_event = -ln(u) / exp(0.8*x1)
    * Make the hazard time-dependent by resampling late events
    replace t_event = t_event * exp(-1.0*x1) if t_event > 1.5
    gen double t_censor = runiform() * 6
    gen double t = min(t_event, t_censor)
    gen byte d = (t_event <= t_censor)
    gen byte status = 0
    replace status = 1 if d == 1 & runiform() > 0.3
    replace status = 2 if d == 1 & status == 0
    stset t, failure(d) id(id)
    _finegray_xv x1, compete(status) cause(1) nolog
    finegray_phtest
    * FG-03: finegray_phtest is a diagnostic and reports the residual-time
    * CORRELATION only (column 1), no p-value.  "Detection" is therefore checked
    * as a diagnostic MAGNITUDE: for a strong known PH violation the correlation
    * must be clearly non-zero.  The floor here is the same boundary the retired
    * p<0.10 implied, |rho| > z(0.95)/sqrt(events) -- computed test-side, so the
    * package makes no calibration claim -- which keeps this test's power to catch
    * a diagnostic that goes blind to a real violation.
    matrix _Pv = r(phtest)
    assert !missing(_Pv[1,1], _Pv[1,2])
    local _events = _Pv[1, 2]
    local _floor = invnormal(0.95) / sqrt(`_events')
    display as text "  PH violation diagnostic: correlation=" %8.4f _Pv[1,1] ///
        " |rho| floor=" %8.4f `_floor'
    assert abs(_Pv[1,1]) > `_floor'
}
if _rc == 0 {
    display as result "  PASS: C31 phtest diagnostic flags PH violation"
    local ++pass_count
}
else {
    display as error "  FAIL: C31 PH violation detection (rc=`=_rc')"
    local ++fail_count
}

* C32: phtest does not reject on simple model with weak effect
* Note: Random allocation to competing events can induce non-proportional
* subdistribution hazards even from proportional cause-specific hazards.
* Use weak effect + moderate N to avoid spurious rejection.
local ++test_count
capture noisily {
    clear
    set seed 999
    set obs 500
    gen id = _n
    gen double x1 = rnormal()
    gen double u = runiform()
    * Very weak effect — beta=0.05 — minimal PH violation from competing risk allocation
    gen double t_event = -ln(u) / exp(0.05*x1)
    gen double t_censor = runiform() * 5
    gen double t = min(t_event, t_censor)
    gen byte d = (t_event <= t_censor)
    gen byte status = 0
    replace status = 1 if d == 1 & runiform() > 0.35
    replace status = 2 if d == 1 & status == 0
    stset t, failure(d) id(id)
    _finegray_xv x1, compete(status) cause(1) nolog
    finegray_phtest
    * FG-03: diagnostic surface [correlation, events]; no p-value.  The weak /
    * no-violation counterpart to C31: the residual-time correlation must stay
    * BELOW the same detection floor (|rho| < z(0.95)/sqrt(events)), i.e. the
    * diagnostic does not flag proportionality where there is none.  (The former
    * `assert _Pw[1,3] > 0.01' read a nonexistent 3rd column, which returns
    * missing, and `missing > 0.01' is vacuously true -- a false green.)
    matrix _Pw = r(phtest)
    assert colsof(_Pw) == 2
    local _events = _Pw[1, 2]
    local _floor = invnormal(0.95) / sqrt(`_events')
    display as text "  Weak-effect PH diagnostic: correlation=" %8.4f _Pw[1,1] ///
        " |rho| floor=" %8.4f `_floor'
    assert abs(_Pw[1,1]) < `_floor'
}
if _rc == 0 {
    display as result "  PASS: C32 phtest diagnostic does not flag weak effect"
    local ++pass_count
}
else {
    display as error "  FAIL: C32 non-rejection (rc=`=_rc')"
    local ++fail_count
}

* {smcl}
* {* SECTION 18: R cross-validation via cmprsk::crr}{...}

display ""
display as text _dup(60) "="
display as text "R CROSS-VALIDATION: finegray vs cmprsk::crr"
display as text _dup(60) "="

* Export hypoxia data for R
_setup_hypoxia
local r_available = 1

capture noisily {
    preserve
    keep if e(sample) != 1
    * Need fresh data — reload
    restore
    _setup_hypoxia
    * Run finegray first to identify estimation sample
    _finegray_xv ifp tumsize pelnode, compete(status) cause(1) nolog
    * Save Stata results for comparison
    matrix b_stata = e(b)
    matrix V_stata = e(V)
    local ll_stata = e(ll)

    * Export data for R (unstratified hypoxia)
    preserve
    keep if e(sample)
    keep stnum _t status ifp tumsize pelnode
    rename stnum id
    rename _t time
    gen str16 dataset = "hypoxia"
    gen byte strata = .
    export delimited using ///
        "`datadir'/finegray_r_input.csv", ///
        replace
    restore

    * Export stratified dataset for R (hypoxia with pelnode as strata)
    * Re-fit with strata to get estimation sample
    *
    * noadjust is required for a LIKE-FOR-LIKE SE comparison against cmprsk.
    * finegray applies a finite-sample adjustment to the sandwich by default
    * (N/(N-1), matching stcrreg); cmprsk::crr applies none. On hypoxia
    * (N = 109) that factor is sqrt(109/108) = 1.0046, i.e. a 0.46% inflation --
    * which is exactly the discrepancy C52 saw against its 0.1% tolerance. That
    * is a difference in the reported estimand, not in the estimator, so the
    * oracle must be compared against the same quantity it computes.
    _finegray_xv ifp tumsize, compete(status) cause(1) nolog strata(pelnode) noadjust
    matrix b_strata_stata = e(b)
    matrix V_strata_stata = e(V)
    local ll_strata_stata = e(ll)
    preserve
    keep if e(sample)
    keep stnum _t status ifp tumsize pelnode
    rename stnum id
    rename _t time
    gen str16 dataset = "hypoxia_strata"
    rename pelnode strata
    export delimited using ///
        "`datadir'/finegray_r_strata.csv", ///
        replace
    restore
}

if _rc != 0 {
    display as error "  SKIP: Could not export data for R crossval"
    local r_available = 0
}

* Call R (unstratified).  Pre-delete even in the run-unique directory so the
* fail-closed contract is explicit and independently regression-testable.
if `r_available' {
    capture erase "`datadir'/finegray_r_output.csv"
    capture noisily {
        shell Rscript "`qadir'/crossval_finegray_r.R" ///
            "`datadir'/finegray_r_input.csv" ///
            "`datadir'/finegray_r_output.csv"
    }
    capture confirm file "`datadir'/finegray_r_output.csv"
    if _rc != 0 {
        display as error "  SKIP: R script failed or output not found"
        local r_available = 0
    }
}

* Call R (stratified)
local r_strata_available = 0
if `r_available' {
    capture erase "`datadir'/finegray_r_strata_output.csv"
    capture noisily {
        shell Rscript "`qadir'/crossval_finegray_r.R" ///
            "`datadir'/finegray_r_strata.csv" ///
            "`datadir'/finegray_r_strata_output.csv"
    }
    capture confirm file "`datadir'/finegray_r_strata_output.csv"
    if _rc == 0 {
        local r_strata_available = 1
    }
    else {
        display as error "  NOTE: R strata script failed; strata crossval will be skipped"
    }
}

if `r_available' {
    * Load R results
    preserve
    import delimited using ///
        "`datadir'/finegray_r_output.csv", ///
        clear
    isid dataset quantity variable

    * C33: Coefficients vs cmprsk::crr
    local ++test_count
    local t33_pass = 1
    foreach var in ifp tumsize pelnode {
        quietly {
            summ value if dataset == "hypoxia" & quantity == "coef" & variable == "`var'", meanonly
        }
        if r(N) == 0 {
            display as error "  FAIL [C33.`var']: R coef not found"
            local t33_pass = 0
            continue
        }
        local r_coef = r(mean)
        * Get Stata coef position
        if "`var'" == "ifp" local pos = 1
        if "`var'" == "tumsize" local pos = 2
        if "`var'" == "pelnode" local pos = 3
        local s_coef = b_stata[1, `pos']
        local adiff = abs(`s_coef' - `r_coef')
        display as text "  coef[`var']: Stata=" %10.6f `s_coef' " R=" %10.6f `r_coef' ///
            " diff=" %10.3e `adiff'
        * TOLERANCE 1e-6.  finegray and cmprsk::crr maximise the same
        * partial likelihood on the same weights, so only the two solvers'
        * convergence tolerances separate them.  MEASURED 2026-09-01:
        * 1.407e-09 (ifp), 7.826e-09 (tumsize), 1.918e-08 (pelnode) -- 1e-6 is
        * about 50x the largest.  The 0.01 that stood here is the same order as
        * the coefficients themselves (0.033 for ifp) and could not have failed.
        if `adiff' >= 1e-6 {
            display as error "  FAIL [C33.`var']: diff `adiff' >= 1e-6"
            local t33_pass = 0
        }
    }
    if `t33_pass' {
        display as result "  PASS: C33 coefficients vs cmprsk::crr (< 1e-6)"
        local ++pass_count
    }
    else {
        display as error "  FAIL: C33 coefficients vs cmprsk::crr"
        local ++fail_count
    }

    * C34: Robust SEs vs cmprsk::crr
    local ++test_count
    local t34_pass = 1
    foreach var in ifp tumsize pelnode {
        quietly {
            summ value if dataset == "hypoxia" & quantity == "se_robust" & variable == "`var'", meanonly
        }
        if r(N) == 0 {
            display as error "  FAIL [C34.`var']: R se_robust not found"
            local t34_pass = 0
            continue
        }
        local r_se = r(mean)
        if "`var'" == "ifp" local pos = 1
        if "`var'" == "tumsize" local pos = 2
        if "`var'" == "pelnode" local pos = 3
        local s_se = sqrt(V_stata[`pos', `pos'])
        local rdiff = abs(`s_se' - `r_se') / `r_se'
        display as text "  se_robust[`var']: Stata=" %10.6f `s_se' " R=" %10.6f `r_se' ///
            " rel_diff=" %10.3e `rdiff'
        * TOLERANCE 0.01 RELATIVE, and it cannot go lower.  finegray's DEFAULT
        * sandwich omits the Fine-Gray psi (weight-estimation) term that
        * cmprsk::crr always includes, so these two SEs are not estimating the
        * same quantity to machine precision -- the documented gap is about
        * 0.4% on the SE (0.8% on the variance) for this fit.  MEASURED
        * 2026-09-01: 4.802e-03 (ifp), 4.455e-03 (tumsize), 5.433e-03
        * (pelnode).  0.01 is about 2x the measured maximum, which is
        * the right multiple here: 10x would re-open the 5% band this test
        * exists to close, and 1e-6 would pin a difference the estimator is
        * documented to have.  A REGRESSION in the psi omission would move
        * this by an order of magnitude, not by a factor of two.
        if `rdiff' >= 0.01 {
            display as error "  FAIL [C34.`var']: rel_diff `rdiff' >= 0.01"
            local t34_pass = 0
        }
    }
    if `t34_pass' {
        display as result "  PASS: C34 robust SEs vs cmprsk::crr (< 1%)"
        local ++pass_count
    }
    else {
        display as error "  FAIL: C34 robust SEs vs cmprsk::crr"
        local ++fail_count
    }

    * C35: Model-based SEs (norobust) vs crr$invinf
    local ++test_count
    local t35_pass = 1
    restore
    _setup_hypoxia
    _finegray_xv ifp tumsize pelnode, compete(status) cause(1) nolog norobust
    matrix V_nr = e(V)
    preserve
    import delimited using ///
        "`datadir'/finegray_r_output.csv", ///
        clear
    foreach var in ifp tumsize pelnode {
        quietly {
            summ value if dataset == "hypoxia" & quantity == "se_model" & variable == "`var'", meanonly
        }
        if r(N) == 0 {
            display as error "  FAIL [C35.`var']: R se_model not found"
            local t35_pass = 0
            continue
        }
        local r_se = r(mean)
        if "`var'" == "ifp" local pos = 1
        if "`var'" == "tumsize" local pos = 2
        if "`var'" == "pelnode" local pos = 3
        local s_se = sqrt(V_nr[`pos', `pos'])
        local rdiff = abs(`s_se' - `r_se') / `r_se'
        display as text "  se_model[`var']: Stata=" %10.6f `s_se' " R=" %10.6f `r_se' ///
            " rel_diff=" %10.3e `rdiff'
        * TOLERANCE 1e-6 RELATIVE.  Unlike C34 there is no psi term on either
        * side: both are the inverse observed information at the same beta, so
        * they agree to solver precision.  MEASURED 2026-09-01: 2.916e-08
        * (ifp), 6.881e-10 (tumsize), 2.320e-08 (pelnode) -- 1e-6 is about 34x
        * the largest.  The 15% that stood here would have accepted a
        * completely different information matrix.
        if `rdiff' >= 1e-6 {
            display as error "  FAIL [C35.`var']: rel_diff `rdiff' >= 1e-6"
            local t35_pass = 0
        }
    }
    if `t35_pass' {
        display as result "  PASS: C35 model-based SEs vs crr$invinf (< 1e-6 rel)"
        local ++pass_count
    }
    else {
        display as error "  FAIL: C35 model-based SEs vs crr$invinf"
        local ++fail_count
    }

    * C36: Log-likelihood vs cmprsk::crr
    local ++test_count
    capture noisily {
        quietly {
            summ value if dataset == "hypoxia" & quantity == "loglik" & variable == "final", meanonly
        }
        local r_ll = r(mean)
        local rdiff = abs(`ll_stata' - `r_ll') / abs(`r_ll')
        display as text "  loglik: Stata=" %12.4f `ll_stata' " R=" %12.4f `r_ll' ///
            " rel_diff=" %10.3e `rdiff'
        * TOLERANCE 1e-6.  MEASURED 2026-09-02: 5.030e-08, so about 20x it.
        * The 0.001 that stood here was four orders above the measurement.
        assert `rdiff' < 1e-6
    }
    if _rc == 0 {
        display as result "  PASS: C36 log-likelihood vs cmprsk::crr (< 0.1%)"
        local ++pass_count
    }
    else {
        display as error "  FAIL: C36 log-likelihood (rc=`=_rc')"
        local ++fail_count
    }

    * C37: CIF at reference pattern (z=0) vs predict.crr
    * QA-H03: t37_pass stayed 1 if EVERY time point skipped (R output missing),
    * so C37 could report PASS having compared nothing.  Count the comparisons
    * actually made and require at least one -- a verdict on zero comparisons is
    * not a pass.
    local ++test_count
    local t37_pass = 1
    local t37_ncmp = 0
    restore
    _setup_hypoxia
    _finegray_xv ifp tumsize pelnode, compete(status) cause(1) nolog basehaz
    * CIF at z=0: 1 - exp(-H0(t))
    matrix bh = e(basehaz)
    local nr_bh = rowsof(bh)
    preserve
    import delimited using ///
        "`datadir'/finegray_r_output.csv", ///
        clear
    foreach tt in 2 5 10 {
        quietly {
            summ value if dataset == "hypoxia" & quantity == "cif_ref" & variable == "t`tt'", meanonly
        }
        if r(N) == 0 {
            display as text "  SKIP [C37.t`tt']: R cif_ref not found"
            continue
        }
        local r_cif = r(mean)
        * Find Stata H0 at time tt
        local H0_tt = 0
        forvalues j = 1/`nr_bh' {
            if bh[`j', 1] <= `tt' {
                local H0_tt = bh[`j', 2]
            }
        }
        local s_cif = 1 - exp(-`H0_tt')
        local adiff = abs(`s_cif' - `r_cif')
        local ++t37_ncmp
        display as text "  CIF(t=`tt',z=0): Stata=" %8.6f `s_cif' " R=" %8.6f `r_cif' ///
            " diff=" %10.3e `adiff'
        * TOLERANCE 1e-7 ABSOLUTE.  Both sides are 1 - exp(-H0(t)) from a
        * Breslow baseline built on the same weighted risk sets, so the only
        * separation is the coefficient agreement of C33 propagated through
        * exp(.).  MEASURED 2026-09-01: 1.076e-09 (t=2), 1.102e-09 (t=5),
        * 3.498e-09 (t=10) -- 1e-7 is about 29x the largest.  The 0.01 that
        * stood here is one sixth of the CIF being compared (0.058 at t = 2).
        if `adiff' >= 1e-7 {
            display as error "  FAIL [C37.t`tt']: diff `adiff' >= 1e-7"
            local t37_pass = 0
        }
    }
    if `t37_ncmp' != 3 {
        display as error "  FAIL: C37 compared `t37_ncmp' of 3 planned time points"
        local t37_pass = 0
    }
    if `t37_pass' {
        display as result "  PASS: C37 CIF at z=0 vs predict.crr (< 1e-7)"
        local ++pass_count
    }
    else {
        display as error "  FAIL: C37 CIF vs predict.crr"
        local ++fail_count
    }
    restore
}
else {
    * R not available — skip C33-C37
    display as text "  SKIP: R cross-validation tests (C33-C37) — R or cmprsk not available"
    forvalues i = 33/37 {
        local ++test_count
        local ++skip_count
    }
}

* {smcl}
* {* SECTION 19: Interaction cross-validation}{...}

* C38: i.var##c.var vs manual indicators + interaction — same coefficients
local ++test_count
capture noisily {
    _setup_hypoxia
    * Fit with fvrevar-based ##
    _finegray_xv i.pelnode##c.ifp tumsize, compete(status) cause(1) nolog
    * e(b) carries the base-level columns; compare the non-base vector
    _finegray_bnb, b(b_fv)
    local ll_fv = e(ll)
    cap drop _fg_*
    * Fit with manual indicators and interaction
    gen byte pel_1 = (pelnode == 1)
    gen double pel_1_ifp = pel_1 * ifp
    _finegray_xv pel_1 ifp pel_1_ifp tumsize, compete(status) cause(1) nolog
    matrix b_man = e(b)
    local ll_man = e(ll)
    * Must produce identical results
    assert abs(`ll_fv' - `ll_man') < 1e-6
    forvalues j = 1/4 {
        assert abs(b_fv[1,`j'] - b_man[1,`j']) < 1e-6
    }
    drop pel_1 pel_1_ifp
}
if _rc == 0 {
    display as result "  PASS: C38 i##c vs manual — identical coefficients"
    local ++pass_count
}
else {
    display as error "  FAIL: C38 i##c vs manual (rc=`=_rc')"
    local ++fail_count
}

* C39: i.var##i.var vs manual indicators — same coefficients
local ++test_count
capture noisily {
    _setup_hypoxia
    gen byte ifp_grp = (ifp > 10)
    * Fit with fvrevar
    _finegray_xv i.pelnode##i.ifp_grp tumsize, compete(status) cause(1) nolog
    _finegray_bnb, b(b_fv)
    local ll_fv = e(ll)
    cap drop _fg_*
    * Manual: create indicators and interaction
    gen byte pel_1 = (pelnode == 1)
    gen byte ifpg_1 = (ifp_grp == 1)
    gen byte pel_1_ifpg_1 = pel_1 * ifpg_1
    _finegray_xv pel_1 ifpg_1 pel_1_ifpg_1 tumsize, compete(status) cause(1) nolog
    matrix b_man = e(b)
    local ll_man = e(ll)
    assert abs(`ll_fv' - `ll_man') < 1e-6
    forvalues j = 1/4 {
        * Use relative tolerance for large coefficients (quasi-separation)
        local _bfv = b_fv[1,`j']
        local _bman = b_man[1,`j']
        local _scale = max(abs(`_bfv'), abs(`_bman'), 1)
        assert abs(`_bfv' - `_bman') / `_scale' < 1e-4
    }
    drop ifp_grp pel_1 ifpg_1 pel_1_ifpg_1
}
if _rc == 0 {
    display as result "  PASS: C39 i##i vs manual — identical coefficients"
    local ++pass_count
}
else {
    display as error "  FAIL: C39 i##i vs manual (rc=`=_rc')"
    local ++fail_count
}

* C40: Interaction model CIF matches manual computation
local ++test_count
capture noisily {
    _setup_hypoxia
    _finegray_xv i.pelnode##c.ifp tumsize, compete(status) cause(1) nolog basehaz
    * CIF via finegray_predict
    finegray_predict cif_auto, cif
    * CIF via manual: 1 - exp(-H0(t) * exp(xb))
    finegray_predict xb_man, xb
    tempname bh
    matrix `bh' = e(basehaz)
    tempvar H0 alltouse
    quietly gen double `H0' = 0
    quietly gen byte `alltouse' = 1
    mata: _finegray_step_lookup("`bh'", "_t", "`H0'", "`alltouse'")
    gen double cif_manual = 1 - exp(-`H0' * exp(xb_man))
    * Must match within floating point tolerance
    gen double cif_diff = abs(cif_auto - cif_manual)
    summ cif_diff, meanonly
    assert r(max) < 1e-6
    drop cif_auto xb_man cif_manual cif_diff
    cap drop _fg_*
}
if _rc == 0 {
    display as result "  PASS: C40 interaction CIF matches manual"
    local ++pass_count
}
else {
    display as error "  FAIL: C40 interaction CIF (rc=`=_rc')"
    local ++fail_count
}

* {smcl}
* {* SECTION 14: Cluster VCE vs stcrreg}{...}

* C41: Cluster VCE coefficients match stcrreg
local ++test_count
capture noisily {
    clear
    set seed 7742
    set obs 1000
    gen id = _n
    gen clid = mod(_n-1, 100) + 1
    gen double x1 = rnormal() + 0.3 * (clid > 50)
    gen double u = runiform()
    gen double t_event = -ln(u) / exp(0.5*x1)
    gen double t_censor = runiform() * 5
    gen double t = min(t_event, t_censor)
    gen byte d = (t_event <= t_censor)
    gen byte status = 0
    replace status = 1 if d == 1 & runiform() > 0.3
    replace status = 2 if d == 1 & status == 0
    stset t, failure(d) id(id)

    _finegray_xv x1, compete(status) cause(1) nolog cluster(clid)
    local b_fg = e(b)[1,1]
    local se_fg = sqrt(e(V)[1,1])

    preserve
    stset t, failure(status==1) id(id)
    stcrreg x1, compete(status == 2) vce(cluster clid)
    local b_ref = e(b)[1,1]
    local se_ref = sqrt(e(V)[1,1])
    restore

    local b_rel = abs(`b_fg' - `b_ref') / abs(`b_ref')
    local se_rel = abs(`se_fg' - `se_ref') / abs(`se_ref')
    display as text "  coef: finegray=" %9.5f `b_fg' " stcrreg=" %9.5f `b_ref' " REL=" %6.4f `b_rel'
    display as text "  SE:   finegray=" %9.5f `se_fg' " stcrreg=" %9.5f `se_ref' " REL=" %6.4f `se_rel'
    assert `b_rel' < 0.02
    assert `se_rel' < 0.05
}
if _rc == 0 {
    display as result "  PASS: C41 cluster VCE coef+SE vs stcrreg"
    local ++pass_count
}
else {
    display as error "  FAIL: C41 cluster VCE vs stcrreg (rc=`=_rc')"
    local ++fail_count
}

* C42: Cluster VCE with two covariates vs stcrreg
local ++test_count
capture noisily {
    clear
    set seed 8853
    set obs 800
    gen id = _n
    gen clid = mod(_n-1, 80) + 1
    gen double x1 = rnormal()
    gen double x2 = rnormal() + 0.2 * (clid > 40)
    gen double u = runiform()
    gen double t_event = -ln(u) / exp(0.4*x1 - 0.3*x2)
    gen double t_censor = runiform() * 4
    gen double t = min(t_event, t_censor)
    gen byte d = (t_event <= t_censor)
    gen byte status = 0
    replace status = 1 if d == 1 & runiform() > 0.35
    replace status = 2 if d == 1 & status == 0
    stset t, failure(d) id(id)

    _finegray_xv x1 x2, compete(status) cause(1) nolog cluster(clid)
    matrix b_fg = e(b)
    matrix V_fg = e(V)

    preserve
    stset t, failure(status==1) id(id)
    stcrreg x1 x2, compete(status == 2) vce(cluster clid)
    matrix b_ref = e(b)
    matrix V_ref = e(V)
    restore

    forvalues j = 1/2 {
        local b_rel = abs(b_fg[1,`j'] - b_ref[1,`j']) / abs(b_ref[1,`j'])
        local se_fg_j = sqrt(V_fg[`j',`j'])
        local se_ref_j = sqrt(V_ref[`j',`j'])
        local se_rel = abs(`se_fg_j' - `se_ref_j') / abs(`se_ref_j')
        display as text "  x`j' coef REL=" %6.4f `b_rel' " SE REL=" %6.4f `se_rel'
        assert `b_rel' < 0.02
        assert `se_rel' < 0.05
    }
}
if _rc == 0 {
    display as result "  PASS: C42 2-covariate cluster VCE vs stcrreg"
    local ++pass_count
}
else {
    display as error "  FAIL: C42 cluster VCE 2-cov (rc=`=_rc')"
    local ++fail_count
}

* {smcl}
* {* SECTION 15: Left-truncation cross-validation}{...}

* C43: Left-truncated coefficients match stcrreg
local ++test_count
capture noisily {
    clear
    set seed 5567
    set obs 600
    gen id = _n
    gen double x1 = rnormal()
    gen double u = runiform()
    gen double t_event = -ln(u) / exp(0.5*x1)
    gen double t_censor = runiform() * 5
    gen double t = min(t_event, t_censor)
    gen byte d = (t_event <= t_censor)
    gen byte status = 0
    replace status = 1 if d == 1 & runiform() > 0.3
    replace status = 2 if d == 1 & status == 0
    * Create delayed entry: ~40% of subjects enter late
    gen double t_enter = runiform() * 0.5 if runiform() > 0.6
    replace t_enter = 0 if missing(t_enter)
    * Drop subjects whose entry is after their event/censor time
    drop if t_enter >= t
    stset t, failure(d) id(id) enter(time t_enter)

    _finegray_xv x1, compete(status) cause(1) nolog
    local b_fg = e(b)[1,1]
    local se_fg = sqrt(e(V)[1,1])

    preserve
    stset t, failure(status==1) id(id) enter(time t_enter)
    stcrreg x1, compete(status == 2)
    local b_ref = e(b)[1,1]
    local se_ref = sqrt(e(V)[1,1])
    restore

    local b_rel = abs(`b_fg' - `b_ref') / abs(`b_ref')
    local se_rel = abs(`se_fg' - `se_ref') / abs(`se_ref')
    display as text "  coef: finegray=" %9.5f `b_fg' " stcrreg=" %9.5f `b_ref' " REL=" %6.4f `b_rel'
    display as text "  SE:   finegray=" %9.5f `se_fg' " stcrreg=" %9.5f `se_ref' " REL=" %6.4f `se_rel'

    * INVERTED, deliberately: under left truncation finegray must NOT match
    * stcrreg, and this test used to assert that it did (b_rel < 0.02).
    *
    * finegray now implements the stabilized Zhang-Zhang-Fine weight, which
    * reweights the risk set for delayed entry.  stcrreg does not: it applies the
    * censoring weight only, which is the estimator the recovery gate
    * (validation_finegray_zzf_recovery.do) measured as BIASED -- the pooled /
    * stcrreg-style arm missed the known truth by +62.96 and +190.07 MC SE, while
    * the ZZF arms recovered it to within +-3 MC SE.  So a green "matches stcrreg
    * under LT" was a test asserting the defect.
    *
    * Asserting mere inequality would pass on any garbage, so pin BOTH sides:
    *   (1) under LT the two must genuinely diverge, and
    *   (2) with the SAME data and NO delayed entry they must still agree --
    *       which proves the divergence is specific to left truncation and not a
    *       general regression against StataCorp.
    assert `b_rel' > 0.02

    * (2) parity WITHOUT delayed entry, same dataset
    preserve
    quietly replace t_enter = 0
    stset t, failure(d) id(id) enter(time t_enter)
    quietly _finegray_xv x1, compete(status) cause(1) nolog
    local b_fg0 = e(b)[1,1]
    stset t, failure(status==1) id(id) enter(time t_enter)
    quietly stcrreg x1, compete(status == 2)
    local b_ref0 = e(b)[1,1]
    restore
    local b_rel0 = abs(`b_fg0' - `b_ref0') / abs(`b_ref0')
    display as text "  no-LT parity: finegray=" %9.5f `b_fg0' " stcrreg=" ///
        %9.5f `b_ref0' " REL=" %8.6f `b_rel0'
    assert `b_rel0' < 0.02
}
if _rc == 0 {
    display as result "  PASS: C43 LT diverges from stcrreg (by design); no-LT parity holds"
    local ++pass_count
}
else {
    display as error "  FAIL: C43 left-truncation vs stcrreg (rc=`=_rc')"
    local ++fail_count
}

* C44: Left-truncated with two covariates vs stcrreg
local ++test_count
capture noisily {
    clear
    set seed 6678
    set obs 800
    gen id = _n
    gen double x1 = rnormal()
    gen double x2 = rnormal()
    gen double u = runiform()
    gen double t_event = -ln(u) / exp(0.4*x1 - 0.2*x2)
    gen double t_censor = runiform() * 4
    gen double t = min(t_event, t_censor)
    gen byte d = (t_event <= t_censor)
    gen byte status = 0
    replace status = 1 if d == 1 & runiform() > 0.35
    replace status = 2 if d == 1 & status == 0
    gen double t_enter = runiform() * 0.3 if runiform() > 0.5
    replace t_enter = 0 if missing(t_enter)
    drop if t_enter >= t
    stset t, failure(d) id(id) enter(time t_enter)

    _finegray_xv x1 x2, compete(status) cause(1) nolog
    matrix b_fg = e(b)
    matrix V_fg = e(V)

    preserve
    stset t, failure(status==1) id(id) enter(time t_enter)
    stcrreg x1 x2, compete(status == 2)
    matrix b_ref = e(b)
    matrix V_ref = e(V)
    restore

    * INVERTED for the same reason as C43: stcrreg does not reweight the risk set
    * for delayed entry, and the recovery gate measured that estimator as biased.
    * At least one coefficient must diverge under LT, and the SAME data with no
    * delayed entry must still reproduce stcrreg -- the divergence has to be
    * caused by the truncation, not by a general disagreement.
    local n_diverged = 0
    forvalues j = 1/2 {
        local b_rel = abs(b_fg[1,`j'] - b_ref[1,`j']) / abs(b_ref[1,`j'])
        local se_fg_j = sqrt(V_fg[`j',`j'])
        local se_ref_j = sqrt(V_ref[`j',`j'])
        local se_rel = abs(`se_fg_j' - `se_ref_j') / abs(`se_ref_j')
        display as text "  x`j' coef REL=" %6.4f `b_rel' " SE REL=" %6.4f `se_rel'
        if `b_rel' > 0.02 local ++n_diverged
    }
    assert `n_diverged' >= 1

    preserve
    quietly replace t_enter = 0
    stset t, failure(d) id(id) enter(time t_enter)
    quietly _finegray_xv x1 x2, compete(status) cause(1) nolog
    matrix b_fg0 = e(b)
    stset t, failure(status==1) id(id) enter(time t_enter)
    quietly stcrreg x1 x2, compete(status == 2)
    matrix b_ref0 = e(b)
    restore
    forvalues j = 1/2 {
        local b_rel0 = abs(b_fg0[1,`j'] - b_ref0[1,`j']) / abs(b_ref0[1,`j'])
        display as text "  no-LT parity x`j': REL=" %8.6f `b_rel0'
        assert `b_rel0' < 0.02
    }
}
if _rc == 0 {
    display as result "  PASS: C44 LT diverges from stcrreg (by design); no-LT parity holds"
    local ++pass_count
}
else {
    display as error "  FAIL: C44 left-truncation 2-cov (rc=`=_rc')"
    local ++fail_count
}

* {smcl}
* {* SECTION 20: fastcmprsk::fastCrr cross-validation}{...}

display ""
display as text _dup(60) "="
display as text "R CROSS-VALIDATION: finegray vs fastcmprsk::fastCrr"
display as text _dup(60) "="

* R output already generated in Section 18. Check if fastcmprsk results exist.
local fastcmprsk_available = 0
if `r_available' {
    preserve
    import delimited using ///
        "`datadir'/finegray_r_output.csv", ///
        clear
    quietly count if quantity == "fastcmprsk_coef"
    if r(N) > 0 {
        local fastcmprsk_available = 1
    }
    restore
}

if `fastcmprsk_available' {
    * Reload Stata results (same model as Section 18)
    _setup_hypoxia
    _finegray_xv ifp tumsize pelnode, compete(status) cause(1) nolog basehaz
    matrix b_stata = e(b)
    matrix V_stata = e(V)
    local ll_stata = e(ll)
    matrix bh_stata = e(basehaz)
    local nr_bh = rowsof(bh_stata)

    preserve
    import delimited using ///
        "`datadir'/finegray_r_output.csv", ///
        clear

    * C45: Coefficients vs fastcmprsk::fastCrr
    local ++test_count
    local t45_pass = 1
    foreach var in ifp tumsize pelnode {
        quietly {
            summ value if dataset == "hypoxia" & quantity == "fastcmprsk_coef" ///
                & variable == "`var'", meanonly
        }
        if r(N) == 0 {
            display as error "  FAIL [C45.`var']: fastCrr coef not found"
            local t45_pass = 0
            continue
        }
        local r_coef = r(mean)
        if "`var'" == "ifp" local pos = 1
        if "`var'" == "tumsize" local pos = 2
        if "`var'" == "pelnode" local pos = 3
        local s_coef = b_stata[1, `pos']
        local adiff = abs(`s_coef' - `r_coef')
        display as text "  coef[`var']: Stata=" %10.6f `s_coef' ///
            " fastCrr=" %10.6f `r_coef' " diff=" %10.3e `adiff'
        * TOLERANCE 1e-6 absolute on coefficients of size 0.03 to 0.78.
        * MEASURED 2026-09-02 (fastcmprsk 1.24.9 with a seeded fastCrr, see
        * crossval_finegray_r.R): 2.318e-09, 2.198e-08, 4.042e-08 -- so this is
        * about 25x the largest.  The 0.01 that stood here was absolute on a
        * coefficient of 0.0327: it could not have failed short of a sign error.
        if `adiff' >= 1e-6 {
            display as error "  FAIL [C45.`var']: diff `adiff' >= 1e-6"
            local t45_pass = 0
        }
    }
    if `t45_pass' {
        display as result "  PASS: C45 coefficients vs fastcmprsk::fastCrr (< 1e-6)"
        local ++pass_count
    }
    else {
        display as error "  FAIL: C45 coefficients vs fastcmprsk::fastCrr"
        local ++fail_count
    }

    * C46: Log-likelihood vs fastcmprsk::fastCrr
    local ++test_count
    capture noisily {
        quietly {
            summ value if dataset == "hypoxia" & quantity == "fastcmprsk_loglik" ///
                & variable == "final", meanonly
        }
        local r_ll = r(mean)
        local rdiff = abs(`ll_stata' - `r_ll') / abs(`r_ll')
        display as text "  loglik: Stata=" %12.4f `ll_stata' ///
            " fastCrr=" %12.4f `r_ll' " rel_diff=" %8.6f `rdiff'
        assert `rdiff' < 0.001
    }
    if _rc == 0 {
        display as result "  PASS: C46 log-likelihood vs fastcmprsk::fastCrr (< 0.1%)"
        local ++pass_count
    }
    else {
        display as error "  FAIL: C46 log-likelihood (rc=`=_rc')"
        local ++fail_count
    }

    * C47: Baseline cumulative hazard vs fastcmprsk::fastCrr
    local ++test_count
    capture noisily {
        quietly {
            summ value if dataset == "hypoxia" & quantity == "fastcmprsk_cumbasehaz" ///
                & variable == "tmax", meanonly
        }
        local r_cbh = r(mean)
        * Stata cumbasehaz at last event time
        local s_cbh = bh_stata[`nr_bh', 2]
        local adiff = abs(`s_cbh' - `r_cbh')
        display as text "  cumbasehaz(tmax): Stata=" %10.8f `s_cbh' ///
            " fastCrr=" %10.8f `r_cbh' " diff=" %10.8f `adiff'
        assert `adiff' < 0.001
    }
    if _rc == 0 {
        display as result "  PASS: C47 baseline hazard vs fastcmprsk::fastCrr (< 0.001)"
        local ++pass_count
    }
    else {
        display as error "  FAIL: C47 baseline hazard (rc=`=_rc')"
        local ++fail_count
    }

    * C48: CIF at z=0 vs fastcmprsk::fastCrr
    local ++test_count
    local t48_pass = 1
    local t48_ncmp = 0
    foreach tt in 2 5 10 {
        quietly {
            summ value if dataset == "hypoxia" & quantity == "fastcmprsk_cif_ref" ///
                & variable == "t`tt'", meanonly
        }
        if r(N) == 0 {
            display as text "  SKIP [C48.t`tt']: fastCrr cif_ref not found"
            continue
        }
        local r_cif = r(mean)
        * Stata CIF at z=0: 1 - exp(-H0(t))
        local H0_tt = 0
        forvalues j = 1/`nr_bh' {
            if bh_stata[`j', 1] <= `tt' {
                local H0_tt = bh_stata[`j', 2]
            }
        }
        local s_cif = 1 - exp(-`H0_tt')
        local adiff = abs(`s_cif' - `r_cif')
        local ++t48_ncmp
        display as text "  CIF(t=`tt',z=0): Stata=" %8.6f `s_cif' ///
            " fastCrr=" %8.6f `r_cif' " diff=" %10.3e `adiff'
        * TOLERANCE 1e-6 absolute on CIFs of size 0.058 to 0.078.  MEASURED
        * 2026-09-02: 1.598e-08, 1.600e-08, 1.885e-08 -- about 50x the largest.
        * The 0.01 that stood here was a sixth of the quantity being compared.
        if `adiff' >= 1e-6 {
            display as error "  FAIL [C48.t`tt']: diff `adiff' >= 1e-6"
            local t48_pass = 0
        }
    }
    if `t48_ncmp' != 3 {
        display as error "  FAIL: C48 compared `t48_ncmp' of 3 planned time points"
        local t48_pass = 0
    }
    if `t48_pass' {
        display as result "  PASS: C48 CIF at z=0 vs fastcmprsk::fastCrr (< 1e-6)"
        local ++pass_count
    }
    else {
        display as error "  FAIL: C48 CIF vs fastcmprsk::fastCrr"
        local ++fail_count
    }

    * C49: Bootstrap SEs vs analytic SEs (fastcmprsk uses bootstrap, not sandwich)
    * Bootstrap SEs should be in the same ballpark — within 50% of analytic.
    local ++test_count
    local t49_pass = 1
    foreach var in ifp tumsize pelnode {
        quietly {
            summ value if dataset == "hypoxia" & quantity == "fastcmprsk_se" ///
                & variable == "`var'", meanonly
        }
        if r(N) == 0 {
            display as error "  FAIL [C49.`var']: fastCrr SE not found"
            local t49_pass = 0
            continue
        }
        local r_se = r(mean)
        if "`var'" == "ifp" local pos = 1
        if "`var'" == "tumsize" local pos = 2
        if "`var'" == "pelnode" local pos = 3
        local s_se = sqrt(V_stata[`pos', `pos'])
        local rdiff = abs(`s_se' - `r_se') / `r_se'
        display as text "  SE[`var']: Stata=" %10.6f `s_se' ///
            " fastCrr(boot)=" %10.6f `r_se' " rel_diff=" %10.3e `rdiff'
        * TOLERANCE 0.30 RELATIVE, and deliberately not tighter.  This is the
        * one comparison in the block that is not an identity: fastCrr's SE is a
        * 200-replication BOOTSTRAP standard error (varianceControl(B = 200)),
        * finegray's is the analytic sandwich, so the two estimate the same
        * quantity by different routes and a gap of tens of percent is the
        * expected sampling behaviour of a 200-replication bootstrap, not a
        * defect.  MEASURED 2026-09-02 with the R script's seed fixed:
        * 1.517e-01, 6.071e-02, 1.680e-01.  0.30 is about 1.8x the largest --
        * enough headroom for the bootstrap's own noise across R versions, and
        * tight enough that a genuinely wrong analytic SE (a dropped
        * finite-sample correction is 1/N, a wrong meat form is a factor) fails.
        * The 0.50 that stood here was 3x the largest measurement.
        if `rdiff' >= 0.30 {
            display as error "  FAIL [C49.`var']: rel_diff `rdiff' >= 0.30"
            local t49_pass = 0
        }
    }
    if `t49_pass' {
        display as result ///
            "  PASS: C49 bootstrap SEs vs analytic (< 30% — expected divergence)"
        local ++pass_count
    }
    else {
        display as error "  FAIL: C49 bootstrap SEs vs analytic"
        local ++fail_count
    }

    * C50: Three-way agreement — finegray vs cmprsk vs fastcmprsk
    * Verify all three implementations agree on coefficients within tolerance
    local ++test_count
    local t50_pass = 1
    foreach var in ifp tumsize pelnode {
        quietly {
            summ value if dataset == "hypoxia" & quantity == "coef" ///
                & variable == "`var'", meanonly
        }
        local crr_coef = r(mean)
        quietly {
            summ value if dataset == "hypoxia" & quantity == "fastcmprsk_coef" ///
                & variable == "`var'", meanonly
        }
        local fast_coef = r(mean)
        if "`var'" == "ifp" local pos = 1
        if "`var'" == "tumsize" local pos = 2
        if "`var'" == "pelnode" local pos = 3
        local s_coef = b_stata[1, `pos']
        * Max pairwise difference across all three
        local d12 = abs(`s_coef' - `crr_coef')
        local d13 = abs(`s_coef' - `fast_coef')
        local d23 = abs(`crr_coef' - `fast_coef')
        local maxd = max(`d12', `d13', `d23')
        display as text "  `var': finegray=" %10.6f `s_coef' ///
            " crr=" %10.6f `crr_coef' " fastCrr=" %10.6f `fast_coef' ///
            " max_diff=" %10.3e `maxd'
        * TOLERANCE 1e-6 absolute.  Three independent implementations of the
        * same estimator on the same data.  MEASURED 2026-09-02: 3.725e-09,
        * 2.98e-08, 5.96e-08 -- about 17x the largest.
        if `maxd' >= 1e-6 {
            display as error "  FAIL [C50.`var']: max_diff `maxd' >= 1e-6"
            local t50_pass = 0
        }
    }
    if `t50_pass' {
        display as result "  PASS: C50 three-way coef agreement (< 1e-6)"
        local ++pass_count
    }
    else {
        display as error "  FAIL: C50 three-way agreement"
        local ++fail_count
    }
    restore
}
else {
    * fastcmprsk not available — skip C45-C50
    display as text "  SKIP: fastcmprsk tests (C45-C50) — package not available"
    forvalues i = 45/50 {
        local ++test_count
        local ++skip_count
    }
}

* {smcl}
* {* SECTION 21: Strata cross-validation vs cmprsk::crr cengroup}{...}

display ""
display as text _dup(60) "="
display as text "R CROSS-VALIDATION: finegray strata() vs cmprsk::crr cengroup"
display as text _dup(60) "="

if `r_strata_available' {
    preserve
    import delimited using ///
        "`datadir'/finegray_r_strata_output.csv", ///
        clear
    isid dataset quantity variable

    * C51: Strata coefficients vs crr cengroup
    * This is a regression gate for group-specific IPCW numerators: using one
    * pooled competing-event accumulator shifts tumsize by about .002 in this
    * dataset even though each stratum's censoring KM is otherwise correct.
    local ++test_count
    local t51_pass = 1
    foreach var in ifp tumsize {
        quietly {
            summ value if dataset == "hypoxia_strata" & ///
                quantity == "strata_coef" & variable == "`var'", meanonly
        }
        if r(N) == 0 {
            display as error "  FAIL [C51.`var']: R strata coef not found"
            local t51_pass = 0
            continue
        }
        local r_coef = r(mean)
        if "`var'" == "ifp" local pos = 1
        if "`var'" == "tumsize" local pos = 2
        local s_coef = b_strata_stata[1, `pos']
        local adiff = abs(`s_coef' - `r_coef')
        display as text "  strata coef[`var']: Stata=" %10.6f `s_coef' ///
            " R(cengroup)=" %10.6f `r_coef' " diff=" %8.6f `adiff'
        if `adiff' >= 1e-6 {
            display as error "  FAIL [C51.`var']: diff `adiff' >= 1e-6"
            local t51_pass = 0
        }
    }
    if `t51_pass' {
        display as result ///
            "  PASS: C51 strata coefficients vs crr cengroup (< 1e-6)"
        local ++pass_count
    }
    else {
        display as error "  FAIL: C51 strata coefficients vs crr cengroup"
        local ++fail_count
    }

    * C52: Strata robust SEs vs crr cengroup
    local ++test_count
    local t52_pass = 1
    foreach var in ifp tumsize {
        quietly {
            summ value if dataset == "hypoxia_strata" & ///
                quantity == "strata_se_robust" & variable == "`var'", meanonly
        }
        if r(N) == 0 {
            display as error "  FAIL [C52.`var']: R strata SE not found"
            local t52_pass = 0
            continue
        }
        local r_se = r(mean)
        if "`var'" == "ifp" local pos = 1
        if "`var'" == "tumsize" local pos = 2
        local s_se = sqrt(V_strata_stata[`pos', `pos'])
        local rdiff = abs(`s_se' - `r_se') / `r_se'
        display as text "  strata se[`var']: Stata=" %10.6f `s_se' ///
            " R(cengroup)=" %10.6f `r_se' " rel_diff=" %6.3f `rdiff'
        if `rdiff' >= 0.001 {
            display as error "  FAIL [C52.`var']: rel_diff `rdiff' >= 0.001"
            local t52_pass = 0
        }
    }
    if `t52_pass' {
        display as result ///
            "  PASS: C52 strata robust SEs vs crr cengroup (< 0.1%)"
        local ++pass_count
    }
    else {
        display as error "  FAIL: C52 strata robust SEs vs crr cengroup"
        local ++fail_count
    }

    * C53: Strata log-likelihood vs crr cengroup
    local ++test_count
    capture noisily {
        quietly {
            summ value if dataset == "hypoxia_strata" & ///
                quantity == "strata_loglik" & variable == "final", meanonly
        }
        local r_ll = r(mean)
        local rdiff = abs(`ll_strata_stata' - `r_ll') / abs(`r_ll')
        display as text "  strata loglik: Stata=" %12.4f `ll_strata_stata' ///
            " R(cengroup)=" %12.4f `r_ll' " rel_diff=" %8.6f `rdiff'
        assert `rdiff' < 1e-6
    }
    if _rc == 0 {
        display as result ///
            "  PASS: C53 strata log-likelihood vs crr cengroup (< 1e-6 relative)"
        local ++pass_count
    }
    else {
        display as error "  FAIL: C53 strata log-likelihood (rc=`=_rc')"
        local ++fail_count
    }

    * C54: Strata CIF at z=0 vs crr cengroup
    local ++test_count
    local t54_pass = 1
    local t54_ncmp = 0
    * Get Stata baseline hazard for CIF calculation
    restore
    _setup_hypoxia
    _finegray_xv ifp tumsize, compete(status) cause(1) nolog strata(pelnode) basehaz
    matrix bh_strata = e(basehaz)
    local nr_bh_s = rowsof(bh_strata)
    preserve
    import delimited using ///
        "`datadir'/finegray_r_strata_output.csv", ///
        clear
    foreach tt in 2 5 10 {
        quietly {
            summ value if dataset == "hypoxia_strata" & ///
                quantity == "strata_cif_ref" & variable == "t`tt'", meanonly
        }
        if r(N) == 0 {
            display as text "  SKIP [C54.t`tt']: R strata cif_ref not found"
            continue
        }
        local r_cif = r(mean)
        * Find Stata H0 at time tt
        local H0_tt = 0
        forvalues j = 1/`nr_bh_s' {
            if bh_strata[`j', 1] <= `tt' {
                local H0_tt = bh_strata[`j', 2]
            }
        }
        local s_cif = 1 - exp(-`H0_tt')
        local adiff = abs(`s_cif' - `r_cif')
        local ++t54_ncmp
        display as text "  strata CIF(t=`tt',z=0): Stata=" %8.6f `s_cif' ///
            " R(cengroup)=" %8.6f `r_cif' " diff=" %8.6f `adiff'
        if `adiff' >= 1e-5 {
            display as error "  FAIL [C54.t`tt']: diff `adiff' >= 1e-5"
            local t54_pass = 0
        }
    }
    if `t54_ncmp' != 3 {
        display as error "  FAIL: C54 compared `t54_ncmp' of 3 planned time points"
        local t54_pass = 0
    }
    if `t54_pass' {
        display as result ///
            "  PASS: C54 strata CIF at z=0 vs crr cengroup (< 1e-5)"
        local ++pass_count
    }
    else {
        display as error "  FAIL: C54 strata CIF vs crr cengroup"
        local ++fail_count
    }

    * C55: Strata vs no-strata — coefficients differ (confirms strata is active)
    local ++test_count
    capture noisily {
        * Get unstratified R coefficients for comparison
        restore
        preserve
        import delimited using ///
            "`datadir'/finegray_r_strata_output.csv", ///
            clear
        * Unstratified coef (from the same dataset, no cengroup)
        quietly summ value if dataset == "hypoxia_strata" & ///
            quantity == "coef" & variable == "ifp", meanonly
        assert r(N) == 1
        local r_nostrata_coef = r(mean)
        * Stratified coef
        quietly summ value if dataset == "hypoxia_strata" & ///
            quantity == "strata_coef" & variable == "ifp", meanonly
        assert r(N) == 1
        local r_strata_coef = r(mean)
        * They should be similar but not identical (different censoring model)
        local coef_diff = abs(`r_strata_coef' - `r_nostrata_coef')
        display as text "  R coef[ifp]: no-strata=" %10.6f `r_nostrata_coef' ///
            " strata=" %10.6f `r_strata_coef' " diff=" %8.6f `coef_diff'
        * Both should be non-zero
        assert `r_strata_coef' < . & `r_nostrata_coef' < .
        assert `r_strata_coef' != 0
        assert `r_nostrata_coef' != 0
        * The check is named for an active cengroup contrast.  Nonzero
        * coefficients alone would also pass if cengroup were silently ignored.
        assert `coef_diff' > 1e-8 & `coef_diff' < .
    }
    if _rc == 0 {
        display as result ///
            "  PASS: C55 strata vs no-strata differ in R (confirms cengroup active)"
        local ++pass_count
    }
    else {
        display as error "  FAIL: C55 strata vs no-strata (rc=`=_rc')"
        local ++fail_count
    }
    restore
}
else {
    * R strata not available — skip C51-C55
    display as text ///
        "  SKIP: strata crossval tests (C51-C55) — R strata output not available"
    forvalues i = 51/55 {
        local ++test_count
        local ++skip_count
    }
}

* {smcl}
* {* SUMMARY}{...}
display ""
display as text _dup(60) "="
display as text "RESULTS: crossval_finegray.do"
display as text _dup(60) "="
display as text "Total:   " as result `test_count'
display as text "Passed:  " as result `pass_count'
display as text "Failed:  " as result `fail_count'
display as text "Skipped: " as result `skip_count'
display as text _dup(60) "="
display as text "RESULT: crossval_finegray tests=`test_count' pass=`pass_count' fail=`fail_count' skip=`skip_count'"

foreach f in finegray_r_input.csv finegray_r_output.csv ///
    finegray_r_strata.csv finegray_r_strata_output.csv {
    capture erase "`datadir'/`f'"
}
capture rmdir "`datadir'"

* A SKIPPED EXTERNAL ORACLE IS AN UNRUN CHECK, NOT A PASS (2026-09-02).
* This suite used to print "RESULT: PASS (n passed, k skipped)" and exit 0 when
* the R oracle was unavailable, so a machine with no R -- or with the package
* missing -- produced a green cross-validation that had cross-validated nothing.
* run_all.do already treats skip > 0 as a lane failure by parsing the machine
* sentinel, but a human reading the suite's own last line was told PASS.  Match
* crossval_pweight.do: skip > 0 exits 1, and the word PASS is not printed on a
* skipped run.  The machine sentinel above is unchanged -- run_all.do parses
* `RESULT: <name> tests=.. pass=.. fail=.. skip=..' and nothing else.
if `fail_count' > 0 {
    display as error "RESULT: FAIL (`fail_count' of `test_count' tests failed)"
    log close _crossval_finegray
    exit 1
}
else if `skip_count' > 0 {
    display as error ///
        "RESULT: NOT RUN (`pass_count' checked, `skip_count' SKIPPED -- an R oracle was unavailable)"
    display as error "Install the missing R dependency and re-run; a skipped oracle is not evidence."
    log close _crossval_finegray
    exit 1
}
display as result "RESULT: PASS (all `test_count' tests passed)"

log close _crossval_finegray
