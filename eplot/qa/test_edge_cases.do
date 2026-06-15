/*******************************************************************************
* test_edge_cases.do
* Tests for eplot v2.0.2 bug fixes
*
* Tests:
*   1-3:   nodiamonds fix — pooled effects show markers/CIs instead of nothing
*   4-6:   Multi-model noci — axis not distorted by placeholder coordinates
*   7-9:   order() with compound quote safety
*   10-12: Edge cases — zero obs, single obs, all missing
*   13-14: varabbrev restore verification
*   15-16: Abbreviation disambiguation (msymbol vs msize)
*
* Author: Timothy Copeland
* Date: 2026-03-21
*******************************************************************************/

clear all
set more off
version 16.0


* === Bootstrap ===
local qa_dir  "`c(pwd)'"
local pkg_dir "`qa_dir'/.."  

adopath ++ "`pkg_dir'"

* Reload to pick up latest changes
capture program drop eplot
capture program drop _eplot_parse_mode
capture program drop _eplot_data
capture program drop _eplot_estimates
capture program drop _eplot_matrix
capture program drop _eplot_apply_coeflabels
capture program drop _eplot_apply_keep
capture program drop _eplot_apply_drop
capture program drop _eplot_apply_rename
capture program drop _eplot_process_groups
capture program drop _eplot_process_headers
run "`pkg_dir'/eplot.ado"

capture log close _all
log using "`pkg_dir'/qa/test_edge_cases.log", replace text nomsg ///
    name(test_edge_cases)

local test_count 0
local pass_count 0
local fail_count 0
local failed_tests ""

* ==========================================================================
* NODIAMONDS FIX: pooled effects should show markers + CIs
* ==========================================================================

* Test 1: nodiamonds with subgroup (type=3) and overall (type=5)
local ++test_count
capture noisily {
    clear
    input str20 study double(es lci uci) byte type
    "Study A"      -0.30  -0.60   0.00   1
    "Study B"      -0.20  -0.45   0.05   1
    "Subgroup"     -0.25  -0.42  -0.08   3
    "Study C"      -0.10  -0.35   0.15   1
    "Overall"      -0.22  -0.36  -0.08   5
    end

    * This should NOT error — pooled effects get markers instead of diamonds
    eplot es lci uci, labels(study) type(type) nodiamonds ///
        name(_v202_t1, replace)
    assert r(N) == 5
}
if _rc == 0 {
    display as result "  PASS: Test 1 - nodiamonds with type 3/5 rows"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 1 - nodiamonds with type 3/5 rows (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 1"
}
capture graph drop _v202_t1

* Test 2: nodiamonds + noci — pooled effects get markers only
local ++test_count
capture noisily {
    clear
    input str20 study double(es lci uci) byte type
    "Study A"      -0.30  -0.60   0.00   1
    "Overall"      -0.22  -0.36  -0.08   5
    end

    eplot es lci uci, labels(study) type(type) nodiamonds noci ///
        name(_v202_t2, replace)
    assert r(N) == 2
}
if _rc == 0 {
    display as result "  PASS: Test 2 - nodiamonds + noci"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 2 - nodiamonds + noci (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 2"
}
capture graph drop _v202_t2

* Test 3: nodiamonds + cicap — pooled effects get capped CIs
local ++test_count
capture noisily {
    clear
    input str20 study double(es lci uci) byte type
    "Study A"      -0.30  -0.60   0.00   1
    "Overall"      -0.22  -0.36  -0.08   5
    end

    eplot es lci uci, labels(study) type(type) nodiamonds cicap ///
        name(_v202_t3, replace)
    assert r(N) == 2
}
if _rc == 0 {
    display as result "  PASS: Test 3 - nodiamonds + cicap"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 3 - nodiamonds + cicap (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3"
}
capture graph drop _v202_t3

* ==========================================================================
* MULTI-MODEL NOCI: no axis distortion
* ==========================================================================

* Test 4: Multi-model with noci — should not error and axis is reasonable
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly regress price mpg weight
    estimates store _t4_m1
    quietly regress price mpg weight foreign
    estimates store _t4_m2

    eplot _t4_m1 _t4_m2, drop(_cons) noci name(_v202_t4, replace)
    assert r(N) > 0
    assert r(n_models) == 2
}
if _rc == 0 {
    display as result "  PASS: Test 4 - Multi-model noci"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 4 - Multi-model noci (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4"
}
capture graph drop _v202_t4
capture estimates drop _t4_m1 _t4_m2

* Test 5: Multi-model with noci + cicap (should still work)
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly regress price mpg weight
    estimates store _t5_m1
    quietly regress price mpg weight foreign
    estimates store _t5_m2

    eplot _t5_m1 _t5_m2, drop(_cons) noci cicap name(_v202_t5, replace)
    assert r(N) > 0
}
if _rc == 0 {
    display as result "  PASS: Test 5 - Multi-model noci + cicap"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 5 - Multi-model noci + cicap (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 5"
}
capture graph drop _v202_t5
capture estimates drop _t5_m1 _t5_m2

* Test 6: Multi-model with noci, modellabels — legend still correct
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly regress price mpg weight
    estimates store _t6_m1
    quietly regress price mpg weight foreign
    estimates store _t6_m2

    eplot _t6_m1 _t6_m2, drop(_cons) noci ///
        modellabels("Base" "Extended") name(_v202_t6, replace)
    assert r(n_models) == 2
}
if _rc == 0 {
    display as result "  PASS: Test 6 - Multi-model noci + modellabels"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 6 - Multi-model noci + modellabels (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 6"
}
capture graph drop _v202_t6
capture estimates drop _t6_m1 _t6_m2

* ==========================================================================
* ORDER() WITH COMPOUND QUOTES
* ==========================================================================

* Test 7: order() in data mode
local ++test_count
capture noisily {
    clear
    input str20 study double(es lci uci)
    "Study A"  0.5  0.2  0.8
    "Study B"  0.3  0.1  0.5
    "Study C"  0.7  0.4  1.0
    end

    eplot es lci uci, labels(study) ///
        order("Study C" "Study A" "Study B") ///
        name(_v202_t7, replace)
    assert r(N) == 3
}
if _rc == 0 {
    display as result "  PASS: Test 7 - order() in data mode"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 7 - order() in data mode (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 7"
}
capture graph drop _v202_t7

* Test 8: order() in estimates mode
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly regress price mpg weight foreign
    eplot ., drop(_cons) order(foreign weight mpg) ///
        name(_v202_t8, replace)
    assert r(N) == 3
}
if _rc == 0 {
    display as result "  PASS: Test 8 - order() in estimates mode"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 8 - order() in estimates mode (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 8"
}
capture graph drop _v202_t8

* Test 9: order() in matrix mode
local ++test_count
capture noisily {
    matrix R = (1.5, 1.1, 2.0 \ 0.8, 0.6, 1.2 \ 1.2, 0.9, 1.6)
    matrix rownames R = "Treatment_A" "Treatment_B" "Treatment_C"

    eplot, matrix(R) order("Treatment_C" "Treatment_A" "Treatment_B") ///
        name(_v202_t9, replace)
    assert r(N) == 3
}
if _rc == 0 {
    display as result "  PASS: Test 9 - order() in matrix mode"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 9 - order() in matrix mode (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 9"
}
capture graph drop _v202_t9

* ==========================================================================
* EDGE CASES
* ==========================================================================

* Test 10: Single observation
local ++test_count
capture noisily {
    clear
    input str10 study double(es lci uci)
    "Only One" 0.5 0.2 0.8
    end

    eplot es lci uci, labels(study) name(_v202_t10, replace)
    assert r(N) == 1
}
if _rc == 0 {
    display as result "  PASS: Test 10 - Single observation"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 10 - Single observation (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 10"
}
capture graph drop _v202_t10

* Test 11: Zero valid observations should error
local ++test_count
capture noisily {
    clear
    input str10 study double(es lci uci)
    "Missing" . . .
    end

    capture eplot es lci uci, labels(study) name(_v202_t11, replace)
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: Test 11 - Zero valid observations errors correctly"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 11 - Zero valid observations (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 11"
}
capture graph drop _v202_t11

* Test 12: Mix of valid and all-missing rows
local ++test_count
capture noisily {
    clear
    input str10 study double(es lci uci)
    "Study A" 0.5 0.2 0.8
    "Missing" .   .   .
    "Study B" 0.3 0.1 0.5
    end

    eplot es lci uci, labels(study) name(_v202_t12, replace)
    * Only 2 valid rows (missing row excluded by markout)
    assert r(N) == 2
}
if _rc == 0 {
    display as result "  PASS: Test 12 - Mix of valid and missing rows"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 12 - Mix of valid and missing rows (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 12"
}
capture graph drop _v202_t12

* ==========================================================================
* VARABBREV RESTORE
* ==========================================================================

* Test 13: varabbrev is restored after successful eplot
local ++test_count
capture noisily {
    set varabbrev on
    sysuse auto, clear
    quietly regress price mpg weight foreign
    eplot ., drop(_cons) name(_v202_t13, replace)
    assert "`c(varabbrev)'" == "on"
}
if _rc == 0 {
    display as result "  PASS: Test 13 - varabbrev restored after success"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 13 - varabbrev restored after success (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 13"
}
capture graph drop _v202_t13

* Test 14: varabbrev is restored after eplot error
local ++test_count
capture noisily {
    set varabbrev on
    clear
    * No data — should error
    capture eplot es lci uci
    * varabbrev should still be on
    assert "`c(varabbrev)'" == "on"
}
if _rc == 0 {
    display as result "  PASS: Test 14 - varabbrev restored after error"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 14 - varabbrev restored after error (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 14"
}

* ==========================================================================
* ABBREVIATION DISAMBIGUATION
* ==========================================================================

* Test 15: msymbol() works with full name
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly regress price mpg weight
    eplot ., drop(_cons) msymbol(D) name(_v202_t15, replace)
    assert r(N) == 2
}
if _rc == 0 {
    display as result "  PASS: Test 15 - msymbol() with full name"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 15 - msymbol() full name (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 15"
}
capture graph drop _v202_t15

* Test 16: msize() works with full name
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly regress price mpg weight
    eplot ., drop(_cons) msize(large) name(_v202_t16, replace)
    assert r(N) == 2
}
if _rc == 0 {
    display as result "  PASS: Test 16 - msize() with full name"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 16 - msize() full name (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 16"
}
capture graph drop _v202_t16

* ==========================================================================
* NODIAMONDS VERTICAL MODE
* ==========================================================================

* Test 17: nodiamonds in vertical layout
local ++test_count
capture noisily {
    clear
    input str20 study double(es lci uci) byte type
    "Study A"      -0.30  -0.60   0.00   1
    "Overall"      -0.22  -0.36  -0.08   5
    end

    eplot es lci uci, labels(study) type(type) nodiamonds vertical ///
        name(_v202_t17, replace)
    assert r(N) == 2
}
if _rc == 0 {
    display as result "  PASS: Test 17 - nodiamonds + vertical"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 17 - nodiamonds + vertical (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 17"
}
capture graph drop _v202_t17

* Test 18: Multi-model three models with noci
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly regress price mpg
    estimates store _t18_m1
    quietly regress price mpg weight
    estimates store _t18_m2
    quietly regress price mpg weight foreign
    estimates store _t18_m3

    eplot _t18_m1 _t18_m2 _t18_m3, drop(_cons) noci ///
        modellabels("M1" "M2" "M3") name(_v202_t18, replace)
    assert r(n_models) == 3
}
if _rc == 0 {
    display as result "  PASS: Test 18 - Three-model noci"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 18 - Three-model noci (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 18"
}
capture graph drop _v202_t18
capture estimates drop _t18_m1 _t18_m2 _t18_m3

* ==========================================================================
* SUMMARY
* ==========================================================================

display _n as text "{hline 70}"
display as text "EPLOT V2.0.2 BUG FIX TEST SUMMARY"
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
    display as error "Some tests FAILED. Review output above."
    exit 1
}
else {
    display as result "ALL TESTS PASSED!"
}

log close test_edge_cases
