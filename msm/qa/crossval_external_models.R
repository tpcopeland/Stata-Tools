#!/usr/bin/env Rscript
# External-dataset model references for msm QA.

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 2) {
    stop("usage: crossval_external_models.R generate DATA_DIR | reference RESULTS_DIR")
}

mode <- args[[1]]
target_dir <- normalizePath(args[[2]], mustWork = FALSE)
dir.create(target_dir, recursive = TRUE, showWarnings = FALSE)

if (mode == "generate") {
    suppressPackageStartupMessages(library(ipw))
    suppressPackageStartupMessages(library(survival))

    data(healthdat, package = "ipw")
    health <- healthdat
    health$treatment <- as.integer(health$income >= stats::median(health$income, na.rm = TRUE))
    health$outcome <- as.integer(health$health >= stats::median(health$health, na.rm = TRUE))
    health$period <- 0L
    health$iq <- as.numeric(scale(health$iq))
    health$iqgrp <- as.integer(cut(
        health$iq,
        breaks = stats::quantile(health$iq, probs = seq(0, 1, 0.25), na.rm = TRUE),
        include.lowest = TRUE,
        labels = FALSE
    ))
    health <- health[, c("id", "period", "treatment", "outcome", "iq", "iqgrp")]
    write.csv(health, file.path(target_dir, "external_health_lpm.csv"), row.names = FALSE)

    pbc <- survival::pbcseq
    pbc <- pbc[order(pbc$id, pbc$day), ]
    pbc <- pbc[complete.cases(pbc[, c("id", "trt", "age", "sex", "status", "stage")]), ]
    pbc$period <- ave(pbc$day, pbc$id, FUN = seq_along) - 1L
    pbc$last_period <- ave(pbc$period, pbc$id, FUN = max)
    pbc$outcome <- as.integer(pbc$status == 2 & pbc$period == pbc$last_period)
    pbc$treatment <- as.integer(pbc$trt == 1)
    pbc$age_dec <- pbc$age / 10
    pbc$female <- as.integer(pbc$sex == "f")
    pbc$stage_bl <- ave(pbc$stage, pbc$id, FUN = function(x) x[1])
    pbc <- pbc[, c("id", "period", "treatment", "outcome", "age_dec", "female", "stage_bl")]
    write.csv(pbc, file.path(target_dir, "external_pbcseq_cox.csv"), row.names = FALSE)
} else if (mode == "reference") {
    suppressPackageStartupMessages(library(sandwich))
    suppressPackageStartupMessages(library(survival))

    lpm <- read.csv(file.path(target_dir, "external_lpm_modeldata.csv"))
    lpm_fit <- lm(outcome ~ treatment + iq, data = lpm, weights = weight)
    lpm_b <- coef(lpm_fit)[["treatment"]]
    lpm_robust_se <- sqrt(vcovHC(lpm_fit, type = "HC1")["treatment", "treatment"])
    lpm_cluster_se <- sqrt(vcovCL(lpm_fit, cluster = ~iqgrp, type = "HC1")["treatment", "treatment"])

    logit_fit <- glm(
        outcome ~ treatment + iq,
        data = lpm,
        weights = weight,
        family = quasibinomial(link = "logit")
    )
    logit_b <- coef(logit_fit)[["treatment"]]
    logit_n <- stats::nobs(logit_fit)
    logit_robust_vcov <- vcovHC(logit_fit, type = "HC0") * (logit_n / (logit_n - 1))
    logit_robust_se <- sqrt(logit_robust_vcov["treatment", "treatment"])
    logit_cluster_se <- sqrt(
        vcovCL(logit_fit, cluster = ~iqgrp, type = "HC0", cadjust = TRUE)["treatment", "treatment"]
    )

    cox <- read.csv(file.path(target_dir, "external_cox_modeldata.csv"))
    cox_fit <- coxph(
        Surv(period, period + 1, outcome) ~ treatment + age_dec + female + cluster(id),
        data = cox,
        ties = "breslow"
    )
    cox_b <- coef(cox_fit)[["treatment"]]
    cox_g <- length(unique(cox$id))
    cox_se <- sqrt(vcov(cox_fit)["treatment", "treatment"] * cox_g / (cox_g - 1))

    cox_strata_fit <- coxph(
        Surv(period, period + 1, outcome) ~ treatment + age_dec + strata(stage_bl) + cluster(id),
        data = cox,
        ties = "breslow"
    )
    cox_strata_b <- coef(cox_strata_fit)[["treatment"]]
    cox_strata_se <- sqrt(vcov(cox_strata_fit)["treatment", "treatment"] * cox_g / (cox_g - 1))

    results <- data.frame(
        model = c("lpm_robust", "lpm_cluster", "logit_robust", "logit_cluster",
                  "cox_cluster", "cox_strata_cluster"),
        source = c("R_lm_HC1", "R_lm_vcovCL", "R_glm_HC0_stata_adj", "R_glm_vcovCL_HC0",
                   "R_survival_coxph_cadj", "R_survival_coxph_strata_cadj"),
        coef = c(lpm_b, lpm_b, logit_b, logit_b, cox_b, cox_strata_b),
        se = c(lpm_robust_se, lpm_cluster_se, logit_robust_se, logit_cluster_se,
               cox_se, cox_strata_se),
        or_hr = c(NA_real_, NA_real_, exp(logit_b), exp(logit_b),
                  exp(cox_b), exp(cox_strata_b))
    )
    write.csv(results, file.path(target_dir, "external_r_results.csv"), row.names = FALSE)
} else {
    stop("unknown mode: ", mode)
}
