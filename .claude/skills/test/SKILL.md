---
name: test
description: Write and run functional tests and validation tests for Stata commands
metadata:
  version: "2.0.0"
  argument-hint: "[command-name] [test-type]"
allowed-tools:
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - Bash
# NOTE: Task tool is NOT allowed - do NOT use subagents
---

# Stata Testing & Validation

Use this for writing or running both functional tests (`test_*.do`) and validation tests (`validation_*.do`).

**IMPORTANT:** Always use `stata-mp` when running tests.

## Testing vs Validation

| Functional Testing | Validation Testing |
|--------------------|--------------------|
| Does it **run** without errors? | Does it produce **correct** results? |
| Uses realistic datasets | Uses minimal hand-crafted datasets |
| Checks return codes, variable existence | Checks specific computed values |
| Location: `_devkit/_testing/test_*.do` | Location: `_devkit/_validation/validation_*.do` |

## Quick Start

### Create Functional Test
```bash
cp _devkit/_templates/testing_TEMPLATE.do _devkit/_testing/test_mycommand.do
# Replace TEMPLATE with command name, customize test cases
```

### Create Validation Test
```bash
cp _devkit/_templates/validation_TEMPLATE.do _devkit/_validation/validation_mycommand.do
# Create datasets with known expected values, write assertions
```

### Run Tests
```bash
# Run single test
stata-mp -b do _devkit/_testing/test_mycommand.do

# Check for errors
grep -E "^r\([0-9]+" _devkit/_testing/test_mycommand.log

# Run all tests
bash .claude/scripts/check-test-coverage.sh
```

## Required Functional Test Categories

1. **Basic Functionality** - Minimal required arguments
2. **Option Tests** - Each option individually + combinations
3. **Error Handling** - Expected failures with capture + assert _rc
4. **Return Values** - Check r() values exist and are valid
5. **Edge Cases** - Single obs, missing values, empty data
6. **Data Preservation** - _N unchanged after command

## Required Validation Categories

1. **Known-Answer Tests** - Hand-calculated expected values
2. **Boundary Tests** - Zero, negative, edge values
3. **Conservation Tests** - Totals preserved
4. **Row-Level Validation** (CRITICAL) - Not just aggregates
5. **Multi-Observation** (CRITICAL) - Multiple records per person/group

## Test Pattern Template

```stata
local ++test_count
if `run_only' == 0 | `run_only' == N {
    capture {
        sysuse auto, clear
        mycommand price mpg, required(weight)
        assert r(N) > 0
    }
    if _rc == 0 {
        display as result "  PASS: Description"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Description (error `=_rc')"
        local ++fail_count
    }
}
```

## Floating Point Comparisons

```stata
// WRONG
assert r(mean) == 3.14159

// CORRECT - use tolerance
assert abs(r(mean) - 3.14159) < 0.0001
```

| Calculation Type | Tolerance |
|-----------------|-----------|
| Exact counts | 0 (use ==) |
| Date differences | 1 day |
| Proportions | 0.001 |
| Means/SDs | 0.001 |

## Debugging Failed Tests

1. Run specific test: `do run_test.do mycommand 15`
2. Deep debug: `set trace on` before failing command
3. Fix and verify single test
4. Run full suite to check regressions

## Check Coverage

Run `.claude/scripts/check-test-coverage.sh` to see which packages are missing tests.

## Delegation

| When | Use |
|------|-----|
| Fixing code bugs found by tests | `/develop` |
| Reviewing test quality | `/reviewer` |
| Running tests and parsing results | `/package` |

## Reference Files

- `workflows/functional-testing.md` - Test creation/running details
- `workflows/validation-testing.md` - Known-answer testing details
- `references/date-reference.md` - Stata date values for testing
- `references/helper-programs.md` - Reusable test helpers
