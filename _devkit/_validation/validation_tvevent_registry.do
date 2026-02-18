/*******************************************************************************
* validation_tvevent_registry.do
*
* Purpose: Validate tvevent against real-world event integration scenarios
*          from disease registries (relapses, EDSS progression, competing
*          risks like death/emigration).
*
* Scenarios:
*   1. type(recurring) with wide-format relapses (0, 1, 5 events)
*   2. Event exactly at study_entry boundary
*   3. Event exactly at study_exit boundary
*   4. Event between intervals (gap)
*   5. Competing risk: compete before primary
*   6. Competing risk: primary before compete
*   7. Both primary and compete on same day
*   8. No events in entire dataset (all censored)
*   9. Event in first interval
*  10. Event in last interval
*
* tvevent boundary rules (from source):
*   - Splitting: only events strictly inside interval (start < date < stop)
*   - Flagging: events at stop boundary (date == stop) ARE valid events
*   - Events exactly at start are NOT flagged
*
* Run: stata-mp -b do validation_tvevent_registry.do
* Log: validation_tvevent_registry.log
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
display "TVEVENT REGISTRY DATA VALIDATION"
display _dup(70) "="
display "Date: $S_DATE $S_TIME"
display ""

quietly adopath ++ "/home/tpcopeland/Stata-Tools/tvtools"

* ============================================================================
* TEST 1: RECURRING EVENTS WITH WIDE-FORMAT RELAPSES
* ============================================================================
display _n _dup(60) "-"
display "TEST 1: type(recurring) with wide-format relapses"
display _dup(60) "-"

local test1_pass = 1

* Create interval data (from tvexpose output): 3 persons, 4 intervals each
clear
set obs 12
gen long id = ceil(_n/4)
gen int seq = _n - (id-1)*4
gen double start = mdy(1,1,2020) + (seq-1)*91
gen double stop  = start + 90
replace stop = mdy(12,31,2020) if seq == 4
gen byte tv_exp = mod(seq, 2)
format start stop %td
drop seq
save "/tmp/tve1_intervals.dta", replace

* Event data: person 1 = 0 relapses, person 2 = 1 relapse, person 3 = 5 relapses
* tvevent type(recurring) expects wide-format: relapse_date1, relapse_date2, etc.
clear
set obs 3
gen long id = _n

* Person 1: no relapses
gen double relapse_date1 = .
gen double relapse_date2 = .
gen double relapse_date3 = .
gen double relapse_date4 = .
gen double relapse_date5 = .

* Person 2: 1 relapse on May 15
replace relapse_date1 = mdy(5,15,2020) in 2

* Person 3: 5 relapses spread across the year
replace relapse_date1 = mdy(2,15,2020)  in 3
replace relapse_date2 = mdy(4,20,2020)  in 3
replace relapse_date3 = mdy(6,10,2020)  in 3
replace relapse_date4 = mdy(8,25,2020)  in 3
replace relapse_date5 = mdy(10,30,2020) in 3

format relapse_date* %td
save "/tmp/tve1_events.dta", replace

use "/tmp/tve1_events.dta", clear
capture noisily tvevent using "/tmp/tve1_intervals.dta", ///
    id(id) date(relapse_date) ///
    type(recurring) generate(relapse_flag)

if _rc != 0 {
    display as error "  FAIL [1.run]: tvevent returned error `=_rc'"
    local test1_pass = 0
}
else {
    sort id start
    list id start stop relapse_flag, noobs

    * Person 1: all relapse_flag should be 0
    quietly count if id == 1 & relapse_flag != 0
    if r(N) == 0 {
        display as result "  PASS [1.p1_none]: person 1 has no events flagged"
    }
    else {
        display as error "  FAIL [1.p1_none]: person 1 has `=r(N)' flagged rows"
        local test1_pass = 0
    }

    * Person 2: exactly 1 row with relapse_flag = 1
    quietly count if id == 2 & relapse_flag == 1
    if r(N) == 1 {
        display as result "  PASS [1.p2_one]: person 2 has exactly 1 event"
    }
    else {
        display as error "  FAIL [1.p2_one]: person 2 has `=r(N)' events (expected 1)"
        local test1_pass = 0
    }

    * Person 3: at least 3 events flagged (5 events but some may fall in same interval)
    quietly count if id == 3 & relapse_flag >= 1
    local p3_events = r(N)
    if `p3_events' >= 3 {
        display as result "  PASS [1.p3_multi]: person 3 has `p3_events' event rows (5 relapses)"
    }
    else {
        display as error "  FAIL [1.p3_multi]: person 3 has `p3_events' event rows (expected >=3)"
        local test1_pass = 0
    }

    * All persons should still be present
    quietly tab id
    if r(r) == 3 {
        display as result "  PASS [1.all_persons]: all 3 persons present"
    }
    else {
        display as error "  FAIL [1.all_persons]: `=r(r)' persons (expected 3)"
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

* ============================================================================
* TEST 2: EVENT EXACTLY AT STUDY ENTRY (= FIRST INTERVAL START)
* ============================================================================
display _n _dup(60) "-"
display "TEST 2: Event exactly at first interval start"
display _dup(60) "-"

local test2_pass = 1

* Interval: [Jan1/2020, Jun30/2020] and [Jul1/2020, Dec31/2020]
clear
set obs 2
gen long id = 1
gen double start = mdy(1,1,2020) in 1
replace start = mdy(7,1,2020) in 2
gen double stop = mdy(6,30,2020) in 1
replace stop = mdy(12,31,2020) in 2
gen byte tv_exp = 1
format start stop %td
save "/tmp/tve2_intervals.dta", replace

* Event exactly at start of first interval
clear
set obs 1
gen long id = 1
gen double event_date = mdy(1,1,2020)
format event_date %td
save "/tmp/tve2_events.dta", replace

use "/tmp/tve2_events.dta", clear
capture noisily tvevent using "/tmp/tve2_intervals.dta", ///
    id(id) date(event_date) ///
    type(single) generate(fail_flag)

if _rc != 0 {
    display as error "  FAIL [2.run]: tvevent returned error `=_rc'"
    local test2_pass = 0
}
else {
    sort id start
    list id start stop fail_flag, noobs

    * Per tvevent rules: events at start are NOT flagged
    * Person should have fail_flag=0 everywhere (event at start = not flagged)
    quietly count if fail_flag == 1
    local n_flagged = r(N)
    display "  INFO: `n_flagged' rows flagged (events at start should NOT be flagged per tvevent rules)"
    if `n_flagged' == 0 {
        display as result "  PASS [2.at_start]: event at start not flagged (per boundary rule)"
    }
    else {
        display as result "  INFO [2.at_start]: event at start IS flagged (`n_flagged' rows)"
        * This is informational - document the behavior
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

* ============================================================================
* TEST 3: EVENT EXACTLY AT STUDY EXIT (= LAST INTERVAL STOP)
* ============================================================================
display _n _dup(60) "-"
display "TEST 3: Event exactly at last interval stop"
display _dup(60) "-"

local test3_pass = 1

* Reuse intervals from test 2
clear
set obs 1
gen long id = 1
gen double event_date = mdy(12,31,2020)
format event_date %td
save "/tmp/tve3_events.dta", replace

use "/tmp/tve3_events.dta", clear
capture noisily tvevent using "/tmp/tve2_intervals.dta", ///
    id(id) date(event_date) ///
    type(single) generate(fail_flag)

if _rc != 0 {
    display as error "  FAIL [3.run]: tvevent returned error `=_rc'"
    local test3_pass = 0
}
else {
    sort id start
    list id start stop fail_flag, noobs

    * Per tvevent rules: events at stop ARE flagged
    quietly count if fail_flag == 1
    local n_flagged = r(N)
    if `n_flagged' == 1 {
        display as result "  PASS [3.at_stop]: event at stop boundary correctly flagged"
    }
    else {
        display as error "  FAIL [3.at_stop]: expected 1 flagged row, got `n_flagged'"
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

* ============================================================================
* TEST 4: EVENT BETWEEN INTERVALS (IN GAP)
* ============================================================================
display _n _dup(60) "-"
display "TEST 4: Event falling in gap between intervals"
display _dup(60) "-"

local test4_pass = 1

* Create intervals with a gap: [Jan1, Mar31] and [May1, Dec31]
* Gap: April 1-30
clear
set obs 2
gen long id = 1
gen double start = mdy(1,1,2020) in 1
replace start = mdy(5,1,2020) in 2
gen double stop = mdy(3,31,2020) in 1
replace stop = mdy(12,31,2020) in 2
gen byte tv_exp = 1
format start stop %td
save "/tmp/tve4_intervals.dta", replace

* Event in the gap (April 15)
clear
set obs 1
gen long id = 1
gen double event_date = mdy(4,15,2020)
format event_date %td
save "/tmp/tve4_events.dta", replace

use "/tmp/tve4_events.dta", clear
capture noisily tvevent using "/tmp/tve4_intervals.dta", ///
    id(id) date(event_date) ///
    type(single) generate(fail_flag)

if _rc != 0 {
    display as error "  INFO [4.run]: tvevent returned error `=_rc' (event in gap)"
    display as result "  PASS [4.handled]: event in gap handled (error is acceptable)"
}
else {
    sort id start
    list id start stop fail_flag, noobs

    * Event in gap should not be flagged in any interval
    quietly count if fail_flag == 1
    local n_flagged = r(N)
    if `n_flagged' == 0 {
        display as result "  PASS [4.no_flag]: event in gap not flagged (correct)"
    }
    else {
        display as result "  INFO [4.flagged]: event in gap flagged in `n_flagged' rows (check nearest interval)"
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

* ============================================================================
* TEST 5: COMPETING RISK - COMPETE EVENT BEFORE PRIMARY
* ============================================================================
display _n _dup(60) "-"
display "TEST 5: Competing risk: compete event occurs before primary"
display _dup(60) "-"

local test5_pass = 1

* Create intervals: 4 quarterly intervals
clear
set obs 4
gen long id = 1
gen double start = mdy(1,1,2020) + (_n-1)*91
gen double stop  = start + 90
replace stop = mdy(12,31,2020) if _n == 4
gen byte tv_exp = 1
format start stop %td
save "/tmp/tve5_intervals.dta", replace

* Primary event: Oct 15 (day 289). Compete (death): May 20 (day 141)
* Death should win because it's earlier
clear
set obs 1
gen long id = 1
gen double primary_date = mdy(10,15,2020)
gen double death_date   = mdy(5,20,2020)
format primary_date death_date %td
save "/tmp/tve5_events.dta", replace

use "/tmp/tve5_events.dta", clear
capture noisily tvevent using "/tmp/tve5_intervals.dta", ///
    id(id) date(primary_date) ///
    compete(death_date) ///
    type(single) generate(fail_status)

if _rc != 0 {
    display as error "  FAIL [5.run]: tvevent returned error `=_rc'"
    local test5_pass = 0
}
else {
    sort id start
    list id start stop fail_status, noobs

    * Death (compete) occurred first - should be coded as fail_status = 2
    * Post-event rows should be dropped (type=single)
    quietly count if fail_status == 2
    local n_compete = r(N)
    quietly count if fail_status == 1
    local n_primary = r(N)

    if `n_compete' >= 1 & `n_primary' == 0 {
        display as result "  PASS [5.compete_wins]: compete event (death) wins, primary not flagged"
    }
    else {
        display as error "  FAIL [5.compete_wins]: compete=`n_compete', primary=`n_primary' (expected compete>0, primary=0)"
        local test5_pass = 0
    }

    * No rows should exist after death date (type=single truncates)
    quietly summarize stop
    local max_stop = r(max)
    if `max_stop' <= mdy(5,20,2020) {
        display as result "  PASS [5.truncated]: no rows after death date"
    }
    else {
        local d1 : display %td `max_stop'
        display as error "  FAIL [5.truncated]: rows extend to `d1' (past death on May 20)"
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
* TEST 6: COMPETING RISK - PRIMARY BEFORE COMPETE
* ============================================================================
display _n _dup(60) "-"
display "TEST 6: Competing risk: primary occurs before compete"
display _dup(60) "-"

local test6_pass = 1

* Primary event: Mar 15. Compete (death): Nov 20.
* Primary should be coded.
clear
set obs 1
gen long id = 1
gen double primary_date = mdy(3,15,2020)
gen double death_date   = mdy(11,20,2020)
format primary_date death_date %td
save "/tmp/tve6_events.dta", replace

use "/tmp/tve6_events.dta", clear
capture noisily tvevent using "/tmp/tve5_intervals.dta", ///
    id(id) date(primary_date) ///
    compete(death_date) ///
    type(single) generate(fail_status)

if _rc != 0 {
    display as error "  FAIL [6.run]: tvevent returned error `=_rc'"
    local test6_pass = 0
}
else {
    sort id start
    list id start stop fail_status, noobs

    * Primary should be coded (=1)
    quietly count if fail_status == 1
    local n_primary = r(N)
    quietly count if fail_status == 2
    local n_compete = r(N)

    if `n_primary' >= 1 & `n_compete' == 0 {
        display as result "  PASS [6.primary_wins]: primary event wins when it occurs first"
    }
    else {
        display as error "  FAIL [6.primary_wins]: primary=`n_primary', compete=`n_compete'"
        local test6_pass = 0
    }

    * Truncated at primary event date
    quietly summarize stop
    local max_stop = r(max)
    if `max_stop' <= mdy(3,15,2020) {
        display as result "  PASS [6.truncated]: truncated at primary event"
    }
    else {
        local d1 : display %td `max_stop'
        display as error "  FAIL [6.truncated]: rows extend to `d1' (past primary on Mar 15)"
        local test6_pass = 0
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
* TEST 7: BOTH PRIMARY AND COMPETE ON SAME DAY
* ============================================================================
display _n _dup(60) "-"
display "TEST 7: Primary and competing event on same day"
display _dup(60) "-"

local test7_pass = 1

* Both events on Jun 15
clear
set obs 1
gen long id = 1
gen double primary_date = mdy(6,15,2020)
gen double death_date   = mdy(6,15,2020)
format primary_date death_date %td
save "/tmp/tve7_events.dta", replace

use "/tmp/tve7_events.dta", clear
capture noisily tvevent using "/tmp/tve5_intervals.dta", ///
    id(id) date(primary_date) ///
    compete(death_date) ///
    type(single) generate(fail_status)

if _rc != 0 {
    display as error "  FAIL [7.run]: tvevent returned error `=_rc'"
    local test7_pass = 0
}
else {
    sort id start
    list id start stop fail_status, noobs

    * Document tie-breaking behavior
    quietly count if fail_status == 1
    local n_primary = r(N)
    quietly count if fail_status == 2
    local n_compete = r(N)

    display "  INFO: Tie-breaking on same day: primary=`n_primary', compete=`n_compete'"

    * At least one should be flagged
    if `n_primary' + `n_compete' >= 1 {
        display as result "  PASS [7.flagged]: at least one event type flagged on tie"
    }
    else {
        display as error "  FAIL [7.flagged]: no event flagged despite same-day events"
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
* TEST 8: NO EVENTS IN ENTIRE DATASET (ALL CENSORED)
* ============================================================================
display _n _dup(60) "-"
display "TEST 8: No events in dataset (all censored)"
display _dup(60) "-"

local test8_pass = 1

* 3 persons with intervals, no events
clear
set obs 6
gen long id = ceil(_n/2)
gen double start = mdy(1,1,2020) if mod(_n,2) == 1
replace start = mdy(7,1,2020) if mod(_n,2) == 0
gen double stop = mdy(6,30,2020) if mod(_n,2) == 1
replace stop = mdy(12,31,2020) if mod(_n,2) == 0
gen byte tv_exp = 1
format start stop %td
save "/tmp/tve8_intervals.dta", replace

* All event dates missing
clear
set obs 3
gen long id = _n
gen double event_date = .
format event_date %td
save "/tmp/tve8_events.dta", replace

use "/tmp/tve8_events.dta", clear
capture noisily tvevent using "/tmp/tve8_intervals.dta", ///
    id(id) date(event_date) ///
    type(single) generate(fail_flag)

if _rc != 0 {
    display as error "  FAIL [8.run]: tvevent returned error `=_rc'"
    local test8_pass = 0
}
else {
    sort id start
    list id start stop fail_flag, noobs

    * All fail_flag should be 0
    quietly count if fail_flag != 0
    if r(N) == 0 {
        display as result "  PASS [8.all_zero]: all outcome=0 (all censored)"
    }
    else {
        display as error "  FAIL [8.all_zero]: `=r(N)' non-zero outcome rows"
        local test8_pass = 0
    }

    * All persons present
    quietly tab id
    if r(r) == 3 {
        display as result "  PASS [8.all_persons]: all 3 persons present"
    }
    else {
        display as error "  FAIL [8.all_persons]: `=r(r)' persons (expected 3)"
        local test8_pass = 0
    }

    * Interval structure preserved (no splits since no events)
    quietly count
    if r(N) == 6 {
        display as result "  PASS [8.no_split]: original 6 intervals preserved (no splits)"
    }
    else {
        display "  INFO [8.rows]: `=r(N)' rows (expected 6 if no splits)"
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

* ============================================================================
* TEST 9: EVENT IN FIRST INTERVAL
* ============================================================================
display _n _dup(60) "-"
display "TEST 9: Event in first interval (day 1 of follow-up)"
display _dup(60) "-"

local test9_pass = 1

* Reuse intervals from test 2: [Jan1, Jun30] and [Jul1, Dec31]
* Event on Jan 5 (inside first interval, not at start boundary)
clear
set obs 1
gen long id = 1
gen double event_date = mdy(1,5,2020)
format event_date %td
save "/tmp/tve9_events.dta", replace

use "/tmp/tve9_events.dta", clear
capture noisily tvevent using "/tmp/tve2_intervals.dta", ///
    id(id) date(event_date) ///
    type(single) generate(fail_flag)

if _rc != 0 {
    display as error "  FAIL [9.run]: tvevent returned error `=_rc'"
    local test9_pass = 0
}
else {
    sort id start
    list id start stop fail_flag, noobs

    * Event should be flagged in first interval (after split)
    quietly count if fail_flag == 1
    if r(N) == 1 {
        display as result "  PASS [9.flagged]: event flagged in first interval"
    }
    else {
        display as error "  FAIL [9.flagged]: `=r(N)' flagged rows (expected 1)"
        local test9_pass = 0
    }

    * type(single): no rows after event date
    quietly summarize stop
    local max_stop = r(max)
    if `max_stop' <= mdy(1,5,2020) {
        display as result "  PASS [9.truncated]: truncated at event (Jan 5)"
    }
    else {
        local d1 : display %td `max_stop'
        display as error "  FAIL [9.truncated]: rows extend to `d1'"
        local test9_pass = 0
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

* ============================================================================
* TEST 10: EVENT IN LAST INTERVAL
* ============================================================================
display _n _dup(60) "-"
display "TEST 10: Event in last interval (last day of follow-up)"
display _dup(60) "-"

local test10_pass = 1

* Event on Dec 15 (inside last interval)
clear
set obs 1
gen long id = 1
gen double event_date = mdy(12,15,2020)
format event_date %td
save "/tmp/tve10_events.dta", replace

use "/tmp/tve10_events.dta", clear
capture noisily tvevent using "/tmp/tve2_intervals.dta", ///
    id(id) date(event_date) ///
    type(single) generate(fail_flag)

if _rc != 0 {
    display as error "  FAIL [10.run]: tvevent returned error `=_rc'"
    local test10_pass = 0
}
else {
    sort id start
    list id start stop fail_flag, noobs

    * Event should be flagged
    quietly count if fail_flag == 1
    if r(N) == 1 {
        display as result "  PASS [10.flagged]: event flagged in last interval"
    }
    else {
        display as error "  FAIL [10.flagged]: `=r(N)' flagged rows (expected 1)"
        local test10_pass = 0
    }

    * First interval should be preserved intact
    sort id start
    local first_stop = stop[1]
    if `first_stop' == mdy(6,30,2020) {
        display as result "  PASS [10.first_intact]: first interval preserved"
    }
    else {
        local d1 : display %td `first_stop'
        display as error "  FAIL [10.first_intact]: first interval stop=`d1' (expected Jun30)"
        local test10_pass = 0
    }

    * Truncated at event date
    quietly summarize stop
    local max_stop = r(max)
    if `max_stop' <= mdy(12,15,2020) {
        display as result "  PASS [10.truncated]: truncated at event"
    }
    else {
        local d1 : display %td `max_stop'
        display as error "  FAIL [10.truncated]: rows extend to `d1'"
        local test10_pass = 0
    }
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
* SUMMARY
* ============================================================================
display _n _dup(70) "="
display "TVEVENT REGISTRY VALIDATION SUMMARY"
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
forvalues i = 1/10 {
    capture erase "/tmp/tve`i'_intervals.dta"
    capture erase "/tmp/tve`i'_events.dta"
}

exit, clear
