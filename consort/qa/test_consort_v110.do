/*******************************************************************************
* test_consort_v110.do
*
* Purpose: Regression tests for v1.1.0 — the csv() and xlsx() data-export
*          options on `consort save`. Covers option combinations, resolved-
*          table known-answer correctness, percentage formatting, RFC-4180
*          round-trip of labels containing commas, fail-fast path validation
*          with state preservation + re-runnability, r(csv)/r(xlsx) returns,
*          and user data/frame integrity after export.
*
* Author: Timothy P Copeland
* Date: 2026-06-24
*******************************************************************************/

clear all
set more off
version 16.0

* === Bootstrap ===
local qa_dir  "`c(pwd)'"
local pkg_dir "`qa_dir'/.."

capture ado uninstall consort
quietly net install consort, from("`pkg_dir'/") replace

* Scratch output directory (relocatable, cleaned at end)
local out "`c(tmpdir)'/consort_v110_`c(pid)'"
capture mkdir "`out'"

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

* Helper: hard-reset diagram state between tests
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

* Helper: build the canonical known-answer diagram to `save'-ready state.
* auto: 74 obs; missing(rep78) drops 5 -> 69; foreign drops 21 -> 48.
capture program drop _build_known
program define _build_known
    sysuse auto, clear
    consort init, initial("Cars in auto.dta")
    consort exclude if missing(rep78), label("Missing repair record") ///
        remaining("Cars with repair data")
    consort exclude if foreign, label("Foreign cars")
end

**# SECTION 1: option combinations (neither / csv / xlsx / both)

* Test 1: neither option -> figure only, no data returns
local ++test_count
capture noisily {
    _clear_consort_state
    _build_known
    consort save, output("`out'/t1.png")
    assert "`r(csv)'" == "" & "`r(xlsx)'" == ""
    capture confirm file "`out'/t1.png"
    assert _rc == 0
}
if _rc == 0 {
    display as result "  PASS `test_count': neither option (figure only)"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': neither option (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}
_clear_consort_state

* Test 2: csv() only
local ++test_count
capture noisily {
    _build_known
    consort save, output("`out'/t2.png") csv("`out'/t2.csv")
    assert "`r(csv)'" == "`out'/t2.csv"
    assert "`r(xlsx)'" == ""
    capture confirm file "`out'/t2.csv"
    assert _rc == 0
}
if _rc == 0 {
    display as result "  PASS `test_count': csv() only"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': csv() only (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}
_clear_consort_state

* Test 3: xlsx() only
local ++test_count
capture noisily {
    _build_known
    consort save, output("`out'/t3.png") xlsx("`out'/t3.xlsx")
    assert "`r(xlsx)'" == "`out'/t3.xlsx"
    assert "`r(csv)'" == ""
    capture confirm file "`out'/t3.xlsx"
    assert _rc == 0
}
if _rc == 0 {
    display as result "  PASS `test_count': xlsx() only"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': xlsx() only (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}
_clear_consort_state

* Test 4: both csv() and xlsx(), returns both
local ++test_count
capture noisily {
    _build_known
    consort save, output("`out'/t4.png") final("Domestic sample") ///
        csv("`out'/t4.csv") xlsx("`out'/t4.xlsx")
    assert "`r(csv)'"  == "`out'/t4.csv"
    assert "`r(xlsx)'" == "`out'/t4.xlsx"
    capture confirm file "`out'/t4.csv"
    assert _rc == 0
    capture confirm file "`out'/t4.xlsx"
    assert _rc == 0
}
if _rc == 0 {
    display as result "  PASS `test_count': both csv() and xlsx()"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': both csv() and xlsx() (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}
* keep t4.csv/t4.xlsx for the next section -> do NOT clear yet
_clear_consort_state

**# SECTION 2: resolved-table known-answer correctness (CSV)

* Test 5: every cell of the resolved CSV matches the hand-computed cohort.
* Read with stringcols(_all) so the exact text (incl. "100.00", empty
* n_excluded on the initial row) is asserted verbatim.
local ++test_count
capture noisily {
    import delimited using "`out'/t4.csv", varnames(1) ///
        bindquote(strict) stringcols(_all) clear
    assert _N == 3
    * All six resolved columns present
    foreach v in step cohort_label n_remaining exclusion_label n_excluded pct_of_initial {
        capture confirm variable `v'
        assert _rc == 0
    }
    * Row 0 (initial population)
    assert step[1]            == "0"
    assert cohort_label[1]    == "Cars in auto.dta"
    assert n_remaining[1]     == "74"
    assert exclusion_label[1] == ""
    assert n_excluded[1]      == ""
    assert pct_of_initial[1]  == "100.00"
    * Row 1 (first exclusion)
    assert step[2]            == "1"
    assert cohort_label[2]    == "Cars with repair data"
    assert n_remaining[2]     == "69"
    assert exclusion_label[2] == "Missing repair record"
    assert n_excluded[2]      == "5"
    assert pct_of_initial[2]  == "93.24"
    * Row 2 (final exclusion, final() label lands in cohort_label)
    assert step[3]            == "2"
    assert cohort_label[3]    == "Domestic sample"
    assert n_remaining[3]     == "48"
    assert exclusion_label[3] == "Foreign cars"
    assert n_excluded[3]      == "21"
    assert pct_of_initial[3]  == "64.86"
}
if _rc == 0 {
    display as result "  PASS `test_count': resolved CSV known-answer (all cells)"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': resolved CSV known-answer (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* Test 6: XLSX carries identical resolved content (key cells)
local ++test_count
capture noisily {
    import excel using "`out'/t4.xlsx", firstrow allstring clear
    assert _N == 3
    assert step[1]           == "0"
    assert cohort_label[1]   == "Cars in auto.dta"
    assert pct_of_initial[1] == "100.00"
    assert cohort_label[3]   == "Domestic sample"
    assert n_remaining[3]    == "48"
    assert n_excluded[3]     == "21"
    assert pct_of_initial[3] == "64.86"
}
if _rc == 0 {
    display as result "  PASS `test_count': resolved XLSX matches CSV content"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': resolved XLSX content (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

**# SECTION 3: RFC-4180 round-trip (labels containing commas)

* Test 7: labels with commas are quoted and parse back losslessly
local ++test_count
capture noisily {
    _clear_consort_state
    sysuse auto, clear
    consort init, initial("All cars, 1978")
    consort exclude if missing(rep78), label("Missing rep78, any year") ///
        remaining("Cohort A, trimmed")
    consort exclude if foreign, label("Foreign cars")
    consort save, output("`out'/t7.png") final("Final, analytic set") ///
        csv("`out'/t7.csv")
    import delimited using "`out'/t7.csv", varnames(1) ///
        bindquote(strict) stringcols(_all) clear
    assert _N == 3
    assert cohort_label[1]    == "All cars, 1978"
    assert cohort_label[2]    == "Cohort A, trimmed"
    assert exclusion_label[2] == "Missing rep78, any year"
    assert cohort_label[3]    == "Final, analytic set"
}
if _rc == 0 {
    display as result "  PASS `test_count': comma-laden labels round-trip (RFC-4180)"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': comma label round-trip (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}
_clear_consort_state

**# SECTION 4: fail-fast path validation, state preserved, re-runnable

* Test 8: bad csv() directory -> rc 601, figure NOT generated, state intact,
*         then a valid re-run succeeds.
local ++test_count
capture noisily {
    _clear_consort_state
    _build_known
    capture consort save, output("`out'/t8.png") csv("`out'/nodir_xyz/t8.csv")
    assert _rc == 601
    * Figure must not have been generated (validation fails before render)
    capture confirm file "`out'/t8.png"
    assert _rc != 0
    * State must be preserved so the workflow is re-runnable
    assert "${CONSORT_ACTIVE}" == "1"
    * Re-run with a valid path now succeeds
    consort save, output("`out'/t8.png") csv("`out'/t8.csv")
    assert _rc == 0
    capture confirm file "`out'/t8.png"
    assert _rc == 0
    capture confirm file "`out'/t8.csv"
    assert _rc == 0
}
if _rc == 0 {
    display as result "  PASS `test_count': bad dir fails fast, state preserved, re-runnable"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': bad-dir fail-fast (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}
_clear_consort_state

* Test 9: bad xlsx() directory likewise rejected with rc 601
local ++test_count
capture noisily {
    _build_known
    capture consort save, output("`out'/t9.png") xlsx("`out'/nodir_xyz/t9.xlsx")
    assert _rc == 601
    assert "${CONSORT_ACTIVE}" == "1"
}
if _rc == 0 {
    display as result "  PASS `test_count': bad xlsx() dir rejected (rc 601)"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': bad xlsx() dir (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}
_clear_consort_state

* Test 10: csv() path with a shell metacharacter -> rc 198, figure NOT
*          generated (rejected before render), state intact, re-runnable.
local ++test_count
capture noisily {
    _build_known
    capture consort save, output("`out'/t10a.png") csv("`out'/bad;name.csv")
    assert _rc == 198
    * Rejected before the figure renders
    capture confirm file "`out'/t10a.png"
    assert _rc != 0
    * State preserved -> workflow re-runnable with a valid path
    assert "${CONSORT_ACTIVE}" == "1"
    consort save, output("`out'/t10a.png") csv("`out'/t10a.csv")
    assert _rc == 0
    capture confirm file "`out'/t10a.csv"
    assert _rc == 0
}
if _rc == 0 {
    display as result "  PASS `test_count': invalid-char csv() rejected (rc 198), re-runnable"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': invalid-char csv() (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}
_clear_consort_state

* Test 11: xlsx() path with a shell metacharacter likewise rejected (rc 198),
*          state preserved. Uses a different metacharacter (|) than test 10.
local ++test_count
capture noisily {
    _build_known
    capture consort save, output("`out'/t11.png") xlsx("`out'/bad|name.xlsx")
    assert _rc == 198
    capture confirm file "`out'/t11.png"
    assert _rc != 0
    assert "${CONSORT_ACTIVE}" == "1"
}
if _rc == 0 {
    display as result "  PASS `test_count': invalid-char xlsx() rejected (rc 198)"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': invalid-char xlsx() (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}
_clear_consort_state

**# SECTION 5: user data + frame integrity after export

* Test 10: active dataset, frame, and frame count are untouched by the export
local ++test_count
capture noisily {
    sysuse auto, clear
    local n0 = _N
    local frame0 "`c(frame)'"
    local nframes0 = .
    capture mata: st_local("nframes0", strofreal(st_nframes()))
    preserve
    consort init, initial("Cars")
    consort exclude if foreign, label("Foreign")
    consort save, output("`out'/t10.png") csv("`out'/t10.csv") xlsx("`out'/t10.xlsx")
    restore
    * Data intact
    assert _N == `n0'
    * Active frame unchanged (export ran in a separate, dropped frame)
    assert "`c(frame)'" == "`frame0'"
    * No leaked frame (only when st_nframes() is available)
    if "`nframes0'" != "." & "`nframes0'" != "" {
        capture mata: st_local("nframes1", strofreal(st_nframes()))
        assert `nframes1' == `nframes0'
    }
}
if _rc == 0 {
    display as result "  PASS `test_count': user data + frame untouched after export"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': data/frame integrity (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}
_clear_consort_state

**# Cleanup scratch output
capture erase "`out'/t1.png"
capture erase "`out'/t10a.png"
capture erase "`out'/t10a.csv"
foreach f in t2 t3 t4 t7 t8 t9 t10 t11 {
    capture erase "`out'/`f'.png"
    capture erase "`out'/`f'.csv"
    capture erase "`out'/`f'.xlsx"
}
capture rmdir "`out'"

**# SUMMARY
display as text _n "{hline 70}"
display as text "CONSORT v1.1.0 (csv/xlsx export) TEST SUMMARY"
display as text "{hline 70}"
display as text   "Total tests:  `test_count'"
display as result "Passed:       `pass_count'"
if `fail_count' > 0 {
    display as error "Failed:       `fail_count'"
    display as error "Failed tests:`failed_tests'"
}
else {
    display as text "Failed:       `fail_count'"
}
display as text "{hline 70}"

display "RESULT: test_consort_v110 tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 {
    display as error _n "RESULT: FAIL"
    exit 1
}
display as result _n "RESULT: PASS"
