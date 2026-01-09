/*******************************************************************************
* test_eplot.do
* Functional tests for eplot command
*
* Author: Timothy Copeland
* Date: 2026-01-09
*******************************************************************************/

clear all
set more off
version 16.0

// Set up test environment
local test_dir "`c(pwd)'"

// Add eplot directory to adopath so Stata can find the command
adopath ++ "`test_dir'/eplot"

capture log close _all
log using "`test_dir'/_testing/test_eplot.log", replace text name(test_eplot)

display _n "{hline 70}"
display "EPLOT FUNCTIONAL TESTS"
display "Date: `c(current_date)' `c(current_time)'"
display "{hline 70}" _n

local n_tests 0
local n_passed 0
local n_failed 0

// =============================================================================
// TEST 1: Basic data mode - simple forest plot
// =============================================================================
display _n "{bf:TEST 1: Basic data mode - simple forest plot}"
local ++n_tests

capture {
    clear
    input str20 study double(es lci uci)
    "Smith 2020"    -0.16  -0.36  0.03
    "Jones 2021"    -0.33  -0.54 -0.12
    "Brown 2022"    -0.09  -0.25  0.06
    "Wilson 2023"   -0.39  -0.65 -0.12
    end

    eplot es lci uci, labels(study) name(test1, replace)

    // Check return values
    assert r(N) == 4
}

if _rc == 0 {
    display as result "  PASSED"
    local ++n_passed
}
else {
    display as error "  FAILED (error code: `=_rc')"
    local ++n_failed
}
capture noisily graph drop test1

// =============================================================================
// TEST 2: Data mode with weights
// =============================================================================
display _n "{bf:TEST 2: Data mode with weights}"
local ++n_tests

capture {
    clear
    input str20 study double(es lci uci weight)
    "Smith 2020"    -0.16  -0.36  0.03  15.2
    "Jones 2021"    -0.33  -0.54 -0.12  18.4
    "Brown 2022"    -0.09  -0.25  0.06  22.1
    "Wilson 2023"   -0.39  -0.65 -0.12  12.8
    end

    eplot es lci uci, labels(study) weights(weight) name(test2, replace)

    assert r(N) == 4
}

if _rc == 0 {
    display as result "  PASSED"
    local ++n_passed
}
else {
    display as error "  FAILED (error code: `=_rc')"
    local ++n_failed
}
capture noisily graph drop test2

// =============================================================================
// TEST 3: Data mode with type variable (pooled effect as diamond)
// =============================================================================
display _n "{bf:TEST 3: Data mode with type variable}"
local ++n_tests

capture {
    clear
    input str20 study double(es lci uci weight) byte type
    "Smith 2020"    -0.16  -0.36  0.03  15.2  1
    "Jones 2021"    -0.33  -0.54 -0.12  18.4  1
    "Brown 2022"    -0.09  -0.25  0.06  22.1  1
    "Wilson 2023"   -0.39  -0.65 -0.12  12.8  1
    "Overall"       -0.24  -0.34 -0.13  .     5
    end

    eplot es lci uci, labels(study) weights(weight) type(type) name(test3, replace)

    assert r(N) == 5
}

if _rc == 0 {
    display as result "  PASSED"
    local ++n_passed
}
else {
    display as error "  FAILED (error code: `=_rc')"
    local ++n_failed
}
capture noisily graph drop test3

// =============================================================================
// TEST 4: Data mode with eform transformation
// =============================================================================
display _n "{bf:TEST 4: Data mode with eform (odds ratios)}"
local ++n_tests

capture {
    clear
    input str20 study double(log_or log_lci log_uci)
    "Study A"   -0.22  -0.51  0.07
    "Study B"    0.15  -0.12  0.42
    "Study C"   -0.35  -0.68 -0.02
    end

    eplot log_or log_lci log_uci, labels(study) eform ///
        effect("Odds Ratio") name(test4, replace)

    assert r(N) == 3
}

if _rc == 0 {
    display as result "  PASSED"
    local ++n_passed
}
else {
    display as error "  FAILED (error code: `=_rc')"
    local ++n_failed
}
capture noisily graph drop test4

// =============================================================================
// TEST 5: Data mode with custom coefficient labels
// =============================================================================
display _n "{bf:TEST 5: Data mode with coeflabels}"
local ++n_tests

capture {
    clear
    input str10 coef double(es lci uci)
    "age"      0.15  0.08  0.22
    "gender"  -0.33 -0.52 -0.14
    "bmi"      0.05 -0.02  0.12
    end

    eplot es lci uci, labels(coef) ///
        coeflabels(age = "Age (years)" gender = "Female vs Male" bmi = "Body Mass Index") ///
        name(test5, replace)

    assert r(N) == 3
}

if _rc == 0 {
    display as result "  PASSED"
    local ++n_passed
}
else {
    display as error "  FAILED (error code: `=_rc')"
    local ++n_failed
}
capture noisily graph drop test5

// =============================================================================
// TEST 6: Data mode with xline reference
// =============================================================================
display _n "{bf:TEST 6: Data mode with xline reference}"
local ++n_tests

capture {
    clear
    input str20 study double(es lci uci)
    "Study 1"    1.5   1.1   2.0
    "Study 2"    0.8   0.5   1.3
    "Study 3"    1.2   0.9   1.6
    end

    eplot es lci uci, labels(study) xline(1) nonull name(test6, replace)

    assert r(N) == 3
}

if _rc == 0 {
    display as result "  PASSED"
    local ++n_passed
}
else {
    display as error "  FAILED (error code: `=_rc')"
    local ++n_failed
}
capture noisily graph drop test6

// =============================================================================
// TEST 7: Data mode vertical layout
// =============================================================================
display _n "{bf:TEST 7: Data mode vertical layout}"
local ++n_tests

capture {
    clear
    input str10 var double(es lci uci)
    "Var1"   0.5   0.2   0.8
    "Var2"  -0.3  -0.6   0.0
    "Var3"   0.1  -0.2   0.4
    end

    eplot es lci uci, labels(var) vertical name(test7, replace)

    assert r(N) == 3
}

if _rc == 0 {
    display as result "  PASSED"
    local ++n_passed
}
else {
    display as error "  FAILED (error code: `=_rc')"
    local ++n_failed
}
capture noisily graph drop test7

// =============================================================================
// TEST 8: Estimates mode - basic regression
// =============================================================================
display _n "{bf:TEST 8: Estimates mode - basic regression}"
local ++n_tests

capture {
    sysuse auto, clear
    quietly regress price mpg weight

    eplot ., name(test8, replace)

    assert r(N) > 0
}

if _rc == 0 {
    display as result "  PASSED"
    local ++n_passed
}
else {
    display as error "  FAILED (error code: `=_rc')"
    local ++n_failed
}
capture noisily graph drop test8

// =============================================================================
// TEST 9: Estimates mode with drop
// =============================================================================
display _n "{bf:TEST 9: Estimates mode with drop(_cons)}"
local ++n_tests

capture {
    sysuse auto, clear
    quietly regress price mpg weight length

    eplot ., drop(_cons) name(test9, replace)

    // Should have 3 coefficients (mpg, weight, length)
    assert r(N) == 3
}

if _rc == 0 {
    display as result "  PASSED"
    local ++n_passed
}
else {
    display as error "  FAILED (error code: `=_rc')"
    local ++n_failed
}
capture noisily graph drop test9

// =============================================================================
// TEST 10: Estimates mode with keep
// =============================================================================
display _n "{bf:TEST 10: Estimates mode with keep}"
local ++n_tests

capture {
    sysuse auto, clear
    quietly regress price mpg weight length foreign

    eplot ., keep(mpg weight) name(test10, replace)

    assert r(N) == 2
}

if _rc == 0 {
    display as result "  PASSED"
    local ++n_passed
}
else {
    display as error "  FAILED (error code: `=_rc')"
    local ++n_failed
}
capture noisily graph drop test10

// =============================================================================
// TEST 11: Estimates mode with custom labels
// =============================================================================
display _n "{bf:TEST 11: Estimates mode with coeflabels}"
local ++n_tests

capture {
    sysuse auto, clear
    quietly regress price mpg weight foreign

    eplot ., drop(_cons) ///
        coeflabels(mpg = "Miles per Gallon" weight = "Weight (lbs)" foreign = "Foreign Make") ///
        name(test11, replace)

    assert r(N) == 3
}

if _rc == 0 {
    display as result "  PASSED"
    local ++n_passed
}
else {
    display as error "  FAILED (error code: `=_rc')"
    local ++n_failed
}
capture noisily graph drop test11

// =============================================================================
// TEST 12: Estimates mode with eform (logistic)
// =============================================================================
display _n "{bf:TEST 12: Estimates mode with eform (logistic)}"
local ++n_tests

capture {
    sysuse auto, clear
    quietly logit foreign mpg weight

    eplot ., drop(_cons) eform effect("Odds Ratio") name(test12, replace)

    assert r(N) == 2
}

if _rc == 0 {
    display as result "  PASSED"
    local ++n_passed
}
else {
    display as error "  FAILED (error code: `=_rc')"
    local ++n_failed
}
capture noisily graph drop test12

// =============================================================================
// TEST 13: Data mode with groups
// =============================================================================
display _n "{bf:TEST 13: Data mode with groups}"
local ++n_tests

capture {
    clear
    input str10 var double(es lci uci)
    "age"       0.15  0.08  0.22
    "gender"   -0.33 -0.52 -0.14
    "bp"        0.08  0.01  0.15
    "chol"      0.12  0.05  0.19
    end

    eplot es lci uci, labels(var) ///
        groups(age gender = "Demographics" bp chol = "Clinical") ///
        name(test13, replace)
}

if _rc == 0 {
    display as result "  PASSED"
    local ++n_passed
}
else {
    display as error "  FAILED (error code: `=_rc')"
    local ++n_failed
}
capture graph drop test13

// =============================================================================
// TEST 14: Data mode with headers
// =============================================================================
display _n "{bf:TEST 14: Data mode with headers}"
local ++n_tests

capture {
    clear
    input str10 var double(es lci uci)
    "age"       0.15  0.08  0.22
    "gender"   -0.33 -0.52 -0.14
    "bp"        0.08  0.01  0.15
    end

    eplot es lci uci, labels(var) ///
        headers(age = "Patient Info" bp = "Vitals") ///
        name(test14, replace)
}

if _rc == 0 {
    display as result "  PASSED"
    local ++n_passed
}
else {
    display as error "  FAILED (error code: `=_rc')"
    local ++n_failed
}
capture graph drop test14

// =============================================================================
// TEST 15: Data mode with title and subtitle
// =============================================================================
display _n "{bf:TEST 15: Data mode with titles}"
local ++n_tests

capture {
    clear
    input str20 study double(es lci uci)
    "Study A"   0.5   0.2   0.8
    "Study B"  -0.3  -0.6   0.0
    end

    eplot es lci uci, labels(study) ///
        title("Main Title") subtitle("Subtitle") ///
        note("Note: Test data") ///
        name(test15, replace)

    assert r(N) == 2
}

if _rc == 0 {
    display as result "  PASSED"
    local ++n_passed
}
else {
    display as error "  FAILED (error code: `=_rc')"
    local ++n_failed
}
capture noisily graph drop test15

// =============================================================================
// TEST 16: Error handling - empty data
// =============================================================================
display _n "{bf:TEST 16: Error handling - empty data after if}"
local ++n_tests

capture {
    clear
    input str10 study double(es lci uci)
    "Study A"   0.5   0.2   0.8
    end

    // This should fail with "no observations"
    eplot es lci uci if study == "NonExistent", labels(study)
}

if _rc == 2000 {
    display as result "  PASSED (correctly caught no observations error)"
    local ++n_passed
}
else if _rc == 0 {
    display as error "  FAILED (should have errored on empty data)"
    local ++n_failed
}
else {
    display as error "  FAILED (unexpected error code: `=_rc')"
    local ++n_failed
}

// =============================================================================
// TEST 17: With if/in conditions
// =============================================================================
display _n "{bf:TEST 17: Data mode with if condition}"
local ++n_tests

capture {
    clear
    input str20 study double(es lci uci) byte include
    "Study A"   0.5   0.2   0.8  1
    "Study B"  -0.3  -0.6   0.0  1
    "Study C"   0.1  -0.2   0.4  0
    end

    eplot es lci uci if include == 1, labels(study) name(test17, replace)

    assert r(N) == 2
}

if _rc == 0 {
    display as result "  PASSED"
    local ++n_passed
}
else {
    display as error "  FAILED (error code: `=_rc')"
    local ++n_failed
}
capture noisily graph drop test17

// =============================================================================
// TEST 18: Rescale option
// =============================================================================
display _n "{bf:TEST 18: Rescale option}"
local ++n_tests

capture {
    clear
    input str10 var double(es lci uci)
    "var1"   0.05   0.02   0.08
    "var2"  -0.03  -0.06   0.00
    end

    // Rescale by 100 (e.g., for percentage points)
    eplot es lci uci, labels(var) rescale(100) name(test18, replace)

    assert r(N) == 2
}

if _rc == 0 {
    display as result "  PASSED"
    local ++n_passed
}
else {
    display as error "  FAILED (error code: `=_rc')"
    local ++n_failed
}
capture noisily graph drop test18

// =============================================================================
// TEST 19: No CI option
// =============================================================================
display _n "{bf:TEST 19: No CI option}"
local ++n_tests

capture {
    clear
    input str10 var double(es lci uci)
    "var1"   0.5   0.2   0.8
    "var2"  -0.3  -0.6   0.0
    end

    eplot es lci uci, labels(var) noci name(test19, replace)

    assert r(N) == 2
}

if _rc == 0 {
    display as result "  PASSED"
    local ++n_passed
}
else {
    display as error "  FAILED (error code: `=_rc')"
    local ++n_failed
}
capture noisily graph drop test19

// =============================================================================
// TEST 20: Subgroup and overall diamonds
// =============================================================================
display _n "{bf:TEST 20: Mixed types with diamonds}"
local ++n_tests

capture {
    clear
    input str20 study double(es lci uci) byte type
    "Group A Header"     .      .      .    0
    "Study A1"        0.5    0.2    0.8    1
    "Study A2"       -0.1   -0.4    0.2    1
    "Subgroup A"      0.2   -0.1    0.5    3
    "Group B Header"     .      .      .    0
    "Study B1"        0.3    0.0    0.6    1
    "Subgroup B"      0.3    0.0    0.6    3
    "Overall"         0.25   0.05   0.45   5
    end

    eplot es lci uci, labels(study) type(type) name(test20, replace)
}

if _rc == 0 {
    display as result "  PASSED"
    local ++n_passed
}
else {
    display as error "  FAILED (error code: `=_rc')"
    local ++n_failed
}
capture graph drop test20

// =============================================================================
// SUMMARY
// =============================================================================
display _n "{hline 70}"
display "{bf:TEST SUMMARY}"
display "{hline 70}"
display "Total tests:  `n_tests'"
display as result "Passed:       `n_passed'"
if `n_failed' > 0 {
    display as error "Failed:       `n_failed'"
}
else {
    display "Failed:       `n_failed'"
}
display "{hline 70}"

if `n_failed' > 0 {
    display as error _n "SOME TESTS FAILED!"
    exit 1
}
else {
    display as result _n "ALL TESTS PASSED!"
}

log close test_eplot

// End of test_eplot.do
