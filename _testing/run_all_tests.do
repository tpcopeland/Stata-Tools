/*******************************************************************************
* run_all_tests.do
*
* Purpose: Master test runner for all Stata-Tools packages
*          Runs all test files and provides summary of results
*
* Prerequisites:
*   - Run generate_test_data.do first to create synthetic datasets
*   - All package .ado files must be accessible (on adopath)
*
* Author: Timothy P Copeland
* Date: 2025-12-08
*******************************************************************************/

clear all
set more off
version 16.0

* =============================================================================
* SETUP: Change to data directory and install packages from local repository
* =============================================================================

* Data directory for test datasets
cd "/Users/tcopeland/Documents/GitHub/Stata-Tools/_testing/data/"

local testdir "`c(pwd)'"
local basedir "/Users/tcopeland/Documents/GitHub/Stata-Tools"

display as text _n "{hline 70}"
display as text "STATA-TOOLS COMPREHENSIVE TEST SUITE"
display as text "{hline 70}"
display as text "Test directory: `testdir'"
display as text "Date: `c(current_date)' `c(current_time)'"
display as text "{hline 70}"

* =============================================================================
* SETUP: Install all packages from local repository
* =============================================================================
display as text _n "Installing packages from local repository..."

local packages "tvtools datamap synthdata mvp table1_tc consort regtab cstat_surv stratetab compress_tc datefix check today setools"

foreach pkg of local packages {
    display as text "  Installing: `pkg'"
    capture net uninstall `pkg'
    capture noisily net install `pkg', from("`basedir'/`pkg'")
}

* =============================================================================
* SETUP: Verify test data exists
* =============================================================================
display as text _n "Checking prerequisites..."

capture confirm file "`testdir'/cohort.dta"
if _rc {
    display as text "Test data not found. Generating..."
    capture noisily do "`basedir'/_testing/generate_test_data.do"
    if _rc {
        display as error "ERROR: Could not generate test data"
        exit _rc
    }
    display as result "Test data generated successfully"
}
else {
    display as result "Test data found"
}

* =============================================================================
* DEFINE TEST FILES
* =============================================================================

* Order matters for some tests (tvtools must run in sequence)
local test_files ""

* tvtools suite (must run in order)
local test_files "`test_files' test_tvexpose"
local test_files "`test_files' test_tvmerge"
local test_files "`test_files' test_tvevent"

* Data management commands
local test_files "`test_files' test_datamap"
local test_files "`test_files' test_datadict"
local test_files "`test_files' test_synthdata"
local test_files "`test_files' test_mvp"
local test_files "`test_files' test_compress_tc"
local test_files "`test_files' test_datefix"
local test_files "`test_files' test_check"
local test_files "`test_files' test_today"

* Analysis commands
local test_files "`test_files' test_table1_tc"
local test_files "`test_files' test_consort"
local test_files "`test_files' test_consortq"
local test_files "`test_files' test_regtab"
local test_files "`test_files' test_cstat_surv"
local test_files "`test_files' test_stratetab"

* Specialized commands
local test_files "`test_files' test_migrations"
local test_files "`test_files' test_sustainedss"

* =============================================================================
* RUN ALL TESTS
* =============================================================================
display as text _n "{hline 70}"
display as text "RUNNING TESTS"
display as text "{hline 70}"

local total_files = 0
local passed_files = 0
local failed_files = 0
local failed_list ""

foreach test of local test_files {
    local ++total_files

    display as text _n "{hline 50}"
    display as text "Running: `test'.do"
    display as text "{hline 50}"

    capture confirm file "`testdir'/`test'.do"
    if _rc {
        display as error "  FILE NOT FOUND: `test'.do"
        local ++failed_files
        local failed_list "`failed_list' `test'"
        continue
    }

    capture noisily do "`testdir'/`test'.do"
    local rc = _rc

    if `rc' == 0 {
        display as result "  PASSED: `test'.do"
        local ++passed_files
    }
    else {
        display as error "  FAILED: `test'.do (error `rc')"
        local ++failed_files
        local failed_list "`failed_list' `test'"
    }
}

* =============================================================================
* SUMMARY
* =============================================================================
display as text _n "{hline 70}"
display as text "COMPREHENSIVE TEST SUMMARY"
display as text "{hline 70}"
display as text "Total test files:  `total_files'"
display as result "Passed:            `passed_files'"
if `failed_files' > 0 {
    display as error "Failed:            `failed_files'"
}
else {
    display as text "Failed:            `failed_files'"
}
display as text "{hline 70}"

if `failed_files' > 0 {
    display as error _n "FAILED TEST FILES:"
    foreach f of local failed_list {
        display as error "  - `f'.do"
    }
    display as text "{hline 70}"
    display as error "Some tests FAILED. Review output above for details."
}
else {
    display as result _n "ALL TESTS PASSED!"
}

display as text _n "Test run completed: `c(current_date)' `c(current_time)'"
display as text "{hline 70}"
