#!/usr/bin/env Rscript
#
# crossval_tvc_r.R
# R-side cross-validation for finegray's tvc()/tsplit() against cmprsk::crr,
# written by R. J. Gray -- the second author of Fine & Gray (1999) -- and the
# reference implementation of that paper.
#
# Usage (called from crossval_tvc.do via Stata's shell):
#   Rscript crossval_tvc_r.R <input_csv> <output_csv>
#
# input_csv:  stacked CSV with columns id, time, status, dataset, ncut, cut1,
#             cut2, x1, x2, and optionally g (a censoring-KM group; when a
#             dataset carries it, a second fit with cengroup = g is emitted
#             under quantity "coef_cg" -- finegray's tvc() + strata() mapping)
# output_csv: long CSV with columns dataset, quantity, variable, value
#
# THE PARAMETERISATION.  crr's linear predictor is
#
#     cov1 %*% beta1  +  sum_j cov2[, j] * tf(t)[, j] * beta2[j]
#
# so a piecewise-constant effect on x1 with J intervals is cov2 = J copies of
# x1 and tf(t) = the J interval indicators.  Each beta2[j] is then that
# interval's own coefficient -- separate coefficients per interval, which is
# exactly what finegray's tvc1 ... tvcJ equations hold -- rather than a main
# effect plus offsets.  x2 stays in cov1 with a single coefficient.
#
# THE TIE CONVENTION.  finegray's interval j is (cut_{j-1}, cut_j], so an event
# exactly on a boundary belongs to the EARLIER interval.  The indicators below
# are built with the same closure (t <= cut, t > cut), so the two agree by
# construction rather than by luck; a fixture with events on the boundary is
# what would expose a mismatch, and the tie fixture rounds times onto a coarse
# grid that includes the cuts for that reason.
#
# Requires: cmprsk (>= 2.2)

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
                "crossval_tvc_r.R", as.character(getRversion()), R.version$platform))
    for (p in pkgs) {
        v <- tryCatch(as.character(utils::packageVersion(p)),
                      error = function(e) "NOT-INSTALLED")
        cat(sprintf("R_ENV: package %s = %s\n", p, v))
    }
}
.fg_banner(c("cmprsk", "survival"))

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 2) {
    stop("Usage: Rscript crossval_tvc_r.R <input_csv> <output_csv>")
}
input_csv <- args[1]
output_csv <- args[2]

dat <- read.csv(input_csv, stringsAsFactors = FALSE)
required <- c("id", "time", "status", "dataset", "ncut", "cut1", "x1", "x2")
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

for (ds in unique(dat$dataset)) {
    d <- dat[dat$dataset == ds, , drop = FALSE]
    ncut <- d$ncut[1]
    cuts <- as.numeric(d$cut1[1])
    if (ncut >= 2) cuts <- c(cuts, as.numeric(d$cut2[1]))
    nint <- length(cuts) + 1L

    cov1 <- as.matrix(d[, "x2", drop = FALSE])
    colnames(cov1) <- "x2"
    cov2 <- matrix(rep(d$x1, nint), ncol = nint)
    colnames(cov2) <- paste0("x1_tvc", seq_len(nint))

    # tf() must return one column per column of cov2, evaluated at the vector of
    # failure times crr hands it.  (cut_{j-1}, cut_j]: strictly greater than the
    # lower bound, less than or equal to the upper.
    tf <- function(uft) {
        out <- matrix(0, nrow = length(uft), ncol = nint)
        lo <- -Inf
        for (j in seq_len(nint)) {
            hi <- if (j == nint) Inf else cuts[j]
            out[, j] <- as.numeric(uft > lo & uft <= hi)
            lo <- hi
        }
        out
    }

    fit <- tryCatch(
        crr(ftime = d$time, fstatus = d$status, cov1 = cov1, cov2 = cov2,
            tf = tf, failcode = 1, cencode = 0),
        error = function(e) {
            message(sprintf("crr failed on %s: %s", ds, conditionMessage(e)))
            NULL
        })
    if (is.null(fit)) next

    cf <- fit$coef
    # crr orders the coefficients cov1 first, then cov2 x tf.
    add_row(ds, "coef", "x2", unname(cf[1]))
    for (j in seq_len(nint)) {
        add_row(ds, "coef", paste0("tvc", j), unname(cf[1 + j]))
    }
    # STANDARD ERRORS (added 2026-08-26 with the variance unification).
    # crr$var is the FULL Fine & Gray (1999) sandwich: cmprsk assembles it in
    # the Fortran routine crrvv, whose eta block is eq. (7) and whose q/pi block
    # is eq. (8) -- the psi term for having ESTIMATED G.  (The same routine is
    # vendored by crrSC and is what crrs's ctype=1 sums over strata.)  Until
    # the unification finegray refused `nuisance' with tvc(), so there was no finegray
    # quantity to compare these against and the Stata side deliberately did not
    # compare SEs at all.  There is now: `tvc() nuisance noadjust' computes the
    # same object, so these rows make the piecewise psi term externally checked
    # rather than internally argued.
    se <- sqrt(diag(fit$var))
    add_row(ds, "se", "x2", unname(se[1]))
    for (j in seq_len(nint)) {
        add_row(ds, "se", paste0("tvc", j), unname(se[1 + j]))
    }
    add_row(ds, "loglik", "loglik", unname(fit$loglik))
    add_row(ds, "nint", "nint", nint)

    # Censoring-KM groups: crr's cengroup estimates G within each level of g,
    # which is finegray's strata() axis.  Fitted only when the dataset carries
    # a g column, so the original fixtures are untouched byte for byte.
    if ("g" %in% names(d) && !all(is.na(d$g))) {
        fit_cg <- tryCatch(
            crr(ftime = d$time, fstatus = d$status, cov1 = cov1, cov2 = cov2,
                tf = tf, cengroup = d$g, failcode = 1, cencode = 0),
            error = function(e) {
                message(sprintf("crr cengroup failed on %s: %s",
                                ds, conditionMessage(e)))
                NULL
            })
        if (!is.null(fit_cg)) {
            cfg <- fit_cg$coef
            add_row(ds, "coef_cg", "x2", unname(cfg[1]))
            for (j in seq_len(nint)) {
                add_row(ds, "coef_cg", paste0("tvc", j), unname(cfg[1 + j]))
            }
            seg <- sqrt(diag(fit_cg$var))
            add_row(ds, "se_cg", "x2", unname(seg[1]))
            for (j in seq_len(nint)) {
                add_row(ds, "se_cg", paste0("tvc", j), unname(seg[1 + j]))
            }
        }
    }
}

if (length(rows) == 0) stop("no crr fit succeeded; nothing to write")
out <- do.call(rbind, rows)
write.csv(out, output_csv, row.names = FALSE)
