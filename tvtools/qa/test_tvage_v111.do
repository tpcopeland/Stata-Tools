* test_tvage_v111.do
*
* Functional tests for tvage v1.1.1 fixes
* Tests: missing date validation, minage/maxage validation,
*        label name overflow, empty dataset guard, warning behavior
*
* Run: stata-mp -b do test_tvage_v111.do

clear all
set more off
version 16.0
set varabbrev off

capture net uninstall tvtools
quietly net install tvtools, from("`c(pwd)'/..") replace

local pass_count = 0
local fail_count = 0
local test_count = 0

* ============================================================================
* TEST 1: Missing DOB triggers error 416
* ============================================================================
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

* ============================================================================
* TEST 2: Missing entry date triggers error 416
* ============================================================================
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

* ============================================================================
* TEST 3: Missing exit date triggers error 416
* ============================================================================
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

* ============================================================================
* TEST 4: All dates non-missing passes validation
* ============================================================================
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

* ============================================================================
* TEST 5: minage > maxage triggers error 198
* ============================================================================
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

* ============================================================================
* TEST 6: minage == maxage is valid (single age)
* ============================================================================
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

* ============================================================================
* TEST 7: Empty dataset after age filtering triggers error 2000
* ============================================================================
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

* ============================================================================
* TEST 8: Data preserved after error 2000 (restore works)
* ============================================================================
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

* ============================================================================
* TEST 9: Long variable name with groupwidth > 1 (label overflow fix)
* ============================================================================
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

* ============================================================================
* TEST 10: Default variable name with groupwidth works (no truncation needed)
* ============================================================================
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

* ============================================================================
* TEST 11: Warning suppressed without noisily option
* ============================================================================
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

* ============================================================================
* TEST 12: Warning shown with noisily option
* ============================================================================
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

* ============================================================================
* TEST 13: Return values correct after saveas + restore
* ============================================================================
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

* ============================================================================
* TEST 14: Version is 1.1.1
* ============================================================================
local ++test_count

capture findfile tvage.ado
if _rc == 0 {
    tempname fh
    file open `fh' using "`r(fn)'", read text
    file read `fh' line
    file close `fh'

    if strpos("`line'", "1.1.1") > 0 {
        display as result "  PASS: Version is 1.1.1"
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

* ============================================================================
* SUMMARY
* ============================================================================

display as text ""
display as text _dup(70) "="
display as text "tvage v1.1.1 RESULTS: " ///
    as result "`pass_count' passed" as text ", " ///
    as result "`fail_count' failed" as text " of `test_count' tests"
display as text _dup(70) "="

if `fail_count' > 0 {
    exit 9
}
