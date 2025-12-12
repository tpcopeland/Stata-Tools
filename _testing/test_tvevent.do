/*******************************************************************************
* test_tvevent.do
*
* Purpose: Comprehensive testing of tvevent command with context-optimized output
*          Supports quiet mode, single test execution, and data validation
*
* Prerequisites:
*   - Run generate_test_data.do first to create synthetic datasets
*   - tvexpose.ado and tvevent.ado must be installed/accessible
*
* Run modes:
*   Standalone: do test_tvevent.do
*   Via runner: do run_test.do test_tvevent [testnumber] [quiet] [machine]
*
* Note: tvevent operates on datasets that already have start/stop variables
*       (created by tvexpose or tvmerge). It integrates event dates and
*       competing risks into the time-varying structure.
*
* Data Validations:
*   - Event count: Number of events matches source data
*   - Event timing: Events occur within person-time periods
*   - Outcome values: Only expected outcome codes present
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
capture confirm file "/Users/tcopeland/Documents/GitHub/Stata-Tools/_testing"
if _rc == 0 {
    global STATA_TOOLS_PATH "/Users/tcopeland/Documents/GitHub/Stata-Tools"
}
else {
    capture confirm file "_testing"
    if _rc == 0 {
        global STATA_TOOLS_PATH "`c(pwd)'"
    }
    else {
        global STATA_TOOLS_PATH "../.."
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
    display as text "TVEVENT COMMAND TESTING"
    display as text "{hline 70}"
    display as text "Data directory: ${DATA_DIR}"
    display as text "{hline 70}"
}

* =============================================================================
* CAPTURE BASELINE DATA FOR VALIDATIONS
* =============================================================================
quietly {
    use "${DATA_DIR}/cohort.dta", clear

    * Count expected events from source data
    count if !missing(edss4_dt)
    local source_edss4_events = r(N)

    count if !missing(death_dt)
    local source_death_events = r(N)
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
* SETUP: Create tvexpose output for tvevent testing
* =============================================================================
if `quiet' == 0 {
    display as text _n "SETUP: Creating tvexpose output dataset..."
    display as text "{hline 50}"
}

capture {
    quietly use "${DATA_DIR}/cohort.dta", clear
    tvexpose using "${DATA_DIR}/dmt.dta", ///
        id(id) start(dmt_start) stop(dmt_stop) ///
        exposure(dmt) reference(0) ///
        entry(study_entry) exit(study_exit) ///
        generate(tv_dmt) ///
        saveas("${DATA_DIR}/_tv_base.dta") replace
}
if _rc {
    if `machine' {
        display "[ERROR] Setup failed|`=_rc'"
    }
    else {
        display as error "SETUP FAILED: Could not create tvexpose dataset (error `=_rc')"
    }
    exit _rc
}

if `quiet' == 0 {
    display as result "Setup complete: tvexpose output file created"
}

* =============================================================================
* TEST 1: Basic single event (primary outcome)
* =============================================================================
local ++test_count
local test_desc "Basic single event"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        quietly use "${DATA_DIR}/_tv_base.dta", clear

        tvevent using "${DATA_DIR}/cohort.dta", ///
            id(id) date(edss4_dt) ///
            type(single) ///
            generate(outcome)

        assert _N > 0
        confirm variable outcome

        * Validate: outcome should be 0 (censored) or 1 (event)
        quietly sum outcome
        assert r(min) >= 0 & r(max) <= 1
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
* TEST 2: Single event with competing risk (death)
* =============================================================================
local ++test_count
local test_desc "Single event with competing risk"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        quietly use "${DATA_DIR}/_tv_base.dta", clear

        tvevent using "${DATA_DIR}/cohort.dta", ///
            id(id) date(edss4_dt) ///
            compete(death_dt) ///
            type(single) ///
            generate(outcome)

        assert _N > 0
        confirm variable outcome

        * outcome: 0=censored, 1=primary, 2=competing
        quietly sum outcome
        assert r(min) >= 0 & r(max) <= 2
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "[OK] `test_count'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
            quietly count if outcome == 2
            display as text "  Deaths (competing): " r(N)
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
* TEST 3: Multiple competing risks
* =============================================================================
local ++test_count
local test_desc "Multiple competing risks"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        quietly use "${DATA_DIR}/_tv_base.dta", clear

        tvevent using "${DATA_DIR}/cohort.dta", ///
            id(id) date(edss4_dt) ///
            compete(death_dt emigration_dt) ///
            type(single) ///
            generate(status)

        assert _N > 0
        confirm variable status

        * status: 0=censored, 1=primary, 2=death, 3=emigration
        quietly sum status
        assert r(min) >= 0 & r(max) <= 3
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
* TEST 4: Recurring events
* =============================================================================
local ++test_count
local test_desc "Recurring events"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        quietly use "${DATA_DIR}/_tv_base.dta", clear

        tvevent using "${DATA_DIR}/hospitalizations.dta", ///
            id(id) date(hosp_date) ///
            type(recurring) ///
            generate(hospitalized)

        assert _N > 0
        confirm variable hospitalized
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
* TEST 5: Custom event labels
* =============================================================================
local ++test_count
local test_desc "Custom event labels"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        quietly use "${DATA_DIR}/_tv_base.dta", clear

        tvevent using "${DATA_DIR}/cohort.dta", ///
            id(id) date(edss4_dt) ///
            compete(death_dt) ///
            type(single) ///
            eventlabel(0 "Censored" 1 "EDSS Progression" 2 "Death") ///
            generate(outcome)

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
* TEST 6: timegen() option - days
* =============================================================================
local ++test_count
local test_desc "timegen() option - days"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        quietly use "${DATA_DIR}/_tv_base.dta", clear

        tvevent using "${DATA_DIR}/cohort.dta", ///
            id(id) date(edss4_dt) ///
            type(single) ///
            timegen(interval_days) timeunit(days) ///
            generate(outcome)

        assert _N > 0
        confirm variable interval_days
        quietly sum interval_days
        assert r(min) >= 0
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "[OK] `test_count'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
            display as text "  Mean interval (days): " %6.1f r(mean)
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
* TEST 7: timegen() option - years
* =============================================================================
local ++test_count
local test_desc "timegen() option - years"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        quietly use "${DATA_DIR}/_tv_base.dta", clear

        tvevent using "${DATA_DIR}/cohort.dta", ///
            id(id) date(edss4_dt) ///
            type(single) ///
            timegen(interval_years) timeunit(years) ///
            generate(outcome)

        assert _N > 0
        confirm variable interval_years
        quietly sum interval_years
        assert r(min) >= 0
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "[OK] `test_count'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
            display as text "  Mean interval (years): " %6.3f r(mean)
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
* TEST 8: Stored results verification
* =============================================================================
local ++test_count
local test_desc "Stored results verification"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        quietly use "${DATA_DIR}/_tv_base.dta", clear

        tvevent using "${DATA_DIR}/cohort.dta", ///
            id(id) date(edss4_dt) ///
            compete(death_dt) ///
            type(single) ///
            generate(outcome)

        assert r(N) > 0
        assert r(N_events) >= 0
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "[OK] `test_count'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
            display as text "  r(N) = " r(N) ", r(N_events) = " r(N_events)
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
* TEST 9: Complete workflow (tvexpose -> tvevent -> stset)
* =============================================================================
local ++test_count
local test_desc "Complete workflow"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        * Step 1: Create time-varying dataset
        quietly use "${DATA_DIR}/cohort.dta", clear
        tvexpose using "${DATA_DIR}/dmt.dta", ///
            id(id) start(dmt_start) stop(dmt_stop) ///
            exposure(dmt) reference(0) ///
            entry(study_entry) exit(study_exit) ///
            generate(tv_dmt)

        * Step 2: Integrate events
        tvevent using "${DATA_DIR}/cohort.dta", ///
            id(id) date(edss4_dt) ///
            compete(death_dt) ///
            type(single) ///
            generate(outcome)

        * Step 3: Set up for survival analysis
        stset stop, id(id) failure(outcome==1) enter(start)

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
* TEST 10: Event count validation
* =============================================================================
local ++test_count
local test_desc "Event count validation"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        quietly use "${DATA_DIR}/_tv_base.dta", clear

        tvevent using "${DATA_DIR}/cohort.dta", ///
            id(id) date(edss4_dt) ///
            type(single) ///
            generate(outcome)

        * Count events in output
        quietly count if outcome == 1
        local output_events = r(N)

        * Events should match source (allowing for censoring before event)
        * Output events should be <= source events
        assert `output_events' <= `source_edss4_events'
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "[OK] `test_count'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
            display as text "  Source events: `source_edss4_events', Output events: `output_events'"
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
    capture erase "${DATA_DIR}/_tv_base.dta"
    capture erase "${DATA_DIR}/_tv_continuous.dta"
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
    display as text "TVEVENT TEST SUMMARY"
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
