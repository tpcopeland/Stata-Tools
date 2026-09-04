# crossval_cif_r.R
# Reference cumulative incidence (point estimates) for the Fine-Gray model,
# from riskRegression::FGR + predictRisk, for cross-validating finegray_cif /
# finegray_predict, cif.
#
# Usage: Rscript crossval_cif_r.R <input.csv> <newdata.csv> <times.csv> <out.csv>
#   input.csv   : columns time, status, and the covariates (ifp tumsize pelnode)
#   newdata.csv : covariate profiles (one row per profile, same covariate cols)
#   times.csv   : single column 'time' of horizons
#   out.csv     : written with columns profile, time, cif

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 4) stop("need input newdata times out")

ok <- requireNamespace("riskRegression", quietly = TRUE) &&
      requireNamespace("prodlim", quietly = TRUE) &&
      requireNamespace("survival", quietly = TRUE)
if (!ok) {
    cat("SKIP: riskRegression/prodlim/survival not available\n")
    quit(status = 0)
}
suppressMessages({
    library(riskRegression); library(prodlim); library(survival)
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
                "crossval_cif_r.R", as.character(getRversion()), R.version$platform))
    for (p in pkgs) {
        v <- tryCatch(as.character(utils::packageVersion(p)),
                      error = function(e) "NOT-INSTALLED")
        cat(sprintf("R_ENV: package %s = %s\n", p, v))
    }
}
.fg_banner(c("riskRegression", "prodlim", "survival"))

# Oracle cache (added 2026-09-04): this script is a pure function of its
# inputs, so its output is cached and only recomputed when an input changes.
# See _fg_oracle_cache.R for the key and the fail-closed rules.
source(file.path(dirname(sub("^--file=", "", grep("^--file=",
       commandArgs(FALSE), value = TRUE)[1])), "_fg_oracle_cache.R"))
.fgc <- fg_oracle_cache_begin('cif', outputs = args[4],
                              key_files = c(args[1], args[2], args[3]),
                              packages = c("riskRegression", "prodlim", "survival"))
if (identical(.fgc$state, "hit")) quit(save = "no", status = 0)

d  <- read.csv(args[1])
nd <- read.csv(args[2])
tm <- read.csv(args[3])$time
d$status <- factor(d$status)

covs <- setdiff(names(d), c("time", "status"))
f <- FGR(as.formula(paste("Hist(time,status) ~", paste(covs, collapse = "+"))),
         data = d, cause = 1)

out <- data.frame()
for (i in seq_len(nrow(nd))) {
    r <- predictRisk(f, newdata = nd[i, , drop = FALSE], times = tm)
    out <- rbind(out, data.frame(profile = i, time = tm, cif = as.numeric(r)))
}
write.csv(out, args[4], row.names = FALSE)
fg_oracle_cache_end(.fgc)
cat("OK: wrote", nrow(out), "rows\n")
