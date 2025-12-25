# Comprehensive tests for tvmerge R implementation
# Based on Stata test suite from _testing/test_tvmerge.do

library(testthat)
library(tvtools)

# Test data path - use RDS files
data_path <- "/home/tpcopeland/Stata-Tools/_reimplementations/data/R"

# Helper function to load and create test data
load_test_data <- function() {
  cohort <- readRDS(file.path(data_path, "cohort.rds"))
  hrt <- readRDS(file.path(data_path, "hrt.rds"))
  dmt <- readRDS(file.path(data_path, "dmt.rds"))
  list(cohort = cohort, hrt = hrt, dmt = dmt)
}

# Helper to create tvexpose outputs for merge testing
create_merge_inputs <- function(data) {
  # Create first exposure dataset
  result1 <- tvexpose(
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

  # Create second exposure dataset
  result2 <- tvexpose(
    master_data = data$cohort,
    exposure_file = data$dmt,
    id = "id",
    start = "dmt_start",
    stop = "dmt_stop",
    exposure = "dmt",
    entry = "study_entry",
    exit = "study_exit",
    reference = 0,
    generate = "dmt_exp",
    verbose = FALSE
  )

  list(ds1 = result1$data, ds2 = result2$data)
}

# ============================================================================
# TEST 1: Basic Two-Dataset Merge
# ============================================================================
test_that("tvmerge performs basic two-dataset merge", {
  data <- load_test_data()
  inputs <- create_merge_inputs(data)

  result <- tvmerge(
    datasets = list(inputs$ds1, inputs$ds2),
    id = "id",
    start = c("start", "start"),
    stop = c("stop", "stop"),
    exposure = c("hrt_exp", "dmt_exp")
  )

  expect_true(is.list(result))
  expect_true("data" %in% names(result))
  expect_true(nrow(result$data) > 0)
  expect_true("hrt_exp" %in% names(result$data))
  expect_true("dmt_exp" %in% names(result$data))
  expect_true("start" %in% names(result$data))
  expect_true("stop" %in% names(result$data))
})

# ============================================================================
# TEST 2: Generate Option
# ============================================================================
test_that("tvmerge generate option renames exposure variables", {
  data <- load_test_data()
  inputs <- create_merge_inputs(data)

  result <- tvmerge(
    datasets = list(inputs$ds1, inputs$ds2),
    id = "id",
    start = c("start", "start"),
    stop = c("stop", "stop"),
    exposure = c("hrt_exp", "dmt_exp"),
    generate = c("hormone", "drug")
  )

  expect_true("hormone" %in% names(result$data))
  expect_true("drug" %in% names(result$data))
})

# ============================================================================
# TEST 3: Prefix Option
# ============================================================================
test_that("tvmerge prefix option works", {
  data <- load_test_data()
  inputs <- create_merge_inputs(data)

  result <- tvmerge(
    datasets = list(inputs$ds1, inputs$ds2),
    id = "id",
    start = c("start", "start"),
    stop = c("stop", "stop"),
    exposure = c("hrt_exp", "dmt_exp"),
    prefix = "tv_"
  )

  expect_true("tv_hrt_exp" %in% names(result$data))
  expect_true("tv_dmt_exp" %in% names(result$data))
})

# ============================================================================
# TEST 4: Continuous Exposure Interpolation
# ============================================================================
test_that("tvmerge continuous option interpolates properly", {
  # Create simple test data with continuous exposure
  ds1 <- data.frame(
    id = c(1, 1),
    start = c(1, 11),
    stop = c(10, 20),
    exp1 = c("A", "B")
  )

  ds2 <- data.frame(
    id = c(1),
    start = c(1),
    stop = c(20),
    dosage = c(100)
  )

  result <- tvmerge(
    datasets = list(ds1, ds2),
    id = "id",
    start = c("start", "start"),
    stop = c("stop", "stop"),
    exposure = c("exp1", "dosage"),
    continuous = c(2),
    generate = c("category", "dose")
  )

  expect_true(is.list(result))
  # Dose should be interpolated based on overlap
  expect_true("dose" %in% names(result$data))
  # Each interval should have ~50 (100 * 10/20)
  expect_true(all(abs(result$data$dose - 50) < 1))
})

# ============================================================================
# TEST 5: Start/Stop Name Options
# ============================================================================
test_that("tvmerge startname and stopname options work", {
  data <- load_test_data()
  inputs <- create_merge_inputs(data)

  result <- tvmerge(
    datasets = list(inputs$ds1, inputs$ds2),
    id = "id",
    start = c("start", "start"),
    stop = c("stop", "stop"),
    exposure = c("hrt_exp", "dmt_exp"),
    startname = "begin",
    stopname = "end"
  )

  expect_true("begin" %in% names(result$data))
  expect_true("end" %in% names(result$data))
})

# ============================================================================
# TEST 6: Force Option (ID Mismatch)
# ============================================================================
test_that("tvmerge force option handles ID mismatch", {
  ds1 <- data.frame(
    id = c(1, 2),
    start = c(1, 1),
    stop = c(10, 10),
    exp1 = c("A", "B")
  )

  ds2 <- data.frame(
    id = c(2, 3),
    start = c(1, 1),
    stop = c(10, 10),
    exp2 = c("X", "Y")
  )

  # Without force, should warn/error
  result <- tvmerge(
    datasets = list(ds1, ds2),
    id = "id",
    start = c("start", "start"),
    stop = c("stop", "stop"),
    exposure = c("exp1", "exp2"),
    force = TRUE
  )

  # Only ID 2 should be in result
  expect_equal(unique(result$data$id), 2)
})

# ============================================================================
# TEST 7: Check Option
# ============================================================================
test_that("tvmerge check option displays diagnostics", {
  data <- load_test_data()
  inputs <- create_merge_inputs(data)

  # Should not error
  expect_error(
    tvmerge(
      datasets = list(inputs$ds1, inputs$ds2),
      id = "id",
      start = c("start", "start"),
      stop = c("stop", "stop"),
      exposure = c("hrt_exp", "dmt_exp"),
      check = TRUE
    ),
    NA
  )
})

# ============================================================================
# TEST 8: ValidateCoverage Option
# ============================================================================
test_that("tvmerge validatecoverage option works", {
  data <- load_test_data()
  inputs <- create_merge_inputs(data)

  result <- tvmerge(
    datasets = list(inputs$ds1, inputs$ds2),
    id = "id",
    start = c("start", "start"),
    stop = c("stop", "stop"),
    exposure = c("hrt_exp", "dmt_exp"),
    validatecoverage = TRUE
  )

  expect_true(!is.null(result$diagnostics$coverage_validation))
})

# ============================================================================
# TEST 9: ValidateOverlap Option
# ============================================================================
test_that("tvmerge validateoverlap option works", {
  data <- load_test_data()
  inputs <- create_merge_inputs(data)

  result <- tvmerge(
    datasets = list(inputs$ds1, inputs$ds2),
    id = "id",
    start = c("start", "start"),
    stop = c("stop", "stop"),
    exposure = c("hrt_exp", "dmt_exp"),
    validateoverlap = TRUE
  )

  expect_true("overlap_validation" %in% names(result$diagnostics))
})

# ============================================================================
# TEST 10: Batch Processing
# ============================================================================
test_that("tvmerge batch option controls batch size", {
  data <- load_test_data()
  inputs <- create_merge_inputs(data)

  # Should work with different batch sizes
  result1 <- tvmerge(
    datasets = list(inputs$ds1, inputs$ds2),
    id = "id",
    start = c("start", "start"),
    stop = c("stop", "stop"),
    exposure = c("hrt_exp", "dmt_exp"),
    batch = 10
  )

  result2 <- tvmerge(
    datasets = list(inputs$ds1, inputs$ds2),
    id = "id",
    start = c("start", "start"),
    stop = c("stop", "stop"),
    exposure = c("hrt_exp", "dmt_exp"),
    batch = 50
  )

  # Results should be the same regardless of batch size
  expect_equal(nrow(result1$data), nrow(result2$data))
})

# ============================================================================
# TEST 11: Point-in-Time Observations
# ============================================================================
test_that("tvmerge handles point-in-time observations", {
  ds1 <- data.frame(
    id = c(1, 1),
    start = c(1, 10),
    stop = c(5, 10),  # Day 10 is point-in-time
    exp1 = c("A", "B")
  )

  ds2 <- data.frame(
    id = c(1),
    start = c(1),
    stop = c(15),
    exp2 = c("X")
  )

  result <- tvmerge(
    datasets = list(ds1, ds2),
    id = "id",
    start = c("start", "start"),
    stop = c("stop", "stop"),
    exposure = c("exp1", "exp2")
  )

  # Should handle single-day interval
  expect_true(nrow(result$data) > 0)
})

# ============================================================================
# TEST 12: Returns Structure
# ============================================================================
test_that("tvmerge returns proper structure", {
  data <- load_test_data()
  inputs <- create_merge_inputs(data)

  result <- tvmerge(
    datasets = list(inputs$ds1, inputs$ds2),
    id = "id",
    start = c("start", "start"),
    stop = c("stop", "stop"),
    exposure = c("hrt_exp", "dmt_exp")
  )

  expect_true("returns" %in% names(result))
  expect_true("N" %in% names(result$returns))
  expect_true("N_persons" %in% names(result$returns))
  expect_true("N_datasets" %in% names(result$returns))
  expect_true("exposure_vars" %in% names(result$returns))
})

# ============================================================================
# Run all tests
# ============================================================================
cat("\nRunning tvmerge tests...\n")
