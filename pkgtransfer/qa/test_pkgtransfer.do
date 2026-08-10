/*
    File:    test_pkgtransfer.do
    Purpose: Functional tests for pkgtransfer
    Prereqs: pkgtransfer package installed or on adopath
    Author:  Tim Copeland
    Date:    2026-03-13

    Run modes:
      do test_pkgtransfer.do          - run all tests (verbose)
      global RUN_TEST_QUIET 1         - suppress per-test output
      global RUN_TEST_MACHINE 1       - machine-parseable output
      global RUN_TEST_NUMBER N        - run only test N
*/

version 16.0
set more off

* Configuration
if "$RUN_TEST_QUIET"   == "" global RUN_TEST_QUIET   0
if "$RUN_TEST_MACHINE" == "" global RUN_TEST_MACHINE 0
if "$RUN_TEST_NUMBER"  == "" global RUN_TEST_NUMBER  0

local quiet   = $RUN_TEST_QUIET
local machine = $RUN_TEST_MACHINE
local run_only = $RUN_TEST_NUMBER

* Path setup

* === Bootstrap ===
local qa_dir  "`c(pwd)'"
local pkg_dir "`qa_dir'/.."  

local orig_dir "`c(pwd)'"
run "`qa_dir'/_pkgtransfer_qa_common.do"
_pkgtransfer_qa_setup, pkgdir("`pkg_dir'")
local qa_root "`r(root)'"
local qa_original_plus "`r(original_plus)'"
local tmpdir "`r(work)'"
local qa_plus "`r(plus)'"

adopath ++ "`pkg_dir'"
capture program drop pkgtransfer
run "`pkg_dir'/pkgtransfer.ado"

* Test counters
local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

* Helper program for test output
capture program drop _run_test
program define _run_test
    args num desc
    local machine = $RUN_TEST_MACHINE
    local quiet   = $RUN_TEST_QUIET
    local run_only = $RUN_TEST_NUMBER
    if `run_only' == 0 | `run_only' == `num' {
        if `machine' == 0 & `quiet' == 0 {
            display as text "  Test `num': `desc'"
        }
    }
end

* ============================================================
* SECTION 1: ERROR HANDLING
* ============================================================

* Test 1: Invalid download() value
local ++test_count
local test_desc "Error on invalid download() value"
_run_test `test_count' "`test_desc'"
if `run_only' == 0 | `run_only' == `test_count' {
    capture noisily pkgtransfer, download(invalid)
    if _rc == 198 {
        local ++pass_count
        if `machine' display "RESULT: [OK] `test_count'"
        else if `quiet' == 0 display as result "    PASSED"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' display "RESULT: [FAIL] `test_count'|`=_rc'|`test_desc'"
        else display as error "    FAILED: expected rc 198, got `=_rc'"
    }
}

* Test 2: Invalid os() value
local ++test_count
local test_desc "Error on invalid os() value"
_run_test `test_count' "`test_desc'"
if `run_only' == 0 | `run_only' == `test_count' {
    capture noisily pkgtransfer, os(Linux)
    if _rc == 198 {
        local ++pass_count
        if `machine' display "RESULT: [OK] `test_count'"
        else if `quiet' == 0 display as result "    PASSED"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' display "RESULT: [FAIL] `test_count'|`=_rc'|`test_desc'"
        else display as error "    FAILED: expected rc 198, got `=_rc'"
    }
}

* Test 3: dofile() without .do extension
local ++test_count
local test_desc "Error on dofile() without .do extension"
_run_test `test_count' "`test_desc'"
if `run_only' == 0 | `run_only' == `test_count' {
    capture noisily pkgtransfer, dofile(myfile.txt)
    if _rc == 198 {
        local ++pass_count
        if `machine' display "RESULT: [OK] `test_count'"
        else if `quiet' == 0 display as result "    PASSED"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' display "RESULT: [FAIL] `test_count'|`=_rc'|`test_desc'"
        else display as error "    FAILED: expected rc 198, got `=_rc'"
    }
}

* Test 4: dofile() with invalid characters
local ++test_count
local test_desc "Error on dofile() with invalid characters"
_run_test `test_count' "`test_desc'"
if `run_only' == 0 | `run_only' == `test_count' {
    capture noisily pkgtransfer, dofile(bad;name.do)
    if _rc == 198 {
        local ++pass_count
        if `machine' display "RESULT: [OK] `test_count'"
        else if `quiet' == 0 display as result "    PASSED"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' display "RESULT: [FAIL] `test_count'|`=_rc'|`test_desc'"
        else display as error "    FAILED: expected rc 198, got `=_rc'"
    }
}

* Test 5: zipfile() without .zip extension
local ++test_count
local test_desc "Error on zipfile() without .zip extension"
_run_test `test_count' "`test_desc'"
if `run_only' == 0 | `run_only' == `test_count' {
    capture noisily pkgtransfer, download(online) zipfile(myfile.tar)
    if _rc == 198 {
        local ++pass_count
        if `machine' display "RESULT: [OK] `test_count'"
        else if `quiet' == 0 display as result "    PASSED"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' display "RESULT: [FAIL] `test_count'|`=_rc'|`test_desc'"
        else display as error "    FAILED: expected rc 198, got `=_rc'"
    }
}

* Test 6: zipfile() with invalid characters
local ++test_count
local test_desc "Error on zipfile() with invalid characters"
_run_test `test_count' "`test_desc'"
if `run_only' == 0 | `run_only' == `test_count' {
    capture noisily pkgtransfer, download(online) zipfile(bad|name.zip)
    if _rc == 198 {
        local ++pass_count
        if `machine' display "RESULT: [OK] `test_count'"
        else if `quiet' == 0 display as result "    PASSED"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' display "RESULT: [FAIL] `test_count'|`=_rc'|`test_desc'"
        else display as error "    FAILED: expected rc 198, got `=_rc'"
    }
}

* Test 7: zipfile() without download() option
local ++test_count
local test_desc "Error on zipfile() without download()"
_run_test `test_count' "`test_desc'"
if `run_only' == 0 | `run_only' == `test_count' {
    capture noisily pkgtransfer, zipfile(my.zip)
    if _rc == 198 {
        local ++pass_count
        if `machine' display "RESULT: [OK] `test_count'"
        else if `quiet' == 0 display as result "    PASSED"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' display "RESULT: [FAIL] `test_count'|`=_rc'|`test_desc'"
        else display as error "    FAILED: expected rc 198, got `=_rc'"
    }
}

* Test 8: limited() with non-existent package
local ++test_count
local test_desc "Error on limited() with non-existent package"
_run_test `test_count' "`test_desc'"
if `run_only' == 0 | `run_only' == `test_count' {
    capture noisily pkgtransfer, limited(zzz_nonexistent_pkg_12345)
    if _rc == 111 {
        local ++pass_count
        if `machine' display "RESULT: [OK] `test_count'"
        else if `quiet' == 0 display as result "    PASSED"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' display "RESULT: [FAIL] `test_count'|`=_rc'|`test_desc'"
        else display as error "    FAILED: expected rc 111, got `=_rc'"
    }
}

* ============================================================
* SECTION 2: VARABBREV RESTORATION
* ============================================================

* Test 9: varabbrev restored after successful run
local ++test_count
local test_desc "varabbrev restored after successful run"
_run_test `test_count' "`test_desc'"
if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        set varabbrev on
        quietly cd "`tmpdir'"
        pkgtransfer, dofile(test_varabbrev_ok.do)
        local vabb_after `c(varabbrev)'
        capture erase "test_varabbrev_ok.do"
        quietly cd "`orig_dir'"
        assert "`vabb_after'" == "on"
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' display "RESULT: [OK] `test_count'"
        else if `quiet' == 0 display as result "    PASSED"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' display "RESULT: [FAIL] `test_count'|`=_rc'|`test_desc'"
        else display as error "    FAILED: varabbrev not restored after success"
    }
    set varabbrev on
}

* Test 10: varabbrev restored after error
local ++test_count
local test_desc "varabbrev restored after error exit"
_run_test `test_count' "`test_desc'"
if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        set varabbrev on
        capture noisily pkgtransfer, download(invalid)
        local vabb_after `c(varabbrev)'
        assert "`vabb_after'" == "on"
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' display "RESULT: [OK] `test_count'"
        else if `quiet' == 0 display as result "    PASSED"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' display "RESULT: [FAIL] `test_count'|`=_rc'|`test_desc'"
        else display as error "    FAILED: varabbrev not restored after error"
    }
    set varabbrev on
}

* Test 11: varabbrev restored after limited() error
local ++test_count
local test_desc "varabbrev restored after limited() package not found"
_run_test `test_count' "`test_desc'"
if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        set varabbrev on
        capture noisily pkgtransfer, limited(zzz_nonexistent_pkg_12345)
        local vabb_after `c(varabbrev)'
        assert "`vabb_after'" == "on"
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' display "RESULT: [OK] `test_count'"
        else if `quiet' == 0 display as result "    PASSED"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' display "RESULT: [FAIL] `test_count'|`=_rc'|`test_desc'"
        else display as error "    FAILED: varabbrev not restored after limited() error"
    }
    set varabbrev on
}

* ============================================================
* SECTION 3: DEFAULT MODE (SCRIPT GENERATION)
* ============================================================

* Test 12: Default mode generates do-file
local ++test_count
local test_desc "Default mode creates pkgtransfer.do"
_run_test `test_count' "`test_desc'"
if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        quietly cd "`tmpdir'"
        pkgtransfer
        confirm file "pkgtransfer.do"
        capture erase "pkgtransfer.do"
        quietly cd "`orig_dir'"
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' display "RESULT: [OK] `test_count'"
        else if `quiet' == 0 display as result "    PASSED"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' display "RESULT: [FAIL] `test_count'|`=_rc'|`test_desc'"
        else display as error "    FAILED: `test_desc'"
    }
}

* Test 13: Custom dofile name
local ++test_count
local test_desc "Custom dofile() name works"
_run_test `test_count' "`test_desc'"
if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        quietly cd "`tmpdir'"
        pkgtransfer, dofile(custom_install.do)
        confirm file "custom_install.do"
        capture erase "custom_install.do"
        quietly cd "`orig_dir'"
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' display "RESULT: [OK] `test_count'"
        else if `quiet' == 0 display as result "    PASSED"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' display "RESULT: [FAIL] `test_count'|`=_rc'|`test_desc'"
        else display as error "    FAILED: `test_desc'"
    }
}

* Test 14: Return values in default mode
local ++test_count
local test_desc "Return values set correctly in default mode"
_run_test `test_count' "`test_desc'"
if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        quietly cd "`tmpdir'"
        pkgtransfer
        assert "`r(download_mode)'" == "script_only"
        assert "`r(os)'" == "`c(os)'"
        assert "`r(dofile)'" == "pkgtransfer.do"
        assert r(N_packages) > 0
        assert "`r(package_list)'" != ""
        capture erase "pkgtransfer.do"
        quietly cd "`orig_dir'"
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' display "RESULT: [OK] `test_count'"
        else if `quiet' == 0 display as result "    PASSED"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' display "RESULT: [FAIL] `test_count'|`=_rc'|`test_desc'"
        else display as error "    FAILED: `test_desc'"
    }
}

* Test 15: OS return value matches specification
local ++test_count
local test_desc "os() option reflected in return value"
_run_test `test_count' "`test_desc'"
if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        quietly cd "`tmpdir'"
        pkgtransfer, os(Windows)
        assert "`r(os)'" == "Windows"
        capture erase "pkgtransfer.do"
        quietly cd "`orig_dir'"
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' display "RESULT: [OK] `test_count'"
        else if `quiet' == 0 display as result "    PASSED"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' display "RESULT: [FAIL] `test_count'|`=_rc'|`test_desc'"
        else display as error "    FAILED: `test_desc'"
    }
}

* Test 16: N_packages matches package_list word count
local ++test_count
local test_desc "N_packages equals word count of package_list"
_run_test `test_count' "`test_desc'"
if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        quietly cd "`tmpdir'"
        pkgtransfer
        local n_ret = r(N_packages)
        local plist "`r(package_list)'"
        local n_words : word count `plist'
        assert `n_ret' == `n_words'
        capture erase "pkgtransfer.do"
        quietly cd "`orig_dir'"
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' display "RESULT: [OK] `test_count'"
        else if `quiet' == 0 display as result "    PASSED"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' display "RESULT: [FAIL] `test_count'|`=_rc'|`test_desc'"
        else display as error "    FAILED: `test_desc'"
    }
}

* ============================================================
* SECTION 4: SKIP OPTION
* ============================================================

* Test 17: skip() reduces package count
local ++test_count
local test_desc "skip() option reduces N_packages"
_run_test `test_count' "`test_desc'"
if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        quietly cd "`tmpdir'"
        * Get baseline count
        pkgtransfer, dofile(baseline.do)
        local n_all = r(N_packages)
        local plist "`r(package_list)'"
        local first_pkg : word 1 of `plist'
        capture erase "baseline.do"

        * Get count with skip
        pkgtransfer, skip(`first_pkg') dofile(skipped.do)
        local n_skip = r(N_packages)
        capture erase "skipped.do"
        quietly cd "`orig_dir'"

        assert `n_skip' < `n_all'
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' display "RESULT: [OK] `test_count'"
        else if `quiet' == 0 display as result "    PASSED"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' display "RESULT: [FAIL] `test_count'|`=_rc'|`test_desc'"
        else display as error "    FAILED: `test_desc'"
    }
}

* ============================================================
* SECTION 5: DATA PRESERVATION
* ============================================================

* Test 18: User data preserved after successful run
local ++test_count
local test_desc "User data preserved after successful run"
_run_test `test_count' "`test_desc'"
if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        sysuse auto, clear
        local orig_N = _N
        quietly cd "`tmpdir'"
        pkgtransfer
        assert _N == `orig_N'
        assert "`=_N'" == "74"
        capture erase "pkgtransfer.do"
        quietly cd "`orig_dir'"
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' display "RESULT: [OK] `test_count'"
        else if `quiet' == 0 display as result "    PASSED"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' display "RESULT: [FAIL] `test_count'|`=_rc'|`test_desc'"
        else display as error "    FAILED: `test_desc'"
    }
}

* Test 19: User data preserved after error
local ++test_count
local test_desc "User data preserved after error exit"
_run_test `test_count' "`test_desc'"
if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        sysuse auto, clear
        local orig_N = _N
        capture noisily pkgtransfer, download(invalid)
        assert _N == `orig_N'
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' display "RESULT: [OK] `test_count'"
        else if `quiet' == 0 display as result "    PASSED"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' display "RESULT: [FAIL] `test_count'|`=_rc'|`test_desc'"
        else display as error "    FAILED: `test_desc'"
    }
}

* ============================================================
* SECTION 6: LIMITED OPTION
* ============================================================

* Test 20: limited() returns only specified package
local ++test_count
local test_desc "limited() returns only specified package"
_run_test `test_count' "`test_desc'"
if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        quietly cd "`tmpdir'"
        * Get a known package from the full list
        pkgtransfer, dofile(full.do)
        local plist "`r(package_list)'"
        local first_pkg : word 1 of `plist'
        capture erase "full.do"

        * Run with limited
        pkgtransfer, limited(`first_pkg') dofile(limited.do)
        assert r(N_packages) == 1
        assert "`r(package_list)'" == "`first_pkg'"
        capture erase "limited.do"
        quietly cd "`orig_dir'"
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' display "RESULT: [OK] `test_count'"
        else if `quiet' == 0 display as result "    PASSED"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' display "RESULT: [FAIL] `test_count'|`=_rc'|`test_desc'"
        else display as error "    FAILED: `test_desc'"
    }
}

* ============================================================
* SECTION 7: DO-FILE CONTENT VALIDATION
* ============================================================

* Test 21: Generated do-file contains install commands
local ++test_count
local test_desc "Generated do-file contains install commands"
_run_test `test_count' "`test_desc'"
if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        quietly cd "`tmpdir'"
        pkgtransfer, dofile(check_content.do)
        tempname fh
        file open `fh' using "check_content.do", read text
        file read `fh' line
        local found_install = 0
        while r(eof) == 0 {
            if strpos(`"`macval(line)'"', "install") > 0 {
                local found_install = 1
            }
            file read `fh' line
        }
        file close `fh'
        capture erase "check_content.do"
        quietly cd "`orig_dir'"
        assert `found_install' == 1
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' display "RESULT: [OK] `test_count'"
        else if `quiet' == 0 display as result "    PASSED"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' display "RESULT: [FAIL] `test_count'|`=_rc'|`test_desc'"
        else display as error "    FAILED: `test_desc'"
    }
}

* Test 22: SSC packages get ssc install command
local ++test_count
local test_desc "SSC packages use ssc install command"
_run_test `test_count' "`test_desc'"
if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        quietly cd "`tmpdir'"
        pkgtransfer, dofile(check_ssc.do)
        tempname fh
        file open `fh' using "check_ssc.do", read text
        file read `fh' line
        local found_ssc = 0
        local found_net = 0
        while r(eof) == 0 {
            if strpos(`"`macval(line)'"', "ssc install") > 0 {
                local found_ssc = 1
            }
            if strpos(`"`macval(line)'"', "net install") > 0 {
                local found_net = 1
            }
            file read `fh' line
        }
        file close `fh'
        capture erase "check_ssc.do"
        quietly cd "`orig_dir'"
        * At least one type of install command should be present
        assert (`found_ssc' == 1 | `found_net' == 1)
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' display "RESULT: [OK] `test_count'"
        else if `quiet' == 0 display as result "    PASSED"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' display "RESULT: [FAIL] `test_count'|`=_rc'|`test_desc'"
        else display as error "    FAILED: `test_desc'"
    }
}

* ============================================================
* SECTION 8: VALID OS OPTIONS
* ============================================================

* Test 23: os(Windows) accepted
local ++test_count
local test_desc "os(Windows) accepted without error"
_run_test `test_count' "`test_desc'"
if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        quietly cd "`tmpdir'"
        pkgtransfer, os(Windows)
        capture erase "pkgtransfer.do"
        quietly cd "`orig_dir'"
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' display "RESULT: [OK] `test_count'"
        else if `quiet' == 0 display as result "    PASSED"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' display "RESULT: [FAIL] `test_count'|`=_rc'|`test_desc'"
        else display as error "    FAILED: `test_desc'"
    }
}

* Test 24: os(Unix) accepted
local ++test_count
local test_desc "os(Unix) accepted without error"
_run_test `test_count' "`test_desc'"
if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        quietly cd "`tmpdir'"
        pkgtransfer, os(Unix)
        capture erase "pkgtransfer.do"
        quietly cd "`orig_dir'"
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' display "RESULT: [OK] `test_count'"
        else if `quiet' == 0 display as result "    PASSED"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' display "RESULT: [FAIL] `test_count'|`=_rc'|`test_desc'"
        else display as error "    FAILED: `test_desc'"
    }
}

* Test 25: os(MacOSX) accepted
local ++test_count
local test_desc "os(MacOSX) accepted without error"
_run_test `test_count' "`test_desc'"
if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        quietly cd "`tmpdir'"
        pkgtransfer, os(MacOSX)
        capture erase "pkgtransfer.do"
        quietly cd "`orig_dir'"
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' display "RESULT: [OK] `test_count'"
        else if `quiet' == 0 display as result "    PASSED"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' display "RESULT: [FAIL] `test_count'|`=_rc'|`test_desc'"
        else display as error "    FAILED: `test_desc'"
    }
}

* ============================================================
* SECTION 9: OFFLINE INSTALLER ARCHIVE CONTRACT
* ============================================================

* Test 26: Custom zipfile() is used by generated installer
local ++test_count
local test_desc "Custom zipfile() is quoted in generated installer"
_run_test `test_count' "`test_desc'"
if `run_only' == 0 | `run_only' == `test_count' {
    local test_rc 0
    local found_custom 0
    local found_default 0
    local original_plus "`c(sysdir_plus)'"
    local fixture_plus "`tmpdir'/fixture plus"
    local install_plus "`tmpdir'/install plus"
    tempname installer_fh
    tempname tracker_fh
    capture noisily {
        quietly cd "`tmpdir'"
        capture confirm file "custom installer.do"
        assert _rc == 601
        capture confirm file "custom archive.zip"
        assert _rc == 601
        local pre_output_dirs : dir "." dirs "pkgtransfer_files", ///
            respectcase
        assert `"`pre_output_dirs'"' == ""
        capture mkdir "`fixture_plus'"
        capture mkdir "`fixture_plus'/p"
        copy "`pkg_dir'/pkgtransfer.ado" ///
            "`fixture_plus'/p/pkgtransfer.ado", replace
        copy "`pkg_dir'/pkgtransfer.sthlp" ///
            "`fixture_plus'/p/pkgtransfer.sthlp", replace
        file open `tracker_fh' using "`fixture_plus'/stata.trk", ///
            write text replace
        file write `tracker_fh' "S `pkg_dir'" _n
        file write `tracker_fh' "N pkgtransfer.pkg" _n
        file write `tracker_fh' "d pkgtransfer fixture" _n
        file write `tracker_fh' "f p/pkgtransfer.ado" _n
        file write `tracker_fh' "f p/pkgtransfer.sthlp" _n
        file write `tracker_fh' "e" _n
        file close `tracker_fh'
        sysdir set PLUS "`fixture_plus'"
        pkgtransfer, download(local) limited(pkgtransfer) ///
            dofile("custom installer.do") zipfile("custom archive.zip")
        local returned_zip "`r(zipfile)'"
        confirm file "custom installer.do"
        confirm file "custom archive.zip"
        capture confirm file "pkgtransfer_files/pkgtransfer.ado"
        assert _rc == 601
        file open `installer_fh' using "custom installer.do", read text
        file read `installer_fh' line
        while r(eof) == 0 {
            if strpos(`"`macval(line)'"', `"unzipfile "custom archive.zip", replace"') {
                local found_custom 1
            }
            if strpos(`"`macval(line)'"', "pkgtransfer_files.zip") {
                local found_default 1
            }
            file read `installer_fh' line
        }
        file close `installer_fh'
        assert "`returned_zip'" == "custom archive.zip"
        assert `found_custom' == 1
        assert `found_default' == 0
        mkdir "`install_plus'"
        mkdir "`install_plus'/p"
        sysdir set PLUS "`install_plus'"
        do "custom installer.do"
        confirm file "pkgtransfer_files/pkgtransfer.ado"
        confirm file "pkgtransfer_files/pkgtransfer.sthlp"
        confirm file "pkgtransfer_files/pkgtransfer.pkg"
        confirm file "pkgtransfer_files/stata.toc"
        confirm file "`install_plus'/p/pkgtransfer.ado"
        confirm file "`install_plus'/p/pkgtransfer.sthlp"
        confirm file "`install_plus'/stata.trk"
    }
    local test_rc = _rc
    local cleanup_rc 0
    capture file close `installer_fh'
    capture file close `tracker_fh'
    capture sysdir set PLUS "`original_plus'"
    if _rc != 0 local cleanup_rc = _rc
    if "`c(sysdir_plus)'" != "`original_plus'" local cleanup_rc = 9
    capture quietly cd "`tmpdir'"
    if _rc != 0 local cleanup_rc = _rc

    foreach artifact in ///
        "pkgtransfer_files/pkgtransfer.ado" ///
        "pkgtransfer_files/pkgtransfer.sthlp" ///
        "pkgtransfer_files/pkgtransfer.pkg" ///
        "pkgtransfer_files/stata.toc" ///
        "custom installer.do" ///
        "custom archive.zip" ///
        "`fixture_plus'/p/pkgtransfer.ado" ///
        "`fixture_plus'/p/pkgtransfer.sthlp" ///
        "`fixture_plus'/stata.trk" ///
        "`install_plus'/p/pkgtransfer.ado" ///
        "`install_plus'/p/pkgtransfer.sthlp" ///
        "`install_plus'/stata.trk" {
        capture erase `"`artifact'"'
        capture confirm file `"`artifact'"'
        if _rc != 601 local cleanup_rc = 9
    }

    capture rmdir "pkgtransfer_files"
    capture mkdir "pkgtransfer_files"
    if _rc != 0 local cleanup_rc = 9
    else capture rmdir "pkgtransfer_files"

    capture rmdir "`fixture_plus'/p"
    capture mkdir "`fixture_plus'/p"
    if _rc != 0 local cleanup_rc = 9
    else capture rmdir "`fixture_plus'/p"
    capture rmdir "`fixture_plus'"
    capture mkdir "`fixture_plus'"
    if _rc != 0 local cleanup_rc = 9
    else capture rmdir "`fixture_plus'"

    capture rmdir "`install_plus'/p"
    capture mkdir "`install_plus'/p"
    if _rc != 0 local cleanup_rc = 9
    else capture rmdir "`install_plus'/p"
    capture rmdir "`install_plus'"
    capture mkdir "`install_plus'"
    if _rc != 0 local cleanup_rc = 9
    else capture rmdir "`install_plus'"

    capture quietly cd "`orig_dir'"
    if _rc != 0 local cleanup_rc = _rc
    if "`c(pwd)'" != "`orig_dir'" local cleanup_rc = 9
    if `test_rc' == 0 & `cleanup_rc' != 0 local test_rc = `cleanup_rc'

    if `test_rc' == 0 {
        local ++pass_count
        if `machine' display "RESULT: [OK] `test_count'"
        else if `quiet' == 0 display as result "    PASSED"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' display "RESULT: [FAIL] `test_count'|`test_rc'|`test_desc'"
        else display as error "    FAILED: `test_desc'"
    }
}

* ============================================================
* SECTION 10: RESTORE CONTRACT
* ============================================================

* Test 27: restore replaces local source from its saved online URL
local ++test_count
local test_desc "restore replaces local source and removes backup marker"
_run_test `test_count' "`test_desc'"
if `run_only' == 0 | `run_only' == `test_count' {
    local test_rc 0
    local restored_alpha 0
    local restored_pkgtransfer 0
    local retained_local_sources 0
    local retained_backup_marker 0
    local backup_local_sources 0
    local backup_markers 0
    local alpha_mapping 0
    local pkgtransfer_mapping 0
    local backup_alpha_mapping 0
    local backup_pkgtransfer_mapping 0
    tempname restore_fh
    capture noisily {
        quietly cd "`tmpdir'"
        capture confirm file "pkgtransfer.do"
        assert _rc == 601
        capture confirm file "pkgtransfer_files.zip"
        assert _rc == 601
        local pre_restore_dirs : dir "." dirs "pkgtransfer_files", ///
            respectcase
        assert `"`pre_restore_dirs'"' == ""

        file open `restore_fh' using "`qa_plus'/stata.trk", ///
            write text replace
        file write `restore_fh' "S `qa_plus'" _n
        file write `restore_fh' "N alpha.pkg" _n
        file write `restore_fh' "d alpha fixture" _n
        file write `restore_fh' "f a/alpha.ado" _n
        file write `restore_fh' ///
            "d S https://example.org/restored/alpha" _n
        file write `restore_fh' "e" _n
        file write `restore_fh' "S `qa_plus'" _n
        file write `restore_fh' "N pkgtransfer.pkg" _n
        file write `restore_fh' "d pkgtransfer fixture" _n
        file write `restore_fh' "f p/pkgtransfer.ado" _n
        file write `restore_fh' "f p/pkgtransfer.sthlp" _n
        file write `restore_fh' ///
            "d S https://example.org/restored/pkgtransfer" _n
        file write `restore_fh' "e" _n
        file close `restore_fh'

        pkgtransfer, restore
        assert "`r(download_mode)'" == "restore"
        confirm file "`qa_plus'/stata.trk.backup"
        capture confirm file "pkgtransfer.do"
        assert _rc == 601
        capture confirm file "pkgtransfer_files.zip"
        assert _rc == 601
        local post_restore_dirs : dir "." dirs "pkgtransfer_files", ///
            respectcase
        assert `"`post_restore_dirs'"' == ""

        file open `restore_fh' using "`qa_plus'/stata.trk", read text
        file read `restore_fh' line
        local active_source ""
        while r(eof) == 0 {
            if substr(`"`macval(line)'"', 1, 2) == "S " {
                local active_source `"`macval(line)'"'
            }
            if `"`macval(line)'"' == "N alpha.pkg" & ///
                `"`active_source'"' == ///
                "S https://example.org/restored/alpha" {
                local alpha_mapping 1
            }
            if `"`macval(line)'"' == "N pkgtransfer.pkg" & ///
                `"`active_source'"' == ///
                "S https://example.org/restored/pkgtransfer" {
                local pkgtransfer_mapping 1
            }
            if `"`macval(line)'"' == ///
                "S https://example.org/restored/alpha" {
                local restored_alpha 1
            }
            if `"`macval(line)'"' == ///
                "S https://example.org/restored/pkgtransfer" {
                local restored_pkgtransfer 1
            }
            if `"`macval(line)'"' == "S `qa_plus'" {
                local ++retained_local_sources
            }
            if substr(`"`macval(line)'"', 1, 4) == "d S " {
                local retained_backup_marker 1
            }
            file read `restore_fh' line
        }
        file close `restore_fh'
        assert `restored_alpha' == 1
        assert `restored_pkgtransfer' == 1
        assert `alpha_mapping' == 1
        assert `pkgtransfer_mapping' == 1
        assert `retained_local_sources' == 0
        assert `retained_backup_marker' == 0

        file open `restore_fh' using "`qa_plus'/stata.trk.backup", ///
            read text
        file read `restore_fh' line
        local backup_package ""
        while r(eof) == 0 {
            if substr(`"`macval(line)'"', 1, 2) == "N " {
                local backup_package `"`macval(line)'"'
            }
            if `"`macval(line)'"' == "S `qa_plus'" {
                local ++backup_local_sources
            }
            if substr(`"`macval(line)'"', 1, 4) == "d S " {
                local ++backup_markers
            }
            if `"`backup_package'"' == "N alpha.pkg" & ///
                `"`macval(line)'"' == ///
                "d S https://example.org/restored/alpha" {
                local backup_alpha_mapping 1
            }
            if `"`backup_package'"' == "N pkgtransfer.pkg" & ///
                `"`macval(line)'"' == ///
                "d S https://example.org/restored/pkgtransfer" {
                local backup_pkgtransfer_mapping 1
            }
            file read `restore_fh' line
        }
        file close `restore_fh'
        assert `backup_local_sources' == 2
        assert `backup_markers' == 2
        assert `backup_alpha_mapping' == 1
        assert `backup_pkgtransfer_mapping' == 1
        quietly cd "`orig_dir'"
    }
    local test_rc = _rc
    local cleanup_rc 0
    capture file close `restore_fh'
    capture quietly cd "`orig_dir'"
    if _rc != 0 local cleanup_rc = _rc
    if "`c(pwd)'" != "`orig_dir'" local cleanup_rc = 9
    if `test_rc' == 0 & `cleanup_rc' != 0 local test_rc = `cleanup_rc'

    if `test_rc' == 0 {
        local ++pass_count
        if `machine' display "RESULT: [OK] `test_count'"
        else if `quiet' == 0 display as result "    PASSED"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' display ///
            "RESULT: [FAIL] `test_count'|`test_rc'|`test_desc'"
        else display as error "    FAILED: `test_desc'"
    }
}

* ============================================================
* SECTION 11: OUTPUT OWNERSHIP AND CALLER STATE
* ============================================================

* Test 28: Existing staging directory is never reused or deleted
local ++test_count
local test_desc "Existing staging directory is preserved"
_run_test `test_count' "`test_desc'"
if `run_only' == 0 | `run_only' == `test_count' {
    local test_rc 0
    local cleanup_rc 0
    tempname sentinel_fh
    capture noisily {
        quietly cd "`tmpdir'"
        mkdir "pkgtransfer_files"
        file open `sentinel_fh' using ///
            "pkgtransfer_files/sentinel.txt", write text replace
        file write `sentinel_fh' "user-owned" _n
        file close `sentinel_fh'

        capture noisily pkgtransfer, download(local) ///
            limited(pkgtransfer) dofile(ownership.do) ///
            zipfile(ownership.zip)
        local command_rc = _rc
        assert `command_rc' == 602
        confirm file "pkgtransfer_files/sentinel.txt"
        file open `sentinel_fh' using ///
            "pkgtransfer_files/sentinel.txt", read text
        file read `sentinel_fh' sentinel_line
        file close `sentinel_fh'
        assert `"`macval(sentinel_line)'"' == "user-owned"
        capture confirm file "ownership.do"
        assert _rc == 601
        capture confirm file "ownership.zip"
        assert _rc == 601
    }
    local test_rc = _rc
    capture file close `sentinel_fh'
    capture erase "pkgtransfer_files/sentinel.txt"
    capture confirm file "pkgtransfer_files/sentinel.txt"
    if _rc != 601 local cleanup_rc = 9
    capture rmdir "pkgtransfer_files"
    local ownership_dirs : dir "." dirs "pkgtransfer_files", respectcase
    if `"`ownership_dirs'"' != "" local cleanup_rc = 9
    capture quietly cd "`orig_dir'"
    if _rc != 0 local cleanup_rc = _rc
    if "`c(pwd)'" != "`orig_dir'" local cleanup_rc = 9
    if `test_rc' == 0 & `cleanup_rc' != 0 local test_rc = `cleanup_rc'

    if `test_rc' == 0 {
        local ++pass_count
        if `machine' display "RESULT: [OK] `test_count'"
        else if `quiet' == 0 display as result "    PASSED"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' display ///
            "RESULT: [FAIL] `test_count'|`test_rc'|`test_desc'"
        else display as error "    FAILED: `test_desc'"
    }
}

* Test 29: A caller's active preserve survives an inner command error
local ++test_count
local test_desc "Caller preserve survives a post-preserve command error"
_run_test `test_count' "`test_desc'"
if `run_only' == 0 | `run_only' == `test_count' {
    local test_rc 0
    local cleanup_rc 0
    local caller_preserved 0
    capture noisily {
        quietly cd "`tmpdir'"
        clear
        set obs 1
        generate marker = 1
        preserve
        local caller_preserved 1
        replace marker = 2

        capture noisily pkgtransfer, ///
            dofile(missing_parent/nested_preserve.do)
        local command_rc = _rc
        assert `command_rc' == 603
        assert marker[1] == 2
        capture confirm file "missing_parent/nested_preserve.do"
        assert _rc == 601

        restore
        local caller_preserved 0
        assert marker[1] == 1
        quietly cd "`orig_dir'"
    }
    local test_rc = _rc
    if `caller_preserved' {
        capture restore
        if _rc != 0 local cleanup_rc = _rc
    }
    capture erase "`tmpdir'/missing_parent/nested_preserve.do"
    capture confirm file "`tmpdir'/missing_parent/nested_preserve.do"
    if _rc != 601 local cleanup_rc = 9
    capture quietly cd "`orig_dir'"
    if _rc != 0 local cleanup_rc = _rc
    if "`c(pwd)'" != "`orig_dir'" local cleanup_rc = 9
    if `test_rc' == 0 & `cleanup_rc' != 0 local test_rc = `cleanup_rc'

    if `test_rc' == 0 {
        local ++pass_count
        if `machine' display "RESULT: [OK] `test_count'"
        else if `quiet' == 0 display as result "    PASSED"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' display ///
            "RESULT: [FAIL] `test_count'|`test_rc'|`test_desc'"
        else display as error "    FAILED: `test_desc'"
    }
}

* Test 30: limited() and skip() cannot contradict one another
local ++test_count
local test_desc "limited() and skip() overlap is rejected"
_run_test `test_count' "`test_desc'"
if `run_only' == 0 | `run_only' == `test_count' {
    capture noisily {
        quietly cd "`tmpdir'"
        capture noisily pkgtransfer, limited(pkgtransfer) ///
            skip(pkgtransfer) dofile(overlap.do)
        local command_rc = _rc
        assert `command_rc' == 198
        capture confirm file "overlap.do"
        assert _rc == 601
        quietly cd "`orig_dir'"
    }
    local test_rc = _rc
    capture erase "`tmpdir'/overlap.do"
    capture quietly cd "`orig_dir'"
    if `test_rc' == 0 & _rc != 0 local test_rc = _rc

    if `test_rc' == 0 {
        local ++pass_count
        if `machine' display "RESULT: [OK] `test_count'"
        else if `quiet' == 0 display as result "    PASSED"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' display ///
            "RESULT: [FAIL] `test_count'|`test_rc'|`test_desc'"
        else display as error "    FAILED: `test_desc'"
    }
}

* Test 31: Post-staging errors remove invocation-owned staging files
local ++test_count
local test_desc "Post-staging error removes owned staging directory"
_run_test `test_count' "`test_desc'"
if `run_only' == 0 | `run_only' == `test_count' {
    capture noisily {
        quietly cd "`tmpdir'"
        capture noisily pkgtransfer, download(local) ///
            limited(pkgtransfer) ///
            dofile(missing_parent/staging.do) zipfile(staging.zip)
        local command_rc = _rc
        assert `command_rc' == 603
        local staging_dirs : dir "." dirs "pkgtransfer_files", ///
            respectcase
        assert `"`staging_dirs'"' == ""
        capture confirm file "staging.zip"
        assert _rc == 601
        quietly cd "`orig_dir'"
    }
    local test_rc = _rc
    capture noisily _pkgtransfer_cleanup_staging, ///
        directory("`tmpdir'/pkgtransfer_files")
    capture erase "`tmpdir'/staging.zip"
    capture quietly cd "`orig_dir'"
    if `test_rc' == 0 & _rc != 0 local test_rc = _rc

    if `test_rc' == 0 {
        local ++pass_count
        if `machine' display "RESULT: [OK] `test_count'"
        else if `quiet' == 0 display as result "    PASSED"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' display ///
            "RESULT: [FAIL] `test_count'|`test_rc'|`test_desc'"
        else display as error "    FAILED: `test_desc'"
    }
}

* Test 32: Installer generation cannot close a caller-owned file handle
local ++test_count
local test_desc "Caller file handle named inst remains open"
_run_test `test_count' "`test_desc'"
if `run_only' == 0 | `run_only' == `test_count' {
    local caller_handle_open 0
    capture noisily {
        quietly cd "`tmpdir'"
        file open inst using "caller_handle.txt", write text replace
        local caller_handle_open 1
        file write inst "before" _n
        pkgtransfer, download(local) limited(pkgtransfer) ///
            dofile(handle.do) zipfile(handle.zip)
        file write inst "after" _n
        file close inst
        local caller_handle_open 0

        tempname verify_handle
        file open `verify_handle' using "caller_handle.txt", read text
        file read `verify_handle' first_line
        file read `verify_handle' second_line
        file close `verify_handle'
        assert `"`macval(first_line)'"' == "before"
        assert `"`macval(second_line)'"' == "after"
        quietly cd "`orig_dir'"
    }
    local test_rc = _rc
    if `caller_handle_open' capture file close inst
    foreach artifact in caller_handle.txt handle.do handle.zip {
        capture erase "`tmpdir'/`artifact'"
    }
    capture quietly cd "`orig_dir'"
    if `test_rc' == 0 & _rc != 0 local test_rc = _rc

    if `test_rc' == 0 {
        local ++pass_count
        if `machine' display "RESULT: [OK] `test_count'"
        else if `quiet' == 0 display as result "    PASSED"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' display ///
            "RESULT: [FAIL] `test_count'|`test_rc'|`test_desc'"
        else display as error "    FAILED: `test_desc'"
    }
}

* Test 33: Missing tracked files fail instead of producing a partial archive
local ++test_count
local test_desc "Missing required package file aborts bundle creation"
_run_test `test_count' "`test_desc'"
if `run_only' == 0 | `run_only' == `test_count' {
    local test_rc 0
    local cleanup_rc 0
    capture noisily {
        quietly cd "`tmpdir'"
        erase "`qa_plus'/p/pkgtransfer.sthlp"
        capture noisily pkgtransfer, download(local) ///
            limited(pkgtransfer) dofile(missing_file.do) ///
            zipfile(missing_file.zip)
        local command_rc = _rc
        assert `command_rc' == 601
        local partial_dirs : dir "." dirs "pkgtransfer_files", ///
            respectcase
        assert `"`partial_dirs'"' == ""
        capture confirm file "missing_file.do"
        assert _rc == 601
        capture confirm file "missing_file.zip"
        assert _rc == 601
        quietly cd "`orig_dir'"
    }
    local test_rc = _rc
    capture copy "`pkg_dir'/pkgtransfer.sthlp" ///
        "`qa_plus'/p/pkgtransfer.sthlp", replace
    if _rc != 0 local cleanup_rc = _rc
    capture noisily _pkgtransfer_cleanup_staging, ///
        directory("`tmpdir'/pkgtransfer_files")
    foreach artifact in missing_file.do missing_file.zip {
        capture erase "`tmpdir'/`artifact'"
    }
    capture quietly cd "`orig_dir'"
    if _rc != 0 local cleanup_rc = _rc
    if `test_rc' == 0 & `cleanup_rc' != 0 local test_rc = `cleanup_rc'

    if `test_rc' == 0 {
        local ++pass_count
        if `machine' display "RESULT: [OK] `test_count'"
        else if `quiet' == 0 display as result "    PASSED"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' display ///
            "RESULT: [FAIL] `test_count'|`test_rc'|`test_desc'"
        else display as error "    FAILED: `test_desc'"
    }
}

* Test 34: Staging cleanup handles arbitrary nesting depth
local ++test_count
local test_desc "Owned staging cleanup is recursive"
_run_test `test_count' "`test_desc'"
if `run_only' == 0 | `run_only' == `test_count' {
    capture noisily {
        quietly cd "`tmpdir'"
        mkdir "cleanup_tree"
        mkdir "cleanup_tree/a"
        mkdir "cleanup_tree/a/b"
        mkdir "cleanup_tree/a/b/c"
        mkdir "cleanup_tree/a/b/c/d"
        tempname nested_fh
        file open `nested_fh' using ///
            "cleanup_tree/a/b/c/d/file.txt", write text replace
        file write `nested_fh' "nested" _n
        file close `nested_fh'
        _pkgtransfer_cleanup_staging, directory("cleanup_tree")
        local cleanup_dirs : dir "." dirs "cleanup_tree", respectcase
        assert `"`cleanup_dirs'"' == ""
        quietly cd "`orig_dir'"
    }
    local test_rc = _rc
    capture noisily _pkgtransfer_cleanup_staging, ///
        directory("`tmpdir'/cleanup_tree")
    capture quietly cd "`orig_dir'"
    if `test_rc' == 0 & _rc != 0 local test_rc = _rc

    if `test_rc' == 0 {
        local ++pass_count
        if `machine' display "RESULT: [OK] `test_count'"
        else if `quiet' == 0 display as result "    PASSED"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' display ///
            "RESULT: [FAIL] `test_count'|`test_rc'|`test_desc'"
        else display as error "    FAILED: `test_desc'"
    }
}

* Test 35: Filtering every package creates empty outputs and zero returns
local ++test_count
local test_desc "All-filtered selections create empty transfers"
_run_test `test_count' "`test_desc'"
if `run_only' == 0 | `run_only' == `test_count' {
    local test_rc 0
    local cleanup_rc 0
    capture noisily {
        quietly cd "`tmpdir'"
        local all_packages "alpha fre pkgtransfer"

        pkgtransfer, skip(`all_packages') dofile(empty_script.do)
        assert r(N_packages) == 0
        assert "`r(package_list)'" == ""
        assert "`r(download_mode)'" == "script_only"
        confirm file "empty_script.do"

        pkgtransfer, download(online) skip(`all_packages') ///
            dofile(empty_online.do) zipfile(empty_online.zip)
        assert r(N_packages) == 0
        assert "`r(package_list)'" == ""
        assert "`r(download_mode)'" == "online"
        confirm file "empty_online.do"
        confirm file "empty_online.zip"
        local online_staging : dir "." dirs "pkgtransfer_files", ///
            respectcase
        assert `"`online_staging'"' == ""
        mkdir "empty_online_extract"
        quietly cd "empty_online_extract"
        unzipfile "../empty_online.zip", replace
        confirm file "pkgtransfer_files/stata.toc"
        local online_pkg_files : dir "pkgtransfer_files" files "*.pkg", ///
            respectcase
        assert `"`online_pkg_files'"' == ""
        quietly cd "`tmpdir'"
        _pkgtransfer_cleanup_staging, ///
            directory("`tmpdir'/empty_online_extract")

        pkgtransfer, download(local) skip(`all_packages') ///
            dofile(empty_local.do) zipfile(empty_local.zip)
        assert r(N_packages) == 0
        assert "`r(package_list)'" == ""
        assert "`r(download_mode)'" == "local"
        confirm file "empty_local.do"
        confirm file "empty_local.zip"
        local local_staging : dir "." dirs "pkgtransfer_files", ///
            respectcase
        assert `"`local_staging'"' == ""
        mkdir "empty_local_extract"
        quietly cd "empty_local_extract"
        unzipfile "../empty_local.zip", replace
        confirm file "pkgtransfer_files/stata.toc"
        local local_pkg_files : dir "pkgtransfer_files" files "*.pkg", ///
            respectcase
        assert `"`local_pkg_files'"' == ""
        quietly cd "`tmpdir'"
        _pkgtransfer_cleanup_staging, ///
            directory("`tmpdir'/empty_local_extract")
        quietly cd "`orig_dir'"
    }
    local test_rc = _rc
    capture noisily _pkgtransfer_cleanup_staging, ///
        directory("`tmpdir'/pkgtransfer_files")
    foreach extract_dir in empty_online_extract empty_local_extract {
        capture quietly _pkgtransfer_cleanup_staging, ///
            directory("`tmpdir'/`extract_dir'")
    }
    foreach artifact in empty_script.do empty_online.do empty_online.zip ///
        empty_local.do empty_local.zip {
        capture erase "`tmpdir'/`artifact'"
    }
    capture quietly cd "`orig_dir'"
    if _rc != 0 local cleanup_rc = _rc
    if `test_rc' == 0 & `cleanup_rc' != 0 local test_rc = `cleanup_rc'

    if `test_rc' == 0 {
        local ++pass_count
        if `machine' display "RESULT: [OK] `test_count'"
        else if `quiet' == 0 display as result "    PASSED"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' display ///
            "RESULT: [FAIL] `test_count'|`test_rc'|`test_desc'"
        else display as error "    FAILED: `test_desc'"
    }
}

* Test 36: Local bundles preserve nested plugin sources from non-SSC packages
local ++test_count
local test_desc "Local plugin bundles preserve nested source paths"
_run_test `test_count' "`test_desc'"
if `run_only' == 0 | `run_only' == `test_count' {
    local test_rc 0
    local cleanup_rc 0
    local plugin_source "`tmpdir'/plugin_source"
    local plugin_extract "`tmpdir'/plugin_extract"
    local plugin_install_plus "`tmpdir'/plugin_install_plus"
    tempname source_pkg source_plugin installed_plugin installed_ado tracker ///
        plugin_pkg bundled_plugin installed_check
    capture noisily {
        quietly cd "`tmpdir'"
        mkdir "`plugin_source'"
        mkdir "`plugin_source'/plug-ins"
        mkdir "`plugin_source'/plug-ins/linux64"
        file open `source_plugin' using ///
            "`plugin_source'/plug-ins/linux64/pluginfixture.plugin", ///
            write text replace
        file write `source_plugin' "plugin fixture" _n
        file close `source_plugin'
        file open `source_pkg' using "`plugin_source'/pluginfixture.pkg", ///
            write text replace
        local tab = char(9)
        file write `source_pkg' "v 3" _n
        file write `source_pkg' "d plugin fixture" _n
        file write `source_pkg' ///
            "g LINUX64`tab'plug-ins/linux64/pluginfixture.plugin" _n
        file write `source_pkg' "h pluginfixture.plugin" _n
        file write `source_pkg' "f pluginfixture.ado" _n
        file close `source_pkg'

        mkdir "`qa_plus'/x"
        file open `installed_plugin' using ///
            "`qa_plus'/x/pluginfixture.plugin", write text replace
        file write `installed_plugin' "installed plugin fixture" _n
        file close `installed_plugin'
        file open `installed_ado' using ///
            "`qa_plus'/p/pluginfixture.ado", write text replace
        file write `installed_ado' "program define pluginfixture" _n
        file write `installed_ado' "end" _n
        file close `installed_ado'
        file open `tracker' using "`qa_plus'/stata.trk", ///
            write text append
        file write `tracker' "S `plugin_source'" _n
        file write `tracker' "N pluginfixture.pkg" _n
        file write `tracker' "d plugin fixture" _n
        file write `tracker' "f x/pluginfixture.plugin" _n
        file write `tracker' "f p/pluginfixture.ado" _n
        file write `tracker' "e" _n
        file close `tracker'

        pkgtransfer, download(local) limited(pluginfixture) ///
            dofile(plugin_local.do) zipfile(plugin_local.zip)
        confirm file "plugin_local.do"
        confirm file "plugin_local.zip"
        mkdir "`plugin_extract'"
        quietly cd "`plugin_extract'"
        unzipfile "../plugin_local.zip", replace
        confirm file "pkgtransfer_files/pluginfixture.pkg"
        confirm file ///
            "pkgtransfer_files/plug-ins/linux64/pluginfixture.plugin"
        file open `plugin_pkg' using ///
            "pkgtransfer_files/pluginfixture.pkg", read text
        local found_nested 0
        file read `plugin_pkg' line
        while r(eof) == 0 {
            if strpos(`"`macval(line)'"', ///
                "plug-ins/linux64/pluginfixture.plugin") local found_nested 1
            file read `plugin_pkg' line
        }
        file close `plugin_pkg'
        assert `found_nested' == 1
        file open `bundled_plugin' using ///
            "pkgtransfer_files/plug-ins/linux64/pluginfixture.plugin", ///
            read text
        file read `bundled_plugin' bundled_line
        file close `bundled_plugin'
        assert `"`macval(bundled_line)'"' == "plugin fixture"

        quietly cd "`tmpdir'"
        mkdir "`plugin_install_plus'"
        mkdir "`plugin_install_plus'/p"
        sysdir set PLUS "`plugin_install_plus'"
        do plugin_local.do
        confirm file "`plugin_install_plus'/p/pluginfixture.plugin"
        file open `installed_check' using ///
            "`plugin_install_plus'/p/pluginfixture.plugin", read text
        file read `installed_check' installed_line
        file close `installed_check'
        assert `"`macval(installed_line)'"' == "plugin fixture"
        sysdir set PLUS "`qa_plus'"
        quietly cd "`orig_dir'"
    }
    local test_rc = _rc
    foreach handle in source_pkg source_plugin installed_plugin installed_ado ///
        tracker plugin_pkg bundled_plugin installed_check {
        capture file close ``handle''
    }
    capture sysdir set PLUS "`qa_plus'"
    if _rc != 0 local cleanup_rc = _rc
    capture quietly cd "`tmpdir'"
    if _rc != 0 local cleanup_rc = _rc
    foreach path in pkgtransfer_files `plugin_extract' `plugin_source' ///
        `plugin_install_plus' {
        capture quietly _pkgtransfer_cleanup_staging, ///
            directory("`path'")
    }
    foreach artifact in plugin_local.do plugin_local.zip {
        capture erase "`artifact'"
    }
    capture quietly cd "`orig_dir'"
    if _rc != 0 local cleanup_rc = _rc
    if `test_rc' == 0 & `cleanup_rc' != 0 local test_rc = `cleanup_rc'

    if `test_rc' == 0 {
        local ++pass_count
        if `machine' display "RESULT: [OK] `test_count'"
        else if `quiet' == 0 display as result "    PASSED"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' display ///
            "RESULT: [FAIL] `test_count'|`test_rc'|`test_desc'"
        else display as error "    FAILED: `test_desc'"
    }
}

capture noisily _pkgtransfer_qa_cleanup, root("`qa_root'") ///
    originalplus("`qa_original_plus'")
if _rc != 0 {
    local ++fail_count
    local failed_tests "`failed_tests' fixture_cleanup"
    display as error "QA fixture cleanup failed with rc `=_rc'"
}

* ============================================================
* SUMMARY
* ============================================================

display ""
display as text "pkgtransfer v1.0.3 - Test Results"
display as text "Tests run:    `test_count'"
display as result "Tests passed: `pass_count'"
if `fail_count' > 0 {
    display as error "Tests failed: `fail_count'"
    display as error "Failed tests: `failed_tests'"
}
else {
    display as result "Tests failed: 0"
}
display ""
if `fail_count' > 0 {
    display as error "RESULT: FAIL"
    exit 9
}
else {
    display as result "RESULT: PASS"
}
