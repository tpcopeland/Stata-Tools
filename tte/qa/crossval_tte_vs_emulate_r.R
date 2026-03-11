#!/usr/bin/env Rscript
# =============================================================================
# Cross-Validation: R emulate vs Stata tte
# Part 1: Generate datasets + Run all R (emulate) configurations
#
# Produces:
#   crossval_data/    - Shared datasets (CSV) for both R and Stata
#   crossval_results/ - R emulate results (CSV) for comparison
#
# 6 Datasets x multiple configs each = ~25 configurations total
# =============================================================================

suppressPackageStartupMessages({
  library(emulate)
  library(data.table)
})

cat(strrep("=", 72), "\n")
cat("Cross-Validation: R emulate v", as.character(packageVersion("emulate")), "\n")
cat("Date:", format(Sys.time()), "\n")
cat(strrep("=", 72), "\n\n")

qa_dir      <- normalizePath("~/Stata-Tools/tte/qa")
data_dir    <- file.path(qa_dir, "crossval_data")
results_dir <- file.path(qa_dir, "crossval_results")
dir.create(data_dir, showWarnings = FALSE, recursive = TRUE)
dir.create(results_dir, showWarnings = FALSE, recursive = TRUE)

# =============================================================================
# Results collector
# =============================================================================
all_results <- data.frame(
  dataset    = character(),
  config     = character(),
  metric     = character(),
  value      = numeric(),
  stringsAsFactors = FALSE
)

add_result <- function(dataset, config, metric, value) {
  all_results <<- rbind(all_results, data.frame(
    dataset = dataset, config = config, metric = metric,
    value = as.numeric(value), stringsAsFactors = FALSE
  ))
}

# Helper: run a full pipeline and extract results
run_config <- function(dataset_name, config_name, data, id_col, period_col,
                       treatment_col, outcome_col, eligible_col,
                       censor_col = NULL,
                       covariates = NULL, baseline_covariates = NULL,
                       estimand = "ITT",
                       maxfollowup = 0, grace = 0,
                       switch_d_cov = NULL, switch_n_cov = NULL,
                       censor_d_cov = NULL, censor_n_cov = NULL,
                       pool_switch = FALSE, pool_censor = FALSE,
                       truncate = NULL,
                       outcome_cov = NULL,
                       model = "logistic",
                       followup_spec = "quadratic",
                       trial_period_spec = "quadratic",
                       pred_times = NULL,
                       pred_type = "cum_inc",
                       pred_seed = 54321,
                       pred_samples = 200) {

  cat(sprintf("  [%s] %s ... ", dataset_name, config_name))
  t0 <- proc.time()

  tryCatch({
    # Prepare
    obj <- suppressMessages(emulate_prepare(
      data, id = id_col, period = period_col,
      treatment = treatment_col, outcome = outcome_col,
      eligible = eligible_col, censor = censor_col,
      covariates = covariates, baseline_covariates = baseline_covariates,
      estimand = estimand
    ))

    # Expand
    expand_args <- list(obj = obj)
    if (maxfollowup > 0) expand_args$maxfollowup <- maxfollowup
    if (grace > 0) expand_args$grace <- grace
    obj <- suppressMessages(do.call(emulate_expand, expand_args))

    n_expanded <- nrow(obj$data)
    n_trials   <- obj$expansion$n_trials
    add_result(dataset_name, config_name, "n_expanded", n_expanded)
    add_result(dataset_name, config_name, "n_trials", n_trials)

    # Weight
    if (estimand %in% c("PP", "AT") && !is.null(switch_d_cov)) {
      obj <- suppressMessages(emulate_weight(
        obj,
        switch_d_cov = switch_d_cov,
        switch_n_cov = switch_n_cov,
        censor_d_cov = censor_d_cov,
        censor_n_cov = censor_n_cov,
        pool_switch = pool_switch,
        pool_censor = pool_censor,
        truncate = truncate,
        quiet = TRUE
      ))

      add_result(dataset_name, config_name, "w_mean", obj$weights$mean)
      add_result(dataset_name, config_name, "w_sd", obj$weights$sd)
      add_result(dataset_name, config_name, "w_min", obj$weights$min)
      add_result(dataset_name, config_name, "w_max", obj$weights$max)
      add_result(dataset_name, config_name, "w_ess", obj$weights$ess)
      add_result(dataset_name, config_name, "w_n_truncated", obj$weights$n_truncated)
    } else {
      obj <- suppressMessages(emulate_weight(obj))
    }

    # Fit
    obj <- suppressMessages(emulate_fit(
      obj,
      outcome_cov = outcome_cov,
      model = model,
      followup_spec = followup_spec,
      trial_period_spec = trial_period_spec
    ))

    b  <- obj$model$b_treat
    se <- obj$model$se_treat
    add_result(dataset_name, config_name, "coef", b)
    add_result(dataset_name, config_name, "se", se)
    add_result(dataset_name, config_name, "or_hr", exp(b))

    # Predict (logistic only)
    if (model == "logistic" && !is.null(pred_times)) {
      obj <- suppressMessages(emulate_predict(
        obj, times = pred_times, type = pred_type,
        samples = pred_samples, seed = pred_seed,
        difference = TRUE
      ))

      pred <- obj$predictions
      for (i in seq_len(nrow(pred))) {
        t <- pred$time[i]
        add_result(dataset_name, config_name, paste0("pred_arm0_t", t), pred$est_0[i])
        add_result(dataset_name, config_name, paste0("pred_arm1_t", t), pred$est_1[i])
        add_result(dataset_name, config_name, paste0("pred_diff_t", t), pred$diff[i])
      }
    }

    elapsed <- (proc.time() - t0)["elapsed"]
    cat(sprintf("OK (%.1fs)\n", elapsed))

  }, error = function(e) {
    cat(sprintf("ERROR: %s\n", conditionMessage(e)))
    add_result(dataset_name, config_name, "error", 1)
  })
}


# =============================================================================
# DATASET 1: trial_example (503 patients, canonical benchmark)
# =============================================================================
cat("\n--- Dataset 1: trial_example (canonical benchmark) ---\n")

te <- read.csv(file.path(qa_dir, "data", "trial_example.csv"))
write.csv(te, file.path(data_dir, "trial_example.csv"), row.names = FALSE)
cat(sprintf("  Loaded: %d rows, %d patients\n", nrow(te), length(unique(te$id))))

# 1A: ITT, logistic, linear
run_config("trial_example", "1A_ITT_logistic_linear", te,
  id_col = "id", period_col = "period", treatment_col = "treatment",
  outcome_col = "outcome", eligible_col = "eligible",
  covariates = c("nvarA", "nvarB"), estimand = "ITT",
  outcome_cov = c("catvarA", "catvarB", "nvarA", "nvarB", "nvarC"),
  model = "logistic", followup_spec = "linear", trial_period_spec = "linear",
  pred_times = seq(0, 30, by = 5))

# 1B: ITT, logistic, quadratic (primary benchmark)
run_config("trial_example", "1B_ITT_logistic_quad", te,
  id_col = "id", period_col = "period", treatment_col = "treatment",
  outcome_col = "outcome", eligible_col = "eligible",
  covariates = c("nvarA", "nvarB"), estimand = "ITT",
  outcome_cov = c("catvarA", "catvarB", "nvarA", "nvarB", "nvarC"),
  model = "logistic", followup_spec = "quadratic", trial_period_spec = "quadratic",
  pred_times = seq(0, 30, by = 5))

# 1C: ITT, logistic, cubic
run_config("trial_example", "1C_ITT_logistic_cubic", te,
  id_col = "id", period_col = "period", treatment_col = "treatment",
  outcome_col = "outcome", eligible_col = "eligible",
  covariates = c("nvarA", "nvarB"), estimand = "ITT",
  outcome_cov = c("catvarA", "catvarB", "nvarA", "nvarB", "nvarC"),
  model = "logistic", followup_spec = "cubic", trial_period_spec = "cubic",
  pred_times = seq(0, 30, by = 5))

# 1D: ITT, logistic, ns(3)
run_config("trial_example", "1D_ITT_logistic_ns3", te,
  id_col = "id", period_col = "period", treatment_col = "treatment",
  outcome_col = "outcome", eligible_col = "eligible",
  covariates = c("nvarA", "nvarB"), estimand = "ITT",
  outcome_cov = c("catvarA", "catvarB", "nvarA", "nvarB", "nvarC"),
  model = "logistic", followup_spec = "ns(3)", trial_period_spec = "ns(3)",
  pred_times = seq(0, 30, by = 5))

# 1E: ITT, cox, quadratic
run_config("trial_example", "1E_ITT_cox_quad", te,
  id_col = "id", period_col = "period", treatment_col = "treatment",
  outcome_col = "outcome", eligible_col = "eligible",
  covariates = c("nvarA", "nvarB"), estimand = "ITT",
  outcome_cov = c("catvarA", "catvarB", "nvarA", "nvarB", "nvarC"),
  model = "cox", followup_spec = "quadratic", trial_period_spec = "quadratic")

# 1F: PP, logistic, quadratic, stratified weights, no truncation
run_config("trial_example", "1F_PP_logistic_quad_strat", te,
  id_col = "id", period_col = "period", treatment_col = "treatment",
  outcome_col = "outcome", eligible_col = "eligible",
  covariates = c("nvarA", "nvarB"), estimand = "PP",
  switch_d_cov = c("nvarA", "nvarB"), switch_n_cov = c("nvarA", "nvarB"),
  outcome_cov = c("catvarA", "catvarB", "nvarA", "nvarB", "nvarC"),
  model = "logistic", followup_spec = "quadratic", trial_period_spec = "quadratic",
  pred_times = seq(0, 30, by = 5))

# 1G: PP, logistic, quadratic, stratified, truncated(1,99)
run_config("trial_example", "1G_PP_logistic_quad_strat_trunc", te,
  id_col = "id", period_col = "period", treatment_col = "treatment",
  outcome_col = "outcome", eligible_col = "eligible",
  covariates = c("nvarA", "nvarB"), estimand = "PP",
  switch_d_cov = c("nvarA", "nvarB"), switch_n_cov = c("nvarA", "nvarB"),
  truncate = c(1, 99),
  outcome_cov = c("catvarA", "catvarB", "nvarA", "nvarB", "nvarC"),
  model = "logistic", followup_spec = "quadratic", trial_period_spec = "quadratic",
  pred_times = seq(0, 30, by = 5))

# 1H: PP, logistic, quadratic, pooled weights, truncated(1,99)
run_config("trial_example", "1H_PP_logistic_quad_pooled_trunc", te,
  id_col = "id", period_col = "period", treatment_col = "treatment",
  outcome_col = "outcome", eligible_col = "eligible",
  covariates = c("nvarA", "nvarB"), estimand = "PP",
  switch_d_cov = c("nvarA", "nvarB"), switch_n_cov = c("nvarA", "nvarB"),
  pool_switch = TRUE, truncate = c(1, 99),
  outcome_cov = c("catvarA", "catvarB", "nvarA", "nvarB", "nvarC"),
  model = "logistic", followup_spec = "quadratic", trial_period_spec = "quadratic",
  pred_times = seq(0, 30, by = 5))

# 1I: PP, logistic, ns(3), stratified, truncated(1,99)
run_config("trial_example", "1I_PP_logistic_ns3_strat_trunc", te,
  id_col = "id", period_col = "period", treatment_col = "treatment",
  outcome_col = "outcome", eligible_col = "eligible",
  covariates = c("nvarA", "nvarB"), estimand = "PP",
  switch_d_cov = c("nvarA", "nvarB"), switch_n_cov = c("nvarA", "nvarB"),
  truncate = c(1, 99),
  outcome_cov = c("catvarA", "catvarB", "nvarA", "nvarB", "nvarC"),
  model = "logistic", followup_spec = "ns(3)", trial_period_spec = "ns(3)",
  pred_times = seq(0, 30, by = 5))

# 1J: PP, cox, quadratic, stratified, truncated(1,99)
run_config("trial_example", "1J_PP_cox_quad_strat_trunc", te,
  id_col = "id", period_col = "period", treatment_col = "treatment",
  outcome_col = "outcome", eligible_col = "eligible",
  covariates = c("nvarA", "nvarB"), estimand = "PP",
  switch_d_cov = c("nvarA", "nvarB"), switch_n_cov = c("nvarA", "nvarB"),
  truncate = c(1, 99),
  outcome_cov = c("catvarA", "catvarB", "nvarA", "nvarB", "nvarC"),
  model = "cox", followup_spec = "quadratic", trial_period_spec = "quadratic")

# 1K: AT, logistic, quadratic, stratified, truncated(1,99)
run_config("trial_example", "1K_AT_logistic_quad_strat_trunc", te,
  id_col = "id", period_col = "period", treatment_col = "treatment",
  outcome_col = "outcome", eligible_col = "eligible",
  covariates = c("nvarA", "nvarB"), estimand = "AT",
  switch_d_cov = c("nvarA", "nvarB"), switch_n_cov = c("nvarA", "nvarB"),
  truncate = c(1, 99),
  outcome_cov = c("catvarA", "catvarB", "nvarA", "nvarB", "nvarC"),
  model = "logistic", followup_spec = "quadratic", trial_period_spec = "quadratic",
  pred_times = seq(0, 30, by = 5))

# 1L: PP, logistic, linear, stratified, truncated(1,99)
run_config("trial_example", "1L_PP_logistic_linear_strat_trunc", te,
  id_col = "id", period_col = "period", treatment_col = "treatment",
  outcome_col = "outcome", eligible_col = "eligible",
  covariates = c("nvarA", "nvarB"), estimand = "PP",
  switch_d_cov = c("nvarA", "nvarB"), switch_n_cov = c("nvarA", "nvarB"),
  truncate = c(1, 99),
  outcome_cov = c("catvarA", "catvarB", "nvarA", "nvarB", "nvarC"),
  model = "logistic", followup_spec = "linear", trial_period_spec = "linear",
  pred_times = seq(0, 30, by = 5))


# =============================================================================
# DATASET 2: NHEFS-style synthetic (single-trial smoking cessation)
# =============================================================================
cat("\n--- Dataset 2: NHEFS-style synthetic ---\n")

dgp_nhefs <- function(n = 1600, periods = 10, seed = 20260311) {
  set.seed(seed)
  rows <- vector("list", n * periods)
  idx <- 0L
  for (i in seq_len(n)) {
    age <- rnorm(1, 45, 12)
    age_std <- (age - 45) / 12
    sex <- sample(0:1, 1)
    wt_base <- rnorm(1, 75, 15)
    wt_std <- (wt_base - 75) / 15
    p_quit <- plogis(-1.1 + 0.15 * age_std + 0.3 * sex)
    treat <- as.integer(runif(1) < p_quit)
    alive <- TRUE
    for (t in 0:(periods - 1L)) {
      if (!alive) break
      log_haz <- -4.0 + 0.4 * age_std + 0.15 * wt_std + 0.05 * t - 0.40 * treat
      p_death <- plogis(log_haz)
      event <- as.integer(runif(1) < p_death)
      idx <- idx + 1L
      rows[[idx]] <- data.frame(
        id = i, period = t, treatment = treat, outcome = event,
        eligible = as.integer(t == 0),
        age_std = round(age_std, 6), sex = sex, wt_std = round(wt_std, 6),
        stringsAsFactors = FALSE
      )
      if (event == 1L) alive <- FALSE
    }
  }
  do.call(rbind, rows[seq_len(idx)])
}

nhefs <- dgp_nhefs()
write.csv(nhefs, file.path(data_dir, "nhefs_synthetic.csv"), row.names = FALSE)
cat(sprintf("  Generated: %d rows, %d patients, %d events\n",
            nrow(nhefs), length(unique(nhefs$id)), sum(nhefs$outcome)))

# 2A: ITT, logistic, quadratic, outcome covariates
run_config("nhefs_synth", "2A_ITT_logistic_quad", nhefs,
  id_col = "id", period_col = "period", treatment_col = "treatment",
  outcome_col = "outcome", eligible_col = "eligible",
  covariates = c("age_std", "sex", "wt_std"), estimand = "ITT",
  outcome_cov = c("age_std", "sex", "wt_std"),
  model = "logistic", followup_spec = "quadratic", trial_period_spec = "none",
  pred_times = 0:9)

# 2B: ITT, logistic, linear
run_config("nhefs_synth", "2B_ITT_logistic_linear", nhefs,
  id_col = "id", period_col = "period", treatment_col = "treatment",
  outcome_col = "outcome", eligible_col = "eligible",
  covariates = c("age_std", "sex", "wt_std"), estimand = "ITT",
  outcome_cov = c("age_std", "sex", "wt_std"),
  model = "logistic", followup_spec = "linear", trial_period_spec = "none",
  pred_times = 0:9)

# 2C: ITT, cox, quadratic
run_config("nhefs_synth", "2C_ITT_cox_quad", nhefs,
  id_col = "id", period_col = "period", treatment_col = "treatment",
  outcome_col = "outcome", eligible_col = "eligible",
  covariates = c("age_std", "sex", "wt_std"), estimand = "ITT",
  outcome_cov = c("age_std", "sex", "wt_std"),
  model = "cox", followup_spec = "quadratic", trial_period_spec = "none")

# 2D: ITT, logistic, ns(3)
run_config("nhefs_synth", "2D_ITT_logistic_ns3", nhefs,
  id_col = "id", period_col = "period", treatment_col = "treatment",
  outcome_col = "outcome", eligible_col = "eligible",
  covariates = c("age_std", "sex", "wt_std"), estimand = "ITT",
  outcome_cov = c("age_std", "sex", "wt_std"),
  model = "logistic", followup_spec = "ns(3)", trial_period_spec = "none",
  pred_times = 0:9)

# 2E: ITT, logistic, cubic
run_config("nhefs_synth", "2E_ITT_logistic_cubic", nhefs,
  id_col = "id", period_col = "period", treatment_col = "treatment",
  outcome_col = "outcome", eligible_col = "eligible",
  covariates = c("age_std", "sex", "wt_std"), estimand = "ITT",
  outcome_cov = c("age_std", "sex", "wt_std"),
  model = "logistic", followup_spec = "cubic", trial_period_spec = "none",
  pred_times = 0:9)


# =============================================================================
# DATASET 3: CCW Simulated (lung cancer surgery, immortal-time bias)
# =============================================================================
cat("\n--- Dataset 3: CCW simulated (lung cancer surgery) ---\n")

dgp_ccw <- function(n = 2000, n_periods = 24, seed = 20260311) {
  set.seed(seed)
  rows <- vector("list", n * n_periods)
  idx <- 0L
  for (i in seq_len(n)) {
    age <- rnorm(1, 65, 10)
    age_std <- (age - 65) / 10
    ps  <- sample(0:1, 1, prob = c(0.7, 0.3))
    stage <- sample(0:1, 1, prob = c(0.65, 0.35))
    u <- runif(1)
    p_surg <- plogis(-1.5 + 0.1 * age_std - 0.5 * ps - 0.8 * stage)
    will_get <- as.integer(u < p_surg)
    surg_period <- if (will_get == 1L) sample(1:8, 1, prob = rep(1/8, 8)) else n_periods + 1L
    surv_time <- rweibull(1, shape = 1.2,
                          scale = exp(3.5 - 0.3 * age_std + 0.4 * ps + 0.6 * stage -
                                        log(0.60) * will_get))
    death_period <- min(floor(surv_time), n_periods)
    alive <- TRUE
    for (t in 0:(n_periods - 1L)) {
      if (!alive) break
      treat <- as.integer(t >= surg_period)
      event <- as.integer(t == death_period & death_period < n_periods)
      elig  <- as.integer(t < surg_period | will_get == 0L)
      idx <- idx + 1L
      rows[[idx]] <- data.frame(
        id = i, period = t, treatment = treat, outcome = event,
        eligible = elig,
        age_std = round(age_std, 6), ps = ps, stage = stage,
        stringsAsFactors = FALSE
      )
      if (event == 1L) alive <- FALSE
    }
  }
  do.call(rbind, rows[seq_len(idx)])
}

ccw <- dgp_ccw()
write.csv(ccw, file.path(data_dir, "ccw_simulated.csv"), row.names = FALSE)
cat(sprintf("  Generated: %d rows, %d patients, %d events\n",
            nrow(ccw), length(unique(ccw$id)), sum(ccw$outcome)))

# 3A: ITT, logistic, quadratic, maxfollowup=12
run_config("ccw_simulated", "3A_ITT_logistic_quad_mfu12", ccw,
  id_col = "id", period_col = "period", treatment_col = "treatment",
  outcome_col = "outcome", eligible_col = "eligible",
  covariates = c("age_std", "ps", "stage"), estimand = "ITT",
  maxfollowup = 12,
  outcome_cov = c("age_std", "ps", "stage"),
  model = "logistic", followup_spec = "quadratic", trial_period_spec = "linear",
  pred_times = seq(0, 12, by = 3))

# 3B: PP, logistic, quadratic, stratified, truncated, maxfollowup=12
run_config("ccw_simulated", "3B_PP_logistic_quad_strat_trunc_mfu12", ccw,
  id_col = "id", period_col = "period", treatment_col = "treatment",
  outcome_col = "outcome", eligible_col = "eligible",
  covariates = c("age_std", "ps", "stage"), estimand = "PP",
  maxfollowup = 12,
  switch_d_cov = c("age_std", "ps", "stage"),
  truncate = c(1, 99),
  outcome_cov = c("age_std", "ps", "stage"),
  model = "logistic", followup_spec = "quadratic", trial_period_spec = "linear",
  pred_times = seq(0, 12, by = 3))

# 3C: PP, logistic, linear, pooled, truncated, maxfollowup=12
run_config("ccw_simulated", "3C_PP_logistic_linear_pooled_trunc_mfu12", ccw,
  id_col = "id", period_col = "period", treatment_col = "treatment",
  outcome_col = "outcome", eligible_col = "eligible",
  covariates = c("age_std", "ps", "stage"), estimand = "PP",
  maxfollowup = 12,
  switch_d_cov = c("age_std", "ps", "stage"),
  pool_switch = TRUE, truncate = c(1, 99),
  outcome_cov = c("age_std", "ps", "stage"),
  model = "logistic", followup_spec = "linear", trial_period_spec = "linear",
  pred_times = seq(0, 12, by = 3))

# 3D: PP, cox, quadratic, stratified, truncated, maxfollowup=12
run_config("ccw_simulated", "3D_PP_cox_quad_strat_trunc_mfu12", ccw,
  id_col = "id", period_col = "period", treatment_col = "treatment",
  outcome_col = "outcome", eligible_col = "eligible",
  covariates = c("age_std", "ps", "stage"), estimand = "PP",
  maxfollowup = 12,
  switch_d_cov = c("age_std", "ps", "stage"),
  truncate = c(1, 99),
  outcome_cov = c("age_std", "ps", "stage"),
  model = "cox", followup_spec = "quadratic", trial_period_spec = "linear")

# 3E: AT, logistic, quadratic, stratified, truncated, maxfollowup=12
run_config("ccw_simulated", "3E_AT_logistic_quad_strat_trunc_mfu12", ccw,
  id_col = "id", period_col = "period", treatment_col = "treatment",
  outcome_col = "outcome", eligible_col = "eligible",
  covariates = c("age_std", "ps", "stage"), estimand = "AT",
  maxfollowup = 12,
  switch_d_cov = c("age_std", "ps", "stage"),
  truncate = c(1, 99),
  outcome_cov = c("age_std", "ps", "stage"),
  model = "logistic", followup_spec = "quadratic", trial_period_spec = "linear",
  pred_times = seq(0, 12, by = 3))


# =============================================================================
# DATASET 4: Null effect DGP (true log-OR = 0)
# =============================================================================
cat("\n--- Dataset 4: Null effect DGP ---\n")

dgp_null <- function(n = 1000, periods = 15, seed = 20260311) {
  set.seed(seed)
  rows <- vector("list", n * periods)
  idx <- 0L
  for (i in seq_len(n)) {
    age_std <- rnorm(1, 0, 1)
    sex <- sample(0:1, 1)
    treat_status <- 0L
    alive <- TRUE
    for (t in 0:(periods - 1L)) {
      if (!alive) break
      if (treat_status == 0L && runif(1) < plogis(-1.5 + 0.2 * age_std + 0.1 * sex)) {
        treat_status <- 1L
      }
      # NO treatment effect (true log-OR = 0)
      log_haz <- -4.5 + 0.3 * age_std + 0.1 * sex + 0.03 * t + 0.0 * treat_status
      event <- as.integer(runif(1) < plogis(log_haz))
      elig <- as.integer(t <= 5)
      idx <- idx + 1L
      rows[[idx]] <- data.frame(
        id = i, period = t, treatment = treat_status, outcome = event,
        eligible = elig, age_std = round(age_std, 6), sex = sex,
        stringsAsFactors = FALSE
      )
      if (event == 1L) alive <- FALSE
    }
  }
  do.call(rbind, rows[seq_len(idx)])
}

null_data <- dgp_null()
write.csv(null_data, file.path(data_dir, "null_effect.csv"), row.names = FALSE)
cat(sprintf("  Generated: %d rows, %d patients, %d events\n",
            nrow(null_data), length(unique(null_data$id)), sum(null_data$outcome)))

# 4A: ITT, logistic, quadratic
run_config("null_effect", "4A_ITT_logistic_quad", null_data,
  id_col = "id", period_col = "period", treatment_col = "treatment",
  outcome_col = "outcome", eligible_col = "eligible",
  covariates = c("age_std", "sex"), estimand = "ITT",
  outcome_cov = c("age_std", "sex"),
  model = "logistic", followup_spec = "quadratic", trial_period_spec = "linear",
  pred_times = seq(0, 14, by = 3))

# 4B: PP, logistic, quadratic, stratified, truncated
run_config("null_effect", "4B_PP_logistic_quad_strat_trunc", null_data,
  id_col = "id", period_col = "period", treatment_col = "treatment",
  outcome_col = "outcome", eligible_col = "eligible",
  covariates = c("age_std", "sex"), estimand = "PP",
  switch_d_cov = c("age_std", "sex"), truncate = c(1, 99),
  outcome_cov = c("age_std", "sex"),
  model = "logistic", followup_spec = "quadratic", trial_period_spec = "linear",
  pred_times = seq(0, 14, by = 3))

# 4C: ITT, cox
run_config("null_effect", "4C_ITT_cox_quad", null_data,
  id_col = "id", period_col = "period", treatment_col = "treatment",
  outcome_col = "outcome", eligible_col = "eligible",
  covariates = c("age_std", "sex"), estimand = "ITT",
  outcome_cov = c("age_std", "sex"),
  model = "cox", followup_spec = "quadratic", trial_period_spec = "linear")


# =============================================================================
# DATASET 5: IPCW DGP (informative censoring)
# =============================================================================
cat("\n--- Dataset 5: IPCW DGP (informative censoring) ---\n")

dgp_ipcw <- function(n = 1200, periods = 12, seed = 20260311) {
  set.seed(seed)
  rows <- vector("list", n * periods)
  idx <- 0L
  for (i in seq_len(n)) {
    age_std <- rnorm(1, 0, 1)
    sex <- sample(0:1, 1)
    treat_status <- 0L
    alive <- TRUE
    censored <- FALSE
    for (t in 0:(periods - 1L)) {
      if (!alive || censored) break
      if (treat_status == 0L && runif(1) < plogis(-1.2 + 0.1 * age_std)) {
        treat_status <- 1L
      }
      # Informative censoring: sicker patients more likely to be censored
      p_censor <- plogis(-3.5 + 0.4 * age_std + 0.2 * sex + 0.05 * t)
      cens <- as.integer(runif(1) < p_censor)
      # Treatment effect log-OR = -0.5
      log_haz <- -4.0 + 0.35 * age_std + 0.15 * sex + 0.04 * t - 0.50 * treat_status
      event <- as.integer(runif(1) < plogis(log_haz))
      if (cens == 1L) event <- 0L
      elig <- as.integer(t <= 4)
      idx <- idx + 1L
      rows[[idx]] <- data.frame(
        id = i, period = t, treatment = treat_status, outcome = event,
        eligible = elig, censor = cens,
        age_std = round(age_std, 6), sex = sex,
        stringsAsFactors = FALSE
      )
      if (event == 1L) alive <- FALSE
      if (cens == 1L) censored <- TRUE
    }
  }
  do.call(rbind, rows[seq_len(idx)])
}

ipcw_data <- dgp_ipcw()
write.csv(ipcw_data, file.path(data_dir, "ipcw_dgp.csv"), row.names = FALSE)
cat(sprintf("  Generated: %d rows, %d patients, %d events, %d censored\n",
            nrow(ipcw_data), length(unique(ipcw_data$id)),
            sum(ipcw_data$outcome), sum(ipcw_data$censor)))

# 5A: PP, logistic, IPTW only (no IPCW)
run_config("ipcw_dgp", "5A_PP_logistic_quad_iptw_only", ipcw_data,
  id_col = "id", period_col = "period", treatment_col = "treatment",
  outcome_col = "outcome", eligible_col = "eligible",
  censor_col = "censor",
  covariates = c("age_std", "sex"), estimand = "PP",
  switch_d_cov = c("age_std", "sex"), truncate = c(1, 99),
  outcome_cov = c("age_std", "sex"),
  model = "logistic", followup_spec = "quadratic", trial_period_spec = "linear",
  pred_times = seq(0, 11, by = 3))

# 5B: PP, logistic, IPTW + IPCW
run_config("ipcw_dgp", "5B_PP_logistic_quad_iptw_ipcw", ipcw_data,
  id_col = "id", period_col = "period", treatment_col = "treatment",
  outcome_col = "outcome", eligible_col = "eligible",
  censor_col = "censor",
  covariates = c("age_std", "sex"), estimand = "PP",
  switch_d_cov = c("age_std", "sex"),
  censor_d_cov = c("age_std", "sex"),
  truncate = c(1, 99),
  outcome_cov = c("age_std", "sex"),
  model = "logistic", followup_spec = "quadratic", trial_period_spec = "linear",
  pred_times = seq(0, 11, by = 3))

# 5C: PP, cox, IPTW + IPCW
run_config("ipcw_dgp", "5C_PP_cox_quad_iptw_ipcw", ipcw_data,
  id_col = "id", period_col = "period", treatment_col = "treatment",
  outcome_col = "outcome", eligible_col = "eligible",
  censor_col = "censor",
  covariates = c("age_std", "sex"), estimand = "PP",
  switch_d_cov = c("age_std", "sex"),
  censor_d_cov = c("age_std", "sex"),
  truncate = c(1, 99),
  outcome_cov = c("age_std", "sex"),
  model = "cox", followup_spec = "quadratic", trial_period_spec = "linear")


# =============================================================================
# DATASET 6: Grace period test (trial_example with grace)
# =============================================================================
cat("\n--- Dataset 6: Grace period variations (trial_example) ---\n")

# 6A: PP, grace=0 (baseline)
run_config("grace_test", "6A_PP_logistic_quad_grace0", te,
  id_col = "id", period_col = "period", treatment_col = "treatment",
  outcome_col = "outcome", eligible_col = "eligible",
  covariates = c("nvarA", "nvarB"), estimand = "PP",
  maxfollowup = 8, grace = 0,
  switch_d_cov = c("nvarA", "nvarB"), truncate = c(1, 99),
  outcome_cov = c("catvarA", "catvarB", "nvarA", "nvarB", "nvarC"),
  model = "logistic", followup_spec = "quadratic", trial_period_spec = "quadratic",
  pred_times = 0:8)

# 6B: PP, grace=1
run_config("grace_test", "6B_PP_logistic_quad_grace1", te,
  id_col = "id", period_col = "period", treatment_col = "treatment",
  outcome_col = "outcome", eligible_col = "eligible",
  covariates = c("nvarA", "nvarB"), estimand = "PP",
  maxfollowup = 8, grace = 1,
  switch_d_cov = c("nvarA", "nvarB"), truncate = c(1, 99),
  outcome_cov = c("catvarA", "catvarB", "nvarA", "nvarB", "nvarC"),
  model = "logistic", followup_spec = "quadratic", trial_period_spec = "quadratic",
  pred_times = 0:8)

# 6C: PP, grace=2
run_config("grace_test", "6C_PP_logistic_quad_grace2", te,
  id_col = "id", period_col = "period", treatment_col = "treatment",
  outcome_col = "outcome", eligible_col = "eligible",
  covariates = c("nvarA", "nvarB"), estimand = "PP",
  maxfollowup = 8, grace = 2,
  switch_d_cov = c("nvarA", "nvarB"), truncate = c(1, 99),
  outcome_cov = c("catvarA", "catvarB", "nvarA", "nvarB", "nvarC"),
  model = "logistic", followup_spec = "quadratic", trial_period_spec = "quadratic",
  pred_times = 0:8)


# =============================================================================
# Save all results
# =============================================================================
write.csv(all_results, file.path(results_dir, "r_emulate_results.csv"),
          row.names = FALSE)

cat(sprintf("\n%s\n", strrep("=", 72)))
cat(sprintf("DONE: %d results across %d configurations\n",
            nrow(all_results), length(unique(paste(all_results$dataset, all_results$config)))))
cat(sprintf("Data saved to:    %s\n", data_dir))
cat(sprintf("Results saved to: %s\n", file.path(results_dir, "r_emulate_results.csv")))
cat(strrep("=", 72), "\n")
