* test_finegray_optimizer.do
* Phase 2 gate: optimizer safety (FG-H05, H07, H08, H09, H10).
*
* The unifying v1.1.4 defect: EVERY one of these failure modes returned rc 0,
* with full results posted and (mostly) converged=1. So every test below asserts
* the RETURN CODE or the posted state -- never merely "it didn't crash".
*
*   FG-H05  rank-deficient information was silently g-inverted. invsym() returns
*           a generalized inverse with NO missing values, so the v1.1.4 guard
*           `if (missing(info_inv[1,1]))' could never fire. A direction the
*           likelihood is exactly flat in was handed a FABRICATED coefficient
*           (beta = -8.10, SE = 0, converged = 1, rc 0).
*   FG-H07  iterate(1) -> rc 0 with results posted and e(converged)=0.
*   FG-H08  early convergence left e(ll) stale: tolerance(1) gave a nonzero beta
*           while e(ll) == e(ll_0) EXACTLY.
*   FG-H09  tolerance(.) accepted (rc 0, converged=1). syntax's `real' type
*           admits missing, and `. <= 0' is false in Stata.
*   FG-H10  (a) scale invariance failed: x vs 1e6*x gave log-likelihoods 18.05
*               apart, both converged=1 -- the rescaled fit stopped early at a
*               worse optimum, because the convergence test was stated on the
*               coefficient scale.
*           (b) line-search off-by-one: after 20 halvings the guard tested
*               step_scale = 2^-20 while the accepted beta_new was built at
*               2^-19.
*           (c) Mata exp(overflow) is missing, and (. > -500) is TRUE, so a
*               missing trial likelihood was accepted as an improvement.
*
* Note on FG-H07: this deliberately diverges from stcrreg, which posts results
* with rc 0 and e(converged)=0. finegray's own bootstrap refits (finegray_cif,
* finegray_predict) call finegray QUIETLY, where a warning is invisible -- a
* nonconverged replication would silently enter the confidence band. A nonzero
* rc is the only signal that path can act on.

clear all
set varabbrev off
version 16.0

capture log close _all
log using "test_finegray_optimizer.log", replace name(_opt)

local qa_dir "`c(pwd)'"
do "`qa_dir'/_finegray_qa_common.do"

local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
capture ado uninstall finegray
quietly net install finegray, from("`pkg_dir'") replace

local test_count = 0
local pass_count = 0
local fail_count = 0

**# 1. FG-H05: an unidentified direction must be a hard error, not a coefficient
* x2 is nonzero ONLY for subjects censored before the first cause event, so it
* enters no cause-event risk set and the likelihood is exactly flat in it. Z is
* globally full rank, so _rmcoll passes -- this is precisely the hole the
* missing() guard left open.
local ++test_count
capture noisily {
    _finegray_qa_unident_data

    * The premise: _rmcoll must NOT be what rejects this, or the test is
    * exercising the wrong guard entirely.
    quietly _rmcoll x x2, forcedrop
    assert r(k_omitted) == 0

    quietly stset t, failure(etype) id(id)
    capture finegray x x2, compete(etype) cause(1) norobust nolog
    local rc_unident = _rc
    display as text "  unidentified-direction rc = `rc_unident' (v1.1.4: 0)"
    assert `rc_unident' == 459
}
if _rc == 0 {
    display as result "  PASS: FG-H05 rank-deficient information errors r(459)"
    local ++pass_count
}
else {
    display as error "  FAIL: FG-H05 rank-deficient information (rc=`=_rc')"
    local ++fail_count
}

**# 2. FG-H05: the identified sub-model still fits
* The guard must reject the unidentified TERM, not the dataset. Dropping x2 from
* the same data must fit cleanly -- otherwise the rank test is over-firing.
local ++test_count
capture noisily {
    _finegray_qa_unident_data
    quietly stset t, failure(etype) id(id)
    capture noisily finegray x, compete(etype) cause(1) norobust nolog
    assert _rc == 0
    assert e(converged) == 1
    assert !missing(_b[x])
    assert _se[x] > 0 & _se[x] < .
}
if _rc == 0 {
    display as result "  PASS: FG-H05 guard does not over-fire on the identified sub-model"
    local ++pass_count
}
else {
    display as error "  FAIL: FG-H05 guard over-fires (rc=`=_rc')"
    local ++fail_count
}

**# 3. FG-H07: nonconvergence must be a hard failure
local ++test_count
capture noisily {
    _finegray_qa_tied_data
    quietly stset t, failure(etype) id(id)
    capture finegray x, compete(etype) cause(1) norobust nolog iterate(1)
    local rc_noconv = _rc
    display as text "  iterate(1) rc = `rc_noconv' (v1.1.4: 0, converged=0, results posted)"
    assert `rc_noconv' == 430
}
if _rc == 0 {
    display as result "  PASS: FG-H07 nonconvergence errors r(430)"
    local ++pass_count
}
else {
    display as error "  FAIL: FG-H07 nonconvergence (rc=`=_rc')"
    local ++fail_count
}

**# 4. FG-H07: a converged fit posts converged=1 (the guard is not blanket)
local ++test_count
capture noisily {
    _finegray_qa_tied_data
    quietly stset t, failure(etype) id(id)
    capture noisily finegray x, compete(etype) cause(1) norobust nolog iterate(200)
    assert _rc == 0
    assert e(converged) == 1
}
if _rc == 0 {
    display as result "  PASS: FG-H07 converged fit still succeeds"
    local ++pass_count
}
else {
    display as error "  FAIL: FG-H07 converged fit (rc=`=_rc')"
    local ++fail_count
}

**# 5. FG-H08: e(ll) must be recomputed at the accepted beta
* tolerance(1) converges on the first step. v1.1.4 took that step but never
* re-evaluated the likelihood, so it posted a nonzero beta alongside
* e(ll) == e(ll_0) exactly. e(ll) must now correspond to e(b).
local ++test_count
capture noisily {
    _finegray_qa_tied_data
    quietly stset t, failure(etype) id(id)
    quietly finegray x, compete(etype) cause(1) norobust nolog tolerance(1)
    local b_loose = _b[x]
    local ll_loose = e(ll)
    local ll0_loose = e(ll_0)

    display as text "  beta = " %14.8f `b_loose'
    display as text "  e(ll)   = " %18.10f `ll_loose'
    display as text "  e(ll_0) = " %18.10f `ll0_loose'

    * beta genuinely moved off zero ...
    assert abs(`b_loose') > 1e-6
    * ... so the likelihood at beta cannot equal the likelihood at 0
    assert `ll_loose' != `ll0_loose'
    * and it must be an improvement on the null
    assert `ll_loose' > `ll0_loose'

    * independent oracle: e(ll) must equal the tight fit's ll to the precision
    * a one-step fit can reach -- i.e. it is a real likelihood at a real beta
    quietly finegray x, compete(etype) cause(1) norobust nolog
    assert reldif(`ll_loose', e(ll)) < 1e-6
}
if _rc == 0 {
    display as result "  PASS: FG-H08 e(ll) is recomputed at the accepted beta"
    local ++pass_count
}
else {
    display as error "  FAIL: FG-H08 stale e(ll) (rc=`=_rc')"
    local ++fail_count
}

**# 6. FG-H09: tolerance(.) must be rejected
local ++test_count
capture noisily {
    _finegray_qa_tied_data
    quietly stset t, failure(etype) id(id)
    capture finegray x, compete(etype) cause(1) norobust nolog tolerance(.)
    local rc_tolmiss = _rc
    display as text "  tolerance(.) rc = `rc_tolmiss' (v1.1.4: 0, converged=1)"
    assert `rc_tolmiss' == 198

    * mirror-check the guard that already worked, so both stay closed
    capture finegray x, compete(etype) cause(1) norobust nolog iterate(.)
    assert _rc == 198
    capture finegray x, compete(etype) cause(1) norobust nolog tolerance(0)
    assert _rc == 198
    capture finegray x, compete(etype) cause(1) norobust nolog tolerance(-1)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: FG-H09 tolerance(.)/(0)/(-1) and iterate(.) all rejected"
    local ++pass_count
}
else {
    display as error "  FAIL: FG-H09 degenerate tolerance accepted (rc=`=_rc')"
    local ++fail_count
}

**# 7. FG-H10(a): scale invariance
* Rescaling a covariate is a linear reparameterization: it must not change the
* optimum. beta(1e6*x) must equal beta(x)/1e6 and the log-likelihoods must be
* identical. v1.1.4's convergence test was stated on the coefficient scale, so
* the 1e6 fit tripped it immediately and stopped 18.05 log-likelihood units
* short -- while still reporting converged=1.
local ++test_count
capture noisily {
    _finegray_qa_tied_data
    gen double x6 = 1e6 * x
    quietly stset t, failure(etype) id(id)

    quietly finegray x, compete(etype) cause(1) norobust nolog
    local b1 = _b[x]
    local ll1 = e(ll)
    assert e(converged) == 1

    quietly finegray x6, compete(etype) cause(1) norobust nolog
    local b2 = _b[x6]
    local ll2 = e(ll)
    assert e(converged) == 1

    display as text "  beta(x)      = " %18.12f `b1'
    display as text "  1e6*beta(x6) = " %18.12f (1e6 * `b2')
    display as text "  ll(x)  = " %18.10f `ll1'
    display as text "  ll(x6) = " %18.10f `ll2'
    display as text "  |dll|  = " %10.2e abs(`ll1' - `ll2')

    * the log-likelihood is invariant under reparameterization: same optimum
    assert reldif(`ll1', `ll2') < 1e-10
    assert reldif(`b1', 1e6 * `b2') < 1e-6
}
if _rc == 0 {
    display as result "  PASS: FG-H10(a) optimizer is scale invariant"
    local ++pass_count
}
else {
    display as error "  FAIL: FG-H10(a) scale invariance (rc=`=_rc')"
    local ++fail_count
}

**# 8. FG-H10(a): scale invariance downward
local ++test_count
capture noisily {
    _finegray_qa_tied_data
    gen double xs = 1e-6 * x
    quietly stset t, failure(etype) id(id)

    quietly finegray x, compete(etype) cause(1) norobust nolog
    local ll1 = e(ll)
    quietly finegray xs, compete(etype) cause(1) norobust nolog
    assert e(converged) == 1
    display as text "  |dll| = " %10.2e abs(`ll1' - e(ll))
    assert reldif(`ll1', e(ll)) < 1e-10
}
if _rc == 0 {
    display as result "  PASS: FG-H10(a) scale invariant under 1e-6 rescaling"
    local ++pass_count
}
else {
    display as error "  FAIL: FG-H10(a) downward scale invariance (rc=`=_rc')"
    local ++fail_count
}

**# 9. FG-H10(c): a nonfinite trial likelihood is never accepted
* Mata returns exp(overflow) as missing, and `(. > ll)' is TRUE, so a bare
* `ll_new > ll' test accepts a missing likelihood as an improvement. Drive the
* linear predictor into overflow territory with an extreme covariate scale: the
* fit must either converge to a real optimum or fail loudly -- it must never
* post a missing likelihood or a missing coefficient as a success.
local ++test_count
capture noisily {
    _finegray_qa_tied_data
    gen double xbig = 500 * x
    quietly stset t, failure(etype) id(id)

    capture finegray xbig, compete(etype) cause(1) norobust nolog
    local rc_big = _rc
    display as text "  extreme-scale rc = `rc_big'"
    if `rc_big' == 0 {
        * if it reports success, the success must be real
        display as text "  converged=" e(converged) "  ll=" %14.6f e(ll) "  b=" %14.8g _b[xbig]
        assert e(converged) == 1
        assert !missing(e(ll))
        assert !missing(_b[xbig])
        assert !missing(_se[xbig])
    }
    else {
        * a failure is acceptable; a SILENT one is not
        display as text "  failed loudly with rc `rc_big' (acceptable)"
        assert inlist(`rc_big', 430, 459, 498)
    }
}
if _rc == 0 {
    display as result "  PASS: FG-H10(c) no missing likelihood accepted as success"
    local ++pass_count
}
else {
    display as error "  FAIL: FG-H10(c) nonfinite trial likelihood (rc=`=_rc')"
    local ++fail_count
}

**# 10. Optimizer invariants on a normal fit
* Whatever else changed, a healthy fit must still land on the true optimum: the
* score at e(b) must be ~0 and the likelihood must beat the null.
local ++test_count
capture noisily {
    _finegray_qa_tied_data
    quietly stset t, failure(etype) id(id)
    quietly finegray x, compete(etype) cause(1) nolog

    assert e(converged) == 1
    assert e(ll) > e(ll_0)
    assert !missing(e(ll)) & !missing(e(ll_0))
    assert e(N) == 300
    assert _se[x] > 0 & _se[x] < .

    * tightening the tolerance must not move the answer: we are AT the optimum,
    * not merely inside a loose stopping rule
    local b_default = _b[x]
    quietly finegray x, compete(etype) cause(1) nolog tolerance(1e-14)
    display as text "  b(tol 1e-8)=" %18.12f `b_default' "  b(tol 1e-14)=" %18.12f _b[x]
    assert reldif(`b_default', _b[x]) < 1e-9
}
if _rc == 0 {
    display as result "  PASS: converged fit sits at the optimum (tolerance-independent)"
    local ++pass_count
}
else {
    display as error "  FAIL: optimizer invariants (rc=`=_rc')"
    local ++fail_count
}

**# Summary
display as text _newline ///
    "RESULT: test_finegray_optimizer tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    log close _opt
    exit 1
}
display as result "ALL TESTS PASSED"
log close _opt
