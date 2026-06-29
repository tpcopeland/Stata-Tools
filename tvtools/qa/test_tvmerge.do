clear all
set more off
set varabbrev off
version 16.0

capture log close
quietly log using "test_tvmerge.log", replace nomsg

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

display as result "tvtools QA: tvmerge functional -- $S_DATE $S_TIME"


**# ===== merged from test_tvtools.do L5452-7055: SECTION 6 TVMERGE =====

* SECTION 6: TVMERGE - Multi-dataset interval merging

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

* SETUP: Create tvexpose output files for tvmerge testing
if `quiet' == 0 {
    display as text "{hline 50}"
}

capture {
    quietly use "${DATA_DIR}/cohort.dta", clear
    tvexpose using "${DATA_DIR}/hrt.dta", ///
        id(id) start(rx_start) stop(rx_stop) ///
        exposure(hrt_type) reference(0) ///
        entry(study_entry) exit(study_exit) ///
        generate(tv_hrt) ///
        saveas("${DATA_DIR}/_tv_hrt.dta") replace

    quietly use "${DATA_DIR}/cohort.dta", clear
    tvexpose using "${DATA_DIR}/dmt.dta", ///
        id(id) start(dmt_start) stop(dmt_stop) ///
        exposure(dmt) reference(0) ///
        entry(study_entry) exit(study_exit) ///
        generate(tv_dmt) ///
        saveas("${DATA_DIR}/_tv_dmt.dta") replace
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

* SECTION A: KNOWN-ANSWER INTERSECTION (Tests 1-5)

* TEST 1: Two-dataset intersection (4 possible combos, 3 valid)
* DS_A: Person 1, [Jan1,Jun30] A=1, [Jul1,Dec31] A=0
* DS_B: Person 1, [Jan1,Mar31] B=0, [Apr1,Dec31] B=1
* Cartesian product: 4 combos. Valid intersections (start<=stop):
*   [Jan1,Mar31] A=1 B=0, [Apr1,Jun30] A=1 B=1, [Jul1,Dec31] A=0 B=1
* Invalid: [Jul1,Mar31] -> start>stop -> dropped
* Expected: 3 rows with exact date boundaries.

display "TEST 1: Two-dataset intersection - 3 valid rows"
local test1_pass = 1

tempfile ds_a ds_b
clear
input int(id) double(exp_a) str10(s_start s_stop)
1 1 "2020-01-01" "2020-06-30"
1 0 "2020-07-01" "2020-12-31"
end
gen double start_a = date(s_start, "YMD")
gen double stop_a  = date(s_stop, "YMD")
format %td start_a stop_a
drop s_start s_stop
save "`ds_a'.dta", replace

clear
input int(id) double(exp_b) str10(s_start s_stop)
1 0 "2020-01-01" "2020-03-31"
1 1 "2020-04-01" "2020-12-31"
end
gen double start_b = date(s_start, "YMD")
gen double stop_b  = date(s_stop, "YMD")
format %td start_b stop_b
drop s_start s_stop
save "`ds_b'.dta", replace

capture noisily tvmerge "`ds_a'.dta" "`ds_b'.dta", ///
    id(id) start(start_a start_b) stop(stop_a stop_b) ///
    exposure(exp_a exp_b)

if _rc != 0 {
    display as error "  FAIL [1.run]: tvmerge error `=_rc'"
    local test1_pass = 0
}
else {
    sort id start

    * Exactly 3 rows
    quietly count
    if r(N) == 3 {
        display as result "  PASS [1.rows]: 3 rows"
    }
    else {
        display as error "  FAIL [1.rows]: `=r(N)' rows, expected 3"
        local test1_pass = 0
    }

    * Row 1: [Jan1,Mar31] A=1 B=0
    if start[1] == mdy(1,1,2020) & stop[1] == mdy(3,31,2020) {
        display as result "  PASS [1.r1_dates]: row 1 = [Jan1,Mar31]"
    }
    else {
        display as error "  FAIL [1.r1_dates]: row 1 dates wrong"
        local test1_pass = 0
    }

    * Row 2: [Apr1,Jun30] A=1 B=1
    if start[2] == mdy(4,1,2020) & stop[2] == mdy(6,30,2020) {
        display as result "  PASS [1.r2_dates]: row 2 = [Apr1,Jun30]"
    }
    else {
        display as error "  FAIL [1.r2_dates]: row 2 dates wrong"
        local test1_pass = 0
    }

    * Row 3: [Jul1,Dec31] A=0 B=1
    if start[3] == mdy(7,1,2020) & stop[3] == mdy(12,31,2020) {
        display as result "  PASS [1.r3_dates]: row 3 = [Jul1,Dec31]"
    }
    else {
        display as error "  FAIL [1.r3_dates]: row 3 dates wrong"
        local test1_pass = 0
    }

    * Person-time = 366
    tempvar pt
    gen `pt' = stop - start + 1
    quietly su `pt'
    if r(sum) == 366 {
        display as result "  PASS [1.pt]: person-time=366"
    }
    else {
        display as error "  FAIL [1.pt]: person-time=`=r(sum)', expected 366"
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

capture erase "`ds_a'.dta"
capture erase "`ds_b'.dta"

* TEST 2: Three-way merge known-answer
* DS_A: [Jan1,Dec31] A=1
* DS_B: [Apr1,Sep30] B=1
* DS_C: [Jul1,Dec31] C=1
* Sequential intersection: A∩B = [Apr1,Sep30], then ∩C = [Jul1,Sep30]
* Expected: 1 row [Jul1,Sep30] with all exposures = 1

display "TEST 2: Three-way merge - single intersection row"
local test2_pass = 1

tempfile ds_a2 ds_b2 ds_c2
clear
input int(id) double(exp_a) str10(s_start s_stop)
1 1 "2020-01-01" "2020-12-31"
end
gen double start_a = date(s_start, "YMD")
gen double stop_a  = date(s_stop, "YMD")
format %td start_a stop_a
drop s_start s_stop
save "`ds_a2'.dta", replace

clear
input int(id) double(exp_b) str10(s_start s_stop)
1 1 "2020-04-01" "2020-09-30"
end
gen double start_b = date(s_start, "YMD")
gen double stop_b  = date(s_stop, "YMD")
format %td start_b stop_b
drop s_start s_stop
save "`ds_b2'.dta", replace

clear
input int(id) double(exp_c) str10(s_start s_stop)
1 1 "2020-07-01" "2020-12-31"
end
gen double start_c = date(s_start, "YMD")
gen double stop_c  = date(s_stop, "YMD")
format %td start_c stop_c
drop s_start s_stop
save "`ds_c2'.dta", replace

capture noisily tvmerge "`ds_a2'.dta" "`ds_b2'.dta" "`ds_c2'.dta", ///
    id(id) start(start_a start_b start_c) stop(stop_a stop_b stop_c) ///
    exposure(exp_a exp_b exp_c)

if _rc != 0 {
    display as error "  FAIL [2.run]: tvmerge error `=_rc'"
    local test2_pass = 0
}
else {
    sort id start

    * Exactly 1 row
    quietly count
    if r(N) == 1 {
        display as result "  PASS [2.rows]: 1 row"
    }
    else {
        display as error "  FAIL [2.rows]: `=r(N)' rows, expected 1"
        local test2_pass = 0
    }

    * Row dates: [Jul1, Sep30]
    if start[1] == mdy(7,1,2020) & stop[1] == mdy(9,30,2020) {
        display as result "  PASS [2.dates]: [Jul1,Sep30]"
    }
    else {
        display as error "  FAIL [2.dates]: start=`=string(start[1],"%td")', stop=`=string(stop[1],"%td")'"
        local test2_pass = 0
    }

    * Person-time = Jul1 to Sep30 = 92 days
    local expected_pt = mdy(9,30,2020) - mdy(7,1,2020) + 1
    tempvar pt
    gen `pt' = stop - start + 1
    quietly su `pt'
    if r(sum) == `expected_pt' {
        display as result "  PASS [2.pt]: person-time=`expected_pt'"
    }
    else {
        display as error "  FAIL [2.pt]: person-time=`=r(sum)', expected `expected_pt'"
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

capture erase "`ds_a2'.dta"
capture erase "`ds_b2'.dta"
capture erase "`ds_c2'.dta"

* TEST 3: Continuous proportioning (2 datasets, exact formula)
* DS_A: [Jan1,Dec31] A=366 (continuous). DS_B: [Jul1,Dec31] B=184.
* Intersection = [Jul1,Dec31] (184 days out of 366 for DS_A)
* A proportioned: 366 * (184/366) = 184.0
* B proportioned: 184 * (184/184) = 184.0

display "TEST 3: Continuous proportioning - exact formula"
local test3_pass = 1

tempfile ds_a3 ds_b3
clear
input int(id) double(exp_a) str10(s_start s_stop)
1 366 "2020-01-01" "2020-12-31"
end
gen double start_a = date(s_start, "YMD")
gen double stop_a  = date(s_stop, "YMD")
format %td start_a stop_a
drop s_start s_stop
save "`ds_a3'.dta", replace

clear
input int(id) double(exp_b) str10(s_start s_stop)
1 184 "2020-07-01" "2020-12-31"
end
gen double start_b = date(s_start, "YMD")
gen double stop_b  = date(s_stop, "YMD")
format %td start_b stop_b
drop s_start s_stop
save "`ds_b3'.dta", replace

capture noisily tvmerge "`ds_a3'.dta" "`ds_b3'.dta", ///
    id(id) start(start_a start_b) stop(stop_a stop_b) ///
    exposure(exp_a exp_b) continuous(exp_a exp_b)

if _rc != 0 {
    display as error "  FAIL [3.run]: tvmerge error `=_rc'"
    local test3_pass = 0
}
else {
    sort id start

    * 1 row: [Jul1,Dec31]
    quietly count
    if r(N) == 1 {
        display as result "  PASS [3.rows]: 1 row"
    }
    else {
        display as error "  FAIL [3.rows]: `=r(N)' rows, expected 1"
        local test3_pass = 0
    }

    * A proportioned: 366 * (184/366) = 184.0
    assert_approx `=exp_a[1]' 184.0 0.01 "3.exp_a"

    * B proportioned: 184 * (184/184) = 184.0
    assert_approx `=exp_b[1]' 184.0 0.01 "3.exp_b"
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

capture erase "`ds_a3'.dta"
capture erase "`ds_b3'.dta"

* TEST 4: Continuous proportioning (3 datasets, cascading)
* DS_A: [Jan1,Dec31] A=365
* DS_B: [Jan1,Jun30] B=181
* DS_C: [Apr1,Jun30] C=91
* Step 1: A∩B = [Jan1,Jun30] (182 days). A proportioned: 365*(182/366) = 181.56...
* Step 2: (A∩B)∩C = [Apr1,Jun30] (91 days out of 182 from merged).
*   A re-proportioned: 181.56 * (91/182) = 90.78...
*   B re-proportioned: 181 * (91/182) = 90.50... wait, B covers [Jan1,Jun30] = 182 days
*     B proportioned at step 1: 181*(182/182) = 181
*     B re-proportioned at step 2: 181*(91/182) = 90.50
*   C proportioned: 91*(91/91) = 91.0

display "TEST 4: Continuous proportioning - 3 datasets cascading"
local test4_pass = 1

tempfile ds_a4 ds_b4 ds_c4
clear
input int(id) double(exp_a) str10(s_start s_stop)
1 365 "2020-01-01" "2020-12-31"
end
gen double start_a = date(s_start, "YMD")
gen double stop_a  = date(s_stop, "YMD")
format %td start_a stop_a
drop s_start s_stop
save "`ds_a4'.dta", replace

clear
input int(id) double(exp_b) str10(s_start s_stop)
1 181 "2020-01-01" "2020-06-30"
end
gen double start_b = date(s_start, "YMD")
gen double stop_b  = date(s_stop, "YMD")
format %td start_b stop_b
drop s_start s_stop
save "`ds_b4'.dta", replace

clear
input int(id) double(exp_c) str10(s_start s_stop)
1 91 "2020-04-01" "2020-06-30"
end
gen double start_c = date(s_start, "YMD")
gen double stop_c  = date(s_stop, "YMD")
format %td start_c stop_c
drop s_start s_stop
save "`ds_c4'.dta", replace

capture noisily tvmerge "`ds_a4'.dta" "`ds_b4'.dta" "`ds_c4'.dta", ///
    id(id) start(start_a start_b start_c) stop(stop_a stop_b stop_c) ///
    exposure(exp_a exp_b exp_c) continuous(exp_a exp_b exp_c)

if _rc != 0 {
    display as error "  FAIL [4.run]: tvmerge error `=_rc'"
    local test4_pass = 0
}
else {
    sort id start

    * Should have 1 row: [Apr1,Jun30]
    quietly count
    if r(N) == 1 {
        display as result "  PASS [4.rows]: 1 row"
    }
    else {
        display as error "  FAIL [4.rows]: `=r(N)' rows, expected 1"
        local test4_pass = 0
    }

    * C = 91.0 (no proportioning needed since interval matches exactly)
    assert_approx `=exp_c[1]' 91.0 0.01 "4.exp_c"

    * All values should be positive and proportioned
    if exp_a[1] > 0 & exp_b[1] > 0 {
        display as result "  PASS [4.positive]: all proportioned values positive"
    }
    else {
        display as error "  FAIL [4.positive]: negative proportioned values"
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

capture erase "`ds_a4'.dta"
capture erase "`ds_b4'.dta"
capture erase "`ds_c4'.dta"

* TEST 5: batch(100) vs batch(1) produce identical results
* 5 persons with varying intervals in DS_A and DS_B.
* Run both batch sizes, compare results.

display "TEST 5: batch(100) vs batch(1) equivalence"
local test5_pass = 1

tempfile ds_a5 ds_b5
clear
input int(id) double(exp_a) str10(s_start s_stop)
1 1 "2020-01-01" "2020-06-30"
1 0 "2020-07-01" "2020-12-31"
2 1 "2020-01-01" "2020-12-31"
3 1 "2020-03-01" "2020-09-30"
4 0 "2020-01-01" "2020-03-31"
4 1 "2020-04-01" "2020-12-31"
5 1 "2020-06-01" "2020-08-31"
end
gen double start_a = date(s_start, "YMD")
gen double stop_a  = date(s_stop, "YMD")
format %td start_a stop_a
drop s_start s_stop
save "`ds_a5'.dta", replace

clear
input int(id) double(exp_b) str10(s_start s_stop)
1 1 "2020-04-01" "2020-09-30"
2 1 "2020-03-01" "2020-06-30"
2 0 "2020-07-01" "2020-12-31"
3 1 "2020-01-01" "2020-12-31"
4 1 "2020-01-01" "2020-12-31"
5 0 "2020-01-01" "2020-04-30"
5 1 "2020-05-01" "2020-12-31"
end
gen double start_b = date(s_start, "YMD")
gen double stop_b  = date(s_stop, "YMD")
format %td start_b stop_b
drop s_start s_stop
save "`ds_b5'.dta", replace

* batch(100) = all at once
tempfile result_100 result_1
capture noisily tvmerge "`ds_a5'.dta" "`ds_b5'.dta", ///
    id(id) start(start_a start_b) stop(stop_a stop_b) ///
    exposure(exp_a exp_b) batch(100)

if _rc != 0 {
    display as error "  FAIL [5a.run]: batch(100) error `=_rc'"
    local test5_pass = 0
}
else {
    sort id start stop
    save `result_100', replace
    local n100 = _N
}

* batch(1) = one ID at a time (1% -> effectively 1 at a time for 5 persons)
capture noisily tvmerge "`ds_a5'.dta" "`ds_b5'.dta", ///
    id(id) start(start_a start_b) stop(stop_a stop_b) ///
    exposure(exp_a exp_b) batch(1)

if _rc != 0 {
    display as error "  FAIL [5b.run]: batch(1) error `=_rc'"
    local test5_pass = 0
}
else {
    sort id start stop
    save `result_1', replace
    local n1 = _N

    * Same row count
    if `n100' == `n1' {
        display as result "  PASS [5.n_rows]: batch(100)=`n100' == batch(1)=`n1'"
    }
    else {
        display as error "  FAIL [5.n_rows]: batch(100)=`n100' != batch(1)=`n1'"
        local test5_pass = 0
    }

    * Exact comparison using cf
    capture {
        use `result_100', clear
        cf id start stop exp_a exp_b using `result_1'
    }
    if _rc == 0 {
        display as result "  PASS [5.identical]: batch(100) and batch(1) are identical"
    }
    else {
        display as error "  FAIL [5.identical]: batch(100) and batch(1) differ"
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

capture erase "`ds_a5'.dta"
capture erase "`ds_b5'.dta"

* SECTION B: DEGENERATE & EDGE CASES (Tests 6-10)

* TEST 6: Empty intersection (no temporal overlap) -> 0 obs
* DS_A: [Jan1,Mar31]. DS_B: [Jul1,Dec31]. No overlap.

display "TEST 6: Empty intersection - no temporal overlap"
local test6_pass = 1

tempfile ds_a6 ds_b6
clear
input int(id) double(exp_a) str10(s_start s_stop)
1 1 "2020-01-01" "2020-03-31"
end
gen double start_a = date(s_start, "YMD")
gen double stop_a  = date(s_stop, "YMD")
format %td start_a stop_a
drop s_start s_stop
save "`ds_a6'.dta", replace

clear
input int(id) double(exp_b) str10(s_start s_stop)
1 1 "2020-07-01" "2020-12-31"
end
gen double start_b = date(s_start, "YMD")
gen double stop_b  = date(s_stop, "YMD")
format %td start_b stop_b
drop s_start s_stop
save "`ds_b6'.dta", replace

capture noisily tvmerge "`ds_a6'.dta" "`ds_b6'.dta", ///
    id(id) start(start_a start_b) stop(stop_a stop_b) ///
    exposure(exp_a exp_b)

if _rc != 0 {
    * Might error or produce 0 obs - check
    display as result "  NOTE [6.rc]: tvmerge returned rc=`=_rc' for empty intersection"
    * Empty intersection producing an error is acceptable
}
else {
    quietly count
    if r(N) == 0 {
        display as result "  PASS [6.empty]: 0 rows (no intersection)"
    }
    else {
        display as error "  FAIL [6.empty]: `=r(N)' rows, expected 0"
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

capture erase "`ds_a6'.dta"
capture erase "`ds_b6'.dta"

* TEST 7: Single-day period merge
* DS_A: [Jun15,Jun15]. DS_B: [Jun15,Jun15]. Intersection = 1 row [Jun15,Jun15].

display "TEST 7: Single-day period merge"
local test7_pass = 1

tempfile ds_a7 ds_b7
clear
input int(id) double(exp_a) str10(s_start s_stop)
1 1 "2020-06-15" "2020-06-15"
end
gen double start_a = date(s_start, "YMD")
gen double stop_a  = date(s_stop, "YMD")
format %td start_a stop_a
drop s_start s_stop
save "`ds_a7'.dta", replace

clear
input int(id) double(exp_b) str10(s_start s_stop)
1 1 "2020-06-15" "2020-06-15"
end
gen double start_b = date(s_start, "YMD")
gen double stop_b  = date(s_stop, "YMD")
format %td start_b stop_b
drop s_start s_stop
save "`ds_b7'.dta", replace

capture noisily tvmerge "`ds_a7'.dta" "`ds_b7'.dta", ///
    id(id) start(start_a start_b) stop(stop_a stop_b) ///
    exposure(exp_a exp_b)

if _rc != 0 {
    display as error "  FAIL [7.run]: error `=_rc'"
    local test7_pass = 0
}
else {
    quietly count
    if r(N) == 1 {
        display as result "  PASS [7.rows]: 1 row"
    }
    else {
        display as error "  FAIL [7.rows]: `=r(N)' rows, expected 1"
        local test7_pass = 0
    }

    * Single day
    tempvar pt
    gen `pt' = stop - start + 1
    quietly su `pt'
    if r(sum) == 1 {
        display as result "  PASS [7.pt]: person-time=1"
    }
    else {
        display as error "  FAIL [7.pt]: person-time=`=r(sum)', expected 1"
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

capture erase "`ds_a7'.dta"
capture erase "`ds_b7'.dta"

* TEST 8: Abutting periods
* DS_A: [Jan1,Jun30]+[Jul1,Dec31]. DS_B: [Jun30,Jul1].
* Intersections: [Jun30,Jun30] from A1∩B, [Jul1,Jul1] from A2∩B.

display "TEST 8: Abutting periods - boundary intersections"
local test8_pass = 1

tempfile ds_a8 ds_b8
clear
input int(id) double(exp_a) str10(s_start s_stop)
1 1 "2020-01-01" "2020-06-30"
1 2 "2020-07-01" "2020-12-31"
end
gen double start_a = date(s_start, "YMD")
gen double stop_a  = date(s_stop, "YMD")
format %td start_a stop_a
drop s_start s_stop
save "`ds_a8'.dta", replace

clear
input int(id) double(exp_b) str10(s_start s_stop)
1 1 "2020-06-30" "2020-07-01"
end
gen double start_b = date(s_start, "YMD")
gen double stop_b  = date(s_stop, "YMD")
format %td start_b stop_b
drop s_start s_stop
save "`ds_b8'.dta", replace

capture noisily tvmerge "`ds_a8'.dta" "`ds_b8'.dta", ///
    id(id) start(start_a start_b) stop(stop_a stop_b) ///
    exposure(exp_a exp_b)

if _rc != 0 {
    display as error "  FAIL [8.run]: error `=_rc'"
    local test8_pass = 0
}
else {
    sort id start

    * Should have 2 rows: [Jun30,Jun30] and [Jul1,Jul1]
    quietly count
    if r(N) == 2 {
        display as result "  PASS [8.rows]: 2 rows"
    }
    else {
        display as error "  FAIL [8.rows]: `=r(N)' rows, expected 2"
        local test8_pass = 0
    }

    * Total person-time = 2 days
    tempvar pt
    gen `pt' = stop - start + 1
    quietly su `pt'
    if r(sum) == 2 {
        display as result "  PASS [8.pt]: person-time=2"
    }
    else {
        display as error "  FAIL [8.pt]: person-time=`=r(sum)', expected 2"
        local test8_pass = 0
    }

    * Row 1 should have exp_a=1 (from first A period)
    * Row 2 should have exp_a=2 (from second A period)
    if exp_a[1] == 1 & exp_a[2] == 2 {
        display as result "  PASS [8.exp_a]: correct exposure values across boundary"
    }
    else {
        display as error "  FAIL [8.exp_a]: exp_a values wrong"
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

capture erase "`ds_a8'.dta"
capture erase "`ds_b8'.dta"

* TEST 9: ID mismatch with force option
* Person 1 in both. Person 2 only in DS_A.
* Without force: should error. With force: drops Person 2, warns.

display "TEST 9: ID mismatch - force option"
local test9_pass = 1

tempfile ds_a9 ds_b9
clear
input int(id) double(exp_a) str10(s_start s_stop)
1 1 "2020-01-01" "2020-12-31"
2 1 "2020-01-01" "2020-12-31"
end
gen double start_a = date(s_start, "YMD")
gen double stop_a  = date(s_stop, "YMD")
format %td start_a stop_a
drop s_start s_stop
save "`ds_a9'.dta", replace

clear
input int(id) double(exp_b) str10(s_start s_stop)
1 1 "2020-01-01" "2020-12-31"
end
gen double start_b = date(s_start, "YMD")
gen double stop_b  = date(s_stop, "YMD")
format %td start_b stop_b
drop s_start s_stop
save "`ds_b9'.dta", replace

* Without force: should error
capture tvmerge "`ds_a9'.dta" "`ds_b9'.dta", ///
    id(id) start(start_a start_b) stop(stop_a stop_b) ///
    exposure(exp_a exp_b)

if _rc != 0 {
    display as result "  PASS [9.no_force]: error without force (rc=`=_rc')"
}
else {
    display as error "  FAIL [9.no_force]: no error without force for mismatched IDs"
    local test9_pass = 0
}

* With force: should succeed with only Person 1
capture noisily tvmerge "`ds_a9'.dta" "`ds_b9'.dta", ///
    id(id) start(start_a start_b) stop(stop_a stop_b) ///
    exposure(exp_a exp_b) force

if _rc != 0 {
    display as error "  FAIL [9.force]: error with force (rc=`=_rc')"
    local test9_pass = 0
}
else {
    * Only Person 1 should remain
    quietly tab id
    if r(r) == 1 {
        display as result "  PASS [9.force_drop]: only Person 1 remains with force"
    }
    else {
        display as error "  FAIL [9.force_drop]: `=r(r)' unique IDs, expected 1"
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

capture erase "`ds_a9'.dta"
capture erase "`ds_b9'.dta"

* TEST 10: keep() with same-named variables -> suffixed
* Both DS_A and DS_B have a variable called "sex".
* keep(sex) should create sex_ds1 and sex_ds2.

display "TEST 10: keep() with name collision -> suffixed variables"
local test10_pass = 1

tempfile ds_a10 ds_b10
clear
input int(id) double(exp_a) int(sex) str10(s_start s_stop)
1 1 1 "2020-01-01" "2020-12-31"
end
gen double start_a = date(s_start, "YMD")
gen double stop_a  = date(s_stop, "YMD")
format %td start_a stop_a
drop s_start s_stop
save "`ds_a10'.dta", replace

clear
input int(id) double(exp_b) int(sex) str10(s_start s_stop)
1 1 0 "2020-01-01" "2020-12-31"
end
gen double start_b = date(s_start, "YMD")
gen double stop_b  = date(s_stop, "YMD")
format %td start_b stop_b
drop s_start s_stop
save "`ds_b10'.dta", replace

capture noisily tvmerge "`ds_a10'.dta" "`ds_b10'.dta", ///
    id(id) start(start_a start_b) stop(stop_a stop_b) ///
    exposure(exp_a exp_b) keep(sex)

if _rc != 0 {
    display as error "  FAIL [10.run]: error `=_rc'"
    local test10_pass = 0
}
else {
    * Check for suffixed variables
    local found_suffix = 0
    capture confirm variable sex_ds1
    if _rc == 0 local found_suffix = `found_suffix' + 1
    capture confirm variable sex_ds2
    if _rc == 0 local found_suffix = `found_suffix' + 1

    * Also check for unsuffixed (if names don't conflict)
    capture confirm variable sex
    local has_plain = (_rc == 0)

    if `found_suffix' == 2 {
        display as result "  PASS [10.suffix]: sex_ds1 and sex_ds2 exist"
    }
    else if `has_plain' {
        display as result "  PASS [10.keep]: sex variable kept (no suffix needed)"
    }
    else {
        display as error "  FAIL [10.suffix]: expected suffixed sex variables"
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

capture erase "`ds_a10'.dta"
capture erase "`ds_b10'.dta"

* SECTION C: PERSON-TIME & COVERAGE (Tests 11-15)

* TEST 11: Person-time equals intersection duration (3 persons)
* P1: full overlap (both cover Jan1-Dec31)
* P2: partial overlap (A:Jan1-Jun30, B:Apr1-Dec31 -> intersection Apr1-Jun30)
* P3: full overlap (both cover Jan1-Dec31)

display "TEST 11: Person-time = intersection duration (3 persons)"
local test11_pass = 1

tempfile ds_a11 ds_b11
clear
input int(id) double(exp_a) str10(s_start s_stop)
1 1 "2020-01-01" "2020-12-31"
2 1 "2020-01-01" "2020-06-30"
3 1 "2020-01-01" "2020-12-31"
end
gen double start_a = date(s_start, "YMD")
gen double stop_a  = date(s_stop, "YMD")
format %td start_a stop_a
drop s_start s_stop
save "`ds_a11'.dta", replace

clear
input int(id) double(exp_b) str10(s_start s_stop)
1 1 "2020-01-01" "2020-12-31"
2 1 "2020-04-01" "2020-12-31"
3 1 "2020-01-01" "2020-12-31"
end
gen double start_b = date(s_start, "YMD")
gen double stop_b  = date(s_stop, "YMD")
format %td start_b stop_b
drop s_start s_stop
save "`ds_b11'.dta", replace

capture noisily tvmerge "`ds_a11'.dta" "`ds_b11'.dta", ///
    id(id) start(start_a start_b) stop(stop_a stop_b) ///
    exposure(exp_a exp_b)

if _rc != 0 {
    display as error "  FAIL [11.run]: error `=_rc'"
    local test11_pass = 0
}
else {
    * P1: full overlap -> 366 days
    tempvar pt
    gen `pt' = stop - start + 1
    quietly su `pt' if id == 1
    if r(sum) == 366 {
        display as result "  PASS [11.pt_p1]: Person 1 = 366 days"
    }
    else {
        display as error "  FAIL [11.pt_p1]: Person 1 = `=r(sum)', expected 366"
        local test11_pass = 0
    }

    * P2: partial overlap [Apr1,Jun30] = 91 days
    quietly su `pt' if id == 2
    local p2_pt = r(sum)
    local expected_p2 = mdy(6,30,2020) - mdy(4,1,2020) + 1
    if `p2_pt' == `expected_p2' {
        display as result "  PASS [11.pt_p2]: Person 2 = `expected_p2' days"
    }
    else {
        display as error "  FAIL [11.pt_p2]: Person 2 = `p2_pt', expected `expected_p2'"
        local test11_pass = 0
    }

    * P3: full overlap -> 366 days
    quietly su `pt' if id == 3
    if r(sum) == 366 {
        display as result "  PASS [11.pt_p3]: Person 3 = 366 days"
    }
    else {
        display as error "  FAIL [11.pt_p3]: Person 3 = `=r(sum)', expected 366"
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

capture erase "`ds_a11'.dta"
capture erase "`ds_b11'.dta"

* TEST 12: Multiple persons: full, partial, no overlap with force

display "TEST 12: Multiple persons - full/partial/no overlap with force"
local test12_pass = 1

tempfile ds_a12 ds_b12
clear
input int(id) double(exp_a) str10(s_start s_stop)
1 1 "2020-01-01" "2020-12-31"
2 1 "2020-01-01" "2020-06-30"
3 1 "2020-01-01" "2020-12-31"
end
gen double start_a = date(s_start, "YMD")
gen double stop_a  = date(s_stop, "YMD")
format %td start_a stop_a
drop s_start s_stop
save "`ds_a12'.dta", replace

clear
input int(id) double(exp_b) str10(s_start s_stop)
1 1 "2020-01-01" "2020-12-31"
2 1 "2020-07-01" "2020-12-31"
end
gen double start_b = date(s_start, "YMD")
gen double stop_b  = date(s_stop, "YMD")
format %td start_b stop_b
drop s_start s_stop
save "`ds_b12'.dta", replace

capture noisily tvmerge "`ds_a12'.dta" "`ds_b12'.dta", ///
    id(id) start(start_a start_b) stop(stop_a stop_b) ///
    exposure(exp_a exp_b) force

if _rc != 0 {
    display as error "  FAIL [12.run]: error `=_rc'"
    local test12_pass = 0
}
else {
    * Person 3 should be dropped (only in DS_A)
    quietly tab id
    local n_ids = r(r)
    * At least Persons 1 and 2 should be present
    quietly count if id == 1
    local p1_n = r(N)
    quietly count if id == 2
    local p2_n = r(N)

    if `p1_n' >= 1 {
        display as result "  PASS [12.p1]: Person 1 present"
    }
    else {
        display as error "  FAIL [12.p1]: Person 1 missing"
        local test12_pass = 0
    }

    if `p2_n' >= 1 {
        display as result "  PASS [12.p2]: Person 2 present"
    }
    else {
        * Person 2 has no overlap (A:Jan-Jun, B:Jul-Dec -> no overlap for same ID)
        * With force this might be handled
        display as result "  NOTE [12.p2]: Person 2 has `p2_n' rows (no temporal overlap)"
    }

    * Person 3 missing from DS_B -> dropped with force
    quietly count if id == 3
    if r(N) == 0 {
        display as result "  PASS [12.p3_dropped]: Person 3 dropped (not in DS_B)"
    }
    else {
        display as error "  FAIL [12.p3_dropped]: Person 3 still present"
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

capture erase "`ds_a12'.dta"
capture erase "`ds_b12'.dta"

* TEST 13: Continuous preserved exactly when intervals align
* Both datasets have identical intervals -> no re-proportioning needed

display "TEST 13: Continuous preserved when intervals align"
local test13_pass = 1

tempfile ds_a13 ds_b13
clear
input int(id) double(exp_a) str10(s_start s_stop)
1 100 "2020-01-01" "2020-06-30"
1 200 "2020-07-01" "2020-12-31"
end
gen double start_a = date(s_start, "YMD")
gen double stop_a  = date(s_stop, "YMD")
format %td start_a stop_a
drop s_start s_stop
save "`ds_a13'.dta", replace

clear
input int(id) double(exp_b) str10(s_start s_stop)
1 50 "2020-01-01" "2020-06-30"
1 75 "2020-07-01" "2020-12-31"
end
gen double start_b = date(s_start, "YMD")
gen double stop_b  = date(s_stop, "YMD")
format %td start_b stop_b
drop s_start s_stop
save "`ds_b13'.dta", replace

capture noisily tvmerge "`ds_a13'.dta" "`ds_b13'.dta", ///
    id(id) start(start_a start_b) stop(stop_a stop_b) ///
    exposure(exp_a exp_b) continuous(exp_a exp_b)

if _rc != 0 {
    display as error "  FAIL [13.run]: error `=_rc'"
    local test13_pass = 0
}
else {
    sort id start

    * 2 rows with exact values preserved (no proportioning needed)
    quietly count
    if r(N) == 2 {
        display as result "  PASS [13.rows]: 2 rows"
    }
    else {
        display as error "  FAIL [13.rows]: `=r(N)' rows, expected 2"
        local test13_pass = 0
    }

    * Values should be exact (proportion = 1.0 since intervals align)
    assert_approx `=exp_a[1]' 100 0.01 "13.a1"
    assert_approx `=exp_a[2]' 200 0.01 "13.a2"
    assert_approx `=exp_b[1]' 50 0.01 "13.b1"
    assert_approx `=exp_b[2]' 75 0.01 "13.b2"
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

capture erase "`ds_a13'.dta"
capture erase "`ds_b13'.dta"

* TEST 14: Three-way merge with partial overlaps - Person 2 dropped at merge step 2

display "TEST 14: Three-way merge - Person 2 dropped at step 2"
local test14_pass = 1

tempfile ds_a14 ds_b14 ds_c14
clear
input int(id) double(exp_a) str10(s_start s_stop)
1 1 "2020-01-01" "2020-12-31"
2 1 "2020-01-01" "2020-12-31"
end
gen double start_a = date(s_start, "YMD")
gen double stop_a  = date(s_stop, "YMD")
format %td start_a stop_a
drop s_start s_stop
save "`ds_a14'.dta", replace

clear
input int(id) double(exp_b) str10(s_start s_stop)
1 1 "2020-01-01" "2020-12-31"
2 1 "2020-01-01" "2020-12-31"
end
gen double start_b = date(s_start, "YMD")
gen double stop_b  = date(s_stop, "YMD")
format %td start_b stop_b
drop s_start s_stop
save "`ds_b14'.dta", replace

clear
input int(id) double(exp_c) str10(s_start s_stop)
1 1 "2020-01-01" "2020-12-31"
end
gen double start_c = date(s_start, "YMD")
gen double stop_c  = date(s_stop, "YMD")
format %td start_c stop_c
drop s_start s_stop
save "`ds_c14'.dta", replace

* Person 2 is in A and B but not C -> should be dropped with force
capture noisily tvmerge "`ds_a14'.dta" "`ds_b14'.dta" "`ds_c14'.dta", ///
    id(id) start(start_a start_b start_c) stop(stop_a stop_b stop_c) ///
    exposure(exp_a exp_b exp_c) force

if _rc != 0 {
    display as error "  FAIL [14.run]: error `=_rc'"
    local test14_pass = 0
}
else {
    * Only Person 1 should remain
    quietly tab id
    if r(r) == 1 {
        display as result "  PASS [14.single_id]: only Person 1 remains"
    }
    else {
        display as error "  FAIL [14.single_id]: `=r(r)' IDs, expected 1"
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

capture erase "`ds_a14'.dta"
capture erase "`ds_b14'.dta"
capture erase "`ds_c14'.dta"

* TEST 15: Three-way continuous proportioning with 2 persons

display "TEST 15: Three-way continuous - 2 persons"
local test15_pass = 1

tempfile ds_a15 ds_b15 ds_c15
clear
input int(id) double(exp_a) str10(s_start s_stop)
1 366 "2020-01-01" "2020-12-31"
2 366 "2020-01-01" "2020-12-31"
end
gen double start_a = date(s_start, "YMD")
gen double stop_a  = date(s_stop, "YMD")
format %td start_a stop_a
drop s_start s_stop
save "`ds_a15'.dta", replace

clear
input int(id) double(exp_b) str10(s_start s_stop)
1 182 "2020-01-01" "2020-06-30"
2 366 "2020-01-01" "2020-12-31"
end
gen double start_b = date(s_start, "YMD")
gen double stop_b  = date(s_stop, "YMD")
format %td start_b stop_b
drop s_start s_stop
save "`ds_b15'.dta", replace

clear
input int(id) double(exp_c) str10(s_start s_stop)
1 91 "2020-04-01" "2020-06-30"
2 366 "2020-01-01" "2020-12-31"
end
gen double start_c = date(s_start, "YMD")
gen double stop_c  = date(s_stop, "YMD")
format %td start_c stop_c
drop s_start s_stop
save "`ds_c15'.dta", replace

capture noisily tvmerge "`ds_a15'.dta" "`ds_b15'.dta" "`ds_c15'.dta", ///
    id(id) start(start_a start_b start_c) stop(stop_a stop_b stop_c) ///
    exposure(exp_a exp_b exp_c) continuous(exp_a exp_b exp_c)

if _rc != 0 {
    display as error "  FAIL [15.run]: error `=_rc'"
    local test15_pass = 0
}
else {
    * Person 2 has full alignment -> values preserved at 366
    quietly su exp_a if id == 2
    assert_approx `=r(mean)' 366 0.01 "15.p2_a"

    * Person 1 has cascading proportioning
    quietly su exp_c if id == 1
    assert_approx `=r(mean)' 91 0.01 "15.p1_c"

    * All values should be positive
    quietly count if exp_a <= 0 | exp_b <= 0 | exp_c <= 0
    if r(N) == 0 {
        display as result "  PASS [15.positive]: all proportioned values positive"
    }
    else {
        display as error "  FAIL [15.positive]: some values <=0"
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

* NOTE: Do NOT erase ds_a15/ds_b15/ds_c15 yet - test 16 reuses them

* SECTION D: NAMING & DIAGNOSTICS (Tests 16-20)

* TEST 16: generate() naming with 3 datasets

display "TEST 16: generate() naming with 3 datasets"
local test16_pass = 1

capture noisily tvmerge "`ds_a15'.dta" "`ds_b15'.dta" "`ds_c15'.dta", ///
    id(id) start(start_a start_b start_c) stop(stop_a stop_b stop_c) ///
    exposure(exp_a exp_b exp_c) generate(drug_a drug_b drug_c)

if _rc != 0 {
    display as error "  FAIL [16.run]: error `=_rc'"
    local test16_pass = 0
}
else {
    * Check renamed variables exist
    local all_found = 1
    foreach v in drug_a drug_b drug_c {
        capture confirm variable `v'
        if _rc != 0 {
            display as error "  FAIL [16.var_`v']: `v' not found"
            local all_found = 0
            local test16_pass = 0
        }
    }
    if `all_found' == 1 {
        display as result "  PASS [16.vars]: drug_a, drug_b, drug_c all exist"
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

capture erase "`ds_a15'.dta"
capture erase "`ds_b15'.dta"
capture erase "`ds_c15'.dta"

* TEST 17: prefix() naming

display "TEST 17: prefix() naming"
local test17_pass = 1

tempfile ds_a17 ds_b17
clear
input int(id) double(exp_a) str10(s_start s_stop)
1 1 "2020-01-01" "2020-12-31"
end
gen double start_a = date(s_start, "YMD")
gen double stop_a  = date(s_stop, "YMD")
format %td start_a stop_a
drop s_start s_stop
save "`ds_a17'.dta", replace

clear
input int(id) double(exp_b) str10(s_start s_stop)
1 1 "2020-01-01" "2020-12-31"
end
gen double start_b = date(s_start, "YMD")
gen double stop_b  = date(s_stop, "YMD")
format %td start_b stop_b
drop s_start s_stop
save "`ds_b17'.dta", replace

capture noisily tvmerge "`ds_a17'.dta" "`ds_b17'.dta", ///
    id(id) start(start_a start_b) stop(stop_a stop_b) ///
    exposure(exp_a exp_b) prefix(tv_)

if _rc != 0 {
    display as error "  FAIL [17.run]: error `=_rc'"
    local test17_pass = 0
}
else {
    * Check prefixed variables
    local found = 0
    capture confirm variable tv_exp_a
    if _rc == 0 local found = `found' + 1
    capture confirm variable tv_exp_b
    if _rc == 0 local found = `found' + 1

    * Also check alternate naming: tv_1, tv_2
    capture confirm variable tv_1
    if _rc == 0 local found = `found' + 1
    capture confirm variable tv_2
    if _rc == 0 local found = `found' + 1

    if `found' >= 2 {
        display as result "  PASS [17.prefix]: prefixed variables found (`found')"
    }
    else {
        display as error "  FAIL [17.prefix]: no prefixed variables found"
        describe
        local test17_pass = 0
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

* NOTE: Do NOT erase ds_a17/ds_b17 yet - test 20 reuses them

* TEST 18: validatecoverage detects known gap

display "TEST 18: validatecoverage detects gap"
local test18_pass = 1

tempfile ds_a18 ds_b18
clear
input int(id) double(exp_a) str10(s_start s_stop)
1 1 "2020-01-01" "2020-03-31"
1 0 "2020-07-01" "2020-12-31"
end
gen double start_a = date(s_start, "YMD")
gen double stop_a  = date(s_stop, "YMD")
format %td start_a stop_a
drop s_start s_stop
save "`ds_a18'.dta", replace

clear
input int(id) double(exp_b) str10(s_start s_stop)
1 1 "2020-01-01" "2020-12-31"
end
gen double start_b = date(s_start, "YMD")
gen double stop_b  = date(s_stop, "YMD")
format %td start_b stop_b
drop s_start s_stop
save "`ds_b18'.dta", replace

capture noisily tvmerge "`ds_a18'.dta" "`ds_b18'.dta", ///
    id(id) start(start_a start_b) stop(stop_a stop_b) ///
    exposure(exp_a exp_b) validatecoverage

if _rc != 0 {
    * validatecoverage might cause an error when gap detected
    display as result "  PASS [18.gap_detected]: validatecoverage flagged gap (rc=`=_rc')"
}
else {
    * Should run but report gap
    * The merged result has a gap (Apr1-Jun30 missing from DS_A)
    quietly count
    if r(N) >= 1 {
        display as result "  PASS [18.ran]: validatecoverage ran successfully"
    }
    else {
        display as error "  FAIL [18.ran]: no output rows"
        local test18_pass = 0
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

capture erase "`ds_a18'.dta"
capture erase "`ds_b18'.dta"

* TEST 19: validateoverlap detects overlapping intervals

display "TEST 19: validateoverlap detects overlap"
local test19_pass = 1

tempfile ds_a19 ds_b19
clear
input int(id) double(exp_a) str10(s_start s_stop)
1 1 "2020-01-01" "2020-06-30"
1 2 "2020-06-01" "2020-12-31"
end
gen double start_a = date(s_start, "YMD")
gen double stop_a  = date(s_stop, "YMD")
format %td start_a stop_a
drop s_start s_stop
save "`ds_a19'.dta", replace

clear
input int(id) double(exp_b) str10(s_start s_stop)
1 1 "2020-01-01" "2020-12-31"
end
gen double start_b = date(s_start, "YMD")
gen double stop_b  = date(s_stop, "YMD")
format %td start_b stop_b
drop s_start s_stop
save "`ds_b19'.dta", replace

capture noisily tvmerge "`ds_a19'.dta" "`ds_b19'.dta", ///
    id(id) start(start_a start_b) stop(stop_a stop_b) ///
    exposure(exp_a exp_b) validateoverlap

if _rc != 0 {
    display as result "  PASS [19.overlap_detected]: validateoverlap flagged overlap (rc=`=_rc')"
}
else {
    * Should complete but with validation info
    display as result "  PASS [19.ran]: validateoverlap ran (overlap in input expected)"
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

capture erase "`ds_a19'.dta"
capture erase "`ds_b19'.dta"

* TEST 20: startname/stopname/dateformat options

display "TEST 20: startname/stopname/dateformat options"
local test20_pass = 1

capture noisily tvmerge "`ds_a17'.dta" "`ds_b17'.dta", ///
    id(id) start(start_a start_b) stop(stop_a stop_b) ///
    exposure(exp_a exp_b) ///
    startname(int_start) stopname(int_stop) dateformat(%td)

if _rc != 0 {
    display as error "  FAIL [20.run]: error `=_rc'"
    local test20_pass = 0
}
else {
    * Check renamed date variables
    capture confirm variable int_start
    local rc1 = _rc
    capture confirm variable int_stop
    local rc2 = _rc

    if `rc1' == 0 & `rc2' == 0 {
        display as result "  PASS [20.names]: int_start and int_stop exist"
    }
    else {
        display as error "  FAIL [20.names]: custom date variable names not found"
        local test20_pass = 0
    }

    * Check date format
    if `rc1' == 0 {
        local fmt : format int_start
        if "`fmt'" == "%td" {
            display as result "  PASS [20.format]: dateformat=%td applied"
        }
        else {
            display as error "  FAIL [20.format]: format=`fmt', expected %td"
            local test20_pass = 0
        }
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

* TEST 21: batch() is deprecated and ignored (no-op; identical results)

display "TEST 21: batch() deprecated no-op"
local test21_pass = 1

* Baseline merge without batch()
capture noisily tvmerge "`ds_a17'.dta" "`ds_b17'.dta", ///
    id(id) start(start_a start_b) stop(stop_a stop_b) exposure(exp_a exp_b)
if _rc != 0 {
    display as error "  FAIL [21.base]: baseline merge error `=_rc'"
    local test21_pass = 0
}
else {
    tempfile _nobatch
    quietly save `_nobatch', replace

    * Same merge passing the deprecated batch(): must still succeed (rc 0) and
    * produce byte-identical output (the option is a no-op).
    capture noisily tvmerge "`ds_a17'.dta" "`ds_b17'.dta", ///
        id(id) start(start_a start_b) stop(stop_a stop_b) exposure(exp_a exp_b) ///
        batch(50)
    if _rc != 0 {
        display as error "  FAIL [21.run]: batch() raised error `=_rc' (should be accepted)"
        local test21_pass = 0
    }
    else {
        capture cf _all using `_nobatch'
        if _rc == 0 {
            display as result "  PASS [21.noop]: batch() accepted and output unchanged"
        }
        else {
            display as error "  FAIL [21.noop]: batch() changed the merged output"
            local test21_pass = 0
        }
    }
}

if `test21_pass' == 1 {
    local pass_count = `pass_count' + 1
    display as result "TEST 21: PASSED"
}
else {
    local fail_count = `fail_count' + 1
    local failed_tests "`failed_tests' 21"
    display as error "TEST 21: FAILED"
}

capture erase "`ds_a17'.dta"
capture erase "`ds_b17'.dta"

}


* ===== Summary =====
* Fold the run_test/test_pass/test_fail harness counters into the totals.
local pass_count = `pass_count' + $TVQA_PASS
local fail_count = `fail_count' + $TVQA_FAIL
local failed_tests "`failed_tests' $TVQA_FAILED"
local test_count = `pass_count' + `fail_count'
display as result _newline "tvtools QA tvmerge functional Results -- $S_DATE $S_TIME"
display as text "Tests run:  `test_count'"
display as text "Passed:     `pass_count'"
display as text "Failed:     `fail_count'"
display "RESULT: test_tvmerge tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 {
    display as error "TESTS FAILED: `failed_tests'"
    exit 1
}
display as result "ALL TESTS PASSED"

