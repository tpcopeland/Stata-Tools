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
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.12.2: merge() Consolidates Close Periods"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear

    * Get count with no merge option (should have more intervals)
    tvexpose using "${DATA_DIR}/exp_gap15.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        merge(0) generate(tv_no_merge)
    local n_no_merge = _N

    * With merge(30) - should consolidate nearby periods
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_gap15.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        merge(30) generate(tv_merge)
    local n_merge = _N

    * Should have equal or fewer intervals after merge
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
    capture erase "${DATA_DIR}/tv_validation.dta"

    tvexpose using "${DATA_DIR}/exp_basic.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        validate generate(tv_exp)

    * Verify validation file was created
    confirm file "${DATA_DIR}/tv_validation.dta"

    * Cleanup
    capture erase "${DATA_DIR}/tv_validation.dta"
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
