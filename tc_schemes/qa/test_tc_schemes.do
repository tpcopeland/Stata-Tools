* test_tc_schemes.do
*
* Functional tests for tc_schemes command
* Tests scheme listing, filtering, file availability, graph rendering,
* varabbrev restore, option abbreviations, error handling, and return values
*
* Author: Timothy P Copeland
* Date: 2026-03-21

clear all
set more off
version 16.0

* =============================================================================
* SETUP
* =============================================================================

* === Bootstrap ===
local qa_dir  "`c(pwd)'"
local pkg_dir "`qa_dir'/.."  

capture ado uninstall tc_schemes
quietly net install tc_schemes, from("`pkg_dir'") replace

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

* =============================================================================
* SECTION 1: Basic functionality
* =============================================================================

* Test 1: tc_schemes runs without error and returns all r() values
local ++test_count
display as text _n "Test `test_count': Basic run returns all r() values"

capture noisily {
    tc_schemes
    assert r(n_schemes) > 0
    assert "`r(schemes)'" != ""
    assert "`r(sources)'" == "blindschemes schemepack"
    assert "`r(version)'" == "1.0.0"
}
if _rc == 0 {
    display as result "  PASS"
    local ++pass_count
}
else {
    display as error "  FAIL (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* Test 2: source(blindschemes) returns correct count and sources
local ++test_count
display as text _n "Test `test_count': source(blindschemes) returns 4 schemes"

capture noisily {
    tc_schemes, source(blindschemes)
    assert r(n_schemes) == 4
    assert "`r(sources)'" == "blindschemes"
}
if _rc == 0 {
    display as result "  PASS"
    local ++pass_count
}
else {
    display as error "  FAIL (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* Test 3: source(schemepack) returns correct count and sources
local ++test_count
display as text _n "Test `test_count': source(schemepack) returns 35 schemes"

capture noisily {
    tc_schemes, source(schemepack)
    assert r(n_schemes) == 35
    assert "`r(sources)'" == "schemepack"
}
if _rc == 0 {
    display as result "  PASS"
    local ++pass_count
}
else {
    display as error "  FAIL (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* Test 4: Total scheme count is 39 (4 + 35)
local ++test_count
display as text _n "Test `test_count': Total scheme count is 39"

capture noisily {
    tc_schemes
    assert r(n_schemes) == 39
}
if _rc == 0 {
    display as result "  PASS"
    local ++pass_count
}
else {
    display as error "  FAIL (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* =============================================================================
* SECTION 2: Display options
* =============================================================================

* Test 5: list option works
local ++test_count
display as text _n "Test `test_count': list option displays without error"

capture noisily {
    tc_schemes, list
    assert r(n_schemes) == 39
}
if _rc == 0 {
    display as result "  PASS"
    local ++pass_count
}
else {
    display as error "  FAIL (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* Test 6: detail option works
local ++test_count
display as text _n "Test `test_count': detail option displays without error"

capture noisily {
    tc_schemes, detail
    assert r(n_schemes) == 39
}
if _rc == 0 {
    display as result "  PASS"
    local ++pass_count
}
else {
    display as error "  FAIL (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* Test 7: source + list combination
local ++test_count
display as text _n "Test `test_count': source(schemepack) list combination"

capture noisily {
    tc_schemes, source(schemepack) list
    assert r(n_schemes) == 35
    assert "`r(sources)'" == "schemepack"
}
if _rc == 0 {
    display as result "  PASS"
    local ++pass_count
}
else {
    display as error "  FAIL (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* Test 8: source + detail combination
local ++test_count
display as text _n "Test `test_count': source(blindschemes) detail combination"

capture noisily {
    tc_schemes, source(blindschemes) detail
    assert r(n_schemes) == 4
    assert "`r(sources)'" == "blindschemes"
}
if _rc == 0 {
    display as result "  PASS"
    local ++pass_count
}
else {
    display as error "  FAIL (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* =============================================================================
* SECTION 3: Option abbreviations
* =============================================================================

* Test 9: Abbreviated source option (so)
local ++test_count
display as text _n "Test `test_count': Abbreviated option so() works"

capture noisily {
    tc_schemes, so(blindschemes)
    assert r(n_schemes) == 4
}
if _rc == 0 {
    display as result "  PASS"
    local ++pass_count
}
else {
    display as error "  FAIL (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* Test 10: Abbreviated list option (li)
local ++test_count
display as text _n "Test `test_count': Abbreviated option li works"

capture noisily {
    tc_schemes, li
    assert r(n_schemes) == 39
}
if _rc == 0 {
    display as result "  PASS"
    local ++pass_count
}
else {
    display as error "  FAIL (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* Test 11: Abbreviated detail option (de)
local ++test_count
display as text _n "Test `test_count': Abbreviated option de works"

capture noisily {
    tc_schemes, de
    assert r(n_schemes) == 39
}
if _rc == 0 {
    display as result "  PASS"
    local ++pass_count
}
else {
    display as error "  FAIL (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* =============================================================================
* SECTION 4: Error handling
* =============================================================================

* Test 12: Invalid source triggers error 198
local ++test_count
display as text _n "Test `test_count': Invalid source triggers error 198"

capture tc_schemes, source(invalid)
if _rc == 198 {
    display as result "  PASS"
    local ++pass_count
}
else {
    display as error "  FAIL (expected rc=198, got `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* Test 13: list + detail mutual exclusivity error 198
local ++test_count
display as text _n "Test `test_count': list + detail mutual exclusivity error 198"

capture tc_schemes, list detail
if _rc == 198 {
    display as result "  PASS"
    local ++pass_count
}
else {
    display as error "  FAIL (expected rc=198, got `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* Test 14: source case insensitivity (uppercase)
local ++test_count
display as text _n "Test `test_count': source is case insensitive (BLINDSCHEMES)"

capture noisily {
    tc_schemes, source(BLINDSCHEMES)
    assert r(n_schemes) == 4
}
if _rc == 0 {
    display as result "  PASS"
    local ++pass_count
}
else {
    display as error "  FAIL (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* Test 15: source case insensitivity (mixed case)
local ++test_count
display as text _n "Test `test_count': source is case insensitive (Schemepack)"

capture noisily {
    tc_schemes, source(Schemepack)
    assert r(n_schemes) == 35
}
if _rc == 0 {
    display as result "  PASS"
    local ++pass_count
}
else {
    display as error "  FAIL (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* =============================================================================
* SECTION 5: Varabbrev save/restore
* =============================================================================

* Test 16: varabbrev restored to ON after successful run
local ++test_count
display as text _n "Test `test_count': varabbrev restored to on after success"

capture noisily {
    set varabbrev on
    tc_schemes
    assert "`c(varabbrev)'" == "on"
}
if _rc == 0 {
    display as result "  PASS"
    local ++pass_count
}
else {
    display as error "  FAIL (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* Test 17: varabbrev restored to OFF after successful run
local ++test_count
display as text _n "Test `test_count': varabbrev restored to off after success"

capture noisily {
    set varabbrev off
    tc_schemes
    assert "`c(varabbrev)'" == "off"
}
if _rc == 0 {
    display as result "  PASS"
    local ++pass_count
}
else {
    display as error "  FAIL (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}
set varabbrev on

* Test 18: varabbrev restored to ON after error
local ++test_count
display as text _n "Test `test_count': varabbrev restored to on after error"

capture noisily {
    set varabbrev on
    capture tc_schemes, source(invalid)
    assert "`c(varabbrev)'" == "on"
}
if _rc == 0 {
    display as result "  PASS"
    local ++pass_count
}
else {
    display as error "  FAIL (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* Test 19: varabbrev restored to OFF after error
local ++test_count
display as text _n "Test `test_count': varabbrev restored to off after error"

capture noisily {
    set varabbrev off
    capture tc_schemes, source(invalid)
    assert "`c(varabbrev)'" == "off"
}
if _rc == 0 {
    display as result "  PASS"
    local ++pass_count
}
else {
    display as error "  FAIL (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}
set varabbrev on

* Test 20: varabbrev restored to OFF after list+detail error
local ++test_count
display as text _n "Test `test_count': varabbrev restored to off after list+detail error"

capture noisily {
    set varabbrev off
    capture tc_schemes, list detail
    assert "`c(varabbrev)'" == "off"
}
if _rc == 0 {
    display as result "  PASS"
    local ++pass_count
}
else {
    display as error "  FAIL (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}
set varabbrev on

* =============================================================================
* SECTION 6: File availability — all scheme files
* =============================================================================

* Test 21: All 39 scheme files findable
local ++test_count
display as text _n "Test `test_count': All 39 scheme files findable"

capture noisily {
    tc_schemes
    local all_schemes "`r(schemes)'"
    local n = r(n_schemes)
    local found = 0
    foreach s of local all_schemes {
        capture findfile scheme-`s'.scheme
        if _rc {
            display as error "  Cannot find scheme-`s'.scheme"
            exit 601
        }
        local ++found
    }
    assert `found' == `n'
}
if _rc == 0 {
    display as result "  PASS (all 39 scheme files found)"
    local ++pass_count
}
else {
    display as error "  FAIL (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* Test 22: All 21 color style files findable
local ++test_count
display as text _n "Test `test_count': All 21 color style files findable"

capture noisily {
    local colors "vermillion sky turquoise reddish sea orangebrown ananas"
    local colors "`colors' plb1 plb2 plb3 plg1 plg2 plg3 plr1 plr2"
    local colors "`colors' ply1 ply2 ply3 pll1 pll2 pll3"
    local found = 0
    foreach c of local colors {
        capture findfile color-`c'.style
        if _rc {
            display as error "  Cannot find color-`c'.style"
            exit 601
        }
        local ++found
    }
    assert `found' == 21
}
if _rc == 0 {
    display as result "  PASS (all 21 color files found)"
    local ++pass_count
}
else {
    display as error "  FAIL (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* =============================================================================
* SECTION 7: Graph rendering
* =============================================================================

* Test 23: Graph renders with plotplainblind
local ++test_count
display as text _n "Test `test_count': Graph renders with plotplainblind"

capture noisily {
    sysuse auto, clear
    quietly graph twoway scatter price mpg, scheme(plotplainblind)
    graph drop _all
}
if _rc == 0 {
    display as result "  PASS"
    local ++pass_count
}
else {
    display as error "  FAIL (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* Test 24: Graph renders with white_tableau
local ++test_count
display as text _n "Test `test_count': Graph renders with white_tableau"

capture noisily {
    sysuse auto, clear
    quietly graph twoway scatter price mpg, scheme(white_tableau)
    graph drop _all
}
if _rc == 0 {
    display as result "  PASS"
    local ++pass_count
}
else {
    display as error "  FAIL (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* Test 25: Graph renders with black_viridis
local ++test_count
display as text _n "Test `test_count': Graph renders with black_viridis"

capture noisily {
    sysuse auto, clear
    quietly graph twoway scatter price mpg, scheme(black_viridis)
    graph drop _all
}
if _rc == 0 {
    display as result "  PASS"
    local ++pass_count
}
else {
    display as error "  FAIL (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* Test 26: Graph renders with gg_ptol
local ++test_count
display as text _n "Test `test_count': Graph renders with gg_ptol"

capture noisily {
    sysuse auto, clear
    quietly graph twoway scatter price mpg, scheme(gg_ptol)
    graph drop _all
}
if _rc == 0 {
    display as result "  PASS"
    local ++pass_count
}
else {
    display as error "  FAIL (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* =============================================================================
* SECTION 8: Package installation
* =============================================================================

* Test 27: which tc_schemes succeeds
local ++test_count
display as text _n "Test `test_count': which tc_schemes succeeds"

capture noisily {
    which tc_schemes
}
if _rc == 0 {
    display as result "  PASS"
    local ++pass_count
}
else {
    display as error "  FAIL (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* Test 28: help tc_schemes renders
local ++test_count
display as text _n "Test `test_count': help file renders without error"

capture noisily {
    quietly help tc_schemes
}
if _rc == 0 {
    display as result "  PASS"
    local ++pass_count
}
else {
    display as error "  FAIL (error `=_rc')"
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
