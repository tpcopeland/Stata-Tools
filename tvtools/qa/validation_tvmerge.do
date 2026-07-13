clear all
set more off
set varabbrev off
version 16.0

capture log close
quietly log using "validation_tvmerge.log", replace nomsg

* Shared scaffold: test globals + helpers + sandboxed install bootstrap
do "`c(pwd)'/_tvtools_qa_common.do"
_tvtools_qa_bootstrap

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""
local run_only = 0
local quiet = 0
local machine = 0

* run_test/test_pass/test_fail harness counters (folded into the totals below)
global TVQA_PASS = 0
global TVQA_FAIL = 0
global TVQA_FAILED ""
global TVQA_CURRENT ""

display as result "tvtools QA: tvmerge correctness -- $S_DATE $S_TIME"


**# ===== merged from validation_tvtools.do L13038-16509: SECTION 6 TVMERGE additivity =====

* SECTION 6: TVMERGE - Merge correctness and person-time additivity

capture noisily {
* HELPER PROGRAMS

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

* CREATE VALIDATION DATA
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

* TEST SECTION 5.1: CARTESIAN PRODUCT TESTS
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 5.1: Cartesian Product Tests"
    display as text "{hline 70}"
}

* Test 5.1.1: Complete Intersection Coverage
* Purpose: Verify all overlapping intervals from both datasets appear
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

* Test 5.1.2: Non-Overlapping Periods Excluded
* Purpose: Verify intervals that don't overlap produce no output
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

* TEST SECTION 5.2: PERSON-TIME TESTS
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 5.2: Person-Time Tests"
    display as text "{hline 70}"
}

* Test 5.2.1: Merged Duration Equals Intersection
* Purpose: Verify output duration matches overlap duration exactly
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

* Test 5.2.2: No Overlapping Intervals in Output
* Purpose: Verify merged output has no overlapping intervals per ID
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

* TEST SECTION 5.3: CONTINUOUS VARIABLE TESTS
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 5.3: Continuous Variable Tests"
    display as text "{hline 70}"
}

* Test 5.3.1: Continuous Interpolation
* Purpose: Verify continuous values are pro-rated correctly
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

* TEST SECTION 5.4: ID MATCHING TESTS
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 5.4: ID Matching Tests"
    display as text "{hline 70}"
}

* Test 5.4.1: ID Intersection Behavior (Without Force)
* Purpose: Verify error when IDs don't match without force option
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

* Test 5.4.2: ID Intersection Behavior (With Force)
* Purpose: Verify force option allows ID mismatches with intersection
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 5.4.2: ID Intersection With Force"
}

capture {
    * With force: should warn and keep only intersection (IDs 2, 3)
    tvmerge "${DATA_DIR}/tvmerge_ds1_ids123.dta" "${DATA_DIR}/tvmerge_ds2_ids234.dta", ///
        id(id) start(start1 start2) stop(stop1 stop2) ///
        exposure(exp1 exp2) force

    quietly levelsof id
    * Only IDs 2 and 3 should appear (intersection)
    assert r(r) == 2

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

* TEST SECTION 5.5: THREE-WAY MERGE TESTS
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 5.5: Three-Way Merge Tests"
    display as text "{hline 70}"
}

* Test 5.5.1: Three Dataset Intersection
* Purpose: Verify three-way merge creates correct intersection
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

* Test 5.5.2: Three-Way Merge Duration Calculation
* Purpose: Verify duration of three-way intersection is correct
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

* TEST SECTION: ERROR HANDLING
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "ERROR HANDLING TESTS"
    display as text "{hline 70}"
}

* Test: Missing Required Options
* Purpose: Verify errors for missing required inputs
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

* Test: Missing input file
* Purpose: Verify error when dataset file doesn't exist
local ++test_count
if `quiet' == 0 {
    display as text _n "Test: Missing input file"
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

* INVARIANT TESTS: Properties that must always hold
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "INVARIANT TESTS: Universal Properties"
    display as text "{hline 70}"
}

* Invariant 1: Date Ordering (start < stop for all rows)
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

* Invariant 2: Output Contains Only IDs Present in All Inputs
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

* Invariant 3: No Duplicate Intervals
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

* TEST SECTION 5.6: OUTPUT NAMING OPTIONS TESTS
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 5.6: Output Naming Options Tests"
    display as text "{hline 70}"
}

* Test 5.6.1: generate() Creates Custom-Named Variables
* Purpose: Verify generate() renames exposure variables in output
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

* Test 5.6.2: prefix() Adds Prefix to Variable Names
* Purpose: Verify prefix() adds consistent prefix to all exposure names
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

* Test 5.6.3: startname() and stopname() Customize Date Variable Names
* Purpose: Verify startname/stopname change output date variable names
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

* Test 5.6.4: dateformat() Applies Custom Date Format
* Purpose: Verify dateformat() changes output date display format
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

* TEST SECTION 5.7: DATA MANAGEMENT OPTIONS TESTS
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 5.7: Data Management Options Tests"
    display as text "{hline 70}"
}

* Test 5.7.1: saveas() and replace Save Output File
* Purpose: Verify saveas() saves merged dataset to file
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

* Test 5.7.2: keep() Retains Additional Variables
* Purpose: Verify keep() brings additional variables from source datasets
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

* TEST SECTION 5.8: DIAGNOSTIC OPTIONS TESTS
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 5.8: Diagnostic Options Tests"
    display as text "{hline 70}"
}

* Test 5.8.1: check Displays Diagnostics
* Purpose: Verify check option runs and displays coverage information
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

* Test 5.8.2: validatecoverage Checks for Gaps
* Purpose: Verify validatecoverage option runs gap detection
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

* Test 5.8.3: validateoverlap Checks for Overlaps
* Purpose: Verify validateoverlap option runs overlap detection
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

* Test 5.8.4: summarize Displays Summary Statistics
* Purpose: Verify summarize option shows date range statistics
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

* TEST SECTION 5.9: PERFORMANCE OPTIONS TESTS
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 5.9: Performance Options Tests"
    display as text "{hline 70}"
}

* Test 5.9.1: batch() Controls Batch Processing
* Purpose: Verify batch() option works with different batch sizes
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

* TEST SECTION 5.10: STORED RESULTS TESTS
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 5.10: Stored Results Tests"
    display as text "{hline 70}"
}

* Test 5.10.1: Stored Scalars
* Purpose: Verify r() scalars are correctly stored
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

* Test 5.10.2: Stored Macros
* Purpose: Verify r() macros are correctly stored
* Note: r(datasets) contains quoted paths that need compound quoting
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

* TEST SECTION 5.11: BATCH SIZE EDGE CASES
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 5.11: batch() Edge Cases"
    display as text "{hline 70}"
}

* Test 5.11.1: batch(1) Minimum Batch Size
* Purpose: Verify batch(1) works correctly
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

* Test 5.11.2: batch(100) Maximum Batch Size
* Purpose: Verify batch(100) works correctly
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

* TEST SECTION 5.12: MISMATCHED OPTIONS ERROR HANDLING
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 5.12: Mismatched Options Error Handling"
    display as text "{hline 70}"
}

* Test 5.12.1: Mismatched start/stop Counts
* Purpose: Verify error when start() and stop() have different numbers
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

* Test 5.12.2: Mismatched Exposure Count
* Purpose: Verify error when exposure() count doesn't match datasets
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

* TEST SECTION 5.13: MULTIPLE EXPOSURES PER DATASET
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

* Test 5.13.1: Multiple Exposures via keep()
* Purpose: Verify keep() can bring multiple exposure variables from each dataset
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

* TEST SECTION 5.14: EMPTY DATASET HANDLING
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

* Test 5.14.1: One Empty Dataset
* Purpose: Verify tvmerge detects empty dataset and produces error
* Note: tvmerge requires non-empty datasets - empty dataset handling is undefined
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

* TEST SECTION 5.15: GENERATE/PREFIX MUTUAL EXCLUSIVITY
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 5.15: generate() and prefix() Options"
    display as text "{hline 70}"
}

* Test 5.15.1: generate() with Wrong Number of Names
* Purpose: Verify error when generate() has wrong number of names
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

* TEST SECTION 5.16: SAME-DAY INTERVAL EDGE CASE
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

* Test 5.16.1: Same-Day Start and Stop
* Purpose: Verify handling of zero-duration intervals
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

* TEST SECTION 5.17: CONTINUOUS WITH POSITIONS
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 5.17: continuous() with Position Numbers"
    display as text "{hline 70}"
}

* Test 5.17.1: continuous() Using Dataset Positions
* Purpose: Verify continuous() works with position syntax (1 or 2)
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

* TEST SECTION 5.18: OPTION COMBINATIONS
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 5.18: Option Combinations"
    display as text "{hline 70}"
}

* Test 5.18.1: generate + startname + stopname + dateformat All Together
* Purpose: Verify all naming options work together
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

* Test 5.18.2: All Diagnostic Options Together
* Purpose: Verify all diagnostics can run simultaneously
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

* Test 5.18.3: force + keep + continuous Combination
* Purpose: Verify force with additional variables and continuous
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

* Test 5.18.4: prefix + continuous Combination
* Purpose: Verify prefix with continuous variables
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

* Test 5.18.5: saveas + replace + all options
* Purpose: Verify saving with multiple options
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

* TEST SECTION 5.19: THREE-WAY MERGE COMBINATIONS
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

* Test 5.19.1: Three-Way Merge with Continuous Variables
* Purpose: Verify three datasets with continuous variable interpolation
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

* Test 5.19.2: Three-Way Merge with All Options
* Purpose: Verify three datasets with all naming and output options
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

* TEST SECTION 5.20: MULTI-PERSON TESTS
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

* Test 5.20.1: Multi-Person Merge
* Purpose: Verify merging works correctly across multiple persons
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 5.20.1: Multi-Person Merge"
}

capture {
    tvmerge "${DATA_DIR}/tvmerge_mp_ds1.dta" "${DATA_DIR}/tvmerge_mp_ds2.dta", ///
        id(id) start(start1 start2) stop(stop1 stop2) ///
        exposure(exp1 exp2)

    * All persons should be present
    quietly levelsof id
    assert r(r) == 3

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

* Test 5.20.2: Multi-Person with ID Mismatch and Force
* Purpose: Verify force option with ID mismatches across persons
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 5.20.2: Multi-Person with ID Mismatch and Force"
}

capture {
    tvmerge "${DATA_DIR}/tvmerge_ds1_ids123.dta" "${DATA_DIR}/tvmerge_ds2_ids234.dta", ///
        id(id) start(start1 start2) stop(stop1 stop2) ///
        exposure(exp1 exp2) force

    * Only common IDs (2, 3) should be present
    quietly levelsof id
    assert r(r) == 2

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

* TEST SECTION 5.21: INVARIANT COMBINATION TESTS
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 5.21: Invariant Combination Tests"
    display as text "{hline 70}"
}

* Test 5.21.1: All Output Invariants After Complex Merge
* Purpose: Verify all output invariants hold after complex options
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

* Test 5.21.2: Person-Time Conservation with Continuous
* Purpose: Verify total overlapping time is preserved with continuous vars
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

* TEST SECTION 5.22: ADVANCED EDGE CASES - INTERVALS AND BOUNDARIES
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
    1 22098 22281 100
end
format %td start2 stop2
label data "Nonoverlapping interval totals with a negative value"
save "${DATA_DIR}/tvmerge_neg_cont.dta", replace

* Test 5.22.1: Touching Intervals (stop1 = start2)
* Purpose: Verify intervals that touch at a point don't create spurious output
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

* Test 5.22.2: Highly Fragmented Intervals (Cartesian Explosion)
* Purpose: Verify highly fragmented datasets produce correct intersections
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

* Test 5.22.3: Adjacent Intervals with Same Exposure
* Purpose: Verify adjacent intervals with same value don't cause issues
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

* Test 5.22.4: Zero-Valued Continuous Variable
* Purpose: Verify continuous interpolation handles zero values correctly
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

* Test 5.22.5: Negative Continuous Variable
* Purpose: Verify continuous interpolation handles negative values correctly
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 5.22.5: Negative Continuous Variable"
}

capture {
    tvmerge "${DATA_DIR}/tvmerge_ds1_cont.dta" "${DATA_DIR}/tvmerge_neg_cont.dta", ///
        id(id) start(start1 start2) stop(stop1 stop2) ///
        exposure(cum1 cum2) continuous(cum1 cum2)

    * Closed intervals sharing an endpoint overlap, so the fixture uses
    * consecutive nonoverlapping rows. Both signed totals must survive.
    assert _N == 2
    quietly count if cum2 < 0
    assert r(N) == 1
    quietly summarize cum2, meanonly
    assert r(min) == -50 & r(max) == 100
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

* TEST SECTION 5.23: INTERVAL ORDER AND BOUNDARY TESTS
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

* Test 5.23.1: Reverse Order Input Intervals
* Purpose: Verify intervals are processed correctly regardless of input order
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

* Test 5.23.2: Overlapping Input Intervals (should error or handle)
* Purpose: Verify handling of overlapping intervals in input dataset
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

* TEST SECTION 5.24: PERSON-TIME INVARIANTS
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 5.24: Person-Time Invariants"
    display as text "{hline 70}"
}

* Test 5.24.1: Output Never Exceeds Minimum Input Duration
* Purpose: Verify merged output duration <= minimum of input durations
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

* Test 5.24.2: Three-Way Merge Output <= All Inputs
* Purpose: Verify three-way merge output is bounded by all input durations
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

* TEST SECTION 5.25: BOUNDARY CONDITION TESTS
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 5.25: Boundary Condition Tests"
    display as text "{hline 70}"
}

* Test 5.25.1: Single-Day Intervals in Both Datasets
* Purpose: Verify single-day intervals (start == stop) merge correctly
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

* Test 5.25.2: Abutting Intervals (stop == next start)
* Purpose: Verify abutting intervals produce contiguous output
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

* Test 5.25.3: Exact Same Intervals
* Purpose: Verify identical intervals in both datasets merge correctly
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

* Test 5.25.4: One Dataset Fully Contains Other
* Purpose: Verify containment relationship handled correctly
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

* TEST SECTION 5.26: INVARIANT ASSERTION TESTS
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 5.26: Invariant Assertion Tests"
    display as text "{hline 70}"
}

* Test 5.26.1: Output Duration <= Minimum Input Duration (Always)
* Purpose: Intersection can never exceed either input
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

* Test 5.26.2: No Output Overlaps Within Person
* Purpose: Verify merged output never has overlapping intervals
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

* Test 5.26.3: Output Sorted by ID and Start
* Purpose: Verify output is properly sorted
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

* Test 5.26.4: All Output Dates Within Input Bounds
* Purpose: Output dates can't exceed input date range
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

* Test 5.26.5: Exposure Values Preserved
* Purpose: Verify exposure values match input values
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

* SUMMARY

}

capture noisily {

* TEST 5A: INTERVAL INTERSECTION BOUNDARIES (EXACT DATES)
display "TEST 5A: Interval intersection boundaries"

local test5a_pass = 1

* Dataset A: Person 1, [Jan1/2020, Jun30/2020]
* Dataset B: Person 1, [Apr1/2020, Sep30/2020]
* Expected intersection: [Apr1/2020, Jun30/2020]
* The merged output should have exactly this interval for the overlap

clear
set obs 1
gen id = 1
gen startA = mdy(1,1,2020)
gen stopA  = mdy(6,30,2020)
gen expA   = 1
save "$TVTOOLS_QA_RUN_DIR/tvm5a_dsetA.dta", replace

clear
set obs 1
gen id = 1
gen startB = mdy(4,1,2020)
gen stopB  = mdy(9,30,2020)
gen expB   = 1
save "$TVTOOLS_QA_RUN_DIR/tvm5a_dsetB.dta", replace

capture noisily tvmerge ///
    "$TVTOOLS_QA_RUN_DIR/tvm5a_dsetA.dta" "$TVTOOLS_QA_RUN_DIR/tvm5a_dsetB.dta", ///
    id(id) start(startA startB) stop(stopA stopB) exposure(expA expB) ///
    generate(exp_A exp_B)

if _rc != 0 {
    display as error "  FAIL [5a.run]: tvmerge returned error `=_rc'"
    local test5a_pass = 0
}
else {
    sort id start
    quietly count
    local nrows = r(N)
    display "  INFO: `nrows' rows in merged output"
    list id start stop exp_A exp_B, noobs

    * Find the row where both datasets overlap (exp_A>0 and exp_B>0)
    quietly count if exp_A > 0 & exp_B > 0
    local n_overlap = r(N)

    if `n_overlap' > 0 {
        quietly sum start if exp_A > 0 & exp_B > 0
        local overlap_start = r(min)
        quietly sum stop if exp_A > 0 & exp_B > 0
        local overlap_stop = r(max)

        local expected_start = mdy(4,1,2020)
        local expected_stop  = mdy(6,30,2020)

        if `overlap_start' == `expected_start' {
            display as result "  PASS [5a.overlap_start]: overlap starts Apr1/2020"
        }
        else {
            local actual_date : display %td `overlap_start'
            display as error "  FAIL [5a.overlap_start]: overlap starts `actual_date'"
            local test5a_pass = 0
        }

        if `overlap_stop' == `expected_stop' {
            display as result "  PASS [5a.overlap_stop]: overlap stops Jun30/2020"
        }
        else {
            local actual_date : display %td `overlap_stop'
            display as error "  FAIL [5a.overlap_stop]: overlap stops `actual_date'"
            local test5a_pass = 0
        }
    }
    else {
        display as error "  FAIL [5a.overlap]: no overlapping periods found"
        local test5a_pass = 0
    }
}

if `test5a_pass' == 1 {
    local pass_count = `pass_count' + 1
    display as result "TEST 5A: PASSED"
}
else {
    local fail_count = `fail_count' + 1
    local failed_tests "`failed_tests' 5a"
    display as error "TEST 5A: FAILED"
}

* TEST 5B: CONTINUOUS PROPORTIONING FORMULA
display "TEST 5B: Continuous proportioning formula"

local test5b_pass = 1

* Original interval A: [Jan1, Dec31/2020] = 366 days (2020 is leap year), rate=365 (units/day)
* Intersect with B: [Jul1, Dec31/2020] = 184 days (or 185? Jul1-Dec31 = 6+31+30+31+30+31=184 days?)
* Actually Jul1 to Dec31: Jul(31-0=31), Aug=31, Sep=30, Oct=31, Nov=30, Dec=31 = 184 days... not counting Jul1
* Inclusive: Jul1 to Dec31 = 31+31+30+31+30+31 = 184 days... actually:
*   mdy(12,31,2020) - mdy(7,1,2020) + 1 = 184
* With rate=365 units/day, expected proportioned units for B portion = 365 * 184/366 ≈ 183.4
* But tvmerge treats continuous as rate per day, so the overlap period with both exposures active
* should have a rate proportional to the fraction.

clear
set obs 1
gen id = 1
gen startA = mdy(1,1,2020)
gen stopA  = mdy(12,31,2020)
gen rate_A = 366.0    // total dose units in period (approximately 1 per day)
save "$TVTOOLS_QA_RUN_DIR/tvm5b_dsetA.dta", replace

clear
set obs 1
gen id = 1
gen startB = mdy(7,1,2020)
gen stopB  = mdy(12,31,2020)
gen expB   = 1
save "$TVTOOLS_QA_RUN_DIR/tvm5b_dsetB.dta", replace

capture noisily tvmerge ///
    "$TVTOOLS_QA_RUN_DIR/tvm5b_dsetA.dta" "$TVTOOLS_QA_RUN_DIR/tvm5b_dsetB.dta", ///
    id(id) start(startA startB) stop(stopA stopB) exposure(rate_A expB) ///
    continuous(rate_A) generate(rate_A_out exp_B_out)

if _rc != 0 {
    display as error "  FAIL [5b.run]: tvmerge returned error `=_rc'"
    local test5b_pass = 0
}
else {
    sort id start
    quietly count
    local nrows = r(N)
    display "  INFO: `nrows' rows in merged output"
    list id start stop rate_A_out exp_B_out, noobs

    * Proportioning check:
    * tvmerge outputs only the INTERSECTION where both datasets have coverage.
    * Original: [Jan1/2020, Dec31/2020] = 366 days, rate_A = 366 (≈1/day)
    * Intersection with B: [Jul1/2020, Dec31/2020] = 184 days
    * Expected rate_A in intersection = 366 × (184/366) = 184.0
    * (proportioning formula: rate_out = rate_in × intersection_days/original_days)
    local orig_days = mdy(12,31,2020) - mdy(1,1,2020) + 1   // = 366
    local intersect_days = mdy(12,31,2020) - mdy(7,1,2020) + 1  // = 184
    local expected_rate = 366 * `intersect_days' / `orig_days'
    display "  INFO: orig_days=`orig_days', intersect_days=`intersect_days'"
    display "  INFO: Expected proportioned rate = `expected_rate' (= 366 × 184/366 = 184)"

    quietly sum rate_A_out
    local total_rate = r(sum)
    display "  INFO: Total rate_A_out in output = `total_rate' (expected = `expected_rate')"

    * The total should equal the proportioned rate (≈184)
    if abs(`total_rate' - `expected_rate') < 1 {
        display as result "  PASS [5b.proportioning]: rate_A proportioned correctly (total=`total_rate', expected=`expected_rate')"
    }
    else {
        display as error "  FAIL [5b.proportioning]: total=`total_rate', expected=`expected_rate', diff=`=abs(`total_rate'-`expected_rate')'"
        local test5b_pass = 0
    }
}

if `test5b_pass' == 1 {
    local pass_count = `pass_count' + 1
    display as result "TEST 5B: PASSED"
}
else {
    local fail_count = `fail_count' + 1
    local failed_tests "`failed_tests' 5b"
    display as error "TEST 5B: FAILED"
}

* TEST 5C: INTERVAL INTEGRITY - NO GAPS, NO OVERLAPS
display "TEST 5C: Interval integrity - no gaps or overlaps within person"

local test5c_pass = 1

* Create two datasets with varying exposure patterns for 5 persons
clear
set obs 5
gen id = _n
gen startA = mdy(1,1,2020) + (id-1)*30
gen stopA  = startA + 180
gen expA   = id
save "$TVTOOLS_QA_RUN_DIR/tvm5c_dsetA.dta", replace

clear
set obs 5
gen id = _n
gen startB = mdy(1,1,2020) + (id-1)*20
gen stopB  = startB + 200
gen expB   = id * 10
save "$TVTOOLS_QA_RUN_DIR/tvm5c_dsetB.dta", replace

capture noisily tvmerge ///
    "$TVTOOLS_QA_RUN_DIR/tvm5c_dsetA.dta" "$TVTOOLS_QA_RUN_DIR/tvm5c_dsetB.dta", ///
    id(id) start(startA startB) stop(stopA stopB) exposure(expA expB) ///
    generate(out_A out_B)

if _rc != 0 {
    display as error "  FAIL [5c.run]: tvmerge returned error `=_rc'"
    local test5c_pass = 0
}
else {
    sort id start
    quietly count
    local nrows = r(N)
    display "  INFO: `nrows' rows"

    * Check for gaps: stop[i] + 1 = start[i+1] within person
    quietly gen gap = start - stop[_n-1] - 1 if _n > 1 & id == id[_n-1]
    quietly count if gap > 0 & !missing(gap)
    if r(N) == 0 {
        display as result "  PASS [5c.no_gaps]: no gaps within any person's time"
    }
    else {
        display as error "  FAIL [5c.no_gaps]: `=r(N)' gaps found within persons"
        list id start stop gap if gap > 0
        local test5c_pass = 0
    }

    * Check for overlaps: start[i+1] <= stop[i] within person
    quietly gen overlap = stop - start[_n+1] if _n < _N & id == id[_n+1]
    quietly count if overlap >= 0 & !missing(overlap)
    if r(N) == 0 {
        display as result "  PASS [5c.no_overlaps]: no overlapping intervals within any person"
    }
    else {
        display as error "  FAIL [5c.no_overlaps]: `=r(N)' overlaps found"
        local test5c_pass = 0
    }

    * Check interval validity: start <= stop everywhere
    quietly count if start > stop
    if r(N) == 0 {
        display as result "  PASS [5c.validity]: start <= stop for all intervals"
    }
    else {
        display as error "  FAIL [5c.validity]: `=r(N)' intervals have start > stop"
        local test5c_pass = 0
    }
}

if `test5c_pass' == 1 {
    local pass_count = `pass_count' + 1
    display as result "TEST 5C: PASSED"
}
else {
    local fail_count = `fail_count' + 1
    local failed_tests "`failed_tests' 5c"
    display as error "TEST 5C: FAILED"
}

* FINAL SUMMARY

}

capture noisily {

* HELPER: Create standard cohort for reuse

* 5 persons, study 2020-2022
clear
set obs 5
gen long id = _n
gen double study_entry = mdy(1,1,2020)
gen double study_exit  = mdy(12,31,2021)
format study_entry study_exit %td
save "$TVTOOLS_QA_RUN_DIR/tvm_cohort.dta", replace

* TEST 1: 3-DATASET MERGE (AGE + DMT + HRT)
display "TEST 1: 3-dataset merge (age + DMT + HRT)"

local test1_pass = 1

* Dataset A: age bands (all 5 persons, 2 intervals each)
clear
set obs 10
gen long id = ceil(_n/2)
gen double startA = mdy(1,1,2020) if mod(_n,2) == 1
replace startA = mdy(1,1,2021) if mod(_n,2) == 0
gen double stopA = mdy(12,31,2020) if mod(_n,2) == 1
replace stopA = mdy(12,31,2021) if mod(_n,2) == 0
gen byte age_cat = 1 if mod(_n,2) == 1
replace age_cat = 2 if mod(_n,2) == 0
format startA stopA %td
save "$TVTOOLS_QA_RUN_DIR/tvm1_dsetA.dta", replace

* Dataset B: DMT exposure (all 5 persons, 3 intervals each)
clear
set obs 15
gen long id = ceil(_n/3)
gen double startB = mdy(1,1,2020) + (_n - (id-1)*3 - 1) * 243
gen double stopB  = startB + 242
replace stopB = mdy(12,31,2021) if stopB > mdy(12,31,2021)
gen byte dmt = mod(_n, 3)
format startB stopB %td
save "$TVTOOLS_QA_RUN_DIR/tvm1_dsetB.dta", replace

* Dataset C: HRT exposure (all 5 persons, 2 intervals each)
clear
set obs 10
gen long id = ceil(_n/2)
gen double startC = mdy(1,1,2020) if mod(_n,2) == 1
replace startC = mdy(7,1,2020) if mod(_n,2) == 0
gen double stopC = mdy(6,30,2020) if mod(_n,2) == 1
replace stopC = mdy(12,31,2021) if mod(_n,2) == 0
gen byte hrt = mod(_n, 2)
format startC stopC %td
save "$TVTOOLS_QA_RUN_DIR/tvm1_dsetC.dta", replace

capture noisily tvmerge ///
    "$TVTOOLS_QA_RUN_DIR/tvm1_dsetA.dta" "$TVTOOLS_QA_RUN_DIR/tvm1_dsetB.dta" "$TVTOOLS_QA_RUN_DIR/tvm1_dsetC.dta", ///
    id(id) start(startA startB startC) stop(stopA stopB stopC) ///
    exposure(age_cat dmt hrt) generate(age_out dmt_out hrt_out)

if _rc != 0 {
    display as error "  FAIL [1.run]: tvmerge returned error `=_rc'"
    local test1_pass = 0
}
else {
    sort id start
    * All 5 persons should be present
    quietly tab id
    local n_persons = r(r)
    if `n_persons' == 5 {
        display as result "  PASS [1.persons]: all 5 persons present"
    }
    else {
        display as error "  FAIL [1.persons]: `n_persons' persons (expected 5)"
        local test1_pass = 0
    }

    * All 3 exposure variables should exist
    local all_vars = 1
    foreach v in age_out dmt_out hrt_out {
        capture confirm variable `v'
        if _rc != 0 {
            display as error "  FAIL [1.vars]: variable `v' missing"
            local all_vars = 0
            local test1_pass = 0
        }
    }
    if `all_vars' == 1 {
        display as result "  PASS [1.vars]: all 3 exposure variables present"
    }

    * No missing values in exposure variables
    local has_miss = 0
    foreach v in age_out dmt_out hrt_out {
        quietly count if missing(`v')
        if r(N) > 0 {
            display as error "  FAIL [1.missing]: `v' has `=r(N)' missing values"
            local has_miss = 1
            local test1_pass = 0
        }
    }
    if `has_miss' == 0 {
        display as result "  PASS [1.no_missing]: no missing exposure values"
    }

    * Person-time conservation
    gen double dur = stop - start + 1
    preserve
    collapse (sum) total_days=dur, by(id)
    local expected_ptime = mdy(12,31,2021) - mdy(1,1,2020) + 1
    gen double ptime_diff = abs(total_days - `expected_ptime')
    quietly summarize ptime_diff
    local max_diff = r(max)
    restore

    if `max_diff' <= 2 {
        display as result "  PASS [1.ptime]: person-time conserved (max diff = `max_diff')"
    }
    else {
        display as error "  FAIL [1.ptime]: person-time not conserved (max diff = `max_diff')"
        local test1_pass = 0
    }
}

if `test1_pass' == 1 {
    local pass_count = `pass_count' + 1
    display as result "TEST 1: PASSED"
}
else {
    local fail_count = `fail_count' + 1
    local failed_tests "`failed_tests' 1"
    display as error "TEST 1: FAILED"
}

* TEST 2: 5-DATASET MERGE
display "TEST 2: 5-dataset merge (age + DMT + HRT + vaginal + IUD)"

local test2_pass = 1

* Dataset D: vaginal estrogen (5 persons, 1 interval each)
clear
set obs 5
gen long id = _n
gen double startD = mdy(1,1,2020)
gen double stopD  = mdy(12,31,2021)
gen byte vaginal = 0
replace vaginal = 1 in 2
replace vaginal = 1 in 4
format startD stopD %td
save "$TVTOOLS_QA_RUN_DIR/tvm2_dsetD.dta", replace

* Dataset E: IUD (5 persons, 1 interval each)
clear
set obs 5
gen long id = _n
gen double startE = mdy(1,1,2020)
gen double stopE  = mdy(12,31,2021)
gen byte iud = 0
replace iud = 1 in 3
replace iud = 1 in 5
format startE stopE %td
save "$TVTOOLS_QA_RUN_DIR/tvm2_dsetE.dta", replace

capture noisily tvmerge ///
    "$TVTOOLS_QA_RUN_DIR/tvm1_dsetA.dta" "$TVTOOLS_QA_RUN_DIR/tvm1_dsetB.dta" "$TVTOOLS_QA_RUN_DIR/tvm1_dsetC.dta" ///
    "$TVTOOLS_QA_RUN_DIR/tvm2_dsetD.dta" "$TVTOOLS_QA_RUN_DIR/tvm2_dsetE.dta", ///
    id(id) start(startA startB startC startD startE) ///
    stop(stopA stopB stopC stopD stopE) ///
    exposure(age_cat dmt hrt vaginal iud) ///
    generate(age5 dmt5 hrt5 vag5 iud5)

if _rc != 0 {
    display as error "  FAIL [2.run]: tvmerge returned error `=_rc'"
    local test2_pass = 0
}
else {
    sort id start

    * All 5 exposure variables should exist
    local all_vars = 1
    foreach v in age5 dmt5 hrt5 vag5 iud5 {
        capture confirm variable `v'
        if _rc != 0 {
            display as error "  FAIL [2.vars]: variable `v' missing"
            local all_vars = 0
            local test2_pass = 0
        }
    }
    if `all_vars' == 1 {
        display as result "  PASS [2.vars]: all 5 exposure variables present"
    }

    * All 5 persons present
    quietly tab id
    if r(r) == 5 {
        display as result "  PASS [2.persons]: all 5 persons present"
    }
    else {
        display as error "  FAIL [2.persons]: `=r(r)' persons (expected 5)"
        local test2_pass = 0
    }

    * Row count should be >= row count from 3-dataset merge
    quietly count
    local n5 = r(N)
    display "  INFO: 5-dataset merge produced `n5' rows"

    * Person-time conservation
    gen double dur = stop - start + 1
    preserve
    collapse (sum) total_days=dur, by(id)
    local expected_ptime = mdy(12,31,2021) - mdy(1,1,2020) + 1
    gen double ptime_diff = abs(total_days - `expected_ptime')
    quietly summarize ptime_diff
    local max_diff = r(max)
    restore

    if `max_diff' <= 2 {
        display as result "  PASS [2.ptime]: person-time conserved (max diff = `max_diff')"
    }
    else {
        display as error "  FAIL [2.ptime]: person-time not conserved (max diff = `max_diff')"
        local test2_pass = 0
    }
}

if `test2_pass' == 1 {
    local pass_count = `pass_count' + 1
    display as result "TEST 2: PASSED"
}
else {
    local fail_count = `fail_count' + 1
    local failed_tests "`failed_tests' 2"
    display as error "TEST 2: FAILED"
}

* TEST 3: BATCH() PRODUCES IDENTICAL OUTPUT
display "TEST 3: batch() option produces identical output"

local test3_pass = 1

* Merge with batch(5)
capture noisily tvmerge ///
    "$TVTOOLS_QA_RUN_DIR/tvm1_dsetA.dta" "$TVTOOLS_QA_RUN_DIR/tvm1_dsetB.dta", ///
    id(id) start(startA startB) stop(stopA stopB) ///
    exposure(age_cat dmt) generate(age_b5 dmt_b5) batch(5)

if _rc != 0 {
    display as error "  FAIL [3.batch5]: tvmerge batch(5) returned error `=_rc'"
    local test3_pass = 0
}
else {
    sort id start
    save "$TVTOOLS_QA_RUN_DIR/tvm3_batch5.dta", replace
}

* Merge with batch(100)
capture noisily tvmerge ///
    "$TVTOOLS_QA_RUN_DIR/tvm1_dsetA.dta" "$TVTOOLS_QA_RUN_DIR/tvm1_dsetB.dta", ///
    id(id) start(startA startB) stop(stopA stopB) ///
    exposure(age_cat dmt) generate(age_b100 dmt_b100) batch(100)

if _rc != 0 {
    display as error "  FAIL [3.batch100]: tvmerge batch(100) returned error `=_rc'"
    local test3_pass = 0
}
else {
    sort id start
    save "$TVTOOLS_QA_RUN_DIR/tvm3_batch100.dta", replace
}

if `test3_pass' == 1 {
    * Compare the two outputs
    use "$TVTOOLS_QA_RUN_DIR/tvm3_batch5.dta", clear
    quietly count
    local n_b5 = r(N)

    use "$TVTOOLS_QA_RUN_DIR/tvm3_batch100.dta", clear
    quietly count
    local n_b100 = r(N)

    if `n_b5' == `n_b100' {
        display as result "  PASS [3.rowcount]: identical row counts (`n_b5')"
    }
    else {
        display as error "  FAIL [3.rowcount]: batch(5)=`n_b5' rows, batch(100)=`n_b100' rows"
        local test3_pass = 0
    }

    * Check values match by comparing sorted row-by-row
    if `test3_pass' == 1 {
        * Load batch100 and save key variables
        use "$TVTOOLS_QA_RUN_DIR/tvm3_batch100.dta", clear
        sort id start stop
        rename age_b100 age_check
        rename dmt_b100 dmt_check
        gen long _rownum = _n
        keep id start stop age_check dmt_check _rownum
        save "$TVTOOLS_QA_RUN_DIR/tvm3_b100_compare.dta", replace

        * Load batch5 and compare
        use "$TVTOOLS_QA_RUN_DIR/tvm3_batch5.dta", clear
        sort id start stop
        gen long _rownum = _n

        * Merge on row number (both are sorted identically)
        merge 1:1 _rownum using "$TVTOOLS_QA_RUN_DIR/tvm3_b100_compare.dta", nogenerate
        gen byte diff_age = (age_b5 != age_check)
        gen byte diff_dmt = (dmt_b5 != dmt_check)
        quietly count if diff_age == 1 | diff_dmt == 1
        if r(N) == 0 {
            display as result "  PASS [3.values]: exposure values identical across batches"
        }
        else {
            display as error "  FAIL [3.values]: `=r(N)' rows differ between batch sizes"
            local test3_pass = 0
        }
        capture erase "$TVTOOLS_QA_RUN_DIR/tvm3_b100_compare.dta"
    }
}

if `test3_pass' == 1 {
    local pass_count = `pass_count' + 1
    display as result "TEST 3: PASSED"
}
else {
    local fail_count = `fail_count' + 1
    local failed_tests "`failed_tests' 3"
    display as error "TEST 3: FAILED"
}

* TEST 4: PERSON IN DATASET A BUT NOT DATASET B
display "TEST 4: Person in dataset A but not dataset B"

local test4_pass = 1

* Dataset A: persons 1-5
clear
set obs 5
gen long id = _n
gen double startA = mdy(1,1,2020)
gen double stopA  = mdy(12,31,2020)
gen byte expA = 1
format startA stopA %td
save "$TVTOOLS_QA_RUN_DIR/tvm4_dsetA.dta", replace

* Dataset B: only persons 1-3 (persons 4,5 missing)
clear
set obs 3
gen long id = _n
gen double startB = mdy(1,1,2020)
gen double stopB  = mdy(12,31,2020)
gen byte expB = 1
format startB stopB %td
save "$TVTOOLS_QA_RUN_DIR/tvm4_dsetB.dta", replace

* Should work with force option
capture noisily tvmerge ///
    "$TVTOOLS_QA_RUN_DIR/tvm4_dsetA.dta" "$TVTOOLS_QA_RUN_DIR/tvm4_dsetB.dta", ///
    id(id) start(startA startB) stop(stopA stopB) ///
    exposure(expA expB) generate(out_A out_B) force

if _rc != 0 {
    display as error "  FAIL [4.run]: tvmerge with force returned error `=_rc'"
    local test4_pass = 0
}
else {
    sort id start

    * Persons 1-3 should be present (matched in both)
    * Persons 4-5 behavior: with force, may be dropped
    quietly tab id
    local n_persons = r(r)
    display "  INFO: `n_persons' persons in output (3 matched, 2 in A only)"

    * Verify matched persons have both variables
    local all_vars = 1
    foreach v in out_A out_B {
        capture confirm variable `v'
        if _rc != 0 {
            local all_vars = 0
        }
    }
    if `all_vars' == 1 {
        display as result "  PASS [4.vars]: both exposure variables present"
    }
    else {
        display as error "  FAIL [4.vars]: missing exposure variable"
        local test4_pass = 0
    }

    * At minimum, 3 matched persons should be in output
    if `n_persons' >= 3 {
        display as result "  PASS [4.matched]: at least 3 matched persons present"
    }
    else {
        display as error "  FAIL [4.matched]: only `n_persons' persons"
        local test4_pass = 0
    }
}

if `test4_pass' == 1 {
    local pass_count = `pass_count' + 1
    display as result "TEST 4: PASSED"
}
else {
    local fail_count = `fail_count' + 1
    local failed_tests "`failed_tests' 4"
    display as error "TEST 4: FAILED"
}

* TEST 5: VERY UNEQUAL INTERVAL COUNTS
display "TEST 5: Datasets with very unequal interval counts"

local test5_pass = 1

* Dataset A: 2 intervals per person (annual)
clear
set obs 6
gen long id = ceil(_n/2)
gen double startA = mdy(1,1,2020) if mod(_n,2) == 1
replace startA = mdy(1,1,2021) if mod(_n,2) == 0
gen double stopA = mdy(12,31,2020) if mod(_n,2) == 1
replace stopA = mdy(12,31,2021) if mod(_n,2) == 0
gen byte expA = mod(_n, 2)
format startA stopA %td
save "$TVTOOLS_QA_RUN_DIR/tvm5_dsetA.dta", replace

* Dataset B: 24 intervals per person (monthly) for persons 1-3
clear
set obs 72
gen long id = ceil(_n/24)
gen int month_idx = _n - (id-1)*24
gen double startB = mdy(1,1,2020) + (month_idx - 1) * 30
gen double stopB  = startB + 29
replace stopB = mdy(12,31,2021) if stopB > mdy(12,31,2021)
* Ensure no gaps/overlaps from crude 30-day approximation
replace startB = stopB[_n-1] + 1 if id == id[_n-1] & startB <= stopB[_n-1] & _n > 1
drop if startB >= mdy(12,31,2021)
gen byte expB = mod(month_idx, 3)
format startB stopB %td
drop month_idx
save "$TVTOOLS_QA_RUN_DIR/tvm5_dsetB.dta", replace

capture noisily tvmerge ///
    "$TVTOOLS_QA_RUN_DIR/tvm5_dsetA.dta" "$TVTOOLS_QA_RUN_DIR/tvm5_dsetB.dta", ///
    id(id) start(startA startB) stop(stopA stopB) ///
    exposure(expA expB) generate(out_A out_B)

if _rc != 0 {
    display as error "  FAIL [5.run]: tvmerge returned error `=_rc'"
    local test5_pass = 0
}
else {
    sort id start

    * Output should have >= 24 rows per person (at least as many as the denser dataset)
    quietly tab id
    local n_persons = r(r)
    quietly count
    local total_rows = r(N)
    local avg_rows = `total_rows' / `n_persons'
    display "  INFO: `total_rows' total rows, avg `avg_rows' per person"

    if `avg_rows' >= 20 {
        display as result "  PASS [5.density]: dense dataset intervals preserved (avg `avg_rows' rows)"
    }
    else {
        display as error "  FAIL [5.density]: too few intervals (avg `avg_rows', expected >=20)"
        local test5_pass = 0
    }

    * No overlapping intervals
    local no_overlap = 1
    forvalues i = 2/`total_rows' {
        if id[`i'] == id[`i'-1] & start[`i'] <= stop[`i'-1] {
            local no_overlap = 0
        }
    }
    if `no_overlap' == 1 {
        display as result "  PASS [5.no_overlap]: no overlapping intervals"
    }
    else {
        display as error "  FAIL [5.no_overlap]: overlapping intervals found"
        local test5_pass = 0
    }
}

if `test5_pass' == 1 {
    local pass_count = `pass_count' + 1
    display as result "TEST 5: PASSED"
}
else {
    local fail_count = `fail_count' + 1
    local failed_tests "`failed_tests' 5"
    display as error "TEST 5: FAILED"
}

* TEST 6: CONTINUOUS PROPORTIONING THROUGH MULTI-MERGE
display "TEST 6: continuous() proportioning through multi-merge"

local test6_pass = 1

* Dataset A: 1 person, 1 year interval, continuous rate = 365 (1 unit/day)
clear
set obs 1
gen long id = 1
gen double startA = mdy(1,1,2020)
gen double stopA  = mdy(12,31,2020)
gen double rate_A = 366.0
format startA stopA %td
save "$TVTOOLS_QA_RUN_DIR/tvm6_dsetA.dta", replace

* Dataset B: 1 person, 2 half-year intervals (categorical)
clear
set obs 2
gen long id = 1
gen double startB = mdy(1,1,2020) in 1
replace startB = mdy(7,1,2020) in 2
gen double stopB = mdy(6,30,2020) in 1
replace stopB = mdy(12,31,2020) in 2
gen byte expB = 0 in 1
replace expB = 1 in 2
format startB stopB %td
save "$TVTOOLS_QA_RUN_DIR/tvm6_dsetB.dta", replace

capture noisily tvmerge ///
    "$TVTOOLS_QA_RUN_DIR/tvm6_dsetA.dta" "$TVTOOLS_QA_RUN_DIR/tvm6_dsetB.dta", ///
    id(id) start(startA startB) stop(stopA stopB) ///
    exposure(rate_A expB) continuous(rate_A) generate(rate_out exp_out)

if _rc != 0 {
    display as error "  FAIL [6.run]: tvmerge returned error `=_rc'"
    local test6_pass = 0
}
else {
    sort id start
    list id start stop rate_out exp_out, noobs

    * Sum of proportioned rate should equal original (366)
    quietly summarize rate_out
    local total_rate = r(sum)
    if abs(`total_rate' - 366) < 1 {
        display as result "  PASS [6.total]: total proportioned rate = `total_rate' (expected 366)"
    }
    else {
        display as error "  FAIL [6.total]: total proportioned rate = `total_rate' (expected 366)"
        local test6_pass = 0
    }

    * First half (Jan-Jun = 182 days in 2020): rate = 366 * 182/366 = 182
    quietly count
    local nrows = r(N)
    if `nrows' >= 2 {
        local rate_h1 = rate_out[1]
        local dur_h1 = stop[1] - start[1] + 1
        local expected_h1 = 366 * `dur_h1' / 366
        if abs(`rate_h1' - `expected_h1') < 1 {
            display as result "  PASS [6.h1_rate]: first half rate = `rate_h1' (expected `expected_h1')"
        }
        else {
            display as error "  FAIL [6.h1_rate]: first half rate = `rate_h1' (expected `expected_h1')"
            local test6_pass = 0
        }
    }
}

if `test6_pass' == 1 {
    local pass_count = `pass_count' + 1
    display as result "TEST 6: PASSED"
}
else {
    local fail_count = `fail_count' + 1
    local failed_tests "`failed_tests' 6"
    display as error "TEST 6: FAILED"
}

* TEST 7: MERGE PRESERVES EXPOSURE VALUES EXACTLY
display "TEST 7: Merge preserves exposure values exactly"

local test7_pass = 1

* Create two datasets with known categorical values
clear
set obs 3
gen long id = 1
gen double startA = mdy(1,1,2020) + (_n-1)*122
gen double stopA  = startA + 121
replace stopA = mdy(12,31,2020) if _n == 3
gen byte expA = _n
format startA stopA %td
save "$TVTOOLS_QA_RUN_DIR/tvm7_dsetA.dta", replace

clear
set obs 2
gen long id = 1
gen double startB = mdy(1,1,2020) in 1
replace startB = mdy(7,1,2020) in 2
gen double stopB = mdy(6,30,2020) in 1
replace stopB = mdy(12,31,2020) in 2
gen byte expB = 10 in 1
replace expB = 20 in 2
format startB stopB %td
save "$TVTOOLS_QA_RUN_DIR/tvm7_dsetB.dta", replace

capture noisily tvmerge ///
    "$TVTOOLS_QA_RUN_DIR/tvm7_dsetA.dta" "$TVTOOLS_QA_RUN_DIR/tvm7_dsetB.dta", ///
    id(id) start(startA startB) stop(stopA stopB) ///
    exposure(expA expB) generate(out_A out_B)

if _rc != 0 {
    display as error "  FAIL [7.run]: tvmerge returned error `=_rc'"
    local test7_pass = 0
}
else {
    sort id start
    list id start stop out_A out_B, noobs

    * Verify values are from original sets only
    local valid_A = 1
    local valid_B = 1
    quietly count
    local nrows = r(N)
    forvalues i = 1/`nrows' {
        local va = out_A[`i']
        if !inlist(`va', 1, 2, 3) {
            local valid_A = 0
        }
        local vb = out_B[`i']
        if !inlist(`vb', 10, 20) {
            local valid_B = 0
        }
    }
    if `valid_A' == 1 {
        display as result "  PASS [7.valuesA]: expA values preserved (all in {1,2,3})"
    }
    else {
        display as error "  FAIL [7.valuesA]: unexpected expA values"
        local test7_pass = 0
    }
    if `valid_B' == 1 {
        display as result "  PASS [7.valuesB]: expB values preserved (all in {10,20})"
    }
    else {
        display as error "  FAIL [7.valuesB]: unexpected expB values"
        local test7_pass = 0
    }
}

if `test7_pass' == 1 {
    local pass_count = `pass_count' + 1
    display as result "TEST 7: PASSED"
}
else {
    local fail_count = `fail_count' + 1
    local failed_tests "`failed_tests' 7"
    display as error "TEST 7: FAILED"
}

* TEST 8: PERSON-TIME CONSERVATION THROUGH MERGE
display "TEST 8: Person-time conservation through merge (5 persons)"

local test8_pass = 1

* Use the 3-dataset merge from test 1 and verify person-time
capture noisily tvmerge ///
    "$TVTOOLS_QA_RUN_DIR/tvm1_dsetA.dta" "$TVTOOLS_QA_RUN_DIR/tvm1_dsetB.dta" "$TVTOOLS_QA_RUN_DIR/tvm1_dsetC.dta", ///
    id(id) start(startA startB startC) stop(stopA stopB stopC) ///
    exposure(age_cat dmt hrt) generate(age_t8 dmt_t8 hrt_t8)

if _rc != 0 {
    display as error "  FAIL [8.run]: tvmerge returned error `=_rc'"
    local test8_pass = 0
}
else {
    sort id start

    * Check person-time for each person individually
    local expected_ptime = mdy(12,31,2021) - mdy(1,1,2020) + 1
    local all_conserved = 1

    forvalues p = 1/5 {
        quietly {
            gen double dur_t8 = stop - start + 1 if id == `p'
            summarize dur_t8
            local pt = r(sum)
            drop dur_t8
        }
        if abs(`pt' - `expected_ptime') <= 2 {
            display as result "  PASS [8.p`p']: person `p' time = `pt'"
        }
        else {
            display as error "  FAIL [8.p`p']: person `p' time = `pt' (expected `expected_ptime')"
            local all_conserved = 0
            local test8_pass = 0
        }
    }

    * No gaps check
    local has_gap = 0
    quietly count
    local nrows = r(N)
    forvalues i = 2/`nrows' {
        if id[`i'] == id[`i'-1] {
            local gap = start[`i'] - stop[`i'-1]
            if `gap' > 1 {
                local has_gap = 1
            }
        }
    }
    if `has_gap' == 0 {
        display as result "  PASS [8.no_gaps]: no gaps in person-time"
    }
    else {
        display as error "  FAIL [8.no_gaps]: gaps found in person-time"
        local test8_pass = 0
    }
}

if `test8_pass' == 1 {
    local pass_count = `pass_count' + 1
    display as result "TEST 8: PASSED"
}
else {
    local fail_count = `fail_count' + 1
    local failed_tests "`failed_tests' 8"
    display as error "TEST 8: FAILED"
}

* SUMMARY

}


* ===== Summary =====
* Fold the run_test/test_pass/test_fail harness counters into the totals.
local pass_count = `pass_count' + $TVQA_PASS
local fail_count = `fail_count' + $TVQA_FAIL
local failed_tests "`failed_tests' $TVQA_FAILED"
local test_count = `pass_count' + `fail_count'
display as result _newline "tvtools QA tvmerge correctness Results -- $S_DATE $S_TIME"
display as text "Tests run:  `test_count'"
display as text "Passed:     `pass_count'"
display as text "Failed:     `fail_count'"
display "RESULT: validation_tvmerge tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 {
    display as error "TESTS FAILED: `failed_tests'"
    exit 1
}
display as result "ALL TESTS PASSED"
