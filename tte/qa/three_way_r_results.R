#!/usr/bin/env Rscript
# Generate R results for three-way cross-validation
# Runs emulate and TrialEmulation on the golden DGP dataset
# Outputs: data/three_way_r_results.csv

suppressPackageStartupMessages({
  library(emulate)
  library(data.table)
})

d <- fread("data/known_dgp_golden.csv")
cat("Golden DGP:", nrow(d), "rows,", length(unique(d$id)), "IDs\n")

results <- data.frame(
  impl = character(), estimand = character(),
  coef = numeric(), se = numeric(),
  stringsAsFactors = FALSE
)

# --- emulate ITT ---
obj <- suppressMessages(emulate_prepare(d, id = "id", period = "period",
                     treatment = "treatment", outcome = "outcome",
                     eligible = "eligible", covariates = "x", estimand = "ITT"))
obj <- suppressMessages(emulate_expand(obj, maxfollowup = 8))
obj <- suppressMessages(emulate_weight(obj))
obj <- suppressMessages(emulate_fit(obj, outcome_cov = "x"))
results <- rbind(results, data.frame(impl = "emulate", estimand = "ITT",
                                      coef = obj$model$b_treat,
                                      se = obj$model$se_treat))

# --- emulate PP ---
obj <- suppressMessages(emulate_prepare(d, id = "id", period = "period",
                     treatment = "treatment", outcome = "outcome",
                     eligible = "eligible", covariates = "x", estimand = "PP"))
obj <- suppressMessages(emulate_expand(obj, maxfollowup = 8))
obj <- suppressMessages(emulate_weight(obj, switch_d_cov = "x",
                                    truncate = c(1, 99), quiet = TRUE))
obj <- suppressMessages(emulate_fit(obj, outcome_cov = "x"))
results <- rbind(results, data.frame(impl = "emulate", estimand = "PP",
                                      coef = obj$model$b_treat,
                                      se = obj$model$se_treat))

# --- TrialEmulation ITT ---
if (requireNamespace("TrialEmulation", quietly = TRUE)) {
  te <- suppressWarnings(TrialEmulation::initiators(
    data.frame(d), id = "id", period = "period", treatment = "treatment",
    outcome = "outcome", eligible = "eligible", estimand_type = "ITT",
    outcome_cov = ~ x,
    include_followup_time = ~ followup_time + I(followup_time^2),
    include_trial_period = ~ trial_period + I(trial_period^2),
    model_var = "assigned_treatment", use_censor_weights = FALSE,
    data_dir = tempdir(), quiet = TRUE
  ))
  te_coefs <- te$robust$summary
  te_row <- te_coefs[te_coefs$names == "assigned_treatment", ]
  results <- rbind(results, data.frame(
    impl = "TrialEmulation", estimand = "ITT",
    coef = te_row$estimate, se = te_row$robust_se
  ))

  # --- TrialEmulation PP ---
  te_pp <- suppressWarnings(TrialEmulation::initiators(
    data.frame(d), id = "id", period = "period", treatment = "treatment",
    outcome = "outcome", eligible = "eligible", estimand_type = "PP",
    outcome_cov = ~ x, switch_d_cov = ~ x, switch_n_cov = ~ x,
    include_followup_time = ~ followup_time + I(followup_time^2),
    include_trial_period = ~ trial_period + I(trial_period^2),
    model_var = "assigned_treatment", use_censor_weights = FALSE,
    data_dir = tempdir(), quiet = TRUE
  ))
  te_pp_coefs <- te_pp$robust$summary
  te_pp_row <- te_pp_coefs[te_pp_coefs$names == "assigned_treatment", ]
  results <- rbind(results, data.frame(
    impl = "TrialEmulation", estimand = "PP",
    coef = te_pp_row$estimate, se = te_pp_row$robust_se
  ))
} else {
  cat("TrialEmulation not installed, skipping\n")
  results <- rbind(results, data.frame(impl = "TrialEmulation", estimand = "ITT",
                                        coef = NA, se = NA))
  results <- rbind(results, data.frame(impl = "TrialEmulation", estimand = "PP",
                                        coef = NA, se = NA))
}

write.csv(results, "data/three_way_r_results.csv", row.names = FALSE)
cat("\nResults:\n")
print(results)
cat("\nSaved to data/three_way_r_results.csv\n")
