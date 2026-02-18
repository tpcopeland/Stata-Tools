# Validation Testing Workflow

## Core Principles

### 1. Known-Answer Testing
Create minimal datasets where you can calculate expected results by hand.

### 2. Invariant Testing
Properties that must ALWAYS hold (proportions between 0-1, counts match, no overlaps).

### 3. Boundary Conditions
Test at exact edges (zero, negative, first/last day).

### 4. Row-Level Validation (CRITICAL)
Always verify row-level calculations, not just aggregates. Aggregates can hide bugs.

### 5. Multi-Observation Testing (CRITICAL)
Test with multiple records per person/group. Single-obs data misses many bugs.

## Validation File Structure

```stata
clear all
set more off
version 16.0

local test_count = 0
local pass_count = 0
local fail_count = 0

* CREATE VALIDATION DATA with known values
clear
input long id double x double expected
    1 10 100
    2 20 400
    3 30 900
end

* Test 1: Known calculation
local ++test_count
capture {
    mycommand x, operation(square) generate(result)
    forvalues i = 1/3 {
        local actual = result[`i']
        local expect = expected[`i']
        assert abs(`actual' - `expect') < 0.001
    }
}
if _rc == 0 {
    display as result "  PASS: Calculation correct"
    local ++pass_count
}
else {
    display as error "  FAIL: Calculation"
    local ++fail_count
}

* Summary
if `fail_count' > 0 exit 1
```

## Checklist

- [ ] Creates datasets with **known values**
- [ ] Each test documents expected answer
- [ ] Uses appropriate tolerance for floats
- [ ] Includes boundary condition tests
- [ ] **Validates row-level, not just aggregates**
- [ ] **Uses multi-observation test data**
- [ ] Summary with exit code
