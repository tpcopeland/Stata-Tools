# Guide: Validating Stata Commands

**Purpose**: How to write deep validation tests that verify Stata commands produce mathematically correct results.

---

## Testing vs Validation

| Testing | Validation |
|---------|------------|
| Does the command **run** without errors? | Does the command produce **correct** results? |
| Focus: **Execution** | Focus: **Correctness** |
| Uses: Realistic datasets | Uses: Minimal hand-crafted datasets |
| Checks: Return codes, variable existence | Checks: Specific computed values |

---

## Core Validation Principles

### 1. Known-Answer Testing

Create minimal datasets where you can calculate expected results by hand:

```stata
* Input: Person with known exposure
clear
input long id double(start stop) byte exposed
    1 21915 22281 1  // Jan 1 - Dec 31, 2020 (366 days, leap year)
end

* Expected output: 366 days of person-time
mycommand ...
gen ptime = stop - start
sum ptime
assert abs(r(sum) - 366) < 0.001  // Known answer
```

### 2. Invariant Testing

Properties that must **always** hold regardless of input:

```stata
* Invariant: All intervals must have start < stop
assert stop > start if !missing(start) & !missing(stop)

* Invariant: No overlapping intervals within a person
sort id start
by id: gen overlap = (start < stop[_n-1]) if _n > 1
count if overlap == 1
assert r(N) == 0

* Invariant: Person-time must be conserved
assert abs(total_output_ptime - total_input_ptime) < 0.001
```

### 3. Boundary Condition Testing

Explicit tests for edge cases:

```stata
* Event exactly at interval boundaries
* Value at minimum/maximum allowed
* Zero-length intervals
* Single observation
* First/last observation handling
```

---

## Validation File Location and Naming

All validation files go in `_validation/`:

```
_validation/
├── validation_mycommand.do    # Validation for mycommand
├── validation_anothercommand.do
└── data/                      # Validation-specific datasets
```

Naming convention: `validation_COMMANDNAME.do`

---

## Validation File Structure

### Standard Template

```stata
/*******************************************************************************
* validation_mycommand.do
*
* Purpose: Deep validation tests for mycommand using known-answer testing
*          These tests verify mathematical correctness, not just execution.
*
* Philosophy: Create minimal datasets where every output value can be
*             mathematically verified by hand.
*
* Run modes:
*   Standalone: do validation_mycommand.do
*   Via runner: do run_test.do validation_mycommand [testnumber] [quiet] [machine]
*
* Author: Your Name
* Date: 2025-01-15
*******************************************************************************/

clear all
set more off
version 16.0

* =============================================================================
* CONFIGURATION
* =============================================================================
if "$RUN_TEST_QUIET" == "" {
    global RUN_TEST_QUIET = 0
}
if "$RUN_TEST_MACHINE" == "" {
    global RUN_TEST_MACHINE = 0
}
if "$RUN_TEST_NUMBER" == "" {
    global RUN_TEST_NUMBER = 0
}

local quiet = $RUN_TEST_QUIET
local machine = $RUN_TEST_MACHINE
local run_only = $RUN_TEST_NUMBER

* =============================================================================
* PATH CONFIGURATION
* =============================================================================
if "`c(os)'" == "MacOSX" {
    global STATA_TOOLS_PATH "/Users/tcopeland/Documents/GitHub/Stata-Tools"
}
else if "`c(os)'" == "Unix" {
    global STATA_TOOLS_PATH "/home/ubuntu/Stata-Tools"
}
else {
    capture confirm file "_validation"
    if _rc == 0 {
        global STATA_TOOLS_PATH "`c(pwd)'"
    }
    else {
        capture confirm file "data"
        if _rc == 0 {
            global STATA_TOOLS_PATH "`c(pwd)'/.."
        }
        else {
            global STATA_TOOLS_PATH "`c(pwd)'/../.."
        }
    }
}

global VALIDATION_DIR "${STATA_TOOLS_PATH}/_validation"
global DATA_DIR "${VALIDATION_DIR}/data"

capture mkdir "${DATA_DIR}"

* Install package
capture net uninstall mycommand
quietly net install mycommand, from("${STATA_TOOLS_PATH}/mycommand")

* =============================================================================
* HEADER
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "MYCOMMAND DEEP VALIDATION TESTS"
    display as text "{hline 70}"
    display as text "These tests verify mathematical correctness, not just execution."
    display as text "{hline 70}"
}

* =============================================================================
* TEST COUNTERS
* =============================================================================
local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

* =============================================================================
* CREATE VALIDATION DATASETS
* =============================================================================
if `quiet' == 0 {
    display as text _n "Creating validation datasets..."
}

* Dataset 1: Known values for basic calculation
clear
input long id double x double y
    1 10 100
    2 20 200
    3 30 300
end
label data "Simple 3-row dataset with known values"
save "${DATA_DIR}/val_basic.dta", replace

if `quiet' == 0 {
    display as result "Validation datasets created in: ${DATA_DIR}"
}

* =============================================================================
* SECTION 1: CORE CALCULATION TESTS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 1: Core Calculation Tests"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 1.1: Known Sum Calculation
* Purpose: Verify sum is calculated correctly
* Known answer: x sum = 10 + 20 + 30 = 60
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 1.1: Known Sum Calculation"
}

capture {
    use "${DATA_DIR}/val_basic.dta", clear
    mycommand x, stat(sum)

    * Known answer: 60
    assert abs(r(result) - 60) < 0.001
}
if _rc == 0 {
    display as result "  PASS: Sum calculation correct (60)"
    local ++pass_count
}
else {
    display as error "  FAIL: Sum calculation (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 1.1"
}

* -----------------------------------------------------------------------------
* Test 1.2: Known Mean Calculation
* Purpose: Verify mean is calculated correctly
* Known answer: x mean = (10 + 20 + 30) / 3 = 20
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 1.2: Known Mean Calculation"
}

capture {
    use "${DATA_DIR}/val_basic.dta", clear
    mycommand x, stat(mean)

    * Known answer: 20
    assert abs(r(result) - 20) < 0.001
}
if _rc == 0 {
    display as result "  PASS: Mean calculation correct (20)"
    local ++pass_count
}
else {
    display as error "  FAIL: Mean calculation (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 1.2"
}

* =============================================================================
* SECTION 2: INVARIANT TESTS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "INVARIANT TESTS: Universal Properties"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Invariant 1: Result should never be missing for non-missing input
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Invariant 1: No Missing Results"
}

capture {
    use "${DATA_DIR}/val_basic.dta", clear
    mycommand x, stat(mean)
    assert r(result) != .
}
if _rc == 0 {
    display as result "  PASS: Result is not missing"
    local ++pass_count
}
else {
    display as error "  FAIL: Result is missing"
    local ++fail_count
    local failed_tests "`failed_tests' Inv1"
}

* =============================================================================
* SUMMARY
* =============================================================================
display as text _n "{hline 70}"
display as text "MYCOMMAND VALIDATION SUMMARY"
display as text "{hline 70}"
display as text "Total tests:  `test_count'"
display as result "Passed:       `pass_count'"
if `fail_count' > 0 {
    display as error "Failed:       `fail_count'"
}
else {
    display as text "Failed:       `fail_count'"
}
display as text "{hline 70}"

if `fail_count' > 0 {
    display as error _n "FAILED TESTS:`failed_tests'"
    display as text "{hline 70}"
    display as error "Some validation tests FAILED."
    exit 1
}
else {
    display as result _n "ALL VALIDATION TESTS PASSED!"
}

display as text _n "Validation completed: `c(current_date)' `c(current_time)'"
display as text "{hline 70}"
```

---

## Validation Test Categories

### 1. Known-Answer Tests

Calculate expected results by hand:

```stata
* Create data with known properties
clear
input double x
    1
    2
    3
    4
    5
end

* Run command
mycommand x, stat(variance)

* Known answer: variance of 1,2,3,4,5 = 2.5
assert abs(r(variance) - 2.5) < 0.001
```

### 2. Invariant Tests

Properties that must always hold:

```stata
* Output count should match input count (for certain commands)
local input_n = _N
mycommand x
assert r(N) == `input_n'

* Values should be within expected bounds
assert r(proportion) >= 0 & r(proportion) <= 1

* Ordering should be preserved
sort id time
mycommand ...
assert time[_n] >= time[_n-1] if _n > 1
```

### 3. Boundary Condition Tests

Test at edges:

```stata
* Minimum value
clear
set obs 1
gen x = 0
mycommand x
assert r(result) == 0

* Maximum value
replace x = c(maxdouble)
mycommand x
assert r(result) != .

* Exact boundary
gen date = mdy(1,1,2020)  // Exact start
mycommand date
* Verify boundary handling
```

### 4. Conservation Tests

Verify quantities are preserved:

```stata
* Person-time conservation
gen input_ptime = exit - entry
sum input_ptime
local input_total = r(sum)

mycommand ...

gen output_ptime = stop - start
sum output_ptime
local output_total = r(sum)

assert abs(`output_total' - `input_total') < 0.001
```

### 5. Comparison Tests

Compare different methods that should give same result:

```stata
* Method 1: Use command
mycommand x
local result1 = r(mean)

* Method 2: Manual calculation
sum x
local result2 = r(mean)

* Should match
assert abs(`result1' - `result2') < 0.001
```

---

## Creating Validation Datasets

### Design Principles

1. **Minimal**: Use smallest dataset that tests the property
2. **Calculable**: Every output value can be computed by hand
3. **Documented**: Label data with what it tests
4. **Deterministic**: Same input always gives same output

### Example Datasets

```stata
* Dataset for testing date calculations
* Using Stata date values (days since Jan 1, 1960)
clear
input long id double(start stop)
    1 21915 22281  // Jan 1, 2020 to Dec 31, 2020 = 366 days (leap year)
    2 21915 22097  // Jan 1, 2020 to Jun 30, 2020 = 182 days
    3 22097 22281  // Jul 1, 2020 to Dec 31, 2020 = 184 days
end
format %td start stop
label data "Known date intervals for duration testing"

* Verify our known values
gen dur = stop - start
list id start stop dur
* id 1: 366 days (correct - leap year)
* id 2: 182 days (correct)
* id 3: 184 days (correct)
```

### Date Reference Table

Common Stata date values for 2020 (leap year):

| Date | Stata Value | Notes |
|------|-------------|-------|
| Jan 1, 2020 | 21915 | Year start |
| Mar 1, 2020 | 21975 | After Feb (leap) |
| Jun 30, 2020 | 22097 | Mid-year |
| Jul 1, 2020 | 22098 | Second half start |
| Dec 31, 2020 | 22280 | Year end (inclusive) |
| Jan 1, 2021 | 22281 | Next year (exclusive stop) |

---

## Writing Validation for Specific Command Types

### Statistical Commands

For commands that compute statistics:

```stata
* Known distribution
clear
input double x
    1
    2
    3
    4
    5
end

* Expected values (calculated by hand):
* Mean = 3.0
* Variance = 2.5
* SD = 1.581
* Min = 1
* Max = 5

mycommand x
assert abs(r(mean) - 3.0) < 0.001
assert abs(r(variance) - 2.5) < 0.001
```

### Transformation Commands

For commands that transform data:

```stata
* Before transformation
clear
input long id double(entry exit)
    1 21915 22281  // 366 days
end

* Expected: No person-time lost
gen input_ptime = exit - entry
sum input_ptime
local expected = r(sum)

mycommand ...

gen output_ptime = stop - start
sum output_ptime
assert abs(r(sum) - `expected') < 0.001
```

### Merge/Join Commands

For commands that combine data:

```stata
* Dataset A: ids 1, 2, 3
* Dataset B: ids 2, 3, 4
* Expected intersection: ids 2, 3

mymerge using A B
distinct id
assert r(ndistinct) == 2

* Verify specific IDs
count if id == 1
assert r(N) == 0  // Not in B
count if id == 4
assert r(N) == 0  // Not in A
```

### Date/Time Commands

For commands that manipulate dates:

```stata
* String date to Stata date
clear
input str10 datestr
    "2020-01-15"
end

datefix datestr
assert datestr == mdy(1, 15, 2020)  // Known value: 21929
```

---

## Tolerance and Precision

### Floating Point Comparisons

Never use exact equality for floating point:

```stata
* BAD: May fail due to floating point precision
assert r(mean) == 3.14159

* GOOD: Use tolerance
assert abs(r(mean) - 3.14159) < 0.0001
```

### Appropriate Tolerances

| Calculation Type | Suggested Tolerance |
|-----------------|---------------------|
| Exact counts | 0 (use ==) |
| Date differences | 1 day |
| Proportions | 0.001 |
| Means/SDs | 0.001 |
| Cumulative values | 0.01 |
| Pro-rated values | 0.1 |

---

## Helper Programs

### Verify No Overlapping Intervals

```stata
capture program drop _verify_no_overlap
program define _verify_no_overlap, rclass
    syntax, id(varname) start(varname) stop(varname)

    sort `id' `start' `stop'
    tempvar prev_stop overlap
    by `id': gen double `prev_stop' = `stop'[_n-1] if _n > 1
    by `id': gen byte `overlap' = (`start' < `prev_stop') if _n > 1
    quietly count if `overlap' == 1
    return scalar n_overlaps = r(N)
end
```

### Verify Person-Time Conservation

```stata
capture program drop _verify_ptime_conserved
program define _verify_ptime_conserved, rclass
    syntax, id(varname) start(varname) stop(varname) ///
            expected(real) [tolerance(real 0.001)]

    tempvar dur
    gen double `dur' = `stop' - `start'
    sum `dur'
    local actual = r(sum)
    local pct_diff = abs(`actual' - `expected') / `expected'
    return scalar pct_diff = `pct_diff'
    return scalar passed = (`pct_diff' < `tolerance')
end
```

---

## Validation Checklist by Command Type

### Data Transformation Commands

- [ ] Total person-time/records conserved
- [ ] No overlapping intervals within ID
- [ ] All input IDs present in output
- [ ] Continuous coverage (no gaps unless expected)
- [ ] Date formats preserved

### Statistical Commands

- [ ] Results match hand calculations
- [ ] Results within valid ranges (e.g., proportions 0-1)
- [ ] Observation counts correct
- [ ] Missing values handled correctly

### Merge/Join Commands

- [ ] Output IDs are correct intersection/union
- [ ] No duplicate records created
- [ ] Values correctly matched
- [ ] Non-matching records handled per specification

### Date Commands

- [ ] Correct date parsing for all formats
- [ ] Leap years handled correctly
- [ ] Boundary dates (month/year transitions) correct
- [ ] Invalid dates produce errors

---

## Mental Execution (Validation Without Stata)

When you can't run Stata (e.g., during code review), you can validate logic through mental execution traces. This technique compensates for lack of runtime by carefully tracing through code.

### Mental Execution Trace Format

Document your mental execution like this:

```
MENTAL EXECUTION TRACE
----------------------
Command: mycommand price mpg, option(value)

Step 1: syntax varlist, Option(string)
  - varlist = "price mpg"
  - option = "value"

Step 2: marksample touse
  - touse created, marks valid obs in price and mpg

Step 3: quietly count if `touse'
  - Assume 74 obs (from sysuse auto)
  - r(N) = 74, passes check

Step 4: foreach v of varlist `varlist' {
  - Iteration 1: v = "price"
  - Iteration 2: v = "mpg"

[Continue tracing...]

RESULT: Execution completes successfully
```

### Normal Path Execution

Trace through the program with these scenarios:

1. **Minimal valid input**: Simplest possible usage
2. **All options specified**: Every option provided
3. **Typical usage**: Common real-world usage pattern

For each scenario, trace:
- What values do macros hold at each step?
- What variables are created/modified?
- What is the expected output?

### Edge Case Mental Execution

Mentally execute with these edge cases:

| Scenario | Expected Behavior | Verify |
|----------|-------------------|--------|
| Empty dataset (0 obs) | Error 2000 with clear message | [ ] |
| Single observation | Completes successfully | [ ] |
| All missing values | Handles gracefully or errors clearly | [ ] |
| Varlist with 1 variable | Works correctly | [ ] |
| Varlist with many variables | No overflow issues | [ ] |
| Invalid option value | Clear error message | [ ] |
| File not found (if applicable) | Error 601 with path info | [ ] |

### Error Path Execution

For each validation/error check in the code:
- What triggers this error?
- Is the error message helpful?
- Is the error code appropriate?
- Does the program exit cleanly?

### State Verification

At program end, verify:
- [ ] No temp variables left in dataset
- [ ] No temp files left on disk
- [ ] No frames left (except original)
- [ ] Return values are populated
- [ ] Original data state preserved (if no output)

### Variable Lifecycle Tracking

Track each variable from creation to last use:

```
VARIABLE LIFECYCLE: _mytemp

Created:  Line 45: tempvar mytemp
          Line 46: gen `mytemp' = price * 2

Used:     Line 50: replace outcome = `mytemp' if condition
          Line 55: drop `mytemp'  <-- ERROR: tempvars auto-drop!

Status:   ERROR - Unnecessary drop of tempvar
```

### Control Flow Graph (Mental)

For complex programs, sketch the control flow:

```
START
  |
  v
[syntax parsing]
  |
  v
[validation] --error--> [exit 198]
  |
  |ok
  v
[if option1?]--yes--> [path A]
  |                      |
  |no                    |
  v                      v
[path B] <---------------+
  |
  v
[return values]
  |
  v
END
```

This helps identify:
- Unreachable code
- Missing error paths
- Variables used before definition in some paths

---

## Running Validation Tests

### Standalone

```stata
do _validation/validation_mycommand.do
```

### Via Test Runner

```stata
do _testing/run_test.do validation_mycommand
```

### Quiet Mode

```stata
global RUN_TEST_QUIET = 1
do _validation/validation_mycommand.do
```

---

## Checklist for Validation Files

- [ ] File named `validation_COMMANDNAME.do`
- [ ] Standard configuration block for runner globals
- [ ] Path configuration for all platforms
- [ ] Creates validation datasets with known values
- [ ] Each test has documented known answer
- [ ] Uses appropriate tolerance for assertions
- [ ] Includes invariant tests
- [ ] Includes boundary condition tests
- [ ] Display statements respect quiet mode
- [ ] PASS/FAIL messages always shown
- [ ] Summary section with exit code

---

*Last updated: 2025-12-14*
