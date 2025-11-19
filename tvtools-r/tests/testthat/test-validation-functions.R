# Test suite for input validation helper functions
# Tests each validation function independently to ensure proper error handling

library(testthat)
library(dplyr)

# Source the tvexpose.R file to load validation functions
source("../../R/tvexpose.R")

# ============================================================================
# HELPER FUNCTIONS FOR TESTING
# ============================================================================

create_basic_master <- function() {
  data.frame(
    id = 1:10,
    entry = as.Date("2010-01-01") + (0:9) * 30,
    exit = as.Date("2020-12-31"),
    age = 50 + (1:10),
    stringsAsFactors = FALSE
  )
}

create_basic_exposure <- function() {
  data.frame(
    id = 1:5,
    exp_start = as.Date("2011-01-01"),
    exp_stop = as.Date("2012-01-01"),
    exposure = rep(1, 5),
    stringsAsFactors = FALSE
  )
}

# ============================================================================
# TEST: validate_master_dataset()
# ============================================================================

test_that("validate_master_dataset accepts valid master dataset", {
  master <- create_basic_master()

  # Should not error on valid dataset
  expect_silent(validate_master_dataset(master, "id", "entry", "exit"))
})

test_that("validate_master_dataset rejects empty master dataset", {
  master <- create_basic_master()[0, ]  # Empty data frame

  expect_error(
    validate_master_dataset(master, "id", "entry", "exit"),
    "master dataset is empty"
  )
})

test_that("validate_master_dataset detects duplicate IDs", {
  master <- create_basic_master()
  master$id[5] <- master$id[1]  # Create duplicate

  expect_error(
    validate_master_dataset(master, "id", "entry", "exit"),
    "duplicate ID"
  )
})

test_that("validate_master_dataset validates ID type", {
  master <- create_basic_master()
  master$id <- factor(master$id)  # Invalid type

  expect_error(
    validate_master_dataset(master, "id", "entry", "exit"),
    "ID variable.*must be numeric or character"
  )
})

test_that("validate_master_dataset accepts character IDs", {
  master <- create_basic_master()
  master$id <- as.character(master$id)

  expect_silent(validate_master_dataset(master, "id", "entry", "exit"))
})

test_that("validate_master_dataset provides informative error for duplicates", {
  master <- create_basic_master()
  master$id[c(2, 3, 4)] <- master$id[1]  # Multiple duplicates

  error_msg <- tryCatch(
    validate_master_dataset(master, "id", "entry", "exit"),
    error = function(e) e$message
  )

  # Should mention count and examples
  expect_match(error_msg, "duplicate")
  expect_match(error_msg, "\\d+")  # Contains number
})

# ============================================================================
# TEST: validate_exposure_dataset()
# ============================================================================

test_that("validate_exposure_dataset accepts valid exposure dataset", {
  exposure <- create_basic_exposure()

  expect_silent(validate_exposure_dataset(exposure, "id", "exposure"))
})

test_that("validate_exposure_dataset accepts empty exposure dataset", {
  exposure <- create_basic_exposure()[0, ]

  # Should emit message but not error
  expect_message(
    validate_exposure_dataset(exposure, "id", "exposure"),
    "empty.*unexposed"
  )
})

test_that("validate_exposure_dataset validates ID type", {
  exposure <- create_basic_exposure()
  exposure$id <- factor(exposure$id)

  expect_error(
    validate_exposure_dataset(exposure, "id", "exposure"),
    "ID variable.*must be numeric or character"
  )
})

test_that("validate_exposure_dataset detects NA in exposure variable", {
  exposure <- create_basic_exposure()
  exposure$exposure[c(2, 4)] <- NA

  expect_error(
    validate_exposure_dataset(exposure, "id", "exposure"),
    "exposure variable.*contains.*NA"
  )
})

test_that("validate_exposure_dataset reports count of NA values", {
  exposure <- create_basic_exposure()
  exposure$exposure[1:3] <- NA

  error_msg <- tryCatch(
    validate_exposure_dataset(exposure, "id", "exposure"),
    error = function(e) e$message
  )

  # Should mention count (3)
  expect_match(error_msg, "3")
})

test_that("validate_exposure_dataset accepts character IDs", {
  exposure <- create_basic_exposure()
  exposure$id <- as.character(exposure$id)

  expect_silent(validate_exposure_dataset(exposure, "id", "exposure"))
})

# ============================================================================
# TEST: validate_id_type_match()
# ============================================================================

test_that("validate_id_type_match accepts matching numeric types", {
  master_id <- 1:10
  exposure_id <- 1:5

  expect_silent(validate_id_type_match(master_id, exposure_id, "id"))
})

test_that("validate_id_type_match accepts matching character types", {
  master_id <- as.character(1:10)
  exposure_id <- as.character(1:5)

  expect_silent(validate_id_type_match(master_id, exposure_id, "id"))
})

test_that("validate_id_type_match detects type mismatch", {
  master_id <- 1:10  # numeric
  exposure_id <- as.character(1:5)  # character

  expect_error(
    validate_id_type_match(master_id, exposure_id, "id"),
    "different types"
  )
})

test_that("validate_id_type_match shows both types in error", {
  master_id <- 1:10
  exposure_id <- as.character(1:5)

  error_msg <- tryCatch(
    validate_id_type_match(master_id, exposure_id, "id"),
    error = function(e) e$message
  )

  # Should show both types
  expect_match(error_msg, "numeric|integer")
  expect_match(error_msg, "character")
})

test_that("validate_id_type_match handles empty exposure", {
  master_id <- 1:10
  exposure_id <- integer(0)

  # Should still check types even if empty
  expect_silent(validate_id_type_match(master_id, exposure_id, "id"))
})

# ============================================================================
# TEST: validate_keepvars()
# ============================================================================

test_that("validate_keepvars accepts NULL keepvars", {
  master <- create_basic_master()

  expect_silent(validate_keepvars(master, NULL))
})

test_that("validate_keepvars accepts empty keepvars", {
  master <- create_basic_master()

  expect_silent(validate_keepvars(master, character(0)))
})

test_that("validate_keepvars accepts valid variable names", {
  master <- create_basic_master()

  expect_silent(validate_keepvars(master, c("age", "id")))
})

test_that("validate_keepvars detects missing variables", {
  master <- create_basic_master()

  expect_error(
    validate_keepvars(master, c("age", "nonexistent")),
    "not found"
  )
})

test_that("validate_keepvars lists all missing variables", {
  master <- create_basic_master()

  error_msg <- tryCatch(
    validate_keepvars(master, c("missing1", "age", "missing2")),
    error = function(e) e$message
  )

  # Should list both missing variables
  expect_match(error_msg, "missing1")
  expect_match(error_msg, "missing2")
})

# ============================================================================
# TEST: validate_duration()
# ============================================================================

test_that("validate_duration accepts NULL", {
  expect_silent(validate_duration(NULL))
})

test_that("validate_duration accepts valid numeric vector", {
  expect_silent(validate_duration(c(1, 5, 10)))
})

test_that("validate_duration accepts single value", {
  expect_silent(validate_duration(5))
})

test_that("validate_duration rejects non-numeric input", {
  expect_error(
    validate_duration(c("1", "5")),
    "must be a numeric vector"
  )
})

test_that("validate_duration rejects negative values", {
  expect_error(
    validate_duration(c(1, -5, 10)),
    "non-negative"
  )
})

test_that("validate_duration detects unsorted values", {
  expect_error(
    validate_duration(c(5, 1, 10)),
    "ascending order"
  )
})

test_that("validate_duration shows provided values in error", {
  error_msg <- tryCatch(
    validate_duration(c(5, 1, 10)),
    error = function(e) e$message
  )

  # Should show the values
  expect_match(error_msg, "5.*1.*10")
})

test_that("validate_duration detects duplicates", {
  expect_error(
    validate_duration(c(1, 5, 5, 10)),
    "unique"
  )
})

test_that("validate_duration accepts zero", {
  expect_silent(validate_duration(c(0, 1, 5)))
})

# ============================================================================
# TEST: validate_recency()
# ============================================================================

test_that("validate_recency accepts NULL", {
  expect_silent(validate_recency(NULL))
})

test_that("validate_recency accepts valid numeric vector", {
  expect_silent(validate_recency(c(1, 5, 10)))
})

test_that("validate_recency accepts single value", {
  expect_silent(validate_recency(5))
})

test_that("validate_recency rejects non-numeric input", {
  expect_error(
    validate_recency(c("1", "5")),
    "must be a numeric vector"
  )
})

test_that("validate_recency rejects negative values", {
  expect_error(
    validate_recency(c(1, -5, 10)),
    "non-negative"
  )
})

test_that("validate_recency detects unsorted values", {
  expect_error(
    validate_recency(c(5, 1, 10)),
    "ascending order"
  )
})

test_that("validate_recency shows provided values in error", {
  error_msg <- tryCatch(
    validate_recency(c(5, 1, 10)),
    error = function(e) e$message
  )

  # Should show the values
  expect_match(error_msg, "5.*1.*10")
})

test_that("validate_recency detects duplicates", {
  expect_error(
    validate_recency(c(1, 5, 5, 10)),
    "unique"
  )
})

test_that("validate_recency accepts zero", {
  expect_silent(validate_recency(c(0, 1, 5)))
})

# ============================================================================
# TEST: validate_no_conflicting_exposure_types()
# ============================================================================

test_that("validate_no_conflicting_exposure_types accepts no exposure types", {
  expect_silent(
    validate_no_conflicting_exposure_types(
      evertreated = FALSE,
      currentformer = FALSE,
      duration = NULL,
      recency = NULL,
      continuousunit = NULL
    )
  )
})

test_that("validate_no_conflicting_exposure_types accepts evertreated only", {
  expect_silent(
    validate_no_conflicting_exposure_types(
      evertreated = TRUE,
      currentformer = FALSE,
      duration = NULL,
      recency = NULL,
      continuousunit = NULL
    )
  )
})

test_that("validate_no_conflicting_exposure_types accepts currentformer only", {
  expect_silent(
    validate_no_conflicting_exposure_types(
      evertreated = FALSE,
      currentformer = TRUE,
      duration = NULL,
      recency = NULL,
      continuousunit = NULL
    )
  )
})

test_that("validate_no_conflicting_exposure_types accepts duration only", {
  expect_silent(
    validate_no_conflicting_exposure_types(
      evertreated = FALSE,
      currentformer = FALSE,
      duration = c(1, 5),
      recency = NULL,
      continuousunit = NULL
    )
  )
})

test_that("validate_no_conflicting_exposure_types accepts recency only", {
  expect_silent(
    validate_no_conflicting_exposure_types(
      evertreated = FALSE,
      currentformer = FALSE,
      duration = NULL,
      recency = c(1, 5),
      continuousunit = NULL
    )
  )
})

test_that("validate_no_conflicting_exposure_types accepts continuousunit only", {
  expect_silent(
    validate_no_conflicting_exposure_types(
      evertreated = FALSE,
      currentformer = FALSE,
      duration = NULL,
      recency = NULL,
      continuousunit = "years"
    )
  )
})

test_that("validate_no_conflicting_exposure_types rejects multiple types", {
  expect_error(
    validate_no_conflicting_exposure_types(
      evertreated = TRUE,
      currentformer = TRUE,
      duration = NULL,
      recency = NULL,
      continuousunit = NULL
    ),
    "Only one exposure type"
  )
})

test_that("validate_no_conflicting_exposure_types lists conflicting types", {
  error_msg <- tryCatch(
    validate_no_conflicting_exposure_types(
      evertreated = TRUE,
      currentformer = FALSE,
      duration = c(1, 5),
      recency = c(1, 5),
      continuousunit = NULL
    ),
    error = function(e) e$message
  )

  # Should list the active types
  expect_match(error_msg, "evertreated")
  expect_match(error_msg, "duration")
  expect_match(error_msg, "recency")
})

test_that("validate_no_conflicting_exposure_types handles all types active", {
  expect_error(
    validate_no_conflicting_exposure_types(
      evertreated = TRUE,
      currentformer = TRUE,
      duration = c(1, 5),
      recency = c(1, 5),
      continuousunit = "years"
    ),
    "Only one exposure type"
  )
})

# ============================================================================
# INTEGRATION TESTS: Validation functions called from tvexpose()
# ============================================================================

test_that("tvexpose calls validate_master_dataset and catches errors", {
  # Empty master should trigger validation error
  master <- create_basic_master()[0, ]
  exposure <- create_basic_exposure()

  expect_error(
    tvexpose(
      master = master,
      exposure_data = exposure,
      id = "id",
      start = "exp_start",
      stop = "exp_stop",
      exposure = "exposure",
      reference = 0,
      entry = "entry",
      exit = "exit"
    ),
    "master dataset is empty"
  )
})

test_that("tvexpose calls validate_exposure_dataset and catches NA errors", {
  master <- create_basic_master()
  exposure <- create_basic_exposure()
  exposure$exposure[1] <- NA

  expect_error(
    tvexpose(
      master = master,
      exposure_data = exposure,
      id = "id",
      start = "exp_start",
      stop = "exp_stop",
      exposure = "exposure",
      reference = 0,
      entry = "entry",
      exit = "exit"
    ),
    "exposure variable.*contains.*NA"
  )
})

test_that("tvexpose calls validate_id_type_match and catches mismatches", {
  master <- create_basic_master()
  exposure <- create_basic_exposure()
  exposure$id <- as.character(exposure$id)  # Type mismatch

  expect_error(
    tvexpose(
      master = master,
      exposure_data = exposure,
      id = "id",
      start = "exp_start",
      stop = "exp_stop",
      exposure = "exposure",
      reference = 0,
      entry = "entry",
      exit = "exit"
    ),
    "different types"
  )
})

test_that("tvexpose calls validate_keepvars and catches missing variables", {
  master <- create_basic_master()
  exposure <- create_basic_exposure()

  expect_error(
    tvexpose(
      master = master,
      exposure_data = exposure,
      id = "id",
      start = "exp_start",
      stop = "exp_stop",
      exposure = "exposure",
      reference = 0,
      entry = "entry",
      exit = "exit",
      keepvars = c("age", "nonexistent")
    ),
    "not found"
  )
})

test_that("tvexpose calls validate_duration and catches invalid cutpoints", {
  master <- create_basic_master()
  exposure <- create_basic_exposure()

  expect_error(
    tvexpose(
      master = master,
      exposure_data = exposure,
      id = "id",
      start = "exp_start",
      stop = "exp_stop",
      exposure = "exposure",
      reference = 0,
      entry = "entry",
      exit = "exit",
      duration = c(5, 1, 10)  # Not sorted
    ),
    "ascending order"
  )
})

test_that("tvexpose calls validate_recency and catches invalid cutpoints", {
  master <- create_basic_master()
  exposure <- create_basic_exposure()

  expect_error(
    tvexpose(
      master = master,
      exposure_data = exposure,
      id = "id",
      start = "exp_start",
      stop = "exp_stop",
      exposure = "exposure",
      reference = 0,
      entry = "entry",
      exit = "exit",
      recency = c(-1, 5)  # Negative value
    ),
    "non-negative"
  )
})

test_that("tvexpose calls validate_no_conflicting_exposure_types", {
  master <- create_basic_master()
  exposure <- create_basic_exposure()

  expect_error(
    tvexpose(
      master = master,
      exposure_data = exposure,
      id = "id",
      start = "exp_start",
      stop = "exp_stop",
      exposure = "exposure",
      reference = 0,
      entry = "entry",
      exit = "exit",
      evertreated = TRUE,
      currentformer = TRUE  # Conflicting types
    ),
    "Only one exposure type"
  )
})
