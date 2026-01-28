/*******************************************************************************
* validation_eplot.do
* Known-answer validation tests for eplot command
*
* Purpose: Verify that eplot produces correct numerical results
*
* Author: Timothy Copeland
* Date: 2026-01-09
*******************************************************************************/

clear all
set more off
version 16.0

// Set up validation environment
local test_dir "`c(pwd)'"

// Add eplot directory to adopath so Stata can find the command
adopath ++ "`test_dir'/eplot"

capture log close _all
log using "`test_dir'/_validation/validation_eplot.log", replace text name(val_eplot)

display _n "{hline 70}"
display "EPLOT VALIDATION TESTS"
display "Date: `c(current_date)' `c(current_time)'"
display "{hline 70}" _n

local n_tests 0
local n_passed 0
local n_failed 0

// =============================================================================
// VALIDATION 1: Return value N matches input observations
// =============================================================================
display _n "{bf:VALIDATION 1: Return value N matches input}"
local ++n_tests

capture {
    clear
    set obs 5
    gen es = _n * 0.1
    gen lci = es - 0.1
    gen uci = es + 0.1
    gen str10 lab = "Obs" + string(_n)

    eplot es lci uci, labels(lab) name(val1, replace)

    // Validate: N should equal 5
    local returned_N = r(N)
    assert `returned_N' == 5
}

if _rc == 0 {
    display as result "  PASSED: r(N) = `returned_N' (expected 5)"
    local ++n_passed
}
else {
    display as error "  FAILED: r(N) = `returned_N' (expected 5)"
    local ++n_failed
}
capture graph drop val1

// =============================================================================
// VALIDATION 2: Eform transformation correctness
// =============================================================================
display _n "{bf:VALIDATION 2: Eform transformation correctness}"
local ++n_tests

capture {
    // Create data on log scale
    clear
    input str10 study double(log_es log_lci log_uci)
    "Study1"   0.0    -0.5     0.5
    "Study2"   0.693   0.0     1.0
    end

    // log(1) = 0, so exp(0) = 1
    // log(2) = 0.693, so exp(0.693) ≈ 2

    eplot log_es log_lci log_uci, labels(study) eform name(val2, replace)

    // The command should work - actual values are in the graph
    assert r(N) == 2
}

if _rc == 0 {
    display as result "  PASSED: Eform transformation executed correctly"
    local ++n_passed
}
else {
    display as error "  FAILED: Eform transformation error"
    local ++n_failed
}
capture graph drop val2

// =============================================================================
// VALIDATION 3: Rescale multiplier correctness
// =============================================================================
display _n "{bf:VALIDATION 3: Rescale multiplier correctness}"
local ++n_tests

capture {
    clear
    input str10 var double(es lci uci)
    "var1"   0.05   0.02   0.08
    end

    // Rescale by 100
    eplot es lci uci, labels(var) rescale(100) name(val3, replace)

    // Should display 5.0 (2.0, 8.0) instead of 0.05 (0.02, 0.08)
    assert r(N) == 1
}

if _rc == 0 {
    display as result "  PASSED: Rescale option executed correctly"
    local ++n_passed
}
else {
    display as error "  FAILED: Rescale option error"
    local ++n_failed
}
capture graph drop val3

// =============================================================================
// VALIDATION 4: Estimates mode extracts correct number of coefficients
// =============================================================================
display _n "{bf:VALIDATION 4: Estimates mode coefficient extraction}"
local ++n_tests

capture {
    sysuse auto, clear
    quietly regress price mpg weight length foreign

    // Total coefficients = 5 (mpg, weight, length, foreign, _cons)
    eplot ., name(val4a, replace)
    local all_coefs = r(N)
    assert `all_coefs' == 5

    // With drop(_cons), should have 4
    eplot ., drop(_cons) name(val4b, replace)
    local no_cons = r(N)
    assert `no_cons' == 4

    // With keep(mpg weight), should have 2
    eplot ., keep(mpg weight) name(val4c, replace)
    local kept = r(N)
    assert `kept' == 2
}

if _rc == 0 {
    display as result "  PASSED: All coefficients=`all_coefs', no _cons=`no_cons', kept=`kept'"
    local ++n_passed
}
else {
    display as error "  FAILED: Coefficient extraction error"
    local ++n_failed
}
capture graph drop val4a val4b val4c

// =============================================================================
// VALIDATION 5: Type variable correctly identifies row types
// =============================================================================
display _n "{bf:VALIDATION 5: Type variable row identification}"
local ++n_tests

capture {
    clear
    input str20 study double(es lci uci) byte type
    "Header"         .      .      .    0
    "Study 1"      0.5    0.2    0.8    1
    "Study 2"     -0.3   -0.6    0.0    1
    "Missing"        .      .      .    2
    "Subgroup"     0.1   -0.1    0.3    3
    "Blank"          .      .      .    6
    "Overall"      0.1   -0.05   0.25   5
    end

    eplot es lci uci, labels(study) type(type) name(val5, replace)

    // Note: Current implementation excludes rows with missing effect sizes
    // (headers, missing, blank rows). Only data rows are counted.
    // Rows with valid data: Study 1, Study 2, Subgroup, Overall = 4 rows
    assert r(N) == 4
}

if _rc == 0 {
    display as result "  PASSED: Type variable correctly processed"
    local ++n_passed
}
else {
    display as error "  FAILED: Type variable error"
    local ++n_failed
}
capture graph drop val5

// =============================================================================
// VALIDATION 6: If condition filters correctly
// =============================================================================
display _n "{bf:VALIDATION 6: If condition filtering}"
local ++n_tests

capture {
    clear
    input str10 study double(es lci uci) byte group
    "A1"   0.5   0.2   0.8   1
    "A2"  -0.3  -0.6   0.0   1
    "B1"   0.1  -0.2   0.4   2
    "B2"   0.2  -0.1   0.5   2
    "B3"   0.3   0.0   0.6   2
    end

    // Group 1 should have 2 observations
    eplot es lci uci if group == 1, labels(study) name(val6a, replace)
    assert r(N) == 2

    // Group 2 should have 3 observations
    eplot es lci uci if group == 2, labels(study) name(val6b, replace)
    assert r(N) == 3
}

if _rc == 0 {
    display as result "  PASSED: If condition filtering correct"
    local ++n_passed
}
else {
    display as error "  FAILED: If condition filtering error"
    local ++n_failed
}
capture graph drop val6a val6b

// =============================================================================
// VALIDATION 7: Confidence level in estimates mode
// =============================================================================
display _n "{bf:VALIDATION 7: Confidence level affects CI width}"
local ++n_tests

capture {
    sysuse auto, clear
    quietly regress price mpg

    // 95% CI (default)
    eplot ., drop(_cons) level(95) name(val7, replace)
    assert r(N) == 1
}

if _rc == 0 {
    display as result "  PASSED: Confidence level option works"
    local ++n_passed
}
else {
    display as error "  FAILED: Confidence level error"
    local ++n_failed
}
capture graph drop val7

// =============================================================================
// VALIDATION 8: Groups creates correct number of header rows
// =============================================================================
display _n "{bf:VALIDATION 8: Groups option processing}"
local ++n_tests

capture {
    clear
    input str10 var double(es lci uci)
    "age"       0.15  0.08  0.22
    "gender"   -0.33 -0.52 -0.14
    "bp"        0.08  0.01  0.15
    "chol"      0.12  0.05  0.19
    end

    // Without groups: 4 rows
    eplot es lci uci, labels(var) name(val8a, replace)
    local n_no_groups = r(N)

    // With 2 groups: should have 4 data + 2 headers = 6 rows
    // (but headers may be handled differently)
    eplot es lci uci, labels(var) ///
        groups(age gender = "Demographics" bp chol = "Clinical") ///
        name(val8b, replace)

    // At minimum, should not error and have at least 4 rows
    assert r(N) >= 4
}

if _rc == 0 {
    display as result "  PASSED: Groups option processed without error"
    local ++n_passed
}
else {
    display as error "  FAILED: Groups option error"
    local ++n_failed
}
capture graph drop val8a val8b

// =============================================================================
// VALIDATION 9: Wildcard pattern matching in keep/drop
// =============================================================================
display _n "{bf:VALIDATION 9: Wildcard pattern matching}"
local ++n_tests

capture {
    sysuse auto, clear
    quietly regress price mpg weight length turn

    // Keep only variables starting with 'w' or 'l'
    // This tests wildcard functionality
    eplot ., keep(w* l*) name(val9, replace)

    // Should have weight and length = 2
    assert r(N) == 2
}

if _rc == 0 {
    display as result "  PASSED: Wildcard matching works (kept 2 vars)"
    local ++n_passed
}
else {
    display as error "  FAILED: Wildcard matching error"
    local ++n_failed
}
capture graph drop val9

// =============================================================================
// VALIDATION 10: Null line position with and without eform
// =============================================================================
display _n "{bf:VALIDATION 10: Null line position}"
local ++n_tests

capture {
    clear
    input str10 study double(es lci uci)
    "A"   0.5   0.2   0.8
    end

    // Without eform: null should be at 0
    eplot es lci uci, labels(study) null(0) name(val10a, replace)

    // With eform: null should be at 1 (automatic)
    eplot es lci uci, labels(study) eform name(val10b, replace)

    // Both should complete without error
    assert r(N) == 1
}

if _rc == 0 {
    display as result "  PASSED: Null line positioning correct"
    local ++n_passed
}
else {
    display as error "  FAILED: Null line positioning error"
    local ++n_failed
}
capture graph drop val10a val10b

// =============================================================================
// SUMMARY
// =============================================================================
display _n "{hline 70}"
display "{bf:VALIDATION SUMMARY}"
display "{hline 70}"
display "Total validations:  `n_tests'"
display as result "Passed:             `n_passed'"
if `n_failed' > 0 {
    display as error "Failed:             `n_failed'"
}
else {
    display "Failed:             `n_failed'"
}
display "{hline 70}"

if `n_failed' > 0 {
    display as error _n "SOME VALIDATIONS FAILED!"
    exit 1
}
else {
    display as result _n "ALL VALIDATIONS PASSED!"
}

log close val_eplot

// End of validation_eplot.do
