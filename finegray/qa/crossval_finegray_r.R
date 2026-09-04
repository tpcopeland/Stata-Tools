#!/usr/bin/env Rscript
#
# crossval_finegray_r.R
# R-side cross-validation for finegray package using cmprsk::crr and fastcmprsk::fastCrr
#
# Usage (called from crossval_finegray.do via Stata's shell):
#   Rscript crossval_finegray_r.R <input_csv> <output_csv>
#
# input_csv:  Stacked CSV with columns: id, time, status, dataset, <covariates>
# output_csv: Long-form CSV with columns: dataset, quantity, variable, value
#
# Requires: cmprsk (>= 2.2), fastcmprsk (>= 1.24)

# cmprsk::crr is the authoritative Fine-Gray reference and is required.
# fastcmprsk::fastCrr is a secondary cross-check; it has been archived on CRAN
# and may be unavailable on newer R. Load it optionally so the cmprsk parity
# still runs when fastcmprsk is absent.
suppressPackageStartupMessages({
    library(cmprsk)
})

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
                "crossval_finegray_r.R", as.character(getRversion()), R.version$platform))
    for (p in pkgs) {
        v <- tryCatch(as.character(utils::packageVersion(p)),
                      error = function(e) "NOT-INSTALLED")
        cat(sprintf("R_ENV: package %s = %s\n", p, v))
    }
}
.fg_banner(c("cmprsk", "fastcmprsk", "survival"))

# REPRODUCIBILITY (added 2026-09-02).  fastcmprsk::fastCrr's variance is a
# BOOTSTRAP (varianceControl(B = 200) below), so without a seed the SEs this
# script emits -- and therefore crossval_finegray.do's C49 comparison against
# them -- differed from run to run.  A cross-validation gate whose reference
# moves on every invocation cannot be tightened, and a failure cannot be
# reproduced.  Seed once, here, before anything random runs.
set.seed(20260902)
have_fast <- requireNamespace("fastcmprsk", quietly = TRUE)
if (have_fast) {
    suppressPackageStartupMessages(library(fastcmprsk))
} else {
    cat("NOTE: fastcmprsk unavailable; running cmprsk parity only\n")
}

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 2) {
    stop("Usage: Rscript crossval_finegray_r.R <input_csv> <output_csv>")
}

input_file  <- args[1]
output_file <- args[2]

# Oracle cache (added 2026-09-04): this script is a pure function of its
# inputs, so its output is cached and only recomputed when an input changes.
# See _fg_oracle_cache.R for the key and the fail-closed rules.
source(file.path(dirname(sub("^--file=", "", grep("^--file=",
       commandArgs(FALSE), value = TRUE)[1])), "_fg_oracle_cache.R"))
.fgc <- fg_oracle_cache_begin('finegray', outputs = output_file,
                              key_files = input_file,
                              packages = c("cmprsk", "fastcmprsk", "survival"))
if (identical(.fgc$state, "hit")) quit(save = "no", status = 0)

df <- read.csv(input_file, stringsAsFactors = FALSE)
datasets <- unique(df$dataset)
results <- data.frame(dataset = character(), quantity = character(),
                      variable = character(), value = numeric(),
                      stringsAsFactors = FALSE)

add_row <- function(ds, qty, var, val) {
    data.frame(dataset = ds, quantity = qty, variable = var, value = val,
               stringsAsFactors = FALSE)
}

for (ds in datasets) {
    sub <- df[df$dataset == ds, ]
    all_cols <- setdiff(names(sub), c("id", "time", "status", "dataset"))
    # Drop columns that are all NA (from stacking datasets with different covariates)
    all_cols <- all_cols[sapply(all_cols, function(x) !all(is.na(sub[[x]])))]
    # Separate strata column from covariates
    cov_cols <- setdiff(all_cols, "strata")
    Z <- as.matrix(sub[, cov_cols, drop = FALSE])
    p <- ncol(Z)
    has_strata <- "strata" %in% all_cols && !all(is.na(sub[["strata"]]))

    cat(sprintf("\n=== Dataset: %s (n=%d, p=%d) ===\n", ds, nrow(sub), p))

    # Fit cause 1
    fit <- crr(sub$time, sub$status, cov1 = Z, failcode = 1, cencode = 0)

    if (!isTRUE(fit$converged)) {
        stop(sprintf("crr did not converge for dataset %s", ds))
    }

    # Coefficients
    for (j in seq_along(cov_cols)) {
        results <- rbind(results, add_row(ds, "coef", cov_cols[j], fit$coef[j]))
        cat(sprintf("  coef[%s] = %12.8f\n", cov_cols[j], fit$coef[j]))
    }

    # Robust SEs (crr default variance)
    se_robust <- sqrt(diag(fit$var))
    for (j in seq_along(cov_cols)) {
        results <- rbind(results, add_row(ds, "se_robust", cov_cols[j], se_robust[j]))
        cat(sprintf("  se_robust[%s] = %12.8f\n", cov_cols[j], se_robust[j]))
    }

    # Model-based SEs (inverse information)
    se_model <- sqrt(diag(fit$invinf))
    for (j in seq_along(cov_cols)) {
        results <- rbind(results, add_row(ds, "se_model", cov_cols[j], se_model[j]))
        cat(sprintf("  se_model[%s] = %12.8f\n", cov_cols[j], se_model[j]))
    }

    # Log pseudo-likelihood
    results <- rbind(results, add_row(ds, "loglik", "final", fit$loglik))
    results <- rbind(results, add_row(ds, "loglik", "null", fit$loglik.null))
    cat(sprintf("  loglik: null=%12.6f final=%12.6f\n", fit$loglik.null, fit$loglik))

    # Cumulative baseline subhazard at last event time
    cum_bh <- cumsum(fit$bfitj)
    results <- rbind(results, add_row(ds, "cumbasehaz", "tmax", tail(cum_bh, 1)))
    cat(sprintf("  cumbasehaz(tmax) = %12.8f\n", tail(cum_bh, 1)))

    # CIF at reference covariate pattern (all zeros) at evaluation times
    z_ref <- matrix(0, nrow = 1, ncol = p)
    pred <- predict(fit, z_ref)
    # pred is a matrix: column 1 = times, column 2 = CIF
    eval_times <- c(2, 5, 10)
    for (tt in eval_times) {
        idx <- which(pred[, 1] <= tt)
        if (length(idx) > 0) {
            cif_val <- pred[max(idx), 2]
        } else {
            cif_val <- 0
        }
        results <- rbind(results, add_row(ds, "cif_ref",
                                          paste0("t", tt), cif_val))
        cat(sprintf("  CIF(t=%d, z=0) = %12.8f\n", tt, cif_val))
    }

    # --- cmprsk::crr with cengroup (stratified censoring) ---
    if (has_strata) {
        cat(sprintf("\n--- cmprsk::crr with cengroup for %s ---\n", ds))
        strata_vec <- sub[["strata"]]

        fit_strata <- crr(sub$time, sub$status, cov1 = Z,
                          failcode = 1, cencode = 0,
                          cengroup = strata_vec)

        if (!isTRUE(fit_strata$converged)) {
            stop(sprintf("crr+cengroup did not converge for %s", ds))
        }

        # Coefficients
        for (j in seq_along(cov_cols)) {
            results <- rbind(results, add_row(ds, "strata_coef",
                                              cov_cols[j], fit_strata$coef[j]))
            cat(sprintf("  strata coef[%s] = %12.8f\n",
                        cov_cols[j], fit_strata$coef[j]))
        }

        # Robust SEs
        se_strata <- sqrt(diag(fit_strata$var))
        for (j in seq_along(cov_cols)) {
            results <- rbind(results, add_row(ds, "strata_se_robust",
                                              cov_cols[j], se_strata[j]))
            cat(sprintf("  strata se_robust[%s] = %12.8f\n",
                        cov_cols[j], se_strata[j]))
        }

        # Log pseudo-likelihood
        results <- rbind(results, add_row(ds, "strata_loglik", "final",
                                          fit_strata$loglik))
        results <- rbind(results, add_row(ds, "strata_loglik", "null",
                                          fit_strata$loglik.null))
        cat(sprintf("  strata loglik: null=%12.6f final=%12.6f\n",
                    fit_strata$loglik.null, fit_strata$loglik))

        # Cumulative baseline subhazard at last event time
        cum_bh_strata <- cumsum(fit_strata$bfitj)
        results <- rbind(results, add_row(ds, "strata_cumbasehaz", "tmax",
                                          tail(cum_bh_strata, 1)))
        cat(sprintf("  strata cumbasehaz(tmax) = %12.8f\n",
                    tail(cum_bh_strata, 1)))

        # CIF at reference pattern (z=0)
        z_ref_s <- matrix(0, nrow = 1, ncol = p)
        pred_strata <- predict(fit_strata, z_ref_s)
        for (tt in eval_times) {
            idx_s <- which(pred_strata[, 1] <= tt)
            if (length(idx_s) > 0) {
                cif_val_s <- pred_strata[max(idx_s), 2]
            } else {
                cif_val_s <- 0
            }
            results <- rbind(results, add_row(ds, "strata_cif_ref",
                                              paste0("t", tt), cif_val_s))
            cat(sprintf("  strata CIF(t=%d, z=0) = %12.8f\n", tt, cif_val_s))
        }
    }

    # --- fastcmprsk::fastCrr (skip for strata-only datasets) ---
    if (has_strata) {
        cat(sprintf("\n--- Skipping fastCrr for %s (strata dataset) ---\n", ds))
        next
    }
    if (!have_fast) {
        cat(sprintf("\n--- Skipping fastCrr for %s (fastcmprsk unavailable) ---\n", ds))
        next
    }
    cat(sprintf("\n--- fastcmprsk::fastCrr for %s ---\n", ds))

    # Build Crisk response object
    cr <- Crisk(ftime = sub$time, fstatus = sub$status,
                cencode = 0, failcode = 1)

    # Fit unpenalized model (variance via bootstrap, B=200 for stability)
    fit_fast <- fastCrr(cr ~ Z, data = data.frame(cr = cr, Z = Z),
                        variance = TRUE,
                        var.control = varianceControl(B = 200,
                                                      useMultipleCores = FALSE),
                        returnDataFrame = TRUE)
    if (any(!is.finite(fit_fast$coef)) ||
        any(!is.finite(fit_fast$var)) ||
        !is.finite(fit_fast$logLik) ||
        !is.finite(fit_fast$logLik.null)) {
        stop(sprintf("fastCrr returned nonfinite results for dataset %s", ds))
    }

    # Coefficients
    for (j in seq_along(cov_cols)) {
        results <- rbind(results, add_row(ds, "fastcmprsk_coef",
                                          cov_cols[j], fit_fast$coef[j]))
        cat(sprintf("  fastCrr coef[%s] = %12.8f\n", cov_cols[j],
                    fit_fast$coef[j]))
    }

    # Bootstrap SEs
    se_fast <- sqrt(diag(fit_fast$var))
    for (j in seq_along(cov_cols)) {
        results <- rbind(results, add_row(ds, "fastcmprsk_se",
                                          cov_cols[j], se_fast[j]))
        cat(sprintf("  fastCrr SE[%s] = %12.8f\n", cov_cols[j],
                    se_fast[j]))
    }

    # Log pseudo-likelihood
    results <- rbind(results, add_row(ds, "fastcmprsk_loglik", "final",
                                      fit_fast$logLik))
    results <- rbind(results, add_row(ds, "fastcmprsk_loglik", "null",
                                      fit_fast$logLik.null))
    cat(sprintf("  fastCrr loglik: null=%12.6f final=%12.6f\n",
                fit_fast$logLik.null, fit_fast$logLik))

    # Baseline cumulative hazard at last event time
    # breslowJump is a data.frame with columns: time, jump
    if (!is.null(fit_fast$breslowJump)) {
        cum_bh_fast <- cumsum(fit_fast$breslowJump$jump)
        results <- rbind(results, add_row(ds, "fastcmprsk_cumbasehaz",
                                          "tmax", tail(cum_bh_fast, 1)))
        cat(sprintf("  fastCrr cumbasehaz(tmax) = %12.8f\n",
                    tail(cum_bh_fast, 1)))
    }

    # CIF at reference pattern (z=0)
    pred_fast <- predict(fit_fast, newdata = z_ref)
    # pred_fast has $CIF (vector) and $ftime (vector)
    for (tt in eval_times) {
        idx_f <- which(pred_fast$ftime <= tt)
        if (length(idx_f) > 0) {
            cif_val_f <- pred_fast$CIF[max(idx_f)]
        } else {
            cif_val_f <- 0
        }
        results <- rbind(results, add_row(ds, "fastcmprsk_cif_ref",
                                          paste0("t", tt), cif_val_f))
        cat(sprintf("  fastCrr CIF(t=%d, z=0) = %12.8f\n", tt, cif_val_f))
    }
}

if (any(!is.finite(results$value))) {
    stop("reference output contains nonfinite values")
}
if (anyDuplicated(results[c("dataset", "quantity", "variable")])) {
    stop("reference output contains duplicate dataset/quantity/variable keys")
}
write.csv(results, output_file, row.names = FALSE)
fg_oracle_cache_end(.fgc)
cat(sprintf("\ncrossval_finegray_r.R: wrote %d rows to %s\n",
            nrow(results), output_file))
