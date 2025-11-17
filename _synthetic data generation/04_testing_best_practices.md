# Comprehensive Guide to Testing Stata Code

## Table of Contents
1. [Introduction to Testing in Stata](#introduction-to-testing-in-stata)
2. [Types of Testing](#types-of-testing)
3. [The Assert Command](#the-assert-command)
4. [Unit Testing Framework](#unit-testing-framework)
5. [Certification Scripts](#certification-scripts)
6. [Integration Testing](#integration-testing)
7. [Regression Testing](#regression-testing)
8. [Testing Edge Cases](#testing-edge-cases)
9. [Data Validation and Quality Checks](#data-validation-and-quality-checks)
10. [Testing Estimation Commands](#testing-estimation-commands)
11. [Automated Testing Workflows](#automated-testing-workflows)
12. [Continuous Integration](#continuous-integration)
13. [Performance Testing](#performance-testing)
14. [Documentation Testing](#documentation-testing)

---

## Introduction to Testing in Stata

### Why Test Your Code?

Testing is critical for:
- **Correctness**: Ensure code does what it's supposed to
- **Reliability**: Catch bugs before users do
- **Maintainability**: Detect when changes break existing functionality
- **Confidence**: Develop with assurance that code works
- **Documentation**: Tests serve as executable specifications
- **Professionalism**: Mark of high-quality software development

### Testing Philosophy for Stata

1. **Test Early and Often**: Write tests as you develop
2. **Automate**: Make tests easy to run repeatedly
3. **Cover Edge Cases**: Test boundary conditions and unusual inputs
4. **Test What Matters**: Focus on critical functionality
5. **Keep Tests Simple**: Tests should be easier to understand than code
6. **Make Tests Fast**: Fast tests run more often

### StataCorp's Approach

StataCorp uses extensive certification scripts for all commands. Every Stata command has comprehensive tests checking:
- Correct results against known values
- Proper error handling
- Consistency across different datasets
- Compatibility across Stata versions

**We should emulate this approach.**

---

## Types of Testing

### 1. Unit Testing

Tests individual functions or commands in isolation.

```stata
* Test a single function
program define test_myfunction
    clear
    set obs 100
    set seed 12345

    generate x = rnormal()
    myfunction x

    * Check result
    assert r(mean) < 0.5  // Should be near 0
    assert r(mean) > -0.5

    display "test_myfunction: PASSED"
end
```

### 2. Integration Testing

Tests how multiple components work together.

```stata
* Test workflow of multiple commands
program define test_workflow
    clear
    sysuse auto

    * Step 1: Prepare data
    myprep price mpg weight
    assert r(N) == 74

    * Step 2: Analyze
    myanalyze price mpg weight
    assert r(converged) == 1

    * Step 3: Post-process
    mypost
    capture confirm variable predicted
    assert _rc == 0  // Variable should exist

    display "test_workflow: PASSED"
end
```

### 3. Regression Testing

Tests that changes don't break existing functionality.

```stata
* Compare against reference results
program define test_regression
    clear
    set seed 99999
    set obs 1000
    generate x = rnormal()
    generate y = 2*x + rnormal()

    myregress y x

    * Load reference results
    scalar ref_coef = 2.05  // From previous version
    scalar ref_se = 0.03

    * Check within tolerance
    assert abs(_b[x] - ref_coef) < 0.01
    assert abs(_se[x] - ref_se) < 0.01

    display "test_regression: PASSED"
end
```

### 4. Smoke Testing

Basic tests that command runs without crashing.

```stata
* Quick check that command doesn't crash
program define test_smoke
    clear
    sysuse auto

    * Just verify it runs
    capture noisily mycommand price mpg weight
    assert _rc == 0  // Should complete without error

    display "test_smoke: PASSED"
end
```

### 5. Validation Testing

Tests against known theoretical or empirical results.

```stata
* Validate against known result
program define test_validation
    * Test with data where we know the answer
    clear
    set obs 100
    set seed 12345

    generate x = _n
    generate y = 3 + 2*x  // Perfect linear relationship

    myregress y x

    * Coefficient should be exactly 2
    assert abs(_b[x] - 2) < 1e-10
    * Intercept should be exactly 3
    assert abs(_b[_cons] - 3) < 1e-10
    * R-squared should be 1
    assert abs(e(r2) - 1) < 1e-10

    display "test_validation: PASSED"
end
```

---

## The Assert Command

### Basic Assert Usage

```stata
* Assert that condition is true
assert x > 0              // All values must be positive
assert !missing(y)        // No missing values
assert inrange(z, 0, 100) // All values between 0 and 100

* If assertion fails, Stata stops with error
* This is the foundation of testing in Stata
```

### Assert in Testing Context

```stata
program define test_with_assert
    clear
    set obs 100
    generate x = rnormal()

    summarize x
    local mean = r(mean)
    local sd = r(sd)

    * Test that results are reasonable
    assert abs(`mean') < 0.5  // Mean near 0
    assert `sd' > 0.5 & `sd' < 1.5  // SD near 1
    assert r(N) == 100  // Correct N

    * Test relationships
    quietly count if x > 0
    local n_pos = r(N)
    assert `n_pos' > 30 & `n_pos' < 70  // Roughly 50% positive
end
```

### Capture with Assert

```stata
* Test that something SHOULD fail
capture assert invalid_condition
assert _rc != 0  // Assertion should have failed

* Example: Test error handling
capture mycommand x if x < 0  // Should error on negative values
assert _rc != 0  // Verify it did error
```

### Assert with Tolerance

```stata
* Floating point comparisons need tolerance
scalar target = 2.0
scalar result = 1.99999999

* DON'T: This might fail due to floating point precision
* assert result == target

* DO: Use tolerance
assert abs(result - target) < 1e-8

* Helper function for floating point comparison
program define assert_close
    args val1 val2 tolerance

    if "`tolerance'" == "" {
        local tolerance = 1e-8
    }

    if abs(`val1' - `val2') > `tolerance' {
        display as error "Assertion failed:"
        display as error "  Value 1: `val1'"
        display as error "  Value 2: `val2'"
        display as error "  Tolerance: `tolerance'"
        exit 9
    }
end

* Usage:
assert_close `result' 2.0 1e-6
```

---

## Unit Testing Framework

### Basic Test Structure

```stata
/*****************************************************************************
* test_mycommand.do
* Unit tests for mycommand
*****************************************************************************/

* Initialize testing
clear all
set more off
local test_count = 0
local test_passed = 0
local test_failed = 0

* Helper: Run single test
program define run_test
    args testname

    display _n as text "Running test: `testname'"

    capture noisily `testname'
    if _rc {
        display as error "  FAILED (error code `=_rc')"
        global test_failed = ${test_failed} + 1
    }
    else {
        display as result "  PASSED"
        global test_passed = ${test_passed} + 1
    }

    global test_count = ${test_count} + 1
end

* Test 1: Basic functionality
program define test_basic
    clear
    set obs 100
    set seed 12345

    generate x = rnormal()
    generate y = 2*x + rnormal()

    mycommand y x

    assert r(N) == 100
    assert abs(r(coef) - 2) < 0.5
    assert r(converged) == 1
end

* Test 2: With options
program define test_with_options
    clear
    sysuse auto

    mycommand price mpg, robust detail

    assert r(N) == 74
    assert "`r(vcetype)'" == "Robust"
end

* Test 3: Error handling
program define test_error_handling
    clear
    set obs 10
    generate x = .

    * Should error on all missing
    capture noisily mycommand x
    assert _rc != 0
end

* Run all tests
global test_count = 0
global test_passed = 0
global test_failed = 0

run_test test_basic
run_test test_with_options
run_test test_error_handling

* Summary
display _n as text "{hline 60}"
display as text "Test Summary:"
display as text "  Total tests: " as result ${test_count}
display as text "  Passed: " as result ${test_passed}
display as text "  Failed: " as error ${test_failed}
display as text "{hline 60}"

if ${test_failed} > 0 {
    display as error _n "SOME TESTS FAILED"
    exit 9
}
else {
    display as result _n "ALL TESTS PASSED"
}
```

### Test Organization

```
tests/
├── test_all.do          # Run all tests
├── test_mycommand.do    # Tests for mycommand
├── test_helper.do       # Helper functions
├── test_utils.do        # Utility tests
└── test_data/          # Test data files
    ├── test1.dta
    └── test2.dta
```

### Master Test Runner

```stata
/*****************************************************************************
* test_all.do
* Run all tests for the project
*****************************************************************************/

clear all
set more off

* Set up test environment
global test_root "`c(pwd)'"
global test_failed = 0

* Helper to run test file
program define run_test_file
    args filename

    display _n as text "{hline 60}"
    display as text "Running: `filename'"
    display as text "{hline 60}"

    capture noisily do "`filename'"
    if _rc {
        display as error "`filename': FAILED"
        global test_failed = 1
    }
    else {
        display as result "`filename': PASSED"
    }
end

* Run each test file
run_test_file "tests/test_mycommand.do"
run_test_file "tests/test_helper.do"
run_test_file "tests/test_utils.do"

* Final summary
display _n as text "{hline 60}"
if ${test_failed} {
    display as error "SOME TEST FILES FAILED"
    exit 9
}
else {
    display as result "ALL TEST FILES PASSED"
}
```

---

## Certification Scripts

### What is a Certification Script?

A certification script is a comprehensive test file that validates a command works correctly. StataCorp uses these for all official commands.

### Structure of Certification Script

```stata
*! certification script for mycommand version 1.0.0

clear all
set more off

* Set seed for reproducibility
set seed 339487731

display _n "mycommand certification script"
display "Version 1.0.0"
display "Date: " c(current_date)
display ""

*****************************************************************************
* Test 1: Basic OLS regression
*****************************************************************************
display _n "Test 1: Basic OLS regression"

clear
set obs 1000
generate x = rnormal()
generate y = 3 + 2*x + rnormal()

mycommand y x

* Verify coefficient is close to 2
assert abs(_b[x] - 2) < 0.1
assert abs(_b[_cons] - 3) < 0.1

* Verify sample size
assert e(N) == 1000

display "  Test 1: PASSED"

*****************************************************************************
* Test 2: Multiple regressors
*****************************************************************************
display _n "Test 2: Multiple regressors"

clear
sysuse auto
mycommand price mpg weight foreign

* Verify results structure
assert e(N) == 74
assert e(df_m) == 3
assert e(df_r) == 70

* Verify R-squared is reasonable
assert e(r2) > 0 & e(r2) < 1

display "  Test 2: PASSED"

*****************************************************************************
* Test 3: Robust standard errors
*****************************************************************************
display _n "Test 3: Robust standard errors"

clear
sysuse auto
mycommand price mpg weight, robust

assert e(N) == 74
assert "`e(vcetype)'" == "Robust"

* Robust SEs should differ from OLS
quietly mycommand price mpg weight
scalar ols_se = _se[mpg]
quietly mycommand price mpg weight, robust
scalar robust_se = _se[mpg]

assert ols_se != robust_se

display "  Test 3: PASSED"

*****************************************************************************
* Test 4: if/in conditions
*****************************************************************************
display _n "Test 4: if/in conditions"

clear
sysuse auto

mycommand price mpg if foreign == 1
assert e(N) == 22

mycommand price mpg in 1/50
assert e(N) == 50

mycommand price mpg if price > 5000 in 1/60
quietly count if price > 5000 & _n <= 60
assert e(N) == r(N)

display "  Test 4: PASSED"

*****************************************************************************
* Test 5: Weights
*****************************************************************************
display _n "Test 5: Weights"

clear
sysuse auto

generate wt = weight / 1000

mycommand price mpg [aweight=wt]
assert e(N) == 74

mycommand price mpg [fweight=wt]
assert e(N) > 74  // Frequency weights increase N

display "  Test 5: PASSED"

*****************************************************************************
* Test 6: Missing values
*****************************************************************************
display _n "Test 6: Missing values"

clear
set obs 100
generate x = rnormal()
generate y = 2*x + rnormal()

* Create missing values
replace y = . in 1/10
replace x = . in 11/20

mycommand y x

* Should use only complete cases
assert e(N) == 80

display "  Test 6: PASSED"

*****************************************************************************
* Test 7: Edge case - perfect collinearity
*****************************************************************************
display _n "Test 7: Perfect collinearity"

clear
set obs 100
generate x = rnormal()
generate x2 = 2*x  // Perfect collinearity
generate y = rnormal()

capture mycommand y x x2
assert _rc != 0  // Should error

display "  Test 7: PASSED"

*****************************************************************************
* Test 8: Edge case - no variance
*****************************************************************************
display _n "Test 8: No variance in regressor"

clear
set obs 100
generate x = 5  // Constant
generate y = rnormal()

capture mycommand y x
assert _rc != 0  // Should error

display "  Test 8: PASSED"

*****************************************************************************
* Test 9: Edge case - single observation
*****************************************************************************
display _n "Test 9: Single observation"

clear
set obs 1
generate x = 5
generate y = 10

capture mycommand y x
assert _rc != 0  // Should error - insufficient observations

display "  Test 9: PASSED"

*****************************************************************************
* Test 10: Stored results
*****************************************************************************
display _n "Test 10: Stored results"

clear
sysuse auto
mycommand price mpg weight

* Verify all expected results are stored
assert e(N) != .
assert e(df_m) != .
assert e(df_r) != .
assert e(r2) != .
assert e(rmse) != .
assert e(F) != .

* Verify macros
assert "`e(cmd)'" == "mycommand"
assert "`e(depvar)'" == "price"

* Verify matrices
matrix b = e(b)
assert colsof(b) == 3  // mpg, weight, _cons

matrix V = e(V)
assert rowsof(V) == 3
assert colsof(V) == 3

display "  Test 10: PASSED"

*****************************************************************************
* Summary
*****************************************************************************
display _n "{hline 60}"
display "Certification complete"
display "All tests PASSED"
display "{hline 60}"
```

### Running Certification Scripts

```stata
* Run certification
do certify_mycommand.do

* Run with logging
log using certify_mycommand.log, replace
do certify_mycommand.do
log close

* Compare log to reference
* (Manual check or automated diff)
```

---

## Integration Testing

### Testing Multiple Commands Together

```stata
/*****************************************************************************
* Integration test: Full analysis workflow
*****************************************************************************/

program define test_full_workflow
    * Step 1: Data preparation
    clear
    sysuse auto

    * Clean data
    drop if missing(price, mpg, weight)

    * Create variables
    generate log_price = log(price)
    generate log_weight = log(weight)

    assert _N == 74 - (number of missing observations)

    * Step 2: Descriptive analysis
    mydescribe log_price log_weight mpg
    assert r(N_vars) == 3

    * Step 3: Main analysis
    myregress log_price mpg log_weight
    assert e(converged) == 1

    * Step 4: Post-estimation
    predict yhat
    predict resid, residuals

    assert !missing(yhat)
    assert !missing(resid)

    * Step 5: Diagnostics
    mydiagnostics
    assert r(heteroskedasticity_p) != .

    * Step 6: Export results
    myexport using "results.tex", replace

    confirm file "results.tex"

    display "Integration test: PASSED"
end
```

### Testing Command Compatibility

```stata
program define test_compatibility
    * Test that command works with Stata's built-in commands

    clear
    sysuse auto

    * Test with by:
    by foreign, sort: mycommand price mpg

    * Test with statsby:
    statsby coef=_b[mpg], by(foreign) clear: mycommand price mpg weight
    assert _N == 2  // Two groups

    * Test with bootstrap:
    clear
    sysuse auto
    bootstrap r(coef): mycommand price mpg

    * Test with simulate:
    program define sim
        drop _all
        set obs 100
        generate x = rnormal()
        generate y = 2*x + rnormal()
        mycommand y x
    end

    simulate coef=r(coef), reps(100) seed(123): sim

    display "Compatibility test: PASSED"
end
```

---

## Regression Testing

### Creating Reference Results

```stata
/*****************************************************************************
* create_reference_results.do
* Generate reference results for regression testing
*****************************************************************************/

clear all
set seed 12345

* Test case 1
clear
set obs 1000
generate x = rnormal()
generate y = 2*x + rnormal()

mycommand y x

* Store reference results
matrix ref1_b = e(b)
matrix ref1_V = e(V)
scalar ref1_N = e(N)
scalar ref1_r2 = e(r2)

* Save reference results
matrix save reference/test1_b.mat, replace
matrix save reference/test1_V.mat, replace

* Save as dataset for easy comparison
clear
set obs 1
generate b_x = ref1_b[1,1]
generate b_cons = ref1_b[1,2]
generate N = ref1_N
generate r2 = ref1_r2

save reference/test1_results.dta, replace

display "Reference results created"
```

### Comparing Against Reference

```stata
/*****************************************************************************
* test_against_reference.do
* Compare current results to reference
*****************************************************************************/

program define test_reference_case1
    clear
    set seed 12345

    * Generate same data
    set obs 1000
    generate x = rnormal()
    generate y = 2*x + rnormal()

    * Run current version
    mycommand y x

    * Load reference
    preserve
    use reference/test1_results.dta, clear
    local ref_b_x = b_x
    local ref_b_cons = b_cons
    local ref_N = N
    local ref_r2 = r2
    restore

    * Compare with tolerance
    local tolerance = 1e-6

    assert abs(_b[x] - `ref_b_x') < `tolerance'
    assert abs(_b[_cons] - `ref_b_cons') < `tolerance'
    assert e(N) == `ref_N'
    assert abs(e(r2) - `ref_r2') < `tolerance'

    display "Reference test case 1: PASSED"
end
```

---

## Testing Edge Cases

### Comprehensive Edge Case Testing

```stata
/*****************************************************************************
* test_edge_cases.do
* Test boundary conditions and unusual inputs
*****************************************************************************/

* Test 1: Empty dataset
program define test_empty_dataset
    clear
    set obs 0

    capture mycommand y x
    assert _rc != 0  // Should error gracefully

    * Check error message is informative
    * (manual verification)
end

* Test 2: Single observation
program define test_single_obs
    clear
    set obs 1
    generate x = 5
    generate y = 10

    capture mycommand y x
    assert _rc != 0  // Insufficient data
end

* Test 3: Two observations
program define test_two_obs
    clear
    set obs 2
    generate x = rnormal()
    generate y = rnormal()

    capture mycommand y x
    * May or may not work depending on command
    * Document expected behavior
end

* Test 4: All missing values
program define test_all_missing
    clear
    set obs 100
    generate x = .
    generate y = .

    capture mycommand y x
    assert _rc != 0
end

* Test 5: Partially missing
program define test_partial_missing
    clear
    set obs 100
    generate x = rnormal()
    generate y = rnormal()

    replace x = . in 1/50
    replace y = . in 51/100

    capture mycommand y x
    * Should work with no complete cases, or error
    * Test expected behavior
end

* Test 6: Perfect correlation
program define test_perfect_correlation
    clear
    set obs 100
    generate x = _n
    generate y = 2*x  // Perfect correlation

    mycommand y x
    assert abs(e(r2) - 1) < 1e-10
end

* Test 7: Zero variance
program define test_zero_variance
    clear
    set obs 100
    generate x = 5  // Constant
    generate y = rnormal()

    capture mycommand y x
    assert _rc != 0  // Should error
end

* Test 8: Extreme values
program define test_extreme_values
    clear
    set obs 100
    generate x = rnormal()
    generate y = rnormal()

    * Add extreme outliers
    replace y = 1e10 in 1
    replace x = -1e10 in 2

    * Should handle gracefully or warn
    capture noisily mycommand y x
    * Verify it completes or errors appropriately
end

* Test 9: Very large dataset
program define test_large_dataset
    clear
    set obs 10000000  // 10 million
    set seed 123

    generate x = rnormal()
    generate y = 2*x + rnormal()

    * Should complete in reasonable time
    timer clear 1
    timer on 1
    mycommand y x
    timer off 1

    quietly timer list 1
    local time = r(t1)
    assert `time' < 60  // Should complete in under 1 minute
end

* Test 10: Very wide dataset
program define test_wide_dataset
    clear
    set obs 100
    set seed 123

    generate y = rnormal()

    forvalues i = 1/1000 {
        quietly generate x`i' = rnormal()
    }

    * Test with many regressors
    mycommand y x1-x1000
    assert e(df_m) == 1000
end

* Test 11: Special characters in variable names
program define test_special_names
    clear
    set obs 100

    generate var_with_underscore = rnormal()
    generate var123 = rnormal()
    generate y = rnormal()

    mycommand y var_with_underscore var123
    * Should handle variable names correctly
end

* Test 12: Unicode in variable labels
program define test_unicode
    clear
    set obs 100
    generate x = rnormal()
    generate y = rnormal()

    label variable x "Covariate with unicode: α β γ"
    label variable y "Outcome: µ ± σ"

    mycommand y x
    * Should not crash on unicode
end
```

---

## Data Validation and Quality Checks

### Assertive Data Validation

```stata
/*****************************************************************************
* validate_data.do
* Comprehensive data validation
*****************************************************************************/

program define validate_analysis_data
    syntax [varlist] [, Strict]

    display as text _n "Validating dataset..."

    local errors = 0

    * Check 1: No completely empty observations
    quietly egen nmiss = rowmiss(`varlist')
    quietly count if nmiss == `:word count `varlist''
    if r(N) > 0 {
        display as error "Warning: `r(N)' observations have all missing values"
        local ++errors
    }
    drop nmiss

    * Check 2: Reasonable sample size
    quietly count
    if r(N) < 30 {
        display as error "Warning: Sample size (`r(N)') is small"
        if "`strict'" != "" {
            error 2001
        }
        local ++errors
    }

    * Check 3: Check for duplicates in ID variable
    capture confirm variable id
    if !_rc {
        quietly duplicates report id
        if r(unique_value) != r(N) {
            display as error "Error: Duplicate IDs found"
            local ++errors
        }
    }

    * Check 4: Verify numeric variables are actually numeric
    foreach var of varlist `varlist' {
        capture confirm numeric variable `var'
        if _rc {
            display as error "Error: `var' is not numeric"
            local ++errors
        }
    }

    * Check 5: Check for infinite values
    foreach var of varlist `varlist' {
        quietly count if `var' == . | `var' >= . | `var' <= .
        if r(N) > 0 {
            display as error "Warning: `var' has infinite or special missing values"
            local ++errors
        }
    }

    * Check 6: Check for extreme outliers (> 5 SD from mean)
    foreach var of varlist `varlist' {
        quietly summarize `var'
        local mean = r(mean)
        local sd = r(sd)
        quietly count if abs(`var' - `mean') > 5*`sd' & !missing(`var')
        if r(N) > 0 {
            display as text "Note: `var' has `r(N)' extreme outliers (>5 SD)"
        }
    }

    * Summary
    if `errors' == 0 {
        display as result _n "Data validation PASSED"
        return scalar valid = 1
    }
    else {
        display as error _n "Data validation found `errors' issues"
        if "`strict'" != "" {
            error 459
        }
        return scalar valid = 0
    }

    return scalar errors = `errors'
end
```

### Automated Quality Checks

```stata
program define quality_checks
    syntax varlist [if] [in]

    marksample touse

    * Generate report
    display as text _n "{hline 60}"
    display as text "Data Quality Report"
    display as text "{hline 60}"

    foreach var of varlist `varlist' {
        display as text _n "Variable: `var'"

        * Missing data
        quietly count if missing(`var') & `touse'
        local nmiss = r(N)
        quietly count if `touse'
        local ntotal = r(N)
        local pct_miss = (`nmiss'/`ntotal')*100

        display as text "  Missing: `nmiss' / `ntotal' (" %3.1f `pct_miss' "%)"

        * Check if numeric
        capture confirm numeric variable `var'
        if !_rc {
            * Numeric variable
            quietly summarize `var' if `touse', detail

            display as text "  Mean: " as result %9.2f r(mean)
            display as text "  SD: " as result %9.2f r(sd)
            display as text "  Min: " as result %9.2f r(min)
            display as text "  Max: " as result %9.2f r(max)
            display as text "  Skewness: " as result %9.2f r(skewness)
            display as text "  Kurtosis: " as result %9.2f r(kurtosis)

            * Flag potential issues
            if r(skewness) > 3 | r(skewness) < -3 {
                display as error "  WARNING: High skewness"
            }
            if r(kurtosis) > 10 {
                display as error "  WARNING: High kurtosis (heavy tails)"
            }
        }
        else {
            * String variable
            quietly tab `var' if `touse'
            display as text "  Unique values: " as result r(r)
        }
    }

    display as text "{hline 60}"
end
```

---

## Testing Estimation Commands

### Test Framework for Estimation

```stata
/*****************************************************************************
* Test estimation command thoroughly
*****************************************************************************/

program define test_estimation_command

    * Test 1: Basic estimation
    display _n "Test 1: Basic estimation"
    clear
    sysuse auto

    myregress price mpg weight

    * Verify estimation results exist
    assert "`e(cmd)'" == "myregress"
    assert e(N) == 74
    assert e(df_m) > 0
    assert e(df_r) > 0

    * Verify coefficients exist
    matrix b = e(b)
    assert colsof(b) > 0

    * Verify variance-covariance matrix
    matrix V = e(V)
    assert rowsof(V) == colsof(b)
    assert colsof(V) == colsof(b)

    display "  PASSED"

    * Test 2: predict works
    display _n "Test 2: predict"

    predict yhat
    assert !missing(yhat)

    predict resid, residuals
    assert !missing(resid)

    * Verify residuals sum to approximately 0
    quietly summarize resid
    assert abs(r(mean)) < 1e-10

    display "  PASSED"

    * Test 3: test command works
    display _n "Test 3: test command"

    myregress price mpg weight
    test mpg = weight
    assert r(p) != .

    display "  PASSED"

    * Test 4: estimates store/restore
    display _n "Test 4: estimates store"

    myregress price mpg weight
    estimates store model1

    myregress price mpg weight foreign
    estimates store model2

    estimates restore model1
    assert e(df_m) == 2

    estimates restore model2
    assert e(df_m) == 3

    display "  PASSED"

    * Test 5: lincom works
    display _n "Test 5: lincom"

    myregress price mpg weight
    lincom mpg + weight
    assert r(estimate) != .
    assert r(se) != .

    display "  PASSED"

    * Test 6: margins works (if applicable)
    display _n "Test 6: margins"

    capture margins, at(mpg=(20 30))
    if _rc == 0 {
        display "  PASSED"
    }
    else {
        display "  SKIPPED (margins not supported)"
    }
end
```

### Testing Numerical Accuracy

```stata
program define test_numerical_accuracy

    * Test against known analytical solution
    display _n "Testing numerical accuracy..."

    clear
    set obs 1000
    set seed 123456

    * Generate data with known parameters
    generate x1 = rnormal()
    generate x2 = rnormal()
    generate y = 3 + 2*x1 - 1.5*x2 + rnormal(0, 0.5)

    * Estimate
    myregress y x1 x2

    * Check coefficients are close to truth
    local tol = 0.1  // Generous tolerance for random data

    assert abs(_b[x1] - 2) < `tol'
    assert abs(_b[x2] - (-1.5)) < `tol'
    assert abs(_b[_cons] - 3) < `tol'

    * Compare to Stata's official regress
    quietly regress y x1 x2
    local official_b1 = _b[x1]
    local official_se1 = _se[x1]

    quietly myregress y x1 x2
    local my_b1 = _b[x1]
    local my_se1 = _se[x1]

    * Should match exactly (or very close)
    assert abs(`my_b1' - `official_b1') < 1e-8
    assert abs(`my_se1' - `official_se1') < 1e-8

    display "  Numerical accuracy: PASSED"
end
```

---

## Automated Testing Workflows

### Make-style Test Automation

```stata
/*****************************************************************************
* run_all_tests.do
* Automated test runner
*****************************************************************************/

clear all
set more off
capture log close

* Configuration
local test_dir "tests"
local log_dir "test_logs"

* Create log directory if needed
capture mkdir "`log_dir'"

* Initialize
global all_tests_passed = 1
global total_tests = 0
global failed_tests = 0

* Helper: Run test file and log
program define run_test_file
    args filepath

    global total_tests = ${total_tests} + 1

    * Extract filename
    local filename: subinstr local filepath ".do" ""
    local filename: subinstr local filename "`test_dir'/" ""

    display _n as text "{hline 70}"
    display as text "Running: `filepath'"
    display as text "{hline 70}"

    * Run with logging
    log using "`log_dir'/`filename'.log", replace text

    capture noisily do "`filepath'"
    local rc = _rc

    log close

    * Report result
    if `rc' {
        display as error "{hline 70}"
        display as error "`filepath': FAILED (return code `rc')"
        display as error "{hline 70}"
        global all_tests_passed = 0
        global failed_tests = ${failed_tests} + 1
    }
    else {
        display as result "{hline 70}"
        display as result "`filepath': PASSED"
        display as result "{hline 70}"
    }
end

* Find and run all test files
local test_files: dir "`test_dir'" files "test_*.do"

foreach file of local test_files {
    run_test_file "`test_dir'/`file'"
}

* Final summary
display _n as text "========================================================================"
display as text "TEST SUMMARY"
display as text "========================================================================"
display as text "Total test files: " as result ${total_tests}
display as text "Passed: " as result ${total_tests} - ${failed_tests}
display as text "Failed: " as error ${failed_tests}

if ${all_tests_passed} {
    display as result _n "ALL TESTS PASSED"
    exit 0
}
else {
    display as error _n "SOME TESTS FAILED"
    display as error "See logs in: `log_dir'/"
    exit 9
}
```

### Pre-commit Hook

Create `.git/hooks/pre-commit`:

```bash
#!/bin/bash
# Run Stata tests before allowing commit

echo "Running Stata tests..."

stata-mp -b do run_all_tests.do

if [ $? -eq 0 ]; then
    echo "Tests passed. Proceeding with commit."
    exit 0
else
    echo "Tests failed. Commit aborted."
    echo "Fix failing tests or use git commit --no-verify to bypass."
    exit 1
fi
```

---

## Continuous Integration

### GitHub Actions Example

Create `.github/workflows/stata-tests.yml`:

```yaml
name: Stata Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest

    steps:
    - uses: actions/checkout@v2

    - name: Setup Stata
      uses: stata/setup-stata@v1
      with:
        stata-version: 18

    - name: Run tests
      run: stata-mp -b do run_all_tests.do

    - name: Upload test logs
      if: always()
      uses: actions/upload-artifact@v2
      with:
        name: test-logs
        path: test_logs/
```

---

## Performance Testing

### Benchmark Testing

```stata
/*****************************************************************************
* benchmark_tests.do
* Performance benchmarking
*****************************************************************************/

program define benchmark_command
    args n_obs

    clear
    set obs `n_obs'
    set seed 12345

    generate x = rnormal()
    generate y = 2*x + rnormal()

    * Time the command
    timer clear 1
    timer on 1
    quietly mycommand y x
    timer off 1

    quietly timer list 1
    local time = r(t1)

    display "N = " %12.0fc `n_obs' "  Time = " %8.3f `time' " seconds"

    return scalar time = `time'
    return scalar n_obs = `n_obs'
end

* Run benchmarks
display _n "Performance Benchmarks"
display "{hline 40}"

benchmark_command 100
benchmark_command 1000
benchmark_command 10000
benchmark_command 100000
benchmark_command 1000000

* Test for linear scaling
* (Time should scale approximately linearly with N for most commands)
```

### Memory Usage Testing

```stata
program define test_memory_usage

    display _n "Memory usage test"

    * Record initial memory
    memory
    local mem_initial = r(data_data_u)

    * Create large dataset
    clear
    set obs 1000000
    set seed 999

    forvalues i = 1/100 {
        quietly generate x`i' = rnormal()
    }

    memory
    local mem_before = r(data_data_u)

    * Run command
    generate y = rnormal()
    mycommand y x1-x100

    memory
    local mem_after = r(data_data_u)

    local mem_increase = `mem_after' - `mem_before'

    display "Memory increase: " `mem_increase' " bytes"

    * Should not have excessive memory growth
    * (Define threshold based on expected usage)
    local threshold = 100000000  // 100 MB
    assert `mem_increase' < `threshold'

    display "Memory usage: PASSED"
end
```

---

## Documentation Testing

### Test Examples in Help File

```stata
/*****************************************************************************
* test_help_examples.do
* Run all examples from help file to verify they work
*****************************************************************************/

program define test_help_examples

    display _n "Testing examples from help file..."

    * Example 1: Setup
    display _n "Example 1: Setup"
    sysuse auto
    describe
    assert _N == 74

    * Example 2: Basic usage
    display _n "Example 2: Basic usage"
    mycommand price mpg weight
    assert e(N) == 74

    * Example 3: With if condition
    display _n "Example 3: With if condition"
    mycommand price mpg weight if foreign == 1
    assert e(N) == 22

    * Example 4: With options
    display _n "Example 4: With options"
    mycommand price mpg weight, detail level(90)
    assert e(level) == 90

    display _n "All help file examples: PASSED"
end
```

---

## Final Testing Checklist

Before releasing code, verify:

- [ ] All unit tests pass
- [ ] Integration tests pass
- [ ] Certification script runs clean
- [ ] Edge cases tested
- [ ] Error handling tested
- [ ] Help file examples tested and work
- [ ] Performance acceptable on large datasets
- [ ] Memory usage reasonable
- [ ] Works with if/in
- [ ] Works with weights
- [ ] Works with missing values
- [ ] Works with by:
- [ ] Compatible with estimate commands (estimates store, etc.)
- [ ] Regression tests pass (results unchanged from previous version)
- [ ] Cross-platform tested (if applicable)
- [ ] Different Stata versions tested (if targeting multiple versions)

---

**End of Testing Best Practices Guide**

Remember: Testing is not optional. It's an essential part of professional software development. Good tests give you confidence to make changes, catch bugs early, and document expected behavior. Invest time in testing—your future self (and your users) will thank you.
