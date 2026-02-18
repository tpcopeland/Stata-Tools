/*******************************************************************************
* test_tvage.do
*
* Purpose: Functional tests for tvage command
*          Tests age interval creation, groupwidth, boundary precision
*
* Run: stata-mp -b do test_tvage.do
*******************************************************************************/

clear all
set more off
version 16.0
set varabbrev off

capture program drop tvage
quietly do "tvtools/tvage.ado"

local pass_count = 0
local fail_count = 0

display as text _newline _dup(70) "="
display as text "tvage Functional Tests"
display as text _dup(70) "="

* ============================================================================
* TEST 1: Known DOB/entry/exit - exact age intervals
* ============================================================================
display as text _newline "TEST 1: Exact age intervals for known person"
display as text _dup(70) "-"

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

* ============================================================================
* TEST 2: Groupwidth 5
* ============================================================================
display as text _newline "TEST 2: Groupwidth 5 (age groups 45-49, 50-54)"
display as text _dup(70) "-"

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

* ============================================================================
* TEST 3: Multiple persons
* ============================================================================
display as text _newline "TEST 3: Multiple persons"
display as text _dup(70) "-"

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

* ============================================================================
* TEST 4: Date precision (no fractional dates)
* ============================================================================
display as text _newline "TEST 4: Date precision - integer dates"
display as text _dup(70) "-"

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

* ============================================================================
* TEST 5: No overlaps within person
* ============================================================================
display as text _newline "TEST 5: No overlapping intervals"
display as text _dup(70) "-"

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

* ============================================================================
* TEST 6: No gaps within person
* ============================================================================
display as text _newline "TEST 6: No gaps between intervals"
display as text _dup(70) "-"

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

* ============================================================================
* SUMMARY
* ============================================================================

display as text _newline _dup(70) "="
display as text "SUMMARY: " as result `pass_count' " passed, " `fail_count' " failed"
display as text _dup(70) "="

if `fail_count' > 0 {
    exit 9
}
