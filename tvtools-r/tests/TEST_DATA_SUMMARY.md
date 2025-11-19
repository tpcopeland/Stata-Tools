# tvtools Test Data - Complete Summary

## Overview

This directory contains comprehensive synthetic test datasets for the tvtools R package, along with scripts for generating, validating, and demonstrating usage of the test data.

**Location:** `/home/user/Stata-Tools/tvtools-r/tests/`

## Directory Structure

```
tvtools-r/tests/
├── generate_test_data.R      # Main script to generate all test datasets
├── validate_test_data.R       # Validation script to verify data integrity
├── example_usage.R            # Example demonstrations of data usage
├── test_data/                 # Directory containing all test datasets
│   ├── README.md              # Detailed documentation of each dataset
│   ├── *.csv                  # 17 CSV files
│   └── *.rds                  # 17 RDS files (R data format)
└── testthat/                  # Unit tests for tvtools functions
    ├── test-tvexpose.R
    └── test-tvmerge.R
```

## Quick Start

### 1. Generate Test Data

```bash
cd /home/user/Stata-Tools/tvtools-r/tests
Rscript generate_test_data.R
```

This creates 17 datasets (34 files total: CSV + RDS) in the `test_data/` directory.

### 2. Validate Test Data

```bash
Rscript validate_test_data.R
```

Verifies that all datasets are properly formatted and loadable.

### 3. Explore Example Usage

```bash
Rscript example_usage.R
```

Demonstrates how to load and use the test datasets.

## Test Datasets Overview

### Core Datasets (10 categories)

| Category | Files | Description | Use Case |
|----------|-------|-------------|----------|
| **1. Basic Cohort** | cohort_basic | 100 persons with baseline characteristics | Primary test cohort |
| **2. Simple Exposures** | exposure_simple | Clean, non-overlapping periods | Basic functionality testing |
| **3. Gaps** | exposure_gaps | Intentional gaps (10-90 days) | Grace period testing |
| **4. Overlaps** | exposure_overlap | Overlapping exposure periods | Layer/split/priority strategies |
| **5. Multiple Types** | exposure_multi_types | 1-6 exposure types per person | Bytype parameter testing |
| **6. Point-in-Time** | exposure_point_time | Events without duration | Pointtime parameter testing |
| **7. Edge Cases** | exposure_edge_cases | Boundary conditions | Robustness testing |
| **8. Large Data** | cohort_large, exposure_large | 1000 persons, 3954+ periods | Performance testing |
| **9. Continuous** | exposure_continuous | Numeric dose rates | Continuous exposures |
| **10. Mixed** | exposure_mixed | Categorical + continuous | Complex scenarios |

### Specialized Datasets (4 additional)

| Dataset | Purpose | Rows | Key Features |
|---------|---------|------|--------------|
| exposure_grace_test | Grace period testing | ~60 | Specific gap sizes: 10, 30, 90 days |
| exposure_lag_washout | Lag/washout testing | ~25 | Long single exposures |
| exposure_switching | Switching patterns | ~127 | Type switching sequences |
| exposure_duration_test | Duration categories | ~119 | Short/medium/long durations |

### Edge Case Datasets (3 special)

| Dataset | Purpose | Rows | Description |
|---------|---------|------|-------------|
| exposure_edge_cases | Various edge cases | ~40 | Before entry, after exit, very short/long |
| exposure_missing_cohort | Error handling | 10 | IDs not in cohort (101-105) |
| cohort_no_exposure | Unexposed handling | 20 | Cohort subset with no exposures |

## Dataset Statistics

```
Total Datasets:    17
Total Files:       34 (17 CSV + 17 RDS)
Total Records:     ~6,900 rows across all datasets
File Sizes:        ~170 KB total

Largest Dataset:   exposure_large (3,954 periods)
Primary Cohort:    cohort_basic (100 persons)
Large Cohort:      cohort_large (1,000 persons)
```

## Key Features by Category

### 1. Basic Cohort Data (`cohort_basic`)
- **100 persons** with realistic characteristics
- Variables: id, study_entry, study_exit, age, sex, bmi, smoker, chronic_disease, region, baseline_score
- Study period: 2010-2020
- Age range: 10-90 years
- Sex distribution: 40% Male, 60% Female

### 2. Simple Exposure Data (`exposure_simple`)
- **118 exposure periods** for 60 persons
- Clean, non-overlapping periods
- 1-3 periods per person
- Duration: 30-365 days
- Exposure types: 1-2
- Includes dose_mg variable

### 3. Complex Gaps (`exposure_gaps`)
- **177 periods** for 50 persons
- Intentional gaps: 10-90 days
- 2-5 periods per person
- Tests grace period merging
- Multiple exposure types (1-3)

### 4. Overlapping Exposures (`exposure_overlap`)
- **122 periods** for 40 persons
- 100% of persons have overlaps
- Priority values: 1-5
- Tests layer/split strategies

### 5. Multiple Exposure Types (`exposure_multi_types`)
- **480 periods** for 70 persons
- 1-6 different types per person
- Drug names: Drug_A through Drug_F
- Tests bytype parameter

### 6. Point-in-Time (`exposure_point_time`)
- **141 events** for 50 persons
- No stop dates (events only)
- Types: Vaccination, Surgery, Diagnosis, Procedure
- 1-5 events per person

### 7. Edge Cases (`exposure_edge_cases`)
- **40 periods** for 30 persons
- Edge case types:
  - `before_entry`: Start before study_entry (6 cases)
  - `after_exit`: End after study_exit (4 cases)
  - `very_short_1day`: 1-day exposures (4 cases)
  - `very_long_10years`: 10-year exposures (5 cases)
  - `entire_followup`: Spans entire period (4 cases)
  - `multiple_1day`: Multiple 1-day events (15 cases)
  - `normal`: Comparison baseline (2 cases)

### 8. Large Datasets (Performance)
- **cohort_large**: 1,000 persons
- **exposure_large**: 3,954 periods
- 0-10 periods per person
- Duration: 30-180 days
- 5 exposure types

### 9. Continuous Exposures (`exposure_continuous`)
- **207 periods** for 60 persons
- Numeric dose_rate: 0-100 mg/day
- Drug names: DrugA, DrugB, DrugC
- Tests continuous parameter in tvmerge

### 10. Mixed Categorical/Continuous (`exposure_mixed`)
- **245 periods** for 60 persons
- Categorical: exposure_type, exposure_category, severity
- Continuous: daily_dose (5-150), intensity (0-1)
- Tests complex variable types

## Usage Examples

### Load Data in R

```r
# Load RDS (recommended - preserves dates)
cohort <- readRDS("test_data/cohort_basic.rds")
exposure <- readRDS("test_data/exposure_simple.rds")

# Load CSV (need to convert dates)
cohort <- read.csv("test_data/cohort_basic.csv", stringsAsFactors = FALSE)
cohort$study_entry <- as.Date(cohort$study_entry)
cohort$study_exit <- as.Date(cohort$study_exit)
```

### Test tvexpose Function

```r
library(tvtools)

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
```

### Test Grace Periods

```r
exposure_gaps <- readRDS("test_data/exposure_grace_test.rds")

# No grace period
result_no_grace <- tvexpose(..., grace = 0)

# 30-day grace period
result_grace_30 <- tvexpose(..., grace = 30)

# Compare results
nrow(result_no_grace)  # More rows (gaps not merged)
nrow(result_grace_30)  # Fewer rows (gaps ≤30 days merged)
```

### Test Overlapping Strategies

```r
exposure_overlap <- readRDS("test_data/exposure_overlap.rds")

# Layer strategy (default)
result_layer <- tvexpose(..., layer = TRUE)

# Split strategy
result_split <- tvexpose(..., split = TRUE)

# Priority strategy
result_priority <- tvexpose(..., priority = c(3, 2, 1))
```

### Test tvmerge Function

```r
# Create two time-varying datasets
tv1 <- tvexpose(master = cohort, exposure_data = exposure1, ...)
tv2 <- tvexpose(master = cohort, exposure_data = exposure2, ...)

# Merge them
merged <- tvmerge(
  dataset1 = tv1,
  dataset2 = tv2,
  id = "id",
  start = c("start", "start"),
  stop = c("stop", "stop"),
  exposure = c("tv_exposure", "tv_exposure")
)
```

## Testing Scenarios Covered

### Basic Functionality
- ✓ Simple time-varying exposure creation
- ✓ Multiple exposure types per person
- ✓ Persons with no exposure
- ✓ Point-in-time events

### Grace Period Handling
- ✓ Gaps of 10, 30, 90 days
- ✓ Grace period merging
- ✓ Variable grace periods by type

### Overlap Strategies
- ✓ Layer (later takes precedence)
- ✓ Split (all boundaries)
- ✓ Priority (by exposure type)
- ✓ Combine (simultaneous exposure)

### Edge Cases
- ✓ Exposure before study entry
- ✓ Exposure after study exit
- ✓ Very short exposures (1 day)
- ✓ Very long exposures (10 years)
- ✓ Zero-length periods
- ✓ Missing persons in cohort
- ✓ Extra persons in cohort

### Advanced Features
- ✓ Bytype (separate variables per type)
- ✓ Ever-treated patterns
- ✓ Current/former status
- ✓ Duration categories
- ✓ Recency categories
- ✓ Switching patterns
- ✓ Lag and washout periods

### Data Types
- ✓ Categorical exposures
- ✓ Continuous exposures (dose rates)
- ✓ Mixed categorical and continuous
- ✓ Multiple simultaneous exposures

### Performance
- ✓ 100-person cohort (standard tests)
- ✓ 1,000-person cohort (scalability)
- ✓ 3,954+ exposure periods
- ✓ Complex overlap scenarios

## File Formats

### RDS Format (Recommended)
- Native R format
- Preserves data types (dates, factors, etc.)
- Smaller file size
- Faster to load

### CSV Format
- Universal compatibility
- Human-readable
- Larger file size
- Requires type conversion

## Reproducibility

All datasets are generated with **seed = 42** for reproducibility.

To regenerate identical data:
```r
set.seed(42)
# ... generation code ...
```

## Data Quality Checks

The `validate_test_data.R` script performs:
- ✓ File existence checks
- ✓ Dimension verification
- ✓ Required column presence
- ✓ Date type validation
- ✓ Missing value detection
- ✓ CSV/RDS consistency

## Additional Documentation

- **Detailed dataset descriptions**: `test_data/README.md`
- **Usage examples**: `example_usage.R`
- **Unit tests**: `testthat/test-*.R`
- **Generation script**: `generate_test_data.R`

## Maintenance

### Regenerate All Data
```bash
Rscript generate_test_data.R
```

### Validate After Changes
```bash
Rscript validate_test_data.R
```

### Run Examples
```bash
Rscript example_usage.R
```

## Notes

- All dates are in ISO 8601 format (YYYY-MM-DD)
- Study period: Generally 2010-01-01 to 2020-12-31
- Person IDs: 1-100 (basic), 1-1000 (large), 101-105 (missing)
- Seed: 42 (for reproducibility)
- No personally identifiable information (all synthetic)

## Support

For questions or issues:
1. Check `test_data/README.md` for dataset details
2. Run `example_usage.R` for working examples
3. Review unit tests in `testthat/` directory
4. Regenerate data if corrupted: `Rscript generate_test_data.R`

---

**Generated:** 2025-11-19
**Version:** 1.0
**Total Datasets:** 17
**Total Test Scenarios:** 30+
