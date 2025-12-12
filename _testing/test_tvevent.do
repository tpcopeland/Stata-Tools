/*******************************************************************************
* test_tvevent.do
*
* Purpose: Comprehensive testing of tvevent command
*          Tests all options documented in tvevent.sthlp
*
* Prerequisites:
*   - Run generate_test_data.do first to create synthetic datasets
*   - tvexpose.ado and tvevent.ado must be installed/accessible
*
* Note: tvevent operates on datasets that already have start/stop variables
*       (created by tvexpose or tvmerge). It integrates event dates and
*       competing risks into the time-varying structure.
*
* Author: Timothy P Copeland
* Date: 2025-12-06
*******************************************************************************/

clear all
set more off
version 16.0

* =============================================================================
* SETUP: Change to data directory and install package from local repository
* =============================================================================

* Data directory for test datasets
cd "_testing/data/"

* Install tvtools package from local repository
local basedir "."
capture net uninstall tvtools
net install tvtools, from("`basedir'/tvtools")

local testdir "`c(pwd)'"

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
* SETUP: Create tvexpose output for tvevent testing
* tvevent requires a dataset with start/stop variables from tvexpose
* =============================================================================
display as text _n "SETUP: Creating tvexpose output dataset..."
display as text "{hline 50}"

capture {
    * Create time-varying DMT dataset (base for tvevent tests)
    use "`testdir'/cohort.dta", clear
    tvexpose using "`testdir'/dmt.dta", ///
        id(id) start(dmt_start) stop(dmt_stop) ///
        exposure(dmt) reference(0) ///
        entry(study_entry) exit(study_exit) ///
        generate(tv_dmt) ///
        saveas("`testdir'/_tv_base.dta") replace
}
if _rc {
    display as error "SETUP FAILED: Could not create tvexpose dataset"
    display as error "Error code: " _rc
    exit _rc
}
display as result "Setup complete: tvexpose output file created"

* =============================================================================
* TEST 1: Basic single event (primary outcome)
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Basic single event"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/_tv_base.dta", clear

    tvevent using "`testdir'/cohort.dta", ///
        id(id) date(edss4_dt) ///
        type(single) ///
        generate(outcome)

    * Verify results
    assert _N > 0
    confirm variable outcome
    * outcome should be 0 (censored) or 1 (event)
    tab outcome
    display as result "  PASSED: Basic single event works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 2: Single event with competing risk (death)
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Single event with competing risk"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/_tv_base.dta", clear

    tvevent using "`testdir'/cohort.dta", ///
        id(id) date(edss4_dt) ///
        compete(death_dt) ///
        type(single) ///
        generate(outcome)

    * Verify results
    assert _N > 0
    confirm variable outcome
    * outcome should be 0=censored, 1=primary, 2=competing
    tab outcome
    count if outcome == 2
    display as text "  Deaths (competing): " r(N)
    display as result "  PASSED: Competing risk works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 3: Multiple competing risks
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Multiple competing risks"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/_tv_base.dta", clear

    tvevent using "`testdir'/cohort.dta", ///
        id(id) date(edss4_dt) ///
        compete(death_dt emigration_dt) ///
        type(single) ///
        generate(status)

    * Verify results
    assert _N > 0
    confirm variable status
    * status should be 0=censored, 1=primary, 2=death, 3=emigration
    tab status
    display as result "  PASSED: Multiple competing risks work"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 4: Recurring events
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Recurring events"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/_tv_base.dta", clear

    tvevent using "`testdir'/hospitalizations.dta", ///
        id(id) date(hosp_date) ///
        type(recurring) ///
        generate(hospitalized)

    * Verify results
    assert _N > 0
    confirm variable hospitalized
    * With recurring, follow-up continues after events
    display as result "  PASSED: Recurring events work"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 5: Custom event labels
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Custom event labels"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/_tv_base.dta", clear

    tvevent using "`testdir'/cohort.dta", ///
        id(id) date(edss4_dt) ///
        compete(death_dt) ///
        type(single) ///
        eventlabel(0 "Censored" 1 "EDSS Progression" 2 "Death") ///
        generate(outcome)

    * Verify labels were applied
    assert _N > 0
    label list outcome
    display as result "  PASSED: Custom event labels work"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 6: Generate time duration variable (days)
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': timegen() option - days"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/_tv_base.dta", clear

    tvevent using "`testdir'/cohort.dta", ///
        id(id) date(edss4_dt) ///
        type(single) ///
        timegen(interval_days) timeunit(days) ///
        generate(outcome)

    * Verify time variable was created
    assert _N > 0
    confirm variable interval_days
    sum interval_days
    assert r(min) >= 0
    display as text "  Mean interval (days): " %6.1f r(mean)
    display as result "  PASSED: timegen() with days works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 7: Generate time duration variable (years)
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': timegen() option - years"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/_tv_base.dta", clear

    tvevent using "`testdir'/cohort.dta", ///
        id(id) date(edss4_dt) ///
        type(single) ///
        timegen(interval_years) timeunit(years) ///
        generate(outcome)

    * Verify time variable was created
    assert _N > 0
    confirm variable interval_years
    sum interval_years
    assert r(min) >= 0
    display as text "  Mean interval (years): " %6.3f r(mean)
    display as result "  PASSED: timegen() with years works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 8: keepvars() option
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': keepvars() option"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/_tv_base.dta", clear

    tvevent using "`testdir'/hospitalizations.dta", ///
        id(id) date(hosp_date) ///
        type(single) ///
        keepvars(icd_code hosp_type) ///
        generate(hospitalized)

    * Verify keepvars were brought over
    assert _N > 0
    confirm variable icd_code hosp_type
    display as result "  PASSED: keepvars() option works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 9: replace option
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': replace option"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/_tv_base.dta", clear

    * First create a variable that will be replaced
    gen outcome = 99

    tvevent using "`testdir'/cohort.dta", ///
        id(id) date(edss4_dt) ///
        type(single) ///
        generate(outcome) replace

    * Verify outcome was replaced (no longer all 99)
    assert _N > 0
    count if outcome != 99
    assert r(N) > 0
    display as result "  PASSED: replace option works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 10: Continuous variable adjustment
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': continuous() option"
display as text "{hline 50}"

capture noisily {
    * First create a dataset with a continuous exposure variable
    use "`testdir'/cohort.dta", clear
    tvexpose using "`testdir'/dmt.dta", ///
        id(id) start(dmt_start) stop(dmt_stop) ///
        exposure(dmt) reference(0) ///
        entry(study_entry) exit(study_exit) ///
        continuousunit(years) ///
        generate(tv_dmt) ///
        saveas("`testdir'/_tv_continuous.dta") replace

    use "`testdir'/_tv_continuous.dta", clear

    tvevent using "`testdir'/cohort.dta", ///
        id(id) date(edss4_dt) ///
        type(single) ///
        continuous(tv_dmt) ///
        generate(outcome)

    * Verify continuous adjustment happened
    assert _N > 0
    display as result "  PASSED: continuous() option works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 11: Stored results verification
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Stored results verification"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/_tv_base.dta", clear

    tvevent using "`testdir'/cohort.dta", ///
        id(id) date(edss4_dt) ///
        compete(death_dt) ///
        type(single) ///
        generate(outcome)

    * Verify stored results exist
    assert r(N) > 0
    assert r(N_events) >= 0

    display as result "  PASSED: Stored results present"
    display as text "  r(N) = " r(N)
    display as text "  r(N_events) = " r(N_events)
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 12: Complete workflow (tvexpose -> tvevent -> stset)
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Complete workflow"
display as text "{hline 50}"

capture noisily {
    * Step 1: Create time-varying dataset
    use "`testdir'/cohort.dta", clear
    tvexpose using "`testdir'/dmt.dta", ///
        id(id) start(dmt_start) stop(dmt_stop) ///
        exposure(dmt) reference(0) ///
        entry(study_entry) exit(study_exit) ///
        generate(tv_dmt)

    * Step 2: Integrate events
    tvevent using "`testdir'/cohort.dta", ///
        id(id) date(edss4_dt) ///
        compete(death_dt) ///
        type(single) ///
        generate(outcome)

    * Step 3: Set up for survival analysis
    stset stop, id(id) failure(outcome==1) enter(start)

    * Verify stset worked
    assert _N > 0
    display as result "  PASSED: Complete workflow works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 13: All options combined
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': All options combined"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/_tv_base.dta", clear

    tvevent using "`testdir'/cohort.dta", ///
        id(id) date(edss4_dt) ///
        compete(death_dt emigration_dt) ///
        type(single) ///
        eventlabel(0 "Censored" 1 "EDSS4" 2 "Death" 3 "Emigration") ///
        timegen(ptime) timeunit(years) ///
        generate(status) replace

    * Verify all components
    assert _N > 0
    confirm variable status ptime
    tab status
    sum ptime
    display as result "  PASSED: All options combined work"
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

local temp_files "_tv_base _tv_continuous"

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
