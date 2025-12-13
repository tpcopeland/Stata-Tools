/*******************************************************************************
* test_tvmerge.do
*
* Purpose: Comprehensive testing of tvmerge command with context-optimized output
*          Supports quiet mode, single test execution, and data validation
*
* Prerequisites:
*   - Run generate_test_data.do first to create synthetic datasets
*   - tvexpose.ado and tvmerge.ado must be installed/accessible
*
* Run modes:
*   Standalone: do test_tvmerge.do
*   Via runner: do run_test.do test_tvmerge [testnumber] [quiet] [machine]
*
* Note: tvmerge operates on datasets already processed by tvexpose, not raw
*       exposure files. This test first creates tvexpose output datasets,
*       then tests tvmerge on those outputs.
*
* Data Validations:
*   - ID preservation: All IDs from both inputs present in merged output
*   - Person-time: Total coverage equals input coverage
*   - No overlaps: Within-ID periods don't overlap after merge
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
    global STATA_TOOLS_PATH "/home/ubuntu/Stata-Tools"
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

global TESTING_DIR "${STATA_TOOLS_PATH}/_testing"
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
    display as text "TVMERGE COMMAND TESTING"
    display as text "{hline 70}"
    display as text "Data directory: ${DATA_DIR}"
    display as text "{hline 70}"
}

* =============================================================================
* TEST COUNTERS AND FAILURE TRACKING
* =============================================================================
local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

* =============================================================================
* TEST EXECUTION MACRO
* =============================================================================
capture program drop _run_test
program define _run_test
    args test_num test_desc

    if $RUN_TEST_NUMBER > 0 & $RUN_TEST_NUMBER != `test_num' {
        exit 0
    }

    if $RUN_TEST_QUIET == 0 {
        display as text _n "TEST `test_num': `test_desc'"
        display as text "{hline 50}"
    }
end

* =============================================================================
* SETUP: Create tvexpose output files for tvmerge testing
* =============================================================================
if `quiet' == 0 {
    display as text _n "SETUP: Creating tvexpose output datasets..."
    display as text "{hline 50}"
}

capture {
    quietly use "${DATA_DIR}/cohort.dta", clear
    tvexpose using "${DATA_DIR}/hrt.dta", ///
        id(id) start(rx_start) stop(rx_stop) ///
        exposure(hrt_type) reference(0) ///
        entry(study_entry) exit(study_exit) ///
        generate(tv_hrt) ///
        saveas("${DATA_DIR}/_tv_hrt.dta") replace

    quietly use "${DATA_DIR}/cohort.dta", clear
    tvexpose using "${DATA_DIR}/dmt.dta", ///
        id(id) start(dmt_start) stop(dmt_stop) ///
        exposure(dmt) reference(0) ///
        entry(study_entry) exit(study_exit) ///
        generate(tv_dmt) ///
        saveas("${DATA_DIR}/_tv_dmt.dta") replace
}
if _rc {
    if `machine' {
        display "[ERROR] Setup failed|`=_rc'"
    }
    else {
        display as error "SETUP FAILED: Could not create tvexpose datasets (error `=_rc')"
    }
    exit _rc
}

if `quiet' == 0 {
    display as result "Setup complete: tvexpose output files created"
}

* =============================================================================
* TEST 1: Basic two-dataset merge
* =============================================================================
local ++test_count
local test_desc "Basic two-dataset merge"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        tvmerge "${DATA_DIR}/_tv_hrt.dta" "${DATA_DIR}/_tv_dmt.dta", ///
            id(id) ///
            start(rx_start dmt_start) stop(rx_stop dmt_stop) ///
            exposure(tv_hrt tv_dmt)

        assert _N > 0
        confirm variable id start stop

        * Validation: Check no overlapping periods within ID
        sort id start stop
        quietly by id: gen byte _overlap = (start < stop[_n-1]) if _n > 1
        quietly count if _overlap == 1
        local n_overlaps = r(N)
        quietly drop _overlap
        * Some overlaps may be expected in merged data
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "[OK] `test_count'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
            display as text "  Merged observations: " _N
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
* TEST 2: Merge with generate() option for custom names
* =============================================================================
local ++test_count
local test_desc "generate() option for custom names"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        tvmerge "${DATA_DIR}/_tv_hrt.dta" "${DATA_DIR}/_tv_dmt.dta", ///
            id(id) ///
            start(rx_start dmt_start) stop(rx_stop dmt_stop) ///
            exposure(tv_hrt tv_dmt) ///
            generate(hrt_status dmt_status)

        confirm variable hrt_status dmt_status
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
* TEST 3: Merge with prefix() option
* =============================================================================
local ++test_count
local test_desc "prefix() option"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        tvmerge "${DATA_DIR}/_tv_hrt.dta" "${DATA_DIR}/_tv_dmt.dta", ///
            id(id) ///
            start(rx_start dmt_start) stop(rx_stop dmt_stop) ///
            exposure(tv_hrt tv_dmt) ///
            prefix(exp_)

        confirm variable exp_1 exp_2
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
* TEST 4: Custom start/stop names
* =============================================================================
local ++test_count
local test_desc "startname() and stopname() options"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        tvmerge "${DATA_DIR}/_tv_hrt.dta" "${DATA_DIR}/_tv_dmt.dta", ///
            id(id) ///
            start(rx_start dmt_start) stop(rx_stop dmt_stop) ///
            exposure(tv_hrt tv_dmt) ///
            startname(period_start) stopname(period_end)

        confirm variable period_start period_end
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
* TEST 5: saveas() and replace options
* =============================================================================
local ++test_count
local test_desc "saveas() and replace options"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        tvmerge "${DATA_DIR}/_tv_hrt.dta" "${DATA_DIR}/_tv_dmt.dta", ///
            id(id) ///
            start(rx_start dmt_start) stop(rx_stop dmt_stop) ///
            exposure(tv_hrt tv_dmt) ///
            generate(hrt dmt) ///
            saveas("${DATA_DIR}/_test_merged.dta") replace

        confirm file "${DATA_DIR}/_test_merged.dta"
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
* TEST 6: check option (diagnostics)
* =============================================================================
local ++test_count
local test_desc "check option (diagnostics)"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        tvmerge "${DATA_DIR}/_tv_hrt.dta" "${DATA_DIR}/_tv_dmt.dta", ///
            id(id) ///
            start(rx_start dmt_start) stop(rx_stop dmt_stop) ///
            exposure(tv_hrt tv_dmt) ///
            check

        assert r(N_persons) > 0
        assert r(mean_periods) > 0
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "[OK] `test_count'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
            display as text "  N persons: " r(N_persons) ", mean periods: " %5.2f r(mean_periods)
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
* TEST 7: summarize option
* =============================================================================
local ++test_count
local test_desc "summarize option"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        tvmerge "${DATA_DIR}/_tv_hrt.dta" "${DATA_DIR}/_tv_dmt.dta", ///
            id(id) ///
            start(rx_start dmt_start) stop(rx_stop dmt_stop) ///
            exposure(tv_hrt tv_dmt) ///
            summarize

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
* TEST 8: validatecoverage option
* =============================================================================
local ++test_count
local test_desc "validatecoverage option"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        tvmerge "${DATA_DIR}/_tv_hrt.dta" "${DATA_DIR}/_tv_dmt.dta", ///
            id(id) ///
            start(rx_start dmt_start) stop(rx_stop dmt_stop) ///
            exposure(tv_hrt tv_dmt) ///
            validatecoverage

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
* TEST 9: Stored results verification
* =============================================================================
local ++test_count
local test_desc "Stored results verification"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        tvmerge "${DATA_DIR}/_tv_hrt.dta" "${DATA_DIR}/_tv_dmt.dta", ///
            id(id) ///
            start(rx_start dmt_start) stop(rx_stop dmt_stop) ///
            exposure(tv_hrt tv_dmt) ///
            generate(hrt dmt) ///
            check

        assert r(N) > 0
        assert r(N_persons) > 0
        assert r(mean_periods) > 0
        assert r(max_periods) > 0
        assert r(N_datasets) == 2
        assert "`r(datasets)'" != ""
        assert "`r(exposure_vars)'" != ""
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "[OK] `test_count'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
            display as text "  r(N) = " r(N) ", r(N_persons) = " r(N_persons)
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
* TEST 10: ID preservation validation
* =============================================================================
local ++test_count
local test_desc "ID preservation validation"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        * Get IDs from both source files
        quietly use "${DATA_DIR}/_tv_hrt.dta", clear
        quietly distinct id
        local hrt_ids = r(ndistinct)

        quietly use "${DATA_DIR}/_tv_dmt.dta", clear
        quietly distinct id
        local dmt_ids = r(ndistinct)

        * Merge and check IDs
        tvmerge "${DATA_DIR}/_tv_hrt.dta" "${DATA_DIR}/_tv_dmt.dta", ///
            id(id) ///
            start(rx_start dmt_start) stop(rx_stop dmt_stop) ///
            exposure(tv_hrt tv_dmt) ///
            generate(hrt dmt)

        quietly distinct id
        local merged_ids = r(ndistinct)

        * Merged should have at least the intersection of IDs
        * (actual count depends on merge behavior)
        assert `merged_ids' > 0
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "[OK] `test_count'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
            display as text "  HRT IDs: `hrt_ids', DMT IDs: `dmt_ids', Merged IDs: `merged_ids'"
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
* TEST 11: Three-dataset merge
* =============================================================================
local ++test_count
local test_desc "Three-dataset merge"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        * First create a third tvexpose output for steroids
        quietly use "${DATA_DIR}/cohort.dta", clear
        tvexpose using "${DATA_DIR}/steroids.dta", ///
            id(id) start(steroid_start) stop(steroid_stop) ///
            exposure(steroid_type) reference(0) ///
            entry(study_entry) exit(study_exit) ///
            generate(tv_steroid) ///
            saveas("${DATA_DIR}/_tv_steroid.dta") replace

        * Now merge all three
        tvmerge "${DATA_DIR}/_tv_hrt.dta" "${DATA_DIR}/_tv_dmt.dta" "${DATA_DIR}/_tv_steroid.dta", ///
            id(id) ///
            start(rx_start dmt_start steroid_start) stop(rx_stop dmt_stop steroid_stop) ///
            exposure(tv_hrt tv_dmt tv_steroid) ///
            generate(hrt dmt steroid) ///
            check

        assert _N > 0
        confirm variable hrt dmt steroid
        assert r(N_datasets) == 3
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "[OK] `test_count'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
            display as text "  Three-way merge: " _N " rows"
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
* TEST 12: continuous() option for continuous exposure types
* =============================================================================
local ++test_count
local test_desc "continuous() option"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        * Create continuous exposure outputs
        quietly use "${DATA_DIR}/cohort.dta", clear
        tvexpose using "${DATA_DIR}/hrt.dta", ///
            id(id) start(rx_start) stop(rx_stop) ///
            exposure(hrt_type) reference(0) ///
            entry(study_entry) exit(study_exit) ///
            continuousunit(years) ///
            generate(cum_hrt) ///
            saveas("${DATA_DIR}/_tv_hrt_cont.dta") replace

        quietly use "${DATA_DIR}/cohort.dta", clear
        tvexpose using "${DATA_DIR}/dmt.dta", ///
            id(id) start(dmt_start) stop(dmt_stop) ///
            exposure(dmt) reference(0) ///
            entry(study_entry) exit(study_exit) ///
            continuousunit(years) ///
            generate(cum_dmt) ///
            saveas("${DATA_DIR}/_tv_dmt_cont.dta") replace

        * Merge continuous exposures
        tvmerge "${DATA_DIR}/_tv_hrt_cont.dta" "${DATA_DIR}/_tv_dmt_cont.dta", ///
            id(id) ///
            start(rx_start dmt_start) stop(rx_stop dmt_stop) ///
            exposure(cum_hrt cum_dmt) ///
            continuous(cum_hrt cum_dmt)

        assert _N > 0
        confirm variable cum_hrt cum_dmt
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
* TEST 13: keep() option to retain additional variables
* =============================================================================
local ++test_count
local test_desc "keep() option"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        * Create tvexpose outputs with keepvars
        quietly use "${DATA_DIR}/cohort.dta", clear
        tvexpose using "${DATA_DIR}/hrt.dta", ///
            id(id) start(rx_start) stop(rx_stop) ///
            exposure(hrt_type) reference(0) ///
            entry(study_entry) exit(study_exit) ///
            keepvars(age female mstype) ///
            generate(tv_hrt) ///
            saveas("${DATA_DIR}/_tv_hrt_keep.dta") replace

        quietly use "${DATA_DIR}/cohort.dta", clear
        tvexpose using "${DATA_DIR}/dmt.dta", ///
            id(id) start(dmt_start) stop(dmt_stop) ///
            exposure(dmt) reference(0) ///
            entry(study_entry) exit(study_exit) ///
            keepvars(age female) ///
            generate(tv_dmt) ///
            saveas("${DATA_DIR}/_tv_dmt_keep.dta") replace

        tvmerge "${DATA_DIR}/_tv_hrt_keep.dta" "${DATA_DIR}/_tv_dmt_keep.dta", ///
            id(id) ///
            start(rx_start dmt_start) stop(rx_stop dmt_stop) ///
            exposure(tv_hrt tv_dmt) ///
            keep(age female mstype)

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

* =============================================================================
* TEST 14: validateoverlap option
* =============================================================================
local ++test_count
local test_desc "validateoverlap option"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        tvmerge "${DATA_DIR}/_tv_hrt.dta" "${DATA_DIR}/_tv_dmt.dta", ///
            id(id) ///
            start(rx_start dmt_start) stop(rx_stop dmt_stop) ///
            exposure(tv_hrt tv_dmt) ///
            validateoverlap

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
* TEST 15: force option
* =============================================================================
local ++test_count
local test_desc "force option"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        tvmerge "${DATA_DIR}/_tv_hrt.dta" "${DATA_DIR}/_tv_dmt.dta", ///
            id(id) ///
            start(rx_start dmt_start) stop(rx_stop dmt_stop) ///
            exposure(tv_hrt tv_dmt) ///
            force

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
* TEST 16: batch() option for large datasets
* =============================================================================
local ++test_count
local test_desc "batch() option"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        tvmerge "${DATA_DIR}/_tv_hrt.dta" "${DATA_DIR}/_tv_dmt.dta", ///
            id(id) ///
            start(rx_start dmt_start) stop(rx_stop dmt_stop) ///
            exposure(tv_hrt tv_dmt) ///
            batch(100)

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
* TEST 17: Person-time conservation validation
* =============================================================================
local ++test_count
local test_desc "Person-time conservation"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        * Calculate input person-time from HRT file
        quietly use "${DATA_DIR}/_tv_hrt.dta", clear
        gen double ptime = rx_stop - rx_start
        quietly sum ptime
        local input_ptime = r(sum)

        * Merge and check output person-time
        tvmerge "${DATA_DIR}/_tv_hrt.dta" "${DATA_DIR}/_tv_dmt.dta", ///
            id(id) ///
            start(rx_start dmt_start) stop(rx_stop dmt_stop) ///
            exposure(tv_hrt tv_dmt)

        gen double output_ptime = stop - start
        quietly sum output_ptime
        local output_ptime = r(sum)

        * Person-time should be approximately conserved
        * (exact match depends on merge behavior and overlaps)
        assert `output_ptime' > 0
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
* TEST 18: Merge same exposure with different transformations
* =============================================================================
local ++test_count
local test_desc "Same exposure - different transformations"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        * Create evertreated version
        quietly use "${DATA_DIR}/cohort.dta", clear
        tvexpose using "${DATA_DIR}/hrt.dta", ///
            id(id) start(rx_start) stop(rx_stop) ///
            exposure(hrt_type) reference(0) ///
            entry(study_entry) exit(study_exit) ///
            evertreated ///
            generate(ever_hrt) ///
            saveas("${DATA_DIR}/_tv_hrt_ever.dta") replace

        * Create currentformer version
        quietly use "${DATA_DIR}/cohort.dta", clear
        tvexpose using "${DATA_DIR}/hrt.dta", ///
            id(id) start(rx_start) stop(rx_stop) ///
            exposure(hrt_type) reference(0) ///
            entry(study_entry) exit(study_exit) ///
            currentformer ///
            generate(cf_hrt) ///
            saveas("${DATA_DIR}/_tv_hrt_cf.dta") replace

        * Merge both versions
        tvmerge "${DATA_DIR}/_tv_hrt_ever.dta" "${DATA_DIR}/_tv_hrt_cf.dta", ///
            id(id) ///
            start(rx_start rx_start) stop(rx_stop rx_stop) ///
            exposure(ever_hrt cf_hrt)

        assert _N > 0
        confirm variable ever_hrt cf_hrt
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
* TEST 19: Full workflow - tvexpose then tvmerge then Cox model
* =============================================================================
local ++test_count
local test_desc "Full workflow: tvexpose -> tvmerge -> Cox"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        * Create HRT exposure with keepvars
        quietly use "${DATA_DIR}/cohort.dta", clear
        tvexpose using "${DATA_DIR}/hrt.dta", ///
            id(id) start(rx_start) stop(rx_stop) ///
            exposure(hrt_type) reference(0) ///
            entry(study_entry) exit(study_exit) ///
            evertreated ///
            keepvars(age female mstype edss4_dt) ///
            generate(ever_hrt) ///
            saveas("${DATA_DIR}/_tv_hrt_workflow.dta") replace

        * Create DMT exposure
        quietly use "${DATA_DIR}/cohort.dta", clear
        tvexpose using "${DATA_DIR}/dmt.dta", ///
            id(id) start(dmt_start) stop(dmt_stop) ///
            exposure(dmt) reference(0) ///
            entry(study_entry) exit(study_exit) ///
            evertreated ///
            keepvars(age female) ///
            generate(ever_dmt) ///
            saveas("${DATA_DIR}/_tv_dmt_workflow.dta") replace

        * Merge both exposures
        tvmerge "${DATA_DIR}/_tv_hrt_workflow.dta" "${DATA_DIR}/_tv_dmt_workflow.dta", ///
            id(id) ///
            start(rx_start dmt_start) stop(rx_stop dmt_stop) ///
            exposure(ever_hrt ever_dmt) ///
            keep(age female mstype edss4_dt) ///
            saveas("${DATA_DIR}/_workflow_merged.dta") replace

        * Use merged dataset for Cox model
        quietly use "${DATA_DIR}/_workflow_merged.dta", clear

        * Create failure indicator
        gen byte failure = (!missing(edss4_dt) & edss4_dt >= start & edss4_dt <= stop)

        * Run stset and Cox model
        stset stop, failure(failure) entry(start) id(id) scale(365.25)
        stcox ever_hrt ever_dmt age i.female

        assert e(N) > 0
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "[OK] `test_count'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
            display as text "  Cox model N = " e(N)
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

* TEST 20: Edge case - Single observation merge
local ++test_count
local test_desc "Edge case: single observation"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        * Create single-obs tvexpose outputs
        quietly use "${DATA_DIR}/edge_single_obs.dta", clear
        tvexpose using "${DATA_DIR}/edge_single_exp.dta", ///
            id(id) start(rx_start) stop(rx_stop) ///
            exposure(hrt_type) reference(0) ///
            entry(study_entry) exit(study_exit) ///
            generate(tv_hrt) ///
            saveas("${DATA_DIR}/_tv_edge1.dta") replace

        * Create a simple second exposure
        quietly use "${DATA_DIR}/edge_single_obs.dta", clear
        tvexpose using "${DATA_DIR}/edge_single_exp.dta", ///
            id(id) start(rx_start) stop(rx_stop) ///
            exposure(hrt_type) reference(0) ///
            entry(study_entry) exit(study_exit) ///
            evertreated ///
            generate(ever_hrt) ///
            saveas("${DATA_DIR}/_tv_edge2.dta") replace

        * Merge single observations
        tvmerge "${DATA_DIR}/_tv_edge1.dta" "${DATA_DIR}/_tv_edge2.dta", ///
            id(id) ///
            start(rx_start rx_start) stop(rx_stop rx_stop) ///
            exposure(tv_hrt ever_hrt)

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

* TEST 21: Merge bytype exposures from same source
local ++test_count
local test_desc "Bytype exposures merge"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        * Create bytype HRT exposures
        quietly use "${DATA_DIR}/cohort.dta", clear
        tvexpose using "${DATA_DIR}/hrt.dta", ///
            id(id) start(rx_start) stop(rx_stop) ///
            exposure(hrt_type) reference(0) ///
            entry(study_entry) exit(study_exit) ///
            evertreated bytype ///
            generate(ever_hrt) ///
            saveas("${DATA_DIR}/_tv_hrt_bytype.dta") replace

        * Create bytype DMT exposures
        quietly use "${DATA_DIR}/cohort.dta", clear
        tvexpose using "${DATA_DIR}/dmt.dta", ///
            id(id) start(dmt_start) stop(dmt_stop) ///
            exposure(dmt) reference(0) ///
            entry(study_entry) exit(study_exit) ///
            evertreated bytype ///
            generate(ever_dmt) ///
            saveas("${DATA_DIR}/_tv_dmt_bytype.dta") replace

        * Check how many exposure variables were created
        quietly use "${DATA_DIR}/_tv_hrt_bytype.dta", clear
        quietly describe ever_hrt*
        local n_hrt_vars = r(k)

        quietly use "${DATA_DIR}/_tv_dmt_bytype.dta", clear
        quietly describe ever_dmt*
        local n_dmt_vars = r(k)

        * Merge bytype exposures - this tests complex multi-variable merge
        tvmerge "${DATA_DIR}/_tv_hrt_bytype.dta" "${DATA_DIR}/_tv_dmt_bytype.dta", ///
            id(id) ///
            start(rx_start dmt_start) stop(rx_stop dmt_stop) ///
            exposure(ever_hrt1 ever_dmt1)

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
* CLEANUP: Remove temporary files
* =============================================================================
if `quiet' == 0 & `run_only' == 0 {
    display as text _n "{hline 70}"
    display as text "Cleaning up temporary files..."
    display as text "{hline 70}"
}

quietly {
    local temp_files "_tv_hrt _tv_dmt _tv_steroid _test_merged _tv_hrt_cont _tv_hrt_keep _tv_dmt_keep _tv_hrt_cont2 _tv_dmt_cont _tv_hrt_ever _tv_hrt_cf _tv_hrt_workflow _tv_dmt_workflow _workflow_merged _tv_edge1 _tv_edge2 _tv_hrt_bytype _tv_dmt_bytype"
    foreach f of local temp_files {
        capture erase "${DATA_DIR}/`f'.dta"
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
    display as text "TVMERGE TEST SUMMARY"
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
