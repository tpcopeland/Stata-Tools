# Comprehensive tests for tvevent R implementation
# Based on Stata test suite from _testing/test_tvevent.do

library(testthat)
library(tvtools)
suppressMessages(library(dplyr))

# Test data path - use RDS files
data_path <- "/home/tpcopeland/Stata-Tools/_reimplementations/data/R"

# Helper function to load test data
load_test_data <- function() {
  cohort <- readRDS(file.path(data_path, "cohort.rds"))
  hrt <- readRDS(file.path(data_path, "hrt.rds"))
  list(cohort = cohort, hrt = hrt)
}

# Helper to create interval data for testing
create_intervals <- function(data) {
  result <- tvexpose(
    master_data = data$cohort,
    exposure_file = data$hrt,
    id = "id",
    start = "rx_start",
    stop = "rx_stop",
    exposure = "hrt_type",
    entry = "study_entry",
    exit = "study_exit",
    reference = 0,
    generate = "hrt_exp",
    verbose = FALSE
  )
  result$data
}

# Helper to create event data
create_events <- function(data) {
  events <- data$cohort[, c("id", "edss4_dt", "death_dt", "emigration_dt")]
  names(events)[2] <- "event_date"
  events
}

# ============================================================================
# TEST 1: Basic Single Event
# ============================================================================
test_that("tvevent creates basic single event flags", {
  data <- load_test_data()
  intervals <- create_intervals(data)
  events <- create_events(data)

  result <- tvevent(
    intervals_data = intervals,
    events_data = events,
    id = "id",
    date = "event_date",
    generate = "outcome",
    type = "single"
  )

  expect_true(is.list(result))
  expect_true("data" %in% names(result))
  expect_true(nrow(result$data) > 0)
  expect_true("outcome" %in% names(result$data))
  expect_true(result$N_events >= 0)
})

# ============================================================================
# TEST 2: Competing Risks
# ============================================================================
test_that("tvevent handles competing risks", {
  data <- load_test_data()
  intervals <- create_intervals(data)
  events <- create_events(data)

  result <- tvevent(
    intervals_data = intervals,
    events_data = events,
    id = "id",
    date = "event_date",
    compete = c("death_dt", "emigration_dt"),
    generate = "outcome",
    type = "single"
  )

  expect_true(is.list(result))
  # Should have multiple event types
  outcome_vals <- unique(result$data$outcome)
  expect_true(length(outcome_vals) > 1)
})

# ============================================================================
# TEST 3: Time Generation - Days
# ============================================================================
test_that("tvevent timegen option creates time variable in days", {
  data <- load_test_data()
  intervals <- create_intervals(data)
  events <- create_events(data)

  result <- tvevent(
    intervals_data = intervals,
    events_data = events,
    id = "id",
    date = "event_date",
    generate = "outcome",
    timegen = "followup_time",
    timeunit = "days",
    type = "single"
  )

  expect_true("followup_time" %in% names(result$data))
  # All times should be non-negative
  expect_true(all(result$data$followup_time >= 0))
})

# ============================================================================
# TEST 4: Time Generation - Months
# ============================================================================
test_that("tvevent timegen option creates time variable in months", {
  data <- load_test_data()
  intervals <- create_intervals(data)
  events <- create_events(data)

  result <- tvevent(
    intervals_data = intervals,
    events_data = events,
    id = "id",
    date = "event_date",
    generate = "outcome",
    timegen = "followup_time",
    timeunit = "months",
    type = "single"
  )

  expect_true("followup_time" %in% names(result$data))
})

# ============================================================================
# TEST 5: Time Generation - Years
# ============================================================================
test_that("tvevent timegen option creates time variable in years", {
  data <- load_test_data()
  intervals <- create_intervals(data)
  events <- create_events(data)

  result <- tvevent(
    intervals_data = intervals,
    events_data = events,
    id = "id",
    date = "event_date",
    generate = "outcome",
    timegen = "followup_time",
    timeunit = "years",
    type = "single"
  )

  expect_true("followup_time" %in% names(result$data))
})

# ============================================================================
# TEST 6: Recurring Events
# ============================================================================
test_that("tvevent handles recurring events", {
  # Create simple recurring event test data
  intervals <- data.frame(
    id = c(1, 1, 1, 2, 2),
    start = c(1, 11, 21, 1, 11),
    stop = c(10, 20, 30, 10, 20),
    exposure = c(1, 1, 0, 1, 0)
  )

  events <- data.frame(
    id = c(1, 1, 2),
    event_date = c(5, 15, 8)
  )

  result <- tvevent(
    intervals_data = intervals,
    events_data = events,
    id = "id",
    date = "event_date",
    generate = "outcome",
    type = "recurring"
  )

  expect_true(is.list(result))
  expect_true(nrow(result$data) > 0)
})

# ============================================================================
# TEST 7: Replace Option
# ============================================================================
test_that("tvevent replace option overwrites existing variable", {
  data <- load_test_data()
  intervals <- create_intervals(data)
  events <- create_events(data)

  # First create outcome
  intervals$outcome <- 0

  result <- tvevent(
    intervals_data = intervals,
    events_data = events,
    id = "id",
    date = "event_date",
    generate = "outcome",
    type = "single",
    replace = TRUE
  )

  expect_true("outcome" %in% names(result$data))
})

# ============================================================================
# TEST 8: Custom Event Labels
# ============================================================================
test_that("tvevent eventlabel option customizes labels", {
  data <- load_test_data()
  intervals <- create_intervals(data)
  events <- create_events(data)

  result <- tvevent(
    intervals_data = intervals,
    events_data = events,
    id = "id",
    date = "event_date",
    compete = c("death_dt", "emigration_dt"),
    generate = "outcome",
    eventlabel = c("0" = "No Event", "1" = "Primary", "2" = "Death", "3" = "Emigration"),
    type = "single"
  )

  # Should complete without error and have outcome variable
  expect_true("outcome" %in% names(result$data))
})

# ============================================================================
# TEST 9: Continuous Variable Adjustment
# ============================================================================
test_that("tvevent continuous option adjusts cumulative variables", {
  # Create intervals with cumulative dose
  intervals <- data.frame(
    id = c(1, 1, 2),
    start = c(1, 11, 1),
    stop = c(10, 20, 30),
    exposure = c(1, 1, 0),
    cum_dose = c(100, 200, 0)
  )

  # Event in middle of interval
  events <- data.frame(
    id = c(1),
    event_date = c(15)
  )

  result <- tvevent(
    intervals_data = intervals,
    events_data = events,
    id = "id",
    date = "event_date",
    generate = "outcome",
    continuous = c("cum_dose"),
    type = "single"
  )

  expect_true(is.list(result))
  expect_true("cum_dose" %in% names(result$data))
})

# ============================================================================
# TEST 10: KeepVars Option
# ============================================================================
test_that("tvevent keepvars option merges additional variables", {
  data <- load_test_data()
  intervals <- create_intervals(data)

  # Create events with extra variables
  events <- data$cohort[, c("id", "edss4_dt", "death_dt", "female", "age")]
  names(events)[2] <- "event_date"

  result <- tvevent(
    intervals_data = intervals,
    events_data = events,
    id = "id",
    date = "event_date",
    generate = "outcome",
    keepvars = c("female", "age"),
    type = "single"
  )

  # Note: keepvars from events are only merged to event intervals
  expect_true(is.list(result))
})

# ============================================================================
# TEST 11: Empty Events Data
# ============================================================================
test_that("tvevent handles empty events data", {
  data <- load_test_data()
  intervals <- create_intervals(data)

  # Create empty events
  events <- data.frame(
    id = integer(0),
    event_date = numeric(0)
  )

  # Should produce all censored
  expect_warning(
    result <- tvevent(
      intervals_data = intervals,
      events_data = events,
      id = "id",
      date = "event_date",
      generate = "outcome",
      type = "single"
    )
  )

  expect_equal(result$N_events, 0)
})

# ============================================================================
# TEST 12: All Missing Event Dates
# ============================================================================
test_that("tvevent handles all missing event dates", {
  data <- load_test_data()
  intervals <- create_intervals(data)

  # Create events with all NA dates (as numeric NA)
  events <- data.frame(
    id = c(1, 2, 3),
    event_date = as.numeric(c(NA, NA, NA))
  )

  expect_warning(
    result <- tvevent(
      intervals_data = intervals,
      events_data = events,
      id = "id",
      date = "event_date",
      generate = "outcome",
      type = "single"
    )
  )
})

# ============================================================================
# TEST 13: Single-Day Intervals
# ============================================================================
test_that("tvevent handles single-day intervals", {
  # Create intervals with single-day entries
  intervals <- data.frame(
    id = c(1, 1, 2),
    start = c(1, 10, 1),
    stop = c(10, 10, 20),  # Day 10 is single-day
    exposure = c(1, 0, 1)
  )

  events <- data.frame(
    id = c(1, 2),
    event_date = c(5, 15)
  )

  result <- tvevent(
    intervals_data = intervals,
    events_data = events,
    id = "id",
    date = "event_date",
    generate = "outcome",
    type = "single"
  )

  expect_true(nrow(result$data) > 0)
})

# ============================================================================
# TEST 14: Returns Structure
# ============================================================================
test_that("tvevent returns proper structure", {
  data <- load_test_data()
  intervals <- create_intervals(data)
  events <- create_events(data)

  result <- tvevent(
    intervals_data = intervals,
    events_data = events,
    id = "id",
    date = "event_date",
    generate = "outcome",
    type = "single"
  )

  expect_true("N" %in% names(result))
  expect_true("N_events" %in% names(result))
  expect_true("generate" %in% names(result))
  expect_true("type" %in% names(result))
})

# ============================================================================
# TEST 15: Class Attribute
# ============================================================================
test_that("tvevent returns object of correct class", {
  data <- load_test_data()
  intervals <- create_intervals(data)
  events <- create_events(data)

  result <- tvevent(
    intervals_data = intervals,
    events_data = events,
    id = "id",
    date = "event_date",
    generate = "outcome",
    type = "single"
  )

  expect_true("tvevent" %in% class(result))
})

# ============================================================================
# Run all tests
# ============================================================================
cat("\nRunning tvevent tests...\n")
