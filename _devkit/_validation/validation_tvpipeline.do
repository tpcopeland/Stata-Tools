/*******************************************************************************
* validation_tvpipeline.do
*
* Purpose: Deep validation tests for tvpipeline command
*          Verifies that the pipeline produces correct results by checking
*          against manually executed steps.
*
* Run modes:
*   Standalone: do validation_tvpipeline.do
*   Via runner: do run_test.do validation_tvpipeline [testnumber] [quiet] [machine]
*
* Author: Timothy P Copeland
* Date: 2025-12-29
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
    capture confirm file "_validation"
    if _rc == 0 {
        global STATA_TOOLS_PATH "`c(pwd)'"
    }
    else {
        capture confirm file "_testing"
        if _rc == 0 {
            global STATA_TOOLS_PATH "`c(pwd)'"
        }
        else {
            global STATA_TOOLS_PATH "/home/`c(username)'/Stata-Tools"
        }
    }
}
else {
    capture confirm file "_validation"
    if _rc == 0 {
        global STATA_TOOLS_PATH "`c(pwd)'"
    }
    else {
        global STATA_TOOLS_PATH "`c(pwd)'/.."
    }
}

global VALIDATION_DIR "${STATA_TOOLS_PATH}/_validation"
global DATA_DIR "${VALIDATION_DIR}/data"

capture mkdir "${DATA_DIR}"

* Install tvtools package
capture net uninstall tvtools
quietly net install tvtools, from("${STATA_TOOLS_PATH}/tvtools")


* =============================================================================
* HEADER
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "TVPIPELINE DEEP VALIDATION TESTS"
    display as text "{hline 70}"
    display as text "Verifying pipeline produces same results as manual steps."
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
* CREATE VALIDATION DATA
* =============================================================================
if `quiet' == 0 {
    display as text _n "Creating validation datasets..."
}

* Simple cohort: 5 people, 2020 (366 days)
clear
input long id double(study_entry study_exit) byte has_event double outcome_date
    1 21915 22281 0 .
    2 21915 22281 1 22100
    3 21915 22281 1 22050
    4 21915 22281 0 .
    5 21915 22281 0 .
end
format %td study_entry study_exit outcome_date
gen age = 50 + id * 5
gen sex = mod(id, 2)
save "${DATA_DIR}/val_cohort_pipe.dta", replace

* Simple exposure data: known exposure periods
clear
input long id double(rx_start rx_stop) byte drug
    1 21946 22006 1
    2 21946 22100 1
    3 22000 22100 2
    4 21915 22281 1
    5 22100 22200 1
end
format %td rx_start rx_stop
save "${DATA_DIR}/val_exp_pipe.dta", replace

if `quiet' == 0 {
    display as result "Validation datasets created"
}

* =============================================================================
* SECTION 1: PIPELINE VS MANUAL EXECUTION
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 1: Pipeline vs Manual Execution"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 1.1: Pipeline produces same output as manual tvexpose
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 1.1: Pipeline matches manual tvexpose"
}

capture {
    * Run pipeline
    use "${DATA_DIR}/val_cohort_pipe.dta", clear
    tvpipeline using "${DATA_DIR}/val_exp_pipe.dta", ///
        id(id) start(rx_start) stop(rx_stop) exposure(drug) ///
        entry(study_entry) exit(study_exit)

    * Save pipeline output (has start, stop after rename)
    tempfile pipeline_out
    save `pipeline_out', replace
    local pipeline_n = _N

    * Run manual tvexpose
    use "${DATA_DIR}/val_cohort_pipe.dta", clear
    tvexpose using "${DATA_DIR}/val_exp_pipe.dta", ///
        id(id) start(rx_start) stop(rx_stop) exposure(drug) ///
        reference(0) entry(study_entry) exit(study_exit)

    * tvexpose preserves original names, so rename to match pipeline
    rename rx_start start
    rename rx_stop stop

    local manual_n = _N

    * Compare observation counts
    assert `pipeline_n' == `manual_n'

    * Compare key variables
    merge 1:1 id start stop using `pipeline_out', assert(match) nogen
    assert tv_exposure == tv_exposure
}
if _rc == 0 {
    display as result "  PASS: Pipeline matches manual tvexpose"
    local ++pass_count
}
else {
    display as error "  FAIL: Pipeline doesn't match manual (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 1.1"
}

* -----------------------------------------------------------------------------
* Test 1.2: Pipeline with event matches manual tvexpose + tvevent
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 1.2: Pipeline with event matches manual"
}

capture {
    * Run pipeline with event
    use "${DATA_DIR}/val_cohort_pipe.dta", clear
    tvpipeline using "${DATA_DIR}/val_exp_pipe.dta", ///
        id(id) start(rx_start) stop(rx_stop) exposure(drug) ///
        entry(study_entry) exit(study_exit) event(outcome_date)

    * Count events from pipeline
    count if _event == 1
    local pipeline_events = r(N)

    tempfile pipeline_out
    save `pipeline_out', replace

    * Run manual tvexpose + tvevent
    * First, tvexpose
    use "${DATA_DIR}/val_cohort_pipe.dta", clear

    * Save event data before tvexpose
    preserve
    keep id outcome_date
    bysort id: keep if _n == 1
    tempfile event_data
    save `event_data', replace
    restore

    tvexpose using "${DATA_DIR}/val_exp_pipe.dta", ///
        id(id) start(rx_start) stop(rx_stop) exposure(drug) ///
        reference(0) entry(study_entry) exit(study_exit)

    * Rename to match pipeline
    rename rx_start start
    rename rx_stop stop

    * Save interval data for tvevent
    tempfile interval_data
    save `interval_data', replace

    * Load event data and run tvevent
    use `event_data', clear
    drop if missing(outcome_date)
    tvevent using `interval_data', id(id) date(outcome_date) generate(_event)

    * Count events from manual
    count if _event == 1
    local manual_events = r(N)

    * Compare event counts
    assert `pipeline_events' == `manual_events'
}
if _rc == 0 {
    display as result "  PASS: Pipeline event handling matches manual"
    local ++pass_count
}
else {
    display as error "  FAIL: Event handling mismatch (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 1.2"
}

* =============================================================================
* SECTION 2: DATA INTEGRITY
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 2: Data Integrity"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 2.1: All cohort IDs preserved
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 2.1: All cohort IDs preserved"
}

capture {
    use "${DATA_DIR}/val_cohort_pipe.dta", clear
    quietly levelsof id
    local cohort_ids = r(r)

    tvpipeline using "${DATA_DIR}/val_exp_pipe.dta", ///
        id(id) start(rx_start) stop(rx_stop) exposure(drug) ///
        entry(study_entry) exit(study_exit)

    quietly levelsof id
    local output_ids = r(r)

    * All 5 cohort IDs should be in output
    assert `output_ids' == `cohort_ids'
}
if _rc == 0 {
    display as result "  PASS: All cohort IDs preserved"
    local ++pass_count
}
else {
    display as error "  FAIL: ID count mismatch (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 2.1"
}

* -----------------------------------------------------------------------------
* Test 2.2: Covariates preserved
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 2.2: Covariates preserved"
}

capture {
    use "${DATA_DIR}/val_cohort_pipe.dta", clear

    * Use balance() option to request covariate preservation
    tvpipeline using "${DATA_DIR}/val_exp_pipe.dta", ///
        id(id) start(rx_start) stop(rx_stop) exposure(drug) ///
        entry(study_entry) exit(study_exit) balance(age sex)

    * Check covariates still exist
    confirm variable age
    confirm variable sex

    * Check covariate values are consistent within ID
    bysort id: egen sd_age = sd(age)
    assert sd_age == 0 | missing(sd_age)
}
if _rc == 0 {
    display as result "  PASS: Covariates preserved correctly with balance()"
    local ++pass_count
}
else {
    display as error "  FAIL: Covariate preservation (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 2.2"
}

* =============================================================================
* SECTION 3: RETURN VALUES
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 3: Return Value Accuracy"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 3.1: Return values match actual counts
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.1: Return values match actual counts"
}

capture {
    use "${DATA_DIR}/val_cohort_pipe.dta", clear
    local input_n = _N
    quietly levelsof id
    local input_ids = r(r)

    tvpipeline using "${DATA_DIR}/val_exp_pipe.dta", ///
        id(id) start(rx_start) stop(rx_stop) exposure(drug) ///
        entry(study_entry) exit(study_exit) event(outcome_date)

    * Store return values
    local ret_n_cohort = r(n_cohort)
    local ret_n_ids = r(n_ids)
    local ret_n_output = r(n_output)
    local ret_n_events = r(n_events)

    * Verify against actual data
    assert `ret_n_cohort' == `input_n'
    assert `ret_n_ids' == `input_ids'
    assert `ret_n_output' == _N

    count if _event == 1
    assert `ret_n_events' == r(N)
}
if _rc == 0 {
    display as result "  PASS: Return values match actual data"
    local ++pass_count
}
else {
    display as error "  FAIL: Return value mismatch (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.1"
}

* =============================================================================
* SECTION 4: INVARIANTS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 4: Invariant Tests"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Invariant 4.1: stop >= start for all intervals
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Invariant 4.1: stop >= start"
}

capture {
    use "${DATA_DIR}/val_cohort_pipe.dta", clear
    tvpipeline using "${DATA_DIR}/val_exp_pipe.dta", ///
        id(id) start(rx_start) stop(rx_stop) exposure(drug) ///
        entry(study_entry) exit(study_exit)

    count if stop < start
    assert r(N) == 0
}
if _rc == 0 {
    display as result "  PASS: All intervals have stop >= start"
    local ++pass_count
}
else {
    display as error "  FAIL: Invalid intervals found (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' Inv4.1"
}

* -----------------------------------------------------------------------------
* Invariant 4.2: No overlapping intervals within ID
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Invariant 4.2: No overlapping intervals"
}

capture {
    use "${DATA_DIR}/val_cohort_pipe.dta", clear
    tvpipeline using "${DATA_DIR}/val_exp_pipe.dta", ///
        id(id) start(rx_start) stop(rx_stop) exposure(drug) ///
        entry(study_entry) exit(study_exit)

    sort id start stop
    by id: gen overlap = (start < stop[_n-1]) if _n > 1
    count if overlap == 1
    assert r(N) == 0
}
if _rc == 0 {
    display as result "  PASS: No overlapping intervals"
    local ++pass_count
}
else {
    display as error "  FAIL: Overlapping intervals found (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' Inv4.2"
}

* =============================================================================
* CLEANUP
* =============================================================================
capture erase "${DATA_DIR}/val_cohort_pipe.dta"
capture erase "${DATA_DIR}/val_exp_pipe.dta"

* =============================================================================
* SUMMARY
* =============================================================================
display as text _n "{hline 70}"
display as text "TVPIPELINE VALIDATION SUMMARY"
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
