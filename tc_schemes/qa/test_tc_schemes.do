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
    assert "`r(sources)'" == "blindschemes schemepack cleanplots modern tc"
    assert "`r(version)'" == "1.1.0"
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

* Test 4: Total scheme count is 45 (4 + 35 + 6)
local ++test_count
display as text _n "Test `test_count': Total scheme count is 45"

capture noisily {
    tc_schemes
    assert r(n_schemes) == 45
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

* Test 4b: source(cleanplots) returns 1 scheme (borrowed, Mize)
local ++test_count
display as text _n "Test `test_count': source(cleanplots) returns 1 scheme"

capture noisily {
    tc_schemes, source(cleanplots)
    assert r(n_schemes) == 1
    assert "`r(schemes)'" == "cleanplots"
    assert "`r(sources)'" == "cleanplots"
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

* Test 4c: source(modern) returns 2 schemes (borrowed, Droste)
local ++test_count
display as text _n "Test `test_count': source(modern) returns 2 schemes"

capture noisily {
    tc_schemes, source(modern)
    assert r(n_schemes) == 2
    assert "`r(schemes)'" == "modern modern_dark"
    assert "`r(sources)'" == "modern"
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

* Test 4d: source(tc) returns 3 original schemes
local ++test_count
display as text _n "Test `test_count': source(tc) returns 3 original schemes"

capture noisily {
    tc_schemes, source(tc)
    assert r(n_schemes) == 3
    assert "`r(schemes)'" == "rdbu ki ki_black"
    assert "`r(sources)'" == "tc"
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

* Test 4e: blindschemes + schemepack + cleanplots + modern + tc == total
local ++test_count
display as text _n "Test `test_count': family counts sum to the total (4+35+1+2+3)"

capture noisily {
    tc_schemes, source(blindschemes)
    local n_b = r(n_schemes)
    tc_schemes, source(schemepack)
    local n_s = r(n_schemes)
    tc_schemes, source(cleanplots)
    local n_c = r(n_schemes)
    tc_schemes, source(modern)
    local n_m = r(n_schemes)
    tc_schemes, source(tc)
    local n_t = r(n_schemes)
    tc_schemes
    assert r(n_schemes) == `n_b' + `n_s' + `n_c' + `n_m' + `n_t'
    assert r(n_schemes) == 45
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
    assert r(n_schemes) == 45
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
    assert r(n_schemes) == 45
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
    assert r(n_schemes) == 45
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
    assert r(n_schemes) == 45
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

* Test 21: All 45 scheme files findable
local ++test_count
display as text _n "Test `test_count': All 45 scheme files findable"

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
    display as result "  PASS (all 45 scheme files found)"
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
* SECTION 9: v1.1.0 regressions — install completeness, new schemes, reload
* =============================================================================

* Test 29: every catalog scheme resolves via `set scheme` (hard error if missing)
* Stronger than findfile: set scheme actually parses the .scheme file and any
* #include base. Proves the .pkg ships every file the catalog advertises.
local ++test_count
display as text _n "Test `test_count': all 45 schemes resolve via set scheme"

capture noisily {
    tc_schemes
    local all_schemes "`r(schemes)'"
    local n = r(n_schemes)
    local resolved = 0
    foreach s of local all_schemes {
        capture set scheme `s'
        if _rc {
            display as error "  set scheme `s' failed (rc=`=_rc')"
            exit 198
        }
        local ++resolved
    }
    set scheme s2color
    assert `resolved' == `n'
    assert `resolved' == 45
}
if _rc == 0 {
    display as result "  PASS (all 45 schemes set without fallback)"
    local ++pass_count
}
else {
    display as error "  FAIL (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* Test 30: graphs render under each new scheme
local ++test_count
display as text _n "Test `test_count': graphs render under the 6 new schemes"

capture noisily {
    sysuse auto, clear
    foreach s in cleanplots modern modern_dark rdbu ki ki_black {
        quietly graph twoway scatter price mpg, scheme(`s')
        graph drop _all
    }
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

* Test 31: r(version) reports 1.1.0
local ++test_count
display as text _n "Test `test_count': r(version) == 1.1.0"

capture noisily {
    tc_schemes, source(tc)
    assert "`r(version)'" == "1.1.0"
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

* Test 32: reload-crash regression — drop+run .ado twice, then call detail.
* Guards the `capture program drop _tc_schemes_detail` fix: re-running the ado
* must not crash with "_tc_schemes_detail already defined".
local ++test_count
display as text _n "Test `test_count': re-running the ado twice does not crash"

capture noisily {
    capture findfile tc_schemes.ado
    local adopath "`r(fn)'"
    capture program drop tc_schemes
    capture program drop _tc_schemes_detail
    run "`adopath'"
    capture program drop tc_schemes
    capture program drop _tc_schemes_detail
    run "`adopath'"
    quietly tc_schemes, detail
    quietly tc_schemes, detail
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

display "RESULT: test_tc_schemes tests=`test_count' pass=`pass_count' fail=`fail_count'"

if `fail_count' > 0 {
    display as error "Some tests FAILED."
    exit 1
}
else {
    display as result "All tests PASSED!"
}

display as text _n "Testing completed: `c(current_date)' `c(current_time)'"
