# Stata-Tools Testing Instructions for Claude

This document provides comprehensive instructions for testing all Stata commands in the Stata-Tools repository using the Stata-MCP server.

## Overview

You are testing a collection of Stata packages for statistical analysis. Your goal is to:
1. Run all existing test files
2. Verify all commands work correctly
3. Identify and report any failures
4. Ensure comprehensive test coverage

## Environment Setup

### Repository Location

**IMPORTANT**: The local repository is located at:
```
/Users/tcopeland/Documents/GitHub/Stata-Tools
```

All test files use this path via the global macro `STATA_TOOLS_PATH`.

### Directory Structure

```
/Users/tcopeland/Documents/GitHub/Stata-Tools/
├── _testing/
│   ├── data/                    # Synthetic test datasets (generated)
│   │   ├── cohort.dta           # Base patient cohort
│   │   ├── hrt.dta              # HRT prescription records
│   │   ├── dmt.dta              # DMT therapy records
│   │   ├── steroids.dta         # Steroid prescriptions with dose (NEW)
│   │   ├── hospitalizations.dta # Hospitalization events
│   │   ├── migrations_wide.dta  # Migration records
│   │   ├── edss_long.dta        # EDSS scores over time
│   │   └── *_miss.dta           # Missing data versions
│   ├── generate_test_data.do    # Creates all synthetic datasets
│   ├── run_all_tests.do         # Master test runner
│   ├── test_*.do                # Individual test files
│   └── TESTING_INSTRUCTIONS.md  # This file
├── tvtools/                     # Time-varying exposure package
├── datamap/                     # Data mapping utilities
├── synthdata/                   # Synthetic data generation
└── [other packages]/
```

### Stata-MCP Connection

This testing uses [Stata-MCP](https://github.com/hanlulong/stata-mcp) to execute Stata commands. The MCP server runs on `http://localhost:4000/mcp` with SSE transport.

**Verify MCP is connected before testing:**
```stata
display "Hello from Stata"
display c(version)
display c(pwd)
```

### Prerequisites
- Stata must be accessible via the MCP server
- Working directory should be set to `/Users/tcopeland/Documents/GitHub/Stata-Tools/_testing/data/`

## Quick Start

### Step 1: Generate Test Data

If test data doesn't exist, generate it first:

```stata
do "/Users/tcopeland/Documents/GitHub/Stata-Tools/_testing/generate_test_data.do"
```

This creates all synthetic datasets including the new `steroids.dta` for dose testing.

### Step 2: Run All Tests

Execute the master test runner:

```stata
do "/Users/tcopeland/Documents/GitHub/Stata-Tools/_testing/run_all_tests.do"
```

### Step 3: Run Individual Tests

To test a specific command:

```stata
do "/Users/tcopeland/Documents/GitHub/Stata-Tools/_testing/test_tvexpose.do"
```

## Test Data Description

### cohort.dta (1,000 patients)
Base patient cohort with:
- `id`: Patient identifier
- `female`: Sex (0=Male, 1=Female)
- `age`: Age at study entry (25-70)
- `mstype`: MS type (1=RRMS, 2=SPMS, 3=PPMS, 4=CIS)
- `study_entry`: Study entry date
- `study_exit`: Study exit date
- `edss4_dt`: Date reached EDSS 4.0 (30% have events)
- `death_dt`: Date of death (5% mortality)

### hrt.dta (HRT Prescriptions)
Hormone replacement therapy records:
- `id`: Patient identifier
- `rx_start`: Prescription start date
- `rx_stop`: Prescription end date
- `hrt_type`: HRT type (1=Estrogen, 2=Combined, 3=Progestin)

### dmt.dta (DMT Records)
Disease-modifying therapy records:
- `id`: Patient identifier
- `dmt_start`: DMT start date
- `dmt_stop`: DMT end date
- `dmt`: DMT type (1-6, different medications)

### steroids.dta (Steroid Prescriptions - NEW)
Steroid prescriptions with dose amounts for testing `tvexpose dose` option:
- `id`: Patient identifier
- `steroid_start`: Course start date
- `steroid_stop`: Course end date
- `steroid_dose`: Dose in mg methylprednisolone (500, 1000, or 1250)
- `steroid_type`: Administration type (1=IV pulse, 2=Oral taper, 3=IV + oral)

**Note**: This dataset intentionally contains ~20% overlapping periods to test proportional dose allocation.

## Testing Workflow

### Phase 1: Data Generation

```stata
* Change to testing directory
cd "/Users/tcopeland/Documents/GitHub/Stata-Tools/_testing/data"

* Generate all test data
do "../generate_test_data.do"
```

Expected output datasets:
- cohort.dta (1,000 patients)
- hrt.dta (~2,000 prescriptions)
- dmt.dta (~2,500 therapy records)
- steroids.dta (~2,500 courses with dose amounts)
- hospitalizations.dta
- migrations_wide.dta
- edss_long.dta
- *_miss.dta versions

### Phase 2: Install Packages

Packages are automatically installed from the local repository when running test files. Manual installation:

```stata
global STATA_TOOLS_PATH "/Users/tcopeland/Documents/GitHub/Stata-Tools"

capture net uninstall tvtools
net install tvtools, from("${STATA_TOOLS_PATH}/tvtools")
```

### Phase 3: Run Tests

#### tvtools Suite (Run in Order)
```stata
do "/Users/tcopeland/Documents/GitHub/Stata-Tools/_testing/test_tvexpose.do"
do "/Users/tcopeland/Documents/GitHub/Stata-Tools/_testing/test_tvmerge.do"
do "/Users/tcopeland/Documents/GitHub/Stata-Tools/_testing/test_tvevent.do"
```

#### Other Commands
```stata
do "/Users/tcopeland/Documents/GitHub/Stata-Tools/_testing/test_datamap.do"
do "/Users/tcopeland/Documents/GitHub/Stata-Tools/_testing/test_table1_tc.do"
* ... etc.
```

## Command Reference & Test Coverage

### HIGH PRIORITY: tvtools Package

#### tvexpose - Time-Varying Exposure Creation

**Current test coverage**: 42 tests (comprehensive, including dose tests)

| Option | Description | Test # |
|--------|-------------|--------|
| Basic exposure | Time-varying categorical exposure | 1 |
| `evertreated` | Binary ever/never exposed | 2 |
| `currentformer` | Trichotomous never/current/former | 3 |
| `duration()` | Cumulative duration categories | 4 |
| `continuousunit()` | Cumulative exposure in time units | 5 |
| `grace()` | Grace period for gaps | 6 |
| `lag()` | Delay before exposure active | 7 |
| `washout()` | Exposure persists after stopping | 8 |
| `bytype` | Separate variables per type | 9 |
| `check` | Display diagnostics | 11 |
| `summarize` | Exposure distribution summary | 12 |
| `validate` | Validation dataset | 13 |
| `gaps` | Show persons with gaps | 14 |
| `overlaps` | Show overlapping periods | 15 |
| `referencelabel()` | Custom reference label | 16 |
| `keepvars()` | Keep additional variables | 17 |
| `recency()` | Time since last exposure | 21 |
| `expandunit()` | Row expansion granularity | 22 |
| `grace(exp=# ...)` | Type-specific grace periods | 23 |
| `merge()` | Merge consecutive periods | 24 |
| `fillgaps()` | Fill gaps with exposure | 25 |
| `carryforward()` | Carry forward exposure | 26 |
| `layer` | Later exposures take precedence | 27 |
| `priority()` | Priority order for overlaps | 28 |
| `split` | Split overlapping periods | 29 |
| `combine()` | Combined exposure variable | 30 |
| `window()` | Acute exposure window | 31 |
| `switching` | Switching indicator | 32 |
| `switchingdetail` | Switching pattern string | 33 |
| `statetime` | Time in current state | 34 |
| `label()` | Custom variable label | 35 |
| `keepdates` | Keep entry/exit dates | 36 |
| **`dose`** | Cumulative dose tracking | 38 |
| **`dosecuts()`** | Categorized dose cutpoints | 39 |
| **Dose overlaps** | Proportional dose allocation | 40 |
| **Dose + keepvars** | Dose with additional variables | 41 |
| **Dose default ref** | Verify reference defaults to 0 | 42 |

#### Dose Option Tests (NEW)

The dose option uses `steroids.dta` which contains:
- Steroid prescriptions with dose amounts (500, 1000, 1250 mg)
- Intentional overlapping periods (~20%) for testing proportional allocation
- Various course durations (3-28 days)

Example test commands:
```stata
* Test: Continuous cumulative dose
use cohort.dta, clear
tvexpose using steroids.dta, ///
    id(id) start(steroid_start) stop(steroid_stop) ///
    exposure(steroid_dose) entry(study_entry) exit(study_exit) ///
    dose generate(cumul_steroid) ///
    saveas("_test_dose") replace

* Test: Categorized dose with cutpoints
use cohort.dta, clear
tvexpose using steroids.dta, ///
    id(id) start(steroid_start) stop(steroid_stop) ///
    exposure(steroid_dose) entry(study_entry) exit(study_exit) ///
    dose dosecuts(1000 3000 5000) generate(dose_cat) ///
    saveas("_test_dosecuts") replace
```

### MEDIUM PRIORITY: Analysis Commands

#### table1_tc - Table 1 Creation
**Test coverage**: 24 tests

#### regtab - Regression Tables
**Test coverage**: Multiple tests

#### stratetab - Strate Output Formatting
**Test coverage**: 2 tests - needs expansion

### LOWER PRIORITY: Utility Commands

- compress_tc
- datefix
- today
- check
- migrations
- sustainedss

## Test Result Reporting

After running each test file, report results in this format:

```
===========================================
TEST RESULTS: [command_name]
===========================================
Total tests:     XX
Passed:          XX
Failed:          XX
-------------------------------------------
Failed tests:
  - Test N: [description] - Error: [error message]
===========================================
```

## Error Handling

When a test fails:

1. **Document the exact error message**
2. **Check if test data exists** - Many tests require `cohort.dta`, `hrt.dta`, etc.
3. **Verify adopath** - Ensure package is installed from local repository
4. **Check Stata version** - Some commands require Stata 16+ or 18+
5. **Report the failure** with full context

## Data Validation

Before running tests, validate test data:

```stata
global DATA_DIR "/Users/tcopeland/Documents/GitHub/Stata-Tools/_testing/data"

use "${DATA_DIR}/cohort.dta", clear
assert _N == 1000
assert study_exit > study_entry
count if missing(id)
assert r(N) == 0

use "${DATA_DIR}/steroids.dta", clear
assert _N > 0
count if steroid_stop < steroid_start
assert r(N) == 0
sum steroid_dose
display "Dose range: " r(min) " to " r(max)
```

## Edge Case Testing

Always test these scenarios:

1. **Empty dataset** - What happens with 0 observations?
2. **Single observation** - Boundary condition
3. **All missing values** - Does command handle gracefully?
4. **Invalid options** - Are error messages clear?
5. **Overlapping exposures** - How are conflicts resolved?
6. **Dose with overlaps** - Is proportional allocation correct?

## Cleanup

After testing, clean up temporary files:

```stata
global DATA_DIR "/Users/tcopeland/Documents/GitHub/Stata-Tools/_testing/data"

* Remove test output files
capture erase "${DATA_DIR}/_test_*.dta"
capture erase "${DATA_DIR}/_tv_*.dta"
capture erase "${DATA_DIR}/test_output_*.xlsx"

* Reset working environment
clear all
```

## Auditing .ado Files

When auditing a specific .ado file:

1. **Read the file** to understand its purpose and options
2. **Check the help file** (.sthlp) for documented syntax
3. **Run existing tests** to establish baseline
4. **Test edge cases** not covered by existing tests
5. **Verify return values** match documentation
6. **Check error handling** for invalid inputs

### Example Audit Workflow

```stata
* 1. Set paths
global STATA_TOOLS_PATH "/Users/tcopeland/Documents/GitHub/Stata-Tools"
global DATA_DIR "${STATA_TOOLS_PATH}/_testing/data"
cd "${DATA_DIR}"

* 2. Install the package being audited
capture net uninstall tvtools
net install tvtools, from("${STATA_TOOLS_PATH}/tvtools")

* 3. View help documentation
help tvexpose

* 4. Run tests
do "${STATA_TOOLS_PATH}/_testing/test_tvexpose.do"

* 5. Try edge cases
use cohort.dta, clear
* Test with subset
keep if female == 1
tvexpose using "${DATA_DIR}/steroids.dta", ///
    id(id) start(steroid_start) stop(steroid_stop) ///
    exposure(steroid_dose) entry(study_entry) exit(study_exit) ///
    dose generate(test_var) saveas("_test_edge") replace
```

## Summary

Your testing mission:
1. Generate test data (including steroids.dta for dose testing)
2. Run all existing test files
3. Document any failures with full context
4. Test edge cases not covered
5. Report comprehensive results

**Focus on HIGH PRIORITY items first** (tvtools suite with dose tests), then MEDIUM PRIORITY (analysis commands), then LOWER PRIORITY (utility commands).

Good luck!
