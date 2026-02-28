/*******************************************************************************
* test_datamap_fixes.do
*
* Purpose: Test datamap and datadict after code review fixes
*          Specifically tests:
*          1. Value label word-indexing bug fix
*          2. preserve/restore (user data not destroyed)
*          3. set more off
*          4. All basic functionality
*
* Run from: ../../_devkit/_testing/ directory
*******************************************************************************/

clear all
set more off
version 16.0

* Path setup
local projroot "/home/tpcopeland/Stata-Dev"
local datadir "`projroot'/_devkit/_testing/data"
local pkgdir "`projroot'/datamap"

local test_count = 0
local pass_count = 0
local fail_count = 0
local tmpdir "`datadir'"

* =============================================================================
* PART 1: DATAMAP TESTS
* =============================================================================

* Clear and load datamap
program drop _all
run "`pkgdir'/datamap.ado"

* Verify test data exists
capture confirm file "`datadir'/cohort.dta"
if _rc {
    di as error "Test data not found at: `datadir'/cohort.dta"
    exit 601
}

di as text _n _dup(70) "="
di as text "DATAMAP/DATADICT POST-FIX TESTING"
di as text _dup(70) "="

* =============================================================================
* TEST 1: Critical fix - Value label word-indexing bug
* =============================================================================
local ++test_count
di as text _n "TEST `test_count': Value label word-indexing bug fix"
di as text _dup(50) "-"

capture noisily {
    * Create test dataset with mixed labeled/unlabeled variables
    clear
    set obs 100
    gen double id = _n
    gen double age = 20 + int(60*runiform())
    gen byte sex = cond(runiform() > 0.5, 1, 0)
    label define sexlbl 0 "Female" 1 "Male"
    label values sex sexlbl
    gen double bmi = 18 + 15*runiform()
    gen byte region = 1 + int(4*runiform())
    label define reglbl 1 "North" 2 "South" 3 "East" 4 "West"
    label values region reglbl

    save "`tmpdir'/_test_vallab.dta", replace

    datamap, single("`tmpdir'/_test_vallab") output("`tmpdir'/_test_vallab_map.txt")

    * Verify output - check classifications are correct
    tempname fh
    file open `fh' using "`tmpdir'/_test_vallab_map.txt", read text
    local found_age_continuous 0
    local found_sex_categorical 0
    local found_bmi_continuous 0
    local found_region_categorical 0
    local current_var ""
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`macval(line)'"', "  age") > 0 & "`current_var'" == "" {
            local current_var "age"
        }
        if strpos(`"`macval(line)'"', "  sex") > 0 & "`current_var'" == "" {
            local current_var "sex"
        }
        if strpos(`"`macval(line)'"', "  bmi") > 0 & "`current_var'" == "" {
            local current_var "bmi"
        }
        if strpos(`"`macval(line)'"', "  region") > 0 & "`current_var'" == "" {
            local current_var "region"
        }
        if strpos(`"`macval(line)'"', "Classification:") > 0 {
            if "`current_var'" == "age" & strpos(`"`macval(line)'"', "continuous") > 0 {
                local found_age_continuous 1
            }
            if "`current_var'" == "sex" & strpos(`"`macval(line)'"', "categorical") > 0 {
                local found_sex_categorical 1
            }
            if "`current_var'" == "bmi" & strpos(`"`macval(line)'"', "continuous") > 0 {
                local found_bmi_continuous 1
            }
            if "`current_var'" == "region" & strpos(`"`macval(line)'"', "categorical") > 0 {
                local found_region_categorical 1
            }
            local current_var ""
        }
        file read `fh' line
    }
    file close `fh'

    assert `found_age_continuous' == 1
    assert `found_sex_categorical' == 1
    assert `found_bmi_continuous' == 1
    assert `found_region_categorical' == 1

    di as result "  PASSED: Variables correctly classified (bug fix verified)"
    local ++pass_count
}
if _rc {
    di as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 2: preserve/restore - user data not destroyed
* =============================================================================
local ++test_count
di as text _n "TEST `test_count': preserve/restore - user data survives"
di as text _dup(50) "-"

capture noisily {
    sysuse auto, clear
    local orig_N = _N
    local orig_k = c(k)

    datamap, single("`datadir'/cohort") output("`tmpdir'/_test_preserve.txt")

    assert _N == `orig_N'
    assert c(k) == `orig_k'
    confirm variable price

    di as result "  PASSED: User data preserved after datamap"
    local ++pass_count
}
if _rc {
    di as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 3: datamap single dataset basic functionality
* =============================================================================
local ++test_count
di as text _n "TEST `test_count': datamap single dataset"
di as text _dup(50) "-"

capture noisily {
    datamap, single("`datadir'/cohort") output("`tmpdir'/_test_dm_single.txt")
    confirm file "`tmpdir'/_test_dm_single.txt"
    assert r(nfiles) == 1
    di as result "  PASSED"
    local ++pass_count
}
if _rc {
    di as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 4: datamap with exclude and datesafe
* =============================================================================
local ++test_count
di as text _n "TEST `test_count': datamap exclude + datesafe"
di as text _dup(50) "-"

capture noisily {
    datamap, single("`datadir'/cohort") exclude(id study_entry study_exit) ///
        datesafe output("`tmpdir'/_test_dm_privacy.txt")
    confirm file "`tmpdir'/_test_dm_privacy.txt"
    di as result "  PASSED"
    local ++pass_count
}
if _rc {
    di as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 5: datamap filelist mode
* =============================================================================
local ++test_count
di as text _n "TEST `test_count': datamap filelist mode"
di as text _dup(50) "-"

capture noisily {
    datamap, filelist("`datadir'/cohort" "`datadir'/hrt" "`datadir'/dmt") ///
        output("`tmpdir'/_test_dm_multi.txt")
    confirm file "`tmpdir'/_test_dm_multi.txt"
    assert r(nfiles) == 3
    di as result "  PASSED"
    local ++pass_count
}
if _rc {
    di as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 6: datamap nostats nofreq nolabels
* =============================================================================
local ++test_count
di as text _n "TEST `test_count': datamap content suppression"
di as text _dup(50) "-"

capture noisily {
    datamap, single("`datadir'/cohort") nostats nofreq nolabels ///
        output("`tmpdir'/_test_dm_suppress.txt")
    confirm file "`tmpdir'/_test_dm_suppress.txt"
    di as result "  PASSED"
    local ++pass_count
}
if _rc {
    di as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 7: datamap autodetect + quality
* =============================================================================
local ++test_count
di as text _n "TEST `test_count': datamap autodetect + quality"
di as text _dup(50) "-"

capture noisily {
    datamap, single("`datadir'/cohort") autodetect quality ///
        output("`tmpdir'/_test_dm_detect.txt")
    confirm file "`tmpdir'/_test_dm_detect.txt"
    di as result "  PASSED"
    local ++pass_count
}
if _rc {
    di as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 8: datamap missing data analysis
* =============================================================================
local ++test_count
di as text _n "TEST `test_count': datamap missing(pattern)"
di as text _dup(50) "-"

capture noisily {
    datamap, single("`datadir'/cohort_miss") missing(pattern) ///
        output("`tmpdir'/_test_dm_missing.txt")
    confirm file "`tmpdir'/_test_dm_missing.txt"
    di as result "  PASSED"
    local ++pass_count
}
if _rc {
    di as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 9: datamap samples + panel detection
* =============================================================================
local ++test_count
di as text _n "TEST `test_count': datamap samples + panel"
di as text _dup(50) "-"

capture noisily {
    datamap, single("`datadir'/edss_long") samples(3) detect(panel) panelid(id) ///
        output("`tmpdir'/_test_dm_panel.txt")
    confirm file "`tmpdir'/_test_dm_panel.txt"
    di as result "  PASSED"
    local ++pass_count
}
if _rc {
    di as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 10: Error handling - invalid options
* =============================================================================
local ++test_count
di as text _n "TEST `test_count': Error handling"
di as text _dup(50) "-"

capture noisily {
    capture datamap
    assert _rc == 198

    capture datamap, single("`datadir'/cohort") directory("`datadir'")
    assert _rc == 198

    capture datamap, single("`datadir'/cohort") maxcat(-1)
    assert _rc == 198

    di as result "  PASSED: Error handling correct"
    local ++pass_count
}
if _rc {
    di as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* PART 2: DATADICT TESTS (reload fresh)
* =============================================================================

program drop _all
run "`pkgdir'/datadict.ado"

* =============================================================================
* TEST 11: datadict preserve/restore
* =============================================================================
local ++test_count
di as text _n "TEST `test_count': datadict preserve/restore"
di as text _dup(50) "-"

capture noisily {
    sysuse auto, clear
    local orig_N = _N

    datadict, single("`datadir'/cohort") output("`tmpdir'/_test_dd_preserve.md")

    assert _N == `orig_N'
    confirm variable price

    di as result "  PASSED: User data preserved after datadict"
    local ++pass_count
}
if _rc {
    di as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 12: datadict basic
* =============================================================================
local ++test_count
di as text _n "TEST `test_count': datadict basic"
di as text _dup(50) "-"

capture noisily {
    datadict, single("`datadir'/cohort") output("`tmpdir'/_test_dd_basic.md")
    confirm file "`tmpdir'/_test_dd_basic.md"
    assert r(nfiles) == 1
    di as result "  PASSED"
    local ++pass_count
}
if _rc {
    di as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 13: datadict with full metadata
* =============================================================================
local ++test_count
di as text _n "TEST `test_count': datadict full metadata"
di as text _dup(50) "-"

capture noisily {
    datadict, single("`datadir'/cohort") output("`tmpdir'/_test_dd_full.md") ///
        title("MS Cohort Study") subtitle("Data Dictionary") ///
        version("2.0") author("Test Author") missing stats
    confirm file "`tmpdir'/_test_dd_full.md"
    di as result "  PASSED"
    local ++pass_count
}
if _rc {
    di as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 14: datadict filelist mode
* =============================================================================
local ++test_count
di as text _n "TEST `test_count': datadict filelist mode"
di as text _dup(50) "-"

capture noisily {
    datadict, filelist("`datadir'/cohort" "`datadir'/hrt") ///
        output("`tmpdir'/_test_dd_multi.md")
    confirm file "`tmpdir'/_test_dd_multi.md"
    assert r(nfiles) == 2
    di as result "  PASSED"
    local ++pass_count
}
if _rc {
    di as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 15: datadict directory mode
* =============================================================================
local ++test_count
di as text _n "TEST `test_count': datadict directory mode"
di as text _dup(50) "-"

capture noisily {
    datadict, directory("`datadir'") output("`tmpdir'/_test_dd_dir.md")
    confirm file "`tmpdir'/_test_dd_dir.md"
    di as result "  PASSED"
    local ++pass_count
}
if _rc {
    di as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* CLEANUP
* =============================================================================
di as text _n _dup(70) "="
di as text "Cleaning up..."
foreach f in _test_vallab_map _test_preserve _test_dm_single ///
    _test_dm_privacy _test_dm_multi _test_dm_suppress _test_dm_detect ///
    _test_dm_missing _test_dm_panel {
    capture erase "`tmpdir'/`f'.txt"
}
capture erase "`tmpdir'/_test_vallab.dta"
foreach f in _test_dd_preserve _test_dd_basic _test_dd_full _test_dd_multi _test_dd_dir {
    capture erase "`tmpdir'/`f'.md"
}

* =============================================================================
* SUMMARY
* =============================================================================
di as text _n _dup(70) "="
di as text "DATAMAP/DATADICT POST-FIX TEST SUMMARY"
di as text _dup(70) "="
di as text "Total tests:  `test_count'"
di as result "Passed:       `pass_count'"
if `fail_count' > 0 {
    di as error "Failed:       `fail_count'"
}
else {
    di as text "Failed:       `fail_count'"
}
di as text _dup(70) "="

if `fail_count' > 0 {
    di as error "SOME TESTS FAILED"
    exit 1
}
else {
    di as result "ALL TESTS PASSED"
}
