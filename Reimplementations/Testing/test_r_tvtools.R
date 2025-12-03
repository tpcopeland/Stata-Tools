#!/usr/bin/env Rscript
# ==============================================================================
# Comprehensive R tvtools Testing Script
# ==============================================================================
# Purpose: Systematically test tvexpose, tvmerge, and tvevent functions
# Date: 2025-12-03
# ==============================================================================

cat("\n")
cat(strrep("=", 80), "\n")
cat("R tvtools Comprehensive Testing Suite\n")
cat(strrep("=", 80), "\n\n")

# ==============================================================================
# Setup
# ==============================================================================

# Set working directory
setwd("/home/user/Stata-Tools/Reimplementations/Testing")

# Create output directory
output_dir <- "/home/user/Stata-Tools/Reimplementations/Testing/R_test_outputs"
dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)

# Initialize bug tracker
bugs_found <- list()
test_number <- 0

# Helper function to record bugs
record_bug <- function(test_name, function_name, description, error_msg = NULL) {
  bug_id <- length(bugs_found) + 1
  bugs_found[[bug_id]] <<- list(
    bug_id = bug_id,
    test = test_name,
    function_name = function_name,
    description = description,
    error = error_msg,
    timestamp = Sys.time()
  )
  cat(sprintf("\n*** BUG #%d FOUND ***\n", bug_id))
  cat(sprintf("Function: %s\n", function_name))
  cat(sprintf("Test: %s\n", test_name))
  cat(sprintf("Description: %s\n", description))
  if (!is.null(error_msg)) {
    cat(sprintf("Error: %s\n", error_msg))
  }
  cat("***********************\n\n")
}

# Helper function to save test output
save_test_output <- function(data, filename) {
  filepath <- file.path(output_dir, filename)
  if (is.data.frame(data)) {
    write.csv(data, filepath, row.names = FALSE)
    cat(sprintf("  Saved output to: %s\n", filepath))
  } else if (is.list(data)) {
    saveRDS(data, filepath)
    cat(sprintf("  Saved output (RDS) to: %s\n", filepath))
  }
}

# ==============================================================================
# Load tvtools Package
# ==============================================================================

cat("\n")
cat(strrep("-", 80), "\n")
cat("STEP 1: Loading tvtools Package\n")
cat(strrep("-", 80), "\n")

tryCatch({
  # Install tvtools package
  cat("Installing tvtools from /home/user/Stata-Tools/Reimplementations/R/tvtools...\n")
  install.packages("/home/user/Stata-Tools/Reimplementations/R/tvtools",
                   repos = NULL, type = "source", quiet = FALSE)

  # Load the package
  library(tvtools)
  cat("SUCCESS: tvtools package loaded\n")

}, error = function(e) {
  cat(sprintf("ERROR loading tvtools: %s\n", e$message))
  record_bug("Package Loading", "tvtools", "Failed to install/load tvtools package", e$message)
  quit(status = 1)
})

# ==============================================================================
# Load Test Data
# ==============================================================================

cat("\n")
cat(strrep("-", 80), "\n")
cat("STEP 2: Loading Test Data\n")
cat(strrep("-", 80), "\n")

tryCatch({
  cohort <- read.csv("cohort.csv", stringsAsFactors = FALSE)
  cohort$study_entry <- as.Date(cohort$study_entry)
  cohort$study_exit <- as.Date(cohort$study_exit)

  exposures <- read.csv("exposures.csv", stringsAsFactors = FALSE)
  exposures$rx_start <- as.Date(exposures$rx_start)
  exposures$rx_stop <- as.Date(exposures$rx_stop)

  exposures2 <- read.csv("exposures2.csv", stringsAsFactors = FALSE)
  exposures2$treatment_start <- as.Date(exposures2$treatment_start)
  exposures2$treatment_stop <- as.Date(exposures2$treatment_stop)

  events <- read.csv("events.csv", stringsAsFactors = FALSE)
  # Convert date columns - events.csv has mi_date, death_date, emigration_date
  if ("mi_date" %in% names(events)) {
    events$mi_date <- as.Date(events$mi_date)
  }
  if ("death_date" %in% names(events)) {
    # Some values are numeric (days since epoch), need special handling
    events$death_date <- suppressWarnings(as.Date(as.numeric(events$death_date), origin = "1970-01-01"))
  }
  if ("emigration_date" %in% names(events)) {
    events$emigration_date <- as.Date(events$emigration_date)
  }

  # Rename patient_id to id to match tvexpose output
  names(events)[names(events) == "patient_id"] <- "id"

  cat(sprintf("  Loaded cohort: %d rows, %d columns\n", nrow(cohort), ncol(cohort)))
  cat(sprintf("  Loaded exposures: %d rows, %d columns\n", nrow(exposures), ncol(exposures)))
  cat(sprintf("  Loaded exposures2: %d rows, %d columns\n", nrow(exposures2), ncol(exposures2)))
  cat(sprintf("  Loaded events: %d rows, %d columns\n", nrow(events), ncol(events)))
  cat("SUCCESS: Test data loaded\n")

}, error = function(e) {
  cat(sprintf("ERROR loading test data: %s\n", e$message))
  record_bug("Data Loading", "read.csv", "Failed to load test data", e$message)
  quit(status = 1)
})

# ==============================================================================
# TVEXPOSE TESTS
# ==============================================================================

cat("\n\n")
cat(strrep("=", 80), "\n")
cat("TESTING: tvexpose Function\n")
cat(strrep("=", 80), "\n\n")

## Test 1: Basic evertreated
test_number <- test_number + 1
cat(sprintf("\nTest %d: tvexpose - Basic evertreated\n", test_number))
cat(strrep("-", 60), "\n")

tryCatch({
  result_ever <- tvexpose(
    master_data = cohort,
    exposure_file = exposures,
    id = "patient_id",
    start = "rx_start",
    stop = "rx_stop",
    exposure = "drug_type",
    reference = 0,
    entry = "study_entry",
    exit = "study_exit",
    evertreated = TRUE,
    generate = "ever_exposed",
    verbose = TRUE
  )

  cat(sprintf("  Result: %d observations, %d persons\n",
              result_ever$metadata$N_periods,
              result_ever$metadata$N_persons))
  cat("  SUCCESS: evertreated test passed\n")

  save_test_output(result_ever$data, "tvexpose_evertreated.csv")
  save_test_output(result_ever, "tvexpose_evertreated_full.rds")

}, error = function(e) {
  cat(sprintf("  FAILED: %s\n", e$message))
  record_bug("Test 1: evertreated", "tvexpose", "Basic evertreated test failed", e$message)
})

## Test 2: Current/Former
test_number <- test_number + 1
cat(sprintf("\nTest %d: tvexpose - Current/Former with grace period\n", test_number))
cat(strrep("-", 60), "\n")

tryCatch({
  result_cf <- tvexpose(
    master_data = cohort,
    exposure_file = exposures,
    id = "patient_id",
    start = "rx_start",
    stop = "rx_stop",
    exposure = "drug_type",
    reference = 0,
    entry = "study_entry",
    exit = "study_exit",
    currentformer = TRUE,
    grace = 30,
    generate = "exposure_status",
    verbose = TRUE
  )

  cat(sprintf("  Result: %d observations, %d persons\n",
              result_cf$metadata$N_periods,
              result_cf$metadata$N_persons))
  cat("  SUCCESS: current/former test passed\n")

  save_test_output(result_cf$data, "tvexpose_currentformer.csv")

}, error = function(e) {
  cat(sprintf("  FAILED: %s\n", e$message))
  record_bug("Test 2: current/former", "tvexpose", "Current/former test failed", e$message)
})

## Test 3: Continuous exposure (cumulative days)
test_number <- test_number + 1
cat(sprintf("\nTest %d: tvexpose - Continuous cumulative exposure\n", test_number))
cat(strrep("-", 60), "\n")

tryCatch({
  result_cont <- tvexpose(
    master_data = cohort,
    exposure_file = exposures,
    id = "patient_id",
    start = "rx_start",
    stop = "rx_stop",
    exposure = "drug_type",
    reference = 0,
    entry = "study_entry",
    exit = "study_exit",
    continuousunit = "days",
    generate = "cumulative_days",
    verbose = TRUE
  )

  cat(sprintf("  Result: %d observations, %d persons\n",
              result_cont$metadata$N_periods,
              result_cont$metadata$N_persons))
  cat("  SUCCESS: continuous exposure test passed\n")

  save_test_output(result_cont$data, "tvexpose_continuous.csv")

}, error = function(e) {
  cat(sprintf("  FAILED: %s\n", e$message))
  record_bug("Test 3: continuous", "tvexpose", "Continuous exposure test failed", e$message)
})

## Test 4: Duration categories
test_number <- test_number + 1
cat(sprintf("\nTest %d: tvexpose - Duration categories\n", test_number))
cat(strrep("-", 60), "\n")

tryCatch({
  result_dur <- tvexpose(
    master_data = cohort,
    exposure_file = exposures,
    id = "patient_id",
    start = "rx_start",
    stop = "rx_stop",
    exposure = "drug_type",
    reference = 0,
    entry = "study_entry",
    exit = "study_exit",
    duration = c(30, 90, 180, 365),
    continuousunit = "days",
    generate = "duration_cat",
    verbose = TRUE
  )

  cat(sprintf("  Result: %d observations, %d persons\n",
              result_dur$metadata$N_periods,
              result_dur$metadata$N_persons))
  cat("  SUCCESS: duration categories test passed\n")

  save_test_output(result_dur$data, "tvexpose_duration.csv")

}, error = function(e) {
  cat(sprintf("  FAILED: %s\n", e$message))
  record_bug("Test 4: duration", "tvexpose", "Duration categories test failed", e$message)
})

## Test 5: By-type analysis
test_number <- test_number + 1
cat(sprintf("\nTest %d: tvexpose - By-type evertreated\n", test_number))
cat(strrep("-", 60), "\n")

tryCatch({
  result_bytype <- tvexpose(
    master_data = cohort,
    exposure_file = exposures,
    id = "patient_id",
    start = "rx_start",
    stop = "rx_stop",
    exposure = "drug_type",
    reference = 0,
    entry = "study_entry",
    exit = "study_exit",
    evertreated = TRUE,
    bytype = TRUE,
    generate = "ever_drug",
    verbose = TRUE
  )

  cat(sprintf("  Result: %d observations, %d persons\n",
              result_bytype$metadata$N_periods,
              result_bytype$metadata$N_persons))
  cat("  SUCCESS: by-type test passed\n")

  save_test_output(result_bytype$data, "tvexpose_bytype.csv")

}, error = function(e) {
  cat(sprintf("  FAILED: %s\n", e$message))
  record_bug("Test 5: bytype", "tvexpose", "By-type evertreated test failed", e$message)
})

## Test 6: Edge cases
test_number <- test_number + 1
cat(sprintf("\nTest %d: tvexpose - Edge cases (overlapping exposures)\n", test_number))
cat(strrep("-", 60), "\n")

tryCatch({
  result_edge <- tvexpose(
    master_data = cohort,
    exposure_file = exposures,
    id = "patient_id",
    start = "rx_start",
    stop = "rx_stop",
    exposure = "drug_type",
    reference = 0,
    entry = "study_entry",
    exit = "study_exit",
    evertreated = TRUE,
    layer = TRUE,  # Layer strategy for overlaps
    check = TRUE,
    gaps = TRUE,
    overlaps = TRUE,
    generate = "ever_exposed_layered",
    verbose = TRUE
  )

  cat("  SUCCESS: edge cases test passed\n")
  save_test_output(result_edge$data, "tvexpose_edge.csv")

}, error = function(e) {
  cat(sprintf("  FAILED: %s\n", e$message))
  record_bug("Test 6: edge cases", "tvexpose", "Edge cases test failed", e$message)
})

# ==============================================================================
# TVMERGE TESTS
# ==============================================================================

cat("\n\n")
cat(strrep("=", 80), "\n")
cat("TESTING: tvmerge Function\n")
cat(strrep("=", 80), "\n\n")

## First, create simple time-varying datasets for merging
cat("Preparing time-varying datasets for tvmerge...\n")

tryCatch({
  # Create TV dataset 1 from exposures
  tv1_result <- tvexpose(
    master_data = cohort,
    exposure_file = exposures,
    id = "patient_id",
    start = "rx_start",
    stop = "rx_stop",
    exposure = "drug_type",
    reference = 0,
    entry = "study_entry",
    exit = "study_exit",
    generate = "drug",
    verbose = FALSE
  )

  tv1 <- tv1_result$data
  # Save as CSV for tvmerge to read
  write.csv(tv1, "tv1.csv", row.names = FALSE)

  # Create TV dataset 2 from exposures2
  tv2_result <- tvexpose(
    master_data = cohort,
    exposure_file = exposures2,
    id = "patient_id",
    start = "treatment_start",
    stop = "treatment_stop",
    exposure = "treatment_type",
    reference = 0,
    entry = "study_entry",
    exit = "study_exit",
    generate = "treatment",
    verbose = FALSE
  )

  tv2 <- tv2_result$data
  write.csv(tv2, "tv2.csv", row.names = FALSE)

  cat("  Prepared tv1.csv and tv2.csv for merging\n")

}, error = function(e) {
  cat(sprintf("ERROR preparing TV datasets: %s\n", e$message))
  record_bug("TV dataset prep", "tvexpose", "Failed to prepare datasets for tvmerge", e$message)
})

## Test 7: Basic tvmerge
test_number <- test_number + 1
cat(sprintf("\nTest %d: tvmerge - Basic two-dataset merge\n", test_number))
cat(strrep("-", 60), "\n")

tryCatch({
  result_merge <- tvmerge(
    datasets = list(tv1, tv2),
    id = "id",
    start = c("start", "start"),
    stop = c("stop", "stop"),
    exposure = c("drug", "treatment"),
    generate = c("drug_final", "treatment_final"),
    startname = "period_start",
    stopname = "period_stop",
    check = TRUE,
    summarize = TRUE
  )

  cat(sprintf("  Result: %d observations, %d persons\n",
              result_merge$returns$N,
              result_merge$returns$N_persons))
  cat("  SUCCESS: basic tvmerge test passed\n")

  save_test_output(result_merge$data, "tvmerge_basic.csv")
  save_test_output(result_merge, "tvmerge_basic_full.rds")

}, error = function(e) {
  cat(sprintf("  FAILED: %s\n", e$message))
  record_bug("Test 7: basic merge", "tvmerge", "Basic tvmerge test failed", e$message)
})

## Test 8: tvmerge with continuous variables
test_number <- test_number + 1
cat(sprintf("\nTest %d: tvmerge - With continuous exposure\n", test_number))
cat(strrep("-", 60), "\n")

tryCatch({
  # First create a continuous exposure dataset
  tv_dose_result <- tvexpose(
    master_data = cohort,
    exposure_file = exposures,
    id = "patient_id",
    start = "rx_start",
    stop = "rx_stop",
    exposure = "drug_type",
    reference = 0,
    entry = "study_entry",
    exit = "study_exit",
    continuousunit = "days",
    generate = "cumul_dose",
    verbose = FALSE
  )

  tv_dose <- tv_dose_result$data

  result_merge_cont <- tvmerge(
    datasets = list(tv1, tv_dose),
    id = "id",
    start = c("start", "start"),
    stop = c("stop", "stop"),
    exposure = c("drug", "tv_exp"),
    continuous = c(2),  # Second exposure is continuous
    generate = c("drug_type", "dose"),
    startname = "start_merged",
    stopname = "stop_merged"
  )

  cat(sprintf("  Result: %d observations\n", nrow(result_merge_cont$data)))
  cat("  SUCCESS: continuous tvmerge test passed\n")

  save_test_output(result_merge_cont$data, "tvmerge_continuous.csv")

}, error = function(e) {
  cat(sprintf("  FAILED: %s\n", e$message))
  record_bug("Test 8: continuous merge", "tvmerge", "Continuous tvmerge test failed", e$message)
})

## Test 9: tvmerge validation checks
test_number <- test_number + 1
cat(sprintf("\nTest %d: tvmerge - Validation checks\n", test_number))
cat(strrep("-", 60), "\n")

tryCatch({
  result_merge_val <- tvmerge(
    datasets = list(tv1, tv2),
    id = "id",
    start = c("start", "start"),
    stop = c("stop", "stop"),
    exposure = c("drug", "treatment"),
    generate = c("drug_validated", "treatment_validated"),
    startname = "start_val",
    stopname = "stop_val",
    validatecoverage = TRUE,
    validateoverlap = TRUE,
    summarize = TRUE
  )

  cat("  SUCCESS: validation checks test passed\n")
  save_test_output(result_merge_val$data, "tvmerge_validated.csv")

}, error = function(e) {
  cat(sprintf("  FAILED: %s\n", e$message))
  record_bug("Test 9: validation", "tvmerge", "Validation checks test failed", e$message)
})

# ==============================================================================
# TVEVENT TESTS
# ==============================================================================

cat("\n\n")
cat(strrep("=", 80), "\n")
cat("TESTING: tvevent Function\n")
cat(strrep("=", 80), "\n\n")

## Test 10: Basic single event
test_number <- test_number + 1
cat(sprintf("\nTest %d: tvevent - Basic single event\n", test_number))
cat(strrep("-", 60), "\n")

tryCatch({
  result_event <- tvevent(
    intervals_data = tv1,
    events_data = events,
    id = "id",
    date = "mi_date",
    generate = "event_status",
    type = "single"
  )

  cat(sprintf("  Result: %d observations, %d events\n",
              result_event$N,
              result_event$N_events))
  cat("  SUCCESS: basic tvevent test passed\n")

  save_test_output(result_event$data, "tvevent_single.csv")

}, error = function(e) {
  cat(sprintf("  FAILED: %s\n", e$message))
  record_bug("Test 10: single event", "tvevent", "Basic single event test failed", e$message)
})

## Test 11: Recurring events
test_number <- test_number + 1
cat(sprintf("\nTest %d: tvevent - Recurring events\n", test_number))
cat(strrep("-", 60), "\n")

tryCatch({
  result_recur <- tvevent(
    intervals_data = tv1,
    events_data = events,
    id = "id",
    date = "mi_date",
    generate = "recurrent_event",
    type = "recurring"
  )

  cat(sprintf("  Result: %d observations, %d events\n",
              result_recur$N,
              result_recur$N_events))
  cat("  SUCCESS: recurring event test passed\n")

  save_test_output(result_recur$data, "tvevent_recurring.csv")

}, error = function(e) {
  cat(sprintf("  FAILED: %s\n", e$message))
  record_bug("Test 11: recurring", "tvevent", "Recurring events test failed", e$message)
})

## Test 12: Competing risks
test_number <- test_number + 1
cat(sprintf("\nTest %d: tvevent - Competing risks\n", test_number))
cat(strrep("-", 60), "\n")

tryCatch({
  # Check if death_date exists
  if ("death_date" %in% names(events)) {
    result_compete <- tvevent(
      intervals_data = tv1,
      events_data = events,
      id = "id",
      date = "mi_date",
      compete = c("death_date"),
      generate = "outcome",
      type = "single",
      timegen = "followup_time",
      timeunit = "years"
    )

    cat(sprintf("  Result: %d observations, %d events\n",
                result_compete$N,
                result_compete$N_events))
    cat("  SUCCESS: competing risks test passed\n")

    save_test_output(result_compete$data, "tvevent_competing.csv")
  } else {
    cat("  SKIPPED: No death_date in events dataset\n")
  }

}, error = function(e) {
  cat(sprintf("  FAILED: %s\n", e$message))
  record_bug("Test 12: competing risks", "tvevent", "Competing risks test failed", e$message)
})

## Test 13: Continuous variable adjustment
test_number <- test_number + 1
cat(sprintf("\nTest %d: tvevent - Continuous variable adjustment\n", test_number))
cat(strrep("-", 60), "\n")

tryCatch({
  # Use the continuous dose dataset
  result_event_cont <- tvevent(
    intervals_data = tv_dose,
    events_data = events,
    id = "id",
    date = "mi_date",
    generate = "event",
    type = "single",
    continuous = c("tv_exp"),
    timegen = "time_days",
    timeunit = "days"
  )

  cat(sprintf("  Result: %d observations\n", result_event_cont$N))
  cat("  SUCCESS: continuous adjustment test passed\n")

  save_test_output(result_event_cont$data, "tvevent_continuous.csv")

}, error = function(e) {
  cat(sprintf("  FAILED: %s\n", e$message))
  record_bug("Test 13: continuous adj", "tvevent", "Continuous adjustment test failed", e$message)
})

# ==============================================================================
# Integration Tests - Full Workflow
# ==============================================================================

cat("\n\n")
cat(strrep("=", 80), "\n")
cat("INTEGRATION TESTS: Full tvtools Workflow\n")
cat(strrep("=", 80), "\n\n")

## Test 14: Complete workflow (tvexpose -> tvmerge -> tvevent)
test_number <- test_number + 1
cat(sprintf("\nTest %d: Complete workflow integration\n", test_number))
cat(strrep("-", 60), "\n")

tryCatch({
  # Step 1: Create time-varying exposure
  cat("  Step 1: tvexpose...\n")
  wf_expose <- tvexpose(
    master_data = cohort,
    exposure_file = exposures,
    id = "patient_id",
    start = "rx_start",
    stop = "rx_stop",
    exposure = "drug_type",
    reference = 0,
    entry = "study_entry",
    exit = "study_exit",
    duration = c(0, 90, 180),
    generate = "drug_status",
    verbose = FALSE
  )

  # Step 2: Create second exposure dataset
  cat("  Step 2: Second tvexpose...\n")
  wf_treat <- tvexpose(
    master_data = cohort,
    exposure_file = exposures2,
    id = "patient_id",
    start = "treatment_start",
    stop = "treatment_stop",
    exposure = "treatment_type",
    reference = 0,
    entry = "study_entry",
    exit = "study_exit",
    continuousunit = "days",
    generate = "treatment_status",
    verbose = FALSE
  )

  # Step 3: Merge datasets
  cat("  Step 3: tvmerge...\n")
  wf_merged <- tvmerge(
    datasets = list(wf_expose$data, wf_treat$data),
    id = "id",
    start = c("start", "start"),
    stop = c("stop", "stop"),
    exposure = c("tv_exp", "tv_exp"),
    continuous = c(2),  # Second dataset is continuous
    generate = c("drug", "treatment"),
    startname = "start",
    stopname = "stop"
  )

  # Step 4: Add events
  cat("  Step 4: tvevent...\n")
  wf_final <- tvevent(
    intervals_data = wf_merged$data,
    events_data = events,
    id = "id",
    date = "mi_date",
    generate = "outcome",
    type = "single",
    timegen = "time_years",
    timeunit = "years"
  )

  cat(sprintf("  Final dataset: %d observations, %d events\n",
              wf_final$N, wf_final$N_events))
  cat("  SUCCESS: Complete workflow test passed\n")

  save_test_output(wf_final$data, "workflow_complete.csv")

}, error = function(e) {
  cat(sprintf("  FAILED: %s\n", e$message))
  record_bug("Test 14: workflow", "integration", "Complete workflow test failed", e$message)
})

# ==============================================================================
# Final Summary and Bug Report
# ==============================================================================

cat("\n\n")
cat(strrep("=", 80), "\n")
cat("TEST SUMMARY\n")
cat(strrep("=", 80), "\n\n")

cat(sprintf("Total tests run: %d\n", test_number))
cat(sprintf("Bugs found: %d\n", length(bugs_found)))

if (length(bugs_found) > 0) {
  cat("\n")
  cat(strrep("-", 80), "\n")
  cat("BUG REPORT\n")
  cat(strrep("-", 80), "\n\n")

  for (bug in bugs_found) {
    cat(sprintf("Bug #%d\n", bug$bug_id))
    cat(sprintf("  Function: %s\n", bug$function_name))
    cat(sprintf("  Test: %s\n", bug$test))
    cat(sprintf("  Description: %s\n", bug$description))
    if (!is.null(bug$error)) {
      cat(sprintf("  Error: %s\n", bug$error))
    }
    cat("\n")
  }

  # Save bug report
  bug_report_file <- file.path(output_dir, "bug_report.txt")
  sink(bug_report_file)
  cat("R tvtools Bug Report\n")
  cat(sprintf("Generated: %s\n\n", Sys.time()))
  for (bug in bugs_found) {
    cat(sprintf("Bug #%d\n", bug$bug_id))
    cat(sprintf("  Function: %s\n", bug$function_name))
    cat(sprintf("  Test: %s\n", bug$test))
    cat(sprintf("  Description: %s\n", bug$description))
    if (!is.null(bug$error)) {
      cat(sprintf("  Error: %s\n", bug$error))
    }
    cat("\n")
  }
  sink()
  cat(sprintf("\nBug report saved to: %s\n", bug_report_file))
}

cat("\n")
cat(strrep("=", 80), "\n")
cat("TESTING COMPLETE\n")
cat(strrep("=", 80), "\n")
cat(sprintf("\nAll test outputs saved to: %s\n", output_dir))
cat("\n")

# Return exit status
if (length(bugs_found) > 0) {
  quit(status = 1)
} else {
  quit(status = 0)
}
