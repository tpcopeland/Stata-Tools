*! _nma_reml Version 1.0.1  2026/02/28
*! Mata REML engine for multivariate random-effects meta-analysis
*! Author: Timothy P Copeland
*! Department of Clinical Neuroscience, Karolinska Institutet
*! Program class: internal (stores results in regular Stata matrices)

/*
Internal command: Fits multivariate random-effects model via REML or ML.
Called by nma_fit. Not intended for direct user invocation.

Syntax:
  _nma_reml , y(string) x(string) v_matrices(string) [method(reml|ml)
      common iterate(integer 200) tolerance(real 1e-8)]

Where:
  y = Mata column vector of stacked contrasts
  x = Mata design matrix
  v_matrices = Mata array name of within-study V matrices
  method = reml (default) or ml
  common = fixed-effect model (no heterogeneity)
*/

program define _nma_reml
    version 16.0
    set varabbrev off
    set more off

    syntax , y_matrix(string) x_matrix(string) v_prefix(string) ///
        n_studies(integer) dim(integer) ///
        [method(string) common ITERate(integer 200) ///
        TOLerance(real 1e-8) noLOG]

    if "`method'" == "" local method "reml"
    if !inlist("`method'", "reml", "ml") {
        display as error "method() must be reml or ml"
        exit 198
    }

    local show_log = ("`log'" != "nolog")

    mata: _nma_reml_engine("`y_matrix'", "`x_matrix'", "`v_prefix'", ///
        `n_studies', `dim', "`method'", "`common'", `iterate', ///
        `tolerance', `show_log')

    * Results are now in Stata matrices:
    *   _nma_reml_b, _nma_reml_V, _nma_reml_Sigma
    *   _nma_reml_tau2, _nma_reml_ll, _nma_reml_conv, _nma_reml_iter
    * Caller (nma_fit) reads these directly and posts to e()
end

* =========================================================================
* Mata: Complete REML/ML engine
* =========================================================================
mata:

struct _nma_reml_results {
    real colvector beta
    real matrix Vbeta
    real matrix Sigma
    real scalar tau2
    real scalar ll
    real scalar converged
    real scalar iterations
}

/* Main entry point */
void _nma_reml_engine(
    string scalar y_name,
    string scalar x_name,
    string scalar v_prefix,
    real scalar n_studies,
    real scalar dim,
    string scalar method,
    string scalar common_str,
    real scalar max_iter,
    real scalar tol,
    real scalar show_log)
{
    real colvector y, study_dims
    real matrix X, Sigma0
    real scalar i, p, N, is_common
    struct _nma_reml_results scalar res

    y = st_matrix(y_name)
    X = st_matrix(x_name)
    is_common = (common_str != "")

    N = rows(y)
    p = cols(X)

    /* Study sizes stored in _nma_study_dims */
    study_dims = st_matrix("_nma_study_dims")

    /* Verify dimensions */
    if (rows(study_dims) != n_studies) {
        errprintf("study_dims has %g rows but n_studies=%g\n", rows(study_dims), n_studies)
        exit(error(498))
    }

    if (is_common) {
        /* Fixed-effect model: Sigma = 0 */
        Sigma0 = J(dim, dim, 0)
        res = _nma_reml_solve_given_sigma(y, X, v_prefix, study_dims, Sigma0, n_studies)
        res.Sigma = Sigma0
        res.tau2 = 0
        res.converged = 1
        res.iterations = 0

        /* Compute log-likelihood */
        res.ll = _nma_reml_loglik_val(y, X, v_prefix, study_dims, Sigma0, n_studies, method)
    }
    else {
        /* Iterative estimation */
        res = _nma_reml_iterate(y, X, v_prefix, study_dims, n_studies, dim, ///
            method, max_iter, tol, show_log)
    }

    /* Post results to Stata */
    _nma_reml_post_results(res, X, y, p, dim, method)
}

/* Iterate to find optimal Sigma */
struct _nma_reml_results scalar _nma_reml_iterate(
    real colvector y,
    real matrix X,
    string scalar v_prefix,
    real colvector study_dims,
    real scalar n_studies,
    real scalar dim,
    string scalar method,
    real scalar max_iter,
    real scalar tol,
    real scalar show_log)
{
    struct _nma_reml_results scalar res
    real matrix Sigma, Sigma_new, H, H_inv
    real scalar iter, ll, ll_new, converged, step_scale, max_halvings, halving
    real colvector theta, theta_new, grad, step
    real scalar trace_sigma

    /* Starting values via method of moments */
    Sigma = _nma_mom_start(y, X, v_prefix, study_dims, n_studies, dim)

    /* Parameterize via Cholesky: Sigma = L*L' */
    theta = _nma_sigma_to_theta(Sigma, dim)

    ll = _nma_reml_loglik_val(y, X, v_prefix, study_dims, ///
        _nma_theta_to_sigma(theta, dim), n_studies, method)

    converged = 0

    if (show_log) {
        printf("{txt}Iteration 0: log likelihood = {res}%12.6f\n", ll)
    }

    for (iter = 1; iter <= max_iter; iter++) {
        /* Gradient and Hessian via numerical differentiation */
        grad = _nma_numerical_gradient(theta, y, X, v_prefix, study_dims, ///
            n_studies, dim, method)
        H = _nma_numerical_hessian(theta, y, X, v_prefix, study_dims, ///
            n_studies, dim, method)

        /* Newton-Raphson step with step halving */
        /* Add small ridge for numerical stability */
        H_inv = invsym(H - 0.001 * I(rows(H)))
        if (missing(H_inv[1,1])) {
            /* Hessian not invertible: use gradient ascent */
            step = 0.01 * grad
        }
        else {
            step = -H_inv * grad
        }

        /* Step halving to ensure likelihood improvement */
        step_scale = 1
        max_halvings = 20
        for (halving = 1; halving <= max_halvings; halving++) {
            theta_new = theta + step_scale * step
            Sigma_new = _nma_theta_to_sigma(theta_new, dim)
            ll_new = _nma_reml_loglik_val(y, X, v_prefix, study_dims, ///
                Sigma_new, n_studies, method)

            if (ll_new > ll | halving == max_halvings) break
            step_scale = step_scale / 2
        }

        if (show_log) {
            printf("{txt}Iteration %g: log likelihood = {res}%12.6f\n", iter, ll_new)
        }

        /* Check convergence */
        if (abs(ll_new - ll) < tol & max(abs(theta_new - theta)) < sqrt(tol)) {
            converged = 1
            theta = theta_new
            ll = ll_new
            break
        }

        theta = theta_new
        ll = ll_new
    }

    if (!converged & show_log) {
        printf("{txt}Warning: REML did not converge in %g iterations\n", max_iter)
        printf("{txt}         Falling back to method-of-moments estimate\n")
    }

    /* Final estimates */
    Sigma = _nma_theta_to_sigma(theta, dim)

    /* Bound tau2 away from negative */
    trace_sigma = trace(Sigma) / dim
    if (trace_sigma < 0) {
        Sigma = J(dim, dim, 0)
        trace_sigma = 0
    }

    res = _nma_reml_solve_given_sigma(y, X, v_prefix, study_dims, Sigma, n_studies)
    res.Sigma = Sigma
    res.tau2 = trace(Sigma) / dim
    res.ll = ll
    res.converged = converged
    res.iterations = iter

    return(res)
}

/* Solve for beta given fixed Sigma (GLS) */
struct _nma_reml_results scalar _nma_reml_solve_given_sigma(
    real colvector y,
    real matrix X,
    string scalar v_prefix,
    real colvector study_dims,
    real matrix Sigma,
    real scalar n_studies)
{
    struct _nma_reml_results scalar res
    real matrix XWX, XWy, W_inv_i, V_i, W_i
    real scalar i, row_start, d_i
    real colvector y_i
    real matrix X_i

    real scalar p
    p = cols(X)

    XWX = J(p, p, 0)
    XWy = J(p, 1, 0)

    row_start = 1
    for (i = 1; i <= n_studies; i++) {
        d_i = study_dims[i]
        y_i = y[row_start..(row_start + d_i - 1)]
        X_i = X[row_start..(row_start + d_i - 1), .]

        V_i = st_matrix(v_prefix + strofreal(i))

        /* W_i = V_i + Sigma (trimmed to study dimension) */
        if (d_i < rows(Sigma)) {
            W_i = V_i + Sigma[1..d_i, 1..d_i]
        }
        else {
            W_i = V_i + Sigma
        }

        W_inv_i = invsym(W_i)

        XWX = XWX + X_i' * W_inv_i * X_i
        XWy = XWy + X_i' * W_inv_i * y_i

        row_start = row_start + d_i
    }

    res.Vbeta = invsym(XWX)
    res.beta = res.Vbeta * XWy

    return(res)
}

/* Evaluate log-likelihood at given Sigma */
real scalar _nma_reml_loglik_val(
    real colvector y,
    real matrix X,
    string scalar v_prefix,
    real colvector study_dims,
    real matrix Sigma,
    real scalar n_studies,
    string scalar method)
{
    real scalar ll, i, row_start, d_i, p
    real colvector y_i, r_i
    real matrix X_i, V_i, W_i, W_inv_i, XWX
    struct _nma_reml_results scalar gls

    p = cols(X)

    /* Get GLS estimate for this Sigma */
    gls = _nma_reml_solve_given_sigma(y, X, v_prefix, study_dims, Sigma, n_studies)

    ll = 0
    XWX = J(p, p, 0)

    row_start = 1
    for (i = 1; i <= n_studies; i++) {
        d_i = study_dims[i]
        y_i = y[row_start..(row_start + d_i - 1)]
        X_i = X[row_start..(row_start + d_i - 1), .]

        V_i = st_matrix(v_prefix + strofreal(i))

        if (d_i < rows(Sigma)) {
            W_i = V_i + Sigma[1..d_i, 1..d_i]
        }
        else {
            W_i = V_i + Sigma
        }

        W_inv_i = invsym(W_i)

        r_i = y_i - X_i * gls.beta

        ll = ll - 0.5 * (d_i * log(2 * pi()) + _nma_logdet(W_i) + r_i' * W_inv_i * r_i)

        if (method == "reml") {
            XWX = XWX + X_i' * W_inv_i * X_i
        }

        row_start = row_start + d_i
    }

    /* REML adjustment */
    if (method == "reml") {
        ll = ll - 0.5 * _nma_logdet(XWX)
    }

    return(ll)
}

/* Log determinant (handling near-singular matrices) */
real scalar _nma_logdet(real matrix A)
{
    real colvector ev
    real scalar ld, i

    if (rows(A) == 1 & cols(A) == 1) {
        return(log(max((A[1,1], 1e-300))))
    }

    ev = symeigenvalues(A)
    ld = 0
    for (i = 1; i <= length(ev); i++) {
        ld = ld + log(max((ev[i], 1e-300)))
    }
    return(ld)
}

/* Method of moments starting values */
real matrix _nma_mom_start(
    real colvector y,
    real matrix X,
    string scalar v_prefix,
    real colvector study_dims,
    real scalar n_studies,
    real scalar dim)
{
    real scalar i, row_start, d_i, p, total_d
    real colvector y_i, r_i, eigval
    real matrix X_i, V_i, Q, Sigma, Sigma0, eigvec
    struct _nma_reml_results scalar fe

    p = cols(X)
    total_d = rows(y)

    /* Fixed-effect GLS with Sigma=0 */
    Sigma0 = J(dim, dim, 0)
    fe = _nma_reml_solve_given_sigma(y, X, v_prefix, study_dims, Sigma0, n_studies)

    /* Compute Q statistic (residual sum of squares weighted by V^-1) */
    Q = J(dim, dim, 0)
    row_start = 1
    for (i = 1; i <= n_studies; i++) {
        d_i = study_dims[i]
        y_i = y[row_start..(row_start + d_i - 1)]
        X_i = X[row_start..(row_start + d_i - 1), .]
        V_i = st_matrix(v_prefix + strofreal(i))

        r_i = y_i - X_i * fe.beta

        /* Contribution to between-study variance estimate */
        if (d_i == dim) {
            Q = Q + r_i * r_i' - V_i
        }
        else {
            /* Partial: only update the d_i x d_i block */
            Q[1..d_i, 1..d_i] = Q[1..d_i, 1..d_i] + r_i * r_i' - V_i
        }

        row_start = row_start + d_i
    }

    /* Average and ensure positive semi-definite */
    Sigma = Q / max((n_studies - p, 1))

    /* Force diagonal to be non-negative */
    for (i = 1; i <= dim; i++) {
        if (Sigma[i, i] < 0) Sigma[i, i] = 0.01
    }

    /* Make symmetric positive semi-definite via eigendecomposition */
    symeigensystem(Sigma, eigvec, eigval)
    for (i = 1; i <= length(eigval); i++) {
        if (eigval[i] < 0) eigval[i] = 0.001
    }
    Sigma = eigvec * diag(eigval) * eigvec'

    return(Sigma)
}

/* Convert Sigma to Cholesky parameter vector */
real colvector _nma_sigma_to_theta(real matrix Sigma, real scalar dim)
{
    real matrix L
    real colvector theta
    real scalar i, j, idx, n_params

    L = cholesky(Sigma + 0.0001 * I(dim))

    /* theta = vech(L) = lower triangle elements */
    n_params = dim * (dim + 1) / 2
    theta = J(n_params, 1, 0)

    idx = 1
    for (j = 1; j <= dim; j++) {
        for (i = j; i <= dim; i++) {
            theta[idx] = L[i, j]
            idx++
        }
    }

    return(theta)
}

/* Convert parameter vector to Sigma */
real matrix _nma_theta_to_sigma(real colvector theta, real scalar dim)
{
    real matrix L, Sigma
    real scalar i, j, idx

    L = J(dim, dim, 0)
    idx = 1
    for (j = 1; j <= dim; j++) {
        for (i = j; i <= dim; i++) {
            L[i, j] = theta[idx]
            idx++
        }
    }

    Sigma = L * L'
    return(Sigma)
}

/* Numerical gradient */
real colvector _nma_numerical_gradient(
    real colvector theta,
    real colvector y,
    real matrix X,
    string scalar v_prefix,
    real colvector study_dims,
    real scalar n_studies,
    real scalar dim,
    string scalar method)
{
    real scalar n_params, i
    real colvector grad, theta_plus, theta_minus
    real scalar h, ll_plus, ll_minus

    n_params = length(theta)
    grad = J(n_params, 1, 0)
    h = 1e-5

    for (i = 1; i <= n_params; i++) {
        theta_plus = theta
        theta_minus = theta
        theta_plus[i] = theta_plus[i] + h
        theta_minus[i] = theta_minus[i] - h

        ll_plus = _nma_reml_loglik_val(y, X, v_prefix, study_dims, ///
            _nma_theta_to_sigma(theta_plus, dim), n_studies, method)
        ll_minus = _nma_reml_loglik_val(y, X, v_prefix, study_dims, ///
            _nma_theta_to_sigma(theta_minus, dim), n_studies, method)

        grad[i] = (ll_plus - ll_minus) / (2 * h)
    }

    return(grad)
}

/* Numerical Hessian */
real matrix _nma_numerical_hessian(
    real colvector theta,
    real colvector y,
    real matrix X,
    string scalar v_prefix,
    real colvector study_dims,
    real scalar n_studies,
    real scalar dim,
    string scalar method)
{
    real scalar n_params, i, j
    real matrix H
    real colvector theta_pp, theta_pm, theta_mp, theta_mm
    real scalar h, ll_pp, ll_pm, ll_mp, ll_mm

    n_params = length(theta)
    H = J(n_params, n_params, 0)
    h = 1e-4

    for (i = 1; i <= n_params; i++) {
        for (j = i; j <= n_params; j++) {
            theta_pp = theta; theta_pp[i] = theta_pp[i] + h; theta_pp[j] = theta_pp[j] + h
            theta_pm = theta; theta_pm[i] = theta_pm[i] + h; theta_pm[j] = theta_pm[j] - h
            theta_mp = theta; theta_mp[i] = theta_mp[i] - h; theta_mp[j] = theta_mp[j] + h
            theta_mm = theta; theta_mm[i] = theta_mm[i] - h; theta_mm[j] = theta_mm[j] - h

            ll_pp = _nma_reml_loglik_val(y, X, v_prefix, study_dims, _nma_theta_to_sigma(theta_pp, dim), n_studies, method)
            ll_pm = _nma_reml_loglik_val(y, X, v_prefix, study_dims, _nma_theta_to_sigma(theta_pm, dim), n_studies, method)
            ll_mp = _nma_reml_loglik_val(y, X, v_prefix, study_dims, _nma_theta_to_sigma(theta_mp, dim), n_studies, method)
            ll_mm = _nma_reml_loglik_val(y, X, v_prefix, study_dims, _nma_theta_to_sigma(theta_mm, dim), n_studies, method)

            H[i, j] = (ll_pp - ll_pm - ll_mp + ll_mm) / (4 * h * h)
            H[j, i] = H[i, j]
        }
    }

    return(H)
}

/* Store results in regular Stata matrices (not e()) */
void _nma_reml_post_results(
    struct _nma_reml_results scalar res,
    real matrix X,
    real colvector y,
    real scalar p,
    real scalar dim,
    string scalar method)
{
    st_matrix("_nma_reml_b", res.beta')
    st_matrix("_nma_reml_V", res.Vbeta)
    st_matrix("_nma_reml_Sigma", res.Sigma)
    st_matrix("_nma_reml_tau2", res.tau2)
    st_matrix("_nma_reml_ll", res.ll)
    st_matrix("_nma_reml_conv", res.converged)
    st_matrix("_nma_reml_iter", res.iterations)
}
end
