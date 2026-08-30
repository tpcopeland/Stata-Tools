#!/usr/bin/env Rscript
# crossval_iivw_pbcseq.R
#
# Independent R reference for the Mayo Clinic PBC sequential data shipped with
# survival. The data are naturally irregular: protocol visits were supplemented
# by extra visits when patients worsened, and follow-up ends at a subject-specific
# death, transplant, or administrative-censoring time.
# Source: https://stat.ethz.ch/R-manual/R-devel/library/survival/html/pbcseq.html
#
# Writes, under --outdir=PATH:
#   pbcseq_data.csv       observed study rows consumed by Stata
#   pbcseq_cox.csv        denominator visit-intensity coefficients/counts
#   pbcseq_weights.csv    raw and mean-one stabilized IIW on modeled visits
#   pbcseq_exog.csv       clustered lagged-outcome Cox coefficient and SE
#   pbcseq_geeglm.csv     weighted quadratic-time GEE coefficients and robust SEs
#   pbcseq_versions.csv   exact R/package versions used for the oracle
#   pbcseq.ok             completion sentinel, written last

suppressPackageStartupMessages({
    library(survival)
    library(geepack)
})

args <- commandArgs(trailingOnly = FALSE)
outdir_arg <- grep("^--outdir=", args, value = TRUE)
if (length(outdir_arg) != 1L) {
    stop("crossval_iivw_pbcseq.R requires exactly one --outdir=PATH argument")
}
outdir <- sub("^--outdir=", "", outdir_arg)
if (!dir.exists(outdir)) {
    dir.create(outdir, recursive = TRUE)
}
outdir <- normalizePath(outdir, mustWork = TRUE)

write_ref <- function(x, filename) {
    write.csv(x, file.path(outdir, filename), row.names = FALSE, na = "")
}

cat("crossval_iivw_pbcseq.R\n")
cat("  output:", outdir, "\n")

# The first 312 PBC patients were randomized. survival::pbcseq contains their
# repeated laboratory measurements and follow-up endpoint. Restrict only on the
# variables used by this oracle, retain subjects with at least three visits, and
# scale days to years before creating the counting-process representation.
d <- survival::pbcseq
d <- d[
    !is.na(d$trt) &
    complete.cases(d[, c("id", "futime", "age", "sex", "day",
                          "bili", "albumin")]) &
    d$day <= d$futime,
]
nvisit <- table(d$id)
d <- d[d$id %in% as.integer(names(nvisit[nvisit >= 3L])), ]
d <- d[order(d$id, d$day), ]

d$time <- d$day / 365.25
d$censor_time <- d$futime / 365.25
d$sex_f <- as.integer(d$sex == "f")
d$logbili <- log(d$bili)
d$event <- 1L

stopifnot(!anyDuplicated(d[, c("id", "time")]))
stopifnot(all(ave(d$time, d$id, FUN = function(x) x[1]) == 0))
stopifnot(all(d$censor_time >= d$time))

# Build the exact risk set used by iivw_weight, censor() baseline(entry): append
# one terminal event-0 interval per subject, create lags after that append, and
# remove the time-zero study-entry row from the visit-intensity fit.
last <- !duplicated(d$id, fromLast = TRUE)
cens <- d[last & d$censor_time > d$time, ]
cens$time <- cens$censor_time
cens$event <- 0L

dc <- rbind(d, cens)
dc <- dc[order(dc$id, dc$time, dc$event), ]
dc$start <- ave(dc$time, dc$id, FUN = function(x) c(0, x[-length(x)]))
dc$logbili_lag <- ave(dc$logbili, dc$id,
    FUN = function(x) c(NA_real_, x[-length(x)]))
dc <- dc[ave(seq_len(nrow(dc)), dc$id, FUN = seq_along) > 1L, ]

den_fit <- coxph(
    Surv(start, time, event) ~ trt + age + sex_f + logbili_lag,
    data = dc,
    ties = "efron"
)
num_fit <- coxph(
    Surv(start, time, event) ~ trt + age + sex_f,
    data = dc,
    ties = "efron"
)
exog_fit <- coxph(
    Surv(start, time, event) ~ logbili_lag + trt + age + sex_f + cluster(id),
    data = dc,
    ties = "efron"
)

# Evaluate both rate models only at observed, modeled visits. reference="zero"
# is load-bearing: Stata's predict, xb is uncentered. iivw then divides these raw
# weights by their mean over modeled events and restores study-entry rows at 1.
obs <- dc[dc$event == 1L, ]
obs$lp_den <- as.numeric(predict(
    den_fit, newdata = obs, type = "lp", reference = "zero"))
obs$lp_num <- as.numeric(predict(
    num_fit, newdata = obs, type = "lp", reference = "zero"))
obs$raw_weight <- exp(obs$lp_num - obs$lp_den)
obs$norm_weight <- obs$raw_weight / mean(obs$raw_weight)

d$r_weight <- 1
key_d <- paste(d$id, format(d$time, digits = 17), sep = "|")
key_obs <- paste(obs$id, format(obs$time, digits = 17), sep = "|")
idx <- match(key_d, key_obs)
d$r_weight[!is.na(idx)] <- obs$norm_weight[idx[!is.na(idx)]]
stopifnot(sum(!is.na(idx)) == nrow(obs))

gee_fit <- geeglm(
    logbili ~ trt + age + sex_f + albumin + time + I(time^2),
    id = id,
    data = d,
    weights = r_weight,
    family = gaussian(),
    corstr = "independence",
    std.err = "san.se"
)
gee_tab <- coef(summary(gee_fit))

write_ref(
    d[, c("id", "time", "censor_time", "trt", "age", "sex_f",
          "logbili", "albumin")],
    "pbcseq_data.csv"
)
write_ref(
    data.frame(
        term = names(coef(den_fit)),
        estimate = unname(coef(den_fit)),
        n = den_fit$n,
        nevent = den_fit$nevent,
        ncensor = sum(dc$event == 0L)
    ),
    "pbcseq_cox.csv"
)
write_ref(
    obs[, c("id", "time", "raw_weight", "norm_weight")],
    "pbcseq_weights.csv"
)
write_ref(
    data.frame(
        estimate = unname(coef(exog_fit)[["logbili_lag"]]),
        se_r = unname(sqrt(diag(vcov(exog_fit)))[["logbili_lag"]]),
        se_stata_fsc = unname(sqrt(diag(vcov(exog_fit)))[["logbili_lag"]]) *
            sqrt(length(unique(dc$id)) / (length(unique(dc$id)) - 1)),
        n = exog_fit$n,
        nevent = exog_fit$nevent
    ),
    "pbcseq_exog.csv"
)
write_ref(
    data.frame(
        term = rownames(gee_tab),
        estimate = gee_tab[, "Estimate"],
        se = gee_tab[, "Std.err"]
    ),
    "pbcseq_geeglm.csv"
)
write_ref(
    data.frame(
        package = c("R", "survival", "geepack"),
        version = c(
            paste(R.version$major, R.version$minor, sep = "."),
            as.character(packageVersion("survival")),
            as.character(packageVersion("geepack"))
        )
    ),
    "pbcseq_versions.csv"
)

cat("  observed rows:", nrow(d), "\n")
cat("  subjects:", length(unique(d$id)), "\n")
cat("  modeled visits:", nrow(obs), "\n")
cat("  censoring rows:", sum(dc$event == 0L), "\n")
writeLines("ok", file.path(outdir, "pbcseq.ok"))
