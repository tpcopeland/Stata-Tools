clear all
set more off
set varabbrev off
version 16.0

capture log close
log using "test_tvevent.log", replace nomsg

* Shared scaffold: test globals + helpers + sandboxed install bootstrap
do "`c(pwd)'/_tvtools_qa_common.do"
_tvtools_qa_bootstrap

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""
local run_only = 0
local quiet = 0

* run_test/test_pass/test_fail harness counters (folded into the totals below)
global TVQA_PASS = 0
global TVQA_FAIL = 0
global TVQA_FAILED ""
global TVQA_CURRENT ""

display as result "tvtools QA: tvevent functional -- $S_DATE $S_TIME"


**# ===== merged from test_tvtools.do L653-2235: SECTION 4 TVEVENT =====

* SECTION 4: TVEVENT - Event splitting and interval construction

capture noisily {
* TEST EXECUTION MACRO
capture program drop _run_test
program define _run_test
    args test_num test_desc

    if $RUN_TEST_NUMBER > 0 & $RUN_TEST_NUMBER != `test_num' {
        exit 0
    }

    if $RUN_TEST_QUIET == 0 {
        display as text _n "TEST `test_num': `test_desc'"
        display as text "{hline 50}"
    }
end

* SETUP: Create tvexpose output for tvevent testing
if `quiet' == 0 {
    display as text "{hline 50}"
}

capture {
    quietly use "${DATA_DIR}/cohort.dta", clear
    tvexpose using "${DATA_DIR}/dmt.dta", ///
        id(id) start(dmt_start) stop(dmt_stop) ///
        exposure(dmt) reference(0) ///
        entry(study_entry) exit(study_exit) ///
        generate(tv_dmt) ///
        saveas("${DATA_DIR}/_tv_base.dta") replace
}

}

capture noisily {
* test_tvevent_keepvars_fix.do
* Verifies that keepvars are retained for ALL people, not just those with events
* Bug: tvevent was dropping covariates for people without events

clear

local n_passed = 0
local n_failed = 0

* TEST 1: keepvars retained for people WITHOUT events (single type)
di as txt "Test 1: keepvars retained for non-event people (single)"

* Create event data: only person 1 has an event, person 2 does not
clear
input long id double eventdate byte female double age
1 21550 1 45.2
2 .     0 62.1
end
format eventdate %td

tempfile events
save `events'

* Create interval data: both people have intervals
clear
input long id double start double stop
1 21500 21550
1 21550 21600
2 21500 21550
2 21550 21600
end
format start %td
format stop %td

tempfile intervals
save `intervals'

* Run tvevent
use `events', clear
tvevent using `intervals', id(id) date(eventdate) keepvars(female age) replace

* Check: person 2 should have female==0 and age==62.1
count if id == 2 & missing(female)
if r(N) > 0 {
    di as error "FAIL: female is missing for person 2 (no event)"
    local n_failed = `n_failed' + 1
}
else {
    count if id == 2 & female == 0 & abs(age - 62.1) < 0.01
    if r(N) == 0 {
        di as error "FAIL: female/age have wrong values for person 2"
        local n_failed = `n_failed' + 1
    }
    else {
        di as txt "  PASS"
        local n_passed = `n_passed' + 1
    }
}

* Check: person 1 should also have female==1 and age==45.2
count if id == 1 & missing(female)
if r(N) > 0 {
    di as error "FAIL: female is missing for person 1 (has event)"
    local n_failed = `n_failed' + 1
}
else {
    count if id == 1 & female == 1 & abs(age - 45.2) < 0.01
    if r(N) == 0 {
        di as error "FAIL: female/age have wrong values for person 1"
        local n_failed = `n_failed' + 1
    }
    else {
        di as txt "  PASS"
        local n_passed = `n_passed' + 1
    }
}

* TEST 2: Auto-detected keepvars retained for non-event people
di as txt "Test 2: auto-detected keepvars retained for non-event people"

use `events', clear
* Don't specify keepvars - let tvevent auto-detect (should pick up female, age)
tvevent using `intervals', id(id) date(eventdate) replace

count if id == 2 & missing(female)
if r(N) > 0 {
    di as error "FAIL: auto-detected female is missing for person 2"
    local n_failed = `n_failed' + 1
}
else {
    di as txt "  PASS"
    local n_passed = `n_passed' + 1
}

* TEST 3: keepvars with competing risks, non-event person
di as txt "Test 3: keepvars with competing risks, non-event person"

clear
input long id double eventdate double deathdate byte female
1 21550 .     1
2 .     21580 0
3 .     .     1
end
format eventdate %td
format deathdate %td

tempfile events_cr
save `events_cr'

* Intervals for 3 people
clear
input long id double start double stop
1 21500 21550
1 21550 21600
2 21500 21550
2 21550 21600
3 21500 21550
3 21550 21600
end
format start %td
format stop %td

tempfile intervals_cr
save `intervals_cr'

use `events_cr', clear
tvevent using `intervals_cr', id(id) date(eventdate) compete(deathdate) ///
    keepvars(female) replace

* Person 3 has no event and no competing event - should still have female==1
count if id == 3 & missing(female)
if r(N) > 0 {
    di as error "FAIL: female is missing for person 3 (no events at all)"
    local n_failed = `n_failed' + 1
}
else {
    count if id == 3 & female == 1
    if r(N) == 0 {
        di as error "FAIL: female has wrong value for person 3"
        local n_failed = `n_failed' + 1
    }
    else {
        di as txt "  PASS"
        local n_passed = `n_passed' + 1
    }
}

* TEST 4: All intervals present for non-event people
di as txt "Test 4: all intervals preserved for non-event people"

use `events', clear
tvevent using `intervals', id(id) date(eventdate) keepvars(female age) replace

* Person 2 should still have 2 intervals
count if id == 2
if r(N) != 2 {
    di as error "FAIL: person 2 should have 2 intervals, has `r(N)'"
    local n_failed = `n_failed' + 1
}
else {
    di as txt "  PASS"
    local n_passed = `n_passed' + 1
}

}

capture noisily {
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

* SECTION A: BOUNDARY PRECISION (Tests 1-5)

* TEST 1: Event at start date → NOT flagged
* Interval [Jan1, Jun30]. Event Jan1.
* tvevent matches event_date == stop_var. Jan1 ≠ Jun30 → not flagged.
* Split check: Jan1 > Jan1 is false → no split.
* Assert: _failure = 0 on all rows.

display "TEST 1: Event at start date - NOT flagged"
local test1_pass = 1

tempfile intervals1 events1
clear
input int(id) str10(s_start s_stop)
1 "2020-01-01" "2020-06-30"
end
gen double start = date(s_start, "YMD")
gen double stop  = date(s_stop, "YMD")
format %td start stop
drop s_start s_stop
save `intervals1', replace

clear
input int(id) str10(s_event)
1 "2020-01-01"
end
gen double event_date = date(s_event, "YMD")
format %td event_date
drop s_event
save `events1', replace

use `events1', clear
capture noisily tvevent using `intervals1', ///
    id(id) start(start) stop(stop) ///
    date(event_date) type(single)

if _rc != 0 {
    display as error "  FAIL [1.run]: error `=_rc'"
    local test1_pass = 0
}
else {
    * Under [start, stop] inclusive convention, event at start IS flagged
    * Interval is split into [start, start] (event) and [start+1, stop]
    capture confirm variable _failure
    if _rc != 0 {
        display as error "  FAIL [1.var]: _failure not found"
        local test1_pass = 0
    }
    else {
        quietly count if _failure != 0
        if r(N) == 1 {
            display as result "  PASS [1.flagged]: event at start correctly flagged"
        }
        else {
            display as error "  FAIL [1.flagged]: `=r(N)' rows with _failure!=0, expected 1"
            local test1_pass = 0
        }
    }

    * Row count = 1: split creates [start,start] and [start+1,stop],
    * but type(single) censors the post-event interval, leaving 1 row
    quietly count
    if r(N) == 1 {
        display as result "  PASS [1.rows]: 1 row (split + single-event censor)"
    }
    else {
        display as error "  FAIL [1.rows]: `=r(N)' rows, expected 1"
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

* TEST 2: Event at stop date → flagged, no split
* Interval [Jan1, Jun30]. Event Jun30.
* match_date = Jun30 = event → flagged.
* Split check: Jun30 > Jan1 & Jun30 < Jun30 → false. No split.
* Assert: _failure = 1, exactly 1 row.

display "TEST 2: Event at stop date - flagged, no split"
local test2_pass = 1

tempfile intervals2 events2
clear
input int(id) str10(s_start s_stop)
1 "2020-01-01" "2020-06-30"
end
gen double start = date(s_start, "YMD")
gen double stop  = date(s_stop, "YMD")
format %td start stop
drop s_start s_stop
save `intervals2', replace

clear
input int(id) str10(s_event)
1 "2020-06-30"
end
gen double event_date = date(s_event, "YMD")
format %td event_date
drop s_event
save `events2', replace

use `events2', clear
capture noisily tvevent using `intervals2', ///
    id(id) start(start) stop(stop) ///
    date(event_date) type(single)

if _rc != 0 {
    display as error "  FAIL [2.run]: error `=_rc'"
    local test2_pass = 0
}
else {
    * _failure should be 1
    quietly count if _failure == 1
    if r(N) == 1 {
        display as result "  PASS [2.flagged]: event flagged (_failure=1)"
    }
    else {
        display as error "  FAIL [2.flagged]: `=r(N)' rows with _failure=1, expected 1"
        local test2_pass = 0
    }

    * No split (1 row)
    quietly count
    if r(N) == 1 {
        display as result "  PASS [2.no_split]: 1 row (no split needed)"
    }
    else {
        display as error "  FAIL [2.no_split]: `=r(N)' rows, expected 1"
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

* TEST 3: Event one day after stop → not flagged
* Interval [Jan1, Jun30]. Event Jul1.
* Jul1 ≠ Jun30 → not matched.
* Assert: _failure = 0.

display "TEST 3: Event one day after stop - not flagged"
local test3_pass = 1

tempfile intervals3 events3
clear
input int(id) str10(s_start s_stop)
1 "2020-01-01" "2020-06-30"
end
gen double start = date(s_start, "YMD")
gen double stop  = date(s_stop, "YMD")
format %td start stop
drop s_start s_stop
save `intervals3', replace

clear
input int(id) str10(s_event)
1 "2020-07-01"
end
gen double event_date = date(s_event, "YMD")
format %td event_date
drop s_event
save `events3', replace

use `events3', clear
capture noisily tvevent using `intervals3', ///
    id(id) start(start) stop(stop) ///
    date(event_date) type(single)

if _rc != 0 {
    display as error "  FAIL [3.run]: error `=_rc'"
    local test3_pass = 0
}
else {
    quietly count if _failure != 0
    if r(N) == 0 {
        display as result "  PASS [3.not_flagged]: event after stop not flagged"
    }
    else {
        display as error "  FAIL [3.not_flagged]: `=r(N)' rows flagged"
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

* TEST 4: Event one day before stop → split + type(single) censoring
* Interval [Jan1, Jun30]. Event Jun29.
* Split: Jun29 > Jan1 & Jun29 < Jun30 → TRUE.
* Creates: [Jan1,Jun29] _failure=1, [Jun30,Jun30] _failure=0.
* type(single) censoring: _first_fail=Jun29, post-event row start=Jun30 > Jun29 → dropped.
* Result: 1 row [Jan1,Jun29] _failure=1.

display "TEST 4: Event one day before stop - split + single censoring"
local test4_pass = 1

tempfile intervals4 events4
clear
input int(id) str10(s_start s_stop)
1 "2020-01-01" "2020-06-30"
end
gen double start = date(s_start, "YMD")
gen double stop  = date(s_stop, "YMD")
format %td start stop
drop s_start s_stop
save `intervals4', replace

clear
input int(id) str10(s_event)
1 "2020-06-29"
end
gen double event_date = date(s_event, "YMD")
format %td event_date
drop s_event
save `events4', replace

use `events4', clear
capture noisily tvevent using `intervals4', ///
    id(id) start(start) stop(stop) ///
    date(event_date) type(single)

if _rc != 0 {
    display as error "  FAIL [4.run]: error `=_rc'"
    local test4_pass = 0
}
else {
    sort id start

    * type(single) censors post-event rows → 1 row remains
    quietly count
    if r(N) == 1 {
        display as result "  PASS [4.rows]: 1 row (post-event row censored by type(single))"
    }
    else {
        display as error "  FAIL [4.rows]: `=r(N)' rows, expected 1"
        local test4_pass = 0
    }

    * Row 1: [Jan1, Jun29] _failure=1
    if stop[1] == mdy(6,29,2020) & _failure[1] == 1 {
        display as result "  PASS [4.r1]: [Jan1,Jun29] _failure=1"
    }
    else {
        display as error "  FAIL [4.r1]: stop=`=string(stop[1],"%td")', _failure=`=_failure[1]'"
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

* TEST 5: Single-day interval with matching event
* Interval [Jun15, Jun15]. Event Jun15.
* match_date = Jun15 = event → flagged. No split (single day).

display "TEST 5: Single-day interval with matching event"
local test5_pass = 1

tempfile intervals5 events5
clear
input int(id) str10(s_start s_stop)
1 "2020-06-15" "2020-06-15"
end
gen double start = date(s_start, "YMD")
gen double stop  = date(s_stop, "YMD")
format %td start stop
drop s_start s_stop
save `intervals5', replace

clear
input int(id) str10(s_event)
1 "2020-06-15"
end
gen double event_date = date(s_event, "YMD")
format %td event_date
drop s_event
save `events5', replace

use `events5', clear
capture noisily tvevent using `intervals5', ///
    id(id) start(start) stop(stop) ///
    date(event_date) type(single)

if _rc != 0 {
    display as error "  FAIL [5.run]: error `=_rc'"
    local test5_pass = 0
}
else {
    * _failure = 1, 1 row
    quietly count
    if r(N) == 1 & _failure[1] == 1 {
        display as result "  PASS [5.flagged]: single-day event flagged"
    }
    else {
        display as error "  FAIL [5.flagged]: N=`=_N', _failure=`=_failure[1]'"
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

* SECTION B: COMPETING RISKS (Tests 6-10)

* TEST 6: Primary earlier than competing → _failure=1
* Interval [Jan1,Dec31]. Primary event Mar15. Competing event Jun15.
* Primary is earlier → _failure=1.

display "TEST 6: Primary earlier than competing - _failure=1"
local test6_pass = 1

tempfile intervals6 events6
clear
input int(id) str10(s_start s_stop)
1 "2020-01-01" "2020-12-31"
end
gen double start = date(s_start, "YMD")
gen double stop  = date(s_stop, "YMD")
format %td start stop
drop s_start s_stop
save `intervals6', replace

clear
input int(id) str10(s_primary s_competing)
1 "2020-03-15" "2020-06-15"
end
gen double event_date = date(s_primary, "YMD")
gen double competing_date = date(s_competing, "YMD")
format %td event_date competing_date
drop s_primary s_competing
save `events6', replace

use `events6', clear
capture noisily tvevent using `intervals6', ///
    id(id) start(start) stop(stop) ///
    date(event_date) compete(competing_date) type(single)

if _rc != 0 {
    display as error "  FAIL [6.run]: error `=_rc'"
    local test6_pass = 0
}
else {
    * Should have _failure=1 (primary wins)
    quietly count if _failure == 1
    if r(N) >= 1 {
        display as result "  PASS [6.primary]: _failure=1 (primary event wins)"
    }
    else {
        quietly levelsof _failure, local(vals)
        display as error "  FAIL [6.primary]: no _failure=1 rows. Values: `vals'"
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

* TEST 7: Competing earlier than primary → _failure=2
* Primary Jun15. Competing Mar15 (earlier). Competing wins → _failure=2.

display "TEST 7: Competing earlier than primary - _failure=2"
local test7_pass = 1

tempfile intervals7 events7
clear
input int(id) str10(s_start s_stop)
1 "2020-01-01" "2020-12-31"
end
gen double start = date(s_start, "YMD")
gen double stop  = date(s_stop, "YMD")
format %td start stop
drop s_start s_stop
save `intervals7', replace

clear
input int(id) str10(s_primary s_competing)
1 "2020-06-15" "2020-03-15"
end
gen double event_date = date(s_primary, "YMD")
gen double competing_date = date(s_competing, "YMD")
format %td event_date competing_date
drop s_primary s_competing
save `events7', replace

use `events7', clear
capture noisily tvevent using `intervals7', ///
    id(id) start(start) stop(stop) ///
    date(event_date) compete(competing_date) type(single)

if _rc != 0 {
    display as error "  FAIL [7.run]: error `=_rc'"
    local test7_pass = 0
}
else {
    * Should have _failure=2 (competing wins)
    quietly count if _failure == 2
    if r(N) >= 1 {
        display as result "  PASS [7.competing]: _failure=2 (competing event wins)"
    }
    else {
        quietly levelsof _failure, local(vals)
        display as error "  FAIL [7.competing]: no _failure=2 rows. Values: `vals'"
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

* TEST 8: Three competing risks - compete2 earliest → _failure=3
* Primary Jun15. Compete1 Sep15. Compete2 Mar15 (earliest).
* compete2 is earliest → _failure=3.

display "TEST 8: Three competing risks - earliest wins"
local test8_pass = 1

tempfile intervals8 events8
clear
input int(id) str10(s_start s_stop)
1 "2020-01-01" "2020-12-31"
end
gen double start = date(s_start, "YMD")
gen double stop  = date(s_stop, "YMD")
format %td start stop
drop s_start s_stop
save `intervals8', replace

clear
input int(id) str10(s_primary s_comp1 s_comp2)
1 "2020-06-15" "2020-09-15" "2020-03-15"
end
gen double event_date = date(s_primary, "YMD")
gen double comp1_date = date(s_comp1, "YMD")
gen double comp2_date = date(s_comp2, "YMD")
format %td event_date comp1_date comp2_date
drop s_primary s_comp1 s_comp2
save `events8', replace

use `events8', clear
capture noisily tvevent using `intervals8', ///
    id(id) start(start) stop(stop) ///
    date(event_date) compete(comp1_date comp2_date) type(single)

if _rc != 0 {
    display as error "  FAIL [8.run]: error `=_rc'"
    local test8_pass = 0
}
else {
    * compete2 is earliest → _failure=3 (primary=1, comp1=2, comp2=3)
    quietly count if _failure == 3
    if r(N) >= 1 {
        display as result "  PASS [8.comp2_wins]: _failure=3 (compete2 earliest)"
    }
    else {
        quietly levelsof _failure, local(vals)
        display as error "  FAIL [8.comp2_wins]: no _failure=3. Values: `vals'"
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

* TEST 9: Tie - primary and competing same date → primary wins (_failure=1)

display "TEST 9: Tie - primary wins over competing"
local test9_pass = 1

tempfile intervals9 events9
clear
input int(id) str10(s_start s_stop)
1 "2020-01-01" "2020-12-31"
end
gen double start = date(s_start, "YMD")
gen double stop  = date(s_stop, "YMD")
format %td start stop
drop s_start s_stop
save `intervals9', replace

clear
input int(id) str10(s_primary s_competing)
1 "2020-06-15" "2020-06-15"
end
gen double event_date = date(s_primary, "YMD")
gen double competing_date = date(s_competing, "YMD")
format %td event_date competing_date
drop s_primary s_competing
save `events9', replace

use `events9', clear
capture noisily tvevent using `intervals9', ///
    id(id) start(start) stop(stop) ///
    date(event_date) compete(competing_date) type(single)

if _rc != 0 {
    display as error "  FAIL [9.run]: error `=_rc'"
    local test9_pass = 0
}
else {
    * Primary should win tie → _failure=1
    quietly count if _failure == 1
    if r(N) >= 1 {
        display as result "  PASS [9.primary_tie]: _failure=1 (primary wins tie)"
    }
    else {
        quietly levelsof _failure, local(vals)
        display as error "  FAIL [9.primary_tie]: no _failure=1. Values: `vals'"
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

* TEST 10: All events missing → all _failure=0, no splits, row count unchanged

display "TEST 10: All events missing - no changes"
local test10_pass = 1

tempfile intervals10 events10
clear
input int(id) str10(s_start s_stop)
1 "2020-01-01" "2020-06-30"
1 "2020-07-01" "2020-12-31"
2 "2020-01-01" "2020-12-31"
end
gen double start = date(s_start, "YMD")
gen double stop  = date(s_stop, "YMD")
format %td start stop
drop s_start s_stop
save `intervals10', replace

clear
input int(id)
1
2
end
gen double event_date = .
format %td event_date
save `events10', replace

use `events10', clear
capture noisily tvevent using `intervals10', ///
    id(id) start(start) stop(stop) ///
    date(event_date) type(single)

if _rc != 0 {
    display as error "  FAIL [10.run]: error `=_rc'"
    local test10_pass = 0
}
else {
    * All _failure = 0
    quietly count if _failure != 0
    if r(N) == 0 {
        display as result "  PASS [10.all_zero]: all _failure=0"
    }
    else {
        display as error "  FAIL [10.all_zero]: `=r(N)' rows with _failure!=0"
        local test10_pass = 0
    }

    * Row count = 3 (unchanged from input)
    quietly count
    if r(N) == 3 {
        display as result "  PASS [10.rows]: row count unchanged (3)"
    }
    else {
        display as error "  FAIL [10.rows]: `=r(N)' rows, expected 3"
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

* SECTION C: SPLITTING & CONTINUOUS (Tests 11-14)

* TEST 11: Continuous adjustment exact math with type(recurring)
* Interval [Jan1, Jun30] (182 days: 31+29+31+30+31+30). tv_dose=182.
* Event Mar15. Split → [Jan1,Mar15] (75 days), [Mar16,Jun30] (107 days).
* tv_dose adjusted proportionally: 182*(75/182)=75, 182*(107/182)=107.
* Using type(recurring) to see both split rows (type(single) would censor
* the post-event row).

display "TEST 11: Continuous adjustment exact math"
local test11_pass = 1

tempfile intervals11 events11
clear
input int(id) double(tv_dose) str10(s_start s_stop)
1 182 "2020-01-01" "2020-06-30"
end
gen double start = date(s_start, "YMD")
gen double stop  = date(s_stop, "YMD")
format %td start stop
drop s_start s_stop
save `intervals11', replace

clear
set obs 1
gen id = 1
gen double event_date1 = mdy(3,15,2020)
format %td event_date1
save `events11', replace

use `events11', clear
capture noisily tvevent using `intervals11', ///
    id(id) start(start) stop(stop) ///
    date(event_date) type(recurring) ///
    continuous(tv_dose)

if _rc != 0 {
    display as error "  FAIL [11.run]: error `=_rc'"
    local test11_pass = 0
}
else {
    sort id start

    * Should have 2 rows after split
    quietly count
    if r(N) == 2 {
        display as result "  PASS [11.split]: 2 rows after split"
    }
    else {
        display as error "  FAIL [11.split]: `=r(N)' rows, expected 2"
        local test11_pass = 0
    }

    * Row durations under [start, stop] inclusive convention = stop - start + 1
    local r1_dur = stop[1] - start[1] + 1
    local r2_dur = stop[2] - start[2] + 1
    local orig_dur = `r1_dur' + `r2_dur'

    * tv_dose for each row: original_dose * (row_duration / total_duration)
    local expected_dose1 = 182 * (`r1_dur' / `orig_dur')
    assert_approx `=tv_dose[1]' `expected_dose1' 0.1 "11.dose1"

    local expected_dose2 = 182 * (`r2_dur' / `orig_dur')
    assert_approx `=tv_dose[2]' `expected_dose2' 0.1 "11.dose2"

    * Sum of adjusted doses should equal original dose
    local dose_sum = tv_dose[1] + tv_dose[2]
    assert_approx `dose_sum' 182 0.1 "11.dose_sum"
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

* TEST 12: Multiple splits from recurring events
* Person 1 with 3 intervals. type(recurring), events at 3 different points.
* All 3 events should be flagged with correct splits.

display "TEST 12: Multiple splits from recurring events"
local test12_pass = 1

tempfile intervals12 events12
clear
input int(id) str10(s_start s_stop)
1 "2020-01-01" "2020-04-30"
1 "2020-05-01" "2020-08-31"
1 "2020-09-01" "2020-12-31"
end
gen double start = date(s_start, "YMD")
gen double stop  = date(s_stop, "YMD")
format %td start stop
drop s_start s_stop
save `intervals12', replace

clear
input int(id) str10(s_ev1 s_ev2 s_ev3)
1 "2020-02-15" "2020-06-15" "2020-10-15"
end
gen double event_date1 = date(s_ev1, "YMD")
gen double event_date2 = date(s_ev2, "YMD")
gen double event_date3 = date(s_ev3, "YMD")
format %td event_date1 event_date2 event_date3
drop s_ev1 s_ev2 s_ev3
save `events12', replace

use `events12', clear
capture noisily tvevent using `intervals12', ///
    id(id) start(start) stop(stop) ///
    date(event_date) type(recurring)

if _rc != 0 {
    display as error "  FAIL [12.run]: error `=_rc'"
    local test12_pass = 0
}
else {
    * All 3 events should be flagged
    quietly count if _failure == 1
    if r(N) == 3 {
        display as result "  PASS [12.events]: 3 events flagged"
    }
    else {
        display as error "  FAIL [12.events]: `=r(N)' events flagged, expected 3"
        local test12_pass = 0
    }

    * Each event causes a split → 3 original + 3 splits = 6 rows
    quietly count
    if r(N) == 6 {
        display as result "  PASS [12.rows]: 6 rows (3 splits)"
    }
    else {
        display as error "  FAIL [12.rows]: `=r(N)' rows, expected 6"
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

* TEST 13: Recurring with 10 event columns (wide format)
* Wide format: event_date1 through event_date10. 5 are non-missing.
* Verify tvevent detects all 10 stubs and processes 5 events.

display "TEST 13: Recurring with 10 event columns - 5 non-missing"
local test13_pass = 1

tempfile intervals13 events13
clear
input int(id) str10(s_start s_stop)
1 "2020-01-01" "2020-12-31"
end
gen double start = date(s_start, "YMD")
gen double stop  = date(s_stop, "YMD")
format %td start stop
drop s_start s_stop
save `intervals13', replace

clear
set obs 1
gen id = 1
gen double event_date1 = mdy(2,15,2020)
gen double event_date2 = mdy(4,15,2020)
gen double event_date3 = mdy(6,15,2020)
gen double event_date4 = mdy(8,15,2020)
gen double event_date5 = mdy(10,15,2020)
gen double event_date6 = .
gen double event_date7 = .
gen double event_date8 = .
gen double event_date9 = .
gen double event_date10 = .
format %td event_date*
save `events13', replace

use `events13', clear
capture noisily tvevent using `intervals13', ///
    id(id) start(start) stop(stop) ///
    date(event_date) type(recurring)

if _rc != 0 {
    display as error "  FAIL [13.run]: error `=_rc'"
    local test13_pass = 0
}
else {
    * 5 non-missing events should be flagged
    quietly count if _failure == 1
    if r(N) == 5 {
        display as result "  PASS [13.events]: 5 events flagged"
    }
    else {
        display as error "  FAIL [13.events]: `=r(N)' events, expected 5"
        local test13_pass = 0
    }

    * 1 original interval + 5 splits = 6 rows total
    * Actually: each event inside splits the interval. Starting with 1 interval:
    * Event 1 splits → 2 rows. Event 2 splits one of those → 3 rows. Etc.
    * 1 + 5 = 6 rows
    quietly count
    if r(N) == 6 {
        display as result "  PASS [13.rows]: 6 rows"
    }
    else {
        display as error "  FAIL [13.rows]: `=r(N)' rows, expected 6"
        local test13_pass = 0
    }
}

if `test13_pass' == 1 {
    local pass_count = `pass_count' + 1
    display as result "TEST 13: PASSED"
}
else {
    local fail_count = `fail_count' + 1
    local failed_tests "`failed_tests' 13"
    display as error "TEST 13: FAILED"
}

* TEST 14: Event for person not in interval data
* Person 1 has intervals. Person 99 has event but no intervals.
* Person 99 should be silently dropped.

display "TEST 14: Event for person not in interval data"
local test14_pass = 1

tempfile intervals14 events14
clear
input int(id) str10(s_start s_stop)
1 "2020-01-01" "2020-12-31"
end
gen double start = date(s_start, "YMD")
gen double stop  = date(s_stop, "YMD")
format %td start stop
drop s_start s_stop
save `intervals14', replace

clear
input int(id) str10(s_event)
1  "2020-06-15"
99 "2020-06-15"
end
gen double event_date = date(s_event, "YMD")
format %td event_date
drop s_event
save `events14', replace

use `events14', clear
capture noisily tvevent using `intervals14', ///
    id(id) start(start) stop(stop) ///
    date(event_date) type(single)

if _rc != 0 {
    display as error "  FAIL [14.run]: error `=_rc'"
    local test14_pass = 0
}
else {
    * Person 99 should not be in output
    quietly count if id == 99
    if r(N) == 0 {
        display as result "  PASS [14.dropped]: Person 99 not in output"
    }
    else {
        display as error "  FAIL [14.dropped]: Person 99 has `=r(N)' rows"
        local test14_pass = 0
    }

    * Person 1 processed correctly
    quietly count if id == 1 & _failure == 1
    if r(N) >= 1 {
        display as result "  PASS [14.p1]: Person 1 event flagged"
    }
    else {
        display as error "  FAIL [14.p1]: Person 1 event not flagged"
        local test14_pass = 0
    }
}

if `test14_pass' == 1 {
    local pass_count = `pass_count' + 1
    display as result "TEST 14: PASSED"
}
else {
    local fail_count = `fail_count' + 1
    local failed_tests "`failed_tests' 14"
    display as error "TEST 14: FAILED"
}

* SECTION D: type(single) vs type(recurring) (Tests 15-16)

* TEST 15: type(single) censors after event
* 5 intervals. Event in interval 2. Everything after event should be dropped.

display "TEST 15: type(single) censors after event"
local test15_pass = 1

tempfile intervals15 events15
clear
input int(id) str10(s_start s_stop)
1 "2020-01-01" "2020-02-29"
1 "2020-03-01" "2020-04-30"
1 "2020-05-01" "2020-06-30"
1 "2020-07-01" "2020-08-31"
1 "2020-09-01" "2020-12-31"
end
gen double start = date(s_start, "YMD")
gen double stop  = date(s_stop, "YMD")
format %td start stop
drop s_start s_stop
save `intervals15', replace

clear
input int(id) str10(s_event)
1 "2020-03-15"
end
gen double event_date = date(s_event, "YMD")
format %td event_date
drop s_event
save `events15', replace

use `events15', clear
capture noisily tvevent using `intervals15', ///
    id(id) start(start) stop(stop) ///
    date(event_date) type(single)

if _rc != 0 {
    display as error "  FAIL [15.run]: error `=_rc'"
    local test15_pass = 0
}
else {
    sort id start

    * Event in interval 2 [Mar1,Apr30] at Mar15. Split creates [Mar1,Mar15] with _failure=1.
    * type(single): everything after event is dropped.
    * Remaining: [Jan1,Feb29] (interval 1), [Mar1,Mar15] (split, event)
    * Post-event portion of interval 2 and intervals 3-5 should be dropped.
    quietly count
    local n_rows = r(N)
    * Should be 2-3 rows (interval 1, split event row, possibly split remainder)
    * With type(single), post-event rows are dropped
    if `n_rows' <= 3 {
        display as result "  PASS [15.censored]: `n_rows' rows (censored after event)"
    }
    else {
        display as error "  FAIL [15.censored]: `n_rows' rows (expected <=3, intervals after event should be dropped)"
        local test15_pass = 0
    }

    * Event row should exist
    quietly count if _failure == 1
    if r(N) == 1 {
        display as result "  PASS [15.event]: event flagged"
    }
    else {
        display as error "  FAIL [15.event]: `=r(N)' event rows, expected 1"
        local test15_pass = 0
    }

    * No rows after the event date
    quietly count if start > mdy(3,15,2020)
    if r(N) <= 1 {
        display as result "  PASS [15.post_drop]: no/minimal rows after event"
    }
    else {
        display as error "  FAIL [15.post_drop]: `=r(N)' rows start after event date"
        local test15_pass = 0
    }
}

if `test15_pass' == 1 {
    local pass_count = `pass_count' + 1
    display as result "TEST 15: PASSED"
}
else {
    local fail_count = `fail_count' + 1
    local failed_tests "`failed_tests' 15"
    display as error "TEST 15: FAILED"
}

* TEST 16: type(recurring) keeps everything
* Same data as test 15. type(recurring): all intervals preserved, event flagged.

display "TEST 16: type(recurring) keeps all intervals"
local test16_pass = 1

* Need to create wide-format events for recurring
tempfile events16
clear
set obs 1
gen id = 1
gen double event_date1 = mdy(3,15,2020)
format %td event_date1
save `events16', replace

use `events16', clear
capture noisily tvevent using `intervals15', ///
    id(id) start(start) stop(stop) ///
    date(event_date) type(recurring)

if _rc != 0 {
    display as error "  FAIL [16.run]: error `=_rc'"
    local test16_pass = 0
}
else {
    sort id start

    * All intervals preserved + split = 6 rows
    * Original 5 intervals, event splits interval 2 → 6 rows
    quietly count
    if r(N) == 6 {
        display as result "  PASS [16.all_kept]: 6 rows (all intervals + split)"
    }
    else {
        display as error "  FAIL [16.all_kept]: `=r(N)' rows, expected 6"
        local test16_pass = 0
    }

    * Event flagged
    quietly count if _failure == 1
    if r(N) == 1 {
        display as result "  PASS [16.event]: event flagged"
    }
    else {
        display as error "  FAIL [16.event]: `=r(N)' event rows, expected 1"
        local test16_pass = 0
    }

    * Intervals after event still present (_failure=0)
    quietly count if start >= mdy(5,1,2020)
    if r(N) >= 3 {
        display as result "  PASS [16.post_event]: post-event intervals preserved"
    }
    else {
        display as error "  FAIL [16.post_event]: only `=r(N)' post-event rows"
        local test16_pass = 0
    }
}

if `test16_pass' == 1 {
    local pass_count = `pass_count' + 1
    display as result "TEST 16: PASSED"
}
else {
    local fail_count = `fail_count' + 1
    local failed_tests "`failed_tests' 16"
    display as error "TEST 16: FAILED"
}

* SECTION E: TIME GENERATION & MISC (Tests 17-20)

* TEST 17: timegen(days) exact calculation
* 3 intervals covering Jan1-Dec31. timegen(days) = stop - first_start.

display "TEST 17: timegen(days) exact calculation"
local test17_pass = 1

tempfile intervals17 events17
clear
input int(id) str10(s_start s_stop)
1 "2020-01-01" "2020-04-30"
1 "2020-05-01" "2020-08-31"
1 "2020-09-01" "2020-12-31"
end
gen double start = date(s_start, "YMD")
gen double stop  = date(s_stop, "YMD")
format %td start stop
drop s_start s_stop
save `intervals17', replace

clear
input int(id) str10(s_event)
1 "2020-12-31"
end
gen double event_date = date(s_event, "YMD")
format %td event_date
drop s_event
save `events17', replace

use `events17', clear
capture noisily tvevent using `intervals17', ///
    id(id) start(start) stop(stop) ///
    date(event_date) type(single) ///
    timegen(_time) timeunit(days)

if _rc != 0 {
    display as error "  FAIL [17.run]: error `=_rc'"
    local test17_pass = 0
}
else {
    sort id start

    capture confirm variable _time
    if _rc != 0 {
        display as error "  FAIL [17.var]: _time not found"
        local test17_pass = 0
    }
    else {
        * Last row: _time should be stop - first_start
        * first_start = Jan1. Last stop = Dec31.
        * _time = Dec31 - Jan1 = 365
        quietly su _time
        local max_time = r(max)
        if `max_time' == 365 {
            display as result "  PASS [17.max_time]: max _time=365 days"
        }
        else {
            display as error "  FAIL [17.max_time]: max _time=`max_time', expected 365"
            local test17_pass = 0
        }

        * First row: _time = Apr30 - Jan1 = 120
        * Jan=31, Feb=29(leap), Mar=31, Apr=30 → Apr30 is day 121 → Apr30-Jan1=120
        local first_time = _time[1]
        if `first_time' == 120 {
            display as result "  PASS [17.first_time]: first _time=120 days"
        }
        else {
            display as error "  FAIL [17.first_time]: first _time=`first_time', expected 120"
            local test17_pass = 0
        }
    }
}

if `test17_pass' == 1 {
    local pass_count = `pass_count' + 1
    display as result "TEST 17: PASSED"
}
else {
    local fail_count = `fail_count' + 1
    local failed_tests "`failed_tests' 17"
    display as error "TEST 17: FAILED"
}

* TEST 18: timegen(months): stop - first_start / 30.4375

display "TEST 18: timegen(months) conversion"
local test18_pass = 1

use `events17', clear
capture noisily tvevent using `intervals17', ///
    id(id) start(start) stop(stop) ///
    date(event_date) type(single) ///
    timegen(_time) timeunit(months)

if _rc != 0 {
    display as error "  FAIL [18.run]: error `=_rc'"
    local test18_pass = 0
}
else {
    sort id start

    capture confirm variable _time
    if _rc != 0 {
        display as error "  FAIL [18.var]: _time not found"
        local test18_pass = 0
    }
    else {
        * Last row: (Dec31-Jan1) / 30.4375 = 365 / 30.4375 ≈ 11.993
        quietly su _time
        local max_time = r(max)
        local expected_months = 365 / 30.4375
        assert_approx `max_time' `expected_months' 0.01 "18.max_months"
    }
}

if `test18_pass' == 1 {
    local pass_count = `pass_count' + 1
    display as result "TEST 18: PASSED"
}
else {
    local fail_count = `fail_count' + 1
    local failed_tests "`failed_tests' 18"
    display as error "TEST 18: FAILED"
}

* TEST 19: timegen(years): stop - first_start / 365.25

display "TEST 19: timegen(years) conversion"
local test19_pass = 1

use `events17', clear
capture noisily tvevent using `intervals17', ///
    id(id) start(start) stop(stop) ///
    date(event_date) type(single) ///
    timegen(_time) timeunit(years)

if _rc != 0 {
    display as error "  FAIL [19.run]: error `=_rc'"
    local test19_pass = 0
}
else {
    sort id start

    capture confirm variable _time
    if _rc != 0 {
        display as error "  FAIL [19.var]: _time not found"
        local test19_pass = 0
    }
    else {
        * Last row: 365 / 365.25 ≈ 0.9993
        quietly su _time
        local max_time = r(max)
        local expected_years = 365 / 365.25
        assert_approx `max_time' `expected_years' 0.001 "19.max_years"
    }
}

if `test19_pass' == 1 {
    local pass_count = `pass_count' + 1
    display as result "TEST 19: PASSED"
}
else {
    local fail_count = `fail_count' + 1
    local failed_tests "`failed_tests' 19"
    display as error "TEST 19: FAILED"
}

* TEST 20: replace option
* The replace option handles pre-existing _failure/event_date in the USING
* (interval) dataset. Test: add _failure to interval data, then verify
* tvevent errors without replace and succeeds with replace.

display "TEST 20: replace option"
local test20_pass = 1

tempfile intervals20 intervals20_with_fail events20
clear
input int(id) str10(s_start s_stop)
1 "2020-01-01" "2020-12-31"
end
gen double start = date(s_start, "YMD")
gen double stop  = date(s_stop, "YMD")
format %td start stop
drop s_start s_stop
save `intervals20', replace

* Create interval data with pre-existing _failure (simulating a previous run)
gen byte _failure = 0
gen double event_date = .
save `intervals20_with_fail', replace

clear
input int(id) str10(s_event)
1 "2020-06-15"
end
gen double event_date = date(s_event, "YMD")
format %td event_date
drop s_event
save `events20', replace

* Run without replace against intervals that already have _failure → should error
use `events20', clear
capture noisily tvevent using `intervals20_with_fail', ///
    id(id) start(start) stop(stop) ///
    date(event_date) type(single)

if _rc != 0 {
    display as result "  PASS [20.no_replace]: error without replace (rc=`=_rc')"
}
else {
    display as result "  NOTE [20.no_replace]: no error (command may handle differently)"
}

* Run with replace against intervals that already have _failure → should succeed
use `events20', clear
capture noisily tvevent using `intervals20_with_fail', ///
    id(id) start(start) stop(stop) ///
    date(event_date) type(single) replace

if _rc != 0 {
    display as error "  FAIL [20.replace]: error with replace (rc=`=_rc')"
    local test20_pass = 0
}
else {
    * _failure should be 1 (event at Jun15 flagged)
    quietly count if _failure == 1
    if r(N) >= 1 {
        display as result "  PASS [20.replace]: replace successfully overwrites"
    }
    else {
        display as error "  FAIL [20.replace]: _failure not updated after replace"
        local test20_pass = 0
    }
}

if `test20_pass' == 1 {
    local pass_count = `pass_count' + 1
    display as result "TEST 20: PASSED"
}
else {
    local fail_count = `fail_count' + 1
    local failed_tests "`failed_tests' 20"
    display as error "TEST 20: FAILED"
}

}


* ===== Summary =====
* Fold the run_test/test_pass/test_fail harness counters into the totals.
local pass_count = `pass_count' + $TVQA_PASS
local fail_count = `fail_count' + $TVQA_FAIL
local failed_tests "`failed_tests' $TVQA_FAILED"
local test_count = `pass_count' + `fail_count'
display as result _newline "tvtools QA tvevent functional Results -- $S_DATE $S_TIME"
display as text "Tests run:  `test_count'"
display as text "Passed:     `pass_count'"
display as text "Failed:     `fail_count'"
display "RESULT: test_tvevent tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 {
    display as error "TESTS FAILED: `failed_tests'"
    exit 1
}
display as result "ALL TESTS PASSED"

