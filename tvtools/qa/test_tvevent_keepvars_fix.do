* test_tvevent_keepvars_fix.do
* Verifies that keepvars are retained for ALL people, not just those with events
* Bug: tvevent was dropping covariates for people without events

clear all
set more off
version 16.0

capture ado uninstall tvtools
net install tvtools, from("/home/tpcopeland/Stata-Tools/tvtools") replace

local n_passed = 0
local n_failed = 0

* =============================================================================
* TEST 1: keepvars retained for people WITHOUT events (single type)
* =============================================================================
di as txt "Test 1: keepvars retained for non-event people (single)"

* Create event data: only person 1 has an event, person 2 does not
clear
input long id double eventdate byte female double age
1 21550 1 45.2
2 .     0 62.1
end
format eventdate %td

tempfile events
save `events'

* Create interval data: both people have intervals
clear
input long id double start double stop
1 21500 21550
1 21550 21600
2 21500 21550
2 21550 21600
end
format start %td
format stop %td

tempfile intervals
save `intervals'

* Run tvevent
use `events', clear
tvevent using `intervals', id(id) date(eventdate) keepvars(female age) replace

* Check: person 2 should have female==0 and age==62.1
count if id == 2 & missing(female)
if r(N) > 0 {
    di as error "FAIL: female is missing for person 2 (no event)"
    local n_failed = `n_failed' + 1
}
else {
    count if id == 2 & female == 0 & abs(age - 62.1) < 0.01
    if r(N) == 0 {
        di as error "FAIL: female/age have wrong values for person 2"
        local n_failed = `n_failed' + 1
    }
    else {
        di as txt "  PASS"
        local n_passed = `n_passed' + 1
    }
}

* Check: person 1 should also have female==1 and age==45.2
count if id == 1 & missing(female)
if r(N) > 0 {
    di as error "FAIL: female is missing for person 1 (has event)"
    local n_failed = `n_failed' + 1
}
else {
    count if id == 1 & female == 1 & abs(age - 45.2) < 0.01
    if r(N) == 0 {
        di as error "FAIL: female/age have wrong values for person 1"
        local n_failed = `n_failed' + 1
    }
    else {
        di as txt "  PASS"
        local n_passed = `n_passed' + 1
    }
}

* =============================================================================
* TEST 2: Auto-detected keepvars retained for non-event people
* =============================================================================
di as txt "Test 2: auto-detected keepvars retained for non-event people"

use `events', clear
* Don't specify keepvars - let tvevent auto-detect (should pick up female, age)
tvevent using `intervals', id(id) date(eventdate) replace

count if id == 2 & missing(female)
if r(N) > 0 {
    di as error "FAIL: auto-detected female is missing for person 2"
    local n_failed = `n_failed' + 1
}
else {
    di as txt "  PASS"
    local n_passed = `n_passed' + 1
}

* =============================================================================
* TEST 3: keepvars with competing risks, non-event person
* =============================================================================
di as txt "Test 3: keepvars with competing risks, non-event person"

clear
input long id double eventdate double deathdate byte female
1 21550 .     1
2 .     21580 0
3 .     .     1
end
format eventdate %td
format deathdate %td

tempfile events_cr
save `events_cr'

* Intervals for 3 people
clear
input long id double start double stop
1 21500 21550
1 21550 21600
2 21500 21550
2 21550 21600
3 21500 21550
3 21550 21600
end
format start %td
format stop %td

tempfile intervals_cr
save `intervals_cr'

use `events_cr', clear
tvevent using `intervals_cr', id(id) date(eventdate) compete(deathdate) ///
    keepvars(female) replace

* Person 3 has no event and no competing event - should still have female==1
count if id == 3 & missing(female)
if r(N) > 0 {
    di as error "FAIL: female is missing for person 3 (no events at all)"
    local n_failed = `n_failed' + 1
}
else {
    count if id == 3 & female == 1
    if r(N) == 0 {
        di as error "FAIL: female has wrong value for person 3"
        local n_failed = `n_failed' + 1
    }
    else {
        di as txt "  PASS"
        local n_passed = `n_passed' + 1
    }
}

* =============================================================================
* TEST 4: All intervals present for non-event people
* =============================================================================
di as txt "Test 4: all intervals preserved for non-event people"

use `events', clear
tvevent using `intervals', id(id) date(eventdate) keepvars(female age) replace

* Person 2 should still have 2 intervals
count if id == 2
if r(N) != 2 {
    di as error "FAIL: person 2 should have 2 intervals, has `r(N)'"
    local n_failed = `n_failed' + 1
}
else {
    di as txt "  PASS"
    local n_passed = `n_passed' + 1
}

* =============================================================================
* SUMMARY
* =============================================================================
di _newline
di as txt "Results: `n_passed' passed, `n_failed' failed"
if `n_failed' > 0 {
    di as error "SOME TESTS FAILED"
    exit 9
}
else {
    di as txt "ALL TESTS PASSED"
}
