---
name: stata-validate
description: Stata Validation Testing - verifying commands produce mathematically correct results
allowed-tools:
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - Bash
# NOTE: Task tool is NOT allowed - do NOT use subagents
---

# Stata Validation Testing

Use this when writing validation tests that verify commands produce mathematically correct results, not just that they run.

---

## Testing vs Validation

| Testing (Use /stata-test) | Validation (This Skill) |
|--------------------------|------------------------|
| Does the command **run** without errors? | Does it produce **correct** results? |
| Uses realistic datasets | Uses minimal hand-crafted datasets |
| Checks return codes, variable existence | Checks specific computed values |
| Location: `_devkit/_testing/test_*.do` | Location: `_devkit/_validation/validation_*.do` |

---

## Core Validation Principles

### 1. Known-Answer Testing
Create minimal datasets where you can calculate expected results by hand:

```stata
clear
input long id double x double y
    1 10 100
    2 20 200
    3 30 300
end

* Expected: mean of x = 20 (hand-calculated)
mycommand x, stat(mean)
assert abs(r(result) - 20) < 0.001
```

### 2. Invariant Testing
Properties that must ALWAYS hold regardless of input:

```stata
* Proportion must be between 0 and 1
assert r(proportion) >= 0 & r(proportion) <= 1

* Output count should match input count
assert r(N) == _N

* No overlapping intervals
sort id start
by id: assert start >= stop[_n-1] if _n > 1
```

### 3. Boundary Condition Testing
Test at exact edges:

```stata
* Event at interval boundary
gen date = mdy(1,1,2020)  // Exact start
mycommand date
* Verify boundary handling

* Zero value
gen x = 0
mycommand x
assert r(result) == 0
```

---

## Quick Start

### Create Validation File

1. Copy template: `cp _devkit/_templates/validation_TEMPLATE.do _devkit/_validation/validation_mycommand.do`
2. Replace all `TEMPLATE` with `mycommand`
3. Create validation datasets with known expected values
4. Write assertions comparing actual to expected

---

## Required Validation Categories

### 1. Known-Answer Tests
```stata
* Data: x = 1, 2, 3, 4, 5
* Known: mean = 3.0, variance = 2.5, sum = 15

mycommand x
assert abs(r(mean) - 3.0) < 0.001
assert abs(r(variance) - 2.5) < 0.001
assert abs(r(sum) - 15) < 0.001
```

### 2. Boundary Tests
```stata
* Zero input
assert result == 0 when x == 0

* Negative input
assert result == -5 when x = -10, y = 2

* Missing propagation
assert missing(result) when missing(x)
```

### 3. Conservation Tests
```stata
* Person-time conservation
gen input_ptime = exit - entry
sum input_ptime
local expected = r(sum)

mycommand ...

gen output_ptime = stop - start
sum output_ptime
assert abs(r(sum) - `expected') < 0.001
```

### 4. Row-Level Validation (CRITICAL)
**Always verify row-level calculations, not just aggregates:**

```stata
* BAD: Only checks aggregate - bug can hide!
quietly sum time_var
assert abs(r(mean) - 136) < 2  // Could pass with wrong values

* GOOD: Verify row-by-row
gen double expected_time = stop - first_start  // Calculate expected
gen byte match = abs(time_var - expected_time) < 0.001
quietly count if match == 0
assert r(N) == 0  // Fails immediately if ANY row is wrong
```

### 5. Multi-Observation Testing (CRITICAL)
**Test with multi-observation per person data:**

```stata
* Create multi-interval test data
clear
input long id double(start stop)
    1  21915  22000   // Person 1, interval 1: 85 days
    1  22000  22100   // Person 1, interval 2: 100 days
    1  22100  22200   // Person 1, interval 3: 100 days
    2  21915  22050   // Person 2, interval 1: 135 days
    2  22050  22200   // Person 2, interval 2: 150 days
end

* Test command
mycommand ...

* Verify each person has DIFFERENT values across their intervals
bysort id: gen byte same_value = (result == result[1])
by id: egen all_same = min(same_value)
* For cumulative time, later intervals should have larger values
quietly count if all_same == 1
assert r(N) < _N  // Not all same!
```

---

## Floating Point Comparisons

**NEVER use exact equality for floats:**

```stata
// WRONG
assert r(mean) == 3.14159

// CORRECT - use tolerance
assert abs(r(mean) - 3.14159) < 0.0001
```

### Suggested Tolerances

| Calculation Type | Tolerance |
|-----------------|-----------|
| Exact counts | 0 (use ==) |
| Date differences | 1 day |
| Proportions | 0.001 |
| Means/SDs | 0.001 |
| Cumulative values | 0.01 |
| Pro-rated values | 0.1 |

---

## Checklist for Validation Files

- [ ] File named `validation_COMMANDNAME.do`
- [ ] Creates validation datasets with **known values**
- [ ] Each test documents expected answer
- [ ] Uses appropriate tolerance for floats
- [ ] Includes boundary condition tests
- [ ] **Uses multi-observation per person test data** (CRITICAL)
- [ ] **Validates row-level calculations, not just aggregates** (CRITICAL)
- [ ] Summary section with exit code
- [ ] Cleans up temporary datasets

---

## Delegation to Other Skills

```
USE stata-test skill WHEN:
- Writing functional tests (does it run?)
- Testing error handling

USE code-reviewer skill WHEN:
- Reviewing validation test quality
- Checking test coverage

USE package-tester skill WHEN:
- Running validation tests
- Checking results
```

---

*Template location: `_devkit/_templates/validation_TEMPLATE.do`*

<!-- LAZY_START: complete_examples -->
## Complete Validation Examples

### Example 1: Statistical Command Validation

```stata
/*******************************************************************************
* validation_mystat.do
* Validates mystat command produces correct statistical results
*******************************************************************************/

clear all
set more off
version 16.0

* Test counters
local test_count = 0
local pass_count = 0
local fail_count = 0

* ===========================================================================
* TEST 1: Mean calculation with known values
* ===========================================================================
local ++test_count

clear
input double x
    1
    2
    3
    4
    5
end

* Hand-calculated: mean = 15/5 = 3.0, variance = 2.5
capture {
    mystat x
    assert abs(r(mean) - 3.0) < 0.0001
    assert abs(r(variance) - 2.5) < 0.0001
    assert r(N) == 5
}
if _rc == 0 {
    display as result "  PASS: Mean and variance calculation"
    local ++pass_count
}
else {
    display as error "  FAIL: Mean and variance calculation"
    local ++fail_count
}

* ===========================================================================
* TEST 2: Weighted mean
* ===========================================================================
local ++test_count

clear
input double x double w
    10  1
    20  2
    30  1
end

* Hand-calculated: weighted mean = (10*1 + 20*2 + 30*1) / (1+2+1) = 80/4 = 20
capture {
    mystat x [aw=w]
    assert abs(r(mean) - 20.0) < 0.0001
}
if _rc == 0 {
    display as result "  PASS: Weighted mean calculation"
    local ++pass_count
}
else {
    display as error "  FAIL: Weighted mean calculation"
    local ++fail_count
}

* ===========================================================================
* SUMMARY
* ===========================================================================
display _dup(60) "="
display "VALIDATION SUMMARY"
display _dup(60) "="
display "Tests run:    `test_count'"
display "Passed:       `pass_count'"
display "Failed:       `fail_count'"
display _dup(60) "="

if `fail_count' > 0 {
    display as error "VALIDATION FAILED"
    exit 1
}
else {
    display as result "ALL VALIDATIONS PASSED"
}
```

### Example 2: Time-Varying Exposure Validation

```stata
/*******************************************************************************
* validation_tvexpose.do
* Validates tvexpose produces correct time-varying exposure intervals
*******************************************************************************/

clear all
set more off
version 16.0

* ===========================================================================
* TEST: Person-time conservation
* ===========================================================================

* Create minimal cohort
clear
input long id double(entry exit)
    1  21915  22280  // Person 1: 365 days
    2  21915  22100  // Person 2: 185 days
end
save "val_cohort.dta", replace

* Create exposure periods
clear
input long id double(start stop) byte exposure
    1  21915  22000  1  // Person 1: exposed days 1-85
    1  22000  22280  0  // Person 1: unexposed days 86-365
    2  21915  22100  1  // Person 2: exposed entire period
end
save "val_exposure.dta", replace

* Run command
use "val_cohort.dta", clear
tvexpose using "val_exposure.dta", id(id) start(start) stop(stop) ///
    exposure(exposure) reference(0) entry(entry) exit(exit)

* VALIDATION: Total person-time must equal input
* Person 1: 365 days, Person 2: 185 days = 550 total
gen ptime = stop - start
quietly sum ptime
assert abs(r(sum) - 550) < 1

* VALIDATION: Row-level check for Person 1
* Should have 2 intervals: 85 days exposed, 280 days unexposed
quietly count if id == 1
assert r(N) == 2

sort id start
gen expected_ptime = cond(id==1 & _n==1, 85, ///
                     cond(id==1 & _n==2, 280, ///
                     cond(id==2, 185, .)))

gen match = abs(ptime - expected_ptime) < 1
quietly count if match == 0
assert r(N) == 0

display as result "PASS: Time-varying exposure validation"

* Cleanup
erase "val_cohort.dta"
erase "val_exposure.dta"
```
<!-- LAZY_END: complete_examples -->

<!-- LAZY_START: file_structure -->
## Validation File Structure Template

```stata
/*******************************************************************************
* validation_mycommand.do
*
* Purpose: Deep validation tests using known-answer testing.
*          Verifies computed values match expected results.
*******************************************************************************/

clear all
set more off
version 16.0

* Configuration
if "$RUN_TEST_QUIET" == "" global RUN_TEST_QUIET = 0
local quiet = $RUN_TEST_QUIET

* Path configuration - CUSTOMIZE THESE PATHS FOR YOUR SYSTEM
* Option 1: Set environment variable STATA_TOOLS_PATH before running Stata
* Option 2: Modify the paths below for your system
if "`c(STATA_TOOLS_PATH)'" != "" {
    global STATA_TOOLS_PATH "`c(STATA_TOOLS_PATH)'"
}
else if "`c(os)'" == "MacOSX" {
    global STATA_TOOLS_PATH "~/Documents/GitHub/Stata-Tools"  // Customize this
}
else if "`c(os)'" == "Unix" {
    global STATA_TOOLS_PATH "~/Stata-Tools"  // Customize this
}
else {
    global STATA_TOOLS_PATH "`c(pwd)'"  // Fallback to current directory
}

global VALIDATION_DIR "${STATA_TOOLS_PATH}/_validation"
global DATA_DIR "${VALIDATION_DIR}/data"

* Test counters
local test_count = 0
local pass_count = 0
local fail_count = 0

* CREATE VALIDATION DATA with known values
clear
input long id double x double expected
    1 10 100    // 10^2 = 100
    2 20 400    // 20^2 = 400
    3 30 900    // 30^2 = 900
end
save "${DATA_DIR}/val_squares.dta", replace

* Test 1.1: Known square calculation
local ++test_count
capture {
    use "${DATA_DIR}/val_squares.dta", clear
    mycommand x, operation(square) generate(result)

    * Verify each value
    forvalues i = 1/3 {
        local actual = result[`i']
        local expect = expected[`i']
        assert abs(`actual' - `expect') < 0.001
    }
}
if _rc == 0 {
    display as result "  PASS: Square calculation correct"
    local ++pass_count
}
else {
    display as error "  FAIL: Square calculation"
    local ++fail_count
}

* Summary
if `fail_count' > 0 exit 1
```
<!-- LAZY_END: file_structure -->

<!-- LAZY_START: date_reference -->
## Date Reference Values

### 2020 Leap Year Reference

| Date | Stata Value | Notes |
|------|-------------|-------|
| Jan 1, 2020 | 21915 | Year start |
| Feb 29, 2020 | 21974 | Leap day |
| Mar 1, 2020 | 21975 | After Feb (leap) |
| Jun 30, 2020 | 22097 | Mid-year |
| Jul 1, 2020 | 22098 | Second half |
| Dec 31, 2020 | 22280 | Year end |
| Jan 1, 2021 | 22281 | Next year |

Days in 2020: 366 (leap year)

### Common Date Calculations

```stata
* Days between dates
local days = date2 - date1

* Years between dates (approximate)
local years = (date2 - date1) / 365.25

* Add 30 days to a date
local new_date = `old_date' + 30

* First day of month containing date
local first = mdy(month(`date'), 1, year(`date'))
```

### Date Validation Patterns

```stata
* Verify date is valid
assert !missing(mydate)
assert mydate >= mdy(1,1,1900) & mydate <= mdy(12,31,2100)

* Verify dates are ordered
assert start_date <= end_date

* Verify no future dates
assert event_date <= date("$S_DATE", "DMY")
```
<!-- LAZY_END: date_reference -->

<!-- LAZY_START: mental_execution -->
## Mental Execution (Without Stata)

When you can't run Stata, trace through code mentally:

```
MENTAL EXECUTION TRACE
----------------------
Command: mycommand price mpg, option(value)

Step 1: syntax varlist, Option(string)
  - varlist = "price mpg"
  - option = "value"

Step 2: marksample touse
  - touse marks valid obs

Step 3: quietly count if `touse'
  - Assume 74 obs (sysuse auto)
  - r(N) = 74, passes check

Step 4: foreach v of varlist `varlist' {
  - Iteration 1: v = "price"
  - Iteration 2: v = "mpg"

RESULT: Execution completes successfully
```

### Mental Execution Checklist

1. **Parse syntax** - What values do local macros hold?
2. **Check marksample** - What observations are marked?
3. **Trace loops** - What happens in each iteration?
4. **Verify conditions** - Do if/else branches go the right way?
5. **Check returns** - What values are stored?

### Common Mental Execution Errors

- Forgetting backticks in macro references
- Miscounting loop iterations
- Confusing scalar vs macro values
- Missing the effect of `quietly`
<!-- LAZY_END: mental_execution -->

<!-- LAZY_START: helper_programs -->
## Helper Programs for Validation

### Floating Point Comparison Helper

```stata
capture program drop _assert_equal
program define _assert_equal
    args actual expected tolerance
    if "`tolerance'" == "" local tolerance = 0.0001
    local diff = abs(`actual' - `expected')
    if `diff' > `tolerance' {
        display as error "Expected: `expected', Got: `actual' (diff: `diff')"
        exit 9
    }
end

* Usage
_assert_equal `result' 3.14159 0.001
```

### Row-by-Row Validation Helper

```stata
capture program drop _validate_rows
program define _validate_rows
    syntax varname, expected(string) [tolerance(real 0.0001)]

    local values `expected'
    local row = 1
    foreach val of local values {
        local actual = `varlist'[`row']
        if abs(`actual' - `val') > `tolerance' {
            display as error "Row `row': expected `val', got `actual'"
            exit 9
        }
        local ++row
    }
    display as result "All `=`row'-1' rows validated"
end

* Usage
_validate_rows result, expected(100 400 900)
```

### Test Counter Helper

```stata
capture program drop _test_result
program define _test_result
    args passed test_name pass_count fail_count

    if `passed' {
        display as result "  PASS: `test_name'"
        c_local `pass_count' = ``pass_count'' + 1
    }
    else {
        display as error "  FAIL: `test_name'"
        c_local `fail_count' = ``fail_count'' + 1
    }
end

* Usage in test file
capture noisily {
    mycommand x
    assert r(N) > 0
}
_test_result `=_rc==0' "Basic functionality" pass_count fail_count
```
<!-- LAZY_END: helper_programs -->

<!-- LAZY_START: checklist_by_type -->
## Validation Checklist by Command Type

### Data Transformation Commands
- [ ] Total person-time conserved
- [ ] No overlapping intervals
- [ ] All input IDs in output
- [ ] No gaps (unless expected)
- [ ] Date formats preserved

### Statistical Commands
- [ ] Results match hand calculations
- [ ] Results within valid ranges
- [ ] Observation counts correct
- [ ] Missing values handled

### Date Commands
- [ ] Correct parsing for all formats
- [ ] Leap years handled
- [ ] Month/year boundaries correct
- [ ] Invalid dates produce errors

### Table Commands
- [ ] Row counts match data
- [ ] Column sums correct
- [ ] Percentages sum to 100
- [ ] Missing category handled

### Merge Commands
- [ ] All source records accounted for
- [ ] No duplicate keys introduced
- [ ] Variables correctly populated
- [ ] Merge indicator accurate
<!-- LAZY_END: checklist_by_type -->
