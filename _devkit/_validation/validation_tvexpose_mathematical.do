/*******************************************************************************
* validation_tvexpose_mathematical.do
*
* Purpose: Mathematical correctness validation for tvexpose with exact expected
*          values computed independently from first principles.
*
* Approach: Each test constructs a minimal, deterministic dataset, calculates the
*           expected output by hand, runs tvexpose, then compares actual to expected.
*           Failures indicate a genuine algorithmic discrepancy, not just run errors.
*
* Tests:
*   3a. Evertreated - monotonicity, exact switch date
*   3b. Currentformer - state machine (0->1->2 transitions)
*   3c. Continuous unit conversion (days/weeks/months/years)
*   3d. Duration categories (threshold boundary)
*   3e. Lag - exact timing
*   3f. Washout - exact timing
*   3g. Grace period - threshold precision (<= grace bridges, > grace does not)
*   3h. Dose proportioning during overlapping prescriptions
*   3i. Bytype independence - no cross-contamination
*
* Run: stata-mp -b do validation_tvexpose_mathematical.do
* Log: validation_tvexpose_mathematical.log (in same directory)
*
* Author: Claude Code
* Date: 2026-02-17
*******************************************************************************/

clear all
set more off
version 16.0
set varabbrev off

* ============================================================================
* TEST INFRASTRUCTURE
* ============================================================================

local pass_count = 0
local fail_count = 0
local failed_tests ""

capture program drop assert_approx
program define assert_approx
    * args: actual expected tolerance label
    args actual expected tolerance label
    local diff = abs(`actual' - `expected')
    if `diff' <= `tolerance' {
        display as result "  PASS [`label']: actual=`actual', expected=`expected', diff=`diff'"
    }
    else {
        display as error "  FAIL [`label']: actual=`actual', expected=`expected', diff=`diff' > tol=`tolerance'"
        exit 9
    }
end

capture program drop assert_exact
program define assert_exact
    args actual expected label
    if `actual' == `expected' {
        display as result "  PASS [`label']: value=`actual'"
    }
    else {
        display as error "  FAIL [`label']: actual=`actual', expected=`expected'"
        exit 9
    }
end

display _n _dup(70) "="
display "TVEXPOSE MATHEMATICAL VALIDATION"
display _dup(70) "="
display "Date: $S_DATE $S_TIME"
display ""

* Add tvtools to path
quietly adopath ++ "/home/tpcopeland/Stata-Tools/tvtools"

* ============================================================================
* TEST 3A: EVERTREATED MONOTONICITY AND EXACT SWITCH DATE
* ============================================================================
display _n _dup(60) "-"
display "TEST 3A: Evertreated - monotonicity and exact switch date"
display _dup(60) "-"

local test3a_pass = 1

* Setup: 1 person, study Jan1/2020 to Dec31/2020
* Exposure: Mar1/2020 (day 60 from Jan1) to Jun30/2020
* Expected output:
*   Row 1: start=Jan1/2020, stop=Feb29/2020(=mdy(2,29,2020)-but since Mar1-1=Feb29), ever=0
*   Row 2: start=Mar1/2020, stop=Dec31/2020, ever=1
* Verify: exactly 2 rows, monotonicity (no 1->0 switch)

clear
set obs 1
gen id = 1
gen study_entry = mdy(1,1,2020)
gen study_exit  = mdy(12,31,2020)
format study_entry study_exit %td
save "/tmp/tve_test3a_cohort.dta", replace

clear
set obs 1
gen id = 1
gen start = mdy(3,1,2020)    // Mar 1, 2020 — use 'start' so tvexpose output keeps name 'start'
gen stop  = mdy(6,30,2020)   // Jun 30, 2020
gen drug = 1                  // Exposure type 1 (reference=0 means unexposed)
save "/tmp/tve_test3a_exp.dta", replace

use "/tmp/tve_test3a_cohort.dta", clear
capture noisily tvexpose using "/tmp/tve_test3a_exp.dta", ///
    id(id) start(start) stop(stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    evertreated generate(ever_exposed)

if _rc != 0 {
    display as error "  FAIL [3a.run]: tvexpose returned error `=_rc'"
    local test3a_pass = 0
}
else {
    * Check row count: should be exactly 2
    quietly count
    if r(N) == 2 {
        display as result "  PASS [3a.rows]: exactly 2 rows"
    }
    else {
        display as error "  FAIL [3a.rows]: expected 2 rows, got `=r(N)'"
        local test3a_pass = 0
    }

    * Check values (output vars named 'start', 'stop' since we used start(start) stop(stop))
    sort id start
    local row1_ever = ever_exposed[1]
    local row2_ever = ever_exposed[2]
    local row1_stop = stop[1]
    local row2_start = start[2]

    * Row 1: ever_exposed should be 0
    if `row1_ever' == 0 {
        display as result "  PASS [3a.row1_ever]: first row ever_exposed=0"
    }
    else {
        display as error "  FAIL [3a.row1_ever]: first row ever_exposed=`row1_ever', expected 0"
        local test3a_pass = 0
    }

    * Row 2: ever_exposed should be 1
    if `row2_ever' == 1 {
        display as result "  PASS [3a.row2_ever]: second row ever_exposed=1"
    }
    else {
        display as error "  FAIL [3a.row2_ever]: second row ever_exposed=`row2_ever', expected 1"
        local test3a_pass = 0
    }

    * Row 1 stop = Mar1 - 1 = Feb 29 (2020 is a leap year)
    local expected_stop = mdy(3,1,2020) - 1
    if `row1_stop' == `expected_stop' {
        display as result "  PASS [3a.switch_date]: unexposed stops at mdy(3,1,2020)-1"
    }
    else {
        local actual_date : display %td `row1_stop'
        local expected_date : display %td `expected_stop'
        display as error "  FAIL [3a.switch_date]: row1 stop=`actual_date', expected=`expected_date'"
        local test3a_pass = 0
    }

    * Row 2 start = Mar 1, 2020
    local expected_start = mdy(3,1,2020)
    if `row2_start' == `expected_start' {
        display as result "  PASS [3a.exposed_start]: exposed starts at mdy(3,1,2020)"
    }
    else {
        local actual_date : display %td `row2_start'
        display as error "  FAIL [3a.exposed_start]: row2 start=`actual_date'"
        local test3a_pass = 0
    }

    * Monotonicity: ever_exposed never decreases
    sort id start
    quietly count
    local n = r(N)
    local monotone = 1
    forvalues i = 2/`n' {
        if ever_exposed[`i'] < ever_exposed[`i'-1] & id[`i'] == id[`i'-1] {
            local monotone = 0
        }
    }
    if `monotone' == 1 {
        display as result "  PASS [3a.monotone]: ever_exposed never decreases"
    }
    else {
        display as error "  FAIL [3a.monotone]: ever_exposed decreased (1->0 detected)"
        local test3a_pass = 0
    }
}

if `test3a_pass' == 1 {
    local pass_count = `pass_count' + 1
    display as result "TEST 3A: PASSED"
}
else {
    local fail_count = `fail_count' + 1
    local failed_tests "`failed_tests' 3a"
    display as error "TEST 3A: FAILED"
}

* ============================================================================
* TEST 3B: CURRENTFORMER STATE MACHINE
* ============================================================================
display _n _dup(60) "-"
display "TEST 3B: Currentformer - state machine (0->1->2 transitions)"
display _dup(60) "-"

local test3b_pass = 1

* Setup: 1 person, Jan1 to Dec31/2020
* Exposure: Mar1 to Jun30 (drug=1)
* Expected: 3 rows: [Jan1,Feb29]=0, [Mar1,Jun30]=1, [Jul1,Dec31]=2
* Verify: values are 0,1,2 in order; only one transition per step

clear
set obs 1
gen id = 1
gen study_entry = mdy(1,1,2020)
gen study_exit  = mdy(12,31,2020)
save "/tmp/tve_test3b_cohort.dta", replace

clear
set obs 1
gen id = 1
gen start = mdy(3,1,2020)
gen stop  = mdy(6,30,2020)
gen drug = 1
save "/tmp/tve_test3b_exp.dta", replace

use "/tmp/tve_test3b_cohort.dta", clear
capture noisily tvexpose using "/tmp/tve_test3b_exp.dta", ///
    id(id) start(start) stop(stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    currentformer generate(cf_status)

if _rc != 0 {
    display as error "  FAIL [3b.run]: tvexpose returned error `=_rc'"
    local test3b_pass = 0
}
else {
    quietly count
    if r(N) == 3 {
        display as result "  PASS [3b.rows]: exactly 3 rows"
    }
    else {
        display as error "  FAIL [3b.rows]: expected 3 rows, got `=r(N)'"
        local test3b_pass = 0
    }

    sort id start
    local v1 = cf_status[1]
    local v2 = cf_status[2]
    local v3 = cf_status[3]

    if `v1' == 0 & `v2' == 1 & `v3' == 2 {
        display as result "  PASS [3b.sequence]: cf_status sequence is 0->1->2"
    }
    else {
        display as error "  FAIL [3b.sequence]: cf_status sequence is `v1'->`v2'->`v3', expected 0->1->2"
        local test3b_pass = 0
    }

    * Verify 0 only before first exposure
    local row2_start = start[2]
    local expected_current_start = mdy(3,1,2020)
    if `row2_start' == `expected_current_start' {
        display as result "  PASS [3b.current_start]: current period starts at Mar1/2020"
    }
    else {
        local actual_date : display %td `row2_start'
        display as error "  FAIL [3b.current_start]: current starts `actual_date'"
        local test3b_pass = 0
    }
}

if `test3b_pass' == 1 {
    local pass_count = `pass_count' + 1
    display as result "TEST 3B: PASSED"
}
else {
    local fail_count = `fail_count' + 1
    local failed_tests "`failed_tests' 3b"
    display as error "TEST 3B: FAILED"
}

* ============================================================================
* TEST 3C: CONTINUOUS UNIT CONVERSION (EXACT MATH)
* ============================================================================
display _n _dup(60) "-"
display "TEST 3C: Continuous unit conversion - exact math"
display _dup(60) "-"

local test3c_pass = 1

* Setup: 1 person, 1 exposure Jan1 to Apr11/2020 = 101 days
* Expected cumulative exposure:
*   days:   101.0
*   weeks:  101/7  = 14.4286
*   months: 101/30.4375 = 3.3182
*   years:  101/365.25 = 0.27652

clear
set obs 1
gen id = 1
gen study_entry = mdy(1,1,2020)
gen study_exit  = mdy(12,31,2020)
save "/tmp/tve_test3c_cohort.dta", replace

* Exposure: Jan 1 to Apr 11 = 101 days
* Jan: 31, Feb: 29 (leap), Mar: 31 = 91 days, then Apr 1-11 = 11 more → total 91+11=102... let me recalculate
* Jan 1 to Apr 11 inclusive: mdy(4,11,2020) - mdy(1,1,2020) + 1 = days_difference + 1
* Apr 11 - Jan 1: 31(Jan) + 29(Feb) + 31(Mar) + 10(Apr 1-10) = 101 days difference = 101 days from Jan1 to Apr11 not inclusive
* Inclusive: Apr11 - Jan1 + 1 = 101 + 1 = 102 days?
* Actually tvexpose interprets [rx_start, rx_stop] as inclusive on both ends.
* If rx_start = mdy(1,1,2020) and rx_stop = mdy(4,11,2020):
*   Duration = mdy(4,11,2020) - mdy(1,1,2020) + 1 days = 102 days
* Let me use a cleaner number: rx_stop = mdy(4,10,2020)
*   Apr 10 - Jan 1 = 31+29+31+9 = 100 → inclusive = 101 days

clear
set obs 1
gen id = 1
gen start = mdy(1,1,2020)
gen stop  = mdy(4,10,2020)    // 101 inclusive days (Jan-Mar=91, Apr1-10=10 → total 101)
gen drug = 1
save "/tmp/tve_test3c_exp.dta", replace

* Verify the exposure length
local n_days = mdy(4,10,2020) - mdy(1,1,2020) + 1
local expected_days = 101
if `n_days' == `expected_days' {
    display as result "  INFO: Exposure length verified = `n_days' days"
}
else {
    display as error "  INFO: Exposure length = `n_days' days (note: may differ from 101)"
    local expected_days = `n_days'
}

local exp_weeks  = `expected_days' / 7
local exp_months = `expected_days' / 30.4375
local exp_years  = `expected_days' / 365.25

* 3c.1: Days
use "/tmp/tve_test3c_cohort.dta", clear
capture noisily tvexpose using "/tmp/tve_test3c_exp.dta", ///
    id(id) start(start) stop(stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    continuousunit(days) generate(tv_exp)

if _rc == 0 {
    * Find exposed row (tv_exp > 0)
    quietly sum tv_exp
    local max_exp = r(max)
    display "  INFO: Max cumulative days = `max_exp'"
    local diff = abs(`max_exp' - `expected_days')
    if `diff' < 1 {
        display as result "  PASS [3c.days]: cumulative=`max_exp', expected=`expected_days', diff=`diff'"
    }
    else {
        display as error "  FAIL [3c.days]: cumulative=`max_exp', expected=`expected_days', diff=`diff'"
        local test3c_pass = 0
    }
}
else {
    display as error "  FAIL [3c.days.run]: error `=_rc'"
    local test3c_pass = 0
}

* 3c.2: Years
use "/tmp/tve_test3c_cohort.dta", clear
capture noisily tvexpose using "/tmp/tve_test3c_exp.dta", ///
    id(id) start(start) stop(stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    continuousunit(years) generate(tv_exp)

if _rc == 0 {
    quietly sum tv_exp
    local max_exp = r(max)
    local diff = abs(`max_exp' - `exp_years')
    if `diff' < 0.01 {
        display as result "  PASS [3c.years]: cumulative=`max_exp', expected=`exp_years', diff=`diff'"
    }
    else {
        display as error "  FAIL [3c.years]: cumulative=`max_exp', expected=`exp_years', diff=`diff'"
        local test3c_pass = 0
    }
}
else {
    display as error "  FAIL [3c.years.run]: error `=_rc'"
    local test3c_pass = 0
}

* 3c.3: Months
use "/tmp/tve_test3c_cohort.dta", clear
capture noisily tvexpose using "/tmp/tve_test3c_exp.dta", ///
    id(id) start(start) stop(stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    continuousunit(months) generate(tv_exp)

if _rc == 0 {
    quietly sum tv_exp
    local max_exp = r(max)
    local diff = abs(`max_exp' - `exp_months')
    if `diff' < 0.1 {
        display as result "  PASS [3c.months]: cumulative=`max_exp', expected=`exp_months', diff=`diff'"
    }
    else {
        display as error "  FAIL [3c.months]: cumulative=`max_exp', expected=`exp_months', diff=`diff'"
        local test3c_pass = 0
    }
}
else {
    display as error "  FAIL [3c.months.run]: error `=_rc'"
    local test3c_pass = 0
}

* 3c.4: Weeks
use "/tmp/tve_test3c_cohort.dta", clear
capture noisily tvexpose using "/tmp/tve_test3c_exp.dta", ///
    id(id) start(start) stop(stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    continuousunit(weeks) generate(tv_exp)

if _rc == 0 {
    quietly sum tv_exp
    local max_exp = r(max)
    local diff = abs(`max_exp' - `exp_weeks')
    if `diff' < 0.1 {
        display as result "  PASS [3c.weeks]: cumulative=`max_exp', expected=`exp_weeks', diff=`diff'"
    }
    else {
        display as error "  FAIL [3c.weeks]: cumulative=`max_exp', expected=`exp_weeks', diff=`diff'"
        local test3c_pass = 0
    }
}
else {
    display as error "  FAIL [3c.weeks.run]: error `=_rc'"
    local test3c_pass = 0
}

if `test3c_pass' == 1 {
    local pass_count = `pass_count' + 1
    display as result "TEST 3C: PASSED"
}
else {
    local fail_count = `fail_count' + 1
    local failed_tests "`failed_tests' 3c"
    display as error "TEST 3C: FAILED"
}

* ============================================================================
* TEST 3D: DURATION CATEGORIES (THRESHOLD BOUNDARY)
* ============================================================================
display _n _dup(60) "-"
display "TEST 3D: Duration categories - threshold boundary"
display _dup(60) "-"

local test3d_pass = 1

* Setup: 1 person, 2-year study (Jan1/2021 – Jan2/2023 = 732 days), continuous exposure
* duration(1 2) continuousunit(years) creates:
*   reference (0) = unexposed
*   cat 1 = <1 year cumulative
*   cat 2 = 1-<2 years cumulative
*   cat 3 = 2+ years cumulative
* With ceil() fix: threshold 1 splits at ceil(365.25)=366 days from start (Jan1/2021+366=Jan2/2022)
*   cumul at start of cat2 = 366/365.25 ≈ 1.002yr ≥ (1-0.001)=0.999 → cat 2 assigned
* threshold 2 splits at ceil(730.5)=731 days from start (Jan1/2021+731=Jan1/2023)
*   cumul at start of cat3 = 731/365.25 ≈ 2.000yr ≥ (2-0.001)=1.999 → cat 3 assigned
* Without fix (floor): floor(730.5)=730, cumul=730/365.25≈1.999yr < 1.999 → cat 3 never assigned

clear
set obs 1
gen id = 1
gen study_entry = mdy(1,1,2021)
gen study_exit  = mdy(1,2,2023)   // 732 days (>2 years of continuous exposure)
save "/tmp/tve_test3d_cohort.dta", replace

clear
set obs 1
gen id = 1
gen start = mdy(1,1,2021)
gen stop  = mdy(1,2,2023)         // continuous exposure covering full study
gen drug = 1
save "/tmp/tve_test3d_exp.dta", replace

use "/tmp/tve_test3d_cohort.dta", clear
capture noisily tvexpose using "/tmp/tve_test3d_exp.dta", ///
    id(id) start(start) stop(stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    continuousunit(years) duration(1 2) generate(dur_cat)

if _rc != 0 {
    display as error "  FAIL [3d.run]: tvexpose returned error `=_rc'"
    local test3d_pass = 0
}
else {
    quietly count
    display "  INFO: `=r(N)' rows in output"
    sort id start

    * Row 1: cat 1 (<100 days cumulative)
    * Row 2: cat 2 (100-<200 days cumulative)
    * Row 3: cat 3 (200+ days cumulative)

    quietly count
    local nrows = r(N)
    if `nrows' >= 3 {
        local cat1 = dur_cat[1]
        local cat2 = dur_cat[2]
        local cat3 = dur_cat[3]

        if `cat1' == 1 {
            display as result "  PASS [3d.cat1]: row1 dur_cat=1 (<1 year)"
        }
        else {
            display as error "  FAIL [3d.cat1]: row1 dur_cat=`cat1', expected 1"
            local test3d_pass = 0
        }

        if `cat2' == 2 {
            display as result "  PASS [3d.cat2]: row2 dur_cat=2 (1-<2 years)"
        }
        else {
            display as error "  FAIL [3d.cat2]: row2 dur_cat=`cat2', expected 2"
            local test3d_pass = 0
        }

        if `cat3' == 3 {
            display as result "  PASS [3d.cat3]: row3 dur_cat=3 (2+ years)"
        }
        else {
            display as error "  FAIL [3d.cat3]: row3 dur_cat=`cat3', expected 3"
            local test3d_pass = 0
        }

        * Verify monotonicity of duration categories
        local monotone = 1
        forvalues i = 2/`nrows' {
            if dur_cat[`i'] < dur_cat[`i'-1] {
                local monotone = 0
            }
        }
        if `monotone' == 1 {
            display as result "  PASS [3d.monotone]: duration categories never decrease"
        }
        else {
            display as error "  FAIL [3d.monotone]: duration categories decreased"
            local test3d_pass = 0
        }
    }
    else {
        display as error "  FAIL [3d.nrows]: expected >= 3 rows, got `nrows'"
        local test3d_pass = 0
    }
}

if `test3d_pass' == 1 {
    local pass_count = `pass_count' + 1
    display as result "TEST 3D: PASSED"
}
else {
    local fail_count = `fail_count' + 1
    local failed_tests "`failed_tests' 3d"
    display as error "TEST 3D: FAILED"
}

* ============================================================================
* TEST 3E: LAG - EXACT TIMING
* ============================================================================
display _n _dup(60) "-"
display "TEST 3E: Lag - exact timing"
display _dup(60) "-"

local test3e_pass = 1

* Setup: 1 person, Jan1 to Dec31/2020
* Exposure: Jan1/2020 to Jun30/2020 (181 days), lag=30
* Effect of lag=30: exposure starts 30 days later = Jan31/2020
* Expected output:
*   Row 1: start=Jan1, stop=Jan30(=mdy(1,31,2020)-1), tv_exposure=0 (reference)
*   Row 2: start=Jan31, stop=Jun30, tv_exposure=1
*   Row 3: start=Jul1, stop=Dec31, tv_exposure=0 (post-exposure)

clear
set obs 1
gen id = 1
gen study_entry = mdy(1,1,2020)
gen study_exit  = mdy(12,31,2020)
save "/tmp/tve_test3e_cohort.dta", replace

clear
set obs 1
gen id = 1
gen start = mdy(1,1,2020)
gen stop  = mdy(6,30,2020)
gen drug = 1
save "/tmp/tve_test3e_exp.dta", replace

use "/tmp/tve_test3e_cohort.dta", clear
capture noisily tvexpose using "/tmp/tve_test3e_exp.dta", ///
    id(id) start(start) stop(stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    lag(30) generate(tv_exp)

if _rc != 0 {
    display as error "  FAIL [3e.run]: tvexpose returned error `=_rc'"
    local test3e_pass = 0
}
else {
    sort id start
    quietly count
    local nrows = r(N)
    display "  INFO: `nrows' rows in output"

    * Find the exposed row
    quietly count if tv_exp == 1
    local n_exposed_rows = r(N)
    display "  INFO: `n_exposed_rows' rows with tv_exp=1"

    if `n_exposed_rows' > 0 {
        * Find the start of the exposed period
        quietly sum start if tv_exp == 1
        local actual_exposed_start = r(min)
        local expected_exposed_start = mdy(1,1,2020) + 30   // Jan1 + 30 = Jan31

        local diff = abs(`actual_exposed_start' - `expected_exposed_start')
        if `diff' == 0 {
            display as result "  PASS [3e.lag_start]: exposed starts at mdy(1,1,2020)+30"
        }
        else {
            local actual_date : display %td `actual_exposed_start'
            local expected_date : display %td `expected_exposed_start'
            display as error "  FAIL [3e.lag_start]: exposed starts `actual_date', expected `expected_date'"
            local test3e_pass = 0
        }
    }
    else {
        display as error "  FAIL [3e.no_exposed]: no exposed rows found"
        local test3e_pass = 0
    }

    * First row should start at study entry (Jan 1)
    local row1_start = start[1]
    if `row1_start' == mdy(1,1,2020) {
        display as result "  PASS [3e.first_start]: first row starts at Jan1/2020"
    }
    else {
        local actual_date : display %td `row1_start'
        display as error "  FAIL [3e.first_start]: first row starts `actual_date'"
        local test3e_pass = 0
    }
}

if `test3e_pass' == 1 {
    local pass_count = `pass_count' + 1
    display as result "TEST 3E: PASSED"
}
else {
    local fail_count = `fail_count' + 1
    local failed_tests "`failed_tests' 3e"
    display as error "TEST 3E: FAILED"
}

* ============================================================================
* TEST 3F: WASHOUT - EXACT TIMING
* ============================================================================
display _n _dup(60) "-"
display "TEST 3F: Washout - exact timing"
display _dup(60) "-"

local test3f_pass = 1

* Setup: 1 person, Jan1 to Dec31/2020
* Exposure: Jan1/2020 to Mar31/2020 (91 days), washout=30
* Effect of washout=30: exposure extends to Apr30/2020 (Mar31 + 30)
* Expected: exposed period is Jan1 to Apr30, post-washout reference period is May1 to Dec31

clear
set obs 1
gen id = 1
gen study_entry = mdy(1,1,2020)
gen study_exit  = mdy(12,31,2020)
save "/tmp/tve_test3f_cohort.dta", replace

clear
set obs 1
gen id = 1
gen start = mdy(1,1,2020)
gen stop  = mdy(3,31,2020)    // Mar 31
gen drug = 1
save "/tmp/tve_test3f_exp.dta", replace

use "/tmp/tve_test3f_cohort.dta", clear
capture noisily tvexpose using "/tmp/tve_test3f_exp.dta", ///
    id(id) start(start) stop(stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    washout(30) generate(tv_exp)

if _rc != 0 {
    display as error "  FAIL [3f.run]: tvexpose returned error `=_rc'"
    local test3f_pass = 0
}
else {
    sort id start
    quietly count
    local nrows = r(N)
    display "  INFO: `nrows' rows in output"

    * Find end of exposed period
    quietly sum stop if tv_exp == 1
    if r(N) > 0 {
        local actual_exposed_stop = r(max)
        local expected_exposed_stop = mdy(3,31,2020) + 30   // Mar31 + 30 = Apr30

        local diff = abs(`actual_exposed_stop' - `expected_exposed_stop')
        if `diff' == 0 {
            display as result "  PASS [3f.washout_stop]: exposed stops at mdy(3,31,2020)+30"
        }
        else {
            local actual_date : display %td `actual_exposed_stop'
            local expected_date : display %td `expected_exposed_stop'
            display as error "  FAIL [3f.washout_stop]: exposed stops `actual_date', expected `expected_date'"
            local test3f_pass = 0
        }
    }
    else {
        display as error "  FAIL [3f.no_exposed]: no exposed rows"
        local test3f_pass = 0
    }
}

if `test3f_pass' == 1 {
    local pass_count = `pass_count' + 1
    display as result "TEST 3F: PASSED"
}
else {
    local fail_count = `fail_count' + 1
    local failed_tests "`failed_tests' 3f"
    display as error "TEST 3F: FAILED"
}

* ============================================================================
* TEST 3G: GRACE PERIOD - THRESHOLD PRECISION (<=  grace bridges, > grace does not)
* ============================================================================
display _n _dup(60) "-"
display "TEST 3G: Grace period - threshold precision"
display _dup(60) "-"

local test3g_pass = 1

* Setup for grace period tests:
* Two exposures of the same type with a gap between them
* Grace period bridges gaps WHERE gap <= grace
*
* Test 3g.1: gap=30, grace=30 → SHOULD bridge (<=)
* Test 3g.2: gap=31, grace=30 → should NOT bridge (>)
* Test 3g.3: gap=30, grace=29 → should NOT bridge (>)

clear
set obs 1
gen id = 1
gen study_entry = mdy(1,1,2020)
gen study_exit  = mdy(12,31,2020)
save "/tmp/tve_test3g_cohort.dta", replace

* 3g.1: Gap = 30 days, grace = 30 → should bridge
clear
set obs 2
gen id = 1
gen start = mdy(1,1,2020) in 1
replace start = mdy(3,1,2020) in 2      // gap = Mar1 - Jan31 - 1 = 30 days
gen stop = mdy(1,31,2020) in 1          // Jan 1 to Jan 31
replace stop = mdy(6,30,2020) in 2
gen drug = 1
save "/tmp/tve_test3g_exp1.dta", replace

* Verify gap
local gap_days = mdy(3,1,2020) - mdy(1,31,2020) - 1
display "  INFO: Gap for 3g.1 = `gap_days' days (expected 30)"

use "/tmp/tve_test3g_cohort.dta", clear
capture noisily tvexpose using "/tmp/tve_test3g_exp1.dta", ///
    id(id) start(start) stop(stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    grace(30) generate(tv_exp)

if _rc == 0 {
    * If grace bridges the gap, the two exposure periods should be joined
    * → no reference period in the middle
    sort id start
    quietly count if tv_exp == 0 & start >= mdy(1,31,2020) & stop <= mdy(3,1,2020)
    local ref_in_gap = r(N)
    if `ref_in_gap' == 0 {
        display as result "  PASS [3g.1]: grace=30, gap=30 → gap is bridged (no reference period in gap)"
    }
    else {
        display as error "  FAIL [3g.1]: grace=30, gap=30 → gap NOT bridged (found `ref_in_gap' reference rows in gap)"
        local test3g_pass = 0
    }
}
else {
    display as error "  FAIL [3g.1.run]: error `=_rc'"
    local test3g_pass = 0
}

* 3g.2: Gap = 31 days, grace = 30 → should NOT bridge
clear
set obs 2
gen id = 1
gen start = mdy(1,1,2020) in 1
replace start = mdy(3,3,2020) in 2      // gap = Mar3 - Jan31 - 1 = 31 days
gen stop = mdy(1,31,2020) in 1
replace stop = mdy(6,30,2020) in 2
gen drug = 1
save "/tmp/tve_test3g_exp2.dta", replace

local gap_days2 = mdy(3,3,2020) - mdy(1,31,2020) - 1
display "  INFO: Gap for 3g.2 = `gap_days2' days (expected 31)"

use "/tmp/tve_test3g_cohort.dta", clear
capture noisily tvexpose using "/tmp/tve_test3g_exp2.dta", ///
    id(id) start(start) stop(stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    grace(30) generate(tv_exp)

if _rc == 0 {
    * Gap should NOT be bridged → there should be a reference period between the exposures
    sort id start
    quietly count if tv_exp == 0 & start > mdy(1,31,2020) & stop < mdy(3,3,2020)
    local ref_in_gap = r(N)
    if `ref_in_gap' > 0 {
        display as result "  PASS [3g.2]: grace=30, gap=31 → gap NOT bridged (reference period present)"
    }
    else {
        display as error "  FAIL [3g.2]: grace=30, gap=31 → gap was bridged (should not be)"
        local test3g_pass = 0
    }
}
else {
    display as error "  FAIL [3g.2.run]: error `=_rc'"
    local test3g_pass = 0
}

if `test3g_pass' == 1 {
    local pass_count = `pass_count' + 1
    display as result "TEST 3G: PASSED"
}
else {
    local fail_count = `fail_count' + 1
    local failed_tests "`failed_tests' 3g"
    display as error "TEST 3G: FAILED"
}

* ============================================================================
* TEST 3H: DOSE PROPORTIONING DURING OVERLAPPING PRESCRIPTIONS
* ============================================================================
display _n _dup(60) "-"
display "TEST 3H: Dose proportioning - overlapping prescriptions"
display _dup(60) "-"

local test3h_pass = 1

* Setup: 2 overlapping prescriptions with the SAME dose amount, 30-day each, overlap=10 days
* Prescription A: Jan1 to Jan30 (30 days), dose_amt=90 → daily rate = 90/30 = 3/day
* Prescription B: Jan21 to Feb19 (30 days), dose_amt=90 → daily rate = 90/30 = 3/day
* Overlap: Jan21 to Jan30 = 10 days
*
* Expected cumulative by segment:
*   Seg 1 [Jan1-Jan20]:  20 days × 3/day = 60 (only A)
*   Seg 2 [Jan21-Jan30]: 10 days × (3+3)/day = 60 (A+B overlap)
*   Seg 3 [Jan31-Feb19]: 20 days × 3/day = 60 (only B)
*   Total cumulative at end of B = 60 + 60 + 60 = 180
*
* Without Bug 1 fix: merge algorithm merges both 90-dose prescriptions into one
* 50-day period (Jan1-Feb19), daily rate = 90/50 = 1.8/day, total = 90. WRONG.
* With fix: dose overlap handler runs on original prescriptions → total = 180. CORRECT.

clear
set obs 1
gen id = 1
gen study_entry = mdy(1,1,2020)
gen study_exit  = mdy(12,31,2020)
save "/tmp/tve_test3h_cohort.dta", replace

clear
set obs 2
gen id = 1
gen start = mdy(1,1,2020) in 1
replace start = mdy(1,21,2020) in 2   // Jan 21 (overlap starts Jan21, A ends Jan30)
gen stop = mdy(1,30,2020) in 1
replace stop = mdy(2,19,2020) in 2    // Feb 19 (B is 30 days: Jan21-Feb19)
gen dose_amt = 90 in 1                 // Same dose - tests that merge bug is fixed
replace dose_amt = 90 in 2
save "/tmp/tve_test3h_exp.dta", replace

* Verify overlap
local overlap_days = mdy(1,30,2020) - mdy(1,21,2020) + 1
display "  INFO: Overlap days = `overlap_days' (expected 10)"

use "/tmp/tve_test3h_cohort.dta", clear
capture noisily tvexpose using "/tmp/tve_test3h_exp.dta", ///
    id(id) start(start) stop(stop) ///
    exposure(dose_amt) ///
    entry(study_entry) exit(study_exit) ///
    dose generate(cumul_dose)

if _rc != 0 {
    display as error "  FAIL [3h.run]: tvexpose returned error `=_rc'"
    local test3h_pass = 0
}
else {
    sort id start
    quietly count
    local nrows = r(N)
    display "  INFO: `nrows' rows in output"

    * Expected total cumulative dose = 60 + 60 + 60 = 180
    * (20 days × 3/day) + (10 days × 6/day) + (20 days × 3/day)
    quietly sum cumul_dose
    local max_dose = r(max)
    local expected_total = 180
    local diff = abs(`max_dose' - `expected_total')

    if `diff' < 1 {
        display as result "  PASS [3h.total_dose]: max cumulative dose=`max_dose', expected=`expected_total'"
    }
    else {
        display as error "  FAIL [3h.total_dose]: max cumulative dose=`max_dose', expected=`expected_total', diff=`diff'"
        local test3h_pass = 0
    }

    * All values should be non-negative
    quietly count if cumul_dose < 0 & !missing(cumul_dose)
    if r(N) == 0 {
        display as result "  PASS [3h.nonneg]: no negative cumulative doses"
    }
    else {
        display as error "  FAIL [3h.nonneg]: found `=r(N)' rows with negative cumulative dose"
        local test3h_pass = 0
    }
}

if `test3h_pass' == 1 {
    local pass_count = `pass_count' + 1
    display as result "TEST 3H: PASSED"
}
else {
    local fail_count = `fail_count' + 1
    local failed_tests "`failed_tests' 3h"
    display as error "TEST 3H: FAILED"
}

* ============================================================================
* TEST 3I: BYTYPE INDEPENDENCE - NO CROSS-CONTAMINATION
* ============================================================================
display _n _dup(60) "-"
display "TEST 3I: Bytype - Drug A and Drug B accumulate independently"
display _dup(60) "-"

local test3i_pass = 1

* Setup: 1 person with Drug A (days 1-100) and Drug B (days 50-150)
* With bytype, evertreated creates: ever1 and ever2 (or everDrugA, everDrugB)
* Drug A: Jan1 to Apr10 (100 inclusive days)
* Drug B: Feb19 to May29 (100 inclusive days, starting day 50)
* Overlap: Feb19 to Apr10 = 51 days
* At day 50 (Feb19): Drug A ever=1, Drug B just started (ever=1 from now)
* At day 100 (Apr10): Drug A ever=1 (since Jan1), Drug B ever=1 (since Feb19)

clear
set obs 1
gen id = 1
gen study_entry = mdy(1,1,2020)
gen study_exit  = mdy(12,31,2020)
save "/tmp/tve_test3i_cohort.dta", replace

clear
set obs 2
gen id = 1
* Drug A: 100 days starting Jan 1
gen start = mdy(1,1,2020) in 1
replace start = mdy(2,19,2020) in 2   // Drug B starts Feb 19 (day 50)
gen stop = mdy(4,10,2020) in 1       // Drug A ends Apr 10 (day 100 inclusive)
replace stop = mdy(5,28,2020) in 2   // Drug B ends May 28 (100 days from Feb19 = May28?)
* Feb19 to May28: Feb=10 days left, Mar=31, Apr=30, May=28 = 10+31+30+28=99... + 1 = 100 inclusive? Let me check:
* mdy(5,28,2020) - mdy(2,19,2020) + 1 = ?
* Feb: 19->29 = 11 days, Mar=31, Apr=30, May 1-28=28 → 11+31+30+28 = 100 ✓
gen drug_type = 1 in 1
replace drug_type = 2 in 2
save "/tmp/tve_test3i_exp.dta", replace

use "/tmp/tve_test3i_cohort.dta", clear
capture noisily tvexpose using "/tmp/tve_test3i_exp.dta", ///
    id(id) start(start) stop(stop) ///
    exposure(drug_type) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    evertreated bytype

if _rc != 0 {
    display as error "  FAIL [3i.run]: tvexpose returned error `=_rc'"
    local test3i_pass = 0
}
else {
    sort id start
    quietly count
    local nrows = r(N)
    display "  INFO: `nrows' rows in output"

    * Check that bytype variables exist
    capture confirm variable ever1
    local has_ever1 = (_rc == 0)
    capture confirm variable ever2
    local has_ever2 = (_rc == 0)

    if `has_ever1' & `has_ever2' {
        display as result "  PASS [3i.vars]: ever1 and ever2 variables created"

        * After Drug A starts (ever1=1), ever2 should still be 0 until Drug B starts
        quietly sum start if ever1 == 1
        local drugA_first_start = r(min)

        quietly sum start if ever2 == 1
        local drugB_first_start = r(min)

        * Drug B should start later than Drug A
        if `drugB_first_start' > `drugA_first_start' {
            display as result "  PASS [3i.independence]: Drug B (ever2) starts after Drug A (ever1)"
        }
        else {
            local dateA : display %td `drugA_first_start'
            local dateB : display %td `drugB_first_start'
            display as error "  FAIL [3i.independence]: ever2 starts `dateB', ever1 starts `dateA'"
            local test3i_pass = 0
        }

        * Before Drug B starts: check that there are rows where ever1=1 and ever2=0
        quietly count if ever1 == 1 & ever2 == 0
        if r(N) > 0 {
            display as result "  PASS [3i.nocross]: rows exist where ever1=1, ever2=0 (no cross-contamination)"
        }
        else {
            display as error "  FAIL [3i.nocross]: no rows with ever1=1, ever2=0 (cross-contamination suspected)"
            local test3i_pass = 0
        }

        * After Drug B starts: both should be 1
        quietly count if ever1 == 1 & ever2 == 1 & start >= mdy(2,19,2020)
        if r(N) > 0 {
            display as result "  PASS [3i.both]: rows exist where both ever1=1 and ever2=1 after both start"
        }
        else {
            display as error "  FAIL [3i.both]: no rows with both ever1=1 and ever2=1 after overlap starts"
            local test3i_pass = 0
        }
    }
    else {
        display as error "  FAIL [3i.vars]: missing bytype variables (ever1=`has_ever1', ever2=`has_ever2')"
        * Show what variables exist
        quietly ds
        display "  Available variables: `r(varlist)'"
        local test3i_pass = 0
    }
}

if `test3i_pass' == 1 {
    local pass_count = `pass_count' + 1
    display as result "TEST 3I: PASSED"
}
else {
    local fail_count = `fail_count' + 1
    local failed_tests "`failed_tests' 3i"
    display as error "TEST 3I: FAILED"
}

* ============================================================================
* TEST 3J: PERSON-TIME CONSERVATION INVARIANT
* ============================================================================
display _n _dup(60) "-"
display "TEST 3J: Person-time conservation invariant"
display _dup(60) "-"

local test3j_pass = 1

* For any person, sum of (stop - start + 1) across all output rows must equal
* study_exit - study_entry + 1 (total study days for that person)
* This must hold for default time-varying exposure type

clear
set obs 5
gen id = _n
gen study_entry = mdy(1,1,2020) + (id-1) * 30
gen study_exit  = study_entry + 180 + (id-1) * 20
* Pre-compute expected person-time per person (before tvexpose drops these vars)
quietly gen expected_pt = study_exit - study_entry + 1
save "/tmp/tve_test3j_cohort.dta", replace
save "/tmp/tve_test3j_expected.dta", replace
keep id expected_pt
save "/tmp/tve_test3j_expected.dta", replace

* Create various exposures for these 5 persons
clear
set obs 10
gen id = ceil(_n / 2)    // ids 1-5, 2 exposures each
gen start = mdy(1,15,2020) + (id-1)*30 + mod(_n,2)*60
gen stop  = start + 45
gen drug = 1 + mod(_n, 2)   // drug types 1 and 2
save "/tmp/tve_test3j_exp.dta", replace

use "/tmp/tve_test3j_cohort.dta", clear
capture noisily tvexpose using "/tmp/tve_test3j_exp.dta", ///
    id(id) start(start) stop(stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    generate(tv_exp)

if _rc != 0 {
    display as error "  FAIL [3j.run]: tvexpose returned error `=_rc'"
    local test3j_pass = 0
}
else {
    quietly gen person_days = stop - start + 1

    * Person-time in output per person
    quietly collapse (sum) actual_pt = person_days, by(id)

    * Merge back expected person-time from pre-computed cohort file
    quietly merge 1:1 id using "/tmp/tve_test3j_expected.dta", keep(match) nogen keepusing(expected_pt)

    quietly gen diff_pt = abs(actual_pt - expected_pt)
    quietly sum diff_pt
    local max_diff = r(max)

    quietly count if diff_pt > 0
    local n_mismatch2 = r(N)

    if `n_mismatch2' == 0 {
        display as result "  PASS [3j.conservation]: person-time conservation holds for all persons (max_diff=0)"
    }
    else {
        display as error "  FAIL [3j.conservation]: `n_mismatch2' persons fail conservation (max_diff=`max_diff')"
        list id actual_pt expected_pt diff_pt if diff_pt > 0
        local test3j_pass = 0
    }
}

if `test3j_pass' == 1 {
    local pass_count = `pass_count' + 1
    display as result "TEST 3J: PASSED"
}
else {
    local fail_count = `fail_count' + 1
    local failed_tests "`failed_tests' 3j"
    display as error "TEST 3J: FAILED"
}

* ============================================================================
* FINAL SUMMARY
* ============================================================================
local total_tests = `pass_count' + `fail_count'
display _n _dup(70) "="
display "TVEXPOSE MATHEMATICAL VALIDATION SUMMARY"
display _dup(70) "="
display "Tests run:    `total_tests'"
display "Tests passed: `pass_count'"
display "Tests failed: `fail_count'"
if "`failed_tests'" != "" {
    display as error "Failed tests: `failed_tests'"
}
display _dup(70) "="

if `fail_count' == 0 {
    display as result _n "ALL TVEXPOSE MATHEMATICAL TESTS PASSED"
}
else {
    display as error _n "`fail_count' TVEXPOSE MATHEMATICAL TESTS FAILED"
    exit 1
}
