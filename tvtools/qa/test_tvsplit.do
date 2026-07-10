*! test_tvsplit.do -- functional tests for tvsplit (multi-axis Lexis splitter)
clear all
set more off
set varabbrev off
version 16.0

capture log close
quietly log using "test_tvsplit.log", replace nomsg

do "`c(pwd)'/_tvtools_qa_common.do"
_tvtools_qa_bootstrap

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

display as result "tvtools QA: tvsplit functional -- $S_DATE $S_TIME"

capture program drop _mkcohort
program define _mkcohort
    clear
    set obs 3
    gen long id = _n
    gen double dob   = mdy(1,1,1970) + (_n-1)*123
    gen double entry = mdy(7,1,2019)
    gen double exitd = mdy(3,15,2021)
    gen byte trt = mod(_n,2)
    format dob entry exitd %td
end

* TEST 1: 3-axis split runs, returns, preserves covariate + adds 3 band vars
local ++test_count
capture {
    _mkcohort
    tvsplit, id(id) start(entry) stop(exitd) age(dob, width(10)) ///
        calendar(, width(1)) elapsed(entry, width(1) unit(year))
    assert r(n_axes)==3
    assert r(n_persons)==3
    assert r(n_observations)==_N
    assert "`r(startvar)'"=="entry"
    assert "`r(stopvar)'"=="exitd"
    confirm variable trt
    confirm variable ageband
    confirm variable calband
    confirm variable fuband
}
if _rc==0 {
    display as result "  PASS: 3-axis split + returns + covariate + band vars"
    local ++pass_count
}
else {
    display as error "  FAIL: 3-axis split (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 1.3axis"
}

* TEST 2: coverage + abutment per id (Lexis grid tiles follow-up exactly)
local ++test_count
capture {
    _mkcohort
    tvsplit, id(id) start(entry) stop(exitd) age(dob, width(10)) calendar(, width(1))
    gen double dur = exitd - entry + 1
    bysort id (entry exitd): gen double cum = sum(dur)
    by id: assert cum[_N] == mdy(3,15,2021) - mdy(7,1,2019) + 1
    by id: assert _n==1 | entry == exitd[_n-1] + 1
}
if _rc==0 {
    display as result "  PASS: Lexis coverage + abutment"
    local ++pass_count
}
else {
    display as error "  FAIL: coverage/abutment (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 2.cover"
}

* TEST 3: tvsplit(age,cal) == composed tvband(age) then tvband(cal)
local ++test_count
capture {
    _mkcohort
    tvsplit, id(id) start(entry) stop(exitd) age(dob, width(10)) calendar(, width(1))
    keep id entry exitd
    sort id entry exitd
    tempfile viasplit
    save "`viasplit'"
    _mkcohort
    tvband, id(id) start(entry) stop(exitd) type(age) origin(dob) width(10) generate(ab)
    tvband, id(id) start(entry) stop(exitd) type(calendar) width(1) generate(cb)
    keep id entry exitd
    sort id entry exitd
    cf _all using "`viasplit'"
}
if _rc==0 {
    display as result "  PASS: tvsplit == composed tvband"
    local ++pass_count
}
else {
    display as error "  FAIL: tvsplit vs composed tvband (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.compose"
}

* TEST 4: custom band names honored
local ++test_count
capture {
    _mkcohort
    tvsplit, id(id) start(entry) stop(exitd) age(dob, width(5) generate(myage)) ///
        calendar(, width(1) generate(mycal))
    confirm variable myage
    confirm variable mycal
    assert "`r(agevar)'"=="myage"
    assert "`r(calvar)'"=="mycal"
}
if _rc==0 {
    display as result "  PASS: custom band names"
    local ++pass_count
}
else {
    display as error "  FAIL: custom band names (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.names"
}

* TEST 5: integration -- split tvexpose output, exposure column survives
local ++test_count
capture {
    * build a simple already-split exposure dataset (multi-row per id)
    clear
    set obs 4
    gen long id = ceil(_n/2)
    bysort id: gen double entry = mdy(1,1,2019) + (_n-1)*200
    bysort id: gen double exitd = entry + 199
    gen byte exposed = mod(_n,2)
    gen double dob = mdy(1,1,1975)
    format entry exitd dob %td
    tvsplit, id(id) start(entry) stop(exitd) calendar(, width(1)) age(dob, width(5))
    confirm variable exposed
    quietly count if missing(exposed)
    assert r(N)==0
}
if _rc==0 {
    display as result "  PASS: multi-row input + covariate survives"
    local ++pass_count
}
else {
    display as error "  FAIL: multi-row integration (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 5.integ"
}

* TEST 6: error guards -- no axis, duplicate names, bad origin
local ++test_count
capture {
    _mkcohort
    capture tvsplit, id(id) start(entry) stop(exitd)
    assert _rc==198
    capture tvsplit, id(id) start(entry) stop(exitd) age(dob, generate(x)) elapsed(entry, generate(x))
    assert _rc==198
    capture tvsplit, id(id) start(entry) stop(exitd) age(, width(10))
    assert _rc==198
    * missing origin must error (not silently mishandle)
    _mkcohort
    replace dob = . in 1
    capture tvsplit, id(id) start(entry) stop(exitd) age(dob, width(10))
    assert _rc==416
}
if _rc==0 {
    display as result "  PASS: error guards (no-axis/dup-name/no-origin/missing-origin)"
    local ++pass_count
}
else {
    display as error "  FAIL: error guards (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 6.guards"
}

* TEST 7: failure mid-run leaves data intact (preserve/restore on error)
local ++test_count
capture {
    _mkcohort
    local norig = _N
    * datetime on a covariate is fine; force a failure via bad elapsed origin name
    capture tvsplit, id(id) start(entry) stop(exitd) calendar(, width(1)) elapsed(nonexist, width(1))
    assert _rc != 0
    assert _N == `norig'
}
if _rc==0 {
    display as result "  PASS: failed run restores original data"
    local ++pass_count
}
else {
    display as error "  FAIL: error-path restore (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 7.restore"
}

* TEST 8: noisily passthrough accepted and produces the same split
local ++test_count
capture {
    _mkcohort
    tvsplit, id(id) start(entry) stop(exitd) calendar(, width(1)) noisily
    quietly count
    local n_noisily = r(N)
    _mkcohort
    tvsplit, id(id) start(entry) stop(exitd) calendar(, width(1))
    quietly count
    assert r(N) == `n_noisily'
}
if _rc==0 {
    display as result "  PASS: noisily passthrough"
    local ++pass_count
}
else {
    display as error "  FAIL: noisily passthrough (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 8.noisily"
}

* ===== Summary =====
local test_count = `pass_count' + `fail_count'
display as result _newline "tvtools QA tvsplit functional Results -- $S_DATE $S_TIME"
display as text "Tests run:  `test_count'"
display as text "Passed:     `pass_count'"
display as text "Failed:     `fail_count'"
display "RESULT: test_tvsplit tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 {
    display as error "TESTS FAILED: `failed_tests'"
    exit 1
}
display as result "ALL TESTS PASSED"
