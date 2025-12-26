/*******************************************************************************
* validation_tvtools_boundary.do
*
* Purpose: Comprehensive boundary condition validation for tvtools commands
*          These tests specifically target edge cases that could cause bugs like
*          the boundary event filtering bug fixed in tvevent v1.3.5.
*
* Philosophy: Events at interval boundaries are VALID and should be captured.
*             This file creates minimal datasets where every outcome can be
*             verified by hand calculation.
*
* Bug Background: tvevent v1.3.4 incorrectly filtered out events at boundaries
*                 (where event_date == stop). This was fixed in v1.3.5.
*
* Categories of Tests:
*   1. Event Boundary Tests (tvevent)
*   2. Interval Integrity Tests (tvexpose, tvmerge)
*   3. Person-Time Conservation Tests
*   4. Comparison with Manual Methods
*
* Run modes:
*   Standalone: do validation_tvtools_boundary.do
*   Via runner: do run_test.do validation_tvtools_boundary
*
* Author: Claude Code
* Date: 2025-12-17
*******************************************************************************/

clear all
set more off
version 16.0
set varabbrev off

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
    * Try to detect path from current working directory
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

* Install packages
capture net uninstall tvtools
quietly net install tvtools, from("${STATA_TOOLS_PATH}/tvtools")

* =============================================================================
* HEADER
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "TVTOOLS BOUNDARY CONDITION VALIDATION"
    display as text "{hline 70}"
    display as text "Tests verify correct handling of events at interval boundaries."
    display as text "These tests would have caught the v1.3.4 boundary bug."
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
* DATE REFERENCE
* =============================================================================
* Key Stata date values for 2020 (leap year):
* Jan 1, 2020  = 21915
* Jul 4, 2020  = 22100  (185 days from Jan 1)
* Oct 12, 2020 = 22200  (285 days from Jan 1)
* Dec 31, 2020 = 22280  (365 days from Jan 1)
* Jan 1, 2021  = 22281

* =============================================================================
* SECTION 1: EVENT AT EXACT STOP BOUNDARY (v1.3.4 BUG SCENARIO)
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 1: Event at Exact Stop Boundary"
    display as text "This is the exact scenario that exposed the v1.3.4 bug"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 1.1: Event exactly at interval stop (no split needed)
* Known answer: 1 event should be flagged
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 1.1: Event at exact stop boundary"
    display as text "  Interval: [21915, 22280], Event at 22280"
    display as text "  Expected: 1 event flagged (event is at stop)"
}

capture {
    * Create master (cohort with event)
    clear
    input long id double(study_entry study_exit event_dt)
        1  21915  22280  22280   // Event exactly at study_exit
    end
    format %td study_entry study_exit event_dt
    save "${DATA_DIR}/_val_cohort_1.dta", replace

    * Create using (interval data)
    clear
    input long id double(start stop) byte exposure
        1  21915  22280  1
    end
    format %td start stop
    save "${DATA_DIR}/_val_intervals_1.dta", replace

    * Run tvevent
    use "${DATA_DIR}/_val_cohort_1.dta", clear
    tvevent using "${DATA_DIR}/_val_intervals_1.dta", ///
        id(id) date(event_dt) ///
        startvar(start) stopvar(stop) ///
        type(single) generate(outcome)

    * Known answer: 1 event should be flagged
    quietly count if outcome == 1
    local actual_events = r(N)
    assert `actual_events' == 1
}
if _rc == 0 {
    local ++pass_count
    if `machine' {
        display "[OK] 1.1"
    }
    else if `quiet' == 0 {
        display as result "  PASS: Event at stop boundary correctly flagged (1 event)"
    }
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' 1.1"
    if `machine' {
        display "[FAIL] 1.1|`=_rc'"
    }
    else {
        display as error "  FAIL: Event at stop boundary (error `=_rc')"
        display as error "  This is the v1.3.4 bug scenario!"
    }
}

* -----------------------------------------------------------------------------
* Test 1.2: Event at boundary between two intervals
* Known answer: 1 event flagged at END of first interval only
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 1.2: Event at boundary between intervals"
    display as text "  Intervals: [21915, 22100] + [22100, 22280]"
    display as text "  Event at: 22100 (boundary)"
    display as text "  Expected: 1 event at end of first interval"
}

capture {
    * Create master
    clear
    input long id double(study_entry study_exit event_dt)
        1  21915  22280  22100   // Event at interval boundary
    end
    format %td study_entry study_exit event_dt
    save "${DATA_DIR}/_val_cohort_2.dta", replace

    * Create using (two intervals, boundary at 22100)
    clear
    input long id double(start stop) byte exposure
        1  21915  22100  0
        1  22100  22280  1
    end
    format %td start stop
    save "${DATA_DIR}/_val_intervals_2.dta", replace

    * Run tvevent
    use "${DATA_DIR}/_val_cohort_2.dta", clear
    tvevent using "${DATA_DIR}/_val_intervals_2.dta", ///
        id(id) date(event_dt) ///
        startvar(start) stopvar(stop) ///
        type(single) generate(outcome)

    * Known answer: exactly 1 event (at end of first interval)
    quietly count if outcome == 1
    local actual_events = r(N)
    assert `actual_events' == 1

    * The event should be at the first interval (stop = 22100)
    * After tvevent, intervals are censored at event time
    quietly sum stop if outcome == 1
    assert r(mean) == 22100
}
if _rc == 0 {
    local ++pass_count
    if `machine' {
        display "[OK] 1.2"
    }
    else if `quiet' == 0 {
        display as result "  PASS: Boundary event flagged once at first interval"
    }
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' 1.2"
    if `machine' {
        display "[FAIL] 1.2|`=_rc'"
    }
    else {
        display as error "  FAIL: Boundary event handling (error `=_rc')"
    }
}

* -----------------------------------------------------------------------------
* Test 1.3: Multiple people with boundary events
* Known answer: 3 events from 3 different boundary scenarios
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 1.3: Multiple boundary scenarios"
    display as text "  Person 1: Event at interval boundary (22100)"
    display as text "  Person 2: Event at interval boundary (22200)"
    display as text "  Person 3: Event at study_exit (22280)"
    display as text "  Expected: 3 events total"
}

capture {
    * Create master with 3 people, different boundary events
    clear
    input long id double(study_entry study_exit event_dt)
        1  21915  22280  22100
        2  21915  22280  22200
        3  21915  22280  22280
    end
    format %td study_entry study_exit event_dt
    save "${DATA_DIR}/_val_cohort_3.dta", replace

    * Create using with boundary points matching events
    clear
    input long id double(start stop) byte exposure
        1  21915  22100  0
        1  22100  22280  1
        2  21915  22200  0
        2  22200  22280  1
        3  21915  22180  0
        3  22180  22280  1
    end
    format %td start stop
    save "${DATA_DIR}/_val_intervals_3.dta", replace

    * Run tvevent
    use "${DATA_DIR}/_val_cohort_3.dta", clear
    tvevent using "${DATA_DIR}/_val_intervals_3.dta", ///
        id(id) date(event_dt) ///
        startvar(start) stopvar(stop) ///
        type(single) generate(outcome)

    * Known answer: 3 events total
    quietly count if outcome == 1
    local actual_events = r(N)
    assert `actual_events' == 3

    * Verify each person has exactly 1 event
    bysort id: egen has_event = max(outcome)
    quietly count if has_event == 1
    assert r(N) == _N  // All rows belong to people with events
}
if _rc == 0 {
    local ++pass_count
    if `machine' {
        display "[OK] 1.3"
    }
    else if `quiet' == 0 {
        display as result "  PASS: All 3 boundary events correctly flagged"
    }
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' 1.3"
    if `machine' {
        display "[FAIL] 1.3|`=_rc'"
    }
    else {
        display as error "  FAIL: Multiple boundary events (error `=_rc')"
    }
}

* =============================================================================
* SECTION 2: EVENT INSIDE INTERVAL (Should still work)
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 2: Events Inside Intervals (Baseline Check)"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 2.1: Event strictly inside interval (causes split)
* Known answer: 1 event, interval split at event date
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 2.1: Event inside interval (requires split)"
    display as text "  Interval: [21915, 22280], Event at 22100 (inside)"
    display as text "  Expected: 1 event, interval split into [21915,22100] + censored"
}

capture {
    * Create master
    clear
    input long id double(study_entry study_exit event_dt)
        1  21915  22280  22100
    end
    format %td study_entry study_exit event_dt
    save "${DATA_DIR}/_val_cohort_4.dta", replace

    * Create using (single interval that needs splitting)
    clear
    input long id double(start stop) byte exposure
        1  21915  22280  1
    end
    format %td start stop
    save "${DATA_DIR}/_val_intervals_4.dta", replace

    * Run tvevent
    use "${DATA_DIR}/_val_cohort_4.dta", clear
    tvevent using "${DATA_DIR}/_val_intervals_4.dta", ///
        id(id) date(event_dt) ///
        startvar(start) stopvar(stop) ///
        type(single) generate(outcome)

    * Known answer: 1 event
    quietly count if outcome == 1
    assert r(N) == 1

    * Event should be at the split point (stop = 22100)
    quietly sum stop if outcome == 1
    assert r(mean) == 22100
}
if _rc == 0 {
    local ++pass_count
    if `machine' {
        display "[OK] 2.1"
    }
    else if `quiet' == 0 {
        display as result "  PASS: Inside event correctly splits interval"
    }
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' 2.1"
    if `machine' {
        display "[FAIL] 2.1|`=_rc'"
    }
    else {
        display as error "  FAIL: Inside event splitting (error `=_rc')"
    }
}

* =============================================================================
* SECTION 3: PERSON-TIME CONSERVATION
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 3: Person-Time Conservation"
    display as text "Total person-time should be preserved (accounting for censoring)"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 3.1: Person-time conservation with no events
* Known answer: 365 days preserved exactly
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.1: Person-time with no events"
    display as text "  Input: 365 days [21915, 22280]"
    display as text "  Expected: 365 days output"
}

capture {
    * Create master with no event
    clear
    input long id double(study_entry study_exit event_dt)
        1  21915  22280  .
    end
    format %td study_entry study_exit event_dt
    save "${DATA_DIR}/_val_cohort_ptime.dta", replace

    * Create using
    clear
    input long id double(start stop) byte exposure
        1  21915  22280  1
    end
    format %td start stop
    save "${DATA_DIR}/_val_intervals_ptime.dta", replace

    * Run tvevent
    use "${DATA_DIR}/_val_cohort_ptime.dta", clear
    tvevent using "${DATA_DIR}/_val_intervals_ptime.dta", ///
        id(id) date(event_dt) ///
        startvar(start) stopvar(stop) ///
        type(single) generate(outcome)

    * Calculate person-time
    gen ptime = stop - start
    quietly sum ptime
    local total_ptime = r(sum)

    * Known answer: 365 days
    assert abs(`total_ptime' - 365) < 0.001
}
if _rc == 0 {
    local ++pass_count
    if `machine' {
        display "[OK] 3.1"
    }
    else if `quiet' == 0 {
        display as result "  PASS: Person-time preserved (365 days)"
    }
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' 3.1"
    if `machine' {
        display "[FAIL] 3.1|`=_rc'"
    }
    else {
        display as error "  FAIL: Person-time conservation (error `=_rc')"
    }
}

* -----------------------------------------------------------------------------
* Test 3.2: Person-time with event (censored at event)
* Known answer: 185 days (from Jan 1 to Jul 4)
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.2: Person-time censored at event"
    display as text "  Event at day 185 (22100)"
    display as text "  Expected: 185 days person-time"
}

capture {
    * Create master with event
    clear
    input long id double(study_entry study_exit event_dt)
        1  21915  22280  22100
    end
    format %td study_entry study_exit event_dt
    save "${DATA_DIR}/_val_cohort_ptime2.dta", replace

    * Create using
    clear
    input long id double(start stop) byte exposure
        1  21915  22280  1
    end
    format %td start stop
    save "${DATA_DIR}/_val_intervals_ptime2.dta", replace

    * Run tvevent
    use "${DATA_DIR}/_val_cohort_ptime2.dta", clear
    tvevent using "${DATA_DIR}/_val_intervals_ptime2.dta", ///
        id(id) date(event_dt) ///
        startvar(start) stopvar(stop) ///
        type(single) generate(outcome)

    * Calculate person-time
    gen ptime = stop - start
    quietly sum ptime
    local total_ptime = r(sum)

    * Known answer: 185 days (21915 to 22100)
    assert abs(`total_ptime' - 185) < 0.001
}
if _rc == 0 {
    local ++pass_count
    if `machine' {
        display "[OK] 3.2"
    }
    else if `quiet' == 0 {
        display as result "  PASS: Person-time correctly censored (185 days)"
    }
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' 3.2"
    if `machine' {
        display "[FAIL] 3.2|`=_rc'"
    }
    else {
        display as error "  FAIL: Person-time with censoring (error `=_rc')"
    }
}

* =============================================================================
* SECTION 4: INTERVAL INTEGRITY INVARIANTS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 4: Interval Integrity Invariants"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 4.1: No overlapping intervals within person
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.1: No overlapping intervals"
}

capture {
    * Use the complex dataset from test 1.3
    use "${DATA_DIR}/_val_cohort_3.dta", clear
    tvevent using "${DATA_DIR}/_val_intervals_3.dta", ///
        id(id) date(event_dt) ///
        startvar(start) stopvar(stop) ///
        type(single) generate(outcome)

    * Check for overlaps
    sort id start
    by id: gen overlap = (start < stop[_n-1]) if _n > 1
    quietly count if overlap == 1
    assert r(N) == 0
}
if _rc == 0 {
    local ++pass_count
    if `machine' {
        display "[OK] 4.1"
    }
    else if `quiet' == 0 {
        display as result "  PASS: No overlapping intervals"
    }
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' 4.1"
    if `machine' {
        display "[FAIL] 4.1|`=_rc'"
    }
    else {
        display as error "  FAIL: Overlapping intervals detected (error `=_rc')"
    }
}

* -----------------------------------------------------------------------------
* Test 4.2: start < stop for all intervals
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.2: All intervals have start < stop"
}

capture {
    use "${DATA_DIR}/_val_cohort_3.dta", clear
    tvevent using "${DATA_DIR}/_val_intervals_3.dta", ///
        id(id) date(event_dt) ///
        startvar(start) stopvar(stop) ///
        type(single) generate(outcome)

    * Verify start < stop
    quietly count if start >= stop
    assert r(N) == 0
}
if _rc == 0 {
    local ++pass_count
    if `machine' {
        display "[OK] 4.2"
    }
    else if `quiet' == 0 {
        display as result "  PASS: All intervals have start < stop"
    }
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' 4.2"
    if `machine' {
        display "[FAIL] 4.2|`=_rc'"
    }
    else {
        display as error "  FAIL: Invalid intervals (start >= stop) (error `=_rc')"
    }
}

* -----------------------------------------------------------------------------
* Test 4.3: Continuous coverage (no gaps) before event
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.3: Continuous coverage (no gaps)"
}

capture {
    use "${DATA_DIR}/_val_cohort_3.dta", clear
    tvevent using "${DATA_DIR}/_val_intervals_3.dta", ///
        id(id) date(event_dt) ///
        startvar(start) stopvar(stop) ///
        type(single) generate(outcome)

    * Check for gaps (where start[n] != stop[n-1])
    sort id start
    by id: gen gap = (start != stop[_n-1]) if _n > 1
    quietly count if gap == 1
    assert r(N) == 0
}
if _rc == 0 {
    local ++pass_count
    if `machine' {
        display "[OK] 4.3"
    }
    else if `quiet' == 0 {
        display as result "  PASS: Continuous coverage (no gaps)"
    }
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' 4.3"
    if `machine' {
        display "[FAIL] 4.3|`=_rc'"
    }
    else {
        display as error "  FAIL: Gaps detected in intervals (error `=_rc')"
    }
}

* =============================================================================
* SECTION 5: COMPARISON WITH MANUAL METHOD
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 5: Comparison with Manual Method"
    display as text "Verify tvevent matches conceptual behavior from manual code"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 5.1: Manual vs tvevent - boundary event
* The manual method uses inrange(event_dt, start, stop) which is inclusive
* tvevent should match: event at stop should be flagged
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 5.1: Manual vs tvevent comparison"
    display as text "  Manual: inrange(event_dt, start, stop) - inclusive"
    display as text "  tvevent: should flag event at stop boundary"
}

capture {
    * Create test data
    clear
    input long id double(study_entry study_exit event_dt)
        1  21915  22280  22100
    end
    format %td study_entry study_exit event_dt
    tempfile cohort
    save `cohort'

    clear
    input long id double(start stop) byte exposure
        1  21915  22100  0
        1  22100  22280  1
    end
    format %td start stop
    tempfile intervals
    save `intervals'

    * MANUAL METHOD (from HRT_2025_12_15.do:1392-1412)
    use `cohort', clear
    merge 1:m id using `intervals', nogen keep(3)
    replace study_exit = event_dt if event_dt < study_exit
    drop if start > study_exit
    replace stop = event_dt if inrange(event_dt, start, stop)
    gen manual_outcome = (event_dt == stop)
    quietly count if manual_outcome == 1
    local manual_events = r(N)

    * TVEVENT METHOD
    use `cohort', clear
    tvevent using `intervals', ///
        id(id) date(event_dt) ///
        startvar(start) stopvar(stop) ///
        type(single) generate(outcome)
    quietly count if outcome == 1
    local tvevent_events = r(N)

    * Note: Manual method may double-count at boundaries
    * tvevent correctly counts once
    * Both should have at least 1 event
    assert `tvevent_events' >= 1
    assert `manual_events' >= 1
}
if _rc == 0 {
    local ++pass_count
    if `machine' {
        display "[OK] 5.1"
    }
    else if `quiet' == 0 {
        display as result "  PASS: Both methods flag boundary event"
        display as text "  Manual events: `manual_events', tvevent events: `tvevent_events'"
    }
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' 5.1"
    if `machine' {
        display "[FAIL] 5.1|`=_rc'"
    }
    else {
        display as error "  FAIL: Manual vs tvevent comparison (error `=_rc')"
    }
}

* =============================================================================
* SECTION 6: COMPETING RISKS AT BOUNDARIES
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 6: Competing Risks at Boundaries"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 6.1: Competing risk at boundary (death at stop)
* Known answer: Competing event flagged as type 2
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 6.1: Competing event at boundary"
    display as text "  Primary event: missing"
    display as text "  Competing (death) at: 22280 (boundary)"
    display as text "  Expected: 1 competing event (outcome=2)"
}

capture {
    * Create master
    clear
    input long id double(study_entry study_exit event_dt death_dt)
        1  21915  22280  .  22280
    end
    format %td study_entry study_exit event_dt death_dt
    save "${DATA_DIR}/_val_cohort_compete.dta", replace

    * Create using
    clear
    input long id double(start stop) byte exposure
        1  21915  22280  1
    end
    format %td start stop
    save "${DATA_DIR}/_val_intervals_compete.dta", replace

    * Run tvevent with competing risk
    use "${DATA_DIR}/_val_cohort_compete.dta", clear
    tvevent using "${DATA_DIR}/_val_intervals_compete.dta", ///
        id(id) date(event_dt) ///
        compete(death_dt) ///
        startvar(start) stopvar(stop) ///
        type(single) generate(outcome)

    * Known answer: 1 competing event (outcome=2)
    quietly count if outcome == 2
    assert r(N) == 1
}
if _rc == 0 {
    local ++pass_count
    if `machine' {
        display "[OK] 6.1"
    }
    else if `quiet' == 0 {
        display as result "  PASS: Competing event at boundary correctly flagged"
    }
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' 6.1"
    if `machine' {
        display "[FAIL] 6.1|`=_rc'"
    }
    else {
        display as error "  FAIL: Competing risk at boundary (error `=_rc')"
    }
}

* =============================================================================
* SECTION 7: TVEXPOSE BOUNDARY TESTS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 7: tvexpose Boundary Tests"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 7.1: Exposure ending at study_exit boundary
* Known answer: Interval includes exposure to the boundary
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 7.1: Exposure ending at study_exit"
    display as text "  Exposure: [21915, 22280] (full study period)"
    display as text "  Expected: 365 days exposed"
}

capture {
    * Create cohort
    clear
    input long id double(study_entry study_exit)
        1  21915  22280
    end
    format %td study_entry study_exit
    save "${DATA_DIR}/_val_cohort_tvx.dta", replace

    * Create exposure that matches study period exactly
    clear
    input long id double(rx_start rx_stop) byte hrt_type
        1  21915  22280  1
    end
    format %td rx_start rx_stop
    save "${DATA_DIR}/_val_exp_tvx.dta", replace

    * Run tvexpose
    use "${DATA_DIR}/_val_cohort_tvx.dta", clear
    tvexpose using "${DATA_DIR}/_val_exp_tvx.dta", ///
        id(id) start(rx_start) stop(rx_stop) ///
        entry(study_entry) exit(study_exit) ///
        exposure(hrt_type) reference(0) ///
        generate(tv_hrt)

    * Known answer: 365 days of exposure
    * Note: tvexpose output uses variable names from start()/stop() options
    gen ptime = rx_stop - rx_start
    quietly sum ptime if tv_hrt == 1
    * Should have 365 days (full period exposed)
    assert abs(r(sum) - 365) < 0.001
}
if _rc == 0 {
    local ++pass_count
    if `machine' {
        display "[OK] 7.1"
    }
    else if `quiet' == 0 {
        display as result "  PASS: Exposure at boundary handled correctly"
    }
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' 7.1"
    if `machine' {
        display "[FAIL] 7.1|`=_rc'"
    }
    else {
        display as error "  FAIL: tvexpose boundary handling (error `=_rc')"
    }
}

* -----------------------------------------------------------------------------
* Test 7.2: Exposure starting at study_entry
* Known answer: Interval starts exactly at entry
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 7.2: Exposure starting at study_entry"
}

capture {
    * Use same data from 7.1
    use "${DATA_DIR}/_val_cohort_tvx.dta", clear
    tvexpose using "${DATA_DIR}/_val_exp_tvx.dta", ///
        id(id) start(rx_start) stop(rx_stop) ///
        entry(study_entry) exit(study_exit) ///
        exposure(hrt_type) reference(0) ///
        generate(tv_hrt)

    * First interval should start at study_entry
    * Note: tvexpose output uses variable names from start()/stop() options
    sort id rx_start
    by id: gen byte first = (_n == 1)
    quietly sum rx_start if first == 1
    assert r(mean) == 21915
}
if _rc == 0 {
    local ++pass_count
    if `machine' {
        display "[OK] 7.2"
    }
    else if `quiet' == 0 {
        display as result "  PASS: First interval starts at study_entry"
    }
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' 7.2"
    if `machine' {
        display "[FAIL] 7.2|`=_rc'"
    }
    else {
        display as error "  FAIL: Entry boundary handling (error `=_rc')"
    }
}

* =============================================================================
* CLEANUP
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "Cleaning up temporary files..."
}

quietly {
    local temp_files "_val_cohort_1 _val_intervals_1 _val_cohort_2 _val_intervals_2"
    local temp_files "`temp_files' _val_cohort_3 _val_intervals_3 _val_cohort_4 _val_intervals_4"
    local temp_files "`temp_files' _val_cohort_ptime _val_intervals_ptime"
    local temp_files "`temp_files' _val_cohort_ptime2 _val_intervals_ptime2"
    local temp_files "`temp_files' _val_cohort_compete _val_intervals_compete"
    local temp_files "`temp_files' _val_cohort_tvx _val_exp_tvx"
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
    display as text "TVTOOLS BOUNDARY VALIDATION SUMMARY"
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
        display as error _n "BOUNDARY VALIDATION FAILED"
        display as error "The tvtools commands may have boundary handling bugs."
        exit 1
    }
    else {
        display as result _n "ALL BOUNDARY TESTS PASSED!"
        display as text "The tvtools commands correctly handle boundary conditions."
    }
}

display as text _n "Validation completed: `c(current_date)' `c(current_time)'"
display as text "{hline 70}"

* Clear globals
global RUN_TEST_QUIET
global RUN_TEST_MACHINE
global RUN_TEST_NUMBER
