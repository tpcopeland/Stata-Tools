/*******************************************************************************
* test_tvbalance.do
*
* Purpose: Functional tests for tvbalance command
*          Tests SMD calculation, weighted balance, threshold flagging
*
* Run: stata-mp -b do test_tvbalance.do
*******************************************************************************/

clear all
set more off
version 16.0
set varabbrev off

* Install tvtools
local root_dir "`c(pwd)'"
capture net uninstall tvtools
quietly net install tvtools, from("`root_dir'/tvtools") replace

local pass_count = 0
local fail_count = 0

display as text _newline _dup(70) "="
display as text "tvbalance Functional Tests"
display as text _dup(70) "="

* ============================================================================
* TEST 1: Basic SMD calculation with known data
* ============================================================================
display as text _newline "TEST 1: Basic binary SMD"
display as text _dup(70) "-"

clear
set seed 42
set obs 200

gen long id = _n
gen byte exposure = (_n > 100)

* Covariate with known difference: ref mean ~10 sd 2, exp mean ~12 sd 3
gen double age = cond(exposure == 0, rnormal(10, 2), rnormal(12, 3))

* Run tvbalance
tvbalance age, exposure(exposure)

* Get SMD from returned matrix
matrix b = r(balance)
local smd = b[1,3]

* Hand-calculate expected SMD
quietly summarize age if exposure == 0
local mean_ref = r(mean)
local var_ref = r(Var)
quietly summarize age if exposure == 1
local mean_exp = r(mean)
local var_exp = r(Var)

local expected_smd = (`mean_exp' - `mean_ref') / sqrt((`var_ref' + `var_exp') / 2)

* Check they match (should be identical since same formula)
local diff = abs(`smd' - `expected_smd')
if `diff' < 0.0001 {
    display as result "PASS: SMD = " %7.4f `smd' " (expected " %7.4f `expected_smd' ")"
    local pass_count = `pass_count' + 1
}
else {
    display as error "FAIL: SMD = " %7.4f `smd' " (expected " %7.4f `expected_smd' ", diff=" %9.6f `diff' ")"
    local fail_count = `fail_count' + 1
}

* ============================================================================
* TEST 2: SMD with zero imbalance
* ============================================================================
display as text _newline "TEST 2: SMD with identical distributions"
display as text _dup(70) "-"

clear
set obs 100
gen long id = _n
gen byte exposure = (_n > 50)
gen double covar = 5  // constant → SMD should be 0

tvbalance covar, exposure(exposure)
matrix b = r(balance)
local smd = b[1,3]

if abs(`smd') < 0.0001 {
    display as result "PASS: SMD = " %7.4f `smd' " (expected ~0)"
    local pass_count = `pass_count' + 1
}
else {
    display as error "FAIL: SMD = " %7.4f `smd' " (expected ~0)"
    local fail_count = `fail_count' + 1
}

* ============================================================================
* TEST 3: Multiple covariates
* ============================================================================
display as text _newline "TEST 3: Multiple covariates"
display as text _dup(70) "-"

clear
set seed 42
set obs 200
gen long id = _n
gen byte exposure = (_n > 100)
gen double age = cond(exposure == 0, rnormal(50, 5), rnormal(52, 5))
gen byte sex = (runiform() > 0.5)
gen double bmi = rnormal(25, 3)

tvbalance age sex bmi, exposure(exposure)
matrix b = r(balance)

* Should have 3 rows (one per covariate)
local nrows = rowsof(b)
if `nrows' == 3 {
    display as result "PASS: Matrix has " `nrows' " rows (one per covariate)"
    local pass_count = `pass_count' + 1
}
else {
    display as error "FAIL: Matrix has " `nrows' " rows (expected 3)"
    local fail_count = `fail_count' + 1
}

* ============================================================================
* TEST 4: Return values present
* ============================================================================
display as text _newline "TEST 4: Return values"
display as text _dup(70) "-"

* r(balance) matrix should exist
capture matrix list r(balance)
if _rc == 0 {
    display as result "PASS: r(balance) matrix exists"
    local pass_count = `pass_count' + 1
}
else {
    display as error "FAIL: r(balance) matrix not found"
    local fail_count = `fail_count' + 1
}

* ============================================================================
* TEST 5: SMD sign direction (with non-zero variance)
* ============================================================================
display as text _newline "TEST 5: SMD sign direction (exposed has higher mean)"
display as text _dup(70) "-"

clear
set seed 99
set obs 200
gen long id = _n
gen byte exposure = (_n > 100)
gen double covar = cond(exposure == 0, rnormal(10, 2), rnormal(20, 2))

tvbalance covar, exposure(exposure)
matrix b = r(balance)
local smd = b[1,3]

if `smd' > 0 & !missing(`smd') {
    display as result "PASS: SMD is positive when exposed mean > reference mean (SMD=" %7.4f `smd' ")"
    local pass_count = `pass_count' + 1
}
else {
    display as error "FAIL: SMD should be positive but got " %7.4f `smd'
    local fail_count = `fail_count' + 1
}

* ============================================================================
* SUMMARY
* ============================================================================

display as text _newline _dup(70) "="
display as text "SUMMARY: " as result `pass_count' " passed, " `fail_count' " failed"
display as text _dup(70) "="

if `fail_count' > 0 {
    exit 9
}
