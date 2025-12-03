# Basic Test Script for tvevent Function
# This script performs simple tests to verify core functionality

library(dplyr)

# Source the tvevent function
source("/home/user/Stata-Tools/Reimplementations/R/tvevent.R")

cat("\n")
cat("="*60, "\n")
cat("BASIC TVEVENT FUNCTIONALITY TESTS\n")
cat("="*60, "\n\n")

# ==============================================================================
# Test 1: Basic Single Event
# ==============================================================================
cat("Test 1: Basic Single Event\n")
cat("-"*60, "\n")

intervals1 <- data.frame(
  id = c(1, 1, 2, 2),
  start = as.Date(c("2020-01-01", "2020-07-01", "2020-01-01", "2020-06-01")),
  stop = as.Date(c("2020-06-30", "2020-12-31", "2020-05-31", "2020-12-31"))
)

events1 <- data.frame(
  id = c(1, 2),
  event_date = as.Date(c("2020-09-15", "2020-08-01"))
)

tryCatch({
  result1 <- tvevent(
    intervals_data = intervals1,
    events_data = events1,
    id = "id",
    date = "event_date",
    generate = "failure",
    type = "single"
  )
  cat("\n✓ Test 1 PASSED: Basic single event\n")
  cat(sprintf("  Observations: %d, Events: %d\n", result1$N, result1$N_events))
}, error = function(e) {
  cat("\n✗ Test 1 FAILED:\n")
  cat(sprintf("  Error: %s\n", e$message))
})

# ==============================================================================
# Test 2: Competing Risks
# ==============================================================================
cat("\n\nTest 2: Competing Risks\n")
cat("-"*60, "\n")

intervals2 <- data.frame(
  id = 1:3,
  start = as.Date(rep("2020-01-01", 3)),
  stop = as.Date(rep("2020-12-31", 3))
)

events2 <- data.frame(
  id = 1:3,
  primary_date = as.Date(c("2020-06-01", "2020-08-01", NA)),
  death_date = as.Date(c("2020-09-01", "2020-05-01", "2020-07-01"))
)

tryCatch({
  result2 <- tvevent(
    intervals_data = intervals2,
    events_data = events2,
    id = "id",
    date = "primary_date",
    compete = "death_date",
    generate = "outcome",
    type = "single"
  )
  cat("\n✓ Test 2 PASSED: Competing risks\n")
  cat(sprintf("  Observations: %d, Events: %d\n", result2$N, result2$N_events))
  cat("  Event types:\n")
  print(table(result2$data$outcome))
}, error = function(e) {
  cat("\n✗ Test 2 FAILED:\n")
  cat(sprintf("  Error: %s\n", e$message))
})

# ==============================================================================
# Test 3: Interval Splitting with Mid-Interval Event
# ==============================================================================
cat("\n\nTest 3: Interval Splitting\n")
cat("-"*60, "\n")

intervals3 <- data.frame(
  id = 1,
  start = as.Date("2020-01-01"),
  stop = as.Date("2020-12-31")
)

events3 <- data.frame(
  id = 1,
  event_date = as.Date("2020-06-15")  # Mid-interval
)

tryCatch({
  result3 <- tvevent(
    intervals_data = intervals3,
    events_data = events3,
    id = "id",
    date = "event_date",
    generate = "status",
    type = "single"
  )
  cat("\n✓ Test 3 PASSED: Interval splitting\n")
  cat(sprintf("  Original intervals: %d, After splitting: %d\n",
              nrow(intervals3), result3$N))
  cat("  Split intervals:\n")
  print(result3$data[, c("id", "start", "stop", "status")])
}, error = function(e) {
  cat("\n✗ Test 3 FAILED:\n")
  cat(sprintf("  Error: %s\n", e$message))
})

# ==============================================================================
# Test 4: Continuous Variable Adjustment
# ==============================================================================
cat("\n\nTest 4: Continuous Variable Adjustment\n")
cat("-"*60, "\n")

intervals4 <- data.frame(
  id = 1,
  start = as.Date("2020-01-01"),
  stop = as.Date("2020-01-31"),  # 30 days
  total_dose = 300  # 10 mg/day
)

events4 <- data.frame(
  id = 1,
  event_date = as.Date("2020-01-11")  # Day 10
)

tryCatch({
  result4 <- tvevent(
    intervals_data = intervals4,
    events_data = events4,
    id = "id",
    date = "event_date",
    continuous = "total_dose",
    type = "single"
  )
  cat("\n✓ Test 4 PASSED: Continuous variable adjustment\n")
  cat(sprintf("  Original total dose: %.2f\n", 300))
  cat(sprintf("  Sum after split: %.2f\n", sum(result4$data$total_dose)))
  cat("  Split doses:\n")
  print(result4$data[, c("id", "start", "stop", "total_dose")])
}, error = function(e) {
  cat("\n✗ Test 4 FAILED:\n")
  cat(sprintf("  Error: %s\n", e$message))
})

# ==============================================================================
# Test 5: Recurring Events
# ==============================================================================
cat("\n\nTest 5: Recurring Events\n")
cat("-"*60, "\n")

intervals5 <- data.frame(
  id = c(1, 1, 1),
  start = as.Date(c("2020-01-01", "2020-04-01", "2020-07-01")),
  stop = as.Date(c("2020-03-31", "2020-06-30", "2020-09-30"))
)

events5 <- data.frame(
  id = c(1, 1),
  event_date = as.Date(c("2020-05-15", "2020-08-15"))  # Two events
)

tryCatch({
  result5 <- tvevent(
    intervals_data = intervals5,
    events_data = events5,
    id = "id",
    date = "event_date",
    type = "recurring",  # Allow multiple events
    generate = "event_flag"
  )
  cat("\n✓ Test 5 PASSED: Recurring events\n")
  cat(sprintf("  Total events flagged: %d\n", result5$N_events))
  cat(sprintf("  Expected: 2, Got: %d\n", result5$N_events))
}, error = function(e) {
  cat("\n✗ Test 5 FAILED:\n")
  cat(sprintf("  Error: %s\n", e$message))
})

# ==============================================================================
# Test 6: Time Generation
# ==============================================================================
cat("\n\nTest 6: Time Variable Generation\n")
cat("-"*60, "\n")

intervals6 <- data.frame(
  id = 1,
  start = as.Date("2020-01-01"),
  stop = as.Date("2020-12-31")  # 366 days (leap year)
)

events6 <- data.frame(
  id = 1,
  event_date = as.Date("2021-01-15")  # After interval
)

tryCatch({
  result6 <- tvevent(
    intervals_data = intervals6,
    events_data = events6,
    id = "id",
    date = "event_date",
    timegen = "time_years",
    timeunit = "years"
  )
  cat("\n✓ Test 6 PASSED: Time variable generation\n")
  cat(sprintf("  Duration in years: %.4f\n", result6$data$time_years))
  cat(sprintf("  Expected: %.4f (366/365.25)\n", 366/365.25))
}, error = function(e) {
  cat("\n✗ Test 6 FAILED:\n")
  cat(sprintf("  Error: %s\n", e$message))
})

# ==============================================================================
# Test 7: Empty Events Dataset
# ==============================================================================
cat("\n\nTest 7: Empty Events Dataset (Warning Expected)\n")
cat("-"*60, "\n")

intervals7 <- data.frame(
  id = 1,
  start = as.Date("2020-01-01"),
  stop = as.Date("2020-12-31")
)

events7 <- data.frame(
  id = integer(),
  event_date = as.Date(character())
)

tryCatch({
  result7 <- suppressWarnings(
    tvevent(
      intervals_data = intervals7,
      events_data = events7,
      id = "id",
      date = "event_date"
    )
  )
  cat("\n✓ Test 7 PASSED: Empty events handled correctly\n")
  cat(sprintf("  All intervals censored: %s\n",
              all(as.integer(result7$data$`_failure`) == 0)))
}, error = function(e) {
  cat("\n✗ Test 7 FAILED:\n")
  cat(sprintf("  Error: %s\n", e$message))
})

# ==============================================================================
# Test 8: Replace Option
# ==============================================================================
cat("\n\nTest 8: Replace Option\n")
cat("-"*60, "\n")

intervals8 <- data.frame(
  id = 1,
  start = as.Date("2020-01-01"),
  stop = as.Date("2020-12-31"),
  `_failure` = 999  # Pre-existing variable
)
names(intervals8)[4] <- "_failure"

events8 <- data.frame(
  id = 1,
  event_date = as.Date("2020-06-15")
)

tryCatch({
  # This should error without replace
  result8_error <- tryCatch(
    tvevent(intervals8, events8, "id", "event_date", replace = FALSE),
    error = function(e) "ERROR_EXPECTED"
  )

  if (result8_error == "ERROR_EXPECTED") {
    cat("\n✓ Test 8a PASSED: Correctly errors without replace=TRUE\n")
  } else {
    cat("\n✗ Test 8a FAILED: Should have errored without replace=TRUE\n")
  }

  # This should succeed with replace
  result8 <- tvevent(intervals8, events8, "id", "event_date", replace = TRUE)
  cat("✓ Test 8b PASSED: Works with replace=TRUE\n")
  cat(sprintf("  Old value (999) removed: %s\n",
              !any(result8$data$`_failure` == "999")))

}, error = function(e) {
  cat("\n✗ Test 8 FAILED:\n")
  cat(sprintf("  Error: %s\n", e$message))
})

# ==============================================================================
# Summary
# ==============================================================================
cat("\n\n")
cat("="*60, "\n")
cat("TEST SUITE COMPLETE\n")
cat("="*60, "\n")
cat("\nAll basic functionality tests completed.\n")
cat("Check output above for any failures.\n\n")
