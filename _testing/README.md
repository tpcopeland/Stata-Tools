# tvtools Testing Suite

This folder contains comprehensive test scripts for comparing the Stata and R implementations of tvtools (tvexpose and tvmerge functions).

## Overview

The test scripts use the same synthetic data generated from `_synthetic data generation/generate_comprehensive_synthetic_data.do` to ensure that both implementations work correctly and produce equivalent results.

## Files

### Test Scripts

- **test_tvtools_stata.do** - Stata test script that:
  - Generates synthetic data
  - Tests `tvexpose` with various exposure definitions
  - Tests `tvmerge` to combine multiple exposures
  - Exports summary statistics for comparison
  - Performs validation checks

- **test_tvtools_r.R** - R test script that:
  - Loads Stata .dta files using the `haven` package
  - Tests `tvexpose` with the same parameters as Stata
  - Tests `tvmerge` with the same data
  - Exports summary statistics for comparison
  - Compares results with Stata implementation

### Generated Outputs

After running both test scripts, the following files will be created:

**Stata outputs:**
- `tv_hrt_stata.dta` - Time-varying HRT exposure
- `tv_dmt_stata.dta` - Current/former DMT exposure
- `tv_evertreated_stata.dta` - Ever-treated HRT
- `tv_duration_stata.dta` - HRT duration categories
- `merged_stata.dta` - Merged HRT × DMT exposures
- `stata_summary.csv` - Summary statistics
- `stata_test_log.txt` - Full test log

**R outputs:**
- `tv_hrt_r.rds` - Time-varying HRT exposure
- `tv_dmt_r.rds` - Current/former DMT exposure
- `tv_evertreated_r.rds` - Ever-treated HRT
- `tv_duration_r.rds` - HRT duration categories
- `merged_r.rds` - Merged HRT × DMT exposures
- `r_summary.csv` - Summary statistics

## Running the Tests

### Prerequisites

**Stata:**
- Stata 16+ recommended
- tvtools ado files must be installed or in the adopath

**R:**
- R 4.0+
- Required packages: `haven`, `dplyr`, `readr`, `tidyr`, `zoo`
- Install with: `install.packages(c("haven", "dplyr", "readr", "tidyr", "zoo"))`

### Running Stata Tests

From the Stata-Tools root directory:

```stata
cd "/path/to/Stata-Tools"
do "_testing/test_tvtools_stata.do"
```

### Running R Tests

From the Stata-Tools root directory:

```bash
cd /path/to/Stata-Tools
Rscript _testing/test_tvtools_r.R
```

Or from within R:

```r
setwd("/path/to/Stata-Tools")
source("_testing/test_tvtools_r.R")
```

## Test Coverage

Both test scripts perform identical tests to ensure equivalence:

### 1. Basic Time-Varying Exposure
Tests `tvexpose` with categorical HRT exposure to create time-varying periods.

### 2. Current/Former Exposure
Tests the `currentformer` option to distinguish between currently exposed, formerly exposed, and never exposed states.

### 3. Ever-Treated
Tests the `evertreated` option to create a binary indicator that switches permanently at first exposure (immortal time bias correction).

### 4. Duration Categories
Tests cumulative exposure duration with category boundaries at 1 and 5 years.

### 5. Merge Multiple Exposures
Tests `tvmerge` to create a combined dataset with both HRT and DMT exposures, creating all possible exposure combinations (Cartesian product).

### 6. Summary Statistics
Generates cross-tabulations and summary statistics for each exposure combination.

### 7. Validation Checks
- No gaps in coverage (all person-time accounted for)
- No overlapping periods
- Valid dates (start ≤ stop)
- Coverage matches original cohort

### 8. Cross-Implementation Comparison
Compares summary statistics between Stata and R implementations to verify equivalence.

## Expected Results

Both implementations should produce:
- Similar number of time-varying periods
- Similar distribution of exposure combinations
- No gaps or overlaps in person-time
- Differences within 5% tolerance due to minor implementation details

## Interpreting Results

### Success Indicators
- All validation checks pass (✓)
- Cross-tabulations show similar patterns
- Summary statistics match within tolerance
- No error messages

### Warning Signs
- Large differences (>5%) in period counts
- Gaps or overlaps detected
- Missing coverage for some persons
- Error messages or failed assertions

## Troubleshooting

### Stata Issues

1. **"command tvexpose not found"**
   - Install tvtools: Copy tvtools/*.ado to your personal ado directory
   - Or add tvtools folder to adopath

2. **"file not found"**
   - Ensure you're running from Stata-Tools root directory
   - Check that synthetic data has been generated

### R Issues

1. **"could not find function tvexpose"**
   - Check that source() commands work correctly
   - Verify R files exist in tvtools-r/R/

2. **"package 'haven' not found"**
   - Install required packages: `install.packages(c("haven", "dplyr", "readr"))`

3. **Date conversion errors**
   - Ensure Stata data uses proper date formats
   - Check that dates are stored as Stata date values (td format)

## Comparing Results

After running both test scripts, compare the summary CSV files:

```r
stata_sum <- read.csv("_testing/stata_summary.csv")
r_sum <- read.csv("_testing/r_summary.csv")

# View side by side
comparison <- rbind(stata_sum, r_sum)
comparison[order(comparison$hrt, comparison$dmt, comparison$source), ]
```

## Notes

- The R script handles Stata date conversion automatically using `haven`
- Stata labeled values are converted to factors in R
- Both implementations use the same algorithms but may differ slightly in internal optimizations
- Synthetic data is saved in Stata 13 format for maximum compatibility

## Author

Timothy P. Copeland
Created: 2025-11-21
