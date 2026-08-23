#!/usr/bin/env Rscript
# Independent .dta oracle for crossval_iivw_dta.do.
#
# This is not a Mendelian-randomization calculation.  iivw is an
# inverse-intensity-of-visit-weighting package; the external implementation
# matched here is survival::coxph plus geepack::geeglm on the same panel.

args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 2L) {
    stop("usage: crossval_iivw_dta.R INPUT.dta OUTPUT.dta")
}

infile <- args[[1L]]
outfile <- args[[2L]]

for (pkg in c("haven", "survival", "geepack")) {
    if (!requireNamespace(pkg, quietly = TRUE)) {
        stop(sprintf("required R package is unavailable: %s", pkg))
    }
}

d <- haven::read_dta(infile)
d <- d[order(d$id, d$time), ]
if (anyDuplicated(d[c("id", "time")])) stop("id-time keys must be unique")
if (anyNA(d[c("id", "time", "x", "y")])) stop("fixture has missing inputs")

# The Stata arm uses baseline(event) and endatlastvisit: every observed row is
# an Andersen-Gill event, with no terminal censoring row.  The first interval
# starts at zero and subsequent intervals start at the prior observed time.
d$start <- ave(d$time, d$id, FUN = function(z) c(0, z[-length(z)]))
d$event <- 1L
visit_fit <- survival::coxph(
    survival::Surv(start, time, event) ~ x,
    data = d,
    ties = "efron"
)
d$iiw_raw <- exp(-as.numeric(predict(visit_fit, type = "lp", reference = "zero")))
d$iiw <- d$iiw_raw / mean(d$iiw_raw)

outcome_fit <- geepack::geeglm(
    y ~ x + time,
    id = id,
    data = d,
    weights = iiw,
    family = gaussian(),
    corstr = "independence",
    std.err = "san.se"
)
outcome_summary <- coef(summary(outcome_fit))
out <- data.frame(
    term = c("x", "time"),
    estimate = c(unname(outcome_summary["x", "Estimate"]),
                 unname(outcome_summary["time", "Estimate"])),
    se = c(unname(outcome_summary["x", "Std.err"]),
           unname(outcome_summary["time", "Std.err"]))
)
if (any(!is.finite(as.matrix(out[c("estimate", "se")]))) || nrow(out) != 2L) {
    stop("R oracle produced non-finite output")
}
haven::write_dta(out, outfile)
