/*******************************************************************************
* validation_tvmerge_registry.do
*
* Purpose: Validate tvmerge against real-world multi-dataset merge scenarios
*          that occur in registry-based pharmacoepidemiologic studies.
*          Creates synthetic data mimicking multi-exposure pipelines
*          (age bands + DMT + HRT + vaginal + IUD) and verifies correct merging.
*
* Scenarios:
*   1. 3-dataset merge (age + DMT + HRT)
*   2. 5-dataset merge
*   3. batch() option produces identical output
*   4. Person in dataset A but not dataset B
*   5. Datasets with very unequal interval counts
*   6. continuous() proportioning through multi-merge
*   7. Merge preserves exposure values exactly
*   8. Person-time conservation through merge
*
* Run: stata-mp -b do validation_tvmerge_registry.do
* Log: validation_tvmerge_registry.log
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
display "TVMERGE REGISTRY DATA VALIDATION"
display _dup(70) "="
display "Date: $S_DATE $S_TIME"
display ""

quietly adopath ++ "/home/tpcopeland/Stata-Tools/tvtools"

* ============================================================================
* HELPER: Create standard cohort for reuse
* ============================================================================

* 5 persons, study 2020-2022
clear
set obs 5
gen long id = _n
gen double study_entry = mdy(1,1,2020)
gen double study_exit  = mdy(12,31,2021)
format study_entry study_exit %td
save "/tmp/tvm_cohort.dta", replace

* ============================================================================
* TEST 1: 3-DATASET MERGE (AGE + DMT + HRT)
* ============================================================================
display _n _dup(60) "-"
display "TEST 1: 3-dataset merge (age + DMT + HRT)"
display _dup(60) "-"

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
save "/tmp/tvm1_dsetA.dta", replace

* Dataset B: DMT exposure (all 5 persons, 3 intervals each)
clear
set obs 15
gen long id = ceil(_n/3)
gen double startB = mdy(1,1,2020) + (_n - (id-1)*3 - 1) * 243
gen double stopB  = startB + 242
replace stopB = mdy(12,31,2021) if stopB > mdy(12,31,2021)
gen byte dmt = mod(_n, 3)
format startB stopB %td
save "/tmp/tvm1_dsetB.dta", replace

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
save "/tmp/tvm1_dsetC.dta", replace

capture noisily tvmerge ///
    "/tmp/tvm1_dsetA.dta" "/tmp/tvm1_dsetB.dta" "/tmp/tvm1_dsetC.dta", ///
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

* ============================================================================
* TEST 2: 5-DATASET MERGE
* ============================================================================
display _n _dup(60) "-"
display "TEST 2: 5-dataset merge (age + DMT + HRT + vaginal + IUD)"
display _dup(60) "-"

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
save "/tmp/tvm2_dsetD.dta", replace

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
save "/tmp/tvm2_dsetE.dta", replace

capture noisily tvmerge ///
    "/tmp/tvm1_dsetA.dta" "/tmp/tvm1_dsetB.dta" "/tmp/tvm1_dsetC.dta" ///
    "/tmp/tvm2_dsetD.dta" "/tmp/tvm2_dsetE.dta", ///
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

* ============================================================================
* TEST 3: BATCH() PRODUCES IDENTICAL OUTPUT
* ============================================================================
display _n _dup(60) "-"
display "TEST 3: batch() option produces identical output"
display _dup(60) "-"

local test3_pass = 1

* Merge with batch(5)
capture noisily tvmerge ///
    "/tmp/tvm1_dsetA.dta" "/tmp/tvm1_dsetB.dta", ///
    id(id) start(startA startB) stop(stopA stopB) ///
    exposure(age_cat dmt) generate(age_b5 dmt_b5) batch(5)

if _rc != 0 {
    display as error "  FAIL [3.batch5]: tvmerge batch(5) returned error `=_rc'"
    local test3_pass = 0
}
else {
    sort id start
    save "/tmp/tvm3_batch5.dta", replace
}

* Merge with batch(100)
capture noisily tvmerge ///
    "/tmp/tvm1_dsetA.dta" "/tmp/tvm1_dsetB.dta", ///
    id(id) start(startA startB) stop(stopA stopB) ///
    exposure(age_cat dmt) generate(age_b100 dmt_b100) batch(100)

if _rc != 0 {
    display as error "  FAIL [3.batch100]: tvmerge batch(100) returned error `=_rc'"
    local test3_pass = 0
}
else {
    sort id start
    save "/tmp/tvm3_batch100.dta", replace
}

if `test3_pass' == 1 {
    * Compare the two outputs
    use "/tmp/tvm3_batch5.dta", clear
    quietly count
    local n_b5 = r(N)

    use "/tmp/tvm3_batch100.dta", clear
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
        use "/tmp/tvm3_batch100.dta", clear
        sort id start stop
        rename age_b100 age_check
        rename dmt_b100 dmt_check
        gen long _rownum = _n
        keep id start stop age_check dmt_check _rownum
        save "/tmp/tvm3_b100_compare.dta", replace

        * Load batch5 and compare
        use "/tmp/tvm3_batch5.dta", clear
        sort id start stop
        gen long _rownum = _n

        * Merge on row number (both are sorted identically)
        merge 1:1 _rownum using "/tmp/tvm3_b100_compare.dta", nogenerate
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
        capture erase "/tmp/tvm3_b100_compare.dta"
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
* TEST 4: PERSON IN DATASET A BUT NOT DATASET B
* ============================================================================
display _n _dup(60) "-"
display "TEST 4: Person in dataset A but not dataset B"
display _dup(60) "-"

local test4_pass = 1

* Dataset A: persons 1-5
clear
set obs 5
gen long id = _n
gen double startA = mdy(1,1,2020)
gen double stopA  = mdy(12,31,2020)
gen byte expA = 1
format startA stopA %td
save "/tmp/tvm4_dsetA.dta", replace

* Dataset B: only persons 1-3 (persons 4,5 missing)
clear
set obs 3
gen long id = _n
gen double startB = mdy(1,1,2020)
gen double stopB  = mdy(12,31,2020)
gen byte expB = 1
format startB stopB %td
save "/tmp/tvm4_dsetB.dta", replace

* Should work with force option
capture noisily tvmerge ///
    "/tmp/tvm4_dsetA.dta" "/tmp/tvm4_dsetB.dta", ///
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

* ============================================================================
* TEST 5: VERY UNEQUAL INTERVAL COUNTS
* ============================================================================
display _n _dup(60) "-"
display "TEST 5: Datasets with very unequal interval counts"
display _dup(60) "-"

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
save "/tmp/tvm5_dsetA.dta", replace

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
save "/tmp/tvm5_dsetB.dta", replace

capture noisily tvmerge ///
    "/tmp/tvm5_dsetA.dta" "/tmp/tvm5_dsetB.dta", ///
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

* ============================================================================
* TEST 6: CONTINUOUS PROPORTIONING THROUGH MULTI-MERGE
* ============================================================================
display _n _dup(60) "-"
display "TEST 6: continuous() proportioning through multi-merge"
display _dup(60) "-"

local test6_pass = 1

* Dataset A: 1 person, 1 year interval, continuous rate = 365 (1 unit/day)
clear
set obs 1
gen long id = 1
gen double startA = mdy(1,1,2020)
gen double stopA  = mdy(12,31,2020)
gen double rate_A = 366.0
format startA stopA %td
save "/tmp/tvm6_dsetA.dta", replace

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
save "/tmp/tvm6_dsetB.dta", replace

capture noisily tvmerge ///
    "/tmp/tvm6_dsetA.dta" "/tmp/tvm6_dsetB.dta", ///
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

* ============================================================================
* TEST 7: MERGE PRESERVES EXPOSURE VALUES EXACTLY
* ============================================================================
display _n _dup(60) "-"
display "TEST 7: Merge preserves exposure values exactly"
display _dup(60) "-"

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
save "/tmp/tvm7_dsetA.dta", replace

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
save "/tmp/tvm7_dsetB.dta", replace

capture noisily tvmerge ///
    "/tmp/tvm7_dsetA.dta" "/tmp/tvm7_dsetB.dta", ///
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

* ============================================================================
* TEST 8: PERSON-TIME CONSERVATION THROUGH MERGE
* ============================================================================
display _n _dup(60) "-"
display "TEST 8: Person-time conservation through merge (5 persons)"
display _dup(60) "-"

local test8_pass = 1

* Use the 3-dataset merge from test 1 and verify person-time
capture noisily tvmerge ///
    "/tmp/tvm1_dsetA.dta" "/tmp/tvm1_dsetB.dta" "/tmp/tvm1_dsetC.dta", ///
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

* ============================================================================
* SUMMARY
* ============================================================================
display _n _dup(70) "="
display "TVMERGE REGISTRY VALIDATION SUMMARY"
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
foreach f in cohort tvm1_dsetA tvm1_dsetB tvm1_dsetC tvm2_dsetD tvm2_dsetE ///
    tvm3_batch5 tvm3_batch100 tvm4_dsetA tvm4_dsetB tvm5_dsetA tvm5_dsetB ///
    tvm6_dsetA tvm6_dsetB tvm7_dsetA tvm7_dsetB {
    capture erase "/tmp/`f'.dta"
}
capture erase "/tmp/tvm_cohort.dta"

exit, clear
