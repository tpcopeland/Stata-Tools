#!/usr/bin/env Rscript
# crossval_finegray_dta_r.R - cmprsk oracle for the .dta fixture.
# Usage: Rscript crossval_finegray_dta_r.R input.dta output.dta

suppressPackageStartupMessages({
    library(haven)
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
                "crossval_finegray_dta_r.R", as.character(getRversion()), R.version$platform))
    for (p in pkgs) {
        v <- tryCatch(as.character(utils::packageVersion(p)),
                      error = function(e) "NOT-INSTALLED")
        cat(sprintf("R_ENV: package %s = %s\n", p, v))
    }
}
.fg_banner(c("haven", "cmprsk"))

args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 2L) {
    stop("Usage: crossval_finegray_dta_r.R input.dta output.dta")
}

d <- read_dta(args[1])
needed <- c("time", "status", "z")
if (!identical(sort(names(d)), sort(needed)) || any(!is.finite(as.matrix(d)))) {
    stop("fixture must contain finite time, status, and z columns only")
}
if (any(!d$status %in% c(0, 1, 2)) || any(d$time <= 0)) {
    stop("fixture status/time contract failed")
}

fit <- crr(d$time, d$status, cov1 = as.matrix(d["z"]), failcode = 1,
           cencode = 0, variance = TRUE)
if (!isTRUE(fit$converged) || any(!is.finite(fit$coef)) ||
    any(!is.finite(fit$var))) {
    stop("cmprsk::crr did not return a finite converged fit")
}

out <- data.frame(
    beta = as.numeric(fit$coef[1]),
    se = sqrt(as.numeric(fit$var[1, 1])),
    n = nrow(d),
    n_tied_cause1 = max(table(d$time[d$status == 1]))
)
if (any(!is.finite(as.matrix(out)))) stop("oracle output is nonfinite")
write_dta(out, args[2], version = 14)
