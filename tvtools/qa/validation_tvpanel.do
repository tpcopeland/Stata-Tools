*! validation_tvpanel.do -- hand-computed known answers for tvpanel
*!
*! test_tvpanel.do proves the grid math on a SINGLE-episode, SINGLE-class
*! fixture. This suite exercises the deterministic paths that a one-episode
*! fixture cannot reach and that downstream MSM panels actually hit:
*!   * latest-start-wins active class when MULTIPLE episodes cover an interval
*!   * the eclass secondary tie-break when two episodes share an exact start
*!   * per-class cumulative accrual RESHAPED across multiple non-reference classes
*!   * the strict estart<pstart cumulative bound vs the estart<=pstart active
*!     bound (an episode starting exactly at the interval start is ACTIVE but
*!     contributes ZERO cumulative days)
*!   * cumulative() unit scaling (cumdiv) on the same accrued day counts
*!
*! Every expected value below is enumerated by hand from the DGP. Width is 100
*! days throughout so the interval arithmetic is exact and inspectable.
*!
*! Fixture (E1=01jan2020, E2=01jun2020, E3=01sep2020; width=100):
*!   Person 1: entry E1, exit E1+250 -> ceil(250/100)=3 periods (0,1,2)
*!       starts E1, E1+100, E1+200 ; stops E1+99, E1+199, E1+250 (last clamped)
*!       episodes: A class 1 [E1+20 ,E1+120], B class 2 [E1+90,E1+260],
*!                 C class 1 [E1+210,E1+260]
*!     active@start: p0->ref 0 (no cover); p1->2 (B start 90 > A start 20);
*!                   p2->2 (only B covers; C starts E1+210 > E1+200)
*!     cum days (eclass!=ref, estart<pstart, days=min(estop,pstart-1)-estart+1):
*!       p0: cum_1=0,  cum_2=0
*!       p1: cum_1=min(120,99)-20+1 =80 ; cum_2=min(260,99)-90+1 =10
*!       p2: cum_1=min(120,199)-20+1=101; cum_2=min(260,199)-90+1=110
*!       (C never accrues: estart E1+210 is never < any pstart in {0,100,200})
*!   Person 2: entry E2, exit E2+100 -> 1 period (0); start E2, stop E2+99
*!       episode class 1 [E2,E2+50] starts AT entry
*!     active@start p0 -> 1 (estart=E2 <= pstart=E2)
*!     cumulative   p0 -> 0 (estart=E2 is NOT < pstart=E2: strict bound)
*!   Person 3: entry E3, exit E3+100 -> 1 period (0)
*!       episodes class 3 [E3,E3+80] and class 7 [E3,E3+80] (identical span)
*!     active@start p0 -> 7 (tie on estart -> highest eclass wins)
*!     cumulative   p0 -> 0 for every class (estart=E3 not < pstart=E3)
*!   Reshape: only classes 1 and 2 ever accrue positive prior days -> the panel
*!   carries cum_1 and cum_2 only; persons 2 and 3 are filled 0.
*!   Totals: n_persons=3, n_observations=3+1+1=5.
clear all
set more off
set varabbrev off
version 16.0

capture log close
quietly log using "validation_tvpanel.log", replace nomsg

do "`c(pwd)'/_tvtools_qa_common.do"
_tvtools_qa_bootstrap

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

display as result "tvtools QA: tvpanel correctness -- $S_DATE $S_TIME"

local E1 = mdy(1,1,2020)
local E2 = mdy(6,1,2020)
local E3 = mdy(9,1,2020)

* Build the shared episode (using) file: 6 episodes across 3 persons.
* (built with set obs + replace so the date expressions evaluate; input does
*  not expand inline `=...' macro functions in its data rows.)
clear
set obs 6
gen long id = .
gen double start = .
gen double stop = .
gen int eclass = .
replace id = 1 in 1/3
replace id = 2 in 4
replace id = 3 in 5/6
replace start = `E1'+20  in 1
replace stop  = `E1'+120 in 1
replace eclass = 1       in 1
replace start = `E1'+90  in 2
replace stop  = `E1'+260 in 2
replace eclass = 2       in 2
replace start = `E1'+210 in 3
replace stop  = `E1'+260 in 3
replace eclass = 1       in 3
replace start = `E2'     in 4
replace stop  = `E2'+50  in 4
replace eclass = 1       in 4
replace start = `E3'     in 5
replace stop  = `E3'+80  in 5
replace eclass = 3       in 5
replace start = `E3'     in 6
replace stop  = `E3'+80  in 6
replace eclass = 7       in 6
format start stop %td
tempfile epi
save `epi'

* Master: one row per person.
clear
set obs 3
gen long id = _n
gen double entry = .
gen double exit = .
replace entry = `E1'     in 1
replace exit  = `E1'+250 in 1
replace entry = `E2'     in 2
replace exit  = `E2'+100 in 2
replace entry = `E3'     in 3
replace exit  = `E3'+100 in 3
format entry exit %td
tempfile master
save `master'

* -----------------------------------------------------------------------
* KA1: grid structure -- ceil period count, 0-based contiguous index,
*      exact entry-anchored starts, last interval clamped at exit.
* -----------------------------------------------------------------------
local ++test_count
capture {
    use `master', clear
    tvpanel using `epi', id(id) entry(entry) exit(exit) exposure(eclass) ///
        reference(0) width(100) cumulative(days)
    assert r(n_persons) == 3
    assert r(n_observations) == 5
    sort id period
    by id: assert period == _n - 1
    * exact entry anchoring: start == entry + 100*period for every row
    gen double _e = cond(id==1, `E1', cond(id==2, `E2', `E3'))
    quietly count if start != _e + 100*period
    assert r(N) == 0
    * person 1 last interval clamped at exit (E1+250), not E1+299
    quietly sum stop if id==1 & period==2, meanonly
    assert r(mean) == `E1'+250
    * person 1 first interval stop = E1+99 (full width minus 1)
    quietly sum stop if id==1 & period==0, meanonly
    assert r(mean) == `E1'+99
}
if _rc==0 {
    display as result "  PASS [KA1.grid]: ceil count, 0-based, entry-anchored, clamped"
    local ++pass_count
}
else {
    display as error "  FAIL [KA1.grid] (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' KA1"
}

* -----------------------------------------------------------------------
* KA2: active class -- latest-start-wins, reference fill, episode-at-entry,
*      and the eclass secondary tie-break on identical starts.
* -----------------------------------------------------------------------
local ++test_count
capture {
    use `master', clear
    tvpanel using `epi', id(id) entry(entry) exit(exit) exposure(eclass) ///
        reference(0) width(100)
    sort id period
    * p1 period0: no episode covers E1 -> reference 0
    quietly sum tv_class if id==1 & period==0, meanonly
    assert r(mean) == 0
    * p1 period1: A[20,120] and B[90,260] both cover E1+100; latest start = B -> 2
    quietly sum tv_class if id==1 & period==1, meanonly
    assert r(mean) == 2
    * p1 period2: only B covers E1+200 (C starts E1+210) -> 2
    quietly sum tv_class if id==1 & period==2, meanonly
    assert r(mean) == 2
    * p2 period0: episode starts AT entry -> active class 1
    quietly sum tv_class if id==2 & period==0, meanonly
    assert r(mean) == 1
    * p3 period0: two episodes share start E3 -> highest eclass wins -> 7
    quietly sum tv_class if id==3 & period==0, meanonly
    assert r(mean) == 7
}
if _rc==0 {
    display as result "  PASS [KA2.active]: latest-start + eclass tie-break + ref fill"
    local ++pass_count
}
else {
    display as error "  FAIL [KA2.active] (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' KA2"
}

* -----------------------------------------------------------------------
* KA3: per-class cumulative accrual (days) -- exact day counts across two
*      classes, strict estart<pstart bound, and 0 for never-exposed persons.
* -----------------------------------------------------------------------
local ++test_count
capture {
    use `master', clear
    tvpanel using `epi', id(id) entry(entry) exit(exit) exposure(eclass) ///
        reference(0) width(100) cumulative(days)
    * reshape kept only the accruing classes: cum_1 and cum_2 exist, cum_3/cum_7 do not
    confirm variable cum_1
    confirm variable cum_2
    capture confirm variable cum_3
    assert _rc != 0
    sort id period
    * person 1 exact accrued days
    quietly sum cum_1 if id==1 & period==0, meanonly
    assert r(mean) == 0
    quietly sum cum_2 if id==1 & period==0, meanonly
    assert r(mean) == 0
    quietly sum cum_1 if id==1 & period==1, meanonly
    assert r(mean) == 80
    quietly sum cum_2 if id==1 & period==1, meanonly
    assert r(mean) == 10
    quietly sum cum_1 if id==1 & period==2, meanonly
    assert r(mean) == 101
    quietly sum cum_2 if id==1 & period==2, meanonly
    assert r(mean) == 110
    * person 2: episode starts AT interval start -> active but cumulative 0 (strict <)
    quietly sum cum_1 if id==2 & period==0, meanonly
    assert r(mean) == 0
    * person 3: never accrues prior days -> all cumulative 0
    quietly sum cum_1 if id==3, meanonly
    assert r(mean) == 0
    quietly sum cum_2 if id==3, meanonly
    assert r(mean) == 0
}
if _rc==0 {
    display as result "  PASS [KA3.cumulative]: multi-class day accrual, strict bound, 0-fill"
    local ++pass_count
}
else {
    display as error "  FAIL [KA3.cumulative] (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' KA3"
}

* -----------------------------------------------------------------------
* KA4: cumulative() unit scaling -- same accrued days divided by cumdiv.
*      weeks: cumdiv=7, so person 1 period1 cum_1 = 80/7, cum_2 = 10/7.
* -----------------------------------------------------------------------
local ++test_count
capture {
    use `master', clear
    tvpanel using `epi', id(id) entry(entry) exit(exit) exposure(eclass) ///
        reference(0) width(100) cumulative(weeks)
    sort id period
    quietly sum cum_1 if id==1 & period==1, meanonly
    assert reldif(r(mean), 80/7) < 1e-9
    quietly sum cum_2 if id==1 & period==1, meanonly
    assert reldif(r(mean), 10/7) < 1e-9
    quietly sum cum_1 if id==1 & period==2, meanonly
    assert reldif(r(mean), 101/7) < 1e-9
}
if _rc==0 {
    display as result "  PASS [KA4.units]: cumdiv scaling exact (weeks)"
    local ++pass_count
}
else {
    display as error "  FAIL [KA4.units] (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' KA4"
}

* ===== Summary =====
local test_count = `pass_count' + `fail_count'
display as result _newline "tvtools QA tvpanel correctness Results -- $S_DATE $S_TIME"
display as text "Tests run:  `test_count'"
display as text "Passed:     `pass_count'"
display as text "Failed:     `fail_count'"
display "RESULT: validation_tvpanel tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 {
    display as error "TESTS FAILED: `failed_tests'"
    exit 1
}
display as result "ALL TESTS PASSED"
