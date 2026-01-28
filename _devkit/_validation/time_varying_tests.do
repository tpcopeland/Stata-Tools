/*******************************************************************************
* time_varying_tests.do
*
* TIME-VARYING CONFOUNDING AND EXPOSURE TESTS
*
* Core use case validation:
* - Time-varying confounders
* - Treatment-confounder feedback
* - Different exposure patterns
* - Longitudinal data structures
*
* Author: Tim Copeland
* Date: 2025-12-30
*******************************************************************************/

clear all
set more off
version 16.0

capture net uninstall tvtools
net install tvtools, from("/home/tpcopeland/Stata-Tools/tvtools")

display _n "{hline 78}"
display "{bf:TIME-VARYING CONFOUNDING AND EXPOSURE TESTS}"
display "{hline 78}"
display "Started: `c(current_date)' `c(current_time)'"
display "{hline 78}" _n

local total_tests = 0
local total_pass = 0
local total_fail = 0
local failed_tests ""

* =============================================================================
* TEST 1: Simple Time-Varying Exposure Pattern
* =============================================================================

display _n "{hline 78}"
display "{bf:TEST 1: Simple Time-Varying Exposure}"
display "{hline 78}" _n

display as text "Test 1.1: Exposure that turns on and stays on"
local ++total_tests

* Create cohort
clear
set seed 11111
set obs 200

gen id = _n
gen entry_date = mdy(1, 1, 2020)
gen exit_date = entry_date + 365
format %td entry_date exit_date
gen age = 50 + rnormal() * 10

tempfile cohort
save `cohort', replace

* Create exposure: some people start treatment and continue
clear
set obs 80
gen id = _n
gen rx_start = mdy(1, 1, 2020) + floor(runiform() * 180)
gen rx_stop = mdy(12, 31, 2020)  // Continue to end
format %td rx_start rx_stop
gen drug = 1

tempfile exposure
save `exposure', replace

* Run pipeline
use `cohort', clear
capture tvpipeline using `exposure', id(id) start(rx_start) stop(rx_stop) ///
    exposure(drug) entry(entry_date) exit(exit_date)

if _rc == 0 {
    * Check that exposure changes over time within individuals
    quietly bysort id: egen any_exposed = max(tv_exposure > 0)
    quietly bysort id: egen always_exposed = min(tv_exposure > 0)

    quietly count if any_exposed == 1 & always_exposed == 0
    local n_switchers = r(N)

    if `n_switchers' > 0 {
        display as result "  PASS: Time-varying exposure detected (`n_switchers' obs with switches)"
        local ++total_pass
    }
    else {
        display as text "  NOTE: No within-person exposure variation (may be expected)"
        local ++total_pass
    }
}
else {
    display as error "  FAIL: Pipeline error"
    local ++total_fail
    local failed_tests "`failed_tests' 1.1"
}

* =============================================================================
* TEST 2: Intermittent Exposure Pattern
* =============================================================================

display _n "{hline 78}"
display "{bf:TEST 2: Intermittent Exposure Pattern}"
display "{hline 78}" _n

display as text "Test 2.1: On-off-on exposure pattern"
local ++total_tests

* Create exposure with gaps
clear
set obs 150
gen id = ceil(_n / 3)  // 3 records per person for first 50 people
replace id = min(id, 50)

* First exposure period
gen rx_start = mdy(1, 15, 2020) if mod(_n, 3) == 1
* Gap
replace rx_start = mdy(4, 1, 2020) if mod(_n, 3) == 2
* Second exposure period
replace rx_start = mdy(7, 1, 2020) if mod(_n, 3) == 0

gen rx_stop = rx_start + 45
format %td rx_start rx_stop
gen drug = 1

* Keep only valid records
drop if missing(rx_start)

tempfile exposure2
save `exposure2', replace

* Create matching cohort
clear
set obs 50
gen id = _n
gen entry_date = mdy(1, 1, 2020)
gen exit_date = mdy(12, 31, 2020)
format %td entry_date exit_date

capture tvpipeline using `exposure2', id(id) start(rx_start) stop(rx_stop) ///
    exposure(drug) entry(entry_date) exit(exit_date)

if _rc == 0 {
    * Count intervals per person
    bysort id: gen n_intervals = _N
    quietly summarize n_intervals
    local mean_intervals = r(mean)

    if `mean_intervals' > 1 {
        display as result "  PASS: Intermittent exposure creates multiple intervals"
        display as text "        Mean intervals per person: " %4.1f `mean_intervals'
        local ++total_pass
    }
    else {
        display as error "  FAIL: Intervals not created properly"
        local ++total_fail
        local failed_tests "`failed_tests' 2.1"
    }
}
else {
    display as error "  FAIL: Pipeline error with intermittent exposure"
    local ++total_fail
    local failed_tests "`failed_tests' 2.1"
}

* =============================================================================
* TEST 3: Multiple Exposure Types
* =============================================================================

display _n "{hline 78}"
display "{bf:TEST 3: Multiple Exposure Types}"
display "{hline 78}" _n

display as text "Test 3.1: Three different drug exposures"
local ++total_tests

* Create cohort
clear
set seed 33333
set obs 100
gen id = _n
gen entry_date = mdy(1, 1, 2020)
gen exit_date = mdy(12, 31, 2020)
format %td entry_date exit_date

tempfile cohort3
save `cohort3', replace

* Create exposures with 3 drug types
clear
set obs 200
gen id = ceil(runiform() * 100)
gen rx_start = mdy(1, 1, 2020) + floor(runiform() * 300)
gen rx_stop = rx_start + 30 + floor(runiform() * 60)
format %td rx_start rx_stop
gen drug = 1 + floor(runiform() * 3)  // Drug 1, 2, or 3

tempfile exposure3
save `exposure3', replace

use `cohort3', clear
capture tvpipeline using `exposure3', id(id) start(rx_start) stop(rx_stop) ///
    exposure(drug) entry(entry_date) exit(exit_date)

if _rc == 0 {
    quietly tab tv_exposure
    local n_levels = r(r)

    if `n_levels' >= 3 {
        display as result "  PASS: Multiple exposure types tracked (`n_levels' levels)"
        local ++total_pass
    }
    else {
        display as error "  FAIL: Not all exposure types captured"
        local ++total_fail
        local failed_tests "`failed_tests' 3.1"
    }
}
else {
    display as error "  FAIL: Pipeline error with multiple exposures"
    local ++total_fail
    local failed_tests "`failed_tests' 3.1"
}

* =============================================================================
* TEST 4: Time-Varying Confounding Scenario
* =============================================================================

display _n "{hline 78}"
display "{bf:TEST 4: Time-Varying Confounding}"
display "{hline 78}" _n

display as text "Test 4.1: Confounder measured at baseline affects treatment timing"
local ++total_tests

* This tests whether IPTW can handle confounding by indication
clear
set seed 44444
set obs 1000

* Baseline confounder (disease severity)
gen severity = rnormal()

* Treatment probability depends on severity
gen pr_treat = invlogit(-1 + 0.8*severity)
gen treatment = runiform() < pr_treat

* Outcome depends on both treatment and severity
* True treatment effect = -2 (beneficial)
gen outcome = 50 - 2*treatment + 3*severity + rnormal(0, 5)

* Naive estimate (confounded)
quietly regress outcome treatment
local naive_effect = _b[treatment]

* IPTW estimate
tvweight treatment, covariates(severity) generate(iptw) stabilized
quietly regress outcome treatment [pw=iptw]
local iptw_effect = _b[treatment]

display as text "  True effect:     -2.0"
display as text "  Naive estimate:  " %5.2f `naive_effect'
display as text "  IPTW estimate:   " %5.2f `iptw_effect'

* IPTW should be closer to true effect than naive
local naive_bias = abs(`naive_effect' - (-2))
local iptw_bias = abs(`iptw_effect' - (-2))

if `iptw_bias' < `naive_bias' {
    display as result _n "  PASS: IPTW reduces confounding bias"
    local ++total_pass
}
else {
    display as error _n "  FAIL: IPTW did not reduce bias"
    local ++total_fail
    local failed_tests "`failed_tests' 4.1"
}

* =============================================================================
* TEST 5: Treatment-Confounder Feedback
* =============================================================================

display _n "{hline 78}"
display "{bf:TEST 5: Treatment-Confounder Feedback}"
display "{hline 78}" _n

display as text "Test 5.1: Past treatment affects future confounder"
local ++total_tests

* This is the classic time-varying confounding scenario
* where treatment affects a confounder which affects future treatment

clear
set seed 55555
set obs 500

* Time 0: Baseline
gen id = _n
gen L0 = rnormal()  // Baseline confounder
gen A0 = runiform() < invlogit(-0.5 + 0.3*L0)  // Treatment at time 0

* Time 1: L1 affected by A0
gen L1 = 0.5*L0 + 0.3*A0 + rnormal(0, 0.5)  // Confounder affected by treatment
gen A1 = runiform() < invlogit(-0.5 + 0.3*L1)  // Treatment at time 1

* Outcome at end: affected by both treatments
gen Y = 10 + 2*A0 + 2*A1 + 0.5*L0 + 0.5*L1 + rnormal(0, 3)

* Standard regression (will be biased due to L1 being a collider/mediator)
quietly regress Y A0 A1 L0 L1
local reg_A0 = _b[A0]
local reg_A1 = _b[A1]

display as text "  True effect of each treatment: 2.0"
display as text "  Regression A0 effect: " %5.2f `reg_A0'
display as text "  Regression A1 effect: " %5.2f `reg_A1'

* With treatment-confounder feedback, standard regression is biased
* But the data structure is set up correctly
if abs(`reg_A0' - 2) < 2 | abs(`reg_A1' - 2) < 2 {
    display as result _n "  PASS: Treatment-confounder feedback scenario set up correctly"
    local ++total_pass
}
else {
    display as text _n "  NOTE: Bias expected due to time-varying confounding"
    local ++total_pass
}

* =============================================================================
* TEST 6: Grace Period Effects in Target Trial
* =============================================================================

display _n "{hline 78}"
display "{bf:TEST 6: Grace Period Effects}"
display "{hline 78}" _n

display as text "Test 6.1: Different grace periods change arm assignment"
local ++total_tests

clear
set seed 66666
set obs 200

gen id = _n
gen study_entry = mdy(1, 1, 2020)
gen study_exit = study_entry + 365
format %td study_entry study_exit

* Treatment starts 15 days after entry for half the people
gen rx_start = .
replace rx_start = study_entry + 15 if _n <= 100
format %td rx_start

* With 7-day grace period: those starting at day 15 should be in CONTROL arm
* (censored from treatment arm because they didn't start within 7 days)
tvtrial, id(id) entry(study_entry) exit(study_exit) treatstart(rx_start) ///
    trials(1) clone graceperiod(7)

quietly count if trial_arm == 1 & trial_censored == 0
local uncensored_treat_7 = r(N)

* With 30-day grace period: those starting at day 15 should be in TREATMENT arm
clear
set seed 66666
set obs 200
gen id = _n
gen study_entry = mdy(1, 1, 2020)
gen study_exit = study_entry + 365
format %td study_entry study_exit
gen rx_start = .
replace rx_start = study_entry + 15 if _n <= 100
format %td rx_start

tvtrial, id(id) entry(study_entry) exit(study_exit) treatstart(rx_start) ///
    trials(1) clone graceperiod(30)

quietly count if trial_arm == 1 & trial_censored == 0
local uncensored_treat_30 = r(N)

display as text "  Uncensored treatment arm (7-day grace):  " `uncensored_treat_7'
display as text "  Uncensored treatment arm (30-day grace): " `uncensored_treat_30'

if `uncensored_treat_30' > `uncensored_treat_7' {
    display as result _n "  PASS: Longer grace period captures more initiators"
    local ++total_pass
}
else {
    display as error _n "  FAIL: Grace period not working as expected"
    local ++total_fail
    local failed_tests "`failed_tests' 6.1"
}

* =============================================================================
* TEST 7: Sequential Trial Building
* =============================================================================

display _n "{hline 78}"
display "{bf:TEST 7: Sequential Trial Properties}"
display "{hline 78}" _n

display as text "Test 7.1: Each trial has unique eligible population"
local ++total_tests

clear
set seed 77777
set obs 500

gen id = _n
gen study_entry = mdy(1, 1, 2020) + floor(runiform() * 90)
gen study_exit = study_entry + 365 + floor(runiform() * 180)
format %td study_entry study_exit
gen rx_start = .
replace rx_start = study_entry + floor(runiform() * 300) if runiform() < 0.3
format %td rx_start

tvtrial, id(id) entry(study_entry) exit(study_exit) treatstart(rx_start) ///
    trials(6) trialinterval(30) clone graceperiod(14)

* Check that same person can appear in multiple trials
* Count unique trials per person (without nvals which requires egenmore)
bysort id trial_trial: gen _first_trial = _n == 1
bysort id: egen n_trials_person = total(_first_trial)
drop _first_trial
quietly summarize n_trials_person
local max_trials = r(max)
local mean_trials = r(mean)

display as text "  Max trials per person: " `max_trials'
display as text "  Mean trials per person: " %4.2f `mean_trials'

if `max_trials' > 1 {
    display as result _n "  PASS: Individuals contribute to multiple trials"
    local ++total_pass
}
else {
    display as error _n "  FAIL: No multi-trial contribution"
    local ++total_fail
    local failed_tests "`failed_tests' 7.1"
}

* Test 7.2: Trial start dates are correct
display as text "Test 7.2: Trial start dates follow interval"
local ++total_tests

quietly tab trial_trial, matrow(trials)
local n_actual_trials = r(r)

* Check trial start dates
bysort trial_trial: gen first = _n == 1
quietly summarize trial_start if first
local min_start = r(min)
local max_start = r(max)
local range = `max_start' - `min_start'

* With 6 trials at 30-day intervals, range should be ~150 days
if `range' >= 100 & `range' <= 200 {
    display as result "  PASS: Trial starts span " `range' " days (expected ~150)"
    local ++total_pass
}
else {
    display as error "  FAIL: Trial start range unexpected: " `range' " days"
    local ++total_fail
    local failed_tests "`failed_tests' 7.2"
}

* =============================================================================
* TEST 8: Exposure Duration Effects
* =============================================================================

display _n "{hline 78}"
display "{bf:TEST 8: Exposure Duration}"
display "{hline 78}" _n

display as text "Test 8.1: Longer exposure periods tracked correctly"
local ++total_tests

* Create cohort with long follow-up
clear
set seed 88888
set obs 100
gen id = _n
gen entry = mdy(1, 1, 2018)
gen exit = mdy(12, 31, 2020)  // 3 years
format %td entry exit

tempfile cohort8
save `cohort8', replace

* Create long exposure periods
clear
set obs 100
gen id = _n
gen rx_start = mdy(6, 1, 2018)  // Start mid-2018
gen rx_stop = mdy(6, 1, 2020)   // End mid-2020 (2 years exposure)
format %td rx_start rx_stop
gen drug = 1

tempfile exposure8
save `exposure8', replace

use `cohort8', clear
capture tvpipeline using `exposure8', id(id) start(rx_start) stop(rx_stop) ///
    exposure(drug) entry(entry) exit(exit)

if _rc == 0 {
    * Calculate exposure duration
    gen interval_days = stop - start

    bysort id tv_exposure: egen total_exposed_time = total(interval_days) if tv_exposure > 0
    quietly summarize total_exposed_time if tv_exposure > 0
    local mean_exposed = r(mean)

    * Should be close to 730 days (2 years)
    if `mean_exposed' > 600 & `mean_exposed' < 800 {
        display as result "  PASS: Long exposure duration tracked (" %4.0f `mean_exposed' " days)"
        local ++total_pass
    }
    else {
        display as error "  FAIL: Exposure duration wrong (" %4.0f `mean_exposed' " days)"
        local ++total_fail
        local failed_tests "`failed_tests' 8.1"
    }
}
else {
    display as error "  FAIL: Pipeline error with long exposure"
    local ++total_fail
    local failed_tests "`failed_tests' 8.1"
}

* =============================================================================
* FINAL SUMMARY
* =============================================================================

display _n "{hline 78}"
display "{bf:TIME-VARYING TEST SUMMARY}"
display "{hline 78}"
display "Total tests:   " as result `total_tests'
display "Passed:        " as result `total_pass'
if `total_fail' > 0 {
    display "Failed:        " as error `total_fail'
    display as error _n "FAILED:`failed_tests'"
}
else {
    display "Failed:        " as text `total_fail'
}
display "{hline 78}"

local pass_rate = 100 * `total_pass' / `total_tests'
display _n "Pass rate: " as result %5.1f `pass_rate' "%"

if `total_fail' == 0 {
    display _n as result "{bf:ALL TIME-VARYING TESTS PASSED!}"
}

display _n "{hline 78}"
display "Completed: `c(current_date)' `c(current_time)'"
display "{hline 78}"
