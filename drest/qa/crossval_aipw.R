#!/usr/bin/env Rscript
#
# crossval_aipw.R — Independent AIPW/TMLE in base R for drest cross-validation
#
# Zero dependencies beyond base R. Implements logistic regression, OLS,
# AIPW, and TMLE from first principles for maximum independence.
#
# Usage:
#   Rscript crossval_aipw.R <input.csv> <output.csv>

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 2) {
  cat("Usage: Rscript crossval_aipw.R <input.csv> <output.csv>\n")
  quit(status = 1)
}

input_file <- args[1]
output_file <- args[2]

# Read data
df <- read.csv(input_file)
y <- df$y
treat <- df$treat
cov_cols <- setdiff(names(df), c("y", "treat"))
X <- as.matrix(df[, cov_cols, drop = FALSE])
n <- length(y)
is_binary <- all(y %in% c(0, 1))

cat(sprintf("Input:  %s (%d obs, %d covs, binary=%s)\n",
            input_file, n, ncol(X), is_binary))

# --- Helper: logistic regression via glm ---
fit_logistic <- function(X, y) {
  dat <- data.frame(y = y, X)
  fit <- glm(y ~ ., data = dat, family = binomial(link = "logit"))
  return(fit)
}

predict_logistic <- function(fit, X) {
  dat <- data.frame(X)
  names(dat) <- names(coef(fit))[-1]  # match covariate names
  predict(fit, newdata = dat, type = "response")
}

# --- Helper: OLS ---
fit_ols <- function(X, y) {
  dat <- data.frame(y = y, X)
  fit <- lm(y ~ ., data = dat)
  return(fit)
}

predict_ols <- function(fit, X) {
  dat <- data.frame(X)
  names(dat) <- names(coef(fit))[-1]
  predict(fit, newdata = dat)
}

# --- AIPW ---
aipw_ate <- function(y, treat, X, trim_lo = 0, trim_hi = 1,
                     is_binary = FALSE) {
  # Step 1: Propensity score
  ps_fit <- fit_logistic(X, treat)
  ps <- predict_logistic(ps_fit, X)
  ps <- pmin(pmax(ps, ifelse(trim_lo > 0, trim_lo, 1e-10)),
             ifelse(trim_hi < 1, trim_hi, 1 - 1e-10))

  # Step 2: Outcome models per arm
  idx1 <- treat == 1
  idx0 <- treat == 0

  if (is_binary) {
    fit1 <- fit_logistic(X[idx1, , drop = FALSE], y[idx1])
    mu1 <- predict_logistic(fit1, X)
    fit0 <- fit_logistic(X[idx0, , drop = FALSE], y[idx0])
    mu0 <- predict_logistic(fit0, X)
  } else {
    fit1 <- fit_ols(X[idx1, , drop = FALSE], y[idx1])
    mu1 <- predict_ols(fit1, X)
    fit0 <- fit_ols(X[idx0, , drop = FALSE], y[idx0])
    mu0 <- predict_ols(fit0, X)
  }

  # Step 3: AIPW pseudo-outcome
  phi <- (mu1 - mu0) +
    treat * (y - mu1) / ps -
    (1 - treat) * (y - mu0) / (1 - ps)

  # Step 4: ATE
  ate <- mean(phi)

  # Step 5: IF-based SE
  variance <- sum((phi - ate)^2) / n^2
  se <- sqrt(variance)

  # Augmented PO means
  aug1 <- mu1 + treat * (y - mu1) / ps
  aug0 <- mu0 + (1 - treat) * (y - mu0) / (1 - ps)
  po1 <- mean(aug1)
  po0 <- mean(aug0)

  z <- qnorm(0.975)
  list(ate = ate, se = se, po1 = po1, po0 = po0,
       ci_lo = ate - z * se, ci_hi = ate + z * se)
}

# --- TMLE ---
tmle_ate <- function(y, treat, X, trim_lo = 0, trim_hi = 1,
                     is_binary = FALSE, max_iter = 100, tol = 1e-5) {
  # Steps 1-2: same as AIPW
  ps_fit <- fit_logistic(X, treat)
  ps <- predict_logistic(ps_fit, X)
  ps <- pmin(pmax(ps, ifelse(trim_lo > 0, trim_lo, 1e-10)),
             ifelse(trim_hi < 1, trim_hi, 1 - 1e-10))

  idx1 <- treat == 1
  idx0 <- treat == 0

  if (is_binary) {
    fit1 <- fit_logistic(X[idx1, , drop = FALSE], y[idx1])
    mu1 <- predict_logistic(fit1, X)
    fit0 <- fit_logistic(X[idx0, , drop = FALSE], y[idx0])
    mu0 <- predict_logistic(fit0, X)
  } else {
    fit1 <- fit_ols(X[idx1, , drop = FALSE], y[idx1])
    mu1 <- predict_ols(fit1, X)
    fit0 <- fit_ols(X[idx0, , drop = FALSE], y[idx0])
    mu0 <- predict_ols(fit0, X)
  }

  # Step 3: Targeting
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
    # Linear fluctuation (one step)
    H <- treat / ps - (1 - treat) / (1 - ps)
    mu_comb <- mu1 * treat + mu0 * (1 - treat)
    resid <- y - mu_comb
    epsilon <- sum(resid * H) / sum(H^2)

    mu1 <- mu1 + epsilon / ps
    mu0 <- mu0 - epsilon / (1 - ps)
  }

  # Step 4: TMLE estimate
  po1 <- mean(mu1)
  po0 <- mean(mu0)
  ate <- po1 - po0

  # Step 5: IF-based SE
  phi <- (mu1 - mu0 - ate) +
    treat * (y - mu1) / ps -
    (1 - treat) * (y - mu0) / (1 - ps)
  variance <- sum(phi^2) / n^2
  se <- sqrt(variance)

  z <- qnorm(0.975)
  list(ate = ate, se = se, po1 = po1, po0 = po0,
       ci_lo = ate - z * se, ci_hi = ate + z * se)
}

# --- Compute all estimators ---
results <- data.frame(
  estimator = character(),
  ate = numeric(), se = numeric(),
  po1 = numeric(), po0 = numeric(),
  ci_lo = numeric(), ci_hi = numeric(),
  stringsAsFactors = FALSE
)

# AIPW no trim
r <- aipw_ate(y, treat, X, 0, 1, is_binary)
results <- rbind(results, data.frame(
  estimator = "aipw_notrim", ate = r$ate, se = r$se,
  po1 = r$po1, po0 = r$po0, ci_lo = r$ci_lo, ci_hi = r$ci_hi))

# AIPW with trim
r <- aipw_ate(y, treat, X, 0.01, 0.99, is_binary)
results <- rbind(results, data.frame(
  estimator = "aipw_trim", ate = r$ate, se = r$se,
  po1 = r$po1, po0 = r$po0, ci_lo = r$ci_lo, ci_hi = r$ci_hi))

# TMLE no trim
r <- tmle_ate(y, treat, X, 0, 1, is_binary)
results <- rbind(results, data.frame(
  estimator = "tmle_notrim", ate = r$ate, se = r$se,
  po1 = r$po1, po0 = r$po0, ci_lo = r$ci_lo, ci_hi = r$ci_hi))

# TMLE with trim
r <- tmle_ate(y, treat, X, 0.01, 0.99, is_binary)
results <- rbind(results, data.frame(
  estimator = "tmle_trim", ate = r$ate, se = r$se,
  po1 = r$po1, po0 = r$po0, ci_lo = r$ci_lo, ci_hi = r$ci_hi))

write.csv(results, output_file, row.names = FALSE)

cat(sprintf("Output: %s\n", output_file))
for (i in seq_len(nrow(results))) {
  cat(sprintf("  %-16s: ATE=%10.6f  SE=%8.6f  PO1=%8.4f  PO0=%8.4f\n",
              results$estimator[i], results$ate[i], results$se[i],
              results$po1[i], results$po0[i]))
}
