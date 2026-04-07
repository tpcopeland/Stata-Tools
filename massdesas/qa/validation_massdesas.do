* validation_massdesas.do
*
* Validation tests for massdesas v1.0.5 — known-answer and invariant tests
*
* Requires: R/haven, filelist, fs
*
* Author: Timothy P Copeland
* Date: 2026-03-21

clear all
set more off
version 14.0

* =============================================================================
* SETUP
* =============================================================================

* === Bootstrap ===
local qa_dir  "`c(pwd)'"
local pkg_dir "`qa_dir'/.."  

capture ado uninstall massdesas
quietly net install massdesas, from("`pkg_dir'") replace

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

* Check dependencies
local has_filelist = 0
local has_fs = 0

capture which filelist
if _rc == 0 local has_filelist = 1

capture which fs
if _rc == 0 local has_fs = 1

local has_deps = (`has_filelist' & `has_fs')

* Create unique temp directories for each test
tempfile tmpbase
local testdir = substr("`tmpbase'", 1, strlen("`tmpbase'") - 4)
local original_cwd `"`c(pwd)'"'

local dir_v1 "`testdir'_v1"
local dir_v4 "`testdir'_v4"
local dir_v5 "`testdir'_v5"
local dir_v6 "`testdir'_v6"
local dir_v7 "`testdir'_v7"
local dir_v8 "`testdir'_v8"
local dir_v9 "`testdir'_v9"
local dir_v11 "`testdir'_v11"
local dir_v12 "`testdir'_v12"

shell mkdir -p "`dir_v1'" "`dir_v4'" "`dir_v5'" "`dir_v6'" "`dir_v7'" "`dir_v8'" "`dir_v9'" "`dir_v11'" "`dir_v12'"

* Create all SAS test data via R/haven
shell Rscript -e "suppressWarnings(library(haven)); write_sas(data.frame(ID=1:100, VALUE=seq(1.5, 150.0, by=1.5)), '`dir_v1'/hundred.sas7bdat')" 2>/dev/null
shell Rscript -e "suppressWarnings(library(haven)); write_sas(data.frame(FirstName=c('Alice','Bob'), LastName=c('Smith','Jones'), AGE_Years=c(30L, 40L)), '`dir_v4'/mixedcase.sas7bdat')" 2>/dev/null
shell Rscript -e "suppressWarnings(library(haven)); write_sas(data.frame(X=c(1L,2L,3L)), '`dir_v5'/good.sas7bdat')" 2>/dev/null
shell Rscript -e "suppressWarnings(library(haven)); write_sas(data.frame(X=1L), '`dir_v6'/keep.sas7bdat')" 2>/dev/null
shell Rscript -e "suppressWarnings(library(haven)); write_sas(data.frame(X=numeric(0)), '`dir_v7'/empty.sas7bdat')" 2>/dev/null
shell Rscript -e "suppressWarnings(library(haven)); write_sas(data.frame(ID=1L, VAL=99.9), '`dir_v8'/single.sas7bdat')" 2>/dev/null
shell Rscript -e "suppressWarnings(library(haven)); for(i in 1:5) write_sas(data.frame(X=as.double(i)), paste0('`dir_v9'/multi_', i, '.sas7bdat'))" 2>/dev/null
shell Rscript -e "suppressWarnings(library(haven)); for(i in 1:3) write_sas(data.frame(X=as.double(i)), paste0('`dir_v11'/rv_', i, '.sas7bdat'))" 2>/dev/null
shell Rscript -e "suppressWarnings(library(haven)); write_sas(data.frame(X=1L), '`dir_v12'/dircheck.sas7bdat')" 2>/dev/null

* Check if SAS test data was created
local can_run = 0
capture confirm file "`dir_v1'/hundred.sas7bdat"
if _rc == 0 & `has_deps' local can_run = 1

if !`can_run' {
    display as error "Validation requires filelist, fs, and R/haven with SAS write support."
    display as text "filelist=`has_filelist' fs=`has_fs' SAS data created: `can_run'"
    shell rm -rf "`testdir'_"*
    exit 0
}

* =============================================================================
* SECTION 1: Known-answer tests
* =============================================================================

* Test 1: Exact row count after conversion
local ++test_count
display as text _n "Test `test_count': Exact row count (100 obs)"

capture noisily {
    massdesas, directory("`dir_v1'")
    use "`dir_v1'/hundred.dta", clear
    assert _N == 100
}
if _rc == 0 {
    display as result "  PASS (_N=100)"
    local ++pass_count
}
else {
    display as error "  FAIL (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* Test 2: Variable values preserved exactly
local ++test_count
display as text _n "Test `test_count': Variable values preserved"

capture noisily {
    use "`dir_v1'/hundred.dta", clear
    assert ID[1] == 1
    assert ID[100] == 100
    assert abs(VALUE[1] - 1.5) < 0.001
    assert abs(VALUE[50] - 75.0) < 0.001
}
if _rc == 0 {
    display as result "  PASS"
    local ++pass_count
}
else {
    display as error "  FAIL (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* Test 3: Variable types preserved (numeric stays numeric)
local ++test_count
display as text _n "Test `test_count': Variable types preserved"

capture noisily {
    use "`dir_v1'/hundred.dta", clear
    confirm numeric variable ID VALUE
}
if _rc == 0 {
    display as result "  PASS"
    local ++pass_count
}
else {
    display as error "  FAIL (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* Test 4: lower option changes ALL variable names
local ++test_count
display as text _n "Test `test_count': lower option changes all names to lowercase"

capture noisily {
    massdesas, directory("`dir_v4'") lower
    use "`dir_v4'/mixedcase.dta", clear
    confirm variable firstname lastname age_years
}
if _rc == 0 {
    display as result "  PASS"
    local ++pass_count
}
else {
    display as error "  FAIL (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* =============================================================================
* SECTION 2: Invariant tests — erase safety
* =============================================================================

* Test 5: erase removes converted .sas7bdat, .dta exists
local ++test_count
display as text _n "Test `test_count': erase removes converted .sas7bdat, .dta exists"

capture noisily {
    massdesas, directory("`dir_v5'") erase
    capture confirm file "`dir_v5'/good.sas7bdat"
    assert _rc != 0
    confirm file "`dir_v5'/good.dta"
    use "`dir_v5'/good.dta", clear
    assert _N == 3
}
if _rc == 0 {
    display as result "  PASS"
    local ++pass_count
}
else {
    display as error "  FAIL (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* Test 6: Without erase, original .sas7bdat preserved
local ++test_count
display as text _n "Test `test_count': Without erase, .sas7bdat preserved"

capture noisily {
    massdesas, directory("`dir_v6'")
    confirm file "`dir_v6'/keep.sas7bdat"
    confirm file "`dir_v6'/keep.dta"
}
if _rc == 0 {
    display as result "  PASS"
    local ++pass_count
}
else {
    display as error "  FAIL (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* =============================================================================
* SECTION 3: Boundary tests
* =============================================================================

* Test 7: Zero-observation SAS file
local ++test_count
display as text _n "Test `test_count': Zero-observation SAS file"

capture noisily {
    massdesas, directory("`dir_v7'")
    assert r(n_converted) == 1
    assert r(n_failed) == 0
    use "`dir_v7'/empty.dta", clear
    assert _N == 0
}
if _rc == 0 {
    display as result "  PASS (0-obs file converted successfully)"
    local ++pass_count
}
else {
    display as error "  FAIL (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* Test 8: Single-observation SAS file
local ++test_count
display as text _n "Test `test_count': Single-observation SAS file"

capture noisily {
    massdesas, directory("`dir_v8'")
    assert r(n_converted) == 1
    use "`dir_v8'/single.dta", clear
    assert _N == 1
    assert abs(VAL[1] - 99.9) < 0.01
}
if _rc == 0 {
    display as result "  PASS"
    local ++pass_count
}
else {
    display as error "  FAIL (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* Test 9: Multiple files — r(n_converted) matches file count
local ++test_count
display as text _n "Test `test_count': Multiple files — n_converted matches count"

capture noisily {
    massdesas, directory("`dir_v9'")
    assert r(n_converted) == 5
    assert r(n_failed) == 0
}
if _rc == 0 {
    display as result "  PASS (n_converted=`r(n_converted)')"
    local ++pass_count
}
else {
    display as error "  FAIL (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* Test 10: Each of the 5 converted files has correct content
local ++test_count
display as text _n "Test `test_count': Each converted file has correct content"

local all_correct = 1
forvalues i = 1/5 {
    capture {
        use "`dir_v9'/multi_`i'.dta", clear
        assert _N == 1
        assert abs(X[1] - `i') < 0.001
    }
    if _rc != 0 {
        local all_correct = 0
    }
}
if `all_correct' {
    display as result "  PASS (all 5 files correct)"
    local ++pass_count
}
else {
    display as error "  FAIL (some files had wrong content)"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* =============================================================================
* SECTION 4: Return value consistency
* =============================================================================

* Test 11: r(n_converted) + r(n_failed) == total files processed
local ++test_count
display as text _n "Test `test_count': r(n_converted) + r(n_failed) == total files"

capture noisily {
    massdesas, directory("`dir_v11'")
    local total = r(n_converted) + r(n_failed)
    assert `total' == 3
}
if _rc == 0 {
    display as result "  PASS (total=`total')"
    local ++pass_count
}
else {
    display as error "  FAIL (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* Test 12: r(directory) matches input directory
local ++test_count
display as text _n "Test `test_count': r(directory) matches input"

capture noisily {
    massdesas, directory("`dir_v12'")
    local returned_dir `"`r(directory)'"'
    assert `"`returned_dir'"' == `"`dir_v12'"'
}
if _rc == 0 {
    display as result "  PASS"
    local ++pass_count
}
else {
    display as error "  FAIL (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* Test 13: Idempotent re-run (converting already-converted dir succeeds)
local ++test_count
display as text _n "Test `test_count': Idempotent re-run succeeds"

capture noisily {
    massdesas, directory("`dir_v12'")
    assert r(n_converted) >= 1
    assert r(n_failed) == 0
}
if _rc == 0 {
    display as result "  PASS (re-run succeeded)"
    local ++pass_count
}
else {
    display as error "  FAIL (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* =============================================================================
* CLEANUP
* =============================================================================
shell rm -rf "`testdir'_"*
cd `"`original_cwd'"'

* =============================================================================
* SUMMARY
* =============================================================================
display as text _n "{hline 70}"
display as text "MASSDESAS VALIDATION TEST SUMMARY (v1.0.5)"
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
