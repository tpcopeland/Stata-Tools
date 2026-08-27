*! test_finegray_bstrata Version 1.0.0  2026/08/24
*! Regression tests for bstrata(): baseline-stratified Fine-Gray
*! Author: Timothy P Copeland, Karolinska Institutet

* WHY THIS SUITE EXISTS.
*
* bstrata(varname) frees the baseline subdistribution hazard within each
* stratum while sharing beta -- Zhou, Latouche, Rocha & Fine (2011), Biometrics
* 67(2):661-670.  It rewrites the inside of the five right-censoring scan
* functions (log-likelihood, score/information, score residuals, baseline
* hazard, Schoenfeld) and reshapes e(basehaz) from K x 2 to K x 3.  Three
* things can go silently wrong, and each has a test here that fails on a
* plausible wrong implementation rather than on a crash:
*
*  1. THE UNSTRATIFIED PATH MOVES.  The scan bodies are shared, so a stratum
*     loop that re-sorts, re-derives or re-accumulates anything changes the
*     floating-point order of every EXISTING fit.  B01 is the guard: a
*     bstrata() variable with one level must reproduce the unstratified fit
*     BIT for bit -- e(b), e(V), e(ll) and e(basehaz) -- not "to 1e-10".
*
*  2. THE STRATIFICATION DOES NOT ACTUALLY BITE.  A loop that runs once over
*     all rows, or accumulates one pooled risk set, still converges and still
*     posts plausible coefficients.  B02 pins the estimator against an
*     INDEPENDENT oracle: with no competing events the subdistribution risk set
*     IS the ordinary risk set, so the stratified Fine-Gray must reproduce
*     `stcox, strata() breslow' exactly -- coefficients AND the per-stratum
*     cumulative baseline.  B13 checks the pooled and stratified fits differ.
*
*  3. POST-ESTIMATION READS THE WRONG STRATUM'S BASELINE.  The baseline is now
*     K step functions and every consumer (predict cif / basecshazard,
*     finegray_cif, the bootstrap replay, the Mata cache) has to pick the right
*     one.  Picking the first block, or the pooled curve, is an rc = 0 answer.
*     B10 ties `predict, basecshazard' back to the e(basehaz) block it must
*     have come from; B08 pins finegray_cif's bstratum() contract.
*
* Every refusal in the design is also tested (B05-B07, B09), because each one
* exists to keep an UNSOURCED estimator from being fitted: neither Zhou et al.
* (2011) nor Zhang et al. (2011) covers left truncation, and the Fine & Gray
* (1999) eq. 7-8 psi term is derived for a single pooled baseline.

clear all
set varabbrev off
version 16.0

capture log close _all
log using "test_finegray_bstrata.log", replace name(_fgbs)

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
capture ado uninstall finegray
quietly net install finegray, from("`pkg_dir'") replace

local test_count = 0
local pass_count = 0
local fail_count = 0

capture program drop _fgbs_result
program define _fgbs_result, rclass
    args rc label
    if `rc' == 0 {
        display as result "  PASS: `label'"
        return scalar pass = 1
        return scalar fail = 0
    }
    else {
        display as error "  FAIL: `label' (rc=`rc')"
        return scalar pass = 0
        return scalar fail = 1
    }
end

* Is a K x 3 baseline curve laid out the way every lookup assumes -- stratum
* blocks ascending by LEVEL VALUE, times strictly ascending inside each block?
* Written as a compiled function rather than an inline `mata:' one-liner because
* the block structure needs a loop, and a loop spliced across `///' lines is not
* a legal Mata arglist (r3000).
mata:
real scalar _fgbs_bh_layout_ok(string scalar mname)
{
    real matrix bh
    real scalar k

    bh = st_matrix(mname)
    if (rows(bh) < 2) return(1)
    for (k = 2; k <= rows(bh); k++) {
        if (bh[k, 1] < bh[k - 1, 1]) return(0)
        if (bh[k, 1] == bh[k - 1, 1] & bh[k, 2] <= bh[k - 1, 2]) return(0)
    }
    return(1)
}

/* An independent reference lookup into a K x 3 baseline curve: for each row,
   the LAST curve row whose stratum matches and whose time is <= the row's own
   time.  Deliberately a naive O(n K) linear scan rather than the package's
   binary search, so the two agree only if the block selection is right.

   Done in Mata, not in Stata.  `local ch = bh[r,3]' round-trips the value
   through a string and loses its last bits -- and the same loss on the TIME
   column flips `_t >= tm' at a row that sits exactly on a step, which moves the
   reference by a whole jump (measured: 5% of rows off by up to 0.06, against a
   1e-8 round-off elsewhere).  A tolerance wide enough to absorb that is wide
   enough to absorb reading the wrong stratum's block. */
void _fgbs_step_ref(string scalar bhname, string scalar tvar,
    string scalar bsvar, string scalar outvar)
{
    real matrix bh
    real colvector tt, kk, out
    real scalar i, r, v

    bh = st_matrix(bhname)
    tt = st_data(., tvar)
    kk = st_data(., bsvar)
    out = J(rows(tt), 1, 0)
    for (i = 1; i <= rows(tt); i++) {
        v = 0
        for (r = 1; r <= rows(bh); r++) {
            if (bh[r, 1] == kk[i] & bh[r, 2] <= tt[i]) v = bh[r, 3]
        }
        out[i] = v
    }
    st_store(., outvar, out)
}
end

* Competing-risks fixture with a genuine per-stratum baseline and a SHARED
* coefficient vector: cause-1 hazard is (a + b*ctr) * exp(z'beta), so the
* stratum shifts the baseline and nothing else.  That is the model bstrata()
* claims to fit, so a pooled fit is misspecified on these data by construction.
capture program drop _fgbs_data
program define _fgbs_data
    version 16.0
    args seed nobs nstrata
    if "`seed'" == "" local seed 20260824
    if "`nobs'" == "" local nobs 800
    if "`nstrata'" == "" local nstrata 3
    clear
    set seed `seed'
    quietly set obs `nobs'
    gen long id = _n
    gen byte ctr = 1 + mod(_n, `nstrata')
    gen double x1 = rnormal()
    gen double x2 = rbinomial(1, 0.4)
    gen double lam1 = (0.20 + 0.25 * ctr) * exp(0.50 * x1 - 0.70 * x2)
    gen double lam2 = 0.45 * exp(0.20 * x1)
    gen double tt1 = -ln(runiform()) / lam1
    gen double tt2 = -ln(runiform()) / lam2
    gen double tc  = rexponential(2.2)
    gen double t   = min(tt1, tt2, tc)
    gen byte status = cond(t == tt1, 1, cond(t == tt2, 2, 0))
    gen byte anyev = status != 0
    quietly stset t, failure(anyev == 1) id(id)
end

* Cause-1-only fixture (no competing events) for the stcox oracle.
capture program drop _fgbs_cox_data
program define _fgbs_cox_data
    version 16.0
    clear
    set seed 20260824
    quietly set obs 900
    gen long id = _n
    gen byte ctr = 1 + mod(_n, 3)
    gen double x1 = rnormal()
    gen double x2 = runiform()
    gen double lam = (0.30 + 0.55 * ctr) * exp(0.60 * x1 - 0.80 * x2)
    gen double tev = -ln(runiform()) / lam
    gen double tc  = rexponential(3)
    gen double t   = min(tev, tc)
    gen byte status = (tev <= tc)
    gen byte anyev = status
    quietly stset t, failure(anyev == 1) id(id)
end

* -----------------------------------------------------------------------------
**# B01: K = 1 must be BIT-identical to the unstratified fit
* -----------------------------------------------------------------------------
* The whole unstratified surface of the package rides on this.  A stratum loop
* that re-sorts, or that rebuilds `expeta' per stratum in a different order,
* perturbs every released result in its last digits -- which no tolerance-based
* test would catch, and which the determinism suite would then blame on itself.
local ++test_count
capture noisily {
    _fgbs_data
    gen byte one = 1

    quietly finegray x1 x2, compete(status) cause(1) nolog basehaz
    matrix _B01b = e(b)
    matrix _B01V = e(V)
    matrix _B01h = e(basehaz)
    scalar _B01ll = e(ll)

    quietly finegray x1 x2, compete(status) cause(1) nolog basehaz bstrata(one)
    * e(k_bstrata) is the fitted stratum count, not "was bstrata() typed".
    assert e(k_bstrata) == 1
    assert "`e(bstrata)'" == "one"
    * K = 1 keeps the released K x 2 shape: a consumer of e(basehaz) that never
    * uses bstrata() must not have to learn a new column layout.
    assert colsof(e(basehaz)) == 2
    assert e(ll) == _B01ll
    mata: st_numscalar("_B01db", max(abs(st_matrix("e(b)") - st_matrix("_B01b"))))
    mata: st_numscalar("_B01dV", max(abs(st_matrix("e(V)") - st_matrix("_B01V"))))
    mata: st_numscalar("_B01dh", max(abs(st_matrix("e(basehaz)") - st_matrix("_B01h"))))
    assert _B01db == 0
    assert _B01dV == 0
    assert _B01dh == 0
}
local _rc = _rc
_fgbs_result `_rc' "B01 bstrata() with one level is bit-identical to no bstrata()"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

* -----------------------------------------------------------------------------
**# B02: stratified Cox oracle -- coefficients AND per-stratum baseline
* -----------------------------------------------------------------------------
* With no competing events every subject leaves the risk set at its own exit,
* so the subdistribution risk set is the ordinary one and the Fine-Gray pseudo-
* likelihood IS the Breslow-tie Cox partial likelihood -- stratum by stratum.
* This is an oracle the package does not compute: stcox's stratified fit is
* independent code with an independent optimizer.
local ++test_count
capture noisily {
    _fgbs_cox_data
    quietly stcox x1 x2, strata(ctr) nolog breslow
    matrix _B02cox = e(b)
    quietly predict double _B02h0cox, basechazard

    quietly finegray x1 x2, compete(status) cause(1) nolog bstrata(ctr)
    mata: st_numscalar("_B02db", max(abs(st_matrix("e(b)") - st_matrix("_B02cox"))))
    assert _B02db < 1e-8

    quietly finegray_predict _B02h0fg, basecshazard
    gen double _B02dh = abs(_B02h0fg - _B02h0cox)
    quietly summarize _B02dh, meanonly
    * stcox's own basechazard is stored at its internal precision; 1e-6 is the
    * agreement floor that comparison supports, and it is four orders below the
    * 1e-2 scale on which the strata differ here.
    assert r(max) < 1e-6
}
local _rc = _rc
_fgbs_result `_rc' "B02 no competing events: stratified FG reproduces stcox, strata()"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

* -----------------------------------------------------------------------------
**# B03: the e() contract, including the K x 3 baseline layout
* -----------------------------------------------------------------------------
local ++test_count
capture noisily {
    _fgbs_data
    quietly finegray x1 x2, compete(status) cause(1) nolog basehaz bstrata(ctr)

    assert "`e(bstrata)'" == "ctr"
    assert e(k_bstrata) == 3
    assert colsof(e(basehaz)) == 3
    local _b03names : colnames e(basehaz)
    assert "`_b03names'" == "bstratum time cumhazard"

    * Column 1 carries the bstrata() VALUE, not a 1..K code, and the blocks are
    * ascending by level with ascending time inside each.  Post-estimation
    * binary-searches those blocks, so the ordering is a contract, not a
    * coincidence of how the scan happened to run.
    matrix _B03h = e(basehaz)
    mata: st_numscalar("_B03lev", rows(uniqrows(st_matrix("_B03h")[., 1])))
    assert _B03lev == 3
    mata: st_numscalar("_B03ok", _fgbs_bh_layout_ok("_B03h"))
    assert _B03ok == 1

    * The strata carry DIFFERENT baselines.  Compare each block's TERMINAL
    * cumulative subhazard: identical values would mean the stratum loop
    * accumulated one pooled curve K times and stamped three labels on it.
    mata: bh = st_matrix("_B03h")
    mata: st_numscalar("_B03t1", max(select(bh[., 3], bh[., 1] :== 1)))
    mata: st_numscalar("_B03t3", max(select(bh[., 3], bh[., 1] :== 3)))
    assert abs(_B03t1 - _B03t3) > 1e-3
}
local _rc = _rc
_fgbs_result `_rc' "B03 e(bstrata)/e(k_bstrata)/K x 3 e(basehaz) contract"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

* -----------------------------------------------------------------------------
**# B04: e(refitcmd) replays the stratified fit exactly (the Z24 contract)
* -----------------------------------------------------------------------------
* finegray_cif's and finegray_predict's bootstrap re-issue e(refitcmd) on each
* resample.  A fit option missing from that line does not error there: the refit
* converges, its covariates still match, the replication is ACCEPTED -- and the
* bootstrap silently describes a DIFFERENT estimator than the point estimate it
* is wrapped around.  truncstrata() was once missing exactly this way.
local ++test_count
capture noisily {
    _fgbs_data
    quietly finegray x1 x2, compete(status) cause(1) nolog bstrata(ctr)
    local _b04cmd `"`e(refitcmd)'"'
    matrix _B04b = e(b)
    * named by the test, not assumed: the line must mention the option at all
    assert strpos(`"`_b04cmd'"', "bstrata(ctr)") > 0
    quietly `_b04cmd'
    mata: st_numscalar("_B04d", max(abs(st_matrix("e(b)") - st_matrix("_B04b"))))
    assert _B04d == 0
}
local _rc = _rc
_fgbs_result `_rc' "B04 e(refitcmd) reproduces e(b) for a bstrata() fit"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

* -----------------------------------------------------------------------------
**# B05: refusal -- bstrata() with delayed entry
* -----------------------------------------------------------------------------
* The ZZF delayed-entry branch has no stratum axis.  Reaching it with K > 1
* would fit the POOLED-baseline estimator and post it as a stratified one.
local ++test_count
capture noisily {
    _fgbs_data
    gen double entry = runiform() * 0.30
    quietly stset t, failure(anyev == 1) id(id) enter(time entry)
    capture noisily finegray x1 x2, compete(status) cause(1) nolog bstrata(ctr)
    assert _rc == 198
    * and the unstratified delayed-entry fit is untouched
    quietly finegray x1 x2, compete(status) cause(1) nolog
    assert e(k_bstrata) == 1
    assert "`e(lt_weight)'" != "right_censoring"
}
local _rc = _rc
_fgbs_result `_rc' "B05 bstrata() is refused with delayed entry (r198)"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

* -----------------------------------------------------------------------------
**# B06: bstrata() WITH nuisance -- the fence lifted in v1.4.0
* -----------------------------------------------------------------------------
* Through v1.3.0 this pair was refused: the psi term is FG (1999) eq. 7-8, whose
* q_g(t) was built from the POOLED S0(s) and zbar(s), so accepting the pair
* would have added an UNSTRATIFIED correction to a stratified sandwich --
* neither the paper's variance nor this package's.  Zhou et al. (2011) sec. 4.1
* had always DEFINED the stratified form (FG's psi "with the added subscript
* k"); only the implementation was missing, and v1.4.0 supplies it.
*
* This test now asserts the opposite of what it used to, on purpose.  What it
* keeps from the old version is the discriminating half: each option must still
* mean what it meant alone, and e(vce_meat) must report which sandwich came
* back.  The estimator itself is gated against crrs ctype=1 in
* crossval_bstrata.do and bit-checked at K=1 in BSPSI-1 below.
local ++test_count
capture noisily {
    _fgbs_data
    quietly finegray x1 x2, compete(status) cause(1) nolog ///
        bstrata(ctr) nuisance
    assert e(converged) == 1
    assert "`e(vce_meat)'" == "nuisance_adjusted"
    assert e(k_bstrata) == 3
    * each half still means what it means on its own
    quietly finegray x1 x2, compete(status) cause(1) nolog nuisance
    assert "`e(vce_meat)'" == "nuisance_adjusted"
    quietly finegray x1 x2, compete(status) cause(1) nolog bstrata(ctr)
    assert "`e(vce_meat)'" == "fixed_weight"
}
local _rc = _rc
_fgbs_result `_rc' "B06 bstrata() with nuisance fits and reports nuisance_adjusted"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

* -----------------------------------------------------------------------------
**# B07: refusal -- a subject may not change baseline stratum
* -----------------------------------------------------------------------------
local ++test_count
capture noisily {
    clear
    set seed 20260824
    quietly set obs 400
    gen long id = ceil(_n / 2)
    bysort id: gen byte seq = _n
    gen double t0 = cond(seq == 1, 0, 1)
    gen double t  = cond(seq == 1, 1, 1 + runiform() * 2)
    gen double x1 = rnormal()
    quietly by id: replace x1 = x1[1]
    gen byte ctr = 1 + mod(id, 2)
    * the second record moves the subject to the other stratum
    quietly replace ctr = 3 - ctr if seq == 2
    * One draw, three branches.  Written as two nested cond()s each calling
    * runiform() the arms were not what they read as: the second cond() drew a
    * FRESH uniform, so cause 2 got 0.5 x 0.5 = 25% and censoring 25%, not the
    * 50/25/25 split the expression looks like.  Harmless to the assertion --
    * the stratum-varying refusal fires before any event is classified -- but
    * this fixture is the kind that gets copied into a test where it matters.
    gen double _u07 = runiform()
    gen byte status = cond(seq != 2, 0, cond(_u07 < .5, 1, cond(_u07 < .75, 2, 0)))
    gen byte anyev = status != 0
    quietly stset t, failure(anyev == 1) id(id) time0(t0)
    capture noisily finegray x1, compete(status) cause(1) nolog bstrata(ctr)
    assert _rc == 198
}
local _rc = _rc
_fgbs_result `_rc' "B07 bstrata() must be constant within id() (r198)"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

* -----------------------------------------------------------------------------
**# B08: finegray_cif's bstratum() contract
* -----------------------------------------------------------------------------
* Under bstrata() a covariate profile no longer identifies a curve: the same
* at() has K different CIFs.  Choosing one silently would report one of K
* answers with nothing on screen to say which.
local ++test_count
capture noisily {
    _fgbs_data
    quietly finegray x1 x2, compete(status) cause(1) nolog bstrata(ctr)

    capture noisily finegray_cif, attime(1) nograph
    assert _rc == 198
    capture noisily finegray_cif, attime(1) bstratum(9) nograph
    assert _rc == 459

    quietly finegray_cif, attime(1 2) bstratum(1) nograph
    matrix _B08a = r(table)
    assert r(bstratum) == 1
    assert "`r(bstrata)'" == "ctr"
    quietly finegray_cif, attime(1 2) bstratum(3) nograph
    matrix _B08c = r(table)
    * same profile, different stratum -> different curve.  Equality here would
    * mean the stratum argument never reached the baseline lookup.
    mata: st_numscalar("_B08d", ///
        max(abs(st_matrix("_B08a")[., 2] - st_matrix("_B08c")[., 2])))
    assert _B08d > 1e-3

    * and bstratum() is refused after an UNSTRATIFIED fit rather than ignored
    quietly finegray x1 x2, compete(status) cause(1) nolog
    capture noisily finegray_cif, attime(1) bstratum(1) nograph
    assert _rc == 198
}
local _rc = _rc
_fgbs_result `_rc' "B08 finegray_cif requires and validates bstratum()"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

* -----------------------------------------------------------------------------
**# B09: a stratum with no cause event is fitted, named, and refused a baseline
* -----------------------------------------------------------------------------
* Its terms drop out of the pseudo-likelihood, so the FIT is fine.  Its Breslow
* baseline, however, is identically zero -- a degenerate curve, not an estimate
* of one -- and a CIF of exactly 0 for a whole centre reads as a finding.
local ++test_count
capture noisily {
    _fgbs_data
    * remove every cause-1 event from stratum 3
    quietly replace status = 2 if ctr == 3 & status == 1
    quietly finegray x1 x2, compete(status) cause(1) nolog bstrata(ctr)
    assert e(k_bstrata) == 3
    assert "`e(bstrata_noevent)'" == "3"

    capture noisily finegray_predict _B09c, cif
    assert _rc == 459
    capture confirm variable _B09c
    assert _rc != 0

    capture noisily finegray_predict _B09b, basecshazard
    assert _rc == 459

    capture noisily finegray_cif, attime(1) bstratum(3) nograph
    assert _rc == 459

    * excluding the degenerate stratum works, and xb never needed a baseline
    quietly finegray_predict _B09c2 if ctr < 3, cif
    quietly summarize _B09c2
    * min can legitimately be 0 -- a subject whose _t precedes the first cause
    * event in its stratum has CIF exactly 0 -- so the assertion is that the
    * column exists and is not uniformly zero.
    assert !missing(r(N), r(max), r(min))
    assert r(N) > 0 & r(max) > 0 & r(min) >= 0
    quietly finegray_predict _B09x, xb
    quietly summarize _B09x
    assert r(N) == e(N)
    quietly finegray_cif, attime(1) bstratum(1) nograph
    assert _rc == 0
}
local _rc = _rc
_fgbs_result `_rc' "B09 an event-free stratum fits, is named in e(), and refuses a baseline"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

* -----------------------------------------------------------------------------
**# B10: predict, basecshazard reads the row's OWN stratum block
* -----------------------------------------------------------------------------
* This is the test that a pooled or first-block lookup fails.  Each subject's
* baseline at its own _t is looked up independently, in Mata, from the K x 3
* curve; here it is recomputed in Stata from e(basehaz) and the two must agree
* exactly.
local ++test_count
capture noisily {
    _fgbs_data
    quietly finegray x1 x2, compete(status) cause(1) nolog basehaz bstrata(ctr)
    * `double' explicitly: `syntax newvarname' defaults to float, and a float
    * column agrees with the curve only to ~1e-8 -- a tolerance wide enough to
    * hide nothing here, but wide enough that the test would stop being an
    * equality test.
    quietly finegray_predict double _B10h0, basecshazard

    matrix _B10bh = e(basehaz)
    gen double _B10ref = .
    mata: _fgbs_step_ref("_B10bh", "_t", "ctr", "_B10ref")
    gen double _B10d = abs(_B10h0 - _B10ref)
    quietly summarize _B10d, meanonly
    assert r(max) == 0

    * and the strata really do give different baselines at a common time
    quietly summarize _B10h0 if ctr == 1, meanonly
    local _m1 = r(mean)
    quietly summarize _B10h0 if ctr == 3, meanonly
    assert abs(r(mean) - `_m1') > 1e-4
}
local _rc = _rc
_fgbs_result `_rc' "B10 predict basecshazard matches the row's own e(basehaz) block"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

* -----------------------------------------------------------------------------
**# B11: bstrata() is in the estimation signature
* -----------------------------------------------------------------------------
* Changing which stratum a subject belongs to changes which baseline answers
* for it.  Post-estimation that reads the estimation data must fail closed.
local ++test_count
capture noisily {
    _fgbs_data
    quietly finegray x1 x2, compete(status) cause(1) nolog bstrata(ctr)
    local _b11sig "`e(datasignaturevars)'"
    local _b11pos : list posof "ctr" in _b11sig
    assert `_b11pos' > 0

    quietly replace ctr = 3 - ctr if ctr < 3 & _n <= 20
    capture noisily finegray_cif, attime(1) bstratum(1) nograph
    assert _rc != 0
    capture noisily finegray_predict _B11c, cif ci
    assert _rc != 0
    capture noisily finegray_phtest
    assert _rc != 0
}
local _rc = _rc
_fgbs_result `_rc' "B11 altering bstrata() after the fit fails post-estimation closed"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

* -----------------------------------------------------------------------------
**# B12: Schoenfeld residuals and finegray_phtest are stratum-aware
* -----------------------------------------------------------------------------
* The residuals are formed against the row's own stratum risk set and pooled for
* the diagnostic.  If the stratum never reached the scan they would equal the
* pooled fit's residuals for the same beta.
local ++test_count
capture noisily {
    _fgbs_data
    quietly finegray x1 x2, compete(status) cause(1) nolog bstrata(ctr)
    quietly finegray_predict _B12s, schoenfeld
    quietly summarize _B12s
    local _b12n = r(N)
    assert `_b12n' == e(N_fail)

    * one residual per cause event, aligned to the cause events themselves
    quietly count if e(sample) & status == 1 & _d == 1 & !missing(_B12s)
    assert r(N) == `_b12n'
    quietly count if !missing(_B12s) & !(status == 1 & _d == 1)
    assert r(N) == 0

    quietly finegray_phtest
    assert _rc == 0

    * Scored against POOLED risk sets the residuals differ ROW BY ROW.  Their
    * MEANS do not discriminate: sum_i (Z_i - zbar) over cause events IS the
    * score, which is zero at either solution, so both columns average ~0
    * whether or not the stratum ever reached the scan.
    quietly finegray x1 x2, compete(status) cause(1) nolog
    quietly finegray_predict _B12p, schoenfeld
    gen double _B12d = abs(_B12s - _B12p)
    quietly summarize _B12d, meanonly
    assert !missing(r(max))
    assert r(max) > 1e-6
}
local _rc = _rc
_fgbs_result `_rc' "B12 Schoenfeld residuals and phtest run within stratum"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

* -----------------------------------------------------------------------------
**# B13: the option changes the estimate, and strata() is a different axis
* -----------------------------------------------------------------------------
* strata() stratifies the censoring KM, bstrata() the baseline.  They compose --
* that pairing is exactly crrSC::crrs's ctype = 1 -- and neither implies the
* other.  A build in which bstrata() were quietly routed into the censoring
* strata would still fit, converge and post coefficients.
local ++test_count
capture noisily {
    _fgbs_data
    quietly finegray x1 x2, compete(status) cause(1) nolog
    matrix _B13pool = e(b)
    quietly finegray x1 x2, compete(status) cause(1) nolog bstrata(ctr)
    matrix _B13bs = e(b)
    quietly finegray x1 x2, compete(status) cause(1) nolog strata(ctr)
    matrix _B13g = e(b)
    quietly finegray x1 x2, compete(status) cause(1) nolog bstrata(ctr) strata(ctr)
    matrix _B13both = e(b)
    assert "`e(bstrata)'" == "ctr"
    assert "`e(strata)'" == "ctr"

    mata: st_numscalar("_B13a", max(abs(st_matrix("_B13bs") - st_matrix("_B13pool"))))
    mata: st_numscalar("_B13b", max(abs(st_matrix("_B13bs") - st_matrix("_B13g"))))
    mata: st_numscalar("_B13c", max(abs(st_matrix("_B13both") - st_matrix("_B13bs"))))
    assert _B13a > 1e-4
    assert _B13b > 1e-4
    assert _B13c > 1e-8
}
local _rc = _rc
_fgbs_result `_rc' "B13 bstrata() moves e(b) and is not strata()"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

* -----------------------------------------------------------------------------
**# B14: the header says the fit is stratified, at fit time and on replay
* -----------------------------------------------------------------------------
* A stratified fit and a pooled one are different estimators.  Before the
* delayed-entry header lines existed, a ZZF fit and an ordinary one were
* display-indistinguishable and only `ereturn list' told them apart; the same
* trap is available here.  The display reads e() only, so the replay must print
* the same lines -- which is also what makes this testable from a log.
local ++test_count
capture noisily {
    _fgbs_data
    capture log close _b14
    tempfile _b14log
    log using `"`_b14log'"', replace text name(_b14)
    finegray x1 x2, compete(status) cause(1) nolog bstrata(ctr)
    finegray
    finegray x1 x2, compete(status) cause(1) nolog
    log close _b14

    * Read the captured output back and count the header lines.  Reading the
    * RENDERED log is the point: an e() macro that is posted but never printed
    * would satisfy any ereturn-based assertion and still leave the two fits
    * looking identical on screen.
    tempname _fh
    local _nvar = 0
    local _nk = 0
    local _nother = 0
    file open `_fh' using `"`_b14log'"', read text
    file read `_fh' line
    while r(eof) == 0 {
        if strpos(`"`line'"', "Baseline strata:") > 0     local ++_nvar
        if strpos(`"`line'"', "No. baseline strata") > 0  local ++_nk
        if strpos(`"`line'"', "Censoring strata:") > 0    local ++_nother
        file read `_fh' line
    }
    file close `_fh'

    * Twice: once at fit time, once on replay.  The third (unstratified) fit
    * must print neither, or the line would be noise on every fit.
    assert `_nvar' == 2
    assert `_nk' == 2
    * and bstrata() is not being reported as the censoring strata
    assert `_nother' == 0
}
local _rc = _rc
capture log close _b14
_fgbs_result `_rc' "B14 the header reports bstrata() at fit time and on replay"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

* -----------------------------------------------------------------------------
**# BSPSI-1 K = 1 with nuisance is BIT-identical to the unstratified psi term
* -----------------------------------------------------------------------------
* The internal half of the v1.4.0 stratified-psi evidence.  crossval_bstrata.do
* gates the estimator against crrs ctype=1 externally; this gates the other
* direction -- that adding the stratum index did not perturb the term it was
* built out of.  Bit-identity, not tolerance: _finegray_psi_residuals takes the
* K == 1 branches literally (colsum for the initial risk-set totals, qsum
* aliased to qg rather than re-summed) precisely so the floating-point
* accumulation order is unchanged, and a tolerance here would not notice if that
* stopped being true.
local ++test_count
capture noisily {
    _fgbs_data
    quietly gen byte one = 1

    quietly finegray x1 x2, compete(status) cause(1) nuisance nolog
    tempname VPLAIN BPLAIN
    matrix `VPLAIN' = e(V)
    matrix `BPLAIN' = e(b)
    assert `"`e(vce_meat)'"' == "nuisance_adjusted"

    quietly finegray x1 x2, compete(status) cause(1) nuisance bstrata(one) nolog
    assert e(k_bstrata) == 1
    assert `"`e(vce_meat)'"' == "nuisance_adjusted"
    * mreldif is exactly 0 only if every cell matches bit for bit
    assert !missing(mreldif(e(V), `VPLAIN'))
    assert mreldif(e(V), `VPLAIN') == 0
    assert mreldif(e(b), `BPLAIN') == 0

    * and the same with a censoring-KM axis in play, which is where the (g, k)
    * flattening could have crossed its indices
    quietly finegray x1 x2, compete(status) cause(1) nuisance strata(ctr) nolog
    matrix `VPLAIN' = e(V)
    quietly finegray x1 x2, compete(status) cause(1) nuisance strata(ctr) ///
        bstrata(one) nolog
    assert mreldif(e(V), `VPLAIN') == 0
}
local _rc = _rc
_fgbs_result `_rc' "BSPSI-1 bstrata(constant) + nuisance is bit-identical to plain nuisance"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

* -----------------------------------------------------------------------------
**# BSPSI-2 psi under bstrata() moves the variance and only the variance
* -----------------------------------------------------------------------------
* Two claims a silently-ignored option would fail: the coefficients must NOT
* move (psi is a variance correction, and if beta moved the option had reached
* the wrong place), and the variance MUST move (or nothing was added).
local ++test_count
capture noisily {
    foreach kk in 2 3 5 {
        _fgbs_data 20260826 900 `kk'
        quietly finegray x1 x2, compete(status) cause(1) bstrata(ctr) nolog
        tempname VETA BETA
        matrix `VETA' = e(V)
        matrix `BETA' = e(b)
        assert e(k_bstrata) == `kk'

        quietly finegray x1 x2, compete(status) cause(1) bstrata(ctr) ///
            nuisance nolog
        assert e(k_bstrata) == `kk'
        assert `"`e(vce_meat)'"' == "nuisance_adjusted"

        forvalues j = 1/`= colsof(`BETA')' {
            assert !missing(`BETA'[1, `j'], e(b)[1, `j'])
            assert reldif(`BETA'[1, `j'], e(b)[1, `j']) < 1e-12
        }
        local moved = 0
        forvalues j = 1/`= colsof(`VETA')' {
            assert !missing(`VETA'[`j', `j'], e(V)[`j', `j'])
            assert e(V)[`j', `j'] > 0
            if reldif(`VETA'[`j', `j'], e(V)[`j', `j']) > 1e-9 local moved = 1
        }
        assert `moved' == 1
    }
}
local _rc = _rc
_fgbs_result `_rc' "BSPSI-2 nuisance under bstrata() moves e(V), never e(b), at K=2/3/5"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

* -----------------------------------------------------------------------------
**# BSPSI-3 degenerate strata under nuisance
* -----------------------------------------------------------------------------
* A stratum with no cause events contributes nothing to the score and nothing to
* q; a stratum with no competing events has an empty retained-competing
* accumulator so its q is exactly zero.  Neither may produce a missing or a
* non-positive variance, and neither may take the fit down.
local ++test_count
capture noisily {
    _fgbs_data 20260826 900 3
    * stratum 3 keeps only censored and competing records: no cause events
    quietly replace status = 2 if ctr == 3 & status == 1
    quietly replace anyev = status != 0
    quietly stset t, failure(anyev == 1) id(id)
    quietly finegray x1 x2, compete(status) cause(1) bstrata(ctr) nuisance nolog
    assert e(converged) == 1
    assert e(k_bstrata) == 3
    forvalues j = 1/`= colsof(e(V))' {
        assert !missing(e(V)[`j', `j'])
        assert e(V)[`j', `j'] > 0
    }

    * stratum 2 keeps no competing events
    _fgbs_data 20260826 900 3
    quietly replace status = 0 if ctr == 2 & status == 2
    quietly replace anyev = status != 0
    quietly stset t, failure(anyev == 1) id(id)
    quietly finegray x1 x2, compete(status) cause(1) bstrata(ctr) nuisance nolog
    assert e(converged) == 1
    forvalues j = 1/`= colsof(e(V))' {
        assert !missing(e(V)[`j', `j'])
        assert e(V)[`j', `j'] > 0
    }

    * no censoring at all: Ghat == 1 everywhere, so psi is identically zero and
    * the corrected variance must equal the eta-only one exactly
    _fgbs_data 20260826 900 3
    quietly replace status = 1 if status == 0
    quietly replace anyev = 1
    quietly stset t, failure(anyev == 1) id(id)
    quietly finegray x1 x2, compete(status) cause(1) bstrata(ctr) nolog
    tempname VNOCENS
    matrix `VNOCENS' = e(V)
    quietly finegray x1 x2, compete(status) cause(1) bstrata(ctr) nuisance nolog
    assert !missing(mreldif(e(V), `VNOCENS'))
    assert mreldif(e(V), `VNOCENS') < 1e-12
}
local _rc = _rc
_fgbs_result `_rc' "BSPSI-3 degenerate strata and complete follow-up under nuisance"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

* -----------------------------------------------------------------------------
**# BSPSI-4 e(refitcmd) replays a nuisance x bstrata fit (Z24 for the new cell)
* -----------------------------------------------------------------------------
* nuisance is deliberately absent from e(refitcmd) -- it cannot move e(b) and
* the bootstrap consumers read only e(b) -- so what this asserts is that the
* newly-legal combination still round-trips the COEFFICIENTS, and that the
* replay is a bstrata() fit rather than a pooled one.
local ++test_count
capture noisily {
    _fgbs_data
    foreach spec in "bstrata(ctr) nuisance" "bstrata(ctr) strata(ctr) nuisance" ///
        "bstrata(ctr) nuisance cluster(ctr)" {
        quietly finegray x1 x2, compete(status) cause(1) `spec' nolog
        tempname B0
        matrix `B0' = e(b)
        local rfc `"`e(refitcmd)'"'
        assert strpos(`"`rfc'"', "bstrata(ctr)") > 0
        quietly `rfc'
        assert e(k_bstrata) == 3
        forvalues j = 1/`= colsof(`B0')' {
            assert !missing(`B0'[1, `j'], e(b)[1, `j'])
            assert reldif(`B0'[1, `j'], e(b)[1, `j']) < 1e-12
        }
    }
}
local _rc = _rc
_fgbs_result `_rc' "BSPSI-4 e(refitcmd) reproduces e(b) for nuisance x bstrata combinations"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

* -----------------------------------------------------------------------------
**# BSPSI-5 the duplicate-stratum identity: an INTERNAL oracle for stratified psi
* -----------------------------------------------------------------------------
* WHY THIS EXISTS.  Mutation-testing the v1.4.0 stratified psi on 2026-08-26
* found that BSPSI-1 to BSPSI-4 are BLIND to it: zeroing one stratum's q block
* entirely left all four green, and only crossval_bstrata.do (which needs R and
* crrSC) went red.  A feature whose only real guard lives behind an external
* dependency is a feature that is unguarded whenever that dependency is missing.
*
* THE ORACLE.  Duplicate the dataset, give the copies distinct ids, and label
* them ctr = 1 and 2.  Then fit with bstrata(ctr) strata(ctr):
*
*   - each stratum's rows ARE the original dataset, so its Ghat (estimated
*     within stratum), its risk-set totals S0_k, its at-risk counts Y_k and
*     therefore its whole (eta + psi) influence contribution are the original
*     data's, value for value;
*   - Zhou (2011) sec. 4.1 makes the score, the information and the meat sums
*     over strata, so Omega_full = 2 Omega and Sigma_full = 2 Sigma exactly;
*   - hence beta-hat is unchanged and
*         V_full = (2 Omega)^-1 (2 Sigma) (2 Omega)^-1 = V / 2.
*
* So the stratified psi term must halve the single-dataset psi variance, EXACTLY
* -- and it can only do that if every stratum's block is present and correct.
* Zero one and the factor is not 2.  No external package is involved.
*
* noadjust on both sides: the N/(N-1) factor sees different N and would spoil
* the identity for a reason that has nothing to do with psi.
local ++test_count
capture noisily {
    _fgbs_data 20260826 700 2

    quietly finegray x1 x2, compete(status) cause(1) nuisance noadjust nolog
    tempname V1 B1
    matrix `V1' = e(V)
    matrix `B1' = e(b)
    local n1 = e(N)
    assert `"`e(vce_meat)'"' == "nuisance_adjusted"

    * two labelled copies, ids kept distinct
    quietly expand 2
    quietly bysort id: gen byte cpy = _n
    quietly replace id = id * 2 - 2 + cpy
    quietly stset t, failure(anyev == 1) id(id)
    quietly finegray x1 x2, compete(status) cause(1) ///
        bstrata(cpy) strata(cpy) nuisance noadjust nolog
    assert e(N) == 2 * `n1'
    assert e(k_bstrata) == 2
    assert `"`e(vce_meat)'"' == "nuisance_adjusted"

    * beta is unchanged: the score doubled, so its root did not move
    forvalues j = 1/`= colsof(`B1')' {
        assert !missing(`B1'[1, `j'], e(b)[1, `j'])
        assert reldif(`B1'[1, `j'], e(b)[1, `j']) < 1e-8
    }
    * and the variance is EXACTLY half.  Not "smaller" -- half.
    tempname HALF
    matrix `HALF' = `V1' / 2
    assert !missing(mreldif(e(V), `HALF'))
    assert mreldif(e(V), `HALF') < 1e-9

    * The same identity must ALSO hold for the eta-only fit, so a pass here
    * cannot be explained by the duplication trick failing to see psi at all.
    * And the two must be different matrices, or psi contributed nothing on
    * this fixture and the halving test is vacuous.
    _fgbs_data 20260826 700 2
    quietly finegray x1 x2, compete(status) cause(1) noadjust nolog
    tempname V1E
    matrix `V1E' = e(V)
    assert mreldif(`V1E', `V1') > 1e-8
    quietly expand 2
    quietly bysort id: gen byte cpy = _n
    quietly replace id = id * 2 - 2 + cpy
    quietly stset t, failure(anyev == 1) id(id)
    quietly finegray x1 x2, compete(status) cause(1) ///
        bstrata(cpy) strata(cpy) noadjust nolog
    matrix `HALF' = `V1E' / 2
    assert mreldif(e(V), `HALF') < 1e-9
}
local _rc = _rc
_fgbs_result `_rc' ///
    "BSPSI-5 duplicating the data into two strata halves e(V) exactly, with psi"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

**# Summary
display as text _newline ///
    "RESULT: test_finegray_bstrata tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    log close _fgbs
    exit 1
}
display as result "ALL TESTS PASSED"
log close _fgbs
