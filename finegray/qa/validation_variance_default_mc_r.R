# validation_variance_default_mc_r.R
# R reference fits for validation_variance_default_mc.do.
#
# Usage (called by the .do file; not a lane member on its own):
#   Rscript validation_variance_default_mc_r.R <A_in.csv> <A_out.csv> <B_in.csv> <B_out.csv>
#
# Scenario A (right censoring, strata(grp) censoring groups):
#   cmprsk::crr(cengroup = grp).  Its censoring survivor per group is set to 0
#   beyond that group's last observed time (the approx() call inside crr), so it
#   is a reference for finegray, strata() only on replications where every
#   censoring group's last observation is a censoring.  The .do file splits the
#   comparison on exactly that property.
# Scenario B (delayed entry, integer-month ties, pooled G):
#   survival::finegray(Surv(L, t, cause)) + coxph(weights = fgwt, ties =
#   "breslow").  cmprsk::crr has no entry argument, so this is the installed R
#   implementation of left-truncated Fine-Gray.

suppressMessages({
    library(cmprsk)
    library(survival)
})
cat("R_ENV: R", as.character(getRversion()),
    "cmprsk", as.character(packageVersion("cmprsk")),
    "survival", as.character(packageVersion("survival")), "\n")

args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 4) stop("expected 4 arguments: A_in A_out B_in B_out")

# ---- scenario A: cmprsk::crr with cengroup ---------------------------------
d <- read.csv(args[1])
res <- list()
for (r in sort(unique(d$rep))) {
    x <- d[d$rep == r, ]
    cov <- as.matrix(x[, c("grp", "z2")])
    fit <- try(crr(ftime = x$t, fstatus = x$status, cov1 = cov, failcode = 1,
                   cencode = 0, cengroup = x$grp), silent = TRUE)
    if (inherits(fit, "try-error") || !isTRUE(fit$converged)) {
        res[[length(res) + 1]] <- data.frame(rep = r, b1 = NA, b2 = NA)
    } else {
        res[[length(res) + 1]] <- data.frame(rep = r, b1 = unname(fit$coef[1]),
                                             b2 = unname(fit$coef[2]))
    }
}
write.csv(do.call(rbind, res), args[2], row.names = FALSE)

# ---- scenario B: survival::finegray with delayed entry ---------------------
d <- read.csv(args[3])
res <- list()
for (r in sort(unique(d$rep))) {
    x <- d[d$rep == r, ]
    x$ev <- factor(x$status, levels = c(0, 1, 2), labels = c("cens", "c1", "c2"))
    row <- data.frame(rep = r, b1 = NA, b2 = NA, nbadwt = NA)
    fg <- try(finegray(Surv(L, t, ev) ~ grp + z2 + id, data = x, etype = "c1",
                       id = id), silent = TRUE)
    if (!inherits(fg, "try-error")) {
        f2 <- try(coxph(Surv(fgstart, fgstop, fgstatus) ~ grp + z2, data = fg,
                        weights = fgwt, ties = "breslow", robust = TRUE,
                        cluster = id), silent = TRUE)
        if (!inherits(f2, "try-error")) {
            row <- data.frame(rep = r, b1 = unname(coef(f2)[1]),
                              b2 = unname(coef(f2)[2]),
                              nbadwt = sum(!is.finite(fg$fgwt)))
        }
    }
    res[[length(res) + 1]] <- row
}
write.csv(do.call(rbind, res), args[4], row.names = FALSE)
cat("R oracles written\n")
