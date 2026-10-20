# crossval_kmplot_cif.R
# External reference for crossval_kmplot_cif.do: cumulative incidence with a
# competing event from R survival::survfit (multi-state pstate) and, on
# unweighted single-record data, cmprsk::cuminc.
# Author: Timothy P Copeland, Karolinska Institutet
#
# Usage: Rscript crossval_kmplot_cif.R <in.csv> <out.csv>
# in.csv columns: scenario, rep, g, id, t0, t, status (0 censored, 1 interest,
# 2 competing), w (case weight).  Scenarios:
#   plain, ties   unweighted, one record per subject, Surv(t, factor(status))
#   wt            weighted, survfit(weights = w)
#   entry         delayed entry, Surv(t0, t, factor(status)) with id
#   gridentry     integer times, entries tie event times (strict t0 < t at risk)
#   gridid        the same with id() record splits at integer times
#   gridfw        gridid with frequency weights; gridpw with double pweights
#   multirec      several contiguous records per subject, same input form
# out.csv: scenario, rep, g, src (sf = survfit, cm = cuminc), time, est
suppressPackageStartupMessages({library(survival); library(cmprsk)})
args <- commandArgs(trailingOnly = TRUE)
dat <- read.csv(args[1])
out <- list()
for (key in unique(paste(dat$scenario, dat$rep))) {
  parts <- strsplit(key, " ")[[1]]
  sc <- parts[1]; rp <- as.numeric(parts[2])
  sub <- dat[dat$scenario == sc & dat$rep == rp, ]
  for (g in sort(unique(sub$g))) {
    sg <- sub[sub$g == g, ]
    sg$ev <- factor(sg$status, levels = c(0, 1, 2))
    if (sc %in% c("gridfw", "gridpw")) {
      fit <- survfit(Surv(t0, t, ev) ~ 1, data = sg, id = id, weights = w)
    } else if (sc %in% c("entry", "multirec", "gridentry", "gridid")) {
      fit <- survfit(Surv(t0, t, ev) ~ 1, data = sg, id = id)
    } else if (sc == "wt") {
      fit <- survfit(Surv(t, ev) ~ 1, data = sg, weights = w)
    } else {
      fit <- survfit(Surv(t, ev) ~ 1, data = sg)
    }
    k <- match("1", colnames(fit$pstate))
    if (is.na(k)) stop("state 1 not found in pstate")
    out[[length(out) + 1]] <- data.frame(scenario = sc, rep = rp, g = g,
      src = "sf", time = fit$time, est = fit$pstate[, k])
    if (sc %in% c("plain", "ties")) {
      ci <- cuminc(sg$t, sg$status, cencode = 0)
      c1 <- ci[["1 1"]]
      # cuminc lists a left and a right limit at each jump; the cumulative
      # incidence is non-decreasing, so the larger value is the post-jump one
      c1 <- aggregate(est ~ time, data = data.frame(time = c1$time, est = c1$est), FUN = max)
      out[[length(out) + 1]] <- data.frame(scenario = sc, rep = rp, g = g,
        src = "cm", time = c1$time, est = c1$est)
    }
  }
}
res <- do.call(rbind, out)
# 17 significant digits so Stata reads back the exact doubles
res$time <- sprintf("%.17g", res$time)
res$est <- sprintf("%.17g", res$est)
write.csv(res, args[2], row.names = FALSE, quote = FALSE)
cat("rows", nrow(res), "survival", as.character(packageVersion("survival")),
    "cmprsk", as.character(packageVersion("cmprsk")), "\n")
