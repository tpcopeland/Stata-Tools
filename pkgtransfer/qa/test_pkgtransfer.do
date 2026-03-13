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
capture ado uninstall pkgtransfer
if "`c(os)'" == "MacOSX" {
    local pkg_dir "~/Stata-Tools/pkgtransfer"
}
else {
    local pkg_dir "~/Stata-Tools/pkgtransfer"
}
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

* Save working directory and create temp dir for file output tests
local orig_dir "`c(pwd)'"
tempfile tmpdir_marker
local tmpdir = substr("`tmpdir_marker'", 1, length("`tmpdir_marker'") - length(regexr("`tmpdir_marker'", "^.+[/\\]", "")))

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
* SUMMARY
* ============================================================

display ""
display as text "pkgtransfer v1.0.4 - Test Results"
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
