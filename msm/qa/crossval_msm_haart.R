#!/usr/bin/env Rscript
# Independent HAART longitudinal reference for crossval_msm_haart.do.

args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 2L) stop("usage: crossval_msm_haart.R input.dta output.dta")

suppressPackageStartupMessages(library(haven))
suppressPackageStartupMessages(library(ipw))
suppressPackageStartupMessages(library(survival))

observed_probability <- function(probability, value) {
    ifelse(value == 1, probability, 1 - probability)
}

cumprod_by_id <- function(factor, id) {
    unsplit(lapply(split(factor, id), cumprod), id)
}

haart <- as.data.frame(read_dta(args[[1]]))
haart <- haart[order(haart$patient, haart$tstart), ]
haart$period <- ave(haart$tstart, haart$patient, FUN = seq_along) - 1L
haart$treatment <- as.integer(haart$haartind)
haart$outcome <- as.integer(haart$event)
haart$censor <- as.integer(haart$dropout)
haart$lag_treatment <- ave(haart$treatment, haart$patient,
                           FUN = function(x) c(NA_integer_, head(x, -1)))
haart$first <- ave(haart$period, haart$patient, FUN = seq_along) == 1L
haart$prior_outcome <- ave(haart$outcome, haart$patient,
                           FUN = function(x) cumsum(c(0L, head(x, -1))))
haart$prior_censor <- ave(haart$censor, haart$patient,
                          FUN = function(x) cumsum(c(0L, head(x, -1))))
haart$at_risk <- haart$prior_outcome == 0L & haart$prior_censor == 0L

# Package-aligned pooled-logistic treatment probabilities. The first decision
# is fitted separately; later decisions include prior treatment and linear time.
first_risk <- haart$at_risk & haart$first
later_risk <- haart$at_risk & !haart$first
fit_td0 <- glm(treatment ~ cd4_sqrt + sex + age, data = haart,
               subset = first_risk, family = binomial())
fit_tn0 <- glm(treatment ~ sex + age, data = haart,
               subset = first_risk, family = binomial())
fit_td <- glm(treatment ~ lag_treatment + cd4_sqrt + sex + age + period,
              data = haart, subset = later_risk, family = binomial())
fit_tn <- glm(treatment ~ lag_treatment + sex + age + period,
              data = haart, subset = later_risk, family = binomial())

haart$treat_den <- NA_real_
haart$treat_num <- NA_real_
haart$treat_den[first_risk] <- predict(fit_td0, newdata = haart[first_risk, ],
                                       type = "response")
haart$treat_num[first_risk] <- predict(fit_tn0, newdata = haart[first_risk, ],
                                       type = "response")
haart$treat_den[later_risk] <- predict(fit_td, newdata = haart[later_risk, ],
                                       type = "response")
haart$treat_num[later_risk] <- predict(fit_tn, newdata = haart[later_risk, ],
                                       type = "response")

clip <- 0.001
haart$treat_den <- pmin(pmax(haart$treat_den, clip), 1 - clip)
haart$treat_num <- pmin(pmax(haart$treat_num, clip), 1 - clip)
haart$tw_factor <- 1
haart$tw_factor[haart$at_risk] <- observed_probability(
    haart$treat_num[haart$at_risk], haart$treatment[haart$at_risk]
) / observed_probability(
    haart$treat_den[haart$at_risk], haart$treatment[haart$at_risk]
)
haart$r_tw_weight <- cumprod_by_id(haart$tw_factor, haart$patient)

# Package-aligned censoring models use all rows alive and uncensored through
# the previous interval and include current treatment plus linear time.
fit_cd <- glm(censor ~ treatment + cd4_sqrt + sex + age + period,
              data = haart, subset = haart$at_risk, family = binomial())
fit_cn <- glm(censor ~ treatment + sex + age + period,
              data = haart, subset = haart$at_risk, family = binomial())
haart$cens_den <- NA_real_
haart$cens_num <- NA_real_
haart$cens_den[haart$at_risk] <- predict(fit_cd, newdata = haart[haart$at_risk, ],
                                         type = "response")
haart$cens_num[haart$at_risk] <- predict(fit_cn, newdata = haart[haart$at_risk, ],
                                         type = "response")
haart$cens_den <- pmin(pmax(haart$cens_den, clip), 1 - clip)
haart$cens_num <- pmin(pmax(haart$cens_num, clip), 1 - clip)
haart$cw_factor <- 1
haart$cw_factor[haart$at_risk] <- (1 - haart$cens_num[haart$at_risk]) /
    (1 - haart$cens_den[haart$at_risk])
haart$r_cw_weight <- cumprod_by_id(haart$cw_factor, haart$patient)
haart$r_weight <- haart$r_tw_weight * haart$r_cw_weight

aligned_sample <- haart$at_risk & haart$censor == 0L
aligned_fit <- coxph(
    Surv(period, period + 1, outcome) ~ treatment + sex + age + cluster(patient),
    data = haart, subset = aligned_sample, weights = r_weight, ties = "breslow"
)
aligned_b <- unname(coef(aligned_fit)["treatment"])
aligned_g <- length(unique(haart$patient[aligned_sample]))
aligned_se <- sqrt(unname(vcov(aligned_fit)["treatment", "treatment"] *
                          aligned_g / (aligned_g - 1)))

# Published JSS Section 4.2 reference: survival-family initiation and dropout
# weights, followed by the weighted marginal structural Cox model.
paper_tw <- ipwtm(
    exposure = haartind, family = "survival",
    numerator = ~sex + age, denominator = ~cd4_sqrt + sex + age,
    id = patient, tstart = tstart, timevar = fuptime, type = "first",
    data = haart
)
paper_cw <- ipwtm(
    exposure = dropout, family = "survival",
    numerator = ~sex + age, denominator = ~cd4_sqrt + sex + age,
    id = patient, tstart = tstart, timevar = fuptime, type = "first",
    data = haart
)
paper_fit <- coxph(
    Surv(tstart, fuptime, event) ~ haartind + cluster(patient),
    data = haart, weights = paper_tw$ipw.weights * paper_cw$ipw.weights
)
paper_b <- unname(coef(paper_fit)["haartind"])
paper_se <- sqrt(unname(vcov(paper_fit)["haartind", "haartind"]))

haart$aligned_b <- aligned_b
haart$aligned_se <- aligned_se
haart$paper_treat_mean <- mean(paper_tw$ipw.weights)
haart$paper_treat_max <- max(paper_tw$ipw.weights)
haart$paper_b <- paper_b
haart$paper_se <- paper_se
haart$paper_hr <- exp(paper_b)

write_dta(
    haart[, c("patient", "tstart", "r_tw_weight", "r_cw_weight", "r_weight",
              "aligned_b", "aligned_se", "paper_treat_mean", "paper_treat_max",
              "paper_b", "paper_se", "paper_hr")],
    args[[2]], version = 15
)
cat("HAART_REFERENCE_COMPLETE\n")
