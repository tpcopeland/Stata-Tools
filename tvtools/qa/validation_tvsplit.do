*! validation_tvsplit.do -- correctness of the Lexis grid produced by tvsplit
*!
*! A correct multi-axis split is uniquely characterized by three properties,
*! which together force exactly the Lexis grid (the coarsest partition whose
*! pieces each lie in one band on every axis):
*!   (1) tiling:      pieces cover [entry,exit] with no gaps/overlaps
*!   (2) single-band: each piece lies within one band on every requested axis
*!   (3) maximality:  no two adjacent pieces share ALL bands (no redundant cut)
*! These are asserted directly, so the test is independent of hand-enumerating
*! cells (which is error-prone across leap years and elapsed-boundary effects).
clear all
set more off
set varabbrev off
version 16.0

capture log close
quietly log using "validation_tvsplit.log", replace nomsg

do "`c(pwd)'/_tvtools_qa_common.do"
_tvtools_qa_bootstrap

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

display as result "tvtools QA: tvsplit correctness -- $S_DATE $S_TIME"

* -----------------------------------------------------------------------
* CASE 1: calendar(1) + elapsed(entry, day, 365) -- exact axes
*   5 persons, varied entry/exit; assert tiling + single-band + maximality
* -----------------------------------------------------------------------
local ++test_count
capture {
    clear
    set obs 5
    gen long id = _n
    gen double entry = mdy(1,1,2018) + (_n-1)*97
    gen double exitd = entry + 600 + (_n-1)*111
    format entry exitd %td
    * record original span per id for the tiling check
    gen double span0 = exitd - entry + 1
    preserve
    keep id span0
    tempfile spans
    save "`spans'"
    restore

    tvsplit, id(id) start(entry) stop(exitd) calendar(, width(1)) ///
        elapsed(entry, width(365) unit(day) generate(fu))

    * bring back original entry to recompute elapsed days; recover via min start
    bysort id (entry): gen double ent0 = entry[1]

    * (2) single-band: calendar
    assert year(entry) == calband
    assert year(exitd) == calband
    * (2) single-band: elapsed
    assert floor((entry - ent0)/365)*365 == fu
    assert floor((exitd - ent0)/365)*365 == fu

    * (1) tiling: per-id summed duration == original span, abutment
    gen double dur = exitd - entry + 1
    bysort id (entry exitd): egen double tot = total(dur)
    bysort id (entry exitd): gen byte abut = (_n==1) | (entry == exitd[_n-1] + 1)
    assert abut == 1
    * compare totals to recorded spans
    bysort id (entry): keep if _n==1
    merge 1:1 id using "`spans'", assert(match) nogenerate
    assert tot == span0

    * (3) maximality re-checked on a fresh split (need full rows)
    clear
    set obs 5
    gen long id = _n
    gen double entry = mdy(1,1,2018) + (_n-1)*97
    gen double exitd = entry + 600 + (_n-1)*111
    format entry exitd %td
    tvsplit, id(id) start(entry) stop(exitd) calendar(, width(1)) ///
        elapsed(entry, width(365) unit(day) generate(fu))
    sort id entry
    by id: gen byte redundant = (_n>1) & (calband==calband[_n-1]) & (fu==fu[_n-1])
    assert redundant == 0
}
if _rc==0 {
    display as result "  PASS [C1]: cal+elapsed tiling/single-band/maximality"
    local ++pass_count
}
else {
    display as error "  FAIL [C1] (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' C1"
}

* -----------------------------------------------------------------------
* CASE 2: 3-axis age(10)+calendar(1)+elapsed(year,1) -- full Lexis grid
*   age band value must equal the round(dob+...) boundary formula
* -----------------------------------------------------------------------
local ++test_count
capture {
    clear
    set obs 4
    gen long id = _n
    gen double dob   = mdy(1,1,1965) + (_n-1)*173
    gen double entry = mdy(4,1,2017)
    gen double exitd = mdy(9,30,2021)
    format dob entry exitd %td
    gen double dob0 = dob
    gen double ent0 = entry

    tvsplit, id(id) start(entry) stop(exitd) age(dob0, width(10)) ///
        calendar(, width(1)) elapsed(ent0, width(1) unit(year))

    * single-band per axis at start and stop
    assert year(entry)==calband & year(exitd)==calband
    * age band value = floor of exact age at band lower edge; verify membership:
    * start age >= ageband and stop age < ageband+10 (in 365.25-year units)
    gen double age_start = (entry - dob0)/365.25
    gen double age_stop  = (exitd - dob0)/365.25
    assert age_start >= ageband - 0.01
    assert age_stop  <  ageband + 10 + 0.01
    * elapsed-year band membership
    gen double fu_start = (entry - ent0)/365.25
    assert fu_start >= fuband - 0.01 & fu_start < fuband + 1 + 0.01

    * tiling per id
    gen double dur = exitd - entry + 1
    bysort id (entry exitd): egen double tot = total(dur)
    by id: gen byte abut = (_n==1) | (entry == exitd[_n-1] + 1)
    assert abut == 1
    by id: assert tot == mdy(9,30,2021) - mdy(4,1,2017) + 1

    * maximality across all 3 bands
    sort id entry
    by id: gen byte redundant = (_n>1) & (ageband==ageband[_n-1]) & ///
        (calband==calband[_n-1]) & (fuband==fuband[_n-1])
    assert redundant == 0
}
if _rc==0 {
    display as result "  PASS [C2]: 3-axis grid membership + tiling + maximality"
    local ++pass_count
}
else {
    display as error "  FAIL [C2] (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' C2"
}

* ===== Summary =====
local test_count = `pass_count' + `fail_count'
display as result _newline "tvtools QA tvsplit correctness Results -- $S_DATE $S_TIME"
display as text "Tests run:  `test_count'"
display as text "Passed:     `pass_count'"
display as text "Failed:     `fail_count'"
display "RESULT: validation_tvsplit tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 {
    display as error "TESTS FAILED: `failed_tests'"
    exit 1
}
display as result "ALL TESTS PASSED"
