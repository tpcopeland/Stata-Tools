#!/usr/bin/env Rscript
#
# crossval_pweight_r.R
# R-side cross-validation for finegray's [pweight=] against
# survival::finegray(weights=) + coxph(weights=, robust=TRUE), the product
# construction Therneau's survival package documents for a weighted Fine-Gray
# fit.
#
# Usage (called from crossval_pweight.do via Stata's shell):
#   Rscript crossval_pweight_r.R <input_csv> <output_csv>
#
# input_csv:  stacked CSV with columns id, time, status, dataset, pw, cl,
#             x1, x2 (and g2, g3 for the factor dataset; absent columns are
#             all-NA after stacking and are dropped)
# output_csv: long CSV with columns dataset, quantity, variable, value
#
# WHAT IS COMPARED, AND WHY IT IS THE RIGHT ORACLE.
#
#   survival::finegray() builds the Fine-Gray expansion: every subject with a
#   competing event is carried forward past its own exit with the IPCW
#   weight G(t)/G(T_i), and the user's `weights' MULTIPLY that fgwt
#   (finegray.R: tdata$fgwt <- split$wt * user.weights[split$row]).  The
#   censoring survivor Gsurv is fitted WITHOUT the user weights -- read in
#   session 2026-08-28, survival 3.8-6 -- which is the convention finegray
#   adopts for pweights (Wogu et al. 2021, sec. 3 p.167, likewise estimate G
#   from the full cohort unweighted).  A weighted coxph on the expansion with
#   ties = "breslow" then solves exactly the estimating equation finegray's
#   scan solves, and robust = TRUE with cluster = id forms the sandwich meat
#   from the per-subject sums of w_i s_i -- sum_i (w_i s_i)^2, the pweight
#   convention.  coxph applies no finite-sample factor, so the Stata side
#   fits with noadjust.
#
#   survfit(fit, newdata = 0) gives the weighted Breslow cumulative
#   subhazard at the reference profile; 1 - exp(-H) is the CIF finegray_cif
#   reports.
#
# THE TIE CONVENTION.  The fixtures use continuous times, so no censoring
# time coincides with an event time and G(t) versus G(t-) cannot differ.
# The pweight feature adds no tie handling of its own; the package's tie
# convention is pinned elsewhere (test_finegray_ties.do, crossval_cif.do).
#
# Requires: survival (>= 3.0)

suppressPackageStartupMessages({
    library(survival)
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
                "crossval_pweight_r.R", as.character(getRversion()), R.version$platform))
    for (p in pkgs) {
        v <- tryCatch(as.character(utils::packageVersion(p)),
                      error = function(e) "NOT-INSTALLED")
        cat(sprintf("R_ENV: package %s = %s\n", p, v))
    }
}
.fg_banner(c("survival"))

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 2) {
    stop("Usage: Rscript crossval_pweight_r.R <input_csv> <output_csv>")
}
input_csv <- args[1]
output_csv <- args[2]

dat <- read.csv(input_csv, stringsAsFactors = FALSE)
required <- c("id", "time", "status", "dataset", "pw", "cl", "x1")
missing_cols <- setdiff(required, names(dat))
if (length(missing_cols) > 0) {
    stop(sprintf("input is missing column(s): %s",
                 paste(missing_cols, collapse = ", ")))
}

rows <- list()
add_row <- function(dataset, quantity, variable, value) {
    rows[[length(rows) + 1L]] <<- data.frame(
        dataset = dataset, quantity = quantity, variable = variable,
        value = value, stringsAsFactors = FALSE)
}

eval_times <- c(0.5, 1, 2)

for (ds in unique(dat$dataset)) {
    d <- dat[dat$dataset == ds, , drop = FALSE]
    # covariate columns: everything that is not bookkeeping and not all-NA
    cov_cols <- setdiff(names(d), c("id", "time", "status", "dataset", "pw", "cl"))
    cov_cols <- cov_cols[sapply(cov_cols, function(v) !all(is.na(d[[v]])))]
    d <- d[, c("id", "time", "status", "pw", "cl", cov_cols)]
    if (anyDuplicated(d$id) > 0) stop("one record per subject is required")

    d$ev <- factor(d$status, levels = c(0, 1, 2), labels = c("cens", "c1", "c2"))

    cat(sprintf("\n=== Dataset: %s (n=%d, p=%d) ===\n", ds, nrow(d), length(cov_cols)))

    # The Fine-Gray expansion for cause c1, user weights multiplying fgwt.
    fml <- as.formula(paste("Surv(time, ev) ~", paste(c(cov_cols, "cl", "id"),
                                                       collapse = " + ")))
    fg <- finegray(fml, data = d, etype = "c1", weights = pw)

    # Weighted Breslow Cox fit on the expansion; sandwich from per-subject sums.
    cfml <- as.formula(paste("Surv(fgstart, fgstop, fgstatus) ~",
                             paste(cov_cols, collapse = " + ")))
    fit <- coxph(cfml, data = fg, weights = fgwt, ties = "breslow",
                 robust = TRUE, cluster = id)
    if (any(!is.finite(coef(fit)))) stop(sprintf("coxph failed on %s", ds))

    for (v in cov_cols) {
        add_row(ds, "coef", v, unname(coef(fit)[v]))
        add_row(ds, "se_robust", v, unname(sqrt(diag(fit$var))[which(cov_cols == v)]))
        cat(sprintf("  coef[%s] = %12.8f   se_robust = %12.8f\n", v,
                    coef(fit)[v], sqrt(diag(fit$var))[which(cov_cols == v)]))
    }
    add_row(ds, "loglik", "final", fit$loglik[2])
    add_row(ds, "loglik", "null", fit$loglik[1])
    cat(sprintf("  loglik: null=%12.6f final=%12.6f\n", fit$loglik[1], fit$loglik[2]))

    # Cluster-robust arm: the same fit, sandwich summed within cl.
    fit_cl <- coxph(cfml, data = fg, weights = fgwt, ties = "breslow",
                    robust = TRUE, cluster = cl)
    for (v in cov_cols) {
        add_row(ds, "se_cluster", v,
                unname(sqrt(diag(fit_cl$var))[which(cov_cols == v)]))
        cat(sprintf("  se_cluster[%s] = %12.8f\n", v,
                    sqrt(diag(fit_cl$var))[which(cov_cols == v)]))
    }

    # Weighted Breslow baseline and CIF at the reference profile z = 0.
    nd <- as.data.frame(as.list(setNames(rep(0, length(cov_cols)), cov_cols)))
    sf <- survfit(fit, newdata = nd)
    ss <- summary(sf, times = eval_times, extend = TRUE)
    H <- -log(ss$surv)
    for (k in seq_along(eval_times)) {
        add_row(ds, "cif_ref", paste0("t", gsub("\\.", "", as.character(eval_times[k]))), 1 - exp(-H[k]))
        cat(sprintf("  CIF(t=%g, z=0) = %12.8f\n", eval_times[k], 1 - exp(-H[k])))
    }
}

results <- do.call(rbind, rows)
if (any(!is.finite(results$value))) {
    stop("reference output contains nonfinite values")
}
if (anyDuplicated(results[c("dataset", "quantity", "variable")])) {
    stop("reference output contains duplicate dataset/quantity/variable keys")
}
write.csv(results, output_csv, row.names = FALSE)
cat(sprintf("\ncrossval_pweight_r.R: wrote %d rows to %s\n", nrow(results), output_csv))
