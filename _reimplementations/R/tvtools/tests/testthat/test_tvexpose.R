# Comprehensive tests for tvexpose R implementation
# Based on Stata test suite from _testing/test_tvexpose.do

library(testthat)
library(tvtools)
library(haven)

# Test data path
data_path <- "/home/ubuntu/Stata-Tools/_testing/data"

# Helper function to load test data
load_test_data <- function() {
  cohort <- read_dta(file.path(data_path, "cohort.dta"))
  hrt <- read_dta(file.path(data_path, "hrt.dta"))
  list(cohort = cohort, hrt = hrt)
}

# ============================================================================
# TEST 1: Basic Time-Varying Exposure
# ============================================================================
test_that("tvexpose creates basic time-varying exposure", {
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
    verbose = FALSE
  )

  expect_true(is.list(result))
  expect_true("data" %in% names(result))
  expect_true(nrow(result$data) > 0)
  expect_true("tv_exposure" %in% names(result$data))
  expect_true("start" %in% names(result$data))
  expect_true("stop" %in% names(result$data))
})

# ============================================================================
# TEST 2: Ever-Treated Option
# ============================================================================
test_that("tvexpose evertreated option works", {
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
    verbose = FALSE
  )

  expect_true(is.list(result))
  # Ever-treated should create binary 0/1 variable
  exposure_values <- unique(result$data$tv_exposure)
  expect_true(all(exposure_values %in% c(0, 1)))
})

# ============================================================================
# TEST 3: Current/Former Option
# ============================================================================
test_that("tvexpose currentformer option works", {
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
    currentformer = TRUE,
    verbose = FALSE
  )

  expect_true(is.list(result))
  # Current/former should create 0/1/2 variable
  exposure_values <- unique(result$data$tv_exposure)
  expect_true(all(exposure_values %in% c(0, 1, 2)))
})

# ============================================================================
# TEST 4: Lag Option
# ============================================================================
test_that("tvexpose lag option works", {
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
    lag = 30,
    verbose = FALSE
  )

  expect_true(is.list(result))
  expect_true(nrow(result$data) > 0)
  expect_equal(result$metadata$parameters$lag, 30)
})

# ============================================================================
# TEST 5: Washout Option
# ============================================================================
test_that("tvexpose washout option works", {
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
    washout = 90,
    verbose = FALSE
  )

  expect_true(is.list(result))
  expect_true(nrow(result$data) > 0)
  expect_equal(result$metadata$parameters$washout, 90)
})

# ============================================================================
# TEST 6: Grace Period Option
# ============================================================================
test_that("tvexpose grace option works", {
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
    grace = 14,
    verbose = FALSE
  )

  expect_true(is.list(result))
  expect_true(nrow(result$data) > 0)
})

# ============================================================================
# TEST 7: Duration Categories
# ============================================================================
test_that("tvexpose duration option works", {
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
    duration = c(1, 3, 5),
    continuousunit = "years",
    verbose = FALSE
  )

  expect_true(is.list(result))
  expect_true(nrow(result$data) > 0)
})

# ============================================================================
# TEST 8: Continuous Exposure
# ============================================================================
test_that("tvexpose continuousunit option works", {
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
    continuousunit = "years",
    verbose = FALSE
  )

  expect_true(is.list(result))
  expect_true(nrow(result$data) > 0)
  # Should have a continuous variable
  expect_true("tv_exp" %in% names(result$data))
})

# ============================================================================
# TEST 9: ByType Option with Ever-Treated
# ============================================================================
test_that("tvexpose bytype with evertreated works", {
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

  expect_true(is.list(result))
  expect_true(nrow(result$data) > 0)
  # Should have multiple ever* columns
  ever_cols <- grep("^ever", names(result$data), value = TRUE)
  expect_true(length(ever_cols) > 0)
})

# ============================================================================
# TEST 10: Custom Generate Name
# ============================================================================
test_that("tvexpose generate option works", {
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
    generate = "my_exposure",
    verbose = FALSE
  )

  expect_true(is.list(result))
  expect_true("my_exposure" %in% names(result$data))
})

# ============================================================================
# TEST 11: Recency Option
# ============================================================================
test_that("tvexpose recency option works", {
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
    recency = c(1, 5),
    verbose = FALSE
  )

  expect_true(is.list(result))
  expect_true(nrow(result$data) > 0)
})

# ============================================================================
# TEST 12: Overlap Handling - Layer
# ============================================================================
test_that("tvexpose layer overlap handling works", {
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
    layer = TRUE,
    verbose = FALSE
  )

  expect_true(is.list(result))
  expect_true(nrow(result$data) > 0)
  expect_equal(result$metadata$parameters$overlap_strategy, "layer")
})

# ============================================================================
# TEST 13: Switching Indicator
# ============================================================================
test_that("tvexpose switching option works", {
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
    switching = TRUE,
    verbose = FALSE
  )

  expect_true(is.list(result))
  expect_true("has_switched" %in% names(result$data))
})

# ============================================================================
# TEST 14: Diagnostics Option
# ============================================================================
test_that("tvexpose check option works", {
  data <- load_test_data()

  # Should not error
  expect_error(
    tvexpose(
      master_data = data$cohort,
      exposure_file = data$hrt,
      id = "id",
      start = "rx_start",
      stop = "rx_stop",
      exposure = "hrt_type",
      entry = "study_entry",
      exit = "study_exit",
      reference = 0,
      check = TRUE,
      verbose = FALSE
    ),
    NA
  )
})

# ============================================================================
# TEST 15: KeepDates Option
# ============================================================================
test_that("tvexpose keepdates option works", {
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
# TEST 16: Empty Exposure Data
# ============================================================================
test_that("tvexpose handles empty exposure data", {
  data <- load_test_data()

  # Create empty exposure data
  empty_hrt <- data$hrt[0, ]

  expect_error(
    tvexpose(
      master_data = data$cohort,
      exposure_file = empty_hrt,
      id = "id",
      start = "rx_start",
      stop = "rx_stop",
      exposure = "hrt_type",
      entry = "study_entry",
      exit = "study_exit",
      reference = 0,
      verbose = FALSE
    )
  )
})

# ============================================================================
# TEST 17: KeepVars Option
# ============================================================================
test_that("tvexpose keepvars option works", {
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

# ============================================================================
# TEST 18: Validation Output
# ============================================================================
test_that("tvexpose validate option works", {
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
    validate = TRUE,
    verbose = FALSE
  )

  expect_true(!is.null(result$diagnostics))
})

# ============================================================================
# Run all tests
# ============================================================================
cat("\nRunning tvexpose tests...\n")
