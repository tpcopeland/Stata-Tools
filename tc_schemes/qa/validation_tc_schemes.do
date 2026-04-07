* validation_tc_schemes.do
*
* Validation tests for tc_schemes command
* Tests known-answer values, invariants, and cross-source consistency
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
* SECTION 1: Known-answer scheme counts
* =============================================================================

* Test 1: blindschemes count is exactly 4
local ++test_count
display as text _n "Test `test_count': blindschemes count == 4"

capture noisily {
    tc_schemes, source(blindschemes)
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

* Test 2: schemepack count is exactly 35
local ++test_count
display as text _n "Test `test_count': schemepack count == 35"

capture noisily {
    tc_schemes, source(schemepack)
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

* Test 3: Total count invariant: all == blindschemes + schemepack
local ++test_count
display as text _n "Test `test_count': all == blindschemes + schemepack"

capture noisily {
    tc_schemes, source(blindschemes)
    local n_blind = r(n_schemes)
    tc_schemes, source(schemepack)
    local n_pack = r(n_schemes)
    tc_schemes
    local n_all = r(n_schemes)
    assert `n_all' == `n_blind' + `n_pack'
}
if _rc == 0 {
    display as result "  PASS (`n_all' == `n_blind' + `n_pack')"
    local ++pass_count
}
else {
    display as error "  FAIL (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* =============================================================================
* SECTION 2: Known-answer scheme names
* =============================================================================

* Test 4: blindschemes r(schemes) contains exact expected names
local ++test_count
display as text _n "Test `test_count': blindschemes r(schemes) has exact names"

capture noisily {
    tc_schemes, source(blindschemes)
    local schemes "`r(schemes)'"
    assert "`schemes'" == "plotplain plotplainblind plottig plottigblind"
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

* Test 5: schemepack r(schemes) starts with tableau series
local ++test_count
display as text _n "Test `test_count': schemepack r(schemes) starts with tableau"

capture noisily {
    tc_schemes, source(schemepack)
    local schemes "`r(schemes)'"
    local w1: word 1 of `schemes'
    local w2: word 2 of `schemes'
    local w3: word 3 of `schemes'
    assert "`w1'" == "white_tableau"
    assert "`w2'" == "black_tableau"
    assert "`w3'" == "gg_tableau"
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

* Test 6: schemepack r(schemes) ends with standalone schemes
local ++test_count
display as text _n "Test `test_count': schemepack r(schemes) ends with standalone"

capture noisily {
    tc_schemes, source(schemepack)
    local schemes "`r(schemes)'"
    local n: word count `schemes'
    local last: word `n' of `schemes'
    assert "`last'" == "rainbow"
    local penult = `n' - 1
    local second_last: word `penult' of `schemes'
    assert "`second_last'" == "neon"
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

* Test 7: all r(schemes) is blindschemes + schemepack concatenated
local ++test_count
display as text _n "Test `test_count': all r(schemes) == blind + pack concatenated"

capture noisily {
    tc_schemes, source(blindschemes)
    local blind_schemes "`r(schemes)'"
    tc_schemes, source(schemepack)
    local pack_schemes "`r(schemes)'"
    tc_schemes
    local all_schemes "`r(schemes)'"
    assert "`all_schemes'" == "`blind_schemes' `pack_schemes'"
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
* SECTION 3: Schemepack series invariants
* =============================================================================

* Test 8: Each series palette has exactly 3 variants (white_, black_, gg_)
local ++test_count
display as text _n "Test `test_count': Each series palette has 3 variants"

capture noisily {
    tc_schemes, source(schemepack) list
    local schemes "`r(schemes)'"
    foreach palette in tableau cividis viridis hue brbg piyg ptol jet w3d {
        local has_white = 0
        local has_black = 0
        local has_gg = 0
        foreach s of local schemes {
            if "`s'" == "white_`palette'" local has_white = 1
            if "`s'" == "black_`palette'" local has_black = 1
            if "`s'" == "gg_`palette'" local has_gg = 1
        }
        assert `has_white' == 1
        assert `has_black' == 1
        assert `has_gg' == 1
    }
}
if _rc == 0 {
    display as result "  PASS (9 palettes x 3 backgrounds)"
    local ++pass_count
}
else {
    display as error "  FAIL (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* Test 9: All 8 standalone schemes present
local ++test_count
display as text _n "Test `test_count': All 8 standalone schemes present"

capture noisily {
    tc_schemes, source(schemepack) list
    local schemes "`r(schemes)'"
    foreach standalone in tab1 tab2 tab3 cblind1 ukraine swift_red neon rainbow {
        local found = 0
        foreach s of local schemes {
            if "`s'" == "`standalone'" local found = 1
        }
        assert `found' == 1
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

* =============================================================================
* SECTION 4: Return value consistency across display modes
* =============================================================================

* Test 10: r(n_schemes) same across default, list, detail
local ++test_count
display as text _n "Test `test_count': r(n_schemes) consistent across display modes"

capture noisily {
    tc_schemes
    local n_default = r(n_schemes)
    tc_schemes, list
    local n_list = r(n_schemes)
    tc_schemes, detail
    local n_detail = r(n_schemes)
    assert `n_default' == `n_list'
    assert `n_default' == `n_detail'
}
if _rc == 0 {
    display as result "  PASS (all `n_default')"
    local ++pass_count
}
else {
    display as error "  FAIL (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* Test 11: r(schemes) same across default, list, detail
local ++test_count
display as text _n "Test `test_count': r(schemes) consistent across display modes"

capture noisily {
    tc_schemes
    local s_default "`r(schemes)'"
    tc_schemes, list
    local s_list "`r(schemes)'"
    tc_schemes, detail
    local s_detail "`r(schemes)'"
    assert "`s_default'" == "`s_list'"
    assert "`s_default'" == "`s_detail'"
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
* SECTION 5: Scheme file existence matches r(schemes)
* =============================================================================

* Test 12: Every scheme in r(schemes) has a findable .scheme file
local ++test_count
display as text _n "Test `test_count': Every r(schemes) entry has a .scheme file"

capture noisily {
    tc_schemes
    local schemes "`r(schemes)'"
    foreach s of local schemes {
        capture findfile scheme-`s'.scheme
        if _rc {
            display as error "  scheme-`s'.scheme not found"
            exit 601
        }
    }
}
if _rc == 0 {
    display as result "  PASS (all 39 verified)"
    local ++pass_count
}
else {
    display as error "  FAIL (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* Test 13: Each scheme in r(schemes) can be used by set scheme
local ++test_count
display as text _n "Test `test_count': set scheme works for sample schemes"

capture noisily {
    local saved_scheme `c(scheme)'
    foreach s in plotplain plotplainblind white_tableau gg_viridis tab1 cblind1 {
        set scheme `s'
        assert "`c(scheme)'" == "`s'"
    }
    set scheme `saved_scheme'
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
* SECTION 6: Graph rendering across background types
* =============================================================================

* Test 14: Graph renders with each background type (white/black/gg)
local ++test_count
display as text _n "Test `test_count': Graphs render with white/black/gg backgrounds"

capture noisily {
    sysuse auto, clear
    foreach bg in white black gg {
        quietly graph twoway scatter price mpg, scheme(`bg'_tableau) name(_test_`bg', replace)
    }
    graph drop _test_white _test_black _test_gg
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

* Test 15: Graph renders with standalone schemes
local ++test_count
display as text _n "Test `test_count': Graphs render with standalone schemes"

capture noisily {
    sysuse auto, clear
    foreach s in tab1 cblind1 neon rainbow {
        quietly graph twoway scatter price mpg, scheme(`s') name(_test_`s', replace)
    }
    graph drop _test_tab1 _test_cblind1 _test_neon _test_rainbow
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
display as text "TC_SCHEMES VALIDATION SUMMARY"
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
