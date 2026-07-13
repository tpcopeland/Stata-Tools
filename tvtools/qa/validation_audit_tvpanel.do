/*******************************************************************************
* validation_audit_tvpanel.do
*
* Audit-closure known-answer checks for one-day follow-up, strict source
* integrity, same-class episode unions, and the downstream survival contract.
*
* Author: Timothy P Copeland, Karolinska Institutet
* Date: 2026-07-13
*******************************************************************************/

clear all
set varabbrev off
version 16.0

capture log close _all
quietly log using "validation_audit_tvpanel.log", replace nomsg

do "`c(pwd)'/_tvtools_qa_common.do"
_tvtools_qa_bootstrap

local test_count 0
local pass_count 0
local fail_count 0
local failed_tests ""

display as result "tvtools QA: audit closure for tvpanel -- $S_DATE $S_TIME"

**# Shared empty episode source
quietly {
    clear
    set obs 0
    generate long id = .
    generate double start = .
    generate double stop = .
    generate int eclass = .
    tempfile empty_episodes
    save `empty_episodes'
}

**# 1. one-day follow-up without an episode emits one reference row
local ++test_count
capture noisily {
    clear
    input long id double(entry exit) byte sentinel
        1 5 5 71
    end
    tvpanel using `empty_episodes', id(id) entry(entry) exit(exit) ///
        exposure(eclass) width(91) keepvars(sentinel)
    assert _N == 1 & id == 1 & period == 0
    assert start == 5 & stop == 5 & tv_class == 0 & sentinel == 71
    assert r(n_persons) == 1 & r(n_observations) == 1
}
if _rc == 0 {
    display as result "  PASS: one-day unexposed follow-up emits one reference row"
    local ++pass_count
}
else {
    display as error "  FAIL: one-day unexposed follow-up (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' one_day_reference"
}

**# 2. one-day follow-up with an episode carries the active class
quietly {
    clear
    input long id double(start stop) int eclass
        1 5 5 4
    end
    tempfile one_day_episode
    save `one_day_episode'
}

local ++test_count
capture noisily {
    clear
    input long id double(entry exit)
        1 5 5
    end
    tvpanel using `one_day_episode', id(id) entry(entry) exit(exit) ///
        exposure(eclass) cumulative(days)
    assert _N == 1 & start == 5 & stop == 5 & tv_class == 4
    confirm variable cum_4
    assert cum_4 == 0
    assert "`: char cum_4[tvtools_quantity]'" == "cumulative"
    assert "`: char cum_4[tvtools_history_point]'" == "start"
}
if _rc == 0 {
    display as result "  PASS: one-day exposed follow-up carries class and cumulative metadata"
    local ++pass_count
}
else {
    display as error "  FAIL: one-day exposed follow-up (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' one_day_exposed"
}

**# 3. a one-day final partial period is retained
local ++test_count
capture noisily {
    clear
    input long id double(entry exit)
        1 1 4
    end
    tvpanel using `empty_episodes', id(id) entry(entry) exit(exit) ///
        exposure(eclass) width(3)
    sort period
    assert _N == 2 & period[1] == 0 & period[2] == 1
    assert start[1] == 1 & stop[1] == 3
    assert start[2] == 4 & stop[2] == 4
}
if _rc == 0 {
    display as result "  PASS: one-day final partial period is retained"
    local ++pass_count
}
else {
    display as error "  FAIL: one-day final partial period (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' one_day_tail"
}

**# 4. cumulative exposure uses each per-class episode union
quietly {
    clear
    input long id double(start stop) int eclass
        1 1 4 1
        1 3 7 1
        1 2 3 1
        1 8 9 1
        1 8 9 1
        1 3 4 2
    end
    tempfile overlapping_episodes
    save `overlapping_episodes'
}

local ++test_count
capture noisily {
    clear
    input long id double(entry exit)
        1 1 10
    end
    tvpanel using `overlapping_episodes', id(id) entry(entry) exit(exit) ///
        exposure(eclass) width(3) cumulative(days)
    sort period
    assert _N == 4
    assert start[1] == 1 & start[2] == 4 & start[3] == 7 & start[4] == 10
    assert cum_1[1] == 0 & cum_1[2] == 3
    assert cum_1[3] == 6 & cum_1[4] == 9
    assert cum_2[1] == 0 & cum_2[2] == 1
    assert cum_2[3] == 2 & cum_2[4] == 2
}
if _rc == 0 {
    display as result "  PASS: nested, crossing, duplicate, and abutting episodes count once per class"
    local ++pass_count
}
else {
    display as error "  FAIL: cumulative episode union (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' cumulative_union"
}

**# 5. malformed master rows are strict with exact dropinvalid counts
quietly {
    clear
    input long id double(start stop) int eclass
        5 5 5 2
    end
    tempfile master_policy_episode
    save `master_policy_episode'
}

local ++test_count
capture noisily {
    clear
    input double(id entry exit) byte sentinel
        . 1   2 81
        2 .   2 82
        3 1.5 3 83
        4 5   3 84
        5 5   5 85
    end
    capture noisily tvpanel using `master_policy_episode', id(id) ///
        entry(entry) exit(exit) exposure(eclass)
    local cmdrc = _rc
    assert `cmdrc' == 498
    assert _N == 5 & sentinel[1] == 81 & sentinel[5] == 85

    tvpanel using `master_policy_episode', id(id) entry(entry) exit(exit) ///
        exposure(eclass) dropinvalid verbose
    assert r(n_invalid) == 4 & r(n_invalid_master) == 4
    assert r(n_invalid_master_id) == 1
    assert r(n_invalid_master_dates) == 2
    assert r(n_invalid_master_order) == 1
    assert r(n_invalid_episodes) == 0
    assert _N == 1 & id == 5 & start == 5 & stop == 5 & tv_class == 2
}
if _rc == 0 {
    display as result "  PASS: master strict/dropinvalid policy has exact accounting"
    local ++pass_count
}
else {
    display as error "  FAIL: master integrity policy (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' master_integrity"
}

**# 6. malformed episode rows are strict with exact dropinvalid counts
quietly {
    clear
    input double(id start stop eclass)
        1 1   10  1
        . 1    2  1
        2 .    2  1
        3 1    2.5 1
        4 5    3  1
        5 1    2  .
        6 1    2  1.5
    end
    tempfile malformed_episodes
    save `malformed_episodes'
}

local ++test_count
capture noisily {
    clear
    input long id double(entry exit) byte sentinel
        1 1 10 86
    end
    capture noisily tvpanel using `malformed_episodes', id(id) ///
        entry(entry) exit(exit) exposure(eclass)
    local cmdrc = _rc
    assert `cmdrc' == 498
    assert _N == 1 & sentinel == 86

    tvpanel using `malformed_episodes', id(id) entry(entry) exit(exit) ///
        exposure(eclass) width(10) dropinvalid verbose
    assert r(n_invalid) == 6 & r(n_invalid_episodes) == 6
    assert r(n_invalid_episode_id) == 1
    assert r(n_invalid_episode_dates) == 2
    assert r(n_invalid_episode_order) == 1
    assert r(n_invalid_episode_exposure) == 2
    assert _N == 1 & id == 1 & tv_class == 1
}
if _rc == 0 {
    display as result "  PASS: episode strict/dropinvalid policy has exact accounting"
    local ++pass_count
}
else {
    display as error "  FAIL: episode integrity policy (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' episode_integrity"
}

**# 7. nonnumeric episode bounds fail before caller mutation
quietly {
    clear
    input long id str2(start stop) int eclass
        1 "1" "5" 1
    end
    tempfile string_episodes
    save `string_episodes'
}

local ++test_count
capture noisily {
    clear
    input long id double(entry exit) byte sentinel
        1 1 5 87
    end
    capture noisily tvpanel using `string_episodes', id(id) ///
        entry(entry) exit(exit) exposure(eclass)
    local cmdrc = _rc
    assert `cmdrc' == 109
    assert _N == 1 & id == 1 & entry == 1 & exit == 5 & sentinel == 87
}
if _rc == 0 {
    display as result "  PASS: string episode bounds fail transactionally"
    local ++pass_count
}
else {
    display as error "  FAIL: string episode bounds (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' string_bounds"
}

**# 8. duplicate master IDs remain a transactional panel-key error
local ++test_count
capture noisily {
    clear
    input long id double(entry exit) byte sentinel
        1 1 5 88
        1 1 5 89
    end
    capture noisily tvpanel using `empty_episodes', id(id) ///
        entry(entry) exit(exit) exposure(eclass)
    local cmdrc = _rc
    assert `cmdrc' == 459
    assert _N == 2 & sentinel[1] == 88 & sentinel[2] == 89
}
if _rc == 0 {
    display as result "  PASS: duplicate master IDs fail transactionally"
    local ++pass_count
}
else {
    display as error "  FAIL: duplicate master ID contract (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' duplicate_master"
}

**# 9. one-day panel survives tvevent and exact stset conversion
local ++test_count
capture noisily {
    clear
    input long id double(entry exit)
        1 5 5
    end
    tempfile one_day_panel
    tvpanel using `one_day_episode', id(id) entry(entry) exit(exit) ///
        exposure(eclass) saveas("`one_day_panel'") replace

    clear
    input long id double eventdate
        1 5
    end
    tvevent using "`one_day_panel'", id(id) date(eventdate) ///
        generate(outcome)
    assert _N == 1 & start == 5 & stop == 5 & outcome == 1
    generate double start0 = start - 1
    stset stop, id(id) failure(outcome == 1) time0(start0)
    generate double analysis_time = _t - _t0
    assert analysis_time == 1 & _d == 1
}
if _rc == 0 {
    display as result "  PASS: one-day tvpanel-tvevent-stset pipeline preserves time and event"
    local ++pass_count
}
else {
    display as error "  FAIL: one-day event pipeline (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' one_day_pipeline"
}

display "RESULT: validation_audit_tvpanel tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 {
    display as error "TESTS FAILED: `failed_tests'"
    exit 1
}

capture log close _all
