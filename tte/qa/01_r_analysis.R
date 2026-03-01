#!/usr/bin/env Rscript
# Cross-Validation: R TrialEmulation analysis
# Exports trial_example data and runs 4 configurations matching Stata tte
#
# Configs:
#   1: ITT, quadratic time, no weights
#   2: PP, quadratic time, stabilized IPTW
#   3: PP, quadratic time, stabilized + truncated (1st/99th pctile)
#   4: PP, ns(3) time, stabilized IPTW
#
# Usage: Rscript 01_r_analysis.R
#   (run from tte/qa/ directory, or from any location)
#
# Output: data/trial_example.csv, r_results/*.csv
#
# Requires: install.packages("TrialEmulation")

library(TrialEmulation)
library(splines)

# Paths — detect script location via commandArgs, fall back to working dir
args <- commandArgs(trailingOnly = FALSE)
script_arg <- sub("--file=", "", args[grep("--file=", args)])
if (length(script_arg) > 0) {
    base_dir <- dirname(normalizePath(script_arg))
} else {
    base_dir <- getwd()
}
data_dir <- file.path(base_dir, "data")
results_dir <- file.path(base_dir, "r_results")
dir.create(data_dir, showWarnings = FALSE, recursive = TRUE)
dir.create(results_dir, showWarnings = FALSE, recursive = TRUE)

# Use a temp dir for TrialEmulation's internal files
te_tempdir <- tempdir()

# =========================================================================
# EXPORT DATASET
# =========================================================================

cat("Loading trial_example dataset...\n")
data(trial_example)
cat(sprintf("  Dimensions: %d rows x %d columns\n", nrow(trial_example), ncol(trial_example)))
cat(sprintf("  Unique patients: %d\n", length(unique(trial_example$id))))
cat(sprintf("  Columns: %s\n", paste(names(trial_example), collapse = ", ")))

write.csv(trial_example, file.path(data_dir, "trial_example.csv"), row.names = FALSE)
cat("  Saved to data/trial_example.csv\n\n")

# Common settings
outcome_cov_formula <- ~ catvarA + catvarB + nvarA + nvarB + nvarC
predict_times <- 0:30

# =========================================================================
# CONFIG 1: ITT, quadratic, no weights
# =========================================================================

cat("Config 1: ITT, quadratic time, no weights\n")
cat("  Running initiators()...\n")

result1 <- initiators(
    data = trial_example,
    id = "id", period = "period", treatment = "treatment",
    outcome = "outcome", eligible = "eligible",
    estimand_type = "ITT",
    outcome_cov = outcome_cov_formula,
    include_followup_time = ~ followup_time + I(followup_time^2),
    include_trial_period = ~ trial_period + I(trial_period^2),
    data_dir = te_tempdir,
    quiet = TRUE
)

cat("  Coefficients:\n")
print(result1$robust$summary)

write.csv(result1$robust$summary,
    file.path(results_dir, "config1_itt_coefs.csv"), row.names = FALSE)

cat("  Computing predictions...\n")
set.seed(12345)
pred1 <- predict(result1, predict_times = predict_times, conf_int_type = "normal")

# Combine predictions into a single data frame
pred1_df <- data.frame(
    followup_time = pred1$assigned_treatment_0$followup_time,
    cum_inc_0 = pred1$assigned_treatment_0$cum_inc,
    cum_inc_0_lo = pred1$assigned_treatment_0[, 3],
    cum_inc_0_hi = pred1$assigned_treatment_0[, 4],
    cum_inc_1 = pred1$assigned_treatment_1$cum_inc,
    cum_inc_1_lo = pred1$assigned_treatment_1[, 3],
    cum_inc_1_hi = pred1$assigned_treatment_1[, 4],
    risk_diff = pred1$difference$cum_inc_diff,
    risk_diff_lo = pred1$difference[, 3],
    risk_diff_hi = pred1$difference[, 4]
)
write.csv(pred1_df, file.path(results_dir, "config1_itt_predictions.csv"),
    row.names = FALSE)
cat("  Saved config1_itt_coefs.csv and config1_itt_predictions.csv\n\n")

# =========================================================================
# CONFIG 2: PP, quadratic, stabilized IPTW
# =========================================================================

cat("Config 2: PP, quadratic time, stabilized IPTW\n")
cat("  Running initiators()...\n")

result2 <- initiators(
    data = trial_example,
    id = "id", period = "period", treatment = "treatment",
    outcome = "outcome", eligible = "eligible",
    estimand_type = "PP",
    outcome_cov = outcome_cov_formula,
    switch_n_cov = ~ nvarA + nvarB,
    switch_d_cov = ~ nvarA + nvarB,
    include_followup_time = ~ followup_time + I(followup_time^2),
    include_trial_period = ~ trial_period + I(trial_period^2),
    data_dir = te_tempdir,
    quiet = TRUE
)

cat("  Coefficients:\n")
print(result2$robust$summary)

write.csv(result2$robust$summary,
    file.path(results_dir, "config2_pp_coefs.csv"), row.names = FALSE)

cat("  Computing predictions...\n")
set.seed(12345)
pred2 <- predict(result2, predict_times = predict_times, conf_int_type = "normal")

pred2_df <- data.frame(
    followup_time = pred2$assigned_treatment_0$followup_time,
    cum_inc_0 = pred2$assigned_treatment_0$cum_inc,
    cum_inc_0_lo = pred2$assigned_treatment_0[, 3],
    cum_inc_0_hi = pred2$assigned_treatment_0[, 4],
    cum_inc_1 = pred2$assigned_treatment_1$cum_inc,
    cum_inc_1_lo = pred2$assigned_treatment_1[, 3],
    cum_inc_1_hi = pred2$assigned_treatment_1[, 4],
    risk_diff = pred2$difference$cum_inc_diff,
    risk_diff_lo = pred2$difference[, 3],
    risk_diff_hi = pred2$difference[, 4]
)
write.csv(pred2_df, file.path(results_dir, "config2_pp_predictions.csv"),
    row.names = FALSE)
cat("  Saved config2_pp_coefs.csv and config2_pp_predictions.csv\n\n")

# =========================================================================
# CONFIG 3: PP, quadratic, stabilized + truncated (1st/99th)
# =========================================================================

cat("Config 3: PP, quadratic time, stabilized + truncated at 1st/99th pctile\n")
cat("  Running initiators() with p99 truncation...\n")

result3 <- initiators(
    data = trial_example,
    id = "id", period = "period", treatment = "treatment",
    outcome = "outcome", eligible = "eligible",
    estimand_type = "PP",
    outcome_cov = outcome_cov_formula,
    switch_n_cov = ~ nvarA + nvarB,
    switch_d_cov = ~ nvarA + nvarB,
    include_followup_time = ~ followup_time + I(followup_time^2),
    include_trial_period = ~ trial_period + I(trial_period^2),
    analysis_weights = "p99",
    data_dir = te_tempdir,
    quiet = TRUE
)

cat("  Coefficients:\n")
print(result3$robust$summary)

write.csv(result3$robust$summary,
    file.path(results_dir, "config3_pp_trunc_coefs.csv"), row.names = FALSE)

cat("  Computing predictions...\n")
set.seed(12345)
pred3 <- predict(result3, predict_times = predict_times, conf_int_type = "normal")

pred3_df <- data.frame(
    followup_time = pred3$assigned_treatment_0$followup_time,
    cum_inc_0 = pred3$assigned_treatment_0$cum_inc,
    cum_inc_0_lo = pred3$assigned_treatment_0[, 3],
    cum_inc_0_hi = pred3$assigned_treatment_0[, 4],
    cum_inc_1 = pred3$assigned_treatment_1$cum_inc,
    cum_inc_1_lo = pred3$assigned_treatment_1[, 3],
    cum_inc_1_hi = pred3$assigned_treatment_1[, 4],
    risk_diff = pred3$difference$cum_inc_diff,
    risk_diff_lo = pred3$difference[, 3],
    risk_diff_hi = pred3$difference[, 4]
)
write.csv(pred3_df, file.path(results_dir, "config3_pp_trunc_predictions.csv"),
    row.names = FALSE)
cat("  Saved config3_pp_trunc_coefs.csv and config3_pp_trunc_predictions.csv\n\n")

# =========================================================================
# CONFIG 4: PP, natural splines ns(3), stabilized IPTW
# =========================================================================

cat("Config 4: PP, ns(3) time, stabilized IPTW\n")
cat("  Running initiators()...\n")

result4 <- initiators(
    data = trial_example,
    id = "id", period = "period", treatment = "treatment",
    outcome = "outcome", eligible = "eligible",
    estimand_type = "PP",
    outcome_cov = outcome_cov_formula,
    switch_n_cov = ~ nvarA + nvarB,
    switch_d_cov = ~ nvarA + nvarB,
    include_followup_time = ~ splines::ns(followup_time, df = 3),
    include_trial_period = ~ splines::ns(trial_period, df = 3),
    data_dir = te_tempdir,
    quiet = TRUE
)

cat("  Coefficients:\n")
print(result4$robust$summary)

write.csv(result4$robust$summary,
    file.path(results_dir, "config4_pp_ns_coefs.csv"), row.names = FALSE)

cat("  Computing predictions...\n")
set.seed(12345)
pred4 <- predict(result4, predict_times = predict_times, conf_int_type = "normal")

pred4_df <- data.frame(
    followup_time = pred4$assigned_treatment_0$followup_time,
    cum_inc_0 = pred4$assigned_treatment_0$cum_inc,
    cum_inc_0_lo = pred4$assigned_treatment_0[, 3],
    cum_inc_0_hi = pred4$assigned_treatment_0[, 4],
    cum_inc_1 = pred4$assigned_treatment_1$cum_inc,
    cum_inc_1_lo = pred4$assigned_treatment_1[, 3],
    cum_inc_1_hi = pred4$assigned_treatment_1[, 4],
    risk_diff = pred4$difference$cum_inc_diff,
    risk_diff_lo = pred4$difference[, 4],
    risk_diff_hi = pred4$difference[, 3]
)
write.csv(pred4_df, file.path(results_dir, "config4_pp_ns_predictions.csv"),
    row.names = FALSE)
cat("  Saved config4_pp_ns_coefs.csv and config4_pp_ns_predictions.csv\n\n")

# =========================================================================
# SUMMARY
# =========================================================================

cat("=======================================================================\n")
cat("R Analysis Complete\n")
cat("=======================================================================\n")
cat("\nTreatment coefficient comparison:\n")
cat(sprintf("  Config 1 (ITT):       %9.6f  (SE: %9.6f)\n",
    result1$robust$summary$estimate[2], result1$robust$summary$robust_se[2]))
cat(sprintf("  Config 2 (PP):        %9.6f  (SE: %9.6f)\n",
    result2$robust$summary$estimate[2], result2$robust$summary$robust_se[2]))
cat(sprintf("  Config 3 (PP trunc):  %9.6f  (SE: %9.6f)\n",
    result3$robust$summary$estimate[2], result3$robust$summary$robust_se[2]))
cat(sprintf("  Config 4 (PP ns):     %9.6f  (SE: %9.6f)\n",
    result4$robust$summary$estimate[2], result4$robust$summary$robust_se[2]))

cat("\nRisk difference at followup=10:\n")
cat(sprintf("  Config 1 (ITT):       %9.6f\n", pred1_df$risk_diff[pred1_df$followup_time == 10]))
cat(sprintf("  Config 2 (PP):        %9.6f\n", pred2_df$risk_diff[pred2_df$followup_time == 10]))
cat(sprintf("  Config 3 (PP trunc):  %9.6f\n", pred3_df$risk_diff[pred3_df$followup_time == 10]))
cat(sprintf("  Config 4 (PP ns):     %9.6f\n", pred4_df$risk_diff[pred4_df$followup_time == 10]))

cat("\nFiles saved:\n")
cat(paste("  ", list.files(results_dir), collapse = "\n"), "\n")
