* validation_outlier.do
*
* Validation tests for outlier command — known-answer tests verifying
* detection math, edge cases, stored results, and action correctness.
*
* Author: Timothy P Copeland
* Date: 2026-03-14

clear all
set more off
version 16.0

* =============================================================================
* SETUP
* =============================================================================
capture ado uninstall outlier
quietly net install outlier, from("~/Stata-Tools/outlier") replace

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

* =============================================================================
* SECTION 1: Known-answer IQR tests
* =============================================================================

* Test 1: IQR bounds structure (no outliers in clean sequence)
* Data: 1 2 3 4 5 6 7 8 9 10
* Stata p25=3, p75=8, IQR=5, multiplier=1.5
* Lower = 3 - 7.5 = -4.5, Upper = 8 + 7.5 = 15.5
local ++test_count
display as text _n "Test `test_count': Known-answer IQR bounds (no outliers)"

capture {
    clear
    set obs 10
    gen x = _n
    outlier x
    assert r(n_outliers) == 0
    assert reldif(r(lower), -4.5) < 0.01
    assert reldif(r(upper), 15.5) < 0.01
}
if _rc == 0 {
    display as result "  PASSED"
    local ++pass_count
}
else {
    display as error "  FAILED (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* Test 2: IQR with known outlier
* Add values 50 and -40 to dataset — both should be flagged
local ++test_count
display as text _n "Test `test_count': Known-answer IQR with outliers"

capture {
    clear
    set obs 12
    gen x = _n in 1/10
    replace x = 50 in 11
    replace x = -40 in 12
    outlier x
    assert r(n_outliers) == 2
}
if _rc == 0 {
    display as result "  PASSED"
    local ++pass_count
}
else {
    display as error "  FAILED (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* Test 3: IQR multiplier=3 makes outliers disappear
local ++test_count
display as text _n "Test `test_count': IQR multiplier=3 reduces outlier count"

capture {
    clear
    set obs 102
    gen x = _n in 1/100
    replace x = 200 in 101
    replace x = -100 in 102
    outlier x, multiplier(1.5)
    local n_out_15 = r(n_outliers)
    outlier x, multiplier(3)
    local n_out_3 = r(n_outliers)
    assert `n_out_3' <= `n_out_15'
}
if _rc == 0 {
    display as result "  PASSED (m=1.5: `n_out_15', m=3: `n_out_3')"
    local ++pass_count
}
else {
    display as error "  FAILED (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* =============================================================================
* SECTION 2: Known-answer SD tests
* =============================================================================

* Test 4: SD method with known mean/SD
* 100 identical values of 50, plus one value at 200
* mean ~ 51.49, sd ~ 14.85 with multiplier=3: upper ~ 51.49+44.55=96.04
* So 200 should be flagged
local ++test_count
display as text _n "Test `test_count': SD method flags extreme value"

capture {
    clear
    set obs 101
    gen x = 50 in 1/100
    replace x = 200 in 101
    outlier x, method(sd) multiplier(3)
    assert r(n_outliers) >= 1
    assert "`r(method)'" == "sd"
}
if _rc == 0 {
    display as result "  PASSED"
    local ++pass_count
}
else {
    display as error "  FAILED (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* Test 5: SD method — tight multiplier flags more
local ++test_count
display as text _n "Test `test_count': SD multiplier=1 flags more than multiplier=3"

capture {
    clear
    set obs 100
    set seed 99999
    gen x = rnormal(0, 1)
    outlier x, method(sd) multiplier(1)
    local n1 = r(n_outliers)
    outlier x, method(sd) multiplier(3)
    local n3 = r(n_outliers)
    assert `n1' >= `n3'
}
if _rc == 0 {
    display as result "  PASSED (m=1: `n1', m=3: `n3')"
    local ++pass_count
}
else {
    display as error "  FAILED (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* =============================================================================
* SECTION 3: Edge cases
* =============================================================================

* Test 6: Single observation
local ++test_count
display as text _n "Test `test_count': Single observation"

capture {
    clear
    set obs 1
    gen x = 42
    outlier x
    assert r(N) == 1
}
if _rc == 0 {
    display as result "  PASSED"
    local ++pass_count
}
else {
    display as error "  FAILED (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* Test 7: All identical values — no outliers possible
local ++test_count
display as text _n "Test `test_count': All identical values (IQR=0)"

capture {
    clear
    set obs 50
    gen x = 100
    outlier x
    assert r(n_outliers) == 0
}
if _rc == 0 {
    display as result "  PASSED"
    local ++pass_count
}
else {
    display as error "  FAILED (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* Test 8: All missing values — command runs with 0 outliers
local ++test_count
display as text _n "Test `test_count': All missing values (0 outliers)"

capture {
    clear
    set obs 20
    gen x = .
    outlier x
    * marksample novarlist includes missing obs, but no non-missing
    * values can be outliers, so n_outliers must be 0
    assert r(n_outliers) == 0
}
if _rc == 0 {
    display as result "  PASSED"
    local ++pass_count
}
else {
    display as error "  FAILED (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* =============================================================================
* SECTION 4: Stored results verification
* =============================================================================

* Test 9: All expected r() scalars present for IQR
local ++test_count
display as text _n "Test `test_count': r() scalars complete for IQR"

capture {
    clear
    set obs 50
    set seed 11111
    gen x = rnormal(100, 15)
    outlier x
    * Check all expected returns exist and are non-missing
    assert r(N) == 50
    assert r(n_outliers) != .
    assert r(multiplier) == 1.5
    assert r(lower) != .
    assert r(upper) != .
    assert r(lower) < r(upper)
    assert "`r(method)'" == "iqr"
    assert "`r(action)'" == "flag"
}
if _rc == 0 {
    display as result "  PASSED"
    local ++pass_count
}
else {
    display as error "  FAILED (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* Test 10: Results matrix correct for multi-variable
local ++test_count
display as text _n "Test `test_count': r(results) matrix dimensions"

capture {
    clear
    set obs 50
    set seed 22222
    gen x = rnormal()
    gen y = rnormal()
    gen z = rnormal()
    outlier x y z
    matrix M = r(results)
    assert rowsof(M) == 3
    assert colsof(M) == 7
    * Row names should match variables
    local rn : rownames M
    assert "`rn'" == "x y z"
}
if _rc == 0 {
    display as result "  PASSED"
    local ++pass_count
}
else {
    display as error "  FAILED (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* =============================================================================
* SECTION 5: Action verification
* =============================================================================

* Test 11: Winsorize caps at bounds
local ++test_count
display as text _n "Test `test_count': Winsorize caps values at bounds"

capture {
    clear
    set obs 12
    gen x = _n in 1/10
    replace x = 100 in 11
    replace x = -80 in 12
    outlier x, action(winsorize) generate(w_)
    * Get bounds
    outlier x
    local lb = r(lower)
    local ub = r(upper)
    * Winsorized values should not exceed bounds
    quietly summarize w__x
    assert r(max) <= `ub' + 0.001
    assert r(min) >= `lb' - 0.001
    * Non-outlier values should be unchanged
    assert w__x[1] == x[1]
    assert w__x[5] == x[5]
}
if _rc == 0 {
    display as result "  PASSED"
    local ++pass_count
}
else {
    display as error "  FAILED (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* Test 12: Exclude sets outliers to missing
local ++test_count
display as text _n "Test `test_count': Exclude drops outlier values to missing"

capture {
    clear
    set obs 12
    gen x = _n in 1/10
    replace x = 100 in 11
    replace x = -80 in 12
    outlier x, action(exclude) generate(ex_)
    * Outlier positions should be missing
    assert missing(ex__x[11])
    assert missing(ex__x[12])
    * Non-outlier positions should be non-missing
    assert !missing(ex__x[1])
    assert !missing(ex__x[5])
}
if _rc == 0 {
    display as result "  PASSED"
    local ++pass_count
}
else {
    display as error "  FAILED (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* Test 13: Flag creates correct indicator
local ++test_count
display as text _n "Test `test_count': Flag creates correct 0/1 indicator"

capture {
    clear
    set obs 12
    gen x = _n in 1/10
    replace x = 100 in 11
    replace x = -80 in 12
    outlier x, action(flag) generate(fl_)
    * Outlier positions should be flagged 1
    assert fl__x[11] == 1
    assert fl__x[12] == 1
    * Non-outlier positions should be 0
    assert fl__x[1] == 0
    assert fl__x[5] == 0
    * Sum of flags should equal n_outliers
    quietly count if fl__x == 1
    local n_flagged = r(N)
    outlier x
    assert `n_flagged' == r(n_outliers)
}
if _rc == 0 {
    display as result "  PASSED"
    local ++pass_count
}
else {
    display as error "  FAILED (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* Test 14: N outliers from flag matches n_outliers from detect
local ++test_count
display as text _n "Test `test_count': Flag count matches r(n_outliers)"

capture {
    clear
    set obs 100
    set seed 33333
    gen x = rnormal(50, 10)
    replace x = 200 in 1
    replace x = -100 in 2
    replace x = 150 in 3
    outlier x
    local expected = r(n_outliers)
    outlier x, action(flag) generate(check_)
    quietly count if check__x == 1
    assert r(N) == `expected'
}
if _rc == 0 {
    display as result "  PASSED"
    local ++pass_count
}
else {
    display as error "  FAILED (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* Test 15: Exclude reduces non-missing count by n_outliers
local ++test_count
display as text _n "Test `test_count': Exclude reduces non-missing count correctly"

capture {
    clear
    set obs 100
    set seed 44444
    gen x = rnormal(0, 1)
    replace x = 20 in 1
    replace x = -20 in 2
    quietly count if !missing(x)
    local orig_n = r(N)
    outlier x
    local n_out = r(n_outliers)
    outlier x, action(exclude) generate(ex_)
    quietly count if !missing(ex__x)
    assert r(N) == `orig_n' - `n_out'
}
if _rc == 0 {
    display as result "  PASSED"
    local ++pass_count
}
else {
    display as error "  FAILED (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* =============================================================================
* SUMMARY
* =============================================================================
display as text _n "{hline 70}"
display as text "OUTLIER VALIDATION TEST SUMMARY"
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
    display as error "Some tests FAILED."
    exit 1
}
else {
    display as result "All tests PASSED!"
}

display as text _n "Validation completed: `c(current_date)' `c(current_time)'"
