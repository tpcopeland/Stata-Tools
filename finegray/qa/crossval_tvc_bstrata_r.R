#!/usr/bin/env Rscript
#
# crossval_tvc_bstrata_r.R
# R-side external VCE oracle for finegray's tvc() x bstrata() composition, and
# for tvc() x bstrata() x cluster(), built on Terry Therneau's survival package.
# (tvc() x strata() x cluster() has NO oracle here; see NOT USED HERE below.)
#
# Usage (called from crossval_tvc_bstrata.do via Stata's shell):
#   Rscript crossval_tvc_bstrata_r.R <input_csv> <output_csv>
#
# input_csv:  stacked CSV with columns id, time, status, dataset, ncut, cut1,
#             cut2, x1, x2, bs, g, clid
# output_csv: long CSV with columns dataset, quantity, variable, value
#
# WHY NOT cmprsk::crr.  crr has cengroup= (finegray's strata() axis: the
# censoring KM estimated within group) but no baseline stratification at all --
# it fits ONE baseline subdistribution hazard.  crrSC::crrs stratifies the
# baseline, but its ctype=1 estimates G WITHIN stratum and its ctype=2 is the
# highly-stratified variance of Zhou et al. (2011) sec. 4.2, a different
# derivation; neither is `bstrata(v)' WITHOUT `strata(v)', which is a stratified
# baseline over a POOLED G.  That cell had no external implementation, which is
# why finegray_methods.sthlp calls it "this package's own composition of Zhou's
# additivity over strata with Fine and Gray's eq. (8) ... validated by
# simulation rather than against an external implementation".  This file is that
# external implementation.
#
# THE CONSTRUCTION.  survival::finegray() materialises the Fine-Gray risk set as
# a weighted (start, stop] dataset -- competing-event subjects are extended to
# the right with a decreasing case weight fgwt -- so any weighted Cox routine
# fits the model over it.  That makes the three axes separable and each one
# expressible with a standard survival idiom:
#
#   POOLED G                finegray(Surv(time, ev) ~ .)  with NO strata() term
#                           in the finegray formula.  The censoring survivor is
#                           one marginal Kaplan-Meier.  This is finegray's
#                           default weight, i.e. `bstrata()' without `strata()'.
#   CLUSTERED SANDWICH      cluster = clid in the coxph() call: the dfbeta score
#                           residuals are summed within cluster before being
#                           squared, which is Zhou, Fine, Latouche and Labopin
#                           (2012) p.376 restricted to the fixed-weight eta half.
#
# NOT USED HERE: survival::finegray's own strata() term.  Its documentation says
# a strata() term makes the censoring distribution be estimated separately per
# stratum, which reads like finegray's strata() axis and like crr's cengroup=.
# MEASURED 2026-09-04, it is neither.  On n = 1500 with censoring INDEPENDENT of
# the group -- where a per-group and a pooled G differ only by sampling noise --
#   crr(cengroup = g)                                 x1 = 0.5799008
#   finegray(~ . + strata(g)) + coxph(weight = fgwt)  x1 = 0.5914494   (2.0e-02)
# and the expanded data carries 24,236 rows summing to 17,962.65 of weight
# against 46,580 rows summing to 34,921.13 for the pooled expansion: the
# stratified branch confines the artificial extension of competing-event
# subjects as well as the weight, which is a different estimator, not a
# different arithmetic path to the same one.  finegray's strata() axis IS
# cross-validated against crr's cengroup= (crossval_tvc.do part C, measured
# 5.3e-09 on coefficients and 1.9e-10 on nuisance SEs); what has no external
# oracle is strata() COMPOSED with cluster(), and this file does not claim one.
#   STRATIFIED BASELINE     strata(bs) in the coxph() formula.  One unconstrained
#                           baseline per level, one shared coefficient vector --
#                           Zhou, Latouche, Rocha and Fine (2011) sec. 2, which
#                           is exactly what finegray's bstrata() fits.
#   PIECEWISE beta(t)       survSplit() the EXPANDED data at the tvc cut points
#                           and give each interval its own copy of the covariate.
#                           survSplit uses (start, stop], so a record ending on a
#                           cut stays in the earlier interval -- finegray's own
#                           convention, matched by construction rather than by
#                           luck.
#
# WHICH VARIANCE.  coxph(weight = fgwt, cluster = id, robust = TRUE) is the
# Lin-Wei sandwich over subject-summed score residuals with the weights treated
# as KNOWN.  That is finegray's `fixed_weight' meat -- the default, i.e. the
# eq. (7) eta term without eq. (8)'s psi -- so the Stata side compares a plain
# (no `nuisance') fit, and adds `noadjust' to drop StataCorp's N/(N-1) factor,
# which coxph does not apply.  Both sides then compute the same estimator and
# the gate is an agreement tolerance rather than a proximity one.
#
# ties = "breslow" is required: Fine & Gray (1999) eq. (8)'s baseline is the
# modified Breslow estimator, and coxph defaults to Efron.
#
# Requires: survival (>= 3.8)

suppressPackageStartupMessages({
    library(survival)
})

.fg_banner <- function(pkgs) {
    cat(sprintf("R_ENV: script=%s R=%s platform=%s\n",
                "crossval_tvc_bstrata_r.R", as.character(getRversion()),
                R.version$platform))
    for (p in pkgs) {
        v <- tryCatch(as.character(utils::packageVersion(p)),
                      error = function(e) "NOT-INSTALLED")
        cat(sprintf("R_ENV: package %s = %s\n", p, v))
    }
}
.fg_banner(c("survival", "cmprsk", "crrSC"))

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 2) {
    stop("Usage: Rscript crossval_tvc_bstrata_r.R <input_csv> <output_csv>")
}
input_csv <- args[1]
output_csv <- args[2]

# Oracle cache: this script is a pure function of its inputs.  See
# _fg_oracle_cache.R for the key and the fail-closed rules.
source(file.path(dirname(sub("^--file=", "", grep("^--file=",
       commandArgs(FALSE), value = TRUE)[1])), "_fg_oracle_cache.R"))
.fgc <- fg_oracle_cache_begin('tvc_bstrata', outputs = output_csv,
                              key_files = input_csv,
                              packages = c("survival", "cmprsk", "crrSC"))
if (identical(.fgc$state, "hit")) quit(save = "no", status = 0)

dat <- read.csv(input_csv, stringsAsFactors = FALSE)
required <- c("id", "time", "status", "dataset", "ncut", "cut1", "x1", "x2",
              "bs", "g", "clid")
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

# Emit a fit's coefficients and the upper triangle of its covariance.
#
# ORDER.  finegray's e(b) stripe is main:x2 first, then tvc1:x1 ... tvcJ:x1, so
# the coxph formula below is written in that order and this function REFUSES a
# fit whose coefficient names came back in any other one.  The Stata side then
# rebuilds the symmetric matrix positionally; if the two orders ever parted, the
# per-coefficient SE comparison (which is name-addressed on the Stata side)
# would stop matching sqrt of the assembled diagonal, and the suite asserts that
# correspondence explicitly rather than assuming it.
emit_fit <- function(ds, tag, fit, nint) {
    cf <- coef(fit)
    V  <- vcov(fit)
    nm <- names(cf)
    want <- c("x2", paste0("x1_", seq_len(nint)))
    if (!identical(nm, want)) {
        stop(sprintf("%s/%s: unexpected coefficient order [%s]", ds, tag,
                     paste(nm, collapse = ", ")))
    }
    add_row(ds, paste0("coef", tag), "x2", unname(cf[1]))
    for (j in seq_len(nint)) {
        add_row(ds, paste0("coef", tag), paste0("tvc", j), unname(cf[1 + j]))
    }
    p <- length(cf)
    for (ri in seq_len(p)) {
        for (ci in ri:p) {
            add_row(ds, paste0("vcov", tag), sprintf("v%d_%d", ri, ci),
                    V[ri, ci])
        }
    }
    add_row(ds, paste0("nobs", tag), "nevent", unname(fit$nevent))
}

for (ds in unique(dat$dataset)) {
    d <- dat[dat$dataset == ds, , drop = FALSE]
    ncut <- d$ncut[1]
    cuts <- as.numeric(d$cut1[1])
    if (ncut >= 2) cuts <- c(cuts, as.numeric(d$cut2[1]))
    nint <- length(cuts) + 1L

    d$ev <- factor(d$status, levels = c(0, 1, 2),
                   labels = c("censor", "cause1", "cause2"))
    d$bs <- factor(d$bs)
    d$g  <- factor(d$g)

    # ---- Arm 1: pooled G, stratified baseline, piecewise beta(t) -----------
    # `id' has to ride along on the RHS: finegray()'s id= argument governs the
    # expansion but does NOT emit an identifier column, and coxph needs one to
    # cluster on.
    pd <- finegray(Surv(time, ev) ~ x1 + x2 + bs + g + clid + id, data = d,
                   etype = "cause1")
    ps <- survSplit(Surv(fgstart, fgstop, fgstatus) ~ ., data = pd,
                    cut = cuts, episode = "ivl")
    for (j in seq_len(nint)) ps[[paste0("x1_", j)]] <- ps$x1 * (ps$ivl == j)
    # coxph resolves `cluster' and `weights' inside data= by non-standard
    # evaluation, so the grouping is put in a fixed column name rather than
    # passed as a pre-evaluated vector (which errors "one of cluster or id is
    # needed").
    ps$fgcluster <- ps$id
    ps$fgclid <- ps$clid
    rhs <- paste(c("x2", paste0("x1_", seq_len(nint)), "strata(bs)"),
                 collapse = " + ")
    f1 <- coxph(as.formula(paste("Surv(fgstart, fgstop, fgstatus) ~", rhs)),
                weights = fgwt, data = ps, cluster = fgcluster, robust = TRUE,
                ties = "breslow")
    emit_fit(ds, "", f1, nint)

    # ---- Arm 2: same weights and baseline strata, CLUSTER-summed sandwich --
    # Only the score-residual grouping changes: coxph sums the dfbeta residuals
    # within clid instead of within subject, which is Zhou, Fine, Latouche and
    # Labopin (2012) p.376's Sigma-hat = n^-1 sum_i (eta_i. + psi_i.)^(x)2 with
    # the influence functions summed WITHIN cluster before squaring, restricted
    # to the fixed-weight eta half.  Fitting it over the SAME expanded data as
    # arm 1 makes this a test of the aggregation alone.
    f2 <- coxph(as.formula(paste("Surv(fgstart, fgstop, fgstatus) ~", rhs)),
                weights = fgwt, data = ps, cluster = fgclid, robust = TRUE,
                ties = "breslow")
    emit_fit(ds, "_cl", f2, nint)

    add_row(ds, "nint", "nint", nint)
}

if (length(rows) == 0) stop("no coxph fit succeeded; nothing to write")
out <- do.call(rbind, rows)
write.csv(out, output_csv, row.names = FALSE)
fg_oracle_cache_end(.fgc)
