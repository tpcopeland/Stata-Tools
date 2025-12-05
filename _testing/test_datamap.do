/*******************************************************************************
* test_datamap.do
*
* Purpose: Comprehensive testing of datamap command
*          Tests all options and common combinations
*
* Prerequisites:
*   - Run generate_test_data.do first to create synthetic datasets
*   - datamap.ado must be installed/accessible
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
display as text "DATAMAP COMMAND TESTING"
display as text "{hline 70}"
display as text "Test directory: `testdir'"
display as text "{hline 70}"

local test_count = 0
local pass_count = 0
local fail_count = 0

* =============================================================================
* TEST 1: Single dataset documentation
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Single dataset documentation"
display as text "{hline 50}"

capture noisily {
    datamap, single("`testdir'/cohort") output("`testdir'/_test_datamap.txt")

    * Check output file exists
    confirm file "`testdir'/_test_datamap.txt"
    display as result "  PASSED: Single dataset documentation works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 2: Custom output filename
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Custom output filename"
display as text "{hline 50}"

capture noisily {
    datamap, single("`testdir'/cohort") output("`testdir'/_test_cohort_map.txt")

    confirm file "`testdir'/_test_cohort_map.txt"
    display as result "  PASSED: Custom output filename works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 3: Exclude variables (privacy)
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Exclude variables"
display as text "{hline 50}"

capture noisily {
    datamap, single("`testdir'/cohort") exclude(id study_entry study_exit) ///
        output("`testdir'/_test_datamap_exclude.txt")

    confirm file "`testdir'/_test_datamap_exclude.txt"
    display as result "  PASSED: Exclude option works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 4: Date-safe mode
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Date-safe mode"
display as text "{hline 50}"

capture noisily {
    datamap, single("`testdir'/cohort") datesafe ///
        output("`testdir'/_test_datamap_datesafe.txt")

    confirm file "`testdir'/_test_datamap_datesafe.txt"
    display as result "  PASSED: Date-safe mode works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 5: No statistics
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': No statistics"
display as text "{hline 50}"

capture noisily {
    datamap, single("`testdir'/cohort") nostats ///
        output("`testdir'/_test_datamap_nostats.txt")

    confirm file "`testdir'/_test_datamap_nostats.txt"
    display as result "  PASSED: nostats option works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 6: No frequencies
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': No frequencies"
display as text "{hline 50}"

capture noisily {
    datamap, single("`testdir'/cohort") nofreq ///
        output("`testdir'/_test_datamap_nofreq.txt")

    confirm file "`testdir'/_test_datamap_nofreq.txt"
    display as result "  PASSED: nofreq option works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 7: Filelist mode (multiple datasets)
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Filelist mode"
display as text "{hline 50}"

capture noisily {
    datamap, filelist("`testdir'/cohort" "`testdir'/hrt" "`testdir'/dmt") ///
        output("`testdir'/_test_datamap_multi.txt")

    confirm file "`testdir'/_test_datamap_multi.txt"
    display as result "  PASSED: Filelist mode works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 8: Custom maxcat and maxfreq
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Custom maxcat and maxfreq"
display as text "{hline 50}"

capture noisily {
    datamap, single("`testdir'/cohort") maxcat(10) maxfreq(10) ///
        output("`testdir'/_test_datamap_maxcat.txt")

    confirm file "`testdir'/_test_datamap_maxcat.txt"
    display as result "  PASSED: maxcat/maxfreq options work"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 9: Quality checks
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Quality checks"
display as text "{hline 50}"

capture noisily {
    datamap, single("`testdir'/cohort") quality ///
        output("`testdir'/_test_datamap_quality.txt")

    confirm file "`testdir'/_test_datamap_quality.txt"
    display as result "  PASSED: Quality checks work"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 10: Missing data analysis (detail)
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Missing data analysis"
display as text "{hline 50}"

capture noisily {
    datamap, single("`testdir'/cohort_miss") missing(detail) ///
        output("`testdir'/_test_datamap_missing.txt")

    confirm file "`testdir'/_test_datamap_missing.txt"
    display as result "  PASSED: Missing data analysis works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 11: Sample observations
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Sample observations"
display as text "{hline 50}"

capture noisily {
    datamap, single("`testdir'/cohort") samples(5) exclude(id) ///
        output("`testdir'/_test_datamap_samples.txt")

    confirm file "`testdir'/_test_datamap_samples.txt"
    display as result "  PASSED: Sample observations option works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 12: Autodetect features
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Autodetect features"
display as text "{hline 50}"

capture noisily {
    datamap, single("`testdir'/cohort") autodetect ///
        output("`testdir'/_test_datamap_autodetect.txt")

    confirm file "`testdir'/_test_datamap_autodetect.txt"
    display as result "  PASSED: Autodetect features work"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 13: Panel detection
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Panel detection"
display as text "{hline 50}"

capture noisily {
    datamap, single("`testdir'/edss_long") detect(panel) panelid(id) ///
        output("`testdir'/_test_datamap_panel.txt")

    confirm file "`testdir'/_test_datamap_panel.txt"
    display as result "  PASSED: Panel detection works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 14: Combined privacy settings
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Combined privacy settings"
display as text "{hline 50}"

capture noisily {
    datamap, single("`testdir'/cohort") exclude(id) datesafe nostats ///
        output("`testdir'/_test_datamap_privacy.txt")

    confirm file "`testdir'/_test_datamap_privacy.txt"
    display as result "  PASSED: Combined privacy settings work"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 15: HRT dataset
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': HRT dataset"
display as text "{hline 50}"

capture noisily {
    datamap, single("`testdir'/hrt") output("`testdir'/_test_datamap_hrt.txt")

    confirm file "`testdir'/_test_datamap_hrt.txt"
    display as result "  PASSED: HRT dataset works"
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

local temp_files "_test_datamap _test_cohort_map _test_datamap_exclude _test_datamap_datesafe _test_datamap_nostats _test_datamap_nofreq _test_datamap_multi _test_datamap_maxcat _test_datamap_quality _test_datamap_missing _test_datamap_samples _test_datamap_autodetect _test_datamap_panel _test_datamap_privacy _test_datamap_hrt"

foreach f of local temp_files {
    capture erase "`testdir'/`f'.txt"
}

* =============================================================================
* SUMMARY
* =============================================================================
display as text _n "{hline 70}"
display as text "DATAMAP TEST SUMMARY"
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
