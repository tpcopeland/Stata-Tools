#!/usr/bin/env Rscript
#
# Test Data Validation Script
#
# This script validates that the generated test datasets are correctly formatted
# and can be loaded successfully.
#
# Usage:
#   Rscript /home/user/Stata-Tools/tvtools-r/tests/validate_test_data.R

cat(paste(rep("=", 78), collapse = ""), "\n", sep = "")
cat("tvtools Test Data Validation\n")
cat(paste(rep("=", 78), collapse = ""), "\n\n", sep = "")

# Determine data directory
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

data_dir <- file.path(script_dir, "test_data")

if (!dir.exists(data_dir)) {
  stop("Test data directory not found: ", data_dir, "\n",
       "Run generate_test_data.R first to create test datasets.")
}

cat("Data directory:", data_dir, "\n\n")

# Helper function to validate dataset
validate_dataset <- function(name, expected_cols = NULL, expected_date_cols = NULL) {
  rds_path <- file.path(data_dir, paste0(name, ".rds"))
  csv_path <- file.path(data_dir, paste0(name, ".csv"))

  cat(sprintf("Validating: %-30s ", name))

  # Check file exists
  if (!file.exists(rds_path)) {
    cat("[FAIL] RDS file not found\n")
    return(FALSE)
  }

  if (!file.exists(csv_path)) {
    cat("[FAIL] CSV file not found\n")
    return(FALSE)
  }

  # Load RDS
  data_rds <- tryCatch({
    readRDS(rds_path)
  }, error = function(e) {
    cat("[FAIL] Cannot load RDS:", e$message, "\n")
    return(NULL)
  })

  if (is.null(data_rds)) return(FALSE)

  # Load CSV
  data_csv <- tryCatch({
    read.csv(csv_path, stringsAsFactors = FALSE)
  }, error = function(e) {
    cat("[FAIL] Cannot load CSV:", e$message, "\n")
    return(NULL)
  })

  if (is.null(data_csv)) return(FALSE)

  # Check dimensions match
  if (nrow(data_rds) != nrow(data_csv)) {
    cat(sprintf("[FAIL] Row mismatch: RDS=%d, CSV=%d\n",
                nrow(data_rds), nrow(data_csv)))
    return(FALSE)
  }

  if (ncol(data_rds) != ncol(data_csv)) {
    cat(sprintf("[FAIL] Column mismatch: RDS=%d, CSV=%d\n",
                ncol(data_rds), ncol(data_csv)))
    return(FALSE)
  }

  # Check expected columns present
  if (!is.null(expected_cols)) {
    missing_cols <- setdiff(expected_cols, names(data_rds))
    if (length(missing_cols) > 0) {
      cat(sprintf("[FAIL] Missing columns: %s\n",
                  paste(missing_cols, collapse = ", ")))
      return(FALSE)
    }
  }

  # Check date columns are Date type in RDS
  if (!is.null(expected_date_cols)) {
    for (col in expected_date_cols) {
      if (col %in% names(data_rds)) {
        if (!inherits(data_rds[[col]], "Date")) {
          cat(sprintf("[FAIL] Column %s is not Date type\n", col))
          return(FALSE)
        }
      }
    }
  }

  # Check no duplicate ID-date combinations (if applicable)
  if ("id" %in% names(data_rds)) {
    if (any(is.na(data_rds$id))) {
      cat("[FAIL] Missing IDs detected\n")
      return(FALSE)
    }
  }

  cat(sprintf("[PASS] %d rows x %d cols\n", nrow(data_rds), ncol(data_rds)))
  return(TRUE)
}

# Validate all datasets
cat("Validating Datasets\n")
cat(paste(rep("-", 78), collapse = ""), "\n", sep = "")

results <- list()

# 1. Cohort datasets
results$cohort_basic <- validate_dataset(
  "cohort_basic",
  expected_cols = c("id", "study_entry", "study_exit", "age", "sex"),
  expected_date_cols = c("study_entry", "study_exit")
)

results$cohort_large <- validate_dataset(
  "cohort_large",
  expected_cols = c("id", "study_entry", "study_exit"),
  expected_date_cols = c("study_entry", "study_exit")
)

results$cohort_no_exposure <- validate_dataset(
  "cohort_no_exposure",
  expected_cols = c("id", "study_entry", "study_exit"),
  expected_date_cols = c("study_entry", "study_exit")
)

# 2. Exposure datasets
results$exposure_simple <- validate_dataset(
  "exposure_simple",
  expected_cols = c("id", "exp_start", "exp_stop", "exposure"),
  expected_date_cols = c("exp_start", "exp_stop")
)

results$exposure_gaps <- validate_dataset(
  "exposure_gaps",
  expected_cols = c("id", "exp_start", "exp_stop", "exposure"),
  expected_date_cols = c("exp_start", "exp_stop")
)

results$exposure_overlap <- validate_dataset(
  "exposure_overlap",
  expected_cols = c("id", "exp_start", "exp_stop", "exposure"),
  expected_date_cols = c("exp_start", "exp_stop")
)

results$exposure_multi_types <- validate_dataset(
  "exposure_multi_types",
  expected_cols = c("id", "exp_start", "exp_stop", "exposure"),
  expected_date_cols = c("exp_start", "exp_stop")
)

results$exposure_point_time <- validate_dataset(
  "exposure_point_time",
  expected_cols = c("id", "event_date"),
  expected_date_cols = c("event_date")
)

results$exposure_edge_cases <- validate_dataset(
  "exposure_edge_cases",
  expected_cols = c("id", "exp_start", "exp_stop", "exposure"),
  expected_date_cols = c("exp_start", "exp_stop")
)

results$exposure_missing_cohort <- validate_dataset(
  "exposure_missing_cohort",
  expected_cols = c("id", "exp_start", "exp_stop", "exposure"),
  expected_date_cols = c("exp_start", "exp_stop")
)

results$exposure_large <- validate_dataset(
  "exposure_large",
  expected_cols = c("id", "exp_start", "exp_stop", "exposure"),
  expected_date_cols = c("exp_start", "exp_stop")
)

results$exposure_continuous <- validate_dataset(
  "exposure_continuous",
  expected_cols = c("id", "exp_start", "exp_stop", "dose_rate"),
  expected_date_cols = c("exp_start", "exp_stop")
)

results$exposure_mixed <- validate_dataset(
  "exposure_mixed",
  expected_cols = c("id", "exp_start", "exp_stop"),
  expected_date_cols = c("exp_start", "exp_stop")
)

results$exposure_grace_test <- validate_dataset(
  "exposure_grace_test",
  expected_cols = c("id", "exp_start", "exp_stop", "exposure"),
  expected_date_cols = c("exp_start", "exp_stop")
)

results$exposure_lag_washout <- validate_dataset(
  "exposure_lag_washout",
  expected_cols = c("id", "exp_start", "exp_stop", "exposure"),
  expected_date_cols = c("exp_start", "exp_stop")
)

results$exposure_switching <- validate_dataset(
  "exposure_switching",
  expected_cols = c("id", "exp_start", "exp_stop", "exposure"),
  expected_date_cols = c("exp_start", "exp_stop")
)

results$exposure_duration_test <- validate_dataset(
  "exposure_duration_test",
  expected_cols = c("id", "exp_start", "exp_stop", "exposure"),
  expected_date_cols = c("exp_start", "exp_stop")
)

# Summary
cat("\n")
cat(paste(rep("=", 78), collapse = ""), "\n", sep = "")
cat("VALIDATION SUMMARY\n")
cat(paste(rep("=", 78), collapse = ""), "\n\n", sep = "")

passed <- sum(unlist(results))
total <- length(results)
failed <- total - passed

cat(sprintf("Total datasets: %d\n", total))
cat(sprintf("Passed:         %d\n", passed))
cat(sprintf("Failed:         %d\n", failed))
cat("\n")

if (failed > 0) {
  cat("VALIDATION FAILED\n")
  failed_names <- names(results)[!unlist(results)]
  cat("Failed datasets:\n")
  for (name in failed_names) {
    cat(sprintf("  - %s\n", name))
  }
  quit(status = 1)
} else {
  cat("ALL VALIDATIONS PASSED\n")
  cat("\nTest datasets are ready for use!\n")
}

cat(paste(rep("=", 78), collapse = ""), "\n", sep = "")
