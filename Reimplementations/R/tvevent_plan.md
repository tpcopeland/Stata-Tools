# R Reimplementation Plan: tvevent

## Overview

The `tvevent` command integrates outcome events and competing risks into time-varying datasets created by tvexpose/tvmerge. It is the third and final step in the tvtools workflow.

**Core Functionality:**
1. Resolves competing risks (earliest date wins)
2. Splits intervals when events occur mid-interval (start < event < stop)
3. Proportionally adjusts continuous/cumulative variables during splits
4. Creates event status flags (0=censored, 1=primary, 2+=competing)
5. Handles single (terminal) vs recurring events
6. Generates time duration variables

---

## Function Signature

```r
tvevent <- function(
  intervals_data,           # Data frame: master dataset with start/stop intervals
  events_data,              # Data frame: events dataset with event dates
  id,                       # String: name of ID column (must exist in both datasets)
  date,                     # String: name of primary event date column in events_data
  compete = NULL,           # Character vector: competing risk date column names
  generate = "_failure",    # String: name for event indicator variable to create
  type = "single",          # String: "single" (terminal) or "recurring"
  keepvars = NULL,          # Character vector: additional vars from events_data to keep
  continuous = NULL,        # Character vector: cumulative vars to adjust during splits
  timegen = NULL,           # String: name for time duration variable (NULL = don't create)
  timeunit = "days",        # String: "days", "months", or "years"
  eventlabel = NULL,        # Named vector: custom labels (e.g., c("0"="Censored", "1"="Event"))
  replace = FALSE           # Logical: replace generate/timegen if they exist
) {
  # Returns: Modified intervals_data with event flags and adjusted variables
}
```

---

## Input Validation (Comprehensive)

### Phase 1: Parameter Validation

```r
# 1. Check type parameter
type <- tolower(type)
if (!type %in% c("single", "recurring")) {
  stop("type must be either 'single' or 'recurring'")
}

# 2. Check timeunit parameter
timeunit <- tolower(timeunit)
if (!timeunit %in% c("days", "months", "years")) {
  stop("timeunit must be 'days', 'months', or 'years'")
}

# 3. Validate data frames
if (!is.data.frame(intervals_data)) {
  stop("intervals_data must be a data frame")
}
if (!is.data.frame(events_data)) {
  stop("events_data must be a data frame")
}

# 4. Check for zero-length inputs
if (nrow(intervals_data) == 0) {
  stop("intervals_data has no rows")
}
if (nrow(events_data) == 0) {
  warning("events_data has no rows - all intervals will be censored")
  # Continue processing with all failures = 0
}
```

### Phase 2: Master Dataset Validation (intervals_data)

```r
# 1. Required columns from tvexpose/tvmerge
required_cols <- c(id, "start", "stop")
missing_cols <- setdiff(required_cols, names(intervals_data))
if (length(missing_cols) > 0) {
  stop(sprintf(
    "intervals_data missing required columns: %s\n  (tvevent requires output from tvexpose/tvmerge with start/stop columns)",
    paste(missing_cols, collapse=", ")
  ))
}

# 2. Validate continuous variables
if (!is.null(continuous)) {
  missing_cont <- setdiff(continuous, names(intervals_data))
  if (length(missing_cont) > 0) {
    stop(sprintf(
      "Continuous variables not found in intervals_data: %s",
      paste(missing_cont, collapse=", ")
    ))
  }

  # Check that continuous vars are numeric
  non_numeric <- continuous[!sapply(intervals_data[continuous], is.numeric)]
  if (length(non_numeric) > 0) {
    stop(sprintf(
      "Continuous variables must be numeric: %s",
      paste(non_numeric, collapse=", ")
    ))
  }
}

# 3. Check replace option
if (!replace) {
  if (generate %in% names(intervals_data)) {
    stop(sprintf(
      "Variable '%s' already exists in intervals_data. Use replace=TRUE to overwrite.",
      generate
    ))
  }
  if (!is.null(timegen) && timegen %in% names(intervals_data)) {
    stop(sprintf(
      "Variable '%s' already exists in intervals_data. Use replace=TRUE to overwrite.",
      timegen
    ))
  }
} else {
  # Drop existing variables if replace=TRUE
  intervals_data[[generate]] <- NULL
  if (!is.null(timegen)) {
    intervals_data[[timegen]] <- NULL
  }
}

# 4. Validate interval structure
if (any(intervals_data$start >= intervals_data$stop)) {
  stop("intervals_data contains invalid intervals where start >= stop")
}
```

### Phase 3: Using Dataset Validation (events_data)

```r
# 1. Check ID column exists
if (!id %in% names(events_data)) {
  stop(sprintf("ID variable '%s' not found in events_data", id))
}

# 2. Check date column exists and is present
if (!date %in% names(events_data)) {
  stop(sprintf("Date variable '%s' not found in events_data", date))
}

# 3. Date must be numeric/Date (Stata uses numeric dates)
if (!is.numeric(events_data[[date]]) && !inherits(events_data[[date]], "Date")) {
  stop(sprintf("Date variable '%s' must be numeric or Date type", date))
}

# 4. Check competing risk variables
if (!is.null(compete)) {
  missing_compete <- setdiff(compete, names(events_data))
  if (length(missing_compete) > 0) {
    stop(sprintf(
      "Competing event variables not found in events_data: %s",
      paste(missing_compete, collapse=", ")
    ))
  }

  # Check competing vars are numeric/Date
  for (comp_var in compete) {
    if (!is.numeric(events_data[[comp_var]]) && !inherits(events_data[[comp_var]], "Date")) {
      stop(sprintf("Competing variable '%s' must be numeric or Date type", comp_var))
    }
  }
}

# 5. Handle keepvars - default to all vars except id, date, compete
if (is.null(keepvars)) {
  keepvars <- setdiff(
    names(events_data),
    c(id, date, compete)
  )
} else {
  # Validate specified keepvars exist
  missing_keep <- setdiff(keepvars, names(events_data))
  if (length(missing_keep) > 0) {
    stop(sprintf(
      "keepvars not found in events_data: %s",
      paste(missing_keep, collapse=", ")
    ))
  }
}
```

---

## Algorithm Implementation

### Step 1: Prepare Events Dataset - Resolve Competing Risks

**Goal:** For each person, determine the earliest event across primary and competing dates, and track which type it was.

```r
# Create working copy of events data
events_work <- events_data %>%
  select(all_of(c(id, date, compete, keepvars)))

# Floor all dates to day precision (Stata behavior: replace var = floor(var))
events_work[[date]] <- floor(as.numeric(events_work[[date]]))

# Initialize effective date and type
events_work$eff_date <- events_work[[date]]
events_work$eff_type <- ifelse(is.na(events_work[[date]]), NA_integer_, 1L)

# Capture variable labels for later (for default eventlabel)
# In Stata: local lab_1 : variable label `date'
date_label <- attr(events_data[[date]], "label")
if (is.null(date_label) || date_label == "") {
  date_label <- sprintf("Event: %s", date)
}

compete_labels <- list()
if (!is.null(compete)) {
  for (i in seq_along(compete)) {
    comp_var <- compete[i]

    # Floor competing dates
    events_work[[comp_var]] <- floor(as.numeric(events_work[[comp_var]]))

    # Capture label
    comp_label <- attr(events_data[[comp_var]], "label")
    if (is.null(comp_label) || comp_label == "") {
      comp_label <- sprintf("Competing: %s", comp_var)
    }
    compete_labels[[i]] <- comp_label

    # Update effective date/type if this competing date is earlier
    # Stata logic: if !missing(v) & (v < eff_date | missing(eff_date))
    is_earlier <- !is.na(events_work[[comp_var]]) &
                  (events_work[[comp_var]] < events_work$eff_date |
                   is.na(events_work$eff_date))

    events_work$eff_type <- ifelse(is_earlier, i + 1L, events_work$eff_type)
    events_work$eff_date <- ifelse(is_earlier, events_work[[comp_var]], events_work$eff_date)
  }
}

# Keep only observations with valid event dates
events_work <- events_work %>%
  filter(!is.na(eff_date))

# If events_data is now empty, warn and proceed with all censored
if (nrow(events_work) == 0) {
  warning("No valid event dates found after competing risk resolution")
  intervals_data[[generate]] <- 0L
  # Skip to final steps (timegen, return)
  # ... (implement early return logic)
}

# Drop original date column, rename effective date
events_work <- events_work %>%
  select(-all_of(c(date, compete))) %>%
  rename(!!date := eff_date,
         event_type = eff_type)

# Remove duplicate events for same person-date
# Stata: duplicates drop `id' `date', force
events_work <- events_work %>%
  distinct(across(all_of(c(id, date))), .keep_all = TRUE)
```

**Key Implementation Notes:**
- Use `floor()` to match Stata's behavior
- Handle NA propagation carefully in comparisons
- Track event type (1=primary, 2=first compete, 3=second compete, etc.)
- Store variable labels for default eventlabel generation

---

### Step 2: Identify Split Points

**Goal:** Find events that occur strictly WITHIN intervals (start < event < stop). These intervals will need splitting.

```r
# Create minimal interval structure for join
intervals_minimal <- intervals_data %>%
  select(all_of(c(id, "start", "stop"))) %>%
  distinct()

# Join intervals with events (Stata: joinby)
# This creates all combinations where id matches
split_candidates <- intervals_minimal %>%
  inner_join(
    events_work %>% select(all_of(c(id, date))),
    by = id,
    relationship = "many-to-many"  # Explicit many-to-many join
  )

# Keep only events occurring STRICTLY within intervals
# Stata: keep if `date' > start & `date' < stop
splits_needed <- split_candidates %>%
  filter(get(date) > start & get(date) < stop) %>%
  select(all_of(c(id, date))) %>%
  distinct()

n_splits <- nrow(splits_needed)
message(sprintf("Splitting intervals for %d internal events...", n_splits))
```

**Key Implementation Notes:**
- Use `inner_join()` with `relationship = "many-to-many"` to replicate Stata's `joinby` behavior
- Filter for STRICT inequality (> and <, not >= or <=)
- Events occurring exactly at interval boundaries do NOT cause splits

---

### Step 3: Execute Splits and Adjust Continuous Variables

**Goal:** Split intervals at event dates, then proportionally adjust continuous variables.

```r
# Store original duration for continuous adjustment
intervals_data$orig_dur <- intervals_data$stop - intervals_data$start

if (n_splits > 0) {
  # Join split points to intervals
  intervals_data <- intervals_data %>%
    left_join(
      splits_needed,
      by = id,
      relationship = "many-to-many"
    )

  # Flag intervals that need splitting
  # Stata: gen long _needs_split = (`date' > start & `date' < stop)
  intervals_data <- intervals_data %>%
    mutate(
      needs_split = !is.na(get(date)) & get(date) > start & get(date) < stop
    )

  # Expand rows that need splitting (Stata: expand 2 if _needs_split, gen(_copy))
  split_rows <- intervals_data %>%
    filter(needs_split) %>%
    mutate(copy = 1)  # Second copy

  # First copy: end at event date
  split_rows_pre <- split_rows %>%
    mutate(
      stop = get(date),
      copy = 0
    )

  # Second copy: start at event date
  split_rows_post <- split_rows %>%
    mutate(
      start = get(date),
      copy = 1
    )

  # Combine: keep non-split rows + both halves of split rows
  intervals_data <- bind_rows(
    intervals_data %>% filter(!needs_split) %>% select(-needs_split),
    split_rows_pre %>% select(-needs_split),
    split_rows_post %>% select(-needs_split)
  ) %>%
    select(-copy) %>%  # Drop temporary copy indicator
    arrange(across(all_of(c(id, "start", "stop"))))

  # Remove duplicates (Stata: duplicates drop `id' start stop, force)
  intervals_data <- intervals_data %>%
    distinct(across(all_of(c(id, "start", "stop"))), .keep_all = TRUE)
}

# Adjust continuous variables proportionally
if (!is.null(continuous)) {
  intervals_data <- intervals_data %>%
    mutate(
      new_dur = stop - start,
      ratio = ifelse(orig_dur == 0 | new_dur == 0, 1, new_dur / orig_dur)
    )

  # Multiply each continuous variable by ratio
  for (cont_var in continuous) {
    intervals_data[[cont_var]] <- intervals_data[[cont_var]] * intervals_data$ratio
  }

  intervals_data <- intervals_data %>%
    select(-new_dur, -ratio)
}

# Drop original duration tracking variable
intervals_data <- intervals_data %>%
  select(-orig_dur)
```

**Key Implementation Notes:**
- Use `left_join()` to preserve all intervals (unmatched intervals have no event)
- Split by creating two rows: one ending at event, one starting at event
- Proportional adjustment formula: `new_value = old_value * (new_duration / old_duration)`
- Handle division by zero: if either duration is 0, use ratio = 1 (no adjustment)
- Remove duplicates after splitting (can occur with multiple events on same date)

**Why This Matters:**
- Cumulative variables (total dose, total exposure days) need adjustment when intervals split
- Example: 100mg over 30 days split at day 10 becomes 33.3mg (10 days) + 66.7mg (20 days)
- Preserves both rate (mg/day) and total sum

---

### Step 4: Merge Event Flags

**Goal:** Match events to intervals where the interval ENDS at the event date (stop == event_date), then flag event type.

```r
# Create match variable (stop date)
intervals_data$match_date <- intervals_data$stop

# Prepare events for merging (rename date to match_date)
events_for_merge <- events_work %>%
  rename(match_date = !!sym(date))

# Left join on id + match_date (Stata uses frames/frlink, but left_join is clearer in R)
intervals_data <- intervals_data %>%
  left_join(
    events_for_merge %>% select(all_of(c(id, "match_date", "event_type", keepvars))),
    by = c(id, "match_date"),
    relationship = "many-to-one",  # Multiple intervals can end at same event
    suffix = c("", "_event")
  )

# Create failure indicator
# Stata: gen long `generate' = `imported_type'; replace `generate' = 0 if missing(.)
intervals_data[[generate]] <- ifelse(
  is.na(intervals_data$event_type),
  0L,
  as.integer(intervals_data$event_type)
)

# Clean up temporary variables
intervals_data <- intervals_data %>%
  select(-match_date, -event_type)
```

**Key Implementation Notes:**
- Match on BOTH id and stop date (events flag the END of an interval)
- Use `left_join()` to preserve all intervals (unmatched = censored)
- Missing event_type becomes 0 (censored)
- Keep all keepvars from events_data for intervals where event occurred

**Edge Case Handling:**
- Events at interval boundaries (start or stop) are NOT internal splits
- Event at stop: flagged as failure for that interval
- Event at start: would flag the PREVIOUS interval (if exists) but typically doesn't exist in tvexpose output
- Events before first interval or after last interval: ignored (no matching stop date)

---

### Step 5: Apply Event Labels

**Goal:** Create factor labels for the event status variable.

```r
# Build default labels
labels <- c("0" = "Censored", "1" = date_label)

# Add competing risk labels
if (!is.null(compete)) {
  for (i in seq_along(compete_labels)) {
    labels[as.character(i + 1)] <- compete_labels[[i]]
  }
}

# Override with user-specified eventlabel
if (!is.null(eventlabel)) {
  # eventlabel should be named vector: c("0"="Censored", "1"="My Event", ...)
  if (is.null(names(eventlabel))) {
    stop("eventlabel must be a named vector (e.g., c('0'='Censored', '1'='Event'))")
  }

  # Merge user labels (user values override defaults)
  for (val in names(eventlabel)) {
    labels[val] <- eventlabel[val]
  }
}

# Convert to factor with labels
# Get unique values present in data
present_vals <- sort(unique(intervals_data[[generate]]))
present_labels <- labels[as.character(present_vals)]

# Create factor (only include levels actually present)
intervals_data[[generate]] <- factor(
  intervals_data[[generate]],
  levels = present_vals,
  labels = present_labels
)

# Add variable label attribute (for documentation)
attr(intervals_data[[generate]], "label") <- "Event Status"
```

**Key Implementation Notes:**
- Default labels: 0="Censored", 1=primary date label, 2+=compete labels
- User can override with eventlabel parameter
- Only create factor levels for values actually present in data
- Store human-readable labels for output

---

### Step 6: Apply Type-Specific Logic (Single vs Recurring)

**Goal:** For single events, censor all follow-up after first event. For recurring, keep all intervals.

#### Type = "single" (default)

```r
if (type == "single") {
  # Find first event per person
  # Stata: bysort `id' (stop): gen long _event_rank = sum(`generate' > 0)
  intervals_data <- intervals_data %>%
    arrange(across(all_of(c(id, "stop")))) %>%
    group_by(across(all_of(id))) %>%
    mutate(
      event_rank = cumsum(as.integer(get(generate)) > 0)
    ) %>%
    ungroup()

  # Find time of first failure
  # Stata: gen double `censor_time' = stop if `generate' > 0 & _event_rank == 1
  #        bysort `id': egen double _first_fail = min(`censor_time')
  intervals_data <- intervals_data %>%
    mutate(
      censor_time = ifelse(as.integer(get(generate)) > 0 & event_rank == 1, stop, NA_real_)
    ) %>%
    group_by(across(all_of(id))) %>%
    mutate(
      first_fail = min(censor_time, na.rm = TRUE)
    ) %>%
    ungroup()

  # Drop intervals starting at or after first failure
  # Stata: drop if !missing(_first_fail) & start >= _first_fail
  intervals_data <- intervals_data %>%
    filter(is.na(first_fail) | is.infinite(first_fail) | start < first_fail)

  # Reset failure flag for any subsequent events (after first)
  # Stata: replace `generate' = 0 if _event_rank > 1
  intervals_data <- intervals_data %>%
    mutate(
      !!sym(generate) := ifelse(
        event_rank > 1,
        factor(0, levels = levels(get(generate)), labels = levels(get(generate))),
        get(generate)
      )
    )

  # Clean up temporary variables
  intervals_data <- intervals_data %>%
    select(-event_rank, -censor_time, -first_fail)

  message("Single event type: Censored person-time after first event.")

} else {
  # type == "recurring"
  # No modification needed - keep all intervals
  message("Recurring event type: Retained all person-time.")
}
```

**Key Implementation Notes:**
- Single: First event is TERMINAL, drop all follow-up after
- Recurring: Keep all intervals, allow multiple events per person
- Use `cumsum()` to track event rank within person
- Filter out post-event intervals for single events
- Reset any post-first-event flags to 0 (censored)

**Edge Cases:**
- Person with no events: all intervals kept (both types)
- Person with multiple events on different dates: only first counts (single)
- Person with multiple events on same date: treated as one event

---

### Step 7: Generate Time Duration Variable (Optional)

**Goal:** Create variable with interval duration in specified units.

```r
if (!is.null(timegen)) {
  # Calculate duration in days
  days_diff <- intervals_data$stop - intervals_data$start

  # Convert to requested unit
  if (timeunit == "days") {
    intervals_data[[timegen]] <- days_diff
    attr(intervals_data[[timegen]], "label") <- "Time (days)"

  } else if (timeunit == "months") {
    # Stata: days / 30.4375 (average days per month)
    intervals_data[[timegen]] <- days_diff / 30.4375
    attr(intervals_data[[timegen]], "label") <- "Time (months)"

  } else if (timeunit == "years") {
    # Stata: days / 365.25 (accounting for leap years)
    intervals_data[[timegen]] <- days_diff / 365.25
    attr(intervals_data[[timegen]], "label") <- "Time (years)"
  }
}
```

**Key Implementation Notes:**
- Use exact conversion factors from Stata
- Months: 30.4375 days (365.25/12)
- Years: 365.25 days (accounting for leap years)
- Add variable label for documentation

**Use Cases:**
- Poisson regression offset: `log(time_years)`
- Rate calculations: events/person-years
- Summary statistics: total follow-up time

---

### Step 8: Final Formatting and Output

```r
# Apply date formatting to start/stop (if not already formatted)
# Stata: format start stop %tdCCYY/NN/DD
# In R, ensure Date class
if (!inherits(intervals_data$start, "Date")) {
  intervals_data$start <- as.Date(intervals_data$start, origin = "1970-01-01")
}
if (!inherits(intervals_data$stop, "Date")) {
  intervals_data$stop <- as.Date(intervals_data$stop, origin = "1970-01-01")
}

# Sort by id, start, stop
intervals_data <- intervals_data %>%
  arrange(across(all_of(c(id, "start", "stop"))))

# Calculate summary statistics
n_total <- nrow(intervals_data)
n_failures <- sum(as.integer(intervals_data[[generate]]) > 0)

# Display summary (matching Stata output)
cat("\n")
cat(strrep("-", 50), "\n")
cat("Event integration complete\n")
cat(sprintf("  Observations: %d\n", n_total))
cat(sprintf("  Events flagged (%s): %d\n", generate, n_failures))
cat(sprintf("  Variable %s labels:\n", generate))

# Display label frequencies
label_table <- table(intervals_data[[generate]])
for (i in seq_along(label_table)) {
  cat(sprintf("    %s = %s\n",
              names(label_table)[i],
              names(label_table)[i]))
}
cat(strrep("-", 50), "\n")

# Return result with attributes
result <- list(
  data = intervals_data,
  N = n_total,
  N_events = n_failures,
  generate = generate,
  type = type
)

class(result) <- c("tvevent", "list")
return(result)
```

**Return Structure:**
- `data`: Modified intervals_data with event flags
- `N`: Total observations
- `N_events`: Number of flagged events
- `generate`: Name of event variable
- `type`: Event type (single/recurring)

---

## Complete Error Handling Strategy

### Error Categories

1. **Invalid Parameters**
   - type not in {single, recurring}
   - timeunit not in {days, months, years}
   - Non-data.frame inputs

2. **Missing Required Columns**
   - intervals_data missing: id, start, stop
   - events_data missing: id, date
   - Missing compete/continuous/keepvars

3. **Variable Type Mismatches**
   - Date columns not numeric/Date
   - Continuous variables not numeric
   - ID columns different types between datasets

4. **Data Structure Issues**
   - Invalid intervals (start >= stop)
   - Duplicate intervals (same id-start-stop)
   - Zero-row datasets

5. **Name Conflicts**
   - generate/timegen already exist (without replace=TRUE)

6. **Edge Cases (Warnings, Not Errors)**
   - No valid events after competing risk resolution
   - No events fall within any intervals
   - All intervals already end at events (no splits needed)

### Error Message Format

```r
# Use informative, actionable error messages:

# BAD:
stop("Invalid type")

# GOOD:
stop(sprintf(
  "type must be either 'single' or 'recurring', got: '%s'",
  type
))

# BEST (with context):
stop(sprintf(
  "type must be either 'single' or 'recurring', got: '%s'\n  single: first event is terminal (default)\n  recurring: allows multiple events",
  type
))
```

---

## Testing Strategy

### Unit Tests (testthat framework)

#### Test 1: Basic Functionality

```r
test_that("tvevent basic functionality works", {
  # Create simple test data
  intervals <- data.frame(
    id = c(1, 1, 2, 2),
    start = as.Date(c("2020-01-01", "2020-07-01", "2020-01-01", "2020-06-01")),
    stop = as.Date(c("2020-06-30", "2020-12-31", "2020-05-31", "2020-12-31"))
  )

  events <- data.frame(
    id = c(1, 2),
    event_date = as.Date(c("2020-09-15", "2020-08-01"))
  )

  result <- tvevent(
    intervals_data = intervals,
    events_data = events,
    id = "id",
    date = "event_date",
    generate = "failure"
  )

  # Assertions
  expect_s3_class(result, "tvevent")
  expect_true("failure" %in% names(result$data))
  expect_equal(sum(as.integer(result$data$failure) > 0), 2)  # 2 events
  expect_gt(result$N, nrow(intervals))  # Should have more rows due to splitting
})
```

#### Test 2: Competing Risks

```r
test_that("tvevent competing risks resolution works", {
  intervals <- data.frame(
    id = c(1, 2, 3),
    start = as.Date(c("2020-01-01", "2020-01-01", "2020-01-01")),
    stop = as.Date(c("2020-12-31", "2020-12-31", "2020-12-31"))
  )

  events <- data.frame(
    id = c(1, 2, 3),
    primary_date = as.Date(c("2020-06-01", "2020-08-01", NA)),
    death_date = as.Date(c("2020-09-01", "2020-05-01", "2020-07-01"))
  )

  result <- tvevent(
    intervals_data = intervals,
    events_data = events,
    id = "id",
    date = "primary_date",
    compete = "death_date",
    generate = "outcome"
  )

  # Person 1: primary at 2020-06-01 (earlier than death)
  expect_equal(as.integer(result$data$outcome[result$data$id == 1 &
                          result$data$stop == as.Date("2020-06-01")]), 1)

  # Person 2: death at 2020-05-01 (earlier than primary)
  expect_equal(as.integer(result$data$outcome[result$data$id == 2 &
                          result$data$stop == as.Date("2020-05-01")]), 2)

  # Person 3: death only (no primary)
  expect_equal(as.integer(result$data$outcome[result$data$id == 3 &
                          result$data$stop == as.Date("2020-07-01")]), 2)
})
```

#### Test 3: Interval Splitting

```r
test_that("tvevent splits intervals correctly", {
  intervals <- data.frame(
    id = 1,
    start = as.Date("2020-01-01"),
    stop = as.Date("2020-12-31")
  )

  events <- data.frame(
    id = 1,
    event_date = as.Date("2020-06-15")  # Mid-interval
  )

  result <- tvevent(
    intervals_data = intervals,
    events_data = events,
    id = "id",
    date = "event_date"
  )

  # Should split into 2 intervals
  expect_equal(nrow(result$data), 2)

  # First interval: Jan 1 to Jun 15
  expect_equal(result$data$start[1], as.Date("2020-01-01"))
  expect_equal(result$data$stop[1], as.Date("2020-06-15"))
  expect_equal(as.integer(result$data$`_failure`[1]), 0)  # No event yet

  # Second interval: Jun 15 to Dec 31
  expect_equal(result$data$start[2], as.Date("2020-06-15"))
  expect_equal(result$data$stop[2], as.Date("2020-12-31"))
  expect_equal(as.integer(result$data$`_failure`[2]), 0)  # Event was at boundary

  # BUT: we also need to check if there's a row ending at Jun 15 with event
  # Actually, this depends on whether event is AT stop or WITHIN interval
  # Need to review Stata logic more carefully here
})
```

#### Test 4: Events at Boundaries (Edge Case)

```r
test_that("tvevent handles events at interval boundaries", {
  intervals <- data.frame(
    id = c(1, 1),
    start = as.Date(c("2020-01-01", "2020-07-01")),
    stop = as.Date(c("2020-06-30", "2020-12-31"))
  )

  events <- data.frame(
    id = 1,
    event_date = as.Date("2020-06-30")  # Exactly at interval end
  )

  result <- tvevent(
    intervals_data = intervals,
    events_data = events,
    id = "id",
    date = "event_date"
  )

  # Should NOT split (event is AT boundary, not WITHIN)
  expect_equal(nrow(result$data), 2)  # Same as input

  # Event should flag the interval ending at that date
  expect_equal(as.integer(result$data$`_failure`[
    result$data$stop == as.Date("2020-06-30")
  ]), 1)
})
```

#### Test 5: Continuous Variable Adjustment

```r
test_that("tvevent adjusts continuous variables proportionally", {
  intervals <- data.frame(
    id = 1,
    start = as.Date("2020-01-01"),
    stop = as.Date("2020-01-31"),  # 30 days
    total_dose = 300  # 10 mg/day
  )

  events <- data.frame(
    id = 1,
    event_date = as.Date("2020-01-11")  # Day 10
  )

  result <- tvevent(
    intervals_data = intervals,
    events_data = events,
    id = "id",
    date = "event_date",
    continuous = "total_dose"
  )

  # Should split into 2 intervals
  expect_equal(nrow(result$data), 2)

  # First interval: 10 days, should have 100 mg (10/30 * 300)
  expect_equal(
    result$data$total_dose[result$data$stop == as.Date("2020-01-11")],
    100,
    tolerance = 0.01
  )

  # Second interval: 20 days, should have 200 mg (20/30 * 300)
  expect_equal(
    result$data$total_dose[result$data$stop == as.Date("2020-01-31")],
    200,
    tolerance = 0.01
  )

  # Total should be preserved
  expect_equal(sum(result$data$total_dose), 300, tolerance = 0.01)
})
```

#### Test 6: Single vs Recurring Event Types

```r
test_that("tvevent single type censors after first event", {
  intervals <- data.frame(
    id = c(1, 1, 1),
    start = as.Date(c("2020-01-01", "2020-04-01", "2020-07-01")),
    stop = as.Date(c("2020-03-31", "2020-06-30", "2020-09-30"))
  )

  events <- data.frame(
    id = c(1, 1),
    event_date = as.Date(c("2020-05-15", "2020-08-15"))  # Two events
  )

  # Single event type
  result_single <- tvevent(
    intervals_data = intervals,
    events_data = events,
    id = "id",
    date = "event_date",
    type = "single"
  )

  # Should only have intervals up to first event (May 15)
  expect_true(all(result_single$data$start < as.Date("2020-05-15") |
                  result_single$data$stop <= as.Date("2020-05-15")))

  # Only one event should be flagged
  expect_equal(sum(as.integer(result_single$data$`_failure`) > 0), 1)

  # Recurring event type
  result_recurring <- tvevent(
    intervals_data = intervals,
    events_data = events,
    id = "id",
    date = "event_date",
    type = "recurring"
  )

  # Should have all intervals
  expect_gt(max(result_recurring$data$stop), as.Date("2020-05-15"))

  # Both events should be flagged
  expect_equal(sum(as.integer(result_recurring$data$`_failure`) > 0), 2)
})
```

#### Test 7: Time Generation

```r
test_that("tvevent generates time duration variable correctly", {
  intervals <- data.frame(
    id = 1,
    start = as.Date("2020-01-01"),
    stop = as.Date("2020-12-31")  # 366 days (leap year)
  )

  events <- data.frame(
    id = 1,
    event_date = as.Date("2021-01-15")  # After interval
  )

  # Days
  result_days <- tvevent(
    intervals_data = intervals,
    events_data = events,
    id = "id",
    date = "event_date",
    timegen = "time",
    timeunit = "days"
  )
  expect_equal(result_days$data$time, 366)

  # Months
  result_months <- tvevent(
    intervals_data = intervals,
    events_data = events,
    id = "id",
    date = "event_date",
    timegen = "time",
    timeunit = "months"
  )
  expect_equal(result_months$data$time, 366 / 30.4375, tolerance = 0.01)

  # Years
  result_years <- tvevent(
    intervals_data = intervals,
    events_data = events,
    id = "id",
    date = "event_date",
    timegen = "time",
    timeunit = "years"
  )
  expect_equal(result_years$data$time, 366 / 365.25, tolerance = 0.001)
})
```

#### Test 8: Events Outside All Intervals

```r
test_that("tvevent handles events outside intervals", {
  intervals <- data.frame(
    id = c(1, 2),
    start = as.Date(c("2020-01-01", "2020-01-01")),
    stop = as.Date(c("2020-12-31", "2020-12-31"))
  )

  events <- data.frame(
    id = c(1, 2, 3),
    event_date = as.Date(c("2019-06-01",  # Before interval
                           "2021-06-01",  # After interval
                           "2020-06-01"))  # No matching person
  )

  result <- tvevent(
    intervals_data = intervals,
    events_data = events,
    id = "id",
    date = "event_date"
  )

  # All intervals should be censored (no events match)
  expect_equal(sum(as.integer(result$data$`_failure`) > 0), 0)
  expect_equal(nrow(result$data), 2)  # Same as input (no splits)
})
```

#### Test 9: Empty Datasets

```r
test_that("tvevent handles empty datasets gracefully", {
  intervals <- data.frame(
    id = integer(),
    start = as.Date(character()),
    stop = as.Date(character())
  )

  events <- data.frame(
    id = integer(),
    event_date = as.Date(character())
  )

  expect_error(
    tvevent(intervals, events, "id", "event_date"),
    "intervals_data has no rows"
  )

  # Non-empty intervals, empty events (should warn but proceed)
  intervals2 <- data.frame(
    id = 1,
    start = as.Date("2020-01-01"),
    stop = as.Date("2020-12-31")
  )

  expect_warning(
    result <- tvevent(intervals2, events, "id", "event_date"),
    "events_data has no rows"
  )

  expect_equal(nrow(result$data), 1)
  expect_equal(as.integer(result$data$`_failure`), 0)  # Censored
})
```

#### Test 10: Replace Option

```r
test_that("tvevent replace option works", {
  intervals <- data.frame(
    id = 1,
    start = as.Date("2020-01-01"),
    stop = as.Date("2020-12-31"),
    `_failure` = 999  # Pre-existing variable
  )

  events <- data.frame(
    id = 1,
    event_date = as.Date("2020-06-15")
  )

  # Without replace: should error
  expect_error(
    tvevent(intervals, events, "id", "event_date"),
    "Variable '_failure' already exists"
  )

  # With replace: should succeed
  result <- tvevent(
    intervals, events, "id", "event_date",
    replace = TRUE
  )

  expect_true("_failure" %in% names(result$data))
  expect_false(any(result$data$`_failure` == 999))  # Old values gone
})
```

### Integration Tests

#### Integration Test 1: Complete tvtools Workflow

```r
test_that("tvevent integrates with tvexpose/tvmerge workflow", {
  # Simulate tvexpose output
  tv_exposure <- data.frame(
    id = rep(1:3, each = 4),
    start = as.Date(rep(c("2020-01-01", "2020-04-01", "2020-07-01", "2020-10-01"), 3)),
    stop = as.Date(rep(c("2020-03-31", "2020-06-30", "2020-09-30", "2020-12-31"), 3)),
    tv_exposure = c(
      0, 1, 1, 0,  # Person 1
      0, 0, 1, 1,  # Person 2
      1, 1, 0, 0   # Person 3
    )
  )

  # Events with competing risks
  outcomes <- data.frame(
    id = 1:3,
    outcome_date = as.Date(c("2020-05-15", "2020-11-20", NA)),
    death_date = as.Date(c(NA, NA, "2020-08-10"))
  )

  result <- tvevent(
    intervals_data = tv_exposure,
    events_data = outcomes,
    id = "id",
    date = "outcome_date",
    compete = "death_date",
    generate = "status",
    type = "single"
  )

  # Person 1: should split at May 15, then censor
  # Person 2: should split at Nov 20, then censor
  # Person 3: should split at Aug 10 (death), then censor

  expect_gt(nrow(result$data), nrow(tv_exposure))  # More rows due to splits
  expect_equal(result$N_events, 3)  # All 3 persons have events

  # Verify no person has data after their event
  for (pid in 1:3) {
    person_data <- result$data[result$data$id == pid, ]
    event_rows <- person_data[as.integer(person_data$status) > 0, ]

    if (nrow(event_rows) > 0) {
      max_event_time <- max(event_rows$stop)
      expect_true(all(person_data$start <= max_event_time))
    }
  }
})
```

### Edge Case Tests

#### Edge Case 1: Multiple Events Same Date

```r
test_that("tvevent handles multiple events on same date", {
  intervals <- data.frame(
    id = 1,
    start = as.Date("2020-01-01"),
    stop = as.Date("2020-12-31")
  )

  events <- data.frame(
    id = c(1, 1, 1),
    event_date = as.Date(c("2020-06-15", "2020-06-15", "2020-06-15")),
    event_code = c("A", "B", "C")  # Different events, same date
  )

  result <- tvevent(
    intervals_data = intervals,
    events_data = events,
    id = "id",
    date = "event_date",
    keepvars = "event_code"
  )

  # Should deduplicate to one event
  # (Stata does: duplicates drop `id' `date', force)
  expect_equal(sum(as.integer(result$data$`_failure`) > 0), 1)
})
```

#### Edge Case 2: Zero-Duration Intervals

```r
test_that("tvevent handles zero-duration intervals", {
  intervals <- data.frame(
    id = c(1, 1),
    start = as.Date(c("2020-01-01", "2020-06-15")),
    stop = as.Date(c("2020-01-01", "2020-12-31")),  # First has zero duration
    dose = c(0, 100)
  )

  events <- data.frame(
    id = 1,
    event_date = as.Date("2020-09-01")
  )

  # Should handle without error (ratio = 1 for zero duration)
  expect_silent(
    result <- tvevent(
      intervals, events, "id", "event_date",
      continuous = "dose"
    )
  )

  # Zero-duration interval should keep dose = 0
  expect_equal(
    result$data$dose[result$data$start == result$data$stop],
    0
  )
})
```

#### Edge Case 3: All Events Compete Away Primary

```r
test_that("tvevent handles all primary events beaten by competing", {
  intervals <- data.frame(
    id = 1:3,
    start = as.Date(rep("2020-01-01", 3)),
    stop = as.Date(rep("2020-12-31", 3))
  )

  events <- data.frame(
    id = 1:3,
    primary = as.Date(c("2020-08-01", "2020-09-01", "2020-10-01")),
    death = as.Date(c("2020-05-01", "2020-06-01", "2020-07-01"))  # All earlier
  )

  result <- tvevent(
    intervals, events, "id", "primary",
    compete = "death",
    generate = "outcome"
  )

  # All events should be type 2 (competing), none type 1 (primary)
  expect_equal(sum(as.integer(result$data$outcome) == 1), 0)
  expect_equal(sum(as.integer(result$data$outcome) == 2), 3)
})
```

---

## Example Usage Code

### Example 1: Basic Single Event Analysis

```r
library(dplyr)
library(lubridate)

# Create sample cohort data
cohort <- data.frame(
  id = 1:100,
  study_entry = as.Date("2020-01-01") + sample(0:365, 100, replace = TRUE),
  study_exit = as.Date("2022-12-31"),
  age = sample(18:80, 100, replace = TRUE),
  sex = sample(c("M", "F"), 100, replace = TRUE)
)

# Create exposure data (medication periods)
exposure <- data.frame(
  id = rep(1:100, each = 3),
  rx_start = as.Date("2020-01-01") + sample(0:730, 300, replace = TRUE),
  rx_stop = as.Date("2020-01-01") + sample(0:730, 300, replace = TRUE)
) %>%
  mutate(rx_stop = pmax(rx_start + 30, rx_stop)) %>%  # At least 30 days
  arrange(id, rx_start)

# Create time-varying dataset (would use tvexpose in real workflow)
tv_data <- cohort %>%
  select(id, start = study_entry, stop = study_exit, age, sex)

# Create outcome data
outcomes <- data.frame(
  id = sample(1:100, 50),  # 50 people have events
  event_date = as.Date("2020-01-01") + sample(0:1095, 50, replace = TRUE),
  death_date = as.Date("2020-01-01") + sample(0:1095, 50, replace = TRUE)
)

# Apply tvevent
result <- tvevent(
  intervals_data = tv_data,
  events_data = outcomes,
  id = "id",
  date = "event_date",
  compete = "death_date",
  generate = "outcome",
  type = "single",
  timegen = "followup_years",
  timeunit = "years"
)

# Use result for survival analysis
library(survival)

survdata <- result$data %>%
  mutate(
    event = as.integer(outcome) == 1,  # Primary outcome only
    time = followup_years
  )

# Cox model
cox_model <- coxph(Surv(time, event) ~ age + sex, data = survdata)
summary(cox_model)

# Competing risks analysis
library(cmprsk)

survdata2 <- result$data %>%
  group_by(id) %>%
  summarize(
    time = sum(followup_years),
    status = max(as.integer(outcome)),
    age = first(age),
    sex = first(sex)
  )

crr_model <- crr(
  ftime = survdata2$time,
  fstatus = survdata2$status,
  cov1 = model.matrix(~ age + sex, data = survdata2)[, -1]
)
```

### Example 2: Recurring Events with Dose Adjustment

```r
# Time-varying exposure with cumulative dose
tv_exposure <- data.frame(
  id = rep(1:50, each = 4),
  start = as.Date("2020-01-01") + rep(c(0, 90, 180, 270), 50),
  stop = as.Date("2020-01-01") + rep(c(89, 179, 269, 364), 50),
  dose = rnorm(200, mean = 100, sd = 20),  # mg/interval
  exposure_status = rep(c(1, 1, 0, 0), 50)  # Exposed first 2 quarters
) %>%
  mutate(cumulative_dose = dose * as.numeric(stop - start))

# Recurring outcome (e.g., hospitalizations)
hospitalizations <- data.frame(
  id = rep(sample(1:50, 20), sample(1:5, 20, replace = TRUE)),
  hosp_date = as.Date("2020-01-01") + sample(0:364, 82, replace = TRUE)
) %>%
  arrange(id, hosp_date)

# Apply tvevent with continuous adjustment
result <- tvevent(
  intervals_data = tv_exposure,
  events_data = hospitalizations,
  id = "id",
  date = "hosp_date",
  generate = "hospitalized",
  type = "recurring",  # Keep all follow-up
  continuous = "cumulative_dose",  # Adjust proportionally
  timegen = "interval_time",
  timeunit = "days"
)

# Poisson regression (rate of events)
library(lme4)

poisson_model <- glmer(
  hospitalized ~ exposure_status + offset(log(interval_time + 1)) + (1 | id),
  data = result$data,
  family = poisson
)

summary(poisson_model)

# Verify cumulative dose preserved
result$data %>%
  group_by(id) %>%
  summarize(
    original_total = first(cumulative_dose) * 4,  # 4 intervals originally
    split_total = sum(cumulative_dose)
  ) %>%
  mutate(diff = abs(original_total - split_total)) %>%
  summarize(max_diff = max(diff))  # Should be near zero
```

### Example 3: Custom Event Labels

```r
# Multiple competing risks with custom labels
outcomes_multi <- data.frame(
  id = 1:100,
  progression = as.Date("2020-01-01") + sample(0:1095, 100, replace = TRUE),
  death = as.Date("2020-01-01") + sample(0:1095, 100, replace = TRUE),
  emigration = as.Date("2020-01-01") + sample(0:1095, 100, replace = TRUE)
)

result <- tvevent(
  intervals_data = tv_data,
  events_data = outcomes_multi,
  id = "id",
  date = "progression",
  compete = c("death", "emigration"),
  generate = "status",
  type = "single",
  eventlabel = c(
    "0" = "Censored",
    "1" = "Disease Progression",
    "2" = "Death",
    "3" = "Emigration"
  )
)

# Summary table
table(result$data$status)
```

### Example 4: Integration with tidyverse Workflow

```r
library(tidyverse)

# Complete pipeline
analysis_data <- cohort %>%
  # Step 1: Create time-varying structure (simplified tvexpose)
  mutate(start = study_entry, stop = study_exit) %>%

  # Step 2: Apply tvevent
  {tvevent(
    intervals_data = .,
    events_data = outcomes,
    id = "id",
    date = "event_date",
    compete = "death_date",
    generate = "outcome",
    timegen = "time_years",
    timeunit = "years"
  )} %>%
  pluck("data") %>%  # Extract data frame from result object

  # Step 3: Further processing
  group_by(id) %>%
  mutate(
    interval_num = row_number(),
    cumulative_time = cumsum(time_years)
  ) %>%
  ungroup()

# Visualize
library(ggplot2)

analysis_data %>%
  filter(id <= 10) %>%  # First 10 people
  ggplot(aes(x = start, xend = stop, y = factor(id), yend = factor(id))) +
  geom_segment(aes(color = factor(outcome)), size = 3) +
  scale_color_manual(
    values = c("0" = "gray70", "1" = "red", "2" = "black"),
    labels = c("0" = "Censored", "1" = "Event", "2" = "Death")
  ) +
  labs(
    title = "Time-varying follow-up with outcomes",
    x = "Calendar Time",
    y = "Person ID",
    color = "Status"
  ) +
  theme_minimal()
```

---

## Implementation Checklist

### Phase 1: Core Function
- [ ] Function signature with all parameters
- [ ] Parameter validation (type, timeunit, data frames)
- [ ] Master dataset validation (intervals_data)
- [ ] Using dataset validation (events_data)
- [ ] Default keepvars logic

### Phase 2: Event Processing
- [ ] Floor dates to day precision
- [ ] Competing risk resolution loop
- [ ] Variable label capture for eventlabel
- [ ] Event deduplication
- [ ] Empty events handling

### Phase 3: Interval Splitting
- [ ] Identify split points (inner join)
- [ ] Filter for internal events (start < event < stop)
- [ ] Track original duration
- [ ] Expand and split rows
- [ ] Deduplicate result

### Phase 4: Adjustments
- [ ] Continuous variable proportional adjustment
- [ ] Calculate ratio (new_dur / orig_dur)
- [ ] Handle zero-duration edge case
- [ ] Clean up temporary variables

### Phase 5: Event Flags
- [ ] Create match_date variable
- [ ] Left join events on id + match_date
- [ ] Create failure indicator
- [ ] Merge keepvars
- [ ] Clean up temporary variables

### Phase 6: Labels and Type Logic
- [ ] Build default labels from variable labels
- [ ] Apply user eventlabel overrides
- [ ] Convert to factor with labels
- [ ] Single event: event rank calculation
- [ ] Single event: find first failure time
- [ ] Single event: drop post-event intervals
- [ ] Single event: reset subsequent event flags
- [ ] Recurring: no modifications (message only)

### Phase 7: Output
- [ ] Generate time duration variable
- [ ] Convert timeunit (days/months/years)
- [ ] Format start/stop as Date
- [ ] Sort by id, start, stop
- [ ] Calculate summary statistics
- [ ] Display summary output
- [ ] Return structured result

### Phase 8: Testing
- [ ] Unit tests for each component
- [ ] Integration tests with workflow
- [ ] Edge case tests
- [ ] Performance tests with large data
- [ ] Documentation examples

### Phase 9: Documentation
- [ ] Function documentation (roxygen2)
- [ ] Parameter descriptions
- [ ] Examples in docs
- [ ] Vignette with complete workflow
- [ ] README with installation

---

## Performance Considerations

### Expected Performance

| Dataset Size | Expected Runtime | Memory Usage |
|--------------|------------------|--------------|
| 1,000 intervals, 100 events | < 1 second | < 10 MB |
| 10,000 intervals, 1,000 events | < 5 seconds | < 50 MB |
| 100,000 intervals, 10,000 events | < 30 seconds | < 200 MB |
| 1,000,000 intervals, 100,000 events | < 5 minutes | < 2 GB |

### Optimization Strategies

1. **Use data.table for large datasets**
   - `inner_join()` → `merge(... , all.x=TRUE)`
   - `group_by() %>% mutate()` → `:=` assignment
   - `arrange()` → `setorder()`

2. **Vectorize operations**
   - Avoid loops over rows
   - Use `ifelse()` instead of `if/else` in mutate
   - Leverage R's vectorized date arithmetic

3. **Memory efficiency**
   - Drop unnecessary columns early
   - Use appropriate data types (integer vs double)
   - Remove temporary variables immediately after use
   - Consider chunking for extremely large datasets

4. **Parallel processing (optional)**
   - Split by id, process chunks in parallel
   - Use `future` or `parallel` packages
   - Combine results at end

### Benchmarking Code

```r
library(microbenchmark)

# Create test data
make_test_data <- function(n_people, intervals_per_person, event_rate) {
  intervals <- data.frame(
    id = rep(1:n_people, each = intervals_per_person),
    start = as.Date("2020-01-01") + rep(seq(0, 365*3, length.out = intervals_per_person), n_people),
    stop = as.Date("2020-01-01") + rep(seq(90, 365*3 + 90, length.out = intervals_per_person), n_people)
  )

  events <- data.frame(
    id = sample(1:n_people, n_people * event_rate),
    event_date = as.Date("2020-01-01") + sample(0:(365*3), n_people * event_rate, replace = TRUE)
  )

  list(intervals = intervals, events = events)
}

# Benchmark
test_data <- make_test_data(n_people = 1000, intervals_per_person = 10, event_rate = 0.5)

benchmark <- microbenchmark(
  tvevent(
    intervals_data = test_data$intervals,
    events_data = test_data$events,
    id = "id",
    date = "event_date"
  ),
  times = 10
)

print(benchmark)
```

---

## Key Differences from Stata Implementation

### Conceptual Differences

1. **Data Structure**
   - Stata: Modifies in-memory dataset (side effect)
   - R: Returns new data frame (functional)

2. **Missing Values**
   - Stata: `.` for missing
   - R: `NA` (with NA propagation rules)

3. **Frames**
   - Stata: Uses frames for temporary joins
   - R: Uses data frames throughout (cheaper in R)

### Implementation Differences

1. **Join Syntax**
   - Stata: `joinby`, `frlink`, `frget`
   - R: `inner_join()`, `left_join()` (dplyr)

2. **Expand Logic**
   - Stata: `expand 2 if condition, gen(copy)`
   - R: Filter + duplicate + bind_rows

3. **Labels**
   - Stata: Value labels are separate from data
   - R: Factors with levels/labels embedded

4. **Quiet Execution**
   - Stata: `quietly { }` block
   - R: `suppressMessages()` / return values

### API Design Differences

1. **Input/Output**
   - Stata: `using` file, modifies master in memory
   - R: Two data frames in, one data frame out

2. **Return Values**
   - Stata: `return scalar`, `return local`
   - R: List with `data`, `N`, `N_events`, etc.

3. **Options**
   - Stata: `option(value)` or `option` (flag)
   - R: Named parameters with defaults

---

## Validation Against Stata

### Test Data Generation

Create identical test data in both R and Stata for validation:

```r
# R code to generate CSV for Stata import
set.seed(12345)

intervals_test <- data.frame(
  id = rep(1:10, each = 4),
  start = as.Date("2020-01-01") + rep(c(0, 90, 180, 270), 10),
  stop = as.Date("2020-01-01") + rep(c(89, 179, 269, 364), 10),
  dose = round(rnorm(40, 100, 20), 2)
)

events_test <- data.frame(
  id = c(1, 2, 3, 5, 7, 8),
  event_date = as.Date(c("2020-03-15", "2020-06-20", "2020-11-10",
                         "2020-02-28", "2020-09-05", "2020-12-15")),
  death_date = as.Date(c(NA, "2020-08-01", NA,
                        "2020-07-15", NA, NA))
)

write.csv(intervals_test, "intervals_test.csv", row.names = FALSE)
write.csv(events_test, "events_test.csv", row.names = FALSE)
```

### Stata Validation Code

```stata
* Import test data
import delimited "intervals_test.csv", clear
gen start_d = date(start, "YMD")
gen stop_d = date(stop, "YMD")
drop start stop
rename (start_d stop_d) (start stop)
format start stop %tdCCYY-NN-DD
save intervals_test.dta, replace

import delimited "events_test.csv", clear
gen event_d = date(event_date, "YMD")
gen death_d = date(death_date, "YMD")
drop event_date death_date
rename (event_d death_d) (event_date death_date)
format event_date death_date %tdCCYY-NN-DD
save events_test.dta, replace

* Run tvevent
use intervals_test, clear
tvevent using events_test, id(id) date(event_date) compete(death_date) ///
  generate(outcome) continuous(dose) timegen(time) timeunit(days)

* Export for comparison
export delimited using "stata_result.csv", replace
```

### R Validation Code

```r
# Run R version
result_r <- tvevent(
  intervals_data = intervals_test,
  events_data = events_test,
  id = "id",
  date = "event_date",
  compete = "death_date",
  generate = "outcome",
  continuous = "dose",
  timegen = "time",
  timeunit = "days"
)

# Export for comparison
write.csv(result_r$data, "r_result.csv", row.names = FALSE)

# Compare
stata_result <- read.csv("stata_result.csv")
r_result <- result_r$data

# Check dimensions
stopifnot(nrow(stata_result) == nrow(r_result))

# Check key columns (allowing for small numeric differences)
compare_cols <- c("id", "start", "stop", "outcome", "dose", "time")

for (col in compare_cols) {
  if (is.numeric(stata_result[[col]])) {
    if (!all.equal(stata_result[[col]], r_result[[col]], tolerance = 1e-6)) {
      warning(sprintf("Mismatch in column %s", col))
    }
  } else {
    if (!all(stata_result[[col]] == r_result[[col]])) {
      warning(sprintf("Mismatch in column %s", col))
    }
  }
}

message("Validation complete!")
```

---

## Next Steps After Implementation

1. **Create R Package**
   - Use `devtools::create()` to scaffold package
   - Add roxygen2 documentation
   - Create vignette with workflow examples
   - Set up unit tests with testthat

2. **Integrate with tvexpose/tvmerge R Implementations**
   - Ensure compatible data structures
   - Create end-to-end workflow vignette
   - Test pipeline integration

3. **Performance Optimization**
   - Profile with `profvis` package
   - Implement data.table backend option
   - Add progress bars for large datasets (with `progress` package)

4. **Extended Features** (Beyond Stata Version)
   - Support for time-varying keepvars (merge different vars at different times)
   - Multiple primary outcomes (not just competing risks)
   - Built-in visualization functions (timeline plots)
   - Support for tibbles and data.table natively

5. **Documentation**
   - Complete function documentation
   - Workflow vignette
   - Comparison with Stata implementation
   - FAQ for common issues

6. **Validation**
   - Run comprehensive test suite
   - Validate against Stata on real datasets
   - Performance benchmarking
   - Edge case testing

---

## Summary

This plan provides a complete specification for reimplementing `tvevent` in R. The implementation should:

1. **Match Stata functionality exactly** (same algorithm, same results)
2. **Follow R best practices** (functional style, informative errors)
3. **Handle edge cases gracefully** (empty data, boundary events, zero durations)
4. **Perform efficiently** (vectorized operations, minimal copies)
5. **Integrate seamlessly** (with tidyverse, survival packages)
6. **Be well-tested** (comprehensive unit and integration tests)
7. **Be well-documented** (roxygen2, vignettes, examples)

The core algorithm is:
1. Resolve competing risks → earliest date wins
2. Identify split points → events strictly within intervals
3. Split intervals → create pre/post segments
4. Adjust continuous vars → proportional to duration ratio
5. Flag events → match on id + stop date
6. Apply type logic → censor after first (single) or keep all (recurring)
7. Generate time var → calculate duration in requested units

This detailed plan should enable Sonnet to implement a production-ready R version of `tvevent` that matches the Stata implementation while following R idioms and best practices.
