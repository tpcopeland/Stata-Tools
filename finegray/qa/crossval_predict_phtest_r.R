#!/usr/bin/env Rscript
#
# crossval_predict_phtest_r.R
# R-side cross-validation for finegray_predict (xb, cif, schoenfeld)
# and finegray_phtest (PH test via Schoenfeld-time correlation)
#
# Usage: Rscript crossval_predict_phtest_r.R <input.csv> <output_dir>
#
# Input CSV columns: id, time, status, <covariates>
#   status: 0=censored, 1=cause of interest, 2+=competing
#
# Output files:
#   r_xb.csv         - id, r_xb
#   r_cif.csv        - id, r_cif
#   r_schoenfeld.csv - time, <cov1>, ..., <covp>, event_id
#   r_phtest.csv     - variable, time_func, rho, chi2, p_value, n_events
#
# Requires: cmprsk (>= 2.2)

suppressPackageStartupMessages(library(cmprsk))

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 2) {
    stop("Usage: Rscript crossval_predict_phtest_r.R <input.csv> <output_dir>")
}

input_file <- args[1]
output_dir <- args[2]

df <- read.csv(input_file, stringsAsFactors = FALSE)
cov_cols <- setdiff(names(df), c("id", "time", "status"))
Z <- as.matrix(df[, cov_cols, drop = FALSE])
n <- nrow(df)
p <- ncol(Z)

cat(sprintf("Data: n=%d, p=%d, covariates: %s\n",
            n, p, paste(cov_cols, collapse = ", ")))

# Fit Fine-Gray model via cmprsk::crr
fit <- crr(df$time, df$status, cov1 = Z, failcode = 1, cencode = 0)
if (!fit$converged) cat("WARNING: crr did not converge\n")
for (j in seq_len(p)) {
    cat(sprintf("  coef[%s] = %.8f\n", cov_cols[j], fit$coef[j]))
}

# =====================================================================
# 1. Linear predictor: xb = Z %*% beta
# =====================================================================
xb <- as.vector(Z %*% fit$coef)
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
write.csv(data.frame(id = df$id, r_cif = cif_values),
          file.path(output_dir, "r_cif.csv"), row.names = FALSE)
cat(sprintf("  CIF range: [%.6f, %.6f]\n", min(cif_values), max(cif_values)))

# =====================================================================
# 3. Schoenfeld residuals (manual FG risk-set computation)
#    r_jk = z_{jk} - z_bar_k(t_j)
#    where z_bar is the IPCW-weighted mean over the risk set at t_j
# =====================================================================

# KM of censoring distribution, matching Stata's convention:
# G[i] = KM survival AFTER processing censoring events at t[i]
compute_G <- function(time, status) {
    n <- length(time)
    G <- numeric(n)
    ord <- order(time)
    surv <- 1.0
    n_risk <- n
    i <- 1
    while (i <= n) {
        cur_time <- time[ord[i]]
        j <- i
        while (j <= n && time[ord[j]] == cur_time) j <- j + 1
        n_cens <- sum(status[ord[i:(j - 1)]] == 0)
        if (n_cens > 0 && n_risk > 0) {
            surv <- surv * (1 - n_cens / n_risk)
        }
        for (k in i:(j - 1)) {
            G[ord[k]] <- surv
            n_risk <- n_risk - 1
        }
        i <- j
    }
    G[G < 1e-10] <- 1e-10
    return(G)
}

G <- compute_G(df$time, df$status)
beta <- fit$coef
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

write.csv(as.data.frame(sch_mat),
          file.path(output_dir, "r_schoenfeld.csv"), row.names = FALSE)

# =====================================================================
# 4. PH test: correlation of Schoenfeld residuals with time
#    Pearson correlation is scale-invariant, so unscaled residuals
#    give the same rho and chi2 as Grambsch-Therneau scaled residuals.
#    chi2 = N * rho^2, summed for global test.
# =====================================================================
phtest_rows <- list()
for (tf_name in c("rank", "log", "identity")) {
    tf <- switch(tf_name,
        rank = rank(sch_mat[, 1]),
        log = log(sch_mat[, 1]),
        identity = sch_mat[, 1])
    global_chi2 <- 0
    for (k in seq_len(p)) {
        r_k <- sch_mat[, k + 1]
        valid <- !is.na(r_k) & !is.na(tf)
        nv <- sum(valid)
        if (nv >= 3) {
            rho <- cor(r_k[valid], tf[valid])
            chi2 <- nv * rho^2
            pval <- pchisq(chi2, 1, lower.tail = FALSE)
            global_chi2 <- global_chi2 + chi2
            phtest_rows[[length(phtest_rows) + 1]] <- data.frame(
                variable = cov_cols[k], time_func = tf_name,
                rho = rho, chi2 = chi2, p_value = pval, n_events = nv,
                stringsAsFactors = FALSE)
            cat(sprintf("  PH[%s,%s]: rho=%.6f chi2=%.4f p=%.4f\n",
                        cov_cols[k], tf_name, rho, chi2, pval))
        }
    }
    global_p <- pchisq(global_chi2, p, lower.tail = FALSE)
    phtest_rows[[length(phtest_rows) + 1]] <- data.frame(
        variable = "GLOBAL", time_func = tf_name,
        rho = NA, chi2 = global_chi2, p_value = global_p,
        n_events = n_events, stringsAsFactors = FALSE)
    cat(sprintf("  PH[GLOBAL,%s]: chi2=%.4f p=%.4f\n",
                tf_name, global_chi2, global_p))
}
phtest_df <- do.call(rbind, phtest_rows)
write.csv(phtest_df, file.path(output_dir, "r_phtest.csv"),
          row.names = FALSE)

cat(sprintf("\nAll results written to %s\n", output_dir))
