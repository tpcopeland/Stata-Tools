/*******************************************************************************
* test_tvexpose.do
*
* Purpose: Comprehensive testing of tvexpose command
*          Tests all options documented in tvexpose.sthlp
*
* Prerequisites:
*   - Run generate_test_data.do first to create synthetic datasets
*   - tvexpose.ado must be installed/accessible
*
* Author: Timothy P Copeland
* Date: 2025-12-06
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
display as text "TVEXPOSE COMMAND TESTING"
display as text "{hline 70}"
display as text "Test directory: `testdir'"
display as text "{hline 70}"

local test_count = 0
local pass_count = 0
local fail_count = 0

* =============================================================================
* TEST 1: Basic time-varying exposure (default behavior)
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Basic time-varying exposure"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort.dta", clear

    tvexpose using "`testdir'/hrt.dta", ///
        id(id) start(rx_start) stop(rx_stop) ///
        exposure(hrt_type) reference(0) ///
        entry(study_entry) exit(study_exit) ///
        generate(tv_hrt) ///
        saveas("`testdir'/_test_tvexpose_basic") replace

    * Verify output
    use "`testdir'/_test_tvexpose_basic.dta", clear
    assert _N > 0
    confirm variable id tv_hrt
    display as result "  PASSED: Basic time-varying exposure created"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 2: evertreated option (binary ever/never)
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': evertreated option"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort.dta", clear

    tvexpose using "`testdir'/hrt.dta", ///
        id(id) start(rx_start) stop(rx_stop) ///
        exposure(hrt_type) reference(0) ///
        entry(study_entry) exit(study_exit) ///
        evertreated ///
        generate(ever_hrt) ///
        saveas("`testdir'/_test_tvexpose_ever") replace

    use "`testdir'/_test_tvexpose_ever.dta", clear
    assert _N > 0
    confirm variable ever_hrt
    * Ever-treated should only have values 0 and 1
    tab ever_hrt
    display as result "  PASSED: evertreated option works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 3: currentformer option (trichotomous never/current/former)
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': currentformer option"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort.dta", clear

    tvexpose using "`testdir'/hrt.dta", ///
        id(id) start(rx_start) stop(rx_stop) ///
        exposure(hrt_type) reference(0) ///
        entry(study_entry) exit(study_exit) ///
        currentformer ///
        generate(cf_hrt) ///
        saveas("`testdir'/_test_tvexpose_cf") replace

    use "`testdir'/_test_tvexpose_cf.dta", clear
    assert _N > 0
    confirm variable cf_hrt
    * Should have values 0=never, 1=current, 2=former
    tab cf_hrt
    display as result "  PASSED: currentformer option works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 4: duration() option (cumulative duration categories)
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': duration() option"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort.dta", clear

    * Create duration categories: unexposed, <1 year, 1-<5 years, 5+ years
    tvexpose using "`testdir'/hrt.dta", ///
        id(id) start(rx_start) stop(rx_stop) ///
        exposure(hrt_type) reference(0) ///
        entry(study_entry) exit(study_exit) ///
        duration(1 5) continuousunit(years) ///
        generate(dur_hrt) ///
        saveas("`testdir'/_test_tvexpose_dur") replace

    use "`testdir'/_test_tvexpose_dur.dta", clear
    assert _N > 0
    confirm variable dur_hrt
    tab dur_hrt
    display as result "  PASSED: duration() option works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 5: continuousunit() option (cumulative exposure in years)
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': continuousunit() option"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort.dta", clear

    tvexpose using "`testdir'/hrt.dta", ///
        id(id) start(rx_start) stop(rx_stop) ///
        exposure(hrt_type) reference(0) ///
        entry(study_entry) exit(study_exit) ///
        continuousunit(years) ///
        generate(cumexp_hrt) ///
        saveas("`testdir'/_test_tvexpose_cont") replace

    use "`testdir'/_test_tvexpose_cont.dta", clear
    assert _N > 0
    confirm variable cumexp_hrt
    sum cumexp_hrt
    assert r(min) >= 0
    display as result "  PASSED: continuousunit() option works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 6: grace() option (grace period for gaps)
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': grace() option"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort.dta", clear

    tvexpose using "`testdir'/hrt.dta", ///
        id(id) start(rx_start) stop(rx_stop) ///
        exposure(hrt_type) reference(0) ///
        entry(study_entry) exit(study_exit) ///
        grace(30) ///
        generate(tv_hrt) ///
        saveas("`testdir'/_test_tvexpose_grace") replace

    use "`testdir'/_test_tvexpose_grace.dta", clear
    assert _N > 0
    display as result "  PASSED: grace() option works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 7: lag() option (delay before exposure active)
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': lag() option"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort.dta", clear

    tvexpose using "`testdir'/hrt.dta", ///
        id(id) start(rx_start) stop(rx_stop) ///
        exposure(hrt_type) reference(0) ///
        entry(study_entry) exit(study_exit) ///
        lag(30) ///
        generate(tv_hrt) ///
        saveas("`testdir'/_test_tvexpose_lag") replace

    use "`testdir'/_test_tvexpose_lag.dta", clear
    assert _N > 0
    display as result "  PASSED: lag() option works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 8: washout() option (exposure persists after stopping)
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': washout() option"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort.dta", clear

    tvexpose using "`testdir'/hrt.dta", ///
        id(id) start(rx_start) stop(rx_stop) ///
        exposure(hrt_type) reference(0) ///
        entry(study_entry) exit(study_exit) ///
        washout(90) ///
        generate(tv_hrt) ///
        saveas("`testdir'/_test_tvexpose_washout") replace

    use "`testdir'/_test_tvexpose_washout.dta", clear
    assert _N > 0
    display as result "  PASSED: washout() option works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 9: bytype option (separate variables per exposure type)
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': bytype option"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort.dta", clear

    tvexpose using "`testdir'/hrt.dta", ///
        id(id) start(rx_start) stop(rx_stop) ///
        exposure(hrt_type) reference(0) ///
        entry(study_entry) exit(study_exit) ///
        evertreated bytype ///
        generate(ever_hrt) ///
        saveas("`testdir'/_test_tvexpose_bytype") replace

    use "`testdir'/_test_tvexpose_bytype.dta", clear
    assert _N > 0
    * Should have separate variables for each HRT type
    describe ever_hrt*
    display as result "  PASSED: bytype option works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 10: DMT dataset test
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': DMT dataset exposure"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort.dta", clear

    tvexpose using "`testdir'/dmt.dta", ///
        id(id) start(dmt_start) stop(dmt_stop) ///
        exposure(dmt) reference(0) ///
        entry(study_entry) exit(study_exit) ///
        generate(tv_dmt) ///
        saveas("`testdir'/_test_tvexpose_dmt") replace

    use "`testdir'/_test_tvexpose_dmt.dta", clear
    assert _N > 0
    confirm variable tv_dmt
    tab tv_dmt
    display as result "  PASSED: DMT exposure works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 11: check option (diagnostics)
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': check option"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort.dta", clear

    tvexpose using "`testdir'/hrt.dta", ///
        id(id) start(rx_start) stop(rx_stop) ///
        exposure(hrt_type) reference(0) ///
        entry(study_entry) exit(study_exit) ///
        generate(tv_hrt) ///
        check ///
        saveas("`testdir'/_test_tvexpose_check") replace

    display as result "  PASSED: check option works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 12: summarize option
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': summarize option"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort.dta", clear

    tvexpose using "`testdir'/hrt.dta", ///
        id(id) start(rx_start) stop(rx_stop) ///
        exposure(hrt_type) reference(0) ///
        entry(study_entry) exit(study_exit) ///
        generate(tv_hrt) ///
        summarize ///
        saveas("`testdir'/_test_tvexpose_summ") replace

    display as result "  PASSED: summarize option works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 13: validate option
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': validate option"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort.dta", clear

    tvexpose using "`testdir'/hrt.dta", ///
        id(id) start(rx_start) stop(rx_stop) ///
        exposure(hrt_type) reference(0) ///
        entry(study_entry) exit(study_exit) ///
        generate(tv_hrt) ///
        validate ///
        saveas("`testdir'/_test_tvexpose_validate") replace

    display as result "  PASSED: validate option works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 14: gaps option (show persons with gaps)
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': gaps option"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort.dta", clear

    tvexpose using "`testdir'/hrt.dta", ///
        id(id) start(rx_start) stop(rx_stop) ///
        exposure(hrt_type) reference(0) ///
        entry(study_entry) exit(study_exit) ///
        generate(tv_hrt) ///
        gaps ///
        saveas("`testdir'/_test_tvexpose_gaps") replace

    display as result "  PASSED: gaps option works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 15: overlaps option
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': overlaps option"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort.dta", clear

    tvexpose using "`testdir'/hrt.dta", ///
        id(id) start(rx_start) stop(rx_stop) ///
        exposure(hrt_type) reference(0) ///
        entry(study_entry) exit(study_exit) ///
        generate(tv_hrt) ///
        overlaps ///
        saveas("`testdir'/_test_tvexpose_overlaps") replace

    display as result "  PASSED: overlaps option works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 16: referencelabel() option
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': referencelabel() option"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort.dta", clear

    tvexpose using "`testdir'/hrt.dta", ///
        id(id) start(rx_start) stop(rx_stop) ///
        exposure(hrt_type) reference(0) ///
        entry(study_entry) exit(study_exit) ///
        referencelabel("No HRT") ///
        generate(tv_hrt) ///
        saveas("`testdir'/_test_tvexpose_reflabel") replace

    use "`testdir'/_test_tvexpose_reflabel.dta", clear
    assert _N > 0
    display as result "  PASSED: referencelabel() option works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 17: keepvars() option
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': keepvars() option"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort.dta", clear

    tvexpose using "`testdir'/hrt.dta", ///
        id(id) start(rx_start) stop(rx_stop) ///
        exposure(hrt_type) reference(0) ///
        entry(study_entry) exit(study_exit) ///
        keepvars(age female mstype) ///
        generate(tv_hrt) ///
        saveas("`testdir'/_test_tvexpose_keepvars") replace

    use "`testdir'/_test_tvexpose_keepvars.dta", clear
    assert _N > 0
    confirm variable age female mstype
    display as result "  PASSED: keepvars() option works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 18: Stored results verification
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Stored results verification"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort.dta", clear

    tvexpose using "`testdir'/hrt.dta", ///
        id(id) start(rx_start) stop(rx_stop) ///
        exposure(hrt_type) reference(0) ///
        entry(study_entry) exit(study_exit) ///
        generate(tv_hrt) check ///
        saveas("`testdir'/_test_tvexpose_results") replace

    * Verify stored results exist
    assert r(N) > 0
    assert r(N_persons) > 0

    display as result "  PASSED: Stored results present"
    display as text "  r(N) = " r(N)
    display as text "  r(N_persons) = " r(N_persons)
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 19: Subset using if condition on master
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Subset using if condition"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort.dta", clear

    * Only females
    keep if female == 1

    tvexpose using "`testdir'/hrt.dta", ///
        id(id) start(rx_start) stop(rx_stop) ///
        exposure(hrt_type) reference(0) ///
        entry(study_entry) exit(study_exit) ///
        generate(tv_hrt) ///
        saveas("`testdir'/_test_tvexpose_females") replace

    use "`testdir'/_test_tvexpose_females.dta", clear
    assert _N > 0
    display as result "  PASSED: Subset works correctly"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 20: Combined options test
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Combined options"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort.dta", clear

    tvexpose using "`testdir'/hrt.dta", ///
        id(id) start(rx_start) stop(rx_stop) ///
        exposure(hrt_type) reference(0) ///
        entry(study_entry) exit(study_exit) ///
        grace(30) lag(14) washout(60) ///
        keepvars(age female) ///
        referencelabel("Unexposed") ///
        generate(tv_hrt) ///
        check summarize ///
        saveas("`testdir'/_test_tvexpose_combined") replace

    use "`testdir'/_test_tvexpose_combined.dta", clear
    assert _N > 0
    confirm variable tv_hrt age female
    display as result "  PASSED: Combined options work together"
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

local temp_files "_test_tvexpose_basic _test_tvexpose_ever _test_tvexpose_cf _test_tvexpose_dur _test_tvexpose_cont _test_tvexpose_grace _test_tvexpose_lag _test_tvexpose_washout _test_tvexpose_bytype _test_tvexpose_dmt _test_tvexpose_check _test_tvexpose_summ _test_tvexpose_validate _test_tvexpose_gaps _test_tvexpose_overlaps _test_tvexpose_reflabel _test_tvexpose_keepvars _test_tvexpose_results _test_tvexpose_females _test_tvexpose_combined"

foreach f of local temp_files {
    capture erase "`testdir'/`f'.dta"
}

* =============================================================================
* SUMMARY
* =============================================================================
display as text _n "{hline 70}"
display as text "TVEXPOSE TEST SUMMARY"
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
