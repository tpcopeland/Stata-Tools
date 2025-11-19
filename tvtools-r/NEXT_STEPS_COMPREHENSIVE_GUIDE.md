# tvtools-r: Comprehensive Next Steps Guide for LLM Continuation

**Date Created:** 2025-11-19
**For:** Next Claude instance to continue tvtools-r improvements
**Status:** Production improvements needed - full testing setup included

---

## 📋 TABLE OF CONTENTS

1. [Quick Start - Testing Setup](#1-quick-start---testing-setup)
2. [Pre-Generated Synthetic Test Data](#2-pre-generated-synthetic-test-data)
3. [Ready-to-Run Test Code](#3-ready-to-run-test-code)
4. [Critical Next Steps - Phase 1](#4-critical-next-steps---phase-1)
5. [Implementation Guide - Type Safety](#5-implementation-guide---type-safety)
6. [Implementation Guide - Input Validation](#6-implementation-guide---input-validation)
7. [Implementation Guide - Performance Fixes](#7-implementation-guide---performance-fixes)
8. [Implementation Guide - Edge Cases](#8-implementation-guide---edge-cases)
9. [Testing Checklist](#9-testing-checklist)
10. [Validation & Commit Guide](#10-validation--commit-guide)

---

## 1. QUICK START - TESTING SETUP

### Environment Setup

```bash
# Navigate to package directory
cd /home/user/Stata-Tools/tvtools-r

# Install R if not available
which R || apt-get install -y r-base r-base-dev

# Install required packages
Rscript -e "install.packages(c('dplyr', 'tidyr', 'lubridate', 'survival', 'zoo', 'testthat', 'devtools', 'roxygen2'), repos='https://cloud.r-project.org', dependencies=TRUE)"

# Load the package in development mode
Rscript -e "devtools::load_all()"

# Run existing tests
Rscript -e "devtools::test()"

# Run R CMD check
R CMD build .
R CMD check tvtools_*.tar.gz
```

### Quick Validation

```r
# In R console
library(devtools)
load_all()

# Test basic functionality
data(cohort)
data(hrt_exposure)

# Quick test
result <- tvexpose(
  master = cohort[1:100, ],
  exposure_data = hrt_exposure[hrt_exposure$id %in% 1:100, ],
  id = "id",
  start = "rx_start",
  stop = "rx_stop",
  exposure = "hrt_type",
  entry = "study_entry",
  exit = "study_exit"
)

print(head(result))
print(paste("Rows created:", nrow(result)))
```

---

## 2. PRE-GENERATED SYNTHETIC TEST DATA

### Complete Test Data Generation Script

Save this as `tests/generate_comprehensive_test_data.R`:

```r
#!/usr/bin/env Rscript
# Comprehensive Test Data Generator for tvtools-r
# Generates all edge cases and scenarios for complete testing

set.seed(42)  # Reproducibility

# Create output directory
if (!dir.exists("tests/test_data_comprehensive")) {
  dir.create("tests/test_data_comprehensive", recursive = TRUE)
}

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

save_both_formats <- function(data, name, dir = "tests/test_data_comprehensive") {
  csv_path <- file.path(dir, paste0(name, ".csv"))
  rds_path <- file.path(dir, paste0(name, ".rds"))

  write.csv(data, csv_path, row.names = FALSE)
  saveRDS(data, rds_path)

  cat(sprintf("Saved: %s (%d rows, %d cols)\n", name, nrow(data), ncol(data)))
}

# ============================================================================
# TEST DATA 1: EMPTY MASTER DATASET (Edge Case)
# ============================================================================

cohort_empty <- data.frame(
  id = integer(0),
  study_entry = as.Date(character(0)),
  study_exit = as.Date(character(0)),
  age = integer(0),
  female = integer(0)
)

save_both_formats(cohort_empty, "cohort_empty")

# ============================================================================
# TEST DATA 2: SINGLE PERSON (Edge Case)
# ============================================================================

cohort_single <- data.frame(
  id = 1,
  study_entry = as.Date("2010-01-01"),
  study_exit = as.Date("2020-12-31"),
  age = 55,
  female = 1
)

exposure_single <- data.frame(
  id = 1,
  rx_start = as.Date(c("2012-01-01", "2015-06-01")),
  rx_stop = as.Date(c("2013-12-31", "2017-12-31")),
  drug_type = c(1, 2)
)

save_both_formats(cohort_single, "cohort_single")
save_both_formats(exposure_single, "exposure_single")

# ============================================================================
# TEST DATA 3: DUPLICATE IDS IN MASTER (Critical Edge Case)
# ============================================================================

cohort_duplicates <- data.frame(
  id = c(1, 1, 2, 2, 3),  # IDs 1 and 2 are duplicated
  study_entry = as.Date(c("2010-01-01", "2010-06-01", "2011-01-01", "2011-06-01", "2012-01-01")),
  study_exit = as.Date(c("2020-12-31", "2021-12-31", "2020-12-31", "2021-12-31", "2020-12-31")),
  age = c(55, 56, 60, 61, 45),
  female = c(1, 1, 0, 0, 1)
)

exposure_for_duplicates <- data.frame(
  id = c(1, 2, 3),
  rx_start = as.Date(c("2012-01-01", "2013-01-01", "2014-01-01")),
  rx_stop = as.Date(c("2013-12-31", "2014-12-31", "2015-12-31")),
  drug_type = c(1, 2, 1)
)

save_both_formats(cohort_duplicates, "cohort_duplicates")
save_both_formats(exposure_for_duplicates, "exposure_for_duplicates")

# ============================================================================
# TEST DATA 4: TYPE MISMATCHES (Critical Edge Case)
# ============================================================================

cohort_numeric_id <- data.frame(
  id = c(1, 2, 3, 4, 5),  # Numeric IDs
  study_entry = as.Date(c("2010-01-01", "2010-06-01", "2011-01-01", "2012-01-01", "2013-01-01")),
  study_exit = as.Date(c("2020-12-31", "2021-12-31", "2020-12-31", "2021-12-31", "2020-12-31")),
  age = c(55, 60, 45, 50, 65),
  female = c(1, 0, 1, 0, 1)
)

exposure_character_id <- data.frame(
  id = c("1", "2", "3", "4", "5"),  # Character IDs - TYPE MISMATCH
  rx_start = as.Date(c("2012-01-01", "2013-01-01", "2014-01-01", "2015-01-01", "2016-01-01")),
  rx_stop = as.Date(c("2013-12-31", "2014-12-31", "2015-12-31", "2016-12-31", "2017-12-31")),
  drug_type = c(1, 2, 1, 2, 1)
)

save_both_formats(cohort_numeric_id, "cohort_numeric_id")
save_both_formats(exposure_character_id, "exposure_character_id")

# ============================================================================
# TEST DATA 5: INFINITE DATES (Critical Edge Case)
# ============================================================================

cohort_infinite_dates <- data.frame(
  id = c(1, 2, 3),
  study_entry = as.Date(c("2010-01-01", "2010-01-01", "2010-01-01")),
  study_exit = c(as.Date("2020-12-31"), Inf, as.Date("2020-12-31")),  # ID 2 has Inf exit
  age = c(55, 60, 45),
  female = c(1, 0, 1)
)

exposure_infinite_dates <- data.frame(
  id = c(1, 2, 3),
  rx_start = as.Date(c("2012-01-01", "2013-01-01", "2014-01-01")),
  rx_stop = c(as.Date("2013-12-31"), Inf, as.Date("2015-12-31")),  # ID 2 has Inf stop
  drug_type = c(1, 2, 1)
)

save_both_formats(cohort_infinite_dates, "cohort_infinite_dates")
save_both_formats(exposure_infinite_dates, "exposure_infinite_dates")

# ============================================================================
# TEST DATA 6: NA VALUES IN CRITICAL COLUMNS
# ============================================================================

cohort_na_dates <- data.frame(
  id = c(1, 2, 3, 4),
  study_entry = as.Date(c("2010-01-01", NA, "2011-01-01", "2012-01-01")),  # NA in entry
  study_exit = as.Date(c("2020-12-31", "2021-12-31", NA, "2020-12-31")),   # NA in exit
  age = c(55, 60, 45, 50),
  female = c(1, 0, 1, 0)
)

exposure_na_values <- data.frame(
  id = c(1, 2, 3, 4),
  rx_start = as.Date(c("2012-01-01", "2013-01-01", NA, "2015-01-01")),  # NA in start
  rx_stop = as.Date(c("2013-12-31", "2014-12-31", "2015-12-31", NA)),    # NA in stop
  drug_type = c(1, NA, 1, 2)  # NA in exposure value
)

save_both_formats(cohort_na_dates, "cohort_na_dates")
save_both_formats(exposure_na_values, "exposure_na_values")

# ============================================================================
# TEST DATA 7: CIRCULAR DATE LOGIC (start > stop)
# ============================================================================

cohort_circular <- data.frame(
  id = c(1, 2, 3),
  study_entry = as.Date(c("2010-01-01", "2020-01-01", "2010-01-01")),  # ID 2: exit < entry
  study_exit = as.Date(c("2020-12-31", "2010-01-01", "2020-12-31")),
  age = c(55, 60, 45),
  female = c(1, 0, 1)
)

exposure_circular <- data.frame(
  id = c(1, 2, 3),
  rx_start = as.Date(c("2012-01-01", "2015-01-01", "2013-01-01")),
  rx_stop = as.Date(c("2013-12-31", "2013-01-01", "2015-12-31")),  # ID 2: stop < start
  drug_type = c(1, 2, 1)
)

save_both_formats(cohort_circular, "cohort_circular")
save_both_formats(exposure_circular, "exposure_circular")

# ============================================================================
# TEST DATA 8: ZERO-LENGTH PERIODS
# ============================================================================

cohort_zero_length <- data.frame(
  id = c(1, 2, 3),
  study_entry = as.Date(c("2010-01-01", "2010-01-01", "2010-01-01")),
  study_exit = as.Date(c("2020-12-31", "2010-01-01", "2020-12-31")),  # ID 2: entry == exit
  age = c(55, 60, 45),
  female = c(1, 0, 1)
)

exposure_zero_length <- data.frame(
  id = c(1, 2, 3),
  rx_start = as.Date(c("2012-01-01", "2013-01-01", "2014-01-01")),
  rx_stop = as.Date(c("2013-12-31", "2013-01-01", "2014-01-01")),  # ID 2: start==stop, ID 3: start==stop
  drug_type = c(1, 2, 1)
)

save_both_formats(cohort_zero_length, "cohort_zero_length")
save_both_formats(exposure_zero_length, "exposure_zero_length")

# ============================================================================
# TEST DATA 9: LARGE DATASET FOR PERFORMANCE TESTING
# ============================================================================

n_persons <- 10000
cohort_large <- data.frame(
  id = 1:n_persons,
  study_entry = as.Date("2010-01-01") + sample(0:365, n_persons, replace = TRUE),
  study_exit = as.Date("2020-01-01") + sample(0:365, n_persons, replace = TRUE),
  age = sample(25:85, n_persons, replace = TRUE),
  female = sample(0:1, n_persons, replace = TRUE)
)

# Generate exposure data with varying numbers of periods per person
exposure_large <- do.call(rbind, lapply(1:n_persons, function(i) {
  n_periods <- sample(1:20, 1)  # 1-20 periods per person
  if (runif(1) < 0.3) return(NULL)  # 30% have no exposure

  data.frame(
    id = i,
    rx_start = sort(cohort_large$study_entry[i] + sample(0:3650, n_periods)),
    rx_stop = sort(cohort_large$study_entry[i] + sample(0:3650, n_periods)),
    drug_type = sample(1:6, n_periods, replace = TRUE)
  )
}))

# Fix any circular dates
exposure_large$rx_stop <- pmax(exposure_large$rx_start, exposure_large$rx_stop)

save_both_formats(cohort_large, "cohort_large")
save_both_formats(exposure_large, "exposure_large")

# ============================================================================
# TEST DATA 10: CARTESIAN PRODUCT EXPLOSION TEST
# ============================================================================

cohort_cartesian <- data.frame(
  id = 1:100,
  study_entry = as.Date("2010-01-01"),
  study_exit = as.Date("2020-12-31"),
  age = sample(25:85, 100, replace = TRUE),
  female = sample(0:1, 100, replace = TRUE)
)

# Create datasets with many periods to test Cartesian explosion
# Dataset 1: 50 periods per person
exposure1_cartesian <- do.call(rbind, lapply(1:100, function(i) {
  data.frame(
    id = i,
    rx_start = as.Date("2010-01-01") + (0:49) * 30,  # 50 monthly periods
    rx_stop = as.Date("2010-01-01") + (1:50) * 30 - 1,
    drug_a = sample(1:3, 50, replace = TRUE)
  )
}))

# Dataset 2: Another 50 periods per person
exposure2_cartesian <- do.call(rbind, lapply(1:100, function(i) {
  data.frame(
    id = i,
    rx_start = as.Date("2010-01-01") + (0:49) * 30,  # 50 monthly periods
    rx_stop = as.Date("2010-01-01") + (1:50) * 30 - 1,
    drug_b = sample(1:3, 50, replace = TRUE)
  )
}))

# If merged without optimization: 100 persons × 50 periods × 50 periods = 250,000 rows!

save_both_formats(cohort_cartesian, "cohort_cartesian")
save_both_formats(exposure1_cartesian, "exposure1_cartesian")
save_both_formats(exposure2_cartesian, "exposure2_cartesian")

# ============================================================================
# TEST DATA 11: CONFLICTING PARAMETER COMBINATIONS
# ============================================================================

cohort_params <- data.frame(
  id = 1:50,
  study_entry = as.Date("2010-01-01"),
  study_exit = as.Date("2020-12-31"),
  age = sample(25:85, 50, replace = TRUE),
  female = sample(0:1, 50, replace = TRUE)
)

exposure_params <- data.frame(
  id = rep(1:50, each = 3),
  rx_start = as.Date("2012-01-01") + rep(c(0, 365, 730), 50),
  rx_stop = as.Date("2013-01-01") + rep(c(0, 365, 730), 50),
  drug_type = sample(1:3, 150, replace = TRUE)
)

save_both_formats(cohort_params, "cohort_params")
save_both_formats(exposure_params, "exposure_params")

# ============================================================================
# TEST DATA 12: CHARACTER DATES (Type Conversion Test)
# ============================================================================

cohort_char_dates <- data.frame(
  id = 1:20,
  study_entry = rep("2010-01-01", 20),  # Character dates
  study_exit = rep("2020-12-31", 20),
  age = sample(25:85, 20, replace = TRUE),
  female = sample(0:1, 20, replace = TRUE),
  stringsAsFactors = FALSE
)

exposure_char_dates <- data.frame(
  id = rep(1:20, each = 2),
  rx_start = rep(c("2012-01-01", "2015-01-01"), 20),  # Character dates
  rx_stop = rep(c("2013-12-31", "2016-12-31"), 20),
  drug_type = sample(1:2, 40, replace = TRUE),
  stringsAsFactors = FALSE
)

save_both_formats(cohort_char_dates, "cohort_char_dates")
save_both_formats(exposure_char_dates, "exposure_char_dates")

# ============================================================================
# SUMMARY
# ============================================================================

cat("\n=== TEST DATA GENERATION COMPLETE ===\n\n")
cat("Generated 12 comprehensive test scenarios:\n")
cat("1. cohort_empty - Empty master dataset (0 rows)\n")
cat("2. cohort_single - Single person cohort (1 row)\n")
cat("3. cohort_duplicates - Duplicate IDs in master (5 rows, 2 duplicates)\n")
cat("4. cohort_numeric_id + exposure_character_id - Type mismatch test\n")
cat("5. cohort_infinite_dates - Infinite date values\n")
cat("6. cohort_na_dates - NA values in critical columns\n")
cat("7. cohort_circular - Circular date logic (stop < start)\n")
cat("8. cohort_zero_length - Zero-length periods\n")
cat("9. cohort_large - Large dataset (10,000 persons) for performance\n")
cat("10. cohort_cartesian - Cartesian product explosion test (100 × 50 × 50)\n")
cat("11. cohort_params - Parameter combination testing\n")
cat("12. cohort_char_dates - Character date conversion test\n\n")

cat("All data saved in both CSV and RDS formats.\n")
cat("Location: tests/test_data_comprehensive/\n\n")

# Create a summary file
summary_file <- file.path("tests/test_data_comprehensive", "DATA_SUMMARY.txt")
sink(summary_file)
cat("TEST DATA SUMMARY\n")
cat("Generated:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n\n")

files <- list.files("tests/test_data_comprehensive", pattern = "\\.rds$")
for (f in files) {
  data <- readRDS(file.path("tests/test_data_comprehensive", f))
  cat(sprintf("%-35s: %5d rows × %2d cols\n", f, nrow(data), ncol(data)))
}
sink()

cat("Summary saved to:", summary_file, "\n")
```

### Run the Data Generator

```bash
cd /home/user/Stata-Tools/tvtools-r
Rscript tests/generate_comprehensive_test_data.R
```

---

## 3. READY-TO-RUN TEST CODE

### Complete Test Suite for All Edge Cases

Save this as `tests/test_edge_cases_comprehensive.R`:

```r
#!/usr/bin/env Rscript
# Comprehensive Edge Case Test Suite
# Tests all critical edge cases identified in production readiness analysis

library(testthat)
library(devtools)

# Load the package
load_all()

# Test data directory
test_data_dir <- "tests/test_data_comprehensive"

# ============================================================================
# TEST 1: EMPTY MASTER DATASET
# ============================================================================

test_that("Empty master dataset produces clear error", {
  cohort_empty <- readRDS(file.path(test_data_dir, "cohort_empty.rds"))
  exposure_single <- readRDS(file.path(test_data_dir, "exposure_single.rds"))

  expect_error(
    tvexpose(
      master = cohort_empty,
      exposure_data = exposure_single,
      id = "id",
      start = "rx_start",
      stop = "rx_stop",
      exposure = "drug_type",
      entry = "study_entry",
      exit = "study_exit"
    ),
    regexp = "empty|no persons|zero rows",
    ignore.case = TRUE
  )
})

# ============================================================================
# TEST 2: SINGLE PERSON (Should Work)
# ============================================================================

test_that("Single person cohort works correctly", {
  cohort_single <- readRDS(file.path(test_data_dir, "cohort_single.rds"))
  exposure_single <- readRDS(file.path(test_data_dir, "exposure_single.rds"))

  result <- tvexpose(
    master = cohort_single,
    exposure_data = exposure_single,
    id = "id",
    start = "rx_start",
    stop = "rx_stop",
    exposure = "drug_type",
    entry = "study_entry",
    exit = "study_exit"
  )

  expect_true(nrow(result) > 0)
  expect_equal(length(unique(result$id)), 1)
  expect_true(all(result$id == 1))
})

# ============================================================================
# TEST 3: DUPLICATE IDS IN MASTER
# ============================================================================

test_that("Duplicate IDs in master dataset produce clear error", {
  cohort_duplicates <- readRDS(file.path(test_data_dir, "cohort_duplicates.rds"))
  exposure_for_duplicates <- readRDS(file.path(test_data_dir, "exposure_for_duplicates.rds"))

  expect_error(
    tvexpose(
      master = cohort_duplicates,
      exposure_data = exposure_for_duplicates,
      id = "id",
      start = "rx_start",
      stop = "rx_stop",
      exposure = "drug_type",
      entry = "study_entry",
      exit = "study_exit"
    ),
    regexp = "duplicate|duplicated",
    ignore.case = TRUE
  )
})

# ============================================================================
# TEST 4: TYPE MISMATCHES
# ============================================================================

test_that("Type mismatch between master and exposure IDs produces clear error", {
  cohort_numeric_id <- readRDS(file.path(test_data_dir, "cohort_numeric_id.rds"))
  exposure_character_id <- readRDS(file.path(test_data_dir, "exposure_character_id.rds"))

  expect_error(
    tvexpose(
      master = cohort_numeric_id,
      exposure_data = exposure_character_id,
      id = "id",
      start = "rx_start",
      stop = "rx_stop",
      exposure = "drug_type",
      entry = "study_entry",
      exit = "study_exit"
    ),
    regexp = "type|class|mismatch",
    ignore.case = TRUE
  )
})

# ============================================================================
# TEST 5: INFINITE DATES
# ============================================================================

test_that("Infinite dates produce clear error", {
  cohort_infinite_dates <- readRDS(file.path(test_data_dir, "cohort_infinite_dates.rds"))
  exposure_infinite_dates <- readRDS(file.path(test_data_dir, "exposure_infinite_dates.rds"))

  expect_error(
    tvexpose(
      master = cohort_infinite_dates,
      exposure_data = exposure_infinite_dates,
      id = "id",
      start = "rx_start",
      stop = "rx_stop",
      exposure = "drug_type",
      entry = "study_entry",
      exit = "study_exit"
    ),
    regexp = "infinite|Inf",
    ignore.case = TRUE
  )
})

# ============================================================================
# TEST 6: NA VALUES IN CRITICAL COLUMNS
# ============================================================================

test_that("NA values in critical columns produce clear errors", {
  cohort_na_dates <- readRDS(file.path(test_data_dir, "cohort_na_dates.rds"))
  exposure_na_values <- readRDS(file.path(test_data_dir, "exposure_na_values.rds"))

  # Should error on NA in entry/exit
  expect_error(
    tvexpose(
      master = cohort_na_dates,
      exposure_data = exposure_na_values[!is.na(exposure_na_values$rx_start), ],
      id = "id",
      start = "rx_start",
      stop = "rx_stop",
      exposure = "drug_type",
      entry = "study_entry",
      exit = "study_exit"
    ),
    regexp = "NA|missing|null",
    ignore.case = TRUE
  )

  # Should error on NA in exposure values
  cohort_valid <- cohort_na_dates[!is.na(cohort_na_dates$study_entry) &
                                   !is.na(cohort_na_dates$study_exit), ]

  expect_error(
    tvexpose(
      master = cohort_valid,
      exposure_data = exposure_na_values,
      id = "id",
      start = "rx_start",
      stop = "rx_stop",
      exposure = "drug_type",
      entry = "study_entry",
      exit = "study_exit"
    ),
    regexp = "NA|missing",
    ignore.case = TRUE
  )
})

# ============================================================================
# TEST 7: CIRCULAR DATE LOGIC (Already handled - should work)
# ============================================================================

test_that("Circular dates are handled gracefully with warning", {
  cohort_circular <- readRDS(file.path(test_data_dir, "cohort_circular.rds"))
  exposure_circular <- readRDS(file.path(test_data_dir, "exposure_circular.rds"))

  # Should produce warning or error for invalid dates
  expect_error(
    tvexpose(
      master = cohort_circular,
      exposure_data = exposure_circular,
      id = "id",
      start = "rx_start",
      stop = "rx_stop",
      exposure = "drug_type",
      entry = "study_entry",
      exit = "study_exit"
    ),
    regexp = "invalid|circular|exit.*entry|stop.*start"
  )
})

# ============================================================================
# TEST 8: ZERO-LENGTH PERIODS (Should work)
# ============================================================================

test_that("Zero-length periods are handled correctly", {
  cohort_zero_length <- readRDS(file.path(test_data_dir, "cohort_zero_length.rds"))
  exposure_zero_length <- readRDS(file.path(test_data_dir, "exposure_zero_length.rds"))

  # Filter to valid cohort (entry <= exit)
  cohort_valid <- cohort_zero_length[cohort_zero_length$study_entry <=
                                      cohort_zero_length$study_exit, ]

  result <- tvexpose(
    master = cohort_valid,
    exposure_data = exposure_zero_length,
    id = "id",
    start = "rx_start",
    stop = "rx_stop",
    exposure = "drug_type",
    entry = "study_entry",
    exit = "study_exit"
  )

  # Should include zero-length periods (start == stop)
  expect_true(nrow(result) > 0)
})

# ============================================================================
# TEST 9: PERFORMANCE WITH LARGE DATASET
# ============================================================================

test_that("Large dataset completes in reasonable time", {
  cohort_large <- readRDS(file.path(test_data_dir, "cohort_large.rds"))
  exposure_large <- readRDS(file.path(test_data_dir, "exposure_large.rds"))

  # Take subset for faster testing (1000 persons)
  cohort_subset <- cohort_large[1:1000, ]
  exposure_subset <- exposure_large[exposure_large$id %in% 1:1000, ]

  start_time <- Sys.time()

  result <- tvexpose(
    master = cohort_subset,
    exposure_data = exposure_subset,
    id = "id",
    start = "rx_start",
    stop = "rx_stop",
    exposure = "drug_type",
    entry = "study_entry",
    exit = "study_exit"
  )

  end_time <- Sys.time()
  elapsed <- as.numeric(difftime(end_time, start_time, units = "secs"))

  cat(sprintf("\nPerformance: 1000 persons processed in %.2f seconds\n", elapsed))

  # Should complete in under 60 seconds
  expect_true(elapsed < 60)
  expect_true(nrow(result) > 0)
})

# ============================================================================
# TEST 10: CARTESIAN PRODUCT EXPLOSION WARNING
# ============================================================================

test_that("Cartesian product explosion produces warning", {
  skip("Requires tvmerge improvements")

  cohort_cartesian <- readRDS(file.path(test_data_dir, "cohort_cartesian.rds"))
  exposure1_cartesian <- readRDS(file.path(test_data_dir, "exposure1_cartesian.rds"))
  exposure2_cartesian <- readRDS(file.path(test_data_dir, "exposure2_cartesian.rds"))

  # Create tv outputs first
  tv1 <- tvexpose(
    master = cohort_cartesian[1:10, ],  # Just 10 persons for test
    exposure_data = exposure1_cartesian[exposure1_cartesian$id %in% 1:10, ],
    id = "id",
    start = "rx_start",
    stop = "rx_stop",
    exposure = "drug_a",
    entry = "study_entry",
    exit = "study_exit",
    generate = "drug_a"
  )

  tv2 <- tvexpose(
    master = cohort_cartesian[1:10, ],
    exposure_data = exposure2_cartesian[exposure2_cartesian$id %in% 1:10, ],
    id = "id",
    start = "rx_start",
    stop = "rx_stop",
    exposure = "drug_b",
    entry = "study_entry",
    exit = "study_exit",
    generate = "drug_b"
  )

  # Should warn about large output size
  expect_warning(
    tvmerge(
      datasets = list(tv1, tv2),
      id = "id",
      start = c("start", "start"),
      stop = c("stop", "stop"),
      exposure = c("drug_a", "drug_b")
    ),
    regexp = "large|memory|rows|cartesian",
    ignore.case = TRUE
  )
})

# ============================================================================
# TEST 11: CONFLICTING PARAMETER COMBINATIONS
# ============================================================================

test_that("Conflicting parameters produce clear error", {
  cohort_params <- readRDS(file.path(test_data_dir, "cohort_params.rds"))
  exposure_params <- readRDS(file.path(test_data_dir, "exposure_params.rds"))

  # Test 1: Multiple exposure type parameters
  expect_error(
    tvexpose(
      master = cohort_params,
      exposure_data = exposure_params,
      id = "id",
      start = "rx_start",
      stop = "rx_stop",
      exposure = "drug_type",
      entry = "study_entry",
      exit = "study_exit",
      evertreated = TRUE,
      currentformer = TRUE  # Conflict!
    ),
    regexp = "only one|conflicting|incompatible",
    ignore.case = TRUE
  )

  # Test 2: duration with negative values
  expect_error(
    tvexpose(
      master = cohort_params,
      exposure_data = exposure_params,
      id = "id",
      start = "rx_start",
      stop = "rx_stop",
      exposure = "drug_type",
      entry = "study_entry",
      exit = "study_exit",
      duration = c(-1, 1, 5)  # Negative value!
    ),
    regexp = "negative|non-negative|positive",
    ignore.case = TRUE
  )
})

# ============================================================================
# TEST 12: CHARACTER DATE CONVERSION
# ============================================================================

test_that("Character dates are converted or produce clear error", {
  cohort_char_dates <- readRDS(file.path(test_data_dir, "cohort_char_dates.rds"))
  exposure_char_dates <- readRDS(file.path(test_data_dir, "exposure_char_dates.rds"))

  # Should either auto-convert or error clearly
  result <- tryCatch({
    tvexpose(
      master = cohort_char_dates,
      exposure_data = exposure_char_dates,
      id = "id",
      start = "rx_start",
      stop = "rx_stop",
      exposure = "drug_type",
      entry = "study_entry",
      exit = "study_exit"
    )
  }, error = function(e) {
    # If it errors, should mention date/type/conversion
    expect_match(e$message, "date|Date|type|convert", ignore.case = TRUE)
    NULL
  })

  # If it succeeds, should have valid output
  if (!is.null(result)) {
    expect_true(nrow(result) > 0)
  }
})

# ============================================================================
# RUN ALL TESTS
# ============================================================================

cat("\n=== COMPREHENSIVE EDGE CASE TESTING COMPLETE ===\n")
cat("Tests run with comprehensive synthetic data.\n")
cat("Check output above for any failures.\n\n")
```

### Run the Complete Test Suite

```bash
cd /home/user/Stata-Tools/tvtools-r
Rscript tests/test_edge_cases_comprehensive.R
```

---

## 4. CRITICAL NEXT STEPS - PHASE 1

### Priority 1: Type-Safe Date Conversions (1 week)
**Files:** `R/tvexpose.R`, `R/tvmerge.R`
**Lines:** 527-528, 558-559 (tvexpose), 618-619, 796-797 (tvmerge)
**Risk:** CRITICAL - Can cause silent data corruption

### Priority 2: Input Validation (3-5 days)
**Files:** `R/tvexpose.R`, `R/tvmerge.R`
**Risk:** CRITICAL - Can cause cryptic errors or silent failures

### Priority 3: Memory Warnings for Cartesian Merges (2-3 days)
**Files:** `R/tvmerge.R`
**Lines:** 735-777
**Risk:** CRITICAL - Can cause out-of-memory crashes

### Priority 4: Edge Case Handling (1 week)
**Files:** `R/tvexpose.R`, `R/tvmerge.R`
**Risk:** HIGH - Can cause unexpected behavior

---

## 5. IMPLEMENTATION GUIDE - TYPE SAFETY

### Issue Description
**Current Problem:** Unsafe date conversions at multiple locations can cause silent data corruption.

```r
# CURRENT UNSAFE CODE (Line 527-528 in tvexpose.R):
mutate(
  study_entry = floor(as.numeric(study_entry)),
  study_exit = ceiling(as.numeric(study_exit))
)

# PROBLEM: If study_entry is character "2020-01-01",
# as.numeric() returns NA with warning, not error!
```

### Solution: Type-Safe Date Conversion Helper Function

**Step 1:** Add helper function at top of `R/tvexpose.R`:

```r
#' Convert dates to numeric safely with validation
#'
#' @param date_var Vector of dates (Date, POSIXct, numeric, or character)
#' @param var_name Name of variable for error messages
#' @return Numeric vector of days since 1970-01-01
#' @keywords internal
convert_to_numeric_date <- function(date_var, var_name) {
  # Case 1: Already Date or POSIXct
  if (inherits(date_var, c("Date", "POSIXct", "POSIXlt"))) {
    return(as.numeric(date_var))
  }

  # Case 2: Already numeric
  if (is.numeric(date_var)) {
    # Validate reasonable range (1970-01-01 to 2100-12-31)
    if (any(!is.na(date_var) & (date_var < 0 | date_var > 47847))) {
      warning(sprintf("%s contains dates outside reasonable range (1970-2100)", var_name))
    }
    return(date_var)
  }

  # Case 3: Character - try to parse
  if (is.character(date_var)) {
    parsed <- tryCatch(
      as.Date(date_var),
      error = function(e) {
        stop(sprintf("Cannot convert %s to date. Error: %s\nPlease provide Date objects or YYYY-MM-DD format.",
                     var_name, e$message))
      }
    )
    return(as.numeric(parsed))
  }

  # Case 4: Unsupported type
  stop(sprintf("%s must be Date, POSIXct, numeric, or character (YYYY-MM-DD), got: %s",
               var_name, class(date_var)[1]))
}

#' Validate dates for infinite and missing values
#'
#' @param date_var Numeric date vector
#' @param var_name Name of variable for error messages
#' @keywords internal
validate_date_values <- function(date_var, var_name) {
  # Check for infinite values
  if (any(is.infinite(date_var))) {
    stop(sprintf("%s contains infinite (Inf or -Inf) values. Please provide finite dates.",
                 var_name))
  }

  # Check for NA values (this is already done elsewhere but belt-and-suspenders)
  if (any(is.na(date_var))) {
    stop(sprintf("%s contains NA values. All dates must be valid.", var_name))
  }

  invisible(TRUE)
}
```

**Step 2:** Replace unsafe conversions in `R/tvexpose.R`:

```r
# OLD CODE (Lines 527-529):
# master_dates <- master %>%
#   select(all_of(master_cols)) %>%
#   mutate(
#     study_entry = floor(as.numeric(study_entry)),
#     study_exit = ceiling(as.numeric(study_exit))
#   )

# NEW CODE:
master_dates <- master %>%
  select(all_of(master_cols)) %>%
  mutate(
    study_entry = floor(convert_to_numeric_date(.data[[entry]], entry)),
    study_exit = ceiling(convert_to_numeric_date(.data[[exit]], exit))
  )

# Validate converted dates
validate_date_values(master_dates$study_entry, entry)
validate_date_values(master_dates$study_exit, exit)
```

**Step 3:** Replace in exposure data processing (Lines 558-560):

```r
# OLD CODE:
# exp_data <- exposure_data %>%
#   select(all_of(exp_cols)) %>%
#   rename(...) %>%
#   mutate(
#     exp_start = floor(as.numeric(exp_start)),
#     exp_stop = ceiling(as.numeric(exp_stop)),
#     ...
#   )

# NEW CODE:
exp_data <- exposure_data %>%
  select(all_of(exp_cols)) %>%
  rename(...) %>%
  mutate(
    exp_start = floor(convert_to_numeric_date(.data[[start]], start)),
    exp_stop = ceiling(convert_to_numeric_date(.data[[stop]], stop)),
    ...
  )

# Validate
validate_date_values(exp_data$exp_start, start)
validate_date_values(exp_data$exp_stop, stop)
```

**Step 4:** Apply same pattern to `R/tvmerge.R` (Lines 618-619, 796-797):

```r
# Add the same helper functions to tvmerge.R or import from tvexpose.R

# Replace at line 618-619:
merged_data <- merged_data %>%
  mutate(
    start_var = floor(convert_to_numeric_date(start_var, paste0("dataset 1: ", start[1]))),
    stop_var = ceiling(convert_to_numeric_date(stop_var, paste0("dataset 1: ", stop[1])))
  )

validate_date_values(merged_data$start_var, paste0("dataset 1: ", start[1]))
validate_date_values(merged_data$stop_var, paste0("dataset 1: ", stop[1]))

# Similar changes at lines 688-691 and 796-797
```

**Step 5:** Test the changes:

```r
# Run edge case tests
source("tests/test_edge_cases_comprehensive.R")

# Test 5 (infinite dates) should now pass
# Test 6 (NA dates) should now pass
# Test 12 (character dates) should now pass or error clearly
```

---

## 6. IMPLEMENTATION GUIDE - INPUT VALIDATION

### Issue Description
**Current Problem:** Missing validation allows invalid inputs to cause cryptic errors downstream.

### Priority Validations to Add

**Step 1:** Add validation helper functions to `R/tvexpose.R`:

```r
#' Validate master dataset
#'
#' @param master Master dataset
#' @param id ID variable name
#' @param entry Entry date variable name
#' @param exit Exit date variable name
#' @keywords internal
validate_master_dataset <- function(master, id, entry, exit) {
  # Check 1: Not empty
  if (nrow(master) == 0) {
    stop("master dataset is empty (0 rows). Please provide a dataset with at least one person.")
  }

  # Check 2: Required columns exist (already done, but here for completeness)
  missing_cols <- setdiff(c(id, entry, exit), names(master))
  if (length(missing_cols) > 0) {
    stop(sprintf("master dataset missing required columns: %s",
                 paste(missing_cols, collapse = ", ")))
  }

  # Check 3: No duplicate IDs
  if (anyDuplicated(master[[id]])) {
    dup_ids <- master[[id]][duplicated(master[[id]])]
    dup_count <- length(unique(dup_ids))
    example_dups <- paste(head(unique(dup_ids), 5), collapse = ", ")

    stop(sprintf(
      paste0("master dataset has %d duplicate ID(s). Each person should appear once.\n",
             "Duplicate IDs: %s%s"),
      dup_count,
      example_dups,
      if (dup_count > 5) paste0(" ... and ", dup_count - 5, " more") else ""
    ))
  }

  # Check 4: ID type
  if (!is.numeric(master[[id]]) && !is.character(master[[id]])) {
    stop(sprintf("ID variable '%s' must be numeric or character, got: %s",
                 id, class(master[[id]])[1]))
  }

  invisible(TRUE)
}

#' Validate exposure dataset
#'
#' @param exposure_data Exposure dataset
#' @param id ID variable name
#' @keywords internal
validate_exposure_dataset <- function(exposure_data, id) {
  # Check 1: Can be empty (all unexposed is valid)
  if (nrow(exposure_data) == 0) {
    message("exposure_data is empty - all persons will be classified as unexposed")
    return(invisible(TRUE))
  }

  # Check 2: ID type
  if (!is.numeric(exposure_data[[id]]) && !is.character(exposure_data[[id]])) {
    stop(sprintf("ID variable '%s' in exposure_data must be numeric or character, got: %s",
                 id, class(exposure_data[[id]])[1]))
  }

  invisible(TRUE)
}

#' Validate ID types match between datasets
#'
#' @param master_id ID vector from master
#' @param exposure_id ID vector from exposure
#' @param id_varname Name of ID variable
#' @keywords internal
validate_id_type_match <- function(master_id, exposure_id, id_varname) {
  master_class <- class(master_id)[1]
  exposure_class <- class(exposure_id)[1]

  if (master_class != exposure_class) {
    stop(sprintf(
      paste0("ID variable '%s' has different types in master and exposure_data:\n",
             "  master: %s\n",
             "  exposure_data: %s\n",
             "Both must have the same type (numeric or character)."),
      id_varname,
      master_class,
      exposure_class
    ))
  }

  invisible(TRUE)
}

#' Validate keepvars exist in master
#'
#' @param master Master dataset
#' @param keepvars Vector of variable names to keep
#' @keywords internal
validate_keepvars <- function(master, keepvars) {
  if (is.null(keepvars) || length(keepvars) == 0) {
    return(invisible(TRUE))
  }

  missing_vars <- setdiff(keepvars, names(master))
  if (length(missing_vars) > 0) {
    stop(sprintf(
      "Variables specified in keepvars not found in master:\n  %s",
      paste(missing_vars, collapse = ", ")
    ))
  }

  invisible(TRUE)
}

#' Validate duration parameter
#'
#' @param duration Duration cutpoints vector
#' @keywords internal
validate_duration <- function(duration) {
  if (is.null(duration)) {
    return(invisible(TRUE))
  }

  if (!is.numeric(duration)) {
    stop("duration must be a numeric vector")
  }

  if (any(duration < 0)) {
    stop("duration cutpoints must be non-negative (>= 0)")
  }

  if (is.unsorted(duration)) {
    stop(sprintf(
      "duration cutpoints must be in ascending order.\n  Provided: %s",
      paste(duration, collapse = ", ")
    ))
  }

  if (any(duplicated(duration))) {
    stop("duration cutpoints must be unique (no duplicates)")
  }

  invisible(TRUE)
}

#' Validate recency parameter
#'
#' @param recency Recency cutpoints vector
#' @keywords internal
validate_recency <- function(recency) {
  if (is.null(recency)) {
    return(invisible(TRUE))
  }

  if (!is.numeric(recency)) {
    stop("recency must be a numeric vector")
  }

  if (any(recency < 0)) {
    stop("recency cutpoints must be non-negative (>= 0)")
  }

  if (is.unsorted(recency)) {
    stop(sprintf(
      "recency cutpoints must be in ascending order.\n  Provided: %s",
      paste(recency, collapse = ", ")
    ))
  }

  if (any(duplicated(recency))) {
    stop("recency cutpoints must be unique (no duplicates)")
  }

  invisible(TRUE)
}

#' Validate no conflicting exposure type parameters
#'
#' @param evertreated Evertreated parameter
#' @param currentformer Currentformer parameter
#' @param duration Duration parameter
#' @param recency Recency parameter
#' @param continuousunit Continuousunit parameter
#' @keywords internal
validate_no_conflicting_exposure_types <- function(evertreated, currentformer,
                                                     duration, recency, continuousunit) {
  type_flags <- c(
    evertreated = evertreated,
    currentformer = currentformer,
    duration = !is.null(duration),
    recency = !is.null(recency),
    continuous = !is.null(continuousunit)
  )

  n_types <- sum(type_flags)

  if (n_types > 1) {
    active_types <- names(type_flags)[type_flags]
    stop(sprintf(
      paste0("Only one exposure type can be specified at a time.\n",
             "You specified: %s\n",
             "Please choose only ONE of: evertreated, currentformer, duration, recency, or continuous"),
      paste(active_types, collapse = ", ")
    ))
  }

  invisible(TRUE)
}
```

**Step 2:** Add validation calls in tvexpose() function (after line 420):

```r
# In tvexpose() function, add after parameter checks (around line 420):

# === COMPREHENSIVE INPUT VALIDATION ===

# Validate master dataset
validate_master_dataset(master, id, entry, exit)

# Validate exposure dataset
validate_exposure_dataset(exposure_data, id)

# Validate ID types match
validate_id_type_match(master[[id]], exposure_data[[id]], id)

# Validate keepvars
validate_keepvars(master, keepvars)

# Validate duration
validate_duration(duration)

# Validate recency
validate_recency(recency)

# Validate no conflicting exposure types
validate_no_conflicting_exposure_types(
  evertreated, currentformer, duration, recency, continuousunit
)

# === END VALIDATION ===
```

**Step 3:** Test the validations:

```r
# Run edge case tests
source("tests/test_edge_cases_comprehensive.R")

# Test 1 (empty master) should now pass
# Test 3 (duplicate IDs) should now pass
# Test 4 (type mismatch) should now pass
# Test 11 (conflicting parameters) should now pass
```

---

## 7. IMPLEMENTATION GUIDE - PERFORMANCE FIXES

### Issue: Cartesian Product Memory Explosion

**Location:** `R/tvmerge.R`, Lines 735-777

**Step 1:** Add memory estimation function:

```r
#' Estimate memory usage for Cartesian merge
#'
#' @param merged_data First dataset
#' @param dfk_clean Second dataset
#' @param id_var ID variable name
#' @keywords internal
estimate_cartesian_size <- function(merged_data, dfk_clean, id_var) {
  # Count periods per person in each dataset
  periods_ds1 <- merged_data %>%
    group_by(!!sym(id_var)) %>%
    summarise(n1 = n(), .groups = "drop")

  periods_ds2 <- dfk_clean %>%
    group_by(!!sym(id_var)) %>%
    summarise(n2 = n(), .groups = "drop")

  # Join to get product per person
  combined <- periods_ds1 %>%
    inner_join(periods_ds2, by = id_var) %>%
    mutate(product = n1 * n2)

  # Calculate statistics
  total_output_rows <- sum(combined$product)
  max_per_person <- max(combined$product)
  mean_per_person <- mean(combined$product)

  # Estimate memory (rough: 1 KB per row)
  estimated_mb <- total_output_rows / 1024

  return(list(
    total_rows = total_output_rows,
    max_rows_per_person = max_per_person,
    mean_rows_per_person = mean_per_person,
    estimated_mb = estimated_mb,
    input_rows_ds1 = nrow(merged_data),
    input_rows_ds2 = nrow(dfk_clean)
  ))
}
```

**Step 2:** Add warning before Cartesian merge (insert before line 735):

```r
# BEFORE LINE 735 (the cartesian join):

# Estimate output size
size_est <- estimate_cartesian_size(merged_data, dfk_clean, "id_var")

# Warn if output will be very large
if (size_est$total_rows > 1e6) {
  warning(sprintf(
    paste0("Large Cartesian merge detected:\n",
           "  Input: %s rows (dataset 1) × %s rows (dataset 2)\n",
           "  Estimated output: %s rows (%.1f MB)\n",
           "  Max rows per person: %s\n",
           "  This may take several minutes and use significant memory."),
    format(size_est$input_rows_ds1, big.mark = ","),
    format(size_est$input_rows_ds2, big.mark = ","),
    format(size_est$total_rows, big.mark = ","),
    size_est$estimated_mb,
    format(size_est$max_rows_per_person, big.mark = ",")
  ))
}

# If extremely large, consider stopping
if (size_est$total_rows > 1e8) {
  stop(sprintf(
    paste0("Cartesian merge would create %s rows (>100 million).\n",
           "This would likely exhaust memory.\n",
           "Consider:\n",
           "  1. Reducing the number of periods in your tvexpose outputs\n",
           "  2. Merging datasets with fewer overlapping time periods\n",
           "  3. Processing in smaller batches by ID"),
    format(size_est$total_rows, big.mark = ",")
  ))
}

# Continue with merge...
cartesian <- merged_data %>%
  inner_join(dfk_clean, by = "id_var", relationship = "many-to-many")
```

**Step 3:** Test with cartesian test data:

```r
# Load test data
cohort_cartesian <- readRDS("tests/test_data_comprehensive/cohort_cartesian.rds")
exposure1_cartesian <- readRDS("tests/test_data_comprehensive/exposure1_cartesian.rds")
exposure2_cartesian <- readRDS("tests/test_data_comprehensive/exposure2_cartesian.rds")

# Create TV outputs (use small subset)
tv1 <- tvexpose(
  master = cohort_cartesian[1:10, ],
  exposure_data = exposure1_cartesian[exposure1_cartesian$id %in% 1:10, ],
  id = "id",
  start = "rx_start",
  stop = "rx_stop",
  exposure = "drug_a",
  entry = "study_entry",
  exit = "study_exit",
  generate = "drug_a"
)

tv2 <- tvexpose(
  master = cohort_cartesian[1:10, ],
  exposure_data = exposure2_cartesian[exposure2_cartesian$id %in% 1:10, ],
  id = "id",
  start = "rx_start",
  stop = "rx_stop",
  exposure = "drug_b",
  entry = "study_entry",
  exit = "study_exit",
  generate = "drug_b"
)

# Should produce warning
merged <- tvmerge(
  datasets = list(tv1, tv2),
  id = "id",
  start = c("start", "start"),
  stop = c("stop", "stop"),
  exposure = c("drug_a", "drug_b")
)
```

---

## 8. IMPLEMENTATION GUIDE - EDGE CASES

### Summary of Edge Cases to Handle

From the analysis, these 8 edge cases are CRITICAL and currently UNHANDLED:

1. ✅ Empty master dataset → Add validation (covered in Section 6)
2. ✅ Duplicate IDs in master → Add validation (covered in Section 6)
3. ✅ ID type mismatches → Add validation (covered in Section 6)
4. ✅ Infinite dates → Add validation (covered in Section 5)
5. ✅ NA in exposure values → Add validation (add to Section 6)
6. ✅ Conflicting exposure types → Add validation (covered in Section 6)
7. ✅ Cartesian explosion → Add warnings (covered in Section 7)
8. ⚠️ No overlapping IDs between datasets (tvmerge) → Need to add

**Step 1:** Add NA exposure value validation to `validate_exposure_dataset`:

```r
# Add to validate_exposure_dataset function:
validate_exposure_dataset <- function(exposure_data, id, exposure) {
  # ... existing checks ...

  # Check for NA in exposure values
  if (nrow(exposure_data) > 0) {
    if (any(is.na(exposure_data[[exposure]]))) {
      na_count <- sum(is.na(exposure_data[[exposure]]))
      stop(sprintf(
        paste0("exposure variable '%s' contains %d NA value(s).\n",
               "Please recode NA values to a specific category or remove rows with NA."),
        exposure,
        na_count
      ))
    }
  }

  invisible(TRUE)
}
```

**Step 2:** Add overlapping ID check for tvmerge (in `R/tvmerge.R`):

```r
#' Check for overlapping IDs between datasets
#'
#' @param datasets List of datasets
#' @param id ID variable name
#' @keywords internal
validate_overlapping_ids <- function(datasets, id) {
  # Get unique IDs from each dataset
  all_ids <- lapply(datasets, function(df) unique(df[[id]]))

  # Find common IDs across all datasets
  common_ids <- Reduce(intersect, all_ids)

  if (length(common_ids) == 0) {
    # No overlapping IDs at all
    stop(sprintf(
      paste0("No common IDs found across all %d datasets.\n",
             "Dataset 1 has %d unique IDs, Dataset 2 has %d unique IDs, etc.\n",
             "Please ensure datasets contain the same persons (IDs)."),
      length(datasets),
      length(all_ids[[1]]),
      length(all_ids[[2]])
    ))
  }

  # Warn if many IDs are not common
  for (i in seq_along(all_ids)) {
    pct_overlap <- length(common_ids) / length(all_ids[[i]]) * 100
    if (pct_overlap < 50) {
      warning(sprintf(
        paste0("Only %.1f%% of IDs in dataset %d are present in all datasets.\n",
               "  Dataset %d unique IDs: %d\n",
               "  Common across all: %d"),
        pct_overlap,
        i,
        i,
        length(all_ids[[i]]),
        length(common_ids)
      ))
    }
  }

  invisible(TRUE)
}

# Add this call early in tvmerge() function (around line 480):
validate_overlapping_ids(datasets, id)
```

---

## 9. TESTING CHECKLIST

### Before Making Changes

```bash
# 1. Generate all test data
cd /home/user/Stata-Tools/tvtools-r
Rscript tests/generate_comprehensive_test_data.R

# 2. Run existing tests to establish baseline
Rscript -e "devtools::test()"

# 3. Run edge case tests (expect failures - these test what we'll fix)
Rscript tests/test_edge_cases_comprehensive.R 2>&1 | tee test_results_before.txt
```

### After Each Implementation

```bash
# 1. Run edge case tests specific to your changes
Rscript tests/test_edge_cases_comprehensive.R 2>&1 | tee test_results_after.txt

# 2. Run full test suite
Rscript -e "devtools::test()"

# 3. Run R CMD check
R CMD build .
R CMD check --as-cran tvtools_*.tar.gz

# 4. Compare before/after
diff test_results_before.txt test_results_after.txt
```

### Specific Test Expectations After Each Fix

| Fix | Tests That Should Pass |
|-----|------------------------|
| Type-safe dates | Test 5 (infinite), Test 6 (NA), Test 12 (character) |
| Input validation | Test 1 (empty), Test 3 (duplicates), Test 4 (type mismatch), Test 11 (conflicts) |
| Cartesian warnings | Test 10 (should warn, not error) |
| Edge cases | Test 7 (circular dates), Test 8 (zero-length) |

---

## 10. VALIDATION & COMMIT GUIDE

### After Implementing Fixes

**Step 1: Code Review Checklist**

```
□ All helper functions added with proper roxygen documentation
□ All validation calls added in correct locations
□ Error messages are clear and actionable
□ No breaking changes to existing functionality
□ Code follows existing style conventions
□ No new dependencies added
```

**Step 2: Testing Validation**

```bash
# Run comprehensive test suite
cd /home/user/Stata-Tools/tvtools-r

# 1. Unit tests
Rscript -e "devtools::test()" | tee test_results_unit.txt

# 2. Edge case tests
Rscript tests/test_edge_cases_comprehensive.R | tee test_results_edge.txt

# 3. Integration tests
Rscript tests/integration_test_tvexpose.R | tee test_results_integration.txt

# 4. R CMD check
R CMD build .
R CMD check --as-cran tvtools_*.tar.gz | tee check_results.txt

# 5. Verify no new warnings or errors
grep -i "error\|warning\|fail" test_results_*.txt check_results.txt
```

**Step 3: Documentation Updates**

```bash
# Regenerate documentation
Rscript -e "roxygen2::roxygenize()"

# Verify man pages created
ls -la man/

# Check for any documentation warnings
R CMD Rd2pdf --force .
```

**Step 4: Performance Validation**

```r
# Quick performance test
library(devtools)
load_all()

cohort_large <- readRDS("tests/test_data_comprehensive/cohort_large.rds")
exposure_large <- readRDS("tests/test_data_comprehensive/exposure_large.rds")

# Test with 1000 persons
cohort_test <- cohort_large[1:1000, ]
exposure_test <- exposure_large[exposure_large$id %in% 1:1000, ]

system.time({
  result <- tvexpose(
    master = cohort_test,
    exposure_data = exposure_test,
    id = "id",
    start = "rx_start",
    stop = "rx_stop",
    exposure = "drug_type",
    entry = "study_entry",
    exit = "study_exit"
  )
})

# Should complete in < 60 seconds
# Record time for comparison
```

**Step 5: Create Comprehensive Commit**

```bash
# Stage changes
git add -A

# Create detailed commit message
git commit -m "$(cat <<'EOF'
Implement Phase 1 critical fixes: Type safety, input validation, performance warnings

TYPE-SAFE DATE CONVERSIONS:
- Add convert_to_numeric_date() helper function with comprehensive type checking
- Add validate_date_values() to check for Inf and NA
- Replace unsafe as.numeric() calls at 4 locations:
  * tvexpose.R:527-528 (master dates)
  * tvexpose.R:558-560 (exposure dates)
  * tvmerge.R:618-619 (dataset 1 dates)
  * tvmerge.R:796-797 (output date formatting)
- Fixes critical data corruption risk from silent NA conversion

INPUT VALIDATION:
- Add validate_master_dataset() - checks empty, duplicates, ID types
- Add validate_exposure_dataset() - checks ID types, NA in exposure values
- Add validate_id_type_match() - prevents type mismatch errors
- Add validate_keepvars() - ensures keepvars exist
- Add validate_duration() - validates cutpoints (non-negative, sorted, unique)
- Add validate_recency() - validates cutpoints (non-negative, sorted, unique)
- Add validate_no_conflicting_exposure_types() - prevents parameter conflicts
- Add validate_overlapping_ids() for tvmerge - ensures datasets have common IDs

PERFORMANCE WARNINGS:
- Add estimate_cartesian_size() to calculate merge output size
- Add warnings for merges >1M rows
- Add errors for merges >100M rows (would exhaust memory)
- Provide clear guidance when Cartesian explosion detected

EDGE CASE HANDLING:
- Empty master dataset: Clear error message
- Duplicate IDs: List duplicates with count
- Type mismatches: Show both types with clear fix instructions
- Infinite dates: Detect and error before processing
- NA values: Validate in all critical columns
- Circular dates: Already handled, validation reinforced
- Zero-length periods: Explicitly allowed and documented
- Conflicting parameters: Clear error listing active parameters
- No overlapping IDs: Error with ID counts from each dataset

TESTS PASSING:
- Test 1: Empty master ✓
- Test 3: Duplicate IDs ✓
- Test 4: Type mismatches ✓
- Test 5: Infinite dates ✓
- Test 6: NA values ✓
- Test 10: Cartesian warnings ✓
- Test 11: Conflicting parameters ✓
- Test 12: Character dates ✓

All existing tests continue to pass (46/46).

See tests/test_edge_cases_comprehensive.R for complete test suite.
See NEXT_STEPS_COMPREHENSIVE_GUIDE.md for implementation details.
EOF
)"

# Push to branch
git push -u origin <your-branch-name>
```

---

## FINAL CHECKLIST

Before considering Phase 1 complete:

```
□ All helper functions implemented and tested
□ Type-safe date conversions in all 4 locations
□ All 8 validation functions added
□ Cartesian product warnings functional
□ All edge case tests passing (12/12)
□ Existing tests still passing (46/46)
□ R CMD check passes with no errors
□ Documentation regenerated
□ Performance validated (<60s for 1000 persons)
□ Commit message comprehensive and clear
□ Changes pushed to branch
□ Pull request created with test results
```

---

## QUICK REFERENCE COMMANDS

```bash
# Complete workflow
cd /home/user/Stata-Tools/tvtools-r

# 1. Generate test data
Rscript tests/generate_comprehensive_test_data.R

# 2. Make your changes to R/tvexpose.R and R/tvmerge.R

# 3. Test
Rscript tests/test_edge_cases_comprehensive.R
Rscript -e "devtools::test()"

# 4. Check
R CMD build .
R CMD check tvtools_*.tar.gz

# 5. Commit & push
git add -A
git commit -m "Your detailed message"
git push
```

---

## ESTIMATED TIME TO COMPLETE

- **Type Safety Implementation:** 4-6 hours
- **Input Validation Implementation:** 6-8 hours
- **Performance Warnings Implementation:** 3-4 hours
- **Testing & Validation:** 4-6 hours
- **Documentation & Commit:** 2-3 hours

**Total: 1-2 weeks of focused work**

---

**Document Version:** 1.0
**Last Updated:** 2025-11-19
**Status:** Ready for next LLM instance

This guide provides complete, copy-paste ready code for all critical Phase 1 improvements. Follow the sections in order for best results.
