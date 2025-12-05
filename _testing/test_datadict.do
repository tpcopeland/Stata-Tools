/*******************************************************************************
* test_datadict.do
*
* Purpose: Comprehensive testing of datadict command
*          Tests all options and common combinations
*
* Prerequisites:
*   - Run generate_test_data.do first to create synthetic datasets
*   - datadict.ado must be installed/accessible
*
* Author: Timothy P Copeland
* Date: 2025-12-05
*******************************************************************************/

clear all
set more off
version 16.0

* Get directory of this do file
local testdir = c(pwd)

* Check for required test data
capture confirm file "`testdir'/cohort.dta"
if _rc {
    display as error "Test data not found. Run generate_test_data.do first."
    exit 601
}

display as text _n "{hline 70}"
display as text "DATADICT COMMAND TESTING"
display as text "{hline 70}"
display as text "Test directory: `testdir'"
display as text "{hline 70}"

local test_count = 0
local pass_count = 0
local fail_count = 0

* =============================================================================
* TEST 1: Basic single dataset documentation
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Basic single dataset documentation"
display as text "{hline 50}"

capture noisily {
    datadict, single("`testdir'/cohort") output("`testdir'/_test_datadict.md")

    * Check output file exists
    confirm file "`testdir'/_test_datadict.md"
    display as result "  PASSED: Single dataset documentation works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 2: Custom title
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Custom title"
display as text "{hline 50}"

capture noisily {
    datadict, single("`testdir'/cohort") output("`testdir'/_test_dd_title.md") ///
        title("Cohort Study Data Dictionary")

    confirm file "`testdir'/_test_dd_title.md"
    display as result "  PASSED: Custom title works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 3: Title and subtitle
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Title and subtitle"
display as text "{hline 50}"

capture noisily {
    datadict, single("`testdir'/cohort") output("`testdir'/_test_dd_sub.md") ///
        title("Cohort Data") subtitle("MS Clinical Study")

    confirm file "`testdir'/_test_dd_sub.md"
    display as result "  PASSED: Subtitle works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 4: Version number
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Version number"
display as text "{hline 50}"

capture noisily {
    datadict, single("`testdir'/cohort") output("`testdir'/_test_dd_ver.md") ///
        title("Cohort Data") version("1.0")

    confirm file "`testdir'/_test_dd_ver.md"
    display as result "  PASSED: Version number works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 5: Author information
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Author information"
display as text "{hline 50}"

capture noisily {
    datadict, single("`testdir'/cohort") output("`testdir'/_test_dd_author.md") ///
        title("Cohort Data") author("Timothy P Copeland")

    confirm file "`testdir'/_test_dd_author.md"
    display as result "  PASSED: Author information works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 6: Missing column
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Missing column"
display as text "{hline 50}"

capture noisily {
    datadict, single("`testdir'/cohort_miss") output("`testdir'/_test_dd_miss.md") ///
        missing

    confirm file "`testdir'/_test_dd_miss.md"
    display as result "  PASSED: Missing column works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 7: Statistics column
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Statistics column"
display as text "{hline 50}"

capture noisily {
    datadict, single("`testdir'/cohort") output("`testdir'/_test_dd_stats.md") ///
        stats

    confirm file "`testdir'/_test_dd_stats.md"
    display as result "  PASSED: Statistics column works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 8: Missing and stats combined
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Missing and stats combined"
display as text "{hline 50}"

capture noisily {
    datadict, single("`testdir'/cohort_miss") output("`testdir'/_test_dd_both.md") ///
        missing stats

    confirm file "`testdir'/_test_dd_both.md"
    display as result "  PASSED: Missing and stats combined work"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 9: Filelist mode
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Filelist mode"
display as text "{hline 50}"

capture noisily {
    datadict, filelist("`testdir'/cohort" "`testdir'/hrt" "`testdir'/dmt") ///
        output("`testdir'/_test_dd_multi.md")

    confirm file "`testdir'/_test_dd_multi.md"
    display as result "  PASSED: Filelist mode works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 10: Custom maxcat
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Custom maxcat"
display as text "{hline 50}"

capture noisily {
    datadict, single("`testdir'/cohort") output("`testdir'/_test_dd_maxcat.md") ///
        maxcat(10)

    confirm file "`testdir'/_test_dd_maxcat.md"
    display as result "  PASSED: Custom maxcat works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 11: Custom maxfreq
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Custom maxfreq"
display as text "{hline 50}"

capture noisily {
    datadict, single("`testdir'/cohort") output("`testdir'/_test_dd_maxfreq.md") ///
        maxfreq(10)

    confirm file "`testdir'/_test_dd_maxfreq.md"
    display as result "  PASSED: Custom maxfreq works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 12: Full metadata
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Full metadata"
display as text "{hline 50}"

capture noisily {
    datadict, single("`testdir'/cohort") output("`testdir'/_test_dd_full.md") ///
        title("MS Cohort Study") subtitle("Data Dictionary") ///
        version("2.0") author("Research Team") ///
        missing stats

    confirm file "`testdir'/_test_dd_full.md"
    display as result "  PASSED: Full metadata works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 13: HRT dataset
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': HRT dataset"
display as text "{hline 50}"

capture noisily {
    datadict, single("`testdir'/hrt") output("`testdir'/_test_dd_hrt.md")

    confirm file "`testdir'/_test_dd_hrt.md"
    display as result "  PASSED: HRT dataset works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 14: DMT dataset
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': DMT dataset"
display as text "{hline 50}"

capture noisily {
    datadict, single("`testdir'/dmt") output("`testdir'/_test_dd_dmt.md")

    confirm file "`testdir'/_test_dd_dmt.md"
    display as result "  PASSED: DMT dataset works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* CLEANUP: Remove temporary files
* =============================================================================
display as text _n "{hline 70}"
display as text "Cleaning up temporary files..."
display as text "{hline 70}"

local temp_files "_test_datadict _test_dd_title _test_dd_sub _test_dd_ver _test_dd_author _test_dd_miss _test_dd_stats _test_dd_both _test_dd_multi _test_dd_maxcat _test_dd_maxfreq _test_dd_full _test_dd_hrt _test_dd_dmt"

foreach f of local temp_files {
    capture erase "`testdir'/`f'.md"
}

* =============================================================================
* SUMMARY
* =============================================================================
display as text _n "{hline 70}"
display as text "DATADICT TEST SUMMARY"
display as text "{hline 70}"
display as text "Total tests:  `test_count'"
display as result "Passed:       `pass_count'"
if `fail_count' > 0 {
    display as error "Failed:       `fail_count'"
}
else {
    display as text "Failed:       `fail_count'"
}
display as text "{hline 70}"

if `fail_count' > 0 {
    display as error "Some tests FAILED. Review output above."
    exit 1
}
else {
    display as result "All tests PASSED!"
}
