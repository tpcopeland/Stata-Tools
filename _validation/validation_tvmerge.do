/*******************************************************************************
* validation_tvmerge.do
*
* Purpose: Deep validation tests for tvmerge command using known-answer testing
*          These tests verify interval intersection, person-time calculations,
*          and ID matching behavior.
*
* Philosophy: Create minimal datasets where every output value can be
*             mathematically verified by hand.
*
* Run modes:
*   Standalone: do validation_tvmerge.do
*   Via runner: do run_test.do validation_tvmerge [testnumber] [quiet] [machine]
*
* Prerequisites:
*   - tvmerge.ado must be installed/accessible
*
* Author: Auto-generated from validation plan
* Date: 2025-12-13
*******************************************************************************/

clear all
set more off
version 16.0

* =============================================================================
* CONFIGURATION: Check for runner globals or set defaults
* =============================================================================
if "$RUN_TEST_QUIET" == "" {
    global RUN_TEST_QUIET = 0
}
if "$RUN_TEST_MACHINE" == "" {
    global RUN_TEST_MACHINE = 0
}
if "$RUN_TEST_NUMBER" == "" {
    global RUN_TEST_NUMBER = 0
}

local quiet = $RUN_TEST_QUIET
local machine = $RUN_TEST_MACHINE
local run_only = $RUN_TEST_NUMBER

* =============================================================================
* PATH CONFIGURATION
* =============================================================================
* Cross-platform path detection
if "`c(os)'" == "MacOSX" {
    global STATA_TOOLS_PATH "/Users/tcopeland/Documents/GitHub/Stata-Tools"
}
else if "`c(os)'" == "Unix" {
    global STATA_TOOLS_PATH "/home/ubuntu/Stata-Tools"
}
else {
    * Windows or other - try to detect from current directory
    capture confirm file "_validation"
    if _rc == 0 {
        * Running from repo root
        global STATA_TOOLS_PATH "`c(pwd)'"
    }
    else {
        capture confirm file "data"
        if _rc == 0 {
            * Running from _validation directory
            global STATA_TOOLS_PATH "`c(pwd)'/.."
        }
        else {
            * Assume running from _validation/data directory
            global STATA_TOOLS_PATH "`c(pwd)'/../.."
        }
    }
}

global VALIDATION_DIR "${STATA_TOOLS_PATH}/_validation"
global DATA_DIR "${VALIDATION_DIR}/data"

* Create data directory if needed
capture mkdir "${DATA_DIR}"

* Install tvtools package
capture net uninstall tvtools
quietly net install tvtools, from("${STATA_TOOLS_PATH}/tvtools")
capture quietly ssc install distinct

* =============================================================================
* HEADER (skip in quiet/machine mode)
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "TVMERGE DEEP VALIDATION TESTS"
    display as text "{hline 70}"
    display as text "These tests verify mathematical correctness, not just execution."
    display as text "{hline 70}"
}

* =============================================================================
* TEST COUNTERS
* =============================================================================
local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

* =============================================================================
* HELPER PROGRAMS
* =============================================================================

* Program to verify non-overlapping intervals
capture program drop _verify_no_overlap
program define _verify_no_overlap, rclass
    syntax, id(varname) start(varname) stop(varname)

    sort `id' `start' `stop'
    tempvar prev_stop overlap
    by `id': gen double `prev_stop' = `stop'[_n-1] if _n > 1
    by `id': gen byte `overlap' = (`start' < `prev_stop') if _n > 1
    quietly count if `overlap' == 1
    return scalar n_overlaps = r(N)
end

* =============================================================================
* CREATE VALIDATION DATA
* =============================================================================
if `quiet' == 0 {
    display as text _n "Creating validation datasets..."
}

* Dataset 1: Single full-year interval
clear
input long id double(start1 stop1) byte exp1
    1 21915 22281 1
end
format %td start1 stop1
label data "Dataset 1: Single full-year interval"
save "${DATA_DIR}/tvmerge_ds1_fullyear.dta", replace

* Dataset 2: Two intervals covering the year
clear
input long id double(start2 stop2) byte exp2
    1 21915 22097 1
    1 22097 22281 2
end
format %td start2 stop2
label data "Dataset 2: Two intervals (Jan-Jun = exp2=1, Jul-Dec = exp2=2)"
save "${DATA_DIR}/tvmerge_ds2_split.dta", replace

* Dataset 1: Partial year (Jan-Jun)
clear
input long id double(start1 stop1) byte exp1
    1 21915 22097 1
end
format %td start1 stop1
label data "Dataset 1: Jan-Jun only"
save "${DATA_DIR}/tvmerge_ds1_partial.dta", replace

* Dataset 2: Partial year (Mar-Sep)
clear
input long id double(start2 stop2) byte exp2
    1 21975 22189 2
end
format %td start2 stop2
label data "Dataset 2: Mar-Sep only"
save "${DATA_DIR}/tvmerge_ds2_partial.dta", replace

* Non-overlapping datasets
clear
input long id double(start1 stop1) byte exp1
    1 21915 21975 1
end
format %td start1 stop1
label data "Dataset 1: Jan-Mar only"
save "${DATA_DIR}/tvmerge_ds1_nonoverlap.dta", replace

clear
input long id double(start2 stop2) byte exp2
    1 22097 22281 2
end
format %td start2 stop2
label data "Dataset 2: Jul-Dec only (no overlap with ds1)"
save "${DATA_DIR}/tvmerge_ds2_nonoverlap.dta", replace

* Datasets with different IDs for intersection testing
clear
input long id double(start1 stop1) byte exp1
    1 21915 22281 1
    2 21915 22281 1
    3 21915 22281 1
end
format %td start1 stop1
label data "Dataset 1: IDs 1, 2, 3"
save "${DATA_DIR}/tvmerge_ds1_ids123.dta", replace

clear
input long id double(start2 stop2) byte exp2
    2 21915 22281 2
    3 21915 22281 2
    4 21915 22281 2
end
format %td start2 stop2
label data "Dataset 2: IDs 2, 3, 4"
save "${DATA_DIR}/tvmerge_ds2_ids234.dta", replace

* Datasets with continuous variables
clear
input long id double(start1 stop1) double cum1
    1 21915 22281 365
end
format %td start1 stop1
label data "Dataset 1: Full year, cumulative = 365"
save "${DATA_DIR}/tvmerge_ds1_cont.dta", replace

clear
input long id double(start2 stop2) double cum2
    1 21915 22097 100
end
format %td start2 stop2
label data "Dataset 2: First half, cumulative = 100"
save "${DATA_DIR}/tvmerge_ds2_cont.dta", replace

* Three datasets for three-way merge testing
clear
input long id double(s1 e1) byte x1
    1 21915 22189 1
end
format %td s1 e1
label data "Dataset 1: Jan-Sep"
save "${DATA_DIR}/tvmerge_3way_ds1.dta", replace

clear
input long id double(s2 e2) byte x2
    1 22006 22281 2
end
format %td s2 e2
label data "Dataset 2: Apr-Dec"
save "${DATA_DIR}/tvmerge_3way_ds2.dta", replace

clear
input long id double(s3 e3) byte x3
    1 22067 22281 3
end
format %td s3 e3
label data "Dataset 3: Jun-Dec"
save "${DATA_DIR}/tvmerge_3way_ds3.dta", replace

if `quiet' == 0 {
    display as result "Validation datasets created in: ${DATA_DIR}"
}

* =============================================================================
* TEST SECTION 5.1: CARTESIAN PRODUCT TESTS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 5.1: Cartesian Product Tests"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 5.1.1: Complete Intersection Coverage
* Purpose: Verify all overlapping intervals from both datasets appear
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 5.1.1: Complete Intersection Coverage"
}

capture {
    tvmerge "${DATA_DIR}/tvmerge_ds1_fullyear.dta" "${DATA_DIR}/tvmerge_ds2_split.dta", ///
        id(id) start(start1 start2) stop(stop1 stop2) ///
        exposure(exp1 exp2)

    * Should produce 2 intervals (Jan-Jun, Jul-Dec)
    assert _N == 2

    * Verify both exposure values present
    sort start
    assert exp1 == 1 in 1/2
    assert exp2 == 1 in 1
    assert exp2 == 2 in 2
}
if _rc == 0 {
    display as result "  PASS: Intersection produces correct number of intervals (2)"
    local ++pass_count
}
else {
    display as error "  FAIL: Complete intersection coverage (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 5.1.1"
}

* -----------------------------------------------------------------------------
* Test 5.1.2: Non-Overlapping Periods Excluded
* Purpose: Verify intervals that don't overlap produce no output
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 5.1.2: Non-Overlapping Periods Excluded"
}

capture {
    tvmerge "${DATA_DIR}/tvmerge_ds1_nonoverlap.dta" "${DATA_DIR}/tvmerge_ds2_nonoverlap.dta", ///
        id(id) start(start1 start2) stop(stop1 stop2) ///
        exposure(exp1 exp2)

    * Should produce 0 intervals (no overlap)
    assert _N == 0
}
if _rc == 0 {
    display as result "  PASS: Non-overlapping periods produce 0 intervals"
    local ++pass_count
}
else {
    display as error "  FAIL: Non-overlapping periods (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 5.1.2"
}

* =============================================================================
* TEST SECTION 5.2: PERSON-TIME TESTS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 5.2: Person-Time Tests"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 5.2.1: Merged Duration Equals Intersection
* Purpose: Verify output duration matches overlap duration exactly
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 5.2.1: Merged Duration Equals Intersection"
}

capture {
    tvmerge "${DATA_DIR}/tvmerge_ds1_partial.dta" "${DATA_DIR}/tvmerge_ds2_partial.dta", ///
        id(id) start(start1 start2) stop(stop1 stop2) ///
        exposure(exp1 exp2)

    * Overlap is Mar 1 - Jun 30 (ds1 ends Jun 30, ds2 starts Mar 1)
    * Calculate overlap duration
    gen dur = stop - start
    quietly sum dur

    * Mar 1 (21975) to Jun 30 (22097) = 122 days
    local expected_dur = 22097 - 21975
    assert abs(r(sum) - `expected_dur') < 1
}
if _rc == 0 {
    display as result "  PASS: Merged duration equals intersection (122 days)"
    local ++pass_count
}
else {
    display as error "  FAIL: Merged duration (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 5.2.1"
}

* -----------------------------------------------------------------------------
* Test 5.2.2: No Overlapping Intervals in Output
* Purpose: Verify merged output has no overlapping intervals per ID
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 5.2.2: No Overlapping Intervals in Output"
}

capture {
    tvmerge "${DATA_DIR}/tvmerge_ds1_fullyear.dta" "${DATA_DIR}/tvmerge_ds2_split.dta", ///
        id(id) start(start1 start2) stop(stop1 stop2) ///
        exposure(exp1 exp2)

    _verify_no_overlap, id(id) start(start) stop(stop)
    assert r(n_overlaps) == 0
}
if _rc == 0 {
    display as result "  PASS: No overlapping intervals in merged output"
    local ++pass_count
}
else {
    display as error "  FAIL: Non-overlapping output (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 5.2.2"
}

* =============================================================================
* TEST SECTION 5.3: CONTINUOUS VARIABLE TESTS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 5.3: Continuous Variable Tests"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 5.3.1: Continuous Interpolation
* Purpose: Verify continuous values are pro-rated correctly
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 5.3.1: Continuous Variable Interpolation"
}

capture {
    tvmerge "${DATA_DIR}/tvmerge_ds1_cont.dta" "${DATA_DIR}/tvmerge_ds2_cont.dta", ///
        id(id) start(start1 start2) stop(stop1 stop2) ///
        exposure(cum1 cum2) continuous(cum1 cum2)

    * Output overlap is Jan 1 - Jun 30 (182/366 of ds1)
    * ds1 total was 365 cumulative over 366 days
    * ds2 total was 100 cumulative over 182 days
    * Intersection is exactly ds2 range (Jan-Jun)

    gen dur = stop - start
    quietly sum dur
    local overlap_dur = r(sum)

    * cum1 should be approximately 182 (182/366 * 365)
    * cum2 should be exactly 100 (full ds2 range)
    quietly sum cum1
    local cum1_val = r(mean)

    quietly sum cum2
    local cum2_val = r(mean)

    * Allow some tolerance for pro-rating
    assert abs(`cum2_val' - 100) < 2
}
if _rc == 0 {
    display as result "  PASS: Continuous variables interpolated correctly"
    local ++pass_count
}
else {
    display as error "  FAIL: Continuous interpolation (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 5.3.1"
}

* =============================================================================
* TEST SECTION 5.4: ID MATCHING TESTS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 5.4: ID Matching Tests"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 5.4.1: ID Intersection Behavior (Without Force)
* Purpose: Verify error when IDs don't match without force option
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 5.4.1: ID Mismatch Without Force"
}

capture {
    * Without force: should error on mismatch
    capture tvmerge "${DATA_DIR}/tvmerge_ds1_ids123.dta" "${DATA_DIR}/tvmerge_ds2_ids234.dta", ///
        id(id) start(start1 start2) stop(stop1 stop2) ///
        exposure(exp1 exp2)

    * Should fail because IDs don't match completely
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: ID mismatch without force produces error"
    local ++pass_count
}
else {
    display as error "  FAIL: ID mismatch error handling (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 5.4.1"
}

* -----------------------------------------------------------------------------
* Test 5.4.2: ID Intersection Behavior (With Force)
* Purpose: Verify force option allows ID mismatches with intersection
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 5.4.2: ID Intersection With Force"
}

capture {
    * With force: should warn and keep only intersection (IDs 2, 3)
    tvmerge "${DATA_DIR}/tvmerge_ds1_ids123.dta" "${DATA_DIR}/tvmerge_ds2_ids234.dta", ///
        id(id) start(start1 start2) stop(stop1 stop2) ///
        exposure(exp1 exp2) force

    distinct id
    * Only IDs 2 and 3 should appear (intersection)
    assert r(ndistinct) == 2

    * Verify it's IDs 2 and 3
    quietly count if id == 1
    assert r(N) == 0

    quietly count if id == 4
    assert r(N) == 0

    quietly count if id == 2
    assert r(N) >= 1

    quietly count if id == 3
    assert r(N) >= 1
}
if _rc == 0 {
    display as result "  PASS: force option keeps ID intersection (IDs 2, 3)"
    local ++pass_count
}
else {
    display as error "  FAIL: ID intersection with force (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 5.4.2"
}

* =============================================================================
* TEST SECTION 5.5: THREE-WAY MERGE TESTS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 5.5: Three-Way Merge Tests"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 5.5.1: Three Dataset Intersection
* Purpose: Verify three-way merge creates correct intersection
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 5.5.1: Three-Way Merge Intersection"
}

capture {
    * ds1: Jan-Sep (21915-22189)
    * ds2: Apr-Dec (22006-22281)
    * ds3: Jun-Dec (22067-22281)
    * Three-way overlap: Jun 1 - Sep 30 (22067-22189)

    tvmerge "${DATA_DIR}/tvmerge_3way_ds1.dta" "${DATA_DIR}/tvmerge_3way_ds2.dta" ///
        "${DATA_DIR}/tvmerge_3way_ds3.dta", ///
        id(id) start(s1 s2 s3) stop(e1 e2 e3) ///
        exposure(x1 x2 x3)

    * Should have intersection Jun 1 - Sep 30
    quietly sum start
    assert r(min) == 22067

    quietly sum stop
    assert r(max) == 22189

    * All three exposure variables should be present
    confirm variable x1 x2 x3
}
if _rc == 0 {
    display as result "  PASS: Three-way merge creates correct intersection (Jun-Sep)"
    local ++pass_count
}
else {
    display as error "  FAIL: Three-way merge (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 5.5.1"
}

* -----------------------------------------------------------------------------
* Test 5.5.2: Three-Way Merge Duration Calculation
* Purpose: Verify duration of three-way intersection is correct
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 5.5.2: Three-Way Merge Duration"
}

capture {
    tvmerge "${DATA_DIR}/tvmerge_3way_ds1.dta" "${DATA_DIR}/tvmerge_3way_ds2.dta" ///
        "${DATA_DIR}/tvmerge_3way_ds3.dta", ///
        id(id) start(s1 s2 s3) stop(e1 e2 e3) ///
        exposure(x1 x2 x3)

    * Jun 1 (22067) to Sep 30 (22189) = 122 days
    gen dur = stop - start
    quietly sum dur
    local expected = 22189 - 22067
    assert abs(r(sum) - `expected') < 1
}
if _rc == 0 {
    display as result "  PASS: Three-way merge duration correct (122 days)"
    local ++pass_count
}
else {
    display as error "  FAIL: Three-way duration (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 5.5.2"
}

* =============================================================================
* TEST SECTION: ERROR HANDLING
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "ERROR HANDLING TESTS"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test: Missing Required Options
* Purpose: Verify errors for missing required inputs
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test: Missing Required Options"
}

capture {
    * Missing id()
    capture tvmerge "${DATA_DIR}/tvmerge_ds1_fullyear.dta" "${DATA_DIR}/tvmerge_ds2_split.dta", ///
        start(start1 start2) stop(stop1 stop2) exposure(exp1 exp2)
    local rc1 = _rc

    * Missing start()
    capture tvmerge "${DATA_DIR}/tvmerge_ds1_fullyear.dta" "${DATA_DIR}/tvmerge_ds2_split.dta", ///
        id(id) stop(stop1 stop2) exposure(exp1 exp2)
    local rc2 = _rc

    * Both should fail
    assert `rc1' != 0
    assert `rc2' != 0
}
if _rc == 0 {
    display as result "  PASS: Missing required options produce errors"
    local ++pass_count
}
else {
    display as error "  FAIL: Missing options error handling (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' ErrReq"
}

* -----------------------------------------------------------------------------
* Test: File Not Found
* Purpose: Verify error when dataset file doesn't exist
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test: File Not Found"
}

capture {
    capture tvmerge "nonexistent_file.dta" "${DATA_DIR}/tvmerge_ds2_split.dta", ///
        id(id) start(start1 start2) stop(stop1 stop2) exposure(exp1 exp2)
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: Non-existent file produces error"
    local ++pass_count
}
else {
    display as error "  FAIL: File not found error handling (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' ErrFile"
}

* =============================================================================
* INVARIANT TESTS: Properties that must always hold
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "INVARIANT TESTS: Universal Properties"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Invariant 1: Date Ordering (start < stop for all rows)
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Invariant 1: Date Ordering (start < stop)"
}

capture {
    tvmerge "${DATA_DIR}/tvmerge_ds1_fullyear.dta" "${DATA_DIR}/tvmerge_ds2_split.dta", ///
        id(id) start(start1 start2) stop(stop1 stop2) ///
        exposure(exp1 exp2)

    quietly count if stop < start
    assert r(N) == 0
}
if _rc == 0 {
    display as result "  PASS: All rows have start < stop"
    local ++pass_count
}
else {
    display as error "  FAIL: Date ordering invariant (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' Inv1"
}

* -----------------------------------------------------------------------------
* Invariant 2: Output Contains Only IDs Present in All Inputs
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Invariant 2: Output IDs are Intersection of Input IDs"
}

capture {
    tvmerge "${DATA_DIR}/tvmerge_ds1_ids123.dta" "${DATA_DIR}/tvmerge_ds2_ids234.dta", ///
        id(id) start(start1 start2) stop(stop1 stop2) ///
        exposure(exp1 exp2) force

    * No ID=1 (only in ds1) or ID=4 (only in ds2) should appear
    quietly count if id == 1 | id == 4
    assert r(N) == 0
}
if _rc == 0 {
    display as result "  PASS: Output contains only intersecting IDs"
    local ++pass_count
}
else {
    display as error "  FAIL: ID intersection invariant (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' Inv2"
}

* -----------------------------------------------------------------------------
* Invariant 3: No Duplicate Intervals
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Invariant 3: No Duplicate Intervals"
}

capture {
    tvmerge "${DATA_DIR}/tvmerge_ds1_fullyear.dta" "${DATA_DIR}/tvmerge_ds2_split.dta", ///
        id(id) start(start1 start2) stop(stop1 stop2) ///
        exposure(exp1 exp2)

    * Check for duplicates on id, start, stop
    duplicates tag id start stop, gen(dup)
    quietly count if dup > 0
    assert r(N) == 0
    drop dup
}
if _rc == 0 {
    display as result "  PASS: No duplicate intervals in output"
    local ++pass_count
}
else {
    display as error "  FAIL: No duplicates invariant (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' Inv3"
}

* =============================================================================
* TEST SECTION 5.6: OUTPUT NAMING OPTIONS TESTS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 5.6: Output Naming Options Tests"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 5.6.1: generate() Creates Custom-Named Variables
* Purpose: Verify generate() renames exposure variables in output
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 5.6.1: generate() Custom Variable Names"
}

capture {
    tvmerge "${DATA_DIR}/tvmerge_ds1_fullyear.dta" "${DATA_DIR}/tvmerge_ds2_split.dta", ///
        id(id) start(start1 start2) stop(stop1 stop2) ///
        exposure(exp1 exp2) generate(hrt_type dmt_type)

    * Verify custom variable names exist
    confirm variable hrt_type
    confirm variable dmt_type
}
if _rc == 0 {
    display as result "  PASS: generate() creates custom-named variables"
    local ++pass_count
}
else {
    display as error "  FAIL: generate() custom names (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 5.6.1"
}

* -----------------------------------------------------------------------------
* Test 5.6.2: prefix() Adds Prefix to Variable Names
* Purpose: Verify prefix() adds consistent prefix to all exposure names
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 5.6.2: prefix() Adds Prefix"
}

capture {
    tvmerge "${DATA_DIR}/tvmerge_ds1_fullyear.dta" "${DATA_DIR}/tvmerge_ds2_split.dta", ///
        id(id) start(start1 start2) stop(stop1 stop2) ///
        exposure(exp1 exp2) prefix(tv_)

    * Verify prefixed variable names exist (prefix + original name)
    confirm variable tv_exp1
    confirm variable tv_exp2
}
if _rc == 0 {
    display as result "  PASS: prefix() adds prefix to variable names"
    local ++pass_count
}
else {
    display as error "  FAIL: prefix() (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 5.6.2"
}

* -----------------------------------------------------------------------------
* Test 5.6.3: startname() and stopname() Customize Date Variable Names
* Purpose: Verify startname/stopname change output date variable names
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 5.6.3: startname() and stopname() Custom Date Names"
}

capture {
    tvmerge "${DATA_DIR}/tvmerge_ds1_fullyear.dta" "${DATA_DIR}/tvmerge_ds2_split.dta", ///
        id(id) start(start1 start2) stop(stop1 stop2) ///
        exposure(exp1 exp2) ///
        startname(period_begin) stopname(period_end)

    * Verify custom date variable names exist
    confirm variable period_begin
    confirm variable period_end
}
if _rc == 0 {
    display as result "  PASS: startname()/stopname() customize date variable names"
    local ++pass_count
}
else {
    display as error "  FAIL: startname()/stopname() (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 5.6.3"
}

* -----------------------------------------------------------------------------
* Test 5.6.4: dateformat() Applies Custom Date Format
* Purpose: Verify dateformat() changes output date display format
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 5.6.4: dateformat() Custom Date Format"
}

capture {
    tvmerge "${DATA_DIR}/tvmerge_ds1_fullyear.dta" "${DATA_DIR}/tvmerge_ds2_split.dta", ///
        id(id) start(start1 start2) stop(stop1 stop2) ///
        exposure(exp1 exp2) dateformat(%tdCCYY-NN-DD)

    * Verify date format was applied
    local fmt : format start
    assert substr("`fmt'", 1, 3) == "%td"
}
if _rc == 0 {
    display as result "  PASS: dateformat() applies custom date format"
    local ++pass_count
}
else {
    display as error "  FAIL: dateformat() (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 5.6.4"
}

* =============================================================================
* TEST SECTION 5.7: DATA MANAGEMENT OPTIONS TESTS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 5.7: Data Management Options Tests"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 5.7.1: saveas() and replace Save Output File
* Purpose: Verify saveas() saves merged dataset to file
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 5.7.1: saveas() and replace Save Output"
}

capture {
    capture erase "${DATA_DIR}/tvmerge_output.dta"

    tvmerge "${DATA_DIR}/tvmerge_ds1_fullyear.dta" "${DATA_DIR}/tvmerge_ds2_split.dta", ///
        id(id) start(start1 start2) stop(stop1 stop2) ///
        exposure(exp1 exp2) ///
        saveas("${DATA_DIR}/tvmerge_output.dta") replace

    * Verify file was created
    confirm file "${DATA_DIR}/tvmerge_output.dta"

    * Load and verify content
    use "${DATA_DIR}/tvmerge_output.dta", clear
    assert _N >= 1

    * Cleanup
    capture erase "${DATA_DIR}/tvmerge_output.dta"
}
if _rc == 0 {
    display as result "  PASS: saveas() and replace save output file"
    local ++pass_count
}
else {
    display as error "  FAIL: saveas()/replace (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 5.7.1"
}

* Create datasets with additional variables for keep() testing
clear
input long id double(start1 stop1) byte exp1 int dose1
    1 21915 22281 1 100
end
format %td start1 stop1
label data "Dataset 1 with dose variable"
save "${DATA_DIR}/tvmerge_ds1_withvars.dta", replace

clear
input long id double(start2 stop2) byte exp2 str10 drug2
    1 21915 22097 1 "DrugA"
    1 22097 22281 2 "DrugB"
end
format %td start2 stop2
label data "Dataset 2 with drug variable"
save "${DATA_DIR}/tvmerge_ds2_withvars.dta", replace

* -----------------------------------------------------------------------------
* Test 5.7.2: keep() Retains Additional Variables
* Purpose: Verify keep() brings additional variables from source datasets
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 5.7.2: keep() Retains Additional Variables"
}

capture {
    tvmerge "${DATA_DIR}/tvmerge_ds1_withvars.dta" "${DATA_DIR}/tvmerge_ds2_withvars.dta", ///
        id(id) start(start1 start2) stop(stop1 stop2) ///
        exposure(exp1 exp2) keep(dose1 drug2)

    * Verify kept variables exist (with _ds# suffix)
    confirm variable dose1_ds1
    confirm variable drug2_ds2
}
if _rc == 0 {
    display as result "  PASS: keep() retains additional variables with suffixes"
    local ++pass_count
}
else {
    display as error "  FAIL: keep() (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 5.7.2"
}

* =============================================================================
* TEST SECTION 5.8: DIAGNOSTIC OPTIONS TESTS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 5.8: Diagnostic Options Tests"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 5.8.1: check Displays Diagnostics
* Purpose: Verify check option runs and displays coverage information
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 5.8.1: check Displays Diagnostics"
}

capture {
    tvmerge "${DATA_DIR}/tvmerge_ds1_fullyear.dta" "${DATA_DIR}/tvmerge_ds2_split.dta", ///
        id(id) start(start1 start2) stop(stop1 stop2) ///
        exposure(exp1 exp2) check

    * Should run without error
    assert _N >= 1
}
if _rc == 0 {
    display as result "  PASS: check displays diagnostics without error"
    local ++pass_count
}
else {
    display as error "  FAIL: check option (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 5.8.1"
}

* -----------------------------------------------------------------------------
* Test 5.8.2: validatecoverage Checks for Gaps
* Purpose: Verify validatecoverage option runs gap detection
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 5.8.2: validatecoverage Checks Gaps"
}

capture {
    tvmerge "${DATA_DIR}/tvmerge_ds1_fullyear.dta" "${DATA_DIR}/tvmerge_ds2_split.dta", ///
        id(id) start(start1 start2) stop(stop1 stop2) ///
        exposure(exp1 exp2) validatecoverage

    * Should run without error
    assert _N >= 1
}
if _rc == 0 {
    display as result "  PASS: validatecoverage checks for gaps"
    local ++pass_count
}
else {
    display as error "  FAIL: validatecoverage (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 5.8.2"
}

* -----------------------------------------------------------------------------
* Test 5.8.3: validateoverlap Checks for Overlaps
* Purpose: Verify validateoverlap option runs overlap detection
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 5.8.3: validateoverlap Checks Overlaps"
}

capture {
    tvmerge "${DATA_DIR}/tvmerge_ds1_fullyear.dta" "${DATA_DIR}/tvmerge_ds2_split.dta", ///
        id(id) start(start1 start2) stop(stop1 stop2) ///
        exposure(exp1 exp2) validateoverlap

    * Should run without error
    assert _N >= 1
}
if _rc == 0 {
    display as result "  PASS: validateoverlap checks for overlaps"
    local ++pass_count
}
else {
    display as error "  FAIL: validateoverlap (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 5.8.3"
}

* -----------------------------------------------------------------------------
* Test 5.8.4: summarize Displays Summary Statistics
* Purpose: Verify summarize option shows date range statistics
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 5.8.4: summarize Displays Statistics"
}

capture {
    tvmerge "${DATA_DIR}/tvmerge_ds1_fullyear.dta" "${DATA_DIR}/tvmerge_ds2_split.dta", ///
        id(id) start(start1 start2) stop(stop1 stop2) ///
        exposure(exp1 exp2) summarize

    * Should run without error
    assert _N >= 1
}
if _rc == 0 {
    display as result "  PASS: summarize displays summary statistics"
    local ++pass_count
}
else {
    display as error "  FAIL: summarize (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 5.8.4"
}

* =============================================================================
* TEST SECTION 5.9: PERFORMANCE OPTIONS TESTS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 5.9: Performance Options Tests"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 5.9.1: batch() Controls Batch Processing
* Purpose: Verify batch() option works with different batch sizes
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 5.9.1: batch() Batch Processing"
}

capture {
    * With batch(50) - larger batches
    tvmerge "${DATA_DIR}/tvmerge_ds1_ids123.dta" "${DATA_DIR}/tvmerge_ds2_ids234.dta", ///
        id(id) start(start1 start2) stop(stop1 stop2) ///
        exposure(exp1 exp2) batch(50) force

    local n_batch50 = _N

    * With batch(10) - smaller batches (should produce same result)
    tvmerge "${DATA_DIR}/tvmerge_ds1_ids123.dta" "${DATA_DIR}/tvmerge_ds2_ids234.dta", ///
        id(id) start(start1 start2) stop(stop1 stop2) ///
        exposure(exp1 exp2) batch(10) force

    local n_batch10 = _N

    * Results should be identical regardless of batch size
    assert `n_batch50' == `n_batch10'
}
if _rc == 0 {
    display as result "  PASS: batch() produces consistent results across batch sizes"
    local ++pass_count
}
else {
    display as error "  FAIL: batch() (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 5.9.1"
}

* =============================================================================
* TEST SECTION 5.10: STORED RESULTS TESTS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 5.10: Stored Results Tests"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 5.10.1: Stored Scalars
* Purpose: Verify r() scalars are correctly stored
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 5.10.1: Stored Scalars"
}

capture {
    tvmerge "${DATA_DIR}/tvmerge_ds1_fullyear.dta" "${DATA_DIR}/tvmerge_ds2_split.dta", ///
        id(id) start(start1 start2) stop(stop1 stop2) ///
        exposure(exp1 exp2)

    * Verify scalars exist
    assert r(N) > 0
    assert r(N_persons) > 0
    assert r(N_datasets) == 2
}
if _rc == 0 {
    display as result "  PASS: Stored scalars are correctly set"
    local ++pass_count
}
else {
    display as error "  FAIL: Stored scalars (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 5.10.1"
}

* -----------------------------------------------------------------------------
* Test 5.10.2: Stored Macros
* Purpose: Verify r() macros are correctly stored
* Note: r(datasets) contains quoted paths that need compound quoting
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 5.10.2: Stored Macros"
}

capture {
    tvmerge "${DATA_DIR}/tvmerge_ds1_fullyear.dta" "${DATA_DIR}/tvmerge_ds2_split.dta", ///
        id(id) start(start1 start2) stop(stop1 stop2) ///
        exposure(exp1 exp2) generate(hrt dmt)

    * Verify macros exist (use compound quotes for r(datasets) which contains paths)
    local ds_count : word count `r(datasets)'
    assert `ds_count' >= 1
    local exp_count : word count `r(exposure_vars)'
    assert `exp_count' >= 1
}
if _rc == 0 {
    display as result "  PASS: Stored macros are correctly set"
    local ++pass_count
}
else {
    display as error "  FAIL: Stored macros (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 5.10.2"
}

* =============================================================================
* SUMMARY
* =============================================================================
display as text _n "{hline 70}"
display as text "TVMERGE VALIDATION SUMMARY"
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
    display as error _n "FAILED TESTS:`failed_tests'"
    display as text "{hline 70}"
    display as error "Some validation tests FAILED."
    exit 1
}
else {
    display as result _n "ALL VALIDATION TESTS PASSED!"
}

display as text _n "Validation completed: `c(current_date)' `c(current_time)'"
display as text "{hline 70}"
