/*******************************************************************************
* validation_compress_tc.do
*
* Purpose: Validation tests for compress_tc command
*          Tests string compression and memory savings calculations.
*
* Command: compress_tc converts str# to strL then runs compress.
*          Returns: r(bytes_saved), r(pct_saved), r(bytes_initial), r(bytes_final)
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

* Add compress_tc to adopath
adopath ++ "`base_path'/compress_tc"

* =============================================================================
* HEADER
* =============================================================================
display as text _n "{hline 70}"
display as text "COMPRESS_TC VALIDATION TESTS"
display as text "{hline 70}"

* =============================================================================
* TEST COUNTERS
* =============================================================================
local test_count = 0
local pass_count = 0
local fail_count = 0

* =============================================================================
* SECTION 1: BASIC EXECUTION TESTS
* =============================================================================
display as text _n "SECTION 1: Basic Execution Tests" _n

* Test 1.1: Basic execution with sysuse auto
local ++test_count
display as text "Test 1.1: Basic execution"
capture {
    sysuse auto, clear
    compress_tc
}
if _rc == 0 {
    display as result "  PASS: compress_tc executes without error"
    local ++pass_count
}
else {
    display as error "  FAIL: compress_tc failed with error `=_rc'"
    local ++fail_count
}

* =============================================================================
* SECTION 2: RETURN VALUES
* =============================================================================
display as text _n "SECTION 2: Return Values" _n

* Test 2.1: r(bytes_saved) exists
local ++test_count
display as text "Test 2.1: r(bytes_saved) returned"
sysuse auto, clear
compress_tc
if r(bytes_saved) != . {
    display as result "  PASS: r(bytes_saved) = `r(bytes_saved)'"
    local ++pass_count
}
else {
    display as error "  FAIL: r(bytes_saved) not returned"
    local ++fail_count
}

* Test 2.2: r(bytes_initial) exists
local ++test_count
display as text "Test 2.2: r(bytes_initial) returned"
if r(bytes_initial) != . & r(bytes_initial) > 0 {
    display as result "  PASS: r(bytes_initial) = `r(bytes_initial)'"
    local ++pass_count
}
else {
    display as error "  FAIL: r(bytes_initial) not returned"
    local ++fail_count
}

* Test 2.3: r(bytes_final) exists
local ++test_count
display as text "Test 2.3: r(bytes_final) returned"
if r(bytes_final) != . & r(bytes_final) > 0 {
    display as result "  PASS: r(bytes_final) = `r(bytes_final)'"
    local ++pass_count
}
else {
    display as error "  FAIL: r(bytes_final) not returned"
    local ++fail_count
}

* Test 2.4: r(pct_saved) exists
local ++test_count
display as text "Test 2.4: r(pct_saved) returned"
if r(pct_saved) != . {
    display as result "  PASS: r(pct_saved) = `r(pct_saved)'%"
    local ++pass_count
}
else {
    display as error "  FAIL: r(pct_saved) not returned"
    local ++fail_count
}

* =============================================================================
* SECTION 3: INVARIANT TESTS
* =============================================================================
display as text _n "SECTION 3: Invariant Tests" _n

* Test 3.1: bytes_saved = bytes_initial - bytes_final
local ++test_count
display as text "Test 3.1: bytes_saved = bytes_initial - bytes_final"
sysuse auto, clear
compress_tc
local diff = r(bytes_initial) - r(bytes_final)
if abs(r(bytes_saved) - `diff') < 1 {
    display as result "  PASS: Invariant holds (`r(bytes_saved)' = `=r(bytes_initial)' - `=r(bytes_final)')"
    local ++pass_count
}
else {
    display as error "  FAIL: Invariant violated"
    local ++fail_count
}

* Test 3.2: bytes_final <= bytes_initial
local ++test_count
display as text "Test 3.2: bytes_final <= bytes_initial"
if r(bytes_final) <= r(bytes_initial) {
    display as result "  PASS: `=r(bytes_final)' <= `=r(bytes_initial)'"
    local ++pass_count
}
else {
    display as error "  FAIL: bytes_final > bytes_initial"
    local ++fail_count
}

* =============================================================================
* SECTION 4: OPTIONS TESTS
* =============================================================================
display as text _n "SECTION 4: Options Tests" _n

* Test 4.1: quietly option
local ++test_count
display as text "Test 4.1: quietly option"
capture {
    sysuse auto, clear
    compress_tc, quietly
}
if _rc == 0 {
    display as result "  PASS: quietly option accepted"
    local ++pass_count
}
else {
    display as error "  FAIL: quietly option failed"
    local ++fail_count
}

* Test 4.2: nocompress option
local ++test_count
display as text "Test 4.2: nocompress option"
capture {
    sysuse auto, clear
    compress_tc, nocompress
}
if _rc == 0 {
    display as result "  PASS: nocompress option accepted"
    local ++pass_count
}
else {
    display as error "  FAIL: nocompress option failed"
    local ++fail_count
}

* Test 4.3: nostrl option
local ++test_count
display as text "Test 4.3: nostrl option"
capture {
    sysuse auto, clear
    compress_tc, nostrl
}
if _rc == 0 {
    display as result "  PASS: nostrl option accepted"
    local ++pass_count
}
else {
    display as error "  FAIL: nostrl option failed"
    local ++fail_count
}

* Test 4.4: noreport option
local ++test_count
display as text "Test 4.4: noreport option"
capture {
    sysuse auto, clear
    compress_tc, noreport
}
if _rc == 0 {
    display as result "  PASS: noreport option accepted"
    local ++pass_count
}
else {
    display as error "  FAIL: noreport option failed"
    local ++fail_count
}

* =============================================================================
* SECTION 5: VARLIST TESTS
* =============================================================================
display as text _n "SECTION 5: Varlist Tests" _n

* Test 5.1: Compress specific varlist
local ++test_count
display as text "Test 5.1: Compress specific variables"
capture {
    sysuse auto, clear
    compress_tc make
}
if _rc == 0 {
    display as result "  PASS: Varlist accepted"
    local ++pass_count
}
else {
    display as error "  FAIL: Varlist failed"
    local ++fail_count
}

* =============================================================================
* SECTION 6: EDGE CASES
* =============================================================================
display as text _n "SECTION 6: Edge Cases" _n

* Test 6.1: Dataset with no strings
local ++test_count
display as text "Test 6.1: Dataset with no strings"
capture {
    clear
    set obs 10
    gen x = _n
    gen y = runiform()
    compress_tc
}
if _rc == 0 {
    display as result "  PASS: Works with numeric-only data"
    local ++pass_count
}
else {
    display as error "  FAIL: Failed with numeric-only data"
    local ++fail_count
}

* Test 6.2: Empty dataset
local ++test_count
display as text "Test 6.2: Empty dataset"
capture {
    clear
    set obs 0
    gen str10 x = ""
    compress_tc
}
if _rc == 0 {
    display as result "  PASS: Works with empty dataset"
    local ++pass_count
}
else {
    display as error "  FAIL: Failed with empty dataset"
    local ++fail_count
}

* =============================================================================
* SECTION 7: DATA INTEGRITY
* =============================================================================
display as text _n "SECTION 7: Data Integrity" _n

* Test 7.1: Data is preserved after compression
local ++test_count
display as text "Test 7.1: Data integrity preserved"
capture {
    sysuse auto, clear
    local orig_n = _N
    local orig_make1 = make[1]
    compress_tc
    assert _N == `orig_n'
    assert make[1] == "`orig_make1'"
}
if _rc == 0 {
    display as result "  PASS: Data integrity preserved"
    local ++pass_count
}
else {
    display as error "  FAIL: Data integrity compromised"
    local ++fail_count
}

* =============================================================================
* SUMMARY
* =============================================================================
display as text _n "{hline 70}"
display as text "COMPRESS_TC VALIDATION SUMMARY"
display as text "{hline 70}"
display as text "Total tests:  `test_count'"
display as result "Passed:       `pass_count'"
if `fail_count' > 0 {
    display as error "Failed:       `fail_count'"
}
else {
    display as text "Failed:       `fail_count'"
}
display as text "{hline 70}"

if `fail_count' > 0 {
    display as error "Some validation tests FAILED."
    exit 1
}
else {
    display as result "ALL VALIDATION TESTS PASSED!"
}

display as text _n "Validation completed: `c(current_date)' `c(current_time)'"
display as text "{hline 70}"
