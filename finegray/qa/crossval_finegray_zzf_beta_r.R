# ---------------------------------------------------------------------
# crossval_finegray_zzf_beta_r.R -- oracle side of the ZZF beta crossval.
#
# PURPOSE.  Emit, for a handful of simulated datasets, BOTH the data and the
# coefficient vector that the independent R implementation of the stabilized
# ZZF Weight-1 estimator produces on it.  `crossval_finegray_zzf.do` then fits
# the SAME datasets with Stata's finegray and compares beta-for-beta.
#
# This is a PER-DATASET comparison, not a comparison of Monte-Carlo means.  It
# answers "does Stata compute the same estimator as the oracle?" -- which a
# recovery study cannot answer, because a recovery study can only see bias, and
# bias is a property of the estimator, not of the implementation.  Twenty
# datasets at n = 3000 settle it; a million reps would not.
#
# The four arms mirror validation_finegray_zzf_recovery.do.  Arms A, B and D
# pool the weights (R: wgroup == 0 for everyone; Stata: no strata(), no
# truncstrata()), so the two implementations compute the SAME statistic and are
# required to agree.  Arm C is DELIBERATELY EXCLUDED: R's `wgroup` stratifies
# G and H jointly, whereas Stata's truncstrata(z1) stratifies H alone and pools
# G.  Those are consistent for the same estimand (censoring does not depend on
# the group in this DGP) but they are NOT the same statistic, so requiring them
# to agree on a single dataset would be wrong.  Arm C's correctness is
# established by recovery in validation_finegray_zzf_recovery.do.
#
# Definitions (gen_fg, zzf_fit, zzf_weights, BETA) are sourced from the frozen
# oracle so this file cannot drift away from it.
#
# Usage (from finegray/qa):
#   Rscript crossval_finegray_zzf_beta_r.R
#   ZZF_XV_N=1500 ZZF_XV_REPS=3 Rscript crossval_finegray_zzf_beta_r.R   # smoke
# ---------------------------------------------------------------------

ORACLE <- "crossval_finegray_zzf_r.R"          # relative: run from finegray/qa
OUT    <- "data"                               # the .do file reads from here

if (!file.exists(ORACLE))
  stop("run this from finegray/qa: cannot find ", ORACLE)

# Load ONLY the top-level function and CONSTANT definitions out of the oracle,
# without executing its fixture-writing body.
local({
  exprs <- parse(ORACLE)
  for (e in exprs) {
    if (!is.call(e) || !identical(e[[1]], as.name("<-"))) next
    nm  <- e[[2]]
    rhs <- e[[3]]
    is_fun   <- is.call(rhs) && identical(rhs[[1]], as.name("function"))
    is_const <- is.name(nm) && grepl("^[A-Z0-9_]+$", as.character(nm))
    if (is_fun || is_const) eval(e, envir = globalenv())
  }
})
stopifnot(is.function(gen_fg), is.function(zzf_fit), all(BETA == c(0.5, -0.5)))
cat("definitions loaded from", ORACLE, "; BETA =", BETA, "\n")

N    <- as.integer(Sys.getenv("ZZF_XV_N",    "3000"))
REPS <- as.integer(Sys.getenv("ZZF_XV_REPS", "20"))

pool <- function(d) { d$wgroup <- 0L; d }

# arm -> (entry pattern, weight specification).  All three POOL the weights.
arms <- list(
  A = list(trunc = "none",        pool = TRUE),
  B = list(trunc = "independent", pool = TRUE),
  D = list(trunc = "bygroup",     pool = TRUE)
)

rows <- list()
for (a in names(arms)) {
  spec <- arms[[a]]
  for (r in seq_len(REPS)) {
    seed <- 20260713L + r                      # same seed => same data across arms
    d <- gen_fg(N, spec$trunc, seed = seed)
    if (spec$pool) d <- pool(d)

    zz <- zzf_fit(d, c("z1", "z2"))
    if (zz$conv != 0)
      stop("oracle failed to converge: arm ", a, " rep ", r)

    # The DATA Stata must fit.  Emit the fields finegray needs and nothing else.
    write.csv(d[, c("id", "L", "X", "status", "z1", "z2")],
              file.path(OUT, sprintf("zzf_xv_%s_%02d.csv", a, r)),
              row.names = FALSE)

    rows[[length(rows) + 1L]] <- data.frame(
      arm = a, rep = r, n = nrow(d), trunc = spec$trunc,
      b1 = unname(zz$beta["z1"]), b2 = unname(zz$beta["z2"]),
      ll = zz$ll, nevent = sum(d$status == 1L)
    )
  }
  cat("arm", a, "(", spec$trunc, "): ", REPS, "datasets fitted\n")
}

beta <- do.call(rbind, rows)
write.csv(beta, file.path(OUT, "zzf_xv_oracle_beta.csv"), row.names = FALSE)

cat("\n=== oracle betas (truth =", BETA, ") ===\n")
print(beta[, c("arm", "rep", "n", "nevent", "b1", "b2")], row.names = FALSE, digits = 8)
cat("\nwrote", nrow(beta), "datasets +", file.path(OUT, "zzf_xv_oracle_beta.csv"), "\n")
