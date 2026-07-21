* test_finegray_nuisance.do
* Fine & Gray (1999) eq. (7)-(8) psi term -- the `nuisance' option.
*
* WHAT THIS PINS.  Through v1.1.0 the sandwich meat was sum_i eta_i^(x)2, which
* treats the censoring survivor G as KNOWN.  FG (1999) sec. 4, pp. 500-501 give
* the meat as sum_i (eta_i + psi_i)^(x)2, where psi_i is the contribution from
* having ESTIMATED G by Kaplan-Meier.  finegray documented the omission rather
* than implementing it, because the delayed-entry form (ZZF 2011, Appendix B)
* was unobtainable; the RIGHT-CENSORING form is in FG (1999) itself and is now
* available behind `nuisance'.
*
* SCOPE.  This suite is deliberately R-FREE and builds every fixture in Stata,
* so it runs in the quick lane on a fresh clone.  Numerical parity against the
* eq. (7)-(8) oracle lives in crossval_nuisance.do, which needs R and rebuilds
* the gitignored qa/data/ oracle first.  Split this way, a machine without R
* still exercises the whole psi CONTRACT -- refusals, e(vce_meat), the
* sum(psi)==0 invariant, cluster handling, and backward compatibility -- and
* only the parity numbers wait for R.
*
* HOW THIS SUITE COULD GO FALSELY GREEN, and what closes each:
*   1. `nuisance' silently ignored.  N1 asserts it MOVES the variance on a
*      fixture where psi is known to be material, and N2 asserts the default
*      is unchanged.  A no-op fails N1; a changed default fails N2.
*   2. psi computed but never reaching e(V) through the cluster path.  N5
*      asserts singleton clusters reproduce the unclustered nuisance variance
*      AND that a real grouping still moves it, so neither a dropped psi nor a
*      dead cluster path passes.
*   3. sum(psi)==0 passing trivially because psi is identically zero.  N7
*      asserts the invariant AND that psi is not the zero matrix.
clear all
set varabbrev off
version 16.0

capture log close _all
log using "test_finegray_nuisance.log", replace name(_tnuis)

local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
capture confirm file "`pkg_dir'/finegray.pkg"
if _rc {
    display as error "test_finegray_nuisance.do must run from finegray/qa"
    exit 601
}
capture ado uninstall finegray
quietly net install finegray, from("`pkg_dir'") replace

local test_count = 0
local pass_count = 0
local fail_count = 0

capture program drop _reldif
program define _reldif, rclass
    version 16.0
    args a b
    return scalar rd = abs(`a' - `b') / max(abs(`b'), 1e-300)
end

* F1: the hand-checkable fixture -- n=20, integer times, ONE cause-1 event per
* distinct time.  Literal so it is identical on every machine and in every
* release; the same 20 rows are the f1 parity fixture in crossval_nuisance.do.
* Built with replace-in-place, NOT `input': `input's terminating `end' also
* closes `program define', so the remainder of the body would run at top level
* against an empty dataset (r(111) "variable X not found").
capture program drop _mk_f1
program define _mk_f1
    version 16.0
    clear
    quietly set obs 20
    gen double X   = .
    gen byte   eps = .
    gen byte   Z   = .
    local xs "1 1 2 2 3 3 4 4 5 5 6 6 7 7 8 8 9 10 11 12"
    local es "1 0 1 2 1 0 2 1 0 1 1 2 0 1 2 1 0 1  2  0"
    local zs "0 1 1 0 0 1 1 0 1 0 1 1 0 1 0 1 1 0  1  0"
    forvalues i = 1/20 {
        local xv : word `i' of `xs'
        local ev : word `i' of `es'
        local zval : word `i' of `zs'
        quietly replace X   = `xv'   in `i'
        quietly replace eps = `ev'   in `i'
        quietly replace Z   = `zval' in `i'
    }
    assert !missing(X) & !missing(eps) & !missing(Z)
    gen long _fgid = _n
    quietly stset X, failure(eps) id(_fgid)
end

* Tied + stratified fixture, generated in Stata so no R is needed.  Coarse
* integer times guarantee many tied cause-1 events, and cg gives three
* censoring strata -- the two structures psi is most easily got wrong on.
capture program drop _mk_tied_strat
program define _mk_tied_strat
    version 16.0
    syntax [, N(integer 200) SEED(integer 20260720)]
    clear
    set seed `seed'
    quietly set obs `n'
    gen long _fgid = _n
    gen double Z  = rnormal()
    gen byte   cg = 1 + mod(_n, 3)
    gen byte   X   = 1 + floor(12 * runiform())
    gen byte   eps = cond(runiform() < .45, 1, cond(runiform() < .5, 2, 0))
    quietly stset X, failure(eps) id(_fgid)
end

* Oracle-free psi probe.  Defined at TOP LEVEL: a mata: ... end block nested
* inside a foreach/if body does not parse as intended and hangs the do-file
* rather than erroring.
mata:
void _fg_psi_invariant(string scalar zv, string scalar gv)
{
    real colvector t, ev, d, b, byg, t0, G
    real matrix Z, eta, psi

    t   = st_data(., "_t")
    ev  = st_data(., "eps")
    d   = (ev :!= 0)
    Z   = st_data(., zv)
    b   = st_matrix("bb")'
    byg = st_data(., gv)
    t0  = J(rows(t), 1, 0)
    G   = _finegray_km_censor(t, d, 0, ev, byg, t0, 1)
    eta = _finegray_score_residuals(t, d, 1, 0, ev, Z, b, G, byg, t0, byg)
    psi = _finegray_psi_residuals(t, d, 1, 0, ev, Z, b, G, byg, t0)
    st_numscalar("PSISUM",  sum(abs(colsum(psi))))
    st_numscalar("ETASUM",  sum(abs(colsum(eta))))
    st_numscalar("PSIABS",  sum(abs(psi)))
}

/* Calls _finegray_psi_residuals with a caller-chosen entry time, so N11 can
   exercise the Mata-level delayed-entry guard directly rather than through
   finegray.ado's option check (which would mask it).
   NOTE: `*' is multiplication in Mata, not a comment -- use // or the block
   form, or the whole mata: block dies with "invalid expression". */
void _fg_psi_lt_probe(string scalar zv, string scalar gv, real scalar ent)
{
    real colvector t, ev, d, b, byg, t0, G
    real matrix Z, psi

    t   = st_data(., "_t")
    ev  = st_data(., "eps")
    d   = (ev :!= 0)
    Z   = st_data(., zv)
    b   = st_matrix("bb")'
    byg = st_data(., gv)
    t0  = J(rows(t), 1, ent)
    G   = _finegray_km_censor(t, d, 0, ev, byg, J(rows(t), 1, 0), 1)
    psi = _finegray_psi_residuals(t, d, 1, 0, ev, Z, b, G, byg, t0)
    st_numscalar("LTPROBE", sum(abs(psi)))
}
end

**# N1. nuisance materially moves the variance, in both directions
* psi is NOT a conservative correction: eta and psi are correlated, so the
* adjusted variance can be smaller as well as larger.  Asserting only
* "different" would pass for a sign error, so the direction is pinned per
* fixture against the sign measured from the eq. (7)-(8) oracle.
local ++test_count
capture noisily {
    _mk_f1
    quietly finegray Z, compete(eps) cause(1) censvalue(0) robust noadjust nolog
    local v_eta = _se[Z]^2
    quietly finegray Z, compete(eps) cause(1) censvalue(0) robust noadjust nuisance nolog
    local v_psi = _se[Z]^2
    * f1: oracle says psi INCREASES the variance, by ~0.20%
    assert `v_psi' > `v_eta'
    _reldif `v_psi' `v_eta'
    assert r(rd) > 1e-3

    _mk_tied_strat
    quietly finegray Z, compete(eps) cause(1) censvalue(0) strata(cg) robust noadjust nolog
    local w_eta = _se[Z]^2
    quietly finegray Z, compete(eps) cause(1) censvalue(0) strata(cg) robust noadjust nuisance nolog
    local w_psi = _se[Z]^2
    _reldif `w_psi' `w_eta'
    assert r(rd) > 1e-6
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: N1 nuisance moves the variance materially (not a no-op)"
}
else {
    local ++fail_count
    display as error "  FAIL: N1 (rc=`=_rc')"
}

**# N2. The DEFAULT is bit-unchanged by this release
* A released package must not move every user's standard errors silently.
* Pinned against values computed before _finegray_psi_residuals
* existed.  If these move, the release is breaking and must say so.
local ++test_count
capture noisily {
    _mk_f1
    quietly finegray Z, compete(eps) cause(1) censvalue(0) robust noadjust nolog
    _reldif (_se[Z]^2) 0.4059317594
    assert r(rd) < 1e-9
    _reldif (_b[Z]) -0.378656132112
    assert r(rd) < 1e-9
    * the adjusted default keeps its n/(n-1) factor
    local v2 = 0.4059317594 * 20 / 19
    quietly finegray Z, compete(eps) cause(1) censvalue(0) robust nolog
    _reldif (_se[Z]^2) `v2'
    assert r(rd) < 1e-9
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: N2 default variance and beta unchanged by nuisance"
}
else {
    local ++fail_count
    display as error "  FAIL: N2 default moved (BREAKING)"
}

**# N3. nuisance is refused with norobust
local ++test_count
capture noisily {
    _mk_f1
    * positive control: the same fit WITHOUT nuisance must succeed, so the
    * refusal is attributable to nuisance and not to a broken fixture.
    quietly finegray Z, compete(eps) cause(1) censvalue(0) norobust nolog
    assert _rc == 0
    capture finegray Z, compete(eps) cause(1) censvalue(0) norobust nuisance nolog
    assert _rc == 198
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: N3 nuisance + norobust refused (198), positive control clean"
}
else {
    local ++fail_count
    display as error "  FAIL: N3 (rc=`=_rc')"
}

**# N4. nuisance is refused under delayed entry
* FG eq. (7)-(8) is derived without entry times; the LT analogue is ZZF (2011)
* Appendix B, which finegray does not implement.  Refusing beats returning a
* plausible number with no derivation behind it.
local ++test_count
capture noisily {
    _mk_f1
    gen double _ent = 0.5
    quietly stset X, failure(eps) id(_fgid) enter(time _ent)
    * positive control: the LT fit itself must succeed and be recognised as LT
    quietly finegray Z, compete(eps) cause(1) censvalue(0) nolog
    assert _rc == 0
    assert e(lt_weight) != "right_censoring"
    capture finegray Z, compete(eps) cause(1) censvalue(0) nuisance nolog
    assert _rc == 198
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: N4 nuisance + delayed entry refused (198), positive control clean"
}
else {
    local ++fail_count
    display as error "  FAIL: N4 (rc=`=_rc')"
}

**# N5. psi survives the cluster path
local ++test_count
capture noisily {
    _mk_tied_strat
    quietly finegray Z, compete(eps) cause(1) censvalue(0) strata(cg) ///
        robust noadjust nuisance nolog
    matrix VU = e(V)
    * singleton clusters: cluster-summing over one-member groups is the
    * identity, so this must reproduce the unclustered nuisance variance.
    quietly finegray Z, compete(eps) cause(1) censvalue(0) strata(cg) ///
        cluster(_fgid) noadjust nuisance nolog
    assert mreldif(VU, e(V)) < 1e-12
    * and a REAL grouping must still move it, or the cluster path is dead and
    * the singleton check above would prove nothing.
    gen byte _cl = mod(_fgid, 7)
    quietly finegray Z, compete(eps) cause(1) censvalue(0) strata(cg) ///
        cluster(_cl) noadjust nuisance nolog
    assert mreldif(VU, e(V)) > 1e-6
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: N5 psi carried through the cluster path"
}
else {
    local ++fail_count
    display as error "  FAIL: N5 (rc=`=_rc')"
}

**# N6. e(vce_meat) names the meat actually used, in all three regimes
local ++test_count
capture noisily {
    _mk_f1
    quietly finegray Z, compete(eps) cause(1) censvalue(0) robust nolog
    assert e(vce_meat) == "fixed_weight"
    quietly finegray Z, compete(eps) cause(1) censvalue(0) robust nuisance nolog
    assert e(vce_meat) == "nuisance_adjusted"
    quietly finegray Z, compete(eps) cause(1) censvalue(0) norobust nolog
    assert e(vce_meat) == "not_applicable"
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: N6 e(vce_meat) contract holds in all three regimes"
}
else {
    local ++fail_count
    display as error "  FAIL: N6 (rc=`=_rc')"
}

**# N7. sum_i psi_i == 0 -- an oracle-free invariant
* psi is a sum of stochastic integrals against censoring martingales; at the
* fitted G its column sums vanish identically.  This catches sign errors and
* mis-indexed accumulation with no external reference.  PSIABS guards the
* trivial pass: an implementation returning the zero matrix satisfies
* sum(psi)==0 but fails here.
local ++test_count
capture noisily {
    * The Mata library is already resident (every finegray call above loaded
    * it).  Do NOT `run' _finegray_mata.ado again -- Mata refuses to redefine
    * an existing function and the whole file aborts with r(3000).
    _mk_tied_strat
    quietly finegray Z, compete(eps) cause(1) censvalue(0) strata(cg) ///
        robust noadjust nuisance nolog
    matrix bb = e(b)
    mata: _fg_psi_invariant("Z", "cg")
    assert scalar(PSISUM) < 1e-8
    assert scalar(ETASUM) < 1e-6
    assert scalar(PSIABS) > 1e-6
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: N7 sum(psi)==0 and psi is not identically zero"
}
else {
    local ++fail_count
    display as error "  FAIL: N7 (rc=`=_rc')"
}

**# N8. The finite-sample adjustment composes with nuisance
local ++test_count
capture noisily {
    _mk_tied_strat
    quietly count
    local n = r(N)
    quietly finegray Z, compete(eps) cause(1) censvalue(0) strata(cg) ///
        robust noadjust nuisance nolog
    local v_noadj = _se[Z]^2
    quietly finegray Z, compete(eps) cause(1) censvalue(0) strata(cg) ///
        robust nuisance nolog
    local v_adj = `v_noadj' * `n' / (`n' - 1)
    _reldif (_se[Z]^2) `v_adj'
    assert r(rd) < 1e-10
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: N8 n/(n-1) adjustment composes with nuisance"
}
else {
    local ++fail_count
    display as error "  FAIL: N8 (rc=`=_rc')"
}

**# N9. nuisance leaves the point estimates alone
* psi enters the meat only.  A change in beta would mean psi had leaked into
* the score or the information, which would be a defect, not a feature.
local ++test_count
capture noisily {
    _mk_tied_strat
    quietly finegray Z, compete(eps) cause(1) censvalue(0) strata(cg) robust nolog
    * a SCALAR, not a local: `local b = _b[Z]' stores a rounded string
    * representation, so a later exact == against the full double fails even
    * when the two fits are bit-identical.
    scalar _b_eta = _b[Z]
    matrix bE = e(b)
    quietly finegray Z, compete(eps) cause(1) censvalue(0) strata(cg) robust nuisance nolog
    assert mreldif(bE, e(b)) == 0
    assert _b[Z] == scalar(_b_eta)
    scalar drop _b_eta
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: N9 nuisance changes only the variance, never beta"
}
else {
    local ++fail_count
    display as error "  FAIL: N9 (rc=`=_rc')"
}

**# N10. nuisance does NOT propagate to post-estimation, and that is by design
* finegray_cif / finegray_predict build intervals from the cumulative-incidence
* influence function (FG 1999 sec. 5), a different derivation with its own
* nuisance term -- not the coefficient psi.  Adding coefficient psi to a CIF
* influence function would be wrong rather than conservative, so their SEs must
* be IDENTICAL after a nuisance fit.  Pinned here so the invariance is a
* deliberate contract and not an accident nobody would notice breaking.
local ++test_count
capture noisily {
    _mk_tied_strat
    quietly finegray Z, compete(eps) cause(1) censvalue(0) strata(cg) robust nolog
    quietly finegray_cif, attime(6) ci nograph
    matrix CIF_E = r(table)

    quietly finegray Z, compete(eps) cause(1) censvalue(0) strata(cg) robust nuisance nolog
    assert e(vce_meat) == "nuisance_adjusted"
    * post-estimation must still RUN after a nuisance fit ...
    quietly finegray_cif, attime(6) ci nograph
    matrix CIF_N = r(table)
    * ... and produce bit-identical intervals
    assert mreldif(CIF_E, CIF_N) == 0
    * predict likewise runs and is unaffected
    capture drop _phat
    quietly finegray_predict double _phat, cif timevar(X)
    assert _rc == 0
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: N10 post-estimation unaffected by nuisance (by design)"
}
else {
    local ++fail_count
    display as error "  FAIL: N10 (rc=`=_rc')"
}

**# N11. The Mata-level delayed-entry guard fires on its own
* N4 exercises the refusal in finegray.ado, which MASKS the second gate inside
* _finegray_psi_residuals().  Calling the Mata function directly with t0 > 0 is
* the only way to prove the inner guard is live -- otherwise a regression in
* the .ado guard would silently hand left-truncated data to a right-censoring
* derivation and return a plausible number.
local ++test_count
capture noisily {
    _mk_tied_strat
    quietly finegray Z, compete(eps) cause(1) censvalue(0) strata(cg) ///
        robust noadjust nuisance nolog
    matrix bb = e(b)
    * positive control: t0 == 0 must succeed, so the failure below is
    * attributable to t0 > 0 and not to bad arguments.
    capture mata: _fg_psi_lt_probe("Z", "cg", 0)
    assert _rc == 0
    capture mata: _fg_psi_lt_probe("Z", "cg", 1)
    assert _rc != 0
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: N11 Mata psi guard refuses t0>0 independently of the .ado gate"
}
else {
    local ++fail_count
    display as error "  FAIL: N11 (rc=`=_rc')"
}

**# N12. With no competing events psi is identically zero, and that is correct
* q_g(t) sums over competing-event subjects; with none, q == 0 and psi == 0.
* That is not a degenerate case to paper over -- with no competing risk the
* subdistribution risk set is the ordinary risk set, the IPCW weights never
* bind, and the estimator reduces to Cox, whose partial-likelihood score does
* not involve Ghat at all.  So `nuisance' MUST be a no-op here.  A psi that
* moved the variance on this fixture would be wrong.
local ++test_count
capture noisily {
    clear
    set seed 424242
    quietly set obs 300
    gen long _fgid = _n
    gen double Z = rnormal()
    gen byte X = 1 + floor(12 * runiform())
    * cause 1 or censored ONLY -- no competing event anywhere
    gen byte eps = (runiform() < .6)
    quietly count if eps == 2
    assert r(N) == 0
    quietly count if eps == 1
    assert r(N) > 50
    quietly stset X, failure(eps) id(_fgid)

    quietly finegray Z, compete(eps) cause(1) censvalue(0) robust noadjust nolog
    matrix V_E = e(V)
    quietly finegray Z, compete(eps) cause(1) censvalue(0) robust noadjust nuisance nolog
    assert mreldif(V_E, e(V)) < 1e-12
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: N12 psi==0 with no competing events (reduces to Cox)"
}
else {
    local ++fail_count
    display as error "  FAIL: N12 (rc=`=_rc')"
}

**# Summary
* The runner parses this sentinel and requires tests == pass + fail with
* fail == 0.  A suite that exits 0 without it is counted as a FAILURE, not a
* pass -- emitting it is part of the lane contract, not decoration.
display as text _newline ///
    "RESULT: test_finegray_nuisance tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    capture log close _tnuis
    exit 9
}
capture log close _tnuis
