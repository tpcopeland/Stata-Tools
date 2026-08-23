#!/usr/bin/env Rscript
# Exact one-period IPTW reference for crossval_msm_ipw_dta.do.

args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 2L) stop("usage: crossval_msm_ipw_dta.R input.dta output.dta")

suppressPackageStartupMessages(library(haven))
suppressPackageStartupMessages(library(ipw))
suppressPackageStartupMessages(library(sandwich))

input <- as.data.frame(read_dta(args[[1]]))
needed <- c("id", "outcome", "treatment", "x1", "x2", "stata_weight")
if (!all(needed %in% names(input))) stop("exchange dataset has missing columns")
if (anyNA(input[needed])) stop("exchange dataset contains missing values")
input$treatment <- as.integer(input$treatment)
input$outcome <- as.integer(input$outcome)

fit_w <- ipwpoint(
    exposure = treatment,
    family = "binomial",
    link = "logit",
    numerator = ~1,
    denominator = ~x1 + x2,
    data = input
)
weight <- fit_w$ipw.weights
if (length(weight) != nrow(input) || any(!is.finite(weight)) || any(weight <= 0)) {
    stop("ipwpoint did not return finite positive weights")
}

fit_y <- lm(outcome ~ treatment, data = input, weights = weight)
r_b <- unname(coef(fit_y)["treatment"])
r_se <- sqrt(unname(vcovHC(fit_y, type = "HC1")["treatment", "treatment"]))
if (!is.finite(r_b) || !is.finite(r_se) || r_se <= 0) stop("non-finite outcome estimate")

write_dta(data.frame(
    r_b = r_b,
    r_se = r_se,
    max_abs_weight_diff = max(abs(input$stata_weight - weight))
), args[[2]], version = 15)
