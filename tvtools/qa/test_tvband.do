*! test_tvband.do -- functional tests for tvband (single-axis splitter)
clear all
set more off
set varabbrev off
version 16.0

capture log close
quietly log using "test_tvband.log", replace nomsg

do "`c(pwd)'/_tvtools_qa_common.do"
_tvtools_qa_bootstrap

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

display as result "tvtools QA: tvband functional -- $S_DATE $S_TIME"

* Reusable cohort builder (3 persons)
capture program drop _mkcohort
program define _mkcohort
    clear
    set obs 3
    gen long id = _n
    gen double dob   = mdy(1,1,1960) + (_n-1)*150
    gen double entry = mdy(7,1,2009)
    gen double exitd = mdy(7,1,2013)
    gen byte sex = mod(_n,2)
    format dob entry exitd %td
end

* TEST 1: calendar split runs, returns, preserves covariate
local ++test_count
capture {
    _mkcohort
    tvband, id(id) start(entry) stop(exitd) type(calendar) width(1) generate(cal)
    assert "`r(varname)'" == "cal"
    assert r(n_persons) == 3
    assert r(n_observations) == _N
    confirm variable sex
    assert year(entry) == cal
}
if _rc==0 {
    display as result "  PASS: calendar split + returns + covariate"
    local ++pass_count
}
else {
    display as error "  FAIL: calendar split (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 1.cal"
}

* TEST 2: age split with grouping + custom names + value label
local ++test_count
capture {
    _mkcohort
    tvband, id(id) start(entry) stop(exitd) type(age) origin(dob) width(5) ///
        generate(ageg) startgen(a0) stopgen(a1)
    confirm variable ageg
    confirm variable a0
    confirm variable a1
    assert "`: value label ageg'" != ""
    assert "`r(startvar)'" == "a0"
    assert "`r(stopvar)'" == "a1"
}
if _rc==0 {
    display as result "  PASS: age grouped split + custom names + label"
    local ++pass_count
}
else {
    display as error "  FAIL: age grouped split (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 2.age"
}

* TEST 3: elapsed (year) split + stset compatibility
local ++test_count
capture {
    _mkcohort
    tvband, id(id) start(entry) stop(exitd) type(elapsed) origin(entry) ///
        width(1) unit(year) generate(fu)
    gen byte dead = 0
    stset exitd, id(id) failure(dead) origin(time entry) enter(time entry)
}
if _rc==0 {
    display as result "  PASS: elapsed-year split + stset compatible"
    local ++pass_count
}
else {
    display as error "  FAIL: elapsed split / stset (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.elapsed"
}

* TEST 4: coverage + abutment invariant (no gaps/overlaps, exact span)
local ++test_count
capture {
    _mkcohort
    tvband, id(id) start(entry) stop(exitd) type(calendar) width(1) generate(cal)
    gen double dur = exitd - entry + 1
    bysort id (entry): gen double cum = sum(dur)
    by id: assert cum[_N] == mdy(7,1,2013) - mdy(7,1,2009) + 1
    by id: assert _n==1 | entry == exitd[_n-1] + 1
}
if _rc==0 {
    display as result "  PASS: coverage + abutment invariant"
    local ++pass_count
}
else {
    display as error "  FAIL: coverage/abutment (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.cover"
}

* TEST 5: error guards (bad type, origin rules, datetime, missing)
local ++test_count
capture {
    _mkcohort
    capture tvband, id(id) start(entry) stop(exitd) type(bogus) origin(dob)
    assert _rc==198
    capture tvband, id(id) start(entry) stop(exitd) type(calendar) origin(dob)
    assert _rc==198
    capture tvband, id(id) start(entry) stop(exitd) type(age)
    assert _rc==198
    * datetime rejection
    _mkcohort
    gen double entc = cofd(entry)
    format entc %tc
    capture tvband, id(id) start(entc) stop(exitd) type(calendar)
    assert _rc==120
    * missing date rejection
    _mkcohort
    replace entry = . in 1
    capture tvband, id(id) start(entry) stop(exitd) type(calendar)
    assert _rc==416
}
if _rc==0 {
    display as result "  PASS: error guards (type/origin/datetime/missing)"
    local ++pass_count
}
else {
    display as error "  FAIL: error guards (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 5.guards"
}

* TEST 6: state preservation -- saveas restores original data
local ++test_count
capture {
    _mkcohort
    local norig = _N
    tempfile out
    tvband, id(id) start(entry) stop(exitd) type(calendar) saveas("`out'") replace
    assert _N == `norig'
    confirm variable sex
}
if _rc==0 {
    display as result "  PASS: saveas restores original data"
    local ++pass_count
}
else {
    display as error "  FAIL: saveas state preservation (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 6.saveas"
}

* TEST 7: min/max bounds drop out-of-range bands (age)
local ++test_count
capture {
    _mkcohort
    tvband, id(id) start(entry) stop(exitd) type(age) origin(dob) width(1) ///
        min(50) max(52) generate(ageb)
    quietly count if ageb < 50 | ageb > 52
    assert r(N) == 0
}
if _rc==0 {
    display as result "  PASS: min/max band bounds"
    local ++pass_count
}
else {
    display as error "  FAIL: min/max bounds (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 7.minmax"
}

* Test 8: noisily passthrough accepted and produces the same split
local ++test_count
capture {
    _mkcohort
    tvband, id(id) start(entry) stop(exitd) type(age) origin(dob) width(1) ///
        generate(ageb) noisily
    quietly count
    local n_noisily = r(N)
    _mkcohort
    tvband, id(id) start(entry) stop(exitd) type(age) origin(dob) width(1) generate(ageb)
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
display as result _newline "tvtools QA tvband functional Results -- $S_DATE $S_TIME"
display as text "Tests run:  `test_count'"
display as text "Passed:     `pass_count'"
display as text "Failed:     `fail_count'"
display "RESULT: test_tvband tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 {
    display as error "TESTS FAILED: `failed_tests'"
    exit 1
}
display as result "ALL TESTS PASSED"
