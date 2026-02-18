/*******************************************************************************
* validation_tvtools_bugfixes.do
*
* Purpose: Validation tests for 4 known tvtools bugs:
*   Bug 1: duration() + continuousunit(years/months) precision
*   Bug 2: Dose with equal-dose overlapping prescriptions
*   Bug 3: Removed distinct dependency (tested implicitly by other test files)
*   Bug 4: tvcalendar range-based merge
*
* Run: stata-mp -b do validation_tvtools_bugfixes.do
* Log: validation_tvtools_bugfixes.log
*
* Author: Claude Code
* Date: 2026-02-18
*******************************************************************************/

clear all
set more off
version 16.0
set varabbrev off

local pass_count = 0
local fail_count = 0
local failed_tests ""

display _n _dup(70) "="
display "TVTOOLS BUG FIX VALIDATION TESTS"
display _dup(70) "="
display "Date: $S_DATE $S_TIME"
display ""

quietly adopath ++ "/home/tpcopeland/Stata-Tools/tvtools"
program drop _allado

* =============================================================================
* BUG 1: DURATION + CONTINUOUSUNIT PRECISION
* =============================================================================
display _n _dup(60) "-"
display "BUG 1: Duration + continuousunit() precision"
display _dup(60) "-"

* ---------------------------------------------------------------------------
* Test 1.1: 365 days should be >= 1 year (non-bytype path)
* ---------------------------------------------------------------------------
display _n "Test 1.1: 365 days of exposure = 1+ year category (non-bytype)"

capture {
    clear
    * Create cohort: 1 person, study period of 2 years
    quietly set obs 1
    gen double id = 1
    gen double study_entry = mdy(1, 1, 2020)
    gen double study_exit = mdy(12, 31, 2021)
    format study_entry study_exit %td
    tempfile cohort
    quietly save `cohort', replace

    * Create exposure: exactly 365 days (Jan 1 to Dec 31, 2020)
    clear
    quietly set obs 1
    gen double id = 1
    gen double rx_start = mdy(1, 1, 2020)
    gen double rx_stop = mdy(12, 31, 2020)
    format rx_start rx_stop %td
    gen double drug = 1
    tempfile exposure
    quietly save `exposure', replace

    * Run tvexpose with duration(1) continuousunit(years)
    use `cohort', clear
    tvexpose using `exposure', id(id) start(rx_start) stop(rx_stop) ///
        exposure(drug) entry(study_entry) exit(study_exit) ///
        duration(1) continuousunit(years) reference(0) generate(tv_exp) ///
        saveas("`c(tmpdir)'/bugfix_test1_1") replace

    quietly use "`c(tmpdir)'/bugfix_test1_1.dta", clear

    * The person has 365 days of exposure
    * With duration(1) continuousunit(years), threshold is at 1 year
    * 365 days >= round(1 * 365.25) = 365 days, so should be category "1+ years"
    * Find the last exposed period (highest tv_exp category)
    quietly summarize tv_exp
    local max_cat = r(max)

    * Category for 1+ years should be 2 (0=reference, 1=<1 year, 2=1+ years)
    assert `max_cat' == 2
}
if _rc == 0 {
    display as result "  PASS"
    local ++pass_count
}
else {
    display as error "  FAIL (rc = " _rc ")"
    local ++fail_count
    local failed_tests "`failed_tests' 1.1"
}

* ---------------------------------------------------------------------------
* Test 1.2: 364 days should be < 1 year (non-bytype path)
* ---------------------------------------------------------------------------
display _n "Test 1.2: 364 days of exposure = <1 year category (non-bytype)"

capture {
    clear
    quietly set obs 1
    gen double id = 1
    gen double study_entry = mdy(1, 1, 2020)
    gen double study_exit = mdy(12, 31, 2021)
    format study_entry study_exit %td
    tempfile cohort
    quietly save `cohort', replace

    * Create exposure: exactly 364 days (Jan 1 to Dec 30, 2020)
    clear
    quietly set obs 1
    gen double id = 1
    gen double rx_start = mdy(1, 1, 2020)
    gen double rx_stop = mdy(12, 30, 2020)
    format rx_start rx_stop %td
    gen double drug = 1
    tempfile exposure
    quietly save `exposure', replace

    use `cohort', clear
    tvexpose using `exposure', id(id) start(rx_start) stop(rx_stop) ///
        exposure(drug) entry(study_entry) exit(study_exit) ///
        duration(1) continuousunit(years) reference(0) generate(tv_exp) ///
        saveas("`c(tmpdir)'/bugfix_test1_2") replace

    quietly use "`c(tmpdir)'/bugfix_test1_2.dta", clear

    * 364 days < 365 threshold, so max category should be 1 (<1 year)
    quietly summarize tv_exp
    local max_cat = r(max)
    assert `max_cat' == 1
}
if _rc == 0 {
    display as result "  PASS"
    local ++pass_count
}
else {
    display as error "  FAIL (rc = " _rc ")"
    local ++fail_count
    local failed_tests "`failed_tests' 1.2"
}

* ---------------------------------------------------------------------------
* Test 1.3: 30 days should be >= 1 month (non-bytype path)
* ---------------------------------------------------------------------------
display _n "Test 1.3: 30 days of exposure = 1+ month category (non-bytype)"

capture {
    clear
    quietly set obs 1
    gen double id = 1
    gen double study_entry = mdy(1, 1, 2020)
    gen double study_exit = mdy(6, 30, 2020)
    format study_entry study_exit %td
    tempfile cohort
    quietly save `cohort', replace

    * Create exposure: 31 days (Jan 1 to Jan 31, 2020)
    * Threshold = round(1 * 30.4375) = 30 days
    * Need > threshold for split to occur, so 31 days works
    clear
    quietly set obs 1
    gen double id = 1
    gen double rx_start = mdy(1, 1, 2020)
    gen double rx_stop = mdy(1, 31, 2020)
    format rx_start rx_stop %td
    gen double drug = 1
    tempfile exposure
    quietly save `exposure', replace

    use `cohort', clear
    tvexpose using `exposure', id(id) start(rx_start) stop(rx_stop) ///
        exposure(drug) entry(study_entry) exit(study_exit) ///
        duration(1) continuousunit(months) reference(0) generate(tv_exp) ///
        saveas("`c(tmpdir)'/bugfix_test1_3") replace

    quietly use "`c(tmpdir)'/bugfix_test1_3.dta", clear

    * 31 days > 30 threshold, crossing at day 31 = Jan 31 (within period)
    * Split: [Jan 1-Jan 30] cat 1, [Jan 31-Jan 31] cat 2
    quietly summarize tv_exp
    local max_cat = r(max)
    assert `max_cat' == 2
}
if _rc == 0 {
    display as result "  PASS"
    local ++pass_count
}
else {
    display as error "  FAIL (rc = " _rc ")"
    local ++fail_count
    local failed_tests "`failed_tests' 1.3"
}

* ---------------------------------------------------------------------------
* Test 1.4: 365 days with bytype path
* ---------------------------------------------------------------------------
display _n "Test 1.4: 365 days of exposure = 1+ year category (bytype path)"

capture {
    clear
    quietly set obs 1
    gen double id = 1
    gen double study_entry = mdy(1, 1, 2020)
    gen double study_exit = mdy(12, 31, 2021)
    format study_entry study_exit %td
    tempfile cohort
    quietly save `cohort', replace

    * Create exposure with a categorical drug type
    clear
    quietly set obs 1
    gen double id = 1
    gen double rx_start = mdy(1, 1, 2020)
    gen double rx_stop = mdy(12, 31, 2020)
    format rx_start rx_stop %td
    gen double drug = 1
    tempfile exposure
    quietly save `exposure', replace

    use `cohort', clear
    tvexpose using `exposure', id(id) start(rx_start) stop(rx_stop) ///
        exposure(drug) entry(study_entry) exit(study_exit) ///
        duration(1) continuousunit(years) bytype reference(0) generate(tv_exp) ///
        saveas("`c(tmpdir)'/bugfix_test1_4") replace

    quietly use "`c(tmpdir)'/bugfix_test1_4.dta", clear

    * With bytype, duration variable is named duration_<type>
    * Check that we have a duration variable
    capture confirm variable duration_1
    if _rc != 0 {
        * Try tv_exp1 pattern
        capture confirm variable tv_exp1
        if _rc != 0 {
            * List all variables to see what was created
            describe, short
            assert 0
        }
        else {
            quietly summarize tv_exp1
            local max_cat = r(max)
            assert `max_cat' == 2
        }
    }
    else {
        quietly summarize duration_1
        local max_cat = r(max)
        assert `max_cat' == 2
    }
}
if _rc == 0 {
    display as result "  PASS"
    local ++pass_count
}
else {
    display as error "  FAIL (rc = " _rc ")"
    local ++fail_count
    local failed_tests "`failed_tests' 1.4"
}

* ---------------------------------------------------------------------------
* Test 1.5: Multiple thresholds - 2 years with years
* ---------------------------------------------------------------------------
display _n "Test 1.5: 730 days with duration(1 2) continuousunit(years)"

capture {
    clear
    quietly set obs 1
    gen double id = 1
    gen double study_entry = mdy(1, 1, 2020)
    gen double study_exit = mdy(12, 31, 2023)
    format study_entry study_exit %td
    tempfile cohort
    quietly save `cohort', replace

    * Create exposure: ~2.5 years (Jan 1, 2020 to Jun 30, 2022)
    * Clearly exceeds both 1-year and 2-year thresholds
    clear
    quietly set obs 1
    gen double id = 1
    gen double rx_start = mdy(1, 1, 2020)
    gen double rx_stop = mdy(6, 30, 2022)
    format rx_start rx_stop %td
    gen double drug = 1
    tempfile exposure
    quietly save `exposure', replace

    use `cohort', clear
    tvexpose using `exposure', id(id) start(rx_start) stop(rx_stop) ///
        exposure(drug) entry(study_entry) exit(study_exit) ///
        duration(1 2) continuousunit(years) reference(0) generate(tv_exp) ///
        saveas("`c(tmpdir)'/bugfix_test1_5") replace

    quietly use "`c(tmpdir)'/bugfix_test1_5.dta", clear

    * ~912 days clearly exceeds both thresholds (365 and ~731)
    * Should reach category 3 (2+ years)
    quietly summarize tv_exp
    local max_cat = r(max)
    assert `max_cat' == 3
}
if _rc == 0 {
    display as result "  PASS"
    local ++pass_count
}
else {
    display as error "  FAIL (rc = " _rc ")"
    local ++fail_count
    local failed_tests "`failed_tests' 1.5"
}

* =============================================================================
* BUG 2: DOSE WITH EQUAL-DOSE OVERLAPPING PRESCRIPTIONS
* =============================================================================
display _n _dup(60) "-"
display "BUG 2: Equal-dose overlapping prescriptions"
display _dup(60) "-"

* ---------------------------------------------------------------------------
* Test 2.1: Two overlapping prescriptions with identical dose
* ---------------------------------------------------------------------------
display _n "Test 2.1: Equal-dose overlapping prescriptions produce correct cumulative dose"

capture {
    clear
    quietly set obs 2
    gen double id = 1
    gen double study_entry = mdy(1, 1, 2020)
    gen double study_exit = mdy(6, 30, 2020)
    format study_entry study_exit %td
    tempfile cohort
    * Keep one row for cohort
    quietly keep if _n == 1
    quietly save `cohort', replace

    * Create two overlapping prescriptions with same dose
    clear
    quietly set obs 2
    gen double id = 1
    gen double rx_start = .
    gen double rx_stop = .
    gen double drug = 10

    * Prescription 1: Jan 1 - Mar 31
    quietly replace rx_start = mdy(1, 1, 2020) if _n == 1
    quietly replace rx_stop = mdy(3, 31, 2020) if _n == 1
    * Prescription 2: Feb 1 - Apr 30 (overlaps by Feb 1 - Mar 31)
    quietly replace rx_start = mdy(2, 1, 2020) if _n == 2
    quietly replace rx_stop = mdy(4, 30, 2020) if _n == 2
    format rx_start rx_stop %td
    tempfile exposure
    quietly save `exposure', replace

    use `cohort', clear
    tvexpose using `exposure', id(id) start(rx_start) stop(rx_stop) ///
        exposure(drug) entry(study_entry) exit(study_exit) ///
        dose generate(tv_exp) ///
        saveas("`c(tmpdir)'/bugfix_test2_1") replace

    quietly use "`c(tmpdir)'/bugfix_test2_1.dta", clear

    * Both prescriptions should contribute dose
    * Total dose from both prescriptions = 10 * 91 + 10 * 90 = 910 + 900 = 1810
    * (Jan=31days, Feb=29days(leap), Mar=31days, Apr=30days)
    * Rx1: Jan1-Mar31 = 91 days, Rx2: Feb1-Apr30 = 90 days
    * With proportional allocation in overlapping period, total should still equal sum
    * The cumulative dose at the end should reflect both prescriptions
    quietly summarize tv_exp
    local max_dose = r(max)

    * Cumulative dose should be > 10 (more than a single prescription's contribution)
    * If the bug existed, equal-dose overlaps would merge and lose one prescription
    assert `max_dose' > 10
}
if _rc == 0 {
    display as result "  PASS"
    local ++pass_count
}
else {
    display as error "  FAIL (rc = " _rc ")"
    local ++fail_count
    local failed_tests "`failed_tests' 2.1"
}

* ---------------------------------------------------------------------------
* Test 2.2: Non-overlapping same-dose prescriptions (control test)
* ---------------------------------------------------------------------------
display _n "Test 2.2: Non-overlapping same-dose prescriptions work correctly"

capture {
    clear
    quietly set obs 1
    gen double id = 1
    gen double study_entry = mdy(1, 1, 2020)
    gen double study_exit = mdy(6, 30, 2020)
    format study_entry study_exit %td
    tempfile cohort
    quietly save `cohort', replace

    * Two non-overlapping prescriptions with same dose
    clear
    quietly set obs 2
    gen double id = 1
    gen double rx_start = .
    gen double rx_stop = .
    gen double drug = 10

    * Rx 1: Jan 1 - Jan 31
    quietly replace rx_start = mdy(1, 1, 2020) if _n == 1
    quietly replace rx_stop = mdy(1, 31, 2020) if _n == 1
    * Rx 2: Mar 1 - Mar 31
    quietly replace rx_start = mdy(3, 1, 2020) if _n == 2
    quietly replace rx_stop = mdy(3, 31, 2020) if _n == 2
    format rx_start rx_stop %td
    tempfile exposure
    quietly save `exposure', replace

    use `cohort', clear
    tvexpose using `exposure', id(id) start(rx_start) stop(rx_stop) ///
        exposure(drug) entry(study_entry) exit(study_exit) ///
        dose generate(tv_exp) ///
        saveas("`c(tmpdir)'/bugfix_test2_2") replace

    quietly use "`c(tmpdir)'/bugfix_test2_2.dta", clear

    * Cumulative dose at end should reflect both prescriptions
    * Both prescriptions contribute, so max cumulative > single prescription
    quietly summarize tv_exp
    local max_dose = r(max)
    assert `max_dose' > 10
}
if _rc == 0 {
    display as result "  PASS"
    local ++pass_count
}
else {
    display as error "  FAIL (rc = " _rc ")"
    local ++fail_count
    local failed_tests "`failed_tests' 2.2"
}

* =============================================================================
* BUG 4: TVCALENDAR RANGE-BASED MERGE
* =============================================================================
display _n _dup(60) "-"
display "BUG 4: tvcalendar range-based merge"
display _dup(60) "-"

* ---------------------------------------------------------------------------
* Test 4.1: Basic range-based merge with non-overlapping periods
* ---------------------------------------------------------------------------
display _n "Test 4.1: Range-based merge with non-overlapping periods"

capture {
    * Create external period data
    clear
    quietly set obs 2
    gen double period_start = .
    gen double period_end = .
    gen double policy_level = .
    * Period 1: Jan-Jun 2020, policy level 1
    quietly replace period_start = mdy(1, 1, 2020) if _n == 1
    quietly replace period_end = mdy(6, 30, 2020) if _n == 1
    quietly replace policy_level = 1 if _n == 1
    * Period 2: Jul-Dec 2020, policy level 2
    quietly replace period_start = mdy(7, 1, 2020) if _n == 2
    quietly replace period_end = mdy(12, 31, 2020) if _n == 2
    quietly replace policy_level = 2 if _n == 2
    format period_start period_end %td
    tempfile ext_data
    quietly save `ext_data', replace

    * Create master person-time data
    clear
    quietly set obs 4
    gen double id = 1
    gen double datevar = .
    quietly replace datevar = mdy(3, 15, 2020) if _n == 1
    quietly replace datevar = mdy(5, 20, 2020) if _n == 2
    quietly replace datevar = mdy(8, 10, 2020) if _n == 3
    quietly replace datevar = mdy(11, 25, 2020) if _n == 4
    format datevar %td

    * Run tvcalendar with range-based merge
    tvcalendar using `ext_data', datevar(datevar) ///
        startvar(period_start) stopvar(period_end) ///
        merge(policy_level)

    * Verify: first two dates should get policy_level = 1
    assert policy_level[1] == 1
    assert policy_level[2] == 1
    * Last two dates should get policy_level = 2
    assert policy_level[3] == 2
    assert policy_level[4] == 2
}
if _rc == 0 {
    display as result "  PASS"
    local ++pass_count
}
else {
    display as error "  FAIL (rc = " _rc ")"
    local ++fail_count
    local failed_tests "`failed_tests' 4.1"
}

* ---------------------------------------------------------------------------
* Test 4.2: Range-based merge with unmatched observations
* ---------------------------------------------------------------------------
display _n "Test 4.2: Range-based merge - unmatched obs kept with missing"

capture {
    * External periods: only covers first half of year
    clear
    quietly set obs 1
    gen double period_start = mdy(1, 1, 2020)
    gen double period_end = mdy(6, 30, 2020)
    gen double season = 1
    format period_start period_end %td
    tempfile ext_data
    quietly save `ext_data', replace

    * Master data: dates in both first and second half
    clear
    quietly set obs 3
    gen double id = _n
    gen double datevar = .
    quietly replace datevar = mdy(3, 15, 2020) if _n == 1
    quietly replace datevar = mdy(5, 20, 2020) if _n == 2
    quietly replace datevar = mdy(9, 10, 2020) if _n == 3
    format datevar %td

    tvcalendar using `ext_data', datevar(datevar) ///
        startvar(period_start) stopvar(period_end) merge(season)

    * First two should have season = 1
    assert season[1] == 1
    assert season[2] == 1
    * Third should be missing (unmatched)
    assert missing(season[3])

    * All 3 observations should be preserved
    assert _N == 3
}
if _rc == 0 {
    display as result "  PASS"
    local ++pass_count
}
else {
    display as error "  FAIL (rc = " _rc ")"
    local ++fail_count
    local failed_tests "`failed_tests' 4.2"
}

* ---------------------------------------------------------------------------
* Test 4.3: Range-based merge with multiple external variables
* ---------------------------------------------------------------------------
display _n "Test 4.3: Range-based merge with multiple merge variables"

capture {
    clear
    quietly set obs 2
    gen double period_start = .
    gen double period_end = .
    gen double temp_avg = .
    gen double precip_mm = .
    * Summer
    quietly replace period_start = mdy(4, 1, 2020) if _n == 1
    quietly replace period_end = mdy(9, 30, 2020) if _n == 1
    quietly replace temp_avg = 25 if _n == 1
    quietly replace precip_mm = 80 if _n == 1
    * Winter
    quietly replace period_start = mdy(10, 1, 2020) if _n == 2
    quietly replace period_end = mdy(3, 31, 2021) if _n == 2
    quietly replace temp_avg = 5 if _n == 2
    quietly replace precip_mm = 120 if _n == 2
    format period_start period_end %td
    tempfile ext_data
    quietly save `ext_data', replace

    * Master data
    clear
    quietly set obs 2
    gen double id = _n
    gen double datevar = .
    quietly replace datevar = mdy(7, 15, 2020) if _n == 1
    quietly replace datevar = mdy(12, 1, 2020) if _n == 2
    format datevar %td

    tvcalendar using `ext_data', datevar(datevar) ///
        startvar(period_start) stopvar(period_end) ///
        merge(temp_avg precip_mm)

    * Summer observation
    assert temp_avg[1] == 25
    assert precip_mm[1] == 80
    * Winter observation
    assert temp_avg[2] == 5
    assert precip_mm[2] == 120
}
if _rc == 0 {
    display as result "  PASS"
    local ++pass_count
}
else {
    display as error "  FAIL (rc = " _rc ")"
    local ++fail_count
    local failed_tests "`failed_tests' 4.3"
}

* ---------------------------------------------------------------------------
* Test 4.4: Point-in-time merge still works (regression check)
* ---------------------------------------------------------------------------
display _n "Test 4.4: Point-in-time merge still works (regression)"

capture {
    clear
    quietly set obs 3
    gen double datevar = mdy(1, 1, 2020) + _n - 1
    gen double id = _n
    format datevar %td

    * Create external data with exact date match
    clear
    quietly set obs 3
    gen double datevar = mdy(1, 1, 2020) + _n - 1
    gen double factor = _n * 10
    format datevar %td
    tempfile ext_data
    quietly save `ext_data', replace

    * Re-create master
    clear
    quietly set obs 3
    gen double datevar = mdy(1, 1, 2020) + _n - 1
    gen double id = _n
    format datevar %td

    tvcalendar using `ext_data', datevar(datevar) merge(factor)

    assert factor[1] == 10
    assert factor[2] == 20
    assert factor[3] == 30
}
if _rc == 0 {
    display as result "  PASS"
    local ++pass_count
}
else {
    display as error "  FAIL (rc = " _rc ")"
    local ++fail_count
    local failed_tests "`failed_tests' 4.4"
}

* =============================================================================
* SUMMARY
* =============================================================================
display _n _dup(70) "="
display "VALIDATION SUMMARY"
display _dup(70) "="
local total = `pass_count' + `fail_count'
display "Total:  `total'"
display "Passed: `pass_count'"
display "Failed: `fail_count'"

if `fail_count' > 0 {
    display as error "FAILED TESTS: `failed_tests'"
    exit 1
}
else {
    display as result "ALL TESTS PASSED"
}
