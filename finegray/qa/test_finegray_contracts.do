* test_finegray_contracts.do
* Two internal contracts nothing else in the suite probes, plus strata edges.
*
* TWO AXES, and neither was probed before.
*
* 1. THE WEIGHT-STRATUM MAPPING, DIRECTLY.  `qa impact' reports
*    _finegray_joint_setup with qa_refs = [] -- 16 Mata callers reach it, but no
*    QA file exercises the function itself.  Everything downstream consumes its
*    jidx/jc/ju, so a wrong mapping does not error: it silently divides the wrong
*    subjects by the wrong stratum's A(t) and returns a plausible fit at rc 0.
*    The 2026-07-25 review replaced its nested `for j { for i }' scan with a binary search over
*    the ukey vector that uniqrows() already returns sorted.  JS-1..JS-5 pin the
*    OUTPUT rather than the algorithm, by differencing the shipped function
*    against a verbatim copy of the scan it replaced.
*
*    HONEST SCOPE: the two implementations are equivalent, so JS-1..JS-4 pass before and after
*    that change alike.  They are a guard for future edits, not a
*    discriminator for this one -- claiming otherwise would be the "test named
*    after the bug it cannot see" failure.  JS-5 is what shows the guard has
*    teeth: it runs a DELIBERATELY WRONG mapping through the same comparison and
*    asserts the comparison rejects it.  A guard that never fires is a comment.
*
* 2. THE DOCUMENTED FACTOR POST-ESTIMATION CONTRACT.  Through 1.2.0 the help
*    files and README said post-estimation "reconstructs factor-variable design
*    columns on demand via fvrevar", that this "requires that the current data
*    preserve the same factor-level support as the estimation sample", and that
*    "if a factor level is dropped or absent, prediction will fail with an
*    error".  All three describe the implementation that had been REPLACED,
*    precisely because pairing a re-run fvexpand with e(b) positionally could
*    mis-pair coefficients silently.  finegray_predict never calls fvrevar; it
*    rebuilds from e(fvsemantic) keyed by level VALUE.  Measured: dropping a
*    fitted level leaves finegray_predict at rc 0, scoring every remaining row.
*
*    FV-1..FV-5 pin the behaviour the corrected documentation now claims, in
*    BOTH directions -- absent fitted level succeeds, unseen level is refused --
*    so the docs cannot silently drift back. These also passed before the doc fix: the code
*    was right and the prose was wrong, so this is a documentation regression
*    guard, not a code fix. Said plainly rather than implied by a test name.
*
* 3. SINGLETON STRATA.  A censoring stratum holding ONE subject makes the
*    per-stratum vectors 1x1, where Mata cannot tell a row vector from a column
*    vector and single-subscript indexing silently changes meaning.  No fixture
*    in the suite had a singleton stratum.  The >=20-subject floor does not
*    apply here: it is enforced on DELAYED-ENTRY fits only (finegray.ado:783),
*    so a right-censoring fit may legitimately carry one.

clear all
set varabbrev off
version 16.0

capture log close _all
log using "test_finegray_contracts.log", replace name(_fg121)

local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
capture ado uninstall finegray
quietly net install finegray, from("`pkg_dir'") replace

local test_count = 0
local pass_count = 0
local fail_count = 0

* Load the Mata engine the same way every command does.
capture mata: _finegray_mata_ok()
if _rc {
    capture findfile _finegray_mata.ado
    if _rc {
        display as error "cannot locate _finegray_mata.ado"
        exit 111
    }
    run "`r(fn)'"
}

* Seeded competing-risks fixture builder.  Built at runtime rather than tracked:
* a fixture on disk cannot be re-derived if it drifts.
capture program drop _mk_fg121
program define _mk_fg121
    version 16.0
    syntax [, N(integer 900) SEED(integer 20260725) NGRP(integer 3)]
    clear
    set seed `seed'
    quietly set obs `n'
    gen long id = _n
    gen byte grp = 1 + mod(_n, `ngrp')
    gen double x1 = rnormal()
    gen double _u = runiform()
    gen double _tt = -ln(_u)/(0.20*exp(0.5*x1 + 0.4*(grp==2)))
    gen double _ct = rexponential(6)
    gen double time = min(_tt, _ct, 10)
    gen byte status = cond(_tt <= min(_ct, 10), 1, cond(_ct < min(_tt, 10), 0, 2))
    quietly replace status = 2 if runiform() < 0.25 & status == 1
    gen byte anyev = (status != 0)
    quietly drop _u _tt _ct
    stset time, failure(anyev==1) id(id)
end

**# 1. JS: _finegray_joint_setup output equivalence
* Reference = the nested scan this replaced, verbatim.  `wrong' = the same scan with
* the joint code collapsed onto the censoring stratum alone, which is what a
* plausible-looking simplification of this function would produce.
mata:
real scalar _fg121_cmp(real colvector b, real colvector u, real scalar mode)
{
    real scalar i, j, nj, n
    real colvector lc, lu, ci, ui, key, ukey, rj, rc_, ru, nj1, nj2, nj3
    lc = uniqrows(b)
    lu = uniqrows(u)
    ci = _finegray_group_index(b, lc)
    ui = _finegray_group_index(u, lu)
    n  = rows(b)
    key = (ci :- 1) :* rows(lu) :+ ui
    if (mode == 1) key = ci                 /* the deliberately WRONG mapping */
    ukey = uniqrows(key)
    nj = rows(ukey)
    rj = J(n, 1, .)
    for (j = 1; j <= nj; j++) {
        for (i = 1; i <= n; i++) if (key[i] == ukey[j]) rj[i] = j
    }
    rc_ = J(nj, 1, .)
    ru  = J(nj, 1, .)
    for (j = 1; j <= nj; j++) {
        rc_[j] = floor((ukey[j] - 1) / rows(lu)) + 1
        ru[j]  = ukey[j] - (rc_[j] - 1) * rows(lu)
    }
    _finegray_joint_setup(b, u, nj1 = ., nj2 = ., nj3 = .)
    return((rj == nj1) & (rc_ == nj2) & (ru == nj3))
}
void _fg121_sweep(real scalar mode, string scalar lname)
{
    real scalar trial, n, nc, nu, nbad
    real colvector b, u
    rseed(20260725)
    nbad = 0
    for (trial = 1; trial <= 60; trial++) {
        n  = ceil(runiform(1,1)*400) + 5
        nc = ceil(runiform(1,1)*12)
        nu = ceil(runiform(1,1)*5)
        b = ceil(runiform(n,1):*nc)
        u = ceil(runiform(n,1):*nu)
        /* adversarial shapes: missing group codes, and negative /
           non-contiguous level codes that a rank-based mapping must survive */
        if (mod(trial,7)  == 0) b[1] = .
        if (mod(trial,11) == 0) u[2] = .
        if (mod(trial,5)  == 0) b = b :* 10 :- 3
        if (!_fg121_cmp(b, u, mode)) nbad++
    }
    st_local(lname, strofreal(nbad))
}
end

* JS-1: randomized equivalence against the replaced scan.
local ++test_count
capture noisily {
    mata: _fg121_sweep(0, "_js_bad")
    display as text "  JS-1 randomized designs differing from the old scan: `_js_bad' of 60"
    assert `_js_bad' == 0
}
if _rc == 0 {
    display as result "  PASS: JS-1 joint_setup matches the replaced scan (60 designs)"
    local ++pass_count
}
else {
    display as error "  FAIL: JS-1 joint_setup equivalence (rc=`=_rc')"
    local ++fail_count
}

* JS-2: singleton strata -- every observation in its own censoring group.
local ++test_count
capture noisily {
    mata: st_local("_js2", strofreal(_fg121_cmp((1\2\3\4\5), J(5,1,1), 0)))
    assert `_js2' == 1
}
if _rc == 0 {
    display as result "  PASS: JS-2 joint_setup with all-singleton strata"
    local ++pass_count
}
else {
    display as error "  FAIL: JS-2 singleton strata (rc=`=_rc')"
    local ++fail_count
}

* JS-3: one observation, one group -- the 1x1 shape.
local ++test_count
capture noisily {
    mata: st_local("_js3", strofreal(_fg121_cmp((1), (1), 0)))
    assert `_js3' == 1
}
if _rc == 0 {
    display as result "  PASS: JS-3 joint_setup on the 1x1 degenerate shape"
    local ++pass_count
}
else {
    display as error "  FAIL: JS-3 1x1 shape (rc=`=_rc')"
    local ++fail_count
}

* JS-4: genuine cross-classification (both grouping variables vary).
local ++test_count
capture noisily {
    mata: st_local("_js4", strofreal(_fg121_cmp((1\1\2\2\3\3), (1\2\1\2\1\2), 0)))
    assert `_js4' == 1
}
if _rc == 0 {
    display as result "  PASS: JS-4 joint_setup cross-classified censoring x truncation"
    local ++pass_count
}
else {
    display as error "  FAIL: JS-4 cross-classification (rc=`=_rc')"
    local ++fail_count
}

* JS-5: the guard has teeth.  Feed the comparison a mapping that ignores the
* truncation stratum and assert it is REJECTED.  Without this, JS-1..JS-4 could
* be passing because the comparison itself is vacuous.
local ++test_count
capture noisily {
    mata: _fg121_sweep(1, "_js_wrong")
    display as text "  JS-5 designs where the WRONG mapping was rejected: `_js_wrong' of 60"
    assert `_js_wrong' > 0
}
if _rc == 0 {
    display as result "  PASS: JS-5 comparison rejects a deliberately wrong mapping"
    local ++pass_count
}
else {
    display as error "  FAIL: JS-5 guard is vacuous -- wrong mapping accepted (rc=`=_rc')"
    local ++fail_count
}

**# 2. FV: the documented factor post-estimation contract
* FV-1: a fitted level ABSENT from the current data is not an error.
local ++test_count
capture noisily {
    _mk_fg121, ngrp(3)
    quietly finegray x1 i.grp, compete(status) cause(1) nolog
    preserve
    quietly drop if grp == 3
    quietly count
    local _nleft = r(N)
    capture finegray_predict _fv1, xb
    local _fv1rc = _rc
    assert `_fv1rc' == 0
    quietly count if !missing(_fv1)
    display as text "  FV-1 rc=`_fv1rc', scored `r(N)' of `_nleft' remaining rows"
    assert r(N) == `_nleft'
    restore
}
if _rc == 0 {
    display as result "  PASS: FV-1 absent fitted level predicts at rc 0 (as documented)"
    local ++pass_count
}
else {
    display as error "  FAIL: FV-1 absent fitted level (rc=`=_rc')"
    local ++fail_count
}

* FV-2: a level the fit never saw IS refused, and with r(459) specifically.
local ++test_count
capture noisily {
    _mk_fg121, ngrp(3)
    quietly finegray x1 i.grp, compete(status) cause(1) nolog
    preserve
    quietly replace grp = 4 in 1/5
    capture finegray_predict _fv2, xb
    local _fv2rc = _rc
    display as text "  FV-2 unseen level rc = `_fv2rc' (expected 459)"
    assert `_fv2rc' == 459
    capture confirm variable _fv2
    assert _rc != 0
    restore
}
if _rc == 0 {
    display as result "  PASS: FV-2 unseen level refused r(459), no partial output"
    local ++pass_count
}
else {
    display as error "  FAIL: FV-2 unseen level refusal (rc=`=_rc')"
    local ++fail_count
}

* FV-3: finegray_predict does not call fvrevar post-estimation.  The contract is
* structural, so assert it against the SHIPPED SOURCE rather than inferring it
* from behaviour -- the docs named the mechanism, so the mechanism is the claim.
local ++test_count
capture noisily {
    local _src "`pkg_dir'/finegray_predict.ado"
    capture confirm file "`_src'"
    assert _rc == 0
    tempname _fh
    file open `_fh' using "`_src'", read text
    local _nfv = 0
    file read `_fh' _line
    while r(eof) == 0 {
        * count only executable references, not the explanatory comments
        if strpos(`"`macval(_line)'"', "fvrevar") > 0 {
            local _trim = strtrim(`"`macval(_line)'"')
            if substr(`"`_trim'"', 1, 1) != "*" local _nfv = `_nfv' + 1
        }
        file read `_fh' _line
    }
    file close `_fh'
    display as text "  FV-3 executable fvrevar references in finegray_predict.ado: `_nfv'"
    assert `_nfv' == 0
}
if _rc == 0 {
    display as result "  PASS: FV-3 finegray_predict does not call fvrevar"
    local ++pass_count
}
else {
    display as error "  FAIL: FV-3 fvrevar reference count (rc=`=_rc')"
    local ++fail_count
}

* FV-4: the absent-level prediction is not merely non-missing, it is CORRECT.
* Scoring must be unchanged for the rows that remain -- an implementation that
* re-expanded the reduced data would still return rc 0 and full coverage here,
* so FV-1 alone cannot distinguish it.  Compare against the full-data xb.
local ++test_count
capture noisily {
    _mk_fg121, ngrp(3)
    quietly finegray x1 i.grp, compete(status) cause(1) nolog
    quietly finegray_predict _xbfull, xb
    preserve
    quietly drop if grp == 3
    quietly finegray_predict _xbsub, xb
    quietly gen double _xbdiff = abs(_xbsub - _xbfull)
    quietly summarize _xbdiff, meanonly
    display as text "  FV-4 max |xb(sub) - xb(full)| on surviving rows = " %10.3e r(max)
    assert r(max) == 0
    restore
}
if _rc == 0 {
    display as result "  PASS: FV-4 surviving rows score identically after a level is dropped"
    local ++pass_count
}
else {
    display as error "  FAIL: FV-4 absent-level scoring drift (rc=`=_rc')"
    local ++fail_count
}

* FV-5: the same contract holds for finegray_cif, which rebuilds _fg_* columns
* by a different code path than finegray_predict.
local ++test_count
capture noisily {
    _mk_fg121, ngrp(3)
    quietly finegray x1 i.grp, compete(status) cause(1) nolog
    quietly finegray_cif, attime(2) at(grp=1)
    local _cif_full = r(table)[1,2]
    local _pv "`r(profile_vars)'"
    display as text "  FV-5 r(profile_vars) = `_pv'"
    * the user's vocabulary, not the internal _fg_* design-column names
    assert strpos("`_pv'", "_fg_") == 0
    assert "`_pv'" == "x1 2.grp 3.grp"
    assert `_cif_full' > 0 & `_cif_full' < 1
}
if _rc == 0 {
    display as result "  PASS: FV-5 finegray_cif reports the typed factor vocabulary"
    local ++pass_count
}
else {
    display as error "  FAIL: FV-5 finegray_cif profile_vars (rc=`=_rc')"
    local ++fail_count
}

**# 3. ST: singleton and many-level censoring strata at the command level
* ST-1: a censoring stratum holding ONE subject.  The >=20-subject floor is a
* delayed-entry guard only, so this must fit rather than error.
local ++test_count
capture noisily {
    _mk_fg121, ngrp(3)
    * carve one subject out into its own censoring stratum
    quietly gen int site = 1 + mod(_n, 2)
    quietly replace site = 99 in 1
    quietly finegray x1, compete(status) cause(1) strata(site) nolog
    assert e(converged) == 1
    display as text "  ST-1 N_weight_strata = " e(N_weight_strata)
    assert e(N_weight_strata) == 3
}
if _rc == 0 {
    display as result "  PASS: ST-1 fit with a singleton censoring stratum"
    local ++pass_count
}
else {
    display as error "  FAIL: ST-1 singleton censoring stratum (rc=`=_rc')"
    local ++fail_count
}

* ST-2: many censoring strata still reproduce the unstratified fit when the
* strata variable is pure noise w.r.t. censoring -- a coarse invariant that
* would catch a mapping error large enough to reassign subjects across strata.
local ++test_count
capture noisily {
    _mk_fg121, n(1200) ngrp(3)
    quietly finegray x1 i.grp, compete(status) cause(1) nolog
    matrix _b_un = e(b)
    quietly gen int manysite = 1 + mod(_n, 40)
    quietly finegray x1 i.grp, compete(status) cause(1) strata(manysite) nolog
    matrix _b_st = e(b)
    assert e(N_weight_strata) == 40
    local _rd = mreldif(_b_un, _b_st)
    display as text "  ST-2 mreldif(unstratified, 40-strata) = " %10.3e `_rd'
    * NOT equality: stratifying G genuinely changes the weights, so some drift
    * is correct.  The bound is 0.02 against a measured 1.09e-03 on this seeded
    * fixture -- ~18x headroom, tight enough that a mapping error large enough
    * to reassign subjects across strata would breach it.  A loose bound here
    * (0.15 was the first draft) would have made this assertion decorative.
    assert `_rd' < 0.02
}
if _rc == 0 {
    display as result "  PASS: ST-2 40-stratum fit stays close to the unstratified fit"
    local ++pass_count
}
else {
    display as error "  FAIL: ST-2 many-strata fit (rc=`=_rc')"
    local ++fail_count
}

**# Summary
display as text _newline ///
    "RESULT: test_finegray_contracts tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    log close _fg121
    exit 1
}
display as result "ALL TESTS PASSED"
log close _fg121
