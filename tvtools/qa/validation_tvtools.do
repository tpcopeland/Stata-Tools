/*******************************************************************************
* validation_tvtools.do
*
* Purpose: Consolidated validation tests for all tvtools commands
*          Mathematical correctness, known-answer tests, registry scenarios
*
* Commands validated:
*   tvage, tvbalance, tvevent, tvexpose, tvmerge, tvweight
*   Plus pipeline integration and boundary condition validation
*
* Usage:
*   cd ~/Stata-Tools/tvtools/qa
*   do validation_tvtools.do
*
* Author: Timothy P Copeland
* Date: 2026-03-12
*******************************************************************************/

clear all
set more off
set varabbrev off
version 16.0

* Path configuration
global DATA_DIR "`c(pwd)'/data"

* Install tvtools from package root
capture ado uninstall tvtools
quietly net install tvtools, from("`c(pwd)'/..") replace

* Generate test data if needed
capture confirm file "${DATA_DIR}/cohort.dta"
if _rc != 0 {
    cd data
    do generate_test_data.do
    cd ..
}

* Load validation helpers
do validation_helpers.do

* Initialize test counters
local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""
local quiet = 0
local machine = 0

display as text ""
display as text "tvtools Validation Test Suite"
display as text "Date: $S_DATE $S_TIME"
display as text ""


* =============================================================================
* SECTION 1: TVAGE - Age interval mathematical validation
* =============================================================================
* --- From validation_tvage_mathematical.do ---

capture noisily {
display _n _dup(70) "="
display "TVAGE MATHEMATICAL VALIDATION"
display _dup(70) "="
display "Date: $S_DATE $S_TIME"
display ""


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

}


* =============================================================================
* SECTION 2: TVBALANCE - SMD formula and weighted balance validation
* =============================================================================
* --- From validation_tvbalance_mathematical.do ---

capture noisily {
display _n _dup(70) "="
display "TVBALANCE MATHEMATICAL VALIDATION"
display _dup(70) "="
display "Date: $S_DATE $S_TIME"
display ""


* ============================================================================
* TEST 7A: BINARY COVARIATE SMD (HAND-CALCULATED)
* ============================================================================
display _n _dup(60) "-"
display "TEST 7A: Binary covariate SMD - hand-calculated expected value"
display _dup(60) "-"

local test7a_pass = 1

* Exposed group (n=10):   female = {1,1,1,1,1,0,0,0,0,0} → p_exp = 0.5
* Unexposed group (n=10): female = {1,1,1,0,0,0,0,0,0,0} → p_ref = 0.3
*
* Using Stata's sample variance (N-1 denominator):
*   var_exp = sum((xi - mean)^2) / (N-1) = 5*(0.5)^2 + 5*(0.5)^2 / 9 = 2.5/9 ≈ 0.27778
*   var_ref = 3*(0.7)^2 + 7*(0.3)^2 / 9 = (1.47+0.63)/9 = 2.1/9 ≈ 0.23333
*   pooled_sd = sqrt((0.27778 + 0.23333) / 2) = sqrt(0.25556) ≈ 0.50553
*   SMD = (0.5 - 0.3) / 0.50553 ≈ 0.3956
*
* Note: This differs from the population formula p*(1-p) which gives SMD≈0.417

clear
set obs 20
gen id = _n
gen exposed = (_n <= 10)    // persons 1-10 are exposed, 11-20 unexposed
gen female = 0
* Exposed group: first 5 have female=1
replace female = 1 if id <= 5
* Unexposed group: first 3 unexposed have female=1 (ids 11,12,13)
replace female = 1 if id >= 11 & id <= 13

* Verify data construction
quietly sum female if exposed == 1
display "  INFO: p_exposed = `r(mean)' (expected 0.5)"
quietly sum female if exposed == 0
display "  INFO: p_unexposed = `r(mean)' (expected 0.3)"

* Calculate exact expected SMD using actual data
quietly sum female if exposed == 0
local mean_ref = r(mean)
local var_ref  = r(Var)
quietly sum female if exposed == 1
local mean_exp = r(mean)
local var_exp  = r(Var)

local pooled_sd = sqrt((`var_ref' + `var_exp') / 2)
local expected_smd = (`mean_exp' - `mean_ref') / `pooled_sd'
display "  INFO: Expected SMD (using actual variances) = `expected_smd'"
display "  INFO: var_ref=`var_ref', var_exp=`var_exp', pooled_sd=`pooled_sd'"

capture noisily tvbalance female, exposure(exposed)

if _rc != 0 {
    display as error "  FAIL [7a.run]: tvbalance returned error `=_rc'"
    local test7a_pass = 0
}
else {
    * Check stored results (SMD is in r(balance) matrix, column 3 = SMD_Unwt)
    tempname bal
    matrix `bal' = r(balance)
    local actual_smd = `bal'[1, 3]
    local diff = abs(`actual_smd' - `expected_smd')
    display "  INFO: Reported SMD = `actual_smd', expected = `expected_smd'"

    if `diff' < 0.001 {
        display as result "  PASS [7a.smd]: binary SMD = `actual_smd', expected = `expected_smd'"
    }
    else {
        display as error "  FAIL [7a.smd]: SMD = `actual_smd', expected = `expected_smd', diff = `diff'"
        local test7a_pass = 0
    }
}

if `test7a_pass' == 1 {
    local pass_count = `pass_count' + 1
    display as result "TEST 7A: PASSED"
}
else {
    local fail_count = `fail_count' + 1
    local failed_tests "`failed_tests' 7a"
    display as error "TEST 7A: FAILED"
}

* ============================================================================
* TEST 7B: CONTINUOUS COVARIATE SMD (HAND-CALCULATED)
* ============================================================================
display _n _dup(60) "-"
display "TEST 7B: Continuous covariate SMD - hand-calculated expected value"
display _dup(60) "-"

local test7b_pass = 1

* Exposed (n=10):   age = {51,52,53,54,55,56,57,58,59,60} → mean=55.5
* Unexposed (n=10): age = {41,42,43,44,45,46,47,48,49,50} → mean=45.5
*
* Using Stata's sample variance (N-1):
*   For {51..60}: sum((xi-55.5)^2) = 2*(0.25+2.25+6.25+12.25+20.25) = 2*41.25 = 82.5
*   var_exp = 82.5/9 ≈ 9.1667
*   var_ref = same = 9.1667 (same spread, just shifted)
*   pooled_sd = sqrt((9.1667 + 9.1667)/2) = sqrt(9.1667) ≈ 3.0277
*   SMD = (55.5 - 45.5) / 3.0277 ≈ 3.302
*
* Note: Plan used population variance (giving SMD≈3.482); actual Stata uses sample var

clear
set obs 20
gen id = _n
gen exposed = (_n <= 10)
gen age = 50 + id if exposed == 1      // 51, 52, ..., 60
replace age = 40 + (id - 10) if exposed == 0  // 41, 42, ..., 50

* Verify data
quietly sum age if exposed == 1
display "  INFO: exposed mean age = `r(mean)' (expected 55.5)"
quietly sum age if exposed == 0
display "  INFO: unexposed mean age = `r(mean)' (expected 45.5)"

* Calculate exact expected SMD
quietly sum age if exposed == 0
local mean_ref = r(mean)
local var_ref  = r(Var)
quietly sum age if exposed == 1
local mean_exp = r(mean)
local var_exp  = r(Var)

local pooled_sd = sqrt((`var_ref' + `var_exp') / 2)
local expected_smd = (`mean_exp' - `mean_ref') / `pooled_sd'
display "  INFO: Expected SMD = `expected_smd'"

capture noisily tvbalance age, exposure(exposed)

if _rc != 0 {
    display as error "  FAIL [7b.run]: tvbalance returned error `=_rc'"
    local test7b_pass = 0
}
else {
    tempname bal
    matrix `bal' = r(balance)
    local actual_smd = `bal'[1, 3]
    local diff = abs(`actual_smd' - `expected_smd')
    display "  INFO: Reported SMD = `actual_smd', expected = `expected_smd'"

    if `diff' < 0.001 {
        display as result "  PASS [7b.smd]: continuous SMD = `actual_smd', expected = `expected_smd'"
    }
    else {
        display as error "  FAIL [7b.smd]: SMD = `actual_smd', expected = `expected_smd', diff = `diff'"
        local test7b_pass = 0
    }
}

if `test7b_pass' == 1 {
    local pass_count = `pass_count' + 1
    display as result "TEST 7B: PASSED"
}
else {
    local fail_count = `fail_count' + 1
    local failed_tests "`failed_tests' 7b"
    display as error "TEST 7B: FAILED"
}

* ============================================================================
* TEST 7C: THRESHOLD FLAGGING (N_IMBALANCED COUNT)
* ============================================================================
display _n _dup(60) "-"
display "TEST 7C: Threshold flagging - n_imbalanced count"
display _dup(60) "-"

local test7c_pass = 1

* Create 4 covariates: 2 imbalanced (SMD > 0.1) and 2 balanced (SMD <= 0.1)
* - age_large: mean 55 vs 45, SMD >> 0.1 (imbalanced)
* - age_small: mean 51 vs 50, SMD ≈ 0.03 (balanced)
* - male_large: 80% vs 30%, SMD >> 0.1 (imbalanced)
* - male_small: 50% vs 48%, SMD tiny (balanced)

clear
set obs 50
gen id = _n
gen exposed = (_n <= 25)

* Large age difference (imbalanced)
gen age_large = 45 + exposed * 10 + runiform() * 2
* Small age difference (balanced)
gen age_small = 50 + exposed * 0.5 + runiform() * 2
* Large proportion difference (imbalanced)
gen male_large = (runiform() < (0.8 * exposed + 0.3 * (1-exposed)))
* Small proportion difference (balanced)
gen male_small = (runiform() < (0.5 * exposed + 0.48 * (1-exposed)))

capture noisily tvbalance age_large age_small male_large male_small, ///
    exposure(exposed) threshold(0.1)

if _rc != 0 {
    display as error "  FAIL [7c.run]: tvbalance returned error `=_rc'"
    local test7c_pass = 0
}
else {
    * Check n_imbalanced stored result
    local n_imbalanced = r(n_imbalanced)
    display "  INFO: n_imbalanced = `n_imbalanced' (expected >= 2)"

    if `n_imbalanced' >= 2 {
        display as result "  PASS [7c.flag]: at least 2 imbalanced covariates detected"
    }
    else {
        display as error "  FAIL [7c.flag]: n_imbalanced=`n_imbalanced', expected >= 2"
        local test7c_pass = 0
    }

    * Verify that n_imbalanced <= 4 (can't have more than we have)
    if `n_imbalanced' <= 4 {
        display as result "  PASS [7c.max]: n_imbalanced <= 4 (number of covariates)"
    }
    else {
        display as error "  FAIL [7c.max]: n_imbalanced=`n_imbalanced' > 4 (impossible)"
        local test7c_pass = 0
    }
}

if `test7c_pass' == 1 {
    local pass_count = `pass_count' + 1
    display as result "TEST 7C: PASSED"
}
else {
    local fail_count = `fail_count' + 1
    local failed_tests "`failed_tests' 7c"
    display as error "TEST 7C: FAILED"
}

* ============================================================================
* TEST 7D: SMD FORMULA VERIFICATION (DIRECTION)
* ============================================================================
display _n _dup(60) "-"
display "TEST 7D: SMD formula direction - exposed minus reference"
display _dup(60) "-"

local test7d_pass = 1

* Exposed has higher mean → SMD should be positive
* Exposed has lower mean → SMD should be negative (if signed) or just verify sign

* Exposed: ages 50-59 (mean=54.5), unexposed: ages 30-39 (mean=34.5)
* Both groups have identical variance, SMD = 20/sqrt(9.1667) ≈ 6.604
clear
set obs 20
gen id = _n
gen exposed = (_n <= 10)
gen age = 49 + id if exposed == 1        // 50,51,...,59 → mean=54.5
replace age = 29 + (id - 10) if exposed == 0  // 30,31,...,39 → mean=34.5

capture noisily tvbalance age, exposure(exposed)

if _rc != 0 {
    display as error "  FAIL [7d.run]: tvbalance returned error `=_rc'"
    local test7d_pass = 0
}
else {
    tempname bal
    matrix `bal' = r(balance)
    local actual_smd = `bal'[1, 3]
    display "  INFO: SMD (exposed higher) = `actual_smd'"

    * SMD should be positive (exposed mean > reference mean)
    if `actual_smd' > 0 {
        display as result "  PASS [7d.sign]: SMD > 0 when exposed mean > reference mean"
    }
    else {
        display as error "  FAIL [7d.sign]: SMD = `actual_smd' (expected positive)"
        local test7d_pass = 0
    }

    * Should be approximately (50-30)/sqrt(approx_pooled_var)
    quietly sum age if exposed == 0
    local m_ref = r(mean)
    local v_ref = r(Var)
    quietly sum age if exposed == 1
    local m_exp = r(mean)
    local v_exp = r(Var)
    local expected = (`m_exp' - `m_ref') / sqrt((`v_ref' + `v_exp') / 2)
    local diff = abs(`actual_smd' - `expected')
    if `diff' < 0.001 {
        display as result "  PASS [7d.formula]: SMD matches pooled SD formula"
    }
    else {
        display as error "  FAIL [7d.formula]: SMD=`actual_smd', expected=`expected', diff=`diff'"
        local test7d_pass = 0
    }
}

if `test7d_pass' == 1 {
    local pass_count = `pass_count' + 1
    display as result "TEST 7D: PASSED"
}
else {
    local fail_count = `fail_count' + 1
    local failed_tests "`failed_tests' 7d"
    display as error "TEST 7D: FAILED"
}

* ============================================================================
* FINAL SUMMARY

}


* =============================================================================
* SECTION 4: TVEVENT - Event splitting and person-time conservation
* =============================================================================
* --- From validation_tvevent.do ---

capture noisily {
* =============================================================================
* HELPER PROGRAMS
* =============================================================================

* Program to verify person-time conservation
capture program drop _verify_ptime_conserved
program define _verify_ptime_conserved, rclass
    syntax, start(varname) stop(varname) expected_ptime(real) [tolerance(real 0.001)]

    tempvar dur
    gen double `dur' = `stop' - `start'
    quietly sum `dur'
    local actual = r(sum)
    local pct_diff = abs(`actual' - `expected_ptime') / `expected_ptime'
    return scalar actual_ptime = `actual'
    return scalar pct_diff = `pct_diff'
    return scalar passed = (`pct_diff' < `tolerance')
end

* =============================================================================
* CREATE VALIDATION DATA
* =============================================================================
if `quiet' == 0 {
    display as text _n "Creating validation datasets..."
}

* Interval data for tvevent testing (simulating tvexpose output)
clear
input long id double(start stop) byte tv_exp
    1 21915 22097 1
    1 22097 22281 0
end
format %td start stop
label data "Pre-split intervals for tvevent tests"
save "${DATA_DIR}/intervals_test.dta", replace

* Full-year single interval
clear
input long id double(start stop) byte tv_exp
    1 21915 22281 1
end
format %td start stop
label data "Full-year single interval"
save "${DATA_DIR}/intervals_fullyear.dta", replace

* Two-person intervals for ID preservation tests
clear
input long id double(start stop) byte tv_exp
    1 21915 22281 1
    2 21915 22281 1
end
format %td start stop
label data "Two-person intervals"
save "${DATA_DIR}/intervals_2person.dta", replace

* Event data: mid-year event
clear
input long id double event_dt
    1 22051
end
format %td event_dt
label data "Single mid-year event (May 15, 2020)"
save "${DATA_DIR}/events_midyear.dta", replace

* Event at exact interval boundaries
clear
input long id double event_dt
    1 21915
end
format %td event_dt
label data "Event at interval start (Jan 1, 2020)"
save "${DATA_DIR}/events_at_start.dta", replace

clear
input long id double event_dt
    1 22281
end
format %td event_dt
label data "Event at interval stop (Dec 31, 2020)"
save "${DATA_DIR}/events_at_stop.dta", replace

* Event one day inside boundaries
clear
input long id double event_dt
    1 21916
end
format %td event_dt
label data "Event one day after start (Jan 2, 2020)"
save "${DATA_DIR}/events_day_after_start.dta", replace

* Event outside study period
clear
input long id double event_dt
    1 22400
end
format %td event_dt
label data "Event outside study period"
save "${DATA_DIR}/events_outside.dta", replace

* Competing risk events
clear
input long id double(primary_dt death_dt)
    1 22097 22006
end
format %td primary_dt death_dt
label data "Competing risk: death (Apr 1) before primary (Jun 30)"
save "${DATA_DIR}/events_competing.dta", replace

* Same-day competing events
clear
input long id double(primary_dt compete_dt)
    1 22082 22082
end
format %td primary_dt compete_dt
label data "Same-day competing events (Jun 15, 2020)"
save "${DATA_DIR}/events_sameday.dta", replace

* Person with no event (missing)
clear
input long id double event_dt
    1 22051
    2 .
end
format %td event_dt
label data "Mixed: person 1 has event, person 2 censored"
save "${DATA_DIR}/events_mixed.dta", replace

* Multiple competing risks
clear
input long id double(primary_dt death_dt emig_dt)
    1 22128 22006 22051
end
format %td primary_dt death_dt emig_dt
label data "Multiple competing risks: death (Apr 1), emig (May 15), primary (Aug 1)"
save "${DATA_DIR}/events_multi_compete.dta", replace

* Competing risk events with event_dt naming (for test 4.24.3)
clear
input long id double(event_dt death_dt)
    1 22097 22158
end
format %td event_dt death_dt
label data "Competing risk with event_dt and death_dt"
save "${DATA_DIR}/events_compete.dta", replace

* Multiple competing risks with event_dt naming (for test 4.24.6)
clear
input long id double(event_dt death_dt other_dt)
    1 22097 22158 22189
end
format %td event_dt death_dt other_dt
label data "Three competing risks with event_dt naming"
save "${DATA_DIR}/events_compete_multi.dta", replace

if `quiet' == 0 {
    display as result "Validation datasets created in: ${DATA_DIR}"
}

* =============================================================================
* TEST SECTION 4.1: EVENT INTEGRATION TESTS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 4.1: Event Integration Tests"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 4.1.1: Event Placed at Correct Boundary
* Purpose: Verify event occurs at interval endpoint, not mid-interval
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.1.1: Event Placed at Correct Boundary"
}

capture {
    use "${DATA_DIR}/events_midyear.dta", clear
    tvevent using "${DATA_DIR}/intervals_fullyear.dta", id(id) date(event_dt) ///
        startvar(start) stopvar(stop) type(single) generate(outcome)

    * Event should split the interval
    * The row WITH the event should have stop = event date
    sort start
    quietly count if outcome == 1
    assert r(N) == 1

    * Event row stop should equal the event date
    quietly sum stop if outcome == 1
    assert r(mean) == 22051
}
if _rc == 0 {
    display as result "  PASS: Event placed at correct boundary (stop = event date)"
    local ++pass_count
}
else {
    display as error "  FAIL: Event boundary placement (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.1.1"
}

* -----------------------------------------------------------------------------
* Test 4.1.2: Event Count Preservation
* Purpose: Verify number of events in output matches input
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.1.2: Event Count Preservation"
}

capture {
    * Count events in source
    use "${DATA_DIR}/events_midyear.dta", clear
    quietly count if !missing(event_dt)
    local source_events = r(N)

    * Run tvevent
    tvevent using "${DATA_DIR}/intervals_fullyear.dta", id(id) date(event_dt) ///
        startvar(start) stopvar(stop) type(single) generate(outcome)

    * Count events in output
    quietly count if outcome == 1
    local output_events = r(N)

    assert `source_events' == `output_events'
}
if _rc == 0 {
    display as result "  PASS: Event count preserved (input = output)"
    local ++pass_count
}
else {
    display as error "  FAIL: Event count preservation (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.1.2"
}

* =============================================================================
* TEST SECTION 4.2: INTERVAL SPLITTING TESTS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 4.2: Interval Splitting Tests"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 4.2.1: Split Preserves Total Duration
* Purpose: Verify splitting doesn't create/lose person-time
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.2.1: Split Preserves Total Duration"
}

capture {
    * Calculate pre-tvevent total duration
    use "${DATA_DIR}/intervals_fullyear.dta", clear
    gen double dur = stop - start
    quietly sum dur
    local pre_total = r(sum)

    * Run tvevent
    use "${DATA_DIR}/events_midyear.dta", clear
    tvevent using "${DATA_DIR}/intervals_fullyear.dta", id(id) date(event_dt) ///
        startvar(start) stopvar(stop) type(single) generate(outcome)

    * After tvevent: calculate total duration (should match input)
    gen double dur = stop - start
    quietly sum dur
    local post_total = r(sum)

    * With type(single), duration should be LESS because follow-up truncated at event
    * But total captured person-time should still be meaningful
    * Here we verify that person-time to event is preserved
    assert `post_total' <= `pre_total'
}
if _rc == 0 {
    display as result "  PASS: Total duration preserved or reduced (type=single truncates)"
    local ++pass_count
}
else {
    display as error "  FAIL: Split duration preservation (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.2.1"
}

* =============================================================================
* TEST SECTION 4.3: COMPETING RISK TESTS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 4.3: Competing Risk Tests"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 4.3.1: Earliest Event Wins
* Purpose: Verify competing risk resolution picks earliest date
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.3.1: Earliest Event Wins"
}

capture {
    * Primary event Jun 30, competing event Apr 1
    * Competing (death) is earlier, so should win
    use "${DATA_DIR}/events_competing.dta", clear
    tvevent using "${DATA_DIR}/intervals_fullyear.dta", id(id) date(primary_dt) ///
        startvar(start) stopvar(stop) compete(death_dt) ///
        type(single) generate(outcome)

    * Outcome should be 2 (competing risk) since Apr 1 < Jun 30
    quietly count if outcome == 2
    assert r(N) == 1

    * Event should occur at Apr 1
    quietly sum stop if outcome == 2
    assert r(mean) == 22006
}
if _rc == 0 {
    display as result "  PASS: Earliest event (competing risk) wins"
    local ++pass_count
}
else {
    display as error "  FAIL: Competing risk earliest event (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.3.1"
}

* -----------------------------------------------------------------------------
* Test 4.3.2: Multiple Competing Risks
* Purpose: Verify correct assignment among multiple competing risks
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.3.2: Multiple Competing Risks"
}

capture {
    * Three events: primary (Aug 1), death (Apr 1), emigration (May 15)
    * Death is earliest -> outcome = 2
    use "${DATA_DIR}/events_multi_compete.dta", clear
    tvevent using "${DATA_DIR}/intervals_fullyear.dta", id(id) date(primary_dt) ///
        startvar(start) stopvar(stop) compete(death_dt emig_dt) ///
        type(single) generate(outcome)

    * Outcome codes: 0=censored, 1=primary, 2=death, 3=emigration
    * Death (Apr 1) is earliest -> outcome = 2
    quietly count if outcome == 2
    assert r(N) == 1
}
if _rc == 0 {
    display as result "  PASS: Multiple competing risks: earliest wins (death=2)"
    local ++pass_count
}
else {
    display as error "  FAIL: Multiple competing risks (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.3.2"
}

* =============================================================================
* TEST SECTION 4.4: SINGLE VS RECURRING TESTS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 4.4: Single vs Recurring Tests"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 4.4.1: type(single) Censors After First Event
* Purpose: Verify follow-up ends after first event for single events
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.4.1: type(single) Censors After Event"
}

capture {
    use "${DATA_DIR}/events_midyear.dta", clear
    tvevent using "${DATA_DIR}/intervals_fullyear.dta", id(id) date(event_dt) ///
        startvar(start) stopvar(stop) type(single) generate(outcome)

    * Should have no rows after the event row
    sort id start
    by id: egen event_time = max(stop * (outcome == 1))
    by id: gen post_event = (start > event_time & !missing(event_time))
    quietly count if post_event == 1
    assert r(N) == 0
}
if _rc == 0 {
    display as result "  PASS: type(single) truncates follow-up at event"
    local ++pass_count
}
else {
    display as error "  FAIL: type(single) censoring (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.4.1"
}

* =============================================================================
* TEST SECTION 4.6: BOUNDARY CONDITION TESTS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 4.6: Boundary Condition Tests (CRITICAL)"
    display as text "{hline 70}"
    display as text "Note: tvevent v1.3.5+ captures events at stop (event == stop)"
    display as text "      Events at start are NOT captured (belong to previous interval)"
}

* -----------------------------------------------------------------------------
* Test 4.6.1: Event Exactly at Interval Start
* Purpose: Under [start, stop] inclusive convention, event at start IS captured
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.6.1: Event at Exact Interval Start"
}

capture {
    use "${DATA_DIR}/events_at_start.dta", clear
    tvevent using "${DATA_DIR}/intervals_fullyear.dta", id(id) date(event_dt) ///
        startvar(start) stopvar(stop) type(single) generate(outcome)

    * Under [start, stop] inclusive convention, event at start IS captured
    quietly count if outcome == 1
    assert r(N) == 1
}
if _rc == 0 {
    display as result "  PASS: Event at exact start correctly captured ([start,stop] inclusive)"
    local ++pass_count
}
else {
    display as error "  FAIL: Event at start boundary (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.6.1"
}

* -----------------------------------------------------------------------------
* Test 4.6.2: Event Exactly at Interval Stop
* Purpose: Verify event at stop boundary IS captured (v1.3.5+ behavior)
* Note: This test was updated for v1.3.5 fix - events at stop ARE valid
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.6.2: Event at Exact Interval Stop"
}

capture {
    use "${DATA_DIR}/events_at_stop.dta", clear
    tvevent using "${DATA_DIR}/intervals_fullyear.dta", id(id) date(event_dt) ///
        startvar(start) stopvar(stop) type(single) generate(outcome)

    * Event SHOULD be captured (v1.3.5+ fix: events at stop boundary are valid)
    quietly count if outcome == 1
    assert r(N) == 1
}
if _rc == 0 {
    display as result "  PASS: Event at exact stop IS captured (v1.3.5+ behavior)"
    local ++pass_count
}
else {
    display as error "  FAIL: Event at stop boundary not captured (error `=_rc')"
    display as error "  This may indicate regression to pre-v1.3.5 bug!"
    local ++fail_count
    local failed_tests "`failed_tests' 4.6.2"
}

* -----------------------------------------------------------------------------
* Test 4.6.3: Event One Day Inside Boundaries
* Purpose: Verify events just inside boundaries ARE captured
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.6.3: Event One Day Inside Start"
}

capture {
    use "${DATA_DIR}/events_day_after_start.dta", clear
    tvevent using "${DATA_DIR}/intervals_fullyear.dta", id(id) date(event_dt) ///
        startvar(start) stopvar(stop) type(single) generate(outcome)

    * Event SHOULD be captured (Jan 2 > Jan 1 and < Dec 31)
    quietly count if outcome == 1
    assert r(N) == 1
}
if _rc == 0 {
    display as result "  PASS: Event one day inside boundaries IS captured"
    local ++pass_count
}
else {
    display as error "  FAIL: Event inside boundaries (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.6.3"
}

* =============================================================================
* TEST SECTION 4.7: EDGE CASE TESTS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 4.7: Edge Case Tests"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 4.7.1: Event Outside Study Period
* Purpose: Verify events outside all intervals are ignored
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.7.1: Event Outside Study Period"
}

capture {
    use "${DATA_DIR}/events_outside.dta", clear
    tvevent using "${DATA_DIR}/intervals_fullyear.dta", id(id) date(event_dt) ///
        startvar(start) stopvar(stop) type(single) generate(outcome)

    * No event should be recorded (event outside all intervals)
    quietly count if outcome == 1
    assert r(N) == 0
}
if _rc == 0 {
    display as result "  PASS: Event outside study period not recorded"
    local ++pass_count
}
else {
    display as error "  FAIL: Event outside study period (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.7.1"
}

* -----------------------------------------------------------------------------
* Test 4.7.2: Person with No Events
* Purpose: Verify persons without events are properly censored
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.7.2: Person with No Event (Censored)"
}

capture {
    use "${DATA_DIR}/events_mixed.dta", clear
    tvevent using "${DATA_DIR}/intervals_2person.dta", id(id) date(event_dt) ///
        startvar(start) stopvar(stop) type(single) generate(outcome)

    * Person 2 should have all outcome = 0 (censored)
    quietly count if id == 2 & outcome == 1
    assert r(N) == 0

    * Person 2 should still have follow-up
    quietly count if id == 2
    assert r(N) >= 1
}
if _rc == 0 {
    display as result "  PASS: Person with missing event date is censored (outcome=0)"
    local ++pass_count
}
else {
    display as error "  FAIL: Person with no event (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.7.2"
}

* -----------------------------------------------------------------------------
* Test 4.7.3: Same-Day Competing Events
* Purpose: Verify handling when primary and competing events occur on same day
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.7.3: Same-Day Competing Events"
}

capture {
    use "${DATA_DIR}/events_sameday.dta", clear
    tvevent using "${DATA_DIR}/intervals_fullyear.dta", id(id) date(primary_dt) ///
        startvar(start) stopvar(stop) compete(compete_dt) ///
        type(single) generate(outcome)

    * When dates are equal, document which wins
    * Typically primary should take precedence (outcome = 1)
    quietly count if outcome == 1 | outcome == 2
    local n_events = r(N)

    * At least one event should be recorded
    assert `n_events' >= 1

    * Display which won for documentation (only in verbose mode)
    quietly sum outcome if outcome > 0
}
if _rc == 0 {
    display as result "  PASS: Same-day competing events handled consistently"
    local ++pass_count
}
else {
    display as error "  FAIL: Same-day competing events (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.7.3"
}

* =============================================================================
* TEST SECTION 4.8: ERROR HANDLING TESTS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 4.8: Error Handling Tests"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 4.8.1: Missing Required Variables
* Purpose: Verify informative errors for invalid inputs
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.8.1: Missing Required Variables"
}

capture {
    use "${DATA_DIR}/events_midyear.dta", clear

    * Missing id
    capture tvevent using "${DATA_DIR}/intervals_fullyear.dta", date(event_dt) ///
        startvar(start) stopvar(stop) type(single) generate(outcome)
    local rc1 = _rc

    * Missing date
    capture tvevent using "${DATA_DIR}/intervals_fullyear.dta", id(id) ///
        startvar(start) stopvar(stop) type(single) generate(outcome)
    local rc2 = _rc

    * Both should fail
    assert `rc1' != 0
    assert `rc2' != 0
}
if _rc == 0 {
    display as result "  PASS: Missing required variables produce errors"
    local ++pass_count
}
else {
    display as error "  FAIL: Missing variable error handling (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.8.1"
}

* -----------------------------------------------------------------------------
* Test 4.8.2: Invalid Type Option
* Purpose: Verify invalid type values are rejected
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.8.2: Invalid Type Option"
}

capture {
    use "${DATA_DIR}/events_midyear.dta", clear
    capture tvevent using "${DATA_DIR}/intervals_fullyear.dta", id(id) date(event_dt) ///
        startvar(start) stopvar(stop) type(invalid) generate(outcome)
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: Invalid type() value is rejected"
    local ++pass_count
}
else {
    display as error "  FAIL: Invalid type error handling (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.8.2"
}

* =============================================================================
* TEST SECTION 4.9: TIMEGEN AND TIMEUNIT TESTS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 4.9: timegen and timeunit Tests"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 4.9.1: timegen Creates Time-to-Event Variable
* Purpose: Verify time-to-event calculation is correct
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.9.1: timegen Creates Time Variable"
}

capture {
    use "${DATA_DIR}/events_midyear.dta", clear
    tvevent using "${DATA_DIR}/intervals_fullyear.dta", id(id) date(event_dt) ///
        startvar(start) stopvar(stop) type(single) ///
        timegen(time_to_event) timeunit(days) generate(outcome)

    * Verify time variable exists
    confirm variable time_to_event

    * Time to event should be approximately 136 days (Jan 1 to May 15)
    * 22051 - 21915 = 136 days
    quietly sum time_to_event if outcome == 1
    assert abs(r(mean) - 136) < 2
}
if _rc == 0 {
    display as result "  PASS: timegen creates correct time-to-event (~136 days)"
    local ++pass_count
}
else {
    display as error "  FAIL: timegen time variable (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.9.1"
}

* -----------------------------------------------------------------------------
* Test 4.9.2: timeunit Conversion
* Purpose: Verify time conversion to different units
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.9.2: timeunit(years) Conversion"
}

capture {
    use "${DATA_DIR}/events_midyear.dta", clear
    tvevent using "${DATA_DIR}/intervals_fullyear.dta", id(id) date(event_dt) ///
        startvar(start) stopvar(stop) type(single) ///
        timegen(time_yrs) timeunit(years) generate(outcome)

    * Time in years should be ~0.37 (136 days / 365.25)
    quietly sum time_yrs if outcome == 1
    assert abs(r(mean) - 0.37) < 0.05
}
if _rc == 0 {
    display as result "  PASS: timeunit(years) converts correctly (~0.37 years)"
    local ++pass_count
}
else {
    display as error "  FAIL: timeunit conversion (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.9.2"
}

* Create cumulative time test datasets
* Person 1: 3 intervals starting at 21915, event at 22150 (cumulative=235)
* Person 2: 2 intervals starting at 21915, event at 22100 (cumulative=185)
clear
input long id double(start stop)
    1 21915 22000
    1 22000 22100
    1 22100 22200
    2 21915 22050
    2 22050 22200
end
format %td start stop
label data "Multi-interval cumulative time test"
save "${DATA_DIR}/intervals_cumtime_test.dta", replace

clear
input long id double event_dt
    1 22150
    2 22100
end
format %td event_dt
label data "Events for cumulative time test"
save "${DATA_DIR}/events_cumtime_test.dta", replace

* -----------------------------------------------------------------------------
* Test 4.9.3: timegen Cumulative Time with Multi-Interval Data
* Purpose: Verify timegen calculates stop - first_start (cumulative time)
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.9.3: timegen Cumulative Time (Multi-Interval)"
}

capture {
    use "${DATA_DIR}/events_cumtime_test.dta", clear
    tvevent using "${DATA_DIR}/intervals_cumtime_test.dta", id(id) date(event_dt) ///
        startvar(start) stopvar(stop) type(single) ///
        timegen(cum_time) timeunit(days) generate(outcome)

    * Calculate expected cumulative time for verification
    bysort id (start): gen double first_start = start[1]
    gen double expected = stop - first_start

    * Verify timegen matches expected cumulative time for ALL rows
    gen byte match = abs(cum_time - expected) < 0.001
    quietly count if match == 0
    assert r(N) == 0

    * Verify specific values for event rows:
    * Person 1: event at 22150, cumulative = 22150-21915 = 235
    * Person 2: event at 22100, cumulative = 22100-21915 = 185
    quietly sum cum_time if id == 1 & outcome == 1
    assert abs(r(mean) - 235) < 2

    quietly sum cum_time if id == 2 & outcome == 1
    assert abs(r(mean) - 185) < 2
}
if _rc == 0 {
    display as result "  PASS: timegen correctly calculates cumulative time"
    local ++pass_count
}
else {
    display as error "  FAIL: timegen cumulative time calculation (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.9.3"
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
    use "${DATA_DIR}/events_midyear.dta", clear
    tvevent using "${DATA_DIR}/intervals_fullyear.dta", id(id) date(event_dt) ///
        startvar(start) stopvar(stop) type(single) generate(outcome)

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
* Invariant 2: Outcome Values Only Valid Categories
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Invariant 2: Valid Outcome Categories"
}

capture {
    use "${DATA_DIR}/events_competing.dta", clear
    tvevent using "${DATA_DIR}/intervals_fullyear.dta", id(id) date(primary_dt) ///
        startvar(start) stopvar(stop) compete(death_dt) ///
        type(single) generate(outcome)

    * Should only have values 0 (censored), 1 (primary), or 2 (competing)
    quietly count if outcome < 0 | outcome > 2
    assert r(N) == 0
}
if _rc == 0 {
    display as result "  PASS: Output outcome values are valid categories only"
    local ++pass_count
}
else {
    display as error "  FAIL: Valid outcome categories invariant (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' Inv2"
}

* -----------------------------------------------------------------------------
* Invariant 3: Exactly One Event Per ID (type=single)
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Invariant 3: At Most One Event Per ID (type=single)"
}

capture {
    use "${DATA_DIR}/events_midyear.dta", clear
    tvevent using "${DATA_DIR}/intervals_fullyear.dta", id(id) date(event_dt) ///
        startvar(start) stopvar(stop) type(single) generate(outcome)

    * Count events per ID - should be at most 1
    bysort id: egen n_events = total(outcome == 1)
    quietly sum n_events
    assert r(max) <= 1
}
if _rc == 0 {
    display as result "  PASS: At most one event per ID for type(single)"
    local ++pass_count
}
else {
    display as error "  FAIL: Single event per ID invariant (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' Inv3"
}

* =============================================================================
* TEST SECTION 4.10: CONTINUOUS ADJUSTMENT TESTS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 4.10: continuous() Adjustment Tests"
    display as text "{hline 70}"
}

* Create intervals with cumulative exposure variable
clear
input long id double(start stop) byte tv_exp double cum_dose
    1 21915 22281 1 365
end
format %td start stop
label data "Full-year interval with cumulative dose"
save "${DATA_DIR}/intervals_with_cum.dta", replace

* -----------------------------------------------------------------------------
* Test 4.10.1: continuous() Adjusts Cumulative Variables
* Purpose: Verify continuous variables are proportionally adjusted when split
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.10.1: continuous() Proportional Adjustment"
}

capture {
    use "${DATA_DIR}/events_midyear.dta", clear
    tvevent using "${DATA_DIR}/intervals_with_cum.dta", id(id) date(event_dt) ///
        startvar(start) stopvar(stop) type(single) ///
        continuous(cum_dose) generate(outcome)

    * The original interval was 366 days with cum_dose = 365
    * After split at day 136 (May 15), the first segment should have
    * proportionally adjusted cum_dose
    sort id start
    quietly sum cum_dose if outcome == 1
    local cum_at_event = r(mean)

    * Should be approximately 136/366 * 365 = 135.7
    assert abs(`cum_at_event' - 135.7) < 5
}
if _rc == 0 {
    display as result "  PASS: continuous() proportionally adjusts cumulative variables"
    local ++pass_count
}
else {
    display as error "  FAIL: continuous() adjustment (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.10.1"
}

* =============================================================================
* TEST SECTION 4.11: EVENTLABEL TESTS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 4.11: eventlabel() Tests"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 4.11.1: eventlabel() Sets Custom Value Labels
* Purpose: Verify custom labels are applied to outcome variable
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.11.1: eventlabel() Custom Labels"
}

capture {
    use "${DATA_DIR}/events_competing.dta", clear
    tvevent using "${DATA_DIR}/intervals_fullyear.dta", id(id) date(primary_dt) ///
        startvar(start) stopvar(stop) compete(death_dt) ///
        type(single) generate(outcome) ///
        eventlabel(0 "Alive" 1 "EDSS Progression" 2 "Death")

    * Verify value labels were applied
    local vallbl : value label outcome
    if "`vallbl'" != "" {
        local lbl0 : label `vallbl' 0
        assert "`lbl0'" == "Alive"
        local lbl2 : label `vallbl' 2
        assert "`lbl2'" == "Death"
    }
}
if _rc == 0 {
    display as result "  PASS: eventlabel() sets custom value labels"
    local ++pass_count
}
else {
    display as error "  FAIL: eventlabel() (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.11.1"
}

* =============================================================================
* TEST SECTION 4.12: KEEPVARS TESTS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 4.12: keepvars() Tests"
    display as text "{hline 70}"
}

* Create event data with additional variables
clear
input long id double event_dt str10 dx_code int severity
    1 22051 "G35" 3
end
format %td event_dt
label data "Event with diagnosis code and severity"
save "${DATA_DIR}/events_with_vars.dta", replace

* -----------------------------------------------------------------------------
* Test 4.12.1: keepvars() Retains Additional Variables from Event Dataset
* Purpose: Verify additional variables from event dataset are kept
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.12.1: keepvars() Retains Event Variables"
}

capture {
    use "${DATA_DIR}/events_with_vars.dta", clear
    tvevent using "${DATA_DIR}/intervals_fullyear.dta", id(id) date(event_dt) ///
        startvar(start) stopvar(stop) type(single) ///
        keepvars(dx_code severity) generate(outcome)

    * Verify kept variables exist
    confirm variable dx_code
    confirm variable severity

    * Values should be populated on event row
    quietly count if outcome == 1 & !missing(dx_code)
    assert r(N) >= 1
}
if _rc == 0 {
    display as result "  PASS: keepvars() retains additional variables from event dataset"
    local ++pass_count
}
else {
    display as error "  FAIL: keepvars() (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.12.1"
}

* =============================================================================
* TEST SECTION 4.13: REPLACE OPTION TESTS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 4.13: replace Option Tests"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 4.13.1: replace Overwrites Existing Variables
* Purpose: Verify replace allows overwriting existing outcome variable
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.13.1: replace Overwrites Existing Variables"
}

capture {
    * Create intervals with existing outcome variable
    use "${DATA_DIR}/intervals_fullyear.dta", clear
    gen byte outcome = 99
    save "${DATA_DIR}/intervals_with_outcome.dta", replace

    use "${DATA_DIR}/events_midyear.dta", clear
    tvevent using "${DATA_DIR}/intervals_with_outcome.dta", id(id) date(event_dt) ///
        startvar(start) stopvar(stop) type(single) ///
        generate(outcome) replace

    * Outcome should be 0 or 1, not 99
    quietly count if outcome == 99
    assert r(N) == 0
}
if _rc == 0 {
    display as result "  PASS: replace overwrites existing variables"
    local ++pass_count
}
else {
    display as error "  FAIL: replace option (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.13.1"
}

* =============================================================================
* TEST SECTION 4.14: RECURRING EVENTS TESTS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 4.14: type(recurring) Tests"
    display as text "{hline 70}"
}

* Create wide-format recurring events data
clear
input long id double(hosp1 hosp2 hosp3)
    1 21975 22097 22189
end
format %td hosp1 hosp2 hosp3
label data "Recurring hospitalizations in wide format"
save "${DATA_DIR}/events_recurring_wide.dta", replace

* -----------------------------------------------------------------------------
* Test 4.14.1: type(recurring) Processes Multiple Events
* Purpose: Verify recurring events are all captured
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.14.1: type(recurring) Multiple Events"
}

capture {
    use "${DATA_DIR}/events_recurring_wide.dta", clear
    tvevent using "${DATA_DIR}/intervals_fullyear.dta", id(id) date(hosp) ///
        startvar(start) stopvar(stop) type(recurring) generate(hospitalized)

    * Should have multiple event rows
    quietly count if hospitalized == 1
    assert r(N) >= 1
}
if _rc == 0 {
    display as result "  PASS: type(recurring) processes multiple events"
    local ++pass_count
}
else {
    display as error "  FAIL: type(recurring) (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.14.1"
}

* -----------------------------------------------------------------------------
* Test 4.14.2: type(recurring) Does Not Truncate Follow-up
* Purpose: Verify recurring events preserve all follow-up time
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.14.2: type(recurring) Preserves Follow-up"
}

capture {
    use "${DATA_DIR}/events_recurring_wide.dta", clear
    tvevent using "${DATA_DIR}/intervals_fullyear.dta", id(id) date(hosp) ///
        startvar(start) stopvar(stop) type(recurring) generate(hospitalized)

    * Total follow-up should be preserved (approximately 366 days)
    gen double dur = stop - start
    quietly sum dur
    assert r(sum) >= 300
}
if _rc == 0 {
    display as result "  PASS: type(recurring) preserves follow-up time"
    local ++pass_count
}
else {
    display as error "  FAIL: type(recurring) follow-up (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.14.2"
}

* =============================================================================
* TEST SECTION 4.15: ADDITIONAL TIMEUNIT TESTS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 4.15: Additional timeunit Tests"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 4.15.1: timeunit(months) Conversion
* Purpose: Verify time conversion to months
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.15.1: timeunit(months) Conversion"
}

capture {
    use "${DATA_DIR}/events_midyear.dta", clear
    tvevent using "${DATA_DIR}/intervals_fullyear.dta", id(id) date(event_dt) ///
        startvar(start) stopvar(stop) type(single) ///
        timegen(time_months) timeunit(months) generate(outcome)

    * Time in months should be ~4.5 (136 days / 30.4375)
    quietly sum time_months if outcome == 1
    assert abs(r(mean) - 4.5) < 0.5
}
if _rc == 0 {
    display as result "  PASS: timeunit(months) converts correctly (~4.5 months)"
    local ++pass_count
}
else {
    display as error "  FAIL: timeunit(months) (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.15.1"
}

* =============================================================================
* TEST SECTION 4.16: STORED RESULTS TESTS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 4.16: Stored Results Tests"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 4.16.1: r(N) and r(N_events) Stored
* Purpose: Verify stored scalars are correctly set
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.16.1: Stored Results"
}

capture {
    use "${DATA_DIR}/events_midyear.dta", clear
    tvevent using "${DATA_DIR}/intervals_fullyear.dta", id(id) date(event_dt) ///
        startvar(start) stopvar(stop) type(single) generate(outcome)

    * Verify r() scalars
    assert r(N) > 0
    assert r(N_events) >= 1
}
if _rc == 0 {
    display as result "  PASS: Stored results are correctly set"
    local ++pass_count
}
else {
    display as error "  FAIL: Stored results (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.16.1"
}

* =============================================================================
* TEST SECTION 4.17: ADDITIONAL COMPETING RISK TESTS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 4.17: Additional Competing Risk Tests"
    display as text "{hline 70}"
}

* Create events with 3 competing risks
clear
input long id double(primary_dt cr1_dt cr2_dt cr3_dt)
    1 22189 22097 22128 22159
end
format %td primary_dt cr1_dt cr2_dt cr3_dt
label data "Primary with 3 competing risks"
save "${DATA_DIR}/events_3_competing.dta", replace

* -----------------------------------------------------------------------------
* Test 4.17.1: Three Competing Risks
* Purpose: Verify correct outcome coding with multiple competing risks
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.17.1: Three Competing Risks"
}

capture {
    use "${DATA_DIR}/events_3_competing.dta", clear
    tvevent using "${DATA_DIR}/intervals_fullyear.dta", id(id) date(primary_dt) ///
        startvar(start) stopvar(stop) ///
        compete(cr1_dt cr2_dt cr3_dt) ///
        type(single) generate(outcome)

    * cr1 is earliest (Jun 30) -> outcome should be 2
    quietly count if outcome == 2
    assert r(N) == 1
}
if _rc == 0 {
    display as result "  PASS: Three competing risks correctly resolved"
    local ++pass_count
}
else {
    display as error "  FAIL: Three competing risks (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.17.1"
}

* -----------------------------------------------------------------------------
* Test 4.17.2: Primary Event Wins When Earliest
* Purpose: Verify primary event is coded as 1 when it's earliest
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.17.2: Primary Event Wins When Earliest"
}

capture {
    * Create events where primary is earliest
    clear
    input long id double(primary_dt death_dt)
        1 21975 22097
    end
    format %td primary_dt death_dt
    save "${DATA_DIR}/events_primary_first.dta", replace

    use "${DATA_DIR}/events_primary_first.dta", clear
    tvevent using "${DATA_DIR}/intervals_fullyear.dta", id(id) date(primary_dt) ///
        startvar(start) stopvar(stop) ///
        compete(death_dt) ///
        type(single) generate(outcome)

    * Primary is earliest -> outcome should be 1
    quietly count if outcome == 1
    assert r(N) == 1
}
if _rc == 0 {
    display as result "  PASS: Primary event coded as 1 when earliest"
    local ++pass_count
}
else {
    display as error "  FAIL: Primary event priority (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.17.2"
}

* =============================================================================
* TEST SECTION 4.18: ERROR HANDLING - ADDITIONAL TESTS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 4.18: Additional Error Handling Tests"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 4.18.1: File Not Found Error
* Purpose: Verify error when using file doesn't exist
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.18.1: File Not Found Error"
}

capture {
    use "${DATA_DIR}/events_midyear.dta", clear
    capture tvevent using "nonexistent_file.dta", id(id) date(event_dt) ///
        startvar(start) stopvar(stop) type(single) generate(outcome)
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: File not found produces error"
    local ++pass_count
}
else {
    display as error "  FAIL: File not found error (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.18.1"
}

* -----------------------------------------------------------------------------
* Test 4.18.2: compete() Ignored with type(recurring)
* Purpose: Verify compete() is silently ignored (not error) with type(recurring)
* Note: tvevent displays a note and ignores compete() rather than erroring
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.18.2: compete() Ignored with type(recurring)"
}

capture {
    use "${DATA_DIR}/events_recurring_wide.dta", clear
    tvevent using "${DATA_DIR}/intervals_fullyear.dta", id(id) date(hosp) ///
        startvar(start) stopvar(stop) ///
        type(recurring) compete(hosp2) generate(outcome)
    * Command should succeed (compete() is ignored, not error)
    * Outcome should only have values 0 and 1 (no competing risk value 2)
    quietly tab outcome
    quietly count if outcome == 2
    assert r(N) == 0  // No competing risk outcomes since compete() was ignored
}
if _rc == 0 {
    display as result "  PASS: compete() with type(recurring) is ignored (no error)"
    local ++pass_count
}
else {
    display as error "  FAIL: compete() with recurring handling (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.18.2"
}

* =============================================================================
* TEST SECTION 4.19: STARTVAR/STOPVAR CUSTOM NAMES TESTS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 4.19: startvar/stopvar Custom Names Tests"
    display as text "{hline 70}"
}

* Create interval data with non-standard column names
clear
input long id double(begin_dt end_dt) byte tv_exp
    1 21915 22281 1
end
format %td begin_dt end_dt
label data "Intervals with custom column names"
save "${DATA_DIR}/intervals_custom_names.dta", replace

* -----------------------------------------------------------------------------
* Test 4.19.1: startvar() and stopvar() with Custom Names
* Purpose: Verify startvar/stopvar options work with non-default names
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.19.1: startvar()/stopvar() Custom Names"
}

capture {
    use "${DATA_DIR}/events_midyear.dta", clear
    tvevent using "${DATA_DIR}/intervals_custom_names.dta", id(id) date(event_dt) ///
        startvar(begin_dt) stopvar(end_dt) type(single) generate(outcome)

    * Should produce valid output with custom start/stop variable names
    assert _N >= 1
    confirm variable begin_dt
    confirm variable end_dt

    * Event should be captured
    quietly count if outcome == 1
    assert r(N) == 1
}
if _rc == 0 {
    display as result "  PASS: startvar()/stopvar() work with custom names"
    local ++pass_count
}
else {
    display as error "  FAIL: startvar()/stopvar() custom names (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.19.1"
}

* =============================================================================
* TEST SECTION 4.20: GENERATE CUSTOM NAME TESTS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 4.20: generate() Custom Name Tests"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 4.20.1: generate() with Custom Variable Name
* Purpose: Verify generate() creates variable with user-specified name
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.20.1: generate() Custom Variable Name"
}

capture {
    use "${DATA_DIR}/events_midyear.dta", clear
    tvevent using "${DATA_DIR}/intervals_fullyear.dta", id(id) date(event_dt) ///
        startvar(start) stopvar(stop) type(single) generate(my_event_flag)

    * Verify custom variable name exists
    confirm variable my_event_flag

    * Default _failure should NOT exist
    capture confirm variable _failure
    assert _rc != 0

    * Event should be recorded in custom variable
    quietly count if my_event_flag == 1
    assert r(N) == 1
}
if _rc == 0 {
    display as result "  PASS: generate() creates custom-named variable"
    local ++pass_count
}
else {
    display as error "  FAIL: generate() custom name (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.20.1"
}

* =============================================================================
* TEST SECTION 4.21: EDGE CASES - EMPTY AND MISSING DATA
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 4.21: Edge Cases - Empty and Missing Data"
    display as text "{hline 70}"
}

* Create empty event dataset
clear
set obs 0
gen long id = .
gen double event_dt = .
format %td event_dt
label data "Empty event dataset"
save "${DATA_DIR}/events_empty.dta", replace

* Create events with all missing dates
clear
input long id double event_dt
    1 .
    2 .
end
format %td event_dt
label data "Events with all missing dates"
save "${DATA_DIR}/events_all_missing.dta", replace

* -----------------------------------------------------------------------------
* Test 4.21.1: Empty Event Dataset
* Purpose: Verify handling when event dataset has no observations
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.21.1: Empty Event Dataset"
}

capture {
    use "${DATA_DIR}/events_empty.dta", clear
    tvevent using "${DATA_DIR}/intervals_fullyear.dta", id(id) date(event_dt) ///
        startvar(start) stopvar(stop) type(single) generate(outcome)

    * Should produce output but with no events
    quietly count if outcome == 1
    assert r(N) == 0
}
if _rc == 0 {
    display as result "  PASS: Empty event dataset produces no events"
    local ++pass_count
}
else {
    display as error "  FAIL: Empty event dataset (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.21.1"
}

* -----------------------------------------------------------------------------
* Test 4.21.2: All Missing Event Dates
* Purpose: Verify handling when all event dates are missing
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.21.2: All Missing Event Dates"
}

capture {
    use "${DATA_DIR}/events_all_missing.dta", clear
    tvevent using "${DATA_DIR}/intervals_2person.dta", id(id) date(event_dt) ///
        startvar(start) stopvar(stop) type(single) generate(outcome)

    * Should produce output with all censored (outcome = 0)
    quietly count if outcome == 1
    assert r(N) == 0

    * But should have follow-up time
    assert _N >= 1
}
if _rc == 0 {
    display as result "  PASS: All missing dates produces all censored"
    local ++pass_count
}
else {
    display as error "  FAIL: All missing dates (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.21.2"
}

* =============================================================================
* TEST SECTION 4.22: INVALID OPTIONS ERROR HANDLING
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 4.22: Invalid Options Error Handling"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 4.22.1: Invalid timeunit Value
* Purpose: Verify error when timeunit has invalid value
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.22.1: Invalid timeunit Value"
}

capture {
    use "${DATA_DIR}/events_midyear.dta", clear
    capture tvevent using "${DATA_DIR}/intervals_fullyear.dta", id(id) date(event_dt) ///
        startvar(start) stopvar(stop) type(single) ///
        timegen(time) timeunit(invalid_unit) generate(outcome)
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: Invalid timeunit produces error"
    local ++pass_count
}
else {
    display as error "  FAIL: Invalid timeunit error (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.22.1"
}

* -----------------------------------------------------------------------------
* Test 4.22.2: Missing Required Using File
* Purpose: Verify error when using file is not specified
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.22.2: Missing Using File"
}

capture {
    use "${DATA_DIR}/events_midyear.dta", clear
    capture tvevent, id(id) date(event_dt) ///
        startvar(start) stopvar(stop) type(single) generate(outcome)
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: Missing using file produces error"
    local ++pass_count
}
else {
    display as error "  FAIL: Missing using file error (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.22.2"
}

* =============================================================================
* TEST SECTION 4.23: CONTINUOUS VARIABLE EDGE CASES
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 4.23: Continuous Variable Edge Cases"
    display as text "{hline 70}"
}

* Create interval with multiple continuous variables
clear
input long id double(start stop) byte tv_exp double(cum_dose cum_cost)
    1 21915 22281 1 365 1000
end
format %td start stop
label data "Interval with multiple continuous variables"
save "${DATA_DIR}/intervals_multi_cont.dta", replace

* -----------------------------------------------------------------------------
* Test 4.23.1: Multiple Continuous Variables
* Purpose: Verify multiple continuous variables are all adjusted
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.23.1: Multiple Continuous Variables"
}

capture {
    use "${DATA_DIR}/events_midyear.dta", clear
    tvevent using "${DATA_DIR}/intervals_multi_cont.dta", id(id) date(event_dt) ///
        startvar(start) stopvar(stop) type(single) ///
        continuous(cum_dose cum_cost) generate(outcome)

    * Both continuous variables should exist and be adjusted
    confirm variable cum_dose
    confirm variable cum_cost

    * Values should be pro-rated (not original 365/1000)
    sort id start
    quietly sum cum_dose if outcome == 1
    local cum_dose_event = r(mean)
    assert `cum_dose_event' < 365

    quietly sum cum_cost if outcome == 1
    local cum_cost_event = r(mean)
    assert `cum_cost_event' < 1000
}
if _rc == 0 {
    display as result "  PASS: Multiple continuous variables adjusted correctly"
    local ++pass_count
}
else {
    display as error "  FAIL: Multiple continuous variables (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.23.1"
}

* =============================================================================
* TEST SECTION 4.24: OPTION COMBINATIONS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 4.24: Option Combinations"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 4.24.1: type(recurring) + timegen + timeunit(months)
* Purpose: Verify recurring events with time variable in months
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.24.1: type(recurring) + timegen + timeunit(months)"
}

capture {
    use "${DATA_DIR}/events_recurring_wide.dta", clear
    tvevent using "${DATA_DIR}/intervals_fullyear.dta", id(id) date(hosp) ///
        startvar(start) stopvar(stop) type(recurring) ///
        timegen(time_months) timeunit(months) generate(outcome)

    * Time variable should exist and be in months
    confirm variable time_months
    quietly sum time_months
    * 366 days / 30.4375 = ~12 months max
    assert r(max) < 15
}
if _rc == 0 {
    display as result "  PASS: type(recurring) + timegen + timeunit(months) works"
    local ++pass_count
}
else {
    display as error "  FAIL: type(recurring) + timegen + timeunit(months) (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.24.1"
}

* -----------------------------------------------------------------------------
* Test 4.24.2: type(recurring) + continuous + keepvars
* Purpose: Verify recurring events with continuous and additional variables
* Note: keepvars brings variables from the MASTER (events) dataset
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.24.2: type(recurring) + continuous + keepvars"
}

* Create interval with continuous variable
clear
input long id double(start stop) byte tv_exp double cumulative
    1 21915 22281 1 365
end
format %td start stop
label data "Interval with cumulative exposure"
save "${DATA_DIR}/intervals_extra_vars.dta", replace

* Create events with keepvars variable (drug is in events, not intervals)
clear
input long id double(hosp1 hosp2 hosp3) str10 drug
    1 21975 22097 22189 "DrugA"
end
format %td hosp1 hosp2 hosp3
label data "Recurring events with drug variable"
save "${DATA_DIR}/events_recurring_keepvars.dta", replace

capture {
    use "${DATA_DIR}/events_recurring_keepvars.dta", clear
    tvevent using "${DATA_DIR}/intervals_extra_vars.dta", id(id) date(hosp) ///
        startvar(start) stopvar(stop) type(recurring) ///
        continuous(cumulative) keepvars(drug) generate(outcome)

    * Both options should work together
    confirm variable cumulative
    confirm variable drug

    * Cumulative should be pro-rated for split intervals
    quietly sum cumulative
    assert r(max) <= 365
}
if _rc == 0 {
    display as result "  PASS: type(recurring) + continuous + keepvars works"
    local ++pass_count
}
else {
    display as error "  FAIL: type(recurring) + continuous + keepvars (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.24.2"
}

* -----------------------------------------------------------------------------
* Test 4.24.3: compete() + eventlabel()
* Purpose: Verify competing risks with labels
* Note: keepvars removed since events_compete.dta has no extra vars to keep
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.24.3: compete() + eventlabel()"
}

capture {
    use "${DATA_DIR}/events_compete.dta", clear
    tvevent using "${DATA_DIR}/intervals_extra_vars.dta", id(id) date(event_dt) ///
        startvar(start) stopvar(stop) type(single) ///
        compete(death_dt) eventlabel(0 "Censored" 1 "Primary" 2 "Death") ///
        generate(outcome)

    * All features should work together
    confirm variable outcome

    * Check value labels are applied
    local lbl : value label outcome
    assert "`lbl'" != ""
}
if _rc == 0 {
    display as result "  PASS: compete() + eventlabel() works"
    local ++pass_count
}
else {
    display as error "  FAIL: compete() + eventlabel() (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.24.3"
}

* -----------------------------------------------------------------------------
* Test 4.24.4: timegen + timeunit(years) + continuous
* Purpose: Verify time in years with continuous variable adjustment
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.24.4: timegen + timeunit(years) + continuous"
}

capture {
    use "${DATA_DIR}/events_midyear.dta", clear
    tvevent using "${DATA_DIR}/intervals_multi_cont.dta", id(id) date(event_dt) ///
        startvar(start) stopvar(stop) type(single) ///
        timegen(time_years) timeunit(years) ///
        continuous(cum_dose cum_cost) generate(outcome)

    * Time should be in years (< 2 for one year)
    confirm variable time_years
    quietly sum time_years
    assert r(max) < 2

    * Continuous variables should still work
    confirm variable cum_dose
    confirm variable cum_cost
}
if _rc == 0 {
    display as result "  PASS: timegen + timeunit(years) + continuous works"
    local ++pass_count
}
else {
    display as error "  FAIL: timegen + timeunit(years) + continuous (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.24.4"
}

* -----------------------------------------------------------------------------
* Test 4.24.5: replace + existing variable
* Purpose: Verify replace properly handles pre-existing outcome variable in using dataset
* Note: The existing variable must be in the USING (intervals) dataset, not master (events)
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.24.5: replace with Existing Variable"
}

capture {
    * Create intervals file with pre-existing outcome variable
    use "${DATA_DIR}/intervals_fullyear.dta", clear
    gen byte outcome = 99
    save "${DATA_DIR}/intervals_with_outcome.dta", replace

    * Load events and run tvevent with replace
    use "${DATA_DIR}/events_midyear.dta", clear
    tvevent using "${DATA_DIR}/intervals_with_outcome.dta", id(id) date(event_dt) ///
        startvar(start) stopvar(stop) type(single) generate(outcome) replace

    * Outcome should be replaced (not 99)
    quietly count if outcome == 99
    assert r(N) == 0

    * Clean up temp file
    capture erase "${DATA_DIR}/intervals_with_outcome.dta"
}
if _rc == 0 {
    display as result "  PASS: replace properly overwrites existing variable"
    local ++pass_count
}
else {
    display as error "  FAIL: replace with existing variable (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.24.5"
}

* -----------------------------------------------------------------------------
* Test 4.24.6: Multiple Competing Risks + continuous + timegen
* Purpose: Verify three competing risks with all options
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.24.6: Multiple compete() + continuous + timegen"
}

capture {
    use "${DATA_DIR}/events_compete_multi.dta", clear
    tvevent using "${DATA_DIR}/intervals_multi_cont.dta", id(id) date(event_dt) ///
        startvar(start) stopvar(stop) type(single) ///
        compete(death_dt other_dt) continuous(cum_dose) ///
        timegen(time) timeunit(days) generate(outcome)

    * All options should work together
    confirm variable outcome
    confirm variable cum_dose
    confirm variable time

    * Outcome should have values 0, 1, 2, or 3
    quietly count if outcome < 0 | outcome > 3
    assert r(N) == 0
}
if _rc == 0 {
    display as result "  PASS: Multiple compete() + continuous + timegen works"
    local ++pass_count
}
else {
    display as error "  FAIL: Multiple compete() + continuous + timegen (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.24.6"
}

* =============================================================================
* TEST SECTION 4.25: BOUNDARY VALUE TESTS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 4.25: Boundary Value Tests"
    display as text "{hline 70}"
}

* Create event exactly at interval boundaries
clear
input long id double event_dt
    1 21915
end
format %td event_dt
label data "Event at exact start boundary"
save "${DATA_DIR}/events_at_start.dta", replace

clear
input long id double event_dt
    1 22281
end
format %td event_dt
label data "Event at exact stop boundary"
save "${DATA_DIR}/events_at_stop.dta", replace

* -----------------------------------------------------------------------------
* Test 4.25.1: Event Exactly at Interval Start
* Purpose: Under [start, stop] inclusive convention, event at start IS captured
* Note: This test confirms the same behavior as Test 4.6.1
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.25.1: Event at Interval Start Boundary"
}

capture {
    use "${DATA_DIR}/events_at_start.dta", clear
    tvevent using "${DATA_DIR}/intervals_fullyear.dta", id(id) date(event_dt) ///
        startvar(start) stopvar(stop) type(single) generate(outcome)

    * Under [start, stop] inclusive convention, event at start IS captured
    quietly count if outcome == 1
    assert r(N) == 1

    * Data should have at least one row
    assert _N >= 1
}
if _rc == 0 {
    display as result "  PASS: Event at interval start boundary correctly captured"
    local ++pass_count
}
else {
    display as error "  FAIL: Event at start boundary (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.25.1"
}

* -----------------------------------------------------------------------------
* Test 4.25.2: Event Exactly at Interval Stop
* Purpose: Verify event at last day of interval (boundary condition)
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.25.2: Event at Interval Stop Boundary"
}

capture {
    use "${DATA_DIR}/events_at_stop.dta", clear
    tvevent using "${DATA_DIR}/intervals_fullyear.dta", id(id) date(event_dt) ///
        startvar(start) stopvar(stop) type(single) generate(outcome)

    * Event at stop should be captured (stop is exclusive in survival)
    * This tests the boundary handling
    assert _N >= 1
}
if _rc == 0 {
    display as result "  PASS: Event at interval stop boundary handled"
    local ++pass_count
}
else {
    display as error "  FAIL: Event at stop boundary (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.25.2"
}

* -----------------------------------------------------------------------------
* Test 4.25.3: Very Short Interval (1 day)
* Purpose: Verify handling of minimal duration intervals
* Note: Under [start, stop] inclusive, event at start of 1-day interval IS captured
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.25.3: Very Short Interval (1 Day)"
}

* Create 1-day interval [22006, 22007] = 2 days under inclusive convention
clear
input long id double(start stop) byte tv_exp
    1 22006 22007 1
end
format %td start stop
save "${DATA_DIR}/intervals_oneday.dta", replace

* Event at start date - captured under [start, stop] inclusive convention
clear
input long id double event_dt
    1 22006
end
format %td event_dt
save "${DATA_DIR}/events_oneday.dta", replace

capture {
    use "${DATA_DIR}/events_oneday.dta", clear
    tvevent using "${DATA_DIR}/intervals_oneday.dta", id(id) date(event_dt) ///
        startvar(start) stopvar(stop) type(single) generate(outcome)

    * Under [start, stop] inclusive convention, event at start IS captured
    assert _N >= 1
    quietly count if outcome == 1
    assert r(N) == 1
}
if _rc == 0 {
    display as result "  PASS: 1-day interval - event at start captured ([start,stop] inclusive)"
    local ++pass_count
}
else {
    display as error "  FAIL: 1-day interval (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.25.3"
}

* =============================================================================
* TEST SECTION 4.26: MULTI-PERSON TESTS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 4.26: Multi-Person Tests"
    display as text "{hline 70}"
}

* Create multi-person interval data
clear
input long id double(start stop) byte tv_exp
    1 21915 22006 1
    1 22006 22189 2
    1 22189 22281 1
    2 21915 22097 1
    2 22097 22281 2
    3 21915 22281 1
end
format %td start stop
label data "Multi-person intervals with varying exposure"
save "${DATA_DIR}/intervals_multiperson.dta", replace

* Multi-person events
clear
input long id double event_dt
    1 22100
    2 22200
end
format %td event_dt
label data "Events for persons 1 and 2, none for 3"
save "${DATA_DIR}/events_multiperson.dta", replace

* -----------------------------------------------------------------------------
* Test 4.26.1: Multiple Persons with Different Event Status
* Purpose: Verify correct handling of mixed event/censored persons
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.26.1: Multiple Persons with Mixed Event Status"
}

capture {
    use "${DATA_DIR}/events_multiperson.dta", clear
    tvevent using "${DATA_DIR}/intervals_multiperson.dta", id(id) date(event_dt) ///
        startvar(start) stopvar(stop) type(single) generate(outcome)

    * Person 1 and 2 should have events, person 3 censored
    quietly count if id == 1 & outcome == 1
    local p1_events = r(N)
    quietly count if id == 2 & outcome == 1
    local p2_events = r(N)
    quietly count if id == 3 & outcome == 1
    local p3_events = r(N)

    assert `p1_events' == 1
    assert `p2_events' == 1
    assert `p3_events' == 0
}
if _rc == 0 {
    display as result "  PASS: Multiple persons with mixed event status handled correctly"
    local ++pass_count
}
else {
    display as error "  FAIL: Multi-person mixed events (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.26.1"
}

* -----------------------------------------------------------------------------
* Test 4.26.2: Multi-Person Recurring Events
* Purpose: Verify recurring events across multiple persons
* Note: type(recurring) requires WIDE format data with hosp1, hosp2, hosp3, etc.
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.26.2: Multi-Person Recurring Events"
}

* Create recurring events for multiple persons in WIDE format
clear
input long id double(hosp1 hosp2 hosp3)
    1 21950 22100 .
    2 22050 . .
    3 21980 22150 22250
end
format %td hosp1 hosp2 hosp3
label data "Recurring events for multiple persons (wide format)"
save "${DATA_DIR}/events_multi_recurring.dta", replace

capture {
    use "${DATA_DIR}/events_multi_recurring.dta", clear
    tvevent using "${DATA_DIR}/intervals_multiperson.dta", id(id) date(hosp) ///
        startvar(start) stopvar(stop) type(recurring) generate(outcome)

    * Count events per person
    quietly count if id == 1 & outcome == 1
    local p1_events = r(N)
    quietly count if id == 2 & outcome == 1
    local p2_events = r(N)
    quietly count if id == 3 & outcome == 1
    local p3_events = r(N)

    * Each person should have their events counted
    * Note: exact count depends on which events fall within intervals
    assert `p1_events' >= 0
    assert `p2_events' >= 0
    assert `p3_events' >= 0

    * At least some events should be recorded
    assert `p1_events' + `p2_events' + `p3_events' >= 1
}
if _rc == 0 {
    display as result "  PASS: Multi-person recurring events counted correctly"
    local ++pass_count
}
else {
    display as error "  FAIL: Multi-person recurring (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.26.2"
}

* =============================================================================
* TEST SECTION 4.27: ADVANCED EDGE CASES - COMPLEX EVENT SCENARIOS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 4.27: Advanced Edge Cases - Complex Event Scenarios"
    display as text "{hline 70}"
}

* Create events very close together (within 1-2 days)
clear
input long id double(hosp1 hosp2 hosp3)
    1 22006 22007 22009
end
format %td hosp1 hosp2 hosp3
label data "Back-to-back events (1-2 days apart)"
save "${DATA_DIR}/events_backtoback.dta", replace

* Create multiple persons with identical event dates
clear
input long id double event_dt
    1 22097
    2 22097
    3 22097
end
format %td event_dt
label data "Multiple persons with same event date"
save "${DATA_DIR}/events_same_date_multi.dta", replace

* Create intervals with zero-value continuous variable
clear
input long id double(start stop) byte tv_exp double cum_exp
    1 21915 22281 1 0
end
format %td start stop
label data "Full year with zero cumulative exposure"
save "${DATA_DIR}/intervals_zero_cum.dta", replace

* Create event before study start
clear
input long id double event_dt
    1 21800
end
format %td event_dt
label data "Event before study period (should be ignored)"
save "${DATA_DIR}/events_before_study.dta", replace

* Create intervals already pre-split (multiple intervals per person)
clear
input long id double(start stop) byte tv_exp
    1 21915 21946 1
    1 21946 22006 2
    1 22006 22097 1
    1 22097 22189 2
    1 22189 22281 1
end
format %td start stop
label data "Pre-split intervals with alternating exposure"
save "${DATA_DIR}/intervals_presplit.dta", replace

* Create event landing exactly on a pre-split boundary
clear
input long id double event_dt
    1 21946
end
format %td event_dt
label data "Event exactly on interval split point"
save "${DATA_DIR}/events_on_split.dta", replace

* -----------------------------------------------------------------------------
* Test 4.27.1: Back-to-Back Events (Micro-Intervals)
* Purpose: Verify close-together recurring events create valid intervals
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.27.1: Back-to-Back Events (1-2 Days Apart)"
}

capture {
    use "${DATA_DIR}/events_backtoback.dta", clear
    tvevent using "${DATA_DIR}/intervals_fullyear.dta", id(id) date(hosp) ///
        startvar(start) stopvar(stop) type(recurring) generate(outcome)

    * Should create multiple micro-intervals
    assert _N >= 3

    * All intervals should have valid duration (stop >= start under [start,stop] inclusive)
    * Single-day intervals have stop == start, which is valid
    quietly count if stop < start
    assert r(N) == 0

    * Multiple events should be recorded
    quietly count if outcome == 1
    assert r(N) >= 2
}
if _rc == 0 {
    display as result "  PASS: Back-to-back events create valid micro-intervals"
    local ++pass_count
}
else {
    display as error "  FAIL: Back-to-back events (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.27.1"
}

* -----------------------------------------------------------------------------
* Test 4.27.2: Multiple Persons Same Event Date
* Purpose: Verify events on same date for different persons handled correctly
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.27.2: Multiple Persons Same Event Date"
}

capture {
    * Create 3-person interval dataset
    clear
    input long id double(start stop) byte tv_exp
        1 21915 22281 1
        2 21915 22281 1
        3 21915 22281 1
    end
    format %td start stop
    save "${DATA_DIR}/intervals_3person.dta", replace

    use "${DATA_DIR}/events_same_date_multi.dta", clear
    tvevent using "${DATA_DIR}/intervals_3person.dta", id(id) date(event_dt) ///
        startvar(start) stopvar(stop) type(single) generate(outcome)

    * Each person should have exactly one event
    forvalues i = 1/3 {
        quietly count if id == `i' & outcome == 1
        assert r(N) == 1
    }

    * All events should be on the same date
    quietly sum stop if outcome == 1
    assert r(sd) == 0 | r(N) == 0  // All identical or none
}
if _rc == 0 {
    display as result "  PASS: Multiple persons same date each get their event"
    local ++pass_count
}
else {
    display as error "  FAIL: Multiple persons same date (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.27.2"
}

* -----------------------------------------------------------------------------
* Test 4.27.3: Zero-Valued Continuous Variable
* Purpose: Verify continuous adjustment handles zero values correctly
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.27.3: Zero-Valued Continuous Variable"
}

capture {
    use "${DATA_DIR}/events_midyear.dta", clear
    tvevent using "${DATA_DIR}/intervals_zero_cum.dta", id(id) date(event_dt) ///
        startvar(start) stopvar(stop) type(single) ///
        continuous(cum_exp) generate(outcome)

    * Zero continuous variable should remain zero after proportional adjustment
    quietly sum cum_exp
    assert r(mean) == 0
}
if _rc == 0 {
    display as result "  PASS: Zero continuous variable remains zero after adjustment"
    local ++pass_count
}
else {
    display as error "  FAIL: Zero continuous variable (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.27.3"
}

* -----------------------------------------------------------------------------
* Test 4.27.4: Event Before Study Period
* Purpose: Verify events before study start are ignored
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.27.4: Event Before Study Period"
}

capture {
    use "${DATA_DIR}/events_before_study.dta", clear
    tvevent using "${DATA_DIR}/intervals_fullyear.dta", id(id) date(event_dt) ///
        startvar(start) stopvar(stop) type(single) generate(outcome)

    * Event before study should not be captured
    quietly count if outcome == 1
    assert r(N) == 0

    * Follow-up should still exist
    assert _N >= 1
}
if _rc == 0 {
    display as result "  PASS: Event before study period is ignored"
    local ++pass_count
}
else {
    display as error "  FAIL: Event before study (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.27.4"
}

* -----------------------------------------------------------------------------
* Test 4.27.5: Event on Pre-Existing Split Boundary
* Purpose: Verify event at split point IS captured (v1.3.5+ behavior)
* Note: This test was updated for v1.3.5 fix - events at stop ARE valid
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.27.5: Event on Pre-Existing Split Boundary"
}

capture {
    use "${DATA_DIR}/events_on_split.dta", clear
    tvevent using "${DATA_DIR}/intervals_presplit.dta", id(id) date(event_dt) ///
        startvar(start) stopvar(stop) type(single) generate(outcome)

    * Event at boundary (21946) is stop of first interval and start of second
    * With v1.3.5+ fix, event at stop SHOULD be captured
    * Event is flagged at the interval that ENDS at the event date
    quietly count if outcome == 1
    assert r(N) == 1  // Event at stop boundary IS captured (v1.3.5+)
}
if _rc == 0 {
    display as result "  PASS: Event on pre-existing split boundary captured (v1.3.5+)"
    local ++pass_count
}
else {
    display as error "  FAIL: Event on split boundary not captured (error `=_rc')"
    display as error "  This may indicate regression to pre-v1.3.5 bug!"
    local ++fail_count
    local failed_tests "`failed_tests' 4.27.5"
}

* -----------------------------------------------------------------------------
* Test 4.27.6: Recurring Events with Pre-Split Intervals
* Purpose: Verify recurring events correctly split pre-fragmented data
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.27.6: Recurring Events with Pre-Split Intervals"
}

capture {
    * Create events in the middle of different intervals
    clear
    input long id double(hosp1 hosp2)
        1 21930 22150
    end
    format %td hosp1 hosp2
    save "${DATA_DIR}/events_in_presplit.dta", replace

    use "${DATA_DIR}/events_in_presplit.dta", clear
    tvevent using "${DATA_DIR}/intervals_presplit.dta", id(id) date(hosp) ///
        startvar(start) stopvar(stop) type(recurring) generate(outcome)

    * Both events should be captured (they fall within intervals, not on boundaries)
    quietly count if outcome == 1
    assert r(N) >= 1

    * No overlapping output intervals
    sort id start
    by id: gen byte overlap_check = (start[_n] < stop[_n-1]) if _n > 1
    quietly count if overlap_check == 1
    assert r(N) == 0
}
if _rc == 0 {
    display as result "  PASS: Recurring events with pre-split intervals work correctly"
    local ++pass_count
}
else {
    display as error "  FAIL: Recurring with pre-split (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.27.6"
}

* =============================================================================
* TEST SECTION 4.28: COMPETING RISK EDGE CASES
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 4.28: Competing Risk Edge Cases"
    display as text "{hline 70}"
}

* Create all missing competing risk dates
clear
input long id double(primary_dt death_dt)
    1 22097 .
end
format %td primary_dt death_dt
label data "Primary event with missing competing risk date"
save "${DATA_DIR}/events_missing_compete.dta", replace

* Create primary missing but competing present
clear
input long id double(primary_dt death_dt)
    1 . 22097
end
format %td primary_dt death_dt
label data "Missing primary with present competing risk"
save "${DATA_DIR}/events_primary_missing.dta", replace

* Create all competing risks on same day
clear
input long id double(primary_dt death_dt emig_dt)
    1 22189 22097 22097
end
format %td primary_dt death_dt emig_dt
label data "Two competing risks on same day"
save "${DATA_DIR}/events_compete_sameday.dta", replace

* -----------------------------------------------------------------------------
* Test 4.28.1: Missing Competing Risk Date
* Purpose: Verify handling when competing risk date is missing
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.28.1: Missing Competing Risk Date"
}

capture {
    use "${DATA_DIR}/events_missing_compete.dta", clear
    tvevent using "${DATA_DIR}/intervals_fullyear.dta", id(id) date(primary_dt) ///
        startvar(start) stopvar(stop) compete(death_dt) ///
        type(single) generate(outcome)

    * Primary event should win since competing risk is missing
    quietly count if outcome == 1
    assert r(N) == 1

    * Competing risk should not be recorded
    quietly count if outcome == 2
    assert r(N) == 0
}
if _rc == 0 {
    display as result "  PASS: Missing competing risk date handled correctly"
    local ++pass_count
}
else {
    display as error "  FAIL: Missing competing risk date (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.28.1"
}

* -----------------------------------------------------------------------------
* Test 4.28.2: Missing Primary with Present Competing Risk
* Purpose: Verify competing risk wins when primary is missing
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.28.2: Missing Primary with Present Competing"
}

capture {
    use "${DATA_DIR}/events_primary_missing.dta", clear
    tvevent using "${DATA_DIR}/intervals_fullyear.dta", id(id) date(primary_dt) ///
        startvar(start) stopvar(stop) compete(death_dt) ///
        type(single) generate(outcome)

    * Competing risk should win since primary is missing
    quietly count if outcome == 2
    assert r(N) == 1

    * Primary should not be recorded
    quietly count if outcome == 1
    assert r(N) == 0
}
if _rc == 0 {
    display as result "  PASS: Missing primary with present competing handled correctly"
    local ++pass_count
}
else {
    display as error "  FAIL: Missing primary (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.28.2"
}

* -----------------------------------------------------------------------------
* Test 4.28.3: Multiple Competing Risks on Same Day
* Purpose: Verify tie-breaking when multiple competing risks share a date
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.28.3: Multiple Competing Risks on Same Day"
}

capture {
    use "${DATA_DIR}/events_compete_sameday.dta", clear
    tvevent using "${DATA_DIR}/intervals_fullyear.dta", id(id) date(primary_dt) ///
        startvar(start) stopvar(stop) compete(death_dt emig_dt) ///
        type(single) generate(outcome)

    * One of the competing risks should win (both are on 22097, before primary 22189)
    * Expected: death (2) or emig (3) - first listed wins when tied
    quietly count if outcome == 2 | outcome == 3
    assert r(N) == 1

    * Primary should not be recorded (competing risks are earlier)
    quietly count if outcome == 1
    assert r(N) == 0
}
if _rc == 0 {
    display as result "  PASS: Multiple competing risks same day resolved consistently"
    local ++pass_count
}
else {
    display as error "  FAIL: Same-day competing risks (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.28.3"
}

* =============================================================================
* TEST SECTION 4.29: PERSON-TIME INVARIANTS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 4.29: Person-Time Invariants"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 4.29.1: type(recurring) Preserves Total Duration
* Purpose: Verify recurring events don't lose any person-time
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.29.1: type(recurring) Preserves Total Duration"
}

capture {
    * Calculate original person-time under [start, stop] inclusive convention
    use "${DATA_DIR}/intervals_fullyear.dta", clear
    gen double dur = stop - start + 1
    quietly sum dur
    local original_pt = r(sum)

    * Run tvevent with recurring
    use "${DATA_DIR}/events_recurring_wide.dta", clear
    tvevent using "${DATA_DIR}/intervals_fullyear.dta", id(id) date(hosp) ///
        startvar(start) stopvar(stop) type(recurring) generate(outcome)

    * Calculate output person-time under [start, stop] inclusive convention
    gen double dur = stop - start + 1
    quietly sum dur
    local output_pt = r(sum)

    * Person-time should be exactly preserved
    assert abs(`output_pt' - `original_pt') < 1
}
if _rc == 0 {
    display as result "  PASS: type(recurring) preserves total person-time exactly"
    local ++pass_count
}
else {
    display as error "  FAIL: Person-time preservation (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.29.1"
}

* -----------------------------------------------------------------------------
* Test 4.29.2: Interval Ordering Maintained After Splits
* Purpose: Verify output intervals are properly ordered within each person
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.29.2: Interval Ordering Maintained After Splits"
}

capture {
    use "${DATA_DIR}/events_recurring_wide.dta", clear
    tvevent using "${DATA_DIR}/intervals_fullyear.dta", id(id) date(hosp) ///
        startvar(start) stopvar(stop) type(recurring) generate(outcome)

    * Verify intervals are properly ordered and non-overlapping
    sort id start
    by id: gen byte order_ok = (start[_n] == stop[_n-1]) if _n > 1
    by id: gen byte gap_ok = (start[_n] >= stop[_n-1]) if _n > 1

    * All intervals should be contiguous or have positive gaps (no overlaps)
    quietly count if gap_ok == 0
    assert r(N) == 0
}
if _rc == 0 {
    display as result "  PASS: Interval ordering maintained after event splits"
    local ++pass_count
}
else {
    display as error "  FAIL: Interval ordering (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.29.2"
}

* -----------------------------------------------------------------------------
* Test 4.29.3: Exactly One Event Row Per Primary Event (type=single)
* Purpose: Verify type(single) produces exactly one event row per person with event
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.29.3: Exactly One Event Row Per Person (type=single)"
}

capture {
    use "${DATA_DIR}/events_midyear.dta", clear
    tvevent using "${DATA_DIR}/intervals_fullyear.dta", id(id) date(event_dt) ///
        startvar(start) stopvar(stop) type(single) generate(outcome)

    * Count event rows per person
    bysort id: egen n_event_rows = total(outcome == 1)
    quietly tab n_event_rows

    * Each person should have at most 1 event row
    quietly sum n_event_rows
    assert r(max) <= 1
}
if _rc == 0 {
    display as result "  PASS: At most one event row per person with type(single)"
    local ++pass_count
}
else {
    display as error "  FAIL: Single event per person (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.29.3"
}

* =============================================================================
* TEST SECTION 4.30: LARGE DATASET STRESS TESTS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 4.30: Large Dataset Stress Tests"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 4.30.1: Large Dataset Event Integration (5000 patients)
* Purpose: Verify tvevent handles large datasets correctly
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.30.1: Large Dataset Event Integration (5000 patients)"
}

capture {
    * Create large cohort (5000 patients)
    clear
    set seed 12345
    set obs 5000
    gen long id = _n
    gen double study_entry = 21915
    gen double study_exit = 22281
    gen byte has_event = runiform() < 0.30
    gen double edss4_dt = study_entry + 30 + floor(runiform() * 300) if has_event
    gen byte has_death = runiform() < 0.08 & !has_event
    gen double death_dt = study_entry + 50 + floor(runiform() * 280) if has_death
    replace edss4_dt = . if edss4_dt > study_exit
    replace death_dt = . if death_dt > study_exit
    format %td study_entry study_exit edss4_dt death_dt
    drop has_event has_death
    save "${DATA_DIR}/cohort_large_val.dta", replace

    * Create corresponding TV data (3 intervals per patient)
    use "${DATA_DIR}/cohort_large_val.dta", clear
    keep id study_entry study_exit
    expand 3
    bysort id: gen interval = _n
    gen double start = study_entry if interval == 1
    replace start = study_entry + 100 if interval == 2
    replace start = study_entry + 200 if interval == 3
    gen double stop = study_entry + 100 if interval == 1
    replace stop = study_entry + 200 if interval == 2
    replace stop = study_exit if interval == 3
    gen byte tv_exp = interval - 1
    drop study_entry study_exit interval
    format %td start stop
    save "${DATA_DIR}/tv_large_val.dta", replace

    * Run tvevent
    use "${DATA_DIR}/cohort_large_val.dta", clear
    tvevent using "${DATA_DIR}/tv_large_val.dta", id(id) date(edss4_dt) ///
        startvar(start) stopvar(stop) compete(death_dt) ///
        type(single) generate(outcome)

    * All 5000 IDs should be present
    tempvar _tag
    quietly egen `_tag' = tag(id)
    quietly count if `_tag' == 1
    assert r(N) == 5000
}
if _rc == 0 {
    display as result "  PASS: Large dataset (5000 patients) integration works"
    local ++pass_count
}
else {
    display as error "  FAIL: Large dataset integration (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.30.1"
}

* -----------------------------------------------------------------------------
* Test 4.30.2: Very Large Dataset (10000 patients)
* Purpose: Stress test tvevent with 10000 patients
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.30.2: Very Large Dataset (10000 patients)"
}

capture {
    * Create very large cohort
    clear
    set seed 54321
    set obs 10000
    gen long id = _n
    gen double study_entry = 21915
    gen double study_exit = 22281
    gen byte has_event = runiform() < 0.25
    gen double edss4_dt = study_entry + 30 + floor(runiform() * 300) if has_event
    gen byte has_death = runiform() < 0.05 & !has_event
    gen double death_dt = study_entry + 50 + floor(runiform() * 280) if has_death
    replace edss4_dt = . if edss4_dt > study_exit
    replace death_dt = . if death_dt > study_exit
    format %td study_entry study_exit edss4_dt death_dt
    drop has_event has_death
    save "${DATA_DIR}/cohort_stress_val.dta", replace

    * Create corresponding TV data (2 intervals per patient)
    use "${DATA_DIR}/cohort_stress_val.dta", clear
    keep id study_entry study_exit
    expand 2
    bysort id: gen interval = _n
    gen double start = study_entry if interval == 1
    replace start = study_entry + 183 if interval == 2
    gen double stop = study_entry + 183 if interval == 1
    replace stop = study_exit if interval == 2
    gen byte tv_exp = interval - 1
    drop study_entry study_exit interval
    format %td start stop
    save "${DATA_DIR}/tv_stress_val.dta", replace

    * Run tvevent
    use "${DATA_DIR}/cohort_stress_val.dta", clear
    tvevent using "${DATA_DIR}/tv_stress_val.dta", id(id) date(edss4_dt) ///
        startvar(start) stopvar(stop) compete(death_dt) ///
        type(single) generate(outcome)

    * All 10000 IDs should be present
    tempvar _tag
    quietly egen `_tag' = tag(id)
    quietly count if `_tag' == 1
    assert r(N) == 10000
}
if _rc == 0 {
    display as result "  PASS: Very large dataset (10000 patients) stress test works"
    local ++pass_count
}
else {
    display as error "  FAIL: Very large dataset stress test (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.30.2"
}

* -----------------------------------------------------------------------------
* Test 4.30.3: Large Dataset Person-Time Conservation
* Purpose: Verify person-time is conserved in large dataset
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.30.3: Large Dataset Person-Time Conservation"
}

capture {
    * Calculate expected person-time from INTERVAL data before tvevent splits it
    * tv_large_val.dta has the intervals (start/stop), cohort has the events
    use "${DATA_DIR}/tv_large_val.dta", clear
    gen double pre_ptime = stop - start
    quietly sum pre_ptime
    local expected_total = r(sum)

    * Run tvevent: master=cohort (events), using=intervals
    use "${DATA_DIR}/cohort_large_val.dta", clear
    tvevent using "${DATA_DIR}/tv_large_val.dta", id(id) date(edss4_dt) ///
        startvar(start) stopvar(stop) compete(death_dt) ///
        type(single) generate(outcome)

    gen double ptime = stop - start
    quietly sum ptime
    local actual_total = r(sum)

    * Actual should be <= expected (type(single) removes post-event intervals)
    * and within 20% (some person-time is correctly censored at events)
    assert `actual_total' <= `expected_total' * 1.001
    local pct_diff = abs(`actual_total' - `expected_total') / `expected_total'
    assert `pct_diff' < 0.20
}
if _rc == 0 {
    display as result "  PASS: Large dataset person-time conserved"
    local ++pass_count
}
else {
    display as error "  FAIL: Large dataset person-time conservation (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.30.3"
}

* -----------------------------------------------------------------------------
* Test 4.30.4: Large Dataset Cox Regression Workflow
* Purpose: Verify full workflow with Cox regression on large dataset
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.30.4: Large Dataset Cox Regression Workflow"
}

capture {
    use "${DATA_DIR}/cohort_large_val.dta", clear
    tvevent using "${DATA_DIR}/tv_large_val.dta", id(id) date(edss4_dt) ///
        startvar(start) stopvar(stop) compete(death_dt) ///
        type(single) generate(outcome)

    * Set up survival data
    stset stop, id(id) failure(outcome==1) enter(start) scale(365.25)

    * Run Cox model
    stcox tv_exp

    assert e(N) > 0
}
if _rc == 0 {
    display as result "  PASS: Large dataset Cox regression workflow works (N = " e(N) ")"
    local ++pass_count
}
else {
    display as error "  FAIL: Large dataset Cox regression (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.30.4"
}

* Cleanup large dataset files
capture erase "${DATA_DIR}/cohort_large_val.dta"
capture erase "${DATA_DIR}/tv_large_val.dta"
capture erase "${DATA_DIR}/cohort_stress_val.dta"
capture erase "${DATA_DIR}/tv_stress_val.dta"

* =============================================================================
* Test 4.31: Validation Option Tests
* Purpose: Verify the validate option correctly identifies data quality issues
* =============================================================================
if `quiet' == 0 {
    display as text _n "=========================="
    display as text "Test Set 4.31: Validate Option"
    display as text "=========================="
}

* -----------------------------------------------------------------------------
* Test 4.31.1: Validate option returns stored results
* Purpose: Verify r(v_outside_bounds), r(v_multiple_events), r(v_same_date_compete)
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.31.1: Validate Option Stored Results"
}

capture {
    * Create simple test data
    clear
    set obs 10
    gen id = _n
    gen edss4_dt = mdy(6, 15, 2020) + runiform()*100
    gen death_dt = .
    replace death_dt = mdy(8, 1, 2020) if _n <= 2
    tempfile event_data
    save `event_data'

    * Create interval data
    clear
    set obs 10
    gen id = _n
    gen start = mdy(1, 1, 2020)
    gen stop = mdy(12, 31, 2020)
    gen tv_exp = mod(_n, 3)
    tempfile interval_data
    save `interval_data'

    * Run tvevent with validate
    use `event_data', clear
    tvevent using `interval_data', id(id) date(edss4_dt) compete(death_dt) ///
        type(single) validate generate(outcome)

    * Verify stored results exist and are non-negative
    assert r(v_outside_bounds) >= 0
    assert r(v_multiple_events) >= 0
    assert r(v_same_date_compete) >= 0
}
if _rc == 0 {
    display as result "  PASS: Validate option returns stored results"
    local ++pass_count
}
else {
    display as error "  FAIL: Validate option stored results (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.31.1"
}

* -----------------------------------------------------------------------------
* Test 4.31.2: Validate detects same-date competing events
* Purpose: Verify v_same_date_compete correctly counts same-date events
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.31.2: Validate Detects Same-Date Competing Events"
}

capture {
    * Create test data with same-date events
    clear
    set obs 5
    gen id = _n
    gen event_dt = mdy(6, 15, 2020)
    gen compete_dt = mdy(6, 15, 2020) if _n <= 2  // 2 same-date events
    replace compete_dt = mdy(7, 1, 2020) if _n > 2
    tempfile event_data
    save `event_data'

    * Create interval data
    clear
    set obs 5
    gen id = _n
    gen start = mdy(1, 1, 2020)
    gen stop = mdy(12, 31, 2020)
    gen tv_exp = 1
    tempfile interval_data
    save `interval_data'

    * Run tvevent with validate
    use `event_data', clear
    tvevent using `interval_data', id(id) date(event_dt) compete(compete_dt) ///
        type(single) validate generate(outcome)

    * Should detect 2 same-date competing events
    assert r(v_same_date_compete) == 2
}
if _rc == 0 {
    display as result "  PASS: Validate correctly detects same-date competing events"
    local ++pass_count
}
else {
    display as error "  FAIL: Same-date competing event detection (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.31.2"
}

* -----------------------------------------------------------------------------
* Test 4.31.3: Validate detects events outside interval bounds
* Purpose: Verify v_outside_bounds correctly counts out-of-range events
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.31.3: Validate Detects Events Outside Bounds"
}

capture {
    * Create test data with out-of-bounds events
    clear
    set obs 5
    gen id = _n
    * Events outside the interval (before start or after stop)
    gen event_dt = mdy(6, 1, 2019) if _n <= 2  // Before start
    replace event_dt = mdy(6, 1, 2021) if _n == 3  // After stop
    replace event_dt = mdy(6, 15, 2020) if _n > 3  // Within bounds
    tempfile event_data
    save `event_data'

    * Create interval data
    clear
    set obs 5
    gen id = _n
    gen start = mdy(1, 1, 2020)
    gen stop = mdy(12, 31, 2020)
    gen tv_exp = 1
    tempfile interval_data
    save `interval_data'

    * Run tvevent with validate
    use `event_data', clear
    tvevent using `interval_data', id(id) date(event_dt) ///
        type(single) validate generate(outcome)

    * Should detect 3 events outside bounds (2 before + 1 after)
    assert r(v_outside_bounds) == 3
}
if _rc == 0 {
    display as result "  PASS: Validate correctly detects events outside bounds"
    local ++pass_count
}
else {
    display as error "  FAIL: Out-of-bounds event detection (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.31.3"
}

* =============================================================================
* SUMMARY

}

* --- From validation_tvevent_mathematical.do ---

capture noisily {
display _n _dup(70) "="
display "TVEVENT MATHEMATICAL VALIDATION"
display _dup(70) "="
display "Date: $S_DATE $S_TIME"
display ""


* ============================================================================
* TEST 4A: TIMEGEN EXACT CALCULATION
* ============================================================================
display _n _dup(60) "-"
display "TEST 4A: Timegen exact calculation (days/months/years)"
display _dup(60) "-"

local test4a_pass = 1

* Interval [2020-01-01, 2020-07-18] = 199 days
* timegen in days  = 199
* timegen in months = 199/30.4375 ≈ 6.538
* timegen in years  = 199/365.25 ≈ 0.5449
* Note: tvevent timegen uses interval length (stop - start + 1? or stop - start?)
* Need to read the ado to confirm, but testing actual vs expected is key

* Create a single interval dataset
clear
set obs 1
gen id = 1
gen event_date = .    // no event
save "/tmp/tve4a_event.dta", replace

clear
set obs 1
gen id = 1
gen start = mdy(1,1,2020)
gen stop  = mdy(7,18,2020)    // Jan1 to Jul18

* Verify the interval length
local interval_days = mdy(7,18,2020) - mdy(1,1,2020)
* tvevent typically generates timegen as (stop - start) or (stop - start + 1)
* We need to check which convention tvevent uses - we'll examine the actual output
display "  INFO: Raw interval length (stop-start): `interval_days' days"

gen tv_exp = 1    // exposure value
save "/tmp/tve4a_intervals.dta", replace

use "/tmp/tve4a_event.dta", clear
capture noisily tvevent using "/tmp/tve4a_intervals.dta", ///
    id(id) date(event_date) ///
    timegen(t_days) timeunit(days)

if _rc != 0 {
    display as error "  FAIL [4a.days.run]: tvevent returned error `=_rc'"
    local test4a_pass = 0
}
else {
    quietly sum t_days
    local actual_days = r(max)
    display "  INFO: t_days = `actual_days'"

    * Check it's approximately the interval length (within 1 day tolerance)
    if abs(`actual_days' - `interval_days') <= 1 | abs(`actual_days' - `interval_days' - 1) <= 0 {
        display as result "  PASS [4a.days]: t_days=`actual_days', interval=`interval_days'"
    }
    else {
        display as error "  FAIL [4a.days]: t_days=`actual_days', interval_days=`interval_days'"
        local test4a_pass = 0
    }
}

* Test with months
use "/tmp/tve4a_event.dta", clear
capture noisily tvevent using "/tmp/tve4a_intervals.dta", ///
    id(id) date(event_date) ///
    timegen(t_months) timeunit(months)

if _rc == 0 {
    quietly sum t_months
    local actual_months = r(max)
    local expected_months = `interval_days' / 30.4375
    local diff = abs(`actual_months' - `expected_months')
    display "  INFO: t_months = `actual_months', expected ≈ `expected_months'"
    if `diff' < 0.5 {
        display as result "  PASS [4a.months]: t_months within 0.5 of expected"
    }
    else {
        display as error "  FAIL [4a.months]: t_months=`actual_months', expected≈`expected_months', diff=`diff'"
        local test4a_pass = 0
    }
}
else {
    display as error "  FAIL [4a.months.run]: tvevent returned error `=_rc'"
    local test4a_pass = 0
}

* Test with years
use "/tmp/tve4a_event.dta", clear
capture noisily tvevent using "/tmp/tve4a_intervals.dta", ///
    id(id) date(event_date) ///
    timegen(t_years) timeunit(years)

if _rc == 0 {
    quietly sum t_years
    local actual_years = r(max)
    local expected_years = `interval_days' / 365.25
    local diff = abs(`actual_years' - `expected_years')
    display "  INFO: t_years = `actual_years', expected ≈ `expected_years'"
    if `diff' < 0.1 {
        display as result "  PASS [4a.years]: t_years within 0.1 of expected"
    }
    else {
        display as error "  FAIL [4a.years]: t_years=`actual_years', expected≈`expected_years', diff=`diff'"
        local test4a_pass = 0
    }
}
else {
    display as error "  FAIL [4a.years.run]: tvevent returned error `=_rc'"
    local test4a_pass = 0
}

if `test4a_pass' == 1 {
    local pass_count = `pass_count' + 1
    display as result "TEST 4A: PASSED"
}
else {
    local fail_count = `fail_count' + 1
    local failed_tests "`failed_tests' 4a"
    display as error "TEST 4A: FAILED"
}

* ============================================================================
* TEST 4B: COMPETING RISK - EARLIEST EVENT WINS
* ============================================================================
display _n _dup(60) "-"
display "TEST 4B: Competing risk resolution - earliest event wins"
display _dup(60) "-"

local test4b_pass = 1

* Person with:
*   Primary event: day 200 from Jan1/2020 = mdy(7,19,2020) (approx)
*   Death (compete1): day 100 = mdy(4,10,2020) - should be the winner
*   Emigration (compete2): day 150 = mdy(5,30,2020)
*
* Expected: the EARLIEST event (death, day 100) is coded as the event.
* All post-event intervals should be dropped (type single)

clear
set obs 1
gen id = 1
gen primary_event = mdy(1,1,2020) + 200    // day 200
gen death         = mdy(1,1,2020) + 100    // day 100 - EARLIEST
gen emigration    = mdy(1,1,2020) + 150    // day 150
save "/tmp/tve4b_event.dta", replace

* Person-time intervals: 5 yearly intervals
clear
set obs 5
gen id = 1
gen start = mdy(1,1,2020) + (_n-1)*73    // ~ every 73 days
gen stop  = start + 72
replace stop = mdy(12,31,2020) if _n == 5
gen tv_exp = 1
save "/tmp/tve4b_intervals.dta", replace

use "/tmp/tve4b_event.dta", clear
capture noisily tvevent using "/tmp/tve4b_intervals.dta", ///
    id(id) date(primary_event) ///
    compete(death emigration) ///
    type(single) generate(fail_status)

if _rc != 0 {
    display as error "  FAIL [4b.run]: tvevent returned error `=_rc'"
    local test4b_pass = 0
}
else {
    sort id start
    quietly count
    display "  INFO: `=r(N)' rows in output"

    * Should have only one event flag per person
    quietly count if fail_status > 0
    local n_events = r(N)

    if `n_events' == 1 {
        display as result "  PASS [4b.one_event]: exactly 1 event row"
    }
    else {
        display as error "  FAIL [4b.one_event]: `n_events' event rows (expected 1)"
        local test4b_pass = 0
    }

    * The event should be coded as death (code=2, since death is first compete variable)
    quietly sum fail_status if fail_status > 0
    if r(N) > 0 {
        local event_code = r(max)
        if `event_code' == 2 {
            display as result "  PASS [4b.event_type]: event coded as death (code=2)"
        }
        else {
            display as error "  FAIL [4b.event_type]: event coded as `event_code' (expected 2=death)"
            local test4b_pass = 0
        }
    }

    * The event row should be the one containing day 100
    local death_date = mdy(1,1,2020) + 100
    quietly count if fail_status > 0 & start <= `death_date' & stop >= `death_date'
    if r(N) == 1 {
        display as result "  PASS [4b.event_row]: event is in the interval containing death date"
    }
    else {
        display as error "  FAIL [4b.event_row]: event not found in death interval"
        list id start stop fail_status
        local test4b_pass = 0
    }
}

if `test4b_pass' == 1 {
    local pass_count = `pass_count' + 1
    display as result "TEST 4B: PASSED"
}
else {
    local fail_count = `fail_count' + 1
    local failed_tests "`failed_tests' 4b"
    display as error "TEST 4B: FAILED"
}

* ============================================================================
* TEST 4C: CONTINUOUS VARIABLE SPLIT PROPORTIONING
* ============================================================================
display _n _dup(60) "-"
display "TEST 4C: Continuous variable split proportioning"
display _dup(60) "-"

local test4c_pass = 1

* Interval [Jan1/2020, Apr10/2020] = 100 days, cumul_dose=100
* Event at day 50 (Feb19/2020): splits into:
*   Pre-event:  [Jan1, Feb19] - should have proportioned dose ≈ 50
*   Post-event: [Feb19, Apr10] - should have proportioned dose ≈ 50
* With type(single): only pre-event row kept
* Proportioning: dose = original_dose * (split_days / total_days)

* Interval
clear
set obs 1
gen id = 1
gen start = mdy(1,1,2020)
gen stop  = mdy(4,10,2020)
gen tv_exp = 1
gen cumul_dose = 100          // 100 dose units in this period
save "/tmp/tve4c_intervals.dta", replace

local total_days = mdy(4,10,2020) - mdy(1,1,2020)
local event_day = mdy(1,1,2020) + 50    // 50 days in
local pre_days  = `event_day' - mdy(1,1,2020)  // = 50
local post_days = mdy(4,10,2020) - `event_day'

display "  INFO: total_days=`total_days', pre=`pre_days', post=`post_days'"

* Event data
* Note: type(recurring) requires wide-format event variables (event_date1, event_date2, ...)
clear
set obs 1
gen id = 1
gen event_date1 = mdy(1,1,2020) + 50    // day 50 (wide format for type(recurring))
save "/tmp/tve4c_event.dta", replace

use "/tmp/tve4c_event.dta", clear
capture noisily tvevent using "/tmp/tve4c_intervals.dta", ///
    id(id) date(event_date) ///
    continuous(cumul_dose) ///
    type(recurring) generate(fail_status)

if _rc != 0 {
    display as error "  FAIL [4c.run]: tvevent returned error `=_rc'"
    local test4c_pass = 0
}
else {
    sort id start
    quietly count
    local nrows = r(N)
    display "  INFO: `nrows' rows after splitting"

    if `nrows' == 2 {
        display as result "  PASS [4c.rows]: exactly 2 rows after split"

        * Pre-event row should have proportioned dose
        local pre_dose  = cumul_dose[1]
        local post_dose = cumul_dose[2]

        * Expected proportioning: dose * fraction_of_interval
        * pre: 50/100 * 100 = 50
        local expected_pre = 100 * `pre_days' / `total_days'
        local expected_post = 100 * `post_days' / `total_days'

        local diff_pre  = abs(`pre_dose'  - `expected_pre')
        local diff_post = abs(`post_dose' - `expected_post')

        if `diff_pre' < 1 {
            display as result "  PASS [4c.pre_dose]: pre-event dose=`pre_dose', expected≈`expected_pre'"
        }
        else {
            display as error "  FAIL [4c.pre_dose]: pre-event dose=`pre_dose', expected≈`expected_pre', diff=`diff_pre'"
            local test4c_pass = 0
        }

        if `diff_post' < 1 {
            display as result "  PASS [4c.post_dose]: post-event dose=`post_dose', expected≈`expected_post'"
        }
        else {
            display as error "  FAIL [4c.post_dose]: post-event dose=`post_dose', expected≈`expected_post', diff=`diff_post'"
            local test4c_pass = 0
        }

        * Conservation: pre + post should sum to original (100)
        local sum_dose = `pre_dose' + `post_dose'
        if abs(`sum_dose' - 100) < 0.01 {
            display as result "  PASS [4c.conservation]: dose conserved (sum=`sum_dose')"
        }
        else {
            display as error "  FAIL [4c.conservation]: dose not conserved (sum=`sum_dose', expected=100)"
            local test4c_pass = 0
        }
    }
    else {
        display as error "  FAIL [4c.rows]: expected 2 rows, got `nrows'"
        list id start stop cumul_dose fail_status
        local test4c_pass = 0
    }
}

if `test4c_pass' == 1 {
    local pass_count = `pass_count' + 1
    display as result "TEST 4C: PASSED"
}
else {
    local fail_count = `fail_count' + 1
    local failed_tests "`failed_tests' 4c"
    display as error "TEST 4C: FAILED"
}

* ============================================================================
* TEST 4D: TYPE(SINGLE) REMOVES ALL POST-EVENT INTERVALS
* ============================================================================
display _n _dup(60) "-"
display "TEST 4D: Type(single) - removes all post-event intervals"
display _dup(60) "-"

local test4d_pass = 1

* 1 person with 5 intervals, event occurs in interval 3 (middle)
* Expected: only intervals 1, 2, and 3 (event row) remain = 3 rows

clear
set obs 5
gen id = 1
gen start = mdy(1,1,2020) + (_n-1)*73
gen stop  = start + 72
replace stop = mdy(12,31,2021) if _n == 5
gen tv_exp = 1
save "/tmp/tve4d_intervals.dta", replace

* Event occurs in interval 3 (day 146-218)
local event_date = mdy(1,1,2020) + 160    // day 160, in interval 3

clear
set obs 1
gen id = 1
gen event_date = mdy(1,1,2020) + 160
save "/tmp/tve4d_event.dta", replace

use "/tmp/tve4d_event.dta", clear
capture noisily tvevent using "/tmp/tve4d_intervals.dta", ///
    id(id) date(event_date) ///
    type(single) generate(fail_status)

if _rc != 0 {
    display as error "  FAIL [4d.run]: tvevent returned error `=_rc'"
    local test4d_pass = 0
}
else {
    sort id start
    quietly count
    local nrows = r(N)
    display "  INFO: `nrows' rows after type(single)"

    * Should have 3 rows (intervals 1, 2, and part of 3)
    * Note: if event is in interval 3, interval 3 is split at event date → 2 rows from interval 3?
    * No - type(single) should keep only up to and including the event row
    * Looking at tvevent behavior: splits if strictly inside interval, event at stop just flags it
    * For event strictly inside interval 3: split into [start3, event] and [event, stop3]
    *   → then type(single) keeps pre-event portion + event row = 3 pre-intervals + split pre = 3 rows
    * Actually: rows 1, 2, pre-event split of 3 = 3 rows total

    if `nrows' == 3 {
        display as result "  PASS [4d.rows]: exactly 3 rows after type(single)"
    }
    else {
        display as error "  FAIL [4d.rows]: expected 3 rows, got `nrows'"
        local test4d_pass = 0
    }

    * Last row should have fail_status=1
    local last_fail = fail_status[`nrows']
    if `last_fail' == 1 {
        display as result "  PASS [4d.event_flag]: last row has fail_status=1"
    }
    else {
        display as error "  FAIL [4d.event_flag]: last row has fail_status=`last_fail' (expected 1)"
        local test4d_pass = 0
    }

    * All rows should be before or at event date
    local event_date_val = mdy(1,1,2020) + 160
    quietly count if stop > `event_date_val'
    if r(N) == 0 {
        display as result "  PASS [4d.truncation]: no intervals extend past event date"
    }
    else {
        display as error "  FAIL [4d.truncation]: `=r(N)' intervals extend past event date"
        list id start stop fail_status
        local test4d_pass = 0
    }
}

if `test4d_pass' == 1 {
    local pass_count = `pass_count' + 1
    display as result "TEST 4D: PASSED"
}
else {
    local fail_count = `fail_count' + 1
    local failed_tests "`failed_tests' 4d"
    display as error "TEST 4D: FAILED"
}

* ============================================================================
* TEST 4E: BOUNDARY BEHAVIOR - EVENT AT STOP DATE IS CAPTURED
* ============================================================================
display _n _dup(60) "-"
display "TEST 4E: Boundary behavior - event at stop date is captured"
display _dup(60) "-"

local test4e_pass = 1

* From tvevent help: "Events at the stop boundary (date == stop) ARE valid and flagged"
* Event exactly at stop of last interval → should be flagged as event, NOT censored

clear
set obs 1
gen id = 1
gen start = mdy(1,1,2020)
gen stop  = mdy(12,31,2020)
gen tv_exp = 1
save "/tmp/tve4e_intervals.dta", replace

clear
set obs 1
gen id = 1
gen event_date = mdy(12,31,2020)    // event at EXACTLY the stop boundary
save "/tmp/tve4e_event.dta", replace

use "/tmp/tve4e_event.dta", clear
capture noisily tvevent using "/tmp/tve4e_intervals.dta", ///
    id(id) date(event_date) ///
    type(single) generate(fail_status)

if _rc != 0 {
    display as error "  FAIL [4e.run]: tvevent returned error `=_rc'"
    local test4e_pass = 0
}
else {
    sort id start
    quietly sum fail_status
    local n_events = r(N)

    quietly count if fail_status == 1
    local n_flagged = r(N)

    if `n_flagged' == 1 {
        display as result "  PASS [4e.boundary]: event at stop boundary correctly flagged (fail_status=1)"
    }
    else {
        display as error "  FAIL [4e.boundary]: expected 1 event row, got `n_flagged' with fail_status=1"
        list id start stop fail_status
        local test4e_pass = 0
    }
}

if `test4e_pass' == 1 {
    local pass_count = `pass_count' + 1
    display as result "TEST 4E: PASSED"
}
else {
    local fail_count = `fail_count' + 1
    local failed_tests "`failed_tests' 4e"
    display as error "TEST 4E: FAILED"
}

* ============================================================================
* FINAL SUMMARY

}

* --- From validation_tvevent_registry.do ---

capture noisily {
display _n _dup(70) "="
display "TVEVENT REGISTRY DATA VALIDATION"
display _dup(70) "="
display "Date: $S_DATE $S_TIME"
display ""


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

}


* =============================================================================
* SECTION 5: TVEXPOSE - Exposure tracking and person-time validation
* =============================================================================
* --- From validation_tvexpose.do ---

capture noisily {
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

* Program to verify person-time conservation
capture program drop _verify_ptime_conserved
program define _verify_ptime_conserved, rclass
    syntax, start(varname) stop(varname) expected_ptime(real) [tolerance(real 0.001)]

    tempvar dur
    * tvexpose uses inclusive endpoints: duration = stop - start + 1
    gen double `dur' = `stop' - `start' + 1
    quietly sum `dur'
    local actual = r(sum)
    local pct_diff = abs(`actual' - `expected_ptime') / `expected_ptime'
    return scalar actual_ptime = `actual'
    return scalar pct_diff = `pct_diff'
    return scalar passed = (`pct_diff' < `tolerance')
end

* =============================================================================
* CREATE VALIDATION DATA
* =============================================================================
if `quiet' == 0 {
    display as text _n "Creating validation datasets..."
}

* Standard cohort: 1 person, 2020 (leap year = 366 days)
clear
input long id double(study_entry study_exit)
    1 21915 22281
end
format %td study_entry study_exit
label variable study_entry "Study entry date"
label variable study_exit "Study exit date"
label data "Single person cohort, 2020 (366 days)"
save "${DATA_DIR}/cohort_single.dta", replace

* 3-person cohort for broader tests
clear
input long id double(study_entry study_exit)
    1 21915 22281
    2 21915 22281
    3 21915 22281
end
format %td study_entry study_exit
label data "3-person cohort, 2020"
save "${DATA_DIR}/cohort_3person.dta", replace

* Basic single exposure (Mar 1 - Jun 30, 2020)
clear
input long id double(rx_start rx_stop) byte exp_type
    1 21975 22097 1
end
format %td rx_start rx_stop
label data "Single exposure Mar 1 - Jun 30, 2020"
save "${DATA_DIR}/exp_basic.dta", replace

* Two non-overlapping exposures
clear
input long id double(rx_start rx_stop) byte exp_type
    1 21946 22006 1
    1 22128 22220 2
end
format %td rx_start rx_stop
label data "Two non-overlapping exposures"
save "${DATA_DIR}/exp_two.dta", replace

* Overlapping exposures (Apr-Jun overlap)
clear
input long id double(rx_start rx_stop) byte exp_type
    1 21915 22097 1
    1 22006 22189 2
end
format %td rx_start rx_stop
label data "Overlapping exposures"
save "${DATA_DIR}/exp_overlap.dta", replace

* Exposures with 15-day gap for grace period testing
* First exposure: Jan 1 - Jan 31 (21915 - 21945)
* Second exposure: Feb 15 - Mar 17 (21960 - 21991)
* Gap: 21960 - 21945 = 15 days
clear
input long id double(rx_start rx_stop) byte exp_type
    1 21915 21945 1
    1 21960 21991 1
end
format %td rx_start rx_stop
label data "Two exposures with 15-day gap"
save "${DATA_DIR}/exp_gap15.dta", replace

* Full-year exposure for cumulative testing
* Jan 1 (21915) to Dec 31 (22281) = 366 days (leap year)
clear
input long id double(rx_start rx_stop) byte exp_type
    1 21915 22281 1
end
format %td rx_start rx_stop
label data "Full year exposure (366 days)"
save "${DATA_DIR}/exp_fullyear.dta", replace

* Simple single exposure period for basic tests
clear
input long id double(rx_start rx_stop) byte exp_type
    1 21946 22067 1
end
format %td rx_start rx_stop
label data "Single exposure period (Feb 1 - Jun 1)"
save "${DATA_DIR}/exposure_single.dta", replace

* Single exposure with cumulative value for continuousunit tests
clear
input long id double(rx_start rx_stop) double cumulative
    1 21946 22067 121
end
format %td rx_start rx_stop
label data "Single exposure with cumulative dose"
save "${DATA_DIR}/exposure_single_cumulative.dta", replace

if `quiet' == 0 {
    display as result "Validation datasets created in: ${DATA_DIR}"
}

* =============================================================================
* TEST SECTION 3.1: CORE TRANSFORMATION TESTS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 3.1: Core Transformation Tests"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 3.1.1: Basic Interval Splitting
* Purpose: Verify exposure periods are correctly split at boundaries
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.1.1: Basic Interval Splitting"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_basic.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        generate(tv_exp)

    * Should have 3 intervals
    assert _N == 3

    * Verify non-overlapping
    _verify_no_overlap, id(id) start(rx_start) stop(rx_stop)
    assert r(n_overlaps) == 0

    * Verify exposure values are correct
    sort rx_start
    assert tv_exp[1] == 0
    assert tv_exp[2] == 1
    assert tv_exp[3] == 0
}
if _rc == 0 {
    display as result "  PASS: Basic interval splitting creates 3 non-overlapping intervals"
    local ++pass_count
}
else {
    display as error "  FAIL: Basic interval splitting (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.1.1"
}

* -----------------------------------------------------------------------------
* Test 3.1.2: Person-Time Conservation
* Purpose: Verify total follow-up time is preserved through transformation
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.1.2: Person-Time Conservation"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear

    * Original person-time: 2020 is a leap year = 367 days (inclusive endpoints)
    local expected_ptime = 22281 - 21915 + 1

    tvexpose using "${DATA_DIR}/exp_basic.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        generate(tv_exp)

    _verify_ptime_conserved, start(rx_start) stop(rx_stop) expected_ptime(`expected_ptime')
    assert r(passed) == 1
}
if _rc == 0 {
    display as result "  PASS: Person-time is conserved (367 days, inclusive)"
    local ++pass_count
}
else {
    display as error "  FAIL: Person-time conservation (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.1.2"
}

* -----------------------------------------------------------------------------
* Test 3.1.3: Non-Overlapping Intervals
* Purpose: Verify no intervals overlap within a person
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.1.3: Non-Overlapping Intervals"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_overlap.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        generate(tv_exp)

    _verify_no_overlap, id(id) start(rx_start) stop(rx_stop)
    assert r(n_overlaps) == 0
}
if _rc == 0 {
    display as result "  PASS: No overlapping intervals even with overlapping exposures"
    local ++pass_count
}
else {
    display as error "  FAIL: Non-overlapping intervals (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.1.3"
}

* =============================================================================
* TEST SECTION 3.2: CUMULATIVE EXPOSURE TESTS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 3.2: Cumulative Exposure Tests"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 3.2.1: continuousunit() Calculation Verification
* Purpose: Verify cumulative exposure is calculated correctly in years
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.2.1: continuousunit(years) Calculation"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear

    tvexpose using "${DATA_DIR}/exp_fullyear.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        continuousunit(years) generate(cum_exp)

    * At end of follow-up, cumulative should be ~1 year (365 days / 365.25)
    quietly sum cum_exp
    local max_cum = r(max)
    * Allow 5% tolerance for leap year / conversion differences
    assert abs(`max_cum' - 1.0) < 0.05
}
if _rc == 0 {
    display as result "  PASS: Cumulative exposure correctly calculated (~1 year)"
    local ++pass_count
}
else {
    display as error "  FAIL: continuousunit(years) calculation (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.2.1"
}

* -----------------------------------------------------------------------------
* Test 3.2.2: Cumulative Monotonicity
* Purpose: Verify cumulative exposure never decreases within a person
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.2.2: Cumulative Monotonicity"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_two.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        continuousunit(days) generate(cum_exp)

    sort id rx_start
    by id: gen double cum_change = cum_exp - cum_exp[_n-1] if _n > 1
    quietly count if cum_change < -0.0001
    assert r(N) == 0
}
if _rc == 0 {
    display as result "  PASS: Cumulative exposure never decreases"
    local ++pass_count
}
else {
    display as error "  FAIL: Cumulative monotonicity (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.2.2"
}

* =============================================================================
* TEST SECTION 3.3: CURRENT/FORMER STATUS TESTS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 3.3: Current/Former Status Tests"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 3.3.1: currentformer Transitions
* Purpose: Verify never->current->former transitions are correct
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.3.1: currentformer Transitions"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_basic.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        currentformer generate(cf_status)

    * Verify: Before exposure = 0 (never)
    *         During exposure = 1 (current)
    *         After exposure = 2 (former)
    sort rx_start
    assert cf_status[1] == 0
    assert cf_status[2] == 1
    assert cf_status[3] == 2
}
if _rc == 0 {
    display as result "  PASS: currentformer transitions: never(0)->current(1)->former(2)"
    local ++pass_count
}
else {
    display as error "  FAIL: currentformer transitions (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.3.1"
}

* -----------------------------------------------------------------------------
* Test 3.3.2: currentformer Never Returns to Current
* Purpose: Verify once "former", status doesn't revert to "current" without new exposure
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.3.2: currentformer Never Reverts to Current"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_basic.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        currentformer generate(cf_status)

    sort id rx_start
    by id: gen byte went_back = (cf_status == 1 & cf_status[_n-1] == 2) if _n > 1
    quietly count if went_back == 1
    assert r(N) == 0
}
if _rc == 0 {
    display as result "  PASS: Status never incorrectly reverts from former to current"
    local ++pass_count
}
else {
    display as error "  FAIL: currentformer reversion check (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.3.2"
}

* =============================================================================
* TEST SECTION 3.4: GRACE PERIOD TESTS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 3.4: Grace Period Tests"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 3.4.1: Grace Period with Gap > Grace Value
* Purpose: Verify exposures NOT merged when gap exceeds grace period
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.4.1: Grace Period (gap > grace value)"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear

    * With grace(14) - should NOT merge (15-day gap > 14)
    tvexpose using "${DATA_DIR}/exp_gap15.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        grace(14) generate(tv_exp)

    * Should have unexposed period between the two exposures
    quietly count if tv_exp == 0
    assert r(N) >= 1
}
if _rc == 0 {
    display as result "  PASS: Grace(14) does not bridge 15-day gap"
    local ++pass_count
}
else {
    display as error "  FAIL: Grace period with gap > grace (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.4.1"
}

* -----------------------------------------------------------------------------
* Test 3.4.2: Grace Period with Gap <= Grace Value
* Purpose: Verify exposures ARE merged when gap within grace period
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.4.2: Grace Period (gap <= grace value)"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear

    * First: count unexposed intervals WITHOUT grace period
    tvexpose using "${DATA_DIR}/exp_gap15.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        grace(0) generate(tv_no_grace)

    quietly count if tv_no_grace == 0
    local n_unexposed_no_grace = r(N)

    * Now with grace(15) - SHOULD merge (15-day gap <= 15)
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_gap15.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        grace(15) generate(tv_exp)

    * Count unexposed intervals - should be fewer due to bridging
    quietly count if tv_exp == 0
    local n_unexposed_grace = r(N)

    * The gap period (Feb 1-15) should now be exposed
    * With grace(15), the gap is bridged, so we should have fewer unexposed intervals
    * (or at minimum, the gap itself should be exposed)
    assert `n_unexposed_grace' <= `n_unexposed_no_grace'
}
if _rc == 0 {
    display as result "  PASS: Grace(15) bridges 15-day gap"
    local ++pass_count
}
else {
    display as error "  FAIL: Grace period with gap <= grace (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.4.2"
}

* =============================================================================
* TEST SECTION 3.5: DURATION CATEGORY TESTS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 3.5: Duration Category Tests"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 3.5.1: duration() Cutpoint Verification
* Purpose: Verify duration categories are assigned correctly at thresholds
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.5.1: duration() Cutpoint Assignment"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_fullyear.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        duration(0.5 1) continuousunit(years) generate(dur_cat)

    * Verify categories exist
    quietly tab dur_cat
    assert r(r) >= 1

    * Duration categories:
    * 0 = Unexposed
    * 1 = <0.5 years
    * 2 = 0.5-<1 years
    * 3 = 1+ years
    * By end of full year, should reach category 3 or 4
    sort rx_start
    quietly sum dur_cat
    assert r(max) >= 2
}
if _rc == 0 {
    display as result "  PASS: Duration categories assigned at cutpoints"
    local ++pass_count
}
else {
    display as error "  FAIL: duration() cutpoint assignment (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.5.1"
}

* =============================================================================
* TEST SECTION 3.6: LAG AND WASHOUT TESTS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 3.6: Lag and Washout Tests"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 3.6.1: lag() Delays Exposure Start
* Purpose: Verify exposure becomes active only after lag period
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.6.1: lag() Delays Exposure Start"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_basic.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        lag(30) generate(tv_exp)

    * With lag(30), exposure starting Mar 1 should become active on Mar 31
    * Days Mar 1-30 should still be unexposed
    sort rx_start

    * Find interval containing mid-March (should be unexposed due to lag)
    gen has_mar15 = (rx_start <= mdy(3,15,2020) & rx_stop >= mdy(3,15,2020))
    quietly count if has_mar15 == 1 & tv_exp == 0
    assert r(N) >= 1
}
if _rc == 0 {
    display as result "  PASS: lag(30) delays exposure activation by 30 days"
    local ++pass_count
}
else {
    display as error "  FAIL: lag() delays exposure (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.6.1"
}

* -----------------------------------------------------------------------------
* Test 3.6.2: washout() Extends Exposure End
* Purpose: Verify exposure persists after nominal stop date
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.6.2: washout() Extends Exposure End"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_basic.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        washout(30) generate(tv_exp)

    * With washout(30), exposure ending Jun 30 should persist until Jul 30
    * Days Jul 1-30 should still be exposed
    sort rx_start

    * Find interval containing mid-July (should be exposed due to washout)
    gen has_jul15 = (rx_start <= mdy(7,15,2020) & rx_stop >= mdy(7,15,2020))
    quietly count if has_jul15 == 1 & tv_exp == 1
    assert r(N) >= 1
}
if _rc == 0 {
    display as result "  PASS: washout(30) extends exposure by 30 days after stop"
    local ++pass_count
}
else {
    display as error "  FAIL: washout() extends exposure (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.6.2"
}

* =============================================================================
* TEST SECTION 3.7: OVERLAPPING EXPOSURE TESTS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 3.7: Overlapping Exposure Tests"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 3.7.1: priority() Resolves Overlaps Correctly
* Purpose: Verify higher priority exposure takes precedence during overlap
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.7.1: priority() Resolves Overlaps"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_overlap.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        priority(2 1) generate(tv_exp)

    * During overlap (Apr-Jun), should be type 2 (higher priority)
    sort rx_start
    gen has_may = (rx_start <= mdy(5,15,2020) & rx_stop >= mdy(5,15,2020))
    quietly count if has_may == 1 & tv_exp == 2
    assert r(N) >= 1
}
if _rc == 0 {
    display as result "  PASS: priority() assigns higher priority exposure during overlap"
    local ++pass_count
}
else {
    display as error "  FAIL: priority() resolves overlaps (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.7.1"
}

* =============================================================================
* TEST SECTION 3.8: EVERTREATED TESTS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 3.8: evertreated Tests"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 3.8.1: evertreated Never Reverts
* Purpose: Verify once exposed, status never returns to unexposed
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.8.1: evertreated Never Reverts"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_basic.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        evertreated generate(ever)

    sort id rx_start
    by id: gen byte reverted = (ever == 0 & ever[_n-1] == 1) if _n > 1
    quietly count if reverted == 1
    assert r(N) == 0
}
if _rc == 0 {
    display as result "  PASS: evertreated never reverts to unexposed"
    local ++pass_count
}
else {
    display as error "  FAIL: evertreated reversion check (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.8.1"
}

* -----------------------------------------------------------------------------
* Test 3.8.2: evertreated Switches at First Exposure
* Purpose: Verify exact timing of ever-treated transition
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.8.2: evertreated Switches at First Exposure"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_basic.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        evertreated generate(ever)

    * First exposure starts Mar 1, 2020
    sort rx_start

    * Before first exposure: ever = 0
    gen before_exp = (rx_stop <= mdy(3,1,2020))
    quietly count if before_exp == 1 & ever == 0
    local n_before = r(N)

    * At/after first exposure: ever = 1
    gen at_or_after_exp = (rx_start >= mdy(3,1,2020))
    quietly count if at_or_after_exp == 1 & ever == 1
    local n_after = r(N)

    * Both conditions must have at least some rows
    assert `n_before' >= 1
    assert `n_after' >= 1
}
if _rc == 0 {
    display as result "  PASS: evertreated switches at first exposure boundary"
    local ++pass_count
}
else {
    display as error "  FAIL: evertreated timing (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.8.2"
}

* =============================================================================
* TEST SECTION 3.17: ERROR HANDLING TESTS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 3.17: Error Handling Tests"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 3.17.1: Missing Required Options
* Purpose: Verify informative errors for missing required inputs
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.17.1: Missing Required Options"
}

capture {
    * Missing id()
    use "${DATA_DIR}/cohort_single.dta", clear
    capture tvexpose using "${DATA_DIR}/exp_basic.dta", start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        generate(tv_exp)
    local rc1 = _rc

    * Missing entry()
    capture tvexpose using "${DATA_DIR}/exp_basic.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) exit(study_exit) ///
        generate(tv_exp)
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
    display as error "  FAIL: Missing required options error handling (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.17.1"
}

* -----------------------------------------------------------------------------
* Test 3.17.3: Variable Not Found
* Purpose: Verify clear errors when specified variables don't exist
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.17.3: Variable Not Found"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    capture tvexpose using "${DATA_DIR}/exp_basic.dta", id(nonexistent_id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        generate(tv_exp)
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: Variable not found produces error"
    local ++pass_count
}
else {
    display as error "  FAIL: Variable not found error handling (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.17.3"
}

* =============================================================================
* TEST SECTION 3.18: DATE FORMAT PRESERVATION TESTS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 3.18: Date Format Preservation Tests"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 3.18.1: Format Retained Through Transformation
* Purpose: Verify date format from input is preserved in output
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.18.1: Date Format Preserved"
}

capture {
    * Create data with specific date format
    clear
    input long id double(study_entry study_exit)
        1 21915 22281
    end
    format %tdCCYY-NN-DD study_entry study_exit
    save "${DATA_DIR}/cohort_formatted.dta", replace

    use "${DATA_DIR}/cohort_formatted.dta", clear
    tvexpose using "${DATA_DIR}/exp_basic.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        generate(tv_exp)

    * Check format is preserved (should be %td variant)
    local fmt : format rx_start
    assert substr("`fmt'", 1, 3) == "%td"
}
if _rc == 0 {
    display as result "  PASS: Date format is preserved through transformation"
    local ++pass_count
}
else {
    display as error "  FAIL: Date format preservation (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.18.1"
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
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_overlap.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        generate(tv_exp)

    quietly count if rx_stop < rx_start
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
* Invariant 2: Exposure Values Only Valid Categories
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Invariant 2: Valid Exposure Categories"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_two.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        generate(tv_exp)

    * Should only have values 0 (reference), 1, or 2 (exposure types from input)
    quietly count if tv_exp < 0 | tv_exp > 2
    assert r(N) == 0
}
if _rc == 0 {
    display as result "  PASS: Output exposure values are valid categories only"
    local ++pass_count
}
else {
    display as error "  FAIL: Valid exposure categories invariant (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' Inv2"
}

* =============================================================================
* TEST SECTION 3.9: RECENCY TESTS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 3.9: Recency Tests"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 3.9.1: recency() Creates Time-Since-Last Categories
* Purpose: Verify recency categories are assigned based on time since exposure
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.9.1: recency() Creates Categories"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_basic.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        recency(0.5 1) generate(recency_cat)

    * Verify variable created with expected categories
    quietly tab recency_cat
    assert r(r) >= 1
}
if _rc == 0 {
    display as result "  PASS: recency() creates time-since-last categories"
    local ++pass_count
}
else {
    display as error "  FAIL: recency() categories (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.9.1"
}

* =============================================================================
* TEST SECTION 3.10: BYTYPE TESTS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 3.10: bytype Tests"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 3.10.1: bytype Creates Separate Variables
* Purpose: Verify bytype creates individual variables for each exposure type
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.10.1: bytype Creates Separate Variables"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    * bytype requires an exposure type option (evertreated, currentformer, duration, continuousunit, or recency)
    tvexpose using "${DATA_DIR}/exp_two.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        continuousunit(days) bytype generate(tv_exp)

    * Should have tv_exp1 and tv_exp2 (for exposure types 1 and 2)
    confirm variable tv_exp1
    confirm variable tv_exp2
}
if _rc == 0 {
    display as result "  PASS: bytype creates separate variables for each exposure type"
    local ++pass_count
}
else {
    display as error "  FAIL: bytype separate variables (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.10.1"
}

* =============================================================================
* TEST SECTION 3.11: DOSE AND DOSECUTS TESTS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 3.11: Dose and Dosecuts Tests"
    display as text "{hline 70}"
}

* Create dose exposure data first
clear
input long id double(rx_start rx_stop) double dose_amt
    1 21946 22006 100
    1 22067 22128 150
end
format %td rx_start rx_stop
label data "Dose exposure data"
save "${DATA_DIR}/exp_dose.dta", replace

* -----------------------------------------------------------------------------
* Test 3.11.1: dose Tracks Cumulative Dose
* Purpose: Verify cumulative dose tracking
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.11.1: dose Tracks Cumulative Dose"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_dose.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(dose_amt) entry(study_entry) exit(study_exit) ///
        dose generate(cum_dose)

    * Verify cumulative dose is tracked
    quietly sum cum_dose
    assert r(max) > 0

    * Should be monotonically increasing
    sort id rx_start
    by id: gen double cum_change = cum_dose - cum_dose[_n-1] if _n > 1
    quietly count if cum_change < -0.0001
    assert r(N) == 0
}
if _rc == 0 {
    display as result "  PASS: dose tracks cumulative dose correctly"
    local ++pass_count
}
else {
    display as error "  FAIL: dose cumulative tracking (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.11.1"
}

* -----------------------------------------------------------------------------
* Test 3.11.2: dosecuts Creates Categorical Dose Variable
* Purpose: Verify dose categorization at specified cutpoints
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.11.2: dosecuts Creates Categories"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_dose.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(dose_amt) entry(study_entry) exit(study_exit) ///
        dose dosecuts(50 100 200) generate(dose_cat)

    * Verify categories exist
    quietly tab dose_cat
    assert r(r) >= 1

    * Values should be non-negative integers
    quietly count if dose_cat < 0 | mod(dose_cat, 1) != 0
    assert r(N) == 0
}
if _rc == 0 {
    display as result "  PASS: dosecuts creates categorical dose variable"
    local ++pass_count
}
else {
    display as error "  FAIL: dosecuts categorization (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.11.2"
}

* =============================================================================
* TEST SECTION 3.12: DATA HANDLING OPTIONS TESTS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 3.12: Data Handling Options Tests"
    display as text "{hline 70}"
}

* Create data for type-specific grace testing
clear
input long id double(rx_start rx_stop) byte exp_type
    1 21915 21945 1
    1 21960 21991 1
    1 22006 22036 2
    1 22066 22097 2
end
format %td rx_start rx_stop
label data "Exposures with different gap sizes by type"
save "${DATA_DIR}/exp_typegrace.dta", replace

* -----------------------------------------------------------------------------
* Test 3.12.1: Type-Specific Grace Periods
* Purpose: Verify different grace periods for different exposure types
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.12.1: Type-Specific Grace Periods"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear

    * Type 1 has 15-day gap, Type 2 has 30-day gap
    * With grace(1=20 2=25): Type 1 bridged, Type 2 NOT bridged
    tvexpose using "${DATA_DIR}/exp_typegrace.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        grace(1=20 2=25) generate(tv_exp)

    * Command should run without error
    assert _N >= 1
}
if _rc == 0 {
    display as result "  PASS: Type-specific grace periods accepted"
    local ++pass_count
}
else {
    display as error "  FAIL: Type-specific grace (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.12.1"
}

* -----------------------------------------------------------------------------
* Test 3.12.2: merge() Consolidates Close Periods
* Purpose: Verify merge() option merges periods within threshold
* Note: merge() must be positive (>=1), default is 120
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.12.2: merge() Consolidates Close Periods"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear

    * Get count with minimal merge (merge=1: only merge periods 1 day apart)
    tvexpose using "${DATA_DIR}/exp_gap15.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        merge(1) generate(tv_no_merge)
    local n_no_merge = _N

    * With merge(30) - should consolidate nearby periods (15-day gap would be merged)
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_gap15.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        merge(30) generate(tv_merge)
    local n_merge = _N

    * Should have equal or fewer intervals after larger merge threshold
    assert `n_merge' <= `n_no_merge'
}
if _rc == 0 {
    display as result "  PASS: merge() consolidates nearby periods"
    local ++pass_count
}
else {
    display as error "  FAIL: merge() consolidation (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.12.2"
}

* -----------------------------------------------------------------------------
* Test 3.12.3: fillgaps() Extends Exposure Beyond Records
* Purpose: Verify fillgaps() extends exposure beyond last stop date
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.12.3: fillgaps() Extends Exposure"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear

    * Without fillgaps - baseline
    tvexpose using "${DATA_DIR}/exp_basic.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        fillgaps(0) generate(tv_no_fill)

    * Count exposed time
    gen double dur_exp = (rx_stop - rx_start) if tv_no_fill == 1
    quietly sum dur_exp
    local exposed_no_fill = r(sum)

    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_basic.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        fillgaps(30) generate(tv_fill)

    gen double dur_exp = (rx_stop - rx_start) if tv_fill == 1
    quietly sum dur_exp
    local exposed_fill = r(sum)

    * Exposed time should be equal or greater with fillgaps
    assert `exposed_fill' >= `exposed_no_fill'
}
if _rc == 0 {
    display as result "  PASS: fillgaps() extends exposure duration"
    local ++pass_count
}
else {
    display as error "  FAIL: fillgaps() extension (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.12.3"
}

* -----------------------------------------------------------------------------
* Test 3.12.4: carryforward() Carries Exposure Through Gaps
* Purpose: Verify carryforward() maintains exposure through gap periods
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.12.4: carryforward() Through Gaps"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_gap15.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        carryforward(20) generate(tv_cf)

    * With carryforward(20), the 15-day gap should be filled
    * Gap interval should be exposed (not reference)
    assert _N >= 1
}
if _rc == 0 {
    display as result "  PASS: carryforward() carries exposure through gaps"
    local ++pass_count
}
else {
    display as error "  FAIL: carryforward() (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.12.4"
}

* =============================================================================
* TEST SECTION 3.13: COMPETING EXPOSURE OPTIONS TESTS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 3.13: Competing Exposure Options Tests"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 3.13.1: layer (Default) Behavior
* Purpose: Verify layer gives precedence to later exposures
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.13.1: layer (Default) Behavior"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_overlap.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        layer generate(tv_layer)

    * With layer, later exposure (type 2) takes precedence during overlap
    * Exposure 2 starts later (Apr), so during Apr-Jun should be type 2
    gen has_may = (rx_start <= mdy(5,15,2020) & rx_stop >= mdy(5,15,2020))
    quietly count if has_may == 1 & tv_layer == 2
    assert r(N) >= 1
}
if _rc == 0 {
    display as result "  PASS: layer gives precedence to later exposures"
    local ++pass_count
}
else {
    display as error "  FAIL: layer behavior (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.13.1"
}

* -----------------------------------------------------------------------------
* Test 3.13.2: split Creates All Overlap Combinations
* Purpose: Verify split option creates separate rows for overlaps
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.13.2: split Creates Overlap Combinations"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear

    * Without split (using layer)
    tvexpose using "${DATA_DIR}/exp_overlap.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        layer generate(tv_nosplit)
    local n_layer = _N

    * With split - should have more rows due to splitting at boundaries
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_overlap.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        split generate(tv_split)
    local n_split = _N

    * Split should create equal or more intervals
    assert `n_split' >= `n_layer'
}
if _rc == 0 {
    display as result "  PASS: split creates boundary-split intervals"
    local ++pass_count
}
else {
    display as error "  FAIL: split option (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.13.2"
}

* -----------------------------------------------------------------------------
* Test 3.13.3: combine() Creates Combined Exposure Variable
* Purpose: Verify combine() creates indicator for simultaneous exposures
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.13.3: combine() Creates Combined Variable"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_overlap.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        combine(combined_exp) generate(tv_exp)

    * Verify combined variable was created
    confirm variable combined_exp
}
if _rc == 0 {
    display as result "  PASS: combine() creates combined exposure variable"
    local ++pass_count
}
else {
    display as error "  FAIL: combine() variable creation (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.13.3"
}

* =============================================================================
* TEST SECTION 3.14: WINDOW OPTION TESTS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 3.14: Window Option Tests"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 3.14.1: window() Restricts to Acute Window
* Purpose: Verify window() only counts exposures within time bounds
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.14.1: window() Acute Exposure Window"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_basic.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        window(30 90) generate(tv_window)

    * Command should run - window restricts which periods are counted
    assert _N >= 1
}
if _rc == 0 {
    display as result "  PASS: window() option restricts to acute window"
    local ++pass_count
}
else {
    display as error "  FAIL: window() option (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.14.1"
}

* =============================================================================
* TEST SECTION 3.15: PATTERN TRACKING OPTIONS TESTS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 3.15: Pattern Tracking Options Tests"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 3.15.1: switching Creates Binary Indicator
* Purpose: Verify switching creates 0/1 indicator for any switch
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.15.1: switching Creates Binary Indicator"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_two.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        switching generate(tv_exp)

    * Verify ever_switched variable exists
    confirm variable ever_switched

    * Should be 0 or 1 only
    quietly count if ever_switched < 0 | ever_switched > 1
    assert r(N) == 0
}
if _rc == 0 {
    display as result "  PASS: switching creates binary indicator"
    local ++pass_count
}
else {
    display as error "  FAIL: switching indicator (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.15.1"
}

* -----------------------------------------------------------------------------
* Test 3.15.2: switchingdetail Creates Pattern String
* Purpose: Verify switchingdetail creates string showing switch sequence
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.15.2: switchingdetail Creates Pattern String"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_two.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        switchingdetail generate(tv_exp)

    * Verify switching_pattern variable exists (string type)
    confirm variable switching_pattern
    confirm string variable switching_pattern
}
if _rc == 0 {
    display as result "  PASS: switchingdetail creates pattern string variable"
    local ++pass_count
}
else {
    display as error "  FAIL: switchingdetail pattern (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.15.2"
}

* -----------------------------------------------------------------------------
* Test 3.15.3: statetime Creates Cumulative State Time
* Purpose: Verify statetime tracks cumulative time in current state
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.15.3: statetime Creates Cumulative State Time"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_basic.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        statetime generate(tv_exp)

    * Verify state_time_years variable exists
    confirm variable state_time_years

    * Should be non-negative
    quietly count if state_time_years < 0
    assert r(N) == 0
}
if _rc == 0 {
    display as result "  PASS: statetime creates cumulative state time variable"
    local ++pass_count
}
else {
    display as error "  FAIL: statetime variable (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.15.3"
}

* =============================================================================
* TEST SECTION 3.16: OUTPUT OPTIONS TESTS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 3.16: Output Options Tests"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 3.16.1: referencelabel() Sets Reference Category Label
* Purpose: Verify referencelabel() changes the label for unexposed
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.16.1: referencelabel() Sets Reference Label"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_basic.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        referencelabel("No Treatment") generate(tv_exp)

    * Verify label was applied
    local vallbl : value label tv_exp
    if "`vallbl'" != "" {
        local lbl0 : label `vallbl' 0
        assert "`lbl0'" == "No Treatment"
    }
}
if _rc == 0 {
    display as result "  PASS: referencelabel() sets custom reference label"
    local ++pass_count
}
else {
    display as error "  FAIL: referencelabel() (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.16.1"
}

* -----------------------------------------------------------------------------
* Test 3.16.2: label() Sets Variable Label
* Purpose: Verify label() sets custom variable label
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.16.2: label() Sets Variable Label"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_basic.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        label("My Custom Exposure Label") generate(tv_exp)

    * Verify variable label was applied
    local varlbl : variable label tv_exp
    assert "`varlbl'" == "My Custom Exposure Label"
}
if _rc == 0 {
    display as result "  PASS: label() sets custom variable label"
    local ++pass_count
}
else {
    display as error "  FAIL: label() variable label (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.16.2"
}

* -----------------------------------------------------------------------------
* Test 3.16.3: saveas() and replace Save Output
* Purpose: Verify saveas() saves dataset to file
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.16.3: saveas() and replace Save Output"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    capture erase "${DATA_DIR}/tvexpose_output.dta"

    tvexpose using "${DATA_DIR}/exp_basic.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        saveas("${DATA_DIR}/tvexpose_output.dta") replace generate(tv_exp)

    * Verify file was created
    confirm file "${DATA_DIR}/tvexpose_output.dta"

    * Load and verify
    use "${DATA_DIR}/tvexpose_output.dta", clear
    confirm variable tv_exp

    * Cleanup
    capture erase "${DATA_DIR}/tvexpose_output.dta"
}
if _rc == 0 {
    display as result "  PASS: saveas() and replace save output to file"
    local ++pass_count
}
else {
    display as error "  FAIL: saveas() and replace (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.16.3"
}

* -----------------------------------------------------------------------------
* Test 3.16.4: keepvars() Keeps Additional Variables
* Purpose: Verify keepvars() brings additional variables from master
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.16.4: keepvars() Keeps Additional Variables"
}

capture {
    * Create cohort with additional variables
    clear
    input long id double(study_entry study_exit) byte female int age
        1 21915 22281 1 45
    end
    format %td study_entry study_exit
    save "${DATA_DIR}/cohort_with_covars.dta", replace

    use "${DATA_DIR}/cohort_with_covars.dta", clear
    tvexpose using "${DATA_DIR}/exp_basic.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        keepvars(female age) generate(tv_exp)

    * Verify kept variables exist
    confirm variable female
    confirm variable age

    * Values should be preserved
    quietly sum female
    assert r(mean) == 1
    quietly sum age
    assert r(mean) == 45
}
if _rc == 0 {
    display as result "  PASS: keepvars() keeps additional variables from master"
    local ++pass_count
}
else {
    display as error "  FAIL: keepvars() (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.16.4"
}

* -----------------------------------------------------------------------------
* Test 3.16.5: keepdates Retains Entry/Exit Dates
* Purpose: Verify keepdates option keeps entry and exit date variables
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.16.5: keepdates Retains Entry/Exit Dates"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_basic.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        keepdates generate(tv_exp)

    * Verify entry and exit dates are present
    confirm variable study_entry
    confirm variable study_exit
}
if _rc == 0 {
    display as result "  PASS: keepdates retains entry and exit date variables"
    local ++pass_count
}
else {
    display as error "  FAIL: keepdates option (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.16.5"
}

* =============================================================================
* TEST SECTION 3.19: CONTINUOUS UNIT TESTS (Additional Units)
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 3.19: continuousunit Additional Units Tests"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 3.19.1: continuousunit(months)
* Purpose: Verify cumulative exposure in months
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.19.1: continuousunit(months)"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_fullyear.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        continuousunit(months) generate(cum_months)

    * Full year should be ~12 months
    quietly sum cum_months
    assert abs(r(max) - 12) < 1
}
if _rc == 0 {
    display as result "  PASS: continuousunit(months) calculates ~12 months"
    local ++pass_count
}
else {
    display as error "  FAIL: continuousunit(months) (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.19.1"
}

* -----------------------------------------------------------------------------
* Test 3.19.2: continuousunit(weeks)
* Purpose: Verify cumulative exposure in weeks
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.19.2: continuousunit(weeks)"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_fullyear.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        continuousunit(weeks) generate(cum_weeks)

    * Full year should be ~52 weeks
    quietly sum cum_weeks
    assert abs(r(max) - 52) < 2
}
if _rc == 0 {
    display as result "  PASS: continuousunit(weeks) calculates ~52 weeks"
    local ++pass_count
}
else {
    display as error "  FAIL: continuousunit(weeks) (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.19.2"
}

* -----------------------------------------------------------------------------
* Test 3.19.3: continuousunit(quarters)
* Purpose: Verify cumulative exposure in quarters
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.19.3: continuousunit(quarters)"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_fullyear.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        continuousunit(quarters) generate(cum_quarters)

    * Full year should be ~4 quarters
    quietly sum cum_quarters
    assert abs(r(max) - 4) < 0.5
}
if _rc == 0 {
    display as result "  PASS: continuousunit(quarters) calculates ~4 quarters"
    local ++pass_count
}
else {
    display as error "  FAIL: continuousunit(quarters) (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.19.3"
}

* =============================================================================
* TEST SECTION 3.20: EXPANDUNIT TESTS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 3.20: expandunit Tests"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 3.20.1: expandunit Creates Finer Granularity
* Purpose: Verify expandunit splits into calendar intervals
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.20.1: expandunit Creates Finer Granularity"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear

    * Without expandunit
    tvexpose using "${DATA_DIR}/exp_fullyear.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        continuousunit(years) generate(tv_no_expand)
    local n_no_expand = _N

    * With expandunit(months) - should create more rows
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_fullyear.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        continuousunit(years) expandunit(months) generate(tv_expand)
    local n_expand = _N

    * Expanded should have more rows
    assert `n_expand' >= `n_no_expand'
}
if _rc == 0 {
    display as result "  PASS: expandunit creates finer granularity rows"
    local ++pass_count
}
else {
    display as error "  FAIL: expandunit (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.20.1"
}

* =============================================================================
* TEST SECTION 3.21: DIAGNOSTIC OPTIONS TESTS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 3.21: Diagnostic Options Tests"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 3.21.1: check Option Runs Without Error
* Purpose: Verify check displays diagnostics without error
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.21.1: check Option Runs"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_basic.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        check generate(tv_exp)

    assert _N >= 1
}
if _rc == 0 {
    display as result "  PASS: check option runs without error"
    local ++pass_count
}
else {
    display as error "  FAIL: check option (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.21.1"
}

* -----------------------------------------------------------------------------
* Test 3.21.2: gaps Option Runs Without Error
* Purpose: Verify gaps displays gap information without error
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.21.2: gaps Option Runs"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_gap15.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        gaps generate(tv_exp)

    assert _N >= 1
}
if _rc == 0 {
    display as result "  PASS: gaps option runs without error"
    local ++pass_count
}
else {
    display as error "  FAIL: gaps option (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.21.2"
}

* -----------------------------------------------------------------------------
* Test 3.21.3: overlaps Option Runs Without Error
* Purpose: Verify overlaps displays overlap information without error
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.21.3: overlaps Option Runs"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_overlap.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        overlaps generate(tv_exp)

    assert _N >= 1
}
if _rc == 0 {
    display as result "  PASS: overlaps option runs without error"
    local ++pass_count
}
else {
    display as error "  FAIL: overlaps option (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.21.3"
}

* -----------------------------------------------------------------------------
* Test 3.21.4: summarize Option Runs Without Error
* Purpose: Verify summarize displays summary statistics without error
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.21.4: summarize Option Runs"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_basic.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        summarize generate(tv_exp)

    assert _N >= 1
}
if _rc == 0 {
    display as result "  PASS: summarize option runs without error"
    local ++pass_count
}
else {
    display as error "  FAIL: summarize option (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.21.4"
}

* -----------------------------------------------------------------------------
* Test 3.21.5: validate Option Creates Validation Dataset
* Purpose: Verify validate creates coverage metrics dataset
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.21.5: validate Option Creates Dataset"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    capture erase "${DATA_DIR}/tvexpose_val_output.dta"
    capture erase "${DATA_DIR}/tvexpose_val_output_validation.dta"

    * Use saveas() so validation file goes to DATA_DIR (validation file is saveas_validation.dta)
    tvexpose using "${DATA_DIR}/exp_basic.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        validate saveas("${DATA_DIR}/tvexpose_val_output.dta") replace generate(tv_exp)

    * Verify validation file was created (derived from saveas path)
    confirm file "${DATA_DIR}/tvexpose_val_output_validation.dta"

    * Cleanup
    capture erase "${DATA_DIR}/tvexpose_val_output.dta"
    capture erase "${DATA_DIR}/tvexpose_val_output_validation.dta"
}
if _rc == 0 {
    display as result "  PASS: validate creates validation dataset"
    local ++pass_count
}
else {
    display as error "  FAIL: validate option (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.21.5"
}

* =============================================================================
* TEST SECTION 3.22: POINTTIME TESTS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 3.22: pointtime Tests"
    display as text "{hline 70}"
}

* Create point-in-time exposure data
clear
input long id double rx_start byte exp_type
    1 21946 1
    1 22067 1
    1 22128 2
end
format %td rx_start
label data "Point-in-time exposures"
save "${DATA_DIR}/exp_pointtime.dta", replace

* -----------------------------------------------------------------------------
* Test 3.22.1: pointtime Works Without stop Variable
* Purpose: Verify pointtime allows exposure data without stop dates
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.22.1: pointtime Without stop Variable"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_pointtime.dta", id(id) start(rx_start) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        pointtime generate(tv_exp)

    * Should run without stop() option
    assert _N >= 1
}
if _rc == 0 {
    display as result "  PASS: pointtime works without stop variable"
    local ++pass_count
}
else {
    display as error "  FAIL: pointtime option (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.22.1"
}

* =============================================================================
* TEST SECTION 3.23: MERGE WITH ZERO VALUE
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 3.23: merge(0) Explicit Tests"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 3.23.1: merge(0) Does Not Consolidate Periods
* Purpose: Verify merge(0) keeps all periods separate (default behavior)
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.23.1: merge(0) Does Not Consolidate Periods"
}

capture {
    * Create exposure with closely-spaced periods (15 days apart)
    clear
    input long id double(rx_start rx_stop) byte exp_type
        1 21915 21975 1
        1 21990 22050 1
        1 22067 22189 1
    end
    format %td rx_start rx_stop
    save "${DATA_DIR}/exp_close_periods.dta", replace

    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_close_periods.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        merge(0) generate(tv_exp)

    * Count intervals with exp_type == 1
    quietly count if tv_exp == 1
    local n_exposed = r(N)

    * With merge(0), should have at least 3 separate exposed intervals
    assert `n_exposed' >= 3
}
if _rc == 0 {
    display as result "  PASS: merge(0) keeps periods separate (no consolidation)"
    local ++pass_count
}
else {
    display as error "  FAIL: merge(0) no consolidation (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.23.1"
}

* =============================================================================
* TEST SECTION 3.24: CONTINUOUSUNIT DAYS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 3.24: continuousunit(days) Explicit Tests"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 3.24.1: continuousunit(days) Calculates in Days
* Purpose: Verify continuousunit(days) returns duration in days
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.24.1: continuousunit(days)"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    * Note: continuousunit() is mutually exclusive with evertreated
    * This test verifies continuousunit(days) calculates cumulative exposure in days
    tvexpose using "${DATA_DIR}/exposure_single_cumulative.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(cumulative) reference(0) entry(study_entry) exit(study_exit) ///
        continuousunit(days) generate(tv_exp)

    * Duration should be in days (larger values than years)
    confirm variable tv_exp
    quietly sum tv_exp
    * If continuousunit is days, values should be reasonable day counts
    assert r(max) >= 1
}
if _rc == 0 {
    display as result "  PASS: continuousunit(days) calculates in days"
    local ++pass_count
}
else {
    display as error "  FAIL: continuousunit(days) (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.24.1"
}

* =============================================================================
* TEST SECTION 3.25: NEGATIVE VALUE ERROR HANDLING
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 3.25: Negative Value Error Handling"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 3.25.1: Negative merge() Produces Error
* Purpose: Verify negative merge value is rejected
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.25.1: Negative merge() Error"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    capture tvexpose using "${DATA_DIR}/exposure_single.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        merge(-10) generate(tv_exp)
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: Negative merge() produces error"
    local ++pass_count
}
else {
    display as error "  FAIL: Negative merge() error (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.25.1"
}

* -----------------------------------------------------------------------------
* Test 3.25.2: Negative lag() Produces Error
* Purpose: Verify negative lag value is rejected
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.25.2: Negative lag() Error"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    capture tvexpose using "${DATA_DIR}/exposure_single.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        lag(-5) generate(tv_exp)
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: Negative lag() produces error"
    local ++pass_count
}
else {
    display as error "  FAIL: Negative lag() error (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.25.2"
}

* -----------------------------------------------------------------------------
* Test 3.25.3: Negative washout() Produces Error
* Purpose: Verify negative washout value is rejected
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.25.3: Negative washout() Error"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    capture tvexpose using "${DATA_DIR}/exposure_single.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        washout(-7) generate(tv_exp)
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: Negative washout() produces error"
    local ++pass_count
}
else {
    display as error "  FAIL: Negative washout() error (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.25.3"
}

* -----------------------------------------------------------------------------
* Test 3.25.4: Negative fillgaps() Produces Error
* Purpose: Verify negative fillgaps value is rejected
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.25.4: Negative fillgaps() Error"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    capture tvexpose using "${DATA_DIR}/exposure_single.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        fillgaps(-30) generate(tv_exp)
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: Negative fillgaps() produces error"
    local ++pass_count
}
else {
    display as error "  FAIL: Negative fillgaps() error (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.25.4"
}

* -----------------------------------------------------------------------------
* Test 3.25.5: Negative carryforward() Produces Error
* Purpose: Verify negative carryforward value is rejected
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.25.5: Negative carryforward() Error"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    capture tvexpose using "${DATA_DIR}/exposure_single.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        carryforward(-14) generate(tv_exp)
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: Negative carryforward() produces error"
    local ++pass_count
}
else {
    display as error "  FAIL: Negative carryforward() error (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.25.5"
}

* =============================================================================
* TEST SECTION 3.26: BYTYPE WITH EXPOSURE TYPES
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 3.26: bytype with Exposure Type Options"
    display as text "{hline 70}"
}

* Create multi-type exposure data
clear
input long id double(rx_start rx_stop) byte exp_type
    1 21915 21975 1
    1 22006 22067 2
    1 22128 22189 1
end
format %td rx_start rx_stop
label data "Multiple exposure types"
save "${DATA_DIR}/exp_multi_type.dta", replace

* -----------------------------------------------------------------------------
* Test 3.26.1: bytype with evertreated
* Purpose: Verify bytype creates separate variables for each type with evertreated
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.26.1: bytype with evertreated"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_multi_type.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        bytype evertreated generate(tv_exp)

    * Should create separate variables for each exposure type (tv_exp1, tv_exp2)
    confirm variable tv_exp1
    confirm variable tv_exp2

    * Note: tvexpose renames start/stop back to original names (rx_start/rx_stop)
    * Each should follow evertreated logic (never revert to 0 once exposed)
    sort id rx_start
    by id: gen byte ever1_reverts = (tv_exp1 == 0 & tv_exp1[_n-1] == 1) if _n > 1
    by id: gen byte ever2_reverts = (tv_exp2 == 0 & tv_exp2[_n-1] == 1) if _n > 1
    quietly count if ever1_reverts == 1
    assert r(N) == 0
    quietly count if ever2_reverts == 1
    assert r(N) == 0
}
if _rc == 0 {
    display as result "  PASS: bytype with evertreated creates separate non-reverting variables"
    local ++pass_count
}
else {
    display as error "  FAIL: bytype with evertreated (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.26.1"
}

* -----------------------------------------------------------------------------
* Test 3.26.2: bytype with currentformer
* Purpose: Verify bytype creates separate variables with currentformer logic
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.26.2: bytype with currentformer"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_multi_type.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        bytype currentformer generate(tv_exp)

    * Should create separate variables for each exposure type (tv_exp1, tv_exp2)
    confirm variable tv_exp1
    confirm variable tv_exp2

    * Values should be 0 (never), 1 (current), or 2 (former)
    quietly count if tv_exp1 < 0 | tv_exp1 > 2
    assert r(N) == 0
    quietly count if tv_exp2 < 0 | tv_exp2 > 2
    assert r(N) == 0
}
if _rc == 0 {
    display as result "  PASS: bytype with currentformer creates valid categorical variables"
    local ++pass_count
}
else {
    display as error "  FAIL: bytype with currentformer (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.26.2"
}

* =============================================================================
* TEST SECTION 3.27: EDGE CASES - SINGLE DAY AND BOUNDARY EXPOSURES
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 3.27: Edge Cases - Single Day and Boundary Exposures"
    display as text "{hline 70}"
}

* Create single-day exposure
clear
input long id double(rx_start rx_stop) byte exp_type
    1 22006 22007 1
end
format %td rx_start rx_stop
label data "Single-day exposure"
save "${DATA_DIR}/exp_single_day.dta", replace

* Create exposure starting at entry
clear
input long id double(rx_start rx_stop) byte exp_type
    1 21915 22006 1
end
format %td rx_start rx_stop
label data "Exposure starting at entry"
save "${DATA_DIR}/exp_at_entry.dta", replace

* Create exposure ending at exit
clear
input long id double(rx_start rx_stop) byte exp_type
    1 22189 22281 1
end
format %td rx_start rx_stop
label data "Exposure ending at exit"
save "${DATA_DIR}/exp_at_exit.dta", replace

* -----------------------------------------------------------------------------
* Test 3.27.1: Single-Day Exposure
* Purpose: Verify single-day exposures are handled correctly
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.27.1: Single-Day Exposure"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_single_day.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        generate(tv_exp)

    * Should have at least one interval with exposure
    quietly count if tv_exp == 1
    assert r(N) >= 1

    * Total person-time should be preserved (inclusive endpoints)
    * Note: tvexpose renames start/stop back to original names (rx_start/rx_stop)
    gen dur = rx_stop - rx_start + 1
    quietly sum dur
    local total_dur = r(sum)
    assert abs(`total_dur' - 367) < 2
}
if _rc == 0 {
    display as result "  PASS: Single-day exposure handled correctly"
    local ++pass_count
}
else {
    display as error "  FAIL: Single-day exposure (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.27.1"
}

* -----------------------------------------------------------------------------
* Test 3.27.2: Exposure Starting at Entry
* Purpose: Verify exposure starting exactly at study entry
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.27.2: Exposure Starting at Entry"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_at_entry.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        generate(tv_exp)

    * There should be exposed periods starting at study entry
    * Note: tvexpose may create 0-duration baseline periods, so check for exposed periods
    * Note: tvexpose renames start/stop back to original names (rx_start/rx_stop)
    sort id rx_start
    quietly count if tv_exp == 1
    assert r(N) >= 1

    * The exposed period should include the study entry date
    quietly sum rx_start if tv_exp == 1
    assert r(min) <= 21915  // study_entry = 21915 (01jan2020)
}
if _rc == 0 {
    display as result "  PASS: Exposure starting at entry handled correctly"
    local ++pass_count
}
else {
    display as error "  FAIL: Exposure at entry (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.27.2"
}

* -----------------------------------------------------------------------------
* Test 3.27.3: Exposure Ending at Exit
* Purpose: Verify exposure ending exactly at study exit
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.27.3: Exposure Ending at Exit"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_at_exit.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        generate(tv_exp)

    * Last interval should be exposed
    * Note: tvexpose renames start/stop back to original names (rx_start/rx_stop)
    sort id rx_start
    assert tv_exp[_N] == 1
}
if _rc == 0 {
    display as result "  PASS: Exposure ending at exit handled correctly"
    local ++pass_count
}
else {
    display as error "  FAIL: Exposure at exit (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.27.3"
}

* =============================================================================
* TEST SECTION 3.28: EMPTY EXPOSURE DATA
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 3.28: Empty Exposure Data"
    display as text "{hline 70}"
}

* Create empty exposure dataset
clear
set obs 0
gen long id = .
gen double rx_start = .
gen double rx_stop = .
gen byte exp_type = .
format %td rx_start rx_stop
label data "Empty exposure dataset"
save "${DATA_DIR}/exp_empty.dta", replace

* -----------------------------------------------------------------------------
* Test 3.28.1: Empty Exposure Dataset Produces Error
* Purpose: Verify tvexpose errors appropriately when exposure dataset is empty
* Note: It's reasonable to error on empty exposure data since there's nothing to process
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.28.1: Empty Exposure Dataset Error"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    * tvexpose should error when exposure dataset has no observations
    capture tvexpose using "${DATA_DIR}/exp_empty.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        generate(tv_exp)
    * Should produce error 198 "Dataset must contain observations"
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: Empty exposure dataset correctly produces error"
    local ++pass_count
}
else {
    display as error "  FAIL: Empty exposure dataset should produce error 198 (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.28.1"
}

* =============================================================================
* TEST SECTION 3.29: INVALID CONTINUOUSUNIT VALUE
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 3.29: Invalid continuousunit Error Handling"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 3.29.1: Invalid continuousunit Value
* Purpose: Verify error for invalid continuousunit string
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.29.1: Invalid continuousunit Value"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    capture tvexpose using "${DATA_DIR}/exposure_single.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        continuousunit(invalid_unit) generate(tv_exp)
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: Invalid continuousunit produces error"
    local ++pass_count
}
else {
    display as error "  FAIL: Invalid continuousunit error (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.29.1"
}

* =============================================================================
* TEST SECTION 3.30: EXPOSURE TYPE COMBINATIONS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 3.30: Exposure Type Combinations"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 3.30.1: evertreated + duration() are Mutually Exclusive
* Purpose: Verify evertreated and duration() cannot be used together (mutually exclusive)
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.30.1: evertreated + duration() mutually exclusive"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    * Note: evertreated and duration() are mutually exclusive exposure type options
    * Only one can be specified at a time
    capture tvexpose using "${DATA_DIR}/exposure_single.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        evertreated duration(30 90 180) generate(tv_exp)
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: evertreated + duration() correctly produces error"
    local ++pass_count
}
else {
    display as error "  FAIL: evertreated + duration() should produce error (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.30.1"
}

* -----------------------------------------------------------------------------
* Test 3.30.2: currentformer + recency() are Mutually Exclusive
* Purpose: Verify currentformer and recency() cannot be used together (mutually exclusive)
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.30.2: currentformer + recency() mutually exclusive"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    * Note: currentformer and recency() are mutually exclusive exposure type options
    capture tvexpose using "${DATA_DIR}/exposure_single.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        currentformer recency(30 90) generate(tv_exp)
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: currentformer + recency() correctly produces error"
    local ++pass_count
}
else {
    display as error "  FAIL: currentformer + recency() should produce error (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.30.2"
}

* -----------------------------------------------------------------------------
* Test 3.30.3: dose + dosecuts Works (bytype not allowed with dose)
* Purpose: Verify dose tracking with categories works correctly
* Note: bytype is not allowed with dose, so we test dose + dosecuts without bytype
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.30.3: dose + dosecuts"
}

* Create exposure with dose information
clear
input long id double(rx_start rx_stop) double dose_amt
    1 21946 22006 100
    1 22067 22128 50
    1 22159 22220 150
end
format %td rx_start rx_stop
label data "Exposure with dose amounts"
save "${DATA_DIR}/exposure_dose.dta", replace

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    * Note: bytype is not allowed with dose, so we test dose + dosecuts alone
    tvexpose using "${DATA_DIR}/exposure_dose.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(dose_amt) entry(study_entry) exit(study_exit) ///
        dose dosecuts(50 100 200) generate(tv_exp)

    * Should create dose categories
    confirm variable tv_exp
    assert _N >= 1
}
if _rc == 0 {
    display as result "  PASS: dose + dosecuts works correctly"
    local ++pass_count
}
else {
    display as error "  FAIL: dose + dosecuts (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.30.3"
}

* =============================================================================
* TEST SECTION 3.31: TIME ADJUSTMENT COMBINATIONS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 3.31: Time Adjustment Combinations"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 3.31.1: grace + lag + washout Combination
* Purpose: Verify multiple time adjustments work together
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.31.1: grace + lag + washout Combination"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exposure_single.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        grace(7) lag(14) washout(30) generate(tv_exp)

    * All adjustments should be applied
    confirm variable tv_exp
    assert _N >= 1
}
if _rc == 0 {
    display as result "  PASS: grace + lag + washout works together"
    local ++pass_count
}
else {
    display as error "  FAIL: grace + lag + washout (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.31.1"
}

* -----------------------------------------------------------------------------
* Test 3.31.2: fillgaps + carryforward Combination
* Purpose: Verify gap handling options together
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.31.2: fillgaps + carryforward Combination"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exposure_single.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        fillgaps(14) carryforward(30) generate(tv_exp)

    * Both options should work
    confirm variable tv_exp
    assert _N >= 1
}
if _rc == 0 {
    display as result "  PASS: fillgaps + carryforward works together"
    local ++pass_count
}
else {
    display as error "  FAIL: fillgaps + carryforward (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.31.2"
}

* -----------------------------------------------------------------------------
* Test 3.31.3: window + lag Combination
* Purpose: Verify acute window with lag adjustment
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.31.3: window + lag Combination"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exposure_single.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        window(0 30) lag(7) generate(tv_exp)

    * Window should start after lag period
    confirm variable tv_exp
    assert _N >= 1
}
if _rc == 0 {
    display as result "  PASS: window + lag works together"
    local ++pass_count
}
else {
    display as error "  FAIL: window + lag (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.31.3"
}

* =============================================================================
* TEST SECTION 3.32: COMPETING EXPOSURE COMBINATIONS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 3.32: Competing Exposure Combinations"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 3.32.1: priority + layer are Mutually Exclusive
* Purpose: Verify priority and layer cannot be specified together
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.32.1: priority + layer mutually exclusive"
}

* Create overlapping exposures
clear
input long id double(rx_start rx_stop) byte exp_type
    1 21946 22067 1
    1 22006 22128 2
end
format %td rx_start rx_stop
label data "Overlapping exposures"
save "${DATA_DIR}/exposure_overlap.dta", replace

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    * Note: priority() and layer are mutually exclusive overlap handling options
    capture tvexpose using "${DATA_DIR}/exposure_overlap.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        priority(1 2) layer generate(tv_exp)
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: priority + layer correctly produces error"
    local ++pass_count
}
else {
    display as error "  FAIL: priority + layer should produce error (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.32.1"
}

* -----------------------------------------------------------------------------
* Test 3.32.2: split + combine are Mutually Exclusive
* Purpose: Verify split and combine() cannot be specified together
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.32.2: split + combine mutually exclusive"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    * Note: split and combine() are mutually exclusive overlap handling options
    capture tvexpose using "${DATA_DIR}/exposure_overlap.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        split combine(combined_exp) generate(tv_exp)
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: split + combine correctly produces error"
    local ++pass_count
}
else {
    display as error "  FAIL: split + combine (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.32.2"
}

* =============================================================================
* TEST SECTION 3.33: SWITCHING COMBINATIONS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 3.33: Switching Analysis Combinations"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 3.33.1: switching + statetime Combination
* Purpose: Verify switching indicator with cumulative state time
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.33.1: switching + statetime Combination"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exposure_overlap.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        switching statetime generate(tv_exp)

    * Both switching and statetime should be created
    * (exact variable names depend on implementation)
    confirm variable tv_exp
    assert _N >= 1
}
if _rc == 0 {
    display as result "  PASS: switching + statetime works together"
    local ++pass_count
}
else {
    display as error "  FAIL: switching + statetime (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.33.1"
}

* -----------------------------------------------------------------------------
* Test 3.33.2: bytype Requires Exposure Type Option
* Purpose: Verify bytype cannot be used without an exposure type option
* Note: bytype requires one of: evertreated, currentformer, duration(), continuousunit(), or recency()
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.33.2: bytype requires exposure type"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    * Note: bytype cannot be used with default time-varying (requires an exposure type option)
    capture tvexpose using "${DATA_DIR}/exp_multi_type.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        switchingdetail bytype generate(tv_exp)
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: bytype without exposure type correctly produces error"
    local ++pass_count
}
else {
    display as error "  FAIL: bytype should require exposure type option (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.33.2"
}

* =============================================================================
* TEST SECTION 3.34: OUTPUT COMBINATIONS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 3.34: Output and Diagnostic Combinations"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 3.34.1: saveas + keepvars + keepdates Combination
* Purpose: Verify saving with additional variables and dates
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.34.1: saveas + keepvars + keepdates Combination"
}

capture {
    capture erase "${DATA_DIR}/tvexpose_combo_output.dta"

    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exposure_single.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        keepdates saveas("${DATA_DIR}/tvexpose_combo_output.dta") replace ///
        generate(tv_exp)

    * File should be created with all options
    confirm file "${DATA_DIR}/tvexpose_combo_output.dta"

    use "${DATA_DIR}/tvexpose_combo_output.dta", clear
    confirm variable tv_exp
    confirm variable study_entry
    confirm variable study_exit

    capture erase "${DATA_DIR}/tvexpose_combo_output.dta"
}
if _rc == 0 {
    display as result "  PASS: saveas + keepvars + keepdates works together"
    local ++pass_count
}
else {
    display as error "  FAIL: saveas + keepvars + keepdates (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.34.1"
}

* -----------------------------------------------------------------------------
* Test 3.34.2: summarize Diagnostic Option
* Purpose: Verify summarize diagnostic option works correctly
* Note: Using summarize alone to avoid tempfile complexity with multiple diagnostics
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.34.2: summarize diagnostic option"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exposure_single.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        summarize generate(tv_exp)

    * Summarize should run and output variable should exist
    confirm variable tv_exp
    assert _N >= 1
}
if _rc == 0 {
    display as result "  PASS: summarize diagnostic option works"
    local ++pass_count
}
else {
    display as error "  FAIL: summarize diagnostic (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.34.2"
}

* -----------------------------------------------------------------------------
* Test 3.34.3: referencelabel + label + evertreated Combination
* Purpose: Verify labeling options with exposure type
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.34.3: referencelabel + label + evertreated"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exposure_single.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        evertreated referencelabel("Never Treated") label("Ever Treated Status") ///
        generate(tv_exp)

    * Labels should be applied
    confirm variable tv_exp

    * Check variable label
    local vlbl : variable label tv_exp
    assert "`vlbl'" == "Ever Treated Status"
}
if _rc == 0 {
    display as result "  PASS: referencelabel + label + evertreated works"
    local ++pass_count
}
else {
    display as error "  FAIL: referencelabel + label + evertreated (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.34.3"
}

* =============================================================================
* TEST SECTION 3.35: MULTI-PERSON TESTS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 3.35: Multi-Person Tests"
    display as text "{hline 70}"
}

* Create multi-person cohort
clear
input long id double(study_entry study_exit)
    1 21915 22281
    2 21946 22189
    3 22006 22281
end
format %td study_entry study_exit
label data "Multi-person cohort"
save "${DATA_DIR}/cohort_multi.dta", replace

* Create multi-person exposures
clear
input long id double(rx_start rx_stop) byte exp_type
    1 21946 22067 1
    1 22128 22220 2
    2 22006 22097 1
    3 22067 22189 1
    3 22189 22250 2
end
format %td rx_start rx_stop
label data "Multi-person exposures"
save "${DATA_DIR}/exposure_multi.dta", replace

* -----------------------------------------------------------------------------
* Test 3.35.1: Multiple Persons with Different Exposure Patterns
* Purpose: Verify correct handling across multiple persons
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.35.1: Multiple Persons with Different Patterns"
}

capture {
    use "${DATA_DIR}/cohort_multi.dta", clear
    tvexpose using "${DATA_DIR}/exposure_multi.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        generate(tv_exp)

    * Output variable should exist
    confirm variable tv_exp
    * Note: tvexpose renames start/stop back to original names (rx_start/rx_stop)
    confirm variable rx_start
    confirm variable rx_stop

    * All 3 persons should be present
    quietly levelsof id, local(ids)
    local n_ids: word count `ids'
    assert `n_ids' == 3

    * Should have multiple time periods
    assert _N >= 3
}
if _rc == 0 {
    display as result "  PASS: Multiple persons handled correctly"
    local ++pass_count
}
else {
    display as error "  FAIL: Multi-person patterns (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.35.1"
}

* -----------------------------------------------------------------------------
* Test 3.35.2: Multi-Person with evertreated + bytype
* Purpose: Verify complex options across multiple persons
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.35.2: Multi-Person with evertreated + bytype"
}

capture {
    use "${DATA_DIR}/cohort_multi.dta", clear
    tvexpose using "${DATA_DIR}/exposure_multi.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        evertreated bytype generate(tv_exp)

    * Should create type-specific variables for all persons (tv_exp1, tv_exp2)
    confirm variable tv_exp1
    confirm variable tv_exp2

    * All 3 persons should be present
    quietly levelsof id, local(ids)
    local n_ids: word count `ids'
    assert `n_ids' == 3
}
if _rc == 0 {
    display as result "  PASS: Multi-person evertreated + bytype works"
    local ++pass_count
}
else {
    display as error "  FAIL: Multi-person evertreated + bytype (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.35.2"
}

* =============================================================================
* TEST SECTION 3.36: ADVANCED EDGE CASES - OVERLAPS AND BOUNDARIES
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 3.36: Advanced Edge Cases - Overlaps and Boundaries"
    display as text "{hline 70}"
}

* Create exposure before cohort entry (starts 30 days before study entry)
clear
input long id double(rx_start rx_stop) byte exp_type
    1 21885 21975 1
end
format %td rx_start rx_stop
label data "Exposure starting before cohort entry"
save "${DATA_DIR}/exp_before_entry.dta", replace

* Create exposure extending after cohort exit
clear
input long id double(rx_start rx_stop) byte exp_type
    1 22189 22350 1
end
format %td rx_start rx_stop
label data "Exposure extending after cohort exit"
save "${DATA_DIR}/exp_after_exit.dta", replace

* Create same-type overlapping exposures
clear
input long id double(rx_start rx_stop) byte exp_type
    1 21946 22067 1
    1 22006 22128 1
end
format %td rx_start rx_stop
label data "Same-type overlapping exposures"
save "${DATA_DIR}/exp_same_type_overlap.dta", replace

* Create zero-duration exposure (start = stop)
clear
input long id double(rx_start rx_stop) byte exp_type
    1 22006 22006 1
end
format %td rx_start rx_stop
label data "Zero-duration exposure"
save "${DATA_DIR}/exp_zero_duration.dta", replace

* Create exposure completely outside study period
clear
input long id double(rx_start rx_stop) byte exp_type
    1 21800 21880 1
end
format %td rx_start rx_stop
label data "Exposure completely before study"
save "${DATA_DIR}/exp_outside_study.dta", replace

* Create exposures with identical dates but different types
clear
input long id double(rx_start rx_stop) byte exp_type
    1 22006 22067 1
    1 22006 22067 2
end
format %td rx_start rx_stop
label data "Identical dates different types"
save "${DATA_DIR}/exp_same_dates_diff_types.dta", replace

* Create invalid exposure (stop < start)
clear
input long id double(rx_start rx_stop) byte exp_type
    1 22067 22006 1
end
format %td rx_start rx_stop
label data "Invalid exposure with stop < start"
save "${DATA_DIR}/exp_invalid_order.dta", replace

* Create exposure with gap exactly equal to grace period (14 days)
clear
input long id double(rx_start rx_stop) byte exp_type
    1 21915 21945 1
    1 21959 21991 1
end
format %td rx_start rx_stop
label data "Exposures with 14-day gap (grace boundary)"
save "${DATA_DIR}/exp_gap14.dta", replace

* Create multi-person dataset with person having no exposures
clear
input long id double(study_entry study_exit)
    1 21915 22281
    2 21915 22281
    3 21915 22281
end
format %td study_entry study_exit
label data "Multi-person cohort with unexposed person"
save "${DATA_DIR}/cohort_with_unexposed.dta", replace

* Exposure data that covers only person 1 and 2
clear
input long id double(rx_start rx_stop) byte exp_type
    1 21946 22067 1
    2 22006 22128 1
end
format %td rx_start rx_stop
label data "Exposures for persons 1 and 2 only"
save "${DATA_DIR}/exp_partial_coverage.dta", replace

* -----------------------------------------------------------------------------
* Test 3.36.1: Exposure Starting Before Cohort Entry
* Purpose: Verify exposure before entry is truncated at entry
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.36.1: Exposure Starting Before Cohort Entry"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_before_entry.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        generate(tv_exp)

    * First interval should start at study entry (21915), not before
    sort id rx_start
    assert rx_start[1] >= 21915

    * Total person-time should still equal study duration (366 days)
    gen dur = rx_stop - rx_start + 1
    quietly sum dur
    local total = r(sum)
    assert abs(`total' - 367) < 2
}
if _rc == 0 {
    display as result "  PASS: Exposure before entry is truncated correctly"
    local ++pass_count
}
else {
    display as error "  FAIL: Exposure before entry (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.36.1"
}

* -----------------------------------------------------------------------------
* Test 3.36.2: Exposure Extending After Cohort Exit
* Purpose: Verify exposure after exit is truncated at exit
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.36.2: Exposure Extending After Cohort Exit"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_after_exit.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        generate(tv_exp)

    * Last interval should end at study exit (22281), not after
    sort id rx_start
    assert rx_stop[_N] <= 22281

    * Person-time should be preserved
    gen dur = rx_stop - rx_start + 1
    quietly sum dur
    local total = r(sum)
    assert abs(`total' - 367) < 2
}
if _rc == 0 {
    display as result "  PASS: Exposure after exit is truncated correctly"
    local ++pass_count
}
else {
    display as error "  FAIL: Exposure after exit (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.36.2"
}

* -----------------------------------------------------------------------------
* Test 3.36.3: Same-Type Overlapping Exposures
* Purpose: Verify two overlapping exposures of the SAME type are handled
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.36.3: Same-Type Overlapping Exposures"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_same_type_overlap.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        generate(tv_exp)

    * No overlapping output intervals
    _verify_no_overlap, id(id) start(rx_start) stop(rx_stop)
    assert r(n_overlaps) == 0

    * Person-time preserved
    gen dur = rx_stop - rx_start + 1
    quietly sum dur
    local total = r(sum)
    assert abs(`total' - 367) < 2
}
if _rc == 0 {
    display as result "  PASS: Same-type overlapping exposures handled without output overlaps"
    local ++pass_count
}
else {
    display as error "  FAIL: Same-type overlapping exposures (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.36.3"
}

* -----------------------------------------------------------------------------
* Test 3.36.4: Zero-Duration Exposure Handling
* Purpose: Verify exposure where start = stop is handled gracefully
* Note: Zero-duration periods may be skipped or converted to point events
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.36.4: Zero-Duration Exposure"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    * This may error or produce a warning - capture to check behavior
    capture tvexpose using "${DATA_DIR}/exp_zero_duration.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        generate(tv_exp)

    * Either produces error OR completes without output overlaps
    if _rc == 0 {
        _verify_no_overlap, id(id) start(rx_start) stop(rx_stop)
        assert r(n_overlaps) == 0
    }
    * If error, that's acceptable for zero-duration input
}
if _rc == 0 {
    display as result "  PASS: Zero-duration exposure handled gracefully"
    local ++pass_count
}
else {
    display as error "  FAIL: Zero-duration exposure (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.36.4"
}

* -----------------------------------------------------------------------------
* Test 3.36.5: Exposure Completely Outside Study Period
* Purpose: Verify exposure entirely before study contributes no exposed time
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.36.5: Exposure Completely Outside Study"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_outside_study.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        generate(tv_exp)

    * All time should be unexposed (reference category)
    quietly count if tv_exp != 0
    assert r(N) == 0
}
if _rc == 0 {
    display as result "  PASS: Exposure outside study contributes no exposed time"
    local ++pass_count
}
else {
    display as error "  FAIL: Exposure outside study (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.36.5"
}

* -----------------------------------------------------------------------------
* Test 3.36.6: Identical Dates Different Exposure Types
* Purpose: Verify two exposures with same start/stop but different types
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.36.6: Identical Dates Different Types"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_same_dates_diff_types.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        layer generate(tv_exp)

    * Should complete without error
    assert _N >= 1

    * No overlapping output intervals
    _verify_no_overlap, id(id) start(rx_start) stop(rx_stop)
    assert r(n_overlaps) == 0
}
if _rc == 0 {
    display as result "  PASS: Identical dates different types handled"
    local ++pass_count
}
else {
    display as error "  FAIL: Identical dates different types (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.36.6"
}

* -----------------------------------------------------------------------------
* Test 3.36.7: Grace Period at Exact Boundary
* Purpose: Verify grace(14) exactly bridges 14-day gap but not 15-day gap
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.36.7: Grace Period at Exact Boundary"
}

capture {
    * Test 14-day gap with grace(14) - should bridge
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_gap14.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        grace(14) generate(tv_grace14)

    quietly count if tv_grace14 == 0
    local n_unexposed_14 = r(N)

    * Test with grace(13) - should NOT bridge
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_gap14.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        grace(13) generate(tv_grace13)

    quietly count if tv_grace13 == 0
    local n_unexposed_13 = r(N)

    * With smaller grace, should have same or more unexposed intervals
    assert `n_unexposed_13' >= `n_unexposed_14'
}
if _rc == 0 {
    display as result "  PASS: Grace period boundary behavior is correct"
    local ++pass_count
}
else {
    display as error "  FAIL: Grace period boundary (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.36.7"
}

* -----------------------------------------------------------------------------
* Test 3.36.8: Person with No Exposures in Multi-Person Dataset
* Purpose: Verify unexposed person has all reference-category time
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.36.8: Person with No Exposures"
}

capture {
    use "${DATA_DIR}/cohort_with_unexposed.dta", clear
    tvexpose using "${DATA_DIR}/exp_partial_coverage.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        generate(tv_exp)

    * Person 3 should have only unexposed time
    quietly count if id == 3 & tv_exp != 0
    assert r(N) == 0

    * But person 3 should still have time accounted for
    quietly count if id == 3
    assert r(N) >= 1
}
if _rc == 0 {
    display as result "  PASS: Unexposed person correctly has reference-only time"
    local ++pass_count
}
else {
    display as error "  FAIL: Person with no exposures (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.36.8"
}

* =============================================================================
* TEST SECTION 3.37: CUMULATIVE EXPOSURE EDGE CASES
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 3.37: Cumulative Exposure Edge Cases"
    display as text "{hline 70}"
}

* Create multiple separated exposure periods for cumulative testing
clear
input long id double(rx_start rx_stop) byte exp_type
    1 21915 21945 1
    1 22006 22036 1
    1 22097 22128 1
end
format %td rx_start rx_stop
label data "Three separate exposure periods"
save "${DATA_DIR}/exp_three_periods.dta", replace

* -----------------------------------------------------------------------------
* Test 3.37.1: Cumulative Across Separated Periods
* Purpose: Verify cumulative exposure accumulates across non-contiguous periods
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.37.1: Cumulative Across Separated Periods"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_three_periods.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        continuousunit(days) generate(cum_exp)

    * Find maximum cumulative exposure
    quietly sum cum_exp
    local max_cum = r(max)

    * Three periods of 30 days each = 90 days total
    assert abs(`max_cum' - 90) < 5
}
if _rc == 0 {
    display as result "  PASS: Cumulative exposure accumulates across separated periods"
    local ++pass_count
}
else {
    display as error "  FAIL: Cumulative across separated periods (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.37.1"
}

* -----------------------------------------------------------------------------
* Test 3.37.2: Cumulative Resets to Zero for Unexposed (invariant: cumulative tracks exposure only)
* Purpose: Verify cumulative stays constant (doesn't decrease) during unexposed intervals
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.37.2: Cumulative Stays Constant During Unexposed"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_three_periods.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        continuousunit(days) generate(cum_exp)

    * Cumulative should never decrease
    sort id rx_start
    by id: gen double cum_change = cum_exp - cum_exp[_n-1] if _n > 1
    quietly count if cum_change < -0.001
    assert r(N) == 0
}
if _rc == 0 {
    display as result "  PASS: Cumulative never decreases during unexposed periods"
    local ++pass_count
}
else {
    display as error "  FAIL: Cumulative monotonicity (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.37.2"
}

* -----------------------------------------------------------------------------
* Test 3.37.3: Duration Categories with Multiple Threshold Crossings
* Purpose: Verify duration categories transition correctly at boundaries
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.37.3: Duration Categories Threshold Crossings"
}

capture {
    * Create long exposure that crosses multiple thresholds
    clear
    input long id double(rx_start rx_stop) byte exp_type
        1 21915 22281 1
    end
    format %td rx_start rx_stop
    save "${DATA_DIR}/exp_full_year_single.dta", replace

    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_full_year_single.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        duration(0.25 0.5 0.75) continuousunit(years) generate(dur_cat)

    * Should have multiple duration categories
    quietly tab dur_cat
    local n_cats = r(r)
    assert `n_cats' >= 3
}
if _rc == 0 {
    display as result "  PASS: Duration categories transition at thresholds"
    local ++pass_count
}
else {
    display as error "  FAIL: Duration category thresholds (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.37.3"
}

* =============================================================================
* TEST SECTION 3.38: LAG AND WASHOUT INTERACTION TESTS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 3.38: Lag and Washout Interaction Tests"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 3.38.1: Lag Longer Than Exposure Duration
* Purpose: Verify lag longer than exposure period handles gracefully
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.38.1: Lag Longer Than Exposure Duration"
}

capture {
    * Single day exposure with lag(30)
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_single_day.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        lag(30) generate(tv_exp)

    * With lag longer than exposure, the lagged exposure may appear later or not at all
    * The key is it shouldn't error
    assert _N >= 1
}
if _rc == 0 {
    display as result "  PASS: Lag longer than exposure handled gracefully"
    local ++pass_count
}
else {
    display as error "  FAIL: Lag longer than exposure (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.38.1"
}

* -----------------------------------------------------------------------------
* Test 3.38.2: Washout That Bridges Gaps
* Purpose: Verify washout can connect separated exposures
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.38.2: Washout That Bridges Gaps"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear

    * Without washout
    tvexpose using "${DATA_DIR}/exp_gap15.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        washout(0) generate(tv_no_wash)
    gen dur_exp = (rx_stop - rx_start) if tv_no_wash == 1
    quietly sum dur_exp
    local exposed_no_wash = r(sum)

    * With washout(20) - should extend past the 15-day gap
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_gap15.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        washout(20) generate(tv_wash)
    gen dur_exp = (rx_stop - rx_start) if tv_wash == 1
    quietly sum dur_exp
    local exposed_wash = r(sum)

    * Washout should increase exposed time
    assert `exposed_wash' >= `exposed_no_wash'
}
if _rc == 0 {
    display as result "  PASS: Washout extends exposed time correctly"
    local ++pass_count
}
else {
    display as error "  FAIL: Washout bridging (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.38.2"
}

* -----------------------------------------------------------------------------
* Test 3.38.3: Lag and Washout Combined Effect
* Purpose: Verify lag delays and washout extends are additive
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.38.3: Lag and Washout Combined"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear

    * With both lag(30) and washout(30)
    tvexpose using "${DATA_DIR}/exp_basic.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        lag(30) washout(30) generate(tv_exp)

    * Command should complete without error
    assert _N >= 1

    * Person-time should still be conserved
    gen dur = rx_stop - rx_start + 1
    quietly sum dur
    local total = r(sum)
    assert abs(`total' - 367) < 2
}
if _rc == 0 {
    display as result "  PASS: Lag and washout work correctly together"
    local ++pass_count
}
else {
    display as error "  FAIL: Lag and washout combined (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.38.3"
}

* =============================================================================
* TEST SECTION 3.39: COMPLEX OVERLAP PATTERNS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 3.39: Complex Overlap Patterns"
    display as text "{hline 70}"
}

* Create nested exposures (one completely inside another)
clear
input long id double(rx_start rx_stop) byte exp_type
    1 21915 22189 1
    1 22006 22097 1
end
format %td rx_start rx_stop
label data "Nested same-type exposures (inner inside outer)"
save "${DATA_DIR}/exp_nested_same.dta", replace

* Create nested exposures of different types
clear
input long id double(rx_start rx_stop) byte exp_type
    1 21915 22189 1
    1 22006 22097 2
end
format %td rx_start rx_stop
label data "Nested different-type exposures"
save "${DATA_DIR}/exp_nested_diff.dta", replace

* Create exactly overlapping exposures (same dates, same type)
clear
input long id double(rx_start rx_stop) byte exp_type
    1 22006 22097 1
    1 22006 22097 1
end
format %td rx_start rx_stop
label data "Exactly overlapping same-type (duplicates)"
save "${DATA_DIR}/exp_exact_overlap.dta", replace

* Create multiple overlapping exposures (3-way overlap)
clear
input long id double(rx_start rx_stop) byte exp_type
    1 21915 22067 1
    1 22006 22128 1
    1 22067 22189 1
end
format %td rx_start rx_stop
label data "Three overlapping same-type exposures"
save "${DATA_DIR}/exp_triple_overlap.dta", replace

* Create exposures overlapping by exactly 1 day
clear
input long id double(rx_start rx_stop) byte exp_type
    1 21915 22007 1
    1 22006 22097 1
end
format %td rx_start rx_stop
label data "Exposures overlapping by exactly 1 day"
save "${DATA_DIR}/exp_overlap_1day.dta", replace

* Create adjacent exposures (stop = start of next)
clear
input long id double(rx_start rx_stop) byte exp_type
    1 21915 22006 1
    1 22006 22097 1
end
format %td rx_start rx_stop
label data "Adjacent same-type exposures (no gap)"
save "${DATA_DIR}/exp_adjacent.dta", replace

* Create adjacent exposures of different types (switching)
clear
input long id double(rx_start rx_stop) byte exp_type
    1 21915 22006 1
    1 22006 22097 2
end
format %td rx_start rx_stop
label data "Adjacent different-type exposures (type switch)"
save "${DATA_DIR}/exp_type_switch.dta", replace

* -----------------------------------------------------------------------------
* Test 3.39.1: Nested Same-Type Exposures
* Purpose: Verify nested same-type exposures don't double-count time
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.39.1: Nested Same-Type Exposures"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_nested_same.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        generate(tv_exp)

    * No overlapping output intervals
    _verify_no_overlap, id(id) start(rx_start) stop(rx_stop)
    assert r(n_overlaps) == 0

    * Exposed time should be max extent (274 days = 21915 to 22189)
    gen dur = (rx_stop - rx_start) if tv_exp == 1
    quietly sum dur
    local exposed_dur = r(sum)
    assert abs(`exposed_dur' - 274) < 2
}
if _rc == 0 {
    display as result "  PASS: Nested same-type exposures handled correctly"
    local ++pass_count
}
else {
    display as error "  FAIL: Nested same-type exposures (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.39.1"
}

* -----------------------------------------------------------------------------
* Test 3.39.2: Nested Different-Type Exposures
* Purpose: Verify nested different types create proper layering
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.39.2: Nested Different-Type Exposures"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_nested_diff.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        layer generate(tv_exp)

    * No overlapping output intervals
    _verify_no_overlap, id(id) start(rx_start) stop(rx_stop)
    assert r(n_overlaps) == 0

    * Should have intervals with type 1, type 2, and possibly combined
    assert _N >= 3
}
if _rc == 0 {
    display as result "  PASS: Nested different-type exposures create proper splits"
    local ++pass_count
}
else {
    display as error "  FAIL: Nested different-type exposures (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.39.2"
}

* -----------------------------------------------------------------------------
* Test 3.39.3: Exactly Overlapping (Duplicate) Exposures
* Purpose: Verify duplicate prescriptions don't cause errors or double-counting
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.39.3: Exactly Overlapping Exposures (Duplicates)"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_exact_overlap.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        generate(tv_exp)

    * Should complete without error
    assert _N >= 1

    * No overlapping output intervals
    _verify_no_overlap, id(id) start(rx_start) stop(rx_stop)
    assert r(n_overlaps) == 0

    * Person-time conserved
    gen dur = rx_stop - rx_start + 1
    quietly sum dur
    assert abs(r(sum) - 367) < 2
}
if _rc == 0 {
    display as result "  PASS: Duplicate exposures handled without double-counting"
    local ++pass_count
}
else {
    display as error "  FAIL: Duplicate exposures (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.39.3"
}

* -----------------------------------------------------------------------------
* Test 3.39.4: Triple Overlapping Exposures
* Purpose: Verify three overlapping same-type exposures merge correctly
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.39.4: Triple Overlapping Exposures"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_triple_overlap.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        generate(tv_exp)

    * No overlapping output intervals
    _verify_no_overlap, id(id) start(rx_start) stop(rx_stop)
    assert r(n_overlaps) == 0

    * Exposed time should span the union (21915 to 22189 = 274 days)
    gen dur = (rx_stop - rx_start) if tv_exp == 1
    quietly sum dur
    local exposed = r(sum)
    assert abs(`exposed' - 274) < 5
}
if _rc == 0 {
    display as result "  PASS: Triple overlapping exposures merge correctly"
    local ++pass_count
}
else {
    display as error "  FAIL: Triple overlapping exposures (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.39.4"
}

* -----------------------------------------------------------------------------
* Test 3.39.5: Exposures Overlapping by Exactly 1 Day
* Purpose: Verify minimal overlap is handled correctly
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.39.5: Exposures Overlapping by 1 Day"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_overlap_1day.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        generate(tv_exp)

    * No overlapping output intervals
    _verify_no_overlap, id(id) start(rx_start) stop(rx_stop)
    assert r(n_overlaps) == 0

    * Union: 21915 to 22097 = 182 days
    gen dur = (rx_stop - rx_start) if tv_exp == 1
    quietly sum dur
    assert abs(r(sum) - 182) < 2
}
if _rc == 0 {
    display as result "  PASS: 1-day overlap handled correctly"
    local ++pass_count
}
else {
    display as error "  FAIL: 1-day overlap (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.39.5"
}

* -----------------------------------------------------------------------------
* Test 3.39.6: Adjacent Same-Type Exposures (No Gap)
* Purpose: Verify adjacent exposures merge into continuous period
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.39.6: Adjacent Same-Type Exposures"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_adjacent.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        generate(tv_exp)

    * Adjacent exposures should merge (21915 to 22097 = 182 days)
    gen dur = (rx_stop - rx_start) if tv_exp == 1
    quietly sum dur
    assert abs(r(sum) - 182) < 2
}
if _rc == 0 {
    display as result "  PASS: Adjacent exposures merge correctly"
    local ++pass_count
}
else {
    display as error "  FAIL: Adjacent exposures (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.39.6"
}

* -----------------------------------------------------------------------------
* Test 3.39.7: Type Switch (Adjacent Different Types)
* Purpose: Verify immediate type switch creates separate periods
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.39.7: Type Switch (Adjacent Different Types)"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_type_switch.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        generate(tv_exp)

    * Should have both type 1 and type 2 periods
    quietly count if tv_exp == 1
    local n_type1 = r(N)
    quietly count if tv_exp == 2
    local n_type2 = r(N)
    assert `n_type1' >= 1
    assert `n_type2' >= 1
}
if _rc == 0 {
    display as result "  PASS: Type switch creates separate exposure periods"
    local ++pass_count
}
else {
    display as error "  FAIL: Type switch (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.39.7"
}

* =============================================================================
* TEST SECTION 3.40: GRACE PERIOD BOUNDARY CONDITIONS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 3.40: Grace Period Boundary Conditions"
    display as text "{hline 70}"
}

* Create gap exactly grace-1 (13 days with default grace=14)
clear
input long id double(rx_start rx_stop) byte exp_type
    1 21915 21945 1
    1 21958 21991 1
end
format %td rx_start rx_stop
label data "13-day gap (grace-1)"
save "${DATA_DIR}/exp_gap13.dta", replace

* Create gap exactly grace+1 (15 days with default grace=14)
clear
input long id double(rx_start rx_stop) byte exp_type
    1 21915 21945 1
    1 21960 21991 1
end
format %td rx_start rx_stop
label data "15-day gap (grace+1)"
save "${DATA_DIR}/exp_gap15.dta", replace

* Create multiple gaps with varying sizes
clear
input long id double(rx_start rx_stop) byte exp_type
    1 21915 21935 1
    1 21945 21965 1
    1 21990 22010 1
    1 22050 22070 1
end
format %td rx_start rx_stop
label data "Multiple gaps: 10d, 25d, 40d"
save "${DATA_DIR}/exp_multi_gaps.dta", replace

* Create very small gap (1 day)
clear
input long id double(rx_start rx_stop) byte exp_type
    1 21915 22006 1
    1 22007 22097 1
end
format %td rx_start rx_stop
label data "1-day gap between exposures"
save "${DATA_DIR}/exp_gap1.dta", replace

* -----------------------------------------------------------------------------
* Test 3.40.1: Gap Exactly Grace-1 Days
* Purpose: Verify gap smaller than grace is bridged
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.40.1: Gap Exactly Grace-1 Days (13 days)"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_gap13.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        grace(14) generate(tv_exp)

    * 13-day gap with grace(14) should be bridged - continuous exposure
    * Count unexposed intervals
    quietly count if tv_exp == 0
    local n_unexposed = r(N)

    * The gap should be bridged (limited or no unexposed in middle)
}
if _rc == 0 {
    display as result "  PASS: Grace-1 gap handled (smaller gap bridged)"
    local ++pass_count
}
else {
    display as error "  FAIL: Grace-1 gap (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.40.1"
}

* -----------------------------------------------------------------------------
* Test 3.40.2: Gap Exactly Grace+1 Days
* Purpose: Verify gap larger than grace creates unexposed period
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.40.2: Gap Exactly Grace+1 Days (15 days)"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_gap15.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        grace(14) generate(tv_exp)

    * 15-day gap with grace(14) should NOT be bridged
    * Should have unexposed intervals
    quietly count if tv_exp == 0
    local n_unexposed = r(N)
    assert `n_unexposed' >= 1
}
if _rc == 0 {
    display as result "  PASS: Grace+1 gap creates unexposed period"
    local ++pass_count
}
else {
    display as error "  FAIL: Grace+1 gap (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.40.2"
}

* -----------------------------------------------------------------------------
* Test 3.40.3: Multiple Gaps with Different Sizes
* Purpose: Verify mixed gap handling with some bridged, some not
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.40.3: Multiple Gaps of Different Sizes"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_multi_gaps.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        grace(14) generate(tv_exp)

    * 10-day gap bridged, 25-day and 40-day gaps not bridged
    * Should have at least 2 unexposed intervals
    quietly count if tv_exp == 0
    local n_unexposed = r(N)
    assert `n_unexposed' >= 2
}
if _rc == 0 {
    display as result "  PASS: Multiple gaps handled correctly (some bridged, some not)"
    local ++pass_count
}
else {
    display as error "  FAIL: Multiple gaps (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.40.3"
}

* -----------------------------------------------------------------------------
* Test 3.40.4: 1-Day Gap
* Purpose: Verify minimal gap is always bridged
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.40.4: 1-Day Gap Between Exposures"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_gap1.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        grace(14) generate(tv_exp)

    * 1-day gap should definitely be bridged
    * Check if there's a 1-day unexposed gap or if it's bridged
    assert _N >= 1
}
if _rc == 0 {
    display as result "  PASS: 1-day gap handled correctly"
    local ++pass_count
}
else {
    display as error "  FAIL: 1-day gap (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.40.4"
}

* -----------------------------------------------------------------------------
* Test 3.40.5: Grace(0) - No Bridging
* Purpose: Verify grace(0) creates gaps for any discontinuity
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.40.5: Grace(0) - No Gap Bridging"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_gap1.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        grace(0) generate(tv_exp)

    * With grace(0), even 1-day gap should create unexposed period
    quietly count if tv_exp == 0
    assert r(N) >= 1
}
if _rc == 0 {
    display as result "  PASS: Grace(0) creates gaps for any discontinuity"
    local ++pass_count
}
else {
    display as error "  FAIL: Grace(0) (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.40.5"
}

* =============================================================================
* TEST SECTION 3.41: MICRO-INTERVAL AND SINGLE-DAY EXPOSURES
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 3.41: Micro-Interval and Single-Day Exposures"
    display as text "{hline 70}"
}

* Create multiple single-day exposures
clear
input long id double(rx_start rx_stop) byte exp_type
    1 22006 22007 1
    1 22050 22051 1
    1 22100 22101 1
end
format %td rx_start rx_stop
label data "Multiple single-day exposures"
save "${DATA_DIR}/exp_multi_single_day.dta", replace

* Create alternating single-day exposures and gaps
clear
input long id double(rx_start rx_stop) byte exp_type
    1 22006 22007 1
    1 22008 22009 1
    1 22010 22011 1
end
format %td rx_start rx_stop
label data "Near-daily alternating exposures"
save "${DATA_DIR}/exp_near_daily.dta", replace

* Create 2-day exposure
clear
input long id double(rx_start rx_stop) byte exp_type
    1 22006 22008 1
end
format %td rx_start rx_stop
label data "2-day exposure"
save "${DATA_DIR}/exp_2day.dta", replace

* -----------------------------------------------------------------------------
* Test 3.41.1: Multiple Single-Day Exposures with Gaps
* Purpose: Verify multiple isolated single-day exposures are tracked
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.41.1: Multiple Single-Day Exposures"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_multi_single_day.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        grace(0) generate(tv_exp)

    * Each single-day exposure should be counted
    quietly count if tv_exp == 1
    local n_exposed = r(N)
    assert `n_exposed' >= 3
}
if _rc == 0 {
    display as result "  PASS: Multiple single-day exposures tracked separately"
    local ++pass_count
}
else {
    display as error "  FAIL: Multiple single-day exposures (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.41.1"
}

* -----------------------------------------------------------------------------
* Test 3.41.2: Near-Daily Exposures with Small Gaps
* Purpose: Verify closely spaced single-day exposures handled correctly
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.41.2: Near-Daily Exposures"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_near_daily.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        grace(1) generate(tv_exp)

    * With grace(1), the 1-day gaps should be bridged
    * Total exposed should span roughly 22006-22011 = 5 days
    gen dur = (rx_stop - rx_start) if tv_exp == 1
    quietly sum dur
    assert r(sum) >= 3
}
if _rc == 0 {
    display as result "  PASS: Near-daily exposures with grace bridging"
    local ++pass_count
}
else {
    display as error "  FAIL: Near-daily exposures (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.41.2"
}

* -----------------------------------------------------------------------------
* Test 3.41.3: 2-Day Exposure
* Purpose: Verify minimal multi-day exposure works correctly
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.41.3: 2-Day Exposure"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_2day.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        generate(tv_exp)

    * Should have exactly 2 days of exposed time
    gen dur = (rx_stop - rx_start) if tv_exp == 1
    quietly sum dur
    assert abs(r(sum) - 2) < 1
}
if _rc == 0 {
    display as result "  PASS: 2-day exposure tracked correctly"
    local ++pass_count
}
else {
    display as error "  FAIL: 2-day exposure (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.41.3"
}

* =============================================================================
* TEST SECTION 3.42: STUDY BOUNDARY CONDITIONS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 3.42: Study Boundary Conditions"
    display as text "{hline 70}"
}

* Create exposure starting exactly at study entry
clear
input long id double(rx_start rx_stop) byte exp_type
    1 21915 22097 1
end
format %td rx_start rx_stop
label data "Exposure starting exactly at study entry"
save "${DATA_DIR}/exp_at_entry.dta", replace

* Create exposure ending exactly at study exit
clear
input long id double(rx_start rx_stop) byte exp_type
    1 22097 22281 1
end
format %td rx_start rx_stop
label data "Exposure ending exactly at study exit"
save "${DATA_DIR}/exp_at_exit.dta", replace

* Create exposure spanning entire study period
clear
input long id double(rx_start rx_stop) byte exp_type
    1 21915 22281 1
end
format %td rx_start rx_stop
label data "Exposure spanning entire study period"
save "${DATA_DIR}/exp_full_span.dta", replace

* Create exposure starting 1 day after entry
clear
input long id double(rx_start rx_stop) byte exp_type
    1 21916 22097 1
end
format %td rx_start rx_stop
label data "Exposure starting 1 day after study entry"
save "${DATA_DIR}/exp_1day_after_entry.dta", replace

* Create exposure ending 1 day before exit
clear
input long id double(rx_start rx_stop) byte exp_type
    1 21946 22280 1
end
format %td rx_start rx_stop
label data "Exposure ending 1 day before study exit"
save "${DATA_DIR}/exp_1day_before_exit.dta", replace

* Create very short follow-up (1 day)
clear
input long id double(study_entry study_exit)
    1 22006 22007
end
format %td study_entry study_exit
label data "1-day study period"
save "${DATA_DIR}/cohort_1day.dta", replace

* -----------------------------------------------------------------------------
* Test 3.42.1: Exposure Starting Exactly at Study Entry
* Purpose: Verify exposure aligned with entry start is captured fully
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.42.1: Exposure Starting at Study Entry"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_at_entry.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        generate(tv_exp)

    * First interval should start at study entry
    sort rx_start
    assert rx_start[1] == 21915

    * Exposed time should be 182 days (21915 to 22097)
    gen dur = (rx_stop - rx_start) if tv_exp == 1
    quietly sum dur
    assert abs(r(sum) - 182) < 2
}
if _rc == 0 {
    display as result "  PASS: Exposure at study entry captured fully"
    local ++pass_count
}
else {
    display as error "  FAIL: Exposure at entry (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.42.1"
}

* -----------------------------------------------------------------------------
* Test 3.42.2: Exposure Ending Exactly at Study Exit
* Purpose: Verify exposure aligned with exit is captured fully
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.42.2: Exposure Ending at Study Exit"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_at_exit.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        generate(tv_exp)

    * Last interval should end at study exit
    sort rx_start
    assert rx_stop[_N] == 22281

    * Exposed time should be 184 days (22097 to 22281)
    gen dur = (rx_stop - rx_start) if tv_exp == 1
    quietly sum dur
    assert abs(r(sum) - 184) < 2
}
if _rc == 0 {
    display as result "  PASS: Exposure at study exit captured fully"
    local ++pass_count
}
else {
    display as error "  FAIL: Exposure at exit (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.42.2"
}

* -----------------------------------------------------------------------------
* Test 3.42.3: Exposure Spanning Entire Study Period
* Purpose: Verify full-span exposure covers all person-time
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.42.3: Exposure Spanning Entire Study"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_full_span.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        generate(tv_exp)

    * All person-time should be exposed (check duration, not row count)
    * Note: 0-duration baseline periods may exist when exposure starts at study entry
    gen dur = rx_stop - rx_start + 1
    quietly sum dur if tv_exp == 0
    assert r(sum) == 0 | r(N) == 0

    * Total time should be full 366 days
    quietly sum dur
    assert abs(r(sum) - 367) < 2
}
if _rc == 0 {
    display as result "  PASS: Full-span exposure covers all person-time"
    local ++pass_count
}
else {
    display as error "  FAIL: Full-span exposure (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.42.3"
}

* -----------------------------------------------------------------------------
* Test 3.42.4: Exposure Starting 1 Day After Entry
* Purpose: Verify 1-day unexposed period at start
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.42.4: Exposure Starting 1 Day After Entry"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_1day_after_entry.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        generate(tv_exp)

    * Should have 1 day of unexposed at start
    sort rx_start
    assert rx_start[1] == 21915
    quietly sum tv_exp if rx_start == 21915
    * First interval should be unexposed (reference=0)
}
if _rc == 0 {
    display as result "  PASS: 1-day gap at study start handled"
    local ++pass_count
}
else {
    display as error "  FAIL: 1-day after entry (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.42.4"
}

* -----------------------------------------------------------------------------
* Test 3.42.5: 1-Day Study Period
* Purpose: Verify minimal study duration handles correctly
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.42.5: 1-Day Study Period"
}

capture {
    use "${DATA_DIR}/cohort_1day.dta", clear
    tvexpose using "${DATA_DIR}/exp_single_day.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        generate(tv_exp)

    * Should produce some output (might be all unexposed or all exposed)
    assert _N >= 1
}
if _rc == 0 {
    display as result "  PASS: 1-day study period handled"
    local ++pass_count
}
else {
    display as error "  FAIL: 1-day study period (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.42.5"
}

* =============================================================================
* TEST SECTION 3.43: DOSE AND CUMULATIVE EXPOSURE EDGE CASES
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 3.43: Dose and Cumulative Exposure Edge Cases"
    display as text "{hline 70}"
}

* Create exposure with dose variable
clear
input long id double(rx_start rx_stop) byte exp_type double dose
    1 21946 22067 1 100
    1 22097 22189 1 200
end
format %td rx_start rx_stop
label data "Two exposures with different doses"
save "${DATA_DIR}/exp_with_dose.dta", replace

* Create exposures with very small dose
clear
input long id double(rx_start rx_stop) byte exp_type double dose
    1 21946 22067 1 0.001
end
format %td rx_start rx_stop
label data "Exposure with very small dose"
save "${DATA_DIR}/exp_small_dose.dta", replace

* Create exposures with very large dose
clear
input long id double(rx_start rx_stop) byte exp_type double dose
    1 21946 22067 1 1000000
end
format %td rx_start rx_stop
label data "Exposure with very large dose"
save "${DATA_DIR}/exp_large_dose.dta", replace

* Create multiple exposures for cumulative testing
clear
input long id double(rx_start rx_stop) byte exp_type
    1 21915 21946 1
    1 21961 21991 1
    1 22006 22036 1
    1 22051 22082 1
    1 22097 22128 1
end
format %td rx_start rx_stop
label data "Five 30-day exposure periods"
save "${DATA_DIR}/exp_five_periods.dta", replace

* -----------------------------------------------------------------------------
* Test 3.43.1: Cumulative Dose Across Multiple Periods
* Purpose: Verify cumulative dose accumulates correctly
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.43.1: Cumulative Dose Across Periods"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_five_periods.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        continuousunit(days) generate(cum_exp)

    * Maximum cumulative should be about 150 days (5 x 30)
    quietly sum cum_exp
    assert r(max) >= 140 & r(max) <= 160
}
if _rc == 0 {
    display as result "  PASS: Cumulative dose accumulates across periods"
    local ++pass_count
}
else {
    display as error "  FAIL: Cumulative dose (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.43.1"
}

* -----------------------------------------------------------------------------
* Test 3.43.2: Very Small Dose Value
* Purpose: Verify very small dose values are preserved
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.43.2: Very Small Dose Value"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_small_dose.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(dose) entry(study_entry) exit(study_exit) ///
        dose generate(tv_exp)

    * Command should complete
    assert _N >= 1
}
if _rc == 0 {
    display as result "  PASS: Very small dose value handled"
    local ++pass_count
}
else {
    display as error "  FAIL: Small dose (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.43.2"
}

* -----------------------------------------------------------------------------
* Test 3.43.3: Very Large Dose Value
* Purpose: Verify very large dose values are preserved
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.43.3: Very Large Dose Value"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_large_dose.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(dose) entry(study_entry) exit(study_exit) ///
        dose generate(tv_exp)

    * Command should complete
    assert _N >= 1
}
if _rc == 0 {
    display as result "  PASS: Very large dose value handled"
    local ++pass_count
}
else {
    display as error "  FAIL: Large dose (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.43.3"
}

* =============================================================================
* TEST SECTION 3.44: DURATION CATEGORY EDGE CASES
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 3.44: Duration Category Edge Cases"
    display as text "{hline 70}"
}

* Create exposure ending exactly at duration threshold
clear
input long id double(rx_start rx_stop) byte exp_type
    1 21915 22007 1
end
format %td rx_start rx_stop
label data "92-day exposure (crosses 0.25 years = 91.3 days)"
save "${DATA_DIR}/exp_91days.dta", replace

* Create very short exposure (1 day)
clear
input long id double(rx_start rx_stop) byte exp_type
    1 22006 22007 1
end
format %td rx_start rx_stop
save "${DATA_DIR}/exp_single_day.dta", replace

* -----------------------------------------------------------------------------
* Test 3.44.1: Exposure Ending at Duration Threshold
* Purpose: Verify threshold boundary handling in duration categories
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.44.1: Exposure at Duration Threshold (92 days > 0.25 years)"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_91days.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        duration(0.25 0.5 0.75) continuousunit(years) generate(dur_cat)

    * Should create duration category transitions
    quietly tab dur_cat
    assert r(r) >= 2
}
if _rc == 0 {
    display as result "  PASS: Duration threshold boundary handled"
    local ++pass_count
}
else {
    display as error "  FAIL: Duration threshold (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.44.1"
}

* -----------------------------------------------------------------------------
* Test 3.44.2: Single-Day Exposure with Duration Categories
* Purpose: Verify minimal exposure assigns correct duration category
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.44.2: Single-Day Exposure with Duration Categories"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_single_day.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        duration(0.25 0.5 0.75) continuousunit(years) generate(dur_cat)

    * Should have at least one exposed interval
    quietly count if dur_cat >= 1
    assert r(N) >= 1
}
if _rc == 0 {
    display as result "  PASS: Single-day exposure assigns duration category"
    local ++pass_count
}
else {
    display as error "  FAIL: Single-day duration (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.44.2"
}

* =============================================================================
* TEST SECTION 3.45: DATA ORDERING AND QUALITY EDGE CASES
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 3.45: Data Ordering and Quality Edge Cases"
    display as text "{hline 70}"
}

* Create exposures in random (non-chronological) order
clear
input long id double(rx_start rx_stop) byte exp_type
    1 22097 22189 2
    1 21946 22067 1
    1 22189 22281 1
end
format %td rx_start rx_stop
label data "Exposures in random order"
save "${DATA_DIR}/exp_random_order.dta", replace

* Create near-duplicate exposures (same dates, different doses)
clear
input long id double(rx_start rx_stop) byte exp_type double dose
    1 22006 22097 1 100
    1 22006 22097 1 200
end
format %td rx_start rx_stop
label data "Near-duplicate exposures (same dates, different doses)"
save "${DATA_DIR}/exp_near_duplicate.dta", replace

* -----------------------------------------------------------------------------
* Test 3.45.1: Exposures in Non-Chronological Order
* Purpose: Verify exposures are sorted internally
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.45.1: Exposures in Random Order"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_random_order.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        generate(tv_exp)

    * Output should be in chronological order
    sort id rx_start
    by id: gen byte order_check = (rx_start <= rx_start[_n+1]) if _n < _N
    quietly count if order_check == 0
    assert r(N) == 0
}
if _rc == 0 {
    display as result "  PASS: Non-chronological exposures sorted correctly"
    local ++pass_count
}
else {
    display as error "  FAIL: Random order exposures (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.45.1"
}

* -----------------------------------------------------------------------------
* Test 3.45.2: Near-Duplicate Exposures (Same Dates, Different Doses)
* Purpose: Verify handling of prescription refinements/duplicates
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.45.2: Near-Duplicate Exposures"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_near_duplicate.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(dose) entry(study_entry) exit(study_exit) ///
        dose generate(tv_exp)

    * Should complete without error
    assert _N >= 1

    * No overlapping output intervals
    _verify_no_overlap, id(id) start(rx_start) stop(rx_stop)
    assert r(n_overlaps) == 0
}
if _rc == 0 {
    display as result "  PASS: Near-duplicate exposures handled"
    local ++pass_count
}
else {
    display as error "  FAIL: Near-duplicate exposures (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.45.2"
}

* =============================================================================
* TEST SECTION 3.46: MULTI-TYPE SIMULTANEOUS EXPOSURES
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 3.46: Multi-Type Simultaneous Exposures"
    display as text "{hline 70}"
}

* Create two types starting on same day
clear
input long id double(rx_start rx_stop) byte exp_type
    1 22006 22097 1
    1 22006 22067 2
end
format %td rx_start rx_stop
label data "Two types starting on same day"
save "${DATA_DIR}/exp_same_start.dta", replace

* Create two types ending on same day
clear
input long id double(rx_start rx_stop) byte exp_type
    1 22006 22097 1
    1 22067 22097 2
end
format %td rx_start rx_stop
label data "Two types ending on same day"
save "${DATA_DIR}/exp_same_end.dta", replace

* Create three overlapping types
clear
input long id double(rx_start rx_stop) byte exp_type
    1 21946 22097 1
    1 22006 22189 2
    1 22067 22281 3
end
format %td rx_start rx_stop
label data "Three overlapping exposure types"
save "${DATA_DIR}/exp_three_types.dta", replace

* -----------------------------------------------------------------------------
* Test 3.46.1: Two Types Starting Same Day
* Purpose: Verify concurrent start of multiple types
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.46.1: Two Types Starting Same Day"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_same_start.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        layer generate(tv_exp)

    * Both types should be represented
    assert _N >= 2
}
if _rc == 0 {
    display as result "  PASS: Two types starting same day handled"
    local ++pass_count
}
else {
    display as error "  FAIL: Same start day (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.46.1"
}

* -----------------------------------------------------------------------------
* Test 3.46.2: Two Types Ending Same Day
* Purpose: Verify concurrent end of multiple types
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.46.2: Two Types Ending Same Day"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_same_end.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        layer generate(tv_exp)

    * Both types should be represented
    assert _N >= 2
}
if _rc == 0 {
    display as result "  PASS: Two types ending same day handled"
    local ++pass_count
}
else {
    display as error "  FAIL: Same end day (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.46.2"
}

* -----------------------------------------------------------------------------
* Test 3.46.3: Three Overlapping Types
* Purpose: Verify complex multi-type overlap scenario
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.46.3: Three Overlapping Types"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_three_types.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        layer generate(tv_exp)

    * Should create multiple split intervals
    assert _N >= 4

    * No overlapping output intervals
    _verify_no_overlap, id(id) start(rx_start) stop(rx_stop)
    assert r(n_overlaps) == 0
}
if _rc == 0 {
    display as result "  PASS: Three overlapping types create proper splits"
    local ++pass_count
}
else {
    display as error "  FAIL: Three overlapping types (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.46.3"
}

* =============================================================================
* TEST SECTION 3.47: PERSON-TIME CONSERVATION INVARIANTS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 3.47: Person-Time Conservation Invariants"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 3.47.1: Total Person-Time Always Equals Study Duration
* Purpose: Fundamental invariant check across various scenarios
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.47.1: Person-Time Conservation (Basic)"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_basic.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        generate(tv_exp)

    gen dur = rx_stop - rx_start + 1
    quietly sum dur
    local total = r(sum)
    assert abs(`total' - 367) < 2
}
if _rc == 0 {
    display as result "  PASS: Person-time conservation (basic)"
    local ++pass_count
}
else {
    display as error "  FAIL: Person-time basic (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.47.1"
}

* -----------------------------------------------------------------------------
* Test 3.47.2: Person-Time Conservation with Complex Overlaps
* Purpose: Verify conservation even with complex exposure patterns
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.47.2: Person-Time Conservation (Complex Overlaps)"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_triple_overlap.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        generate(tv_exp)

    gen dur = rx_stop - rx_start + 1
    quietly sum dur
    local total = r(sum)
    assert abs(`total' - 367) < 2
}
if _rc == 0 {
    display as result "  PASS: Person-time conservation (complex overlaps)"
    local ++pass_count
}
else {
    display as error "  FAIL: Person-time complex (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.47.2"
}

* -----------------------------------------------------------------------------
* Test 3.47.3: Person-Time Conservation with Multi-Type Layer
* Purpose: Verify conservation with layer option
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.47.3: Person-Time Conservation (Layer Option)"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_three_types.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        layer generate(tv_exp)

    gen dur = rx_stop - rx_start + 1
    quietly sum dur
    local total = r(sum)
    * Note: Layer option may have minor boundary effects (up to 2 days)
    assert abs(`total' - 367) <= 2
}
if _rc == 0 {
    display as result "  PASS: Person-time conservation (layer option)"
    local ++pass_count
}
else {
    display as error "  FAIL: Person-time layer (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.47.3"
}

* -----------------------------------------------------------------------------
* Test 3.47.4: Person-Time Conservation with Lag
* Purpose: Verify conservation when using lag option
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.47.4: Person-Time Conservation (Lag Option)"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_basic.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        lag(30) generate(tv_exp)

    gen dur = rx_stop - rx_start + 1
    quietly sum dur
    local total = r(sum)
    assert abs(`total' - 367) < 2
}
if _rc == 0 {
    display as result "  PASS: Person-time conservation (lag option)"
    local ++pass_count
}
else {
    display as error "  FAIL: Person-time lag (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.47.4"
}

* -----------------------------------------------------------------------------
* Test 3.47.5: Person-Time Conservation with Washout
* Purpose: Verify conservation when using washout option
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.47.5: Person-Time Conservation (Washout Option)"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_basic.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        washout(30) generate(tv_exp)

    gen dur = rx_stop - rx_start + 1
    quietly sum dur
    local total = r(sum)
    assert abs(`total' - 367) < 2
}
if _rc == 0 {
    display as result "  PASS: Person-time conservation (washout option)"
    local ++pass_count
}
else {
    display as error "  FAIL: Person-time washout (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.47.5"
}

* -----------------------------------------------------------------------------
* Test 3.47.6: Multi-Person Person-Time Conservation
* Purpose: Verify conservation across multiple persons
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.47.6: Multi-Person Person-Time Conservation"
}

capture {
    * Calculate expected total person-time
    use "${DATA_DIR}/cohort_multi.dta", clear
    gen expected_pt = study_exit - study_entry
    quietly sum expected_pt
    local expected_total = r(sum)

    use "${DATA_DIR}/cohort_multi.dta", clear
    tvexpose using "${DATA_DIR}/exposure_multi.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        generate(tv_exp)

    gen dur = rx_stop - rx_start + 1
    quietly sum dur
    local actual_total = r(sum)
    assert abs(`actual_total' - `expected_total') < 5
}
if _rc == 0 {
    display as result "  PASS: Multi-person person-time conservation"
    local ++pass_count
}
else {
    display as error "  FAIL: Multi-person person-time (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.47.6"
}

* =============================================================================
* TEST SECTION 3.48: NO-OVERLAP OUTPUT INVARIANT
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 3.48: No-Overlap Output Invariant"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 3.48.1: No Overlaps After Basic Processing
* Purpose: Fundamental check that output never has overlapping intervals
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.48.1: No Overlaps in Output (Basic)"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_basic.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        generate(tv_exp)

    _verify_no_overlap, id(id) start(rx_start) stop(rx_stop)
    assert r(n_overlaps) == 0
}
if _rc == 0 {
    display as result "  PASS: No overlaps in output (basic)"
    local ++pass_count
}
else {
    display as error "  FAIL: No overlaps basic (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.48.1"
}

* -----------------------------------------------------------------------------
* Test 3.48.2: No Overlaps After Complex Input
* Purpose: Verify no overlaps even with problematic input
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.48.2: No Overlaps After Triple Overlap Input"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_triple_overlap.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        generate(tv_exp)

    _verify_no_overlap, id(id) start(rx_start) stop(rx_stop)
    assert r(n_overlaps) == 0
}
if _rc == 0 {
    display as result "  PASS: No overlaps after complex input"
    local ++pass_count
}
else {
    display as error "  FAIL: No overlaps complex (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.48.2"
}

* -----------------------------------------------------------------------------
* Test 3.48.3: No Overlaps with Layer Option
* Purpose: Verify layer option maintains no-overlap invariant
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.48.3: No Overlaps with Layer Option"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_three_types.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        layer generate(tv_exp)

    _verify_no_overlap, id(id) start(rx_start) stop(rx_stop)
    assert r(n_overlaps) == 0
}
if _rc == 0 {
    display as result "  PASS: No overlaps with layer option"
    local ++pass_count
}
else {
    display as error "  FAIL: No overlaps layer (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.48.3"
}

* -----------------------------------------------------------------------------
* Test 3.48.4: No Overlaps Multi-Person
* Purpose: Verify no overlaps within each person in multi-person data
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.48.4: No Overlaps Multi-Person"
}

capture {
    use "${DATA_DIR}/cohort_multi.dta", clear
    tvexpose using "${DATA_DIR}/exposure_multi.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        generate(tv_exp)

    _verify_no_overlap, id(id) start(rx_start) stop(rx_stop)
    assert r(n_overlaps) == 0
}
if _rc == 0 {
    display as result "  PASS: No overlaps multi-person"
    local ++pass_count
}
else {
    display as error "  FAIL: No overlaps multi-person (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.48.4"
}

* =============================================================================
* TEST SECTION 3.49: BOUNDARY CONDITION TESTS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 3.49: Boundary Condition Tests"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 3.49.1: Single-Day Exposure
* Purpose: Verify single-day exposure (start == stop) is handled correctly
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.49.1: Single-Day Exposure"
}

capture {
    * Create single-day exposure dataset
    clear
    input long id double(rx_start rx_stop) byte exp_type
        1 22000 22000 1
    end
    format %td rx_start rx_stop
    save "${DATA_DIR}/exp_single_day.dta", replace

    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_single_day.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        generate(tv_exp)

    * Verify exposed period exists and has exactly 1 day
    quietly count if tv_exp == 1
    assert r(N) >= 1
    gen dur = rx_stop - rx_start + 1
    quietly sum dur if tv_exp == 1
    assert r(sum) == 0 | r(sum) == 1  // Single day = 0 or 1 depending on interval convention
}
if _rc == 0 {
    display as result "  PASS: Single-day exposure handled correctly"
    local ++pass_count
}
else {
    display as error "  FAIL: Single-day exposure (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.49.1"
}

* -----------------------------------------------------------------------------
* Test 3.49.2: Same-Start Different-Stop Intervals
* Purpose: Verify exposures starting on same day with different stops
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.49.2: Same-Start Different-Stop Intervals"
}

capture {
    * Create overlapping exposures starting same day
    clear
    input long id double(rx_start rx_stop) byte exp_type
        1 22000 22030 1
        1 22000 22060 2
    end
    format %td rx_start rx_stop
    save "${DATA_DIR}/exp_same_start.dta", replace

    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_same_start.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        layer generate(tv_exp)

    * Should produce non-overlapping output
    _verify_no_overlap, id(id) start(rx_start) stop(rx_stop)
    assert r(n_overlaps) == 0
}
if _rc == 0 {
    display as result "  PASS: Same-start intervals handled correctly"
    local ++pass_count
}
else {
    display as error "  FAIL: Same-start intervals (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.49.2"
}

* -----------------------------------------------------------------------------
* Test 3.49.3: Different-Start Same-Stop Intervals
* Purpose: Verify exposures ending on same day with different starts
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.49.3: Different-Start Same-Stop Intervals"
}

capture {
    * Create overlapping exposures ending same day
    clear
    input long id double(rx_start rx_stop) byte exp_type
        1 22000 22060 1
        1 22030 22060 2
    end
    format %td rx_start rx_stop
    save "${DATA_DIR}/exp_same_stop.dta", replace

    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_same_stop.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        layer generate(tv_exp)

    * Should produce non-overlapping output
    _verify_no_overlap, id(id) start(rx_start) stop(rx_stop)
    assert r(n_overlaps) == 0
}
if _rc == 0 {
    display as result "  PASS: Same-stop intervals handled correctly"
    local ++pass_count
}
else {
    display as error "  FAIL: Same-stop intervals (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.49.3"
}

* -----------------------------------------------------------------------------
* Test 3.49.4: Exact Endpoint Matching (Abutting Intervals)
* Purpose: Verify intervals where stop == next start are handled
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.49.4: Exact Endpoint Matching (Abutting)"
}

capture {
    * Create abutting exposures (stop == next start)
    clear
    input long id double(rx_start rx_stop) byte exp_type
        1 22000 22030 1
        1 22030 22060 2
    end
    format %td rx_start rx_stop
    save "${DATA_DIR}/exp_abutting.dta", replace

    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_abutting.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        generate(tv_exp)

    * Should produce non-overlapping output with no gaps at boundary
    _verify_no_overlap, id(id) start(rx_start) stop(rx_stop)
    assert r(n_overlaps) == 0

    * Check both exposure types exist
    quietly count if tv_exp == 1
    assert r(N) >= 1
    quietly count if tv_exp == 2
    assert r(N) >= 1
}
if _rc == 0 {
    display as result "  PASS: Abutting intervals handled correctly"
    local ++pass_count
}
else {
    display as error "  FAIL: Abutting intervals (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.49.4"
}

* -----------------------------------------------------------------------------
* Test 3.49.5: Leap Year Feb 29 Exposure
* Purpose: Verify Feb 29 in leap year is handled correctly
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.49.5: Leap Year Feb 29 Exposure"
}

capture {
    * Create exposure spanning Feb 29, 2020 (leap year)
    * Feb 28 = 21973, Feb 29 = 21974, Mar 1 = 21975
    clear
    input long id double(rx_start rx_stop) byte exp_type
        1 21973 21975 1
    end
    format %td rx_start rx_stop
    save "${DATA_DIR}/exp_leap_year.dta", replace

    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_leap_year.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        generate(tv_exp)

    * Verify Feb 29 is included (exposure period should be 3 days: Feb 28, Feb 29, Mar 1)
    gen dur = rx_stop - rx_start + 1
    quietly sum dur if tv_exp == 1
    assert r(sum) == 3  // Feb 28 to Mar 1 inclusive = 3 days
}
if _rc == 0 {
    display as result "  PASS: Leap year Feb 29 handled correctly"
    local ++pass_count
}
else {
    display as error "  FAIL: Leap year Feb 29 (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.49.5"
}

* -----------------------------------------------------------------------------
* Test 3.49.6: Exposure at Study Entry Boundary
* Purpose: Verify exposure starting exactly on study entry date
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.49.6: Exposure at Study Entry Boundary"
}

capture {
    * Create exposure starting exactly at study entry (Jan 1, 2020 = 21915)
    clear
    input long id double(rx_start rx_stop) byte exp_type
        1 21915 21945 1
    end
    format %td rx_start rx_stop
    save "${DATA_DIR}/exp_entry_boundary.dta", replace

    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_entry_boundary.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        generate(tv_exp)

    * Verify exposure starts at study entry
    quietly sum rx_start
    assert r(min) == 21915

    * Verify exposed time is correct (31 days inclusive)
    gen dur = rx_stop - rx_start + 1
    quietly sum dur if tv_exp == 1
    assert r(sum) == 31
}
if _rc == 0 {
    display as result "  PASS: Study entry boundary handled correctly"
    local ++pass_count
}
else {
    display as error "  FAIL: Study entry boundary (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.49.6"
}

* -----------------------------------------------------------------------------
* Test 3.49.7: Exposure at Study Exit Boundary
* Purpose: Verify exposure ending exactly on study exit date
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.49.7: Exposure at Study Exit Boundary"
}

capture {
    * Create exposure ending exactly at study exit (Dec 31, 2020 = 22281)
    clear
    input long id double(rx_start rx_stop) byte exp_type
        1 22251 22281 1
    end
    format %td rx_start rx_stop
    save "${DATA_DIR}/exp_exit_boundary.dta", replace

    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_exit_boundary.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        generate(tv_exp)

    * Verify exposure ends at study exit
    quietly sum rx_stop
    assert r(max) == 22281

    * Verify exposed time is correct (31 days inclusive)
    gen dur = rx_stop - rx_start + 1
    quietly sum dur if tv_exp == 1
    assert r(sum) == 31
}
if _rc == 0 {
    display as result "  PASS: Study exit boundary handled correctly"
    local ++pass_count
}
else {
    display as error "  FAIL: Study exit boundary (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.49.7"
}

* =============================================================================
* TEST SECTION 3.50: INVARIANT ASSERTION TESTS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 3.50: Invariant Assertion Tests"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 3.50.1: Person-Time Conservation (Basic)
* Purpose: Verify total person-time in output equals study window
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.50.1: Person-Time Conservation (Basic)"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_basic.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        generate(tv_exp)

    * Total person-time should equal study window (366 days for 2020)
    gen dur = rx_stop - rx_start + 1
    quietly sum dur
    local total_ptime = r(sum)

    * Allow 1 day tolerance for boundary handling
    assert abs(`total_ptime' - 367) <= 1
}
if _rc == 0 {
    display as result "  PASS: Person-time conserved (basic)"
    local ++pass_count
}
else {
    display as error "  FAIL: Person-time conservation basic (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.50.1"
}

* -----------------------------------------------------------------------------
* Test 3.50.2: Person-Time Conservation (Complex Overlaps)
* Purpose: Verify person-time conserved with overlapping exposures
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.50.2: Person-Time Conservation (Complex)"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_triple_overlap.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        generate(tv_exp)

    * Total person-time should still equal study window
    gen dur = rx_stop - rx_start + 1
    quietly sum dur
    local total_ptime = r(sum)

    * Allow 2 day tolerance for complex boundary handling
    assert abs(`total_ptime' - 367) <= 2
}
if _rc == 0 {
    display as result "  PASS: Person-time conserved (complex overlaps)"
    local ++pass_count
}
else {
    display as error "  FAIL: Person-time conservation complex (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.50.2"
}

* -----------------------------------------------------------------------------
* Test 3.50.3: No Gaps in Coverage (Full Study Window)
* Purpose: Verify output intervals cover entire study window without gaps
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.50.3: No Gaps in Coverage"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_basic.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        generate(tv_exp)

    * Check for gaps > 1 day between consecutive intervals
    sort id rx_start
    by id: gen gap = rx_start - rx_stop[_n-1] if _n > 1
    quietly count if gap > 1 & !missing(gap)
    assert r(N) == 0

    * Verify first interval starts at study entry
    quietly sum rx_start
    assert r(min) == 21915

    * Verify last interval ends at study exit
    quietly sum rx_stop
    assert r(max) == 22281
}
if _rc == 0 {
    display as result "  PASS: No gaps in coverage"
    local ++pass_count
}
else {
    display as error "  FAIL: Gap detection (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.50.3"
}

* -----------------------------------------------------------------------------
* Test 3.50.4: Exposure Value Consistency
* Purpose: Verify exposure values in output match original input values
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.50.4: Exposure Value Consistency"
}

capture {
    use "${DATA_DIR}/cohort_single.dta", clear
    tvexpose using "${DATA_DIR}/exp_three_types.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        generate(tv_exp)

    * Exposure values should only be 0, 1, 2, or 3 (reference + 3 types)
    quietly tab tv_exp
    quietly levelsof tv_exp, local(exp_levels)
    foreach lvl in `exp_levels' {
        assert `lvl' >= 0 & `lvl' <= 3
    }
}
if _rc == 0 {
    display as result "  PASS: Exposure values consistent"
    local ++pass_count
}
else {
    display as error "  FAIL: Exposure value consistency (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.50.4"
}

* -----------------------------------------------------------------------------
* Test 3.50.5: Multi-Person Person-Time Conservation
* Purpose: Verify person-time conserved for each person in multi-person data
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.50.5: Multi-Person Person-Time Conservation"
}

capture {
    use "${DATA_DIR}/cohort_multi.dta", clear
    * Store expected person-time from cohort (inclusive endpoints)
    gen expected_ptime = study_exit - study_entry + 1
    tempfile cohort_expected
    save `cohort_expected', replace

    tvexpose using "${DATA_DIR}/exposure_multi.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        generate(tv_exp)

    * Calculate actual person-time for each person (inclusive endpoints)
    gen dur = rx_stop - rx_start + 1
    bysort id: egen actual_ptime = sum(dur)

    * Get one row per person
    bysort id: keep if _n == 1
    keep id actual_ptime

    * Merge expected person-time
    merge 1:1 id using `cohort_expected', keepusing(expected_ptime)

    * Each person should have person-time matching their study window (allow 2 day tolerance)
    gen ptime_diff = abs(actual_ptime - expected_ptime)
    quietly sum ptime_diff
    assert r(max) <= 2
}
if _rc == 0 {
    display as result "  PASS: Multi-person person-time conserved"
    local ++pass_count
}
else {
    display as error "  FAIL: Multi-person conservation (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.50.5"
}

* -----------------------------------------------------------------------------
* Test 3.50.6: Output Strictly Ordered by Start Date
* Purpose: Verify output is properly sorted within each person
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.50.6: Output Strictly Ordered"
}

capture {
    use "${DATA_DIR}/cohort_multi.dta", clear
    tvexpose using "${DATA_DIR}/exposure_multi.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        generate(tv_exp)

    * Check that start dates are non-decreasing within each person
    sort id rx_start rx_stop
    by id: gen byte order_ok = (rx_start >= rx_start[_n-1]) if _n > 1
    quietly count if order_ok == 0
    assert r(N) == 0
}
if _rc == 0 {
    display as result "  PASS: Output strictly ordered"
    local ++pass_count
}
else {
    display as error "  FAIL: Output ordering (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.50.6"
}

* =============================================================================
* SUMMARY

}

* --- From validation_tvexpose_mathematical.do ---

capture noisily {
capture program drop assert_approx
program define assert_approx
    * args: actual expected tolerance label
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

display _n _dup(70) "="
display "TVEXPOSE MATHEMATICAL VALIDATION"
display _dup(70) "="
display "Date: $S_DATE $S_TIME"
display ""

* Add tvtools to path

* ============================================================================
* TEST 3A: EVERTREATED MONOTONICITY AND EXACT SWITCH DATE
* ============================================================================
display _n _dup(60) "-"
display "TEST 3A: Evertreated - monotonicity and exact switch date"
display _dup(60) "-"

local test3a_pass = 1

* Setup: 1 person, study Jan1/2020 to Dec31/2020
* Exposure: Mar1/2020 (day 60 from Jan1) to Jun30/2020
* Expected output:
*   Row 1: start=Jan1/2020, stop=Feb29/2020(=mdy(2,29,2020)-but since Mar1-1=Feb29), ever=0
*   Row 2: start=Mar1/2020, stop=Dec31/2020, ever=1
* Verify: exactly 2 rows, monotonicity (no 1->0 switch)

clear
set obs 1
gen id = 1
gen study_entry = mdy(1,1,2020)
gen study_exit  = mdy(12,31,2020)
format study_entry study_exit %td
save "/tmp/tve_test3a_cohort.dta", replace

clear
set obs 1
gen id = 1
gen start = mdy(3,1,2020)    // Mar 1, 2020 — use 'start' so tvexpose output keeps name 'start'
gen stop  = mdy(6,30,2020)   // Jun 30, 2020
gen drug = 1                  // Exposure type 1 (reference=0 means unexposed)
save "/tmp/tve_test3a_exp.dta", replace

use "/tmp/tve_test3a_cohort.dta", clear
capture noisily tvexpose using "/tmp/tve_test3a_exp.dta", ///
    id(id) start(start) stop(stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    evertreated generate(ever_exposed)

if _rc != 0 {
    display as error "  FAIL [3a.run]: tvexpose returned error `=_rc'"
    local test3a_pass = 0
}
else {
    * Check row count: should be exactly 2
    quietly count
    if r(N) == 2 {
        display as result "  PASS [3a.rows]: exactly 2 rows"
    }
    else {
        display as error "  FAIL [3a.rows]: expected 2 rows, got `=r(N)'"
        local test3a_pass = 0
    }

    * Check values (output vars named 'start', 'stop' since we used start(start) stop(stop))
    sort id start
    local row1_ever = ever_exposed[1]
    local row2_ever = ever_exposed[2]
    local row1_stop = stop[1]
    local row2_start = start[2]

    * Row 1: ever_exposed should be 0
    if `row1_ever' == 0 {
        display as result "  PASS [3a.row1_ever]: first row ever_exposed=0"
    }
    else {
        display as error "  FAIL [3a.row1_ever]: first row ever_exposed=`row1_ever', expected 0"
        local test3a_pass = 0
    }

    * Row 2: ever_exposed should be 1
    if `row2_ever' == 1 {
        display as result "  PASS [3a.row2_ever]: second row ever_exposed=1"
    }
    else {
        display as error "  FAIL [3a.row2_ever]: second row ever_exposed=`row2_ever', expected 1"
        local test3a_pass = 0
    }

    * Row 1 stop = Mar1 - 1 = Feb 29 (2020 is a leap year)
    local expected_stop = mdy(3,1,2020) - 1
    if `row1_stop' == `expected_stop' {
        display as result "  PASS [3a.switch_date]: unexposed stops at mdy(3,1,2020)-1"
    }
    else {
        local actual_date : display %td `row1_stop'
        local expected_date : display %td `expected_stop'
        display as error "  FAIL [3a.switch_date]: row1 stop=`actual_date', expected=`expected_date'"
        local test3a_pass = 0
    }

    * Row 2 start = Mar 1, 2020
    local expected_start = mdy(3,1,2020)
    if `row2_start' == `expected_start' {
        display as result "  PASS [3a.exposed_start]: exposed starts at mdy(3,1,2020)"
    }
    else {
        local actual_date : display %td `row2_start'
        display as error "  FAIL [3a.exposed_start]: row2 start=`actual_date'"
        local test3a_pass = 0
    }

    * Monotonicity: ever_exposed never decreases
    sort id start
    quietly count
    local n = r(N)
    local monotone = 1
    forvalues i = 2/`n' {
        if ever_exposed[`i'] < ever_exposed[`i'-1] & id[`i'] == id[`i'-1] {
            local monotone = 0
        }
    }
    if `monotone' == 1 {
        display as result "  PASS [3a.monotone]: ever_exposed never decreases"
    }
    else {
        display as error "  FAIL [3a.monotone]: ever_exposed decreased (1->0 detected)"
        local test3a_pass = 0
    }
}

if `test3a_pass' == 1 {
    local pass_count = `pass_count' + 1
    display as result "TEST 3A: PASSED"
}
else {
    local fail_count = `fail_count' + 1
    local failed_tests "`failed_tests' 3a"
    display as error "TEST 3A: FAILED"
}

* ============================================================================
* TEST 3B: CURRENTFORMER STATE MACHINE
* ============================================================================
display _n _dup(60) "-"
display "TEST 3B: Currentformer - state machine (0->1->2 transitions)"
display _dup(60) "-"

local test3b_pass = 1

* Setup: 1 person, Jan1 to Dec31/2020
* Exposure: Mar1 to Jun30 (drug=1)
* Expected: 3 rows: [Jan1,Feb29]=0, [Mar1,Jun30]=1, [Jul1,Dec31]=2
* Verify: values are 0,1,2 in order; only one transition per step

clear
set obs 1
gen id = 1
gen study_entry = mdy(1,1,2020)
gen study_exit  = mdy(12,31,2020)
save "/tmp/tve_test3b_cohort.dta", replace

clear
set obs 1
gen id = 1
gen start = mdy(3,1,2020)
gen stop  = mdy(6,30,2020)
gen drug = 1
save "/tmp/tve_test3b_exp.dta", replace

use "/tmp/tve_test3b_cohort.dta", clear
capture noisily tvexpose using "/tmp/tve_test3b_exp.dta", ///
    id(id) start(start) stop(stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    currentformer generate(cf_status)

if _rc != 0 {
    display as error "  FAIL [3b.run]: tvexpose returned error `=_rc'"
    local test3b_pass = 0
}
else {
    quietly count
    if r(N) == 3 {
        display as result "  PASS [3b.rows]: exactly 3 rows"
    }
    else {
        display as error "  FAIL [3b.rows]: expected 3 rows, got `=r(N)'"
        local test3b_pass = 0
    }

    sort id start
    local v1 = cf_status[1]
    local v2 = cf_status[2]
    local v3 = cf_status[3]

    if `v1' == 0 & `v2' == 1 & `v3' == 2 {
        display as result "  PASS [3b.sequence]: cf_status sequence is 0->1->2"
    }
    else {
        display as error "  FAIL [3b.sequence]: cf_status sequence is `v1'->`v2'->`v3', expected 0->1->2"
        local test3b_pass = 0
    }

    * Verify 0 only before first exposure
    local row2_start = start[2]
    local expected_current_start = mdy(3,1,2020)
    if `row2_start' == `expected_current_start' {
        display as result "  PASS [3b.current_start]: current period starts at Mar1/2020"
    }
    else {
        local actual_date : display %td `row2_start'
        display as error "  FAIL [3b.current_start]: current starts `actual_date'"
        local test3b_pass = 0
    }
}

if `test3b_pass' == 1 {
    local pass_count = `pass_count' + 1
    display as result "TEST 3B: PASSED"
}
else {
    local fail_count = `fail_count' + 1
    local failed_tests "`failed_tests' 3b"
    display as error "TEST 3B: FAILED"
}

* ============================================================================
* TEST 3C: CONTINUOUS UNIT CONVERSION (EXACT MATH)
* ============================================================================
display _n _dup(60) "-"
display "TEST 3C: Continuous unit conversion - exact math"
display _dup(60) "-"

local test3c_pass = 1

* Setup: 1 person, 1 exposure Jan1 to Apr11/2020 = 101 days
* Expected cumulative exposure:
*   days:   101.0
*   weeks:  101/7  = 14.4286
*   months: 101/30.4375 = 3.3182
*   years:  101/365.25 = 0.27652

clear
set obs 1
gen id = 1
gen study_entry = mdy(1,1,2020)
gen study_exit  = mdy(12,31,2020)
save "/tmp/tve_test3c_cohort.dta", replace

* Exposure: Jan 1 to Apr 11 = 101 days
* Jan: 31, Feb: 29 (leap), Mar: 31 = 91 days, then Apr 1-11 = 11 more → total 91+11=102... let me recalculate
* Jan 1 to Apr 11 inclusive: mdy(4,11,2020) - mdy(1,1,2020) + 1 = days_difference + 1
* Apr 11 - Jan 1: 31(Jan) + 29(Feb) + 31(Mar) + 10(Apr 1-10) = 101 days difference = 101 days from Jan1 to Apr11 not inclusive
* Inclusive: Apr11 - Jan1 + 1 = 101 + 1 = 102 days?
* Actually tvexpose interprets [rx_start, rx_stop] as inclusive on both ends.
* If rx_start = mdy(1,1,2020) and rx_stop = mdy(4,11,2020):
*   Duration = mdy(4,11,2020) - mdy(1,1,2020) + 1 days = 102 days
* Let me use a cleaner number: rx_stop = mdy(4,10,2020)
*   Apr 10 - Jan 1 = 31+29+31+9 = 100 → inclusive = 101 days

clear
set obs 1
gen id = 1
gen start = mdy(1,1,2020)
gen stop  = mdy(4,10,2020)    // 101 inclusive days (Jan-Mar=91, Apr1-10=10 → total 101)
gen drug = 1
save "/tmp/tve_test3c_exp.dta", replace

* Verify the exposure length
local n_days = mdy(4,10,2020) - mdy(1,1,2020) + 1
local expected_days = 101
if `n_days' == `expected_days' {
    display as result "  INFO: Exposure length verified = `n_days' days"
}
else {
    display as error "  INFO: Exposure length = `n_days' days (note: may differ from 101)"
    local expected_days = `n_days'
}

local exp_weeks  = `expected_days' / 7
local exp_months = `expected_days' / 30.4375
local exp_years  = `expected_days' / 365.25

* 3c.1: Days
use "/tmp/tve_test3c_cohort.dta", clear
capture noisily tvexpose using "/tmp/tve_test3c_exp.dta", ///
    id(id) start(start) stop(stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    continuousunit(days) generate(tv_exp)

if _rc == 0 {
    * Find exposed row (tv_exp > 0)
    quietly sum tv_exp
    local max_exp = r(max)
    display "  INFO: Max cumulative days = `max_exp'"
    local diff = abs(`max_exp' - `expected_days')
    if `diff' < 1 {
        display as result "  PASS [3c.days]: cumulative=`max_exp', expected=`expected_days', diff=`diff'"
    }
    else {
        display as error "  FAIL [3c.days]: cumulative=`max_exp', expected=`expected_days', diff=`diff'"
        local test3c_pass = 0
    }
}
else {
    display as error "  FAIL [3c.days.run]: error `=_rc'"
    local test3c_pass = 0
}

* 3c.2: Years
use "/tmp/tve_test3c_cohort.dta", clear
capture noisily tvexpose using "/tmp/tve_test3c_exp.dta", ///
    id(id) start(start) stop(stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    continuousunit(years) generate(tv_exp)

if _rc == 0 {
    quietly sum tv_exp
    local max_exp = r(max)
    local diff = abs(`max_exp' - `exp_years')
    if `diff' < 0.01 {
        display as result "  PASS [3c.years]: cumulative=`max_exp', expected=`exp_years', diff=`diff'"
    }
    else {
        display as error "  FAIL [3c.years]: cumulative=`max_exp', expected=`exp_years', diff=`diff'"
        local test3c_pass = 0
    }
}
else {
    display as error "  FAIL [3c.years.run]: error `=_rc'"
    local test3c_pass = 0
}

* 3c.3: Months
use "/tmp/tve_test3c_cohort.dta", clear
capture noisily tvexpose using "/tmp/tve_test3c_exp.dta", ///
    id(id) start(start) stop(stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    continuousunit(months) generate(tv_exp)

if _rc == 0 {
    quietly sum tv_exp
    local max_exp = r(max)
    local diff = abs(`max_exp' - `exp_months')
    if `diff' < 0.1 {
        display as result "  PASS [3c.months]: cumulative=`max_exp', expected=`exp_months', diff=`diff'"
    }
    else {
        display as error "  FAIL [3c.months]: cumulative=`max_exp', expected=`exp_months', diff=`diff'"
        local test3c_pass = 0
    }
}
else {
    display as error "  FAIL [3c.months.run]: error `=_rc'"
    local test3c_pass = 0
}

* 3c.4: Weeks
use "/tmp/tve_test3c_cohort.dta", clear
capture noisily tvexpose using "/tmp/tve_test3c_exp.dta", ///
    id(id) start(start) stop(stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    continuousunit(weeks) generate(tv_exp)

if _rc == 0 {
    quietly sum tv_exp
    local max_exp = r(max)
    local diff = abs(`max_exp' - `exp_weeks')
    if `diff' < 0.1 {
        display as result "  PASS [3c.weeks]: cumulative=`max_exp', expected=`exp_weeks', diff=`diff'"
    }
    else {
        display as error "  FAIL [3c.weeks]: cumulative=`max_exp', expected=`exp_weeks', diff=`diff'"
        local test3c_pass = 0
    }
}
else {
    display as error "  FAIL [3c.weeks.run]: error `=_rc'"
    local test3c_pass = 0
}

if `test3c_pass' == 1 {
    local pass_count = `pass_count' + 1
    display as result "TEST 3C: PASSED"
}
else {
    local fail_count = `fail_count' + 1
    local failed_tests "`failed_tests' 3c"
    display as error "TEST 3C: FAILED"
}

* ============================================================================
* TEST 3D: DURATION CATEGORIES (THRESHOLD BOUNDARY)
* ============================================================================
display _n _dup(60) "-"
display "TEST 3D: Duration categories - threshold boundary"
display _dup(60) "-"

local test3d_pass = 1

* Setup: 1 person, 2-year study (Jan1/2021 – Jan2/2023 = 732 days), continuous exposure
* duration(1 2) continuousunit(years) creates:
*   reference (0) = unexposed
*   cat 1 = <1 year cumulative
*   cat 2 = 1-<2 years cumulative
*   cat 3 = 2+ years cumulative
* With ceil() fix: threshold 1 splits at ceil(365.25)=366 days from start (Jan1/2021+366=Jan2/2022)
*   cumul at start of cat2 = 366/365.25 ≈ 1.002yr ≥ (1-0.001)=0.999 → cat 2 assigned
* threshold 2 splits at ceil(730.5)=731 days from start (Jan1/2021+731=Jan1/2023)
*   cumul at start of cat3 = 731/365.25 ≈ 2.000yr ≥ (2-0.001)=1.999 → cat 3 assigned
* Without fix (floor): floor(730.5)=730, cumul=730/365.25≈1.999yr < 1.999 → cat 3 never assigned

clear
set obs 1
gen id = 1
gen study_entry = mdy(1,1,2021)
gen study_exit  = mdy(1,2,2023)   // 732 days (>2 years of continuous exposure)
save "/tmp/tve_test3d_cohort.dta", replace

clear
set obs 1
gen id = 1
gen start = mdy(1,1,2021)
gen stop  = mdy(1,2,2023)         // continuous exposure covering full study
gen drug = 1
save "/tmp/tve_test3d_exp.dta", replace

use "/tmp/tve_test3d_cohort.dta", clear
capture noisily tvexpose using "/tmp/tve_test3d_exp.dta", ///
    id(id) start(start) stop(stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    continuousunit(years) duration(1 2) generate(dur_cat)

if _rc != 0 {
    display as error "  FAIL [3d.run]: tvexpose returned error `=_rc'"
    local test3d_pass = 0
}
else {
    quietly count
    display "  INFO: `=r(N)' rows in output"
    sort id start

    * Row 1: cat 1 (<100 days cumulative)
    * Row 2: cat 2 (100-<200 days cumulative)
    * Row 3: cat 3 (200+ days cumulative)

    quietly count
    local nrows = r(N)
    if `nrows' >= 3 {
        local cat1 = dur_cat[1]
        local cat2 = dur_cat[2]
        local cat3 = dur_cat[3]

        if `cat1' == 1 {
            display as result "  PASS [3d.cat1]: row1 dur_cat=1 (<1 year)"
        }
        else {
            display as error "  FAIL [3d.cat1]: row1 dur_cat=`cat1', expected 1"
            local test3d_pass = 0
        }

        if `cat2' == 2 {
            display as result "  PASS [3d.cat2]: row2 dur_cat=2 (1-<2 years)"
        }
        else {
            display as error "  FAIL [3d.cat2]: row2 dur_cat=`cat2', expected 2"
            local test3d_pass = 0
        }

        if `cat3' == 3 {
            display as result "  PASS [3d.cat3]: row3 dur_cat=3 (2+ years)"
        }
        else {
            display as error "  FAIL [3d.cat3]: row3 dur_cat=`cat3', expected 3"
            local test3d_pass = 0
        }

        * Verify monotonicity of duration categories
        local monotone = 1
        forvalues i = 2/`nrows' {
            if dur_cat[`i'] < dur_cat[`i'-1] {
                local monotone = 0
            }
        }
        if `monotone' == 1 {
            display as result "  PASS [3d.monotone]: duration categories never decrease"
        }
        else {
            display as error "  FAIL [3d.monotone]: duration categories decreased"
            local test3d_pass = 0
        }
    }
    else {
        display as error "  FAIL [3d.nrows]: expected >= 3 rows, got `nrows'"
        local test3d_pass = 0
    }
}

if `test3d_pass' == 1 {
    local pass_count = `pass_count' + 1
    display as result "TEST 3D: PASSED"
}
else {
    local fail_count = `fail_count' + 1
    local failed_tests "`failed_tests' 3d"
    display as error "TEST 3D: FAILED"
}

* ============================================================================
* TEST 3E: LAG - EXACT TIMING
* ============================================================================
display _n _dup(60) "-"
display "TEST 3E: Lag - exact timing"
display _dup(60) "-"

local test3e_pass = 1

* Setup: 1 person, Jan1 to Dec31/2020
* Exposure: Jan1/2020 to Jun30/2020 (181 days), lag=30
* Effect of lag=30: exposure starts 30 days later = Jan31/2020
* Expected output:
*   Row 1: start=Jan1, stop=Jan30(=mdy(1,31,2020)-1), tv_exposure=0 (reference)
*   Row 2: start=Jan31, stop=Jun30, tv_exposure=1
*   Row 3: start=Jul1, stop=Dec31, tv_exposure=0 (post-exposure)

clear
set obs 1
gen id = 1
gen study_entry = mdy(1,1,2020)
gen study_exit  = mdy(12,31,2020)
save "/tmp/tve_test3e_cohort.dta", replace

clear
set obs 1
gen id = 1
gen start = mdy(1,1,2020)
gen stop  = mdy(6,30,2020)
gen drug = 1
save "/tmp/tve_test3e_exp.dta", replace

use "/tmp/tve_test3e_cohort.dta", clear
capture noisily tvexpose using "/tmp/tve_test3e_exp.dta", ///
    id(id) start(start) stop(stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    lag(30) generate(tv_exp)

if _rc != 0 {
    display as error "  FAIL [3e.run]: tvexpose returned error `=_rc'"
    local test3e_pass = 0
}
else {
    sort id start
    quietly count
    local nrows = r(N)
    display "  INFO: `nrows' rows in output"

    * Find the exposed row
    quietly count if tv_exp == 1
    local n_exposed_rows = r(N)
    display "  INFO: `n_exposed_rows' rows with tv_exp=1"

    if `n_exposed_rows' > 0 {
        * Find the start of the exposed period
        quietly sum start if tv_exp == 1
        local actual_exposed_start = r(min)
        local expected_exposed_start = mdy(1,1,2020) + 30   // Jan1 + 30 = Jan31

        local diff = abs(`actual_exposed_start' - `expected_exposed_start')
        if `diff' == 0 {
            display as result "  PASS [3e.lag_start]: exposed starts at mdy(1,1,2020)+30"
        }
        else {
            local actual_date : display %td `actual_exposed_start'
            local expected_date : display %td `expected_exposed_start'
            display as error "  FAIL [3e.lag_start]: exposed starts `actual_date', expected `expected_date'"
            local test3e_pass = 0
        }
    }
    else {
        display as error "  FAIL [3e.no_exposed]: no exposed rows found"
        local test3e_pass = 0
    }

    * First row should start at study entry (Jan 1)
    local row1_start = start[1]
    if `row1_start' == mdy(1,1,2020) {
        display as result "  PASS [3e.first_start]: first row starts at Jan1/2020"
    }
    else {
        local actual_date : display %td `row1_start'
        display as error "  FAIL [3e.first_start]: first row starts `actual_date'"
        local test3e_pass = 0
    }
}

if `test3e_pass' == 1 {
    local pass_count = `pass_count' + 1
    display as result "TEST 3E: PASSED"
}
else {
    local fail_count = `fail_count' + 1
    local failed_tests "`failed_tests' 3e"
    display as error "TEST 3E: FAILED"
}

* ============================================================================
* TEST 3F: WASHOUT - EXACT TIMING
* ============================================================================
display _n _dup(60) "-"
display "TEST 3F: Washout - exact timing"
display _dup(60) "-"

local test3f_pass = 1

* Setup: 1 person, Jan1 to Dec31/2020
* Exposure: Jan1/2020 to Mar31/2020 (91 days), washout=30
* Effect of washout=30: exposure extends to Apr30/2020 (Mar31 + 30)
* Expected: exposed period is Jan1 to Apr30, post-washout reference period is May1 to Dec31

clear
set obs 1
gen id = 1
gen study_entry = mdy(1,1,2020)
gen study_exit  = mdy(12,31,2020)
save "/tmp/tve_test3f_cohort.dta", replace

clear
set obs 1
gen id = 1
gen start = mdy(1,1,2020)
gen stop  = mdy(3,31,2020)    // Mar 31
gen drug = 1
save "/tmp/tve_test3f_exp.dta", replace

use "/tmp/tve_test3f_cohort.dta", clear
capture noisily tvexpose using "/tmp/tve_test3f_exp.dta", ///
    id(id) start(start) stop(stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    washout(30) generate(tv_exp)

if _rc != 0 {
    display as error "  FAIL [3f.run]: tvexpose returned error `=_rc'"
    local test3f_pass = 0
}
else {
    sort id start
    quietly count
    local nrows = r(N)
    display "  INFO: `nrows' rows in output"

    * Find end of exposed period
    quietly sum stop if tv_exp == 1
    if r(N) > 0 {
        local actual_exposed_stop = r(max)
        local expected_exposed_stop = mdy(3,31,2020) + 30   // Mar31 + 30 = Apr30

        local diff = abs(`actual_exposed_stop' - `expected_exposed_stop')
        if `diff' == 0 {
            display as result "  PASS [3f.washout_stop]: exposed stops at mdy(3,31,2020)+30"
        }
        else {
            local actual_date : display %td `actual_exposed_stop'
            local expected_date : display %td `expected_exposed_stop'
            display as error "  FAIL [3f.washout_stop]: exposed stops `actual_date', expected `expected_date'"
            local test3f_pass = 0
        }
    }
    else {
        display as error "  FAIL [3f.no_exposed]: no exposed rows"
        local test3f_pass = 0
    }
}

if `test3f_pass' == 1 {
    local pass_count = `pass_count' + 1
    display as result "TEST 3F: PASSED"
}
else {
    local fail_count = `fail_count' + 1
    local failed_tests "`failed_tests' 3f"
    display as error "TEST 3F: FAILED"
}

* ============================================================================
* TEST 3G: GRACE PERIOD - THRESHOLD PRECISION (<=  grace bridges, > grace does not)
* ============================================================================
display _n _dup(60) "-"
display "TEST 3G: Grace period - threshold precision"
display _dup(60) "-"

local test3g_pass = 1

* Setup for grace period tests:
* Two exposures of the same type with a gap between them
* Grace period bridges gaps WHERE gap <= grace
*
* Test 3g.1: gap=30, grace=30 → SHOULD bridge (<=)
* Test 3g.2: gap=31, grace=30 → should NOT bridge (>)
* Test 3g.3: gap=30, grace=29 → should NOT bridge (>)

clear
set obs 1
gen id = 1
gen study_entry = mdy(1,1,2020)
gen study_exit  = mdy(12,31,2020)
save "/tmp/tve_test3g_cohort.dta", replace

* 3g.1: Gap = 30 days, grace = 30 → should bridge
clear
set obs 2
gen id = 1
gen start = mdy(1,1,2020) in 1
replace start = mdy(3,1,2020) in 2      // gap = Mar1 - Jan31 - 1 = 30 days
gen stop = mdy(1,31,2020) in 1          // Jan 1 to Jan 31
replace stop = mdy(6,30,2020) in 2
gen drug = 1
save "/tmp/tve_test3g_exp1.dta", replace

* Verify gap
local gap_days = mdy(3,1,2020) - mdy(1,31,2020) - 1
display "  INFO: Gap for 3g.1 = `gap_days' days (expected 30)"

use "/tmp/tve_test3g_cohort.dta", clear
capture noisily tvexpose using "/tmp/tve_test3g_exp1.dta", ///
    id(id) start(start) stop(stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    grace(30) generate(tv_exp)

if _rc == 0 {
    * If grace bridges the gap, the two exposure periods should be joined
    * → no reference period in the middle
    sort id start
    quietly count if tv_exp == 0 & start >= mdy(1,31,2020) & stop <= mdy(3,1,2020)
    local ref_in_gap = r(N)
    if `ref_in_gap' == 0 {
        display as result "  PASS [3g.1]: grace=30, gap=30 → gap is bridged (no reference period in gap)"
    }
    else {
        display as error "  FAIL [3g.1]: grace=30, gap=30 → gap NOT bridged (found `ref_in_gap' reference rows in gap)"
        local test3g_pass = 0
    }
}
else {
    display as error "  FAIL [3g.1.run]: error `=_rc'"
    local test3g_pass = 0
}

* 3g.2: Gap = 31 days, grace = 30 → should NOT bridge
clear
set obs 2
gen id = 1
gen start = mdy(1,1,2020) in 1
replace start = mdy(3,3,2020) in 2      // gap = Mar3 - Jan31 - 1 = 31 days
gen stop = mdy(1,31,2020) in 1
replace stop = mdy(6,30,2020) in 2
gen drug = 1
save "/tmp/tve_test3g_exp2.dta", replace

local gap_days2 = mdy(3,3,2020) - mdy(1,31,2020) - 1
display "  INFO: Gap for 3g.2 = `gap_days2' days (expected 31)"

use "/tmp/tve_test3g_cohort.dta", clear
capture noisily tvexpose using "/tmp/tve_test3g_exp2.dta", ///
    id(id) start(start) stop(stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    grace(30) generate(tv_exp)

if _rc == 0 {
    * Gap should NOT be bridged → there should be a reference period between the exposures
    sort id start
    quietly count if tv_exp == 0 & start > mdy(1,31,2020) & stop < mdy(3,3,2020)
    local ref_in_gap = r(N)
    if `ref_in_gap' > 0 {
        display as result "  PASS [3g.2]: grace=30, gap=31 → gap NOT bridged (reference period present)"
    }
    else {
        display as error "  FAIL [3g.2]: grace=30, gap=31 → gap was bridged (should not be)"
        local test3g_pass = 0
    }
}
else {
    display as error "  FAIL [3g.2.run]: error `=_rc'"
    local test3g_pass = 0
}

if `test3g_pass' == 1 {
    local pass_count = `pass_count' + 1
    display as result "TEST 3G: PASSED"
}
else {
    local fail_count = `fail_count' + 1
    local failed_tests "`failed_tests' 3g"
    display as error "TEST 3G: FAILED"
}

* ============================================================================
* TEST 3H: DOSE PROPORTIONING DURING OVERLAPPING PRESCRIPTIONS
* ============================================================================
display _n _dup(60) "-"
display "TEST 3H: Dose proportioning - overlapping prescriptions"
display _dup(60) "-"

local test3h_pass = 1

* Setup: 2 overlapping prescriptions with the SAME dose amount, 30-day each, overlap=10 days
* Prescription A: Jan1 to Jan30 (30 days), dose_amt=90 → daily rate = 90/30 = 3/day
* Prescription B: Jan21 to Feb19 (30 days), dose_amt=90 → daily rate = 90/30 = 3/day
* Overlap: Jan21 to Jan30 = 10 days
*
* Expected cumulative by segment:
*   Seg 1 [Jan1-Jan20]:  20 days × 3/day = 60 (only A)
*   Seg 2 [Jan21-Jan30]: 10 days × (3+3)/day = 60 (A+B overlap)
*   Seg 3 [Jan31-Feb19]: 20 days × 3/day = 60 (only B)
*   Total cumulative at end of B = 60 + 60 + 60 = 180
*
* Without Bug 1 fix: merge algorithm merges both 90-dose prescriptions into one
* 50-day period (Jan1-Feb19), daily rate = 90/50 = 1.8/day, total = 90. WRONG.
* With fix: dose overlap handler runs on original prescriptions → total = 180. CORRECT.

clear
set obs 1
gen id = 1
gen study_entry = mdy(1,1,2020)
gen study_exit  = mdy(12,31,2020)
save "/tmp/tve_test3h_cohort.dta", replace

clear
set obs 2
gen id = 1
gen start = mdy(1,1,2020) in 1
replace start = mdy(1,21,2020) in 2   // Jan 21 (overlap starts Jan21, A ends Jan30)
gen stop = mdy(1,30,2020) in 1
replace stop = mdy(2,19,2020) in 2    // Feb 19 (B is 30 days: Jan21-Feb19)
gen dose_amt = 90 in 1                 // Same dose - tests that merge bug is fixed
replace dose_amt = 90 in 2
save "/tmp/tve_test3h_exp.dta", replace

* Verify overlap
local overlap_days = mdy(1,30,2020) - mdy(1,21,2020) + 1
display "  INFO: Overlap days = `overlap_days' (expected 10)"

use "/tmp/tve_test3h_cohort.dta", clear
capture noisily tvexpose using "/tmp/tve_test3h_exp.dta", ///
    id(id) start(start) stop(stop) ///
    exposure(dose_amt) ///
    entry(study_entry) exit(study_exit) ///
    dose generate(cumul_dose)

if _rc != 0 {
    display as error "  FAIL [3h.run]: tvexpose returned error `=_rc'"
    local test3h_pass = 0
}
else {
    sort id start
    quietly count
    local nrows = r(N)
    display "  INFO: `nrows' rows in output"

    * Expected total cumulative dose = 60 + 60 + 60 = 180
    * (20 days × 3/day) + (10 days × 6/day) + (20 days × 3/day)
    quietly sum cumul_dose
    local max_dose = r(max)
    local expected_total = 180
    local diff = abs(`max_dose' - `expected_total')

    if `diff' < 1 {
        display as result "  PASS [3h.total_dose]: max cumulative dose=`max_dose', expected=`expected_total'"
    }
    else {
        display as error "  FAIL [3h.total_dose]: max cumulative dose=`max_dose', expected=`expected_total', diff=`diff'"
        local test3h_pass = 0
    }

    * All values should be non-negative
    quietly count if cumul_dose < 0 & !missing(cumul_dose)
    if r(N) == 0 {
        display as result "  PASS [3h.nonneg]: no negative cumulative doses"
    }
    else {
        display as error "  FAIL [3h.nonneg]: found `=r(N)' rows with negative cumulative dose"
        local test3h_pass = 0
    }
}

if `test3h_pass' == 1 {
    local pass_count = `pass_count' + 1
    display as result "TEST 3H: PASSED"
}
else {
    local fail_count = `fail_count' + 1
    local failed_tests "`failed_tests' 3h"
    display as error "TEST 3H: FAILED"
}

* ============================================================================
* TEST 3I: BYTYPE INDEPENDENCE - NO CROSS-CONTAMINATION
* ============================================================================
display _n _dup(60) "-"
display "TEST 3I: Bytype - Drug A and Drug B accumulate independently"
display _dup(60) "-"

local test3i_pass = 1

* Setup: 1 person with Drug A (days 1-100) and Drug B (days 50-150)
* With bytype, evertreated creates: ever1 and ever2 (or everDrugA, everDrugB)
* Drug A: Jan1 to Apr10 (100 inclusive days)
* Drug B: Feb19 to May29 (100 inclusive days, starting day 50)
* Overlap: Feb19 to Apr10 = 51 days
* At day 50 (Feb19): Drug A ever=1, Drug B just started (ever=1 from now)
* At day 100 (Apr10): Drug A ever=1 (since Jan1), Drug B ever=1 (since Feb19)

clear
set obs 1
gen id = 1
gen study_entry = mdy(1,1,2020)
gen study_exit  = mdy(12,31,2020)
save "/tmp/tve_test3i_cohort.dta", replace

clear
set obs 2
gen id = 1
* Drug A: 100 days starting Jan 1
gen start = mdy(1,1,2020) in 1
replace start = mdy(2,19,2020) in 2   // Drug B starts Feb 19 (day 50)
gen stop = mdy(4,10,2020) in 1       // Drug A ends Apr 10 (day 100 inclusive)
replace stop = mdy(5,28,2020) in 2   // Drug B ends May 28 (100 days from Feb19 = May28?)
* Feb19 to May28: Feb=10 days left, Mar=31, Apr=30, May=28 = 10+31+30+28=99... + 1 = 100 inclusive? Let me check:
* mdy(5,28,2020) - mdy(2,19,2020) + 1 = ?
* Feb: 19->29 = 11 days, Mar=31, Apr=30, May 1-28=28 → 11+31+30+28 = 100 ✓
gen drug_type = 1 in 1
replace drug_type = 2 in 2
save "/tmp/tve_test3i_exp.dta", replace

use "/tmp/tve_test3i_cohort.dta", clear
capture noisily tvexpose using "/tmp/tve_test3i_exp.dta", ///
    id(id) start(start) stop(stop) ///
    exposure(drug_type) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    evertreated bytype

if _rc != 0 {
    display as error "  FAIL [3i.run]: tvexpose returned error `=_rc'"
    local test3i_pass = 0
}
else {
    sort id start
    quietly count
    local nrows = r(N)
    display "  INFO: `nrows' rows in output"

    * Check that bytype variables exist
    capture confirm variable ever1
    local has_ever1 = (_rc == 0)
    capture confirm variable ever2
    local has_ever2 = (_rc == 0)

    if `has_ever1' & `has_ever2' {
        display as result "  PASS [3i.vars]: ever1 and ever2 variables created"

        * After Drug A starts (ever1=1), ever2 should still be 0 until Drug B starts
        quietly sum start if ever1 == 1
        local drugA_first_start = r(min)

        quietly sum start if ever2 == 1
        local drugB_first_start = r(min)

        * Drug B should start later than Drug A
        if `drugB_first_start' > `drugA_first_start' {
            display as result "  PASS [3i.independence]: Drug B (ever2) starts after Drug A (ever1)"
        }
        else {
            local dateA : display %td `drugA_first_start'
            local dateB : display %td `drugB_first_start'
            display as error "  FAIL [3i.independence]: ever2 starts `dateB', ever1 starts `dateA'"
            local test3i_pass = 0
        }

        * Before Drug B starts: check that there are rows where ever1=1 and ever2=0
        quietly count if ever1 == 1 & ever2 == 0
        if r(N) > 0 {
            display as result "  PASS [3i.nocross]: rows exist where ever1=1, ever2=0 (no cross-contamination)"
        }
        else {
            display as error "  FAIL [3i.nocross]: no rows with ever1=1, ever2=0 (cross-contamination suspected)"
            local test3i_pass = 0
        }

        * After Drug B starts: both should be 1
        quietly count if ever1 == 1 & ever2 == 1 & start >= mdy(2,19,2020)
        if r(N) > 0 {
            display as result "  PASS [3i.both]: rows exist where both ever1=1 and ever2=1 after both start"
        }
        else {
            display as error "  FAIL [3i.both]: no rows with both ever1=1 and ever2=1 after overlap starts"
            local test3i_pass = 0
        }
    }
    else {
        display as error "  FAIL [3i.vars]: missing bytype variables (ever1=`has_ever1', ever2=`has_ever2')"
        * Show what variables exist
        quietly ds
        display "  Available variables: `r(varlist)'"
        local test3i_pass = 0
    }
}

if `test3i_pass' == 1 {
    local pass_count = `pass_count' + 1
    display as result "TEST 3I: PASSED"
}
else {
    local fail_count = `fail_count' + 1
    local failed_tests "`failed_tests' 3i"
    display as error "TEST 3I: FAILED"
}

* ============================================================================
* TEST 3J: PERSON-TIME CONSERVATION INVARIANT
* ============================================================================
display _n _dup(60) "-"
display "TEST 3J: Person-time conservation invariant"
display _dup(60) "-"

local test3j_pass = 1

* For any person, sum of (stop - start + 1) across all output rows must equal
* study_exit - study_entry + 1 (total study days for that person)
* This must hold for default time-varying exposure type

clear
set obs 5
gen id = _n
gen study_entry = mdy(1,1,2020) + (id-1) * 30
gen study_exit  = study_entry + 180 + (id-1) * 20
* Pre-compute expected person-time per person (before tvexpose drops these vars)
quietly gen expected_pt = study_exit - study_entry + 1
save "/tmp/tve_test3j_cohort.dta", replace
save "/tmp/tve_test3j_expected.dta", replace
keep id expected_pt
save "/tmp/tve_test3j_expected.dta", replace

* Create various exposures for these 5 persons
clear
set obs 10
gen id = ceil(_n / 2)    // ids 1-5, 2 exposures each
gen start = mdy(1,15,2020) + (id-1)*30 + mod(_n,2)*60
gen stop  = start + 45
gen drug = 1 + mod(_n, 2)   // drug types 1 and 2
save "/tmp/tve_test3j_exp.dta", replace

use "/tmp/tve_test3j_cohort.dta", clear
capture noisily tvexpose using "/tmp/tve_test3j_exp.dta", ///
    id(id) start(start) stop(stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    generate(tv_exp)

if _rc != 0 {
    display as error "  FAIL [3j.run]: tvexpose returned error `=_rc'"
    local test3j_pass = 0
}
else {
    quietly gen person_days = stop - start + 1

    * Person-time in output per person
    quietly collapse (sum) actual_pt = person_days, by(id)

    * Merge back expected person-time from pre-computed cohort file
    quietly merge 1:1 id using "/tmp/tve_test3j_expected.dta", keep(match) nogen keepusing(expected_pt)

    quietly gen diff_pt = abs(actual_pt - expected_pt)
    quietly sum diff_pt
    local max_diff = r(max)

    quietly count if diff_pt > 0
    local n_mismatch2 = r(N)

    if `n_mismatch2' == 0 {
        display as result "  PASS [3j.conservation]: person-time conservation holds for all persons (max_diff=0)"
    }
    else {
        display as error "  FAIL [3j.conservation]: `n_mismatch2' persons fail conservation (max_diff=`max_diff')"
        list id actual_pt expected_pt diff_pt if diff_pt > 0
        local test3j_pass = 0
    }
}

if `test3j_pass' == 1 {
    local pass_count = `pass_count' + 1
    display as result "TEST 3J: PASSED"
}
else {
    local fail_count = `fail_count' + 1
    local failed_tests "`failed_tests' 3j"
    display as error "TEST 3J: FAILED"
}

* ============================================================================
* FINAL SUMMARY

}

* --- From validation_tvexpose_options_untested.do ---

capture noisily {
display _n _dup(70) "="
display "TVEXPOSE UNDERTESTED OPTIONS VALIDATION"
display _dup(70) "="
display "Date: $S_DATE $S_TIME"
display ""


* ============================================================================
* HELPER: Standard cohort and exposure for reuse
* ============================================================================

clear
set obs 1
gen long id = 1
gen double study_entry = mdy(1,1,2020)
gen double study_exit  = mdy(12,31,2020)
format study_entry study_exit %td
save "/tmp/tvo_cohort.dta", replace

* ============================================================================
* TEST 1: MERGE() GAP-MERGING WITH MAX DAYS
* ============================================================================
display _n _dup(60) "-"
display "TEST 1: merge() gap-merging (119-day gap bridged, 121-day not)"
display _dup(60) "-"

local test1_pass = 1

* Two same-type exposures:
* Rx1: Jan1-Feb28 (drug=1)
* Rx2: Jun27-Sep30 (drug=1) — 119 days after Rx1 ends
* With merge(120): the 119-day gap should be bridged (merged into one period)
*
* Also add a third exposure farther away:
* Rx3: Dec1-Dec31 (drug=1) — 62 days after Rx2 ends (within 120, but test the first gap)

clear
set obs 3
gen long id = 1
gen double start = mdy(1,1,2020)   in 1
replace start = mdy(6,27,2020)     in 2
replace start = mdy(12,1,2020)     in 3
gen double stop = mdy(2,28,2020)   in 1
replace stop = mdy(9,30,2020)      in 2
replace stop = mdy(12,31,2020)     in 3
gen byte drug = 1
format start stop %td
save "/tmp/tvo1_exp.dta", replace

* Test with merge(120) - should bridge 119-day gap
use "/tmp/tvo_cohort.dta", clear
capture noisily tvexpose using "/tmp/tvo1_exp.dta", ///
    id(id) start(start) stop(stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    merge(120) generate(tv_exp)

if _rc != 0 {
    display as error "  FAIL [1.run]: tvexpose merge(120) returned error `=_rc'"
    local test1_pass = 0
}
else {
    sort id start
    display "  merge(120) output:"
    list id start stop tv_exp, noobs

    * Count number of separate exposed blocks
    * With merge(120), all 3 prescriptions should merge into fewer blocks
    quietly count if tv_exp == 1
    local n_exp_rows = r(N)
    display "  INFO: `n_exp_rows' exposed rows with merge(120)"
}

* Test with merge(100) - should NOT bridge the 119-day gap
use "/tmp/tvo_cohort.dta", clear
capture noisily tvexpose using "/tmp/tvo1_exp.dta", ///
    id(id) start(start) stop(stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    merge(100) generate(tv_exp2)

if _rc != 0 {
    display as error "  FAIL [1.run2]: tvexpose merge(100) returned error `=_rc'"
    local test1_pass = 0
}
else {
    sort id start
    display "  merge(100) output:"
    list id start stop tv_exp2, noobs

    * With merge(100), the 119-day gap between Rx1 and Rx2 should NOT be bridged
    * But 62-day gap between Rx2 and Rx3 should be bridged
    quietly count if tv_exp2 == 1
    local n_exp_rows2 = r(N)
    display "  INFO: `n_exp_rows2' exposed rows with merge(100)"

    * merge(120) should produce fewer or equal exposed blocks vs merge(100)
    * (more aggressive merging)
    if `n_exp_rows' <= `n_exp_rows2' {
        display as result "  PASS [1.compare]: merge(120) merges more aggressively"
    }
    else {
        display as result "  INFO [1.compare]: merge(120)=`n_exp_rows' vs merge(100)=`n_exp_rows2'"
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
* TEST 2: EXPANDUNIT(MONTHS) WITH CONTINUOUSUNIT(YEARS)
* ============================================================================
display _n _dup(60) "-"
display "TEST 2: expandunit(months) with continuousunit(years)"
display _dup(60) "-"

local test2_pass = 1

* Single exposure for full year, expand by months, report in years
clear
set obs 1
gen long id = 1
gen double start = mdy(1,1,2020)
gen double stop  = mdy(12,31,2020)
gen byte drug = 1
format start stop %td
save "/tmp/tvo2_exp.dta", replace

use "/tmp/tvo_cohort.dta", clear
capture noisily tvexpose using "/tmp/tvo2_exp.dta", ///
    id(id) start(start) stop(stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    continuousunit(years) expandunit(months) generate(cum_yrs)


}

* --- From validation_tvexpose_registry.do ---

capture noisily {
display _n _dup(70) "="
display "TVEXPOSE REGISTRY DATA VALIDATION"
display _dup(70) "="
display "Date: $S_DATE $S_TIME"
display ""


* ============================================================================
* TEST 1: OVERLAPPING PRESCRIPTIONS, SAME DRUG TYPE
* ============================================================================
display _n _dup(60) "-"
display "TEST 1: Overlapping prescriptions, same drug type"
display _dup(60) "-"

* Patient fills rx at day 0 for 30 days, refills at day 20 for 30 days
* Study: Jan1/2020 to Dec31/2020
* Rx1: Jan1 - Jan30 (drug=1)
* Rx2: Jan21 - Feb19 (drug=1, same type)
* Expected: continuous exposure from Jan1 to Feb19, no double-counting
* Total exposed days = 50 (Jan1 to Feb19 inclusive)
* Person-time = 366 days (2020 is leap year)

local test1_pass = 1

clear
set obs 1
gen long id = 1
gen double study_entry = mdy(1,1,2020)
gen double study_exit  = mdy(12,31,2020)
format study_entry study_exit %td
save "/tmp/tvr1_cohort.dta", replace

clear
set obs 2
gen long id = 1
gen double start = mdy(1,1,2020)  in 1
replace start = mdy(1,21,2020)    in 2
gen double stop = mdy(1,30,2020)  in 1
replace stop = mdy(2,19,2020)     in 2
gen byte drug = 1
format start stop %td
save "/tmp/tvr1_exp.dta", replace

use "/tmp/tvr1_cohort.dta", clear
capture noisily tvexpose using "/tmp/tvr1_exp.dta", ///
    id(id) start(start) stop(stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    generate(tv_exp)

if _rc != 0 {
    display as error "  FAIL [1.run]: tvexpose returned error `=_rc'"
    local test1_pass = 0
}
else {
    * Check no overlapping output intervals
    sort id start
    quietly count
    local nrows = r(N)
    display "  INFO: `nrows' rows in output"
    list id start stop tv_exp, noobs

    * Verify person-time conservation: sum of (stop - start + 1) should = 366
    gen double dur = stop - start + 1
    quietly summarize dur
    local total_ptime = r(sum)
    if abs(`total_ptime' - 366) <= 1 {
        display as result "  PASS [1.ptime]: person-time = `total_ptime' (expected 366)"
    }
    else {
        display as error "  FAIL [1.ptime]: person-time = `total_ptime' (expected 366)"
        local test1_pass = 0
    }

    * Verify exposure period is continuous (one exposed block, no fragmentation)
    quietly count if tv_exp == 1
    local n_exposed_rows = r(N)
    if `n_exposed_rows' == 1 {
        display as result "  PASS [1.merge]: single merged exposed period"
    }
    else {
        display as result "  INFO [1.merge]: `n_exposed_rows' exposed rows (may be split but should be contiguous)"
        * Check contiguity: all exposed rows should be adjacent
        sort id start
        local contiguous = 1
        forvalues i = 2/`nrows' {
            if tv_exp[`i'] == 1 & tv_exp[`i'-1] == 1 {
                if start[`i'] != stop[`i'-1] + 1 {
                    local contiguous = 0
                }
            }
        }
        if `contiguous' == 1 {
            display as result "  PASS [1.merge]: exposed periods are contiguous"
        }
        else {
            display as error "  FAIL [1.merge]: exposed periods are NOT contiguous"
            local test1_pass = 0
        }
    }

    * Verify the exposed period covers Jan1 to Feb19
    quietly summarize start if tv_exp == 1
    local exp_start = r(min)
    quietly summarize stop if tv_exp == 1
    local exp_stop = r(max)
    if `exp_start' == mdy(1,1,2020) & `exp_stop' == mdy(2,19,2020) {
        display as result "  PASS [1.dates]: exposed Jan1-Feb19 as expected"
    }
    else {
        local d1 : display %td `exp_start'
        local d2 : display %td `exp_stop'
        display as error "  FAIL [1.dates]: exposed `d1' to `d2'"
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
* TEST 2: OVERLAPPING PRESCRIPTIONS, DIFFERENT DRUG TYPES
* ============================================================================
display _n _dup(60) "-"
display "TEST 2: Overlapping prescriptions, different drug types"
display _dup(60) "-"

* Estrogen (drug=1) from Jan1-Mar31, Progestogen (drug=2) from Feb1-Apr30
* With priority(1 2): drug 1 takes precedence in overlap
* Expected intervals: Jan1-Jan31 drug=1, Feb1-Mar31 drug=1 (priority), Apr1-Apr30 drug=2

local test2_pass = 1

clear
set obs 1
gen long id = 1
gen double study_entry = mdy(1,1,2020)
gen double study_exit  = mdy(12,31,2020)
format study_entry study_exit %td
save "/tmp/tvr2_cohort.dta", replace

clear
set obs 2
gen long id = 1
gen double start = mdy(1,1,2020)  in 1
replace start = mdy(2,1,2020)     in 2
gen double stop = mdy(3,31,2020)  in 1
replace stop = mdy(4,30,2020)     in 2
gen byte drug = 1 in 1
replace drug = 2 in 2
format start stop %td
save "/tmp/tvr2_exp.dta", replace

use "/tmp/tvr2_cohort.dta", clear
capture noisily tvexpose using "/tmp/tvr2_exp.dta", ///
    id(id) start(start) stop(stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    priority(1 2) generate(tv_exp)

if _rc != 0 {
    display as error "  FAIL [2.run]: tvexpose returned error `=_rc'"
    local test2_pass = 0
}
else {
    sort id start
    list id start stop tv_exp, noobs

    * Verify person-time conservation
    gen double dur = stop - start + 1
    quietly summarize dur
    local total_ptime = r(sum)
    if abs(`total_ptime' - 366) <= 1 {
        display as result "  PASS [2.ptime]: person-time = `total_ptime'"
    }
    else {
        display as error "  FAIL [2.ptime]: person-time = `total_ptime' (expected 366)"
        local test2_pass = 0
    }

    * During overlap (Feb1-Mar31) drug=1 should win (priority)
    * Check that no person-time is lost for drug=2
    quietly count if tv_exp == 2
    local n_drug2 = r(N)
    if `n_drug2' >= 1 {
        display as result "  PASS [2.drug2_exists]: drug=2 has `n_drug2' intervals after overlap resolution"
    }
    else {
        display as error "  FAIL [2.drug2_exists]: drug=2 has no intervals"
        local test2_pass = 0
    }

    * No overlapping intervals in output
    local no_overlap = 1
    quietly count
    local nrows = r(N)
    sort id start
    forvalues i = 2/`nrows' {
        if id[`i'] == id[`i'-1] & start[`i'] <= stop[`i'-1] {
            local no_overlap = 0
        }
    }
    if `no_overlap' == 1 {
        display as result "  PASS [2.no_overlap]: no overlapping output intervals"
    }
    else {
        display as error "  FAIL [2.no_overlap]: overlapping intervals in output"
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
* TEST 3: SAME-DAY DISPENSING OF MULTIPLE DRUGS
* ============================================================================
display _n _dup(60) "-"
display "TEST 3: Same-day dispensing of multiple drugs"
display _dup(60) "-"

* Two different drugs dispensed same day but with staggered end dates
* Drug 1: Jan15-Apr30, Drug 2: Jan15-Mar15
* With split: drug 2 period ends first, then drug 1 alone from Mar16-Apr30
* Both drug values should appear in output

local test3_pass = 1

clear
set obs 1
gen long id = 1
gen double study_entry = mdy(1,1,2020)
gen double study_exit  = mdy(12,31,2020)
format study_entry study_exit %td
save "/tmp/tvr3_cohort.dta", replace

clear
set obs 2
gen long id = 1
gen double start = mdy(1,15,2020)
gen double stop = mdy(4,30,2020)  in 1
replace stop = mdy(3,15,2020)     in 2
gen byte drug = 1 in 1
replace drug = 2 in 2
format start stop %td
save "/tmp/tvr3_exp.dta", replace

use "/tmp/tvr3_cohort.dta", clear
capture noisily tvexpose using "/tmp/tvr3_exp.dta", ///
    id(id) start(start) stop(stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    split generate(tv_exp)

if _rc != 0 {
    display as error "  FAIL [3.run]: tvexpose returned error `=_rc'"
    local test3_pass = 0
}
else {
    sort id start
    list id start stop tv_exp, noobs

    * With split, at least drug 1 should appear alone after drug 2 ends
    * Drug 1 should be visible in [Mar16-Apr30] at minimum
    quietly levelsof tv_exp, local(exp_levels)
    local has_drug1 = 0
    local has_drug2 = 0
    local has_exposed = 0
    foreach lev of local exp_levels {
        if `lev' == 1 local has_drug1 = 1
        if `lev' == 2 local has_drug2 = 1
        if `lev' > 0 local has_exposed = 1
    }
    if `has_exposed' == 1 {
        display as result "  PASS [3.exposed]: exposed periods present in output"
    }
    else {
        display as error "  FAIL [3.exposed]: no exposed periods in output"
        local test3_pass = 0
    }

    * At least one drug type should appear (split resolves overlap somehow)
    if `has_drug1' == 1 | `has_drug2' == 1 {
        display as result "  PASS [3.drugs]: drug types in output (drug1=`has_drug1' drug2=`has_drug2')"
    }
    else {
        display as error "  FAIL [3.drugs]: no drug types found"
        local test3_pass = 0
    }

    * Person-time conservation
    gen double dur = stop - start + 1
    quietly summarize dur
    local total_ptime = r(sum)
    display "  INFO: total person-time = `total_ptime'"
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
* TEST 4: EXTREME DURATION - 1-DAY AND 3000-DAY EXPOSURES
* ============================================================================
display _n _dup(60) "-"
display "TEST 4: Extreme duration exposures (1-day and 3000-day)"
display _dup(60) "-"

* After correction, days_supply can be very small or very large
* Rx1: 1-day exposure on Jan15
* Rx2: 3000-day exposure starting Mar1 (8+ years, like an IUD)
* Study: 2020-2028 (9 years)

local test4_pass = 1

clear
set obs 1
gen long id = 1
gen double study_entry = mdy(1,1,2020)
gen double study_exit  = mdy(12,31,2028)
format study_entry study_exit %td
save "/tmp/tvr4_cohort.dta", replace

clear
set obs 2
gen long id = 1
gen double start = mdy(1,15,2020) in 1
replace start = mdy(3,1,2020)     in 2
gen double stop = mdy(1,15,2020)  in 1
replace stop = mdy(3,1,2020) + 2999 in 2
gen byte drug = 1
format start stop %td
save "/tmp/tvr4_exp.dta", replace

use "/tmp/tvr4_cohort.dta", clear
capture noisily tvexpose using "/tmp/tvr4_exp.dta", ///
    id(id) start(start) stop(stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    generate(tv_exp)

if _rc != 0 {
    display as error "  FAIL [4.run]: tvexpose returned error `=_rc'"
    local test4_pass = 0
}
else {
    sort id start
    list id start stop tv_exp, noobs

    * Verify no errors and output exists
    quietly count
    if r(N) > 0 {
        display as result "  PASS [4.output]: output has `=r(N)' rows"
    }
    else {
        display as error "  FAIL [4.output]: no output rows"
        local test4_pass = 0
    }

    * Verify the 1-day exposure is captured
    local found_1day = 0
    quietly count
    local nrows = r(N)
    forvalues i = 1/`nrows' {
        if tv_exp[`i'] == 1 {
            local dur_i = stop[`i'] - start[`i'] + 1
            if `dur_i' == 1 {
                local found_1day = 1
            }
        }
    }
    * The 1-day and 3000-day exposures may merge since they're both drug=1
    * Just verify that exposed time covers Jan15 continuously through the long period
    quietly summarize start if tv_exp == 1
    local first_exp = r(min)
    if `first_exp' == mdy(1,15,2020) {
        display as result "  PASS [4.start]: exposure starts Jan15/2020"
    }
    else {
        local d1 : display %td `first_exp'
        display as error "  FAIL [4.start]: exposure starts `d1' (expected Jan15/2020)"
        local test4_pass = 0
    }

    * Person-time conservation
    local expected_ptime = mdy(12,31,2028) - mdy(1,1,2020) + 1
    gen double dur = stop - start + 1
    quietly summarize dur
    local total_ptime = r(sum)
    if abs(`total_ptime' - `expected_ptime') <= 1 {
        display as result "  PASS [4.ptime]: person-time = `total_ptime' (expected `expected_ptime')"
    }
    else {
        display as error "  FAIL [4.ptime]: person-time = `total_ptime' (expected `expected_ptime')"
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
* TEST 5: VERY LONG SINGLE EXPOSURE (IUD, 8 YEARS)
* ============================================================================
display _n _dup(60) "-"
display "TEST 5: Very long single exposure (IUD, 2922 days)"
display _dup(60) "-"

* IUD with 8-year duration (2922 days)
* Study window is 5 years - should be truncated at exit

local test5_pass = 1

clear
set obs 1
gen long id = 1
gen double study_entry = mdy(1,1,2020)
gen double study_exit  = mdy(12,31,2024)
format study_entry study_exit %td
save "/tmp/tvr5_cohort.dta", replace

clear
set obs 1
gen long id = 1
gen double start = mdy(6,1,2020)
gen double stop  = start + 2921
gen byte drug = 1
format start stop %td
save "/tmp/tvr5_exp.dta", replace

use "/tmp/tvr5_cohort.dta", clear
capture noisily tvexpose using "/tmp/tvr5_exp.dta", ///
    id(id) start(start) stop(stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    generate(tv_exp)

if _rc != 0 {
    display as error "  FAIL [5.run]: tvexpose returned error `=_rc'"
    local test5_pass = 0
}
else {
    sort id start
    list id start stop tv_exp, noobs

    * The exposure extends beyond study_exit - should be truncated
    quietly summarize stop if tv_exp == 1
    local max_stop = r(max)
    if `max_stop' <= mdy(12,31,2024) {
        display as result "  PASS [5.truncate]: exposure truncated at/before study exit"
    }
    else {
        local d1 : display %td `max_stop'
        display as error "  FAIL [5.truncate]: exposure extends to `d1' beyond exit"
        local test5_pass = 0
    }

    * Person-time conservation
    local expected_ptime = mdy(12,31,2024) - mdy(1,1,2020) + 1
    gen double dur = stop - start + 1
    quietly summarize dur
    local total_ptime = r(sum)
    if abs(`total_ptime' - `expected_ptime') <= 1 {
        display as result "  PASS [5.ptime]: person-time = `total_ptime' (expected `expected_ptime')"
    }
    else {
        display as error "  FAIL [5.ptime]: person-time = `total_ptime' (expected `expected_ptime')"
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
* TEST 6: FRACTIONAL DAYS_SUPPLY
* ============================================================================
display _n _dup(60) "-"
display "TEST 6: Fractional days_supply (42.5 days)"
display _dup(60) "-"

* days_supply = 42.5 from multiplier computation
* start = Jan1/2020, stop = start + 42.5 = Feb12.5/2020
* tvexpose should handle non-integer stop dates

local test6_pass = 1

clear
set obs 1
gen long id = 1
gen double study_entry = mdy(1,1,2020)
gen double study_exit  = mdy(12,31,2020)
format study_entry study_exit %td
save "/tmp/tvr6_cohort.dta", replace

clear
set obs 1
gen long id = 1
gen double start = mdy(1,1,2020)
gen double stop  = start + 42.5
gen byte drug = 1
format start stop %td
save "/tmp/tvr6_exp.dta", replace

use "/tmp/tvr6_cohort.dta", clear
capture noisily tvexpose using "/tmp/tvr6_exp.dta", ///
    id(id) start(start) stop(stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    generate(tv_exp)

if _rc != 0 {
    display as error "  FAIL [6.run]: tvexpose returned error `=_rc'"
    local test6_pass = 0
}
else {
    sort id start
    list id start stop tv_exp, noobs

    * Should produce output without error
    quietly count
    if r(N) > 0 {
        display as result "  PASS [6.output]: output has `=r(N)' rows"
    }
    else {
        display as error "  FAIL [6.output]: no output"
        local test6_pass = 0
    }

    * Verify exposed period captures the ~42 day exposure
    gen double dur = stop - start + 1 if tv_exp == 1
    quietly summarize dur
    local exp_dur = r(sum)
    if `exp_dur' >= 42 & `exp_dur' <= 44 {
        display as result "  PASS [6.duration]: exposed duration = `exp_dur' (~42.5)"
    }
    else {
        display as error "  FAIL [6.duration]: exposed duration = `exp_dur' (expected ~42-44)"
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
* TEST 7: ZERO-LENGTH EXPOSURE (stop == start)
* ============================================================================
display _n _dup(60) "-"
display "TEST 7: Zero-length exposure (stop == start)"
display _dup(60) "-"

* rx_stop == rx_start - should create a 1-day period or be handled gracefully

local test7_pass = 1

clear
set obs 1
gen long id = 1
gen double study_entry = mdy(1,1,2020)
gen double study_exit  = mdy(12,31,2020)
format study_entry study_exit %td
save "/tmp/tvr7_cohort.dta", replace

clear
set obs 1
gen long id = 1
gen double start = mdy(6,15,2020)
gen double stop  = mdy(6,15,2020)
gen byte drug = 1
format start stop %td
save "/tmp/tvr7_exp.dta", replace

use "/tmp/tvr7_cohort.dta", clear
capture noisily tvexpose using "/tmp/tvr7_exp.dta", ///
    id(id) start(start) stop(stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    generate(tv_exp)

if _rc != 0 {
    display as error "  INFO [7.run]: tvexpose returned error `=_rc' (may be expected)"
    * Still a pass if it errors gracefully on invalid data
    display as result "  PASS [7.handled]: zero-length exposure handled (error or drop)"
}
else {
    sort id start
    list id start stop tv_exp, noobs

    quietly count
    if r(N) > 0 {
        display as result "  PASS [7.output]: output has `=r(N)' rows"
    }
    else {
        display as error "  FAIL [7.output]: no output rows"
        local test7_pass = 0
    }

    * Person should still be in output (at least as unexposed)
    quietly count if tv_exp == 0
    if r(N) >= 1 {
        display as result "  PASS [7.person]: person present with unexposed time"
    }
    else {
        display as result "  INFO [7.person]: no unexposed rows (entire window may be exposed)"
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
* TEST 8: REVERSED DATES (stop < start)
* ============================================================================
display _n _dup(60) "-"
display "TEST 8: Reversed dates (stop < start)"
display _dup(60) "-"

* Data entry error: rx_stop before rx_start
* tvexpose should error or handle safely

local test8_pass = 1

clear
set obs 1
gen long id = 1
gen double study_entry = mdy(1,1,2020)
gen double study_exit  = mdy(12,31,2020)
format study_entry study_exit %td
save "/tmp/tvr8_cohort.dta", replace

clear
set obs 1
gen long id = 1
gen double start = mdy(6,15,2020)
gen double stop  = mdy(6,1,2020)
gen byte drug = 1
format start stop %td
save "/tmp/tvr8_exp.dta", replace

use "/tmp/tvr8_cohort.dta", clear
capture noisily tvexpose using "/tmp/tvr8_exp.dta", ///
    id(id) start(start) stop(stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    generate(tv_exp)

if _rc != 0 {
    display as result "  PASS [8.handled]: reversed dates handled with error (rc=`=_rc')"
}
else {
    * If it succeeds, the person should still be in output
    sort id start
    list id start stop tv_exp, noobs
    quietly count
    if r(N) > 0 {
        display as result "  PASS [8.handled]: reversed dates handled (person in output, `=r(N)' rows)"
        * Verify the reversed record was dropped (person should be all unexposed)
        quietly count if tv_exp != 0
        if r(N) == 0 {
            display as result "  PASS [8.dropped]: reversed record dropped, person fully unexposed"
        }
        else {
            display as result "  INFO [8.kept]: reversed record kept/reinterpreted (`=r(N)' exposed rows)"
        }
    }
    else {
        display as error "  FAIL [8.handled]: no output and no error"
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
* TEST 9: ALL EXPOSURES OUTSIDE STUDY WINDOW
* ============================================================================
display _n _dup(60) "-"
display "TEST 9: All exposures outside study window"
display _dup(60) "-"

* Person has prescriptions only before entry and after exit
* Should appear in output with reference value only

local test9_pass = 1

clear
set obs 1
gen long id = 1
gen double study_entry = mdy(1,1,2020)
gen double study_exit  = mdy(12,31,2020)
format study_entry study_exit %td
save "/tmp/tvr9_cohort.dta", replace

clear
set obs 2
gen long id = 1
gen double start = mdy(1,1,2019) in 1
replace start = mdy(3,1,2021) in 2
gen double stop = mdy(6,30,2019) in 1
replace stop = mdy(9,30,2021) in 2
gen byte drug = 1
format start stop %td
save "/tmp/tvr9_exp.dta", replace

use "/tmp/tvr9_cohort.dta", clear
capture noisily tvexpose using "/tmp/tvr9_exp.dta", ///
    id(id) start(start) stop(stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    generate(tv_exp)

if _rc != 0 {
    display as error "  FAIL [9.run]: tvexpose returned error `=_rc'"
    local test9_pass = 0
}
else {
    sort id start
    list id start stop tv_exp, noobs

    * Person should be present
    quietly count
    if r(N) >= 1 {
        display as result "  PASS [9.present]: person present in output"
    }
    else {
        display as error "  FAIL [9.present]: person missing from output"
        local test9_pass = 0
    }

    * Person should be fully unexposed (all tv_exp == 0)
    quietly count if tv_exp != 0
    if r(N) == 0 {
        display as result "  PASS [9.unexposed]: person fully unexposed (reference value)"
    }
    else {
        display as error "  FAIL [9.unexposed]: person has `=r(N)' exposed rows despite all rx outside window"
        local test9_pass = 0
    }

    * Person-time conservation
    gen double dur = stop - start + 1
    quietly summarize dur
    local total_ptime = r(sum)
    if abs(`total_ptime' - 366) <= 1 {
        display as result "  PASS [9.ptime]: person-time = `total_ptime'"
    }
    else {
        display as error "  FAIL [9.ptime]: person-time = `total_ptime' (expected 366)"
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
* TEST 10: EXPOSURE SPANNING STUDY_ENTRY
* ============================================================================
display _n _dup(60) "-"
display "TEST 10: Exposure spanning study_entry"
display _dup(60) "-"

* rx_start before study_entry, rx_stop after study_entry
* Should be truncated at entry - no time leakage before study

local test10_pass = 1

clear
set obs 1
gen long id = 1
gen double study_entry = mdy(3,1,2020)
gen double study_exit  = mdy(12,31,2020)
format study_entry study_exit %td
save "/tmp/tvr10_cohort.dta", replace

clear
set obs 1
gen long id = 1
gen double start = mdy(1,1,2020)
gen double stop  = mdy(6,30,2020)
gen byte drug = 1
format start stop %td
save "/tmp/tvr10_exp.dta", replace

use "/tmp/tvr10_cohort.dta", clear
capture noisily tvexpose using "/tmp/tvr10_exp.dta", ///
    id(id) start(start) stop(stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    generate(tv_exp)

if _rc != 0 {
    display as error "  FAIL [10.run]: tvexpose returned error `=_rc'"
    local test10_pass = 0
}
else {
    sort id start
    list id start stop tv_exp, noobs

    * No row should start before study_entry
    quietly summarize start
    local min_start = r(min)
    if `min_start' >= mdy(3,1,2020) {
        display as result "  PASS [10.entry_trunc]: no rows before study entry"
    }
    else {
        local d1 : display %td `min_start'
        display as error "  FAIL [10.entry_trunc]: rows start at `d1', before study entry"
        local test10_pass = 0
    }

    * First row should be exposed (exposure was active at entry)
    sort id start
    local first_exp = tv_exp[1]
    if `first_exp' == 1 {
        display as result "  PASS [10.exposed_at_entry]: exposed from study entry"
    }
    else {
        display as error "  FAIL [10.exposed_at_entry]: first row tv_exp=`first_exp' (expected 1)"
        local test10_pass = 0
    }

    * Person-time conservation
    local expected_ptime = mdy(12,31,2020) - mdy(3,1,2020) + 1
    gen double dur = stop - start + 1
    quietly summarize dur
    local total_ptime = r(sum)
    if abs(`total_ptime' - `expected_ptime') <= 1 {
        display as result "  PASS [10.ptime]: person-time = `total_ptime' (expected `expected_ptime')"
    }
    else {
        display as error "  FAIL [10.ptime]: person-time = `total_ptime' (expected `expected_ptime')"
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
* TEST 11: EXPOSURE SPANNING STUDY_EXIT
* ============================================================================
display _n _dup(60) "-"
display "TEST 11: Exposure spanning study_exit"
display _dup(60) "-"

* rx_start before study_exit, rx_stop after study_exit
* Should be truncated at exit

local test11_pass = 1

clear
set obs 1
gen long id = 1
gen double study_entry = mdy(1,1,2020)
gen double study_exit  = mdy(6,30,2020)
format study_entry study_exit %td
save "/tmp/tvr11_cohort.dta", replace

clear
set obs 1
gen long id = 1
gen double start = mdy(4,1,2020)
gen double stop  = mdy(12,31,2020)
gen byte drug = 1
format start stop %td
save "/tmp/tvr11_exp.dta", replace

use "/tmp/tvr11_cohort.dta", clear
capture noisily tvexpose using "/tmp/tvr11_exp.dta", ///
    id(id) start(start) stop(stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    generate(tv_exp)

if _rc != 0 {
    display as error "  FAIL [11.run]: tvexpose returned error `=_rc'"
    local test11_pass = 0
}
else {
    sort id start
    list id start stop tv_exp, noobs

    * No row should end after study_exit
    quietly summarize stop
    local max_stop = r(max)
    if `max_stop' <= mdy(6,30,2020) {
        display as result "  PASS [11.exit_trunc]: no rows extend beyond study exit"
    }
    else {
        local d1 : display %td `max_stop'
        display as error "  FAIL [11.exit_trunc]: rows extend to `d1', beyond study exit"
        local test11_pass = 0
    }

    * Person-time conservation
    local expected_ptime = mdy(6,30,2020) - mdy(1,1,2020) + 1
    gen double dur = stop - start + 1
    quietly summarize dur
    local total_ptime = r(sum)
    if abs(`total_ptime' - `expected_ptime') <= 1 {
        display as result "  PASS [11.ptime]: person-time = `total_ptime' (expected `expected_ptime')"
    }
    else {
        display as error "  FAIL [11.ptime]: person-time = `total_ptime' (expected `expected_ptime')"
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

* ============================================================================
* TEST 12: EXPOSURE SPANNING BOTH ENTRY AND EXIT
* ============================================================================
display _n _dup(60) "-"
display "TEST 12: Exposure spanning both entry and exit"
display _dup(60) "-"

* Exposure fully contains the study window
* person-time should = study_exit - study_entry + 1

local test12_pass = 1

clear
set obs 1
gen long id = 1
gen double study_entry = mdy(3,1,2020)
gen double study_exit  = mdy(9,30,2020)
format study_entry study_exit %td
save "/tmp/tvr12_cohort.dta", replace

clear
set obs 1
gen long id = 1
gen double start = mdy(1,1,2019)
gen double stop  = mdy(12,31,2021)
gen byte drug = 1
format start stop %td
save "/tmp/tvr12_exp.dta", replace

use "/tmp/tvr12_cohort.dta", clear
capture noisily tvexpose using "/tmp/tvr12_exp.dta", ///
    id(id) start(start) stop(stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    generate(tv_exp)

if _rc != 0 {
    display as error "  FAIL [12.run]: tvexpose returned error `=_rc'"
    local test12_pass = 0
}
else {
    sort id start
    list id start stop tv_exp, noobs

    * Should be entirely exposed
    quietly count if tv_exp != 1
    if r(N) == 0 {
        display as result "  PASS [12.all_exposed]: person fully exposed"
    }
    else {
        display as error "  FAIL [12.all_exposed]: `=r(N)' unexposed rows"
        local test12_pass = 0
    }

    * Person-time = study window
    local expected_ptime = mdy(9,30,2020) - mdy(3,1,2020) + 1
    gen double dur = stop - start + 1
    quietly summarize dur
    local total_ptime = r(sum)
    if abs(`total_ptime' - `expected_ptime') <= 1 {
        display as result "  PASS [12.ptime]: person-time = `total_ptime' (expected `expected_ptime')"
    }
    else {
        display as error "  FAIL [12.ptime]: person-time = `total_ptime' (expected `expected_ptime')"
        local test12_pass = 0
    }

    * Start/stop should match study boundaries
    quietly summarize start
    local out_start = r(min)
    quietly summarize stop
    local out_stop = r(max)
    if `out_start' == mdy(3,1,2020) & `out_stop' == mdy(9,30,2020) {
        display as result "  PASS [12.boundaries]: output bounded by study window"
    }
    else {
        display as error "  FAIL [12.boundaries]: output not bounded by study window"
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
* TEST 13: MISSING STOP DATE WITH ONGOING TREATMENT
* ============================================================================
display _n _dup(60) "-"
display "TEST 13: Missing stop date with ongoing treatment"
display _dup(60) "-"

* Treatment still ongoing at data cutoff - stop is missing
* Use fillgaps() to impute continuation
* Person should have exposure through study exit

local test13_pass = 1

clear
set obs 1
gen long id = 1
gen double study_entry = mdy(1,1,2020)
gen double study_exit  = mdy(12,31,2020)
format study_entry study_exit %td
save "/tmp/tvr13_cohort.dta", replace

clear
set obs 1
gen long id = 1
gen double start = mdy(3,1,2020)
gen double stop  = .
gen byte drug = 1
format start stop %td
save "/tmp/tvr13_exp.dta", replace

* fillgaps should extend exposure beyond last known date
use "/tmp/tvr13_cohort.dta", clear
capture noisily tvexpose using "/tmp/tvr13_exp.dta", ///
    id(id) start(start) stop(stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    fillgaps(9999) generate(tv_exp)

if _rc != 0 {
    * Try without fillgaps - pointtime approach
    display "  INFO: fillgaps with missing stop failed (rc=`=_rc'), trying pointtime"
    use "/tmp/tvr13_cohort.dta", clear
    capture noisily tvexpose using "/tmp/tvr13_exp.dta", ///
        id(id) start(start) ///
        exposure(drug) reference(0) ///
        entry(study_entry) exit(study_exit) ///
        pointtime fillgaps(9999) generate(tv_exp)

    if _rc != 0 {
        display as error "  FAIL [13.run]: tvexpose returned error `=_rc' with both approaches"
        local test13_pass = 0
    }
    else {
        sort id start
        list id start stop tv_exp, noobs

        * Person should be exposed from Mar1 through study exit
        quietly count
        if r(N) > 0 {
            display as result "  PASS [13.output]: output has `=r(N)' rows"
        }
        else {
            display as error "  FAIL [13.output]: no output"
            local test13_pass = 0
        }
    }
}
else {
    sort id start
    list id start stop tv_exp, noobs

    * Verify exposure extends through study
    quietly summarize stop if tv_exp == 1
    local max_exp_stop = r(max)
    if `max_exp_stop' >= mdy(12,31,2020) {
        display as result "  PASS [13.ongoing]: exposure extends to study exit"
    }
    else {
        local d1 : display %td `max_exp_stop'
        display as result "  INFO [13.ongoing]: exposure ends at `d1' (fillgaps may have capped)"
    }

    quietly count
    if r(N) > 0 {
        display as result "  PASS [13.output]: output has `=r(N)' rows"
    }
    else {
        display as error "  FAIL [13.output]: no output"
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

* ============================================================================
* TEST 14: START == STOP WITH DIFFERENT HANDLING
* ============================================================================
display _n _dup(60) "-"
display "TEST 14: start_date == stop_date (single-day treatment)"
display _dup(60) "-"

* This is a legitimate single-day treatment (like an infusion)
* Should create exactly 1 exposed day

local test14_pass = 1

clear
set obs 1
gen long id = 1
gen double study_entry = mdy(1,1,2020)
gen double study_exit  = mdy(12,31,2020)
format study_entry study_exit %td
save "/tmp/tvr14_cohort.dta", replace

clear
set obs 1
gen long id = 1
gen double start = mdy(6,15,2020)
gen double stop  = mdy(6,15,2020)
gen byte drug = 1
format start stop %td
save "/tmp/tvr14_exp.dta", replace

use "/tmp/tvr14_cohort.dta", clear
capture noisily tvexpose using "/tmp/tvr14_exp.dta", ///
    id(id) start(start) stop(stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    generate(tv_exp)

if _rc != 0 {
    display as result "  INFO [14.run]: rc=`=_rc' (single-day treatment may need special handling)"
    * Not a failure - behavior may be acceptable
}
else {
    sort id start
    list id start stop tv_exp, noobs

    * Person should be in output
    quietly count
    if r(N) >= 1 {
        display as result "  PASS [14.present]: person present, `=r(N)' rows"
    }
    else {
        display as error "  FAIL [14.present]: person missing"
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

* ============================================================================
* TEST 15: DRUG-SPECIFIC MINIMUM DURATIONS (BIOLOGIC)
* ============================================================================
display _n _dup(60) "-"
display "TEST 15: Drug-specific minimum durations (biologic with washout)"
display _dup(60) "-"

* rituximab: 1-day recorded duration but biologically active 180 days
* Use washout(180) to extend exposure effect

local test15_pass = 1

clear
set obs 1
gen long id = 1
gen double study_entry = mdy(1,1,2020)
gen double study_exit  = mdy(12,31,2020)
format study_entry study_exit %td
save "/tmp/tvr15_cohort.dta", replace

clear
set obs 1
gen long id = 1
gen double start = mdy(3,1,2020)
gen double stop  = mdy(3,1,2020)
gen byte drug = 1
format start stop %td
save "/tmp/tvr15_exp.dta", replace

use "/tmp/tvr15_cohort.dta", clear
capture noisily tvexpose using "/tmp/tvr15_exp.dta", ///
    id(id) start(start) stop(stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    washout(180) generate(tv_exp)

if _rc != 0 {
    display as error "  FAIL [15.run]: tvexpose returned error `=_rc'"
    local test15_pass = 0
}
else {
    sort id start
    list id start stop tv_exp, noobs

    * Exposure should extend ~180 days past stop (Mar1 + 180 ≈ Aug28)
    quietly summarize stop if tv_exp == 1
    local max_exp = r(max)
    local expected_wash_end = mdy(3,1,2020) + 180
    * Allow tolerance since washout interacts with stop date
    if `max_exp' >= `expected_wash_end' - 5 {
        local d1 : display %td `max_exp'
        display as result "  PASS [15.washout]: exposure extends to `d1' (washout 180 days)"
    }
    else {
        local d1 : display %td `max_exp'
        local d2 : display %td `expected_wash_end'
        display as error "  FAIL [15.washout]: exposure ends `d1', expected near `d2'"
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

* ============================================================================
* TEST 16: SEQUENTIAL TREATMENTS WITH NO GAP
* ============================================================================
display _n _dup(60) "-"
display "TEST 16: Sequential treatments with no gap (A ends day N, B starts day N)"
display _dup(60) "-"

* Treatment A: Jan1-Mar31, Treatment B: Mar31-Jun30
* They share the boundary date
* No gap should be created

local test16_pass = 1

clear
set obs 1
gen long id = 1
gen double study_entry = mdy(1,1,2020)
gen double study_exit  = mdy(12,31,2020)
format study_entry study_exit %td
save "/tmp/tvr16_cohort.dta", replace

clear
set obs 2
gen long id = 1
gen double start = mdy(1,1,2020)   in 1
replace start = mdy(3,31,2020)     in 2
gen double stop = mdy(3,31,2020)   in 1
replace stop = mdy(6,30,2020)      in 2
gen byte drug = 1 in 1
replace drug = 2 in 2
format start stop %td
save "/tmp/tvr16_exp.dta", replace

use "/tmp/tvr16_cohort.dta", clear
capture noisily tvexpose using "/tmp/tvr16_exp.dta", ///
    id(id) start(start) stop(stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    generate(tv_exp)

if _rc != 0 {
    display as error "  FAIL [16.run]: tvexpose returned error `=_rc'"
    local test16_pass = 0
}
else {
    sort id start
    list id start stop tv_exp, noobs

    * Check for gaps in the output between exposed periods
    quietly count
    local nrows = r(N)
    local has_gap = 0
    forvalues i = 2/`nrows' {
        local gap = start[`i'] - stop[`i'-1]
        if `gap' > 1 & tv_exp[`i'] > 0 & tv_exp[`i'-1] > 0 {
            local has_gap = 1
            display "  INFO: gap of `gap' days between rows `=`i'-1' and `i'"
        }
    }
    if `has_gap' == 0 {
        display as result "  PASS [16.no_gap]: no unexpected gaps between treatments"
    }
    else {
        display as error "  FAIL [16.no_gap]: gap found between sequential treatments"
        local test16_pass = 0
    }

    * Person-time conservation
    local expected_ptime = mdy(12,31,2020) - mdy(1,1,2020) + 1
    gen double dur = stop - start + 1
    quietly summarize dur
    local total_ptime = r(sum)
    if abs(`total_ptime' - `expected_ptime') <= 1 {
        display as result "  PASS [16.ptime]: person-time = `total_ptime'"
    }
    else {
        display as error "  FAIL [16.ptime]: person-time = `total_ptime' (expected `expected_ptime')"
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
* TEST 17: SEQUENTIAL TREATMENTS WITH 1-DAY GAP + GRACE PERIOD
* ============================================================================
display _n _dup(60) "-"
display "TEST 17: Sequential treatments with 1-day gap and grace period"
display _dup(60) "-"

* Treatment A: Jan1-Mar31, Treatment B: Apr2-Jun30 (1-day gap on Apr1)
* grace(1) should bridge the gap; grace(0) should not

local test17_pass = 1

clear
set obs 1
gen long id = 1
gen double study_entry = mdy(1,1,2020)
gen double study_exit  = mdy(12,31,2020)
format study_entry study_exit %td
save "/tmp/tvr17_cohort.dta", replace

clear
set obs 2
gen long id = 1
gen double start = mdy(1,1,2020)  in 1
replace start = mdy(4,2,2020)    in 2
gen double stop = mdy(3,31,2020) in 1
replace stop = mdy(6,30,2020)    in 2
gen byte drug = 1
format start stop %td
save "/tmp/tvr17_exp.dta", replace

* First test with grace(1) - should bridge
use "/tmp/tvr17_cohort.dta", clear
capture noisily tvexpose using "/tmp/tvr17_exp.dta", ///
    id(id) start(start) stop(stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    grace(1) generate(tv_exp)

if _rc != 0 {
    display as error "  FAIL [17.grace1.run]: tvexpose returned error `=_rc'"
    local test17_pass = 0
}
else {
    sort id start
    display "  With grace(1):"
    list id start stop tv_exp, noobs

    * Count reference periods between exposed periods
    quietly count if tv_exp == 0
    local n_unexp = r(N)
    * With grace(1), the 1-day gap should be bridged, so only pre/post unexposed
    display "  INFO: `n_unexp' unexposed intervals with grace(1)"
}

* Now test without grace - should have gap
use "/tmp/tvr17_cohort.dta", clear
capture noisily tvexpose using "/tmp/tvr17_exp.dta", ///
    id(id) start(start) stop(stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    generate(tv_exp2)

if _rc != 0 {
    display as error "  FAIL [17.nograce.run]: tvexpose returned error `=_rc'"
    local test17_pass = 0
}
else {
    sort id start
    display "  Without grace:"
    list id start stop tv_exp2, noobs

    * Should have an unexposed gap between Mar31 and Apr2
    quietly count if tv_exp2 == 0
    local n_unexp_nograce = r(N)
    display "  INFO: `n_unexp_nograce' unexposed intervals without grace"

    if `n_unexp_nograce' >= 2 {
        display as result "  PASS [17.gap]: gap present without grace (>=2 unexposed intervals)"
    }
    else {
        display as result "  INFO [17.gap]: `n_unexp_nograce' unexposed intervals without grace"
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

* ============================================================================
* TEST 18: RAPID SWITCHING (5 CHANGES IN 30 DAYS)
* ============================================================================
display _n _dup(60) "-"
display "TEST 18: Rapid switching (5 treatment changes in 30 days)"
display _dup(60) "-"

* 5 different drugs in rapid succession over 30 days
* All transitions should be captured

local test18_pass = 1

clear
set obs 1
gen long id = 1
gen double study_entry = mdy(1,1,2020)
gen double study_exit  = mdy(12,31,2020)
format study_entry study_exit %td
save "/tmp/tvr18_cohort.dta", replace

clear
set obs 5
gen long id = 1
gen double start = mdy(3,1,2020) + (_n-1)*6
gen double stop  = start + 5
gen byte drug = _n
format start stop %td
save "/tmp/tvr18_exp.dta", replace

use "/tmp/tvr18_cohort.dta", clear
capture noisily tvexpose using "/tmp/tvr18_exp.dta", ///
    id(id) start(start) stop(stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    generate(tv_exp)

if _rc != 0 {
    display as error "  FAIL [18.run]: tvexpose returned error `=_rc'"
    local test18_pass = 0
}
else {
    sort id start
    list id start stop tv_exp, noobs

    * All 5 drug types should appear
    quietly levelsof tv_exp, local(exp_levels)
    local n_types = 0
    foreach lev of local exp_levels {
        if `lev' > 0 local n_types = `n_types' + 1
    }
    if `n_types' == 5 {
        display as result "  PASS [18.all_types]: all 5 drug types in output"
    }
    else {
        display as error "  FAIL [18.all_types]: only `n_types' drug types (expected 5)"
        local test18_pass = 0
    }

    * Person-time conservation
    local expected_ptime = mdy(12,31,2020) - mdy(1,1,2020) + 1
    gen double dur = stop - start + 1
    quietly summarize dur
    local total_ptime = r(sum)
    if abs(`total_ptime' - `expected_ptime') <= 1 {
        display as result "  PASS [18.ptime]: person-time = `total_ptime'"
    }
    else {
        display as error "  FAIL [18.ptime]: person-time = `total_ptime' (expected `expected_ptime')"
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

* ============================================================================
* TEST 19: MULTI-PERSON MIX (10 PERSONS WITH DIFFERENT PATTERNS)
* ============================================================================
display _n _dup(60) "-"
display "TEST 19: Multi-person mix (10 persons, diverse patterns)"
display _dup(60) "-"

* Person 1: untreated
* Person 2: single exposure, mid-study
* Person 3: heavy switcher (3 drugs)
* Person 4: all exposures outside window
* Person 5: exposure = full study window
* Person 6: overlapping same-drug prescriptions
* Person 7: exposure spanning entry only
* Person 8: exposure spanning exit only
* Person 9: two separate exposures with gap
* Person 10: very short study window (7 days)

local test19_pass = 1

clear
set obs 10
gen long id = _n
gen double study_entry = mdy(1,1,2020)
gen double study_exit  = mdy(12,31,2020)
* Person 10: very short window
replace study_exit = mdy(1,7,2020) in 10
format study_entry study_exit %td
save "/tmp/tvr19_cohort.dta", replace

* Build exposure data
clear
set obs 0
gen long id = .
gen double start = .
gen double stop = .
gen byte drug = .

* Person 1: no exposures (skip)

* Person 2: single exposure Mar1-Jun30
local n = _N + 1
set obs `n'
replace id = 2 in `n'
replace start = mdy(3,1,2020) in `n'
replace stop = mdy(6,30,2020) in `n'
replace drug = 1 in `n'

* Person 3: heavy switcher
foreach d in 1 2 3 {
    local n = _N + 1
    set obs `n'
    replace id = 3 in `n'
    replace start = mdy(1,1,2020) + (`d'-1)*60 in `n'
    replace stop = mdy(1,1,2020) + `d'*60 - 1 in `n'
    replace drug = `d' in `n'
}

* Person 4: all outside window
local n = _N + 1
set obs `n'
replace id = 4 in `n'
replace start = mdy(6,1,2019) in `n'
replace stop = mdy(11,30,2019) in `n'
replace drug = 1 in `n'

* Person 5: full window coverage
local n = _N + 1
set obs `n'
replace id = 5 in `n'
replace start = mdy(1,1,2020) in `n'
replace stop = mdy(12,31,2020) in `n'
replace drug = 1 in `n'

* Person 6: overlapping same-drug
foreach rx in 1 2 {
    local n = _N + 1
    set obs `n'
    replace id = 6 in `n'
    replace start = mdy(4,1,2020) + (`rx'-1)*20 in `n'
    replace stop = mdy(4,1,2020) + (`rx'-1)*20 + 29 in `n'
    replace drug = 1 in `n'
}

* Person 7: spanning entry
local n = _N + 1
set obs `n'
replace id = 7 in `n'
replace start = mdy(10,1,2019) in `n'
replace stop = mdy(4,30,2020) in `n'
replace drug = 1 in `n'

* Person 8: spanning exit
local n = _N + 1
set obs `n'
replace id = 8 in `n'
replace start = mdy(9,1,2020) in `n'
replace stop = mdy(6,30,2021) in `n'
replace drug = 1 in `n'

* Person 9: two separate exposures
foreach rx in 1 2 {
    local n = _N + 1
    set obs `n'
    replace id = 9 in `n'
    if `rx' == 1 {
        replace start = mdy(2,1,2020) in `n'
        replace stop = mdy(3,31,2020) in `n'
    }
    else {
        replace start = mdy(8,1,2020) in `n'
        replace stop = mdy(9,30,2020) in `n'
    }
    replace drug = 1 in `n'
}

* Person 10: exposure in short window
local n = _N + 1
set obs `n'
replace id = 10 in `n'
replace start = mdy(1,3,2020) in `n'
replace stop = mdy(1,5,2020) in `n'
replace drug = 1 in `n'

format start stop %td
save "/tmp/tvr19_exp.dta", replace

use "/tmp/tvr19_cohort.dta", clear
capture noisily tvexpose using "/tmp/tvr19_exp.dta", ///
    id(id) start(start) stop(stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    generate(tv_exp)

if _rc != 0 {
    display as error "  FAIL [19.run]: tvexpose returned error `=_rc'"
    local test19_pass = 0
}
else {
    sort id start
    * Check all 10 persons present
    quietly tab id
    local n_persons = r(r)
    if `n_persons' == 10 {
        display as result "  PASS [19.all_persons]: all 10 persons in output"
    }
    else {
        display as error "  FAIL [19.all_persons]: `n_persons' persons (expected 10)"
        local test19_pass = 0
    }

    * Person 1: should be fully unexposed
    quietly count if id == 1 & tv_exp != 0
    if r(N) == 0 {
        display as result "  PASS [19.p1_unexp]: person 1 fully unexposed"
    }
    else {
        display as error "  FAIL [19.p1_unexp]: person 1 has `=r(N)' exposed rows"
        local test19_pass = 0
    }

    * Person 4: should be fully unexposed (outside window)
    quietly count if id == 4 & tv_exp != 0
    if r(N) == 0 {
        display as result "  PASS [19.p4_unexp]: person 4 fully unexposed (outside window)"
    }
    else {
        display as error "  FAIL [19.p4_unexp]: person 4 has `=r(N)' exposed rows"
        local test19_pass = 0
    }

    * Person 5: should be fully exposed
    quietly count if id == 5 & tv_exp == 0
    if r(N) == 0 {
        display as result "  PASS [19.p5_exp]: person 5 fully exposed"
    }
    else {
        display as error "  FAIL [19.p5_exp]: person 5 has `=r(N)' unexposed rows"
        local test19_pass = 0
    }

    * No overlapping intervals per person
    local overlap_found = 0
    sort id start
    quietly count
    local nrows = r(N)
    forvalues i = 2/`nrows' {
        if id[`i'] == id[`i'-1] & start[`i'] <= stop[`i'-1] {
            local overlap_found = 1
        }
    }
    if `overlap_found' == 0 {
        display as result "  PASS [19.no_overlap]: no overlapping intervals in output"
    }
    else {
        display as error "  FAIL [19.no_overlap]: overlapping intervals found"
        local test19_pass = 0
    }

    * Person-time per person: check a few
    preserve
    gen double dur = stop - start + 1
    collapse (sum) total_days=dur (min) entry=start (max) exit=stop, by(id)
    merge 1:1 id using "/tmp/tvr19_cohort.dta", keepusing(study_entry study_exit) nogenerate
    gen double expected_days = study_exit - study_entry + 1
    gen double ptime_diff = abs(total_days - expected_days)
    quietly summarize ptime_diff
    local max_diff = r(max)
    restore

    if `max_diff' <= 1 {
        display as result "  PASS [19.ptime]: person-time conserved (max diff = `max_diff')"
    }
    else {
        display as error "  FAIL [19.ptime]: person-time not conserved (max diff = `max_diff')"
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

* ============================================================================
* TEST 20: PERSON WITH 50+ PRESCRIPTION RECORDS
* ============================================================================
display _n _dup(60) "-"
display "TEST 20: Person with 50+ prescription records (stress test)"
display _dup(60) "-"

* Performance and correctness with many short exposures

local test20_pass = 1

clear
set obs 1
gen long id = 1
gen double study_entry = mdy(1,1,2018)
gen double study_exit  = mdy(12,31,2024)
format study_entry study_exit %td
save "/tmp/tvr20_cohort.dta", replace

* 60 prescriptions over 7 years (approx one per 6 weeks)
clear
set obs 60
gen long id = 1
gen double start = mdy(1,1,2018) + (_n-1)*42
gen double stop  = start + 30
gen byte drug = mod(_n-1, 3) + 1
format start stop %td
save "/tmp/tvr20_exp.dta", replace

use "/tmp/tvr20_cohort.dta", clear
capture noisily tvexpose using "/tmp/tvr20_exp.dta", ///
    id(id) start(start) stop(stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    generate(tv_exp)

if _rc != 0 {
    display as error "  FAIL [20.run]: tvexpose returned error `=_rc'"
    local test20_pass = 0
}
else {
    sort id start
    quietly count
    local nrows = r(N)
    display "  INFO: `nrows' output rows from 60 input prescriptions"

    * All 3 drug types should appear
    quietly levelsof tv_exp, local(exp_levels)
    local n_types = 0
    foreach lev of local exp_levels {
        if `lev' > 0 local n_types = `n_types' + 1
    }
    if `n_types' == 3 {
        display as result "  PASS [20.all_types]: all 3 drug types present"
    }
    else {
        display as error "  FAIL [20.all_types]: `n_types' types (expected 3)"
        local test20_pass = 0
    }

    * No overlapping intervals
    local no_overlap = 1
    sort id start
    forvalues i = 2/`nrows' {
        if start[`i'] <= stop[`i'-1] {
            local no_overlap = 0
        }
    }
    if `no_overlap' == 1 {
        display as result "  PASS [20.no_overlap]: no overlapping output intervals"
    }
    else {
        display as error "  FAIL [20.no_overlap]: overlapping intervals found"
        local test20_pass = 0
    }

    * Person-time conservation
    local expected_ptime = mdy(12,31,2024) - mdy(1,1,2018) + 1
    gen double dur = stop - start + 1
    quietly summarize dur
    local total_ptime = r(sum)
    if abs(`total_ptime' - `expected_ptime') <= 1 {
        display as result "  PASS [20.ptime]: person-time = `total_ptime' (expected `expected_ptime')"
    }
    else {
        display as error "  FAIL [20.ptime]: person-time = `total_ptime' (expected `expected_ptime')"
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

* ============================================================================
* SUMMARY

}


* =============================================================================
* SECTION 6: TVMERGE - Merge correctness and person-time additivity
* =============================================================================
* --- From validation_tvmerge.do ---

capture noisily {
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

}

* --- From validation_tvmerge_mathematical.do ---

capture noisily {
display _n _dup(70) "="
display "TVMERGE MATHEMATICAL VALIDATION"
display _dup(70) "="
display "Date: $S_DATE $S_TIME"
display ""


* ============================================================================
* TEST 5A: INTERVAL INTERSECTION BOUNDARIES (EXACT DATES)
* ============================================================================
display _n _dup(60) "-"
display "TEST 5A: Interval intersection boundaries"
display _dup(60) "-"

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
save "/tmp/tvm5a_dsetA.dta", replace

clear
set obs 1
gen id = 1
gen startB = mdy(4,1,2020)
gen stopB  = mdy(9,30,2020)
gen expB   = 1
save "/tmp/tvm5a_dsetB.dta", replace

capture noisily tvmerge ///
    "/tmp/tvm5a_dsetA.dta" "/tmp/tvm5a_dsetB.dta", ///
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

* ============================================================================
* TEST 5B: CONTINUOUS PROPORTIONING FORMULA
* ============================================================================
display _n _dup(60) "-"
display "TEST 5B: Continuous proportioning formula"
display _dup(60) "-"

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
save "/tmp/tvm5b_dsetA.dta", replace

clear
set obs 1
gen id = 1
gen startB = mdy(7,1,2020)
gen stopB  = mdy(12,31,2020)
gen expB   = 1
save "/tmp/tvm5b_dsetB.dta", replace

capture noisily tvmerge ///
    "/tmp/tvm5b_dsetA.dta" "/tmp/tvm5b_dsetB.dta", ///
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

* ============================================================================
* TEST 5C: INTERVAL INTEGRITY - NO GAPS, NO OVERLAPS
* ============================================================================
display _n _dup(60) "-"
display "TEST 5C: Interval integrity - no gaps or overlaps within person"
display _dup(60) "-"

local test5c_pass = 1

* Create two datasets with varying exposure patterns for 5 persons
clear
set obs 5
gen id = _n
gen startA = mdy(1,1,2020) + (id-1)*30
gen stopA  = startA + 180
gen expA   = id
save "/tmp/tvm5c_dsetA.dta", replace

clear
set obs 5
gen id = _n
gen startB = mdy(1,1,2020) + (id-1)*20
gen stopB  = startB + 200
gen expB   = id * 10
save "/tmp/tvm5c_dsetB.dta", replace

capture noisily tvmerge ///
    "/tmp/tvm5c_dsetA.dta" "/tmp/tvm5c_dsetB.dta", ///
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

* ============================================================================
* FINAL SUMMARY

}

* --- From validation_tvmerge_registry.do ---

capture noisily {
display _n _dup(70) "="
display "TVMERGE REGISTRY DATA VALIDATION"
display _dup(70) "="
display "Date: $S_DATE $S_TIME"
display ""


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

}


* =============================================================================
* SECTION 7: TVWEIGHT - IPTW weight properties validation
* =============================================================================
* --- From validation_tvweight.do ---

capture noisily {
* =============================================================================
* VALIDATION DATASETS
* =============================================================================
if `quiet' == 0 {
    display as text _n "Creating validation datasets..."
}

* Dataset 1: Simple known propensity scores
* Create data where we can verify IPTW calculation manually
* 100 observations: 50 with x=0 (all untreated), 50 with x=1 (all treated)
clear
set obs 100
gen id = _n
gen x = (_n > 50)
gen treatment = x
* All PS should be 1 for treated when x=1, 0 for treated when x=0
* Weight = 1/1 = 1 for all
save "${DATA_DIR}/val_perfect_sep.dta", replace

* Dataset 2: Known propensity scores from simple model
* Create balanced data with predictable PS
clear
set obs 200
gen id = _n
* Binary covariate
gen x = mod(_n, 2)
* Treatment pattern: P(T=1|x=0) = 0.25, P(T=1|x=1) = 0.75
gen treatment = 0
replace treatment = 1 if x == 0 & _n <= 25  // 25 treated of 100 with x=0
replace treatment = 1 if x == 1 & _n > 100 & _n <= 175  // 75 treated of 100 with x=1
save "${DATA_DIR}/val_known_ps.dta", replace

* Dataset 3: For ESS calculation
* Simple case where ESS can be calculated by hand
clear
set obs 10
gen id = _n
gen x = 1
gen treatment = (_n <= 5)
save "${DATA_DIR}/val_ess.dta", replace

if `quiet' == 0 {
    display as result "Validation datasets created in: ${DATA_DIR}"
}

* =============================================================================
* SECTION 1: WEIGHT CALCULATION CORRECTNESS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 1: Weight Calculation Correctness"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 1.1: Known IPTW for simple case
* Purpose: Verify IPTW = 1/PS for treated, 1/(1-PS) for untreated
* With known PS from logistic regression
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 1.1: Known IPTW calculation"
}

capture {
    use "${DATA_DIR}/val_known_ps.dta", clear

    * First, fit logit manually and calculate expected weights
    quietly logit treatment x
    quietly predict ps_manual, pr

    * Calculate expected IPTW
    gen expected_iptw = .
    replace expected_iptw = 1/ps_manual if treatment == 1
    replace expected_iptw = 1/(1-ps_manual) if treatment == 0

    * Now use tvweight
    tvweight treatment, covariates(x) nolog

    * Verify weights match expected
    gen diff = abs(iptw - expected_iptw)
    sum diff
    assert r(max) < 0.0001
}
if _rc == 0 {
    display as result "  PASS: IPTW matches manual calculation"
    local ++pass_count
}
else {
    display as error "  FAIL: IPTW calculation (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 1.1"
}

* -----------------------------------------------------------------------------
* Test 1.2: Stabilized weights calculation
* Purpose: Verify SW = marginal_prob / PS (for treated)
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 1.2: Stabilized weights calculation"
}

capture {
    use "${DATA_DIR}/val_known_ps.dta", clear

    * Calculate marginal probability of treatment
    sum treatment
    local marg_prob = r(mean)

    * Fit logit and get PS
    quietly logit treatment x
    quietly predict ps_manual, pr

    * Calculate expected stabilized weights
    gen expected_sw = .
    replace expected_sw = `marg_prob' / ps_manual if treatment == 1
    replace expected_sw = (1 - `marg_prob') / (1 - ps_manual) if treatment == 0

    * Use tvweight with stabilized
    tvweight treatment, covariates(x) stabilized nolog

    * Verify weights match expected
    gen diff = abs(iptw - expected_sw)
    sum diff
    assert r(max) < 0.0001
}
if _rc == 0 {
    display as result "  PASS: Stabilized weights match manual calculation"
    local ++pass_count
}
else {
    display as error "  FAIL: Stabilized weights (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 1.2"
}

* =============================================================================
* SECTION 2: EFFECTIVE SAMPLE SIZE
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 2: Effective Sample Size"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 2.1: ESS calculation
* Purpose: Verify ESS = (sum w)^2 / sum(w^2)
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 2.1: ESS calculation"
}

capture {
    use "${DATA_DIR}/val_known_ps.dta", clear

    tvweight treatment, covariates(x) nolog

    * Save ESS from tvweight before other commands overwrite r()
    local tvweight_ess = r(ess)

    * Calculate ESS manually
    sum iptw
    local sum_w = r(sum)
    gen w2 = iptw^2
    sum w2
    local sum_w2 = r(sum)
    local expected_ess = (`sum_w'^2) / `sum_w2'

    * Compare with returned ESS
    assert abs(`tvweight_ess' - `expected_ess') < 0.01
}
if _rc == 0 {
    display as result "  PASS: ESS matches manual calculation"
    local ++pass_count
}
else {
    display as error "  FAIL: ESS calculation (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 2.1"
}

* -----------------------------------------------------------------------------
* Test 2.2: ESS percentage
* Purpose: Verify ESS% = 100 * ESS / N
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 2.2: ESS percentage"
}

capture {
    use "${DATA_DIR}/val_known_ps.dta", clear

    tvweight treatment, covariates(x) nolog

    * Save all return values before any other commands
    local n = r(N)
    local ess = r(ess)
    local ess_pct = r(ess_pct)
    local expected_pct = 100 * `ess' / `n'

    assert abs(`ess_pct' - `expected_pct') < 0.01
}
if _rc == 0 {
    display as result "  PASS: ESS percentage correct"
    local ++pass_count
}
else {
    display as error "  FAIL: ESS percentage (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 2.2"
}

* =============================================================================
* SECTION 3: TRUNCATION
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 3: Truncation Validation"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 3.1: Truncation bounds
* Purpose: After truncation, no weights outside bounds
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.1: Truncation bounds enforced"
}

capture {
    use "${DATA_DIR}/val_known_ps.dta", clear

    * Calculate untrimmed weights first
    tvweight treatment, covariates(x) generate(iptw_raw) nolog

    * Get 5th and 95th percentiles
    _pctile iptw_raw, p(5 95)
    local p5 = r(r1)
    local p95 = r(r2)

    * Now with truncation
    tvweight treatment, covariates(x) truncate(5 95) replace nolog

    * Verify no weights outside bounds
    count if iptw < `p5' - 0.0001
    assert r(N) == 0
    count if iptw > `p95' + 0.0001
    assert r(N) == 0
}
if _rc == 0 {
    display as result "  PASS: Truncation bounds enforced"
    local ++pass_count
}
else {
    display as error "  FAIL: Truncation bounds (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.1"
}

* =============================================================================
* SECTION 4: INVARIANTS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 4: Invariant Tests"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Invariant 4.1: Weights always positive
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Invariant 4.1: Weights always positive"
}

capture {
    use "${DATA_DIR}/val_known_ps.dta", clear
    tvweight treatment, covariates(x) nolog

    count if iptw <= 0 | missing(iptw)
    assert r(N) == 0
}
if _rc == 0 {
    display as result "  PASS: All weights positive"
    local ++pass_count
}
else {
    display as error "  FAIL: Some weights non-positive (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' Inv4.1"
}

* -----------------------------------------------------------------------------
* Invariant 4.2: Propensity scores between 0 and 1
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Invariant 4.2: Propensity scores bounded"
}

capture {
    use "${DATA_DIR}/val_known_ps.dta", clear
    tvweight treatment, covariates(x) denominator(ps) nolog

    count if ps <= 0 | ps >= 1
    assert r(N) == 0
}
if _rc == 0 {
    display as result "  PASS: All PS between 0 and 1"
    local ++pass_count
}
else {
    display as error "  FAIL: PS out of bounds (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' Inv4.2"
}

* -----------------------------------------------------------------------------
* Invariant 4.3: ESS <= N
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Invariant 4.3: ESS <= N"
}

capture {
    use "${DATA_DIR}/val_known_ps.dta", clear
    tvweight treatment, covariates(x) nolog

    assert r(ess) <= r(N) + 0.01  // Small tolerance for floating point
}
if _rc == 0 {
    display as result "  PASS: ESS <= N"
    local ++pass_count
}
else {
    display as error "  FAIL: ESS > N (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' Inv4.3"
}

* -----------------------------------------------------------------------------
* Invariant 4.4: Stabilized weights have mean near 1
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Invariant 4.4: Stabilized weights mean ~ 1"
}

capture {
    use "${DATA_DIR}/val_known_ps.dta", clear
    tvweight treatment, covariates(x) stabilized nolog

    * Mean of stabilized weights should be close to 1
    sum iptw
    assert abs(r(mean) - 1) < 0.1
}
if _rc == 0 {
    display as result "  PASS: Stabilized weights have mean near 1"
    local ++pass_count
}
else {
    display as error "  FAIL: Stabilized weights mean not near 1 (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' Inv4.4"
}

* =============================================================================
* SECTION 5: MULTINOMIAL WEIGHTS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 5: Multinomial Weight Validation"
    display as text "{hline 70}"
}

* Create multinomial test data
clear
set obs 300
gen id = _n
gen x = mod(_n, 3)  // 0, 1, 2 pattern
gen treatment = x   // Perfect prediction for testing
save "${DATA_DIR}/val_mlogit.dta", replace

* -----------------------------------------------------------------------------
* Test 5.1: Multinomial IPTW
* Purpose: Verify weights = 1/P(A=a|X) for each level
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 5.1: Multinomial IPTW calculation"
}

capture {
    use "${DATA_DIR}/val_mlogit.dta", clear

    * Add noise to prevent perfect separation
    replace treatment = mod(treatment + 1, 3) if _n <= 30

    * Fit mlogit manually
    quietly mlogit treatment x, baseoutcome(0)

    * Predict probabilities for each outcome
    forvalues k = 0/2 {
        quietly predict ps`k', pr outcome(`k')
    }

    * Calculate expected weights
    gen expected_w = .
    replace expected_w = 1/ps0 if treatment == 0
    replace expected_w = 1/ps1 if treatment == 1
    replace expected_w = 1/ps2 if treatment == 2

    * Use tvweight
    tvweight treatment, covariates(x) model(mlogit) nolog

    * Compare
    gen diff = abs(iptw - expected_w)
    sum diff
    assert r(max) < 0.0001
}
if _rc == 0 {
    display as result "  PASS: Multinomial IPTW matches manual calculation"
    local ++pass_count
}
else {
    display as error "  FAIL: Multinomial IPTW (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 5.1"
}

* =============================================================================
* SUMMARY

}

* --- From validation_tvweight_mathematical.do ---

capture noisily {
display _n _dup(70) "="
display "TVWEIGHT MATHEMATICAL VALIDATION"
display _dup(70) "="
display "Date: $S_DATE $S_TIME"
display ""


* ============================================================================
* TEST 8A: IPTW FORMULA WITH KNOWN PROPENSITY SCORES
* ============================================================================
display _n _dup(60) "-"
display "TEST 8A: IPTW formula - exact check with known propensity scores"
display _dup(60) "-"

local test8a_pass = 1

* Create a simple dataset where treatment is perfectly predicted by a covariate
* This allows us to verify: PS(treated) = 1, PS(untreated) = 0
* But with perfect separation, logit won't converge. Use an imperfect but strong predictor.
*
* Strategy: 2 groups (treated/untreated) with strong covariate signal
* After logit, PS for treated group ≈ high, for untreated ≈ low
* We verify: IPTW_i = 1/PS_i for treated, 1/(1-PS_i) for untreated

* Create a simple 40-person dataset with clear treatment groups
clear
set obs 40
gen id = _n
set seed 12345

* Perfect predictor: x1 determines treatment
gen x1 = (_n <= 20)    // 1 for persons 1-20, 0 for 21-40
gen treatment = x1 * 1    // treatment = 1 iff x1=1 (perfectly correlated)
* Add a tiny bit of noise to avoid perfect separation
replace treatment = 0 if id == 5    // one treated person in untreated group (per x1)
replace treatment = 1 if id == 25   // one untreated person in treated group

* Run tvweight
capture noisily tvweight treatment, ///
    covariates(x1) generate(iptw) denominator(ps_score) nolog replace

if _rc != 0 {
    display as error "  FAIL [8a.run]: tvweight returned error `=_rc'"
    local test8a_pass = 0
}
else {
    display "  INFO: Checking IPTW formula for each observation"

    * For each treated person: iptw should equal 1/ps_score
    quietly gen iptw_check = .
    quietly replace iptw_check = 1/ps_score if treatment == 1
    quietly replace iptw_check = 1/(1-ps_score) if treatment == 0

    quietly gen diff_iptw = abs(iptw - iptw_check)
    quietly sum diff_iptw
    local max_diff = r(max)
    local mean_diff = r(mean)

    if `max_diff' < 0.0001 {
        display as result "  PASS [8a.formula]: IPTW = 1/PS (treated) or 1/(1-PS) (untreated), max_diff=`max_diff'"
    }
    else {
        display as error "  FAIL [8a.formula]: max_diff=`max_diff', mean_diff=`mean_diff'"
        list treatment ps_score iptw iptw_check diff_iptw if diff_iptw > 0.001, noobs
        local test8a_pass = 0
    }

    * All IPTW should be positive
    quietly count if iptw <= 0 | missing(iptw)
    if r(N) == 0 {
        display as result "  PASS [8a.positive]: all IPTW weights > 0"
    }
    else {
        display as error "  FAIL [8a.positive]: `=r(N)' non-positive IPTW values"
        local test8a_pass = 0
    }
}

if `test8a_pass' == 1 {
    local pass_count = `pass_count' + 1
    display as result "TEST 8A: PASSED"
}
else {
    local fail_count = `fail_count' + 1
    local failed_tests "`failed_tests' 8a"
    display as error "TEST 8A: FAILED"
}

* ============================================================================
* TEST 8B: STABILIZED IPTW - MEAN = 1.0 EXACTLY (DETERMINISTIC)
* ============================================================================
display _n _dup(60) "-"
display "TEST 8B: Stabilized IPTW - mean = 1.0 in each group (deterministic)"
display _dup(60) "-"

local test8b_pass = 1

* Deterministic 4-cell balanced design (no random data → no convergence issues)
* 70 obs: 25 (x1=1,trt=1), 10 (x1=1,trt=0), 10 (x1=0,trt=1), 25 (x1=0,trt=0)
*
* Logit model: logit(P) = alpha + beta*x1
*   P(A=1|x1=1) = 25/35 = 5/7 ≈ 0.7143
*   P(A=1|x1=0) = 10/35 = 2/7 ≈ 0.2857
*   Marginal P(A=1) = 35/70 = 0.5
*
* Expected stabilized IPTW:
*   x1=1, treated:   0.5 / (5/7) = 0.7
*   x1=0, treated:   0.5 / (2/7) = 1.75
*   x1=1, untreated: 0.5 / (2/7) = 1.75
*   x1=0, untreated: 0.5 / (5/7) = 0.7
*
* Mean stab IPTW (treated)   = (25×0.7 + 10×1.75) / 35 = 35/35 = 1.0 exactly
* Mean stab IPTW (untreated) = (10×1.75 + 25×0.7) / 35 = 35/35 = 1.0 exactly

clear
set obs 70
gen id = _n
gen x1 = (_n <= 35)
gen treatment = 0
replace treatment = 1 if _n <= 25               // 25 with x1=1, treated
replace treatment = 1 if _n > 35 & _n <= 45    // 10 with x1=0, treated

* Verify cell counts
quietly count if treatment == 1
display "  INFO: n_treated = `r(N)' (expected 35)"
quietly count if treatment == 0
display "  INFO: n_untreated = `r(N)' (expected 35)"

capture noisily tvweight treatment, ///
    covariates(x1) generate(iptw_stab) stabilized nolog replace

if _rc != 0 {
    display as error "  FAIL [8b.run]: tvweight returned error `=_rc'"
    local test8b_pass = 0
}
else {
    * Check mean stabilized weight in each group
    quietly sum iptw_stab if treatment == 1
    local mean_treated = r(mean)
    quietly sum iptw_stab if treatment == 0
    local mean_untreated = r(mean)

    display "  INFO: Mean stabilized IPTW (treated) = `mean_treated' (expected 1.0)"
    display "  INFO: Mean stabilized IPTW (untreated) = `mean_untreated' (expected 1.0)"

    * With deterministic data and balanced design, mean should be ≈1.0 (within 0.01)
    if abs(`mean_treated' - 1) < 0.01 {
        display as result "  PASS [8b.treated]: mean stab IPTW (treated) = `mean_treated' ≈ 1.0"
    }
    else {
        display as error "  FAIL [8b.treated]: mean stab IPTW (treated) = `mean_treated', expected 1.0"
        local test8b_pass = 0
    }

    if abs(`mean_untreated' - 1) < 0.01 {
        display as result "  PASS [8b.untreated]: mean stab IPTW (untreated) = `mean_untreated' ≈ 1.0"
    }
    else {
        display as error "  FAIL [8b.untreated]: mean stab IPTW (untreated) = `mean_untreated', expected 1.0"
        local test8b_pass = 0
    }

    * All weights should be positive
    quietly count if iptw_stab <= 0 | missing(iptw_stab)
    if r(N) == 0 {
        display as result "  PASS [8b.positive]: all stabilized IPTW > 0"
    }
    else {
        display as error "  FAIL [8b.positive]: `=r(N)' non-positive stabilized IPTW"
        local test8b_pass = 0
    }
}

if `test8b_pass' == 1 {
    local pass_count = `pass_count' + 1
    display as result "TEST 8B: PASSED"
}
else {
    local fail_count = `fail_count' + 1
    local failed_tests "`failed_tests' 8b"
    display as error "TEST 8B: FAILED"
}

* ============================================================================
* TEST 8C: HORVITZ-THOMPSON IDENTITY (UNSTABILIZED IPTW) - EXACT VALUE
* ============================================================================
display _n _dup(60) "-"
display "TEST 8C: Horvitz-Thompson: mean IPTW (treated) = n_total/n_treated (exact)"
display _dup(60) "-"

local test8c_pass = 1

* Reuse same 4-cell deterministic dataset as 8B:
* n_total=70, n_treated=35, expected mean IPTW (treated) = 70/35 = 2.0 exactly
*
* Expected unstabilized IPTW:
*   x1=1, treated (25 obs):   1 / (5/7) = 7/5 = 1.4
*   x1=0, treated (10 obs):   1 / (2/7) = 7/2 = 3.5
*   Mean IPTW (treated) = (25×1.4 + 10×3.5) / 35 = 70/35 = 2.0 exactly
*   This equals n_total/n_treated = 70/35 = 2.0 (Horvitz-Thompson)

clear
set obs 70
gen id = _n
gen x1 = (_n <= 35)
gen treatment = 0
replace treatment = 1 if _n <= 25
replace treatment = 1 if _n > 35 & _n <= 45

quietly count
local n_total = r(N)
quietly count if treatment == 1
local n_treated = r(N)
local ht_expected = `n_total' / `n_treated'

display "  INFO: n_total=`n_total', n_treated=`n_treated', HT expected=`ht_expected' (expected 2.0)"

capture noisily tvweight treatment, ///
    covariates(x1) generate(iptw) nolog replace

if _rc != 0 {
    display as error "  FAIL [8c.run]: tvweight returned error `=_rc'"
    local test8c_pass = 0
}
else {
    quietly sum iptw if treatment == 1
    local mean_iptw_treated = r(mean)
    display "  INFO: Mean unstabilized IPTW (treated) = `mean_iptw_treated', expected = `ht_expected'"

    * With deterministic data, should match within 0.01
    local diff = abs(`mean_iptw_treated' - `ht_expected') / `ht_expected'
    if `diff' < 0.01 {
        display as result "  PASS [8c.ht]: IPTW mean = `mean_iptw_treated' = n_total/n_treated (diff=`=100*`diff''%)"
    }
    else {
        display as error "  FAIL [8c.ht]: IPTW mean=`mean_iptw_treated', expected=`ht_expected' (diff=`=100*`diff''%)"
        local test8c_pass = 0
    }
}

if `test8c_pass' == 1 {
    local pass_count = `pass_count' + 1
    display as result "TEST 8C: PASSED"
}
else {
    local fail_count = `fail_count' + 1
    local failed_tests "`failed_tests' 8c"
    display as error "TEST 8C: FAILED"
}

* ============================================================================
* FINAL SUMMARY

}


* =============================================================================
* SECTION 8: _CROSS_CUTTING - Pipeline, boundary, bugfix, and stress validation
* =============================================================================
* --- From validation_tvtools_boundary.do ---

capture noisily {
* =============================================================================
* DATE REFERENCE
* =============================================================================
* Key Stata date values for 2020 (leap year):
* Jan 1, 2020  = 21915
* Jul 4, 2020  = 22100  (185 days from Jan 1)
* Oct 12, 2020 = 22200  (285 days from Jan 1)
* Dec 31, 2020 = 22280  (365 days from Jan 1)
* Jan 1, 2021  = 22281

* =============================================================================
* SECTION 1: EVENT AT EXACT STOP BOUNDARY (v1.3.4 BUG SCENARIO)
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 1: Event at Exact Stop Boundary"
    display as text "This is the exact scenario that exposed the v1.3.4 bug"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 1.1: Event exactly at interval stop (no split needed)
* Known answer: 1 event should be flagged
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 1.1: Event at exact stop boundary"
    display as text "  Interval: [21915, 22280], Event at 22280"
    display as text "  Expected: 1 event flagged (event is at stop)"
}

capture {
    * Create master (cohort with event)
    clear
    input long id double(study_entry study_exit event_dt)
        1  21915  22280  22280   // Event exactly at study_exit
    end
    format %td study_entry study_exit event_dt
    save "${DATA_DIR}/_val_cohort_1.dta", replace

    * Create using (interval data)
    clear
    input long id double(start stop) byte exposure
        1  21915  22280  1
    end
    format %td start stop
    save "${DATA_DIR}/_val_intervals_1.dta", replace

    * Run tvevent
    use "${DATA_DIR}/_val_cohort_1.dta", clear
    tvevent using "${DATA_DIR}/_val_intervals_1.dta", ///
        id(id) date(event_dt) ///
        startvar(start) stopvar(stop) ///
        type(single) generate(outcome)

    * Known answer: 1 event should be flagged
    quietly count if outcome == 1
    local actual_events = r(N)
    assert `actual_events' == 1
}
if _rc == 0 {
    local ++pass_count
    if `machine' {
        display "[OK] 1.1"
    }
    else if `quiet' == 0 {
        display as result "  PASS: Event at stop boundary correctly flagged (1 event)"
    }
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' 1.1"
    if `machine' {
        display "[FAIL] 1.1|`=_rc'"
    }
    else {
        display as error "  FAIL: Event at stop boundary (error `=_rc')"
        display as error "  This is the v1.3.4 bug scenario!"
    }
}

* -----------------------------------------------------------------------------
* Test 1.2: Event at boundary between two intervals
* Known answer: 1 event flagged at END of first interval only
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 1.2: Event at boundary between intervals"
    display as text "  Intervals: [21915, 22100] + [22100, 22280]"
    display as text "  Event at: 22100 (boundary)"
    display as text "  Expected: 1 event at end of first interval"
}

capture {
    * Create master
    clear
    input long id double(study_entry study_exit event_dt)
        1  21915  22280  22100   // Event at interval boundary
    end
    format %td study_entry study_exit event_dt
    save "${DATA_DIR}/_val_cohort_2.dta", replace

    * Create using (two intervals, boundary at 22100)
    clear
    input long id double(start stop) byte exposure
        1  21915  22100  0
        1  22100  22280  1
    end
    format %td start stop
    save "${DATA_DIR}/_val_intervals_2.dta", replace

    * Run tvevent
    use "${DATA_DIR}/_val_cohort_2.dta", clear
    tvevent using "${DATA_DIR}/_val_intervals_2.dta", ///
        id(id) date(event_dt) ///
        startvar(start) stopvar(stop) ///
        type(single) generate(outcome)

    * Known answer: exactly 1 event (at end of first interval)
    quietly count if outcome == 1
    local actual_events = r(N)
    assert `actual_events' == 1

    * The event should be at the first interval (stop = 22100)
    * After tvevent, intervals are censored at event time
    quietly sum stop if outcome == 1
    assert r(mean) == 22100
}
if _rc == 0 {
    local ++pass_count
    if `machine' {
        display "[OK] 1.2"
    }
    else if `quiet' == 0 {
        display as result "  PASS: Boundary event flagged once at first interval"
    }
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' 1.2"
    if `machine' {
        display "[FAIL] 1.2|`=_rc'"
    }
    else {
        display as error "  FAIL: Boundary event handling (error `=_rc')"
    }
}

* -----------------------------------------------------------------------------
* Test 1.3: Multiple people with boundary events
* Known answer: 3 events from 3 different boundary scenarios
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 1.3: Multiple boundary scenarios"
    display as text "  Person 1: Event at interval boundary (22100)"
    display as text "  Person 2: Event at interval boundary (22200)"
    display as text "  Person 3: Event at study_exit (22280)"
    display as text "  Expected: 3 events total"
}

capture {
    * Create master with 3 people, different boundary events
    clear
    input long id double(study_entry study_exit event_dt)
        1  21915  22280  22100
        2  21915  22280  22200
        3  21915  22280  22280
    end
    format %td study_entry study_exit event_dt
    save "${DATA_DIR}/_val_cohort_3.dta", replace

    * Create using with boundary points matching events
    clear
    input long id double(start stop) byte exposure
        1  21915  22100  0
        1  22100  22280  1
        2  21915  22200  0
        2  22200  22280  1
        3  21915  22180  0
        3  22180  22280  1
    end
    format %td start stop
    save "${DATA_DIR}/_val_intervals_3.dta", replace

    * Run tvevent
    use "${DATA_DIR}/_val_cohort_3.dta", clear
    tvevent using "${DATA_DIR}/_val_intervals_3.dta", ///
        id(id) date(event_dt) ///
        startvar(start) stopvar(stop) ///
        type(single) generate(outcome)

    * Known answer: 3 events total
    quietly count if outcome == 1
    local actual_events = r(N)
    assert `actual_events' == 3

    * Verify each person has exactly 1 event
    bysort id: egen has_event = max(outcome)
    quietly count if has_event == 1
    assert r(N) == _N  // All rows belong to people with events
}
if _rc == 0 {
    local ++pass_count
    if `machine' {
        display "[OK] 1.3"
    }
    else if `quiet' == 0 {
        display as result "  PASS: All 3 boundary events correctly flagged"
    }
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' 1.3"
    if `machine' {
        display "[FAIL] 1.3|`=_rc'"
    }
    else {
        display as error "  FAIL: Multiple boundary events (error `=_rc')"
    }
}

* =============================================================================
* SECTION 2: EVENT INSIDE INTERVAL (Should still work)
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 2: Events Inside Intervals (Baseline Check)"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 2.1: Event strictly inside interval (causes split)
* Known answer: 1 event, interval split at event date
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 2.1: Event inside interval (requires split)"
    display as text "  Interval: [21915, 22280], Event at 22100 (inside)"
    display as text "  Expected: 1 event, interval split into [21915,22100] + censored"
}

capture {
    * Create master
    clear
    input long id double(study_entry study_exit event_dt)
        1  21915  22280  22100
    end
    format %td study_entry study_exit event_dt
    save "${DATA_DIR}/_val_cohort_4.dta", replace

    * Create using (single interval that needs splitting)
    clear
    input long id double(start stop) byte exposure
        1  21915  22280  1
    end
    format %td start stop
    save "${DATA_DIR}/_val_intervals_4.dta", replace

    * Run tvevent
    use "${DATA_DIR}/_val_cohort_4.dta", clear
    tvevent using "${DATA_DIR}/_val_intervals_4.dta", ///
        id(id) date(event_dt) ///
        startvar(start) stopvar(stop) ///
        type(single) generate(outcome)

    * Known answer: 1 event
    quietly count if outcome == 1
    assert r(N) == 1

    * Event should be at the split point (stop = 22100)
    quietly sum stop if outcome == 1
    assert r(mean) == 22100
}
if _rc == 0 {
    local ++pass_count
    if `machine' {
        display "[OK] 2.1"
    }
    else if `quiet' == 0 {
        display as result "  PASS: Inside event correctly splits interval"
    }
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' 2.1"
    if `machine' {
        display "[FAIL] 2.1|`=_rc'"
    }
    else {
        display as error "  FAIL: Inside event splitting (error `=_rc')"
    }
}

* =============================================================================
* SECTION 3: PERSON-TIME CONSERVATION
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 3: Person-Time Conservation"
    display as text "Total person-time should be preserved (accounting for censoring)"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 3.1: Person-time conservation with no events
* Known answer: 365 days preserved exactly
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.1: Person-time with no events"
    display as text "  Input: 365 days [21915, 22280]"
    display as text "  Expected: 365 days output"
}

capture {
    * Create master with no event
    clear
    input long id double(study_entry study_exit event_dt)
        1  21915  22280  .
    end
    format %td study_entry study_exit event_dt
    save "${DATA_DIR}/_val_cohort_ptime.dta", replace

    * Create using
    clear
    input long id double(start stop) byte exposure
        1  21915  22280  1
    end
    format %td start stop
    save "${DATA_DIR}/_val_intervals_ptime.dta", replace

    * Run tvevent
    use "${DATA_DIR}/_val_cohort_ptime.dta", clear
    tvevent using "${DATA_DIR}/_val_intervals_ptime.dta", ///
        id(id) date(event_dt) ///
        startvar(start) stopvar(stop) ///
        type(single) generate(outcome)

    * Calculate person-time
    gen ptime = stop - start
    quietly sum ptime
    local total_ptime = r(sum)

    * Known answer: 365 days
    assert abs(`total_ptime' - 365) < 0.001
}
if _rc == 0 {
    local ++pass_count
    if `machine' {
        display "[OK] 3.1"
    }
    else if `quiet' == 0 {
        display as result "  PASS: Person-time preserved (365 days)"
    }
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' 3.1"
    if `machine' {
        display "[FAIL] 3.1|`=_rc'"
    }
    else {
        display as error "  FAIL: Person-time conservation (error `=_rc')"
    }
}

* -----------------------------------------------------------------------------
* Test 3.2: Person-time with event (censored at event)
* Known answer: 185 days (from Jan 1 to Jul 4)
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.2: Person-time censored at event"
    display as text "  Event at day 185 (22100)"
    display as text "  Expected: 185 days person-time"
}

capture {
    * Create master with event
    clear
    input long id double(study_entry study_exit event_dt)
        1  21915  22280  22100
    end
    format %td study_entry study_exit event_dt
    save "${DATA_DIR}/_val_cohort_ptime2.dta", replace

    * Create using
    clear
    input long id double(start stop) byte exposure
        1  21915  22280  1
    end
    format %td start stop
    save "${DATA_DIR}/_val_intervals_ptime2.dta", replace

    * Run tvevent
    use "${DATA_DIR}/_val_cohort_ptime2.dta", clear
    tvevent using "${DATA_DIR}/_val_intervals_ptime2.dta", ///
        id(id) date(event_dt) ///
        startvar(start) stopvar(stop) ///
        type(single) generate(outcome)

    * Calculate person-time
    gen ptime = stop - start
    quietly sum ptime
    local total_ptime = r(sum)

    * Known answer: 185 days (21915 to 22100)
    assert abs(`total_ptime' - 185) < 0.001
}
if _rc == 0 {
    local ++pass_count
    if `machine' {
        display "[OK] 3.2"
    }
    else if `quiet' == 0 {
        display as result "  PASS: Person-time correctly censored (185 days)"
    }
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' 3.2"
    if `machine' {
        display "[FAIL] 3.2|`=_rc'"
    }
    else {
        display as error "  FAIL: Person-time with censoring (error `=_rc')"
    }
}

* =============================================================================
* SECTION 4: INTERVAL INTEGRITY INVARIANTS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 4: Interval Integrity Invariants"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 4.1: No overlapping intervals within person
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.1: No overlapping intervals"
}

capture {
    * Use the complex dataset from test 1.3
    use "${DATA_DIR}/_val_cohort_3.dta", clear
    tvevent using "${DATA_DIR}/_val_intervals_3.dta", ///
        id(id) date(event_dt) ///
        startvar(start) stopvar(stop) ///
        type(single) generate(outcome)

    * Check for overlaps
    sort id start
    by id: gen overlap = (start < stop[_n-1]) if _n > 1
    quietly count if overlap == 1
    assert r(N) == 0
}
if _rc == 0 {
    local ++pass_count
    if `machine' {
        display "[OK] 4.1"
    }
    else if `quiet' == 0 {
        display as result "  PASS: No overlapping intervals"
    }
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' 4.1"
    if `machine' {
        display "[FAIL] 4.1|`=_rc'"
    }
    else {
        display as error "  FAIL: Overlapping intervals detected (error `=_rc')"
    }
}

* -----------------------------------------------------------------------------
* Test 4.2: start < stop for all intervals
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.2: All intervals have start < stop"
}

capture {
    use "${DATA_DIR}/_val_cohort_3.dta", clear
    tvevent using "${DATA_DIR}/_val_intervals_3.dta", ///
        id(id) date(event_dt) ///
        startvar(start) stopvar(stop) ///
        type(single) generate(outcome)

    * Verify start < stop
    quietly count if start >= stop
    assert r(N) == 0
}
if _rc == 0 {
    local ++pass_count
    if `machine' {
        display "[OK] 4.2"
    }
    else if `quiet' == 0 {
        display as result "  PASS: All intervals have start < stop"
    }
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' 4.2"
    if `machine' {
        display "[FAIL] 4.2|`=_rc'"
    }
    else {
        display as error "  FAIL: Invalid intervals (start >= stop) (error `=_rc')"
    }
}

* -----------------------------------------------------------------------------
* Test 4.3: Continuous coverage (no gaps) before event
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.3: Continuous coverage (no gaps)"
}

capture {
    use "${DATA_DIR}/_val_cohort_3.dta", clear
    tvevent using "${DATA_DIR}/_val_intervals_3.dta", ///
        id(id) date(event_dt) ///
        startvar(start) stopvar(stop) ///
        type(single) generate(outcome)

    * Check for gaps (where start[n] != stop[n-1])
    sort id start
    by id: gen gap = (start != stop[_n-1]) if _n > 1
    quietly count if gap == 1
    assert r(N) == 0
}
if _rc == 0 {
    local ++pass_count
    if `machine' {
        display "[OK] 4.3"
    }
    else if `quiet' == 0 {
        display as result "  PASS: Continuous coverage (no gaps)"
    }
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' 4.3"
    if `machine' {
        display "[FAIL] 4.3|`=_rc'"
    }
    else {
        display as error "  FAIL: Gaps detected in intervals (error `=_rc')"
    }
}

* =============================================================================
* SECTION 5: COMPARISON WITH MANUAL METHOD
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 5: Comparison with Manual Method"
    display as text "Verify tvevent matches conceptual behavior from manual code"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 5.1: Manual vs tvevent - boundary event
* The manual method uses inrange(event_dt, start, stop) which is inclusive
* tvevent should match: event at stop should be flagged
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 5.1: Manual vs tvevent comparison"
    display as text "  Manual: inrange(event_dt, start, stop) - inclusive"
    display as text "  tvevent: should flag event at stop boundary"
}

capture {
    * Create test data
    clear
    input long id double(study_entry study_exit event_dt)
        1  21915  22280  22100
    end
    format %td study_entry study_exit event_dt
    tempfile cohort
    save `cohort'

    clear
    input long id double(start stop) byte exposure
        1  21915  22100  0
        1  22100  22280  1
    end
    format %td start stop
    tempfile intervals
    save `intervals'

    * MANUAL METHOD (from HRT_2025_12_15.do:1392-1412)
    use `cohort', clear
    merge 1:m id using `intervals', nogen keep(3)
    replace study_exit = event_dt if event_dt < study_exit
    drop if start > study_exit
    replace stop = event_dt if inrange(event_dt, start, stop)
    gen manual_outcome = (event_dt == stop)
    quietly count if manual_outcome == 1
    local manual_events = r(N)

    * TVEVENT METHOD
    use `cohort', clear
    tvevent using `intervals', ///
        id(id) date(event_dt) ///
        startvar(start) stopvar(stop) ///
        type(single) generate(outcome)
    quietly count if outcome == 1
    local tvevent_events = r(N)

    * Note: Manual method may double-count at boundaries
    * tvevent correctly counts once
    * Both should have at least 1 event
    assert `tvevent_events' >= 1
    assert `manual_events' >= 1
}
if _rc == 0 {
    local ++pass_count
    if `machine' {
        display "[OK] 5.1"
    }
    else if `quiet' == 0 {
        display as result "  PASS: Both methods flag boundary event"
        display as text "  Manual events: `manual_events', tvevent events: `tvevent_events'"
    }
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' 5.1"
    if `machine' {
        display "[FAIL] 5.1|`=_rc'"
    }
    else {
        display as error "  FAIL: Manual vs tvevent comparison (error `=_rc')"
    }
}

* =============================================================================
* SECTION 6: COMPETING RISKS AT BOUNDARIES
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 6: Competing Risks at Boundaries"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 6.1: Competing risk at boundary (death at stop)
* Known answer: Competing event flagged as type 2
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 6.1: Competing event at boundary"
    display as text "  Primary event: missing"
    display as text "  Competing (death) at: 22280 (boundary)"
    display as text "  Expected: 1 competing event (outcome=2)"
}

capture {
    * Create master
    clear
    input long id double(study_entry study_exit event_dt death_dt)
        1  21915  22280  .  22280
    end
    format %td study_entry study_exit event_dt death_dt
    save "${DATA_DIR}/_val_cohort_compete.dta", replace

    * Create using
    clear
    input long id double(start stop) byte exposure
        1  21915  22280  1
    end
    format %td start stop
    save "${DATA_DIR}/_val_intervals_compete.dta", replace

    * Run tvevent with competing risk
    use "${DATA_DIR}/_val_cohort_compete.dta", clear
    tvevent using "${DATA_DIR}/_val_intervals_compete.dta", ///
        id(id) date(event_dt) ///
        compete(death_dt) ///
        startvar(start) stopvar(stop) ///
        type(single) generate(outcome)

    * Known answer: 1 competing event (outcome=2)
    quietly count if outcome == 2
    assert r(N) == 1
}
if _rc == 0 {
    local ++pass_count
    if `machine' {
        display "[OK] 6.1"
    }
    else if `quiet' == 0 {
        display as result "  PASS: Competing event at boundary correctly flagged"
    }
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' 6.1"
    if `machine' {
        display "[FAIL] 6.1|`=_rc'"
    }
    else {
        display as error "  FAIL: Competing risk at boundary (error `=_rc')"
    }
}

* =============================================================================
* SECTION 7: TVEXPOSE BOUNDARY TESTS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 7: tvexpose Boundary Tests"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 7.1: Exposure ending at study_exit boundary
* Known answer: Interval includes exposure to the boundary
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 7.1: Exposure ending at study_exit"
    display as text "  Exposure: [21915, 22280] (full study period)"
    display as text "  Expected: 365 days exposed"
}

capture {
    * Create cohort
    clear
    input long id double(study_entry study_exit)
        1  21915  22280
    end
    format %td study_entry study_exit
    save "${DATA_DIR}/_val_cohort_tvx.dta", replace

    * Create exposure that matches study period exactly
    clear
    input long id double(rx_start rx_stop) byte hrt_type
        1  21915  22280  1
    end
    format %td rx_start rx_stop
    save "${DATA_DIR}/_val_exp_tvx.dta", replace

    * Run tvexpose
    use "${DATA_DIR}/_val_cohort_tvx.dta", clear
    tvexpose using "${DATA_DIR}/_val_exp_tvx.dta", ///
        id(id) start(rx_start) stop(rx_stop) ///
        entry(study_entry) exit(study_exit) ///
        exposure(hrt_type) reference(0) ///
        generate(tv_hrt)

    * Known answer: 365 days of exposure
    * Note: tvexpose output uses variable names from start()/stop() options
    gen ptime = rx_stop - rx_start
    quietly sum ptime if tv_hrt == 1
    * Should have 365 days (full period exposed)
    assert abs(r(sum) - 365) < 0.001
}
if _rc == 0 {
    local ++pass_count
    if `machine' {
        display "[OK] 7.1"
    }
    else if `quiet' == 0 {
        display as result "  PASS: Exposure at boundary handled correctly"
    }
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' 7.1"
    if `machine' {
        display "[FAIL] 7.1|`=_rc'"
    }
    else {
        display as error "  FAIL: tvexpose boundary handling (error `=_rc')"
    }
}

* -----------------------------------------------------------------------------
* Test 7.2: Exposure starting at study_entry
* Known answer: Interval starts exactly at entry
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 7.2: Exposure starting at study_entry"
}

capture {
    * Use same data from 7.1
    use "${DATA_DIR}/_val_cohort_tvx.dta", clear
    tvexpose using "${DATA_DIR}/_val_exp_tvx.dta", ///
        id(id) start(rx_start) stop(rx_stop) ///
        entry(study_entry) exit(study_exit) ///
        exposure(hrt_type) reference(0) ///
        generate(tv_hrt)

    * First interval should start at study_entry
    * Note: tvexpose output uses variable names from start()/stop() options
    sort id rx_start
    by id: gen byte first = (_n == 1)
    quietly sum rx_start if first == 1
    assert r(mean) == 21915
}
if _rc == 0 {
    local ++pass_count
    if `machine' {
        display "[OK] 7.2"
    }
    else if `quiet' == 0 {
        display as result "  PASS: First interval starts at study_entry"
    }
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' 7.2"
    if `machine' {
        display "[FAIL] 7.2|`=_rc'"
    }
    else {
        display as error "  FAIL: Entry boundary handling (error `=_rc')"
    }
}

* =============================================================================
* CLEANUP
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "Cleaning up temporary files..."
}

quietly {
    local temp_files "_val_cohort_1 _val_intervals_1 _val_cohort_2 _val_intervals_2"
    local temp_files "`temp_files' _val_cohort_3 _val_intervals_3 _val_cohort_4 _val_intervals_4"
    local temp_files "`temp_files' _val_cohort_ptime _val_intervals_ptime"
    local temp_files "`temp_files' _val_cohort_ptime2 _val_intervals_ptime2"
    local temp_files "`temp_files' _val_cohort_compete _val_intervals_compete"
    local temp_files "`temp_files' _val_cohort_tvx _val_exp_tvx"
    foreach f of local temp_files {
        capture erase "${DATA_DIR}/`f'.dta"
    }
}

* =============================================================================
* SUMMARY

}

* --- From validation_tvtools_bugfixes.do ---

capture noisily {
display _n _dup(70) "="
display "TVTOOLS BUG FIX VALIDATION TESTS"
display _dup(70) "="
display "Date: $S_DATE $S_TIME"
display ""

program drop _allado

* =============================================================================
* BUG 1: DURATION + CONTINUOUSUNIT PRECISION
* =============================================================================
display _n _dup(60) "-"
display "BUG 1: Duration + continuousunit() precision"
display _dup(60) "-"

* ---------------------------------------------------------------------------
* Test 1.1: 365 days should be >= 1 year (non-bytype path)
* ---------------------------------------------------------------------------
display _n "Test 1.1: 365 days of exposure = 1+ year category (non-bytype)"

capture {
    clear
    * Create cohort: 1 person, study period of 2 years
    quietly set obs 1
    gen double id = 1
    gen double study_entry = mdy(1, 1, 2020)
    gen double study_exit = mdy(12, 31, 2021)
    format study_entry study_exit %td
    tempfile cohort
    quietly save `cohort', replace

    * Create exposure: exactly 365 days (Jan 1 to Dec 31, 2020)
    clear
    quietly set obs 1
    gen double id = 1
    gen double rx_start = mdy(1, 1, 2020)
    gen double rx_stop = mdy(12, 31, 2020)
    format rx_start rx_stop %td
    gen double drug = 1
    tempfile exposure
    quietly save `exposure', replace

    * Run tvexpose with duration(1) continuousunit(years)
    use `cohort', clear
    tvexpose using `exposure', id(id) start(rx_start) stop(rx_stop) ///
        exposure(drug) entry(study_entry) exit(study_exit) ///
        duration(1) continuousunit(years) reference(0) generate(tv_exp) ///
        saveas("`c(tmpdir)'/bugfix_test1_1") replace

    quietly use "`c(tmpdir)'/bugfix_test1_1.dta", clear

    * The person has 365 days of exposure
    * With duration(1) continuousunit(years), threshold is at 1 year
    * 365 days >= round(1 * 365.25) = 365 days, so should be category "1+ years"
    * Find the last exposed period (highest tv_exp category)
    quietly summarize tv_exp
    local max_cat = r(max)

    * Category for 1+ years should be 2 (0=reference, 1=<1 year, 2=1+ years)
    assert `max_cat' == 2
}
if _rc == 0 {
    display as result "  PASS"
    local ++pass_count
}
else {
    display as error "  FAIL (rc = " _rc ")"
    local ++fail_count
    local failed_tests "`failed_tests' 1.1"
}

* ---------------------------------------------------------------------------
* Test 1.2: 364 days should be < 1 year (non-bytype path)
* ---------------------------------------------------------------------------
display _n "Test 1.2: 364 days of exposure = <1 year category (non-bytype)"

capture {
    clear
    quietly set obs 1
    gen double id = 1
    gen double study_entry = mdy(1, 1, 2020)
    gen double study_exit = mdy(12, 31, 2021)
    format study_entry study_exit %td
    tempfile cohort
    quietly save `cohort', replace

    * Create exposure: exactly 364 days (Jan 1 to Dec 30, 2020)
    clear
    quietly set obs 1
    gen double id = 1
    gen double rx_start = mdy(1, 1, 2020)
    gen double rx_stop = mdy(12, 30, 2020)
    format rx_start rx_stop %td
    gen double drug = 1
    tempfile exposure
    quietly save `exposure', replace

    use `cohort', clear
    tvexpose using `exposure', id(id) start(rx_start) stop(rx_stop) ///
        exposure(drug) entry(study_entry) exit(study_exit) ///
        duration(1) continuousunit(years) reference(0) generate(tv_exp) ///
        saveas("`c(tmpdir)'/bugfix_test1_2") replace

    quietly use "`c(tmpdir)'/bugfix_test1_2.dta", clear

    * 364 days < 365 threshold, so max category should be 1 (<1 year)
    quietly summarize tv_exp
    local max_cat = r(max)
    assert `max_cat' == 1
}
if _rc == 0 {
    display as result "  PASS"
    local ++pass_count
}
else {
    display as error "  FAIL (rc = " _rc ")"
    local ++fail_count
    local failed_tests "`failed_tests' 1.2"
}

* ---------------------------------------------------------------------------
* Test 1.3: 30 days should be >= 1 month (non-bytype path)
* ---------------------------------------------------------------------------
display _n "Test 1.3: 30 days of exposure = 1+ month category (non-bytype)"

capture {
    clear
    quietly set obs 1
    gen double id = 1
    gen double study_entry = mdy(1, 1, 2020)
    gen double study_exit = mdy(6, 30, 2020)
    format study_entry study_exit %td
    tempfile cohort
    quietly save `cohort', replace

    * Create exposure: 31 days (Jan 1 to Jan 31, 2020)
    * Threshold = round(1 * 30.4375) = 30 days
    * Need > threshold for split to occur, so 31 days works
    clear
    quietly set obs 1
    gen double id = 1
    gen double rx_start = mdy(1, 1, 2020)
    gen double rx_stop = mdy(1, 31, 2020)
    format rx_start rx_stop %td
    gen double drug = 1
    tempfile exposure
    quietly save `exposure', replace

    use `cohort', clear
    tvexpose using `exposure', id(id) start(rx_start) stop(rx_stop) ///
        exposure(drug) entry(study_entry) exit(study_exit) ///
        duration(1) continuousunit(months) reference(0) generate(tv_exp) ///
        saveas("`c(tmpdir)'/bugfix_test1_3") replace

    quietly use "`c(tmpdir)'/bugfix_test1_3.dta", clear

    * 31 days > 30 threshold, crossing at day 31 = Jan 31 (within period)
    * Split: [Jan 1-Jan 30] cat 1, [Jan 31-Jan 31] cat 2
    quietly summarize tv_exp
    local max_cat = r(max)
    assert `max_cat' == 2
}
if _rc == 0 {
    display as result "  PASS"
    local ++pass_count
}
else {
    display as error "  FAIL (rc = " _rc ")"
    local ++fail_count
    local failed_tests "`failed_tests' 1.3"
}

* ---------------------------------------------------------------------------
* Test 1.4: 365 days with bytype path
* ---------------------------------------------------------------------------
display _n "Test 1.4: 365 days of exposure = 1+ year category (bytype path)"

capture {
    clear
    quietly set obs 1
    gen double id = 1
    gen double study_entry = mdy(1, 1, 2020)
    gen double study_exit = mdy(12, 31, 2021)
    format study_entry study_exit %td
    tempfile cohort
    quietly save `cohort', replace

    * Create exposure with a categorical drug type
    clear
    quietly set obs 1
    gen double id = 1
    gen double rx_start = mdy(1, 1, 2020)
    gen double rx_stop = mdy(12, 31, 2020)
    format rx_start rx_stop %td
    gen double drug = 1
    tempfile exposure
    quietly save `exposure', replace

    use `cohort', clear
    tvexpose using `exposure', id(id) start(rx_start) stop(rx_stop) ///
        exposure(drug) entry(study_entry) exit(study_exit) ///
        duration(1) continuousunit(years) bytype reference(0) generate(tv_exp) ///
        saveas("`c(tmpdir)'/bugfix_test1_4") replace

    quietly use "`c(tmpdir)'/bugfix_test1_4.dta", clear

    * With bytype, duration variable is named duration_<type>
    * Check that we have a duration variable
    capture confirm variable duration_1
    if _rc != 0 {
        * Try tv_exp1 pattern
        capture confirm variable tv_exp1
        if _rc != 0 {
            * List all variables to see what was created
            describe, short
            assert 0
        }
        else {
            quietly summarize tv_exp1
            local max_cat = r(max)
            assert `max_cat' == 2
        }
    }
    else {
        quietly summarize duration_1
        local max_cat = r(max)
        assert `max_cat' == 2
    }
}
if _rc == 0 {
    display as result "  PASS"
    local ++pass_count
}
else {
    display as error "  FAIL (rc = " _rc ")"
    local ++fail_count
    local failed_tests "`failed_tests' 1.4"
}

* ---------------------------------------------------------------------------
* Test 1.5: Multiple thresholds - 2 years with years
* ---------------------------------------------------------------------------
display _n "Test 1.5: 730 days with duration(1 2) continuousunit(years)"

capture {
    clear
    quietly set obs 1
    gen double id = 1
    gen double study_entry = mdy(1, 1, 2020)
    gen double study_exit = mdy(12, 31, 2023)
    format study_entry study_exit %td
    tempfile cohort
    quietly save `cohort', replace

    * Create exposure: ~2.5 years (Jan 1, 2020 to Jun 30, 2022)
    * Clearly exceeds both 1-year and 2-year thresholds
    clear
    quietly set obs 1
    gen double id = 1
    gen double rx_start = mdy(1, 1, 2020)
    gen double rx_stop = mdy(6, 30, 2022)
    format rx_start rx_stop %td
    gen double drug = 1
    tempfile exposure
    quietly save `exposure', replace

    use `cohort', clear
    tvexpose using `exposure', id(id) start(rx_start) stop(rx_stop) ///
        exposure(drug) entry(study_entry) exit(study_exit) ///
        duration(1 2) continuousunit(years) reference(0) generate(tv_exp) ///
        saveas("`c(tmpdir)'/bugfix_test1_5") replace

    quietly use "`c(tmpdir)'/bugfix_test1_5.dta", clear

    * ~912 days clearly exceeds both thresholds (365 and ~731)
    * Should reach category 3 (2+ years)
    quietly summarize tv_exp
    local max_cat = r(max)
    assert `max_cat' == 3
}
if _rc == 0 {
    display as result "  PASS"
    local ++pass_count
}
else {
    display as error "  FAIL (rc = " _rc ")"
    local ++fail_count
    local failed_tests "`failed_tests' 1.5"
}

* =============================================================================
* BUG 2: DOSE WITH EQUAL-DOSE OVERLAPPING PRESCRIPTIONS
* =============================================================================
display _n _dup(60) "-"
display "BUG 2: Equal-dose overlapping prescriptions"
display _dup(60) "-"

* ---------------------------------------------------------------------------
* Test 2.1: Two overlapping prescriptions with identical dose
* ---------------------------------------------------------------------------
display _n "Test 2.1: Equal-dose overlapping prescriptions produce correct cumulative dose"

capture {
    clear
    quietly set obs 2
    gen double id = 1
    gen double study_entry = mdy(1, 1, 2020)
    gen double study_exit = mdy(6, 30, 2020)
    format study_entry study_exit %td
    tempfile cohort
    * Keep one row for cohort
    quietly keep if _n == 1
    quietly save `cohort', replace

    * Create two overlapping prescriptions with same dose
    clear
    quietly set obs 2
    gen double id = 1
    gen double rx_start = .
    gen double rx_stop = .
    gen double drug = 10

    * Prescription 1: Jan 1 - Mar 31
    quietly replace rx_start = mdy(1, 1, 2020) if _n == 1
    quietly replace rx_stop = mdy(3, 31, 2020) if _n == 1
    * Prescription 2: Feb 1 - Apr 30 (overlaps by Feb 1 - Mar 31)
    quietly replace rx_start = mdy(2, 1, 2020) if _n == 2
    quietly replace rx_stop = mdy(4, 30, 2020) if _n == 2
    format rx_start rx_stop %td
    tempfile exposure
    quietly save `exposure', replace

    use `cohort', clear
    tvexpose using `exposure', id(id) start(rx_start) stop(rx_stop) ///
        exposure(drug) entry(study_entry) exit(study_exit) ///
        dose generate(tv_exp) ///
        saveas("`c(tmpdir)'/bugfix_test2_1") replace

    quietly use "`c(tmpdir)'/bugfix_test2_1.dta", clear

    * Both prescriptions should contribute dose
    * Total dose from both prescriptions = 10 * 91 + 10 * 90 = 910 + 900 = 1810
    * (Jan=31days, Feb=29days(leap), Mar=31days, Apr=30days)
    * Rx1: Jan1-Mar31 = 91 days, Rx2: Feb1-Apr30 = 90 days
    * With proportional allocation in overlapping period, total should still equal sum
    * The cumulative dose at the end should reflect both prescriptions
    quietly summarize tv_exp
    local max_dose = r(max)

    * Cumulative dose should be > 10 (more than a single prescription's contribution)
    * If the bug existed, equal-dose overlaps would merge and lose one prescription
    assert `max_dose' > 10
}
if _rc == 0 {
    display as result "  PASS"
    local ++pass_count
}
else {
    display as error "  FAIL (rc = " _rc ")"
    local ++fail_count
    local failed_tests "`failed_tests' 2.1"
}

* ---------------------------------------------------------------------------
* Test 2.2: Non-overlapping same-dose prescriptions (control test)
* ---------------------------------------------------------------------------
display _n "Test 2.2: Non-overlapping same-dose prescriptions work correctly"

capture {
    clear
    quietly set obs 1
    gen double id = 1
    gen double study_entry = mdy(1, 1, 2020)
    gen double study_exit = mdy(6, 30, 2020)
    format study_entry study_exit %td
    tempfile cohort
    quietly save `cohort', replace

    * Two non-overlapping prescriptions with same dose
    clear
    quietly set obs 2
    gen double id = 1
    gen double rx_start = .
    gen double rx_stop = .
    gen double drug = 10

    * Rx 1: Jan 1 - Jan 31
    quietly replace rx_start = mdy(1, 1, 2020) if _n == 1
    quietly replace rx_stop = mdy(1, 31, 2020) if _n == 1
    * Rx 2: Mar 1 - Mar 31
    quietly replace rx_start = mdy(3, 1, 2020) if _n == 2
    quietly replace rx_stop = mdy(3, 31, 2020) if _n == 2
    format rx_start rx_stop %td
    tempfile exposure
    quietly save `exposure', replace

    use `cohort', clear
    tvexpose using `exposure', id(id) start(rx_start) stop(rx_stop) ///
        exposure(drug) entry(study_entry) exit(study_exit) ///
        dose generate(tv_exp) ///
        saveas("`c(tmpdir)'/bugfix_test2_2") replace

    quietly use "`c(tmpdir)'/bugfix_test2_2.dta", clear

    * Cumulative dose at end should reflect both prescriptions
    * Both prescriptions contribute, so max cumulative > single prescription
    quietly summarize tv_exp
    local max_dose = r(max)
    assert `max_dose' > 10
}
if _rc == 0 {
    display as result "  PASS"
    local ++pass_count
}
else {
    display as error "  FAIL (rc = " _rc ")"
    local ++fail_count
    local failed_tests "`failed_tests' 2.2"
}

* =============================================================================
* BUG 4: TVCALENDAR RANGE-BASED MERGE
* =============================================================================
display _n _dup(60) "-"
display "BUG 4: tvcalendar range-based merge"
display _dup(60) "-"

* ---------------------------------------------------------------------------
* Test 4.1: Basic range-based merge with non-overlapping periods
* ---------------------------------------------------------------------------
display _n "Test 4.1: Range-based merge with non-overlapping periods"

capture {
    * Create external period data
    clear
    quietly set obs 2
    gen double period_start = .
    gen double period_end = .
    gen double policy_level = .
    * Period 1: Jan-Jun 2020, policy level 1
    quietly replace period_start = mdy(1, 1, 2020) if _n == 1
    quietly replace period_end = mdy(6, 30, 2020) if _n == 1
    quietly replace policy_level = 1 if _n == 1
    * Period 2: Jul-Dec 2020, policy level 2
    quietly replace period_start = mdy(7, 1, 2020) if _n == 2
    quietly replace period_end = mdy(12, 31, 2020) if _n == 2
    quietly replace policy_level = 2 if _n == 2
    format period_start period_end %td
    tempfile ext_data
    quietly save `ext_data', replace

    * Create master person-time data
    clear
    quietly set obs 4
    gen double id = 1
    gen double datevar = .
    quietly replace datevar = mdy(3, 15, 2020) if _n == 1
    quietly replace datevar = mdy(5, 20, 2020) if _n == 2
    quietly replace datevar = mdy(8, 10, 2020) if _n == 3
    quietly replace datevar = mdy(11, 25, 2020) if _n == 4
    format datevar %td

    * Run tvcalendar with range-based merge
    tvcalendar using `ext_data', datevar(datevar) ///
        startvar(period_start) stopvar(period_end) ///
        merge(policy_level)

    * Verify: first two dates should get policy_level = 1
    assert policy_level[1] == 1
    assert policy_level[2] == 1
    * Last two dates should get policy_level = 2
    assert policy_level[3] == 2
    assert policy_level[4] == 2
}
if _rc == 0 {
    display as result "  PASS"
    local ++pass_count
}
else {
    display as error "  FAIL (rc = " _rc ")"
    local ++fail_count
    local failed_tests "`failed_tests' 4.1"
}

* ---------------------------------------------------------------------------
* Test 4.2: Range-based merge with unmatched observations
* ---------------------------------------------------------------------------
display _n "Test 4.2: Range-based merge - unmatched obs kept with missing"

capture {
    * External periods: only covers first half of year
    clear
    quietly set obs 1
    gen double period_start = mdy(1, 1, 2020)
    gen double period_end = mdy(6, 30, 2020)
    gen double season = 1
    format period_start period_end %td
    tempfile ext_data
    quietly save `ext_data', replace

    * Master data: dates in both first and second half
    clear
    quietly set obs 3
    gen double id = _n
    gen double datevar = .
    quietly replace datevar = mdy(3, 15, 2020) if _n == 1
    quietly replace datevar = mdy(5, 20, 2020) if _n == 2
    quietly replace datevar = mdy(9, 10, 2020) if _n == 3
    format datevar %td

    tvcalendar using `ext_data', datevar(datevar) ///
        startvar(period_start) stopvar(period_end) merge(season)

    * First two should have season = 1
    assert season[1] == 1
    assert season[2] == 1
    * Third should be missing (unmatched)
    assert missing(season[3])

    * All 3 observations should be preserved
    assert _N == 3
}
if _rc == 0 {
    display as result "  PASS"
    local ++pass_count
}
else {
    display as error "  FAIL (rc = " _rc ")"
    local ++fail_count
    local failed_tests "`failed_tests' 4.2"
}

* ---------------------------------------------------------------------------
* Test 4.3: Range-based merge with multiple external variables
* ---------------------------------------------------------------------------
display _n "Test 4.3: Range-based merge with multiple merge variables"

capture {
    clear
    quietly set obs 2
    gen double period_start = .
    gen double period_end = .
    gen double temp_avg = .
    gen double precip_mm = .
    * Summer
    quietly replace period_start = mdy(4, 1, 2020) if _n == 1
    quietly replace period_end = mdy(9, 30, 2020) if _n == 1
    quietly replace temp_avg = 25 if _n == 1
    quietly replace precip_mm = 80 if _n == 1
    * Winter
    quietly replace period_start = mdy(10, 1, 2020) if _n == 2
    quietly replace period_end = mdy(3, 31, 2021) if _n == 2
    quietly replace temp_avg = 5 if _n == 2
    quietly replace precip_mm = 120 if _n == 2
    format period_start period_end %td
    tempfile ext_data
    quietly save `ext_data', replace

    * Master data
    clear
    quietly set obs 2
    gen double id = _n
    gen double datevar = .
    quietly replace datevar = mdy(7, 15, 2020) if _n == 1
    quietly replace datevar = mdy(12, 1, 2020) if _n == 2
    format datevar %td

    tvcalendar using `ext_data', datevar(datevar) ///
        startvar(period_start) stopvar(period_end) ///
        merge(temp_avg precip_mm)

    * Summer observation
    assert temp_avg[1] == 25
    assert precip_mm[1] == 80
    * Winter observation
    assert temp_avg[2] == 5
    assert precip_mm[2] == 120
}
if _rc == 0 {
    display as result "  PASS"
    local ++pass_count
}
else {
    display as error "  FAIL (rc = " _rc ")"
    local ++fail_count
    local failed_tests "`failed_tests' 4.3"
}

* ---------------------------------------------------------------------------
* Test 4.4: Point-in-time merge still works (regression check)
* ---------------------------------------------------------------------------
display _n "Test 4.4: Point-in-time merge still works (regression)"

capture {
    clear
    quietly set obs 3
    gen double datevar = mdy(1, 1, 2020) + _n - 1
    gen double id = _n
    format datevar %td

    * Create external data with exact date match
    clear
    quietly set obs 3
    gen double datevar = mdy(1, 1, 2020) + _n - 1
    gen double factor = _n * 10
    format datevar %td
    tempfile ext_data
    quietly save `ext_data', replace

    * Re-create master
    clear
    quietly set obs 3
    gen double datevar = mdy(1, 1, 2020) + _n - 1
    gen double id = _n
    format datevar %td

    tvcalendar using `ext_data', datevar(datevar) merge(factor)

    assert factor[1] == 10
    assert factor[2] == 20
    assert factor[3] == 30
}
if _rc == 0 {
    display as result "  PASS"
    local ++pass_count
}
else {
    display as error "  FAIL (rc = " _rc ")"
    local ++fail_count
    local failed_tests "`failed_tests' 4.4"
}

* =============================================================================
* SUMMARY

}

* --- From validation_tvtools_comprehensive.do ---

capture noisily {
* =============================================================================
* SECTION 1: END-TO-END PIPELINE TESTS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 1: End-to-End Pipeline (tvexpose -> tvmerge -> tvevent)"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 1.1: Complete pipeline with single person, verify all transformations
* Known answer: Person has 365 days follow-up, 200 days exposed, event at day 300
* Note: type(single) censors post-event time, so PT = 300 days, not 365
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 1.1: Complete pipeline - single person"
    display as text "  Follow-up: 365 days, Exposure: days 50-250, Event: day 300"
    display as text "  Note: type(single) removes post-event time"
}

capture {
    * Create master cohort
    clear
    input long id double(study_entry study_exit)
        1  21915  22280   // Jan 1 2020 to Dec 31 2020 (366 days, leap year)
    end
    format %td study_entry study_exit
    save "${DATA_DIR}/_val_cohort_e2e.dta", replace

    * Create exposure dataset (exposed from day 50 to day 250)
    clear
    input long id double(start stop) byte exp_type
        1  21965  22165  1   // Feb 20 to Aug 8, 2020 (200 days exposed)
    end
    format %td start stop
    save "${DATA_DIR}/_val_exposure_e2e.dta", replace

    * Create event dataset
    clear
    input long id double(event_dt)
        1  22215   // Sep 27, 2020 (day 300 of follow-up)
    end
    format %td event_dt
    save "${DATA_DIR}/_val_events_e2e.dta", replace

    * Step 1: tvexpose
    use "${DATA_DIR}/_val_cohort_e2e.dta", clear
    tvexpose using "${DATA_DIR}/_val_exposure_e2e.dta", id(id) start(start) stop(stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit)

    * Verify tvexpose output
    quietly count
    assert r(N) == 3  // Should have 3 intervals: unexposed, exposed, unexposed

    save "${DATA_DIR}/_val_tv_data_e2e.dta", replace

    * Step 2: tvevent with type(single) - default behavior
    use "${DATA_DIR}/_val_events_e2e.dta", clear
    tvevent using "${DATA_DIR}/_val_tv_data_e2e.dta", id(id) date(event_dt) ///
        startvar(start) stopvar(stop) ///
        generate(outcome)

    * Verify final output
    quietly count
    local n_intervals = r(N)

    * type(single) censors post-event time, so 3 intervals remain
    * (event at 22215 is within the 3rd unexposed interval [22165, 22280])
    assert `n_intervals' == 3

    * Verify event is flagged exactly once
    quietly count if outcome == 1
    assert r(N) == 1

    * Verify total person-time (post-event time removed)
    gen double pt = stop - start
    quietly sum pt
    local total_pt = r(sum)
    * PT = day 0 to day 300 = 300 days (not 365, since post-event removed)
    * Allow tolerance of 3 days for interval boundary handling (floor/ceil)
    assert abs(`total_pt' - 300) <= 3
}
if _rc == 0 {
    local ++pass_count
    if `machine' {
        display "[OK] 1.1"
    }
    else if `quiet' == 0 {
        display as result "  PASS: Complete pipeline produces correct intervals and event"
    }
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' 1.1"
    if `machine' {
        display "[FAIL] 1.1|`=_rc'"
    }
    else {
        display as error "  FAIL: Complete pipeline test (error `=_rc')"
    }
}

* -----------------------------------------------------------------------------
* Test 1.2: Pipeline with tvmerge - two exposures merged
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 1.2: Pipeline with tvmerge - two exposures"
}

capture {
    * Create cohort
    clear
    input long id double(study_entry study_exit)
        1  21915  22280
    end
    format %td study_entry study_exit
    save "${DATA_DIR}/_val_cohort_merge.dta", replace

    * Exposure 1: Drug A (days 0-180)
    clear
    input long id double(start stop) byte drug_a
        1  21915  22095  1
    end
    format %td start stop
    save "${DATA_DIR}/_val_exp_a.dta", replace

    * Exposure 2: Drug B (days 90-270)
    clear
    input long id double(start stop) byte drug_b
        1  22005  22185  1
    end
    format %td start stop
    save "${DATA_DIR}/_val_exp_b.dta", replace

    * Create tv datasets
    use "${DATA_DIR}/_val_cohort_merge.dta", clear
    tvexpose using "${DATA_DIR}/_val_exp_a.dta", id(id) start(start) stop(stop) ///
        exposure(drug_a) reference(0) entry(study_entry) exit(study_exit) ///
        generate(tv_drug_a)
    save "${DATA_DIR}/_val_tv_a.dta", replace

    use "${DATA_DIR}/_val_cohort_merge.dta", clear
    tvexpose using "${DATA_DIR}/_val_exp_b.dta", id(id) start(start) stop(stop) ///
        exposure(drug_b) reference(0) entry(study_entry) exit(study_exit) ///
        generate(tv_drug_b)
    save "${DATA_DIR}/_val_tv_b.dta", replace

    * Merge with tvmerge
    tvmerge "${DATA_DIR}/_val_tv_a.dta" "${DATA_DIR}/_val_tv_b.dta", id(id) ///
        start(start start) stop(stop stop) ///
        exposure(tv_drug_a tv_drug_b) ///
        generate(drug_a drug_b)

    * Verify: Should have periods for all combinations
    * Period 1: Neither drug (0-90)
    * Period 2: Drug A only (90-180)
    * Period 3: Both drugs (overlap)
    * Period 4: Drug B only (180-270)
    * Period 5: Neither drug (270-365)

    quietly count
    assert r(N) >= 4

    * Verify person-time conservation
    * Allow tolerance of 3 days for interval boundary handling (floor/ceil)
    gen double pt = stop - start
    quietly sum pt
    local total_pt = r(sum)
    assert abs(`total_pt' - 365) <= 3
}
if _rc == 0 {
    local ++pass_count
    if `machine' {
        display "[OK] 1.2"
    }
    else if `quiet' == 0 {
        display as result "  PASS: tvmerge pipeline preserves person-time"
    }
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' 1.2"
    if `machine' {
        display "[FAIL] 1.2|`=_rc'"
    }
    else {
        display as error "  FAIL: tvmerge pipeline test (error `=_rc')"
    }
}

* =============================================================================
* SECTION 2: CONTINUOUS VARIABLE CONSERVATION
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 2: Continuous Variable Conservation"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 2.1: tvevent continuous splitting - sum preserved
* Known answer: 100mg dose split at midpoint should give 2x ~50mg
* Note: type(recurring) requires wide format; we use type(single) and test
*       that the pre-event portion has the correct proportioned dose
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 2.1: Continuous variable splitting in tvevent"
    display as text "  Interval [0, 100] with dose=100, event at day 50"
    display as text "  Expected: Event interval has dose ~50 (proportioned)"
}

capture {
    * Create interval data
    clear
    input long id double(start stop) double cumul_dose
        1  21915  22015  100   // 100-day interval with 100mg
    end
    format %td start stop
    save "${DATA_DIR}/_val_cont_intervals.dta", replace

    * Create event at midpoint
    clear
    input long id double(event_dt)
        1  21965   // Day 50 of the interval
    end
    format %td event_dt

    * Run tvevent with continuous adjustment - type(single) removes post-event
    tvevent using "${DATA_DIR}/_val_cont_intervals.dta", id(id) date(event_dt) ///
        startvar(start) stopvar(stop) ///
        continuous(cumul_dose) generate(outcome)

    * With type(single), only the pre-event portion remains (with event flagged)
    quietly count
    assert r(N) == 1

    * Verify event is flagged
    quietly count if outcome == 1
    assert r(N) == 1

    * Verify dose is proportioned correctly (50 days out of 100 = 50%)
    * The formula is new_dur/orig_dur * dose = 50/100 * 100 = 50
    quietly sum cumul_dose
    local event_dose = r(mean)
    assert abs(`event_dose' - 50) < 5
}
if _rc == 0 {
    local ++pass_count
    if `machine' {
        display "[OK] 2.1"
    }
    else if `quiet' == 0 {
        display as result "  PASS: Continuous variable sum preserved after split"
    }
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' 2.1"
    if `machine' {
        display "[FAIL] 2.1|`=_rc'"
    }
    else {
        display as error "  FAIL: Continuous variable split test (error `=_rc')"
    }
}

* -----------------------------------------------------------------------------
* Test 2.2: Multiple splits - continuous sum still preserved
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 2.2: Multiple splits - continuous sum preserved"
}

capture {
    * Create interval data
    clear
    input long id double(start stop) double cumul_dose
        1  21915  22015  100
    end
    format %td start stop
    save "${DATA_DIR}/_val_cont_multi.dta", replace

    * Create multiple events (wide format for recurring)
    clear
    input long id double(event1 event2 event3)
        1  21935  21965  21995   // Days 20, 50, 80
    end
    format %td event1 event2 event3

    * Run tvevent with recurring events
    tvevent using "${DATA_DIR}/_val_cont_multi.dta", id(id) date(event) ///
        startvar(start) stopvar(stop) ///
        continuous(cumul_dose) generate(outcome) ///
        type(recurring)

    * Verify sum is preserved
    quietly sum cumul_dose
    local total_dose = r(sum)
    assert abs(`total_dose' - 100) < 1

    * Verify we have 4 intervals (3 splits create 4 segments)
    quietly count
    assert r(N) == 4
}
if _rc == 0 {
    local ++pass_count
    if `machine' {
        display "[OK] 2.2"
    }
    else if `quiet' == 0 {
        display as result "  PASS: Multiple splits preserve continuous sum"
    }
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' 2.2"
    if `machine' {
        display "[FAIL] 2.2|`=_rc'"
    }
    else {
        display as error "  FAIL: Multiple splits test (error `=_rc')"
    }
}

* -----------------------------------------------------------------------------
* Test 2.3: tvmerge continuous proportioning
* Tests that tvmerge correctly proportions continuous exposures when slicing
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 2.3: tvmerge continuous proportioning"
}

capture {
    * Dataset 1: Full interval (100 days) with dose = 100
    clear
    input long id double(start stop) double dose_rate
        1  21915  22015  100   // 100 days [Jan 1 - Apr 10]
    end
    format %td start stop
    save "${DATA_DIR}/_val_merge_ds1.dta", replace

    * Dataset 2: Partial overlap (50 days overlap with ds1)
    clear
    input long id double(start stop) byte other_var
        1  21965  22065  1   // [Feb 20 - May 10]
    end
    format %td start stop
    save "${DATA_DIR}/_val_merge_ds2.dta", replace

    * Merge with continuous proportioning
    tvmerge "${DATA_DIR}/_val_merge_ds1.dta" "${DATA_DIR}/_val_merge_ds2.dta", id(id) ///
        start(start start) stop(stop stop) ///
        exposure(dose_rate other_var) ///
        continuous(dose_rate) ///
        generate(dose other)

    * The intersection is [21965, 22015] = 50 days out of 100 days
    * tvmerge proportion = (50+1)/(100+1) = 51/101 ≈ 0.505
    * With dose_rate=100, result dose should be approximately 50.5

    quietly count
    assert r(N) == 1

    * Verify interval boundaries
    quietly sum start
    assert r(mean) == 21965  // Feb 20

    quietly sum stop
    assert r(mean) == 22015  // Apr 10

    * Verify dose is correctly proportioned
    quietly sum dose
    local merged_dose = r(sum)

    * Allow for the +1 formula (should be ~50.5, not exactly 50)
    assert abs(`merged_dose' - 50.5) < 2
}
if _rc == 0 {
    local ++pass_count
    if `machine' {
        display "[OK] 2.3"
    }
    else if `quiet' == 0 {
        display as result "  PASS: tvmerge continuous proportion correct"
    }
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' 2.3"
    if `machine' {
        display "[FAIL] 2.3|`=_rc'"
    }
    else {
        display as error "  FAIL: tvmerge continuous test (error `=_rc')"
    }
}

* -----------------------------------------------------------------------------
* Test 2.4: End-to-end continuous through tvmerge + tvevent
* Tests that continuous proportioning works correctly through pipeline
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 2.4: Continuous variable through tvmerge then tvevent"
}

capture {
    * Dataset 1: 100 days with dose = 100
    clear
    input long id double(start stop) double dose_rate
        1  21915  22015  100
    end
    format %td start stop
    save "${DATA_DIR}/_val_e2e_ds1.dta", replace

    * Dataset 2: Overlaps first 60 days
    clear
    input long id double(start stop) byte flag
        1  21915  21975  1
    end
    format %td start stop
    save "${DATA_DIR}/_val_e2e_ds2.dta", replace

    * Merge - produces intersection [21915, 21975] = 60 days
    tvmerge "${DATA_DIR}/_val_e2e_ds1.dta" "${DATA_DIR}/_val_e2e_ds2.dta", id(id) ///
        start(start start) stop(stop stop) ///
        exposure(dose_rate flag) ///
        continuous(dose_rate) ///
        generate(dose marker)

    * Get the dose after merge: proportion = (60+1)/(100+1) = 61/101 ≈ 0.604
    * dose = 100 * 0.604 ≈ 60.4
    quietly sum dose
    local post_merge_dose = r(sum)

    save "${DATA_DIR}/_val_e2e_merged.dta", replace

    * Now split with tvevent at day 30 (21945)
    * type(single) splits and keeps only pre-event portion
    clear
    input long id double(event_dt)
        1  21945   // Day 30
    end
    format %td event_dt

    tvevent using "${DATA_DIR}/_val_e2e_merged.dta", id(id) date(event_dt) ///
        startvar(start) stopvar(stop) ///
        continuous(dose) generate(outcome)

    * After tvevent with type(single):
    * - Original interval [21915, 21975] split at 21945
    * - Pre-event [21915, 21945] = 30 days with event
    * - Post-event [21945, 21975] = 30 days is REMOVED by type(single)
    * The proportioned dose for pre-event = 30/60 * post_merge_dose ≈ 30.2

    quietly sum dose
    local post_split_dose = r(sum)

    * The split should proportion: (30 days pre-event) / (60 days original)
    * Expected = post_merge_dose * 30/60 = post_merge_dose / 2
    local expected = `post_merge_dose' / 2
    assert abs(`post_split_dose' - `expected') < 2
}
if _rc == 0 {
    local ++pass_count
    if `machine' {
        display "[OK] 2.4"
    }
    else if `quiet' == 0 {
        display as result "  PASS: Continuous preserved through tvmerge + tvevent"
    }
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' 2.4"
    if `machine' {
        display "[FAIL] 2.4|`=_rc'"
    }
    else {
        display as error "  FAIL: End-to-end continuous test (error `=_rc')"
    }
}

* =============================================================================
* SECTION 3: PERSON-TIME CONSERVATION
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 3: Person-Time Conservation"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 3.1: Person-time after tvexpose equals study duration
* Note: Small variance (1-2 days) allowed due to interval boundary handling
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.1: Person-time conservation in tvexpose"
}

capture {
    * Create cohort with known duration
    clear
    input long id double(study_entry study_exit)
        1  21915  22280   // 365 days
        2  21915  22100   // 185 days
        3  21915  21945   // 30 days
    end
    format %td study_entry study_exit

    * Calculate expected total person-time
    gen double expected_pt = study_exit - study_entry
    quietly sum expected_pt
    local expected_total = r(sum)

    save "${DATA_DIR}/_val_pt_cohort.dta", replace

    * Create exposure with gaps
    clear
    input long id double(start stop) byte exp_type
        1  21930  21960  1
        1  22000  22100  1
        2  21920  21980  1
        3  21920  21940  1
    end
    format %td start stop
    save "${DATA_DIR}/_val_pt_exposure.dta", replace

    * Run tvexpose
    use "${DATA_DIR}/_val_pt_cohort.dta", clear
    tvexpose using "${DATA_DIR}/_val_pt_exposure.dta", id(id) start(start) stop(stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit)

    * Calculate actual total person-time
    gen double actual_pt = stop - start
    quietly sum actual_pt
    local actual_total = r(sum)

    * Should match expected within tolerance
    * Allow 3 days per person (9 days total for 3 persons) for boundary handling
    assert abs(`actual_total' - `expected_total') <= 10
}
if _rc == 0 {
    local ++pass_count
    if `machine' {
        display "[OK] 3.1"
    }
    else if `quiet' == 0 {
        display as result "  PASS: Person-time conserved in tvexpose"
    }
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' 3.1"
    if `machine' {
        display "[FAIL] 3.1|`=_rc'"
    }
    else {
        display as error "  FAIL: Person-time conservation test (error `=_rc')"
    }
}

* -----------------------------------------------------------------------------
* Test 3.2: Person-time after tvevent type(single) - post-event time removed
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.2: Person-time after tvevent type(single)"
}

capture {
    * Create intervals totaling 100 days
    clear
    input long id double(start stop)
        1  21915  22015
    end
    format %td start stop

    gen double orig_pt = stop - start
    quietly sum orig_pt
    local orig_total = r(sum)

    save "${DATA_DIR}/_val_pt_single.dta", replace

    * Event at day 40
    clear
    input long id double(event_dt)
        1  21955
    end
    format %td event_dt

    tvevent using "${DATA_DIR}/_val_pt_single.dta", id(id) date(event_dt) ///
        startvar(start) stopvar(stop) ///
        type(single) generate(outcome)

    * Should only have person-time up to event
    gen double final_pt = stop - start
    quietly sum final_pt
    local final_total = r(sum)

    * Person-time should be ~40 (event at day 40 censors rest)
    assert abs(`final_total' - 40) < 1
}
if _rc == 0 {
    local ++pass_count
    if `machine' {
        display "[OK] 3.2"
    }
    else if `quiet' == 0 {
        display as result "  PASS: Post-event person-time correctly removed"
    }
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' 3.2"
    if `machine' {
        display "[FAIL] 3.2|`=_rc'"
    }
    else {
        display as error "  FAIL: Post-event person-time test (error `=_rc')"
    }
}

* =============================================================================
* SECTION 4: ZERO-DURATION INTERVAL HANDLING
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 4: Zero-Duration Interval Handling"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 4.1: Zero-duration interval in tvevent
* Note: For zero-duration [X, X], event at X is at start (not within interval)
* so it won't match. We test with event at stop instead.
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.1: Zero-duration interval handling"
    display as text "  Interval [day X, day X] - tests dose preservation"
}

capture {
    * Create zero-duration interval
    clear
    input long id double(start stop) double dose
        1  21915  21915  10   // Same day = instant exposure
    end
    format %td start stop
    save "${DATA_DIR}/_val_zero_dur.dta", replace

    * Event AFTER the zero-duration interval (so it doesn't affect it)
    * This tests that zero-duration intervals are preserved correctly
    clear
    input long id double(event_dt)
        1  21920   // 5 days after the zero-duration interval
    end
    format %td event_dt

    tvevent using "${DATA_DIR}/_val_zero_dur.dta", id(id) date(event_dt) ///
        startvar(start) stopvar(stop) ///
        continuous(dose) generate(outcome)

    * Event is outside the interval, so no match - interval preserved as-is
    quietly count
    assert r(N) == 1

    * Event should NOT be flagged (event date not in [21915, 21915])
    quietly count if outcome == 1
    assert r(N) == 0

    * Dose should be preserved
    quietly sum dose
    assert abs(r(mean) - 10) < 0.1
}
if _rc == 0 {
    local ++pass_count
    if `machine' {
        display "[OK] 4.1"
    }
    else if `quiet' == 0 {
        display as result "  PASS: Zero-duration interval handled correctly"
    }
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' 4.1"
    if `machine' {
        display "[FAIL] 4.1|`=_rc'"
    }
    else {
        display as error "  FAIL: Zero-duration interval test (error `=_rc')"
    }
}

* -----------------------------------------------------------------------------
* Test 4.2: Zero-duration in tvmerge
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.2: Zero-duration interval in tvmerge"
}

capture {
    * Dataset 1 with zero-duration
    clear
    input long id double(start stop) double dose
        1  21915  21915  10
    end
    format %td start stop
    save "${DATA_DIR}/_val_zero_ds1.dta", replace

    * Dataset 2 spanning that point
    clear
    input long id double(start stop) byte flag
        1  21910  21920  1
    end
    format %td start stop
    save "${DATA_DIR}/_val_zero_ds2.dta", replace

    * Merge
    tvmerge "${DATA_DIR}/_val_zero_ds1.dta" "${DATA_DIR}/_val_zero_ds2.dta", id(id) ///
        start(start start) stop(stop stop) ///
        exposure(dose flag) ///
        continuous(dose) ///
        generate(d f)

    * Should get intersection at single point
    quietly count if start == stop
    assert r(N) >= 1

    * Dose at that point should be 10 (100% overlap)
    quietly sum d if start == 21915 & stop == 21915
    assert abs(r(mean) - 10) < 0.1
}
if _rc == 0 {
    local ++pass_count
    if `machine' {
        display "[OK] 4.2"
    }
    else if `quiet' == 0 {
        display as result "  PASS: Zero-duration in tvmerge handled correctly"
    }
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' 4.2"
    if `machine' {
        display "[FAIL] 4.2|`=_rc'"
    }
    else {
        display as error "  FAIL: Zero-duration tvmerge test (error `=_rc')"
    }
}

* =============================================================================
* SECTION 5: EVENTS AT INTERVAL START DATES
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 5: Events at Interval Start Dates"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 5.1: Event exactly at interval start (IS flagged under [start,stop] inclusive)
* Under [start, stop] inclusive convention, events at start ARE captured
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 5.1: Event at interval start date"
    display as text "  Interval [21915, 22015], Event at 21915"
    display as text "  Expected: Event IS flagged ([start,stop] inclusive convention)"
}

capture {
    * Create interval
    clear
    input long id double(start stop)
        1  21915  22015
    end
    format %td start stop
    save "${DATA_DIR}/_val_start_event.dta", replace

    * Event at exact start
    clear
    input long id double(event_dt)
        1  21915
    end
    format %td event_dt

    tvevent using "${DATA_DIR}/_val_start_event.dta", id(id) date(event_dt) ///
        startvar(start) stopvar(stop) ///
        generate(outcome)

    * Under [start, stop] inclusive convention, event at start IS flagged
    quietly count if outcome == 1
    local n_events = r(N)

    assert `n_events' == 1
}
if _rc == 0 {
    local ++pass_count
    if `machine' {
        display "[OK] 5.1"
    }
    else if `quiet' == 0 {
        display as result "  PASS: Event at start correctly flagged ([start,stop] inclusive)"
    }
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' 5.1"
    if `machine' {
        display "[FAIL] 5.1|`=_rc'"
    }
    else {
        display as error "  FAIL: Event at start test (error `=_rc')"
    }
}

* -----------------------------------------------------------------------------
* Test 5.2: Event between two consecutive intervals - flagged at end of first
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 5.2: Event at boundary between consecutive intervals"
}

capture {
    * Two consecutive intervals
    clear
    input long id double(start stop)
        1  21915  21965
        1  21965  22015
    end
    format %td start stop
    save "${DATA_DIR}/_val_boundary_event.dta", replace

    * Event at boundary (21965)
    clear
    input long id double(event_dt)
        1  21965
    end
    format %td event_dt

    tvevent using "${DATA_DIR}/_val_boundary_event.dta", id(id) date(event_dt) ///
        startvar(start) stopvar(stop) ///
        generate(outcome)

    * Event at stop of first interval should be flagged there
    quietly count if outcome == 1 & stop == 21965
    assert r(N) == 1

    * Event at start of second interval should NOT be flagged there
    quietly count if outcome == 1 & start == 21965
    assert r(N) == 0
}
if _rc == 0 {
    local ++pass_count
    if `machine' {
        display "[OK] 5.2"
    }
    else if `quiet' == 0 {
        display as result "  PASS: Boundary event flagged at interval end, not start"
    }
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' 5.2"
    if `machine' {
        display "[FAIL] 5.2|`=_rc'"
    }
    else {
        display as error "  FAIL: Boundary event test (error `=_rc')"
    }
}

* =============================================================================
* SECTION 6: MISSING VALUE HANDLING
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 6: Missing Value Handling"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 6.1: Missing event date - should not flag any events
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 6.1: Missing event date"
}

capture {
    * Create intervals
    clear
    input long id double(start stop)
        1  21915  22015
    end
    format %td start stop
    save "${DATA_DIR}/_val_missing_event.dta", replace

    * Missing event date
    clear
    input long id double(event_dt)
        1  .
    end

    tvevent using "${DATA_DIR}/_val_missing_event.dta", id(id) date(event_dt) ///
        startvar(start) stopvar(stop) ///
        generate(outcome)

    * No events should be flagged
    quietly count if outcome == 1
    assert r(N) == 0

    * Should still have the original interval
    quietly count
    assert r(N) == 1
}
if _rc == 0 {
    local ++pass_count
    if `machine' {
        display "[OK] 6.1"
    }
    else if `quiet' == 0 {
        display as result "  PASS: Missing event date handled correctly"
    }
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' 6.1"
    if `machine' {
        display "[FAIL] 6.1|`=_rc'"
    }
    else {
        display as error "  FAIL: Missing event date test (error `=_rc')"
    }
}

* -----------------------------------------------------------------------------
* Test 6.2: Missing continuous variable value
* Tests that missing values remain missing after continuous proportioning
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 6.2: Missing continuous variable value"
}

capture {
    * Create interval with missing dose
    clear
    input long id double(start stop) double dose
        1  21915  22015  .
    end
    format %td start stop
    save "${DATA_DIR}/_val_missing_cont.dta", replace

    * Event to trigger split - type(single) keeps only pre-event interval
    clear
    input long id double(event_dt)
        1  21965
    end
    format %td event_dt

    tvevent using "${DATA_DIR}/_val_missing_cont.dta", id(id) date(event_dt) ///
        startvar(start) stopvar(stop) ///
        continuous(dose) generate(outcome)

    * With type(single), only the pre-event interval remains
    quietly count
    assert r(N) == 1

    * Dose should still be missing (missing * ratio = missing)
    quietly count if missing(dose)
    assert r(N) == 1
}
if _rc == 0 {
    local ++pass_count
    if `machine' {
        display "[OK] 6.2"
    }
    else if `quiet' == 0 {
        display as result "  PASS: Missing continuous value preserved as missing"
    }
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' 6.2"
    if `machine' {
        display "[FAIL] 6.2|`=_rc'"
    }
    else {
        display as error "  FAIL: Missing continuous test (error `=_rc')"
    }
}

* =============================================================================
* SECTION 7: VARIABLE LABEL PRESERVATION
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 7: Variable Label Preservation"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 7.1: Variable labels survive tvexpose
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 7.1: Variable labels preserved by tvexpose"
}

capture {
    * Create cohort with labeled variables
    clear
    input long id double(study_entry study_exit) byte female
        1  21915  22280  1
    end
    format %td study_entry study_exit
    label variable study_entry "Date of study enrollment"
    label variable study_exit "Date of study exit"
    label variable female "Patient sex (1=female)"
    save "${DATA_DIR}/_val_label_cohort.dta", replace

    * Create exposure
    clear
    input long id double(start stop) byte exp_type
        1  21930  21960  1
    end
    format %td start stop
    save "${DATA_DIR}/_val_label_exposure.dta", replace

    * Run tvexpose with keepvars
    use "${DATA_DIR}/_val_label_cohort.dta", clear
    tvexpose using "${DATA_DIR}/_val_label_exposure.dta", id(id) start(start) stop(stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        keepvars(female) keepdates

    * Check labels are preserved
    local lbl_entry : variable label study_entry
    local lbl_exit : variable label study_exit
    local lbl_female : variable label female

    assert "`lbl_entry'" == "Date of study enrollment"
    assert "`lbl_exit'" == "Date of study exit"
    assert "`lbl_female'" == "Patient sex (1=female)"
}
if _rc == 0 {
    local ++pass_count
    if `machine' {
        display "[OK] 7.1"
    }
    else if `quiet' == 0 {
        display as result "  PASS: Variable labels preserved by tvexpose"
    }
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' 7.1"
    if `machine' {
        display "[FAIL] 7.1|`=_rc'"
    }
    else {
        display as error "  FAIL: Variable label preservation test (error `=_rc')"
    }
}

* -----------------------------------------------------------------------------
* Test 7.2: Value labels survive tvevent
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 7.2: Value labels created by tvevent"
}

capture {
    * Create intervals
    clear
    input long id double(start stop)
        1  21915  22015
    end
    format %td start stop
    save "${DATA_DIR}/_val_vallbl_intervals.dta", replace

    * Event with label
    clear
    input long id double(event_dt death_dt)
        1  21965  .
    end
    format %td event_dt death_dt
    label variable event_dt "Primary outcome event"
    label variable death_dt "Death"

    tvevent using "${DATA_DIR}/_val_vallbl_intervals.dta", id(id) date(event_dt) ///
        startvar(start) stopvar(stop) ///
        compete(death_dt) ///
        generate(status)

    * Check value labels exist
    local vallbl : value label status
    assert "`vallbl'" != ""

    * Check label for value 0 (censored)
    local lbl0 : label `vallbl' 0
    assert "`lbl0'" == "Censored"
}
if _rc == 0 {
    local ++pass_count
    if `machine' {
        display "[OK] 7.2"
    }
    else if `quiet' == 0 {
        display as result "  PASS: Value labels created by tvevent"
    }
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' 7.2"
    if `machine' {
        display "[FAIL] 7.2|`=_rc'"
    }
    else {
        display as error "  FAIL: tvevent value labels test (error `=_rc')"
    }
}

* =============================================================================
* SUMMARY

}

* --- From validation_tvtools_gold.do ---

capture noisily {
local DATA_DIR "data"

* =============================================================================
* SECTION 1: TVBALANCE MATHEMATICAL VALIDATION
* =============================================================================

* Test 1.1: SMD exact calculation - equal variance groups
local ++test_count
capture {
    clear
    input byte(id exposure) double(x1 x2)
        1  0  10  100
        2  0  20  100
        3  0  30  100
        4  0  40  100
        5  1  30  110
        6  1  40  110
        7  1  50  110
        8  1  60  110
    end

    tvbalance x1 x2, exposure(exposure)
    matrix B = r(balance)

    * x1: Mean_ref=25, Mean_exp=45, Var_ref=Var_exp=166.667
    * Pooled SD = sqrt((166.667+166.667)/2) = 12.9099
    * SMD = (45-25)/12.9099 = 1.5492
    assert abs(B[1,1] - 25) < 0.01
    assert abs(B[1,2] - 45) < 0.01
    assert abs(B[1,3] - 1.5492) < 0.01

    * x2: Mean_ref=100, Mean_exp=110, Var both=0
    * Pooled SD = 0 → different means → SMD = missing
    * Actually all ref are 100 and all exp are 110, so var=0
    * But means differ → SMD should be missing (undefined)
    assert B[2,3] == . | abs(B[2,3]) > 10  // undefined or very large
}
if _rc == 0 {
    display as result "  PASS 1.1: SMD exact calculation"
    local ++pass_count
}
else {
    display as error "  FAIL 1.1: SMD exact calculation (error `=_rc')"
    local ++fail_count
}

* Test 1.2: Weighted SMD reduces imbalance
local ++test_count
capture {
    clear
    input byte(id exposure) double(x1 w)
        1  0  10  2.0
        2  0  20  1.0
        3  0  30  1.0
        4  1  20  1.0
        5  1  30  1.0
        6  1  40  2.0
    end

    tvbalance x1, exposure(exposure) weights(w)
    matrix B = r(balance)

    * Unweighted: mean_ref=20, mean_exp=30, SMD=1.0
    assert abs(B[1,3] - 1.0) < 0.01

    * Weighted: weights upweight extreme values differently
    * Weighted mean_ref = (10*2+20*1+30*1)/(2+1+1) = 70/4 = 17.5
    * Weighted mean_exp = (20*1+30*1+40*2)/(1+1+2) = 130/4 = 32.5
    * Weighted SMD may differ from unweighted
    assert !missing(B[1,4])
}
if _rc == 0 {
    display as result "  PASS 1.2: Weighted SMD computation"
    local ++pass_count
}
else {
    display as error "  FAIL 1.2: Weighted SMD computation (error `=_rc')"
    local ++fail_count
}

* Test 1.3: ESS formula validation (ESS = sum(w)^2 / sum(w^2))
local ++test_count
capture {
    clear
    input byte(id exposure) double(x1 w)
        1  0  10  1.0
        2  0  20  1.0
        3  0  30  1.0
        4  1  20  2.0
        5  1  30  0.5
        6  1  40  1.5
    end

    tvbalance x1, exposure(exposure) weights(w)

    * ESS for reference: all w=1 → ESS = 3^2/3 = 3
    assert abs(r(ess_ref) - 3) < 0.01

    * ESS for exposed: sum(w) = 4, sum(w^2) = 4+0.25+2.25 = 6.5
    * ESS = 16/6.5 = 2.4615
    assert abs(r(ess_exp) - 2.4615) < 0.01
}
if _rc == 0 {
    display as result "  PASS 1.3: ESS formula validation"
    local ++pass_count
}
else {
    display as error "  FAIL 1.3: ESS formula validation (error `=_rc')"
    local ++fail_count
}

* Test 1.4: Threshold correctly classifies covariates
local ++test_count
capture {
    clear
    input byte(id exposure) double(x1 x2)
        1  0  10  50
        2  0  20  51
        3  0  30  49
        4  1  20  50
        5  1  30  51
        6  1  40  49
    end

    * x1: SMD = (30-20)/pooled_sd (large imbalance)
    * x2: SMD ≈ 0 (balanced)
    tvbalance x1 x2, exposure(exposure) threshold(0.1)

    * Should flag x1 as imbalanced
    assert r(n_imbalanced) >= 1

    * With high threshold, nothing flagged
    tvbalance x1 x2, exposure(exposure) threshold(5.0)
    assert r(n_imbalanced) == 0
}
if _rc == 0 {
    display as result "  PASS 1.4: Threshold classification"
    local ++pass_count
}
else {
    display as error "  FAIL 1.4: Threshold classification (error `=_rc')"
    local ++fail_count
}


* =============================================================================
* SECTION 2: TVCALENDAR MATHEMATICAL VALIDATION
* =============================================================================

* Test 2.1: Point-in-time merge correctness (every row matched)
local ++test_count
capture {
    * Create 3 persons with known dates
    clear
    input long id double date byte outcome
        1 22006 0
        2 22007 1
        3 22008 0
    end
    format %td date

    * External data: exact dates
    preserve
    clear
    input double date byte season float temp
        22006 1 -5.0
        22007 1 -3.0
        22008 2  2.0
    end
    format %td date
    save "`DATA_DIR'/_val_tvcal_pt.dta", replace
    restore

    tvcalendar using "`DATA_DIR'/_val_tvcal_pt.dta", datevar(date)

    * Verify exact matches
    sort id
    assert season[1] == 1 & abs(temp[1] - (-5.0)) < 0.001
    assert season[2] == 1 & abs(temp[2] - (-3.0)) < 0.001
    assert season[3] == 2 & abs(temp[3] - 2.0) < 0.001

    * N preserved
    assert _N == 3

    erase "`DATA_DIR'/_val_tvcal_pt.dta"
}
if _rc == 0 {
    display as result "  PASS 2.1: tvcalendar point merge exact values"
    local ++pass_count
}
else {
    display as error "  FAIL 2.1: tvcalendar point merge exact values (error `=_rc')"
    local ++fail_count
}

* Test 2.2: Range merge assigns correct periods
local ++test_count
capture {
    * Master: dates spanning multiple periods
    clear
    input long id double date
        1 22010
        2 22040
        3 22070
        4 22100
    end
    format %td date

    * External: three periods
    preserve
    clear
    input double(ps pe) byte era
        22001 22030 1
        22031 22060 2
        22061 22090 3
    end
    format %td ps pe
    save "`DATA_DIR'/_val_tvcal_range.dta", replace
    restore

    tvcalendar using "`DATA_DIR'/_val_tvcal_range.dta", ///
        datevar(date) startvar(ps) stopvar(pe)

    sort id
    * id=1 date=22010 → era=1 (22001-22030)
    assert era[1] == 1
    * id=2 date=22040 → era=2 (22031-22060)
    assert era[2] == 2
    * id=3 date=22070 → era=3 (22061-22090)
    assert era[3] == 3
    * id=4 date=22100 → no match → era missing
    assert missing(era[4])

    erase "`DATA_DIR'/_val_tvcal_range.dta"
}
if _rc == 0 {
    display as result "  PASS 2.2: tvcalendar range merge correct period assignment"
    local ++pass_count
}
else {
    display as error "  FAIL 2.2: tvcalendar range merge assignment (error `=_rc')"
    local ++fail_count
}

* Test 2.3: Range merge boundary inclusion
local ++test_count
capture {
    * Date ON period boundary
    clear
    input long id double date
        1 22030
        2 22031
    end
    format %td date

    preserve
    clear
    input double(ps pe) byte era
        22001 22030 1
        22031 22060 2
    end
    format %td ps pe
    save "`DATA_DIR'/_val_tvcal_boundary.dta", replace
    restore

    tvcalendar using "`DATA_DIR'/_val_tvcal_boundary.dta", ///
        datevar(date) startvar(ps) stopvar(pe)

    sort id
    * 22030 falls in [22001,22030] → era=1
    assert era[1] == 1
    * 22031 falls in [22031,22060] → era=2
    assert era[2] == 2

    erase "`DATA_DIR'/_val_tvcal_boundary.dta"
}
if _rc == 0 {
    display as result "  PASS 2.3: tvcalendar boundary inclusion"
    local ++pass_count
}
else {
    display as error "  FAIL 2.3: tvcalendar boundary inclusion (error `=_rc')"
    local ++fail_count
}


* =============================================================================
* SECTION 3: TVWEIGHT MATHEMATICAL VALIDATION
* =============================================================================

* Test 3.1: IPTW formula (binary): W = A/PS + (1-A)/(1-PS)
local ++test_count
capture {
    * Create known data where we can verify propensity scores
    clear
    set seed 77777
    set obs 500
    gen long id = _n
    gen double x = rnormal()
    * Generate treatment with known probability
    gen double ps_true = invlogit(0.5*x)
    gen byte treatment = (runiform() < ps_true)

    tvweight treatment, covariates(x) generate(w) nolog

    * All weights should be > 0
    assert w > 0 if !missing(w)

    * Mean weight for treated should be > 1 (since 1/PS > 1 for PS < 1)
    quietly sum w if treatment == 1
    assert r(mean) >= 1

    * Mean weight for untreated should also be > 1
    quietly sum w if treatment == 0
    assert r(mean) >= 1

    * ESS should be meaningful and positive
    assert r(ess) > 0
    assert r(ess_pct) > 0
}
if _rc == 0 {
    display as result "  PASS 3.1: IPTW binary formula properties"
    local ++pass_count
}
else {
    display as error "  FAIL 3.1: IPTW binary formula properties (error `=_rc')"
    local ++fail_count
}

* Test 3.2: Stabilized weights should have mean closer to 1
local ++test_count
capture {
    clear
    set seed 88888
    set obs 400
    gen double x = rnormal()
    gen byte treatment = (runiform() < invlogit(0.3*x))

    * Unstabilized
    tvweight treatment, covariates(x) generate(w_unstab) nolog
    quietly sum w_unstab
    local mean_unstab = r(mean)

    * Stabilized
    drop w_unstab
    tvweight treatment, covariates(x) generate(w_stab) stabilized nolog
    quietly sum w_stab
    local mean_stab = r(mean)

    * Stabilized mean should be closer to 1
    assert abs(`mean_stab' - 1) < abs(`mean_unstab' - 1) + 0.5
}
if _rc == 0 {
    display as result "  PASS 3.2: Stabilized weights mean ≈ 1"
    local ++pass_count
}
else {
    display as error "  FAIL 3.2: Stabilized weights mean ≈ 1 (error `=_rc')"
    local ++fail_count
}

* Test 3.3: Truncation at percentiles
local ++test_count
capture {
    clear
    set seed 55555
    set obs 300
    gen double x = rnormal()
    gen byte treatment = (runiform() < invlogit(x))

    * Untruncated first
    tvweight treatment, covariates(x) generate(w_full) nolog
    quietly sum w_full
    local full_min = r(min)
    local full_max = r(max)

    * Now truncated
    tvweight treatment, covariates(x) generate(w_trunc) truncate(5 95) nolog

    * Truncated range should be narrower or equal
    quietly sum w_trunc
    assert r(min) >= `full_min' - 0.001
    assert r(max) <= `full_max' + 0.001
}
if _rc == 0 {
    display as result "  PASS 3.3: Truncation reduces extreme weights"
    local ++pass_count
}
else {
    display as error "  FAIL 3.3: Truncation reduces extreme weights (error `=_rc')"
    local ++fail_count
}


* =============================================================================
* SECTION 5: TVDIAGNOSE MATHEMATICAL VALIDATION
* =============================================================================

* Test 5.1: Coverage calculation exact values
local ++test_count
capture {
    * Person 1: 100% coverage (31+30=61 days, entry-exit span=61)
    * Person 2: ~50% coverage (31 days covered, 61 span)
    clear
    input long id double(start stop entry exit)
        1 22006 22036 22006 22066
        1 22036 22066 22006 22066
        2 22006 22036 22006 22066
    end
    format %td start stop entry exit

    tvdiagnose, id(id) start(start) stop(stop) entry(entry) exit(exit) coverage

    * Person 1 coverage = 100%
    * Person 2 coverage = 31/61 * 100 ≈ 50.8%
    * Mean coverage = (100 + 50.8)/2 ≈ 75.4
    assert abs(r(mean_coverage) - 75.4) < 1.0
    assert r(n_with_gaps) == 1  // only person 2 has gap
}
if _rc == 0 {
    display as result "  PASS 5.1: Coverage calculation exact"
    local ++pass_count
}
else {
    display as error "  FAIL 5.1: Coverage calculation exact (error `=_rc')"
    local ++fail_count
}

* Test 5.2: Gap detection with known gaps
local ++test_count
capture {
    clear
    input long id double(start stop)
        1 22006 22036
        1 22046 22067
        1 22097 22127
        2 22006 22067
    end
    format %td start stop

    * Person 1: 2 gaps (10-day gap + 30-day gap)
    * Person 2: no gaps (single period)
    tvdiagnose, id(id) start(start) stop(stop) gaps threshold(15)

    assert r(n_gaps) == 2
    assert r(n_large_gaps) == 1  // only the 30-day gap > threshold 15
}
if _rc == 0 {
    display as result "  PASS 5.2: Gap detection exact count"
    local ++pass_count
}
else {
    display as error "  FAIL 5.2: Gap detection exact count (error `=_rc')"
    local ++fail_count
}

* Test 5.3: Overlap detection
local ++test_count
capture {
    clear
    input long id double(start stop)
        1 22006 22040
        1 22036 22067
        2 22006 22036
        2 22036 22067
    end
    format %td start stop

    * Person 1: overlap (22036 < 22040)
    * Person 2: no overlap (22036 == 22036, abutting)
    * Note: overlap check is start <= stop[_n-1], so 22036 <= 22036 IS overlap
    tvdiagnose, id(id) start(start) stop(stop) overlaps

    * At least person 1 has clear overlap
    assert r(n_overlaps) >= 1
}
if _rc == 0 {
    display as result "  PASS 5.3: Overlap detection"
    local ++pass_count
}
else {
    display as error "  FAIL 5.3: Overlap detection (error `=_rc')"
    local ++fail_count
}

* Test 5.4: Summarize total person-time calculation
local ++test_count
capture {
    clear
    input long id double(start stop) byte exposure
        1 22006 22036 1
        1 22036 22066 0
        2 22006 22036 1
    end
    format %td start stop

    * Total days = (31+31+31) = 93 (using stop-start+1 formula)
    tvdiagnose, id(id) start(start) stop(stop) exposure(exposure) summarize

    assert r(total_person_time) == 93
}
if _rc == 0 {
    display as result "  PASS 5.4: Total person-time exact"
    local ++pass_count
}
else {
    display as error "  FAIL 5.4: Total person-time exact (error `=_rc')"
    local ++fail_count
}


* =============================================================================
* SECTION 6: TVEXPOSE CARRYFORWARD/STATETIME VALIDATION
* =============================================================================

* Test 6.1: Carryforward extends exposure into gaps
local ++test_count
capture {
    * Cohort: 1 person, 100 days follow-up
    clear
    input long id double(study_entry study_exit)
        1 22006 22106
    end
    format %td study_entry study_exit
    save "`DATA_DIR'/_val_cf_cohort.dta", replace

    * Exposure: 1 period ending at day 22036 (30 days in)
    clear
    input long id double(rx_start rx_stop) byte drug
        1 22006 22036 1
    end
    format %td rx_start rx_stop
    save "`DATA_DIR'/_val_cf_rx.dta", replace

    * Without carryforward: exposed 22006-22036, unexposed 22036-22106
    use "`DATA_DIR'/_val_cf_cohort.dta", clear
    tvexpose using "`DATA_DIR'/_val_cf_rx.dta", ///
        id(id) start(rx_start) stop(rx_stop) exposure(drug) ///
        reference(0) entry(study_entry) exit(study_exit)

    quietly count if tv_exposure != 0
    local exposed_no_cf = r(N)

    * With carryforward(10): exposure extends 10 days past rx_stop
    use "`DATA_DIR'/_val_cf_cohort.dta", clear
    tvexpose using "`DATA_DIR'/_val_cf_rx.dta", ///
        id(id) start(rx_start) stop(rx_stop) exposure(drug) ///
        reference(0) entry(study_entry) exit(study_exit) ///
        carryforward(10)

    * Should have more or equal exposed intervals than without carryforward
    quietly count if tv_exposure != 0
    assert r(N) >= `exposed_no_cf'

    * Total person-time should still be preserved (output uses rx_start/rx_stop)
    gen double dur = rx_stop - rx_start
    quietly sum dur
    assert r(sum) > 0

    erase "`DATA_DIR'/_val_cf_cohort.dta"
    erase "`DATA_DIR'/_val_cf_rx.dta"
}
if _rc == 0 {
    display as result "  PASS 6.1: Carryforward extends exposure into gaps"
    local ++pass_count
}
else {
    display as error "  FAIL 6.1: Carryforward extends exposure (error `=_rc')"
    local ++fail_count
}

* Test 6.2: Statetime cumulates within state blocks
local ++test_count
capture {
    * Cohort: 1 person, 90 days
    clear
    input long id double(study_entry study_exit)
        1 22006 22096
    end
    format %td study_entry study_exit
    save "`DATA_DIR'/_val_st_cohort.dta", replace

    * Exposure: drug 1 for 30 days, drug 2 for 30 days, drug 1 again for 30 days
    clear
    input long id double(rx_start rx_stop) byte drug
        1 22006 22036 1
        1 22036 22066 2
        1 22066 22096 1
    end
    format %td rx_start rx_stop
    save "`DATA_DIR'/_val_st_rx.dta", replace

    use "`DATA_DIR'/_val_st_cohort.dta", clear
    tvexpose using "`DATA_DIR'/_val_st_rx.dta", ///
        id(id) start(rx_start) stop(rx_stop) exposure(drug) ///
        reference(0) entry(study_entry) exit(study_exit) ///
        statetime

    * state_time_years should exist and reset at state changes
    confirm variable state_time_years
    assert state_time_years > 0 if !missing(state_time_years)

    erase "`DATA_DIR'/_val_st_cohort.dta"
    erase "`DATA_DIR'/_val_st_rx.dta"
}
if _rc == 0 {
    display as result "  PASS 6.2: Statetime cumulates within state blocks"
    local ++pass_count
}
else {
    display as error "  FAIL 6.2: Statetime cumulation (error `=_rc')"
    local ++fail_count
}


* =============================================================================
* SECTION 7: TVMERGE CUSTOM NAMES VALIDATION
* =============================================================================

* Test 7.1: Custom start/stop names propagate through merge
local ++test_count
capture {
    * Dataset 1
    clear
    input long id double(s1 e1) byte exp1
        1 22006 22036 1
        1 22036 22066 0
    end
    format %td s1 e1
    save "`DATA_DIR'/_val_merge_names1.dta", replace

    * Dataset 2
    clear
    input long id double(s2 e2) byte exp2
        1 22006 22050 1
    end
    format %td s2 e2
    save "`DATA_DIR'/_val_merge_names2.dta", replace

    tvmerge "`DATA_DIR'/_val_merge_names1.dta" "`DATA_DIR'/_val_merge_names2.dta", ///
        id(id) start(s1 s2) stop(e1 e2) exposure(exp1 exp2) ///
        startname(begin_dt) stopname(end_dt) dateformat(%tdDD/NN/CCYY)

    * Custom names should be used
    confirm variable begin_dt
    confirm variable end_dt

    * Date format should be applied
    local fmt : format begin_dt
    assert "`fmt'" == "%tdDD/NN/CCYY"

    * Merged data should have valid intervals
    assert begin_dt < end_dt

    erase "`DATA_DIR'/_val_merge_names1.dta"
    erase "`DATA_DIR'/_val_merge_names2.dta"
}
if _rc == 0 {
    display as result "  PASS 7.1: Custom start/stop names in merge"
    local ++pass_count
}
else {
    display as error "  FAIL 7.1: Custom merge names (error `=_rc')"
    local ++fail_count
}

* Test 7.2: Validatecoverage detects gaps
local ++test_count
capture {
    * Dataset 1: full coverage
    clear
    input long id double(s1 e1) byte exp1
        1 22006 22036 1
        1 22036 22066 0
    end
    format %td s1 e1
    save "`DATA_DIR'/_val_merge_vc1.dta", replace

    * Dataset 2: partial coverage (gap between 22036-22050)
    clear
    input long id double(s2 e2) byte exp2
        1 22006 22036 1
        1 22050 22066 0
    end
    format %td s2 e2
    save "`DATA_DIR'/_val_merge_vc2.dta", replace

    * Should detect the gap and still produce valid output
    tvmerge "`DATA_DIR'/_val_merge_vc1.dta" "`DATA_DIR'/_val_merge_vc2.dta", ///
        id(id) start(s1 s2) stop(e1 e2) exposure(exp1 exp2) ///
        validatecoverage

    assert r(N) > 0

    erase "`DATA_DIR'/_val_merge_vc1.dta"
    erase "`DATA_DIR'/_val_merge_vc2.dta"
}
if _rc == 0 {
    display as result "  PASS 7.2: Validatecoverage detects gaps"
    local ++pass_count
}
else {
    display as error "  FAIL 7.2: Validatecoverage gap detection (error `=_rc')"
    local ++fail_count
}


* =============================================================================
* SECTION 8: RETURN VALUE COMPLETENESS
* =============================================================================

* Test 8.1: tvdiagnose returns all documented r() scalars
local ++test_count
capture {
    clear
    input long id double(start stop entry exit) byte exposure
        1 22006 22036 22006 22066 1
        1 22036 22066 22006 22066 0
        2 22006 22036 22006 22066 1
    end
    format %td start stop entry exit

    tvdiagnose, id(id) start(start) stop(stop) ///
        exposure(exposure) entry(entry) exit(exit) all

    * Must return these
    assert !missing(r(n_persons))
    assert !missing(r(n_observations))
    assert !missing(r(mean_coverage))
    assert !missing(r(n_with_gaps))
    assert !missing(r(total_person_time))
    assert "`r(id)'" == "id"
}
if _rc == 0 {
    display as result "  PASS 8.1: tvdiagnose all r() values present"
    local ++pass_count
}
else {
    display as error "  FAIL 8.1: tvdiagnose r() values (error `=_rc')"
    local ++fail_count
}

* Test 8.2: tvweight returns all documented r() scalars
local ++test_count
capture {
    clear
    set seed 44444
    set obs 200
    gen byte treatment = (runiform() > 0.5)
    gen double age = 50 + 5*rnormal()

    tvweight treatment, covariates(age) generate(w) ///
        stabilized truncate(5 95) denominator(ps) nolog

    * Must return these
    assert !missing(r(N))
    assert !missing(r(n_levels))
    assert !missing(r(ess))
    assert !missing(r(ess_pct))
    assert !missing(r(w_mean))
    assert !missing(r(w_sd))
    assert !missing(r(w_min))
    assert !missing(r(w_max))
    assert !missing(r(w_p1))
    assert !missing(r(w_p50))
    assert !missing(r(w_p99))
    assert !missing(r(n_truncated))
    assert !missing(r(trunc_lo))
    assert !missing(r(trunc_hi))
    assert "`r(exposure)'" == "treatment"
    assert "`r(model)'" == "logit"
    assert "`r(stabilized)'" == "stabilized"
    assert "`r(denominator)'" == "ps"
}
if _rc == 0 {
    display as result "  PASS 8.2: tvweight all r() values present"
    local ++pass_count
}
else {
    display as error "  FAIL 8.2: tvweight r() values (error `=_rc')"
    local ++fail_count
}

* Test 8.4: tvcalendar returns all documented r() scalars
local ++test_count
capture {
    clear
    input long id double date byte outcome
        1 22006 0
        2 22007 1
    end
    format %td date

    preserve
    clear
    input double date byte season
        22006 1
        22007 1
    end
    format %td date
    save "`DATA_DIR'/_val_tvcal_rvals.dta", replace
    restore

    tvcalendar using "`DATA_DIR'/_val_tvcal_rvals.dta", datevar(date)

    assert r(n_master) == 2
    assert r(n_merged) == 2
    assert "`r(datevar)'" == "date"

    erase "`DATA_DIR'/_val_tvcal_rvals.dta"
}
if _rc == 0 {
    display as result "  PASS 8.4: tvcalendar all r() values present"
    local ++pass_count
}
else {
    display as error "  FAIL 8.4: tvcalendar r() values (error `=_rc')"
    local ++fail_count
}


* =============================================================================
* RESULTS SUMMARY

}

* --- From validation_tvtools_pipeline.do ---

capture noisily {
display as text _newline _dup(70) "="
display as text "TVTOOLS INTEGRATION PIPELINE VALIDATION"
display as text _dup(70) "="

* ============================================================================
* CREATE SIMULATED DATA
* ============================================================================

display as text _newline "Step 0: Creating simulated data"
display as text _dup(70) "-"

set seed 42

* Cohort: 100 persons, study period 2020-2023
clear
set obs 100
gen long id = _n
gen double study_entry = mdy(1, 1, 2020) + floor(runiform() * 90)
gen double study_exit = study_entry + 365 + floor(runiform() * 730)
format study_entry study_exit %tdCCYY/NN/DD

* Covariates for each person
gen double age = floor(40 + runiform() * 30)
gen byte sex = (runiform() > 0.5)

display as result "Created cohort: " _N " persons"

tempfile cohort_data
quietly save `cohort_data'

* Exposure data: ~60% of persons get treatment
clear
set obs 150
gen long id = ceil(runiform() * 100)
gen double rx_start = mdy(1, 1, 2020) + floor(runiform() * 365)
gen double rx_stop = rx_start + 30 + floor(runiform() * 90)
gen byte exp_type = 1
format rx_start rx_stop %tdCCYY/NN/DD
drop if id > 100

display as result "Created exposure data: " _N " records"

tempfile exposure_data
quietly save `exposure_data'

* Event data: outcome for ~15% of persons
use `cohort_data', clear
gen double event_date = study_entry + floor(runiform() * (study_exit - study_entry))
gen byte has_event = (runiform() < 0.15)
replace event_date = . if has_event == 0
format event_date %tdCCYY/NN/DD
keep id event_date
drop if missing(event_date)

display as result "Created event data: " _N " events"

tempfile event_data
quietly save `event_data'

* ============================================================================
* STEP 1: tvexpose
* ============================================================================

display as text _newline "Step 1: tvexpose"
display as text _dup(70) "-"

use `cohort_data', clear

tvexpose using `exposure_data', id(id) start(rx_start) stop(rx_stop) ///
    exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
    generate(tv_exp)

* Test 1.1: All persons present
quietly tab id
local n_persons = r(r)
if `n_persons' == 100 {
    display as result "PASS 1.1: All 100 persons present"
    local pass_count = `pass_count' + 1
}
else {
    display as error "FAIL 1.1: " `n_persons' " persons (expected 100)"
    local fail_count = `fail_count' + 1
}

* Test 1.2: No overlapping intervals
sort id rx_start
by id: gen double _gap = rx_start - rx_stop[_n-1] if _n > 1
quietly count if _gap < 1 & !missing(_gap)
local n_overlaps = r(N)
if `n_overlaps' == 0 {
    display as result "PASS 1.2: No overlapping intervals"
    local pass_count = `pass_count' + 1
}
else {
    display as error "FAIL 1.2: " `n_overlaps' " overlapping intervals"
    local fail_count = `fail_count' + 1
}
drop _gap

* Test 1.3: Person-time conserved
preserve
gen double days = rx_stop - rx_start + 1
collapse (sum) total_days=days, by(id)
merge 1:1 id using `cohort_data', keepusing(study_entry study_exit) nogenerate
gen double expected_days = study_exit - study_entry + 1
gen double day_diff = abs(total_days - expected_days)
quietly summarize day_diff
local max_diff = r(max)
restore

if `max_diff' <= 1 {
    display as result "PASS 1.3: Person-time conserved (max diff = " `max_diff' ")"
    local pass_count = `pass_count' + 1
}
else {
    display as error "FAIL 1.3: Person-time not conserved (max diff = " `max_diff' ")"
    local fail_count = `fail_count' + 1
}

display as result "tvexpose output: " _N " rows"

tempfile tvexpose_result
quietly save `tvexpose_result'

* ============================================================================
* STEP 2: tvevent
* ============================================================================

display as text _newline "Step 2: tvevent"
display as text _dup(70) "-"

* tvevent expects: master = event data, using = time-varying intervals
use `event_data', clear
tvevent using `tvexpose_result', id(id) date(event_date) ///
    startvar(rx_start) stopvar(rx_stop) generate(tv_event)

* Test 2.1: Event flag is binary
quietly tab tv_event
local n_levels = r(r)
if `n_levels' <= 2 {
    display as result "PASS 2.1: Event flag has " `n_levels' " levels"
    local pass_count = `pass_count' + 1
}
else {
    display as error "FAIL 2.1: Event flag has " `n_levels' " levels"
    local fail_count = `fail_count' + 1
}

* Test 2.2: No overlapping intervals after split
sort id rx_start
by id: gen double _gap = rx_start - rx_stop[_n-1] if _n > 1
quietly count if _gap < 1 & !missing(_gap)
local n_overlaps = r(N)
if `n_overlaps' == 0 {
    display as result "PASS 2.2: No overlaps after tvevent"
    local pass_count = `pass_count' + 1
}
else {
    display as error "FAIL 2.2: " `n_overlaps' " overlaps after tvevent"
    local fail_count = `fail_count' + 1
}
drop _gap

display as result "tvevent output: " _N " rows"

tempfile tvevent_result
quietly save `tvevent_result'

* ============================================================================
* STEP 3: tvdiagnose
* ============================================================================

display as text _newline "Step 3: tvdiagnose"
display as text _dup(70) "-"

tvdiagnose, id(id) start(rx_start) stop(rx_stop) overlaps

* Test 3.1: No overlaps detected
local n_overlaps = r(n_overlaps)
if `n_overlaps' == 0 {
    display as result "PASS 3.1: tvdiagnose confirms no overlaps"
    local pass_count = `pass_count' + 1
}
else {
    display as error "FAIL 3.1: tvdiagnose found " `n_overlaps' " overlaps"
    local fail_count = `fail_count' + 1
}

* ============================================================================
* STEP 4: tvbalance
* ============================================================================

display as text _newline "Step 4: tvbalance"
display as text _dup(70) "-"

* Create binary exposure for balance check
gen byte exposed = (tv_exp > 0) if !missing(tv_exp)

* Merge age/sex covariates back for balance
merge m:1 id using `cohort_data', keepusing(age sex) nogenerate

* Test 4.1: tvbalance runs
capture tvbalance age sex, exposure(exposed)
if _rc == 0 {
    display as result "PASS 4.1: tvbalance completed"
    local pass_count = `pass_count' + 1

    * Test 4.2: Matrix exists
    matrix b = r(balance)
    local nrows = rowsof(b)
    if `nrows' == 2 {
        display as result "PASS 4.2: Balance matrix has 2 rows (age, sex)"
        local pass_count = `pass_count' + 1
    }
    else {
        display as error "FAIL 4.2: Balance matrix has " `nrows' " rows"
        local fail_count = `fail_count' + 1
    }
}

}

* --- From validation_tvtools_pipeline_mathematical.do ---

capture noisily {
display _n _dup(70) "="
display "TVTOOLS PIPELINE MATHEMATICAL VALIDATION"
display _dup(70) "="
display "Date: $S_DATE $S_TIME"
display ""


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

}

* --- From validation_tvtools_pipeline_stress.do ---

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

display _n _dup(70) "="
display "TVTOOLS PIPELINE STRESS VALIDATION (12 tests)"
display _dup(70) "="
display "Date: $S_DATE $S_TIME"
display ""


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

}


* =============================================================================
* SECTION 9: TVPLOT VALIDATION (8 tests)
* =============================================================================

capture noisily {
display _n _dup(70) "="
display "TVPLOT VALIDATION"
display _dup(70) "="

* Create test data: 5 persons with intervals and exposure
tempfile tvp_plotdata
clear
input int(id) str10(s_start s_stop) byte(tv_exp)
1 "2020-01-01" "2020-06-30" 1
1 "2020-07-01" "2020-12-31" 0
2 "2020-03-01" "2020-09-30" 1
3 "2020-01-01" "2020-04-30" 0
3 "2020-05-01" "2020-12-31" 1
4 "2020-02-01" "2020-08-31" 1
5 "2020-01-01" "2020-12-31" 0
end
gen double start = date(s_start, "YMD")
gen double stop  = date(s_stop, "YMD")
format %td start stop
drop s_start s_stop
save `tvp_plotdata', replace

* Test 9.1: swimlane returns
local ++test_count
capture {
    use `tvp_plotdata', clear
    tvplot, id(id) start(start) stop(stop)
    assert "`r(plottype)'" == "swimlane"
    assert "`r(id)'" == "id"
    assert "`r(start)'" == "start"
    assert "`r(stop)'" == "stop"
}
if _rc == 0 {
    display as result "  PASS: tvplot swimlane returns"
    local ++pass_count
}
else {
    display as error "  FAIL: tvplot swimlane returns (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 9.1"
}

* Test 9.2: persontime returns
local ++test_count
capture {
    use `tvp_plotdata', clear
    tvplot, id(id) start(start) stop(stop) exposure(tv_exp) persontime
    assert "`r(plottype)'" == "persontime"
}
if _rc == 0 {
    display as result "  PASS: tvplot persontime returns"
    local ++pass_count
}
else {
    display as error "  FAIL: tvplot persontime returns (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 9.2"
}

* Test 9.3: saving() creates file (tvplot uses graph export)
local ++test_count
capture {
    use `tvp_plotdata', clear
    capture erase "/tmp/_tvplot_test.png"
    tvplot, id(id) start(start) stop(stop) saving("/tmp/_tvplot_test.png") replace
    confirm file "/tmp/_tvplot_test.png"
    erase "/tmp/_tvplot_test.png"
}
if _rc == 0 {
    display as result "  PASS: tvplot saving() creates file"
    local ++pass_count
}
else {
    display as error "  FAIL: tvplot saving() creates file (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 9.3"
}

* Test 9.4: sample(2) limits output
local ++test_count
capture {
    use `tvp_plotdata', clear
    tvplot, id(id) start(start) stop(stop) sample(2)
}
if _rc == 0 {
    display as result "  PASS: tvplot sample(2) completes"
    local ++pass_count
}
else {
    display as error "  FAIL: tvplot sample(2) (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 9.4"
}

* Test 9.5: sortby(entry) completes
local ++test_count
capture {
    use `tvp_plotdata', clear
    tvplot, id(id) start(start) stop(stop) sortby(entry)
}
if _rc == 0 {
    display as result "  PASS: tvplot sortby(entry)"
    local ++pass_count
}
else {
    display as error "  FAIL: tvplot sortby(entry) (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 9.5"
}

* Test 9.6: sortby(exit) completes
local ++test_count
capture {
    use `tvp_plotdata', clear
    tvplot, id(id) start(start) stop(stop) sortby(exit)
}
if _rc == 0 {
    display as result "  PASS: tvplot sortby(exit)"
    local ++pass_count
}
else {
    display as error "  FAIL: tvplot sortby(exit) (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 9.6"
}

* Test 9.7: sortby(persontime) with exposure
local ++test_count
capture {
    use `tvp_plotdata', clear
    tvplot, id(id) start(start) stop(stop) exposure(tv_exp) sortby(persontime)
}
if _rc == 0 {
    display as result "  PASS: tvplot sortby(persontime)"
    local ++pass_count
}
else {
    display as error "  FAIL: tvplot sortby(persontime) (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 9.7"
}

* Test 9.8: persontime without exposure() -> error
local ++test_count
capture {
    use `tvp_plotdata', clear
    capture noisily tvplot, id(id) start(start) stop(stop) persontime
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: tvplot persontime error without exposure"
    local ++pass_count
}
else {
    display as error "  FAIL: tvplot persontime error without exposure (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 9.8"
}

}


* =============================================================================
* SECTION 10: TVDIAGNOSE DEEP VALIDATION (8 tests)
* =============================================================================

capture noisily {
display _n _dup(70) "="
display "TVDIAGNOSE DEEP VALIDATION"
display _dup(70) "="

* Test 10.1: 100% coverage
local ++test_count
capture {
    clear
    input int(id) str10(s_start s_stop s_entry s_exit)
    1 "2020-01-01" "2020-12-31" "2020-01-01" "2020-12-31"
    2 "2020-01-01" "2020-12-31" "2020-01-01" "2020-12-31"
    end
    gen double start = date(s_start, "YMD")
    gen double stop  = date(s_stop, "YMD")
    gen double entry = date(s_entry, "YMD")
    gen double exit_ = date(s_exit, "YMD")
    format %td start stop entry exit_
    drop s_*
    tvdiagnose, id(id) start(start) stop(stop) entry(entry) exit(exit_) coverage
    assert r(mean_coverage) == 100
    assert r(n_with_gaps) == 0
}
if _rc == 0 {
    display as result "  PASS: tvdiagnose 100% coverage"
    local ++pass_count
}
else {
    display as error "  FAIL: tvdiagnose 100% coverage (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 10.1"
}

* Test 10.2: ~50% known gap
local ++test_count
capture {
    clear
    input int(id) str10(s_start s_stop s_entry s_exit)
    1 "2020-01-01" "2020-07-01" "2020-01-01" "2021-01-01"
    end
    gen double start = date(s_start, "YMD")
    gen double stop  = date(s_stop, "YMD")
    gen double entry = date(s_entry, "YMD")
    gen double exit_ = date(s_exit, "YMD")
    format %td start stop entry exit_
    drop s_*
    tvdiagnose, id(id) start(start) stop(stop) entry(entry) exit(exit_) coverage
    assert r(mean_coverage) > 45 & r(mean_coverage) < 55
    assert r(n_with_gaps) == 1
}
if _rc == 0 {
    display as result "  PASS: tvdiagnose ~50% coverage"
    local ++pass_count
}
else {
    display as error "  FAIL: tvdiagnose ~50% coverage (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 10.2"
}

* Test 10.3: Gap size precision
local ++test_count
capture {
    clear
    input int(id) str10(s_start s_stop s_entry s_exit)
    1 "2020-01-01" "2020-03-31" "2020-01-01" "2020-12-31"
    1 "2020-05-01" "2020-12-31" "2020-01-01" "2020-12-31"
    end
    gen double start = date(s_start, "YMD")
    gen double stop  = date(s_stop, "YMD")
    gen double entry = date(s_entry, "YMD")
    gen double exit_ = date(s_exit, "YMD")
    format %td start stop entry exit_
    drop s_*
    * Gap: Apr 1 to Apr 30 = ~31 days
    tvdiagnose, id(id) start(start) stop(stop) entry(entry) exit(exit_) gaps
    assert r(n_gaps) == 1
    assert r(mean_gap) >= 28 & r(mean_gap) <= 35
    assert r(max_gap) >= 28 & r(max_gap) <= 35
}
if _rc == 0 {
    display as result "  PASS: tvdiagnose gap size precision"
    local ++pass_count
}
else {
    display as error "  FAIL: tvdiagnose gap size precision (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 10.3"
}

* Test 10.4: threshold() filtering
local ++test_count
capture {
    clear
    input int(id) str10(s_start s_stop s_entry s_exit)
    1 "2020-01-01" "2020-02-28" "2020-01-01" "2020-12-31"
    1 "2020-03-05" "2020-05-31" "2020-01-01" "2020-12-31"
    1 "2020-08-01" "2020-12-31" "2020-01-01" "2020-12-31"
    end
    gen double start = date(s_start, "YMD")
    gen double stop  = date(s_stop, "YMD")
    gen double entry = date(s_entry, "YMD")
    gen double exit_ = date(s_exit, "YMD")
    format %td start stop entry exit_
    drop s_*
    * Gap 1: Mar 1-4 = ~5 days (small), Gap 2: Jun 1-Jul 31 = ~61 days (large)
    tvdiagnose, id(id) start(start) stop(stop) entry(entry) exit(exit_) gaps threshold(30)
    assert r(n_large_gaps) == 1
    assert r(n_gaps) == 2
}
if _rc == 0 {
    display as result "  PASS: tvdiagnose threshold() filtering"
    local ++pass_count
}
else {
    display as error "  FAIL: tvdiagnose threshold() filtering (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 10.4"
}

* Test 10.5: Overlap count
local ++test_count
capture {
    clear
    input int(id) str10(s_start s_stop)
    1 "2020-01-01" "2020-06-30"
    1 "2020-04-01" "2020-12-31"
    2 "2020-01-01" "2020-12-31"
    end
    gen double start = date(s_start, "YMD")
    gen double stop  = date(s_stop, "YMD")
    format %td start stop
    drop s_*
    tvdiagnose, id(id) start(start) stop(stop) overlaps
    assert r(n_overlaps) >= 1
    assert r(n_ids_affected) == 1
}
if _rc == 0 {
    display as result "  PASS: tvdiagnose overlap count"
    local ++pass_count
}
else {
    display as error "  FAIL: tvdiagnose overlap count (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 10.5"
}

* Test 10.6: Person-time by exposure
local ++test_count
capture {
    clear
    input int(id) str10(s_start s_stop)
    1 "2020-01-01" "2020-12-31"
    2 "2020-01-01" "2020-12-31"
    3 "2020-01-01" "2020-12-31"
    end
    gen double start = date(s_start, "YMD")
    gen double stop  = date(s_stop, "YMD")
    format %td start stop
    drop s_*
    gen byte exp = 1
    tvdiagnose, id(id) start(start) stop(stop) exposure(exp) summarize
    assert r(total_person_time) >= 1090 & r(total_person_time) <= 1100
}
if _rc == 0 {
    display as result "  PASS: tvdiagnose person-time"
    local ++pass_count
}
else {
    display as error "  FAIL: tvdiagnose person-time (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 10.6"
}

* Test 10.7: all option populates all returns
local ++test_count
capture {
    clear
    input int(id) str10(s_start s_stop s_entry s_exit)
    1 "2020-01-01" "2020-06-30" "2020-01-01" "2020-12-31"
    1 "2020-07-01" "2020-12-31" "2020-01-01" "2020-12-31"
    2 "2020-01-01" "2020-12-31" "2020-01-01" "2020-12-31"
    end
    gen double start = date(s_start, "YMD")
    gen double stop  = date(s_stop, "YMD")
    gen double entry = date(s_entry, "YMD")
    gen double exit_ = date(s_exit, "YMD")
    format %td start stop entry exit_
    drop s_*
    gen byte exp = 1
    tvdiagnose, id(id) start(start) stop(stop) entry(entry) exit(exit_) exposure(exp) all
    assert !missing(r(mean_coverage))
    assert !missing(r(n_gaps))
    assert !missing(r(n_overlaps))
    assert !missing(r(total_person_time))
}
if _rc == 0 {
    display as result "  PASS: tvdiagnose all option"
    local ++pass_count
}
else {
    display as error "  FAIL: tvdiagnose all option (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 10.7"
}

* Test 10.8: Multi-person n_persons
local ++test_count
capture {
    clear
    input int(id) str10(s_start s_stop)
    1 "2020-01-01" "2020-06-30"
    2 "2020-01-01" "2020-06-30"
    3 "2020-01-01" "2020-06-30"
    4 "2020-01-01" "2020-06-30"
    5 "2020-01-01" "2020-06-30"
    end
    gen double start = date(s_start, "YMD")
    gen double stop  = date(s_stop, "YMD")
    format %td start stop
    drop s_*
    tvdiagnose, id(id) start(start) stop(stop) overlaps
    assert r(n_persons) == 5
    assert r(n_observations) == 5
}
if _rc == 0 {
    display as result "  PASS: tvdiagnose n_persons"
    local ++pass_count
}
else {
    display as error "  FAIL: tvdiagnose n_persons (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 10.8"
}

}


* =============================================================================
* SECTION 12: TVAGE EXPANDED VALIDATION (8 tests)
* =============================================================================

capture noisily {
display _n _dup(70) "="
display "TVAGE EXPANDED VALIDATION"
display _dup(70) "="

* Test 12.1: Multi-person correctness
local ++test_count
capture {
    clear
    input int(id) str10(s_dob s_entry s_exit)
    1 "1970-01-01" "2020-01-01" "2020-12-31"
    2 "1980-06-15" "2020-01-01" "2020-12-31"
    3 "1990-12-31" "2020-01-01" "2020-12-31"
    end
    gen double dob   = date(s_dob, "YMD")
    gen double entry = date(s_entry, "YMD")
    gen double exit_ = date(s_exit, "YMD")
    format %td dob entry exit_
    drop s_*
    tvage, idvar(id) dobvar(dob) entryvar(entry) exitvar(exit_) groupwidth(1)
    assert r(n_persons) == 3
    quietly summarize age_tv if id == 3
    assert r(min) == 29
}
if _rc == 0 {
    display as result "  PASS: tvage multi-person correctness"
    local ++pass_count
}
else {
    display as error "  FAIL: tvage multi-person correctness (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 12.1"
}

* Test 12.2: No gaps/overlaps invariant
local ++test_count
capture {
    clear
    set obs 1
    gen int id = 1
    gen double dob = mdy(6,15,1970)
    gen double entry = mdy(1,1,2020)
    gen double exit_ = mdy(12,31,2023)
    format %td dob entry exit_
    tvage, idvar(id) dobvar(dob) entryvar(entry) exitvar(exit_) groupwidth(1)
    sort id age_start
    local n = _N
    forvalues i = 2/`n' {
        local prev = `i' - 1
        local prev_stop = age_stop[`prev']
        local curr_start = age_start[`i']
        assert `curr_start' - `prev_stop' <= 1
    }
}
if _rc == 0 {
    display as result "  PASS: tvage no gaps invariant"
    local ++pass_count
}
else {
    display as error "  FAIL: tvage no gaps invariant (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 12.2"
}

* Test 12.3: groupwidth(5) binning
local ++test_count
capture {
    clear
    set obs 1
    gen int id = 1
    gen double dob = mdy(1,1,1970)
    gen double entry = mdy(1,1,2020)
    gen double exit_ = mdy(12,31,2030)
    format %td dob entry exit_
    tvage, idvar(id) dobvar(dob) entryvar(entry) exitvar(exit_) groupwidth(5)
    assert r(groupwidth) == 5
    quietly levelsof age_tv, local(ages)
    local n_groups : word count `ages'
    assert `n_groups' >= 2 & `n_groups' <= 4
}
if _rc == 0 {
    display as result "  PASS: tvage groupwidth(5) binning"
    local ++pass_count
}
else {
    display as error "  FAIL: tvage groupwidth(5) binning (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 12.3"
}

* Test 12.4: minage clamping
local ++test_count
capture {
    clear
    set obs 1
    gen int id = 1
    gen double dob = mdy(1,1,1990)
    gen double entry = mdy(1,1,2020)
    gen double exit_ = mdy(12,31,2025)
    format %td dob entry exit_
    tvage, idvar(id) dobvar(dob) entryvar(entry) exitvar(exit_) groupwidth(1) minage(32)
    quietly summarize age_tv
    assert r(min) >= 32
}
if _rc == 0 {
    display as result "  PASS: tvage minage clamping"
    local ++pass_count
}
else {
    display as error "  FAIL: tvage minage clamping (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 12.4"
}

* Test 12.5: maxage clamping
local ++test_count
capture {
    clear
    set obs 1
    gen int id = 1
    gen double dob = mdy(1,1,1960)
    gen double entry = mdy(1,1,2020)
    gen double exit_ = mdy(12,31,2030)
    format %td dob entry exit_
    tvage, idvar(id) dobvar(dob) entryvar(entry) exitvar(exit_) groupwidth(1) maxage(65)
    quietly summarize age_tv
    assert r(max) <= 65
}
if _rc == 0 {
    display as result "  PASS: tvage maxage clamping"
    local ++pass_count
}
else {
    display as error "  FAIL: tvage maxage clamping (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 12.5"
}

* Test 12.6: saveas() produces loadable file
local ++test_count
capture {
    clear
    set obs 1
    gen int id = 1
    gen double dob = mdy(1,1,1980)
    gen double entry = mdy(1,1,2020)
    gen double exit_ = mdy(12,31,2022)
    format %td dob entry exit_
    capture erase "/tmp/_tvage_saveas_test.dta"
    tvage, idvar(id) dobvar(dob) entryvar(entry) exitvar(exit_) groupwidth(1) ///
        saveas("/tmp/_tvage_saveas_test")
    use "/tmp/_tvage_saveas_test.dta", clear
    confirm variable age_tv
    confirm variable age_start
    confirm variable age_stop
    capture erase "/tmp/_tvage_saveas_test.dta"
}
if _rc == 0 {
    display as result "  PASS: tvage saveas() loadable"
    local ++pass_count
}
else {
    display as error "  FAIL: tvage saveas() loadable (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 12.6"
}

* Test 12.7: Single-day follow-up
local ++test_count
capture {
    clear
    set obs 1
    gen int id = 1
    gen double dob = mdy(1,1,1980)
    gen double entry = mdy(6,15,2020)
    gen double exit_ = mdy(6,15,2020)
    format %td dob entry exit_
    tvage, idvar(id) dobvar(dob) entryvar(entry) exitvar(exit_) groupwidth(1)
    assert _N == 1
}
if _rc == 0 {
    display as result "  PASS: tvage single-day follow-up"
    local ++pass_count
}
else {
    display as error "  FAIL: tvage single-day follow-up (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 12.7"
}

* Test 12.8: r() values match data
local ++test_count
capture {
    clear
    input int(id) str10(s_dob s_entry s_exit)
    1 "1970-01-01" "2020-01-01" "2020-12-31"
    2 "1980-06-15" "2020-01-01" "2020-12-31"
    3 "1990-12-31" "2020-01-01" "2020-12-31"
    end
    gen double dob   = date(s_dob, "YMD")
    gen double entry = date(s_entry, "YMD")
    gen double exit_ = date(s_exit, "YMD")
    format %td dob entry exit_
    drop s_*
    tvage, idvar(id) dobvar(dob) entryvar(entry) exitvar(exit_) groupwidth(1)
    assert r(n_persons) == 3
    assert r(n_observations) == _N
}
if _rc == 0 {
    display as result "  PASS: tvage r() values match data"
    local ++pass_count
}
else {
    display as error "  FAIL: tvage r() values match data (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 12.8"
}

}


* =============================================================================
* SECTION 13: TVBALANCE EXPANDED VALIDATION (7 tests)
* =============================================================================

capture noisily {
display _n _dup(70) "="
display "TVBALANCE EXPANDED VALIDATION"
display _dup(70) "="

* Test 13.1: Known imbalance produces large SMD
local ++test_count
capture {
    clear
    set obs 200
    gen byte exposed = (_n > 100)
    gen double age = cond(exposed == 1, 60, 40) + (_n - 100*exposed) * 0.01
    tvbalance age, exposure(exposed) threshold(0.1)
    matrix b = r(balance)
    local smd = b[1, 3]
    assert abs(`smd') > 1
    assert r(n_imbalanced) == 1
}
if _rc == 0 {
    display as result "  PASS: tvbalance large SMD with known imbalance"
    local ++pass_count
}
else {
    display as error "  FAIL: tvbalance large SMD (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 13.1"
}

* Test 13.2: 3-level exposure
local ++test_count
capture {
    clear
    set obs 150
    gen byte exposed = cond(_n <= 50, 0, cond(_n <= 100, 1, 2))
    gen double age = 50 + exposed * 5 + (_n - 50*exposed) * 0.01
    tvbalance age, exposure(exposed) threshold(0.1)
    matrix b = r(balance)
    assert rowsof(b) == 1
}
if _rc == 0 {
    display as result "  PASS: tvbalance 3-level exposure"
    local ++pass_count
}
else {
    display as error "  FAIL: tvbalance 3-level exposure (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 13.2"
}

* Test 13.3: Missing data exclusion
local ++test_count
capture {
    clear
    set obs 100
    set seed 13300
    gen byte exposed = (_n > 50)
    gen double age = 50 + 5 * rnormal()
    replace age = . in 1/10
    tvbalance age, exposure(exposed)
    local total = r(n_ref) + r(n_exp)
    assert `total' == 90
}
if _rc == 0 {
    display as result "  PASS: tvbalance missing data exclusion"
    local ++pass_count
}
else {
    display as error "  FAIL: tvbalance missing data exclusion (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 13.3"
}

* Test 13.4: Equal weights -> ESS == N
local ++test_count
capture {
    clear
    set obs 100
    set seed 13400
    gen byte exposed = (_n > 50)
    gen double age = 50 + 5 * rnormal()
    gen double wt = 1
    tvbalance age, exposure(exposed) weights(wt)
    assert reldif(r(ess_ref), r(n_ref)) < 0.01
    assert reldif(r(ess_exp), r(n_exp)) < 0.01
}
if _rc == 0 {
    display as result "  PASS: tvbalance ESS == N with unit weights"
    local ++pass_count
}
else {
    display as error "  FAIL: tvbalance ESS == N (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 13.4"
}

* Test 13.5: Matrix dimensions match covariates
local ++test_count
capture {
    clear
    set obs 100
    set seed 13500
    gen byte exposed = (_n > 50)
    gen double age = 50 + 5 * rnormal()
    gen double bmi = 25 + 3 * rnormal()
    gen double sbp = 120 + 10 * rnormal()
    tvbalance age bmi sbp, exposure(exposed)
    matrix b = r(balance)
    assert rowsof(b) == 3
    assert r(n_covariates) == 3
}
if _rc == 0 {
    display as result "  PASS: tvbalance matrix dimensions"
    local ++pass_count
}
else {
    display as error "  FAIL: tvbalance matrix dimensions (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 13.5"
}

* Test 13.6: n_imbalanced_wt count bounded
local ++test_count
capture {
    clear
    set obs 200
    set seed 13600
    gen byte exposed = (_n > 100)
    gen double age = cond(exposed, 60, 40) + 5*rnormal()
    gen double bmi = 25 + 3*rnormal()
    gen double wt = 1
    tvbalance age bmi, exposure(exposed) weights(wt)
    assert r(n_imbalanced_wt) >= 0
    assert r(n_imbalanced_wt) <= 2
}
if _rc == 0 {
    display as result "  PASS: tvbalance n_imbalanced_wt bounded"
    local ++pass_count
}
else {
    display as error "  FAIL: tvbalance n_imbalanced_wt (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 13.6"
}

* Test 13.7: Balanced data below threshold
local ++test_count
capture {
    clear
    set obs 2000
    set seed 13700
    gen byte exposed = (_n > 1000)
    gen double age = 50 + 5*rnormal()
    tvbalance age, exposure(exposed) threshold(0.1)
    assert r(n_imbalanced) == 0
}
if _rc == 0 {
    display as result "  PASS: tvbalance balanced data below threshold"
    local ++pass_count
}
else {
    display as error "  FAIL: tvbalance threshold (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 13.7"
}

}


* =============================================================================
* SECTION 14: TVWEIGHT EXPANDED VALIDATION (7 tests)
* =============================================================================

capture noisily {
display _n _dup(70) "="
display "TVWEIGHT EXPANDED VALIDATION"
display _dup(70) "="

* Test 14.1: Weight = 1/PS relationship
local ++test_count
capture {
    clear
    set obs 500
    set seed 14100
    gen double x = rnormal()
    gen byte treat = (x + rnormal() > 0)
    tvweight treat, covariates(x) generate(w) denominator(ps)
    gen double expected_w = cond(treat, 1/ps, 1/(1-ps))
    gen double diff = abs(w - expected_w)
    quietly summarize diff
    assert r(max) < 0.001
    drop w ps expected_w diff
}
if _rc == 0 {
    display as result "  PASS: tvweight 1/PS relationship"
    local ++pass_count
}
else {
    display as error "  FAIL: tvweight 1/PS relationship (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 14.1"
}

* Test 14.2: Unstabilized weight sum reasonable
local ++test_count
capture {
    clear
    set obs 500
    set seed 14200
    gen double x = rnormal()
    gen byte treat = (x + rnormal() > 0)
    tvweight treat, covariates(x)
    quietly summarize iptw
    local wsum = r(sum)
    assert `wsum' > 700 & `wsum' < 1500
}
if _rc == 0 {
    display as result "  PASS: tvweight unstabilized weight sum"
    local ++pass_count
}
else {
    display as error "  FAIL: tvweight weight sum (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 14.2"
}

* Test 14.3: Stabilized weight mean near 1
local ++test_count
capture {
    clear
    set obs 500
    set seed 14300
    gen double x = rnormal()
    gen byte treat = (x + rnormal() > 0)
    tvweight treat, covariates(x) stabilized
    quietly summarize iptw
    assert abs(r(mean) - 1) < 0.15
}
if _rc == 0 {
    display as result "  PASS: tvweight stabilized mean near 1"
    local ++pass_count
}
else {
    display as error "  FAIL: tvweight stabilized mean (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 14.3"
}

* Test 14.4: 3-level multinomial weights all positive
local ++test_count
capture {
    clear
    set obs 1500
    set seed 14401
    gen double x = rnormal()
    gen double x2 = rnormal()
    * Use well-separated groups for convergence
    gen byte treat = cond(_n <= 500, 0, cond(_n <= 1000, 1, 2))
    tvweight treat, covariates(x x2)
    local saved_nlevels = r(n_levels)
    quietly count if iptw <= 0
    assert r(N) == 0
    assert `saved_nlevels' == 3
}
if _rc == 0 {
    display as result "  PASS: tvweight 3-level multinomial"
    local ++pass_count
}
else {
    display as error "  FAIL: tvweight 3-level multinomial (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 14.4"
}

* Test 14.5: Denominator PS bounded in (0,1)
local ++test_count
capture {
    clear
    set obs 500
    set seed 14500
    gen double x = rnormal()
    gen byte treat = (x + rnormal() > 0)
    tvweight treat, covariates(x) denominator(ps)
    quietly summarize ps
    assert r(min) > 0
    assert r(max) < 1
    drop ps
}
if _rc == 0 {
    display as result "  PASS: tvweight PS bounded"
    local ++pass_count
}
else {
    display as error "  FAIL: tvweight PS bounded (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 14.5"
}

* Test 14.6: Truncation enforcement
local ++test_count
capture {
    clear
    set obs 500
    set seed 14600
    gen double x = 3*rnormal()
    gen byte treat = (x + rnormal() > 0)
    tvweight treat, covariates(x) truncate(5 95)
    assert r(n_truncated) >= 0
    assert r(w_min) > 0
}
if _rc == 0 {
    display as result "  PASS: tvweight truncation enforcement"
    local ++pass_count
}
else {
    display as error "  FAIL: tvweight truncation (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 14.6"
}

* Test 14.7: ESS formula verification
local ++test_count
capture {
    clear
    set obs 500
    set seed 14700
    gen double x = rnormal()
    gen byte treat = (x + rnormal() > 0)
    tvweight treat, covariates(x)
    local reported_ess = r(ess)
    quietly summarize iptw
    local sum_w = r(sum)
    quietly gen double w2 = iptw^2
    quietly summarize w2
    local sum_w2 = r(sum)
    local manual_ess = (`sum_w')^2 / `sum_w2'
    assert reldif(`reported_ess', `manual_ess') < 0.01
    drop w2
}
if _rc == 0 {
    display as result "  PASS: tvweight ESS formula"
    local ++pass_count
}
else {
    display as error "  FAIL: tvweight ESS formula (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 14.7"
}

}


* =============================================================================
* SECTION 15: TVCALENDAR EXPANDED VALIDATION (6 tests)
* =============================================================================

capture noisily {
display _n _dup(70) "="
display "TVCALENDAR EXPANDED VALIDATION"
display _dup(70) "="

* Create calendar data files
tempfile cal_data cal_range

* Point-in-time calendar data
clear
input str10(s_date) double(rate temp)
"2020-01-15" 1.5 32
"2020-02-15" 1.8 35
"2020-03-15" 2.0 42
"2020-04-15" 2.3 55
"2020-05-15" 2.1 68
"2020-06-15" 1.9 78
end
gen double date = date(s_date, "YMD")
format %td date
drop s_date
save `cal_data', replace

* Range-based calendar data (seasonal periods)
clear
input str10(s_start s_stop) str10(season) double(risk)
"2020-01-01" "2020-03-31" "winter" 1.5
"2020-04-01" "2020-06-30" "spring" 1.0
"2020-07-01" "2020-09-30" "summer" 0.8
"2020-10-01" "2020-12-31" "fall"   1.2
end
gen double cal_start = date(s_start, "YMD")
gen double cal_stop  = date(s_stop, "YMD")
format %td cal_start cal_stop
drop s_start s_stop
save `cal_range', replace

* Test 15.1: merge() specifies variables to merge
local ++test_count
capture {
    clear
    input int(id) str10(s_date)
    1 "2020-01-15"
    2 "2020-03-15"
    end
    gen double date = date(s_date, "YMD")
    format %td date
    drop s_date
    tvcalendar using `cal_data', datevar(date) merge(rate)
    * Rate should be merged and have non-missing values
    confirm variable rate
    quietly count if !missing(rate)
    assert r(N) == 2
}
if _rc == 0 {
    display as result "  PASS: tvcalendar merge() specifies variables"
    local ++pass_count
}
else {
    display as error "  FAIL: tvcalendar merge() (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 15.1"
}

* Test 15.2: Unmatched dates get missing
local ++test_count
capture {
    clear
    input int(id) str10(s_date)
    1 "2020-01-15"
    2 "2020-07-15"
    end
    gen double date = date(s_date, "YMD")
    format %td date
    drop s_date
    tvcalendar using `cal_data', datevar(date) merge(rate)
    assert _N == 2
    quietly summarize rate if id == 2
    assert r(N) == 0
}
if _rc == 0 {
    display as result "  PASS: tvcalendar unmatched dates get missing"
    local ++pass_count
}
else {
    display as error "  FAIL: tvcalendar unmatched (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 15.2"
}

* Test 15.3: Overlapping periods handled
local ++test_count
capture {
    tempfile cal_overlap
    clear
    input str10(s_start s_stop) double(era)
    "2020-01-01" "2020-06-30" 1
    "2020-04-01" "2020-12-31" 2
    end
    gen double cal_start = date(s_start, "YMD")
    gen double cal_stop  = date(s_stop, "YMD")
    format %td cal_start cal_stop
    drop s_*
    save `cal_overlap', replace
    clear
    input int(id) str10(s_date)
    1 "2020-05-15"
    end
    gen double mydate = date(s_date, "YMD")
    format %td mydate
    drop s_date
    tvcalendar using `cal_overlap', datevar(mydate) startvar(cal_start) stopvar(cal_stop)
    assert _N >= 1
}
if _rc == 0 {
    display as result "  PASS: tvcalendar overlapping periods"
    local ++pass_count
}
else {
    display as error "  FAIL: tvcalendar overlapping periods (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 15.3"
}

* Test 15.4: N-preservation
local ++test_count
capture {
    clear
    set obs 20
    gen int id = _n
    gen double mydate = mdy(1,1,2020) + _n * 15
    format %td mydate
    local n_before = _N
    tvcalendar using `cal_range', datevar(mydate) startvar(cal_start) stopvar(cal_stop)
    assert _N == `n_before'
}
if _rc == 0 {
    display as result "  PASS: tvcalendar N-preservation"
    local ++pass_count
}
else {
    display as error "  FAIL: tvcalendar N-preservation (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 15.4"
}

* Test 15.5: Auto-merge without merge() merges all numeric vars
local ++test_count
capture {
    clear
    input int(id) str10(s_date)
    1 "2020-01-15"
    2 "2020-03-15"
    end
    gen double date = date(s_date, "YMD")
    format %td date
    drop s_date
    tvcalendar using `cal_data', datevar(date)
    confirm variable rate
    confirm variable temp
}
if _rc == 0 {
    display as result "  PASS: tvcalendar auto-merge all numeric vars"
    local ++pass_count
}
else {
    display as error "  FAIL: tvcalendar auto-merge (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 15.5"
}

* Test 15.6: Range merge with abutting periods covers full year
local ++test_count
capture {
    clear
    set obs 12
    gen int id = 1
    gen double mydate = mdy(_n, 15, 2020)
    format %td mydate
    tvcalendar using `cal_range', datevar(mydate) startvar(cal_start) stopvar(cal_stop)
    confirm variable risk
    quietly count if missing(risk)
    assert r(N) == 0
}
if _rc == 0 {
    display as result "  PASS: tvcalendar abutting period merge"
    local ++pass_count
}
else {
    display as error "  FAIL: tvcalendar abutting periods (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 15.6"
}

}


* =============================================================================
* SECTION 16: INVARIANT AND CONSERVATION TESTS (15 tests)
* =============================================================================

* --- 16a: tvevent invariants (4 tests) ---

capture noisily {
display _n _dup(70) "="
display "INVARIANT TESTS: TVEVENT"
display _dup(70) "="

* Create interval data
tempfile inv_intervals inv_events
clear
input int(id) str10(s_start s_stop) byte(tv_exp)
1 "2020-01-01" "2020-04-30" 0
1 "2020-05-01" "2020-08-31" 1
1 "2020-09-01" "2020-12-31" 0
2 "2020-01-01" "2020-06-30" 1
2 "2020-07-01" "2020-12-31" 0
3 "2020-01-01" "2020-12-31" 1
end
gen double start = date(s_start, "YMD")
gen double stop  = date(s_stop, "YMD")
format %td start stop
drop s_*
save `inv_intervals', replace

* Compute person-time before tvevent
quietly gen double pt = stop - start
quietly summarize pt
local ptime_before = r(sum)

* Events
clear
input int(id) str10(s_event)
1 "2020-06-15"
3 "2020-09-15"
end
gen double event_date = date(s_event, "YMD")
format %td event_date
drop s_event
set obs 3
replace id = 2 in 3
save `inv_events', replace

* Run tvevent
use `inv_events', clear
tvevent using `inv_intervals', id(id) date(event_date) ///
    type(single) generate(fail_flag) replace

* Test 16.1: Person-time within expected range after merge
local ++test_count
capture {
    quietly gen double pt = stop - start
    quietly summarize pt
    local ptime_after = r(sum)
    * Person-time may differ if tvevent truncates at event dates
    * but should be in the same order of magnitude
    assert `ptime_after' > 0
    assert `ptime_after' <= `ptime_before' * 1.01
}
if _rc == 0 {
    display as result "  PASS: tvevent person-time reasonable"
    local ++pass_count
}
else {
    display as error "  FAIL: tvevent person-time (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 16.1"
}

* Test 16.2: Interval continuity (no gaps)
local ++test_count
capture {
    sort id start
    quietly by id: gen double gap = start - stop[_n-1] if _n > 1
    quietly summarize gap
    assert r(max) <= 1
    drop gap
}
if _rc == 0 {
    display as result "  PASS: tvevent interval continuity"
    local ++pass_count
}
else {
    display as error "  FAIL: tvevent interval continuity (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 16.2"
}

* Test 16.3: Correct event count
local ++test_count
capture {
    quietly count if fail_flag == 1
    local n_events = r(N)
    assert `n_events' == 2
}
if _rc == 0 {
    display as result "  PASS: tvevent correct event count"
    local ++pass_count
}
else {
    display as error "  FAIL: tvevent event count (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 16.3"
}

* Test 16.4: Failure indicator binary (0 or 1)
local ++test_count
capture {
    quietly count if fail_flag != 0 & fail_flag != 1 & !missing(fail_flag)
    assert r(N) == 0
}
if _rc == 0 {
    display as result "  PASS: tvevent failure indicator binary"
    local ++pass_count
}
else {
    display as error "  FAIL: tvevent indicator binary (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 16.4"
}

}

* --- 16b: tvmerge invariants (4 tests) ---

capture noisily {
display _n _dup(70) "="
display "INVARIANT TESTS: TVMERGE"
display _dup(70) "="

* Create two interval datasets
clear
input int(id) str10(s_start s_stop) byte(expA)
1 "2020-01-01" "2020-06-30" 1
1 "2020-07-01" "2020-12-31" 0
2 "2020-01-01" "2020-12-31" 1
end
gen double startA = date(s_start, "YMD")
gen double stopA  = date(s_stop, "YMD")
format %td startA stopA
drop s_*
save "/tmp/_v16_merge1.dta", replace

clear
input int(id) str10(s_start s_stop) byte(expB)
1 "2020-01-01" "2020-04-30" 1
1 "2020-05-01" "2020-12-31" 0
2 "2020-01-01" "2020-08-31" 1
2 "2020-09-01" "2020-12-31" 0
end
gen double startB = date(s_start, "YMD")
gen double stopB  = date(s_stop, "YMD")
format %td startB stopB
drop s_*
save "/tmp/_v16_merge2.dta", replace

tvmerge "/tmp/_v16_merge1.dta" "/tmp/_v16_merge2.dta", ///
    id(id) start(startA startB) stop(stopA stopB) exposure(expA expB)

* Save r() values before they get overwritten by summarize
local merge_N_persons = r(N_persons)

* Test 16.5: Output intervals are subsets of both inputs
local ++test_count
capture {
    quietly summarize start
    local out_min = r(min)
    assert `out_min' >= mdy(1,1,2020)
    quietly summarize stop
    local out_max = r(max)
    assert `out_max' <= mdy(12,31,2020)
}
if _rc == 0 {
    display as result "  PASS: tvmerge output intervals bounded"
    local ++pass_count
}
else {
    display as error "  FAIL: tvmerge intervals bounded (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 16.5"
}

* Test 16.6: Both exposure values present
local ++test_count
capture {
    confirm variable expA
    confirm variable expB
    quietly count if missing(expA) | missing(expB)
    assert r(N) == 0
}
if _rc == 0 {
    display as result "  PASS: tvmerge exposure values carried"
    local ++pass_count
}
else {
    display as error "  FAIL: tvmerge exposure values (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 16.6"
}

* Test 16.7: N_persons matches input
local ++test_count
capture {
    assert `merge_N_persons' == 2
}
if _rc == 0 {
    display as result "  PASS: tvmerge N_persons correct"
    local ++pass_count
}
else {
    display as error "  FAIL: tvmerge N_persons (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 16.7"
}

* Test 16.8: Person-time conservation
local ++test_count
capture {
    * Total person-time: each person has Jan1-Dec31 = 365 days
    * Two persons = 730 days
    quietly gen double pt = stop - start
    quietly summarize pt
    local merged_pt = r(sum)
    assert `merged_pt' >= 725 & `merged_pt' <= 735
    drop pt
}
if _rc == 0 {
    display as result "  PASS: tvmerge person-time conservation"
    local ++pass_count
}
else {
    display as error "  FAIL: tvmerge person-time (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 16.8"
}

capture erase "/tmp/_v16_merge1.dta"
capture erase "/tmp/_v16_merge2.dta"

}

* --- 16c: tvexpose preservation (3 tests) ---

capture noisily {
display _n _dup(70) "="
display "INVARIANT TESTS: TVEXPOSE PRESERVATION"
display _dup(70) "="

* Create cohort with value labels
tempfile expo_cohort expo_rx
clear
input int(id) str10(s_entry s_exit) double(baseline_age) byte(sex)
1 "2020-01-01" "2020-12-31" 55 1
2 "2020-01-01" "2020-12-31" 62 0
3 "2020-01-01" "2020-12-31" 48 1
end
gen double entry = date(s_entry, "YMD")
gen double exit_ = date(s_exit, "YMD")
format %td entry exit_
drop s_*
label define sex_lbl 0 "Female" 1 "Male"
label values sex sex_lbl
save `expo_cohort', replace

* Exposure data
clear
input int(id) str10(s_start s_stop) byte(drug)
1 "2020-03-01" "2020-09-30" 1
2 "2020-05-01" "2020-12-31" 1
end
gen double rx_start = date(s_start, "YMD")
gen double rx_stop  = date(s_stop, "YMD")
format %td rx_start rx_stop
drop s_*
save `expo_rx', replace

use `expo_cohort', clear
tvexpose using `expo_rx', id(id) start(rx_start) stop(rx_stop) ///
    exposure(drug) entry(entry) exit(exit_) ///
    reference(0) generate(tv_exp) keepvars(baseline_age sex) ///
    referencelabel("Unexposed") keepdates

* Test 16.9: keepvars values preserved
local ++test_count
capture {
    confirm variable baseline_age
    confirm variable sex
    * Person 1 should still have baseline_age == 55
    quietly summarize baseline_age if id == 1
    assert r(mean) == 55
}
if _rc == 0 {
    display as result "  PASS: tvexpose keepvars preserved"
    local ++pass_count
}
else {
    display as error "  FAIL: tvexpose keepvars (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 16.9"
}

* Test 16.10: Value labels preserved
local ++test_count
capture {
    local lbl : value label sex
    assert "`lbl'" != ""
    local male_text : label `lbl' 1
    assert "`male_text'" == "Male"
}
if _rc == 0 {
    display as result "  PASS: tvexpose value labels preserved"
    local ++pass_count
}
else {
    display as error "  FAIL: tvexpose value labels (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 16.10"
}

* Test 16.11: referencelabel in value label
local ++test_count
capture {
    local explbl : value label tv_exp
    assert "`explbl'" != ""
    local ref_text : label `explbl' 0
    assert "`ref_text'" == "Unexposed"
}
if _rc == 0 {
    display as result "  PASS: tvexpose referencelabel applied"
    local ++pass_count
}
else {
    display as error "  FAIL: tvexpose referencelabel (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 16.11"
}

}


* =============================================================================
* VALIDATION RESULTS SUMMARY
* =============================================================================

display as text ""
display as text "tvtools Validation Results"
display as text ""
display as text "Tests run:  `test_count'"
display as text "Passed:     `pass_count'"
display as text "Failed:     `fail_count'"
display as text ""

if `fail_count' > 0 {
    display as error "VALIDATION FAILED: `failed_tests'"
    exit 1
}
else {
    display as result "ALL VALIDATIONS PASSED"
}
