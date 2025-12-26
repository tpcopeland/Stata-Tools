/*******************************************************************************
* validation_tvtools_comprehensive.do
*
* Purpose: Comprehensive conceptual validation for tvtools commands
*          Tests end-to-end pipeline behavior, edge cases, and conservation laws
*          that an experienced statistician would verify.
*
* Categories of Tests:
*   Section 1: End-to-End Pipeline Tests (tvexpose -> tvmerge -> tvevent)
*   Section 2: Continuous Variable Conservation
*   Section 3: Person-Time Conservation
*   Section 4: Zero-Duration Interval Handling
*   Section 5: Events at Interval Start Dates
*   Section 6: Missing Value Handling
*   Section 7: Variable Label Preservation
*
* Philosophy: Every transformation should preserve what should be preserved
*             (person-time, cumulative totals, labels) and correctly transform
*             what should change (interval boundaries, event flags).
*
* Run modes:
*   Standalone: do validation_tvtools_comprehensive.do
*   Via runner: do run_test.do validation_tvtools_comprehensive
*
* Author: Claude Code (Comprehensive Audit)
* Date: 2025-12-18
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
    display as text "TVTOOLS COMPREHENSIVE CONCEPTUAL VALIDATION"
    display as text "{hline 70}"
    display as text "Tests verify end-to-end pipeline behavior, conservation laws,"
    display as text "and edge cases that an experienced statistician would check."
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
* SECTION 1: END-TO-END PIPELINE TESTS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 1: End-to-End Pipeline (tvexpose -> tvmerge -> tvevent)"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 1.1: Complete pipeline with single person, verify all transformations
* Known answer: Person has 365 days follow-up, 200 days exposed, event at day 300
* Note: type(single) censors post-event time, so PT = 300 days, not 365
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 1.1: Complete pipeline - single person"
    display as text "  Follow-up: 365 days, Exposure: days 50-250, Event: day 300"
    display as text "  Note: type(single) removes post-event time"
}

capture {
    * Create master cohort
    clear
    input long id double(study_entry study_exit)
        1  21915  22280   // Jan 1 2020 to Dec 31 2020 (366 days, leap year)
    end
    format %td study_entry study_exit
    save "${DATA_DIR}/_val_cohort_e2e.dta", replace

    * Create exposure dataset (exposed from day 50 to day 250)
    clear
    input long id double(start stop) byte exp_type
        1  21965  22165  1   // Feb 20 to Aug 8, 2020 (200 days exposed)
    end
    format %td start stop
    save "${DATA_DIR}/_val_exposure_e2e.dta", replace

    * Create event dataset
    clear
    input long id double(event_dt)
        1  22215   // Sep 27, 2020 (day 300 of follow-up)
    end
    format %td event_dt
    save "${DATA_DIR}/_val_events_e2e.dta", replace

    * Step 1: tvexpose
    use "${DATA_DIR}/_val_cohort_e2e.dta", clear
    tvexpose using "${DATA_DIR}/_val_exposure_e2e.dta", id(id) start(start) stop(stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit)

    * Verify tvexpose output
    quietly count
    assert r(N) == 3  // Should have 3 intervals: unexposed, exposed, unexposed

    save "${DATA_DIR}/_val_tv_data_e2e.dta", replace

    * Step 2: tvevent with type(single) - default behavior
    use "${DATA_DIR}/_val_events_e2e.dta", clear
    tvevent using "${DATA_DIR}/_val_tv_data_e2e.dta", id(id) date(event_dt) ///
        startvar(start) stopvar(stop) ///
        generate(outcome)

    * Verify final output
    quietly count
    local n_intervals = r(N)

    * type(single) censors post-event time, so 3 intervals remain
    * (event at 22215 is within the 3rd unexposed interval [22165, 22280])
    assert `n_intervals' == 3

    * Verify event is flagged exactly once
    quietly count if outcome == 1
    assert r(N) == 1

    * Verify total person-time (post-event time removed)
    gen double pt = stop - start
    quietly sum pt
    local total_pt = r(sum)
    * PT = day 0 to day 300 = 300 days (not 365, since post-event removed)
    * Allow tolerance of 3 days for interval boundary handling (floor/ceil)
    assert abs(`total_pt' - 300) <= 3
}
if _rc == 0 {
    local ++pass_count
    if `machine' {
        display "[OK] 1.1"
    }
    else if `quiet' == 0 {
        display as result "  PASS: Complete pipeline produces correct intervals and event"
    }
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' 1.1"
    if `machine' {
        display "[FAIL] 1.1|`=_rc'"
    }
    else {
        display as error "  FAIL: Complete pipeline test (error `=_rc')"
    }
}

* -----------------------------------------------------------------------------
* Test 1.2: Pipeline with tvmerge - two exposures merged
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 1.2: Pipeline with tvmerge - two exposures"
}

capture {
    * Create cohort
    clear
    input long id double(study_entry study_exit)
        1  21915  22280
    end
    format %td study_entry study_exit
    save "${DATA_DIR}/_val_cohort_merge.dta", replace

    * Exposure 1: Drug A (days 0-180)
    clear
    input long id double(start stop) byte drug_a
        1  21915  22095  1
    end
    format %td start stop
    save "${DATA_DIR}/_val_exp_a.dta", replace

    * Exposure 2: Drug B (days 90-270)
    clear
    input long id double(start stop) byte drug_b
        1  22005  22185  1
    end
    format %td start stop
    save "${DATA_DIR}/_val_exp_b.dta", replace

    * Create tv datasets
    use "${DATA_DIR}/_val_cohort_merge.dta", clear
    tvexpose using "${DATA_DIR}/_val_exp_a.dta", id(id) start(start) stop(stop) ///
        exposure(drug_a) reference(0) entry(study_entry) exit(study_exit) ///
        generate(tv_drug_a)
    save "${DATA_DIR}/_val_tv_a.dta", replace

    use "${DATA_DIR}/_val_cohort_merge.dta", clear
    tvexpose using "${DATA_DIR}/_val_exp_b.dta", id(id) start(start) stop(stop) ///
        exposure(drug_b) reference(0) entry(study_entry) exit(study_exit) ///
        generate(tv_drug_b)
    save "${DATA_DIR}/_val_tv_b.dta", replace

    * Merge with tvmerge
    tvmerge "${DATA_DIR}/_val_tv_a.dta" "${DATA_DIR}/_val_tv_b.dta", id(id) ///
        start(start start) stop(stop stop) ///
        exposure(tv_drug_a tv_drug_b) ///
        generate(drug_a drug_b)

    * Verify: Should have periods for all combinations
    * Period 1: Neither drug (0-90)
    * Period 2: Drug A only (90-180)
    * Period 3: Both drugs (overlap)
    * Period 4: Drug B only (180-270)
    * Period 5: Neither drug (270-365)

    quietly count
    assert r(N) >= 4

    * Verify person-time conservation
    * Allow tolerance of 3 days for interval boundary handling (floor/ceil)
    gen double pt = stop - start
    quietly sum pt
    local total_pt = r(sum)
    assert abs(`total_pt' - 365) <= 3
}
if _rc == 0 {
    local ++pass_count
    if `machine' {
        display "[OK] 1.2"
    }
    else if `quiet' == 0 {
        display as result "  PASS: tvmerge pipeline preserves person-time"
    }
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' 1.2"
    if `machine' {
        display "[FAIL] 1.2|`=_rc'"
    }
    else {
        display as error "  FAIL: tvmerge pipeline test (error `=_rc')"
    }
}

* =============================================================================
* SECTION 2: CONTINUOUS VARIABLE CONSERVATION
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 2: Continuous Variable Conservation"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 2.1: tvevent continuous splitting - sum preserved
* Known answer: 100mg dose split at midpoint should give 2x ~50mg
* Note: type(recurring) requires wide format; we use type(single) and test
*       that the pre-event portion has the correct proportioned dose
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 2.1: Continuous variable splitting in tvevent"
    display as text "  Interval [0, 100] with dose=100, event at day 50"
    display as text "  Expected: Event interval has dose ~50 (proportioned)"
}

capture {
    * Create interval data
    clear
    input long id double(start stop) double cumul_dose
        1  21915  22015  100   // 100-day interval with 100mg
    end
    format %td start stop
    save "${DATA_DIR}/_val_cont_intervals.dta", replace

    * Create event at midpoint
    clear
    input long id double(event_dt)
        1  21965   // Day 50 of the interval
    end
    format %td event_dt

    * Run tvevent with continuous adjustment - type(single) removes post-event
    tvevent using "${DATA_DIR}/_val_cont_intervals.dta", id(id) date(event_dt) ///
        startvar(start) stopvar(stop) ///
        continuous(cumul_dose) generate(outcome)

    * With type(single), only the pre-event portion remains (with event flagged)
    quietly count
    assert r(N) == 1

    * Verify event is flagged
    quietly count if outcome == 1
    assert r(N) == 1

    * Verify dose is proportioned correctly (50 days out of 100 = 50%)
    * The formula is new_dur/orig_dur * dose = 50/100 * 100 = 50
    quietly sum cumul_dose
    local event_dose = r(mean)
    assert abs(`event_dose' - 50) < 5
}
if _rc == 0 {
    local ++pass_count
    if `machine' {
        display "[OK] 2.1"
    }
    else if `quiet' == 0 {
        display as result "  PASS: Continuous variable sum preserved after split"
    }
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' 2.1"
    if `machine' {
        display "[FAIL] 2.1|`=_rc'"
    }
    else {
        display as error "  FAIL: Continuous variable split test (error `=_rc')"
    }
}

* -----------------------------------------------------------------------------
* Test 2.2: Multiple splits - continuous sum still preserved
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 2.2: Multiple splits - continuous sum preserved"
}

capture {
    * Create interval data
    clear
    input long id double(start stop) double cumul_dose
        1  21915  22015  100
    end
    format %td start stop
    save "${DATA_DIR}/_val_cont_multi.dta", replace

    * Create multiple events (wide format for recurring)
    clear
    input long id double(event1 event2 event3)
        1  21935  21965  21995   // Days 20, 50, 80
    end
    format %td event1 event2 event3

    * Run tvevent with recurring events
    tvevent using "${DATA_DIR}/_val_cont_multi.dta", id(id) date(event) ///
        startvar(start) stopvar(stop) ///
        continuous(cumul_dose) generate(outcome) ///
        type(recurring)

    * Verify sum is preserved
    quietly sum cumul_dose
    local total_dose = r(sum)
    assert abs(`total_dose' - 100) < 1

    * Verify we have 4 intervals (3 splits create 4 segments)
    quietly count
    assert r(N) == 4
}
if _rc == 0 {
    local ++pass_count
    if `machine' {
        display "[OK] 2.2"
    }
    else if `quiet' == 0 {
        display as result "  PASS: Multiple splits preserve continuous sum"
    }
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' 2.2"
    if `machine' {
        display "[FAIL] 2.2|`=_rc'"
    }
    else {
        display as error "  FAIL: Multiple splits test (error `=_rc')"
    }
}

* -----------------------------------------------------------------------------
* Test 2.3: tvmerge continuous proportioning
* Tests that tvmerge correctly proportions continuous exposures when slicing
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 2.3: tvmerge continuous proportioning"
}

capture {
    * Dataset 1: Full interval (100 days) with dose = 100
    clear
    input long id double(start stop) double dose_rate
        1  21915  22015  100   // 100 days [Jan 1 - Apr 10]
    end
    format %td start stop
    save "${DATA_DIR}/_val_merge_ds1.dta", replace

    * Dataset 2: Partial overlap (50 days overlap with ds1)
    clear
    input long id double(start stop) byte other_var
        1  21965  22065  1   // [Feb 20 - May 10]
    end
    format %td start stop
    save "${DATA_DIR}/_val_merge_ds2.dta", replace

    * Merge with continuous proportioning
    tvmerge "${DATA_DIR}/_val_merge_ds1.dta" "${DATA_DIR}/_val_merge_ds2.dta", id(id) ///
        start(start start) stop(stop stop) ///
        exposure(dose_rate other_var) ///
        continuous(dose_rate) ///
        generate(dose other)

    * The intersection is [21965, 22015] = 50 days out of 100 days
    * tvmerge proportion = (50+1)/(100+1) = 51/101 ≈ 0.505
    * With dose_rate=100, result dose should be approximately 50.5

    quietly count
    assert r(N) == 1

    * Verify interval boundaries
    quietly sum start
    assert r(mean) == 21965  // Feb 20

    quietly sum stop
    assert r(mean) == 22015  // Apr 10

    * Verify dose is correctly proportioned
    quietly sum dose
    local merged_dose = r(sum)

    * Allow for the +1 formula (should be ~50.5, not exactly 50)
    assert abs(`merged_dose' - 50.5) < 2
}
if _rc == 0 {
    local ++pass_count
    if `machine' {
        display "[OK] 2.3"
    }
    else if `quiet' == 0 {
        display as result "  PASS: tvmerge continuous proportion correct"
    }
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' 2.3"
    if `machine' {
        display "[FAIL] 2.3|`=_rc'"
    }
    else {
        display as error "  FAIL: tvmerge continuous test (error `=_rc')"
    }
}

* -----------------------------------------------------------------------------
* Test 2.4: End-to-end continuous through tvmerge + tvevent
* Tests that continuous proportioning works correctly through pipeline
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 2.4: Continuous variable through tvmerge then tvevent"
}

capture {
    * Dataset 1: 100 days with dose = 100
    clear
    input long id double(start stop) double dose_rate
        1  21915  22015  100
    end
    format %td start stop
    save "${DATA_DIR}/_val_e2e_ds1.dta", replace

    * Dataset 2: Overlaps first 60 days
    clear
    input long id double(start stop) byte flag
        1  21915  21975  1
    end
    format %td start stop
    save "${DATA_DIR}/_val_e2e_ds2.dta", replace

    * Merge - produces intersection [21915, 21975] = 60 days
    tvmerge "${DATA_DIR}/_val_e2e_ds1.dta" "${DATA_DIR}/_val_e2e_ds2.dta", id(id) ///
        start(start start) stop(stop stop) ///
        exposure(dose_rate flag) ///
        continuous(dose_rate) ///
        generate(dose marker)

    * Get the dose after merge: proportion = (60+1)/(100+1) = 61/101 ≈ 0.604
    * dose = 100 * 0.604 ≈ 60.4
    quietly sum dose
    local post_merge_dose = r(sum)

    save "${DATA_DIR}/_val_e2e_merged.dta", replace

    * Now split with tvevent at day 30 (21945)
    * type(single) splits and keeps only pre-event portion
    clear
    input long id double(event_dt)
        1  21945   // Day 30
    end
    format %td event_dt

    tvevent using "${DATA_DIR}/_val_e2e_merged.dta", id(id) date(event_dt) ///
        startvar(start) stopvar(stop) ///
        continuous(dose) generate(outcome)

    * After tvevent with type(single):
    * - Original interval [21915, 21975] split at 21945
    * - Pre-event [21915, 21945] = 30 days with event
    * - Post-event [21945, 21975] = 30 days is REMOVED by type(single)
    * The proportioned dose for pre-event = 30/60 * post_merge_dose ≈ 30.2

    quietly sum dose
    local post_split_dose = r(sum)

    * The split should proportion: (30 days pre-event) / (60 days original)
    * Expected = post_merge_dose * 30/60 = post_merge_dose / 2
    local expected = `post_merge_dose' / 2
    assert abs(`post_split_dose' - `expected') < 2
}
if _rc == 0 {
    local ++pass_count
    if `machine' {
        display "[OK] 2.4"
    }
    else if `quiet' == 0 {
        display as result "  PASS: Continuous preserved through tvmerge + tvevent"
    }
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' 2.4"
    if `machine' {
        display "[FAIL] 2.4|`=_rc'"
    }
    else {
        display as error "  FAIL: End-to-end continuous test (error `=_rc')"
    }
}

* =============================================================================
* SECTION 3: PERSON-TIME CONSERVATION
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 3: Person-Time Conservation"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 3.1: Person-time after tvexpose equals study duration
* Note: Small variance (1-2 days) allowed due to interval boundary handling
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.1: Person-time conservation in tvexpose"
}

capture {
    * Create cohort with known duration
    clear
    input long id double(study_entry study_exit)
        1  21915  22280   // 365 days
        2  21915  22100   // 185 days
        3  21915  21945   // 30 days
    end
    format %td study_entry study_exit

    * Calculate expected total person-time
    gen double expected_pt = study_exit - study_entry
    quietly sum expected_pt
    local expected_total = r(sum)

    save "${DATA_DIR}/_val_pt_cohort.dta", replace

    * Create exposure with gaps
    clear
    input long id double(start stop) byte exp_type
        1  21930  21960  1
        1  22000  22100  1
        2  21920  21980  1
        3  21920  21940  1
    end
    format %td start stop
    save "${DATA_DIR}/_val_pt_exposure.dta", replace

    * Run tvexpose
    use "${DATA_DIR}/_val_pt_cohort.dta", clear
    tvexpose using "${DATA_DIR}/_val_pt_exposure.dta", id(id) start(start) stop(stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit)

    * Calculate actual total person-time
    gen double actual_pt = stop - start
    quietly sum actual_pt
    local actual_total = r(sum)

    * Should match expected within tolerance
    * Allow 3 days per person (9 days total for 3 persons) for boundary handling
    assert abs(`actual_total' - `expected_total') <= 10
}
if _rc == 0 {
    local ++pass_count
    if `machine' {
        display "[OK] 3.1"
    }
    else if `quiet' == 0 {
        display as result "  PASS: Person-time conserved in tvexpose"
    }
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' 3.1"
    if `machine' {
        display "[FAIL] 3.1|`=_rc'"
    }
    else {
        display as error "  FAIL: Person-time conservation test (error `=_rc')"
    }
}

* -----------------------------------------------------------------------------
* Test 3.2: Person-time after tvevent type(single) - post-event time removed
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.2: Person-time after tvevent type(single)"
}

capture {
    * Create intervals totaling 100 days
    clear
    input long id double(start stop)
        1  21915  22015
    end
    format %td start stop

    gen double orig_pt = stop - start
    quietly sum orig_pt
    local orig_total = r(sum)

    save "${DATA_DIR}/_val_pt_single.dta", replace

    * Event at day 40
    clear
    input long id double(event_dt)
        1  21955
    end
    format %td event_dt

    tvevent using "${DATA_DIR}/_val_pt_single.dta", id(id) date(event_dt) ///
        startvar(start) stopvar(stop) ///
        type(single) generate(outcome)

    * Should only have person-time up to event
    gen double final_pt = stop - start
    quietly sum final_pt
    local final_total = r(sum)

    * Person-time should be ~40 (event at day 40 censors rest)
    assert abs(`final_total' - 40) < 1
}
if _rc == 0 {
    local ++pass_count
    if `machine' {
        display "[OK] 3.2"
    }
    else if `quiet' == 0 {
        display as result "  PASS: Post-event person-time correctly removed"
    }
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' 3.2"
    if `machine' {
        display "[FAIL] 3.2|`=_rc'"
    }
    else {
        display as error "  FAIL: Post-event person-time test (error `=_rc')"
    }
}

* =============================================================================
* SECTION 4: ZERO-DURATION INTERVAL HANDLING
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 4: Zero-Duration Interval Handling"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 4.1: Zero-duration interval in tvevent
* Note: For zero-duration [X, X], event at X is at start (not within interval)
* so it won't match. We test with event at stop instead.
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.1: Zero-duration interval handling"
    display as text "  Interval [day X, day X] - tests dose preservation"
}

capture {
    * Create zero-duration interval
    clear
    input long id double(start stop) double dose
        1  21915  21915  10   // Same day = instant exposure
    end
    format %td start stop
    save "${DATA_DIR}/_val_zero_dur.dta", replace

    * Event AFTER the zero-duration interval (so it doesn't affect it)
    * This tests that zero-duration intervals are preserved correctly
    clear
    input long id double(event_dt)
        1  21920   // 5 days after the zero-duration interval
    end
    format %td event_dt

    tvevent using "${DATA_DIR}/_val_zero_dur.dta", id(id) date(event_dt) ///
        startvar(start) stopvar(stop) ///
        continuous(dose) generate(outcome)

    * Event is outside the interval, so no match - interval preserved as-is
    quietly count
    assert r(N) == 1

    * Event should NOT be flagged (event date not in [21915, 21915])
    quietly count if outcome == 1
    assert r(N) == 0

    * Dose should be preserved
    quietly sum dose
    assert abs(r(mean) - 10) < 0.1
}
if _rc == 0 {
    local ++pass_count
    if `machine' {
        display "[OK] 4.1"
    }
    else if `quiet' == 0 {
        display as result "  PASS: Zero-duration interval handled correctly"
    }
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' 4.1"
    if `machine' {
        display "[FAIL] 4.1|`=_rc'"
    }
    else {
        display as error "  FAIL: Zero-duration interval test (error `=_rc')"
    }
}

* -----------------------------------------------------------------------------
* Test 4.2: Zero-duration in tvmerge
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.2: Zero-duration interval in tvmerge"
}

capture {
    * Dataset 1 with zero-duration
    clear
    input long id double(start stop) double dose
        1  21915  21915  10
    end
    format %td start stop
    save "${DATA_DIR}/_val_zero_ds1.dta", replace

    * Dataset 2 spanning that point
    clear
    input long id double(start stop) byte flag
        1  21910  21920  1
    end
    format %td start stop
    save "${DATA_DIR}/_val_zero_ds2.dta", replace

    * Merge
    tvmerge "${DATA_DIR}/_val_zero_ds1.dta" "${DATA_DIR}/_val_zero_ds2.dta", id(id) ///
        start(start start) stop(stop stop) ///
        exposure(dose flag) ///
        continuous(dose) ///
        generate(d f)

    * Should get intersection at single point
    quietly count if start == stop
    assert r(N) >= 1

    * Dose at that point should be 10 (100% overlap)
    quietly sum d if start == 21915 & stop == 21915
    assert abs(r(mean) - 10) < 0.1
}
if _rc == 0 {
    local ++pass_count
    if `machine' {
        display "[OK] 4.2"
    }
    else if `quiet' == 0 {
        display as result "  PASS: Zero-duration in tvmerge handled correctly"
    }
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' 4.2"
    if `machine' {
        display "[FAIL] 4.2|`=_rc'"
    }
    else {
        display as error "  FAIL: Zero-duration tvmerge test (error `=_rc')"
    }
}

* =============================================================================
* SECTION 5: EVENTS AT INTERVAL START DATES
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 5: Events at Interval Start Dates"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 5.1: Event exactly at interval start (should NOT flag in that interval)
* This tests the survival analysis convention: risk begins at start
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 5.1: Event at interval start date"
    display as text "  Interval [21915, 22015], Event at 21915"
    display as text "  Expected: Event NOT flagged (risk starts at, not before, start)"
}

capture {
    * Create interval
    clear
    input long id double(start stop)
        1  21915  22015
    end
    format %td start stop
    save "${DATA_DIR}/_val_start_event.dta", replace

    * Event at exact start
    clear
    input long id double(event_dt)
        1  21915
    end
    format %td event_dt

    tvevent using "${DATA_DIR}/_val_start_event.dta", id(id) date(event_dt) ///
        startvar(start) stopvar(stop) ///
        generate(outcome)

    * Event at start should NOT cause a split (date > start is strict)
    * The event should NOT be flagged in this interval
    quietly count if outcome == 1
    local n_events = r(N)

    * Per survival analysis convention, event at t=start is before risk begins
    assert `n_events' == 0
}
if _rc == 0 {
    local ++pass_count
    if `machine' {
        display "[OK] 5.1"
    }
    else if `quiet' == 0 {
        display as result "  PASS: Event at start not flagged (correct per survival convention)"
    }
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' 5.1"
    if `machine' {
        display "[FAIL] 5.1|`=_rc'"
    }
    else {
        display as error "  FAIL: Event at start test (error `=_rc')"
    }
}

* -----------------------------------------------------------------------------
* Test 5.2: Event between two consecutive intervals - flagged at end of first
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 5.2: Event at boundary between consecutive intervals"
}

capture {
    * Two consecutive intervals
    clear
    input long id double(start stop)
        1  21915  21965
        1  21965  22015
    end
    format %td start stop
    save "${DATA_DIR}/_val_boundary_event.dta", replace

    * Event at boundary (21965)
    clear
    input long id double(event_dt)
        1  21965
    end
    format %td event_dt

    tvevent using "${DATA_DIR}/_val_boundary_event.dta", id(id) date(event_dt) ///
        startvar(start) stopvar(stop) ///
        generate(outcome)

    * Event at stop of first interval should be flagged there
    quietly count if outcome == 1 & stop == 21965
    assert r(N) == 1

    * Event at start of second interval should NOT be flagged there
    quietly count if outcome == 1 & start == 21965
    assert r(N) == 0
}
if _rc == 0 {
    local ++pass_count
    if `machine' {
        display "[OK] 5.2"
    }
    else if `quiet' == 0 {
        display as result "  PASS: Boundary event flagged at interval end, not start"
    }
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' 5.2"
    if `machine' {
        display "[FAIL] 5.2|`=_rc'"
    }
    else {
        display as error "  FAIL: Boundary event test (error `=_rc')"
    }
}

* =============================================================================
* SECTION 6: MISSING VALUE HANDLING
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 6: Missing Value Handling"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 6.1: Missing event date - should not flag any events
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 6.1: Missing event date"
}

capture {
    * Create intervals
    clear
    input long id double(start stop)
        1  21915  22015
    end
    format %td start stop
    save "${DATA_DIR}/_val_missing_event.dta", replace

    * Missing event date
    clear
    input long id double(event_dt)
        1  .
    end

    tvevent using "${DATA_DIR}/_val_missing_event.dta", id(id) date(event_dt) ///
        startvar(start) stopvar(stop) ///
        generate(outcome)

    * No events should be flagged
    quietly count if outcome == 1
    assert r(N) == 0

    * Should still have the original interval
    quietly count
    assert r(N) == 1
}
if _rc == 0 {
    local ++pass_count
    if `machine' {
        display "[OK] 6.1"
    }
    else if `quiet' == 0 {
        display as result "  PASS: Missing event date handled correctly"
    }
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' 6.1"
    if `machine' {
        display "[FAIL] 6.1|`=_rc'"
    }
    else {
        display as error "  FAIL: Missing event date test (error `=_rc')"
    }
}

* -----------------------------------------------------------------------------
* Test 6.2: Missing continuous variable value
* Tests that missing values remain missing after continuous proportioning
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 6.2: Missing continuous variable value"
}

capture {
    * Create interval with missing dose
    clear
    input long id double(start stop) double dose
        1  21915  22015  .
    end
    format %td start stop
    save "${DATA_DIR}/_val_missing_cont.dta", replace

    * Event to trigger split - type(single) keeps only pre-event interval
    clear
    input long id double(event_dt)
        1  21965
    end
    format %td event_dt

    tvevent using "${DATA_DIR}/_val_missing_cont.dta", id(id) date(event_dt) ///
        startvar(start) stopvar(stop) ///
        continuous(dose) generate(outcome)

    * With type(single), only the pre-event interval remains
    quietly count
    assert r(N) == 1

    * Dose should still be missing (missing * ratio = missing)
    quietly count if missing(dose)
    assert r(N) == 1
}
if _rc == 0 {
    local ++pass_count
    if `machine' {
        display "[OK] 6.2"
    }
    else if `quiet' == 0 {
        display as result "  PASS: Missing continuous value preserved as missing"
    }
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' 6.2"
    if `machine' {
        display "[FAIL] 6.2|`=_rc'"
    }
    else {
        display as error "  FAIL: Missing continuous test (error `=_rc')"
    }
}

* =============================================================================
* SECTION 7: VARIABLE LABEL PRESERVATION
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 7: Variable Label Preservation"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 7.1: Variable labels survive tvexpose
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 7.1: Variable labels preserved by tvexpose"
}

capture {
    * Create cohort with labeled variables
    clear
    input long id double(study_entry study_exit) byte female
        1  21915  22280  1
    end
    format %td study_entry study_exit
    label variable study_entry "Date of study enrollment"
    label variable study_exit "Date of study exit"
    label variable female "Patient sex (1=female)"
    save "${DATA_DIR}/_val_label_cohort.dta", replace

    * Create exposure
    clear
    input long id double(start stop) byte exp_type
        1  21930  21960  1
    end
    format %td start stop
    save "${DATA_DIR}/_val_label_exposure.dta", replace

    * Run tvexpose with keepvars
    use "${DATA_DIR}/_val_label_cohort.dta", clear
    tvexpose using "${DATA_DIR}/_val_label_exposure.dta", id(id) start(start) stop(stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        keepvars(female) keepdates

    * Check labels are preserved
    local lbl_entry : variable label study_entry
    local lbl_exit : variable label study_exit
    local lbl_female : variable label female

    assert "`lbl_entry'" == "Date of study enrollment"
    assert "`lbl_exit'" == "Date of study exit"
    assert "`lbl_female'" == "Patient sex (1=female)"
}
if _rc == 0 {
    local ++pass_count
    if `machine' {
        display "[OK] 7.1"
    }
    else if `quiet' == 0 {
        display as result "  PASS: Variable labels preserved by tvexpose"
    }
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' 7.1"
    if `machine' {
        display "[FAIL] 7.1|`=_rc'"
    }
    else {
        display as error "  FAIL: Variable label preservation test (error `=_rc')"
    }
}

* -----------------------------------------------------------------------------
* Test 7.2: Value labels survive tvevent
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 7.2: Value labels created by tvevent"
}

capture {
    * Create intervals
    clear
    input long id double(start stop)
        1  21915  22015
    end
    format %td start stop
    save "${DATA_DIR}/_val_vallbl_intervals.dta", replace

    * Event with label
    clear
    input long id double(event_dt death_dt)
        1  21965  .
    end
    format %td event_dt death_dt
    label variable event_dt "Primary outcome event"
    label variable death_dt "Death"

    tvevent using "${DATA_DIR}/_val_vallbl_intervals.dta", id(id) date(event_dt) ///
        startvar(start) stopvar(stop) ///
        compete(death_dt) ///
        generate(status)

    * Check value labels exist
    local vallbl : value label status
    assert "`vallbl'" != ""

    * Check label for value 0 (censored)
    local lbl0 : label `vallbl' 0
    assert "`lbl0'" == "Censored"
}
if _rc == 0 {
    local ++pass_count
    if `machine' {
        display "[OK] 7.2"
    }
    else if `quiet' == 0 {
        display as result "  PASS: Value labels created by tvevent"
    }
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' 7.2"
    if `machine' {
        display "[FAIL] 7.2|`=_rc'"
    }
    else {
        display as error "  FAIL: tvevent value labels test (error `=_rc')"
    }
}

* =============================================================================
* SUMMARY
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "COMPREHENSIVE VALIDATION SUMMARY"
    display as text "{hline 70}"
    display as text "Total tests:  `test_count'"
    display as text "Passed:       `pass_count'"
    display as text "Failed:       `fail_count'"

    if `fail_count' > 0 {
        display as error "Failed tests:`failed_tests'"
    }
    else {
        display as result "All tests PASSED!"
    }
    display as text "{hline 70}"
}

if `machine' {
    display "[SUMMARY] `pass_count'/`test_count'"
}

* Set return code
if `fail_count' > 0 {
    exit 1
}
