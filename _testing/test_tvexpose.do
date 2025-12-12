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
* Updated: 2025-12-12 (added dose option tests, updated paths)
*******************************************************************************/

clear all
set more off
version 16.0

* =============================================================================
* PATH CONFIGURATION
* =============================================================================
* Local machine path (for Claude with stata-mcp access)
global STATA_TOOLS_PATH "/Users/tcopeland/Documents/GitHub/Stata-Tools"

* Directory structure
global TESTING_DIR "${STATA_TOOLS_PATH}/_testing"
global DATA_DIR "${TESTING_DIR}/data"

* Change to the data directory
cd "${DATA_DIR}"

* Install tvtools package from local repository
capture net uninstall tvtools
net install tvtools, from("${STATA_TOOLS_PATH}/tvtools")

* Check for required test data
capture confirm file "${DATA_DIR}/cohort.dta"
if _rc {
    display as error "Test data not found. Run generate_test_data.do first."
    exit 601
}

display as text _n "{hline 70}"
display as text "TVEXPOSE COMMAND TESTING"
display as text "{hline 70}"
display as text "Data directory: ${DATA_DIR}"
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
    use "${DATA_DIR}/cohort.dta", clear

    tvexpose using "${DATA_DIR}/hrt.dta", ///
        id(id) start(rx_start) stop(rx_stop) ///
        exposure(hrt_type) reference(0) ///
        entry(study_entry) exit(study_exit) ///
        generate(tv_hrt) ///
        saveas("${DATA_DIR}/_test_tvexpose_basic") replace

    * Verify output
    use "${DATA_DIR}/_test_tvexpose_basic.dta", clear
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
    use "${DATA_DIR}/cohort.dta", clear

    tvexpose using "${DATA_DIR}/hrt.dta", ///
        id(id) start(rx_start) stop(rx_stop) ///
        exposure(hrt_type) reference(0) ///
        entry(study_entry) exit(study_exit) ///
        evertreated ///
        generate(ever_hrt) ///
        saveas("${DATA_DIR}/_test_tvexpose_ever") replace

    use "${DATA_DIR}/_test_tvexpose_ever.dta", clear
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
    use "${DATA_DIR}/cohort.dta", clear

    tvexpose using "${DATA_DIR}/hrt.dta", ///
        id(id) start(rx_start) stop(rx_stop) ///
        exposure(hrt_type) reference(0) ///
        entry(study_entry) exit(study_exit) ///
        currentformer ///
        generate(cf_hrt) ///
        saveas("${DATA_DIR}/_test_tvexpose_cf") replace

    use "${DATA_DIR}/_test_tvexpose_cf.dta", clear
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
    use "${DATA_DIR}/cohort.dta", clear

    * Create duration categories: unexposed, <1 year, 1-<5 years, 5+ years
    tvexpose using "${DATA_DIR}/hrt.dta", ///
        id(id) start(rx_start) stop(rx_stop) ///
        exposure(hrt_type) reference(0) ///
        entry(study_entry) exit(study_exit) ///
        duration(1 5) continuousunit(years) ///
        generate(dur_hrt) ///
        saveas("${DATA_DIR}/_test_tvexpose_dur") replace

    use "${DATA_DIR}/_test_tvexpose_dur.dta", clear
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
    use "${DATA_DIR}/cohort.dta", clear

    tvexpose using "${DATA_DIR}/hrt.dta", ///
        id(id) start(rx_start) stop(rx_stop) ///
        exposure(hrt_type) reference(0) ///
        entry(study_entry) exit(study_exit) ///
        continuousunit(years) ///
        generate(cumexp_hrt) ///
        saveas("${DATA_DIR}/_test_tvexpose_cont") replace

    use "${DATA_DIR}/_test_tvexpose_cont.dta", clear
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
    use "${DATA_DIR}/cohort.dta", clear

    tvexpose using "${DATA_DIR}/hrt.dta", ///
        id(id) start(rx_start) stop(rx_stop) ///
        exposure(hrt_type) reference(0) ///
        entry(study_entry) exit(study_exit) ///
        grace(30) ///
        generate(tv_hrt) ///
        saveas("${DATA_DIR}/_test_tvexpose_grace") replace

    use "${DATA_DIR}/_test_tvexpose_grace.dta", clear
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
    use "${DATA_DIR}/cohort.dta", clear

    tvexpose using "${DATA_DIR}/hrt.dta", ///
        id(id) start(rx_start) stop(rx_stop) ///
        exposure(hrt_type) reference(0) ///
        entry(study_entry) exit(study_exit) ///
        lag(30) ///
        generate(tv_hrt) ///
        saveas("${DATA_DIR}/_test_tvexpose_lag") replace

    use "${DATA_DIR}/_test_tvexpose_lag.dta", clear
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
    use "${DATA_DIR}/cohort.dta", clear

    tvexpose using "${DATA_DIR}/hrt.dta", ///
        id(id) start(rx_start) stop(rx_stop) ///
        exposure(hrt_type) reference(0) ///
        entry(study_entry) exit(study_exit) ///
        washout(90) ///
        generate(tv_hrt) ///
        saveas("${DATA_DIR}/_test_tvexpose_washout") replace

    use "${DATA_DIR}/_test_tvexpose_washout.dta", clear
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
    use "${DATA_DIR}/cohort.dta", clear

    tvexpose using "${DATA_DIR}/hrt.dta", ///
        id(id) start(rx_start) stop(rx_stop) ///
        exposure(hrt_type) reference(0) ///
        entry(study_entry) exit(study_exit) ///
        evertreated bytype ///
        generate(ever_hrt) ///
        saveas("${DATA_DIR}/_test_tvexpose_bytype") replace

    use "${DATA_DIR}/_test_tvexpose_bytype.dta", clear
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
    use "${DATA_DIR}/cohort.dta", clear

    tvexpose using "${DATA_DIR}/dmt.dta", ///
        id(id) start(dmt_start) stop(dmt_stop) ///
        exposure(dmt) reference(0) ///
        entry(study_entry) exit(study_exit) ///
        generate(tv_dmt) ///
        saveas("${DATA_DIR}/_test_tvexpose_dmt") replace

    use "${DATA_DIR}/_test_tvexpose_dmt.dta", clear
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
    use "${DATA_DIR}/cohort.dta", clear

    tvexpose using "${DATA_DIR}/hrt.dta", ///
        id(id) start(rx_start) stop(rx_stop) ///
        exposure(hrt_type) reference(0) ///
        entry(study_entry) exit(study_exit) ///
        generate(tv_hrt) ///
        check ///
        saveas("${DATA_DIR}/_test_tvexpose_check") replace

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
    use "${DATA_DIR}/cohort.dta", clear

    tvexpose using "${DATA_DIR}/hrt.dta", ///
        id(id) start(rx_start) stop(rx_stop) ///
        exposure(hrt_type) reference(0) ///
        entry(study_entry) exit(study_exit) ///
        generate(tv_hrt) ///
        summarize ///
        saveas("${DATA_DIR}/_test_tvexpose_summ") replace

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
    use "${DATA_DIR}/cohort.dta", clear

    tvexpose using "${DATA_DIR}/hrt.dta", ///
        id(id) start(rx_start) stop(rx_stop) ///
        exposure(hrt_type) reference(0) ///
        entry(study_entry) exit(study_exit) ///
        generate(tv_hrt) ///
        validate ///
        saveas("${DATA_DIR}/_test_tvexpose_validate") replace

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
    use "${DATA_DIR}/cohort.dta", clear

    tvexpose using "${DATA_DIR}/hrt.dta", ///
        id(id) start(rx_start) stop(rx_stop) ///
        exposure(hrt_type) reference(0) ///
        entry(study_entry) exit(study_exit) ///
        generate(tv_hrt) ///
        gaps ///
        saveas("${DATA_DIR}/_test_tvexpose_gaps") replace

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
    use "${DATA_DIR}/cohort.dta", clear

    tvexpose using "${DATA_DIR}/hrt.dta", ///
        id(id) start(rx_start) stop(rx_stop) ///
        exposure(hrt_type) reference(0) ///
        entry(study_entry) exit(study_exit) ///
        generate(tv_hrt) ///
        overlaps ///
        saveas("${DATA_DIR}/_test_tvexpose_overlaps") replace

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
    use "${DATA_DIR}/cohort.dta", clear

    tvexpose using "${DATA_DIR}/hrt.dta", ///
        id(id) start(rx_start) stop(rx_stop) ///
        exposure(hrt_type) reference(0) ///
        entry(study_entry) exit(study_exit) ///
        referencelabel("No HRT") ///
        generate(tv_hrt) ///
        saveas("${DATA_DIR}/_test_tvexpose_reflabel") replace

    use "${DATA_DIR}/_test_tvexpose_reflabel.dta", clear
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
    use "${DATA_DIR}/cohort.dta", clear

    tvexpose using "${DATA_DIR}/hrt.dta", ///
        id(id) start(rx_start) stop(rx_stop) ///
        exposure(hrt_type) reference(0) ///
        entry(study_entry) exit(study_exit) ///
        keepvars(age female mstype) ///
        generate(tv_hrt) ///
        saveas("${DATA_DIR}/_test_tvexpose_keepvars") replace

    use "${DATA_DIR}/_test_tvexpose_keepvars.dta", clear
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
    use "${DATA_DIR}/cohort.dta", clear

    tvexpose using "${DATA_DIR}/hrt.dta", ///
        id(id) start(rx_start) stop(rx_stop) ///
        exposure(hrt_type) reference(0) ///
        entry(study_entry) exit(study_exit) ///
        generate(tv_hrt) check ///
        saveas("${DATA_DIR}/_test_tvexpose_results") replace

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
    use "${DATA_DIR}/cohort.dta", clear

    * Only females
    keep if female == 1

    tvexpose using "${DATA_DIR}/hrt.dta", ///
        id(id) start(rx_start) stop(rx_stop) ///
        exposure(hrt_type) reference(0) ///
        entry(study_entry) exit(study_exit) ///
        generate(tv_hrt) ///
        saveas("${DATA_DIR}/_test_tvexpose_females") replace

    use "${DATA_DIR}/_test_tvexpose_females.dta", clear
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
    use "${DATA_DIR}/cohort.dta", clear

    tvexpose using "${DATA_DIR}/hrt.dta", ///
        id(id) start(rx_start) stop(rx_stop) ///
        exposure(hrt_type) reference(0) ///
        entry(study_entry) exit(study_exit) ///
        grace(30) lag(14) washout(60) ///
        keepvars(age female) ///
        referencelabel("Unexposed") ///
        generate(tv_hrt) ///
        check summarize ///
        saveas("${DATA_DIR}/_test_tvexpose_combined") replace

    use "${DATA_DIR}/_test_tvexpose_combined.dta", clear
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
* TEST 21: recency() option (time since last exposure categories)
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': recency() option"
display as text "{hline 50}"

capture noisily {
    use "${DATA_DIR}/cohort.dta", clear

    tvexpose using "${DATA_DIR}/hrt.dta", ///
        id(id) start(rx_start) stop(rx_stop) ///
        exposure(hrt_type) reference(0) ///
        entry(study_entry) exit(study_exit) ///
        recency(1 5) ///
        generate(recency_hrt) ///
        saveas("${DATA_DIR}/_test_tvexpose_recency") replace

    use "${DATA_DIR}/_test_tvexpose_recency.dta", clear
    assert _N > 0
    confirm variable recency_hrt
    tab recency_hrt
    display as result "  PASSED: recency() option works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 22: expandunit() option (row expansion granularity)
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': expandunit() option"
display as text "{hline 50}"

capture noisily {
    use "${DATA_DIR}/cohort.dta", clear

    tvexpose using "${DATA_DIR}/hrt.dta", ///
        id(id) start(rx_start) stop(rx_stop) ///
        exposure(hrt_type) reference(0) ///
        entry(study_entry) exit(study_exit) ///
        continuousunit(years) expandunit(months) ///
        generate(tv_hrt) ///
        saveas("${DATA_DIR}/_test_tvexpose_expand") replace

    use "${DATA_DIR}/_test_tvexpose_expand.dta", clear
    assert _N > 0
    confirm variable tv_hrt
    display as result "  PASSED: expandunit() option works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 23: type-specific grace periods grace(exp=# ...)
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': type-specific grace periods"
display as text "{hline 50}"

capture noisily {
    use "${DATA_DIR}/cohort.dta", clear

    tvexpose using "${DATA_DIR}/hrt.dta", ///
        id(id) start(rx_start) stop(rx_stop) ///
        exposure(hrt_type) reference(0) ///
        entry(study_entry) exit(study_exit) ///
        grace(1=30 2=60 3=90) ///
        generate(tv_hrt) ///
        saveas("${DATA_DIR}/_test_tvexpose_grace_types") replace

    use "${DATA_DIR}/_test_tvexpose_grace_types.dta", clear
    assert _N > 0
    display as result "  PASSED: type-specific grace periods work"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 24: merge() option (merge consecutive periods)
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': merge() option"
display as text "{hline 50}"

capture noisily {
    use "${DATA_DIR}/cohort.dta", clear

    tvexpose using "${DATA_DIR}/hrt.dta", ///
        id(id) start(rx_start) stop(rx_stop) ///
        exposure(hrt_type) reference(0) ///
        entry(study_entry) exit(study_exit) ///
        merge(60) ///
        generate(tv_hrt) ///
        saveas("${DATA_DIR}/_test_tvexpose_merge") replace

    use "${DATA_DIR}/_test_tvexpose_merge.dta", clear
    assert _N > 0
    display as result "  PASSED: merge() option works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 25: fillgaps() option
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': fillgaps() option"
display as text "{hline 50}"

capture noisily {
    use "${DATA_DIR}/cohort.dta", clear

    tvexpose using "${DATA_DIR}/hrt.dta", ///
        id(id) start(rx_start) stop(rx_stop) ///
        exposure(hrt_type) reference(0) ///
        entry(study_entry) exit(study_exit) ///
        fillgaps(30) ///
        generate(tv_hrt) ///
        saveas("${DATA_DIR}/_test_tvexpose_fillgaps") replace

    use "${DATA_DIR}/_test_tvexpose_fillgaps.dta", clear
    assert _N > 0
    display as result "  PASSED: fillgaps() option works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 26: carryforward() option
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': carryforward() option"
display as text "{hline 50}"

capture noisily {
    use "${DATA_DIR}/cohort.dta", clear

    tvexpose using "${DATA_DIR}/hrt.dta", ///
        id(id) start(rx_start) stop(rx_stop) ///
        exposure(hrt_type) reference(0) ///
        entry(study_entry) exit(study_exit) ///
        carryforward(60) ///
        generate(tv_hrt) ///
        saveas("${DATA_DIR}/_test_tvexpose_carry") replace

    use "${DATA_DIR}/_test_tvexpose_carry.dta", clear
    assert _N > 0
    display as result "  PASSED: carryforward() option works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 27: layer option (competing exposures - later takes precedence)
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': layer option"
display as text "{hline 50}"

capture noisily {
    use "${DATA_DIR}/cohort.dta", clear

    tvexpose using "${DATA_DIR}/dmt.dta", ///
        id(id) start(dmt_start) stop(dmt_stop) ///
        exposure(dmt) reference(0) ///
        entry(study_entry) exit(study_exit) ///
        layer ///
        generate(tv_dmt) ///
        saveas("${DATA_DIR}/_test_tvexpose_layer") replace

    use "${DATA_DIR}/_test_tvexpose_layer.dta", clear
    assert _N > 0
    display as result "  PASSED: layer option works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 28: priority() option (priority order for overlaps)
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': priority() option"
display as text "{hline 50}"

capture noisily {
    use "${DATA_DIR}/cohort.dta", clear

    tvexpose using "${DATA_DIR}/dmt.dta", ///
        id(id) start(dmt_start) stop(dmt_stop) ///
        exposure(dmt) reference(0) ///
        entry(study_entry) exit(study_exit) ///
        priority(6 5 4 3 2 1) ///
        generate(tv_dmt) ///
        saveas("${DATA_DIR}/_test_tvexpose_priority") replace

    use "${DATA_DIR}/_test_tvexpose_priority.dta", clear
    assert _N > 0
    display as result "  PASSED: priority() option works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 29: split option (split overlapping periods)
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': split option"
display as text "{hline 50}"

capture noisily {
    use "${DATA_DIR}/cohort.dta", clear

    tvexpose using "${DATA_DIR}/dmt.dta", ///
        id(id) start(dmt_start) stop(dmt_stop) ///
        exposure(dmt) reference(0) ///
        entry(study_entry) exit(study_exit) ///
        split ///
        generate(tv_dmt) ///
        saveas("${DATA_DIR}/_test_tvexpose_split") replace

    use "${DATA_DIR}/_test_tvexpose_split.dta", clear
    assert _N > 0
    display as result "  PASSED: split option works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 30: combine() option (combined exposure variable)
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': combine() option"
display as text "{hline 50}"

capture noisily {
    use "${DATA_DIR}/cohort.dta", clear

    tvexpose using "${DATA_DIR}/dmt.dta", ///
        id(id) start(dmt_start) stop(dmt_stop) ///
        exposure(dmt) reference(0) ///
        entry(study_entry) exit(study_exit) ///
        combine(combined_dmt) ///
        generate(tv_dmt) ///
        saveas("${DATA_DIR}/_test_tvexpose_combine") replace

    use "${DATA_DIR}/_test_tvexpose_combine.dta", clear
    assert _N > 0
    confirm variable combined_dmt
    display as result "  PASSED: combine() option works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 31: window() option (acute exposure window)
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': window() option"
display as text "{hline 50}"

capture noisily {
    use "${DATA_DIR}/cohort.dta", clear

    tvexpose using "${DATA_DIR}/hrt.dta", ///
        id(id) start(rx_start) stop(rx_stop) ///
        exposure(hrt_type) reference(0) ///
        entry(study_entry) exit(study_exit) ///
        window(7 90) ///
        generate(tv_hrt) ///
        saveas("${DATA_DIR}/_test_tvexpose_window") replace

    use "${DATA_DIR}/_test_tvexpose_window.dta", clear
    assert _N > 0
    display as result "  PASSED: window() option works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 32: switching option (binary switching indicator)
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': switching option"
display as text "{hline 50}"

capture noisily {
    use "${DATA_DIR}/cohort.dta", clear

    tvexpose using "${DATA_DIR}/dmt.dta", ///
        id(id) start(dmt_start) stop(dmt_stop) ///
        exposure(dmt) reference(0) ///
        entry(study_entry) exit(study_exit) ///
        switching ///
        generate(tv_dmt) ///
        saveas("${DATA_DIR}/_test_tvexpose_switching") replace

    use "${DATA_DIR}/_test_tvexpose_switching.dta", clear
    assert _N > 0
    confirm variable has_switched
    tab has_switched
    display as result "  PASSED: switching option works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 33: switchingdetail option (switching pattern string)
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': switchingdetail option"
display as text "{hline 50}"

capture noisily {
    use "${DATA_DIR}/cohort.dta", clear

    tvexpose using "${DATA_DIR}/dmt.dta", ///
        id(id) start(dmt_start) stop(dmt_stop) ///
        exposure(dmt) reference(0) ///
        entry(study_entry) exit(study_exit) ///
        switchingdetail ///
        generate(tv_dmt) ///
        saveas("${DATA_DIR}/_test_tvexpose_switchdet") replace

    use "${DATA_DIR}/_test_tvexpose_switchdet.dta", clear
    assert _N > 0
    confirm variable switching_pattern
    display as result "  PASSED: switchingdetail option works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 34: statetime option (cumulative time in current state)
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': statetime option"
display as text "{hline 50}"

capture noisily {
    use "${DATA_DIR}/cohort.dta", clear

    tvexpose using "${DATA_DIR}/dmt.dta", ///
        id(id) start(dmt_start) stop(dmt_stop) ///
        exposure(dmt) reference(0) ///
        entry(study_entry) exit(study_exit) ///
        statetime ///
        generate(tv_dmt) ///
        saveas("${DATA_DIR}/_test_tvexpose_statetime") replace

    use "${DATA_DIR}/_test_tvexpose_statetime.dta", clear
    assert _N > 0
    display as result "  PASSED: statetime option works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 35: label() option (custom variable label)
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': label() option"
display as text "{hline 50}"

capture noisily {
    use "${DATA_DIR}/cohort.dta", clear

    tvexpose using "${DATA_DIR}/hrt.dta", ///
        id(id) start(rx_start) stop(rx_stop) ///
        exposure(hrt_type) reference(0) ///
        entry(study_entry) exit(study_exit) ///
        label("Custom HRT Exposure Label") ///
        generate(tv_hrt) ///
        saveas("${DATA_DIR}/_test_tvexpose_label") replace

    use "${DATA_DIR}/_test_tvexpose_label.dta", clear
    assert _N > 0
    local varlbl : variable label tv_hrt
    assert "`varlbl'" == "Custom HRT Exposure Label"
    display as result "  PASSED: label() option works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 36: keepdates option (keep entry/exit dates)
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': keepdates option"
display as text "{hline 50}"

capture noisily {
    use "${DATA_DIR}/cohort.dta", clear

    tvexpose using "${DATA_DIR}/hrt.dta", ///
        id(id) start(rx_start) stop(rx_stop) ///
        exposure(hrt_type) reference(0) ///
        entry(study_entry) exit(study_exit) ///
        keepdates ///
        generate(tv_hrt) ///
        saveas("${DATA_DIR}/_test_tvexpose_keepdates") replace

    use "${DATA_DIR}/_test_tvexpose_keepdates.dta", clear
    assert _N > 0
    confirm variable study_entry study_exit
    display as result "  PASSED: keepdates option works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 37: switching + switchingdetail combined
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': switching + switchingdetail combined"
display as text "{hline 50}"

capture noisily {
    use "${DATA_DIR}/cohort.dta", clear

    tvexpose using "${DATA_DIR}/dmt.dta", ///
        id(id) start(dmt_start) stop(dmt_stop) ///
        exposure(dmt) reference(0) ///
        entry(study_entry) exit(study_exit) ///
        switching switchingdetail ///
        generate(tv_dmt) ///
        saveas("${DATA_DIR}/_test_tvexpose_switch_both") replace

    use "${DATA_DIR}/_test_tvexpose_switch_both.dta", clear
    assert _N > 0
    confirm variable has_switched switching_pattern
    display as result "  PASSED: switching + switchingdetail combined works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 38: dose option (continuous cumulative dose)
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': dose option (continuous cumulative dose)"
display as text "{hline 50}"

capture noisily {
    use "${DATA_DIR}/cohort.dta", clear

    * Use steroids.dta which has steroid_dose amounts
    tvexpose using "${DATA_DIR}/steroids.dta", ///
        id(id) start(steroid_start) stop(steroid_stop) ///
        exposure(steroid_dose) ///
        entry(study_entry) exit(study_exit) ///
        dose ///
        generate(cumul_steroid) ///
        saveas("${DATA_DIR}/_test_tvexpose_dose") replace

    use "${DATA_DIR}/_test_tvexpose_dose.dta", clear
    assert _N > 0
    confirm variable cumul_steroid
    * Cumulative dose should be non-negative
    sum cumul_steroid
    assert r(min) >= 0
    display as text "  Cumulative dose range: " r(min) " to " r(max)
    display as result "  PASSED: dose option works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 39: dose + dosecuts() option (categorized cumulative dose)
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': dose + dosecuts() option"
display as text "{hline 50}"

capture noisily {
    use "${DATA_DIR}/cohort.dta", clear

    * Use steroids.dta with cutpoints at 1000, 3000, 5000 mg
    tvexpose using "${DATA_DIR}/steroids.dta", ///
        id(id) start(steroid_start) stop(steroid_stop) ///
        exposure(steroid_dose) ///
        entry(study_entry) exit(study_exit) ///
        dose dosecuts(1000 3000 5000) ///
        generate(dose_cat) ///
        saveas("${DATA_DIR}/_test_tvexpose_dosecuts") replace

    use "${DATA_DIR}/_test_tvexpose_dosecuts.dta", clear
    assert _N > 0
    confirm variable dose_cat
    * Should have categories: 0=no dose, 1=<1000, 2=1000-<3000, 3=3000-<5000, 4=5000+
    tab dose_cat
    display as result "  PASSED: dose + dosecuts() option works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 40: dose option with overlapping periods (proportional allocation)
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': dose with overlapping periods"
display as text "{hline 50}"

capture noisily {
    use "${DATA_DIR}/cohort.dta", clear

    * steroids.dta has intentional overlaps to test proportional dose allocation
    tvexpose using "${DATA_DIR}/steroids.dta", ///
        id(id) start(steroid_start) stop(steroid_stop) ///
        exposure(steroid_dose) ///
        entry(study_entry) exit(study_exit) ///
        dose ///
        generate(cumul_steroid) ///
        check ///
        saveas("${DATA_DIR}/_test_tvexpose_dose_overlap") replace

    use "${DATA_DIR}/_test_tvexpose_dose_overlap.dta", clear
    assert _N > 0
    * Should have handled overlaps with proportional allocation
    display as result "  PASSED: dose with overlapping periods works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 41: dose option with keepvars
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': dose + keepvars() option"
display as text "{hline 50}"

capture noisily {
    use "${DATA_DIR}/cohort.dta", clear

    tvexpose using "${DATA_DIR}/steroids.dta", ///
        id(id) start(steroid_start) stop(steroid_stop) ///
        exposure(steroid_dose) ///
        entry(study_entry) exit(study_exit) ///
        dose ///
        keepvars(age female mstype) ///
        generate(cumul_steroid) ///
        saveas("${DATA_DIR}/_test_tvexpose_dose_keep") replace

    use "${DATA_DIR}/_test_tvexpose_dose_keep.dta", clear
    assert _N > 0
    confirm variable cumul_steroid age female mstype
    display as result "  PASSED: dose + keepvars() option works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 42: dose option - verify reference defaults to 0
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': dose with default reference(0)"
display as text "{hline 50}"

capture noisily {
    use "${DATA_DIR}/cohort.dta", clear

    * Note: reference() is optional with dose, should default to 0
    tvexpose using "${DATA_DIR}/steroids.dta", ///
        id(id) start(steroid_start) stop(steroid_stop) ///
        exposure(steroid_dose) ///
        entry(study_entry) exit(study_exit) ///
        dose ///
        generate(cumul_steroid) ///
        saveas("${DATA_DIR}/_test_tvexpose_dose_noref") replace

    use "${DATA_DIR}/_test_tvexpose_dose_noref.dta", clear
    assert _N > 0
    * Minimum cumulative dose should be 0 (reference)
    sum cumul_steroid
    assert r(min) == 0
    display as result "  PASSED: dose defaults reference to 0"
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

local temp_files "_test_tvexpose_basic _test_tvexpose_ever _test_tvexpose_cf _test_tvexpose_dur _test_tvexpose_cont _test_tvexpose_grace _test_tvexpose_lag _test_tvexpose_washout _test_tvexpose_bytype _test_tvexpose_dmt _test_tvexpose_check _test_tvexpose_summ _test_tvexpose_validate _test_tvexpose_gaps _test_tvexpose_overlaps _test_tvexpose_reflabel _test_tvexpose_keepvars _test_tvexpose_results _test_tvexpose_females _test_tvexpose_combined _test_tvexpose_recency _test_tvexpose_expand _test_tvexpose_grace_types _test_tvexpose_merge _test_tvexpose_fillgaps _test_tvexpose_carry _test_tvexpose_layer _test_tvexpose_priority _test_tvexpose_split _test_tvexpose_combine _test_tvexpose_window _test_tvexpose_switching _test_tvexpose_switchdet _test_tvexpose_statetime _test_tvexpose_label _test_tvexpose_keepdates _test_tvexpose_switch_both _test_tvexpose_dose _test_tvexpose_dosecuts _test_tvexpose_dose_overlap _test_tvexpose_dose_keep _test_tvexpose_dose_noref"

foreach f of local temp_files {
    capture erase "${DATA_DIR}/`f'.dta"
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
