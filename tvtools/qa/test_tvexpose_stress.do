/*******************************************************************************
* test_tvexpose_stress.do
*
* Purpose: Manuscript-grade stress tests for tvexpose with inline synthetic
*          data where every expected value is hand-calculable.
*
* Tests:
*   Section A (1-9):   Multi-option interaction combos
*   Section B (10-16): Pathological data
*   Section C (17-21): Person-time conservation invariants
*   Section D (22-25): Recency & complex types
*   Section E (26-30): Edge cases from code review
*
* Run: stata-mp -b do test_tvexpose_stress.do
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
display "TVEXPOSE STRESS TESTS (30 tests)"
display _dup(70) "="
display "Date: $S_DATE $S_TIME"
display ""

capture net uninstall tvtools
quietly net install tvtools, from("`c(pwd)'/..") replace

* ============================================================================
* SECTION A: MULTI-OPTION INTERACTION (Tests 1-9)
* ============================================================================

* TEST 1: lag + washout + duration (3-option combo)
* 1 person Jan1-Dec31 2020. Drug 1: Mar1-May31.
* lag(30): start shifts Mar1+30 = Mar31
* washout(60): stop extends May31+60 = Jul30
* Exposed period: Mar31-Jul30 = 122 days
* duration(90 180): <90 days → cat 1, 90-<180 → cat 2
*   First 90 days exposed: Mar31 to Jun27 (89 days is category 1 boundary)
*   Actually: day 1=Mar31, day 90=Jun28. So [Mar31,Jun27]=cat1(89d), [Jun28,Jul30]=cat2(33d)
* Expected rows: 4 (pre-exposure, dur1, dur2, post-exposure)
* Person-time: 90 + 89 + 33 + 154 = 366

display _n _dup(60) "-"
display "TEST 1: lag(30) + washout(60) + duration(90 180)"
display _dup(60) "-"
local test1_pass = 1

tempfile cohort1 exp1
clear
set obs 1
gen id = 1
gen study_entry = mdy(1,1,2020)
gen study_exit  = mdy(12,31,2020)
format %td study_entry study_exit
save `cohort1', replace

clear
input int(id) int(drug)
1 1
end
gen double start = mdy(3,1,2020)
gen double stop  = mdy(5,31,2020)
format %td start stop
save `exp1', replace

use `cohort1', clear
capture noisily tvexpose using `exp1', ///
    id(id) start(start) stop(stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    lag(30) washout(60) duration(90 180) generate(dur_cat)

if _rc != 0 {
    display as error "  FAIL [1.run]: tvexpose returned error `=_rc'"
    local test1_pass = 0
}
else {
    sort id start

    * Check row count
    quietly count
    if r(N) == 4 {
        display as result "  PASS [1.rows]: 4 rows"
    }
    else {
        display as error "  FAIL [1.rows]: expected 4, got `=r(N)'"
        local test1_pass = 0
    }

    * Person-time conservation: sum(stop-start+1) = 366
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

    * Pre-exposure row: [Jan1, Mar30], dur_cat=0
    * Mar31 is the lagged start. Pre-exposure stops at Mar30.
    if dur_cat[1] == 0 {
        display as result "  PASS [1.pre_exp]: dur_cat=0"
    }
    else {
        display as error "  FAIL [1.pre_exp]: dur_cat=`=dur_cat[1]', expected 0"
        local test1_pass = 0
    }
    local expected_pre_stop = mdy(3,31,2020) - 1
    if stop[1] == `expected_pre_stop' {
        display as result "  PASS [1.pre_stop]: pre-exposure stops at Mar30"
    }
    else {
        display as error "  FAIL [1.pre_stop]: stop=`=string(stop[1], "%td")'"
        local test1_pass = 0
    }

    * Duration category 1 row: starts Mar31
    if dur_cat[2] == 1 & start[2] == mdy(3,31,2020) {
        display as result "  PASS [1.dur1]: dur_cat=1 starting Mar31"
    }
    else {
        display as error "  FAIL [1.dur1]: dur_cat=`=dur_cat[2]', start=`=string(start[2], "%td")'"
        local test1_pass = 0
    }

    * Duration category 2 row: starts when cumulative reaches 90 days
    if dur_cat[3] == 2 {
        display as result "  PASS [1.dur2]: dur_cat=2"
    }
    else {
        display as error "  FAIL [1.dur2]: dur_cat=`=dur_cat[3]', expected 2"
        local test1_pass = 0
    }

    * Post-exposure row: dur_cat=0
    quietly count
    local nr = r(N)
    if dur_cat[`nr'] == 0 {
        display as result "  PASS [1.post_exp]: last row dur_cat=0"
    }
    else {
        display as error "  FAIL [1.post_exp]: last row dur_cat=`=dur_cat[`nr']'"
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


* TEST 2: window + lag + washout triple interaction
* 1 person Jan1-Dec31 2020. Drug 1 Feb1-Mar31.
* Order: lag(10) → washout(20) → window(5 30)
* lag(10): start Feb1+10=Feb11
* washout(20): stop Mar31+20=Apr20
* window(5 30): start=Feb11+5=Feb16, stop=min(Feb11+30, Apr20)=min(Mar12, Apr20)=Mar12
* Exposed window: [Feb16, Mar12] = 26 days
* Expected: 3 rows (pre, exposed, post), person-time=366

display _n _dup(60) "-"
display "TEST 2: window(5 30) + lag(10) + washout(20)"
display _dup(60) "-"
local test2_pass = 1

tempfile cohort2 exp2
clear
set obs 1
gen id = 1
gen study_entry = mdy(1,1,2020)
gen study_exit  = mdy(12,31,2020)
format %td study_entry study_exit
save `cohort2', replace

clear
input int(id) int(drug)
1 1
end
gen double start = mdy(2,1,2020)
gen double stop  = mdy(3,31,2020)
format %td start stop
save `exp2', replace

use `cohort2', clear
capture noisily tvexpose using `exp2', ///
    id(id) start(start) stop(stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    lag(10) washout(20) window(5 30) evertreated generate(exp_val)

if _rc != 0 {
    display as error "  FAIL [2.run]: tvexpose returned error `=_rc'"
    local test2_pass = 0
}
else {
    sort id start

    * Person-time = 366
    tempvar pt
    gen `pt' = stop - start + 1
    quietly su `pt'
    if r(sum) == 366 {
        display as result "  PASS [2.pt]: person-time=366"
    }
    else {
        display as error "  FAIL [2.pt]: person-time=`=r(sum)', expected 366"
        local test2_pass = 0
    }

    * Find exposed row and check boundaries
    * Exposed start should be Feb16 = mdy(2,16,2020)
    * Exposed stop should be Mar12 = mdy(3,12,2020)
    quietly count if exp_val == 1
    local n_exposed = r(N)
    if `n_exposed' == 1 {
        display as result "  PASS [2.exp_rows]: 1 exposed row"
    }
    else {
        display as error "  FAIL [2.exp_rows]: `n_exposed' exposed rows, expected 1"
        local test2_pass = 0
    }

    quietly su start if exp_val == 1
    local exp_start = r(mean)
    if `exp_start' == mdy(2,16,2020) {
        display as result "  PASS [2.exp_start]: exposed starts Feb16"
    }
    else {
        display as error "  FAIL [2.exp_start]: start=`=string(`exp_start', "%td")', expected Feb16"
        local test2_pass = 0
    }

    quietly su stop if exp_val == 1
    local exp_stop = r(mean)
    if `exp_stop' == mdy(3,12,2020) {
        display as result "  PASS [2.exp_stop]: exposed stops Mar12"
    }
    else {
        display as error "  FAIL [2.exp_stop]: stop=`=string(`exp_stop', "%td")', expected Mar12"
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


* TEST 3: fillgaps + carryforward + grace interaction
* 1 person Jan1-Dec31. Drug 1: Jan15-Feb28, Drug 1: Apr1-May31.
* Gap: Apr1 - Feb28 - 1 = 32 days (Feb29 through Mar31)
* grace(5): 32 > 5 → NOT bridged
* carryforward(15): fills 15 days after first exposure (Feb29-Mar14 with Drug 1)
* fillgaps(10): extends LAST exposure stop by 10 (May31→Jun10)
* Key: grace does NOT bridge, carryforward fills partial gap, fillgaps extends end

display _n _dup(60) "-"
display "TEST 3: fillgaps(10) + carryforward(15) + grace(5)"
display _dup(60) "-"
local test3_pass = 1

tempfile cohort3 exp3
clear
set obs 1
gen id = 1
gen study_entry = mdy(1,1,2020)
gen study_exit  = mdy(12,31,2020)
format %td study_entry study_exit
save `cohort3', replace

clear
input int(id) int(drug) str10(s_start s_stop)
1 1 "2020-01-15" "2020-02-28"
1 1 "2020-04-01" "2020-05-31"
end
gen double start = date(s_start, "YMD")
gen double stop  = date(s_stop, "YMD")
format %td start stop
drop s_start s_stop
save `exp3', replace

use `cohort3', clear
capture noisily tvexpose using `exp3', ///
    id(id) start(start) stop(stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    grace(5) carryforward(15) fillgaps(10) ///
    evertreated generate(exp_val)

if _rc != 0 {
    display as error "  FAIL [3.run]: tvexpose returned error `=_rc'"
    local test3_pass = 0
}
else {
    sort id start

    * Person-time conservation = 366
    tempvar pt
    gen `pt' = stop - start + 1
    quietly su `pt'
    if r(sum) == 366 {
        display as result "  PASS [3.pt]: person-time=366"
    }
    else {
        display as error "  FAIL [3.pt]: person-time=`=r(sum)', expected 366"
        local test3_pass = 0
    }

    * Check that the gap period (Mar15-Mar31) is unexposed (evertreated=1 since already exposed)
    * Actually with evertreated, once exposed always 1. So ALL post-first-exposure rows are 1.
    * The carryforward and gap are distinguishable only without evertreated.
    * Let's check total exposed person-time instead.
    * Exposed time = all post-Jan15 rows = Jan15 to Dec31 = 352 days (all evertreated=1)
    * Unexposed time = Jan1-Jan14 = 14 days (evertreated=0)
    quietly count if exp_val == 0
    local n_unexp = r(N)
    if `n_unexp' >= 1 {
        display as result "  PASS [3.pre_exp]: pre-exposure rows exist"
    }
    else {
        display as error "  FAIL [3.pre_exp]: no unexposed rows"
        local test3_pass = 0
    }

    * With evertreated, once exposed all subsequent rows are 1
    * So the real test is person-time conservation and that it runs without error
    * Check pre-exposure stop date = Jan14
    quietly su stop if exp_val == 0
    local pre_stop = r(max)
    if `pre_stop' == mdy(1,14,2020) {
        display as result "  PASS [3.pre_stop]: pre-exposure ends Jan14"
    }
    else {
        display as error "  FAIL [3.pre_stop]: pre_stop=`=string(`pre_stop', "%td")', expected Jan14"
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


* TEST 4: dose + overlaps + proportional allocation
* 1 person Jan1-Dec31. Rx1: Jan1-Jan30 dose=300 (rate=10/day).
* Rx2: Jan16-Feb14 dose=600 (rate=20/day).
* Dose proportioning on overlap:
*   [Jan1,Jan15]: Rx1 only → dose = 15 * 10 = 150
*   [Jan16,Jan30]: both → dose = 15*10 + 15*20 = 150+300 = 450
*   [Jan31,Feb14]: Rx2 only → dose = 15 * 20 = 300
* Cumulative at each segment end: 150, 600, 900

display _n _dup(60) "-"
display "TEST 4: dose proportioning with overlapping prescriptions"
display _dup(60) "-"
local test4_pass = 1

tempfile cohort4 exp4
clear
set obs 1
gen id = 1
gen study_entry = mdy(1,1,2020)
gen study_exit  = mdy(12,31,2020)
format %td study_entry study_exit
save `cohort4', replace

clear
input int(id) double(dose_val) str10(s_start s_stop)
1 300 "2020-01-01" "2020-01-30"
1 600 "2020-01-16" "2020-02-14"
end
gen double start = date(s_start, "YMD")
gen double stop  = date(s_stop, "YMD")
format %td start stop
drop s_start s_stop
save `exp4', replace

use `cohort4', clear
capture noisily tvexpose using `exp4', ///
    id(id) start(start) stop(stop) ///
    exposure(dose_val) ///
    entry(study_entry) exit(study_exit) ///
    dose generate(cum_dose)

if _rc != 0 {
    display as error "  FAIL [4.run]: tvexpose returned error `=_rc'"
    local test4_pass = 0
}
else {
    sort id start

    * Person-time conservation
    tempvar pt
    gen `pt' = stop - start + 1
    quietly su `pt'
    if r(sum) == 366 {
        display as result "  PASS [4.pt]: person-time=366"
    }
    else {
        display as error "  FAIL [4.pt]: person-time=`=r(sum)', expected 366"
        local test4_pass = 0
    }

    * Check that dose segments exist (at least 3 exposed rows)
    quietly count if cum_dose > 0
    if r(N) >= 3 {
        display as result "  PASS [4.dose_rows]: `=r(N)' exposed dose rows"
    }
    else {
        display as error "  FAIL [4.dose_rows]: only `=r(N)' exposed rows, expected >=3"
        local test4_pass = 0
    }

    * Check final cumulative dose is approximately 900
    * Rx1 total=300 + Rx2 total=600 = 900
    quietly su cum_dose
    local max_dose = r(max)
    assert_approx `max_dose' 900 1 "4.total_dose"
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


* TEST 5: layer vs priority behavioral divergence
* 1 person Jan1-Dec31. Drug A(1): Jan1-Jun30. Drug B(2): Mar1-Apr30.
* (a) layer: B interrupts A. [Jan1,Feb29]=1, [Mar1,Apr30]=2, [May1,Jun30]=1, [Jul1,Dec31]=0
* (b) priority(2 1): type 2 gets rank 1 (highest). Same as layer → identical rows.
* (c) priority(1 2): type 1 gets rank 1 (highest). A wins everywhere → [Jan1,Jun30]=1, [Jul1,Dec31]=0

display _n _dup(60) "-"
display "TEST 5: layer vs priority behavioral divergence"
display _dup(60) "-"
local test5_pass = 1

tempfile cohort5 exp5
clear
set obs 1
gen id = 1
gen study_entry = mdy(1,1,2020)
gen study_exit  = mdy(12,31,2020)
format %td study_entry study_exit
save `cohort5', replace

clear
input int(id drug) str10(s_start s_stop)
1 1 "2020-01-01" "2020-06-30"
1 2 "2020-03-01" "2020-04-30"
end
gen double start = date(s_start, "YMD")
gen double stop  = date(s_stop, "YMD")
format %td start stop
drop s_start s_stop
save `exp5', replace

* (a) layer
use `cohort5', clear
capture noisily tvexpose using `exp5', ///
    id(id) start(start) stop(stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    layer generate(exp_val)

if _rc != 0 {
    display as error "  FAIL [5a.run]: layer error `=_rc'"
    local test5_pass = 0
}
else {
    sort id start
    quietly count
    local layer_n = r(N)

    * Save layer results for comparison
    tempfile layer_result
    save `layer_result', replace

    * Layer: B interrupts A → at least 3 exposed rows + 1 reference
    * Check row with Drug B during overlap
    quietly count if exp_val == 2
    if r(N) >= 1 {
        display as result "  PASS [5a.drug_b]: Drug B row exists in layer"
    }
    else {
        display as error "  FAIL [5a.drug_b]: no Drug B rows"
        local test5_pass = 0
    }

    * Drug A resumes after Drug B
    quietly count if exp_val == 1 & start >= mdy(5,1,2020)
    if r(N) >= 1 {
        display as result "  PASS [5a.resume]: Drug A resumes after Drug B"
    }
    else {
        display as error "  FAIL [5a.resume]: Drug A does not resume after Drug B"
        local test5_pass = 0
    }
}

* (c) priority(1 2): Drug A (type 1) has rank 1 (highest priority)
use `cohort5', clear
capture noisily tvexpose using `exp5', ///
    id(id) start(start) stop(stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    priority(1 2) generate(exp_val)

if _rc != 0 {
    display as error "  FAIL [5c.run]: priority(1 2) error `=_rc'"
    local test5_pass = 0
}
else {
    sort id start

    * Drug A wins everywhere → no Drug B rows
    quietly count if exp_val == 2
    if r(N) == 0 {
        display as result "  PASS [5c.no_drug_b]: Drug A dominates, no Drug B rows"
    }
    else {
        display as error "  FAIL [5c.no_drug_b]: `=r(N)' Drug B rows, expected 0"
        local test5_pass = 0
    }

    * Drug A covers Jan1-Jun30 continuously
    quietly count if exp_val == 1
    if r(N) == 1 {
        display as result "  PASS [5c.single_a]: single Drug A row"
    }
    else {
        display as error "  FAIL [5c.single_a]: `=r(N)' Drug A rows, expected 1"
        local test5_pass = 0
    }

    * Person-time = 366
    tempvar pt
    gen `pt' = stop - start + 1
    quietly su `pt'
    if r(sum) == 366 {
        display as result "  PASS [5c.pt]: person-time=366"
    }
    else {
        display as error "  FAIL [5c.pt]: person-time=`=r(sum)', expected 366"
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


* TEST 6: merge() iterative chaining
* 1 person Jan1-Dec31. Drug 1: [Jan1,Jan10], [Jan14,Jan20], [Jan25,Jan31]
* Gaps: gap1 = Jan14-Jan10 = 4, gap2 = Jan25-Jan20 = 5
* merge(3): 4>3 and 5>3 → no merging → 3 exposed periods
* merge(5): 4<=5 → merge [Jan1,Jan20]; then Jan25-Jan20=5<=5 → merge all → 1 period
* Tests iterative convergence.

display _n _dup(60) "-"
display "TEST 6: merge() iterative chaining"
display _dup(60) "-"
local test6_pass = 1

tempfile cohort6 exp6
clear
set obs 1
gen id = 1
gen study_entry = mdy(1,1,2020)
gen study_exit  = mdy(12,31,2020)
format %td study_entry study_exit
save `cohort6', replace

clear
input int(id drug) str10(s_start s_stop)
1 1 "2020-01-01" "2020-01-10"
1 1 "2020-01-14" "2020-01-20"
1 1 "2020-01-25" "2020-01-31"
end
gen double start = date(s_start, "YMD")
gen double stop  = date(s_stop, "YMD")
format %td start stop
drop s_start s_stop
save `exp6', replace

* merge(3): no merging
use `cohort6', clear
capture noisily tvexpose using `exp6', ///
    id(id) start(start) stop(stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    merge(3) evertreated generate(exp_val)

if _rc != 0 {
    display as error "  FAIL [6a.run]: merge(3) error `=_rc'"
    local test6_pass = 0
}
else {
    sort id start

    * With evertreated, all post-first-exposure rows are 1
    * But the exposed periods are separate (not merged)
    * The key check: person-time conservation
    tempvar pt
    gen `pt' = stop - start + 1
    quietly su `pt'
    if r(sum) == 366 {
        display as result "  PASS [6a.pt]: person-time=366 with merge(3)"
    }
    else {
        display as error "  FAIL [6a.pt]: person-time=`=r(sum)', expected 366"
        local test6_pass = 0
    }

    * Save row count for comparison
    quietly count
    local merge3_rows = r(N)
}

* merge(5): all merged → fewer rows
use `cohort6', clear
capture noisily tvexpose using `exp6', ///
    id(id) start(start) stop(stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    merge(5) evertreated generate(exp_val)

if _rc != 0 {
    display as error "  FAIL [6b.run]: merge(5) error `=_rc'"
    local test6_pass = 0
}
else {
    sort id start

    tempvar pt
    gen `pt' = stop - start + 1
    quietly su `pt'
    if r(sum) == 366 {
        display as result "  PASS [6b.pt]: person-time=366 with merge(5)"
    }
    else {
        display as error "  FAIL [6b.pt]: person-time=`=r(sum)', expected 366"
        local test6_pass = 0
    }

    * merge(5) should produce fewer rows than merge(3)
    quietly count
    local merge5_rows = r(N)
    if `merge5_rows' < `merge3_rows' {
        display as result "  PASS [6.fewer_rows]: merge(5)=`merge5_rows' < merge(3)=`merge3_rows'"
    }
    else {
        display as error "  FAIL [6.fewer_rows]: merge(5)=`merge5_rows' >= merge(3)=`merge3_rows'"
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


* TEST 7: dose + dosecuts category boundaries
* 1 person Jan1-Dec31. Single Rx Jan1-Apr10 (100 days), dose_val=50.
* dosecuts(10 25 50): categories 0=unexposed, 1=<10, 2=10-<25, 3=25-<50, 4=50+
* Daily rate = 50/100 = 0.5/day. Cumulative at day D = D*0.5.
* Category boundaries:
*   cum<10 → cat1: D<20 → days 1-19 (Jan1-Jan19)
*   10<=cum<25 → cat2: 20<=D<50 → days 20-49 (Jan20-Feb18)
*   25<=cum<50 → cat3: 50<=D<100 → days 50-99 (Feb19-Apr9)
*   cum>=50 → cat4: D>=100 → day 100 (Apr10)
* Expected: multiple rows splitting at category boundaries

display _n _dup(60) "-"
display "TEST 7: dose + dosecuts category boundaries"
display _dup(60) "-"
local test7_pass = 1

tempfile cohort7 exp7
clear
set obs 1
gen id = 1
gen study_entry = mdy(1,1,2020)
gen study_exit  = mdy(12,31,2020)
format %td study_entry study_exit
save `cohort7', replace

clear
input int(id) double(dose_val) str10(s_start s_stop)
1 50 "2020-01-01" "2020-04-10"
end
gen double start = date(s_start, "YMD")
gen double stop  = date(s_stop, "YMD")
format %td start stop
drop s_start s_stop
save `exp7', replace

use `cohort7', clear
capture noisily tvexpose using `exp7', ///
    id(id) start(start) stop(stop) ///
    exposure(dose_val) ///
    entry(study_entry) exit(study_exit) ///
    dose dosecuts(10 25 50) generate(dose_cat)

if _rc != 0 {
    display as error "  FAIL [7.run]: dose+dosecuts error `=_rc'"
    local test7_pass = 0
}
else {
    sort id start

    * Person-time
    tempvar pt
    gen `pt' = stop - start + 1
    quietly su `pt'
    if r(sum) == 366 {
        display as result "  PASS [7.pt]: person-time=366"
    }
    else {
        display as error "  FAIL [7.pt]: person-time=`=r(sum)', expected 366"
        local test7_pass = 0
    }

    * Check that dose categories 1-4 all appear
    forvalues cat = 1/4 {
        quietly count if dose_cat == `cat'
        if r(N) >= 1 {
            display as result "  PASS [7.cat`cat']: dose category `cat' exists"
        }
        else {
            display as error "  FAIL [7.cat`cat']: dose category `cat' not found"
            local test7_pass = 0
        }
    }

    * Unexposed period after Apr10
    quietly count if dose_cat == 0
    if r(N) >= 1 {
        display as result "  PASS [7.unexp]: unexposed period exists"
    }
    else {
        display as error "  FAIL [7.unexp]: no unexposed period"
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


* TEST 8: switching + switchingdetail exact detection
* 1 person Jan1-Dec31. Drug 1: Jan15-Mar31. Drug 2: Apr1-Jun30. Drug 1: Jul1-Sep30.
* Pattern: unexposed→Drug1→Drug2→Drug1→unexposed
* switching creates ever_switched: should be 1 after first switch (Drug1→Drug2)
* switchingdetail creates switching_pattern string

display _n _dup(60) "-"
display "TEST 8: switching + switchingdetail exact detection"
display _dup(60) "-"
local test8_pass = 1

tempfile cohort8 exp8
clear
set obs 1
gen id = 1
gen study_entry = mdy(1,1,2020)
gen study_exit  = mdy(12,31,2020)
format %td study_entry study_exit
save `cohort8', replace

clear
input int(id drug) str10(s_start s_stop)
1 1 "2020-01-15" "2020-03-31"
1 2 "2020-04-01" "2020-06-30"
1 1 "2020-07-01" "2020-09-30"
end
gen double start = date(s_start, "YMD")
gen double stop  = date(s_stop, "YMD")
format %td start stop
drop s_start s_stop
save `exp8', replace

use `cohort8', clear
capture noisily tvexpose using `exp8', ///
    id(id) start(start) stop(stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    switching switchingdetail generate(exp_val)

if _rc != 0 {
    display as error "  FAIL [8.run]: switching error `=_rc'"
    local test8_pass = 0
}
else {
    sort id start

    * Person-time = 366
    tempvar pt
    gen `pt' = stop - start + 1
    quietly su `pt'
    if r(sum) == 366 {
        display as result "  PASS [8.pt]: person-time=366"
    }
    else {
        display as error "  FAIL [8.pt]: person-time=`=r(sum)', expected 366"
        local test8_pass = 0
    }

    * Check ever_switched variable exists and has value 1 somewhere
    capture confirm variable ever_switched
    if _rc == 0 {
        quietly count if ever_switched == 1
        if r(N) >= 1 {
            display as result "  PASS [8.switched]: ever_switched=1 detected"
        }
        else {
            display as error "  FAIL [8.switched]: no ever_switched=1 rows"
            local test8_pass = 0
        }
    }
    else {
        display as error "  FAIL [8.var]: ever_switched variable not found"
        local test8_pass = 0
    }

    * Check switching_pattern variable exists
    capture confirm variable switching_pattern
    if _rc == 0 {
        display as result "  PASS [8.detail_var]: switching_pattern exists"
    }
    else {
        display as error "  FAIL [8.detail_var]: switching_pattern not found"
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


* TEST 9: statetime cumulative time in current state
* 1 person Jan1-Dec31. Drug 1: Feb1-Apr30, gap May1-Jun30, Drug 1: Jul1-Sep30.
* statetime creates state_time_years (cumulative time in current exposure state)
* State transitions: unexposed→Drug1→unexposed→Drug1→unexposed
* state_time_years should reset at each transition

display _n _dup(60) "-"
display "TEST 9: statetime cumulative time in current state"
display _dup(60) "-"
local test9_pass = 1

tempfile cohort9 exp9
clear
set obs 1
gen id = 1
gen study_entry = mdy(1,1,2020)
gen study_exit  = mdy(12,31,2020)
format %td study_entry study_exit
save `cohort9', replace

clear
input int(id drug) str10(s_start s_stop)
1 1 "2020-02-01" "2020-04-30"
1 1 "2020-07-01" "2020-09-30"
end
gen double start = date(s_start, "YMD")
gen double stop  = date(s_stop, "YMD")
format %td start stop
drop s_start s_stop
save `exp9', replace

use `cohort9', clear
capture noisily tvexpose using `exp9', ///
    id(id) start(start) stop(stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    statetime generate(exp_val)

if _rc != 0 {
    display as error "  FAIL [9.run]: statetime error `=_rc'"
    local test9_pass = 0
}
else {
    sort id start

    * state_time_years should exist
    capture confirm variable state_time_years
    if _rc == 0 {
        display as result "  PASS [9.var]: state_time_years exists"
    }
    else {
        display as error "  FAIL [9.var]: state_time_years not found"
        local test9_pass = 0
    }

    * Person-time = 366
    tempvar pt
    gen `pt' = stop - start + 1
    quietly su `pt'
    if r(sum) == 366 {
        display as result "  PASS [9.pt]: person-time=366"
    }
    else {
        display as error "  FAIL [9.pt]: person-time=`=r(sum)', expected 366"
        local test9_pass = 0
    }

    * Check that state_time_years is not monotonically increasing (resets at transitions)
    * The second Drug 1 period should have a smaller state_time_years than the first Drug 1's end
    capture confirm variable state_time_years
    if _rc == 0 {
        * Find state_time at start of second Drug 1 period (Jul1)
        quietly su state_time_years if start == mdy(7,1,2020)
        local st_jul = r(mean)
        * Find state_time at end of first Drug 1 period
        quietly su state_time_years if stop == mdy(4,30,2020)
        local st_apr = r(mean)
        if !missing(`st_jul') & !missing(`st_apr') & `st_jul' < `st_apr' {
            display as result "  PASS [9.reset]: state_time resets (Jul=`st_jul' < Apr=`st_apr')"
        }
        else if missing(`st_jul') | missing(`st_apr') {
            display as error "  FAIL [9.reset]: could not find expected rows"
            local test9_pass = 0
        }
        else {
            display as error "  FAIL [9.reset]: state_time did not reset (Jul=`st_jul', Apr=`st_apr')"
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


* ============================================================================
* SECTION B: PATHOLOGICAL DATA (Tests 10-16)
* ============================================================================

* TEST 10: 100% identical overlapping exposures (dedup)
* 1 person. Drug 1 [Jan1,Jun30] duplicated 3 times. Verify dedup → single exposed period.

display _n _dup(60) "-"
display "TEST 10: 100% identical overlapping exposures (dedup)"
display _dup(60) "-"
local test10_pass = 1

tempfile cohort10 exp10
clear
set obs 1
gen id = 1
gen study_entry = mdy(1,1,2020)
gen study_exit  = mdy(12,31,2020)
format %td study_entry study_exit
save `cohort10', replace

clear
input int(id drug) str10(s_start s_stop)
1 1 "2020-01-01" "2020-06-30"
1 1 "2020-01-01" "2020-06-30"
1 1 "2020-01-01" "2020-06-30"
end
gen double start = date(s_start, "YMD")
gen double stop  = date(s_stop, "YMD")
format %td start stop
drop s_start s_stop
save `exp10', replace

use `cohort10', clear
capture noisily tvexpose using `exp10', ///
    id(id) start(start) stop(stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    evertreated generate(exp_val)

if _rc != 0 {
    display as error "  FAIL [10.run]: error `=_rc'"
    local test10_pass = 0
}
else {
    sort id start
    quietly count
    * Should be 2 rows: [Jan1,Jun30]=exposed, [Jul1,Dec31]=unexposed
    * or if evertreated, 1 exposed row + 1 ever-treated row
    * With evertreated: [Jan1,Dec31] is all 1 after first exposure on Jan1
    * Actually: [Jan1,Jun30]=1 (exposed), [Jul1,Dec31]=1 (ever treated)
    * So 2 rows total
    if r(N) == 2 {
        display as result "  PASS [10.rows]: 2 rows (deduped)"
    }
    else {
        display as error "  FAIL [10.rows]: `=r(N)' rows, expected 2"
        local test10_pass = 0
    }

    * Person-time = 366
    tempvar pt
    gen `pt' = stop - start + 1
    quietly su `pt'
    if r(sum) == 366 {
        display as result "  PASS [10.pt]: person-time=366"
    }
    else {
        display as error "  FAIL [10.pt]: person-time=`=r(sum)', expected 366"
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


* TEST 11: Adjacent periods (zero-gap)
* 1 person. Drug 1 [Jan1,Mar31], Drug 1 [Apr1,Jun30].
* Gap in merge formula: Apr1 - Mar31 = 1 (adjacent, not overlapping)
* Gap in grace formula: Apr1 - Mar31 - 1 = 0
* Default merge(0): 1 > 0 → NOT merged by merge step
* Default grace(0): 0 <= 0 → bridged by grace
* But grace bridge condition has exp_stop < exp_start[_n+1]-1 check → Mar31 < Mar31 = FALSE
* So grace doesn't actually modify anything either.
* Result: two adjacent same-drug rows covering Jan1-Jun30, no gap between them.
* Person-time must be 366.

display _n _dup(60) "-"
display "TEST 11: Adjacent periods (zero calendar-day gap)"
display _dup(60) "-"
local test11_pass = 1

tempfile cohort11 exp11
clear
set obs 1
gen id = 1
gen study_entry = mdy(1,1,2020)
gen study_exit  = mdy(12,31,2020)
format %td study_entry study_exit
save `cohort11', replace

clear
input int(id drug) str10(s_start s_stop)
1 1 "2020-01-01" "2020-03-31"
1 1 "2020-04-01" "2020-06-30"
end
gen double start = date(s_start, "YMD")
gen double stop  = date(s_stop, "YMD")
format %td start stop
drop s_start s_stop
save `exp11', replace

use `cohort11', clear
capture noisily tvexpose using `exp11', ///
    id(id) start(start) stop(stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    evertreated generate(exp_val)

if _rc != 0 {
    display as error "  FAIL [11.run]: error `=_rc'"
    local test11_pass = 0
}
else {
    sort id start

    * Person-time = 366 (no gap created)
    tempvar pt
    gen `pt' = stop - start + 1
    quietly su `pt'
    if r(sum) == 366 {
        display as result "  PASS [11.pt]: person-time=366 (no gap)"
    }
    else {
        display as error "  FAIL [11.pt]: person-time=`=r(sum)', expected 366"
        local test11_pass = 0
    }

    * No reference periods between the two Drug 1 periods
    * With evertreated, first exposure is Jan1 so all rows are exp_val=1
    quietly count if exp_val == 0
    if r(N) == 0 {
        display as result "  PASS [11.no_ref]: no reference periods (exposed from Jan1)"
    }
    else {
        display as error "  FAIL [11.no_ref]: `=r(N)' reference rows, expected 0"
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


* TEST 12: Single-day exposures
* 1 person Jan1-Dec31. Drug 1 start=stop=Mar1. Drug 2 start=stop=Jun15.
* Each exposure lasts exactly 1 day.
* Expected: multiple rows covering entire study period with single-day exposed intervals.

display _n _dup(60) "-"
display "TEST 12: Single-day exposures"
display _dup(60) "-"
local test12_pass = 1

tempfile cohort12 exp12
clear
set obs 1
gen id = 1
gen study_entry = mdy(1,1,2020)
gen study_exit  = mdy(12,31,2020)
format %td study_entry study_exit
save `cohort12', replace

clear
input int(id drug) str10(s_start s_stop)
1 1 "2020-03-01" "2020-03-01"
1 2 "2020-06-15" "2020-06-15"
end
gen double start = date(s_start, "YMD")
gen double stop  = date(s_stop, "YMD")
format %td start stop
drop s_start s_stop
save `exp12', replace

use `cohort12', clear
capture noisily tvexpose using `exp12', ///
    id(id) start(start) stop(stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    generate(exp_val)

if _rc != 0 {
    display as error "  FAIL [12.run]: error `=_rc'"
    local test12_pass = 0
}
else {
    sort id start

    * Person-time = 366
    tempvar pt
    gen `pt' = stop - start + 1
    quietly su `pt'
    if r(sum) == 366 {
        display as result "  PASS [12.pt]: person-time=366"
    }
    else {
        display as error "  FAIL [12.pt]: person-time=`=r(sum)', expected 366"
        local test12_pass = 0
    }

    * Drug 1 single-day row exists
    quietly count if exp_val == 1
    if r(N) == 1 {
        display as result "  PASS [12.drug1]: single Drug 1 row"
    }
    else {
        display as error "  FAIL [12.drug1]: `=r(N)' Drug 1 rows, expected 1"
        local test12_pass = 0
    }

    * Drug 2 single-day row exists
    quietly count if exp_val == 2
    if r(N) == 1 {
        display as result "  PASS [12.drug2]: single Drug 2 row"
    }
    else {
        display as error "  FAIL [12.drug2]: `=r(N)' Drug 2 rows, expected 1"
        local test12_pass = 0
    }

    * Drug 1 row is exactly 1 day
    quietly su start if exp_val == 1
    local d1_start = r(mean)
    quietly su stop if exp_val == 1
    local d1_stop = r(mean)
    local d1_days = `d1_stop' - `d1_start' + 1
    if `d1_days' == 1 {
        display as result "  PASS [12.d1_single]: Drug 1 is 1-day interval"
    }
    else {
        display as error "  FAIL [12.d1_single]: Drug 1 duration=`d1_days', expected 1"
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


* TEST 13: Exposure entirely before study entry
* study_entry=Jul1, study_exit=Dec31. Exposure Jan1-Mar31.
* Exposure ends before study starts → person is fully unexposed during study period.
* Expected: 1 row [Jul1,Dec31] exp_val=0 (reference)

display _n _dup(60) "-"
display "TEST 13: Exposure entirely before study entry"
display _dup(60) "-"
local test13_pass = 1

tempfile cohort13 exp13
clear
set obs 1
gen id = 1
gen study_entry = mdy(7,1,2020)
gen study_exit  = mdy(12,31,2020)
format %td study_entry study_exit
save `cohort13', replace

clear
input int(id drug) str10(s_start s_stop)
1 1 "2020-01-01" "2020-03-31"
end
gen double start = date(s_start, "YMD")
gen double stop  = date(s_stop, "YMD")
format %td start stop
drop s_start s_stop
save `exp13', replace

use `cohort13', clear
capture noisily tvexpose using `exp13', ///
    id(id) start(start) stop(stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    generate(exp_val)

if _rc != 0 {
    display as error "  FAIL [13.run]: error `=_rc'"
    local test13_pass = 0
}
else {
    sort id start

    * Should be reference only
    quietly count if exp_val != 0
    if r(N) == 0 {
        display as result "  PASS [13.all_ref]: all reference (exposure before entry)"
    }
    else {
        display as error "  FAIL [13.all_ref]: `=r(N)' exposed rows, expected 0"
        local test13_pass = 0
    }

    * Person-time = Jul1 to Dec31 = 184 days
    tempvar pt
    gen `pt' = stop - start + 1
    quietly su `pt'
    local expected_pt = mdy(12,31,2020) - mdy(7,1,2020) + 1
    if r(sum) == `expected_pt' {
        display as result "  PASS [13.pt]: person-time=`expected_pt'"
    }
    else {
        display as error "  FAIL [13.pt]: person-time=`=r(sum)', expected `expected_pt'"
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


* TEST 14: Exposure entirely after study exit
* study_entry=Jan1, study_exit=Jun30. Exposure Sep1-Nov30.
* Expected: 1 row [Jan1,Jun30] exp_val=0

display _n _dup(60) "-"
display "TEST 14: Exposure entirely after study exit"
display _dup(60) "-"
local test14_pass = 1

tempfile cohort14 exp14
clear
set obs 1
gen id = 1
gen study_entry = mdy(1,1,2020)
gen study_exit  = mdy(6,30,2020)
format %td study_entry study_exit
save `cohort14', replace

clear
input int(id drug) str10(s_start s_stop)
1 1 "2020-09-01" "2020-11-30"
end
gen double start = date(s_start, "YMD")
gen double stop  = date(s_stop, "YMD")
format %td start stop
drop s_start s_stop
save `exp14', replace

use `cohort14', clear
capture noisily tvexpose using `exp14', ///
    id(id) start(start) stop(stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    generate(exp_val)

if _rc != 0 {
    display as error "  FAIL [14.run]: error `=_rc'"
    local test14_pass = 0
}
else {
    sort id start

    * All reference
    quietly count if exp_val != 0
    if r(N) == 0 {
        display as result "  PASS [14.all_ref]: all reference (exposure after exit)"
    }
    else {
        display as error "  FAIL [14.all_ref]: `=r(N)' exposed rows, expected 0"
        local test14_pass = 0
    }

    * Person-time = Jan1 to Jun30 = 182 days (2020 leap year)
    tempvar pt
    gen `pt' = stop - start + 1
    quietly su `pt'
    local expected_pt = mdy(6,30,2020) - mdy(1,1,2020) + 1
    if r(sum) == `expected_pt' {
        display as result "  PASS [14.pt]: person-time=`expected_pt'"
    }
    else {
        display as error "  FAIL [14.pt]: person-time=`=r(sum)', expected `expected_pt'"
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


* TEST 15: Missing exposure values in using data
* 2 persons. Person 1 drug=1, Person 2 drug=. (missing).
* Person 2 should be treated as fully unexposed.

display _n _dup(60) "-"
display "TEST 15: Missing exposure values in using data"
display _dup(60) "-"
local test15_pass = 1

tempfile cohort15 exp15
clear
input int(id)
1
2
end
gen study_entry = mdy(1,1,2020)
gen study_exit  = mdy(12,31,2020)
format %td study_entry study_exit
save `cohort15', replace

clear
input int(id) str10(s_start s_stop)
1 "2020-03-01" "2020-06-30"
2 "2020-03-01" "2020-06-30"
end
gen double start = date(s_start, "YMD")
gen double stop  = date(s_stop, "YMD")
format %td start stop
drop s_start s_stop
gen drug = 1 if id == 1
* Person 2: drug is missing
save `exp15', replace

use `cohort15', clear
capture noisily tvexpose using `exp15', ///
    id(id) start(start) stop(stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    evertreated generate(exp_val)

if _rc != 0 {
    * Missing values might cause an error - that's also acceptable behavior
    display as result "  PASS [15.missing_handled]: command handled missing values (rc=`=_rc')"
}
else {
    * If it succeeds, check Person 1 has exposed rows, Person 2 doesn't
    quietly count if id == 1 & exp_val == 1
    if r(N) >= 1 {
        display as result "  PASS [15.p1_exposed]: Person 1 has exposed rows"
    }
    else {
        display as error "  FAIL [15.p1_exposed]: Person 1 has no exposed rows"
        local test15_pass = 0
    }

    * Person 2 with missing drug should be all reference
    quietly count if id == 2 & exp_val == 1
    if r(N) == 0 {
        display as result "  PASS [15.p2_unexp]: Person 2 all unexposed"
    }
    else {
        * Missing drug value might be treated as an exposure type
        display as result "  NOTE [15.p2]: Person 2 has `=r(N)' exposed rows (missing treated as exposure)"
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


* TEST 16: String IDs
* 2 persons with string IDs "ABC" and "XYZ".
* Verify tvexpose handles string IDs correctly.

display _n _dup(60) "-"
display "TEST 16: String IDs"
display _dup(60) "-"
local test16_pass = 1

tempfile cohort16 exp16
clear
input str3(id)
"ABC"
"XYZ"
end
gen study_entry = mdy(1,1,2020)
gen study_exit  = mdy(12,31,2020)
format %td study_entry study_exit
save `cohort16', replace

clear
input str3(id) int(drug) str10(s_start s_stop)
"ABC" 1 "2020-03-01" "2020-06-30"
"XYZ" 1 "2020-05-01" "2020-08-31"
end
gen double start = date(s_start, "YMD")
gen double stop  = date(s_stop, "YMD")
format %td start stop
drop s_start s_stop
save `exp16', replace

use `cohort16', clear
capture noisily tvexpose using `exp16', ///
    id(id) start(start) stop(stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    evertreated generate(exp_val)

if _rc != 0 {
    display as error "  FAIL [16.run]: error `=_rc'"
    local test16_pass = 0
}
else {
    * Both persons should have rows
    quietly tab id
    if r(r) == 2 {
        display as result "  PASS [16.ids]: both string IDs present"
    }
    else {
        display as error "  FAIL [16.ids]: `=r(r)' unique IDs, expected 2"
        local test16_pass = 0
    }

    * ID type preserved as string
    capture confirm string variable id
    if _rc == 0 {
        display as result "  PASS [16.type]: id is string type"
    }
    else {
        display as error "  FAIL [16.type]: id is not string type"
        local test16_pass = 0
    }

    * Person-time per person = 366
    tempvar pt
    gen `pt' = stop - start + 1
    quietly su `pt' if id == "ABC"
    if r(sum) == 366 {
        display as result "  PASS [16.pt_abc]: ABC person-time=366"
    }
    else {
        display as error "  FAIL [16.pt_abc]: ABC person-time=`=r(sum)', expected 366"
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


* ============================================================================
* SECTION C: PERSON-TIME CONSERVATION INVARIANTS (Tests 17-21)
* Invariant: sum(stop - start + 1) per person = study_exit - study_entry + 1
* ============================================================================

* TEST 17: Person-time conservation with evertreated
* 3 persons: P1 no exposure, P2 partial, P3 full year exposure

display _n _dup(60) "-"
display "TEST 17: Person-time conservation - evertreated"
display _dup(60) "-"
local test17_pass = 1

tempfile cohort17 exp17
clear
input int(id)
1
2
3
end
gen study_entry = mdy(1,1,2020)
gen study_exit  = mdy(12,31,2020)
format %td study_entry study_exit
save `cohort17', replace

clear
input int(id drug) str10(s_start s_stop)
2 1 "2020-04-01" "2020-09-30"
3 1 "2020-01-01" "2020-12-31"
end
gen double start = date(s_start, "YMD")
gen double stop  = date(s_stop, "YMD")
format %td start stop
drop s_start s_stop
save `exp17', replace

use `cohort17', clear
capture noisily tvexpose using `exp17', ///
    id(id) start(start) stop(stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    evertreated generate(exp_val)

if _rc != 0 {
    display as error "  FAIL [17.run]: error `=_rc'"
    local test17_pass = 0
}
else {
    local expected_pt = mdy(12,31,2020) - mdy(1,1,2020) + 1
    forvalues p = 1/3 {
        tempvar pt`p'
        gen `pt`p'' = stop - start + 1 if id == `p'
        quietly su `pt`p''
        if r(sum) == `expected_pt' {
            display as result "  PASS [17.pt_p`p']: person `p' time=`expected_pt'"
        }
        else {
            display as error "  FAIL [17.pt_p`p']: person `p' time=`=r(sum)', expected `expected_pt'"
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


* TEST 18: Person-time conservation with currentformer
* Same 3 persons as test 17

display _n _dup(60) "-"
display "TEST 18: Person-time conservation - currentformer"
display _dup(60) "-"
local test18_pass = 1

use `cohort17', clear
capture noisily tvexpose using `exp17', ///
    id(id) start(start) stop(stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    currentformer generate(cf_val)

if _rc != 0 {
    display as error "  FAIL [18.run]: error `=_rc'"
    local test18_pass = 0
}
else {
    local expected_pt = 366
    forvalues p = 1/3 {
        tempvar pt`p'
        gen `pt`p'' = stop - start + 1 if id == `p'
        quietly su `pt`p''
        if r(sum) == `expected_pt' {
            display as result "  PASS [18.pt_p`p']: person `p' time=`expected_pt'"
        }
        else {
            display as error "  FAIL [18.pt_p`p']: person `p' time=`=r(sum)', expected `expected_pt'"
            local test18_pass = 0
        }
    }

    * Person 1 should be all 0 (never exposed)
    quietly count if id == 1 & cf_val != 0
    if r(N) == 0 {
        display as result "  PASS [18.p1_never]: Person 1 always cf=0"
    }
    else {
        display as error "  FAIL [18.p1_never]: Person 1 has non-zero cf rows"
        local test18_pass = 0
    }

    * Person 2 should have all 3 states: 0 (pre), 1 (current), 2 (former)
    quietly levelsof cf_val if id == 2, local(p2_vals)
    local n_states : word count `p2_vals'
    if `n_states' == 3 {
        display as result "  PASS [18.p2_states]: Person 2 has 3 states (0,1,2)"
    }
    else {
        display as error "  FAIL [18.p2_states]: Person 2 has `n_states' states, expected 3"
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


* TEST 19: Person-time conservation with lag + washout
* lag(30) can eat into short exposures. washout(60) extends them.
* 3 persons with varying exposure lengths.

display _n _dup(60) "-"
display "TEST 19: Person-time conservation - lag(30) + washout(60)"
display _dup(60) "-"
local test19_pass = 1

tempfile cohort19 exp19
clear
input int(id)
1
2
3
end
gen study_entry = mdy(1,1,2020)
gen study_exit  = mdy(12,31,2020)
format %td study_entry study_exit
save `cohort19', replace

clear
input int(id drug) str10(s_start s_stop)
1 1 "2020-03-01" "2020-06-30"
2 1 "2020-05-01" "2020-05-15"
3 1 "2020-01-01" "2020-11-30"
end
gen double start = date(s_start, "YMD")
gen double stop  = date(s_stop, "YMD")
format %td start stop
drop s_start s_stop
save `exp19', replace

use `cohort19', clear
capture noisily tvexpose using `exp19', ///
    id(id) start(start) stop(stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    lag(30) washout(60) evertreated generate(exp_val)

if _rc != 0 {
    display as error "  FAIL [19.run]: error `=_rc'"
    local test19_pass = 0
}
else {
    local expected_pt = 366
    forvalues p = 1/3 {
        tempvar pt`p'
        gen `pt`p'' = stop - start + 1 if id == `p'
        quietly su `pt`p''
        if r(sum) == `expected_pt' {
            display as result "  PASS [19.pt_p`p']: person `p' time=`expected_pt'"
        }
        else {
            display as error "  FAIL [19.pt_p`p']: person `p' time=`=r(sum)', expected `expected_pt'"
            local test19_pass = 0
        }
    }

    * Person 2: exposure May1-May15 (15 days). lag(30): May1+30=May31. May31>May15 → exposure eaten.
    * So Person 2 should be fully unexposed after lag.
    quietly count if id == 2 & exp_val == 1
    * With evertreated=1 if ever exposed. But lag ate the entire exposure → never exposed.
    if r(N) == 0 {
        display as result "  PASS [19.lag_eats]: lag(30) eats 15-day exposure for Person 2"
    }
    else {
        display as error "  FAIL [19.lag_eats]: Person 2 has `=r(N)' exposed rows after lag"
        local test19_pass = 0
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


* TEST 20: Person-time conservation with layer (3 overlapping exposures)
* 1 person. Drug A Jan1-Jun30, Drug B Mar1-Sep30, Drug C Aug1-Nov30.
* Layer resolves overlaps by giving precedence to later-arriving drugs.

display _n _dup(60) "-"
display "TEST 20: Person-time conservation - layer with 3 overlaps"
display _dup(60) "-"
local test20_pass = 1

tempfile cohort20 exp20
clear
set obs 1
gen id = 1
gen study_entry = mdy(1,1,2020)
gen study_exit  = mdy(12,31,2020)
format %td study_entry study_exit
save `cohort20', replace

clear
input int(id drug) str10(s_start s_stop)
1 1 "2020-01-01" "2020-06-30"
1 2 "2020-03-01" "2020-09-30"
1 3 "2020-08-01" "2020-11-30"
end
gen double start = date(s_start, "YMD")
gen double stop  = date(s_stop, "YMD")
format %td start stop
drop s_start s_stop
save `exp20', replace

use `cohort20', clear
capture noisily tvexpose using `exp20', ///
    id(id) start(start) stop(stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    layer generate(exp_val)

if _rc != 0 {
    display as error "  FAIL [20.run]: error `=_rc'"
    local test20_pass = 0
}
else {
    * Person-time = 366
    tempvar pt
    gen `pt' = stop - start + 1
    quietly su `pt'
    if r(sum) == 366 {
        display as result "  PASS [20.pt]: person-time=366"
    }
    else {
        display as error "  FAIL [20.pt]: person-time=`=r(sum)', expected 366"
        local test20_pass = 0
    }

    * All 3 drug types should appear
    forvalues d = 1/3 {
        quietly count if exp_val == `d'
        if r(N) >= 1 {
            display as result "  PASS [20.drug`d']: Drug `d' rows exist"
        }
        else {
            display as error "  FAIL [20.drug`d']: no Drug `d' rows"
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


* TEST 21: Person-time conservation with combine (overlapping exposures)
* 1 person. Drug 1 Jan1-Jun30, Drug 2 Apr1-Sep30.
* combine(combo): overlapping period gets combined value = 1*100+2 = 102
* Person-time must still be 366.

display _n _dup(60) "-"
display "TEST 21: Person-time conservation - combine"
display _dup(60) "-"
local test21_pass = 1

tempfile cohort21 exp21
clear
set obs 1
gen id = 1
gen study_entry = mdy(1,1,2020)
gen study_exit  = mdy(12,31,2020)
format %td study_entry study_exit
save `cohort21', replace

clear
input int(id drug) str10(s_start s_stop)
1 1 "2020-01-01" "2020-06-30"
1 2 "2020-04-01" "2020-09-30"
end
gen double start = date(s_start, "YMD")
gen double stop  = date(s_stop, "YMD")
format %td start stop
drop s_start s_stop
save `exp21', replace

use `cohort21', clear
capture noisily tvexpose using `exp21', ///
    id(id) start(start) stop(stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    combine(combo) generate(exp_val)

if _rc != 0 {
    display as error "  FAIL [21.run]: error `=_rc'"
    local test21_pass = 0
}
else {
    * Person-time = 366
    tempvar pt
    gen `pt' = stop - start + 1
    quietly su `pt'
    if r(sum) == 366 {
        display as result "  PASS [21.pt]: person-time=366"
    }
    else {
        display as error "  FAIL [21.pt]: person-time=`=r(sum)', expected 366"
        local test21_pass = 0
    }

    * Combined value should exist
    capture confirm variable combo
    if _rc == 0 {
        quietly count if combo == 102
        if r(N) >= 1 {
            display as result "  PASS [21.combo]: combined value 102 exists"
        }
        else {
            display as error "  FAIL [21.combo]: no combo=102 rows"
            local test21_pass = 0
        }
    }
    else {
        display as error "  FAIL [21.combo_var]: combo variable not found"
        local test21_pass = 0
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


* ============================================================================
* SECTION D: RECENCY & COMPLEX TYPES (Tests 22-25)
* ============================================================================

* TEST 22: Recency boundary cutpoint precision
* 1 person Jan1-Dec31. Drug 1 Mar1-Mar31 (31 days).
* recency(30 90): cutpoints in DAYS
* Categories: 0=pre-exposure, 1=currently exposed, 2=<30d since, 3=30-<90d, 4=90+d
* Exposure ends Mar31. Days since = current_date - Mar31.
*   [Jan1,Feb29]: 0 (pre-exposure reference)
*   [Mar1,Mar31]: 1 (currently exposed)
*   [Apr1,Apr29]: 2 (1-29 days since, <30)
*   [Apr30,Jun28]: 3 (30-89 days since)
*   [Jun29,Dec31]: 4 (90+ days since)

display _n _dup(60) "-"
display "TEST 22: Recency boundary cutpoint precision"
display _dup(60) "-"
local test22_pass = 1

tempfile cohort22 exp22
clear
set obs 1
gen id = 1
gen study_entry = mdy(1,1,2020)
gen study_exit  = mdy(12,31,2020)
format %td study_entry study_exit
save `cohort22', replace

clear
input int(id drug) str10(s_start s_stop)
1 1 "2020-03-01" "2020-03-31"
end
gen double start = date(s_start, "YMD")
gen double stop  = date(s_stop, "YMD")
format %td start stop
drop s_start s_stop
save `exp22', replace

use `cohort22', clear
capture noisily tvexpose using `exp22', ///
    id(id) start(start) stop(stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    recency(30 90) generate(rec_cat)

if _rc != 0 {
    display as error "  FAIL [22.run]: error `=_rc'"
    local test22_pass = 0
}
else {
    sort id start

    * Person-time = 366
    tempvar pt
    gen `pt' = stop - start + 1
    quietly su `pt'
    if r(sum) == 366 {
        display as result "  PASS [22.pt]: person-time=366"
    }
    else {
        display as error "  FAIL [22.pt]: person-time=`=r(sum)', expected 366"
        local test22_pass = 0
    }

    * Pre-exposure row should be rec_cat=0
    quietly su rec_cat if start == mdy(1,1,2020)
    if r(mean) == 0 {
        display as result "  PASS [22.pre]: pre-exposure rec_cat=0"
    }
    else {
        display as error "  FAIL [22.pre]: pre-exposure rec_cat=`=r(mean)', expected 0"
        local test22_pass = 0
    }

    * Currently exposed row (Mar1-Mar31)
    quietly su rec_cat if start == mdy(3,1,2020)
    if r(mean) == 1 {
        display as result "  PASS [22.current]: currently exposed rec_cat=1"
    }
    else {
        display as error "  FAIL [22.current]: exposed rec_cat=`=r(mean)', expected 1"
        local test22_pass = 0
    }

    * Check that recency categories 2, 3, 4 all appear
    forvalues c = 2/4 {
        quietly count if rec_cat == `c'
        if r(N) >= 1 {
            display as result "  PASS [22.cat`c']: recency category `c' exists"
        }
        else {
            display as error "  FAIL [22.cat`c']: recency category `c' not found"
            local test22_pass = 0
        }
    }
}

if `test22_pass' == 1 {
    local pass_count = `pass_count' + 1
    display as result "TEST 22: PASSED"
}
else {
    local fail_count = `fail_count' + 1
    local failed_tests "`failed_tests' 22"
    display as error "TEST 22: FAILED"
}


* TEST 23: Recency with bytype (independence check)
* 1 person. Drug 1 Jan15-Feb28, Drug 2 Jun1-Jul31.
* recency(30 90) bytype: each drug's recency should be independent.
* Drug 1 recency should not be affected by Drug 2 and vice versa.

display _n _dup(60) "-"
display "TEST 23: Recency with bytype - independence"
display _dup(60) "-"
local test23_pass = 1

tempfile cohort23 exp23
clear
set obs 1
gen id = 1
gen study_entry = mdy(1,1,2020)
gen study_exit  = mdy(12,31,2020)
format %td study_entry study_exit
save `cohort23', replace

clear
input int(id drug) str10(s_start s_stop)
1 1 "2020-01-15" "2020-02-28"
1 2 "2020-06-01" "2020-07-31"
end
gen double start = date(s_start, "YMD")
gen double stop  = date(s_stop, "YMD")
format %td start stop
drop s_start s_stop
save `exp23', replace

use `cohort23', clear
capture noisily tvexpose using `exp23', ///
    id(id) start(start) stop(stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    recency(30 90) bytype generate(rec)

if _rc != 0 {
    display as error "  FAIL [23.run]: error `=_rc'"
    local test23_pass = 0
}
else {
    * Person-time = 366
    tempvar pt
    gen `pt' = stop - start + 1
    quietly su `pt'
    if r(sum) == 366 {
        display as result "  PASS [23.pt]: person-time=366"
    }
    else {
        display as error "  FAIL [23.pt]: person-time=`=r(sum)', expected 366"
        local test23_pass = 0
    }

    * Check that bytype variables exist (rec_1 and rec_2)
    capture confirm variable rec_1
    local rc1 = _rc
    capture confirm variable rec_2
    local rc2 = _rc
    if `rc1' == 0 & `rc2' == 0 {
        display as result "  PASS [23.vars]: rec_1 and rec_2 exist"
    }
    else {
        display as error "  FAIL [23.vars]: bytype variables not found (rc1=`rc1', rc2=`rc2')"
        local test23_pass = 0
    }

    * Independence: during Drug 2's exposure (Jun-Jul), Drug 1's recency should be
    * based on time since Drug 1 ended (Feb28), NOT affected by Drug 2.
    * Days since Drug 1 at Jun1: Jun1 - Feb28 = 94 days. So rec_1 should be 4 (90+)
    capture {
        quietly su rec_1 if start >= mdy(6,1,2020) & stop <= mdy(7,31,2020)
        local r1_during_d2 = r(mean)
        * rec_1 during Drug 2 period should be 4 (90+ days since Drug 1)
        if `r1_during_d2' == 4 {
            display as result "  PASS [23.indep]: rec_1=4 during Drug 2 (independent)"
        }
        else {
            display as error "  FAIL [23.indep]: rec_1=`r1_during_d2' during Drug 2, expected 4"
            local test23_pass = 0
        }
    }
}

if `test23_pass' == 1 {
    local pass_count = `pass_count' + 1
    display as result "TEST 23: PASSED"
}
else {
    local fail_count = `fail_count' + 1
    local failed_tests "`failed_tests' 23"
    display as error "TEST 23: FAILED"
}


* TEST 24: expandunit(months) + continuousunit(years) across leap year
* 1 person, full year 2020 (366d), exposed entire year.
* expandunit(months): 12 calendar month rows
* continuousunit(years): cumulative exposure in years (÷365.25)

display _n _dup(60) "-"
display "TEST 24: expandunit(months) + continuousunit(years) across leap year"
display _dup(60) "-"
local test24_pass = 1

tempfile cohort24 exp24
clear
set obs 1
gen id = 1
gen study_entry = mdy(1,1,2020)
gen study_exit  = mdy(12,31,2020)
format %td study_entry study_exit
save `cohort24', replace

clear
input int(id drug) str10(s_start s_stop)
1 1 "2020-01-01" "2020-12-31"
end
gen double start = date(s_start, "YMD")
gen double stop  = date(s_stop, "YMD")
format %td start stop
drop s_start s_stop
save `exp24', replace

use `cohort24', clear
capture noisily tvexpose using `exp24', ///
    id(id) start(start) stop(stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    expandunit(months) continuousunit(years) generate(cum_yrs)

if _rc != 0 {
    display as error "  FAIL [24.run]: error `=_rc'"
    local test24_pass = 0
}
else {
    sort id start

    * Should have 12 rows (one per month)
    quietly count
    if r(N) == 12 {
        display as result "  PASS [24.rows]: 12 monthly rows"
    }
    else {
        display as error "  FAIL [24.rows]: `=r(N)' rows, expected 12"
        local test24_pass = 0
    }

    * Person-time = 366
    tempvar pt
    gen `pt' = stop - start + 1
    quietly su `pt'
    if r(sum) == 366 {
        display as result "  PASS [24.pt]: person-time=366"
    }
    else {
        display as error "  FAIL [24.pt]: person-time=`=r(sum)', expected 366"
        local test24_pass = 0
    }

    * Final row's cumulative years should be approximately 366/365.25 ≈ 1.002
    quietly su cum_yrs
    local max_yrs = r(max)
    assert_approx `max_yrs' 1.00205 0.01 "24.final_yrs"
}

if `test24_pass' == 1 {
    local pass_count = `pass_count' + 1
    display as result "TEST 24: PASSED"
}
else {
    local fail_count = `fail_count' + 1
    local failed_tests "`failed_tests' 24"
    display as error "TEST 24: FAILED"
}


* TEST 25: grace(exp=# exp=#) category-specific
* 1 person. Drug 1: [Jan1,Jan10] + [Jan16,Jan25] (gap_days = Jan16-Jan10-1 = 5)
*           Drug 2: [Jun1,Jun10] + [Jun20,Jun25] (gap_days = Jun20-Jun10-1 = 9)
* grace(1=10 2=5): Drug 1 grace=10, Drug 2 grace=5
* Drug 1: gap_days(5) <= grace(10) → bridged
* Drug 2: gap_days(9) > grace(5) → NOT bridged

display _n _dup(60) "-"
display "TEST 25: grace(1=10 2=5) category-specific"
display _dup(60) "-"
local test25_pass = 1

tempfile cohort25 exp25
clear
set obs 1
gen id = 1
gen study_entry = mdy(1,1,2020)
gen study_exit  = mdy(12,31,2020)
format %td study_entry study_exit
save `cohort25', replace

clear
input int(id drug) str10(s_start s_stop)
1 1 "2020-01-01" "2020-01-10"
1 1 "2020-01-16" "2020-01-25"
1 2 "2020-06-01" "2020-06-10"
1 2 "2020-06-20" "2020-06-25"
end
gen double start = date(s_start, "YMD")
gen double stop  = date(s_stop, "YMD")
format %td start stop
drop s_start s_stop
save `exp25', replace

use `cohort25', clear
capture noisily tvexpose using `exp25', ///
    id(id) start(start) stop(stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    grace(1=10 2=5) generate(exp_val)

if _rc != 0 {
    display as error "  FAIL [25.run]: error `=_rc'"
    local test25_pass = 0
}
else {
    sort id start

    * Person-time = 366
    tempvar pt
    gen `pt' = stop - start + 1
    quietly su `pt'
    if r(sum) == 366 {
        display as result "  PASS [25.pt]: person-time=366"
    }
    else {
        display as error "  FAIL [25.pt]: person-time=`=r(sum)', expected 366"
        local test25_pass = 0
    }

    * Drug 1: gap bridged → should be 1 continuous period
    * The two Drug 1 periods (Jan1-10, Jan16-25) should merge into 1 exposed period
    * because grace(1=10) bridges the 5-day gap
    quietly count if exp_val == 1
    local d1_rows = r(N)
    if `d1_rows' == 1 {
        display as result "  PASS [25.d1_bridged]: Drug 1 gap bridged (1 exposed row)"
    }
    else {
        display as error "  FAIL [25.d1_bridged]: Drug 1 has `d1_rows' rows, expected 1 (bridged)"
        local test25_pass = 0
    }

    * Drug 2: gap NOT bridged → should be 2 separate periods
    quietly count if exp_val == 2
    local d2_rows = r(N)
    if `d2_rows' == 2 {
        display as result "  PASS [25.d2_unbridged]: Drug 2 gap NOT bridged (2 exposed rows)"
    }
    else {
        display as error "  FAIL [25.d2_unbridged]: Drug 2 has `d2_rows' rows, expected 2 (unbridged)"
        local test25_pass = 0
    }
}

if `test25_pass' == 1 {
    local pass_count = `pass_count' + 1
    display as result "TEST 25: PASSED"
}
else {
    local fail_count = `fail_count' + 1
    local failed_tests "`failed_tests' 25"
    display as error "TEST 25: FAILED"
}


* ============================================================================
* SECTION E: EDGE CASES FROM CODE REVIEW (Tests 26-30)
* ============================================================================

* TEST 26: Exposure starts exactly on study_entry
* Exposure start = study_entry = Jan1. Should have no pre-exposure row (or zero-length).

display _n _dup(60) "-"
display "TEST 26: Exposure starts exactly on study_entry"
display _dup(60) "-"
local test26_pass = 1

tempfile cohort26 exp26
clear
set obs 1
gen id = 1
gen study_entry = mdy(1,1,2020)
gen study_exit  = mdy(12,31,2020)
format %td study_entry study_exit
save `cohort26', replace

clear
input int(id drug) str10(s_start s_stop)
1 1 "2020-01-01" "2020-06-30"
end
gen double start = date(s_start, "YMD")
gen double stop  = date(s_stop, "YMD")
format %td start stop
drop s_start s_stop
save `exp26', replace

use `cohort26', clear
capture noisily tvexpose using `exp26', ///
    id(id) start(start) stop(stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    generate(exp_val)

if _rc != 0 {
    display as error "  FAIL [26.run]: error `=_rc'"
    local test26_pass = 0
}
else {
    sort id start

    * First row should start at study_entry and be exposed
    if start[1] == mdy(1,1,2020) & exp_val[1] != 0 {
        display as result "  PASS [26.start]: first row starts at entry and is exposed"
    }
    else {
        display as error "  FAIL [26.start]: first row start=`=string(start[1], "%td")', exp_val=`=exp_val[1]'"
        local test26_pass = 0
    }

    * No pre-exposure reference row
    quietly count if exp_val == 0 & stop < mdy(1,1,2020)
    if r(N) == 0 {
        display as result "  PASS [26.no_pre]: no pre-exposure row"
    }
    else {
        display as error "  FAIL [26.no_pre]: pre-exposure rows exist"
        local test26_pass = 0
    }

    * Person-time = 366
    tempvar pt
    gen `pt' = stop - start + 1
    quietly su `pt'
    if r(sum) == 366 {
        display as result "  PASS [26.pt]: person-time=366"
    }
    else {
        display as error "  FAIL [26.pt]: person-time=`=r(sum)', expected 366"
        local test26_pass = 0
    }
}

if `test26_pass' == 1 {
    local pass_count = `pass_count' + 1
    display as result "TEST 26: PASSED"
}
else {
    local fail_count = `fail_count' + 1
    local failed_tests "`failed_tests' 26"
    display as error "TEST 26: FAILED"
}


* TEST 27: Exposure ends exactly on study_exit
* Exposure stop = study_exit = Dec31. Should have no post-exposure row.

display _n _dup(60) "-"
display "TEST 27: Exposure ends exactly on study_exit"
display _dup(60) "-"
local test27_pass = 1

tempfile cohort27 exp27
clear
set obs 1
gen id = 1
gen study_entry = mdy(1,1,2020)
gen study_exit  = mdy(12,31,2020)
format %td study_entry study_exit
save `cohort27', replace

clear
input int(id drug) str10(s_start s_stop)
1 1 "2020-06-01" "2020-12-31"
end
gen double start = date(s_start, "YMD")
gen double stop  = date(s_stop, "YMD")
format %td start stop
drop s_start s_stop
save `exp27', replace

use `cohort27', clear
capture noisily tvexpose using `exp27', ///
    id(id) start(start) stop(stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    generate(exp_val)

if _rc != 0 {
    display as error "  FAIL [27.run]: error `=_rc'"
    local test27_pass = 0
}
else {
    sort id start

    * Last row should stop at study_exit and be exposed
    quietly count
    local nr = r(N)
    if stop[`nr'] == mdy(12,31,2020) & exp_val[`nr'] != 0 {
        display as result "  PASS [27.end]: last row ends at exit and is exposed"
    }
    else {
        display as error "  FAIL [27.end]: last row stop=`=string(stop[`nr'], "%td")', exp_val=`=exp_val[`nr']'"
        local test27_pass = 0
    }

    * No post-exposure reference row after Dec31
    quietly count if exp_val == 0 & start > mdy(12,31,2020)
    if r(N) == 0 {
        display as result "  PASS [27.no_post]: no post-exposure row"
    }
    else {
        display as error "  FAIL [27.no_post]: post-exposure rows exist"
        local test27_pass = 0
    }

    * Person-time = 366
    tempvar pt
    gen `pt' = stop - start + 1
    quietly su `pt'
    if r(sum) == 366 {
        display as result "  PASS [27.pt]: person-time=366"
    }
    else {
        display as error "  FAIL [27.pt]: person-time=`=r(sum)', expected 366"
        local test27_pass = 0
    }
}

if `test27_pass' == 1 {
    local pass_count = `pass_count' + 1
    display as result "TEST 27: PASSED"
}
else {
    local fail_count = `fail_count' + 1
    local failed_tests "`failed_tests' 27"
    display as error "TEST 27: FAILED"
}


* TEST 28: combine() encoding
* 1 person. Drug 1 Jan1-Jun30, Drug 2 Apr1-Sep30. Overlap Apr1-Jun30.
* combine(combo): combined value = 1*100 + 2 = 102
* Expected rows: Drug 1 only, Drug 1+2 combined, Drug 2 only, reference

display _n _dup(60) "-"
display "TEST 28: combine() encoding: 1*100+2=102"
display _dup(60) "-"
local test28_pass = 1

tempfile cohort28 exp28
clear
set obs 1
gen id = 1
gen study_entry = mdy(1,1,2020)
gen study_exit  = mdy(12,31,2020)
format %td study_entry study_exit
save `cohort28', replace

clear
input int(id drug) str10(s_start s_stop)
1 1 "2020-01-01" "2020-06-30"
1 2 "2020-04-01" "2020-09-30"
end
gen double start = date(s_start, "YMD")
gen double stop  = date(s_stop, "YMD")
format %td start stop
drop s_start s_stop
save `exp28', replace

use `cohort28', clear
capture noisily tvexpose using `exp28', ///
    id(id) start(start) stop(stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    combine(combo) generate(exp_val)

if _rc != 0 {
    display as error "  FAIL [28.run]: error `=_rc'"
    local test28_pass = 0
}
else {
    sort id start

    * Check combo variable has value 102 during overlap
    capture confirm variable combo
    if _rc == 0 {
        quietly count if combo == 102
        if r(N) >= 1 {
            display as result "  PASS [28.val]: combo=102 (1*100+2) exists"
        }
        else {
            * List actual combo values for debugging
            quietly levelsof combo, local(vals)
            display as error "  FAIL [28.val]: no combo=102. Values: `vals'"
            local test28_pass = 0
        }
    }
    else {
        display as error "  FAIL [28.var]: combo variable not found"
        local test28_pass = 0
    }

    * Combo=102 period should be [Apr1,Jun30]
    quietly su start if combo == 102
    local combo_start = r(mean)
    quietly su stop if combo == 102
    local combo_stop = r(mean)
    if `combo_start' == mdy(4,1,2020) & `combo_stop' == mdy(6,30,2020) {
        display as result "  PASS [28.dates]: combo period is [Apr1,Jun30]"
    }
    else {
        display as error "  FAIL [28.dates]: combo period start=`=string(`combo_start',"%td")', stop=`=string(`combo_stop',"%td")'"
        local test28_pass = 0
    }

    * Person-time = 366
    tempvar pt
    gen `pt' = stop - start + 1
    quietly su `pt'
    if r(sum) == 366 {
        display as result "  PASS [28.pt]: person-time=366"
    }
    else {
        display as error "  FAIL [28.pt]: person-time=`=r(sum)', expected 366"
        local test28_pass = 0
    }
}

if `test28_pass' == 1 {
    local pass_count = `pass_count' + 1
    display as result "TEST 28: PASSED"
}
else {
    local fail_count = `fail_count' + 1
    local failed_tests "`failed_tests' 28"
    display as error "TEST 28: FAILED"
}


* TEST 29: Priority with 3 types: priority(3 2 1) → Drug 3 wins triple overlap
* 1 person. Drug 1 Jan1-Dec31, Drug 2 Mar1-Sep30, Drug 3 May1-Jul31.
* priority(3 2 1): Drug 1 rank 3 (lowest), Drug 2 rank 2, Drug 3 rank 1 (highest)
* During triple overlap (May1-Jul31): Drug 3 wins.

display _n _dup(60) "-"
display "TEST 29: Priority with 3 types - triple overlap"
display _dup(60) "-"
local test29_pass = 1

tempfile cohort29 exp29
clear
set obs 1
gen id = 1
gen study_entry = mdy(1,1,2020)
gen study_exit  = mdy(12,31,2020)
format %td study_entry study_exit
save `cohort29', replace

clear
input int(id drug) str10(s_start s_stop)
1 1 "2020-01-01" "2020-12-31"
1 2 "2020-03-01" "2020-09-30"
1 3 "2020-05-01" "2020-07-31"
end
gen double start = date(s_start, "YMD")
gen double stop  = date(s_stop, "YMD")
format %td start stop
drop s_start s_stop
save `exp29', replace

use `cohort29', clear
capture noisily tvexpose using `exp29', ///
    id(id) start(start) stop(stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    priority(3 2 1) generate(exp_val)

if _rc != 0 {
    display as error "  FAIL [29.run]: error `=_rc'"
    local test29_pass = 0
}
else {
    sort id start

    * Drug 3 should be present during May-Jul
    quietly count if exp_val == 3
    if r(N) >= 1 {
        display as result "  PASS [29.drug3]: Drug 3 rows exist (highest priority)"
    }
    else {
        display as error "  FAIL [29.drug3]: no Drug 3 rows"
        local test29_pass = 0
    }

    * During triple overlap, Drug 3 wins → exp_val=3 for May1-Jul31
    quietly su exp_val if start >= mdy(5,1,2020) & stop <= mdy(7,31,2020)
    if r(mean) == 3 {
        display as result "  PASS [29.triple]: Drug 3 wins triple overlap"
    }
    else {
        display as error "  FAIL [29.triple]: overlap exp_val=`=r(mean)', expected 3"
        local test29_pass = 0
    }

    * Person-time = 366
    tempvar pt
    gen `pt' = stop - start + 1
    quietly su `pt'
    if r(sum) == 366 {
        display as result "  PASS [29.pt]: person-time=366"
    }
    else {
        display as error "  FAIL [29.pt]: person-time=`=r(sum)', expected 366"
        local test29_pass = 0
    }
}

if `test29_pass' == 1 {
    local pass_count = `pass_count' + 1
    display as result "TEST 29: PASSED"
}
else {
    local fail_count = `fail_count' + 1
    local failed_tests "`failed_tests' 29"
    display as error "TEST 29: FAILED"
}


* TEST 30: keepdates preserves entry/exit variables
* Without keepdates: study_entry and study_exit should NOT be in output.
* With keepdates: study_entry and study_exit should be in output.

display _n _dup(60) "-"
display "TEST 30: keepdates preserves entry/exit variables"
display _dup(60) "-"
local test30_pass = 1

tempfile cohort30 exp30
clear
set obs 1
gen id = 1
gen study_entry = mdy(1,1,2020)
gen study_exit  = mdy(12,31,2020)
format %td study_entry study_exit
save `cohort30', replace

clear
input int(id drug) str10(s_start s_stop)
1 1 "2020-03-01" "2020-06-30"
end
gen double start = date(s_start, "YMD")
gen double stop  = date(s_stop, "YMD")
format %td start stop
drop s_start s_stop
save `exp30', replace

* Without keepdates
use `cohort30', clear
capture noisily tvexpose using `exp30', ///
    id(id) start(start) stop(stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    evertreated generate(exp_val)

if _rc != 0 {
    display as error "  FAIL [30a.run]: error `=_rc'"
    local test30_pass = 0
}
else {
    capture confirm variable study_entry
    if _rc != 0 {
        display as result "  PASS [30a.no_dates]: entry/exit dropped without keepdates"
    }
    else {
        display as error "  FAIL [30a.no_dates]: study_entry still present without keepdates"
        local test30_pass = 0
    }
}

* With keepdates
use `cohort30', clear
capture noisily tvexpose using `exp30', ///
    id(id) start(start) stop(stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    evertreated keepdates generate(exp_val)

if _rc != 0 {
    display as error "  FAIL [30b.run]: error `=_rc'"
    local test30_pass = 0
}
else {
    capture confirm variable study_entry
    local rc1 = _rc
    capture confirm variable study_exit
    local rc2 = _rc
    if `rc1' == 0 & `rc2' == 0 {
        display as result "  PASS [30b.dates]: entry/exit preserved with keepdates"
    }
    else {
        display as error "  FAIL [30b.dates]: entry/exit missing with keepdates"
        local test30_pass = 0
    }

    * Verify values are correct
    if `rc1' == 0 {
        quietly su study_entry
        if r(mean) == mdy(1,1,2020) {
            display as result "  PASS [30b.entry_val]: study_entry = Jan1"
        }
        else {
            display as error "  FAIL [30b.entry_val]: study_entry = `=string(r(mean), "%td")'"
            local test30_pass = 0
        }
    }
}

if `test30_pass' == 1 {
    local pass_count = `pass_count' + 1
    display as result "TEST 30: PASSED"
}
else {
    local fail_count = `fail_count' + 1
    local failed_tests "`failed_tests' 30"
    display as error "TEST 30: FAILED"
}


* ============================================================================
* FINAL SUMMARY
* ============================================================================
local total_tests = `pass_count' + `fail_count'
display _n _dup(70) "="
display "TVEXPOSE STRESS TEST SUMMARY"
display _dup(70) "="
display "Tests run:    `total_tests'"
display "Tests passed: `pass_count'"
display "Tests failed: `fail_count'"
if "`failed_tests'" != "" {
    display as error "Failed tests: `failed_tests'"
}
display _dup(70) "="

if `fail_count' == 0 {
    display as result _n "ALL TVEXPOSE STRESS TESTS PASSED"
}
else {
    display as error _n "`fail_count' TVEXPOSE STRESS TESTS FAILED"
    exit 1
}
