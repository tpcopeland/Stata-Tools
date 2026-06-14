clear all
set more off
set varabbrev off
version 16.0

capture log close
log using "test_tvage.log", replace nomsg

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

display as result "tvtools QA: tvage functional -- $S_DATE $S_TIME"


**# ===== merged from test_tvtools.do L50-652: SECTION 1 TVAGE =====

* SECTION 1: TVAGE - Age interval creation and grouping

capture noisily {

* TEST 1: Known DOB/entry/exit - exact age intervals

clear
set obs 1
gen long id = 1
gen dob = mdy(6, 15, 1970)
gen entry = mdy(1, 1, 2020)
gen exit = mdy(12, 31, 2023)
format dob entry exit %tdCCYY/NN/DD

* Age at entry: floor((21915 - 3818) / 365.25) = floor(49.55) = 49
* Age at exit: floor((23376 - 3818) / 365.25) = floor(53.55) = 53
* Should get 5 intervals: ages 49, 50, 51, 52, 53

tvage, idvar(id) dobvar(dob) entryvar(entry) exitvar(exit) groupwidth(1)

local n = _N
if `n' == 5 {
    display as result "PASS: Got " `n' " intervals (expected 5)"
    local pass_count = `pass_count' + 1
}
else {
    display as error "FAIL: Got " `n' " intervals (expected 5)"
    local fail_count = `fail_count' + 1
}

* First interval starts at study entry
sort age_start
local first_start = age_start[1]
local expected_start = mdy(1, 1, 2020)
if `first_start' == `expected_start' {
    display as result "PASS: First start = entry date"
    local pass_count = `pass_count' + 1
}
else {
    display as error "FAIL: First start = " %td `first_start' " (expected " %td `expected_start' ")"
    local fail_count = `fail_count' + 1
}

* Last interval ends at study exit
local last_stop = age_stop[_N]
local expected_stop = mdy(12, 31, 2023)
if `last_stop' == `expected_stop' {
    display as result "PASS: Last stop = exit date"
    local pass_count = `pass_count' + 1
}
else {
    display as error "FAIL: Last stop = " %td `last_stop' " (expected " %td `expected_stop' ")"
    local fail_count = `fail_count' + 1
}

* Person-time conservation
gen double days = age_stop - age_start + 1
quietly summarize days
local total_days = r(sum)
local expected_days = mdy(12, 31, 2023) - mdy(1, 1, 2020) + 1

if `total_days' == `expected_days' {
    display as result "PASS: Person-time conserved (" `total_days' " = " `expected_days' " days)"
    local pass_count = `pass_count' + 1
}
else {
    display as error "FAIL: Person-time " `total_days' " != " `expected_days' " days"
    local fail_count = `fail_count' + 1
}

* TEST 2: Groupwidth 5

clear
set obs 1
gen long id = 1
gen dob = mdy(6, 15, 1970)
gen entry = mdy(1, 1, 2020)
gen exit = mdy(12, 31, 2023)
format dob entry exit %tdCCYY/NN/DD

tvage, idvar(id) dobvar(dob) entryvar(entry) exitvar(exit) groupwidth(5)

* Should get 2 groups: 45-49 and 50-54
local n = _N
if `n' == 2 {
    display as result "PASS: Got " `n' " groups (expected 2)"
    local pass_count = `pass_count' + 1
}
else {
    display as error "FAIL: Got " `n' " groups (expected 2)"
    local fail_count = `fail_count' + 1
}

* Check group values
sort age_start
local g1 = age_tv[1]
local g2 = age_tv[2]
if `g1' == 45 & `g2' == 50 {
    display as result "PASS: Groups are 45 and 50"
    local pass_count = `pass_count' + 1
}
else {
    display as error "FAIL: Groups are " `g1' " and " `g2' " (expected 45 and 50)"
    local fail_count = `fail_count' + 1
}

* TEST 3: Multiple persons

clear
set obs 3
gen long id = _n
gen dob = mdy(1, 1, 1960) in 1
replace dob = mdy(1, 1, 1970) in 2
replace dob = mdy(1, 1, 1980) in 3
gen entry = mdy(1, 1, 2020)
gen exit = mdy(12, 31, 2021)
format dob entry exit %tdCCYY/NN/DD

tvage, idvar(id) dobvar(dob) entryvar(entry) exitvar(exit) groupwidth(1)

* Person 1: age 60 at entry, should get intervals for 60, 61
quietly count if id == 1
local p1 = r(N)

* Person 2: age 50 at entry, should get intervals for 50, 51
quietly count if id == 2
local p2 = r(N)

* Person 3: age 40 at entry, should get intervals for 40, 41
quietly count if id == 3
local p3 = r(N)

if `p1' == 2 & `p2' == 2 & `p3' == 2 {
    display as result "PASS: Each person has 2 intervals"
    local pass_count = `pass_count' + 1
}
else {
    display as error "FAIL: Person intervals: " `p1' ", " `p2' ", " `p3' " (expected 2, 2, 2)"
    local fail_count = `fail_count' + 1
}

* TEST 4: Date precision (no fractional dates)

gen double start_frac = age_start - floor(age_start)
gen double stop_frac = age_stop - floor(age_stop)

quietly summarize start_frac
local max_start_frac = r(max)
quietly summarize stop_frac
local max_stop_frac = r(max)

if `max_start_frac' == 0 & `max_stop_frac' == 0 {
    display as result "PASS: All dates are exact integers"
    local pass_count = `pass_count' + 1
}
else {
    display as error "FAIL: Fractional dates found (max start=" `max_start_frac' " stop=" `max_stop_frac' ")"
    local fail_count = `fail_count' + 1
}

* TEST 5: No overlaps within person

sort id age_start
by id: gen double gap = age_start - age_stop[_n-1] if _n > 1
quietly count if gap < 1 & !missing(gap)
local n_overlaps = r(N)

if `n_overlaps' == 0 {
    display as result "PASS: No overlapping intervals"
    local pass_count = `pass_count' + 1
}
else {
    display as error "FAIL: " `n_overlaps' " overlapping intervals found"
    local fail_count = `fail_count' + 1
}

* TEST 6: No gaps within person

quietly count if gap > 1 & !missing(gap)
local n_gaps = r(N)

if `n_gaps' == 0 {
    display as result "PASS: No gaps between intervals"
    local pass_count = `pass_count' + 1
}
else {
    display as error "FAIL: " `n_gaps' " gaps found"
    local fail_count = `fail_count' + 1
}

}

capture noisily {
* Test tvage fixes for precision, labels, and default groupwidth
* Version 1.1.0 fixes

clear
set seed 42

* TEST 1: Date precision - ensure dates are proper integers for merging

clear
set obs 5
gen long id = _n
gen dob = mdy(1, 1, 1950) + floor(runiform() * 365 * 10)  // Born 1950-1960
gen entry = mdy(1, 1, 2000) + floor(runiform() * 365)     // Enter 2000
gen exit = entry + floor(runiform() * 365 * 20)           // Follow 0-20 years
format dob entry exit %tdCCYY/NN/DD

list, clean noobs

tvage, idvar(id) dobvar(dob) entryvar(entry) exitvar(exit) noisily

* Check that dates are integers (no fractional parts)
gen start_frac = age_start - floor(age_start)
gen stop_frac = age_stop - floor(age_stop)
summarize start_frac stop_frac

assert start_frac == 0
assert stop_frac == 0
drop start_frac stop_frac

}

capture noisily {
* TEST 1: Missing DOB triggers error 416
local ++test_count

clear
set obs 3
gen long id = _n
gen dob = mdy(1, 1, 1960)
replace dob = . in 2
gen entry = mdy(1, 1, 2020)
gen exit = mdy(12, 31, 2022)
format dob entry exit %tdCCYY/NN/DD

capture noisily tvage, idvar(id) dobvar(dob) entryvar(entry) exitvar(exit)
if _rc == 416 {
    display as result "  PASS: Missing DOB correctly triggers error 416"
    local ++pass_count
}
else {
    display as error "  FAIL: Missing DOB returned _rc=" _rc " (expected 416)"
    local ++fail_count
}

* TEST 2: Missing entry date triggers error 416
local ++test_count

clear
set obs 3
gen long id = _n
gen dob = mdy(1, 1, 1960)
gen entry = mdy(1, 1, 2020)
replace entry = . in 3
gen exit = mdy(12, 31, 2022)
format dob entry exit %tdCCYY/NN/DD

capture noisily tvage, idvar(id) dobvar(dob) entryvar(entry) exitvar(exit)
if _rc == 416 {
    display as result "  PASS: Missing entry date correctly triggers error 416"
    local ++pass_count
}
else {
    display as error "  FAIL: Missing entry date returned _rc=" _rc " (expected 416)"
    local ++fail_count
}

* TEST 3: Missing exit date triggers error 416
local ++test_count

clear
set obs 3
gen long id = _n
gen dob = mdy(1, 1, 1960)
gen entry = mdy(1, 1, 2020)
gen exit = mdy(12, 31, 2022)
replace exit = . in 1
format dob entry exit %tdCCYY/NN/DD

capture noisily tvage, idvar(id) dobvar(dob) entryvar(entry) exitvar(exit)
if _rc == 416 {
    display as result "  PASS: Missing exit date correctly triggers error 416"
    local ++pass_count
}
else {
    display as error "  FAIL: Missing exit date returned _rc=" _rc " (expected 416)"
    local ++fail_count
}

* TEST 4: All dates non-missing passes validation
local ++test_count

clear
set obs 3
gen long id = _n
gen dob = mdy(1, 1, 1960)
gen entry = mdy(1, 1, 2020)
gen exit = mdy(12, 31, 2022)
format dob entry exit %tdCCYY/NN/DD

capture noisily tvage, idvar(id) dobvar(dob) entryvar(entry) exitvar(exit)
if _rc == 0 {
    display as result "  PASS: Non-missing dates pass validation"
    local ++pass_count
}
else {
    display as error "  FAIL: Non-missing dates returned _rc=" _rc " (expected 0)"
    local ++fail_count
}

* TEST 5: minage > maxage triggers error 198
local ++test_count

clear
set obs 3
gen long id = _n
gen dob = mdy(1, 1, 1960)
gen entry = mdy(1, 1, 2020)
gen exit = mdy(12, 31, 2022)
format dob entry exit %tdCCYY/NN/DD

capture noisily tvage, idvar(id) dobvar(dob) entryvar(entry) exitvar(exit) ///
    minage(60) maxage(40)
if _rc == 198 {
    display as result "  PASS: minage > maxage correctly triggers error 198"
    local ++pass_count
}
else {
    display as error "  FAIL: minage > maxage returned _rc=" _rc " (expected 198)"
    local ++fail_count
}

* TEST 6: minage == maxage is valid (single age)
local ++test_count

clear
set obs 3
gen long id = _n
gen dob = mdy(1, 1, 1960)
gen entry = mdy(1, 1, 2020)
gen exit = mdy(12, 31, 2022)
format dob entry exit %tdCCYY/NN/DD

capture noisily tvage, idvar(id) dobvar(dob) entryvar(entry) exitvar(exit) ///
    minage(60) maxage(60)
if _rc == 0 {
    display as result "  PASS: minage == maxage accepted (single age)"
    local ++pass_count
}
else {
    display as error "  FAIL: minage == maxage returned _rc=" _rc " (expected 0)"
    local ++fail_count
}

* TEST 7: Empty dataset after age filtering triggers error 2000
local ++test_count

clear
set obs 3
gen long id = _n
gen dob = mdy(1, 1, 1960)
gen entry = mdy(1, 1, 2020)
gen exit = mdy(12, 31, 2022)
format dob entry exit %tdCCYY/NN/DD

* Everyone is ~60 at entry; minage(80) maxage(90) excludes all
capture noisily tvage, idvar(id) dobvar(dob) entryvar(entry) exitvar(exit) ///
    minage(80) maxage(90)
if _rc == 2000 {
    display as result "  PASS: Empty dataset after filtering triggers error 2000"
    local ++pass_count
}
else {
    display as error "  FAIL: Empty dataset returned _rc=" _rc " (expected 2000)"
    local ++fail_count
}

* TEST 8: Data preserved after error 2000 (restore works)
local ++test_count

clear
set obs 5
gen long id = _n
gen dob = mdy(1, 1, 1960)
gen entry = mdy(1, 1, 2020)
gen exit = mdy(12, 31, 2022)
gen marker = 999
format dob entry exit %tdCCYY/NN/DD

local n_before = _N
capture noisily tvage, idvar(id) dobvar(dob) entryvar(entry) exitvar(exit) ///
    minage(80) maxage(90)

* Data should be restored after error
if _N == `n_before' {
    capture confirm variable marker
    if _rc == 0 {
        display as result "  PASS: Original data restored after error 2000"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Original data not fully restored (marker variable missing)"
        local ++fail_count
    }
}
else {
    display as error "  FAIL: _N changed from " `n_before' " to " _N " after error"
    local ++fail_count
}

* TEST 9: Long variable name with groupwidth > 1 (label overflow fix)
local ++test_count

clear
set obs 3
gen long id = _n
gen dob = mdy(1, 1, 1960)
gen entry = mdy(1, 1, 2020)
gen exit = mdy(12, 31, 2025)
format dob entry exit %tdCCYY/NN/DD

* Use a 30-character variable name (> 28, triggers truncation)
capture noisily tvage, idvar(id) dobvar(dob) entryvar(entry) exitvar(exit) ///
    generate(age_variable_name_that_is_lon) groupwidth(5)
if _rc == 0 {
    * Verify variable exists and has labels
    capture confirm variable age_variable_name_that_is_lon
    if _rc == 0 {
        local lbl : value label age_variable_name_that_is_lon
        if "`lbl'" != "" {
            display as result "  PASS: Long variable name with groupwidth works, label = `lbl'"
            local ++pass_count
        }
        else {
            display as error "  FAIL: Variable exists but no value label applied"
            local ++fail_count
        }
    }
    else {
        display as error "  FAIL: Variable not created"
        local ++fail_count
    }
}
else {
    display as error "  FAIL: Long variable name returned _rc=" _rc " (expected 0)"
    local ++fail_count
}

* TEST 10: Default variable name with groupwidth works (no truncation needed)
local ++test_count

clear
set obs 3
gen long id = _n
gen dob = mdy(1, 1, 1960)
gen entry = mdy(1, 1, 2020)
gen exit = mdy(12, 31, 2025)
format dob entry exit %tdCCYY/NN/DD

capture noisily tvage, idvar(id) dobvar(dob) entryvar(entry) exitvar(exit) ///
    groupwidth(5)
if _rc == 0 {
    local lbl : value label age_tv
    if "`lbl'" == "age_tv_lbl" {
        display as result "  PASS: Default name uses age_tv_lbl label"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Expected label 'age_tv_lbl', got '`lbl''"
        local ++fail_count
    }
}
else {
    display as error "  FAIL: Default groupwidth returned _rc=" _rc
    local ++fail_count
}

* TEST 11: Warning suppressed without noisily option
local ++test_count

clear
set obs 3
gen long id = _n
gen dob = mdy(1, 1, 2025)
gen entry = mdy(1, 1, 2020)
gen exit = mdy(12, 31, 2022)
format dob entry exit %tdCCYY/NN/DD

* DOB after entry means invalid ages — all will be dropped
* Without noisily, should still get error 2000 (empty dataset)
* but no warning text should appear
capture noisily tvage, idvar(id) dobvar(dob) entryvar(entry) exitvar(exit)
if _rc == 2000 {
    display as result "  PASS: Invalid ages without noisily triggers error 2000 (no warning shown)"
    local ++pass_count
}
else {
    display as error "  FAIL: Expected error 2000, got _rc=" _rc
    local ++fail_count
}

* TEST 12: Warning shown with noisily option
local ++test_count

clear
set obs 5
gen long id = _n
gen dob = mdy(1, 1, 1960)
replace dob = mdy(1, 1, 2025) in 1
gen entry = mdy(1, 1, 2020)
gen exit = mdy(12, 31, 2022)
format dob entry exit %tdCCYY/NN/DD

* Person 1 has DOB after entry — will be dropped. Others valid.
capture noisily tvage, idvar(id) dobvar(dob) entryvar(entry) exitvar(exit) noisily
if _rc == 0 {
    * Check that we got 4 persons (1 dropped)
    quietly egen _tag = tag(id)
    quietly count if _tag == 1
    if r(N) == 4 {
        display as result "  PASS: 1 invalid person dropped with noisily, 4 remain"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Expected 4 persons, got " r(N)
        local ++fail_count
    }
}
else {
    display as error "  FAIL: Partial invalid with noisily returned _rc=" _rc
    local ++fail_count
}

* TEST 13: Return values correct after saveas + restore
local ++test_count

clear
set obs 3
gen long id = _n
gen dob = mdy(1, 1, 1960)
gen entry = mdy(1, 1, 2020)
gen exit = mdy(12, 31, 2022)
gen marker = 888
format dob entry exit %tdCCYY/NN/DD

tempfile tvout
capture noisily tvage, idvar(id) dobvar(dob) entryvar(entry) exitvar(exit) ///
    saveas("`tvout'") replace
if _rc == 0 {
    * After saveas, original data should be restored
    capture confirm variable marker
    local has_marker = (_rc == 0)

    * Return values should reflect expanded dataset
    local rn = r(n_persons)
    local ro = r(n_observations)

    if `has_marker' & `rn' == 3 & `ro' > 3 {
        display as result "  PASS: saveas restores data, returns n_persons=`rn' n_obs=`ro'"
        local ++pass_count
    }
    else {
        display as error "  FAIL: marker=" `has_marker' " n_persons=`rn' n_obs=`ro'"
        local ++fail_count
    }
}
else {
    display as error "  FAIL: saveas returned _rc=" _rc
    local ++fail_count
}

* TEST 14: Version is 1.0.0
local ++test_count

capture findfile tvage.ado
if _rc == 0 {
    tempname fh
    file open `fh' using "`r(fn)'", read text
    file read `fh' line
    file close `fh'

    if strpos("`line'", "1.0.0") > 0 {
        display as result "  PASS: Version is 1.0.0"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Version line: `line'"
        local ++fail_count
    }
}
else {
    display as error "  FAIL: tvage.ado not found"
    local ++fail_count
}

    as result "`pass_count' passed" as text ", " ///
    as result "`fail_count' failed" as text " of `test_count' tests"

}



**# ===== merged from test_tvtools.do L12997-13333: TVAGE expanded edge cases =====

* SECTION 6: TVAGE — expanded edge cases

* TEST 6.1: Groupwidth > 1 with stored results
local ++test_count
capture noisily {
    clear
    set obs 1
    gen long id = 1
    gen dob = mdy(6, 15, 1970)
    gen entry = mdy(1, 1, 2020)
    gen exit_date = mdy(12, 31, 2023)
    format dob entry exit_date %tdCCYY/NN/DD

    tvage, idvar(id) dobvar(dob) entryvar(entry) exitvar(exit_date) groupwidth(5)
    assert r(n_persons) == 1
    assert r(n_observations) > 0
    assert r(groupwidth) == 5
    assert "`r(varname)'" == "age_tv"
    assert "`r(startvar)'" == "age_start"
    assert "`r(stopvar)'" == "age_stop"
}
if _rc == 0 {
    display as result "  PASS: Groupwidth(5) with all stored results"
    local ++pass_count
}
else {
    display as error "  FAIL: Groupwidth(5) with all stored results (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 6.1"
}

* TEST 6.2: Custom generate/startgen/stopgen names
local ++test_count
capture noisily {
    clear
    set obs 1
    gen long id = 1
    gen dob = mdy(1, 1, 1960)
    gen entry = mdy(1, 1, 2020)
    gen exit_date = mdy(12, 31, 2022)
    format dob entry exit_date %td

    tvage, idvar(id) dobvar(dob) entryvar(entry) exitvar(exit_date) ///
        generate(myage) startgen(mystart) stopgen(mystop)
    assert "`r(varname)'" == "myage"
    assert "`r(startvar)'" == "mystart"
    assert "`r(stopvar)'" == "mystop"
    capture confirm variable myage
    assert _rc == 0
    capture confirm variable mystart
    assert _rc == 0
    capture confirm variable mystop
    assert _rc == 0
}
if _rc == 0 {
    display as result "  PASS: Custom generate/startgen/stopgen names"
    local ++pass_count
}
else {
    display as error "  FAIL: Custom generate/startgen/stopgen names (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 6.2"
}

* TEST 6.3: minage/maxage filtering
local ++test_count
capture noisily {
    clear
    set obs 1
    gen long id = 1
    gen dob = mdy(1, 1, 1960)
    gen entry = mdy(1, 1, 2020)
    gen exit_date = mdy(12, 31, 2025)
    format dob entry exit_date %td
    * Age range: 60-65
    tvage, idvar(id) dobvar(dob) entryvar(entry) exitvar(exit_date) ///
        minage(62) maxage(63)
    * Should only get ages 62 and 63
    assert r(n_observations) <= 2
    assert r(n_observations) >= 1
}
if _rc == 0 {
    display as result "  PASS: minage/maxage filtering works"
    local ++pass_count
}
else {
    display as error "  FAIL: minage/maxage filtering works (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 6.3"
}

* TEST 6.4: minage > maxage — error 198
local ++test_count
capture noisily {
    clear
    set obs 1
    gen long id = 1
    gen dob = mdy(1, 1, 1960)
    gen entry = mdy(1, 1, 2020)
    gen exit_date = mdy(12, 31, 2022)
    format dob entry exit_date %td
    capture tvage, idvar(id) dobvar(dob) entryvar(entry) exitvar(exit_date) ///
        minage(70) maxage(50)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: minage > maxage returns error 198"
    local ++pass_count
}
else {
    display as error "  FAIL: minage > maxage returns error 198 (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 6.4"
}

* TEST 6.5: Datetime format rejection — error 120
local ++test_count
capture noisily {
    clear
    set obs 1
    gen long id = 1
    gen double dob = clock("1960-01-01", "YMD")
    format dob %tc
    gen entry = mdy(1, 1, 2020)
    gen exit_date = mdy(12, 31, 2022)
    format entry exit_date %td
    capture tvage, idvar(id) dobvar(dob) entryvar(entry) exitvar(exit_date)
    assert _rc == 120
}
if _rc == 0 {
    display as result "  PASS: Datetime format variable returns error 120"
    local ++pass_count
}
else {
    display as error "  FAIL: Datetime format variable returns error 120 (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 6.5"
}

* TEST 6.6: Missing dates — error 416
local ++test_count
capture noisily {
    clear
    set obs 2
    gen long id = _n
    gen dob = mdy(1, 1, 1960)
    replace dob = . in 2
    gen entry = mdy(1, 1, 2020)
    gen exit_date = mdy(12, 31, 2022)
    format dob entry exit_date %td
    capture tvage, idvar(id) dobvar(dob) entryvar(entry) exitvar(exit_date)
    assert _rc == 416
}
if _rc == 0 {
    display as result "  PASS: Missing dates returns error 416"
    local ++pass_count
}
else {
    display as error "  FAIL: Missing dates returns error 416 (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 6.6"
}

* TEST 6.7: Duplicate IDs — error 459
local ++test_count
capture noisily {
    clear
    set obs 3
    gen long id = 1
    gen dob = mdy(1, 1, 1960)
    gen entry = mdy(1, 1, 2020)
    gen exit_date = mdy(12, 31, 2022)
    format dob entry exit_date %td
    capture tvage, idvar(id) dobvar(dob) entryvar(entry) exitvar(exit_date)
    assert _rc == 459
}
if _rc == 0 {
    display as result "  PASS: Duplicate IDs returns error 459"
    local ++pass_count
}
else {
    display as error "  FAIL: Duplicate IDs returns error 459 (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 6.7"
}

* TEST 6.8: saveas option
local ++test_count
capture noisily {
    clear
    set obs 1
    gen long id = 1
    gen dob = mdy(1, 1, 1970)
    gen entry = mdy(1, 1, 2020)
    gen exit_date = mdy(12, 31, 2022)
    format dob entry exit_date %td
    capture erase "test_tvage_output.dta"
    tvage, idvar(id) dobvar(dob) entryvar(entry) exitvar(exit_date) ///
        saveas("test_tvage_output") replace
    * When saveas is used, original data should be restored
    * The output was saved to the file
    capture confirm file "test_tvage_output.dta"
    assert _rc == 0
    erase "test_tvage_output.dta"
}
if _rc == 0 {
    display as result "  PASS: saveas option saves and restores original data"
    local ++pass_count
}
else {
    display as error "  FAIL: saveas option saves and restores original data (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 6.8"
}

* TEST 6.9: noisily option
local ++test_count
capture noisily {
    clear
    set obs 1
    gen long id = 1
    gen dob = mdy(1, 1, 1970)
    gen entry = mdy(1, 1, 2020)
    gen exit_date = mdy(12, 31, 2022)
    format dob entry exit_date %td
    tvage, idvar(id) dobvar(dob) entryvar(entry) exitvar(exit_date) noisily
    assert r(n_persons) == 1
}
if _rc == 0 {
    display as result "  PASS: noisily option works"
    local ++pass_count
}
else {
    display as error "  FAIL: noisily option works (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 6.9"
}

* TEST 6.10: Groupwidth boundaries (51 — error 198)
local ++test_count
capture noisily {
    clear
    set obs 1
    gen long id = 1
    gen dob = mdy(1, 1, 1970)
    gen entry = mdy(1, 1, 2020)
    gen exit_date = mdy(12, 31, 2022)
    format dob entry exit_date %td
    capture tvage, idvar(id) dobvar(dob) entryvar(entry) exitvar(exit_date) ///
        groupwidth(51)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: groupwidth(51) returns error 198"
    local ++pass_count
}
else {
    display as error "  FAIL: groupwidth(51) returns error 198 (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 6.10"
}

* TEST 6.11: Varabbrev restore after tvage
local ++test_count
capture noisily {
    clear
    set obs 1
    gen long id = 1
    gen dob = mdy(1, 1, 1970)
    gen entry = mdy(1, 1, 2020)
    gen exit_date = mdy(12, 31, 2022)
    format dob entry exit_date %td
    set varabbrev on
    tvage, idvar(id) dobvar(dob) entryvar(entry) exitvar(exit_date)
    assert "`c(varabbrev)'" == "on"
    set varabbrev off
}
if _rc == 0 {
    display as result "  PASS: Varabbrev restored after tvage"
    local ++pass_count
}
else {
    display as error "  FAIL: Varabbrev restored after tvage (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 6.11"
}

* TEST 6.12: Varabbrev restore after tvage error
local ++test_count
capture noisily {
    clear
    set obs 2
    gen long id = _n
    gen dob = mdy(1, 1, 1960)
    replace dob = . in 2
    gen entry = mdy(1, 1, 2020)
    gen exit_date = mdy(12, 31, 2022)
    format dob entry exit_date %td
    set varabbrev on
    capture tvage, idvar(id) dobvar(dob) entryvar(entry) exitvar(exit_date)
    assert "`c(varabbrev)'" == "on"
    set varabbrev off
}
if _rc == 0 {
    display as result "  PASS: Varabbrev restored after tvage error"
    local ++pass_count
}
else {
    display as error "  FAIL: Varabbrev restored after tvage error (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 6.12"
}

* TEST 6.13: Multiple persons
local ++test_count
capture noisily {
    clear
    set obs 3
    gen long id = _n
    gen dob = mdy(1, 1, 1960) + (_n - 1) * 3652
    gen entry = mdy(1, 1, 2020)
    gen exit_date = mdy(12, 31, 2022)
    format dob entry exit_date %td
    tvage, idvar(id) dobvar(dob) entryvar(entry) exitvar(exit_date)
    assert r(n_persons) == 3
    assert r(n_observations) >= 3
}
if _rc == 0 {
    display as result "  PASS: Multiple persons produces correct person count"
    local ++pass_count
}
else {
    display as error "  FAIL: Multiple persons produces correct person count (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 6.13"
}


* ===== Summary =====
* Fold the run_test/test_pass/test_fail harness counters into the totals.
local pass_count = `pass_count' + $TVQA_PASS
local fail_count = `fail_count' + $TVQA_FAIL
local failed_tests "`failed_tests' $TVQA_FAILED"
local test_count = `pass_count' + `fail_count'
display as result _newline "tvtools QA tvage functional Results -- $S_DATE $S_TIME"
display as text "Tests run:  `test_count'"
display as text "Passed:     `pass_count'"
display as text "Failed:     `fail_count'"
display "RESULT: test_tvage tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 {
    display as error "TESTS FAILED: `failed_tests'"
    exit 1
}
display as result "ALL TESTS PASSED"

