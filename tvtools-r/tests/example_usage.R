#!/usr/bin/env Rscript
#
# Example Usage of tvtools Test Data
#
# This script demonstrates how to use the generated test datasets
# with the tvtools package functions.
#
# Usage:
#   Rscript /home/user/Stata-Tools/tvtools-r/tests/example_usage.R
#
# Requirements:
#   - tvtools package loaded or sourced
#   - Test data generated (run generate_test_data.R first)

# ============================================================================
# SETUP
# ============================================================================

cat("\n")
cat(paste(rep("=", 78), collapse = ""), "\n", sep = "")
cat("tvtools Test Data - Example Usage\n")
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

# Try to load tvtools package
has_tvtools <- require("tvtools", quietly = TRUE)
if (!has_tvtools) {
  cat("NOTE: tvtools package not installed.\n")
  cat("This script will demonstrate data loading only.\n")
  cat("To test tvtools functions, install the package first.\n\n")
}

# ============================================================================
# EXAMPLE 1: Loading Test Data
# ============================================================================

cat(paste(rep("-", 78), collapse = ""), "\n", sep = "")
cat("EXAMPLE 1: Loading Test Data\n")
cat(paste(rep("-", 78), collapse = ""), "\n", sep = "")

cat("\nLoading cohort_basic...\n")
cohort <- readRDS(file.path(data_dir, "cohort_basic.rds"))
cat(sprintf("  Loaded %d persons\n", nrow(cohort)))
cat("  Columns:", paste(names(cohort), collapse = ", "), "\n")
cat("  First few rows:\n")
print(head(cohort, 3))

cat("\nLoading exposure_simple...\n")
exposure <- readRDS(file.path(data_dir, "exposure_simple.rds"))
cat(sprintf("  Loaded %d exposure periods\n", nrow(exposure)))
cat(sprintf("  Covering %d persons\n", length(unique(exposure$id))))
cat("  Columns:", paste(names(exposure), collapse = ", "), "\n")
cat("  First few rows:\n")
print(head(exposure, 3))

# ============================================================================
# EXAMPLE 2: Basic Summary Statistics
# ============================================================================

cat("\n")
cat(paste(rep("-", 78), collapse = ""), "\n", sep = "")
cat("EXAMPLE 2: Basic Summary Statistics\n")
cat(paste(rep("-", 78), collapse = ""), "\n", sep = "")

cat("\nCohort characteristics:\n")
cat(sprintf("  Age: mean=%.1f, range=[%d, %d]\n",
            mean(cohort$age), min(cohort$age), max(cohort$age)))
cat(sprintf("  Sex: %d Male, %d Female\n",
            sum(cohort$sex == "M"), sum(cohort$sex == "F")))
cat(sprintf("  Study period: %s to %s\n",
            min(cohort$study_entry), max(cohort$study_exit)))

cat("\nExposure characteristics:\n")
cat(sprintf("  Exposure types: %s\n",
            paste(unique(exposure$exposure), collapse = ", ")))
cat(sprintf("  Persons with exposure: %d (%.1f%%)\n",
            length(unique(exposure$id)),
            100 * length(unique(exposure$id)) / nrow(cohort)))

exposure$duration_days <- as.numeric(exposure$exp_stop - exposure$exp_start)
cat(sprintf("  Exposure duration: mean=%.1f days, range=[%d, %d]\n",
            mean(exposure$duration_days),
            min(exposure$duration_days),
            max(exposure$duration_days)))

# ============================================================================
# EXAMPLE 3: Testing Different Datasets
# ============================================================================

cat("\n")
cat(paste(rep("-", 78), collapse = ""), "\n", sep = "")
cat("EXAMPLE 3: Testing Different Datasets\n")
cat(paste(rep("-", 78), collapse = ""), "\n", sep = "")

datasets <- c(
  "exposure_simple",
  "exposure_gaps",
  "exposure_overlap",
  "exposure_multi_types",
  "exposure_continuous",
  "exposure_edge_cases"
)

cat("\nDataset summaries:\n\n")
for (ds_name in datasets) {
  ds <- readRDS(file.path(data_dir, paste0(ds_name, ".rds")))
  cat(sprintf("  %-30s: %4d rows, %2d persons\n",
              ds_name, nrow(ds), length(unique(ds$id))))
}

# ============================================================================
# EXAMPLE 4: Checking for Overlaps and Gaps
# ============================================================================

cat("\n")
cat(paste(rep("-", 78), collapse = ""), "\n", sep = "")
cat("EXAMPLE 4: Checking for Overlaps and Gaps\n")
cat(paste(rep("-", 78), collapse = ""), "\n", sep = "")

# Check overlapping exposures
cat("\nChecking exposure_overlap for overlaps:\n")
exposure_overlap <- readRDS(file.path(data_dir, "exposure_overlap.rds"))

# For each person, check if any periods overlap
has_overlap <- sapply(unique(exposure_overlap$id), function(pid) {
  person_data <- exposure_overlap[exposure_overlap$id == pid, ]
  if (nrow(person_data) <= 1) return(FALSE)

  person_data <- person_data[order(person_data$exp_start), ]

  for (i in 1:(nrow(person_data) - 1)) {
    if (person_data$exp_stop[i] > person_data$exp_start[i + 1]) {
      return(TRUE)
    }
  }
  return(FALSE)
})

cat(sprintf("  Persons with overlapping exposures: %d (%.1f%%)\n",
            sum(has_overlap),
            100 * mean(has_overlap)))

# Check gaps
cat("\nChecking exposure_gaps for gaps:\n")
exposure_gaps <- readRDS(file.path(data_dir, "exposure_gaps.rds"))

gap_info <- do.call(rbind, lapply(unique(exposure_gaps$id), function(pid) {
  person_data <- exposure_gaps[exposure_gaps$id == pid, ]
  if (nrow(person_data) <= 1) return(NULL)

  person_data <- person_data[order(person_data$exp_start), ]

  gaps <- c()
  for (i in 1:(nrow(person_data) - 1)) {
    gap_days <- as.numeric(person_data$exp_start[i + 1] - person_data$exp_stop[i])
    if (gap_days > 0) {
      gaps <- c(gaps, gap_days)
    }
  }

  if (length(gaps) > 0) {
    data.frame(
      id = pid,
      n_gaps = length(gaps),
      mean_gap = mean(gaps),
      min_gap = min(gaps),
      max_gap = max(gaps)
    )
  } else {
    NULL
  }
}))

if (!is.null(gap_info) && nrow(gap_info) > 0) {
  cat(sprintf("  Persons with gaps: %d\n", nrow(gap_info)))
  cat(sprintf("  Total gaps: %d\n", sum(gap_info$n_gaps)))
  cat(sprintf("  Gap size: mean=%.1f days, range=[%d, %d]\n",
              mean(gap_info$mean_gap),
              min(gap_info$min_gap),
              max(gap_info$max_gap)))
}

# ============================================================================
# EXAMPLE 5: Edge Cases Exploration
# ============================================================================

cat("\n")
cat(paste(rep("-", 78), collapse = ""), "\n", sep = "")
cat("EXAMPLE 5: Edge Cases Exploration\n")
cat(paste(rep("-", 78), collapse = ""), "\n", sep = "")

edge_cases <- readRDS(file.path(data_dir, "exposure_edge_cases.rds"))

cat("\nEdge case distribution:\n")
edge_table <- table(edge_cases$edge_case_type)
for (case_type in names(edge_table)) {
  cat(sprintf("  %-20s: %2d occurrences\n", case_type, edge_table[case_type]))
}

# Check for exposures before entry or after exit
cat("\nChecking temporal boundaries:\n")
for (pid in unique(edge_cases$id)) {
  person_cohort <- cohort[cohort$id == pid, ]
  if (nrow(person_cohort) == 0) next

  person_exposure <- edge_cases[edge_cases$id == pid, ]

  before_entry <- person_exposure$exp_start < person_cohort$study_entry
  after_exit <- person_exposure$exp_stop > person_cohort$study_exit

  if (any(before_entry)) {
    cat(sprintf("  Person %d: Exposure starts before study entry\n", pid))
  }
  if (any(after_exit)) {
    cat(sprintf("  Person %d: Exposure ends after study exit\n", pid))
  }
}

# ============================================================================
# SUMMARY
# ============================================================================

cat("\n")
cat(paste(rep("=", 78), collapse = ""), "\n", sep = "")
cat("SUMMARY\n")
cat(paste(rep("=", 78), collapse = ""), "\n", sep = "")

cat("\nAvailable test datasets:\n")
cat("  - cohort_basic: Master cohort (100 persons)\n")
cat("  - cohort_large: Large cohort (1000 persons)\n")
cat("  - exposure_simple: Clean exposures (no overlaps/gaps)\n")
cat("  - exposure_gaps: Exposures with gaps (grace period testing)\n")
cat("  - exposure_overlap: Overlapping exposures\n")
cat("  - exposure_multi_types: Multiple exposure types (bytype testing)\n")
cat("  - exposure_continuous: Continuous dose rates\n")
cat("  - exposure_edge_cases: Edge cases and boundary conditions\n")
cat("  - exposure_point_time: Point-in-time events\n")
cat("  - And more...\n\n")

cat("For detailed documentation, see:\n")
cat("  ", file.path(data_dir, "README.md"), "\n\n")

if (has_tvtools) {
  cat("tvtools package is available!\n")
  cat("You can now test tvexpose() and tvmerge() functions.\n")
} else {
  cat("To use tvtools functions, install the package:\n")
  cat("  install.packages('devtools')\n")
  cat("  devtools::install_local('/home/user/Stata-Tools/tvtools-r')\n")
}

cat("\n")
cat(paste(rep("=", 78), collapse = ""), "\n", sep = "")
cat("Examples complete!\n")
cat(paste(rep("=", 78), collapse = ""), "\n\n", sep = "")
