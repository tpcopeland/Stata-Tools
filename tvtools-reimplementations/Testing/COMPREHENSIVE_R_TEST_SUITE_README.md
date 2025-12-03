# Comprehensive R Test Suite for tvtools

**Created**: 2025-12-03
**Test Script**: `/home/user/Stata-Tools/Reimplementations/Testing/comprehensive_r_tests.R`
**Status**: ⚠️ Not yet executed (requires R installation)

---

## Overview

This document describes the comprehensive R test suite created to systematically test all tvtools functions with all option combinations using stress test data.

### Key Differences from Existing test_r_tvtools.R

| Feature | test_r_tvtools.R | comprehensive_r_tests.R |
|---------|------------------|------------------------|
| **Data Source** | Small test data (100 patients, 246 exposures) | Stress test data (500 patients, 3000+ exposures) |
| **TVExpose Tests** | 6 tests (basic functionality) | 14 tests (all option combinations) |
| **TVMerge Tests** | 3 tests | 3 tests (more focused on parameter variations) |
| **TVEvent Tests** | 4 tests | 7 tests (all type and option combinations) |
| **Total Tests** | 14 tests | 24 tests |
| **Output Format** | CSV + RDS + text logs | CSV + structured summary report |
| **Error Handling** | Stops on critical errors | Continues through all tests, reports at end |
| **Test Data** | cohort.csv, exposures.csv, events.csv | stress_cohort.csv, stress_exposures.csv, stress_events.csv |

---

## Test Coverage

### TVExpose Tests (14 tests)

| Test # | Test Name | Description | Key Parameters |
|--------|-----------|-------------|----------------|
| 1 | Basic exposure | No special options | Default binary exposure |
| 2 | evertreated=TRUE | Ever-treated indicator | `evertreated=TRUE` |
| 3 | currentformer=TRUE | Current vs former exposure | `currentformer=TRUE` |
| 4 | duration with cutpoints | Duration categories | `duration=c(30,90,180,365)` |
| 5 | continuousunit="days" | Cumulative exposure in days | `continuousunit="days"` |
| 6 | continuousunit="months" | Cumulative exposure in months | `continuousunit="months"` |
| 7 | continuousunit="years" | Cumulative exposure in years | `continuousunit="years"` |
| 8 | bytype=TRUE | Separate variable per exposure type | `bytype=TRUE, exposure_type="exptype"` |
| 9 | grace=30 | Grace period of 30 days | `grace=30` |
| 10 | grace=60 | Grace period of 60 days | `grace=60` |
| 11 | lag=14 | 14-day lag period | `lag=14` |
| 12 | washout=30 | 30-day washout period | `washout=30` |
| 13 | lag + washout | Combined lag and washout | `lag=14, washout=30` |
| 14 | layer=TRUE | Overlap handling with layering | `layer=TRUE` |

### TVMerge Tests (3 tests)

| Test # | Test Name | Description | Key Parameters |
|--------|-----------|-------------|----------------|
| 15 | Basic two-dataset merge | Merge two time-varying datasets | Default merge |
| 16 | Merge with continuous | Merge with continuous exposure variable | `continuous="exposed_days"` |
| 17 | Custom generate name | Different output variable naming | `generate="treatment"` |

### TVEvent Tests (7 tests)

| Test # | Test Name | Description | Key Parameters |
|--------|-----------|-------------|----------------|
| 18 | type="single" | Single event per person | `type="single"` |
| 19 | type="recurring" | Multiple events per person | `type="recurring"` |
| 20 | Single competing risk | One competing risk | `compete=compete_events` |
| 21 | Multiple competing risks | Multiple competing risks | `compete=list(compete1, compete2)` |
| 22 | Continuous variable | With continuous variable adjustment | `continuous="exposed_days"` |
| 23 | timegen + timeunit="days" | Generate time variable in days | `timegen="followup_days", timeunit="days"` |
| 24 | timegen + timeunit="years" | Generate time variable in years | `timegen="followup_years", timeunit="years"` |

---

## Test Data

### Input Files

```
/home/user/Stata-Tools/Reimplementations/Testing/stress_cohort.csv
  - 500 patients
  - Columns: id, startdate, enddate

/home/user/Stata-Tools/Reimplementations/Testing/stress_exposures.csv
  - 3000+ exposure records
  - Columns: id, expstart, expend, exptype

/home/user/Stata-Tools/Reimplementations/Testing/stress_events.csv
  - 150+ event records
  - Columns: id, eventdate, eventtype
```

### Output Directory

```
/home/user/Stata-Tools/Reimplementations/Testing/R_comprehensive_outputs/
  - tvexpose_01_basic.csv
  - tvexpose_02_evertreated.csv
  - ...
  - tvmerge_15_basic.csv
  - ...
  - tvevent_18_single.csv
  - ...
  - test_results_summary.csv
```

---

## Running the Test Suite

### Prerequisites

1. **R Installation** (version 4.0+)
   ```bash
   # Check if R is installed
   R --version
   ```

2. **Required R Packages**
   - dplyr
   - readr
   - tvtools (installed from local directory)

### Execution

```bash
# Navigate to testing directory
cd /home/user/Stata-Tools/Reimplementations/Testing

# Run the test suite
Rscript comprehensive_r_tests.R
```

### Expected Runtime

- **Installation**: 30-60 seconds
- **Test Execution**: 10-15 minutes (due to large stress test data)
- **Total Runtime**: ~15-20 minutes

---

## Test Script Architecture

### Phase 1: Setup
1. Create output directory
2. Install tvtools package from `/home/user/Stata-Tools/Reimplementations/R/tvtools`
3. Load required libraries (dplyr, readr, tvtools)
4. Initialize results tracking

### Phase 2: Data Loading
1. Load stress_cohort.csv (convert dates)
2. Load stress_exposures.csv (convert dates)
3. Load or create stress_events.csv (if missing, generates synthetic data)

### Phase 3: TVExpose Testing
- Run all 14 TVExpose tests sequentially
- Each test wrapped in tryCatch for error handling
- Record success/failure, output dimensions, patient counts
- Save outputs to CSV files

### Phase 4: TVMerge Testing
- Prepare exposure datasets using TVExpose
- Run 3 TVMerge tests
- Test different merge scenarios and parameters
- Save merge results

### Phase 5: TVEvent Testing
- Load event data
- Run 7 TVEvent tests
- Test single/recurring events, competing risks, time variables
- Save event analysis results

### Phase 6: Summary Report
1. Calculate aggregate statistics
2. Generate category summaries
3. Detail failed tests with error messages
4. List successful tests with output info
5. Save detailed results to CSV
6. Return exit code (0=success, 1=failures detected)

---

## Output Format

### Console Output

```
================================================================================
Comprehensive R tvtools Test Suite
================================================================================

Installing tvtools package from local directory...
✓ Package installed successfully

Loading test data...
✓ Cohort data loaded: 500 rows, 3 columns
✓ Exposure data loaded: 3000 rows, 4 columns

================================================================================
TVEXPOSE TESTS
================================================================================

Test 1: Basic exposure (no special options)
✓ PASSED - Output: 1234 rows, 4 columns

Test 2: evertreated=TRUE
✓ PASSED - Output: 567 rows, 4 columns

...

================================================================================
TEST SUMMARY REPORT
================================================================================

Total tests run: 24
Tests passed:    22 (91.7%)
Tests failed:    2

Results by category:
  category   total  passed  failed
1 TVExpose      14      13       1
2 TVMerge        3       3       0
3 TVEvent        7       6       1
```

### CSV Summary (test_results_summary.csv)

```csv
test_num,category,test_name,success,error_msg,nrow,ncol,n_patients,notes
1,TVExpose,Basic exposure,TRUE,NA,1234,4,500,""
2,TVExpose,evertreated=TRUE,TRUE,NA,567,4,500,""
3,TVExpose,currentformer=TRUE,FALSE,"Variable 'exposure_status' not found",NA,NA,NA,""
...
```

---

## Error Handling Features

### Graceful Failure
- Each test wrapped in tryCatch
- Failures don't stop subsequent tests
- All errors logged with full messages

### Comprehensive Recording
For each test, the script records:
- Test number and name
- Category (TVExpose, TVMerge, TVEvent)
- Success/failure status
- Error message (if failed)
- Output dimensions: nrow, ncol
- Number of unique patients
- Additional notes

### Exit Codes
- **0**: All tests passed
- **1**: One or more tests failed

---

## Known Issues from Previous Testing

Based on existing test results in `/home/user/Stata-Tools/Reimplementations/Testing/R_test_outputs/TEST_RESULTS_SUMMARY.md`:

### Critical Bugs (may affect comprehensive tests)

1. **Missing Exposure Variables** (Bug #2)
   - `evertreated` and `currentformer` don't create output variables
   - Affects Tests 2 and 3
   - Expected failures in comprehensive test suite

2. **`generate` Parameter Ignored** (Bug #3)
   - Output variable always named `tv_exp`
   - May affect interpretation of results

3. **Duration Vector Error** (Bug #4)
   - Issue with `duration = c(0, 90, 180)` in some contexts
   - May affect Test 4

### Expected Warnings

```
Warning: no non-missing arguments to min; returning Inf
```
- Harmless, occurs when patients have no exposures
- Does not affect results

---

## Comparison with Existing Results

### Previous Test Suite Results (test_r_tvtools.R)

**Overall**: 85.7% success rate (12/14 tests)

- **tvexpose**: 5/6 passed (83%)
- **tvmerge**: 3/3 passed (100%)
- **tvevent**: 4/4 passed (100%)
- **Integration**: 0/1 passed (0%)

### Expected Comprehensive Test Results

Based on known bugs, we expect:

- **tvexpose**: ~10/14 passed (71%)
  - Tests 2, 3 likely to fail (evertreated, currentformer bugs)
  - Test 4 may fail (duration vector bug)
  - Test 17 may have naming issues (generate parameter bug)

- **tvmerge**: 3/3 passed (100%)
  - No known bugs in tvmerge

- **tvevent**: 6-7/7 passed (86-100%)
  - Mostly functional
  - May have minor issues with continuous variable handling

**Expected Overall**: ~19-21/24 passed (79-88%)

---

## Stress Test Data Characteristics

### Cohort (stress_cohort.csv)
- **Patients**: 500
- **Follow-up**: Various durations (1 month to 3 years)
- **Date range**: 2015-2020

### Exposures (stress_exposures.csv)
- **Records**: 3000+
- **Average per patient**: 6 exposures
- **Types**: 5 different exposure types
- **Patterns**:
  - Overlapping exposures (tests layer handling)
  - Gaps between exposures (tests grace/washout)
  - Long-term exposures (tests duration categories)
  - Short-term exposures (tests lag handling)

### Events (stress_events.csv)
- **Records**: 150+
- **Types**:
  - Primary outcome events
  - Competing risk events (2 types)
- **Recurrent events**: Some patients have multiple events

---

## Advantages of Comprehensive Test Suite

### 1. Exhaustive Coverage
- Tests all documented parameter combinations
- Covers edge cases from stress test data
- More realistic data volumes (500 patients vs 100)

### 2. Systematic Approach
- Organized by function and feature
- Clear test numbering and naming
- Structured output format

### 3. Better Error Reporting
- Continues through failures
- Comprehensive summary at end
- Detailed CSV output for analysis

### 4. Production-Ready Output
- All outputs saved to dedicated directory
- Consistent naming convention
- Easy to compare results across test runs

### 5. Stress Testing
- Large dataset (500 patients, 3000+ exposures)
- Complex exposure patterns
- Better reflects real-world usage

---

## Usage Recommendations

### For Package Developers
1. Run after any code changes to tvtools functions
2. Compare test_results_summary.csv across versions
3. Use failing tests to guide bug fixes
4. Track pass rate over time

### For Package Users
1. Run before using tvtools in production
2. Check which features are working correctly
3. Avoid using features with known failures
4. Compare results with Stata tvtools for validation

### For Quality Assurance
1. Run on different R versions
2. Run on different operating systems
3. Compare with Python tvtools implementation
4. Validate against original Stata tvtools

---

## Next Steps

### To Execute This Test Suite

1. **Install R** on the system
   ```bash
   # Ubuntu/Debian
   sudo apt-get update
   sudo apt-get install r-base r-base-dev

   # Or use Docker
   docker run -v /home/user/Stata-Tools:/work -it r-base R
   ```

2. **Run the test script**
   ```bash
   cd /home/user/Stata-Tools/Reimplementations/Testing
   Rscript comprehensive_r_tests.R
   ```

3. **Review results**
   ```bash
   cat R_comprehensive_outputs/test_results_summary.csv
   ls -lh R_comprehensive_outputs/
   ```

### To Compare with Python Tests

```bash
cd /home/user/Stata-Tools/Reimplementations/Testing
python3 cross_validate_outputs.py --r-dir R_comprehensive_outputs --python-dir Python_test_outputs
```

---

## File Locations

### Test Script
```
/home/user/Stata-Tools/Reimplementations/Testing/comprehensive_r_tests.R
```

### Test Data
```
/home/user/Stata-Tools/Reimplementations/Testing/stress_cohort.csv
/home/user/Stata-Tools/Reimplementations/Testing/stress_exposures.csv
/home/user/Stata-Tools/Reimplementations/Testing/stress_events.csv
```

### Output Directory
```
/home/user/Stata-Tools/Reimplementations/Testing/R_comprehensive_outputs/
```

### Package Location
```
/home/user/Stata-Tools/Reimplementations/R/tvtools/
```

---

## Conclusion

This comprehensive test suite provides systematic testing of all tvtools R functions with all documented parameter combinations. It uses realistic stress test data and provides detailed, structured output suitable for regression testing, quality assurance, and cross-validation with other implementations.

**Status**: Script created and ready to run when R is available on the system.

**Recommendation**: Run this comprehensive test suite alongside the existing test_r_tvtools.R to get both quick validation (existing tests) and exhaustive coverage (comprehensive tests).

---

**Created**: 2025-12-03
**Author**: Claude AI Assistant
**Repository**: /home/user/Stata-Tools
