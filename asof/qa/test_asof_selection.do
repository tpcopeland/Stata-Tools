clear all
set processors 1
set varabbrev off
version 16.0

capture log close _all
log using "test_asof_selection.log", replace text nomsg
global ASOF_QA_STATUS "fail"

do "_asof_qa_common.do"
quietly _asof_qa_bootstrap

local test_count = 0
local pass_count = 0
local fail_count = 0

**# Direction by selection rule: exact row answers for all 15 crossings
tempfile events
clear
set obs 15
generate long id = ceil(_n / 5)
bysort id: generate double visit = 100 * id + cond(_n == 1, -30, ///
    cond(_n == 2, -10, cond(_n == 3, 0, cond(_n == 4, 10, 40))))
generate double value = visit
format %td visit
save `events'

local exp_before_nearest = -10
local exp_before_first = -30
local exp_before_last = -10
local exp_onorbefore_nearest = 0
local exp_onorbefore_first = -30
local exp_onorbefore_last = 0
local exp_after_nearest = 10
local exp_after_first = 10
local exp_after_last = 40
local exp_onorafter_nearest = 0
local exp_onorafter_first = 0
local exp_onorafter_last = 40
local exp_both_nearest = 0
local exp_both_first = -30
local exp_both_last = 40

foreach direction in before onorbefore after onorafter both {
    foreach selection in nearest first last {
        local ++test_count
        capture noisily {
            clear
            set obs 3
            generate long id = _n
            generate double anchor = 100 * id
            generate double expected = anchor + `exp_`direction'_`selection''
            format %td anchor expected
            asof value using `events', id(id) date(visit) anchor(anchor) ///
                direction(`direction') select(`selection') generate(got) ///
                matchname(found) nowarn
            assert got == expected
            assert found == 1
            assert r(N_matched) == 3
            assert r(N_unmatched) == 0
            assert "`r(direction)'" == "`direction'"
            assert "`r(select)'" == "`selection'"
        }
        if _rc == 0 local ++pass_count
        else local ++fail_count
    }
}

**# Repeated identifiers with different anchors receive different matches
local ++test_count
capture noisily {
    tempfile grid_events
    clear
    input long id double visit value
    1 5 50
    1 15 150
    1 25 250
    1 35 350
    1 45 450
    end
    save `grid_events'
    clear
    input long id double anchor expected
    1 4 50
    1 14 150
    1 24 250
    1 34 350
    1 44 450
    end
    asof value using `grid_events', id(id) date(visit) anchor(anchor) ///
        direction(onorafter) select(nearest) generate(got)
    assert got == expected
    assert r(N_master) == 5
    assert r(N_keys) == 5
}
if _rc == 0 local ++pass_count
else local ++fail_count

**# Duplicate master keys share one deterministic key-level choice
local ++test_count
capture noisily {
    tempfile dup_events
    clear
    input long id double visit value
    1 90 9
    1 110 11
    end
    save `dup_events'
    clear
    input long id double anchor
    1 100
    1 100
    1 100
    end
    asof value using `dup_events', id(id) date(visit) anchor(anchor) ///
        direction(both) select(nearest) generate(got)
    assert got == 9
    assert r(N_master) == 3
    assert r(N_keys) == 1
    assert r(N_matched) == 3
    assert r(N_ties) == 1
}
if _rc == 0 local ++pass_count
else local ++fail_count

display "RESULT: test_asof_selection tests=`test_count' pass=`pass_count' fail=`fail_count' skip=0"
if `fail_count' > 0 {
    capture log close _all
    exit 1
}
global ASOF_QA_STATUS "pass"
log close _all
