clear all
version 16.0
set varabbrev off

* test_iivw_phase2_contract.do - estimator contract under the supported 2.x
* design (Phase 2, Gate 2)
*
* Usage:
*   cd iivw/qa
*   stata-mp -b do test_iivw_phase2_contract.do
*
* WHAT THIS SUITE IS FOR
* ----------------------
* Phase 1 made the weighting state transactional and exactly replayable. It
* changed no estimator. This suite covers the three estimator defects Phase 2
* fixes -- each of which returned rc=0 and a plausible-looking number:
*
*   B05  FIPTIW omitted treat() from the visit-intensity denominator, so the IIW
*        factor could not correct a visit process that depends on treatment. That
*        is not the FIPTIW of the source literature; it is IIW-without-treatment
*        multiplied by IPTW.
*   B04  A stabilized IIW numerator was never checked against the outcome design.
*        Stabilizing on a variable the outcome model never sees changes the
*        estimand, and a shipped recovery scenario did exactly that and counted
*        the result as a pass.
*   B06  iivw_balance built a STABILIZED observed weight and compared it to an
*        UNSTABILIZED target measure (dLambda0 instead of h(X)dLambda0), so every
*        balance number under stabcov() described two different populations.
*   B07  truncate() clipped the final product only. Under FIPTIW it could not say
*        which component was extreme, and iivw_balance went on describing the
*        untrimmed IIW while the outcome model used the trimmed one.
*
* THE ORACLE FOR B06: SATURATED STABILIZATION
* -------------------------------------------
* Set stabcov() equal to the FULL visit model. Then the numerator h(X) is
* exp(xb_full), the denominator is exp(xb_full), and the stabilized IIW is
* IDENTICALLY 1 -- not approximately, exactly, for every row. A weight vector of
* all ones reweights nothing, so the balance target must reproduce the observed
* visit distribution and every TSMD must be 0.
*
* This is a tier-1 oracle in the sense of TOLERANCE_FRAMEWORK.md: it is an
* algebraic identity of the estimator, hand-checkable, with no Monte Carlo error
* to hide a defect behind and no external implementation needed. It does not ask
* whether the weights are good; it asks whether the balance table can be trusted
* to say so.
*
* Measured on the pre-Phase-2 build: max |TSMD| = 0.3321411, for a weight vector
* that is identically 1. Shipped: 0.000000.
*
* WHICH OF THESE ARE EVIDENCE, AND WHICH ARE GUARDS
* -------------------------------------------------
* Run against the pre-Phase-2 build (git HEAD, 2026-07-14), this suite scores
* 4/15. The eleven that fail there are the evidence. The four that pass are not
* defect detectors and are not claimed to be:
*
*   T4  The replay identity draw passes on the old build too, because the old
*       build omitted treat() from the visit model on BOTH sides -- observed and
*       replayed. That is the known limit of an identity-draw oracle: it runs the
*       same iivw_weight on both sides, so a defect INSIDE iivw_weight cancels.
*       T4 is a regression guard on the new design, not proof of the fix. T1-T3
*       are what prove the fix.
*   T5  The saturated-stabilization WEIGHT identity was never broken -- only the
*       balance TARGET was. T5 is the precondition that makes T6 mean something:
*       it establishes the weight really is identically 1 before T6 asks whether
*       a weight of 1 balances.
*   T7  Must pass on both builds. It is the regression guard proving the B06 fix
*       left the unstabilized path bit-for-bit alone.
*   T14 Passes on both only because it now checks that the options EXIST before
*       checking that they are refused where inapplicable. Without that it
*       "passed" on the old build for the wrong reason -- an unrecognized option
*       is r(198) too. See the note in T14.

local qa_dir "`c(pwd)'"
local basename = substr("`qa_dir'", strrpos("`qa_dir'", "/") + 1, .)
if "`basename'" != "qa" {
    display as error "test_iivw_phase2_contract.do must be run from iivw/qa"
    exit 198
}
do "`qa_dir'/_iivw_qa_common.do"
iivw_qa_sandbox
local pkg_dir  "`r(pkg_dir)'"

capture ado uninstall iivw
quietly net install iivw, from("`pkg_dir'") replace

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

* Class E from TOLERANCE_FRAMEWORK.md: an algebraic identity holds to
* floating-point noise or it is not an identity.
local TOL_EXACT = 1e-12
* The saturated-stabilization TSMD is an identity in exact arithmetic, but it is
* computed through a Cox fit, a baseline-hazard step function and two ratios, so
* it accumulates ordinary double roundoff. 1e-6 is far below any balance
* threshold a user would act on (0.10) and far above the noise floor.
local TOL_TSMD = 1e-6

* Informative visiting driven by BOTH a covariate and treatment: the DGP the
* FIPTIW estimator exists for. Visits are thinned by x and by treat, so a visit
* model without treat() is misspecified in a way that has to show up.
capture program drop _p2_panel
program define _p2_panel
    version 16.0
    syntax [, N(integer 500) SEED(integer 31415)]

    clear
    set seed `seed'
    set obs `n'
    gen long id = _n
    gen double x = rnormal()
    gen double z = rnormal()
    gen byte treat = runiform() < invlogit(1.2*x)
    gen double fu_end = 75
    expand 14
    bysort id: gen int k = _n
    gen double time = k * 5
    bysort id (time): gen double u = runiform()
    * Visit intensity depends on x, z AND treatment.
    gen byte seen = (u < invlogit(-0.3 + 0.9*x + 0.6*z + 0.8*treat))
    bysort id (time): replace seen = 1 if _n == 1
    keep if seen
    bysort id (time): gen int nvis = _N
    drop if nvis < 2
    gen double y = 1 + 0.4*treat + 0.3*x + 0.2*z + rnormal()
end

**# T1 - FIPTIW puts treat() in the visit-intensity denominator by construction

local ++test_count
display as text "T1: FIPTIW visit model contains treat()"
capture noisily {
    _p2_panel
    quietly iivw_weight, id(id) time(time) visit_cov(x z) treat(treat) ///
        treat_cov(x) wtype(fiptiw) censor(fu_end) nolog

    * The design handed to stcox, not the raw option.
    local vc "`r(visit_covars)'"
    assert "`vc'" == "x z treat"
    assert r(treat_in_visit) == 1

    * And it is on the contract, so a replay can reproduce it.
    local ch : char _dta[_iivw_treat_in_visit]
    assert "`ch'" == "1"

    * The fit carries it forward into e(), so a saved estimation result records
    * that this FIPTIW analysis put treatment in the visit-intensity model.
    quietly iivw_fit y treat x, vce(fixed) timespec(linear) nolog
    assert "`e(iivw_treat_in_visit)'" == "1"
}
if _rc == 0 {
    display as result "  PASS: T1 - treat() is in the FIPTIW visit model"
    local ++pass_count
}
else {
    display as error "  FAIL: T1 - treat() in FIPTIW visit model (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T1"
}

**# T2 - a user who already supplied treat() in visit_cov() gets it once

local ++test_count
display as text "T2: treat() is deduplicated, not entered twice"
capture noisily {
    _p2_panel
    quietly iivw_weight, id(id) time(time) visit_cov(x z treat) treat(treat) ///
        treat_cov(x) wtype(fiptiw) censor(fu_end) nolog
    * A duplicate column would be collinear and stcox would drop it -- silently,
    * and with a different reported design than the one that was fitted.
    assert "`r(visit_covars)'" == "x z treat"
    assert r(treat_in_visit) == 1
}
if _rc == 0 {
    display as result "  PASS: T2 - treat() deduplicated in the visit design"
    local ++pass_count
}
else {
    display as error "  FAIL: T2 - treat() deduplication (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T2"
}

**# T3 - omitting treat() from the visit model is reachable only via the
**#      experimental opt-out, and the contract records that it was taken

local ++test_count
display as text "T3: experimentalnotreatvisit is the only way out, and is recorded"
capture noisily {
    _p2_panel
    quietly iivw_weight, id(id) time(time) visit_cov(x z) treat(treat) ///
        treat_cov(x) wtype(fiptiw) censor(fu_end) nolog experimentalnotreatvisit
    assert "`r(visit_covars)'" == "x z"
    assert r(treat_in_visit) == 0
    local ch : char _dta[_iivw_treat_in_visit]
    assert "`ch'" == "0"

    * The opt-out is FIPTIW-only: there is nothing to opt out of elsewhere, and
    * an option that silently does nothing is worse than an option that errors.
    capture iivw_weight, id(id) time(time) visit_cov(x z) censor(fu_end) ///
        wtype(iivw) replace nolog experimentalnotreatvisit
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: T3 - opt-out is explicit, recorded, and FIPTIW-only"
    local ++pass_count
}
else {
    display as error "  FAIL: T3 - experimentalnotreatvisit contract (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T3"
}

**# T4 - the treat-in-visit contract survives the refit bootstrap replay
**#      (an identity draw: every subject drawn once, so the draw IS the panel)

local ++test_count
display as text "T4: refitweights replays the FIPTIW visit design exactly"
capture noisily {
    _p2_panel, n(150)
    quietly iivw_weight, id(id) time(time) visit_cov(x z) treat(treat) ///
        treat_cov(x) wtype(fiptiw) censor(fu_end) nolog
    quietly gen double w_obs = _iivw_weight

    * An identity draw: hand _iivw_bs_refit a resample in which every subject
    * appears exactly once. The recomputed weights must equal the observed ones.
    * If the replay rebuilt the visit model WITHOUT treat() while the observed
    * pass built it WITH treat(), the two disagree and this catches it.
    quietly gen long bsid = id
    quietly _iivw_bs_refit y treat x, newid(bsid) panelid(id) timevar(time) ///
        wtype(fiptiw) prefix(_iivw_) model(gee) ///
        visitcov(x z) treat(treat) treatcov(x) ///
        baseline(entry) censor(fu_end) family(gaussian) link(identity) nolog

    quietly gen double reld = abs(_iivw_weight - w_obs) / max(abs(w_obs), 1e-30)
    quietly summarize reld, meanonly
    local maxreld = r(max)
    display as text "    max reldif observed vs identity draw = " %8.2e `maxreld'
    assert `maxreld' < `TOL_EXACT'
}
if _rc == 0 {
    display as result "  PASS: T4 - FIPTIW visit design replays exactly"
    local ++pass_count
}
else {
    display as error "  FAIL: T4 - FIPTIW replay identity draw (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T4"
}

**# T5 - SATURATED STABILIZATION: the weight is identically 1

local ++test_count
display as text "T5: stabcov() == the full visit model gives weight identically 1"
capture noisily {
    _p2_panel
    quietly iivw_weight, id(id) time(time) visit_cov(x z) stabcov(x z) ///
        censor(fu_end) nolog

    * exp(xb_stab - xb_full) with the same covariates in both models is exp(0).
    * Not "close to 1" -- exactly 1, on every row, before the mean-1
    * normalization even has anything to do.
    quietly summarize _iivw_iw
    assert r(sd) < `TOL_EXACT'
    assert abs(r(min) - 1) < `TOL_EXACT'
    assert abs(r(max) - 1) < `TOL_EXACT'
}
if _rc == 0 {
    display as result "  PASS: T5 - saturated stabilization gives weight == 1"
    local ++pass_count
}
else {
    display as error "  FAIL: T5 - saturated stabilization weight (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T5"
}

**# T6 - ...and a weight of 1 must balance PERFECTLY. This is the B06 oracle.

local ++test_count
display as text "T6: a weight identically 1 has zero TSMD (the B06 oracle)"
capture noisily {
    _p2_panel
    quietly iivw_weight, id(id) time(time) visit_cov(x z) stabcov(x z) ///
        censor(fu_end) nolog
    quietly iivw_balance

    local mt = r(balance_max_tsmd)
    display as text "    max |TSMD| under saturated stabilization = " %10.7f `mt'

    * The stabilized target is h(X) dLambda0 = exp(xb_full) dLambda0, which is
    * the fitted visit intensity itself. Reweighting the observed visits by a
    * CONSTANT must reproduce the at-risk average under that intensity -- which
    * is the observed visit average. So every TSMD is 0 by algebra.
    *
    * The pre-Phase-2 build weighted the target by dLambda0 alone and reported
    * max |TSMD| = 0.3321411 here: a 0.33 "imbalance" for a weight vector that
    * does not reweight anything. It was not a balance defect. It was the wrong
    * target, and it made a correctly stabilized IIW look broken.
    assert `mt' < `TOL_TSMD'
}
if _rc == 0 {
    display as result "  PASS: T6 - saturated stabilization balances exactly"
    local ++pass_count
}
else {
    display as error "  FAIL: T6 - saturated-stabilization balance oracle (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T6"
}

**# T7 - the fix does not touch the UNSTABILIZED path

local ++test_count
display as text "T7: the unstabilized target is unchanged (regression guard)"
capture noisily {
    * Without stabcov(), h(X) == 1 and h(X)dLambda0 IS dLambda0. The new target
    * must therefore reduce to the old one EXACTLY -- if it does not, the fix
    * changed a path it had no business changing, and every unstabilized balance
    * number the package has ever reported just moved.
    _p2_panel
    quietly iivw_weight, id(id) time(time) visit_cov(x z) censor(fu_end) nolog
    quietly iivw_balance
    local mt_unstab = r(balance_max_tsmd)
    display as text "    unstabilized max |TSMD| = " %10.7f `mt_unstab'

    * MEASURED on the pre-Phase-2 build (git HEAD, 2026-07-14) with this exact
    * DGP and seed, and it agrees to every printed digit with the shipped build.
    * A literal, not a recomputation: an "expected" value recomputed by the code
    * under test moves with the code and can never detect that the code moved.
    assert reldif(`mt_unstab', .04872) < 1e-4
}
if _rc == 0 {
    display as result "  PASS: T7 - unstabilized balance target is unchanged"
    local ++pass_count
}
else {
    display as error "  FAIL: T7 - unstabilized balance regression (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T7"
}

**# T8 - stabilizing on a variable the outcome model never sees is REFUSED

local ++test_count
display as text "T8: invalid stabilization errors before the outcome is fitted"
capture noisily {
    _p2_panel
    quietly iivw_weight, id(id) time(time) visit_cov(x z) stabcov(z) ///
        censor(fu_end) nolog

    * z is in the stabilization numerator but NOT in this outcome model. The
    * weighted estimating equation then solves for an h(X)-weighted average of
    * subject-specific effects, not for the beta the table prints. Before Phase 2
    * this ran to completion and printed a coefficient.
    capture iivw_fit y treat x, vce(fixed) timespec(linear) nolog replace
    local rc_bad = _rc
    assert `rc_bad' == 198

    * Add z to the outcome model and the SAME weights become valid.
    capture iivw_fit y treat x z, vce(fixed) timespec(linear) nolog replace
    assert _rc == 0
    assert e(iivw_stabilization_validated) == 1
    assert "`e(iivw_stab_terms)'" == "z"
}
if _rc == 0 {
    display as result "  PASS: T8 - invalid stabilization refused, valid accepted"
    local ++pass_count
}
else {
    display as error "  FAIL: T8 - stabilization validation (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T8"
}

**# T9 - unstabilized weights are always valid and are marked as unvalidated

local ++test_count
display as text "T9: unstabilized IIW needs no stabilization check"
capture noisily {
    _p2_panel
    quietly iivw_weight, id(id) time(time) visit_cov(x z) censor(fu_end) nolog
    quietly iivw_fit y treat x, vce(fixed) timespec(linear) nolog replace
    * Nothing to validate: there is no numerator. The flag says "not applicable",
    * not "checked and passed" -- a consumer must be able to tell those apart.
    assert e(iivw_stabilization_validated) == 0
    assert "`e(iivw_stab_terms)'" == ""
}
if _rc == 0 {
    display as result "  PASS: T9 - unstabilized fit needs no numerator check"
    local ++pass_count
}
else {
    display as error "  FAIL: T9 - unstabilized stabilization flag (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T9"
}

**# T10 - the ambiguous truncate() is gone, and says what to use instead

local ++test_count
display as text "T10: truncate() is refused"
capture noisily {
    _p2_panel
    capture iivw_weight, id(id) time(time) visit_cov(x z) censor(fu_end) ///
        truncate(1 99) nolog
    assert _rc == 198
    * And it must not have half-created a contract on the way out.
    local w : char _dta[_iivw_weighted]
    assert "`w'" == ""
}
if _rc == 0 {
    display as result "  PASS: T10 - truncate() refused, no partial contract"
    local ++pass_count
}
else {
    display as error "  FAIL: T10 - truncate() removal (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T10"
}

**# T11 - each component trims independently, keeps its raw column, and reports
**#       its own cutpoints

local ++test_count
display as text "T11: component trims are separate, bounded, and reported"
capture noisily {
    _p2_panel
    quietly iivw_weight, id(id) time(time) visit_cov(x z) treat(treat) ///
        treat_cov(x) wtype(fiptiw) censor(fu_end) ///
        truncvisit(5 95) trunctreat(5 95) nolog

    * Both components actually bit on this DGP -- a trim test on a DGP where
    * nothing is extreme proves nothing.
    assert r(n_trunc_visit) > 0
    assert r(n_trunc_treat) > 0

    * The command echoes back which components were trimmed and the raw-column
    * names it kept, so a caller (and the replay contract) can read the trim
    * specification from r() without re-parsing the command line.
    assert "`r(truncvisit)'" == "5 95"
    assert "`r(trunctreat)'" == "5 95"
    assert "`r(iw_raw_var)'" == "_iivw_iw_raw"
    assert "`r(tw_raw_var)'" == "_iivw_tw_raw"

    * A final-product trim echoes r(truncfinal) and reports no component raw
    * columns (it clips the product, not a component).
    quietly iivw_weight, id(id) time(time) visit_cov(x z) treat(treat) ///
        treat_cov(x) wtype(fiptiw) censor(fu_end) truncfinal(2 98) replace nolog
    assert "`r(truncfinal)'" == "2 98"

    _p2_panel
    quietly iivw_weight, id(id) time(time) visit_cov(x z) treat(treat) ///
        treat_cov(x) wtype(fiptiw) censor(fu_end) ///
        truncvisit(5 95) trunctreat(5 95) nolog

    * The ANALYSIS component is bounded by its own cutpoints, exactly.
    local vlo = r(trunc_visit_lo)
    local vhi = r(trunc_visit_hi)
    local tlo = r(trunc_treat_lo)
    local thi = r(trunc_treat_hi)
    quietly count if !missing(_iivw_iw) & ///
        (_iivw_iw < `vlo' - `TOL_EXACT' | _iivw_iw > `vhi' + `TOL_EXACT')
    assert r(N) == 0
    quietly count if !missing(_iivw_tw) & ///
        (_iivw_tw < `tlo' - `TOL_EXACT' | _iivw_tw > `thi' + `TOL_EXACT')
    assert r(N) == 0

    * The RAW component is kept and is genuinely wider -- otherwise "raw" is a
    * copy with a different name and the trim did nothing.
    confirm variable _iivw_iw_raw
    confirm variable _iivw_tw_raw
    quietly summarize _iivw_iw_raw
    assert r(min) < `vlo'
    assert r(max) > `vhi'

    * The final weight is the product of the ANALYSIS components, not the raw
    * ones. Trimming a component that never reaches the product is a no-op that
    * reports a count -- the worst kind of silent failure.
    quietly gen double prod_chk = _iivw_iw * _iivw_tw
    quietly count if abs(prod_chk - _iivw_weight) > `TOL_EXACT' & ///
        !missing(prod_chk, _iivw_weight)
    assert r(N) == 0
}
if _rc == 0 {
    display as result "  PASS: T11 - components trim separately and feed the product"
    local ++pass_count
}
else {
    display as error "  FAIL: T11 - component truncation (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T11"
}

**# T12 - a rerun without trims clears the raw columns (ownership round-trip)

local ++test_count
display as text "T12: an untrimmed rerun clears the previous run's raw columns"
capture noisily {
    _p2_panel
    quietly iivw_weight, id(id) time(time) visit_cov(x z) treat(treat) ///
        treat_cov(x) wtype(fiptiw) censor(fu_end) ///
        truncvisit(5 95) trunctreat(5 95) nolog
    confirm variable _iivw_iw_raw

    * Rerunning without the trims must not leave _iivw_iw_raw behind describing
    * a trim that no longer exists. The raw columns are owned unconditionally for
    * exactly this reason -- and they have to be STAMPED, or replace refuses to
    * touch them and the second call errors instead of cleaning up.
    quietly iivw_weight, id(id) time(time) visit_cov(x z) treat(treat) ///
        treat_cov(x) wtype(fiptiw) censor(fu_end) replace nolog
    capture confirm variable _iivw_iw_raw
    assert _rc == 111
    capture confirm variable _iivw_tw_raw
    assert _rc == 111
}
if _rc == 0 {
    display as result "  PASS: T12 - raw columns are cleared by an untrimmed rerun"
    local ++pass_count
}
else {
    display as error "  FAIL: T12 - raw column ownership round-trip (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T12"
}

**# T13 - iivw_balance describes the ANALYSIS weight, not the untrimmed one

local ++test_count
display as text "T13: balance reports on the trimmed weight the outcome model used"
capture noisily {
    _p2_panel
    quietly iivw_weight, id(id) time(time) visit_cov(x z) censor(fu_end) nolog
    quietly iivw_balance
    local tsmd_untrimmed = r(balance_max_tsmd)

    quietly iivw_weight, id(id) time(time) visit_cov(x z) censor(fu_end) ///
        truncvisit(5 95) replace nolog
    quietly iivw_balance
    local tsmd_trimmed = r(balance_max_tsmd)

    display as text "    max |TSMD| untrimmed = " %9.6f `tsmd_untrimmed'
    display as text "    max |TSMD| trimmed   = " %9.6f `tsmd_trimmed'

    * These must DIFFER. Before Phase 2 iivw_balance rebuilt exp(-xb) from the
    * refit and never applied the trim, so it returned the untrimmed number in
    * both cases -- it reported the balance of a weight vector the outcome model
    * never saw, and reported it as the analysis.
    assert reldif(`tsmd_trimmed', `tsmd_untrimmed') > 1e-3

    * And the honest direction: trimming the VISIT weight makes balance WORSE,
    * because bounding the weights bounds their ability to reweight. That is the
    * whole reason the help refuses to call it a remedy for misspecification.
    assert `tsmd_trimmed' > `tsmd_untrimmed'
}
if _rc == 0 {
    display as result "  PASS: T13 - balance follows the analysis weight"
    local ++pass_count
}
else {
    display as error "  FAIL: T13 - balance describes analysis weight (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T13"
}

**# T14 - a component trim is refused for a weight type that has no such component

local ++test_count
display as text "T14: component trims are refused where the component does not exist"
capture noisily {
    _p2_panel

    * FIRST establish that the options EXIST and work in their proper place.
    *
    * Without this, the two error checks below pass on ANY build that lacks the
    * options entirely -- an unrecognized option is also r(198), so "refused
    * because inapplicable" and "refused because it does not exist" are the same
    * return code. This test passed against the pre-Phase-2 build for exactly
    * that reason, which makes it a false green: it asserted a behaviour the old
    * code could not possibly have had, and the assertion held anyway.
    quietly iivw_weight, id(id) time(time) visit_cov(x z) censor(fu_end) ///
        wtype(iivw) nolog truncvisit(5 95)
    assert r(n_trunc_visit) < .
    quietly iivw_weight, id(id) time(time) treat(treat) treat_cov(x) ///
        wtype(iptw) replace nolog trunctreat(5 95)
    assert r(n_trunc_treat) < .

    * NOW the refusals mean what they say.
    * IPTW has no visit-intensity component.
    capture iivw_weight, id(id) time(time) treat(treat) treat_cov(x) ///
        wtype(iptw) replace nolog truncvisit(5 95)
    assert _rc == 198
    * IIW has no treatment component.
    capture iivw_weight, id(id) time(time) visit_cov(x z) censor(fu_end) ///
        wtype(iivw) replace nolog trunctreat(5 95)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: T14 - component trims refused where inapplicable"
    local ++pass_count
}
else {
    display as error "  FAIL: T14 - component trim applicability (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T14"
}

**# T15 - the trimming spec is on the contract and reaches the replay

local ++test_count
display as text "T15: the trim spec is replayed by percentile, per draw"
capture noisily {
    _p2_panel, n(150)
    quietly iivw_weight, id(id) time(time) visit_cov(x z) censor(fu_end) ///
        truncvisit(5 95) nolog
    local tv : char _dta[_iivw_truncvisit]
    assert "`tv'" == "5 95"
    local lc : char _dta[_iivw_tv_locut]
    assert "`lc'" != ""

    quietly gen double w_obs = _iivw_weight
    quietly gen long bsid = id
    quietly _iivw_bs_refit y treat x, newid(bsid) panelid(id) timevar(time) ///
        wtype(iivw) prefix(_iivw_) model(gee) ///
        visitcov(x z) truncvisit(5 95) ///
        baseline(entry) censor(fu_end) family(gaussian) link(identity) nolog

    * The identity draw is the observed panel, so its 5th/95th percentiles ARE
    * the observed cutpoints and the trimmed weights must come back identical.
    * (A draw that is NOT the identity has different percentiles -- which is the
    * point: the estimator is "fit, then clip at the pth percentile of THIS
    * sample", so freezing the observed cutpoint into every replicate would
    * remove a real source of variation from the bootstrap.)
    quietly gen double reld = abs(_iivw_weight - w_obs) / max(abs(w_obs), 1e-30)
    quietly summarize reld, meanonly
    display as text "    max reldif trimmed observed vs identity draw = " %8.2e r(max)
    assert r(max) < `TOL_EXACT'
}
if _rc == 0 {
    display as result "  PASS: T15 - trim spec replays exactly on an identity draw"
    local ++pass_count
}
else {
    display as error "  FAIL: T15 - trim spec replay (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T15"
}

**# Summary

display as result "iivw Phase-2 contract results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "FAILED TESTS:`failed_tests'"
    display "RESULT: test_iivw_phase2_contract tests=`test_count' pass=`pass_count' fail=`fail_count'"
    exit 1
}

display as result "ALL IIVW PHASE-2 CONTRACT TESTS PASSED"
display "RESULT: test_iivw_phase2_contract tests=`test_count' pass=`pass_count' fail=`fail_count'"
