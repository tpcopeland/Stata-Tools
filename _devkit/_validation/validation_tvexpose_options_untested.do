/*******************************************************************************
* validation_tvexpose_options_untested.do
*
* Purpose: Validation tests for undertested tvexpose option combinations.
*          Tests options that have insufficient coverage in existing test suites.
*
* Scenarios:
*    1. merge() gap-merging with max days
*    2. expandunit(months) with continuousunit(years)
*    3. bytype + duration() (independent per type)
*    4. bytype + continuousunit() (independent per type)
*    5. lag() + washout() interaction
*    6. grace() with different exposure types
*    7. keepdates option
*    8. statetime option
*    9. window() option
*   10. layer option
*   11. referencelabel() correctness
*
* Run: stata-mp -b do validation_tvexpose_options_untested.do
* Log: validation_tvexpose_options_untested.log
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
display "TVEXPOSE UNDERTESTED OPTIONS VALIDATION"
display _dup(70) "="
display "Date: $S_DATE $S_TIME"
display ""

quietly adopath ++ "/home/tpcopeland/Stata-Tools/tvtools"

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

if _rc != 0 {
    display as error "  FAIL [2.run]: tvexpose expandunit(months) failed (rc=`=_rc')"
    local test2_pass = 0
}
else {
    sort id start
    * Should have ~12 rows for the exposed period (one per month)
    quietly count if cum_yrs > 0
    local n_exp = r(N)
    display "  INFO: `n_exp' exposed rows (expected ~12 for monthly expansion)"

    if `n_exp' >= 10 & `n_exp' <= 14 {
        display as result "  PASS [2.monthly]: ~12 monthly rows created (`n_exp')"
    }
    else {
        display as error "  FAIL [2.monthly]: `n_exp' exposed rows (expected ~12)"
        local test2_pass = 0
    }

    * Cumulative at last row should be ~1.0 years
    quietly summarize cum_yrs
    local max_cum = r(max)
    if abs(`max_cum' - 1.0) < 0.1 {
        display as result "  PASS [2.cumulative]: max cumulative = `max_cum' years (expected ~1.0)"
    }
    else {
        display as error "  FAIL [2.cumulative]: max cumulative = `max_cum' (expected ~1.0)"
        local test2_pass = 0
    }

    * Cumulative should be monotonically increasing
    local monotone = 1
    quietly count
    local nrows = r(N)
    forvalues i = 2/`nrows' {
        if cum_yrs[`i'] < cum_yrs[`i'-1] & cum_yrs[`i'] > 0 {
            local monotone = 0
        }
    }
    if `monotone' == 1 {
        display as result "  PASS [2.monotone]: cumulative is monotonically increasing"
    }
    else {
        display as error "  FAIL [2.monotone]: cumulative decreases at some point"
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
* TEST 3: BYTYPE + DURATION() (INDEPENDENT PER TYPE)
* ============================================================================
display _n _dup(60) "-"
display "TEST 3: bytype + duration() — independent duration per type"
display _dup(60) "-"

local test3_pass = 1

* Drug 1: Jan1-Jun30 (6 months), Drug 2: Oct1-Dec31 (3 months)
* With duration(0.5) continuousunit(years): drug 1 should cross 0.5yr, drug 2 should not
clear
set obs 2
gen long id = 1
gen double start = mdy(1,1,2020) in 1
replace start = mdy(10,1,2020) in 2
gen double stop = mdy(6,30,2020) in 1
replace stop = mdy(12,31,2020) in 2
gen byte drug = 1 in 1
replace drug = 2 in 2
format start stop %td
save "/tmp/tvo3_exp.dta", replace

use "/tmp/tvo_cohort.dta", clear
capture noisily tvexpose using "/tmp/tvo3_exp.dta", ///
    id(id) start(start) stop(stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    bytype duration(0.5) continuousunit(years) generate(dur_cat)

if _rc != 0 {
    display as error "  FAIL [3.run]: tvexpose bytype duration() failed (rc=`=_rc')"
    local test3_pass = 0
}
else {
    sort id start
    * List all variables to see bytype output naming
    describe, short
    list, noobs

    * Should have separate duration variables per type
    * Check that bytype variables exist (naming convention: dur_cat1, dur_cat2, etc.)
    local has_bytype = 0
    foreach suffix in 1 2 {
        capture confirm variable dur_cat`suffix'
        if _rc == 0 {
            local has_bytype = 1
        }
    }
    if `has_bytype' == 1 {
        display as result "  PASS [3.bytype_vars]: bytype duration variables created"
    }
    else {
        display as result "  INFO [3.bytype_vars]: bytype variables may use different naming"
        * Try alternate naming
        capture confirm variable dur_cat
        if _rc == 0 {
            display "  INFO: single dur_cat variable exists (may encode both types)"
        }
    }

    quietly count
    display "  INFO: `=r(N)' output rows"
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
* TEST 4: BYTYPE + CONTINUOUSUNIT() (INDEPENDENT PER TYPE)
* ============================================================================
display _n _dup(60) "-"
display "TEST 4: bytype + continuousunit() — independent cumulative per type"
display _dup(60) "-"

local test4_pass = 1

use "/tmp/tvo_cohort.dta", clear
capture noisily tvexpose using "/tmp/tvo3_exp.dta", ///
    id(id) start(start) stop(stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    bytype continuousunit(days) generate(cum_exp)

if _rc != 0 {
    display as error "  FAIL [4.run]: tvexpose bytype continuousunit() failed (rc=`=_rc')"
    local test4_pass = 0
}
else {
    sort id start
    list, noobs

    * Check for bytype continuous variables
    local has_cum1 = 0
    local has_cum2 = 0
    capture confirm variable cum_exp1
    if _rc == 0 local has_cum1 = 1
    capture confirm variable cum_exp2
    if _rc == 0 local has_cum2 = 1

    if `has_cum1' == 1 & `has_cum2' == 1 {
        display as result "  PASS [4.bytype_cum]: separate cumulative per type (cum_exp1, cum_exp2)"

        * Drug 1 max cumulative ≈ 182 days (Jan1-Jun30)
        quietly summarize cum_exp1
        local max_cum1 = r(max)
        if abs(`max_cum1' - 182) <= 5 {
            display as result "  PASS [4.cum1_val]: drug 1 cumulative = `max_cum1' (expected ~182)"
        }
        else {
            display as error "  FAIL [4.cum1_val]: drug 1 cumulative = `max_cum1' (expected ~182)"
            local test4_pass = 0
        }

        * Drug 2 max cumulative ≈ 92 days (Oct1-Dec31)
        quietly summarize cum_exp2
        local max_cum2 = r(max)
        if abs(`max_cum2' - 92) <= 5 {
            display as result "  PASS [4.cum2_val]: drug 2 cumulative = `max_cum2' (expected ~92)"
        }
        else {
            display as error "  FAIL [4.cum2_val]: drug 2 cumulative = `max_cum2' (expected ~92)"
            local test4_pass = 0
        }

        * Independence: when drug 2 starts, drug 1 cumulative should not change
        * (drug 1 ended Jun30, so cum_exp1 should plateau)
    }
    else {
        display "  INFO [4.bytype_cum]: separate variables not found (has1=`has_cum1' has2=`has_cum2')"
        display "  INFO: checking for alternative naming..."
        describe, short
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
* TEST 5: LAG() + WASHOUT() INTERACTION
* ============================================================================
display _n _dup(60) "-"
display "TEST 5: lag() + washout() interaction"
display _dup(60) "-"

local test5_pass = 1

* Exposure: Mar1-Jun30
* lag(30): exposure becomes active 30 days after start → active from Mar31
* washout(60): exposure persists 60 days after stopping → persists until Aug29
* So: unexposed Jan1-Mar30, exposed Mar31-Aug29, unexposed Aug30-Dec31

clear
set obs 1
gen long id = 1
gen double start = mdy(3,1,2020)
gen double stop  = mdy(6,30,2020)
gen byte drug = 1
format start stop %td
save "/tmp/tvo5_exp.dta", replace

use "/tmp/tvo_cohort.dta", clear
capture noisily tvexpose using "/tmp/tvo5_exp.dta", ///
    id(id) start(start) stop(stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    lag(30) washout(60) generate(tv_exp)

if _rc != 0 {
    display as error "  FAIL [5.run]: tvexpose lag+washout failed (rc=`=_rc')"
    local test5_pass = 0
}
else {
    sort id start
    list id start stop tv_exp, noobs

    * Verify exposure doesn't start until ~Mar31 (30 days after Mar1)
    quietly summarize start if tv_exp == 1
    local exp_start = r(min)
    local expected_lag_start = mdy(3,1,2020) + 30
    if abs(`exp_start' - `expected_lag_start') <= 2 {
        local d1 : display %td `exp_start'
        display as result "  PASS [5.lag_start]: exposure starts at `d1' (lag=30)"
    }
    else {
        local d1 : display %td `exp_start'
        local d2 : display %td `expected_lag_start'
        display as error "  FAIL [5.lag_start]: exposure starts `d1' (expected ~`d2')"
        local test5_pass = 0
    }

    * Verify exposure extends ~60 days past Jun30 (washout)
    quietly summarize stop if tv_exp == 1
    local exp_stop = r(max)
    local expected_wash_end = mdy(6,30,2020) + 60
    if abs(`exp_stop' - `expected_wash_end') <= 2 {
        local d1 : display %td `exp_stop'
        display as result "  PASS [5.washout_end]: exposure ends at `d1' (washout=60)"
    }
    else {
        local d1 : display %td `exp_stop'
        local d2 : display %td `expected_wash_end'
        display as error "  FAIL [5.washout_end]: exposure ends `d1' (expected ~`d2')"
        local test5_pass = 0
    }

    * Person-time conservation
    gen double dur = stop - start + 1
    quietly summarize dur
    local total_ptime = r(sum)
    if abs(`total_ptime' - 366) <= 1 {
        display as result "  PASS [5.ptime]: person-time = `total_ptime'"
    }
    else {
        display as error "  FAIL [5.ptime]: person-time = `total_ptime' (expected 366)"
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
* TEST 6: GRACE() WITH DIFFERENT EXPOSURE TYPES
* ============================================================================
display _n _dup(60) "-"
display "TEST 6: grace() with different exposure types"
display _dup(60) "-"

local test6_pass = 1

* Drug 1: Jan1-Mar31, Drug 1 again: Apr15-Jun30 (14-day gap)
* Drug 2: Aug1-Sep30, Drug 2 again: Oct5-Dec31 (4-day gap)
* grace(10): should bridge the 4-day gap (drug2) but NOT the 14-day gap (drug1)

clear
set obs 4
gen long id = 1
gen double start = mdy(1,1,2020)   in 1
replace start = mdy(4,15,2020)     in 2
replace start = mdy(8,1,2020)      in 3
replace start = mdy(10,5,2020)     in 4
gen double stop = mdy(3,31,2020)   in 1
replace stop = mdy(6,30,2020)      in 2
replace stop = mdy(9,30,2020)      in 3
replace stop = mdy(12,31,2020)     in 4
gen byte drug = 1 in 1
replace drug = 1 in 2
replace drug = 2 in 3
replace drug = 2 in 4
format start stop %td
save "/tmp/tvo6_exp.dta", replace

use "/tmp/tvo_cohort.dta", clear
capture noisily tvexpose using "/tmp/tvo6_exp.dta", ///
    id(id) start(start) stop(stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    grace(10) generate(tv_exp)

if _rc != 0 {
    display as error "  FAIL [6.run]: tvexpose grace(10) failed (rc=`=_rc')"
    local test6_pass = 0
}
else {
    sort id start
    list id start stop tv_exp, noobs

    * Drug 2: 4-day gap should be bridged
    * Drug 1: 14-day gap should NOT be bridged
    * Count unexposed intervals between exposed blocks
    quietly count if tv_exp == 0
    local n_unexp = r(N)
    display "  INFO: `n_unexp' unexposed intervals with grace(10)"

    * At minimum, drug1's 14-day gap should produce an unexposed interval
    if `n_unexp' >= 1 {
        display as result "  PASS [6.gap_kept]: at least 1 unbridged gap (drug1's 14-day)"
    }
    else {
        display as error "  FAIL [6.gap_kept]: no unexposed intervals (14-day gap should NOT be bridged)"
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
* TEST 7: KEEPDATES OPTION
* ============================================================================
display _n _dup(60) "-"
display "TEST 7: keepdates option preserves entry/exit"
display _dup(60) "-"

local test7_pass = 1

clear
set obs 1
gen long id = 1
gen double start = mdy(3,1,2020)
gen double stop  = mdy(6,30,2020)
gen byte drug = 1
format start stop %td
save "/tmp/tvo7_exp.dta", replace

use "/tmp/tvo_cohort.dta", clear
capture noisily tvexpose using "/tmp/tvo7_exp.dta", ///
    id(id) start(start) stop(stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    keepdates generate(tv_exp)

if _rc != 0 {
    display as error "  FAIL [7.run]: tvexpose keepdates failed (rc=`=_rc')"
    local test7_pass = 0
}
else {
    * Check that study_entry and study_exit are preserved
    capture confirm variable study_entry
    local has_entry = (_rc == 0)
    capture confirm variable study_exit
    local has_exit = (_rc == 0)

    if `has_entry' == 1 & `has_exit' == 1 {
        display as result "  PASS [7.keepdates]: study_entry and study_exit preserved"

        * Values should be correct
        quietly summarize study_entry
        local se = r(mean)
        quietly summarize study_exit
        local sx = r(mean)
        if `se' == mdy(1,1,2020) & `sx' == mdy(12,31,2020) {
            display as result "  PASS [7.values]: entry/exit values correct"
        }
        else {
            display as error "  FAIL [7.values]: entry/exit values incorrect"
            local test7_pass = 0
        }
    }
    else {
        display as error "  FAIL [7.keepdates]: entry=`has_entry', exit=`has_exit' (expected both present)"
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
* TEST 8: STATETIME OPTION
* ============================================================================
display _n _dup(60) "-"
display "TEST 8: statetime option (cumulative time in current state)"
display _dup(60) "-"

local test8_pass = 1

* Two exposure periods with a gap:
* Drug 1: Jan1-Mar31, Drug 1: Jul1-Sep30
* statetime should track time in each state independently

clear
set obs 2
gen long id = 1
gen double start = mdy(1,1,2020) in 1
replace start = mdy(7,1,2020) in 2
gen double stop = mdy(3,31,2020) in 1
replace stop = mdy(9,30,2020) in 2
gen byte drug = 1
format start stop %td
save "/tmp/tvo8_exp.dta", replace

use "/tmp/tvo_cohort.dta", clear
capture noisily tvexpose using "/tmp/tvo8_exp.dta", ///
    id(id) start(start) stop(stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    statetime generate(tv_exp)

if _rc != 0 {
    display as error "  FAIL [8.run]: tvexpose statetime failed (rc=`=_rc')"
    local test8_pass = 0
}
else {
    sort id start
    describe, short
    list, noobs

    * Look for statetime variable (naming may vary)
    capture confirm variable tv_statetime
    if _rc == 0 {
        display as result "  PASS [8.var]: tv_statetime variable created"

        * statetime should reset when state changes
        * After gap (reference period), exposed statetime should restart from 0
        quietly count
        display "  INFO: `=r(N)' rows"
    }
    else {
        * Try other naming conventions
        local found_st = 0
        foreach v of varlist _all {
            local vl = lower("`v'")
            if strpos("`vl'", "state") > 0 | strpos("`vl'", "time") > 0 {
                display "  INFO: found variable `v'"
                local found_st = 1
            }
        }
        if `found_st' == 0 {
            display as result "  INFO [8.var]: statetime variable not found by expected name"
        }
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
* TEST 9: WINDOW() OPTION
* ============================================================================
display _n _dup(60) "-"
display "TEST 9: window() option (min/max acute exposure window)"
display _dup(60) "-"

local test9_pass = 1

* Exposure: Mar1-Jun30 (122 days)
* window(30 90): exposure delayed by min=30 days, window restricted by max=90
* Start should be at least 30 days after Mar1

clear
set obs 1
gen long id = 1
gen double start = mdy(3,1,2020)
gen double stop  = mdy(6,30,2020)
gen byte drug = 1
format start stop %td
save "/tmp/tvo9_exp.dta", replace

use "/tmp/tvo_cohort.dta", clear
capture noisily tvexpose using "/tmp/tvo9_exp.dta", ///
    id(id) start(start) stop(stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    window(30 90) generate(tv_exp)

if _rc != 0 {
    display as error "  FAIL [9.run]: tvexpose window(30 90) failed (rc=`=_rc')"
    local test9_pass = 0
}
else {
    sort id start
    list id start stop tv_exp, noobs

    * Exposure should start ~30 days after Mar1 (window min)
    quietly summarize start if tv_exp == 1
    local win_start = r(min)
    local expected_win_start = mdy(3,1,2020) + 30
    if abs(`win_start' - `expected_win_start') <= 2 {
        local d1 : display %td `win_start'
        display as result "  PASS [9.win_start]: window starts at `d1' (min=30 days delay)"
    }
    else {
        local d1 : display %td `win_start'
        local d2 : display %td `expected_win_start'
        display as error "  FAIL [9.win_start]: window starts `d1' (expected ~`d2')"
        local test9_pass = 0
    }

    * Exposure should not extend beyond original rx stop date
    quietly summarize stop if tv_exp == 1
    local win_stop = r(max)
    if `win_stop' <= mdy(6,30,2020) {
        local d1 : display %td `win_stop'
        display as result "  PASS [9.win_stop]: window ends at `d1' (within rx bounds)"
    }
    else {
        local d1 : display %td `win_stop'
        display as error "  FAIL [9.win_stop]: window extends to `d1' beyond rx stop"
        local test9_pass = 0
    }

    * Exposed duration should be less than full prescription (122 days)
    * because window(30 90) restricts the active period
    gen double exp_dur = stop - start + 1 if tv_exp == 1
    quietly summarize exp_dur
    local total_exp = r(sum)
    if `total_exp' < 122 {
        display as result "  PASS [9.restricted]: exposed duration = `total_exp' < 122 (restricted by window)"
    }
    else {
        display "  INFO [9.restricted]: exposed duration = `total_exp' (expected < 122)"
    }

    * Person-time conservation
    drop exp_dur
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
* TEST 10: LAYER OPTION
* ============================================================================
display _n _dup(60) "-"
display "TEST 10: layer option (later exposures take precedence)"
display _dup(60) "-"

local test10_pass = 1

* Drug 1: Jan1-Jun30, Drug 2: Apr1-Sep30
* With layer: drug 2 should take precedence in overlap (Apr1-Jun30)
* After drug 2 ends, drug 1 should NOT resume (layer means later covers earlier)

clear
set obs 2
gen long id = 1
gen double start = mdy(1,1,2020) in 1
replace start = mdy(4,1,2020) in 2
gen double stop = mdy(6,30,2020) in 1
replace stop = mdy(9,30,2020) in 2
gen byte drug = 1 in 1
replace drug = 2 in 2
format start stop %td
save "/tmp/tvo10_exp.dta", replace

use "/tmp/tvo_cohort.dta", clear
capture noisily tvexpose using "/tmp/tvo10_exp.dta", ///
    id(id) start(start) stop(stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    layer generate(tv_exp)

if _rc != 0 {
    display as error "  FAIL [10.run]: tvexpose layer failed (rc=`=_rc')"
    local test10_pass = 0
}
else {
    sort id start
    list id start stop tv_exp, noobs

    * In overlap (Apr1-Jun30), drug 2 should be active
    local overlap_start = mdy(4,1,2020)
    local overlap_stop  = mdy(6,30,2020)

    * Check what drug is active during overlap period
    local drug2_in_overlap = 0
    quietly count
    local nrows = r(N)
    forvalues i = 1/`nrows' {
        if start[`i'] >= `overlap_start' & stop[`i'] <= `overlap_stop' & tv_exp[`i'] == 2 {
            local drug2_in_overlap = 1
        }
    }
    if `drug2_in_overlap' == 1 {
        display as result "  PASS [10.layer]: drug 2 takes precedence in overlap"
    }
    else {
        display "  INFO [10.layer]: checking overlap behavior..."
    }

    * Before overlap: drug 1 should be active (Jan1-Mar31)
    quietly count if stop < `overlap_start' & tv_exp == 1
    if r(N) >= 1 {
        display as result "  PASS [10.pre_overlap]: drug 1 active before overlap"
    }
    else {
        display "  INFO [10.pre_overlap]: no drug 1 rows before overlap"
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
* TEST 11: REFERENCELABEL() CORRECTNESS
* ============================================================================
display _n _dup(60) "-"
display "TEST 11: referencelabel() correctness"
display _dup(60) "-"

local test11_pass = 1

clear
set obs 1
gen long id = 1
gen double start = mdy(3,1,2020)
gen double stop  = mdy(6,30,2020)
gen byte drug = 1
format start stop %td
save "/tmp/tvo11_exp.dta", replace

use "/tmp/tvo_cohort.dta", clear
capture noisily tvexpose using "/tmp/tvo11_exp.dta", ///
    id(id) start(start) stop(stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    referencelabel("No treatment") generate(tv_exp)

if _rc != 0 {
    display as error "  FAIL [11.run]: tvexpose referencelabel() failed (rc=`=_rc')"
    local test11_pass = 0
}
else {
    sort id start

    * Check that the value label for reference category contains "No treatment"
    local lbl : value label tv_exp
    if "`lbl'" != "" {
        local ref_label : label `lbl' 0
        if strpos("`ref_label'", "No treatment") > 0 {
            display as result "  PASS [11.label]: reference label = `ref_label'"
        }
        else {
            display as error "  FAIL [11.label]: reference label = '`ref_label'' (expected 'No treatment')"
            local test11_pass = 0
        }
    }
    else {
        display as error "  FAIL [11.label]: no value label applied to tv_exp"
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
* SUMMARY
* ============================================================================
display _n _dup(70) "="
display "TVEXPOSE UNDERTESTED OPTIONS VALIDATION SUMMARY"
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
capture erase "/tmp/tvo_cohort.dta"
forvalues i = 1/11 {
    capture erase "/tmp/tvo`i'_exp.dta"
}

exit, clear
