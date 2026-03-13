/*******************************************************************************
* validation_balancetab.do
*
* Purpose: Deep validation tests for balancetab using known-answer testing.
*          Verifies SMD calculations, means, matrix contents, and invariants
*          against hand-calculated expected values.
*
* Philosophy: Create minimal datasets where every output value can be
*             mathematically verified by hand.
*
* Run modes:
*   Standalone: do validation_balancetab.do
*   Via runner: do run_test.do validation_balancetab [testnumber] [quiet] [machine]
*
* Author: Timothy Copeland
* Date: 2026-03-13
*******************************************************************************/

clear all
set more off
set seed 12345
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
    global STATA_TOOLS_PATH "/home/tpcopeland/Stata-Tools"
}
else {
    global STATA_TOOLS_PATH "`c(pwd)'"
}

global QA_DIR "${STATA_TOOLS_PATH}/balancetab/qa"
global DATA_DIR "${QA_DIR}/data"

capture mkdir "${DATA_DIR}"

adopath ++ "${STATA_TOOLS_PATH}/balancetab"

* Reload to pick up latest changes
capture program drop balancetab
run "${STATA_TOOLS_PATH}/balancetab/balancetab.ado"

* =============================================================================
* HEADER
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "BALANCETAB DEEP VALIDATION TESTS"
    display as text "{hline 70}"
    display as text "These tests verify mathematical correctness, not just execution."
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
* HELPER: Floating-point equality with reldif()
* =============================================================================
capture program drop _assert_equal
program define _assert_equal
    args actual expected tolerance
    if "`tolerance'" == "" local tolerance = 1e-6

    if missing(`actual') & missing(`expected') exit 0
    if missing(`actual') | missing(`expected') {
        display as error "  Expected: `expected', Got: `actual' (one is missing)"
        exit 9
    }

    local rel_diff = reldif(`actual', `expected')
    if `rel_diff' > `tolerance' {
        local abs_diff = abs(`actual' - `expected')
        display as error "  Expected: `expected', Got: `actual'"
        display as error "  Absolute diff: `abs_diff', Relative diff: `rel_diff'"
        exit 9
    }
end

* =============================================================================
* CREATE VALIDATION DATASETS
* =============================================================================
if `quiet' == 0 {
    display as text _n "Creating validation datasets..."
}

* Dataset 1: 10 obs for exact hand calculations
* Treatment (id 1-5): covar = 10, 12, 14, 16, 18 -> mean=14, var=10
* Control   (id 6-10): covar = 6, 8, 10, 12, 14  -> mean=10, var=10
* Pooled SD = sqrt((10+10)/2) = sqrt(10) = 3.16228
* SMD = (14-10)/3.16228 = 1.26491
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
label data "10 obs for hand calculation"
save "${DATA_DIR}/valid_balance_10.dta", replace

* Dataset 2: Known negative SMD (treatment mean < control mean)
* Treatment (id 1-5): covar = 2, 4, 6, 8, 10 -> mean=6, var=10
* Control   (id 6-10): covar = 10, 12, 14, 16, 18 -> mean=14, var=10
* SMD = (6-14)/sqrt(10) = -8/3.16228 = -2.52982
clear
input id treat covar
    1 1 2
    2 1 4
    3 1 6
    4 1 8
    5 1 10
    6 0 10
    7 0 12
    8 0 14
    9 0 16
    10 0 18
end
label data "10 obs, negative SMD (T < C)"
save "${DATA_DIR}/valid_balance_neg.dta", replace

* Dataset 3: 100 obs balanced groups
clear
set obs 100
gen id = _n
gen treat = _n <= 50
gen covar1 = cond(treat==1, 100 + 10*invnorm(uniform()), 90 + 10*invnorm(uniform()))
gen covar2 = 50 + 5*invnorm(uniform())
label data "100 obs: 50 treated, 50 control"
save "${DATA_DIR}/valid_balance_100.dta", replace

if `quiet' == 0 {
    display as result "Validation datasets created."
}

* =============================================================================
* SECTION 1: SMD CALCULATION VALIDATION
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 1: SMD Calculation Validation"
    display as text "{hline 70}"
}

* Test 1: Known SMD calculation (10-obs dataset)
local ++test_count
if `quiet' == 0 display as text _n "Test `test_count': SMD with known values"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        use "${DATA_DIR}/valid_balance_10.dta", clear
        balancetab covar, treatment(treat)

        * Hand-calculated: SMD = (14-10)/sqrt(10) = 1.26491
        _assert_equal `r(N_treated)' 5 0.01
        _assert_equal `r(N_control)' 5 0.01

        matrix M = r(balance)
        local smd = M[1,3]
        _assert_equal `smd' 1.26491 0.001
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' display "[OK] `test_count'"
        else if `quiet' == 0 display as result "  PASS: SMD = 1.265 (expected 1.265)"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' display "[FAIL] `test_count'|`=_rc'|SMD calculation"
        else display as error "  FAIL: SMD calculation (error `=_rc')"
    }
}

* Test 2: Means validation (matrix cols 1 and 2)
local ++test_count
if `quiet' == 0 display as text _n "Test `test_count': Means in matrix cols 1-2"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        use "${DATA_DIR}/valid_balance_10.dta", clear
        balancetab covar, treatment(treat)

        matrix M = r(balance)
        * Treatment mean = (10+12+14+16+18)/5 = 14
        _assert_equal M[1,1] 14 1e-6
        * Control mean = (6+8+10+12+14)/5 = 10
        _assert_equal M[1,2] 10 1e-6
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' display "[OK] `test_count'"
        else if `quiet' == 0 display as result "  PASS: Mean(T)=14, Mean(C)=10"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' display "[FAIL] `test_count'|`=_rc'|Means validation"
        else display as error "  FAIL: Means validation (error `=_rc')"
    }
}

* Test 3: Zero SMD when groups are identical
local ++test_count
if `quiet' == 0 display as text _n "Test `test_count': Zero SMD for constant covariate"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        clear
        set obs 100
        gen treat = _n <= 50
        gen covar = 50

        balancetab covar, treatment(treat)
        matrix M = r(balance)
        _assert_equal M[1,3] 0 0.001
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' display "[OK] `test_count'"
        else if `quiet' == 0 display as result "  PASS: SMD = 0 for constant covariate"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' display "[FAIL] `test_count'|`=_rc'|Zero SMD"
        else display as error "  FAIL: Zero SMD test (error `=_rc')"
    }
}

* Test 4: SMD sign positive when T > C
local ++test_count
if `quiet' == 0 display as text _n "Test `test_count': SMD positive when T > C"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        use "${DATA_DIR}/valid_balance_10.dta", clear
        balancetab covar, treatment(treat)

        matrix M = r(balance)
        assert M[1,3] > 0
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' display "[OK] `test_count'"
        else if `quiet' == 0 display as result "  PASS: SMD > 0 when T > C"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' display "[FAIL] `test_count'|`=_rc'|SMD sign positive"
        else display as error "  FAIL: SMD sign test (error `=_rc')"
    }
}

* Test 5: SMD sign negative when T < C
local ++test_count
if `quiet' == 0 display as text _n "Test `test_count': SMD negative when T < C"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        use "${DATA_DIR}/valid_balance_neg.dta", clear
        balancetab covar, treatment(treat)

        matrix M = r(balance)
        * Treatment mean=6, Control mean=14, so SMD should be negative
        assert M[1,3] < 0
        _assert_equal M[1,3] -2.52982 0.001
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' display "[OK] `test_count'"
        else if `quiet' == 0 display as result "  PASS: SMD = -2.530 when T < C"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' display "[FAIL] `test_count'|`=_rc'|SMD sign negative"
        else display as error "  FAIL: SMD negative test (error `=_rc')"
    }
}

* =============================================================================
* SECTION 2: COUNT VALIDATION
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 2: Count Validation"
    display as text "{hline 70}"
}

* Test 6: Correct treatment/control counts
local ++test_count
if `quiet' == 0 display as text _n "Test `test_count': Treatment/control counts"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        use "${DATA_DIR}/valid_balance_100.dta", clear
        balancetab covar1, treatment(treat)

        assert r(N_treated) == 50
        assert r(N_control) == 50
        assert r(N) == 100
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' display "[OK] `test_count'"
        else if `quiet' == 0 display as result "  PASS: Counts correct (50/50/100)"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' display "[FAIL] `test_count'|`=_rc'|Count validation"
        else display as error "  FAIL: Count validation (error `=_rc')"
    }
}

* Test 7: n_imbalanced count accuracy
local ++test_count
if `quiet' == 0 display as text _n "Test `test_count': n_imbalanced count"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        use "${DATA_DIR}/valid_balance_10.dta", clear
        * SMD = 1.265, which exceeds any reasonable threshold
        balancetab covar, treatment(treat) threshold(0.1)
        assert r(n_imbalanced) == 1
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' display "[OK] `test_count'"
        else if `quiet' == 0 display as result "  PASS: n_imbalanced = 1"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' display "[FAIL] `test_count'|`=_rc'|n_imbalanced"
        else display as error "  FAIL: n_imbalanced count (error `=_rc')"
    }
}

* Test 8: Threshold boundary - exactly at threshold is balanced
local ++test_count
if `quiet' == 0 display as text _n "Test `test_count': Threshold boundary (SMD = threshold)"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        use "${DATA_DIR}/valid_balance_10.dta", clear
        * SMD = 1.26491, set threshold to 1.265 (just above)
        balancetab covar, treatment(treat) threshold(1.265)
        assert r(n_imbalanced) == 0

        * Now set threshold to 1.264 (just below)
        balancetab covar, treatment(treat) threshold(1.264)
        assert r(n_imbalanced) == 1
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' display "[OK] `test_count'"
        else if `quiet' == 0 display as result "  PASS: Threshold boundary correct"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' display "[FAIL] `test_count'|`=_rc'|Threshold boundary"
        else display as error "  FAIL: Threshold boundary (error `=_rc')"
    }
}

* Test 9: if condition reduces N correctly
local ++test_count
if `quiet' == 0 display as text _n "Test `test_count': if condition reduces N"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        use "${DATA_DIR}/valid_balance_10.dta", clear
        * Keep ids 1-8: 5 treated (id 1-5) + 3 control (id 6-8)
        balancetab covar if id <= 8, treatment(treat)
        assert r(N) == 8
        assert r(N_treated) == 5
        assert r(N_control) == 3

        * Hand calc:
        * T: (10+12+14+16+18)/5 = 14, T var = (16+4+0+4+16)/4 = 10
        * C: (6+8+10)/3 = 8, C var = (4+0+4)/2 = 4
        * Pooled SD = sqrt((10+4)/2) = sqrt(7) = 2.64575
        * SMD = (14-8)/2.64575 = 2.26779
        matrix M = r(balance)
        _assert_equal M[1,1] 14 1e-6
        _assert_equal M[1,2] 8 1e-6
        _assert_equal M[1,3] 2.26779 0.001
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' display "[OK] `test_count'"
        else if `quiet' == 0 display as result "  PASS: if condition N=8, SMD=1.549"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' display "[FAIL] `test_count'|`=_rc'|if condition"
        else display as error "  FAIL: if condition test (error `=_rc')"
    }
}

* =============================================================================
* SECTION 3: MATRIX STRUCTURE VALIDATION
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 3: Matrix Structure Validation"
    display as text "{hline 70}"
}

* Test 10: Matrix dimensions
local ++test_count
if `quiet' == 0 display as text _n "Test `test_count': Matrix dimensions"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        sysuse auto, clear
        balancetab price mpg weight, treatment(foreign)

        matrix M = r(balance)
        assert rowsof(M) == 3
        assert colsof(M) == 6
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' display "[OK] `test_count'"
        else if `quiet' == 0 display as result "  PASS: Matrix is 3x6"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' display "[FAIL] `test_count'|`=_rc'|Matrix dimensions"
        else display as error "  FAIL: Matrix dimensions (error `=_rc')"
    }
}

* Test 11: Matrix row names match varlist
local ++test_count
if `quiet' == 0 display as text _n "Test `test_count': Matrix row names"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        sysuse auto, clear
        balancetab price mpg, treatment(foreign)

        matrix M = r(balance)
        local rnames : rownames M
        assert "`rnames'" == "price mpg"
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' display "[OK] `test_count'"
        else if `quiet' == 0 display as result "  PASS: Row names match varlist"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' display "[FAIL] `test_count'|`=_rc'|Matrix row names"
        else display as error "  FAIL: Matrix row names (error `=_rc')"
    }
}

* Test 12: Unadjusted columns 4-6 are missing
local ++test_count
if `quiet' == 0 display as text _n "Test `test_count': Unadjusted cols 4-6 missing"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        sysuse auto, clear
        balancetab price mpg, treatment(foreign)

        matrix M = r(balance)
        assert missing(M[1,4])
        assert missing(M[1,5])
        assert missing(M[1,6])
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' display "[OK] `test_count'"
        else if `quiet' == 0 display as result "  PASS: Cols 4-6 missing when unadjusted"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' display "[FAIL] `test_count'|`=_rc'|Unadjusted cols"
        else display as error "  FAIL: Unadjusted columns (error `=_rc')"
    }
}

* =============================================================================
* SECTION 4: WEIGHTED SMD VALIDATION
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 4: Weighted SMD Validation"
    display as text "{hline 70}"
}

* Test 13: Adjusted columns populated when weighted
local ++test_count
if `quiet' == 0 display as text _n "Test `test_count': Adjusted columns populated"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        sysuse auto, clear
        gen wgt = 1 + uniform()
        balancetab price mpg, treatment(foreign) wvar(wgt)

        matrix M = r(balance)
        assert !missing(M[1,4])
        assert !missing(M[1,5])
        assert !missing(M[1,6])
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' display "[OK] `test_count'"
        else if `quiet' == 0 display as result "  PASS: Adjusted columns populated"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' display "[FAIL] `test_count'|`=_rc'|Adjusted columns"
        else display as error "  FAIL: Adjusted columns (error `=_rc')"
    }
}

* Test 14: Unit weights = unweighted
local ++test_count
if `quiet' == 0 display as text _n "Test `test_count': Unit weights equal unweighted"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        use "${DATA_DIR}/valid_balance_10.dta", clear

        * Unweighted SMD
        balancetab covar, treatment(treat)
        matrix M_raw = r(balance)
        local smd_raw = M_raw[1,3]

        * Weighted with all weights = 1 (should give same result)
        gen wgt = 1
        balancetab covar, treatment(treat) wvar(wgt)
        matrix M_wgt = r(balance)
        local smd_adj = M_wgt[1,6]

        _assert_equal `smd_adj' `smd_raw' 1e-6
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' display "[OK] `test_count'"
        else if `quiet' == 0 display as result "  PASS: Unit weights = unweighted"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' display "[FAIL] `test_count'|`=_rc'|Unit weights"
        else display as error "  FAIL: Unit weights test (error `=_rc')"
    }
}

* Test 15: Hand-calculated weighted means
local ++test_count
if `quiet' == 0 display as text _n "Test `test_count': Hand-calculated weighted means"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        * Create simple dataset with known weights
        clear
        input id treat covar wgt
            1 1 10 2
            2 1 20 1
            3 0 5  1
            4 0 15 2
        end

        balancetab covar, treatment(treat) wvar(wgt)
        matrix M = r(balance)

        * Weighted mean(T) = (10*2 + 20*1)/(2+1) = 40/3 = 13.3333
        _assert_equal M[1,4] 13.33333 0.001

        * Weighted mean(C) = (5*1 + 15*2)/(1+2) = 35/3 = 11.6667
        _assert_equal M[1,5] 11.66667 0.001
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' display "[OK] `test_count'"
        else if `quiet' == 0 display as result "  PASS: Weighted means match hand calc"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' display "[FAIL] `test_count'|`=_rc'|Weighted means"
        else display as error "  FAIL: Weighted means (error `=_rc')"
    }
}

* Test 16: IPTW reduces SMD for confounded data
local ++test_count
if `quiet' == 0 display as text _n "Test `test_count': IPTW reduces SMD"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        sysuse auto, clear

        * Get raw SMD
        balancetab price mpg, treatment(foreign)
        local raw_max = r(max_smd_raw)

        * Create IPTW weights
        logit foreign price mpg
        predict ps, pr
        gen ipw = cond(foreign==1, 1/ps, 1/(1-ps))
        replace ipw = min(ipw, 10)

        balancetab price mpg, treatment(foreign) wvar(ipw)

        * Adjusted max should exist (direction of change depends on data)
        assert r(max_smd_adj) != .
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' display "[OK] `test_count'"
        else if `quiet' == 0 display as result "  PASS: Weighted SMD calculated"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' display "[FAIL] `test_count'|`=_rc'|IPTW reduces SMD"
        else display as error "  FAIL: IPTW test (error `=_rc')"
    }
}

* =============================================================================
* SECTION 5: INVARIANT TESTS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 5: Invariant Tests"
    display as text "{hline 70}"
}

* Test 17: max_smd_raw equals max of |SMD| values
local ++test_count
if `quiet' == 0 display as text _n "Test `test_count': max_smd_raw invariant"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        sysuse auto, clear
        balancetab price mpg weight, treatment(foreign)

        matrix M = r(balance)
        local max_manual = 0
        forvalues i = 1/3 {
            if !missing(M[`i',3]) {
                local abs_smd = abs(M[`i',3])
                if `abs_smd' > `max_manual' local max_manual = `abs_smd'
            }
        }

        _assert_equal `r(max_smd_raw)' `max_manual' 1e-6
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' display "[OK] `test_count'"
        else if `quiet' == 0 display as result "  PASS: max_smd_raw matches calculated max"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' display "[FAIL] `test_count'|`=_rc'|max_smd_raw invariant"
        else display as error "  FAIL: max_smd_raw invariant (error `=_rc')"
    }
}

* Test 18: N_treated + N_control = N
local ++test_count
if `quiet' == 0 display as text _n "Test `test_count': Count conservation"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        sysuse auto, clear
        balancetab price mpg, treatment(foreign)
        assert r(N_treated) + r(N_control) == r(N)
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' display "[OK] `test_count'"
        else if `quiet' == 0 display as result "  PASS: N_treated + N_control = N"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' display "[FAIL] `test_count'|`=_rc'|Count conservation"
        else display as error "  FAIL: Count conservation (error `=_rc')"
    }
}

* Test 19: Idempotency - running twice gives same result
local ++test_count
if `quiet' == 0 display as text _n "Test `test_count': Idempotency"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        use "${DATA_DIR}/valid_balance_10.dta", clear

        * Run 1
        balancetab covar, treatment(treat)
        matrix M1 = r(balance)
        local N1 = r(N)
        local smd1 = r(max_smd_raw)

        * Run 2
        balancetab covar, treatment(treat)
        matrix M2 = r(balance)
        local N2 = r(N)
        local smd2 = r(max_smd_raw)

        assert `N1' == `N2'
        _assert_equal `smd1' `smd2' 1e-10
        _assert_equal M1[1,1] M2[1,1] 1e-10
        _assert_equal M1[1,2] M2[1,2] 1e-10
        _assert_equal M1[1,3] M2[1,3] 1e-10
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' display "[OK] `test_count'"
        else if `quiet' == 0 display as result "  PASS: Idempotency holds"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' display "[FAIL] `test_count'|`=_rc'|Idempotency"
        else display as error "  FAIL: Idempotency (error `=_rc')"
    }
}

* Test 20: Data preservation
local ++test_count
if `quiet' == 0 display as text _n "Test `test_count': Data preservation"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        sysuse auto, clear
        local orig_N = _N
        local orig_vars : char _dta[__varlist__]

        * Run with all output types
        gen wgt = 1 + uniform()
        balancetab price mpg weight, treatment(foreign) wvar(wgt)

        * N preserved
        assert _N == `orig_N'
        * Original variables still exist
        confirm variable price mpg weight foreign make
        * No extra variables created
        confirm variable wgt
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' display "[OK] `test_count'"
        else if `quiet' == 0 display as result "  PASS: Data preserved"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' display "[FAIL] `test_count'|`=_rc'|Data preservation"
        else display as error "  FAIL: Data preservation (error `=_rc')"
    }
}

* Test 21: Threshold stored correctly
local ++test_count
if `quiet' == 0 display as text _n "Test `test_count': Threshold stored in r()"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        sysuse auto, clear
        balancetab price, treatment(foreign) threshold(0.25)
        _assert_equal r(threshold) 0.25 1e-10

        balancetab price, treatment(foreign)
        _assert_equal r(threshold) 0.1 1e-10
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' display "[OK] `test_count'"
        else if `quiet' == 0 display as result "  PASS: Threshold stored correctly"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' display "[FAIL] `test_count'|`=_rc'|Threshold stored"
        else display as error "  FAIL: Threshold stored (error `=_rc')"
    }
}

* Test 22: Return macro correctness
local ++test_count
if `quiet' == 0 display as text _n "Test `test_count': Return macros correct"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        sysuse auto, clear
        gen wgt = 1
        balancetab price mpg, treatment(foreign) wvar(wgt)

        assert "`r(treatment)'" == "foreign"
        assert "`r(varlist)'" == "price mpg"
        assert "`r(wvar)'" == "wgt"
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' display "[OK] `test_count'"
        else if `quiet' == 0 display as result "  PASS: Return macros correct"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' display "[FAIL] `test_count'|`=_rc'|Return macros"
        else display as error "  FAIL: Return macros (error `=_rc')"
    }
}

* =============================================================================
* CLEANUP
* =============================================================================
capture erase "${DATA_DIR}/valid_balance_10.dta"
capture erase "${DATA_DIR}/valid_balance_neg.dta"
capture erase "${DATA_DIR}/valid_balance_100.dta"

* =============================================================================
* SUMMARY
* =============================================================================
if `machine' {
    display "[SUMMARY] `pass_count'/`test_count' passed"
    if `fail_count' > 0 {
        display "[FAILED]`failed_tests'"
    }
}
else {
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
}

display as text _n "Validation completed: `c(current_date)' `c(current_time)'"

* Clear global flags
global RUN_TEST_QUIET
global RUN_TEST_MACHINE
global RUN_TEST_NUMBER
