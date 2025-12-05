/*******************************************************************************
* test_tvevent.do
*
* Purpose: Comprehensive testing of tvevent command
*          Tests all options and common combinations
*
* Prerequisites:
*   - Run generate_test_data.do first to create synthetic datasets
*   - tvevent.ado must be installed/accessible
*
* Author: Timothy P Copeland
* Date: 2025-12-05
*******************************************************************************/

clear all
set more off
version 16.0

* Get directory of this do file
local testdir = c(pwd)

* Check for required test data
capture confirm file "`testdir'/cohort.dta"
if _rc {
    display as error "Test data not found. Run generate_test_data.do first."
    exit 601
}

display as text _n "{hline 70}"
display as text "TVEVENT COMMAND TESTING"
display as text "{hline 70}"
display as text "Test directory: `testdir'"
display as text "{hline 70}"

local test_count = 0
local pass_count = 0
local fail_count = 0

* =============================================================================
* TEST 1: Basic single event (first hospitalization)
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Basic single event"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort.dta", clear

    tvevent using "`testdir'/hospitalizations.dta", ///
        id(id) start(study_entry) stop(study_exit) event(edss4_dt) ///
        eventdate(hosp_date) ///
        type(single) ///
        saveas("`testdir'/_test_tvevent_single") replace

    use "`testdir'/_test_tvevent_single.dta", clear
    assert _N > 0
    confirm variable _start _stop _event
    display as result "  PASSED: Basic single event works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 2: Recurring events
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Recurring events"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort.dta", clear

    tvevent using "`testdir'/hospitalizations.dta", ///
        id(id) start(study_entry) stop(study_exit) event(edss4_dt) ///
        eventdate(hosp_date) ///
        type(recurring) ///
        saveas("`testdir'/_test_tvevent_recurring") replace

    use "`testdir'/_test_tvevent_recurring.dta", clear
    assert _N > 0
    * Check that event count variable exists
    confirm variable _n_events
    sum _n_events
    assert r(max) >= 1
    display as result "  PASSED: Recurring events work"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 3: Count exposure (cumulative count of events)
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Count exposure type"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort.dta", clear

    tvevent using "`testdir'/hospitalizations.dta", ///
        id(id) start(study_entry) stop(study_exit) event(edss4_dt) ///
        eventdate(hosp_date) ///
        type(count) ///
        saveas("`testdir'/_test_tvevent_count") replace

    use "`testdir'/_test_tvevent_count.dta", clear
    assert _N > 0
    * Count should be cumulative
    confirm variable _count
    display as result "  PASSED: Count exposure type works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 4: Ever exposed (binary time-varying)
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Ever exposed type"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort.dta", clear

    tvevent using "`testdir'/hospitalizations.dta", ///
        id(id) start(study_entry) stop(study_exit) event(edss4_dt) ///
        eventdate(hosp_date) ///
        type(ever) ///
        saveas("`testdir'/_test_tvevent_ever") replace

    use "`testdir'/_test_tvevent_ever.dta", clear
    assert _N > 0
    * Ever should be 0 or 1
    confirm variable _ever
    assert inlist(_ever, 0, 1)
    display as result "  PASSED: Ever exposed type works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 5: With lag period
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Lag period option"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort.dta", clear

    tvevent using "`testdir'/hospitalizations.dta", ///
        id(id) start(study_entry) stop(study_exit) event(edss4_dt) ///
        eventdate(hosp_date) ///
        type(ever) ///
        lag(30) ///
        saveas("`testdir'/_test_tvevent_lag") replace

    use "`testdir'/_test_tvevent_lag.dta", clear
    assert _N > 0
    display as result "  PASSED: Lag period option works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 6: With washout period
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Washout period option"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort.dta", clear

    tvevent using "`testdir'/hospitalizations.dta", ///
        id(id) start(study_entry) stop(study_exit) event(edss4_dt) ///
        eventdate(hosp_date) ///
        type(ever) ///
        washout(90) ///
        saveas("`testdir'/_test_tvevent_washout") replace

    use "`testdir'/_test_tvevent_washout.dta", clear
    assert _N > 0
    display as result "  PASSED: Washout period option works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 7: Event with value (hospitalization type)
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Event with categorical value"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort.dta", clear

    tvevent using "`testdir'/hospitalizations.dta", ///
        id(id) start(study_entry) stop(study_exit) event(edss4_dt) ///
        eventdate(hosp_date) ///
        eventvalue(hosp_type) ///
        type(single) ///
        saveas("`testdir'/_test_tvevent_value") replace

    use "`testdir'/_test_tvevent_value.dta", clear
    assert _N > 0
    confirm variable hosp_type
    display as result "  PASSED: Event with value works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 8: Combined lag and washout
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Combined lag and washout"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort.dta", clear

    tvevent using "`testdir'/hospitalizations.dta", ///
        id(id) start(study_entry) stop(study_exit) event(edss4_dt) ///
        eventdate(hosp_date) ///
        type(ever) ///
        lag(30) washout(60) ///
        saveas("`testdir'/_test_tvevent_lag_washout") replace

    use "`testdir'/_test_tvevent_lag_washout.dta", clear
    assert _N > 0
    display as result "  PASSED: Combined lag and washout works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 9: Subjects with no events
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Subjects with no events"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort.dta", clear

    * Keep only first 100 subjects
    keep if id <= 100

    tvevent using "`testdir'/hospitalizations.dta", ///
        id(id) start(study_entry) stop(study_exit) event(edss4_dt) ///
        eventdate(hosp_date) ///
        type(ever) ///
        saveas("`testdir'/_test_tvevent_subset") replace

    use "`testdir'/_test_tvevent_subset.dta", clear
    assert _N > 0
    * Some should have _ever = 0
    count if _ever == 0
    display as text "  Subjects with no events: " r(N)
    display as result "  PASSED: Subjects with no events handled"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 10: Time-since-event variable
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Time since event"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort.dta", clear

    tvevent using "`testdir'/hospitalizations.dta", ///
        id(id) start(study_entry) stop(study_exit) event(edss4_dt) ///
        eventdate(hosp_date) ///
        type(single) ///
        timesince ///
        saveas("`testdir'/_test_tvevent_timesince") replace

    use "`testdir'/_test_tvevent_timesince.dta", clear
    assert _N > 0
    confirm variable _time_since
    display as result "  PASSED: Time since event works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 11: Nodelete option
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Nodelete option"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort.dta", clear

    tvevent using "`testdir'/hospitalizations.dta", ///
        id(id) start(study_entry) stop(study_exit) event(edss4_dt) ///
        eventdate(hosp_date) ///
        type(ever) ///
        nodelete ///
        saveas("`testdir'/_test_tvevent_nodelete") replace

    use "`testdir'/_test_tvevent_nodelete.dta", clear
    assert _N > 0
    display as result "  PASSED: Nodelete option works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* CLEANUP: Remove temporary files
* =============================================================================
display as text _n "{hline 70}"
display as text "Cleaning up temporary files..."
display as text "{hline 70}"

local temp_files "_test_tvevent_single _test_tvevent_recurring _test_tvevent_count _test_tvevent_ever _test_tvevent_lag _test_tvevent_washout _test_tvevent_value _test_tvevent_lag_washout _test_tvevent_subset _test_tvevent_timesince _test_tvevent_nodelete"

foreach f of local temp_files {
    capture erase "`testdir'/`f'.dta"
}

* =============================================================================
* SUMMARY
* =============================================================================
display as text _n "{hline 70}"
display as text "TVEVENT TEST SUMMARY"
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
    display as error "Some tests FAILED. Review output above."
    exit 1
}
else {
    display as result "All tests PASSED!"
}
