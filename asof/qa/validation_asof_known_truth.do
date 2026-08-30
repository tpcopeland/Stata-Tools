*! validation_asof_known_truth.do - Hand-computed and brute-force oracles
*! Author: Timothy P Copeland, Karolinska Institutet
*! Requires: Stata 16.0+

clear all
set processors 1
set varabbrev off
version 16.0

capture log close _all
log using "validation_asof_known_truth.log", replace text nomsg
global ASOF_QA_STATUS "fail"

do "_asof_qa_common.do"
quietly _asof_qa_bootstrap

local test_count = 0
local pass_count = 0
local fail_count = 0

**# V1: Hand-computed nearest choices and gap distribution
local ++test_count
capture noisily {
    tempfile events
    clear
    input long id double visit value
    1 80 8
    1 105 10.5
    2 190 19
    2 230 23
    3 300 30
    end
    save `events'
    clear
    input long id double anchor expected expected_gap
    1 100 10.5 5
    2 200 19 -10
    3 300 30 0
    end
    asof value using `events', id(id) date(visit) anchor(anchor) ///
        direction(both) select(nearest) generate(got) gapname(gap)
    assert got == expected
    assert gap == expected_gap
    assert r(gap_min) == -10
    assert r(gap_max) == 5
    assert abs(r(gap_mean) + 5/3) < 1e-12
    assert r(gap_p50) == 0
}
if _rc == 0 local ++pass_count
else local ++fail_count

**# V2: Strict versus inclusive direction at the anchor
local ++test_count
capture noisily {
    tempfile events
    clear
    input long id double visit value
    1 90 9
    1 100 10
    end
    save `events'
    clear
    input long id double anchor
    1 100
    end
    asof value using `events', id(id) date(visit) anchor(anchor) ///
        direction(before) select(nearest) generate(strict_pick)
    asof value using `events', id(id) date(visit) anchor(anchor) ///
        direction(onorbefore) select(nearest) generate(inclusive_pick)
    assert strict_pick == 9
    assert inclusive_pick == 10
}
if _rc == 0 local ++pass_count
else local ++fail_count

**# V3: Fast Mata path agrees exactly with a brute-force joinby oracle
local ++test_count
capture noisily {
    tempfile events master fast reference
    clear
    set obs 200
    generate long id = _n
    expand 9
    bysort id: generate double visit = id * 1000 + (_n - 5) * 10
    generate long event_row = _n
    save `events'

    clear
    set obs 200
    generate long id = _n
    generate double anchor = id * 1000 + 5
    generate long master_row = _n
    save `master'

    asof event_row visit using `events', id(id) date(visit) anchor(anchor) ///
        direction(both) select(nearest) ties(before) window(-25 25) ///
        generate(fast_row fast_date)
    keep id master_row fast_row fast_date
    save `fast'

    use `master', clear
    joinby id using `events'
    generate double signed_gap = visit - anchor
    keep if inrange(signed_gap, -25, 25)
    generate double abs_gap = abs(signed_gap)
    gsort master_row abs_gap signed_gap event_row
    by master_row: keep if _n == 1
    rename event_row reference_row
    rename visit reference_date
    keep id master_row reference_row reference_date
    save `reference'

    use `fast', clear
    merge 1:1 master_row using `reference', assert(3) nogen
    assert fast_row == reference_row
    assert fast_date == reference_date
}
if _rc == 0 local ++pass_count
else local ++fail_count

**# V4: Eligible-record count is a union over keys, not pair multiplicity
local ++test_count
capture noisily {
    tempfile events
    clear
    input long id double visit value
    1 90 9
    1 100 10
    1 110 11
    end
    save `events'
    clear
    input long id double anchor
    1 95
    1 105
    end
    asof value using `events', id(id) date(visit) anchor(anchor) ///
        direction(both) select(nearest) window(-20 20) generate(got)
    assert got[1] == 9
    assert got[2] == 10
    assert r(N_eligible) == 3
    assert r(N_keys) == 2
}
if _rc == 0 local ++pass_count
else local ++fail_count

display "RESULT: validation_asof_known_truth tests=`test_count' pass=`pass_count' fail=`fail_count' skip=0"
if `fail_count' > 0 {
    capture log close _all
    exit 1
}
global ASOF_QA_STATUS "pass"
log close _all
