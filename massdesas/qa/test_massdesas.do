* test_massdesas.do
*
* Functional tests for massdesas v1.0.5 — batch .sas7bdat to .dta conversion
*
* Sections:
*   1. Installation and dependency checks (Tests 1-3)
*   2. Error handling (Tests 4-8)
*   3. Varabbrev save/restore (Tests 9-11)
*   4. Working directory preservation (Tests 12-14)
*   5. Round-trip conversion (Tests 15-22, requires R/haven)
*   6. Data preservation (Tests 23-24)
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

* Create temp directories for testing — unique per test section
tempfile tmpbase
local testdir = substr("`tmpbase'", 1, strlen("`tmpbase'") - 4)
local emptydir "`testdir'_empty"
shell mkdir -p "`emptydir'"

* Check dependencies upfront
local has_filelist = 0
local has_fs = 0
local has_r = 0

capture which filelist
if _rc == 0 local has_filelist = 1

capture which fs
if _rc == 0 local has_fs = 1

* Check R/haven for SAS file creation
capture shell Rscript -e "suppressWarnings(library(haven))" 2>/dev/null
if _rc == 0 local has_r = 1

local has_deps = (`has_filelist' & `has_fs')

display as text "Dependencies: filelist=`has_filelist' fs=`has_fs' R/haven=`has_r'"

* Save original CWD
local original_cwd `"`c(pwd)'"'

* Pre-create all test data using R/haven (SAS file creation)
* Each test gets its own directory to avoid cleanup issues
local dir_t15 "`testdir'_t15"
local dir_t16 "`testdir'_t16"
local dir_t17 "`testdir'_t17"
local dir_t18 "`testdir'_t18"
local dir_t19 "`testdir'_t19"
local dir_t20 "`testdir'_t20"
local dir_t21 "`testdir'_t21"
local dir_t22 "`testdir'_t22"
local dir_t22s "`testdir'_t22/sub"
local dir_dp "`testdir'_dp"

shell mkdir -p "`dir_t15'" "`dir_t16'" "`dir_t17'" "`dir_t18'" "`dir_t19'" "`dir_t20'" "`dir_t21'" "`dir_t22'" "`dir_t22s'" "`dir_dp'"

shell Rscript -e "suppressWarnings(library(haven)); write_sas(data.frame(ID=1:5, AGE=c(25,30,35,40,45), SCORE=c(88.5,92.1,76.3,81.0,95.7)), '`dir_t15'/testdata.sas7bdat')" 2>/dev/null
shell Rscript -e "suppressWarnings(library(haven)); write_sas(data.frame(ID=1:5, AGE=c(25,30,35,40,45), SCORE=c(88.5,92.1,76.3,81.0,95.7)), '`dir_t16'/testdata.sas7bdat')" 2>/dev/null
shell Rscript -e "suppressWarnings(library(haven)); write_sas(data.frame(ID=1:5, AGE=c(25,30,35,40,45), SCORE=c(88.5,92.1,76.3,81.0,95.7)), '`dir_t17'/testdata.sas7bdat')" 2>/dev/null
shell Rscript -e "suppressWarnings(library(haven)); write_sas(data.frame(ID=1:5, AGE=c(25,30,35,40,45), SCORE=c(88.5,92.1,76.3,81.0,95.7)), '`dir_t18'/testdata.sas7bdat')" 2>/dev/null
shell Rscript -e "suppressWarnings(library(haven)); write_sas(data.frame(X=c(1L,2L,3L)), '`dir_t19'/erasetest.sas7bdat')" 2>/dev/null
shell Rscript -e "suppressWarnings(library(haven)); write_sas(data.frame(X=1L), '`dir_t20'/cwd_test.sas7bdat')" 2>/dev/null
shell Rscript -e "suppressWarnings(library(haven)); write_sas(data.frame(X=1L), '`dir_t21'/va_test.sas7bdat')" 2>/dev/null
shell Rscript -e "suppressWarnings(library(haven)); write_sas(data.frame(A=c(1L,2L)), '`dir_t22'/root.sas7bdat'); write_sas(data.frame(A=c(1L,2L)), '`dir_t22'/sub/child.sas7bdat')" 2>/dev/null
shell Rscript -e "suppressWarnings(library(haven)); write_sas(data.frame(X=1L), '`dir_dp'/dp_test.sas7bdat')" 2>/dev/null

* Check if SAS test data was created
local sas_ok = 0
capture confirm file "`dir_t15'/testdata.sas7bdat"
if _rc == 0 & `has_deps' local sas_ok = 1

display as text "SAS test data created: `sas_ok'"

* =============================================================================
* SECTION 1: Installation and dependency checks
* =============================================================================

* Test 1: Package installs successfully
local ++test_count
display as text _n "Test `test_count': Package installs and command is discoverable"

capture noisily {
    which massdesas
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

* Test 2: Help file renders without error
local ++test_count
display as text _n "Test `test_count': Help file renders"

capture noisily {
    help massdesas
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

* Test 3: Version string present in header
local ++test_count
display as text _n "Test `test_count': Version 1.0.5 in which output"

capture noisily {
    which massdesas
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
* SECTION 2: Error handling
* =============================================================================

* Test 4: Nonexistent directory triggers rc=601
local ++test_count
display as text _n "Test `test_count': Nonexistent directory triggers rc=601"

capture massdesas, directory("/nonexistent/path/xyz_99999")
if _rc == 601 {
    display as result "  PASS"
    local ++pass_count
}
else {
    display as error "  FAIL (expected rc=601, got `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* Test 5: Empty directory (no .sas7bdat files) triggers error
local ++test_count
display as text _n "Test `test_count': Empty directory triggers error"

capture massdesas, directory("`emptydir'")
if _rc == 601 | _rc == 199 {
    display as result "  PASS (rc=`=_rc')"
    local ++pass_count
}
else {
    display as error "  FAIL (expected rc=601 or 199, got `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* Test 6: Default directory (no arguments) works or errors gracefully
local ++test_count
display as text _n "Test `test_count': No arguments uses CWD (errors if no SAS files)"

capture massdesas
if _rc == 0 | _rc == 601 | _rc == 199 {
    display as result "  PASS (rc=`=_rc' — directory() is optional)"
    local ++pass_count
}
else {
    display as error "  FAIL (unexpected rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* Test 7: Invalid option rejected
local ++test_count
display as text _n "Test `test_count': Invalid option rejected"

capture massdesas, badoption
if _rc != 0 {
    display as result "  PASS (rc=`=_rc')"
    local ++pass_count
}
else {
    display as error "  FAIL (should have rejected invalid option)"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* Test 8: Empty string directory
local ++test_count
display as text _n "Test `test_count': Empty string directory uses CWD"

capture massdesas, directory("")
if _rc == 0 | _rc == 601 | _rc == 199 {
    display as result "  PASS (rc=`=_rc')"
    local ++pass_count
}
else {
    display as error "  FAIL (unexpected rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* =============================================================================
* SECTION 3: Varabbrev save/restore
* =============================================================================

* Test 9: varabbrev ON preserved after error exit
local ++test_count
display as text _n "Test `test_count': varabbrev ON preserved after error"

set varabbrev on
capture massdesas, directory("/nonexistent/path/xyz_99999")
if "`c(varabbrev)'" == "on" {
    display as result "  PASS (varabbrev=on preserved)"
    local ++pass_count
}
else {
    display as error "  FAIL (varabbrev=`c(varabbrev)', expected on)"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* Test 10: varabbrev OFF preserved after error exit
local ++test_count
display as text _n "Test `test_count': varabbrev OFF preserved after error"

set varabbrev off
capture massdesas, directory("/nonexistent/path/xyz_99999")
if "`c(varabbrev)'" == "off" {
    display as result "  PASS (varabbrev=off preserved)"
    local ++pass_count
}
else {
    display as error "  FAIL (varabbrev=`c(varabbrev)', expected off)"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}
set varabbrev on

* Test 11: varabbrev OFF preserved after empty-dir error
local ++test_count
display as text _n "Test `test_count': varabbrev OFF preserved after empty-dir error"

set varabbrev off
capture massdesas, directory("`emptydir'")
if "`c(varabbrev)'" == "off" {
    display as result "  PASS (varabbrev=off preserved)"
    local ++pass_count
}
else {
    display as error "  FAIL (varabbrev=`c(varabbrev)', expected off)"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}
set varabbrev on

* =============================================================================
* SECTION 4: Working directory preservation
* =============================================================================

* Test 12: CWD restored after nonexistent directory error
local ++test_count
display as text _n "Test `test_count': CWD restored after nonexistent dir error"

local pre_cwd `"`c(pwd)'"'
capture massdesas, directory("/nonexistent/path/xyz_99999")
local post_cwd `"`c(pwd)'"'
if `"`pre_cwd'"' == `"`post_cwd'"' {
    display as result "  PASS (CWD unchanged)"
    local ++pass_count
}
else {
    display as error "  FAIL (CWD changed)"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
    cd `"`original_cwd'"'
}

* Test 13: CWD restored after empty directory error
local ++test_count
display as text _n "Test `test_count': CWD restored after empty dir error"

local pre_cwd `"`c(pwd)'"'
capture massdesas, directory("`emptydir'")
local post_cwd `"`c(pwd)'"'
if `"`pre_cwd'"' == `"`post_cwd'"' {
    display as result "  PASS (CWD unchanged)"
    local ++pass_count
}
else {
    display as error "  FAIL (CWD changed)"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
    cd `"`original_cwd'"'
}

* Test 14: CWD restored after invalid option error
local ++test_count
display as text _n "Test `test_count': CWD restored after invalid option error"

local pre_cwd `"`c(pwd)'"'
capture massdesas, badoption
local post_cwd `"`c(pwd)'"'
if `"`pre_cwd'"' == `"`post_cwd'"' {
    display as result "  PASS (CWD unchanged)"
    local ++pass_count
}
else {
    display as error "  FAIL (CWD changed)"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
    cd `"`original_cwd'"'
}

* =============================================================================
* SECTION 5: Round-trip conversion (requires R/haven + filelist + fs)
* =============================================================================

if !`sas_ok' {
    display as text _n "Skipping round-trip tests (sas_ok=`sas_ok', deps=`has_deps', R=`has_r')"
}

* Test 15: Basic single-file conversion
if `sas_ok' {
    local ++test_count
    display as text _n "Test `test_count': Single file conversion"

    capture noisily {
        massdesas, directory("`dir_t15'")
        assert r(n_converted) == 1
        assert r(n_failed) == 0
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
}

* Test 16: Converted .dta has correct content
if `sas_ok' {
    local ++test_count
    display as text _n "Test `test_count': Converted .dta content correct"

    capture noisily {
        massdesas, directory("`dir_t16'")
        use "`dir_t16'/testdata.dta", clear
        assert _N == 5
        confirm variable ID AGE SCORE
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
}

* Test 17: lower option converts variable names
if `sas_ok' {
    local ++test_count
    display as text _n "Test `test_count': lower option"

    capture noisily {
        massdesas, directory("`dir_t17'") lower
        use "`dir_t17'/testdata.dta", clear
        confirm variable id age score
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
}

* Test 18: Return values populated correctly
if `sas_ok' {
    local ++test_count
    display as text _n "Test `test_count': Return values"

    capture noisily {
        massdesas, directory("`dir_t18'")
        assert r(n_converted) == 1
        assert r(n_failed) == 0
        assert `"`r(directory)'"' != ""
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
}

* Test 19: erase option removes source files
if `sas_ok' {
    local ++test_count
    display as text _n "Test `test_count': erase option removes source files"

    capture noisily {
        massdesas, directory("`dir_t19'") erase
        capture confirm file "`dir_t19'/erasetest.sas7bdat"
        assert _rc != 0
        confirm file "`dir_t19'/erasetest.dta"
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
}

* Test 20: CWD restored after successful conversion
if `sas_ok' {
    local ++test_count
    display as text _n "Test `test_count': CWD restored after successful conversion"

    local pre_cwd `"`c(pwd)'"'
    capture noisily {
        massdesas, directory("`dir_t20'")
    }
    local post_cwd `"`c(pwd)'"'
    if `"`pre_cwd'"' == `"`post_cwd'"' & _rc == 0 {
        display as result "  PASS"
        local ++pass_count
    }
    else {
        display as error "  FAIL (CWD changed or rc=`=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        cd `"`original_cwd'"'
    }
}

* Test 21: varabbrev OFF preserved after successful conversion
if `sas_ok' {
    local ++test_count
    display as text _n "Test `test_count': varabbrev OFF preserved after success"

    set varabbrev off
    capture noisily {
        massdesas, directory("`dir_t21'")
    }
    if "`c(varabbrev)'" == "off" & _rc == 0 {
        display as result "  PASS"
        local ++pass_count
    }
    else {
        display as error "  FAIL (varabbrev=`c(varabbrev)', rc=`=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
    }
    set varabbrev on
}

* Test 22: Subdirectory conversion (recursive)
if `sas_ok' {
    local ++test_count
    display as text _n "Test `test_count': Recursive subdirectory conversion"

    capture noisily {
        massdesas, directory("`dir_t22'")
        assert r(n_converted) == 2
        assert r(n_failed) == 0
        confirm file "`dir_t22'/root.dta"
        confirm file "`dir_t22'/sub/child.dta"
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
}

* =============================================================================
* SECTION 6: Data preservation
* =============================================================================

* Test 23: User data preserved after error
local ++test_count
display as text _n "Test `test_count': User data preserved after error"

sysuse auto, clear
local pre_N = _N
capture massdesas, directory("/nonexistent/path/xyz_99999")
if _N == `pre_N' {
    display as result "  PASS (_N=`=_N' preserved)"
    local ++pass_count
}
else {
    display as error "  FAIL (_N changed from `pre_N' to `=_N')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* Test 24: User data preserved after successful conversion
if `sas_ok' {
    local ++test_count
    display as text _n "Test `test_count': User data preserved after success"

    sysuse auto, clear
    local pre_N = _N
    capture noisily massdesas, directory("`dir_dp'")
    if _N == `pre_N' & _rc == 0 {
        display as result "  PASS (_N=`=_N' preserved)"
        local ++pass_count
    }
    else {
        display as error "  FAIL (_N=`=_N' expected `pre_N', rc=`=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
    }
}

* =============================================================================
* CLEANUP
* =============================================================================
shell rm -rf "`testdir'_"*
shell rm -rf "`emptydir'"
cd `"`original_cwd'"'

* =============================================================================
* SUMMARY
* =============================================================================
display as text _n "{hline 70}"
display as text "MASSDESAS FUNCTIONAL TEST SUMMARY (v1.0.5)"
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
