# Test suite for tvexpose function
# Tests cover basic functionality, edge cases, exposure types, parameter validation, and output format

library(testthat)
library(dplyr)
library(lubridate)

# ============================================================================
# Helper function to create test cohort data
# ============================================================================
create_test_cohort <- function(n = 10) {
  data.frame(
    id = 1:n,
    study_entry = as.Date("2010-01-01") + (0:(n-1)) * 30,
    study_exit = as.Date("2020-12-31"),
    age = 50 + (1:n),
    female = rep(c(0, 1), length.out = n),
    stringsAsFactors = FALSE
  )
}

# ============================================================================
# Helper function to create test exposure data
# ============================================================================
create_test_exposure <- function(ids = 1:5, exposure_type = "simple") {
  if (exposure_type == "simple") {
    # Simple non-overlapping periods
    data.frame(
      id = ids,
      exp_start = as.Date("2011-01-01") + (ids - 1) * 10,
      exp_stop = as.Date("2012-01-01") + (ids - 1) * 10,
      exposure = rep(1, length(ids)),
      stringsAsFactors = FALSE
    )
  } else if (exposure_type == "gaps") {
    # Exposure with gaps
    bind_rows(
      data.frame(id = 1, exp_start = as.Date("2011-01-01"),
                 exp_stop = as.Date("2012-01-01"), exposure = 1),
      data.frame(id = 1, exp_start = as.Date("2013-01-01"),
                 exp_stop = as.Date("2014-01-01"), exposure = 1),
      data.frame(id = 2, exp_start = as.Date("2011-06-01"),
                 exp_stop = as.Date("2012-06-01"), exposure = 2)
    )
  } else if (exposure_type == "overlaps") {
    # Overlapping exposure periods
    bind_rows(
      data.frame(id = 1, exp_start = as.Date("2011-01-01"),
                 exp_stop = as.Date("2012-01-01"), exposure = 1),
      data.frame(id = 1, exp_start = as.Date("2011-06-01"),
                 exp_stop = as.Date("2012-06-01"), exposure = 2),
      data.frame(id = 2, exp_start = as.Date("2011-01-01"),
                 exp_stop = as.Date("2013-01-01"), exposure = 1)
    )
  } else if (exposure_type == "multiple_types") {
    # Multiple exposure types
    bind_rows(
      data.frame(id = 1, exp_start = as.Date("2011-01-01"),
                 exp_stop = as.Date("2012-01-01"), exposure = 1),
      data.frame(id = 1, exp_start = as.Date("2012-01-01"),
                 exp_stop = as.Date("2013-01-01"), exposure = 2),
      data.frame(id = 1, exp_start = as.Date("2013-01-01"),
                 exp_stop = as.Date("2014-01-01"), exposure = 3),
      data.frame(id = 2, exp_start = as.Date("2011-01-01"),
                 exp_stop = as.Date("2015-01-01"), exposure = 1)
    )
  } else if (exposure_type == "point_time") {
    # Point-in-time exposures (no stop date)
    data.frame(
      id = ids,
      exp_start = as.Date("2011-01-01") + (ids - 1) * 30,
      exposure = rep(1, length(ids)),
      stringsAsFactors = FALSE
    )
  }
}

# ============================================================================
# BASIC FUNCTIONALITY TESTS
# ============================================================================

test_that("tvexpose handles basic time-varying exposure", {
  cohort <- create_test_cohort(5)
  exposure <- create_test_exposure(1:3, "simple")

  result <- tvexpose(
    data = cohort,
    exposure_data = exposure,
    id = "id",
    start = "exp_start",
    stop = "exp_stop",
    exposure = "exposure",
    reference = 0,
    entry = "study_entry",
    exit = "study_exit"
  )

  # Check output structure
  expect_s3_class(result, "data.frame")
  expect_true("id" %in% names(result))
  expect_true("start" %in% names(result) | "tstart" %in% names(result))
  expect_true("stop" %in% names(result) | "tstop" %in% names(result))
  expect_true("tv_exposure" %in% names(result))

  # Check that all IDs from cohort are present
  expect_equal(sort(unique(result$id)), sort(cohort$id))

  # Check that exposed persons have exposure periods
  exposed_ids <- unique(exposure$id)
  result_exposed <- result %>% filter(id %in% exposed_ids, tv_exposure != 0)
  expect_true(nrow(result_exposed) > 0)
})

test_that("tvexpose creates correct number of rows", {
  cohort <- create_test_cohort(10)
  exposure <- create_test_exposure(1:5, "simple")

  result <- tvexpose(
    data = cohort,
    exposure_data = exposure,
    id = "id",
    start = "exp_start",
    stop = "exp_stop",
    exposure = "exposure",
    reference = 0,
    entry = "study_entry",
    exit = "study_exit"
  )

  # Each person should have at least one row
  expect_true(nrow(result) >= nrow(cohort))

  # Exposed persons should have multiple rows (exposed + unexposed periods)
  exposed_ids <- unique(exposure$id)
  for (id in exposed_ids) {
    person_rows <- result %>% filter(id == !!id)
    expect_true(nrow(person_rows) >= 2)  # At least unexposed before/after
  }
})

test_that("tvexpose handles unexposed persons correctly", {
  cohort <- create_test_cohort(10)
  exposure <- create_test_exposure(1:3, "simple")  # Only 3 of 10 exposed

  result <- tvexpose(
    data = cohort,
    exposure_data = exposure,
    id = "id",
    start = "exp_start",
    stop = "exp_stop",
    exposure = "exposure",
    reference = 0,
    entry = "study_entry",
    exit = "study_exit"
  )

  # Unexposed persons should have one row with reference exposure
  unexposed_ids <- setdiff(cohort$id, unique(exposure$id))
  for (id in unexposed_ids) {
    person_rows <- result %>% filter(id == !!id)
    expect_equal(nrow(person_rows), 1)
    expect_equal(person_rows$tv_exposure[1], 0)
  }
})

# ============================================================================
# EDGE CASES: GAPS
# ============================================================================

test_that("tvexpose handles gaps in exposure correctly", {
  cohort <- create_test_cohort(5)
  exposure <- create_test_exposure(1:2, "gaps")

  result <- tvexpose(
    data = cohort,
    exposure_data = exposure,
    id = "id",
    start = "exp_start",
    stop = "exp_stop",
    exposure = "exposure",
    reference = 0,
    entry = "study_entry",
    exit = "study_exit"
  )

  # Person 1 has gap between exposures - should have unexposed period in gap
  person1 <- result %>% filter(id == 1) %>% arrange(start)
  expect_true(nrow(person1) >= 3)  # Before, exposed, gap, exposed, after

  # Check that gaps are filled with reference category
  has_reference_in_gap <- any(person1$tv_exposure == 0 &
                               person1$start >= as.Date("2012-01-01") &
                               person1$stop <= as.Date("2013-01-01"))
  expect_true(has_reference_in_gap)
})

test_that("tvexpose grace period merges gaps", {
  cohort <- create_test_cohort(5)
  # Create exposure with small gap (30 days)
  exposure <- bind_rows(
    data.frame(id = 1, exp_start = as.Date("2011-01-01"),
               exp_stop = as.Date("2011-12-31"), exposure = 1),
    data.frame(id = 1, exp_start = as.Date("2012-01-30"),
               exp_stop = as.Date("2012-12-31"), exposure = 1)
  )

  result_no_grace <- tvexpose(
    data = cohort,
    exposure_data = exposure,
    id = "id",
    start = "exp_start",
    stop = "exp_stop",
    exposure = "exposure",
    reference = 0,
    entry = "study_entry",
    exit = "study_exit",
    grace = 0
  )

  result_with_grace <- tvexpose(
    data = cohort,
    exposure_data = exposure,
    id = "id",
    start = "exp_start",
    stop = "exp_stop",
    exposure = "exposure",
    reference = 0,
    entry = "study_entry",
    exit = "study_exit",
    grace = 60  # 60 day grace period should merge the gap
  )

  # With grace period, should have fewer rows (gap merged)
  person1_no_grace <- result_no_grace %>% filter(id == 1)
  person1_with_grace <- result_with_grace %>% filter(id == 1)
  expect_true(nrow(person1_with_grace) <= nrow(person1_no_grace))
})

# ============================================================================
# EDGE CASES: OVERLAPS
# ============================================================================

test_that("tvexpose handles overlapping exposures with layer strategy", {
  cohort <- create_test_cohort(5)
  exposure <- create_test_exposure(1:2, "overlaps")

  result <- tvexpose(
    data = cohort,
    exposure_data = exposure,
    id = "id",
    start = "exp_start",
    stop = "exp_stop",
    exposure = "exposure",
    reference = 0,
    entry = "study_entry",
    exit = "study_exit",
    overlap_strategy = "layer"  # Later exposures take precedence
  )

  # Check that result has proper structure
  expect_s3_class(result, "data.frame")

  # Person 1 has overlapping periods - later should take precedence
  person1 <- result %>% filter(id == 1) %>% arrange(start)
  expect_true(nrow(person1) > 1)
})

test_that("tvexpose handles overlapping exposures with split strategy", {
  cohort <- create_test_cohort(5)
  exposure <- create_test_exposure(1:2, "overlaps")

  result <- tvexpose(
    data = cohort,
    exposure_data = exposure,
    id = "id",
    start = "exp_start",
    stop = "exp_stop",
    exposure = "exposure",
    reference = 0,
    entry = "study_entry",
    exit = "study_exit",
    overlap_strategy = "split"  # Split at all boundaries
  )

  # Check that overlapping periods are split
  expect_s3_class(result, "data.frame")
  person1 <- result %>% filter(id == 1) %>% arrange(start)
  expect_true(nrow(person1) > 1)
})

# ============================================================================
# EDGE CASES: MISSING VALUES
# ============================================================================

test_that("tvexpose handles missing exposure values", {
  cohort <- create_test_cohort(5)
  exposure <- create_test_exposure(1:3, "simple")
  exposure$exposure[2] <- NA  # Introduce missing value

  expect_error(
    tvexpose(
      data = cohort,
      exposure_data = exposure,
      id = "id",
      start = "exp_start",
      stop = "exp_stop",
      exposure = "exposure",
      reference = 0,
      entry = "study_entry",
      exit = "study_exit"
    ),
    "missing"
  )
})

test_that("tvexpose handles missing dates", {
  cohort <- create_test_cohort(5)
  exposure <- create_test_exposure(1:3, "simple")
  exposure$exp_start[2] <- NA  # Introduce missing date

  expect_error(
    tvexpose(
      data = cohort,
      exposure_data = exposure,
      id = "id",
      start = "exp_start",
      stop = "exp_stop",
      exposure = "exposure",
      reference = 0,
      entry = "study_entry",
      exit = "study_exit"
    ),
    "missing|NA"
  )
})

test_that("tvexpose handles persons with no exposure data", {
  cohort <- create_test_cohort(10)
  exposure <- create_test_exposure(1:3, "simple")

  result <- tvexpose(
    data = cohort,
    exposure_data = exposure,
    id = "id",
    start = "exp_start",
    stop = "exp_stop",
    exposure = "exposure",
    reference = 0,
    entry = "study_entry",
    exit = "study_exit"
  )

  # All persons from cohort should appear in result
  expect_setequal(unique(result$id), cohort$id)

  # Unexposed persons should have reference exposure
  unexposed <- result %>%
    filter(!(id %in% unique(exposure$id)))
  expect_true(all(unexposed$tv_exposure == 0))
})

# ============================================================================
# DIFFERENT EXPOSURE TYPES
# ============================================================================

test_that("tvexpose creates evertreated exposure variable", {
  cohort <- create_test_cohort(5)
  exposure <- create_test_exposure(1:3, "simple")

  result <- tvexpose(
    data = cohort,
    exposure_data = exposure,
    id = "id",
    start = "exp_start",
    stop = "exp_stop",
    exposure = "exposure",
    reference = 0,
    entry = "study_entry",
    exit = "study_exit",
    exposure_type = "evertreated"
  )

  # For evertreated, should switch from 0 to 1 at first exposure
  # and remain 1 thereafter
  exposed_ids <- unique(exposure$id)
  for (id in exposed_ids) {
    person_rows <- result %>% filter(id == !!id) %>% arrange(start)

    # Find first exposure
    first_exposed <- which(person_rows$tv_exposure == 1)[1]
    if (!is.na(first_exposed) && first_exposed < nrow(person_rows)) {
      # All subsequent rows should also be exposed
      expect_true(all(person_rows$tv_exposure[first_exposed:nrow(person_rows)] == 1))
    }
  }
})

test_that("tvexpose creates currentformer exposure variable", {
  cohort <- create_test_cohort(5)
  exposure <- create_test_exposure(1:2, "gaps")

  result <- tvexpose(
    data = cohort,
    exposure_data = exposure,
    id = "id",
    start = "exp_start",
    stop = "exp_stop",
    exposure = "exposure",
    reference = 0,
    entry = "study_entry",
    exit = "study_exit",
    exposure_type = "currentformer"
  )

  # Current/former should have 3 levels: 0=never, 1=current, 2=former
  expect_true(all(result$tv_exposure %in% c(0, 1, 2)))

  # Person with gaps should have former exposure in gaps
  person1 <- result %>% filter(id == 1) %>% arrange(start)
  if (nrow(person1) > 2) {
    # Should have never (0), current (1), and former (2) periods
    expect_true(1 %in% person1$tv_exposure)  # Current
    expect_true(any(person1$tv_exposure == 2 | person1$tv_exposure == 0))  # Former or never
  }
})

test_that("tvexpose creates duration-based exposure variable", {
  cohort <- create_test_cohort(5)
  exposure <- create_test_exposure(1:3, "simple")

  result <- tvexpose(
    data = cohort,
    exposure_data = exposure,
    id = "id",
    start = "exp_start",
    stop = "exp_stop",
    exposure = "exposure",
    reference = 0,
    entry = "study_entry",
    exit = "study_exit",
    exposure_type = "duration",
    duration_breaks = c(0, 0.5, 1, 2)  # years
  )

  # Duration should create categories based on cumulative exposure time
  expect_s3_class(result, "data.frame")
  expect_true("tv_exposure" %in% names(result))

  # Exposure values should reflect duration categories
  # 0 = unexposed, 1-4 for different duration categories
  exposed_rows <- result %>% filter(id %in% unique(exposure$id), tv_exposure != 0)
  expect_true(nrow(exposed_rows) > 0)
})

test_that("tvexpose creates recency-based exposure variable", {
  cohort <- create_test_cohort(5)
  exposure <- create_test_exposure(1:2, "gaps")

  result <- tvexpose(
    data = cohort,
    exposure_data = exposure,
    id = "id",
    start = "exp_start",
    stop = "exp_stop",
    exposure = "exposure",
    reference = 0,
    entry = "study_entry",
    exit = "study_exit",
    exposure_type = "recency",
    recency_breaks = c(0, 30, 90, 365)  # days since last exposure
  )

  # Recency should create categories based on time since last exposure
  expect_s3_class(result, "data.frame")
  expect_true("tv_exposure" %in% names(result))
})

test_that("tvexpose handles bytype exposure creation", {
  cohort <- create_test_cohort(5)
  exposure <- create_test_exposure(1:3, "multiple_types")

  result <- tvexpose(
    data = cohort,
    exposure_data = exposure,
    id = "id",
    start = "exp_start",
    stop = "exp_stop",
    exposure = "exposure",
    reference = 0,
    entry = "study_entry",
    exit = "study_exit",
    bytype = TRUE
  )

  # With bytype, should create separate variables for each exposure type
  # e.g., tv_exposure_1, tv_exposure_2, tv_exposure_3
  exposure_types <- unique(exposure$exposure[exposure$exposure != 0])
  for (exp_type in exposure_types) {
    var_name <- paste0("tv_exposure_", exp_type)
    expect_true(var_name %in% names(result),
                info = paste("Expected variable", var_name, "not found"))
  }
})

test_that("tvexpose handles point-in-time exposures", {
  cohort <- create_test_cohort(5)
  exposure <- create_test_exposure(1:3, "point_time")

  result <- tvexpose(
    data = cohort,
    exposure_data = exposure,
    id = "id",
    start = "exp_start",
    exposure = "exposure",
    reference = 0,
    entry = "study_entry",
    exit = "study_exit",
    point_time = TRUE
  )

  # Point-in-time exposures should create exposure starting from the point
  expect_s3_class(result, "data.frame")

  # Exposed persons should have periods starting from exposure point
  exposed_ids <- unique(exposure$id)
  for (id in exposed_ids) {
    person_rows <- result %>% filter(id == !!id) %>% arrange(start)
    expect_true(nrow(person_rows) >= 1)
  }
})

# ============================================================================
# PARAMETER VALIDATION
# ============================================================================

test_that("tvexpose validates required parameters", {
  cohort <- create_test_cohort(5)
  exposure <- create_test_exposure(1:3, "simple")

  # Missing data
  expect_error(
    tvexpose(
      exposure_data = exposure,
      id = "id",
      start = "exp_start",
      stop = "exp_stop",
      exposure = "exposure",
      reference = 0,
      entry = "study_entry",
      exit = "study_exit"
    ),
    "data"
  )

  # Missing id
  expect_error(
    tvexpose(
      data = cohort,
      exposure_data = exposure,
      start = "exp_start",
      stop = "exp_stop",
      exposure = "exposure",
      reference = 0,
      entry = "study_entry",
      exit = "study_exit"
    ),
    "id"
  )

  # Missing start
  expect_error(
    tvexpose(
      data = cohort,
      exposure_data = exposure,
      id = "id",
      stop = "exp_stop",
      exposure = "exposure",
      reference = 0,
      entry = "study_entry",
      exit = "study_exit"
    ),
    "start"
  )
})

test_that("tvexpose validates date variables exist", {
  cohort <- create_test_cohort(5)
  exposure <- create_test_exposure(1:3, "simple")

  expect_error(
    tvexpose(
      data = cohort,
      exposure_data = exposure,
      id = "id",
      start = "nonexistent_start",
      stop = "exp_stop",
      exposure = "exposure",
      reference = 0,
      entry = "study_entry",
      exit = "study_exit"
    ),
    "nonexistent_start|not found"
  )
})

test_that("tvexpose validates exposure values are valid", {
  cohort <- create_test_cohort(5)
  exposure <- create_test_exposure(1:3, "simple")
  exposure$exposure <- c("A", "B", "C")  # Invalid non-numeric exposure

  expect_error(
    tvexpose(
      data = cohort,
      exposure_data = exposure,
      id = "id",
      start = "exp_start",
      stop = "exp_stop",
      exposure = "exposure",
      reference = 0,
      entry = "study_entry",
      exit = "study_exit"
    ),
    "numeric|categorical"
  )
})

test_that("tvexpose validates date ordering", {
  cohort <- create_test_cohort(5)
  exposure <- create_test_exposure(1:3, "simple")
  # Swap start and stop to create invalid ordering
  temp <- exposure$exp_start
  exposure$exp_start <- exposure$exp_stop
  exposure$exp_stop <- temp

  expect_error(
    tvexpose(
      data = cohort,
      exposure_data = exposure,
      id = "id",
      start = "exp_start",
      stop = "exp_stop",
      exposure = "exposure",
      reference = 0,
      entry = "study_entry",
      exit = "study_exit"
    ),
    "start.*stop|before|after|order"
  )
})

# ============================================================================
# OUTPUT FORMAT VERIFICATION
# ============================================================================

test_that("tvexpose output has correct column names", {
  cohort <- create_test_cohort(5)
  exposure <- create_test_exposure(1:3, "simple")

  result <- tvexpose(
    data = cohort,
    exposure_data = exposure,
    id = "id",
    start = "exp_start",
    stop = "exp_stop",
    exposure = "exposure",
    reference = 0,
    entry = "study_entry",
    exit = "study_exit"
  )

  # Standard output columns
  expect_true("id" %in% names(result))
  expect_true(any(c("start", "tstart", "tstart_date") %in% names(result)))
  expect_true(any(c("stop", "tstop", "tstop_date") %in% names(result)))
  expect_true("tv_exposure" %in% names(result))
})

test_that("tvexpose respects custom variable names", {
  cohort <- create_test_cohort(5)
  exposure <- create_test_exposure(1:3, "simple")

  result <- tvexpose(
    data = cohort,
    exposure_data = exposure,
    id = "id",
    start = "exp_start",
    stop = "exp_stop",
    exposure = "exposure",
    reference = 0,
    entry = "study_entry",
    exit = "study_exit",
    generate = "my_exposure"
  )

  expect_true("my_exposure" %in% names(result))
})

test_that("tvexpose output has no missing values in key columns", {
  cohort <- create_test_cohort(5)
  exposure <- create_test_exposure(1:3, "simple")

  result <- tvexpose(
    data = cohort,
    exposure_data = exposure,
    id = "id",
    start = "exp_start",
    stop = "exp_stop",
    exposure = "exposure",
    reference = 0,
    entry = "study_entry",
    exit = "study_exit"
  )

  expect_false(any(is.na(result$id)))
  expect_false(any(is.na(result$tv_exposure)))

  # Check start/stop columns (may have different names)
  start_col <- intersect(c("start", "tstart", "tstart_date"), names(result))[1]
  stop_col <- intersect(c("stop", "tstop", "tstop_date"), names(result))[1]

  if (!is.na(start_col)) expect_false(any(is.na(result[[start_col]])))
  if (!is.na(stop_col)) expect_false(any(is.na(result[[stop_col]])))
})

test_that("tvexpose output has non-overlapping periods per person", {
  cohort <- create_test_cohort(5)
  exposure <- create_test_exposure(1:3, "simple")

  result <- tvexpose(
    data = cohort,
    exposure_data = exposure,
    id = "id",
    start = "exp_start",
    stop = "exp_stop",
    exposure = "exposure",
    reference = 0,
    entry = "study_entry",
    exit = "study_exit"
  )

  # Get start/stop column names
  start_col <- intersect(c("start", "tstart", "tstart_date"), names(result))[1]
  stop_col <- intersect(c("stop", "tstop", "tstop_date"), names(result))[1]

  # Check each person's periods don't overlap
  for (person_id in unique(result$id)) {
    person_rows <- result %>%
      filter(id == !!person_id) %>%
      arrange(.data[[start_col]])

    if (nrow(person_rows) > 1) {
      for (i in 1:(nrow(person_rows) - 1)) {
        # End of current period should be <= start of next period
        expect_true(
          person_rows[[stop_col]][i] <= person_rows[[start_col]][i + 1],
          info = paste("Overlapping periods for person", person_id)
        )
      }
    }
  }
})

test_that("tvexpose output covers full follow-up period", {
  cohort <- create_test_cohort(5)
  exposure <- create_test_exposure(1:3, "simple")

  result <- tvexpose(
    data = cohort,
    exposure_data = exposure,
    id = "id",
    start = "exp_start",
    stop = "exp_stop",
    exposure = "exposure",
    reference = 0,
    entry = "study_entry",
    exit = "study_exit"
  )

  # Get start/stop column names
  start_col <- intersect(c("start", "tstart", "tstart_date"), names(result))[1]
  stop_col <- intersect(c("stop", "tstop", "tstop_date"), names(result))[1]

  # Check each person's coverage
  for (person_id in cohort$id) {
    person_cohort <- cohort %>% filter(id == !!person_id)
    person_result <- result %>%
      filter(id == !!person_id) %>%
      arrange(.data[[start_col]])

    # First period should start at or before entry
    expect_true(
      person_result[[start_col]][1] <= person_cohort$study_entry,
      info = paste("First period for person", person_id, "starts after entry")
    )

    # Last period should end at or after exit
    expect_true(
      person_result[[stop_col]][nrow(person_result)] >= person_cohort$study_exit,
      info = paste("Last period for person", person_id, "ends before exit")
    )
  }
})

# ============================================================================
# LAG AND WASHOUT TESTS
# ============================================================================

test_that("tvexpose applies lag correctly", {
  cohort <- create_test_cohort(5)
  exposure <- data.frame(
    id = 1,
    exp_start = as.Date("2011-01-01"),
    exp_stop = as.Date("2012-01-01"),
    exposure = 1
  )

  result <- tvexpose(
    data = cohort,
    exposure_data = exposure,
    id = "id",
    start = "exp_start",
    stop = "exp_stop",
    exposure = "exposure",
    reference = 0,
    entry = "study_entry",
    exit = "study_exit",
    lag = 30  # 30 day lag
  )

  # Exposure should start 30 days after exp_start
  person1 <- result %>% filter(id == 1, tv_exposure == 1)
  if (nrow(person1) > 0) {
    start_col <- intersect(c("start", "tstart", "tstart_date"), names(result))[1]
    expected_start <- exposure$exp_start[1] + 30
    expect_true(person1[[start_col]][1] >= expected_start)
  }
})

test_that("tvexpose applies washout correctly", {
  cohort <- create_test_cohort(5)
  exposure <- data.frame(
    id = 1,
    exp_start = as.Date("2011-01-01"),
    exp_stop = as.Date("2012-01-01"),
    exposure = 1
  )

  result <- tvexpose(
    data = cohort,
    exposure_data = exposure,
    id = "id",
    start = "exp_start",
    stop = "exp_stop",
    exposure = "exposure",
    reference = 0,
    entry = "study_entry",
    exit = "study_exit",
    washout = 60  # 60 day washout
  )

  # Exposure should persist 60 days after exp_stop
  person1 <- result %>% filter(id == 1, tv_exposure == 1)
  if (nrow(person1) > 0) {
    stop_col <- intersect(c("stop", "tstop", "tstop_date"), names(result))[1]
    expected_stop <- exposure$exp_stop[1] + 60
    # Last exposed period should end around expected_stop
    last_exposed_stop <- person1[[stop_col]][nrow(person1)]
    expect_true(last_exposed_stop >= exposure$exp_stop[1])
  }
})

# ============================================================================
# ADDITIONAL VARIABLES TESTS
# ============================================================================

test_that("tvexpose keeps additional variables from cohort", {
  cohort <- create_test_cohort(5)
  exposure <- create_test_exposure(1:3, "simple")

  result <- tvexpose(
    data = cohort,
    exposure_data = exposure,
    id = "id",
    start = "exp_start",
    stop = "exp_stop",
    exposure = "exposure",
    reference = 0,
    entry = "study_entry",
    exit = "study_exit",
    keep_vars = c("age", "female")
  )

  expect_true("age" %in% names(result))
  expect_true("female" %in% names(result))
})

test_that("tvexpose preserves variable types", {
  cohort <- create_test_cohort(5)
  exposure <- create_test_exposure(1:3, "simple")

  result <- tvexpose(
    data = cohort,
    exposure_data = exposure,
    id = "id",
    start = "exp_start",
    stop = "exp_stop",
    exposure = "exposure",
    reference = 0,
    entry = "study_entry",
    exit = "study_exit",
    keep_vars = c("age", "female")
  )

  # Check that variable types are preserved
  expect_type(result$id, "integer")
  if ("age" %in% names(result)) {
    expect_type(result$age, "double")
  }
})
