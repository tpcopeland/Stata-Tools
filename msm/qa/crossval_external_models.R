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
    health <- health[, c("id", "period", "treatment", "outcome", "iq")]
    write.csv(health, file.path(target_dir, "external_health_lpm.csv"), row.names = FALSE)

    pbc <- survival::pbcseq
    pbc <- pbc[order(pbc$id, pbc$day), ]
    pbc <- pbc[complete.cases(pbc[, c("id", "trt", "age", "sex", "status")]), ]
    pbc$period <- ave(pbc$day, pbc$id, FUN = seq_along) - 1L
    pbc$last_period <- ave(pbc$period, pbc$id, FUN = max)
    pbc$outcome <- as.integer(pbc$status == 2 & pbc$period == pbc$last_period)
    pbc$treatment <- as.integer(pbc$trt == 1)
    pbc$age_dec <- pbc$age / 10
    pbc$female <- as.integer(pbc$sex == "f")
    pbc <- pbc[, c("id", "period", "treatment", "outcome", "age_dec", "female")]
    write.csv(pbc, file.path(target_dir, "external_pbcseq_cox.csv"), row.names = FALSE)
} else if (mode == "reference") {
    suppressPackageStartupMessages(library(survey))
    suppressPackageStartupMessages(library(survival))

    lpm <- read.csv(file.path(target_dir, "external_lpm_modeldata.csv"))
    lpm_design <- svydesign(ids = ~id, weights = ~weight, data = lpm)
    lpm_fit <- svyglm(outcome ~ treatment + iq, design = lpm_design)
    lpm_b <- coef(lpm_fit)[["treatment"]]
    lpm_se <- sqrt(vcov(lpm_fit)["treatment", "treatment"])

    cox <- read.csv(file.path(target_dir, "external_cox_modeldata.csv"))
    cox_fit <- coxph(
        Surv(period, period + 1, outcome) ~ treatment + age_dec + female + cluster(id),
        data = cox,
        ties = "breslow"
    )
    cox_b <- coef(cox_fit)[["treatment"]]
    cox_se <- sqrt(vcov(cox_fit)["treatment", "treatment"])

    results <- data.frame(
        model = c("lpm", "cox"),
        source = c("R_survey_svyglm", "R_survival_coxph"),
        coef = c(lpm_b, cox_b),
        se = c(lpm_se, cox_se),
        or_hr = c(NA_real_, exp(cox_b))
    )
    write.csv(results, file.path(target_dir, "external_r_results.csv"), row.names = FALSE)
} else {
    stop("unknown mode: ", mode)
}
