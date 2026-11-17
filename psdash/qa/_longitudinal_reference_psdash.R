#!/usr/bin/env Rscript
# _longitudinal_reference_psdash.R -- cobalt + WeightIt reference values for
# psdash combined's longitudinal (period-stratified) route.
# Usage: Rscript _longitudinal_reference_psdash.R <in.csv> <out.csv>
#   in.csv  columns id, period, treat (0/1), ps, wt  -- exactly the rows psdash analysed
#   out.csv columns scope, metric, value (value printed with %.17g)
#
# Definition map (psdash quantity -> reference implementation):
#   overlap_by_period N, N_treated, N_control    -> row counts by arm
#   overlap_by_period mean_treated/mean_control  -> cobalt::bal.tab Balance M.1.Un / M.0.Un of ps
#   weights_by_period N                          -> row count
#   weights_by_period mean, sd                   -> cobalt::col_w_mean, cobalt::col_w_sd (n-1 SD)
#   weights_by_period max                        -> WeightIt summary(as.weightit(...))$weight.range max over arms
#   weights_by_period ess_pct                    -> 100 * WeightIt::ESS(w) / N
#   weights_by_period ess_treated/control_pct    -> 100 * summary.weightit effective.sample.size / arm N
#                                                   (cobalt bal.tab()$Observations "Adjusted" row is a second check)
#   overall mean_wt/sd_wt/cv                     -> cobalt col_w_mean/col_w_sd, sd/mean
#   overall min_wt/max_wt                        -> WeightIt summary weight.range over arms
#   overall ess, ess_pct                         -> WeightIt::ESS (Kish, pooled across arms)
#   overall p1/p5/p50/p95/p99                    -> stats::quantile(type = 2), the Stata summarize,detail rule
#   overall n_extreme                            -> count of w > 10
# Not claimable here (no maintained package reports them): per-period min/max PS
# by arm, overlap bounds, percent outside support, per-period p95/p99.

args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 2L) stop("usage: Rscript _longitudinal_reference_psdash.R <in.csv> <out.csv>")
suppressMessages({
  library(cobalt)
  library(WeightIt)
})

d <- read.csv(args[[1]], check.names = FALSE)
stopifnot(all(c("id", "period", "treat", "ps", "wt") %in% names(d)))
stopifnot(!anyNA(d[, c("period", "treat", "ps", "wt")]))

rows <- list()
add <- function(scope, metric, value) {
  rows[[length(rows) + 1L]] <<- data.frame(
    scope = scope, metric = metric,
    value = sprintf("%.17g", as.numeric(value)), stringsAsFactors = FALSE)
}
wmean <- function(x) as.numeric(cobalt::col_w_mean(matrix(x, ncol = 1)))
wsd <- function(x) as.numeric(cobalt::col_w_sd(matrix(x, ncol = 1)))
wrange <- function(sm) c(min(sm$weight.range$treated[1], sm$weight.range$control[1]),
                         max(sm$weight.range$treated[2], sm$weight.range$control[2]))

periods <- sort(unique(d$period))
for (p in periods) {
  s <- d[d$period == p, , drop = FALSE]
  sc <- paste0("p", p)
  w <- WeightIt::as.weightit(s$wt, treat = s$treat, covs = data.frame(ps = s$ps),
                             estimand = "ATE")
  sm <- summary(w)
  ess <- sm$effective.sample.size
  bt <- cobalt::bal.tab(treat ~ ps, data = s, weights = s$wt, continuous = "raw",
                        un = TRUE, disp.means = TRUE)
  b <- bt$Balance
  obs <- bt$Observations
  add(sc, "n", nrow(s))
  add(sc, "n_t", sum(s$treat == 1))
  add(sc, "n_c", sum(s$treat == 0))
  add(sc, "mean_t", b["ps", "M.1.Un"])
  add(sc, "mean_c", b["ps", "M.0.Un"])
  add(sc, "wt_mean", wmean(s$wt))
  add(sc, "wt_sd", wsd(s$wt))
  add(sc, "wt_max", wrange(sm)[2])
  add(sc, "ess_pct", 100 * WeightIt::ESS(s$wt) / nrow(s))
  add(sc, "ess_t_pct", 100 * ess["Weighted", "Treated"] / sum(s$treat == 1))
  add(sc, "ess_c_pct", 100 * ess["Weighted", "Control"] / sum(s$treat == 0))
  add(sc, "cb_ess_t_pct", 100 * obs["Adjusted", "Treated"] / sum(s$treat == 1))
  add(sc, "cb_ess_c_pct", 100 * obs["Adjusted", "Control"] / sum(s$treat == 0))
}

sc <- "all"
wa <- WeightIt::as.weightit(d$wt, treat = d$treat, covs = data.frame(ps = d$ps),
                            estimand = "ATE")
sa <- summary(wa)
q <- function(p) as.numeric(stats::quantile(d$wt, p, type = 2))
add(sc, "n", nrow(d))
add(sc, "n_periods", length(periods))
add(sc, "mean", wmean(d$wt))
add(sc, "sd", wsd(d$wt))
add(sc, "min", wrange(sa)[1])
add(sc, "max", wrange(sa)[2])
add(sc, "cv", wsd(d$wt) / wmean(d$wt))
add(sc, "ess", WeightIt::ESS(d$wt))
add(sc, "ess_pct", 100 * WeightIt::ESS(d$wt) / nrow(d))
for (k in c(1, 5, 50, 95, 99)) add(sc, paste0("p", k), q(k / 100))
add(sc, "n_extreme", sum(d$wt > 10))
add(sc, "pct_extreme", 100 * mean(d$wt > 10))

write.csv(do.call(rbind, rows), args[[2]], row.names = FALSE, quote = FALSE)
