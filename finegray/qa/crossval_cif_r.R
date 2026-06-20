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
cat("OK: wrote", nrow(out), "rows\n")
