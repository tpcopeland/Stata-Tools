* validation_nuisance_strata_numeric.do
* The psi term (FG 1999 eq. 7-8) under strata(): analytic psi versus a
* numerical derivative of the fitted score.
*
* WHY THIS FILE EXISTS (1.3.3).  Until 1.3.3, _finegray_psi_residuals summed
* q_g(u) over cause events FROM censoring group g only.  Ghat_g enters the
* score through the weights of group g's RETAINED competing-event subjects,
* and those subjects sit in the risk set of every later cause event, whatever
* the event subject's group -- so the cross-group terms were missing.  A
* censoring group with competing events but no cause events then carried an
* identically zero psi.  cmprsk::crr's crrvv makes the same omission
* (crr.f: qu(k, icg(j1)) accumulates only ss3(k, icg(j1))), so the crr-parity
* oracle in crossval_nuisance.do could not see it: an oracle that reaches the
* number through the same restriction is structurally blind to it.
*
* THE ORACLE HERE IS THE ESTIMATING EQUATION ITSELF.  psi_i is, by
* construction, the influence of Ghat on the score:
*
*   psi_i = int q_g(u) / Y_g(u) dM_i^c(u),   q_g(u) = dU / d lambda_g(u)
*
* where lambda_g(u) is the censoring-hazard increment of group g at u and U is
* the score.  So q_g(u) is obtained WITHOUT any of the package's psi code:
* scale Ghat_g(t) by exp(-/+ eps) for every t >= u (that is what a hazard
* increment at u does to a Kaplan-Meier), re-evaluate the package's own score
* at the fitted beta, and take the central difference.  The martingale
* integral is then formed by hand from Y_g, dN^c_g and the censoring
* indicator.  The central difference is exact to O(eps^2), so the tolerance
* is tight (1e-6 relative), not a Monte Carlo band.
*
* Times are drawn continuous and asserted DISTINCT, so the tie conventions
* (X_j < u <= t_k in the analytic form) cannot enter the comparison.
*
* ARMS.
*   N0  pooled (one censoring group): the analytic psi here is pinned to crr
*       at 1e-8 by crossval_nuisance.do, so this arm calibrates the ORACLE.
*   N1  the 2026-09-12 review fixture: two censoring groups, group 2 holds
*       competing events and censorings but no cause events.  The oracle's
*       group-2 norm must be visibly nonzero (the arm can see the defect) and
*       the analytic psi must match it.  Pre-fix: analytic group-2 psi == 0.
*   N2  two groups, cause events in both, p = 2.
*   N3  strata(cg) with bstrata(bs) on an independent variable (K = 2).
*   N4  strata(v) == bstrata(v): the separate-risk-set case; must still match.
*   N5  tvc() + strata(cg): the piecewise psi is the per-interval sum, and the
*       fix lives in the shared function every interval calls.
*   N6  public surface: e(V) from `strata(cg) nuisance' equals the sandwich
*       built from the ORACLE's psi on the N1 fixture, so a regression anywhere
*       between psi and e(V) is caught at the surface the user reads.

clear all
set varabbrev off
version 16.0

capture log close _all
log using "validation_nuisance_strata_numeric.log", replace name(_nnum)

local test_count = 0
local pass_count = 0
local fail_count = 0

* Relative tolerance on max|psi_analytic - psi_numeric| / max|psi_numeric|.
* Central differences at eps = 1e-4 carry O(eps^2) ~ 1e-8 truncation and
* ~1e-10 rounding; 1e-6 leaves two orders of headroom and is still four
* orders below the 1.6e-2 relative gap the pre-fix code shows on N1.
local TOL = 1e-6
local EPS = 1e-4

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
capture ado uninstall finegray
quietly net install finegray, from("`pkg_dir'") replace

**# Fixture generator
* Continuous times; cg = 1 + mod(_n, ng) censoring groups with group-specific
* censoring hazards, so the groups' Ghat differ.  zeroevent relabels every
* cause event in group 2 as a competing event -- the review fixture.
capture program drop _fgnn_dgp
program define _fgnn_dgp
    version 16.0
    syntax , n(integer) seed(integer) [ng(integer 2) zeroevent p2 bs]
    clear
    set seed `seed'
    quietly set obs `n'
    gen long id = _n
    gen double x1 = rnormal()
    gen double x2 = rnormal()
    gen byte cg = 1 + mod(_n, `ng')
    gen byte bs = 1 + mod(floor((_n - 1) / 3), 2)
    if "`p2'" != "" local lp2 "- 0.3 * x2"
    else            local lp2 ""
    gen double t1 = -ln(runiform()) / exp(0.4 * x1 `lp2')
    gen double t2 = -ln(runiform()) / exp(-0.4 * x1)
    gen double tc = -ln(runiform()) / exp(1.5 * (cg - 1))
    gen double t = min(t1, t2, tc)
    gen byte status = cond(t == t1, 1, cond(t == t2, 2, 0))
    if "`zeroevent'" != "" quietly replace status = 2 if cg == 2 & status == 1
    gen byte ev = status > 0
    quietly stset t, failure(ev) id(id)
    * distinct times: the tie conventions must not enter the comparison
    quietly duplicates report t
    assert r(unique_value) == `n'
    quietly count if status == 1
    assert !missing(r(N)) & r(N) > 10
end

**# Oracle
* _fgnn_score: the package's own score at beta, summed over tvc intervals,
* evaluated at a supplied (possibly perturbed) Ghat vector.
* _fgnn_numeric_psi: q_g(u) by central differences, then the martingale
* integral by hand.  No call into _finegray_psi_residuals*.
capture mata: mata drop _fgnn_score()
capture mata: mata drop _fgnn_numeric_psi()
mata:
real colvector _fgnn_score(real colvector t, real colvector d,
    real scalar cause, real scalar censval, real colvector et,
    real matrix Z, real colvector beta, real colvector G,
    real colvector g, real colvector t0, real colvector bsraw,
    real colvector ivl, real colvector fixpos, real colvector tvcpos,
    real scalar nint)
{
    real colvector tg, gidx, Gminus, Apool, U, s, etj
    real matrix Gt, Dj, I
    real scalar up, j

    tg = J(rows(t), 1, 1)
    up = 0
    gidx = Gminus = Apool = .
    Gt = .
    _finegray_prepare_weight_design(t, d, censval, et, G, g, t0, tg, up,
        gidx, Gminus, Gt, Apool)
    U = J(rows(beta), 1, 0)
    for (j = 1; j <= nint; j++) {
        if (nint > 1) {
            etj = _finegray_tvc_mask(et, cause, censval, ivl, j)
            Dj = _finegray_tvc_design(Z, fixpos, tvcpos, nint, j)
        }
        else {
            etj = et
            Dj = Z
        }
        s = .
        I = .
        _finegray_score_info(t, d, cause, censval, etj, Dj, beta, G, g,
            s, I, t0, tg, up, gidx, Gminus, Gt, Apool, bsraw)
        U = U + s
    }
    return(U)
}

real matrix _fgnn_numeric_psi(real colvector t, real colvector d,
    real scalar cause, real scalar censval, real colvector et,
    real matrix Z, real colvector beta, real colvector G,
    real colvector g, real colvector t0, real colvector bsraw,
    real colvector ivl, real colvector fixpos, real colvector tvcpos,
    real scalar nint, real scalar eps)
{
    real scalar n, ng, gg, i, k, c, u, Yg, dNc
    real colvector levels, gidx, iscens, ing, pert, ct, q, Up, Um
    real matrix psi

    n = rows(t)
    levels = uniqrows(g)
    ng = rows(levels)
    gidx = J(n, 1, .)
    for (i = 1; i <= n; i++) {
        for (k = 1; k <= ng; k++) if (g[i] == levels[k]) gidx[i] = k
    }
    iscens = (d :== 0) :| (et :== censval)
    psi = J(n, rows(beta), 0)
    for (gg = 1; gg <= ng; gg++) {
        ing = (gidx :== gg)
        ct = select(t, ing :& iscens)
        if (rows(ct) == 0) continue
        ct = uniqrows(ct)
        for (c = 1; c <= rows(ct); c++) {
            u = ct[c]
            Yg = sum(ing :& (t :>= u))
            dNc = sum(ing :& iscens :& (t :== u))
            /* a hazard increment at u moves Ghat_g(t) for every t >= u */
            pert = ing :& (t :>= u)
            Up = _fgnn_score(t, d, cause, censval, et, Z, beta,
                G :* exp(-eps :* pert), g, t0, bsraw, ivl, fixpos, tvcpos, nint)
            Um = _fgnn_score(t, d, cause, censval, et, Z, beta,
                G :* exp(eps :* pert), g, t0, bsraw, ivl, fixpos, tvcpos, nint)
            q = (Up - Um) / (2 * eps)
            /* dM_i^c(u) = dN_i^c(u) - 1(X_i >= u) dN^c_g(u) / Y_g(u) */
            for (i = 1; i <= n; i++) {
                if (!ing[i]) continue
                if (t[i] >= u) psi[i, .] = psi[i, .] - (dNc / (Yg * Yg)) * q'
                if (iscens[i] & t[i] == u) psi[i, .] = psi[i, .] + q' / Yg
            }
        }
    }
    return(psi)
}
end

* Compare after a fit.  Reads the fitted sample, builds both psi vectors and
* leaves the comparison scalars in r().  bsvar/gvar name the bstrata() /
* strata() variables ("" = none); tvc arm passes cuts and design positions.
capture program drop _fgnn_compare
program define _fgnn_compare, rclass
    version 16.0
    syntax , zvars(varlist) eps(real) ///
        [gvar(name) bsvar(name) cuts(numlist) tvcpos(integer 0)]
    tempvar one samp
    quietly gen byte `one' = 1
    quietly gen byte `samp' = e(sample)
    if "`gvar'" == ""  local gvar `one'
    if "`bsvar'" == "" local bsvar `one'
    mata: _fgnn_run("_t", "_d", "_t0", "`e(compete)'", "`zvars'", "`gvar'", ///
        "`bsvar'", "`samp'", `=e(cause)', `=e(censvalue)', "`cuts'", ///
        `tvcpos', `eps')
    return scalar maxdiff = maxdiff
    return scalar maxnum  = maxnum
    return scalar score   = scoremax
    return scalar norm_g2_num = norm_g2_num
    return scalar norm_g2_an  = norm_g2_an
end

capture mata: mata drop _fgnn_run()
mata:
void _fgnn_run(string scalar tv, string scalar dv, string scalar t0v,
    string scalar ev, string scalar zv, string scalar gv, string scalar bv,
    string scalar samp, real scalar cause, real scalar censval, string scalar cutstr,
    real scalar tvcp, real scalar eps)
{
    real colvector t, d, t0, et, g, bs, beta, G, ivl, fixpos, tvcpos, cuts
    real matrix Z, pa, pn, eta, I
    real scalar n, p, nint, i, j, one
    real colvector s, tg

    t  = st_data(., tv, samp)
    d  = st_data(., dv, samp)
    t0 = st_data(., t0v, samp)
    et = st_data(., ev, samp)
    Z  = st_data(., tokens(zv), samp)
    g  = st_data(., gv, samp)
    bs = st_data(., bv, samp)
    beta = st_matrix("e(b)")'
    n = rows(t)
    p = cols(Z)
    if (cutstr == "") {
        cuts = J(0, 1, .)
        nint = 1
        ivl = J(n, 1, 1)
        fixpos = (1::p)
        tvcpos = J(0, 1, .)
    }
    else {
        cuts = strtoreal(tokens(cutstr))'
        nint = rows(cuts) + 1
        ivl = _finegray_tvc_interval(t, cuts)
        tvcpos = J(1, 1, tvcp)
        fixpos = J(0, 1, .)
        for (i = 1; i <= p; i++) if (i != tvcp) fixpos = fixpos \ i
    }
    G = _finegray_km_censor(t, d, censval, et, g, t0, 1)
    /* the oracle differentiates the SAME estimating equation the fit solved */
    s = _fgnn_score(t, d, cause, censval, et, Z, beta, G, g, t0, bs,
        ivl, fixpos, tvcpos, nint)
    st_numscalar("scoremax", max(abs(s)))
    if (nint > 1) {
        pa = _finegray_psi_residuals_pw(t, d, cause, censval, et, Z, beta,
            G, g, t0, bs, ivl, fixpos, tvcpos, nint)
    }
    else {
        pa = _finegray_psi_residuals(t, d, cause, censval, et, Z, beta,
            G, g, t0, bs)
    }
    pn = _fgnn_numeric_psi(t, d, cause, censval, et, Z, beta, G, g, t0, bs,
        ivl, fixpos, tvcpos, nint, eps)
    st_numscalar("maxdiff", max(abs(pa - pn)))
    st_numscalar("maxnum", max(abs(pn)))
    st_numscalar("norm_g2_num", sqrt(sum(select(pn, g :== 2):^2)))
    st_numscalar("norm_g2_an",  sqrt(sum(select(pa, g :== 2):^2)))
    /* sandwich from the ORACLE's psi, for the public-surface arm (plain
       fits only: eta and the information are the unmasked ones) */
    if (nint == 1) {
        tg = J(n, 1, 1)
        s = .
        I = .
        _finegray_score_info(t, d, cause, censval, et, Z, beta, G, g, s, I,
            t0, tg)
        eta = _finegray_score_residuals(t, d, cause, censval, et, Z, beta,
            G, g, t0, tg)
        st_matrix("Vnum", invsym(I) * cross(eta + pn, eta + pn) * invsym(I) *
            n / (n - 1))
    }
}
end

**# N0. pooled: calibrates the oracle against the crr-pinned analytic psi
local ++test_count
capture noisily {
    _fgnn_dgp, n(200) seed(39127) ng(1)
    quietly finegray x1, compete(status) cause(1) nuisance nolog
    assert e(converged) == 1
    _fgnn_compare, zvars(x1) eps(`EPS')
    display as text "    N0 pooled: |score|=" %9.2e r(score) ///
        "  max|psi_a - psi_n|=" %9.2e r(maxdiff) "  max|psi_n|=" %9.2e r(maxnum)
    assert !missing(r(score), r(maxnum), r(maxdiff))
    assert r(score) < 1e-6
    assert r(maxnum) > 1e-3
    assert r(maxdiff) / r(maxnum) < `TOL'
}
if _rc == 0 {
    display as result "  PASS: N0 pooled analytic psi equals the score derivative (calibrates the oracle)"
    local ++pass_count
}
else {
    display as error "  FAIL: N0 pooled psi vs score derivative (rc=`=_rc')"
    local ++fail_count
}

**# N1. review fixture: group 2 has competing events and censorings, no cause events
local ++test_count
capture noisily {
    _fgnn_dgp, n(200) seed(39127) ng(2) zeroevent
    quietly count if cg == 2 & status == 1
    assert r(N) == 0
    quietly count if cg == 2 & status == 2
    assert !missing(r(N)) & r(N) > 10
    quietly finegray x1, compete(status) cause(1) strata(cg) nuisance nolog
    assert e(converged) == 1
    _fgnn_compare, zvars(x1) gvar(cg) eps(`EPS')
    display as text "    N1 zero-event group: |score|=" %9.2e r(score) ///
        "  max|psi_a - psi_n|=" %9.2e r(maxdiff) "  max|psi_n|=" %9.2e r(maxnum)
    display as text "    group-2 psi norm: analytic=" %9.6f r(norm_g2_an) ///
        "  numeric=" %9.6f r(norm_g2_num)
    assert !missing(r(score), r(maxnum), r(maxdiff), r(norm_g2_num), r(norm_g2_an))
    assert r(score) < 1e-6
    * the arm can see the defect: the derivative through group 2 is not zero
    assert r(norm_g2_num) > 0.01
    * pre-1.3.3 this was exactly 0
    assert r(norm_g2_an) > 0.01
    assert r(maxdiff) / r(maxnum) < `TOL'
    matrix Vfit = e(V)
}
if _rc == 0 {
    display as result "  PASS: N1 a censoring group without cause events carries its cross-group psi"
    local ++pass_count
}
else {
    display as error "  FAIL: N1 zero-cause-event censoring group psi (rc=`=_rc')"
    local ++fail_count
}

**# N6. public surface: e(V) equals the sandwich built from the oracle's psi
local ++test_count
capture noisily {
    * Vnum was left by the N1 comparison (plain fit, same data)
    assert mreldif(Vfit, Vnum) < `TOL'
    display as text "    N6 e(V)=" %12.9f Vfit[1,1] "  oracle=" %12.9f Vnum[1,1]
}
if _rc == 0 {
    display as result "  PASS: N6 e(V) under strata() nuisance equals the score-derivative sandwich"
    local ++pass_count
}
else {
    display as error "  FAIL: N6 e(V) vs score-derivative sandwich (rc=`=_rc')"
    local ++fail_count
}

**# N2. two groups, cause events in both, p = 2
local ++test_count
capture noisily {
    _fgnn_dgp, n(240) seed(4471) ng(2) p2
    quietly count if cg == 2 & status == 1
    assert !missing(r(N)) & r(N) > 10
    quietly finegray x1 x2, compete(status) cause(1) strata(cg) nuisance nolog
    assert e(converged) == 1
    _fgnn_compare, zvars(x1 x2) gvar(cg) eps(`EPS')
    display as text "    N2 two groups p=2: |score|=" %9.2e r(score) ///
        "  max|psi_a - psi_n|=" %9.2e r(maxdiff) "  max|psi_n|=" %9.2e r(maxnum)
    assert !missing(r(score), r(maxnum), r(maxdiff))
    assert r(score) < 1e-6
    assert r(maxdiff) / r(maxnum) < `TOL'
    assert mreldif(e(V), Vnum) < `TOL'
}
if _rc == 0 {
    display as result "  PASS: N2 two censoring groups, cause events in both, p = 2"
    local ++pass_count
}
else {
    display as error "  FAIL: N2 two censoring groups p = 2 (rc=`=_rc')"
    local ++fail_count
}

**# N3. strata(cg) with an independent bstrata(bs)
local ++test_count
capture noisily {
    _fgnn_dgp, n(300) seed(9013) ng(2) p2
    quietly finegray x1 x2, compete(status) cause(1) strata(cg) bstrata(bs) nuisance nolog
    assert e(converged) == 1
    assert e(k_bstrata) == 2
    _fgnn_compare, zvars(x1 x2) gvar(cg) bsvar(bs) eps(`EPS')
    display as text "    N3 strata+bstrata: |score|=" %9.2e r(score) ///
        "  max|psi_a - psi_n|=" %9.2e r(maxdiff) "  max|psi_n|=" %9.2e r(maxnum)
    assert !missing(r(score), r(maxnum), r(maxdiff))
    assert r(score) < 1e-6
    assert r(maxdiff) / r(maxnum) < `TOL'
}
if _rc == 0 {
    display as result "  PASS: N3 strata(cg) with independent bstrata(bs)"
    local ++pass_count
}
else {
    display as error "  FAIL: N3 strata(cg) with bstrata(bs) (rc=`=_rc')"
    local ++fail_count
}

**# N4. strata(v) == bstrata(v): separate risk sets
local ++test_count
capture noisily {
    _fgnn_dgp, n(300) seed(2207) ng(2) p2
    quietly finegray x1 x2, compete(status) cause(1) strata(cg) bstrata(cg) nuisance nolog
    assert e(converged) == 1
    _fgnn_compare, zvars(x1 x2) gvar(cg) bsvar(cg) eps(`EPS')
    display as text "    N4 strata==bstrata: |score|=" %9.2e r(score) ///
        "  max|psi_a - psi_n|=" %9.2e r(maxdiff) "  max|psi_n|=" %9.2e r(maxnum)
    assert !missing(r(score), r(maxnum), r(maxdiff))
    assert r(score) < 1e-6
    assert r(maxdiff) / r(maxnum) < `TOL'
}
if _rc == 0 {
    display as result "  PASS: N4 strata(v) == bstrata(v) still matches the score derivative"
    local ++pass_count
}
else {
    display as error "  FAIL: N4 strata(v) == bstrata(v) (rc=`=_rc')"
    local ++fail_count
}

**# N5. tvc() + strata(cg): the piecewise psi
local ++test_count
capture noisily {
    _fgnn_dgp, n(300) seed(7301) ng(2) p2
    quietly _pctile t if status == 1, p(33 67)
    local c1 : display %6.4f r(r1)
    local c2 : display %6.4f r(r2)
    quietly finegray x1 x2, compete(status) cause(1) tvc(x1) tsplit(`c1' `c2') ///
        strata(cg) nuisance nolog
    assert e(converged) == 1
    assert e(n_intervals) == 3
    _fgnn_compare, zvars(x1 x2) gvar(cg) cuts(`c1' `c2') tvcpos(1) eps(`EPS')
    display as text "    N5 tvc+strata: |score|=" %9.2e r(score) ///
        "  max|psi_a - psi_n|=" %9.2e r(maxdiff) "  max|psi_n|=" %9.2e r(maxnum)
    assert !missing(r(score), r(maxnum), r(maxdiff))
    assert r(score) < 1e-6
    assert r(maxdiff) / r(maxnum) < `TOL'
}
if _rc == 0 {
    display as result "  PASS: N5 tvc() + strata(cg) piecewise psi matches the score derivative"
    local ++pass_count
}
else {
    display as error "  FAIL: N5 tvc() + strata(cg) (rc=`=_rc')"
    local ++fail_count
}

**# Summary
display as text _newline ///
    "RESULT: validation_nuisance_strata_numeric tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    log close _nnum
    exit 1
}
display as result "ALL TESTS PASSED"
log close _nnum
