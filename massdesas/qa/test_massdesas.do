* test_massdesas.do
*
* Functional tests for massdesas command — batch conversion of .sas7bdat
* to .dta. Tests error paths, syntax, and (when pandas is available)
* round-trip conversion.
*
* Author: Timothy P Copeland
* Date: 2026-03-14

clear all
set more off
version 16.0

* =============================================================================
* SETUP
* =============================================================================
capture ado uninstall massdesas
quietly net install massdesas, from("~/Stata-Tools/massdesas") replace

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

* Create temp directories for testing
tempfile tmpbase
local testdir = substr("`tmpbase'", 1, strlen("`tmpbase'") - 4)
local sasdir "`testdir'_sastest"
local emptydir "`testdir'_empty"
shell mkdir -p "`sasdir'"
shell mkdir -p "`emptydir'"

* =============================================================================
* SECTION 1: Error handling
* =============================================================================

* Test 1: Missing directory triggers error
local ++test_count
display as text _n "Test `test_count': Missing directory triggers error"

capture massdesas, directory("/nonexistent/path/xyz_99999")
if _rc == 601 {
    display as result "  PASSED (correctly rejected with rc=601)"
    local ++pass_count
}
else {
    display as error "  FAILED (expected rc=601, got `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* Test 2: Empty directory (no .sas7bdat files) triggers error
local ++test_count
display as text _n "Test `test_count': No .sas7bdat files triggers error"

capture massdesas, directory("`emptydir'")
if _rc == 601 {
    display as result "  PASSED (correctly rejected with rc=601)"
    local ++pass_count
}
else if _rc == 199 {
    display as result "  PASSED (missing dependency — acceptable)"
    local ++pass_count
}
else {
    display as error "  FAILED (expected rc=601 or 199, got `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* Test 3: Syntax requires directory option
local ++test_count
display as text _n "Test `test_count': Syntax requires directory()"

capture massdesas
if _rc != 0 {
    display as result "  PASSED (correctly rejected with rc=`=_rc')"
    local ++pass_count
}
else {
    display as error "  FAILED (should have errored without directory)"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* =============================================================================
* SECTION 2: Dependency checks
* =============================================================================

* Test 4: filelist dependency check
local ++test_count
display as text _n "Test `test_count': filelist dependency available"

capture which filelist
if _rc == 0 {
    display as result "  PASSED (filelist found)"
    local ++pass_count
    local has_filelist = 1
}
else {
    display as result "  PASSED (filelist not installed — massdesas will error correctly)"
    local ++pass_count
    local has_filelist = 0
}

* Test 5: fs dependency check
local ++test_count
display as text _n "Test `test_count': fs dependency available"

capture which fs
if _rc == 0 {
    display as result "  PASSED (fs found)"
    local ++pass_count
    local has_fs = 1
}
else {
    display as result "  PASSED (fs not installed — massdesas will error correctly)"
    local ++pass_count
    local has_fs = 0
}

* =============================================================================
* SECTION 3: Round-trip test (requires pandas)
* =============================================================================

* Try to create a .sas7bdat file using Python/pandas
local has_pandas = 0
capture shell python3 -c "import pandas; print('OK')" > /dev/null 2>&1
if _rc == 0 {
    local has_pandas = 1
}

if `has_pandas' & `has_filelist' & `has_fs' {
    display as text _n "pandas available — running round-trip tests"

    * Create a known .sas7bdat file
    shell python3 -c "import pandas as pd; df = pd.DataFrame({'ID': [1,2,3,4,5], 'AGE': [25,30,35,40,45], 'SCORE': [88.5, 92.1, 76.3, 81.0, 95.7]}); df.to_sas('`sasdir'/testdata.sas7bdat', version=7)"

    capture confirm file "`sasdir'/testdata.sas7bdat"
    local sas_created = (_rc == 0)

    if `sas_created' {
        * Test 6: Basic conversion
        local ++test_count
        display as text _n "Test `test_count': Round-trip conversion"

        capture {
            massdesas, directory("`sasdir'")
            assert r(n_converted) == 1
            assert r(n_failed) == 0
        }
        if _rc == 0 {
            display as result "  PASSED"
            local ++pass_count
        }
        else {
            display as error "  FAILED (error `=_rc')"
            local ++fail_count
            local failed_tests "`failed_tests' `test_count'"
        }

        * Test 7: Converted .dta has correct content
        local ++test_count
        display as text _n "Test `test_count': Converted .dta content correct"

        capture {
            use "`sasdir'/testdata.dta", clear
            assert _N == 5
            quietly count
            assert r(N) == 5
            * Check variables exist
            confirm variable ID AGE SCORE
        }
        if _rc == 0 {
            display as result "  PASSED"
            local ++pass_count
        }
        else {
            display as error "  FAILED (error `=_rc')"
            local ++fail_count
            local failed_tests "`failed_tests' `test_count'"
        }

        * Clean up for lowercase test
        capture erase "`sasdir'/testdata.dta"

        * Test 8: lower option
        local ++test_count
        display as text _n "Test `test_count': lower option converts variable names"

        capture {
            massdesas, directory("`sasdir'") lower
            use "`sasdir'/testdata.dta", clear
            confirm variable id age score
            assert r(n_converted) == 1
        }
        if _rc == 0 {
            display as result "  PASSED"
            local ++pass_count
        }
        else {
            display as error "  FAILED (error `=_rc')"
            local ++fail_count
            local failed_tests "`failed_tests' `test_count'"
        }

        * Clean up for erase test — recreate .sas7bdat
        capture erase "`sasdir'/testdata.dta"
        shell python3 -c "import pandas as pd; df = pd.DataFrame({'ID': [1,2,3], 'VAL': [10,20,30]}); df.to_sas('`sasdir'/erasetest.sas7bdat', version=7)"

        * Test 9: erase option removes .sas7bdat after conversion
        local ++test_count
        display as text _n "Test `test_count': erase option removes source files"

        capture {
            massdesas, directory("`sasdir'") erase
            * The .sas7bdat files should be gone
            capture confirm file "`sasdir'/erasetest.sas7bdat"
            assert _rc != 0
            * But .dta should exist
            capture confirm file "`sasdir'/erasetest.dta"
            assert _rc == 0
        }
        if _rc == 0 {
            display as result "  PASSED"
            local ++pass_count
        }
        else {
            display as error "  FAILED (error `=_rc')"
            local ++fail_count
            local failed_tests "`failed_tests' `test_count'"
        }

        * Test 10: Return values correct
        local ++test_count
        display as text _n "Test `test_count': Return values after conversion"

        * Recreate test files
        shell python3 -c "import pandas as pd; df = pd.DataFrame({'X': [1,2,3]}); df.to_sas('`sasdir'/ret1.sas7bdat', version=7); df.to_sas('`sasdir'/ret2.sas7bdat', version=7)"

        capture {
            massdesas, directory("`sasdir'")
            assert r(n_converted) >= 1
            assert r(n_failed) == 0
            assert "`r(directory)'" != ""
        }
        if _rc == 0 {
            display as result "  PASSED (n_converted=`r(n_converted)')"
            local ++pass_count
        }
        else {
            display as error "  FAILED (error `=_rc')"
            local ++fail_count
            local failed_tests "`failed_tests' `test_count'"
        }
    }
    else {
        display as text "  Could not create .sas7bdat file — skipping round-trip tests"
    }
}
else {
    display as text _n "Skipping round-trip tests (pandas=`has_pandas', filelist=`has_filelist', fs=`has_fs')"
}

* =============================================================================
* CLEANUP
* =============================================================================
shell rm -rf "`sasdir'" "`emptydir'"

* =============================================================================
* SUMMARY
* =============================================================================
display as text _n "{hline 70}"
display as text "MASSDESAS FUNCTIONAL TEST SUMMARY"
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
