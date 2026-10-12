# crossval_kmplot_survfit.R
# External reference for crossval_kmplot_survfit.do: R survival::survfit.
# Author: Timothy P Copeland, Karolinska Institutet
#
# Usage: Rscript crossval_kmplot_survfit.R <in.csv> <out.csv> <times>
# in.csv: scenario, rep, grp, t0, t, d.  For every scenario x rep x grp it
# writes the log-log pointwise interval (conf.type = "log-log", conf.int =
# 0.95), the number at risk (counting-process Surv(t0, t, d), so delayed
# entry is honoured), and the median.  R's median is the midpoint of an
# exact S = 0.5 plateau (within R's own tolerance, sqrt(.Machine$double.eps));
# plateau_start records where that plateau begins,
# which is the convention of Stata's stci and kmplot.
suppressPackageStartupMessages(library(survival))
args <- commandArgs(trailingOnly = TRUE)
dat <- read.csv(args[1])
times <- as.numeric(strsplit(args[3], " ")[[1]])
out <- list()
for (key in unique(paste(dat$scenario, dat$rep, dat$grp))) {
  parts <- strsplit(key, " ")[[1]]
  sub <- dat[dat$scenario == parts[1] & dat$rep == as.numeric(parts[2]) &
               dat$grp == as.numeric(parts[3]), ]
  fit <- survfit(Surv(t0, t, d) ~ 1, data = sub, conf.type = "log-log",
                 conf.int = 0.95)
  s <- summary(fit, times = times, extend = TRUE)
  med <- unname(summary(fit)$table["median"])
  half <- which(abs(fit$surv - 0.5) < sqrt(.Machine$double.eps))
  plateau <- if (length(half)) fit$time[min(half)] else NA
  first_below <- which(fit$surv <= 0.5 + sqrt(.Machine$double.eps))
  stata_rule <- if (length(first_below)) fit$time[min(first_below)] else NA
  out[[key]] <- data.frame(scenario = parts[1], rep = as.numeric(parts[2]),
    grp = as.numeric(parts[3]), time = s$time, surv = s$surv,
    lower = s$lower, upper = s$upper, n_risk = s$n.risk,
    r_median = med, plateau_start = plateau, first_le_half = stata_rule,
    maxfu = max(sub$t))
}
res <- do.call(rbind, out)
write.csv(res, args[2], row.names = FALSE, na = "")
cat("rows", nrow(res), "survival", as.character(packageVersion("survival")), "\n")
