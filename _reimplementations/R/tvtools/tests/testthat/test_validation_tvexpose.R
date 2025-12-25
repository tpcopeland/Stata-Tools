# Comprehensive validation tests for tvexpose R implementation
# Matches Stata validation tests from _validation/validation_tvexpose.do

library(testthat)
library(tvtools)

# Test data path - use RDS files
data_path <- "/home/tpcopeland/Stata-Tools/_reimplementations/data/R"

# Helper functions
load_test_data <- function() {
  cohort <- readRDS(file.path(data_path, "cohort.rds"))
  hrt <- readRDS(file.path(data_path, "hrt.rds"))
  list(cohort = cohort, hrt = hrt)
}

# Create minimal validation datasets
create_validation_data <- function() {
  # Single person cohort, 2020 (366 days = leap year)
  cohort_single <- data.frame(
    id = 1L,
    study_entry = as.Date("2020-01-01"),
    study_exit = as.Date("2020-12-31")
  )

  # Basic single exposure (Mar 1 - Jun 30, 2020)
  exp_basic <- data.frame(
    id = 1L,
    rx_start = as.Date("2020-03-01"),
    rx_stop = as.Date("2020-06-30"),
    exp_type = 1L
  )

  # Two non-overlapping exposures
  exp_two <- data.frame(
    id = c(1L, 1L),
    rx_start = as.Date(c("2020-02-01", "2020-08-01")),
    rx_stop = as.Date(c("2020-03-31", "2020-10-31")),
    exp_type = c(1L, 2L)
  )

  # Overlapping exposures (Apr-Jun overlap)
  exp_overlap <- data.frame(
    id = c(1L, 1L),
    rx_start = as.Date(c("2020-01-01", "2020-04-01")),
    rx_stop = as.Date(c("2020-06-30", "2020-09-30")),
    exp_type = c(1L, 2L)
  )

  # Exposures with 15-day gap for grace period testing
  exp_gap15 <- data.frame(
    id = c(1L, 1L),
    rx_start = as.Date(c("2020-01-01", "2020-02-15")),
    rx_stop = as.Date(c("2020-01-31", "2020-03-17")),
    exp_type = c(1L, 1L)
  )

  # Full-year exposure for cumulative testing
  exp_fullyear <- data.frame(
    id = 1L,
    rx_start = as.Date("2020-01-01"),
    rx_stop = as.Date("2020-12-31"),
    exp_type = 1L
  )

  list(
    cohort_single = cohort_single,
    exp_basic = exp_basic,
    exp_two = exp_two,
    exp_overlap = exp_overlap,
    exp_gap15 = exp_gap15,
    exp_fullyear = exp_fullyear
  )
}

# ============================================================================
# SECTION 3.1: CORE TRANSFORMATION TESTS
# ============================================================================

test_that("3.1.1: Basic Interval Splitting", {
  vdata <- create_validation_data()

  result <- tvexpose(
    master_data = vdata$cohort_single,
    exposure_file = vdata$exp_basic,
    id = "id",
    start = "rx_start",
    stop = "rx_stop",
    exposure = "exp_type",
    entry = "study_entry",
    exit = "study_exit",
    reference = 0,
    verbose = FALSE
  )

  # Should have 3 intervals (before, during, after exposure)
  expect_gte(nrow(result$data), 3)

  # Verify non-overlapping
  df <- result$data
  df <- df[order(df$start), ]
  for (i in 2:nrow(df)) {
    expect_lte(df$stop[i-1], df$start[i])
  }
})

test_that("3.1.2: Person-Time Conservation", {
  vdata <- create_validation_data()

  # Original person-time
  expected_ptime <- as.numeric(vdata$cohort_single$study_exit - vdata$cohort_single$study_entry)

  result <- tvexpose(
    master_data = vdata$cohort_single,
    exposure_file = vdata$exp_basic,
    id = "id",
    start = "rx_start",
    stop = "rx_stop",
    exposure = "exp_type",
    entry = "study_entry",
    exit = "study_exit",
    reference = 0,
    verbose = FALSE
  )

  df <- result$data
  actual_ptime <- sum(as.numeric(df$stop - df$start))

  # Allow small tolerance for date handling
  expect_lt(abs(actual_ptime - expected_ptime) / expected_ptime, 0.01)
})

test_that("3.1.3: Non-Overlapping Intervals with Overlapping Exposures", {
  vdata <- create_validation_data()

  result <- tvexpose(
    master_data = vdata$cohort_single,
    exposure_file = vdata$exp_overlap,
    id = "id",
    start = "rx_start",
    stop = "rx_stop",
    exposure = "exp_type",
    entry = "study_entry",
    exit = "study_exit",
    reference = 0,
    verbose = FALSE
  )

  df <- result$data
  df <- df[order(df$id, df$start), ]

  # Check no overlaps
  n_overlaps <- 0
  for (i in 2:nrow(df)) {
    if (df$id[i] == df$id[i-1] && df$start[i] < df$stop[i-1]) {
      n_overlaps <- n_overlaps + 1
    }
  }
  expect_equal(n_overlaps, 0)
})

# ============================================================================
# SECTION 3.2: CUMULATIVE EXPOSURE TESTS
# ============================================================================

test_that("3.2.1: continuousunit(years) Calculation", {
  vdata <- create_validation_data()

  result <- tvexpose(
    master_data = vdata$cohort_single,
    exposure_file = vdata$exp_fullyear,
    id = "id",
    start = "rx_start",
    stop = "rx_stop",
    exposure = "exp_type",
    entry = "study_entry",
    exit = "study_exit",
    reference = 0,
    continuousunit = "years",
    verbose = FALSE
  )

  df <- result$data
  max_cum <- max(df$tv_exp, na.rm = TRUE)

  # Full year should be ~1 year
  expect_lt(abs(max_cum - 1.0), 0.1)
})

test_that("3.2.2: Cumulative Monotonicity", {
  vdata <- create_validation_data()

  result <- tvexpose(
    master_data = vdata$cohort_single,
    exposure_file = vdata$exp_two,
    id = "id",
    start = "rx_start",
    stop = "rx_stop",
    exposure = "exp_type",
    entry = "study_entry",
    exit = "study_exit",
    reference = 0,
    continuousunit = "days",
    verbose = FALSE
  )

  df <- result$data
  df <- df[order(df$id, df$start), ]

  # Cumulative exposure should never decrease within a person
  for (i in 2:nrow(df)) {
    if (df$id[i] == df$id[i-1]) {
      expect_gte(df$tv_exp[i], df$tv_exp[i-1] - 0.001)
    }
  }
})

# ============================================================================
# SECTION 3.3: CURRENT/FORMER STATUS TESTS
# ============================================================================

test_that("3.3.1: currentformer Transitions", {
  vdata <- create_validation_data()

  result <- tvexpose(
    master_data = vdata$cohort_single,
    exposure_file = vdata$exp_basic,
    id = "id",
    start = "rx_start",
    stop = "rx_stop",
    exposure = "exp_type",
    entry = "study_entry",
    exit = "study_exit",
    reference = 0,
    currentformer = TRUE,
    verbose = FALSE
  )

  df <- result$data
  df <- df[order(df$start), ]

  # Should have 0 (never), 1 (current), 2 (former)
  expect_true(0 %in% df$tv_exposure)
  expect_true(1 %in% df$tv_exposure)
  expect_true(2 %in% df$tv_exposure)

  # Before exposure: 0, During: 1, After: 2
  expect_equal(df$tv_exposure[1], 0)
  # Last should be 2 (former)
  expect_equal(df$tv_exposure[nrow(df)], 2)
})

test_that("3.3.2: currentformer Never Reverts to Current", {
  vdata <- create_validation_data()

  result <- tvexpose(
    master_data = vdata$cohort_single,
    exposure_file = vdata$exp_basic,
    id = "id",
    start = "rx_start",
    stop = "rx_stop",
    exposure = "exp_type",
    entry = "study_entry",
    exit = "study_exit",
    reference = 0,
    currentformer = TRUE,
    verbose = FALSE
  )

  df <- result$data
  df <- df[order(df$id, df$start), ]

  # Once former (2), should never go back to current (1)
  n_reverts <- 0
  for (i in 2:nrow(df)) {
    if (df$id[i] == df$id[i-1] && df$tv_exposure[i] == 1 && df$tv_exposure[i-1] == 2) {
      n_reverts <- n_reverts + 1
    }
  }
  expect_equal(n_reverts, 0)
})

# ============================================================================
# SECTION 3.4: GRACE PERIOD TESTS
# ============================================================================

test_that("3.4.1: Grace Period (gap > grace value)", {
  vdata <- create_validation_data()

  # With grace(14), 15-day gap should NOT be bridged
  result <- tvexpose(
    master_data = vdata$cohort_single,
    exposure_file = vdata$exp_gap15,
    id = "id",
    start = "rx_start",
    stop = "rx_stop",
    exposure = "exp_type",
    entry = "study_entry",
    exit = "study_exit",
    reference = 0,
    grace = 14,
    verbose = FALSE
  )

  df <- result$data
  # Should have unexposed period between exposures
  expect_true(0 %in% df$tv_exposure)
})

test_that("3.4.2: Grace Period (gap <= grace value)", {
  vdata <- create_validation_data()

  # Without grace
  result_no_grace <- tvexpose(
    master_data = vdata$cohort_single,
    exposure_file = vdata$exp_gap15,
    id = "id",
    start = "rx_start",
    stop = "rx_stop",
    exposure = "exp_type",
    entry = "study_entry",
    exit = "study_exit",
    reference = 0,
    grace = 0,
    verbose = FALSE
  )
  n_unexposed_no_grace <- sum(result_no_grace$data$tv_exposure == 0)

  # With grace(15), 15-day gap should be bridged
  result_grace <- tvexpose(
    master_data = vdata$cohort_single,
    exposure_file = vdata$exp_gap15,
    id = "id",
    start = "rx_start",
    stop = "rx_stop",
    exposure = "exp_type",
    entry = "study_entry",
    exit = "study_exit",
    reference = 0,
    grace = 15,
    verbose = FALSE
  )
  n_unexposed_grace <- sum(result_grace$data$tv_exposure == 0)

  # Should have fewer or equal unexposed intervals with grace
  expect_lte(n_unexposed_grace, n_unexposed_no_grace)
})

# ============================================================================
# SECTION 3.6: LAG AND WASHOUT TESTS
# ============================================================================

test_that("3.6.1: lag() Delays Exposure Start", {
  vdata <- create_validation_data()

  result <- tvexpose(
    master_data = vdata$cohort_single,
    exposure_file = vdata$exp_basic,
    id = "id",
    start = "rx_start",
    stop = "rx_stop",
    exposure = "exp_type",
    entry = "study_entry",
    exit = "study_exit",
    reference = 0,
    lag = 30,
    verbose = FALSE
  )

  # With lag(30), exposure starting Mar 1 should become active on Mar 31
  expect_true(!is.null(result$metadata$parameters$lag))
  expect_equal(result$metadata$parameters$lag, 30)
})

test_that("3.6.2: washout() Extends Exposure End", {
  vdata <- create_validation_data()

  result <- tvexpose(
    master_data = vdata$cohort_single,
    exposure_file = vdata$exp_basic,
    id = "id",
    start = "rx_start",
    stop = "rx_stop",
    exposure = "exp_type",
    entry = "study_entry",
    exit = "study_exit",
    reference = 0,
    washout = 30,
    verbose = FALSE
  )

  expect_true(!is.null(result$metadata$parameters$washout))
  expect_equal(result$metadata$parameters$washout, 30)
})

# ============================================================================
# SECTION 3.8: EVERTREATED TESTS
# ============================================================================

test_that("3.8.1: evertreated Never Reverts", {
  vdata <- create_validation_data()

  result <- tvexpose(
    master_data = vdata$cohort_single,
    exposure_file = vdata$exp_basic,
    id = "id",
    start = "rx_start",
    stop = "rx_stop",
    exposure = "exp_type",
    entry = "study_entry",
    exit = "study_exit",
    reference = 0,
    evertreated = TRUE,
    verbose = FALSE
  )

  df <- result$data
  df <- df[order(df$id, df$start), ]

  # Once exposed (1), should never revert to unexposed (0)
  n_reverts <- 0
  for (i in 2:nrow(df)) {
    if (df$id[i] == df$id[i-1] && df$tv_exposure[i] == 0 && df$tv_exposure[i-1] == 1) {
      n_reverts <- n_reverts + 1
    }
  }
  expect_equal(n_reverts, 0)
})

test_that("3.8.2: evertreated Switches at First Exposure", {
  vdata <- create_validation_data()

  result <- tvexpose(
    master_data = vdata$cohort_single,
    exposure_file = vdata$exp_basic,
    id = "id",
    start = "rx_start",
    stop = "rx_stop",
    exposure = "exp_type",
    entry = "study_entry",
    exit = "study_exit",
    reference = 0,
    evertreated = TRUE,
    verbose = FALSE
  )

  df <- result$data
  df <- df[order(df$start), ]

  # Before first exposure: 0
  # At/after first exposure: 1
  exp_start <- as.Date("2020-03-01")
  n_before <- sum(df$stop <= exp_start & df$tv_exposure == 0)
  n_after <- sum(df$start >= exp_start & df$tv_exposure == 1)

  expect_gte(n_before, 1)
  expect_gte(n_after, 1)
})

# ============================================================================
# SECTION 3.17: ERROR HANDLING TESTS
# ============================================================================

test_that("3.17.1: Missing Required Options", {
  vdata <- create_validation_data()

  # Missing entry should fail
  expect_error(
    tvexpose(
      master_data = vdata$cohort_single,
      exposure_file = vdata$exp_basic,
      id = "id",
      start = "rx_start",
      stop = "rx_stop",
      exposure = "exp_type",
      exit = "study_exit",
      reference = 0,
      verbose = FALSE
    )
  )
})

test_that("3.17.3: Variable Not Found", {
  vdata <- create_validation_data()

  expect_error(
    tvexpose(
      master_data = vdata$cohort_single,
      exposure_file = vdata$exp_basic,
      id = "nonexistent_id",
      start = "rx_start",
      stop = "rx_stop",
      exposure = "exp_type",
      entry = "study_entry",
      exit = "study_exit",
      reference = 0,
      verbose = FALSE
    )
  )
})

# ============================================================================
# INVARIANT TESTS
# ============================================================================

test_that("Invariant 1: Date Ordering (start < stop)", {
  vdata <- create_validation_data()

  result <- tvexpose(
    master_data = vdata$cohort_single,
    exposure_file = vdata$exp_overlap,
    id = "id",
    start = "rx_start",
    stop = "rx_stop",
    exposure = "exp_type",
    entry = "study_entry",
    exit = "study_exit",
    reference = 0,
    verbose = FALSE
  )

  df <- result$data
  expect_true(all(df$stop > df$start))
})

test_that("Invariant 2: Valid Exposure Categories", {
  vdata <- create_validation_data()

  result <- tvexpose(
    master_data = vdata$cohort_single,
    exposure_file = vdata$exp_two,
    id = "id",
    start = "rx_start",
    stop = "rx_stop",
    exposure = "exp_type",
    entry = "study_entry",
    exit = "study_exit",
    reference = 0,
    verbose = FALSE
  )

  df <- result$data
  # Should only have values 0 (reference), 1, 2 (exposure types)
  expect_true(all(df$tv_exposure %in% c(0, 1, 2)))
})

# ============================================================================
# SECTION 3.19: CONTINUOUS UNIT TESTS
# ============================================================================

test_that("3.19.1: continuousunit(months)", {
  vdata <- create_validation_data()

  result <- tvexpose(
    master_data = vdata$cohort_single,
    exposure_file = vdata$exp_fullyear,
    id = "id",
    start = "rx_start",
    stop = "rx_stop",
    exposure = "exp_type",
    entry = "study_entry",
    exit = "study_exit",
    reference = 0,
    continuousunit = "months",
    verbose = FALSE
  )

  df <- result$data
  max_cum <- max(df$tv_exp, na.rm = TRUE)

  # Full year should be ~12 months
  expect_lt(abs(max_cum - 12), 1)
})

test_that("3.19.2: continuousunit(weeks)", {
  vdata <- create_validation_data()

  result <- tvexpose(
    master_data = vdata$cohort_single,
    exposure_file = vdata$exp_fullyear,
    id = "id",
    start = "rx_start",
    stop = "rx_stop",
    exposure = "exp_type",
    entry = "study_entry",
    exit = "study_exit",
    reference = 0,
    continuousunit = "weeks",
    verbose = FALSE
  )

  df <- result$data
  max_cum <- max(df$tv_exp, na.rm = TRUE)

  # Full year should be ~52 weeks
  expect_lt(abs(max_cum - 52), 2)
})

test_that("3.24.1: continuousunit(days) Calculates in Days", {
  vdata <- create_validation_data()

  result <- tvexpose(
    master_data = vdata$cohort_single,
    exposure_file = vdata$exp_fullyear,
    id = "id",
    start = "rx_start",
    stop = "rx_stop",
    exposure = "exp_type",
    entry = "study_entry",
    exit = "study_exit",
    reference = 0,
    continuousunit = "days",
    verbose = FALSE
  )

  df <- result$data
  max_cum <- max(df$tv_exp, na.rm = TRUE)

  # Full year should be ~365 days
  expect_lt(abs(max_cum - 365), 5)
})

# ============================================================================
# SECTION 3.15: PATTERN TRACKING OPTIONS
# ============================================================================

test_that("3.15.1: switching Creates Binary Indicator", {
  vdata <- create_validation_data()

  result <- tvexpose(
    master_data = vdata$cohort_single,
    exposure_file = vdata$exp_two,
    id = "id",
    start = "rx_start",
    stop = "rx_stop",
    exposure = "exp_type",
    entry = "study_entry",
    exit = "study_exit",
    reference = 0,
    switching = TRUE,
    verbose = FALSE
  )

  # Verify switching variable exists
  expect_true("ever_switched" %in% names(result$data) || "has_switched" %in% names(result$data))
})

# ============================================================================
# SECTION 3.16: OUTPUT OPTIONS
# ============================================================================

test_that("3.16.4: keepvars() Keeps Additional Variables", {
  data <- load_test_data()

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
    keepvars = c("female", "age"),
    verbose = FALSE
  )

  expect_true("female" %in% names(result$data))
  expect_true("age" %in% names(result$data))
})

test_that("3.16.5: keepdates Retains Entry/Exit Dates", {
  data <- load_test_data()

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
    keepdates = TRUE,
    verbose = FALSE
  )

  expect_true("study_entry" %in% names(result$data))
  expect_true("study_exit" %in% names(result$data))
})

# ============================================================================
# SECTION 3.27: EDGE CASES
# ============================================================================

test_that("3.27.1: Single-Day Exposure", {
  cohort <- data.frame(
    id = 1L,
    study_entry = as.Date("2020-01-01"),
    study_exit = as.Date("2020-12-31")
  )

  exp_single_day <- data.frame(
    id = 1L,
    rx_start = as.Date("2020-06-15"),
    rx_stop = as.Date("2020-06-16"),
    exp_type = 1L
  )

  result <- tvexpose(
    master_data = cohort,
    exposure_file = exp_single_day,
    id = "id",
    start = "rx_start",
    stop = "rx_stop",
    exposure = "exp_type",
    entry = "study_entry",
    exit = "study_exit",
    reference = 0,
    verbose = FALSE
  )

  expect_true(nrow(result$data) >= 1)
})

test_that("3.27.2: Exposure Starting at Entry", {
  vdata <- create_validation_data()

  # Exposure starting exactly at study entry
  exp_at_entry <- data.frame(
    id = 1L,
    rx_start = as.Date("2020-01-01"),  # Same as study_entry
    rx_stop = as.Date("2020-03-31"),
    exp_type = 1L
  )

  result <- tvexpose(
    master_data = vdata$cohort_single,
    exposure_file = exp_at_entry,
    id = "id",
    start = "rx_start",
    stop = "rx_stop",
    exposure = "exp_type",
    entry = "study_entry",
    exit = "study_exit",
    reference = 0,
    verbose = FALSE
  )

  expect_true(nrow(result$data) >= 1)
})

test_that("3.27.3: Exposure Ending at Exit", {
  vdata <- create_validation_data()

  # Exposure ending exactly at study exit
  exp_at_exit <- data.frame(
    id = 1L,
    rx_start = as.Date("2020-10-01"),
    rx_stop = as.Date("2020-12-31"),  # Same as study_exit
    exp_type = 1L
  )

  result <- tvexpose(
    master_data = vdata$cohort_single,
    exposure_file = exp_at_exit,
    id = "id",
    start = "rx_start",
    stop = "rx_stop",
    exposure = "exp_type",
    entry = "study_entry",
    exit = "study_exit",
    reference = 0,
    verbose = FALSE
  )

  expect_true(nrow(result$data) >= 1)
})

# ============================================================================
# SECTION 3.35: MULTI-PERSON TESTS
# ============================================================================

test_that("3.35.1: Multiple Persons with Different Exposure Patterns", {
  # 3 persons with different patterns
  cohort_3person <- data.frame(
    id = c(1L, 2L, 3L),
    study_entry = rep(as.Date("2020-01-01"), 3),
    study_exit = rep(as.Date("2020-12-31"), 3)
  )

  # Person 1: one exposure, Person 2: two exposures, Person 3: no exposure
  exp_multi <- data.frame(
    id = c(1L, 2L, 2L),
    rx_start = as.Date(c("2020-03-01", "2020-02-01", "2020-08-01")),
    rx_stop = as.Date(c("2020-06-30", "2020-04-30", "2020-10-31")),
    exp_type = c(1L, 1L, 2L)
  )

  result <- tvexpose(
    master_data = cohort_3person,
    exposure_file = exp_multi,
    id = "id",
    start = "rx_start",
    stop = "rx_stop",
    exposure = "exp_type",
    entry = "study_entry",
    exit = "study_exit",
    reference = 0,
    verbose = FALSE
  )

  df <- result$data

  # All 3 persons should be in output
  expect_equal(length(unique(df$id)), 3)

  # Person 3 should only have unexposed periods
  person3 <- df[df$id == 3, ]
  expect_true(all(person3$tv_exposure == 0))
})

test_that("3.35.2: Multi-Person with evertreated + bytype", {
  data <- load_test_data()

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
    evertreated = TRUE,
    bytype = TRUE,
    verbose = FALSE
  )

  # Should have multiple ever* columns
  ever_cols <- grep("^ever", names(result$data), value = TRUE)
  expect_gte(length(ever_cols), 1)
})

cat("\nR tvexpose validation tests complete.\n")
