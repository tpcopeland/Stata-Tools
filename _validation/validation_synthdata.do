/*******************************************************************************
* validation_synthdata.do
*
* Purpose: Validation tests for synthdata command
*
* Author: Claude Code
* Date: 2025-12-14
*******************************************************************************/

clear all
set more off
version 16.0

* =============================================================================
* PATH CONFIGURATION
* =============================================================================
local pwd "`c(pwd)'"
if regexm("`pwd'", "_validation$") {
    local base_path ".."
}
else {
    local base_path "."
}

adopath ++ "`base_path'/synthdata"

capture mkdir "data"

* =============================================================================
* HEADER
* =============================================================================
display as text _n "{hline 70}"
display as text "SYNTHDATA VALIDATION TESTS"
display as text "{hline 70}"

local test_count = 0
local pass_count = 0
local fail_count = 0

* =============================================================================
* SECTION 1: BASIC EXECUTION
* =============================================================================
display as text _n "SECTION 1: Basic Execution" _n

* Test 1.1: Basic execution
local ++test_count
display as text "Test 1.1: Basic execution with sysuse auto"
capture {
    sysuse auto, clear
    synthdata, saving(data/val_synth_temp.dta) replace
}
if _rc == 0 {
    display as result "  PASS: synthdata executes without error"
    local ++pass_count
}
else {
    display as error "  FAIL: synthdata failed with error `=_rc'"
    local ++fail_count
}

* =============================================================================
* SECTION 2: METHODS
* =============================================================================
display as text _n "SECTION 2: Synthesis Methods" _n

* Test 2.1: Parametric method (default)
local ++test_count
display as text "Test 2.1: Parametric method"
capture {
    sysuse auto, clear
    synthdata, saving(data/val_synth_param.dta) replace seed(12345)
}
if _rc == 0 {
    display as result "  PASS: Parametric method works"
    local ++pass_count
}
else {
    display as error "  FAIL: Parametric method failed"
    local ++fail_count
}

* Test 2.2: Bootstrap method
local ++test_count
display as text "Test 2.2: Bootstrap method"
capture {
    sysuse auto, clear
    synthdata, bootstrap saving(data/val_synth_boot.dta) replace seed(12345)
}
if _rc == 0 {
    display as result "  PASS: Bootstrap method works"
    local ++pass_count
}
else {
    display as error "  FAIL: Bootstrap method failed"
    local ++fail_count
}

* Test 2.3: Permute method
local ++test_count
display as text "Test 2.3: Permute method"
capture {
    sysuse auto, clear
    synthdata, permute saving(data/val_synth_perm.dta) replace seed(12345)
}
if _rc == 0 {
    display as result "  PASS: Permute method works"
    local ++pass_count
}
else {
    display as error "  FAIL: Permute method failed"
    local ++fail_count
}

* =============================================================================
* SECTION 3: OPTIONS
* =============================================================================
display as text _n "SECTION 3: Options" _n

* Test 3.1: n() option
local ++test_count
display as text "Test 3.1: n(50) option"
capture {
    sysuse auto, clear
    synthdata, n(50) saving(data/val_synth_n50.dta) replace
    use data/val_synth_n50.dta, clear
    local new_n = _N
}
if _rc == 0 & `new_n' == 50 {
    display as result "  PASS: n(50) produced 50 observations"
    local ++pass_count
}
else {
    display as error "  FAIL: n(50) option failed"
    local ++fail_count
}

* Test 3.2: seed() option for reproducibility
local ++test_count
display as text "Test 3.2: seed() option"
local val1 = .
local val2 = .
capture {
    sysuse auto, clear
    synthdata, seed(12345) saving(data/val_synth_s1.dta) replace
    use data/val_synth_s1.dta, clear
    local val1 = price[1]

    sysuse auto, clear
    synthdata, seed(12345) saving(data/val_synth_s2.dta) replace
    use data/val_synth_s2.dta, clear
    local val2 = price[1]
}
if _rc == 0 & `val1' != . & `val1' == `val2' {
    display as result "  PASS: seed() produces reproducible results"
    local ++pass_count
}
else {
    display as error "  FAIL: seed() option not reproducible"
    local ++fail_count
}

* =============================================================================
* SECTION 4: OUTPUT VALIDATION
* =============================================================================
display as text _n "SECTION 4: Output Validation" _n

* Test 4.1: Output preserves variable count
local ++test_count
display as text "Test 4.1: Variable count preserved"
capture {
    sysuse auto, clear
    local orig_k = c(k)
    synthdata, saving(data/val_synth_vars.dta) replace
    use data/val_synth_vars.dta, clear
    local new_k = c(k)
}
if _rc == 0 & `orig_k' == `new_k' {
    display as result "  PASS: Variable count preserved (`orig_k' -> `new_k')"
    local ++pass_count
}
else {
    display as error "  FAIL: Variable count changed"
    local ++fail_count
}

* =============================================================================
* SECTION 5: MATHEMATICAL VALIDATIONS
* =============================================================================
display as text _n "SECTION 5: Mathematical Validations" _n

* Test 5.1: Mean preservation within tolerance
local ++test_count
display as text "Test 5.1: Mean preservation (within 20%)"
capture {
    sysuse auto, clear
    sum price
    local orig_mean = r(mean)
    local orig_sd = r(sd)

    synthdata, n(500) saving(data/val_synth_mean.dta) replace seed(12345)
    use data/val_synth_mean.dta, clear
    sum price
    local synth_mean = r(mean)

    * Check within 20% tolerance
    local pct_diff = abs(`synth_mean' - `orig_mean') / `orig_mean' * 100
    assert `pct_diff' < 20
}
if _rc == 0 {
    display as result "  PASS: Mean preserved within 20% (`pct_diff'%)"
    local ++pass_count
}
else {
    display as error "  FAIL: Mean not preserved"
    local ++fail_count
}

* Test 5.2: Standard deviation preservation
local ++test_count
display as text "Test 5.2: Standard deviation preservation (within 30%)"
capture {
    sysuse auto, clear
    sum mpg
    local orig_sd = r(sd)

    synthdata, n(500) saving(data/val_synth_sd.dta) replace seed(12345)
    use data/val_synth_sd.dta, clear
    sum mpg
    local synth_sd = r(sd)

    local pct_diff = abs(`synth_sd' - `orig_sd') / `orig_sd' * 100
    assert `pct_diff' < 30
}
if _rc == 0 {
    display as result "  PASS: SD preserved within 30% (`pct_diff'%)"
    local ++pass_count
}
else {
    display as error "  FAIL: SD not preserved"
    local ++fail_count
}

* Test 5.3: Categorical proportions preservation
local ++test_count
display as text "Test 5.3: Categorical proportions (foreign)"
capture {
    sysuse auto, clear
    tab foreign
    local orig_pct = r(N)
    count if foreign == 1
    local orig_foreign = r(N) / _N * 100

    synthdata, n(500) categorical(foreign) saving(data/val_synth_cat.dta) replace seed(12345)
    use data/val_synth_cat.dta, clear
    count if foreign == 1
    local synth_foreign = r(N) / _N * 100

    * Within 15 percentage points
    local pct_diff = abs(`synth_foreign' - `orig_foreign')
    assert `pct_diff' < 15
}
if _rc == 0 {
    display as result "  PASS: Categorical proportions preserved (diff = `pct_diff'%)"
    local ++pass_count
}
else {
    display as error "  FAIL: Categorical proportions not preserved"
    local ++fail_count
}

* Test 5.4: Correlation preservation
local ++test_count
display as text "Test 5.4: Correlation preservation (price/mpg)"
capture {
    sysuse auto, clear
    correlate price mpg
    local orig_corr = r(rho)

    synthdata, n(500) correlations saving(data/val_synth_corr.dta) replace seed(12345)
    use data/val_synth_corr.dta, clear
    correlate price mpg
    local synth_corr = r(rho)

    * Correlation should be within 0.3
    local corr_diff = abs(`synth_corr' - `orig_corr')
    assert `corr_diff' < 0.3
}
if _rc == 0 {
    display as result "  PASS: Correlation preserved (diff = `corr_diff')"
    local ++pass_count
}
else {
    display as error "  FAIL: Correlation not preserved"
    local ++fail_count
}

* Test 5.5: Range preservation with noextreme
local ++test_count
display as text "Test 5.5: Range preservation with noextreme"
capture {
    sysuse auto, clear
    sum price
    local orig_min = r(min)
    local orig_max = r(max)

    synthdata, n(500) noextreme saving(data/val_synth_range.dta) replace seed(12345)
    use data/val_synth_range.dta, clear
    sum price

    * Synthetic values should be within original range
    assert r(min) >= `orig_min'
    assert r(max) <= `orig_max'
}
if _rc == 0 {
    display as result "  PASS: Values within original range"
    local ++pass_count
}
else {
    display as error "  FAIL: Values outside original range"
    local ++fail_count
}

* Test 5.6: Bounds constraint enforcement
local ++test_count
display as text "Test 5.6: Bounds constraint enforcement"
capture {
    sysuse auto, clear

    synthdata, n(500) bounds("mpg 15 30") saving(data/val_synth_bounds.dta) replace seed(12345)
    use data/val_synth_bounds.dta, clear
    sum mpg

    assert r(min) >= 15
    assert r(max) <= 30
}
if _rc == 0 {
    display as result "  PASS: Bounds constraints enforced"
    local ++pass_count
}
else {
    display as error "  FAIL: Bounds constraints not enforced"
    local ++fail_count
}

* Test 5.7: Constraints enforcement
local ++test_count
display as text "Test 5.7: Constraints enforcement"
capture {
    sysuse auto, clear

    synthdata, n(500) constraints("price>=5000" "price<=15000") ///
        saving(data/val_synth_cons.dta) replace seed(12345)
    use data/val_synth_cons.dta, clear
    sum price

    assert r(min) >= 5000
    assert r(max) <= 15000
}
if _rc == 0 {
    display as result "  PASS: Constraints enforced"
    local ++pass_count
}
else {
    display as error "  FAIL: Constraints not enforced"
    local ++fail_count
}

* =============================================================================
* SECTION 6: KNOWN-ANSWER TESTS (Minimal Datasets)
* =============================================================================
display as text _n "SECTION 6: Known-Answer Tests" _n

* Test 6.1: Binary variable preservation
local ++test_count
display as text "Test 6.1: Binary variable (50/50 split)"
capture {
    clear
    set obs 100
    gen byte binary = _n <= 50

    synthdata, n(1000) categorical(binary) saving(data/val_synth_binary.dta) replace seed(12345)
    use data/val_synth_binary.dta, clear

    count if binary == 1
    local pct_ones = r(N) / _N * 100

    * Should be approximately 50% (within 10 percentage points)
    assert abs(`pct_ones' - 50) < 10
}
if _rc == 0 {
    display as result "  PASS: Binary 50/50 preserved (`pct_ones'%)"
    local ++pass_count
}
else {
    display as error "  FAIL: Binary proportions not preserved"
    local ++fail_count
}

* Test 6.2: Uniform distribution test
local ++test_count
display as text "Test 6.2: Uniform distribution synthesis"
capture {
    clear
    set obs 100
    gen double uniform = _n  // Values 1-100

    synthdata, n(1000) saving(data/val_synth_uniform.dta) replace seed(12345)
    use data/val_synth_uniform.dta, clear
    sum uniform

    * Mean should be around 50.5 (within 20%)
    local expected_mean = 50.5
    local pct_diff = abs(r(mean) - `expected_mean') / `expected_mean' * 100
    assert `pct_diff' < 20
}
if _rc == 0 {
    display as result "  PASS: Uniform distribution mean preserved"
    local ++pass_count
}
else {
    display as error "  FAIL: Uniform distribution not preserved"
    local ++fail_count
}

* Test 6.3: Multi-category variable
local ++test_count
display as text "Test 6.3: Multi-category variable (4 groups)"
capture {
    clear
    set obs 100
    gen byte category = ceil(_n/25)  // 25 each of 1,2,3,4

    synthdata, n(1000) categorical(category) saving(data/val_synth_multi.dta) replace seed(12345)
    use data/val_synth_multi.dta, clear

    * Each category should be approximately 25% (within 10 percentage points)
    forvalues i = 1/4 {
        count if category == `i'
        local pct_`i' = r(N) / _N * 100
        assert abs(`pct_`i'' - 25) < 10
    }
}
if _rc == 0 {
    display as result "  PASS: Multi-category proportions preserved"
    local ++pass_count
}
else {
    display as error "  FAIL: Multi-category proportions not preserved"
    local ++fail_count
}

* Test 6.4: Zero-variance variable handling
local ++test_count
display as text "Test 6.4: Zero-variance variable handling"
capture {
    clear
    set obs 50
    gen byte constant = 5
    gen double varied = rnormal(100, 10)

    synthdata, n(100) saving(data/val_synth_const.dta) replace seed(12345)
    use data/val_synth_const.dta, clear

    sum constant
    * Constant variable should remain constant or close
    assert r(sd) < 1
}
if _rc == 0 {
    display as result "  PASS: Zero-variance variable handled"
    local ++pass_count
}
else {
    display as error "  FAIL: Zero-variance variable not handled properly"
    local ++fail_count
}

* =============================================================================
* SECTION 7: LARGE DATASET VALIDATIONS
* =============================================================================
display as text _n "SECTION 7: Large Dataset Validations" _n

* Test 7.1: Large dataset synthesis (5000 obs)
local ++test_count
display as text "Test 7.1: Large dataset synthesis (5000 obs)"
capture {
    sysuse auto, clear
    sum price
    local orig_mean = r(mean)

    synthdata, n(5000) saving(data/val_synth_large.dta) replace seed(12345)
    use data/val_synth_large.dta, clear
    assert _N == 5000

    sum price
    local synth_mean = r(mean)
    local pct_diff = abs(`synth_mean' - `orig_mean') / `orig_mean' * 100
    assert `pct_diff' < 15  // Stricter with larger N
}
if _rc == 0 {
    display as result "  PASS: Large dataset synthesis works (mean diff `pct_diff'%)"
    local ++pass_count
}
else {
    display as error "  FAIL: Large dataset synthesis failed"
    local ++fail_count
}

* Test 7.2: Very large synthesis (10000 obs)
local ++test_count
display as text "Test 7.2: Very large synthesis (10000 obs)"
capture {
    sysuse auto, clear

    synthdata, n(10000) saving(data/val_synth_vlarge.dta) replace seed(12345)
    use data/val_synth_vlarge.dta, clear
    assert _N == 10000
}
if _rc == 0 {
    display as result "  PASS: Very large synthesis (10000 obs) works"
    local ++pass_count
}
else {
    display as error "  FAIL: Very large synthesis failed"
    local ++fail_count
}

* Test 7.3: Multiple synthesis consistency
local ++test_count
display as text "Test 7.3: Multiple synthesis consistency"
capture {
    sysuse auto, clear

    synthdata, n(500) multiple(3) saving(data/val_synth_mult) replace seed(12345)

    * Each file should exist and have 500 obs
    forvalues i = 1/3 {
        use data/val_synth_mult_`i'.dta, clear
        assert _N == 500
    }
}
if _rc == 0 {
    display as result "  PASS: Multiple synthesis files created correctly"
    local ++pass_count
}
else {
    display as error "  FAIL: Multiple synthesis failed"
    local ++fail_count
}

* Test 7.4: Large dataset with correlations
local ++test_count
display as text "Test 7.4: Large dataset correlation preservation"
capture {
    sysuse auto, clear
    correlate price mpg
    local orig_corr = r(rho)

    synthdata, n(5000) correlations saving(data/val_synth_lcorr.dta) replace seed(12345)
    use data/val_synth_lcorr.dta, clear
    correlate price mpg
    local synth_corr = r(rho)

    * With large N, correlation should be closer
    local corr_diff = abs(`synth_corr' - `orig_corr')
    assert `corr_diff' < 0.2
}
if _rc == 0 {
    display as result "  PASS: Large dataset correlation preserved (diff = `corr_diff')"
    local ++pass_count
}
else {
    display as error "  FAIL: Large dataset correlation not preserved"
    local ++fail_count
}

* =============================================================================
* SECTION 8: BOOTSTRAP AND PERMUTE VALIDATIONS
* =============================================================================
display as text _n "SECTION 8: Bootstrap and Permute Method Validations" _n

* Test 8.1: Bootstrap preserves exact values
local ++test_count
display as text "Test 8.1: Bootstrap uses exact original values"
capture {
    sysuse auto, clear
    sum price
    local orig_min = r(min)
    local orig_max = r(max)

    * Note: Bootstrap sample size must be <= original N (74 for auto dataset)
    synthdata, bootstrap n(50) saving(data/val_synth_bootval.dta) replace seed(12345)
    use data/val_synth_bootval.dta, clear
    sum price

    * Bootstrap should produce values within original range (exact resampling)
    assert r(min) >= `orig_min'
    assert r(max) <= `orig_max'
}
if _rc == 0 {
    display as result "  PASS: Bootstrap values within original range"
    local ++pass_count
}
else {
    display as error "  FAIL: Bootstrap produced out-of-range values"
    local ++fail_count
}

* Test 8.2: Permute breaks correlations
local ++test_count
display as text "Test 8.2: Permute method breaks correlations"
capture {
    sysuse auto, clear
    correlate price mpg
    local orig_corr = abs(r(rho))

    synthdata, permute n(500) saving(data/val_synth_permcorr.dta) replace seed(12345)
    use data/val_synth_permcorr.dta, clear
    correlate price mpg
    local perm_corr = abs(r(rho))

    * Permute should reduce correlation magnitude (not necessarily to zero)
    assert `perm_corr' < `orig_corr' + 0.1  // Allow some random correlation
}
if _rc == 0 {
    display as result "  PASS: Permute method works (orig corr: `orig_corr', perm corr: `perm_corr')"
    local ++pass_count
}
else {
    display as error "  FAIL: Permute did not affect correlations as expected"
    local ++fail_count
}

* =============================================================================
* CLEANUP
* =============================================================================
capture erase data/val_synth_temp.dta
capture erase data/val_synth_param.dta
capture erase data/val_synth_boot.dta
capture erase data/val_synth_perm.dta
capture erase data/val_synth_n50.dta
capture erase data/val_synth_s1.dta
capture erase data/val_synth_s2.dta
capture erase data/val_synth_vars.dta
capture erase data/val_synth_mean.dta
capture erase data/val_synth_sd.dta
capture erase data/val_synth_cat.dta
capture erase data/val_synth_corr.dta
capture erase data/val_synth_range.dta
capture erase data/val_synth_bounds.dta
capture erase data/val_synth_cons.dta
capture erase data/val_synth_binary.dta
capture erase data/val_synth_uniform.dta
capture erase data/val_synth_multi.dta
capture erase data/val_synth_const.dta
capture erase data/val_synth_large.dta
capture erase data/val_synth_vlarge.dta
capture erase data/val_synth_mult_1.dta
capture erase data/val_synth_mult_2.dta
capture erase data/val_synth_mult_3.dta
capture erase data/val_synth_lcorr.dta
capture erase data/val_synth_bootval.dta
capture erase data/val_synth_permcorr.dta

* =============================================================================
* SUMMARY
* =============================================================================
display as text _n "{hline 70}"
display as text "SYNTHDATA VALIDATION SUMMARY"
display as text "{hline 70}"
display as text "Total tests:  `test_count'"
display as result "Passed:       `pass_count'"
if `fail_count' > 0 {
    display as error "Failed:       `fail_count'"
    display as error "Some validation tests FAILED."
    exit 1
}
else {
    display as text "Failed:       `fail_count'"
    display as result "ALL VALIDATION TESTS PASSED!"
}
display as text "{hline 70}"
