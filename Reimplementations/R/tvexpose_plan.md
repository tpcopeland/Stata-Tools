# tvexpose R Reimplementation Plan

**Version:** 1.0.0
**Date:** 2025-12-02
**Target:** Complete R reimplementation of Stata tvexpose command

---

## Executive Summary

The `tvexpose` command creates time-varying exposure variables for survival analysis from period-based exposure data. This is a complex command with ~4000 lines of Stata code implementing multiple algorithms for period merging, overlap resolution, gap filling, and various exposure definitions (ever-treated, current/former, duration categories, continuous cumulative exposure, recency).

This plan provides extremely detailed specifications for R reimplementation using `data.table` for performance and `tidyverse` for user-friendly interfaces.

---

## Table of Contents

1. [Function Signature](#1-function-signature)
2. [Data Structures](#2-data-structures)
3. [Input Validation](#3-input-validation)
4. [Core Algorithms](#4-core-algorithms)
5. [Exposure Type Implementations](#5-exposure-type-implementations)
6. [Helper Functions](#6-helper-functions)
7. [Return Value Structure](#7-return-value-structure)
8. [Error Handling](#8-error-handling)
9. [Testing Strategy](#9-testing-strategy)
10. [Example Usage](#10-example-usage)
11. [Performance Considerations](#11-performance-considerations)

---

## 1. Function Signature

```r
tvexpose <- function(
  # Required parameters
  master_data,                    # Data frame: cohort with entry/exit dates
  exposure_file,                  # String path OR data frame: exposure periods
  id,                             # String: person identifier column name
  start,                          # String: exposure start date column name
  exposure,                       # String: exposure type column name
  reference,                      # Numeric: value indicating unexposed status
  entry,                          # String: study entry date column name
  exit,                           # String: study exit date column name

  # Core options
  stop = NULL,                    # String: exposure stop date column (required unless pointtime=TRUE)
  pointtime = FALSE,              # Logical: data are point-in-time (start only)

  # Exposure definition options (mutually exclusive)
  evertreated = FALSE,            # Logical: binary ever/never exposed
  currentformer = FALSE,          # Logical: trichotomous never/current/former
  duration = NULL,                # Numeric vector: cumulative duration cutpoints
  continuousunit = NULL,          # String: "days", "weeks", "months", "quarters", "years"
  expandunit = NULL,              # String: row expansion granularity
  bytype = FALSE,                 # Logical: create separate vars per exposure type
  recency = NULL,                 # Numeric vector: time since last exposure cutpoints

  # Data handling options
  grace = 0,                      # Numeric OR named list: grace period(s) in days
  merge_days = 120,               # Numeric: days to merge same-type periods
  fillgaps = 0,                   # Numeric: assume exposure continues N days beyond last record
  carryforward = 0,               # Numeric: carry forward exposure N days through gaps

  # Competing exposures options (mutually exclusive)
  priority = NULL,                # Numeric vector: priority order (highest first)
  split = FALSE,                  # Logical: split at all boundaries
  layer = TRUE,                   # Logical: later exposures take precedence (default)
  combine = NULL,                 # String: variable name for combined exposure

  # Lag and washout options
  lag = 0,                        # Numeric: days before exposure becomes active
  washout = 0,                    # Numeric: days exposure persists after stopping
  window = NULL,                  # Numeric vector c(min, max): acute exposure window

  # Pattern tracking options
  switching = FALSE,              # Logical: create switching indicator
  switchingdetail = FALSE,        # Logical: create switching pattern string
  statetime = FALSE,              # Logical: create cumulative time in current state

  # Output options
  generate = "tv_exposure",       # String: name for output variable
  referencelabel = "Unexposed",   # String: label for reference category
  label = NULL,                   # String: custom variable label
  saveas = NULL,                  # String: path to save output
  keepvars = NULL,                # Character vector: additional vars to keep
  keepdates = FALSE,              # Logical: keep entry/exit dates

  # Diagnostic options
  check = FALSE,                  # Logical: display coverage diagnostics
  gaps = FALSE,                   # Logical: show persons with gaps
  overlaps = FALSE,               # Logical: show overlapping periods
  summarize = FALSE,              # Logical: display exposure distribution
  validate = FALSE,               # Logical: create validation dataset

  # Advanced options
  verbose = TRUE                  # Logical: show progress messages
)
```

---

## 2. Data Structures

### 2.1 Input Data Structures

**Master Data (cohort):**
- Must contain: `id`, `entry`, `exit` columns
- Optional: `keepvars` columns
- All date columns should be Date or numeric (days since epoch)

**Exposure Data:**
- Must contain: `id`, `start`, `exposure` columns
- Must contain: `stop` column unless `pointtime = TRUE`
- Date columns should be Date or numeric

### 2.2 Internal Data Structures

**Exposure Period Table (data.table):**
```r
# Columns after initial processing:
# - id: person identifier
# - exp_start: period start date (integer days)
# - exp_stop: period stop date (integer days)
# - exp_value: exposure category
# - study_entry: study entry date
# - study_exit: study exit date
# - [keepvars]: additional columns from master
```

**Key Intermediate Variables:**
```r
# __orig_exp_binary: 0/1 indicator (exposed vs reference)
# __orig_exp_category: original exposure value before transformations
# __all_exp_types: all exposure types person was ever exposed to (for bytype)
# period_days: duration of each period in days
# cumul_days_end: cumulative exposure days at end of period
```

### 2.3 Output Data Structure

```r
list(
  data = <data.frame>,              # Time-varying dataset
  metadata = list(
    N_persons = <integer>,          # Number of unique persons
    N_periods = <integer>,          # Number of time-varying periods
    total_time = <numeric>,         # Total person-time in days
    exposed_time = <numeric>,       # Exposed person-time
    unexposed_time = <numeric>,     # Unexposed person-time
    pct_exposed = <numeric>,        # Percentage of time exposed
    exposure_types = <vector>,      # Unique exposure values
    parameters = list(...)          # All input parameters
  ),
  diagnostics = <data.frame or NULL>,  # If validate=TRUE
  warnings = <character vector>     # Any warnings generated
)
```

---

## 3. Input Validation

### 3.1 Parameter Validation Sequence

```r
validate_inputs <- function(params) {
  # Step 1: Check required parameters exist
  required <- c("master_data", "exposure_file", "id", "start",
                "exposure", "reference", "entry", "exit")
  for (param in required) {
    if (is.null(params[[param]])) {
      stop(sprintf("Required parameter '%s' is missing", param))
    }
  }

  # Step 2: Validate stop or pointtime
  if (is.null(params$stop) && !params$pointtime) {
    stop("'stop' is required unless pointtime=TRUE")
  }

  # Step 3: Check master_data is data frame
  if (!is.data.frame(params$master_data)) {
    stop("master_data must be a data.frame")
  }

  # Step 4: Check required columns exist in master_data
  master_cols <- c(params$id, params$entry, params$exit)
  if (!is.null(params$keepvars)) {
    master_cols <- c(master_cols, params$keepvars)
  }
  missing <- setdiff(master_cols, names(params$master_data))
  if (length(missing) > 0) {
    stop(sprintf("Columns not found in master_data: %s",
                 paste(missing, collapse=", ")))
  }

  # Step 5: Load and validate exposure data
  if (is.character(params$exposure_file)) {
    # File path - read it
    if (!file.exists(params$exposure_file)) {
      stop(sprintf("Exposure file not found: %s", params$exposure_file))
    }
    # Determine file type and read
    if (grepl("\\.csv$", params$exposure_file, ignore.case=TRUE)) {
      exp_data <- read.csv(params$exposure_file, stringsAsFactors=FALSE)
    } else if (grepl("\\.rds$", params$exposure_file, ignore.case=TRUE)) {
      exp_data <- readRDS(params$exposure_file)
    } else if (grepl("\\.dta$", params$exposure_file, ignore.case=TRUE)) {
      if (!requireNamespace("haven", quietly=TRUE)) {
        stop("Package 'haven' required to read .dta files")
      }
      exp_data <- haven::read_dta(params$exposure_file)
    } else {
      stop("Unsupported file format. Use .csv, .rds, or .dta")
    }
  } else if (is.data.frame(params$exposure_file)) {
    exp_data <- params$exposure_file
  } else {
    stop("exposure_file must be a file path or data.frame")
  }

  # Step 6: Check required columns in exposure data
  exp_cols <- c(params$id, params$start, params$exposure)
  if (!params$pointtime) {
    exp_cols <- c(exp_cols, params$stop)
  }
  missing <- setdiff(exp_cols, names(exp_data))
  if (length(missing) > 0) {
    stop(sprintf("Columns not found in exposure data: %s",
                 paste(missing, collapse=", ")))
  }

  # Step 7: Validate mutually exclusive exposure types
  exp_types <- c(params$evertreated, params$currentformer,
                 !is.null(params$duration),
                 !is.null(params$continuousunit) && is.null(params$duration),
                 !is.null(params$recency))
  if (sum(exp_types) > 1) {
    stop("Only one exposure type can be specified: evertreated, currentformer, duration, continuousunit, or recency")
  }

  # Step 8: Validate mutually exclusive overlap strategies
  overlap_opts <- c(!is.null(params$priority), params$split,
                    !is.null(params$combine), params$layer)
  if (sum(overlap_opts) > 1) {
    stop("Only one overlap handling option can be specified: priority, split, layer, or combine")
  }

  # Step 9: Validate numeric parameters
  numeric_params <- list(
    merge_days = params$merge_days,
    lag = params$lag,
    washout = params$washout,
    fillgaps = params$fillgaps,
    carryforward = params$carryforward
  )

  for (name in names(numeric_params)) {
    val <- numeric_params[[name]]
    if (!is.numeric(val) || length(val) != 1) {
      stop(sprintf("%s must be a single numeric value", name))
    }
    if (name == "merge_days" && val <= 0) {
      stop("merge_days must be positive")
    }
    if (val < 0 && name != "merge_days") {
      stop(sprintf("%s cannot be negative", name))
    }
  }

  # Step 10: Validate window format
  if (!is.null(params$window)) {
    if (length(params$window) != 2 || !is.numeric(params$window)) {
      stop("window must be a numeric vector of length 2: c(min, max)")
    }
    if (params$window[1] >= params$window[2]) {
      stop("window must be specified with min < max")
    }
  }

  # Step 11: Validate continuousunit and expandunit
  valid_units <- c("days", "weeks", "months", "quarters", "years")
  if (!is.null(params$continuousunit)) {
    if (!tolower(params$continuousunit) %in% valid_units) {
      stop(sprintf("continuousunit must be one of: %s",
                   paste(valid_units, collapse=", ")))
    }
  }
  if (!is.null(params$expandunit)) {
    if (!tolower(params$expandunit) %in% valid_units) {
      stop(sprintf("expandunit must be one of: %s",
                   paste(valid_units, collapse=", ")))
    }
  }

  # Step 12: Validate duration/recency are ascending if specified
  if (!is.null(params$duration)) {
    if (!is.numeric(params$duration)) {
      stop("duration must be a numeric vector")
    }
    if (is.unsorted(params$duration)) {
      stop("duration cutpoints must be in ascending order")
    }
  }
  if (!is.null(params$recency)) {
    if (!is.numeric(params$recency)) {
      stop("recency must be a numeric vector")
    }
    if (is.unsorted(params$recency)) {
      stop("recency cutpoints must be in ascending order")
    }
  }

  # Step 13: Validate bytype usage
  if (params$bytype) {
    # bytype cannot be used with default (timevarying)
    if (!any(c(params$evertreated, params$currentformer,
               !is.null(params$duration), !is.null(params$continuousunit),
               !is.null(params$recency)))) {
      stop("bytype cannot be used with default time-varying option")
    }
  }

  # Step 14: Validate grace format
  if (!is.null(params$grace) && !is.numeric(params$grace)) {
    if (!is.list(params$grace)) {
      stop("grace must be numeric or a named list")
    }
    # If list, check it's named with numeric values
    if (is.null(names(params$grace)) || any(names(params$grace) == "")) {
      stop("grace list must have names (exposure categories)")
    }
    if (!all(sapply(params$grace, is.numeric))) {
      stop("grace list values must be numeric (days)")
    }
  }

  return(exp_data)
}
```

---

## 4. Core Algorithms

### 4.1 Data Preparation Algorithm

**Purpose:** Load, merge, and prepare exposure and master data

**Steps:**

```r
prepare_data <- function(master_data, exp_data, params) {
  # Convert to data.table for performance
  library(data.table)

  master_dt <- as.data.table(master_data)
  exp_dt <- as.data.table(exp_data)

  # Step 1: Ensure date columns are numeric (days)
  # Convert Date objects to numeric if needed
  for (col in c(params$entry, params$exit)) {
    if (inherits(master_dt[[col]], "Date")) {
      master_dt[[col]] <- as.numeric(master_dt[[col]])
    }
    # Floor entry, ceiling exit for conservative coverage
    master_dt[[col]] := floor(master_dt[[col]])
  }
  master_dt[[params$exit]] <- ceiling(master_dt[[params$exit]])

  for (col in c(params$start, if(!params$pointtime) params$stop)) {
    if (inherits(exp_dt[[col]], "Date")) {
      exp_dt[[col]] <- as.numeric(exp_dt[[col]])
    }
    exp_dt[[col]] := as.integer(exp_dt[[col]])
  }

  # Step 2: Rename columns to standard internal names
  setnames(master_dt,
           c(params$id, params$entry, params$exit),
           c("id", "study_entry", "study_exit"),
           skip_absent=TRUE)

  setnames(exp_dt,
           c(params$id, params$start, params$exposure),
           c("id", "exp_start", "exp_value"),
           skip_absent=TRUE)

  if (!params$pointtime) {
    setnames(exp_dt, params$stop, "exp_stop", skip_absent=TRUE)
  } else {
    # For pointtime, set stop = start
    exp_dt[, exp_stop := exp_start]
  }

  # Step 3: Keep only specified columns from master
  keep_cols <- c("id", "study_entry", "study_exit")
  if (!is.null(params$keepvars)) {
    keep_cols <- c(keep_cols, params$keepvars)
  }
  master_dt <- master_dt[, ..keep_cols]

  # Step 4: Merge exposure data with master dates
  # Only keep exposure records for persons in master dataset
  exp_dt <- merge(exp_dt, master_dt, by="id", all.x=FALSE, all.y=FALSE)

  # Step 5: Truncate exposure periods to study window
  # Exposure can't start before entry or end after exit
  exp_dt[, exp_start := pmax(exp_start, study_entry)]
  exp_dt[, exp_stop := pmin(exp_stop, study_exit)]

  # Step 6: Remove invalid periods (stop before start after truncation)
  exp_dt <- exp_dt[exp_stop >= exp_start]

  # Step 7: Remove periods entirely outside study window
  exp_dt <- exp_dt[exp_start <= study_exit & exp_stop >= study_entry]

  # Step 8: Apply lag if specified
  # Lag shifts exposure start forward by N days
  if (params$lag > 0) {
    exp_dt[, exp_start := exp_start + params$lag]
    # Remove periods that become invalid after lag
    exp_dt <- exp_dt[exp_start <= exp_stop]
  }

  # Step 9: Apply washout if specified
  # Washout extends exposure stop by N days
  if (params$washout > 0) {
    exp_dt[, exp_stop := pmin(exp_stop + params$washout, study_exit)]
  }

  # Step 10: Apply window filter if specified
  # Keep only periods with duration in [min, max] days
  if (!is.null(params$window)) {
    exp_dt[, period_duration := exp_stop - exp_start + 1]
    exp_dt <- exp_dt[period_duration >= params$window[1] &
                     period_duration <= params$window[2]]
    exp_dt[, period_duration := NULL]
  }

  # Step 11: Apply fillgaps if specified
  # Extend last exposure period by N days
  if (params$fillgaps > 0) {
    exp_dt[, is_last := .I == .N, by=id]
    exp_dt[is_last == TRUE, exp_stop := pmin(exp_stop + params$fillgaps, study_exit)]
    exp_dt[, is_last := NULL]
  }

  # Step 12: Create helper variables
  exp_dt[, `:=`(
    __orig_exp_binary = as.integer(exp_value != params$reference),
    __orig_exp_category = exp_value
  )]

  # Step 13: Sort by id, start, stop
  setkey(exp_dt, id, exp_start, exp_stop)

  return(list(master=master_dt, exposure=exp_dt))
}
```

### 4.2 Iterative Period Merging Algorithm

**Purpose:** Merge consecutive periods of same exposure type within merge_days

**Algorithm:**
- Iterate until no more merges possible
- Find periods of same exposure type within merge_days
- Extend earlier period to cover later period
- Mark later period for deletion if fully subsumed
- Repeat

**Implementation:**

```r
merge_periods <- function(exp_dt, merge_days, reference, verbose=TRUE) {
  # Iterative merging until convergence
  max_iter <- 10000
  iter <- 0
  changes <- 1

  while (changes > 0 && iter < max_iter) {
    # Progress indicator every 100 iterations
    if (verbose && iter > 0 && iter %% 100 == 0) {
      message(sprintf("  Merge iteration %d/%d (processing...)", iter, max_iter))
    }

    # Reset drop flag
    exp_dt[, drop_flag := 0L]

    # Calculate gap to next period (negative for overlaps)
    exp_dt[, gap_to_next := shift(exp_start, type="lead") - exp_stop, by=id]
    exp_dt[, next_value := shift(exp_value, type="lead"), by=id]
    exp_dt[, next_stop := shift(exp_stop, type="lead"), by=id]

    # Mark periods that can merge with next
    exp_dt[, can_merge := !is.na(gap_to_next) &
                          gap_to_next <= merge_days &
                          exp_value == next_value]

    # Extend current period's stop to encompass next period
    exp_dt[can_merge == TRUE, exp_stop := pmax(exp_stop, next_stop)]

    # Mark next period for deletion if fully subsumed
    # Use shift to mark the following row
    exp_dt[, should_drop := shift(can_merge, type="lag", fill=FALSE), by=id]
    exp_dt[, prev_start := shift(exp_start, type="lag"), by=id]
    exp_dt[, prev_stop := shift(exp_stop, type="lag"), by=id]

    # Only drop if fully contained in previous merged period
    exp_dt[should_drop == TRUE, drop_flag :=
           as.integer(exp_start >= prev_start & exp_stop <= prev_stop)]

    # Count changes
    changes <- sum(exp_dt$drop_flag)

    # Remove dropped periods
    if (changes > 0) {
      exp_dt <- exp_dt[drop_flag == 0]
    }

    # Clean up temporary columns
    exp_dt[, c("gap_to_next", "next_value", "next_stop", "can_merge",
               "should_drop", "prev_start", "prev_stop", "drop_flag") := NULL]

    iter <- iter + 1
  }

  if (iter >= max_iter) {
    warning(sprintf("Merge iteration limit (%d) reached. Some periods may not be fully merged.", max_iter))
  } else if (verbose && iter > 100) {
    message(sprintf("  Merge completed after %d iterations", iter))
  }

  # Remove exact duplicates
  exp_dt <- unique(exp_dt, by=c("id", "exp_start", "exp_stop", "exp_value"))

  return(exp_dt)
}
```

### 4.3 Iterative Contained Period Removal

**Purpose:** Remove periods fully contained within another period of same type

**Algorithm:**
- Iterate until no contained periods remain
- A period is contained if: same ID, same exposure, start >= prev_start, stop <= prev_stop
- Remove contained periods
- Repeat (removal may reveal new contained periods)

**Implementation:**

```r
remove_contained <- function(exp_dt, verbose=TRUE) {
  max_iter <- 10000
  iter <- 0
  done <- FALSE

  while (!done && iter < max_iter) {
    # Progress indicator
    if (verbose && iter > 0 && iter %% 100 == 0) {
      message(sprintf("  Containment check iteration %d/%d", iter, max_iter))
    }

    # Check for contained periods
    exp_dt[, contained := 0L]
    exp_dt[, prev_start := shift(exp_start, type="lag"), by=id]
    exp_dt[, prev_stop := shift(exp_stop, type="lag"), by=id]
    exp_dt[, prev_value := shift(exp_value, type="lag"), by=id]

    # Mark as contained if fully within previous period of same type
    exp_dt[!is.na(prev_start), contained :=
           as.integer(exp_start >= prev_start &
                      exp_stop <= prev_stop &
                      exp_value == prev_value)]

    # Count contained
    n_contained <- sum(exp_dt$contained)

    if (n_contained == 0) {
      done <- TRUE
    } else {
      # Remove contained
      exp_dt <- exp_dt[contained == 0]
      # Re-sort
      setkey(exp_dt, id, exp_start, exp_stop)
    }

    # Clean up
    exp_dt[, c("contained", "prev_start", "prev_stop", "prev_value") := NULL]

    iter <- iter + 1
  }

  if (iter >= max_iter) {
    warning("Containment check iteration limit reached")
  } else if (verbose && iter > 100) {
    message(sprintf("  Containment check completed after %d iterations", iter))
  }

  return(exp_dt)
}
```

### 4.4 Overlap Resolution Algorithms

#### 4.4.1 Split Strategy

**Purpose:** Create separate periods at all exposure boundaries

**Implementation:**

```r
resolve_overlaps_split <- function(exp_dt) {
  # Collect all unique boundaries per person
  boundaries_start <- exp_dt[, .(id, boundary = exp_start)]
  boundaries_stop <- exp_dt[, .(id, boundary = exp_stop + 1)]

  # Combine and deduplicate
  all_boundaries <- rbindlist(list(boundaries_start, boundaries_stop))
  all_boundaries <- unique(all_boundaries)
  setkey(all_boundaries, id, boundary)

  # Add period ID to original data
  exp_dt[, period_id := .I]

  # Cross join boundaries with periods for same person
  split_dt <- merge(exp_dt, all_boundaries, by="id", allow.cartesian=TRUE)

  # Keep only boundaries within period (not at edges)
  split_dt <- split_dt[boundary > exp_start & boundary < exp_stop]

  # If no internal boundaries, return original
  if (nrow(split_dt) == 0) {
    exp_dt[, period_id := NULL]
    return(exp_dt)
  }

  # Create split periods
  setkey(split_dt, id, period_id, boundary)
  split_dt[, `:=`(
    new_start = fifelse(.I == 1, exp_start, boundary),
    new_stop = fifelse(.I == .N, exp_stop, boundary - 1)
  ), by=.(id, period_id)]

  # Keep valid splits
  split_dt <- split_dt[new_start <= new_stop]

  # Identify which period_ids were actually split
  split_ids <- unique(split_dt$period_id)

  # Remove original unsplit versions of split periods
  exp_dt <- exp_dt[!period_id %in% split_ids]

  # Prepare split data
  split_dt[, `:=`(exp_start = new_start, exp_stop = new_stop)]
  split_dt[, c("new_start", "new_stop", "boundary", "period_id") := NULL]

  # Combine
  result <- rbindlist(list(exp_dt[, period_id := NULL], split_dt), fill=TRUE)

  # Remove duplicates
  result <- unique(result, by=c("id", "exp_start", "exp_stop", "exp_value"))
  setkey(result, id, exp_start, exp_stop)

  return(result)
}
```

#### 4.4.2 Priority Strategy

**Purpose:** Apply priority order when periods overlap

**Implementation:**

```r
resolve_overlaps_priority <- function(exp_dt, priority_order) {
  # Add priority rank (lower number = higher priority)
  priority_map <- data.table(
    exp_value = priority_order,
    priority_rank = seq_along(priority_order)
  )

  exp_dt <- merge(exp_dt, priority_map, by="exp_value", all.x=TRUE)

  # For values not in priority list, assign lowest priority
  max_rank <- max(priority_map$priority_rank)
  exp_dt[is.na(priority_rank), priority_rank := max_rank + 1]

  # Sort by id, start, priority
  setorder(exp_dt, id, exp_start, priority_rank)

  # Truncate lower priority periods that overlap with higher priority
  exp_dt[, `:=`(
    prev_stop = shift(exp_stop, type="lag"),
    prev_priority = shift(priority_rank, type="lag")
  ), by=id]

  # If current period starts before previous ends AND has lower priority
  # Truncate start to after previous period
  exp_dt[!is.na(prev_stop) &
         exp_start <= prev_stop &
         priority_rank > prev_priority,
         exp_start := prev_stop + 1]

  # Remove invalid periods
  exp_dt <- exp_dt[exp_start <= exp_stop]

  # Clean up
  exp_dt[, c("priority_rank", "prev_stop", "prev_priority") := NULL]

  return(exp_dt)
}
```

#### 4.4.3 Layer Strategy (Default)

**Purpose:** Later exposures take precedence; earlier resume after

**Implementation:**

```r
resolve_overlaps_layer <- function(exp_dt) {
  # Sort by id and start
  setkey(exp_dt, id, exp_start, exp_stop)

  # Identify overlaps with next period
  exp_dt[, `:=`(
    next_start = shift(exp_start, type="lead"),
    next_stop = shift(exp_stop, type="lead"),
    next_value = shift(exp_value, type="lead")
  ), by=id]

  # Mark periods with overlap
  exp_dt[, has_overlap := !is.na(next_start) & next_start <= exp_stop]

  # For overlapping periods of different types, split into:
  # 1. Pre-overlap segment (current exposure)
  # 2. Overlap segment (later exposure takes precedence)
  # 3. Post-overlap segment (current exposure resumes)

  overlaps <- exp_dt[has_overlap == TRUE & exp_value != next_value]

  if (nrow(overlaps) > 0) {
    # Create three segments for each overlap
    pre_overlap <- overlaps[next_start > exp_start,
                            .(id, exp_start,
                              exp_stop = next_start - 1,
                              exp_value)]

    # Post-overlap: current exposure resumes after next period ends
    post_overlap <- overlaps[exp_stop > next_stop,
                             .(id,
                               exp_start = next_stop + 1,
                               exp_stop,
                               exp_value)]

    # Remove original overlapping periods
    exp_dt <- exp_dt[!(has_overlap == TRUE & exp_value != next_value)]

    # Add segments
    exp_dt <- rbindlist(list(exp_dt, pre_overlap, post_overlap), fill=TRUE)
  }

  # Clean up
  exp_dt[, c("next_start", "next_stop", "next_value", "has_overlap") := NULL]

  # Remove duplicates and invalid periods
  exp_dt <- exp_dt[exp_start <= exp_stop]
  exp_dt <- unique(exp_dt, by=c("id", "exp_start", "exp_stop", "exp_value"))
  setkey(exp_dt, id, exp_start, exp_stop)

  return(exp_dt)
}
```

#### 4.4.4 Combine Strategy

**Purpose:** Create combined exposure variable for overlaps

**Implementation:**

```r
resolve_overlaps_combine <- function(exp_dt, combine_varname) {
  # Detect overlaps
  exp_dt[, `:=`(
    next_start = shift(exp_start, type="lead"),
    next_value = shift(exp_value, type="lead")
  ), by=id]

  # Mark overlaps with different exposure types
  exp_dt[, has_overlap := !is.na(next_start) &
                          next_start <= exp_stop &
                          exp_value != next_value]

  # Create combined exposure encoding: val1 * 100 + val2
  exp_dt[, exp_combined := exp_value]
  exp_dt[has_overlap == TRUE,
         exp_combined := exp_value * 100 + next_value]

  # Also mark the overlapped period (next row)
  exp_dt[, `:=`(
    prev_value = shift(exp_value, type="lag"),
    prev_stop = shift(exp_stop, type="lag")
  ), by=id]

  exp_dt[!is.na(prev_stop) &
         exp_start <= prev_stop &
         exp_value != prev_value,
         exp_combined := prev_value * 100 + exp_value]

  # Create the named combined variable
  setnames(exp_dt, "exp_combined", combine_varname)

  # Clean up
  exp_dt[, c("next_start", "next_value", "has_overlap",
             "prev_value", "prev_stop") := NULL]

  return(exp_dt)
}
```

### 4.5 Gap Period Creation Algorithm

**Purpose:** Fill gaps between exposure periods with reference (unexposed) time

**Implementation:**

```r
create_gap_periods <- function(exp_dt, reference, grace_default,
                                grace_bycategory, grace_list,
                                carryforward, verbose=TRUE) {

  # Calculate gap between consecutive periods
  exp_dt[, `:=`(
    next_start = shift(exp_start, type="lead"),
    next_value = shift(exp_value, type="lead")
  ), by=id]

  exp_dt[, gap_days := next_start - exp_stop - 1]

  # Apply grace periods
  exp_dt[, grace_days := grace_default]

  if (grace_bycategory && !is.null(grace_list)) {
    # Apply category-specific grace
    for (cat in names(grace_list)) {
      cat_num <- as.numeric(cat)
      exp_dt[exp_value == cat_num, grace_days := grace_list[[cat]]]
    }
  }

  # Bridge small gaps within grace period (same exposure type only)
  exp_dt[!is.na(gap_days) &
         gap_days <= grace_days &
         gap_days >= 0 &
         exp_value == next_value,
         exp_stop := next_start - 1]

  # Recalculate gaps after bridging
  exp_dt[, next_start := shift(exp_start, type="lead"), by=id]
  exp_dt[, gap_days := next_start - exp_stop - 1]

  # Identify gaps that need filling (exceed grace period)
  gaps <- exp_dt[!is.na(gap_days) & gap_days > grace_days,
                 .(id,
                   gap_start = exp_stop + 1,
                   gap_stop = next_start - 1,
                   gap_days,
                   prev_value = exp_value)]

  if (nrow(gaps) == 0) {
    exp_dt[, c("next_start", "next_value", "gap_days", "grace_days") := NULL]
    return(list(exp_dt=exp_dt, gaps=NULL))
  }

  # Apply carryforward if specified
  if (carryforward > 0) {
    # Split gaps into carryforward period and reference period
    gaps[, `:=`(
      carry_stop = pmin(gap_start + carryforward - 1, gap_stop),
      needs_ref = gap_days > carryforward
    )]

    # Create carryforward periods
    carry_periods <- gaps[, .(
      id,
      exp_start = gap_start,
      exp_stop = carry_stop,
      exp_value = prev_value
    )]

    # Create reference periods for remaining gap
    ref_periods <- gaps[needs_ref == TRUE, .(
      id,
      exp_start = carry_stop + 1,
      exp_stop = gap_stop,
      exp_value = reference
    )]

    # Combine
    gap_periods <- rbindlist(list(carry_periods, ref_periods), fill=TRUE)
  } else {
    # No carryforward: all gaps are reference
    gap_periods <- gaps[, .(
      id,
      exp_start = gap_start,
      exp_stop = gap_stop,
      exp_value = reference
    )]
  }

  # Clean up temporary columns
  exp_dt[, c("next_start", "next_value", "gap_days", "grace_days") := NULL]

  return(list(exp_dt=exp_dt, gaps=gap_periods))
}
```

### 4.6 Baseline and Post-Exposure Period Creation

**Implementation:**

```r
create_baseline_periods <- function(master_dt, exp_dt, reference) {
  # Find earliest exposure per person
  earliest <- exp_dt[, .(earliest_exp = min(exp_start)), by=id]

  # Merge with master
  baseline <- merge(master_dt, earliest, by="id", all.x=TRUE)

  # Create baseline period
  baseline[, `:=`(
    exp_start = study_entry,
    exp_stop = fifelse(is.na(earliest_exp),
                       study_exit,           # Never exposed: full follow-up
                       earliest_exp - 1),    # Ever exposed: until first exposure
    exp_value = reference
  )]

  # Keep only valid periods
  baseline <- baseline[exp_stop >= exp_start]

  return(baseline[, .(id, exp_start, exp_stop, exp_value)])
}

create_postexposure_periods <- function(exp_dt, reference) {
  # Find last exposure end per person
  last_exp <- exp_dt[, .(
    id,
    last_exp_stop = max(exp_stop),
    study_exit = first(study_exit)
  ), by=id]

  # Create post-exposure periods only where gap exists
  post <- last_exp[last_exp_stop < study_exit,
                   .(id,
                     exp_start = last_exp_stop + 1,
                     exp_stop = study_exit,
                     exp_value = reference)]

  return(post)
}
```

---

## 5. Exposure Type Implementations

### 5.1 Ever-Treated

**Logic:**
- Binary variable: 0 before first exposure, 1 from first exposure onward
- Switches permanently at first exposure
- With `bytype`: separate binary variable per exposure type

**Implementation:**

```r
apply_evertreated <- function(exp_dt, reference, bytype, stub_name, params) {
  # Find first exposure date per person
  exp_dt[, first_exp_any := min(exp_start[__orig_exp_binary == 1]), by=id]

  if (bytype) {
    # Create separate ever_X variables for each type
    exp_types <- unique(exp_dt[exp_value != reference, exp_value])

    for (exp_type_val in exp_types) {
      # Sanitize variable name suffix
      suffix <- gsub("-", "neg", as.character(exp_type_val))
      suffix <- gsub("\\.", "p", suffix)
      varname <- paste0(stub_name, suffix)

      # Find first exposure to this type
      exp_dt[, temp_first := min(exp_start[__orig_exp_category == exp_type_val]),
             by=id]

      # Binary indicator: 0 before first, 1 after
      exp_dt[, (varname) := fifelse(
        is.na(temp_first) | exp_start < temp_first,
        0,
        1
      )]

      exp_dt[, temp_first := NULL]
    }

    # Collapse consecutive periods with same ever_X values
    # Build grouping key from all ever_X variables
    ever_vars <- paste0(stub_name,
                        gsub("-", "neg", gsub("\\.", "p", as.character(exp_types))))

    exp_dt[, period_group := .GRP,
           by=c("id", "exp_value", ever_vars)]

    # Collapse
    keep_cols <- c("id", "exp_value", ever_vars)
    if (!is.null(params$keepvars)) {
      keep_cols <- c(keep_cols, params$keepvars)
    }

    result <- exp_dt[, .(
      exp_start = min(exp_start),
      exp_stop = max(exp_stop)
    ), by=c("period_group", keep_cols)]

    result[, period_group := NULL]

  } else {
    # Single ever-treated variable
    exp_dt[, exp_value_new := fifelse(
      is.na(first_exp_any) | exp_start < first_exp_any,
      0,
      1
    )]

    exp_dt[, exp_value := exp_value_new]
    exp_dt[, exp_value_new := NULL]

    # Collapse consecutive periods
    exp_dt[, period_group := rleid(id, exp_value)]

    keep_cols <- c("id", "exp_value")
    if (!is.null(params$keepvars)) {
      keep_cols <- c(keep_cols, params$keepvars)
    }

    result <- exp_dt[, .(
      exp_start = min(exp_start),
      exp_stop = max(exp_stop)
    ), by=c("period_group", keep_cols)]

    result[, period_group := NULL]
  }

  result[, first_exp_any := NULL]
  setkey(result, id, exp_start)

  return(result)
}
```

### 5.2 Current/Former

**Logic:**
- Trichotomous: 0=never, 1=current, 2=former
- Current exposure = exp_value matches original exposure
- Former exposure = after first exposure but not currently exposed
- With `bytype`: separate 0/1/2 variable per exposure type

**Implementation:**

```r
apply_currentformer <- function(exp_dt, reference, bytype, stub_name, params) {

  if (bytype) {
    # Create separate cf_X variables for each type
    exp_types <- unique(exp_dt[exp_value != reference, exp_value])

    for (exp_type_val in exp_types) {
      suffix <- gsub("-", "neg", as.character(exp_type_val))
      suffix <- gsub("\\.", "p", suffix)
      varname <- paste0(stub_name, suffix)

      # Find first and last exposure to this type
      exp_dt[, `:=`(
        first_exp = min(exp_start[__orig_exp_category == exp_type_val]),
        last_exp = max(exp_stop[__orig_exp_category == exp_type_val])
      ), by=id]

      # Assign 0/1/2
      exp_dt[, (varname) := fcase(
        is.na(first_exp), 0L,                           # Never exposed
        __orig_exp_category == exp_type_val, 1L,        # Currently exposed
        exp_start >= first_exp, 2L,                     # Formerly exposed
        default = 0L
      )]

      exp_dt[, c("first_exp", "last_exp") := NULL]
    }

    # Collapse
    cf_vars <- paste0(stub_name,
                      gsub("-", "neg", gsub("\\.", "p", as.character(exp_types))))

    exp_dt[, period_group := .GRP,
           by=c("id", "exp_value", cf_vars)]

    keep_cols <- c("id", "exp_value", cf_vars)
    if (!is.null(params$keepvars)) {
      keep_cols <- c(keep_cols, params$keepvars)
    }

    result <- exp_dt[, .(
      exp_start = min(exp_start),
      exp_stop = max(exp_stop)
    ), by=c("period_group", keep_cols)]

    result[, period_group := NULL]

  } else {
    # Single current/former variable across all types
    exp_dt[, `:=`(
      first_exp_any = min(exp_start[__orig_exp_binary == 1]),
      currently_exposed = __orig_exp_binary
    ), by=id]

    exp_dt[, exp_value_new := fcase(
      is.na(first_exp_any), 0L,              # Never exposed
      currently_exposed == 1, 1L,            # Currently exposed
      exp_start >= first_exp_any, 2L,        # Formerly exposed
      default = 0L
    )]

    exp_dt[, exp_value := exp_value_new]
    exp_dt[, c("exp_value_new", "first_exp_any", "currently_exposed") := NULL]

    # Collapse
    exp_dt[, period_group := rleid(id, exp_value)]

    keep_cols <- c("id", "exp_value")
    if (!is.null(params$keepvars)) {
      keep_cols <- c(keep_cols, params$keepvars)
    }

    result <- exp_dt[, .(
      exp_start = min(exp_start),
      exp_stop = max(exp_stop)
    ), by=c("period_group", keep_cols)]

    result[, period_group := NULL]
  }

  setkey(result, id, exp_start)
  return(result)
}
```

### 5.3 Continuous Cumulative Exposure

**Logic:**
- Continuous variable tracking cumulative exposure in specified units
- Optional row expansion by time units (weeks/months/quarters/years)
- With `bytype`: separate continuous variable per exposure type

**Implementation:**

```r
apply_continuous <- function(exp_dt, reference, bytype, stub_name, params) {
  # Unit conversion factors (days to target unit)
  unit_divisor <- switch(
    tolower(params$continuousunit),
    "days" = 1,
    "weeks" = 7,
    "months" = 365.25 / 12,
    "quarters" = 365.25 / 4,
    "years" = 365.25
  )

  # Determine expansion unit (defaults to continuous unit if not specified)
  expand_unit <- if (!is.null(params$expandunit)) {
    tolower(params$expandunit)
  } else {
    tolower(params$continuousunit)
  }

  # Apply row expansion if not "days"
  if (expand_unit != "days") {
    exp_dt <- expand_by_unit(exp_dt, expand_unit, reference)
  }

  # Calculate period days
  exp_dt[, period_days := exp_stop - exp_start + 1]
  # Only count exposed time
  exp_dt[exp_value == reference, period_days := 0]

  # Calculate cumulative exposure at end of each period
  exp_dt[, cumul_days_end := cumsum(period_days), by=id]

  if (bytype) {
    # Separate variables per type
    exp_types <- unique(exp_dt[exp_value != reference, exp_value])

    for (exp_type_val in exp_types) {
      suffix <- gsub("-", "neg", as.character(exp_type_val))
      suffix <- gsub("\\.", "p", suffix)
      varname <- paste0(stub_name, suffix)

      # Days for this specific type
      exp_dt[, temp_days := fifelse(__orig_exp_category == exp_type_val,
                                     period_days,
                                     0)]

      # Cumulative for this type
      exp_dt[, temp_cumul := cumsum(temp_days), by=id]

      # Convert to specified unit
      exp_dt[, (varname) := temp_cumul / unit_divisor]

      exp_dt[, c("temp_days", "temp_cumul") := NULL]
    }

    # Collapse consecutive periods with same cumulative values
    tvexp_vars <- paste0(stub_name,
                         gsub("-", "neg", gsub("\\.", "p", as.character(exp_types))))

    exp_dt[, period_group := .GRP, by=c("id", tvexp_vars)]

    keep_cols <- c("id", "exp_value", tvexp_vars)
    if (!is.null(params$keepvars)) {
      keep_cols <- c(keep_cols, params$keepvars)
    }

    result <- exp_dt[, .(
      exp_start = min(exp_start),
      exp_stop = max(exp_stop)
    ), by=c("period_group", keep_cols)]

    result[, period_group := NULL]

  } else {
    # Single continuous variable
    exp_dt[, tv_exp := cumul_days_end / unit_divisor]

    # Collapse
    exp_dt[, period_group := rleid(id, tv_exp)]

    keep_cols <- c("id", "exp_value", "tv_exp")
    if (!is.null(params$keepvars)) {
      keep_cols <- c(keep_cols, params$keepvars)
    }

    result <- exp_dt[, .(
      exp_start = min(exp_start),
      exp_stop = max(exp_stop)
    ), by=c("period_group", keep_cols)]

    result[, period_group := NULL]
  }

  setkey(result, id, exp_start)
  return(result)
}

# Helper function for row expansion
expand_by_unit <- function(exp_dt, unit, reference) {
  # Only expand exposed periods
  exp_dt[, needs_expansion := (exp_value != reference)]

  exposed <- exp_dt[needs_expansion == TRUE]
  unexposed <- exp_dt[needs_expansion == FALSE]

  if (nrow(exposed) > 0) {
    # Calculate unit size in days
    unit_days <- switch(
      unit,
      "weeks" = 7,
      "months" = 30.4375,      # Average month
      "quarters" = 91.3125,    # Average quarter
      "years" = 365.25
    )

    # Number of units in each period
    exposed[, n_units := ceiling((exp_stop - exp_start + 1) / unit_days)]

    # Expand
    exposed[, period_id := .I]
    expanded <- exposed[rep(1:.N, n_units)]
    expanded[, unit_seq := seq_len(.N), by=period_id]

    # Calculate unit boundaries
    expanded[, `:=`(
      unit_start = floor(exp_start + (unit_seq - 1) * unit_days),
      unit_stop = floor(exp_start + unit_seq * unit_days) - 1
    )]

    # Fix last unit in each period
    expanded[, is_last := (unit_seq == max(unit_seq)), by=period_id]
    expanded[is_last == TRUE, unit_stop := exp_stop]

    # Replace boundaries
    expanded[, `:=`(exp_start = unit_start, exp_stop = unit_stop)]
    expanded[, c("unit_start", "unit_stop", "n_units", "unit_seq",
                 "is_last", "period_id") := NULL]

    # Combine with unexposed
    result <- rbindlist(list(expanded, unexposed), fill=TRUE)
  } else {
    result <- unexposed
  }

  result[, needs_expansion := NULL]
  setkey(result, id, exp_start)

  return(result)
}
```

### 5.4 Duration Categories

**Logic:**
- First calculate continuous cumulative exposure
- Then categorize into bins based on cutpoints
- Categories: unexposed, <cut1, cut1-<cut2, ..., >=last_cut

**Implementation:**

```r
apply_duration <- function(exp_dt, reference, duration_cuts, bytype,
                           stub_name, params) {
  # First apply continuous logic
  exp_dt <- apply_continuous(exp_dt, reference, bytype=FALSE, stub_name, params)

  # tv_exp now contains cumulative exposure in specified units

  # Create duration categories
  # Category 0 = unexposed (reference)
  # Category 1 = 0 to <cut1
  # Category 2 = cut1 to <cut2
  # etc.

  exp_dt[, exp_duration := reference]

  # Apply cutpoints
  for (i in seq_along(duration_cuts)) {
    if (i == 1) {
      # First category: 0 to <cut1
      exp_dt[tv_exp > 0 & tv_exp < duration_cuts[i],
             exp_duration := i]
    } else {
      # Middle categories: cut[i-1] to <cut[i]
      exp_dt[tv_exp >= duration_cuts[i-1] & tv_exp < duration_cuts[i],
             exp_duration := i]
    }
  }

  # Last category: >= last cut
  exp_dt[tv_exp >= duration_cuts[length(duration_cuts)],
         exp_duration := length(duration_cuts) + 1]

  # If bytype, need separate duration categories per type
  if (bytype) {
    exp_types <- unique(exp_dt[exp_value != reference, exp_value])

    # This requires recalculating with type-specific cumulative exposure
    # Implementing full bytype logic for duration...
    # (Similar to continuous bytype but with categorization)
    # [Detailed implementation omitted for brevity - follows same pattern]
  }

  # Replace exp_value with duration category
  exp_dt[, exp_value := exp_duration]
  exp_dt[, c("tv_exp", "exp_duration") := NULL]

  # Collapse
  exp_dt[, period_group := rleid(id, exp_value)]

  keep_cols <- c("id", "exp_value")
  if (!is.null(params$keepvars)) {
    keep_cols <- c(keep_cols, params$keepvars)
  }

  result <- exp_dt[, .(
    exp_start = min(exp_start),
    exp_stop = max(exp_stop)
  ), by=c("period_group", keep_cols)]

  result[, period_group := NULL]
  setkey(result, id, exp_start)

  return(result)
}
```

### 5.5 Recency

**Logic:**
- Categories based on time since last exposure
- Current exposure = 0 years since
- Former categories: <cut1 years, cut1-<cut2 years, etc.

**Implementation:**

```r
apply_recency <- function(exp_dt, reference, recency_cuts, bytype,
                          stub_name, params) {
  # Find last exposure end date per person
  exp_dt[, last_exp_end := max(exp_stop[__orig_exp_binary == 1]), by=id]

  # Calculate time since last exposure (in years)
  exp_dt[, years_since := (exp_start - last_exp_end) / 365.25]

  # Categorize
  exp_dt[, recency_cat := fcase(
    is.na(last_exp_end), reference,              # Never exposed
    __orig_exp_binary == 1, 1L,                  # Currently exposed
    default = NA_integer_
  )]

  # Apply cutpoints for former exposure
  for (i in seq_along(recency_cuts)) {
    if (i == 1) {
      # First former category: <cut1 years since
      exp_dt[!is.na(years_since) &
             years_since > 0 &
             years_since < recency_cuts[i],
             recency_cat := i + 1]
    } else {
      # Middle categories
      exp_dt[years_since >= recency_cuts[i-1] &
             years_since < recency_cuts[i],
             recency_cat := i + 1]
    }
  }

  # Last category: >= last cut
  exp_dt[years_since >= recency_cuts[length(recency_cuts)],
         recency_cat := length(recency_cuts) + 2]

  # If bytype, create separate recency variables
  if (bytype) {
    # [Similar pattern to other bytype implementations]
    # [Detailed implementation omitted for brevity]
  }

  exp_dt[, exp_value := recency_cat]
  exp_dt[, c("last_exp_end", "years_since", "recency_cat") := NULL]

  # Collapse
  exp_dt[, period_group := rleid(id, exp_value)]

  keep_cols <- c("id", "exp_value")
  if (!is.null(params$keepvars)) {
    keep_cols <- c(keep_cols, params$keepvars)
  }

  result <- exp_dt[, .(
    exp_start = min(exp_start),
    exp_stop = max(exp_stop)
  ), by=c("period_group", keep_cols)]

  result[, period_group := NULL]
  setkey(result, id, exp_start)

  return(result)
}
```

---

## 6. Helper Functions

### 6.1 Pattern Tracking Functions

```r
add_switching_indicator <- function(exp_dt) {
  # Binary indicator: has person ever switched exposure types?
  exp_dt[, n_unique_exp := uniqueN(exp_value[exp_value != min(exp_value)]),
         by=id]
  exp_dt[, has_switched := as.integer(n_unique_exp > 1)]
  exp_dt[, n_unique_exp := NULL]

  return(exp_dt)
}

add_switching_detail <- function(exp_dt) {
  # Create string showing switching pattern
  # E.g., "0->1->2"

  exp_dt[, `:=`(
    prev_value = shift(exp_value, type="lag"),
    is_switch = FALSE
  ), by=id]

  exp_dt[, is_switch := (!is.na(prev_value) & exp_value != prev_value)]

  # Build pattern string
  switching_patterns <- exp_dt[, {
    if (any(is_switch)) {
      # Get sequence of unique values in order
      vals <- unique(exp_value)
      pattern <- paste(vals, collapse="->")
      .(switching_pattern = pattern)
    } else {
      .(switching_pattern = as.character(exp_value[1]))
    }
  }, by=id]

  exp_dt <- merge(exp_dt, switching_patterns, by="id", all.x=TRUE)
  exp_dt[, c("prev_value", "is_switch") := NULL]

  return(exp_dt)
}

add_statetime <- function(exp_dt) {
  # Cumulative time in current exposure state (resets when exposure changes)
  exp_dt[, `:=`(
    period_days = exp_stop - exp_start + 1,
    prev_value = shift(exp_value, type="lag")
  ), by=id]

  exp_dt[, state_reset := (is.na(prev_value) | exp_value != prev_value)]
  exp_dt[, state_group := cumsum(state_reset), by=id]

  exp_dt[, statetime := cumsum(period_days), by=.(id, state_group)]

  exp_dt[, c("period_days", "prev_value", "state_reset", "state_group") := NULL]

  return(exp_dt)
}
```

### 6.2 Diagnostic Functions

```r
check_coverage <- function(exp_dt, master_dt) {
  # Calculate coverage metrics per person
  coverage <- exp_dt[, .(
    n_periods = .N,
    first_period_start = min(exp_start),
    last_period_stop = max(exp_stop),
    total_period_days = sum(exp_stop - exp_start + 1)
  ), by=id]

  coverage <- merge(coverage,
                    master_dt[, .(id, study_entry, study_exit)],
                    by="id")

  coverage[, `:=`(
    expected_days = study_exit - study_entry + 1,
    coverage_gap = expected_days - total_period_days,
    pct_covered = 100 * total_period_days / expected_days
  )]

  return(coverage)
}

identify_gaps <- function(exp_dt) {
  # Find persons with gaps
  exp_dt[, `:=`(
    next_start = shift(exp_start, type="lead"),
    period_end = exp_stop
  ), by=id]

  gaps <- exp_dt[!is.na(next_start) & next_start > period_end + 1,
                 .(id,
                   gap_start = period_end + 1,
                   gap_end = next_start - 1,
                   gap_days = next_start - period_end - 1)]

  exp_dt[, c("next_start", "period_end") := NULL]

  return(gaps)
}

identify_overlaps <- function(exp_dt) {
  # Find overlapping periods
  exp_dt[, `:=`(
    next_start = shift(exp_start, type="lead"),
    next_value = shift(exp_value, type="lead")
  ), by=id]

  overlaps <- exp_dt[!is.na(next_start) &
                     next_start <= exp_stop &
                     exp_value != next_value,
                     .(id,
                       period1_start = exp_start,
                       period1_stop = exp_stop,
                       period1_value = exp_value,
                       period2_start = next_start,
                       period2_value = next_value,
                       overlap_days = exp_stop - next_start + 1)]

  exp_dt[, c("next_start", "next_value") := NULL]

  return(overlaps)
}

summarize_exposure <- function(exp_dt, reference) {
  # Summary statistics by exposure category
  summary <- exp_dt[, .(
    n_periods = .N,
    n_persons = uniqueN(id),
    total_days = sum(exp_stop - exp_start + 1),
    mean_period_days = mean(exp_stop - exp_start + 1),
    median_period_days = median(exp_stop - exp_start + 1)
  ), by=exp_value]

  # Add percentages
  summary[, pct_person_time := 100 * total_days / sum(total_days)]

  setorder(summary, exp_value)

  return(summary)
}
```

---

## 7. Return Value Structure

```r
# Main function returns a list with:
list(
  # Primary output: time-varying dataset
  data = <data.frame with columns:>
    # - id: person identifier
    # - exp_start: period start date
    # - exp_stop: period stop date
    # - tv_exposure (or custom name): exposure variable
    # - [exposure-specific vars]: e.g., ever1, ever2, cf1, tv_exp1
    # - [keepvars]: additional columns from master
    # - [study_entry, study_exit]: if keepdates=TRUE
    # - [switching indicators]: if switching/switchingdetail=TRUE
    # - [statetime]: if statetime=TRUE

  # Metadata
  metadata = list(
    N_persons = <integer>,              # Unique persons
    N_periods = <integer>,              # Total rows
    total_time = <numeric>,             # Total person-days
    exposed_time = <numeric>,           # Exposed person-days
    unexposed_time = <numeric>,         # Unexposed person-days
    pct_exposed = <numeric>,            # Percentage exposed
    exposure_types = <vector>,          # Unique exposure values

    # Parameters used
    parameters = list(
      exposure_definition = <string>,   # "evertreated", "currentformer", etc.
      continuousunit = <string or NULL>,
      expandunit = <string or NULL>,
      overlap_strategy = <string>,      # "layer", "split", "priority", "combine"
      grace = <numeric or list>,
      merge_days = <numeric>,
      lag = <numeric>,
      washout = <numeric>,
      carryforward = <numeric>,
      fillgaps = <numeric>,
      bytype = <logical>,
      # ... other parameters
    )
  ),

  # Diagnostics (if validate=TRUE)
  diagnostics = <data.frame or NULL with columns:>
    # - id
    # - n_periods
    # - total_period_days
    # - expected_days
    # - coverage_gap
    # - pct_covered
    # - has_gaps
    # - has_overlaps

  # Warnings
  warnings = <character vector of any warnings>
)
```

---

## 8. Error Handling

### 8.1 Error Categories

**Critical Errors (stop execution):**
1. Missing required parameters
2. Required columns not found in data
3. Data type mismatches
4. Invalid parameter combinations
5. Empty datasets after filtering
6. File I/O errors

**Warnings (proceed with caution):**
1. Iteration limits reached (merging, containment checks)
2. Missing data in optional columns
3. Datetime precision loss
4. Large datasets (performance warning)
5. Unusual coverage patterns

**Informational Messages:**
1. Progress indicators for long operations
2. Parameter defaults applied
3. Coalescing overlaps
4. Grace period applications

### 8.2 Error Handling Pattern

```r
# Use tryCatch for recoverable errors
result <- tryCatch({
  # Main processing
  process_data(...)
}, error = function(e) {
  stop(sprintf("Error in tvexpose: %s", e$message))
}, warning = function(w) {
  # Collect warnings
  warnings_list <<- c(warnings_list, w$message)
  invokeRestart("muffleWarning")
})

# Validate results before returning
if (nrow(result$data) == 0) {
  stop("No time-varying periods created. Check your data and parameters.")
}

# Check for complete coverage
coverage_check <- check_coverage(result$data, master_dt)
if (any(coverage_check$pct_covered < 99.9)) {
  warning(sprintf("%d persons have incomplete coverage (gaps in person-time)",
                  sum(coverage_check$pct_covered < 99.9)))
}
```

---

## 9. Testing Strategy

### 9.1 Unit Tests

**Test each algorithm independently:**

```r
# Test: Period merging
test_that("merge_periods correctly merges consecutive same-type periods", {
  # Create test data with gaps of various sizes
  test_dt <- data.table(
    id = c(1, 1, 1),
    exp_start = c(0, 100, 130),
    exp_stop = c(90, 120, 150),
    exp_value = c(1, 1, 1)
  )

  # With merge_days=15, periods 2 and 3 should merge
  result <- merge_periods(test_dt, merge_days=15, reference=0, verbose=FALSE)

  expect_equal(nrow(result), 2)
  expect_equal(result[2, exp_stop], 150)
})

# Test: Contained period removal
test_that("remove_contained removes fully contained periods", {
  test_dt <- data.table(
    id = c(1, 1),
    exp_start = c(0, 10),
    exp_stop = c(100, 50),
    exp_value = c(1, 1)
  )

  result <- remove_contained(test_dt, verbose=FALSE)

  expect_equal(nrow(result), 1)
  expect_equal(result[1, exp_start], 0)
  expect_equal(result[1, exp_stop], 100)
})

# Test: Gap creation
test_that("create_gap_periods fills gaps with reference value", {
  test_dt <- data.table(
    id = c(1, 1),
    exp_start = c(0, 100),
    exp_stop = c(50, 150),
    exp_value = c(1, 1),
    study_entry = c(0, 0),
    study_exit = c(200, 200)
  )

  result <- create_gap_periods(test_dt, reference=0, grace_default=0,
                                grace_bycategory=FALSE, grace_list=NULL,
                                carryforward=0, verbose=FALSE)

  expect_equal(nrow(result$gaps), 1)
  expect_equal(result$gaps[1, exp_start], 51)
  expect_equal(result$gaps[1, exp_stop], 99)
  expect_equal(result$gaps[1, exp_value], 0)
})

# Additional tests for each algorithm...
```

### 9.2 Integration Tests

**Test complete workflows:**

```r
test_that("evertreated workflow produces correct output", {
  # Create synthetic cohort
  cohort <- data.frame(
    id = 1:100,
    entry = rep(as.Date("2020-01-01"), 100),
    exit = rep(as.Date("2023-12-31"), 100)
  )

  # Create synthetic exposures
  exposures <- data.frame(
    id = rep(1:50, each=2),
    start = as.Date(c("2020-06-01", "2021-06-01")),
    stop = as.Date(c("2020-12-31", "2021-12-31")),
    exp = rep(1, 100)
  )

  result <- tvexpose(
    master_data = cohort,
    exposure_file = exposures,
    id = "id",
    start = "start",
    stop = "stop",
    exposure = "exp",
    reference = 0,
    entry = "entry",
    exit = "exit",
    evertreated = TRUE
  )

  # All 100 persons should have records
  expect_equal(uniqueN(result$data$id), 100)

  # Persons 1-50 should have tv_exposure=1 after first exposure
  exposed <- result$data[id %in% 1:50 & exp_start >= as.Date("2020-06-01")]
  expect_true(all(exposed$tv_exposure == 1))

  # Persons 51-100 should have tv_exposure=0 throughout
  never_exposed <- result$data[id %in% 51:100]
  expect_true(all(never_exposed$tv_exposure == 0))
})
```

### 9.3 Edge Cases to Test

**Critical edge cases:**

1. **Empty exposure data**: Person in cohort but no exposures
2. **Single observation**: Only one person in cohort
3. **Overlapping identical periods**: Same exposure, same dates
4. **Complete overlap**: One period fully contains another
5. **Touching periods**: stop[n] + 1 = start[n+1]
6. **Exposure before entry**: Exposure starts before study entry
7. **Exposure after exit**: Exposure extends beyond study exit
8. **Zero-day periods**: start = stop
9. **Negative gaps**: Overlapping periods
10. **Missing stop dates** (with pointtime=TRUE)
11. **All reference values**: No actual exposures
12. **Single exposure type**: Only one non-reference value
13. **Many exposure types**: 10+ different types
14. **Very short periods**: 1-day exposures
15. **Very long follow-up**: 10+ years per person
16. **Large cohort**: 100,000+ persons
17. **Fragmented exposure**: 100+ periods per person
18. **Grace period edge cases**:
    - gap = grace exactly
    - gap = grace + 1
    - gap = grace - 1
19. **Carryforward edge cases**:
    - gap = carryforward exactly
    - gap < carryforward
    - gap > carryforward
20. **Window filter edge cases**:
    - period duration = min exactly
    - period duration = max exactly
    - all periods filtered out

### 9.4 Performance Tests

```r
test_that("handles large datasets efficiently", {
  # Generate large synthetic dataset
  n_persons <- 10000
  cohort <- data.frame(
    id = 1:n_persons,
    entry = rep(as.Date("2010-01-01"), n_persons),
    exit = rep(as.Date("2020-12-31"), n_persons)
  )

  # Each person has 5 exposure periods
  exposures <- do.call(rbind, lapply(1:n_persons, function(i) {
    data.frame(
      id = i,
      start = as.Date("2010-01-01") + sort(sample(1:3650, 5)) * 30,
      stop = as.Date("2010-01-01") + sort(sample(1:3650, 5)) * 30 + 90,
      exp = sample(1:3, 5, replace=TRUE)
    )
  }))

  # Should complete in reasonable time
  start_time <- Sys.time()
  result <- tvexpose(
    master_data = cohort,
    exposure_file = exposures,
    id = "id",
    start = "start",
    stop = "stop",
    exposure = "exp",
    reference = 0,
    entry = "entry",
    exit = "exit",
    verbose = FALSE
  )
  end_time <- Sys.time()

  elapsed <- as.numeric(difftime(end_time, start_time, units="secs"))

  # Should complete in under 60 seconds for 10K persons
  expect_lt(elapsed, 60)

  # Output should be reasonable size
  expect_gt(nrow(result$data), n_persons)  # At least one row per person
  expect_lt(nrow(result$data), n_persons * 20)  # Not excessive expansion
})
```

---

## 10. Example Usage

### 10.1 Basic Examples

**Example 1: Simple evertreated**

```r
library(tvexpose)

# Load data
cohort <- read.csv("cohort.csv")
exposures <- read.csv("exposures.csv")

# Create ever-treated variable
result <- tvexpose(
  master_data = cohort,
  exposure_file = exposures,
  id = "patient_id",
  start = "rx_start",
  stop = "rx_stop",
  exposure = "drug_type",
  reference = 0,
  entry = "study_entry",
  exit = "study_exit",
  evertreated = TRUE,
  generate = "ever_treated"
)

# Access time-varying dataset
tv_data <- result$data

# View metadata
print(result$metadata$N_persons)
print(result$metadata$pct_exposed)

# Save output
write.csv(tv_data, "tv_evertreated.csv", row.names=FALSE)
```

**Example 2: Current/former with grace period**

```r
result <- tvexpose(
  master_data = cohort,
  exposure_file = exposures,
  id = "patient_id",
  start = "rx_start",
  stop = "rx_stop",
  exposure = "drug_type",
  reference = 0,
  entry = "study_entry",
  exit = "study_exit",
  currentformer = TRUE,
  grace = 30,  # Treat gaps <= 30 days as continuous
  generate = "drug_status"
)

# Result has 0=never, 1=current, 2=former
table(result$data$drug_status)
```

**Example 3: Continuous cumulative exposure by month**

```r
result <- tvexpose(
  master_data = cohort,
  exposure_file = exposures,
  id = "patient_id",
  start = "rx_start",
  stop = "rx_stop",
  exposure = "drug_type",
  reference = 0,
  entry = "study_entry",
  exit = "study_exit",
  continuousunit = "years",
  expandunit = "months",  # One row per calendar month
  generate = "cumul_years"
)

# Each row represents one month with cumulative years
head(result$data)
```

**Example 4: Duration categories**

```r
result <- tvexpose(
  master_data = cohort,
  exposure_file = exposures,
  id = "patient_id",
  start = "rx_start",
  stop = "rx_stop",
  exposure = "drug_type",
  reference = 0,
  entry = "study_entry",
  exit = "study_exit",
  duration = c(1, 5, 10),  # Cutpoints in years
  continuousunit = "years",
  generate = "duration_cat"
)

# Categories: 0=unexposed, 1=<1yr, 2=1-<5yr, 3=5-<10yr, 4=10+yr
table(result$data$duration_cat)
```

**Example 5: Separate variables per exposure type**

```r
result <- tvexpose(
  master_data = cohort,
  exposure_file = exposures,
  id = "patient_id",
  start = "rx_start",
  stop = "rx_stop",
  exposure = "drug_type",
  reference = 0,
  entry = "study_entry",
  exit = "study_exit",
  continuousunit = "years",
  bytype = TRUE,
  generate = "tv_exp"
)

# Creates tv_exp1, tv_exp2, tv_exp3, ... for each drug type
names(result$data)
```

### 10.2 Advanced Examples

**Example 6: Priority-based overlap resolution with lag/washout**

```r
result <- tvexpose(
  master_data = cohort,
  exposure_file = exposures,
  id = "patient_id",
  start = "rx_start",
  stop = "rx_stop",
  exposure = "drug_type",
  reference = 0,
  entry = "study_entry",
  exit = "study_exit",
  priority = c(3, 2, 1),  # Drug 3 highest priority
  lag = 30,               # Exposure active 30 days after start
  washout = 90,           # Effect persists 90 days after stop
  generate = "drug_priority"
)
```

**Example 7: Recency categories**

```r
result <- tvexpose(
  master_data = cohort,
  exposure_file = exposures,
  id = "patient_id",
  start = "rx_start",
  stop = "rx_stop",
  exposure = "drug_type",
  reference = 0,
  entry = "study_entry",
  exit = "study_exit",
  recency = c(1, 5),  # Cutpoints in years since last exposure
  generate = "time_since"
)

# Categories: 0=never, 1=current, 2=<1yr since, 3=1-<5yr since, 4=5+yr since
```

**Example 8: Full workflow with survival analysis**

```r
# Create time-varying exposure
tv_result <- tvexpose(
  master_data = cohort,
  exposure_file = exposures,
  id = "patient_id",
  start = "rx_start",
  stop = "rx_stop",
  exposure = "drug_type",
  reference = 0,
  entry = "study_entry",
  exit = "study_exit",
  currentformer = TRUE,
  grace = 30,
  keepvars = c("age", "sex", "baseline_score"),
  generate = "drug_cf"
)

# Prepare for survival analysis
library(survival)
tv_data <- tv_result$data

# Add failure indicator
tv_data$failure <- ifelse(!is.na(tv_data$outcome_date) &
                          tv_data$outcome_date <= tv_data$exp_stop, 1, 0)

# Cox regression
cox_model <- coxph(Surv(exp_start, exp_stop, failure) ~
                   factor(drug_cf) + age + sex + baseline_score,
                   data = tv_data)

summary(cox_model)
```

**Example 9: Diagnostics and validation**

```r
result <- tvexpose(
  master_data = cohort,
  exposure_file = exposures,
  id = "patient_id",
  start = "rx_start",
  stop = "rx_stop",
  exposure = "drug_type",
  reference = 0,
  entry = "study_entry",
  exit = "study_exit",
  check = TRUE,
  gaps = TRUE,
  overlaps = TRUE,
  summarize = TRUE,
  validate = TRUE
)

# View diagnostics
View(result$diagnostics)

# Check for persons with gaps
gaps <- result$diagnostics[result$diagnostics$coverage_gap > 0, ]
print(gaps)

# View warnings
print(result$warnings)
```

---

## 11. Performance Considerations

### 11.1 Optimization Strategies

**Use data.table throughout:**
- All internal operations use `data.table` for speed
- In-place modifications with `:=`
- Fast grouping with `by=`
- Fast sorting with `setkey()` and `setorder()`

**Minimize data copies:**
- Avoid `rbind`/`cbind` in loops
- Use `rbindlist()` for combining
- Modify in place when possible

**Efficient iterations:**
- Set reasonable max_iter limits (10000)
- Show progress for long operations
- Early termination when convergence reached

**Memory management:**
- Drop temporary columns immediately after use
- Use `rm()` and `gc()` for large intermediate objects
- Consider chunking for very large datasets (100K+ persons)

### 11.2 Performance Benchmarks

**Expected performance (single-threaded):**

| Cohort Size | Avg Periods/Person | Expected Time |
|-------------|-------------------|---------------|
| 1,000 | 5 | <1 second |
| 10,000 | 5 | <10 seconds |
| 100,000 | 5 | <2 minutes |
| 1,000,000 | 5 | <20 minutes |

**Factors increasing processing time:**
- High period fragmentation (50+ periods/person)
- Complex overlap patterns
- Row expansion with fine units (daily)
- Many exposure types with bytype
- Large grace periods requiring many iterations

### 11.3 Scalability Recommendations

**For very large datasets (1M+ persons):**

1. **Process in chunks:**
```r
# Split cohort into chunks
chunk_size <- 50000
n_chunks <- ceiling(nrow(cohort) / chunk_size)

results_list <- list()
for (i in 1:n_chunks) {
  start_idx <- (i-1) * chunk_size + 1
  end_idx <- min(i * chunk_size, nrow(cohort))

  chunk_cohort <- cohort[start_idx:end_idx, ]
  chunk_ids <- chunk_cohort$id
  chunk_exp <- exposures[exposures$id %in% chunk_ids, ]

  chunk_result <- tvexpose(
    master_data = chunk_cohort,
    exposure_file = chunk_exp,
    # ... parameters
    verbose = FALSE
  )

  results_list[[i]] <- chunk_result$data
}

# Combine results
final_data <- rbindlist(results_list)
```

2. **Parallel processing:**
```r
library(parallel)

# Create clusters
cl <- makeCluster(detectCores() - 1)

# Export function and data
clusterExport(cl, c("tvexpose", "cohort", "exposures"))

# Process chunks in parallel
results <- parLapply(cl, chunk_list, function(chunk_ids) {
  tvexpose(
    master_data = cohort[cohort$id %in% chunk_ids, ],
    exposure_file = exposures[exposures$id %in% chunk_ids, ],
    # ... parameters
  )
})

stopCluster(cl)

# Combine
final_data <- rbindlist(lapply(results, `[[`, "data"))
```

3. **Database backend for very large data:**
```r
# Use database for initial filtering/joins
# Only bring final time-varying data into R memory
```

### 11.4 Memory Footprint

**Typical memory usage:**
- Input data: N_persons × avg_periods × columns × 8 bytes
- Peak during processing: ~3x input size (temporary objects)
- Output: Depends on expansion and exposure type

**Memory optimization tips:**
- Use integer types where possible (dates as integer days)
- Drop keepvars not needed for analysis
- Set expandunit=NULL or coarse unit unless fine granularity required
- Consider saveas to disk if output is very large

---

## 12. Implementation Checklist

### Phase 1: Core Infrastructure
- [ ] Implement input validation function
- [ ] Implement data preparation function
- [ ] Create test datasets (small, medium, large)
- [ ] Test basic data loading and merging

### Phase 2: Core Algorithms
- [ ] Implement period merging algorithm
- [ ] Implement contained period removal
- [ ] Implement gap creation
- [ ] Implement baseline/post-exposure period creation
- [ ] Test each algorithm independently

### Phase 3: Overlap Resolution
- [ ] Implement split strategy
- [ ] Implement priority strategy
- [ ] Implement layer strategy
- [ ] Implement combine strategy
- [ ] Test all overlap strategies

### Phase 4: Exposure Types
- [ ] Implement evertreated
- [ ] Implement currentformer
- [ ] Implement continuous cumulative
- [ ] Implement duration categories
- [ ] Implement recency
- [ ] Implement bytype for each
- [ ] Test all exposure types

### Phase 5: Advanced Features
- [ ] Implement row expansion (weeks/months/quarters/years)
- [ ] Implement grace period logic (single and by-category)
- [ ] Implement carryforward logic
- [ ] Implement lag/washout
- [ ] Implement window filter
- [ ] Test advanced features

### Phase 6: Pattern Tracking
- [ ] Implement switching indicator
- [ ] Implement switching detail
- [ ] Implement statetime
- [ ] Test pattern tracking

### Phase 7: Diagnostics
- [ ] Implement check_coverage
- [ ] Implement identify_gaps
- [ ] Implement identify_overlaps
- [ ] Implement summarize_exposure
- [ ] Test diagnostics

### Phase 8: Integration & Polish
- [ ] Implement main wrapper function
- [ ] Implement return value structure
- [ ] Add progress indicators
- [ ] Add informative error messages
- [ ] Write comprehensive documentation
- [ ] Create vignette with examples

### Phase 9: Testing
- [ ] Write unit tests for all algorithms
- [ ] Write integration tests
- [ ] Test all edge cases
- [ ] Performance testing
- [ ] Memory profiling

### Phase 10: Package Creation
- [ ] Create R package structure
- [ ] Write DESCRIPTION, NAMESPACE
- [ ] Add dependencies
- [ ] Build and check package
- [ ] Create GitHub repository
- [ ] Write README with examples
- [ ] Publish to CRAN (optional)

---

## 13. Known Limitations & Future Enhancements

### Current Limitations
1. Does not handle time-varying covariates beyond exposure
2. No built-in support for competing risks
3. No automatic handling of irregular time units (lunar months, etc.)
4. Limited to left-truncated, right-censored survival data
5. No built-in imputation for missing exposure dates

### Potential Future Enhancements
1. **Time-varying covariate support**: Merge multiple time-varying variables
2. **Competing risks**: Mark different failure types
3. **Calendar time splitting**: Automatic calendar period boundaries
4. **Parallel processing**: Built-in parallel support for large datasets
5. **Database integration**: Direct database queries for very large data
6. **Interactive diagnostics**: Shiny app for exploring coverage issues
7. **Visualization**: Plot individual exposure timelines
8. **Multiple exposures**: Handle multiple independent exposures simultaneously
9. **Dose modeling**: Track dose changes within exposure periods
10. **Export formats**: Direct export to SAS, Stata formats

---

## Appendix: Algorithm Complexity

### Time Complexity Analysis

| Algorithm | Best Case | Average Case | Worst Case |
|-----------|-----------|--------------|------------|
| Data preparation | O(n) | O(n) | O(n) |
| Period merging | O(n) | O(n × k) | O(n × 10000) |
| Contained removal | O(n) | O(n × k) | O(n × 10000) |
| Gap creation | O(n) | O(n) | O(n) |
| Split overlap | O(n) | O(n × b) | O(n × b²) |
| Priority overlap | O(n log n) | O(n log n) | O(n log n) |
| Layer overlap | O(n) | O(n) | O(n) |
| Evertreated | O(n) | O(n) | O(n) |
| Current/former | O(n) | O(n) | O(n) |
| Continuous | O(n) | O(n) | O(n × u) |
| Duration | O(n) | O(n) | O(n × u) |
| Recency | O(n) | O(n) | O(n) |

Where:
- n = number of exposure periods
- k = average iterations to convergence (typically <10)
- b = average boundaries per period (for split)
- u = expansion units (for continuous/duration)

### Space Complexity

| Component | Space |
|-----------|-------|
| Input data | O(n) |
| Processing | O(n) to O(3n) |
| Output | O(n) to O(n × u) |

---

**End of tvexpose R Reimplementation Plan**

This plan should provide complete specifications for implementing tvexpose in R. All algorithms are described in detail with R/data.table code patterns. The implementation should achieve feature parity with the Stata version while leveraging R's strengths in statistical computing and package ecosystem.
