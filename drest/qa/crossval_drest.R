#!/usr/bin/env Rscript
#
# crossval_drest.R — Comprehensive R cross-validation for drest package
#
# Base R only (no dependencies). Implements from first principles:
#   AIPW (ATE/ATT/ATC), TMLE, IPTW, G-computation, cross-fitted AIPW,
#   E-value, PS diagnostics, covariate balance, row-level predictions.
#
# Usage:
#   Rscript crossval_drest.R <input.csv> <output_prefix> [--foldvar COLNAME]
#
# Outputs:
#   {prefix}_estimates.csv  — method-level results (ate, se, po1, po0)
#   {prefix}_predictions.csv — row-level (ps, mu1, mu0, phi)
#   {prefix}_diagnostics.csv — PS stats, SMDs, ESS, C-stat, E-value
#
# Author: Timothy P Copeland
# Date: 2026-03-15

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 2) {
  cat("Usage: Rscript crossval_drest.R <input.csv> <output_prefix> [--foldvar COL]\n")
  quit(status = 1)
}

input_file <- args[1]
output_prefix <- args[2]
foldvar <- NULL
if (length(args) >= 4 && args[3] == "--foldvar") {
  foldvar <- args[4]
}

df <- read.csv(input_file)
y <- df$y
treat <- df$treat
cov_cols <- setdiff(names(df), c("y", "treat", foldvar))
X <- as.matrix(df[, cov_cols, drop = FALSE])
n <- length(y)
is_binary <- all(y %in% c(0, 1))

cat(sprintf("crossval_drest.R: %s (%d obs, %d covs, binary=%s)\n",
            input_file, n, ncol(X), is_binary))

# ==========================================================================
# HELPERS
# ==========================================================================

fit_logistic <- function(X, y) {
  dat <- data.frame(y = y, X)
  fit <- glm(y ~ ., data = dat, family = binomial(link = "logit"))
  return(fit)
}

predict_logistic <- function(fit, Xnew) {
  dat <- data.frame(Xnew)
  names(dat) <- names(coef(fit))[-1]
  predict(fit, newdata = dat, type = "response")
}

fit_ols <- function(X, y) {
  dat <- data.frame(y = y, X)
  fit <- lm(y ~ ., data = dat)
  return(fit)
}

predict_ols <- function(fit, Xnew) {
  dat <- data.frame(Xnew)
  names(dat) <- names(coef(fit))[-1]
  predict(fit, newdata = dat)
}

fit_outcome <- function(X, y, is_binary) {
  if (is_binary) fit_logistic(X, y) else fit_ols(X, y)
}

predict_outcome <- function(fit, X, is_binary) {
  if (is_binary) predict_logistic(fit, X) else predict_ols(fit, X)
}

# ==========================================================================
# AIPW (ATE, ATT, ATC)
# ==========================================================================

aipw <- function(y, treat, X, estimand = "ATE",
                 trim_lo = 0, trim_hi = 1, is_binary = FALSE) {
  # PS model
  ps_fit <- fit_logistic(X, treat)
  ps <- predict_logistic(ps_fit, X)
  lo <- ifelse(trim_lo > 0, trim_lo, 1e-10)
  hi <- ifelse(trim_hi < 1, trim_hi, 1 - 1e-10)
  ps <- pmin(pmax(ps, lo), hi)
  n_trimmed <- sum(predict_logistic(ps_fit, X) < lo | predict_logistic(ps_fit, X) > hi)

  # Outcome models per arm
  idx1 <- treat == 1; idx0 <- treat == 0
  fit1 <- fit_outcome(X[idx1, , drop = FALSE], y[idx1], is_binary)
  mu1 <- predict_outcome(fit1, X, is_binary)
  fit0 <- fit_outcome(X[idx0, , drop = FALSE], y[idx0], is_binary)
  mu0 <- predict_outcome(fit0, X, is_binary)

  if (estimand == "ATE") {
    phi <- (mu1 - mu0) +
      treat * (y - mu1) / ps -
      (1 - treat) * (y - mu0) / (1 - ps)
    tau <- mean(phi)
    if_centered <- (phi - tau)^2
    variance <- sum(if_centered) / n^2
    se <- sqrt(variance)

    aug1 <- mu1 + treat * (y - mu1) / ps
    aug0 <- mu0 + (1 - treat) * (y - mu0) / (1 - ps)
    po1 <- mean(aug1)
    po0 <- mean(aug0)
  } else if (estimand == "ATT") {
    n1 <- sum(treat == 1)
    phi <- treat * (y - mu0) -
      (1 - treat) * ps / (1 - ps) * (y - mu0)
    tau <- sum(phi) / n1
    if_centered <- (phi - tau * treat)^2
    variance <- sum(if_centered) / n1^2
    se <- sqrt(variance)
    po1 <- mean(y[idx1])
    po0 <- po1 - tau
  } else if (estimand == "ATC") {
    n0 <- sum(treat == 0)
    phi <- (1 - treat) * (mu1 - y) +
      treat * (1 - ps) / ps * (y - mu1)
    tau <- sum(phi) / n0
    if_centered <- (phi - tau * (1 - treat))^2
    variance <- sum(if_centered) / n0^2
    se <- sqrt(variance)
    po0 <- mean(y[idx0])
    po1 <- po0 + tau
  }

  z <- qnorm(0.975)
  list(tau = tau, se = se, po1 = po1, po0 = po0,
       ci_lo = tau - z * se, ci_hi = tau + z * se,
       ps = ps, mu1 = mu1, mu0 = mu0, phi = phi,
       n_trimmed = n_trimmed)
}

# ==========================================================================
# TMLE
# ==========================================================================

tmle <- function(y, treat, X, trim_lo = 0, trim_hi = 1,
                 is_binary = FALSE, max_iter = 100, tol = 1e-5) {
  ps_fit <- fit_logistic(X, treat)
  ps <- predict_logistic(ps_fit, X)
  lo <- ifelse(trim_lo > 0, trim_lo, 1e-10)
  hi <- ifelse(trim_hi < 1, trim_hi, 1 - 1e-10)
  ps <- pmin(pmax(ps, lo), hi)

  idx1 <- treat == 1; idx0 <- treat == 0
  fit1 <- fit_outcome(X[idx1, , drop = FALSE], y[idx1], is_binary)
  mu1 <- predict_outcome(fit1, X, is_binary)
  fit0 <- fit_outcome(X[idx0, , drop = FALSE], y[idx0], is_binary)
  mu0 <- predict_outcome(fit0, X, is_binary)

  if (is_binary) {
    mu1 <- pmin(pmax(mu1, 0.001), 0.999)
    mu0 <- pmin(pmax(mu0, 0.001), 0.999)
    H <- treat / ps - (1 - treat) / (1 - ps)

    for (iter in seq_len(max_iter)) {
      mu_comb <- mu1 * treat + mu0 * (1 - treat)
      mu_comb <- pmin(pmax(mu_comb, 0.001), 0.999)
      offset_val <- log(mu_comb / (1 - mu_comb))
      fluc <- glm(y ~ -1 + H, family = binomial(), offset = offset_val)
      epsilon <- coef(fluc)[1]
      if (abs(epsilon) < tol) break
      logit_mu1 <- log(pmin(pmax(mu1, 0.001), 0.999) /
                        (1 - pmin(pmax(mu1, 0.001), 0.999)))
      logit_mu0 <- log(pmin(pmax(mu0, 0.001), 0.999) /
                        (1 - pmin(pmax(mu0, 0.001), 0.999)))
      mu1 <- plogis(logit_mu1 + epsilon / ps)
      mu0 <- plogis(logit_mu0 - epsilon / (1 - ps))
    }
  } else {
    H <- treat / ps - (1 - treat) / (1 - ps)
    mu_comb <- mu1 * treat + mu0 * (1 - treat)
    resid <- y - mu_comb
    epsilon <- sum(resid * H) / sum(H^2)
    mu1 <- mu1 + epsilon / ps
    mu0 <- mu0 - epsilon / (1 - ps)
  }

  po1 <- mean(mu1); po0 <- mean(mu0)
  tau <- po1 - po0

  phi <- (mu1 - mu0 - tau) +
    treat * (y - mu1) / ps -
    (1 - treat) * (y - mu0) / (1 - ps)
  variance <- sum(phi^2) / n^2
  se <- sqrt(variance)

  z <- qnorm(0.975)
  list(tau = tau, se = se, po1 = po1, po0 = po0,
       ci_lo = tau - z * se, ci_hi = tau + z * se)
}

# ==========================================================================
# IPTW
# ==========================================================================

iptw <- function(y, treat, X, trim_lo = 0, trim_hi = 1) {
  ps_fit <- fit_logistic(X, treat)
  ps <- predict_logistic(ps_fit, X)
  lo <- ifelse(trim_lo > 0, trim_lo, 1e-10)
  hi <- ifelse(trim_hi < 1, trim_hi, 1 - 1e-10)
  ps <- pmin(pmax(ps, lo), hi)

  w <- ifelse(treat == 1, 1 / ps, 1 / (1 - ps))
  m1 <- weighted.mean(y[treat == 1], w[treat == 1])
  m0 <- weighted.mean(y[treat == 0], w[treat == 0])
  tau <- m1 - m0

  # Hajek SE
  phi <- ifelse(treat == 1,
                w * (y - m1),
                -w * (y - m0))
  variance <- sum(phi^2) / n^2
  se <- sqrt(variance)

  z <- qnorm(0.975)
  list(tau = tau, se = se,
       ci_lo = tau - z * se, ci_hi = tau + z * se)
}

# ==========================================================================
# G-COMPUTATION
# ==========================================================================

gcomp <- function(y, treat, X, is_binary = FALSE) {
  idx1 <- treat == 1; idx0 <- treat == 0
  fit1 <- fit_outcome(X[idx1, , drop = FALSE], y[idx1], is_binary)
  mu1 <- predict_outcome(fit1, X, is_binary)
  fit0 <- fit_outcome(X[idx0, , drop = FALSE], y[idx0], is_binary)
  mu0 <- predict_outcome(fit0, X, is_binary)

  po1 <- mean(mu1); po0 <- mean(mu0)
  tau <- po1 - po0

  phi <- (mu1 - mu0) - tau
  variance <- sum(phi^2) / n^2
  se <- sqrt(variance)

  z <- qnorm(0.975)
  list(tau = tau, se = se, po1 = po1, po0 = po0,
       ci_lo = tau - z * se, ci_hi = tau + z * se)
}

# ==========================================================================
# CROSS-FITTED AIPW
# ==========================================================================

crossfit_aipw <- function(y, treat, X, folds_vec,
                          trim_lo = 0.01, trim_hi = 0.99,
                          is_binary = FALSE) {
  K <- max(folds_vec)
  ps_cf <- rep(NA, n)
  mu1_cf <- rep(NA, n)
  mu0_cf <- rep(NA, n)
  n_trimmed <- 0

  for (k in seq_len(K)) {
    test_idx <- folds_vec == k
    train_idx <- !test_idx

    # PS
    ps_fit <- fit_logistic(X[train_idx, , drop = FALSE], treat[train_idx])
    ps_k <- predict_logistic(ps_fit, X[test_idx, , drop = FALSE])
    nt <- sum(ps_k < trim_lo | ps_k > trim_hi)
    n_trimmed <- n_trimmed + nt
    ps_k <- pmin(pmax(ps_k, trim_lo), trim_hi)
    ps_cf[test_idx] <- ps_k

    # Outcome treated
    t1 <- train_idx & treat == 1
    fit1 <- fit_outcome(X[t1, , drop = FALSE], y[t1], is_binary)
    mu1_cf[test_idx] <- predict_outcome(fit1, X[test_idx, , drop = FALSE], is_binary)

    # Outcome control
    t0 <- train_idx & treat == 0
    fit0 <- fit_outcome(X[t0, , drop = FALSE], y[t0], is_binary)
    mu0_cf[test_idx] <- predict_outcome(fit0, X[test_idx, , drop = FALSE], is_binary)
  }

  phi <- (mu1_cf - mu0_cf) +
    treat * (y - mu1_cf) / ps_cf -
    (1 - treat) * (y - mu0_cf) / (1 - ps_cf)
  tau <- mean(phi)
  if_centered <- (phi - tau)^2
  variance <- sum(if_centered) / n^2
  se <- sqrt(variance)

  aug1 <- mu1_cf + treat * (y - mu1_cf) / ps_cf
  aug0 <- mu0_cf + (1 - treat) * (y - mu0_cf) / (1 - ps_cf)
  po1 <- mean(aug1)
  po0 <- mean(aug0)

  z <- qnorm(0.975)
  list(tau = tau, se = se, po1 = po1, po0 = po0,
       ci_lo = tau - z * se, ci_hi = tau + z * se,
       n_trimmed = n_trimmed)
}

# ==========================================================================
# E-VALUE
# ==========================================================================

compute_evalue <- function(rr) {
  if (rr >= 1) {
    rr + sqrt(rr * (rr - 1))
  } else {
    ri <- 1 / rr
    ri + sqrt(ri * (ri - 1))
  }
}

# ==========================================================================
# PS DIAGNOSTICS
# ==========================================================================

ps_diagnostics <- function(ps, treat) {
  ps_mean <- mean(ps)
  ps_sd <- sd(ps)
  ps_min <- min(ps)
  ps_max <- max(ps)
  ps_mean1 <- mean(ps[treat == 1])
  ps_mean0 <- mean(ps[treat == 0])

  # C-statistic (Wilcoxon/Mann-Whitney)
  n1 <- sum(treat == 1); n0 <- sum(treat == 0)
  ranks <- rank(ps)
  sum_r1 <- sum(ranks[treat == 1])
  c_stat <- (sum_r1 - n1 * (n1 + 1) / 2) / (n1 * n0)

  # ESS
  w <- ifelse(treat == 1, 1 / ps, 1 / (1 - ps))
  ess <- sum(w)^2 / sum(w^2)
  ess_pct <- 100 * ess / n

  # Extreme PS
  n_extreme <- sum(ps < 0.05 | ps > 0.95)

  list(ps_mean = ps_mean, ps_sd = ps_sd, ps_min = ps_min, ps_max = ps_max,
       ps_mean1 = ps_mean1, ps_mean0 = ps_mean0,
       c_stat = c_stat, ess = ess, ess_pct = ess_pct,
       n_extreme = n_extreme)
}

# ==========================================================================
# COVARIATE BALANCE
# ==========================================================================

covariate_balance <- function(X, treat, ps) {
  w <- ifelse(treat == 1, 1 / ps, 1 / (1 - ps))
  results <- list()

  for (j in seq_len(ncol(X))) {
    v <- X[, j]
    m1 <- mean(v[treat == 1]); v1 <- var(v[treat == 1])
    m0 <- mean(v[treat == 0]); v0 <- var(v[treat == 0])
    pooled_sd <- sqrt((v1 + v0) / 2)
    raw_smd <- if (pooled_sd > 0) (m1 - m0) / pooled_sd else 0

    wm1 <- weighted.mean(v[treat == 1], w[treat == 1])
    wm0 <- weighted.mean(v[treat == 0], w[treat == 0])
    wt_smd <- if (pooled_sd > 0) (wm1 - wm0) / pooled_sd else 0

    results[[colnames(X)[j]]] <- list(raw_smd = raw_smd, wt_smd = wt_smd)
  }
  results
}

# ==========================================================================
# COMPUTE ALL RESULTS
# ==========================================================================

estimates <- data.frame(
  method = character(), estimand = character(),
  estimate = numeric(), se = numeric(),
  po1 = numeric(), po0 = numeric(),
  ci_lo = numeric(), ci_hi = numeric(),
  stringsAsFactors = FALSE
)

add_est <- function(method, estimand, r) {
  data.frame(method = method, estimand = estimand,
             estimate = r$tau, se = r$se,
             po1 = ifelse(is.null(r$po1), NA, r$po1),
             po0 = ifelse(is.null(r$po0), NA, r$po0),
             ci_lo = r$ci_lo, ci_hi = r$ci_hi,
             stringsAsFactors = FALSE)
}

# --- AIPW ATE (no trim) ---
r_aipw <- aipw(y, treat, X, "ATE", 0, 1, is_binary)
estimates <- rbind(estimates, add_est("aipw", "ATE", r_aipw))

# --- AIPW ATE (trimmed) ---
r_aipw_tr <- aipw(y, treat, X, "ATE", 0.01, 0.99, is_binary)
estimates <- rbind(estimates, add_est("aipw_trim", "ATE", r_aipw_tr))

# --- ATT (no trim) ---
r_att <- aipw(y, treat, X, "ATT", 0, 1, is_binary)
estimates <- rbind(estimates, add_est("aipw", "ATT", r_att))

# --- ATC (no trim) ---
r_atc <- aipw(y, treat, X, "ATC", 0, 1, is_binary)
estimates <- rbind(estimates, add_est("aipw", "ATC", r_atc))

# --- TMLE ATE (no trim) ---
r_tmle <- tmle(y, treat, X, 0, 1, is_binary)
estimates <- rbind(estimates, add_est("tmle", "ATE", r_tmle))

# --- TMLE ATE (trimmed) ---
r_tmle_tr <- tmle(y, treat, X, 0.01, 0.99, is_binary)
estimates <- rbind(estimates, add_est("tmle_trim", "ATE", r_tmle_tr))

# --- IPTW ---
r_iptw <- iptw(y, treat, X, 0, 1)
estimates <- rbind(estimates, add_est("iptw", "ATE", r_iptw))

# --- IPTW trimmed ---
r_iptw_tr <- iptw(y, treat, X, 0.01, 0.99)
estimates <- rbind(estimates, add_est("iptw_trim", "ATE", r_iptw_tr))

# --- G-computation ---
r_gc <- gcomp(y, treat, X, is_binary)
estimates <- rbind(estimates, add_est("gcomp", "ATE", r_gc))

# --- Cross-fitted AIPW (if fold variable provided) ---
if (!is.null(foldvar) && foldvar %in% names(df)) {
  folds_vec <- df[[foldvar]]
  r_cf <- crossfit_aipw(y, treat, X, folds_vec, 0.01, 0.99, is_binary)
  estimates <- rbind(estimates, add_est("crossfit", "ATE", r_cf))
}

# Write estimates
write.csv(estimates, paste0(output_prefix, "_estimates.csv"), row.names = FALSE)
cat(sprintf("  Wrote %d estimates to %s_estimates.csv\n",
            nrow(estimates), output_prefix))

# --- Row-level predictions (from AIPW no-trim) ---
preds <- data.frame(
  ps = r_aipw$ps,
  mu1 = r_aipw$mu1,
  mu0 = r_aipw$mu0,
  phi = r_aipw$phi
)
write.csv(preds, paste0(output_prefix, "_predictions.csv"), row.names = FALSE)
cat(sprintf("  Wrote %d rows to %s_predictions.csv\n", nrow(preds), output_prefix))

# --- Diagnostics ---
diag <- ps_diagnostics(r_aipw$ps, treat)
bal <- covariate_balance(X, treat, r_aipw$ps)

diag_df <- data.frame(
  metric = c("ps_mean", "ps_sd", "ps_min", "ps_max",
             "ps_mean1", "ps_mean0",
             "c_stat", "ess", "ess_pct", "n_extreme"),
  value = c(diag$ps_mean, diag$ps_sd, diag$ps_min, diag$ps_max,
            diag$ps_mean1, diag$ps_mean0,
            diag$c_stat, diag$ess, diag$ess_pct, diag$n_extreme),
  stringsAsFactors = FALSE
)

# Add balance metrics
for (vname in names(bal)) {
  diag_df <- rbind(diag_df,
    data.frame(metric = paste0("raw_smd_", vname),
               value = bal[[vname]]$raw_smd, stringsAsFactors = FALSE),
    data.frame(metric = paste0("wt_smd_", vname),
               value = bal[[vname]]$wt_smd, stringsAsFactors = FALSE))
}

# E-value (binary outcomes only)
if (is_binary) {
  po1_val <- r_aipw$po1; po0_val <- r_aipw$po0
  if (po0_val > 0) {
    rr <- po1_val / po0_val
    ev <- compute_evalue(rr)
    diag_df <- rbind(diag_df,
      data.frame(metric = "rr", value = rr, stringsAsFactors = FALSE),
      data.frame(metric = "evalue", value = ev, stringsAsFactors = FALSE))
  }
}

write.csv(diag_df, paste0(output_prefix, "_diagnostics.csv"), row.names = FALSE)
cat(sprintf("  Wrote %d metrics to %s_diagnostics.csv\n",
            nrow(diag_df), output_prefix))

# Summary
cat("\nResults:\n")
for (i in seq_len(nrow(estimates))) {
  cat(sprintf("  %-12s %-4s: est=%10.6f  se=%8.6f\n",
              estimates$method[i], estimates$estimand[i],
              estimates$estimate[i], estimates$se[i]))
}
