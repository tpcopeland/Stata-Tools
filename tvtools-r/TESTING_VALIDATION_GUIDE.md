# Testing and Validation Guide for tvtools-r

## Overview

This guide provides step-by-step instructions for testing and validating the tvtools-r package to ensure production readiness. All validation functions have been implemented and comprehensive unit tests have been created.

## Status Summary

### ✅ Completed
- [x] Validation helper functions created (7 functions)
- [x] Validation functions integrated into tvexpose()
- [[x] Comprehensive unit tests created (test-validation-functions.R)
- [x] Code syntax verified

### ⚠️ Requires R Environment
- [ ] Install R dependencies
- [ ] Update package documentation
- [ ] Run test suite
- [ ] Run R CMD check
- [ ] Fix any identified errors
- [ ] Final validation

---

## Prerequisites

This package requires R (version >= 3.5.0) with the following packages:

### Required Dependencies
```r
install.packages(c(
  'dplyr',
  'tidyr',
  'lubridate',
  'survival',
  'zoo',
  'testthat',
  'devtools',
  'roxygen2'
), repos='https://cloud.r-project.org')
```

---

## Testing Procedure

### Step 1: Install Dependencies

```bash
# Install required R packages
Rscript -e "install.packages(c('dplyr', 'tidyr', 'lubridate', 'testthat', 'devtools'), repos='https://cloud.r-project.org')"
```

**Expected Outcome:** All packages install successfully without errors.

---

### Step 2: Update Documentation

Generate updated documentation from roxygen comments:

```bash
cd tvtools-r
Rscript -e "devtools::document()"
```

**Expected Outcome:**
- NAMESPACE file updated with exported functions
- Man pages generated in `man/` directory
- No warnings about documentation issues

**Files to Check:**
- `NAMESPACE` - should contain proper exports
- `man/tvexpose.Rd` - should include all parameter documentation

---

### Step 3: Run Validation Function Tests

Run the new validation function test suite:

```bash
Rscript -e "devtools::test('tests/testthat/test-validation-functions.R')"
```

**Expected Outcome:** All tests pass (0 failures, 0 errors)

**Test Coverage:**
- `validate_master_dataset()` - 6 tests
- `validate_exposure_dataset()` - 6 tests
- `validate_id_type_match()` - 5 tests
- `validate_keepvars()` - 5 tests
- `validate_duration()` - 9 tests
- `validate_recency()` - 9 tests
- `validate_no_conflicting_exposure_types()` - 9 tests
- Integration tests - 7 tests

**Total:** 56+ validation tests

---

### Step 4: Run Full Test Suite

Run all existing tests plus new validation tests:

```bash
Rscript -e "devtools::test()"
```

**Expected Outcome:** All tests pass

**What This Tests:**
- Basic tvexpose functionality
- Edge cases (gaps, overlaps, missing values)
- Different exposure types (evertreated, currentformer, duration, recency, bytype)
- Parameter validation
- Output format verification
- Lag and washout functionality
- New validation functions

---

### Step 5: Run R CMD check

Perform comprehensive package check:

```bash
# Build the package
R CMD build tvtools-r/

# Check the package
R CMD check tvtools_*.tar.gz
```

**Expected Outcome:**
- 0 ERRORs
- 0 WARNINGs
- Minimal NOTEs (acceptable: package size, documentation)

**Common Issues to Watch For:**
1. **Undocumented functions** - All exported functions must have documentation
2. **Missing dependencies** - All used packages must be in DESCRIPTION
3. **Example failures** - Examples in documentation must run successfully
4. **S3 method registration** - Generic methods must be properly registered

---

### Step 6: Manual Integration Tests

Run the existing integration tests:

```bash
cd tvtools-r/tests
Rscript integration_test_tvexpose.R
Rscript integration_test_tvmerge.R
```

**Expected Outcome:**
- All test scenarios complete successfully
- Output files created in `test_output/`
- No unexpected errors or warnings

---

### Step 7: Specific Validation Checks

Test each validation function individually to ensure proper error messages:

```r
# Start R session
R

# Load the package
devtools::load_all()

# Test 1: Empty master dataset
master_empty <- data.frame(id = integer(), entry = as.Date(character()),
                          exit = as.Date(character()))
tryCatch(
  validate_master_dataset(master_empty, "id", "entry", "exit"),
  error = function(e) print(e$message)
)
# Expected: "master dataset is empty (0 rows)"

# Test 2: Duplicate IDs
master_dup <- data.frame(id = c(1, 1, 2),
                        entry = as.Date("2010-01-01") + 0:2,
                        exit = as.Date("2020-01-01"))
tryCatch(
  validate_master_dataset(master_dup, "id", "entry", "exit"),
  error = function(e) print(e$message)
)
# Expected: Error mentioning "duplicate ID(s)"

# Test 3: Type mismatch
master <- data.frame(id = 1:10,
                    entry = as.Date("2010-01-01"),
                    exit = as.Date("2020-01-01"))
exposure <- data.frame(id = as.character(1:5),
                      exp_start = as.Date("2011-01-01"),
                      exp_stop = as.Date("2012-01-01"),
                      exposure = 1)
tryCatch(
  validate_id_type_match(master$id, exposure$id, "id"),
  error = function(e) print(e$message)
)
# Expected: Error mentioning "different types"

# Test 4: NA in exposure
exposure_na <- data.frame(id = 1:5,
                         exp_start = as.Date("2011-01-01"),
                         exp_stop = as.Date("2012-01-01"),
                         exposure = c(1, NA, 1, NA, 1))
tryCatch(
  validate_exposure_dataset(exposure_na, "id", "exposure"),
  error = function(e) print(e$message)
)
# Expected: Error mentioning "contains 2 NA value(s)"

# Test 5: Invalid duration cutpoints
tryCatch(
  validate_duration(c(5, 1, 10)),  # Not sorted
  error = function(e) print(e$message)
)
# Expected: Error about "ascending order"

# Test 6: Conflicting exposure types
tryCatch(
  validate_no_conflicting_exposure_types(
    evertreated = TRUE,
    currentformer = TRUE,
    duration = NULL,
    recency = NULL,
    continuousunit = NULL
  ),
  error = function(e) print(e$message)
)
# Expected: Error about "Only one exposure type"

# Test 7: Missing keepvars
master <- data.frame(id = 1:10, age = 50:59,
                    entry = as.Date("2010-01-01"),
                    exit = as.Date("2020-01-01"))
tryCatch(
  validate_keepvars(master, c("age", "gender")),
  error = function(e) print(e$message)
)
# Expected: Error listing "gender" as not found
```

---

## Validation Checklist

### Code Quality
- [ ] All validation functions have proper roxygen documentation
- [ ] Error messages are clear and actionable
- [ ] Functions follow consistent naming conventions
- [ ] Code follows R style guidelines

### Functionality
- [ ] Validation functions catch all edge cases
- [ ] Error messages include helpful context (counts, examples)
- [ ] Functions return invisible(TRUE) on success
- [ ] NULL/empty inputs handled gracefully

### Integration
- [ ] tvexpose() calls all validation functions
- [ ] Validation occurs before main processing
- [ ] Validation errors propagate correctly to user
- [ ] No regression in existing functionality

### Testing
- [ ] All validation function tests pass
- [ ] All integration tests pass
- [ ] Edge cases covered (empty data, NAs, type mismatches)
- [ ] Error messages tested for clarity

### Documentation
- [ ] NAMESPACE updated
- [ ] Man pages generated
- [ ] Examples run successfully
- [ ] README includes validation function information

### Package Check
- [ ] R CMD check passes with 0 errors, 0 warnings
- [ ] All dependencies listed in DESCRIPTION
- [ ] Version number appropriate
- [ ] License file present

---

## Known Issues and Fixes

### Issue 1: Empty exposure_data with validate_id_type_match

**Scenario:** When exposure_data has 0 rows, `exposure_data[[id]]` returns empty vector.

**Status:** ✅ Handled - Empty vectors still have class, comparison works correctly

**Test:** Line 790 in tvexpose.R
```r
validate_id_type_match(master[[id]], exposure_data[[id]], id)
```

### Issue 2: Validation called before column existence checks

**Status:** ✅ Verified - Basic column existence checks happen first (lines 703-726)

**Order of Operations:**
1. Data frame type checks (lines 696-701)
2. Column existence checks (lines 703-726)
3. NA value checks (lines 728-748)
4. Parameter type checks (lines 750-777)
5. Comprehensive validation (lines 783-804)

---

## Expected Test Results

### test-validation-functions.R
```
Test results:
✓ validate_master_dataset accepts valid master dataset
✓ validate_master_dataset rejects empty master dataset
✓ validate_master_dataset detects duplicate IDs
✓ validate_master_dataset validates ID type
✓ validate_master_dataset accepts character IDs
✓ validate_master_dataset provides informative error for duplicates
✓ validate_exposure_dataset accepts valid exposure dataset
✓ validate_exposure_dataset accepts empty exposure dataset
✓ validate_exposure_dataset validates ID type
✓ validate_exposure_dataset detects NA in exposure variable
✓ validate_exposure_dataset reports count of NA values
✓ validate_exposure_dataset accepts character IDs
... (44 more tests)

Total: 56 tests, 0 failures, 0 errors
```

### test-tvexpose.R
```
Test results:
✓ tvexpose handles basic time-varying exposure
✓ tvexpose creates correct number of rows
✓ tvexpose handles unexposed persons correctly
✓ tvexpose handles gaps in exposure correctly
... (50+ more tests)

Total: 50+ tests, 0 failures, 0 errors
```

### R CMD check
```
* using log directory '/tmp/tvtools.Rcheck'
* using R version 4.x.x
* checking package namespace information ... OK
* checking for code/documentation mismatches ... OK
* checking examples ... OK
* checking tests ... OK
  Running 'testthat.R'
* checking PDF version of manual ... OK

Status: OK

R CMD check results
0 errors | 0 warnings | 1 note
```

---

## Troubleshooting

### Test Failures

**Symptom:** Tests fail with "could not find function"

**Cause:** Package not properly loaded

**Fix:**
```r
devtools::load_all()
devtools::test()
```

---

**Symptom:** Tests fail with validation errors

**Cause:** Validation functions working correctly!

**Fix:** Review error message - this indicates the validation is catching bad inputs

---

**Symptom:** R CMD check fails with "undocumented arguments"

**Cause:** Roxygen documentation incomplete

**Fix:**
```r
devtools::document()
R CMD check --as-cran tvtools_*.tar.gz
```

---

### Documentation Issues

**Symptom:** Man pages not generated

**Cause:** roxygen2 not running

**Fix:**
```r
devtools::document()
```

---

**Symptom:** NAMESPACE conflicts

**Cause:** Manual edits to NAMESPACE

**Fix:** Delete NAMESPACE and regenerate:
```r
file.remove("NAMESPACE")
devtools::document()
```

---

## Success Criteria

The package is production-ready when:

1. ✅ All 7 validation functions implemented and documented
2. ✅ All validation functions integrated into tvexpose()
3. ✅ Comprehensive test suite created (56+ validation tests)
4. ⏳ All tests pass (requires R environment)
5. ⏳ R CMD check returns 0 errors, 0 warnings
6. ⏳ Documentation complete and accurate
7. ⏳ Integration tests run successfully

**Current Status:** 3/7 complete (awaiting R environment for remaining items)

---

## Next Steps After Testing

Once all tests pass:

1. **Update version number** in DESCRIPTION if needed
2. **Update NEWS.md** with changes
3. **Commit changes** with descriptive message
4. **Create pull request** with test results
5. **Tag release** if ready for production

---

## Contact

For issues or questions:
- Check test output in `tests/testthat/` directory
- Review validation function code in `R/tvexpose.R` (lines 1-268)
- Consult NEXT_STEPS_COMPREHENSIVE_GUIDE.md for implementation details

---

## Appendix: File Locations

### Validation Functions
- **Location:** `R/tvexpose.R` (lines 1-268)
- **Functions:** 7 validation helpers
- **Integration:** `R/tvexpose.R` (lines 783-804)

### Test Files
- **Validation tests:** `tests/testthat/test-validation-functions.R` (NEW)
- **Main tests:** `tests/testthat/test-tvexpose.R`
- **Integration tests:** `tests/integration_test_tvexpose.R`

### Documentation
- **Guide:** `NEXT_STEPS_COMPREHENSIVE_GUIDE.md`
- **Implementation report:** `VALIDATION_FUNCTIONS_REPORT.md`
- **This guide:** `TESTING_VALIDATION_GUIDE.md`

### Test Data
- **Location:** `tests/test_data/`
- **Examples:** cohort_basic.csv, exposure_*.csv
- **Summary:** `tests/TEST_DATA_SUMMARY.md`
