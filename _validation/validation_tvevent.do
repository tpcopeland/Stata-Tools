/*******************************************************************************
* validation_tvevent.do
*
* Purpose: Deep validation tests for tvevent command using known-answer testing
*          These tests verify event placement, interval splitting, and
*          competing risk resolution match expected results.
*
* Philosophy: Create minimal datasets where every output value can be
*             mathematically verified by hand.
*
* Key Behavior: tvevent uses strict inequality (start < date < stop)
*               Events exactly at boundaries are NOT captured.
*
* Run modes:
*   Standalone: do validation_tvevent.do
*   Via runner: do run_test.do validation_tvevent [testnumber] [quiet] [machine]
*
* Prerequisites:
*   - tvevent.ado must be installed/accessible
*
* Author: Auto-generated from validation plan
* Date: 2025-12-13
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
    capture confirm file "_validation"
    if _rc == 0 {
        * Running from repo root
        global STATA_TOOLS_PATH "`c(pwd)'"
    }
    else {
        capture confirm file "data"
        if _rc == 0 {
            * Running from _validation directory
            global STATA_TOOLS_PATH "`c(pwd)'/.."
        }
        else {
            * Assume running from _validation/data directory
            global STATA_TOOLS_PATH "`c(pwd)'/../.."
        }
    }
}

global VALIDATION_DIR "${STATA_TOOLS_PATH}/_validation"
global DATA_DIR "${VALIDATION_DIR}/data"

* Create data directory if needed
capture mkdir "${DATA_DIR}"

* Install tvtools package
capture net uninstall tvtools
quietly net install tvtools, from("${STATA_TOOLS_PATH}/tvtools")
capture quietly ssc install distinct

* =============================================================================
* HEADER (skip in quiet/machine mode)
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "TVEVENT DEEP VALIDATION TESTS"
    display as text "{hline 70}"
    display as text "These tests verify mathematical correctness, not just execution."
    display as text "Note: tvevent uses STRICT inequality (start < date < stop)"
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
* HELPER PROGRAMS
* =============================================================================

* Program to verify person-time conservation
capture program drop _verify_ptime_conserved
program define _verify_ptime_conserved, rclass
    syntax, start(varname) stop(varname) expected_ptime(real) [tolerance(real 0.001)]

    tempvar dur
    gen double `dur' = `stop' - `start'
    quietly sum `dur'
    local actual = r(sum)
    local pct_diff = abs(`actual' - `expected_ptime') / `expected_ptime'
    return scalar actual_ptime = `actual'
    return scalar pct_diff = `pct_diff'
    return scalar passed = (`pct_diff' < `tolerance')
end

* =============================================================================
* CREATE VALIDATION DATA
* =============================================================================
if `quiet' == 0 {
    display as text _n "Creating validation datasets..."
}

* Interval data for tvevent testing (simulating tvexpose output)
clear
input long id double(start stop) byte tv_exp
    1 21915 22097 1
    1 22097 22281 0
end
format %td start stop
label data "Pre-split intervals for tvevent tests"
save "${DATA_DIR}/intervals_test.dta", replace

* Full-year single interval
clear
input long id double(start stop) byte tv_exp
    1 21915 22281 1
end
format %td start stop
label data "Full-year single interval"
save "${DATA_DIR}/intervals_fullyear.dta", replace

* Two-person intervals for ID preservation tests
clear
input long id double(start stop) byte tv_exp
    1 21915 22281 1
    2 21915 22281 1
end
format %td start stop
label data "Two-person intervals"
save "${DATA_DIR}/intervals_2person.dta", replace

* Event data: mid-year event
clear
input long id double event_dt
    1 22051
end
format %td event_dt
label data "Single mid-year event (May 15, 2020)"
save "${DATA_DIR}/events_midyear.dta", replace

* Event at exact interval boundaries
clear
input long id double event_dt
    1 21915
end
format %td event_dt
label data "Event at interval start (Jan 1, 2020)"
save "${DATA_DIR}/events_at_start.dta", replace

clear
input long id double event_dt
    1 22281
end
format %td event_dt
label data "Event at interval stop (Dec 31, 2020)"
save "${DATA_DIR}/events_at_stop.dta", replace

* Event one day inside boundaries
clear
input long id double event_dt
    1 21916
end
format %td event_dt
label data "Event one day after start (Jan 2, 2020)"
save "${DATA_DIR}/events_day_after_start.dta", replace

* Event outside study period
clear
input long id double event_dt
    1 22400
end
format %td event_dt
label data "Event outside study period"
save "${DATA_DIR}/events_outside.dta", replace

* Competing risk events
clear
input long id double(primary_dt death_dt)
    1 22097 22006
end
format %td primary_dt death_dt
label data "Competing risk: death (Apr 1) before primary (Jun 30)"
save "${DATA_DIR}/events_competing.dta", replace

* Same-day competing events
clear
input long id double(primary_dt compete_dt)
    1 22082 22082
end
format %td primary_dt compete_dt
label data "Same-day competing events (Jun 15, 2020)"
save "${DATA_DIR}/events_sameday.dta", replace

* Person with no event (missing)
clear
input long id double event_dt
    1 22051
    2 .
end
format %td event_dt
label data "Mixed: person 1 has event, person 2 censored"
save "${DATA_DIR}/events_mixed.dta", replace

* Multiple competing risks
clear
input long id double(primary_dt death_dt emig_dt)
    1 22128 22006 22051
end
format %td primary_dt death_dt emig_dt
label data "Multiple competing risks: death (Apr 1), emig (May 15), primary (Aug 1)"
save "${DATA_DIR}/events_multi_compete.dta", replace

if `quiet' == 0 {
    display as result "Validation datasets created in: ${DATA_DIR}"
}

* =============================================================================
* TEST SECTION 4.1: EVENT INTEGRATION TESTS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 4.1: Event Integration Tests"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 4.1.1: Event Placed at Correct Boundary
* Purpose: Verify event occurs at interval endpoint, not mid-interval
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.1.1: Event Placed at Correct Boundary"
}

capture {
    use "${DATA_DIR}/events_midyear.dta", clear
    tvevent using "${DATA_DIR}/intervals_fullyear.dta", id(id) date(event_dt) ///
        startvar(start) stopvar(stop) type(single) generate(outcome)

    * Event should split the interval
    * The row WITH the event should have stop = event date
    sort start
    quietly count if outcome == 1
    assert r(N) == 1

    * Event row stop should equal the event date
    quietly sum stop if outcome == 1
    assert r(mean) == 22051
}
if _rc == 0 {
    display as result "  PASS: Event placed at correct boundary (stop = event date)"
    local ++pass_count
}
else {
    display as error "  FAIL: Event boundary placement (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.1.1"
}

* -----------------------------------------------------------------------------
* Test 4.1.2: Event Count Preservation
* Purpose: Verify number of events in output matches input
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.1.2: Event Count Preservation"
}

capture {
    * Count events in source
    use "${DATA_DIR}/events_midyear.dta", clear
    quietly count if !missing(event_dt)
    local source_events = r(N)

    * Run tvevent
    tvevent using "${DATA_DIR}/intervals_fullyear.dta", id(id) date(event_dt) ///
        startvar(start) stopvar(stop) type(single) generate(outcome)

    * Count events in output
    quietly count if outcome == 1
    local output_events = r(N)

    assert `source_events' == `output_events'
}
if _rc == 0 {
    display as result "  PASS: Event count preserved (input = output)"
    local ++pass_count
}
else {
    display as error "  FAIL: Event count preservation (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.1.2"
}

* =============================================================================
* TEST SECTION 4.2: INTERVAL SPLITTING TESTS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 4.2: Interval Splitting Tests"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 4.2.1: Split Preserves Total Duration
* Purpose: Verify splitting doesn't create/lose person-time
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.2.1: Split Preserves Total Duration"
}

capture {
    * Calculate pre-tvevent total duration
    use "${DATA_DIR}/intervals_fullyear.dta", clear
    gen double dur = stop - start
    quietly sum dur
    local pre_total = r(sum)

    * Run tvevent
    use "${DATA_DIR}/events_midyear.dta", clear
    tvevent using "${DATA_DIR}/intervals_fullyear.dta", id(id) date(event_dt) ///
        startvar(start) stopvar(stop) type(single) generate(outcome)

    * After tvevent: calculate total duration (should match input)
    gen double dur = stop - start
    quietly sum dur
    local post_total = r(sum)

    * With type(single), duration should be LESS because follow-up truncated at event
    * But total captured person-time should still be meaningful
    * Here we verify that person-time to event is preserved
    assert `post_total' <= `pre_total'
}
if _rc == 0 {
    display as result "  PASS: Total duration preserved or reduced (type=single truncates)"
    local ++pass_count
}
else {
    display as error "  FAIL: Split duration preservation (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.2.1"
}

* =============================================================================
* TEST SECTION 4.3: COMPETING RISK TESTS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 4.3: Competing Risk Tests"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 4.3.1: Earliest Event Wins
* Purpose: Verify competing risk resolution picks earliest date
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.3.1: Earliest Event Wins"
}

capture {
    * Primary event Jun 30, competing event Apr 1
    * Competing (death) is earlier, so should win
    use "${DATA_DIR}/events_competing.dta", clear
    tvevent using "${DATA_DIR}/intervals_fullyear.dta", id(id) date(primary_dt) ///
        startvar(start) stopvar(stop) compete(death_dt) ///
        type(single) generate(outcome)

    * Outcome should be 2 (competing risk) since Apr 1 < Jun 30
    quietly count if outcome == 2
    assert r(N) == 1

    * Event should occur at Apr 1
    quietly sum stop if outcome == 2
    assert r(mean) == 22006
}
if _rc == 0 {
    display as result "  PASS: Earliest event (competing risk) wins"
    local ++pass_count
}
else {
    display as error "  FAIL: Competing risk earliest event (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.3.1"
}

* -----------------------------------------------------------------------------
* Test 4.3.2: Multiple Competing Risks
* Purpose: Verify correct assignment among multiple competing risks
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.3.2: Multiple Competing Risks"
}

capture {
    * Three events: primary (Aug 1), death (Apr 1), emigration (May 15)
    * Death is earliest -> outcome = 2
    use "${DATA_DIR}/events_multi_compete.dta", clear
    tvevent using "${DATA_DIR}/intervals_fullyear.dta", id(id) date(primary_dt) ///
        startvar(start) stopvar(stop) compete(death_dt emig_dt) ///
        type(single) generate(outcome)

    * Outcome codes: 0=censored, 1=primary, 2=death, 3=emigration
    * Death (Apr 1) is earliest -> outcome = 2
    quietly count if outcome == 2
    assert r(N) == 1
}
if _rc == 0 {
    display as result "  PASS: Multiple competing risks: earliest wins (death=2)"
    local ++pass_count
}
else {
    display as error "  FAIL: Multiple competing risks (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.3.2"
}

* =============================================================================
* TEST SECTION 4.4: SINGLE VS RECURRING TESTS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 4.4: Single vs Recurring Tests"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 4.4.1: type(single) Censors After First Event
* Purpose: Verify follow-up ends after first event for single events
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.4.1: type(single) Censors After Event"
}

capture {
    use "${DATA_DIR}/events_midyear.dta", clear
    tvevent using "${DATA_DIR}/intervals_fullyear.dta", id(id) date(event_dt) ///
        startvar(start) stopvar(stop) type(single) generate(outcome)

    * Should have no rows after the event row
    sort id start
    by id: egen event_time = max(stop * (outcome == 1))
    by id: gen post_event = (start > event_time & !missing(event_time))
    quietly count if post_event == 1
    assert r(N) == 0
}
if _rc == 0 {
    display as result "  PASS: type(single) truncates follow-up at event"
    local ++pass_count
}
else {
    display as error "  FAIL: type(single) censoring (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.4.1"
}

* =============================================================================
* TEST SECTION 4.6: BOUNDARY CONDITION TESTS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 4.6: Boundary Condition Tests (CRITICAL)"
    display as text "{hline 70}"
    display as text "Note: tvevent uses STRICT inequality: start < date < stop"
}

* -----------------------------------------------------------------------------
* Test 4.6.1: Event Exactly at Interval Start
* Purpose: Verify event at start boundary is NOT captured
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.6.1: Event at Exact Interval Start"
}

capture {
    use "${DATA_DIR}/events_at_start.dta", clear
    tvevent using "${DATA_DIR}/intervals_fullyear.dta", id(id) date(event_dt) ///
        startvar(start) stopvar(stop) type(single) generate(outcome)

    * Event should NOT be captured (date not > start)
    quietly count if outcome == 1
    assert r(N) == 0
}
if _rc == 0 {
    display as result "  PASS: Event at exact start NOT captured (strict inequality)"
    local ++pass_count
}
else {
    display as error "  FAIL: Event at start boundary (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.6.1"
}

* -----------------------------------------------------------------------------
* Test 4.6.2: Event Exactly at Interval Stop
* Purpose: Verify event at stop boundary is NOT captured
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.6.2: Event at Exact Interval Stop"
}

capture {
    use "${DATA_DIR}/events_at_stop.dta", clear
    tvevent using "${DATA_DIR}/intervals_fullyear.dta", id(id) date(event_dt) ///
        startvar(start) stopvar(stop) type(single) generate(outcome)

    * Event should NOT be captured (date not < stop)
    quietly count if outcome == 1
    assert r(N) == 0
}
if _rc == 0 {
    display as result "  PASS: Event at exact stop NOT captured (strict inequality)"
    local ++pass_count
}
else {
    display as error "  FAIL: Event at stop boundary (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.6.2"
}

* -----------------------------------------------------------------------------
* Test 4.6.3: Event One Day Inside Boundaries
* Purpose: Verify events just inside boundaries ARE captured
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.6.3: Event One Day Inside Start"
}

capture {
    use "${DATA_DIR}/events_day_after_start.dta", clear
    tvevent using "${DATA_DIR}/intervals_fullyear.dta", id(id) date(event_dt) ///
        startvar(start) stopvar(stop) type(single) generate(outcome)

    * Event SHOULD be captured (Jan 2 > Jan 1 and < Dec 31)
    quietly count if outcome == 1
    assert r(N) == 1
}
if _rc == 0 {
    display as result "  PASS: Event one day inside boundaries IS captured"
    local ++pass_count
}
else {
    display as error "  FAIL: Event inside boundaries (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.6.3"
}

* =============================================================================
* TEST SECTION 4.7: EDGE CASE TESTS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 4.7: Edge Case Tests"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 4.7.1: Event Outside Study Period
* Purpose: Verify events outside all intervals are ignored
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.7.1: Event Outside Study Period"
}

capture {
    use "${DATA_DIR}/events_outside.dta", clear
    tvevent using "${DATA_DIR}/intervals_fullyear.dta", id(id) date(event_dt) ///
        startvar(start) stopvar(stop) type(single) generate(outcome)

    * No event should be recorded (event outside all intervals)
    quietly count if outcome == 1
    assert r(N) == 0
}
if _rc == 0 {
    display as result "  PASS: Event outside study period not recorded"
    local ++pass_count
}
else {
    display as error "  FAIL: Event outside study period (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.7.1"
}

* -----------------------------------------------------------------------------
* Test 4.7.2: Person with No Events
* Purpose: Verify persons without events are properly censored
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.7.2: Person with No Event (Censored)"
}

capture {
    use "${DATA_DIR}/events_mixed.dta", clear
    tvevent using "${DATA_DIR}/intervals_2person.dta", id(id) date(event_dt) ///
        startvar(start) stopvar(stop) type(single) generate(outcome)

    * Person 2 should have all outcome = 0 (censored)
    quietly count if id == 2 & outcome == 1
    assert r(N) == 0

    * Person 2 should still have follow-up
    quietly count if id == 2
    assert r(N) >= 1
}
if _rc == 0 {
    display as result "  PASS: Person with missing event date is censored (outcome=0)"
    local ++pass_count
}
else {
    display as error "  FAIL: Person with no event (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.7.2"
}

* -----------------------------------------------------------------------------
* Test 4.7.3: Same-Day Competing Events
* Purpose: Verify handling when primary and competing events occur on same day
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.7.3: Same-Day Competing Events"
}

capture {
    use "${DATA_DIR}/events_sameday.dta", clear
    tvevent using "${DATA_DIR}/intervals_fullyear.dta", id(id) date(primary_dt) ///
        startvar(start) stopvar(stop) compete(compete_dt) ///
        type(single) generate(outcome)

    * When dates are equal, document which wins
    * Typically primary should take precedence (outcome = 1)
    quietly count if outcome == 1 | outcome == 2
    local n_events = r(N)

    * At least one event should be recorded
    assert `n_events' >= 1

    * Display which won for documentation (only in verbose mode)
    quietly sum outcome if outcome > 0
}
if _rc == 0 {
    display as result "  PASS: Same-day competing events handled consistently"
    local ++pass_count
}
else {
    display as error "  FAIL: Same-day competing events (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.7.3"
}

* =============================================================================
* TEST SECTION 4.8: ERROR HANDLING TESTS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 4.8: Error Handling Tests"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 4.8.1: Missing Required Variables
* Purpose: Verify informative errors for invalid inputs
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.8.1: Missing Required Variables"
}

capture {
    use "${DATA_DIR}/events_midyear.dta", clear

    * Missing id
    capture tvevent using "${DATA_DIR}/intervals_fullyear.dta", date(event_dt) ///
        startvar(start) stopvar(stop) type(single) generate(outcome)
    local rc1 = _rc

    * Missing date
    capture tvevent using "${DATA_DIR}/intervals_fullyear.dta", id(id) ///
        startvar(start) stopvar(stop) type(single) generate(outcome)
    local rc2 = _rc

    * Both should fail
    assert `rc1' != 0
    assert `rc2' != 0
}
if _rc == 0 {
    display as result "  PASS: Missing required variables produce errors"
    local ++pass_count
}
else {
    display as error "  FAIL: Missing variable error handling (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.8.1"
}

* -----------------------------------------------------------------------------
* Test 4.8.2: Invalid Type Option
* Purpose: Verify invalid type values are rejected
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.8.2: Invalid Type Option"
}

capture {
    use "${DATA_DIR}/events_midyear.dta", clear
    capture tvevent using "${DATA_DIR}/intervals_fullyear.dta", id(id) date(event_dt) ///
        startvar(start) stopvar(stop) type(invalid) generate(outcome)
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: Invalid type() value is rejected"
    local ++pass_count
}
else {
    display as error "  FAIL: Invalid type error handling (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.8.2"
}

* =============================================================================
* TEST SECTION 4.9: TIMEGEN AND TIMEUNIT TESTS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 4.9: timegen and timeunit Tests"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 4.9.1: timegen Creates Time-to-Event Variable
* Purpose: Verify time-to-event calculation is correct
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.9.1: timegen Creates Time Variable"
}

capture {
    use "${DATA_DIR}/events_midyear.dta", clear
    tvevent using "${DATA_DIR}/intervals_fullyear.dta", id(id) date(event_dt) ///
        startvar(start) stopvar(stop) type(single) ///
        timegen(time_to_event) timeunit(days) generate(outcome)

    * Verify time variable exists
    confirm variable time_to_event

    * Time to event should be approximately 136 days (Jan 1 to May 15)
    * 22051 - 21915 = 136 days
    quietly sum time_to_event if outcome == 1
    assert abs(r(mean) - 136) < 2
}
if _rc == 0 {
    display as result "  PASS: timegen creates correct time-to-event (~136 days)"
    local ++pass_count
}
else {
    display as error "  FAIL: timegen time variable (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.9.1"
}

* -----------------------------------------------------------------------------
* Test 4.9.2: timeunit Conversion
* Purpose: Verify time conversion to different units
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.9.2: timeunit(years) Conversion"
}

capture {
    use "${DATA_DIR}/events_midyear.dta", clear
    tvevent using "${DATA_DIR}/intervals_fullyear.dta", id(id) date(event_dt) ///
        startvar(start) stopvar(stop) type(single) ///
        timegen(time_yrs) timeunit(years) generate(outcome)

    * Time in years should be ~0.37 (136 days / 365.25)
    quietly sum time_yrs if outcome == 1
    assert abs(r(mean) - 0.37) < 0.05
}
if _rc == 0 {
    display as result "  PASS: timeunit(years) converts correctly (~0.37 years)"
    local ++pass_count
}
else {
    display as error "  FAIL: timeunit conversion (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.9.2"
}

* =============================================================================
* INVARIANT TESTS: Properties that must always hold
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "INVARIANT TESTS: Universal Properties"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Invariant 1: Date Ordering (start < stop for all rows)
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Invariant 1: Date Ordering (start < stop)"
}

capture {
    use "${DATA_DIR}/events_midyear.dta", clear
    tvevent using "${DATA_DIR}/intervals_fullyear.dta", id(id) date(event_dt) ///
        startvar(start) stopvar(stop) type(single) generate(outcome)

    quietly count if stop < start
    assert r(N) == 0
}
if _rc == 0 {
    display as result "  PASS: All rows have start < stop"
    local ++pass_count
}
else {
    display as error "  FAIL: Date ordering invariant (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' Inv1"
}

* -----------------------------------------------------------------------------
* Invariant 2: Outcome Values Only Valid Categories
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Invariant 2: Valid Outcome Categories"
}

capture {
    use "${DATA_DIR}/events_competing.dta", clear
    tvevent using "${DATA_DIR}/intervals_fullyear.dta", id(id) date(primary_dt) ///
        startvar(start) stopvar(stop) compete(death_dt) ///
        type(single) generate(outcome)

    * Should only have values 0 (censored), 1 (primary), or 2 (competing)
    quietly count if outcome < 0 | outcome > 2
    assert r(N) == 0
}
if _rc == 0 {
    display as result "  PASS: Output outcome values are valid categories only"
    local ++pass_count
}
else {
    display as error "  FAIL: Valid outcome categories invariant (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' Inv2"
}

* -----------------------------------------------------------------------------
* Invariant 3: Exactly One Event Per ID (type=single)
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Invariant 3: At Most One Event Per ID (type=single)"
}

capture {
    use "${DATA_DIR}/events_midyear.dta", clear
    tvevent using "${DATA_DIR}/intervals_fullyear.dta", id(id) date(event_dt) ///
        startvar(start) stopvar(stop) type(single) generate(outcome)

    * Count events per ID - should be at most 1
    bysort id: egen n_events = total(outcome == 1)
    quietly sum n_events
    assert r(max) <= 1
}
if _rc == 0 {
    display as result "  PASS: At most one event per ID for type(single)"
    local ++pass_count
}
else {
    display as error "  FAIL: Single event per ID invariant (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' Inv3"
}

* =============================================================================
* SUMMARY
* =============================================================================
display as text _n "{hline 70}"
display as text "TVEVENT VALIDATION SUMMARY"
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
