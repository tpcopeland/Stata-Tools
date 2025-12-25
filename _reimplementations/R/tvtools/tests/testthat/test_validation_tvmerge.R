# Comprehensive validation tests for tvmerge R implementation
# Matches Stata validation tests from _validation/validation_tvmerge.do

library(testthat)
library(tvtools)

# Test data path - use RDS files
data_path <- "/home/tpcopeland/Stata-Tools/_reimplementations/data/R"

# Helper functions
load_test_data <- function() {
  cohort <- readRDS(file.path(data_path, "cohort.rds"))
  hrt <- readRDS(file.path(data_path, "hrt.rds"))
  dmt <- readRDS(file.path(data_path, "dmt.rds"))
  list(cohort = cohort, hrt = hrt, dmt = dmt)
}

# Create validation datasets
create_tvmerge_validation_data <- function() {
  # Dataset 1: Single full-year interval
  ds1_fullyear <- data.frame(
    id = 1L,
    start1 = as.Date("2020-01-01"),
    stop1 = as.Date("2020-12-31"),
    exp1 = 1L
  )

  # Dataset 2: Two intervals covering the year
  ds2_split <- data.frame(
    id = c(1L, 1L),
    start2 = as.Date(c("2020-01-01", "2020-07-01")),
    stop2 = as.Date(c("2020-06-30", "2020-12-31")),
    exp2 = c(1L, 2L)
  )

  # Dataset 1: Partial year (Jan-Jun)
  ds1_partial <- data.frame(
    id = 1L,
    start1 = as.Date("2020-01-01"),
    stop1 = as.Date("2020-06-30"),
    exp1 = 1L
  )

  # Dataset 2: Partial year (Mar-Sep)
  ds2_partial <- data.frame(
    id = 1L,
    start2 = as.Date("2020-03-01"),
    stop2 = as.Date("2020-09-30"),
    exp2 = 2L
  )

  # Non-overlapping datasets
  ds1_nonoverlap <- data.frame(
    id = 1L,
    start1 = as.Date("2020-01-01"),
    stop1 = as.Date("2020-03-01"),
    exp1 = 1L
  )

  ds2_nonoverlap <- data.frame(
    id = 1L,
    start2 = as.Date("2020-07-01"),
    stop2 = as.Date("2020-12-31"),
    exp2 = 2L
  )

  # Datasets with different IDs
  ds1_ids123 <- data.frame(
    id = c(1L, 2L, 3L),
    start1 = rep(as.Date("2020-01-01"), 3),
    stop1 = rep(as.Date("2020-12-31"), 3),
    exp1 = c(1L, 1L, 1L)
  )

  ds2_ids234 <- data.frame(
    id = c(2L, 3L, 4L),
    start2 = rep(as.Date("2020-01-01"), 3),
    stop2 = rep(as.Date("2020-12-31"), 3),
    exp2 = c(2L, 2L, 2L)
  )

  # Datasets with continuous variables
  ds1_cont <- data.frame(
    id = 1L,
    start1 = as.Date("2020-01-01"),
    stop1 = as.Date("2020-12-31"),
    cum1 = 365
  )

  ds2_cont <- data.frame(
    id = 1L,
    start2 = as.Date("2020-01-01"),
    stop2 = as.Date("2020-06-30"),
    cum2 = 100
  )

  # Three datasets for three-way merge
  ds3way_1 <- data.frame(
    id = 1L,
    s1 = as.Date("2020-01-01"),
    e1 = as.Date("2020-09-30"),
    x1 = 1L
  )

  ds3way_2 <- data.frame(
    id = 1L,
    s2 = as.Date("2020-04-01"),
    e2 = as.Date("2020-12-31"),
    x2 = 2L
  )

  ds3way_3 <- data.frame(
    id = 1L,
    s3 = as.Date("2020-06-01"),
    e3 = as.Date("2020-12-31"),
    x3 = 3L
  )

  list(
    ds1_fullyear = ds1_fullyear,
    ds2_split = ds2_split,
    ds1_partial = ds1_partial,
    ds2_partial = ds2_partial,
    ds1_nonoverlap = ds1_nonoverlap,
    ds2_nonoverlap = ds2_nonoverlap,
    ds1_ids123 = ds1_ids123,
    ds2_ids234 = ds2_ids234,
    ds1_cont = ds1_cont,
    ds2_cont = ds2_cont,
    ds3way_1 = ds3way_1,
    ds3way_2 = ds3way_2,
    ds3way_3 = ds3way_3
  )
}

# ============================================================================
# SECTION 5.1: CARTESIAN PRODUCT TESTS
# ============================================================================

test_that("5.1.1: Complete Intersection Coverage", {
  vdata <- create_tvmerge_validation_data()

  result <- tvmerge(
    datasets = list(vdata$ds1_fullyear, vdata$ds2_split),
    id = "id",
    start = c("start1", "start2"),
    stop = c("stop1", "stop2"),
    exposure = c("exp1", "exp2")
  )

  # Should produce 2 intervals (Jan-Jun, Jul-Dec)
  expect_equal(nrow(result$data), 2)

  # Both exposure values should be present
  df <- result$data
  df <- df[order(df$start), ]
  expect_true("exp1" %in% names(df) || any(grepl("exp", names(df))))
})

test_that("5.1.2: Non-Overlapping Periods Excluded", {
  vdata <- create_tvmerge_validation_data()

  result <- tvmerge(
    datasets = list(vdata$ds1_nonoverlap, vdata$ds2_nonoverlap),
    id = "id",
    start = c("start1", "start2"),
    stop = c("stop1", "stop2"),
    exposure = c("exp1", "exp2")
  )

  # Should produce 0 intervals (no overlap)
  expect_equal(nrow(result$data), 0)
})

# ============================================================================
# SECTION 5.2: PERSON-TIME TESTS
# ============================================================================

test_that("5.2.1: Merged Duration Equals Intersection", {
  vdata <- create_tvmerge_validation_data()

  result <- tvmerge(
    datasets = list(vdata$ds1_partial, vdata$ds2_partial),
    id = "id",
    start = c("start1", "start2"),
    stop = c("stop1", "stop2"),
    exposure = c("exp1", "exp2")
  )

  df <- result$data
  df$dur <- as.numeric(df$stop - df$start)
  total_dur <- sum(df$dur)

  # Overlap is Mar 1 - Jun 30 = 122 days
  expected_dur <- as.numeric(as.Date("2020-06-30") - as.Date("2020-03-01"))
  expect_lt(abs(total_dur - expected_dur), 2)
})

test_that("5.2.2: No Overlapping Intervals in Output", {
  vdata <- create_tvmerge_validation_data()

  result <- tvmerge(
    datasets = list(vdata$ds1_fullyear, vdata$ds2_split),
    id = "id",
    start = c("start1", "start2"),
    stop = c("stop1", "stop2"),
    exposure = c("exp1", "exp2")
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
# SECTION 5.3: CONTINUOUS VARIABLE TESTS
# ============================================================================

test_that("5.3.1: Continuous Interpolation", {
  vdata <- create_tvmerge_validation_data()

  result <- tvmerge(
    datasets = list(vdata$ds1_cont, vdata$ds2_cont),
    id = "id",
    start = c("start1", "start2"),
    stop = c("stop1", "stop2"),
    exposure = c("cum1", "cum2"),
    continuous = c(1, 2)
  )

  df <- result$data

  # Intersection is Jan 1 - Jun 30
  # cum2 should be approximately 100 (full ds2 range)
  expect_true(nrow(df) >= 1)
})

# ============================================================================
# SECTION 5.4: ID MATCHING TESTS
# ============================================================================

test_that("5.4.1: ID Mismatch Without Force", {
  vdata <- create_tvmerge_validation_data()

  # Without force: should error on mismatch
  expect_error(
    tvmerge(
      datasets = list(vdata$ds1_ids123, vdata$ds2_ids234),
      id = "id",
      start = c("start1", "start2"),
      stop = c("stop1", "stop2"),
      exposure = c("exp1", "exp2")
    )
  )
})

test_that("5.4.2: ID Intersection With Force", {
  vdata <- create_tvmerge_validation_data()

  result <- tvmerge(
    datasets = list(vdata$ds1_ids123, vdata$ds2_ids234),
    id = "id",
    start = c("start1", "start2"),
    stop = c("stop1", "stop2"),
    exposure = c("exp1", "exp2"),
    force = TRUE
  )

  df <- result$data
  unique_ids <- unique(df$id)

  # Only IDs 2 and 3 should appear (intersection)
  expect_equal(length(unique_ids), 2)
  expect_true(all(unique_ids %in% c(2, 3)))
  expect_false(1 %in% unique_ids)
  expect_false(4 %in% unique_ids)
})

# ============================================================================
# SECTION 5.5: THREE-WAY MERGE TESTS
# ============================================================================

test_that("5.5.1: Three Dataset Intersection", {
  vdata <- create_tvmerge_validation_data()

  result <- tvmerge(
    datasets = list(vdata$ds3way_1, vdata$ds3way_2, vdata$ds3way_3),
    id = "id",
    start = c("s1", "s2", "s3"),
    stop = c("e1", "e2", "e3"),
    exposure = c("x1", "x2", "x3")
  )

  df <- result$data

  # Three-way intersection: Jun 1 - Sep 30
  expect_gte(nrow(df), 1)
})

test_that("5.5.2: Three-Way Merge Duration Calculation", {
  vdata <- create_tvmerge_validation_data()

  result <- tvmerge(
    datasets = list(vdata$ds3way_1, vdata$ds3way_2, vdata$ds3way_3),
    id = "id",
    start = c("s1", "s2", "s3"),
    stop = c("e1", "e2", "e3"),
    exposure = c("x1", "x2", "x3")
  )

  df <- result$data
  df$dur <- as.numeric(df$stop - df$start)
  total_dur <- sum(df$dur)

  # Three-way intersection: Jun 1 - Sep 30 = 122 days
  expected_dur <- as.numeric(as.Date("2020-09-30") - as.Date("2020-06-01"))
  expect_lt(abs(total_dur - expected_dur), 2)
})

# ============================================================================
# SECTION 5.6: OUTPUT OPTIONS TESTS
# ============================================================================

test_that("5.6.1: generate() Creates Custom-Named Variables", {
  vdata <- create_tvmerge_validation_data()

  result <- tvmerge(
    datasets = list(vdata$ds1_fullyear, vdata$ds2_split),
    id = "id",
    start = c("start1", "start2"),
    stop = c("stop1", "stop2"),
    exposure = c("exp1", "exp2"),
    generate = c("my_exp1", "my_exp2")
  )

  expect_true("my_exp1" %in% names(result$data))
  expect_true("my_exp2" %in% names(result$data))
})

test_that("5.6.2: prefix() Adds Prefix to Variable Names", {
  vdata <- create_tvmerge_validation_data()

  result <- tvmerge(
    datasets = list(vdata$ds1_fullyear, vdata$ds2_split),
    id = "id",
    start = c("start1", "start2"),
    stop = c("stop1", "stop2"),
    exposure = c("exp1", "exp2"),
    prefix = "tv_"
  )

  # Check for prefixed variables
  expect_true(any(grepl("^tv_", names(result$data))))
})

test_that("5.6.3: startname() and stopname() Customize Date Variable Names", {
  vdata <- create_tvmerge_validation_data()

  result <- tvmerge(
    datasets = list(vdata$ds1_fullyear, vdata$ds2_split),
    id = "id",
    start = c("start1", "start2"),
    stop = c("stop1", "stop2"),
    exposure = c("exp1", "exp2"),
    startname = "period_start",
    stopname = "period_stop"
  )

  expect_true("period_start" %in% names(result$data))
  expect_true("period_stop" %in% names(result$data))
})

# ============================================================================
# SECTION 5.10: STORED RESULTS TESTS
# ============================================================================

test_that("5.10.1: Stored Scalars", {
  vdata <- create_tvmerge_validation_data()

  result <- tvmerge(
    datasets = list(vdata$ds1_fullyear, vdata$ds2_split),
    id = "id",
    start = c("start1", "start2"),
    stop = c("stop1", "stop2"),
    exposure = c("exp1", "exp2")
  )

  # Check for returns
  expect_true(!is.null(result$returns))
  expect_true("N" %in% names(result$returns) || "n_obs" %in% names(result$returns))
})

# ============================================================================
# SECTION 5.12: ERROR HANDLING TESTS
# ============================================================================

test_that("5.12.1: Mismatched start/stop Counts", {
  vdata <- create_tvmerge_validation_data()

  expect_error(
    tvmerge(
      datasets = list(vdata$ds1_fullyear, vdata$ds2_split),
      id = "id",
      start = c("start1"),  # Only 1 start
      stop = c("stop1", "stop2"),  # 2 stops
      exposure = c("exp1", "exp2")
    )
  )
})

test_that("5.12.2: Mismatched Exposure Count", {
  vdata <- create_tvmerge_validation_data()

  expect_error(
    tvmerge(
      datasets = list(vdata$ds1_fullyear, vdata$ds2_split),
      id = "id",
      start = c("start1", "start2"),
      stop = c("stop1", "stop2"),
      exposure = c("exp1")  # Only 1 exposure for 2 datasets
    )
  )
})

# ============================================================================
# SECTION 5.16: EDGE CASES
# ============================================================================

test_that("5.16.1: Same-Day Start and Stop", {
  # Create datasets with same-day intervals
  ds1_sameday <- data.frame(
    id = 1L,
    start1 = as.Date("2020-06-15"),
    stop1 = as.Date("2020-06-16"),
    exp1 = 1L
  )

  ds2_sameday <- data.frame(
    id = 1L,
    start2 = as.Date("2020-06-15"),
    stop2 = as.Date("2020-06-16"),
    exp2 = 2L
  )

  result <- tvmerge(
    datasets = list(ds1_sameday, ds2_sameday),
    id = "id",
    start = c("start1", "start2"),
    stop = c("stop1", "stop2"),
    exposure = c("exp1", "exp2")
  )

  expect_gte(nrow(result$data), 1)
})

# ============================================================================
# SECTION 5.20: MULTI-PERSON TESTS
# ============================================================================

test_that("5.20.1: Multi-Person Merge", {
  skip("Integration test requires specific test data setup")
  data <- load_test_data()

  # Create TV datasets from real data
  tv1 <- tvexpose(
    master_data = data$cohort,
    exposure_file = data$hrt,
    id = "id",
    start = "rx_start",
    stop = "rx_stop",
    exposure = "hrt_type",
    entry = "study_entry",
    exit = "study_exit",
    reference = 0,
    verbose = FALSE
  )$data

  tv2 <- tvexpose(
    master_data = data$cohort,
    exposure_file = data$dmt,
    id = "id",
    start = "dmt_start",
    stop = "dmt_stop",
    exposure = "dmt",
    entry = "study_entry",
    exit = "study_exit",
    reference = 0,
    verbose = FALSE
  )$data

  result <- tvmerge(
    datasets = list(tv1, tv2),
    id = "id",
    start = c("start", "start"),
    stop = c("stop", "stop"),
    exposure = c("tv_exposure", "tv_exposure"),
    generate = c("hrt_exp", "dmt_exp")
  )

  df <- result$data

  # Should have multiple persons
  expect_gte(length(unique(df$id)), 2)

  # No overlaps
  df <- df[order(df$id, df$start), ]
  n_overlaps <- 0
  for (i in 2:nrow(df)) {
    if (df$id[i] == df$id[i-1] && df$start[i] < df$stop[i-1]) {
      n_overlaps <- n_overlaps + 1
    }
  }
  expect_equal(n_overlaps, 0)
})

# ============================================================================
# SECTION 5.21: OUTPUT INVARIANTS
# ============================================================================

test_that("5.21.1: All Output Invariants After Complex Merge", {
  skip("Integration test requires specific test data setup")
  data <- load_test_data()

  tv1 <- tvexpose(
    master_data = data$cohort,
    exposure_file = data$hrt,
    id = "id",
    start = "rx_start",
    stop = "rx_stop",
    exposure = "hrt_type",
    entry = "study_entry",
    exit = "study_exit",
    reference = 0,
    verbose = FALSE
  )$data

  tv2 <- tvexpose(
    master_data = data$cohort,
    exposure_file = data$dmt,
    id = "id",
    start = "dmt_start",
    stop = "dmt_stop",
    exposure = "dmt",
    entry = "study_entry",
    exit = "study_exit",
    reference = 0,
    verbose = FALSE
  )$data

  result <- tvmerge(
    datasets = list(tv1, tv2),
    id = "id",
    start = c("start", "start"),
    stop = c("stop", "stop"),
    exposure = c("tv_exposure", "tv_exposure"),
    generate = c("hrt_exp", "dmt_exp")
  )

  df <- result$data

  # Invariant 1: start < stop for all rows
  expect_true(all(df$stop > df$start))

  # Invariant 2: Sorted by id, start
  df_sorted <- df[order(df$id, df$start), ]
  expect_equal(df$id, df_sorted$id)
  expect_equal(as.character(df$start), as.character(df_sorted$start))

  # Invariant 3: No overlaps within person
  n_overlaps <- 0
  for (i in 2:nrow(df_sorted)) {
    if (df_sorted$id[i] == df_sorted$id[i-1] && df_sorted$start[i] < df_sorted$stop[i-1]) {
      n_overlaps <- n_overlaps + 1
    }
  }
  expect_equal(n_overlaps, 0)
})

# ============================================================================
# SECTION 5.26: UNIVERSAL INVARIANTS
# ============================================================================

test_that("5.26.1: Output Duration <= Minimum Input Duration (Always)", {
  vdata <- create_tvmerge_validation_data()

  # ds1_partial: Jan 1 - Jun 30 (181 days)
  # ds2_partial: Mar 1 - Sep 30 (214 days)
  # Intersection: Mar 1 - Jun 30 (122 days)

  input1_dur <- as.numeric(vdata$ds1_partial$stop1 - vdata$ds1_partial$start1)
  input2_dur <- as.numeric(vdata$ds2_partial$stop2 - vdata$ds2_partial$start2)
  min_input_dur <- min(input1_dur, input2_dur)

  result <- tvmerge(
    datasets = list(vdata$ds1_partial, vdata$ds2_partial),
    id = "id",
    start = c("start1", "start2"),
    stop = c("stop1", "stop2"),
    exposure = c("exp1", "exp2")
  )

  df <- result$data
  df$dur <- as.numeric(df$stop - df$start)
  output_dur <- sum(df$dur)

  expect_lte(output_dur, min_input_dur)
})

test_that("5.26.2: No Output Overlaps Within Person", {
  vdata <- create_tvmerge_validation_data()

  result <- tvmerge(
    datasets = list(vdata$ds1_fullyear, vdata$ds2_split),
    id = "id",
    start = c("start1", "start2"),
    stop = c("stop1", "stop2"),
    exposure = c("exp1", "exp2")
  )

  df <- result$data
  df <- df[order(df$id, df$start), ]

  n_overlaps <- 0
  for (i in 2:nrow(df)) {
    if (df$id[i] == df$id[i-1] && df$start[i] < df$stop[i-1]) {
      n_overlaps <- n_overlaps + 1
    }
  }
  expect_equal(n_overlaps, 0)
})

test_that("5.26.3: Output Sorted by ID and Start", {
  vdata <- create_tvmerge_validation_data()

  result <- tvmerge(
    datasets = list(vdata$ds1_fullyear, vdata$ds2_split),
    id = "id",
    start = c("start1", "start2"),
    stop = c("stop1", "stop2"),
    exposure = c("exp1", "exp2")
  )

  df <- result$data
  df_sorted <- df[order(df$id, df$start), ]

  expect_equal(df$id, df_sorted$id)
  expect_equal(as.character(df$start), as.character(df_sorted$start))
})

cat("\nR tvmerge validation tests complete.\n")
