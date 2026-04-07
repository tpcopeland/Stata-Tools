/*******************************************************************************
* test_consort_expanded.do
*
* Purpose: Expanded functional tests for consort command — fills coverage gaps
*          in save return values, option combinations, label edge cases,
*          missing data handling, reproducibility, state management, error
*          paths, and boundary conditions.
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

* Helper: clear consort state
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
* SECTION 1: SAVE RETURN VALUES
* =============================================================================

* Test 1: r(N_initial) equals initial count
local ++test_count
capture noisily {
    _clear_consort_state
    sysuse auto, clear
    consort init, initial("All cars")
    consort exclude if rep78 == ., label("Missing repair")
    consort save, output("/tmp/test_exp_s1.png") final("Final")
    assert r(N_initial) == 74
}
if _rc == 0 {
    display as result "  PASS `test_count': r(N_initial) equals initial count"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': r(N_initial) (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}
capture erase "/tmp/test_exp_s1.png"
_clear_consort_state

* Test 2: r(N_final) equals final count
local ++test_count
capture noisily {
    _clear_consort_state
    sysuse auto, clear
    consort init, initial("All cars")
    consort exclude if rep78 == ., label("Missing repair")
    consort save, output("/tmp/test_exp_s2.png") final("Final")
    assert r(N_final) == 69
}
if _rc == 0 {
    display as result "  PASS `test_count': r(N_final) equals final count"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': r(N_final) (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}
capture erase "/tmp/test_exp_s2.png"
_clear_consort_state

* Test 3: r(N_excluded) equals total excluded
local ++test_count
capture noisily {
    _clear_consort_state
    sysuse auto, clear
    consort init, initial("All cars")
    consort exclude if rep78 == ., label("Missing repair")
    consort exclude if foreign == 1, label("Foreign")
    consort save, output("/tmp/test_exp_s3.png") final("Final")
    * 5 missing + some foreign from remaining 69
    assert r(N_excluded) == 74 - _N
}
if _rc == 0 {
    display as result "  PASS `test_count': r(N_excluded) equals total excluded"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': r(N_excluded) (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}
capture erase "/tmp/test_exp_s3.png"
_clear_consort_state

* Test 4: r(steps) equals number of exclusion steps
local ++test_count
capture noisily {
    _clear_consort_state
    sysuse auto, clear
    consort init, initial("All cars")
    consort exclude if rep78 == ., label("Missing")
    consort exclude if foreign == 1, label("Foreign")
    consort exclude if price > 10000, label("Expensive")
    consort save, output("/tmp/test_exp_s4.png") final("Final")
    assert r(steps) == 3
}
if _rc == 0 {
    display as result "  PASS `test_count': r(steps) equals exclusion count"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': r(steps) (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}
capture erase "/tmp/test_exp_s4.png"
_clear_consort_state

* Test 5: r(output) returns the output path
local ++test_count
capture noisily {
    _clear_consort_state
    sysuse auto, clear
    consort init, initial("All cars")
    consort exclude if rep78 == ., label("Missing")
    consort save, output("/tmp/test_exp_s5.png") final("Final")
    assert "`r(output)'" == "/tmp/test_exp_s5.png"
}
if _rc == 0 {
    display as result "  PASS `test_count': r(output) returns output path"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': r(output) (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}
capture erase "/tmp/test_exp_s5.png"
_clear_consort_state

* Test 6: r(final) returns the final label
local ++test_count
capture noisily {
    _clear_consort_state
    sysuse auto, clear
    consort init, initial("All cars")
    consort exclude if rep78 == ., label("Missing")
    consort save, output("/tmp/test_exp_s6.png") final("My Custom Final")
    assert "`r(final)'" == "My Custom Final"
}
if _rc == 0 {
    display as result "  PASS `test_count': r(final) returns final label"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': r(final) (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}
capture erase "/tmp/test_exp_s6.png"
_clear_consort_state

* Test 7: Conservation: r(N_initial) = r(N_final) + r(N_excluded)
local ++test_count
capture noisily {
    _clear_consort_state
    sysuse auto, clear
    consort init, initial("All cars")
    consort exclude if rep78 == ., label("Missing")
    consort exclude if foreign == 1, label("Foreign")
    consort save, output("/tmp/test_exp_s7.png") final("Final")
    assert r(N_initial) == r(N_final) + r(N_excluded)
}
if _rc == 0 {
    display as result "  PASS `test_count': r(N_initial) = r(N_final) + r(N_excluded)"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': conservation (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}
capture erase "/tmp/test_exp_s7.png"
_clear_consort_state

* =============================================================================
* SECTION 2: OPTION COMBINATIONS
* =============================================================================

* Test 8: save with shading + dpi combined
local ++test_count
capture noisily {
    _clear_consort_state
    sysuse auto, clear
    consort init, initial("All cars")
    consort exclude if rep78 == ., label("Missing")
    consort save, output("/tmp/test_exp_o1.png") shading dpi(200)
    confirm file "/tmp/test_exp_o1.png"
}
if _rc == 0 {
    display as result "  PASS `test_count': save with shading + dpi combined"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': shading + dpi (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}
capture erase "/tmp/test_exp_o1.png"
_clear_consort_state

* Test 9: save with shading + final combined
local ++test_count
capture noisily {
    _clear_consort_state
    sysuse auto, clear
    consort init, initial("All cars")
    consort exclude if rep78 == ., label("Missing")
    consort save, output("/tmp/test_exp_o2.png") shading final("Shaded Final")
    confirm file "/tmp/test_exp_o2.png"
    assert "`r(final)'" == "Shaded Final"
}
if _rc == 0 {
    display as result "  PASS `test_count': save with shading + final combined"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': shading + final (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}
capture erase "/tmp/test_exp_o2.png"
_clear_consort_state

* Test 10: save with all options: final + shading + dpi
local ++test_count
capture noisily {
    _clear_consort_state
    sysuse auto, clear
    consort init, initial("All cars")
    consort exclude if rep78 == ., label("Missing")
    consort save, output("/tmp/test_exp_o3.png") final("All Options") shading dpi(300)
    confirm file "/tmp/test_exp_o3.png"
    assert "`r(final)'" == "All Options"
    assert r(steps) == 1
}
if _rc == 0 {
    display as result "  PASS `test_count': save with all options combined"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': all options (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}
capture erase "/tmp/test_exp_o3.png"
_clear_consort_state

* Test 11: Multiple exclude steps with mix of remaining() and without
local ++test_count
capture noisily {
    _clear_consort_state
    sysuse auto, clear
    consort init, initial("All cars")
    consort exclude if rep78 == ., label("Missing") remaining("Has repair data")
    consort exclude if foreign == 1, label("Foreign")
    consort exclude if price > 10000, label("Expensive") remaining("Affordable domestic")
    consort save, output("/tmp/test_exp_o4.png") final("Study cohort")
    confirm file "/tmp/test_exp_o4.png"
    assert r(steps) == 3
}
if _rc == 0 {
    display as result "  PASS `test_count': mixed remaining() and without"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': mixed remaining (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}
capture erase "/tmp/test_exp_o4.png"
_clear_consort_state

* Test 12: init with file() then verify custom CSV path
local ++test_count
capture noisily {
    _clear_consort_state
    sysuse auto, clear
    consort init, initial("All cars") file("/tmp/test_exp_custom.csv")
    assert "${CONSORT_FILE}" == "/tmp/test_exp_custom.csv"
    confirm file "/tmp/test_exp_custom.csv"
}
if _rc == 0 {
    display as result "  PASS `test_count': init file() uses custom CSV path"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': file() option (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}
capture erase "/tmp/test_exp_custom.csv"
_clear_consort_state

* =============================================================================
* SECTION 3: LABEL EDGE CASES
* =============================================================================

* Test 13: Very long initial label (>100 chars)
local ++test_count
capture noisily {
    _clear_consort_state
    sysuse auto, clear
    consort init, initial("All patients enrolled in the multicenter prospective cohort study across 15 hospitals in Sweden from 2015 to 2024 inclusive")
    assert r(N) == 74
}
if _rc == 0 {
    display as result "  PASS `test_count': very long initial label"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': long initial label (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}
_clear_consort_state

* Test 14: Very long exclude label (>100 chars)
local ++test_count
capture noisily {
    _clear_consort_state
    sysuse auto, clear
    consort init, initial("All cars")
    consort exclude if rep78 == ., label("Missing required baseline laboratory measurements including hemoglobin, creatinine, albumin, and liver function tests at index date")
    assert r(n_excluded) == 5
}
if _rc == 0 {
    display as result "  PASS `test_count': very long exclude label"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': long exclude label (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}
_clear_consort_state

* Test 15: Label with commas
local ++test_count
capture noisily {
    _clear_consort_state
    sysuse auto, clear
    consort init, initial("Cars: domestic, foreign, all types")
    consort exclude if rep78 == ., label("Missing repair, warranty, or service data")
    assert r(n_excluded) == 5
}
if _rc == 0 {
    display as result "  PASS `test_count': label with commas"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': label with commas (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}
_clear_consort_state

* Test 16: Label with parentheses
local ++test_count
capture noisily {
    _clear_consort_state
    sysuse auto, clear
    consort init, initial("All cars (N=74)")
    consort exclude if rep78 == ., label("Missing repair (n=5)")
    assert r(n_excluded) == 5
}
if _rc == 0 {
    display as result "  PASS `test_count': label with parentheses"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': label with parentheses (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}
_clear_consort_state

* Test 17: Label with single quotes
local ++test_count
capture noisily {
    _clear_consort_state
    sysuse auto, clear
    consort init, initial(`"Patient's records"')
    consort exclude if rep78 == ., label(`"Didn't have data"')
    assert r(n_excluded) == 5
}
if _rc == 0 {
    display as result "  PASS `test_count': label with single quotes"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': label with single quotes (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}
_clear_consort_state

* Test 18: empty remaining("") accepted without error
local ++test_count
capture noisily {
    _clear_consort_state
    sysuse auto, clear
    consort init, initial("All cars")
    consort exclude if rep78 == ., label("Missing") remaining("")
    assert r(n_excluded) == 5
}
if _rc == 0 {
    display as result "  PASS `test_count': empty remaining() accepted"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': empty remaining (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}
_clear_consort_state

* =============================================================================
* SECTION 4: MISSING DATA HANDLING
* =============================================================================

* Test 19: Exclude condition on variable with all missing values
local ++test_count
capture noisily {
    _clear_consort_state
    clear
    set obs 50
    gen id = _n
    gen x = .

    consort init, initial("50 subjects")
    * x == 1 matches nothing since all are missing
    consort exclude if x == 1, label("Has x=1")
    assert r(n_excluded) == 0
    assert _N == 50
}
if _rc == 0 {
    display as result "  PASS `test_count': exclude on all-missing variable"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': all-missing variable (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}
_clear_consort_state

* Test 20: Exclude condition on string variable
local ++test_count
capture noisily {
    _clear_consort_state
    clear
    set obs 20
    gen id = _n
    gen str10 group = "control" if _n <= 10
    replace group = "treated" if _n > 10

    consort init, initial("20 subjects")
    consort exclude if group == "control", label("Control group")
    assert r(n_excluded) == 10
    assert r(n_remaining) == 10
}
if _rc == 0 {
    display as result "  PASS `test_count': exclude on string variable"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': string variable (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}
_clear_consort_state

* Test 21: Dataset with missing values in multiple variables
local ++test_count
capture noisily {
    _clear_consort_state
    clear
    set obs 100
    gen id = _n
    gen age = 20 + int(60 * runiform()) if _n > 10
    gen bmi = 18 + 15 * runiform() if _n > 20
    gen lab = runiform() if _n > 5

    consort init, initial("100 subjects")
    consort exclude if missing(age), label("Missing age")
    assert r(n_excluded) == 10
    consort exclude if missing(bmi), label("Missing BMI")
    consort exclude if missing(lab), label("Missing lab")
}
if _rc == 0 {
    display as result "  PASS `test_count': multiple variables with missing"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': multiple missing (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}
_clear_consort_state

* =============================================================================
* SECTION 5: REPRODUCIBILITY
* =============================================================================

* Test 22: Same data + same workflow = same r() values (run twice)
local ++test_count
capture noisily {
    _clear_consort_state

    * Run 1
    sysuse auto, clear
    consort init, initial("All cars")
    consort exclude if rep78 == ., label("Missing")
    local excl1 = r(n_excluded)
    local remain1 = r(n_remaining)
    consort save, output("/tmp/test_exp_repro1.png") final("Final")
    local Ni1 = r(N_initial)
    local Nf1 = r(N_final)
    local Ne1 = r(N_excluded)
    local steps1 = r(steps)

    * Run 2
    sysuse auto, clear
    consort init, initial("All cars")
    consort exclude if rep78 == ., label("Missing")
    local excl2 = r(n_excluded)
    local remain2 = r(n_remaining)
    consort save, output("/tmp/test_exp_repro2.png") final("Final")
    local Ni2 = r(N_initial)
    local Nf2 = r(N_final)
    local Ne2 = r(N_excluded)
    local steps2 = r(steps)

    * Compare
    assert `excl1' == `excl2'
    assert `remain1' == `remain2'
    assert `Ni1' == `Ni2'
    assert `Nf1' == `Nf2'
    assert `Ne1' == `Ne2'
    assert `steps1' == `steps2'
}
if _rc == 0 {
    display as result "  PASS `test_count': reproducibility — same results twice"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': reproducibility (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}
capture erase "/tmp/test_exp_repro1.png"
capture erase "/tmp/test_exp_repro2.png"
_clear_consort_state

* Test 23: After clear, re-init on same data gives same results
local ++test_count
capture noisily {
    _clear_consort_state
    sysuse auto, clear
    consort init, initial("All cars")
    local n1 = r(N)
    consort clear

    sysuse auto, clear
    consort init, initial("All cars")
    local n2 = r(N)

    assert `n1' == `n2'
}
if _rc == 0 {
    display as result "  PASS `test_count': re-init after clear gives same N"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': re-init after clear (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}
_clear_consort_state

* =============================================================================
* SECTION 6: STATE MANAGEMENT
* =============================================================================

* Test 24: save clears all globals
local ++test_count
capture noisily {
    _clear_consort_state
    sysuse auto, clear
    consort init, initial("All cars")
    consort exclude if rep78 == ., label("Missing")
    consort save, output("/tmp/test_exp_state1.png") final("Final")

    assert "${CONSORT_ACTIVE}" == ""
    assert "${CONSORT_N}" == ""
    assert "${CONSORT_STEPS}" == ""
    assert "${CONSORT_FILE}" == ""
}
if _rc == 0 {
    display as result "  PASS `test_count': save clears all globals"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': save globals (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}
capture erase "/tmp/test_exp_state1.png"
_clear_consort_state

* Test 25: After save, new init works correctly
local ++test_count
capture noisily {
    _clear_consort_state
    sysuse auto, clear
    consort init, initial("Diagram 1")
    consort exclude if rep78 == ., label("Missing")
    consort save, output("/tmp/test_exp_state2.png") final("Final 1")

    * Now start a new diagram
    sysuse auto, clear
    consort init, initial("Diagram 2")
    assert "${CONSORT_ACTIVE}" == "1"
    assert "${CONSORT_N}" == "74"
    assert "${CONSORT_STEPS}" == "0"
    consort exclude if foreign == 1, label("Foreign")
    assert r(n_excluded) == 22
}
if _rc == 0 {
    display as result "  PASS `test_count': new init after save works"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': new init after save (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}
capture erase "/tmp/test_exp_state2.png"
_clear_consort_state

* Test 26: clear when no diagram active (quiet) — no error
local ++test_count
capture noisily {
    _clear_consort_state
    consort clear, quiet
}
if _rc == 0 {
    display as result "  PASS `test_count': clear quiet when inactive — no error"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': clear quiet inactive (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* Test 27: clear without quiet when no diagram active — no error
local ++test_count
capture noisily {
    _clear_consort_state
    consort clear
}
if _rc == 0 {
    display as result "  PASS `test_count': clear (no quiet) when inactive — no error"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': clear no-quiet inactive (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* =============================================================================
* SECTION 7: ADDITIONAL ERROR PATHS
* =============================================================================

* Test 28: exclude with empty label errors
local ++test_count
capture noisily {
    _clear_consort_state
    sysuse auto, clear
    consort init, initial("All cars")
    capture consort exclude if rep78 == ., label("")
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS `test_count': empty label rejected rc=198"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': empty label (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}
_clear_consort_state

* Test 29: save to current directory (no path separator)
local ++test_count
capture noisily {
    _clear_consort_state
    sysuse auto, clear
    consort init, initial("All cars")
    consort exclude if rep78 == ., label("Missing")
    consort save, output("test_exp_cwd.png") final("Final")
    confirm file "test_exp_cwd.png"
}
if _rc == 0 {
    display as result "  PASS `test_count': save to current directory works"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': cwd save (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}
capture erase "test_exp_cwd.png"
_clear_consort_state

* Test 30: init when no data loaded (0 obs)
local ++test_count
capture noisily {
    _clear_consort_state
    clear
    capture consort init, initial("Empty")
    assert _rc == 2000
}
if _rc == 0 {
    display as result "  PASS `test_count': init on empty dataset errors rc=2000"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': init empty (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}
_clear_consort_state

* Test 31: exclude with label that is only whitespace errors
local ++test_count
capture noisily {
    _clear_consort_state
    sysuse auto, clear
    consort init, initial("All cars")
    capture consort exclude if rep78 == ., label("   ")
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS `test_count': whitespace-only label rejected"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': whitespace label (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}
_clear_consort_state

* =============================================================================
* SECTION 8: BOUNDARY TESTS
* =============================================================================

* Test 32: Two observations, exclude one
local ++test_count
capture noisily {
    _clear_consort_state
    clear
    set obs 2
    gen id = _n
    gen flag = (_n == 1)

    consort init, initial("2 subjects")
    assert r(N) == 2
    consort exclude if flag == 1, label("First")
    assert r(n_excluded) == 1
    assert r(n_remaining) == 1
    assert _N == 1
}
if _rc == 0 {
    display as result "  PASS `test_count': two obs, exclude one"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': two obs (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}
_clear_consort_state

* Test 33: Ten exclusion steps
local ++test_count
capture noisily {
    _clear_consort_state
    clear
    set obs 200
    gen id = _n

    consort init, initial("200 subjects")
    forvalues i = 1/10 {
        local lo = (`i' - 1) * 10 + 1
        local hi = `i' * 10
        consort exclude if id >= `lo' & id <= `hi', label("Step `i': ids `lo'-`hi'")
    }
    assert ${CONSORT_STEPS} == 10
    assert _N == 100
}
if _rc == 0 {
    display as result "  PASS `test_count': ten exclusion steps"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': ten steps (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}
_clear_consort_state

* Test 34: Exclude leaving exactly 1 observation, then save
local ++test_count
capture noisily {
    _clear_consort_state
    clear
    set obs 10
    gen id = _n

    consort init, initial("10 subjects")
    consort exclude if id <= 9, label("First 9")
    assert _N == 1
    consort save, output("/tmp/test_exp_bound1.png") final("Single subject")
    confirm file "/tmp/test_exp_bound1.png"
    assert r(N_final) == 1
}
if _rc == 0 {
    display as result "  PASS `test_count': save with single remaining obs"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': single obs save (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}
capture erase "/tmp/test_exp_bound1.png"
_clear_consort_state

* Test 35: r(initial) from init matches r(N_initial) from save
local ++test_count
capture noisily {
    _clear_consort_state
    clear
    set obs 500
    gen id = _n

    consort init, initial("500 subjects")
    local init_n = r(N)
    consort exclude if id <= 100, label("First 100")
    consort exclude if id > 400, label("Last 100")
    consort save, output("/tmp/test_exp_bound2.png") final("Remaining")
    assert r(N_initial) == `init_n'
    assert r(N_initial) == 500
    assert r(N_final) == 300
    assert r(N_excluded) == 200
}
if _rc == 0 {
    display as result "  PASS `test_count': init r(N) matches save r(N_initial)"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': init/save N consistency (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}
capture erase "/tmp/test_exp_bound2.png"
_clear_consort_state

* Test 36: r(label) returned by exclude
local ++test_count
capture noisily {
    _clear_consort_state
    sysuse auto, clear
    consort init, initial("All cars")
    consort exclude if rep78 == ., label("My specific label")
    assert "`r(label)'" == "My specific label"
}
if _rc == 0 {
    display as result "  PASS `test_count': r(label) from exclude"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': r(label) (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}
_clear_consort_state

* Test 37: r(initial) from init returns label text
local ++test_count
capture noisily {
    _clear_consort_state
    sysuse auto, clear
    consort init, initial("My Population Label")
    assert "`r(initial)'" == "My Population Label"
}
if _rc == 0 {
    display as result "  PASS `test_count': r(initial) returns label text"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': r(initial) (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}
_clear_consort_state

* Test 38: r(file) from init returns file path
local ++test_count
capture noisily {
    _clear_consort_state
    sysuse auto, clear
    consort init, initial("All cars")
    assert "`r(file)'" != ""
    * Should be a temp file path
    local fpath "`r(file)'"
    confirm file "`fpath'"
}
if _rc == 0 {
    display as result "  PASS `test_count': r(file) returns valid path"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': r(file) (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}
_clear_consort_state

* =============================================================================
* CLEANUP AND SUMMARY
* =============================================================================
_clear_consort_state

display as text _n "{hline 70}"
display as text "CONSORT EXPANDED FUNCTIONAL TEST SUMMARY"
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
    display as error _n "RESULT: FAIL"
    exit 1
}
else {
    display as result _n "RESULT: PASS"
}
