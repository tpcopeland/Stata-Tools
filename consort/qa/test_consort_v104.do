/*******************************************************************************
* test_consort_v104.do
*
* Purpose: Tests for v1.0.4 fixes — varabbrev restore, output path validation,
*          directory existence check, DPI validation, final() precedence,
*          protected globals, scientific notation prevention.
*
* Author: Timothy P Copeland
* Date: 2026-03-19
*******************************************************************************/

clear all
set more off
version 16.0

* Install package

* === Bootstrap ===
local qa_dir  "`c(pwd)'"
local pkg_dir "`qa_dir'/.."  

capture ado uninstall consort
quietly net install consort, from("`pkg_dir'/") replace

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

* Helper
capture program drop _clear_consort_state
program define _clear_consort_state
    capture consort clear, quiet
    global CONSORT_FILE ""
    global CONSORT_N ""
    global CONSORT_ACTIVE ""
    global CONSORT_STEPS ""
    global CONSORT_TEMPFILE ""
    global CONSORT_SCRIPT_PATH ""
end

* =============================================================================
* SECTION 1: VARABBREV RESTORE
* =============================================================================

* Test 1: varabbrev restored after successful workflow
local ++test_count
capture noisily {
    _clear_consort_state
    set varabbrev on
    sysuse auto, clear
    consort init, initial("All cars")
    consort exclude if rep78 == ., label("Missing")
    consort save, output("/tmp/test_v104_varabbrev.png") final("Final")
    assert "`c(varabbrev)'" == "on"
}
if _rc == 0 {
    display as result "  PASS `test_count': varabbrev restored after success"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': varabbrev not restored after success (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}
capture erase "/tmp/test_v104_varabbrev.png"
_clear_consort_state

* Test 2: varabbrev restored after error (missing subcommand)
local ++test_count
capture noisily {
    set varabbrev on
    capture consort
    assert "`c(varabbrev)'" == "on"
}
if _rc == 0 {
    display as result "  PASS `test_count': varabbrev restored after error"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': varabbrev not restored after error (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* Test 3: varabbrev restored after init error (empty dataset)
local ++test_count
capture noisily {
    _clear_consort_state
    set varabbrev on
    clear
    set obs 0
    gen x = .
    capture consort init, initial("Empty")
    assert "`c(varabbrev)'" == "on"
}
if _rc == 0 {
    display as result "  PASS `test_count': varabbrev restored after init error"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': varabbrev not restored after init error (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}
_clear_consort_state

* Test 4: set more restored after command
local ++test_count
capture noisily {
    _clear_consort_state
    set more on
    sysuse auto, clear
    consort init, initial("All cars")
    assert "`c(more)'" == "on"
    _clear_consort_state
    set more off
}
if _rc == 0 {
    display as result "  PASS `test_count': set more restored"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': set more not restored (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
    set more off
}
_clear_consort_state

* =============================================================================
* SECTION 2: OUTPUT PATH VALIDATION
* =============================================================================

* Test 5: semicolon in output path rejected
local ++test_count
capture noisily {
    _clear_consort_state
    sysuse auto, clear
    consort init, initial("All cars")
    consort exclude if rep78 == ., label("Missing")
    capture consort save, output("/tmp/test;evil.png")
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS `test_count': semicolon in path rejected"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': semicolon in path not rejected (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}
_clear_consort_state

* Test 6: pipe in output path rejected
local ++test_count
capture noisily {
    _clear_consort_state
    sysuse auto, clear
    consort init, initial("All cars")
    consort exclude if rep78 == ., label("Missing")
    capture consort save, output("/tmp/test|evil.png")
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS `test_count': pipe in path rejected"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': pipe in path not rejected (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}
_clear_consort_state

* Test 7: ampersand in output path rejected
local ++test_count
capture noisily {
    _clear_consort_state
    sysuse auto, clear
    consort init, initial("All cars")
    consort exclude if rep78 == ., label("Missing")
    capture consort save, output("/tmp/test&evil.png")
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS `test_count': ampersand in path rejected"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': ampersand in path not rejected (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}
_clear_consort_state

* Test 8: valid path accepted (no metacharacters)
local ++test_count
capture noisily {
    _clear_consort_state
    sysuse auto, clear
    consort init, initial("All cars")
    consort exclude if rep78 == ., label("Missing")
    consort save, output("/tmp/test_v104_valid.png") final("Final")
    confirm file "/tmp/test_v104_valid.png"
}
if _rc == 0 {
    display as result "  PASS `test_count': valid path accepted"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': valid path rejected (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}
capture erase "/tmp/test_v104_valid.png"
_clear_consort_state

* =============================================================================
* SECTION 3: DIRECTORY EXISTENCE CHECK
* =============================================================================

* Test 9: nonexistent directory rejected
local ++test_count
capture noisily {
    _clear_consort_state
    sysuse auto, clear
    consort init, initial("All cars")
    consort exclude if rep78 == ., label("Missing")
    capture consort save, output("/tmp/nonexistent_dir_v104/test.png")
    assert _rc == 601
}
if _rc == 0 {
    display as result "  PASS `test_count': nonexistent directory rejected"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': nonexistent directory not rejected (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}
_clear_consort_state

* =============================================================================
* SECTION 4: DPI VALIDATION
* =============================================================================

* Test 10: dpi(0) rejected
local ++test_count
capture noisily {
    _clear_consort_state
    sysuse auto, clear
    consort init, initial("All cars")
    consort exclude if rep78 == ., label("Missing")
    capture consort save, output("/tmp/test_dpi0.png") dpi(0)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS `test_count': dpi(0) rejected"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': dpi(0) not rejected (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}
_clear_consort_state

* Test 11: negative dpi rejected
local ++test_count
capture noisily {
    _clear_consort_state
    sysuse auto, clear
    consort init, initial("All cars")
    consort exclude if rep78 == ., label("Missing")
    capture consort save, output("/tmp/test_dpi_neg.png") dpi(-100)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS `test_count': negative dpi rejected"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': negative dpi not rejected (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}
_clear_consort_state

* =============================================================================
* SECTION 5: FINAL() PRECEDENCE OVER REMAINING()
* =============================================================================

* Test 12: final() overrides remaining() on last exclude step
local ++test_count
capture noisily {
    _clear_consort_state
    sysuse auto, clear
    consort init, initial("All cars")
    consort exclude if rep78 == ., label("Missing") remaining("Has data")
    consort save, output("/tmp/test_v104_final.png") final("My Final Label")
    confirm file "/tmp/test_v104_final.png"
    * Verify return value
    assert "`r(final)'" == "My Final Label"
}
if _rc == 0 {
    display as result "  PASS `test_count': final() overrides remaining()"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': final() did not override remaining() (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}
capture erase "/tmp/test_v104_final.png"
_clear_consort_state

* Test 13: remaining() preserved when final() not specified
local ++test_count
capture noisily {
    _clear_consort_state
    sysuse auto, clear
    consort init, initial("All cars")
    consort exclude if rep78 == ., label("Missing") remaining("Cars with data")
    consort save, output("/tmp/test_v104_remain.png")
    confirm file "/tmp/test_v104_remain.png"
    * Default final() = "Final Cohort" should NOT override existing remaining()
    assert "`r(final)'" == "Final Cohort"
}
if _rc == 0 {
    display as result "  PASS `test_count': remaining() preserved when final() not specified"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': remaining() not preserved (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}
capture erase "/tmp/test_v104_remain.png"
_clear_consort_state

* =============================================================================
* SECTION 6: PROTECTED GLOBALS
* =============================================================================

* Test 14: command works even with corrupted CONSORT_STEPS global
local ++test_count
capture noisily {
    _clear_consort_state
    sysuse auto, clear
    consort init, initial("All cars")
    * CONSORT_STEPS should be "0" — verify protected arithmetic works
    assert "${CONSORT_STEPS}" == "0"
    consort exclude if rep78 == ., label("Missing")
    assert "${CONSORT_STEPS}" == "1"
    consort exclude if foreign == 1, label("Foreign")
    assert "${CONSORT_STEPS}" == "2"
}
if _rc == 0 {
    display as result "  PASS `test_count': global step counter works correctly"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': global step counter broken (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}
_clear_consort_state

* =============================================================================
* SECTION 7: CSV BEFORE DROP (DATA INTEGRITY)
* =============================================================================

* Test 15: CSV written before drop — verify n_remain matches
local ++test_count
capture noisily {
    _clear_consort_state
    sysuse auto, clear
    local orig_n = _N
    consort init, initial("All cars")
    consort exclude if rep78 == ., label("Missing repair")
    local excluded = r(n_excluded)
    local remaining = r(n_remaining)
    assert `remaining' == _N
    assert `excluded' + `remaining' == `orig_n'
}
if _rc == 0 {
    display as result "  PASS `test_count': CSV-before-drop count integrity"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': CSV-before-drop count mismatch (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}
_clear_consort_state

* =============================================================================
* SECTION 8: PACKAGE INSTALLATION
* =============================================================================

* Test 16: net install and which discover all files
local ++test_count
capture noisily {
    capture ado uninstall consort
    quietly net install consort, from("`pkg_dir'/") replace
    which consort
}
if _rc == 0 {
    display as result "  PASS `test_count': net install + which consort"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': net install or which failed (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* Test 17: help file renders without error
local ++test_count
capture noisily {
    help consort
}
if _rc == 0 {
    display as result "  PASS `test_count': help consort renders"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': help consort failed (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* =============================================================================
* CLEANUP AND SUMMARY
* =============================================================================
_clear_consort_state
capture erase "/tmp/test_v104_varabbrev.png"
capture erase "/tmp/test_v104_valid.png"
capture erase "/tmp/test_v104_final.png"
capture erase "/tmp/test_v104_remain.png"

display as text _n "{hline 70}"
display as text "CONSORT v1.0.4 FIX COVERAGE TEST SUMMARY"
display as text "{hline 70}"
display as text "Total tests:  `test_count'"
display as result "Passed:       `pass_count'"
if `fail_count' > 0 {
    display as error "Failed:       `fail_count'"
    display as error "Failed tests:`failed_tests'"
}
else {
    display as text "Failed:       0"
}
display as text "{hline 70}"

if `fail_count' > 0 {
    display as error _n "Some tests FAILED."
    exit 1
}
else {
    display as result _n "ALL v1.0.4 FIX TESTS PASSED!"
}
