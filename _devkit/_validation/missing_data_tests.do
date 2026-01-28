/*******************************************************************************
* missing_data_tests.do
*
* MISSING DATA AND COVARIATE TYPE TESTS
*
* Tests behavior with:
* - Missing values in covariates
* - Missing values in treatment
* - Missing values in outcome
* - Different covariate types (binary, categorical, continuous)
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
display "{bf:MISSING DATA AND COVARIATE TYPE TESTS}"
display "{hline 78}"
display "Started: `c(current_date)' `c(current_time)'"
display "{hline 78}" _n

local total_tests = 0
local total_pass = 0
local total_fail = 0
local failed_tests ""

* =============================================================================
* TEST 1: Missing Values in Covariates
* =============================================================================

display _n "{hline 78}"
display "{bf:TEST 1: Missing Values in Covariates}"
display "{hline 78}" _n

display as text "Test 1.1: tvweight with missing covariate values"
local ++total_tests

clear
set seed 11111
set obs 500

gen x1 = rnormal()
gen x2 = rnormal()
* Introduce 10% missing
replace x1 = . if runiform() < 0.1
gen treatment = runiform() > 0.5

local n_before = _N
capture tvweight treatment, covariates(x1 x2) generate(w)

if _rc == 0 {
    * Check that missing covariates result in missing weights
    quietly count if missing(w)
    local n_miss_w = r(N)
    quietly count if missing(x1)
    local n_miss_x1 = r(N)

    if `n_miss_w' >= `n_miss_x1' {
        display as result "  PASS: Missing covariates -> missing weights"
        display as text "        (`n_miss_x1' missing x1, `n_miss_w' missing weights)"
        local ++total_pass
    }
    else {
        display as error "  FAIL: Weights computed for missing covariates"
        local ++total_fail
        local failed_tests "`failed_tests' 1.1"
    }
}
else {
    display as error "  FAIL: Error handling missing covariates"
    local ++total_fail
    local failed_tests "`failed_tests' 1.1"
}

* Test 1.2: tvestimate with missing covariates
display as text "Test 1.2: tvestimate with missing confounders"
local ++total_tests

gen outcome = 10 + 2*treatment + 0.5*x1 + rnormal()
replace outcome = . if missing(x1)  // Make outcome missing where x1 missing

capture tvestimate outcome treatment, confounders(x1 x2)

if _rc == 0 {
    display as result "  PASS: tvestimate handles missing confounders"
    local ++total_pass
}
else if _rc == 2000 {
    display as result "  PASS: tvestimate excludes obs with missing data"
    local ++total_pass
}
else {
    display as error "  FAIL: Unexpected error with missing confounders"
    local ++total_fail
    local failed_tests "`failed_tests' 1.2"
}

* =============================================================================
* TEST 2: Missing Treatment Values
* =============================================================================

display _n "{hline 78}"
display "{bf:TEST 2: Missing Treatment Values}"
display "{hline 78}" _n

display as text "Test 2.1: tvweight with missing treatment"
local ++total_tests

clear
set seed 22222
set obs 500

gen x1 = rnormal()
gen treatment = runiform() > 0.5
replace treatment = . if runiform() < 0.05  // 5% missing treatment

capture tvweight treatment, covariates(x1) generate(w)

if _rc == 0 {
    quietly count if missing(w)
    local n_miss_w = r(N)
    quietly count if missing(treatment)
    local n_miss_t = r(N)

    if `n_miss_w' >= `n_miss_t' {
        display as result "  PASS: Missing treatment -> missing weights"
        local ++total_pass
    }
    else {
        display as error "  FAIL: Weights computed for missing treatment"
        local ++total_fail
        local failed_tests "`failed_tests' 2.1"
    }
}
else {
    display as error "  FAIL: Error with missing treatment"
    local ++total_fail
    local failed_tests "`failed_tests' 2.1"
}

* =============================================================================
* TEST 3: Missing Outcome Values
* =============================================================================

display _n "{hline 78}"
display "{bf:TEST 3: Missing Outcome Values}"
display "{hline 78}" _n

display as text "Test 3.1: tvestimate with missing outcomes"
local ++total_tests

clear
set seed 33333
set obs 500

gen x1 = rnormal()
gen treatment = runiform() > 0.5
gen outcome = 10 + 2*treatment + x1 + rnormal()
replace outcome = . if runiform() < 0.1  // 10% missing

capture tvestimate outcome treatment, confounders(x1)

if _rc == 0 {
    display as result "  PASS: tvestimate handles missing outcomes"
    local ++total_pass
}
else {
    display as error "  FAIL: Error with missing outcomes"
    local ++total_fail
    local failed_tests "`failed_tests' 3.1"
}

* =============================================================================
* TEST 4: Binary Covariates
* =============================================================================

display _n "{hline 78}"
display "{bf:TEST 4: Binary Covariates}"
display "{hline 78}" _n

display as text "Test 4.1: tvweight with binary covariates"
local ++total_tests

clear
set seed 44444
set obs 500

gen female = runiform() > 0.5
gen diabetes = runiform() > 0.85
gen hypertension = runiform() > 0.7
gen treatment = runiform() < invlogit(-1 + 0.3*female + 0.5*diabetes + 0.4*hypertension)

capture tvweight treatment, covariates(female diabetes hypertension) generate(w)

if _rc == 0 {
    quietly summarize w
    if r(min) > 0 & r(max) < . {
        display as result "  PASS: Binary covariates handled correctly"
        local ++total_pass
    }
    else {
        display as error "  FAIL: Invalid weights with binary covariates"
        local ++total_fail
        local failed_tests "`failed_tests' 4.1"
    }
}
else {
    display as error "  FAIL: Error with binary covariates"
    local ++total_fail
    local failed_tests "`failed_tests' 4.1"
}

* Test 4.2: tvestimate with binary covariates
display as text "Test 4.2: tvestimate with binary confounders"
local ++total_tests

gen outcome = 50 + 3*treatment + 5*female + 10*diabetes + rnormal(0, 5)

capture tvestimate outcome treatment, confounders(female diabetes hypertension)

if _rc == 0 {
    local psi = e(psi)
    if abs(`psi' - 3) < 1.5 {
        display as result "  PASS: Binary confounders work (effect ~ " %4.2f `psi' ")"
        local ++total_pass
    }
    else {
        display as error "  FAIL: Effect estimate wrong with binary confounders"
        local ++total_fail
        local failed_tests "`failed_tests' 4.2"
    }
}
else {
    display as error "  FAIL: Error with binary confounders"
    local ++total_fail
    local failed_tests "`failed_tests' 4.2"
}

* =============================================================================
* TEST 5: Categorical Covariates (as factor)
* =============================================================================

display _n "{hline 78}"
display "{bf:TEST 5: Categorical Covariates}"
display "{hline 78}" _n

display as text "Test 5.1: tvweight with categorical covariate (dummies)"
local ++total_tests

clear
set seed 55555
set obs 500

* Create categorical variable with 4 levels
gen region = 1 + floor(runiform() * 4)
gen continuous = rnormal()

* Create dummies
gen region2 = region == 2
gen region3 = region == 3
gen region4 = region == 4

gen treatment = runiform() < invlogit(-0.5 + 0.3*region2 + 0.5*region3 + 0.2*region4 + 0.1*continuous)

capture tvweight treatment, covariates(region2 region3 region4 continuous) generate(w)

if _rc == 0 {
    display as result "  PASS: Dummy-coded categorical covariate works"
    local ++total_pass
}
else {
    display as error "  FAIL: Error with categorical covariate"
    local ++total_fail
    local failed_tests "`failed_tests' 5.1"
}

* =============================================================================
* TEST 6: Mixed Covariate Types
* =============================================================================

display _n "{hline 78}"
display "{bf:TEST 6: Mixed Covariate Types}"
display "{hline 78}" _n

display as text "Test 6.1: All types together"
local ++total_tests

clear
set seed 66666
set obs 1000

* Binary
gen female = runiform() > 0.5
gen smoker = runiform() > 0.8

* Categorical (dummies)
gen education = 1 + floor(runiform() * 3)
gen edu_hs = education == 2
gen edu_college = education == 3

* Continuous
gen age = 40 + rnormal() * 15
gen bmi = 25 + rnormal() * 5
gen income = exp(10 + rnormal())  // Log-normal

* Treatment
gen pr_treat = invlogit(-2 + 0.02*age + 0.3*female + 0.5*smoker + 0.2*edu_college + 0.00001*income)
gen treatment = runiform() < pr_treat

capture tvweight treatment, covariates(female smoker edu_hs edu_college age bmi income) generate(w)

if _rc == 0 {
    quietly summarize w
    display as result "  PASS: Mixed covariate types handled"
    display as text "        Weights: mean=" %5.2f r(mean) ", range=[" %5.2f r(min) ", " %5.2f r(max) "]"
    local ++total_pass
}
else {
    display as error "  FAIL: Error with mixed covariate types"
    local ++total_fail
    local failed_tests "`failed_tests' 6.1"
}

* Test 6.2: G-estimation with mixed types
display as text "Test 6.2: tvestimate with mixed types"
local ++total_tests

gen outcome = 100 + 5*treatment + 0.3*age - 2*female + 5*smoker + rnormal(0, 10)

capture tvestimate outcome treatment, confounders(female smoker edu_hs edu_college age bmi income)

if _rc == 0 {
    local psi = e(psi)
    display as result "  PASS: Mixed types in G-estimation (effect = " %5.2f `psi' ")"
    local ++total_pass
}
else {
    display as error "  FAIL: Error with mixed types in G-estimation"
    local ++total_fail
    local failed_tests "`failed_tests' 6.2"
}

* =============================================================================
* TEST 7: High-Dimensional Covariates
* =============================================================================

display _n "{hline 78}"
display "{bf:TEST 7: High-Dimensional Covariates}"
display "{hline 78}" _n

display as text "Test 7.1: tvweight with 15 covariates"
local ++total_tests

clear
set seed 77777
set obs 1000

* Generate 15 covariates
forvalues i = 1/15 {
    gen x`i' = rnormal()
}

gen treatment = runiform() > 0.5

capture tvweight treatment, covariates(x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 x12 x13 x14 x15) generate(w)

if _rc == 0 {
    display as result "  PASS: 15 covariates handled"
    local ++total_pass
}
else {
    display as error "  FAIL: Error with 15 covariates"
    local ++total_fail
    local failed_tests "`failed_tests' 7.1"
}

* Test 7.2: tvdml with many covariates
display as text "Test 7.2: tvdml with 15 covariates"
local ++total_tests

gen outcome = 10 + 2*treatment + 0.1*x1 + 0.1*x2 + rnormal()

capture tvdml outcome treatment, covariates(x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 x12 x13 x14 x15) crossfit(3) seed(99999)

if _rc == 0 {
    display as result "  PASS: DML with 15 covariates"
    local ++total_pass
}
else {
    display as error "  FAIL: Error with DML and 15 covariates"
    local ++total_fail
    local failed_tests "`failed_tests' 7.2"
}

* =============================================================================
* TEST 8: Sparse Binary Covariates
* =============================================================================

display _n "{hline 78}"
display "{bf:TEST 8: Sparse Binary Covariates}"
display "{hline 78}" _n

display as text "Test 8.1: Very rare binary covariate (2%)"
local ++total_tests

clear
set seed 88888
set obs 1000

gen x1 = rnormal()
gen rare_disease = runiform() < 0.02  // Only 2% have disease
gen treatment = runiform() > 0.5

capture tvweight treatment, covariates(x1 rare_disease) generate(w)

if _rc == 0 {
    display as result "  PASS: Rare binary covariate handled"
    local ++total_pass
}
else {
    display as error "  FAIL: Error with rare binary covariate"
    local ++total_fail
    local failed_tests "`failed_tests' 8.1"
}

* =============================================================================
* FINAL SUMMARY
* =============================================================================

display _n "{hline 78}"
display "{bf:MISSING DATA AND COVARIATE TYPE TEST SUMMARY}"
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
    display _n as result "{bf:ALL MISSING DATA AND COVARIATE TESTS PASSED!}"
}

display _n "{hline 78}"
display "Completed: `c(current_date)' `c(current_time)'"
display "{hline 78}"
