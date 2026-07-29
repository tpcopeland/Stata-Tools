*! test_extended_missing.do
*! Cross-command regression tests for Stata extended missing values (.a-.z).

clear all
set more off
set varabbrev off
version 16.0

capture log close _all
quietly log using "test_extended_missing.log", replace nomsg

do "`c(pwd)'/_tvtools_qa_common.do"
_tvtools_qa_bootstrap

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

**# 1. tvage treats an extended-missing required date as missing
local ++test_count
capture noisily {
    clear
    input long id double(dob entry exit)
        1 0 365 730
        2 0 .a  730
    end
    datasignature set
    capture noisily tvage, id(id) dob(dob) entry(entry) exit(exit)
    local cmdrc = _rc
    assert `cmdrc' == 416
    datasignature confirm
    assert entry[2] == .a
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' tvage"
}

**# 2. tvband treats an extended-missing origin as missing
local ++test_count
capture noisily {
    clear
    input long id double(start stop origin)
        1 100 110 0
        2 100 110 .b
    end
    datasignature set
    capture noisily tvband, id(id) start(start) stop(stop) ///
        type(elapsed) origin(origin)
    local cmdrc = _rc
    assert `cmdrc' == 416
    datasignature confirm
    assert origin[2] == .b
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' tvband"
}

**# 3. tvsplit treats an extended-missing interval bound as missing
local ++test_count
capture noisily {
    clear
    input long id double(start stop)
        1 0 365
        2 0 .c
    end
    datasignature set
    capture noisily tvsplit, id(id) start(start) stop(stop) ///
        calendar(, width(1))
    local cmdrc = _rc
    assert `cmdrc' == 416
    datasignature confirm
    assert stop[2] == .c
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' tvsplit"
}

**# 4. tvdiagnose rejects an extended-missing interval bound transactionally
local ++test_count
capture noisily {
    clear
    input long id double(start stop)
        1 1 10
        2 1 .d
    end
    datasignature set
    capture noisily tvdiagnose, id(id) start(start) stop(stop) gaps
    local cmdrc = _rc
    assert `cmdrc' == 416
    datasignature confirm
    assert stop[2] == .d
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' tvdiagnose"
}

**# 5. tvevent preserves the contract that a missing event date is censoring
local ++test_count
capture noisily {
    clear
    input long id double(start stop)
        1 1 10
    end
    tempfile event_intervals
    save `event_intervals'

    clear
    input long id double eventdate
        1 .a
    end
    tvevent using `event_intervals', id(id) date(eventdate) generate(outcome)
    assert _N == 1
    assert id == 1 & outcome == 0
    assert missing(eventdate)
    assert start == 1 & stop == 10
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' tvevent_censor"
}

**# 6. tvevent counts an extended-missing required interval date exactly
local ++test_count
capture noisily {
    clear
    input long id double(start stop)
        1 1 10
        2 1 .e
    end
    tempfile event_bad_intervals
    save `event_bad_intervals'

    clear
    input long id double eventdate
        1 5
        2 .a
    end
    datasignature set
    capture noisily tvevent using `event_bad_intervals', id(id) ///
        date(eventdate) generate(outcome)
    local cmdrc = _rc
    assert `cmdrc' == 498
    datasignature confirm

    tvevent using `event_bad_intervals', id(id) date(eventdate) ///
        generate(outcome) dropinvalid flow
    local n_invalid = r(n_invalid)
    local n_intervals = r(n_invalid_intervals)
    local n_dates = r(n_invalid_interval_dates)
    assert `n_invalid' == 1
    assert `n_intervals' == 1 & `n_dates' == 1
    assert _N == 1 & id == 1 & outcome == 1
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' tvevent_interval"
}

**# 7. tvexpose applies strict and dropinvalid rules to extended missings
local ++test_count
capture noisily {
    clear
    input long id double(start stop) byte exposure
        1 2 4 1
        2 2 4 1
    end
    tempfile exposure_episodes
    save `exposure_episodes'

    clear
    input long id double(entry exit)
        1 1 10
        2 .f 10
    end
    datasignature set
    capture noisily tvexpose using `exposure_episodes', id(id) ///
        start(start) stop(stop) exposure(exposure) ///
        entry(entry) exit(exit) reference(0) generate(exposed)
    local cmdrc = _rc
    assert `cmdrc' == 498
    datasignature confirm

    tvexpose using `exposure_episodes', id(id) start(start) stop(stop) ///
        exposure(exposure) entry(entry) exit(exit) reference(0) ///
        generate(exposed) dropinvalid flow
    local n_master = r(n_invalid_master)
    local n_dates = r(n_invalid_master_dates)
    assert `n_master' == 1 & `n_dates' == 1
    quietly count if id == 2
    assert r(N) == 0
    sort id start stop
    assert _N == 3
    assert start[1] == 1 & stop[1] == 1 & exposed[1] == 0
    assert start[2] == 2 & stop[2] == 4 & exposed[2] == 1
    assert start[3] == 5 & stop[3] == 10 & exposed[3] == 0
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' tvexpose"
}

**# 8. tvmerge classifies an extended-missing exposure without guessing
local ++test_count
capture noisily {
    clear
    input long id double(s1 e1 x1)
        1 1 5 1
        2 1 5 .g
    end
    tempfile merge_one
    save `merge_one'

    clear
    input long id double(s2 e2 x2)
        1 1 5 2
    end
    tempfile merge_two
    save `merge_two'

    clear
    input int sentinel
        808
    end
    datasignature set
    capture noisily tvmerge "`merge_one'" "`merge_two'", id(id) ///
        start(s1 s2) stop(e1 e2) exposure(x1 x2)
    local cmdrc = _rc
    assert `cmdrc' == 498
    datasignature confirm

    tvmerge "`merge_one'" "`merge_two'", id(id) ///
        start(s1 s2) stop(e1 e2) exposure(x1 x2) dropinvalid
    local n_invalid = r(n_invalid)
    local n_exposure = r(n_invalid_exposure)
    local n_ds1 = r(n_invalid_ds1)
    local n_ds2 = r(n_invalid_ds2)
    assert `n_invalid' == 1 & `n_exposure' == 1
    assert `n_ds1' == 1 & `n_ds2' == 0
    assert _N == 1 & id == 1 & x1 == 1 & x2 == 2
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' tvmerge"
}

**# 9. tvpanel counts an extended-missing episode class exactly
local ++test_count
capture noisily {
    clear
    input long id double(start stop eclass)
        1 1 5 1
        2 1 5 .h
    end
    tempfile panel_episodes
    save `panel_episodes'

    clear
    input long id double(entry exit)
        1 1 10
        2 1 10
    end
    datasignature set
    capture noisily tvpanel using `panel_episodes', id(id) ///
        entry(entry) exit(exit) exposure(eclass) width(5)
    local cmdrc = _rc
    assert `cmdrc' == 498
    datasignature confirm

    tvpanel using `panel_episodes', id(id) entry(entry) exit(exit) ///
        exposure(eclass) width(5) dropinvalid
    local n_invalid = r(n_invalid)
    local n_episodes = r(n_invalid_episodes)
    local n_exposure = r(n_invalid_episode_exposure)
    assert `n_invalid' == 1
    assert `n_episodes' == 1 & `n_exposure' == 1
    assert _N == 4
    quietly count if id == 2 & tv_class != 0
    assert r(N) == 0
    quietly count if id == 2 & tv_class == 0
    assert r(N) == 2
    quietly count if id == 1 & tv_class == 1
    assert r(N) == 1
    quietly count if id == 1 & tv_class == 0
    assert r(N) == 1
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' tvpanel"
}

**# 10. tvweight excludes extended-missing model inputs from estimation
local ++test_count
capture noisily {
    clear
    set seed 29072026
    set obs 1000
    generate double x = rnormal()
    generate byte a = runiform() < invlogit(0.2 + 0.5*x)
    replace x = .a in 1
    replace a = .b in 2

    tvweight a, covariates(x) generate(w) nolog
    local n_fit = r(N)
    assert `n_fit' == 998
    assert x[1] == .a & a[2] == .b
    assert missing(w[1]) & missing(w[2])
    quietly count if !missing(w)
    assert r(N) == 998
    quietly count if w <= 0 & !missing(w)
    assert r(N) == 0
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' tvweight"
}

**# Summary
display "RESULT: test_extended_missing tests=`test_count' pass=`pass_count' fail=`fail_count'"
capture log close _all
if `fail_count' > 0 {
    display as error "extended-missing failures:`failed_tests'"
    exit 1
}
