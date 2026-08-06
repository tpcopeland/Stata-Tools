* =============================================================================
* _iivw_cr_ladder.do - CR0/CR1S/CR2/CR3 cluster-robust variance ladder
* =============================================================================
* WHAT THIS IS
* ------------
* A Mata implementation of the clubSandwich cluster-robust variance ladder for a
* weighted linear (identity-link, Gaussian) fit, so that the ladder can be
* evaluated inside a Stata simulation without a per-replication round trip to R.
*
* It exists for `probe_cr_ladder.do' (se_recovery.md section 13.2): read the
* SCALE axis of the FIPTIW interval deficit with the degrees-of-freedom term
* removed, i.e. every rung is paired with a z critical value, never with
* Satterthwaite df.
*
* THE FORMULAS ARE TRANSCRIBED FROM THE REFERENCE IMPLEMENTATION, NOT FROM
* RECALL. Source: clubSandwich 0.6.2 (installed at /usr/lib/R/site-library),
* internal functions `vcov_CR', `adjust_est_mats', `IH_jj_list', `matrix_power',
* `CR1S', `CR2', `CR3', `weightMatrix.default', `targetVariance.default'.
* Definitions cross-checked against the package reference page
* (jepusto.github.io/clubSandwich/reference/vcovCR.html), which cites
* Pustejovsky & Tipton (2017/2018) for CR2 and Bell & McCaffrey (2002) for CR3.
* `test_iivw_cr_ladder.do' proves the transcription numerically against
* clubSandwich itself; this file is not to be trusted without that test.
*
* WITH the configuration used here -- an lm-like weighted fit, no augmented
* model matrix, `inverse_var = FALSE', and the default target -- clubSandwich
* takes Theta_g = I (identity working variance) and the ladder reduces to:
*
*   B        = (X' W X)^-1                       (W = diag(w), the bread)
*   XW_g     = X_g' W_g                          (p x n_g estimating matrix)
*   H_g      = X_g B XW_g                        (n_g x n_g leverage block)
*   CR0      : E_g = XW_g
*   CR1      : E_g = XW_g * sqrt( m / (m-1) )                 m = # clusters
*   CR1S     : E_g = XW_g * sqrt( m(N-1) / ((m-1)(N-p)) )
*   CR2      : E_g = XW_g A_g,  A_g = G_g^(-1/2),
*              G_g = I - H_g - H_g' + X_g B (sum_h XW_h XW_h') B X_g'
*   CR3      : E_g = XW_g (I - H_g)^-1
*   V        = B ( sum_g E_g e_g e_g' E_g' ) B
*
* G_g^(-1/2) is the SYMMETRIC power: eigendecompose, raise eigenvalues above
* 1e-12 to -1/2 and set the rest to 0 (clubSandwich `matrix_power', tol = -12).
*
* Every quantity above is invariant to rescaling w by a constant, which is why
* this file uses the raw weights where clubSandwich normalizes them by their
* mean and multiplies the scale back in afterwards.
*
* Usage:
*   do "`qa_dir'/_iivw_cr_ladder.do"
*   iivw_cr_ladder y A if e(sample), clustervar(id) weightvar(_iivw_weight)
*   -> r(b) r(se_cr0) r(se_cr1) r(se_cr1s) r(se_cr2) r(se_cr3)
*      r(nclust) r(nobs) r(maxlev) r(n_singular)
*
* CR1 is on the ladder because it is the rung `iivw_fit, vce(fixed)' actually
* ships: `glm [pw=], vce(cluster)' multiplies by m/(m-1), not by CR1S's
* m(N-1)/((m-1)(N-p)). Measured, not assumed -- `test_iivw_cr_ladder.do' C4
* pins it, and without that rung every inflation factor would be quoted against
* a baseline the package does not use.
*
* r(maxlev) is the largest diagonal leverage encountered and r(n_singular) the
* number of clusters whose (I - H_g) could not be inverted -- both are CR3
* blow-up tells, and a run that ignores them can report a finite mean SE built
* out of a few enormous ones.
*
* The varlist is depvar followed by the covariates; a constant is appended, and
* the FIRST covariate is the coefficient whose SEs are returned.
* =============================================================================

version 16.0

capture mata: mata drop _iivw_cr_matpow()
capture mata: mata drop _iivw_cr_bounds()
capture mata: mata drop _iivw_cr_run()

mata:
mata set matastrict on

// Symmetric matrix power, clubSandwich matrix_power() with tol = -12.
real matrix _iivw_cr_matpow(real matrix x, real scalar pw)
{
    real matrix V, Sym
    real rowvector L
    real colvector Lp
    real scalar j

    Sym = (x + x') / 2
    symeigensystem(Sym, V, L)
    Lp = J(cols(L), 1, 0)
    for (j = 1; j <= cols(L); j++) {
        if (L[j] > 1e-12) Lp[j] = L[j]^pw
    }
    return(V * (Lp :* V'))
}

// Start/end row of each cluster. Requires cl sorted ascending.
real matrix _iivw_cr_bounds(real colvector cl)
{
    real matrix bnd
    real scalar i, lo, n

    n = rows(cl)
    bnd = J(0, 2, .)
    lo = 1
    for (i = 2; i <= n; i++) {
        if (cl[i] != cl[i-1]) {
            bnd = bnd \ (lo, i - 1)
            lo = i
        }
    }
    bnd = bnd \ (lo, n)
    return(bnd)
}

void _iivw_cr_run(string scalar yv, string scalar xv, string scalar wv,
                  string scalar cv, string scalar tousev)
{
    real matrix X, Bread, Ssum, MWM, bnd, Xg, XWg, Hg, Gg, Ag, IHg, IHinv
    real matrix meat0, meat2, meat3, V0, V2, V3
    real colvector y, w, sw, cl, e, b, eg, wg, c0, c2, c3
    real scalar N, p, m, g, lo, hi, ng, cr1, cr1s, maxlev, nsing

    y  = st_data(., yv, tousev)
    X  = st_data(., tokens(xv), tousev)
    w  = st_data(., wv, tousev)
    cl = st_data(., cv, tousev)
    X  = X, J(rows(X), 1, 1)

    N     = rows(X)
    p     = cols(X)
    Bread = invsym(quadcross(X, w, X))

    // b via QR on the sqrt(w)-scaled design, not via the normal equations.
    // Solving Bread * X'Wy squares the condition number, and measured against
    // R's lm (which is QR) that cost about 1.5e-8 relative on the FIPTIW
    // fixture -- small, but it propagates into every residual and therefore
    // into every rung of the ladder.
    sw = sqrt(w)
    b  = qrsolve(X :* sw, y :* sw)
    e  = y - X * b

    bnd = _iivw_cr_bounds(cl)
    m   = rows(bnd)
    if (m < 2) _error(459, "cluster-robust variance needs at least 2 clusters")

    // Pass 1: sum_h XW_h Theta_h XW_h' with Theta_h = I.
    Ssum = J(p, p, 0)
    for (g = 1; g <= m; g++) {
        lo = bnd[g,1]; hi = bnd[g,2]
        Xg   = X[lo..hi, .]
        wg   = w[lo..hi]
        XWg  = Xg' :* wg'
        Ssum = Ssum + XWg * XWg'
    }
    MWM = Bread * Ssum * Bread

    // Pass 2: the three meats (CR1S is a scalar multiple of CR0).
    meat0  = J(p, p, 0)
    meat2  = J(p, p, 0)
    meat3  = J(p, p, 0)
    maxlev = 0
    nsing  = 0
    for (g = 1; g <= m; g++) {
        lo = bnd[g,1]; hi = bnd[g,2]
        ng  = hi - lo + 1
        Xg  = X[lo..hi, .]
        wg  = w[lo..hi]
        eg  = e[lo..hi]
        XWg = Xg' :* wg'
        Hg  = Xg * Bread * XWg
        if (max(diagonal(Hg)) > maxlev) maxlev = max(diagonal(Hg))

        Gg  = I(ng) - Hg - Hg' + Xg * MWM * Xg'
        Ag  = _iivw_cr_matpow(Gg, -0.5)
        IHg = I(ng) - Hg

        // luinv() returns a matrix of missings on a singular argument rather
        // than erroring, so a blown-up cluster would otherwise poison the sum
        // silently. Count it and leave CR3 missing for the whole dataset.
        IHinv = luinv(IHg)
        if (hasmissing(IHinv)) nsing = nsing + 1

        c0 = XWg * eg
        c2 = (XWg * Ag) * eg
        c3 = (XWg * IHinv) * eg

        meat0 = meat0 + c0 * c0'
        meat2 = meat2 + c2 * c2'
        if (nsing == 0) meat3 = meat3 + c3 * c3'
    }

    V0 = Bread * meat0 * Bread
    V2 = Bread * meat2 * Bread
    V3 = Bread * meat3 * Bread
    cr1  = m / (m - 1)
    cr1s = m * (N - 1) / ((m - 1) * (N - p))

    st_numscalar("__iivw_cr_b",       b[1])
    st_numscalar("__iivw_cr_se0",     sqrt(V0[1,1]))
    st_numscalar("__iivw_cr_se1",     sqrt(cr1 * V0[1,1]))
    st_numscalar("__iivw_cr_se1s",    sqrt(cr1s * V0[1,1]))
    st_numscalar("__iivw_cr_se2",     sqrt(V2[1,1]))
    st_numscalar("__iivw_cr_se3",     nsing > 0 ? . : sqrt(V3[1,1]))
    st_numscalar("__iivw_cr_m",       m)
    st_numscalar("__iivw_cr_n",       N)
    st_numscalar("__iivw_cr_maxlev",  maxlev)
    st_numscalar("__iivw_cr_nsing",   nsing)
}
end

capture program drop iivw_cr_ladder
program define iivw_cr_ladder, rclass
    version 16.0
    syntax varlist(min=2 numeric) [if] [in], CLUSTERvar(varname) WEIGHTVar(varname)

    marksample touse
    markout `touse' `varlist' `clustervar' `weightvar'
    quietly count if `touse'
    if r(N) == 0 {
        display as error "iivw_cr_ladder: no observations"
        exit 2000
    }

    gettoken depvar covars : varlist
    if "`covars'" == "" {
        display as error "iivw_cr_ladder: needs at least one covariate"
        exit 198
    }

    * The Mata code walks clusters as contiguous row blocks, so the data must be
    * in cluster order. Sorting is not optional and is not the caller's job:
    * an unsorted call would silently split one subject into many "clusters"
    * and return a variance that is too small, at rc 0.
    tempvar order
    quietly generate long `order' = _n
    sort `clustervar' `order'

    mata: _iivw_cr_run("`depvar'", "`covars'", "`weightvar'", ///
        "`clustervar'", "`touse'")

    sort `order'

    return scalar b         = scalar(__iivw_cr_b)
    return scalar se_cr0    = scalar(__iivw_cr_se0)
    return scalar se_cr1    = scalar(__iivw_cr_se1)
    return scalar se_cr1s   = scalar(__iivw_cr_se1s)
    return scalar se_cr2    = scalar(__iivw_cr_se2)
    return scalar se_cr3    = scalar(__iivw_cr_se3)
    return scalar nclust    = scalar(__iivw_cr_m)
    return scalar nobs      = scalar(__iivw_cr_n)
    return scalar maxlev    = scalar(__iivw_cr_maxlev)
    return scalar n_singular = scalar(__iivw_cr_nsing)

    scalar drop __iivw_cr_b __iivw_cr_se0 __iivw_cr_se1 __iivw_cr_se1s ///
        __iivw_cr_se2 __iivw_cr_se3 __iivw_cr_m __iivw_cr_n ///
        __iivw_cr_maxlev __iivw_cr_nsing
end
