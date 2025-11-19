# tvtools Test Data Documentation

This directory contains comprehensive synthetic test datasets for testing the tvtools R package functions (`tvexpose` and `tvmerge`).

## Overview

All datasets are available in both CSV and RDS formats. The datasets are organized into categories covering different testing scenarios.

**Generated:** 2025-11-19
**Seed:** 42 (for reproducibility)

## Dataset Categories

### 1. Basic Cohort Data

**File:** `cohort_basic.csv` / `cohort_basic.rds`
**Rows:** 100 persons
**Columns:** id, study_entry, study_exit, age, sex, bmi, smoker, chronic_disease, region, baseline_score

Master cohort dataset with 100 persons and baseline characteristics. This is the primary cohort for most test scenarios.

### 2. Simple Exposure Data

**File:** `exposure_simple.csv` / `exposure_simple.rds`
**Rows:** ~118 exposure periods
**Columns:** id, exp_start, exp_stop, exposure, dose_mg

Clean, non-overlapping exposure periods for 60 persons from the basic cohort. Ideal for testing basic `tvexpose` functionality.

**Use case:** Basic time-varying exposure creation, no complications

### 3. Exposure Data with Gaps

**File:** `exposure_gaps.csv` / `exposure_gaps.rds`
**Rows:** ~177 exposure periods
**Columns:** id, exp_start, exp_stop, exposure, exposure_type

Exposure periods with intentional gaps (10-90 days) between periods for the same person.

**Use case:** Testing grace period (`grace` parameter) functionality

### 4. Overlapping Exposures

**File:** `exposure_overlap.csv` / `exposure_overlap.rds`
**Rows:** ~122 exposure periods
**Columns:** id, exp_start, exp_stop, exposure, priority

Exposure periods that overlap within the same person.

**Use case:** Testing overlap strategies (`layer`, `split`, `priority` parameters)

### 5. Multiple Exposure Types

**File:** `exposure_multi_types.csv` / `exposure_multi_types.rds`
**Rows:** ~480 exposure periods
**Columns:** id, exp_start, exp_stop, exposure, exposure_name

1-6 different exposure types per person (Drug_A through Drug_F).

**Use case:** Testing `bytype` parameter to create separate variables for each exposure type

### 6. Point-in-Time Exposures

**File:** `exposure_point_time.csv` / `exposure_point_time.rds`
**Rows:** ~141 events
**Columns:** id, event_date, event_type, event_code

Point-in-time events without stop dates (vaccinations, surgeries, diagnoses, procedures).

**Use case:** Testing `pointtime` parameter

### 7. Edge Cases

#### Main Edge Cases
**File:** `exposure_edge_cases.csv` / `exposure_edge_cases.rds`
**Rows:** ~40 exposure periods
**Columns:** id, exp_start, exp_stop, exposure, edge_case_type

Edge case types:
- `before_entry`: Exposure starts before study_entry
- `after_exit`: Exposure ends after study_exit
- `very_short_1day`: Extremely short exposures (1 day)
- `very_long_10years`: Very long exposures (10 years)
- `entire_followup`: Exposure spanning entire follow-up period
- `multiple_1day`: Multiple 1-day exposures
- `normal`: Normal exposure for comparison

#### Missing Cohort IDs
**File:** `exposure_missing_cohort.csv` / `exposure_missing_cohort.rds`
**Rows:** 10 exposure periods
**Columns:** id, exp_start, exp_stop, exposure

Exposure data for person IDs that do not exist in the cohort (IDs 101-105). Tests error handling.

#### No Exposure Cohort
**File:** `cohort_no_exposure.csv` / `cohort_no_exposure.rds`
**Rows:** 20 persons
**Columns:** Same as cohort_basic

Subset of cohort with no corresponding exposure data. Tests handling of unexposed persons.

### 8. Large Datasets (Performance Testing)

**Files:**
- `cohort_large.csv` / `cohort_large.rds` (1000 persons)
- `exposure_large.csv` / `exposure_large.rds` (~3954 exposure periods)

**Use case:** Performance testing and scalability assessment

### 9. Continuous Exposures

**File:** `exposure_continuous.csv` / `exposure_continuous.rds`
**Rows:** ~207 exposure periods
**Columns:** id, exp_start, exp_stop, dose_rate, drug_name

Continuous numeric exposure values representing dosage rates (mg/day).

**Use case:** Testing `continuous` parameter in `tvmerge`

### 10. Mixed Categorical and Continuous

**File:** `exposure_mixed.csv` / `exposure_mixed.rds`
**Rows:** ~245 exposure periods
**Columns:** id, exp_start, exp_stop, exposure_type, exposure_category, daily_dose, intensity, severity

Combination of categorical and continuous exposure variables.

**Use case:** Testing mixed exposure types in `tvmerge`

### 11. Specialized Datasets

#### Grace Period Testing
**File:** `exposure_grace_test.csv` / `exposure_grace_test.rds`
**Rows:** ~60 exposure periods
**Columns:** id, exp_start, exp_stop, exposure, gap_before

Specific gap sizes (10, 30, 90 days) for systematic grace period testing.

#### Lag and Washout Testing
**File:** `exposure_lag_washout.csv` / `exposure_lag_washout.rds`
**Rows:** ~25 exposure periods
**Columns:** id, exp_start, exp_stop, exposure, expected_lag_days, expected_washout_days

Single long exposure periods for testing `lag` and `washout` parameters.

#### Switching Testing
**File:** `exposure_switching.csv` / `exposure_switching.rds`
**Rows:** ~127 exposure periods
**Columns:** id, exp_start, exp_stop, exposure, switch_number

Patterns of switching between different exposure types.

**Use case:** Testing `switching` and `switchingdetail` parameters

#### Duration Testing
**File:** `exposure_duration_test.csv` / `exposure_duration_test.rds`
**Rows:** ~119 exposure periods
**Columns:** id, exp_start, exp_stop, exposure, duration_category, cumulative_days

Varying cumulative exposure durations (short <6mo, medium 6-18mo, long >18mo).

**Use case:** Testing `duration` parameter

## Usage Examples

### Load Test Data

```r
# Load CSV files
cohort <- read.csv("test_data/cohort_basic.csv", stringsAsFactors = FALSE)
cohort$study_entry <- as.Date(cohort$study_entry)
cohort$study_exit <- as.Date(cohort$study_exit)

exposure <- read.csv("test_data/exposure_simple.csv", stringsAsFactors = FALSE)
exposure$exp_start <- as.Date(exposure$exp_start)
exposure$exp_stop <- as.Date(exposure$exp_stop)

# Or load RDS files (dates already in Date format)
cohort <- readRDS("test_data/cohort_basic.rds")
exposure <- readRDS("test_data/exposure_simple.rds")
```

### Basic tvexpose Test

```r
library(tvtools)

# Load data
cohort <- readRDS("test_data/cohort_basic.rds")
exposure <- readRDS("test_data/exposure_simple.rds")

# Create time-varying exposure
result <- tvexpose(
  master = cohort,
  exposure_data = exposure,
  id = "id",
  start = "exp_start",
  stop = "exp_stop",
  exposure = "exposure",
  reference = 0,
  entry = "study_entry",
  exit = "study_exit"
)

head(result)
```

### Testing Grace Periods

```r
# Load gap data
exposure_gaps <- readRDS("test_data/exposure_grace_test.rds")

# Test with different grace periods
result_no_grace <- tvexpose(
  master = cohort,
  exposure_data = exposure_gaps,
  id = "id",
  start = "exp_start",
  stop = "exp_stop",
  exposure = "exposure",
  reference = 0,
  entry = "study_entry",
  exit = "study_exit",
  grace = 0
)

result_grace_30 <- tvexpose(
  master = cohort,
  exposure_data = exposure_gaps,
  id = "id",
  start = "exp_start",
  stop = "exp_stop",
  exposure = "exposure",
  reference = 0,
  entry = "study_entry",
  exit = "study_exit",
  grace = 30  # Merge gaps <= 30 days
)

# Compare number of periods
table(table(result_no_grace$id))
table(table(result_grace_30$id))
```

### Testing Overlaps

```r
# Load overlapping exposure data
exposure_overlap <- readRDS("test_data/exposure_overlap.rds")

# Test layer strategy
result_layer <- tvexpose(
  master = cohort,
  exposure_data = exposure_overlap,
  id = "id",
  start = "exp_start",
  stop = "exp_stop",
  exposure = "exposure",
  reference = 0,
  entry = "study_entry",
  exit = "study_exit",
  layer = TRUE
)

# Test split strategy
result_split <- tvexpose(
  master = cohort,
  exposure_data = exposure_overlap,
  id = "id",
  start = "exp_start",
  stop = "exp_stop",
  exposure = "exposure",
  reference = 0,
  entry = "study_entry",
  exit = "study_exit",
  split = TRUE
)
```

### Testing tvmerge with Continuous Exposures

```r
# Load continuous exposure data
exposure_cont <- readRDS("test_data/exposure_continuous.rds")

# Create two time-varying datasets
tv1 <- tvexpose(
  master = cohort,
  exposure_data = exposure_simple,
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
  exposure_data = exposure_cont,
  id = "id",
  start = "exp_start",
  stop = "exp_stop",
  exposure = "dose_rate",
  reference = 0,
  entry = "study_entry",
  exit = "study_exit"
)

# Merge them
merged <- tvmerge(
  dataset1 = tv1,
  dataset2 = tv2,
  id = "id",
  start = c("start", "start"),
  stop = c("stop", "stop"),
  exposure = c("tv_exposure", "tv_exposure"),
  continuous = c(NA, "tv_exposure")  # Second is continuous
)
```

## Regenerating Test Data

To regenerate all test datasets:

```bash
Rscript /home/user/Stata-Tools/tvtools-r/tests/generate_test_data.R
```

This will overwrite existing files in the `test_data/` directory.

## Notes

- All dates are in ISO 8601 format (YYYY-MM-DD)
- The random seed is set to 42 for reproducibility
- Study period is generally 2010-01-01 to 2020-12-31
- Person IDs in cohort_basic range from 1-100
- Person IDs in cohort_large range from 1-1000
- Missing cohort IDs are 101-105

## File Size Summary

- Total CSV files: 17 (~140 KB)
- Total RDS files: 17 (~26 KB)
- Total files: 34

RDS files are more compact and preserve R data types (especially dates).
