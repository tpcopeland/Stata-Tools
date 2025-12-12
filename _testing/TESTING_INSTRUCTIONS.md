# Stata-Tools Testing Instructions for Claude

This document provides comprehensive instructions for testing all Stata commands in the Stata-Tools repository using the Stata-MCP server.

## Overview

You are testing a collection of Stata packages for statistical analysis. Your goal is to:
1. Run all existing test files
2. Verify all commands work correctly
3. Identify and report any failures
4. Ensure comprehensive test coverage

## Environment Setup

### Stata-MCP Connection

This testing uses [Stata-MCP](https://github.com/hanlulong/stata-mcp) to execute Stata commands. The MCP server runs on `http://localhost:4000/mcp` with SSE transport.

**Verify MCP is connected before testing:**
```stata
display "Hello from Stata"
display c(version)
```

**Recommended VS Code settings for testing:**
- `stata-vscode.resultDisplayMode`: "compact" (reduces token usage)
- `stata-vscode.maxOutputTokens`: 10000 (or higher for verbose tests)
- `stata-vscode.runFileTimeout`: 600 (10 minutes for long tests)

### Prerequisites
- Stata must be accessible via the MCP server
- All test data must be generated (run `generate_test_data.do` first)
- Working directory should be `_testing/`

### Initial Setup

```stata
* Change to testing directory
cd "/workspace/Stata-Tools/_testing"

* Generate test data if not present
capture confirm file "cohort.dta"
if _rc {
    do generate_test_data.do
}
```

## Testing Workflow

### Phase 1: Generate Test Data

First, ensure test data exists:

```stata
cd "/workspace/Stata-Tools/_testing"
do generate_test_data.do
```

This creates:
- `cohort.dta` - 1,000 patients with demographics, dates, outcomes
- `hrt.dta` - HRT exposure records
- `dmt.dta` - DMT exposure records
- `hospitalizations.dta` - Hospitalization events
- Additional supporting files

### Phase 2: Install Packages

Ensure all packages are on the adopath:

```stata
adopath ++ "/workspace/Stata-Tools/tvtools"
adopath ++ "/workspace/Stata-Tools/datamap"
adopath ++ "/workspace/Stata-Tools/synthdata"
adopath ++ "/workspace/Stata-Tools/mvp"
adopath ++ "/workspace/Stata-Tools/table1_tc"
adopath ++ "/workspace/Stata-Tools/regtab"
adopath ++ "/workspace/Stata-Tools/cstat_surv"
adopath ++ "/workspace/Stata-Tools/stratetab"
adopath ++ "/workspace/Stata-Tools/compress_tc"
adopath ++ "/workspace/Stata-Tools/datefix"
adopath ++ "/workspace/Stata-Tools/check"
adopath ++ "/workspace/Stata-Tools/today"
adopath ++ "/workspace/Stata-Tools/setools"
adopath ++ "/workspace/Stata-Tools/pkgtransfer"
```

### Phase 3: Run Test Files

Execute tests in this order (dependencies first):

#### 3.1 Core Data Generation
```stata
do generate_test_data.do
```

#### 3.2 tvtools Suite (Run in Order)
```stata
do test_tvexpose.do   // Must run first - creates base datasets
do test_tvmerge.do    // Depends on tvexpose output
do test_tvevent.do    // Depends on tvexpose output
```

#### 3.3 Data Management Commands
```stata
do test_datamap.do
do test_datadict.do
do test_synthdata.do
do test_mvp.do
do test_compress_tc.do
do test_datefix.do
do test_check.do
do test_today.do
```

#### 3.4 Analysis Commands
```stata
do test_table1_tc.do
do test_regtab.do
do test_cstat_surv.do
do test_stratetab.do
```

#### 3.5 Specialized Commands
```stata
do test_migrations.do
do test_sustainedss.do
```

## Command Reference & Test Coverage

### HIGH PRIORITY: tvtools Package

#### tvexpose - Time-Varying Exposure Creation

**Current test coverage**: 37 tests (comprehensive)
**All documented options now tested:**

| Option | Description | Test Status |
|--------|-------------|-------------|
| `pointtime` | Point-in-time data (no stop date) | ✅ Test 21 |
| `expandunit()` | Row expansion granularity | ✅ Test 22 |
| `recency()` | Time since last exposure categories | ✅ Test 21 |
| `grace(exp=# ...)` | Type-specific grace periods | ✅ Test 23 |
| `merge()` | Merge consecutive periods | ✅ Test 24 |
| `fillgaps()` | Fill gaps with exposure | ✅ Test 25 |
| `carryforward()` | Carry forward exposure | ✅ Test 26 |
| `layer` | Later exposures take precedence | ✅ Test 27 |
| `priority()` | Priority order for overlaps | ✅ Test 28 |
| `split` | Split overlapping periods | ✅ Test 29 |
| `combine()` | Combined exposure variable | ✅ Test 30 |
| `window()` | Acute exposure window | ✅ Test 31 |
| `switching` | Switching indicator | ✅ Test 32 |
| `switchingdetail` | Switching pattern string | ✅ Test 33 |
| `statetime` | Time in current state | ✅ Test 34 |
| `label()` | Custom variable label | ✅ Test 35 |
| `keepdates` | Keep entry/exit dates | ✅ Test 36-37 |

**Example tests for reference**:

```stata
* Test: pointtime option
use cohort, clear
tvexpose using hrt, id(id) start(rx_start) ///
    exposure(hrt_type) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    pointtime generate(tv_hrt)

* Test: recency option
use cohort, clear
tvexpose using hrt, id(id) start(rx_start) stop(rx_stop) ///
    exposure(hrt_type) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    recency(1 5) generate(recency_hrt)

* Test: priority option
use cohort, clear
tvexpose using dmt, id(id) start(dmt_start) stop(dmt_stop) ///
    exposure(dmt) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    priority(6 5 4 3 2 1) generate(tv_dmt)

* Test: switching options
use cohort, clear
tvexpose using dmt, id(id) start(dmt_start) stop(dmt_stop) ///
    exposure(dmt) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    switching switchingdetail generate(tv_dmt)
confirm variable has_switched switching_pattern
```

#### tvmerge - Merge Time-Varying Datasets

**Current test coverage**: 16 tests (comprehensive)
**All documented options now tested:**

| Option | Description | Test Status |
|--------|-------------|-------------|
| `continuous()` | Continuous exposure handling | ✅ Test 14 |
| `keep()` | Keep additional variables | ✅ Test 15 |
| Multiple continuous | Multiple continuous exposures | ✅ Test 16 |

**Example tests for reference**:

```stata
* Test: continuous option
tvmerge tv_hrt tv_dose, id(id) ///
    start(rx_start dmt_start) stop(rx_stop dmt_stop) ///
    exposure(tv_exposure dosage_rate) ///
    continuous(dosage_rate) generate(hrt_type dose)

* Test: keep option
tvmerge tv_hrt tv_dmt, id(id) ///
    start(rx_start dmt_start) stop(rx_stop dmt_stop) ///
    exposure(tv_hrt tv_dmt) ///
    keep(dose strength) generate(hrt dmt)
```

#### tvevent - Event Integration

**Current test coverage**: 13 tests - COMPLETE COVERAGE ✓

### MEDIUM PRIORITY: Analysis Commands

#### stratetab - Strate Output Formatting

**Current test coverage**: 2 tests - INCOMPLETE
**Missing tests**:

```stata
* Test: sheet option
stratetab using strate_output, xlsx(output.xlsx) outcomes(edss4) sheet("Main Results")

* Test: title option
stratetab using strate_output, xlsx(output.xlsx) outcomes(edss4) title("Table 2")

* Test: digit options
stratetab using strate_output, xlsx(output.xlsx) outcomes(edss4) ///
    digits(3) eventdigits(0) pydigits(1)

* Test: scaling options
stratetab using strate_output, xlsx(output.xlsx) outcomes(edss4) ///
    pyscale(1000) ratescale(1000)
```

#### table1_tc - Table 1 Creation

**Current test coverage**: 24 tests - MOSTLY COMPLETE
**Missing tests**:

```stata
* Test: weight support
sysuse auto, clear
gen wt = price/1000
table1_tc mpg weight, by(foreign) fweight(wt)

* Test: gsd formatting
table1_tc mpg weight, by(foreign) gsdleft("[") gsdright("]")

* Test: p-value decimals
table1_tc mpg weight, by(foreign) test pdp(3) highpdp(4)
```

### LOWER PRIORITY: Utility Commands

#### compress_tc - String Compression

**Missing tests**: `nocompress`, `nostrl`, `quietly`, `varsavings`

#### datefix - Date Fixing

**Missing tests**: Multiple format testing, `topyear` option

#### today - Date Stamping

**Missing tests**: `tsep`, `hm`, timezone conversion

#### migrations - Swedish Migration Registry

**Missing tests**: `saveexclude`, `savecensor`, `replace`, `verbose`

#### sustainedss - Sustained EDSS

**Missing tests**: `baselinethreshold`, `keepall`, `quietly`

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
3. **Verify adopath** - Ensure package is on the path
4. **Check Stata version** - Some commands require Stata 16+ or 18+
5. **Report the failure** with full context

## Test Data Validation

Before running tests, validate test data:

```stata
use cohort, clear
assert _N == 1000
assert study_exit > study_entry
count if missing(id)
assert r(N) == 0

use hrt, clear
assert _N > 0
count if rx_stop < rx_start
assert r(N) == 0

use dmt, clear
assert _N > 0
count if dmt_stop < dmt_start
assert r(N) == 0
```

## Edge Case Testing

Always test these scenarios:

1. **Empty dataset** - What happens with 0 observations?
2. **Single observation** - Boundary condition
3. **All missing values** - Does command handle gracefully?
4. **Invalid options** - Are error messages clear?
5. **Large datasets** - Performance with 100k+ observations

## Cleanup

After testing, clean up temporary files:

```stata
* Remove test output files
capture erase _test_*.dta
capture erase _tv_*.dta
capture erase test_output_*.xlsx

* Reset working environment
clear all
```

## Complete Test Run Script

For a complete automated test run:

```stata
* Master test runner
clear all
set more off
cd "/workspace/Stata-Tools/_testing"

* Log all output
log using "test_run_`c(current_date)'.log", replace

* Run all tests
local test_files "generate_test_data test_tvexpose test_tvmerge test_tvevent"
local test_files "`test_files' test_datamap test_datadict test_synthdata test_mvp"
local test_files "`test_files' test_table1_tc test_regtab"
local test_files "`test_files' test_cstat_surv test_stratetab"
local test_files "`test_files' test_compress_tc test_datefix test_check test_today"
local test_files "`test_files' test_migrations test_sustainedss"

foreach test of local test_files {
    display _n "{hline 70}"
    display "Running: `test'.do"
    display "{hline 70}"
    capture noisily do `test'.do
    if _rc {
        display as error "FAILED: `test'.do (error `_rc')"
    }
    else {
        display as result "PASSED: `test'.do"
    }
}

log close
display _n "Test run complete. See log file for details."
```

## Summary

Your testing mission:
1. ✅ Generate test data
2. ✅ Run all existing test files
3. ✅ Document any failures
4. 🔲 Test missing options (listed above)
5. 🔲 Report comprehensive results

Focus on HIGH PRIORITY items first (tvtools suite), then MEDIUM PRIORITY (analysis commands), then LOWER PRIORITY (utility commands).

Good luck!
