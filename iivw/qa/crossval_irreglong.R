#!/usr/bin/env Rscript
# crossval_irreglong.R - Generate IrregLong reference weights for cross-validation
#
# Replicates the IrregLong Phenobarb vignette and exports exactly these files
# (this list is the contract; crossval_iivw.do reads them):
#   1. Prepared dataset                      (phenobarb_prepared.csv)
#   2. Parity Cox coefficients               (phenobarb_parity_coefs.csv)
#   3. Parity Cox coefficients, with entry   (phenobarb_parity_entry_coefs.csv)
#   4. Parity WEIGHTS, with entry            (phenobarb_parity_entry_weights.csv)
#   5. Cox model coefficients                (phenobarb_cox_coefs.csv)
#   6. Cox counting-process data             (phenobarb_cox_data.csv)
#   7. Package-version manifest              (crossval_irreglong_versions.csv)
#   8. Completion sentinel                   (crossval_irreglong.ok, gitignored)
#
# It does NOT write phenobarb_weights.csv, whatever earlier versions of this
# header claimed.
#
# (4) is the oracle for XV4c. (3) proves iivw and IrregLong fit the same Cox
# model; only (4) proves they turn it into the same weight, which is a separate
# claim -- the exponent sign, the centering convention and the first-visit rule
# all sit downstream of the coefficient.
#
# Usage: Rscript iivw/qa/crossval_irreglong.R

library(IrregLong)
library(nlme)
library(survival)

cat("=== IrregLong Phenobarb Cross-Validation ===\n")
cat("IrregLong version:", as.character(packageVersion("IrregLong")), "\n\n")

cmd_args <- commandArgs(FALSE)
file_arg <- grep("^--file=", cmd_args, value = TRUE)
outdir <- if (length(file_arg)) {
    dirname(normalizePath(sub("^--file=", "", file_arg[1])))
} else {
    getwd()
}

# =============================================================================
# 1. Load and prepare Phenobarb data (following vignette exactly)
# =============================================================================

data(Phenobarb)
Phenobarb$event <- 1 - as.numeric(is.na(Phenobarb$conc))
data <- Phenobarb
data <- data[data$event == 1, ]
data$id <- as.numeric(data$Subject)
data <- data[data$time < 16 * 24, ]
data <- data[order(data$id, data$time), ]
data$Apgar <- as.numeric(data$Apgar)

cat("Phenobarb prepared: N =", nrow(data), "observations,",
    length(unique(data$id)), "subjects\n")

# =============================================================================
# 2. Compute IIW weights using iiw.weights()
# =============================================================================

# Following the vignette: simplified model after backward elimination
# Covariates: binned lagged concentration
i <- iiw.weights(
    Surv(time.lag, time, event) ~ I(conc.lag > 0 & conc.lag <= 20) +
                                   I(conc.lag > 20 & conc.lag <= 30) +
                                   I(conc.lag > 30) +
                                   cluster(Subject),
    id = "Subject",
    time = "time",
    event = "event",
    data = data,
    invariant = c("Subject", "Wt"),
    lagvars = c("time", "conc"),
    maxfu = 16 * 24,
    lagfirst = c(0, 0),
    first = FALSE
)

# Extract weights
data$iiw_weight <- i$iiw.weight

# Cox model coefficients
cox_coefs <- coef(i$m)
cox_ses <- sqrt(diag(vcov(i$m)))
cat("\nCox model coefficients:\n")
print(cox_coefs)

# Also compute with first=TRUE for alternative comparison
i_first <- iiw.weights(
    Surv(time.lag, time, event) ~ I(conc.lag > 0 & conc.lag <= 20) +
                                   I(conc.lag > 20 & conc.lag <= 30) +
                                   I(conc.lag > 30) +
                                   cluster(Subject),
    id = "Subject",
    time = "time",
    event = "event",
    data = data,
    invariant = c("Subject", "Wt"),
    lagvars = c("time", "conc"),
    maxfu = 16 * 24,
    lagfirst = c(0, 0),
    first = TRUE
)
data$iiw_weight_first1 <- i_first$iiw.weight

cat("\nWeight summary (first=FALSE):\n")
print(summary(data$iiw_weight))
cat("\nWeight summary (first=TRUE):\n")
print(summary(data$iiw_weight_first1))

# =============================================================================
# 3. Export: prepared data with weights
# =============================================================================

# Create lagged variables matching what IrregLong used internally
data_sorted <- data[order(data$id, data$time), ]
data_sorted$time_lag <- ave(data_sorted$time, data_sorted$id,
    FUN = function(x) c(0, x[-length(x)]))
data_sorted$conc_lag <- ave(data_sorted$conc, data_sorted$id,
    FUN = function(x) c(0, x[-length(x)]))

# Observation number within subject
data_sorted$visit_n <- ave(rep(1, nrow(data_sorted)), data_sorted$id,
    FUN = cumsum)

# Export dataset
export_cols <- c("id", "time", "time_lag", "conc", "conc_lag", "Wt",
                 "Apgar", "event", "visit_n", "iiw_weight", "iiw_weight_first1")
write.csv(data_sorted[, export_cols],
    file = file.path(outdir, "phenobarb_prepared.csv"),
    row.names = FALSE)

# =============================================================================
# 2b. EXACT-PARITY reference model
# =============================================================================
# The binned model above cannot be reproduced exactly by iivw_weight, and the
# reason is worth stating: its covariates are *pre-computed* bins of conc.lag.
# IrregLong builds its lags AFTER appending the maxfu censoring rows, so on a
# censoring row conc.lag is conc at the subject's last visit. A pre-computed lag
# copied onto that row instead carries conc from the visit before it -- off by
# one. Any implementation that lags before appending gets this wrong.
#
# So the parity oracle uses conc.lag itself, which BOTH sides derive from the
# raw conc column: R via lagvars=c("time","conc"), Stata via lagvars(conc). The
# two censoring rows are then identical by construction, and the Cox
# coefficients must agree to numerical tolerance -- not merely correlate.
i_par <- iiw.weights(
    Surv(time.lag, time, event) ~ conc.lag + cluster(Subject),
    id = "Subject", time = "time", event = "event",
    data = data,
    invariant = c("Subject", "Wt"),
    lagvars = c("time", "conc"),
    maxfu = 16 * 24,
    lagfirst = c(0, 0),
    first = FALSE
)
par_coefs <- coef(i_par$m)
par_ses <- sqrt(diag(vcov(i_par$m)))
cat("\nExact-parity Cox model (conc.lag, maxfu = 384):\n")
print(par_coefs)
cat("  n intervals:", i_par$m$n, " n events:", i_par$m$nevent, "\n")

write.csv(
    data.frame(term = names(par_coefs),
               estimate = as.numeric(par_coefs),
               se = as.numeric(par_ses),
               n = i_par$m$n,
               nevent = i_par$m$nevent),
    file = file.path(outdir, "phenobarb_parity_coefs.csv"),
    row.names = FALSE
)

# ... and the same model under iivw's DEFAULT baseline contract, where the first
# visit is study entry rather than a modeled event.
#
# This is the arm Stata can match to the digit. IrregLong sets the first row's
# lag to a constant (lagfirst = 0); iivw leaves it missing, since there is no
# previous visit to lag from. That disagreement only touches the FIRST interval
# of each subject -- and under baseline(entry) that interval is not a modeled
# event at all, so the two implementations are then fitting identically
# constructed data and the coefficients must agree exactly rather than merely
# closely.
dc <- addcensoredrows(data, maxfu = 16 * 24,
                      tinvarcols = which(names(data) %in% c("Subject", "Wt")),
                      id = "Subject", time = "time", event = "event")
dc <- lagfn(dc, lagvars = c("time", "conc"), id = "Subject", time = "time",
            lagfirst = c(0, 0))
dc <- dc[order(dc$Subject, dc$time), ]
# Drop each subject's first VISIT row (the censoring rows are not visits).
firstvisit <- ave(rep(1, nrow(dc)), dc$Subject, FUN = cumsum) == 1
dc_entry <- dc[!firstvisit, ]

m_entry <- coxph(Surv(time.lag, time, event) ~ conc.lag, data = dc_entry)
cat("\nExact-parity Cox model, baseline-as-entry (conc.lag, maxfu = 384):\n")
print(coef(m_entry))
cat("  n intervals:", m_entry$n, " n events:", m_entry$nevent, "\n")

write.csv(
    data.frame(term = names(coef(m_entry)),
               estimate = as.numeric(coef(m_entry)),
               se = as.numeric(sqrt(diag(vcov(m_entry)))),
               n = m_entry$n,
               nevent = m_entry$nevent),
    file = file.path(outdir, "phenobarb_parity_entry_coefs.csv"),
    row.names = FALSE
)

# Exact-parity WEIGHTS from that same model.
#
# Matching the coefficient proves the two implementations fit the same Cox
# model. It does NOT prove they then turn it into the same weight: the exponent
# sign, the centering convention and the first-visit rule all live downstream of
# the coefficient, and a bug in any of them leaves the coefficient untouched.
# So export exp(-xb) at each observed visit row and let Stata match it to the
# digit.
#
# reference = "zero" is load-bearing. coxph's default linear predictor is
# CENTERED at the mean covariate; Stata's `predict, xb' after stcox is not. A
# centered oracle would differ from iivw by the constant exp(mean(x) * beta) --
# a uniform rescaling that a correlation check sails straight through, which is
# the exact failure mode XV4/XV3 already demonstrated.
dc_entry$xb_par <- as.numeric(
    predict(m_entry, newdata = dc_entry, type = "lp", reference = "zero"))
obs_par <- dc_entry[dc_entry$event == 1, ]
write.csv(
    data.frame(id = obs_par$Subject,
               time = obs_par$time,
               r_w = exp(-obs_par$xb_par)),
    file = file.path(outdir, "phenobarb_parity_entry_weights.csv"),
    row.names = FALSE
)
cat("  parity weights rows:", nrow(obs_par), "\n")

# Export Cox coefficients
coef_df <- data.frame(
    term = names(cox_coefs),
    estimate = as.numeric(cox_coefs),
    se = as.numeric(cox_ses)
)
write.csv(coef_df,
    file = file.path(outdir, "phenobarb_cox_coefs.csv"),
    row.names = FALSE)

# Also export the full Cox data (with censoring rows) for diagnostics
cox_data <- i$datacox
write.csv(cox_data[, c("Subject", "time", "time.lag", "conc", "conc.lag",
                        "event", "Wt")],
    file = file.path(outdir, "phenobarb_cox_data.csv"),
    row.names = FALSE)

cat("\nExported:\n")
cat("  ", file.path(outdir, "phenobarb_prepared.csv"), "\n")
cat("  ", file.path(outdir, "phenobarb_cox_coefs.csv"), "\n")
cat("  ", file.path(outdir, "phenobarb_parity_coefs.csv"), "\n")
cat("  ", file.path(outdir, "phenobarb_cox_data.csv"), "\n")

# =============================================================================
# 4. Also compute weights manually for verification
# =============================================================================

cat("\n=== Manual weight verification ===\n")
# The Cox data includes censoring rows at maxfu
# Fit Cox on full data (with censoring)
m_manual <- coxph(
    Surv(time.lag, time, event) ~ I(conc.lag > 0 & conc.lag <= 20) +
                                   I(conc.lag > 20 & conc.lag <= 30) +
                                   I(conc.lag > 30),
    data = cox_data
)
cat("Manual Cox coefs (should match):\n")
print(coef(m_manual))

# Predict on observed data only
obs_data <- cox_data[cox_data$event == 1, ]
xb <- predict(m_manual, newdata = obs_data, type = "lp")
manual_weights <- exp(-xb)
cat("\nManual weight summary (exp(-xb)):\n")
print(summary(manual_weights))

cat("\n=== Cross-validation data ready ===\n")

# =============================================================================
# Completion sentinel + version manifest
# =============================================================================
# Stata's `shell' does not propagate a child process's exit status: _rc is 0
# even when Rscript is missing or dies halfway. The runner therefore cannot tell
# "R failed" from "R succeeded" by return code, and a failed R run would leave
# the reference CSVs above STALE while the crossval lane compared against them
# and passed. This file is written as the very last statement of the script, so
# its existence is the only proof the CSVs were actually regenerated.
#
# It is written from R rather than by a shell `touch' in the runner, both because
# `touch' is Unix-only and because a sentinel R writes itself proves the script
# reached its end -- a `touch' chained with && only proves Rscript exited 0.
#
# The manifest records the exact package versions that produced these CSVs. A
# parity failure that turns out to be an upstream version change is otherwise
# indistinguishable from a regression in iivw.
pkgs <- c("survival", "nlme", "IrregLong", "geepack", "ipw", "cobalt")
have <- pkgs[vapply(pkgs, requireNamespace, logical(1), quietly = TRUE)]
manifest <- data.frame(
    package = c("R", have),
    version = c(paste(R.version$major, R.version$minor, sep = "."),
                vapply(have, function(p) as.character(utils::packageVersion(p)),
                       character(1)))
)
write.csv(manifest, file = file.path(outdir, "crossval_irreglong_versions.csv"),
          row.names = FALSE)
cat("\nReference package versions:\n")
print(manifest, row.names = FALSE)

writeLines("ok", file.path(outdir, "crossval_irreglong.ok"))
