#!/usr/bin/env Rscript

################################################################################
# Comprehensive R tvtools Test Suite
# Tests all functions with all option combinations
################################################################################

cat("=" , rep("=", 78), "\n", sep="")
cat("Comprehensive R tvtools Test Suite\n")
cat("=" , rep("=", 78), "\n\n", sep="")

# Setup -----------------------------------------------------------------------
library(dplyr)
library(readr)

# Create output directory
output_dir <- "/home/user/Stata-Tools/Reimplementations/Testing/R_comprehensive_outputs"
if (!dir.exists(output_dir)) {
  dir.create(output_dir, recursive = TRUE)
}

# Install tvtools package from local directory
cat("Installing tvtools package from local directory...\n")
tryCatch({
  install.packages("/home/user/Stata-Tools/Reimplementations/R/tvtools",
                   repos = NULL, type = "source", quiet = TRUE)
  cat("✓ Package installed successfully\n\n")
}, error = function(e) {
  cat("✗ Package installation failed:", e$message, "\n\n")
  quit(status = 1)
})

library(tvtools)

# Initialize results tracking
test_results <- list()
test_counter <- 0

# Helper function to record test results
record_test <- function(test_name, category, success, error_msg = NULL,
                        nrow = NA, ncol = NA, n_patients = NA, notes = "") {
  test_counter <<- test_counter + 1
  test_results[[test_counter]] <<- list(
    test_num = test_counter,
    category = category,
    test_name = test_name,
    success = success,
    error_msg = error_msg,
    nrow = nrow,
    ncol = ncol,
    n_patients = n_patients,
    notes = notes
  )
}

# Load test data --------------------------------------------------------------
cat("Loading test data...\n")
tryCatch({
  cohort <- read_csv("/home/user/Stata-Tools/Reimplementations/Testing/stress_cohort.csv",
                     show_col_types = FALSE) %>%
    mutate(
      startdate = as.Date(startdate),
      enddate = as.Date(enddate)
    )

  exposures <- read_csv("/home/user/Stata-Tools/Reimplementations/Testing/stress_exposures.csv",
                        show_col_types = FALSE) %>%
    mutate(
      expstart = as.Date(expstart),
      expend = as.Date(expend)
    )

  cat("✓ Cohort data loaded:", nrow(cohort), "rows,", ncol(cohort), "columns\n")
  cat("✓ Exposure data loaded:", nrow(exposures), "rows,", ncol(exposures), "columns\n\n")
}, error = function(e) {
  cat("✗ Failed to load test data:", e$message, "\n\n")
  quit(status = 1)
})

################################################################################
# TVEXPOSE TESTS
################################################################################

cat("=" , rep("=", 78), "\n", sep="")
cat("TVEXPOSE TESTS\n")
cat("=" , rep("=", 78), "\n\n", sep="")

# Test 1: Basic exposure (no special options)
cat("Test 1: Basic exposure (no special options)\n")
tryCatch({
  result <- TVExpose(
    cohort = cohort,
    cohort_id = "id",
    cohort_start = "startdate",
    cohort_end = "enddate",
    exposure = exposures,
    exposure_id = "id",
    exposure_start = "expstart",
    exposure_end = "expend"
  )
  write_csv(result, file.path(output_dir, "tvexpose_01_basic.csv"))
  record_test("Basic exposure", "TVExpose", TRUE,
              nrow = nrow(result), ncol = ncol(result),
              n_patients = n_distinct(result$id))
  cat("✓ PASSED - Output:", nrow(result), "rows,", ncol(result), "columns\n\n")
}, error = function(e) {
  record_test("Basic exposure", "TVExpose", FALSE, error_msg = e$message)
  cat("✗ FAILED:", e$message, "\n\n")
})

# Test 2: evertreated=TRUE
cat("Test 2: evertreated=TRUE\n")
tryCatch({
  result <- TVExpose(
    cohort = cohort,
    cohort_id = "id",
    cohort_start = "startdate",
    cohort_end = "enddate",
    exposure = exposures,
    exposure_id = "id",
    exposure_start = "expstart",
    exposure_end = "expend",
    evertreated = TRUE
  )
  write_csv(result, file.path(output_dir, "tvexpose_02_evertreated.csv"))
  record_test("evertreated=TRUE", "TVExpose", TRUE,
              nrow = nrow(result), ncol = ncol(result),
              n_patients = n_distinct(result$id))
  cat("✓ PASSED - Output:", nrow(result), "rows,", ncol(result), "columns\n\n")
}, error = function(e) {
  record_test("evertreated=TRUE", "TVExpose", FALSE, error_msg = e$message)
  cat("✗ FAILED:", e$message, "\n\n")
})

# Test 3: currentformer=TRUE
cat("Test 3: currentformer=TRUE\n")
tryCatch({
  result <- TVExpose(
    cohort = cohort,
    cohort_id = "id",
    cohort_start = "startdate",
    cohort_end = "enddate",
    exposure = exposures,
    exposure_id = "id",
    exposure_start = "expstart",
    exposure_end = "expend",
    currentformer = TRUE
  )
  write_csv(result, file.path(output_dir, "tvexpose_03_currentformer.csv"))
  record_test("currentformer=TRUE", "TVExpose", TRUE,
              nrow = nrow(result), ncol = ncol(result),
              n_patients = n_distinct(result$id))
  cat("✓ PASSED - Output:", nrow(result), "rows,", ncol(result), "columns\n\n")
}, error = function(e) {
  record_test("currentformer=TRUE", "TVExpose", FALSE, error_msg = e$message)
  cat("✗ FAILED:", e$message, "\n\n")
})

# Test 4: duration with cutpoints
cat("Test 4: duration with cutpoints c(30, 90, 180, 365)\n")
tryCatch({
  result <- TVExpose(
    cohort = cohort,
    cohort_id = "id",
    cohort_start = "startdate",
    cohort_end = "enddate",
    exposure = exposures,
    exposure_id = "id",
    exposure_start = "expstart",
    exposure_end = "expend",
    duration = c(30, 90, 180, 365)
  )
  write_csv(result, file.path(output_dir, "tvexpose_04_duration.csv"))
  record_test("duration with cutpoints", "TVExpose", TRUE,
              nrow = nrow(result), ncol = ncol(result),
              n_patients = n_distinct(result$id))
  cat("✓ PASSED - Output:", nrow(result), "rows,", ncol(result), "columns\n\n")
}, error = function(e) {
  record_test("duration with cutpoints", "TVExpose", FALSE, error_msg = e$message)
  cat("✗ FAILED:", e$message, "\n\n")
})

# Test 5: continuousunit="days"
cat("Test 5: continuousunit=\"days\"\n")
tryCatch({
  result <- TVExpose(
    cohort = cohort,
    cohort_id = "id",
    cohort_start = "startdate",
    cohort_end = "enddate",
    exposure = exposures,
    exposure_id = "id",
    exposure_start = "expstart",
    exposure_end = "expend",
    continuousunit = "days"
  )
  write_csv(result, file.path(output_dir, "tvexpose_05_continuous_days.csv"))
  record_test("continuousunit=days", "TVExpose", TRUE,
              nrow = nrow(result), ncol = ncol(result),
              n_patients = n_distinct(result$id))
  cat("✓ PASSED - Output:", nrow(result), "rows,", ncol(result), "columns\n\n")
}, error = function(e) {
  record_test("continuousunit=days", "TVExpose", FALSE, error_msg = e$message)
  cat("✗ FAILED:", e$message, "\n\n")
})

# Test 6: continuousunit="months"
cat("Test 6: continuousunit=\"months\"\n")
tryCatch({
  result <- TVExpose(
    cohort = cohort,
    cohort_id = "id",
    cohort_start = "startdate",
    cohort_end = "enddate",
    exposure = exposures,
    exposure_id = "id",
    exposure_start = "expstart",
    exposure_end = "expend",
    continuousunit = "months"
  )
  write_csv(result, file.path(output_dir, "tvexpose_06_continuous_months.csv"))
  record_test("continuousunit=months", "TVExpose", TRUE,
              nrow = nrow(result), ncol = ncol(result),
              n_patients = n_distinct(result$id))
  cat("✓ PASSED - Output:", nrow(result), "rows,", ncol(result), "columns\n\n")
}, error = function(e) {
  record_test("continuousunit=months", "TVExpose", FALSE, error_msg = e$message)
  cat("✗ FAILED:", e$message, "\n\n")
})

# Test 7: continuousunit="years"
cat("Test 7: continuousunit=\"years\"\n")
tryCatch({
  result <- TVExpose(
    cohort = cohort,
    cohort_id = "id",
    cohort_start = "startdate",
    cohort_end = "enddate",
    exposure = exposures,
    exposure_id = "id",
    exposure_start = "expstart",
    exposure_end = "expend",
    continuousunit = "years"
  )
  write_csv(result, file.path(output_dir, "tvexpose_07_continuous_years.csv"))
  record_test("continuousunit=years", "TVExpose", TRUE,
              nrow = nrow(result), ncol = ncol(result),
              n_patients = n_distinct(result$id))
  cat("✓ PASSED - Output:", nrow(result), "rows,", ncol(result), "columns\n\n")
}, error = function(e) {
  record_test("continuousunit=years", "TVExpose", FALSE, error_msg = e$message)
  cat("✗ FAILED:", e$message, "\n\n")
})

# Test 8: bytype=TRUE
cat("Test 8: bytype=TRUE (separate variable per exposure type)\n")
tryCatch({
  result <- TVExpose(
    cohort = cohort,
    cohort_id = "id",
    cohort_start = "startdate",
    cohort_end = "enddate",
    exposure = exposures,
    exposure_id = "id",
    exposure_start = "expstart",
    exposure_end = "expend",
    exposure_type = "exptype",
    bytype = TRUE
  )
  write_csv(result, file.path(output_dir, "tvexpose_08_bytype.csv"))
  record_test("bytype=TRUE", "TVExpose", TRUE,
              nrow = nrow(result), ncol = ncol(result),
              n_patients = n_distinct(result$id))
  cat("✓ PASSED - Output:", nrow(result), "rows,", ncol(result), "columns\n\n")
}, error = function(e) {
  record_test("bytype=TRUE", "TVExpose", FALSE, error_msg = e$message)
  cat("✗ FAILED:", e$message, "\n\n")
})

# Test 9: grace=30
cat("Test 9: grace=30\n")
tryCatch({
  result <- TVExpose(
    cohort = cohort,
    cohort_id = "id",
    cohort_start = "startdate",
    cohort_end = "enddate",
    exposure = exposures,
    exposure_id = "id",
    exposure_start = "expstart",
    exposure_end = "expend",
    grace = 30
  )
  write_csv(result, file.path(output_dir, "tvexpose_09_grace30.csv"))
  record_test("grace=30", "TVExpose", TRUE,
              nrow = nrow(result), ncol = ncol(result),
              n_patients = n_distinct(result$id))
  cat("✓ PASSED - Output:", nrow(result), "rows,", ncol(result), "columns\n\n")
}, error = function(e) {
  record_test("grace=30", "TVExpose", FALSE, error_msg = e$message)
  cat("✗ FAILED:", e$message, "\n\n")
})

# Test 10: grace=60
cat("Test 10: grace=60\n")
tryCatch({
  result <- TVExpose(
    cohort = cohort,
    cohort_id = "id",
    cohort_start = "startdate",
    cohort_end = "enddate",
    exposure = exposures,
    exposure_id = "id",
    exposure_start = "expstart",
    exposure_end = "expend",
    grace = 60
  )
  write_csv(result, file.path(output_dir, "tvexpose_10_grace60.csv"))
  record_test("grace=60", "TVExpose", TRUE,
              nrow = nrow(result), ncol = ncol(result),
              n_patients = n_distinct(result$id))
  cat("✓ PASSED - Output:", nrow(result), "rows,", ncol(result), "columns\n\n")
}, error = function(e) {
  record_test("grace=60", "TVExpose", FALSE, error_msg = e$message)
  cat("✗ FAILED:", e$message, "\n\n")
})

# Test 11: lag=14
cat("Test 11: lag=14\n")
tryCatch({
  result <- TVExpose(
    cohort = cohort,
    cohort_id = "id",
    cohort_start = "startdate",
    cohort_end = "enddate",
    exposure = exposures,
    exposure_id = "id",
    exposure_start = "expstart",
    exposure_end = "expend",
    lag = 14
  )
  write_csv(result, file.path(output_dir, "tvexpose_11_lag14.csv"))
  record_test("lag=14", "TVExpose", TRUE,
              nrow = nrow(result), ncol = ncol(result),
              n_patients = n_distinct(result$id))
  cat("✓ PASSED - Output:", nrow(result), "rows,", ncol(result), "columns\n\n")
}, error = function(e) {
  record_test("lag=14", "TVExpose", FALSE, error_msg = e$message)
  cat("✗ FAILED:", e$message, "\n\n")
})

# Test 12: washout=30
cat("Test 12: washout=30\n")
tryCatch({
  result <- TVExpose(
    cohort = cohort,
    cohort_id = "id",
    cohort_start = "startdate",
    cohort_end = "enddate",
    exposure = exposures,
    exposure_id = "id",
    exposure_start = "expstart",
    exposure_end = "expend",
    washout = 30
  )
  write_csv(result, file.path(output_dir, "tvexpose_12_washout30.csv"))
  record_test("washout=30", "TVExpose", TRUE,
              nrow = nrow(result), ncol = ncol(result),
              n_patients = n_distinct(result$id))
  cat("✓ PASSED - Output:", nrow(result), "rows,", ncol(result), "columns\n\n")
}, error = function(e) {
  record_test("washout=30", "TVExpose", FALSE, error_msg = e$message)
  cat("✗ FAILED:", e$message, "\n\n")
})

# Test 13: Combined lag=14, washout=30
cat("Test 13: Combined lag=14, washout=30\n")
tryCatch({
  result <- TVExpose(
    cohort = cohort,
    cohort_id = "id",
    cohort_start = "startdate",
    cohort_end = "enddate",
    exposure = exposures,
    exposure_id = "id",
    exposure_start = "expstart",
    exposure_end = "expend",
    lag = 14,
    washout = 30
  )
  write_csv(result, file.path(output_dir, "tvexpose_13_lag_washout.csv"))
  record_test("lag=14, washout=30", "TVExpose", TRUE,
              nrow = nrow(result), ncol = ncol(result),
              n_patients = n_distinct(result$id))
  cat("✓ PASSED - Output:", nrow(result), "rows,", ncol(result), "columns\n\n")
}, error = function(e) {
  record_test("lag=14, washout=30", "TVExpose", FALSE, error_msg = e$message)
  cat("✗ FAILED:", e$message, "\n\n")
})

# Test 14: layer=TRUE for overlap handling
cat("Test 14: layer=TRUE for overlap handling\n")
tryCatch({
  result <- TVExpose(
    cohort = cohort,
    cohort_id = "id",
    cohort_start = "startdate",
    cohort_end = "enddate",
    exposure = exposures,
    exposure_id = "id",
    exposure_start = "expstart",
    exposure_end = "expend",
    layer = TRUE
  )
  write_csv(result, file.path(output_dir, "tvexpose_14_layer.csv"))
  record_test("layer=TRUE", "TVExpose", TRUE,
              nrow = nrow(result), ncol = ncol(result),
              n_patients = n_distinct(result$id))
  cat("✓ PASSED - Output:", nrow(result), "rows,", ncol(result), "columns\n\n")
}, error = function(e) {
  record_test("layer=TRUE", "TVExpose", FALSE, error_msg = e$message)
  cat("✗ FAILED:", e$message, "\n\n")
})

################################################################################
# TVMERGE TESTS
################################################################################

cat("=" , rep("=", 78), "\n", sep="")
cat("TVMERGE TESTS\n")
cat("=" , rep("=", 78), "\n\n", sep="")

# First create exposure dataset using TVExpose for merging
cat("Preparing exposure dataset for TVMerge tests...\n")
tryCatch({
  exposure_data <- TVExpose(
    cohort = cohort,
    cohort_id = "id",
    cohort_start = "startdate",
    cohort_end = "enddate",
    exposure = exposures,
    exposure_id = "id",
    exposure_start = "expstart",
    exposure_end = "expend"
  )
  cat("✓ Exposure dataset prepared\n\n")
}, error = function(e) {
  cat("✗ Failed to prepare exposure dataset:", e$message, "\n\n")
  exposure_data <- NULL
})

# Test 15: Basic two-dataset merge
if (!is.null(exposure_data)) {
  cat("Test 15: Basic two-dataset merge\n")
  tryCatch({
    result <- TVMerge(
      cohort = cohort,
      cohort_id = "id",
      cohort_start = "startdate",
      cohort_end = "enddate",
      exposure = exposure_data,
      exposure_id = "id",
      exposure_start = "startdate",
      exposure_end = "enddate"
    )
    write_csv(result, file.path(output_dir, "tvmerge_15_basic.csv"))
    record_test("Basic two-dataset merge", "TVMerge", TRUE,
                nrow = nrow(result), ncol = ncol(result),
                n_patients = n_distinct(result$id))
    cat("✓ PASSED - Output:", nrow(result), "rows,", ncol(result), "columns\n\n")
  }, error = function(e) {
    record_test("Basic two-dataset merge", "TVMerge", FALSE, error_msg = e$message)
    cat("✗ FAILED:", e$message, "\n\n")
  })
}

# Test 16: Merge with continuous exposure
if (!is.null(exposure_data)) {
  cat("Test 16: Merge with continuous exposure variable\n")
  tryCatch({
    # First create a continuous exposure
    exposure_continuous <- TVExpose(
      cohort = cohort,
      cohort_id = "id",
      cohort_start = "startdate",
      cohort_end = "enddate",
      exposure = exposures,
      exposure_id = "id",
      exposure_start = "expstart",
      exposure_end = "expend",
      continuousunit = "days"
    )

    result <- TVMerge(
      cohort = cohort,
      cohort_id = "id",
      cohort_start = "startdate",
      cohort_end = "enddate",
      exposure = exposure_continuous,
      exposure_id = "id",
      exposure_start = "startdate",
      exposure_end = "enddate",
      continuous = "exposed_days"
    )
    write_csv(result, file.path(output_dir, "tvmerge_16_continuous.csv"))
    record_test("Merge with continuous exposure", "TVMerge", TRUE,
                nrow = nrow(result), ncol = ncol(result),
                n_patients = n_distinct(result$id))
    cat("✓ PASSED - Output:", nrow(result), "rows,", ncol(result), "columns\n\n")
  }, error = function(e) {
    record_test("Merge with continuous exposure", "TVMerge", FALSE, error_msg = e$message)
    cat("✗ FAILED:", e$message, "\n\n")
  })
}

# Test 17: Different output naming with generate parameter
if (!is.null(exposure_data)) {
  cat("Test 17: Different output naming with generate parameter\n")
  tryCatch({
    result <- TVMerge(
      cohort = cohort,
      cohort_id = "id",
      cohort_start = "startdate",
      cohort_end = "enddate",
      exposure = exposure_data,
      exposure_id = "id",
      exposure_start = "startdate",
      exposure_end = "enddate",
      generate = "treatment"
    )
    write_csv(result, file.path(output_dir, "tvmerge_17_generate.csv"))
    record_test("Merge with generate parameter", "TVMerge", TRUE,
                nrow = nrow(result), ncol = ncol(result),
                n_patients = n_distinct(result$id),
                notes = "Variable name: treatment")
    cat("✓ PASSED - Output:", nrow(result), "rows,", ncol(result), "columns\n\n")
  }, error = function(e) {
    record_test("Merge with generate parameter", "TVMerge", FALSE, error_msg = e$message)
    cat("✗ FAILED:", e$message, "\n\n")
  })
}

################################################################################
# TVEVENT TESTS
################################################################################

cat("=" , rep("=", 78), "\n", sep="")
cat("TVEVENT TESTS\n")
cat("=" , rep("=", 78), "\n\n", sep="")

# Load event data
cat("Loading event test data...\n")
tryCatch({
  events <- read_csv("/home/user/Stata-Tools/Reimplementations/Testing/stress_events.csv",
                     show_col_types = FALSE) %>%
    mutate(eventdate = as.Date(eventdate))

  cat("✓ Event data loaded:", nrow(events), "rows,", ncol(events), "columns\n\n")
}, error = function(e) {
  cat("✗ Failed to load event data:", e$message, "\n")
  cat("Creating synthetic event data for testing...\n")
  set.seed(123)
  events <- cohort %>%
    slice_sample(prop = 0.3) %>%
    mutate(
      eventdate = startdate + sample(0:365, n(), replace = TRUE),
      eventtype = sample(c("outcome", "compete1", "compete2"), n(), replace = TRUE)
    ) %>%
    filter(eventdate <= enddate) %>%
    select(id, eventdate, eventtype)

  write_csv(events, "/home/user/Stata-Tools/Reimplementations/Testing/stress_events.csv")
  cat("✓ Synthetic event data created\n\n")
})

# Test 18: type="single" (primary event only)
cat("Test 18: type=\"single\" (primary event only)\n")
tryCatch({
  result <- TVEvent(
    cohort = cohort,
    cohort_id = "id",
    cohort_start = "startdate",
    cohort_end = "enddate",
    event = events %>% filter(eventtype == "outcome"),
    event_id = "id",
    event_date = "eventdate",
    type = "single"
  )
  write_csv(result, file.path(output_dir, "tvevent_18_single.csv"))
  record_test("type=single", "TVEvent", TRUE,
              nrow = nrow(result), ncol = ncol(result),
              n_patients = n_distinct(result$id))
  cat("✓ PASSED - Output:", nrow(result), "rows,", ncol(result), "columns\n\n")
}, error = function(e) {
  record_test("type=single", "TVEvent", FALSE, error_msg = e$message)
  cat("✗ FAILED:", e$message, "\n\n")
})

# Test 19: type="recurring"
cat("Test 19: type=\"recurring\"\n")
tryCatch({
  result <- TVEvent(
    cohort = cohort,
    cohort_id = "id",
    cohort_start = "startdate",
    cohort_end = "enddate",
    event = events %>% filter(eventtype == "outcome"),
    event_id = "id",
    event_date = "eventdate",
    type = "recurring"
  )
  write_csv(result, file.path(output_dir, "tvevent_19_recurring.csv"))
  record_test("type=recurring", "TVEvent", TRUE,
              nrow = nrow(result), ncol = ncol(result),
              n_patients = n_distinct(result$id))
  cat("✓ PASSED - Output:", nrow(result), "rows,", ncol(result), "columns\n\n")
}, error = function(e) {
  record_test("type=recurring", "TVEvent", FALSE, error_msg = e$message)
  cat("✗ FAILED:", e$message, "\n\n")
})

# Test 20: Single competing risk
cat("Test 20: Single competing risk (compete parameter)\n")
tryCatch({
  compete_events <- events %>% filter(eventtype == "compete1")

  result <- TVEvent(
    cohort = cohort,
    cohort_id = "id",
    cohort_start = "startdate",
    cohort_end = "enddate",
    event = events %>% filter(eventtype == "outcome"),
    event_id = "id",
    event_date = "eventdate",
    type = "single",
    compete = compete_events,
    compete_id = "id",
    compete_date = "eventdate"
  )
  write_csv(result, file.path(output_dir, "tvevent_20_compete_single.csv"))
  record_test("Single competing risk", "TVEvent", TRUE,
              nrow = nrow(result), ncol = ncol(result),
              n_patients = n_distinct(result$id))
  cat("✓ PASSED - Output:", nrow(result), "rows,", ncol(result), "columns\n\n")
}, error = function(e) {
  record_test("Single competing risk", "TVEvent", FALSE, error_msg = e$message)
  cat("✗ FAILED:", e$message, "\n\n")
})

# Test 21: Multiple competing risks
cat("Test 21: Multiple competing risks\n")
tryCatch({
  # Create list of competing risk datasets
  compete_list <- list(
    events %>% filter(eventtype == "compete1"),
    events %>% filter(eventtype == "compete2")
  )

  result <- TVEvent(
    cohort = cohort,
    cohort_id = "id",
    cohort_start = "startdate",
    cohort_end = "enddate",
    event = events %>% filter(eventtype == "outcome"),
    event_id = "id",
    event_date = "eventdate",
    type = "single",
    compete = compete_list,
    compete_id = "id",
    compete_date = "eventdate"
  )
  write_csv(result, file.path(output_dir, "tvevent_21_compete_multiple.csv"))
  record_test("Multiple competing risks", "TVEvent", TRUE,
              nrow = nrow(result), ncol = ncol(result),
              n_patients = n_distinct(result$id))
  cat("✓ PASSED - Output:", nrow(result), "rows,", ncol(result), "columns\n\n")
}, error = function(e) {
  record_test("Multiple competing risks", "TVEvent", FALSE, error_msg = e$message)
  cat("✗ FAILED:", e$message, "\n\n")
})

# Test 22: With continuous variable adjustment
cat("Test 22: With continuous variable adjustment\n")
tryCatch({
  # First create continuous exposure variable
  cohort_with_exposure <- TVExpose(
    cohort = cohort,
    cohort_id = "id",
    cohort_start = "startdate",
    cohort_end = "enddate",
    exposure = exposures,
    exposure_id = "id",
    exposure_start = "expstart",
    exposure_end = "expend",
    continuousunit = "days"
  )

  result <- TVEvent(
    cohort = cohort_with_exposure,
    cohort_id = "id",
    cohort_start = "startdate",
    cohort_end = "enddate",
    event = events %>% filter(eventtype == "outcome"),
    event_id = "id",
    event_date = "eventdate",
    type = "single",
    continuous = "exposed_days"
  )
  write_csv(result, file.path(output_dir, "tvevent_22_continuous.csv"))
  record_test("With continuous variable", "TVEvent", TRUE,
              nrow = nrow(result), ncol = ncol(result),
              n_patients = n_distinct(result$id))
  cat("✓ PASSED - Output:", nrow(result), "rows,", ncol(result), "columns\n\n")
}, error = function(e) {
  record_test("With continuous variable", "TVEvent", FALSE, error_msg = e$message)
  cat("✗ FAILED:", e$message, "\n\n")
})

# Test 23: With timegen and timeunit="days"
cat("Test 23: With timegen and timeunit=\"days\"\n")
tryCatch({
  result <- TVEvent(
    cohort = cohort,
    cohort_id = "id",
    cohort_start = "startdate",
    cohort_end = "enddate",
    event = events %>% filter(eventtype == "outcome"),
    event_id = "id",
    event_date = "eventdate",
    type = "single",
    timegen = "followup_days",
    timeunit = "days"
  )
  write_csv(result, file.path(output_dir, "tvevent_23_timegen_days.csv"))
  record_test("timegen with timeunit=days", "TVEvent", TRUE,
              nrow = nrow(result), ncol = ncol(result),
              n_patients = n_distinct(result$id),
              notes = "Time variable: followup_days")
  cat("✓ PASSED - Output:", nrow(result), "rows,", ncol(result), "columns\n\n")
}, error = function(e) {
  record_test("timegen with timeunit=days", "TVEvent", FALSE, error_msg = e$message)
  cat("✗ FAILED:", e$message, "\n\n")
})

# Test 24: With timegen and timeunit="years"
cat("Test 24: With timegen and timeunit=\"years\"\n")
tryCatch({
  result <- TVEvent(
    cohort = cohort,
    cohort_id = "id",
    cohort_start = "startdate",
    cohort_end = "enddate",
    event = events %>% filter(eventtype == "outcome"),
    event_id = "id",
    event_date = "eventdate",
    type = "single",
    timegen = "followup_years",
    timeunit = "years"
  )
  write_csv(result, file.path(output_dir, "tvevent_24_timegen_years.csv"))
  record_test("timegen with timeunit=years", "TVEvent", TRUE,
              nrow = nrow(result), ncol = ncol(result),
              n_patients = n_distinct(result$id),
              notes = "Time variable: followup_years")
  cat("✓ PASSED - Output:", nrow(result), "rows,", ncol(result), "columns\n\n")
}, error = function(e) {
  record_test("timegen with timeunit=years", "TVEvent", FALSE, error_msg = e$message)
  cat("✗ FAILED:", e$message, "\n\n")
})

################################################################################
# GENERATE SUMMARY REPORT
################################################################################

cat("\n")
cat("=" , rep("=", 78), "\n", sep="")
cat("TEST SUMMARY REPORT\n")
cat("=" , rep("=", 78), "\n\n", sep="")

# Convert results to data frame
results_df <- bind_rows(test_results)

# Summary statistics
total_tests <- nrow(results_df)
passed_tests <- sum(results_df$success)
failed_tests <- total_tests - passed_tests
success_rate <- round(100 * passed_tests / total_tests, 1)

cat("Total tests run:", total_tests, "\n")
cat("Tests passed:   ", passed_tests, "(", success_rate, "%)\n")
cat("Tests failed:   ", failed_tests, "\n\n")

# Summary by category
cat("Results by category:\n")
category_summary <- results_df %>%
  group_by(category) %>%
  summarize(
    total = n(),
    passed = sum(success),
    failed = sum(!success),
    .groups = "drop"
  )
print(category_summary, n = Inf)

cat("\n")

# Failed tests details
if (failed_tests > 0) {
  cat("FAILED TESTS DETAILS:\n")
  cat(rep("-", 80), "\n", sep="")
  failed <- results_df %>% filter(!success)
  for (i in 1:nrow(failed)) {
    cat("\nTest", failed$test_num[i], ":", failed$test_name[i], "\n")
    cat("Category:", failed$category[i], "\n")
    cat("Error:", failed$error_msg[i], "\n")
  }
  cat("\n")
}

# Successful tests with output info
cat("SUCCESSFUL TESTS:\n")
cat(rep("-", 80), "\n", sep="")
successful <- results_df %>% filter(success)
for (i in 1:nrow(successful)) {
  cat(sprintf("Test %2d: %-40s [%s]\n",
              successful$test_num[i],
              successful$test_name[i],
              successful$category[i]))
  cat(sprintf("         Output: %d rows, %d cols, %d patients\n",
              successful$nrow[i],
              successful$ncol[i],
              successful$n_patients[i]))
  if (successful$notes[i] != "") {
    cat(sprintf("         Notes: %s\n", successful$notes[i]))
  }
}

# Save detailed results
results_file <- file.path(output_dir, "test_results_summary.csv")
write_csv(results_df, results_file)
cat("\n")
cat("Detailed results saved to:", results_file, "\n")

# Final status
cat("\n")
cat("=" , rep("=", 78), "\n", sep="")
if (failed_tests == 0) {
  cat("ALL TESTS PASSED!\n")
} else {
  cat("SOME TESTS FAILED - REVIEW ERRORS ABOVE\n")
}
cat("=" , rep("=", 78), "\n", sep="")

# Exit with appropriate status code
if (failed_tests > 0) {
  quit(status = 1)
} else {
  quit(status = 0)
}
