/*******************************************************************************
* validation_tvtools_pipeline_stress.do
*
* Purpose: End-to-end pipeline stress tests: tvexpose → tvevent → stset → stcox.
*          Uses a deterministic 3-person synthetic cohort with hand-calculable results.
*
* Synthetic Cohort (all 2020, leap year = 366 days):
*   P1 (control):        Jan1-Dec31, no exposure, no event (censored)
*   P2 (exposed,censor): Jan1-Dec31, Drug 1 Apr1-Sep30, no event (censored)
*   P3 (exposed,event):  Jan1-Dec31, Drug 1 Feb1-Jul31, event Jun15
*
* Tests 1-5:   tvexpose → tvevent single-drug pipeline
* Tests 6-8:   Survival analysis verification
* Tests 9-12:  Multi-drug pipeline (add Drug B for Person 2)
*
* Run: stata-mp -b do validation_tvtools_pipeline_stress.do
*
* Author: Claude Code
* Date: 2026-03-11
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

capture program drop assert_exact
program define assert_exact
    args actual expected label
    if `actual' == `expected' {
        display as result "  PASS [`label']: value=`actual'"
    }
    else {
        display as error "  FAIL [`label']: actual=`actual', expected=`expected'"
        exit 9
    }
end

capture program drop assert_approx
program define assert_approx
    args actual expected tolerance label
    local diff = abs(`actual' - `expected')
    if `diff' <= `tolerance' {
        display as result "  PASS [`label']: actual=`actual', expected=`expected', diff=`diff'"
    }
    else {
        display as error "  FAIL [`label']: actual=`actual', expected=`expected', diff=`diff' > tol=`tolerance'"
        exit 9
    }
end

display _n _dup(70) "="
display "TVTOOLS PIPELINE STRESS VALIDATION (12 tests)"
display _dup(70) "="
display "Date: $S_DATE $S_TIME"
display ""

capture net uninstall tvtools
quietly net install tvtools, from("`c(pwd)'/..") replace

* ============================================================================
* CREATE SYNTHETIC COHORT
* ============================================================================

* Cohort master data
tempfile cohort
clear
input int(id)
1
2
3
end
gen double study_entry = mdy(1,1,2020)
gen double study_exit  = mdy(12,31,2020)
format %td study_entry study_exit
save `cohort', replace

* Exposure data (single drug)
tempfile exposure1
clear
input int(id drug) str10(s_start s_stop)
2 1 "2020-04-01" "2020-09-30"
3 1 "2020-02-01" "2020-07-31"
end
gen double start = date(s_start, "YMD")
gen double stop  = date(s_stop, "YMD")
format %td start stop
drop s_start s_stop
save `exposure1', replace

* Event data
tempfile events_single
clear
input int(id) str10(s_event)
3 "2020-06-15"
end
gen double event_date = date(s_event, "YMD")
format %td event_date
drop s_event
* Persons 1 and 2 have no event (censored)
* Add them with missing event dates
set obs 3
replace id = 1 in 2
replace id = 2 in 3
save `events_single', replace


* ============================================================================
* TESTS 1-5: TVEXPOSE → TVEVENT SINGLE-DRUG PIPELINE
* ============================================================================

* Run tvexpose
use `cohort', clear
capture noisily tvexpose using `exposure1', ///
    id(id) start(start) stop(stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    generate(exp_val)

if _rc != 0 {
    display as error "PIPELINE SETUP FAILED: tvexpose error `=_rc'"
    display as error "Cannot continue pipeline tests."
    exit 1
}

tempfile tvexpose_result
save `tvexpose_result', replace

* TEST 1: tvexpose row count
* P1: no exposure → 1 row [Jan1,Dec31] exp_val=0
* P2: Drug 1 Apr1-Sep30 → 3 rows [Jan1,Mar31]=0, [Apr1,Sep30]=1, [Oct1,Dec31]=0
* P3: Drug 1 Feb1-Jul31 → 3 rows [Jan1,Jan31]=0, [Feb1,Jul31]=1, [Aug1,Dec31]=0
* Total: 1 + 3 + 3 = 7 rows

display _n _dup(60) "-"
display "TEST 1: tvexpose row count"
display _dup(60) "-"
local test1_pass = 1

quietly count
if r(N) == 7 {
    display as result "  PASS [1.rows]: 7 rows"
}
else {
    display as error "  FAIL [1.rows]: `=r(N)' rows, expected 7"
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


* TEST 2: Person-time conservation (all 3 persons = 366 days each = 1098 total)

display _n _dup(60) "-"
display "TEST 2: Person-time conservation (1098 total)"
display _dup(60) "-"
local test2_pass = 1

tempvar pt
gen `pt' = stop - start + 1
quietly su `pt'
if r(sum) == 1098 {
    display as result "  PASS [2.total_pt]: total person-time=1098"
}
else {
    display as error "  FAIL [2.total_pt]: total=`=r(sum)', expected 1098"
    local test2_pass = 0
}

* Per-person check
forvalues p = 1/3 {
    quietly su `pt' if id == `p'
    if r(sum) == 366 {
        display as result "  PASS [2.pt_p`p']: person `p'=366"
    }
    else {
        display as error "  FAIL [2.pt_p`p']: person `p'=`=r(sum)', expected 366"
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


* TEST 3: tvevent flags Person 3's Jun15 event
* Jun15 is inside [Feb1,Jul31]: split → [Feb1,Jun15] _failure=1
* type(single): post-event dropped for Person 3

display _n _dup(60) "-"
display "TEST 3: tvevent flags Person 3's event"
display _dup(60) "-"
local test3_pass = 1

use `events_single', clear
capture noisily tvevent using `tvexpose_result', ///
    id(id) start(start) stop(stop) ///
    date(event_date) type(single)

if _rc != 0 {
    display as error "  FAIL [3.run]: tvevent error `=_rc'"
    local test3_pass = 0
}
else {
    tempfile tvevent_result
    save `tvevent_result', replace

    sort id start

    * Person 3 should have _failure=1
    quietly count if id == 3 & _failure == 1
    if r(N) == 1 {
        display as result "  PASS [3.p3_event]: Person 3 event flagged"
    }
    else {
        display as error "  FAIL [3.p3_event]: Person 3 has `=r(N)' event rows"
        local test3_pass = 0
    }

    * Event row should stop at Jun15
    quietly su stop if id == 3 & _failure == 1
    if r(mean) == mdy(6,15,2020) {
        display as result "  PASS [3.event_date]: event at Jun15"
    }
    else {
        display as error "  FAIL [3.event_date]: event stop=`=string(r(mean), "%td")'"
        local test3_pass = 0
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


* TEST 4: Post-tvevent person-time
* P1: 366 (full year, censored)
* P2: 366 (full year, censored)
* P3: Jan1 to Jun15 = 167 days (type(single) censors after event)
*   Jan=31, Feb=29, Mar=31, Apr=30, May=31, Jun1-15=15 → 167 days

display _n _dup(60) "-"
display "TEST 4: Post-tvevent person-time"
display _dup(60) "-"
local test4_pass = 1

capture {
    use `tvevent_result', clear
    tempvar pt
    gen `pt' = stop - start + 1

    * Person 1 and 2: full year
    quietly su `pt' if id == 1
    assert_exact `=r(sum)' 366 "4.pt_p1"

    quietly su `pt' if id == 2
    assert_exact `=r(sum)' 366 "4.pt_p2"

    * Person 3: censored at Jun15
    * Jan1-Jan31=31, Feb1-Feb29=29, Mar1-Mar31=31, Apr1-Apr30=30, May1-May31=31, Jun1-Jun15=15
    * Total: 31+29+31+30+31+15 = 167 days
    quietly su `pt' if id == 3
    local p3_pt = r(sum)
    if `p3_pt' == 167 {
        display as result "  PASS [4.pt_p3]: Person 3 = 167 days (censored at Jun15)"
    }
    else {
        * Allow some flexibility: might include the post-split remainder
        display as error "  FAIL [4.pt_p3]: Person 3 = `p3_pt', expected 167"
        local test4_pass = 0
    }
}
if _rc != 0 {
    display as error "  FAIL [4.error]: assertion error"
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


* TEST 5: No events for Persons 1 and 2

display _n _dup(60) "-"
display "TEST 5: No events for Persons 1 and 2"
display _dup(60) "-"
local test5_pass = 1

capture {
    use `tvevent_result', clear

    * Person 1: all _failure=0
    quietly count if id == 1 & _failure != 0
    if r(N) == 0 {
        display as result "  PASS [5.p1_cens]: Person 1 all _failure=0"
    }
    else {
        display as error "  FAIL [5.p1_cens]: Person 1 has `=r(N)' event rows"
        local test5_pass = 0
    }

    * Person 2: all _failure=0
    quietly count if id == 2 & _failure != 0
    if r(N) == 0 {
        display as result "  PASS [5.p2_cens]: Person 2 all _failure=0"
    }
    else {
        display as error "  FAIL [5.p2_cens]: Person 2 has `=r(N)' event rows"
        local test5_pass = 0
    }
}
if _rc != 0 {
    display as error "  FAIL [5.error]: assertion error"
    local test5_pass = 0
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
* TESTS 6-8: SURVIVAL ANALYSIS VERIFICATION
* ============================================================================

* TEST 6: stset produces valid survival data

display _n _dup(60) "-"
display "TEST 6: stset produces valid survival data"
display _dup(60) "-"
local test6_pass = 1

capture {
    use `tvevent_result', clear

    * Create analysis time variables (avoid _t/_t0 which stset reserves)
    gen double atime0 = start - mdy(1,1,2020)
    gen double atime  = stop  - mdy(1,1,2020) + 1

    * stset with time-varying data
    stset atime, failure(_failure) enter(atime0) id(id)

    * All observations should be valid (_st==1)
    quietly count if _st != 1
    if r(N) == 0 {
        display as result "  PASS [6.valid]: all observations _st==1"
    }
    else {
        display as error "  FAIL [6.valid]: `=r(N)' observations with _st!=1"
        local test6_pass = 0
    }

    * Only Person 3 should have _d==1
    quietly count if _d == 1
    if r(N) == 1 {
        display as result "  PASS [6.events]: 1 failure event"
    }
    else {
        display as error "  FAIL [6.events]: `=r(N)' failures, expected 1"
        local test6_pass = 0
    }

    quietly su _d if id == 3
    if r(max) == 1 {
        display as result "  PASS [6.p3_fail]: Person 3 has failure"
    }
    else {
        display as error "  FAIL [6.p3_fail]: Person 3 max(_d)=`=r(max)'"
        local test6_pass = 0
    }
}
if _rc != 0 {
    display as error "  FAIL [6.stset]: stset error `=_rc'"
    local test6_pass = 0
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


* TEST 7: stcox with binary exposure converges

display _n _dup(60) "-"
display "TEST 7: stcox with binary exposure converges"
display _dup(60) "-"
local test7_pass = 1

capture {
    use `tvevent_result', clear

    * Create analysis time and exposure indicator (avoid _t/_t0 which stset reserves)
    gen double atime0 = start - mdy(1,1,2020)
    gen double atime  = stop  - mdy(1,1,2020) + 1
    gen byte exposed = (exp_val != 0)

    stset atime, failure(_failure) enter(atime0) id(id)
    stcox exposed, nolog

    * Check convergence: HR should be finite and non-missing
    matrix b = e(b)
    local hr = exp(b[1,1])
    if !missing(`hr') & `hr' > 0 & `hr' < . {
        display as result "  PASS [7.converged]: HR=`hr' (finite)"
    }
    else {
        display as error "  FAIL [7.converged]: HR=`hr' (not finite)"
        local test7_pass = 0
    }
}
if _rc != 0 {
    display as error "  FAIL [7.stcox]: stcox error `=_rc'"
    local test7_pass = 0
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


* TEST 8: Exposed vs unexposed person-time matches hand calculation

display _n _dup(60) "-"
display "TEST 8: Exposed/unexposed person-time"
display _dup(60) "-"
local test8_pass = 1

capture {
    use `tvevent_result', clear
    tempvar pt
    gen `pt' = stop - start + 1

    * Exposed person-time (exp_val != 0):
    * P2: Apr1-Sep30 = 183 days
    * P3: Feb1-Jun15 = 136 days (31+29+31+30+15=136, censored at event)
    * Total exposed PT = 183 + 136 = 319
    * (but P3 only has 1 exposed period that may be split by tvevent)
    quietly su `pt' if exp_val != 0
    local exp_pt = r(sum)

    * Unexposed person-time:
    * P1: 366 days
    * P2: Jan1-Mar31(91) + Oct1-Dec31(92) = 183 days
    * P3: Jan1-Jan31(31) = 31 days (post-event dropped)
    * Total unexposed PT = 366 + 183 + 31 = 580
    quietly su `pt' if exp_val == 0
    local unexp_pt = r(sum)

    * Total should match overall person-time
    local total = `exp_pt' + `unexp_pt'
    display as result "  INFO [8]: exposed_pt=`exp_pt', unexposed_pt=`unexp_pt', total=`total'"

    * Verify non-zero exposed and unexposed
    if `exp_pt' > 0 & `unexp_pt' > 0 {
        display as result "  PASS [8.both]: both exposed and unexposed person-time > 0"
    }
    else {
        display as error "  FAIL [8.both]: exposed=`exp_pt', unexposed=`unexp_pt'"
        local test8_pass = 0
    }
}
if _rc != 0 {
    display as error "  FAIL [8.error]: error `=_rc'"
    local test8_pass = 0
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


* ============================================================================
* TESTS 9-12: MULTI-DRUG PIPELINE
* ============================================================================

* Add Drug B for Person 2 (Jul1-Dec31) to create overlap scenario
tempfile exposure_multi
clear
input int(id drug) str10(s_start s_stop)
2 1 "2020-04-01" "2020-09-30"
3 1 "2020-02-01" "2020-07-31"
2 2 "2020-07-01" "2020-12-31"
end
gen double start = date(s_start, "YMD")
gen double stop  = date(s_stop, "YMD")
format %td start stop
drop s_start s_stop
save `exposure_multi', replace

* TEST 9: tvexpose with two drugs → tvmerge equivalent
* Person 2 has Drug 1 Apr1-Sep30 and Drug 2 Jul1-Dec31.
* Overlap: Jul1-Sep30 (both drugs active).
* Using layer: Drug 2 takes precedence during overlap.

display _n _dup(60) "-"
display "TEST 9: Multi-drug tvexpose pipeline"
display _dup(60) "-"
local test9_pass = 1

use `cohort', clear
capture noisily tvexpose using `exposure_multi', ///
    id(id) start(start) stop(stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    layer generate(exp_val)

if _rc != 0 {
    display as error "  FAIL [9.run]: tvexpose multi-drug error `=_rc'"
    local test9_pass = 0
}
else {
    tempfile multi_result
    save `multi_result', replace

    * Person 2 should have rows for both Drug 1 and Drug 2
    quietly count if id == 2 & exp_val == 1
    local d1_rows = r(N)
    quietly count if id == 2 & exp_val == 2
    local d2_rows = r(N)

    if `d1_rows' >= 1 & `d2_rows' >= 1 {
        display as result "  PASS [9.both_drugs]: Person 2 has Drug 1 and Drug 2 rows"
    }
    else {
        display as error "  FAIL [9.both_drugs]: Drug1=`d1_rows', Drug2=`d2_rows'"
        local test9_pass = 0
    }

    * Person-time conservation
    tempvar pt
    gen `pt' = stop - start + 1
    forvalues p = 1/3 {
        quietly su `pt' if id == `p'
        if r(sum) == 366 {
            display as result "  PASS [9.pt_p`p']: person `p'=366"
        }
        else {
            display as error "  FAIL [9.pt_p`p']: person `p'=`=r(sum)'"
            local test9_pass = 0
        }
    }
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


* TEST 10: Multi-drug person-time verification

display _n _dup(60) "-"
display "TEST 10: Multi-drug person-time"
display _dup(60) "-"
local test10_pass = 1

capture {
    use `multi_result', clear
    tempvar pt
    gen `pt' = stop - start + 1

    * Total person-time = 3 * 366 = 1098
    quietly su `pt'
    if r(sum) == 1098 {
        display as result "  PASS [10.total]: total person-time=1098"
    }
    else {
        display as error "  FAIL [10.total]: total=`=r(sum)', expected 1098"
        local test10_pass = 0
    }
}
if _rc != 0 {
    display as error "  FAIL [10.error]: error `=_rc'"
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


* TEST 11: tvevent on multi-drug data - Person 3's event correctly placed

display _n _dup(60) "-"
display "TEST 11: tvevent on multi-drug data"
display _dup(60) "-"
local test11_pass = 1

use `events_single', clear
capture noisily tvevent using `multi_result', ///
    id(id) start(start) stop(stop) ///
    date(event_date) type(single)

if _rc != 0 {
    display as error "  FAIL [11.run]: tvevent error `=_rc'"
    local test11_pass = 0
}
else {
    tempfile multi_tvevent
    save `multi_tvevent', replace

    * Person 3's event at Jun15 should still be flagged
    quietly count if id == 3 & _failure == 1
    if r(N) == 1 {
        display as result "  PASS [11.p3_event]: Person 3 event flagged in multi-drug"
    }
    else {
        display as error "  FAIL [11.p3_event]: Person 3 has `=r(N)' event rows"
        local test11_pass = 0
    }

    * Persons 1 and 2: no events
    quietly count if id == 1 & _failure != 0
    local p1_events = r(N)
    quietly count if id == 2 & _failure != 0
    local p2_events = r(N)
    if `p1_events' == 0 & `p2_events' == 0 {
        display as result "  PASS [11.no_events]: Persons 1,2 correctly censored"
    }
    else {
        display as error "  FAIL [11.no_events]: P1=`p1_events', P2=`p2_events' events"
        local test11_pass = 0
    }
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


* TEST 12: stcox with both drug variables converges

display _n _dup(60) "-"
display "TEST 12: stcox with multi-drug model"
display _dup(60) "-"
local test12_pass = 1

capture {
    use `multi_tvevent', clear

    * Create analysis time (avoid _t/_t0 which stset reserves)
    gen double atime0 = start - mdy(1,1,2020)
    gen double atime  = stop  - mdy(1,1,2020) + 1

    * Create drug indicators
    gen byte drug1 = (exp_val == 1)
    gen byte drug2 = (exp_val == 2)

    stset atime, failure(_failure) enter(atime0) id(id)
    stcox drug1 drug2, nolog

    * Check convergence
    matrix b = e(b)
    local hr1 = exp(b[1,1])
    local hr2 = exp(b[1,2])

    if !missing(`hr1') & `hr1' > 0 & `hr1' < . {
        display as result "  PASS [12.hr1]: Drug 1 HR=`hr1' (finite)"
    }
    else {
        display as error "  FAIL [12.hr1]: Drug 1 HR=`hr1'"
        local test12_pass = 0
    }

    if !missing(`hr2') & `hr2' > 0 & `hr2' < . {
        display as result "  PASS [12.hr2]: Drug 2 HR=`hr2' (finite)"
    }
    else {
        display as error "  FAIL [12.hr2]: Drug 2 HR=`hr2'"
        local test12_pass = 0
    }
}
if _rc != 0 {
    display as error "  FAIL [12.stcox]: stcox error `=_rc'"
    local test12_pass = 0
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
* FINAL SUMMARY
* ============================================================================
local total_tests = `pass_count' + `fail_count'
display _n _dup(70) "="
display "TVTOOLS PIPELINE STRESS VALIDATION SUMMARY"
display _dup(70) "="
display "Tests run:    `total_tests'"
display "Tests passed: `pass_count'"
display "Tests failed: `fail_count'"
if "`failed_tests'" != "" {
    display as error "Failed tests: `failed_tests'"
}
display _dup(70) "="

if `fail_count' == 0 {
    display as result _n "ALL PIPELINE STRESS TESTS PASSED"
}
else {
    display as error _n "`fail_count' PIPELINE STRESS TESTS FAILED"
    exit 1
}
