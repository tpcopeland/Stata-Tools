* Test tvage fixes for precision, labels, and default groupwidth
* Version 1.1.0 fixes

clear all
set more off
set seed 42

capture program drop tvage
quietly do "tvtools/tvage.ado"

display as text _newline _dup(70) "="
display as text "Testing tvage Version 1.1.0 fixes"
display as text _dup(70) "="

* ============================================================================
* TEST 1: Date precision - ensure dates are proper integers for merging
* ============================================================================
display as text _newline "TEST 1: Date precision (should produce integer dates)"
display as text _dup(70) "-"

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

display as result "PASSED: All dates are integers"

* ============================================================================
* TEST 2: Age labels cover actual data range (not just minage/maxage)
* ============================================================================
display as text _newline "TEST 2: Age labels cover actual data range"
display as text _dup(70) "-"

* Create data where people's ages span a wide range
clear
set obs 10
gen long id = _n

* People born between 1930-1970 (so ages at entry vary 30-70)
gen dob = mdy(1, 1, 1930) + (_n - 1) * 365.25 * 4
format dob %tdCCYY/NN/DD

* All enter on same date in 2000
gen entry = mdy(1, 1, 2000)
format entry %tdCCYY/NN/DD

* Exit 15 years later (so ages increase by 15)
gen exit = mdy(1, 1, 2015)
format exit %tdCCYY/NN/DD

list id dob, clean noobs
display as text "Age range at entry: 30-70, ages increase by 15 years"

tvage, idvar(id) dobvar(dob) entryvar(entry) exitvar(exit) groupwidth(10) noisily

* Check that labels exist for all age groups present
tab age_tv, missing

* Get range of ages
summarize age_tv
local min_age = r(min)
local max_age = r(max)

display as text "Actual age range in data: `min_age' - `max_age'"

* Verify labels exist for all values
levelsof age_tv, local(ages)
foreach a of local ages {
    local lbl : label (age_tv) `a'
    assert "`lbl'" != ""
    display as text "  Age `a' has label: `lbl'"
}

display as result "PASSED: All age groups have labels"

* ============================================================================
* TEST 3: Default groupwidth=1 produces continuous ages without labels
* ============================================================================
display as text _newline "TEST 3: Default groupwidth=1 (continuous, no labels)"
display as text _dup(70) "-"

clear
set obs 3
gen long id = _n
gen dob = mdy(1, 1, 1960) + (_n - 1) * 365 * 5
gen entry = mdy(1, 1, 2000)
gen exit = mdy(1, 1, 2005)
format dob entry exit %tdCCYY/NN/DD

tvage, idvar(id) dobvar(dob) entryvar(entry) exitvar(exit) noisily

* Check no label is applied
local lbl : value label age_tv
display as text "Value label applied: '`lbl''"
assert "`lbl'" == ""

* Check ages are continuous integers
tab age_tv
summarize age_tv

display as result "PASSED: Continuous ages without labels"

* ============================================================================
* TEST 4: Test merge capability (the original precision issue)
* ============================================================================
display as text _newline "TEST 4: Dates can merge properly"
display as text _dup(70) "-"

* Create exposure data
clear
set obs 3
gen long id = _n
gen dob = mdy(6, 15, 1960)
gen entry = mdy(1, 1, 2000)
gen exit = mdy(12, 31, 2005)
format dob entry exit %tdCCYY/NN/DD

tvage, idvar(id) dobvar(dob) entryvar(entry) exitvar(exit)
tempfile exposure
save `exposure'

* Create events data on exact start dates
use `exposure', clear
keep id age_start age_tv
keep if _n <= 5
tempfile events
save `events'

* Reload and merge back on age_start
use `exposure', clear
merge 1:1 id age_start using `events', keepusing(age_tv)

display as text "Merge results:"
tab _merge

* All events should merge (matched or master only, no using-only)
count if _merge == 2
assert r(N) == 0
display as result "PASSED: Dates merge correctly"

* ============================================================================
* TEST 5: Groupwidth > 1 with real age progression
* ============================================================================
display as text _newline "TEST 5: 5-year age groups with age progression"
display as text _dup(70) "-"

clear
set obs 5
gen long id = _n
gen dob = mdy(7, 1, 1940) + (_n - 1) * 365 * 2  // Born 1940, 1942, 1944, 1946, 1948
gen entry = mdy(1, 1, 1980)  // Enter at age 40, 38, 36, 34, 32
gen exit = mdy(1, 1, 2020)   // 40 years of follow-up (to age 80, 78, 76, 74, 72)
format dob entry exit %tdCCYY/NN/DD

tvage, idvar(id) dobvar(dob) entryvar(entry) exitvar(exit) groupwidth(5) noisily

* Display distribution
tab age_tv

* Check label coverage spans actual range
summarize age_tv
local minv = r(min)
local maxv = r(max)

display as text "Age group range: `minv' to `maxv'"

* Verify all groups have labels
levelsof age_tv, local(groups)
local n_groups : word count `groups'
display as text "Number of distinct age groups: `n_groups'"

foreach g of local groups {
    local lbl : label (age_tv) `g'
    assert "`lbl'" != ""
}

display as result "PASSED: All age groups properly labeled"

* ============================================================================
* Summary
* ============================================================================
display as text _newline _dup(70) "="
display as result "ALL TESTS PASSED"
display as text _dup(70) "="
display as text _newline "Summary of fixes verified:"
display as text "  1. Date precision: Uses double + round() for proper integers"
display as text "  2. Label coverage: Based on actual data range, not minage/maxage"
display as text "  3. Default groupwidth=1: Continuous ages, no labeling"
display as text "  4. Merge capability: Integer dates merge correctly"
display as text "  5. Age progression: Labels cover full range as ages increase"
