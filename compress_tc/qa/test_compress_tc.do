* test_compress_tc.do
* Functional tests for compress_tc v1.1.0
* Author: Timothy P Copeland
* Date: 2026-03-21
* Tests: 85

clear all
set more off
version 16.0

* Setup: find local package
capture ado uninstall compress_tc
local pkg_dir "`c(pwd)'/.."
adopath ++ "`pkg_dir'"

local test_count 0
local pass_count 0
local fail_count 0

* =============================================================================
* SECTION 1: Basic execution
* =============================================================================

* Test 1: Basic execution on all variables
local ++test_count
capture noisily {
    sysuse auto, clear
    compress_tc
    assert r(bytes_initial) != .
    assert r(bytes_final) != .
}
if _rc == 0 {
    display as result "RESULT: PASS Test `test_count' — basic execution"
    local ++pass_count
}
else {
    display as error "RESULT: FAIL Test `test_count' — basic execution (rc=`=_rc')"
    local ++fail_count
}

* Test 2: Specific varlist
local ++test_count
capture noisily {
    sysuse auto, clear
    compress_tc make
    assert "`r(varlist)'" == "make"
}
if _rc == 0 {
    display as result "RESULT: PASS Test `test_count' — specific varlist"
    local ++pass_count
}
else {
    display as error "RESULT: FAIL Test `test_count' — specific varlist (rc=`=_rc')"
    local ++fail_count
}

* Test 3: Multiple specific variables
local ++test_count
capture noisily {
    clear
    set obs 100
    gen str20 s1 = "hello"
    gen str20 s2 = "world"
    gen double x = runiform()
    compress_tc s1 s2
}
if _rc == 0 {
    display as result "RESULT: PASS Test `test_count' — multiple specific vars"
    local ++pass_count
}
else {
    display as error "RESULT: FAIL Test `test_count' — multiple specific vars (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* SECTION 2: Option tests
* =============================================================================

* Test 4: nocompress option
local ++test_count
capture noisily {
    sysuse auto, clear
    compress_tc, nocompress
    assert r(bytes_saved) != .
}
if _rc == 0 {
    display as result "RESULT: PASS Test `test_count' — nocompress option"
    local ++pass_count
}
else {
    display as error "RESULT: FAIL Test `test_count' — nocompress option (rc=`=_rc')"
    local ++fail_count
}

* Test 5: nostrl option
local ++test_count
capture noisily {
    sysuse auto, clear
    compress_tc, nostrl
    assert r(bytes_saved) != .
}
if _rc == 0 {
    display as result "RESULT: PASS Test `test_count' — nostrl option"
    local ++pass_count
}
else {
    display as error "RESULT: FAIL Test `test_count' — nostrl option (rc=`=_rc')"
    local ++fail_count
}

* Test 6: noreport option
local ++test_count
capture noisily {
    sysuse auto, clear
    compress_tc, noreport
    assert r(bytes_saved) != .
}
if _rc == 0 {
    display as result "RESULT: PASS Test `test_count' — noreport option"
    local ++pass_count
}
else {
    display as error "RESULT: FAIL Test `test_count' — noreport option (rc=`=_rc')"
    local ++fail_count
}

* Test 7: quietly option
local ++test_count
capture noisily {
    sysuse auto, clear
    compress_tc, quietly
    assert r(bytes_saved) != .
    assert r(pct_saved) != .
    assert r(bytes_initial) != .
    assert r(bytes_final) != .
}
if _rc == 0 {
    display as result "RESULT: PASS Test `test_count' — quietly option returns r()"
    local ++pass_count
}
else {
    display as error "RESULT: FAIL Test `test_count' — quietly option (rc=`=_rc')"
    local ++fail_count
}

* Test 8: detail option
local ++test_count
capture noisily {
    sysuse auto, clear
    compress_tc, detail
}
if _rc == 0 {
    display as result "RESULT: PASS Test `test_count' — detail option"
    local ++pass_count
}
else {
    display as error "RESULT: FAIL Test `test_count' — detail option (rc=`=_rc')"
    local ++fail_count
}

* Test 9: varsavings option
local ++test_count
capture noisily {
    sysuse auto, clear
    compress_tc, varsavings
}
if _rc == 0 {
    display as result "RESULT: PASS Test `test_count' — varsavings option"
    local ++pass_count
}
else {
    display as error "RESULT: FAIL Test `test_count' — varsavings option (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* SECTION 3: Option combinations
* =============================================================================

* Test 10: detail + varsavings
local ++test_count
capture noisily {
    sysuse auto, clear
    compress_tc, detail varsavings
}
if _rc == 0 {
    display as result "RESULT: PASS Test `test_count' — detail + varsavings"
    local ++pass_count
}
else {
    display as error "RESULT: FAIL Test `test_count' — detail + varsavings (rc=`=_rc')"
    local ++fail_count
}

* Test 11: noreport + varsavings
local ++test_count
capture noisily {
    sysuse auto, clear
    compress_tc, noreport varsavings
}
if _rc == 0 {
    display as result "RESULT: PASS Test `test_count' — noreport + varsavings"
    local ++pass_count
}
else {
    display as error "RESULT: FAIL Test `test_count' — noreport + varsavings (rc=`=_rc')"
    local ++fail_count
}

* Test 12: nocompress + detail
local ++test_count
capture noisily {
    sysuse auto, clear
    compress_tc, nocompress detail
}
if _rc == 0 {
    display as result "RESULT: PASS Test `test_count' — nocompress + detail"
    local ++pass_count
}
else {
    display as error "RESULT: FAIL Test `test_count' — nocompress + detail (rc=`=_rc')"
    local ++fail_count
}

* Test 13: nostrl + quietly
local ++test_count
capture noisily {
    sysuse auto, clear
    compress_tc, nostrl quietly
    assert r(bytes_saved) != .
}
if _rc == 0 {
    display as result "RESULT: PASS Test `test_count' — nostrl + quietly"
    local ++pass_count
}
else {
    display as error "RESULT: FAIL Test `test_count' — nostrl + quietly (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* SECTION 4: Error handling
* =============================================================================

* Test 14: Mutually exclusive options (nocompress + nostrl)
local ++test_count
capture noisily {
    sysuse auto, clear
    capture compress_tc, nocompress nostrl
    assert _rc == 198
}
if _rc == 0 {
    display as result "RESULT: PASS Test `test_count' — nocompress+nostrl error 198"
    local ++pass_count
}
else {
    display as error "RESULT: FAIL Test `test_count' — nocompress+nostrl error (rc=`=_rc')"
    local ++fail_count
}

* Test 15: Invalid option
local ++test_count
capture noisily {
    sysuse auto, clear
    capture compress_tc, badoption
    assert _rc != 0
}
if _rc == 0 {
    display as result "RESULT: PASS Test `test_count' — invalid option rejected"
    local ++pass_count
}
else {
    display as error "RESULT: FAIL Test `test_count' — invalid option (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* SECTION 5: Return values
* =============================================================================

* Test 16: All return scalars exist
local ++test_count
capture noisily {
    sysuse auto, clear
    compress_tc, quietly
    assert r(bytes_saved) != .
    assert r(pct_saved) != .
    assert r(bytes_initial) != .
    assert r(bytes_final) != .
}
if _rc == 0 {
    display as result "RESULT: PASS Test `test_count' — all return scalars exist"
    local ++pass_count
}
else {
    display as error "RESULT: FAIL Test `test_count' — return scalars (rc=`=_rc')"
    local ++fail_count
}

* Test 17: r(varlist) returned
local ++test_count
capture noisily {
    sysuse auto, clear
    compress_tc make, quietly
    assert "`r(varlist)'" != ""
}
if _rc == 0 {
    display as result "RESULT: PASS Test `test_count' — r(varlist) returned"
    local ++pass_count
}
else {
    display as error "RESULT: FAIL Test `test_count' — r(varlist) (rc=`=_rc')"
    local ++fail_count
}

* Test 18: Invariant: bytes_saved == bytes_initial - bytes_final
local ++test_count
capture noisily {
    sysuse auto, clear
    compress_tc, quietly
    local diff = r(bytes_initial) - r(bytes_final)
    assert abs(r(bytes_saved) - `diff') < 1
}
if _rc == 0 {
    display as result "RESULT: PASS Test `test_count' — bytes_saved invariant"
    local ++pass_count
}
else {
    display as error "RESULT: FAIL Test `test_count' — bytes_saved invariant (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* SECTION 6: Edge cases
* =============================================================================

* Test 19: Zero observations
local ++test_count
capture noisily {
    clear
    gen str10 x = ""
    assert _N == 0
    compress_tc, quietly
    assert r(bytes_saved) == 0
    assert r(bytes_initial) == 0
    assert r(bytes_final) == 0
    assert "`r(varlist)'" == ""
}
if _rc == 0 {
    display as result "RESULT: PASS Test `test_count' — zero observations"
    local ++pass_count
}
else {
    display as error "RESULT: FAIL Test `test_count' — zero observations (rc=`=_rc')"
    local ++fail_count
}

* Test 20: Single observation
local ++test_count
capture noisily {
    clear
    set obs 1
    gen str50 name = "test"
    compress_tc, quietly
    assert r(bytes_saved) != .
    assert r(bytes_initial) > 0
}
if _rc == 0 {
    display as result "RESULT: PASS Test `test_count' — single observation"
    local ++pass_count
}
else {
    display as error "RESULT: FAIL Test `test_count' — single observation (rc=`=_rc')"
    local ++fail_count
}

* Test 21: All missing strings
local ++test_count
capture noisily {
    clear
    set obs 100
    gen str20 x = ""
    compress_tc, quietly
    assert r(bytes_saved) != .
}
if _rc == 0 {
    display as result "RESULT: PASS Test `test_count' — all missing/empty strings"
    local ++pass_count
}
else {
    display as error "RESULT: FAIL Test `test_count' — all missing strings (rc=`=_rc')"
    local ++fail_count
}

* Test 22: Numeric-only data
local ++test_count
capture noisily {
    clear
    set obs 100
    gen double x = runiform()
    gen long y = _n
    compress_tc, quietly
    assert r(bytes_saved) != .
}
if _rc == 0 {
    display as result "RESULT: PASS Test `test_count' — numeric-only data"
    local ++pass_count
}
else {
    display as error "RESULT: FAIL Test `test_count' — numeric-only data (rc=`=_rc')"
    local ++fail_count
}

* Test 23: Numeric-only varlist on mixed data
local ++test_count
capture noisily {
    sysuse auto, clear
    compress_tc price mpg, quietly
    assert r(bytes_saved) != .
}
if _rc == 0 {
    display as result "RESULT: PASS Test `test_count' — numeric varlist on mixed data"
    local ++pass_count
}
else {
    display as error "RESULT: FAIL Test `test_count' — numeric varlist (rc=`=_rc')"
    local ++fail_count
}

* Test 24: Large repeated strings (strL compression benefit)
local ++test_count
capture noisily {
    clear
    set obs 10000
    gen str200 longtext = "This is a long repeated text for strL compression test with deduplication benefit"
    compress_tc, quietly
    assert r(bytes_saved) > 0
}
if _rc == 0 {
    display as result "RESULT: PASS Test `test_count' — large repeated strings save space"
    local ++pass_count
}
else {
    display as error "RESULT: FAIL Test `test_count' — large repeated strings (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* SECTION 7: Data integrity
* =============================================================================

* Test 25: Observation count preserved
local ++test_count
capture noisily {
    sysuse auto, clear
    local orig_n = _N
    compress_tc, quietly
    assert _N == `orig_n'
}
if _rc == 0 {
    display as result "RESULT: PASS Test `test_count' — observation count preserved"
    local ++pass_count
}
else {
    display as error "RESULT: FAIL Test `test_count' — obs count (rc=`=_rc')"
    local ++fail_count
}

* Test 26: String values preserved
local ++test_count
capture noisily {
    sysuse auto, clear
    local make1 = make[1]
    local make5 = make[5]
    compress_tc, quietly
    assert make[1] == "`make1'"
    assert make[5] == "`make5'"
}
if _rc == 0 {
    display as result "RESULT: PASS Test `test_count' — string values preserved"
    local ++pass_count
}
else {
    display as error "RESULT: FAIL Test `test_count' — string values (rc=`=_rc')"
    local ++fail_count
}

* Test 27: Numeric values preserved
local ++test_count
capture noisily {
    sysuse auto, clear
    local price1 = price[1]
    local mpg1 = mpg[1]
    compress_tc, quietly
    assert price[1] == `price1'
    assert mpg[1] == `mpg1'
}
if _rc == 0 {
    display as result "RESULT: PASS Test `test_count' — numeric values preserved"
    local ++pass_count
}
else {
    display as error "RESULT: FAIL Test `test_count' — numeric values (rc=`=_rc')"
    local ++fail_count
}

* Test 28: Variable count preserved
local ++test_count
capture noisily {
    sysuse auto, clear
    local orig_k = c(k)
    compress_tc, quietly
    assert c(k) == `orig_k'
}
if _rc == 0 {
    display as result "RESULT: PASS Test `test_count' — variable count preserved"
    local ++pass_count
}
else {
    display as error "RESULT: FAIL Test `test_count' — variable count (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* SECTION 8: varabbrev save/restore
* =============================================================================

* Test 29: varabbrev off preserved on success
local ++test_count
capture noisily {
    set varabbrev off
    sysuse auto, clear
    compress_tc, quietly
    assert "`c(varabbrev)'" == "off"
    set varabbrev on
}
if _rc == 0 {
    display as result "RESULT: PASS Test `test_count' — varabbrev off preserved on success"
    local ++pass_count
}
else {
    set varabbrev on
    display as error "RESULT: FAIL Test `test_count' — varabbrev restore success (rc=`=_rc')"
    local ++fail_count
}

* Test 30: varabbrev on preserved on success
local ++test_count
capture noisily {
    set varabbrev on
    sysuse auto, clear
    compress_tc, quietly
    assert "`c(varabbrev)'" == "on"
}
if _rc == 0 {
    display as result "RESULT: PASS Test `test_count' — varabbrev on preserved on success"
    local ++pass_count
}
else {
    set varabbrev on
    display as error "RESULT: FAIL Test `test_count' — varabbrev restore on (rc=`=_rc')"
    local ++fail_count
}

* Test 31: varabbrev off preserved on error path
local ++test_count
capture noisily {
    set varabbrev off
    sysuse auto, clear
    capture compress_tc, nocompress nostrl
    assert "`c(varabbrev)'" == "off"
    set varabbrev on
}
if _rc == 0 {
    display as result "RESULT: PASS Test `test_count' — varabbrev off preserved on error"
    local ++pass_count
}
else {
    set varabbrev on
    display as error "RESULT: FAIL Test `test_count' — varabbrev restore error path (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* SECTION 9: Option abbreviations
* =============================================================================

* Test 32: nocompress abbreviated to noc
local ++test_count
capture noisily {
    sysuse auto, clear
    compress_tc, noc
}
if _rc == 0 {
    display as result "RESULT: PASS Test `test_count' — noc abbreviation"
    local ++pass_count
}
else {
    display as error "RESULT: FAIL Test `test_count' — noc abbreviation (rc=`=_rc')"
    local ++fail_count
}

* Test 33: nostrl abbreviated to nos
local ++test_count
capture noisily {
    sysuse auto, clear
    compress_tc, nos
}
if _rc == 0 {
    display as result "RESULT: PASS Test `test_count' — nos abbreviation"
    local ++pass_count
}
else {
    display as error "RESULT: FAIL Test `test_count' — nos abbreviation (rc=`=_rc')"
    local ++fail_count
}

* Test 34: quietly abbreviated to q
local ++test_count
capture noisily {
    sysuse auto, clear
    compress_tc, q
    assert r(bytes_saved) != .
}
if _rc == 0 {
    display as result "RESULT: PASS Test `test_count' — q abbreviation"
    local ++pass_count
}
else {
    display as error "RESULT: FAIL Test `test_count' — q abbreviation (rc=`=_rc')"
    local ++fail_count
}

* Test 35: detail abbreviated to det
local ++test_count
capture noisily {
    sysuse auto, clear
    compress_tc, det
}
if _rc == 0 {
    display as result "RESULT: PASS Test `test_count' — det abbreviation"
    local ++pass_count
}
else {
    display as error "RESULT: FAIL Test `test_count' — det abbreviation (rc=`=_rc')"
    local ++fail_count
}

* Test 36: varsavings abbreviated to vars
local ++test_count
capture noisily {
    sysuse auto, clear
    compress_tc, vars
}
if _rc == 0 {
    display as result "RESULT: PASS Test `test_count' — vars abbreviation"
    local ++pass_count
}
else {
    display as error "RESULT: FAIL Test `test_count' — vars abbreviation (rc=`=_rc')"
    local ++fail_count
}

* Test 37: noreport abbreviated to nor
local ++test_count
capture noisily {
    sysuse auto, clear
    compress_tc, nor
}
if _rc == 0 {
    display as result "RESULT: PASS Test `test_count' — nor abbreviation"
    local ++pass_count
}
else {
    display as error "RESULT: FAIL Test `test_count' — nor abbreviation (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* SECTION 10: Package installation
* =============================================================================

* Test 38: which finds command
local ++test_count
capture noisily {
    which compress_tc
}
if _rc == 0 {
    display as result "RESULT: PASS Test `test_count' — which compress_tc"
    local ++pass_count
}
else {
    display as error "RESULT: FAIL Test `test_count' — which compress_tc (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* SECTION 11: Additional edge cases
* =============================================================================

* Test 39: Already-strL variables (no str# to convert)
local ++test_count
capture noisily {
    clear
    set obs 100
    gen str50 s = "test value"
    recast strL s
    compress_tc, quietly
    assert r(bytes_saved) != .
    assert r(bytes_initial) > 0
}
if _rc == 0 {
    display as result "RESULT: PASS Test `test_count' — already-strL variables"
    local ++pass_count
}
else {
    display as error "RESULT: FAIL Test `test_count' — already-strL (rc=`=_rc')"
    local ++fail_count
}

* Test 40: Single string variable in dataset
local ++test_count
capture noisily {
    clear
    set obs 50
    gen str30 only_var = "single var dataset"
    compress_tc, quietly
    assert r(bytes_saved) != .
    assert r(bytes_initial) > 0
}
if _rc == 0 {
    display as result "RESULT: PASS Test `test_count' — single string variable"
    local ++pass_count
}
else {
    display as error "RESULT: FAIL Test `test_count' — single string var (rc=`=_rc')"
    local ++fail_count
}

* Test 41: Many string variables (>10) — exercises line wrapping
local ++test_count
capture noisily {
    clear
    set obs 100
    forvalues i = 1/15 {
        gen str30 longvarname_`i' = "value `i'"
    }
    compress_tc, quietly
    assert r(bytes_saved) != .
}
if _rc == 0 {
    display as result "RESULT: PASS Test `test_count' — many string variables (15)"
    local ++pass_count
}
else {
    display as error "RESULT: FAIL Test `test_count' — many string vars (rc=`=_rc')"
    local ++fail_count
}

* Test 42: String variables with special characters
local ++test_count
capture noisily {
    clear
    set obs 50
    gen str80 s = `"Hello, World! It's a "test" with; special & chars <> @#$%"'
    compress_tc, quietly
    assert r(bytes_saved) != .
}
if _rc == 0 {
    display as result "RESULT: PASS Test `test_count' — special characters in strings"
    local ++pass_count
}
else {
    display as error "RESULT: FAIL Test `test_count' — special chars (rc=`=_rc')"
    local ++fail_count
}

* Test 43: String with very long values (near 2045 limit)
local ++test_count
capture noisily {
    clear
    set obs 50
    gen str2045 longstr = ""
    forvalues i = 1/40 {
        replace longstr = longstr + "This is a long segment of text number `i'. "
    }
    compress_tc, quietly
    assert r(bytes_saved) != .
    assert r(bytes_initial) > 0
}
if _rc == 0 {
    display as result "RESULT: PASS Test `test_count' — very long strings (near 2045)"
    local ++pass_count
}
else {
    display as error "RESULT: FAIL Test `test_count' — long strings (rc=`=_rc')"
    local ++fail_count
}

* Test 44: Mixed str# and strL variables in same dataset
local ++test_count
capture noisily {
    clear
    set obs 100
    gen str50 fixed_str = "fixed length string"
    gen str20 another_fixed = "short"
    recast strL fixed_str
    * Now dataset has one strL and one str#
    compress_tc, quietly
    assert r(bytes_saved) != .
}
if _rc == 0 {
    display as result "RESULT: PASS Test `test_count' — mixed str# and strL"
    local ++pass_count
}
else {
    display as error "RESULT: FAIL Test `test_count' — mixed str types (rc=`=_rc')"
    local ++fail_count
}

* Test 45: Empty string variable (all observations are "")
local ++test_count
capture noisily {
    clear
    set obs 200
    gen str50 empty = ""
    compress_tc, quietly
    assert r(bytes_saved) != .
}
if _rc == 0 {
    display as result "RESULT: PASS Test `test_count' — all empty strings"
    local ++pass_count
}
else {
    display as error "RESULT: FAIL Test `test_count' — empty strings (rc=`=_rc')"
    local ++fail_count
}

* Test 46: Variable with mix of empty and non-empty strings
local ++test_count
capture noisily {
    clear
    set obs 100
    gen str50 mixed = ""
    replace mixed = "has content" if mod(_n, 3) == 0
    compress_tc, quietly
    assert r(bytes_saved) != .
}
if _rc == 0 {
    display as result "RESULT: PASS Test `test_count' — mixed empty/non-empty"
    local ++pass_count
}
else {
    display as error "RESULT: FAIL Test `test_count' — mixed empty (rc=`=_rc')"
    local ++fail_count
}

* Test 47: Constant string variable (all same value)
local ++test_count
capture noisily {
    clear
    set obs 1000
    gen str100 constant = "exactly the same value in every observation"
    compress_tc, quietly
    assert r(bytes_saved) > 0
}
if _rc == 0 {
    display as result "RESULT: PASS Test `test_count' — constant string (saves space)"
    local ++pass_count
}
else {
    display as error "RESULT: FAIL Test `test_count' — constant string (rc=`=_rc')"
    local ++fail_count
}

* Test 48: String variable with all unique values
local ++test_count
capture noisily {
    clear
    set obs 200
    gen str20 unique = "val_" + string(_n, "%04.0f")
    compress_tc, quietly
    assert r(bytes_saved) != .
}
if _rc == 0 {
    display as result "RESULT: PASS Test `test_count' — all unique strings"
    local ++pass_count
}
else {
    display as error "RESULT: FAIL Test `test_count' — unique strings (rc=`=_rc')"
    local ++fail_count
}

* Test 49: Duplicate observations in dataset
local ++test_count
capture noisily {
    clear
    set obs 50
    gen str30 s = "duplicate row"
    gen double x = 42.5
    expand 2
    compress_tc, quietly
    assert r(bytes_saved) != .
    assert _N == 100
}
if _rc == 0 {
    display as result "RESULT: PASS Test `test_count' — duplicate observations"
    local ++pass_count
}
else {
    display as error "RESULT: FAIL Test `test_count' — duplicates (rc=`=_rc')"
    local ++fail_count
}

* Test 50: Very large dataset (50,000 obs)
local ++test_count
capture noisily {
    clear
    set obs 50000
    gen str100 text = "Category " + string(mod(_n, 20))
    gen double value = runiform()
    compress_tc, quietly
    assert r(bytes_saved) != .
    assert r(bytes_initial) > 0
    assert _N == 50000
}
if _rc == 0 {
    display as result "RESULT: PASS Test `test_count' — large dataset (50000 obs)"
    local ++pass_count
}
else {
    display as error "RESULT: FAIL Test `test_count' — large dataset (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* SECTION 12: Additional option combinations
* =============================================================================

* Test 51: nocompress + noreport
local ++test_count
capture noisily {
    sysuse auto, clear
    compress_tc, nocompress noreport
    assert r(bytes_saved) != .
}
if _rc == 0 {
    display as result "RESULT: PASS Test `test_count' — nocompress + noreport"
    local ++pass_count
}
else {
    display as error "RESULT: FAIL Test `test_count' — nocompress+noreport (rc=`=_rc')"
    local ++fail_count
}

* Test 52: nocompress + varsavings
local ++test_count
capture noisily {
    sysuse auto, clear
    compress_tc, nocompress varsavings
    assert r(bytes_saved) != .
}
if _rc == 0 {
    display as result "RESULT: PASS Test `test_count' — nocompress + varsavings"
    local ++pass_count
}
else {
    display as error "RESULT: FAIL Test `test_count' — nocompress+varsavings (rc=`=_rc')"
    local ++fail_count
}

* Test 53: nostrl + detail
local ++test_count
capture noisily {
    sysuse auto, clear
    compress_tc, nostrl detail
    assert r(bytes_saved) != .
}
if _rc == 0 {
    display as result "RESULT: PASS Test `test_count' — nostrl + detail"
    local ++pass_count
}
else {
    display as error "RESULT: FAIL Test `test_count' — nostrl+detail (rc=`=_rc')"
    local ++fail_count
}

* Test 54: nostrl + noreport
local ++test_count
capture noisily {
    sysuse auto, clear
    compress_tc, nostrl noreport
    assert r(bytes_saved) != .
}
if _rc == 0 {
    display as result "RESULT: PASS Test `test_count' — nostrl + noreport"
    local ++pass_count
}
else {
    display as error "RESULT: FAIL Test `test_count' — nostrl+noreport (rc=`=_rc')"
    local ++fail_count
}

* Test 55: nostrl + varsavings
local ++test_count
capture noisily {
    sysuse auto, clear
    compress_tc, nostrl varsavings
    assert r(bytes_saved) != .
}
if _rc == 0 {
    display as result "RESULT: PASS Test `test_count' — nostrl + varsavings"
    local ++pass_count
}
else {
    display as error "RESULT: FAIL Test `test_count' — nostrl+varsavings (rc=`=_rc')"
    local ++fail_count
}

* Test 56: detail + noreport (both affect display)
local ++test_count
capture noisily {
    sysuse auto, clear
    compress_tc, detail noreport
    assert r(bytes_saved) != .
}
if _rc == 0 {
    display as result "RESULT: PASS Test `test_count' — detail + noreport"
    local ++pass_count
}
else {
    display as error "RESULT: FAIL Test `test_count' — detail+noreport (rc=`=_rc')"
    local ++fail_count
}

* Test 57: detail + quietly (quietly suppresses detail)
local ++test_count
capture noisily {
    sysuse auto, clear
    compress_tc, detail quietly
    assert r(bytes_saved) != .
}
if _rc == 0 {
    display as result "RESULT: PASS Test `test_count' — detail + quietly"
    local ++pass_count
}
else {
    display as error "RESULT: FAIL Test `test_count' — detail+quietly (rc=`=_rc')"
    local ++fail_count
}

* Test 58: varsavings + quietly (quietly suppresses varsavings)
local ++test_count
capture noisily {
    sysuse auto, clear
    compress_tc, varsavings quietly
    assert r(bytes_saved) != .
}
if _rc == 0 {
    display as result "RESULT: PASS Test `test_count' — varsavings + quietly"
    local ++pass_count
}
else {
    display as error "RESULT: FAIL Test `test_count' — varsavings+quietly (rc=`=_rc')"
    local ++fail_count
}

* Test 59: noreport + quietly
local ++test_count
capture noisily {
    sysuse auto, clear
    compress_tc, noreport quietly
    assert r(bytes_saved) != .
}
if _rc == 0 {
    display as result "RESULT: PASS Test `test_count' — noreport + quietly"
    local ++pass_count
}
else {
    display as error "RESULT: FAIL Test `test_count' — noreport+quietly (rc=`=_rc')"
    local ++fail_count
}

* Test 60: Three options: nocompress + detail + varsavings
local ++test_count
capture noisily {
    sysuse auto, clear
    compress_tc, nocompress detail varsavings
    assert r(bytes_saved) != .
}
if _rc == 0 {
    display as result "RESULT: PASS Test `test_count' — nocompress+detail+varsavings"
    local ++pass_count
}
else {
    display as error "RESULT: FAIL Test `test_count' — nocompress+detail+varsavings (rc=`=_rc')"
    local ++fail_count
}

* Test 61: Three options: nostrl + noreport + varsavings
local ++test_count
capture noisily {
    sysuse auto, clear
    compress_tc, nostrl noreport varsavings
    assert r(bytes_saved) != .
}
if _rc == 0 {
    display as result "RESULT: PASS Test `test_count' — nostrl+noreport+varsavings"
    local ++pass_count
}
else {
    display as error "RESULT: FAIL Test `test_count' — nostrl+noreport+varsavings (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* SECTION 13: Numeric-only and mixed varlist edge cases
* =============================================================================

* Test 62: nocompress on numeric-only data
local ++test_count
capture noisily {
    clear
    set obs 100
    gen double x = runiform()
    gen long y = _n
    compress_tc, nocompress quietly
    assert r(bytes_saved) != .
}
if _rc == 0 {
    display as result "RESULT: PASS Test `test_count' — nocompress on numeric-only"
    local ++pass_count
}
else {
    display as error "RESULT: FAIL Test `test_count' — nocompress numeric (rc=`=_rc')"
    local ++fail_count
}

* Test 63: nostrl on numeric-only data
local ++test_count
capture noisily {
    clear
    set obs 100
    gen double x = runiform()
    gen long y = _n
    compress_tc, nostrl quietly
    assert r(bytes_saved) != .
}
if _rc == 0 {
    display as result "RESULT: PASS Test `test_count' — nostrl on numeric-only"
    local ++pass_count
}
else {
    display as error "RESULT: FAIL Test `test_count' — nostrl numeric (rc=`=_rc')"
    local ++fail_count
}

* Test 64: Varlist with single numeric variable
local ++test_count
capture noisily {
    sysuse auto, clear
    compress_tc price, quietly
    assert r(bytes_saved) != .
}
if _rc == 0 {
    display as result "RESULT: PASS Test `test_count' — single numeric varlist"
    local ++pass_count
}
else {
    display as error "RESULT: FAIL Test `test_count' — single numeric varlist (rc=`=_rc')"
    local ++fail_count
}

* Test 65: Varlist with mix of string and numeric
local ++test_count
capture noisily {
    sysuse auto, clear
    compress_tc make price mpg, quietly
    assert r(bytes_saved) != .
    assert strpos("`r(varlist)'", "make") > 0
}
if _rc == 0 {
    display as result "RESULT: PASS Test `test_count' — mixed string+numeric varlist"
    local ++pass_count
}
else {
    display as error "RESULT: FAIL Test `test_count' — mixed varlist (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* SECTION 14: v1.1.0 — lowmem, dryrun, minlength, new returns
* =============================================================================

* Test 66: lowmem option runs and returns valid results
local ++test_count
capture noisily {
    clear
    set obs 20000
    gen str200 longtext = "Category " + string(mod(_n,15))
    gen double x = runiform()
    compress_tc, lowmem quietly
    assert r(bytes_saved) != .
    assert r(bytes_initial) > 0
}
if _rc == 0 {
    display as result "RESULT: PASS Test `test_count' — lowmem runs"
    local ++pass_count
}
else {
    display as error "RESULT: FAIL Test `test_count' — lowmem runs (rc=`=_rc')"
    local ++fail_count
}

* Test 67: lowmem reaches the SAME final bytes as batch mode (equivalence)
local ++test_count
capture noisily {
    clear
    set obs 20000
    gen str200 a = "repeated alpha " + string(mod(_n,10))
    gen str200 b = "repeated beta " + string(mod(_n,12))
    gen double x = runiform()
    tempfile orig
    save `orig'
    compress_tc, quietly
    local batch_final = r(bytes_final)
    use `orig', clear
    compress_tc, lowmem quietly
    local low_final = r(bytes_final)
    assert `batch_final' == `low_final'
}
if _rc == 0 {
    display as result "RESULT: PASS Test `test_count' — lowmem == batch final bytes"
    local ++pass_count
}
else {
    display as error "RESULT: FAIL Test `test_count' — lowmem equivalence (rc=`=_rc')"
    local ++fail_count
}

* Test 68: lowmem + varsavings (measured per-variable path) runs
local ++test_count
capture noisily {
    clear
    set obs 20000
    gen str200 a = "long repeated alpha " + string(mod(_n,10))
    compress_tc, lowmem varsavings
    assert r(bytes_saved) != .
}
if _rc == 0 {
    display as result "RESULT: PASS Test `test_count' — lowmem + varsavings"
    local ++pass_count
}
else {
    display as error "RESULT: FAIL Test `test_count' — lowmem+varsavings (rc=`=_rc')"
    local ++fail_count
}

* Test 69: dryrun does NOT modify the data (storage types restored)
local ++test_count
capture noisily {
    clear
    set obs 5000
    gen str100 t = "repeated value " + string(mod(_n,5))
    local before : type t
    compress_tc, dryrun quietly
    local after : type t
    assert "`before'" == "`after'"
    assert "`after'" == "str100"
}
if _rc == 0 {
    display as result "RESULT: PASS Test `test_count' — dryrun leaves data unmodified"
    local ++pass_count
}
else {
    display as error "RESULT: FAIL Test `test_count' — dryrun unmodified (rc=`=_rc')"
    local ++fail_count
}

* Test 70: dryrun still posts results in r()
local ++test_count
capture noisily {
    clear
    set obs 5000
    gen str100 t = "repeated value " + string(mod(_n,5))
    compress_tc, dryrun quietly
    assert r(bytes_saved) != .
    assert r(bytes_initial) > 0
    assert r(bytes_final) != .
}
if _rc == 0 {
    display as result "RESULT: PASS Test `test_count' — dryrun posts r()"
    local ++pass_count
}
else {
    display as error "RESULT: FAIL Test `test_count' — dryrun r() (rc=`=_rc')"
    local ++fail_count
}

* Test 71: dryrun projected savings approximate an actual run on the same data
*          (dryrun is a preview; under preserve the strL heap may retain a tiny
*           residual, so projected savings are accurate to a fraction of a percent)
local ++test_count
capture noisily {
    clear
    set obs 8000
    gen str200 s = "repeated content " + string(mod(_n,7))
    tempfile orig
    save `orig'
    compress_tc, dryrun quietly
    local dry_saved = r(bytes_saved)
    use `orig', clear
    compress_tc, quietly
    local real_saved = r(bytes_saved)
    assert reldif(`dry_saved', `real_saved') < 0.01
}
if _rc == 0 {
    display as result "RESULT: PASS Test `test_count' — dryrun matches actual savings"
    local ++pass_count
}
else {
    display as error "RESULT: FAIL Test `test_count' — dryrun savings (rc=`=_rc')"
    local ++fail_count
}

* Test 72: minlength skips short str# from strL but they stay in r(varlist)
local ++test_count
capture noisily {
    clear
    set obs 1000
    gen str3 shortc = "abc"
    gen str200 longc = "long repeated " + string(mod(_n,5))
    compress_tc, minlength(20) quietly
    assert r(k_converted) == 1
    assert strpos("`r(varlist)'", "shortc") > 0
    assert strpos("`r(varlist)'", "longc") > 0
}
if _rc == 0 {
    display as result "RESULT: PASS Test `test_count' — minlength skips short, keeps in varlist"
    local ++pass_count
}
else {
    display as error "RESULT: FAIL Test `test_count' — minlength (rc=`=_rc')"
    local ++fail_count
}

* Test 73: minlength(0) default converts every str# variable
local ++test_count
capture noisily {
    clear
    set obs 1000
    gen str3 c1 = "abc"
    gen str200 c2 = "long " + string(mod(_n,5))
    compress_tc, nocompress minlength(0) quietly
    assert r(k_converted) == 2
}
if _rc == 0 {
    display as result "RESULT: PASS Test `test_count' — minlength(0) converts all"
    local ++pass_count
}
else {
    display as error "RESULT: FAIL Test `test_count' — minlength(0) (rc=`=_rc')"
    local ++fail_count
}

* Test 74: negative minlength is rejected
local ++test_count
capture noisily {
    sysuse auto, clear
    capture compress_tc, minlength(-5)
    assert _rc == 198
}
if _rc == 0 {
    display as result "RESULT: PASS Test `test_count' — negative minlength error 198"
    local ++pass_count
}
else {
    display as error "RESULT: FAIL Test `test_count' — negative minlength (rc=`=_rc')"
    local ++fail_count
}

* Test 75: new scalar returns exist and are sensible
local ++test_count
capture noisily {
    clear
    set obs 5000
    gen str100 s = "repeated " + string(mod(_n,8))
    gen double x = runiform()
    compress_tc, quietly
    assert r(bytes_strl) != .
    assert r(bytes_strl) >= 0
    assert r(k_converted) != .
    assert r(k_reverted) != .
    assert r(k_reverted) <= r(k_converted)
}
if _rc == 0 {
    display as result "RESULT: PASS Test `test_count' — new scalar returns sensible"
    local ++pass_count
}
else {
    display as error "RESULT: FAIL Test `test_count' — new scalar returns (rc=`=_rc')"
    local ++fail_count
}

* Test 76: r(vars_strl) names the variable that genuinely stays strL
local ++test_count
capture noisily {
    clear
    set obs 5000
    gen str2045 bigtext = "Category" + string(mod(_n,5))
    forvalues k = 1/180 {
        quietly replace bigtext = bigtext + "ABCDEFGHIJ"
    }
    compress_tc, quietly
    assert strpos("`r(vars_strl)'", "bigtext") > 0
    assert r(bytes_strl) > 0
}
if _rc == 0 {
    display as result "RESULT: PASS Test `test_count' — vars_strl names surviving strL var"
    local ++pass_count
}
else {
    display as error "RESULT: FAIL Test `test_count' — vars_strl content (rc=`=_rc')"
    local ++fail_count
}

* Test 77: r(vars_strl) is empty when nothing stays strL
local ++test_count
capture noisily {
    sysuse auto, clear
    compress_tc make, quietly
    assert "`r(vars_strl)'" == ""
    assert r(bytes_strl) == 0 | r(bytes_strl) >= 0
}
if _rc == 0 {
    display as result "RESULT: PASS Test `test_count' — vars_strl empty when no strL survives"
    local ++pass_count
}
else {
    display as error "RESULT: FAIL Test `test_count' — vars_strl empty (rc=`=_rc')"
    local ++fail_count
}

* Test 78: dryrun + lowmem combine
local ++test_count
capture noisily {
    clear
    set obs 10000
    gen str200 s = "repeated " + string(mod(_n,6))
    local before : type s
    compress_tc, dryrun lowmem quietly
    local after : type s
    assert "`before'" == "`after'"
    assert r(bytes_saved) != .
}
if _rc == 0 {
    display as result "RESULT: PASS Test `test_count' — dryrun + lowmem"
    local ++pass_count
}
else {
    display as error "RESULT: FAIL Test `test_count' — dryrun+lowmem (rc=`=_rc')"
    local ++fail_count
}

* Test 79: new option abbreviations (low, dry, min)
local ++test_count
capture noisily {
    clear
    set obs 2000
    gen str100 s = "repeated " + string(mod(_n,5))
    compress_tc, low quietly
    compress_tc s, dry quietly
    clear
    set obs 2000
    gen str100 s = "repeated " + string(mod(_n,5))
    compress_tc, min(10) quietly
}
if _rc == 0 {
    display as result "RESULT: PASS Test `test_count' — low/dry/min abbreviations"
    local ++pass_count
}
else {
    display as error "RESULT: FAIL Test `test_count' — new abbreviations (rc=`=_rc')"
    local ++fail_count
}

* Test 80: varsavings before/after table runs on mixed data (no crash)
local ++test_count
capture noisily {
    clear
    set obs 5000
    gen str200 longtext = "Category " + string(mod(_n,15))
    gen str4 code = string(mod(_n,9999))
    gen double x = runiform()
    compress_tc, varsavings
    assert r(bytes_saved) != .
}
if _rc == 0 {
    display as result "RESULT: PASS Test `test_count' — varsavings before/after table"
    local ++pass_count
}
else {
    display as error "RESULT: FAIL Test `test_count' — varsavings table (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* SECTION 15: v1.1.0 regression — early-exit state restore & detail min abbrev
* =============================================================================

* Test 81: varabbrev restored after empty-dataset (_N==0) early exit
*          (bare exit inside capture noisily previously bypassed cleanup)
local ++test_count
capture noisily {
    set varabbrev on
    clear
    set obs 0
    gen str5 x = ""
    compress_tc, quietly
    assert "`c(varabbrev)'" == "on"
}
if _rc == 0 {
    display as result "RESULT: PASS Test `test_count' — varabbrev restored on empty-dataset exit"
    local ++pass_count
}
else {
    set varabbrev on
    display as error "RESULT: FAIL Test `test_count' — empty-dataset varabbrev restore (rc=`=_rc')"
    local ++fail_count
}

* Test 82: varabbrev restored after no-data (zero-byte) early exit
local ++test_count
capture noisily {
    set varabbrev on
    clear
    set obs 10
    compress_tc, quietly
    assert "`c(varabbrev)'" == "on"
}
if _rc == 0 {
    display as result "RESULT: PASS Test `test_count' — varabbrev restored on no-data exit"
    local ++pass_count
}
else {
    set varabbrev on
    display as error "RESULT: FAIL Test `test_count' — no-data varabbrev restore (rc=`=_rc')"
    local ++fail_count
}

* Test 83: a user's OFF state is preserved (not forced on) on the empty path
local ++test_count
capture noisily {
    set varabbrev off
    clear
    set obs 0
    gen str5 y = ""
    compress_tc, quietly
    assert "`c(varabbrev)'" == "off"
    set varabbrev on
}
if _rc == 0 {
    display as result "RESULT: PASS Test `test_count' — varabbrev off preserved on empty path"
    local ++pass_count
}
else {
    set varabbrev on
    display as error "RESULT: FAIL Test `test_count' — empty-path off preserved (rc=`=_rc')"
    local ++fail_count
}

* Test 84: returns still fully posted on the empty early-exit path
local ++test_count
capture noisily {
    clear
    set obs 0
    gen str5 z = ""
    compress_tc, quietly
    assert r(bytes_saved)   == 0
    assert r(k_converted)   == 0
    assert r(k_reverted)    == 0
    assert r(bytes_strl)    == 0
    assert "`r(vars_strl)'" == ""
    assert "`r(varlist)'"   == ""
}
if _rc == 0 {
    display as result "RESULT: PASS Test `test_count' — returns posted on empty early exit"
    local ++pass_count
}
else {
    display as error "RESULT: FAIL Test `test_count' — empty-path returns (rc=`=_rc')"
    local ++fail_count
}

* Test 85: detail abbreviates to its documented minimum 'd' (syntax: Detail)
local ++test_count
capture noisily {
    sysuse auto, clear
    compress_tc, d
}
if _rc == 0 {
    display as result "RESULT: PASS Test `test_count' — detail min abbreviation 'd'"
    local ++pass_count
}
else {
    display as error "RESULT: FAIL Test `test_count' — detail min abbreviation 'd' (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* SUMMARY
* =============================================================================
display as text ""
display as text "COMPRESS_TC FUNCTIONAL TEST SUMMARY"
display as text "Total:  `test_count'"
display as result "Passed: `pass_count'"
if `fail_count' > 0 {
    display as error "Failed: `fail_count'"
}
else {
    display as text "Failed: `fail_count'"
}

if `fail_count' > 0 {
    exit 1
}
