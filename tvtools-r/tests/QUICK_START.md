# Quick Start Guide - tvtools Test Data

## TL;DR - Get Started in 3 Steps

```bash
# 1. Generate test data
cd /home/user/Stata-Tools/tvtools-r/tests
Rscript generate_test_data.R

# 2. Validate it worked
Rscript validate_test_data.R

# 3. See examples
Rscript example_usage.R
```

## What You Get

- **17 comprehensive test datasets** (34 files: CSV + RDS)
- **100-person cohort** for standard testing
- **1,000-person cohort** for performance testing
- **3,954+ exposure periods** covering all edge cases
- **Complete documentation** and examples

## File Locations

```
/home/user/Stata-Tools/tvtools-r/tests/
├── generate_test_data.R    ← Run this to create data
├── validate_test_data.R    ← Run this to verify data
├── example_usage.R         ← Run this to see examples
├── TEST_DATA_SUMMARY.md    ← Overview documentation
└── test_data/
    ├── README.md           ← Detailed dataset documentation
    ├── cohort_basic.*      ← Primary cohort (100 persons)
    ├── exposure_simple.*   ← Clean exposures
    ├── exposure_gaps.*     ← Gaps for grace period testing
    ├── exposure_overlap.*  ← Overlapping exposures
    └── ... (13 more datasets)
```

## Use in R

```r
# Load a cohort
cohort <- readRDS("test_data/cohort_basic.rds")

# Load exposure data
exposure <- readRDS("test_data/exposure_simple.rds")

# Use with tvtools (if package installed)
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

## Test Scenarios Covered

| Scenario | Dataset | Description |
|----------|---------|-------------|
| Basic functionality | exposure_simple | Clean, non-overlapping periods |
| Grace periods | exposure_gaps, exposure_grace_test | Gaps to test merging |
| Overlaps | exposure_overlap | Test layer/split/priority |
| Multiple types | exposure_multi_types | 1-6 types per person |
| Point-in-time | exposure_point_time | Events without duration |
| Edge cases | exposure_edge_cases | Boundary conditions |
| Continuous | exposure_continuous | Numeric dose rates |
| Performance | cohort_large, exposure_large | 1000 persons, 3954+ periods |
| Mixed types | exposure_mixed | Categorical + continuous |
| Switching | exposure_switching | Type switching patterns |
| Duration | exposure_duration_test | Cumulative duration |
| Lag/washout | exposure_lag_washout | Temporal delays |

## Common Commands

```bash
# Regenerate all data
Rscript generate_test_data.R

# Check data integrity
Rscript validate_test_data.R

# See usage examples
Rscript example_usage.R

# List all datasets
ls test_data/*.rds

# Check file sizes
du -sh test_data/

# View dataset in R
R
> cohort <- readRDS("test_data/cohort_basic.rds")
> head(cohort)
> summary(cohort)
```

## Dataset Quick Reference

```r
# Cohort datasets
cohort_basic          # 100 persons, standard testing
cohort_large          # 1000 persons, performance testing
cohort_no_exposure    # 20 persons with no exposure

# Simple exposure datasets
exposure_simple       # Clean periods, no gaps/overlaps
exposure_large        # 3954+ periods, performance

# Complex scenarios
exposure_gaps         # Periods with gaps (10-90 days)
exposure_overlap      # Overlapping periods
exposure_multi_types  # 1-6 types per person (Drug_A - Drug_F)

# Specialized testing
exposure_point_time   # Events without duration
exposure_continuous   # Numeric dose rates (0-100 mg/day)
exposure_mixed        # Categorical + continuous variables
exposure_grace_test   # Specific gap sizes: 10, 30, 90 days
exposure_lag_washout  # Single long exposures
exposure_switching    # Type switching patterns
exposure_duration_test # Short/medium/long cumulative duration

# Edge cases
exposure_edge_cases       # Before entry, after exit, very short/long
exposure_missing_cohort   # IDs not in cohort (error handling)
```

## Need More Info?

- **Detailed documentation**: `test_data/README.md`
- **Complete overview**: `TEST_DATA_SUMMARY.md`
- **Working examples**: `example_usage.R`
- **Unit tests**: `testthat/test-*.R`

## Troubleshooting

**Data files missing?**
```bash
Rscript generate_test_data.R
```

**Data seems corrupt?**
```bash
Rscript validate_test_data.R
```

**Not sure how to use?**
```bash
Rscript example_usage.R
cat test_data/README.md
```

**Package not working?**
```r
# Install tvtools first
install.packages("devtools")
devtools::install_local("/home/user/Stata-Tools/tvtools-r")
```

---

**Questions?** Check the documentation files or run the example scripts!
