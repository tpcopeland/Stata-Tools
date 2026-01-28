/*******************************************************************************
* helpfile_validation.do
*
* HELP FILE EXAMPLE VALIDATION
*
* Runs all examples from command help files to ensure they work correctly.
* This catches documentation/code mismatches.
*
* Author: Tim Copeland
* Date: 2025-12-30
*******************************************************************************/

clear all
set more off
version 16.0

* Reinstall tvtools
capture net uninstall tvtools
net install tvtools, from("/home/tpcopeland/Stata-Tools/tvtools")

display _n "{hline 78}"
display "{bf:HELP FILE EXAMPLE VALIDATION}"
display "{hline 78}"
display "Started: `c(current_date)' `c(current_time)'"
display "{hline 78}" _n

local total_tests = 0
local total_pass = 0
local total_fail = 0
local failed_tests ""

* =============================================================================
* TEST 1: tvweight Help Examples
* =============================================================================

display _n "{hline 78}"
display "{bf:TEST 1: tvweight.sthlp Examples}"
display "{hline 78}" _n

* Example 1: Basic IPTW
display as text "Example 1.1: Basic IPTW weights"
local ++total_tests

capture {
    clear
    set seed 12345
    set obs 1000
    gen age = 50 + rnormal(0, 10)
    gen sex = runiform() > 0.5
    gen treatment = runiform() < invlogit(-1 + 0.02*age + 0.3*sex)

    tvweight treatment, covariates(age sex) generate(iptw)
    confirm variable iptw
}

if _rc == 0 {
    display as result "  PASS"
    local ++total_pass
}
else {
    display as error "  FAIL (error `=_rc')"
    local ++total_fail
    local failed_tests "`failed_tests' tvweight-1"
}

* Example 2: Stabilized weights
display as text "Example 1.2: Stabilized weights"
local ++total_tests

capture {
    tvweight treatment, covariates(age sex) generate(siptw) stabilized
    confirm variable siptw
}

if _rc == 0 {
    display as result "  PASS"
    local ++total_pass
}
else {
    display as error "  FAIL (error `=_rc')"
    local ++total_fail
    local failed_tests "`failed_tests' tvweight-2"
}

* Example 3: Truncated weights
display as text "Example 1.3: Truncated weights"
local ++total_tests

capture {
    tvweight treatment, covariates(age sex) generate(tiptw) truncate(1 99)
    confirm variable tiptw
}

if _rc == 0 {
    display as result "  PASS"
    local ++total_pass
}
else {
    display as error "  FAIL (error `=_rc')"
    local ++total_fail
    local failed_tests "`failed_tests' tvweight-3"
}

* =============================================================================
* TEST 2: tvestimate Help Examples
* =============================================================================

display _n "{hline 78}"
display "{bf:TEST 2: tvestimate.sthlp Examples}"
display "{hline 78}" _n

display as text "Example 2.1: Basic G-estimation"
local ++total_tests

capture {
    clear
    set seed 54321
    set obs 1000
    gen age = 50 + rnormal(0, 10)
    gen sex = runiform() > 0.5
    gen treatment = runiform() < invlogit(-1 + 0.02*age + 0.3*sex)
    gen outcome = 100 + 2*treatment + 0.5*age + rnormal(0, 10)

    tvestimate outcome treatment, confounders(age sex)
    assert e(psi) != .
}

if _rc == 0 {
    display as result "  PASS"
    local ++total_pass
}
else {
    display as error "  FAIL (error `=_rc')"
    local ++total_fail
    local failed_tests "`failed_tests' tvestimate-1"
}

* =============================================================================
* TEST 3: tvtrial Help Examples
* =============================================================================

display _n "{hline 78}"
display "{bf:TEST 3: tvtrial.sthlp Examples}"
display "{hline 78}" _n

display as text "Example 3.1: Basic target trial emulation"
local ++total_tests

capture {
    clear
    set seed 12345
    set obs 1000
    gen id = _n
    gen study_entry = mdy(1, 1, 2020) + floor(runiform() * 30)
    gen study_exit = study_entry + 365 + floor(runiform() * 180)
    gen rx_start = .
    replace rx_start = study_entry + floor(runiform() * 200) if runiform() < 0.4
    format %td study_entry study_exit rx_start

    tvtrial, id(id) entry(study_entry) exit(study_exit) treatstart(rx_start)
    confirm variable trial_trial
    confirm variable trial_arm
}

if _rc == 0 {
    display as result "  PASS"
    local ++total_pass
}
else {
    display as error "  FAIL (error `=_rc')"
    local ++total_fail
    local failed_tests "`failed_tests' tvtrial-1"
}

display as text "Example 3.2: Clone-censor-weight approach"
local ++total_tests

capture {
    clear
    set seed 12345
    set obs 500
    gen id = _n
    gen study_entry = mdy(1, 1, 2020) + floor(runiform() * 30)
    gen study_exit = study_entry + 365 + floor(runiform() * 180)
    gen rx_start = .
    replace rx_start = study_entry + floor(runiform() * 200) if runiform() < 0.4
    format %td study_entry study_exit rx_start

    tvtrial, id(id) entry(study_entry) exit(study_exit) treatstart(rx_start) ///
        clone graceperiod(30)
    confirm variable trial_censored
}

if _rc == 0 {
    display as result "  PASS"
    local ++total_pass
}
else {
    display as error "  FAIL (error `=_rc')"
    local ++total_fail
    local failed_tests "`failed_tests' tvtrial-2"
}

* =============================================================================
* TEST 4: tvdml Help Examples
* =============================================================================

display _n "{hline 78}"
display "{bf:TEST 4: tvdml.sthlp Examples}"
display "{hline 78}" _n

display as text "Example 4.1: Basic DML estimation"
local ++total_tests

capture {
    clear
    set seed 11111
    set obs 500
    gen x1 = rnormal()
    gen x2 = rnormal()
    gen x3 = rnormal()
    gen treatment = runiform() < invlogit(0.3*x1 + 0.2*x2)
    gen outcome = 10 + 2*treatment + 0.5*x1 + rnormal(0, 2)

    tvdml outcome treatment, covariates(x1 x2 x3) crossfit(3) seed(12345)
    assert e(psi) != .
}

if _rc == 0 {
    display as result "  PASS"
    local ++total_pass
}
else {
    display as error "  FAIL (error `=_rc')"
    local ++total_fail
    local failed_tests "`failed_tests' tvdml-1"
}

* =============================================================================
* TEST 5: tvsensitivity Help Examples
* =============================================================================

display _n "{hline 78}"
display "{bf:TEST 5: tvsensitivity.sthlp Examples}"
display "{hline 78}" _n

display as text "Example 5.1: E-value calculation"
local ++total_tests

capture {
    tvsensitivity, rr(2.0)
    assert r(evalue) > 1
}

if _rc == 0 {
    display as result "  PASS"
    local ++total_pass
}
else {
    display as error "  FAIL (error `=_rc')"
    local ++total_fail
    local failed_tests "`failed_tests' tvsensitivity-1"
}

display as text "Example 5.2: E-value with bias method"
local ++total_tests

capture {
    tvsensitivity, rr(1.8) method(bias)
    assert r(rr) == 1.8
}

if _rc == 0 {
    display as result "  PASS"
    local ++total_pass
}
else {
    display as error "  FAIL (error `=_rc')"
    local ++total_fail
    local failed_tests "`failed_tests' tvsensitivity-2"
}

* =============================================================================
* TEST 6: tvtable Help Examples
* =============================================================================

display _n "{hline 78}"
display "{bf:TEST 6: tvtable.sthlp Examples}"
display "{hline 78}" _n

display as text "Example 6.1: Basic exposure table"
local ++total_tests

capture {
    clear
    set obs 500
    gen tv_exposure = floor(runiform() * 3)
    gen fu_time = 100 + runiform() * 200
    gen _event = runiform() < 0.2

    tvtable, exposure(tv_exposure)
    assert r(n_levels) == 3
}

if _rc == 0 {
    display as result "  PASS"
    local ++total_pass
}
else {
    display as error "  FAIL (error `=_rc')"
    local ++total_fail
    local failed_tests "`failed_tests' tvtable-1"
}

* =============================================================================
* TEST 7: tvreport Help Examples
* =============================================================================

display _n "{hline 78}"
display "{bf:TEST 7: tvreport.sthlp Examples}"
display "{hline 78}" _n

display as text "Example 7.1: Basic report generation"
local ++total_tests

capture {
    clear
    set obs 200
    gen id = _n
    gen start = mdy(1, 1, 2020)
    gen stop = start + 100 + floor(runiform() * 200)
    format %td start stop
    gen tv_exposure = floor(runiform() * 3)
    gen _event = runiform() < 0.2

    tvreport, id(id) start(start) stop(stop) exposure(tv_exposure) event(_event)
    assert r(n_obs) == 200
}

if _rc == 0 {
    display as result "  PASS"
    local ++total_pass
}
else {
    display as error "  FAIL (error `=_rc')"
    local ++total_fail
    local failed_tests "`failed_tests' tvreport-1"
}

* =============================================================================
* TEST 8: tvpipeline Help Examples
* =============================================================================

display _n "{hline 78}"
display "{bf:TEST 8: tvpipeline.sthlp Examples}"
display "{hline 78}" _n

display as text "Example 8.1: Basic pipeline workflow"
local ++total_tests

capture {
    * Create cohort
    clear
    set seed 12345
    set obs 100
    gen id = _n
    gen study_entry = mdy(1, 1, 2020) + floor(runiform() * 30)
    gen study_exit = study_entry + 365 + floor(runiform() * 180)
    format %td study_entry study_exit
    gen age = 40 + floor(runiform() * 40)
    gen sex = runiform() > 0.5

    tempfile cohort
    save `cohort', replace

    * Create exposure
    clear
    set obs 150
    gen id = ceil(_n / 1.5)
    replace id = min(id, 100)
    gen rx_start = mdy(1, 1, 2020) + floor(runiform() * 200)
    gen rx_stop = rx_start + 30 + floor(runiform() * 90)
    format %td rx_start rx_stop
    gen drug = 1 + floor(runiform() * 2)

    tempfile exposure
    save `exposure', replace

    use `cohort', clear
    tvpipeline using `exposure', id(id) start(rx_start) stop(rx_stop) ///
        exposure(drug) entry(study_entry) exit(study_exit)

    confirm variable start
    confirm variable stop
    confirm variable tv_exposure
}

if _rc == 0 {
    display as result "  PASS"
    local ++total_pass
}
else {
    display as error "  FAIL (error `=_rc')"
    local ++total_fail
    local failed_tests "`failed_tests' tvpipeline-1"
}

* =============================================================================
* FINAL SUMMARY
* =============================================================================

display _n "{hline 78}"
display "{bf:HELP FILE VALIDATION SUMMARY}"
display "{hline 78}"
display "Total examples tested:  " as result `total_tests'
display "Examples passed:        " as result `total_pass'
if `total_fail' > 0 {
    display "Examples failed:        " as error `total_fail'
    display as error _n "FAILED EXAMPLES:`failed_tests'"
}
else {
    display "Examples failed:        " as text `total_fail'
}
display "{hline 78}"

local pass_rate = 100 * `total_pass' / `total_tests'
display _n "Pass rate: " as result %5.1f `pass_rate' "%"

if `total_fail' == 0 {
    display _n as result "{bf:ALL HELP FILE EXAMPLES WORK CORRECTLY!}"
    display as result "Documentation matches implementation."
}
else {
    display _n as error "{bf:SOME EXAMPLES FAILED - UPDATE HELP FILES}"
}

display _n "{hline 78}"
display "Completed: `c(current_date)' `c(current_time)'"
display "{hline 78}"
