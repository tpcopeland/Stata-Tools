* validation_finegray_zzf_factorization.do
* ===========================================================================
* SENSITIVITY ANALYSIS: what does the factorized weight cost when its own
* assumption is violated, and why is it the shipped default anyway?
*
* finegray's delayed-entry weight is the stabilized Zhang-Zhang-Fine Weight 1,
* computed in Geskus's product form
*
*     A(t-) = G(t-) * H(t-)            Geskus (2011) eq. (11)
*
* with G the reverse-time censoring survivor (estimated within strata()) and H
* the entry distribution (estimated within truncstrata()).  When the two
* groupings differ, finegray estimates G within strata(), estimates H within
* truncstrata(), and MULTIPLIES their cells -- the "factorized cross-
* classification" the README and finegray.sthlp document as a package extension.
*
* THE ASSUMPTION THAT PRODUCT BUYS, verbatim from ZZF (2011) sec. 3.2, the
* paragraph after eq. (6): the nonparametric weight is valid only when
*
*     P(L <= t <= C | L <= X, Z) = P(L <= t <= C | L <= X),
*
* i.e. the truncation-censoring probability does not depend on the covariate,
* and -- for the PRODUCT form specifically -- the joint factors:
*
*     P(L <= t <= C | cell) = P(L <= t | cell) * P(C >= t | cell) = H * G.
*
* That second step is an INDEPENDENCE assumption: within a weight cell, the
* entry mechanism L and the censoring mechanism C must be conditionally
* independent.  ZZF sec. 5 (the BMT example) is the paper's own negative
* control for the FIRST half ("the truncation time is associated with the
* covariate ... the nonparametric weight is not appropriate").  This file is
* the negative control for the SECOND half: a shared driver of BOTH L and C
* that no single grouping can absorb -- "a dependence that does not split
* across the two groupings."
*
* ---------------------------------------------------------------------------
* WHAT REVIEWERS ASK FOR, AND WHY THIS ANSWERS IT
*
* A referee who sees a factorized G*H weight will ask: what happens when the
* factorization is false?  Two things could be true and only a simulation
* separates them:
*   (i)  the product form is fragile and the bias is large, or
*   (ii) the product form is a deliberate bias-variance/positivity trade whose
*        cost is bounded and whose benefit (feasibility) is real.
* This file measures both the bias (Part 1) and the price the "fully-joint"
* alternative pays to avoid it (Part 2), so the choice is documented, not
* asserted.  The motivation for the trade is the package's own Z23 finding:
* the fully-joint stratified denominators are exactly what go to zero under
* refinement (see qa/README.md "The hard positivity failure (Z23)").
*
* ===========================================================================
* PART 1 -- BIAS UNDER A FACTORIZATION VIOLATION
*
* DGP.  ZZF sec. 4.1 cause-1 subdistribution, true log-SHR b = (0.5, -0.5)
* EXACTLY (identical event process to validation_finegray_zzf_recovery.do and
* crossval_finegray_zzf_r.R -- the truth is not re-derived here):
*
*     F1(t | x) = 1 - { 1 - 0.5 (1 - e^-t) } ^ exp(0.5 x1 - 0.5 x2).
*
* Superimposed on it, a SHARED observation-process factor W (think "enrolment
* wave" or "site"):
*   * W has K ordered levels; its level RISES with x1, so W is correlated with
*     the covariate of interest (this is what turns a nuisance-weight error
*     into a COEFFICIENT bias -- ZZF sec. 5's mechanism).
*   * the censoring hazard rises with W   (G depends on W),
*   * the entry time rises with W         (H depends on W),
*   * C and L are drawn INDEPENDENTLY given W.
* So marginally, C and L are positively associated (both driven by W) and both
* associated with x1.  Conditionally on W they are independent -- which is the
* whole point: the dependence is removable, but only by conditioning on W in
* BOTH factors at once.
*
* The event times are independent of (L, C, W) given (x1, x2), so ZZF's
* identifying assumption T |= (L,C) | Z holds and the TRUE subdistribution SHR
* is unchanged by W.  Any deviation of b-hat from (0.5, -0.5) is therefore the
* WEIGHT, not the estimand.
*
* FOUR WEIGHT SPECIFICATIONS, all fitting the SAME (correct) mean model x1 x2,
* cause 1, on the SAME depend-on dataset each replication (paired):
*
*   JOINT     strata(W) truncstrata(W)   condition W in BOTH factors.
*                                        Matching groups => ZZF eq. (7) same-
*                                        group form.  A = G_W * H_W is the
*                                        correct conditional weight.  RECOVER.
*   MARGINAL  (no strata)                condition W in NEITHER.  A = G-bar *
*                                        H-bar ignores W entirely.  BIASED.
*   SPLIT_G   strata(W)                  condition W in G only; H pooled over W.
*                                        The dependence is in one grouping but
*                                        not the other.  BIASED.
*   SPLIT_H   truncstrata(W)             condition W in H only; G pooled over W.
*                                        BIASED.
*
* SPLIT_G and SPLIT_H are the literal content of "a dependence that does not
* split across the two groupings": putting W in one grouping alone does not
* fix it (and, as it happens, biases in OPPOSITE directions -- reported below,
* not preregistered as a signed claim).  Only JOINT, which conditions both
* factors on W simultaneously, recovers.
*
* A FIFTH ARM IS THE CONTROL:
*   NULL      MARGINAL fit on a depend-OFF dataset (W generated identically and
*             still correlated with x1, but NOT driving C or L; entry
*             homogeneous).  MARGINAL must RECOVER here.  This proves the bias
*             in the other arms is the C-L dependence, not the mere existence
*             of W or of delayed entry, and not a coding artifact -- the same
*             estimator that is biased with the dependence is clean without it.
*
* ---------------------------------------------------------------------------
* [FAC-PREREG]  Written before the gated replications were run.  These are the
* theory claims (ZZF sec. 3.2 and sec. 3.4), not this Monte Carlo's output:
*
*   1. JOINT recovers b1 AND b2 within +/- PASS_Z MC SE.  Conditioning the
*      common cause W in both factors restores the product identity within
*      each W-cell (C |= L | W by construction).
*   2. MARGINAL, SPLIT_G and SPLIT_H are each biased on b1 beyond NEG_Z MC SE.
*      A weight whose factorization is false is an inconsistent weight, and an
*      inconsistent weight biases the weighted estimating equation.
*   3. NULL (MARGINAL with the dependence switched off) recovers.  Necessary to
*      attribute (2) to the dependence rather than to the estimator or the DGP.
*
* The SIGNS of the SPLIT arms are RECORDED as a measured result, not
* preregistered: a directional claim I cannot derive from a source I have read
* is not gated (the same discipline validation_finegray_zzf_recovery.do applies
* to arm D).  The gate asserts magnitude (biased / recovered); the opposite-
* sign signature is displayed and asserted only as "the two SPLIT arms disagree
* in sign," which is the model-free statement of the factorization failure.
*
* ===========================================================================
* PART 2 -- THE FULLY-JOINT ALTERNATIVE IS A POSITIVITY/VARIANCE CHOICE
*
* Part 1 shows JOINT is the unbiased option here.  Part 2 shows why it is not
* the DEFAULT.  The fully-joint (matching-groups eq. 7) weight consults a
* stratum-specific denominator A_W(X_i-) in every observed joint cell, and that
* is precisely the quantity Z23 shows goes to zero under refinement.  So the
* choice between the factorized product and the fully-joint stratification is a
* bias-variance/POSITIVITY trade:
*
*   * VARIANCE: with the dependence coarse (few W-levels), JOINT is unbiased but
*     more variable than MARGINAL -- it estimates a separate denominator per
*     cell instead of pooling.  Reported as mean analytic SE and empirical SD.
*   * POSITIVITY: as W is refined, each cell's entry distribution H_W is
*     estimated from fewer subjects, so a consulted A_W(X_i-) hits exactly zero
*     -- the Z23 hard failure r(459).  The MARGINAL product weight, pooling
*     across W, stays feasible (biased, but it fits).  The fully-joint weight
*     simply stops existing.
*
* That is the trade the shipped factorized default makes on purpose: accept a
* bounded bias when L and C share an unsplit dependence, in exchange for a
* weight that stays defined as strata refine.  Z23 is the reason the trade is
* not free.
*
* ---------------------------------------------------------------------------
* COST.  Part 1 is ~REPS x N x 5 fits; Part 2 adds a small variance loop and a
* deterministic positivity ladder.  FULL gate: N=100000, REPS=100 (hours).
* Smoke:  global ZZF_FAC_N 8000 ; global ZZF_FAC_REPS 25   (NOT a gate).
* ===========================================================================

clear all
set varabbrev off
version 16.0

capture log close _all
log using "validation_finegray_zzf_factorization.log", replace name(_zzffac)

local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
capture confirm file "`pkg_dir'/finegray.pkg"
if _rc {
    display as error "run this from the finegray/qa directory"
    exit 601
}
capture ado uninstall finegray
quietly net install finegray, from("`pkg_dir'") replace

* --- gate parameters -------------------------------------------------------
local N     = 100000
local REPS  = 100
if "$ZZF_FAC_N"    != "" local N    = $ZZF_FAC_N
if "$ZZF_FAC_REPS" != "" local REPS = $ZZF_FAC_REPS
local SEED0 = 20260715
local FULL  = (`N' >= 100000 & `REPS' >= 100)

local TRUTH1 =  0.5
local TRUTH2 = -0.5
local PASS_Z = 3
local NEG_Z  = 5

* Part 2 knobs (independent of Part 1 REPS so the trade is measured at a fixed
* cost).  VREPS drives the variance comparison; the positivity ladder is a
* single deterministic dataset per K.
local VREPS = 60
if `REPS' < `VREPS' local VREPS = `REPS'

display as text _newline "ZZF factorization sensitivity analysis"
display as text "  N = `N' retained/rep, REPS = `REPS', base seed = `SEED0'"
display as text "  truth: b1 = `TRUTH1' (on x1, binary; also drives W), b2 = `TRUTH2' (on x2)"
if !`FULL' {
    display as error "  SMOKE SETTINGS (N < 100000 or REPS < 100): this run is NOT a gate."
}

* ---------------------------------------------------------------------------
* DGP.  depend(on) drives C and L through the shared K-level factor W;
* depend(off) leaves C and L homogeneous (W still generated and correlated with
* x1, but inert) for the NULL control.  Oversamples to absorb the truncation and
* keeps exactly n survivors so every arm is compared at one sample size.
* ---------------------------------------------------------------------------
capture program drop _zzffac_gen
program define _zzffac_gen, rclass
    syntax , n(integer) seed(integer) depend(string) ///
        [klevels(integer 2) entrymul(real 1.0) over(integer 10) ///
         cwslope(real 1.5) lwslope(real 1.3)]

    if !inlist("`depend'", "on", "off") {
        display as error "depend() must be on or off"
        exit 198
    }
    if `klevels' < 2 {
        display as error "klevels() must be >= 2"
        exit 198
    }

    clear
    set seed `seed'
    quietly set obs `=`n' * `over''

    * --- event process: ZZF sec. 4.1, true b = (0.5, -0.5). Independent of W.
    gen byte   x1 = runiform() < 0.5
    gen double x2 = rnormal()
    gen double ez = exp(0.5 * x1 - 0.5 * x2)
    gen double p1 = 1 - (1 - 0.5)^ez
    gen byte   cause = cond(runiform() < p1, 1, 2)
    gen double v     = runiform()
    gen double tev = -ln(1 - (1 - (1 - v * p1)^(1 / ez)) / 0.5) if cause == 1
    replace    tev = rexponential(1 / (0.5 * exp(0.5 * x1 + 0.5 * x2))) if cause == 2

    * --- shared factor W: K ordered levels, level rises with x1 (=> W and the
    * covariate of interest are correlated: corr(x1,W) ~ 0.5 at K=2). wfac in
    * [0,1] is monotone in W.
    gen double s = 1.4 * x1 + rnormal()
    gen byte W = 0
    forvalues j = 1/`=`klevels'-1' {
        quietly replace W = W + (s > invnormal(`j' / `klevels'))
    }
    gen double wfac = W / `=`klevels'-1'

    * --- observation process.  depend(on): BOTH the censoring hazard and the
    * entry time rise with W, drawn independently given W.  depend(off): both
    * homogeneous (the product identity then holds and MARGINAL is unbiased).
    if "`depend'" == "on" {
        gen double cens = min(rexponential(1 / (0.15 * exp(`cwslope' * wfac))), 6)
        gen double t0   = rexponential(`entrymul' * 0.9 * exp(`lwslope' * wfac))
    }
    else {
        gen double cens = min(rexponential(1 / 0.15), 6)
        gen double t0   = rexponential(`entrymul' * 0.9)
    }

    gen double t      = min(tev, cens)
    gen byte   status = cond(tev <= cens, cause, 0)
    gen byte   anyev  = status > 0

    quietly count
    local pre = r(N)
    quietly drop if !(t0 < t)
    quietly count
    return scalar truncfrac = 1 - r(N) / `pre'
    if r(N) < `n' {
        display as error "oversample exhausted: only `r(N)' of `n' survived truncation"
        display as error "raise over() for this klevels()/entrymul()"
        exit 498
    }
    quietly keep in 1/`n'
    gen long id = _n
    quietly corr x1 W
    return scalar corr_x1W = r(rho)
end

* ---------------------------------------------------------------------------
* CAPABILITY PROBE.  This suite is GREEN-only: it requires strata() and
* truncstrata() to fit a matching-groups JOINT model.  Probe rather than assume
* so a stale install cannot silently degrade the gate to a subset.
* ---------------------------------------------------------------------------
_zzffac_gen, n(2000) seed(`SEED0') depend(on) klevels(2)
quietly stset t, failure(anyev == 1) id(id) enter(time t0)
capture noisily finegray x1 x2, compete(status) cause(1) strata(W) truncstrata(W)
if _rc {
    display as error "JOINT fit (strata()+truncstrata()) unavailable: rc = `=_rc'"
    display as error "this suite requires the ZZF stratified weight; check the install"
    * Use macros, not literal counts: the runner reads the log as data, and a
    * SKIPPED branch is still ECHOED.  A literal `tests=1 pass=0 fail=1' echo
    * parses as a numeric RESULT even when this branch never runs, so the runner
    * would see two sentinels and reject the suite.  Backticked macros in the
    * echo are unparseable; only the evaluated line carries numbers.
    local _t = 1
    local _p = 0
    local _f = 1
    local _s = 1
    display as text "RESULT: validation_finegray_zzf_factorization tests=`_t' pass=`_p' fail=`_f' smoke=`_s'"
    log close _zzffac
    exit 9
}

* ===========================================================================
* PART 1 -- Monte Carlo
* ===========================================================================
tempname pf
tempfile mc
postfile `pf' str9 arm int rep double(b1 b2 se1 tf) using "`mc'", replace

local t0run = c(current_time)
forvalues r = 1/`REPS' {
    local s = `SEED0' + `r'

    * one depend-ON dataset; the four weight specifications are PAIRED on it.
    capture _zzffac_gen, n(`N') seed(`s') depend(on) klevels(2)
    if _rc {
        display as error "  GENFAIL depend=on rep `r': rc=`=_rc'"
        foreach a in JOINT MARGINAL SPLIT_G SPLIT_H {
            post `pf' ("`a'") (`r') (.) (.) (.) (.)
        }
    }
    else {
        local tf = r(truncfrac)
        quietly stset t, failure(anyev == 1) id(id) enter(time t0)
        foreach a in JOINT MARGINAL SPLIT_G SPLIT_H {
            local opt ""
            if "`a'" == "JOINT"    local opt "strata(W) truncstrata(W)"
            if "`a'" == "SPLIT_G"  local opt "strata(W)"
            if "`a'" == "SPLIT_H"  local opt "truncstrata(W)"
            capture quietly finegray x1 x2, compete(status) cause(1) `opt'
            if _rc {
                display as error "  FITFAIL `a' rep `r': rc=`=_rc'"
                post `pf' ("`a'") (`r') (.) (.) (.) (`tf')
            }
            else post `pf' ("`a'") (`r') (_b[x1]) (_b[x2]) (_se[x1]) (`tf')
        }
    }

    * NULL control: MARGINAL on a depend-OFF dataset (same seed offset family).
    capture _zzffac_gen, n(`N') seed(`s') depend(off) klevels(2)
    if _rc {
        display as error "  GENFAIL depend=off rep `r': rc=`=_rc'"
        post `pf' ("NULL") (`r') (.) (.) (.) (.)
    }
    else {
        local tf = r(truncfrac)
        quietly stset t, failure(anyev == 1) id(id) enter(time t0)
        capture quietly finegray x1 x2, compete(status) cause(1)
        if _rc post `pf' ("NULL") (`r') (.) (.) (.) (`tf')
        else   post `pf' ("NULL") (`r') (_b[x1]) (_b[x2]) (_se[x1]) (`tf')
    }

    if mod(`r', 10) == 0 ///
        display as text "  ... rep `r' of `REPS' (started `t0run', now `c(current_time)')"
}
postclose `pf'

* ---------------------------------------------------------------------------
* PART 1 verdict
* ---------------------------------------------------------------------------
use "`mc'", clear

local fail_count = 0
local test_count = 0

display as text _newline "{hline 82}"
display as text "PART 1 -- bias under a factorization violation (N = `N', REPS = `REPS')"
display as text "{hline 82}"
display as text %-9s "arm" %-4s "coef" %6s "reps" %9s "mean" %10s "bias" ///
    %10s "MCSE" %8s "z" "  required   verdict"

* per-arm required behaviour
*   JOINT, NULL  -> recover (|z| <= PASS_Z)
*   MARGINAL, SPLIT_G, SPLIT_H -> biased on b1 (|z| > NEG_Z); b2 reported only
foreach a in JOINT NULL MARGINAL SPLIT_G SPLIT_H {
    local kmax = 2
    if inlist("`a'", "MARGINAL", "SPLIT_G", "SPLIT_H") local kmax = 1  /* gate b1 only */
    forvalues k = 1/`kmax' {
        local ++test_count
        local truth = cond(`k' == 1, `TRUTH1', `TRUTH2')

        quietly count if arm == "`a'" & !missing(b`k')
        local nrep = r(N)
        if `nrep' < 2 {
            display as error %-9s "`a'" %-4s "b`k'" "   only `nrep' usable reps"
            local ++fail_count
            continue
        }
        if `nrep' < `REPS' ///
            display as error "  NOTE: `a'/b`k' fitted `nrep' of `REPS' reps (excluded from moments)"

        quietly summarize b`k' if arm == "`a'"
        local mean = r(mean)
        local sd   = r(sd)
        local bias = `mean' - `truth'
        local mcse = `sd' / sqrt(`nrep')
        local z    = `bias' / `mcse'

        if inlist("`a'", "JOINT", "NULL") {
            local ok   = (abs(`z') <= `PASS_Z' & `nrep' == `REPS')
            local want = "recover"
        }
        else {
            local ok   = (abs(`z') > `NEG_Z' & `nrep' == `REPS')
            local want = "biased "
        }
        local verdict = cond(`ok', "PASS", "FAIL")
        if !`ok' local ++fail_count

        * stash b1 bias/sign for the SPLIT signature check below
        if `k' == 1 {
            scalar _bias_`a' = `bias'
            scalar _z_`a'    = `z'
        }

        if `ok' display as result %-9s "`a'" %-4s "b`k'" %6.0f `nrep' %9.5f `mean' ///
            %10.5f `bias' %10.5f `mcse' %8.2f `z' "  `want'    `verdict'"
        else    display as error  %-9s "`a'" %-4s "b`k'" %6.0f `nrep' %9.5f `mean' ///
            %10.5f `bias' %10.5f `mcse' %8.2f `z' "  `want'    `verdict'"
    }
}

* --- the SPLIT signature: measured, not preregistered as a signed claim.
* The two half-conditioned arms must DISAGREE IN SIGN on b1.  That is the
* model-free statement of "the dependence does not split across the two
* groupings": neither single grouping fixes it, and they err oppositely.
local ++test_count
local sig_ok = (_bias_SPLIT_G * _bias_SPLIT_H < 0)
if `sig_ok' {
    display as result _newline "SPLIT signature: SPLIT_G bias = " %8.5f _bias_SPLIT_G ///
        " (z " %6.2f _z_SPLIT_G "), SPLIT_H bias = " %8.5f _bias_SPLIT_H ///
        " (z " %6.2f _z_SPLIT_H ")  -- OPPOSITE signs, as expected: PASS"
}
else {
    display as error _newline "SPLIT signature: SPLIT_G bias = " %8.5f _bias_SPLIT_G ///
        ", SPLIT_H bias = " %8.5f _bias_SPLIT_H "  -- SAME sign, unexpected: FAIL"
    local ++fail_count
}

* ===========================================================================
* PART 2 -- fully-joint vs factorized: the positivity/variance trade
* ===========================================================================
display as text _newline "{hline 82}"
display as text "PART 2 -- the fully-joint alternative is a positivity/variance choice"
display as text "{hline 82}"

* --- 2a. VARIANCE.  Coarse dependence (K=2): JOINT is unbiased (Part 1) but
* estimates a per-cell denominator instead of pooling, so it is more variable.
* Mean analytic SE is the stable metric (per-fit, not a moment over few reps);
* empirical SD is shown beside it.
tempname vf
tempfile vres
postfile `vf' double(bm sm bj sj) using "`vres'", replace
forvalues r = 1/`VREPS' {
    local s = `SEED0' + 500000 + `r'
    capture _zzffac_gen, n(`=min(`N',20000)') seed(`s') depend(on) klevels(2)
    if _rc continue
    quietly stset t, failure(anyev == 1) id(id) enter(time t0)
    capture quietly finegray x1 x2, compete(status) cause(1)
    if _rc {
        local bm = .
        local sm = .
    }
    else {
        local bm = _b[x1]
        local sm = _se[x1]
    }
    capture quietly finegray x1 x2, compete(status) cause(1) strata(W) truncstrata(W)
    if _rc {
        local bj = .
        local sj = .
    }
    else {
        local bj = _b[x1]
        local sj = _se[x1]
    }
    post `vf' (`bm') (`sm') (`bj') (`sj')
}
postclose `vf'

preserve
use "`vres'", clear
quietly count if !missing(sm, sj)
local nv = r(N)
quietly summarize sm if !missing(sm, sj)
local mse_m = r(mean)
quietly summarize sj if !missing(sm, sj)
local mse_j = r(mean)
quietly summarize bm if !missing(sm, sj)
local sd_m = r(sd)
quietly summarize bj if !missing(sm, sj)
local sd_j = r(sd)
restore

local seratio = `mse_j' / `mse_m'
local sdratio = `sd_j'  / `sd_m'
display as text "  variance (K=2, `nv' paired fits):"
display as text "    mean analytic SE(x1):  MARGINAL " %7.5f `mse_m' ///
    "   JOINT " %7.5f `mse_j' "   ratio " %5.2f `seratio'
display as text "    empirical SD(b1):      MARGINAL " %7.5f `sd_m' ///
    "   JOINT " %7.5f `sd_j' "   ratio " %5.2f `sdratio'

local ++test_count
local var_ok = (`seratio' > 1.0 & `nv' >= 2)
if `var_ok' ///
    display as result "  => JOINT is more variable than MARGINAL (SE ratio > 1): PASS"
else {
    display as error "  => expected JOINT SE ratio > 1 (the variance cost of not pooling): FAIL"
    local ++fail_count
}

* --- 2b. POSITIVITY.  Refine W on a fixed n and watch the fully-joint weight's
* denominator go to zero (Z23) while the factorized product stays feasible.
* Deterministic single dataset per K.  klevels are kept <= 100 and cell sizes
* large, so the r(459) that fires is the Z23 ZERO-DENOMINATOR guard, not the
* coarse >100-strata or <20-subject support guards (both of which are separately
* covered by test_finegray_zzf.do).  The Z23 message is asserted from the log,
* not inferred from rc alone -- the user's axis is the message, not the code.
*
* The ladder deliberately uses a MODERATE dependence (cwslope/lwslope below the
* Part 1 values) with LATE entry (entrymul 1.6).  Z23 is a refinement/late-entry
* phenomenon -- a cell with no entrant before a consulted time -- not a
* dependence-strength one; the moderate setting keeps cells >= 20 subjects so the
* guard that fires is the zero-denominator one, isolated from the support guard.
local POSN = 8000
if `POSN' > `N' local POSN = `N'
display as text _newline "  positivity ladder (n = `POSN', entrymul = 1.6, one dataset per K):"
display as text "    K    trunc%   MARGINAL rc   JOINT rc"

local wall_K = 0          /* first K at which JOINT fails but MARGINAL fits */
foreach K in 4 20 40 80 {
    capture _zzffac_gen, n(`POSN') seed(778001) depend(on) klevels(`K') ///
        entrymul(1.6) over(40) cwslope(1.1) lwslope(0.9)
    if _rc {
        display as error "    K=`K': gen rc=`=_rc' (skipped)"
        continue
    }
    local tf = r(truncfrac)
    quietly stset t, failure(anyev == 1) id(id) enter(time t0)
    capture quietly finegray x1 x2, compete(status) cause(1)
    local rcm = _rc

    * JOINT fit into its OWN log so the Z23 message can be read back as data.
    tempfile jlog
    capture log close _fgjoint
    log using "`jlog'", replace name(_fgjoint) text
    capture noisily finegray x1 x2, compete(status) cause(1) strata(W) truncstrata(W)
    local rcj = _rc
    capture log close _fgjoint

    local zmsg = 0
    if `rcj' == 459 {
        preserve
        quietly capture import delimited using "`jlog'", delimiter(`"`=char(1)'"') ///
            varnames(nonames) stringcols(_all) clear
        if _rc == 0 {
            quietly count if strpos(v1, "positivity violation in the delayed-entry weights") > 0
            if r(N) > 0 local zmsg = 1
        }
        restore
    }

    display as text "    " %3.0f `K' %9.1f `=100*`tf'' %12.0f `rcm' %11.0f `rcj' ///
        cond(`rcj'==459 & `zmsg', "  (Z23 zero-denominator)", "")

    if `wall_K' == 0 & `rcm' == 0 & `rcj' == 459 & `zmsg' {
        local wall_K = `K'
        local wall_tf = `tf'
    }
}

local ++test_count
if `wall_K' > 0 {
    display as result _newline "  => at K = `wall_K' the fully-joint weight hits the Z23 positivity"
    display as result "     failure (r(459), zero joint-stratum denominators) while the factorized"
    display as result "     MARGINAL product still fits.  That is the trade: PASS"
}
else {
    display as error _newline "  => did not observe a K where JOINT fails on Z23 while MARGINAL fits."
    display as error "     The positivity trade is unproven in this run: FAIL"
    local ++fail_count
}

* ===========================================================================
* VERDICT
* ===========================================================================
display as text _newline "{hline 82}"
local pass_count = `test_count' - `fail_count'
local smoke = !`FULL'

if `fail_count' == 0 & `FULL' {
    display as result "FACTORIZATION SENSITIVITY: PASS (`test_count' checks, 0 failures)."
    display as result "  JOINT (fully-joint, W in both factors) recovers the truth; MARGINAL and the"
    display as result "  two SPLIT arms are biased (SPLIT arms oppositely) -- the factorization"
    display as result "  violation is real and quantified.  The fully-joint fix costs variance and,"
    display as result "  under refinement, feasibility (Z23 r(459)).  The shipped factorized default"
    display as result "  is that bias-variance/positivity trade, made deliberately."
}
else if `fail_count' == 0 & !`FULL' {
    display as error "Green SHAPE at SMOKE settings (N=`N', REPS=`REPS') -- NOT a gate."
    display as error "  Rerun at N >= 100000, REPS >= 100 to close this sensitivity gate."
}
else {
    display as error "FACTORIZATION SENSITIVITY: FAIL (`fail_count' of `test_count' checks)."
}

display as text "RESULT: validation_finegray_zzf_factorization tests=`test_count' pass=`pass_count' fail=`fail_count' smoke=`smoke'"
log close _zzffac

local gate_ok = (`FULL' & `fail_count' == 0)
if !`gate_ok' exit 9
