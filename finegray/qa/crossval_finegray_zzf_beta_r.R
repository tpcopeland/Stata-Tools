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
# The five arms include the published stratified construction (C: the same
# discrete group controls G and H) and a genuinely cross-classified extension
# (X: distinct censoring and entry groups).  Every arm is compared dataset by
# dataset; none is allowed to hide behind recovery alone.
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

suppressPackageStartupMessages(library(survival))

if (!file.exists(ORACLE))
  stop("run this from finegray/qa: cannot find ", ORACLE)
dir.create(OUT, showWarnings = FALSE, recursive = TRUE)
stale <- list.files(OUT, pattern = "^zzf_xv_.*[.]csv$", full.names = TRUE)
if (length(stale) && !all(file.remove(stale)))
  stop("could not invalidate every stale ZZF cross-validation artifact")

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
stopifnot(is.function(gen_fg), is.function(zzf_fit),
          is.function(zzf_fit_cross), is.function(coxph_on_our_weights),
          all(BETA == c(0.5, -0.5)))
cat("definitions loaded from", ORACLE, "; BETA =", BETA, "\n")

N    <- as.integer(Sys.getenv("ZZF_XV_N",    "3000"))
REPS <- as.integer(Sys.getenv("ZZF_XV_REPS", "20"))

pool <- function(d) { d$wgroup <- 0L; d }

# arm -> entry pattern and weight specification.
arms <- list(
  A = list(trunc = "none",        method = "pooled"),
  B = list(trunc = "independent", method = "pooled"),
  C = list(trunc = "bygroup",     method = "same"),
  D = list(trunc = "bygroup",     method = "pooled"),
  X = list(trunc = "cross",       method = "cross")
)

rows <- list()
for (a in names(arms)) {
  spec <- arms[[a]]
  for (r in seq_len(REPS)) {
    seed <- 20260713L + r                      # same seed => same data across arms
    d <- gen_fg(N, spec$trunc, seed = seed)
    if (spec$method == "pooled") {
      d <- pool(d)
      zz <- zzf_fit(d, c("z1", "z2"), stabilizer = "pooled")
    } else if (spec$method == "same") {
      d$cgroup <- d$z1
      d$tgroup <- d$z1
      zz <- zzf_fit_cross(d, c("z1", "z2"), d$cgroup, d$tgroup)
    } else {
      zz <- zzf_fit_cross(d, c("z1", "z2"), d$cgroup, d$tgroup)
    }
    if (zz$conv != 0)
      stop("oracle failed to converge: arm ", a, " rep ", r)

    # Same weights, independent optimizer.  This catches a direct-oracle
    # objective/gradient mistake before Stata ever sees the frozen beta.
    cxb <- coxph_on_our_weights(d, zz, c("z1", "z2"))
    if (max(abs(cxb - zz$beta)) >= 5e-5)
      stop("oracle optimizer disagreement: arm ", a, " rep ", r)

    # The DATA Stata must fit.  Emit the fields finegray needs and nothing else.
    write.csv(d[, c("id", "L", "X", "status", "z1", "z2", "cgroup", "tgroup")],
              file.path(OUT, sprintf("zzf_xv_%s_%02d.csv", a, r)),
              row.names = FALSE)

    rows[[length(rows) + 1L]] <- data.frame(
      arm = a, rep = r, n = nrow(d), trunc = spec$trunc, method = spec$method,
      b1 = unname(zz$beta["z1"]), b2 = unname(zz$beta["z2"]),
      ll = zz$ll, nevent = sum(d$status == 1L)
    )
  }
  cat("arm", a, "(", spec$trunc, ",", spec$method, "): ", REPS,
      "datasets fitted\n")
}

beta <- do.call(rbind, rows)
write.csv(beta, file.path(OUT, "zzf_xv_oracle_beta.csv"), row.names = FALSE)
manifest <- data.frame(
  schema_version = 2L,
  arm = names(arms),
  expected_reps = REPS,
  expected_n = N,
  method = vapply(arms, `[[`, character(1), "method"),
  fit_options = c("pooled", "pooled", "strata(z1) truncstrata(z1)",
                  "pooled", "strata(cgroup) truncstrata(tgroup)")
)
write.csv(manifest, file.path(OUT, "zzf_xv_manifest.csv"), row.names = FALSE)

cat("\n=== oracle betas (truth =", BETA, ") ===\n")
print(beta[, c("arm", "rep", "n", "nevent", "b1", "b2")], row.names = FALSE, digits = 8)
cat("\nwrote", nrow(beta), "datasets + oracle + manifest in", OUT, "\n")
