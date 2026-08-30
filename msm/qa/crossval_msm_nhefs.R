#!/usr/bin/env Rscript
# Independent NHEFS point-treatment reference for crossval_msm_nhefs.do.

args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 2L) stop("usage: crossval_msm_nhefs.R input.dta output.dta")

suppressPackageStartupMessages(library(haven))
suppressPackageStartupMessages(library(ipw))
suppressPackageStartupMessages(library(sandwich))
suppressPackageStartupMessages(library(survey))

nhefs <- as.data.frame(read_dta(args[[1]]))
nhefs <- nhefs[!is.na(nhefs$wt82_71), ]
nhefs$age_sq <- nhefs$age^2
nhefs$smokeintensity_sq <- nhefs$smokeintensity^2
nhefs$smokeyrs_sq <- nhefs$smokeyrs^2
nhefs$wt71_sq <- nhefs$wt71^2

fit_w <- ipwpoint(
    exposure = qsmk,
    family = "binomial",
    link = "logit",
    numerator = ~1,
    denominator = ~sex + race + age + age_sq + smokeintensity +
        smokeintensity_sq + smokeyrs + smokeyrs_sq + exercise + active +
        wt71 + wt71_sq,
    data = nhefs
)
nhefs$r_weight <- fit_w$ipw.weights
if (any(!is.finite(nhefs$r_weight)) || any(nhefs$r_weight <= 0)) {
    stop("ipwpoint returned invalid weights")
}

fit_gain <- lm(wt82_71 ~ qsmk, data = nhefs, weights = r_weight)
r_gain <- unname(coef(fit_gain)["qsmk"])
r_gain_se <- sqrt(unname(vcovHC(fit_gain, type = "HC1")["qsmk", "qsmk"]))

death_design <- svydesign(ids = ~seqn, weights = ~r_weight, data = nhefs)
fit_death <- svyglm(death ~ qsmk, design = death_design,
                    family = quasibinomial(link = "logit"))
r_death_b <- unname(coef(fit_death)["qsmk"])
r_death_se <- sqrt(unname(vcov(fit_death)["qsmk", "qsmk"]))

nhefs$r_gain <- r_gain
nhefs$r_gain_se <- r_gain_se
nhefs$r_death_b <- r_death_b
nhefs$r_death_se <- r_death_se
nhefs$r_weight_mean <- mean(nhefs$r_weight)
nhefs$r_weight_sd <- sd(nhefs$r_weight)
nhefs$r_weight_min <- min(nhefs$r_weight)
nhefs$r_weight_max <- max(nhefs$r_weight)

write_dta(
    nhefs[, c("seqn", "r_weight", "r_gain", "r_gain_se", "r_death_b",
              "r_death_se", "r_weight_mean", "r_weight_sd", "r_weight_min",
              "r_weight_max")],
    args[[2]], version = 15
)
cat("NHEFS_REFERENCE_COMPLETE\n")
