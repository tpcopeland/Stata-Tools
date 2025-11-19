# Running tvexpose Integration Tests

## Quick Start

```bash
cd /home/user/Stata-Tools/tvtools-r/tests
Rscript integration_test_tvexpose.R
```

## Expected Output

```
================================================================================
  TVEXPOSE INTEGRATION TEST SUITE
================================================================================

--- SECTION 1: SETUP ---
Loading required packages...
Packages loaded successfully.
Loading tvtools functions...
Functions loaded successfully.
Loading test datasets...
Loaded 16 test datasets.

--- SECTION 2: BASIC FUNCTIONALITY TESTS ---
[✓] Test 1: Basic time-varying exposure - PASS
[✓] Test 2: Complete coverage of follow-up - PASS
[✓] Test 3: Handling of unexposed persons - PASS

... (27 more tests) ...

================================================================================
  TEST SUMMARY
================================================================================

Total Tests: 30
Passed:      30 (100.0%)
Failed:      0 (0.0%)

================================================================================
  ALL TESTS PASSED
================================================================================
```

## Test Duration

- Small dataset tests: ~2-3 minutes
- Includes large dataset test (1000 persons): ~15-20 seconds
- Total runtime: ~3-4 minutes

## Requirements

The test suite will automatically install required packages if missing:
- dplyr
- tidyr
- lubridate
- survival
- zoo

## Test Coverage

### 30 Comprehensive Tests:

1. ✅ Basic time-varying exposure
2. ✅ Complete coverage of follow-up
3. ✅ Handling of unexposed persons
4. ✅ Ever-treated indicator
5. ✅ Current/former exposure indicator
6. ✅ Multiple exposure types (bytype)
7. ✅ Duration categories
8. ✅ Recency categories
9. ✅ No grace period (baseline)
10. ✅ Grace period (30 days)
11. ✅ Named grace periods by type
12. ✅ Lag period (30 days)
13. ✅ Washout period (60 days)
14. ✅ Combined lag and washout
15. ✅ Overlap handling - layer strategy
16. ✅ Overlap handling - priority strategy
17. ✅ Overlap handling - split strategy
18. ✅ Point-in-time events
19. ✅ Keepvars from master dataset
20. ✅ Edge case - exposure before study entry
21. ✅ Edge case - exposure after study exit
22. ✅ Edge case - very short exposures (1 day)
23. ✅ Edge case - very long exposures (10 years)
24. ✅ Edge case - empty exposure dataset
25. ✅ Edge case - exposure spanning entire follow-up
26. ✅ Switching indicator
27. ✅ Switching detail (sequence)
28. ✅ Large dataset (1000 persons)
29. ✅ Complex combination - evertreated + grace + lag
30. ✅ Complex combination - duration + bytype

## Validation Checks

Each test validates:
- ✅ No missing values in exposure variables
- ✅ No overlapping periods per person
- ✅ Complete temporal coverage
- ✅ Proper date ordering
- ✅ Correct exposure categorization

## Files Used

**Test Script:**
- `/home/user/Stata-Tools/tvtools-r/tests/integration_test_tvexpose.R`

**Test Data:** (16 datasets in `/home/user/Stata-Tools/tvtools-r/tests/test_data/`)
- cohort_basic.rds (100 persons)
- cohort_no_exposure.rds (20 persons)
- cohort_large.rds (1000 persons)
- exposure_simple.rds, exposure_gaps.rds, exposure_overlap.rds
- exposure_multi_types.rds, exposure_point_time.rds
- exposure_edge_cases.rds, exposure_grace_test.rds
- exposure_lag_washout.rds, exposure_switching.rds
- exposure_duration_test.rds, exposure_continuous.rds
- exposure_mixed.rds, exposure_large.rds

**Results:**
- `/home/user/Stata-Tools/tvtools-r/tests/INTEGRATION_TEST_RESULTS.md`

## Interpreting Results

### Success (Exit Code 0)
```
================================================================================
  ALL TESTS PASSED
================================================================================
```

### Failure (Exit Code 1)
```
================================================================================
  SOME TESTS FAILED
================================================================================

FAILED TESTS:
-------------
  [X] Test Name
      Error: Description of failure
```

## Troubleshooting

### Missing Packages
If packages are missing, the script will auto-install them from CRAN.

### Test Data Missing
Regenerate test data:
```bash
Rscript /home/user/Stata-Tools/tvtools-r/tests/generate_test_data.R
```

### Function Errors
Check that R source files are present:
```bash
ls /home/user/Stata-Tools/tvtools-r/R/tvexpose.R
ls /home/user/Stata-Tools/tvtools-r/R/tvmerge.R
```

## Test Results

**Current Status:** ✅ ALL 30 TESTS PASSING (100.0%)

See `INTEGRATION_TEST_RESULTS.md` for detailed analysis.
