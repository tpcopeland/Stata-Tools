*! _iivw_mlib Version 1.0.1  2026/10/30
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
// its column. The decision is then a cone-membership test solved by
// nonnegative least squares (_iivw_cr_search, which states the argument),
// with every accepted direction verified on every (event, at-risk) pair.
// A slack is judged against the size of the terms forming it (a
// floating-point error bound), never against a fitted coefficient.
//
// Risk sets are swept in event-time order (rows enter when their run of
// event times starts and leave after it ends), so memory is O(rows) and a
// pass costs the total size of the risk sets.
//
// Returns 1 x (p + 1): status (0 a finite maximum exists, 1 a verified
// recession direction exists, 2 the search did not settle), then for each
// covariate 1 if some verified direction moves it.
real rowvector _iivw_cox_recession(string scalar t0v, string scalar tv,
    string scalar dv, string scalar xvars, string scalar tousev)
{
    real colvector T0, T, Dd, ev, a, x, lo, hi, ordlo, cc, w, sv, keep
    real matrix X, S, stat, U, Vt, M, Xw, Xr
    real rowvector out, g
    real scalar p, N, k, status, sc, gs
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
    ordlo = order(lo, 1)
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

    for (k = 1; k <= p; k++) {
        x = X[., k]
        X[., k] = _iivw_cr_rscale(x)
    }
    g = _iivw_cr_pass(X, lo, hi, ordlo, PD, J(p, 1, .), 0, cc, w, J(p, 1, 0))
    if (max(abs(g)) == 0 | hasmissing(g)) return(out)
    gs = w[1] / max(abs(g))
    g = g :/ max(abs(g))
    S = J(0, p, .)
    status = _iivw_cr_search(X, lo, hi, ordlo, PD, S, g, a, gs)
    M = I(p)

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
    if (status == 2) {
        Xw = X
        for (k = 1; k <= p; k++) {
            sc = _iivw_cr_rspread(X[., k])
            if (sc > 0 & sc < .) Xw[., k] = rowmin((rowmax((Xw[., k], J(N, 1, -50 * sc))), J(N, 1, 50 * sc)))
        }
        svd(Xw, U, sv, Vt)
        if (min(sv) < 1e-6 * max(sv)) {
            M = Vt' :/ sv'
            keep = J(0, 1, .)
            for (k = 1; k <= cols(M); k++) {
                if (norm(X * Vt[k, .]') > 1e-13 * norm(X)) keep = keep \ k
            }
            if (rows(keep) == 0) return(out)
            M = M[., keep]
            Xr = X * M
            for (k = 1; k <= cols(Xr); k++) {
                sc = _iivw_cr_rspread(Xr[., k])
                if (sc > 0 & sc < .) {
                    Xr[., k] = Xr[., k] :/ sc
                    M[., k] = M[., k] :/ sc
                }
            }
            g = _iivw_cr_pass(Xr, lo, hi, ordlo, PD, J(cols(Xr), 1, .), 0, cc, w, J(cols(Xr), 1, 0))
            if (max(abs(g)) == 0 | hasmissing(g)) return(out)
            gs = w[1] / max(abs(g))
            g = g :/ max(abs(g))
            S = J(0, cols(Xr), .)
            status = _iivw_cr_search(Xr, lo, hi, ordlo, PD, S, g, a, gs)
        }
    }
    out[1] = status
    // The terms named are those the verified direction moves, mapped back
    // to the original terms (a'(M'd) = (Ma)'d).
    if (status == 1) {
        a = M * a
        out[|2 \ p + 1|] = (abs(a') :> 1e-7 * max(abs(a)))
    }
    return(out)
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
// time, cc with their violations, and w[1] with the largest slack seen.
real matrix _iivw_cr_pass(real matrix X, real colvector lo, real colvector hi,
    real colvector ordlo, pointer(real colvector) rowvector PD, real colvector a,
    real scalar mode, real colvector cc, real colvector w, | real colvector errv,
    real scalar kstop)
{
    real colvector active, D, nr, s, sz, rs
    real matrix Z, V, g
    real scalar m, pos, q, i, best, kk

    g = J(1, cols(X), 0)
    V = J(0, cols(X), .)
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
                }
            }
        }
    }
    w = best
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
// Returns 0 (no strict direction), 1 (a verified one, in a), 2 (did not
// settle: no new violated pair could be added, or 500 rounds).
real scalar _iivw_cr_search(real matrix X, real colvector lo, real colvector hi,
    real colvector ordlo, pointer(real colvector) rowvector PD, real matrix S,
    real rowvector g, real colvector a, real scalar gs)
{
    real matrix V
    real colvector cc, w, o, mu, r, errv
    real scalar it, n, nb, ng, bound, summu, aerr, tight, gray

    // The membership decision must not depend on how many pairs there are
    // or on ||g||: one strict pair among 10^8 flat ones moves -g out of the
    // cone by only ~1/10^8 of ||g||, so a bound proportional to ||g|| (or a
    // fixed relative one) swamps it. The bound is the floating-point error
    // of the quantities themselves: g is a sum of gs unit-1-norm terms (gs
    // = pairs / max|g| after g is scaled to max|g| = 1), and the residual
    // adds sum(mu) unit rows; each sum carries ~eps per term.
    ng = sqrt(g * g')
    for (it = 1; it <= 500; it++) {
        bound = 1e2 * 2.2e-16 * (gs + ng)
        tight = bound
        summu = 0
        if (rows(S) == 0) r = -g'
        else {
            mu = _iivw_cr_nnls(S', -g')
            r = -g' - S' * mu
            // The residual is computed from a sum of unit rows weighted by
            // mu, so its rounding error grows with sum(mu): a near-parallel
            // pair (x and x + 1e-9 e_k) can generate a tiny direction only
            // with weights near 1e9, leaving ~1e-7 of pure cancellation.
            // A residual inside that error bound is membership.
            summu = sum(mu)
            bound = bound + 1e2 * 2.2e-16 * summu
        }
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
        a = a :* (abs(a) :>= aerr)
        errv = aerr :* ((a :!= 0) :& (abs(a) :!= 1))
        V = _iivw_cr_pass(X, lo, hi, ordlo, PD, a, 1, cc, w, errv, 8 * (2 * cols(X) + 4))
        if (rows(V) == 0) {
            if (w[1] > 1) return(1)
            return(0)
        }
        if (gray) return(2)
        o = order(cc, 1)
        n = min((rows(o), 2 * cols(X) + 4))
        nb = rows(S)
        S = uniqrows(S \ V[o[|1 \ n|], .])
        if (rows(S) == nb) return(2)
    }
    return(2)
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

end
