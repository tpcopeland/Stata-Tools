# tvmerge R Implementation Summary

## Overview

The `tvmerge.R` file contains a complete R implementation of the Stata `tvmerge` command based on the detailed specification in `tvmerge_plan.md`.

## Implementation Statistics

- **Total Lines**: 1,140
- **Functions Implemented**: 19
- **Roxygen Documentation Lines**: 133
- **Dependencies**: dplyr, tibble, data.table, haven, rlang

## Function Inventory

### Main Function
1. **tvmerge()** - Main entry point with full parameter validation and workflow orchestration

### Input Validation (5 functions)
2. **validate_datasets()** - Validates and loads datasets from files or data.frames
3. **validate_variables()** - Ensures all required variables exist in each dataset
4. **validate_naming_options()** - Validates generate/prefix parameters and output variable names
5. **validate_continuous()** - Validates continuous exposure specifications (positions or names)
6. **validate_batch()** - Validates batch percentage parameter (1-100)

### Core Algorithm (4 functions)
7. **prepare_first_dataset()** - Prepares first dataset with renaming, date flooring/ceiling, and invalid period removal
8. **validate_id_matching()** - Checks ID consistency across datasets with detailed error messages
9. **cartesian_merge_batch()** - Performs batched Cartesian product with interval intersection and continuous interpolation
10. **merge_all_datasets()** - Main merge loop that processes all datasets sequentially

### Diagnostic Functions (3 functions)
11. **validate_coverage()** - Detects gaps >1 day in coverage
12. **validate_overlap()** - Detects unexpected overlapping periods with identical exposures
13. **compute_diagnostics()** - Calculates n_persons, avg_periods, max_periods

### Display Functions (5 functions)
14. **display_diagnostics()** - Displays coverage diagnostics table
15. **display_gap_validation()** - Displays gap validation results
16. **display_overlap_validation()** - Displays overlap validation results
17. **display_summary_stats()** - Displays summary statistics for dates
18. **display_final_summary()** - Displays final merge summary

### Utility Functions (1 function)
19. **require_packages()** - Checks and loads required packages with informative errors

## Key Features Implemented

### Algorithm
- ✓ Cartesian product merge by ID using data.table for performance
- ✓ Interval intersection calculation (new_start = max(start_A, start_B), new_stop = min(stop_A, stop_B))
- ✓ Batch processing (configurable 1-100% of IDs per batch)
- ✓ Continuous exposure interpolation based on overlap proportion
- ✓ Date flooring (start) and ceiling (stop) for fractional dates
- ✓ Duplicate removal based on ID + dates + exposures
- ✓ Proper handling of point-in-time observations (start == stop)

### Validation
- ✓ Minimum 2 datasets required
- ✓ File existence and Stata format validation
- ✓ Variable existence checks with informative errors
- ✓ Duplicate exposure name detection
- ✓ ID matching validation with force mode option
- ✓ Invalid period detection and removal (start > stop or missing dates)
- ✓ Keep variable validation

### Naming Options
- ✓ `generate` parameter for custom exposure names
- ✓ `prefix` parameter for prefixing exposure names
- ✓ Custom `startname` and `stopname` for output intervals
- ✓ Automatic suffixing of keep variables (_ds1, _ds2, etc.)
- ✓ Mutual exclusivity check (generate vs prefix)

### Diagnostics
- ✓ Coverage diagnostics (n_persons, avg_periods, max_periods)
- ✓ Gap detection (>1 day gaps in coverage)
- ✓ Overlap detection (unexpected overlaps with identical exposures)
- ✓ Summary statistics for start/stop dates
- ✓ Invalid period counts per dataset
- ✓ Duplicate count reporting

### Output
- ✓ Returns list with data, diagnostics, and Stata-style returns
- ✓ Optional save to .dta file using haven::write_dta
- ✓ Comprehensive display functions for console output

### Error Handling
- ✓ Clear error messages with context (dataset number, variable names)
- ✓ Graceful handling of empty batches
- ✓ Warnings for invalid periods and duplicates
- ✓ Force mode for ID mismatches with detailed warnings

## Algorithm Details

### Core Merge Logic (for each dataset k = 2 to n)

1. **Preparation**
   - Rename ID, start, stop, exposure variables
   - Floor start dates, ceiling stop dates
   - Drop invalid periods (start > stop or missing)
   - Add keep variables with _dsk suffix

2. **ID Validation**
   - Check ID overlap between merged result and dataset k
   - Error (force=FALSE) or warn (force=TRUE) on mismatch

3. **Batch Processing**
   - Split unique IDs into batches (default 20%)
   - For each batch:
     - Filter both datasets to batch IDs
     - Convert to data.table with keyed join
     - Perform Cartesian product (all combinations within ID)
     - Calculate interval intersections
     - Filter to valid overlaps (new_start <= new_stop)
     - Interpolate continuous exposures if applicable
   - Combine batch results

4. **Cleanup**
   - Remove exact duplicates
   - Sort by ID, start, stop

### Continuous Exposure Interpolation

```r
overlap_duration = new_stop - new_start + 1
original_duration = stop_k - start_k + 1
proportion = overlap_duration / original_duration
proportion = min(proportion, 1)  # Cap at 1.0 for floating point safety
interpolated_value = original_value * proportion
```

### Interval Intersection

```r
new_start = max(start_merged, start_k)
new_stop = min(stop_merged, stop_k)
keep_if = new_start <= new_stop  # Intervals overlap
```

## Return Value Structure

```r
list(
  data = <data.frame>,              # Merged dataset
  diagnostics = list(
    n_persons = <int>,
    avg_periods = <numeric>,
    max_periods = <int>,
    invalid_counts = <vector>,
    n_duplicates = <int>,
    coverage_validation = <list>,   # If validatecoverage=TRUE
    overlap_validation = <list>     # If validateoverlap=TRUE
  ),
  returns = list(                   # Stata-style returns
    N = <int>,
    N_persons = <int>,
    mean_periods = <numeric>,
    max_periods = <int>,
    N_datasets = <int>,
    exposure_vars = <vector>,
    continuous_vars = <vector>,
    categorical_vars = <vector>,
    n_continuous = <int>,
    n_categorical = <int>,
    startname = <string>,
    stopname = <string>,
    prefix = <string>,
    generated_names = <vector>,
    output_file = <string>
  )
)
```

## Example Usage

### Basic Merge

```r
result <- tvmerge(
  datasets = c("tv_hrt.dta", "tv_dmt.dta"),
  id = "id",
  start = c("rx_start", "dmt_start"),
  stop = c("rx_stop", "dmt_stop"),
  exposure = c("tv_exposure", "tv_exposure"),
  generate = c("hrt", "dmt_type")
)

merged_data <- result$data
```

### With Continuous Exposure

```r
result <- tvmerge(
  datasets = c("tv_hrt.dta", "tv_dosage.dta"),
  id = "id",
  start = c("rx_start", "dose_start"),
  stop = c("rx_stop", "dose_stop"),
  exposure = c("hrt_type", "dosage_rate"),
  continuous = c(2),  # Position 2 (dosage_rate) is continuous
  generate = c("hrt", "dose")
)
```

### With Full Validation

```r
result <- tvmerge(
  datasets = c("tv_hrt.dta", "tv_dmt.dta"),
  id = "id",
  start = c("rx_start", "dmt_start"),
  stop = c("rx_stop", "dmt_stop"),
  exposure = c("tv_exposure", "tv_exposure"),
  generate = c("hrt", "dmt_type"),
  check = TRUE,
  validatecoverage = TRUE,
  validateoverlap = TRUE,
  summarize = TRUE,
  saveas = "merged_exposures.dta"
)
```

## Performance Characteristics

### Memory Efficiency
- Batch processing prevents loading entire Cartesian product into memory
- Default 20% batch size balances memory and performance
- Adjustable from 1% (memory-constrained) to 100% (RAM-abundant systems)

### Computational Efficiency
- data.table used for Cartesian joins (much faster than base R)
- Vectorized operations throughout (dplyr/data.table)
- Early filtering (invalid periods dropped before merge)
- Pre-computation of continuous flags

### Expected Performance

| Dataset Size | IDs | Periods/ID | Batch % | Expected Time |
|-------------|-----|-----------|---------|---------------|
| Small | 100 | 10 | 20 | < 1 second |
| Medium | 1,000 | 20 | 20 | 5-10 seconds |
| Large | 10,000 | 30 | 20 | 1-2 minutes |
| Very Large | 50,000 | 50 | 10 | 5-15 minutes |

## Testing Recommendations

### High Priority Tests
1. Basic 2-dataset merge with perfect overlap
2. Basic 2-dataset merge with partial overlap
3. Basic 2-dataset merge with no overlap
4. Continuous exposure interpolation accuracy
5. ID mismatch validation (force=FALSE and force=TRUE)

### Medium Priority Tests
1. 3-dataset merge with various overlap patterns
2. Batch processing consistency (compare batch=10 vs batch=50 vs batch=100)
3. Keep variables with proper suffixing
4. Custom naming (generate, prefix)

### Edge Cases
1. Empty datasets after validation
2. Single observation per person
3. Point-in-time observations (start == stop)
4. Missing exposure values (should be retained)
5. Missing dates (should be dropped with warning)
6. Large datasets (10,000+ IDs)

## Dependencies

### Required Packages
- **dplyr**: Data manipulation (mutate, filter, select, arrange)
- **tibble**: Modern data.frame structure
- **data.table**: Fast Cartesian joins with allow.cartesian=TRUE
- **haven**: Read/write Stata .dta files
- **rlang**: Tidy evaluation (sym, :=)

### Installation
```r
install.packages(c("dplyr", "tibble", "data.table", "haven", "rlang"))
```

## Key Design Decisions

1. **data.table for Cartesian joins**: Significantly faster than base R merge with allow.cartesian
2. **Batch processing by IDs not observations**: Ensures complete processing of each person
3. **Floor/ceiling dates**: Handles fractional Stata date values without losing coverage
4. **Strict ID matching by default**: Prevents silent data loss, overridden with force=TRUE
5. **Duplicate removal based on all exposures**: Prevents spurious duplicates in Cartesian product
6. **Point-in-time observations valid**: Important for lab measurements and single-day events

## Differences from Stata Implementation

1. **Return structure**: Returns a list instead of modifying global r() state
2. **Progress display**: Uses message() instead of Stata's display
3. **Date handling**: Automatic (no dateformat parameter needed)
4. **Package loading**: Uses require_packages() helper instead of ssc install

## File Location

`/home/user/Stata-Tools/Reimplementations/R/tvmerge.R`

## Documentation

Full roxygen2 documentation included. Generate HTML documentation with:

```r
library(roxygen2)
roxygen2::roxygenize("path/to/package")
```

## Status

✅ **Implementation Complete** - All features from tvmerge_plan.md implemented with full validation, diagnostics, and error handling.
