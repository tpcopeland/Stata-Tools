clear all
set processors 1
set varabbrev on
version 16.0

capture log close _all
log using "test_asof_syntax.log", replace text nomsg
global ASOF_QA_STATUS "fail"

do "_asof_qa_common.do"
quietly _asof_qa_bootstrap

local test_count = 0
local pass_count = 0
local fail_count = 0

**# Baseline syntax, output names, and stored results
local ++test_count
capture noisily {
    tempfile events
    clear
    input long id double visit score
    1 90 9
    1 110 11
    2 195 19
    2 205 21
    end
    format %td visit
    save `events'

    clear
    input long id double anchor
    1 100
    2 200
    end
    format %td anchor
    asof score using `events', id(id) date(visit) anchor(anchor) ///
        direction(both) select(nearest) generate(chosen) ///
        datename(chosen_date) gapname(gap) matchname(found) noisily
    assert chosen[1] == 9 & chosen[2] == 19
    assert gap[1] == -10 & gap[2] == -5
    assert found[1] == 1 & found[2] == 1
    assert r(N_master) == 2
    assert r(N_keys) == 2
    assert r(N_matched) == 2
    assert r(N_unmatched) == 0
    assert r(N_using) == 4
    assert r(N_eligible) == 4
    assert r(N_ties) == 2
    assert "`r(varlist)'" == "score"
    assert "`r(generate)'" == "chosen"
    assert "`r(direction)'" == "both"
    assert "`r(select)'" == "nearest"
    assert "`r(ties)'" == "before"
}
if _rc == 0 local ++pass_count
else local ++fail_count

**# Direction and select are mandatory
local ++test_count
capture noisily {
    tempfile events
    clear
    input id visit score
    1 1 1
    end
    save `events'
    clear
    input id anchor
    1 1
    end
    capture noisily asof score using `events', id(id) date(visit) ///
        anchor(anchor) select(nearest)
    assert _rc == 198
    capture noisily asof score using `events', id(id) date(visit) ///
        anchor(anchor) direction(both)
    assert _rc == 198
}
if _rc == 0 local ++pass_count
else local ++fail_count

**# Invalid rule values and combinations fail explicitly
local ++test_count
capture noisily {
    tempfile events
    clear
    input id visit score
    1 1 1
    end
    save `events'
    clear
    input id anchor
    1 1
    end
    capture noisily asof score using `events', id(id) date(visit) ///
        anchor(anchor) direction(sideways) select(nearest)
    assert _rc == 198
    capture noisily asof score using `events', id(id) date(visit) ///
        anchor(anchor) direction(both) select(average)
    assert _rc == 198
    capture noisily asof score using `events', id(id) date(visit) ///
        anchor(anchor) direction(both) select(first) ties(before)
    assert _rc == 198
}
if _rc == 0 local ++pass_count
else local ++fail_count

**# Prefix, suffix, and explicit generate naming
local ++test_count
capture noisily {
    tempfile events
    clear
    input id visit score str4 grade
    1 5 7 "high"
    end
    save `events'
    clear
    input id anchor
    1 5
    end
    asof score grade using `events', id(id) date(visit) anchor(anchor) ///
        direction(both) select(nearest) prefix(at_)
    assert at_score == 7 & at_grade == "high"
    drop at_score at_grade
    asof score grade using `events', id(id) date(visit) anchor(anchor) ///
        direction(both) select(nearest) suffix(_x)
    assert score_x == 7 & grade_x == "high"
    drop score_x grade_x
    asof score grade using `events', id(id) date(visit) anchor(anchor) ///
        direction(both) select(nearest) generate(s g)
    assert s == 7 & g == "high"
}
if _rc == 0 local ++pass_count
else local ++fail_count

**# Carried and required varlists expand wildcards and ranges in using data
local ++test_count
capture noisily {
    tempfile events
    clear
    input long id double visit score_a score_b req_a req_b
    1 90 9 90 1 1
    1 99 99 990 1 .
    end
    save `events'
    clear
    input long id double anchor
    1 100
    end
    asof score_* using `events', id(id) date(visit) anchor(anchor) ///
        direction(both) select(nearest) generate(wild_a wild_b)
    assert wild_a == 99 & wild_b == 990
    asof score_a-score_b using `events', id(id) date(visit) ///
        anchor(anchor) direction(both) select(nearest) ///
        generate(range_a range_b)
    assert range_a == 99 & range_b == 990
    asof score_a using `events', id(id) date(visit) anchor(anchor) ///
        direction(both) select(nearest) require(req_*) generate(required)
    assert required == 9
    assert "`r(varlist)'" == "score_a"
}
if _rc == 0 local ++pass_count
else local ++fail_count

**# Output-name guards reject collisions, bad counts, and overlength names
local ++test_count
capture noisily {
    tempfile events
    clear
    input id visit score grade abcdefghijklmnopqrstuvwxyz
    1 5 7 8 9
    end
    save `events'
    clear
    input id anchor existing
    1 5 0
    end
    capture noisily asof score grade using `events', id(id) date(visit) ///
        anchor(anchor) direction(both) select(nearest) generate(one)
    assert _rc == 198
    capture noisily asof score using `events', id(id) date(visit) ///
        anchor(anchor) direction(both) select(nearest) ///
        generate(existing)
    assert _rc == 110
    capture noisily asof score using `events', id(id) date(visit) ///
        anchor(anchor) direction(both) select(nearest) ///
        generate(id) replace
    assert _rc == 198
    capture noisily asof score using `events', id(id) date(visit) ///
        anchor(anchor) direction(both) select(nearest) ///
        generate(x) datename(x)
    assert _rc == 198
    capture noisily asof abcdefghijklmnopqrstuvwxyz using `events', ///
        id(id) date(visit) anchor(anchor) direction(both) ///
        select(nearest) suffix(_123456789)
    assert _rc == 198
}
if _rc == 0 local ++pass_count
else local ++fail_count

**# replace updates only selected valid-key rows
local ++test_count
capture noisily {
    tempfile events
    clear
    input id visit score
    1 5 50
    2 5 60
    end
    save `events'
    clear
    input id anchor existing
    1 5 -1
    2 5 -2
    3 5 -3
    end
    asof score using `events' if id == 1, id(id) date(visit) ///
        anchor(anchor) direction(both) select(nearest) ///
        generate(existing) replace
    assert existing[1] == 50
    assert existing[2] == -2
    assert existing[3] == -3
    assert r(N_master) == 1
}
if _rc == 0 local ++pass_count
else local ++fail_count

**# varabbrev is restored on success and error
local ++test_count
capture noisily {
    tempfile events
    clear
    input id visit score
    1 5 50
    end
    save `events'
    clear
    input id anchor
    1 5
    end
    set varabbrev on
    asof score using `events', id(id) date(visit) anchor(anchor) ///
        direction(both) select(nearest)
    assert "`c(varabbrev)'" == "on"
    capture noisily asof score using `events', id(id) date(visit) ///
        anchor(anchor) direction(bad) select(nearest)
    assert _rc == 198
    assert "`c(varabbrev)'" == "on"
}
if _rc == 0 local ++pass_count
else local ++fail_count

display "RESULT: test_asof_syntax tests=`test_count' pass=`pass_count' fail=`fail_count' skip=0"
if `fail_count' > 0 {
    capture log close _all
    exit 1
}
global ASOF_QA_STATUS "pass"
log close _all
