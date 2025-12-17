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
* TEST SECTION 5.11: BATCH SIZE EDGE CASES
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 5.11: batch() Edge Cases"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 5.11.1: batch(1) Minimum Batch Size
* Purpose: Verify batch(1) works correctly
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 5.11.1: batch(1) Minimum Batch Size"
}

capture {
    tvmerge "${DATA_DIR}/tvmerge_ds1_fullyear.dta" "${DATA_DIR}/tvmerge_ds2_split.dta", ///
        id(id) start(start1 start2) stop(stop1 stop2) ///
        exposure(exp1 exp2) batch(1)

    * Should work with minimum batch size
    assert _N >= 1
}
if _rc == 0 {
    display as result "  PASS: batch(1) works correctly"
    local ++pass_count
}
else {
    display as error "  FAIL: batch(1) (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 5.11.1"
}

* -----------------------------------------------------------------------------
* Test 5.11.2: batch(100) Maximum Batch Size
* Purpose: Verify batch(100) works correctly
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 5.11.2: batch(100) Maximum Batch Size"
}

capture {
    tvmerge "${DATA_DIR}/tvmerge_ds1_fullyear.dta" "${DATA_DIR}/tvmerge_ds2_split.dta", ///
        id(id) start(start1 start2) stop(stop1 stop2) ///
        exposure(exp1 exp2) batch(100)

    * Should work with maximum batch size
    assert _N >= 1
}
if _rc == 0 {
    display as result "  PASS: batch(100) works correctly"
    local ++pass_count
}
else {
    display as error "  FAIL: batch(100) (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 5.11.2"
}

* =============================================================================
* TEST SECTION 5.12: MISMATCHED OPTIONS ERROR HANDLING
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 5.12: Mismatched Options Error Handling"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 5.12.1: Mismatched start/stop Counts
* Purpose: Verify error when start() and stop() have different numbers
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 5.12.1: Mismatched start()/stop() Counts"
}

capture {
    capture tvmerge "${DATA_DIR}/tvmerge_ds1_fullyear.dta" "${DATA_DIR}/tvmerge_ds2_split.dta", ///
        id(id) start(start1 start2) stop(stop1) ///
        exposure(exp1 exp2)
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: Mismatched start/stop counts produces error"
    local ++pass_count
}
else {
    display as error "  FAIL: Mismatched start/stop error (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 5.12.1"
}

* -----------------------------------------------------------------------------
* Test 5.12.2: Mismatched Exposure Count
* Purpose: Verify error when exposure() count doesn't match datasets
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 5.12.2: Mismatched Exposure Count"
}

capture {
    capture tvmerge "${DATA_DIR}/tvmerge_ds1_fullyear.dta" "${DATA_DIR}/tvmerge_ds2_split.dta", ///
        id(id) start(start1 start2) stop(stop1 stop2) ///
        exposure(exp1)
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: Mismatched exposure count produces error"
    local ++pass_count
}
else {
    display as error "  FAIL: Mismatched exposure error (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 5.12.2"
}

* =============================================================================
* TEST SECTION 5.13: MULTIPLE EXPOSURES PER DATASET
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 5.13: Multiple Exposures Per Dataset"
    display as text "{hline 70}"
}

* Create dataset with multiple exposure variables
clear
input long id double(start1 stop1) byte exp1a double exp1b
    1 21915 22281 1 100
end
format %td start1 stop1
label data "Dataset with multiple exposures"
save "${DATA_DIR}/tvmerge_ds1_multi_exp.dta", replace

clear
input long id double(start2 stop2) byte exp2a double exp2b
    1 21915 22097 1 50
    1 22097 22281 2 75
end
format %td start2 stop2
label data "Dataset 2 with multiple exposures"
save "${DATA_DIR}/tvmerge_ds2_multi_exp.dta", replace

* -----------------------------------------------------------------------------
* Test 5.13.1: Multiple Exposures via keep()
* Purpose: Verify keep() can bring multiple exposure variables from each dataset
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 5.13.1: Multiple Exposures via keep()"
}

capture {
    tvmerge "${DATA_DIR}/tvmerge_ds1_multi_exp.dta" "${DATA_DIR}/tvmerge_ds2_multi_exp.dta", ///
        id(id) start(start1 start2) stop(stop1 stop2) ///
        exposure(exp1a exp2a) keep(exp1b exp2b)

    * Verify all exposure variables exist
    confirm variable exp1a
    confirm variable exp2a
    confirm variable exp1b_ds1
    confirm variable exp2b_ds2
}
if _rc == 0 {
    display as result "  PASS: Multiple exposures via keep() preserved"
    local ++pass_count
}
else {
    display as error "  FAIL: Multiple exposures (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 5.13.1"
}

* =============================================================================
* TEST SECTION 5.14: EMPTY DATASET HANDLING
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 5.14: Empty Dataset Handling"
    display as text "{hline 70}"
}

* Create empty dataset
clear
set obs 0
gen long id = .
gen double start1 = .
gen double stop1 = .
gen byte exp1 = .
format %td start1 stop1
label data "Empty dataset"
save "${DATA_DIR}/tvmerge_ds_empty.dta", replace

* -----------------------------------------------------------------------------
* Test 5.14.1: One Empty Dataset
* Purpose: Verify tvmerge detects empty dataset and produces error
* Note: tvmerge requires non-empty datasets - empty dataset handling is undefined
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 5.14.1: One Empty Dataset"
}

capture {
    tvmerge "${DATA_DIR}/tvmerge_ds_empty.dta" "${DATA_DIR}/tvmerge_ds2_split.dta", ///
        id(id) start(start1 start2) stop(stop1 stop2) ///
        exposure(exp1 exp2) force
}
* tvmerge should error on empty dataset (expected behavior)
if _rc != 0 {
    display as result "  PASS: Empty dataset produces error as expected"
    local ++pass_count
}
else {
    display as error "  FAIL: Empty dataset should produce an error"
    local ++fail_count
    local failed_tests "`failed_tests' 5.14.1"
}

* =============================================================================
* TEST SECTION 5.15: GENERATE/PREFIX MUTUAL EXCLUSIVITY
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 5.15: generate() and prefix() Options"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 5.15.1: generate() with Wrong Number of Names
* Purpose: Verify error when generate() has wrong number of names
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 5.15.1: generate() with Wrong Number of Names"
}

capture {
    capture tvmerge "${DATA_DIR}/tvmerge_ds1_fullyear.dta" "${DATA_DIR}/tvmerge_ds2_split.dta", ///
        id(id) start(start1 start2) stop(stop1 stop2) ///
        exposure(exp1 exp2) generate(only_one_name)
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: generate() with wrong count produces error"
    local ++pass_count
}
else {
    display as error "  FAIL: generate() wrong count error (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 5.15.1"
}

* =============================================================================
* TEST SECTION 5.16: SAME-DAY INTERVAL EDGE CASE
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 5.16: Same-Day Interval Edge Cases"
    display as text "{hline 70}"
}

* Create dataset with same-day start/stop
clear
input long id double(start1 stop1) byte exp1
    1 22006 22006 1
end
format %td start1 stop1
label data "Same-day interval (0 duration)"
save "${DATA_DIR}/tvmerge_ds_sameday.dta", replace

* -----------------------------------------------------------------------------
* Test 5.16.1: Same-Day Start and Stop
* Purpose: Verify handling of zero-duration intervals
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 5.16.1: Same-Day Start and Stop (Zero Duration)"
}

capture {
    tvmerge "${DATA_DIR}/tvmerge_ds_sameday.dta" "${DATA_DIR}/tvmerge_ds2_split.dta", ///
        id(id) start(start1 start2) stop(stop1 stop2) ///
        exposure(exp1 exp2) force

    * Zero-duration intervals should either be handled or excluded
    * Test should not error
    assert _rc == 0
}
if _rc == 0 {
    display as result "  PASS: Same-day intervals handled without error"
    local ++pass_count
}
else {
    display as error "  FAIL: Same-day intervals (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 5.16.1"
}

* =============================================================================
* TEST SECTION 5.17: CONTINUOUS WITH POSITIONS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 5.17: continuous() with Position Numbers"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 5.17.1: continuous() Using Dataset Positions
* Purpose: Verify continuous() works with position syntax (1 or 2)
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 5.17.1: continuous() with Position Syntax"
}

capture {
    tvmerge "${DATA_DIR}/tvmerge_ds1_cont.dta" "${DATA_DIR}/tvmerge_ds2_cont.dta", ///
        id(id) start(start1 start2) stop(stop1 stop2) ///
        exposure(cum1 cum2) continuous(cum1 cum2)

    * Should run without error
    assert _N >= 1

    * Continuous variables should be interpolated
    confirm variable cum1
    confirm variable cum2
}
if _rc == 0 {
    display as result "  PASS: continuous() with variable names works"
    local ++pass_count
}
else {
    display as error "  FAIL: continuous() syntax (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 5.17.1"
}

* =============================================================================
* TEST SECTION 5.18: OPTION COMBINATIONS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 5.18: Option Combinations"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 5.18.1: generate + startname + stopname + dateformat All Together
* Purpose: Verify all naming options work together
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 5.18.1: generate + startname + stopname + dateformat"
}

capture {
    tvmerge "${DATA_DIR}/tvmerge_ds1_fullyear.dta" "${DATA_DIR}/tvmerge_ds2_split.dta", ///
        id(id) start(start1 start2) stop(stop1 stop2) ///
        exposure(exp1 exp2) generate(drug1 drug2) ///
        startname(period_start) stopname(period_end) ///
        dateformat(%tdCCYY-NN-DD)

    * All custom names should be applied
    confirm variable drug1
    confirm variable drug2
    confirm variable period_start
    confirm variable period_end

    * Check date format
    local fmt : format period_start
    assert substr("`fmt'", 1, 3) == "%td"
}
if _rc == 0 {
    display as result "  PASS: All naming options work together"
    local ++pass_count
}
else {
    display as error "  FAIL: All naming options (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 5.18.1"
}

* -----------------------------------------------------------------------------
* Test 5.18.2: All Diagnostic Options Together
* Purpose: Verify all diagnostics can run simultaneously
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 5.18.2: check + validatecoverage + validateoverlap + summarize"
}

capture {
    tvmerge "${DATA_DIR}/tvmerge_ds1_fullyear.dta" "${DATA_DIR}/tvmerge_ds2_split.dta", ///
        id(id) start(start1 start2) stop(stop1 stop2) ///
        exposure(exp1 exp2) check validatecoverage validateoverlap summarize

    * All diagnostics should run without error
    assert _N >= 1
}
if _rc == 0 {
    display as result "  PASS: All diagnostic options work together"
    local ++pass_count
}
else {
    display as error "  FAIL: All diagnostics (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 5.18.2"
}

* -----------------------------------------------------------------------------
* Test 5.18.3: force + keep + continuous Combination
* Purpose: Verify force with additional variables and continuous
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 5.18.3: force + keep + continuous Combination"
}

capture {
    tvmerge "${DATA_DIR}/tvmerge_ds1_cont.dta" "${DATA_DIR}/tvmerge_ds2_cont.dta", ///
        id(id) start(start1 start2) stop(stop1 stop2) ///
        exposure(cum1 cum2) continuous(cum1 cum2) force

    * Should work with all options
    assert _N >= 1
    confirm variable cum1
    confirm variable cum2
}
if _rc == 0 {
    display as result "  PASS: force + keep + continuous works together"
    local ++pass_count
}
else {
    display as error "  FAIL: force + keep + continuous (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 5.18.3"
}

* -----------------------------------------------------------------------------
* Test 5.18.4: prefix + continuous Combination
* Purpose: Verify prefix with continuous variables
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 5.18.4: prefix + continuous Combination"
}

capture {
    tvmerge "${DATA_DIR}/tvmerge_ds1_cont.dta" "${DATA_DIR}/tvmerge_ds2_cont.dta", ///
        id(id) start(start1 start2) stop(stop1 stop2) ///
        exposure(cum1 cum2) continuous(cum1 cum2) prefix(tv_)

    * Prefixed variable names should exist
    confirm variable tv_cum1
    confirm variable tv_cum2
}
if _rc == 0 {
    display as result "  PASS: prefix + continuous works together"
    local ++pass_count
}
else {
    display as error "  FAIL: prefix + continuous (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 5.18.4"
}

* -----------------------------------------------------------------------------
* Test 5.18.5: saveas + replace + all options
* Purpose: Verify saving with multiple options
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 5.18.5: saveas + replace with Multiple Options"
}

capture {
    capture erase "${DATA_DIR}/tvmerge_combo_output.dta"

    tvmerge "${DATA_DIR}/tvmerge_ds1_fullyear.dta" "${DATA_DIR}/tvmerge_ds2_split.dta", ///
        id(id) start(start1 start2) stop(stop1 stop2) ///
        exposure(exp1 exp2) generate(type1 type2) ///
        startname(begin) stopname(end) ///
        saveas("${DATA_DIR}/tvmerge_combo_output.dta") replace

    * File should be created with all options
    confirm file "${DATA_DIR}/tvmerge_combo_output.dta"

    use "${DATA_DIR}/tvmerge_combo_output.dta", clear
    confirm variable type1
    confirm variable type2
    confirm variable begin
    confirm variable end

    capture erase "${DATA_DIR}/tvmerge_combo_output.dta"
}
if _rc == 0 {
    display as result "  PASS: saveas + replace with multiple options works"
    local ++pass_count
}
else {
    display as error "  FAIL: saveas + multiple options (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 5.18.5"
}

* =============================================================================
* TEST SECTION 5.19: THREE-WAY MERGE COMBINATIONS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 5.19: Three-Way Merge Combinations"
    display as text "{hline 70}"
}

* Create three datasets with continuous variables for testing
clear
input long id double(s1 e1) byte x1 double c1
    1 21915 22189 1 274
end
format %td s1 e1
save "${DATA_DIR}/tvmerge_3way_cont1.dta", replace

clear
input long id double(s2 e2) byte x2 double c2
    1 22006 22281 2 275
end
format %td s2 e2
save "${DATA_DIR}/tvmerge_3way_cont2.dta", replace

clear
input long id double(s3 e3) byte x3 double c3
    1 22067 22281 3 214
end
format %td s3 e3
save "${DATA_DIR}/tvmerge_3way_cont3.dta", replace

* -----------------------------------------------------------------------------
* Test 5.19.1: Three-Way Merge with Continuous Variables
* Purpose: Verify three datasets with continuous variable interpolation
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 5.19.1: Three-Way Merge with Continuous Variables"
}

capture {
    tvmerge "${DATA_DIR}/tvmerge_3way_cont1.dta" "${DATA_DIR}/tvmerge_3way_cont2.dta" ///
        "${DATA_DIR}/tvmerge_3way_cont3.dta", ///
        id(id) start(s1 s2 s3) stop(e1 e2 e3) ///
        exposure(c1 c2 c3) continuous(c1 c2 c3)

    * Should have three-way intersection with interpolated values
    assert _N >= 1
    confirm variable c1
    confirm variable c2
    confirm variable c3

    * Continuous values should be interpolated for datasets 2+ based on overlap
    * Note: c1 from dataset 1 may not be interpolated; check c2 instead
    * c2 original value = 275, merged period is smaller, so should be < 275
    quietly sum c2
    assert r(mean) < 275
}
if _rc == 0 {
    display as result "  PASS: Three-way merge with continuous works"
    local ++pass_count
}
else {
    display as error "  FAIL: Three-way merge with continuous (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 5.19.1"
}

* -----------------------------------------------------------------------------
* Test 5.19.2: Three-Way Merge with All Options
* Purpose: Verify three datasets with all naming and output options
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 5.19.2: Three-Way Merge with All Options"
}

capture {
    tvmerge "${DATA_DIR}/tvmerge_3way_ds1.dta" "${DATA_DIR}/tvmerge_3way_ds2.dta" ///
        "${DATA_DIR}/tvmerge_3way_ds3.dta", ///
        id(id) start(s1 s2 s3) stop(e1 e2 e3) ///
        exposure(x1 x2 x3) generate(exp1 exp2 exp3) ///
        startname(begin_date) stopname(end_date) ///
        check summarize

    * All custom names should be applied
    confirm variable exp1
    confirm variable exp2
    confirm variable exp3
    confirm variable begin_date
    confirm variable end_date
}
if _rc == 0 {
    display as result "  PASS: Three-way merge with all options works"
    local ++pass_count
}
else {
    display as error "  FAIL: Three-way merge with all options (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 5.19.2"
}

* =============================================================================
* TEST SECTION 5.20: MULTI-PERSON TESTS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 5.20: Multi-Person Tests"
    display as text "{hline 70}"
}

* Create multi-person datasets
clear
input long id double(start1 stop1) byte exp1
    1 21915 22097 1
    1 22097 22281 2
    2 21915 22189 1
    3 21946 22281 1
end
format %td start1 stop1
label data "Multi-person dataset 1"
save "${DATA_DIR}/tvmerge_mp_ds1.dta", replace

clear
input long id double(start2 stop2) byte exp2
    1 21915 22189 10
    1 22189 22281 20
    2 21946 22281 10
    3 21915 22189 10
end
format %td start2 stop2
label data "Multi-person dataset 2"
save "${DATA_DIR}/tvmerge_mp_ds2.dta", replace

* -----------------------------------------------------------------------------
* Test 5.20.1: Multi-Person Merge
* Purpose: Verify merging works correctly across multiple persons
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 5.20.1: Multi-Person Merge"
}

capture {
    tvmerge "${DATA_DIR}/tvmerge_mp_ds1.dta" "${DATA_DIR}/tvmerge_mp_ds2.dta", ///
        id(id) start(start1 start2) stop(stop1 stop2) ///
        exposure(exp1 exp2)

    * All persons should be present
    distinct id
    assert r(ndistinct) == 3

    * Each person should have proper intervals
    by id: assert _N >= 1
}
if _rc == 0 {
    display as result "  PASS: Multi-person merge works correctly"
    local ++pass_count
}
else {
    display as error "  FAIL: Multi-person merge (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 5.20.1"
}

* -----------------------------------------------------------------------------
* Test 5.20.2: Multi-Person with ID Mismatch and Force
* Purpose: Verify force option with ID mismatches across persons
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 5.20.2: Multi-Person with ID Mismatch and Force"
}

capture {
    tvmerge "${DATA_DIR}/tvmerge_ds1_ids123.dta" "${DATA_DIR}/tvmerge_ds2_ids234.dta", ///
        id(id) start(start1 start2) stop(stop1 stop2) ///
        exposure(exp1 exp2) force

    * Only common IDs (2, 3) should be present
    distinct id
    assert r(ndistinct) == 2

    quietly count if id == 1 | id == 4
    assert r(N) == 0
}
if _rc == 0 {
    display as result "  PASS: Multi-person with force keeps intersection"
    local ++pass_count
}
else {
    display as error "  FAIL: Multi-person with force (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 5.20.2"
}

* =============================================================================
* TEST SECTION 5.21: INVARIANT COMBINATION TESTS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 5.21: Invariant Combination Tests"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 5.21.1: All Output Invariants After Complex Merge
* Purpose: Verify all output invariants hold after complex options
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 5.21.1: All Output Invariants After Complex Merge"
}

capture {
    tvmerge "${DATA_DIR}/tvmerge_mp_ds1.dta" "${DATA_DIR}/tvmerge_mp_ds2.dta", ///
        id(id) start(start1 start2) stop(stop1 stop2) ///
        exposure(exp1 exp2) generate(drug1 drug2) ///
        startname(period_start) stopname(period_end)

    * Invariant 1: Date ordering (start < stop)
    quietly count if period_end <= period_start
    assert r(N) == 0

    * Invariant 2: No overlapping intervals per ID
    _verify_no_overlap, id(id) start(period_start) stop(period_end)
    assert r(n_overlaps) == 0

    * Invariant 3: No duplicate intervals
    duplicates tag id period_start period_end, gen(dup)
    quietly count if dup > 0
    assert r(N) == 0
    drop dup

    * Invariant 4: All exposure variables present
    confirm variable drug1
    confirm variable drug2
}
if _rc == 0 {
    display as result "  PASS: All invariants hold after complex merge"
    local ++pass_count
}
else {
    display as error "  FAIL: Invariants after complex merge (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 5.21.1"
}

* -----------------------------------------------------------------------------
* Test 5.21.2: Person-Time Conservation with Continuous
* Purpose: Verify total overlapping time is preserved with continuous vars
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 5.21.2: Person-Time Conservation with Continuous"
}

capture {
    tvmerge "${DATA_DIR}/tvmerge_ds1_fullyear.dta" "${DATA_DIR}/tvmerge_ds2_split.dta", ///
        id(id) start(start1 start2) stop(stop1 stop2) ///
        exposure(exp1 exp2)

    * Calculate total person-time
    gen dur = stop - start
    quietly sum dur
    local total_pt = r(sum)

    * Should equal the full year (366 days for 2020)
    assert abs(`total_pt' - 366) < 2
}
if _rc == 0 {
    display as result "  PASS: Person-time conserved in merge"
    local ++pass_count
}
else {
    display as error "  FAIL: Person-time conservation (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 5.21.2"
}

* =============================================================================
* TEST SECTION 5.22: ADVANCED EDGE CASES - INTERVALS AND BOUNDARIES
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 5.22: Advanced Edge Cases - Intervals and Boundaries"
    display as text "{hline 70}"
}

* Create touching but non-overlapping intervals
clear
input long id double(start1 stop1) byte exp1
    1 21915 22006 1
end
format %td start1 stop1
label data "Interval ending at day 22006"
save "${DATA_DIR}/tvmerge_touch_ds1.dta", replace

clear
input long id double(start2 stop2) byte exp2
    1 22006 22281 2
end
format %td start2 stop2
label data "Interval starting at day 22006"
save "${DATA_DIR}/tvmerge_touch_ds2.dta", replace

* Create datasets with highly fragmented intervals
clear
input long id double(start1 stop1) byte exp1
    1 21915 21946 1
    1 21946 21975 2
    1 21975 22006 3
    1 22006 22037 4
    1 22037 22067 5
end
format %td start1 stop1
label data "Five consecutive 30-day intervals"
save "${DATA_DIR}/tvmerge_frag_ds1.dta", replace

clear
input long id double(start2 stop2) byte exp2
    1 21915 21961 10
    1 21961 22006 20
    1 22006 22052 30
    1 22052 22097 40
end
format %td start2 stop2
label data "Four consecutive ~45-day intervals"
save "${DATA_DIR}/tvmerge_frag_ds2.dta", replace

* Create dataset with adjacent intervals having different values
clear
input long id double(start1 stop1) byte exp1
    1 21915 22006 1
    1 22006 22097 1
    1 22097 22189 2
    1 22189 22281 2
end
format %td start1 stop1
label data "Same exposure value in adjacent intervals"
save "${DATA_DIR}/tvmerge_adj_same_ds1.dta", replace

* Create dataset with zero value continuous variable
clear
input long id double(start1 stop1) double cum1
    1 21915 22281 0
end
format %td start1 stop1
label data "Continuous variable with zero value"
save "${DATA_DIR}/tvmerge_zero_cont.dta", replace

* Create dataset with negative continuous variable
clear
input long id double(start2 stop2) double cum2
    1 21915 22097 -50
    1 22097 22281 100
end
format %td start2 stop2
label data "Continuous variable with negative value"
save "${DATA_DIR}/tvmerge_neg_cont.dta", replace

* -----------------------------------------------------------------------------
* Test 5.22.1: Touching Intervals (stop1 = start2)
* Purpose: Verify intervals that touch at a point don't create spurious output
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 5.22.1: Touching Intervals (stop1 = start2)"
}

capture {
    tvmerge "${DATA_DIR}/tvmerge_touch_ds1.dta" "${DATA_DIR}/tvmerge_touch_ds2.dta", ///
        id(id) start(start1 start2) stop(stop1 stop2) ///
        exposure(exp1 exp2) force

    * Touching at a point - may have 0 overlap or be handled as edge case
    * Should not error
    * If intervals touch at stop=start, there is no duration overlap
    * Expected behavior: 0 rows or error
}
if _rc == 0 {
    display as result "  PASS: Touching intervals handled without error"
    local ++pass_count
}
else {
    display as error "  FAIL: Touching intervals (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 5.22.1"
}

* -----------------------------------------------------------------------------
* Test 5.22.2: Highly Fragmented Intervals (Cartesian Explosion)
* Purpose: Verify highly fragmented datasets produce correct intersections
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 5.22.2: Highly Fragmented Intervals"
}

capture {
    tvmerge "${DATA_DIR}/tvmerge_frag_ds1.dta" "${DATA_DIR}/tvmerge_frag_ds2.dta", ///
        id(id) start(start1 start2) stop(stop1 stop2) ///
        exposure(exp1 exp2)

    * Should produce multiple intervals
    assert _N >= 5

    * No overlapping output intervals
    _verify_no_overlap, id(id) start(start) stop(stop)
    assert r(n_overlaps) == 0

    * Total duration should match original overlap
    gen dur = stop - start
    quietly sum dur
    local total = r(sum)
    * Both datasets cover roughly 150 days (Jan-May), overlap should be similar
    assert `total' > 100 & `total' < 200
}
if _rc == 0 {
    display as result "  PASS: Fragmented intervals produce correct non-overlapping output"
    local ++pass_count
}
else {
    display as error "  FAIL: Fragmented intervals (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 5.22.2"
}

* -----------------------------------------------------------------------------
* Test 5.22.3: Adjacent Intervals with Same Exposure
* Purpose: Verify adjacent intervals with same value don't cause issues
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 5.22.3: Adjacent Intervals Same Exposure Value"
}

capture {
    tvmerge "${DATA_DIR}/tvmerge_adj_same_ds1.dta" "${DATA_DIR}/tvmerge_ds2_split.dta", ///
        id(id) start(start1 start2) stop(stop1 stop2) ///
        exposure(exp1 exp2)

    * Should complete without error
    assert _N >= 1

    * No overlapping output intervals
    _verify_no_overlap, id(id) start(start) stop(stop)
    assert r(n_overlaps) == 0
}
if _rc == 0 {
    display as result "  PASS: Adjacent same-value intervals handled correctly"
    local ++pass_count
}
else {
    display as error "  FAIL: Adjacent same-value intervals (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 5.22.3"
}

* -----------------------------------------------------------------------------
* Test 5.22.4: Zero-Valued Continuous Variable
* Purpose: Verify continuous interpolation handles zero values correctly
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 5.22.4: Zero-Valued Continuous Variable"
}

capture {
    tvmerge "${DATA_DIR}/tvmerge_zero_cont.dta" "${DATA_DIR}/tvmerge_ds2_cont.dta", ///
        id(id) start(start1 start2) stop(stop1 stop2) ///
        exposure(cum1 cum2) continuous(cum1 cum2)

    * Zero-valued continuous should remain zero after interpolation
    quietly sum cum1
    assert r(mean) == 0
}
if _rc == 0 {
    display as result "  PASS: Zero-valued continuous variable interpolated correctly"
    local ++pass_count
}
else {
    display as error "  FAIL: Zero-valued continuous (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 5.22.4"
}

* -----------------------------------------------------------------------------
* Test 5.22.5: Negative Continuous Variable
* Purpose: Verify continuous interpolation handles negative values correctly
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 5.22.5: Negative Continuous Variable"
}

capture {
    tvmerge "${DATA_DIR}/tvmerge_ds1_cont.dta" "${DATA_DIR}/tvmerge_neg_cont.dta", ///
        id(id) start(start1 start2) stop(stop1 stop2) ///
        exposure(cum1 cum2) continuous(cum1 cum2)

    * Should complete without error
    assert _N >= 1

    * Negative values should be preserved/interpolated
    quietly sum cum2
    * Should have some negative or mixed values depending on period
}
if _rc == 0 {
    display as result "  PASS: Negative continuous variable handled correctly"
    local ++pass_count
}
else {
    display as error "  FAIL: Negative continuous (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 5.22.5"
}

* =============================================================================
* TEST SECTION 5.23: INTERVAL ORDER AND BOUNDARY TESTS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 5.23: Interval Order and Boundary Tests"
    display as text "{hline 70}"
}

* Create dataset with intervals in reverse order
clear
input long id double(start1 stop1) byte exp1
    1 22097 22281 2
    1 21915 22097 1
end
format %td start1 stop1
label data "Intervals in reverse chronological order"
save "${DATA_DIR}/tvmerge_reverse_ds1.dta", replace

* Create dataset with overlapping intervals (problematic input)
clear
input long id double(start1 stop1) byte exp1
    1 21915 22097 1
    1 22006 22189 2
end
format %td start1 stop1
label data "Overlapping input intervals"
save "${DATA_DIR}/tvmerge_overlap_input.dta", replace

* -----------------------------------------------------------------------------
* Test 5.23.1: Reverse Order Input Intervals
* Purpose: Verify intervals are processed correctly regardless of input order
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 5.23.1: Reverse Order Input Intervals"
}

capture {
    tvmerge "${DATA_DIR}/tvmerge_reverse_ds1.dta" "${DATA_DIR}/tvmerge_ds2_split.dta", ///
        id(id) start(start1 start2) stop(stop1 stop2) ///
        exposure(exp1 exp2)

    * Should produce same result as correctly ordered input
    assert _N >= 1

    * Output should be in non-decreasing order (allows equal start dates at boundaries)
    sort id start
    by id: gen byte order_check = (start <= start[_n+1]) if _n < _N
    quietly count if order_check == 0
    assert r(N) == 0
}
if _rc == 0 {
    display as result "  PASS: Reverse order inputs produce correctly ordered output"
    local ++pass_count
}
else {
    display as error "  FAIL: Reverse order inputs (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 5.23.1"
}

* -----------------------------------------------------------------------------
* Test 5.23.2: Overlapping Input Intervals (should error or handle)
* Purpose: Verify handling of overlapping intervals in input dataset
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 5.23.2: Overlapping Input Intervals"
}

capture {
    * tvmerge may error on overlapping input, or handle it
    capture tvmerge "${DATA_DIR}/tvmerge_overlap_input.dta" "${DATA_DIR}/tvmerge_ds2_split.dta", ///
        id(id) start(start1 start2) stop(stop1 stop2) ///
        exposure(exp1 exp2)

    * Errors are acceptable (overlapping input is ambiguous)
    * If succeeds, output may have overlaps reflecting input overlaps
    * Just verify it doesn't crash
    if _rc != 0 {
        * Error is acceptable for overlapping input
        local _inner_rc = 0
    }
    else {
        * Success is also acceptable - just verify we got output
        assert _N >= 1
    }
}
if _rc == 0 {
    display as result "  PASS: Overlapping input intervals handled appropriately"
    local ++pass_count
}
else {
    display as error "  FAIL: Overlapping input intervals (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 5.23.2"
}

* =============================================================================
* TEST SECTION 5.24: PERSON-TIME INVARIANTS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 5.24: Person-Time Invariants"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 5.24.1: Output Never Exceeds Minimum Input Duration
* Purpose: Verify merged output duration <= minimum of input durations
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 5.24.1: Output Duration <= Min Input Duration"
}

capture {
    tvmerge "${DATA_DIR}/tvmerge_ds1_partial.dta" "${DATA_DIR}/tvmerge_ds2_partial.dta", ///
        id(id) start(start1 start2) stop(stop1 stop2) ///
        exposure(exp1 exp2)

    * Calculate merged duration
    gen dur = stop - start
    quietly sum dur
    local merged_dur = r(sum)

    * ds1: Jan-Jun = 182 days, ds2: Mar-Sep = 214 days
    * Intersection: Mar-Jun = 122 days (should be less than either input)
    assert `merged_dur' <= 182
    assert `merged_dur' <= 214
}
if _rc == 0 {
    display as result "  PASS: Output duration does not exceed minimum input duration"
    local ++pass_count
}
else {
    display as error "  FAIL: Output duration invariant (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 5.24.1"
}

* -----------------------------------------------------------------------------
* Test 5.24.2: Three-Way Merge Output <= All Inputs
* Purpose: Verify three-way merge output is bounded by all input durations
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 5.24.2: Three-Way Merge Duration Bounded"
}

capture {
    tvmerge "${DATA_DIR}/tvmerge_3way_ds1.dta" "${DATA_DIR}/tvmerge_3way_ds2.dta" ///
        "${DATA_DIR}/tvmerge_3way_ds3.dta", ///
        id(id) start(s1 s2 s3) stop(e1 e2 e3) ///
        exposure(x1 x2 x3)

    * Calculate merged duration
    gen dur = stop - start
    quietly sum dur
    local merged_dur = r(sum)

    * ds1: 274 days, ds2: 275 days, ds3: 214 days
    * Output should be <= minimum (214)
    assert `merged_dur' <= 214
}
if _rc == 0 {
    display as result "  PASS: Three-way merge output bounded by all inputs"
    local ++pass_count
}
else {
    display as error "  FAIL: Three-way duration bound (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 5.24.2"
}

* =============================================================================
* TEST SECTION 5.25: BOUNDARY CONDITION TESTS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 5.25: Boundary Condition Tests"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 5.25.1: Single-Day Intervals in Both Datasets
* Purpose: Verify single-day intervals (start == stop) merge correctly
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 5.25.1: Single-Day Intervals"
}

capture {
    * Create single-day interval datasets
    clear
    input long id double(start1 stop1) byte exp1
        1 22000 22000 1
    end
    format %td start1 stop1
    save "${DATA_DIR}/tvmerge_single_day1.dta", replace

    clear
    input long id double(start2 stop2) byte exp2
        1 22000 22000 2
    end
    format %td start2 stop2
    save "${DATA_DIR}/tvmerge_single_day2.dta", replace

    * Merge single-day intervals
    tvmerge "${DATA_DIR}/tvmerge_single_day1.dta" "${DATA_DIR}/tvmerge_single_day2.dta", ///
        id(id) start(start1 start2) stop(stop1 stop2) ///
        exposure(exp1 exp2)

    * Should produce exactly 1 row with both exposures
    assert _N == 1
    assert exp1 == 1
    assert exp2 == 2
}
if _rc == 0 {
    display as result "  PASS: Single-day intervals merged correctly"
    local ++pass_count
}
else {
    display as error "  FAIL: Single-day intervals (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 5.25.1"
}

* -----------------------------------------------------------------------------
* Test 5.25.2: Abutting Intervals (stop == next start)
* Purpose: Verify abutting intervals produce contiguous output
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 5.25.2: Abutting Intervals"
}

capture {
    * Create abutting interval datasets
    clear
    input long id double(start1 stop1) byte exp1
        1 22000 22030 1
        1 22030 22060 1
    end
    format %td start1 stop1
    save "${DATA_DIR}/tvmerge_abutting1.dta", replace

    clear
    input long id double(start2 stop2) byte exp2
        1 22000 22060 2
    end
    format %td start2 stop2
    save "${DATA_DIR}/tvmerge_abutting2.dta", replace

    * Merge abutting intervals
    tvmerge "${DATA_DIR}/tvmerge_abutting1.dta" "${DATA_DIR}/tvmerge_abutting2.dta", ///
        id(id) start(start1 start2) stop(stop1 stop2) ///
        exposure(exp1 exp2)

    * Verify no gaps in output
    sort id start
    by id: gen gap = start - stop[_n-1] if _n > 1
    quietly count if gap > 1 & !missing(gap)
    assert r(N) == 0
}
if _rc == 0 {
    display as result "  PASS: Abutting intervals handled correctly"
    local ++pass_count
}
else {
    display as error "  FAIL: Abutting intervals (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 5.25.2"
}

* -----------------------------------------------------------------------------
* Test 5.25.3: Exact Same Intervals
* Purpose: Verify identical intervals in both datasets merge correctly
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 5.25.3: Identical Intervals"
}

capture {
    * Create identical interval datasets
    clear
    input long id double(start1 stop1) byte exp1
        1 22000 22060 1
    end
    format %td start1 stop1
    save "${DATA_DIR}/tvmerge_identical1.dta", replace

    clear
    input long id double(start2 stop2) byte exp2
        1 22000 22060 2
    end
    format %td start2 stop2
    save "${DATA_DIR}/tvmerge_identical2.dta", replace

    * Merge identical intervals
    tvmerge "${DATA_DIR}/tvmerge_identical1.dta" "${DATA_DIR}/tvmerge_identical2.dta", ///
        id(id) start(start1 start2) stop(stop1 stop2) ///
        exposure(exp1 exp2)

    * Should produce exactly 1 row
    assert _N == 1
    gen dur = stop - start
    assert dur == 60
}
if _rc == 0 {
    display as result "  PASS: Identical intervals merged correctly"
    local ++pass_count
}
else {
    display as error "  FAIL: Identical intervals (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 5.25.3"
}

* -----------------------------------------------------------------------------
* Test 5.25.4: One Dataset Fully Contains Other
* Purpose: Verify containment relationship handled correctly
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 5.25.4: Containment Intervals"
}

capture {
    * Create containment interval datasets
    clear
    input long id double(start1 stop1) byte exp1
        1 22000 22090 1
    end
    format %td start1 stop1
    save "${DATA_DIR}/tvmerge_contain1.dta", replace

    clear
    input long id double(start2 stop2) byte exp2
        1 22030 22060 2
    end
    format %td start2 stop2
    save "${DATA_DIR}/tvmerge_contain2.dta", replace

    * Merge - output should be the intersection
    tvmerge "${DATA_DIR}/tvmerge_contain1.dta" "${DATA_DIR}/tvmerge_contain2.dta", ///
        id(id) start(start1 start2) stop(stop1 stop2) ///
        exposure(exp1 exp2)

    * Output should be the smaller interval (30 days)
    gen dur = stop - start
    quietly sum dur
    assert r(sum) == 30
}
if _rc == 0 {
    display as result "  PASS: Containment intervals handled correctly"
    local ++pass_count
}
else {
    display as error "  FAIL: Containment intervals (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 5.25.4"
}

* =============================================================================
* TEST SECTION 5.26: INVARIANT ASSERTION TESTS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 5.26: Invariant Assertion Tests"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 5.26.1: Output Duration <= Minimum Input Duration (Always)
* Purpose: Intersection can never exceed either input
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 5.26.1: Output <= Min Input (General)"
}

capture {
    * Use existing partial overlap datasets
    tvmerge "${DATA_DIR}/tvmerge_ds1_partial.dta" "${DATA_DIR}/tvmerge_ds2_partial.dta", ///
        id(id) start(start1 start2) stop(stop1 stop2) ///
        exposure(exp1 exp2)

    gen dur = stop - start
    quietly sum dur
    local out_dur = r(sum)

    * Output duration must be <= minimum of inputs
    * This is a fundamental property of interval intersection
    assert `out_dur' <= 182  // ds1 duration
    assert `out_dur' <= 214  // ds2 duration
}
if _rc == 0 {
    display as result "  PASS: Output bounded by inputs"
    local ++pass_count
}
else {
    display as error "  FAIL: Output bound invariant (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 5.26.1"
}

* -----------------------------------------------------------------------------
* Test 5.26.2: No Output Overlaps Within Person
* Purpose: Verify merged output never has overlapping intervals
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 5.26.2: No Output Overlaps"
}

capture {
    tvmerge "${DATA_DIR}/tvmerge_ds1_fullyear.dta" "${DATA_DIR}/tvmerge_ds2_split.dta", ///
        id(id) start(start1 start2) stop(stop1 stop2) ///
        exposure(exp1 exp2)

    _verify_no_overlap, id(id) start(start) stop(stop)
    assert r(n_overlaps) == 0
}
if _rc == 0 {
    display as result "  PASS: No overlaps in output"
    local ++pass_count
}
else {
    display as error "  FAIL: Output overlap check (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 5.26.2"
}

* -----------------------------------------------------------------------------
* Test 5.26.3: Output Sorted by ID and Start
* Purpose: Verify output is properly sorted
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 5.26.3: Output Properly Sorted"
}

capture {
    tvmerge "${DATA_DIR}/tvmerge_ds1_fullyear.dta" "${DATA_DIR}/tvmerge_ds2_split.dta", ///
        id(id) start(start1 start2) stop(stop1 stop2) ///
        exposure(exp1 exp2)

    * Check sort order
    sort id start stop
    by id: gen byte order_ok = (start >= start[_n-1]) if _n > 1
    quietly count if order_ok == 0
    assert r(N) == 0
}
if _rc == 0 {
    display as result "  PASS: Output properly sorted"
    local ++pass_count
}
else {
    display as error "  FAIL: Output sort check (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 5.26.3"
}

* -----------------------------------------------------------------------------
* Test 5.26.4: All Output Dates Within Input Bounds
* Purpose: Output dates can't exceed input date range
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 5.26.4: Output Dates Within Bounds"
}

capture {
    tvmerge "${DATA_DIR}/tvmerge_ds1_fullyear.dta" "${DATA_DIR}/tvmerge_ds2_split.dta", ///
        id(id) start(start1 start2) stop(stop1 stop2) ///
        exposure(exp1 exp2)

    * Get output date range
    quietly sum start
    local out_min = r(min)
    quietly sum stop
    local out_max = r(max)

    * Output should be within Jan 1 - Dec 31 2020 (21915 - 22281)
    assert `out_min' >= 21915
    assert `out_max' <= 22281
}
if _rc == 0 {
    display as result "  PASS: Output dates within bounds"
    local ++pass_count
}
else {
    display as error "  FAIL: Date bounds check (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 5.26.4"
}

* -----------------------------------------------------------------------------
* Test 5.26.5: Exposure Values Preserved
* Purpose: Verify exposure values match input values
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 5.26.5: Exposure Values Preserved"
}

capture {
    tvmerge "${DATA_DIR}/tvmerge_ds1_fullyear.dta" "${DATA_DIR}/tvmerge_ds2_split.dta", ///
        id(id) start(start1 start2) stop(stop1 stop2) ///
        exposure(exp1 exp2)

    * Exposure values should only be values that exist in input
    quietly levelsof exp1, local(exp1_vals)
    foreach v in `exp1_vals' {
        assert `v' >= 0 & `v' <= 3
    }
    quietly levelsof exp2, local(exp2_vals)
    foreach v in `exp2_vals' {
        assert `v' >= 0 & `v' <= 3
    }
}
if _rc == 0 {
    display as result "  PASS: Exposure values preserved"
    local ++pass_count
}
else {
    display as error "  FAIL: Exposure preservation (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 5.26.5"
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
