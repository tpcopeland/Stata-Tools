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

* Install datamap package from local repository (contains datadict)
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
* TEST 15: Directory mode
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Directory mode"
display as text "{hline 50}"

capture noisily {
    datadict, directory("`testdir'") output("`testdir'/_test_dd_dir.md")

    confirm file "`testdir'/_test_dd_dir.md"
    display as result "  PASSED: Directory mode works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 16: Directory with recursive option
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Directory with recursive"
display as text "{hline 50}"

capture noisily {
    * Create a subdirectory with a test file for recursive testing
    capture mkdir "`testdir'/_subdir"
    use "`testdir'/cohort.dta", clear
    keep in 1/10
    save "`testdir'/_subdir/_subtest.dta", replace

    datadict, directory("`testdir'") output("`testdir'/_test_dd_recursive.md") recursive

    confirm file "`testdir'/_test_dd_recursive.md"

    * Cleanup subdirectory
    capture erase "`testdir'/_subdir/_subtest.dta"
    capture rmdir "`testdir'/_subdir"

    display as result "  PASSED: Recursive option works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 17: Separate output files
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Separate output files"
display as text "{hline 50}"

capture noisily {
    datadict, filelist("`testdir'/cohort" "`testdir'/hrt") ///
        output("`testdir'/_test_dd_sep.md") separate

    * Check that separate files were created
    * Note: separate creates <basename>_dictionary.md files, not using output() prefix
    confirm file "`testdir'/cohort_dictionary.md"
    confirm file "`testdir'/hrt_dictionary.md"

    display as result "  PASSED: Separate output works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 18: Date option
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Date option"
display as text "{hline 50}"

capture noisily {
    datadict, single("`testdir'/cohort") output("`testdir'/_test_dd_date.md") ///
        date("2025-12-06")

    confirm file "`testdir'/_test_dd_date.md"
    display as result "  PASSED: Date option works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 19: Notes option
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Notes option"
display as text "{hline 50}"

capture noisily {
    datadict, single("`testdir'/cohort") output("`testdir'/_test_dd_notes.md") ///
        notes("This dataset contains clinical data from the MS cohort study. All dates are in Stata date format.")

    confirm file "`testdir'/_test_dd_notes.md"
    display as result "  PASSED: Notes option works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 20: Changelog option
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Changelog option"
display as text "{hline 50}"

capture noisily {
    datadict, single("`testdir'/cohort") output("`testdir'/_test_dd_changelog.md") ///
        changelog("v1.0 (2025-01-01): Initial release \ v1.1 (2025-06-01): Added region variable \ v2.0 (2025-12-01): Added outcome variables")

    confirm file "`testdir'/_test_dd_changelog.md"
    display as result "  PASSED: Changelog option works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 21: Full documentation with all metadata
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Full documentation with all metadata"
display as text "{hline 50}"

capture noisily {
    datadict, single("`testdir'/cohort") output("`testdir'/_test_dd_complete.md") ///
        title("MS Cohort Study") subtitle("Clinical Data Dictionary") ///
        version("2.0") author("Timothy P Copeland") date("2025-12-06") ///
        notes("Comprehensive clinical dataset for MS progression analysis.") ///
        changelog("v1.0: Initial \ v2.0: Added outcomes") ///
        missing stats maxcat(15) maxfreq(20)

    confirm file "`testdir'/_test_dd_complete.md"
    display as result "  PASSED: Complete documentation works"
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

local temp_files "_test_datadict _test_dd_title _test_dd_sub _test_dd_ver _test_dd_author _test_dd_miss _test_dd_stats _test_dd_both _test_dd_multi _test_dd_maxcat _test_dd_maxfreq _test_dd_full _test_dd_hrt _test_dd_dmt _test_dd_dir _test_dd_recursive _test_dd_sep _test_dd_sep_cohort _test_dd_sep_hrt _test_dd_date _test_dd_notes _test_dd_changelog _test_dd_complete"

foreach f of local temp_files {
    capture erase "`testdir'/`f'.md"
}

* Also cleanup any leftover subdirectory from recursive test
capture erase "`testdir'/_subdir/_subtest.dta"
capture rmdir "`testdir'/_subdir"

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
