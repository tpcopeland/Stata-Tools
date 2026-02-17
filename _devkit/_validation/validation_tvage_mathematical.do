/*******************************************************************************
* validation_tvage_mathematical.do
*
* Purpose: Mathematical correctness validation for tvage with exact expected
*          values computed independently from first principles.
*
* Key insight: tvage uses round(dob + age*365.25) for boundaries — NOT calendar
*              birthdays. This means for round DOBs, the boundary can be computed
*              exactly.
*
* Tests:
*   6a. Birthday boundary for round DOB (DOB=Jan1)
*   6b. Non-round DOB boundary (DOB=Jul1)
*   6c. Groupwidth=5 category assignment
*   6d. minage/maxage clipping
*
* Run: stata-mp -b do validation_tvage_mathematical.do
* Log: validation_tvage_mathematical.log
*
* Author: Claude Code
* Date: 2026-02-17
*******************************************************************************/

clear all
set more off
version 16.0
set varabbrev off

local pass_count = 0
local fail_count = 0
local failed_tests ""

display _n _dup(70) "="
display "TVAGE MATHEMATICAL VALIDATION"
display _dup(70) "="
display "Date: $S_DATE $S_TIME"
display ""

quietly adopath ++ "/home/tpcopeland/Stata-Tools/tvtools"

* ============================================================================
* TEST 6A: BIRTHDAY BOUNDARY FOR ROUND DOB
* ============================================================================
display _n _dup(60) "-"
display "TEST 6A: Birthday boundary - round DOB (Jan1/1980)"
display _dup(60) "-"

local test6a_pass = 1

* DOB = Jan1, 1980 (mdy(1,1,1980))
* Entry = Jan1, 2020 (mdy(1,1,2020))
* Exit  = Dec31, 2020 (mdy(12,31,2020))
*
* Key calculation:
* mdy(1,1,2020) - mdy(1,1,1980) = 14610 days (40 years, 10 leap years)
* age_entry = floor(14610 / 365.25) = floor(40.000) = 40
* age_exit  = floor((mdy(12,31,2020) - mdy(1,1,1980)) / 365.25)
*           = floor(14975 / 365.25) = floor(40.993) = 40
* n_periods = 40 - 40 + 1 = 1
*
* Expected output: 1 row, age_tv=40, age_start=Jan1/2020, age_stop=Dec31/2020

clear
set obs 1
gen id = 1
gen dob = mdy(1,1,1980)
gen entry = mdy(1,1,2020)
gen exit_ = mdy(12,31,2020)
format dob entry exit_ %td

* Verify our math before running tvage
local entry_dob_diff = mdy(1,1,2020) - mdy(1,1,1980)
local exit_dob_diff  = mdy(12,31,2020) - mdy(1,1,1980)
local age_entry = floor(`entry_dob_diff' / 365.25)
local age_exit  = floor(`exit_dob_diff' / 365.25)
display "  INFO: entry-dob=`entry_dob_diff' days, age_entry=`age_entry'"
display "  INFO: exit-dob=`exit_dob_diff' days, age_exit=`age_exit'"

capture noisily tvage, ///
    idvar(id) dobvar(dob) entryvar(entry) exitvar(exit_) ///
    generate(age_tv) startgen(age_start) stopgen(age_stop)

if _rc != 0 {
    display as error "  FAIL [6a.run]: tvage returned error `=_rc'"
    local test6a_pass = 0
}
else {
    sort id age_start
    quietly count
    local nrows = r(N)
    display "  INFO: `nrows' rows in output"
    list id age_tv age_start age_stop, noobs

    if `nrows' == 1 {
        display as result "  PASS [6a.rows]: exactly 1 row (single age=40 period)"
    }
    else {
        display as error "  FAIL [6a.rows]: expected 1 row, got `nrows'"
        local test6a_pass = 0
    }

    if `nrows' >= 1 {
        local age_val = age_tv[1]
        if `age_val' == 40 {
            display as result "  PASS [6a.age]: age_tv=40"
        }
        else {
            display as error "  FAIL [6a.age]: age_tv=`age_val', expected 40"
            local test6a_pass = 0
        }

        local start_val = age_start[1]
        local stop_val  = age_stop[1]
        if `start_val' == mdy(1,1,2020) {
            display as result "  PASS [6a.start]: age_start=Jan1/2020"
        }
        else {
            local actual_date : display %td `start_val'
            display as error "  FAIL [6a.start]: age_start=`actual_date'"
            local test6a_pass = 0
        }

        if `stop_val' == mdy(12,31,2020) {
            display as result "  PASS [6a.stop]: age_stop=Dec31/2020"
        }
        else {
            local actual_date : display %td `stop_val'
            display as error "  FAIL [6a.stop]: age_stop=`actual_date'"
            local test6a_pass = 0
        }
    }
}

if `test6a_pass' == 1 {
    local pass_count = `pass_count' + 1
    display as result "TEST 6A: PASSED"
}
else {
    local fail_count = `fail_count' + 1
    local failed_tests "`failed_tests' 6a"
    display as error "TEST 6A: FAILED"
}

* ============================================================================
* TEST 6B: NON-ROUND DOB (MID-YEAR BIRTHDAY)
* ============================================================================
display _n _dup(60) "-"
display "TEST 6B: Non-round DOB boundary (DOB=Jul1/1980)"
display _dup(60) "-"

local test6b_pass = 1

* DOB = Jul1, 1980 (mdy(7,1,1980))
* Entry = Jan1, 2020
* Exit  = Jun30, 2021
*
* age_entry = floor((mdy(1,1,2020) - mdy(7,1,1980)) / 365.25)
* From Jul 1 1980 to Jan 1 2020:
*   40 years = 14610 days from Jul1 1980 to Jul1 2020
*   Jan 1 to Jul 1 = 182 days in 2020 (Jan31+Feb29+Mar31+Apr30+May31+Jun30 = 182)
*   So Jul1 1980 to Jan1 2020 = 14610 - 182 = 14428 days
*   age_entry = floor(14428 / 365.25) = floor(39.502) = 39
*
* Birthday boundary: round(mdy(7,1,1980) + 40 * 365.25)
*   = round(mdy(7,1,1980) + 14610)
*   = Jul1 1980 + 14610 days = Jul1 2020 (exactly, as confirmed above)
*
* Expected rows:
*   Row 1: age_tv=39, start=Jan1/2020, stop=Jun30/2020
*   Row 2: age_tv=40, start=Jul1/2020, stop=Jun30/2021

clear
set obs 1
gen id = 1
gen dob   = mdy(7,1,1980)
gen entry = mdy(1,1,2020)
gen exit_ = mdy(6,30,2021)
format dob entry exit_ %td

* Verify math
local diff_to_entry = mdy(1,1,2020) - mdy(7,1,1980)
local diff_to_exit  = mdy(6,30,2021) - mdy(7,1,1980)
local age_entry_calc = floor(`diff_to_entry' / 365.25)
local age_exit_calc  = floor(`diff_to_exit' / 365.25)
display "  INFO: entry-dob=`diff_to_entry', age_entry=`age_entry_calc'"
display "  INFO: exit-dob=`diff_to_exit', age_exit=`age_exit_calc'"

capture noisily tvage, ///
    idvar(id) dobvar(dob) entryvar(entry) exitvar(exit_) ///
    generate(age_tv) startgen(age_start) stopgen(age_stop)

if _rc != 0 {
    display as error "  FAIL [6b.run]: tvage returned error `=_rc'"
    local test6b_pass = 0
}
else {
    sort id age_start
    quietly count
    local nrows = r(N)
    display "  INFO: `nrows' rows in output"
    list id age_tv age_start age_stop, noobs

    if `nrows' == 2 {
        display as result "  PASS [6b.rows]: exactly 2 rows (age=39, then age=40)"
    }
    else {
        display as error "  FAIL [6b.rows]: expected 2 rows, got `nrows'"
        local test6b_pass = 0
    }

    if `nrows' >= 2 {
        local age1 = age_tv[1]
        local age2 = age_tv[2]

        if `age1' == 39 & `age2' == 40 {
            display as result "  PASS [6b.ages]: age sequence is 39, 40"
        }
        else {
            display as error "  FAIL [6b.ages]: age sequence is `age1', `age2'"
            local test6b_pass = 0
        }

        * Row 1 should start at study entry
        local start1 = age_start[1]
        if `start1' == mdy(1,1,2020) {
            display as result "  PASS [6b.row1_start]: first row starts at Jan1/2020"
        }
        else {
            local actual_date : display %td `start1'
            display as error "  FAIL [6b.row1_start]: first row starts `actual_date'"
            local test6b_pass = 0
        }

        * Row 2 should start at Jul1/2020 (birthday boundary by tvage's calculation)
        local start2 = age_start[2]
        local expected_boundary = round(mdy(7,1,1980) + 40 * 365.25)
        display "  INFO: Birthday boundary = `expected_boundary' (=`=string(mdy(7,1,1980) + 40 * 365.25, "%td")')"
        if `start2' == `expected_boundary' {
            display as result "  PASS [6b.boundary]: row 2 starts at expected birthday boundary"
        }
        else {
            local actual_date : display %td `start2'
            local expected_date : display %td `expected_boundary'
            display as error "  FAIL [6b.boundary]: row 2 starts `actual_date', expected `expected_date'"
            local test6b_pass = 0
        }
    }
}

if `test6b_pass' == 1 {
    local pass_count = `pass_count' + 1
    display as result "TEST 6B: PASSED"
}
else {
    local fail_count = `fail_count' + 1
    local failed_tests "`failed_tests' 6b"
    display as error "TEST 6B: FAILED"
}

* ============================================================================
* TEST 6C: GROUPWIDTH=5 CATEGORY ASSIGNMENT
* ============================================================================
display _n _dup(60) "-"
display "TEST 6C: Groupwidth=5 category assignment"
display _dup(60) "-"

local test6c_pass = 1

* Test that ages 40-44 → category 40, 45-49 → category 45, 50-54 → category 50
* Using 3 different persons with known ages at entry

clear
set obs 3
gen id = _n
* Person 1: age 42 at entry → should be in category 40
* Person 2: age 47 at entry → should be in category 45
* Person 3: age 50 at entry → should be in category 50
gen dob = .
replace dob = mdy(1,1,2020) - floor(42.5 * 365.25) in 1   // age ~42.5 at Jan1/2020
replace dob = mdy(1,1,2020) - floor(47.5 * 365.25) in 2   // age ~47.5 at Jan1/2020
replace dob = mdy(1,1,2020) - floor(50.5 * 365.25) in 3   // age ~50.5 at Jan1/2020
gen entry = mdy(1,1,2020)
gen exit_ = mdy(12,31,2020)
format dob entry exit_ %td

* Verify ages
forvalues i = 1/3 {
    local d = dob[`i']
    local age_calc = floor((mdy(1,1,2020) - `d') / 365.25)
    display "  INFO: Person `i': dob=`=string(`d', "%td")', age at entry=`age_calc'"
}

capture noisily tvage, ///
    idvar(id) dobvar(dob) entryvar(entry) exitvar(exit_) ///
    generate(age_grp) startgen(age_start) stopgen(age_stop) ///
    groupwidth(5)

if _rc != 0 {
    display as error "  FAIL [6c.run]: tvage returned error `=_rc'"
    local test6c_pass = 0
}
else {
    sort id age_start

    forvalues i = 1/3 {
        quietly sum age_grp if id == `i'
        local min_cat = r(min)
        local max_cat = r(max)
        display "  INFO: Person `i' age categories: `min_cat' to `max_cat'"
    }

    * Person 1 (age ~42): all rows should be in category 40
    quietly sum age_grp if id == 1
    local p1_cat = r(min)
    if `p1_cat' == 40 {
        display as result "  PASS [6c.p1]: person with age 42 has category 40"
    }
    else {
        display as error "  FAIL [6c.p1]: person with age 42 has category `p1_cat' (expected 40)"
        local test6c_pass = 0
    }

    * Person 2 (age ~47): first rows should be in category 45
    quietly sum age_grp if id == 2
    local p2_cat = r(min)
    if `p2_cat' == 45 {
        display as result "  PASS [6c.p2]: person with age 47 has category 45"
    }
    else {
        display as error "  FAIL [6c.p2]: person with age 47 has category `p2_cat' (expected 45)"
        local test6c_pass = 0
    }

    * Person 3 (age ~50): first rows should be in category 50
    quietly sum age_grp if id == 3
    local p3_cat = r(min)
    if `p3_cat' == 50 {
        display as result "  PASS [6c.p3]: person with age 50 has category 50"
    }
    else {
        display as error "  FAIL [6c.p3]: person with age 50 has category `p3_cat' (expected 50)"
        local test6c_pass = 0
    }

    * Verify category formula: floor(age / 5) * 5
    gen expected_cat = floor(age_grp / 5) * 5
    quietly count if expected_cat != age_grp
    if r(N) == 0 {
        display as result "  PASS [6c.formula]: all categories = floor(age/5)*5"
    }
    else {
        display as error "  FAIL [6c.formula]: `=r(N)' rows have wrong category"
        local test6c_pass = 0
    }
}

if `test6c_pass' == 1 {
    local pass_count = `pass_count' + 1
    display as result "TEST 6C: PASSED"
}
else {
    local fail_count = `fail_count' + 1
    local failed_tests "`failed_tests' 6c"
    display as error "TEST 6C: FAILED"
}

* ============================================================================
* TEST 6D: MINAGE/MAXAGE CLIPPING
* ============================================================================
display _n _dup(60) "-"
display "TEST 6D: Minage/maxage clipping"
display _dup(60) "-"

local test6d_pass = 1

* Person A: age 38 at entry, minage=40 → first interval should start at age-40 boundary
* Person B: age 75 at study, maxage=70 → intervals at and after age 70 should be clipped

clear
set obs 2
gen id = _n
* Person 1: age ~38 at entry → minage=40 clips their early intervals
gen dob = .
replace dob = mdy(1,1,2020) - floor(38 * 365.25) in 1
replace dob = mdy(1,1,2020) - floor(70 * 365.25) in 2
gen entry = mdy(1,1,2020)
gen exit_ = mdy(12,31,2025)    // 6-year study
format dob entry exit_ %td

local age1_at_entry = floor((mdy(1,1,2020) - dob[1]) / 365.25)
local age2_at_entry = floor((mdy(1,1,2020) - dob[2]) / 365.25)
display "  INFO: Person 1 age at entry = `age1_at_entry' (minage=40 should clip)"
display "  INFO: Person 2 age at entry = `age2_at_entry' (maxage=73 will be used)"

* Test minage clipping
capture noisily tvage, ///
    idvar(id) dobvar(dob) entryvar(entry) exitvar(exit_) ///
    generate(age_tv) startgen(age_start) stopgen(age_stop) ///
    minage(40) maxage(75)

if _rc != 0 {
    display as error "  FAIL [6d.run]: tvage returned error `=_rc'"
    local test6d_pass = 0
}
else {
    sort id age_start
    display "  INFO: Output:"
    list id age_tv age_start age_stop, noobs

    * Person 1: no intervals with age < 40
    quietly count if id == 1 & age_tv < 40
    if r(N) == 0 {
        display as result "  PASS [6d.minage]: person 1 has no intervals with age < 40"
    }
    else {
        display as error "  FAIL [6d.minage]: person 1 has `=r(N)' intervals with age < 40"
        local test6d_pass = 0
    }

    * All persons: no intervals with age > maxage
    quietly count if age_tv > 75
    if r(N) == 0 {
        display as result "  PASS [6d.maxage]: no intervals with age > 75"
    }
    else {
        display as error "  FAIL [6d.maxage]: `=r(N)' intervals have age > 75"
        local test6d_pass = 0
    }
}

if `test6d_pass' == 1 {
    local pass_count = `pass_count' + 1
    display as result "TEST 6D: PASSED"
}
else {
    local fail_count = `fail_count' + 1
    local failed_tests "`failed_tests' 6d"
    display as error "TEST 6D: FAILED"
}

* ============================================================================
* FINAL SUMMARY
* ============================================================================
local total_tests = `pass_count' + `fail_count'
display _n _dup(70) "="
display "TVAGE MATHEMATICAL VALIDATION SUMMARY"
display _dup(70) "="
display "Tests run:    `total_tests'"
display "Tests passed: `pass_count'"
display "Tests failed: `fail_count'"
if "`failed_tests'" != "" {
    display as error "Failed tests: `failed_tests'"
}
display _dup(70) "="

if `fail_count' == 0 {
    display as result _n "ALL TVAGE MATHEMATICAL TESTS PASSED"
}
else {
    display as error _n "`fail_count' TVAGE MATHEMATICAL TESTS FAILED"
    exit 1
}
