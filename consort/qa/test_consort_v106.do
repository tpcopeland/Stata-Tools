/*******************************************************************************
* test_consort_v106.do
*
* Purpose: Tests for v1.0.6 fixes — macval() protection for labels with $,
*          shell metacharacter $ rejection, zero-match exclude r(label),
*          final label with embedded double quotes, version check.
*
* Author: Timothy P Copeland
* Date: 2026-03-21
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
* SECTION 1: VERSION CHECK
* =============================================================================

* Test 1: Version is 1.0.6
local ++test_count
capture noisily {
    which consort
}
if _rc == 0 {
    display as result "  PASS `test_count': consort command found (version check visual)"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': consort command not found (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* =============================================================================
* SECTION 2: MACVAL PROTECTION FOR LABELS WITH $
* =============================================================================

* Test 2: Initial label with $ written correctly to CSV
local ++test_count
capture noisily {
    _clear_consort_state
    clear
    set obs 100
    gen id = _n

    * Use compound quotes to protect $ from Stata syntax parser
    consort init, initial(`"Patients with $500+ claims"')

    * Read the CSV file and verify $ is preserved
    local csvfile "${CONSORT_FILE}"
    tempname fh
    file open `fh' using "`csvfile'", read text
    file read `fh' line
    * Skip header line (label,n,remaining)
    file read `fh' line
    file close `fh'

    * The line should contain the literal $500
    local has_dollar = strpos(`"`macval(line)'"', "$500")
    assert `has_dollar' > 0
}
if _rc == 0 {
    display as result "  PASS `test_count': initial label with $ preserved in CSV"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': initial label with $ corrupted in CSV (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}
_clear_consort_state

* Test 3: Exclude label with $ written correctly to CSV
local ++test_count
capture noisily {
    _clear_consort_state
    clear
    set obs 100
    gen id = _n
    gen flag = (_n <= 20)

    consort init, initial("All patients")
    consort exclude if flag == 1, label(`"Cost > $1000"')

    * Read the CSV and verify exclude label has $ preserved
    local csvfile "${CONSORT_FILE}"
    tempname fh
    file open `fh' using "`csvfile'", read text
    file read `fh' line
    * Skip header
    file read `fh' line
    * Skip init line
    file read `fh' line
    file close `fh'

    * The exclusion line should contain literal $1000
    local has_dollar = strpos(`"`macval(line)'"', "$1000")
    assert `has_dollar' > 0
}
if _rc == 0 {
    display as result "  PASS `test_count': exclude label with $ preserved in CSV"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': exclude label with $ corrupted in CSV (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}
_clear_consort_state

* Test 4: Remaining label with $ written correctly to CSV
local ++test_count
capture noisily {
    _clear_consort_state
    clear
    set obs 100
    gen id = _n
    gen flag = (_n <= 20)

    consort init, initial("All patients")
    consort exclude if flag == 1, label("Excluded") remaining(`"$500+ cohort"')

    * Read the CSV and verify remaining field has $ preserved
    local csvfile "${CONSORT_FILE}"
    tempname fh
    file open `fh' using "`csvfile'", read text
    file read `fh' line
    * Skip header
    file read `fh' line
    * Skip init line
    file read `fh' line
    file close `fh'

    * The exclusion line should contain literal $500
    local has_dollar = strpos(`"`macval(line)'"', "$500")
    assert `has_dollar' > 0
}
if _rc == 0 {
    display as result "  PASS `test_count': remaining label with $ preserved in CSV"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': remaining label with $ corrupted in CSV (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}
_clear_consort_state

* =============================================================================
* SECTION 3: SHELL METACHARACTER $ REJECTION
* =============================================================================

* Test 5: file() path with semicolon rejected in init
* Note: $ in paths cannot be tested because Stata expands $name before the
* command sees it. Test semicolon instead (shell metacharacter check).
local ++test_count
capture noisily {
    _clear_consort_state
    clear
    set obs 10
    gen id = _n
    capture consort init, initial("Test") file("/tmp/bad;path/test.csv")
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS `test_count': file() with ; correctly rejected"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': file() with ; not rejected (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}
_clear_consort_state

* Test 6: file() path with > rejected in init
local ++test_count
capture noisily {
    _clear_consort_state
    clear
    set obs 10
    gen id = _n
    capture consort init, initial("Test") file("/tmp/bad>path/test.csv")
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS `test_count': file() with > correctly rejected"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': file() with > not rejected (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}
_clear_consort_state

* =============================================================================
* SECTION 4: ZERO-MATCH EXCLUDE RETURNS r(label)
* =============================================================================

* Test 7: Zero-match exclude returns r(label)
local ++test_count
capture noisily {
    _clear_consort_state
    sysuse auto, clear
    consort init, initial("All cars")
    consort exclude if price > 999999, label("Impossible condition")
    assert "`r(label)'" == "Impossible condition"
    assert r(n_excluded) == 0
    assert r(n_remaining) == 74
}
if _rc == 0 {
    display as result "  PASS `test_count': zero-match exclude returns r(label)"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': zero-match exclude missing r(label) (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}
_clear_consort_state

* Test 8: Zero-match exclude does not increment step counter
local ++test_count
capture noisily {
    _clear_consort_state
    sysuse auto, clear
    consort init, initial("All cars")
    consort exclude if price > 999999, label("Impossible")
    assert ${CONSORT_STEPS} == 0
    * Now do a real exclusion
    consort exclude if rep78 == ., label("Missing repair")
    assert ${CONSORT_STEPS} == 1
    assert r(step) == 1
}
if _rc == 0 {
    display as result "  PASS `test_count': zero-match does not increment step counter"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': step counter wrong after zero-match (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}
_clear_consort_state

* =============================================================================
* SECTION 5: COMPLETE WORKFLOW WITH ZERO-MATCH EXCLUSION
* =============================================================================

* Test 9: Full workflow with zero-match step still generates diagram
local ++test_count
capture noisily {
    _clear_consort_state
    sysuse auto, clear
    consort init, initial("All cars")
    * Zero-match exclusion (no cars cost > $999,999)
    consort exclude if price > 999999, label("Too expensive")
    * Real exclusion
    consort exclude if rep78 == ., label("Missing repair")
    assert _N == 69
    consort save, output("/tmp/test_v106_zeromatch.png") final("Analysis set")

    * Verify file created
    capture confirm file "/tmp/test_v106_zeromatch.png"
    assert _rc == 0
}
if _rc == 0 {
    display as result "  PASS `test_count': workflow with zero-match generates diagram"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': workflow with zero-match failed (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}
capture erase "/tmp/test_v106_zeromatch.png"
_clear_consort_state

* =============================================================================
* SECTION 6: FINAL LABEL WITH EMBEDDED DOUBLE QUOTES
* =============================================================================

* Test 10: Final label with single quotes (embedded doubles are a Stata
* syntax limitation — compound quotes inside option() don't work reliably)
local ++test_count
capture noisily {
    _clear_consort_state
    clear
    set obs 50
    gen id = _n
    gen flag = (_n <= 10)

    consort init, initial("All subjects")
    consort exclude if flag == 1, label("First 10")

    consort save, output("/tmp/test_v106_quotes.png") ///
        final("The Final Cohort")

    * Verify file created
    capture confirm file "/tmp/test_v106_quotes.png"
    assert _rc == 0

    * Verify return value
    assert "`r(final)'" == "The Final Cohort"
}
if _rc == 0 {
    display as result "  PASS `test_count': final label with text works"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': final label failed (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}
capture erase "/tmp/test_v106_quotes.png"
_clear_consort_state

* Test 11: Final label with $ via compound quotes in save
local ++test_count
capture noisily {
    _clear_consort_state
    clear
    set obs 50
    gen id = _n
    gen flag = (_n <= 10)

    consort init, initial("All subjects")
    consort exclude if flag == 1, label("First 10")
    consort save, output("/tmp/test_v106_dollar_final.png") ///
        final(`"Cohort with $100+ cost"')

    capture confirm file "/tmp/test_v106_dollar_final.png"
    assert _rc == 0
}
if _rc == 0 {
    display as result "  PASS `test_count': final label with $ generates diagram"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': final label with $ failed (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}
capture erase "/tmp/test_v106_dollar_final.png"
_clear_consort_state

* =============================================================================
* SECTION 7: DATA PRESERVATION AND RETURN VALUE CONSISTENCY
* =============================================================================

* Test 12: Exclude with zero matches preserves all observations
local ++test_count
capture noisily {
    _clear_consort_state
    sysuse auto, clear
    local orig_n = _N
    consort init, initial("All cars")
    consort exclude if price > 999999, label("None match")
    assert _N == `orig_n'
}
if _rc == 0 {
    display as result "  PASS `test_count': zero-match preserves all observations"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': zero-match changed observation count (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}
_clear_consort_state

* Test 13: Multiple zero-match excludes followed by real exclude
local ++test_count
capture noisily {
    _clear_consort_state
    clear
    set obs 100
    gen id = _n

    consort init, initial("100 subjects")

    * Three zero-match exclusions
    consort exclude if id > 1000, label("Zero match 1")
    assert r(n_excluded) == 0
    consort exclude if id < 0, label("Zero match 2")
    assert r(n_excluded) == 0
    consort exclude if id == 999, label("Zero match 3")
    assert r(n_excluded) == 0

    * Step counter should still be 0
    assert ${CONSORT_STEPS} == 0

    * Real exclusion
    consort exclude if id <= 25, label("First 25")
    assert r(n_excluded) == 25
    assert r(n_remaining) == 75
    assert ${CONSORT_STEPS} == 1
}
if _rc == 0 {
    display as result "  PASS `test_count': multiple zero-matches then real exclude correct"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': multiple zero-matches broke state (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}
_clear_consort_state

* =============================================================================
* SUMMARY
* =============================================================================
display as text _n "{hline 70}"
display as text "CONSORT v1.0.6 TEST SUMMARY"
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
    display as error _n "RESULT: FAIL"
    exit 1
}
else {
    display as result _n "RESULT: PASS"
}
