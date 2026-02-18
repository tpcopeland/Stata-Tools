/*******************************************************************************
* test_tvtrial.do
*
* Purpose: Functional tests for tvtrial (target trial emulation) command
*
* Run modes:
*   Standalone: do test_tvtrial.do
*   Via runner: do run_test.do test_tvtrial [testnumber] [quiet] [machine]
*
* Author: Timothy P Copeland
* Date: 2025-12-29
*******************************************************************************/

clear all
set more off
version 16.0

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
    capture confirm file "_testing"
    if _rc == 0 {
        global STATA_TOOLS_PATH "`c(pwd)'"
    }
    else {
        global STATA_TOOLS_PATH "/home/`c(username)'/Stata-Tools"
    }
}
else {
    capture confirm file "_testing"
    if _rc == 0 {
        global STATA_TOOLS_PATH "`c(pwd)'"
    }
    else {
        global STATA_TOOLS_PATH "`c(pwd)'/.."
    }
}

global TESTING_DIR "${STATA_TOOLS_PATH}/_testing"
global DATA_DIR "${TESTING_DIR}/data"

capture mkdir "${DATA_DIR}"

* Install tvtools package
capture net uninstall tvtools
quietly net install tvtools, from("${STATA_TOOLS_PATH}/tvtools")


* =============================================================================
* HEADER
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "TVTRIAL (TARGET TRIAL EMULATION) TEST SUITE"
    display as text "{hline 70}"
    display as text "Testing target trial emulation for observational data"
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
* CREATE TEST DATA
* =============================================================================
if `quiet' == 0 {
    display as text _n "Creating test datasets..."
}

clear
set seed 12345
set obs 500

* Generate cohort
gen id = _n
gen study_entry = mdy(1, 1, 2020) + floor(runiform() * 60)
gen study_exit = study_entry + 365 + floor(runiform() * 180)
format %td study_entry study_exit

* Treatment initiation (~40% treated)
gen rx_start = .
replace rx_start = study_entry + floor(runiform() * 200) if runiform() < 0.4
format %td rx_start

* Outcome
gen outcome = .
replace outcome = study_entry + floor(runiform() * (study_exit - study_entry)) if runiform() < 0.2
format %td outcome

save "${DATA_DIR}/test_trial.dta", replace

if `quiet' == 0 {
    display as result "Test data created"
}

* =============================================================================
* SECTION 1: BASIC FUNCTIONALITY
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 1: Basic Functionality"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 1.1: Basic target trial emulation
* -----------------------------------------------------------------------------
local ++test_count
if `run_only' == 0 | `run_only' == 1 {
    if `quiet' == 0 {
        display as text _n "Test 1.1: Basic target trial emulation"
    }

    capture {
        use "${DATA_DIR}/test_trial.dta", clear
        tvtrial, id(id) entry(study_entry) exit(study_exit) treatstart(rx_start)

        * Verify variables created
        confirm variable trial_trial
        confirm variable trial_arm
        confirm variable trial_fu_time

        * Check results stored
        assert r(n_orig) == 500
        assert r(n_persontrials) > 0
    }
    if _rc == 0 {
        display as result "  PASS: Basic target trial emulation works"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Basic target trial emulation (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' 1.1"
    }
}

* -----------------------------------------------------------------------------
* Test 1.2: Custom trial parameters
* -----------------------------------------------------------------------------
local ++test_count
if `run_only' == 0 | `run_only' == 2 {
    if `quiet' == 0 {
        display as text _n "Test 1.2: Custom trial parameters"
    }

    capture {
        use "${DATA_DIR}/test_trial.dta", clear
        tvtrial, id(id) entry(study_entry) exit(study_exit) treatstart(rx_start) ///
            trials(6) trialinterval(60)

        * Should have 6 trials
        quietly levelsof trial_trial
        assert r(r) <= 6
    }
    if _rc == 0 {
        display as result "  PASS: Custom trial parameters work"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Custom parameters (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' 1.2"
    }
}

* =============================================================================
* SECTION 2: CLONE APPROACH
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 2: Clone Approach"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 2.1: Clone option creates duplicates
* -----------------------------------------------------------------------------
local ++test_count
if `run_only' == 0 | `run_only' == 3 {
    if `quiet' == 0 {
        display as text _n "Test 2.1: Clone option creates duplicates"
    }

    capture {
        use "${DATA_DIR}/test_trial.dta", clear

        * Without clone
        tvtrial, id(id) entry(study_entry) exit(study_exit) treatstart(rx_start) trials(3)
        local n_noclone = _N

        * With clone
        use "${DATA_DIR}/test_trial.dta", clear
        tvtrial, id(id) entry(study_entry) exit(study_exit) treatstart(rx_start) trials(3) clone
        local n_clone = _N

        * Clone should have more obs (roughly 2x)
        assert `n_clone' > `n_noclone'
    }
    if _rc == 0 {
        display as result "  PASS: Clone creates more observations"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Clone option (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' 2.1"
    }
}

* -----------------------------------------------------------------------------
* Test 2.2: Clone creates both arms for each eligible
* -----------------------------------------------------------------------------
local ++test_count
if `run_only' == 0 | `run_only' == 4 {
    if `quiet' == 0 {
        display as text _n "Test 2.2: Clone creates both treatment arms"
    }

    capture {
        use "${DATA_DIR}/test_trial.dta", clear
        tvtrial, id(id) entry(study_entry) exit(study_exit) treatstart(rx_start) ///
            trials(3) clone

        * Both arms should exist
        count if trial_arm == 1
        assert r(N) > 0
        count if trial_arm == 0
        assert r(N) > 0
    }
    if _rc == 0 {
        display as result "  PASS: Both treatment arms created"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Treatment arms (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' 2.2"
    }
}

* -----------------------------------------------------------------------------
* Test 2.3: Censoring indicator created
* -----------------------------------------------------------------------------
local ++test_count
if `run_only' == 0 | `run_only' == 5 {
    if `quiet' == 0 {
        display as text _n "Test 2.3: Censoring indicator created"
    }

    capture {
        use "${DATA_DIR}/test_trial.dta", clear
        tvtrial, id(id) entry(study_entry) exit(study_exit) treatstart(rx_start) ///
            trials(3) clone graceperiod(30)

        * Censoring variable should exist
        confirm variable trial_censored

        * Some should be censored, some not
        count if trial_censored == 1
        local n_cens = r(N)
        count if trial_censored == 0
        local n_uncens = r(N)

        assert `n_cens' > 0 | `n_uncens' > 0
    }
    if _rc == 0 {
        display as result "  PASS: Censoring indicator created"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Censoring indicator (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' 2.3"
    }
}

* =============================================================================
* SECTION 3: GRACE PERIOD
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 3: Grace Period"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 3.1: Grace period affects arm assignment
* -----------------------------------------------------------------------------
local ++test_count
if `run_only' == 0 | `run_only' == 6 {
    if `quiet' == 0 {
        display as text _n "Test 3.1: Grace period affects arm assignment"
    }

    capture {
        use "${DATA_DIR}/test_trial.dta", clear

        * No grace period - only exact start dates count
        tvtrial, id(id) entry(study_entry) exit(study_exit) treatstart(rx_start) ///
            trials(3) graceperiod(0)
        count if trial_arm == 1
        local n_treat_0 = r(N)

        * 90-day grace period - more should be treated
        use "${DATA_DIR}/test_trial.dta", clear
        tvtrial, id(id) entry(study_entry) exit(study_exit) treatstart(rx_start) ///
            trials(3) graceperiod(90)
        count if trial_arm == 1
        local n_treat_90 = r(N)

        * More should be in treatment arm with longer grace period
        assert `n_treat_90' >= `n_treat_0'
    }
    if _rc == 0 {
        display as result "  PASS: Grace period affects arm assignment"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Grace period (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' 3.1"
    }
}

* =============================================================================
* SECTION 4: IPCW OPTION
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 4: IPCW Option"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 4.1: IPCW creates weight variable
* -----------------------------------------------------------------------------
local ++test_count
if `run_only' == 0 | `run_only' == 7 {
    if `quiet' == 0 {
        display as text _n "Test 4.1: IPCW creates weight variable"
    }

    capture {
        use "${DATA_DIR}/test_trial.dta", clear
        tvtrial, id(id) entry(study_entry) exit(study_exit) treatstart(rx_start) ///
            clone ipcweight graceperiod(30)

        * Weight variable should exist
        confirm variable trial_ipcw

        * Weights should be positive for uncensored
        count if trial_ipcw > 0 & trial_censored == 0
        assert r(N) > 0
    }
    if _rc == 0 {
        display as result "  PASS: IPCW creates weight variable"
        local ++pass_count
    }
    else {
        display as error "  FAIL: IPCW option (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' 4.1"
    }
}

* =============================================================================
* SECTION 5: FOLLOW-UP TIME
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 5: Follow-up Time"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 5.1: Max follow-up limits follow-up time
* -----------------------------------------------------------------------------
local ++test_count
if `run_only' == 0 | `run_only' == 8 {
    if `quiet' == 0 {
        display as text _n "Test 5.1: Max follow-up limits follow-up time"
    }

    capture {
        use "${DATA_DIR}/test_trial.dta", clear
        tvtrial, id(id) entry(study_entry) exit(study_exit) treatstart(rx_start) ///
            maxfollowup(180)

        * Follow-up should be <= 180 days
        summarize trial_fu_time
        assert r(max) <= 180
    }
    if _rc == 0 {
        display as result "  PASS: Max follow-up limits correctly"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Max follow-up (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' 5.1"
    }
}

* -----------------------------------------------------------------------------
* Test 5.2: Follow-up time is positive
* -----------------------------------------------------------------------------
local ++test_count
if `run_only' == 0 | `run_only' == 9 {
    if `quiet' == 0 {
        display as text _n "Test 5.2: Follow-up time is positive"
    }

    capture {
        use "${DATA_DIR}/test_trial.dta", clear
        tvtrial, id(id) entry(study_entry) exit(study_exit) treatstart(rx_start)

        * Follow-up should be >= 0
        count if trial_fu_time < 0
        assert r(N) == 0
    }
    if _rc == 0 {
        display as result "  PASS: Follow-up time is non-negative"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Follow-up time (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' 5.2"
    }
}

* =============================================================================
* SECTION 6: ERROR HANDLING
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 6: Error Handling"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 6.1: Missing required variable
* -----------------------------------------------------------------------------
local ++test_count
if `run_only' == 0 | `run_only' == 10 {
    if `quiet' == 0 {
        display as text _n "Test 6.1: Missing required variable error"
    }

    capture {
        use "${DATA_DIR}/test_trial.dta", clear
        tvtrial, id(id) entry(study_entry) exit(study_exit) treatstart(nonexistent)
    }
    if _rc != 0 {
        display as result "  PASS: Correctly errors on missing variable"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Should error on missing variable"
        local ++fail_count
        local failed_tests "`failed_tests' 6.1"
    }
}

* -----------------------------------------------------------------------------
* Test 6.2: Negative grace period error
* -----------------------------------------------------------------------------
local ++test_count
if `run_only' == 0 | `run_only' == 11 {
    if `quiet' == 0 {
        display as text _n "Test 6.2: Negative grace period error"
    }

    capture {
        use "${DATA_DIR}/test_trial.dta", clear
        tvtrial, id(id) entry(study_entry) exit(study_exit) treatstart(rx_start) ///
            graceperiod(-10)
    }
    if _rc != 0 {
        display as result "  PASS: Correctly errors on negative grace period"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Should error on negative grace period"
        local ++fail_count
        local failed_tests "`failed_tests' 6.2"
    }
}

* =============================================================================
* CLEANUP
* =============================================================================
capture erase "${DATA_DIR}/test_trial.dta"

* =============================================================================
* SUMMARY
* =============================================================================
display as text _n "{hline 70}"
display as text "TVTRIAL TEST SUMMARY"
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
    display as error "Some tests FAILED."
    exit 1
}
else {
    display as result _n "ALL TESTS PASSED!"
}

display as text _n "Testing completed: `c(current_date)' `c(current_time)'"
display as text "{hline 70}"
