#!/usr/bin/env python3
"""
crossval_aipw.py — Independent AIPW implementation for drest cross-validation

Computes AIPW ATE, SE, PO means from scratch using only numpy/scipy.
Zero shared code with drest. Exports results to CSV for Stata comparison.

Usage:
    python3 crossval_aipw.py <input.csv> <output.csv>

Input CSV must have columns: y, treat, x1, x2 [, x3, ...]
Output CSV has columns: estimator, ate, se, po1, po0, ci_lo, ci_hi
"""

import sys
import numpy as np
import pandas as pd
from scipy.special import expit  # logistic function
from scipy.optimize import minimize
from scipy.stats import norm


def fit_logistic(X, y):
    """Fit logistic regression via MLE. Returns coefficients."""
    n, p = X.shape
    X_aug = np.column_stack([np.ones(n), X])

    def neg_loglik(beta):
        z = X_aug @ beta
        z = np.clip(z, -500, 500)
        p = expit(z)
        p = np.clip(p, 1e-15, 1 - 1e-15)
        return -np.sum(y * np.log(p) + (1 - y) * np.log(1 - p))

    beta0 = np.zeros(p + 1)
    result = minimize(neg_loglik, beta0, method='BFGS',
                      options={'maxiter': 1000, 'gtol': 1e-8})
    return result.x

def predict_logistic(X, beta):
    """Predict probabilities from logistic model."""
    X_aug = np.column_stack([np.ones(X.shape[0]), X])
    return expit(X_aug @ beta)

def fit_ols(X, y):
    """Fit OLS regression. Returns coefficients."""
    X_aug = np.column_stack([np.ones(len(y)), X])
    beta = np.linalg.lstsq(X_aug, y, rcond=None)[0]
    return beta

def predict_ols(X, beta):
    """Predict from OLS model."""
    X_aug = np.column_stack([np.ones(X.shape[0]), X])
    return X_aug @ beta


def aipw_ate(y, treat, X, trim_lo=0.0, trim_hi=1.0, is_binary=False):
    """
    Compute AIPW ATE from scratch.

    Parameters:
        y: outcome vector
        treat: binary treatment vector
        X: covariate matrix
        trim_lo, trim_hi: PS trimming bounds
        is_binary: if True, use logistic outcome model

    Returns:
        dict with ate, se, po1, po0, ci_lo, ci_hi
    """
    n = len(y)

    # Step 1: Propensity score model (logistic)
    ps_beta = fit_logistic(X, treat)
    ps = predict_logistic(X, ps_beta)

    # Trim PS
    ps = np.clip(ps, trim_lo if trim_lo > 0 else 1e-10,
                 trim_hi if trim_hi < 1 else 1 - 1e-10)

    # Step 2: Outcome models (separate by treatment arm)
    idx1 = treat == 1
    idx0 = treat == 0

    if is_binary:
        beta1 = fit_logistic(X[idx1], y[idx1])
        mu1 = predict_logistic(X, beta1)
        beta0 = fit_logistic(X[idx0], y[idx0])
        mu0 = predict_logistic(X, beta0)
    else:
        beta1 = fit_ols(X[idx1], y[idx1])
        mu1 = predict_ols(X, beta1)
        beta0 = fit_ols(X[idx0], y[idx0])
        mu0 = predict_ols(X, beta0)

    # Step 3: AIPW pseudo-outcome
    phi = (mu1 - mu0) \
        + treat * (y - mu1) / ps \
        - (1 - treat) * (y - mu0) / (1 - ps)

    # Step 4: ATE = mean(phi)
    ate = np.mean(phi)

    # Step 5: IF-based SE
    if_centered = (phi - ate) ** 2
    variance = np.sum(if_centered) / (n ** 2)
    se = np.sqrt(variance)

    # Augmented PO means
    aug1 = mu1 + treat * (y - mu1) / ps
    aug0 = mu0 + (1 - treat) * (y - mu0) / (1 - ps)
    po1 = np.mean(aug1)
    po0 = np.mean(aug0)

    # 95% CI
    z = norm.ppf(0.975)
    ci_lo = ate - z * se
    ci_hi = ate + z * se

    return {
        'ate': ate, 'se': se,
        'po1': po1, 'po0': po0,
        'ci_lo': ci_lo, 'ci_hi': ci_hi
    }


def tmle_ate(y, treat, X, trim_lo=0.0, trim_hi=1.0, is_binary=False,
             max_iter=100, tol=1e-5):
    """
    Compute TMLE ATE from scratch.

    For continuous outcomes: one-step linear fluctuation.
    For binary outcomes: iterative logistic fluctuation.
    """
    n = len(y)

    # Step 1: PS
    ps_beta = fit_logistic(X, treat)
    ps = predict_logistic(X, ps_beta)
    ps = np.clip(ps, trim_lo if trim_lo > 0 else 1e-10,
                 trim_hi if trim_hi < 1 else 1 - 1e-10)

    # Step 2: Outcome models
    idx1 = treat == 1
    idx0 = treat == 0

    if is_binary:
        beta1 = fit_logistic(X[idx1], y[idx1])
        mu1 = predict_logistic(X, beta1)
        beta0 = fit_logistic(X[idx0], y[idx0])
        mu0 = predict_logistic(X, beta0)
    else:
        beta1 = fit_ols(X[idx1], y[idx1])
        mu1 = predict_ols(X, beta1)
        beta0 = fit_ols(X[idx0], y[idx0])
        mu0 = predict_ols(X, beta0)

    # Step 3: Targeting
    if is_binary:
        mu1 = np.clip(mu1, 0.001, 0.999)
        mu0 = np.clip(mu0, 0.001, 0.999)

        H1 = treat / ps
        H0 = -(1 - treat) / (1 - ps)
        H = H1 + H0

        for iteration in range(max_iter):
            mu_combined = mu1 * treat + mu0 * (1 - treat)
            mu_combined = np.clip(mu_combined, 0.001, 0.999)
            offset = np.log(mu_combined / (1 - mu_combined))

            # Fit epsilon: logit(Y) = epsilon*H + offset
            # One-parameter logistic regression with offset
            def neg_ll(eps):
                eta = offset + eps[0] * H
                eta = np.clip(eta, -500, 500)
                p = expit(eta)
                p = np.clip(p, 1e-15, 1 - 1e-15)
                return -np.sum(y * np.log(p) + (1 - y) * np.log(1 - p))

            result = minimize(neg_ll, [0.0], method='BFGS')
            epsilon = result.x[0]

            if abs(epsilon) < tol:
                break

            # Update
            logit_mu1 = np.log(np.clip(mu1, 0.001, 0.999) /
                               (1 - np.clip(mu1, 0.001, 0.999)))
            logit_mu0 = np.log(np.clip(mu0, 0.001, 0.999) /
                               (1 - np.clip(mu0, 0.001, 0.999)))
            mu1 = expit(logit_mu1 + epsilon / ps)
            mu0 = expit(logit_mu0 - epsilon / (1 - ps))
    else:
        # Linear fluctuation (one step)
        H = treat / ps - (1 - treat) / (1 - ps)
        mu_combined = mu1 * treat + mu0 * (1 - treat)
        resid = y - mu_combined

        # epsilon = cov(resid, H) / var(H) — OLS without intercept
        epsilon = np.sum(resid * H) / np.sum(H ** 2)

        mu1 = mu1 + epsilon / ps
        mu0 = mu0 - epsilon / (1 - ps)

    # Step 4: TMLE estimate (substitution)
    po1 = np.mean(mu1)
    po0 = np.mean(mu0)
    ate = po1 - po0

    # Step 5: IF-based SE
    phi = (mu1 - mu0 - ate) \
        + treat * (y - mu1) / ps \
        - (1 - treat) * (y - mu0) / (1 - ps)
    variance = np.sum(phi ** 2) / (n ** 2)
    se = np.sqrt(variance)

    z = norm.ppf(0.975)
    return {
        'ate': ate, 'se': se,
        'po1': po1, 'po0': po0,
        'ci_lo': ate - z * se, 'ci_hi': ate + z * se
    }


def main():
    if len(sys.argv) < 3:
        print("Usage: python3 crossval_aipw.py <input.csv> <output.csv>")
        sys.exit(1)

    input_file = sys.argv[1]
    output_file = sys.argv[2]

    # Read data
    df = pd.read_csv(input_file)
    y = df['y'].values.astype(float)
    treat = df['treat'].values.astype(float)

    # Covariates: everything except y, treat
    cov_cols = [c for c in df.columns if c not in ('y', 'treat')]
    X = df[cov_cols].values.astype(float)

    # Detect binary outcome
    is_binary = set(np.unique(y)) <= {0.0, 1.0}

    results = []

    # AIPW (no trimming — matches teffects)
    r_aipw_notrim = aipw_ate(y, treat, X, trim_lo=0.0, trim_hi=1.0,
                              is_binary=is_binary)
    results.append({
        'estimator': 'aipw_notrim',
        **r_aipw_notrim
    })

    # AIPW (with default trimming [0.01, 0.99])
    r_aipw_trim = aipw_ate(y, treat, X, trim_lo=0.01, trim_hi=0.99,
                            is_binary=is_binary)
    results.append({
        'estimator': 'aipw_trim',
        **r_aipw_trim
    })

    # TMLE (no trimming)
    r_tmle_notrim = tmle_ate(y, treat, X, trim_lo=0.0, trim_hi=1.0,
                              is_binary=is_binary)
    results.append({
        'estimator': 'tmle_notrim',
        **r_tmle_notrim
    })

    # TMLE (with trimming)
    r_tmle_trim = tmle_ate(y, treat, X, trim_lo=0.01, trim_hi=0.99,
                            is_binary=is_binary)
    results.append({
        'estimator': 'tmle_trim',
        **r_tmle_trim
    })

    out_df = pd.DataFrame(results)
    out_df.to_csv(output_file, index=False, float_format='%.12f')

    # Print summary
    print(f"Input:  {input_file} ({len(y)} obs, {X.shape[1]} covs, "
          f"binary={is_binary})")
    print(f"Output: {output_file}")
    for r in results:
        print(f"  {r['estimator']:16s}: ATE={r['ate']:10.6f}  "
              f"SE={r['se']:8.6f}  "
              f"PO1={r['po1']:8.4f}  PO0={r['po0']:8.4f}")


if __name__ == '__main__':
    main()
