/*******************************************************************************
* boundary_tests.do
*
* BOUNDARY CONDITION AND MINIMUM SAMPLE SIZE TESTS
*
* Tests commands at their operational limits:
* - Minimum sample sizes
* - Extreme covariate values
* - Boundary dates
* - Numerical precision limits
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
display "{bf:BOUNDARY CONDITION TESTS}"
display "{hline 78}"
display "Started: `c(current_date)' `c(current_time)'"
display "{hline 78}" _n

local total_tests = 0
local total_pass = 0
local total_fail = 0
local failed_tests ""

* =============================================================================
* TEST 1: Minimum Sample Sizes
* =============================================================================

display _n "{hline 78}"
display "{bf:TEST 1: Minimum Sample Size Discovery}"
display "{hline 78}" _n

* Test 1.1: tvweight minimum N
display as text "Test 1.1: tvweight minimum sample size"
local ++total_tests

local min_n_weight = 0
foreach n in 10 20 30 50 {
    quietly {
        clear
        set seed `n'
        set obs `n'
        gen x1 = rnormal()
        gen treatment = _n <= `n'/2

        capture tvweight treatment, covariates(x1) generate(w)
        if _rc == 0 {
            local min_n_weight = `n'
            continue, break
        }
    }
}

if `min_n_weight' > 0 {
    display as result "  PASS: tvweight works with N = `min_n_weight'"
    local ++total_pass
}
else {
    display as error "  FAIL: tvweight requires > 50 observations"
    local ++total_fail
    local failed_tests "`failed_tests' 1.1"
}

* Test 1.2: tvestimate minimum N
display as text "Test 1.2: tvestimate minimum sample size"
local ++total_tests

local min_n_est = 0
foreach n in 20 30 50 100 {
    quietly {
        clear
        set seed `n'
        set obs `n'
        gen x1 = rnormal()
        gen treatment = _n <= `n'/2
        gen outcome = 10 + 2*treatment + x1 + rnormal()

        capture tvestimate outcome treatment, confounders(x1)
        if _rc == 0 {
            local min_n_est = `n'
            continue, break
        }
    }
}

if `min_n_est' > 0 {
    display as result "  PASS: tvestimate works with N = `min_n_est'"
    local ++total_pass
}
else {
    display as error "  FAIL: tvestimate requires > 100 observations"
    local ++total_fail
    local failed_tests "`failed_tests' 1.2"
}

* Test 1.3: tvtrial minimum N
display as text "Test 1.3: tvtrial minimum sample size"
local ++total_tests

local min_n_trial = 0
foreach n in 10 20 30 50 {
    quietly {
        clear
        set seed `n'
        set obs `n'
        gen id = _n
        gen study_entry = mdy(1, 1, 2020)
        gen study_exit = study_entry + 365
        format %td study_entry study_exit
        gen rx_start = cond(_n <= `n'/3, study_entry + 30, .)
        format %td rx_start

        capture tvtrial, id(id) entry(study_entry) exit(study_exit) ///
            treatstart(rx_start) trials(1)
        if _rc == 0 {
            local min_n_trial = `n'
            continue, break
        }
    }
}

if `min_n_trial' > 0 {
    display as result "  PASS: tvtrial works with N = `min_n_trial'"
    local ++total_pass
}
else {
    display as error "  FAIL: tvtrial requires > 50 observations"
    local ++total_fail
    local failed_tests "`failed_tests' 1.3"
}

* =============================================================================
* TEST 2: Extreme Covariate Values
* =============================================================================

display _n "{hline 78}"
display "{bf:TEST 2: Extreme Covariate Values}"
display "{hline 78}" _n

display as text "Test 2.1: tvweight with large covariate values"
local ++total_tests

clear
set seed 22222
set obs 500

* Very large covariate values
gen x1 = rnormal() * 1000
gen x2 = rnormal() * 1000
gen treatment = runiform() < invlogit((x1 + x2)/10000)

capture tvweight treatment, covariates(x1 x2) generate(w_large)
if _rc == 0 {
    quietly summarize w_large
    if r(min) > 0 & r(max) < . {
        display as result "  PASS: Handles large covariate values"
        local ++total_pass
    }
    else {
        display as error "  FAIL: Invalid weights with large covariates"
        local ++total_fail
        local failed_tests "`failed_tests' 2.1"
    }
}
else {
    display as error "  FAIL: Error with large covariates"
    local ++total_fail
    local failed_tests "`failed_tests' 2.1"
}

* Test 2.2: Very small covariate values
display as text "Test 2.2: tvweight with small covariate values"
local ++total_tests

clear
set seed 33333
set obs 500

gen x1 = rnormal() * 0.001
gen x2 = rnormal() * 0.001
gen treatment = runiform() > 0.5

capture tvweight treatment, covariates(x1 x2) generate(w_small)
if _rc == 0 {
    display as result "  PASS: Handles small covariate values"
    local ++total_pass
}
else {
    display as error "  FAIL: Error with small covariates"
    local ++total_fail
    local failed_tests "`failed_tests' 2.2"
}

* Test 2.3: Mixed scale covariates
display as text "Test 2.3: tvweight with mixed scale covariates"
local ++total_tests

clear
set seed 44444
set obs 500

gen x1 = rnormal() * 1000000   // Very large
gen x2 = rnormal() * 0.000001  // Very small
gen x3 = rnormal()             // Normal scale
gen treatment = runiform() > 0.5

capture tvweight treatment, covariates(x1 x2 x3) generate(w_mixed)
if _rc == 0 {
    display as result "  PASS: Handles mixed scale covariates"
    local ++total_pass
}
else {
    display as error "  FAIL: Error with mixed scale covariates"
    local ++total_fail
    local failed_tests "`failed_tests' 2.3"
}

* =============================================================================
* TEST 3: Date Boundary Conditions
* =============================================================================

display _n "{hline 78}"
display "{bf:TEST 3: Date Boundary Conditions}"
display "{hline 78}" _n

display as text "Test 3.1: Leap year dates"
local ++total_tests

clear
set obs 100
gen id = _n
gen study_entry = mdy(2, 28, 2020)  // Leap year
gen study_exit = mdy(3, 1, 2020)    // Day after leap day
format %td study_entry study_exit
gen rx_start = cond(_n <= 30, mdy(2, 29, 2020), .)  // Leap day
format %td rx_start

capture tvtrial, id(id) entry(study_entry) exit(study_exit) ///
    treatstart(rx_start) trials(1)

if _rc == 0 {
    display as result "  PASS: Handles leap year dates"
    local ++total_pass
}
else {
    display as error "  FAIL: Error with leap year dates"
    local ++total_fail
    local failed_tests "`failed_tests' 3.1"
}

display as text "Test 3.2: Year boundary dates"
local ++total_tests

clear
set obs 100
gen id = _n
gen study_entry = mdy(12, 31, 2019)
gen study_exit = mdy(1, 2, 2020)
format %td study_entry study_exit
gen rx_start = cond(_n <= 30, mdy(1, 1, 2020), .)
format %td rx_start

capture tvtrial, id(id) entry(study_entry) exit(study_exit) ///
    treatstart(rx_start) trials(1)

if _rc == 0 {
    display as result "  PASS: Handles year boundary dates"
    local ++total_pass
}
else {
    display as error "  FAIL: Error with year boundary dates"
    local ++total_fail
    local failed_tests "`failed_tests' 3.2"
}

display as text "Test 3.3: Same day entry and exit"
local ++total_tests

clear
set obs 50
gen id = _n
gen study_entry = mdy(1, 1, 2020)
gen study_exit = mdy(1, 1, 2020)  // Same day!
format %td study_entry study_exit
gen rx_start = .

capture tvtrial, id(id) entry(study_entry) exit(study_exit) ///
    treatstart(rx_start) trials(1)

* This might fail or give 0 follow-up - both are acceptable
if _rc == 0 | _rc == 2000 {
    display as result "  PASS: Handles same-day entry/exit gracefully"
    local ++total_pass
}
else {
    display as error "  FAIL: Unexpected error with same-day dates"
    local ++total_fail
    local failed_tests "`failed_tests' 3.3"
}

* =============================================================================
* TEST 4: Numerical Precision
* =============================================================================

display _n "{hline 78}"
display "{bf:TEST 4: Numerical Precision}"
display "{hline 78}" _n

display as text "Test 4.1: E-value near boundary (RR ≈ 1)"
local ++total_tests

* RR very close to 1 should give E-value very close to 1
tvsensitivity, rr(1.0001)
local ev_near1 = r(evalue)

if `ev_near1' >= 1 & `ev_near1' < 1.1 {
    display as result "  PASS: E-value near 1 for RR ≈ 1 (E = " %6.4f `ev_near1' ")"
    local ++total_pass
}
else {
    display as error "  FAIL: E-value wrong near boundary"
    local ++total_fail
    local failed_tests "`failed_tests' 4.1"
}

display as text "Test 4.2: E-value with very large RR"
local ++total_tests

tvsensitivity, rr(1000)
local ev_large = r(evalue)

if `ev_large' > 1000 & `ev_large' < . {
    display as result "  PASS: E-value computed for large RR (E = " %8.1f `ev_large' ")"
    local ++total_pass
}
else {
    display as error "  FAIL: E-value overflow with large RR"
    local ++total_fail
    local failed_tests "`failed_tests' 4.2"
}

display as text "Test 4.3: tvestimate with outcome near zero"
local ++total_tests

clear
set seed 55555
set obs 500

gen x1 = rnormal()
gen treatment = runiform() > 0.5
gen outcome = 0.0001 + 0.00001*treatment + 0.000001*x1 + rnormal(0, 0.00001)

capture tvestimate outcome treatment, confounders(x1)
if _rc == 0 {
    display as result "  PASS: Handles very small outcome values"
    local ++total_pass
}
else {
    display as error "  FAIL: Error with small outcomes"
    local ++total_fail
    local failed_tests "`failed_tests' 4.3"
}

* =============================================================================
* TEST 5: Empty/Degenerate Cases
* =============================================================================

display _n "{hline 78}"
display "{bf:TEST 5: Empty/Degenerate Cases}"
display "{hline 78}" _n

display as text "Test 5.1: All treated (no controls)"
local ++total_tests

clear
set obs 100
gen x1 = rnormal()
gen treatment = 1  // All treated

capture tvweight treatment, covariates(x1) generate(w_all1)

* Should fail gracefully
if _rc != 0 {
    display as result "  PASS: Correctly rejects all-treated case"
    local ++total_pass
}
else {
    display as error "  FAIL: Should reject all-treated case"
    local ++total_fail
    local failed_tests "`failed_tests' 5.1"
}

display as text "Test 5.2: No events in tvtable"
local ++total_tests

clear
set obs 100
gen tv_exposure = floor(runiform() * 3)
gen fu_time = 100
gen _event = 0  // No events

capture tvtable, exposure(tv_exposure)
if _rc == 0 {
    display as result "  PASS: Handles zero events"
    local ++total_pass
}
else {
    display as error "  FAIL: Error with zero events"
    local ++total_fail
    local failed_tests "`failed_tests' 5.2"
}

display as text "Test 5.3: Single observation per exposure level"
local ++total_tests

clear
set obs 3
gen tv_exposure = _n - 1  // 0, 1, 2
gen fu_time = 100
gen _event = 0

capture tvtable, exposure(tv_exposure)
if _rc == 0 {
    display as result "  PASS: Handles single obs per level"
    local ++total_pass
}
else {
    display as error "  FAIL: Error with single obs per level"
    local ++total_fail
    local failed_tests "`failed_tests' 5.3"
}

* =============================================================================
* TEST 6: Binary Covariate Edge Cases
* =============================================================================

display _n "{hline 78}"
display "{bf:TEST 6: Binary Covariate Edge Cases}"
display "{hline 78}" _n

display as text "Test 6.1: All-zero covariate"
local ++total_tests

clear
set seed 66666
set obs 200

gen x1 = 0  // Constant zero
gen x2 = rnormal()
gen treatment = runiform() > 0.5

capture tvweight treatment, covariates(x1 x2) generate(w_zero)

* Might fail or succeed with warning - either is acceptable
if _rc == 0 {
    display as result "  PASS: Handles constant covariate (or drops it)"
    local ++total_pass
}
else if _rc == 2000 | _rc == 111 {
    display as result "  PASS: Correctly identifies constant covariate issue"
    local ++total_pass
}
else {
    display as error "  FAIL: Unexpected error with constant covariate"
    local ++total_fail
    local failed_tests "`failed_tests' 6.1"
}

display as text "Test 6.2: Perfectly correlated covariates"
local ++total_tests

clear
set seed 77777
set obs 200

gen x1 = rnormal()
gen x2 = x1  // Perfect correlation
gen treatment = runiform() > 0.5

capture tvweight treatment, covariates(x1 x2) generate(w_corr)

* Should fail or handle gracefully
if _rc == 0 | _rc == 2000 {
    display as result "  PASS: Handles perfect correlation"
    local ++total_pass
}
else {
    display as error "  FAIL: Unexpected error with perfect correlation"
    local ++total_fail
    local failed_tests "`failed_tests' 6.2"
}

* =============================================================================
* FINAL SUMMARY
* =============================================================================

display _n "{hline 78}"
display "{bf:BOUNDARY TEST SUMMARY}"
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
    display _n as result "{bf:ALL BOUNDARY TESTS PASSED!}"
    display as result "Commands handle edge cases correctly."
}

display _n "{hline 78}"
display "Completed: `c(current_date)' `c(current_time)'"
display "{hline 78}"
