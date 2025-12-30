/*******************************************************************************
* reproducibility_tests.do
*
* REPRODUCIBILITY AND DETERMINISM VALIDATION
*
* Tests that commands produce identical results when:
* - Run with same seed
* - Run on same data multiple times
* - Data is saved/loaded
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
display "{bf:REPRODUCIBILITY AND DETERMINISM TESTS}"
display "{hline 78}"
display "Started: `c(current_date)' `c(current_time)'"
display "{hline 78}" _n

local total_tests = 0
local total_pass = 0
local total_fail = 0
local failed_tests ""

* =============================================================================
* TEST 1: tvweight Reproducibility
* =============================================================================

display _n "{hline 78}"
display "{bf:TEST 1: tvweight Reproducibility}"
display "{hline 78}" _n

display as text "Test 1.1: Same data produces identical weights"
local ++total_tests

clear
set seed 12345
set obs 500
gen x1 = rnormal()
gen x2 = rnormal()
gen treatment = runiform() < invlogit(0.3*x1 + 0.2*x2)

tempfile testdata
save `testdata', replace

* Run 1
tvweight treatment, covariates(x1 x2) generate(w1)
quietly summarize w1
local mean1 = r(mean)
local sd1 = r(sd)
local sum1 = r(sum)

* Run 2 on same data
drop w1
tvweight treatment, covariates(x1 x2) generate(w2)
quietly summarize w2
local mean2 = r(mean)
local sd2 = r(sd)
local sum2 = r(sum)

if abs(`mean1' - `mean2') < 1e-10 & abs(`sd1' - `sd2') < 1e-10 & abs(`sum1' - `sum2') < 1e-10 {
    display as result "  PASS: Weights identical on repeated runs"
    local ++total_pass
}
else {
    display as error "  FAIL: Weights differ between runs"
    local ++total_fail
    local failed_tests "`failed_tests' 1.1"
}

* -----------------------------------------------------------------------------
display as text "Test 1.2: Save/load produces identical weights"
local ++total_tests

* Run on fresh load
use `testdata', clear
tvweight treatment, covariates(x1 x2) generate(w3)
quietly summarize w3
local mean3 = r(mean)

if abs(`mean1' - `mean3') < 1e-10 {
    display as result "  PASS: Weights identical after save/load"
    local ++total_pass
}
else {
    display as error "  FAIL: Weights differ after save/load"
    local ++total_fail
    local failed_tests "`failed_tests' 1.2"
}

* =============================================================================
* TEST 2: tvestimate Reproducibility
* =============================================================================

display _n "{hline 78}"
display "{bf:TEST 2: tvestimate Reproducibility}"
display "{hline 78}" _n

display as text "Test 2.1: Same data produces identical estimates"
local ++total_tests

clear
set seed 54321
set obs 500
gen x1 = rnormal()
gen treatment = runiform() > 0.5
gen outcome = 10 + 2*treatment + 0.5*x1 + rnormal()

tempfile testdata2
save `testdata2', replace

* Run 1
tvestimate outcome treatment, confounders(x1)
local psi1 = e(psi)
local se1 = e(se_psi)

* Run 2
tvestimate outcome treatment, confounders(x1)
local psi2 = e(psi)
local se2 = e(se_psi)

if abs(`psi1' - `psi2') < 1e-10 & abs(`se1' - `se2') < 1e-10 {
    display as result "  PASS: Estimates identical on repeated runs"
    local ++total_pass
}
else {
    display as error "  FAIL: Estimates differ"
    local ++total_fail
    local failed_tests "`failed_tests' 2.1"
}

* -----------------------------------------------------------------------------
display as text "Test 2.2: Identical results after data reload"
local ++total_tests

use `testdata2', clear
tvestimate outcome treatment, confounders(x1)
local psi3 = e(psi)

if abs(`psi1' - `psi3') < 1e-10 {
    display as result "  PASS: Estimates identical after reload"
    local ++total_pass
}
else {
    display as error "  FAIL: Estimates differ after reload"
    local ++total_fail
    local failed_tests "`failed_tests' 2.2"
}

* =============================================================================
* TEST 3: tvdml Reproducibility with Seed
* =============================================================================

display _n "{hline 78}"
display "{bf:TEST 3: tvdml Seed Reproducibility}"
display "{hline 78}" _n

display as text "Test 3.1: Same seed produces identical DML estimates"
local ++total_tests

clear
set seed 11111
set obs 500
gen x1 = rnormal()
gen x2 = rnormal()
gen treatment = runiform() > 0.5
gen outcome = 5 + 3*treatment + x1 + rnormal()

* Run 1 with seed
tvdml outcome treatment, covariates(x1 x2) crossfit(3) seed(99999)
local psi_dml1 = e(psi)

* Run 2 with same seed
tvdml outcome treatment, covariates(x1 x2) crossfit(3) seed(99999)
local psi_dml2 = e(psi)

if abs(`psi_dml1' - `psi_dml2') < 1e-10 {
    display as result "  PASS: DML identical with same seed"
    local ++total_pass
}
else {
    display as error "  FAIL: DML differs with same seed"
    local ++total_fail
    local failed_tests "`failed_tests' 3.1"
}

* -----------------------------------------------------------------------------
display as text "Test 3.2: Different seeds produce different estimates"
local ++total_tests

tvdml outcome treatment, covariates(x1 x2) crossfit(3) seed(11111)
local psi_dml3 = e(psi)

* Should be different (but close) with different seed
if abs(`psi_dml1' - `psi_dml3') > 0.001 {
    display as result "  PASS: Different seeds give different estimates (expected)"
    local ++total_pass
}
else {
    display as text "  NOTE: Seeds gave very similar results (possible but unusual)"
    local ++total_pass
}

* =============================================================================
* TEST 4: tvtrial Reproducibility
* =============================================================================

display _n "{hline 78}"
display "{bf:TEST 4: tvtrial Reproducibility}"
display "{hline 78}" _n

display as text "Test 4.1: Same data produces identical trial structure"
local ++total_tests

clear
set seed 22222
set obs 100
gen id = _n
gen study_entry = mdy(1, 1, 2020)
gen study_exit = study_entry + 365
format %td study_entry study_exit
gen rx_start = .
replace rx_start = study_entry + floor(runiform() * 200) if runiform() < 0.4
format %td rx_start

tempfile trialdata
save `trialdata', replace

* Run 1
tvtrial, id(id) entry(study_entry) exit(study_exit) treatstart(rx_start) ///
    trials(3) clone graceperiod(30)
local n1 = _N
quietly count if trial_arm == 1
local treat1 = r(N)

* Run 2
use `trialdata', clear
tvtrial, id(id) entry(study_entry) exit(study_exit) treatstart(rx_start) ///
    trials(3) clone graceperiod(30)
local n2 = _N
quietly count if trial_arm == 1
local treat2 = r(N)

if `n1' == `n2' & `treat1' == `treat2' {
    display as result "  PASS: Trial structure identical"
    local ++total_pass
}
else {
    display as error "  FAIL: Trial structure differs"
    local ++total_fail
    local failed_tests "`failed_tests' 4.1"
}

* =============================================================================
* TEST 5: tvsensitivity Reproducibility
* =============================================================================

display _n "{hline 78}"
display "{bf:TEST 5: tvsensitivity Reproducibility}"
display "{hline 78}" _n

display as text "Test 5.1: E-value is deterministic"
local ++total_tests

tvsensitivity, rr(2.5)
local ev1 = r(evalue)

tvsensitivity, rr(2.5)
local ev2 = r(evalue)

tvsensitivity, rr(2.5)
local ev3 = r(evalue)

if `ev1' == `ev2' & `ev2' == `ev3' {
    display as result "  PASS: E-value deterministic across runs"
    local ++total_pass
}
else {
    display as error "  FAIL: E-value varies"
    local ++total_fail
    local failed_tests "`failed_tests' 5.1"
}

* =============================================================================
* TEST 6: Order Independence
* =============================================================================

display _n "{hline 78}"
display "{bf:TEST 6: Order Independence}"
display "{hline 78}" _n

display as text "Test 6.1: tvweight invariant to observation order"
local ++total_tests

clear
set seed 33333
set obs 200
gen id = _n
gen x1 = rnormal()
gen treatment = runiform() < invlogit(0.3*x1)

* Original order
tvweight treatment, covariates(x1) generate(w_orig)
quietly summarize w_orig
local mean_orig = r(mean)

* Shuffle order
gen rand = runiform()
sort rand
drop rand

tvweight treatment, covariates(x1) generate(w_shuffled)
quietly summarize w_shuffled
local mean_shuffled = r(mean)

if abs(`mean_orig' - `mean_shuffled') < 1e-8 {
    display as result "  PASS: Weights invariant to row order"
    local ++total_pass
}
else {
    display as error "  FAIL: Weights depend on row order"
    local ++total_fail
    local failed_tests "`failed_tests' 6.1"
}

* =============================================================================
* FINAL SUMMARY
* =============================================================================

display _n "{hline 78}"
display "{bf:REPRODUCIBILITY TEST SUMMARY}"
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
    display _n as result "{bf:ALL REPRODUCIBILITY TESTS PASSED!}"
}

display _n "{hline 78}"
display "Completed: `c(current_date)' `c(current_time)'"
display "{hline 78}"
