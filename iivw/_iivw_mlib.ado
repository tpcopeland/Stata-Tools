*! _iivw_mlib Version 1.0.2  2026/10/30
*! iivw's Mata source. Contains NO Stata program: this file is -run-, never
*! autoloaded.
*! Author: Timothy P Copeland, Karolinska Institutet

* Why this file defines no program
* --------------------------------
* Stata's ado autoloader does not EXECUTE an ado file. It reads it far enough to
* define the program being called, and nothing else in the file runs -- so a
* -mata:- block in an ado file is never compiled by an autoload, whether it sits
* above or below the program. Measured, not assumed: -run- on this file compiles
* _iivw_stacked_nest() and calling an autoloaded program in the same file leaves
* -mata: mata describe- empty.
*
* So the Mata has to be -run- explicitly, and the file must therefore contain no
* program at all. An earlier shape paired the block with a trivial program so
* that calling it would trigger the load; the call loaded the file without
* compiling anything, and the recovery -run- then failed with "program
* _iivw_mlib already defined" because the autoload had defined it. Removing the
* program removes both failures: there is nothing to autoload and nothing to
* redefine.
*
* _iivw_stacked_vce.ado owns the guard that runs this file, and re-runs it after
* anything (-discard-, -mata: mata clear-) drops the functions.

version 16.0

mata:

// Two-step (stacked) influence-function sandwich for a weighted GEE fit.
// Derivation, sources and sign convention: see _iivw_stacked_vce.ado.
//
//   D    = sum_j w_j v(mu_j) x_j x_j'                        (bread)
//   U_i  = sum_{j in i} w_j x_j (y_j - mu_j)                 (fixed score)
//   G    = sum_j w_j (y_j - mu_j) x_j (dlog w_j/dtheta)'     (cross-derivative)
//   psi_i = U_i + G A^-1 s_i                                 (corrected score)
//   V    = D^-1 (sum_i psi_i psi_i') D^-1 * m/(m-1)
//
// Two row sets. The outcome sample (tousevar) carries D, U and G. The nuisance
// population (nusevar) -- every subject whose rows fed the weight models, a
// superset of the outcome sample -- carries s_i. A subject outside the outcome
// sample has U_i = 0 but generally s_i != 0, and its G A^-1 s_i term is part
// of the two-step influence function (B&L PDF p.10-11; Coulombe App. A.3,
// printed p.153-155). m counts that union; the fixed sandwich keeps the
// outcome-sample count so it still reproduces glm's own vce(cluster).
//
// Clusters may hold several subjects (cluster() above the subject). The
// nuisance score is a per-SUBJECT quantity, so a cluster's contribution is the
// sum of its subjects' scores, each counted once. With the subject equal to
// the cluster this is the subject-level formula exactly. A subject whose rows
// sit in two clusters is not nested and is refused: the clusters would not be
// independent units.
//
// Renamed from _iivw_stacked_core() when the second row set was added, and
// from _iivw_stacked_union() when the subject index was, so a session still
// holding an old compiled signature recompiles instead of calling it with the
// wrong arguments.
void _iivw_stacked_nest(string scalar xvars,
                        string scalar breadvar,
                        string scalar resvar,
                        string scalar ndvars,
                        string scalar nsvars,
                        string scalar cidxvar,
                        string scalar sidxvar,
                        string scalar tousevar,
                        string scalar nusevar,
                        string scalar ainvname,
                        real scalar M,
                        real scalar Mout,
                        string scalar vsname,
                        string scalar vfname,
                        string scalar gname)
{
    real matrix X, ND, NS, D, Dinv, G, Ainv, Ufix, Ustk, Vs, Vf, S, SS
    real colvector BW, R, C, CN, SN, SC
    real scalar j, k, N, p, q, cf, cfout, dev, worst, nsplit

    st_view(X = .,  ., tokens(xvars),   tousevar)
    st_view(BW = ., ., breadvar,        tousevar)
    st_view(R = .,  ., resvar,          tousevar)
    st_view(ND = ., ., tokens(ndvars),  tousevar)
    st_view(C = .,  ., cidxvar,         tousevar)
    st_view(NS = ., ., tokens(nsvars),  nusevar)
    st_view(CN = ., ., cidxvar,         nusevar)
    st_view(SN = ., ., sidxvar,         nusevar)

    N = rows(X)
    p = cols(X)
    q = cols(ND)
    Ainv = st_matrix(ainvname)

    D = quadcross(X, BW, X)
    G = quadcross(X, R, ND)

    // Per-cluster sums of the outcome score, and the per-cluster value of the
    // nuisance score.
    //
    // The nuisance score is subject-CONSTANT by construction: the Cox score is
    // summed within subject before it is broadcast, and the propensity score is
    // merged m:1 from a one-row-per-subject fit. So its cluster contribution is
    // a REPRESENTATIVE value, never a total over rows. Totalling a
    // subject-constant column over a subject's rows multiplies it by that
    // subject's visit count -- which would weight every correction by follow-up
    // intensity, the exact quantity the weights exist to remove.
    //
    // That constancy is asserted rather than trusted, because it is the one
    // assumption here a user could break by editing a column, and breaking it
    // silently produces a plausible wrong variance.
    Ufix = J(M, p, 0)
    SS   = J(max(SN), q, .)
    SC   = J(max(SN), 1, .)
    worst = 0
    nsplit = 0
    for (j = 1; j <= N; j++) {
        Ufix[C[j], .] = Ufix[C[j], .] + X[j, .] :* R[j]
    }
    // One representative score per subject, and the one cluster it sits in.
    for (j = 1; j <= rows(NS); j++) {
        k = SN[j]
        if (SC[k] == .) {
            SS[k, .] = NS[j, .]
            SC[k]    = CN[j]
        }
        else {
            if (SC[k] != CN[j]) nsplit++
            dev = mreldif(SS[k, .], NS[j, .])
            if (dev > worst) worst = dev
        }
    }
    if (nsplit > 0) {
        errprintf("stacked variance: subjects are not nested within clusters\n")
        errprintf("  a subject's rows fall in more than one cluster() value;\n")
        errprintf("  vce(stacked) needs every subject inside one cluster\n")
        exit(459)
    }
    if (hasmissing(SS) | hasmissing(SC)) {
        errprintf("stacked variance: a subject has no nuisance score row\n")
        exit(459)
    }
    if (worst > 1e-10) {
        errprintf("stacked variance: the nuisance score columns are not")
        errprintf(" constant within subject\n")
        errprintf("  worst within-subject relative difference %g\n", worst)
        errprintf("  re-run iivw_weight, scores\n")
        exit(459)
    }
    // A cluster's nuisance contribution is the sum over its subjects.
    S = J(M, q, 0)
    for (k = 1; k <= rows(SS); k++) {
        S[SC[k], .] = S[SC[k], .] + SS[k, .]
    }

    Ustk = Ufix + S * (Ainv * G')

    Dinv = invsym(D)
    if (diag0cnt(Dinv) > 0) {
        errprintf("stacked variance: the weighted design matrix is singular\n")
        exit(506)
    }

    // CR1 finite-cluster adjustment: the same m/(m-1) that glm's vce(cluster)
    // applies, and therefore the one iivw_fit, vce(fixed) already reports.
    // Measured, not assumed -- the CR-ladder probe identified vce(fixed) as the
    // CR1 rung to 2.2e-15 (coverage_results/CR_LADDER_2026-08-06.md). Using a
    // different adjustment here would make the stacked and fixed standard
    // errors differ by a factor that has nothing to do with the correction.
    cf    = M / (M - 1)
    cfout = Mout / (Mout - 1)

    Vf = Dinv * quadcross(Ufix, Ufix) * Dinv * cfout
    Vs = Dinv * quadcross(Ustk, Ustk) * Dinv * cf

    st_matrix(vsname, makesymmetric(Vs))
    st_matrix(vfname, makesymmetric(Vf))
    st_matrix(gname, G)
}

// Wald tests of the exogeneity lags on the SD-scaled coefficients: bs = b*sd,
// Vs = V .* (sd'sd). invsym() drops a direction whose variance falls below
// an absolute tolerance; on the scaled covariance that tolerance measures
// information, not units, and chi2 = bs' Vs^- bs equals b' V^- b whenever no
// direction is dropped. Sets locals __iivw_wchi2 (%21x), __iivw_wdf (rank),
// and __iivw_tdf_k (1 when lag k alone is testable).
void _iivw_exog_wald(string scalar bn, string scalar vn, string scalar names,
    string scalar sds)
{
    real rowvector b, sd, idx, bs
    real matrix V, Vs, Vi
    string rowvector cn, nm
    real scalar k, j, rk, W

    b = st_matrix(bn)
    V = st_matrix(vn)
    cn = st_matrixcolstripe(bn)[., 2]'
    for (j = 1; j <= cols(cn); j++) {
        if (substr(cn[j], 1, 2) == "o.") cn[j] = substr(cn[j], 3, .)
    }
    nm = tokens(names)
    sd = strtoreal(tokens(sds))
    idx = J(1, cols(nm), .)
    for (k = 1; k <= cols(nm); k++) {
        for (j = 1; j <= cols(cn); j++) {
            if (cn[j] == nm[k]) idx[k] = j
        }
    }
    if (hasmissing(idx) | cols(sd) != cols(nm)) _error(3498, "lag not found")
    bs = b[idx] :* sd
    Vs = V[idx, idx] :* (sd' * sd)
    Vi = invsym(Vs)
    rk = sum(diagonal(Vi) :!= 0)
    W = bs * Vi * bs'
    st_local("__iivw_wdf", strofreal(rk))
    st_local("__iivw_wchi2", strofreal(W, "%21x"))
    for (k = 1; k <= cols(nm); k++) {
        st_local("__iivw_tdf_" + strofreal(k), strofreal(invsym(Vs[k, k]) != 0))
    }
}

// ---------------------------------------------------------------------------
// Monotone likelihood (no finite maximum) of a Cox partial likelihood.
//
// Condition. With covariate rows x, risk set R(t) and event set D(t), the
// maximum partial likelihood estimate fails to exist when some direction
// a != 0 satisfies a'(x_j - x_i) >= 0 for every event i at every event time
// t and every j in R(t), with at least one inequality strict (Jacobsen 1989,
// stated by Chen, Ibrahim and Shao 2009, J. Multivariate Anal. 100:2018-2030,
// Remark 3.5, for the Breslow likelihood). Along beta = -s a every event row
// then carries the largest linear predictor of its risk set, so each
// partial-likelihood term is nondecreasing in s and the fit runs off to
// infinity. The same holds for Efron ties: dividing an Efron denominator
// sum_R e^eta - (k/d) sum_D e^eta by the common e^eta of the tied events
// leaves (d - k) + sum_{R\D} e^{-s a'(x_j - x_i)}, nonincreasing in s.
// A 1-D screen per term is not enough with several terms: two lags can each
// vary within every risk set while their difference separates.
//
// One covariate: a = +1 or -1, checked exactly on the raw values (every
// event at the minimum of its risk set, or every event at the maximum, with
// a strict gap somewhere). No arithmetic, so no conditioning to lose.
//
// Several covariates. Each constraint a'd >= 0, d = x_j - x_i, is unchanged
// by a positive rescaling of its own row, so every pair difference is used
// as the unit vector d/||d||: the cone, and whether a direction is strict,
// are exactly those of the raw constraints, but no pair can dominate because
// one covariate value is extreme (a lag of 1e9 once left a linear program
// infeasible or returning parameters outside its box). Columns are first
// centred and scaled by a spread set by the bulk of the column (the
// interquartile range, or the median nonzero deviation from the median),
// which rescales a per coordinate and so leaves the existence of a
// direction unchanged, while keeping one outlier from collapsing the rest of
// its column. A cone-membership search by nonnegative least squares
// (_iivw_cr_search, which states the argument) then proposes an answer.
//
// No floating-point tolerance decides the answer. Status 1 needs a direction
// whose slacks are signed EXACTLY on the original rows (_iivw_cr_xverify);
// status 0 needs a Stiemke vector y > 0 with Z'y = 0 shown to exist with a
// rigorous error bound (_iivw_cr_stiemke). Before any search, an O(rows)
// Stiemke certificate with pair weights 1 + eta_j - eta_i on an exact grid
// (_iivw_cr_stiemke_fast) settles most finite designs. A candidate that misses only by
// rounding is snapped to the exact extreme ray it approximates
// (_iivw_cr_snap), and a small problem is decided by exhaustive exact
// enumeration of the extreme rays (_iivw_cr_xsmall). Neither certificate
// found: status 2. See "Exact layer" below for the arithmetic.
//
// Risk sets are swept in event-time order (rows enter when their run of
// event times starts and leave after it ends), so memory is O(rows) and a
// pass costs the total size of the risk sets.
//
// Returns 1 x (p + 1): status (0 a finite maximum exists, certified; 1 a
// recession direction exists, certified; 2 neither certificate was found),
// then for each covariate 1 if the certified direction moves it. The
// optional route = 1 is for QA only (see below the scaling step).
real rowvector _iivw_cox_recession(string scalar t0v, string scalar tv,
    string scalar dv, string scalar xvars, string scalar tousev,
    | real scalar route)
{
    real colvector T0, T, Dd, ev, a, x, lo, hi, ordlo, cc, w, sv, keep, mu, ao, acand, snapped
    real matrix X, S, stat, U, Vt, M, Xw, Xr, Xo, Amap, Sid, Ax
    real rowvector out, g, sc, md, as
    real scalar p, N, k, status, sc2, gs, G, j, l, rn
    pointer(real colvector) rowvector PD

    T0 = st_data(., t0v, tousev)
    T  = st_data(., tv, tousev)
    Dd = st_data(., dv, tousev)
    X  = st_data(., tokens(xvars), tousev)
    p  = cols(X)
    N  = rows(X)
    out = J(1, p + 1, 0)
    if (N == 0 | p == 0) return(out)
    if (hasmissing(T0) | hasmissing(T) | hasmissing(X)) {
        out[1] = 2
        return(out)
    }
    ev = uniqrows(select(T, Dd :!= 0))
    if (rows(ev) == 0) return(out)
    lo = _iivw_cr_count_le(ev, T0) :+ 1
    hi = _iivw_cr_count_le(ev, T)
    ordlo = _iivw_cr_ord(lo)
    PD = _iivw_cr_events(Dd, hi, rows(ev))

    if (p == 1) {
        // Columns: max over D > min over R; min over D < max over R;
        // max over R > max over D; min over R < min over D.
        stat = _iivw_cr_pass1(X[., 1], lo, hi, ordlo, PD)
        if ((!any(stat[., 1]) & any(stat[., 3])) | (!any(stat[., 2]) & any(stat[., 4]))) {
            out = (1, 1)
        }
        return(out)
    }

    // The original rows are kept for the exact layer, which needs them
    // inside the range where error-free products are exact.
    Xo = X
    if (max(abs(Xo)) > 1e100 | any((abs(Xo) :< 1e-100) :& (Xo :!= 0))) {
        out[1] = 2
        return(out)
    }
    // Columns equal on almost every row (a lag and its copy changed on one
    // row) get one common centre and scale, so their search rows stay
    // exactly parallel where the data are; different scales made those rows
    // cancel only to rounding, with weights near 2e8. Any positive scale per
    // column leaves the answer unchanged.
    sc = J(1, p, 0)
    md = J(1, p, 0)
    for (k = 1; k <= p; k++) {
        x = Xo[., k]
        l = 0
        for (j = 1; j < k; j++) {
            if (sc[j] > 0 & mean(x :== Xo[., j]) >= 0.9) {
                l = j
                break
            }
        }
        if (l) {
            sc[k] = sc[l]
            md[k] = md[l]
        }
        else {
            sc[k] = _iivw_cr_rspread(x)
            md[k] = sort(x, 1)[ceil(N / 2)]
        }
        if (sc[k] > 0 & sc[k] < .) X[., k] = (x :- md[k]) :/ sc[k]
        else {
            sc[k] = 0
            X[., k] = J(N, 1, 0)
        }
    }
    // a in search coordinates is a_orig = Amap * a on the original rows.
    Amap = diag((sc :> 0) :/ (sc :+ (sc :== 0)))
    // Most designs have a finite maximum with room to spare: an exact
    // Stiemke certificate built in O(rows) (_iivw_cr_stiemke_fast) settles
    // them before any pass over the pairs. When it fails nothing is lost.
    // route = 1 (QA only; iivw_exogtest never passes it) skips this shortcut
    // and the exhaustive small-problem route, so the search decides whether
    // the check settles (the Stiemke step after a search still tries the
    // O(rows) certificate with the search's pairs). Every answer is still
    // certified.
    if (args() < 6) route = 0
    if (route != 1) {
        if (_iivw_cr_stiemke_fast(X, Xo, lo, hi, ordlo, PD,
            _iivw_cr_pairsample(Xo, lo, hi, PD), sc, Amap)) return(out)
    }
    g = _iivw_cr_pass(X, lo, hi, ordlo, PD, J(p, 1, .), 0, cc, w, J(p, 1, 0))
    if (hasmissing(g)) {
        out[1] = 2
        return(out)
    }
    S = J(0, p, .)
    Sid = J(0, 2, .)
    mu = J(0, 1, .)
    acand = J(0, 1, .)
    Ax = J(0, 0, .)
    G = max(abs(g))
    // g = 0: the pair rows cancel with unit weights, the membership side.
    status = 0
    rn = 0
    if (G > 0) {
        gs = w[1] / G
        g = g :/ G
        status = _iivw_cr_search(X, lo, hi, ordlo, PD, S, g, a, gs, Xo, Amap, Sid, mu, ao, rn)
        if (rows(ao)) acand = ao
        if (status == 1) Ax = ao
    }
    // Membership is status 0 only with a Stiemke certificate. A search that
    // stopped unsettled first tries to snap its candidate to an exact ray
    // (one pass, and it settles most such stops), then, if it stopped close
    // to membership, the Stiemke certificate.
    snapped = J(0, 1, .)
    if (status == 0) {
        if (_iivw_cr_stiemke(X, Xo, lo, hi, ordlo, PD, Sid, mu, (G > 0 ? G : 1), sc, Amap)) status = 0
        else status = 2
    }
    else if (status == 2) {
        if (rows(acand)) {
            snapped = acand
            if (_iivw_cr_snap(Xo, lo, hi, ordlo, PD, acand, Ax, sc)) status = 1
        }
        if (status == 2 & rn < 1e-4) {
            if (_iivw_cr_stiemke(X, Xo, lo, hi, ordlo, PD, Sid, mu, (G > 0 ? G : 1), sc, Amap)) status = 0
        }
    }

    // Rescue for nearly collinear terms (y and y + 1e-9 noise), whose
    // shared direction the search above sees only at 1e-9 and may fail to
    // settle. Rotate to the right singular vectors of the bulk of the data
    // (each column clipped at 50 spreads from its median, so one extreme
    // value cannot pose as collinearity) and divide by the singular values.
    // Any invertible linear map M carries the cone onto the cone of the
    // mapped rows (a'd >= 0 iff (M^-1 a)'(M'd) >= 0), so existence and
    // strictness are unchanged; a direction v with X v = 0 is exactly flat
    // (no difference has a component along it) and is dropped. Used only
    // when the first search did not settle and the bulk is ill-conditioned.
    // Its answers are certified on the original rows like the first's.
    if (status == 2) {
        Xw = X
        for (k = 1; k <= p; k++) {
            sc2 = _iivw_cr_rspread(X[., k])
            if (sc2 > 0 & sc2 < .) Xw[., k] = rowmin((rowmax((Xw[., k], J(N, 1, -50 * sc2))), J(N, 1, 50 * sc2)))
        }
        svd(Xw, U, sv, Vt)
        if (min(sv) < 1e-6 * max(sv)) {
            M = Vt' :/ sv'
            keep = J(0, 1, .)
            for (k = 1; k <= cols(M); k++) {
                if (norm(X * Vt[k, .]') > 1e-13 * norm(X)) keep = keep \ k
            }
            if (rows(keep)) {
                M = M[., keep]
                Xr = X * M
                for (k = 1; k <= cols(Xr); k++) {
                    sc2 = _iivw_cr_rspread(Xr[., k])
                    if (sc2 > 0 & sc2 < .) {
                        Xr[., k] = Xr[., k] :/ sc2
                        M[., k] = M[., k] :/ sc2
                    }
                }
                g = _iivw_cr_pass(Xr, lo, hi, ordlo, PD, J(cols(Xr), 1, .), 0, cc, w, J(cols(Xr), 1, 0))
                if (!hasmissing(g)) {
                    G = max(abs(g))
                    S = J(0, cols(Xr), .)
                    status = 0
                    rn = 0
                    if (G > 0) {
                        gs = w[1] / G
                        g = g :/ G
                        status = _iivw_cr_search(Xr, lo, hi, ordlo, PD, S, g, a, gs, Xo, Amap * M, Sid, mu, ao, rn)
                        if (rows(ao)) acand = ao
                        if (status == 1) Ax = ao
                    }
                    if (status == 0) {
                        if (_iivw_cr_stiemke(Xr, Xo, lo, hi, ordlo, PD, Sid, mu, (G > 0 ? G : 1), sc, Amap * M)) status = 0
                        else status = 2
                    }
                    else if (status == 2) {
                        if (rows(acand) & acand != snapped) {
                            snapped = acand
                            if (_iivw_cr_snap(Xo, lo, hi, ordlo, PD, acand, Ax, sc)) status = 1
                        }
                        if (status == 2 & rn < 1e-4) {
                            if (_iivw_cr_stiemke(Xr, Xo, lo, hi, ordlo, PD, Sid, mu, (G > 0 ? G : 1), sc, Amap * M)) status = 0
                        }
                    }
                }
            }
        }
    }
    // A candidate that failed only through rounding: snap it to the exact
    // extreme ray it approximates. Then, for small problems, decide exactly.
    if (status == 2 & rows(acand)) {
        if (acand != snapped) {
            if (_iivw_cr_snap(Xo, lo, hi, ordlo, PD, acand, Ax, sc)) status = 1
        }
    }
    if (status == 2 & route != 1) status = _iivw_cr_xsmall(Xo, lo, hi, ordlo, PD, Ax, 400, 3000, sc)
    out[1] = status
    // The terms named are those the verified direction moves, judged in the
    // scaled coordinates (a_scaled = a_orig * scale).
    if (status == 1) {
        as = rowsum(Ax)' :* sc
        out[|2 \ p + 1|] = (abs(as) :> 1e-7 * max(abs(as)))
    }
    return(out)
}

// Ascending order of v with ties broken by position. order() alone breaks
// ties with Stata's sort jumbler, so the sweep order, and with it which
// pairs the search sees first, changed with sortrngstate.
real colvector _iivw_cr_ord(real colvector v)
{
    return(order((v, (1::rows(v))), (1, 2)))
}

// Spread of a column set by its bulk: interquartile range, else the median
// nonzero deviation from the median (as _iivw_cr_rscale), 0 if constant.
real scalar _iivw_cr_rspread(real colvector x)
{
    real colvector xs, dv
    real scalar n, med, sc

    n = rows(x)
    xs = sort(x, 1)
    med = xs[ceil(n / 2)]
    sc = xs[ceil(0.75 * n)] - xs[max((1, ceil(0.25 * n)))]
    if (!(sc > 0 & sc < .)) {
        dv = sort(select(abs(x :- med), abs(x :- med) :> 0), 1)
        if (rows(dv) == 0) return(0)
        sc = dv[ceil(rows(dv) / 2)]
    }
    return(sc)
}

// Centre at the median and divide by the interquartile range, or, when
// that is zero (a column that is mostly one value), by the median nonzero
// absolute deviation from the median: a spread set by the bulk of the
// column, which an extreme value cannot inflate. A constant column becomes 0
// (it cannot move any constraint).
real colvector _iivw_cr_rscale(real colvector x)
{
    real colvector xs, dv
    real scalar n, med, sc

    n = rows(x)
    xs = sort(x, 1)
    med = xs[ceil(n / 2)]
    sc = xs[ceil(0.75 * n)] - xs[max((1, ceil(0.25 * n)))]
    if (!(sc > 0 & sc < .)) {
        dv = sort(select(abs(x :- med), abs(x :- med) :> 0), 1)
        if (rows(dv) == 0) return(J(n, 1, 0))
        sc = dv[ceil(rows(dv) / 2)]
    }
    return((x :- med) :/ sc)
}

// Event rows grouped by event-time index (an event row's own time is the
// last of its run, hi).
pointer(real colvector) rowvector _iivw_cr_events(real colvector Dd,
    real colvector hi, real scalar nt)
{
    pointer(real colvector) rowvector PD
    real colvector ei, em, o
    real matrix info
    real scalar m

    PD = J(1, nt, NULL)
    ei = selectindex(Dd :!= 0)
    em = hi[ei]
    o = order((em, ei), (1, 2))
    em = em[o]
    ei = ei[o]
    info = panelsetup(em, 1)
    for (m = 1; m <= rows(info); m++) {
        PD[em[info[m, 1]]] = &(ei[|info[m, 1] \ info[m, 2]|])
    }
    return(PD)
}

// Advance the sweep to event-time index m: drop rows whose run ended, add
// rows whose run starts at or before m (pos walks the rows in lo order).
void _iivw_cr_advance(real colvector active, real scalar pos, real scalar m,
    real colvector lo, real colvector hi, real colvector ordlo)
{
    real scalar j
    if (rows(active)) active = select(active, hi[active] :>= m)
    // select() of a vector can return 0 x 0; keep a column for the append.
    if (rows(active) == 0) active = J(0, 1, .)
    while (pos <= rows(ordlo)) {
        j = ordlo[pos]
        if (lo[j] > m) break
        if (hi[j] >= m) active = active \ j
        pos++
    }
}

// One-covariate pass: per event time, the four extreme comparisons.
real matrix _iivw_cr_pass1(real colvector x, real colvector lo, real colvector hi,
    real colvector ordlo, pointer(real colvector) rowvector PD)
{
    real colvector active, xr, xd
    real matrix out
    real scalar m, pos

    out = J(cols(PD), 4, 0)
    active = J(0, 1, .)
    pos = 1
    for (m = 1; m <= cols(PD); m++) {
        _iivw_cr_advance(active, pos, m, lo, hi, ordlo)
        xr = x[active]
        xd = x[*PD[m]]
        out[m, 1] = max(xd) > min(xr)
        out[m, 2] = min(xd) < max(xr)
        out[m, 3] = max(xr) > max(xd)
        out[m, 4] = min(xr) < min(xd)
    }
    return(out)
}

// Several-covariate pass over every (event, at-risk) pair as unit rows.
// mode 0: return g, the sum of all pairs at unit 1-norm. mode 1: for a,
// fill V (returned) with the most violated unit row of each violating event
// time, cc with their violations, Vid with their (event row, at-risk row),
// and w[1] with the largest slack seen.
real matrix _iivw_cr_pass(real matrix X, real colvector lo, real colvector hi,
    real colvector ordlo, pointer(real colvector) rowvector PD, real colvector a,
    real scalar mode, real colvector cc, real colvector w, | real colvector errv,
    real scalar kstop, real matrix Vid)
{
    real colvector active, D, nr, s, sz, rs, act
    real matrix Z, V, g, vid
    real scalar m, pos, q, i, best, kk

    g = J(1, cols(X), 0)
    V = J(0, cols(X), .)
    vid = J(0, 2, .)
    cc = J(0, 1, .)
    best = 0
    active = J(0, 1, .)
    pos = 1
    if (args() < 11) kstop = .
    for (m = 1; m <= cols(PD); m++) {
        // A verification pass may stop once it holds kstop violated pairs:
        // any violated pair is a valid cut. Only a pass that finds none has
        // to (and does) see every risk set.
        if (rows(V) >= kstop) break
        _iivw_cr_advance(active, pos, m, lo, hi, ordlo)
        D = *PD[m]
        for (q = 1; q <= rows(D); q++) {
            i = D[q]
            Z = X[active, .] :- X[i, .]
            if (mode == 0) {
                // g needs every pair with SOME positive weight (the cone
                // argument holds for any); 1-norm units skip a sqrt and a
                // copy on the one pass that must touch every pair.
                nr = rowsum(abs(Z))
                g = g + colsum(Z :/ (nr :+ (nr :== 0)))
                best = best + rows(Z)
                continue
            }
            nr = sqrt(rowsum(Z :* Z))
            Z = select(Z, nr :> 0)
            act = select(active, nr :> 0)
            nr = select(nr, nr :> 0)
            if (rows(Z) == 0) continue
            Z = Z :/ nr
            {
                // Slack s of each unit constraint, judged against a
                // floating-point error bound: relative to the terms that form
                // it (so a small but decisive component is never rounded
                // away), plus the error a carries from the solve (absolute,
                // about 1e-16 per unit of max|a| = 1, times the row's size).
                s = Z * a
                sz = 1e-10 * (abs(Z) * abs(a)) + abs(Z) * errv
                sz = sz :+ 1e-300 * (sz :== 0)
                rs = s :/ sz
                best = max((best, max(rs)))
                kk = _iivw_cr_argmin(rs)
                if (rs[kk] < -1) {
                    V = V \ Z[kk, .]
                    cc = cc \ rs[kk]
                    vid = vid \ (i, act[kk])
                }
            }
        }
    }
    w = best
    if (args() >= 12) Vid = vid
    if (mode == 0) return(g)
    return(V)
}

// For each x, the number of elements of the sorted vector v that are <= x.
real colvector _iivw_cr_count_le(real colvector v, real colvector x)
{
    real colvector key, flag, pos, o, cs, xi, res, po, fo

    key = (v \ x)
    flag = (J(rows(v), 1, 1) \ J(rows(x), 1, 0))
    pos = (J(rows(v), 1, 0) \ (1::rows(x)))
    o = order((key, -flag), (1, 2))
    fo = flag[o]
    po = pos[o]
    cs = runningsum(fo)
    xi = selectindex(fo :== 0)
    res = J(rows(x), 1, 0)
    res[po[xi]] = cs[xi]
    return(res)
}

// Search by cone membership. Let K be the cone generated by the pair rows
// z_k and g = sum c_k z_k a combination of ALL of them with every c_k > 0
// (each pair at unit 1-norm). A strict recession direction exists exactly when
// K is not a linear subspace (the cone of directions with z_k'a >= 0 is K's
// dual, whose only directions orthogonal to every z_k are K's orthogonal
// complement), and K is a subspace exactly when -g lies in K: if
// -g = sum mu_k z_k with mu >= 0 then sum (c_k + mu_k) z_k = 0 with every
// weight positive (Stiemke's alternative), and conversely. Membership is a
// nonnegative least-squares problem, min ||Z'mu + g|| over mu >= 0
// (Lawson-Hanson). Its residual r certifies either answer: r = 0 means no
// strict direction; otherwise a = -r satisfies z_k'a >= 0 for every
// generator in the problem (the NNLS optimality condition) and
// g'a = ||r||^2 > 0. Only a working set S of pairs enters the NNLS: -g in
// cone(S) already proves membership in K, and a candidate a is accepted only
// after it violates no pair of the full set; violated pairs join S. No
// linear program, so nothing to fail to converge, return out-of-box
// parameters, or abort.
// Neither answer is taken from this floating-point search alone. A direction
// it accepts on the search rows is re-checked EXACTLY on the original rows
// (_iivw_cr_xverify, through Amap: a_orig = Amap * a); pairs it violates
// exactly join S as cuts. A membership answer is returned as 0 and stands
// only if the caller can show a Stiemke vector from S, Sid and mu
// (_iivw_cr_stiemke). ao returns the last candidate in original coordinates.
// Returns 0 (membership, still to be certified), 1 (an exactly verified
// direction; a in search coordinates), 2 (did not settle).
real scalar _iivw_cr_search(real matrix X, real colvector lo, real colvector hi,
    real colvector ordlo, pointer(real colvector) rowvector PD, real matrix S,
    real rowvector g, real colvector a, real scalar gs, real matrix Xo,
    real matrix Amap, real matrix Sid, real colvector mu, real colvector ao,
    real scalar rn)
{
    real matrix V, Vid, xid, Sw
    real colvector cc, w, o, r, errv, zr, muw, az
    real scalar it, n, nb, ng, bound, summu, aerr, tight, gray, xs, k, mx

    // The membership decision must not depend on how many pairs there are
    // or on ||g||: one strict pair among 10^8 flat ones moves -g out of the
    // cone by only ~1/10^8 of ||g||, so a bound proportional to ||g|| (or a
    // fixed relative one) swamps it. The bound is the floating-point error
    // of the quantities themselves: g is a sum of gs unit-1-norm terms (gs
    // = pairs / max|g| after g is scaled to max|g| = 1), and the residual
    // adds sum(mu) unit rows; each sum carries ~eps per term.
    ng = sqrt(g * g')
    Sw = J(rows(S), 2, .)
    Sid = J(0, 2, .)
    mu = J(0, 1, .)
    ao = J(0, 1, .)
    rn = .
    for (it = 1; it <= 500; it++) {
        bound = 1e2 * 2.2e-16 * (gs + ng)
        tight = bound
        summu = 0
        if (rows(S) == 0) {
            r = -g'
            muw = J(0, 1, .)
        }
        else {
            muw = _iivw_cr_nnls(S', -g')
            r = -g' - S' * muw
            // The residual is computed from a sum of unit rows weighted by
            // mu, so its rounding error grows with sum(mu): a near-parallel
            // pair (x and x + 1e-9 e_k) can generate a tiny direction only
            // with weights near 1e9, leaving ~1e-7 of pure cancellation.
            // A residual inside that error bound is membership.
            summu = sum(muw)
            bound = bound + 1e2 * 2.2e-16 * summu
        }
        // The pairs and weights of this solve, for a Stiemke certificate.
        Sid = Sw
        mu = muw
        rn = sqrt(r' * r)
        // Below the error of g itself: membership. Between that and the
        // error the weights mu can add (a near-parallel pair cancelled with
        // weights near 1e9), the residual may be a real but tiny separation
        // (one strict pair among 10^8 flat ones) or cancellation noise: the
        // candidate -r is then accepted only if it verifies on every pair
        // as a concrete vector, and the verdict is "did not settle" (2)
        // otherwise.
        gray = 0
        if (sqrt(r' * r) <= tight) return(0)
        if (sqrt(r' * r) <= bound) gray = 1
        a = -r
        // The error a carries: the residual's own rounding (~1e-14 of
        // ||g|| + sum(mu)) after scaling a to max|a| = 1. Components below it
        // are set to zero. A component that is exactly 0 or exactly +/-1
        // after that carries no error; the others carry aerr, and slacks are
        // judged against it.
        aerr = max((1e-12, (1e2 * 2.2e-16 * (gs + ng + summu)) / max(abs(a))))
        a = a :/ max(abs(a))
        // The raw candidate in original coordinates, kept for the repair
        // step whatever this round decides (its small components locate the
        // tight rows; zeroing them below would lose that).
        ao = Amap * a
        mx = max(abs(ao))
        if (mx > 0 & mx < .) ao = ao :/ mx
        else ao = J(0, 1, .)
        a = a :* (abs(a) :>= aerr)
        errv = aerr :* ((a :!= 0) :& (abs(a) :!= 1))
        V = _iivw_cr_pass(X, lo, hi, ordlo, PD, a, 1, cc, w, errv, 8 * (2 * cols(X) + 4), Vid)
        if (rows(V) == 0) {
            // Accepted on the search rows within their error allowance. The
            // allowance can swallow a real violation (a 1e9 lag left a
            // normalised slack of -1e-17 inside it), so the verdict is the
            // exact check of the same direction on the original rows.
            az = Amap * a
            mx = max(abs(az))
            if (!(mx > 0 & mx < .)) return(2)
            az = az :/ mx
            xs = _iivw_cr_xverify(Xo, lo, hi, ordlo, PD, az, xid, 2 * cols(X) + 4)
            if (xs == 1) {
                ao = az
                return(1)
            }
            // An integer combination missed only by rounding (a lag copy
            // changed on one row): its plain integer roundings, checked
            // exactly with a stop at the first violated pair.
            for (k = 1; k <= rows(ao); k++) {
                if (abs(ao[k]) < 0.05 * max(abs(ao))) continue
                zr = round(ao :/ ao[k]) :* sign(ao[k])
                if (all(zr :== 0)) continue
                if (_iivw_cr_xverify(Xo, lo, hi, ordlo, PD, zr, Vid, 1) == 1) {
                    ao = zr
                    return(1)
                }
            }
            nb = rows(S)
            if (xs == -1) {
                for (k = 1; k <= rows(xid); k++) {
                    zr = (X[xid[k, 2], .] - X[xid[k, 1], .])'
                    if (norm(zr) > 0 & norm(zr) < .) {
                        _iivw_cr_addrows(S, Sw, zr' :/ norm(zr), xid[k, .])
                    }
                }
            }
            if (rows(S) > nb) continue
            // Nothing strict above the error and no exact violation left to
            // cut: the membership side, which the caller must certify.
            if (w[1] <= 1) return(0)
            return(2)
        }
        if (gray) return(2)
        o = _iivw_cr_ord(cc)
        n = min((rows(o), 2 * cols(X) + 4))
        nb = rows(S)
        _iivw_cr_addrows(S, Sw, V[o[|1 \ n|], .], Vid[o[|1 \ n|], .])
        if (rows(S) == nb) return(2)
    }
    return(2)
}

// S = uniqrows(S \ Vn), as the search always kept it (sorted, distinct), with
// the pair ids Sid carried along (the first id of a repeated row is kept).
void _iivw_cr_addrows(real matrix S, real matrix Sid, real matrix Vn,
    real matrix Vidn)
{
    real matrix C
    real colvector o, keep
    real scalar k, p

    p = cols(Vn)
    C = (S, Sid) \ (Vn, Vidn)
    o = order((C[., 1..p], (1::rows(C))), 1..(p + 1))
    C = C[o, .]
    keep = J(rows(C), 1, 1)
    for (k = 2; k <= rows(C); k++) {
        if (C[k, 1..p] == C[k - 1, 1..p]) keep[k] = 0
    }
    C = select(C, keep)
    S = C[., 1..p]
    Sid = C[., (p + 1)..(p + 2)]
}

// Lawson-Hanson nonnegative least squares: min ||A x - b|| over x >= 0.
real colvector _iivw_cr_nnls(real matrix A, real colvector b)
{
    real colvector x, z, w, P, idx, zi, xi, neg
    real scalar n, it, inner, j, alpha, tol, rk

    n = cols(A)
    x = J(n, 1, 0)
    P = J(n, 1, 0)
    tol = 1e-12 * max((1, max(abs(A)) * max(abs(b)))) * n
    for (it = 1; it <= 3 * n + 10; it++) {
        w = A' * (b - A * x)
        if (all(P) | max(w :* (1 :- P) :- 1e300 * P) <= tol) break
        j = _iivw_cr_argmin(-(w :* (1 :- P) :- 1e300 * P))
        P[j] = 1
        for (inner = 1; inner <= 3 * n + 10; inner++) {
            idx = selectindex(P)
            z = J(n, 1, 0)
            // A tight rank tolerance: unit rows of an extreme pair carry
            // 1e-9-scale components that the default would discard.
            zi = svsolve(A[., idx], b, rk, 1e-6)
            z[idx] = zi
            if (min(zi) > tol) {
                x = z
                break
            }
            xi = x[idx]
            neg = selectindex(zi :<= tol)
            alpha = min(xi[neg] :/ (xi[neg] - zi[neg]))
            if (alpha >= .) alpha = 0
            x = x + alpha * (z - x)
            P = P :* (x :> tol)
            x = x :* P
            if (!any(P)) break
        }
    }
    return(x)
}

real scalar _iivw_cr_argmin(real colvector v)
{
    real colvector i, w
    minindex(v, 1, i, w)
    return(i[1])
}

// ---------------------------------------------------------------------------
// Exact layer of the separation check. Every verdict the check returns rests
// on a certificate checked on the ORIGINAL rows with a rigorous error bound:
// status 1 on a direction a whose slacks z'a, z = x_j - x_i, are signed
// exactly (_iivw_cr_xverify), status 0 on a Stiemke vector y > 0 with
// Z'y = 0 shown to exist (_iivw_cr_stiemke) or on an exhaustive exact search
// of a small problem (_iivw_cr_xsmall). The floating-point search above only
// proposes candidates; no tolerance of it decides an answer.
//
// The arithmetic is built from error-free transformations of IEEE doubles:
// Knuth's TwoSum (s + e = a + b exactly) and Dekker's TwoProduct with a
// 2^27 + 1 split (p + e = a * b exactly), valid without overflow and, for
// the product, without underflow (inputs are confined to [1e-100, 1e100]
// and products below 1e-250 are refused). Sums are signed or bounded with
// the summation error bound gamma_n = n u / (1 - n u), u = 2^-53, which
// holds for any order of n - 1 additions (Higham 2002, Accuracy and
// Stability of Numerical Algorithms, sec. 4.2); Ogita, Rump and Oishi
// (2005, SIAM J. Sci. Comput. 26:1955-1988) give the transformations.
// An "expansion" is a row vector of doubles whose exact sum is the value.

// Indices of the nonzero elements of v as a column (selectindex() of a 1 x 1
// zero returns a 1 x 0 row, whose rows() is 1).
real colvector _iivw_cr_which(real vector v)
{
    real vector x

    x = selectindex(v)
    if (length(x) == 0) return(J(0, 1, .))
    return(colshape(x, 1))
}

void _iivw_cr_tsum(real matrix a, real matrix b, real matrix s, real matrix e)
{
    real matrix bp

    s = a :+ b
    bp = s :- a
    e = (a :- (s :- bp)) :+ (b :- bp)
}

void _iivw_cr_tprod(real matrix a, real matrix b, real matrix p, real matrix e)
{
    real matrix c, ah, al, bh, bl

    p = a :* b
    c = 134217729 :* a
    ah = c :- (c :- a)
    al = a :- ah
    c = 134217729 :* b
    bh = c :- (c :- b)
    bl = b :- bh
    e = al :* bl :- (((p :- ah :* bh) :- al :* bh) :- ah :* bl)
}

// Sign (-1, 0, 1; missing if not settled) of the exact sum of each row of Q.
// Each sweep of error-free sums moves the running sum into the last column
// and leaves exact remainders, so the row's exact sum never changes. Once
// the last column exceeds the sum of the remainders' magnitudes (inflated
// for the rounding of that sum) it carries the sign.
real colvector _iivw_cr_xsign(real matrix Q)
{
    real colvector res, und, top, rest, dec
    real matrix W, s, e
    real scalar n, it, c

    res = J(rows(Q), 1, .)
    if (rows(Q) == 0) return(res)
    n = cols(Q)
    if (n == 1) return(sign(Q))
    und = (1::rows(Q))
    W = Q
    for (it = 1; it <= 3 * n + 3; it++) {
        for (c = 2; c <= n; c++) {
            _iivw_cr_tsum(W[., c - 1], W[., c], s, e)
            W[., c] = s
            W[., c - 1] = e
        }
        top = W[., n]
        rest = rowsum(abs(W[|1, 1 \ rows(W), n - 1|]))
        dec = (abs(top) :> rest :* (1 + 4 * n * 2^-53)) :| ((top :== 0) :& (rest :== 0))
        if (hasmissing(top) | hasmissing(rest)) dec = dec :& (top :< .) :& (rest :< .)
        if (any(dec)) {
            res[select(und, dec)] = sign(select(top, dec))
            if (all(dec)) break
            und = select(und, !dec)
            W = select(W, !dec)
        }
    }
    return(res)
}

// Compress an expansion: two sweeps of error-free sums, zeros dropped.
real rowvector _iivw_cr_xcomp(real rowvector v)
{
    real rowvector w
    real matrix s, e
    real scalar c, k

    if (hasmissing(v)) return(.)
    w = select(v, v :!= 0)
    for (k = 1; k <= 2; k++) {
        if (cols(w) <= 1) break
        for (c = 2; c <= cols(w); c++) {
            _iivw_cr_tsum(w[c - 1], w[c], s, e)
            w[c] = s
            w[c - 1] = e
        }
        w = select(w, w :!= 0)
    }
    if (cols(w) == 0) w = 0
    return(w)
}

// Exact product of two expansions (missing if a partial product could
// underflow, which would make TwoProduct inexact).
real rowvector _iivw_cr_xmul(real rowvector a, real rowvector b)
{
    real matrix A, B, P, E

    if (hasmissing(a) | hasmissing(b)) return(.)
    A = a' * J(1, cols(b), 1)
    B = J(cols(a), 1, 1) * b
    _iivw_cr_tprod(A, B, P, E)
    // A product below 1e-250, or one that underflowed to 0 from nonzero
    // factors, may have lost its error term.
    if (any((abs(P) :< 1e-250) :& ((P :!= 0) :| ((A :!= 0) :& (B :!= 0))))) return(.)
    return(_iivw_cr_xcomp((vec(P)', vec(E)')))
}

// Exact determinant of a square matrix of expansions (Laplace expansion
// along the first row; used for at most 5 x 5).
real rowvector _iivw_cr_xdet(pointer(real rowvector) matrix E)
{
    pointer(real rowvector) matrix Es
    real rowvector acc, t, cl
    real scalar n, j

    n = rows(E)
    if (n == 1) return(*E[1, 1])
    if (n == 2) return(_iivw_cr_xcomp((_iivw_cr_xmul(*E[1, 1], *E[2, 2]),
        -_iivw_cr_xmul(*E[1, 2], *E[2, 1]))))
    acc = 0
    for (j = 1; j <= n; j++) {
        if (all(*E[1, j] :== 0)) continue
        cl = select(1..n, (1..n) :!= j)
        Es = E[|2, 1 \ n, n|]
        Es = Es[., cl]
        t = _iivw_cr_xmul(*E[1, j], _iivw_cr_xdet(Es))
        if (mod(j, 2) == 0) t = -t
        acc = _iivw_cr_xcomp((acc, t))
        if (hasmissing(acc)) return(.)
    }
    return(acc)
}

// Exact generalized cross product of the rows of Rh + Rl (n - 1 rows of
// length n): v with v'r = 0 exactly for every row r, as an n x L matrix
// whose row k is an expansion of v_k. Rows are first scaled by powers of 2
// (exact). Missing if an intermediate product left the exact range.
real matrix _iivw_cr_gcp(real matrix Rh0, real matrix Rl0)
{
    pointer(real rowvector) matrix E
    pointer(real rowvector) colvector C
    real matrix Rh, Rl, V
    real rowvector d, cl
    real scalar n, r, k, L, f

    n = cols(Rh0)
    Rh = Rh0
    Rl = Rl0
    for (r = 1; r <= rows(Rh); r++) {
        f = max(abs(Rh[r, .]))
        if (!(f > 0 & f < .)) return(J(n, 1, .))
        f = _iivw_cr_pow2(-floor(ln(f) / ln(2)))
        Rh[r, .] = Rh[r, .] :* f
        Rl[r, .] = Rl[r, .] :* f
    }
    if (n == 1) return(J(1, 1, 1))
    E = J(n - 1, n, NULL)
    for (r = 1; r <= n - 1; r++) {
        for (k = 1; k <= n; k++) {
            E[r, k] = &(_iivw_cr_xcomp((Rh[r, k], Rl[r, k])))
        }
    }
    C = J(n, 1, NULL)
    L = 1
    for (k = 1; k <= n; k++) {
        cl = select(1..n, (1..n) :!= k)
        d = _iivw_cr_xdet(E[., cl])
        if (hasmissing(d)) return(J(n, 1, .))
        if (mod(k, 2) == 0) d = -d
        // &(d) would be the address of d itself, shared by every k; an
        // expression gets its own temporary.
        C[k] = &(d :* 1)
        if (cols(d) > L) L = cols(d)
    }
    V = J(n, L, 0)
    for (k = 1; k <= n; k++) V[|k, 1 \ k, cols(*C[k])|] = *C[k]
    return(V)
}

// Exact signs of the slacks z'a for the rows z = Zh + Zl (exact, as formed
// by TwoSum) and a = rowsum(Ax) (Ax p x L, an expansion per component). A
// floating-point filter with a rigorous bound settles most rows; the rest
// are summed exactly from error-free products. Missing where a product
// could underflow.
real colvector _iivw_cr_xslack(real matrix Zh, real matrix Zl, real matrix Ax)
{
    real rowvector af, da
    real colvector sf, bnd, res, ui, bad
    real matrix Q, P, E, P2, E2, Zu, Zv
    real scalar k, m, p, L, u

    res = J(rows(Zh), 1, .)
    if (rows(Zh) == 0) return(res)
    p = cols(Zh)
    L = cols(Ax)
    u = 2^-53
    af = rowsum(Ax)'
    da = J(1, p, 0)
    if (L > 1) da = (4 * L * u) :* rowsum(abs(Ax))'
    // |exact - sf| <= |Zl||a| + |Zh||a - af| + gamma_p |Zh||af|, with
    // |Zl| <= u |Zh| and |a - af| <= da (sum of the expansion's terms).
    sf = Zh * af'
    bnd = (4 * (p + 2) * u) :* (abs(Zh) * abs(af')) :+ 2 :* (abs(Zh) * da') :+ 1e-290
    res = sign(sf)
    ui = _iivw_cr_which(abs(sf) :<= bnd)
    if (rows(ui) == 0) return(res)
    Zu = Zh[ui, .]
    Zv = Zl[ui, .]
    Q = J(rows(ui), 0, .)
    bad = J(rows(ui), 1, 0)
    for (k = 1; k <= p; k++) {
        for (m = 1; m <= L; m++) {
            if (Ax[k, m] == 0) continue
            _iivw_cr_tprod(Zu[., k], Ax[k, m], P, E)
            _iivw_cr_tprod(Zv[., k], Ax[k, m], P2, E2)
            Q = (Q, P, E, P2, E2)
            // TwoProduct is exact only if the product does not underflow.
            bad = bad :| ((abs(P) :< 1e-250) :& ((P :!= 0) :| (Zu[., k] :!= 0))) :|
                ((abs(P2) :< 1e-250) :& ((P2 :!= 0) :| (Zv[., k] :!= 0)))
        }
    }
    if (cols(Q) == 0) {
        res[ui] = J(rows(ui), 1, 0)
        return(res)
    }
    res[ui] = _iivw_cr_xsign(Q)
    if (any(bad)) res[select(ui, bad)] = J(sum(bad), 1, .)
    return(res)
}

// Exact linear predictor eta = X a of every row, a = rowsum(Ax) (Ax p x L,
// an expansion per component): T holds, per row, error-free products whose
// exact sum is eta_r, after sweeps of error-free sums (the last column is
// the floating sum). eta_r lies in [elo_r, ehi_r], a rigorous enclosure
// computed in floating point with margin; ex_r = 1 when the remainders are
// all 0, so that eta_r = T[r, cols(T)] exactly (elo = ehi = that value).
// bad_r = 1 if a product could underflow (the row is then never signed).
void _iivw_cr_xeta(real matrix X, real matrix Ax, real matrix T,
    real colvector elo, real colvector ehi, real colvector ex, real colvector bad)
{
    real matrix P, E, s, e
    real colvector top, rest, mg
    real scalar k, m, c, n, it, u

    u = 2^-53
    T = J(rows(X), 0, .)
    bad = J(rows(X), 1, 0)
    for (k = 1; k <= rows(Ax); k++) {
        for (m = 1; m <= cols(Ax); m++) {
            if (Ax[k, m] == 0) continue
            _iivw_cr_tprod(X[., k], Ax[k, m], P, E)
            T = (T, E, P)
            bad = bad :| ((abs(P) :< 1e-250) :& ((P :!= 0) :| (X[., k] :!= 0)))
        }
    }
    if (cols(T) == 0) T = J(rows(X), 1, 0)
    n = cols(T)
    for (it = 1; it <= 3 & n > 1; it++) {
        for (c = 2; c <= n; c++) {
            _iivw_cr_tsum(T[., c - 1], T[., c], s, e)
            T[., c] = s
            T[., c - 1] = e
        }
    }
    top = T[., n]
    rest = J(rows(X), 1, 0)
    if (n > 1) rest = rowsum(abs(T[|1, 1 \ rows(T), n - 1|]))
    ex = (rest :== 0)
    // |eta - top| <= sum of the remainders; the margin covers the rounding
    // of that sum and of top -/+ it.
    mg = (rest :* (1 + 4 * n * u) :+ 2 * u :* abs(top)) :* (1 + 8 * u) :+ 1e-300
    elo = top :- mg
    ehi = top :+ mg
    elo = ex :* top :+ (1 :- ex) :* elo
    ehi = ex :* top :+ (1 :- ex) :* ehi
}

// Exact check of a candidate direction (Ax as in _iivw_cr_xslack) on every
// (event, at-risk) pair of the original rows Xo. Each slack is the exact
// difference eta_j - eta_i of the rows' linear predictors, so it is signed
// from their enclosures (_iivw_cr_xeta); only pairs whose enclosures overlap
// and are not both exact are summed exactly (_iivw_cr_xsign). Returns 1
// (every slack >= 0, one > 0: a strict recession direction), 0 (every slack
// exactly 0), -1 (a slack < 0; up to kstop violating (event row, at-risk
// row) in vid), missing (a slack could not be signed).
real scalar _iivw_cr_xverify(real matrix Xo, real colvector lo, real colvector hi,
    real colvector ordlo, pointer(real colvector) rowvector PD, real matrix Ax,
    real matrix vid, real scalar kstop)
{
    real colvector active, D, sg, act, nz, vi, elo, ehi, ex, bad, pos_, neg_, zer, ui
    real matrix T
    real scalar m, pos, q, i, npos, nund, k

    vid = J(0, 2, .)
    if (hasmissing(Ax)) return(.)
    _iivw_cr_xeta(Xo, Ax, T, elo, ehi, ex, bad)
    // A missing enclosure would compare as larger than every number.
    if (hasmissing(elo) | hasmissing(ehi)) return(.)
    npos = 0
    nund = 0
    active = J(0, 1, .)
    pos = 1
    for (m = 1; m <= cols(PD); m++) {
        _iivw_cr_advance(active, pos, m, lo, hi, ordlo)
        D = *PD[m]
        for (q = 1; q <= rows(D); q++) {
            i = D[q]
            // Pairs with an exactly zero difference are no constraint.
            nz = rowsum(Xo[active, .] :!= Xo[i, .]) :> 0
            if (!any(nz)) continue
            act = select(active, nz)
            pos_ = elo[act] :> ehi[i]
            neg_ = ehi[act] :< elo[i]
            zer = ex[act] :& ex[i] :& (ehi[act] :== ehi[i])
            sg = pos_ - neg_
            ui = _iivw_cr_which(!(pos_ :| neg_ :| zer))
            if (rows(ui)) {
                sg[ui] = _iivw_cr_xsign((T[act[ui], .], -J(rows(ui), 1, T[i, .])))
            }
            if (bad[i]) sg = J(rows(sg), 1, .)
            else {
                ui = _iivw_cr_which(bad[act])
                if (rows(ui)) sg[ui] = J(rows(ui), 1, .)
            }
            npos = npos + sum(sg :== 1)
            nund = nund + sum(sg :>= .)
            vi = _iivw_cr_which(sg :== -1)
            if (rows(vi)) {
                if (rows(vi) > 2) vi = vi[|1 \ 2|]
                vid = vid \ (J(rows(vi), 1, i), act[vi])
                if (rows(vid) >= kstop) return(-1)
            }
        }
    }
    if (rows(vid)) return(-1)
    if (nund) return(.)
    return(npos > 0)
}

// Rigorous running sum of the rows of Zh .* y + Zl .* y (y a column of
// weights): H holds an error-free tree sum, Lo the floating sum of every
// remainder (TwoSum and TwoProduct errors, and the products Zl .* y), Ab the
// sum of their magnitudes, AbF that of Zl .* y (its own rounding), nlow
// their count. nlow becomes missing if a product could underflow.
void _iivw_cr_accum(real matrix Zh, real matrix Zl, real colvector y,
    real rowvector H, real rowvector Lo, real rowvector Ab, real rowvector AbF,
    real scalar nlow)
{
    real matrix P, E, F, S1, E1, A, B
    real scalar n, h

    if (rows(Zh) == 0) return
    _iivw_cr_tprod(Zh, y, P, E)
    if (any((abs(P) :< 1e-250) :& ((P :!= 0) :| ((Zh :!= 0) :& (y :!= 0))))) nlow = .
    F = Zl :* y
    Lo = Lo + colsum(E) + colsum(F)
    Ab = Ab + colsum(abs(E)) + colsum(abs(F))
    AbF = AbF + colsum(abs(F))
    nlow = nlow + 2 * rows(P)
    while (rows(P) > 1) {
        n = rows(P)
        h = floor(n / 2)
        A = P[|1, 1 \ h, cols(P)|]
        B = P[|h + 1, 1 \ 2 * h, cols(P)|]
        _iivw_cr_tsum(A, B, S1, E1)
        Lo = Lo + colsum(E1)
        Ab = Ab + colsum(abs(E1))
        nlow = nlow + h
        if (n > 2 * h) P = S1 \ P[n, .]
        else P = S1
    }
    _iivw_cr_tsum(H, P, S1, E1)
    H = S1
    Lo = Lo + E1
    Ab = Ab + abs(E1)
    nlow = nlow + 1
}

// Z * M with each element formed as rowsum(Z[r, .] :* M[., c]'), so a row
// gives the same doubles whether it is multiplied alone or in a block (a
// BLAS product need not); weights recomputed for one pair then equal the
// pass's exactly.
real matrix _iivw_cr_rmul(real matrix Z, real matrix M)
{
    real matrix out
    real scalar c

    out = J(rows(Z), cols(M), .)
    for (c = 1; c <= cols(M); c++) out[., c] = rowsum(Z :* M[., c]')
    return(out)
}

// A small spread of (event row, at-risk row) pairs for the B rows of a
// Stiemke correction when no search has run: at up to 25 event times spread
// over follow-up, the first event against the rows holding the smallest and
// largest value of each column in its risk set.
real matrix _iivw_cr_pairsample(real matrix Xo, real colvector lo,
    real colvector hi, pointer(real colvector) rowvector PD)
{
    real matrix out, w
    real colvector R, ix
    real scalar nt, m, t, i, k, step

    nt = cols(PD)
    out = J(0, 2, .)
    if (nt == 0) return(out)
    step = max((1, floor(nt / 25)))
    for (t = 1; t <= nt; t = t + step) {
        i = (*PD[t])[1]
        R = _iivw_cr_which((lo :<= t) :& (hi :>= t))
        if (rows(R) < 2) continue
        for (k = 1; k <= cols(Xo); k++) {
            minindex(Xo[R, k], 1, ix, w)
            if (R[ix[1]] != i) out = out \ (i, R[ix[1]])
            maxindex(Xo[R, k], 1, ix, w)
            if (R[ix[1]] != i) out = out \ (i, R[ix[1]])
        }
    }
    if (rows(out)) out = uniqrows(out)
    return(out)
}

// Exact integer coefficients 2^q C_r of _iivw_cr_stiemke_fast for the grid
// predictor eta = kk 2^-q (sq = 2^q): sum over every (event i, at-risk j)
// pair of (1 + eta_j - eta_i)(x_j - x_i) equals sum_r C_r x_r. Missing if a
// coefficient could reach 2^52 (then integers are no longer exact).
real colvector _iivw_cr_dyadcoef(real colvector lo, real colvector hi,
    pointer(real colvector) rowvector PD, real colvector kk, real scalar sq)
{
    real colvector Bt, Et, cumE, Fr, Cr, inr, dv, cumd, Ar, mt, ev, tev, D
    real scalar N, nt, r, t

    N = rows(lo)
    nt = cols(PD)
    inr = (lo :<= hi) :& (hi :>= 1)
    // A_r: events whose risk set holds row r; m_t: size of risk set t;
    // ev, tev: event rows and their event-time index.
    dv = J(nt, 1, 0)
    for (t = 1; t <= nt; t++) dv[t] = rows(*PD[t])
    cumd = runningsum(dv)
    Ar = J(N, 1, 0)
    mt = J(nt + 1, 1, 0)
    for (r = 1; r <= N; r++) {
        if (!inr[r]) continue
        Ar[r] = cumd[hi[r]] - (lo[r] > 1 ? cumd[lo[r] - 1] : 0)
        mt[lo[r]] = mt[lo[r]] + 1
        mt[hi[r] + 1] = mt[hi[r] + 1] - 1
    }
    mt = runningsum(mt)
    ev = J(N, 1, 0)
    tev = J(N, 1, 0)
    for (t = 1; t <= nt; t++) {
        D = *PD[t]
        ev[D] = J(rows(D), 1, 1)
        tev[D] = J(rows(D), 1, t)
    }
    // The identity needs every event row in its own risk set (t0 < t).
    if (any(ev :& !inr)) return(J(N, 1, .))
    Bt = J(nt + 1, 1, 0)
    for (r = 1; r <= N; r++) {
        if (!inr[r]) continue
        Bt[lo[r]] = Bt[lo[r]] + kk[r]
        Bt[hi[r] + 1] = Bt[hi[r] + 1] - kk[r]
    }
    Bt = runningsum(Bt)
    Et = J(nt, 1, 0)
    for (t = 1; t <= nt; t++) Et[t] = sum(kk[*PD[t]])
    cumE = runningsum(Et)
    Fr = J(N, 1, 0)
    Cr = J(N, 1, 0)
    for (r = 1; r <= N; r++) {
        if (!inr[r]) continue
        Fr[r] = cumE[hi[r]] - (lo[r] > 1 ? cumE[lo[r] - 1] : 0)
        Cr[r] = Ar[r] * (sq + kk[r]) - Fr[r]
        if (ev[r]) Cr[r] = Cr[r] + mt[tev[r]] * (kk[r] - sq) - Bt[tev[r]]
    }
    if (max(abs(Cr)) >= 2^52) return(J(N, 1, .))
    return(Cr)
}

// Fast Stiemke certificate, tried before the pass of _iivw_cr_stiemke. It
// never visits the pairs. The weight of pair (event i, at-risk j) is
// y_ij = 1 + eta_j - eta_i, eta a per-row predictor on the dyadic grid
// k_r 2^-q with |eta| < 1/2 (so every y_ij > 0). Then, with A_r the number
// of events whose risk set holds row r, m_t the size of risk set t, B_t the
// sum of eta over risk set t, E_t over the events at t and F_r the sum of E_t
// over the event times row r is at risk,
//   sum_pairs y_ij (x_j - x_i) = sum_r C_r x_r,
//   C_r = A_r (1 + eta_r) - F_r + [r an event at t] (m_t (eta_r - 1) - B_t),
// and 2^q C_r is an integer below 2^53 (q is chosen so), formed exactly. So
// the residual of these weights is exact in O(rows). eta = R w is chosen by
// Newton steps on K w = -rho, K = sum_pairs r r' from risk-set moments in
// the well-conditioned rotated coordinates R (as in _iivw_cr_stiemke), and
// the last residual goes to the correction and verified-inverse step
// (_iivw_cr_stiemke_b) on the working-set pairs. A failure proves nothing.
real scalar _iivw_cr_stiemke_fast(real matrix Xw, real matrix Xo,
    real colvector lo, real colvector hi, real colvector ordlo,
    pointer(real colvector) rowvector PD, real matrix Sid, real rowvector sc,
    real matrix Amap)
{
    real rowvector H, Lo, Ab, AbF, cmax, ac, ac2, H2, Lo2, Ab2, AbF2, rng, rho
    real colvector dv, cumd, mt, Ar, D, yt, inr, ev, tev, kk, Cr, eta, wv, svx, kp
    real matrix Ch, Cl, zr, zl1, cand, Xr, Mr, Vt, Xc, S1, Ev, K
    real scalar p, nt, N, r, t, k, nlow, nl2, tr, q, sq, it, kmax, ok

    p = cols(Xo)
    N = rows(Xo)
    nt = cols(PD)
    if (nt == 0) return(0)
    inr = (lo :<= hi) :& (hi :>= 1)
    // Event-time structure (all integers).
    dv = J(nt, 1, 0)
    for (t = 1; t <= nt; t++) dv[t] = rows(*PD[t])
    cumd = runningsum(dv)
    Ar = J(N, 1, 0)
    mt = J(nt + 1, 1, 0)
    for (r = 1; r <= N; r++) {
        if (!inr[r]) continue
        Ar[r] = cumd[hi[r]] - (lo[r] > 1 ? cumd[lo[r] - 1] : 0)
        mt[lo[r]] = mt[lo[r]] + 1
        mt[hi[r] + 1] = mt[hi[r] + 1] - 1
    }
    mt = runningsum(mt)
    ev = J(N, 1, 0)
    tev = J(N, 1, 0)
    for (t = 1; t <= nt; t++) {
        D = *PD[t]
        ev[D] = J(rows(D), 1, 1)
        tev[D] = J(rows(D), 1, t)
    }
    // Grid: 2^q |C_r| <= 4 N 2^q must stay below 2^53.
    q = floor(50 - ln(N + 1) / ln(2))
    if (q < 10) return(0)
    sq = _iivw_cr_pow2(q)
    kmax = floor(0.45 * sq)
    // Well-conditioned rotated coordinates (mean-centred search rows).
    if (rows(Xw) < cols(Xw)) return(0)
    Xc = Xw :- mean(Xw)
    _svd(Xc, svx, Vt)
    kp = _iivw_cr_which(svx :> 1e-300 * max(svx))
    if (rows(kp) == 0) return(0)
    Mr = (Vt[kp, .])' :/ (svx[kp])'
    Xr = (Xw :- mean(Xw)) * Mr
    // K = sum_pairs (r_j - r_i)(r_j - r_i)' from moments: sum_r (A_r + [ev] m_t)
    // r_r r_r' minus, for each event i, S1_t r_i' + r_i S1_t', S1_t the sum of
    // r over risk set t (floating point; K only steers the steps).
    S1 = J(nt + 1, cols(Xr), 0)
    for (r = 1; r <= N; r++) {
        if (!inr[r]) continue
        S1[lo[r], .] = S1[lo[r], .] + Xr[r, .]
        S1[hi[r] + 1, .] = S1[hi[r] + 1, .] - Xr[r, .]
    }
    for (k = 1; k <= cols(S1); k++) S1[., k] = runningsum(S1[., k])
    Ev = J(N, cols(Xr), 0)
    for (r = 1; r <= N; r++) {
        if (ev[r]) Ev[r, .] = S1[tev[r], .]
    }
    K = (Xr :* (Ar :+ ev :* mt[tev :+ (tev :== 0)]))' * Xr - (Ev' * Xr + Xr' * Ev)
    if (hasmissing(K)) return(0)
    wv = J(cols(Xr), 1, 0)
    kk = J(N, 1, 0)
    for (it = 0; it <= 4; it++) {
        if (it > 0) {
            // Newton step on the exact residual, mapped to R coordinates.
            wv = wv - svsolve(K, Mr' * (Amap' * rho'))
            if (hasmissing(wv)) return(0)
            eta = Xr * wv
            if (max(abs(eta)) >= 0.45) return(0)
            kk = round(eta :* sq)
            kk = rowmin((rowmax((kk, J(N, 1, -kmax))), J(N, 1, kmax)))
        }
        Cr = _iivw_cr_dyadcoef(lo, hi, PD, kk, sq)
        if (hasmissing(Cr)) return(0)
        H = J(1, p, 0)
        Lo = J(1, p, 0)
        Ab = J(1, p, 0)
        AbF = J(1, p, 0)
        nlow = 0
        _iivw_cr_accum(Xo, J(N, p, 0), Cr :* _iivw_cr_pow2(-q), H, Lo, Ab, AbF, nlow)
        if (nlow >= .) return(0)
        rho = H + Lo
        if (hasmissing(rho)) return(0)
        if (it < 2) continue
        // Candidate pairs: the working set; weights 1 + eta_j - eta_i exact.
        cand = uniqrows(Sid)
        if (rows(cand) == 0) return(0)
        yt = 1 :+ (kk[cand[., 2]] - kk[cand[., 1]]) :* _iivw_cr_pow2(-q)
        Ch = J(rows(cand), p, .)
        Cl = J(rows(cand), p, .)
        for (k = 1; k <= rows(cand); k++) {
            _iivw_cr_tsum(Xo[cand[k, 2], .], -Xo[cand[k, 1], .], zr, zl1)
            Ch[k, .] = zr
            Cl[k, .] = zl1
        }
        // Active columns: every column that varies over the rows that enter
        // a pair (a superset of those with a nonzero pair difference, which
        // is what soundness needs; an extra column only blocks the proof).
        rng = colmax(select(Xo, inr)) - colmin(select(Xo, inr))
        ac = _iivw_cr_which(rng :!= 0)'
        if (cols(ac) == 0) return(1)
        cmax = colmax(abs(Ch)) :* (colmax(abs(Ch)) :> 0) :+ abs(rng) :* (colmax(abs(Ch)) :== 0)
        ok = 0
        for (tr = 1; tr <= 2 & !ok; tr++) {
            H2 = H
            Lo2 = Lo
            Ab2 = Ab
            AbF2 = AbF
            nl2 = nlow
            ac2 = ac
            ok = _iivw_cr_stiemke_b(Xo, cand, yt, Ch, Cl, ac2, cmax,
                (tr == 1 ? sc : J(1, p, 0)), H2, Lo2, Ab2, AbF2, nl2, lo, hi, ordlo, PD)
        }
        if (ok) return(1)
    }
    return(0)
}

// Certificate for status 0. By Stiemke's alternative no strict direction
// exists exactly when some y > 0 (one weight per nonzero pair row) has
// sum_k y_k z_k = 0. y is taken from the search: 1/||w_k||_1 on every pair
// (w_k the pair's row in the search coordinates Xw) plus G mu_s/||w_s||_2 on
// the working-set pairs Sid, which make -g = S'mu. Its residual rho on the
// ORIGINAL rows is summed with a rigorous bound and refined by corrections
// on p independent, heavily weighted pairs B; a last exact correction delta
// with Z_B' delta = -rho is then bounded through a verified inverse
// (||I - R A|| <= theta < 1 gives ||A^-1|| <= ||R|| / (1 - theta)). If y_B
// exceeds that bound, y + delta is an exact Stiemke vector: status 0.
real scalar _iivw_cr_stiemke(real matrix Xw, real matrix Xo, real colvector lo,
    real colvector hi, real colvector ordlo, pointer(real colvector) rowvector PD,
    real matrix Sid, real colvector mu, real scalar G, real rowvector sc,
    real matrix Amap)
{
    real rowvector H, Lo, Ab, AbF, cmax, rho, ac, ac2, H2, Lo2, Ab2, AbF2
    real colvector active, D, nr1, y, nz, act, o, yt, ex, tw, wv, svx, kp
    real matrix wt, Zw, Zh, Zl, Zr, pool, cand, zr, zl1, Ch, Cl, K, Mr, Vt, Xc
    real scalar p, m, pos, q, i, nlow, k, kk, j, tr, nl2, rd, y0

    // The O(rows) unit-weight certificate first; the full pass only if it
    // fails.
    if (_iivw_cr_stiemke_fast(Xw, Xo, lo, hi, ordlo, PD, Sid, sc, Amap)) return(1)
    p = cols(Xo)
    // Rounds 2 and 3 reweight every pair by (1 + r_k'v), r_k the pair's row
    // in coordinates where the search rows are well conditioned (right
    // singular vectors of Xw divided by the singular values), v solving
    // K v = -rho for K = sum y r r' accumulated in round 1: a residual along
    // a nearly flat direction (nearly collinear terms) cannot be absorbed by
    // p rows alone, and K in the original coordinates is singular to
    // rounding along it. The weights stay concrete and positive; each pass
    // forms their residual exactly again.
    // Mean-centred: pair differences remove any constant, so a column that is
    // an affine function of the others is flat in the differences.
    // (_svd needs rows >= columns; with fewer rows no rotation is used.)
    if (rows(Xw) >= cols(Xw)) {
        Xc = Xw :- mean(Xw)
        _svd(Xc, svx, Vt)
        kp = _iivw_cr_which(svx :> 1e-300 * max(svx))
        if (rows(kp) == 0) return(0)
        Mr = (Vt[kp, .])' :/ (svx[kp])'
    }
    else Mr = I(cols(Xw))
    wv = J(cols(Mr), 1, 0)
    for (rd = 1; rd <= 3; rd++) {
        H = J(1, p, 0)
        Lo = J(1, p, 0)
        Ab = J(1, p, 0)
        AbF = J(1, p, 0)
        nlow = 0
        cmax = J(1, p, 0)
        pool = J(0, 3, .)
        if (rd == 1) K = J(cols(Mr), cols(Mr), 0)
        active = J(0, 1, .)
        pos = 1
        for (m = 1; m <= cols(PD); m++) {
            _iivw_cr_advance(active, pos, m, lo, hi, ordlo)
            D = *PD[m]
            for (q = 1; q <= rows(D); q++) {
                i = D[q]
                _iivw_cr_tsum(Xo[active, .], -Xo[i, .], Zh, Zl)
                nz = rowsum(Zh :!= 0) :> 0
                if (!any(nz)) continue
                act = select(active, nz)
                Zh = select(Zh, nz)
                Zl = select(Zl, nz)
                Zw = Xw[act, .] :- Xw[i, .]
                Zr = _iivw_cr_rmul(Zw, Mr)
                nr1 = rowsum(abs(Zw))
                // A pair whose search row rounded to zero still needs a
                // positive weight; a tiny one keeps its share negligible.
                y = (1 :/ (nr1 :+ (nr1 :== 0))) :* (nr1 :> 0) :+ (nr1 :== 0) :* (2^-80 :/ rowmax(abs(Zh)))
                if (rd >= 2) {
                    tw = 1 :+ rowsum(Zr :* wv')
                    if (hasmissing(tw) | any(tw :<= 0.5)) return(0)
                    y = y :* tw
                }
                if (hasmissing(y) | any(y :<= 0)) return(0)
                cmax = colmax(cmax \ abs(Zh))
                _iivw_cr_accum(Zh, Zl, y, H, Lo, Ab, AbF, nlow)
                if (rd == 1) K = K + (Zr :* y)' * Zr
                // The heaviest pairs of this risk set (ties in row order).
                maxindex(y, 2 * p, o, wt)
                kk = min((rows(o), 2 * p))
                pool = pool \ (J(kk, 1, i), act[o[|1 \ kk|]], y[o[|1 \ kk|]])
                if (rows(pool) > 16 * p) {
                    o = _iivw_cr_ord(-pool[., 3])
                    pool = pool[o[|1 \ 8 * p|], .]
                }
            }
        }
        if (nlow >= .) return(0)
        ac = _iivw_cr_which(cmax :> 0)'
        if (cols(ac) == 0) return(1)
        // Working-set pairs carry G mu_s / ||w_s||_2 more.
        ex = J(rows(Sid), 1, 0)
        for (k = 1; k <= rows(Sid); k++) {
            if (!(mu[k] > 0)) continue
            zr = Xw[Sid[k, 2], .] - Xw[Sid[k, 1], .]
            if (!(norm(zr) > 0)) continue
            ex[k] = G * mu[k] / norm(zr)
            if (!(ex[k] > 0 & ex[k] < .)) return(0)
            _iivw_cr_tsum(Xo[Sid[k, 2], .], -Xo[Sid[k, 1], .], zr, zl1)
            _iivw_cr_accum(zr, zl1, ex[k], H, Lo, Ab, AbF, nlow)
        }
        if (nlow >= .) return(0)
        // Candidate pairs for B with their total weight (the pass weight,
        // recomputed by the same operations, plus any working-set extra).
        cand = uniqrows(pool[., 1..2] \ Sid)
        yt = J(rows(cand), 1, 0)
        for (k = 1; k <= rows(cand); k++) {
            zr = Xw[cand[k, 2], .] - Xw[cand[k, 1], .]
            if (rowsum(abs(Xo[cand[k, 2], .] - Xo[cand[k, 1], .])) == 0) {
                yt[k] = -1
                continue
            }
            if (rowsum(abs(zr)) > 0) y0 = 1 / rowsum(abs(zr))
            else {
                _iivw_cr_tsum(Xo[cand[k, 2], .], -Xo[cand[k, 1], .], zl1, Zl)
                y0 = 2^-80 / max(abs(zl1))
            }
            if (rd >= 2) y0 = y0 * (1 + rowsum(_iivw_cr_rmul(zr, Mr) :* wv'))
            yt[k] = y0
            for (j = 1; j <= rows(Sid); j++) {
                if (Sid[j, 1] == cand[k, 1] & Sid[j, 2] == cand[k, 2]) yt[k] = yt[k] + ex[j]
            }
        }
        cand = select(cand, yt :> 0)
        yt = select(yt, yt :> 0)
        if (rows(cand) == 0) return(0)
        o = _iivw_cr_ord(-yt)
        cand = cand[o, .]
        yt = yt[o]
        Ch = J(rows(cand), p, .)
        Cl = J(rows(cand), p, .)
        for (k = 1; k <= rows(cand); k++) {
            _iivw_cr_tsum(Xo[cand[k, 2], .], -Xo[cand[k, 1], .], zr, zl1)
            Ch[k, .] = zr
            Cl[k, .] = zl1
        }
        // The rows are judged on power-of-2 columns from the robust spreads,
        // then from the largest entries: each try is rigorous on its own.
        for (tr = 1; tr <= 2; tr++) {
            H2 = H
            Lo2 = Lo
            Ab2 = Ab
            AbF2 = AbF
            nl2 = nlow
            ac2 = ac
            if (_iivw_cr_stiemke_b(Xo, cand, yt, Ch, Cl, ac2, cmax,
                (tr == 1 ? sc : J(1, p, 0)), H2, Lo2, Ab2, AbF2, nl2, lo, hi, ordlo, PD)) return(1)
        }
        if (rd == 3) break
        rho = H + Lo
        if (hasmissing(K) | hasmissing(rho)) return(0)
        // The residual in the well-conditioned coordinates: z_w = Amap' z_o.
        wv = wv - svsolve(K, Mr' * (Amap' * rho'))
        if (hasmissing(wv)) return(0)
    }
    return(0)
}

// The correction and verified-inverse step of _iivw_cr_stiemke for one
// choice of column scales.
real scalar _iivw_cr_stiemke_b(real matrix Xo, real matrix cand, real colvector yt,
    real matrix Ch, real matrix Cl, real rowvector ac, real rowvector cmax,
    real rowvector sc, real rowvector H, real rowvector Lo, real rowvector Ab,
    real rowvector AbF, real scalar nlow, real colvector lo, real colvector hi,
    real colvector ordlo, pointer(real colvector) rowvector PD)
{
    real rowvector rho, eps, rb, dsc, act2, H0, Lo0, Ab0, AbF0
    real colvector ycor, absd, f, dlt, x, ylow, dbnd, sv
    real matrix Bh, Bl, Ah, R, E1, RA, T, zr, zl1
    real scalar p, k, kk, pa, it, ng, theta, nrm, u, nb, red, ok, tol, nl0

    p = cols(Xo)
    u = 2^-53
    H0 = H
    Lo0 = Lo
    Ab0 = Ab
    AbF0 = AbF
    nl0 = nlow
    // B is chosen well conditioned first; nearly collinear terms leave no
    // such choice, and then a nearly singular one is tried (the verified
    // inverse below is what certifies, whatever the conditioning).
    for (tol = 1e-9; tol >= 1e-13; tol = tol * 1e-4) {
    H = H0
    Lo = Lo0
    Ab = Ab0
    AbF = AbF0
    nlow = nl0
    for (red = 0; red <= 1; red++) {
        pa = cols(ac)
        // Exact power-of-2 column scales.
        dsc = _iivw_cr_p2scale(sc[ac], cmax[ac])
        // Greedy choice of pa well-independent rows, heaviest first.
        Bh = J(0, pa, .)
        Bl = J(0, pa, .)
        f = J(0, 1, .)
        nb = 0
        x = J(0, 1, .)
        for (k = 1; k <= rows(cand) & nb < pa; k++) {
            zr = Ch[k, ac] :* dsc
            zl1 = Cl[k, ac] :* dsc
            if (max(abs(zr)) == 0) continue
            kk = _iivw_cr_pow2(-floor(ln(max(abs(zr))) / ln(2)))
            T = (Bh \ (zr :* kk))
            sv = svdsv(T)
            if (min(sv) <= tol * max(sv)) continue
            Bh = T
            Bl = Bl \ (zl1 :* kk)
            f = f \ kk
            x = x \ k
            nb++
        }
        if (nb == pa | red) break
        // Fewer independent rows than columns: drop columns that exact null
        // vectors show to be combinations of the others.
        act2 = _iivw_cr_reduce(Ch, Cl, ac, Xo, lo, hi, ordlo, PD, 1, sc)
        if (cols(act2) == cols(ac)) break
        ac = act2
    }
    if (nb < pa) continue
    // B rows in original units are diag(1/f) (Bh + Bl) diag(1/dsc).
    ycor = J(pa, 1, 0)
    absd = J(pa, 1, 0)
    Ah = Bh'
    R = luinv(Ah)
    if (hasmissing(R)) continue
    for (it = 1; it <= 8; it++) {
        rho = (H + Lo)[ac]
        // Ah' z = -D rho with z = delta / f.
        dlt = -(R * (rho :* dsc)') :* f
        if (hasmissing(dlt)) break
        if (all(dlt :== 0)) break
        ycor = ycor + dlt
        absd = absd + abs(dlt)
        for (k = 1; k <= pa; k++) {
            if (dlt[k] == 0) continue
            _iivw_cr_tsum(Xo[cand[x[k], 2], .], -Xo[cand[x[k], 1], .], zr, zl1)
            _iivw_cr_accum(zr, zl1, dlt[k], H, Lo, Ab, AbF, nlow)
        }
        if (nlow >= .) break
    }
    if (hasmissing(dlt) | nlow >= .) continue
    // Rigorous bound on the exact residual.
    ng = (nlow + 4) * u
    if (ng >= 0.01) continue
    ng = ng / (1 - ng)
    rho = H + Lo
    eps = 2 * ng :* Ab :+ 2 * u :* AbF :+ 2 * u :* abs(rho) :+ 1e-290
    rb = (abs(rho) + eps)[ac]
    // max() skips missing values, so an overflowed residual must stop here.
    if (hasmissing(rb) | hasmissing(H) | hasmissing(Lo) | hasmissing(Ab)) continue
    // Verified inverse of the exact Ah = Ahh + Ahl, |Ahl| <= u |Ahh|.
    E1 = I(pa) - R * Ah
    RA = abs(R) * abs(Ah)
    theta = max(rowsum(abs(E1))) + 2 * (pa + 2) * u * max(rowsum(I(pa) + RA)) +
        2 * u * max(rowsum(RA))
    theta = theta * (1 + 1e-10) + 1e-300
    if (!(theta < 0.5)) continue
    nrm = max(rowsum(abs(R))) * (1 + 1e-10) / (1 - theta)
    dbnd = f :* (nrm * max(rb :* dsc) * (1 + 1e-10))
    ylow = (yt[x] + ycor) - 1e-12 :* (yt[x] + absd)
    ok = all(ylow :> dbnd)
    if (ok) return(1)
    }
    return(0)
}

// Repair a candidate a0 (original coordinates) that failed the exact check
// only through rounding. An extreme ray of {a : Z a >= 0} is orthogonal to
// pa - 1 independent rows (pa = columns that vary on some pair), so it is
// their exact generalized cross product. The rows closest to tight under a0
// are collected, a few independent ones are kept, and each (pa - 1)-subset
// gives an exact ray, screened on the collected rows and then checked
// exactly on every pair. Returns 1 with the verified ray in Ax.
real scalar _iivw_cr_snap(real matrix Xo, real colvector lo, real colvector hi,
    real colvector ordlo, pointer(real colvector) rowvector PD, real colvector a0,
    real matrix Ax, real rowvector sc)
{
    real colvector active, D, nz, rel, o, c, sg, x, sv
    real rowvector cmax, act, dsc
    real matrix Zh, Zl, Bh, Bl, Ch, Cl, Cn, V, Vx, xid, T, bid, wt, tried
    real scalar m, pos, q, i, p, pa, k, kk, nsel, s, xs, mx

    p = cols(Xo)
    // The plain integer roundings of a0 first, each checked exactly with a
    // stop at the first violated pair: when the direction is an integer
    // combination (a lag copy changed on one row) this settles it without
    // the collection pass below.
    mx = max(abs(a0))
    if (mx > 0 & mx < .) {
        tried = J(0, p, .)
        for (k = 1; k <= p; k++) {
            if (abs(a0[k]) < 0.05 * mx) continue
            c = round(a0 :/ a0[k]) :* sign(a0[k])
            if (all(c :== 0) | _iivw_cr_hasrow(tried, c')) continue
            tried = tried \ c'
            if (_iivw_cr_xverify(Xo, lo, hi, ordlo, PD, c, xid, 1) == 1) {
                Ax = c
                return(1)
            }
        }
    }
    // Collect the pairs nearest to tight (float slacks rank them; only the
    // kept pairs are formed exactly).
    bid = J(0, 2, .)
    rel = J(0, 1, .)
    cmax = J(1, p, 0)
    active = J(0, 1, .)
    pos = 1
    for (m = 1; m <= cols(PD); m++) {
        _iivw_cr_advance(active, pos, m, lo, hi, ordlo)
        D = *PD[m]
        for (q = 1; q <= rows(D); q++) {
            i = D[q]
            Zh = Xo[active, .] :- Xo[i, .]
            nz = rowsum(Zh :!= 0) :> 0
            if (!any(nz)) continue
            Zh = select(Zh, nz)
            cmax = colmax(cmax \ abs(Zh))
            x = abs(Zh * a0) :/ (abs(Zh) * abs(a0) :+ 1e-300)
            minindex(x, 16 * p, o, wt)
            kk = min((rows(o), 16 * p))
            o = o[|1 \ kk|]
            bid = bid \ (J(kk, 1, i), select(active, nz)[o])
            rel = rel \ x[o]
            if (rows(bid) > 64 * p) {
                o = _iivw_cr_ord(rel)
                o = o[|1 \ 16 * p|]
                bid = bid[o, .]
                rel = rel[o]
            }
        }
    }
    Bh = J(rows(bid), p, .)
    Bl = J(rows(bid), p, .)
    for (k = 1; k <= rows(bid); k++) {
        _iivw_cr_tsum(Xo[bid[k, 2], .], -Xo[bid[k, 1], .], Zh, Zl)
        Bh[k, .] = Zh
        Bl[k, .] = Zl
    }
    act = _iivw_cr_which(cmax :> 0)'
    if (cols(act) == 0 | rows(Bh) == 0) return(0)
    // Directions with small integer ratios in the original columns (a lag
    // equal to the sum of two others, up to rounding of the data) are the
    // ones a floating candidate cannot hit exactly when every slack cancels
    // to the last bits: round a0 to integer vectors and check them exactly.
    if (_iivw_cr_ratsnap(Xo, lo, hi, ordlo, PD, a0, Bh, Bl, Ax)) return(1)
    act = _iivw_cr_reduce(Bh, Bl, act, Xo, lo, hi, ordlo, PD, 1, sc)
    pa = cols(act)
    if (pa == 1) {
        // One column left: the direction is +/- that column.
        for (s = 1; s >= -1; s = s - 2) {
            Vx = J(p, 1, 0)
            Vx[act] = s
            if (_iivw_cr_xverify(Xo, lo, hi, ordlo, PD, Vx, xid, 1) == 1) {
                Ax = Vx
                return(1)
            }
        }
        return(0)
    }
    if (pa > 5) return(0)
    o = _iivw_cr_ord(rel)
    Bh = Bh[o, act]
    Bl = Bl[o, act]
    for (k = 1; k <= 2; k++) {
        if (_iivw_cr_snap_b(Xo, lo, hi, ordlo, PD, Bh, Bl, act, (k == 1 ? sc[act] : J(1, pa, 0)), Ax)) return(1)
    }
    return(0)
}

// 1 if the row vector v is already a row of S (exact equality).
real scalar _iivw_cr_hasrow(real matrix S, real rowvector v)
{
    if (rows(S) == 0) return(0)
    return(any(rowsum(S :== v) :== cols(S)))
}

// Integer roundings of a candidate a0: for each pivot component k (|a0_k| at
// least 5% of the largest) and denominators D = 1, 2, 3, 4, 6, 12, the
// integer vector round(D a0 / a0_k) sign(a0_k), screened on the collected
// rows Bh + Bl and then checked exactly on every pair. Returns 1 with the
// verified direction in Ax.
real scalar _iivw_cr_ratsnap(real matrix Xo, real colvector lo, real colvector hi,
    real colvector ordlo, pointer(real colvector) rowvector PD, real colvector a0,
    real matrix Bh, real matrix Bl, real matrix Ax)
{
    real colvector c, sg, dd
    real matrix tried, xid
    real scalar k, i, mx

    mx = max(abs(a0))
    if (!(mx > 0 & mx < .)) return(0)
    dd = (1 \ 2 \ 3 \ 4 \ 6 \ 12)
    tried = J(0, rows(a0), .)
    for (k = 1; k <= rows(a0); k++) {
        if (abs(a0[k]) < 0.05 * mx) continue
        for (i = 1; i <= rows(dd); i++) {
            c = round(dd[i] :* a0 :/ a0[k]) :* sign(a0[k])
            if (all(c :== 0) | max(abs(c)) > 1e6) continue
            if (_iivw_cr_hasrow(tried, c')) continue
            tried = tried \ c'
            sg = _iivw_cr_xslack(Bh, Bl, c)
            if (hasmissing(sg) | any(sg :== -1)) continue
            if (_iivw_cr_xverify(Xo, lo, hi, ordlo, PD, c, xid, 1) == 1) {
                Ax = c
                return(1)
            }
        }
    }
    return(0)
}

// Subset enumeration of _iivw_cr_snap for one choice of column scales; Bh,
// Bl hold the collected rows on the active columns act, nearest to tight
// first.
real scalar _iivw_cr_snap_b(real matrix Xo, real colvector lo, real colvector hi,
    real colvector ordlo, pointer(real colvector) rowvector PD, real matrix Bh,
    real matrix Bl, real rowvector act, real rowvector sca, real matrix Ax)
{
    real colvector c, sg, sv
    real rowvector dsc
    real matrix Ch, Cl, Cn, V, Vx, xid, T
    real scalar p, pa, k, kk, nsel, s, xs

    p = cols(Xo)
    pa = cols(act)
    // Independent rows, nearest to tight first (pa of them, judged on
    // power-of-2 equilibrated columns), then a few more that are not
    // parallel to a kept row, so a near-tight non-tight row taken early
    // does not block the ray.
    Ch = J(0, pa, .)
    Cl = J(0, pa, .)
    Cn = J(0, pa, .)
    dsc = _iivw_cr_p2scale(sca, colmax(abs(Bh)))
    for (k = 1; k <= rows(Bh) & rows(Ch) < pa + 3; k++) {
        T = Bh[k, .] :* dsc
        if (max(abs(T)) == 0) continue
        T = Cn \ (T :/ norm(T))
        if (rows(T) > 1) {
            if (rows(T) <= pa) {
                sv = svdsv(T)
                if (min(sv) <= 1e-10 * max(sv)) continue
            }
            else if (max(abs(Cn * T[rows(T), .]')) >= 1 - 1e-12) continue
        }
        Cn = T
        Ch = Ch \ Bh[k, .]
        Cl = Cl \ Bl[k, .]
    }
    nsel = rows(Ch)
    if (nsel < pa - 1) return(0)
    c = (1::pa - 1)
    while (1) {
        V = _iivw_cr_gcp(Ch[c, .], Cl[c, .])
        if (!hasmissing(V) & any(rowsum(V) :!= 0)) {
            for (s = 1; s >= -1; s = s - 2) {
                Vx = J(p, cols(V), 0)
                Vx[act, .] = s * V
                sg = _iivw_cr_xslack(Bh, Bl, Vx[act, .])
                if (any(sg :== -1) | hasmissing(sg)) continue
                xs = _iivw_cr_xverify(Xo, lo, hi, ordlo, PD, Vx, xid, 1)
                if (xs == 1) {
                    Ax = Vx
                    return(1)
                }
            }
        }
        // next (pa - 1)-subset of 1..nsel
        kk = pa - 1
        while (kk >= 1) {
            if (c[kk] != nsel - (pa - 1) + kk) break
            kk--
        }
        if (kk < 1) break
        c[kk] = c[kk] + 1
        for (k = kk + 1; k <= pa - 1; k++) c[k] = c[k - 1] + 1
    }
    return(0)
}

// Exact powers of two 2^k (k integer, clamped to -1074..1023), elementwise.
// Mata's 2^k is not exact (off by ~1e-16 relative for most k, e.g. 2^-69),
// and a scaling that is not an exact power of two breaks every exactness
// argument below; repeated squaring of 2 or 1/2 multiplies exact powers of
// two only, so each product is exact.
real matrix _iivw_cr_pow2(real matrix k)
{
    real matrix out
    real scalar i, j, p, b, n

    out = J(rows(k), cols(k), .)
    for (i = 1; i <= rows(k); i++) {
        for (j = 1; j <= cols(k); j++) {
            if (k[i, j] >= .) continue
            n = trunc(k[i, j])
            if (n < -1074) n = -1074
            if (n > 1023) n = 1023
            p = 1
            b = (n < 0 ? 0.5 : 2)
            n = abs(n)
            while (n > 0) {
                if (mod(n, 2) == 1) p = p * b
                n = floor(n / 2)
                if (n > 0) b = b * b
            }
            out[i, j] = p
        }
    }
    return(out)
}

// Power-of-2 column scales (exact multipliers) from the robust spreads sc of
// the search, falling back to the largest entry cm where a spread is 0: an
// outlier must not set the scale of its column.
real rowvector _iivw_cr_p2scale(real rowvector sc, real rowvector cm)
{
    real rowvector b

    b = sc :* (sc :> 0) :+ cm :* !(sc :> 0)
    b = b :+ (b :<= 0)
    return(_iivw_cr_pow2(-floor(ln(b) :/ ln(2))))
}

// Exact column reduction for rank-deficient pair rows. If an exact null
// vector n (Z n = 0 on EVERY pair row) has n_k != 0, column k is an exact
// combination of the others on every row: Z a = Z_-k (a_-k - (a_k/n_k) n_-k)
// and z_k'y = -(1/n_k) sum_l n_l z_l'y, so dropping it leaves both the set of
// slack vectors and the Stiemke vectors unchanged. Null vectors are proposed
// from r numerically independent rows (Rh + Rl, a sample or all rows) as
// exact cross products with unit vectors, and accepted only if every slack
// is exactly 0: on all pair rows (Xo given, full = 1) or on Rh + Rl (full =
// 0, when they are all the rows). Returns the reduced active columns.
real rowvector _iivw_cr_reduce(real matrix Rh, real matrix Rl, real rowvector act0,
    real matrix Xo, real colvector lo, real colvector hi, real colvector ordlo,
    pointer(real colvector) rowvector PD, real scalar full, real rowvector sc)
{
    real rowvector act, cm, dsc, cl, uc
    real colvector ix, sg, c, vf
    real matrix T, Th, Tl, V, Vx, xid, Bn
    real scalar pa, r, k, nu, kk, found, l, xs, p, cnt

    act = act0
    p = cols(Xo)
    for (cnt = 1; cnt <= p; cnt++) {
        pa = cols(act)
        if (pa <= 1 | rows(Rh) == 0) return(act)
        cm = colmax(abs(Rh[., act]))
        if (any(cm :== 0)) return(act)
        dsc = _iivw_cr_p2scale(sc[act], cm)
        ix = J(0, 1, .)
        Bn = J(0, pa, .)
        for (k = 1; k <= rows(Rh) & rows(ix) < pa; k++) {
            T = Rh[k, act] :* dsc
            if (max(abs(T)) == 0) continue
            T = Bn \ (T :/ norm(T))
            if (rows(T) > 1) {
                if (min(svdsv(T)) <= 1e-9 * max(svdsv(T))) continue
            }
            Bn = T
            ix = ix \ k
        }
        r = rows(ix)
        if (r == pa | r == 0) return(act)
        nu = pa - 1 - r
        found = 0
        c = (1::nu)
        while (!found) {
            Th = Rh[ix, act]
            Tl = Rl[ix, act]
            if (nu > 0) {
                uc = J(nu, pa, 0)
                for (k = 1; k <= nu; k++) uc[k, c[k]] = 1
                Th = Th \ uc
                Tl = Tl \ J(nu, pa, 0)
            }
            V = _iivw_cr_gcp(Th, Tl)
            if (!hasmissing(V) & any(V :!= 0)) {
                if (full) {
                    Vx = J(p, cols(V), 0)
                    Vx[act, .] = V
                    xs = _iivw_cr_xverify(Xo, lo, hi, ordlo, PD, Vx, xid, 1)
                    found = (xs == 0)
                }
                else {
                    sg = _iivw_cr_xslack(Rh[., act], Rl[., act], V)
                    found = !hasmissing(sg) & all(sg :== 0)
                }
                if (found) {
                    // The pivot must be exactly nonzero (signed exactly).
                    sg = _iivw_cr_xsign(V)
                    vf = abs(rowsum(V)) :* (sg :!= 0) :* (sg :< .)
                    l = _iivw_cr_argmin(-vf)
                    if (!(vf[l] > 0)) found = 0
                    else act = select(act, (1..pa) :!= l)
                }
            }
            if (found | nu == 0) break
            kk = nu
            while (kk >= 1) {
                if (c[kk] != pa - nu + kk) break
                kk--
            }
            if (kk < 1) break
            c[kk] = c[kk] + 1
            for (k = kk + 1; k <= nu; k++) c[k] = c[k - 1] + 1
        }
        if (!found) return(act)
    }
    return(act)
}

// Small problems decided exactly. Every distinct nonzero pair row is
// collected; pa columns vary on some pair. If Z has full column rank pa on
// them (an exactly nonzero pa x pa minor), the cone {a : Z a >= 0} is pointed
// (on the varying columns; the others carry no constraint), so it holds a
// strict direction exactly when it has an extreme ray, and every extreme ray
// is the generalized cross product of some pa - 1 independent rows. All
// (pa - 1)-subsets are tried exactly: one verifying gives status 1, none
// gives status 0. Returns 2 when the problem is too large, a slack cannot be
// signed, or full rank is not shown.
real scalar _iivw_cr_xsmall(real matrix Xo, real colvector lo, real colvector hi,
    real colvector ordlo, pointer(real colvector) rowvector PD, real matrix Ax,
    real scalar maxrows, real scalar maxsub, real rowvector sc)
{
    pointer(real rowvector) matrix E
    real colvector active, D, nz, c, sg, o
    real rowvector cmax, act, dt, dsc
    real matrix Zh, Zl, Rh, Rl, V, T, Bh, Bl, Bn
    real scalar m, pos, q, i, p, pa, n, k, kk, s, unsure, nb, r

    p = cols(Xo)
    Rh = J(0, p, .)
    Rl = J(0, p, .)
    active = J(0, 1, .)
    pos = 1
    for (m = 1; m <= cols(PD); m++) {
        _iivw_cr_advance(active, pos, m, lo, hi, ordlo)
        D = *PD[m]
        for (q = 1; q <= rows(D); q++) {
            i = D[q]
            _iivw_cr_tsum(Xo[active, .], -Xo[i, .], Zh, Zl)
            nz = rowsum(Zh :!= 0) :> 0
            if (!any(nz)) continue
            Rh = Rh \ select(Zh, nz)
            Rl = Rl \ select(Zl, nz)
            if (rows(Rh) > 4 * maxrows) {
                T = uniqrows((Rh, Rl))
                Rh = T[., 1..p]
                Rl = T[., (p + 1)..(2 * p)]
                if (rows(Rh) > maxrows) return(2)
            }
        }
    }
    if (rows(Rh) == 0) return(0)
    T = uniqrows((Rh, Rl))
    Rh = T[., 1..p]
    Rl = T[., (p + 1)..(2 * p)]
    n = rows(Rh)
    if (n > maxrows) return(2)
    cmax = colmax(abs(Rh))
    act = _iivw_cr_which(cmax :> 0)'
    if (cols(act) == 0) return(0)
    act = _iivw_cr_reduce(Rh, Rl, act, Xo, lo, hi, ordlo, PD, 0, sc)
    pa = cols(act)
    if (pa > 5) return(2)
    if (pa == 1) {
        // One varying column: the signs of its differences are exact.
        sg = sign(Rh[., act])
        Ax = J(p, 1, 0)
        if (all(sg :>= 0)) Ax[act] = 1
        else if (all(sg :<= 0)) Ax[act] = -1
        else return(0)
        return(1)
    }
    if (n < pa - 1 | comb(n, pa - 1) > maxsub) return(2)
    Rh = Rh[., act]
    Rl = Rl[., act]
    unsure = 0
    c = (1::pa - 1)
    while (1) {
        V = _iivw_cr_gcp(Rh[c, .], Rl[c, .])
        if (hasmissing(V)) unsure = 1
        else if (any(V :!= 0)) {
            // The completeness argument needs V exactly orthogonal to the
            // rows that define it; if it is not, nothing is proven here.
            sg = _iivw_cr_xslack(Rh[c, .], Rl[c, .], V)
            if (hasmissing(sg) | any(sg :!= 0)) {
                unsure = 1
                V = J(rows(V), cols(V), 0)
            }
        }
        if (hasmissing(V)) {
        }
        else if (any(V :!= 0)) {
            sg = _iivw_cr_xslack(Rh, Rl, V)
            if (hasmissing(sg)) unsure = 1
            else if (any(sg :!= 0)) {
                s = 0
                if (all(sg :>= 0)) s = 1
                else if (all(sg :<= 0)) s = -1
                if (s != 0) {
                    Ax = J(p, cols(V), 0)
                    Ax[act, .] = s * V
                    return(1)
                }
            }
        }
        kk = pa - 1
        while (kk >= 1) {
            if (c[kk] != n - (pa - 1) + kk) break
            kk--
        }
        if (kk < 1) break
        c[kk] = c[kk] + 1
        for (k = kk + 1; k <= pa - 1; k++) c[k] = c[k - 1] + 1
    }
    if (unsure) return(2)
    // Full column rank: pa rows (chosen numerically) with an exactly
    // nonzero determinant.
    // (numerically on power-of-2 equilibrated columns; the determinant is exact)
    Bh = J(0, pa, .)
    Bl = J(0, pa, .)
    Bn = J(0, pa, .)
    dsc = _iivw_cr_p2scale(sc[act], colmax(abs(Rh)))
    for (k = 1; k <= n & rows(Bh) < pa; k++) {
        T = Rh[k, .] :* dsc
        T = Bn \ (T :/ norm(T))
        if (min(svdsv(T)) <= 1e-12 * max(svdsv(T))) continue
        Bn = T
        Bh = Bh \ Rh[k, .]
        Bl = Bl \ Rl[k, .]
    }
    if (rows(Bh) < pa) return(2)
    E = J(pa, pa, NULL)
    for (r = 1; r <= pa; r++) {
        for (k = 1; k <= pa; k++) {
            E[r, k] = &(_iivw_cr_xcomp((Bh[r, k], Bl[r, k])))
        }
    }
    dt = _iivw_cr_xdet(E)
    if (hasmissing(dt)) return(2)
    if (all(dt :== 0)) return(2)
    return(0)
}

end
