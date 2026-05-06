#!/usr/bin/env Rscript
# crossval_iivw_external_refs.R
#
# External reference generator for iivw package QA.
#
# Sources:
#   - survival::bladder2 recurrent bladder cancer data for IIW/Cox validation
#   - cobalt::lalonde + ipw::ipwpoint for point-treatment IPTW validation
#   - geepack::dietox + geepack::geeglm for FIPTIW-weighted outcome validation

suppressPackageStartupMessages({
    library(survival)
    library(ipw)
    library(cobalt)
    library(geepack)
})

args <- commandArgs(trailingOnly = FALSE)
file_arg <- grep("^--file=", args, value = TRUE)
if (length(file_arg) > 0) {
    this_file <- normalizePath(sub("^--file=", "", file_arg[1]),
        mustWork = TRUE)
    outdir <- dirname(this_file)
} else {
    outdir <- getwd()
}

write_ref <- function(x, filename) {
    write.csv(x, file.path(outdir, filename), row.names = FALSE,
        na = "")
}

expit <- function(x) 1 / (1 + exp(-x))

cat("crossval_iivw_external_refs.R\n")
cat("  output:", outdir, "\n")

# IIW reference: survival::bladder2

bladder <- survival::bladder2
bladder <- bladder[bladder$event == 1, ]
bladder <- bladder[order(bladder$id, bladder$stop), ]
bladder$n_visits <- ave(rep(1, nrow(bladder)), bladder$id, FUN = length)
bladder <- bladder[bladder$n_visits >= 2, ]
bladder <- bladder[order(bladder$id, bladder$stop), ]
bladder$rx2 <- as.integer(bladder$rx == 2)
bladder$time <- bladder$stop
bladder$time_lag <- ave(bladder$time, bladder$id,
    FUN = function(x) c(0, x[-length(x)]))
bladder$event_one <- 1L
bladder$visit_n <- ave(rep(1, nrow(bladder)), bladder$id, FUN = cumsum)

bladder_cox <- coxph(
    Surv(time_lag, time, event_one) ~ rx2 + number + size,
    data = bladder,
    ties = "efron"
)
bladder_se <- sqrt(diag(vcov(bladder_cox)))
bladder_lp <- predict(bladder_cox, newdata = bladder, type = "lp",
    reference = "zero")
bladder$r_iivw <- exp(-bladder_lp)
bladder$r_iivw[bladder$visit_n == 1] <- 1

write_ref(
    bladder[, c("id", "time", "time_lag", "event_one", "rx2",
                "number", "size", "visit_n", "r_iivw")],
    "crossval_iivw_external_bladder.csv"
)
write_ref(
    data.frame(
        rx2 = unname(coef(bladder_cox)[["rx2"]]),
        number = unname(coef(bladder_cox)[["number"]]),
        size = unname(coef(bladder_cox)[["size"]]),
        se_rx2 = unname(bladder_se[["rx2"]]),
        se_number = unname(bladder_se[["number"]]),
        se_size = unname(bladder_se[["size"]])
    ),
    "crossval_iivw_external_bladder_coefs.csv"
)

cat("  bladder:", nrow(bladder), "visits;",
    length(unique(bladder$id)), "subjects\n")

# IPTW reference: cobalt::lalonde + ipw::ipwpoint

lalonde <- cobalt::lalonde
lalonde$id <- seq_len(nrow(lalonde))
lalonde$time <- 0
lalonde$black <- as.integer(lalonde$race == "black")
lalonde$hispan <- as.integer(lalonde$race == "hispan")
lalonde$white <- as.integer(lalonde$race == "white")

lalonde_ipw <- ipwpoint(
    exposure = treat,
    family = "binomial",
    link = "logit",
    numerator = ~ 1,
    denominator = ~ age + educ + black + hispan + married +
        nodegree + re74 + re75,
    data = lalonde
)
lalonde$r_iptw <- lalonde_ipw$ipw.weights
lalonde_den_se <- sqrt(diag(vcov(lalonde_ipw$den.mod)))
lalonde_num_se <- sqrt(diag(vcov(lalonde_ipw$num.mod)))

write_ref(
    lalonde[, c("id", "time", "treat", "age", "educ", "black",
                "hispan", "white", "married", "nodegree", "re74",
                "re75", "re78", "r_iptw")],
    "crossval_iivw_external_lalonde.csv"
)
write_ref(
    data.frame(
        intercept = unname(coef(lalonde_ipw$den.mod)[["(Intercept)"]]),
        age = unname(coef(lalonde_ipw$den.mod)[["age"]]),
        educ = unname(coef(lalonde_ipw$den.mod)[["educ"]]),
        black = unname(coef(lalonde_ipw$den.mod)[["black"]]),
        hispan = unname(coef(lalonde_ipw$den.mod)[["hispan"]]),
        married = unname(coef(lalonde_ipw$den.mod)[["married"]]),
        nodegree = unname(coef(lalonde_ipw$den.mod)[["nodegree"]]),
        re74 = unname(coef(lalonde_ipw$den.mod)[["re74"]]),
        re75 = unname(coef(lalonde_ipw$den.mod)[["re75"]]),
        numerator_intercept =
            unname(coef(lalonde_ipw$num.mod)[["(Intercept)"]]),
        se_intercept = unname(lalonde_den_se[["(Intercept)"]]),
        se_age = unname(lalonde_den_se[["age"]]),
        se_educ = unname(lalonde_den_se[["educ"]]),
        se_black = unname(lalonde_den_se[["black"]]),
        se_hispan = unname(lalonde_den_se[["hispan"]]),
        se_married = unname(lalonde_den_se[["married"]]),
        se_nodegree = unname(lalonde_den_se[["nodegree"]]),
        se_re74 = unname(lalonde_den_se[["re74"]]),
        se_re75 = unname(lalonde_den_se[["re75"]]),
        se_numerator_intercept =
            unname(lalonde_num_se[["(Intercept)"]])
    ),
    "crossval_iivw_external_lalonde_coefs.csv"
)

cat("  lalonde:", nrow(lalonde), "subjects\n")

# FIPTIW/outcome reference: geepack::dietox

dietox <- geepack::dietox
dietox <- dietox[order(dietox$Pig, dietox$Time), ]
dietox$id <- as.integer(factor(dietox$Pig))
dietox$pen <- ceiling(dietox$id / 5)
dietox$time <- dietox$Time
dietox$feed0 <- ifelse(is.na(dietox$Feed), 0, dietox$Feed)
dietox$startwt <- dietox$Start
dietox$cu_high <- as.integer(dietox$Cu == "Cu175")
dietox$evit100 <- as.integer(dietox$Evit == "Evit100")
dietox$evit200 <- as.integer(dietox$Evit == "Evit200")
dietox$heavy <- as.integer(dietox$Weight > median(dietox$Weight,
    na.rm = TRUE))

# Create a reproducible irregular-observation subset from the weekly Dietox
# measurements so the visit-process component is non-degenerate while preserving
# the documented dataset as the source.
set.seed(20260506)
visit_lp <- -0.35 + 0.45 * dietox$cu_high +
    0.03 * (dietox$startwt - 25) +
    0.05 * (dietox$time - 6) +
    0.20 * dietox$evit200 -
    0.10 * dietox$evit100
dietox$visit_prob <- expit(visit_lp)
dietox$is_first <- ave(dietox$time, dietox$id,
    FUN = function(x) x == min(x)) == 1
dietox$is_last <- ave(dietox$time, dietox$id,
    FUN = function(x) x == max(x)) == 1
dietox$keep_visit <- dietox$is_first | dietox$is_last |
    runif(nrow(dietox)) < dietox$visit_prob
dietox <- dietox[dietox$keep_visit, ]
dietox <- dietox[order(dietox$id, dietox$time), ]
dietox$time_lag <- ave(dietox$time, dietox$id,
    FUN = function(x) c(0, x[-length(x)]))
dietox$event_one <- 1L
dietox$visit_n <- ave(rep(1, nrow(dietox)), dietox$id, FUN = cumsum)

dietox_num <- coxph(
    Surv(time_lag, time, event_one) ~ cu_high,
    data = dietox,
    ties = "efron"
)
dietox_den <- coxph(
    Surv(time_lag, time, event_one) ~ cu_high + startwt + evit100 + evit200,
    data = dietox,
    ties = "efron"
)
dietox_ps <- glm(
    cu_high ~ startwt + evit100 + evit200,
    data = dietox[!duplicated(dietox$id), ],
    family = binomial(link = "logit")
)

dietox_lp_num <- predict(dietox_num, newdata = dietox, type = "lp",
    reference = "zero")
dietox_lp_den <- predict(dietox_den, newdata = dietox, type = "lp",
    reference = "zero")
dietox$r_iiw <- exp(dietox_lp_num - dietox_lp_den)
dietox$r_iiw[dietox$visit_n == 1] <- 1

dietox_pr_treat <- mean(dietox$cu_high[!duplicated(dietox$id)])
dietox_ps_hat <- predict(dietox_ps, newdata = dietox, type = "response")
dietox$r_iptw <- ifelse(
    dietox$cu_high == 1,
    dietox_pr_treat / dietox_ps_hat,
    (1 - dietox_pr_treat) / (1 - dietox_ps_hat)
)
dietox$r_fiptiw <- dietox$r_iiw * dietox$r_iptw

dietox_gee <- geeglm(
    Weight ~ cu_high + feed0 + time,
    id = id,
    data = dietox,
    weights = r_fiptiw,
    family = gaussian(),
    corstr = "independence",
    std.err = "san.se"
)
dietox_gee_summary <- coef(summary(dietox_gee))
dietox_gee_pen <- geeglm(
    Weight ~ cu_high + feed0 + time,
    id = pen,
    data = dietox,
    weights = r_fiptiw,
    family = gaussian(),
    corstr = "independence",
    std.err = "san.se"
)
dietox_gee_pen_summary <- coef(summary(dietox_gee_pen))
dietox_gee_logit <- geeglm(
    heavy ~ cu_high + feed0 + time,
    id = id,
    data = dietox,
    weights = r_fiptiw,
    family = binomial(link = "logit"),
    corstr = "independence",
    std.err = "san.se"
)
dietox_gee_logit_summary <- coef(summary(dietox_gee_logit))

write_ref(
    dietox[, c("id", "pen", "time", "time_lag", "event_one", "Weight",
               "heavy",
               "feed0", "startwt", "cu_high", "evit100", "evit200",
               "visit_n", "r_iiw", "r_iptw", "r_fiptiw")],
    "crossval_iivw_external_dietox.csv"
)
write_ref(
    data.frame(
        num_cu_high = unname(coef(dietox_num)[["cu_high"]]),
        den_cu_high = unname(coef(dietox_den)[["cu_high"]]),
        den_startwt = unname(coef(dietox_den)[["startwt"]]),
        den_evit100 = unname(coef(dietox_den)[["evit100"]]),
        den_evit200 = unname(coef(dietox_den)[["evit200"]]),
        ps_intercept = unname(coef(dietox_ps)[["(Intercept)"]]),
        ps_startwt = unname(coef(dietox_ps)[["startwt"]]),
        ps_evit100 = unname(coef(dietox_ps)[["evit100"]]),
        ps_evit200 = unname(coef(dietox_ps)[["evit200"]]),
        pr_treat = dietox_pr_treat
    ),
    "crossval_iivw_external_dietox_weight_coefs.csv"
)
write_ref(
    data.frame(
        intercept = unname(coef(dietox_gee)[["(Intercept)"]]),
        cu_high = unname(coef(dietox_gee)[["cu_high"]]),
        feed0 = unname(coef(dietox_gee)[["feed0"]]),
        time = unname(coef(dietox_gee)[["time"]]),
        se_intercept = unname(dietox_gee_summary["(Intercept)", "Std.err"]),
        se_cu_high = unname(dietox_gee_summary["cu_high", "Std.err"]),
        se_feed0 = unname(dietox_gee_summary["feed0", "Std.err"]),
        se_time = unname(dietox_gee_summary["time", "Std.err"])
    ),
    "crossval_iivw_external_dietox_geeglm.csv"
)
write_ref(
    data.frame(
        intercept = unname(coef(dietox_gee_pen)[["(Intercept)"]]),
        cu_high = unname(coef(dietox_gee_pen)[["cu_high"]]),
        feed0 = unname(coef(dietox_gee_pen)[["feed0"]]),
        time = unname(coef(dietox_gee_pen)[["time"]]),
        se_intercept =
            unname(dietox_gee_pen_summary["(Intercept)", "Std.err"]),
        se_cu_high = unname(dietox_gee_pen_summary["cu_high", "Std.err"]),
        se_feed0 = unname(dietox_gee_pen_summary["feed0", "Std.err"]),
        se_time = unname(dietox_gee_pen_summary["time", "Std.err"])
    ),
    "crossval_iivw_external_dietox_geeglm_pen.csv"
)
write_ref(
    data.frame(
        intercept = unname(coef(dietox_gee_logit)[["(Intercept)"]]),
        cu_high = unname(coef(dietox_gee_logit)[["cu_high"]]),
        feed0 = unname(coef(dietox_gee_logit)[["feed0"]]),
        time = unname(coef(dietox_gee_logit)[["time"]]),
        se_intercept =
            unname(dietox_gee_logit_summary["(Intercept)", "Std.err"]),
        se_cu_high =
            unname(dietox_gee_logit_summary["cu_high", "Std.err"]),
        se_feed0 = unname(dietox_gee_logit_summary["feed0", "Std.err"]),
        se_time = unname(dietox_gee_logit_summary["time", "Std.err"])
    ),
    "crossval_iivw_external_dietox_geeglm_logit.csv"
)

cat("  dietox:", nrow(dietox), "visits;",
    length(unique(dietox$id)), "pigs\n")
cat("done\n")
