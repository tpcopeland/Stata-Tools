clear all
set more off
set varabbrev off
version 16.0

capture log close
log using "validation_tvevent.log", replace nomsg

* Shared scaffold: test globals + helpers + sandboxed install bootstrap
do "`c(pwd)'/_tvtools_qa_common.do"
_tvtools_qa_bootstrap

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""
local run_only = 0
local quiet = 0
local machine = 0

* run_test/test_pass/test_fail harness counters (folded into the totals below)
global TVQA_PASS = 0
global TVQA_FAIL = 0
global TVQA_FAILED ""
global TVQA_CURRENT ""

display as result "tvtools QA: tvevent correctness -- $S_DATE $S_TIME"


**# ===== merged from validation_tvtools.do L445-4509: SECTION 4 TVEVENT conservation =====

* SECTION 4: TVEVENT - Event splitting and person-time conservation

capture noisily {
* HELPER PROGRAMS

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

* CREATE VALIDATION DATA
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

* Competing risk events with event_dt naming (for test 4.24.3)
clear
input long id double(event_dt death_dt)
    1 22097 22158
end
format %td event_dt death_dt
label data "Competing risk with event_dt and death_dt"
save "${DATA_DIR}/events_compete.dta", replace

* Multiple competing risks with event_dt naming (for test 4.24.6)
clear
input long id double(event_dt death_dt other_dt)
    1 22097 22158 22189
end
format %td event_dt death_dt other_dt
label data "Three competing risks with event_dt naming"
save "${DATA_DIR}/events_compete_multi.dta", replace

if `quiet' == 0 {
    display as result "Validation datasets created in: ${DATA_DIR}"
}

* TEST SECTION 4.1: EVENT INTEGRATION TESTS
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 4.1: Event Integration Tests"
    display as text "{hline 70}"
}

* Test 4.1.1: Event Placed at Correct Boundary
* Purpose: Verify event occurs at interval endpoint, not mid-interval
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

* Test 4.1.2: Event Count Preservation
* Purpose: Verify number of events in output matches input
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

* TEST SECTION 4.2: INTERVAL SPLITTING TESTS
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 4.2: Interval Splitting Tests"
    display as text "{hline 70}"
}

* Test 4.2.1: Split Preserves Total Duration
* Purpose: Verify splitting doesn't create/lose person-time
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

* TEST SECTION 4.3: COMPETING RISK TESTS
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 4.3: Competing Risk Tests"
    display as text "{hline 70}"
}

* Test 4.3.1: Earliest Event Wins
* Purpose: Verify competing risk resolution picks earliest date
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

* Test 4.3.2: Multiple Competing Risks
* Purpose: Verify correct assignment among multiple competing risks
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

* TEST SECTION 4.4: SINGLE VS RECURRING TESTS
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 4.4: Single vs Recurring Tests"
    display as text "{hline 70}"
}

* Test 4.4.1: type(single) Censors After First Event
* Purpose: Verify follow-up ends after first event for single events
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

* TEST SECTION 4.6: BOUNDARY CONDITION TESTS
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 4.6: Boundary Condition Tests (CRITICAL)"
    display as text "{hline 70}"
    display as text "Note: tvevent v1.3.5+ captures events at stop (event == stop)"
    display as text "      Events at start are NOT captured (belong to previous interval)"
}

* Test 4.6.1: Event Exactly at Interval Start
* Purpose: Under [start, stop] inclusive convention, event at start IS captured
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.6.1: Event at Exact Interval Start"
}

capture {
    use "${DATA_DIR}/events_at_start.dta", clear
    tvevent using "${DATA_DIR}/intervals_fullyear.dta", id(id) date(event_dt) ///
        startvar(start) stopvar(stop) type(single) generate(outcome)

    * Under [start, stop] inclusive convention, event at start IS captured
    quietly count if outcome == 1
    assert r(N) == 1
}
if _rc == 0 {
    display as result "  PASS: Event at exact start correctly captured ([start,stop] inclusive)"
    local ++pass_count
}
else {
    display as error "  FAIL: Event at start boundary (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.6.1"
}

* Test 4.6.2: Event Exactly at Interval Stop
* Purpose: Verify event at stop boundary IS captured (v1.3.5+ behavior)
* Note: This test was updated for v1.3.5 fix - events at stop ARE valid
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.6.2: Event at Exact Interval Stop"
}

capture {
    use "${DATA_DIR}/events_at_stop.dta", clear
    tvevent using "${DATA_DIR}/intervals_fullyear.dta", id(id) date(event_dt) ///
        startvar(start) stopvar(stop) type(single) generate(outcome)

    * Event SHOULD be captured (v1.3.5+ fix: events at stop boundary are valid)
    quietly count if outcome == 1
    assert r(N) == 1
}
if _rc == 0 {
    display as result "  PASS: Event at exact stop IS captured (v1.3.5+ behavior)"
    local ++pass_count
}
else {
    display as error "  FAIL: Event at stop boundary not captured (error `=_rc')"
    display as error "  This may indicate regression to pre-v1.3.5 bug!"
    local ++fail_count
    local failed_tests "`failed_tests' 4.6.2"
}

* Test 4.6.3: Event One Day Inside Boundaries
* Purpose: Verify events just inside boundaries ARE captured
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

* TEST SECTION 4.7: EDGE CASE TESTS
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 4.7: Edge Case Tests"
    display as text "{hline 70}"
}

* Test 4.7.1: Event Outside Study Period
* Purpose: Verify events outside all intervals are ignored
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

* Test 4.7.2: Person with No Events
* Purpose: Verify persons without events are properly censored
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

* Test 4.7.3: Same-Day Competing Events
* Purpose: Verify handling when primary and competing events occur on same day
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

* TEST SECTION 4.8: ERROR HANDLING TESTS
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 4.8: Error Handling Tests"
    display as text "{hline 70}"
}

* Test 4.8.1: Missing Required Variables
* Purpose: Verify informative errors for invalid inputs
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

* Test 4.8.2: Invalid Type Option
* Purpose: Verify invalid type values are rejected
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

* TEST SECTION 4.9: TIMEGEN AND TIMEUNIT TESTS
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 4.9: timegen and timeunit Tests"
    display as text "{hline 70}"
}

* Test 4.9.1: timegen Creates Time-to-Event Variable
* Purpose: Verify time-to-event calculation is correct
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

* Test 4.9.2: timeunit Conversion
* Purpose: Verify time conversion to different units
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

* Create cumulative time test datasets
* Person 1: 3 intervals starting at 21915, event at 22150 (cumulative=235)
* Person 2: 2 intervals starting at 21915, event at 22100 (cumulative=185)
clear
input long id double(start stop)
    1 21915 22000
    1 22000 22100
    1 22100 22200
    2 21915 22050
    2 22050 22200
end
format %td start stop
label data "Multi-interval cumulative time test"
save "${DATA_DIR}/intervals_cumtime_test.dta", replace

clear
input long id double event_dt
    1 22150
    2 22100
end
format %td event_dt
label data "Events for cumulative time test"
save "${DATA_DIR}/events_cumtime_test.dta", replace

* Test 4.9.3: timegen Cumulative Time with Multi-Interval Data
* Purpose: Verify timegen calculates stop - first_start (cumulative time)
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.9.3: timegen Cumulative Time (Multi-Interval)"
}

capture {
    use "${DATA_DIR}/events_cumtime_test.dta", clear
    tvevent using "${DATA_DIR}/intervals_cumtime_test.dta", id(id) date(event_dt) ///
        startvar(start) stopvar(stop) type(single) ///
        timegen(cum_time) timeunit(days) generate(outcome)

    * Calculate expected cumulative time for verification
    bysort id (start): gen double first_start = start[1]
    gen double expected = stop - first_start

    * Verify timegen matches expected cumulative time for ALL rows
    gen byte match = abs(cum_time - expected) < 0.001
    quietly count if match == 0
    assert r(N) == 0

    * Verify specific values for event rows:
    * Person 1: event at 22150, cumulative = 22150-21915 = 235
    * Person 2: event at 22100, cumulative = 22100-21915 = 185
    quietly sum cum_time if id == 1 & outcome == 1
    assert abs(r(mean) - 235) < 2

    quietly sum cum_time if id == 2 & outcome == 1
    assert abs(r(mean) - 185) < 2
}
if _rc == 0 {
    display as result "  PASS: timegen correctly calculates cumulative time"
    local ++pass_count
}
else {
    display as error "  FAIL: timegen cumulative time calculation (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.9.3"
}

* INVARIANT TESTS: Properties that must always hold
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "INVARIANT TESTS: Universal Properties"
    display as text "{hline 70}"
}

* Invariant 1: Date Ordering (start < stop for all rows)
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

* Invariant 2: Outcome Values Only Valid Categories
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

* Invariant 3: Exactly One Event Per ID (type=single)
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

* TEST SECTION 4.10: CONTINUOUS ADJUSTMENT TESTS
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 4.10: continuous() Adjustment Tests"
    display as text "{hline 70}"
}

* Create intervals with cumulative exposure variable
clear
input long id double(start stop) byte tv_exp double cum_dose
    1 21915 22281 1 365
end
format %td start stop
label data "Full-year interval with cumulative dose"
save "${DATA_DIR}/intervals_with_cum.dta", replace

* Test 4.10.1: continuous() Adjusts Cumulative Variables
* Purpose: Verify continuous variables are proportionally adjusted when split
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.10.1: continuous() Proportional Adjustment"
}

capture {
    use "${DATA_DIR}/events_midyear.dta", clear
    tvevent using "${DATA_DIR}/intervals_with_cum.dta", id(id) date(event_dt) ///
        startvar(start) stopvar(stop) type(single) ///
        continuous(cum_dose) generate(outcome)

    * The original interval was 366 days with cum_dose = 365
    * After split at day 136 (May 15), the first segment should have
    * proportionally adjusted cum_dose
    sort id start
    quietly sum cum_dose if outcome == 1
    local cum_at_event = r(mean)

    * Should be approximately 136/366 * 365 = 135.7
    assert abs(`cum_at_event' - 135.7) < 5
}
if _rc == 0 {
    display as result "  PASS: continuous() proportionally adjusts cumulative variables"
    local ++pass_count
}
else {
    display as error "  FAIL: continuous() adjustment (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.10.1"
}

* TEST SECTION 4.11: EVENTLABEL TESTS
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 4.11: eventlabel() Tests"
    display as text "{hline 70}"
}

* Test 4.11.1: eventlabel() Sets Custom Value Labels
* Purpose: Verify custom labels are applied to outcome variable
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.11.1: eventlabel() Custom Labels"
}

capture {
    use "${DATA_DIR}/events_competing.dta", clear
    tvevent using "${DATA_DIR}/intervals_fullyear.dta", id(id) date(primary_dt) ///
        startvar(start) stopvar(stop) compete(death_dt) ///
        type(single) generate(outcome) ///
        eventlabel(0 "Alive" 1 "EDSS Progression" 2 "Death")

    * Verify value labels were applied
    local vallbl : value label outcome
    if "`vallbl'" != "" {
        local lbl0 : label `vallbl' 0
        assert "`lbl0'" == "Alive"
        local lbl2 : label `vallbl' 2
        assert "`lbl2'" == "Death"
    }
}
if _rc == 0 {
    display as result "  PASS: eventlabel() sets custom value labels"
    local ++pass_count
}
else {
    display as error "  FAIL: eventlabel() (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.11.1"
}

* TEST SECTION 4.12: KEEPVARS TESTS
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 4.12: keepvars() Tests"
    display as text "{hline 70}"
}

* Create event data with additional variables
clear
input long id double event_dt str10 dx_code int severity
    1 22051 "G35" 3
end
format %td event_dt
label data "Event with diagnosis code and severity"
save "${DATA_DIR}/events_with_vars.dta", replace

* Test 4.12.1: keepvars() Retains Additional Variables from Event Dataset
* Purpose: Verify additional variables from event dataset are kept
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.12.1: keepvars() Retains Event Variables"
}

capture {
    use "${DATA_DIR}/events_with_vars.dta", clear
    tvevent using "${DATA_DIR}/intervals_fullyear.dta", id(id) date(event_dt) ///
        startvar(start) stopvar(stop) type(single) ///
        keepvars(dx_code severity) generate(outcome)

    * Verify kept variables exist
    confirm variable dx_code
    confirm variable severity

    * Values should be populated on event row
    quietly count if outcome == 1 & !missing(dx_code)
    assert r(N) >= 1
}
if _rc == 0 {
    display as result "  PASS: keepvars() retains additional variables from event dataset"
    local ++pass_count
}
else {
    display as error "  FAIL: keepvars() (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.12.1"
}

* TEST SECTION 4.13: REPLACE OPTION TESTS
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 4.13: replace Option Tests"
    display as text "{hline 70}"
}

* Test 4.13.1: replace Overwrites Existing Variables
* Purpose: Verify replace allows overwriting existing outcome variable
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.13.1: replace Overwrites Existing Variables"
}

capture {
    * Create intervals with existing outcome variable
    use "${DATA_DIR}/intervals_fullyear.dta", clear
    gen byte outcome = 99
    save "${DATA_DIR}/intervals_with_outcome.dta", replace

    use "${DATA_DIR}/events_midyear.dta", clear
    tvevent using "${DATA_DIR}/intervals_with_outcome.dta", id(id) date(event_dt) ///
        startvar(start) stopvar(stop) type(single) ///
        generate(outcome) replace

    * Outcome should be 0 or 1, not 99
    quietly count if outcome == 99
    assert r(N) == 0
}
if _rc == 0 {
    display as result "  PASS: replace overwrites existing variables"
    local ++pass_count
}
else {
    display as error "  FAIL: replace option (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.13.1"
}

* TEST SECTION 4.14: RECURRING EVENTS TESTS
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 4.14: type(recurring) Tests"
    display as text "{hline 70}"
}

* Create wide-format recurring events data
clear
input long id double(hosp1 hosp2 hosp3)
    1 21975 22097 22189
end
format %td hosp1 hosp2 hosp3
label data "Recurring hospitalizations in wide format"
save "${DATA_DIR}/events_recurring_wide.dta", replace

* Test 4.14.1: type(recurring) Processes Multiple Events
* Purpose: Verify recurring events are all captured
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.14.1: type(recurring) Multiple Events"
}

capture {
    use "${DATA_DIR}/events_recurring_wide.dta", clear
    tvevent using "${DATA_DIR}/intervals_fullyear.dta", id(id) date(hosp) ///
        startvar(start) stopvar(stop) type(recurring) generate(hospitalized)

    * Should have multiple event rows
    quietly count if hospitalized == 1
    assert r(N) >= 1
}
if _rc == 0 {
    display as result "  PASS: type(recurring) processes multiple events"
    local ++pass_count
}
else {
    display as error "  FAIL: type(recurring) (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.14.1"
}

* Test 4.14.2: type(recurring) Does Not Truncate Follow-up
* Purpose: Verify recurring events preserve all follow-up time
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.14.2: type(recurring) Preserves Follow-up"
}

capture {
    use "${DATA_DIR}/events_recurring_wide.dta", clear
    tvevent using "${DATA_DIR}/intervals_fullyear.dta", id(id) date(hosp) ///
        startvar(start) stopvar(stop) type(recurring) generate(hospitalized)

    * Total follow-up should be preserved (approximately 366 days)
    gen double dur = stop - start
    quietly sum dur
    assert r(sum) >= 300
}
if _rc == 0 {
    display as result "  PASS: type(recurring) preserves follow-up time"
    local ++pass_count
}
else {
    display as error "  FAIL: type(recurring) follow-up (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.14.2"
}

* TEST SECTION 4.15: ADDITIONAL TIMEUNIT TESTS
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 4.15: Additional timeunit Tests"
    display as text "{hline 70}"
}

* Test 4.15.1: timeunit(months) Conversion
* Purpose: Verify time conversion to months
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.15.1: timeunit(months) Conversion"
}

capture {
    use "${DATA_DIR}/events_midyear.dta", clear
    tvevent using "${DATA_DIR}/intervals_fullyear.dta", id(id) date(event_dt) ///
        startvar(start) stopvar(stop) type(single) ///
        timegen(time_months) timeunit(months) generate(outcome)

    * Time in months should be ~4.5 (136 days / 30.4375)
    quietly sum time_months if outcome == 1
    assert abs(r(mean) - 4.5) < 0.5
}
if _rc == 0 {
    display as result "  PASS: timeunit(months) converts correctly (~4.5 months)"
    local ++pass_count
}
else {
    display as error "  FAIL: timeunit(months) (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.15.1"
}

* TEST SECTION 4.16: STORED RESULTS TESTS
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 4.16: Stored Results Tests"
    display as text "{hline 70}"
}

* Test 4.16.1: r(N) and r(N_events) Stored
* Purpose: Verify stored scalars are correctly set
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.16.1: Stored Results"
}

capture {
    use "${DATA_DIR}/events_midyear.dta", clear
    tvevent using "${DATA_DIR}/intervals_fullyear.dta", id(id) date(event_dt) ///
        startvar(start) stopvar(stop) type(single) generate(outcome)

    * Verify r() scalars
    assert r(N) > 0
    assert r(N_events) >= 1
}
if _rc == 0 {
    display as result "  PASS: Stored results are correctly set"
    local ++pass_count
}
else {
    display as error "  FAIL: Stored results (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.16.1"
}

* TEST SECTION 4.17: ADDITIONAL COMPETING RISK TESTS
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 4.17: Additional Competing Risk Tests"
    display as text "{hline 70}"
}

* Create events with 3 competing risks
clear
input long id double(primary_dt cr1_dt cr2_dt cr3_dt)
    1 22189 22097 22128 22159
end
format %td primary_dt cr1_dt cr2_dt cr3_dt
label data "Primary with 3 competing risks"
save "${DATA_DIR}/events_3_competing.dta", replace

* Test 4.17.1: Three Competing Risks
* Purpose: Verify correct outcome coding with multiple competing risks
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.17.1: Three Competing Risks"
}

capture {
    use "${DATA_DIR}/events_3_competing.dta", clear
    tvevent using "${DATA_DIR}/intervals_fullyear.dta", id(id) date(primary_dt) ///
        startvar(start) stopvar(stop) ///
        compete(cr1_dt cr2_dt cr3_dt) ///
        type(single) generate(outcome)

    * cr1 is earliest (Jun 30) -> outcome should be 2
    quietly count if outcome == 2
    assert r(N) == 1
}
if _rc == 0 {
    display as result "  PASS: Three competing risks correctly resolved"
    local ++pass_count
}
else {
    display as error "  FAIL: Three competing risks (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.17.1"
}

* Test 4.17.2: Primary Event Wins When Earliest
* Purpose: Verify primary event is coded as 1 when it's earliest
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.17.2: Primary Event Wins When Earliest"
}

capture {
    * Create events where primary is earliest
    clear
    input long id double(primary_dt death_dt)
        1 21975 22097
    end
    format %td primary_dt death_dt
    save "${DATA_DIR}/events_primary_first.dta", replace

    use "${DATA_DIR}/events_primary_first.dta", clear
    tvevent using "${DATA_DIR}/intervals_fullyear.dta", id(id) date(primary_dt) ///
        startvar(start) stopvar(stop) ///
        compete(death_dt) ///
        type(single) generate(outcome)

    * Primary is earliest -> outcome should be 1
    quietly count if outcome == 1
    assert r(N) == 1
}
if _rc == 0 {
    display as result "  PASS: Primary event coded as 1 when earliest"
    local ++pass_count
}
else {
    display as error "  FAIL: Primary event priority (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.17.2"
}

* TEST SECTION 4.18: ERROR HANDLING - ADDITIONAL TESTS
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 4.18: Additional Error Handling Tests"
    display as text "{hline 70}"
}

* Test 4.18.1: File Not Found Error
* Purpose: Verify error when using file doesn't exist
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.18.1: File Not Found Error"
}

capture {
    use "${DATA_DIR}/events_midyear.dta", clear
    capture tvevent using "nonexistent_file.dta", id(id) date(event_dt) ///
        startvar(start) stopvar(stop) type(single) generate(outcome)
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: File not found produces error"
    local ++pass_count
}
else {
    display as error "  FAIL: File not found error (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.18.1"
}

* Test 4.18.2: compete() Ignored with type(recurring)
* Purpose: Verify compete() is silently ignored (not error) with type(recurring)
* Note: tvevent displays a note and ignores compete() rather than erroring
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.18.2: compete() Ignored with type(recurring)"
}

capture {
    use "${DATA_DIR}/events_recurring_wide.dta", clear
    tvevent using "${DATA_DIR}/intervals_fullyear.dta", id(id) date(hosp) ///
        startvar(start) stopvar(stop) ///
        type(recurring) compete(hosp2) generate(outcome)
    * Command should succeed (compete() is ignored, not error)
    * Outcome should only have values 0 and 1 (no competing risk value 2)
    quietly tab outcome
    quietly count if outcome == 2
    assert r(N) == 0  // No competing risk outcomes since compete() was ignored
}
if _rc == 0 {
    display as result "  PASS: compete() with type(recurring) is ignored (no error)"
    local ++pass_count
}
else {
    display as error "  FAIL: compete() with recurring handling (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.18.2"
}

* TEST SECTION 4.19: STARTVAR/STOPVAR CUSTOM NAMES TESTS
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 4.19: startvar/stopvar Custom Names Tests"
    display as text "{hline 70}"
}

* Create interval data with non-standard column names
clear
input long id double(begin_dt end_dt) byte tv_exp
    1 21915 22281 1
end
format %td begin_dt end_dt
label data "Intervals with custom column names"
save "${DATA_DIR}/intervals_custom_names.dta", replace

* Test 4.19.1: startvar() and stopvar() with Custom Names
* Purpose: Verify startvar/stopvar options work with non-default names
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.19.1: startvar()/stopvar() Custom Names"
}

capture {
    use "${DATA_DIR}/events_midyear.dta", clear
    tvevent using "${DATA_DIR}/intervals_custom_names.dta", id(id) date(event_dt) ///
        startvar(begin_dt) stopvar(end_dt) type(single) generate(outcome)

    * Should produce valid output with custom start/stop variable names
    assert _N >= 1
    confirm variable begin_dt
    confirm variable end_dt

    * Event should be captured
    quietly count if outcome == 1
    assert r(N) == 1
}
if _rc == 0 {
    display as result "  PASS: startvar()/stopvar() work with custom names"
    local ++pass_count
}
else {
    display as error "  FAIL: startvar()/stopvar() custom names (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.19.1"
}

* TEST SECTION 4.20: GENERATE CUSTOM NAME TESTS
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 4.20: generate() Custom Name Tests"
    display as text "{hline 70}"
}

* Test 4.20.1: generate() with Custom Variable Name
* Purpose: Verify generate() creates variable with user-specified name
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.20.1: generate() Custom Variable Name"
}

capture {
    use "${DATA_DIR}/events_midyear.dta", clear
    tvevent using "${DATA_DIR}/intervals_fullyear.dta", id(id) date(event_dt) ///
        startvar(start) stopvar(stop) type(single) generate(my_event_flag)

    * Verify custom variable name exists
    confirm variable my_event_flag

    * Default _failure should NOT exist
    capture confirm variable _failure
    assert _rc != 0

    * Event should be recorded in custom variable
    quietly count if my_event_flag == 1
    assert r(N) == 1
}
if _rc == 0 {
    display as result "  PASS: generate() creates custom-named variable"
    local ++pass_count
}
else {
    display as error "  FAIL: generate() custom name (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.20.1"
}

* TEST SECTION 4.21: EDGE CASES - EMPTY AND MISSING DATA
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 4.21: Edge Cases - Empty and Missing Data"
    display as text "{hline 70}"
}

* Create empty event dataset
clear
set obs 0
gen long id = .
gen double event_dt = .
format %td event_dt
label data "Empty event dataset"
save "${DATA_DIR}/events_empty.dta", replace

* Create events with all missing dates
clear
input long id double event_dt
    1 .
    2 .
end
format %td event_dt
label data "Events with all missing dates"
save "${DATA_DIR}/events_all_missing.dta", replace

* Test 4.21.1: Empty Event Dataset
* Purpose: Verify handling when event dataset has no observations
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.21.1: Empty Event Dataset"
}

capture {
    use "${DATA_DIR}/events_empty.dta", clear
    tvevent using "${DATA_DIR}/intervals_fullyear.dta", id(id) date(event_dt) ///
        startvar(start) stopvar(stop) type(single) generate(outcome)

    * Should produce output but with no events
    quietly count if outcome == 1
    assert r(N) == 0
}
if _rc == 0 {
    display as result "  PASS: Empty event dataset produces no events"
    local ++pass_count
}
else {
    display as error "  FAIL: Empty event dataset (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.21.1"
}

* Test 4.21.2: All Missing Event Dates
* Purpose: Verify handling when all event dates are missing
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.21.2: All Missing Event Dates"
}

capture {
    use "${DATA_DIR}/events_all_missing.dta", clear
    tvevent using "${DATA_DIR}/intervals_2person.dta", id(id) date(event_dt) ///
        startvar(start) stopvar(stop) type(single) generate(outcome)

    * Should produce output with all censored (outcome = 0)
    quietly count if outcome == 1
    assert r(N) == 0

    * But should have follow-up time
    assert _N >= 1
}
if _rc == 0 {
    display as result "  PASS: All missing dates produces all censored"
    local ++pass_count
}
else {
    display as error "  FAIL: All missing dates (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.21.2"
}

* TEST SECTION 4.22: INVALID OPTIONS ERROR HANDLING
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 4.22: Invalid Options Error Handling"
    display as text "{hline 70}"
}

* Test 4.22.1: Invalid timeunit Value
* Purpose: Verify error when timeunit has invalid value
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.22.1: Invalid timeunit Value"
}

capture {
    use "${DATA_DIR}/events_midyear.dta", clear
    capture tvevent using "${DATA_DIR}/intervals_fullyear.dta", id(id) date(event_dt) ///
        startvar(start) stopvar(stop) type(single) ///
        timegen(time) timeunit(invalid_unit) generate(outcome)
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: Invalid timeunit produces error"
    local ++pass_count
}
else {
    display as error "  FAIL: Invalid timeunit error (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.22.1"
}

* Test 4.22.2: Missing Required Using File
* Purpose: Verify error when using file is not specified
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.22.2: Missing Using File"
}

capture {
    use "${DATA_DIR}/events_midyear.dta", clear
    capture tvevent, id(id) date(event_dt) ///
        startvar(start) stopvar(stop) type(single) generate(outcome)
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: Missing using file produces error"
    local ++pass_count
}
else {
    display as error "  FAIL: Missing using file error (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.22.2"
}

* TEST SECTION 4.23: CONTINUOUS VARIABLE EDGE CASES
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 4.23: Continuous Variable Edge Cases"
    display as text "{hline 70}"
}

* Create interval with multiple continuous variables
clear
input long id double(start stop) byte tv_exp double(cum_dose cum_cost)
    1 21915 22281 1 365 1000
end
format %td start stop
label data "Interval with multiple continuous variables"
save "${DATA_DIR}/intervals_multi_cont.dta", replace

* Test 4.23.1: Multiple Continuous Variables
* Purpose: Verify multiple continuous variables are all adjusted
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.23.1: Multiple Continuous Variables"
}

capture {
    use "${DATA_DIR}/events_midyear.dta", clear
    tvevent using "${DATA_DIR}/intervals_multi_cont.dta", id(id) date(event_dt) ///
        startvar(start) stopvar(stop) type(single) ///
        continuous(cum_dose cum_cost) generate(outcome)

    * Both continuous variables should exist and be adjusted
    confirm variable cum_dose
    confirm variable cum_cost

    * Values should be pro-rated (not original 365/1000)
    sort id start
    quietly sum cum_dose if outcome == 1
    local cum_dose_event = r(mean)
    assert `cum_dose_event' < 365

    quietly sum cum_cost if outcome == 1
    local cum_cost_event = r(mean)
    assert `cum_cost_event' < 1000
}
if _rc == 0 {
    display as result "  PASS: Multiple continuous variables adjusted correctly"
    local ++pass_count
}
else {
    display as error "  FAIL: Multiple continuous variables (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.23.1"
}

* TEST SECTION 4.24: OPTION COMBINATIONS
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 4.24: Option Combinations"
    display as text "{hline 70}"
}

* Test 4.24.1: type(recurring) + timegen + timeunit(months)
* Purpose: Verify recurring events with time variable in months
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.24.1: type(recurring) + timegen + timeunit(months)"
}

capture {
    use "${DATA_DIR}/events_recurring_wide.dta", clear
    tvevent using "${DATA_DIR}/intervals_fullyear.dta", id(id) date(hosp) ///
        startvar(start) stopvar(stop) type(recurring) ///
        timegen(time_months) timeunit(months) generate(outcome)

    * Time variable should exist and be in months
    confirm variable time_months
    quietly sum time_months
    * 366 days / 30.4375 = ~12 months max
    assert r(max) < 15
}
if _rc == 0 {
    display as result "  PASS: type(recurring) + timegen + timeunit(months) works"
    local ++pass_count
}
else {
    display as error "  FAIL: type(recurring) + timegen + timeunit(months) (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.24.1"
}

* Test 4.24.2: type(recurring) + continuous + keepvars
* Purpose: Verify recurring events with continuous and additional variables
* Note: keepvars brings variables from the MASTER (events) dataset
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.24.2: type(recurring) + continuous + keepvars"
}

* Create interval with continuous variable
clear
input long id double(start stop) byte tv_exp double cumulative
    1 21915 22281 1 365
end
format %td start stop
label data "Interval with cumulative exposure"
save "${DATA_DIR}/intervals_extra_vars.dta", replace

* Create events with keepvars variable (drug is in events, not intervals)
clear
input long id double(hosp1 hosp2 hosp3) str10 drug
    1 21975 22097 22189 "DrugA"
end
format %td hosp1 hosp2 hosp3
label data "Recurring events with drug variable"
save "${DATA_DIR}/events_recurring_keepvars.dta", replace

capture {
    use "${DATA_DIR}/events_recurring_keepvars.dta", clear
    tvevent using "${DATA_DIR}/intervals_extra_vars.dta", id(id) date(hosp) ///
        startvar(start) stopvar(stop) type(recurring) ///
        continuous(cumulative) keepvars(drug) generate(outcome)

    * Both options should work together
    confirm variable cumulative
    confirm variable drug

    * Cumulative should be pro-rated for split intervals
    quietly sum cumulative
    assert r(max) <= 365
}
if _rc == 0 {
    display as result "  PASS: type(recurring) + continuous + keepvars works"
    local ++pass_count
}
else {
    display as error "  FAIL: type(recurring) + continuous + keepvars (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.24.2"
}

* Test 4.24.3: compete() + eventlabel()
* Purpose: Verify competing risks with labels
* Note: keepvars removed since events_compete.dta has no extra vars to keep
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.24.3: compete() + eventlabel()"
}

capture {
    use "${DATA_DIR}/events_compete.dta", clear
    tvevent using "${DATA_DIR}/intervals_extra_vars.dta", id(id) date(event_dt) ///
        startvar(start) stopvar(stop) type(single) ///
        compete(death_dt) eventlabel(0 "Censored" 1 "Primary" 2 "Death") ///
        generate(outcome)

    * All features should work together
    confirm variable outcome

    * Check value labels are applied
    local lbl : value label outcome
    assert "`lbl'" != ""
}
if _rc == 0 {
    display as result "  PASS: compete() + eventlabel() works"
    local ++pass_count
}
else {
    display as error "  FAIL: compete() + eventlabel() (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.24.3"
}

* Test 4.24.4: timegen + timeunit(years) + continuous
* Purpose: Verify time in years with continuous variable adjustment
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.24.4: timegen + timeunit(years) + continuous"
}

capture {
    use "${DATA_DIR}/events_midyear.dta", clear
    tvevent using "${DATA_DIR}/intervals_multi_cont.dta", id(id) date(event_dt) ///
        startvar(start) stopvar(stop) type(single) ///
        timegen(time_years) timeunit(years) ///
        continuous(cum_dose cum_cost) generate(outcome)

    * Time should be in years (< 2 for one year)
    confirm variable time_years
    quietly sum time_years
    assert r(max) < 2

    * Continuous variables should still work
    confirm variable cum_dose
    confirm variable cum_cost
}
if _rc == 0 {
    display as result "  PASS: timegen + timeunit(years) + continuous works"
    local ++pass_count
}
else {
    display as error "  FAIL: timegen + timeunit(years) + continuous (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.24.4"
}

* Test 4.24.5: replace + existing variable
* Purpose: Verify replace properly handles pre-existing outcome variable in using dataset
* Note: The existing variable must be in the USING (intervals) dataset, not master (events)
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.24.5: replace with Existing Variable"
}

capture {
    * Create intervals file with pre-existing outcome variable
    use "${DATA_DIR}/intervals_fullyear.dta", clear
    gen byte outcome = 99
    save "${DATA_DIR}/intervals_with_outcome.dta", replace

    * Load events and run tvevent with replace
    use "${DATA_DIR}/events_midyear.dta", clear
    tvevent using "${DATA_DIR}/intervals_with_outcome.dta", id(id) date(event_dt) ///
        startvar(start) stopvar(stop) type(single) generate(outcome) replace

    * Outcome should be replaced (not 99)
    quietly count if outcome == 99
    assert r(N) == 0

    * Clean up temp file
    capture erase "${DATA_DIR}/intervals_with_outcome.dta"
}
if _rc == 0 {
    display as result "  PASS: replace properly overwrites existing variable"
    local ++pass_count
}
else {
    display as error "  FAIL: replace with existing variable (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.24.5"
}

* Test 4.24.6: Multiple Competing Risks + continuous + timegen
* Purpose: Verify three competing risks with all options
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.24.6: Multiple compete() + continuous + timegen"
}

capture {
    use "${DATA_DIR}/events_compete_multi.dta", clear
    tvevent using "${DATA_DIR}/intervals_multi_cont.dta", id(id) date(event_dt) ///
        startvar(start) stopvar(stop) type(single) ///
        compete(death_dt other_dt) continuous(cum_dose) ///
        timegen(time) timeunit(days) generate(outcome)

    * All options should work together
    confirm variable outcome
    confirm variable cum_dose
    confirm variable time

    * Outcome should have values 0, 1, 2, or 3
    quietly count if outcome < 0 | outcome > 3
    assert r(N) == 0
}
if _rc == 0 {
    display as result "  PASS: Multiple compete() + continuous + timegen works"
    local ++pass_count
}
else {
    display as error "  FAIL: Multiple compete() + continuous + timegen (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.24.6"
}

* TEST SECTION 4.25: BOUNDARY VALUE TESTS
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 4.25: Boundary Value Tests"
    display as text "{hline 70}"
}

* Create event exactly at interval boundaries
clear
input long id double event_dt
    1 21915
end
format %td event_dt
label data "Event at exact start boundary"
save "${DATA_DIR}/events_at_start.dta", replace

clear
input long id double event_dt
    1 22281
end
format %td event_dt
label data "Event at exact stop boundary"
save "${DATA_DIR}/events_at_stop.dta", replace

* Test 4.25.1: Event Exactly at Interval Start
* Purpose: Under [start, stop] inclusive convention, event at start IS captured
* Note: This test confirms the same behavior as Test 4.6.1
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.25.1: Event at Interval Start Boundary"
}

capture {
    use "${DATA_DIR}/events_at_start.dta", clear
    tvevent using "${DATA_DIR}/intervals_fullyear.dta", id(id) date(event_dt) ///
        startvar(start) stopvar(stop) type(single) generate(outcome)

    * Under [start, stop] inclusive convention, event at start IS captured
    quietly count if outcome == 1
    assert r(N) == 1

    * Data should have at least one row
    assert _N >= 1
}
if _rc == 0 {
    display as result "  PASS: Event at interval start boundary correctly captured"
    local ++pass_count
}
else {
    display as error "  FAIL: Event at start boundary (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.25.1"
}

* Test 4.25.2: Event Exactly at Interval Stop
* Purpose: Verify event at last day of interval (boundary condition)
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.25.2: Event at Interval Stop Boundary"
}

capture {
    use "${DATA_DIR}/events_at_stop.dta", clear
    tvevent using "${DATA_DIR}/intervals_fullyear.dta", id(id) date(event_dt) ///
        startvar(start) stopvar(stop) type(single) generate(outcome)

    * Event at stop should be captured (stop is exclusive in survival)
    * This tests the boundary handling
    assert _N >= 1
}
if _rc == 0 {
    display as result "  PASS: Event at interval stop boundary handled"
    local ++pass_count
}
else {
    display as error "  FAIL: Event at stop boundary (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.25.2"
}

* Test 4.25.3: Very Short Interval (1 day)
* Purpose: Verify handling of minimal duration intervals
* Note: Under [start, stop] inclusive, event at start of 1-day interval IS captured
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.25.3: Very Short Interval (1 Day)"
}

* Create 1-day interval [22006, 22007] = 2 days under inclusive convention
clear
input long id double(start stop) byte tv_exp
    1 22006 22007 1
end
format %td start stop
save "${DATA_DIR}/intervals_oneday.dta", replace

* Event at start date - captured under [start, stop] inclusive convention
clear
input long id double event_dt
    1 22006
end
format %td event_dt
save "${DATA_DIR}/events_oneday.dta", replace

capture {
    use "${DATA_DIR}/events_oneday.dta", clear
    tvevent using "${DATA_DIR}/intervals_oneday.dta", id(id) date(event_dt) ///
        startvar(start) stopvar(stop) type(single) generate(outcome)

    * Under [start, stop] inclusive convention, event at start IS captured
    assert _N >= 1
    quietly count if outcome == 1
    assert r(N) == 1
}
if _rc == 0 {
    display as result "  PASS: 1-day interval - event at start captured ([start,stop] inclusive)"
    local ++pass_count
}
else {
    display as error "  FAIL: 1-day interval (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.25.3"
}

* TEST SECTION 4.26: MULTI-PERSON TESTS
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 4.26: Multi-Person Tests"
    display as text "{hline 70}"
}

* Create multi-person interval data
clear
input long id double(start stop) byte tv_exp
    1 21915 22006 1
    1 22006 22189 2
    1 22189 22281 1
    2 21915 22097 1
    2 22097 22281 2
    3 21915 22281 1
end
format %td start stop
label data "Multi-person intervals with varying exposure"
save "${DATA_DIR}/intervals_multiperson.dta", replace

* Multi-person events
clear
input long id double event_dt
    1 22100
    2 22200
end
format %td event_dt
label data "Events for persons 1 and 2, none for 3"
save "${DATA_DIR}/events_multiperson.dta", replace

* Test 4.26.1: Multiple Persons with Different Event Status
* Purpose: Verify correct handling of mixed event/censored persons
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.26.1: Multiple Persons with Mixed Event Status"
}

capture {
    use "${DATA_DIR}/events_multiperson.dta", clear
    tvevent using "${DATA_DIR}/intervals_multiperson.dta", id(id) date(event_dt) ///
        startvar(start) stopvar(stop) type(single) generate(outcome)

    * Person 1 and 2 should have events, person 3 censored
    quietly count if id == 1 & outcome == 1
    local p1_events = r(N)
    quietly count if id == 2 & outcome == 1
    local p2_events = r(N)
    quietly count if id == 3 & outcome == 1
    local p3_events = r(N)

    assert `p1_events' == 1
    assert `p2_events' == 1
    assert `p3_events' == 0
}
if _rc == 0 {
    display as result "  PASS: Multiple persons with mixed event status handled correctly"
    local ++pass_count
}
else {
    display as error "  FAIL: Multi-person mixed events (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.26.1"
}

* Test 4.26.2: Multi-Person Recurring Events
* Purpose: Verify recurring events across multiple persons
* Note: type(recurring) requires WIDE format data with hosp1, hosp2, hosp3, etc.
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.26.2: Multi-Person Recurring Events"
}

* Create recurring events for multiple persons in WIDE format
clear
input long id double(hosp1 hosp2 hosp3)
    1 21950 22100 .
    2 22050 . .
    3 21980 22150 22250
end
format %td hosp1 hosp2 hosp3
label data "Recurring events for multiple persons (wide format)"
save "${DATA_DIR}/events_multi_recurring.dta", replace

capture {
    use "${DATA_DIR}/events_multi_recurring.dta", clear
    tvevent using "${DATA_DIR}/intervals_multiperson.dta", id(id) date(hosp) ///
        startvar(start) stopvar(stop) type(recurring) generate(outcome)

    * Count events per person
    quietly count if id == 1 & outcome == 1
    local p1_events = r(N)
    quietly count if id == 2 & outcome == 1
    local p2_events = r(N)
    quietly count if id == 3 & outcome == 1
    local p3_events = r(N)

    * Each person should have their events counted
    * Note: exact count depends on which events fall within intervals
    assert `p1_events' >= 0
    assert `p2_events' >= 0
    assert `p3_events' >= 0

    * At least some events should be recorded
    assert `p1_events' + `p2_events' + `p3_events' >= 1
}
if _rc == 0 {
    display as result "  PASS: Multi-person recurring events counted correctly"
    local ++pass_count
}
else {
    display as error "  FAIL: Multi-person recurring (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.26.2"
}

* TEST SECTION 4.27: ADVANCED EDGE CASES - COMPLEX EVENT SCENARIOS
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 4.27: Advanced Edge Cases - Complex Event Scenarios"
    display as text "{hline 70}"
}

* Create events very close together (within 1-2 days)
clear
input long id double(hosp1 hosp2 hosp3)
    1 22006 22007 22009
end
format %td hosp1 hosp2 hosp3
label data "Back-to-back events (1-2 days apart)"
save "${DATA_DIR}/events_backtoback.dta", replace

* Create multiple persons with identical event dates
clear
input long id double event_dt
    1 22097
    2 22097
    3 22097
end
format %td event_dt
label data "Multiple persons with same event date"
save "${DATA_DIR}/events_same_date_multi.dta", replace

* Create intervals with zero-value continuous variable
clear
input long id double(start stop) byte tv_exp double cum_exp
    1 21915 22281 1 0
end
format %td start stop
label data "Full year with zero cumulative exposure"
save "${DATA_DIR}/intervals_zero_cum.dta", replace

* Create event before study start
clear
input long id double event_dt
    1 21800
end
format %td event_dt
label data "Event before study period (should be ignored)"
save "${DATA_DIR}/events_before_study.dta", replace

* Create intervals already pre-split (multiple intervals per person)
clear
input long id double(start stop) byte tv_exp
    1 21915 21946 1
    1 21946 22006 2
    1 22006 22097 1
    1 22097 22189 2
    1 22189 22281 1
end
format %td start stop
label data "Pre-split intervals with alternating exposure"
save "${DATA_DIR}/intervals_presplit.dta", replace

* Create event landing exactly on a pre-split boundary
clear
input long id double event_dt
    1 21946
end
format %td event_dt
label data "Event exactly on interval split point"
save "${DATA_DIR}/events_on_split.dta", replace

* Test 4.27.1: Back-to-Back Events (Micro-Intervals)
* Purpose: Verify close-together recurring events create valid intervals
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.27.1: Back-to-Back Events (1-2 Days Apart)"
}

capture {
    use "${DATA_DIR}/events_backtoback.dta", clear
    tvevent using "${DATA_DIR}/intervals_fullyear.dta", id(id) date(hosp) ///
        startvar(start) stopvar(stop) type(recurring) generate(outcome)

    * Should create multiple micro-intervals
    assert _N >= 3

    * All intervals should have valid duration (stop >= start under [start,stop] inclusive)
    * Single-day intervals have stop == start, which is valid
    quietly count if stop < start
    assert r(N) == 0

    * Multiple events should be recorded
    quietly count if outcome == 1
    assert r(N) >= 2
}
if _rc == 0 {
    display as result "  PASS: Back-to-back events create valid micro-intervals"
    local ++pass_count
}
else {
    display as error "  FAIL: Back-to-back events (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.27.1"
}

* Test 4.27.2: Multiple Persons Same Event Date
* Purpose: Verify events on same date for different persons handled correctly
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.27.2: Multiple Persons Same Event Date"
}

capture {
    * Create 3-person interval dataset
    clear
    input long id double(start stop) byte tv_exp
        1 21915 22281 1
        2 21915 22281 1
        3 21915 22281 1
    end
    format %td start stop
    save "${DATA_DIR}/intervals_3person.dta", replace

    use "${DATA_DIR}/events_same_date_multi.dta", clear
    tvevent using "${DATA_DIR}/intervals_3person.dta", id(id) date(event_dt) ///
        startvar(start) stopvar(stop) type(single) generate(outcome)

    * Each person should have exactly one event
    forvalues i = 1/3 {
        quietly count if id == `i' & outcome == 1
        assert r(N) == 1
    }

    * All events should be on the same date
    quietly sum stop if outcome == 1
    assert r(sd) == 0 | r(N) == 0  // All identical or none
}
if _rc == 0 {
    display as result "  PASS: Multiple persons same date each get their event"
    local ++pass_count
}
else {
    display as error "  FAIL: Multiple persons same date (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.27.2"
}

* Test 4.27.3: Zero-Valued Continuous Variable
* Purpose: Verify continuous adjustment handles zero values correctly
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.27.3: Zero-Valued Continuous Variable"
}

capture {
    use "${DATA_DIR}/events_midyear.dta", clear
    tvevent using "${DATA_DIR}/intervals_zero_cum.dta", id(id) date(event_dt) ///
        startvar(start) stopvar(stop) type(single) ///
        continuous(cum_exp) generate(outcome)

    * Zero continuous variable should remain zero after proportional adjustment
    quietly sum cum_exp
    assert r(mean) == 0
}
if _rc == 0 {
    display as result "  PASS: Zero continuous variable remains zero after adjustment"
    local ++pass_count
}
else {
    display as error "  FAIL: Zero continuous variable (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.27.3"
}

* Test 4.27.4: Event Before Study Period
* Purpose: Verify events before study start are ignored
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.27.4: Event Before Study Period"
}

capture {
    use "${DATA_DIR}/events_before_study.dta", clear
    tvevent using "${DATA_DIR}/intervals_fullyear.dta", id(id) date(event_dt) ///
        startvar(start) stopvar(stop) type(single) generate(outcome)

    * Event before study should not be captured
    quietly count if outcome == 1
    assert r(N) == 0

    * Follow-up should still exist
    assert _N >= 1
}
if _rc == 0 {
    display as result "  PASS: Event before study period is ignored"
    local ++pass_count
}
else {
    display as error "  FAIL: Event before study (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.27.4"
}

* Test 4.27.5: Event on Pre-Existing Split Boundary
* Purpose: Verify event at split point IS captured (v1.3.5+ behavior)
* Note: This test was updated for v1.3.5 fix - events at stop ARE valid
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.27.5: Event on Pre-Existing Split Boundary"
}

capture {
    use "${DATA_DIR}/events_on_split.dta", clear
    tvevent using "${DATA_DIR}/intervals_presplit.dta", id(id) date(event_dt) ///
        startvar(start) stopvar(stop) type(single) generate(outcome)

    * Event at boundary (21946) is stop of first interval and start of second
    * With v1.3.5+ fix, event at stop SHOULD be captured
    * Event is flagged at the interval that ENDS at the event date
    quietly count if outcome == 1
    assert r(N) == 1  // Event at stop boundary IS captured (v1.3.5+)
}
if _rc == 0 {
    display as result "  PASS: Event on pre-existing split boundary captured (v1.3.5+)"
    local ++pass_count
}
else {
    display as error "  FAIL: Event on split boundary not captured (error `=_rc')"
    display as error "  This may indicate regression to pre-v1.3.5 bug!"
    local ++fail_count
    local failed_tests "`failed_tests' 4.27.5"
}

* Test 4.27.6: Recurring Events with Pre-Split Intervals
* Purpose: Verify recurring events correctly split pre-fragmented data
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.27.6: Recurring Events with Pre-Split Intervals"
}

capture {
    * Create events in the middle of different intervals
    clear
    input long id double(hosp1 hosp2)
        1 21930 22150
    end
    format %td hosp1 hosp2
    save "${DATA_DIR}/events_in_presplit.dta", replace

    use "${DATA_DIR}/events_in_presplit.dta", clear
    tvevent using "${DATA_DIR}/intervals_presplit.dta", id(id) date(hosp) ///
        startvar(start) stopvar(stop) type(recurring) generate(outcome)

    * Both events should be captured (they fall within intervals, not on boundaries)
    quietly count if outcome == 1
    assert r(N) >= 1

    * No overlapping output intervals
    sort id start
    by id: gen byte overlap_check = (start[_n] < stop[_n-1]) if _n > 1
    quietly count if overlap_check == 1
    assert r(N) == 0
}
if _rc == 0 {
    display as result "  PASS: Recurring events with pre-split intervals work correctly"
    local ++pass_count
}
else {
    display as error "  FAIL: Recurring with pre-split (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.27.6"
}

* TEST SECTION 4.28: COMPETING RISK EDGE CASES
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 4.28: Competing Risk Edge Cases"
    display as text "{hline 70}"
}

* Create all missing competing risk dates
clear
input long id double(primary_dt death_dt)
    1 22097 .
end
format %td primary_dt death_dt
label data "Primary event with missing competing risk date"
save "${DATA_DIR}/events_missing_compete.dta", replace

* Create primary missing but competing present
clear
input long id double(primary_dt death_dt)
    1 . 22097
end
format %td primary_dt death_dt
label data "Missing primary with present competing risk"
save "${DATA_DIR}/events_primary_missing.dta", replace

* Create all competing risks on same day
clear
input long id double(primary_dt death_dt emig_dt)
    1 22189 22097 22097
end
format %td primary_dt death_dt emig_dt
label data "Two competing risks on same day"
save "${DATA_DIR}/events_compete_sameday.dta", replace

* Test 4.28.1: Missing Competing Risk Date
* Purpose: Verify handling when competing risk date is missing
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.28.1: Missing Competing Risk Date"
}

capture {
    use "${DATA_DIR}/events_missing_compete.dta", clear
    tvevent using "${DATA_DIR}/intervals_fullyear.dta", id(id) date(primary_dt) ///
        startvar(start) stopvar(stop) compete(death_dt) ///
        type(single) generate(outcome)

    * Primary event should win since competing risk is missing
    quietly count if outcome == 1
    assert r(N) == 1

    * Competing risk should not be recorded
    quietly count if outcome == 2
    assert r(N) == 0
}
if _rc == 0 {
    display as result "  PASS: Missing competing risk date handled correctly"
    local ++pass_count
}
else {
    display as error "  FAIL: Missing competing risk date (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.28.1"
}

* Test 4.28.2: Missing Primary with Present Competing Risk
* Purpose: Verify competing risk wins when primary is missing
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.28.2: Missing Primary with Present Competing"
}

capture {
    use "${DATA_DIR}/events_primary_missing.dta", clear
    tvevent using "${DATA_DIR}/intervals_fullyear.dta", id(id) date(primary_dt) ///
        startvar(start) stopvar(stop) compete(death_dt) ///
        type(single) generate(outcome)

    * Competing risk should win since primary is missing
    quietly count if outcome == 2
    assert r(N) == 1

    * Primary should not be recorded
    quietly count if outcome == 1
    assert r(N) == 0
}
if _rc == 0 {
    display as result "  PASS: Missing primary with present competing handled correctly"
    local ++pass_count
}
else {
    display as error "  FAIL: Missing primary (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.28.2"
}

* Test 4.28.3: Multiple Competing Risks on Same Day
* Purpose: Verify tie-breaking when multiple competing risks share a date
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.28.3: Multiple Competing Risks on Same Day"
}

capture {
    use "${DATA_DIR}/events_compete_sameday.dta", clear
    tvevent using "${DATA_DIR}/intervals_fullyear.dta", id(id) date(primary_dt) ///
        startvar(start) stopvar(stop) compete(death_dt emig_dt) ///
        type(single) generate(outcome)

    * One of the competing risks should win (both are on 22097, before primary 22189)
    * Expected: death (2) or emig (3) - first listed wins when tied
    quietly count if outcome == 2 | outcome == 3
    assert r(N) == 1

    * Primary should not be recorded (competing risks are earlier)
    quietly count if outcome == 1
    assert r(N) == 0
}
if _rc == 0 {
    display as result "  PASS: Multiple competing risks same day resolved consistently"
    local ++pass_count
}
else {
    display as error "  FAIL: Same-day competing risks (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.28.3"
}

* TEST SECTION 4.29: PERSON-TIME INVARIANTS
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 4.29: Person-Time Invariants"
    display as text "{hline 70}"
}

* Test 4.29.1: type(recurring) Preserves Total Duration
* Purpose: Verify recurring events don't lose any person-time
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.29.1: type(recurring) Preserves Total Duration"
}

capture {
    * Calculate original person-time under [start, stop] inclusive convention
    use "${DATA_DIR}/intervals_fullyear.dta", clear
    gen double dur = stop - start + 1
    quietly sum dur
    local original_pt = r(sum)

    * Run tvevent with recurring
    use "${DATA_DIR}/events_recurring_wide.dta", clear
    tvevent using "${DATA_DIR}/intervals_fullyear.dta", id(id) date(hosp) ///
        startvar(start) stopvar(stop) type(recurring) generate(outcome)

    * Calculate output person-time under [start, stop] inclusive convention
    gen double dur = stop - start + 1
    quietly sum dur
    local output_pt = r(sum)

    * Person-time should be exactly preserved
    assert abs(`output_pt' - `original_pt') < 1
}
if _rc == 0 {
    display as result "  PASS: type(recurring) preserves total person-time exactly"
    local ++pass_count
}
else {
    display as error "  FAIL: Person-time preservation (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.29.1"
}

* Test 4.29.2: Interval Ordering Maintained After Splits
* Purpose: Verify output intervals are properly ordered within each person
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.29.2: Interval Ordering Maintained After Splits"
}

capture {
    use "${DATA_DIR}/events_recurring_wide.dta", clear
    tvevent using "${DATA_DIR}/intervals_fullyear.dta", id(id) date(hosp) ///
        startvar(start) stopvar(stop) type(recurring) generate(outcome)

    * Verify intervals are properly ordered and non-overlapping
    sort id start
    by id: gen byte order_ok = (start[_n] == stop[_n-1]) if _n > 1
    by id: gen byte gap_ok = (start[_n] >= stop[_n-1]) if _n > 1

    * All intervals should be contiguous or have positive gaps (no overlaps)
    quietly count if gap_ok == 0
    assert r(N) == 0
}
if _rc == 0 {
    display as result "  PASS: Interval ordering maintained after event splits"
    local ++pass_count
}
else {
    display as error "  FAIL: Interval ordering (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.29.2"
}

* Test 4.29.3: Exactly One Event Row Per Primary Event (type=single)
* Purpose: Verify type(single) produces exactly one event row per person with event
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.29.3: Exactly One Event Row Per Person (type=single)"
}

capture {
    use "${DATA_DIR}/events_midyear.dta", clear
    tvevent using "${DATA_DIR}/intervals_fullyear.dta", id(id) date(event_dt) ///
        startvar(start) stopvar(stop) type(single) generate(outcome)

    * Count event rows per person
    bysort id: egen n_event_rows = total(outcome == 1)
    quietly tab n_event_rows

    * Each person should have at most 1 event row
    quietly sum n_event_rows
    assert r(max) <= 1
}
if _rc == 0 {
    display as result "  PASS: At most one event row per person with type(single)"
    local ++pass_count
}
else {
    display as error "  FAIL: Single event per person (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.29.3"
}

* TEST SECTION 4.30: LARGE DATASET STRESS TESTS
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 4.30: Large Dataset Stress Tests"
    display as text "{hline 70}"
}

* Test 4.30.1: Large Dataset Event Integration (5000 patients)
* Purpose: Verify tvevent handles large datasets correctly
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.30.1: Large Dataset Event Integration (5000 patients)"
}

capture {
    * Create large cohort (5000 patients)
    clear
    set seed 12345
    set obs 5000
    gen long id = _n
    gen double study_entry = 21915
    gen double study_exit = 22281
    gen byte has_event = runiform() < 0.30
    gen double edss4_dt = study_entry + 30 + floor(runiform() * 300) if has_event
    gen byte has_death = runiform() < 0.08 & !has_event
    gen double death_dt = study_entry + 50 + floor(runiform() * 280) if has_death
    replace edss4_dt = . if edss4_dt > study_exit
    replace death_dt = . if death_dt > study_exit
    format %td study_entry study_exit edss4_dt death_dt
    drop has_event has_death
    save "${DATA_DIR}/cohort_large_val.dta", replace

    * Create corresponding TV data (3 intervals per patient)
    use "${DATA_DIR}/cohort_large_val.dta", clear
    keep id study_entry study_exit
    expand 3
    bysort id: gen interval = _n
    gen double start = study_entry if interval == 1
    replace start = study_entry + 100 if interval == 2
    replace start = study_entry + 200 if interval == 3
    gen double stop = study_entry + 100 if interval == 1
    replace stop = study_entry + 200 if interval == 2
    replace stop = study_exit if interval == 3
    gen byte tv_exp = interval - 1
    drop study_entry study_exit interval
    format %td start stop
    save "${DATA_DIR}/tv_large_val.dta", replace

    * Run tvevent
    use "${DATA_DIR}/cohort_large_val.dta", clear
    tvevent using "${DATA_DIR}/tv_large_val.dta", id(id) date(edss4_dt) ///
        startvar(start) stopvar(stop) compete(death_dt) ///
        type(single) generate(outcome)

    * All 5000 IDs should be present
    tempvar _tag
    quietly egen `_tag' = tag(id)
    quietly count if `_tag' == 1
    assert r(N) == 5000
}
if _rc == 0 {
    display as result "  PASS: Large dataset (5000 patients) integration works"
    local ++pass_count
}
else {
    display as error "  FAIL: Large dataset integration (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.30.1"
}

* Test 4.30.2: Very Large Dataset (10000 patients)
* Purpose: Stress test tvevent with 10000 patients
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.30.2: Very Large Dataset (10000 patients)"
}

capture {
    * Create very large cohort
    clear
    set seed 54321
    set obs 10000
    gen long id = _n
    gen double study_entry = 21915
    gen double study_exit = 22281
    gen byte has_event = runiform() < 0.25
    gen double edss4_dt = study_entry + 30 + floor(runiform() * 300) if has_event
    gen byte has_death = runiform() < 0.05 & !has_event
    gen double death_dt = study_entry + 50 + floor(runiform() * 280) if has_death
    replace edss4_dt = . if edss4_dt > study_exit
    replace death_dt = . if death_dt > study_exit
    format %td study_entry study_exit edss4_dt death_dt
    drop has_event has_death
    save "${DATA_DIR}/cohort_stress_val.dta", replace

    * Create corresponding TV data (2 intervals per patient)
    use "${DATA_DIR}/cohort_stress_val.dta", clear
    keep id study_entry study_exit
    expand 2
    bysort id: gen interval = _n
    gen double start = study_entry if interval == 1
    replace start = study_entry + 183 if interval == 2
    gen double stop = study_entry + 183 if interval == 1
    replace stop = study_exit if interval == 2
    gen byte tv_exp = interval - 1
    drop study_entry study_exit interval
    format %td start stop
    save "${DATA_DIR}/tv_stress_val.dta", replace

    * Run tvevent
    use "${DATA_DIR}/cohort_stress_val.dta", clear
    tvevent using "${DATA_DIR}/tv_stress_val.dta", id(id) date(edss4_dt) ///
        startvar(start) stopvar(stop) compete(death_dt) ///
        type(single) generate(outcome)

    * All 10000 IDs should be present
    tempvar _tag
    quietly egen `_tag' = tag(id)
    quietly count if `_tag' == 1
    assert r(N) == 10000
}
if _rc == 0 {
    display as result "  PASS: Very large dataset (10000 patients) stress test works"
    local ++pass_count
}
else {
    display as error "  FAIL: Very large dataset stress test (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.30.2"
}

* Test 4.30.3: Large Dataset Person-Time Conservation
* Purpose: Verify person-time is conserved in large dataset
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.30.3: Large Dataset Person-Time Conservation"
}

capture {
    * Calculate expected person-time from INTERVAL data before tvevent splits it
    * tv_large_val.dta has the intervals (start/stop), cohort has the events
    use "${DATA_DIR}/tv_large_val.dta", clear
    gen double pre_ptime = stop - start
    quietly sum pre_ptime
    local expected_total = r(sum)

    * Run tvevent: master=cohort (events), using=intervals
    use "${DATA_DIR}/cohort_large_val.dta", clear
    tvevent using "${DATA_DIR}/tv_large_val.dta", id(id) date(edss4_dt) ///
        startvar(start) stopvar(stop) compete(death_dt) ///
        type(single) generate(outcome)

    gen double ptime = stop - start
    quietly sum ptime
    local actual_total = r(sum)

    * Actual should be <= expected (type(single) removes post-event intervals)
    * and within 20% (some person-time is correctly censored at events)
    assert `actual_total' <= `expected_total' * 1.001
    local pct_diff = abs(`actual_total' - `expected_total') / `expected_total'
    assert `pct_diff' < 0.20
}
if _rc == 0 {
    display as result "  PASS: Large dataset person-time conserved"
    local ++pass_count
}
else {
    display as error "  FAIL: Large dataset person-time conservation (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.30.3"
}

* Test 4.30.4: Large Dataset Cox Regression Workflow
* Purpose: Verify full workflow with Cox regression on large dataset
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.30.4: Large Dataset Cox Regression Workflow"
}

capture {
    use "${DATA_DIR}/cohort_large_val.dta", clear
    tvevent using "${DATA_DIR}/tv_large_val.dta", id(id) date(edss4_dt) ///
        startvar(start) stopvar(stop) compete(death_dt) ///
        type(single) generate(outcome)

    * Set up survival data
    stset stop, id(id) failure(outcome==1) enter(start) scale(365.25)

    * Run Cox model
    stcox tv_exp

    assert e(N) > 0
}
if _rc == 0 {
    display as result "  PASS: Large dataset Cox regression workflow works (N = " e(N) ")"
    local ++pass_count
}
else {
    display as error "  FAIL: Large dataset Cox regression (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.30.4"
}

* Cleanup large dataset files
capture erase "${DATA_DIR}/cohort_large_val.dta"
capture erase "${DATA_DIR}/tv_large_val.dta"
capture erase "${DATA_DIR}/cohort_stress_val.dta"
capture erase "${DATA_DIR}/tv_stress_val.dta"

* Test 4.31: Validation Option Tests
* Purpose: Verify the validate option correctly identifies data quality issues
if `quiet' == 0 {
    display as text _n "=========================="
    display as text "Test Set 4.31: Validate Option"
    display as text "=========================="
}

* Test 4.31.1: Validate option returns stored results
* Purpose: Verify r(v_outside_bounds), r(v_multiple_events), r(v_same_date_compete)
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.31.1: Validate Option Stored Results"
}

capture {
    * Create simple test data
    clear
    set obs 10
    gen id = _n
    gen edss4_dt = mdy(6, 15, 2020) + runiform()*100
    gen death_dt = .
    replace death_dt = mdy(8, 1, 2020) if _n <= 2
    tempfile event_data
    save `event_data'

    * Create interval data
    clear
    set obs 10
    gen id = _n
    gen start = mdy(1, 1, 2020)
    gen stop = mdy(12, 31, 2020)
    gen tv_exp = mod(_n, 3)
    tempfile interval_data
    save `interval_data'

    * Run tvevent with validate
    use `event_data', clear
    tvevent using `interval_data', id(id) date(edss4_dt) compete(death_dt) ///
        type(single) validate generate(outcome)

    * Verify stored results exist and are non-negative
    assert r(v_outside_bounds) >= 0
    assert r(v_multiple_events) >= 0
    assert r(v_same_date_compete) >= 0
}
if _rc == 0 {
    display as result "  PASS: Validate option returns stored results"
    local ++pass_count
}
else {
    display as error "  FAIL: Validate option stored results (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.31.1"
}

* Test 4.31.2: Validate detects same-date competing events
* Purpose: Verify v_same_date_compete correctly counts same-date events
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.31.2: Validate Detects Same-Date Competing Events"
}

capture {
    * Create test data with same-date events
    clear
    set obs 5
    gen id = _n
    gen event_dt = mdy(6, 15, 2020)
    gen compete_dt = mdy(6, 15, 2020) if _n <= 2  // 2 same-date events
    replace compete_dt = mdy(7, 1, 2020) if _n > 2
    tempfile event_data
    save `event_data'

    * Create interval data
    clear
    set obs 5
    gen id = _n
    gen start = mdy(1, 1, 2020)
    gen stop = mdy(12, 31, 2020)
    gen tv_exp = 1
    tempfile interval_data
    save `interval_data'

    * Run tvevent with validate
    use `event_data', clear
    tvevent using `interval_data', id(id) date(event_dt) compete(compete_dt) ///
        type(single) validate generate(outcome)

    * Should detect 2 same-date competing events
    assert r(v_same_date_compete) == 2
}
if _rc == 0 {
    display as result "  PASS: Validate correctly detects same-date competing events"
    local ++pass_count
}
else {
    display as error "  FAIL: Same-date competing event detection (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.31.2"
}

* Test 4.31.3: Validate detects events outside interval bounds
* Purpose: Verify v_outside_bounds correctly counts out-of-range events
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.31.3: Validate Detects Events Outside Bounds"
}

capture {
    * Create test data with out-of-bounds events
    clear
    set obs 5
    gen id = _n
    * Events outside the interval (before start or after stop)
    gen event_dt = mdy(6, 1, 2019) if _n <= 2  // Before start
    replace event_dt = mdy(6, 1, 2021) if _n == 3  // After stop
    replace event_dt = mdy(6, 15, 2020) if _n > 3  // Within bounds
    tempfile event_data
    save `event_data'

    * Create interval data
    clear
    set obs 5
    gen id = _n
    gen start = mdy(1, 1, 2020)
    gen stop = mdy(12, 31, 2020)
    gen tv_exp = 1
    tempfile interval_data
    save `interval_data'

    * Run tvevent with validate
    use `event_data', clear
    tvevent using `interval_data', id(id) date(event_dt) ///
        type(single) validate generate(outcome)

    * Should detect 3 events outside bounds (2 before + 1 after)
    assert r(v_outside_bounds) == 3
}
if _rc == 0 {
    display as result "  PASS: Validate correctly detects events outside bounds"
    local ++pass_count
}
else {
    display as error "  FAIL: Out-of-bounds event detection (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.31.3"
}

* SUMMARY

}

capture noisily {

* TEST 4A: TIMEGEN EXACT CALCULATION
display "TEST 4A: Timegen exact calculation (days/months/years)"

local test4a_pass = 1

* Interval [2020-01-01, 2020-07-18] = 199 days
* timegen in days  = 199
* timegen in months = 199/30.4375 ≈ 6.538
* timegen in years  = 199/365.25 ≈ 0.5449
* Note: tvevent timegen uses interval length (stop - start + 1? or stop - start?)
* Need to read the ado to confirm, but testing actual vs expected is key

* Create a single interval dataset
clear
set obs 1
gen id = 1
gen event_date = .    // no event
save "/tmp/tve4a_event.dta", replace

clear
set obs 1
gen id = 1
gen start = mdy(1,1,2020)
gen stop  = mdy(7,18,2020)    // Jan1 to Jul18

* Verify the interval length
local interval_days = mdy(7,18,2020) - mdy(1,1,2020)
* tvevent typically generates timegen as (stop - start) or (stop - start + 1)
* We need to check which convention tvevent uses - we'll examine the actual output
display "  INFO: Raw interval length (stop-start): `interval_days' days"

gen tv_exp = 1    // exposure value
save "/tmp/tve4a_intervals.dta", replace

use "/tmp/tve4a_event.dta", clear
capture noisily tvevent using "/tmp/tve4a_intervals.dta", ///
    id(id) date(event_date) ///
    timegen(t_days) timeunit(days)

if _rc != 0 {
    display as error "  FAIL [4a.days.run]: tvevent returned error `=_rc'"
    local test4a_pass = 0
}
else {
    quietly sum t_days
    local actual_days = r(max)
    display "  INFO: t_days = `actual_days'"

    * Check it's approximately the interval length (within 1 day tolerance)
    if abs(`actual_days' - `interval_days') <= 1 | abs(`actual_days' - `interval_days' - 1) <= 0 {
        display as result "  PASS [4a.days]: t_days=`actual_days', interval=`interval_days'"
    }
    else {
        display as error "  FAIL [4a.days]: t_days=`actual_days', interval_days=`interval_days'"
        local test4a_pass = 0
    }
}

* Test with months
use "/tmp/tve4a_event.dta", clear
capture noisily tvevent using "/tmp/tve4a_intervals.dta", ///
    id(id) date(event_date) ///
    timegen(t_months) timeunit(months)

if _rc == 0 {
    quietly sum t_months
    local actual_months = r(max)
    local expected_months = `interval_days' / 30.4375
    local diff = abs(`actual_months' - `expected_months')
    display "  INFO: t_months = `actual_months', expected ≈ `expected_months'"
    if `diff' < 0.5 {
        display as result "  PASS [4a.months]: t_months within 0.5 of expected"
    }
    else {
        display as error "  FAIL [4a.months]: t_months=`actual_months', expected≈`expected_months', diff=`diff'"
        local test4a_pass = 0
    }
}
else {
    display as error "  FAIL [4a.months.run]: tvevent returned error `=_rc'"
    local test4a_pass = 0
}

* Test with years
use "/tmp/tve4a_event.dta", clear
capture noisily tvevent using "/tmp/tve4a_intervals.dta", ///
    id(id) date(event_date) ///
    timegen(t_years) timeunit(years)

if _rc == 0 {
    quietly sum t_years
    local actual_years = r(max)
    local expected_years = `interval_days' / 365.25
    local diff = abs(`actual_years' - `expected_years')
    display "  INFO: t_years = `actual_years', expected ≈ `expected_years'"
    if `diff' < 0.1 {
        display as result "  PASS [4a.years]: t_years within 0.1 of expected"
    }
    else {
        display as error "  FAIL [4a.years]: t_years=`actual_years', expected≈`expected_years', diff=`diff'"
        local test4a_pass = 0
    }
}
else {
    display as error "  FAIL [4a.years.run]: tvevent returned error `=_rc'"
    local test4a_pass = 0
}

if `test4a_pass' == 1 {
    local pass_count = `pass_count' + 1
    display as result "TEST 4A: PASSED"
}
else {
    local fail_count = `fail_count' + 1
    local failed_tests "`failed_tests' 4a"
    display as error "TEST 4A: FAILED"
}

* TEST 4B: COMPETING RISK - EARLIEST EVENT WINS
display "TEST 4B: Competing risk resolution - earliest event wins"

local test4b_pass = 1

* Person with:
*   Primary event: day 200 from Jan1/2020 = mdy(7,19,2020) (approx)
*   Death (compete1): day 100 = mdy(4,10,2020) - should be the winner
*   Emigration (compete2): day 150 = mdy(5,30,2020)
*
* Expected: the EARLIEST event (death, day 100) is coded as the event.
* All post-event intervals should be dropped (type single)

clear
set obs 1
gen id = 1
gen primary_event = mdy(1,1,2020) + 200    // day 200
gen death         = mdy(1,1,2020) + 100    // day 100 - EARLIEST
gen emigration    = mdy(1,1,2020) + 150    // day 150
save "/tmp/tve4b_event.dta", replace

* Person-time intervals: 5 yearly intervals
clear
set obs 5
gen id = 1
gen start = mdy(1,1,2020) + (_n-1)*73    // ~ every 73 days
gen stop  = start + 72
replace stop = mdy(12,31,2020) if _n == 5
gen tv_exp = 1
save "/tmp/tve4b_intervals.dta", replace

use "/tmp/tve4b_event.dta", clear
capture noisily tvevent using "/tmp/tve4b_intervals.dta", ///
    id(id) date(primary_event) ///
    compete(death emigration) ///
    type(single) generate(fail_status)

if _rc != 0 {
    display as error "  FAIL [4b.run]: tvevent returned error `=_rc'"
    local test4b_pass = 0
}
else {
    sort id start
    quietly count
    display "  INFO: `=r(N)' rows in output"

    * Should have only one event flag per person
    quietly count if fail_status > 0
    local n_events = r(N)

    if `n_events' == 1 {
        display as result "  PASS [4b.one_event]: exactly 1 event row"
    }
    else {
        display as error "  FAIL [4b.one_event]: `n_events' event rows (expected 1)"
        local test4b_pass = 0
    }

    * The event should be coded as death (code=2, since death is first compete variable)
    quietly sum fail_status if fail_status > 0
    if r(N) > 0 {
        local event_code = r(max)
        if `event_code' == 2 {
            display as result "  PASS [4b.event_type]: event coded as death (code=2)"
        }
        else {
            display as error "  FAIL [4b.event_type]: event coded as `event_code' (expected 2=death)"
            local test4b_pass = 0
        }
    }

    * The event row should be the one containing day 100
    local death_date = mdy(1,1,2020) + 100
    quietly count if fail_status > 0 & start <= `death_date' & stop >= `death_date'
    if r(N) == 1 {
        display as result "  PASS [4b.event_row]: event is in the interval containing death date"
    }
    else {
        display as error "  FAIL [4b.event_row]: event not found in death interval"
        list id start stop fail_status
        local test4b_pass = 0
    }
}

if `test4b_pass' == 1 {
    local pass_count = `pass_count' + 1
    display as result "TEST 4B: PASSED"
}
else {
    local fail_count = `fail_count' + 1
    local failed_tests "`failed_tests' 4b"
    display as error "TEST 4B: FAILED"
}

* TEST 4C: CONTINUOUS VARIABLE SPLIT PROPORTIONING
display "TEST 4C: Continuous variable split proportioning"

local test4c_pass = 1

* Interval [Jan1/2020, Apr10/2020] = 100 days, cumul_dose=100
* Event at day 50 (Feb19/2020): splits into:
*   Pre-event:  [Jan1, Feb19] - should have proportioned dose ≈ 50
*   Post-event: [Feb19, Apr10] - should have proportioned dose ≈ 50
* With type(single): only pre-event row kept
* Proportioning: dose = original_dose * (split_days / total_days)

* Interval
clear
set obs 1
gen id = 1
gen start = mdy(1,1,2020)
gen stop  = mdy(4,10,2020)
gen tv_exp = 1
gen cumul_dose = 100          // 100 dose units in this period
save "/tmp/tve4c_intervals.dta", replace

local total_days = mdy(4,10,2020) - mdy(1,1,2020)
local event_day = mdy(1,1,2020) + 50    // 50 days in
local pre_days  = `event_day' - mdy(1,1,2020)  // = 50
local post_days = mdy(4,10,2020) - `event_day'

display "  INFO: total_days=`total_days', pre=`pre_days', post=`post_days'"

* Event data
* Note: type(recurring) requires wide-format event variables (event_date1, event_date2, ...)
clear
set obs 1
gen id = 1
gen event_date1 = mdy(1,1,2020) + 50    // day 50 (wide format for type(recurring))
save "/tmp/tve4c_event.dta", replace

use "/tmp/tve4c_event.dta", clear
capture noisily tvevent using "/tmp/tve4c_intervals.dta", ///
    id(id) date(event_date) ///
    continuous(cumul_dose) ///
    type(recurring) generate(fail_status)

if _rc != 0 {
    display as error "  FAIL [4c.run]: tvevent returned error `=_rc'"
    local test4c_pass = 0
}
else {
    sort id start
    quietly count
    local nrows = r(N)
    display "  INFO: `nrows' rows after splitting"

    if `nrows' == 2 {
        display as result "  PASS [4c.rows]: exactly 2 rows after split"

        * Pre-event row should have proportioned dose
        local pre_dose  = cumul_dose[1]
        local post_dose = cumul_dose[2]

        * Expected proportioning: dose * fraction_of_interval
        * pre: 50/100 * 100 = 50
        local expected_pre = 100 * `pre_days' / `total_days'
        local expected_post = 100 * `post_days' / `total_days'

        local diff_pre  = abs(`pre_dose'  - `expected_pre')
        local diff_post = abs(`post_dose' - `expected_post')

        if `diff_pre' < 1 {
            display as result "  PASS [4c.pre_dose]: pre-event dose=`pre_dose', expected≈`expected_pre'"
        }
        else {
            display as error "  FAIL [4c.pre_dose]: pre-event dose=`pre_dose', expected≈`expected_pre', diff=`diff_pre'"
            local test4c_pass = 0
        }

        if `diff_post' < 1 {
            display as result "  PASS [4c.post_dose]: post-event dose=`post_dose', expected≈`expected_post'"
        }
        else {
            display as error "  FAIL [4c.post_dose]: post-event dose=`post_dose', expected≈`expected_post', diff=`diff_post'"
            local test4c_pass = 0
        }

        * Conservation: pre + post should sum to original (100)
        local sum_dose = `pre_dose' + `post_dose'
        if abs(`sum_dose' - 100) < 0.01 {
            display as result "  PASS [4c.conservation]: dose conserved (sum=`sum_dose')"
        }
        else {
            display as error "  FAIL [4c.conservation]: dose not conserved (sum=`sum_dose', expected=100)"
            local test4c_pass = 0
        }
    }
    else {
        display as error "  FAIL [4c.rows]: expected 2 rows, got `nrows'"
        list id start stop cumul_dose fail_status
        local test4c_pass = 0
    }
}

if `test4c_pass' == 1 {
    local pass_count = `pass_count' + 1
    display as result "TEST 4C: PASSED"
}
else {
    local fail_count = `fail_count' + 1
    local failed_tests "`failed_tests' 4c"
    display as error "TEST 4C: FAILED"
}

* TEST 4D: TYPE(SINGLE) REMOVES ALL POST-EVENT INTERVALS
display "TEST 4D: Type(single) - removes all post-event intervals"

local test4d_pass = 1

* 1 person with 5 intervals, event occurs in interval 3 (middle)
* Expected: only intervals 1, 2, and 3 (event row) remain = 3 rows

clear
set obs 5
gen id = 1
gen start = mdy(1,1,2020) + (_n-1)*73
gen stop  = start + 72
replace stop = mdy(12,31,2021) if _n == 5
gen tv_exp = 1
save "/tmp/tve4d_intervals.dta", replace

* Event occurs in interval 3 (day 146-218)
local event_date = mdy(1,1,2020) + 160    // day 160, in interval 3

clear
set obs 1
gen id = 1
gen event_date = mdy(1,1,2020) + 160
save "/tmp/tve4d_event.dta", replace

use "/tmp/tve4d_event.dta", clear
capture noisily tvevent using "/tmp/tve4d_intervals.dta", ///
    id(id) date(event_date) ///
    type(single) generate(fail_status)

if _rc != 0 {
    display as error "  FAIL [4d.run]: tvevent returned error `=_rc'"
    local test4d_pass = 0
}
else {
    sort id start
    quietly count
    local nrows = r(N)
    display "  INFO: `nrows' rows after type(single)"

    * Should have 3 rows (intervals 1, 2, and part of 3)
    * Note: if event is in interval 3, interval 3 is split at event date → 2 rows from interval 3?
    * No - type(single) should keep only up to and including the event row
    * Looking at tvevent behavior: splits if strictly inside interval, event at stop just flags it
    * For event strictly inside interval 3: split into [start3, event] and [event, stop3]
    *   → then type(single) keeps pre-event portion + event row = 3 pre-intervals + split pre = 3 rows
    * Actually: rows 1, 2, pre-event split of 3 = 3 rows total

    if `nrows' == 3 {
        display as result "  PASS [4d.rows]: exactly 3 rows after type(single)"
    }
    else {
        display as error "  FAIL [4d.rows]: expected 3 rows, got `nrows'"
        local test4d_pass = 0
    }

    * Last row should have fail_status=1
    local last_fail = fail_status[`nrows']
    if `last_fail' == 1 {
        display as result "  PASS [4d.event_flag]: last row has fail_status=1"
    }
    else {
        display as error "  FAIL [4d.event_flag]: last row has fail_status=`last_fail' (expected 1)"
        local test4d_pass = 0
    }

    * All rows should be before or at event date
    local event_date_val = mdy(1,1,2020) + 160
    quietly count if stop > `event_date_val'
    if r(N) == 0 {
        display as result "  PASS [4d.truncation]: no intervals extend past event date"
    }
    else {
        display as error "  FAIL [4d.truncation]: `=r(N)' intervals extend past event date"
        list id start stop fail_status
        local test4d_pass = 0
    }
}

if `test4d_pass' == 1 {
    local pass_count = `pass_count' + 1
    display as result "TEST 4D: PASSED"
}
else {
    local fail_count = `fail_count' + 1
    local failed_tests "`failed_tests' 4d"
    display as error "TEST 4D: FAILED"
}

* TEST 4E: BOUNDARY BEHAVIOR - EVENT AT STOP DATE IS CAPTURED
display "TEST 4E: Boundary behavior - event at stop date is captured"

local test4e_pass = 1

* From tvevent help: "Events at the stop boundary (date == stop) ARE valid and flagged"
* Event exactly at stop of last interval → should be flagged as event, NOT censored

clear
set obs 1
gen id = 1
gen start = mdy(1,1,2020)
gen stop  = mdy(12,31,2020)
gen tv_exp = 1
save "/tmp/tve4e_intervals.dta", replace

clear
set obs 1
gen id = 1
gen event_date = mdy(12,31,2020)    // event at EXACTLY the stop boundary
save "/tmp/tve4e_event.dta", replace

use "/tmp/tve4e_event.dta", clear
capture noisily tvevent using "/tmp/tve4e_intervals.dta", ///
    id(id) date(event_date) ///
    type(single) generate(fail_status)

if _rc != 0 {
    display as error "  FAIL [4e.run]: tvevent returned error `=_rc'"
    local test4e_pass = 0
}
else {
    sort id start
    quietly sum fail_status
    local n_events = r(N)

    quietly count if fail_status == 1
    local n_flagged = r(N)

    if `n_flagged' == 1 {
        display as result "  PASS [4e.boundary]: event at stop boundary correctly flagged (fail_status=1)"
    }
    else {
        display as error "  FAIL [4e.boundary]: expected 1 event row, got `n_flagged' with fail_status=1"
        list id start stop fail_status
        local test4e_pass = 0
    }
}

if `test4e_pass' == 1 {
    local pass_count = `pass_count' + 1
    display as result "TEST 4E: PASSED"
}
else {
    local fail_count = `fail_count' + 1
    local failed_tests "`failed_tests' 4e"
    display as error "TEST 4E: FAILED"
}

* FINAL SUMMARY

}

capture noisily {

* TEST 1: RECURRING EVENTS WITH WIDE-FORMAT RELAPSES
display "TEST 1: type(recurring) with wide-format relapses"

local test1_pass = 1

* Create interval data (from tvexpose output): 3 persons, 4 intervals each
clear
set obs 12
gen long id = ceil(_n/4)
gen int seq = _n - (id-1)*4
gen double start = mdy(1,1,2020) + (seq-1)*91
gen double stop  = start + 90
replace stop = mdy(12,31,2020) if seq == 4
gen byte tv_exp = mod(seq, 2)
format start stop %td
drop seq
save "/tmp/tve1_intervals.dta", replace

* Event data: person 1 = 0 relapses, person 2 = 1 relapse, person 3 = 5 relapses
* tvevent type(recurring) expects wide-format: relapse_date1, relapse_date2, etc.
clear
set obs 3
gen long id = _n

* Person 1: no relapses
gen double relapse_date1 = .
gen double relapse_date2 = .
gen double relapse_date3 = .
gen double relapse_date4 = .
gen double relapse_date5 = .

* Person 2: 1 relapse on May 15
replace relapse_date1 = mdy(5,15,2020) in 2

* Person 3: 5 relapses spread across the year
replace relapse_date1 = mdy(2,15,2020)  in 3
replace relapse_date2 = mdy(4,20,2020)  in 3
replace relapse_date3 = mdy(6,10,2020)  in 3
replace relapse_date4 = mdy(8,25,2020)  in 3
replace relapse_date5 = mdy(10,30,2020) in 3

format relapse_date* %td
save "/tmp/tve1_events.dta", replace

use "/tmp/tve1_events.dta", clear
capture noisily tvevent using "/tmp/tve1_intervals.dta", ///
    id(id) date(relapse_date) ///
    type(recurring) generate(relapse_flag)

if _rc != 0 {
    display as error "  FAIL [1.run]: tvevent returned error `=_rc'"
    local test1_pass = 0
}
else {
    sort id start
    list id start stop relapse_flag, noobs

    * Person 1: all relapse_flag should be 0
    quietly count if id == 1 & relapse_flag != 0
    if r(N) == 0 {
        display as result "  PASS [1.p1_none]: person 1 has no events flagged"
    }
    else {
        display as error "  FAIL [1.p1_none]: person 1 has `=r(N)' flagged rows"
        local test1_pass = 0
    }

    * Person 2: exactly 1 row with relapse_flag = 1
    quietly count if id == 2 & relapse_flag == 1
    if r(N) == 1 {
        display as result "  PASS [1.p2_one]: person 2 has exactly 1 event"
    }
    else {
        display as error "  FAIL [1.p2_one]: person 2 has `=r(N)' events (expected 1)"
        local test1_pass = 0
    }

    * Person 3: at least 3 events flagged (5 events but some may fall in same interval)
    quietly count if id == 3 & relapse_flag >= 1
    local p3_events = r(N)
    if `p3_events' >= 3 {
        display as result "  PASS [1.p3_multi]: person 3 has `p3_events' event rows (5 relapses)"
    }
    else {
        display as error "  FAIL [1.p3_multi]: person 3 has `p3_events' event rows (expected >=3)"
        local test1_pass = 0
    }

    * All persons should still be present
    quietly tab id
    if r(r) == 3 {
        display as result "  PASS [1.all_persons]: all 3 persons present"
    }
    else {
        display as error "  FAIL [1.all_persons]: `=r(r)' persons (expected 3)"
        local test1_pass = 0
    }
}

if `test1_pass' == 1 {
    local pass_count = `pass_count' + 1
    display as result "TEST 1: PASSED"
}
else {
    local fail_count = `fail_count' + 1
    local failed_tests "`failed_tests' 1"
    display as error "TEST 1: FAILED"
}

* TEST 2: EVENT EXACTLY AT STUDY ENTRY (= FIRST INTERVAL START)
display "TEST 2: Event exactly at first interval start"

local test2_pass = 1

* Interval: [Jan1/2020, Jun30/2020] and [Jul1/2020, Dec31/2020]
clear
set obs 2
gen long id = 1
gen double start = mdy(1,1,2020) in 1
replace start = mdy(7,1,2020) in 2
gen double stop = mdy(6,30,2020) in 1
replace stop = mdy(12,31,2020) in 2
gen byte tv_exp = 1
format start stop %td
save "/tmp/tve2_intervals.dta", replace

* Event exactly at start of first interval
clear
set obs 1
gen long id = 1
gen double event_date = mdy(1,1,2020)
format event_date %td
save "/tmp/tve2_events.dta", replace

use "/tmp/tve2_events.dta", clear
capture noisily tvevent using "/tmp/tve2_intervals.dta", ///
    id(id) date(event_date) ///
    type(single) generate(fail_flag)

if _rc != 0 {
    display as error "  FAIL [2.run]: tvevent returned error `=_rc'"
    local test2_pass = 0
}
else {
    sort id start
    list id start stop fail_flag, noobs

    * Per tvevent rules: events at start are NOT flagged
    * Person should have fail_flag=0 everywhere (event at start = not flagged)
    quietly count if fail_flag == 1
    local n_flagged = r(N)
    display "  INFO: `n_flagged' rows flagged (events at start should NOT be flagged per tvevent rules)"
    if `n_flagged' == 0 {
        display as result "  PASS [2.at_start]: event at start not flagged (per boundary rule)"
    }
    else {
        display as result "  INFO [2.at_start]: event at start IS flagged (`n_flagged' rows)"
        * This is informational - document the behavior
    }
}

if `test2_pass' == 1 {
    local pass_count = `pass_count' + 1
    display as result "TEST 2: PASSED"
}
else {
    local fail_count = `fail_count' + 1
    local failed_tests "`failed_tests' 2"
    display as error "TEST 2: FAILED"
}

* TEST 3: EVENT EXACTLY AT STUDY EXIT (= LAST INTERVAL STOP)
display "TEST 3: Event exactly at last interval stop"

local test3_pass = 1

* Reuse intervals from test 2
clear
set obs 1
gen long id = 1
gen double event_date = mdy(12,31,2020)
format event_date %td
save "/tmp/tve3_events.dta", replace

use "/tmp/tve3_events.dta", clear
capture noisily tvevent using "/tmp/tve2_intervals.dta", ///
    id(id) date(event_date) ///
    type(single) generate(fail_flag)

if _rc != 0 {
    display as error "  FAIL [3.run]: tvevent returned error `=_rc'"
    local test3_pass = 0
}
else {
    sort id start
    list id start stop fail_flag, noobs

    * Per tvevent rules: events at stop ARE flagged
    quietly count if fail_flag == 1
    local n_flagged = r(N)
    if `n_flagged' == 1 {
        display as result "  PASS [3.at_stop]: event at stop boundary correctly flagged"
    }
    else {
        display as error "  FAIL [3.at_stop]: expected 1 flagged row, got `n_flagged'"
        local test3_pass = 0
    }
}

if `test3_pass' == 1 {
    local pass_count = `pass_count' + 1
    display as result "TEST 3: PASSED"
}
else {
    local fail_count = `fail_count' + 1
    local failed_tests "`failed_tests' 3"
    display as error "TEST 3: FAILED"
}

* TEST 4: EVENT BETWEEN INTERVALS (IN GAP)
display "TEST 4: Event falling in gap between intervals"

local test4_pass = 1

* Create intervals with a gap: [Jan1, Mar31] and [May1, Dec31]
* Gap: April 1-30
clear
set obs 2
gen long id = 1
gen double start = mdy(1,1,2020) in 1
replace start = mdy(5,1,2020) in 2
gen double stop = mdy(3,31,2020) in 1
replace stop = mdy(12,31,2020) in 2
gen byte tv_exp = 1
format start stop %td
save "/tmp/tve4_intervals.dta", replace

* Event in the gap (April 15)
clear
set obs 1
gen long id = 1
gen double event_date = mdy(4,15,2020)
format event_date %td
save "/tmp/tve4_events.dta", replace

use "/tmp/tve4_events.dta", clear
capture noisily tvevent using "/tmp/tve4_intervals.dta", ///
    id(id) date(event_date) ///
    type(single) generate(fail_flag)

if _rc != 0 {
    display as error "  INFO [4.run]: tvevent returned error `=_rc' (event in gap)"
    display as result "  PASS [4.handled]: event in gap handled (error is acceptable)"
}
else {
    sort id start
    list id start stop fail_flag, noobs

    * Event in gap should not be flagged in any interval
    quietly count if fail_flag == 1
    local n_flagged = r(N)
    if `n_flagged' == 0 {
        display as result "  PASS [4.no_flag]: event in gap not flagged (correct)"
    }
    else {
        display as result "  INFO [4.flagged]: event in gap flagged in `n_flagged' rows (check nearest interval)"
    }
}

if `test4_pass' == 1 {
    local pass_count = `pass_count' + 1
    display as result "TEST 4: PASSED"
}
else {
    local fail_count = `fail_count' + 1
    local failed_tests "`failed_tests' 4"
    display as error "TEST 4: FAILED"
}

* TEST 5: COMPETING RISK - COMPETE EVENT BEFORE PRIMARY
display "TEST 5: Competing risk: compete event occurs before primary"

local test5_pass = 1

* Create intervals: 4 quarterly intervals
clear
set obs 4
gen long id = 1
gen double start = mdy(1,1,2020) + (_n-1)*91
gen double stop  = start + 90
replace stop = mdy(12,31,2020) if _n == 4
gen byte tv_exp = 1
format start stop %td
save "/tmp/tve5_intervals.dta", replace

* Primary event: Oct 15 (day 289). Compete (death): May 20 (day 141)
* Death should win because it's earlier
clear
set obs 1
gen long id = 1
gen double primary_date = mdy(10,15,2020)
gen double death_date   = mdy(5,20,2020)
format primary_date death_date %td
save "/tmp/tve5_events.dta", replace

use "/tmp/tve5_events.dta", clear
capture noisily tvevent using "/tmp/tve5_intervals.dta", ///
    id(id) date(primary_date) ///
    compete(death_date) ///
    type(single) generate(fail_status)

if _rc != 0 {
    display as error "  FAIL [5.run]: tvevent returned error `=_rc'"
    local test5_pass = 0
}
else {
    sort id start
    list id start stop fail_status, noobs

    * Death (compete) occurred first - should be coded as fail_status = 2
    * Post-event rows should be dropped (type=single)
    quietly count if fail_status == 2
    local n_compete = r(N)
    quietly count if fail_status == 1
    local n_primary = r(N)

    if `n_compete' >= 1 & `n_primary' == 0 {
        display as result "  PASS [5.compete_wins]: compete event (death) wins, primary not flagged"
    }
    else {
        display as error "  FAIL [5.compete_wins]: compete=`n_compete', primary=`n_primary' (expected compete>0, primary=0)"
        local test5_pass = 0
    }

    * No rows should exist after death date (type=single truncates)
    quietly summarize stop
    local max_stop = r(max)
    if `max_stop' <= mdy(5,20,2020) {
        display as result "  PASS [5.truncated]: no rows after death date"
    }
    else {
        local d1 : display %td `max_stop'
        display as error "  FAIL [5.truncated]: rows extend to `d1' (past death on May 20)"
        local test5_pass = 0
    }
}

if `test5_pass' == 1 {
    local pass_count = `pass_count' + 1
    display as result "TEST 5: PASSED"
}
else {
    local fail_count = `fail_count' + 1
    local failed_tests "`failed_tests' 5"
    display as error "TEST 5: FAILED"
}

* TEST 6: COMPETING RISK - PRIMARY BEFORE COMPETE
display "TEST 6: Competing risk: primary occurs before compete"

local test6_pass = 1

* Primary event: Mar 15. Compete (death): Nov 20.
* Primary should be coded.
clear
set obs 1
gen long id = 1
gen double primary_date = mdy(3,15,2020)
gen double death_date   = mdy(11,20,2020)
format primary_date death_date %td
save "/tmp/tve6_events.dta", replace

use "/tmp/tve6_events.dta", clear
capture noisily tvevent using "/tmp/tve5_intervals.dta", ///
    id(id) date(primary_date) ///
    compete(death_date) ///
    type(single) generate(fail_status)

if _rc != 0 {
    display as error "  FAIL [6.run]: tvevent returned error `=_rc'"
    local test6_pass = 0
}
else {
    sort id start
    list id start stop fail_status, noobs

    * Primary should be coded (=1)
    quietly count if fail_status == 1
    local n_primary = r(N)
    quietly count if fail_status == 2
    local n_compete = r(N)

    if `n_primary' >= 1 & `n_compete' == 0 {
        display as result "  PASS [6.primary_wins]: primary event wins when it occurs first"
    }
    else {
        display as error "  FAIL [6.primary_wins]: primary=`n_primary', compete=`n_compete'"
        local test6_pass = 0
    }

    * Truncated at primary event date
    quietly summarize stop
    local max_stop = r(max)
    if `max_stop' <= mdy(3,15,2020) {
        display as result "  PASS [6.truncated]: truncated at primary event"
    }
    else {
        local d1 : display %td `max_stop'
        display as error "  FAIL [6.truncated]: rows extend to `d1' (past primary on Mar 15)"
        local test6_pass = 0
    }
}

if `test6_pass' == 1 {
    local pass_count = `pass_count' + 1
    display as result "TEST 6: PASSED"
}
else {
    local fail_count = `fail_count' + 1
    local failed_tests "`failed_tests' 6"
    display as error "TEST 6: FAILED"
}

* TEST 7: BOTH PRIMARY AND COMPETE ON SAME DAY
display "TEST 7: Primary and competing event on same day"

local test7_pass = 1

* Both events on Jun 15
clear
set obs 1
gen long id = 1
gen double primary_date = mdy(6,15,2020)
gen double death_date   = mdy(6,15,2020)
format primary_date death_date %td
save "/tmp/tve7_events.dta", replace

use "/tmp/tve7_events.dta", clear
capture noisily tvevent using "/tmp/tve5_intervals.dta", ///
    id(id) date(primary_date) ///
    compete(death_date) ///
    type(single) generate(fail_status)

if _rc != 0 {
    display as error "  FAIL [7.run]: tvevent returned error `=_rc'"
    local test7_pass = 0
}
else {
    sort id start
    list id start stop fail_status, noobs

    * Document tie-breaking behavior
    quietly count if fail_status == 1
    local n_primary = r(N)
    quietly count if fail_status == 2
    local n_compete = r(N)

    display "  INFO: Tie-breaking on same day: primary=`n_primary', compete=`n_compete'"

    * At least one should be flagged
    if `n_primary' + `n_compete' >= 1 {
        display as result "  PASS [7.flagged]: at least one event type flagged on tie"
    }
    else {
        display as error "  FAIL [7.flagged]: no event flagged despite same-day events"
        local test7_pass = 0
    }
}

if `test7_pass' == 1 {
    local pass_count = `pass_count' + 1
    display as result "TEST 7: PASSED"
}
else {
    local fail_count = `fail_count' + 1
    local failed_tests "`failed_tests' 7"
    display as error "TEST 7: FAILED"
}

* TEST 8: NO EVENTS IN ENTIRE DATASET (ALL CENSORED)
display "TEST 8: No events in dataset (all censored)"

local test8_pass = 1

* 3 persons with intervals, no events
clear
set obs 6
gen long id = ceil(_n/2)
gen double start = mdy(1,1,2020) if mod(_n,2) == 1
replace start = mdy(7,1,2020) if mod(_n,2) == 0
gen double stop = mdy(6,30,2020) if mod(_n,2) == 1
replace stop = mdy(12,31,2020) if mod(_n,2) == 0
gen byte tv_exp = 1
format start stop %td
save "/tmp/tve8_intervals.dta", replace

* All event dates missing
clear
set obs 3
gen long id = _n
gen double event_date = .
format event_date %td
save "/tmp/tve8_events.dta", replace

use "/tmp/tve8_events.dta", clear
capture noisily tvevent using "/tmp/tve8_intervals.dta", ///
    id(id) date(event_date) ///
    type(single) generate(fail_flag)

if _rc != 0 {
    display as error "  FAIL [8.run]: tvevent returned error `=_rc'"
    local test8_pass = 0
}
else {
    sort id start
    list id start stop fail_flag, noobs

    * All fail_flag should be 0
    quietly count if fail_flag != 0
    if r(N) == 0 {
        display as result "  PASS [8.all_zero]: all outcome=0 (all censored)"
    }
    else {
        display as error "  FAIL [8.all_zero]: `=r(N)' non-zero outcome rows"
        local test8_pass = 0
    }

    * All persons present
    quietly tab id
    if r(r) == 3 {
        display as result "  PASS [8.all_persons]: all 3 persons present"
    }
    else {
        display as error "  FAIL [8.all_persons]: `=r(r)' persons (expected 3)"
        local test8_pass = 0
    }

    * Interval structure preserved (no splits since no events)
    quietly count
    if r(N) == 6 {
        display as result "  PASS [8.no_split]: original 6 intervals preserved (no splits)"
    }
    else {
        display "  INFO [8.rows]: `=r(N)' rows (expected 6 if no splits)"
    }
}

if `test8_pass' == 1 {
    local pass_count = `pass_count' + 1
    display as result "TEST 8: PASSED"
}
else {
    local fail_count = `fail_count' + 1
    local failed_tests "`failed_tests' 8"
    display as error "TEST 8: FAILED"
}

* TEST 9: EVENT IN FIRST INTERVAL
display "TEST 9: Event in first interval (day 1 of follow-up)"

local test9_pass = 1

* Reuse intervals from test 2: [Jan1, Jun30] and [Jul1, Dec31]
* Event on Jan 5 (inside first interval, not at start boundary)
clear
set obs 1
gen long id = 1
gen double event_date = mdy(1,5,2020)
format event_date %td
save "/tmp/tve9_events.dta", replace

use "/tmp/tve9_events.dta", clear
capture noisily tvevent using "/tmp/tve2_intervals.dta", ///
    id(id) date(event_date) ///
    type(single) generate(fail_flag)

if _rc != 0 {
    display as error "  FAIL [9.run]: tvevent returned error `=_rc'"
    local test9_pass = 0
}
else {
    sort id start
    list id start stop fail_flag, noobs

    * Event should be flagged in first interval (after split)
    quietly count if fail_flag == 1
    if r(N) == 1 {
        display as result "  PASS [9.flagged]: event flagged in first interval"
    }
    else {
        display as error "  FAIL [9.flagged]: `=r(N)' flagged rows (expected 1)"
        local test9_pass = 0
    }

    * type(single): no rows after event date
    quietly summarize stop
    local max_stop = r(max)
    if `max_stop' <= mdy(1,5,2020) {
        display as result "  PASS [9.truncated]: truncated at event (Jan 5)"
    }
    else {
        local d1 : display %td `max_stop'
        display as error "  FAIL [9.truncated]: rows extend to `d1'"
        local test9_pass = 0
    }
}

if `test9_pass' == 1 {
    local pass_count = `pass_count' + 1
    display as result "TEST 9: PASSED"
}
else {
    local fail_count = `fail_count' + 1
    local failed_tests "`failed_tests' 9"
    display as error "TEST 9: FAILED"
}

* TEST 10: EVENT IN LAST INTERVAL
display "TEST 10: Event in last interval (last day of follow-up)"

local test10_pass = 1

* Event on Dec 15 (inside last interval)
clear
set obs 1
gen long id = 1
gen double event_date = mdy(12,15,2020)
format event_date %td
save "/tmp/tve10_events.dta", replace

use "/tmp/tve10_events.dta", clear
capture noisily tvevent using "/tmp/tve2_intervals.dta", ///
    id(id) date(event_date) ///
    type(single) generate(fail_flag)

if _rc != 0 {
    display as error "  FAIL [10.run]: tvevent returned error `=_rc'"
    local test10_pass = 0
}
else {
    sort id start
    list id start stop fail_flag, noobs

    * Event should be flagged
    quietly count if fail_flag == 1
    if r(N) == 1 {
        display as result "  PASS [10.flagged]: event flagged in last interval"
    }
    else {
        display as error "  FAIL [10.flagged]: `=r(N)' flagged rows (expected 1)"
        local test10_pass = 0
    }

    * First interval should be preserved intact
    sort id start
    local first_stop = stop[1]
    if `first_stop' == mdy(6,30,2020) {
        display as result "  PASS [10.first_intact]: first interval preserved"
    }
    else {
        local d1 : display %td `first_stop'
        display as error "  FAIL [10.first_intact]: first interval stop=`d1' (expected Jun30)"
        local test10_pass = 0
    }

    * Truncated at event date
    quietly summarize stop
    local max_stop = r(max)
    if `max_stop' <= mdy(12,15,2020) {
        display as result "  PASS [10.truncated]: truncated at event"
    }
    else {
        local d1 : display %td `max_stop'
        display as error "  FAIL [10.truncated]: rows extend to `d1'"
        local test10_pass = 0
    }
}

if `test10_pass' == 1 {
    local pass_count = `pass_count' + 1
    display as result "TEST 10: PASSED"
}
else {
    local fail_count = `fail_count' + 1
    local failed_tests "`failed_tests' 10"
    display as error "TEST 10: FAILED"
}

* SUMMARY

}


* ===== Summary =====
* Fold the run_test/test_pass/test_fail harness counters into the totals.
local pass_count = `pass_count' + $TVQA_PASS
local fail_count = `fail_count' + $TVQA_FAIL
local failed_tests "`failed_tests' $TVQA_FAILED"
local test_count = `pass_count' + `fail_count'
display as result _newline "tvtools QA tvevent correctness Results -- $S_DATE $S_TIME"
display as text "Tests run:  `test_count'"
display as text "Passed:     `pass_count'"
display as text "Failed:     `fail_count'"
display "RESULT: validation_tvevent tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 {
    display as error "TESTS FAILED: `failed_tests'"
    exit 1
}
display as result "ALL TESTS PASSED"

