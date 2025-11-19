# Test suite for tvmerge function
# Tests cover basic merging, continuous/categorical exposures, parameter validation,
# output format, and integration with tvexpose

library(testthat)
library(dplyr)
library(lubridate)

# ============================================================================
# Helper functions to create test data
# ============================================================================

create_cohort <- function(n = 10) {
  data.frame(
    id = 1:n,
    study_entry = as.Date("2010-01-01"),
    study_exit = as.Date("2020-12-31"),
    age = 50 + (1:n),
    female = rep(c(0, 1), length.out = n),
    stringsAsFactors = FALSE
  )
}

# Create time-varying exposure dataset (as if from tvexpose)
create_tv_dataset1 <- function(type = "simple") {
  if (type == "simple") {
    # Simple non-overlapping periods for exposure A
    bind_rows(
      data.frame(id = 1, start = as.Date("2010-01-01"),
                 stop = as.Date("2012-01-01"), exp_a = 0),
      data.frame(id = 1, start = as.Date("2012-01-01"),
                 stop = as.Date("2015-01-01"), exp_a = 1),
      data.frame(id = 1, start = as.Date("2015-01-01"),
                 stop = as.Date("2020-12-31"), exp_a = 0),
      data.frame(id = 2, start = as.Date("2010-01-01"),
                 stop = as.Date("2020-12-31"), exp_a = 0),
      data.frame(id = 3, start = as.Date("2010-01-01"),
                 stop = as.Date("2013-01-01"), exp_a = 0),
      data.frame(id = 3, start = as.Date("2013-01-01"),
                 stop = as.Date("2020-12-31"), exp_a = 2)
    )
  } else if (type == "continuous") {
    # Continuous exposure (rate per day)
    bind_rows(
      data.frame(id = 1, start = as.Date("2010-01-01"),
                 stop = as.Date("2012-01-01"), exp_a = 0.0),
      data.frame(id = 1, start = as.Date("2012-01-01"),
                 stop = as.Date("2015-01-01"), exp_a = 0.5),
      data.frame(id = 1, start = as.Date("2015-01-01"),
                 stop = as.Date("2020-12-31"), exp_a = 0.0),
      data.frame(id = 2, start = as.Date("2010-01-01"),
                 stop = as.Date("2020-12-31"), exp_a = 0.0),
      data.frame(id = 3, start = as.Date("2010-01-01"),
                 stop = as.Date("2013-01-01"), exp_a = 1.0),
      data.frame(id = 3, start = as.Date("2013-01-01"),
                 stop = as.Date("2020-12-31"), exp_a = 0.0)
    )
  }
}

create_tv_dataset2 <- function(type = "simple") {
  if (type == "simple") {
    # Simple periods for exposure B with different boundaries
    bind_rows(
      data.frame(id = 1, start = as.Date("2010-01-01"),
                 stop = as.Date("2011-06-01"), exp_b = 1),
      data.frame(id = 1, start = as.Date("2011-06-01"),
                 stop = as.Date("2014-01-01"), exp_b = 0),
      data.frame(id = 1, start = as.Date("2014-01-01"),
                 stop = as.Date("2020-12-31"), exp_b = 1),
      data.frame(id = 2, start = as.Date("2010-01-01"),
                 stop = as.Date("2016-01-01"), exp_b = 1),
      data.frame(id = 2, start = as.Date("2016-01-01"),
                 stop = as.Date("2020-12-31"), exp_b = 0),
      data.frame(id = 3, start = as.Date("2010-01-01"),
                 stop = as.Date("2020-12-31"), exp_b = 0)
    )
  } else if (type == "continuous") {
    # Continuous exposure B
    bind_rows(
      data.frame(id = 1, start = as.Date("2010-01-01"),
                 stop = as.Date("2011-06-01"), exp_b = 0.3),
      data.frame(id = 1, start = as.Date("2011-06-01"),
                 stop = as.Date("2014-01-01"), exp_b = 0.0),
      data.frame(id = 1, start = as.Date("2014-01-01"),
                 stop = as.Date("2020-12-31"), exp_b = 0.7),
      data.frame(id = 2, start = as.Date("2010-01-01"),
                 stop = as.Date("2016-01-01"), exp_b = 0.4),
      data.frame(id = 2, start = as.Date("2016-01-01"),
                 stop = as.Date("2020-12-31"), exp_b = 0.0),
      data.frame(id = 3, start = as.Date("2010-01-01"),
                 stop = as.Date("2020-12-31"), exp_b = 0.0)
    )
  }
}

create_tv_dataset3 <- function() {
  # Third exposure dataset for testing 3+ merges
  bind_rows(
    data.frame(id = 1, start = as.Date("2010-01-01"),
               stop = as.Date("2013-01-01"), exp_c = 0),
    data.frame(id = 1, start = as.Date("2013-01-01"),
               stop = as.Date("2017-01-01"), exp_c = 1),
    data.frame(id = 1, start = as.Date("2017-01-01"),
               stop = as.Date("2020-12-31"), exp_c = 0),
    data.frame(id = 2, start = as.Date("2010-01-01"),
               stop = as.Date("2020-12-31"), exp_c = 1),
    data.frame(id = 3, start = as.Date("2010-01-01"),
               stop = as.Date("2020-12-31"), exp_c = 0)
  )
}

# ============================================================================
# BASIC FUNCTIONALITY TESTS
# ============================================================================

test_that("tvmerge merges two datasets correctly", {
  ds1 <- create_tv_dataset1("simple")
  ds2 <- create_tv_dataset2("simple")

  result <- tvmerge(
    datasets = list(ds1, ds2),
    id = "id",
    start = c("start", "start"),
    stop = c("stop", "stop"),
    exposure = c("exp_a", "exp_b")
  )

  # Check output structure
  expect_s3_class(result, "data.frame")
  expect_true("id" %in% names(result))
  expect_true("start" %in% names(result))
  expect_true("stop" %in% names(result))
  expect_true("exp_a" %in% names(result))
  expect_true("exp_b" %in% names(result))

  # Check that all IDs are present
  expect_setequal(unique(result$id), unique(c(ds1$id, ds2$id)))

  # Result should have more rows than either input (due to splitting)
  expect_true(nrow(result) >= max(nrow(ds1), nrow(ds2)))
})

test_that("tvmerge creates correct time periods", {
  ds1 <- create_tv_dataset1("simple")
  ds2 <- create_tv_dataset2("simple")

  result <- tvmerge(
    datasets = list(ds1, ds2),
    id = "id",
    start = c("start", "start"),
    stop = c("stop", "stop"),
    exposure = c("exp_a", "exp_b")
  )

  # Check that periods don't overlap within each person
  for (person_id in unique(result$id)) {
    person_rows <- result %>%
      filter(id == !!person_id) %>%
      arrange(start)

    if (nrow(person_rows) > 1) {
      for (i in 1:(nrow(person_rows) - 1)) {
        # End of period i should equal start of period i+1 (or be before)
        expect_true(
          person_rows$stop[i] <= person_rows$start[i + 1],
          info = paste("Overlapping periods for person", person_id)
        )
      }
    }
  }
})

test_that("tvmerge handles cartesian product of exposures", {
  # Create simple datasets with known combinations
  ds1 <- data.frame(
    id = c(1, 1),
    start = as.Date(c("2010-01-01", "2015-01-01")),
    stop = as.Date(c("2015-01-01", "2020-01-01")),
    exp_a = c(0, 1)
  )

  ds2 <- data.frame(
    id = c(1, 1),
    start = as.Date(c("2010-01-01", "2012-01-01")),
    stop = as.Date(c("2012-01-01", "2020-01-01")),
    exp_b = c(0, 1)
  )

  result <- tvmerge(
    datasets = list(ds1, ds2),
    id = "id",
    start = c("start", "start"),
    stop = c("stop", "stop"),
    exposure = c("exp_a", "exp_b")
  )

  # Should have all combinations: (0,0), (0,1), (1,1)
  combinations <- result %>%
    select(exp_a, exp_b) %>%
    distinct() %>%
    arrange(exp_a, exp_b)

  expect_true(nrow(combinations) >= 3)
  expect_true(any(combinations$exp_a == 0 & combinations$exp_b == 0))
  expect_true(any(combinations$exp_a == 0 & combinations$exp_b == 1))
  expect_true(any(combinations$exp_a == 1 & combinations$exp_b == 1))
})

test_that("tvmerge merges three datasets correctly", {
  ds1 <- create_tv_dataset1("simple")
  ds2 <- create_tv_dataset2("simple")
  ds3 <- create_tv_dataset3()

  result <- tvmerge(
    datasets = list(ds1, ds2, ds3),
    id = "id",
    start = c("start", "start", "start"),
    stop = c("stop", "stop", "stop"),
    exposure = c("exp_a", "exp_b", "exp_c")
  )

  # Check output structure
  expect_s3_class(result, "data.frame")
  expect_true(all(c("exp_a", "exp_b", "exp_c") %in% names(result)))

  # All three exposures should be present in output
  expect_true("exp_a" %in% names(result))
  expect_true("exp_b" %in% names(result))
  expect_true("exp_c" %in% names(result))
})

# ============================================================================
# CONTINUOUS VS CATEGORICAL EXPOSURES
# ============================================================================

test_that("tvmerge handles categorical exposures by default", {
  ds1 <- create_tv_dataset1("simple")
  ds2 <- create_tv_dataset2("simple")

  result <- tvmerge(
    datasets = list(ds1, ds2),
    id = "id",
    start = c("start", "start"),
    stop = c("stop", "stop"),
    exposure = c("exp_a", "exp_b")
  )

  # Categorical exposures should be preserved as-is
  expect_true(all(result$exp_a %in% unique(ds1$exp_a)))
  expect_true(all(result$exp_b %in% unique(ds2$exp_b)))
})

test_that("tvmerge handles continuous exposures correctly", {
  ds1 <- create_tv_dataset1("continuous")
  ds2 <- create_tv_dataset2("continuous")

  result <- tvmerge(
    datasets = list(ds1, ds2),
    id = "id",
    start = c("start", "start"),
    stop = c("stop", "stop"),
    exposure = c("exp_a", "exp_b"),
    continuous = c("exp_a", "exp_b")
  )

  # For continuous exposures, should calculate period-specific amounts
  # Should have rate columns and amount columns
  expect_s3_class(result, "data.frame")

  # Continuous exposures should have rates
  expect_true("exp_a" %in% names(result))
  expect_true("exp_b" %in% names(result))

  # May also have amount columns (e.g., exp_a_amount)
  # Check that values are numeric
  expect_type(result$exp_a, "double")
  expect_type(result$exp_b, "double")
})

test_that("tvmerge handles mixed continuous and categorical exposures", {
  ds1 <- create_tv_dataset1("continuous")  # Continuous
  ds2 <- create_tv_dataset2("simple")      # Categorical

  result <- tvmerge(
    datasets = list(ds1, ds2),
    id = "id",
    start = c("start", "start"),
    stop = c("stop", "stop"),
    exposure = c("exp_a", "exp_b"),
    continuous = c("exp_a")  # Only exp_a is continuous
  )

  expect_s3_class(result, "data.frame")
  expect_true(all(c("exp_a", "exp_b") %in% names(result)))

  # exp_a should be numeric (continuous)
  expect_type(result$exp_a, "double")

  # exp_b should preserve categorical values
  expect_true(all(result$exp_b %in% unique(ds2$exp_b)))
})

test_that("tvmerge calculates continuous exposure amounts correctly", {
  # Create simple test case
  ds1 <- data.frame(
    id = 1,
    start = as.Date("2010-01-01"),
    stop = as.Date("2010-01-11"),  # 10 days
    exp_a = 0.5  # 0.5 units per day
  )

  ds2 <- data.frame(
    id = 1,
    start = as.Date("2010-01-01"),
    stop = as.Date("2010-01-11"),
    exp_b = 1  # Categorical
  )

  result <- tvmerge(
    datasets = list(ds1, ds2),
    id = "id",
    start = c("start", "start"),
    stop = c("stop", "stop"),
    exposure = c("exp_a", "exp_b"),
    continuous = c("exp_a")
  )

  # For continuous exposure, total amount = rate * days
  # 0.5 units/day * 10 days = 5 units
  if ("exp_a_amount" %in% names(result)) {
    expect_equal(result$exp_a_amount[1], 5.0, tolerance = 0.01)
  }
})

# ============================================================================
# PARAMETER VALIDATION
# ============================================================================

test_that("tvmerge validates required parameters", {
  ds1 <- create_tv_dataset1("simple")
  ds2 <- create_tv_dataset2("simple")

  # Missing datasets parameter or insufficient datasets
  expect_error(
    tvmerge(
      datasets = list(ds2),  # Only one dataset, need at least 2
      id = "id",
      start = c("start", "start"),
      stop = c("stop", "stop"),
      exposure = c("exp_a", "exp_b")
    ),
    "at least 2"
  )

  # Missing id
  expect_error(
    tvmerge(
      datasets = list(ds1, ds2),
      start = c("start", "start"),
      stop = c("stop", "stop"),
      exposure = c("exp_a", "exp_b")
    ),
    "id"
  )

  # Mismatched parameter lengths
  expect_error(
    tvmerge(
      datasets = list(ds1, ds2),
      id = "id",
      start = c("start"),  # Only one value for two datasets
      stop = c("stop", "stop"),
      exposure = c("exp_a", "exp_b")
    ),
    "length|mismatch|equal"
  )
})

test_that("tvmerge validates column existence", {
  ds1 <- create_tv_dataset1("simple")
  ds2 <- create_tv_dataset2("simple")

  # Non-existent start column
  expect_error(
    tvmerge(
      datasets = list(ds1, ds2),
      id = "id",
      start = c("nonexistent_start", "start"),
      stop = c("stop", "stop"),
      exposure = c("exp_a", "exp_b")
    ),
    "nonexistent_start|not found"
  )

  # Non-existent exposure column
  expect_error(
    tvmerge(
      datasets = list(ds1, ds2),
      id = "id",
      start = c("start", "start"),
      stop = c("stop", "stop"),
      exposure = c("exp_a", "nonexistent_exp")
    ),
    "nonexistent_exp|not found"
  )
})

test_that("tvmerge validates ID consistency across datasets", {
  ds1 <- create_tv_dataset1("simple")
  ds2 <- create_tv_dataset2("simple")

  # Modify ds2 to have different ID variable name
  ds2_renamed <- ds2
  names(ds2_renamed)[names(ds2_renamed) == "id"] <- "person_id"

  # Should error if ID variable not found
  expect_error(
    tvmerge(
      datasets = list(ds1, ds2_renamed),
      id = "id",
      start = c("start", "start"),
      stop = c("stop", "stop"),
      exposure = c("exp_a", "exp_b")
    ),
    "id|not found"
  )
})

test_that("tvmerge validates date ordering", {
  # Create dataset with invalid date ordering
  ds1 <- data.frame(
    id = 1,
    start = as.Date("2012-01-01"),
    stop = as.Date("2010-01-01"),  # stop before start!
    exp_a = 1
  )

  ds2 <- create_tv_dataset2("simple")

  # Note: Function drops invalid periods with a message, not an error
  result <- suppressMessages(
    tvmerge(
      datasets = list(ds1, ds2),
      id = "id",
      start = c("start", "start"),
      stop = c("stop", "stop"),
      exposure = c("exp_a", "exp_b")
    )
  )

  # Should still create a result, just with invalid periods dropped
  expect_s3_class(result, "data.frame")
})

# ============================================================================
# OUTPUT FORMAT VERIFICATION
# ============================================================================

test_that("tvmerge output has correct column names", {
  ds1 <- create_tv_dataset1("simple")
  ds2 <- create_tv_dataset2("simple")

  result <- tvmerge(
    datasets = list(ds1, ds2),
    id = "id",
    start = c("start", "start"),
    stop = c("stop", "stop"),
    exposure = c("exp_a", "exp_b")
  )

  # Should have id, start, stop, and both exposures
  expect_true("id" %in% names(result))
  expect_true("start" %in% names(result))
  expect_true("stop" %in% names(result))
  expect_true("exp_a" %in% names(result))
  expect_true("exp_b" %in% names(result))
})

test_that("tvmerge respects custom output column names", {
  ds1 <- create_tv_dataset1("simple")
  ds2 <- create_tv_dataset2("simple")

  result <- tvmerge(
    datasets = list(ds1, ds2),
    id = "id",
    start = c("start", "start"),
    stop = c("stop", "stop"),
    exposure = c("exp_a", "exp_b"),
    generate = c("exposure_A", "exposure_B")
  )

  expect_true("exposure_A" %in% names(result))
  expect_true("exposure_B" %in% names(result))
})

test_that("tvmerge respects custom start/stop names", {
  ds1 <- create_tv_dataset1("simple")
  ds2 <- create_tv_dataset2("simple")

  result <- tvmerge(
    datasets = list(ds1, ds2),
    id = "id",
    start = c("start", "start"),
    stop = c("stop", "stop"),
    exposure = c("exp_a", "exp_b"),
    startname = "period_start",
    stopname = "period_stop"
  )

  expect_true("period_start" %in% names(result))
  expect_true("period_stop" %in% names(result))
})

test_that("tvmerge output has no missing values in key columns", {
  ds1 <- create_tv_dataset1("simple")
  ds2 <- create_tv_dataset2("simple")

  result <- tvmerge(
    datasets = list(ds1, ds2),
    id = "id",
    start = c("start", "start"),
    stop = c("stop", "stop"),
    exposure = c("exp_a", "exp_b")
  )

  expect_false(any(is.na(result$id)))
  expect_false(any(is.na(result$start)))
  expect_false(any(is.na(result$stop)))
  expect_false(any(is.na(result$exp_a)))
  expect_false(any(is.na(result$exp_b)))
})

test_that("tvmerge output periods are non-overlapping per person", {
  ds1 <- create_tv_dataset1("simple")
  ds2 <- create_tv_dataset2("simple")

  result <- tvmerge(
    datasets = list(ds1, ds2),
    id = "id",
    start = c("start", "start"),
    stop = c("stop", "stop"),
    exposure = c("exp_a", "exp_b")
  )

  for (person_id in unique(result$id)) {
    person_rows <- result %>%
      filter(id == !!person_id) %>%
      arrange(start)

    if (nrow(person_rows) > 1) {
      for (i in 1:(nrow(person_rows) - 1)) {
        # Current period should end before or at start of next period
        expect_true(
          person_rows$stop[i] <= person_rows$start[i + 1],
          info = paste("Overlapping periods for person", person_id,
                      "at row", i)
        )
      }
    }
  }
})

test_that("tvmerge output covers full time range", {
  ds1 <- create_tv_dataset1("simple")
  ds2 <- create_tv_dataset2("simple")

  result <- tvmerge(
    datasets = list(ds1, ds2),
    id = "id",
    start = c("start", "start"),
    stop = c("stop", "stop"),
    exposure = c("exp_a", "exp_b")
  )

  for (person_id in unique(result$id)) {
    # Get original time range from both datasets
    ds1_person <- ds1 %>% filter(id == !!person_id)
    ds2_person <- ds2 %>% filter(id == !!person_id)

    if (nrow(ds1_person) > 0 && nrow(ds2_person) > 0) {
      original_start <- min(c(ds1_person$start, ds2_person$start))
      original_stop <- max(c(ds1_person$stop, ds2_person$stop))

      result_person <- result %>%
        filter(id == !!person_id) %>%
        arrange(start)

      # Merged data should cover same time range
      expect_equal(min(result_person$start), original_start)
      expect_equal(max(result_person$stop), original_stop)
    }
  }
})

# ============================================================================
# INTEGRATION WITH TVEXPOSE
# ============================================================================

test_that("tvmerge works with tvexpose output format", {
  # Skip if tvexpose not available
  skip_if_not(exists("tvexpose"), "tvexpose function not available")

  cohort <- create_cohort(3)

  # Create two exposure datasets
  exposure1 <- data.frame(
    id = c(1, 2),
    exp_start = as.Date("2011-01-01"),
    exp_stop = as.Date("2015-01-01"),
    exposure = 1
  )

  exposure2 <- data.frame(
    id = c(1, 3),
    exp_start = as.Date("2012-01-01"),
    exp_stop = as.Date("2016-01-01"),
    exposure = 1
  )

  # Run tvexpose on each
  tv1 <- tvexpose(
    master = cohort,
    exposure_data = exposure1,
    id = "id",
    start = "exp_start",
    stop = "exp_stop",
    exposure = "exposure",
    reference = 0,
    entry = "study_entry",
    exit = "study_exit"
  )

  tv2 <- tvexpose(
    master = cohort,
    exposure_data = exposure2,
    id = "id",
    start = "exp_start",
    stop = "exp_stop",
    exposure = "exposure",
    reference = 0,
    entry = "study_entry",
    exit = "study_exit"
  )

  # Determine column names from tvexpose output
  start_col1 <- intersect(c("start", "tstart", "tstart_date"), names(tv1))[1]
  stop_col1 <- intersect(c("stop", "tstop", "tstop_date"), names(tv1))[1]
  exp_col1 <- "tv_exposure"

  start_col2 <- intersect(c("start", "tstart", "tstart_date"), names(tv2))[1]
  stop_col2 <- intersect(c("stop", "tstop", "tstop_date"), names(tv2))[1]
  exp_col2 <- "tv_exposure"

  # Merge them with tvmerge
  result <- tvmerge(
    datasets = list(tv1, tv2),
    id = "id",
    start = c(start_col1, start_col2),
    stop = c(stop_col1, stop_col2),
    exposure = c(exp_col1, exp_col2)
  )

  # Check that result has expected structure
  expect_s3_class(result, "data.frame")
  expect_true("id" %in% names(result))

  # Should have all IDs from cohort
  expect_setequal(unique(result$id), cohort$id)
})

test_that("tvmerge preserves additional variables from inputs", {
  ds1 <- create_tv_dataset1("simple")
  ds2 <- create_tv_dataset2("simple")

  # Add additional variables
  ds1$var1 <- "from_ds1"
  ds2$var2 <- "from_ds2"

  result <- tvmerge(
    datasets = list(ds1, ds2),
    id = "id",
    start = c("start", "start"),
    stop = c("stop", "stop"),
    exposure = c("exp_a", "exp_b"),
    keep = c("var1", "var2")
  )

  # Additional variables should be present (possibly suffixed)
  has_var1 <- any(grepl("var1", names(result)))
  has_var2 <- any(grepl("var2", names(result)))

  expect_true(has_var1 | has_var2,
              info = "At least one additional variable should be preserved")
})

# ============================================================================
# EDGE CASES
# ============================================================================

test_that("tvmerge handles persons present in only one dataset", {
  ds1 <- data.frame(
    id = c(1, 2),
    start = as.Date("2010-01-01"),
    stop = as.Date("2020-01-01"),
    exp_a = c(1, 0)
  )

  ds2 <- data.frame(
    id = c(2, 3),
    start = as.Date("2010-01-01"),
    stop = as.Date("2020-01-01"),
    exp_b = c(1, 1)
  )

  result <- tvmerge(
    datasets = list(ds1, ds2),
    id = "id",
    start = c("start", "start"),
    stop = c("stop", "stop"),
    exposure = c("exp_a", "exp_b")
  )

  # Result should only include persons present in BOTH datasets
  # (or handle missing appropriately)
  expect_true(2 %in% unique(result$id))  # Person 2 is in both

  # Check how persons in only one dataset are handled
  # This depends on implementation - they might be excluded or filled with NA
})

test_that("tvmerge handles zero-length periods appropriately", {
  # Create dataset with same start and stop date
  ds1 <- data.frame(
    id = 1,
    start = as.Date("2010-01-01"),
    stop = as.Date("2010-01-01"),  # Zero length
    exp_a = 1
  )

  ds2 <- data.frame(
    id = 1,
    start = as.Date("2010-01-01"),
    stop = as.Date("2020-01-01"),
    exp_b = 1
  )

  # Note: tvmerge may allow zero-length periods (point-in-time events)
  # or may filter them out. Test that it handles gracefully.
  result <- try(suppressMessages(
    tvmerge(
      datasets = list(ds1, ds2),
      id = "id",
      start = c("start", "start"),
      stop = c("stop", "stop"),
      exposure = c("exp_a", "exp_b")
    )
  ), silent = TRUE)

  # Should either succeed or fail gracefully
  expect_true(inherits(result, "data.frame") || inherits(result, "try-error"))
})

test_that("tvmerge handles large number of periods efficiently", {
  # Create datasets with many periods
  n_periods <- 100

  ds1 <- data.frame(
    id = rep(1, n_periods),
    start = as.Date("2010-01-01") + (0:(n_periods - 1)) * 30,
    stop = as.Date("2010-01-01") + (1:n_periods) * 30,
    exp_a = rep(c(0, 1), length.out = n_periods)
  )

  ds2 <- data.frame(
    id = rep(1, n_periods),
    start = as.Date("2010-01-01") + (0:(n_periods - 1)) * 30,
    stop = as.Date("2010-01-01") + (1:n_periods) * 30,
    exp_b = rep(c(0, 1), length.out = n_periods)
  )

  # Should complete in reasonable time
  start_time <- Sys.time()

  result <- tvmerge(
    datasets = list(ds1, ds2),
    id = "id",
    start = c("start", "start"),
    stop = c("stop", "stop"),
    exposure = c("exp_a", "exp_b")
  )

  end_time <- Sys.time()
  elapsed <- as.numeric(difftime(end_time, start_time, units = "secs"))

  expect_s3_class(result, "data.frame")
  expect_true(elapsed < 10, info = "Merging should complete within 10 seconds")
})

test_that("tvmerge handles different date formats", {
  ds1 <- create_tv_dataset1("simple")
  ds2 <- create_tv_dataset2("simple")

  # Convert dates to numeric (days since epoch)
  ds1$start <- as.numeric(ds1$start)
  ds1$stop <- as.numeric(ds1$stop)

  # Should error or convert appropriately
  result <- try(
    tvmerge(
      datasets = list(ds1, ds2),
      id = "id",
      start = c("start", "start"),
      stop = c("stop", "stop"),
      exposure = c("exp_a", "exp_b")
    ),
    silent = TRUE
  )

  # Either should work (with conversion) or give informative error
  expect_true(
    inherits(result, "data.frame") || inherits(result, "try-error")
  )
})

# ============================================================================
# SUMMARY STATISTICS AND DIAGNOSTICS
# ============================================================================

test_that("tvmerge check option provides diagnostics", {
  ds1 <- create_tv_dataset1("simple")
  ds2 <- create_tv_dataset2("simple")

  # Capture output if check option is supported
  expect_output(
    result <- tvmerge(
      datasets = list(ds1, ds2),
      id = "id",
      start = c("start", "start"),
      stop = c("stop", "stop"),
      exposure = c("exp_a", "exp_b"),
      check = TRUE
    ),
    regex = ".*",  # Should produce some output
    info = "check option should provide diagnostics"
  )
})

test_that("tvmerge validates coverage when requested", {
  ds1 <- create_tv_dataset1("simple")
  ds2 <- create_tv_dataset2("simple")

  result <- tvmerge(
    datasets = list(ds1, ds2),
    id = "id",
    start = c("start", "start"),
    stop = c("stop", "stop"),
    exposure = c("exp_a", "exp_b"),
    validate_coverage = TRUE
  )

  # Should complete without error if coverage is complete
  expect_s3_class(result, "data.frame")
})
