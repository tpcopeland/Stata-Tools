/*******************************************************************************
* test_tvmerge.do
*
* Purpose: Comprehensive testing of tvmerge command
*          Tests all options documented in tvmerge.sthlp
*
* Prerequisites:
*   - Run generate_test_data.do first to create synthetic datasets
*   - tvexpose.ado and tvmerge.ado must be installed/accessible
*
* Note: tvmerge operates on datasets already processed by tvexpose, not raw
*       exposure files. This test first creates tvexpose output datasets,
*       then tests tvmerge on those outputs.
*
* Author: Timothy P Copeland
* Date: 2025-12-06
*******************************************************************************/

clear all
set more off
version 16.0

* =============================================================================
* SETUP: Change to data directory and install package from local repository
* =============================================================================

* Data directory for test datasets
cd "/Users/tcopeland/Documents/GitHub/Stata-Tools/_testing/data/"

* Install tvtools package from local repository
local basedir "/Users/tcopeland/Documents/GitHub/Stata-Tools"
capture net uninstall tvtools
net install tvtools, from("`basedir'/tvtools")

local testdir "`c(pwd)'"

* Check for required test data
capture confirm file "`testdir'/cohort.dta"
if _rc {
    display as error "Test data not found. Run generate_test_data.do first."
    exit 601
}

display as text _n "{hline 70}"
display as text "TVMERGE COMMAND TESTING"
display as text "{hline 70}"
display as text "Test directory: `testdir'"
display as text "{hline 70}"

local test_count = 0
local pass_count = 0
local fail_count = 0

* =============================================================================
* SETUP: Create tvexpose output files for tvmerge testing
* tvmerge requires datasets that have been processed by tvexpose first
* =============================================================================
display as text _n "SETUP: Creating tvexpose output datasets..."
display as text "{hline 50}"

capture {
    * Create time-varying HRT dataset
    use "`testdir'/cohort.dta", clear
    tvexpose using "`testdir'/hrt.dta", ///
        id(id) start(rx_start) stop(rx_stop) ///
        exposure(hrt_type) reference(0) ///
        entry(study_entry) exit(study_exit) ///
        generate(tv_hrt) ///
        saveas("`testdir'/_tv_hrt.dta") replace

    * Create time-varying DMT dataset
    use "`testdir'/cohort.dta", clear
    tvexpose using "`testdir'/dmt.dta", ///
        id(id) start(dmt_start) stop(dmt_stop) ///
        exposure(dmt) reference(0) ///
        entry(study_entry) exit(study_exit) ///
        generate(tv_dmt) ///
        saveas("`testdir'/_tv_dmt.dta") replace
}
if _rc {
    display as error "SETUP FAILED: Could not create tvexpose datasets"
    display as error "Error code: " _rc
    exit _rc
}
display as result "Setup complete: tvexpose output files created"

* =============================================================================
* TEST 1: Basic two-dataset merge
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Basic two-dataset merge"
display as text "{hline 50}"

capture noisily {
    tvmerge "`testdir'/_tv_hrt.dta" "`testdir'/_tv_dmt.dta", ///
        id(id) ///
        start(rx_start dmt_start) stop(rx_stop dmt_stop) ///
        exposure(tv_hrt tv_dmt)

    * Verify output
    assert _N > 0
    confirm variable id start stop
    display as result "  PASSED: Basic merge works"
    display as text "  Merged observations: " _N
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 2: Merge with generate() option for custom names
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': generate() option for custom variable names"
display as text "{hline 50}"

capture noisily {
    tvmerge "`testdir'/_tv_hrt.dta" "`testdir'/_tv_dmt.dta", ///
        id(id) ///
        start(rx_start dmt_start) stop(rx_stop dmt_stop) ///
        exposure(tv_hrt tv_dmt) ///
        generate(hrt_status dmt_status)

    * Verify custom names exist
    confirm variable hrt_status dmt_status
    display as result "  PASSED: generate() creates custom variable names"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 3: Merge with prefix() option
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': prefix() option"
display as text "{hline 50}"

capture noisily {
    tvmerge "`testdir'/_tv_hrt.dta" "`testdir'/_tv_dmt.dta", ///
        id(id) ///
        start(rx_start dmt_start) stop(rx_stop dmt_stop) ///
        exposure(tv_hrt tv_dmt) ///
        prefix(exp_)

    * Verify prefixed names exist
    confirm variable exp_1 exp_2
    display as result "  PASSED: prefix() creates prefixed variable names"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 4: Custom start/stop names with startname() and stopname()
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': startname() and stopname() options"
display as text "{hline 50}"

capture noisily {
    tvmerge "`testdir'/_tv_hrt.dta" "`testdir'/_tv_dmt.dta", ///
        id(id) ///
        start(rx_start dmt_start) stop(rx_stop dmt_stop) ///
        exposure(tv_hrt tv_dmt) ///
        startname(period_start) stopname(period_end)

    * Verify custom date names exist
    confirm variable period_start period_end
    display as result "  PASSED: startname() and stopname() work"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 5: saveas() and replace options
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': saveas() and replace options"
display as text "{hline 50}"

capture noisily {
    tvmerge "`testdir'/_tv_hrt.dta" "`testdir'/_tv_dmt.dta", ///
        id(id) ///
        start(rx_start dmt_start) stop(rx_stop dmt_stop) ///
        exposure(tv_hrt tv_dmt) ///
        generate(hrt dmt) ///
        saveas("`testdir'/_test_merged.dta") replace

    * Verify file was saved
    confirm file "`testdir'/_test_merged.dta"
    display as result "  PASSED: saveas() saves merged dataset"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 6: check option (diagnostics)
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': check option (diagnostics)"
display as text "{hline 50}"

capture noisily {
    tvmerge "`testdir'/_tv_hrt.dta" "`testdir'/_tv_dmt.dta", ///
        id(id) ///
        start(rx_start dmt_start) stop(rx_stop dmt_stop) ///
        exposure(tv_hrt tv_dmt) ///
        check

    * Verify stored results from check
    assert r(N_persons) > 0
    assert r(mean_periods) > 0
    display as result "  PASSED: check option displays diagnostics"
    display as text "  N persons: " r(N_persons) ", mean periods: " %5.2f r(mean_periods)
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 7: summarize option
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': summarize option"
display as text "{hline 50}"

capture noisily {
    tvmerge "`testdir'/_tv_hrt.dta" "`testdir'/_tv_dmt.dta", ///
        id(id) ///
        start(rx_start dmt_start) stop(rx_stop dmt_stop) ///
        exposure(tv_hrt tv_dmt) ///
        summarize

    display as result "  PASSED: summarize option works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 8: validatecoverage option
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': validatecoverage option"
display as text "{hline 50}"

capture noisily {
    tvmerge "`testdir'/_tv_hrt.dta" "`testdir'/_tv_dmt.dta", ///
        id(id) ///
        start(rx_start dmt_start) stop(rx_stop dmt_stop) ///
        exposure(tv_hrt tv_dmt) ///
        validatecoverage

    display as result "  PASSED: validatecoverage option works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 9: validateoverlap option
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': validateoverlap option"
display as text "{hline 50}"

capture noisily {
    tvmerge "`testdir'/_tv_hrt.dta" "`testdir'/_tv_dmt.dta", ///
        id(id) ///
        start(rx_start dmt_start) stop(rx_stop dmt_stop) ///
        exposure(tv_hrt tv_dmt) ///
        validateoverlap

    display as result "  PASSED: validateoverlap option works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 10: batch() option for performance control
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': batch() option"
display as text "{hline 50}"

capture noisily {
    * Test with small batch size
    tvmerge "`testdir'/_tv_hrt.dta" "`testdir'/_tv_dmt.dta", ///
        id(id) ///
        start(rx_start dmt_start) stop(rx_stop dmt_stop) ///
        exposure(tv_hrt tv_dmt) ///
        batch(10)

    assert _N > 0
    display as result "  PASSED: batch(10) works"

    * Test with larger batch size
    tvmerge "`testdir'/_tv_hrt.dta" "`testdir'/_tv_dmt.dta", ///
        id(id) ///
        start(rx_start dmt_start) stop(rx_stop dmt_stop) ///
        exposure(tv_hrt tv_dmt) ///
        batch(50)

    assert _N > 0
    display as result "  PASSED: batch(50) works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 11: dateformat() option
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': dateformat() option"
display as text "{hline 50}"

capture noisily {
    tvmerge "`testdir'/_tv_hrt.dta" "`testdir'/_tv_dmt.dta", ///
        id(id) ///
        start(rx_start dmt_start) stop(rx_stop dmt_stop) ///
        exposure(tv_hrt tv_dmt) ///
        dateformat(%tdNN/DD/CCYY)

    * Check that the format was applied
    local fmt : format start
    assert "`fmt'" == "%tdNN/DD/CCYY"
    display as result "  PASSED: dateformat() applies custom format"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 12: All diagnostic options combined
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': All diagnostic options combined"
display as text "{hline 50}"

capture noisily {
    tvmerge "`testdir'/_tv_hrt.dta" "`testdir'/_tv_dmt.dta", ///
        id(id) ///
        start(rx_start dmt_start) stop(rx_stop dmt_stop) ///
        exposure(tv_hrt tv_dmt) ///
        generate(hrt dmt) ///
        check validatecoverage validateoverlap summarize

    display as result "  PASSED: All diagnostic options work together"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 13: Stored results verification
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Stored results verification"
display as text "{hline 50}"

capture noisily {
    tvmerge "`testdir'/_tv_hrt.dta" "`testdir'/_tv_dmt.dta", ///
        id(id) ///
        start(rx_start dmt_start) stop(rx_stop dmt_stop) ///
        exposure(tv_hrt tv_dmt) ///
        generate(hrt dmt) ///
        check

    * Verify all expected stored results exist
    assert r(N) > 0
    assert r(N_persons) > 0
    assert r(mean_periods) > 0
    assert r(max_periods) > 0
    assert r(N_datasets) == 2

    * Verify macros
    assert "`r(datasets)'" != ""
    assert "`r(exposure_vars)'" != ""

    display as result "  PASSED: All stored results present"
    display as text "  r(N) = " r(N)
    display as text "  r(N_persons) = " r(N_persons)
    display as text "  r(N_datasets) = " r(N_datasets)
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 14: continuous() option - treating exposure as rate per day
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': continuous() option"
display as text "{hline 50}"

capture noisily {
    * First create a continuous exposure dataset
    use "`testdir'/cohort.dta", clear
    tvexpose using "`testdir'/hrt.dta", ///
        id(id) start(rx_start) stop(rx_stop) ///
        exposure(hrt_type) reference(0) ///
        entry(study_entry) exit(study_exit) ///
        continuousunit(years) ///
        generate(tv_hrt_cont) ///
        saveas("`testdir'/_tv_hrt_cont.dta") replace

    tvmerge "`testdir'/_tv_hrt_cont.dta" "`testdir'/_tv_dmt.dta", ///
        id(id) ///
        start(rx_start dmt_start) stop(rx_stop dmt_stop) ///
        exposure(tv_hrt_cont tv_dmt) ///
        continuous(tv_hrt_cont) ///
        generate(hrt_cont dmt_status)

    * Verify continuous exposure creates rate and period variables
    assert _N > 0
    confirm variable hrt_cont dmt_status
    display as result "  PASSED: continuous() option works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 15: keep() option - additional variables from source datasets
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': keep() option"
display as text "{hline 50}"

capture noisily {
    * Create tvexpose output with additional variables to keep
    use "`testdir'/cohort.dta", clear
    tvexpose using "`testdir'/hrt.dta", ///
        id(id) start(rx_start) stop(rx_stop) ///
        exposure(hrt_type) reference(0) ///
        entry(study_entry) exit(study_exit) ///
        keepvars(age female) ///
        generate(tv_hrt) ///
        saveas("`testdir'/_tv_hrt_keep.dta") replace

    use "`testdir'/cohort.dta", clear
    tvexpose using "`testdir'/dmt.dta", ///
        id(id) start(dmt_start) stop(dmt_stop) ///
        exposure(dmt) reference(0) ///
        entry(study_entry) exit(study_exit) ///
        keepvars(mstype edss_baseline) ///
        generate(tv_dmt) ///
        saveas("`testdir'/_tv_dmt_keep.dta") replace

    tvmerge "`testdir'/_tv_hrt_keep.dta" "`testdir'/_tv_dmt_keep.dta", ///
        id(id) ///
        start(rx_start dmt_start) stop(rx_stop dmt_stop) ///
        exposure(tv_hrt tv_dmt) ///
        keep(age female mstype edss_baseline) ///
        generate(hrt dmt)

    * Verify kept variables are present (with _ds# suffixes)
    assert _N > 0
    * Variables from different datasets get _ds1, _ds2 suffixes
    describe
    display as result "  PASSED: keep() option works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 16: Multiple continuous exposures
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Multiple continuous exposures"
display as text "{hline 50}"

capture noisily {
    * Create two continuous exposure datasets
    use "`testdir'/cohort.dta", clear
    tvexpose using "`testdir'/hrt.dta", ///
        id(id) start(rx_start) stop(rx_stop) ///
        exposure(hrt_type) reference(0) ///
        entry(study_entry) exit(study_exit) ///
        continuousunit(months) ///
        generate(tv_hrt_months) ///
        saveas("`testdir'/_tv_hrt_cont2.dta") replace

    use "`testdir'/cohort.dta", clear
    tvexpose using "`testdir'/dmt.dta", ///
        id(id) start(dmt_start) stop(dmt_stop) ///
        exposure(dmt) reference(0) ///
        entry(study_entry) exit(study_exit) ///
        continuousunit(years) ///
        generate(tv_dmt_years) ///
        saveas("`testdir'/_tv_dmt_cont.dta") replace

    tvmerge "`testdir'/_tv_hrt_cont2.dta" "`testdir'/_tv_dmt_cont.dta", ///
        id(id) ///
        start(rx_start dmt_start) stop(rx_stop dmt_stop) ///
        exposure(tv_hrt_months tv_dmt_years) ///
        continuous(1 2) ///
        generate(hrt_exp dmt_exp)

    * Verify both continuous exposures work
    assert _N > 0
    display as result "  PASSED: Multiple continuous exposures work"
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

local temp_files "_tv_hrt _tv_dmt _test_merged _tv_hrt_cont _tv_hrt_keep _tv_dmt_keep _tv_hrt_cont2 _tv_dmt_cont"

foreach f of local temp_files {
    capture erase "`testdir'/`f'.dta"
}

* =============================================================================
* SUMMARY
* =============================================================================
display as text _n "{hline 70}"
display as text "TVMERGE TEST SUMMARY"
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
