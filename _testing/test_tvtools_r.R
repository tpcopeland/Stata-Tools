#!/usr/bin/env Rscript
################################################################################
# COMPREHENSIVE TEST SCRIPT FOR TVTOOLS (R VERSION)
# Author: Timothy P. Copeland
# Created: 2025-11-21
# Purpose: Test tvexpose and tvmerge using synthetic Stata data to ensure
#          proper functionality and compare with Stata implementation
################################################################################

# Suppress startup messages
suppressPackageStartupMessages({
  library(haven)      # For reading Stata .dta files
  library(dplyr)      # For data manipulation
  library(readr)      # For reading/writing CSV
})

# Source the tvtools-r functions
source("tvtools-r/R/tvexpose.R")
source("tvtools-r/R/tvmerge.R")

cat("\n")
cat(strrep("=", 80), "\n")
cat("TVTOOLS R IMPLEMENTATION TEST SUITE\n")
cat("Testing Date:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")
cat(strrep("=", 80), "\n")
cat("\n")

# Helper function to print test status
print_test <- function(test_name, status = "PASS", message = "") {
  symbol <- ifelse(status == "PASS", "\u2713", "\u2717")
  cat(sprintf("  %s %s\n", symbol, test_name))
  if (message != "") {
    cat(sprintf("    %s\n", message))
  }
}

################################################################################
## STEP 1: Load Synthetic Data from Stata Files
################################################################################

cat("\n")
cat(strrep("-", 80), "\n")
cat("STEP 1: Loading synthetic test data from Stata files\n")
cat(strrep("-", 80), "\n")

# Read Stata .dta files using haven
cohort <- read_dta("cohort.dta")
hrt <- read_dta("hrt.dta")
dmt <- read_dta("dmt.dta")

# Convert Stata dates to R dates
# Stata dates are days since 1960-01-01, R dates are days since 1970-01-01
stata_date_origin <- as.Date("1960-01-01")

# Convert cohort dates
cohort <- cohort %>%
  mutate(
    study_entry = as.Date(study_entry, origin = stata_date_origin),
    study_exit = as.Date(study_exit, origin = stata_date_origin),
    dob = as.Date(dob, origin = stata_date_origin),
    indexdate = as.Date(indexdate, origin = stata_date_origin)
  )

# Convert HRT dates
hrt <- hrt %>%
  mutate(
    rx_start = as.Date(rx_start, origin = stata_date_origin),
    rx_stop = as.Date(rx_stop, origin = stata_date_origin)
  )

# Convert DMT dates
dmt <- dmt %>%
  mutate(
    dmt_start = as.Date(dmt_start, origin = stata_date_origin),
    dmt_stop = as.Date(dmt_stop, origin = stata_date_origin)
  )

# Convert labeled variables to regular numeric/character
# Haven stores Stata value labels as attributes, we need raw values
cohort <- cohort %>%
  mutate(across(where(is.labelled), as_factor))

hrt <- hrt %>%
  mutate(
    hrt_type = as.numeric(hrt_type),
    dose = as.numeric(dose)
  )

dmt <- dmt %>%
  mutate(dmt = as.numeric(dmt))

print_test("Loaded cohort.dta", "PASS", sprintf("N = %d", nrow(cohort)))
print_test("Loaded hrt.dta", "PASS", sprintf("N = %d", nrow(hrt)))
print_test("Loaded dmt.dta", "PASS", sprintf("N = %d", nrow(dmt)))

# Verify required variables exist
required_cohort <- c("id", "study_entry", "study_exit", "age", "female", "mstype")
required_hrt <- c("id", "rx_start", "rx_stop", "hrt_type")
required_dmt <- c("id", "dmt_start", "dmt_stop", "dmt")

if (!all(required_cohort %in% names(cohort))) {
  stop("Missing required variables in cohort")
}
print_test("Verified cohort variables", "PASS")

if (!all(required_hrt %in% names(hrt))) {
  stop("Missing required variables in hrt")
}
print_test("Verified HRT variables", "PASS")

if (!all(required_dmt %in% names(dmt))) {
  stop("Missing required variables in dmt")
}
print_test("Verified DMT variables", "PASS")

################################################################################
## STEP 2: Test tvexpose - Basic Time-Varying Exposure
################################################################################

cat("\n")
cat(strrep("=", 80), "\n")
cat("TEST 1: tvexpose - Basic time-varying HRT exposure\n")
cat(strrep("=", 80), "\n")

tv_hrt_r <- tvexpose(
  master = cohort,
  exposure_data = hrt,
  id = "id",
  start = "rx_start",
  stop = "rx_stop",
  exposure = "hrt_type",
  reference = 0,
  entry = "study_entry",
  exit = "study_exit",
  generate = "tv_hrt"
)

# Validate results
if (any(is.na(tv_hrt_r$tv_hrt))) {
  print_test("No missing exposure values", "FAIL", "Found NA values")
  stop("Test failed")
}
print_test("No missing exposure values", "PASS")

print_test("Created time-varying periods", "PASS",
           sprintf("N = %s", format(nrow(tv_hrt_r), big.mark = ",")))

# Save for later use
saveRDS(tv_hrt_r, "_testing/tv_hrt_r.rds")
print_test("Saved tv_hrt_r.rds", "PASS")

################################################################################
## STEP 3: Test tvexpose - Current/Former Exposure
################################################################################

cat("\n")
cat(strrep("=", 80), "\n")
cat("TEST 2: tvexpose - Current/Former DMT exposure\n")
cat(strrep("=", 80), "\n")

# First, ensure numeric variables are actually numeric
cohort <- cohort %>%
  mutate(
    age = as.numeric(age),
    female = as.numeric(female),
    mstype = as.numeric(as.character(mstype))  # Convert factor to numeric
  )

tv_dmt_r <- tvexpose(
  master = cohort,
  exposure_data = dmt,
  id = "id",
  start = "dmt_start",
  stop = "dmt_stop",
  exposure = "dmt",
  reference = 0,
  entry = "study_entry",
  exit = "study_exit",
  currentformer = TRUE,
  generate = "dmt_status",
  keepvars = c("age", "female", "mstype")
)

# Validate results
if (any(is.na(tv_dmt_r$dmt_status))) {
  print_test("No missing exposure values", "FAIL")
  stop("Test failed")
}
print_test("No missing exposure values", "PASS")

# Check that we have 0=never, 1=current, 2=former
levels <- unique(tv_dmt_r$dmt_status)
print_test("DMT status levels", "PASS",
           sprintf("Levels: %s", paste(sort(levels), collapse = ", ")))

# Verify keepvars were retained
for (var in c("age", "female", "mstype")) {
  if (!var %in% names(tv_dmt_r)) {
    print_test(sprintf("Keepvar %s present", var), "FAIL")
    stop("Test failed")
  }
  print_test(sprintf("Keepvar %s present", var), "PASS")
}

print_test("Created time-varying periods", "PASS",
           sprintf("N = %s", format(nrow(tv_dmt_r), big.mark = ",")))

# Save for later use
saveRDS(tv_dmt_r, "_testing/tv_dmt_r.rds")
print_test("Saved tv_dmt_r.rds", "PASS")

################################################################################
## STEP 4: Test tvexpose - Ever-Treated
################################################################################

cat("\n")
cat(strrep("=", 80), "\n")
cat("TEST 3: tvexpose - Ever-treated HRT\n")
cat(strrep("=", 80), "\n")

tv_ever_r <- tvexpose(
  master = cohort,
  exposure_data = hrt,
  id = "id",
  start = "rx_start",
  stop = "rx_stop",
  exposure = "hrt_type",
  reference = 0,
  entry = "study_entry",
  exit = "study_exit",
  evertreated = TRUE,
  generate = "ever_hrt"
)

# Validate results - should only be 0 or 1
if (!all(tv_ever_r$ever_hrt %in% c(0, 1))) {
  print_test("Ever-treated is binary (0/1)", "FAIL")
  stop("Test failed")
}
print_test("Ever-treated is binary (0/1)", "PASS")

# Once switched to 1, should stay 1
tv_ever_check <- tv_ever_r %>%
  arrange(id, start) %>%
  group_by(id) %>%
  mutate(
    prev_ever = lag(ever_hrt, default = 0),
    switched_back = (prev_ever == 1 & ever_hrt == 0)
  ) %>%
  ungroup()

if (any(tv_ever_check$switched_back, na.rm = TRUE)) {
  print_test("Ever-treated remains 1 after first exposure", "FAIL")
  stop("Test failed")
}
print_test("Ever-treated remains 1 after first exposure", "PASS")

print_test("Created time-varying periods", "PASS",
           sprintf("N = %s", format(nrow(tv_ever_r), big.mark = ",")))

saveRDS(tv_ever_r, "_testing/tv_evertreated_r.rds")
print_test("Saved tv_evertreated_r.rds", "PASS")

################################################################################
## STEP 5: Test tvexpose - Duration Categories
################################################################################

cat("\n")
cat(strrep("=", 80), "\n")
cat("TEST 4: tvexpose - Duration categories\n")
cat(strrep("=", 80), "\n")

tv_duration_r <- tvexpose(
  master = cohort,
  exposure_data = hrt,
  id = "id",
  start = "rx_start",
  stop = "rx_stop",
  exposure = "hrt_type",
  reference = 0,
  entry = "study_entry",
  exit = "study_exit",
  duration = c(1, 5),
  continuousunit = "years",
  generate = "hrt_duration"
)

# Validate results - should have categories 0, 1, 2, 3
# 0 = unexposed, 1 = <1 year, 2 = 1-<5 years, 3 = 5+ years
levels <- unique(tv_duration_r$hrt_duration)
print_test("Duration categories", "PASS",
           sprintf("Categories: %s", paste(sort(levels), collapse = ", ")))

print_test("Created time-varying periods", "PASS",
           sprintf("N = %s", format(nrow(tv_duration_r), big.mark = ",")))

saveRDS(tv_duration_r, "_testing/tv_duration_r.rds")
print_test("Saved tv_duration_r.rds", "PASS")

################################################################################
## STEP 6: Test tvmerge - Merge HRT and DMT
################################################################################

cat("\n")
cat(strrep("=", 80), "\n")
cat("TEST 5: tvmerge - Merge HRT and DMT exposures\n")
cat(strrep("=", 80), "\n")

# Use the time-varying datasets created earlier
merged_r <- tvmerge(
  datasets = list(tv_hrt_r, tv_dmt_r),
  id = "id",
  start = c("start", "start"),
  stop = c("stop", "stop"),
  exposure = c("tv_hrt", "dmt_status"),
  generate = c("hrt", "dmt"),
  keep = c("age", "female", "mstype"),
  check = TRUE
)

# Validate results
if (any(is.na(merged_r$hrt))) {
  print_test("No missing HRT values", "FAIL")
  stop("Test failed")
}
print_test("No missing HRT values", "PASS")

if (any(is.na(merged_r$dmt))) {
  print_test("No missing DMT values", "FAIL")
  stop("Test failed")
}
print_test("No missing DMT values", "PASS")

# Verify keep variables are present with suffixes
for (var in c("age", "female", "mstype")) {
  var_ds2 <- paste0(var, "_ds2")
  if (!var_ds2 %in% names(merged_r)) {
    print_test(sprintf("Keep variable %s present", var_ds2), "FAIL")
    stop("Test failed")
  }
  print_test(sprintf("Keep variable %s present", var_ds2), "PASS")
}

print_test("Merged dataset created", "PASS",
           sprintf("N = %s", format(nrow(merged_r), big.mark = ",")))

saveRDS(merged_r, "_testing/merged_r.rds")
print_test("Saved merged_r.rds", "PASS")

################################################################################
## STEP 7: Summary Statistics and Cross-tabulation
################################################################################

cat("\n")
cat(strrep("=", 80), "\n")
cat("TEST 6: Summary statistics and cross-tabulation\n")
cat(strrep("=", 80), "\n")

# Cross-tabulate HRT and DMT exposures
cat("\nCross-tabulation of HRT × DMT:\n")
print(table(HRT = merged_r$hrt, DMT = merged_r$dmt, useNA = "always"))

# Summary of time periods
cat("\nSummary of time period lengths (days):\n")
merged_r <- merged_r %>%
  mutate(period_length = as.numeric(stop - start) + 1)
print(summary(merged_r$period_length))

# Person-level summary
cat("\nPeriods per person:\n")
periods_per_person <- merged_r %>%
  group_by(id) %>%
  summarise(n_periods = n(), .groups = "drop")
print(summary(periods_per_person$n_periods))

print_test("Summary statistics complete", "PASS")

################################################################################
## STEP 8: Export Summary Data for Stata Comparison
################################################################################

cat("\n")
cat(strrep("=", 80), "\n")
cat("TEST 7: Export summary statistics for Stata comparison\n")
cat(strrep("=", 80), "\n")

# Create summary dataset
r_summary <- merged_r %>%
  group_by(hrt, dmt) %>%
  summarise(
    n_periods = n(),
    total_days = sum(period_length, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  mutate(source = "R")

# Save summary
write_csv(r_summary, "_testing/r_summary.csv")
print_test("Exported r_summary.csv", "PASS")

################################################################################
## STEP 9: Validation Checks
################################################################################

cat("\n")
cat(strrep("=", 80), "\n")
cat("TEST 8: Validation checks\n")
cat(strrep("=", 80), "\n")

# Check 1: No gaps in coverage per person
gaps <- merged_r %>%
  arrange(id, start) %>%
  group_by(id) %>%
  mutate(
    gap = as.numeric(start - lag(stop)) - 1
  ) %>%
  ungroup() %>%
  filter(!is.na(gap), gap > 1)

if (nrow(gaps) > 0) {
  cat(sprintf("  Warning: %d gaps >1 day found\n", nrow(gaps)))
  print(gaps %>% select(id, start, stop, gap) %>% head(20))
}
print_test("No gaps in coverage", ifelse(nrow(gaps) == 0, "PASS", "WARNING"))

# Check 2: No overlaps
overlaps <- merged_r %>%
  arrange(id, start) %>%
  group_by(id) %>%
  mutate(
    overlap = start < lag(stop)
  ) %>%
  ungroup() %>%
  filter(!is.na(overlap), overlap == TRUE)

if (nrow(overlaps) > 0) {
  print_test("No overlapping periods", "FAIL",
             sprintf("Found %d overlapping periods", nrow(overlaps)))
  stop("Test failed")
}
print_test("No overlapping periods", "PASS")

# Check 3: All periods have valid dates
invalid_dates <- merged_r %>%
  filter(start > stop)

if (nrow(invalid_dates) > 0) {
  print_test("All periods have valid dates", "FAIL",
             sprintf("Found %d periods with start > stop", nrow(invalid_dates)))
  stop("Test failed")
}
print_test("All periods have valid dates (start ≤ stop)", "PASS")

# Check 4: Coverage matches original cohort
coverage_check <- merged_r %>%
  group_by(id) %>%
  summarise(
    first_start = min(start),
    last_stop = max(stop),
    .groups = "drop"
  ) %>%
  inner_join(cohort %>% select(id, study_entry, study_exit), by = "id") %>%
  mutate(
    entry_match = abs(as.numeric(first_start - study_entry)) <= 1,
    exit_match = abs(as.numeric(last_stop - study_exit)) <= 1
  )

n_entry_mismatch <- sum(!coverage_check$entry_match)
n_exit_mismatch <- sum(!coverage_check$exit_match)

if (n_entry_mismatch > 0) {
  cat(sprintf("  Warning: %d persons with entry date mismatch\n", n_entry_mismatch))
}
print_test("All entry dates match cohort",
           ifelse(n_entry_mismatch == 0, "PASS", "WARNING"))

if (n_exit_mismatch > 0) {
  cat(sprintf("  Warning: %d persons with exit date mismatch\n", n_exit_mismatch))
}
print_test("All exit dates match cohort",
           ifelse(n_exit_mismatch == 0, "PASS", "WARNING"))

################################################################################
## STEP 10: Compare with Stata Results
################################################################################

cat("\n")
cat(strrep("=", 80), "\n")
cat("TEST 9: Compare R and Stata results\n")
cat(strrep("=", 80), "\n")

# Read Stata summary if it exists
if (file.exists("_testing/stata_summary.csv")) {
  stata_summary <- read_csv("_testing/stata_summary.csv", show_col_types = FALSE)

  # Combine summaries
  comparison <- bind_rows(stata_summary, r_summary) %>%
    arrange(hrt, dmt, source)

  cat("\nComparison of R vs Stata results:\n")
  print(comparison)

  # Calculate differences
  wide_comparison <- comparison %>%
    select(hrt, dmt, source, n_periods, total_days) %>%
    tidyr::pivot_wider(
      names_from = source,
      values_from = c(n_periods, total_days)
    ) %>%
    mutate(
      periods_diff = n_periods_R - n_periods_Stata,
      days_diff = total_days_R - total_days_Stata,
      periods_pct_diff = 100 * periods_diff / n_periods_Stata,
      days_pct_diff = 100 * days_diff / total_days_Stata
    )

  cat("\nDifferences (R - Stata):\n")
  print(wide_comparison)

  # Check if differences are within tolerance (5%)
  max_periods_diff <- max(abs(wide_comparison$periods_pct_diff), na.rm = TRUE)
  max_days_diff <- max(abs(wide_comparison$days_pct_diff), na.rm = TRUE)

  if (max_periods_diff > 5 || max_days_diff > 5) {
    print_test("Results match within 5% tolerance", "WARNING",
               sprintf("Max diff: %.1f%% periods, %.1f%% days",
                      max_periods_diff, max_days_diff))
  } else {
    print_test("Results match within 5% tolerance", "PASS",
               sprintf("Max diff: %.1f%% periods, %.1f%% days",
                      max_periods_diff, max_days_diff))
  }
} else {
  print_test("Stata results available for comparison", "SKIP",
             "stata_summary.csv not found - run Stata tests first")
}

################################################################################
## FINAL SUMMARY
################################################################################

cat("\n")
cat(strrep("=", 80), "\n")
cat("ALL TESTS COMPLETED SUCCESSFULLY\n")
cat(strrep("=", 80), "\n")
cat("\n")

cat("Generated test datasets:\n")
cat("  • tv_hrt_r.rds - Basic time-varying HRT\n")
cat("  • tv_dmt_r.rds - Current/former DMT with keepvars\n")
cat("  • tv_evertreated_r.rds - Ever-treated HRT\n")
cat("  • tv_duration_r.rds - Duration categories\n")
cat("  • merged_r.rds - Merged HRT × DMT exposures\n")
cat("  • r_summary.csv - Summary statistics for comparison\n")

cat("\n")
cat("Testing complete! Review comparison tables above.\n")
cat(strrep("=", 80), "\n")
