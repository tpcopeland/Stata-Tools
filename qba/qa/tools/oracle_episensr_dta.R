#!/usr/bin/env Rscript
# Same-run .dta oracle for qba fixed-parameter bias corrections.

args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 2L) stop("usage: oracle_episensr_dta.R INPUT.dta OUTPUT.dta")
for (pkg in c("haven", "episensr")) {
    if (!requireNamespace(pkg, quietly = TRUE)) stop(paste("missing R package:", pkg))
}

d <- haven::read_dta(args[[1L]])
if (nrow(d) != 1L || anyNA(d)) stop("input must be one complete scenario row")
tab <- matrix(c(d$a, d$b, d$c, d$d), nrow = 2L, byrow = TRUE)
fit <- episensr::misclass(
    tab,
    type = "exposure",
    bias_parms = c(d$seca, d$secb, d$spca, d$spcb)
)
out <- data.frame(
    name = c("a", "b", "c", "d", "rr", "or"),
    value = c(fit$corr_data[1, 1], fit$corr_data[1, 2],
              fit$corr_data[2, 1], fit$corr_data[2, 2],
              fit$adj_measures[1, 1], fit$adj_measures[2, 1])
)
if (any(!is.finite(out$value))) stop("episensr returned a non-finite value")
haven::write_dta(out, args[[2L]])
