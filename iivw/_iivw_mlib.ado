*! _iivw_mlib Version 4.3.2  2026/09/29
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

end
