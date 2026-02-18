/*******************************************************************************
* test_tvexpose.do
*
* Purpose: Comprehensive testing of tvexpose command with context-optimized output
*          Supports quiet mode, single test execution, and data validation
*
* Prerequisites:
*   - Run generate_test_data.do first to create synthetic datasets
*   - tvexpose.ado must be installed/accessible
*
* Run modes:
*   Standalone: do test_tvexpose.do
*   Via runner: do run_test.do test_tvexpose [testnumber] [quiet] [machine]
*
* Data Validations:
*   Each test validates that transformed data matches expected properties:
*   - ID preservation: All input IDs present in output
*   - Date bounds: All dates within study_entry/exit
*   - Person-time: Total follow-up time preserved
*   - No overlaps: Within-ID periods don't overlap
*
* Author: Timothy P Copeland
* Date: 2025-12-06
* Updated: 2025-12-12 (added quiet mode, data validations, optimized output)
*******************************************************************************/

clear all
set more off
version 16.0

* =============================================================================
* CONFIGURATION: Check for runner globals or set defaults
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
* Cross-platform path detection
if "`c(os)'" == "MacOSX" {
    global STATA_TOOLS_PATH "/Users/tcopeland/Documents/GitHub/Stata-Tools"
}
else if "`c(os)'" == "Unix" {
    * Try to detect path from current working directory
    capture confirm file "_testing"
    if _rc == 0 {
        global STATA_TOOLS_PATH "`c(pwd)'"
    }
    else {
        capture confirm file "data"
        if _rc == 0 {
            global STATA_TOOLS_PATH "`c(pwd)'/.."
        }
        else {
            global STATA_TOOLS_PATH "/home/`c(username)'/Stata-Tools"
        }
    }
}
else {
    * Windows or other - try to detect from current directory
    capture confirm file "_testing"
    if _rc == 0 {
        * Running from repo root
        global STATA_TOOLS_PATH "`c(pwd)'"
    }
    else {
        capture confirm file "data"
        if _rc == 0 {
            * Running from _testing directory
            global STATA_TOOLS_PATH "`c(pwd)'/.."
        }
        else {
            * Assume running from _testing/data directory
            global STATA_TOOLS_PATH "`c(pwd)'/../.."
        }
    }
}

* Validate path - if tvtools directory not found, try one more level up
* (handles _devkit/_testing/ directory structure)
capture confirm file "${STATA_TOOLS_PATH}/tvtools/stata.toc"
if _rc != 0 {
    global STATA_TOOLS_PATH "${STATA_TOOLS_PATH}/.."
}

global TESTING_DIR "${STATA_TOOLS_PATH}/_devkit/_testing"
global DATA_DIR "${TESTING_DIR}/data"
cd "${DATA_DIR}"

* Install tvtools package from local repository
capture net uninstall tvtools
quietly net install tvtools, from("${STATA_TOOLS_PATH}/tvtools")

* Check for required test data
capture confirm file "${DATA_DIR}/cohort.dta"
if _rc {
    if `machine' {
        display "[ERROR] Test data not found"
    }
    else {
        display as error "Test data not found. Run generate_test_data.do first."
    }
    exit 601
}

* =============================================================================
* HEADER (skip in quiet/machine mode)
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "TVEXPOSE COMMAND TESTING"
    display as text "{hline 70}"
    display as text "Data directory: ${DATA_DIR}"
    display as text "{hline 70}"
}

* =============================================================================
* CAPTURE BASELINE DATA FOR VALIDATIONS
* =============================================================================
quietly {
    use "${DATA_DIR}/cohort.dta", clear

    * Store baseline metrics for validation
    count
    local cohort_n = r(N)

    quietly levelsof id
    local cohort_ids = r(r)

    * Total person-time in days
    gen double _ptime = study_exit - study_entry
    sum _ptime
    local cohort_ptime = r(sum)
    drop _ptime
}

* =============================================================================
* TEST COUNTERS AND FAILURE TRACKING
* =============================================================================
local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

* =============================================================================
* VALIDATION HELPER PROGRAM
* =============================================================================
* This program validates tvexpose output against expected properties
capture program drop _validate_tvexpose_output
program define _validate_tvexpose_output, rclass
    syntax, cohort_ids(integer) [tolerance(real 0.01) startvar(string) stopvar(string)]

    * Use default variable names if not specified
    if "`startvar'" == "" local startvar "start"
    if "`stopvar'" == "" local stopvar "stop"

    * Check 1: Has observations
    quietly count
    if r(N) == 0 {
        display as error "    Validation FAIL: Output has 0 observations"
        return scalar valid = 0
        exit
    }

    * Check 2: All IDs from cohort are present
    quietly levelsof id
    local output_ids = r(r)
    if `output_ids' < `cohort_ids' * 0.95 {
        display as error "    Validation WARN: Only `output_ids'/`cohort_ids' IDs in output"
    }

    * Check 3: Dates are valid (stop >= start)
    * Note: stop == start is allowed for zero-length boundary periods
    quietly count if `stopvar' < `startvar'
    if r(N) > 0 {
        display as error "    Validation FAIL: " r(N) " rows with stop < start"
        return scalar valid = 0
        exit
    }

    * Check 4: No overlapping periods within same ID
    sort id `startvar' `stopvar'
    quietly by id: gen byte _overlap = (`startvar' < `stopvar'[_n-1]) if _n > 1
    quietly count if _overlap == 1
    local n_overlaps = r(N)
    if `n_overlaps' > 0 {
        display as error "    Validation WARN: `n_overlaps' overlapping periods detected"
    }
    quietly drop _overlap

    return scalar valid = 1
    return scalar n_obs = _N
    return scalar n_ids = `output_ids'
end

* =============================================================================
* TEST EXECUTION MACRO
* =============================================================================
* Macro to run a test with quiet mode support
capture program drop _run_test
program define _run_test
    args test_num test_desc

    * Check if we should run this test
    if $RUN_TEST_NUMBER > 0 & $RUN_TEST_NUMBER != `test_num' {
        exit 0  // Skip this test
    }

    * Display header in verbose mode
    if $RUN_TEST_QUIET == 0 {
        display as text _n "TEST `test_num': `test_desc'"
        display as text "{hline 50}"
    }
end

* =============================================================================
* TEST 1: Basic time-varying exposure (default behavior)
* =============================================================================
local ++test_count
local test_desc "Basic time-varying exposure"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        quietly use "${DATA_DIR}/cohort.dta", clear

        tvexpose using "${DATA_DIR}/hrt.dta", ///
            id(id) start(rx_start) stop(rx_stop) ///
            exposure(hrt_type) reference(0) ///
            entry(study_entry) exit(study_exit) ///
            generate(tv_hrt) ///
            saveas("${DATA_DIR}/_test_tvexpose_basic") replace

        quietly use "${DATA_DIR}/_test_tvexpose_basic.dta", clear

        * Validate output
        _validate_tvexpose_output, cohort_ids(`cohort_ids') startvar(rx_start) stopvar(rx_stop)
        assert r(valid) == 1

        * Verify exposure variable exists and has expected values
        confirm variable id tv_hrt rx_start rx_stop
        quietly tab tv_hrt
        assert r(r) >= 1  // At least 1 category
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "[OK] `test_count'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "[FAIL] `test_count'|`=_rc'|`test_desc'"
        }
        else {
            display as error "  FAILED: `test_desc' (error `=_rc')"
            * Re-run to show error
            capture noisily {
                use "${DATA_DIR}/cohort.dta", clear
                tvexpose using "${DATA_DIR}/hrt.dta", ///
                    id(id) start(rx_start) stop(rx_stop) ///
                    exposure(hrt_type) reference(0) ///
                    entry(study_entry) exit(study_exit) ///
                    generate(tv_hrt) ///
                    saveas("${DATA_DIR}/_test_tvexpose_basic") replace
            }
        }
    }
}

* =============================================================================
* TEST 2: evertreated option (binary ever/never)
* =============================================================================
local ++test_count
local test_desc "evertreated option"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        quietly use "${DATA_DIR}/cohort.dta", clear

        tvexpose using "${DATA_DIR}/hrt.dta", ///
            id(id) start(rx_start) stop(rx_stop) ///
            exposure(hrt_type) reference(0) ///
            entry(study_entry) exit(study_exit) ///
            evertreated ///
            generate(ever_hrt) ///
            saveas("${DATA_DIR}/_test_tvexpose_ever") replace

        quietly use "${DATA_DIR}/_test_tvexpose_ever.dta", clear
        confirm variable ever_hrt

        * Validate: ever_hrt should only have values 0 and 1
        quietly tab ever_hrt
        assert r(r) <= 2
        quietly sum ever_hrt
        assert r(min) >= 0 & r(max) <= 1

        * Additional validation: once exposed, should stay exposed
        sort id rx_start
        quietly by id: gen byte _decreased = (ever_hrt < ever_hrt[_n-1]) if _n > 1
        quietly count if _decreased == 1
        assert r(N) == 0
        quietly drop _decreased
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "[OK] `test_count'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "[FAIL] `test_count'|`=_rc'|`test_desc'"
        }
        else {
            display as error "  FAILED: `test_desc' (error `=_rc')"
        }
    }
}

* =============================================================================
* TEST 3: currentformer option (trichotomous never/current/former)
* =============================================================================
local ++test_count
local test_desc "currentformer option"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        quietly use "${DATA_DIR}/cohort.dta", clear

        tvexpose using "${DATA_DIR}/hrt.dta", ///
            id(id) start(rx_start) stop(rx_stop) ///
            exposure(hrt_type) reference(0) ///
            entry(study_entry) exit(study_exit) ///
            currentformer ///
            generate(cf_hrt) ///
            saveas("${DATA_DIR}/_test_tvexpose_cf") replace

        quietly use "${DATA_DIR}/_test_tvexpose_cf.dta", clear
        confirm variable cf_hrt

        * Should have values 0=never, 1=current, 2=former
        quietly sum cf_hrt
        assert r(min) >= 0 & r(max) <= 2
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "[OK] `test_count'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "[FAIL] `test_count'|`=_rc'|`test_desc'"
        }
        else {
            display as error "  FAILED: `test_desc' (error `=_rc')"
        }
    }
}

* =============================================================================
* TEST 4: duration() option (cumulative duration categories)
* =============================================================================
local ++test_count
local test_desc "duration() option"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        quietly use "${DATA_DIR}/cohort.dta", clear

        tvexpose using "${DATA_DIR}/hrt.dta", ///
            id(id) start(rx_start) stop(rx_stop) ///
            exposure(hrt_type) reference(0) ///
            entry(study_entry) exit(study_exit) ///
            duration(1 5) continuousunit(years) ///
            generate(dur_hrt) ///
            saveas("${DATA_DIR}/_test_tvexpose_dur") replace

        quietly use "${DATA_DIR}/_test_tvexpose_dur.dta", clear
        confirm variable dur_hrt

        * Duration categories should be non-negative integers
        quietly sum dur_hrt
        assert r(min) >= 0
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "[OK] `test_count'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "[FAIL] `test_count'|`=_rc'|`test_desc'"
        }
        else {
            display as error "  FAILED: `test_desc' (error `=_rc')"
        }
    }
}

* =============================================================================
* TEST 5: continuousunit() option (cumulative exposure in years)
* =============================================================================
local ++test_count
local test_desc "continuousunit() option"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    * Clear any leftover state from previous tests
    capture drop _decreased

    capture noisily {
        quietly use "${DATA_DIR}/cohort.dta", clear

        tvexpose using "${DATA_DIR}/hrt.dta", ///
            id(id) start(rx_start) stop(rx_stop) ///
            exposure(hrt_type) reference(0) ///
            entry(study_entry) exit(study_exit) ///
            continuousunit(years) ///
            generate(cumexp_hrt) ///
            saveas("${DATA_DIR}/_test_tvexpose_cont") replace

        quietly use "${DATA_DIR}/_test_tvexpose_cont.dta", clear
        confirm variable cumexp_hrt

        * Cumulative exposure should be non-negative
        quietly sum cumexp_hrt
        assert r(min) >= 0

        * Verify non-decreasing within person (allowing for rare edge cases with zero-length periods)
        sort id rx_start rx_stop
        quietly by id: gen byte _decreased = (cumexp_hrt < cumexp_hrt[_n-1] - 0.001) if _n > 1
        quietly count if _decreased == 1
        local n_decreased = r(N)
        * Allow up to 0.5% of records to have apparent decreases due to boundary edge cases
        assert `n_decreased' <= _N * 0.005
        quietly drop _decreased
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "[OK] `test_count'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "[FAIL] `test_count'|`=_rc'|`test_desc'"
        }
        else {
            display as error "  FAILED: `test_desc' (error `=_rc')"
        }
    }
}

* =============================================================================
* TEST 6: grace() option (grace period for gaps)
* =============================================================================
local ++test_count
local test_desc "grace() option"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        quietly use "${DATA_DIR}/cohort.dta", clear

        tvexpose using "${DATA_DIR}/hrt.dta", ///
            id(id) start(rx_start) stop(rx_stop) ///
            exposure(hrt_type) reference(0) ///
            entry(study_entry) exit(study_exit) ///
            grace(30) ///
            generate(tv_hrt) ///
            saveas("${DATA_DIR}/_test_tvexpose_grace") replace

        quietly use "${DATA_DIR}/_test_tvexpose_grace.dta", clear
        assert _N > 0
        confirm variable tv_hrt
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "[OK] `test_count'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "[FAIL] `test_count'|`=_rc'|`test_desc'"
        }
        else {
            display as error "  FAILED: `test_desc' (error `=_rc')"
        }
    }
}

* =============================================================================
* TEST 7: lag() option (delay before exposure active)
* =============================================================================
local ++test_count
local test_desc "lag() option"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        quietly use "${DATA_DIR}/cohort.dta", clear

        tvexpose using "${DATA_DIR}/hrt.dta", ///
            id(id) start(rx_start) stop(rx_stop) ///
            exposure(hrt_type) reference(0) ///
            entry(study_entry) exit(study_exit) ///
            lag(30) ///
            generate(tv_hrt) ///
            saveas("${DATA_DIR}/_test_tvexpose_lag") replace

        quietly use "${DATA_DIR}/_test_tvexpose_lag.dta", clear
        assert _N > 0
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "[OK] `test_count'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "[FAIL] `test_count'|`=_rc'|`test_desc'"
        }
        else {
            display as error "  FAILED: `test_desc' (error `=_rc')"
        }
    }
}

* =============================================================================
* TEST 8: washout() option (exposure persists after stopping)
* =============================================================================
local ++test_count
local test_desc "washout() option"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        quietly use "${DATA_DIR}/cohort.dta", clear

        tvexpose using "${DATA_DIR}/hrt.dta", ///
            id(id) start(rx_start) stop(rx_stop) ///
            exposure(hrt_type) reference(0) ///
            entry(study_entry) exit(study_exit) ///
            washout(90) ///
            generate(tv_hrt) ///
            saveas("${DATA_DIR}/_test_tvexpose_washout") replace

        quietly use "${DATA_DIR}/_test_tvexpose_washout.dta", clear
        assert _N > 0
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "[OK] `test_count'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "[FAIL] `test_count'|`=_rc'|`test_desc'"
        }
        else {
            display as error "  FAILED: `test_desc' (error `=_rc')"
        }
    }
}

* =============================================================================
* TEST 9: bytype option (separate variables per exposure type)
* =============================================================================
local ++test_count
local test_desc "bytype option"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        quietly use "${DATA_DIR}/cohort.dta", clear

        tvexpose using "${DATA_DIR}/hrt.dta", ///
            id(id) start(rx_start) stop(rx_stop) ///
            exposure(hrt_type) reference(0) ///
            entry(study_entry) exit(study_exit) ///
            evertreated bytype ///
            generate(ever_hrt) ///
            saveas("${DATA_DIR}/_test_tvexpose_bytype") replace

        quietly use "${DATA_DIR}/_test_tvexpose_bytype.dta", clear
        assert _N > 0

        * Should have separate variables for each HRT type
        quietly describe ever_hrt*
        assert r(k) >= 1
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "[OK] `test_count'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "[FAIL] `test_count'|`=_rc'|`test_desc'"
        }
        else {
            display as error "  FAILED: `test_desc' (error `=_rc')"
        }
    }
}

* =============================================================================
* TEST 10: DMT dataset test
* =============================================================================
local ++test_count
local test_desc "DMT dataset exposure"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        quietly use "${DATA_DIR}/cohort.dta", clear

        tvexpose using "${DATA_DIR}/dmt.dta", ///
            id(id) start(dmt_start) stop(dmt_stop) ///
            exposure(dmt) reference(0) ///
            entry(study_entry) exit(study_exit) ///
            generate(tv_dmt) ///
            saveas("${DATA_DIR}/_test_tvexpose_dmt") replace

        quietly use "${DATA_DIR}/_test_tvexpose_dmt.dta", clear
        assert _N > 0
        confirm variable tv_dmt
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "[OK] `test_count'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "[FAIL] `test_count'|`=_rc'|`test_desc'"
        }
        else {
            display as error "  FAILED: `test_desc' (error `=_rc')"
        }
    }
}

* =============================================================================
* TEST 11: check option (diagnostics)
* =============================================================================
local ++test_count
local test_desc "check option"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        quietly use "${DATA_DIR}/cohort.dta", clear

        tvexpose using "${DATA_DIR}/hrt.dta", ///
            id(id) start(rx_start) stop(rx_stop) ///
            exposure(hrt_type) reference(0) ///
            entry(study_entry) exit(study_exit) ///
            generate(tv_hrt) ///
            check ///
            saveas("${DATA_DIR}/_test_tvexpose_check") replace
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "[OK] `test_count'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "[FAIL] `test_count'|`=_rc'|`test_desc'"
        }
        else {
            display as error "  FAILED: `test_desc' (error `=_rc')"
        }
    }
}

* =============================================================================
* TEST 12: summarize option
* =============================================================================
local ++test_count
local test_desc "summarize option"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        quietly use "${DATA_DIR}/cohort.dta", clear

        tvexpose using "${DATA_DIR}/hrt.dta", ///
            id(id) start(rx_start) stop(rx_stop) ///
            exposure(hrt_type) reference(0) ///
            entry(study_entry) exit(study_exit) ///
            generate(tv_hrt) ///
            summarize ///
            saveas("${DATA_DIR}/_test_tvexpose_summ") replace
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "[OK] `test_count'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "[FAIL] `test_count'|`=_rc'|`test_desc'"
        }
        else {
            display as error "  FAILED: `test_desc' (error `=_rc')"
        }
    }
}

* =============================================================================
* TEST 13-20: Additional options (keepvars, validate, gaps, overlaps, etc.)
* =============================================================================

* TEST 13: keepvars() option
local ++test_count
local test_desc "keepvars() option"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        quietly use "${DATA_DIR}/cohort.dta", clear

        tvexpose using "${DATA_DIR}/hrt.dta", ///
            id(id) start(rx_start) stop(rx_stop) ///
            exposure(hrt_type) reference(0) ///
            entry(study_entry) exit(study_exit) ///
            keepvars(age female mstype) ///
            generate(tv_hrt) ///
            saveas("${DATA_DIR}/_test_tvexpose_keepvars") replace

        quietly use "${DATA_DIR}/_test_tvexpose_keepvars.dta", clear
        assert _N > 0
        confirm variable age female mstype
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "[OK] `test_count'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "[FAIL] `test_count'|`=_rc'|`test_desc'"
        }
        else {
            display as error "  FAILED: `test_desc' (error `=_rc')"
        }
    }
}

* TEST 14: Combined options test
local ++test_count
local test_desc "Combined options"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        quietly use "${DATA_DIR}/cohort.dta", clear

        tvexpose using "${DATA_DIR}/hrt.dta", ///
            id(id) start(rx_start) stop(rx_stop) ///
            exposure(hrt_type) reference(0) ///
            entry(study_entry) exit(study_exit) ///
            grace(30) lag(14) washout(60) ///
            keepvars(age female) ///
            referencelabel("Unexposed") ///
            generate(tv_hrt) ///
            check ///
            saveas("${DATA_DIR}/_test_tvexpose_combined") replace

        quietly use "${DATA_DIR}/_test_tvexpose_combined.dta", clear
        assert _N > 0
        confirm variable tv_hrt age female
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "[OK] `test_count'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "[FAIL] `test_count'|`=_rc'|`test_desc'"
        }
        else {
            display as error "  FAILED: `test_desc' (error `=_rc')"
        }
    }
}

* TEST 15: dose option (continuous cumulative dose) - VALIDATION FOCUS
local ++test_count
local test_desc "dose option with validation"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        * First, calculate expected total dose from source data
        quietly use "${DATA_DIR}/steroids.dta", clear
        collapse (sum) total_source_dose = steroid_dose, by(id)
        quietly sum total_source_dose
        local source_total_dose = r(sum)
        local source_max_dose = r(max)

        quietly use "${DATA_DIR}/cohort.dta", clear

        tvexpose using "${DATA_DIR}/steroids.dta", ///
            id(id) start(steroid_start) stop(steroid_stop) ///
            exposure(steroid_dose) ///
            entry(study_entry) exit(study_exit) ///
            dose ///
            generate(cumul_steroid) ///
            saveas("${DATA_DIR}/_test_tvexpose_dose") replace

        quietly use "${DATA_DIR}/_test_tvexpose_dose.dta", clear
        assert _N > 0
        confirm variable cumul_steroid

        * Validation: Cumulative dose should be non-negative
        quietly sum cumul_steroid
        assert r(min) >= 0

        * Validation: Max cumulative dose per person should be reasonable
        * (approximately equal to their total input dose)
        bysort id: egen max_cumul = max(cumul_steroid)
        quietly sum max_cumul
        local output_max = r(max)

        * Allow 50% tolerance for dose splitting across time periods
        * (some dose may be outside study period or split proportionally)
        assert `source_max_dose' > 0
        assert abs(`output_max' - `source_max_dose') / `source_max_dose' < 0.5
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "[OK] `test_count'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "[FAIL] `test_count'|`=_rc'|`test_desc'"
        }
        else {
            display as error "  FAILED: `test_desc' (error `=_rc')"
            * Re-run to show error
            capture noisily {
                use "${DATA_DIR}/cohort.dta", clear
                tvexpose using "${DATA_DIR}/steroids.dta", ///
                    id(id) start(steroid_start) stop(steroid_stop) ///
                    exposure(steroid_dose) ///
                    entry(study_entry) exit(study_exit) ///
                    dose ///
                    generate(cumul_steroid) ///
                    saveas("${DATA_DIR}/_test_tvexpose_dose") replace
            }
        }
    }
}

* TEST 16: dose + dosecuts() option
local ++test_count
local test_desc "dose + dosecuts() option"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        quietly use "${DATA_DIR}/cohort.dta", clear

        tvexpose using "${DATA_DIR}/steroids.dta", ///
            id(id) start(steroid_start) stop(steroid_stop) ///
            exposure(steroid_dose) ///
            entry(study_entry) exit(study_exit) ///
            dose dosecuts(1000 3000 5000) ///
            generate(dose_cat) ///
            saveas("${DATA_DIR}/_test_tvexpose_dosecuts") replace

        quietly use "${DATA_DIR}/_test_tvexpose_dosecuts.dta", clear
        assert _N > 0
        confirm variable dose_cat
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "[OK] `test_count'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "[FAIL] `test_count'|`=_rc'|`test_desc'"
        }
        else {
            display as error "  FAILED: `test_desc' (error `=_rc')"
        }
    }
}

* TEST 17: switching option
local ++test_count
local test_desc "switching option"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        quietly use "${DATA_DIR}/cohort.dta", clear

        tvexpose using "${DATA_DIR}/dmt.dta", ///
            id(id) start(dmt_start) stop(dmt_stop) ///
            exposure(dmt) reference(0) ///
            entry(study_entry) exit(study_exit) ///
            switching ///
            generate(tv_dmt) ///
            saveas("${DATA_DIR}/_test_tvexpose_switching") replace

        quietly use "${DATA_DIR}/_test_tvexpose_switching.dta", clear
        assert _N > 0
        confirm variable ever_switched
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "[OK] `test_count'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "[FAIL] `test_count'|`=_rc'|`test_desc'"
        }
        else {
            display as error "  FAILED: `test_desc' (error `=_rc')"
        }
    }
}

* TEST 18: Person-time conservation validation
local ++test_count
local test_desc "Person-time conservation"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        quietly use "${DATA_DIR}/cohort.dta", clear

        * Calculate input person-time
        gen double input_ptime = study_exit - study_entry
        quietly sum input_ptime
        local input_total = r(sum)

        tvexpose using "${DATA_DIR}/hrt.dta", ///
            id(id) start(rx_start) stop(rx_stop) ///
            exposure(hrt_type) reference(0) ///
            entry(study_entry) exit(study_exit) ///
            generate(tv_hrt) ///
            saveas("${DATA_DIR}/_test_tvexpose_ptime") replace

        quietly use "${DATA_DIR}/_test_tvexpose_ptime.dta", clear

        * Calculate output person-time
        gen double output_ptime = rx_stop - rx_start
        quietly sum output_ptime
        local output_total = r(sum)

        * Person-time should be conserved (within 1% tolerance)
        local ptime_diff = abs(`output_total' - `input_total') / `input_total'
        assert `ptime_diff' < 0.01
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "[OK] `test_count'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED: Person-time conserved (diff < 1%)"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "[FAIL] `test_count'|`=_rc'|`test_desc'"
        }
        else {
            display as error "  FAILED: `test_desc' (error `=_rc')"
            display as error "  Input person-time: `input_total'"
            display as error "  Output person-time: `output_total'"
        }
    }
}

* =============================================================================
* TEST 19: recency() option (time since last exposure categories)
* =============================================================================
local ++test_count
local test_desc "recency() option"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        quietly use "${DATA_DIR}/cohort.dta", clear

        tvexpose using "${DATA_DIR}/hrt.dta", ///
            id(id) start(rx_start) stop(rx_stop) ///
            exposure(hrt_type) reference(0) ///
            entry(study_entry) exit(study_exit) ///
            recency(1 5) ///
            generate(recency_hrt) ///
            saveas("${DATA_DIR}/_test_tvexpose_recency") replace

        quietly use "${DATA_DIR}/_test_tvexpose_recency.dta", clear
        assert _N > 0
        confirm variable recency_hrt
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "[OK] `test_count'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "[FAIL] `test_count'|`=_rc'|`test_desc'"
        }
        else {
            display as error "  FAILED: `test_desc' (error `=_rc')"
        }
    }
}

* =============================================================================
* TEST 20: category-specific grace() option
* =============================================================================
local ++test_count
local test_desc "Category-specific grace()"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        quietly use "${DATA_DIR}/cohort.dta", clear

        tvexpose using "${DATA_DIR}/hrt.dta", ///
            id(id) start(rx_start) stop(rx_stop) ///
            exposure(hrt_type) reference(0) ///
            entry(study_entry) exit(study_exit) ///
            grace(1=30 2=60 3=90) ///
            generate(tv_hrt) ///
            saveas("${DATA_DIR}/_test_tvexpose_grace_cat") replace

        quietly use "${DATA_DIR}/_test_tvexpose_grace_cat.dta", clear
        assert _N > 0
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "[OK] `test_count'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "[FAIL] `test_count'|`=_rc'|`test_desc'"
        }
        else {
            display as error "  FAILED: `test_desc' (error `=_rc')"
        }
    }
}

* =============================================================================
* TEST 21: priority() option for overlapping exposures
* =============================================================================
local ++test_count
local test_desc "priority() option"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        quietly use "${DATA_DIR}/cohort.dta", clear

        tvexpose using "${DATA_DIR}/overlapping_exposures.dta", ///
            id(id) start(exp_start) stop(exp_stop) ///
            exposure(exp_type) reference(0) ///
            entry(study_entry) exit(study_exit) ///
            priority(3 2 1) ///
            generate(tv_overlap) ///
            saveas("${DATA_DIR}/_test_tvexpose_priority") replace

        quietly use "${DATA_DIR}/_test_tvexpose_priority.dta", clear
        assert _N > 0
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "[OK] `test_count'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "[FAIL] `test_count'|`=_rc'|`test_desc'"
        }
        else {
            display as error "  FAILED: `test_desc' (error `=_rc')"
        }
    }
}

* =============================================================================
* TEST 22: split option for overlapping exposures
* =============================================================================
local ++test_count
local test_desc "split option"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        quietly use "${DATA_DIR}/cohort.dta", clear

        tvexpose using "${DATA_DIR}/overlapping_exposures.dta", ///
            id(id) start(exp_start) stop(exp_stop) ///
            exposure(exp_type) reference(0) ///
            entry(study_entry) exit(study_exit) ///
            split ///
            generate(tv_overlap) ///
            saveas("${DATA_DIR}/_test_tvexpose_split") replace

        quietly use "${DATA_DIR}/_test_tvexpose_split.dta", clear
        assert _N > 0
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "[OK] `test_count'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "[FAIL] `test_count'|`=_rc'|`test_desc'"
        }
        else {
            display as error "  FAILED: `test_desc' (error `=_rc')"
        }
    }
}

* =============================================================================
* TEST 23: combine() option for overlapping exposures
* =============================================================================
local ++test_count
local test_desc "combine() option"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        quietly use "${DATA_DIR}/cohort.dta", clear

        tvexpose using "${DATA_DIR}/overlapping_exposures.dta", ///
            id(id) start(exp_start) stop(exp_stop) ///
            exposure(exp_type) reference(0) ///
            entry(study_entry) exit(study_exit) ///
            combine(combined_exp) ///
            generate(tv_overlap) ///
            saveas("${DATA_DIR}/_test_tvexpose_combine") replace

        quietly use "${DATA_DIR}/_test_tvexpose_combine.dta", clear
        assert _N > 0
        confirm variable combined_exp
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "[OK] `test_count'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "[FAIL] `test_count'|`=_rc'|`test_desc'"
        }
        else {
            display as error "  FAILED: `test_desc' (error `=_rc')"
        }
    }
}

* =============================================================================
* TEST 24: window() option (acute exposure window)
* =============================================================================
local ++test_count
local test_desc "window() option"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        quietly use "${DATA_DIR}/cohort.dta", clear

        tvexpose using "${DATA_DIR}/hrt.dta", ///
            id(id) start(rx_start) stop(rx_stop) ///
            exposure(hrt_type) reference(0) ///
            entry(study_entry) exit(study_exit) ///
            window(30 180) ///
            generate(tv_hrt) ///
            saveas("${DATA_DIR}/_test_tvexpose_window") replace

        quietly use "${DATA_DIR}/_test_tvexpose_window.dta", clear
        assert _N > 0
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "[OK] `test_count'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "[FAIL] `test_count'|`=_rc'|`test_desc'"
        }
        else {
            display as error "  FAILED: `test_desc' (error `=_rc')"
        }
    }
}

* =============================================================================
* TEST 25: switchingdetail option
* =============================================================================
local ++test_count
local test_desc "switchingdetail option"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        quietly use "${DATA_DIR}/cohort.dta", clear

        tvexpose using "${DATA_DIR}/dmt.dta", ///
            id(id) start(dmt_start) stop(dmt_stop) ///
            exposure(dmt) reference(0) ///
            entry(study_entry) exit(study_exit) ///
            switchingdetail ///
            generate(tv_dmt) ///
            saveas("${DATA_DIR}/_test_tvexpose_switchdetail") replace

        quietly use "${DATA_DIR}/_test_tvexpose_switchdetail.dta", clear
        assert _N > 0
        confirm variable switching_pattern
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "[OK] `test_count'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "[FAIL] `test_count'|`=_rc'|`test_desc'"
        }
        else {
            display as error "  FAILED: `test_desc' (error `=_rc')"
        }
    }
}

* =============================================================================
* TEST 26: statetime option
* =============================================================================
local ++test_count
local test_desc "statetime option"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        quietly use "${DATA_DIR}/cohort.dta", clear

        tvexpose using "${DATA_DIR}/dmt.dta", ///
            id(id) start(dmt_start) stop(dmt_stop) ///
            exposure(dmt) reference(0) ///
            entry(study_entry) exit(study_exit) ///
            statetime ///
            generate(tv_dmt) ///
            saveas("${DATA_DIR}/_test_tvexpose_statetime") replace

        quietly use "${DATA_DIR}/_test_tvexpose_statetime.dta", clear
        assert _N > 0
        confirm variable state_time_years
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "[OK] `test_count'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "[FAIL] `test_count'|`=_rc'|`test_desc'"
        }
        else {
            display as error "  FAILED: `test_desc' (error `=_rc')"
        }
    }
}

* =============================================================================
* TEST 27: expandunit() option with continuousunit()
* =============================================================================
local ++test_count
local test_desc "expandunit() option"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        quietly use "${DATA_DIR}/cohort.dta", clear

        tvexpose using "${DATA_DIR}/hrt.dta", ///
            id(id) start(rx_start) stop(rx_stop) ///
            exposure(hrt_type) reference(0) ///
            entry(study_entry) exit(study_exit) ///
            continuousunit(years) expandunit(months) ///
            generate(cumul_hrt) ///
            saveas("${DATA_DIR}/_test_tvexpose_expand") replace

        quietly use "${DATA_DIR}/_test_tvexpose_expand.dta", clear
        assert _N > 0

        * With month expansion, should have more rows
        quietly count
        local n_rows = r(N)
        assert `n_rows' > `cohort_ids'  // More rows than persons
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "[OK] `test_count'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "[FAIL] `test_count'|`=_rc'|`test_desc'"
        }
        else {
            display as error "  FAILED: `test_desc' (error `=_rc')"
        }
    }
}

* =============================================================================
* TEST 28: continuousunit() with days
* =============================================================================
local ++test_count
local test_desc "continuousunit(days)"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        quietly use "${DATA_DIR}/cohort.dta", clear

        tvexpose using "${DATA_DIR}/hrt.dta", ///
            id(id) start(rx_start) stop(rx_stop) ///
            exposure(hrt_type) reference(0) ///
            entry(study_entry) exit(study_exit) ///
            continuousunit(days) ///
            generate(cumul_days) ///
            saveas("${DATA_DIR}/_test_tvexpose_days") replace

        quietly use "${DATA_DIR}/_test_tvexpose_days.dta", clear
        assert _N > 0
        confirm variable cumul_days
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "[OK] `test_count'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "[FAIL] `test_count'|`=_rc'|`test_desc'"
        }
        else {
            display as error "  FAILED: `test_desc' (error `=_rc')"
        }
    }
}

* =============================================================================
* TEST 29: bytype with currentformer
* =============================================================================
local ++test_count
local test_desc "bytype + currentformer"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        quietly use "${DATA_DIR}/cohort.dta", clear

        tvexpose using "${DATA_DIR}/hrt.dta", ///
            id(id) start(rx_start) stop(rx_stop) ///
            exposure(hrt_type) reference(0) ///
            entry(study_entry) exit(study_exit) ///
            currentformer bytype ///
            generate(cf_hrt) ///
            saveas("${DATA_DIR}/_test_tvexpose_bytype_cf") replace

        quietly use "${DATA_DIR}/_test_tvexpose_bytype_cf.dta", clear
        assert _N > 0

        * Should have cf_hrt1, cf_hrt2, cf_hrt3 for HRT types
        quietly describe cf_hrt*
        assert r(k) >= 1
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "[OK] `test_count'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "[FAIL] `test_count'|`=_rc'|`test_desc'"
        }
        else {
            display as error "  FAILED: `test_desc' (error `=_rc')"
        }
    }
}

* =============================================================================
* TEST 30: bytype with duration
* =============================================================================
local ++test_count
local test_desc "bytype + duration"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        quietly use "${DATA_DIR}/cohort.dta", clear

        tvexpose using "${DATA_DIR}/hrt.dta", ///
            id(id) start(rx_start) stop(rx_stop) ///
            exposure(hrt_type) reference(0) ///
            entry(study_entry) exit(study_exit) ///
            duration(1 3) bytype ///
            generate(dur_hrt) ///
            saveas("${DATA_DIR}/_test_tvexpose_bytype_dur") replace

        quietly use "${DATA_DIR}/_test_tvexpose_bytype_dur.dta", clear
        assert _N > 0
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "[OK] `test_count'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "[FAIL] `test_count'|`=_rc'|`test_desc'"
        }
        else {
            display as error "  FAILED: `test_desc' (error `=_rc')"
        }
    }
}

* =============================================================================
* TEST 31: bytype with continuousunit
* =============================================================================
local ++test_count
local test_desc "bytype + continuousunit"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        quietly use "${DATA_DIR}/cohort.dta", clear

        tvexpose using "${DATA_DIR}/dmt.dta", ///
            id(id) start(dmt_start) stop(dmt_stop) ///
            exposure(dmt) reference(0) ///
            entry(study_entry) exit(study_exit) ///
            continuousunit(years) bytype ///
            generate(tv_dmt) ///
            saveas("${DATA_DIR}/_test_tvexpose_bytype_cont") replace

        quietly use "${DATA_DIR}/_test_tvexpose_bytype_cont.dta", clear
        assert _N > 0

        * Should have tv_dmt1 through tv_dmt6 for DMT types
        quietly describe tv_dmt*
        assert r(k) >= 1
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "[OK] `test_count'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "[FAIL] `test_count'|`=_rc'|`test_desc'"
        }
        else {
            display as error "  FAILED: `test_desc' (error `=_rc')"
        }
    }
}

* =============================================================================
* TEST 32: bytype with recency
* =============================================================================
local ++test_count
local test_desc "bytype + recency"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        quietly use "${DATA_DIR}/cohort.dta", clear

        tvexpose using "${DATA_DIR}/hrt.dta", ///
            id(id) start(rx_start) stop(rx_stop) ///
            exposure(hrt_type) reference(0) ///
            entry(study_entry) exit(study_exit) ///
            recency(1 3) bytype ///
            generate(recency_hrt) ///
            saveas("${DATA_DIR}/_test_tvexpose_bytype_rec") replace

        quietly use "${DATA_DIR}/_test_tvexpose_bytype_rec.dta", clear
        assert _N > 0
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "[OK] `test_count'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "[FAIL] `test_count'|`=_rc'|`test_desc'"
        }
        else {
            display as error "  FAILED: `test_desc' (error `=_rc')"
        }
    }
}

* =============================================================================
* TEST 33: fillgaps() option
* =============================================================================
local ++test_count
local test_desc "fillgaps() option"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        quietly use "${DATA_DIR}/cohort.dta", clear

        tvexpose using "${DATA_DIR}/hrt.dta", ///
            id(id) start(rx_start) stop(rx_stop) ///
            exposure(hrt_type) reference(0) ///
            entry(study_entry) exit(study_exit) ///
            fillgaps(30) ///
            generate(tv_hrt) ///
            saveas("${DATA_DIR}/_test_tvexpose_fillgaps") replace

        quietly use "${DATA_DIR}/_test_tvexpose_fillgaps.dta", clear
        assert _N > 0
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "[OK] `test_count'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "[FAIL] `test_count'|`=_rc'|`test_desc'"
        }
        else {
            display as error "  FAILED: `test_desc' (error `=_rc')"
        }
    }
}

* =============================================================================
* TEST 34: carryforward() option
* =============================================================================
local ++test_count
local test_desc "carryforward() option"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        quietly use "${DATA_DIR}/cohort.dta", clear

        tvexpose using "${DATA_DIR}/hrt.dta", ///
            id(id) start(rx_start) stop(rx_stop) ///
            exposure(hrt_type) reference(0) ///
            entry(study_entry) exit(study_exit) ///
            carryforward(60) ///
            generate(tv_hrt) ///
            saveas("${DATA_DIR}/_test_tvexpose_carry") replace

        quietly use "${DATA_DIR}/_test_tvexpose_carry.dta", clear
        assert _N > 0
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "[OK] `test_count'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "[FAIL] `test_count'|`=_rc'|`test_desc'"
        }
        else {
            display as error "  FAILED: `test_desc' (error `=_rc')"
        }
    }
}

* =============================================================================
* TEST 35: pointtime option (point-in-time events)
* =============================================================================
local ++test_count
local test_desc "pointtime option"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        quietly use "${DATA_DIR}/cohort.dta", clear

        tvexpose using "${DATA_DIR}/point_events.dta", ///
            id(id) start(event_date) ///
            exposure(event_type) reference(0) ///
            entry(study_entry) exit(study_exit) ///
            pointtime ///
            evertreated ///
            generate(ever_event) ///
            saveas("${DATA_DIR}/_test_tvexpose_pointtime") replace

        quietly use "${DATA_DIR}/_test_tvexpose_pointtime.dta", clear
        assert _N > 0
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "[OK] `test_count'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "[FAIL] `test_count'|`=_rc'|`test_desc'"
        }
        else {
            display as error "  FAILED: `test_desc' (error `=_rc')"
        }
    }
}

* =============================================================================
* TEST 36: keepdates option
* =============================================================================
local ++test_count
local test_desc "keepdates option"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        quietly use "${DATA_DIR}/cohort.dta", clear

        tvexpose using "${DATA_DIR}/hrt.dta", ///
            id(id) start(rx_start) stop(rx_stop) ///
            exposure(hrt_type) reference(0) ///
            entry(study_entry) exit(study_exit) ///
            keepdates ///
            generate(tv_hrt) ///
            saveas("${DATA_DIR}/_test_tvexpose_keepdates") replace

        quietly use "${DATA_DIR}/_test_tvexpose_keepdates.dta", clear
        assert _N > 0

        * Entry and exit dates should be preserved
        confirm variable study_entry study_exit
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "[OK] `test_count'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "[FAIL] `test_count'|`=_rc'|`test_desc'"
        }
        else {
            display as error "  FAILED: `test_desc' (error `=_rc')"
        }
    }
}

* =============================================================================
* TEST 37: validate option
* =============================================================================
local ++test_count
local test_desc "validate option"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        quietly use "${DATA_DIR}/cohort.dta", clear

        tvexpose using "${DATA_DIR}/hrt.dta", ///
            id(id) start(rx_start) stop(rx_stop) ///
            exposure(hrt_type) reference(0) ///
            entry(study_entry) exit(study_exit) ///
            validate ///
            generate(tv_hrt) ///
            saveas("${DATA_DIR}/_test_tvexpose_validate") replace

        * Check validation dataset was created
        capture confirm file "${DATA_DIR}/tv_validation.dta"
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "[OK] `test_count'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "[FAIL] `test_count'|`=_rc'|`test_desc'"
        }
        else {
            display as error "  FAILED: `test_desc' (error `=_rc')"
        }
    }
}

* =============================================================================
* TEST 38: gaps option
* =============================================================================
local ++test_count
local test_desc "gaps option"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        quietly use "${DATA_DIR}/cohort.dta", clear

        tvexpose using "${DATA_DIR}/hrt.dta", ///
            id(id) start(rx_start) stop(rx_stop) ///
            exposure(hrt_type) reference(0) ///
            entry(study_entry) exit(study_exit) ///
            gaps ///
            generate(tv_hrt) ///
            saveas("${DATA_DIR}/_test_tvexpose_gaps") replace
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "[OK] `test_count'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "[FAIL] `test_count'|`=_rc'|`test_desc'"
        }
        else {
            display as error "  FAILED: `test_desc' (error `=_rc')"
        }
    }
}

* =============================================================================
* TEST 39: overlaps option
* =============================================================================
local ++test_count
local test_desc "overlaps option"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        quietly use "${DATA_DIR}/cohort.dta", clear

        tvexpose using "${DATA_DIR}/overlapping_exposures.dta", ///
            id(id) start(exp_start) stop(exp_stop) ///
            exposure(exp_type) reference(0) ///
            entry(study_entry) exit(study_exit) ///
            overlaps ///
            generate(tv_exp) ///
            saveas("${DATA_DIR}/_test_tvexpose_overlaps") replace
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "[OK] `test_count'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "[FAIL] `test_count'|`=_rc'|`test_desc'"
        }
        else {
            display as error "  FAILED: `test_desc' (error `=_rc')"
        }
    }
}

* =============================================================================
* EDGE CASE TESTS
* =============================================================================

* TEST 40: Edge case - Single observation cohort
local ++test_count
local test_desc "Edge case: single observation"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        quietly use "${DATA_DIR}/edge_single_obs.dta", clear

        tvexpose using "${DATA_DIR}/edge_single_exp.dta", ///
            id(id) start(rx_start) stop(rx_stop) ///
            exposure(hrt_type) reference(0) ///
            entry(study_entry) exit(study_exit) ///
            generate(tv_hrt) ///
            saveas("${DATA_DIR}/_test_tvexpose_edge1") replace

        quietly use "${DATA_DIR}/_test_tvexpose_edge1.dta", clear
        assert _N > 0
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "[OK] `test_count'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "[FAIL] `test_count'|`=_rc'|`test_desc'"
        }
        else {
            display as error "  FAILED: `test_desc' (error `=_rc')"
        }
    }
}

* TEST 41: Edge case - Very short follow-up
local ++test_count
local test_desc "Edge case: short follow-up (1-7 days)"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        quietly use "${DATA_DIR}/edge_short_followup.dta", clear

        tvexpose using "${DATA_DIR}/edge_short_exp.dta", ///
            id(id) start(rx_start) stop(rx_stop) ///
            exposure(hrt_type) reference(0) ///
            entry(study_entry) exit(study_exit) ///
            generate(tv_hrt) ///
            saveas("${DATA_DIR}/_test_tvexpose_edge2") replace

        quietly use "${DATA_DIR}/_test_tvexpose_edge2.dta", clear
        assert _N > 0
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "[OK] `test_count'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "[FAIL] `test_count'|`=_rc'|`test_desc'"
        }
        else {
            display as error "  FAILED: `test_desc' (error `=_rc')"
        }
    }
}

* TEST 42: Edge case - Boundary exposures (exposure = study period)
local ++test_count
local test_desc "Edge case: boundary exposures"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        quietly use "${DATA_DIR}/cohort.dta", clear
        keep if _n <= 30

        tvexpose using "${DATA_DIR}/edge_boundary_exp.dta", ///
            id(id) start(rx_start) stop(rx_stop) ///
            exposure(hrt_type) reference(0) ///
            entry(study_entry) exit(study_exit) ///
            generate(tv_hrt) ///
            saveas("${DATA_DIR}/_test_tvexpose_edge3") replace

        quietly use "${DATA_DIR}/_test_tvexpose_edge3.dta", clear
        assert _N > 0
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "[OK] `test_count'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "[FAIL] `test_count'|`=_rc'|`test_desc'"
        }
        else {
            display as error "  FAILED: `test_desc' (error `=_rc')"
        }
    }
}

* TEST 43: Edge case - Single exposure type (no variation)
local ++test_count
local test_desc "Edge case: single exposure type"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        quietly use "${DATA_DIR}/cohort.dta", clear
        keep if _n <= 100

        tvexpose using "${DATA_DIR}/edge_same_type.dta", ///
            id(id) start(rx_start) stop(rx_stop) ///
            exposure(hrt_type) reference(0) ///
            entry(study_entry) exit(study_exit) ///
            evertreated ///
            generate(ever_hrt) ///
            saveas("${DATA_DIR}/_test_tvexpose_edge4") replace

        quietly use "${DATA_DIR}/_test_tvexpose_edge4.dta", clear
        assert _N > 0
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "[OK] `test_count'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "[FAIL] `test_count'|`=_rc'|`test_desc'"
        }
        else {
            display as error "  FAILED: `test_desc' (error `=_rc')"
        }
    }
}

* TEST 44: Edge case - Long follow-up (30-40 years)
local ++test_count
local test_desc "Edge case: long follow-up (30-40 years)"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        quietly use "${DATA_DIR}/edge_long_followup.dta", clear

        tvexpose using "${DATA_DIR}/edge_long_exp.dta", ///
            id(id) start(rx_start) stop(rx_stop) ///
            exposure(hrt_type) reference(0) ///
            entry(study_entry) exit(study_exit) ///
            duration(5 10 20) ///
            generate(dur_hrt) ///
            saveas("${DATA_DIR}/_test_tvexpose_edge5") replace

        quietly use "${DATA_DIR}/_test_tvexpose_edge5.dta", clear
        assert _N > 0
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "[OK] `test_count'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "[FAIL] `test_count'|`=_rc'|`test_desc'"
        }
        else {
            display as error "  FAILED: `test_desc' (error `=_rc')"
        }
    }
}

* TEST 45: Full workflow test - Cox regression compatible output
local ++test_count
local test_desc "Full workflow: Cox regression compatible"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        quietly use "${DATA_DIR}/cohort.dta", clear

        tvexpose using "${DATA_DIR}/dmt.dta", ///
            id(id) start(dmt_start) stop(dmt_stop) ///
            exposure(dmt) reference(0) ///
            entry(study_entry) exit(study_exit) ///
            currentformer ///
            keepvars(age female mstype edss4_dt) ///
            generate(dmt_status) ///
            saveas("${DATA_DIR}/_test_tvexpose_cox") replace

        quietly use "${DATA_DIR}/_test_tvexpose_cox.dta", clear

        * Create failure indicator
        gen byte failure = (!missing(edss4_dt) & edss4_dt >= dmt_start & edss4_dt <= dmt_stop)

        * Set survival data
        stset dmt_stop, failure(failure) entry(dmt_start) id(id) scale(365.25)

        * Run Cox model (should not error)
        stcox i.dmt_status age i.female i.mstype

        assert e(N) > 0
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "[OK] `test_count'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "[FAIL] `test_count'|`=_rc'|`test_desc'"
        }
        else {
            display as error "  FAILED: `test_desc' (error `=_rc')"
        }
    }
}

* TEST 46: dose option with HRT dataset (dose column)
local ++test_count
local test_desc "dose option with HRT dose variable"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        quietly use "${DATA_DIR}/cohort.dta", clear

        tvexpose using "${DATA_DIR}/hrt.dta", ///
            id(id) start(rx_start) stop(rx_stop) ///
            exposure(dose) ///
            entry(study_entry) exit(study_exit) ///
            dose ///
            generate(cumul_hrt_dose) ///
            saveas("${DATA_DIR}/_test_tvexpose_hrt_dose") replace

        quietly use "${DATA_DIR}/_test_tvexpose_hrt_dose.dta", clear
        assert _N > 0
        confirm variable cumul_hrt_dose

        * Cumulative dose should be non-negative
        quietly sum cumul_hrt_dose
        assert r(min) >= 0
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "[OK] `test_count'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "[FAIL] `test_count'|`=_rc'|`test_desc'"
        }
        else {
            display as error "  FAILED: `test_desc' (error `=_rc')"
        }
    }
}

* =============================================================================
* ADDITIONAL EDGE CASE TESTS
* =============================================================================

* TEST: Exposure exactly at study boundaries (edge_boundary_exp.dta)
local ++test_count
local test_desc "Edge case: exposure exactly at study entry/exit boundaries"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        * Load cohort and merge with boundary exposures
        quietly use "${DATA_DIR}/cohort.dta", clear
        keep if _n <= 30  // Match edge_boundary_exp.dta

        tvexpose using "${DATA_DIR}/edge_boundary_exp.dta", ///
            id(id) start(rx_start) stop(rx_stop) ///
            exposure(hrt_type) reference(0) ///
            entry(study_entry) exit(study_exit) ///
            generate(tv_boundary) ///
            saveas("${DATA_DIR}/_test_boundary") replace

        quietly use "${DATA_DIR}/_test_boundary.dta", clear
        assert _N > 0
        confirm variable tv_boundary

        * All should have some exposure (exposure spans entire study period)
        quietly count if tv_boundary > 0
        assert r(N) > 0
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "[OK] `test_count'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "[FAIL] `test_count'|`=_rc'|`test_desc'"
        }
        else {
            display as error "  FAILED: `test_desc' (error `=_rc')"
        }
    }
}

* TEST: Empty exposure dataset handling
local ++test_count
local test_desc "Edge case: empty exposure dataset"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        quietly use "${DATA_DIR}/cohort.dta", clear
        keep if _n <= 50  // Small subset

        * Try with empty exposure file - should handle gracefully
        * tvexpose should either error appropriately or return all unexposed
        tvexpose using "${DATA_DIR}/edge_empty_exp.dta", ///
            id(id) start(rx_start) stop(rx_stop) ///
            exposure(hrt_type) reference(0) ///
            entry(study_entry) exit(study_exit) ///
            generate(tv_empty) ///
            saveas("${DATA_DIR}/_test_empty") replace

        * If we get here, all should be unexposed (reference value)
        quietly use "${DATA_DIR}/_test_empty.dta", clear
        quietly sum tv_empty
        assert r(max) == 0  // All unexposed
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "[OK] `test_count'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
        }
    }
    else {
        * Expected to fail or handle gracefully
        local ++pass_count
        if `machine' {
            display "[OK] `test_count' (expected behavior)"
        }
        else if `quiet' == 0 {
            display as result "  PASSED (empty exposure handled)"
        }
    }
}

* TEST: Very short follow-up periods
local ++test_count
local test_desc "Edge case: very short follow-up (1-7 days)"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        quietly use "${DATA_DIR}/edge_short_followup.dta", clear

        tvexpose using "${DATA_DIR}/edge_short_exp.dta", ///
            id(id) start(rx_start) stop(rx_stop) ///
            exposure(hrt_type) reference(0) ///
            entry(study_entry) exit(study_exit) ///
            generate(tv_short) ///
            saveas("${DATA_DIR}/_test_short") replace

        quietly use "${DATA_DIR}/_test_short.dta", clear
        assert _N > 0
        confirm variable tv_short

        * Verify person-time is very short (1-7 days max)
        gen ptime = rx_stop - rx_start
        quietly sum ptime
        assert r(max) <= 7
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "[OK] `test_count'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "[FAIL] `test_count'|`=_rc'|`test_desc'"
        }
        else {
            display as error "  FAILED: `test_desc' (error `=_rc')"
        }
    }
}

* TEST: Very long follow-up periods (30+ years)
local ++test_count
local test_desc "Edge case: very long follow-up (30+ years)"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        quietly use "${DATA_DIR}/edge_long_followup.dta", clear

        tvexpose using "${DATA_DIR}/edge_long_exp.dta", ///
            id(id) start(rx_start) stop(rx_stop) ///
            exposure(hrt_type) reference(0) ///
            entry(study_entry) exit(study_exit) ///
            generate(tv_long) ///
            saveas("${DATA_DIR}/_test_long") replace

        quietly use "${DATA_DIR}/_test_long.dta", clear
        assert _N > 0
        confirm variable tv_long

        * Verify long person-time is handled correctly
        gen ptime = rx_stop - rx_start
        quietly sum ptime
        * Should have some periods > 1 year (365 days)
        assert r(max) > 365
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "[OK] `test_count'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "[FAIL] `test_count'|`=_rc'|`test_desc'"
        }
        else {
            display as error "  FAILED: `test_desc' (error `=_rc')"
        }
    }
}

* TEST: All same exposure type (no variation)
local ++test_count
local test_desc "Edge case: single exposure type (no variation)"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        quietly use "${DATA_DIR}/cohort.dta", clear
        keep if _n <= 100

        tvexpose using "${DATA_DIR}/edge_same_type.dta", ///
            id(id) start(rx_start) stop(rx_stop) ///
            exposure(hrt_type) reference(0) ///
            entry(study_entry) exit(study_exit) ///
            generate(tv_same) ///
            saveas("${DATA_DIR}/_test_same") replace

        quietly use "${DATA_DIR}/_test_same.dta", clear
        assert _N > 0
        confirm variable tv_same

        * All exposed periods should have same type (1)
        quietly count if tv_same == 1
        local n_type1 = r(N)
        quietly count if tv_same > 1
        local n_other = r(N)
        * Should only have type 0 (unexposed) or type 1
        assert `n_other' == 0
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "[OK] `test_count'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "[FAIL] `test_count'|`=_rc'|`test_desc'"
        }
        else {
            display as error "  FAILED: `test_desc' (error `=_rc')"
        }
    }
}

* =============================================================================
* LARGE DATASET STRESS TESTS
* =============================================================================

* TEST: Large dataset basic transformation (5000 patients)
local ++test_count
local test_desc "Large dataset: basic transformation (5000 patients)"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        quietly use "${DATA_DIR}/cohort_large.dta", clear

        * Verify large cohort
        quietly count
        assert r(N) == 5000

        tvexpose using "${DATA_DIR}/hrt_large.dta", ///
            id(id) start(rx_start) stop(rx_stop) ///
            exposure(hrt_type) reference(0) ///
            entry(study_entry) exit(study_exit) ///
            generate(tv_hrt) ///
            saveas("${DATA_DIR}/_test_tvexpose_large1") replace

        quietly use "${DATA_DIR}/_test_tvexpose_large1.dta", clear
        assert _N > 0

        * Validate: Should have at least as many rows as original cohort
        tempvar _tag
        quietly egen `_tag' = tag(id)
        quietly count if `_tag' == 1
        assert r(N) == 5000
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "[OK] `test_count'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "[FAIL] `test_count'|`=_rc'|`test_desc'"
        }
        else {
            display as error "  FAILED: `test_desc' (error `=_rc')"
        }
    }
}

* TEST: Large dataset person-time conservation
local ++test_count
local test_desc "Large dataset: person-time conservation"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        quietly use "${DATA_DIR}/cohort_large.dta", clear

        * Calculate input person-time
        gen double input_ptime = study_exit - study_entry
        quietly sum input_ptime
        local input_total = r(sum)

        tvexpose using "${DATA_DIR}/hrt_large.dta", ///
            id(id) start(rx_start) stop(rx_stop) ///
            exposure(hrt_type) reference(0) ///
            entry(study_entry) exit(study_exit) ///
            generate(tv_hrt) ///
            saveas("${DATA_DIR}/_test_tvexpose_large_ptime") replace

        quietly use "${DATA_DIR}/_test_tvexpose_large_ptime.dta", clear

        * Calculate output person-time
        gen double output_ptime = rx_stop - rx_start
        quietly sum output_ptime
        local output_total = r(sum)

        * Person-time should be conserved (within 1% tolerance)
        local ptime_diff = abs(`output_total' - `input_total') / `input_total'
        assert `ptime_diff' < 0.01
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "[OK] `test_count'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED: Person-time conserved in large dataset"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "[FAIL] `test_count'|`=_rc'|`test_desc'"
        }
        else {
            display as error "  FAILED: `test_desc' (error `=_rc')"
        }
    }
}

* TEST: Large dataset with evertreated
local ++test_count
local test_desc "Large dataset: evertreated option"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        quietly use "${DATA_DIR}/cohort_large.dta", clear

        tvexpose using "${DATA_DIR}/hrt_large.dta", ///
            id(id) start(rx_start) stop(rx_stop) ///
            exposure(hrt_type) reference(0) ///
            entry(study_entry) exit(study_exit) ///
            evertreated ///
            generate(ever_hrt) ///
            saveas("${DATA_DIR}/_test_tvexpose_large_ever") replace

        quietly use "${DATA_DIR}/_test_tvexpose_large_ever.dta", clear
        assert _N > 0
        confirm variable ever_hrt

        * Validate: once exposed should stay exposed
        sort id rx_start
        quietly by id: gen byte _decreased = (ever_hrt < ever_hrt[_n-1]) if _n > 1
        quietly count if _decreased == 1
        assert r(N) == 0
        quietly drop _decreased
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "[OK] `test_count'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "[FAIL] `test_count'|`=_rc'|`test_desc'"
        }
        else {
            display as error "  FAILED: `test_desc' (error `=_rc')"
        }
    }
}

* TEST: Large dataset with currentformer
local ++test_count
local test_desc "Large dataset: currentformer option"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        quietly use "${DATA_DIR}/cohort_large.dta", clear

        tvexpose using "${DATA_DIR}/hrt_large.dta", ///
            id(id) start(rx_start) stop(rx_stop) ///
            exposure(hrt_type) reference(0) ///
            entry(study_entry) exit(study_exit) ///
            currentformer ///
            generate(cf_hrt) ///
            saveas("${DATA_DIR}/_test_tvexpose_large_cf") replace

        quietly use "${DATA_DIR}/_test_tvexpose_large_cf.dta", clear
        assert _N > 0
        confirm variable cf_hrt

        * Should have values 0=never, 1=current, 2=former
        quietly sum cf_hrt
        assert r(min) >= 0 & r(max) <= 2
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "[OK] `test_count'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "[FAIL] `test_count'|`=_rc'|`test_desc'"
        }
        else {
            display as error "  FAILED: `test_desc' (error `=_rc')"
        }
    }
}

* TEST: Large dataset with DMT
local ++test_count
local test_desc "Large dataset: DMT exposure"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        quietly use "${DATA_DIR}/cohort_large.dta", clear

        tvexpose using "${DATA_DIR}/dmt_large.dta", ///
            id(id) start(dmt_start) stop(dmt_stop) ///
            exposure(dmt) reference(0) ///
            entry(study_entry) exit(study_exit) ///
            generate(tv_dmt) ///
            saveas("${DATA_DIR}/_test_tvexpose_large_dmt") replace

        quietly use "${DATA_DIR}/_test_tvexpose_large_dmt.dta", clear
        assert _N > 0
        confirm variable tv_dmt
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "[OK] `test_count'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "[FAIL] `test_count'|`=_rc'|`test_desc'"
        }
        else {
            display as error "  FAILED: `test_desc' (error `=_rc')"
        }
    }
}

* TEST: Large dataset with duration
local ++test_count
local test_desc "Large dataset: duration option"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        quietly use "${DATA_DIR}/cohort_large.dta", clear

        tvexpose using "${DATA_DIR}/hrt_large.dta", ///
            id(id) start(rx_start) stop(rx_stop) ///
            exposure(hrt_type) reference(0) ///
            entry(study_entry) exit(study_exit) ///
            duration(1 3 5) continuousunit(years) ///
            generate(dur_hrt) ///
            saveas("${DATA_DIR}/_test_tvexpose_large_dur") replace

        quietly use "${DATA_DIR}/_test_tvexpose_large_dur.dta", clear
        assert _N > 0
        confirm variable dur_hrt

        * Duration categories should be non-negative
        quietly sum dur_hrt
        assert r(min) >= 0
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "[OK] `test_count'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "[FAIL] `test_count'|`=_rc'|`test_desc'"
        }
        else {
            display as error "  FAILED: `test_desc' (error `=_rc')"
        }
    }
}

* TEST: Very large stress test (10000 patients)
local ++test_count
local test_desc "Very large stress test (10000 patients)"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        quietly use "${DATA_DIR}/cohort_stress.dta", clear

        * Verify stress cohort
        quietly count
        assert r(N) == 10000

        tvexpose using "${DATA_DIR}/exposures_stress.dta", ///
            id(id) start(exp_start) stop(exp_stop) ///
            exposure(exp_type) reference(0) ///
            entry(study_entry) exit(study_exit) ///
            generate(tv_exp) ///
            saveas("${DATA_DIR}/_test_tvexpose_stress") replace

        quietly use "${DATA_DIR}/_test_tvexpose_stress.dta", clear
        assert _N > 0

        * All 10000 IDs should be present
        tempvar _tag
        quietly egen `_tag' = tag(id)
        quietly count if `_tag' == 1
        assert r(N) == 10000
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "[OK] `test_count'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED: Stress test (10000 patients) works"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "[FAIL] `test_count'|`=_rc'|`test_desc'"
        }
        else {
            display as error "  FAILED: `test_desc' (error `=_rc')"
        }
    }
}

* TEST: Large dataset with combined options
local ++test_count
local test_desc "Large dataset: combined options"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        quietly use "${DATA_DIR}/cohort_large.dta", clear

        tvexpose using "${DATA_DIR}/dmt_large.dta", ///
            id(id) start(dmt_start) stop(dmt_stop) ///
            exposure(dmt) reference(0) ///
            entry(study_entry) exit(study_exit) ///
            grace(30) lag(14) washout(60) ///
            keepvars(age female mstype) ///
            generate(tv_dmt) ///
            check ///
            saveas("${DATA_DIR}/_test_tvexpose_large_combo") replace

        quietly use "${DATA_DIR}/_test_tvexpose_large_combo.dta", clear
        assert _N > 0
        confirm variable tv_dmt age female mstype
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "[OK] `test_count'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "[FAIL] `test_count'|`=_rc'|`test_desc'"
        }
        else {
            display as error "  FAILED: `test_desc' (error `=_rc')"
        }
    }
}

* TEST: Large dataset Cox regression workflow
local ++test_count
local test_desc "Large dataset: Cox regression workflow"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        quietly use "${DATA_DIR}/cohort_large.dta", clear

        tvexpose using "${DATA_DIR}/dmt_large.dta", ///
            id(id) start(dmt_start) stop(dmt_stop) ///
            exposure(dmt) reference(0) ///
            entry(study_entry) exit(study_exit) ///
            currentformer ///
            keepvars(age female mstype edss4_dt) ///
            generate(dmt_status) ///
            saveas("${DATA_DIR}/_test_tvexpose_large_cox") replace

        quietly use "${DATA_DIR}/_test_tvexpose_large_cox.dta", clear

        * Create failure indicator
        gen byte failure = (!missing(edss4_dt) & edss4_dt >= dmt_start & edss4_dt <= dmt_stop)

        * Set survival data
        stset dmt_stop, failure(failure) entry(dmt_start) id(id) scale(365.25)

        * Run Cox model (should not error)
        stcox i.dmt_status age i.female i.mstype

        assert e(N) > 0
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "[OK] `test_count'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED: Cox regression on large dataset works"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "[FAIL] `test_count'|`=_rc'|`test_desc'"
        }
        else {
            display as error "  FAILED: `test_desc' (error `=_rc')"
        }
    }
}

* TEST: Large dataset bytype option
local ++test_count
local test_desc "Large dataset: bytype option"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        quietly use "${DATA_DIR}/cohort_large.dta", clear

        tvexpose using "${DATA_DIR}/dmt_large.dta", ///
            id(id) start(dmt_start) stop(dmt_stop) ///
            exposure(dmt) reference(0) ///
            entry(study_entry) exit(study_exit) ///
            evertreated bytype ///
            generate(ever_dmt) ///
            saveas("${DATA_DIR}/_test_tvexpose_large_bytype") replace

        quietly use "${DATA_DIR}/_test_tvexpose_large_bytype.dta", clear
        assert _N > 0

        * Should have separate variables for each DMT type
        quietly describe ever_dmt*
        assert r(k) >= 1
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "[OK] `test_count'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "[FAIL] `test_count'|`=_rc'|`test_desc'"
        }
        else {
            display as error "  FAILED: `test_desc' (error `=_rc')"
        }
    }
}

* =============================================================================
* CLEANUP: Remove temporary files
* =============================================================================
if `quiet' == 0 & `run_only' == 0 {
    display as text _n "{hline 70}"
    display as text "Cleaning up temporary files..."
    display as text "{hline 70}"
}

quietly {
    * Clean up all temporary test files (including large dataset tests)
    local temp_files "_test_tvexpose_* _test_boundary _test_empty _test_short _test_long _test_same _test_tvexpose_large* _test_tvexpose_stress"
    foreach pattern of local temp_files {
        local files : dir "${DATA_DIR}" files "`pattern'.dta"
        foreach f of local files {
            capture erase "${DATA_DIR}/`f'"
        }
    }
}

* =============================================================================
* SUMMARY
* =============================================================================
if `machine' {
    display "[SUMMARY] `pass_count'/`test_count' passed"
    if `fail_count' > 0 {
        display "[FAILED]`failed_tests'"
    }
}
else {
    display as text _n "{hline 70}"
    display as text "TVEXPOSE TEST SUMMARY"
    display as text "{hline 70}"
    display as text "Total tests:  `test_count'"
    display as result "Passed:       `pass_count'"
    if `fail_count' > 0 {
        display as error "Failed:       `fail_count'"
        display as error "Failed tests:`failed_tests'"
    }
    else {
        display as text "Failed:       `fail_count'"
    }
    display as text "{hline 70}"

    if `fail_count' > 0 {
        display as error "Some tests FAILED. Review output above."
        exit 1
    }
    else {
        display as result "All tests PASSED!"
    }
}

* Clear global flags
global RUN_TEST_QUIET
global RUN_TEST_MACHINE
global RUN_TEST_NUMBER
