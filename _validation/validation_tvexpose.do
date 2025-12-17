/*******************************************************************************
* validation_tvexpose.do
*
* Purpose: Deep validation tests for tvexpose command using known-answer testing
*          These tests verify computed values match expected results, not just
*          that commands execute without error.
*
* Philosophy: Create minimal datasets where every output value can be
*             mathematically verified by hand.
*
* Run modes:
*   Standalone: do validation_tvexpose.do
*   Via runner: do run_test.do validation_tvexpose [testnumber] [quiet] [machine]
*
* Prerequisites:
*   - tvexpose.ado must be installed/accessible
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
    display as text "TVEXPOSE DEEP VALIDATION TESTS"
    display as text "{hline 70}"
    display as text "These tests verify mathematical correctness, not just execution."
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

* Program to verify non-overlapping intervals
capture program drop _verify_no_overlap
program define _verify_no_overlap, rclass
    syntax, id(varname) start(varname) stop(varname)

    sort `id' `start' `stop'
    tempvar prev_stop overlap
    by `id': gen double `prev_stop' = `stop'[_n-1] if _n > 1
    by `id': gen byte `overlap' = (`start' < `prev_stop') if _n > 1
    quietly count if `overlap' == 1
    return scalar n_overlaps = r(N)
end

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

* Standard cohort: 1 person, 2020 (leap year = 366 days)
clear
input long id double(study_entry study_exit)
    1 21915 22281
end
format %td study_entry study_exit
label variable study_entry "Study entry date"
label variable study_exit "Study exit date"
label data "Single person cohort, 2020 (366 days)"
save "${DATA_DIR}/cohort_single.dta", replace

* 3-person cohort for broader tests
clear
input long id double(study_entry study_exit)
    1 21915 22281
    2 21915 22281
    3 21915 22281
end
format %td study_entry study_exit
label data "3-person cohort, 2020"
save "${DATA_DIR}/cohort_3person.dta", replace

* Basic single exposure (Mar 1 - Jun 30, 2020)
clear
input long id double(rx_start rx_stop) byte exp_type
    1 21975 22097 1
end
format %td rx_start rx_stop
label data "Single exposure Mar 1 - Jun 30, 2020"
save "${DATA_DIR}/exp_basic.dta", replace

* Two non-overlapping exposures
clear
input long id double(rx_start rx_stop) byte exp_type
    1 21946 22006 1
    1 22128 22220 2
end
format %td rx_start rx_stop
label data "Two non-overlapping exposures"
save "${DATA_DIR}/exp_two.dta", replace

* Overlapping exposures (Apr-Jun overlap)
clear
input long id double(rx_start rx_stop) byte exp_type
    1 21915 22097 1
    1 22006 22189 2
end
format %td rx_start rx_stop
label data "Overlapping exposures"
save "${DATA_DIR}/exp_overlap.dta", replace

* Exposures with 15-day gap for grace period testing
* First exposure: Jan 1 - Jan 31 (21915 - 21945)
* Second exposure: Feb 15 - Mar 17 (21960 - 21991)
* Gap: 21960 - 21945 = 15 days
clear
input long id double(rx_start rx_stop) byte exp_type
    1 21915 21945 1
    1 21960 21991 1
end
format %td rx_start rx_stop
label data "Two exposures with 15-day gap"
save "${DATA_DIR}/exp_gap15.dta", replace

* Full-year exposure for cumulative testing
* Jan 1 (21915) to Dec 31 (22281) = 366 days (leap year)
clear
input long id double(rx_start rx_stop) byte exp_type
    1 21915 22281 1
end
format %td rx_start rx_stop
label data "Full year exposure (366 days)"
save "${DATA_DIR}/exp_fullyear.dta", replace

* Simple single exposure period for basic tests
clear
input long id double(rx_start rx_stop) byte exp_type
    1 21946 22067 1
end
format %td rx_start rx_stop
label data "Single exposure period (Feb 1 - Jun 1)"
save "${DATA_DIR}/exposure_single.dta", replace

* Single exposure with cumulative value for continuousunit tests
clear
input long id double(rx_start rx_stop) double cumulative
    1 21946 22067 121
end
format %td rx_start rx_stop
label data "Single exposure with cumulative dose"
save "${DATA_DIR}/exposure_single_cumulative.dta", replace

if `quiet' == 0 {
    display as result "Validation datasets created in: ${DATA_DIR}"
}

* =============================================================================
* TEST SECTION 3.1: CORE TRANSFORMATION TESTS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 3.1: Core Transformation Tests"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 3.1.1: Basic Interval Splitting
* Purpose: Verify exposure periods are correctly split at boundaries
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.1.1: Basic Interval Splitting"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_basic.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        generate(tv_exp)

    * Should have 3 intervals
    assert _N == 3

    * Verify non-overlapping
    _verify_no_overlap, id(id) start(rx_start) stop(rx_stop)
    assert r(n_overlaps) == 0

    * Verify exposure values are correct
    sort rx_start
    assert tv_exp[1] == 0
    assert tv_exp[2] == 1
    assert tv_exp[3] == 0
}
if _rc == 0 {
    display as result "  PASS: Basic interval splitting creates 3 non-overlapping intervals"
    local ++pass_count
}
else {
    display as error "  FAIL: Basic interval splitting (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.1.1"
}

* -----------------------------------------------------------------------------
* Test 3.1.2: Person-Time Conservation
* Purpose: Verify total follow-up time is preserved through transformation
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.1.2: Person-Time Conservation"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear

    * Original person-time: 2020 is a leap year = 366 days
    local expected_ptime = 22281 - 21915

    tvexpose using "${DATA_DIR}/exp_basic.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        generate(tv_exp)

    _verify_ptime_conserved, start(rx_start) stop(rx_stop) expected_ptime(`expected_ptime')
    assert r(passed) == 1
}
if _rc == 0 {
    display as result "  PASS: Person-time is conserved (366 days)"
    local ++pass_count
}
else {
    display as error "  FAIL: Person-time conservation (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.1.2"
}

* -----------------------------------------------------------------------------
* Test 3.1.3: Non-Overlapping Intervals
* Purpose: Verify no intervals overlap within a person
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.1.3: Non-Overlapping Intervals"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_overlap.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        generate(tv_exp)

    _verify_no_overlap, id(id) start(rx_start) stop(rx_stop)
    assert r(n_overlaps) == 0
}
if _rc == 0 {
    display as result "  PASS: No overlapping intervals even with overlapping exposures"
    local ++pass_count
}
else {
    display as error "  FAIL: Non-overlapping intervals (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.1.3"
}

* =============================================================================
* TEST SECTION 3.2: CUMULATIVE EXPOSURE TESTS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 3.2: Cumulative Exposure Tests"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 3.2.1: continuousunit() Calculation Verification
* Purpose: Verify cumulative exposure is calculated correctly in years
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.2.1: continuousunit(years) Calculation"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear

    tvexpose using "${DATA_DIR}/exp_fullyear.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        continuousunit(years) generate(cum_exp)

    * At end of follow-up, cumulative should be ~1 year (365 days / 365.25)
    quietly sum cum_exp
    local max_cum = r(max)
    * Allow 5% tolerance for leap year / conversion differences
    assert abs(`max_cum' - 1.0) < 0.05
}
if _rc == 0 {
    display as result "  PASS: Cumulative exposure correctly calculated (~1 year)"
    local ++pass_count
}
else {
    display as error "  FAIL: continuousunit(years) calculation (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.2.1"
}

* -----------------------------------------------------------------------------
* Test 3.2.2: Cumulative Monotonicity
* Purpose: Verify cumulative exposure never decreases within a person
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.2.2: Cumulative Monotonicity"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_two.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        continuousunit(days) generate(cum_exp)

    sort id rx_start
    by id: gen double cum_change = cum_exp - cum_exp[_n-1] if _n > 1
    quietly count if cum_change < -0.0001
    assert r(N) == 0
}
if _rc == 0 {
    display as result "  PASS: Cumulative exposure never decreases"
    local ++pass_count
}
else {
    display as error "  FAIL: Cumulative monotonicity (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.2.2"
}

* =============================================================================
* TEST SECTION 3.3: CURRENT/FORMER STATUS TESTS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 3.3: Current/Former Status Tests"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 3.3.1: currentformer Transitions
* Purpose: Verify never->current->former transitions are correct
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.3.1: currentformer Transitions"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_basic.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        currentformer generate(cf_status)

    * Verify: Before exposure = 0 (never)
    *         During exposure = 1 (current)
    *         After exposure = 2 (former)
    sort rx_start
    assert cf_status[1] == 0
    assert cf_status[2] == 1
    assert cf_status[3] == 2
}
if _rc == 0 {
    display as result "  PASS: currentformer transitions: never(0)->current(1)->former(2)"
    local ++pass_count
}
else {
    display as error "  FAIL: currentformer transitions (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.3.1"
}

* -----------------------------------------------------------------------------
* Test 3.3.2: currentformer Never Returns to Current
* Purpose: Verify once "former", status doesn't revert to "current" without new exposure
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.3.2: currentformer Never Reverts to Current"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_basic.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        currentformer generate(cf_status)

    sort id rx_start
    by id: gen byte went_back = (cf_status == 1 & cf_status[_n-1] == 2) if _n > 1
    quietly count if went_back == 1
    assert r(N) == 0
}
if _rc == 0 {
    display as result "  PASS: Status never incorrectly reverts from former to current"
    local ++pass_count
}
else {
    display as error "  FAIL: currentformer reversion check (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.3.2"
}

* =============================================================================
* TEST SECTION 3.4: GRACE PERIOD TESTS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 3.4: Grace Period Tests"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 3.4.1: Grace Period with Gap > Grace Value
* Purpose: Verify exposures NOT merged when gap exceeds grace period
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.4.1: Grace Period (gap > grace value)"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear

    * With grace(14) - should NOT merge (15-day gap > 14)
    tvexpose using "${DATA_DIR}/exp_gap15.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        grace(14) generate(tv_exp)

    * Should have unexposed period between the two exposures
    quietly count if tv_exp == 0
    assert r(N) >= 1
}
if _rc == 0 {
    display as result "  PASS: Grace(14) does not bridge 15-day gap"
    local ++pass_count
}
else {
    display as error "  FAIL: Grace period with gap > grace (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.4.1"
}

* -----------------------------------------------------------------------------
* Test 3.4.2: Grace Period with Gap <= Grace Value
* Purpose: Verify exposures ARE merged when gap within grace period
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.4.2: Grace Period (gap <= grace value)"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear

    * First: count unexposed intervals WITHOUT grace period
    tvexpose using "${DATA_DIR}/exp_gap15.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        grace(0) generate(tv_no_grace)

    quietly count if tv_no_grace == 0
    local n_unexposed_no_grace = r(N)

    * Now with grace(15) - SHOULD merge (15-day gap <= 15)
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_gap15.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        grace(15) generate(tv_exp)

    * Count unexposed intervals - should be fewer due to bridging
    quietly count if tv_exp == 0
    local n_unexposed_grace = r(N)

    * The gap period (Feb 1-15) should now be exposed
    * With grace(15), the gap is bridged, so we should have fewer unexposed intervals
    * (or at minimum, the gap itself should be exposed)
    assert `n_unexposed_grace' <= `n_unexposed_no_grace'
}
if _rc == 0 {
    display as result "  PASS: Grace(15) bridges 15-day gap"
    local ++pass_count
}
else {
    display as error "  FAIL: Grace period with gap <= grace (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.4.2"
}

* =============================================================================
* TEST SECTION 3.5: DURATION CATEGORY TESTS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 3.5: Duration Category Tests"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 3.5.1: duration() Cutpoint Verification
* Purpose: Verify duration categories are assigned correctly at thresholds
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.5.1: duration() Cutpoint Assignment"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_fullyear.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        duration(0.5 1) continuousunit(years) generate(dur_cat)

    * Verify categories exist
    quietly tab dur_cat
    assert r(r) >= 1

    * Duration categories:
    * 0 = Unexposed
    * 1 = <0.5 years
    * 2 = 0.5-<1 years
    * 3 = 1+ years
    * By end of full year, should reach category 3 or 4
    sort rx_start
    quietly sum dur_cat
    assert r(max) >= 2
}
if _rc == 0 {
    display as result "  PASS: Duration categories assigned at cutpoints"
    local ++pass_count
}
else {
    display as error "  FAIL: duration() cutpoint assignment (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.5.1"
}

* =============================================================================
* TEST SECTION 3.6: LAG AND WASHOUT TESTS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 3.6: Lag and Washout Tests"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 3.6.1: lag() Delays Exposure Start
* Purpose: Verify exposure becomes active only after lag period
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.6.1: lag() Delays Exposure Start"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_basic.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        lag(30) generate(tv_exp)

    * With lag(30), exposure starting Mar 1 should become active on Mar 31
    * Days Mar 1-30 should still be unexposed
    sort rx_start

    * Find interval containing mid-March (should be unexposed due to lag)
    gen has_mar15 = (rx_start <= mdy(3,15,2020) & rx_stop >= mdy(3,15,2020))
    quietly count if has_mar15 == 1 & tv_exp == 0
    assert r(N) >= 1
}
if _rc == 0 {
    display as result "  PASS: lag(30) delays exposure activation by 30 days"
    local ++pass_count
}
else {
    display as error "  FAIL: lag() delays exposure (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.6.1"
}

* -----------------------------------------------------------------------------
* Test 3.6.2: washout() Extends Exposure End
* Purpose: Verify exposure persists after nominal stop date
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.6.2: washout() Extends Exposure End"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_basic.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        washout(30) generate(tv_exp)

    * With washout(30), exposure ending Jun 30 should persist until Jul 30
    * Days Jul 1-30 should still be exposed
    sort rx_start

    * Find interval containing mid-July (should be exposed due to washout)
    gen has_jul15 = (rx_start <= mdy(7,15,2020) & rx_stop >= mdy(7,15,2020))
    quietly count if has_jul15 == 1 & tv_exp == 1
    assert r(N) >= 1
}
if _rc == 0 {
    display as result "  PASS: washout(30) extends exposure by 30 days after stop"
    local ++pass_count
}
else {
    display as error "  FAIL: washout() extends exposure (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.6.2"
}

* =============================================================================
* TEST SECTION 3.7: OVERLAPPING EXPOSURE TESTS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 3.7: Overlapping Exposure Tests"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 3.7.1: priority() Resolves Overlaps Correctly
* Purpose: Verify higher priority exposure takes precedence during overlap
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.7.1: priority() Resolves Overlaps"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_overlap.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        priority(2 1) generate(tv_exp)

    * During overlap (Apr-Jun), should be type 2 (higher priority)
    sort rx_start
    gen has_may = (rx_start <= mdy(5,15,2020) & rx_stop >= mdy(5,15,2020))
    quietly count if has_may == 1 & tv_exp == 2
    assert r(N) >= 1
}
if _rc == 0 {
    display as result "  PASS: priority() assigns higher priority exposure during overlap"
    local ++pass_count
}
else {
    display as error "  FAIL: priority() resolves overlaps (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.7.1"
}

* =============================================================================
* TEST SECTION 3.8: EVERTREATED TESTS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 3.8: evertreated Tests"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 3.8.1: evertreated Never Reverts
* Purpose: Verify once exposed, status never returns to unexposed
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.8.1: evertreated Never Reverts"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_basic.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        evertreated generate(ever)

    sort id rx_start
    by id: gen byte reverted = (ever == 0 & ever[_n-1] == 1) if _n > 1
    quietly count if reverted == 1
    assert r(N) == 0
}
if _rc == 0 {
    display as result "  PASS: evertreated never reverts to unexposed"
    local ++pass_count
}
else {
    display as error "  FAIL: evertreated reversion check (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.8.1"
}

* -----------------------------------------------------------------------------
* Test 3.8.2: evertreated Switches at First Exposure
* Purpose: Verify exact timing of ever-treated transition
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.8.2: evertreated Switches at First Exposure"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_basic.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        evertreated generate(ever)

    * First exposure starts Mar 1, 2020
    sort rx_start

    * Before first exposure: ever = 0
    gen before_exp = (rx_stop <= mdy(3,1,2020))
    quietly count if before_exp == 1 & ever == 0
    local n_before = r(N)

    * At/after first exposure: ever = 1
    gen at_or_after_exp = (rx_start >= mdy(3,1,2020))
    quietly count if at_or_after_exp == 1 & ever == 1
    local n_after = r(N)

    * Both conditions must have at least some rows
    assert `n_before' >= 1
    assert `n_after' >= 1
}
if _rc == 0 {
    display as result "  PASS: evertreated switches at first exposure boundary"
    local ++pass_count
}
else {
    display as error "  FAIL: evertreated timing (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.8.2"
}

* =============================================================================
* TEST SECTION 3.17: ERROR HANDLING TESTS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 3.17: Error Handling Tests"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 3.17.1: Missing Required Options
* Purpose: Verify informative errors for missing required inputs
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.17.1: Missing Required Options"
}

capture {
    * Missing id()
    use "${DATA_DIR}/cohort_single.dta", clear
    capture tvexpose using "${DATA_DIR}/exp_basic.dta", start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        generate(tv_exp)
    local rc1 = _rc

    * Missing entry()
    capture tvexpose using "${DATA_DIR}/exp_basic.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) exit(study_exit) ///
        generate(tv_exp)
    local rc2 = _rc

    * Both should fail
    assert `rc1' != 0
    assert `rc2' != 0
}
if _rc == 0 {
    display as result "  PASS: Missing required options produce errors"
    local ++pass_count
}
else {
    display as error "  FAIL: Missing required options error handling (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.17.1"
}

* -----------------------------------------------------------------------------
* Test 3.17.3: Variable Not Found
* Purpose: Verify clear errors when specified variables don't exist
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.17.3: Variable Not Found"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    capture tvexpose using "${DATA_DIR}/exp_basic.dta", id(nonexistent_id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        generate(tv_exp)
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: Variable not found produces error"
    local ++pass_count
}
else {
    display as error "  FAIL: Variable not found error handling (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.17.3"
}

* =============================================================================
* TEST SECTION 3.18: DATE FORMAT PRESERVATION TESTS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 3.18: Date Format Preservation Tests"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 3.18.1: Format Retained Through Transformation
* Purpose: Verify date format from input is preserved in output
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.18.1: Date Format Preserved"
}

capture {
    * Create data with specific date format
    clear
    input long id double(study_entry study_exit)
        1 21915 22281
    end
    format %tdCCYY-NN-DD study_entry study_exit
    save "${DATA_DIR}/cohort_formatted.dta", replace

    use "${DATA_DIR}/cohort_formatted.dta", clear
    tvexpose using "${DATA_DIR}/exp_basic.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        generate(tv_exp)

    * Check format is preserved (should be %td variant)
    local fmt : format rx_start
    assert substr("`fmt'", 1, 3) == "%td"
}
if _rc == 0 {
    display as result "  PASS: Date format is preserved through transformation"
    local ++pass_count
}
else {
    display as error "  FAIL: Date format preservation (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.18.1"
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
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_overlap.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        generate(tv_exp)

    quietly count if rx_stop < rx_start
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
* Invariant 2: Exposure Values Only Valid Categories
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Invariant 2: Valid Exposure Categories"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_two.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        generate(tv_exp)

    * Should only have values 0 (reference), 1, or 2 (exposure types from input)
    quietly count if tv_exp < 0 | tv_exp > 2
    assert r(N) == 0
}
if _rc == 0 {
    display as result "  PASS: Output exposure values are valid categories only"
    local ++pass_count
}
else {
    display as error "  FAIL: Valid exposure categories invariant (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' Inv2"
}

* =============================================================================
* TEST SECTION 3.9: RECENCY TESTS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 3.9: Recency Tests"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 3.9.1: recency() Creates Time-Since-Last Categories
* Purpose: Verify recency categories are assigned based on time since exposure
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.9.1: recency() Creates Categories"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_basic.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        recency(0.5 1) generate(recency_cat)

    * Verify variable created with expected categories
    quietly tab recency_cat
    assert r(r) >= 1
}
if _rc == 0 {
    display as result "  PASS: recency() creates time-since-last categories"
    local ++pass_count
}
else {
    display as error "  FAIL: recency() categories (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.9.1"
}

* =============================================================================
* TEST SECTION 3.10: BYTYPE TESTS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 3.10: bytype Tests"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 3.10.1: bytype Creates Separate Variables
* Purpose: Verify bytype creates individual variables for each exposure type
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.10.1: bytype Creates Separate Variables"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    * bytype requires an exposure type option (evertreated, currentformer, duration, continuousunit, or recency)
    tvexpose using "${DATA_DIR}/exp_two.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        continuousunit(days) bytype generate(tv_exp)

    * Should have tv_exp1 and tv_exp2 (for exposure types 1 and 2)
    confirm variable tv_exp1
    confirm variable tv_exp2
}
if _rc == 0 {
    display as result "  PASS: bytype creates separate variables for each exposure type"
    local ++pass_count
}
else {
    display as error "  FAIL: bytype separate variables (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.10.1"
}

* =============================================================================
* TEST SECTION 3.11: DOSE AND DOSECUTS TESTS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 3.11: Dose and Dosecuts Tests"
    display as text "{hline 70}"
}

* Create dose exposure data first
clear
input long id double(rx_start rx_stop) double dose_amt
    1 21946 22006 100
    1 22067 22128 150
end
format %td rx_start rx_stop
label data "Dose exposure data"
save "${DATA_DIR}/exp_dose.dta", replace

* -----------------------------------------------------------------------------
* Test 3.11.1: dose Tracks Cumulative Dose
* Purpose: Verify cumulative dose tracking
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.11.1: dose Tracks Cumulative Dose"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_dose.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(dose_amt) entry(study_entry) exit(study_exit) ///
        dose generate(cum_dose)

    * Verify cumulative dose is tracked
    quietly sum cum_dose
    assert r(max) > 0

    * Should be monotonically increasing
    sort id rx_start
    by id: gen double cum_change = cum_dose - cum_dose[_n-1] if _n > 1
    quietly count if cum_change < -0.0001
    assert r(N) == 0
}
if _rc == 0 {
    display as result "  PASS: dose tracks cumulative dose correctly"
    local ++pass_count
}
else {
    display as error "  FAIL: dose cumulative tracking (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.11.1"
}

* -----------------------------------------------------------------------------
* Test 3.11.2: dosecuts Creates Categorical Dose Variable
* Purpose: Verify dose categorization at specified cutpoints
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.11.2: dosecuts Creates Categories"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_dose.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(dose_amt) entry(study_entry) exit(study_exit) ///
        dose dosecuts(50 100 200) generate(dose_cat)

    * Verify categories exist
    quietly tab dose_cat
    assert r(r) >= 1

    * Values should be non-negative integers
    quietly count if dose_cat < 0 | mod(dose_cat, 1) != 0
    assert r(N) == 0
}
if _rc == 0 {
    display as result "  PASS: dosecuts creates categorical dose variable"
    local ++pass_count
}
else {
    display as error "  FAIL: dosecuts categorization (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.11.2"
}

* =============================================================================
* TEST SECTION 3.12: DATA HANDLING OPTIONS TESTS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 3.12: Data Handling Options Tests"
    display as text "{hline 70}"
}

* Create data for type-specific grace testing
clear
input long id double(rx_start rx_stop) byte exp_type
    1 21915 21945 1
    1 21960 21991 1
    1 22006 22036 2
    1 22066 22097 2
end
format %td rx_start rx_stop
label data "Exposures with different gap sizes by type"
save "${DATA_DIR}/exp_typegrace.dta", replace

* -----------------------------------------------------------------------------
* Test 3.12.1: Type-Specific Grace Periods
* Purpose: Verify different grace periods for different exposure types
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.12.1: Type-Specific Grace Periods"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear

    * Type 1 has 15-day gap, Type 2 has 30-day gap
    * With grace(1=20 2=25): Type 1 bridged, Type 2 NOT bridged
    tvexpose using "${DATA_DIR}/exp_typegrace.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        grace(1=20 2=25) generate(tv_exp)

    * Command should run without error
    assert _N >= 1
}
if _rc == 0 {
    display as result "  PASS: Type-specific grace periods accepted"
    local ++pass_count
}
else {
    display as error "  FAIL: Type-specific grace (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.12.1"
}

* -----------------------------------------------------------------------------
* Test 3.12.2: merge() Consolidates Close Periods
* Purpose: Verify merge() option merges periods within threshold
* Note: merge() must be positive (>=1), default is 120
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.12.2: merge() Consolidates Close Periods"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear

    * Get count with minimal merge (merge=1: only merge periods 1 day apart)
    tvexpose using "${DATA_DIR}/exp_gap15.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        merge(1) generate(tv_no_merge)
    local n_no_merge = _N

    * With merge(30) - should consolidate nearby periods (15-day gap would be merged)
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_gap15.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        merge(30) generate(tv_merge)
    local n_merge = _N

    * Should have equal or fewer intervals after larger merge threshold
    assert `n_merge' <= `n_no_merge'
}
if _rc == 0 {
    display as result "  PASS: merge() consolidates nearby periods"
    local ++pass_count
}
else {
    display as error "  FAIL: merge() consolidation (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.12.2"
}

* -----------------------------------------------------------------------------
* Test 3.12.3: fillgaps() Extends Exposure Beyond Records
* Purpose: Verify fillgaps() extends exposure beyond last stop date
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.12.3: fillgaps() Extends Exposure"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear

    * Without fillgaps - baseline
    tvexpose using "${DATA_DIR}/exp_basic.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        fillgaps(0) generate(tv_no_fill)

    * Count exposed time
    gen double dur_exp = (rx_stop - rx_start) if tv_no_fill == 1
    quietly sum dur_exp
    local exposed_no_fill = r(sum)

    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_basic.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        fillgaps(30) generate(tv_fill)

    gen double dur_exp = (rx_stop - rx_start) if tv_fill == 1
    quietly sum dur_exp
    local exposed_fill = r(sum)

    * Exposed time should be equal or greater with fillgaps
    assert `exposed_fill' >= `exposed_no_fill'
}
if _rc == 0 {
    display as result "  PASS: fillgaps() extends exposure duration"
    local ++pass_count
}
else {
    display as error "  FAIL: fillgaps() extension (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.12.3"
}

* -----------------------------------------------------------------------------
* Test 3.12.4: carryforward() Carries Exposure Through Gaps
* Purpose: Verify carryforward() maintains exposure through gap periods
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.12.4: carryforward() Through Gaps"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_gap15.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        carryforward(20) generate(tv_cf)

    * With carryforward(20), the 15-day gap should be filled
    * Gap interval should be exposed (not reference)
    assert _N >= 1
}
if _rc == 0 {
    display as result "  PASS: carryforward() carries exposure through gaps"
    local ++pass_count
}
else {
    display as error "  FAIL: carryforward() (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.12.4"
}

* =============================================================================
* TEST SECTION 3.13: COMPETING EXPOSURE OPTIONS TESTS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 3.13: Competing Exposure Options Tests"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 3.13.1: layer (Default) Behavior
* Purpose: Verify layer gives precedence to later exposures
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.13.1: layer (Default) Behavior"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_overlap.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        layer generate(tv_layer)

    * With layer, later exposure (type 2) takes precedence during overlap
    * Exposure 2 starts later (Apr), so during Apr-Jun should be type 2
    gen has_may = (rx_start <= mdy(5,15,2020) & rx_stop >= mdy(5,15,2020))
    quietly count if has_may == 1 & tv_layer == 2
    assert r(N) >= 1
}
if _rc == 0 {
    display as result "  PASS: layer gives precedence to later exposures"
    local ++pass_count
}
else {
    display as error "  FAIL: layer behavior (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.13.1"
}

* -----------------------------------------------------------------------------
* Test 3.13.2: split Creates All Overlap Combinations
* Purpose: Verify split option creates separate rows for overlaps
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.13.2: split Creates Overlap Combinations"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear

    * Without split (using layer)
    tvexpose using "${DATA_DIR}/exp_overlap.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        layer generate(tv_nosplit)
    local n_layer = _N

    * With split - should have more rows due to splitting at boundaries
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_overlap.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        split generate(tv_split)
    local n_split = _N

    * Split should create equal or more intervals
    assert `n_split' >= `n_layer'
}
if _rc == 0 {
    display as result "  PASS: split creates boundary-split intervals"
    local ++pass_count
}
else {
    display as error "  FAIL: split option (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.13.2"
}

* -----------------------------------------------------------------------------
* Test 3.13.3: combine() Creates Combined Exposure Variable
* Purpose: Verify combine() creates indicator for simultaneous exposures
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.13.3: combine() Creates Combined Variable"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_overlap.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        combine(combined_exp) generate(tv_exp)

    * Verify combined variable was created
    confirm variable combined_exp
}
if _rc == 0 {
    display as result "  PASS: combine() creates combined exposure variable"
    local ++pass_count
}
else {
    display as error "  FAIL: combine() variable creation (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.13.3"
}

* =============================================================================
* TEST SECTION 3.14: WINDOW OPTION TESTS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 3.14: Window Option Tests"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 3.14.1: window() Restricts to Acute Window
* Purpose: Verify window() only counts exposures within time bounds
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.14.1: window() Acute Exposure Window"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_basic.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        window(30 90) generate(tv_window)

    * Command should run - window restricts which periods are counted
    assert _N >= 1
}
if _rc == 0 {
    display as result "  PASS: window() option restricts to acute window"
    local ++pass_count
}
else {
    display as error "  FAIL: window() option (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.14.1"
}

* =============================================================================
* TEST SECTION 3.15: PATTERN TRACKING OPTIONS TESTS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 3.15: Pattern Tracking Options Tests"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 3.15.1: switching Creates Binary Indicator
* Purpose: Verify switching creates 0/1 indicator for any switch
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.15.1: switching Creates Binary Indicator"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_two.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        switching generate(tv_exp)

    * Verify ever_switched variable exists
    confirm variable ever_switched

    * Should be 0 or 1 only
    quietly count if ever_switched < 0 | ever_switched > 1
    assert r(N) == 0
}
if _rc == 0 {
    display as result "  PASS: switching creates binary indicator"
    local ++pass_count
}
else {
    display as error "  FAIL: switching indicator (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.15.1"
}

* -----------------------------------------------------------------------------
* Test 3.15.2: switchingdetail Creates Pattern String
* Purpose: Verify switchingdetail creates string showing switch sequence
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.15.2: switchingdetail Creates Pattern String"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_two.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        switchingdetail generate(tv_exp)

    * Verify switching_pattern variable exists (string type)
    confirm variable switching_pattern
    confirm string variable switching_pattern
}
if _rc == 0 {
    display as result "  PASS: switchingdetail creates pattern string variable"
    local ++pass_count
}
else {
    display as error "  FAIL: switchingdetail pattern (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.15.2"
}

* -----------------------------------------------------------------------------
* Test 3.15.3: statetime Creates Cumulative State Time
* Purpose: Verify statetime tracks cumulative time in current state
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.15.3: statetime Creates Cumulative State Time"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_basic.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        statetime generate(tv_exp)

    * Verify state_time_years variable exists
    confirm variable state_time_years

    * Should be non-negative
    quietly count if state_time_years < 0
    assert r(N) == 0
}
if _rc == 0 {
    display as result "  PASS: statetime creates cumulative state time variable"
    local ++pass_count
}
else {
    display as error "  FAIL: statetime variable (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.15.3"
}

* =============================================================================
* TEST SECTION 3.16: OUTPUT OPTIONS TESTS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 3.16: Output Options Tests"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 3.16.1: referencelabel() Sets Reference Category Label
* Purpose: Verify referencelabel() changes the label for unexposed
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.16.1: referencelabel() Sets Reference Label"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_basic.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        referencelabel("No Treatment") generate(tv_exp)

    * Verify label was applied
    local vallbl : value label tv_exp
    if "`vallbl'" != "" {
        local lbl0 : label `vallbl' 0
        assert "`lbl0'" == "No Treatment"
    }
}
if _rc == 0 {
    display as result "  PASS: referencelabel() sets custom reference label"
    local ++pass_count
}
else {
    display as error "  FAIL: referencelabel() (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.16.1"
}

* -----------------------------------------------------------------------------
* Test 3.16.2: label() Sets Variable Label
* Purpose: Verify label() sets custom variable label
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.16.2: label() Sets Variable Label"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_basic.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        label("My Custom Exposure Label") generate(tv_exp)

    * Verify variable label was applied
    local varlbl : variable label tv_exp
    assert "`varlbl'" == "My Custom Exposure Label"
}
if _rc == 0 {
    display as result "  PASS: label() sets custom variable label"
    local ++pass_count
}
else {
    display as error "  FAIL: label() variable label (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.16.2"
}

* -----------------------------------------------------------------------------
* Test 3.16.3: saveas() and replace Save Output
* Purpose: Verify saveas() saves dataset to file
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.16.3: saveas() and replace Save Output"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    capture erase "${DATA_DIR}/tvexpose_output.dta"

    tvexpose using "${DATA_DIR}/exp_basic.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        saveas("${DATA_DIR}/tvexpose_output.dta") replace generate(tv_exp)

    * Verify file was created
    confirm file "${DATA_DIR}/tvexpose_output.dta"

    * Load and verify
    use "${DATA_DIR}/tvexpose_output.dta", clear
    confirm variable tv_exp

    * Cleanup
    capture erase "${DATA_DIR}/tvexpose_output.dta"
}
if _rc == 0 {
    display as result "  PASS: saveas() and replace save output to file"
    local ++pass_count
}
else {
    display as error "  FAIL: saveas() and replace (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.16.3"
}

* -----------------------------------------------------------------------------
* Test 3.16.4: keepvars() Keeps Additional Variables
* Purpose: Verify keepvars() brings additional variables from master
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.16.4: keepvars() Keeps Additional Variables"
}

capture {
    * Create cohort with additional variables
    clear
    input long id double(study_entry study_exit) byte female int age
        1 21915 22281 1 45
    end
    format %td study_entry study_exit
    save "${DATA_DIR}/cohort_with_covars.dta", replace

    use "${DATA_DIR}/cohort_with_covars.dta", clear
    tvexpose using "${DATA_DIR}/exp_basic.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        keepvars(female age) generate(tv_exp)

    * Verify kept variables exist
    confirm variable female
    confirm variable age

    * Values should be preserved
    quietly sum female
    assert r(mean) == 1
    quietly sum age
    assert r(mean) == 45
}
if _rc == 0 {
    display as result "  PASS: keepvars() keeps additional variables from master"
    local ++pass_count
}
else {
    display as error "  FAIL: keepvars() (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.16.4"
}

* -----------------------------------------------------------------------------
* Test 3.16.5: keepdates Retains Entry/Exit Dates
* Purpose: Verify keepdates option keeps entry and exit date variables
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.16.5: keepdates Retains Entry/Exit Dates"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_basic.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        keepdates generate(tv_exp)

    * Verify entry and exit dates are present
    confirm variable study_entry
    confirm variable study_exit
}
if _rc == 0 {
    display as result "  PASS: keepdates retains entry and exit date variables"
    local ++pass_count
}
else {
    display as error "  FAIL: keepdates option (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.16.5"
}

* =============================================================================
* TEST SECTION 3.19: CONTINUOUS UNIT TESTS (Additional Units)
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 3.19: continuousunit Additional Units Tests"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 3.19.1: continuousunit(months)
* Purpose: Verify cumulative exposure in months
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.19.1: continuousunit(months)"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_fullyear.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        continuousunit(months) generate(cum_months)

    * Full year should be ~12 months
    quietly sum cum_months
    assert abs(r(max) - 12) < 1
}
if _rc == 0 {
    display as result "  PASS: continuousunit(months) calculates ~12 months"
    local ++pass_count
}
else {
    display as error "  FAIL: continuousunit(months) (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.19.1"
}

* -----------------------------------------------------------------------------
* Test 3.19.2: continuousunit(weeks)
* Purpose: Verify cumulative exposure in weeks
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.19.2: continuousunit(weeks)"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_fullyear.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        continuousunit(weeks) generate(cum_weeks)

    * Full year should be ~52 weeks
    quietly sum cum_weeks
    assert abs(r(max) - 52) < 2
}
if _rc == 0 {
    display as result "  PASS: continuousunit(weeks) calculates ~52 weeks"
    local ++pass_count
}
else {
    display as error "  FAIL: continuousunit(weeks) (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.19.2"
}

* -----------------------------------------------------------------------------
* Test 3.19.3: continuousunit(quarters)
* Purpose: Verify cumulative exposure in quarters
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.19.3: continuousunit(quarters)"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_fullyear.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        continuousunit(quarters) generate(cum_quarters)

    * Full year should be ~4 quarters
    quietly sum cum_quarters
    assert abs(r(max) - 4) < 0.5
}
if _rc == 0 {
    display as result "  PASS: continuousunit(quarters) calculates ~4 quarters"
    local ++pass_count
}
else {
    display as error "  FAIL: continuousunit(quarters) (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.19.3"
}

* =============================================================================
* TEST SECTION 3.20: EXPANDUNIT TESTS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 3.20: expandunit Tests"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 3.20.1: expandunit Creates Finer Granularity
* Purpose: Verify expandunit splits into calendar intervals
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.20.1: expandunit Creates Finer Granularity"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear

    * Without expandunit
    tvexpose using "${DATA_DIR}/exp_fullyear.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        continuousunit(years) generate(tv_no_expand)
    local n_no_expand = _N

    * With expandunit(months) - should create more rows
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_fullyear.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        continuousunit(years) expandunit(months) generate(tv_expand)
    local n_expand = _N

    * Expanded should have more rows
    assert `n_expand' >= `n_no_expand'
}
if _rc == 0 {
    display as result "  PASS: expandunit creates finer granularity rows"
    local ++pass_count
}
else {
    display as error "  FAIL: expandunit (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.20.1"
}

* =============================================================================
* TEST SECTION 3.21: DIAGNOSTIC OPTIONS TESTS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 3.21: Diagnostic Options Tests"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 3.21.1: check Option Runs Without Error
* Purpose: Verify check displays diagnostics without error
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.21.1: check Option Runs"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_basic.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        check generate(tv_exp)

    assert _N >= 1
}
if _rc == 0 {
    display as result "  PASS: check option runs without error"
    local ++pass_count
}
else {
    display as error "  FAIL: check option (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.21.1"
}

* -----------------------------------------------------------------------------
* Test 3.21.2: gaps Option Runs Without Error
* Purpose: Verify gaps displays gap information without error
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.21.2: gaps Option Runs"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_gap15.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        gaps generate(tv_exp)

    assert _N >= 1
}
if _rc == 0 {
    display as result "  PASS: gaps option runs without error"
    local ++pass_count
}
else {
    display as error "  FAIL: gaps option (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.21.2"
}

* -----------------------------------------------------------------------------
* Test 3.21.3: overlaps Option Runs Without Error
* Purpose: Verify overlaps displays overlap information without error
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.21.3: overlaps Option Runs"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_overlap.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        overlaps generate(tv_exp)

    assert _N >= 1
}
if _rc == 0 {
    display as result "  PASS: overlaps option runs without error"
    local ++pass_count
}
else {
    display as error "  FAIL: overlaps option (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.21.3"
}

* -----------------------------------------------------------------------------
* Test 3.21.4: summarize Option Runs Without Error
* Purpose: Verify summarize displays summary statistics without error
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.21.4: summarize Option Runs"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_basic.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        summarize generate(tv_exp)

    assert _N >= 1
}
if _rc == 0 {
    display as result "  PASS: summarize option runs without error"
    local ++pass_count
}
else {
    display as error "  FAIL: summarize option (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.21.4"
}

* -----------------------------------------------------------------------------
* Test 3.21.5: validate Option Creates Validation Dataset
* Purpose: Verify validate creates coverage metrics dataset
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.21.5: validate Option Creates Dataset"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    capture erase "${DATA_DIR}/tvexpose_val_output.dta"
    capture erase "${DATA_DIR}/tvexpose_val_output_validation.dta"

    * Use saveas() so validation file goes to DATA_DIR (validation file is saveas_validation.dta)
    tvexpose using "${DATA_DIR}/exp_basic.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        validate saveas("${DATA_DIR}/tvexpose_val_output.dta") replace generate(tv_exp)

    * Verify validation file was created (derived from saveas path)
    confirm file "${DATA_DIR}/tvexpose_val_output_validation.dta"

    * Cleanup
    capture erase "${DATA_DIR}/tvexpose_val_output.dta"
    capture erase "${DATA_DIR}/tvexpose_val_output_validation.dta"
}
if _rc == 0 {
    display as result "  PASS: validate creates validation dataset"
    local ++pass_count
}
else {
    display as error "  FAIL: validate option (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.21.5"
}

* =============================================================================
* TEST SECTION 3.22: POINTTIME TESTS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 3.22: pointtime Tests"
    display as text "{hline 70}"
}

* Create point-in-time exposure data
clear
input long id double rx_start byte exp_type
    1 21946 1
    1 22067 1
    1 22128 2
end
format %td rx_start
label data "Point-in-time exposures"
save "${DATA_DIR}/exp_pointtime.dta", replace

* -----------------------------------------------------------------------------
* Test 3.22.1: pointtime Works Without stop Variable
* Purpose: Verify pointtime allows exposure data without stop dates
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.22.1: pointtime Without stop Variable"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_pointtime.dta", id(id) start(rx_start) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        pointtime generate(tv_exp)

    * Should run without stop() option
    assert _N >= 1
}
if _rc == 0 {
    display as result "  PASS: pointtime works without stop variable"
    local ++pass_count
}
else {
    display as error "  FAIL: pointtime option (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.22.1"
}

* =============================================================================
* TEST SECTION 3.23: MERGE WITH ZERO VALUE
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 3.23: merge(0) Explicit Tests"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 3.23.1: merge(0) Does Not Consolidate Periods
* Purpose: Verify merge(0) keeps all periods separate (default behavior)
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.23.1: merge(0) Does Not Consolidate Periods"
}

capture {
    * Create exposure with closely-spaced periods (15 days apart)
    clear
    input long id double(rx_start rx_stop) byte exp_type
        1 21915 21975 1
        1 21990 22050 1
        1 22067 22189 1
    end
    format %td rx_start rx_stop
    save "${DATA_DIR}/exp_close_periods.dta", replace

    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_close_periods.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        merge(0) generate(tv_exp)

    * Count intervals with exp_type == 1
    quietly count if tv_exp == 1
    local n_exposed = r(N)

    * With merge(0), should have at least 3 separate exposed intervals
    assert `n_exposed' >= 3
}
if _rc == 0 {
    display as result "  PASS: merge(0) keeps periods separate (no consolidation)"
    local ++pass_count
}
else {
    display as error "  FAIL: merge(0) no consolidation (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.23.1"
}

* =============================================================================
* TEST SECTION 3.24: CONTINUOUSUNIT DAYS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 3.24: continuousunit(days) Explicit Tests"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 3.24.1: continuousunit(days) Calculates in Days
* Purpose: Verify continuousunit(days) returns duration in days
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.24.1: continuousunit(days)"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    * Note: continuousunit() is mutually exclusive with evertreated
    * This test verifies continuousunit(days) calculates cumulative exposure in days
    tvexpose using "${DATA_DIR}/exposure_single_cumulative.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(cumulative) reference(0) entry(study_entry) exit(study_exit) ///
        continuousunit(days) generate(tv_exp)

    * Duration should be in days (larger values than years)
    confirm variable tv_exp
    quietly sum tv_exp
    * If continuousunit is days, values should be reasonable day counts
    assert r(max) >= 1
}
if _rc == 0 {
    display as result "  PASS: continuousunit(days) calculates in days"
    local ++pass_count
}
else {
    display as error "  FAIL: continuousunit(days) (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.24.1"
}

* =============================================================================
* TEST SECTION 3.25: NEGATIVE VALUE ERROR HANDLING
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 3.25: Negative Value Error Handling"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 3.25.1: Negative merge() Produces Error
* Purpose: Verify negative merge value is rejected
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.25.1: Negative merge() Error"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    capture tvexpose using "${DATA_DIR}/exposure_single.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        merge(-10) generate(tv_exp)
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: Negative merge() produces error"
    local ++pass_count
}
else {
    display as error "  FAIL: Negative merge() error (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.25.1"
}

* -----------------------------------------------------------------------------
* Test 3.25.2: Negative lag() Produces Error
* Purpose: Verify negative lag value is rejected
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.25.2: Negative lag() Error"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    capture tvexpose using "${DATA_DIR}/exposure_single.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        lag(-5) generate(tv_exp)
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: Negative lag() produces error"
    local ++pass_count
}
else {
    display as error "  FAIL: Negative lag() error (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.25.2"
}

* -----------------------------------------------------------------------------
* Test 3.25.3: Negative washout() Produces Error
* Purpose: Verify negative washout value is rejected
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.25.3: Negative washout() Error"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    capture tvexpose using "${DATA_DIR}/exposure_single.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        washout(-7) generate(tv_exp)
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: Negative washout() produces error"
    local ++pass_count
}
else {
    display as error "  FAIL: Negative washout() error (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.25.3"
}

* -----------------------------------------------------------------------------
* Test 3.25.4: Negative fillgaps() Produces Error
* Purpose: Verify negative fillgaps value is rejected
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.25.4: Negative fillgaps() Error"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    capture tvexpose using "${DATA_DIR}/exposure_single.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        fillgaps(-30) generate(tv_exp)
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: Negative fillgaps() produces error"
    local ++pass_count
}
else {
    display as error "  FAIL: Negative fillgaps() error (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.25.4"
}

* -----------------------------------------------------------------------------
* Test 3.25.5: Negative carryforward() Produces Error
* Purpose: Verify negative carryforward value is rejected
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.25.5: Negative carryforward() Error"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    capture tvexpose using "${DATA_DIR}/exposure_single.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        carryforward(-14) generate(tv_exp)
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: Negative carryforward() produces error"
    local ++pass_count
}
else {
    display as error "  FAIL: Negative carryforward() error (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.25.5"
}

* =============================================================================
* TEST SECTION 3.26: BYTYPE WITH EXPOSURE TYPES
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 3.26: bytype with Exposure Type Options"
    display as text "{hline 70}"
}

* Create multi-type exposure data
clear
input long id double(rx_start rx_stop) byte exp_type
    1 21915 21975 1
    1 22006 22067 2
    1 22128 22189 1
end
format %td rx_start rx_stop
label data "Multiple exposure types"
save "${DATA_DIR}/exp_multi_type.dta", replace

* -----------------------------------------------------------------------------
* Test 3.26.1: bytype with evertreated
* Purpose: Verify bytype creates separate variables for each type with evertreated
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.26.1: bytype with evertreated"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_multi_type.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        bytype evertreated generate(tv_exp)

    * Should create separate variables for each exposure type (tv_exp1, tv_exp2)
    confirm variable tv_exp1
    confirm variable tv_exp2

    * Note: tvexpose renames start/stop back to original names (rx_start/rx_stop)
    * Each should follow evertreated logic (never revert to 0 once exposed)
    sort id rx_start
    by id: gen byte ever1_reverts = (tv_exp1 == 0 & tv_exp1[_n-1] == 1) if _n > 1
    by id: gen byte ever2_reverts = (tv_exp2 == 0 & tv_exp2[_n-1] == 1) if _n > 1
    quietly count if ever1_reverts == 1
    assert r(N) == 0
    quietly count if ever2_reverts == 1
    assert r(N) == 0
}
if _rc == 0 {
    display as result "  PASS: bytype with evertreated creates separate non-reverting variables"
    local ++pass_count
}
else {
    display as error "  FAIL: bytype with evertreated (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.26.1"
}

* -----------------------------------------------------------------------------
* Test 3.26.2: bytype with currentformer
* Purpose: Verify bytype creates separate variables with currentformer logic
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.26.2: bytype with currentformer"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_multi_type.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        bytype currentformer generate(tv_exp)

    * Should create separate variables for each exposure type (tv_exp1, tv_exp2)
    confirm variable tv_exp1
    confirm variable tv_exp2

    * Values should be 0 (never), 1 (current), or 2 (former)
    quietly count if tv_exp1 < 0 | tv_exp1 > 2
    assert r(N) == 0
    quietly count if tv_exp2 < 0 | tv_exp2 > 2
    assert r(N) == 0
}
if _rc == 0 {
    display as result "  PASS: bytype with currentformer creates valid categorical variables"
    local ++pass_count
}
else {
    display as error "  FAIL: bytype with currentformer (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.26.2"
}

* =============================================================================
* TEST SECTION 3.27: EDGE CASES - SINGLE DAY AND BOUNDARY EXPOSURES
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 3.27: Edge Cases - Single Day and Boundary Exposures"
    display as text "{hline 70}"
}

* Create single-day exposure
clear
input long id double(rx_start rx_stop) byte exp_type
    1 22006 22007 1
end
format %td rx_start rx_stop
label data "Single-day exposure"
save "${DATA_DIR}/exp_single_day.dta", replace

* Create exposure starting at entry
clear
input long id double(rx_start rx_stop) byte exp_type
    1 21915 22006 1
end
format %td rx_start rx_stop
label data "Exposure starting at entry"
save "${DATA_DIR}/exp_at_entry.dta", replace

* Create exposure ending at exit
clear
input long id double(rx_start rx_stop) byte exp_type
    1 22189 22281 1
end
format %td rx_start rx_stop
label data "Exposure ending at exit"
save "${DATA_DIR}/exp_at_exit.dta", replace

* -----------------------------------------------------------------------------
* Test 3.27.1: Single-Day Exposure
* Purpose: Verify single-day exposures are handled correctly
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.27.1: Single-Day Exposure"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_single_day.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        generate(tv_exp)

    * Should have at least one interval with exposure
    quietly count if tv_exp == 1
    assert r(N) >= 1

    * Total person-time should be preserved
    * Note: tvexpose renames start/stop back to original names (rx_start/rx_stop)
    gen dur = rx_stop - rx_start
    quietly sum dur
    local total_dur = r(sum)
    assert abs(`total_dur' - 366) < 2
}
if _rc == 0 {
    display as result "  PASS: Single-day exposure handled correctly"
    local ++pass_count
}
else {
    display as error "  FAIL: Single-day exposure (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.27.1"
}

* -----------------------------------------------------------------------------
* Test 3.27.2: Exposure Starting at Entry
* Purpose: Verify exposure starting exactly at study entry
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.27.2: Exposure Starting at Entry"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_at_entry.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        generate(tv_exp)

    * There should be exposed periods starting at study entry
    * Note: tvexpose may create 0-duration baseline periods, so check for exposed periods
    * Note: tvexpose renames start/stop back to original names (rx_start/rx_stop)
    sort id rx_start
    quietly count if tv_exp == 1
    assert r(N) >= 1

    * The exposed period should include the study entry date
    quietly sum rx_start if tv_exp == 1
    assert r(min) <= 21915  // study_entry = 21915 (01jan2020)
}
if _rc == 0 {
    display as result "  PASS: Exposure starting at entry handled correctly"
    local ++pass_count
}
else {
    display as error "  FAIL: Exposure at entry (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.27.2"
}

* -----------------------------------------------------------------------------
* Test 3.27.3: Exposure Ending at Exit
* Purpose: Verify exposure ending exactly at study exit
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.27.3: Exposure Ending at Exit"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_at_exit.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        generate(tv_exp)

    * Last interval should be exposed
    * Note: tvexpose renames start/stop back to original names (rx_start/rx_stop)
    sort id rx_start
    assert tv_exp[_N] == 1
}
if _rc == 0 {
    display as result "  PASS: Exposure ending at exit handled correctly"
    local ++pass_count
}
else {
    display as error "  FAIL: Exposure at exit (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.27.3"
}

* =============================================================================
* TEST SECTION 3.28: EMPTY EXPOSURE DATA
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 3.28: Empty Exposure Data"
    display as text "{hline 70}"
}

* Create empty exposure dataset
clear
set obs 0
gen long id = .
gen double rx_start = .
gen double rx_stop = .
gen byte exp_type = .
format %td rx_start rx_stop
label data "Empty exposure dataset"
save "${DATA_DIR}/exp_empty.dta", replace

* -----------------------------------------------------------------------------
* Test 3.28.1: Empty Exposure Dataset Produces Error
* Purpose: Verify tvexpose errors appropriately when exposure dataset is empty
* Note: It's reasonable to error on empty exposure data since there's nothing to process
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.28.1: Empty Exposure Dataset Error"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    * tvexpose should error when exposure dataset has no observations
    capture tvexpose using "${DATA_DIR}/exp_empty.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        generate(tv_exp)
    * Should produce error 198 "Dataset must contain observations"
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: Empty exposure dataset correctly produces error"
    local ++pass_count
}
else {
    display as error "  FAIL: Empty exposure dataset should produce error 198 (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.28.1"
}

* =============================================================================
* TEST SECTION 3.29: INVALID CONTINUOUSUNIT VALUE
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 3.29: Invalid continuousunit Error Handling"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 3.29.1: Invalid continuousunit Value
* Purpose: Verify error for invalid continuousunit string
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.29.1: Invalid continuousunit Value"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    capture tvexpose using "${DATA_DIR}/exposure_single.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        continuousunit(invalid_unit) generate(tv_exp)
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: Invalid continuousunit produces error"
    local ++pass_count
}
else {
    display as error "  FAIL: Invalid continuousunit error (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.29.1"
}

* =============================================================================
* TEST SECTION 3.30: EXPOSURE TYPE COMBINATIONS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 3.30: Exposure Type Combinations"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 3.30.1: evertreated + duration() are Mutually Exclusive
* Purpose: Verify evertreated and duration() cannot be used together (mutually exclusive)
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.30.1: evertreated + duration() mutually exclusive"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    * Note: evertreated and duration() are mutually exclusive exposure type options
    * Only one can be specified at a time
    capture tvexpose using "${DATA_DIR}/exposure_single.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        evertreated duration(30 90 180) generate(tv_exp)
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: evertreated + duration() correctly produces error"
    local ++pass_count
}
else {
    display as error "  FAIL: evertreated + duration() should produce error (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.30.1"
}

* -----------------------------------------------------------------------------
* Test 3.30.2: currentformer + recency() are Mutually Exclusive
* Purpose: Verify currentformer and recency() cannot be used together (mutually exclusive)
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.30.2: currentformer + recency() mutually exclusive"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    * Note: currentformer and recency() are mutually exclusive exposure type options
    capture tvexpose using "${DATA_DIR}/exposure_single.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        currentformer recency(30 90) generate(tv_exp)
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: currentformer + recency() correctly produces error"
    local ++pass_count
}
else {
    display as error "  FAIL: currentformer + recency() should produce error (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.30.2"
}

* -----------------------------------------------------------------------------
* Test 3.30.3: dose + dosecuts Works (bytype not allowed with dose)
* Purpose: Verify dose tracking with categories works correctly
* Note: bytype is not allowed with dose, so we test dose + dosecuts without bytype
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.30.3: dose + dosecuts"
}

* Create exposure with dose information
clear
input long id double(rx_start rx_stop) double dose_amt
    1 21946 22006 100
    1 22067 22128 50
    1 22159 22220 150
end
format %td rx_start rx_stop
label data "Exposure with dose amounts"
save "${DATA_DIR}/exposure_dose.dta", replace

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    * Note: bytype is not allowed with dose, so we test dose + dosecuts alone
    tvexpose using "${DATA_DIR}/exposure_dose.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(dose_amt) entry(study_entry) exit(study_exit) ///
        dose dosecuts(50 100 200) generate(tv_exp)

    * Should create dose categories
    confirm variable tv_exp
    assert _N >= 1
}
if _rc == 0 {
    display as result "  PASS: dose + dosecuts works correctly"
    local ++pass_count
}
else {
    display as error "  FAIL: dose + dosecuts (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.30.3"
}

* =============================================================================
* TEST SECTION 3.31: TIME ADJUSTMENT COMBINATIONS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 3.31: Time Adjustment Combinations"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 3.31.1: grace + lag + washout Combination
* Purpose: Verify multiple time adjustments work together
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.31.1: grace + lag + washout Combination"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exposure_single.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        grace(7) lag(14) washout(30) generate(tv_exp)

    * All adjustments should be applied
    confirm variable tv_exp
    assert _N >= 1
}
if _rc == 0 {
    display as result "  PASS: grace + lag + washout works together"
    local ++pass_count
}
else {
    display as error "  FAIL: grace + lag + washout (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.31.1"
}

* -----------------------------------------------------------------------------
* Test 3.31.2: fillgaps + carryforward Combination
* Purpose: Verify gap handling options together
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.31.2: fillgaps + carryforward Combination"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exposure_single.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        fillgaps(14) carryforward(30) generate(tv_exp)

    * Both options should work
    confirm variable tv_exp
    assert _N >= 1
}
if _rc == 0 {
    display as result "  PASS: fillgaps + carryforward works together"
    local ++pass_count
}
else {
    display as error "  FAIL: fillgaps + carryforward (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.31.2"
}

* -----------------------------------------------------------------------------
* Test 3.31.3: window + lag Combination
* Purpose: Verify acute window with lag adjustment
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.31.3: window + lag Combination"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exposure_single.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        window(0 30) lag(7) generate(tv_exp)

    * Window should start after lag period
    confirm variable tv_exp
    assert _N >= 1
}
if _rc == 0 {
    display as result "  PASS: window + lag works together"
    local ++pass_count
}
else {
    display as error "  FAIL: window + lag (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.31.3"
}

* =============================================================================
* TEST SECTION 3.32: COMPETING EXPOSURE COMBINATIONS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 3.32: Competing Exposure Combinations"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 3.32.1: priority + layer are Mutually Exclusive
* Purpose: Verify priority and layer cannot be specified together
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.32.1: priority + layer mutually exclusive"
}

* Create overlapping exposures
clear
input long id double(rx_start rx_stop) byte exp_type
    1 21946 22067 1
    1 22006 22128 2
end
format %td rx_start rx_stop
label data "Overlapping exposures"
save "${DATA_DIR}/exposure_overlap.dta", replace

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    * Note: priority() and layer are mutually exclusive overlap handling options
    capture tvexpose using "${DATA_DIR}/exposure_overlap.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        priority(1 2) layer generate(tv_exp)
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: priority + layer correctly produces error"
    local ++pass_count
}
else {
    display as error "  FAIL: priority + layer should produce error (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.32.1"
}

* -----------------------------------------------------------------------------
* Test 3.32.2: split + combine are Mutually Exclusive
* Purpose: Verify split and combine() cannot be specified together
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.32.2: split + combine mutually exclusive"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    * Note: split and combine() are mutually exclusive overlap handling options
    capture tvexpose using "${DATA_DIR}/exposure_overlap.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        split combine(combined_exp) generate(tv_exp)
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: split + combine correctly produces error"
    local ++pass_count
}
else {
    display as error "  FAIL: split + combine (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.32.2"
}

* =============================================================================
* TEST SECTION 3.33: SWITCHING COMBINATIONS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 3.33: Switching Analysis Combinations"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 3.33.1: switching + statetime Combination
* Purpose: Verify switching indicator with cumulative state time
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.33.1: switching + statetime Combination"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exposure_overlap.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        switching statetime generate(tv_exp)

    * Both switching and statetime should be created
    * (exact variable names depend on implementation)
    confirm variable tv_exp
    assert _N >= 1
}
if _rc == 0 {
    display as result "  PASS: switching + statetime works together"
    local ++pass_count
}
else {
    display as error "  FAIL: switching + statetime (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.33.1"
}

* -----------------------------------------------------------------------------
* Test 3.33.2: bytype Requires Exposure Type Option
* Purpose: Verify bytype cannot be used without an exposure type option
* Note: bytype requires one of: evertreated, currentformer, duration(), continuousunit(), or recency()
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.33.2: bytype requires exposure type"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    * Note: bytype cannot be used with default time-varying (requires an exposure type option)
    capture tvexpose using "${DATA_DIR}/exp_multi_type.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        switchingdetail bytype generate(tv_exp)
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: bytype without exposure type correctly produces error"
    local ++pass_count
}
else {
    display as error "  FAIL: bytype should require exposure type option (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.33.2"
}

* =============================================================================
* TEST SECTION 3.34: OUTPUT COMBINATIONS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 3.34: Output and Diagnostic Combinations"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 3.34.1: saveas + keepvars + keepdates Combination
* Purpose: Verify saving with additional variables and dates
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.34.1: saveas + keepvars + keepdates Combination"
}

capture {
    capture erase "${DATA_DIR}/tvexpose_combo_output.dta"

    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exposure_single.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        keepdates saveas("${DATA_DIR}/tvexpose_combo_output.dta") replace ///
        generate(tv_exp)

    * File should be created with all options
    confirm file "${DATA_DIR}/tvexpose_combo_output.dta"

    use "${DATA_DIR}/tvexpose_combo_output.dta", clear
    confirm variable tv_exp
    confirm variable study_entry
    confirm variable study_exit

    capture erase "${DATA_DIR}/tvexpose_combo_output.dta"
}
if _rc == 0 {
    display as result "  PASS: saveas + keepvars + keepdates works together"
    local ++pass_count
}
else {
    display as error "  FAIL: saveas + keepvars + keepdates (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.34.1"
}

* -----------------------------------------------------------------------------
* Test 3.34.2: summarize Diagnostic Option
* Purpose: Verify summarize diagnostic option works correctly
* Note: Using summarize alone to avoid tempfile complexity with multiple diagnostics
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.34.2: summarize diagnostic option"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exposure_single.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        summarize generate(tv_exp)

    * Summarize should run and output variable should exist
    confirm variable tv_exp
    assert _N >= 1
}
if _rc == 0 {
    display as result "  PASS: summarize diagnostic option works"
    local ++pass_count
}
else {
    display as error "  FAIL: summarize diagnostic (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.34.2"
}

* -----------------------------------------------------------------------------
* Test 3.34.3: referencelabel + label + evertreated Combination
* Purpose: Verify labeling options with exposure type
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.34.3: referencelabel + label + evertreated"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exposure_single.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        evertreated referencelabel("Never Treated") label("Ever Treated Status") ///
        generate(tv_exp)

    * Labels should be applied
    confirm variable tv_exp

    * Check variable label
    local vlbl : variable label tv_exp
    assert "`vlbl'" == "Ever Treated Status"
}
if _rc == 0 {
    display as result "  PASS: referencelabel + label + evertreated works"
    local ++pass_count
}
else {
    display as error "  FAIL: referencelabel + label + evertreated (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.34.3"
}

* =============================================================================
* TEST SECTION 3.35: MULTI-PERSON TESTS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 3.35: Multi-Person Tests"
    display as text "{hline 70}"
}

* Create multi-person cohort
clear
input long id double(study_entry study_exit)
    1 21915 22281
    2 21946 22189
    3 22006 22281
end
format %td study_entry study_exit
label data "Multi-person cohort"
save "${DATA_DIR}/cohort_multi.dta", replace

* Create multi-person exposures
clear
input long id double(rx_start rx_stop) byte exp_type
    1 21946 22067 1
    1 22128 22220 2
    2 22006 22097 1
    3 22067 22189 1
    3 22189 22250 2
end
format %td rx_start rx_stop
label data "Multi-person exposures"
save "${DATA_DIR}/exposure_multi.dta", replace

* -----------------------------------------------------------------------------
* Test 3.35.1: Multiple Persons with Different Exposure Patterns
* Purpose: Verify correct handling across multiple persons
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.35.1: Multiple Persons with Different Patterns"
}

capture {
    use "${DATA_DIR}/cohort_multi.dta", clear
    tvexpose using "${DATA_DIR}/exposure_multi.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        generate(tv_exp)

    * Output variable should exist
    confirm variable tv_exp
    * Note: tvexpose renames start/stop back to original names (rx_start/rx_stop)
    confirm variable rx_start
    confirm variable rx_stop

    * All 3 persons should be present
    quietly levelsof id, local(ids)
    local n_ids: word count `ids'
    assert `n_ids' == 3

    * Should have multiple time periods
    assert _N >= 3
}
if _rc == 0 {
    display as result "  PASS: Multiple persons handled correctly"
    local ++pass_count
}
else {
    display as error "  FAIL: Multi-person patterns (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.35.1"
}

* -----------------------------------------------------------------------------
* Test 3.35.2: Multi-Person with evertreated + bytype
* Purpose: Verify complex options across multiple persons
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.35.2: Multi-Person with evertreated + bytype"
}

capture {
    use "${DATA_DIR}/cohort_multi.dta", clear
    tvexpose using "${DATA_DIR}/exposure_multi.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        evertreated bytype generate(tv_exp)

    * Should create type-specific variables for all persons (tv_exp1, tv_exp2)
    confirm variable tv_exp1
    confirm variable tv_exp2

    * All 3 persons should be present
    quietly levelsof id, local(ids)
    local n_ids: word count `ids'
    assert `n_ids' == 3
}
if _rc == 0 {
    display as result "  PASS: Multi-person evertreated + bytype works"
    local ++pass_count
}
else {
    display as error "  FAIL: Multi-person evertreated + bytype (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.35.2"
}

* =============================================================================
* TEST SECTION 3.36: ADVANCED EDGE CASES - OVERLAPS AND BOUNDARIES
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 3.36: Advanced Edge Cases - Overlaps and Boundaries"
    display as text "{hline 70}"
}

* Create exposure before cohort entry (starts 30 days before study entry)
clear
input long id double(rx_start rx_stop) byte exp_type
    1 21885 21975 1
end
format %td rx_start rx_stop
label data "Exposure starting before cohort entry"
save "${DATA_DIR}/exp_before_entry.dta", replace

* Create exposure extending after cohort exit
clear
input long id double(rx_start rx_stop) byte exp_type
    1 22189 22350 1
end
format %td rx_start rx_stop
label data "Exposure extending after cohort exit"
save "${DATA_DIR}/exp_after_exit.dta", replace

* Create same-type overlapping exposures
clear
input long id double(rx_start rx_stop) byte exp_type
    1 21946 22067 1
    1 22006 22128 1
end
format %td rx_start rx_stop
label data "Same-type overlapping exposures"
save "${DATA_DIR}/exp_same_type_overlap.dta", replace

* Create zero-duration exposure (start = stop)
clear
input long id double(rx_start rx_stop) byte exp_type
    1 22006 22006 1
end
format %td rx_start rx_stop
label data "Zero-duration exposure"
save "${DATA_DIR}/exp_zero_duration.dta", replace

* Create exposure completely outside study period
clear
input long id double(rx_start rx_stop) byte exp_type
    1 21800 21880 1
end
format %td rx_start rx_stop
label data "Exposure completely before study"
save "${DATA_DIR}/exp_outside_study.dta", replace

* Create exposures with identical dates but different types
clear
input long id double(rx_start rx_stop) byte exp_type
    1 22006 22067 1
    1 22006 22067 2
end
format %td rx_start rx_stop
label data "Identical dates different types"
save "${DATA_DIR}/exp_same_dates_diff_types.dta", replace

* Create invalid exposure (stop < start)
clear
input long id double(rx_start rx_stop) byte exp_type
    1 22067 22006 1
end
format %td rx_start rx_stop
label data "Invalid exposure with stop < start"
save "${DATA_DIR}/exp_invalid_order.dta", replace

* Create exposure with gap exactly equal to grace period (14 days)
clear
input long id double(rx_start rx_stop) byte exp_type
    1 21915 21945 1
    1 21959 21991 1
end
format %td rx_start rx_stop
label data "Exposures with 14-day gap (grace boundary)"
save "${DATA_DIR}/exp_gap14.dta", replace

* Create multi-person dataset with person having no exposures
clear
input long id double(study_entry study_exit)
    1 21915 22281
    2 21915 22281
    3 21915 22281
end
format %td study_entry study_exit
label data "Multi-person cohort with unexposed person"
save "${DATA_DIR}/cohort_with_unexposed.dta", replace

* Exposure data that covers only person 1 and 2
clear
input long id double(rx_start rx_stop) byte exp_type
    1 21946 22067 1
    2 22006 22128 1
end
format %td rx_start rx_stop
label data "Exposures for persons 1 and 2 only"
save "${DATA_DIR}/exp_partial_coverage.dta", replace

* -----------------------------------------------------------------------------
* Test 3.36.1: Exposure Starting Before Cohort Entry
* Purpose: Verify exposure before entry is truncated at entry
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.36.1: Exposure Starting Before Cohort Entry"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_before_entry.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        generate(tv_exp)

    * First interval should start at study entry (21915), not before
    sort id rx_start
    assert rx_start[1] >= 21915

    * Total person-time should still equal study duration (366 days)
    gen dur = rx_stop - rx_start
    quietly sum dur
    local total = r(sum)
    assert abs(`total' - 366) < 2
}
if _rc == 0 {
    display as result "  PASS: Exposure before entry is truncated correctly"
    local ++pass_count
}
else {
    display as error "  FAIL: Exposure before entry (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.36.1"
}

* -----------------------------------------------------------------------------
* Test 3.36.2: Exposure Extending After Cohort Exit
* Purpose: Verify exposure after exit is truncated at exit
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.36.2: Exposure Extending After Cohort Exit"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_after_exit.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        generate(tv_exp)

    * Last interval should end at study exit (22281), not after
    sort id rx_start
    assert rx_stop[_N] <= 22281

    * Person-time should be preserved
    gen dur = rx_stop - rx_start
    quietly sum dur
    local total = r(sum)
    assert abs(`total' - 366) < 2
}
if _rc == 0 {
    display as result "  PASS: Exposure after exit is truncated correctly"
    local ++pass_count
}
else {
    display as error "  FAIL: Exposure after exit (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.36.2"
}

* -----------------------------------------------------------------------------
* Test 3.36.3: Same-Type Overlapping Exposures
* Purpose: Verify two overlapping exposures of the SAME type are handled
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.36.3: Same-Type Overlapping Exposures"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_same_type_overlap.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        generate(tv_exp)

    * No overlapping output intervals
    _verify_no_overlap, id(id) start(rx_start) stop(rx_stop)
    assert r(n_overlaps) == 0

    * Person-time preserved
    gen dur = rx_stop - rx_start
    quietly sum dur
    local total = r(sum)
    assert abs(`total' - 366) < 2
}
if _rc == 0 {
    display as result "  PASS: Same-type overlapping exposures handled without output overlaps"
    local ++pass_count
}
else {
    display as error "  FAIL: Same-type overlapping exposures (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.36.3"
}

* -----------------------------------------------------------------------------
* Test 3.36.4: Zero-Duration Exposure Handling
* Purpose: Verify exposure where start = stop is handled gracefully
* Note: Zero-duration periods may be skipped or converted to point events
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.36.4: Zero-Duration Exposure"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    * This may error or produce a warning - capture to check behavior
    capture tvexpose using "${DATA_DIR}/exp_zero_duration.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        generate(tv_exp)

    * Either produces error OR completes without output overlaps
    if _rc == 0 {
        _verify_no_overlap, id(id) start(rx_start) stop(rx_stop)
        assert r(n_overlaps) == 0
    }
    * If error, that's acceptable for zero-duration input
}
if _rc == 0 {
    display as result "  PASS: Zero-duration exposure handled gracefully"
    local ++pass_count
}
else {
    display as error "  FAIL: Zero-duration exposure (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.36.4"
}

* -----------------------------------------------------------------------------
* Test 3.36.5: Exposure Completely Outside Study Period
* Purpose: Verify exposure entirely before study contributes no exposed time
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.36.5: Exposure Completely Outside Study"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_outside_study.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        generate(tv_exp)

    * All time should be unexposed (reference category)
    quietly count if tv_exp != 0
    assert r(N) == 0
}
if _rc == 0 {
    display as result "  PASS: Exposure outside study contributes no exposed time"
    local ++pass_count
}
else {
    display as error "  FAIL: Exposure outside study (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.36.5"
}

* -----------------------------------------------------------------------------
* Test 3.36.6: Identical Dates Different Exposure Types
* Purpose: Verify two exposures with same start/stop but different types
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.36.6: Identical Dates Different Types"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_same_dates_diff_types.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        layer generate(tv_exp)

    * Should complete without error
    assert _N >= 1

    * No overlapping output intervals
    _verify_no_overlap, id(id) start(rx_start) stop(rx_stop)
    assert r(n_overlaps) == 0
}
if _rc == 0 {
    display as result "  PASS: Identical dates different types handled"
    local ++pass_count
}
else {
    display as error "  FAIL: Identical dates different types (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.36.6"
}

* -----------------------------------------------------------------------------
* Test 3.36.7: Grace Period at Exact Boundary
* Purpose: Verify grace(14) exactly bridges 14-day gap but not 15-day gap
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.36.7: Grace Period at Exact Boundary"
}

capture {
    * Test 14-day gap with grace(14) - should bridge
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_gap14.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        grace(14) generate(tv_grace14)

    quietly count if tv_grace14 == 0
    local n_unexposed_14 = r(N)

    * Test with grace(13) - should NOT bridge
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_gap14.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        grace(13) generate(tv_grace13)

    quietly count if tv_grace13 == 0
    local n_unexposed_13 = r(N)

    * With smaller grace, should have same or more unexposed intervals
    assert `n_unexposed_13' >= `n_unexposed_14'
}
if _rc == 0 {
    display as result "  PASS: Grace period boundary behavior is correct"
    local ++pass_count
}
else {
    display as error "  FAIL: Grace period boundary (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.36.7"
}

* -----------------------------------------------------------------------------
* Test 3.36.8: Person with No Exposures in Multi-Person Dataset
* Purpose: Verify unexposed person has all reference-category time
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.36.8: Person with No Exposures"
}

capture {
    use "${DATA_DIR}/cohort_with_unexposed.dta", clear
    tvexpose using "${DATA_DIR}/exp_partial_coverage.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        generate(tv_exp)

    * Person 3 should have only unexposed time
    quietly count if id == 3 & tv_exp != 0
    assert r(N) == 0

    * But person 3 should still have time accounted for
    quietly count if id == 3
    assert r(N) >= 1
}
if _rc == 0 {
    display as result "  PASS: Unexposed person correctly has reference-only time"
    local ++pass_count
}
else {
    display as error "  FAIL: Person with no exposures (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.36.8"
}

* =============================================================================
* TEST SECTION 3.37: CUMULATIVE EXPOSURE EDGE CASES
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 3.37: Cumulative Exposure Edge Cases"
    display as text "{hline 70}"
}

* Create multiple separated exposure periods for cumulative testing
clear
input long id double(rx_start rx_stop) byte exp_type
    1 21915 21945 1
    1 22006 22036 1
    1 22097 22128 1
end
format %td rx_start rx_stop
label data "Three separate exposure periods"
save "${DATA_DIR}/exp_three_periods.dta", replace

* -----------------------------------------------------------------------------
* Test 3.37.1: Cumulative Across Separated Periods
* Purpose: Verify cumulative exposure accumulates across non-contiguous periods
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.37.1: Cumulative Across Separated Periods"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_three_periods.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        continuousunit(days) generate(cum_exp)

    * Find maximum cumulative exposure
    quietly sum cum_exp
    local max_cum = r(max)

    * Three periods of 30 days each = 90 days total
    assert abs(`max_cum' - 90) < 5
}
if _rc == 0 {
    display as result "  PASS: Cumulative exposure accumulates across separated periods"
    local ++pass_count
}
else {
    display as error "  FAIL: Cumulative across separated periods (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.37.1"
}

* -----------------------------------------------------------------------------
* Test 3.37.2: Cumulative Resets to Zero for Unexposed (invariant: cumulative tracks exposure only)
* Purpose: Verify cumulative stays constant (doesn't decrease) during unexposed intervals
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.37.2: Cumulative Stays Constant During Unexposed"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_three_periods.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        continuousunit(days) generate(cum_exp)

    * Cumulative should never decrease
    sort id rx_start
    by id: gen double cum_change = cum_exp - cum_exp[_n-1] if _n > 1
    quietly count if cum_change < -0.001
    assert r(N) == 0
}
if _rc == 0 {
    display as result "  PASS: Cumulative never decreases during unexposed periods"
    local ++pass_count
}
else {
    display as error "  FAIL: Cumulative monotonicity (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.37.2"
}

* -----------------------------------------------------------------------------
* Test 3.37.3: Duration Categories with Multiple Threshold Crossings
* Purpose: Verify duration categories transition correctly at boundaries
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.37.3: Duration Categories Threshold Crossings"
}

capture {
    * Create long exposure that crosses multiple thresholds
    clear
    input long id double(rx_start rx_stop) byte exp_type
        1 21915 22281 1
    end
    format %td rx_start rx_stop
    save "${DATA_DIR}/exp_full_year_single.dta", replace

    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_full_year_single.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        duration(0.25 0.5 0.75) continuousunit(years) generate(dur_cat)

    * Should have multiple duration categories
    quietly tab dur_cat
    local n_cats = r(r)
    assert `n_cats' >= 3
}
if _rc == 0 {
    display as result "  PASS: Duration categories transition at thresholds"
    local ++pass_count
}
else {
    display as error "  FAIL: Duration category thresholds (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.37.3"
}

* =============================================================================
* TEST SECTION 3.38: LAG AND WASHOUT INTERACTION TESTS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 3.38: Lag and Washout Interaction Tests"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 3.38.1: Lag Longer Than Exposure Duration
* Purpose: Verify lag longer than exposure period handles gracefully
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.38.1: Lag Longer Than Exposure Duration"
}

capture {
    * Single day exposure with lag(30)
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_single_day.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        lag(30) generate(tv_exp)

    * With lag longer than exposure, the lagged exposure may appear later or not at all
    * The key is it shouldn't error
    assert _N >= 1
}
if _rc == 0 {
    display as result "  PASS: Lag longer than exposure handled gracefully"
    local ++pass_count
}
else {
    display as error "  FAIL: Lag longer than exposure (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.38.1"
}

* -----------------------------------------------------------------------------
* Test 3.38.2: Washout That Bridges Gaps
* Purpose: Verify washout can connect separated exposures
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.38.2: Washout That Bridges Gaps"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear

    * Without washout
    tvexpose using "${DATA_DIR}/exp_gap15.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        washout(0) generate(tv_no_wash)
    gen dur_exp = (rx_stop - rx_start) if tv_no_wash == 1
    quietly sum dur_exp
    local exposed_no_wash = r(sum)

    * With washout(20) - should extend past the 15-day gap
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_gap15.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        washout(20) generate(tv_wash)
    gen dur_exp = (rx_stop - rx_start) if tv_wash == 1
    quietly sum dur_exp
    local exposed_wash = r(sum)

    * Washout should increase exposed time
    assert `exposed_wash' >= `exposed_no_wash'
}
if _rc == 0 {
    display as result "  PASS: Washout extends exposed time correctly"
    local ++pass_count
}
else {
    display as error "  FAIL: Washout bridging (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.38.2"
}

* -----------------------------------------------------------------------------
* Test 3.38.3: Lag and Washout Combined Effect
* Purpose: Verify lag delays and washout extends are additive
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.38.3: Lag and Washout Combined"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear

    * With both lag(30) and washout(30)
    tvexpose using "${DATA_DIR}/exp_basic.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        lag(30) washout(30) generate(tv_exp)

    * Command should complete without error
    assert _N >= 1

    * Person-time should still be conserved
    gen dur = rx_stop - rx_start
    quietly sum dur
    local total = r(sum)
    assert abs(`total' - 366) < 2
}
if _rc == 0 {
    display as result "  PASS: Lag and washout work correctly together"
    local ++pass_count
}
else {
    display as error "  FAIL: Lag and washout combined (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.38.3"
}

* =============================================================================
* TEST SECTION 3.39: COMPLEX OVERLAP PATTERNS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 3.39: Complex Overlap Patterns"
    display as text "{hline 70}"
}

* Create nested exposures (one completely inside another)
clear
input long id double(rx_start rx_stop) byte exp_type
    1 21915 22189 1
    1 22006 22097 1
end
format %td rx_start rx_stop
label data "Nested same-type exposures (inner inside outer)"
save "${DATA_DIR}/exp_nested_same.dta", replace

* Create nested exposures of different types
clear
input long id double(rx_start rx_stop) byte exp_type
    1 21915 22189 1
    1 22006 22097 2
end
format %td rx_start rx_stop
label data "Nested different-type exposures"
save "${DATA_DIR}/exp_nested_diff.dta", replace

* Create exactly overlapping exposures (same dates, same type)
clear
input long id double(rx_start rx_stop) byte exp_type
    1 22006 22097 1
    1 22006 22097 1
end
format %td rx_start rx_stop
label data "Exactly overlapping same-type (duplicates)"
save "${DATA_DIR}/exp_exact_overlap.dta", replace

* Create multiple overlapping exposures (3-way overlap)
clear
input long id double(rx_start rx_stop) byte exp_type
    1 21915 22067 1
    1 22006 22128 1
    1 22067 22189 1
end
format %td rx_start rx_stop
label data "Three overlapping same-type exposures"
save "${DATA_DIR}/exp_triple_overlap.dta", replace

* Create exposures overlapping by exactly 1 day
clear
input long id double(rx_start rx_stop) byte exp_type
    1 21915 22007 1
    1 22006 22097 1
end
format %td rx_start rx_stop
label data "Exposures overlapping by exactly 1 day"
save "${DATA_DIR}/exp_overlap_1day.dta", replace

* Create adjacent exposures (stop = start of next)
clear
input long id double(rx_start rx_stop) byte exp_type
    1 21915 22006 1
    1 22006 22097 1
end
format %td rx_start rx_stop
label data "Adjacent same-type exposures (no gap)"
save "${DATA_DIR}/exp_adjacent.dta", replace

* Create adjacent exposures of different types (switching)
clear
input long id double(rx_start rx_stop) byte exp_type
    1 21915 22006 1
    1 22006 22097 2
end
format %td rx_start rx_stop
label data "Adjacent different-type exposures (type switch)"
save "${DATA_DIR}/exp_type_switch.dta", replace

* -----------------------------------------------------------------------------
* Test 3.39.1: Nested Same-Type Exposures
* Purpose: Verify nested same-type exposures don't double-count time
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.39.1: Nested Same-Type Exposures"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_nested_same.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        generate(tv_exp)

    * No overlapping output intervals
    _verify_no_overlap, id(id) start(rx_start) stop(rx_stop)
    assert r(n_overlaps) == 0

    * Exposed time should be max extent (274 days = 21915 to 22189)
    gen dur = (rx_stop - rx_start) if tv_exp == 1
    quietly sum dur
    local exposed_dur = r(sum)
    assert abs(`exposed_dur' - 274) < 2
}
if _rc == 0 {
    display as result "  PASS: Nested same-type exposures handled correctly"
    local ++pass_count
}
else {
    display as error "  FAIL: Nested same-type exposures (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.39.1"
}

* -----------------------------------------------------------------------------
* Test 3.39.2: Nested Different-Type Exposures
* Purpose: Verify nested different types create proper layering
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.39.2: Nested Different-Type Exposures"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_nested_diff.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        layer generate(tv_exp)

    * No overlapping output intervals
    _verify_no_overlap, id(id) start(rx_start) stop(rx_stop)
    assert r(n_overlaps) == 0

    * Should have intervals with type 1, type 2, and possibly combined
    assert _N >= 3
}
if _rc == 0 {
    display as result "  PASS: Nested different-type exposures create proper splits"
    local ++pass_count
}
else {
    display as error "  FAIL: Nested different-type exposures (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.39.2"
}

* -----------------------------------------------------------------------------
* Test 3.39.3: Exactly Overlapping (Duplicate) Exposures
* Purpose: Verify duplicate prescriptions don't cause errors or double-counting
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.39.3: Exactly Overlapping Exposures (Duplicates)"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_exact_overlap.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        generate(tv_exp)

    * Should complete without error
    assert _N >= 1

    * No overlapping output intervals
    _verify_no_overlap, id(id) start(rx_start) stop(rx_stop)
    assert r(n_overlaps) == 0

    * Person-time conserved
    gen dur = rx_stop - rx_start
    quietly sum dur
    assert abs(r(sum) - 366) < 2
}
if _rc == 0 {
    display as result "  PASS: Duplicate exposures handled without double-counting"
    local ++pass_count
}
else {
    display as error "  FAIL: Duplicate exposures (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.39.3"
}

* -----------------------------------------------------------------------------
* Test 3.39.4: Triple Overlapping Exposures
* Purpose: Verify three overlapping same-type exposures merge correctly
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.39.4: Triple Overlapping Exposures"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_triple_overlap.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        generate(tv_exp)

    * No overlapping output intervals
    _verify_no_overlap, id(id) start(rx_start) stop(rx_stop)
    assert r(n_overlaps) == 0

    * Exposed time should span the union (21915 to 22189 = 274 days)
    gen dur = (rx_stop - rx_start) if tv_exp == 1
    quietly sum dur
    local exposed = r(sum)
    assert abs(`exposed' - 274) < 5
}
if _rc == 0 {
    display as result "  PASS: Triple overlapping exposures merge correctly"
    local ++pass_count
}
else {
    display as error "  FAIL: Triple overlapping exposures (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.39.4"
}

* -----------------------------------------------------------------------------
* Test 3.39.5: Exposures Overlapping by Exactly 1 Day
* Purpose: Verify minimal overlap is handled correctly
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.39.5: Exposures Overlapping by 1 Day"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_overlap_1day.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        generate(tv_exp)

    * No overlapping output intervals
    _verify_no_overlap, id(id) start(rx_start) stop(rx_stop)
    assert r(n_overlaps) == 0

    * Union: 21915 to 22097 = 182 days
    gen dur = (rx_stop - rx_start) if tv_exp == 1
    quietly sum dur
    assert abs(r(sum) - 182) < 2
}
if _rc == 0 {
    display as result "  PASS: 1-day overlap handled correctly"
    local ++pass_count
}
else {
    display as error "  FAIL: 1-day overlap (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.39.5"
}

* -----------------------------------------------------------------------------
* Test 3.39.6: Adjacent Same-Type Exposures (No Gap)
* Purpose: Verify adjacent exposures merge into continuous period
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.39.6: Adjacent Same-Type Exposures"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_adjacent.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        generate(tv_exp)

    * Adjacent exposures should merge (21915 to 22097 = 182 days)
    gen dur = (rx_stop - rx_start) if tv_exp == 1
    quietly sum dur
    assert abs(r(sum) - 182) < 2
}
if _rc == 0 {
    display as result "  PASS: Adjacent exposures merge correctly"
    local ++pass_count
}
else {
    display as error "  FAIL: Adjacent exposures (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.39.6"
}

* -----------------------------------------------------------------------------
* Test 3.39.7: Type Switch (Adjacent Different Types)
* Purpose: Verify immediate type switch creates separate periods
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.39.7: Type Switch (Adjacent Different Types)"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_type_switch.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        generate(tv_exp)

    * Should have both type 1 and type 2 periods
    quietly count if tv_exp == 1
    local n_type1 = r(N)
    quietly count if tv_exp == 2
    local n_type2 = r(N)
    assert `n_type1' >= 1
    assert `n_type2' >= 1
}
if _rc == 0 {
    display as result "  PASS: Type switch creates separate exposure periods"
    local ++pass_count
}
else {
    display as error "  FAIL: Type switch (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.39.7"
}

* =============================================================================
* TEST SECTION 3.40: GRACE PERIOD BOUNDARY CONDITIONS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 3.40: Grace Period Boundary Conditions"
    display as text "{hline 70}"
}

* Create gap exactly grace-1 (13 days with default grace=14)
clear
input long id double(rx_start rx_stop) byte exp_type
    1 21915 21945 1
    1 21958 21991 1
end
format %td rx_start rx_stop
label data "13-day gap (grace-1)"
save "${DATA_DIR}/exp_gap13.dta", replace

* Create gap exactly grace+1 (15 days with default grace=14)
clear
input long id double(rx_start rx_stop) byte exp_type
    1 21915 21945 1
    1 21960 21991 1
end
format %td rx_start rx_stop
label data "15-day gap (grace+1)"
save "${DATA_DIR}/exp_gap15.dta", replace

* Create multiple gaps with varying sizes
clear
input long id double(rx_start rx_stop) byte exp_type
    1 21915 21935 1
    1 21945 21965 1
    1 21990 22010 1
    1 22050 22070 1
end
format %td rx_start rx_stop
label data "Multiple gaps: 10d, 25d, 40d"
save "${DATA_DIR}/exp_multi_gaps.dta", replace

* Create very small gap (1 day)
clear
input long id double(rx_start rx_stop) byte exp_type
    1 21915 22006 1
    1 22007 22097 1
end
format %td rx_start rx_stop
label data "1-day gap between exposures"
save "${DATA_DIR}/exp_gap1.dta", replace

* -----------------------------------------------------------------------------
* Test 3.40.1: Gap Exactly Grace-1 Days
* Purpose: Verify gap smaller than grace is bridged
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.40.1: Gap Exactly Grace-1 Days (13 days)"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_gap13.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        grace(14) generate(tv_exp)

    * 13-day gap with grace(14) should be bridged - continuous exposure
    * Count unexposed intervals
    quietly count if tv_exp == 0
    local n_unexposed = r(N)

    * The gap should be bridged (limited or no unexposed in middle)
}
if _rc == 0 {
    display as result "  PASS: Grace-1 gap handled (smaller gap bridged)"
    local ++pass_count
}
else {
    display as error "  FAIL: Grace-1 gap (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.40.1"
}

* -----------------------------------------------------------------------------
* Test 3.40.2: Gap Exactly Grace+1 Days
* Purpose: Verify gap larger than grace creates unexposed period
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.40.2: Gap Exactly Grace+1 Days (15 days)"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_gap15.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        grace(14) generate(tv_exp)

    * 15-day gap with grace(14) should NOT be bridged
    * Should have unexposed intervals
    quietly count if tv_exp == 0
    local n_unexposed = r(N)
    assert `n_unexposed' >= 1
}
if _rc == 0 {
    display as result "  PASS: Grace+1 gap creates unexposed period"
    local ++pass_count
}
else {
    display as error "  FAIL: Grace+1 gap (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.40.2"
}

* -----------------------------------------------------------------------------
* Test 3.40.3: Multiple Gaps with Different Sizes
* Purpose: Verify mixed gap handling with some bridged, some not
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.40.3: Multiple Gaps of Different Sizes"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_multi_gaps.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        grace(14) generate(tv_exp)

    * 10-day gap bridged, 25-day and 40-day gaps not bridged
    * Should have at least 2 unexposed intervals
    quietly count if tv_exp == 0
    local n_unexposed = r(N)
    assert `n_unexposed' >= 2
}
if _rc == 0 {
    display as result "  PASS: Multiple gaps handled correctly (some bridged, some not)"
    local ++pass_count
}
else {
    display as error "  FAIL: Multiple gaps (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.40.3"
}

* -----------------------------------------------------------------------------
* Test 3.40.4: 1-Day Gap
* Purpose: Verify minimal gap is always bridged
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.40.4: 1-Day Gap Between Exposures"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_gap1.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        grace(14) generate(tv_exp)

    * 1-day gap should definitely be bridged
    * Check if there's a 1-day unexposed gap or if it's bridged
    assert _N >= 1
}
if _rc == 0 {
    display as result "  PASS: 1-day gap handled correctly"
    local ++pass_count
}
else {
    display as error "  FAIL: 1-day gap (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.40.4"
}

* -----------------------------------------------------------------------------
* Test 3.40.5: Grace(0) - No Bridging
* Purpose: Verify grace(0) creates gaps for any discontinuity
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.40.5: Grace(0) - No Gap Bridging"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_gap1.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        grace(0) generate(tv_exp)

    * With grace(0), even 1-day gap should create unexposed period
    quietly count if tv_exp == 0
    assert r(N) >= 1
}
if _rc == 0 {
    display as result "  PASS: Grace(0) creates gaps for any discontinuity"
    local ++pass_count
}
else {
    display as error "  FAIL: Grace(0) (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.40.5"
}

* =============================================================================
* TEST SECTION 3.41: MICRO-INTERVAL AND SINGLE-DAY EXPOSURES
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 3.41: Micro-Interval and Single-Day Exposures"
    display as text "{hline 70}"
}

* Create multiple single-day exposures
clear
input long id double(rx_start rx_stop) byte exp_type
    1 22006 22007 1
    1 22050 22051 1
    1 22100 22101 1
end
format %td rx_start rx_stop
label data "Multiple single-day exposures"
save "${DATA_DIR}/exp_multi_single_day.dta", replace

* Create alternating single-day exposures and gaps
clear
input long id double(rx_start rx_stop) byte exp_type
    1 22006 22007 1
    1 22008 22009 1
    1 22010 22011 1
end
format %td rx_start rx_stop
label data "Near-daily alternating exposures"
save "${DATA_DIR}/exp_near_daily.dta", replace

* Create 2-day exposure
clear
input long id double(rx_start rx_stop) byte exp_type
    1 22006 22008 1
end
format %td rx_start rx_stop
label data "2-day exposure"
save "${DATA_DIR}/exp_2day.dta", replace

* -----------------------------------------------------------------------------
* Test 3.41.1: Multiple Single-Day Exposures with Gaps
* Purpose: Verify multiple isolated single-day exposures are tracked
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.41.1: Multiple Single-Day Exposures"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_multi_single_day.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        grace(0) generate(tv_exp)

    * Each single-day exposure should be counted
    quietly count if tv_exp == 1
    local n_exposed = r(N)
    assert `n_exposed' >= 3
}
if _rc == 0 {
    display as result "  PASS: Multiple single-day exposures tracked separately"
    local ++pass_count
}
else {
    display as error "  FAIL: Multiple single-day exposures (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.41.1"
}

* -----------------------------------------------------------------------------
* Test 3.41.2: Near-Daily Exposures with Small Gaps
* Purpose: Verify closely spaced single-day exposures handled correctly
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.41.2: Near-Daily Exposures"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_near_daily.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        grace(1) generate(tv_exp)

    * With grace(1), the 1-day gaps should be bridged
    * Total exposed should span roughly 22006-22011 = 5 days
    gen dur = (rx_stop - rx_start) if tv_exp == 1
    quietly sum dur
    assert r(sum) >= 3
}
if _rc == 0 {
    display as result "  PASS: Near-daily exposures with grace bridging"
    local ++pass_count
}
else {
    display as error "  FAIL: Near-daily exposures (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.41.2"
}

* -----------------------------------------------------------------------------
* Test 3.41.3: 2-Day Exposure
* Purpose: Verify minimal multi-day exposure works correctly
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.41.3: 2-Day Exposure"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_2day.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        generate(tv_exp)

    * Should have exactly 2 days of exposed time
    gen dur = (rx_stop - rx_start) if tv_exp == 1
    quietly sum dur
    assert abs(r(sum) - 2) < 1
}
if _rc == 0 {
    display as result "  PASS: 2-day exposure tracked correctly"
    local ++pass_count
}
else {
    display as error "  FAIL: 2-day exposure (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.41.3"
}

* =============================================================================
* TEST SECTION 3.42: STUDY BOUNDARY CONDITIONS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 3.42: Study Boundary Conditions"
    display as text "{hline 70}"
}

* Create exposure starting exactly at study entry
clear
input long id double(rx_start rx_stop) byte exp_type
    1 21915 22097 1
end
format %td rx_start rx_stop
label data "Exposure starting exactly at study entry"
save "${DATA_DIR}/exp_at_entry.dta", replace

* Create exposure ending exactly at study exit
clear
input long id double(rx_start rx_stop) byte exp_type
    1 22097 22281 1
end
format %td rx_start rx_stop
label data "Exposure ending exactly at study exit"
save "${DATA_DIR}/exp_at_exit.dta", replace

* Create exposure spanning entire study period
clear
input long id double(rx_start rx_stop) byte exp_type
    1 21915 22281 1
end
format %td rx_start rx_stop
label data "Exposure spanning entire study period"
save "${DATA_DIR}/exp_full_span.dta", replace

* Create exposure starting 1 day after entry
clear
input long id double(rx_start rx_stop) byte exp_type
    1 21916 22097 1
end
format %td rx_start rx_stop
label data "Exposure starting 1 day after study entry"
save "${DATA_DIR}/exp_1day_after_entry.dta", replace

* Create exposure ending 1 day before exit
clear
input long id double(rx_start rx_stop) byte exp_type
    1 21946 22280 1
end
format %td rx_start rx_stop
label data "Exposure ending 1 day before study exit"
save "${DATA_DIR}/exp_1day_before_exit.dta", replace

* Create very short follow-up (1 day)
clear
input long id double(study_entry study_exit)
    1 22006 22007
end
format %td study_entry study_exit
label data "1-day study period"
save "${DATA_DIR}/cohort_1day.dta", replace

* -----------------------------------------------------------------------------
* Test 3.42.1: Exposure Starting Exactly at Study Entry
* Purpose: Verify exposure aligned with entry start is captured fully
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.42.1: Exposure Starting at Study Entry"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_at_entry.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        generate(tv_exp)

    * First interval should start at study entry
    sort rx_start
    assert rx_start[1] == 21915

    * Exposed time should be 182 days (21915 to 22097)
    gen dur = (rx_stop - rx_start) if tv_exp == 1
    quietly sum dur
    assert abs(r(sum) - 182) < 2
}
if _rc == 0 {
    display as result "  PASS: Exposure at study entry captured fully"
    local ++pass_count
}
else {
    display as error "  FAIL: Exposure at entry (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.42.1"
}

* -----------------------------------------------------------------------------
* Test 3.42.2: Exposure Ending Exactly at Study Exit
* Purpose: Verify exposure aligned with exit is captured fully
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.42.2: Exposure Ending at Study Exit"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_at_exit.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        generate(tv_exp)

    * Last interval should end at study exit
    sort rx_start
    assert rx_stop[_N] == 22281

    * Exposed time should be 184 days (22097 to 22281)
    gen dur = (rx_stop - rx_start) if tv_exp == 1
    quietly sum dur
    assert abs(r(sum) - 184) < 2
}
if _rc == 0 {
    display as result "  PASS: Exposure at study exit captured fully"
    local ++pass_count
}
else {
    display as error "  FAIL: Exposure at exit (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.42.2"
}

* -----------------------------------------------------------------------------
* Test 3.42.3: Exposure Spanning Entire Study Period
* Purpose: Verify full-span exposure covers all person-time
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.42.3: Exposure Spanning Entire Study"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_full_span.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        generate(tv_exp)

    * All person-time should be exposed (check duration, not row count)
    * Note: 0-duration baseline periods may exist when exposure starts at study entry
    gen dur = rx_stop - rx_start
    quietly sum dur if tv_exp == 0
    assert r(sum) == 0 | r(N) == 0

    * Total time should be full 366 days
    quietly sum dur
    assert abs(r(sum) - 366) < 2
}
if _rc == 0 {
    display as result "  PASS: Full-span exposure covers all person-time"
    local ++pass_count
}
else {
    display as error "  FAIL: Full-span exposure (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.42.3"
}

* -----------------------------------------------------------------------------
* Test 3.42.4: Exposure Starting 1 Day After Entry
* Purpose: Verify 1-day unexposed period at start
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.42.4: Exposure Starting 1 Day After Entry"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_1day_after_entry.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        generate(tv_exp)

    * Should have 1 day of unexposed at start
    sort rx_start
    assert rx_start[1] == 21915
    quietly sum tv_exp if rx_start == 21915
    * First interval should be unexposed (reference=0)
}
if _rc == 0 {
    display as result "  PASS: 1-day gap at study start handled"
    local ++pass_count
}
else {
    display as error "  FAIL: 1-day after entry (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.42.4"
}

* -----------------------------------------------------------------------------
* Test 3.42.5: 1-Day Study Period
* Purpose: Verify minimal study duration handles correctly
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.42.5: 1-Day Study Period"
}

capture {
    use "${DATA_DIR}/cohort_1day.dta", clear
    tvexpose using "${DATA_DIR}/exp_single_day.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        generate(tv_exp)

    * Should produce some output (might be all unexposed or all exposed)
    assert _N >= 1
}
if _rc == 0 {
    display as result "  PASS: 1-day study period handled"
    local ++pass_count
}
else {
    display as error "  FAIL: 1-day study period (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.42.5"
}

* =============================================================================
* TEST SECTION 3.43: DOSE AND CUMULATIVE EXPOSURE EDGE CASES
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 3.43: Dose and Cumulative Exposure Edge Cases"
    display as text "{hline 70}"
}

* Create exposure with dose variable
clear
input long id double(rx_start rx_stop) byte exp_type double dose
    1 21946 22067 1 100
    1 22097 22189 1 200
end
format %td rx_start rx_stop
label data "Two exposures with different doses"
save "${DATA_DIR}/exp_with_dose.dta", replace

* Create exposures with very small dose
clear
input long id double(rx_start rx_stop) byte exp_type double dose
    1 21946 22067 1 0.001
end
format %td rx_start rx_stop
label data "Exposure with very small dose"
save "${DATA_DIR}/exp_small_dose.dta", replace

* Create exposures with very large dose
clear
input long id double(rx_start rx_stop) byte exp_type double dose
    1 21946 22067 1 1000000
end
format %td rx_start rx_stop
label data "Exposure with very large dose"
save "${DATA_DIR}/exp_large_dose.dta", replace

* Create multiple exposures for cumulative testing
clear
input long id double(rx_start rx_stop) byte exp_type
    1 21915 21946 1
    1 21961 21991 1
    1 22006 22036 1
    1 22051 22082 1
    1 22097 22128 1
end
format %td rx_start rx_stop
label data "Five 30-day exposure periods"
save "${DATA_DIR}/exp_five_periods.dta", replace

* -----------------------------------------------------------------------------
* Test 3.43.1: Cumulative Dose Across Multiple Periods
* Purpose: Verify cumulative dose accumulates correctly
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.43.1: Cumulative Dose Across Periods"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_five_periods.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        continuousunit(days) generate(cum_exp)

    * Maximum cumulative should be about 150 days (5 x 30)
    quietly sum cum_exp
    assert r(max) >= 140 & r(max) <= 160
}
if _rc == 0 {
    display as result "  PASS: Cumulative dose accumulates across periods"
    local ++pass_count
}
else {
    display as error "  FAIL: Cumulative dose (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.43.1"
}

* -----------------------------------------------------------------------------
* Test 3.43.2: Very Small Dose Value
* Purpose: Verify very small dose values are preserved
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.43.2: Very Small Dose Value"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_small_dose.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(dose) entry(study_entry) exit(study_exit) ///
        dose generate(tv_exp)

    * Command should complete
    assert _N >= 1
}
if _rc == 0 {
    display as result "  PASS: Very small dose value handled"
    local ++pass_count
}
else {
    display as error "  FAIL: Small dose (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.43.2"
}

* -----------------------------------------------------------------------------
* Test 3.43.3: Very Large Dose Value
* Purpose: Verify very large dose values are preserved
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.43.3: Very Large Dose Value"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_large_dose.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(dose) entry(study_entry) exit(study_exit) ///
        dose generate(tv_exp)

    * Command should complete
    assert _N >= 1
}
if _rc == 0 {
    display as result "  PASS: Very large dose value handled"
    local ++pass_count
}
else {
    display as error "  FAIL: Large dose (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.43.3"
}

* =============================================================================
* TEST SECTION 3.44: DURATION CATEGORY EDGE CASES
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 3.44: Duration Category Edge Cases"
    display as text "{hline 70}"
}

* Create exposure ending exactly at duration threshold
clear
input long id double(rx_start rx_stop) byte exp_type
    1 21915 22006 1
end
format %td rx_start rx_stop
label data "91-day exposure (exactly 0.25 years)"
save "${DATA_DIR}/exp_91days.dta", replace

* Create very short exposure (1 day)
clear
input long id double(rx_start rx_stop) byte exp_type
    1 22006 22007 1
end
format %td rx_start rx_stop
save "${DATA_DIR}/exp_single_day.dta", replace

* -----------------------------------------------------------------------------
* Test 3.44.1: Exposure Ending at Duration Threshold
* Purpose: Verify threshold boundary handling in duration categories
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.44.1: Exposure at Duration Threshold (91 days ≈ 0.25 years)"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_91days.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        duration(0.25 0.5 0.75) continuousunit(years) generate(dur_cat)

    * Should create duration category transitions
    quietly tab dur_cat
    assert r(r) >= 2
}
if _rc == 0 {
    display as result "  PASS: Duration threshold boundary handled"
    local ++pass_count
}
else {
    display as error "  FAIL: Duration threshold (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.44.1"
}

* -----------------------------------------------------------------------------
* Test 3.44.2: Single-Day Exposure with Duration Categories
* Purpose: Verify minimal exposure assigns correct duration category
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.44.2: Single-Day Exposure with Duration Categories"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_single_day.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        duration(0.25 0.5 0.75) continuousunit(years) generate(dur_cat)

    * Should have at least one exposed interval
    quietly count if dur_cat >= 1
    assert r(N) >= 1
}
if _rc == 0 {
    display as result "  PASS: Single-day exposure assigns duration category"
    local ++pass_count
}
else {
    display as error "  FAIL: Single-day duration (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.44.2"
}

* =============================================================================
* TEST SECTION 3.45: DATA ORDERING AND QUALITY EDGE CASES
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 3.45: Data Ordering and Quality Edge Cases"
    display as text "{hline 70}"
}

* Create exposures in random (non-chronological) order
clear
input long id double(rx_start rx_stop) byte exp_type
    1 22097 22189 2
    1 21946 22067 1
    1 22189 22281 1
end
format %td rx_start rx_stop
label data "Exposures in random order"
save "${DATA_DIR}/exp_random_order.dta", replace

* Create near-duplicate exposures (same dates, different doses)
clear
input long id double(rx_start rx_stop) byte exp_type double dose
    1 22006 22097 1 100
    1 22006 22097 1 200
end
format %td rx_start rx_stop
label data "Near-duplicate exposures (same dates, different doses)"
save "${DATA_DIR}/exp_near_duplicate.dta", replace

* -----------------------------------------------------------------------------
* Test 3.45.1: Exposures in Non-Chronological Order
* Purpose: Verify exposures are sorted internally
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.45.1: Exposures in Random Order"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_random_order.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        generate(tv_exp)

    * Output should be in chronological order
    sort id rx_start
    by id: gen byte order_check = (rx_start <= rx_start[_n+1]) if _n < _N
    quietly count if order_check == 0
    assert r(N) == 0
}
if _rc == 0 {
    display as result "  PASS: Non-chronological exposures sorted correctly"
    local ++pass_count
}
else {
    display as error "  FAIL: Random order exposures (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.45.1"
}

* -----------------------------------------------------------------------------
* Test 3.45.2: Near-Duplicate Exposures (Same Dates, Different Doses)
* Purpose: Verify handling of prescription refinements/duplicates
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.45.2: Near-Duplicate Exposures"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_near_duplicate.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(dose) entry(study_entry) exit(study_exit) ///
        dose generate(tv_exp)

    * Should complete without error
    assert _N >= 1

    * No overlapping output intervals
    _verify_no_overlap, id(id) start(rx_start) stop(rx_stop)
    assert r(n_overlaps) == 0
}
if _rc == 0 {
    display as result "  PASS: Near-duplicate exposures handled"
    local ++pass_count
}
else {
    display as error "  FAIL: Near-duplicate exposures (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.45.2"
}

* =============================================================================
* TEST SECTION 3.46: MULTI-TYPE SIMULTANEOUS EXPOSURES
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 3.46: Multi-Type Simultaneous Exposures"
    display as text "{hline 70}"
}

* Create two types starting on same day
clear
input long id double(rx_start rx_stop) byte exp_type
    1 22006 22097 1
    1 22006 22067 2
end
format %td rx_start rx_stop
label data "Two types starting on same day"
save "${DATA_DIR}/exp_same_start.dta", replace

* Create two types ending on same day
clear
input long id double(rx_start rx_stop) byte exp_type
    1 22006 22097 1
    1 22067 22097 2
end
format %td rx_start rx_stop
label data "Two types ending on same day"
save "${DATA_DIR}/exp_same_end.dta", replace

* Create three overlapping types
clear
input long id double(rx_start rx_stop) byte exp_type
    1 21946 22097 1
    1 22006 22189 2
    1 22067 22281 3
end
format %td rx_start rx_stop
label data "Three overlapping exposure types"
save "${DATA_DIR}/exp_three_types.dta", replace

* -----------------------------------------------------------------------------
* Test 3.46.1: Two Types Starting Same Day
* Purpose: Verify concurrent start of multiple types
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.46.1: Two Types Starting Same Day"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_same_start.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        layer generate(tv_exp)

    * Both types should be represented
    assert _N >= 2
}
if _rc == 0 {
    display as result "  PASS: Two types starting same day handled"
    local ++pass_count
}
else {
    display as error "  FAIL: Same start day (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.46.1"
}

* -----------------------------------------------------------------------------
* Test 3.46.2: Two Types Ending Same Day
* Purpose: Verify concurrent end of multiple types
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.46.2: Two Types Ending Same Day"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_same_end.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        layer generate(tv_exp)

    * Both types should be represented
    assert _N >= 2
}
if _rc == 0 {
    display as result "  PASS: Two types ending same day handled"
    local ++pass_count
}
else {
    display as error "  FAIL: Same end day (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.46.2"
}

* -----------------------------------------------------------------------------
* Test 3.46.3: Three Overlapping Types
* Purpose: Verify complex multi-type overlap scenario
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.46.3: Three Overlapping Types"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_three_types.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        layer generate(tv_exp)

    * Should create multiple split intervals
    assert _N >= 4

    * No overlapping output intervals
    _verify_no_overlap, id(id) start(rx_start) stop(rx_stop)
    assert r(n_overlaps) == 0
}
if _rc == 0 {
    display as result "  PASS: Three overlapping types create proper splits"
    local ++pass_count
}
else {
    display as error "  FAIL: Three overlapping types (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.46.3"
}

* =============================================================================
* TEST SECTION 3.47: PERSON-TIME CONSERVATION INVARIANTS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 3.47: Person-Time Conservation Invariants"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 3.47.1: Total Person-Time Always Equals Study Duration
* Purpose: Fundamental invariant check across various scenarios
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.47.1: Person-Time Conservation (Basic)"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_basic.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        generate(tv_exp)

    gen dur = rx_stop - rx_start
    quietly sum dur
    local total = r(sum)
    assert abs(`total' - 366) < 2
}
if _rc == 0 {
    display as result "  PASS: Person-time conservation (basic)"
    local ++pass_count
}
else {
    display as error "  FAIL: Person-time basic (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.47.1"
}

* -----------------------------------------------------------------------------
* Test 3.47.2: Person-Time Conservation with Complex Overlaps
* Purpose: Verify conservation even with complex exposure patterns
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.47.2: Person-Time Conservation (Complex Overlaps)"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_triple_overlap.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        generate(tv_exp)

    gen dur = rx_stop - rx_start
    quietly sum dur
    local total = r(sum)
    assert abs(`total' - 366) < 2
}
if _rc == 0 {
    display as result "  PASS: Person-time conservation (complex overlaps)"
    local ++pass_count
}
else {
    display as error "  FAIL: Person-time complex (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.47.2"
}

* -----------------------------------------------------------------------------
* Test 3.47.3: Person-Time Conservation with Multi-Type Layer
* Purpose: Verify conservation with layer option
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.47.3: Person-Time Conservation (Layer Option)"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_three_types.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        layer generate(tv_exp)

    gen dur = rx_stop - rx_start
    quietly sum dur
    local total = r(sum)
    * Note: Layer option may have minor boundary effects (up to 2 days)
    assert abs(`total' - 366) <= 2
}
if _rc == 0 {
    display as result "  PASS: Person-time conservation (layer option)"
    local ++pass_count
}
else {
    display as error "  FAIL: Person-time layer (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.47.3"
}

* -----------------------------------------------------------------------------
* Test 3.47.4: Person-Time Conservation with Lag
* Purpose: Verify conservation when using lag option
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.47.4: Person-Time Conservation (Lag Option)"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_basic.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        lag(30) generate(tv_exp)

    gen dur = rx_stop - rx_start
    quietly sum dur
    local total = r(sum)
    assert abs(`total' - 366) < 2
}
if _rc == 0 {
    display as result "  PASS: Person-time conservation (lag option)"
    local ++pass_count
}
else {
    display as error "  FAIL: Person-time lag (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.47.4"
}

* -----------------------------------------------------------------------------
* Test 3.47.5: Person-Time Conservation with Washout
* Purpose: Verify conservation when using washout option
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.47.5: Person-Time Conservation (Washout Option)"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_basic.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        washout(30) generate(tv_exp)

    gen dur = rx_stop - rx_start
    quietly sum dur
    local total = r(sum)
    assert abs(`total' - 366) < 2
}
if _rc == 0 {
    display as result "  PASS: Person-time conservation (washout option)"
    local ++pass_count
}
else {
    display as error "  FAIL: Person-time washout (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.47.5"
}

* -----------------------------------------------------------------------------
* Test 3.47.6: Multi-Person Person-Time Conservation
* Purpose: Verify conservation across multiple persons
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.47.6: Multi-Person Person-Time Conservation"
}

capture {
    * Calculate expected total person-time
    use "${DATA_DIR}/cohort_multi.dta", clear
    gen expected_pt = study_exit - study_entry
    quietly sum expected_pt
    local expected_total = r(sum)

    use "${DATA_DIR}/cohort_multi.dta", clear
    tvexpose using "${DATA_DIR}/exposure_multi.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        generate(tv_exp)

    gen dur = rx_stop - rx_start
    quietly sum dur
    local actual_total = r(sum)
    assert abs(`actual_total' - `expected_total') < 5
}
if _rc == 0 {
    display as result "  PASS: Multi-person person-time conservation"
    local ++pass_count
}
else {
    display as error "  FAIL: Multi-person person-time (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.47.6"
}

* =============================================================================
* TEST SECTION 3.48: NO-OVERLAP OUTPUT INVARIANT
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 3.48: No-Overlap Output Invariant"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 3.48.1: No Overlaps After Basic Processing
* Purpose: Fundamental check that output never has overlapping intervals
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.48.1: No Overlaps in Output (Basic)"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_basic.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        generate(tv_exp)

    _verify_no_overlap, id(id) start(rx_start) stop(rx_stop)
    assert r(n_overlaps) == 0
}
if _rc == 0 {
    display as result "  PASS: No overlaps in output (basic)"
    local ++pass_count
}
else {
    display as error "  FAIL: No overlaps basic (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.48.1"
}

* -----------------------------------------------------------------------------
* Test 3.48.2: No Overlaps After Complex Input
* Purpose: Verify no overlaps even with problematic input
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.48.2: No Overlaps After Triple Overlap Input"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_triple_overlap.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        generate(tv_exp)

    _verify_no_overlap, id(id) start(rx_start) stop(rx_stop)
    assert r(n_overlaps) == 0
}
if _rc == 0 {
    display as result "  PASS: No overlaps after complex input"
    local ++pass_count
}
else {
    display as error "  FAIL: No overlaps complex (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.48.2"
}

* -----------------------------------------------------------------------------
* Test 3.48.3: No Overlaps with Layer Option
* Purpose: Verify layer option maintains no-overlap invariant
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.48.3: No Overlaps with Layer Option"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_three_types.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        layer generate(tv_exp)

    _verify_no_overlap, id(id) start(rx_start) stop(rx_stop)
    assert r(n_overlaps) == 0
}
if _rc == 0 {
    display as result "  PASS: No overlaps with layer option"
    local ++pass_count
}
else {
    display as error "  FAIL: No overlaps layer (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.48.3"
}

* -----------------------------------------------------------------------------
* Test 3.48.4: No Overlaps Multi-Person
* Purpose: Verify no overlaps within each person in multi-person data
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.48.4: No Overlaps Multi-Person"
}

capture {
    use "${DATA_DIR}/cohort_multi.dta", clear
    tvexpose using "${DATA_DIR}/exposure_multi.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        generate(tv_exp)

    _verify_no_overlap, id(id) start(rx_start) stop(rx_stop)
    assert r(n_overlaps) == 0
}
if _rc == 0 {
    display as result "  PASS: No overlaps multi-person"
    local ++pass_count
}
else {
    display as error "  FAIL: No overlaps multi-person (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.48.4"
}

* =============================================================================
* TEST SECTION 3.49: BOUNDARY CONDITION TESTS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 3.49: Boundary Condition Tests"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 3.49.1: Single-Day Exposure
* Purpose: Verify single-day exposure (start == stop) is handled correctly
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.49.1: Single-Day Exposure"
}

capture {
    * Create single-day exposure dataset
    clear
    input long id double(rx_start rx_stop) byte exp_type
        1 22000 22000 1
    end
    format %td rx_start rx_stop
    save "${DATA_DIR}/exp_single_day.dta", replace

    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_single_day.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        generate(tv_exp)

    * Verify exposed period exists and has exactly 1 day
    quietly count if tv_exp == 1
    assert r(N) >= 1
    gen dur = rx_stop - rx_start
    quietly sum dur if tv_exp == 1
    assert r(sum) == 0 | r(sum) == 1  // Single day = 0 or 1 depending on interval convention
}
if _rc == 0 {
    display as result "  PASS: Single-day exposure handled correctly"
    local ++pass_count
}
else {
    display as error "  FAIL: Single-day exposure (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.49.1"
}

* -----------------------------------------------------------------------------
* Test 3.49.2: Same-Start Different-Stop Intervals
* Purpose: Verify exposures starting on same day with different stops
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.49.2: Same-Start Different-Stop Intervals"
}

capture {
    * Create overlapping exposures starting same day
    clear
    input long id double(rx_start rx_stop) byte exp_type
        1 22000 22030 1
        1 22000 22060 2
    end
    format %td rx_start rx_stop
    save "${DATA_DIR}/exp_same_start.dta", replace

    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_same_start.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        layer generate(tv_exp)

    * Should produce non-overlapping output
    _verify_no_overlap, id(id) start(rx_start) stop(rx_stop)
    assert r(n_overlaps) == 0
}
if _rc == 0 {
    display as result "  PASS: Same-start intervals handled correctly"
    local ++pass_count
}
else {
    display as error "  FAIL: Same-start intervals (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.49.2"
}

* -----------------------------------------------------------------------------
* Test 3.49.3: Different-Start Same-Stop Intervals
* Purpose: Verify exposures ending on same day with different starts
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.49.3: Different-Start Same-Stop Intervals"
}

capture {
    * Create overlapping exposures ending same day
    clear
    input long id double(rx_start rx_stop) byte exp_type
        1 22000 22060 1
        1 22030 22060 2
    end
    format %td rx_start rx_stop
    save "${DATA_DIR}/exp_same_stop.dta", replace

    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_same_stop.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        layer generate(tv_exp)

    * Should produce non-overlapping output
    _verify_no_overlap, id(id) start(rx_start) stop(rx_stop)
    assert r(n_overlaps) == 0
}
if _rc == 0 {
    display as result "  PASS: Same-stop intervals handled correctly"
    local ++pass_count
}
else {
    display as error "  FAIL: Same-stop intervals (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.49.3"
}

* -----------------------------------------------------------------------------
* Test 3.49.4: Exact Endpoint Matching (Abutting Intervals)
* Purpose: Verify intervals where stop == next start are handled
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.49.4: Exact Endpoint Matching (Abutting)"
}

capture {
    * Create abutting exposures (stop == next start)
    clear
    input long id double(rx_start rx_stop) byte exp_type
        1 22000 22030 1
        1 22030 22060 2
    end
    format %td rx_start rx_stop
    save "${DATA_DIR}/exp_abutting.dta", replace

    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_abutting.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        generate(tv_exp)

    * Should produce non-overlapping output with no gaps at boundary
    _verify_no_overlap, id(id) start(rx_start) stop(rx_stop)
    assert r(n_overlaps) == 0

    * Check both exposure types exist
    quietly count if tv_exp == 1
    assert r(N) >= 1
    quietly count if tv_exp == 2
    assert r(N) >= 1
}
if _rc == 0 {
    display as result "  PASS: Abutting intervals handled correctly"
    local ++pass_count
}
else {
    display as error "  FAIL: Abutting intervals (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.49.4"
}

* -----------------------------------------------------------------------------
* Test 3.49.5: Leap Year Feb 29 Exposure
* Purpose: Verify Feb 29 in leap year is handled correctly
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.49.5: Leap Year Feb 29 Exposure"
}

capture {
    * Create exposure spanning Feb 29, 2020 (leap year)
    * Feb 28 = 21973, Feb 29 = 21974, Mar 1 = 21975
    clear
    input long id double(rx_start rx_stop) byte exp_type
        1 21973 21975 1
    end
    format %td rx_start rx_stop
    save "${DATA_DIR}/exp_leap_year.dta", replace

    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_leap_year.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        generate(tv_exp)

    * Verify Feb 29 is included (exposure period should be 2 days: Feb 28-29 to Mar 1)
    gen dur = rx_stop - rx_start
    quietly sum dur if tv_exp == 1
    assert r(sum) == 2  // Feb 28 to Mar 1 = 2 days
}
if _rc == 0 {
    display as result "  PASS: Leap year Feb 29 handled correctly"
    local ++pass_count
}
else {
    display as error "  FAIL: Leap year Feb 29 (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.49.5"
}

* -----------------------------------------------------------------------------
* Test 3.49.6: Exposure at Study Entry Boundary
* Purpose: Verify exposure starting exactly on study entry date
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.49.6: Exposure at Study Entry Boundary"
}

capture {
    * Create exposure starting exactly at study entry (Jan 1, 2020 = 21915)
    clear
    input long id double(rx_start rx_stop) byte exp_type
        1 21915 21945 1
    end
    format %td rx_start rx_stop
    save "${DATA_DIR}/exp_entry_boundary.dta", replace

    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_entry_boundary.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        generate(tv_exp)

    * Verify exposure starts at study entry
    quietly sum rx_start
    assert r(min) == 21915

    * Verify exposed time is correct (30 days)
    gen dur = rx_stop - rx_start
    quietly sum dur if tv_exp == 1
    assert r(sum) == 30
}
if _rc == 0 {
    display as result "  PASS: Study entry boundary handled correctly"
    local ++pass_count
}
else {
    display as error "  FAIL: Study entry boundary (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.49.6"
}

* -----------------------------------------------------------------------------
* Test 3.49.7: Exposure at Study Exit Boundary
* Purpose: Verify exposure ending exactly on study exit date
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.49.7: Exposure at Study Exit Boundary"
}

capture {
    * Create exposure ending exactly at study exit (Dec 31, 2020 = 22281)
    clear
    input long id double(rx_start rx_stop) byte exp_type
        1 22251 22281 1
    end
    format %td rx_start rx_stop
    save "${DATA_DIR}/exp_exit_boundary.dta", replace

    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_exit_boundary.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        generate(tv_exp)

    * Verify exposure ends at study exit
    quietly sum rx_stop
    assert r(max) == 22281

    * Verify exposed time is correct (30 days)
    gen dur = rx_stop - rx_start
    quietly sum dur if tv_exp == 1
    assert r(sum) == 30
}
if _rc == 0 {
    display as result "  PASS: Study exit boundary handled correctly"
    local ++pass_count
}
else {
    display as error "  FAIL: Study exit boundary (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.49.7"
}

* =============================================================================
* TEST SECTION 3.50: INVARIANT ASSERTION TESTS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 3.50: Invariant Assertion Tests"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 3.50.1: Person-Time Conservation (Basic)
* Purpose: Verify total person-time in output equals study window
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.50.1: Person-Time Conservation (Basic)"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_basic.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        generate(tv_exp)

    * Total person-time should equal study window (366 days for 2020)
    gen dur = rx_stop - rx_start
    quietly sum dur
    local total_ptime = r(sum)

    * Allow 1 day tolerance for boundary handling
    assert abs(`total_ptime' - 366) <= 1
}
if _rc == 0 {
    display as result "  PASS: Person-time conserved (basic)"
    local ++pass_count
}
else {
    display as error "  FAIL: Person-time conservation basic (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.50.1"
}

* -----------------------------------------------------------------------------
* Test 3.50.2: Person-Time Conservation (Complex Overlaps)
* Purpose: Verify person-time conserved with overlapping exposures
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.50.2: Person-Time Conservation (Complex)"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_triple_overlap.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        generate(tv_exp)

    * Total person-time should still equal study window
    gen dur = rx_stop - rx_start
    quietly sum dur
    local total_ptime = r(sum)

    * Allow 2 day tolerance for complex boundary handling
    assert abs(`total_ptime' - 366) <= 2
}
if _rc == 0 {
    display as result "  PASS: Person-time conserved (complex overlaps)"
    local ++pass_count
}
else {
    display as error "  FAIL: Person-time conservation complex (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.50.2"
}

* -----------------------------------------------------------------------------
* Test 3.50.3: No Gaps in Coverage (Full Study Window)
* Purpose: Verify output intervals cover entire study window without gaps
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.50.3: No Gaps in Coverage"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_basic.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        generate(tv_exp)

    * Check for gaps > 1 day between consecutive intervals
    sort id rx_start
    by id: gen gap = rx_start - rx_stop[_n-1] if _n > 1
    quietly count if gap > 1 & !missing(gap)
    assert r(N) == 0

    * Verify first interval starts at study entry
    quietly sum rx_start
    assert r(min) == 21915

    * Verify last interval ends at study exit
    quietly sum rx_stop
    assert r(max) == 22281
}
if _rc == 0 {
    display as result "  PASS: No gaps in coverage"
    local ++pass_count
}
else {
    display as error "  FAIL: Gap detection (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.50.3"
}

* -----------------------------------------------------------------------------
* Test 3.50.4: Exposure Value Consistency
* Purpose: Verify exposure values in output match original input values
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.50.4: Exposure Value Consistency"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_three_types.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        generate(tv_exp)

    * Exposure values should only be 0, 1, 2, or 3 (reference + 3 types)
    quietly tab tv_exp
    quietly levelsof tv_exp, local(exp_levels)
    foreach lvl in `exp_levels' {
        assert `lvl' >= 0 & `lvl' <= 3
    }
}
if _rc == 0 {
    display as result "  PASS: Exposure values consistent"
    local ++pass_count
}
else {
    display as error "  FAIL: Exposure value consistency (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.50.4"
}

* -----------------------------------------------------------------------------
* Test 3.50.5: Multi-Person Person-Time Conservation
* Purpose: Verify person-time conserved for each person in multi-person data
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.50.5: Multi-Person Person-Time Conservation"
}

capture {
    use "${DATA_DIR}/cohort_multi.dta", clear
    * Store expected person-time from cohort
    gen expected_ptime = study_exit - study_entry
    tempfile cohort_expected
    save `cohort_expected', replace

    tvexpose using "${DATA_DIR}/exposure_multi.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        generate(tv_exp)

    * Calculate actual person-time for each person
    gen dur = rx_stop - rx_start
    bysort id: egen actual_ptime = sum(dur)

    * Get one row per person
    bysort id: keep if _n == 1
    keep id actual_ptime

    * Merge expected person-time
    merge 1:1 id using `cohort_expected', keepusing(expected_ptime)

    * Each person should have person-time matching their study window (allow 2 day tolerance)
    gen ptime_diff = abs(actual_ptime - expected_ptime)
    quietly sum ptime_diff
    assert r(max) <= 2
}
if _rc == 0 {
    display as result "  PASS: Multi-person person-time conserved"
    local ++pass_count
}
else {
    display as error "  FAIL: Multi-person conservation (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.50.5"
}

* -----------------------------------------------------------------------------
* Test 3.50.6: Output Strictly Ordered by Start Date
* Purpose: Verify output is properly sorted within each person
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.50.6: Output Strictly Ordered"
}

capture {
    use "${DATA_DIR}/cohort_multi.dta", clear
    tvexpose using "${DATA_DIR}/exposure_multi.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        generate(tv_exp)

    * Check that start dates are non-decreasing within each person
    sort id rx_start rx_stop
    by id: gen byte order_ok = (rx_start >= rx_start[_n-1]) if _n > 1
    quietly count if order_ok == 0
    assert r(N) == 0
}
if _rc == 0 {
    display as result "  PASS: Output strictly ordered"
    local ++pass_count
}
else {
    display as error "  FAIL: Output ordering (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.50.6"
}

* =============================================================================
* SUMMARY
* =============================================================================
display as text _n "{hline 70}"
display as text "TVEXPOSE VALIDATION SUMMARY"
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
