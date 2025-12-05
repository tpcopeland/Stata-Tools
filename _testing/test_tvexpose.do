/*******************************************************************************
* test_tvexpose.do
*
* Purpose: Comprehensive testing of tvexpose command
*          Tests all options and common combinations
*
* Prerequisites:
*   - Run generate_test_data.do first to create synthetic datasets
*   - tvexpose.ado must be installed/accessible
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
display as text "TVEXPOSE COMMAND TESTING"
display as text "{hline 70}"
display as text "Test directory: `testdir'"
display as text "{hline 70}"

local test_count = 0
local pass_count = 0
local fail_count = 0

* =============================================================================
* TEST 1: Basic binary time-varying exposure (HRT)
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Basic binary time-varying exposure"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort.dta", clear

    tvexpose using "`testdir'/hrt.dta", ///
        id(id) start(study_entry) stop(study_exit) event(edss4_dt) ///
        expstart(rx_start) expstop(rx_stop) ///
        type(binary) ///
        saveas("`testdir'/_test_tvexpose_binary") replace

    * Verify output
    use "`testdir'/_test_tvexpose_binary.dta", clear
    assert _N > 0
    confirm variable id _start _stop _event _exposed
    display as result "  PASSED: Binary exposure created successfully"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 2: Duration-based exposure
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Duration-based exposure"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort.dta", clear

    tvexpose using "`testdir'/hrt.dta", ///
        id(id) start(study_entry) stop(study_exit) event(edss4_dt) ///
        expstart(rx_start) expstop(rx_stop) ///
        type(duration) ///
        saveas("`testdir'/_test_tvexpose_duration") replace

    use "`testdir'/_test_tvexpose_duration.dta", clear
    assert _N > 0
    confirm variable _duration
    sum _duration
    assert r(min) >= 0
    display as result "  PASSED: Duration exposure created successfully"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 3: Categorical exposure with multiple categories
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Categorical exposure"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort.dta", clear

    tvexpose using "`testdir'/hrt.dta", ///
        id(id) start(study_entry) stop(study_exit) event(edss4_dt) ///
        expstart(rx_start) expstop(rx_stop) ///
        expvalue(hrt_type) ///
        type(categories) ///
        saveas("`testdir'/_test_tvexpose_categorical") replace

    use "`testdir'/_test_tvexpose_categorical.dta", clear
    assert _N > 0
    confirm variable hrt_type
    tab hrt_type
    display as result "  PASSED: Categorical exposure created successfully"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 4: Using gap (grace period) option
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Gap (grace period) option"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort.dta", clear

    tvexpose using "`testdir'/hrt.dta", ///
        id(id) start(study_entry) stop(study_exit) event(edss4_dt) ///
        expstart(rx_start) expstop(rx_stop) ///
        type(binary) ///
        gap(30) ///
        saveas("`testdir'/_test_tvexpose_gap30") replace

    use "`testdir'/_test_tvexpose_gap30.dta", clear
    assert _N > 0
    display as result "  PASSED: Gap option works correctly"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 5: Multiple competing events
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Multiple events (death as competing)"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort.dta", clear

    * Use earliest of edss4_dt and death_dt as the event
    gen event_date = min(edss4_dt, death_dt) if !missing(edss4_dt) | !missing(death_dt)
    replace event_date = edss4_dt if missing(event_date) & !missing(edss4_dt)
    replace event_date = death_dt if missing(event_date) & !missing(death_dt)
    format event_date %tdCCYY/NN/DD

    tvexpose using "`testdir'/hrt.dta", ///
        id(id) start(study_entry) stop(study_exit) event(event_date) ///
        expstart(rx_start) expstop(rx_stop) ///
        type(binary) ///
        saveas("`testdir'/_test_tvexpose_competing") replace

    use "`testdir'/_test_tvexpose_competing.dta", clear
    assert _N > 0
    display as result "  PASSED: Competing events handled correctly"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 6: DMT exposure (different dataset)
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': DMT exposure dataset"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort.dta", clear

    tvexpose using "`testdir'/dmt.dta", ///
        id(id) start(study_entry) stop(study_exit) event(edss4_dt) ///
        expstart(dmt_start) expstop(dmt_stop) ///
        type(binary) ///
        saveas("`testdir'/_test_tvexpose_dmt") replace

    use "`testdir'/_test_tvexpose_dmt.dta", clear
    assert _N > 0
    confirm variable _exposed
    display as result "  PASSED: DMT exposure dataset works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 7: Datetime exposure type
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Datetime exposure type"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort.dta", clear

    * Convert dates to datetime for testing
    gen double study_entry_dt = study_entry * 24 * 60 * 60 * 1000
    gen double study_exit_dt = study_exit * 24 * 60 * 60 * 1000
    gen double edss4_datetime = edss4_dt * 24 * 60 * 60 * 1000 if !missing(edss4_dt)
    format study_entry_dt study_exit_dt edss4_datetime %tc

    * Create datetime HRT file
    preserve
    use "`testdir'/hrt.dta", clear
    gen double rx_start_dt = rx_start * 24 * 60 * 60 * 1000
    gen double rx_stop_dt = rx_stop * 24 * 60 * 60 * 1000
    format rx_start_dt rx_stop_dt %tc
    save "`testdir'/_temp_hrt_datetime.dta", replace
    restore

    tvexpose using "`testdir'/_temp_hrt_datetime.dta", ///
        id(id) start(study_entry_dt) stop(study_exit_dt) event(edss4_datetime) ///
        expstart(rx_start_dt) expstop(rx_stop_dt) ///
        type(datetime) ///
        saveas("`testdir'/_test_tvexpose_datetime") replace

    use "`testdir'/_test_tvexpose_datetime.dta", clear
    assert _N > 0
    display as result "  PASSED: Datetime exposure type works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 8: nodelete option
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': nodelete option"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort.dta", clear

    tvexpose using "`testdir'/hrt.dta", ///
        id(id) start(study_entry) stop(study_exit) event(edss4_dt) ///
        expstart(rx_start) expstop(rx_stop) ///
        type(binary) ///
        nodelete ///
        saveas("`testdir'/_test_tvexpose_nodelete") replace

    use "`testdir'/_test_tvexpose_nodelete.dta", clear
    assert _N > 0
    display as result "  PASSED: nodelete option works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 9: Duration with custom exposure value
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Duration with dose as exposure value"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort.dta", clear

    tvexpose using "`testdir'/hrt.dta", ///
        id(id) start(study_entry) stop(study_exit) event(edss4_dt) ///
        expstart(rx_start) expstop(rx_stop) ///
        expvalue(dose) ///
        type(duration) ///
        saveas("`testdir'/_test_tvexpose_dose_duration") replace

    use "`testdir'/_test_tvexpose_dose_duration.dta", clear
    assert _N > 0
    confirm variable dose _duration
    display as result "  PASSED: Duration with custom value works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 10: DMT with efficacy categories
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': DMT with efficacy categories"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort.dta", clear

    tvexpose using "`testdir'/dmt.dta", ///
        id(id) start(study_entry) stop(study_exit) event(edss4_dt) ///
        expstart(dmt_start) expstop(dmt_stop) ///
        expvalue(efficacy) ///
        type(categories) ///
        saveas("`testdir'/_test_tvexpose_efficacy") replace

    use "`testdir'/_test_tvexpose_efficacy.dta", clear
    assert _N > 0
    confirm variable efficacy
    tab efficacy, missing
    display as result "  PASSED: DMT efficacy categories work"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 11: Large gap value
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Large gap value (90 days)"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort.dta", clear

    tvexpose using "`testdir'/hrt.dta", ///
        id(id) start(study_entry) stop(study_exit) event(edss4_dt) ///
        expstart(rx_start) expstop(rx_stop) ///
        type(binary) ///
        gap(90) ///
        saveas("`testdir'/_test_tvexpose_gap90") replace

    use "`testdir'/_test_tvexpose_gap90.dta", clear
    assert _N > 0
    display as result "  PASSED: Large gap value works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 12: Subset of observations using if
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Subset using if condition"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort.dta", clear

    * Only females
    keep if female == 1

    tvexpose using "`testdir'/hrt.dta", ///
        id(id) start(study_entry) stop(study_exit) event(edss4_dt) ///
        expstart(rx_start) expstop(rx_stop) ///
        type(binary) ///
        saveas("`testdir'/_test_tvexpose_females") replace

    use "`testdir'/_test_tvexpose_females.dta", clear
    assert _N > 0
    display as result "  PASSED: Subset works correctly"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 13: No events (all censored)
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': No events (all censored)"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort.dta", clear

    * Replace all events with missing
    replace edss4_dt = .

    tvexpose using "`testdir'/hrt.dta", ///
        id(id) start(study_entry) stop(study_exit) event(edss4_dt) ///
        expstart(rx_start) expstop(rx_stop) ///
        type(binary) ///
        saveas("`testdir'/_test_tvexpose_noevents") replace

    use "`testdir'/_test_tvexpose_noevents.dta", clear
    assert _N > 0
    * All _event should be 0
    sum _event
    assert r(max) == 0
    display as result "  PASSED: No events handled correctly"
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

local temp_files "_test_tvexpose_binary _test_tvexpose_duration _test_tvexpose_categorical _test_tvexpose_gap30 _test_tvexpose_competing _test_tvexpose_dmt _test_tvexpose_datetime _temp_hrt_datetime _test_tvexpose_nodelete _test_tvexpose_dose_duration _test_tvexpose_efficacy _test_tvexpose_gap90 _test_tvexpose_females _test_tvexpose_noevents"

foreach f of local temp_files {
    capture erase "`testdir'/`f'.dta"
}

* =============================================================================
* SUMMARY
* =============================================================================
display as text _n "{hline 70}"
display as text "TVEXPOSE TEST SUMMARY"
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
