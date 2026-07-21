#!/usr/bin/env Rscript
# crossval_fiptiw.R - Generate FIPTIW reference weights for cross-validation
#
# Implements the Tompkins et al. (2025) DGP and computes IIW, IPTW, and
# FIPTIW weights for comparison with the Stata iivw package.
#
# Exports exactly these three files (this list is the contract):
#   1. Observed-only simulated dataset with weights (fiptiw_simdata.csv)
#   2. Model coefficients                           (fiptiw_coefs.csv)
#   3. Weighted GEE outcome fit                     (fiptiw_outcome_geeglm.csv)
#
# It does NOT write fiptiw_weights.csv, whatever earlier versions of this header
# claimed; the weights travel in fiptiw_simdata.csv.
#
# Usage: Rscript iivw/qa/crossval_fiptiw.R

library(survival)
library(geepack)

cat("=== FIPTIW Simulation Cross-Validation ===\n")
cat("Based on Tompkins, Dubin & Wallace (2025)\n\n")

cmd_args <- commandArgs(FALSE)
file_arg <- grep("^--file=", cmd_args, value = TRUE)
outdir <- if (length(file_arg)) {
    dirname(normalizePath(sub("^--file=", "", file_arg[1])))
} else {
    getwd()
}

expit <- function(x) 1 / (1 + exp(-x))

# =============================================================================
# 1. Data Generating Process (Tompkins et al. 2025 - simplified)
# =============================================================================

# Parameters from their base scenario
set.seed(20260306)
n <- 200
tau <- 7
beta1 <- 0.5    # treatment effect
beta2 <- 2      # W effect
beta3 <- 1      # Z effect
gamma1 <- 0.5   # D on visit intensity
gamma2 <- 0.3   # W(t) on visit intensity
gamma3 <- 0.6   # Z on visit intensity
alpha0 <- -1    # treatment model intercept
alpha1 <- 1.5   # W on treatment assignment

# Distribution parameters
mu_Z_D0 <- 2; var_Z_D0 <- 1
mu_Z_D1 <- 0; var_Z_D1 <- 0.5
var_phi <- 1.25; var_epsilon <- 1

cat("DGP parameters:\n")
cat("  n =", n, ", tau =", tau, "\n")
cat("  beta = (", beta1, ",", beta2, ",", beta3, ")\n")
cat("  gamma = (", gamma1, ",", gamma2, ",", gamma3, ")\n")
cat("  alpha = (", alpha0, ",", alpha1, ")\n\n")

# Generate data using a grid approach (matching Tompkins)
# Use fixed visit grid instead of thinning (simpler, reproducible)
all_data <- list()
obs_data <- list()

for (i in 1:n) {
    # Subject-level variables
    W <- runif(1, 0, 1)
    prD <- expit(alpha0 + alpha1 * W)
    D <- rbinom(1, 1, prD)
    Z <- ifelse(D == 0, rnorm(1, mu_Z_D0, sqrt(var_Z_D0)),
                rnorm(1, mu_Z_D1, sqrt(var_Z_D1)))
    phi <- rnorm(1, 0, sqrt(var_phi))

    # Generate visit times via thinning algorithm
    # Intensity: lambda(t) = eta * sqrt(t)/2 * exp(gamma1*D + gamma2*W*log(t) + gamma3*Z)
    eta <- rgamma(1, shape = 100, scale = 0.01)

    # Thinning: find visits in (0, tau]
    # Upper bound for intensity over [0, tau]
    t_grid <- seq(0.01, tau, by = 0.01)
    lambda_vals <- eta * sqrt(t_grid) / 2 *
        exp(gamma1 * D + gamma2 * W * log(t_grid) + gamma3 * Z)
    lambda_max <- max(lambda_vals) * 1.2

    # Generate candidate events from homogeneous Poisson
    n_candidates <- rpois(1, lambda_max * tau)
    if (n_candidates == 0) next
    candidate_times <- sort(runif(n_candidates, 0.01, tau))

    # Accept/reject
    lambda_at_candidates <- eta * sqrt(candidate_times) / 2 *
        exp(gamma1 * D + gamma2 * W * log(candidate_times) + gamma3 * Z)
    accept <- runif(n_candidates) < (lambda_at_candidates / lambda_max)
    visit_times <- candidate_times[accept]

    if (length(visit_times) < 2) next  # Need at least 2 visits

    # Censoring time (noninformative)
    C <- runif(1, tau / 2, tau)
    visit_times <- visit_times[visit_times <= C]
    if (length(visit_times) < 2) next

    # Round to avoid floating point issues
    visit_times <- round(visit_times, 4)

    # Generate outcomes at visit times
    Wt <- W * log(visit_times)
    cexp_Wt_D <- 0.5 * log(visit_times)
    cexp_Z_D <- ifelse(D == 0, mu_Z_D0, mu_Z_D1)

    y <- (2 - visit_times) + beta1 * D +
        beta2 * (Wt - cexp_Wt_D) +
        beta3 * (Z - cexp_Z_D) +
        phi + rnorm(length(visit_times), 0, sqrt(var_epsilon))

    # Store
    subj_data <- data.frame(
        id = i,
        time = visit_times,
        D = D,
        W = W,
        Wt = Wt,
        Z = Z,
        y = y,
        observed = 1
    )
    obs_data[[length(obs_data) + 1]] <- subj_data
}

# Combine
simdata_obs <- do.call(rbind, obs_data)
simdata_obs <- simdata_obs[order(simdata_obs$id, simdata_obs$time), ]

# Create lagged time for counting process
simdata_obs$time_lag <- ave(simdata_obs$time, simdata_obs$id,
    FUN = function(x) c(0, x[-length(x)]))

# Visit number within subject
simdata_obs$visit_n <- ave(rep(1, nrow(simdata_obs)), simdata_obs$id,
    FUN = cumsum)

n_actual <- length(unique(simdata_obs$id))
cat("Generated data: N =", nrow(simdata_obs), "observations,",
    n_actual, "subjects\n")
cat("Mean visits per subject:", round(nrow(simdata_obs) / n_actual, 1), "\n\n")

# =============================================================================
# 2. Compute IIW weights (stabilized, Tompkins method)
# =============================================================================

# We also need the FULL grid data for the Cox models
# But for simplicity, use the observed data in counting process format
# This matches how Tompkins computes it

# Marginal intensity model (numerator): D only
delta_fit <- coxph(Surv(time_lag, time, observed) ~ D,
    data = simdata_obs)
delta_hat <- coef(delta_fit)
delta_se <- sqrt(diag(vcov(delta_fit)))

# Conditional intensity model (denominator): D + Wt + Z
gamma_fit <- coxph(Surv(time_lag, time, observed) ~ D + Wt + Z,
    data = simdata_obs)
gamma_hat <- coef(gamma_fit)
gamma_se <- sqrt(diag(vcov(gamma_fit)))

cat("IIW models:\n")
cat("  Marginal (delta):     D =", round(delta_hat, 4), "\n")
cat("  Conditional (gamma): D =", round(gamma_hat[1], 4),
    " Wt =", round(gamma_hat[2], 4),
    " Z =", round(gamma_hat[3], 4), "\n")

# Stabilized IIW = exp(D * delta) / exp(D*gamma1 + Wt*gamma2 + Z*gamma3)
iiw_num <- exp(as.matrix(simdata_obs[, "D", drop = FALSE]) %*% delta_hat)
iiw_den <- exp(as.matrix(simdata_obs[, c("D", "Wt", "Z")]) %*% gamma_hat)
simdata_obs$iiw_weight <- as.numeric(iiw_num / iiw_den)

cat("  IIW weight summary:\n")
print(summary(simdata_obs$iiw_weight))

# =============================================================================
# 3. Compute IPTW weights (stabilized)
# =============================================================================

# Cross-sectional: one row per subject for propensity score
subj_data <- simdata_obs[!duplicated(simdata_obs$id), ]

# Full propensity score model
ps_fit <- glm(D ~ W, family = binomial(link = "logit"), data = subj_data)
ps_se <- sqrt(diag(vcov(ps_fit)))

# Marginal treatment probability
prD <- mean(subj_data$D)

# Predict PS for all observations (W is time-invariant)
ps <- expit(predict(ps_fit, newdata = simdata_obs))

# Stabilized IPTW
simdata_obs$iptw_weight <- ifelse(simdata_obs$D == 1,
    prD / ps,
    (1 - prD) / (1 - ps))

cat("\n  IPTW weight summary:\n")
print(summary(simdata_obs$iptw_weight))

# =============================================================================
# 4. FIPTIW = IIW * IPTW
# =============================================================================

simdata_obs$fiptiw_weight <- simdata_obs$iiw_weight * simdata_obs$iptw_weight

cat("\n  FIPTIW weight summary:\n")
print(summary(simdata_obs$fiptiw_weight))

# =============================================================================
# 5. Also compute unstabilized IIW (for comparison with iivw default)
# =============================================================================

# Unstabilized IIW = exp(-xb) from the conditional model
# predict() returns values for non-NA Surv rows; some rows may be dropped
# Use newdata to ensure alignment
xb_cond <- predict(gamma_fit, newdata = simdata_obs, type = "lp",
    reference = "zero")
simdata_obs$iiw_unstab <- exp(-xb_cond)

# The first1 convention: override the first observation's weight to 1 while
# every other row keeps its fitted exp(-xb). This is IrregLong's `first=TRUE`
# and it corresponds to iivw's baseline(entry) mode, where the study-entry
# visit is not a modelled monitoring event.
#
# Note that first1 is NOT invariant to the parameterization of the visit model:
# shifting a Cox covariate by a constant multiplies every fitted weight by a
# common factor while leaving the hard-coded 1s alone, so the baseline-to-
# follow-up ratio moves. Kept here because it is the published convention and
# the reference implementation's default, not because it is the better one.
first_obs <- !duplicated(simdata_obs$id)
simdata_obs$iiw_unstab_first1 <- simdata_obs$iiw_unstab
simdata_obs$iiw_unstab_first1[first_obs] <- 1

cat("\n  Unstabilized IIW (exp(-xb), first=1) summary:\n")
print(summary(simdata_obs$iiw_unstab_first1))

simdata_obs$stata_fiptiw_weight <-
    simdata_obs$iiw_unstab_first1 * simdata_obs$iptw_weight

# The weight matching iivw's baseline(event) mode, where EVERY visit including
# the first is a modelled event and keeps its own fitted rate-ratio weight.
# This is the oracle for the FIPTIW outcome comparison below, which runs the
# package in baseline(event).
simdata_obs$fiptiw_weight_baseevent <-
    simdata_obs$iiw_unstab * simdata_obs$iptw_weight

# Fitted with the baseline(event) weight, because the Stata side of this
# comparison (crossval_iivw.do XV10) runs iivw_weight in baseline(event). Using
# the first1 weight here would compare two different estimands and report the
# difference as a parity failure.
outcome_gee <- geeglm(
    y ~ D + time,
    id = id,
    data = simdata_obs,
    weights = fiptiw_weight_baseevent,
    family = gaussian(),
    corstr = "independence",
    std.err = "san.se"
)
outcome_gee_summary <- coef(summary(outcome_gee))

# =============================================================================
# 6. Export
# =============================================================================

# Export observed data with all weights
write.csv(simdata_obs,
    file = file.path(outdir, "fiptiw_simdata.csv"),
    row.names = FALSE)

# Export model coefficients
coefs <- data.frame(
    model = c(rep("marginal_cox", length(delta_hat)),
              rep("conditional_cox", length(gamma_hat)),
              "ps_intercept", "ps_W", "marginal_prD"),
    term = c(names(delta_hat), names(gamma_hat),
             "(Intercept)", "W", "prD"),
    estimate = c(delta_hat, gamma_hat,
                 coef(ps_fit), prD),
    se = c(delta_se, gamma_se, ps_se, NA_real_)
)
write.csv(coefs,
    file = file.path(outdir, "fiptiw_coefs.csv"),
    row.names = FALSE)

write.csv(
    data.frame(
        intercept = unname(coef(outcome_gee)[["(Intercept)"]]),
        D = unname(coef(outcome_gee)[["D"]]),
        time = unname(coef(outcome_gee)[["time"]]),
        se_intercept =
            unname(outcome_gee_summary["(Intercept)", "Std.err"]),
        se_D = unname(outcome_gee_summary["D", "Std.err"]),
        se_time = unname(outcome_gee_summary["time", "Std.err"])
    ),
    file = file.path(outdir, "fiptiw_outcome_geeglm.csv"),
    row.names = FALSE
)

cat("\nExported:\n")
cat("  ", file.path(outdir, "fiptiw_simdata.csv"), "\n")
cat("  ", file.path(outdir, "fiptiw_coefs.csv"), "\n")
cat("  ", file.path(outdir, "fiptiw_outcome_geeglm.csv"), "\n")

cat("\n=== FIPTIW cross-validation data ready ===\n")

# =============================================================================
# Completion sentinel + version manifest
# =============================================================================
# Stata's `shell' does not propagate a child process's exit status: _rc is 0
# even when Rscript is missing or dies halfway. The runner therefore cannot tell
# "R failed" from "R succeeded" by return code, and a failed R run would leave
# the reference CSVs above STALE while the crossval lane compared against them
# and passed. This file is written as the very last statement of the script, so
# its existence is the only proof the CSVs were actually regenerated.
#
# It is written from R rather than by a shell `touch' in the runner, both because
# `touch' is Unix-only and because a sentinel R writes itself proves the script
# reached its end -- a `touch' chained with && only proves Rscript exited 0.
#
# The manifest records the exact package versions that produced these CSVs. A
# parity failure that turns out to be an upstream version change is otherwise
# indistinguishable from a regression in iivw.
pkgs <- c("survival", "nlme", "IrregLong", "geepack", "ipw", "cobalt")
have <- pkgs[vapply(pkgs, requireNamespace, logical(1), quietly = TRUE)]
manifest <- data.frame(
    package = c("R", have),
    version = c(paste(R.version$major, R.version$minor, sep = "."),
                vapply(have, function(p) as.character(utils::packageVersion(p)),
                       character(1)))
)
write.csv(manifest, file = file.path(outdir, "crossval_fiptiw_versions.csv"),
          row.names = FALSE)
cat("\nReference package versions:\n")
print(manifest, row.names = FALSE)

writeLines("ok", file.path(outdir, "crossval_fiptiw.ok"))
