/*******************************************************************************
* validation_pkgtransfer.do
* Known-answer validation tests for pkgtransfer command
*
* Purpose: Verify that pkgtransfer produces correct, verifiable output files
*          and return values — not just error handling but actual content checks.
*
* Author: Timothy Copeland
* Date: 2026-03-13
*******************************************************************************/

clear all
set more off
version 16.0

* Set up validation environment
if "`c(os)'" == "MacOSX" {
    local pkg_dir "~/Stata-Tools/pkgtransfer"
}
else {
    local pkg_dir "~/Stata-Tools/pkgtransfer"
}
adopath ++ "`pkg_dir'"
capture program drop pkgtransfer
run "`pkg_dir'/pkgtransfer.ado"

capture log close _all
log using "`pkg_dir'/qa/validation_pkgtransfer.log", replace text nomsg name(val_pkgtransfer)

display _n "{hline 70}"
display "PKGTRANSFER VALIDATION TESTS"
display "Date: `c(current_date)' `c(current_time)'"
display "{hline 70}" _n

local n_tests 0
local n_passed 0
local n_failed 0

* Save working directory
local orig_dir "`c(pwd)'"
tempfile tmpdir_marker
local tmpdir = substr("`tmpdir_marker'", 1, length("`tmpdir_marker'") - length(regexr("`tmpdir_marker'", "^.+[/\\]", "")))

* =============================================================================
* VALIDATION 1: Every returned package appears in the do-file
* =============================================================================
display _n "{bf:VALIDATION 1: Every returned package appears in the do-file}"
local ++n_tests

capture {
    quietly cd "`tmpdir'"
    pkgtransfer, dofile(val1.do)
    local n_pkgs = r(N_packages)
    local plist "`r(package_list)'"

    * Read entire do-file content
    tempname fh
    file open `fh' using "val1.do", read text
    file read `fh' line
    local file_content ""
    while r(eof) == 0 {
        local file_content `"`file_content' `macval(line)'"'
        file read `fh' line
    }
    file close `fh'

    * Verify each package from return list appears in file with install command
    local n_found = 0
    foreach pkg of local plist {
        if strpos(`"`file_content'"', "install `pkg'") > 0 {
            local ++n_found
        }
    }

    assert `n_found' == `n_pkgs'
    capture erase "val1.do"
    quietly cd "`orig_dir'"
}

if _rc == 0 {
    display as result "  PASSED: All `n_pkgs' packages found in do-file"
    local ++n_passed
}
else {
    display as error "  FAILED: `n_found'/`n_pkgs' packages found in do-file"
    local ++n_failed
}

* =============================================================================
* VALIDATION 2: SSC packages use "ssc install" command
* =============================================================================
display _n "{bf:VALIDATION 2: SSC packages use ssc install}"
local ++n_tests

capture {
    quietly cd "`tmpdir'"
    pkgtransfer, dofile(val2.do)

    * Read file and check: lines with fmwww.bc.edu should NOT exist
    * (because SSC packages use "ssc install", not "net install ... from(fmwww)")
    tempname fh
    file open `fh' using "val2.do", read text
    file read `fh' line
    local found_ssc_as_net = 0
    while r(eof) == 0 {
        if strpos(`"`macval(line)'"', "net install") > 0 & strpos(`"`macval(line)'"', "fmwww.bc.edu") > 0 {
            local found_ssc_as_net = 1
        }
        file read `fh' line
    }
    file close `fh'

    * No SSC package should appear as "net install ... from(fmwww...)"
    assert `found_ssc_as_net' == 0
    capture erase "val2.do"
    quietly cd "`orig_dir'"
}

if _rc == 0 {
    display as result "  PASSED: No SSC packages using net install with bc.edu URL"
    local ++n_passed
}
else {
    display as error "  FAILED: Found SSC package using net install instead of ssc install"
    local ++n_failed
}

* =============================================================================
* VALIDATION 3: limited() output contains exactly the specified package
* =============================================================================
display _n "{bf:VALIDATION 3: limited() do-file contains only specified package}"
local ++n_tests

capture {
    quietly cd "`tmpdir'"

    * Get all packages first
    pkgtransfer, dofile(val3_all.do)
    local all_list "`r(package_list)'"
    local first_pkg : word 1 of `all_list'
    capture erase "val3_all.do"

    * Run limited
    pkgtransfer, limited(`first_pkg') dofile(val3_limited.do)

    * Read file: every install line should contain the target package
    tempname fh
    file open `fh' using "val3_limited.do", read text
    file read `fh' line
    local n_install = 0
    local n_correct = 0
    while r(eof) == 0 {
        if strpos(`"`macval(line)'"', " install ") > 0 {
            local ++n_install
            if strpos(`"`macval(line)'"', "`first_pkg'") > 0 {
                local ++n_correct
            }
        }
        file read `fh' line
    }
    file close `fh'

    assert `n_install' == 1
    assert `n_correct' == 1
    capture erase "val3_limited.do"
    quietly cd "`orig_dir'"
}

if _rc == 0 {
    display as result "  PASSED: limited(`first_pkg') produced exactly 1 correct install line"
    local ++n_passed
}
else {
    display as error "  FAILED: limited() produced `n_install' lines, `n_correct' correct"
    local ++n_failed
}

* =============================================================================
* VALIDATION 4: skip() removes exactly the skipped package
* =============================================================================
display _n "{bf:VALIDATION 4: skip() removes target from do-file}"
local ++n_tests

capture {
    quietly cd "`tmpdir'"

    * Get all packages
    pkgtransfer, dofile(val4_all.do)
    local all_list "`r(package_list)'"
    local n_all = r(N_packages)
    local skip_pkg : word 1 of `all_list'
    capture erase "val4_all.do"

    * Run with skip
    pkgtransfer, skip(`skip_pkg') dofile(val4_skip.do)
    local n_skip = r(N_packages)

    * Read file: no line should contain the skipped package name as an install target
    tempname fh
    file open `fh' using "val4_skip.do", read text
    file read `fh' line
    local found_skipped = 0
    while r(eof) == 0 {
        if strpos(`"`macval(line)'"', " install `skip_pkg'") > 0 | ///
           strpos(`"`macval(line)'"', " install `skip_pkg',") > 0 {
            local found_skipped = 1
        }
        file read `fh' line
    }
    file close `fh'

    assert `n_skip' == `n_all' - 1
    assert `found_skipped' == 0
    capture erase "val4_skip.do"
    quietly cd "`orig_dir'"
}

if _rc == 0 {
    display as result "  PASSED: skip(`skip_pkg') removed package (`n_all' -> `n_skip')"
    local ++n_passed
}
else {
    display as error "  FAILED: skip() did not correctly remove package"
    local ++n_failed
}

* =============================================================================
* VALIDATION 5: Return values internally consistent
* =============================================================================
display _n "{bf:VALIDATION 5: r(N_packages) == wordcount(r(package_list))}"
local ++n_tests

capture {
    quietly cd "`tmpdir'"

    pkgtransfer, dofile(val5.do)
    local n_ret = r(N_packages)
    local plist "`r(package_list)'"
    local n_words : word count `plist'

    * Each package name in the list should be non-empty
    local all_nonempty = 1
    forvalues w = 1/`n_words' {
        local this_word : word `w' of `plist'
        if "`this_word'" == "" local all_nonempty = 0
    }

    assert `n_ret' == `n_words'
    assert `all_nonempty' == 1
    assert `n_ret' > 0

    capture erase "val5.do"
    quietly cd "`orig_dir'"
}

if _rc == 0 {
    display as result "  PASSED: r(N_packages) = `n_ret', wordcount = `n_words', all non-empty"
    local ++n_passed
}
else {
    display as error "  FAILED: r(N_packages)=`n_ret' vs wordcount=`n_words'"
    local ++n_failed
}

* =============================================================================
* VALIDATION 6: Each install command has valid syntax structure
* =============================================================================
display _n "{bf:VALIDATION 6: Every install command has valid structure}"
local ++n_tests

capture {
    quietly cd "`tmpdir'"
    pkgtransfer, dofile(val6.do)

    tempname fh
    file open `fh' using "val6.do", read text
    file read `fh' line
    local n_checked = 0
    local n_valid = 0
    while r(eof) == 0 {
        if strpos(`"`macval(line)'"', " install ") > 0 {
            local ++n_checked
            * Must be one of: "ssc install X, replace"
            *                 "net install X, replace from(...)"
            *                 "github install user/X, stable replace"
            local is_valid = 0
            if strpos(`"`macval(line)'"', "ssc install") > 0 & ///
               strpos(`"`macval(line)'"', ", replace") > 0 {
                local is_valid = 1
            }
            if strpos(`"`macval(line)'"', "net install") > 0 & ///
               strpos(`"`macval(line)'"', "from(") > 0 {
                local is_valid = 1
            }
            if strpos(`"`macval(line)'"', "github install") > 0 & ///
               strpos(`"`macval(line)'"', "stable") > 0 {
                local is_valid = 1
            }
            if `is_valid' local ++n_valid
        }
        file read `fh' line
    }
    file close `fh'

    assert `n_checked' > 0
    assert `n_valid' == `n_checked'
    capture erase "val6.do"
    quietly cd "`orig_dir'"
}

if _rc == 0 {
    display as result "  PASSED: All `n_checked' install commands have valid syntax"
    local ++n_passed
}
else {
    display as error "  FAILED: `n_valid'/`n_checked' commands valid"
    local ++n_failed
}

* =============================================================================
* VALIDATION 7: Data in memory unchanged after pkgtransfer
* =============================================================================
display _n "{bf:VALIDATION 7: Data in memory is byte-identical after run}"
local ++n_tests

capture {
    sysuse auto, clear
    local N_before = _N

    * Save snapshot for comparison
    tempfile data_before
    quietly save "`data_before'"

    quietly cd "`tmpdir'"
    pkgtransfer, dofile(val7.do)
    capture erase "val7.do"
    quietly cd "`orig_dir'"

    * Verify data identical via cf
    assert _N == `N_before'
    cf _all using "`data_before'"
}

if _rc == 0 {
    display as result "  PASSED: Data identical after pkgtransfer (N=`N_before')"
    local ++n_passed
}
else {
    display as error "  FAILED: Data changed after pkgtransfer"
    local ++n_failed
}

* =============================================================================
* VALIDATION 8: Multiple limited() packages all present
* =============================================================================
display _n "{bf:VALIDATION 8: limited() with 2 packages returns both}"
local ++n_tests

capture {
    quietly cd "`tmpdir'"

    * Get all packages
    pkgtransfer, dofile(val8_all.do)
    local all_list "`r(package_list)'"
    local n_all = r(N_packages)
    capture erase "val8_all.do"

    * Need at least 2 packages
    assert `n_all' >= 2
    local pkg1 : word 1 of `all_list'
    local pkg2 : word 2 of `all_list'

    * Run with two limited packages
    pkgtransfer, limited(`pkg1' `pkg2') dofile(val8_limited.do)
    assert r(N_packages) == 2

    * Verify both appear in the do-file
    tempname fh
    file open `fh' using "val8_limited.do", read text
    file read `fh' line
    local found_pkg1 = 0
    local found_pkg2 = 0
    while r(eof) == 0 {
        if strpos(`"`macval(line)'"', "`pkg1'") > 0 & strpos(`"`macval(line)'"', "install") > 0 {
            local found_pkg1 = 1
        }
        if strpos(`"`macval(line)'"', "`pkg2'") > 0 & strpos(`"`macval(line)'"', "install") > 0 {
            local found_pkg2 = 1
        }
        file read `fh' line
    }
    file close `fh'

    assert `found_pkg1' == 1
    assert `found_pkg2' == 1
    capture erase "val8_limited.do"
    quietly cd "`orig_dir'"
}

if _rc == 0 {
    display as result "  PASSED: Both `pkg1' and `pkg2' present in limited output"
    local ++n_passed
}
else {
    display as error "  FAILED: limited() with 2 packages — pkg1=`found_pkg1', pkg2=`found_pkg2'"
    local ++n_failed
}

* =============================================================================
* VALIDATION 9: Custom dofile name produces correct r(dofile)
* =============================================================================
display _n "{bf:VALIDATION 9: Custom dofile name in return value}"
local ++n_tests

capture {
    quietly cd "`tmpdir'"
    pkgtransfer, dofile(my_custom_transfer.do)
    assert "`r(dofile)'" == "my_custom_transfer.do"
    confirm file "my_custom_transfer.do"
    capture erase "my_custom_transfer.do"
    quietly cd "`orig_dir'"
}

if _rc == 0 {
    display as result "  PASSED: r(dofile) = my_custom_transfer.do"
    local ++n_passed
}
else {
    display as error "  FAILED: r(dofile) = `r(dofile)'"
    local ++n_failed
}

* =============================================================================
* VALIDATION 10: Default download_mode is "script_only"
* =============================================================================
display _n "{bf:VALIDATION 10: Default download_mode is script_only}"
local ++n_tests

capture {
    quietly cd "`tmpdir'"
    pkgtransfer, dofile(val10.do)
    assert "`r(download_mode)'" == "script_only"
    assert "`r(zipfile)'" == ""
    capture erase "val10.do"
    quietly cd "`orig_dir'"
}

if _rc == 0 {
    display as result "  PASSED: r(download_mode) = script_only, r(zipfile) empty"
    local ++n_passed
}
else {
    display as error "  FAILED: r(download_mode) = `r(download_mode)'"
    local ++n_failed
}

* =============================================================================
* SUMMARY
* =============================================================================

display _n "{hline 70}"
display "PKGTRANSFER VALIDATION SUMMARY"
display "{hline 70}"
display as text "Tests run:    `n_tests'"
display as result "Tests passed: `n_passed'"
if `n_failed' > 0 {
    display as error "Tests failed: `n_failed'"
}
else {
    display as result "Tests failed: 0"
}
display ""
if `n_failed' > 0 {
    display as error "RESULT: FAIL"
}
else {
    display as result "RESULT: PASS"
}

log close val_pkgtransfer
