* test_tc_schemes.do
*
* Functional tests for tc_schemes command
* Tests scheme listing, filtering, file availability, and basic graph rendering
*
* Author: Timothy P Copeland
* Date: 2026-03-14

clear all
set more off
version 16.0

* =============================================================================
* SETUP
* =============================================================================
capture ado uninstall tc_schemes
quietly net install tc_schemes, from("~/Stata-Tools/tc_schemes") replace

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

* =============================================================================
* SECTION 1: Basic functionality
* =============================================================================

* Test 1: tc_schemes runs without error and returns r(n_schemes)
local ++test_count
display as text _n "Test `test_count': Basic run returns r(n_schemes)"

capture {
    tc_schemes
    assert r(n_schemes) > 0
    assert "`r(schemes)'" != ""
    assert "`r(sources)'" == "blindschemes schemepack"
}
if _rc == 0 {
    display as result "  PASSED (n_schemes = `r(n_schemes)')"
    local ++pass_count
}
else {
    display as error "  FAILED (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* Test 2: source(blindschemes) returns correct count
local ++test_count
display as text _n "Test `test_count': source(blindschemes) returns 4 schemes"

capture {
    tc_schemes, source(blindschemes)
    assert r(n_schemes) == 4
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

* Test 3: source(schemepack) returns correct count
local ++test_count
display as text _n "Test `test_count': source(schemepack) returns >30 schemes"

capture {
    tc_schemes, source(schemepack)
    assert r(n_schemes) > 30
}
if _rc == 0 {
    display as result "  PASSED (n_schemes = `r(n_schemes)')"
    local ++pass_count
}
else {
    display as error "  FAILED (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* Test 4: Invalid source triggers error 198
local ++test_count
display as text _n "Test `test_count': Invalid source triggers error"

capture tc_schemes, source(invalid)
if _rc == 198 {
    display as result "  PASSED (correctly rejected)"
    local ++pass_count
}
else {
    display as error "  FAILED (expected rc=198, got `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* =============================================================================
* SECTION 2: Display options
* =============================================================================

* Test 5: list option works
local ++test_count
display as text _n "Test `test_count': list option displays without error"

capture {
    tc_schemes, list
    assert r(n_schemes) > 0
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

* Test 6: detail option works
local ++test_count
display as text _n "Test `test_count': detail option displays without error"

capture {
    tc_schemes, detail
    assert r(n_schemes) > 0
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
* SECTION 3: File availability
* =============================================================================

* Test 7: All blindschemes .scheme files findable
local ++test_count
display as text _n "Test `test_count': blindschemes .scheme files findable"

capture {
    local schemes "plotplain plotplainblind plottig plottigblind"
    foreach s of local schemes {
        capture findfile scheme-`s'.scheme
        if _rc {
            display as error "  Cannot find scheme-`s'.scheme"
            exit 601
        }
    }
}
if _rc == 0 {
    display as result "  PASSED (all 4 scheme files found)"
    local ++pass_count
}
else {
    display as error "  FAILED (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* Test 8: Sample schemepack .scheme files findable
local ++test_count
display as text _n "Test `test_count': Sample schemepack .scheme files findable"

capture {
    local schemes "white_tableau black_tableau gg_tableau tab1 cblind1"
    foreach s of local schemes {
        capture findfile scheme-`s'.scheme
        if _rc {
            display as error "  Cannot find scheme-`s'.scheme"
            exit 601
        }
    }
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
* SECTION 4: Graph rendering
* =============================================================================

* Test 9: Basic graph renders with plotplainblind
local ++test_count
display as text _n "Test `test_count': Graph renders with plotplainblind"

capture {
    sysuse auto, clear
    quietly graph twoway scatter price mpg, scheme(plotplainblind)
    graph drop _all
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

* Test 10: Basic graph renders with a schemepack scheme
local ++test_count
display as text _n "Test `test_count': Graph renders with white_tableau"

capture {
    sysuse auto, clear
    quietly graph twoway scatter price mpg, scheme(white_tableau)
    graph drop _all
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
display as text "TC_SCHEMES FUNCTIONAL TEST SUMMARY"
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

display as text _n "Testing completed: `c(current_date)' `c(current_time)'"
