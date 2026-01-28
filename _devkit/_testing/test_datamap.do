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

* =============================================================================
* PATH CONFIGURATION
* =============================================================================
* Cross-platform path detection
if "`c(os)'" == "MacOSX" {
    global STATA_TOOLS_PATH "/Users/tcopeland/Documents/GitHub/Stata-Tools"
}
else if "`c(os)'" == "Unix" {
    * Try to detect path from current working directory
    capture confirm file "_testing"
    if _rc == 0 {
        global STATA_TOOLS_PATH "`c(pwd)'"
    }
    else {
        capture confirm file "data"
        if _rc == 0 {
            global STATA_TOOLS_PATH "`c(pwd)'/.."
        }
        else {
            global STATA_TOOLS_PATH "/home/`c(username)'/Stata-Tools"
        }
    }
}
else {
    * Windows or other - try to detect from current directory
    capture confirm file "_testing"
    if _rc == 0 {
        * Running from repo root
        global STATA_TOOLS_PATH "`c(pwd)'"
    }
    else {
        capture confirm file "data"
        if _rc == 0 {
            * Running from _testing directory
            global STATA_TOOLS_PATH "`c(pwd)'/.."
        }
        else {
            * Assume running from _testing/data directory
            global STATA_TOOLS_PATH "`c(pwd)'/../.."
        }
    }
}

* Directory structure
global TESTING_DIR "${STATA_TOOLS_PATH}/_testing"
global DATA_DIR "${TESTING_DIR}/data"

* =============================================================================
* SETUP: Change to data directory and install package from local repository
* =============================================================================

* Change to data directory
cd "${DATA_DIR}"

* Install datamap package from local repository
capture net uninstall datamap
net install datamap, from("${STATA_TOOLS_PATH}/datamap") force

local testdir "${DATA_DIR}"

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
* TEST 16: Directory mode
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Directory mode"
display as text "{hline 50}"

capture noisily {
    datamap, directory("`testdir'") output("`testdir'/_test_datamap_dir.txt")

    confirm file "`testdir'/_test_datamap_dir.txt"
    display as result "  PASSED: Directory mode works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 17: Directory with recursive option
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Directory with recursive"
display as text "{hline 50}"

capture noisily {
    * Create a subdirectory with a test file
    capture mkdir "`testdir'/_subdir_dm"
    use "`testdir'/cohort.dta", clear
    keep in 1/10
    save "`testdir'/_subdir_dm/_subtest.dta", replace

    datamap, directory("`testdir'") output("`testdir'/_test_datamap_recursive.txt") recursive

    confirm file "`testdir'/_test_datamap_recursive.txt"

    * Cleanup subdirectory
    capture erase "`testdir'/_subdir_dm/_subtest.dta"
    capture rmdir "`testdir'/_subdir_dm"

    display as result "  PASSED: Recursive option works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 18: Separate output files
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Separate output files"
display as text "{hline 50}"

capture noisily {
    datamap, filelist("`testdir'/cohort" "`testdir'/hrt") ///
        output("`testdir'/_test_datamap_sep.txt") separate

    * Check that separate files were created
    * Note: separate creates <basename>_map.txt files, not using output() prefix
    confirm file "`testdir'/cohort_map.txt"
    confirm file "`testdir'/hrt_map.txt"

    display as result "  PASSED: Separate output works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 19: Append mode
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Append mode"
display as text "{hline 50}"

capture noisily {
    * First create initial file
    datamap, single("`testdir'/cohort") output("`testdir'/_test_datamap_append.txt")

    * Then append another dataset
    datamap, single("`testdir'/hrt") output("`testdir'/_test_datamap_append.txt") append

    confirm file "`testdir'/_test_datamap_append.txt"
    display as result "  PASSED: Append mode works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 20: No labels option
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': No labels option"
display as text "{hline 50}"

capture noisily {
    datamap, single("`testdir'/cohort") nolabels ///
        output("`testdir'/_test_datamap_nolabels.txt")

    confirm file "`testdir'/_test_datamap_nolabels.txt"
    display as result "  PASSED: nolabels option works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 21: No notes option
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': No notes option"
display as text "{hline 50}"

capture noisily {
    datamap, single("`testdir'/cohort") nonotes ///
        output("`testdir'/_test_datamap_nonotes.txt")

    confirm file "`testdir'/_test_datamap_nonotes.txt"
    display as result "  PASSED: nonotes option works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 22: Quality2 strict mode
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Quality2 strict mode"
display as text "{hline 50}"

capture noisily {
    datamap, single("`testdir'/cohort") quality2(strict) ///
        output("`testdir'/_test_datamap_quality2.txt")

    confirm file "`testdir'/_test_datamap_quality2.txt"
    display as result "  PASSED: quality2(strict) works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 23: Missing pattern analysis
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Missing pattern analysis"
display as text "{hline 50}"

capture noisily {
    datamap, single("`testdir'/cohort_miss") missing(pattern) ///
        output("`testdir'/_test_datamap_misspattern.txt")

    confirm file "`testdir'/_test_datamap_misspattern.txt"
    display as result "  PASSED: missing(pattern) works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 24: Survival variables detection
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Survival variables detection"
display as text "{hline 50}"

capture noisily {
    datamap, single("`testdir'/cohort") survivalvars(study_entry study_exit edss4_dt) ///
        output("`testdir'/_test_datamap_survival.txt")

    confirm file "`testdir'/_test_datamap_survival.txt"
    display as result "  PASSED: survivalvars() works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 25: Detect binary variables
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Detect binary variables"
display as text "{hline 50}"

capture noisily {
    datamap, single("`testdir'/cohort") detect(binary) ///
        output("`testdir'/_test_datamap_binary.txt")

    confirm file "`testdir'/_test_datamap_binary.txt"
    display as result "  PASSED: detect(binary) works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 26: Detect survival structure
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Detect survival structure"
display as text "{hline 50}"

capture noisily {
    datamap, single("`testdir'/cohort") detect(survival) ///
        output("`testdir'/_test_datamap_detectsurv.txt")

    confirm file "`testdir'/_test_datamap_detectsurv.txt"
    display as result "  PASSED: detect(survival) works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 27: Detect common issues
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Detect common issues"
display as text "{hline 50}"

capture noisily {
    datamap, single("`testdir'/cohort") detect(common) ///
        output("`testdir'/_test_datamap_common.txt")

    confirm file "`testdir'/_test_datamap_common.txt"
    display as result "  PASSED: detect(common) works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 28: Full comprehensive analysis
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Full comprehensive analysis"
display as text "{hline 50}"

capture noisily {
    datamap, single("`testdir'/cohort_miss") ///
        output("`testdir'/_test_datamap_complete.txt") ///
        exclude(id) datesafe quality missing(detail) ///
        samples(3) autodetect maxcat(15) maxfreq(20)

    confirm file "`testdir'/_test_datamap_complete.txt"
    display as result "  PASSED: Full comprehensive analysis works"
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

local temp_files "_test_datamap _test_cohort_map _test_datamap_exclude _test_datamap_datesafe _test_datamap_nostats _test_datamap_nofreq _test_datamap_multi _test_datamap_maxcat _test_datamap_quality _test_datamap_missing _test_datamap_samples _test_datamap_autodetect _test_datamap_panel _test_datamap_privacy _test_datamap_hrt _test_datamap_dir _test_datamap_recursive _test_datamap_sep _test_datamap_sep_cohort _test_datamap_sep_hrt _test_datamap_append _test_datamap_nolabels _test_datamap_nonotes _test_datamap_quality2 _test_datamap_misspattern _test_datamap_survival _test_datamap_binary _test_datamap_detectsurv _test_datamap_common _test_datamap_complete"

foreach f of local temp_files {
    capture erase "`testdir'/`f'.txt"
}

* Also cleanup any leftover subdirectory from recursive test
capture erase "`testdir'/_subdir_dm/_subtest.dta"
capture rmdir "`testdir'/_subdir_dm"

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
