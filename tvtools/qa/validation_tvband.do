*! validation_tvband.do -- hand-computed known answers for tvband
clear all
set more off
set varabbrev off
version 16.0

capture log close
quietly log using "validation_tvband.log", replace nomsg

do "`c(pwd)'/_tvtools_qa_common.do"
_tvtools_qa_bootstrap

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

display as result "tvtools QA: tvband correctness -- $S_DATE $S_TIME"

* -----------------------------------------------------------------------
* KA1: elapsed (day) -- fully hand-enumerable
*   interval [100,250], origin=100, width=50 (days)
*   bands: [100,149]=0 [150,199]=50 [200,249]=100 [250,250]=150
* -----------------------------------------------------------------------
local ++test_count
capture {
    clear
    set obs 1
    gen long id = 1
    gen double t0 = 100
    gen double t1 = 250
    gen double orig = 100
    tvband, id(id) start(t0) stop(t1) type(elapsed) origin(orig) width(50) unit(day) generate(b)
    assert "`r(axistype)'" == "elapsed"
    assert "`r(varname)'" == "b"
    assert r(width) == 50
    sort t0
    assert _N == 4
    assert t0[1]==100 & t1[1]==149 & b[1]==0
    assert t0[2]==150 & t1[2]==199 & b[2]==50
    assert t0[3]==200 & t1[3]==249 & b[3]==100
    assert t0[4]==250 & t1[4]==250 & b[4]==150
}
if _rc==0 {
    display as result "  PASS [KA1.elapsed-day]: exact band boundaries"
    local ++pass_count
}
else {
    display as error "  FAIL [KA1.elapsed-day] (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' KA1"
}

* -----------------------------------------------------------------------
* KA2: calendar -- Jan-1 cut points exactly
*   interval [01jun2019, 15mar2021], width=1
*   2019: [01jun2019,31dec2019]; 2020 full; 2021: [01jan2021,15mar2021]
* -----------------------------------------------------------------------
local ++test_count
capture {
    clear
    set obs 1
    gen long id = 1
    gen double t0 = mdy(6,1,2019)
    gen double t1 = mdy(3,15,2021)
    format t0 t1 %td
    tvband, id(id) start(t0) stop(t1) type(calendar) width(1) generate(cy)
    sort t0
    assert _N == 3
    assert cy[1]==2019 & t0[1]==mdy(6,1,2019) & t1[1]==mdy(12,31,2019)
    assert cy[2]==2020 & t0[2]==mdy(1,1,2020) & t1[2]==mdy(12,31,2020)
    assert cy[3]==2021 & t0[3]==mdy(1,1,2021) & t1[3]==mdy(3,15,2021)
}
if _rc==0 {
    display as result "  PASS [KA2.calendar]: exact Jan-1 cuts"
    local ++pass_count
}
else {
    display as error "  FAIL [KA2.calendar] (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' KA2"
}

* -----------------------------------------------------------------------
* KA3: age -- boundary date = round(dob + age*365.25)
*   dob=01jan1960, interval [01jul2009, 01jul2013], width=1
*   each interval [round(dob+a*365.25), round(dob+(a+1)*365.25)-1] clamped
* -----------------------------------------------------------------------
local ++test_count
capture {
    clear
    set obs 1
    gen long id = 1
    gen double dob = mdy(1,1,1960)
    gen double t0  = mdy(7,1,2009)
    gen double t1  = mdy(7,1,2013)
    format dob t0 t1 %td
    tvband, id(id) start(t0) stop(t1) type(age) origin(dob) width(1) generate(a)
    sort t0
    * first row starts at study entry; later rows at exact birthday boundaries
    assert t0[1]==mdy(7,1,2009)
    assert t1[_N]==mdy(7,1,2013)
    * each interior boundary equals round(dob + age*365.25)
    gen double expect_start = round(mdy(1,1,1960) + a*365.25)
    assert t0==expect_start if _n>1
    * abutment + coverage
    gen double dur = t1 - t0 + 1
    quietly summarize dur
    assert r(sum) == mdy(7,1,2013) - mdy(7,1,2009) + 1
    assert _n==1 | t0 == t1[_n-1] + 1
}
if _rc==0 {
    display as result "  PASS [KA3.age]: birthday boundaries + coverage"
    local ++pass_count
}
else {
    display as error "  FAIL [KA3.age] (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' KA3"
}

* -----------------------------------------------------------------------
* KA4: calendar width=2, anchor pinned -- 2-year blocks from anchor(2018)
*   [01jan2019, 31dec2022], anchor 2018, width 2 -> blocks 2018-19, 2020-21, 2022-23
*   2019 in block 2018; 2020-21 in block 2020; 2022 in block 2022
* -----------------------------------------------------------------------
local ++test_count
capture {
    clear
    set obs 1
    gen long id = 1
    gen double t0 = mdy(1,1,2019)
    gen double t1 = mdy(12,31,2022)
    format t0 t1 %td
    tvband, id(id) start(t0) stop(t1) type(calendar) width(2) anchor(2018) generate(cb)
    sort t0
    assert _N == 3
    assert cb[1]==2018 & t0[1]==mdy(1,1,2019)  & t1[1]==mdy(12,31,2019)
    assert cb[2]==2020 & t0[2]==mdy(1,1,2020)  & t1[2]==mdy(12,31,2021)
    assert cb[3]==2022 & t0[3]==mdy(1,1,2022)  & t1[3]==mdy(12,31,2022)
}
if _rc==0 {
    display as result "  PASS [KA4.calendar-w2]: 2-year anchored blocks"
    local ++pass_count
}
else {
    display as error "  FAIL [KA4.calendar-w2] (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' KA4"
}

* ===== Summary =====
local test_count = `pass_count' + `fail_count'
display as result _newline "tvtools QA tvband correctness Results -- $S_DATE $S_TIME"
display as text "Tests run:  `test_count'"
display as text "Passed:     `pass_count'"
display as text "Failed:     `fail_count'"
display "RESULT: validation_tvband tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 {
    display as error "TESTS FAILED: `failed_tests'"
    exit 1
}
display as result "ALL TESTS PASSED"
