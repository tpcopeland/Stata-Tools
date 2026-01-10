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
| Location: `_testing/test_*.do` | Location: `_validation/validation_*.do` |

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

* Maximum value
replace x = c(maxdouble)
mycommand x
assert r(result) != .
```

---

## Quick Start

### Create Validation File

1. Copy template: `cp _templates/validation_TEMPLATE.do _validation/validation_mycommand.do`
2. Replace all `TEMPLATE` with `mycommand`
3. Create validation datasets with known expected values
4. Write assertions comparing actual to expected

---

## Validation File Structure

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

### 4. Invariant Tests
```stata
* Idempotency (running twice gives same result)
mycommand x, generate(result1)
mycommand result1, generate(result2)
assert result1 == result2

* Monotonicity (larger inputs give larger outputs)
sort x
gen is_monotonic = (result >= result[_n-1]) if _n > 1
count if is_monotonic == 0
assert r(N) == 0
```

### 5. Comparison Tests
```stata
* Compare to known-good method
mycommand x
local result1 = r(mean)

sum x
local result2 = r(mean)

assert abs(`result1' - `result2') < 0.001
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

## Helper Program for Comparisons

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

---

## Date Reference Values (2020 Leap Year)

| Date | Stata Value | Notes |
|------|-------------|-------|
| Jan 1, 2020 | 21915 | Year start |
| Mar 1, 2020 | 21975 | After Feb (leap) |
| Jun 30, 2020 | 22097 | Mid-year |
| Jul 1, 2020 | 22098 | Second half |
| Dec 31, 2020 | 22280 | Year end |
| Jan 1, 2021 | 22281 | Next year |

Days in 2020: 366 (leap year)

---

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

---

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

---

## Checklist for Validation Files

- [ ] File named `validation_COMMANDNAME.do`
- [ ] Configuration block for runner globals
- [ ] Path configuration for all platforms
- [ ] Creates validation datasets with **known values**
- [ ] Each test documents expected answer
- [ ] Uses appropriate tolerance for floats
- [ ] Includes invariant tests
- [ ] Includes boundary condition tests
- [ ] Display respects quiet mode
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

*Template location: `_templates/validation_TEMPLATE.do`*
*Full validation guide: `_guides/validating.md`*
