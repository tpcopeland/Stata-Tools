#!/usr/bin/env Rscript
#
# crossval_predict_phtest_r.R
# R-side cross-validation for finegray_predict (xb, cif, schoenfeld)
# and finegray_phtest (descriptive Schoenfeld-time correlation)
#
# Usage: Rscript crossval_predict_phtest_r.R <input.csv> <output_dir> [beta]
#
#   beta (optional): comma-separated coefficient vector, in the covariate
#   column order of <input.csv>.  When supplied, the Schoenfeld residuals
#   (and therefore the PH diagnostic) are computed at THESE coefficients instead of
#   crr's own fitted beta.  This isolates the residual/risk-set algorithm from
#   tiny optimizer-to-optimizer beta differences, which are otherwise amplified
#   through exp(z'beta) on wide-range covariates (e.g. ifp in [0,76]) and inflate
#   the correlation comparison. xb and cif outputs always use crr's own fitted beta,
#   so the coefficient agreement is still cross-checked downstream.
#
# Input CSV columns: id, time, status, <covariates>
#   status: 0=censored, 1=cause of interest, 2+=competing
#
# Output files:
#   r_xb.csv         - id, r_xb
#   r_cif.csv        - id, r_cif
#   r_schoenfeld.csv - time, <cov1>, ..., <covp>, event_id
#   r_phtest.csv     - variable, time_func, rho, n_events
#
# Requires: cmprsk (>= 2.2)

suppressPackageStartupMessages(library(cmprsk))

# ---------------------------------------------------------------------------
# ORACLE TOOLCHAIN BANNER (added 2026-09-02).  run_all.sh records "R_version"
# in the receipt, but it does that by asking Rscript at RECEIPT time -- after
# every oracle has already run, and saying nothing at all about which package
# versions produced the numbers.  A crossval whose oracle silently moved from
# one package release to another is exactly the drift a cross-validation exists
# to catch, so every crossval_*_r.R prints its own R and package versions to
# stdout, where the suite's .do file echoes them into the run log.
.fg_banner <- function(pkgs) {
    cat(sprintf("R_ENV: script=%s R=%s platform=%s\n",
                "crossval_predict_phtest_r.R", as.character(getRversion()), R.version$platform))
    for (p in pkgs) {
        v <- tryCatch(as.character(utils::packageVersion(p)),
                      error = function(e) "NOT-INSTALLED")
        cat(sprintf("R_ENV: package %s = %s\n", p, v))
    }
}
.fg_banner(c("cmprsk", "survival"))

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 2) {
    stop("Usage: Rscript crossval_predict_phtest_r.R <input.csv> <output_dir>")
}

input_file <- args[1]
output_dir <- args[2]
beta_override <- NULL
if (length(args) >= 3 && nzchar(args[3])) {
    beta_override <- as.numeric(strsplit(args[3], ",")[[1]])
}

# Oracle cache (added 2026-09-04): this script is a pure function of its
# inputs, so its output is cached and only recomputed when an input changes.
# See _fg_oracle_cache.R for the key and the fail-closed rules.
source(file.path(dirname(sub("^--file=", "", grep("^--file=",
       commandArgs(FALSE), value = TRUE)[1])), "_fg_oracle_cache.R"))
.fgc <- fg_oracle_cache_begin("predict_phtest",
        outputs = file.path(output_dir, c("r_xb.csv", "r_cif.csv",
                                          "r_schoenfeld.csv", "r_phtest.csv")),
        key_files = input_file,
        key_values = list(beta = if (length(args) >= 3) args[3] else ""),
        packages = c("cmprsk", "survival", "crrSC"))
if (identical(.fgc$state, "hit")) quit(save = "no", status = 0)

df <- read.csv(input_file, stringsAsFactors = FALSE)
cov_cols <- setdiff(names(df), c("id", "time", "status"))
Z <- as.matrix(df[, cov_cols, drop = FALSE])
n <- nrow(df)
p <- ncol(Z)
if (n == 0L || p == 0L || anyDuplicated(df$id) ||
    any(!is.finite(df$time)) || any(!is.finite(df$status)) ||
    any(!is.finite(Z))) {
    stop("input must have unique ids and finite time/status/covariate values")
}

cat(sprintf("Data: n=%d, p=%d, covariates: %s\n",
            n, p, paste(cov_cols, collapse = ", ")))

# Fit Fine-Gray model via cmprsk::crr
fit <- crr(df$time, df$status, cov1 = Z, failcode = 1, cencode = 0)
if (!isTRUE(fit$converged)) stop("crr did not converge")
if (length(fit$coef) != p || any(!is.finite(fit$coef))) {
    stop("crr returned an incomplete or nonfinite coefficient vector")
}
for (j in seq_len(p)) {
    cat(sprintf("  coef[%s] = %.8f\n", cov_cols[j], fit$coef[j]))
}

# =====================================================================
# 1. Linear predictor: xb = Z %*% beta
# =====================================================================
xb <- as.vector(Z %*% fit$coef)
if (any(!is.finite(xb))) stop("linear-predictor reference is nonfinite")
write.csv(data.frame(id = df$id, r_xb = xb),
          file.path(output_dir, "r_xb.csv"), row.names = FALSE)
cat(sprintf("  xb range: [%.6f, %.6f]\n", min(xb), max(xb)))

# =====================================================================
# 2. CIF at each observation's (time, covariates)
#    CIF(t|z) = 1 - exp(-H0(t) * exp((z-ubar)'beta))
#    predict.crr handles the centering internally
# =====================================================================
pred <- predict(fit, Z)
cif_values <- numeric(n)
pred_times <- pred[, 1]
for (i in seq_len(n)) {
    idx <- which(pred_times <= df$time[i])
    if (length(idx) > 0) {
        cif_values[i] <- pred[max(idx), i + 1]
    }
}
if (any(!is.finite(cif_values))) stop("CIF reference is nonfinite")
write.csv(data.frame(id = df$id, r_cif = cif_values),
          file.path(output_dir, "r_cif.csv"), row.names = FALSE)
cat(sprintf("  CIF range: [%.6f, %.6f]\n", min(cif_values), max(cif_values)))

# =====================================================================
# 3. Schoenfeld residuals (manual FG risk-set computation)
#    r_jk = z_{jk} - z_bar_k(t_j)
#    where z_bar is the IPCW-weighted mean over the risk set at t_j
# =====================================================================

# Censoring survivor G.  REWRITTEN 2026-09-02.  What stood here was a hand
# written Kaplan-Meier loop that reproduced finegray's own post-jump convention
# ("G[i] = KM survival AFTER processing censoring events at t[i]") and its 1e-10
# floor.  An oracle that reimplements the convention under test is a mirror, not
# an independent check: the arm could not have disagreed with the package about
# G no matter what the package did.
#
# It is now survival::survfit on the censoring indicator, evaluated as the LEFT
# limit G(t-) -- the same construction crossval_finegray_zzf_r.R uses for its
# all-cause survivor (`findInterval(u - 1e-12, ev)'), and the convention
# crrSC::crrs and survival::finegray both use.  No floor is applied: if G
# reaches 0 the comparison should say so rather than silently clamp.
make_G <- function(time, status) {
    km <- survival::survfit(survival::Surv(time, as.numeric(status == 0)) ~ 1)
    ev <- km$time
    sv <- km$surv
    # G(u-) = the KM value carried by the last censoring time STRICTLY BELOW u
    function(u) {
        idx <- findInterval(u - 1e-12, ev)
        c(1, sv)[idx + 1L]
    }
}
Gfun <- make_G(df$time, df$status)
G <- Gfun(df$time)
if (any(!is.finite(G))) stop("censoring survivor G is nonfinite")
cat(sprintf("  G(t-) from survival::survfit: range [%.10f, %.10f]\n",
            min(G), max(G)))
if (!is.null(beta_override)) {
    if (length(beta_override) != p || any(!is.finite(beta_override)))
        stop(sprintf("beta override length %d != p %d", length(beta_override), p))
    beta <- beta_override
    cat(sprintf("  Schoenfeld/PH computed at supplied beta: %s\n",
                paste(sprintf("%.8f", beta), collapse = ", ")))
} else {
    beta <- fit$coef
}
expeta <- exp(as.vector(Z %*% beta))
is_cause <- (df$status == 1)
is_compete <- (df$status > 1)

# Sort cause events by time
cause_idx <- which(is_cause)
cause_order <- order(df$time[cause_idx])
cause_sorted <- cause_idx[cause_order]
n_events <- length(cause_sorted)
cat(sprintf("  Cause events: %d\n", n_events))

sch_mat <- matrix(NA, nrow = n_events, ncol = p + 2)
colnames(sch_mat) <- c("time", cov_cols, "event_id")

# Direct O(n * n_events) computation for correctness
for (jj in seq_len(n_events)) {
    j <- cause_sorted[jj]
    tj <- df$time[j]

    # Risk set: subjects with t >= tj (weight 1) + competing events
    # before tj (IPCW weight G(tj)/G(ti))
    S0 <- 0.0
    S1 <- rep(0.0, p)
    for (ii in seq_len(n)) {
        if (df$time[ii] >= tj) {
            S0 <- S0 + expeta[ii]
            S1 <- S1 + expeta[ii] * Z[ii, ]
        } else if (is_compete[ii]) {
            w <- G[j] / G[ii]
            S0 <- S0 + w * expeta[ii]
            S1 <- S1 + w * expeta[ii] * Z[ii, ]
        }
    }

    z_bar <- S1 / S0
    sch_mat[jj, 1] <- tj
    sch_mat[jj, 2:(p + 1)] <- Z[j, ] - z_bar
    sch_mat[jj, p + 2] <- df$id[j]
}

if (any(!is.finite(sch_mat))) stop("Schoenfeld reference is nonfinite")
write.csv(as.data.frame(sch_mat),
          file.path(output_dir, "r_schoenfeld.csv"), row.names = FALSE)

# =====================================================================
# 4. PH diagnostic: correlation of raw Schoenfeld residuals with time
#
#    ORACLE SCOPE. cmprsk ships no PH test, so this script recomputes the
#    descriptive correlation by the same rule as the .ado. The independent
#    content of the comparison is crr's beta and the Schoenfeld residuals built
#    from it (section 3 / test P11), not a null calibration.
#
#    Before 1.2.0 this script also emitted per-variable chi2/p columns and a
#    "GLOBAL" row that summed those components and referred the total to
#    chi2(p), reproducing finegray_phtest's own rule exactly. That was a mirror
#    oracle, not independent calibration. The inferential columns and omnibus
#    are retired: the Stata side compares only the `rho' column written here,
#    which is a coding-consistency check rather than a test-calibration claim.
# =====================================================================
phtest_rows <- list()
for (tf_name in c("rank", "log", "identity")) {
    tf <- switch(tf_name,
        rank = rank(sch_mat[, 1]),
        log = log(sch_mat[, 1]),
        identity = sch_mat[, 1])
    for (k in seq_len(p)) {
        r_k <- sch_mat[, k + 1]
        valid <- !is.na(r_k) & !is.na(tf)
        nv <- sum(valid)
        if (nv >= 3) {
            rho <- cor(r_k[valid], tf[valid])
            phtest_rows[[length(phtest_rows) + 1]] <- data.frame(
                variable = cov_cols[k], time_func = tf_name,
                rho = rho, n_events = nv,
                stringsAsFactors = FALSE)
            cat(sprintf("  PH[%s,%s]: rho=%.6f n=%d\n",
                        cov_cols[k], tf_name, rho, nv))
        }
    }
}
phtest_df <- do.call(rbind, phtest_rows)
if (is.null(phtest_df) || nrow(phtest_df) != 3L * p ||
    anyDuplicated(phtest_df[c("variable", "time_func")]) ||
    any(!is.finite(phtest_df$rho)) ||
    any(!is.finite(phtest_df$n_events))) {
    stop("PH-diagnostic reference is incomplete, duplicated, or nonfinite")
}
write.csv(phtest_df, file.path(output_dir, "r_phtest.csv"),
          row.names = FALSE)
fg_oracle_cache_end(.fgc)

cat(sprintf("\nAll results written to %s\n", output_dir))
