/*******************************************************************************
* test_tvpipeline.do
*
* Purpose: Functional tests for tvpipeline command
*          Tests that all options execute without errors.
*
* Run modes:
*   Standalone: do test_tvpipeline.do
*   Via runner: do run_test.do test_tvpipeline [testnumber] [quiet] [machine]
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
    capture confirm file "_testing"
    if _rc == 0 {
        global STATA_TOOLS_PATH "`c(pwd)'"
    }
    else {
        global STATA_TOOLS_PATH "`c(pwd)'/.."
    }
}

* Validate path - if tvtools directory not found, try one more level up
capture confirm file "${STATA_TOOLS_PATH}/tvtools/stata.toc"
if _rc != 0 {
    global STATA_TOOLS_PATH "${STATA_TOOLS_PATH}/.."
}

global TESTING_DIR "${STATA_TOOLS_PATH}/_devkit/_testing"
global DATA_DIR "${TESTING_DIR}/data"

* Create data directory if needed
capture mkdir "${DATA_DIR}"

* Install tvtools package
capture net uninstall tvtools
quietly net install tvtools, from("${STATA_TOOLS_PATH}/tvtools")


* =============================================================================
* HEADER
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "TVPIPELINE FUNCTIONAL TESTS"
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
* CREATE TEST DATA
* =============================================================================
if `quiet' == 0 {
    display as text _n "Creating test data..."
}

* Create cohort data
clear
set seed 54321
set obs 100

gen id = _n
gen study_entry = mdy(1, 1, 2020) + floor(runiform() * 30)
gen study_exit = study_entry + 365 + floor(runiform() * 180)
format %td study_entry study_exit

* Covariates
gen age = 40 + floor(runiform() * 40)
gen sex = runiform() > 0.5
gen comorbidity = runiform() > 0.7

* Event dates (some have events)
gen outcome_date = .
replace outcome_date = study_entry + floor(runiform() * (study_exit - study_entry)) if runiform() < 0.3
format %td outcome_date

* Competing event (death)
gen death_date = .
replace death_date = study_entry + floor(runiform() * (study_exit - study_entry)) if runiform() < 0.1 & missing(outcome_date)
format %td death_date

save "${DATA_DIR}/test_cohort_pipeline.dta", replace

* Create exposure data
clear
set obs 150
gen id = ceil(_n / 1.5)
replace id = min(id, 100)

* Generate exposure periods
bysort id: gen episode = _n
gen rx_start = mdy(1, 1, 2020) + floor(runiform() * 200)
gen rx_stop = rx_start + 30 + floor(runiform() * 90)
format %td rx_start rx_stop

* Exposure type
gen drug = 1 + floor(runiform() * 2)  // 1 or 2

save "${DATA_DIR}/test_exposure_pipeline.dta", replace

if `quiet' == 0 {
    display as result "Test data created"
}

* =============================================================================
* SECTION 1: BASIC FUNCTIONALITY
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 1: Basic Functionality"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 1.1: Basic pipeline (tvexpose only)
* -----------------------------------------------------------------------------
local ++test_count
if `run_only' == 0 | `run_only' == 1 {
    if `quiet' == 0 {
        display as text _n "Test 1.1: Basic pipeline"
    }

    capture {
        use "${DATA_DIR}/test_cohort_pipeline.dta", clear
        tvpipeline using "${DATA_DIR}/test_exposure_pipeline.dta", ///
            id(id) start(rx_start) stop(rx_stop) exposure(drug) ///
            entry(study_entry) exit(study_exit)

        * Verify key variables exist
        confirm variable start
        confirm variable stop
        confirm variable tv_exposure

        * Verify return values
        assert r(n_cohort) == 100
        assert r(n_output) > 0
    }
    if _rc == 0 {
        display as result "  PASS: Basic pipeline works"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Basic pipeline (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' 1.1"
    }
}

* -----------------------------------------------------------------------------
* Test 1.2: Pipeline with custom reference level
* -----------------------------------------------------------------------------
local ++test_count
if `run_only' == 0 | `run_only' == 2 {
    if `quiet' == 0 {
        display as text _n "Test 1.2: Custom reference level"
    }

    capture {
        use "${DATA_DIR}/test_cohort_pipeline.dta", clear
        tvpipeline using "${DATA_DIR}/test_exposure_pipeline.dta", ///
            id(id) start(rx_start) stop(rx_stop) exposure(drug) ///
            entry(study_entry) exit(study_exit) reference(0)

        * Reference periods should have tv_exposure = 0
        count if tv_exposure == 0
        assert r(N) > 0
    }
    if _rc == 0 {
        display as result "  PASS: Custom reference level works"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Custom reference level (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' 1.2"
    }
}

* =============================================================================
* SECTION 2: EVENT HANDLING
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 2: Event Handling"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 2.1: Pipeline with event
* -----------------------------------------------------------------------------
local ++test_count
if `run_only' == 0 | `run_only' == 3 {
    if `quiet' == 0 {
        display as text _n "Test 2.1: Pipeline with event"
    }

    capture {
        use "${DATA_DIR}/test_cohort_pipeline.dta", clear
        tvpipeline using "${DATA_DIR}/test_exposure_pipeline.dta", ///
            id(id) start(rx_start) stop(rx_stop) exposure(drug) ///
            entry(study_entry) exit(study_exit) event(outcome_date)

        * Verify event variable exists
        confirm variable _event
        assert r(n_events) >= 0
    }
    if _rc == 0 {
        display as result "  PASS: Pipeline with event works"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Pipeline with event (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' 2.1"
    }
}

* -----------------------------------------------------------------------------
* Test 2.2: Pipeline with competing event
* -----------------------------------------------------------------------------
local ++test_count
if `run_only' == 0 | `run_only' == 4 {
    if `quiet' == 0 {
        display as text _n "Test 2.2: Pipeline with competing event"
    }

    capture {
        use "${DATA_DIR}/test_cohort_pipeline.dta", clear
        tvpipeline using "${DATA_DIR}/test_exposure_pipeline.dta", ///
            id(id) start(rx_start) stop(rx_stop) exposure(drug) ///
            entry(study_entry) exit(study_exit) ///
            event(outcome_date) compete(death_date)

        * Verify compete variable exists
        confirm variable _event
        confirm variable _compete
    }
    if _rc == 0 {
        display as result "  PASS: Pipeline with competing event works"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Pipeline with competing event (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' 2.2"
    }
}

* =============================================================================
* SECTION 3: DIAGNOSTIC OPTIONS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 3: Diagnostic Options"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 3.1: Pipeline with diagnose
* -----------------------------------------------------------------------------
local ++test_count
if `run_only' == 0 | `run_only' == 5 {
    if `quiet' == 0 {
        display as text _n "Test 3.1: Pipeline with diagnose"
    }

    capture {
        use "${DATA_DIR}/test_cohort_pipeline.dta", clear
        tvpipeline using "${DATA_DIR}/test_exposure_pipeline.dta", ///
            id(id) start(rx_start) stop(rx_stop) exposure(drug) ///
            entry(study_entry) exit(study_exit) diagnose
    }
    if _rc == 0 {
        display as result "  PASS: Pipeline with diagnose works"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Pipeline with diagnose (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' 3.1"
    }
}

* -----------------------------------------------------------------------------
* Test 3.2: Pipeline with balance
* -----------------------------------------------------------------------------
local ++test_count
if `run_only' == 0 | `run_only' == 6 {
    if `quiet' == 0 {
        display as text _n "Test 3.2: Pipeline with balance"
    }

    capture {
        use "${DATA_DIR}/test_cohort_pipeline.dta", clear
        tvpipeline using "${DATA_DIR}/test_exposure_pipeline.dta", ///
            id(id) start(rx_start) stop(rx_stop) exposure(drug) ///
            entry(study_entry) exit(study_exit) balance(age sex)
    }
    if _rc == 0 {
        display as result "  PASS: Pipeline with balance works"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Pipeline with balance (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' 3.2"
    }
}

* -----------------------------------------------------------------------------
* Test 3.3: Pipeline with plot
* -----------------------------------------------------------------------------
local ++test_count
if `run_only' == 0 | `run_only' == 7 {
    if `quiet' == 0 {
        display as text _n "Test 3.3: Pipeline with plot"
    }

    capture {
        use "${DATA_DIR}/test_cohort_pipeline.dta", clear
        tvpipeline using "${DATA_DIR}/test_exposure_pipeline.dta", ///
            id(id) start(rx_start) stop(rx_stop) exposure(drug) ///
            entry(study_entry) exit(study_exit) plot
    }
    if _rc == 0 {
        display as result "  PASS: Pipeline with plot works"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Pipeline with plot (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' 3.3"
    }
}

* =============================================================================
* SECTION 4: SAVE OPTIONS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 4: Save Options"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 4.1: Pipeline with saveas
* -----------------------------------------------------------------------------
local ++test_count
if `run_only' == 0 | `run_only' == 8 {
    if `quiet' == 0 {
        display as text _n "Test 4.1: Pipeline with saveas"
    }

    capture {
        use "${DATA_DIR}/test_cohort_pipeline.dta", clear
        capture erase "${DATA_DIR}/pipeline_output.dta"
        tvpipeline using "${DATA_DIR}/test_exposure_pipeline.dta", ///
            id(id) start(rx_start) stop(rx_stop) exposure(drug) ///
            entry(study_entry) exit(study_exit) ///
            saveas("${DATA_DIR}/pipeline_output.dta")

        * Verify file was created
        confirm file "${DATA_DIR}/pipeline_output.dta"
        capture erase "${DATA_DIR}/pipeline_output.dta"
    }
    if _rc == 0 {
        display as result "  PASS: Pipeline with saveas works"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Pipeline with saveas (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' 4.1"
    }
}

* -----------------------------------------------------------------------------
* Test 4.2: Pipeline with replace
* -----------------------------------------------------------------------------
local ++test_count
if `run_only' == 0 | `run_only' == 9 {
    if `quiet' == 0 {
        display as text _n "Test 4.2: Pipeline with replace"
    }

    capture {
        use "${DATA_DIR}/test_cohort_pipeline.dta", clear

        * Create file first
        save "${DATA_DIR}/pipeline_output.dta", replace

        * Run pipeline with replace
        use "${DATA_DIR}/test_cohort_pipeline.dta", clear
        tvpipeline using "${DATA_DIR}/test_exposure_pipeline.dta", ///
            id(id) start(rx_start) stop(rx_stop) exposure(drug) ///
            entry(study_entry) exit(study_exit) ///
            saveas("${DATA_DIR}/pipeline_output.dta") replace

        capture erase "${DATA_DIR}/pipeline_output.dta"
    }
    if _rc == 0 {
        display as result "  PASS: Pipeline with replace works"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Pipeline with replace (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' 4.2"
    }
}

* =============================================================================
* SECTION 5: COMPLETE PIPELINE
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 5: Complete Pipeline"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 5.1: Full pipeline with all options
* -----------------------------------------------------------------------------
local ++test_count
if `run_only' == 0 | `run_only' == 10 {
    if `quiet' == 0 {
        display as text _n "Test 5.1: Full pipeline with all options"
    }

    capture {
        use "${DATA_DIR}/test_cohort_pipeline.dta", clear
        capture erase "${DATA_DIR}/full_pipeline.dta"

        tvpipeline using "${DATA_DIR}/test_exposure_pipeline.dta", ///
            id(id) start(rx_start) stop(rx_stop) exposure(drug) ///
            reference(0) entry(study_entry) exit(study_exit) ///
            event(outcome_date) compete(death_date) ///
            diagnose balance(age sex) plot ///
            saveas("${DATA_DIR}/full_pipeline.dta")

        * Verify all expected outputs
        confirm variable start
        confirm variable stop
        confirm variable tv_exposure
        confirm variable _event
        confirm variable _compete
        confirm file "${DATA_DIR}/full_pipeline.dta"

        capture erase "${DATA_DIR}/full_pipeline.dta"
    }
    if _rc == 0 {
        display as result "  PASS: Full pipeline works"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Full pipeline (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' 5.1"
    }
}

* =============================================================================
* SECTION 6: ERROR HANDLING
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 6: Error Handling"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 6.1: Missing exposure file
* -----------------------------------------------------------------------------
local ++test_count
if `run_only' == 0 | `run_only' == 11 {
    if `quiet' == 0 {
        display as text _n "Test 6.1: Missing exposure file"
    }

    capture {
        use "${DATA_DIR}/test_cohort_pipeline.dta", clear
        capture tvpipeline using "nonexistent_file.dta", ///
            id(id) start(rx_start) stop(rx_stop) exposure(drug) ///
            entry(study_entry) exit(study_exit)
        assert _rc == 601
    }
    if _rc == 0 {
        display as result "  PASS: Missing file produces error"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Missing file not caught"
        local ++fail_count
        local failed_tests "`failed_tests' 6.1"
    }
}

* -----------------------------------------------------------------------------
* Test 6.2: Missing required variable
* -----------------------------------------------------------------------------
local ++test_count
if `run_only' == 0 | `run_only' == 12 {
    if `quiet' == 0 {
        display as text _n "Test 6.2: Missing required variable"
    }

    capture {
        use "${DATA_DIR}/test_cohort_pipeline.dta", clear
        drop study_entry
        capture tvpipeline using "${DATA_DIR}/test_exposure_pipeline.dta", ///
            id(id) start(rx_start) stop(rx_stop) exposure(drug) ///
            entry(study_entry) exit(study_exit)
        assert _rc == 111
    }
    if _rc == 0 {
        display as result "  PASS: Missing variable produces error"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Missing variable not caught"
        local ++fail_count
        local failed_tests "`failed_tests' 6.2"
    }
}

* =============================================================================
* SECTION 7: RETURN VALUES
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 7: Return Values"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 7.1: Return values
* -----------------------------------------------------------------------------
local ++test_count
if `run_only' == 0 | `run_only' == 13 {
    if `quiet' == 0 {
        display as text _n "Test 7.1: Return values"
    }

    capture {
        use "${DATA_DIR}/test_cohort_pipeline.dta", clear
        tvpipeline using "${DATA_DIR}/test_exposure_pipeline.dta", ///
            id(id) start(rx_start) stop(rx_stop) exposure(drug) ///
            entry(study_entry) exit(study_exit) event(outcome_date)

        * Check all return values
        assert r(n_cohort) == 100
        assert r(n_ids) == 100
        assert r(n_output) > 0
        assert r(n_ids_output) > 0
        assert r(n_events) >= 0
        assert "`r(id)'" == "id"
        assert "`r(exposure)'" == "drug"
    }
    if _rc == 0 {
        display as result "  PASS: All return values present"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Return values (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' 7.1"
    }
}

* =============================================================================
* CLEANUP
* =============================================================================
capture erase "${DATA_DIR}/test_cohort_pipeline.dta"
capture erase "${DATA_DIR}/test_exposure_pipeline.dta"
capture erase "${DATA_DIR}/pipeline_output.dta"
capture erase "${DATA_DIR}/full_pipeline.dta"

* =============================================================================
* SUMMARY
* =============================================================================
display as text _n "{hline 70}"
display as text "TVPIPELINE TEST SUMMARY"
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
    display as error "Some tests FAILED."
    exit 1
}
else {
    display as result _n "ALL TESTS PASSED!"
}

display as text _n "Testing completed: `c(current_date)' `c(current_time)'"
display as text "{hline 70}"
