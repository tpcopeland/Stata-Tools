clear all
set processors 1
set varabbrev off
version 16.0

capture log close _all
log using "benchmark_asof_scaling.log", replace text nomsg
global ASOF_QA_STATUS "fail"

do "_asof_qa_common.do"
quietly _asof_qa_bootstrap

local test_count = 0
local pass_count = 0
local fail_count = 0
timer clear

local timer_id = 0
foreach n_events in 10000 100000 1000000 {
    local ++timer_id
    local ++test_count
    capture noisily {
        tempfile events
        clear
        set obs `n_events'
        generate long id = ceil(_n / 20)
        bysort id: generate double visit = id * 1000 + (_n - 1) * 10
        generate double value = visit
        save `events'

        clear
        set obs `=`n_events'/20'
        generate long id = _n
        generate double anchor = id * 1000 + 97
        timer on `timer_id'
        asof value using `events', id(id) date(visit) anchor(anchor) ///
            direction(both) select(nearest) window(-50 50) ///
            generate(got) nowarn
        timer off `timer_id'
        assert got == id * 1000 + 100
        assert r(N_using) == `n_events'
        assert r(N_matched) == `n_events' / 20
    }
    if _rc == 0 local ++pass_count
    else local ++fail_count
    timer list `timer_id'
    local time_`n_events' = r(t`timer_id')
    display "BENCH: events=`n_events' seconds=`time_`n_events''"
}

**# Subquadratic shape gate from 100k to 1M events
local ++test_count
capture noisily {
    local ratio = `time_1000000' / `time_100000'
    display "BENCH: ratio_1m_to_100k=`ratio'"
    assert `time_100000' > 0
    assert `ratio' < 15
}
if _rc == 0 local ++pass_count
else local ++fail_count

display "RESULT: benchmark_asof_scaling tests=`test_count' pass=`pass_count' fail=`fail_count' skip=0"
if `fail_count' > 0 {
    capture log close _all
    exit 1
}
global ASOF_QA_STATUS "pass"
log close _all
