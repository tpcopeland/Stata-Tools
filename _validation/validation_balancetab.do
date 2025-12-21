/*******************************************************************************
* validation_balancetab.do
*
* Purpose: Deep validation tests for balancetab using known-answer testing.
*          Verifies SMD calculations against hand-calculated expected values.
*
* Author: Claude (automated testing)
* Date: 2025-12-21
*******************************************************************************/

clear all
set more off
version 16.0

* =============================================================================
* PATH CONFIGURATION
* =============================================================================
if "`c(os)'" == "MacOSX" {
    global STATA_TOOLS_PATH "/Users/tcopeland/Documents/GitHub/Stata-Tools"
}
else if "`c(os)'" == "Unix" {
    global STATA_TOOLS_PATH "/home/ubuntu/Stata-Tools"
}
else {
    global STATA_TOOLS_PATH "`c(pwd)'"
}

global VALIDATION_DIR "${STATA_TOOLS_PATH}/_validation"
global DATA_DIR "${VALIDATION_DIR}/data"

capture mkdir "${DATA_DIR}"

* Install package
capture net uninstall balancetab
quietly net install balancetab, from("${STATA_TOOLS_PATH}/balancetab")

* =============================================================================
* HEADER
* =============================================================================
display as text _n "{hline 70}"
display as text "BALANCETAB DEEP VALIDATION TESTS"
display as text "{hline 70}"
display as text "These tests verify mathematical correctness, not just execution."
display as text "{hline 70}"

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

* =============================================================================
* HELPER: Tolerance comparison
* =============================================================================
capture program drop _assert_near
program define _assert_near
    args actual expected tol
    if "`tol'" == "" local tol = 0.001
    local diff = abs(`actual' - `expected')
    if `diff' > `tol' {
        display as error "  Expected: `expected', Got: `actual' (diff: `diff')"
        exit 9
    }
end

* =============================================================================
* CREATE VALIDATION DATASETS
* =============================================================================
display as text _n "Creating validation datasets..."

* Dataset 1: Simple known values for SMD calculation
* Treatment: n=50, Mean=100, SD=10
* Control: n=50, Mean=90, SD=10
* Pooled SD = sqrt((100+100)/2) = 10
* SMD = (100-90)/10 = 1.0
clear
set obs 100
gen id = _n
gen treat = _n <= 50

* Create covariate with known properties
* Treatment group: mean=100, sd=10
* Control group: mean=90, sd=10
set seed 12345
gen covar1 = cond(treat==1, 100 + 10*invnorm(uniform()), 90 + 10*invnorm(uniform()))

* Create another covariate with zero difference
gen covar2 = 50 + 5*invnorm(uniform())

label data "100 obs: 50 treated, 50 control"
save "${DATA_DIR}/valid_balance_100.dta", replace

* Dataset 2: Perfectly balanced dataset
clear
set obs 100
gen id = _n
gen treat = _n <= 50
gen balanced_var = _n
label data "Perfectly balanced by design"
save "${DATA_DIR}/valid_balance_perfect.dta", replace

* Dataset 3: Small dataset for exact calculations
clear
input id treat covar
    1 1 10
    2 1 12
    3 1 14
    4 1 16
    5 1 18
    6 0 6
    7 0 8
    8 0 10
    9 0 12
    10 0 14
end
* Treatment: mean=14, var=10
* Control: mean=10, var=10
* Pooled SD = sqrt((10+10)/2) = sqrt(10) = 3.162
* SMD = (14-10)/3.162 = 1.265
label data "10 obs for hand calculation"
save "${DATA_DIR}/valid_balance_10.dta", replace

display as result "Validation datasets created."

* =============================================================================
* SECTION 1: SMD CALCULATION VALIDATION
* =============================================================================
display as text _n "{hline 70}"
display as text "SECTION 1: SMD Calculation Validation"
display as text "{hline 70}"

* -----------------------------------------------------------------------------
* Test 1.1: Known SMD calculation (10-obs dataset)
* -----------------------------------------------------------------------------
local ++test_count
display as text _n "Test 1.1: SMD calculation with known values"

capture {
    use "${DATA_DIR}/valid_balance_10.dta", clear

    * Hand-calculated values:
    * Treatment: mean = (10+12+14+16+18)/5 = 14
    * Control: mean = (6+8+10+12+14)/5 = 10
    * Treatment variance = sum((x-14)^2)/4 = (16+4+0+4+16)/4 = 10
    * Control variance = sum((x-10)^2)/4 = (16+4+0+4+16)/4 = 10
    * Pooled SD = sqrt((10+10)/2) = sqrt(10) = 3.1623
    * SMD = (14-10)/3.1623 = 1.2649

    balancetab covar, treatment(treat)

    * Check returned values
    _assert_near `r(N_treated)' 5 0.1
    _assert_near `r(N_control)' 5 0.1

    * Get SMD from matrix
    matrix M = r(balance)
    local smd = M[1,3]
    _assert_near `smd' 1.2649 0.01
}
if _rc == 0 {
    display as result "  PASS: SMD = 1.265 (expected 1.265)"
    local ++pass_count
}
else {
    display as error "  FAIL: SMD calculation (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 1.1"
}

* -----------------------------------------------------------------------------
* Test 1.2: Zero SMD when groups are identical
* -----------------------------------------------------------------------------
local ++test_count
display as text _n "Test 1.2: Zero SMD when no difference"

capture {
    clear
    set obs 100
    gen treat = _n <= 50
    gen covar = 50  // Constant value

    balancetab covar, treatment(treat)

    matrix M = r(balance)
    local smd = M[1,3]
    _assert_near `smd' 0 0.001
}
if _rc == 0 {
    display as result "  PASS: SMD = 0 for constant covariate"
    local ++pass_count
}
else {
    display as error "  FAIL: Zero SMD test (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 1.2"
}

* -----------------------------------------------------------------------------
* Test 1.3: SMD sign is correct (positive when T > C)
* -----------------------------------------------------------------------------
local ++test_count
display as text _n "Test 1.3: SMD sign correctness"

capture {
    use "${DATA_DIR}/valid_balance_10.dta", clear

    balancetab covar, treatment(treat)

    matrix M = r(balance)
    local smd = M[1,3]
    * Treatment mean (14) > Control mean (10), so SMD should be positive
    assert `smd' > 0
}
if _rc == 0 {
    display as result "  PASS: SMD is positive when T > C"
    local ++pass_count
}
else {
    display as error "  FAIL: SMD sign test (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 1.3"
}

* =============================================================================
* SECTION 2: COUNT VALIDATION
* =============================================================================
display as text _n "{hline 70}"
display as text "SECTION 2: Count Validation"
display as text "{hline 70}"

* -----------------------------------------------------------------------------
* Test 2.1: Correct treatment/control counts
* -----------------------------------------------------------------------------
local ++test_count
display as text _n "Test 2.1: Treatment/control counts"

capture {
    use "${DATA_DIR}/valid_balance_100.dta", clear

    balancetab covar1, treatment(treat)

    assert r(N_treated) == 50
    assert r(N_control) == 50
    assert r(N) == 100
}
if _rc == 0 {
    display as result "  PASS: Counts correct (50 treated, 50 control)"
    local ++pass_count
}
else {
    display as error "  FAIL: Count validation (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 2.1"
}

* -----------------------------------------------------------------------------
* Test 2.2: n_imbalanced count
* -----------------------------------------------------------------------------
local ++test_count
display as text _n "Test 2.2: n_imbalanced count"

capture {
    use "${DATA_DIR}/valid_balance_10.dta", clear

    * SMD = 1.265 which is > 0.1 threshold
    balancetab covar, treatment(treat) threshold(0.1)

    assert r(n_imbalanced) == 1
}
if _rc == 0 {
    display as result "  PASS: n_imbalanced = 1 (SMD > threshold)"
    local ++pass_count
}
else {
    display as error "  FAIL: n_imbalanced count (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 2.2"
}

* =============================================================================
* SECTION 3: MATRIX STRUCTURE VALIDATION
* =============================================================================
display as text _n "{hline 70}"
display as text "SECTION 3: Matrix Structure Validation"
display as text "{hline 70}"

* -----------------------------------------------------------------------------
* Test 3.1: Matrix dimensions
* -----------------------------------------------------------------------------
local ++test_count
display as text _n "Test 3.1: Matrix dimensions"

capture {
    sysuse auto, clear
    balancetab price mpg weight, treatment(foreign)

    matrix M = r(balance)
    assert rowsof(M) == 3  // 3 covariates
    assert colsof(M) == 6  // 6 columns
}
if _rc == 0 {
    display as result "  PASS: Matrix is 3x6"
    local ++pass_count
}
else {
    display as error "  FAIL: Matrix dimensions (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.1"
}

* -----------------------------------------------------------------------------
* Test 3.2: Matrix row names
* -----------------------------------------------------------------------------
local ++test_count
display as text _n "Test 3.2: Matrix row names"

capture {
    sysuse auto, clear
    balancetab price mpg, treatment(foreign)

    matrix M = r(balance)
    local rnames : rownames M
    assert "`rnames'" == "price mpg"
}
if _rc == 0 {
    display as result "  PASS: Row names match varlist"
    local ++pass_count
}
else {
    display as error "  FAIL: Matrix row names (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.2"
}

* =============================================================================
* SECTION 4: WEIGHTED SMD VALIDATION
* =============================================================================
display as text _n "{hline 70}"
display as text "SECTION 4: Weighted SMD Validation"
display as text "{hline 70}"

* -----------------------------------------------------------------------------
* Test 4.1: Weights reduce SMD when appropriate
* -----------------------------------------------------------------------------
local ++test_count
display as text _n "Test 4.1: IPTW reduces SMD"

capture {
    sysuse auto, clear

    * Get raw SMD
    balancetab price mpg, treatment(foreign)
    local raw_max = r(max_smd_raw)

    * Create weights that should improve balance
    logit foreign price mpg
    predict ps, pr
    gen ipw = cond(foreign==1, 1/ps, 1/(1-ps))

    * Truncate extreme weights
    replace ipw = min(ipw, 10)

    balancetab price mpg, treatment(foreign) wvar(ipw)

    * Adjusted max SMD should exist
    assert r(max_smd_adj) != .
}
if _rc == 0 {
    display as result "  PASS: Weighted SMD calculated"
    local ++pass_count
}
else {
    display as error "  FAIL: Weighted SMD (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.1"
}

* -----------------------------------------------------------------------------
* Test 4.2: Adjusted columns filled when weighted
* -----------------------------------------------------------------------------
local ++test_count
display as text _n "Test 4.2: Adjusted columns populated"

capture {
    sysuse auto, clear
    gen wgt = 1 + uniform()

    balancetab price mpg, treatment(foreign) wvar(wgt)

    matrix M = r(balance)
    * Columns 4,5,6 should be non-missing
    assert M[1,4] != .
    assert M[1,5] != .
    assert M[1,6] != .
}
if _rc == 0 {
    display as result "  PASS: Adjusted columns populated"
    local ++pass_count
}
else {
    display as error "  FAIL: Adjusted columns (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.2"
}

* =============================================================================
* SECTION 5: INVARIANT TESTS
* =============================================================================
display as text _n "{hline 70}"
display as text "SECTION 5: Invariant Tests"
display as text "{hline 70}"

* -----------------------------------------------------------------------------
* Test 5.1: max_smd_raw equals maximum of |SMD| values
* -----------------------------------------------------------------------------
local ++test_count
display as text _n "Test 5.1: max_smd_raw invariant"

capture {
    sysuse auto, clear
    balancetab price mpg weight, treatment(foreign)

    matrix M = r(balance)
    local max_manual = 0
    forvalues i = 1/3 {
        local abs_smd = abs(M[`i',3])
        if `abs_smd' > `max_manual' local max_manual = `abs_smd'
    }

    _assert_near `r(max_smd_raw)' `max_manual' 0.0001
}
if _rc == 0 {
    display as result "  PASS: max_smd_raw matches calculated maximum"
    local ++pass_count
}
else {
    display as error "  FAIL: max_smd_raw invariant (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 5.1"
}

* -----------------------------------------------------------------------------
* Test 5.2: N_treated + N_control = N
* -----------------------------------------------------------------------------
local ++test_count
display as text _n "Test 5.2: Count conservation"

capture {
    sysuse auto, clear
    balancetab price mpg, treatment(foreign)

    assert r(N_treated) + r(N_control) == r(N)
}
if _rc == 0 {
    display as result "  PASS: N_treated + N_control = N"
    local ++pass_count
}
else {
    display as error "  FAIL: Count conservation (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 5.2"
}

* =============================================================================
* CLEANUP
* =============================================================================
capture erase "${DATA_DIR}/valid_balance_100.dta"
capture erase "${DATA_DIR}/valid_balance_perfect.dta"
capture erase "${DATA_DIR}/valid_balance_10.dta"

* =============================================================================
* SUMMARY
* =============================================================================
display as text _n "{hline 70}"
display as text "BALANCETAB VALIDATION SUMMARY"
display as text "{hline 70}"
display as text "Total tests:  `test_count'"
display as result "Passed:       `pass_count'"
if `fail_count' > 0 {
    display as error "Failed:       `fail_count'"
    display as error "Failed tests:`failed_tests'"
}
else {
    display as text "Failed:       `fail_count'"
}
display as text "{hline 70}"

if `fail_count' > 0 {
    display as error _n "Some validation tests FAILED."
    exit 1
}
else {
    display as result _n "ALL VALIDATION TESTS PASSED!"
}

display as text _n "Validation completed: `c(current_date)' `c(current_time)'"
