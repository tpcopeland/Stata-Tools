# validation_finegray_zzf_prereg_r.R
#
# Z2 PREREGISTRATION probe.  Companion to validation_finegray_zzf_recovery.do:
# it fixes that file's negative-control expectation, and its output is quoted
# verbatim in that file's Z2-PREREG header.  Kept in qa/ so the preregistration
# is REPRODUCIBLE -- a recorded expectation nobody can re-derive is an assertion,
# not evidence.
#
# Run:  Rscript validation_finegray_zzf_prereg_r.R     (from finegray/qa)
#
# ORIGINAL HEADER
# --------------
#
# fg_zzf_plan.md Phase Z2: "State the expected sign of the negative-control bias
# in the QA header BEFORE running the gated repetitions."
#
# The sign of the arm-D bias is a property of (estimator, DGP), not of the Stata
# Monte Carlo.  So derive it from the independent R oracle instead of guessing --
# and get, for free, the answer to the question that actually decides whether Z3
# is worth building: does the ZZF estimator RECOVER the truth on arms B and C?
# If it does not, no amount of engine work will turn Gate Z2 green.
#
# Arms (all share gen_fg, the ZZF sec. 4.1 DGP; truth = BETA = (0.5, -0.5)):
#   A  none        + pooled weights      -> control, must recover
#   B  independent + pooled weights      -> supported, must recover
#   C  bygroup     + published stratified weights -> supported, must recover
#   D  bygroup     + pooled weights      -> NEGATIVE CONTROL, must stay biased
#
# "pooled" is represented by collapsing wgroup to a single level.  Arm C uses
# ZZF equation (7): a pooled time-side stabilizer with z1-specific denominators.

# The oracle file runs the Z1 gate at top level, so source() would re-run it (and
# rewrite the frozen CSVs).  Evaluate ONLY its definitions: function definitions
# and ALL_CAPS constants.  Anything else in the file is gate code and is skipped.
suppressPackageStartupMessages({library(survival); library(cmprsk)})
ORACLE <- "crossval_finegray_zzf_r.R"          # relative: run from finegray/qa
if (!file.exists(ORACLE)) stop("run this from the finegray/qa directory (cannot see ", ORACLE, ")")
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
          is.function(zzf_fit_cross), all(BETA == c(0.5, -0.5)))
cat("definitions loaded: gen_fg, zzf_fit, zzf_fit_cross; BETA =", BETA, "\n")

# The preregistration itself was run at N = 3000, REPS = 80 (the numbers quoted
# in validation_finegray_zzf_recovery.do's Z2-PREREG header).  Override to check
# cheaply that this file still resolves its oracle after a move:
#   ZZF_PREREG_N=800 ZZF_PREREG_REPS=2 Rscript validation_finegray_zzf_prereg_r.R
N    <- as.integer(Sys.getenv("ZZF_PREREG_N",    "3000"))
REPS <- as.integer(Sys.getenv("ZZF_PREREG_REPS", "80"))
if (N < 3000L || REPS < 80L)
  cat("*** SMOKE SETTINGS (N =", N, ", REPS =", REPS, ") -- path/plumbing check only.\n",
      "*** These numbers do NOT restate the preregistration.\n")

pool <- function(d) { d$wgroup <- 0L; d }

arms <- list(
  A_none_pooled      = function(s) zzf_fit(pool(gen_fg(N, "none",        seed = s)), c("z1","z2")),
  B_indep_pooled     = function(s) zzf_fit(pool(gen_fg(N, "independent", seed = s)), c("z1","z2")),
  C_bygroup_strat    = function(s) {
    d <- gen_fg(N, "bygroup", seed = s)
    zzf_fit_cross(d, c("z1", "z2"), d$z1, d$z1)
  },
  D_bygroup_pooled   = function(s) zzf_fit(pool(gen_fg(N, "bygroup",     seed = s)), c("z1","z2"))
)

res <- lapply(arms, function(f) matrix(NA_real_, REPS, 2, dimnames = list(NULL, c("z1","z2"))))
for (r in seq_len(REPS)) {
  s <- 900000L + r
  for (a in names(arms)) res[[a]][r, ] <- tryCatch(f <- arms[[a]](s)$beta, error = function(e) c(NA, NA))
}

cat("\n=== Z2 preregistration: ZZF oracle, n =", N, "reps =", REPS, "truth = (0.5, -0.5)\n")
cat(sprintf("%-18s %-4s %9s %9s %9s %9s %10s\n",
            "arm", "coef", "mean", "bias", "SD", "MCSE", "bias/MCSE"))
for (a in names(res)) {
  for (cf in c("z1", "z2")) {
    b <- res[[a]][, cf]; b <- b[is.finite(b)]
    truth <- BETA[[cf]]
    bias <- mean(b) - truth; mcse <- sd(b) / sqrt(length(b))
    cat(sprintf("%-18s %-4s %9.5f %+9.5f %9.5f %9.5f %+10.2f\n",
                a, cf, mean(b), bias, sd(b), mcse, bias / mcse))
  }
}
cat("\nreps used per arm:", vapply(res, function(m) sum(is.finite(m[,1])), integer(1)), "\n")
