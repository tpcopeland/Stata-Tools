/*******************************************************************************
* validation_tvtools_pipeline_mathematical.do
*
* Purpose: End-to-end mathematical validation tracing exact values through
*          the full tvexpose -> tvmerge -> tvevent pipeline (mirrors an HRT
*          study workflow).
*
* Tests:
*   A. Person-Time Invariants (1-3)
*   B. Exposure Consistency (4-6)
*   C. Event Accuracy (7-8)
*   D. Conceptual Integrity (9-12)
*
* Run: stata-mp -b do validation_tvtools_pipeline_mathematical.do
* Log: validation_tvtools_pipeline_mathematical.log
*
* Author: Claude Code
* Date: 2026-02-18
*******************************************************************************/

clear all
set more off
version 16.0
set varabbrev off

* ============================================================================
* TEST INFRASTRUCTURE
* ============================================================================

local pass_count = 0
local fail_count = 0
local failed_tests ""

display _n _dup(70) "="
display "TVTOOLS PIPELINE MATHEMATICAL VALIDATION"
display _dup(70) "="
display "Date: $S_DATE $S_TIME"
display ""

quietly adopath ++ "/home/tpcopeland/Stata-Tools/tvtools"

* ============================================================================
* CREATE SHARED PIPELINE DATA
* ============================================================================
* 5 persons with precisely defined exposure and event patterns
* Person 1: unexposed throughout (control)
* Person 2: single exposure to drug A, no event
* Person 3: exposure to drug A then drug B, event day 200
* Person 4: overlapping drugs A and B, event day 300
* Person 5: full-window exposure to drug A, censored at exit

display _n _dup(60) "-"
display "Setting up pipeline data (5 persons)"
display _dup(60) "-"

* Cohort
clear
set obs 5
gen long id = _n
gen double study_entry = mdy(1,1,2020)
gen double study_exit  = mdy(12,31,2020)
format study_entry study_exit %td
save "/tmp/tvp_cohort.dta", replace

local ptime_expected = mdy(12,31,2020) - mdy(1,1,2020) + 1
display "  Expected person-time per person: `ptime_expected' days"

* ===== EXPOSURE DATASET A (drug A) =====
clear
set obs 0
gen long id = .
gen double startA = .
gen double stopA  = .
gen byte drugA = .

* Person 2: drug A from Mar1-Jun30
local n = _N + 1
set obs `n'
replace id = 2 in `n'
replace startA = mdy(3,1,2020) in `n'
replace stopA  = mdy(6,30,2020) in `n'
replace drugA  = 1 in `n'

* Person 3: drug A from Feb1-May31
local n = _N + 1
set obs `n'
replace id = 3 in `n'
replace startA = mdy(2,1,2020) in `n'
replace stopA  = mdy(5,31,2020) in `n'
replace drugA  = 1 in `n'

* Person 4: drug A from Jan15-Sep30
local n = _N + 1
set obs `n'
replace id = 4 in `n'
replace startA = mdy(1,15,2020) in `n'
replace stopA  = mdy(9,30,2020) in `n'
replace drugA  = 1 in `n'

* Person 5: drug A full window
local n = _N + 1
set obs `n'
replace id = 5 in `n'
replace startA = mdy(1,1,2020) in `n'
replace stopA  = mdy(12,31,2020) in `n'
replace drugA  = 1 in `n'

format startA stopA %td
save "/tmp/tvp_expA.dta", replace

* ===== EXPOSURE DATASET B (drug B) =====
clear
set obs 0
gen long id = .
gen double startB = .
gen double stopB  = .
gen byte drugB = .

* Person 3: drug B from Jun1-Oct31 (sequential after A)
local n = _N + 1
set obs `n'
replace id = 3 in `n'
replace startB = mdy(6,1,2020) in `n'
replace stopB  = mdy(10,31,2020) in `n'
replace drugB  = 1 in `n'

* Person 4: drug B from Jul1-Dec31 (overlaps with A's Jul1-Sep30 period)
local n = _N + 1
set obs `n'
replace id = 4 in `n'
replace startB = mdy(7,1,2020) in `n'
replace stopB  = mdy(12,31,2020) in `n'
replace drugB  = 1 in `n'

format startB stopB %td
save "/tmp/tvp_expB.dta", replace

* ===== STEP 1: tvexpose for drug A =====
display _n "Running tvexpose for drug A..."
use "/tmp/tvp_cohort.dta", clear
capture noisily tvexpose using "/tmp/tvp_expA.dta", ///
    id(id) start(startA) stop(stopA) ///
    exposure(drugA) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    generate(exp_A)

if _rc != 0 {
    display as error "FATAL: tvexpose for drug A failed (rc=`=_rc')"
    display as error "Cannot continue pipeline tests."
    exit `=_rc'
}

sort id startA
save "/tmp/tvp_step1A.dta", replace
display "  tvexpose A: `=_N' rows"

* ===== STEP 1B: tvexpose for drug B =====
display "Running tvexpose for drug B..."
use "/tmp/tvp_cohort.dta", clear
capture noisily tvexpose using "/tmp/tvp_expB.dta", ///
    id(id) start(startB) stop(stopB) ///
    exposure(drugB) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    generate(exp_B)

if _rc != 0 {
    display as error "FATAL: tvexpose for drug B failed (rc=`=_rc')"
    exit `=_rc'
}

sort id startB
save "/tmp/tvp_step1B.dta", replace
display "  tvexpose B: `=_N' rows"

* ===== STEP 2: tvmerge =====
display _n "Running tvmerge..."
capture noisily tvmerge ///
    "/tmp/tvp_step1A.dta" "/tmp/tvp_step1B.dta", ///
    id(id) start(startA startB) stop(stopA stopB) ///
    exposure(exp_A exp_B) generate(merged_A merged_B)

if _rc != 0 {
    display as error "FATAL: tvmerge failed (rc=`=_rc')"
    exit `=_rc'
}

sort id start
save "/tmp/tvp_step2.dta", replace
display "  tvmerge: `=_N' rows"

* ===== EVENT DATA =====
* Person 3: event on Jul 19 (day 200 from Jan1)
* Person 4: event on Oct 27 (day 300 from Jan1)
clear
set obs 5
gen long id = _n
gen double event_date = .
replace event_date = mdy(1,1,2020) + 199 in 3
replace event_date = mdy(1,1,2020) + 299 in 4
format event_date %td
save "/tmp/tvp_events.dta", replace

* ===== STEP 3: tvevent =====
display "Running tvevent..."
use "/tmp/tvp_events.dta", clear
capture noisily tvevent using "/tmp/tvp_step2.dta", ///
    id(id) date(event_date) ///
    type(single) generate(outcome)

if _rc != 0 {
    display as error "FATAL: tvevent failed (rc=`=_rc')"
    exit `=_rc'
}

sort id start
save "/tmp/tvp_step3.dta", replace
display "  tvevent: `=_N' rows"

display _n "Pipeline complete. Running mathematical validation tests."

* ============================================================================
* TEST 1: PERSON-TIME AFTER TVEXPOSE
* ============================================================================
display _n _dup(60) "-"
display "TEST 1: Person-time invariant after tvexpose"
display _dup(60) "-"

local test1_pass = 1

use "/tmp/tvp_step1A.dta", clear
gen double dur = stopA - startA + 1
preserve
collapse (sum) total_days=dur, by(id)
gen double ptime_diff = abs(total_days - `ptime_expected')
quietly summarize ptime_diff
local max_diff = r(max)
restore

if `max_diff' <= 1 {
    display as result "  PASS [1.ptime_A]: all 5 persons ptime correct after tvexpose A (max diff=`max_diff')"
}
else {
    display as error "  FAIL [1.ptime_A]: person-time error after tvexpose A (max diff=`max_diff')"
    local test1_pass = 0
}

use "/tmp/tvp_step1B.dta", clear
gen double dur = stopB - startB + 1
preserve
collapse (sum) total_days=dur, by(id)
gen double ptime_diff = abs(total_days - `ptime_expected')
quietly summarize ptime_diff
local max_diff_B = r(max)
restore

if `max_diff_B' <= 1 {
    display as result "  PASS [1.ptime_B]: all 5 persons ptime correct after tvexpose B (max diff=`max_diff_B')"
}
else {
    display as error "  FAIL [1.ptime_B]: person-time error after tvexpose B (max diff=`max_diff_B')"
    local test1_pass = 0
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

* ============================================================================
* TEST 2: PERSON-TIME AFTER TVMERGE
* ============================================================================
display _n _dup(60) "-"
display "TEST 2: Person-time invariant after tvmerge"
display _dup(60) "-"

local test2_pass = 1

use "/tmp/tvp_step2.dta", clear
gen double dur = stop - start + 1
preserve
collapse (sum) total_days=dur, by(id)
gen double ptime_diff = abs(total_days - `ptime_expected')
quietly summarize ptime_diff
local max_diff = r(max)
local mean_diff = r(mean)
restore

if `max_diff' <= 1 {
    display as result "  PASS [2.ptime_merge]: person-time conserved after merge (max diff=`max_diff')"
}
else {
    display as error "  FAIL [2.ptime_merge]: person-time error after merge (max diff=`max_diff')"
    local test2_pass = 0
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

* ============================================================================
* TEST 3: PERSON-TIME AFTER TVEVENT (TRUNCATED AT EVENT)
* ============================================================================
display _n _dup(60) "-"
display "TEST 3: Person-time after tvevent (truncated correctly)"
display _dup(60) "-"

local test3_pass = 1

use "/tmp/tvp_step3.dta", clear
gen double dur = stop - start + 1

* Person 1,2,5: no event - ptime should = full window
* Person 3: event day 200 - ptime should ≈ 200
* Person 4: event day 300 - ptime should ≈ 300

preserve
collapse (sum) total_days=dur, by(id)

* Persons without events
foreach p in 1 2 5 {
    quietly summarize total_days if id == `p'
    local pt = r(mean)
    if abs(`pt' - `ptime_expected') <= 1 {
        display as result "  PASS [3.p`p']: person `p' ptime=`pt' (full window, no event)"
    }
    else {
        display as error "  FAIL [3.p`p']: person `p' ptime=`pt' (expected `ptime_expected')"
        local test3_pass = 0
    }
}

* Person 3: event at day 200 (mdy(1,1,2020)+199 = Jul19/2020)
* Expected ptime from Jan1 to Jul19 = 200 days (inclusive of both endpoints? depends on convention)
quietly summarize total_days if id == 3
local pt3 = r(mean)
if `pt3' >= 199 & `pt3' <= 201 {
    display as result "  PASS [3.p3]: person 3 ptime=`pt3' (event day ~200)"
}
else {
    display as error "  FAIL [3.p3]: person 3 ptime=`pt3' (expected ~200)"
    local test3_pass = 0
}

* Person 4: event at day 300
quietly summarize total_days if id == 4
local pt4 = r(mean)
if `pt4' >= 299 & `pt4' <= 301 {
    display as result "  PASS [3.p4]: person 4 ptime=`pt4' (event day ~300)"
}
else {
    display as error "  FAIL [3.p4]: person 4 ptime=`pt4' (expected ~300)"
    local test3_pass = 0
}

restore

if `test3_pass' == 1 {
    local pass_count = `pass_count' + 1
    display as result "TEST 3: PASSED"
}
else {
    local fail_count = `fail_count' + 1
    local failed_tests "`failed_tests' 3"
    display as error "TEST 3: FAILED"
}

* ============================================================================
* TEST 4: EXPOSURE CONSISTENCY THROUGH PIPELINE
* ============================================================================
display _n _dup(60) "-"
display "TEST 4: Exposure values consistent through pipeline"
display _dup(60) "-"

local test4_pass = 1

use "/tmp/tvp_step2.dta", clear

* Person 2: drug A exposed from Mar1-Jun30, unexposed rest
* Check all merged rows overlapping Mar1-Jun30 have merged_A == 1
local exp_start = mdy(3,1,2020)
local exp_stop  = mdy(6,30,2020)

* Rows where person 2 should be exposed to A
quietly count if id == 2 & start >= `exp_start' & stop <= `exp_stop' & merged_A != 1
local n_wrong_A = r(N)
if `n_wrong_A' == 0 {
    display as result "  PASS [4.p2_expA]: person 2 correctly exposed to A during [Mar1,Jun30]"
}
else {
    display as error "  FAIL [4.p2_expA]: `n_wrong_A' rows with wrong exposure in [Mar1,Jun30]"
    local test4_pass = 0
}

* Rows where person 2 should NOT be exposed to A (before Mar1 or after Jun30)
quietly count if id == 2 & (stop < `exp_start' | start > `exp_stop') & merged_A != 0
local n_wrong_unexp = r(N)
if `n_wrong_unexp' == 0 {
    display as result "  PASS [4.p2_unexpA]: person 2 correctly unexposed outside [Mar1,Jun30]"
}
else {
    display as error "  FAIL [4.p2_unexpA]: `n_wrong_unexp' rows incorrectly exposed outside window"
    local test4_pass = 0
}

* Person 5: drug A for entire window
quietly count if id == 5 & merged_A != 1
local n_p5_unexp = r(N)
if `n_p5_unexp' == 0 {
    display as result "  PASS [4.p5_full]: person 5 exposed throughout"
}
else {
    display as error "  FAIL [4.p5_full]: person 5 has `n_p5_unexp' unexposed rows"
    local test4_pass = 0
}

* Person 1: never exposed to either drug
quietly count if id == 1 & (merged_A != 0 | merged_B != 0)
local n_p1_exp = r(N)
if `n_p1_exp' == 0 {
    display as result "  PASS [4.p1_unexp]: person 1 unexposed to both drugs"
}
else {
    display as error "  FAIL [4.p1_unexp]: person 1 has `n_p1_exp' exposed rows"
    local test4_pass = 0
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

* ============================================================================
* TEST 5: CUMULATIVE EXPOSURE TRACKING (CONTINUOUS)
* ============================================================================
display _n _dup(60) "-"
display "TEST 5: Cumulative exposure tracking with continuousunit"
display _dup(60) "-"

local test5_pass = 1

* Create a fresh tvexpose with continuousunit(days)
use "/tmp/tvp_cohort.dta", clear
capture noisily tvexpose using "/tmp/tvp_expA.dta", ///
    id(id) start(startA) stop(stopA) ///
    exposure(drugA) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    continuousunit(days) generate(cum_A)

if _rc != 0 {
    display as error "  FAIL [5.run]: tvexpose with continuousunit(days) failed (rc=`=_rc')"
    local test5_pass = 0
}
else {
    sort id startA

    * Person 2: exposed Mar1-Jun30 = 122 days
    * At last exposed row, cumulative should be ~122
    quietly summarize cum_A if id == 2
    local max_cum_2 = r(max)
    if abs(`max_cum_2' - 122) <= 2 {
        display as result "  PASS [5.p2_cum]: person 2 cumulative = `max_cum_2' (expected ~122)"
    }
    else {
        display as error "  FAIL [5.p2_cum]: person 2 cumulative = `max_cum_2' (expected ~122)"
        local test5_pass = 0
    }

    * Person 5: exposed full window = 366 days (leap year)
    quietly summarize cum_A if id == 5
    local max_cum_5 = r(max)
    if abs(`max_cum_5' - 366) <= 2 {
        display as result "  PASS [5.p5_cum]: person 5 cumulative = `max_cum_5' (expected ~366)"
    }
    else {
        display as error "  FAIL [5.p5_cum]: person 5 cumulative = `max_cum_5' (expected ~366)"
        local test5_pass = 0
    }

    * Person 1: no exposure, cumulative should be 0
    quietly summarize cum_A if id == 1
    local max_cum_1 = r(max)
    if `max_cum_1' == 0 {
        display as result "  PASS [5.p1_zero]: person 1 cumulative = 0 (unexposed)"
    }
    else {
        display as error "  FAIL [5.p1_zero]: person 1 cumulative = `max_cum_1' (expected 0)"
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

* ============================================================================
* TEST 6: DURATION CATEGORY BOUNDARIES
* ============================================================================
display _n _dup(60) "-"
display "TEST 6: Duration category transitions at correct day"
display _dup(60) "-"

local test6_pass = 1

* Person with long exposure: Jan1-Dec31, duration(0.5) with continuousunit(years)
* 0.5 years = ~183 days. At day ~183, should transition from category <0.5 to 0.5+

clear
set obs 1
gen long id = 1
gen double study_entry = mdy(1,1,2020)
gen double study_exit  = mdy(12,31,2020)
format study_entry study_exit %td
save "/tmp/tvp6_cohort.dta", replace

clear
set obs 1
gen long id = 1
gen double start = mdy(1,1,2020)
gen double stop  = mdy(12,31,2020)
gen byte drug = 1
format start stop %td
save "/tmp/tvp6_exp.dta", replace

use "/tmp/tvp6_cohort.dta", clear
capture noisily tvexpose using "/tmp/tvp6_exp.dta", ///
    id(id) start(start) stop(stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    duration(0.5) continuousunit(years) generate(dur_cat)

if _rc != 0 {
    display as error "  FAIL [6.run]: tvexpose with duration() failed (rc=`=_rc')"
    local test6_pass = 0
}
else {
    sort id start
    list id start stop dur_cat, noobs

    * Should have at least 2 different duration categories for exposed time
    quietly levelsof dur_cat, local(dur_levels)
    local n_levels : word count `dur_levels'

    if `n_levels' >= 2 {
        display as result "  PASS [6.categories]: `n_levels' duration categories present"
    }
    else {
        display as error "  FAIL [6.categories]: only `n_levels' categories (expected >=2)"
        local test6_pass = 0
    }

    * The transition should happen around day 183 (0.5 * 365.25)
    * Check the stop date of the first exposed row
    quietly count
    local nrows = r(N)
    if `nrows' >= 2 {
        * Find where category changes
        local trans_date = .
        forvalues i = 2/`nrows' {
            if dur_cat[`i'] != dur_cat[`i'-1] & dur_cat[`i'] > 0 {
                local trans_date = start[`i']
                continue, break
            }
        }
        if `trans_date' != . {
            local trans_day = `trans_date' - mdy(1,1,2020)
            local expected_trans = floor(0.5 * 365.25)
            display "  INFO: transition at day `trans_day' (expected ~`expected_trans')"
            if abs(`trans_day' - `expected_trans') <= 5 {
                display as result "  PASS [6.boundary]: transition at correct day"
            }
            else {
                display as error "  FAIL [6.boundary]: transition at day `trans_day' (expected ~`expected_trans')"
                local test6_pass = 0
            }
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

* ============================================================================
* TEST 7: EVENT ACCURACY THROUGH FULL PIPELINE
* ============================================================================
display _n _dup(60) "-"
display "TEST 7: Event coded in correct row through full pipeline"
display _dup(60) "-"

local test7_pass = 1

use "/tmp/tvp_step3.dta", clear

* Person 3: event at mdy(1,1,2020)+199 = Jul 19, 2020
* The outcome variable should be 1 in exactly 1 row for this person
quietly count if id == 3 & outcome == 1
local p3_events = r(N)
if `p3_events' == 1 {
    display as result "  PASS [7.p3_count]: person 3 has exactly 1 event row"
}
else {
    display as error "  FAIL [7.p3_count]: person 3 has `p3_events' event rows (expected 1)"
    local test7_pass = 0
}

* Verify the event row's stop date = event date
if `p3_events' == 1 {
    quietly summarize stop if id == 3 & outcome == 1
    local event_stop = r(mean)
    local expected_event = mdy(1,1,2020) + 199
    if `event_stop' == `expected_event' {
        display as result "  PASS [7.p3_date]: person 3 event at correct date"
    }
    else {
        local d1 : display %td `event_stop'
        local d2 : display %td `expected_event'
        display as error "  FAIL [7.p3_date]: event stop=`d1', expected=`d2'"
        local test7_pass = 0
    }
}

* Person 4: event at mdy(1,1,2020)+299 = Oct 27, 2020
quietly count if id == 4 & outcome == 1
local p4_events = r(N)
if `p4_events' == 1 {
    display as result "  PASS [7.p4_count]: person 4 has exactly 1 event row"
}
else {
    display as error "  FAIL [7.p4_count]: person 4 has `p4_events' event rows (expected 1)"
    local test7_pass = 0
}

* Persons 1, 2, 5: no events
foreach p in 1 2 5 {
    quietly count if id == `p' & outcome == 1
    if r(N) == 0 {
        display as result "  PASS [7.p`p'_censor]: person `p' has no event (censored)"
    }
    else {
        display as error "  FAIL [7.p`p'_censor]: person `p' has `=r(N)' event rows"
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

* ============================================================================
* TEST 8: CENSORING TIME CALCULATION
* ============================================================================
display _n _dup(60) "-"
display "TEST 8: Censoring/event time = last_stop - study_entry"
display _dup(60) "-"

local test8_pass = 1

use "/tmp/tvp_step3.dta", clear
sort id start

* Calculate total follow-up per person (last stop - first start + 1)
preserve
collapse (min) first_start=start (max) last_stop=stop, by(id)

* Person 3: follow-up should end at event date (day 200)
quietly summarize last_stop if id == 3
local p3_last = r(mean)
local p3_expected = mdy(1,1,2020) + 199
if abs(`p3_last' - `p3_expected') <= 1 {
    display as result "  PASS [8.p3_time]: person 3 follow-up ends at event"
}
else {
    local d1 : display %td `p3_last'
    display as error "  FAIL [8.p3_time]: person 3 last_stop=`d1'"
    local test8_pass = 0
}

* Censored persons (1,2,5): follow-up should end at study_exit
foreach p in 1 2 5 {
    quietly summarize last_stop if id == `p'
    local pt_last = r(mean)
    if `pt_last' == mdy(12,31,2020) {
        display as result "  PASS [8.p`p'_censor]: person `p' censored at study exit"
    }
    else {
        local d1 : display %td `pt_last'
        display as error "  FAIL [8.p`p'_censor]: person `p' last_stop=`d1' (expected Dec31/2020)"
        local test8_pass = 0
    }
}

restore

if `test8_pass' == 1 {
    local pass_count = `pass_count' + 1
    display as result "TEST 8: PASSED"
}
else {
    local fail_count = `fail_count' + 1
    local failed_tests "`failed_tests' 8"
    display as error "TEST 8: FAILED"
}

* ============================================================================
* TEST 9: TIME ADDITIVITY
* ============================================================================
display _n _dup(60) "-"
display "TEST 9: Time additivity (sum of intervals = total follow-up)"
display _dup(60) "-"

local test9_pass = 1

use "/tmp/tvp_step3.dta", clear
gen double dur = stop - start + 1

preserve
collapse (sum) total_days=dur (min) first_start=start (max) last_stop=stop, by(id)
gen double span = last_stop - first_start + 1
gen double additivity_err = abs(total_days - span)
quietly summarize additivity_err
local max_err = r(max)
restore

if `max_err' <= 1 {
    display as result "  PASS [9.additivity]: all intervals sum to span (max error=`max_err')"
}
else {
    display as error "  FAIL [9.additivity]: interval sums deviate from span (max error=`max_err')"
    local test9_pass = 0
}

if `test9_pass' == 1 {
    local pass_count = `pass_count' + 1
    display as result "TEST 9: PASSED"
}
else {
    local fail_count = `fail_count' + 1
    local failed_tests "`failed_tests' 9"
    display as error "TEST 9: FAILED"
}

* ============================================================================
* TEST 10: NO IMMORTAL TIME BIAS
* ============================================================================
display _n _dup(60) "-"
display "TEST 10: No immortal time bias (unexposed time preserved)"
display _dup(60) "-"

local test10_pass = 1

use "/tmp/tvp_step2.dta", clear

* Person 2: unexposed before Mar1 and after Jun30
* Check that the reference period exists and is classified correctly
quietly count if id == 2 & merged_A == 0
local n_unexp = r(N)
if `n_unexp' >= 1 {
    display as result "  PASS [10.p2_ref]: person 2 has `n_unexp' reference period rows"
}
else {
    display as error "  FAIL [10.p2_ref]: person 2 has no reference periods (immortal time bias!)"
    local test10_pass = 0
}

* The reference periods should cover time before first exposure and after last
* Before exposure: Jan1 to Feb29 (60 days)
quietly summarize start if id == 2 & merged_A == 0
local first_ref_start = r(min)
if `first_ref_start' == mdy(1,1,2020) {
    display as result "  PASS [10.p2_early_ref]: unexposed time starts at study entry"
}
else {
    local d1 : display %td `first_ref_start'
    display as error "  FAIL [10.p2_early_ref]: unexposed starts at `d1' (expected Jan1)"
    local test10_pass = 0
}

* Person 1: fully unexposed - all person-time should be reference
quietly count if id == 1 & (merged_A != 0 | merged_B != 0)
if r(N) == 0 {
    display as result "  PASS [10.p1_all_ref]: person 1 fully in reference group"
}
else {
    display as error "  FAIL [10.p1_all_ref]: person 1 has `=r(N)' exposed rows"
    local test10_pass = 0
}

if `test10_pass' == 1 {
    local pass_count = `pass_count' + 1
    display as result "TEST 10: PASSED"
}
else {
    local fail_count = `fail_count' + 1
    local failed_tests "`failed_tests' 10"
    display as error "TEST 10: FAILED"
}

* ============================================================================
* TEST 11: NO FUTURE EXPOSURE
* ============================================================================
display _n _dup(60) "-"
display "TEST 11: No future exposure (exposure only from started prescriptions)"
display _dup(60) "-"

local test11_pass = 1

use "/tmp/tvp_step2.dta", clear

* Person 2: drug A starts Mar1. Before Mar1, merged_A must be 0
quietly count if id == 2 & start < mdy(3,1,2020) & merged_A != 0
local n_future = r(N)
if `n_future' == 0 {
    display as result "  PASS [11.no_future]: no future exposure for person 2 before Mar1"
}
else {
    display as error "  FAIL [11.no_future]: `n_future' rows with exposure before prescription start"
    local test11_pass = 0
}

* Person 3: drug B starts Jun1. Before Jun1, merged_B must be 0
quietly count if id == 3 & start < mdy(6,1,2020) & merged_B != 0
local n_future3 = r(N)
if `n_future3' == 0 {
    display as result "  PASS [11.no_future3]: no future exposure for person 3 (drug B) before Jun1"
}
else {
    display as error "  FAIL [11.no_future3]: `n_future3' rows with future exposure"
    local test11_pass = 0
}

if `test11_pass' == 1 {
    local pass_count = `pass_count' + 1
    display as result "TEST 11: PASSED"
}
else {
    local fail_count = `fail_count' + 1
    local failed_tests "`failed_tests' 11"
    display as error "TEST 11: FAILED"
}

* ============================================================================
* TEST 12: CORRECT CENSORING (NO POST-EVENT ROWS)
* ============================================================================
display _n _dup(60) "-"
display "TEST 12: Correct censoring (no post-event rows for type=single)"
display _dup(60) "-"

local test12_pass = 1

use "/tmp/tvp_step3.dta", clear

* Person 3: event at day 200 (Jul19). No rows should exist after this date.
local p3_event = mdy(1,1,2020) + 199
quietly count if id == 3 & start > `p3_event'
local n_post3 = r(N)
if `n_post3' == 0 {
    display as result "  PASS [12.p3_no_post]: no post-event rows for person 3"
}
else {
    display as error "  FAIL [12.p3_no_post]: `n_post3' rows after event for person 3"
    local test12_pass = 0
}

* Person 4: event at day 300 (Oct27). No rows after.
local p4_event = mdy(1,1,2020) + 299
quietly count if id == 4 & start > `p4_event'
local n_post4 = r(N)
if `n_post4' == 0 {
    display as result "  PASS [12.p4_no_post]: no post-event rows for person 4"
}
else {
    display as error "  FAIL [12.p4_no_post]: `n_post4' rows after event for person 4"
    local test12_pass = 0
}

* Censored persons should have rows through study exit
foreach p in 1 2 5 {
    quietly summarize stop if id == `p'
    local pt_last = r(max)
    if `pt_last' == mdy(12,31,2020) {
        display as result "  PASS [12.p`p'_full]: person `p' has rows through study exit"
    }
    else {
        local d1 : display %td `pt_last'
        display as error "  FAIL [12.p`p'_full]: person `p' ends at `d1' (expected Dec31)"
        local test12_pass = 0
    }
}

if `test12_pass' == 1 {
    local pass_count = `pass_count' + 1
    display as result "TEST 12: PASSED"
}
else {
    local fail_count = `fail_count' + 1
    local failed_tests "`failed_tests' 12"
    display as error "TEST 12: FAILED"
}

* ============================================================================
* SUMMARY
* ============================================================================
display _n _dup(70) "="
display "TVTOOLS PIPELINE MATHEMATICAL VALIDATION SUMMARY"
display _dup(70) "="
display "Total tests: `=`pass_count' + `fail_count''"
display as result "Passed: `pass_count'"
if `fail_count' > 0 {
    display as error "Failed: `fail_count'"
    display as error "Failed tests:`failed_tests'"
}
else {
    display as result "Failed: 0"
    display as result "ALL TESTS PASSED"
}
display _dup(70) "="

* Clean up temp files
foreach f in cohort expA expB step1A step1B step2 events step3 {
    capture erase "/tmp/tvp_`f'.dta"
}
capture erase "/tmp/tvp6_cohort.dta"
capture erase "/tmp/tvp6_exp.dta"

exit, clear
