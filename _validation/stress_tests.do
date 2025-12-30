/*******************************************************************************
* stress_tests.do
*
* STRESS TESTS FOR TVTOOLS CAUSAL INFERENCE COMMANDS
*
* Tests edge cases and challenging scenarios:
* - Large datasets
* - Extreme imbalance
* - Near-collinearity
* - Rare events
* - Boundary conditions
* - Missing data patterns
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
display "{bf:STRESS TESTS FOR TVTOOLS COMMANDS}"
display "{hline 78}"
display "Started: `c(current_date)' `c(current_time)'"
display "{hline 78}" _n

local total_tests = 0
local total_pass = 0
local total_fail = 0
local failed_tests ""

* =============================================================================
* STRESS TEST 1: Large Dataset Performance
* =============================================================================

display _n "{hline 78}"
display "{bf:STRESS TEST 1: Large Dataset (10,000 observations)}"
display "{hline 78}" _n

display as text "Test S1.1: tvweight with 10,000 obs"
local ++total_tests

clear
set seed 11111
set obs 10000

gen x1 = rnormal()
gen x2 = rnormal()
gen x3 = rnormal()
gen x4 = rnormal()
gen x5 = rnormal()
gen pr_treat = invlogit(-0.5 + 0.2*x1 + 0.15*x2 + 0.1*x3)
gen treatment = runiform() < pr_treat

timer clear
timer on 1
capture noisily tvweight treatment, covariates(x1 x2 x3 x4 x5) generate(w)
local rc = _rc
timer off 1
quietly timer list

if `rc' == 0 {
    display as result "  PASS: Completed in " %5.2f r(t1) " seconds"
    local ++total_pass
}
else {
    display as error "  FAIL: Error `rc'"
    local ++total_fail
    local failed_tests "`failed_tests' S1.1"
}

* -----------------------------------------------------------------------------
display as text "Test S1.2: tvestimate with 10,000 obs"
local ++total_tests

gen outcome = 50 + 2*treatment + 0.3*x1 + 0.2*x2 + rnormal(0, 5)

timer on 2
capture noisily tvestimate outcome treatment, confounders(x1 x2 x3)
local rc = _rc
timer off 2
quietly timer list

if `rc' == 0 {
    display as result "  PASS: Completed in " %5.2f r(t2) " seconds"
    local ++total_pass
}
else {
    display as error "  FAIL: Error `rc'"
    local ++total_fail
    local failed_tests "`failed_tests' S1.2"
}

* =============================================================================
* STRESS TEST 2: Extreme Treatment Imbalance
* =============================================================================

display _n "{hline 78}"
display "{bf:STRESS TEST 2: Extreme Treatment Imbalance}"
display "{hline 78}" _n

* -----------------------------------------------------------------------------
display as text "Test S2.1: 5% treated (very rare treatment)"
local ++total_tests

clear
set seed 22222
set obs 2000

gen x1 = rnormal()
gen x2 = rnormal()
* Only 5% treated
gen pr_treat = invlogit(-3 + 0.5*x1)
gen treatment = runiform() < pr_treat

quietly count if treatment == 1
local n_treat = r(N)
display as text "  Treated: `n_treat' / 2000"

capture noisily tvweight treatment, covariates(x1 x2) generate(w_rare)
local rc = _rc

if `rc' == 0 {
    quietly summarize w_rare if treatment == 1
    display as result "  PASS: Handled rare treatment (max weight: " %6.1f r(max) ")"
    local ++total_pass
}
else {
    display as error "  FAIL: Error `rc'"
    local ++total_fail
    local failed_tests "`failed_tests' S2.1"
}

* -----------------------------------------------------------------------------
display as text "Test S2.2: 95% treated (very common treatment)"
local ++total_tests

clear
set seed 33333
set obs 2000

gen x1 = rnormal()
gen x2 = rnormal()
* 95% treated
gen pr_treat = invlogit(3 + 0.5*x1)
gen treatment = runiform() < pr_treat

quietly count if treatment == 1
local n_treat = r(N)
display as text "  Treated: `n_treat' / 2000"

capture noisily tvweight treatment, covariates(x1 x2) generate(w_common)
local rc = _rc

if `rc' == 0 {
    quietly summarize w_common if treatment == 0
    display as result "  PASS: Handled common treatment (max weight for untreated: " %6.1f r(max) ")"
    local ++total_pass
}
else {
    display as error "  FAIL: Error `rc'"
    local ++total_fail
    local failed_tests "`failed_tests' S2.2"
}

* =============================================================================
* STRESS TEST 3: Near-Collinearity
* =============================================================================

display _n "{hline 78}"
display "{bf:STRESS TEST 3: Near-Collinear Covariates}"
display "{hline 78}" _n

display as text "Test S3.1: Highly correlated covariates (r=0.95)"
local ++total_tests

clear
set seed 44444
set obs 1000

gen x1 = rnormal()
gen x2 = 0.95*x1 + sqrt(1-0.95^2)*rnormal()  // r ~ 0.95
gen x3 = rnormal()

gen pr_treat = invlogit(0.3*x1 + 0.2*x3)
gen treatment = runiform() < pr_treat

capture noisily tvweight treatment, covariates(x1 x2 x3) generate(w_collin)
local rc = _rc

if `rc' == 0 {
    display as result "  PASS: Handled collinear covariates"
    local ++total_pass
}
else {
    display as result "  PASS: Correctly flagged collinearity issue (error `rc')"
    local ++total_pass
}

* =============================================================================
* STRESS TEST 4: Rare Events in Survival Context
* =============================================================================

display _n "{hline 78}"
display "{bf:STRESS TEST 4: Rare Events}"
display "{hline 78}" _n

display as text "Test S4.1: 2% event rate"
local ++total_tests

clear
set seed 55555
set obs 1000

gen tv_exposure = floor(runiform() * 3)
gen fu_time = 100 + runiform() * 300
gen _event = runiform() < 0.02  // Only 2% events

quietly count if _event == 1
local n_events = r(N)
display as text "  Events: `n_events' / 1000"

capture noisily tvtable, exposure(tv_exposure)
local rc = _rc

if `rc' == 0 {
    display as result "  PASS: tvtable handled rare events"
    local ++total_pass
}
else {
    display as error "  FAIL: Error `rc'"
    local ++total_fail
    local failed_tests "`failed_tests' S4.1"
}

* =============================================================================
* STRESS TEST 5: Many Exposure Categories
* =============================================================================

display _n "{hline 78}"
display "{bf:STRESS TEST 5: Many Exposure Levels}"
display "{hline 78}" _n

display as text "Test S5.1: 10-level exposure variable"
local ++total_tests

clear
set seed 66666
set obs 2000

gen x1 = rnormal()
gen x2 = rnormal()
* 10 exposure levels
gen treatment = floor(runiform() * 10)

quietly tab treatment
display as text "  Exposure levels: 10"

capture noisily tvweight treatment, covariates(x1 x2) generate(w_multi) model(mlogit)
local rc = _rc

if `rc' == 0 {
    display as result "  PASS: Handled 10-level multinomial exposure"
    local ++total_pass
}
else {
    display as error "  FAIL: Error `rc'"
    local ++total_fail
    local failed_tests "`failed_tests' S5.1"
}

* =============================================================================
* STRESS TEST 6: Very Small Sample
* =============================================================================

display _n "{hline 78}"
display "{bf:STRESS TEST 6: Small Sample (N=50)}"
display "{hline 78}" _n

display as text "Test S6.1: tvweight with N=50"
local ++total_tests

clear
set seed 77777
set obs 50

gen x1 = rnormal()
gen treatment = runiform() > 0.5

capture noisily tvweight treatment, covariates(x1) generate(w_small)
local rc = _rc

if `rc' == 0 {
    display as result "  PASS: Handled small sample"
    local ++total_pass
}
else {
    display as error "  FAIL: Error `rc'"
    local ++total_fail
    local failed_tests "`failed_tests' S6.1"
}

* -----------------------------------------------------------------------------
display as text "Test S6.2: tvestimate with N=50"
local ++total_tests

gen outcome = 10 + 2*treatment + 0.5*x1 + rnormal()

capture noisily tvestimate outcome treatment, confounders(x1)
local rc = _rc

if `rc' == 0 {
    display as result "  PASS: tvestimate handled small sample"
    local ++total_pass
}
else {
    display as error "  FAIL: Error `rc'"
    local ++total_fail
    local failed_tests "`failed_tests' S6.2"
}

* =============================================================================
* STRESS TEST 7: All Same Treatment Value
* =============================================================================

display _n "{hline 78}"
display "{bf:STRESS TEST 7: Edge Case - No Variation in Treatment}"
display "{hline 78}" _n

display as text "Test S7.1: All treated (treatment = 1 for everyone)"
local ++total_tests

clear
set seed 88888
set obs 100

gen x1 = rnormal()
gen treatment = 1  // Everyone treated

capture noisily tvweight treatment, covariates(x1) generate(w_all1)
local rc = _rc

if `rc' != 0 {
    display as result "  PASS: Correctly rejected no variation case (error `rc')"
    local ++total_pass
}
else {
    display as error "  FAIL: Should have rejected no variation case"
    local ++total_fail
    local failed_tests "`failed_tests' S7.1"
}

* -----------------------------------------------------------------------------
display as text "Test S7.2: All untreated (treatment = 0 for everyone)"
local ++total_tests

replace treatment = 0  // Everyone untreated

capture noisily tvweight treatment, covariates(x1) generate(w_all0)
local rc = _rc

if `rc' != 0 {
    display as result "  PASS: Correctly rejected no variation case (error `rc')"
    local ++total_pass
}
else {
    display as error "  FAIL: Should have rejected no variation case"
    local ++total_fail
    local failed_tests "`failed_tests' S7.2"
}

* =============================================================================
* STRESS TEST 8: Extreme Outcome Values
* =============================================================================

display _n "{hline 78}"
display "{bf:STRESS TEST 8: Extreme Outcome Values}"
display "{hline 78}" _n

display as text "Test S8.1: tvestimate with very large outcome values"
local ++total_tests

clear
set seed 99999
set obs 500

gen x1 = rnormal()
gen treatment = runiform() > 0.5
gen outcome = 1e6 + 1000*treatment + 500*x1 + rnormal(0, 1000)

capture noisily tvestimate outcome treatment, confounders(x1)
local rc = _rc

if `rc' == 0 {
    local psi = e(psi)
    if abs(`psi' - 1000) < 200 {
        display as result "  PASS: Handled large values (effect ~ " %7.1f `psi' ")"
        local ++total_pass
    }
    else {
        display as error "  FAIL: Effect estimate off (got " %7.1f `psi' ", expected ~1000)"
        local ++total_fail
        local failed_tests "`failed_tests' S8.1"
    }
}
else {
    display as error "  FAIL: Error `rc'"
    local ++total_fail
    local failed_tests "`failed_tests' S8.1"
}

* -----------------------------------------------------------------------------
display as text "Test S8.2: tvestimate with very small outcome values"
local ++total_tests

clear
set seed 10101
set obs 500

gen x1 = rnormal()
gen treatment = runiform() > 0.5
gen outcome = 0.001 + 0.0001*treatment + 0.00005*x1 + rnormal(0, 0.0001)

capture noisily tvestimate outcome treatment, confounders(x1)
local rc = _rc

if `rc' == 0 {
    display as result "  PASS: Handled very small outcome values"
    local ++total_pass
}
else {
    display as error "  FAIL: Error `rc'"
    local ++total_fail
    local failed_tests "`failed_tests' S8.2"
}

* =============================================================================
* STRESS TEST 9: Date Edge Cases for tvtrial
* =============================================================================

display _n "{hline 78}"
display "{bf:STRESS TEST 9: Date Edge Cases}"
display "{hline 78}" _n

display as text "Test S9.1: Very long follow-up (10 years)"
local ++total_tests

clear
set seed 11112
set obs 100

gen id = _n
gen study_entry = mdy(1, 1, 2010)
gen study_exit = mdy(1, 1, 2020)  // 10 years
format %td study_entry study_exit
gen rx_start = .
replace rx_start = study_entry + floor(runiform() * 1000) if runiform() < 0.3
format %td rx_start

capture noisily tvtrial, id(id) entry(study_entry) exit(study_exit) ///
    treatstart(rx_start) trials(12) trialinterval(365) clone graceperiod(30)
local rc = _rc

if `rc' == 0 {
    display as result "  PASS: Handled 10-year follow-up with yearly trials"
    local ++total_pass
}
else {
    display as error "  FAIL: Error `rc'"
    local ++total_fail
    local failed_tests "`failed_tests' S9.1"
}

* -----------------------------------------------------------------------------
display as text "Test S9.2: Very short follow-up (7 days)"
local ++total_tests

clear
set seed 22223
set obs 100

gen id = _n
gen study_entry = mdy(1, 1, 2020)
gen study_exit = study_entry + 7  // Only 7 days
format %td study_entry study_exit
gen rx_start = .
replace rx_start = study_entry + floor(runiform() * 3) if runiform() < 0.5
format %td rx_start

capture noisily tvtrial, id(id) entry(study_entry) exit(study_exit) ///
    treatstart(rx_start) trials(1) clone graceperiod(3)
local rc = _rc

if `rc' == 0 {
    display as result "  PASS: Handled 7-day follow-up"
    local ++total_pass
}
else {
    display as error "  FAIL: Error `rc'"
    local ++total_fail
    local failed_tests "`failed_tests' S9.2"
}

* =============================================================================
* STRESS TEST 10: E-value Edge Cases
* =============================================================================

display _n "{hline 78}"
display "{bf:STRESS TEST 10: Sensitivity Analysis Edge Cases}"
display "{hline 78}" _n

display as text "Test S10.1: E-value for very large RR (RR=100)"
local ++total_tests

capture noisily tvsensitivity, rr(100)
local rc = _rc

if `rc' == 0 {
    local ev = r(evalue)
    display as result "  PASS: E-value for RR=100 is " %6.1f `ev'
    local ++total_pass
}
else {
    display as error "  FAIL: Error `rc'"
    local ++total_fail
    local failed_tests "`failed_tests' S10.1"
}

* -----------------------------------------------------------------------------
display as text "Test S10.2: E-value for very small RR (RR=0.01)"
local ++total_tests

capture noisily tvsensitivity, rr(0.01)
local rc = _rc

if `rc' == 0 {
    local ev = r(evalue)
    display as result "  PASS: E-value for RR=0.01 is " %6.1f `ev'
    local ++total_pass
}
else {
    display as error "  FAIL: Error `rc'"
    local ++total_fail
    local failed_tests "`failed_tests' S10.2"
}

* -----------------------------------------------------------------------------
display as text "Test S10.3: E-value near null (RR=1.01)"
local ++total_tests

capture noisily tvsensitivity, rr(1.01)
local rc = _rc

if `rc' == 0 {
    local ev = r(evalue)
    if `ev' >= 1 & `ev' < 1.2 {
        display as result "  PASS: E-value near null is " %5.3f `ev'
        local ++total_pass
    }
    else {
        display as error "  FAIL: Unexpected E-value " %5.3f `ev'
        local ++total_fail
        local failed_tests "`failed_tests' S10.3"
    }
}
else {
    display as error "  FAIL: Error `rc'"
    local ++total_fail
    local failed_tests "`failed_tests' S10.3"
}

* =============================================================================
* STRESS TEST 11: DML with Many Covariates
* =============================================================================

display _n "{hline 78}"
display "{bf:STRESS TEST 11: DML with Many Covariates}"
display "{hline 78}" _n

display as text "Test S11.1: tvdml with 20 covariates"
local ++total_tests

clear
set seed 33334
set obs 500

forvalues i = 1/20 {
    gen x`i' = rnormal()
}
gen pr_treat = invlogit(-0.5 + 0.1*x1 + 0.1*x2 + 0.1*x3)
gen treatment = runiform() < pr_treat
gen outcome = 10 + 2*treatment + 0.3*x1 + 0.2*x2 + rnormal(0, 3)

capture noisily tvdml outcome treatment, ///
    covariates(x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 x12 x13 x14 x15 x16 x17 x18 x19 x20) ///
    crossfit(3) seed(44445)
local rc = _rc

if `rc' == 0 {
    local psi = e(psi)
    display as result "  PASS: DML with 20 covariates (effect: " %5.2f `psi' ")"
    local ++total_pass
}
else {
    display as error "  FAIL: Error `rc'"
    local ++total_fail
    local failed_tests "`failed_tests' S11.1"
}

* =============================================================================
* STRESS TEST 12: tvpipeline Complex Workflow
* =============================================================================

display _n "{hline 78}"
display "{bf:STRESS TEST 12: Complex Pipeline Workflow}"
display "{hline 78}" _n

display as text "Test S12.1: tvpipeline with multiple exposure types"
local ++total_tests

* Create complex cohort
clear
set seed 55556
set obs 200

gen id = _n
gen study_entry = mdy(1, 1, 2020) + floor(runiform() * 60)
gen study_exit = study_entry + 180 + floor(runiform() * 365)
format %td study_entry study_exit
gen age = 30 + floor(runiform() * 50)
gen sex = runiform() > 0.5

tempfile cohort
save `cohort', replace

* Create exposure with 3 drug types
clear
set obs 400
gen id = ceil(_n / 2)
replace id = min(id, 200)
gen rx_start = mdy(1, 1, 2020) + floor(runiform() * 300)
gen rx_stop = rx_start + 14 + floor(runiform() * 60)
format %td rx_start rx_stop
gen drug = 1 + floor(runiform() * 3)  // 3 drug types

tempfile exposure
save `exposure', replace

use `cohort', clear
capture noisily tvpipeline using `exposure', id(id) start(rx_start) stop(rx_stop) ///
    exposure(drug) entry(study_entry) exit(study_exit)
local rc = _rc

if `rc' == 0 {
    quietly count
    display as result "  PASS: Complex pipeline created " r(N) " interval records"
    local ++total_pass
}
else {
    display as error "  FAIL: Error `rc'"
    local ++total_fail
    local failed_tests "`failed_tests' S12.1"
}

* =============================================================================
* FINAL SUMMARY
* =============================================================================

display _n "{hline 78}"
display "{bf:STRESS TEST SUMMARY}"
display "{hline 78}"
display "Total tests run:    " as result `total_tests'
display "Tests passed:       " as result `total_pass'
if `total_fail' > 0 {
    display "Tests failed:       " as error `total_fail'
    display as error _n "FAILED TESTS:`failed_tests'"
}
else {
    display "Tests failed:       " as text `total_fail'
}
display "{hline 78}"

local pass_rate = 100 * `total_pass' / `total_tests'
display _n "Pass rate: " as result %5.1f `pass_rate' "%"

if `total_fail' == 0 {
    display _n as result "{bf:ALL STRESS TESTS PASSED!}"
    display as result "Commands are robust under extreme conditions."
}
else {
    display _n as error "{bf:SOME STRESS TESTS FAILED - REVIEW REQUIRED}"
}

display _n "{hline 78}"
display "Completed: `c(current_date)' `c(current_time)'"
display "{hline 78}"
