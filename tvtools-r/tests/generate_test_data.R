#!/usr/bin/env Rscript
#
# Comprehensive Test Data Generation Script for tvtools R Package
#
# This script generates diverse synthetic test datasets covering a wide range of
# scenarios for testing the tvtools R package functions (tvexpose and tvmerge).
#
# Usage:
#   Rscript /home/user/Stata-Tools/tvtools-r/tests/generate_test_data.R
#
# Output:
#   Saves test datasets as both CSV and RDS files in tests/test_data/
#
# Author: Generated for tvtools package testing
# Date: 2025-11-19

# ============================================================================
# SETUP AND INITIALIZATION
# ============================================================================

cat(paste(rep("=", 78), collapse = ""), "\n", sep = "")
cat("tvtools Test Data Generation Script\n")
cat(paste(rep("=", 78), collapse = ""), "\n\n", sep = "")

# Set seed for reproducibility
set.seed(42)

# Determine output directory
# Try to get script directory, fall back to working directory
script_dir <- tryCatch({
  args <- commandArgs(trailingOnly = FALSE)
  file_arg <- grep("^--file=", args, value = TRUE)
  if (length(file_arg) > 0) {
    script_path <- sub("^--file=", "", file_arg)
    dirname(normalizePath(script_path))
  } else {
    getwd()
  }
}, error = function(e) {
  getwd()
})

# Set output directory
output_dir <- file.path(script_dir, "test_data")

# Create output directory if it doesn't exist
if (!dir.exists(output_dir)) {
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
}

cat("Output directory:", output_dir, "\n\n")

# Helper function to save data
save_data <- function(data, name, description = "") {
  csv_path <- file.path(output_dir, paste0(name, ".csv"))
  rds_path <- file.path(output_dir, paste0(name, ".rds"))

  write.csv(data, csv_path, row.names = FALSE)
  saveRDS(data, rds_path)

  cat(sprintf("  %-35s: %6d rows x %2d cols\n",
              name, nrow(data), ncol(data)))
  if (description != "") {
    cat(sprintf("    %s\n", description))
  }
}

# ============================================================================
# 1. BASIC COHORT DATA (100 persons)
# ============================================================================

cat("Generating Dataset 1: Basic Cohort Data\n")
cat(paste(rep("-", 78), collapse = ""), "\n", sep = "")

n_cohort <- 100

cohort_basic <- data.frame(
  id = 1:n_cohort,
  study_entry = as.Date("2010-01-01") + sample(0:365, n_cohort, replace = TRUE),
  study_exit = as.Date("2020-12-31") - sample(0:365, n_cohort, replace = TRUE),
  age = round(rnorm(n_cohort, mean = 55, sd = 15)),
  sex = sample(c("M", "F"), n_cohort, replace = TRUE, prob = c(0.45, 0.55)),
  bmi = round(rnorm(n_cohort, mean = 27, sd = 5), 1),
  smoker = sample(c(0, 1), n_cohort, replace = TRUE, prob = c(0.7, 0.3)),
  chronic_disease = sample(c(0, 1), n_cohort, replace = TRUE, prob = c(0.65, 0.35)),
  region = sample(c("North", "South", "East", "West"), n_cohort, replace = TRUE),
  baseline_score = round(rnorm(n_cohort, mean = 50, sd = 10), 1),
  stringsAsFactors = FALSE
)

# Ensure study_exit > study_entry
cohort_basic$study_exit <- pmax(
  cohort_basic$study_exit,
  cohort_basic$study_entry + 30
)

save_data(cohort_basic, "cohort_basic",
          "Master cohort: 100 persons with baseline characteristics")

cat("\n")

# ============================================================================
# 2. SIMPLE EXPOSURE DATA (no gaps, no overlaps)
# ============================================================================

cat("Generating Dataset 2: Simple Exposure Data\n")
cat(paste(rep("-", 78), collapse = ""), "\n", sep = "")

# Select 60% of cohort to have exposures
exposed_ids <- sample(cohort_basic$id, size = 60)

exposure_simple <- do.call(rbind, lapply(exposed_ids, function(pid) {
  person_entry <- cohort_basic$study_entry[cohort_basic$id == pid]
  person_exit <- cohort_basic$study_exit[cohort_basic$id == pid]

  # 1-3 non-overlapping exposure periods
  n_periods <- sample(1:3, 1)

  # Generate start dates
  date_range <- as.numeric(person_exit - person_entry)
  starts <- sort(person_entry + sample(30:(date_range - 100), n_periods))

  # Generate durations (30-365 days)
  durations <- sample(30:365, n_periods, replace = TRUE)
  stops <- starts + durations

  # Ensure stops don't exceed exit
  stops <- pmin(stops, person_exit)

  # Ensure no overlaps by adjusting subsequent starts
  if (n_periods > 1) {
    for (i in 2:n_periods) {
      if (starts[i] < stops[i-1]) {
        starts[i] <- stops[i-1] + sample(1:30, 1)
        stops[i] <- starts[i] + sample(30:180, 1)
        stops[i] <- min(stops[i], person_exit)
      }
    }
  }

  data.frame(
    id = pid,
    exp_start = starts,
    exp_stop = stops,
    exposure = sample(1:2, n_periods, replace = TRUE),
    dose_mg = sample(c(10, 20, 50, 100), n_periods, replace = TRUE),
    stringsAsFactors = FALSE
  )
}))

# Remove any invalid periods (start >= stop)
exposure_simple <- exposure_simple[exposure_simple$exp_start < exposure_simple$exp_stop, ]

save_data(exposure_simple, "exposure_simple",
          "Clean non-overlapping exposure periods for 60 persons")

cat("\n")

# ============================================================================
# 3. COMPLEX EXPOSURE DATA WITH GAPS
# ============================================================================

cat("Generating Dataset 3: Complex Exposure with Gaps\n")
cat(paste(rep("-", 78), collapse = ""), "\n", sep = "")

# Select 50% of cohort
exposed_ids_gaps <- sample(cohort_basic$id, size = 50)

exposure_gaps <- do.call(rbind, lapply(exposed_ids_gaps, function(pid) {
  person_entry <- cohort_basic$study_entry[cohort_basic$id == pid]
  person_exit <- cohort_basic$study_exit[cohort_basic$id == pid]

  # 2-5 exposure periods with intentional gaps
  n_periods <- sample(2:5, 1)

  date_range <- as.numeric(person_exit - person_entry)

  periods_list <- list()
  current_date <- person_entry + sample(30:100, 1)

  for (i in 1:n_periods) {
    if (current_date >= person_exit) break

    # Duration of exposure: 30-180 days
    duration <- sample(30:180, 1)
    exp_stop <- min(current_date + duration, person_exit)

    periods_list[[i]] <- data.frame(
      id = pid,
      exp_start = current_date,
      exp_stop = exp_stop,
      exposure = sample(1:3, 1),
      exposure_type = sample(c("Type_A", "Type_B", "Type_C"), 1),
      stringsAsFactors = FALSE
    )

    # Add gap of 10-90 days before next exposure
    gap <- sample(10:90, 1)
    current_date <- exp_stop + gap
  }

  do.call(rbind, periods_list)
}))

# Remove NULL entries
exposure_gaps <- exposure_gaps[!is.na(exposure_gaps$id), ]

save_data(exposure_gaps, "exposure_gaps",
          "Exposure periods with gaps (10-90 days) for testing grace periods")

cat("\n")

# ============================================================================
# 4. OVERLAPPING EXPOSURES
# ============================================================================

cat("Generating Dataset 4: Overlapping Exposures\n")
cat(paste(rep("-", 78), collapse = ""), "\n", sep = "")

# Select 40 persons
exposed_ids_overlap <- sample(cohort_basic$id, size = 40)

exposure_overlap <- do.call(rbind, lapply(exposed_ids_overlap, function(pid) {
  person_entry <- cohort_basic$study_entry[cohort_basic$id == pid]
  person_exit <- cohort_basic$study_exit[cohort_basic$id == pid]

  # 2-4 overlapping periods
  n_periods <- sample(2:4, 1)

  date_range <- as.numeric(person_exit - person_entry)

  # First period
  start1 <- person_entry + sample(30:100, 1)
  duration1 <- sample(180:730, 1)  # Long duration to ensure overlaps
  stop1 <- min(start1 + duration1, person_exit)

  periods <- data.frame(
    id = pid,
    exp_start = start1,
    exp_stop = stop1,
    exposure = 1,
    priority = 1,
    stringsAsFactors = FALSE
  )

  # Add overlapping periods
  for (i in 2:n_periods) {
    # Start during previous period (overlap)
    start_i <- start1 + sample(30:120, 1)
    if (start_i >= person_exit) break

    duration_i <- sample(90:365, 1)
    stop_i <- min(start_i + duration_i, person_exit)

    periods <- rbind(periods, data.frame(
      id = pid,
      exp_start = start_i,
      exp_stop = stop_i,
      exposure = i,
      priority = sample(1:5, 1),
      stringsAsFactors = FALSE
    ))
  }

  periods
}))

save_data(exposure_overlap, "exposure_overlap",
          "Overlapping exposure periods for testing layer/split/priority strategies")

cat("\n")

# ============================================================================
# 5. MULTIPLE EXPOSURE TYPES (1-6 different types)
# ============================================================================

cat("Generating Dataset 5: Multiple Exposure Types\n")
cat(paste(rep("-", 78), collapse = ""), "\n", sep = "")

exposed_ids_multi <- sample(cohort_basic$id, size = 70)

exposure_multi_types <- do.call(rbind, lapply(exposed_ids_multi, function(pid) {
  person_entry <- cohort_basic$study_entry[cohort_basic$id == pid]
  person_exit <- cohort_basic$study_exit[cohort_basic$id == pid]

  # Random number of exposure types (1-6)
  n_types <- sample(1:6, 1)
  exposure_types <- sample(1:6, n_types)

  periods_list <- list()

  for (exp_type in exposure_types) {
    # 1-3 periods per type
    n_periods_type <- sample(1:3, 1)

    for (j in 1:n_periods_type) {
      date_range <- as.numeric(person_exit - person_entry)
      if (date_range < 60) next

      start_offset <- sample(0:(date_range - 60), 1)
      start_date <- person_entry + start_offset
      duration <- sample(30:180, 1)
      stop_date <- min(start_date + duration, person_exit)

      periods_list[[length(periods_list) + 1]] <- data.frame(
        id = pid,
        exp_start = start_date,
        exp_stop = stop_date,
        exposure = exp_type,
        exposure_name = paste0("Drug_", LETTERS[exp_type]),
        stringsAsFactors = FALSE
      )
    }
  }

  if (length(periods_list) > 0) {
    do.call(rbind, periods_list)
  } else {
    NULL
  }
}))

# Remove NULL entries
exposure_multi_types <- exposure_multi_types[!is.na(exposure_multi_types$id), ]

save_data(exposure_multi_types, "exposure_multi_types",
          "1-6 different exposure types per person for bytype testing")

cat("\n")

# ============================================================================
# 6. POINT-IN-TIME EXPOSURES
# ============================================================================

cat("Generating Dataset 6: Point-in-Time Exposures\n")
cat(paste(rep("-", 78), collapse = ""), "\n", sep = "")

exposed_ids_point <- sample(cohort_basic$id, size = 50)

exposure_point_time <- do.call(rbind, lapply(exposed_ids_point, function(pid) {
  person_entry <- cohort_basic$study_entry[cohort_basic$id == pid]
  person_exit <- cohort_basic$study_exit[cohort_basic$id == pid]

  # 1-5 point-in-time events
  n_events <- sample(1:5, 1)

  date_range <- as.numeric(person_exit - person_entry)
  event_dates <- sort(person_entry + sample(0:date_range, n_events, replace = FALSE))

  data.frame(
    id = pid,
    event_date = event_dates,
    event_type = sample(c("Vaccination", "Surgery", "Diagnosis", "Procedure"),
                       n_events, replace = TRUE),
    event_code = sample(1:4, n_events, replace = TRUE),
    stringsAsFactors = FALSE
  )
}))

save_data(exposure_point_time, "exposure_point_time",
          "Point-in-time events (no stop date) for testing pointtime option")

cat("\n")

# ============================================================================
# 7. EDGE CASES
# ============================================================================

cat("Generating Dataset 7: Edge Cases\n")
cat(paste(rep("-", 78), collapse = ""), "\n", sep = "")

edge_case_ids <- sample(cohort_basic$id, size = 30)
exposure_edge_cases <- data.frame()

for (pid in edge_case_ids) {
  person_entry <- cohort_basic$study_entry[cohort_basic$id == pid]
  person_exit <- cohort_basic$study_exit[cohort_basic$id == pid]

  edge_type <- sample(1:7, 1)

  if (edge_type == 1) {
    # Exposure starts BEFORE study_entry
    exp_start <- person_entry - sample(30:365, 1)
    exp_stop <- person_entry + sample(30:180, 1)
    edge_desc <- "before_entry"

  } else if (edge_type == 2) {
    # Exposure ends AFTER study_exit
    exp_start <- person_exit - sample(30:180, 1)
    exp_stop <- person_exit + sample(30:365, 1)
    edge_desc <- "after_exit"

  } else if (edge_type == 3) {
    # Very short exposure (1 day)
    exp_start <- person_entry + sample(30:100, 1)
    exp_stop <- exp_start + 1
    edge_desc <- "very_short_1day"

  } else if (edge_type == 4) {
    # Very long exposure (10 years)
    exp_start <- person_entry + sample(0:100, 1)
    exp_stop <- exp_start + 3650  # 10 years
    edge_desc <- "very_long_10years"

  } else if (edge_type == 5) {
    # Exposure spanning entire follow-up
    exp_start <- person_entry
    exp_stop <- person_exit
    edge_desc <- "entire_followup"

  } else if (edge_type == 6) {
    # Multiple very short exposures
    exp_start <- c(person_entry + 30, person_entry + 100, person_entry + 200)
    exp_stop <- exp_start + 1
    edge_desc <- rep("multiple_1day", 3)

  } else {
    # Normal exposure for comparison
    exp_start <- person_entry + sample(30:100, 1)
    exp_stop <- exp_start + sample(30:180, 1)
    edge_desc <- "normal"
  }

  edge_case <- data.frame(
    id = pid,
    exp_start = exp_start,
    exp_stop = exp_stop,
    exposure = sample(1:2, length(exp_start), replace = TRUE),
    edge_case_type = edge_desc,
    stringsAsFactors = FALSE
  )

  exposure_edge_cases <- rbind(exposure_edge_cases, edge_case)
}

save_data(exposure_edge_cases, "exposure_edge_cases",
          "Edge cases: before entry, after exit, very short/long periods")

# Extra edge cases: Missing persons

# Persons in exposure but NOT in cohort
missing_cohort_ids <- (max(cohort_basic$id) + 1):(max(cohort_basic$id) + 5)
exposure_missing_cohort <- data.frame(
  id = rep(missing_cohort_ids, each = 2),
  exp_start = as.Date("2012-01-01") + sample(0:365, 10, replace = TRUE),
  exp_stop = as.Date("2013-01-01") + sample(0:365, 10, replace = TRUE),
  exposure = sample(1:2, 10, replace = TRUE),
  stringsAsFactors = FALSE
)

save_data(exposure_missing_cohort, "exposure_missing_cohort",
          "Exposure data for IDs not in cohort (testing error handling)")

# Persons in cohort but NOT in exposure (already handled by using subset of cohort)
cohort_no_exposure_ids <- setdiff(cohort_basic$id, unique(exposure_simple$id))[1:20]
cohort_no_exposure <- cohort_basic[cohort_basic$id %in% cohort_no_exposure_ids, ]

save_data(cohort_no_exposure, "cohort_no_exposure",
          "Cohort subset with no corresponding exposure data")

cat("\n")

# ============================================================================
# 8. LARGE DATASET (1000 persons, 5000 exposure periods)
# ============================================================================

cat("Generating Dataset 8: Large Dataset for Performance Testing\n")
cat(paste(rep("-", 78), collapse = ""), "\n", sep = "")

n_large <- 1000

cohort_large <- data.frame(
  id = 1:n_large,
  study_entry = as.Date("2005-01-01") + sample(0:(5*365), n_large, replace = TRUE),
  study_exit = as.Date("2020-12-31") - sample(0:(2*365), n_large, replace = TRUE),
  age = round(rnorm(n_large, mean = 55, sd = 15)),
  sex = sample(c("M", "F"), n_large, replace = TRUE),
  bmi = round(rnorm(n_large, mean = 27, sd = 5), 1),
  region = sample(c("North", "South", "East", "West", "Central"),
                 n_large, replace = TRUE),
  stringsAsFactors = FALSE
)

# Ensure valid dates
cohort_large$study_exit <- pmax(
  cohort_large$study_exit,
  cohort_large$study_entry + 365
)

save_data(cohort_large, "cohort_large",
          "Large cohort: 1000 persons for performance testing")

# Generate ~5000 exposure periods
target_periods <- 5000
avg_periods_per_person <- ceiling(target_periods / n_large)

exposure_large <- do.call(rbind, lapply(1:n_large, function(pid) {
  person_entry <- cohort_large$study_entry[pid]
  person_exit <- cohort_large$study_exit[pid]

  # Random number of periods (0-10)
  n_periods <- sample(0:10, 1, prob = c(0.3, rep(0.7/10, 10)))

  if (n_periods == 0) return(NULL)

  date_range <- as.numeric(person_exit - person_entry)
  if (date_range < 30) return(NULL)

  starts <- sort(person_entry + sample(0:(date_range-30),
                                       min(n_periods, date_range %/% 30)))
  durations <- sample(30:180, length(starts), replace = TRUE)
  stops <- pmin(starts + durations, person_exit)

  data.frame(
    id = pid,
    exp_start = starts,
    exp_stop = stops,
    exposure = sample(1:5, length(starts), replace = TRUE),
    dose = sample(c(5, 10, 20, 50, 100), length(starts), replace = TRUE),
    stringsAsFactors = FALSE
  )
}))

# Remove NULL entries
exposure_large <- do.call(rbind,
                         Filter(function(x) !is.null(x) && nrow(x) > 0,
                               split(exposure_large,
                                    rep(1:ceiling(nrow(exposure_large)/100),
                                       each = 100, length.out = nrow(exposure_large)))))

save_data(exposure_large, "exposure_large",
          sprintf("Large exposure dataset: %d periods for performance testing",
                 nrow(exposure_large)))

cat("\n")

# ============================================================================
# 9. CONTINUOUS EXPOSURES (dosage rates)
# ============================================================================

cat("Generating Dataset 9: Continuous Exposures (Dosage Rates)\n")
cat(paste(rep("-", 78), collapse = ""), "\n", sep = "")

exposed_ids_continuous <- sample(cohort_basic$id, size = 60)

exposure_continuous <- do.call(rbind, lapply(exposed_ids_continuous, function(pid) {
  person_entry <- cohort_basic$study_entry[cohort_basic$id == pid]
  person_exit <- cohort_basic$study_exit[cohort_basic$id == pid]

  # 2-5 periods with different dosage rates
  n_periods <- sample(2:5, 1)

  date_range <- as.numeric(person_exit - person_entry)
  if (date_range < 60) return(NULL)

  # Generate non-overlapping periods
  total_duration <- date_range - 100
  period_lengths <- diff(c(0, sort(sample(1:total_duration, n_periods - 1)), total_duration))

  starts <- person_entry + 30 + cumsum(c(0, period_lengths[-length(period_lengths)]))
  stops <- starts + period_lengths
  stops <- pmin(stops, person_exit)

  # Continuous dose rates (mg/day)
  dose_rates <- round(runif(n_periods, min = 0, max = 100), 2)

  # Some periods with zero exposure
  zero_mask <- sample(c(TRUE, FALSE), n_periods, replace = TRUE, prob = c(0.3, 0.7))
  dose_rates[zero_mask] <- 0

  data.frame(
    id = pid,
    exp_start = starts,
    exp_stop = stops,
    dose_rate = dose_rates,  # mg/day (continuous)
    drug_name = sample(c("DrugA", "DrugB", "DrugC"), n_periods, replace = TRUE),
    stringsAsFactors = FALSE
  )
}))

# Remove NULL entries
exposure_continuous <- exposure_continuous[!is.na(exposure_continuous$id), ]

save_data(exposure_continuous, "exposure_continuous",
          "Continuous exposure with numeric dose rates (mg/day)")

cat("\n")

# ============================================================================
# 10. MIXED CATEGORICAL AND CONTINUOUS
# ============================================================================

cat("Generating Dataset 10: Mixed Categorical and Continuous Exposures\n")
cat(paste(rep("-", 78), collapse = ""), "\n", sep = "")

exposed_ids_mixed <- sample(cohort_basic$id, size = 60)

exposure_mixed <- do.call(rbind, lapply(exposed_ids_mixed, function(pid) {
  person_entry <- cohort_basic$study_entry[cohort_basic$id == pid]
  person_exit <- cohort_basic$study_exit[cohort_basic$id == pid]

  n_periods <- sample(2:6, 1)

  date_range <- as.numeric(person_exit - person_entry)
  if (date_range < 60) return(NULL)

  starts <- sort(person_entry + sample(0:(date_range-30), n_periods))
  durations <- sample(30:180, n_periods, replace = TRUE)
  stops <- pmin(starts + durations, person_exit)

  data.frame(
    id = pid,
    exp_start = starts,
    exp_stop = stops,
    # Categorical exposure type
    exposure_type = sample(c("TypeA", "TypeB", "TypeC"), n_periods, replace = TRUE),
    exposure_category = sample(1:4, n_periods, replace = TRUE),
    # Continuous dose
    daily_dose = round(runif(n_periods, min = 5, max = 150), 1),
    # Continuous intensity score
    intensity = round(runif(n_periods, min = 0, max = 1), 3),
    # Categorical severity
    severity = sample(c("mild", "moderate", "severe"), n_periods, replace = TRUE),
    stringsAsFactors = FALSE
  )
}))

# Remove NULL entries
exposure_mixed <- exposure_mixed[!is.na(exposure_mixed$id), ]

save_data(exposure_mixed, "exposure_mixed",
          "Mixed categorical and continuous exposure variables")

cat("\n")

# ============================================================================
# ADDITIONAL SPECIALIZED DATASETS
# ============================================================================

cat("Generating Additional Specialized Datasets\n")
cat(paste(rep("-", 78), collapse = ""), "\n", sep = "")

# 11. Exposure for testing grace periods (small gaps)
exposure_grace_test <- data.frame()
for (pid in sample(cohort_basic$id, 20)) {
  person_entry <- cohort_basic$study_entry[cohort_basic$id == pid]
  person_exit <- cohort_basic$study_exit[cohort_basic$id == pid]

  # Create 3 periods with specific gap sizes
  gaps <- c(10, 30, 90)  # days

  start1 <- person_entry + 60
  stop1 <- start1 + 90

  start2 <- stop1 + gaps[1]
  stop2 <- start2 + 90

  start3 <- stop2 + gaps[2]
  stop3 <- start3 + 90

  if (stop3 > person_exit) next

  exposure_grace_test <- rbind(exposure_grace_test, data.frame(
    id = pid,
    exp_start = c(start1, start2, start3),
    exp_stop = c(stop1, stop2, stop3),
    exposure = c(1, 1, 1),
    gap_before = c(NA, gaps[1], gaps[2]),
    stringsAsFactors = FALSE
  ))
}

save_data(exposure_grace_test, "exposure_grace_test",
          "Specific gap sizes (10, 30, 90 days) for grace period testing")

# 12. Exposure for testing lag and washout
exposure_lag_washout <- data.frame()
for (pid in sample(cohort_basic$id, 25)) {
  person_entry <- cohort_basic$study_entry[cohort_basic$id == pid]
  person_exit <- cohort_basic$study_exit[cohort_basic$id == pid]

  start <- person_entry + 180
  stop <- start + 365

  if (stop + 180 > person_exit) next

  exposure_lag_washout <- rbind(exposure_lag_washout, data.frame(
    id = pid,
    exp_start = start,
    exp_stop = stop,
    exposure = 1,
    expected_lag_days = 30,
    expected_washout_days = 60,
    stringsAsFactors = FALSE
  ))
}

save_data(exposure_lag_washout, "exposure_lag_washout",
          "Single long exposure for testing lag and washout parameters")

# 13. Exposure for testing switching
exposure_switching <- data.frame()
for (pid in sample(cohort_basic$id, 30)) {
  person_entry <- cohort_basic$study_entry[cohort_basic$id == pid]
  person_exit <- cohort_basic$study_exit[cohort_basic$id == pid]

  # Create sequence of different exposure types (switching pattern)
  types <- c(1, 2, 3, 2, 1, 3)
  n_switches <- sample(2:6, 1)
  type_sequence <- types[1:n_switches]

  starts <- seq(person_entry + 60,
               by = as.numeric(person_exit - person_entry) / (n_switches + 1),
               length.out = n_switches)
  durations <- rep(60, n_switches)
  stops <- starts + durations

  if (any(stops > person_exit)) next

  exposure_switching <- rbind(exposure_switching, data.frame(
    id = pid,
    exp_start = starts,
    exp_stop = stops,
    exposure = type_sequence,
    switch_number = 1:n_switches,
    stringsAsFactors = FALSE
  ))
}

save_data(exposure_switching, "exposure_switching",
          "Patterns of switching between exposure types")

# 14. Duration-based exposure (for testing duration parameter)
exposure_duration_test <- data.frame()
for (pid in sample(cohort_basic$id, 40)) {
  person_entry <- cohort_basic$study_entry[cohort_basic$id == pid]
  person_exit <- cohort_basic$study_exit[cohort_basic$id == pid]

  # Create exposures of varying cumulative duration
  # Short: <6 months, Medium: 6-18 months, Long: >18 months
  duration_type <- sample(c("short", "medium", "long"), 1)

  if (duration_type == "short") {
    n_periods <- sample(1:2, 1)
    period_lengths <- sample(30:90, n_periods)
  } else if (duration_type == "medium") {
    n_periods <- sample(2:4, 1)
    period_lengths <- sample(60:180, n_periods)
  } else {
    n_periods <- sample(3:6, 1)
    period_lengths <- sample(90:365, n_periods)
  }

  cumulative_duration <- sum(period_lengths)

  starts <- sort(person_entry + sample(30:200, n_periods))
  stops <- pmin(starts + period_lengths, person_exit)

  if (any(stops > person_exit)) next

  exposure_duration_test <- rbind(exposure_duration_test, data.frame(
    id = pid,
    exp_start = starts,
    exp_stop = stops,
    exposure = 1,
    duration_category = duration_type,
    cumulative_days = cumulative_duration,
    stringsAsFactors = FALSE
  ))
}

save_data(exposure_duration_test, "exposure_duration_test",
          "Varying cumulative exposure durations for duration-based analysis")

cat("\n")

# ============================================================================
# SUMMARY REPORT
# ============================================================================

cat(paste(rep("=", 78), collapse = ""), "\n", sep = "")
cat("TEST DATA GENERATION COMPLETE\n")
cat(paste(rep("=", 78), collapse = ""), "\n\n", sep = "")

# List all generated files
csv_files <- list.files(output_dir, pattern = "\\.csv$", full.names = FALSE)
rds_files <- list.files(output_dir, pattern = "\\.rds$", full.names = FALSE)

cat("Generated", length(csv_files), "CSV files\n")
cat("Generated", length(rds_files), "RDS files\n")
cat("Total files:", length(csv_files) + length(rds_files), "\n\n")

cat("Output location:", output_dir, "\n\n")

cat("Dataset Categories:\n")
cat("  1. Basic cohort data (cohort_basic)\n")
cat("  2. Simple exposures (exposure_simple)\n")
cat("  3. Exposures with gaps (exposure_gaps)\n")
cat("  4. Overlapping exposures (exposure_overlap)\n")
cat("  5. Multiple exposure types (exposure_multi_types)\n")
cat("  6. Point-in-time events (exposure_point_time)\n")
cat("  7. Edge cases (exposure_edge_cases, exposure_missing_cohort)\n")
cat("  8. Large datasets (cohort_large, exposure_large)\n")
cat("  9. Continuous exposures (exposure_continuous)\n")
cat(" 10. Mixed categorical/continuous (exposure_mixed)\n")
cat(" 11. Specialized: grace periods, lag/washout, switching, duration\n")

cat("\n")
cat(paste(rep("=", 78), collapse = ""), "\n", sep = "")
cat("All datasets ready for testing!\n")
cat(paste(rep("=", 78), collapse = ""), "\n", sep = "")
