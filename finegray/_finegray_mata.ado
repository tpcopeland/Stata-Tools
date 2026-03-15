*! _finegray_mata Version 1.0.0  2026/03/15
*! Mata forward-backward scan engine for Fine-Gray regression
*! Author: Timothy P Copeland
*! Department of Clinical Neuroscience, Karolinska Institutet
*! Program class: internal (stores results in Stata matrices)

/*
Internal command: Fits Fine-Gray subdistribution hazard model using
the forward-backward scan algorithm (Kawaguchi et al. 2020).
Called by finegray with fast option. Not intended for direct user invocation.

Algorithm: O(np) per Newton-Raphson iteration
  1. KM censoring distribution G(t)
  2. Forward scan: at-risk sums for uncensored subjects
  3. Backward scan: weighted sums for competing-event subjects
  4. Combine at cause-event times for score/Hessian
  5. Newton-Raphson with step halving

Key detail: processes observations in time-point groups to correctly
handle tied events (Breslow method) and prevent double-counting of
competing events at tied cause-event times.
*/

* Loading guard
capture program drop _finegray_mata_loaded
program define _finegray_mata_loaded
    version 16.0
    display as text "_finegray_mata is loaded"
end

mata:
mata set matastrict on

/* Single-stratum KM of censoring distribution */
real colvector _finegray_km_censor_single(
    real colvector t,
    real colvector delta,
    real scalar censval,
    real colvector event_type)
{
    real scalar n, i, j, surv, n_risk_at_t, n_cens_at_t, cur_time
    real colvector G, ord

    n = rows(t)
    G = J(n, 1, 1)
    ord = order(t, 1)
    surv = 1
    i = 1

    while (i <= n) {
        cur_time = t[ord[i]]
        n_risk_at_t = n - i + 1
        n_cens_at_t = 0

        j = i
        while (j <= n) {
            if (t[ord[j]] != cur_time) break
            if (event_type[ord[j]] == censval & delta[ord[j]] == 0) {
                n_cens_at_t++
            }
            j++
        }

        if (n_cens_at_t > 0) {
            surv = surv * (1 - n_cens_at_t / n_risk_at_t)
        }

        while (i < j) {
            G[ord[i]] = surv
            i++
        }
    }

    for (i = 1; i <= n; i++) {
        if (G[i] < 1e-10) G[i] = 1e-10
    }

    return(G)
}

/* KM of censoring distribution, optionally stratified by byg */
real colvector _finegray_km_censor(
    real colvector t,
    real colvector delta,
    real scalar censval,
    real colvector event_type,
    real colvector byg_id)
{
    real scalar n, g, nlev
    real colvector G, levels, sel

    n = rows(t)
    G = J(n, 1, 1)

    levels = uniqrows(byg_id)
    nlev = rows(levels)
    if (nlev > 1) {
        for (g = 1; g <= nlev; g++) {
            sel = selectindex(byg_id :== levels[g])
            G[sel] = _finegray_km_censor_single(t[sel], delta[sel],
                censval, event_type[sel])
        }
        return(G)
    }

    G = _finegray_km_censor_single(t, delta, censval, event_type)
    return(G)
}

/* Log pseudo-likelihood via forward-backward scan with Breslow ties */
real scalar _finegray_loglik(
    real colvector t,
    real colvector delta,
    real scalar cause,
    real scalar censval,
    real colvector event_type,
    real matrix Z,
    real colvector beta,
    real colvector G)
{
    real scalar n, p, i, j, k, ll, S0, raw_bwd, idx, cur_time, S0_fwd_at_t
    real colvector eta, expeta, is_cause, is_compete, ord, S0_fwd

    n = rows(t)
    p = cols(Z)

    eta = Z * beta
    expeta = exp(eta)
    is_cause = (event_type :== cause) :& (delta :== 1)
    is_compete = (event_type :!= cause) :& (event_type :!= censval) :& (delta :== 1)

    ord = order(t, 1)

    /* Forward scan: cumulate S0 from end */
    S0_fwd = J(n, 1, 0)
    S0 = 0
    for (i = n; i >= 1; i--) {
        S0 = S0 + expeta[ord[i]]
        S0_fwd[i] = S0  /* indexed by SORTED position */
    }

    /* Process by time-point groups */
    ll = 0
    raw_bwd = 0
    i = 1

    while (i <= n) {
        cur_time = t[ord[i]]

        /* Find end of this time group */
        j = i
        while (j <= n) {
            if (t[ord[j]] != cur_time) break
            j++
        }
        /* Obs at this time: sorted positions i..j-1 */

        /* S0_fwd for Breslow: use value at first position (includes all obs >= cur_time) */
        S0_fwd_at_t = S0_fwd[i]

        /* Process all cause events at this time */
        for (k = i; k < j; k++) {
            idx = ord[k]
            if (is_cause[idx]) {
                S0 = S0_fwd_at_t + G[idx] * raw_bwd
                ll = ll + eta[idx] - log(S0)
            }
        }

        /* AFTER processing cause events, add competing events at this time to backward */
        for (k = i; k < j; k++) {
            idx = ord[k]
            if (is_compete[idx]) {
                raw_bwd = raw_bwd + expeta[idx] / G[idx]
            }
        }

        i = j
    }

    return(ll)
}

/* Score vector and observed information via forward-backward scan */
void _finegray_score_info(
    real colvector t,
    real colvector delta,
    real scalar cause,
    real scalar censval,
    real colvector event_type,
    real matrix Z,
    real colvector beta,
    real colvector G,
    real colvector score,
    real matrix info)
{
    real scalar n, p, i, j, k, idx, cum_s0, bwd_s0_raw, S0_total, S0_fwd_at_t
    real scalar cur_time
    real colvector eta, expeta, is_cause, is_compete, ord, S0_fwd
    real matrix S1_fwd, fwd_s2_cum, bwd_s2_raw, S2_total
    real matrix S2_fwd_at_t
    real rowvector cum_s1, bwd_s1_raw, S1_total, z_bar, S1_fwd_at_t

    n = rows(t)
    p = cols(Z)

    eta = Z * beta
    expeta = exp(eta)
    is_cause = (event_type :== cause) :& (delta :== 1)
    is_compete = (event_type :!= cause) :& (event_type :!= censval) :& (delta :== 1)

    ord = order(t, 1)

    /* Forward scan: cumulate S0, S1, S2 from end (indexed by sorted position) */
    S0_fwd = J(n, 1, 0)
    S1_fwd = J(n, p, 0)

    cum_s0 = 0
    cum_s1 = J(1, p, 0)
    fwd_s2_cum = J(p, p, 0)

    /* Store S0, S1, S2 at each sorted position in single pass */
    transmorphic scalar fwd_s2_at
    fwd_s2_at = asarray_create("real", 1)

    for (i = n; i >= 1; i--) {
        idx = ord[i]
        cum_s0 = cum_s0 + expeta[idx]
        cum_s1 = cum_s1 + expeta[idx] * Z[idx, .]
        fwd_s2_cum = fwd_s2_cum + expeta[idx] * (Z[idx, .]' * Z[idx, .])
        S0_fwd[i] = cum_s0
        S1_fwd[i, .] = cum_s1
        asarray(fwd_s2_at, i, fwd_s2_cum)
    }

    /* Forward pass with backward accumulation, processing time-point groups */
    score = J(p, 1, 0)
    info = J(p, p, 0)
    bwd_s0_raw = 0
    bwd_s1_raw = J(1, p, 0)
    bwd_s2_raw = J(p, p, 0)

    i = 1
    while (i <= n) {
        cur_time = t[ord[i]]

        j = i
        while (j <= n) {
            if (t[ord[j]] != cur_time) break
            j++
        }

        /* Breslow: use forward sums from first position at this time */
        S0_fwd_at_t = S0_fwd[i]
        S1_fwd_at_t = S1_fwd[i, .]
        S2_fwd_at_t = asarray(fwd_s2_at, i)

        /* Process cause events at this time */
        for (k = i; k < j; k++) {
            idx = ord[k]
            if (is_cause[idx]) {
                S0_total = S0_fwd_at_t + G[idx] * bwd_s0_raw
                S1_total = S1_fwd_at_t + G[idx] * bwd_s1_raw
                S2_total = S2_fwd_at_t + G[idx] * bwd_s2_raw

                z_bar = S1_total / S0_total

                score = score + (Z[idx, .] - z_bar)'
                info = info + S2_total / S0_total - z_bar' * z_bar
            }
        }

        /* AFTER cause events, add competing events at this time to backward */
        for (k = i; k < j; k++) {
            idx = ord[k]
            if (is_compete[idx]) {
                bwd_s0_raw = bwd_s0_raw + expeta[idx] / G[idx]
                bwd_s1_raw = bwd_s1_raw + expeta[idx] / G[idx] * Z[idx, .]
                bwd_s2_raw = bwd_s2_raw + expeta[idx] / G[idx] *
                    (Z[idx, .]' * Z[idx, .])
            }
        }

        i = j
    }
}

/* Robust (sandwich) variance estimator */
real matrix _finegray_robust_var(
    real colvector t,
    real colvector delta,
    real scalar cause,
    real scalar censval,
    real colvector event_type,
    real matrix Z,
    real colvector beta,
    real colvector G,
    real matrix info_inv,
    string scalar clust_var,
    real colvector clust_id)
{
    real scalar n, p, i, j, k, idx, cum_s0, bwd_s0_raw, running_invS0
    real scalar S0_t, use_cluster, S0_fwd_at_t, cur_time
    real colvector eta, expeta, is_cause, is_compete, ord
    real colvector S0_fwd, cum_invS0, clev, sel
    real matrix S1_fwd, scores, cum_zbars, meat, clust_scores
    real rowvector cum_s1, bwd_s1_raw, running_zbar_sum, z_bar_t, S1_t
    real rowvector S1_fwd_at_t

    n = rows(t)
    p = cols(Z)

    eta = Z * beta
    expeta = exp(eta)
    is_cause = (event_type :== cause) :& (delta :== 1)
    is_compete = (event_type :!= cause) :& (event_type :!= censval) :& (delta :== 1)

    ord = order(t, 1)

    /* Forward S0, S1 (sorted position indexing) */
    S0_fwd = J(n, 1, 0)
    S1_fwd = J(n, p, 0)
    cum_s0 = 0
    cum_s1 = J(1, p, 0)
    for (i = n; i >= 1; i--) {
        idx = ord[i]
        cum_s0 = cum_s0 + expeta[idx]
        cum_s1 = cum_s1 + expeta[idx] * Z[idx, .]
        S0_fwd[i] = cum_s0
        S1_fwd[i, .] = cum_s1
    }

    /* Compute individual score residuals */
    scores = J(n, p, 0)
    bwd_s0_raw = 0
    bwd_s1_raw = J(1, p, 0)
    cum_zbars = J(n, p, 0)
    cum_invS0 = J(n, 1, 0)
    running_invS0 = 0
    running_zbar_sum = J(1, p, 0)

    /* Process by time-point groups */
    i = 1
    while (i <= n) {
        cur_time = t[ord[i]]

        j = i
        while (j <= n) {
            if (t[ord[j]] != cur_time) break
            j++
        }

        S0_fwd_at_t = S0_fwd[i]
        S1_fwd_at_t = S1_fwd[i, .]

        /* Process cause events */
        for (k = i; k < j; k++) {
            idx = ord[k]
            if (is_cause[idx]) {
                S0_t = S0_fwd_at_t + G[idx] * bwd_s0_raw
                S1_t = S1_fwd_at_t + G[idx] * bwd_s1_raw
                z_bar_t = S1_t / S0_t

                scores[idx, .] = Z[idx, .] - z_bar_t
                running_invS0 = running_invS0 + 1 / S0_t
                running_zbar_sum = running_zbar_sum + z_bar_t / S0_t
            }
        }

        /* Assign cumulative terms to all obs at this time */
        for (k = i; k < j; k++) {
            idx = ord[k]
            cum_invS0[idx] = running_invS0
            cum_zbars[idx, .] = running_zbar_sum
        }

        /* Add competing events to backward */
        for (k = i; k < j; k++) {
            idx = ord[k]
            if (is_compete[idx]) {
                bwd_s0_raw = bwd_s0_raw + expeta[idx] / G[idx]
                bwd_s1_raw = bwd_s1_raw + expeta[idx] / G[idx] * Z[idx, .]
            }
        }

        i = j
    }

    /* Subtract the at-risk contribution for non-event subjects */
    for (i = 1; i <= n; i++) {
        if (!is_cause[i]) {
            scores[i, .] = -expeta[i] *
                (Z[i, .] * cum_invS0[i] - cum_zbars[i, .])
        }
    }

    /* Compute meat */
    use_cluster = (clust_var != "" & rows(clust_id) == n)
    if (use_cluster) {
        clev = uniqrows(clust_id)
        clust_scores = J(rows(clev), p, 0)
        for (i = 1; i <= rows(clev); i++) {
            sel = selectindex(clust_id :== clev[i])
            clust_scores[i, .] = colsum(scores[sel, .])
        }
        meat = clust_scores' * clust_scores
    }
    else {
        meat = scores' * scores
    }

    return(info_inv * meat * info_inv)
}

/* Compute baseline cumulative subhazard */
real matrix _finegray_basehazard(
    real colvector t,
    real colvector delta,
    real scalar cause,
    real scalar censval,
    real colvector event_type,
    real matrix Z,
    real colvector beta,
    real colvector G)
{
    real scalar n, p, i, j, k, idx, cum_s0, bwd_s0_raw, cum_bh
    real scalar n_events, ev_idx, S0_t, S0_fwd_at_t, cur_time
    real colvector eta, expeta, is_cause, is_compete, ord, S0_fwd
    real matrix result

    n = rows(t)
    p = cols(Z)

    eta = Z * beta
    expeta = exp(eta)
    is_cause = (event_type :== cause) :& (delta :== 1)
    is_compete = (event_type :!= cause) :& (event_type :!= censval) :& (delta :== 1)

    ord = order(t, 1)

    /* Forward S0 (sorted position) */
    S0_fwd = J(n, 1, 0)
    cum_s0 = 0
    for (i = n; i >= 1; i--) {
        idx = ord[i]
        cum_s0 = cum_s0 + expeta[idx]
        S0_fwd[i] = cum_s0
    }

    n_events = sum(is_cause)
    result = J(n_events, 2, .)

    bwd_s0_raw = 0
    cum_bh = 0
    ev_idx = 0

    i = 1
    while (i <= n) {
        cur_time = t[ord[i]]

        j = i
        while (j <= n) {
            if (t[ord[j]] != cur_time) break
            j++
        }

        S0_fwd_at_t = S0_fwd[i]

        /* Process cause events - accumulate baseline hazard */
        for (k = i; k < j; k++) {
            idx = ord[k]
            if (is_cause[idx]) {
                S0_t = S0_fwd_at_t + G[idx] * bwd_s0_raw
                cum_bh = cum_bh + 1 / S0_t
                ev_idx++
                result[ev_idx, 1] = t[idx]
                result[ev_idx, 2] = cum_bh
            }
        }

        /* Add competing events to backward */
        for (k = i; k < j; k++) {
            idx = ord[k]
            if (is_compete[idx]) {
                bwd_s0_raw = bwd_s0_raw + expeta[idx] / G[idx]
            }
        }

        i = j
    }

    return(result)
}

/* Main engine: Newton-Raphson with step halving */
void _finegray_engine(
    string scalar varlist_str,
    string scalar events_str,
    real scalar cause,
    real scalar censval,
    string scalar byg_str,
    string scalar vce_type,
    string scalar clust_str,
    real scalar max_iter,
    real scalar tol,
    real scalar show_log)
{
    real colvector t, delta, event_type, G, byg_id
    real matrix Z, V, bh
    real colvector beta, beta_new, score_vec, step, clust_id
    real matrix info_mat, info_inv
    real scalar n, p, ll, ll_new, ll_0, converged, iter
    real scalar step_scale, halving, max_halvings, chi2, p_model, df_m
    string rowvector vars

    /* Read data */
    vars = tokens(varlist_str)
    p = length(vars)

    Z = st_data(., vars)
    t = st_data(., "_t")
    delta = st_data(., "_d")
    event_type = st_data(., events_str)
    n = rows(t)

    /* Read byg variable if specified */
    if (byg_str != "") {
        byg_id = st_data(., byg_str)
    }
    else {
        byg_id = J(n, 1, 1)
    }

    /* Compute censoring distribution */
    G = _finegray_km_censor(t, delta, censval, event_type, byg_id)

    /* Starting values: zeros */
    beta = J(p, 1, 0)

    /* Null log-likelihood */
    ll_0 = _finegray_loglik(t, delta, cause, censval, event_type, Z,
        J(p, 1, 0), G)
    ll = ll_0

    if (show_log) {
        printf("{txt}Iteration 0: log pseudo-likelihood = {res}%12.6f\n", ll)
    }

    converged = 0
    max_halvings = 20

    for (iter = 1; iter <= max_iter; iter++) {
        /* Score and information */
        _finegray_score_info(t, delta, cause, censval, event_type,
            Z, beta, G, score_vec, info_mat)

        /* Newton-Raphson step */
        info_inv = invsym(info_mat)
        if (missing(info_inv[1,1])) {
            info_inv = invsym(info_mat + 0.001 * I(p))
            if (missing(info_inv[1,1])) {
                errprintf("information matrix is singular\n")
                exit(error(498))
            }
        }

        step = info_inv * score_vec

        /* Step halving */
        step_scale = 1
        for (halving = 1; halving <= max_halvings; halving++) {
            beta_new = beta + step_scale * step
            ll_new = _finegray_loglik(t, delta, cause, censval,
                event_type, Z, beta_new, G)

            if (ll_new > ll | halving == max_halvings) break
            step_scale = step_scale / 2
        }

        if (show_log) {
            printf("{txt}Iteration %g: log pseudo-likelihood = {res}%12.6f\n",
                iter, ll_new)
        }

        /* Check convergence */
        if (abs(ll_new - ll) < tol & max(abs(beta_new - beta)) < sqrt(tol)) {
            converged = 1
            beta = beta_new
            ll = ll_new
            break
        }

        beta = beta_new
        ll = ll_new
    }

    if (!converged & show_log) {
        printf("{err}Warning: did not converge in %g iterations\n", max_iter)
    }

    /* Final information for variance */
    _finegray_score_info(t, delta, cause, censval, event_type,
        Z, beta, G, score_vec, info_mat)
    info_inv = invsym(info_mat)

    /* Variance estimation */
    if (vce_type == "robust" | vce_type == "cluster") {
        if (vce_type == "cluster") {
            clust_id = st_data(., clust_str)
        }
        else {
            clust_id = J(n, 1, .)
        }
        V = _finegray_robust_var(t, delta, cause, censval, event_type,
            Z, beta, G, info_inv, clust_str, clust_id)
    }
    else {
        V = info_inv
    }

    /* Compute baseline hazard */
    bh = _finegray_basehazard(t, delta, cause, censval, event_type,
        Z, beta, G)

    /* Model chi2 */
    df_m = p
    chi2 = beta' * invsym(V) * beta
    p_model = chi2tail(df_m, chi2)

    /* Post results to Stata matrices */
    st_matrix("_finegray_b", beta')
    st_matrix("_finegray_V", V)
    st_matrix("_finegray_basehaz", bh)
    st_matrix("_finegray_ll", ll)
    st_matrix("_finegray_ll_0", ll_0)
    st_matrix("_finegray_chi2", chi2)
    st_matrix("_finegray_p_model", p_model)
    st_matrix("_finegray_df_m", df_m)
    st_matrix("_finegray_conv", converged)
    st_matrix("_finegray_N_expand", 0)
}

end
