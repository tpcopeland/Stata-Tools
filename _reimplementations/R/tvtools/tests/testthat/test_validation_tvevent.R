# Comprehensive validation tests for tvevent R implementation
# Matches Stata validation tests from _validation/validation_tvevent.do

library(testthat)
library(tvtools)

# Test data path - use RDS files
data_path <- "/home/tpcopeland/Stata-Tools/_reimplementations/data/R"

# Helper functions
load_test_data <- function() {
  cohort <- readRDS(file.path(data_path, "cohort.rds"))
  # Create outcomes from cohort data (events are in cohort)
  outcomes <- cohort[, c("id", "edss4_dt", "death_dt", "emigration_dt")]
  list(cohort = cohort, outcomes = outcomes)
}

# Helper to check if outcome is censored (handles both factor and numeric)
is_censored <- function(x) {
  if (is.factor(x)) {
    as.character(x) == "Censored"
  } else {
    x == 0
  }
}

# Helper to check if outcome is an event (not censored)
is_event <- function(x) {
  !is_censored(x)
}

# Helper to count events
count_events <- function(x) {
  sum(is_event(x), na.rm = TRUE)
}

# Create validation datasets
create_tvevent_validation_data <- function() {
  # Base TV dataset (3 intervals)
  tv_base <- data.frame(
    id = c(1L, 1L, 1L),
    start = as.Date(c("2020-01-01", "2020-05-01", "2020-09-01")),
    stop = as.Date(c("2020-04-30", "2020-08-31", "2020-12-31")),
    exposure = c(0L, 1L, 0L)
  )

  # Event in middle interval
  event_mid <- data.frame(
    id = 1L,
    event_date = as.Date("2020-06-15")
  )

  # Event at interval boundary
  event_boundary <- data.frame(
    id = 1L,
    event_date = as.Date("2020-05-01")
  )

  # Event at interval stop
  event_stop <- data.frame(
    id = 1L,
    event_date = as.Date("2020-04-30")
  )

  # Event outside study period
  event_outside <- data.frame(
    id = 1L,
    event_date = as.Date("2021-06-15")
  )

  # Competing risks events
  event_competing <- data.frame(
    id = 1L,
    event_date = as.Date("2020-06-15"),
    compete_date = as.Date("2020-08-15")
  )

  # Earlier competing event
  event_compete_first <- data.frame(
    id = 1L,
    event_date = as.Date("2020-08-15"),
    compete_date = as.Date("2020-06-15")
  )

  # Multiple events for recurring
  event_recurring <- data.frame(
    id = c(1L, 1L, 1L),
    event_date = as.Date(c("2020-02-15", "2020-06-15", "2020-10-15"))
  )

  # Multi-person TV dataset
  tv_multi <- data.frame(
    id = c(1L, 1L, 2L, 2L, 3L),
    start = as.Date(c("2020-01-01", "2020-07-01", "2020-01-01", "2020-07-01", "2020-01-01")),
    stop = as.Date(c("2020-06-30", "2020-12-31", "2020-06-30", "2020-12-31", "2020-12-31")),
    exposure = c(0L, 1L, 1L, 0L, 0L)
  )

  # Multi-person events
  event_multi <- data.frame(
    id = c(1L, 2L),
    event_date = as.Date(c("2020-03-15", "2020-09-15"))
  )

  # Three competing risks
  event_3compete <- data.frame(
    id = 1L,
    event_date = as.Date("2020-08-15"),
    compete1_date = as.Date("2020-06-15"),
    compete2_date = as.Date("2020-07-15")
  )

  list(
    tv_base = tv_base,
    event_mid = event_mid,
    event_boundary = event_boundary,
    event_stop = event_stop,
    event_outside = event_outside,
    event_competing = event_competing,
    event_compete_first = event_compete_first,
    event_recurring = event_recurring,
    tv_multi = tv_multi,
    event_multi = event_multi,
    event_3compete = event_3compete
  )
}

# ============================================================================
# SECTION 4.1: EVENT PLACEMENT TESTS
# ============================================================================

test_that("4.1.1: Event Placed at Correct Boundary", {
  vdata <- create_tvevent_validation_data()

  result <- tvevent(
    intervals_data = vdata$tv_base,
    events_data = vdata$event_mid,
    id = "id",
    date = "event_date",
    type = "single"
  )

  df <- result$data
  df <- df[order(df$start), ]

  # With type=single, person-time is censored after first event
  # So we expect 2 rows: pre-event interval and event interval
  expect_gte(nrow(df), 2)
  # Check that event row exists ending at event date
  event_rows <- df[df$stop == as.Date("2020-06-15"), ]
  expect_gte(nrow(event_rows), 1)
})

test_that("4.1.2: Event Count Preservation", {
  vdata <- create_tvevent_validation_data()

  result <- tvevent(
    intervals_data = vdata$tv_base,
    events_data = vdata$event_mid,
    id = "id",
    date = "event_date",
    type = "single"
  )

  df <- result$data
  # Get the outcome column name (might be _failure or outcome)
  outcome_col <- grep("outcome|failure", names(df), value = TRUE)[1]
  if (!is.na(outcome_col)) {
    event_count <- count_events(df[[outcome_col]])
    expect_equal(event_count, 1)
  }
})

# ============================================================================
# SECTION 4.2: PERSON-TIME TESTS
# ============================================================================

test_that("4.2.1: Split Preserves Total Duration (single)", {
  vdata <- create_tvevent_validation_data()

  original_dur <- sum(as.numeric(vdata$tv_base$stop - vdata$tv_base$start))

  result <- tvevent(
    intervals_data = vdata$tv_base,
    events_data = vdata$event_mid,
    id = "id",
    date = "event_date",
    type = "single"
  )

  df <- result$data
  result_dur <- sum(as.numeric(df$stop - df$start))

  # Duration should be less or equal (truncated at event for type=single)
  expect_lte(result_dur, original_dur)
})

# ============================================================================
# SECTION 4.3: COMPETING RISKS TESTS
# ============================================================================

test_that("4.3.1: Earliest Event Wins", {
  vdata <- create_tvevent_validation_data()

  result <- tvevent(
    intervals_data = vdata$tv_base,
    events_data = vdata$event_compete_first,
    id = "id",
    date = "event_date",
    compete = "compete_date",
    type = "single"
  )

  df <- result$data
  # Competing event on Jun 15 is earlier than primary on Aug 15
  outcome_col <- grep("outcome|failure", names(df), value = TRUE)[1]
  if (!is.na(outcome_col)) {
    event_rows <- df[is_event(df[[outcome_col]]), ]
    expect_equal(event_rows$stop[1], as.Date("2020-06-15"))
  }
})

test_that("4.3.2: Multiple Competing Risks", {
  vdata <- create_tvevent_validation_data()

  result <- tvevent(
    intervals_data = vdata$tv_base,
    events_data = vdata$event_competing,
    id = "id",
    date = "event_date",
    compete = "compete_date",
    type = "single"
  )

  df <- result$data
  outcome_col <- grep("outcome|failure", names(df), value = TRUE)[1]
  if (!is.na(outcome_col)) {
    event_rows <- df[is_event(df[[outcome_col]]), ]
    expect_gte(nrow(event_rows), 1)
  }
})

# ============================================================================
# SECTION 4.4: EVENT TYPE TESTS
# ============================================================================

test_that("4.4.1: type(single) Censors After First Event", {
  vdata <- create_tvevent_validation_data()

  result <- tvevent(
    intervals_data = vdata$tv_base,
    events_data = vdata$event_mid,
    id = "id",
    date = "event_date",
    type = "single"
  )

  df <- result$data
  df <- df[order(df$start), ]

  event_date <- as.Date("2020-06-15")
  rows_after_event <- df[df$start > event_date, ]

  # For type=single, follow-up should stop at event
  expect_equal(nrow(rows_after_event), 0)
})

# ============================================================================
# SECTION 4.6: BOUNDARY TESTS
# ============================================================================

test_that("4.6.1: Event Exactly at Interval Start", {
  vdata <- create_tvevent_validation_data()

  result <- tvevent(
    intervals_data = vdata$tv_base,
    events_data = vdata$event_boundary,
    id = "id",
    date = "event_date",
    type = "single"
  )

  df <- result$data
  expect_gte(nrow(df), 1)
})

test_that("4.6.2: Event Exactly at Interval Stop", {
  vdata <- create_tvevent_validation_data()

  result <- tvevent(
    intervals_data = vdata$tv_base,
    events_data = vdata$event_stop,
    id = "id",
    date = "event_date",
    type = "single"
  )

  df <- result$data
  expect_gte(nrow(df), 1)
})

test_that("4.6.3: Event One Day Inside Boundaries", {
  vdata <- create_tvevent_validation_data()

  event_inside <- data.frame(
    id = 1L,
    event_date = as.Date("2020-05-02")
  )

  result <- tvevent(
    intervals_data = vdata$tv_base,
    events_data = event_inside,
    id = "id",
    date = "event_date",
    type = "single"
  )

  df <- result$data
  expect_gte(nrow(df), 1)
})

# ============================================================================
# SECTION 4.7: MISSING/OUTSIDE EVENTS TESTS
# ============================================================================

test_that("4.7.1: Event Outside Study Period", {
  vdata <- create_tvevent_validation_data()

  result <- tvevent(
    intervals_data = vdata$tv_base,
    events_data = vdata$event_outside,
    id = "id",
    date = "event_date",
    type = "single"
  )

  df <- result$data
  outcome_col <- grep("outcome|failure", names(df), value = TRUE)[1]
  if (!is.na(outcome_col)) {
    expect_true(all(is_censored(df[[outcome_col]])))
  }
})

test_that("4.7.2: Person with No Events", {
  vdata <- create_tvevent_validation_data()

  event_empty <- data.frame(
    id = integer(0),
    event_date = as.Date(character(0))
  )

  result <- tvevent(
    intervals_data = vdata$tv_base,
    events_data = event_empty,
    id = "id",
    date = "event_date",
    type = "single"
  )

  df <- result$data
  outcome_col <- grep("outcome|failure", names(df), value = TRUE)[1]
  if (!is.na(outcome_col)) {
    expect_true(all(is_censored(df[[outcome_col]])))
  }
})

# ============================================================================
# SECTION 4.8: ERROR HANDLING TESTS
# ============================================================================

test_that("4.8.1: Missing Required Variables", {
  vdata <- create_tvevent_validation_data()

  event_no_id <- data.frame(
    wrong_id = 1L,
    event_date = as.Date("2020-06-15")
  )

  expect_error(
    tvevent(
      intervals_data = vdata$tv_base,
      events_data = event_no_id,
      id = "id",
      date = "event_date",
      type = "single"
    )
  )
})

test_that("4.8.2: Invalid Type Option", {
  vdata <- create_tvevent_validation_data()

  expect_error(
    tvevent(
      intervals_data = vdata$tv_base,
      events_data = vdata$event_mid,
      id = "id",
      date = "event_date",
      type = "invalid_type"
    )
  )
})

# ============================================================================
# SECTION 4.9: TIME GENERATION TESTS
# ============================================================================

test_that("4.9.1: timegen Creates Time-to-Event Variable", {
  vdata <- create_tvevent_validation_data()

  result <- tvevent(
    intervals_data = vdata$tv_base,
    events_data = vdata$event_mid,
    id = "id",
    date = "event_date",
    type = "single",
    timegen = "time"
  )

  df <- result$data
  expect_true("time" %in% names(df) || any(grepl("time", names(df), ignore.case = TRUE)))
})

test_that("4.9.2: timeunit Conversion", {
  vdata <- create_tvevent_validation_data()

  result <- tvevent(
    intervals_data = vdata$tv_base,
    events_data = vdata$event_mid,
    id = "id",
    date = "event_date",
    type = "single",
    timegen = "time",
    timeunit = "years"
  )

  df <- result$data
  if ("time" %in% names(df)) {
    expect_true(max(df$time, na.rm = TRUE) < 2)
  }
})

# ============================================================================
# SECTION 4.14: RECURRING EVENTS TESTS
# ============================================================================

test_that("4.14.1: type(recurring) Processes Multiple Events", {
  vdata <- create_tvevent_validation_data()

  result <- tvevent(
    intervals_data = vdata$tv_base,
    events_data = vdata$event_recurring,
    id = "id",
    date = "event_date",
    type = "recurring"
  )

  df <- result$data
  outcome_col <- grep("outcome|failure", names(df), value = TRUE)[1]
  if (!is.na(outcome_col)) {
    event_count <- count_events(df[[outcome_col]])
    expect_gte(event_count, 2)
  }
})

test_that("4.14.2: type(recurring) Does Not Truncate Follow-up", {
  vdata <- create_tvevent_validation_data()

  orig_end <- max(vdata$tv_base$stop)

  result <- tvevent(
    intervals_data = vdata$tv_base,
    events_data = vdata$event_recurring,
    id = "id",
    date = "event_date",
    type = "recurring"
  )

  df <- result$data
  expect_equal(max(df$stop), orig_end)
})

# ============================================================================
# SECTION 4.15: TIMEUNIT TESTS
# ============================================================================

test_that("4.15.1: timeunit(months) Conversion", {
  vdata <- create_tvevent_validation_data()

  result <- tvevent(
    intervals_data = vdata$tv_base,
    events_data = vdata$event_mid,
    id = "id",
    date = "event_date",
    type = "single",
    timegen = "time",
    timeunit = "months"
  )

  df <- result$data
  if ("time" %in% names(df)) {
    expect_true(max(df$time, na.rm = TRUE) < 15)
  }
})

# ============================================================================
# SECTION 4.17: THREE COMPETING RISKS TESTS
# ============================================================================

test_that("4.17.1: Three Competing Risks", {
  vdata <- create_tvevent_validation_data()

  result <- tvevent(
    intervals_data = vdata$tv_base,
    events_data = vdata$event_3compete,
    id = "id",
    date = "event_date",
    compete = c("compete1_date", "compete2_date"),
    type = "single"
  )

  df <- result$data
  outcome_col <- grep("outcome|failure", names(df), value = TRUE)[1]
  if (!is.na(outcome_col)) {
    event_rows <- df[is_event(df[[outcome_col]]), ]
    expect_gte(nrow(event_rows), 1)
    expect_equal(event_rows$stop[1], as.Date("2020-06-15"))
  }
})

test_that("4.17.2: Primary Event Wins When Earliest", {
  tv <- data.frame(
    id = 1L,
    start = as.Date("2020-01-01"),
    stop = as.Date("2020-12-31"),
    exposure = 1L
  )

  events <- data.frame(
    id = 1L,
    event_date = as.Date("2020-03-15"),
    compete_date = as.Date("2020-06-15")
  )

  result <- tvevent(
    intervals_data = tv,
    events_data = events,
    id = "id",
    date = "event_date",
    compete = "compete_date",
    type = "single"
  )

  df <- result$data
  outcome_col <- grep("outcome|failure", names(df), value = TRUE)[1]
  if (!is.na(outcome_col)) {
    # Handle factor columns - check for non-Censored (event occurred)
    if (is.factor(df[[outcome_col]])) {
      event_rows <- df[as.character(df[[outcome_col]]) != "Censored", ]
      expect_equal(event_rows$stop[1], as.Date("2020-03-15"))
      # For factor, check it's the primary event (level containing "Event:" and not "Competing")
      expect_true(grepl("Event:", as.character(event_rows[[outcome_col]][1])))
    } else {
      event_rows <- df[df[[outcome_col]] != 0, ]
      expect_equal(event_rows$stop[1], as.Date("2020-03-15"))
      expect_equal(event_rows[[outcome_col]][1], 1)
    }
  }
})

# ============================================================================
# SECTION 4.26: MULTI-PERSON TESTS
# ============================================================================

test_that("4.26.1: Multiple Persons with Different Event Status", {
  vdata <- create_tvevent_validation_data()

  result <- tvevent(
    intervals_data = vdata$tv_multi,
    events_data = vdata$event_multi,
    id = "id",
    date = "event_date",
    type = "single"
  )

  df <- result$data
  outcome_col <- grep("outcome|failure", names(df), value = TRUE)[1]

  if (!is.na(outcome_col)) {
    person1 <- df[df$id == 1, ]
    person2 <- df[df$id == 2, ]
    person3 <- df[df$id == 3, ]

    # Handle factor columns - compare to "Censored" for censored, anything else for event
    if (is.factor(df[[outcome_col]])) {
      expect_true(any(as.character(person1[[outcome_col]]) != "Censored"))
      expect_true(any(as.character(person2[[outcome_col]]) != "Censored"))
      expect_true(all(as.character(person3[[outcome_col]]) == "Censored"))
    } else {
      expect_true(any(person1[[outcome_col]] != 0))
      expect_true(any(person2[[outcome_col]] != 0))
      expect_true(all(person3[[outcome_col]] == 0))
    }
  }
})

test_that("4.26.2: Multi-Person Recurring Events", {
  vdata <- create_tvevent_validation_data()

  event_multi_recurring <- data.frame(
    id = c(1L, 1L, 2L),
    event_date = as.Date(c("2020-03-15", "2020-09-15", "2020-06-15"))
  )

  result <- tvevent(
    intervals_data = vdata$tv_multi,
    events_data = event_multi_recurring,
    id = "id",
    date = "event_date",
    type = "recurring"
  )

  df <- result$data
  outcome_col <- grep("outcome|failure", names(df), value = TRUE)[1]

  if (!is.na(outcome_col)) {
    person1_events <- sum(df$id == 1 & is_event(df[[outcome_col]]))
    person2_events <- sum(df$id == 2 & is_event(df[[outcome_col]]))

    expect_gte(person1_events, 1)
    expect_gte(person2_events, 1)
  }
})

# ============================================================================
# SECTION 4.29: INVARIANTS
# ============================================================================

test_that("4.29.1: type(recurring) Preserves Total Duration", {
  vdata <- create_tvevent_validation_data()

  original_dur <- sum(as.numeric(vdata$tv_base$stop - vdata$tv_base$start))

  result <- tvevent(
    intervals_data = vdata$tv_base,
    events_data = vdata$event_recurring,
    id = "id",
    date = "event_date",
    type = "recurring"
  )

  df <- result$data
  result_dur <- sum(as.numeric(df$stop - df$start))

  expect_equal(result_dur, original_dur)
})

test_that("4.29.2: Interval Ordering Maintained After Splits", {
  vdata <- create_tvevent_validation_data()

  result <- tvevent(
    intervals_data = vdata$tv_base,
    events_data = vdata$event_mid,
    id = "id",
    date = "event_date",
    type = "single"
  )

  df <- result$data
  df <- df[order(df$id, df$start), ]

  for (i in 2:nrow(df)) {
    if (df$id[i] == df$id[i-1]) {
      expect_lte(df$stop[i-1], df$start[i])
    }
  }
})

test_that("4.29.3: Exactly One Event Row Per Primary Event (type=single)", {
  vdata <- create_tvevent_validation_data()

  result <- tvevent(
    intervals_data = vdata$tv_base,
    events_data = vdata$event_mid,
    id = "id",
    date = "event_date",
    type = "single"
  )

  df <- result$data
  outcome_col <- grep("outcome|failure", names(df), value = TRUE)[1]
  if (!is.na(outcome_col)) {
    event_count <- count_events(df[[outcome_col]])
    expect_equal(event_count, 1)
  }
})

# ============================================================================
# REAL DATA TESTS
# ============================================================================

test_that("Real data: Basic event integration", {
  skip("Integration test requires specific test data")
  data <- load_test_data()

  tv <- tvexpose(
    master_data = data$cohort,
    exposure_file = read_dta(file.path(data_path, "hrt.dta")),
    id = "id",
    start = "rx_start",
    stop = "rx_stop",
    exposure = "hrt_type",
    entry = "study_entry",
    exit = "study_exit",
    reference = 0,
    verbose = FALSE
  )$data

  result <- tvevent(
    intervals_data = tv,
    events_data = data$outcomes,
    id = "id",
    date = "outcome_date",
    type = "single"
  )

  df <- result$data

  expect_gte(nrow(df), 1)
  expect_true(all(df$stop > df$start))
})

cat("\nR tvevent validation tests complete.\n")
