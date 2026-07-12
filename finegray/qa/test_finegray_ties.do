* test_finegray_ties.do
* Phase 1 gate: estimator core numerics (FG-C02, FG-C03).
*
* Every test here FAILS against v1.1.4 and passes after the fix. That is the
* point of the suite: the pre-existing oracles could not go red on either
* defect, because the flagship fixture (webuse hypoxia) has zero cause-event
* times shared with a censored observation.
*
*   FG-C02  censoring ties must use the LEFT LIMIT G(t-). v1.1.4 applied the
*           KM jump at t before assigning G to the observations at t, so any
*           observation sharing its time with a censoring event absorbed that
*           jump. cmprsk (xout = ftime*(1-100*eps)) and stcrreg both use G(t-).
*           v1.1.4 on the tied fixture: off by 2.05e-03 vs stcrreg.
*
*   FG-C03  Stata intervals are (t0, t], so a subject entering at exactly t is
*           NOT at risk for a failure at t. v1.1.4 admitted it (t0 <= t) at
*           seven scan sites, so nudging an entry time by 1e-7 moved the
*           coefficients by 2.2e-03. stcrreg is exactly invariant.
*
* Oracle: stcrreg (StataCorp). Note that stcrreg's DEFAULT convergence
* tolerances leave it ~3e-08 from its own fixed point, which is looser than the
* agreement we are asserting -- so the oracle is run with tightened tolerances.
* Comparing against default-tolerance stcrreg would cap this test's resolution
* at 1e-07 and hide any future regression finer than that.

clear all
set varabbrev off
version 16.0

capture log close _all
log using "test_finegray_ties.log", replace name(_ties)

local qa_dir "`c(pwd)'"
do "`qa_dir'/_finegray_qa_common.do"

local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
capture ado uninstall finegray
quietly net install finegray, from("`pkg_dir'") replace

local test_count = 0
local pass_count = 0
local fail_count = 0

* Parity tolerance between two INDEPENDENT double-precision Newton solvers.
*
* Both estimators are at their own fixed points here (tightening either one's
* tolerance further moves nothing), so the residual is not convergence slack --
* it is floating-point accumulation noise. With a log pseudo-likelihood of order
* 1e3, double precision resolves ll to ~1e-13 absolute, which maps to a
* coefficient uncertainty of roughly sqrt(2*1e-13 / lambda_min(I)) ~ 1e-8. So
* ~1e-8 relative is the FLOOR of what any two independent implementations can
* agree to; asserting below it would be testing the summation order, not the
* estimator. Observed here: 5e-13 (1 covariate), 1.4e-09 (2 covariates).
*
* 1e-7 sits above that floor and far below the defect it guards: FG-C02 moved
* the tied-data coefficient by 3.6e-03 relative, ~36,000x this gate. Verified
* to go RED against v1.1.4 at this tolerance.
local tol_parity = 1e-7

**# 1. The flagship fixture is BLIND to censoring ties -- assert why
* This test asserts a property of webuse hypoxia, not of finegray. It exists so
* that the reason the old suite could be green while FG-C02 was live is
* recorded as an executable fact rather than a comment: on hypoxia a G(t) and a
* G(t-) implementation agree exactly, because no cause-event time is shared
* with a censored observation.
local ++test_count
capture noisily {
    webuse hypoxia, clear
    quietly levelsof dftime if failtype == 1, local(evtimes)
    local n_shared = 0
    foreach tt of local evtimes {
        quietly count if failtype == 0 & dftime == `tt'
        if r(N) > 0 local ++n_shared
    }
    local n_ev : word count `evtimes'
    display as text "  hypoxia: `n_ev' distinct cause-event times, " ///
        "`n_shared' shared with a censored obs"
    assert `n_ev' > 0
    assert `n_shared' == 0
}
if _rc == 0 {
    display as result "  PASS: hypoxia has zero censor/event time collisions (tie-blind by construction)"
    local ++pass_count
}
else {
    display as error "  FAIL: hypoxia tie structure changed (rc=`=_rc')"
    local ++fail_count
}

**# 2. FG-C02: tied data -- finegray must match stcrreg
* v1.1.4: finegray -0.5660184124 vs stcrreg -0.5680729200 (absdif 2.05e-03).
local ++test_count
capture noisily {
    _finegray_qa_tied_data

    * the fixture must actually be tied, or this test proves nothing
    quietly levelsof t if etype == 1, local(evtimes)
    local n_shared = 0
    foreach tt of local evtimes {
        quietly count if etype == 0 & t == `tt'
        if r(N) > 0 local ++n_shared
    }
    display as text "  tied fixture: `n_shared' cause-event times shared with a censored obs"
    assert `n_shared' >= 3

    * oracle: stcrreg, converged tightly (see header note)
    quietly stset t, failure(etype == 1) id(id)
    quietly stcrreg x, compete(etype == 2) nolog ///
        tolerance(1e-11) ltolerance(1e-13) nrtolerance(1e-11)
    local b_stcrreg = _b[x]

    quietly stset t, failure(etype) id(id)
    quietly finegray x, compete(etype) cause(1) norobust nolog
    local b_finegray = _b[x]

    display as text "  finegray = " %20.12f `b_finegray'
    display as text "  stcrreg  = " %20.12f `b_stcrreg'
    display as text "  reldif   = " %10.2e reldif(`b_finegray', `b_stcrreg')
    assert reldif(`b_finegray', `b_stcrreg') < `tol_parity'
}
if _rc == 0 {
    display as result "  PASS: FG-C02 tied-data parity with stcrreg"
    local ++pass_count
}
else {
    display as error "  FAIL: FG-C02 tied-data parity with stcrreg (rc=`=_rc')"
    local ++fail_count
}

**# 3. FG-C02: tied data, multiple covariates and robust VCE
local ++test_count
capture noisily {
    _finegray_qa_tied_data, n(500) seed(99)
    gen double z = rnormal() + 0.3 * x

    quietly stset t, failure(etype == 1) id(id)
    quietly stcrreg x z, compete(etype == 2) nolog ///
        tolerance(1e-11) ltolerance(1e-13) nrtolerance(1e-11)
    local b_x = _b[x]
    local b_z = _b[z]

    quietly stset t, failure(etype) id(id)
    quietly finegray x z, compete(etype) cause(1) nolog

    display as text "  x: finegray=" %14.10f _b[x] "  stcrreg=" %14.10f `b_x'
    display as text "  z: finegray=" %14.10f _b[z] "  stcrreg=" %14.10f `b_z'
    assert reldif(_b[x], `b_x') < `tol_parity'
    assert reldif(_b[z], `b_z') < `tol_parity'
}
if _rc == 0 {
    display as result "  PASS: FG-C02 tied-data parity, 2 covariates"
    local ++pass_count
}
else {
    display as error "  FAIL: FG-C02 tied-data parity, 2 covariates (rc=`=_rc')"
    local ++fail_count
}

**# 4. FG-C03: entry-boundary invariance
* Moving a block of entry times from exactly 5 to 5+1e-7, with no event times
* in between, cannot change the risk sets -- so it cannot change any estimate.
* v1.1.4 moved by 2.245e-03. stcrreg is exactly invariant; so are we now.
local ++test_count
capture noisily {
    _finegray_qa_entry_data, eps(0)
    quietly count if etype == 1 & t == 5
    assert r(N) > 0              // there must BE cause events at the entry time
    quietly stset t, failure(etype) id(id) time0(t0)
    quietly finegray x, compete(etype) cause(1) norobust nolog
    local b_at5 = _b[x]

    _finegray_qa_entry_data, eps(1e-7)
    quietly stset t, failure(etype) id(id) time0(t0)
    quietly finegray x, compete(etype) cause(1) norobust nolog
    local b_eps = _b[x]

    display as text "  t0=5     : " %20.12f `b_at5'
    display as text "  t0=5+1e-7: " %20.12f `b_eps'
    display as text "  shift    : " %10.2e abs(`b_at5' - `b_eps')

    * The two risk sets are literally identical, so the estimate must be too --
    * but NOT bit-identical: this fixture is heavily tied, Stata randomizes the
    * order of tied observations after `sort' (governed by the sort seed), and
    * Mata's order() is not stable. The two fits therefore accumulate the same
    * sums in a different order, differing in the last ulp. Asserting exact
    * equality here tests the summation order, not the estimator -- and it does
    * so nondeterministically (it passed standalone and failed under run_all,
    * where earlier suites had advanced the sort seed).
    *
    * 1e-12 is ~10 orders below the defect it guards (FG-C03 moved this
    * coefficient by 2.245e-03, i.e. 2.3e-02 relative) and ~4 orders above ulp
    * noise. Verified to go RED against v1.1.4.
    assert reldif(`b_at5', `b_eps') < 1e-12
}
if _rc == 0 {
    display as result "  PASS: FG-C03 entry-boundary invariance (exact)"
    local ++pass_count
}
else {
    display as error "  FAIL: FG-C03 entry-boundary invariance (rc=`=_rc')"
    local ++fail_count
}

**# 5. FG-C03: delayed-entry parity with stcrreg
* Bit-parity with stcrreg under delayed entry. NOTE: this asserts agreement
* with stcrreg, NOT correctness against the Zhang-Zhang-Fine target -- both
* estimators carry a demonstrated >10-MC-SE bias under left truncation. See
* the left-truncation section of finegray.sthlp; Phase 9 of the remediation
* plan owns that decision.
local ++test_count
capture noisily {
    _finegray_qa_entry_data, eps(0)
    quietly stset t, failure(etype == 1) id(id) time0(t0)
    quietly stcrreg x, compete(etype == 2) nolog ///
        tolerance(1e-11) ltolerance(1e-13) nrtolerance(1e-11)
    local b_stcrreg = _b[x]

    quietly stset t, failure(etype) id(id) time0(t0)
    quietly finegray x, compete(etype) cause(1) norobust nolog

    display as text "  finegray=" %16.12f _b[x] "  stcrreg=" %16.12f `b_stcrreg'
    assert reldif(_b[x], `b_stcrreg') < `tol_parity'
}
if _rc == 0 {
    display as result "  PASS: FG-C03 delayed-entry parity with stcrreg"
    local ++pass_count
}
else {
    display as error "  FAIL: FG-C03 delayed-entry parity with stcrreg (rc=`=_rc')"
    local ++fail_count
}

**# 6. Regression: the tie-free fixture must NOT move
* hypoxia has no censoring ties and no delayed entry, so neither Phase 1 fix may
* touch it. This is the guard against "fixed the tied case, broke everything
* else" -- it pins the numbers the package has always produced here.
local ++test_count
capture noisily {
    webuse hypoxia, clear
    gen long id = _n
    quietly stset dftime, failure(failtype == 1) id(id)
    quietly stcrreg ifp tumsize pelnode, compete(failtype == 2) nolog ///
        tolerance(1e-11) ltolerance(1e-13) nrtolerance(1e-11)
    matrix b_sc = e(b)

    quietly stset dftime, failure(failtype) id(id)
    quietly finegray ifp tumsize pelnode, compete(failtype) cause(1) norobust nolog
    matrix b_fg = e(b)

    forvalues k = 1/3 {
        display as text "  coef `k': reldif = " %10.2e reldif(b_fg[1,`k'], b_sc[1,`k'])
        assert reldif(b_fg[1,`k'], b_sc[1,`k']) < `tol_parity'
    }
}
if _rc == 0 {
    display as result "  PASS: tie-free hypoxia still matches stcrreg (no regression)"
    local ++pass_count
}
else {
    display as error "  FAIL: tie-free hypoxia regression (rc=`=_rc')"
    local ++fail_count
}

**# Summary
display as text _newline ///
    "RESULT: test_finegray_ties tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    log close _ties
    exit 1
}
display as result "ALL TESTS PASSED"
log close _ties
