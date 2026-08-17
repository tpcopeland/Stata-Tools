*! _iivw_mlib Version 3.4.3  2026/08/17
*! iivw's Mata source. Contains NO Stata program: this file is -run-, never
*! autoloaded.
*! Author: Timothy P Copeland, Karolinska Institutet

* Why this file defines no program
* --------------------------------
* Stata's ado autoloader does not EXECUTE an ado file. It reads it far enough to
* define the program being called, and nothing else in the file runs -- so a
* -mata:- block in an ado file is never compiled by an autoload, whether it sits
* above or below the program. Measured, not assumed: -run- on this file compiles
* _iivw_stacked_core() and calling an autoloaded program in the same file leaves
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
void _iivw_stacked_core(string scalar xvars,
                        string scalar breadvar,
                        string scalar resvar,
                        string scalar ndvars,
                        string scalar nsvars,
                        string scalar cidxvar,
                        string scalar tousevar,
                        string scalar ainvname,
                        real scalar M,
                        string scalar vsname,
                        string scalar vfname,
                        string scalar gname)
{
    real matrix X, ND, NS, D, Dinv, G, Ainv, Ufix, Ustk, Vs, Vf, S
    real colvector BW, R, C
    real scalar j, N, p, q, cf, dev, worst

    st_view(X = .,  ., tokens(xvars),   tousevar)
    st_view(BW = ., ., breadvar,        tousevar)
    st_view(R = .,  ., resvar,          tousevar)
    st_view(ND = ., ., tokens(ndvars),  tousevar)
    st_view(NS = ., ., tokens(nsvars),  tousevar)
    st_view(C = .,  ., cidxvar,         tousevar)

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
    S    = J(M, q, .)
    worst = 0
    for (j = 1; j <= N; j++) {
        Ufix[C[j], .] = Ufix[C[j], .] + X[j, .] :* R[j]
        if (S[C[j], 1] == .) {
            S[C[j], .] = NS[j, .]
        }
        else {
            dev = mreldif(S[C[j], .], NS[j, .])
            if (dev > worst) worst = dev
        }
    }
    if (worst > 1e-10) {
        errprintf("stacked variance: the nuisance score columns are not")
        errprintf(" constant within cluster\n")
        errprintf("  worst within-cluster relative difference %g\n", worst)
        errprintf("  re-run iivw_weight, scores\n")
        exit(459)
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
    cf = M / (M - 1)

    Vf = Dinv * quadcross(Ufix, Ufix) * Dinv * cf
    Vs = Dinv * quadcross(Ustk, Ustk) * Dinv * cf

    st_matrix(vsname, makesymmetric(Vs))
    st_matrix(vfname, makesymmetric(Vf))
    st_matrix(gname, G)
}

end
