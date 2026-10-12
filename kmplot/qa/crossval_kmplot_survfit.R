# crossval_kmplot_survfit.R
# External reference for crossval_kmplot_survfit.do: R survival::survfit.
# Author: Timothy P Copeland, Karolinska Institutet
#
# Usage: Rscript crossval_kmplot_survfit.R <in.csv> <out.csv> <times> <lr.csv>
# in.csv: scenario, rep, grp, t0, t, d.  For every scenario x rep x grp it
# writes the pointwise 95% interval under all three transforms
# (conf.type = "log-log", "log", "plain"; R clamps log and plain to [0, 1],
# as kmplot does), the number at risk (counting-process Surv(t0, t, d), so delayed
# entry is honoured), and the median.  R's median is the midpoint of an
# exact S = 0.5 plateau (within R's own tolerance, sqrt(.Machine$double.eps));
# plateau_start records where that plateau begins,
# which is the convention of Stata's stci and kmplot.
# lr.csv: for every scenario x rep, the two-group log-rank chi-squared and
# p-value from survdiff(rho = 0).  survdiff refuses counting-process data,
# so this comparison treats every subject as entering at time 0 (Surv(t, d)).
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
  s_log <- summary(survfit(Surv(t0, t, d) ~ 1, data = sub, conf.type = "log",
                          conf.int = 0.95), times = times, extend = TRUE)
  s_pl <- summary(survfit(Surv(t0, t, d) ~ 1, data = sub, conf.type = "plain",
                         conf.int = 0.95), times = times, extend = TRUE)
  med <- unname(summary(fit)$table["median"])
  half <- which(abs(fit$surv - 0.5) < sqrt(.Machine$double.eps))
  plateau <- if (length(half)) fit$time[min(half)] else NA
  first_below <- which(fit$surv <= 0.5 + sqrt(.Machine$double.eps))
  stata_rule <- if (length(first_below)) fit$time[min(first_below)] else NA
  out[[key]] <- data.frame(scenario = parts[1], rep = as.numeric(parts[2]),
    grp = as.numeric(parts[3]), time = s$time, surv = s$surv,
    lower = s$lower, upper = s$upper,
    lower_log = s_log$lower, upper_log = s_log$upper,
    lower_plain = s_pl$lower, upper_plain = s_pl$upper, n_risk = s$n.risk,
    r_median = med, plateau_start = plateau, first_le_half = stata_rule,
    maxfu = max(sub$t))
}
res <- do.call(rbind, out)
lr <- list()
for (key in unique(paste(dat$scenario, dat$rep))) {
  parts <- strsplit(key, " ")[[1]]
  sub <- dat[dat$scenario == parts[1] & dat$rep == as.numeric(parts[2]), ]
  sd <- survdiff(Surv(t, d) ~ grp, data = sub, rho = 0)
  lr[[key]] <- data.frame(scenario = parts[1], rep = as.numeric(parts[2]),
    chisq = sd$chisq, p = pchisq(sd$chisq, df = 1, lower.tail = FALSE))
}
write.csv(do.call(rbind, lr), args[4], row.names = FALSE, na = "")
write.csv(res, args[2], row.names = FALSE, na = "")
cat("rows", nrow(res), "survival", as.character(packageVersion("survival")), "\n")
