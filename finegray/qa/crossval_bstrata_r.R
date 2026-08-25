#!/usr/bin/env Rscript
#
# crossval_bstrata_r.R
# R-side cross-validation for finegray's bstrata() against crrSC::crrs, the
# reference implementation of Zhou, Latouche, Rocha & Fine (2011), "Competing
# risks regression for stratified data", Biometrics 67(2):661-670.
#
# Usage (called from crossval_bstrata.do via Stata's shell):
#   Rscript crossval_bstrata_r.R <input_csv> <output_csv>
#
# input_csv:  stacked CSV with columns id, time, status, strata, dataset, x1, x2
# output_csv: long CSV with columns dataset, ctype, quantity, variable, value
#
# THE ctype MAPPING.  crrs's `ctype' argument decides how the censoring
# distribution G is estimated, and that is a DIFFERENT axis from the baseline
# stratification (which crrs always applies to `strata'):
#
#   ctype = 1  G estimated WITHIN strata  -> finegray, bstrata(v) strata(v)
#   ctype = 2  G pooled over strata       -> finegray, bstrata(v)
#
# Verified against the crrSC 1.1.2 source: the ctype == 1 branch loops over
# strata calling survfit(Surv(ftime, cenind) ~ 1) inside each; the else branch
# calls it once on the whole sample.  Both evaluate G at ftime*(1 - eps), i.e.
# the LEFT limit G(t-), which is the convention finegray uses too.
#
# VARIANCE.  ctype is also an asymptotic-regime declaration in the paper --
# ctype = 2 carries the highly-stratified (many small strata) variance, which
# finegray does not implement and does not claim to.  So only the ctype = 1
# standard errors are comparable, and the Stata side compares only those.
#
# Requires: crrSC (>= 1.1)

suppressPackageStartupMessages({
    library(crrSC)
})

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 2) {
    stop("Usage: Rscript crossval_bstrata_r.R <input_csv> <output_csv>")
}
input_file  <- args[1]
output_file <- args[2]

df <- read.csv(input_file, stringsAsFactors = FALSE)
covs <- setdiff(names(df), c("id", "time", "status", "strata", "dataset"))
if (length(covs) == 0) stop("no covariate columns found in input CSV")

results <- list()
add <- function(ds, ct, qty, var, val) {
    results[[length(results) + 1L]] <<- data.frame(
        dataset = ds, ctype = ct, quantity = qty, variable = var,
        value = val, stringsAsFactors = FALSE)
}

for (ds in unique(df$dataset)) {
    d <- df[df$dataset == ds, , drop = FALSE]
    Z <- as.matrix(d[, covs, drop = FALSE])
    for (ct in c(1L, 2L)) {
        fit <- try(crrs(ftime = d$time, fstatus = d$status, cov1 = Z,
                        strata = d$strata, failcode = 1, cencode = 0,
                        ctype = ct), silent = TRUE)
        if (inherits(fit, "try-error")) {
            cat(sprintf("NOTE: crrs failed for %s ctype=%d\n", ds, ct))
            next
        }
        add(ds, ct, "converged", "_all", as.numeric(isTRUE(fit$converged)))
        se <- sqrt(diag(fit$var))
        for (j in seq_along(covs)) {
            add(ds, ct, "coef", covs[j], unname(fit$coef[j]))
            add(ds, ct, "se",   covs[j], unname(se[j]))
        }
    }
}

out <- do.call(rbind, results)
write.csv(out, file = output_file, row.names = FALSE)
cat(sprintf("wrote %d rows to %s\n", nrow(out), output_file))
