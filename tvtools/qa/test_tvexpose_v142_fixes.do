/*******************************************************************************
* test_tvexpose_v142_fixes.do
*
* Purpose: Regression tests for tvexpose v1.4.2 bug fixes
*   1. window() off-by-N fix (exp_stop computed from original start)
*   2. Dead tempvar removal (no __break tempvar leak)
*   3. set more restored after execution
*   4. Bytype duration with threshold crossing (exercises __cumul_start_days_)
*   5. Complete person-time coverage with window()
*   6. Return values
*
* Note on output variable names: tvexpose renames output start/stop columns
* back to the original names from start()/stop(). Tests use start(start)
* and stop(stop) so output columns are named "start" and "stop".
*
* Author: Timothy P Copeland
* Date: 2026-03-06
*******************************************************************************/

clear all
set more off
version 16.0

* Uninstall any existing version and install from local
capture net uninstall tvtools
quietly net install tvtools, from("`c(pwd)'/..") replace

local test_count = 0
local pass_count = 0
local fail_count = 0

* =============================================================================
* TEST 1: window() produces correct date boundaries
* =============================================================================
* window(1 7) should produce [orig+1, orig+7], a 7-day window
* Before fix: produced [orig+1, orig+8] (8-day window, off-by-1)
local ++test_count
capture {
    clear
    set obs 1
    gen long id = 1
    gen double entry = mdy(1, 1, 2020)
    gen double exit = mdy(12, 31, 2020)
    format entry exit %tdCCYY/NN/DD
    tempfile master
    save `master'

    * Exposure: single period starting Apr 10, ending Jul 19
    clear
    set obs 1
    gen long id = 1
    gen double start = mdy(4, 10, 2020)
    gen double stop = mdy(7, 19, 2020)
    gen int drug = 1
    format start stop %tdCCYY/NN/DD
    tempfile exp_data
    save `exp_data'

    use `master', clear
    tvexpose using `exp_data', id(id) start(start) stop(stop) ///
        exposure(drug) reference(0) entry(entry) exit(exit) ///
        window(1 7) keepdates

    * Find the exposed period
    quietly count if tv_exposure == 1
    assert r(N) == 1

    * Check exposed period boundaries
    quietly summarize start if tv_exposure == 1
    local actual_start = r(mean)
    quietly summarize stop if tv_exposure == 1
    local actual_stop = r(mean)

    * Expected: start = Apr 10 + 1 = Apr 11, stop = Apr 10 + 7 = Apr 17
    assert `actual_start' == mdy(4, 11, 2020)
    assert `actual_stop' == mdy(4, 17, 2020)

    * Verify window length = 7 days (inclusive)
    assert (`actual_stop' - `actual_start' + 1) == 7
}
if _rc == 0 {
    display as result "  PASS: window(1 7) produces correct 7-day window [start+1, start+7]"
    local ++pass_count
}
else {
    display as error "  FAIL: window(1 7) date boundaries incorrect (error `=_rc')"
    local ++fail_count
}

* =============================================================================
* TEST 2: window() with larger values
* =============================================================================
* window(30 90) should produce [orig+30, orig+90], a 61-day window
local ++test_count
capture {
    clear
    set obs 1
    gen long id = 1
    gen double entry = mdy(1, 1, 2020)
    gen double exit = mdy(12, 31, 2020)
    format entry exit %tdCCYY/NN/DD
    tempfile master2
    save `master2'

    clear
    set obs 1
    gen long id = 1
    gen double start = mdy(3, 1, 2020)
    gen double stop = mdy(12, 1, 2020)
    gen int drug = 1
    format start stop %tdCCYY/NN/DD
    tempfile exp2
    save `exp2'

    use `master2', clear
    tvexpose using `exp2', id(id) start(start) stop(stop) ///
        exposure(drug) reference(0) entry(entry) exit(exit) ///
        window(30 90) keepdates

    quietly summarize start if tv_exposure == 1
    local s = r(mean)
    quietly summarize stop if tv_exposure == 1
    local e = r(mean)

    * Expected: start = Mar 1 + 30 = Mar 31, stop = Mar 1 + 90 = May 30
    assert `s' == mdy(3, 31, 2020)
    assert `e' == mdy(5, 30, 2020)

    * Window length = 61 days
    assert (`e' - `s' + 1) == 61
}
if _rc == 0 {
    display as result "  PASS: window(30 90) produces correct 61-day window"
    local ++pass_count
}
else {
    display as error "  FAIL: window(30 90) boundaries incorrect (error `=_rc')"
    local ++fail_count
}

* =============================================================================
* TEST 3: window() truncation when exposure period is short
* =============================================================================
local ++test_count
capture {
    clear
    set obs 1
    gen long id = 1
    gen double entry = mdy(1, 1, 2020)
    gen double exit = mdy(12, 31, 2020)
    format entry exit %tdCCYY/NN/DD
    tempfile master3
    save `master3'

    * Short exposure: Jun 1-5 (only 5 days)
    clear
    set obs 1
    gen long id = 1
    gen double start = mdy(6, 1, 2020)
    gen double stop = mdy(6, 5, 2020)
    gen int drug = 1
    format start stop %tdCCYY/NN/DD
    tempfile exp3
    save `exp3'

    use `master3', clear
    tvexpose using `exp3', id(id) start(start) stop(stop) ///
        exposure(drug) reference(0) entry(entry) exit(exit) ///
        window(1 7) keepdates

    * exp_stop = min(Jun 1 + 7, Jun 5) = Jun 5 (truncated)
    * exp_start = Jun 1 + 1 = Jun 2
    * Result: [Jun 2, Jun 5] = 4 days
    quietly count if tv_exposure == 1
    assert r(N) == 1

    quietly summarize start if tv_exposure == 1
    assert r(mean) == mdy(6, 2, 2020)
    quietly summarize stop if tv_exposure == 1
    assert r(mean) == mdy(6, 5, 2020)
}
if _rc == 0 {
    display as result "  PASS: window() correctly truncates to exposure period end"
    local ++pass_count
}
else {
    display as error "  FAIL: window() truncation incorrect (error `=_rc')"
    local ++fail_count
}

* =============================================================================
* TEST 4: set more is restored after tvexpose
* =============================================================================
local ++test_count
capture {
    set more on

    clear
    set obs 2
    gen long id = _n
    gen double entry = mdy(1, 1, 2020)
    gen double exit = mdy(12, 31, 2020)
    format entry exit %tdCCYY/NN/DD
    tempfile master4
    save `master4'

    clear
    set obs 1
    gen long id = 1
    gen double start = mdy(3, 1, 2020)
    gen double stop = mdy(6, 1, 2020)
    gen int drug = 1
    format start stop %tdCCYY/NN/DD
    tempfile exp4
    save `exp4'

    use `master4', clear
    tvexpose using `exp4', id(id) start(start) stop(stop) ///
        exposure(drug) reference(0) entry(entry) exit(exit)

    assert "`c(more)'" == "on"
    set more off
}
if _rc == 0 {
    display as result "  PASS: set more restored after tvexpose"
    local ++pass_count
}
else {
    set more off
    display as error "  FAIL: set more not restored (error `=_rc')"
    local ++fail_count
}

* =============================================================================
* TEST 5: No tempvar leak (__break, __grp, __ovl)
* =============================================================================
local ++test_count
capture {
    clear
    set obs 2
    gen long id = _n
    gen double entry = mdy(1, 1, 2020)
    gen double exit = mdy(12, 31, 2020)
    format entry exit %tdCCYY/NN/DD
    tempfile master5
    save `master5'

    clear
    set obs 2
    gen long id = 1
    gen double start = mdy(3, 1, 2020) if _n == 1
    replace start = mdy(6, 1, 2020) if _n == 2
    gen double stop = mdy(5, 31, 2020) if _n == 1
    replace stop = mdy(9, 30, 2020) if _n == 2
    gen int drug = 1
    format start stop %tdCCYY/NN/DD
    tempfile exp5
    save `exp5'

    use `master5', clear
    tvexpose using `exp5', id(id) start(start) stop(stop) ///
        exposure(drug) reference(0) entry(entry) exit(exit) ///
        continuousunit(years) expandunit(months)

    * Verify no __ prefixed variables leaked into output
    capture confirm variable __break
    assert _rc != 0
    capture confirm variable __grp
    assert _rc != 0
    capture confirm variable __ovl
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: No __ tempvar variables leaked into output"
    local ++pass_count
}
else {
    display as error "  FAIL: Tempvar leak detected in output (error `=_rc')"
    local ++fail_count
}

* =============================================================================
* TEST 6: Bytype duration with threshold crossing
* =============================================================================
* Exercises __cumul_start_days_ (was __cumul_units_start_ before fix)
local ++test_count
capture {
    clear
    set obs 3
    gen long id = _n
    gen double entry = mdy(1, 1, 2018)
    gen double exit = mdy(12, 31, 2022)
    format entry exit %tdCCYY/NN/DD
    tempfile master6
    save `master6'

    clear
    set obs 4
    gen long id = 1 if _n <= 2
    replace id = 2 if _n == 3
    replace id = 3 if _n == 4
    gen int drug = 1 if inlist(_n, 1, 3)
    replace drug = 2 if inlist(_n, 2, 4)
    gen double start = mdy(1, 15, 2018) if _n == 1
    replace start = mdy(6, 1, 2019) if _n == 2
    replace start = mdy(3, 1, 2018) if _n == 3
    replace start = mdy(1, 1, 2020) if _n == 4
    gen double stop = mdy(12, 31, 2020) if _n == 1
    replace stop = mdy(12, 31, 2021) if _n == 2
    replace stop = mdy(12, 31, 2020) if _n == 3
    replace stop = mdy(6, 30, 2022) if _n == 4
    format start stop %tdCCYY/NN/DD
    tempfile exp6
    save `exp6'

    use `master6', clear
    tvexpose using `exp6', id(id) start(start) stop(stop) ///
        exposure(drug) reference(0) entry(entry) exit(exit) ///
        duration(1 3) continuousunit(years) bytype keepdates

    * Should create duration1 and duration2 variables
    confirm variable duration1
    confirm variable duration2

    * Person-time should be complete
    gen double pt = stop - start + 1
    bysort id: egen double total_pt = total(pt)
    gen double expected_pt = study_exit - study_entry + 1
    bysort id: gen byte first = _n == 1
    assert abs(total_pt - expected_pt) < 2 if first
}
if _rc == 0 {
    display as result "  PASS: Bytype duration with threshold crossing works correctly"
    local ++pass_count
}
else {
    display as error "  FAIL: Bytype duration threshold crossing (error `=_rc')"
    local ++fail_count
}

* =============================================================================
* TEST 7: Complete person-time coverage after window()
* =============================================================================
local ++test_count
capture {
    clear
    set obs 3
    gen long id = _n
    gen double entry = mdy(1, 1, 2020)
    gen double exit = mdy(12, 31, 2020)
    format entry exit %tdCCYY/NN/DD
    tempfile master7
    save `master7'

    clear
    set obs 2
    gen long id = 1 if _n == 1
    replace id = 2 if _n == 2
    gen double start = mdy(4, 1, 2020)
    gen double stop = mdy(8, 31, 2020)
    gen int drug = 1
    format start stop %tdCCYY/NN/DD
    tempfile exp7
    save `exp7'

    use `master7', clear
    tvexpose using `exp7', id(id) start(start) stop(stop) ///
        exposure(drug) reference(0) entry(entry) exit(exit) ///
        window(7 30) keepdates

    * Check complete coverage for each person
    gen double pt = stop - start + 1
    bysort id: egen double total_pt = total(pt)
    gen double expected_pt = study_exit - study_entry + 1
    bysort id: gen byte first = _n == 1

    count if abs(total_pt - expected_pt) > 1 & first
    assert r(N) == 0

    * Check no overlapping periods within person
    sort id start
    by id: gen byte overlap_chk = (start <= stop[_n-1]) if _n > 1
    count if overlap_chk == 1
    assert r(N) == 0
}
if _rc == 0 {
    display as result "  PASS: Complete person-time coverage with window() option"
    local ++pass_count
}
else {
    display as error "  FAIL: Person-time coverage gap with window() (error `=_rc')"
    local ++fail_count
}

* =============================================================================
* TEST 8: Return values present after successful run
* =============================================================================
local ++test_count
capture {
    clear
    set obs 2
    gen long id = _n
    gen double entry = mdy(1, 1, 2020)
    gen double exit = mdy(12, 31, 2020)
    format entry exit %tdCCYY/NN/DD
    tempfile master8
    save `master8'

    clear
    set obs 1
    gen long id = 1
    gen double start = mdy(3, 1, 2020)
    gen double stop = mdy(6, 1, 2020)
    gen int drug = 1
    format start stop %tdCCYY/NN/DD
    tempfile exp8
    save `exp8'

    use `master8', clear
    tvexpose using `exp8', id(id) start(start) stop(stop) ///
        exposure(drug) reference(0) entry(entry) exit(exit)

    assert r(N_persons) == 2
    assert r(N_periods) > 0
    assert r(total_time) > 0
    assert r(exposed_time) > 0
    assert r(unexposed_time) > 0
    assert r(pct_exposed) > 0 & r(pct_exposed) < 100
}
if _rc == 0 {
    display as result "  PASS: Return values correct after execution"
    local ++pass_count
}
else {
    display as error "  FAIL: Return values missing or incorrect (error `=_rc')"
    local ++fail_count
}

* =============================================================================
* TEST 9: Version loads
* =============================================================================
local ++test_count
capture {
    which tvexpose
}
if _rc == 0 {
    display as result "  PASS: tvexpose loads successfully (version check)"
    local ++pass_count
}
else {
    display as error "  FAIL: tvexpose failed to load (error `=_rc')"
    local ++fail_count
}

* =============================================================================
* SUMMARY
* =============================================================================
display ""
display as text "============================================="
display as text "  tvexpose v1.4.2 Regression Tests"
display as text "============================================="
display as text "  Tests run:    " as result `test_count'
display as text "  Passed:       " as result `pass_count'
display as text "  Failed:       " as result `fail_count'
display as text "============================================="

if `fail_count' == 0 {
    display as result "  ALL TESTS PASSED"
}
else {
    display as error "  `fail_count' TEST(S) FAILED"
}
display as text "============================================="

if `fail_count' > 0 {
    exit 9
}
