*! test_asof_windows.do - Protocol, observability, and missingness contracts
*! Author: Timothy P Copeland, Karolinska Institutet
*! Requires: Stata 16.0+

clear all
set processors 1
set varabbrev off
version 16.0

capture log close _all
log using "test_asof_windows.log", replace text nomsg
global ASOF_QA_STATUS "fail"

do "_asof_qa_common.do"
quietly _asof_qa_bootstrap

local test_count = 0
local pass_count = 0
local fail_count = 0

**# window() and range() are intersected per key
local ++test_count
capture noisily {
    tempfile events
    clear
    input long id double visit value
    1 85 85
    1 95 95
    1 125 125
    2 205 205
    2 210 210
    2 215 215
    end
    save `events'
    clear
    input long id double anchor lower upper expected
    1 100 80 120 95
    2 200 210 300 210
    end
    asof value using `events', id(id) date(visit) anchor(anchor) ///
        direction(both) select(first) window(-10 10) ///
        range(lower upper) generate(got)
    assert got == expected
    assert r(N_eligible) == 2
}
if _rc == 0 local ++pass_count
else local ++fail_count

**# Missing observability bounds are open independently
local ++test_count
capture noisily {
    tempfile events
    clear
    input long id double visit value
    1 90 90
    1 120 120
    2 180 180
    2 195 195
    3 280 280
    3 320 320
    end
    save `events'
    clear
    input long id double anchor lower upper expected
    1 100 . 110 90
    2 200 190 . 195
    3 300 . . 280
    end
    asof value using `events', id(id) date(visit) anchor(anchor) ///
        direction(both) select(first) range(lower upper) generate(got)
    assert got == expected
}
if _rc == 0 local ++pass_count
else local ++fail_count

**# require() defaults to carried variables and can be narrowed to the date
local ++test_count
capture noisily {
    tempfile events
    clear
    input long id double visit score
    1 95 .
    1 100 10
    end
    save `events'
    clear
    input long id double anchor
    1 96
    end
    asof score using `events', id(id) date(visit) anchor(anchor) ///
        direction(both) select(nearest) generate(default_pick)
    assert default_pick == 10
    asof score using `events', id(id) date(visit) anchor(anchor) ///
        direction(both) select(nearest) require(visit) ///
        generate(date_only_pick) datename(date_only_date)
    assert missing(date_only_pick)
    assert date_only_date == 95
    assert r(N_eligible) == 2
}
if _rc == 0 local ++pass_count
else local ++fail_count

**# Inclusive bounds admit records exactly on every boundary
local ++test_count
capture noisily {
    tempfile events
    clear
    input long id double visit value
    1 90 90
    1 110 110
    end
    save `events'
    clear
    input long id double anchor lower upper
    1 100 90 110
    end
    asof value using `events', id(id) date(visit) anchor(anchor) ///
        direction(both) select(first) window(-10 10) ///
        range(lower upper) generate(first_bound)
    asof value using `events', id(id) date(visit) anchor(anchor) ///
        direction(both) select(last) window(-10 10) ///
        range(lower upper) generate(last_bound)
    assert first_bound == 90
    assert last_bound == 110
}
if _rc == 0 local ++pass_count
else local ++fail_count

**# Invalid window and range definitions fail rather than guess
local ++test_count
capture noisily {
    tempfile events
    clear
    input long id double visit value
    1 100 1
    end
    save `events'
    clear
    input long id double anchor lower upper
    1 100 110 90
    end
    capture noisily asof value using `events', id(id) date(visit) ///
        anchor(anchor) direction(both) select(nearest) window(10 -10)
    assert _rc == 198
    capture noisily asof value using `events', id(id) date(visit) ///
        anchor(anchor) direction(both) select(nearest) range(lower upper)
    assert _rc == 459
}
if _rc == 0 local ++pass_count
else local ++fail_count

**# Identical id-anchor keys may not carry conflicting range bounds
local ++test_count
capture noisily {
    tempfile events
    clear
    input long id double visit value
    1 100 1
    end
    save `events'
    clear
    input long id double anchor lower upper
    1 100 80 120
    1 100 90 120
    end
    capture noisily asof value using `events', id(id) date(visit) ///
        anchor(anchor) direction(both) select(nearest) range(lower upper)
    assert _rc == 459
}
if _rc == 0 local ++pass_count
else local ++fail_count

display "RESULT: test_asof_windows tests=`test_count' pass=`pass_count' fail=`fail_count' skip=0"
if `fail_count' > 0 {
    capture log close _all
    exit 1
}
global ASOF_QA_STATUS "pass"
log close _all
