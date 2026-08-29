*! test_finegray_weights Version 1.0.0  2026/08/28
*! Functional and identity tests for [pweight=] / [fweight=] on finegray
*! Author: Timothy P Copeland, Karolinska Institutet

* WHY THIS SUITE EXISTS.
*
* Design weights thread one per-subject constant through every risk-set sum
* of the forward-backward scan (Wogu, Zhao, Nichols & Cai 2021, eq. 3), the
* Breslow baseline (eq. 4), the score residuals, the influence-function CIF
* variance and the Schoenfeld residuals.  Three things go silently wrong in an
* implementation like that, and each has a test here that fails on a
* plausible wrong implementation rather than on a crash:
*
*  1. THE UNWEIGHTED PATH MOVES.  The scan bodies are shared, so a weight
*     that is applied as `1 * x' in one accumulator and `x / 1' in another,
*     or an association that changed, perturbs every EXISTING fit in its last
*     bits.  WT-01/WT-02 are the guard: [pw=1] and [fw=1] must reproduce the
*     unweighted fit BIT for bit -- e(b), e(V), e(ll), e(basehaz), every
*     row-level prediction, the CIF table -- not "to 1e-10".
*
*  2. THE WEIGHT DOES NOT ACTUALLY BITE EVERYWHERE.  A weight applied in the
*     risk set but not in the Breslow numerator, or in the score but not in
*     the meat, still converges and posts plausible numbers.  Two internal
*     oracles catch that without R:
*       fweight == expand   (WT-03) an fweighted fit IS the fit of the
*                           replicated data: e(b), e(V), e(ll), N, the
*                           counts, the baseline and the CIF must all agree,
*                           censoring included (the censoring KM is
*                           fweighted too).
*       pweight == expand + cluster(id)   (WT-06) with NO censoring (G == 1),
*                           the pweight sandwich sum_i (w_i s_i)^2 with
*                           N/(N-1) is exactly the cluster-robust sandwich
*                           of the replicated data clustered on the
*                           original subject, with g/(g-1), g = N.  This is
*                           the meat-form check: the fweight form
*                           sum_i w_i s_i^2 fails it.
*     The censored pweight case has no in-Stata oracle and is cross-validated
*     against survival::finegray(weights=) + coxph(robust=TRUE) in
*     qa/crossval_pweight.do.
*
*  3. POST-ESTIMATION FORGETS THE WEIGHT.  The baseline is rebuilt from the
*     data on three paths, the CIF variance recomputes the score residuals,
*     the bootstrap re-issues e(refitcmd), and the Schoenfeld residuals use
*     the risk-set mean.  Any of them rebuilt UNWEIGHTED answers at rc 0 with
*     the wrong curve.  WT-08/WT-09 tie every post-estimation route back to
*     the fit and to each other; WT-10 pins that a changed weight is refused.
*     WT-14 pins the OTHER half of that refusal: the signature covers only
*     the variables the expression names, so a changed scalar, or a re-sort
*     under a subscript such as w[1], rebuilt a different column at rc 0 until
*     _finegray_weight_var reconciled the rebuilt total against e(sum_w).
*
* The scope fences (every cell the release does not derive) are asserted on
* (rc, tokens) in test_finegray_fences.do and their wording in the canary in
* test_finegray_errors.do; here only the DATA-level refusals are exercised.
*
* EVERY BLOCK ENDS WITH `capture restore'.  `preserve' inside a do-file is not
* scoped to the `capture noisily' block: an assertion that fails between a
* `preserve' and its `restore' leaks the preserved state, and the NEXT block
* that preserves then stops at r(621) before reaching any assertion of its
* own.  Observed on a deliberately sabotaged build (2026-08-29): WT-03 failed
* genuinely at rc 9, after which WT-06 and WT-07 reported failures they had
* never actually run.  The `capture restore' after each block keeps one real
* failure from manufacturing others.

clear all
set varabbrev off
version 16.0

local qa_dir "`c(pwd)'"
capture log close _all
log using "test_finegray_weights.log", replace text name(_fgwt)
do "`qa_dir'/_finegray_qa_common.do"
quietly _finegray_qa_bootstrap

local test_count = 0
local pass_count = 0
local fail_count = 0

capture program drop _fgwt_result
program define _fgwt_result, rclass
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

* Competing-risks fixture drawn from the Fine-Gray model itself: cause 1 by
* inverting F1(t|z) = 1 - [1 - p(1 - e^-t)]^exp(eta) exactly, cause 2 with the
* remaining mass, exponential censoring.  Continuous weights `pw', integer
* weights `fw' in 1..3, a three-level factor, 25 clusters, and a constant `one'.
capture program drop _fgwt_data
program define _fgwt_data
    version 16.0
    syntax [, N(integer 600) SEED(integer 20260828) CENSrate(real 0.15) TIES]
    clear
    set seed `seed'
    quietly set obs `n'
    gen long id = _n
    gen double x1 = rnormal()
    gen byte grp = 1 + floor(runiform() * 3)
    gen byte cl = 1 + mod(_n, 25)
    gen double eta = 0.5 * x1 + 0.3 * (grp == 2) - 0.4 * (grp == 3)
    gen double u = runiform()
    gen double f1inf = 1 - (1 - 0.5)^exp(eta)
    gen byte cause = cond(u < f1inf, 1, 2)
    gen double tev = -ln(1 - (1 - (1 - u)^exp(-eta)) / 0.5) if cause == 1
    quietly replace tev = -ln(runiform()) if cause == 2
    gen double tc = cond(`censrate' > 0, -ln(runiform()) / `censrate', 1e10)
    gen double time = min(tev, tc)
    gen byte status = cond(tev <= tc, cause, 0)
    if "`ties'" != "" quietly replace time = ceil(time * 4) / 4
    quietly replace time = 1e-6 if time <= 0
    gen double pw = 0.5 + 2.5 * runiform()
    gen byte fw = 1 + floor(runiform() * 3)
    gen byte one = 1
    drop u f1inf tev tc eta
    quietly stset time, failure(status) id(id)
end

* Assert two matrices are IDENTICAL (mreldif == 0), with a readable failure.
capture program drop _fgwt_same
program define _fgwt_same
    args a b label
    capture assert mreldif(`a', `b') == 0
    if _rc {
        display as error "  not bit-identical: `label' (mreldif = " mreldif(`a', `b') ")"
        error 9
    }
end

* -----------------------------------------------------------------------------
**# WT-01  [pweight = 1] is bit-identical to the unweighted fit, everywhere
* -----------------------------------------------------------------------------
local ++test_count
capture noisily {
    _fgwt_data
    finegray x1 i.grp, compete(status) cause(1) nolog basehaz
    tempname b0 V0 bh0 cif0
    matrix `b0' = e(b)
    matrix `V0' = e(V)
    matrix `bh0' = e(basehaz)
    local ll0 = e(ll)
    local ll00 = e(ll_0)
    local chi0 = e(chi2)
    predict double cif0, cif
    predict double cifc0, cif ci
    predict double sch0, schoenfeld
    predict double h00, basecshazard
    finegray_cif, at(x1=0.3 grp=2) attime(0.5 1 2) ci nograph
    matrix `cif0' = r(table)

    finegray x1 i.grp [pw = one], compete(status) cause(1) nolog basehaz
    assert "`e(wtype)'" == "pweight"
    assert "`e(wexp)'" == "= one"
    assert e(N) == _N
    assert e(sum_w) == _N
    assert "`e(vce)'" == "robust"
    _fgwt_same e(b) `b0' "pw=1 e(b)"
    _fgwt_same e(V) `V0' "pw=1 e(V)"
    _fgwt_same e(basehaz) `bh0' "pw=1 e(basehaz)"
    assert e(ll) == `ll0'
    assert e(ll_0) == `ll00'
    assert e(chi2) == `chi0'
    predict double cif1, cif
    predict double cifc1, cif ci
    predict double sch1, schoenfeld
    predict double h01, basecshazard
    assert cif1 == cif0
    assert cifc1_lci == cifc0_lci & cifc1_uci == cifc0_uci
    assert sch1 == sch0 & sch1_2 == sch0_2 & sch1_3 == sch0_3
    assert h01 == h00
    finegray_cif, at(x1=0.3 grp=2) attime(0.5 1 2) ci nograph
    _fgwt_same r(table) `cif0' "pw=1 finegray_cif table"
    * replay prints the weighted header and returns rc 0
    finegray
    assert "`e(wtype)'" == "pweight"
}
local _rc = _rc
capture restore
_fgwt_result `_rc' "WT-01 [pw=1] bit-identical: e(b) e(V) e(ll) e(basehaz) predict cif/ci/schoenfeld/basecshazard finegray_cif"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

* -----------------------------------------------------------------------------
**# WT-02  [fweight = 1] is bit-identical, including the censoring KM and norobust
* -----------------------------------------------------------------------------
local ++test_count
capture noisily {
    _fgwt_data
    finegray x1 i.grp, compete(status) cause(1) nolog basehaz
    tempname b0 V0 bh0
    matrix `b0' = e(b)
    matrix `V0' = e(V)
    matrix `bh0' = e(basehaz)
    local ll0 = e(ll)
    local ntr0 = e(N_G_trunc)
    finegray x1 i.grp, compete(status) cause(1) nolog norobust
    tempname Vm0
    matrix `Vm0' = e(V)
    finegray x1 i.grp, compete(status) cause(1) nolog cluster(cl)
    tempname Vc0
    matrix `Vc0' = e(V)

    finegray x1 i.grp [fw = one], compete(status) cause(1) nolog basehaz
    assert "`e(wtype)'" == "fweight"
    assert e(N) == _N
    assert e(N_fail) + e(N_compete) + e(N_cens) == _N
    assert e(N_G_trunc) == `ntr0'
    _fgwt_same e(b) `b0' "fw=1 e(b)"
    _fgwt_same e(V) `V0' "fw=1 e(V)"
    _fgwt_same e(basehaz) `bh0' "fw=1 e(basehaz)"
    assert e(ll) == `ll0'
    finegray x1 i.grp [fw = one], compete(status) cause(1) nolog norobust
    assert "`e(vce)'" == "oim"
    _fgwt_same e(V) `Vm0' "fw=1 norobust e(V)"
    finegray x1 i.grp [fw = one], compete(status) cause(1) nolog cluster(cl)
    assert "`e(vce)'" == "cluster"
    _fgwt_same e(V) `Vc0' "fw=1 cluster e(V)"
}
local _rc = _rc
capture restore
_fgwt_result `_rc' "WT-02 [fw=1] bit-identical: robust, norobust, cluster()"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

* -----------------------------------------------------------------------------
**# WT-03  fweight == expand: the replicated-data identity, censoring included
* -----------------------------------------------------------------------------
* Each arm below is the same estimator on two representations of the same
* data, so they agree to summation order (1e-10), never to a looser tolerance.
local ++test_count
capture noisily {
    _fgwt_data
    * -- robust
    finegray x1 i.grp [fw = fw], compete(status) cause(1) nolog basehaz
    tempname bw Vw bhw cifw
    matrix `bw' = e(b)
    matrix `Vw' = e(V)
    matrix `bhw' = e(basehaz)
    local llw = e(ll)
    local Nw = e(N)
    local Nfw = e(N_fail)
    local Ncw = e(N_compete)
    local Nzw = e(N_cens)
    local ntrw = e(N_G_trunc)
    quietly summarize fw, meanonly
    assert `Nw' == r(sum)
    quietly summarize fw if status == 1, meanonly
    assert `Nfw' == r(sum)
    quietly summarize fw if status == 2, meanonly
    assert `Ncw' == r(sum)
    quietly summarize fw if status == 0, meanonly
    assert `Nzw' == r(sum)
    finegray_cif, at(x1=0.3 grp=2) attime(0.5 1 2) ci nograph
    matrix `cifw' = r(table)
    * -- norobust
    finegray x1 i.grp [fw = fw], compete(status) cause(1) nolog norobust
    tempname Vwm
    matrix `Vwm' = e(V)
    * -- cluster
    finegray x1 i.grp [fw = fw], compete(status) cause(1) nolog cluster(cl)
    tempname Vwc
    matrix `Vwc' = e(V)

    preserve
    expand fw
    gen long id2 = _n
    quietly stset time, failure(status) id(id2)
    finegray x1 i.grp, compete(status) cause(1) nolog basehaz
    assert e(N) == `Nw'
    assert e(N_fail) == `Nfw' & e(N_compete) == `Ncw' & e(N_cens) == `Nzw'
    assert mreldif(e(b), `bw') < 1e-10
    assert mreldif(e(V), `Vw') < 1e-10
    assert reldif(e(ll), `llw') < 1e-10
    assert mreldif(e(basehaz), `bhw') < 1e-10
    * the fweighted censoring KM: same floor count as the replicated data
    assert e(N_G_trunc) == `ntrw'
    finegray_cif, at(x1=0.3 grp=2) attime(0.5 1 2) ci nograph
    assert mreldif(r(table), `cifw') < 1e-8
    finegray x1 i.grp, compete(status) cause(1) nolog norobust
    assert mreldif(e(V), `Vwm') < 1e-10
    finegray x1 i.grp, compete(status) cause(1) nolog cluster(cl)
    assert mreldif(e(V), `Vwc') < 1e-10
    restore
}
local _rc = _rc
capture restore
_fgwt_result `_rc' "WT-03 [fw=w] equals the expanded data: e(b) e(V) e(ll) counts e(basehaz) CIF table, robust/norobust/cluster"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

* -----------------------------------------------------------------------------
**# WT-04  A constant pweight is a no-op for e(b) and e(V), scales e(ll)
* -----------------------------------------------------------------------------
* S0, score and information all scale by c, the meat by c^2, so the sandwich
* c^-1 I^-1 (c^2 M) c^-1 I^-1 is the unweighted one.  The log pseudo-likelihood
* is NOT simply scaled: each event term is c [eta - log(c S0)], so
* ll_w = c (ll - N_fail log c), which is what a weighted coxph reports too.
* A weight that reached the meat but not the bread (or the reverse) fails the
* variance identity; a weight missing from the risk set fails the ll one.
local ++test_count
capture noisily {
    _fgwt_data
    finegray x1 i.grp, compete(status) cause(1) nolog
    tempname b0 V0
    matrix `b0' = e(b)
    matrix `V0' = e(V)
    local ll0 = e(ll)
    local ll00 = e(ll_0)
    local nf = e(N_fail)
    gen double cw = 2.75
    finegray x1 i.grp [pw = cw], compete(status) cause(1) nolog
    assert mreldif(e(b), `b0') < 1e-10
    assert mreldif(e(V), `V0') < 1e-10
    assert reldif(e(ll), 2.75 * (`ll0' - `nf' * ln(2.75))) < 1e-10
    assert reldif(e(ll_0), 2.75 * (`ll00' - `nf' * ln(2.75))) < 1e-10
    assert reldif(e(sum_w), 2.75 * _N) < 1e-12
    assert e(N) == _N
}
local _rc = _rc
capture restore
_fgwt_result `_rc' "WT-04 constant pweight: e(b), e(V) unchanged; e(ll) = c (ll - N_fail log c)"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

* -----------------------------------------------------------------------------
**# WT-05  pweight and fweight with the same integer weights: same e(b), different e(V)
* -----------------------------------------------------------------------------
local ++test_count
capture noisily {
    _fgwt_data
    finegray x1 i.grp [fw = fw], compete(status) cause(1) nolog
    tempname bf Vf
    matrix `bf' = e(b)
    matrix `Vf' = e(V)
    local llf = e(ll)
    finegray x1 i.grp [pw = fw], compete(status) cause(1) nolog
    * the point estimates solve the same weighted score only when the
    * censoring KM is the same, and it is NOT: pweights leave G unweighted,
    * fweights replicate it.  So e(b) differs too, unless there is no
    * censoring.  Assert the disclosure instead, and the no-censoring case
    * below (WT-06) asserts the estimating-equation identity.
    assert "`e(wtype)'" == "pweight"
    assert e(N) == _N
    assert mreldif(e(V), `Vf') > 1e-6
    _fgwt_data, censrate(0)
    quietly count if status == 0
    assert r(N) == 0
    finegray x1 i.grp [fw = fw], compete(status) cause(1) nolog
    matrix `bf' = e(b)
    matrix `Vf' = e(V)
    finegray x1 i.grp [pw = fw], compete(status) cause(1) nolog
    assert mreldif(e(b), `bf') < 1e-10
    assert mreldif(e(V), `Vf') > 1e-6
}
local _rc = _rc
capture restore
_fgwt_result `_rc' "WT-05 pweight vs fweight: same score (no censoring), different sandwich"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

* -----------------------------------------------------------------------------
**# WT-06  pweight == expand + cluster(id) when G == 1: the meat-form oracle
* -----------------------------------------------------------------------------
* Replicating subject i w_i times and clustering on i gives cluster score
* w_i s_i, meat sum_i (w_i s_i)^2, bread the weighted information, and the
* finite-sample factor g/(g-1) with g = N subjects -- exactly the pweight
* sandwich with N/(N-1).  With cluster(cl) on top, both sides sum w_i s_i
* within cl.  Needs G == 1 because the expanded censoring KM would be
* replicated while the pweight one is not; censrate(0) makes every subject
* fail from cause 1 or 2.
local ++test_count
capture noisily {
    _fgwt_data, censrate(0)
    finegray x1 i.grp [pw = fw], compete(status) cause(1) nolog basehaz
    tempname bp Vp bhp Vpc
    matrix `bp' = e(b)
    matrix `Vp' = e(V)
    matrix `bhp' = e(basehaz)
    local llp = e(ll)
    finegray x1 i.grp [pw = fw], compete(status) cause(1) nolog cluster(cl)
    matrix `Vpc' = e(V)
    preserve
    expand fw
    gen long id2 = _n
    quietly stset time, failure(status) id(id2)
    finegray x1 i.grp, compete(status) cause(1) nolog cluster(id) basehaz
    assert e(N_clust) == 600
    assert mreldif(e(b), `bp') < 1e-10
    assert mreldif(e(V), `Vp') < 1e-10
    assert mreldif(e(basehaz), `bhp') < 1e-10
    assert reldif(e(ll), `llp') < 1e-10
    finegray x1 i.grp, compete(status) cause(1) nolog cluster(cl)
    assert mreldif(e(V), `Vpc') < 1e-10
    restore
}
local _rc = _rc
capture restore
_fgwt_result `_rc' "WT-06 pweight sandwich == expanded data clustered on subject (G == 1), with and without cluster()"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

* -----------------------------------------------------------------------------
**# WT-07  Data-level refusals: aweight/iweight, negative, noninteger fweight,
**#        weight varying within id(), zero weights dropped
* -----------------------------------------------------------------------------
local ++test_count
capture noisily {
    _fgwt_data
    capture finegray x1 [aw = pw], compete(status) cause(1) nolog
    assert _rc == 101
    capture finegray x1 [iw = pw], compete(status) cause(1) nolog
    assert _rc == 101
    gen double negw = pw
    quietly replace negw = -1 in 5
    capture finegray x1 [pw = negw], compete(status) cause(1) nolog
    assert _rc == 402
    gen double fracw = fw + 0.5
    capture finegray x1 [fw = fracw], compete(status) cause(1) nolog
    assert _rc == 401
    * zero weights leave the sample, and e(N) says so
    gen double zw = pw
    quietly replace zw = 0 in 1/10
    finegray x1 [pw = zw], compete(status) cause(1) nolog
    assert e(N) == _N - 10
    quietly count if e(sample)
    assert r(N) == _N - 10
    * the weight must be constant within id() on multiple-record data
    preserve
    quietly stsplit sp, at(0.5 1)
    * stsplit blanks the failure variable on non-terminal episodes; carry the
    * subject's event type onto every episode (the documented rule)
    bysort id (_t): replace status = status[_N]
    gen double vw = pw
    quietly replace vw = pw + 1 if sp > 0
    capture finegray x1 [pw = vw], compete(status) cause(1) nolog
    assert _rc == 198
    * ... and a constant one reproduces the single-record fit exactly
    finegray x1 i.grp [pw = pw], compete(status) cause(1) nolog
    tempname bm Vm
    matrix `bm' = e(b)
    matrix `Vm' = e(V)
    local llm = e(ll)
    restore
    finegray x1 i.grp [pw = pw], compete(status) cause(1) nolog
    _fgwt_same e(b) `bm' "multi-record pw e(b)"
    _fgwt_same e(V) `Vm' "multi-record pw e(V)"
    assert e(ll) == `llm'
    * A subject only PARTIALLY in the estimation sample must not read as
    * varying.  The constancy scans compare against the first SELECTED record
    * -- the `-`touse'' key leading their gsort -- and both `_fg_w' and a
    * markout'ed covariate are MISSING on excluded records, so comparing
    * against the first record in TIME would make `abs(x - .) >= 1e-9' true
    * and flag every in-sample record of that subject.  Both scans are pinned:
    * the covariate one with the earliest episode dropped (unweighted, since a
    * weighted fit with delayed entry is refused before the scan is reached),
    * the weight one with the last episode dropped.
    preserve
    quietly stsplit sp, at(0.5 1)
    bysort id (_t): replace status = status[_N]
    quietly replace x1 = . if sp == 0 & mod(id, 7) == 0
    finegray x1 i.grp, compete(status) cause(1) nolog
    assert e(N) > 0
    restore
    preserve
    quietly stsplit sp, at(0.5 1)
    bysort id (_t): replace status = status[_N]
    * censored subjects only: dropping a FAILING subject's terminal episode
    * leaves _d == 0 with a nonzero compete(), which finegray refuses first
    quietly bysort id (_t): replace x1 = . if _n == _N & mod(id, 7) == 0 & status == 0
    finegray x1 i.grp [pw = pw], compete(status) cause(1) nolog
    assert e(N) > 0
    * ... and the scan still fires on a weight that really varies
    gen double vw2 = pw
    quietly replace vw2 = pw + 1 if sp > 0
    capture finegray x1 [pw = vw2], compete(status) cause(1) nolog
    assert _rc == 198
    restore
}
local _rc = _rc
capture restore
_fgwt_result `_rc' "WT-07 aweight/iweight r(101), negative r(402), noninteger fweight r(401), zero weights dropped, id()-varying weight r(198), multi-record reduction bit-identical"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

* -----------------------------------------------------------------------------
**# WT-08  e(refitcmd) replays the weighted estimator bit for bit
* -----------------------------------------------------------------------------
local ++test_count
capture noisily {
    _fgwt_data
    finegray x1 i.grp [pw = pw], compete(status) cause(1) nolog cluster(cl)
    tempname b1 V1
    matrix `b1' = e(b)
    matrix `V1' = e(V)
    local rc1 `"`e(refitcmd)'"'
    assert strpos(`"`rc1'"', "[pweight= pw]") > 0 | strpos(`"`rc1'"', "[pweight = pw]") > 0
    `rc1'
    _fgwt_same e(b) `b1' "refitcmd pw e(b)"
    _fgwt_same e(V) `V1' "refitcmd pw e(V)"
    finegray x1 i.grp [fw = fw], compete(status) cause(1) nolog norobust
    matrix `b1' = e(b)
    matrix `V1' = e(V)
    local rc1 `"`e(refitcmd)'"'
    assert strpos(`"`rc1'"', "fweight") > 0 & strpos(`"`rc1'"', "norobust") > 0
    `rc1'
    _fgwt_same e(b) `b1' "refitcmd fw e(b)"
    _fgwt_same e(V) `V1' "refitcmd fw e(V)"
}
local _rc = _rc
capture restore
_fgwt_result `_rc' "WT-08 e(refitcmd) carries the weight and reproduces e(b), e(V)"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

* -----------------------------------------------------------------------------
**# WT-09  Post-estimation on a weighted fit: every baseline route agrees,
**#        the analytic CIF variance is weighted, the bootstrap replays weights
* -----------------------------------------------------------------------------
local ++test_count
capture noisily {
    _fgwt_data
    finegray x1 i.grp [pw = pw], compete(status) cause(1) nolog basehaz
    tempname bh cifA cifB
    matrix `bh' = e(basehaz)
    * path 1: posted matrix
    predict double h0a, basecshazard
    predict double cifa, cif
    predict double cifac, cif ci
    finegray_cif, at(x1=0.3 grp=2) attime(0.5 1 2) ci nograph
    matrix `cifA' = r(table)
    * path 3: cold rebuild from the data (cache wiped, no e(basehaz)).  The
    * rebuild reads the data in the caller's row order while the fit scanned
    * them sorted by _t, so the risk-set sums accumulate in a different
    * floating-point order: agreement is to 1e-12, as for every cold-rebuild
    * check in this suite, not bit for bit.
    finegray x1 i.grp [pw = pw], compete(status) cause(1) nolog
    mata: mata clear
    predict double h0c, basecshazard
    assert reldif(h0c, h0a) < 1e-12
    predict double cifcc, cif ci
    assert reldif(cifcc, cifa) < 1e-12
    assert reldif(cifcc_lci, cifac_lci) < 1e-10 & reldif(cifcc_uci, cifac_uci) < 1e-10
    finegray_cif, at(x1=0.3 grp=2) attime(0.5 1 2) ci nograph
    assert mreldif(r(table), `cifA') < 1e-10
    * path 2: warm cache -- the fit's own curve, bit for bit
    finegray x1 i.grp [pw = pw], compete(status) cause(1) nolog
    predict double h0w, basecshazard
    assert h0w == h0a
    * the weighted baseline is NOT the unweighted one
    finegray x1 i.grp, compete(status) cause(1) nolog basehaz
    assert mreldif(e(basehaz), `bh') > 1e-4
    * the weighted analytic SE is not the unweighted one either
    finegray_cif, at(x1=0.3 grp=2) attime(0.5 1 2) ci nograph
    matrix `cifB' = r(table)
    assert reldif(`cifA'[2, 3], `cifB'[2, 3]) > 1e-4
    * bootstrap: every replication is a weighted refit (e(refitcmd)), and the
    * interval is finite; a cluster() fit resamples clusters
    finegray x1 i.grp [pw = pw], compete(status) cause(1) nolog
    finegray_cif, at(x1=0.3 grp=2) attime(0.5 1 2) ci bootstrap(25) seed(11) nograph
    assert r(bootstrap_success) == 25
    assert "`r(se_method)'" == "bootstrap"
    matrix `cifB' = r(table)
    assert `cifB'[2, 3] > 0 & `cifB'[2, 3] < .
    predict double cifbs, cif ci bootstrap(25) seed(11)
    assert cifbs_lci < cifbs & cifbs < cifbs_uci if cifbs > 0
    finegray x1 i.grp [pw = pw], compete(status) cause(1) nolog cluster(cl)
    finegray_cif, at(x1=0.3 grp=2) attime(1) ci bootstrap(25) seed(11) nograph
    assert r(bootstrap_success) == 25
    * Schoenfeld residuals are the weighted-risk-set ones: with a constant
    * weight they equal the unweighted residuals, with pw they differ
    finegray x1 i.grp, compete(status) cause(1) nolog
    predict double s0, schoenfeld
    finegray x1 i.grp [pw = one], compete(status) cause(1) nolog
    predict double s1, schoenfeld
    assert s1 == s0
    finegray x1 i.grp [pw = pw], compete(status) cause(1) nolog
    predict double s2, schoenfeld
    quietly count if s2 != s0 & s2 < .
    assert r(N) > 0
    * xb is the plain linear predictor, weights or not
    predict double xbw, xb
    tempname bnb
    _finegray_bnb, b(`bnb')
    gen double xbh = `bnb'[1,1] * x1 + `bnb'[1,2] * (grp == 2) + `bnb'[1,3] * (grp == 3)
    assert reldif(xbw, xbh) < 1e-12
    * margins reads e(wtype)/e(wexp) itself and runs on the weighted fit
    margins, dydx(x1)
    assert r(table)[1,1] < .
    * finegray_phtest is refused on a weighted fit
    capture finegray_phtest
    assert _rc == 198
}
local _rc = _rc
capture restore
_fgwt_result `_rc' "WT-09 weighted post-estimation: three baseline routes agree, weighted analytic CIF SE, bootstrap replays the weighted refit, schoenfeld, xb, margins, phtest refused"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

* -----------------------------------------------------------------------------
**# WT-10  A changed weight makes every data-reading post-estimation path fail
* -----------------------------------------------------------------------------
local ++test_count
capture noisily {
    _fgwt_data
    finegray x1 i.grp [pw = pw], compete(status) cause(1) nolog
    assert strpos(" `e(datasignaturevars)' ", " pw ") > 0
    quietly replace pw = pw * 2 in 1
    capture finegray_cif, at(x1=0.3 grp=2) attime(1) ci nograph
    assert _rc == 459
    capture predict double cifx, cif ci
    assert _rc == 459
    * the cache path does not read the data and still answers
    predict double cifk, cif
    assert cifk < .
    * an expression weight: the variables it names are signed too
    quietly replace pw = pw / 2 in 1
    finegray x1 i.grp [pw = 1/(0.2 + 0.5*fw)], compete(status) cause(1) nolog
    assert strpos(" `e(datasignaturevars)' ", " fw ") > 0
    assert "`e(wexp)'" == "= 1/(0.2 + 0.5*fw)"
    quietly replace fw = fw + 1 in 2
    capture finegray_cif, at(x1=0.3 grp=2) attime(1) ci nograph
    assert _rc == 459
    * A STRING variable can feed the weight through a function.  It is not a
    * numeric variable, so a `confirm numeric variable' token test drops it
    * from the signature; post-estimation then re-evaluates e(wexp) live and
    * rebuilds a DIFFERENT weight column at rc 0 -- a different baseline curve
    * and a different CIF, silently.  _datasignature signs string variables.
    quietly replace fw = fw - 1 in 2
    gen str12 sw = string(pw)
    finegray x1 i.grp [pw = real(sw)], compete(status) cause(1) nolog
    assert "`e(wexp)'" == "= real(sw)"
    assert strpos(" `e(datasignaturevars)' ", " sw ") > 0
    quietly finegray_cif, at(x1=0.3 grp=2) attime(1) ci nograph
    quietly replace sw = "5"
    capture finegray_cif, at(x1=0.3 grp=2) attime(1) ci nograph
    assert _rc == 459
    capture predict double cifs, cif ci
    assert _rc == 459
}
local _rc = _rc
capture restore
_fgwt_result `_rc' "WT-10 weight variables are in e(datasignaturevars); a changed weight is refused r(459); expression weights; string-mediated weights are signed"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

* -----------------------------------------------------------------------------
**# WT-11  Determinism and permutation invariance of a weighted fit
* -----------------------------------------------------------------------------
local ++test_count
capture noisily {
    _fgwt_data, ties
    finegray x1 i.grp [pw = pw], compete(status) cause(1) nolog basehaz
    tempname b1 V1 bh1
    matrix `b1' = e(b)
    matrix `V1' = e(V)
    matrix `bh1' = e(basehaz)
    finegray x1 i.grp [pw = pw], compete(status) cause(1) nolog basehaz
    _fgwt_same e(b) `b1' "determinism e(b)"
    _fgwt_same e(V) `V1' "determinism e(V)"
    _fgwt_same e(basehaz) `bh1' "determinism e(basehaz)"
    gen double shuf = runiform()
    sort shuf
    finegray x1 i.grp [pw = pw], compete(status) cause(1) nolog basehaz
    assert mreldif(e(b), `b1') < 1e-12
    assert mreldif(e(V), `V1') < 1e-12
    assert mreldif(e(basehaz), `bh1') < 1e-12
}
local _rc = _rc
capture restore
_fgwt_result `_rc' "WT-11 weighted fit is deterministic and permutation-invariant (tied fixture)"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

* -----------------------------------------------------------------------------
**# WT-12  The e() weight contract and the header
* -----------------------------------------------------------------------------
local ++test_count
capture noisily {
    _fgwt_data
    finegray x1 [pw = pw], compete(status) cause(1) nolog
    assert "`e(wtype)'" == "pweight"
    assert "`e(wexp)'" == "= pw"
    assert "`e(vce)'" == "robust"
    assert "`e(vce_meat)'" == "fixed_weight"
    assert "`e(lt_weight)'" == "right_censoring"
    quietly summarize pw if e(sample), meanonly
    assert reldif(e(sum_w), r(sum)) < 1e-12
    assert e(N) == r(N)
    * the header names the weight
    tempfile cap
    quietly log using "`cap'", replace text name(_fgwtcap)
    finegray
    quietly log close _fgwtcap
    tempname fh
    local saw = 0
    file open `fh' using "`cap'", read text
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`line'"', "Weights:") > 0 & strpos(`"`line'"', "pweight = pw") > 0 local saw = 1
        file read `fh' line
    }
    file close `fh'
    assert `saw' == 1
    finegray x1, compete(status) cause(1) nolog
    assert "`e(wtype)'" == ""
    assert e(sum_w) == .
}
local _rc = _rc
capture restore
_fgwt_result `_rc' "WT-12 e(wtype), e(wexp), e(sum_w), disclosure macros, header line"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

* -----------------------------------------------------------------------------
**# WT-13  e(basehaz) and finegray_cif agree under a CENSORED pweight
* -----------------------------------------------------------------------------
* The one weighted cell with no external oracle.  finegray_cif does NOT read
* e(basehaz): its curve comes from _finegray_cif_core/_cif_accum (dLm = wm :/
* S0m), while e(basehaz), `predict, cif' and `predict, basecshazard' come from
* _finegray_basehazard.  The R crossval oracles the FORMER only -- dropping
* w[idx] from the Breslow numerator in _finegray_basehazard passes
* qa/crossval_pweight.do on all four arms (measured 2026-08-29: coef 2.0e-9,
* robust SE 9.2e-9, cluster SE 1.7e-9, CIF 5.0e-9) while e(basehaz) moves in
* the first decimal.  WT-03 catches that sabotage through the fweight-equals-
* expand baseline assertion, but WT-03 is unweighted-G-free only in the
* fweight sense; the CENSORED pweight cell of _finegray_basehazard has no
* assertion of its own.
*
* This test closes it transitively.  At the reference profile xb == 0, so the
* CIF implied by the baseline is 1 - exp(-H0(t)); tying that to the
* R-cross-validated finegray_cif curve puts _finegray_basehazard's censored
* pweight arithmetic behind the R oracle without a second R arm.
*
* The probe times are MIDPOINTS between consecutive baseline jumps, never the
* jump times themselves: attime() parses through `numlist', which returns 13
* significant digits, so an event time typed at full double precision comes
* back a hair short and the step lookup answers with the PREVIOUS jump.  That
* is a property of the probe, not of the estimator, and midpoints are immune
* to it.
local ++test_count
capture noisily {
    _fgwt_data
    finegray x1 i.grp [pw = pw], compete(status) cause(1) nolog basehaz
    tempname BH
    matrix `BH' = e(basehaz)
    local K = rowsof(`BH')
    assert colsof(`BH') == 2
    assert `K' > 50
    * ~20 probe times spread over the curve
    local step = ceil(`K' / 20)
    local tlist ""
    local rows ""
    forvalues r = 1(`step')`=`K' - 1' {
        local m = (`BH'[`r', 1] + `BH'[`r' + 1, 1]) / 2
        local tlist "`tlist' `m'"
        local rows "`rows' `r'"
    }
    finegray_cif, at(x1=0 grp=1) attime(`tlist') nograph
    tempname T
    matrix `T' = r(table)
    local nprobe : word count `rows'
    assert rowsof(`T') == `nprobe'
    local maxd = 0
    local j = 0
    foreach r of local rows {
        local ++j
        local implied = 1 - exp(-`BH'[`r', 2])
        local d = reldif(`implied', `T'[`j', 2])
        if `d' > `maxd' local maxd = `d'
    }
    display as text "  WT-13 max reldif(1 - exp(-e(basehaz)), finegray_cif CIF) = " %9.2e `maxd'
    * measured 4.8e-17 (hypoxia) and 5.6e-17 (this fixture) on 2026-08-29; the
    * gate is five orders looser than that and eight orders tighter than the
    * 1e-3-and-up divergence an unweighted Breslow numerator produces
    assert `maxd' < 1e-12
    * and the same tie under fweights, where the baseline is replication-scaled
    finegray x1 i.grp [fw = fw], compete(status) cause(1) nolog basehaz
    matrix `BH' = e(basehaz)
    local K = rowsof(`BH')
    local step = ceil(`K' / 20)
    local tlist ""
    local rows ""
    forvalues r = 1(`step')`=`K' - 1' {
        local m = (`BH'[`r', 1] + `BH'[`r' + 1, 1]) / 2
        local tlist "`tlist' `m'"
        local rows "`rows' `r'"
    }
    finegray_cif, at(x1=0 grp=1) attime(`tlist') nograph
    matrix `T' = r(table)
    local maxd = 0
    local j = 0
    foreach r of local rows {
        local ++j
        local implied = 1 - exp(-`BH'[`r', 2])
        local d = reldif(`implied', `T'[`j', 2])
        if `d' > `maxd' local maxd = `d'
    }
    display as text "  WT-13 fweight max reldif = " %9.2e `maxd'
    assert `maxd' < 1e-12
}
local _rc = _rc
capture restore
_fgwt_result `_rc' "WT-13 e(basehaz) implies the finegray_cif curve under censored pweights and fweights"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

* -----------------------------------------------------------------------------
**# WT-14  The rebuilt weight is reconciled against the fit, not only signed
* -----------------------------------------------------------------------------
* e(datasignature) covers the VARIABLES a weight expression names.  A scalar,
* an e()/c() value, or a subscript such as pw[1] inside the expression is not
* a variable, so a change to it -- or, for the subscript, a re-sort -- rebuilt
* a DIFFERENT weight column at rc 0: measured 2026-08-29 (independent
* review), the CIF moved 4.6e-4 for a changed scalar and 2.4e-4 for a
* re-sorted w[1], both at rc 0.  _finegray_weight_var now reconciles the
* rebuilt column's total over e(sample) against e(sum_w) and refuses r(459)
* when it has moved.  Watched fail on the pre-reconciliation helper: the two
* `assert _rc == 459' lines below returned rc 0 there.
local ++test_count
capture noisily {
    _fgwt_data
    scalar _fgwt_k = 0.5
    finegray x1 i.grp [pw = 1/(0.2 + _fgwt_k*pw)], compete(status) cause(1) nolog
    tempname T0
    quietly finegray_cif, at(x1=0.3 grp=2) attime(1) ci nograph
    matrix `T0' = r(table)
    * an unchanged scalar: every route still answers, identically
    quietly finegray_cif, at(x1=0.3 grp=2) attime(1) ci nograph
    assert mreldif(r(table), `T0') == 0
    scalar _fgwt_k = 2
    capture finegray_cif, at(x1=0.3 grp=2) attime(1) ci nograph
    assert _rc == 459
    capture predict double cifr, cif ci
    assert _rc == 459
    capture predict double schr, schoenfeld
    assert _rc == 459
    * restoring the scalar restores the answer
    scalar _fgwt_k = 0.5
    quietly finegray_cif, at(x1=0.3 grp=2) attime(1) ci nograph
    assert mreldif(r(table), `T0') == 0
    * a subscript is order dependent: a re-sort moves the rebuilt column
    finegray x1 i.grp [pw = pw + pw[1]], compete(status) cause(1) nolog
    quietly finegray_cif, at(x1=0.3 grp=2) attime(1) ci nograph
    gen double shuf = runiform()
    sort shuf
    capture finegray_cif, at(x1=0.3 grp=2) attime(1) ci nograph
    assert _rc == 459
    * a plain variable weight survives the same re-sort: the total is
    * order invariant, so the reconciliation must not fire on it
    finegray x1 i.grp [pw = pw], compete(status) cause(1) nolog
    quietly finegray_cif, at(x1=0.3 grp=2) attime(1) ci nograph
    matrix `T0' = r(table)
    gen double shuf2 = runiform()
    sort shuf2
    quietly finegray_cif, at(x1=0.3 grp=2) attime(1) ci nograph
    assert mreldif(r(table), `T0') < 1e-12
    predict double sch2, schoenfeld
    assert sch2 < . if e(sample) & status == 1
    * fweights reconcile the same way
    finegray x1 i.grp [fw = fw], compete(status) cause(1) nolog
    quietly finegray_cif, at(x1=0.3 grp=2) attime(1) ci nograph
    matrix `T0' = r(table)
    quietly finegray_cif, at(x1=0.3 grp=2) attime(1) ci nograph
    assert mreldif(r(table), `T0') == 0
}
local _rc = _rc
capture restore
capture scalar drop _fgwt_k
_fgwt_result `_rc' "WT-14 the rebuilt weight column is reconciled against e(sum_w): changed scalar and re-sorted subscript refused r(459); variable weights unaffected"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

**# Summary
display as text _newline ///
    "RESULT: test_finegray_weights tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    capture log close _fgwt
    exit 1
}
display as result "ALL TESTS PASSED"
capture log close _fgwt
