*! test_asof_ties.do - Tie-resolution contracts for asof
*! Author: Timothy P Copeland, Karolinska Institutet
*! Requires: Stata 16.0+

clear all
set processors 1
set varabbrev off
version 16.0

capture log close _all
log using "test_asof_ties.log", replace text nomsg
global ASOF_QA_STATUS "fail"

do "_asof_qa_common.do"
quietly _asof_qa_bootstrap

local test_count = 0
local pass_count = 0
local fail_count = 0

**# Equidistant nearest ties choose the declared side and ignore row order
foreach reverse in 0 1 {
    local ++test_count
    capture noisily {
        tempfile events
        clear
        set obs 2
        generate long id = 1
        generate double visit = cond(_n == 1, 70, 130)
        generate double value = cond(_n == 1, 7, 13)
        if `reverse' gsort -visit
        save `events'
        clear
        set obs 1
        generate long id = 1
        generate double anchor = 100
        asof value using `events', id(id) date(visit) anchor(anchor) ///
            direction(both) select(nearest) ties(before) generate(got)
        assert got == 7
        assert r(N_ties) == 1
        drop got
        asof value using `events', id(id) date(visit) anchor(anchor) ///
            direction(both) select(nearest) ties(after) generate(got)
        assert got == 13
        assert r(N_ties) == 1
    }
    if _rc == 0 local ++pass_count
    else local ++fail_count
}

**# nearest ties(first/last) follow original using-file order
local ++test_count
capture noisily {
    tempfile events
    clear
    input long id double visit value
    1 130 13
    1 70 7
    end
    save `events'
    clear
    input long id double anchor
    1 100
    end
    asof value using `events', id(id) date(visit) anchor(anchor) ///
        direction(both) select(nearest) ties(first) generate(first_pick)
    asof value using `events', id(id) date(visit) anchor(anchor) ///
        direction(both) select(nearest) ties(last) generate(last_pick)
    assert first_pick == 13
    assert last_pick == 7
}
if _rc == 0 local ++pass_count
else local ++fail_count

**# ties(error) returns 459 without leaving partial output
local ++test_count
capture noisily {
    tempfile events
    clear
    input long id double visit value
    1 70 7
    1 130 13
    end
    save `events'
    clear
    input long id double anchor sentinel
    1 100 42
    end
    capture noisily asof value using `events', id(id) date(visit) ///
        anchor(anchor) direction(both) select(nearest) ties(error) ///
        generate(got)
    assert _rc == 459
    capture confirm variable got
    assert _rc == 111
    assert sentinel == 42
    assert _N == 1
}
if _rc == 0 local ++pass_count
else local ++fail_count

**# first/last duplicate dates follow original order in either input ordering
foreach reverse in 0 1 {
    local ++test_count
    capture noisily {
        tempfile events
        clear
        set obs 4
        generate long id = 1
        generate double visit = cond(_n <= 2, 50, 60)
        generate double value = cond(_n == 1, 501, ///
            cond(_n == 2, 502, cond(_n == 3, 600, 601)))
        if `reverse' gsort -visit -value
        save `events'
        clear
        set obs 1
        generate long id = 1
        generate double anchor = 100
        asof value using `events', id(id) date(visit) anchor(anchor) ///
            direction(before) select(first) ties(first) generate(first_first)
        assert r(N_ties) == 1
        asof value using `events', id(id) date(visit) anchor(anchor) ///
            direction(before) select(first) ties(last) generate(first_last)
        assert r(N_ties) == 1
        asof value using `events', id(id) date(visit) anchor(anchor) ///
            direction(before) select(last) ties(first) generate(last_first)
        assert r(N_ties) == 1
        asof value using `events', id(id) date(visit) anchor(anchor) ///
            direction(before) select(last) ties(last) generate(last_last)
        assert r(N_ties) == 1

        if !`reverse' {
            assert first_first == 501 & first_last == 502
            assert last_first == 600 & last_last == 601
        }
        else {
            assert first_first == 502 & first_last == 501
            assert last_first == 601 & last_last == 600
        }
    }
    if _rc == 0 local ++pass_count
    else local ++fail_count
}

**# duplicate-date ties(error) is enforced for first and last
local ++test_count
capture noisily {
    tempfile events
    clear
    input long id double visit value
    1 50 501
    1 50 502
    1 60 600
    1 60 601
    end
    save `events'
    clear
    input long id double anchor
    1 100
    end
    capture noisily asof value using `events', id(id) date(visit) ///
        anchor(anchor) direction(before) select(first) ties(error)
    assert _rc == 459
    capture noisily asof value using `events', id(id) date(visit) ///
        anchor(anchor) direction(before) select(last) ties(error)
    assert _rc == 459
}
if _rc == 0 local ++pass_count
else local ++fail_count

display "RESULT: test_asof_ties tests=`test_count' pass=`pass_count' fail=`fail_count' skip=0"
if `fail_count' > 0 {
    capture log close _all
    exit 1
}
global ASOF_QA_STATUS "pass"
log close _all
