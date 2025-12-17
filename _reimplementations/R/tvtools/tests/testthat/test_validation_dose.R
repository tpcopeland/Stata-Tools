# Comprehensive validation tests for tvexpose dose functionality
# Tests cumulative dose tracking with proportional overlap handling

library(testthat)
library(tvtools)

# ============================================================================
# TEST DATA CREATION
# ============================================================================

create_dose_test_data <- function() {
  # Master cohort: 5 persons with 1-year follow-up
  master <- data.frame(
    id = 1:5,
    study_entry = as.Date(c("2020-01-01", "2020-01-01", "2020-01-01",
                            "2020-01-01", "2020-01-01")),
    study_exit = as.Date(c("2020-12-31", "2020-12-31", "2020-12-31",
                           "2020-12-31", "2020-12-31"))
  )

  # Exposure data with dose amounts (not categorical)
  # Person 1: Single prescription, 100mg over 30 days
  # Person 2: Two non-overlapping prescriptions
  # Person 3: Two overlapping prescriptions (proportional allocation needed)
  # Person 4: Multiple overlapping prescriptions (complex)
  # Person 5: No prescriptions (should remain at 0 dose)
  exposures <- data.frame(
    id = c(1, 2, 2, 3, 3, 4, 4, 4),
    rx_start = as.Date(c("2020-03-01",   # Person 1: single
                         "2020-02-01", "2020-06-01",  # Person 2: non-overlapping
                         "2020-03-01", "2020-03-15",  # Person 3: overlapping
                         "2020-04-01", "2020-04-10", "2020-04-20")),  # Person 4: multiple overlap
    rx_stop = as.Date(c("2020-03-30",    # Person 1
                        "2020-02-28", "2020-06-30",   # Person 2
                        "2020-03-30", "2020-04-14",   # Person 3
                        "2020-04-30", "2020-04-30", "2020-04-30")),  # Person 4
    dose = c(100,           # Person 1: 100mg total
             50, 75,        # Person 2: 50mg then 75mg
             60, 90,        # Person 3: overlapping 60mg and 90mg
             30, 40, 50)    # Person 4: triple overlap
  )

  list(master = master, exposures = exposures)
}

# ============================================================================
# SECTION 1: BASIC DOSE FUNCTIONALITY
# ============================================================================

test_that("1.1: Basic dose option creates cumulative dose variable", {
  data <- create_dose_test_data()

  result <- tvexpose(
    master_data = data$master[1, , drop = FALSE],  # Person 1 only
    exposure_file = data$exposures[data$exposures$id == 1, ],
    id = "id",
    start = "rx_start",
    stop = "rx_stop",
    exposure = "dose",
    reference = 0,
    entry = "study_entry",
    exit = "study_exit",
    dose = TRUE,
    verbose = FALSE
  )

  df <- result$data
  expect_true(nrow(df) >= 1)
  # Should have cumulative dose at the end
  final_period <- df[df$stop == max(df$stop), ]
  expect_true(final_period$tv_exposure >= 100)  # Cumulative dose should be at least 100
})

test_that("1.2: Dose without dosecuts produces continuous output", {
  data <- create_dose_test_data()

  result <- tvexpose(
    master_data = data$master[1, , drop = FALSE],
    exposure_file = data$exposures[data$exposures$id == 1, ],
    id = "id",
    start = "rx_start",
    stop = "rx_stop",
    exposure = "dose",
    reference = 0,
    entry = "study_entry",
    exit = "study_exit",
    dose = TRUE,
    verbose = FALSE
  )

  df <- result$data
  # Output should be numeric (continuous), not factor
  expect_true(is.numeric(df$tv_exposure))
})

test_that("1.3: Dose with dosecuts produces categorical output", {
  data <- create_dose_test_data()

  result <- tvexpose(
    master_data = data$master[1:2, ],
    exposure_file = data$exposures[data$exposures$id %in% 1:2, ],
    id = "id",
    start = "rx_start",
    stop = "rx_stop",
    exposure = "dose",
    reference = 0,
    entry = "study_entry",
    exit = "study_exit",
    dose = TRUE,
    dosecuts = c(50, 100),
    verbose = FALSE
  )

  df <- result$data
  # Output should be factor (categorical)
  expect_true(is.factor(df$tv_exposure))
  # Should have expected categories
  expect_true("No dose" %in% levels(df$tv_exposure))
  expect_true("<50" %in% levels(df$tv_exposure))
  expect_true("50-<100" %in% levels(df$tv_exposure))
  expect_true("100+" %in% levels(df$tv_exposure))
})

# ============================================================================
# SECTION 2: NON-OVERLAPPING DOSE PERIODS
# ============================================================================

test_that("2.1: Non-overlapping periods sum correctly", {
  data <- create_dose_test_data()

  result <- tvexpose(
    master_data = data$master[2, , drop = FALSE],  # Person 2
    exposure_file = data$exposures[data$exposures$id == 2, ],
    id = "id",
    start = "rx_start",
    stop = "rx_stop",
    exposure = "dose",
    reference = 0,
    entry = "study_entry",
    exit = "study_exit",
    dose = TRUE,
    verbose = FALSE
  )

  df <- result$data
  # Final cumulative dose should be 50 + 75 = 125
  final_dose <- max(df$tv_exposure, na.rm = TRUE)
  expect_equal(final_dose, 125, tolerance = 0.01)
})

test_that("2.2: Cumulative dose is monotonically increasing", {
  data <- create_dose_test_data()

  result <- tvexpose(
    master_data = data$master[2, , drop = FALSE],
    exposure_file = data$exposures[data$exposures$id == 2, ],
    id = "id",
    start = "rx_start",
    stop = "rx_stop",
    exposure = "dose",
    reference = 0,
    entry = "study_entry",
    exit = "study_exit",
    dose = TRUE,
    verbose = FALSE
  )

  df <- result$data
  df <- df[order(df$start), ]

  # Once dose > 0, it should never decrease (cumulative)
  doses <- df$tv_exposure
  for (i in 2:length(doses)) {
    expect_true(doses[i] >= doses[i-1])
  }
})

# ============================================================================
# SECTION 3: OVERLAPPING DOSE PERIODS (PROPORTIONAL ALLOCATION)
# ============================================================================

test_that("3.1: Overlapping periods use proportional allocation", {
  data <- create_dose_test_data()

  result <- tvexpose(
    master_data = data$master[3, , drop = FALSE],  # Person 3 with overlap
    exposure_file = data$exposures[data$exposures$id == 3, ],
    id = "id",
    start = "rx_start",
    stop = "rx_stop",
    exposure = "dose",
    reference = 0,
    entry = "study_entry",
    exit = "study_exit",
    dose = TRUE,
    verbose = FALSE
  )

  df <- result$data
  # With proportional allocation, total dose should still equal sum of prescriptions
  # Person 3: 60mg + 90mg = 150mg total
  final_dose <- max(df$tv_exposure, na.rm = TRUE)
  expect_equal(final_dose, 150, tolerance = 0.5)
})

test_that("3.2: Triple overlap preserves total dose", {
  data <- create_dose_test_data()

  result <- tvexpose(
    master_data = data$master[4, , drop = FALSE],  # Person 4 with triple overlap
    exposure_file = data$exposures[data$exposures$id == 4, ],
    id = "id",
    start = "rx_start",
    stop = "rx_stop",
    exposure = "dose",
    reference = 0,
    entry = "study_entry",
    exit = "study_exit",
    dose = TRUE,
    verbose = FALSE
  )

  df <- result$data
  # Person 4: 30 + 40 + 50 = 120mg total
  final_dose <- max(df$tv_exposure, na.rm = TRUE)
  expect_equal(final_dose, 120, tolerance = 0.5)
})

test_that("3.3: Overlap creates multiple segments with different rates", {
  data <- create_dose_test_data()

  result <- tvexpose(
    master_data = data$master[3, , drop = FALSE],
    exposure_file = data$exposures[data$exposures$id == 3, ],
    id = "id",
    start = "rx_start",
    stop = "rx_stop",
    exposure = "dose",
    reference = 0,
    entry = "study_entry",
    exit = "study_exit",
    dose = TRUE,
    verbose = FALSE
  )

  df <- result$data
  # Should have periods before, during, and after overlap
  expect_gte(nrow(df), 2)
})

# ============================================================================
# SECTION 4: DOSECUTS CATEGORIZATION
# ============================================================================

test_that("4.1: Dosecuts creates correct number of categories", {
  data <- create_dose_test_data()

  result <- tvexpose(
    master_data = data$master,
    exposure_file = data$exposures,
    id = "id",
    start = "rx_start",
    stop = "rx_stop",
    exposure = "dose",
    reference = 0,
    entry = "study_entry",
    exit = "study_exit",
    dose = TRUE,
    dosecuts = c(25, 75, 125),  # 3 cuts = 5 categories (0, <25, 25-<75, 75-<125, 125+)
    verbose = FALSE
  )

  df <- result$data
  expect_equal(nlevels(df$tv_exposure), 5)
})

test_that("4.2: Single dosecut creates 3 categories", {
  data <- create_dose_test_data()

  result <- tvexpose(
    master_data = data$master[1:2, ],
    exposure_file = data$exposures[data$exposures$id %in% 1:2, ],
    id = "id",
    start = "rx_start",
    stop = "rx_stop",
    exposure = "dose",
    reference = 0,
    entry = "study_entry",
    exit = "study_exit",
    dose = TRUE,
    dosecuts = c(100),  # 1 cut = 3 categories (0, <100, 100+)
    verbose = FALSE
  )

  df <- result$data
  expect_equal(nlevels(df$tv_exposure), 3)
  expect_true("No dose" %in% levels(df$tv_exposure))
  expect_true("<100" %in% levels(df$tv_exposure))
  expect_true("100+" %in% levels(df$tv_exposure))
})

test_that("4.3: No dose category is reference (=0)", {
  # Test that "No dose" category is assigned to periods before first prescription
  master <- data.frame(
    id = 1,
    study_entry = as.Date("2020-01-01"),
    study_exit = as.Date("2020-12-31")
  )

  exposures <- data.frame(
    id = 1,
    rx_start = as.Date("2020-06-01"),  # Prescription starts mid-year
    rx_stop = as.Date("2020-06-30"),
    dose = 100
  )

  result <- tvexpose(
    master_data = master,
    exposure_file = exposures,
    id = "id",
    start = "rx_start",
    stop = "rx_stop",
    exposure = "dose",
    reference = 0,
    entry = "study_entry",
    exit = "study_exit",
    dose = TRUE,
    dosecuts = c(50, 100),
    verbose = FALSE
  )

  df <- result$data
  # First period (before prescription) should be "No dose" category
  first_period <- df[df$start == min(df$start), ]
  expect_equal(as.character(first_period$tv_exposure), "No dose")
})

# ============================================================================
# SECTION 5: ERROR HANDLING
# ============================================================================

test_that("5.1: dosecuts without dose raises error", {
  data <- create_dose_test_data()

  expect_error(
    tvexpose(
      master_data = data$master[1, , drop = FALSE],
      exposure_file = data$exposures[data$exposures$id == 1, ],
      id = "id",
      start = "rx_start",
      stop = "rx_stop",
      exposure = "dose",
      reference = 0,
      entry = "study_entry",
      exit = "study_exit",
      dose = FALSE,  # dose=FALSE
      dosecuts = c(50, 100),  # but dosecuts provided
      verbose = FALSE
    ),
    "dosecuts requires dose"
  )
})

test_that("5.2: dose with bytype raises error", {
  data <- create_dose_test_data()

  expect_error(
    tvexpose(
      master_data = data$master[1, , drop = FALSE],
      exposure_file = data$exposures[data$exposures$id == 1, ],
      id = "id",
      start = "rx_start",
      stop = "rx_stop",
      exposure = "dose",
      reference = 0,
      entry = "study_entry",
      exit = "study_exit",
      dose = TRUE,
      bytype = TRUE,  # bytype not allowed with dose
      verbose = FALSE
    ),
    "bytype cannot be used with dose"
  )
})

test_that("5.3: dose is mutually exclusive with other exposure types", {
  data <- create_dose_test_data()

  expect_error(
    tvexpose(
      master_data = data$master[1, , drop = FALSE],
      exposure_file = data$exposures[data$exposures$id == 1, ],
      id = "id",
      start = "rx_start",
      stop = "rx_stop",
      exposure = "dose",
      reference = 0,
      entry = "study_entry",
      exit = "study_exit",
      dose = TRUE,
      evertreated = TRUE,  # Can't combine with dose
      verbose = FALSE
    ),
    "Only one exposure type"
  )
})

# ============================================================================
# SECTION 6: INVARIANTS
# ============================================================================

test_that("6.1: Output intervals are non-overlapping", {
  data <- create_dose_test_data()

  result <- tvexpose(
    master_data = data$master,
    exposure_file = data$exposures,
    id = "id",
    start = "rx_start",
    stop = "rx_stop",
    exposure = "dose",
    reference = 0,
    entry = "study_entry",
    exit = "study_exit",
    dose = TRUE,
    verbose = FALSE
  )

  df <- result$data
  df <- df[order(df$id, df$start), ]

  # Check no overlaps within person
  n_overlaps <- 0
  for (i in 2:nrow(df)) {
    if (df$id[i] == df$id[i-1]) {
      if (df$start[i] < df$stop[i-1]) {
        n_overlaps <- n_overlaps + 1
      }
    }
  }
  expect_equal(n_overlaps, 0)
})

test_that("6.2: Output is sorted by id and start", {
  data <- create_dose_test_data()

  result <- tvexpose(
    master_data = data$master,
    exposure_file = data$exposures,
    id = "id",
    start = "rx_start",
    stop = "rx_stop",
    exposure = "dose",
    reference = 0,
    entry = "study_entry",
    exit = "study_exit",
    dose = TRUE,
    verbose = FALSE
  )

  df <- result$data
  df_sorted <- df[order(df$id, df$start), ]

  expect_equal(df$id, df_sorted$id)
  expect_equal(df$start, df_sorted$start)
})

test_that("6.3: Cumulative dose never decreases within person", {
  data <- create_dose_test_data()

  result <- tvexpose(
    master_data = data$master,
    exposure_file = data$exposures,
    id = "id",
    start = "rx_start",
    stop = "rx_stop",
    exposure = "dose",
    reference = 0,
    entry = "study_entry",
    exit = "study_exit",
    dose = TRUE,
    verbose = FALSE
  )

  df <- result$data
  df <- df[order(df$id, df$start), ]

  # For each person, cumulative dose should be monotonically non-decreasing
  for (person_id in unique(df$id)) {
    person_df <- df[df$id == person_id, ]
    doses <- person_df$tv_exposure
    if (length(doses) > 1) {
      for (i in 2:length(doses)) {
        expect_true(doses[i] >= doses[i-1],
                    info = sprintf("Person %d: dose decreased from %f to %f",
                                   person_id, doses[i-1], doses[i]))
      }
    }
  }
})

test_that("6.4: Total dose preservation (sum of inputs = final cumulative)", {
  # Create simple test case with known total
  master <- data.frame(
    id = 1,
    study_entry = as.Date("2020-01-01"),
    study_exit = as.Date("2020-12-31")
  )

  exposures <- data.frame(
    id = c(1, 1, 1),
    rx_start = as.Date(c("2020-02-01", "2020-04-01", "2020-06-01")),
    rx_stop = as.Date(c("2020-02-28", "2020-04-30", "2020-06-30")),
    dose = c(100, 200, 150)
  )

  result <- tvexpose(
    master_data = master,
    exposure_file = exposures,
    id = "id",
    start = "rx_start",
    stop = "rx_stop",
    exposure = "dose",
    reference = 0,
    entry = "study_entry",
    exit = "study_exit",
    dose = TRUE,
    verbose = FALSE
  )

  df <- result$data
  expected_total <- sum(exposures$dose)  # 100 + 200 + 150 = 450
  actual_total <- max(df$tv_exposure, na.rm = TRUE)
  expect_equal(actual_total, expected_total, tolerance = 0.01)
})

# ============================================================================
# SECTION 7: EDGE CASES
# ============================================================================

test_that("7.1: Single day prescription", {
  master <- data.frame(
    id = 1,
    study_entry = as.Date("2020-01-01"),
    study_exit = as.Date("2020-12-31")
  )

  exposures <- data.frame(
    id = 1,
    rx_start = as.Date("2020-06-15"),
    rx_stop = as.Date("2020-06-15"),  # Same day
    dose = 50
  )

  result <- tvexpose(
    master_data = master,
    exposure_file = exposures,
    id = "id",
    start = "rx_start",
    stop = "rx_stop",
    exposure = "dose",
    reference = 0,
    entry = "study_entry",
    exit = "study_exit",
    dose = TRUE,
    verbose = FALSE
  )

  df <- result$data
  expect_true(any(df$tv_exposure >= 50))
})

test_that("7.2: Completely overlapping prescriptions (same dates)", {
  master <- data.frame(
    id = 1,
    study_entry = as.Date("2020-01-01"),
    study_exit = as.Date("2020-12-31")
  )

  exposures <- data.frame(
    id = c(1, 1),
    rx_start = as.Date(c("2020-03-01", "2020-03-01")),  # Same start
    rx_stop = as.Date(c("2020-03-31", "2020-03-31")),   # Same stop
    dose = c(100, 50)
  )

  result <- tvexpose(
    master_data = master,
    exposure_file = exposures,
    id = "id",
    start = "rx_start",
    stop = "rx_stop",
    exposure = "dose",
    reference = 0,
    entry = "study_entry",
    exit = "study_exit",
    dose = TRUE,
    verbose = FALSE
  )

  df <- result$data
  # Total should be 100 + 50 = 150
  final_dose <- max(df$tv_exposure, na.rm = TRUE)
  expect_equal(final_dose, 150, tolerance = 0.01)
})

test_that("7.3: Large dose values", {
  master <- data.frame(
    id = 1,
    study_entry = as.Date("2020-01-01"),
    study_exit = as.Date("2020-12-31")
  )

  exposures <- data.frame(
    id = 1,
    rx_start = as.Date("2020-03-01"),
    rx_stop = as.Date("2020-03-31"),
    dose = 1e6  # 1 million
  )

  result <- tvexpose(
    master_data = master,
    exposure_file = exposures,
    id = "id",
    start = "rx_start",
    stop = "rx_stop",
    exposure = "dose",
    reference = 0,
    entry = "study_entry",
    exit = "study_exit",
    dose = TRUE,
    verbose = FALSE
  )

  df <- result$data
  expect_true(any(df$tv_exposure >= 1e6))
})

test_that("7.4: Very small dose values", {
  master <- data.frame(
    id = 1,
    study_entry = as.Date("2020-01-01"),
    study_exit = as.Date("2020-12-31")
  )

  exposures <- data.frame(
    id = 1,
    rx_start = as.Date("2020-03-01"),
    rx_stop = as.Date("2020-03-31"),
    dose = 0.001
  )

  result <- tvexpose(
    master_data = master,
    exposure_file = exposures,
    id = "id",
    start = "rx_start",
    stop = "rx_stop",
    exposure = "dose",
    reference = 0,
    entry = "study_entry",
    exit = "study_exit",
    dose = TRUE,
    verbose = FALSE
  )

  df <- result$data
  expect_true(any(df$tv_exposure >= 0.001))
})

# ============================================================================
# SECTION 8: METADATA
# ============================================================================

test_that("8.1: Metadata indicates dose exposure type", {
  data <- create_dose_test_data()

  result <- tvexpose(
    master_data = data$master[1, , drop = FALSE],
    exposure_file = data$exposures[data$exposures$id == 1, ],
    id = "id",
    start = "rx_start",
    stop = "rx_stop",
    exposure = "dose",
    reference = 0,
    entry = "study_entry",
    exit = "study_exit",
    dose = TRUE,
    verbose = FALSE
  )

  expect_equal(result$metadata$parameters$exposure_definition, "dose")
})

test_that("8.2: Metadata includes dosecuts when provided", {
  data <- create_dose_test_data()

  cuts <- c(25, 75, 125)
  result <- tvexpose(
    master_data = data$master[1, , drop = FALSE],
    exposure_file = data$exposures[data$exposures$id == 1, ],
    id = "id",
    start = "rx_start",
    stop = "rx_stop",
    exposure = "dose",
    reference = 0,
    entry = "study_entry",
    exit = "study_exit",
    dose = TRUE,
    dosecuts = cuts,
    verbose = FALSE
  )

  expect_equal(result$metadata$parameters$dosecuts, cuts)
})

cat("\nR tvexpose dose validation tests complete.\n")
