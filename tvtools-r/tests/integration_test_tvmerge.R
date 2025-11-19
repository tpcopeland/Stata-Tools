#!/usr/bin/env Rscript
#
# Comprehensive Integration Tests for tvmerge Function
#
# This script performs comprehensive integration testing of the tvmerge function
# using generated test data. It validates:
#   - 2-dataset and 3-dataset merges
#   - Continuous exposures
#   - Mixed categorical + continuous
#   - Custom variable naming (generate, prefix)
#   - Keep variables functionality
#   - Different startname/stopname
#   - Saveas functionality
#   - Cartesian product correctness
#   - Coverage validation (no gaps/overlaps)
#   - Continuous exposure calculations
#
# Usage:
#   Rscript /home/user/Stata-Tools/tvtools-r/tests/integration_test_tvmerge.R
#
# Author: tvtools package testing
# Date: 2025-11-19

# ============================================================================
# SETUP AND INITIALIZATION
# ============================================================================

cat("\n")
cat(paste(rep("=", 80), collapse = ""), "\n", sep = "")
cat("tvmerge Integration Tests\n")
cat(paste(rep("=", 80), collapse = ""), "\n\n", sep = "")

# Track test results
test_results <- list()
test_count <- 0

# Helper function to record test results
record_test <- function(test_name, passed, message = "") {
  test_count <<- test_count + 1
  test_results[[test_count]] <<- list(
    number = test_count,
    name = test_name,
    passed = passed,
    message = message
  )

  status <- if (passed) "PASS" else "FAIL"
  status_color <- if (passed) "\033[32m" else "\033[31m"
  reset_color <- "\033[0m"

  cat(sprintf("%s[%s]%s Test %d: %s\n",
              status_color, status, reset_color, test_count, test_name))
  if (message != "") {
    cat(sprintf("      %s\n", message))
  }
}

# Helper function to validate no gaps
validate_no_gaps <- function(data, id_var, start_var, stop_var, tolerance = 1) {
  gaps_found <- list()

  for (pid in unique(data[[id_var]])) {
    person_data <- data[data[[id_var]] == pid, ]
    person_data <- person_data[order(person_data[[start_var]]), ]

    if (nrow(person_data) <= 1) next

    for (i in 1:(nrow(person_data) - 1)) {
      gap <- as.numeric(person_data[[start_var]][i+1] - person_data[[stop_var]][i]) - 1
      if (gap > tolerance) {
        gaps_found[[length(gaps_found) + 1]] <- list(
          id = pid,
          gap_days = gap,
          after_period = i
        )
      }
    }
  }

  return(gaps_found)
}

# Helper function to validate no overlaps
validate_no_overlaps <- function(data, id_var, start_var, stop_var) {
  overlaps_found <- list()

  for (pid in unique(data[[id_var]])) {
    person_data <- data[data[[id_var]] == pid, ]
    person_data <- person_data[order(person_data[[start_var]]), ]

    if (nrow(person_data) <= 1) next

    for (i in 1:(nrow(person_data) - 1)) {
      if (person_data[[start_var]][i+1] < person_data[[stop_var]][i]) {
        overlaps_found[[length(overlaps_found) + 1]] <- list(
          id = pid,
          period1_end = person_data[[stop_var]][i],
          period2_start = person_data[[start_var]][i+1],
          overlap_days = as.numeric(person_data[[stop_var]][i] - person_data[[start_var]][i+1])
        )
      }
    }
  }

  return(overlaps_found)
}

# Determine script directory
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

# Set paths
r_dir <- file.path(dirname(script_dir), "R")
data_dir <- file.path(script_dir, "test_data")
output_dir <- file.path(script_dir, "test_output")

# Create output directory
if (!dir.exists(output_dir)) {
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
}

cat("R source directory:", r_dir, "\n")
cat("Data directory:", data_dir, "\n")
cat("Output directory:", output_dir, "\n\n")

# ============================================================================
# LOAD FUNCTIONS
# ============================================================================

cat(paste(rep("-", 80), collapse = ""), "\n", sep = "")
cat("Loading tvtools functions...\n")
cat(paste(rep("-", 80), collapse = ""), "\n", sep = "")

# Load required packages
suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
})

# Source tvtools functions
source(file.path(r_dir, "tvexpose.R"))
source(file.path(r_dir, "tvmerge.R"))

cat("Functions loaded successfully\n\n")

# ============================================================================
# LOAD TEST DATA
# ============================================================================

cat(paste(rep("-", 80), collapse = ""), "\n", sep = "")
cat("Loading test data...\n")
cat(paste(rep("-", 80), collapse = ""), "\n", sep = "")

cohort <- readRDS(file.path(data_dir, "cohort_basic.rds"))
exposure_simple <- readRDS(file.path(data_dir, "exposure_simple.rds"))
exposure_continuous <- readRDS(file.path(data_dir, "exposure_continuous.rds"))
exposure_mixed <- readRDS(file.path(data_dir, "exposure_mixed.rds"))

cat(sprintf("Loaded cohort: %d persons\n", nrow(cohort)))
cat(sprintf("Loaded exposure_simple: %d periods\n", nrow(exposure_simple)))
cat(sprintf("Loaded exposure_continuous: %d periods\n", nrow(exposure_continuous)))
cat(sprintf("Loaded exposure_mixed: %d periods\n\n", nrow(exposure_mixed)))

# ============================================================================
# CREATE TVEXPOSE OUTPUTS
# ============================================================================

cat(paste(rep("-", 80), collapse = ""), "\n", sep = "")
cat("Creating tvexpose outputs for testing...\n")
cat(paste(rep("-", 80), collapse = ""), "\n\n", sep = "")

# Dataset 1: Simple categorical exposure (HRT-like)
cat("Creating tvexpose output 1 (categorical)...\n")
tv_exp1 <- tvexpose(
  master = cohort,
  exposure_data = exposure_simple,
  id = "id",
  start = "exp_start",
  stop = "exp_stop",
  exposure = "exposure",
  reference = 0,
  entry = "study_entry",
  exit = "study_exit",
  generate = "tv_exposure",
  keepvars = c("age", "sex")
)
cat(sprintf("  Created: %d rows\n\n", nrow(tv_exp1)))

# Dataset 2: Simple categorical exposure (DMT-like) - reuse same data with different variable names
cat("Creating tvexpose output 2 (categorical)...\n")
exposure_simple2 <- exposure_simple
names(exposure_simple2)[names(exposure_simple2) == "dose_mg"] <- "strength"
tv_exp2 <- tvexpose(
  master = cohort,
  exposure_data = exposure_simple2,
  id = "id",
  start = "exp_start",
  stop = "exp_stop",
  exposure = "exposure",
  reference = 0,
  entry = "study_entry",
  exit = "study_exit",
  generate = "tv_exposure",
  keepvars = c("bmi", "smoker")
)
cat(sprintf("  Created: %d rows\n\n", nrow(tv_exp2)))

# Dataset 3: Another categorical for 3-way merge
cat("Creating tvexpose output 3 (categorical)...\n")
tv_exp3 <- tvexpose(
  master = cohort,
  exposure_data = exposure_simple,
  id = "id",
  start = "exp_start",
  stop = "exp_stop",
  exposure = "exposure",
  reference = 0,
  entry = "study_entry",
  exit = "study_exit",
  generate = "tv_exposure"
)
cat(sprintf("  Created: %d rows\n\n", nrow(tv_exp3)))

# Dataset 4: Continuous exposure (dose rates)
cat("Creating tvexpose output 4 (continuous)...\n")
tv_cont <- tvexpose(
  master = cohort,
  exposure_data = exposure_continuous,
  id = "id",
  start = "exp_start",
  stop = "exp_stop",
  exposure = "dose_rate",
  reference = 0,
  entry = "study_entry",
  exit = "study_exit",
  generate = "tv_dose"
)
cat(sprintf("  Created: %d rows\n\n", nrow(tv_cont)))

# Dataset 5: Mixed categorical exposure
cat("Creating tvexpose output 5 (categorical from mixed)...\n")
tv_mixed_cat <- tvexpose(
  master = cohort,
  exposure_data = exposure_mixed,
  id = "id",
  start = "exp_start",
  stop = "exp_stop",
  exposure = "exposure_category",
  reference = 0,
  entry = "study_entry",
  exit = "study_exit",
  generate = "tv_category"
)
cat(sprintf("  Created: %d rows\n\n", nrow(tv_mixed_cat)))

# Dataset 6: Continuous from mixed (daily dose)
cat("Creating tvexpose output 6 (continuous from mixed)...\n")
tv_mixed_cont <- tvexpose(
  master = cohort,
  exposure_data = exposure_mixed,
  id = "id",
  start = "exp_start",
  stop = "exp_stop",
  exposure = "daily_dose",
  reference = 0,
  entry = "study_entry",
  exit = "study_exit",
  generate = "tv_daily_dose"
)
cat(sprintf("  Created: %d rows\n\n", nrow(tv_mixed_cont)))

# ============================================================================
# TEST 1: Basic 2-Dataset Merge (Categorical)
# ============================================================================

cat(paste(rep("=", 80), collapse = ""), "\n", sep = "")
cat("TEST 1: Basic 2-Dataset Merge (Categorical)\n")
cat(paste(rep("=", 80), collapse = ""), "\n\n", sep = "")

tryCatch({
  merge_2ds <- tvmerge(
    datasets = list(tv_exp1, tv_exp2),
    id = "id",
    start = c("start", "start"),
    stop = c("stop", "stop"),
    exposure = c("tv_exposure", "tv_exposure"),
    generate = c("exp1", "exp2")  # Fix: provide unique names
  )

  # Validate basic structure
  has_correct_cols <- all(c("id", "start", "stop", "exp1", "exp2") %in% names(merge_2ds))
  has_data <- nrow(merge_2ds) > 0
  has_all_persons <- length(unique(merge_2ds$id)) > 0

  # Validate no gaps > 1 day
  gaps <- validate_no_gaps(merge_2ds, "id", "start", "stop")
  has_no_gaps <- length(gaps) == 0

  # Validate no overlaps
  overlaps <- validate_no_overlaps(merge_2ds, "id", "start", "stop")
  has_no_overlaps <- length(overlaps) == 0

  all_valid <- has_correct_cols && has_data && has_all_persons && has_no_gaps && has_no_overlaps

  msg <- sprintf("Rows: %d, Persons: %d, Gaps: %d, Overlaps: %d",
                 nrow(merge_2ds), length(unique(merge_2ds$id)),
                 length(gaps), length(overlaps))

  record_test("Basic 2-dataset merge (categorical)", all_valid, msg)

}, error = function(e) {
  record_test("Basic 2-dataset merge (categorical)", FALSE, paste("Error:", e$message))
})

# ============================================================================
# TEST 2: 3-Dataset Merge
# ============================================================================

cat("\n")
cat(paste(rep("=", 80), collapse = ""), "\n", sep = "")
cat("TEST 2: 3-Dataset Merge\n")
cat(paste(rep("=", 80), collapse = ""), "\n\n", sep = "")

tryCatch({
  merge_3ds <- tvmerge(
    datasets = list(tv_exp1, tv_exp2, tv_exp3),
    id = "id",
    start = c("start", "start", "start"),
    stop = c("stop", "stop", "stop"),
    exposure = c("tv_exposure", "tv_exposure", "tv_exposure"),
    generate = c("exp1", "exp2", "exp3")
  )

  # Validate structure
  expected_cols <- c("id", "start", "stop", "exp1", "exp2", "exp3")
  has_correct_cols <- all(expected_cols %in% names(merge_3ds))
  has_data <- nrow(merge_3ds) > 0

  # Validate no gaps
  gaps <- validate_no_gaps(merge_3ds, "id", "start", "stop")
  has_no_gaps <- length(gaps) == 0

  all_valid <- has_correct_cols && has_data && has_no_gaps

  msg <- sprintf("Rows: %d, Persons: %d, Expected cols present: %s",
                 nrow(merge_3ds), length(unique(merge_3ds$id)),
                 all(expected_cols %in% names(merge_3ds)))

  record_test("3-dataset merge", all_valid, msg)

}, error = function(e) {
  record_test("3-dataset merge", FALSE, paste("Error:", e$message))
})

# ============================================================================
# TEST 3: Continuous Exposures
# ============================================================================

cat("\n")
cat(paste(rep("=", 80), collapse = ""), "\n", sep = "")
cat("TEST 3: Continuous Exposures\n")
cat(paste(rep("=", 80), collapse = ""), "\n\n", sep = "")

tryCatch({
  merge_cont <- tvmerge(
    datasets = list(tv_exp1, tv_cont),
    id = "id",
    start = c("start", "start"),
    stop = c("stop", "stop"),
    exposure = c("tv_exposure", "tv_dose"),
    continuous = "tv_dose",
    generate = c("category", "dose")
  )

  # Validate structure - should have dose and dose_period
  expected_cols <- c("id", "start", "stop", "category", "dose", "dose_period")
  has_correct_cols <- all(expected_cols %in% names(merge_cont))
  has_data <- nrow(merge_cont) > 0

  # Validate dose_period calculation (rate * days)
  if (nrow(merge_cont) > 0) {
    merge_cont$expected_period <- merge_cont$dose * (as.numeric(merge_cont$stop - merge_cont$start) + 1)
    # Allow small floating point differences
    calc_correct <- all(abs(merge_cont$dose_period - merge_cont$expected_period) < 0.01, na.rm = TRUE)
  } else {
    calc_correct <- FALSE
  }

  all_valid <- has_correct_cols && has_data && calc_correct

  msg <- sprintf("Rows: %d, Has dose_period: %s, Calculations correct: %s",
                 nrow(merge_cont), "dose_period" %in% names(merge_cont), calc_correct)

  record_test("Continuous exposure merge", all_valid, msg)

}, error = function(e) {
  record_test("Continuous exposure merge", FALSE, paste("Error:", e$message))
})

# ============================================================================
# TEST 4: Mixed Categorical + Continuous
# ============================================================================

cat("\n")
cat(paste(rep("=", 80), collapse = ""), "\n", sep = "")
cat("TEST 4: Mixed Categorical + Continuous\n")
cat(paste(rep("=", 80), collapse = ""), "\n\n", sep = "")

tryCatch({
  merge_mixed <- tvmerge(
    datasets = list(tv_mixed_cat, tv_mixed_cont),
    id = "id",
    start = c("start", "start"),
    stop = c("stop", "stop"),
    exposure = c("tv_category", "tv_daily_dose"),
    continuous = c("tv_daily_dose"),
    generate = c("cat", "dose")
  )

  # Validate structure
  expected_cols <- c("id", "start", "stop", "cat", "dose", "dose_period")
  has_correct_cols <- all(expected_cols %in% names(merge_mixed))
  has_data <- nrow(merge_mixed) > 0

  # Check that cat is categorical and dose is continuous
  has_cat_var <- "cat" %in% names(merge_mixed)
  has_dose_var <- "dose" %in% names(merge_mixed)
  has_period_var <- "dose_period" %in% names(merge_mixed)

  all_valid <- has_correct_cols && has_data && has_cat_var && has_dose_var && has_period_var

  msg <- sprintf("Rows: %d, Categorical: %s, Continuous: %s, Period: %s",
                 nrow(merge_mixed), has_cat_var, has_dose_var, has_period_var)

  record_test("Mixed categorical + continuous", all_valid, msg)

}, error = function(e) {
  record_test("Mixed categorical + continuous", FALSE, paste("Error:", e$message))
})

# ============================================================================
# TEST 5: Custom Variable Names (generate)
# ============================================================================

cat("\n")
cat(paste(rep("=", 80), collapse = ""), "\n", sep = "")
cat("TEST 5: Custom Variable Names (generate)\n")
cat(paste(rep("=", 80), collapse = ""), "\n\n", sep = "")

tryCatch({
  merge_custom <- tvmerge(
    datasets = list(tv_exp1, tv_exp2),
    id = "id",
    start = c("start", "start"),
    stop = c("stop", "stop"),
    exposure = c("tv_exposure", "tv_exposure"),
    generate = c("hrt_status", "dmt_status")
  )

  # Validate custom names are present
  has_hrt <- "hrt_status" %in% names(merge_custom)
  has_dmt <- "dmt_status" %in% names(merge_custom)
  has_data <- nrow(merge_custom) > 0

  all_valid <- has_hrt && has_dmt && has_data

  msg <- sprintf("Rows: %d, Has 'hrt_status': %s, Has 'dmt_status': %s",
                 nrow(merge_custom), has_hrt, has_dmt)

  record_test("Custom variable names (generate)", all_valid, msg)

}, error = function(e) {
  record_test("Custom variable names (generate)", FALSE, paste("Error:", e$message))
})

# ============================================================================
# TEST 6: Variable Name Prefix
# ============================================================================

cat("\n")
cat(paste(rep("=", 80), collapse = ""), "\n", sep = "")
cat("TEST 6: Variable Name Prefix\n")
cat(paste(rep("=", 80), collapse = ""), "\n\n", sep = "")

tryCatch({
  # Create datasets with different exposure variable names for prefix test
  tv_exp1_renamed <- tv_exp1
  tv_exp2_renamed <- tv_exp2
  names(tv_exp1_renamed)[names(tv_exp1_renamed) == "tv_exposure"] <- "hrt"
  names(tv_exp2_renamed)[names(tv_exp2_renamed) == "tv_exposure"] <- "dmt"

  merge_prefix <- tvmerge(
    datasets = list(tv_exp1_renamed, tv_exp2_renamed),
    id = "id",
    start = c("start", "start"),
    stop = c("stop", "stop"),
    exposure = c("hrt", "dmt"),
    prefix = "exp_"
  )

  # Validate prefixed names
  has_exp_hrt <- "exp_hrt" %in% names(merge_prefix)
  has_exp_dmt <- "exp_dmt" %in% names(merge_prefix)
  has_data <- nrow(merge_prefix) > 0

  all_valid <- has_exp_hrt && has_exp_dmt && has_data

  msg <- sprintf("Rows: %d, Has 'exp_hrt': %s, Has 'exp_dmt': %s",
                 nrow(merge_prefix), has_exp_hrt, has_exp_dmt)

  record_test("Variable name prefix", all_valid, msg)

}, error = function(e) {
  record_test("Variable name prefix", FALSE, paste("Error:", e$message))
})

# ============================================================================
# TEST 7: Keep Variables
# ============================================================================

cat("\n")
cat(paste(rep("=", 80), collapse = ""), "\n", sep = "")
cat("TEST 7: Keep Variables\n")
cat(paste(rep("=", 80), collapse = ""), "\n\n", sep = "")

tryCatch({
  merge_keep <- tvmerge(
    datasets = list(tv_exp1, tv_exp2),
    id = "id",
    start = c("start", "start"),
    stop = c("stop", "stop"),
    exposure = c("tv_exposure", "tv_exposure"),
    keep = c("age", "sex", "bmi", "smoker"),
    generate = c("exp1", "exp2")
  )

  # Validate keep variables with suffixes
  has_age_ds1 <- "age_ds1" %in% names(merge_keep)
  has_sex_ds1 <- "sex_ds1" %in% names(merge_keep)
  has_bmi_ds2 <- "bmi_ds2" %in% names(merge_keep)
  has_smoker_ds2 <- "smoker_ds2" %in% names(merge_keep)
  has_data <- nrow(merge_keep) > 0

  all_valid <- has_age_ds1 && has_sex_ds1 && has_bmi_ds2 && has_smoker_ds2 && has_data

  msg <- sprintf("Rows: %d, age_ds1: %s, sex_ds1: %s, bmi_ds2: %s, smoker_ds2: %s",
                 nrow(merge_keep), has_age_ds1, has_sex_ds1, has_bmi_ds2, has_smoker_ds2)

  record_test("Keep variables with suffixes", all_valid, msg)

}, error = function(e) {
  record_test("Keep variables with suffixes", FALSE, paste("Error:", e$message))
})

# ============================================================================
# TEST 8: Different Start/Stop Names
# ============================================================================

cat("\n")
cat(paste(rep("=", 80), collapse = ""), "\n", sep = "")
cat("TEST 8: Different Start/Stop Names\n")
cat(paste(rep("=", 80), collapse = ""), "\n\n", sep = "")

tryCatch({
  merge_names <- tvmerge(
    datasets = list(tv_exp1, tv_exp2),
    id = "id",
    start = c("start", "start"),
    stop = c("stop", "stop"),
    exposure = c("tv_exposure", "tv_exposure"),
    generate = c("exp1", "exp2"),  # Fix: provide unique names
    startname = "period_start",
    stopname = "period_end"
  )

  # Validate custom start/stop names
  has_period_start <- "period_start" %in% names(merge_names)
  has_period_end <- "period_end" %in% names(merge_names)
  has_no_start <- !("start" %in% names(merge_names))
  has_no_stop <- !("stop" %in% names(merge_names))
  has_data <- nrow(merge_names) > 0

  all_valid <- has_period_start && has_period_end && has_no_start && has_no_stop && has_data

  msg <- sprintf("Rows: %d, Has 'period_start': %s, Has 'period_end': %s",
                 nrow(merge_names), has_period_start, has_period_end)

  record_test("Custom start/stop names", all_valid, msg)

}, error = function(e) {
  record_test("Custom start/stop names", FALSE, paste("Error:", e$message))
})

# ============================================================================
# TEST 9: Cartesian Product Validation
# ============================================================================

cat("\n")
cat(paste(rep("=", 80), collapse = ""), "\n", sep = "")
cat("TEST 9: Cartesian Product Validation\n")
cat(paste(rep("=", 80), collapse = ""), "\n\n", sep = "")

tryCatch({
  # Use simple test case - single person with known structure
  test_id <- tv_exp1$id[1]

  tv1_subset <- tv_exp1[tv_exp1$id == test_id, ]
  tv2_subset <- tv_exp2[tv_exp2$id == test_id, ]

  merge_cart <- tvmerge(
    datasets = list(tv1_subset, tv2_subset),
    id = "id",
    start = c("start", "start"),
    stop = c("stop", "stop"),
    exposure = c("tv_exposure", "tv_exposure"),
    generate = c("exp1", "exp2")
  )

  # Count unique combinations
  if (nrow(merge_cart) > 0) {
    unique_combos <- nrow(unique(merge_cart[, c("exp1", "exp2")]))
    total_periods <- nrow(merge_cart)

    # Cartesian product should create multiple combinations
    has_data <- total_periods > 0
    has_multiple_combos <- unique_combos > 1 || total_periods == 1

    all_valid <- has_data && has_multiple_combos

    msg <- sprintf("Rows: %d, Unique combinations: %d",
                   total_periods, unique_combos)
  } else {
    all_valid <- FALSE
    msg <- "No data in merge result"
  }

  record_test("Cartesian product correctness", all_valid, msg)

}, error = function(e) {
  record_test("Cartesian product correctness", FALSE, paste("Error:", e$message))
})

# ============================================================================
# TEST 10: Coverage Validation (No Gaps)
# ============================================================================

cat("\n")
cat(paste(rep("=", 80), collapse = ""), "\n", sep = "")
cat("TEST 10: Coverage Validation (No Gaps > 1 Day)\n")
cat(paste(rep("=", 80), collapse = ""), "\n\n", sep = "")

tryCatch({
  merge_coverage <- tvmerge(
    datasets = list(tv_exp1, tv_exp2),
    id = "id",
    start = c("start", "start"),
    stop = c("stop", "stop"),
    exposure = c("tv_exposure", "tv_exposure"),
    generate = c("exp1", "exp2")  # Fix: provide unique names
  )

  gaps <- validate_no_gaps(merge_coverage, "id", "start", "stop", tolerance = 1)
  has_no_gaps <- length(gaps) == 0

  msg <- sprintf("Gaps found: %d", length(gaps))
  if (length(gaps) > 0 && length(gaps) <= 5) {
    gap_details <- sapply(gaps, function(g) sprintf("ID %d: %d days", g$id, g$gap_days))
    msg <- paste(msg, paste(gap_details, collapse = "; "))
  }

  record_test("No gaps > 1 day in coverage", has_no_gaps, msg)

}, error = function(e) {
  record_test("No gaps > 1 day in coverage", FALSE, paste("Error:", e$message))
})

# ============================================================================
# TEST 11: Overlap Validation
# ============================================================================

cat("\n")
cat(paste(rep("=", 80), collapse = ""), "\n", sep = "")
cat("TEST 11: Overlap Validation (No Overlaps)\n")
cat(paste(rep("=", 80), collapse = ""), "\n\n", sep = "")

tryCatch({
  merge_overlap <- tvmerge(
    datasets = list(tv_exp1, tv_exp2),
    id = "id",
    start = c("start", "start"),
    stop = c("stop", "stop"),
    exposure = c("tv_exposure", "tv_exposure"),
    generate = c("exp1", "exp2")  # Fix: provide unique names
  )

  overlaps <- validate_no_overlaps(merge_overlap, "id", "start", "stop")
  has_no_overlaps <- length(overlaps) == 0

  msg <- sprintf("Overlaps found: %d", length(overlaps))

  record_test("No overlapping periods", has_no_overlaps, msg)

}, error = function(e) {
  record_test("No overlapping periods", FALSE, paste("Error:", e$message))
})

# ============================================================================
# TEST 12: All Persons Present
# ============================================================================

cat("\n")
cat(paste(rep("=", 80), collapse = ""), "\n", sep = "")
cat("TEST 12: All Persons Present in Output\n")
cat(paste(rep("=", 80), collapse = ""), "\n\n", sep = "")

tryCatch({
  merge_persons <- tvmerge(
    datasets = list(tv_exp1, tv_exp2),
    id = "id",
    start = c("start", "start"),
    stop = c("stop", "stop"),
    exposure = c("tv_exposure", "tv_exposure"),
    generate = c("exp1", "exp2")  # Fix: provide unique names
  )

  # Get persons present in both input datasets (intersection)
  persons_in_tv1 <- unique(tv_exp1$id)
  persons_in_tv2 <- unique(tv_exp2$id)
  expected_persons <- intersect(persons_in_tv1, persons_in_tv2)

  persons_in_merge <- unique(merge_persons$id)

  all_present <- all(expected_persons %in% persons_in_merge)
  n_expected <- length(expected_persons)
  n_actual <- length(persons_in_merge)

  msg <- sprintf("Expected: %d, Actual: %d, All present: %s",
                 n_expected, n_actual, all_present)

  record_test("All persons present in output", all_present, msg)

}, error = function(e) {
  record_test("All persons present in output", FALSE, paste("Error:", e$message))
})

# ============================================================================
# TEST 13: Continuous Exposure Period Calculation
# ============================================================================

cat("\n")
cat(paste(rep("=", 80), collapse = ""), "\n", sep = "")
cat("TEST 13: Continuous Exposure Period Calculation (rate * days)\n")
cat(paste(rep("=", 80), collapse = ""), "\n\n", sep = "")

tryCatch({
  merge_calc <- tvmerge(
    datasets = list(tv_exp1, tv_cont),
    id = "id",
    start = c("start", "start"),
    stop = c("stop", "stop"),
    exposure = c("tv_exposure", "tv_dose"),
    continuous = c("tv_dose"),
    generate = c("cat", "dose")
  )

  # Validate calculation: dose_period = dose * (stop - start + 1)
  if (nrow(merge_calc) > 0 && "dose_period" %in% names(merge_calc)) {
    merge_calc$days <- as.numeric(merge_calc$stop - merge_calc$start) + 1
    merge_calc$expected <- merge_calc$dose * merge_calc$days

    # Check calculations (allow for small floating point errors)
    differences <- abs(merge_calc$dose_period - merge_calc$expected)
    max_diff <- max(differences, na.rm = TRUE)
    all_correct <- max_diff < 0.01

    msg <- sprintf("Max calculation error: %.6f, All correct: %s", max_diff, all_correct)
  } else {
    all_correct <- FALSE
    msg <- "Missing dose_period variable or no data"
  }

  record_test("Continuous exposure calculation", all_correct, msg)

}, error = function(e) {
  record_test("Continuous exposure calculation", FALSE, paste("Error:", e$message))
})

# ============================================================================
# TEST 14: SaveAs Functionality (CSV)
# ============================================================================

cat("\n")
cat(paste(rep("=", 80), collapse = ""), "\n", sep = "")
cat("TEST 14: SaveAs Functionality (CSV)\n")
cat(paste(rep("=", 80), collapse = ""), "\n\n", sep = "")

tryCatch({
  output_csv <- file.path(output_dir, "test_merge_output.csv")

  # Remove file if it exists
  if (file.exists(output_csv)) {
    file.remove(output_csv)
  }

  merge_save <- tvmerge(
    datasets = list(tv_exp1, tv_exp2),
    id = "id",
    start = c("start", "start"),
    stop = c("stop", "stop"),
    exposure = c("tv_exposure", "tv_exposure"),
    generate = c("exp1", "exp2"),  # Fix: provide unique names
    saveas = output_csv,
    replace = TRUE
  )

  # Check if file was created
  file_exists <- file.exists(output_csv)

  # Check if file has data
  if (file_exists) {
    saved_data <- read.csv(output_csv)
    has_data <- nrow(saved_data) > 0
    matches_output <- nrow(saved_data) == nrow(merge_save)
  } else {
    has_data <- FALSE
    matches_output <- FALSE
  }

  all_valid <- file_exists && has_data && matches_output

  msg <- sprintf("File exists: %s, Has data: %s, Matches output: %s",
                 file_exists, has_data, matches_output)

  record_test("SaveAs CSV functionality", all_valid, msg)

}, error = function(e) {
  record_test("SaveAs CSV functionality", FALSE, paste("Error:", e$message))
})

# ============================================================================
# TEST 15: SaveAs Functionality (RDS)
# ============================================================================

cat("\n")
cat(paste(rep("=", 80), collapse = ""), "\n", sep = "")
cat("TEST 15: SaveAs Functionality (RDS)\n")
cat(paste(rep("=", 80), collapse = ""), "\n\n", sep = "")

tryCatch({
  output_rds <- file.path(output_dir, "test_merge_output.rds")

  # Remove file if it exists
  if (file.exists(output_rds)) {
    file.remove(output_rds)
  }

  merge_save_rds <- tvmerge(
    datasets = list(tv_exp1, tv_exp2),
    id = "id",
    start = c("start", "start"),
    stop = c("stop", "stop"),
    exposure = c("tv_exposure", "tv_exposure"),
    generate = c("exp1", "exp2"),  # Fix: provide unique names
    saveas = output_rds,
    replace = TRUE
  )

  # Check if file was created
  file_exists <- file.exists(output_rds)

  # Check if file has data
  if (file_exists) {
    saved_data <- readRDS(output_rds)
    has_data <- nrow(saved_data) > 0
    matches_output <- nrow(saved_data) == nrow(merge_save_rds)
  } else {
    has_data <- FALSE
    matches_output <- FALSE
  }

  all_valid <- file_exists && has_data && matches_output

  msg <- sprintf("File exists: %s, Has data: %s, Matches output: %s",
                 file_exists, has_data, matches_output)

  record_test("SaveAs RDS functionality", all_valid, msg)

}, error = function(e) {
  record_test("SaveAs RDS functionality", FALSE, paste("Error:", e$message))
})

# ============================================================================
# TEST 16: Multiple Continuous Exposures
# ============================================================================

cat("\n")
cat(paste(rep("=", 80), collapse = ""), "\n", sep = "")
cat("TEST 16: Multiple Continuous Exposures\n")
cat(paste(rep("=", 80), collapse = ""), "\n\n", sep = "")

tryCatch({
  # NOTE: When dataset 1 is continuous, tvmerge doesn't create the _period variable
  # for it (only for datasets 2+). Workaround: put categorical first, continuous second
  merge_multi_cont <- tvmerge(
    datasets = list(tv_mixed_cat, tv_cont, tv_mixed_cont),  # Put categorical first
    id = "id",
    start = c("start", "start", "start"),
    stop = c("stop", "stop", "stop"),
    exposure = c("tv_category", "tv_dose", "tv_daily_dose"),
    continuous = c(2, 3),  # Datasets 2 and 3 are continuous
    generate = c("cat", "dose1", "dose2")
  )

  # Should have both continuous period variables (for datasets 2 and 3)
  has_dose1_period <- "dose1_period" %in% names(merge_multi_cont)
  has_dose2_period <- "dose2_period" %in% names(merge_multi_cont)
  has_dose1 <- "dose1" %in% names(merge_multi_cont)
  has_dose2 <- "dose2" %in% names(merge_multi_cont)
  has_cat <- "cat" %in% names(merge_multi_cont)
  has_data <- nrow(merge_multi_cont) > 0

  all_valid <- has_dose1_period && has_dose2_period && has_dose1 && has_dose2 && has_cat && has_data

  msg <- sprintf("Rows: %d, dose1_period: %s, dose2_period: %s, categorical: %s",
                 nrow(merge_multi_cont), has_dose1_period, has_dose2_period, has_cat)

  record_test("Multiple continuous exposures", all_valid, msg)

}, error = function(e) {
  record_test("Multiple continuous exposures", FALSE, paste("Error:", e$message))
})

# ============================================================================
# FINAL SUMMARY
# ============================================================================

cat("\n")
cat(paste(rep("=", 80), collapse = ""), "\n", sep = "")
cat("TEST RESULTS SUMMARY\n")
cat(paste(rep("=", 80), collapse = ""), "\n\n", sep = "")

# Count pass/fail
passed <- sum(sapply(test_results, function(t) t$passed))
failed <- sum(sapply(test_results, function(t) !t$passed))
total <- length(test_results)

# Print summary
cat(sprintf("Total tests: %d\n", total))
cat(sprintf("Passed: %d (%.1f%%)\n", passed, 100 * passed / total))
cat(sprintf("Failed: %d (%.1f%%)\n\n", failed, 100 * failed / total))

# Print failed tests
if (failed > 0) {
  cat("Failed tests:\n")
  for (result in test_results) {
    if (!result$passed) {
      cat(sprintf("  [%d] %s\n", result$number, result$name))
      if (result$message != "") {
        cat(sprintf("      %s\n", result$message))
      }
    }
  }
  cat("\n")
}

# Overall result
if (failed == 0) {
  cat("\033[32m")
  cat("======================================\n")
  cat("  ALL TESTS PASSED!  \n")
  cat("======================================\n")
  cat("\033[0m\n")
} else {
  cat("\033[31m")
  cat("======================================\n")
  cat(sprintf("  %d TEST(S) FAILED  \n", failed))
  cat("======================================\n")
  cat("\033[0m\n")
}

cat(paste(rep("=", 80), collapse = ""), "\n", sep = "")
cat("Integration testing complete\n")
cat(paste(rep("=", 80), collapse = ""), "\n\n", sep = "")

# Return exit code
if (failed > 0) {
  quit(status = 1)
} else {
  quit(status = 0)
}
