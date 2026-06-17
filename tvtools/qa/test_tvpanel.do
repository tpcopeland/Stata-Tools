clear all
set more off
set varabbrev off
version 16.0

capture log close
log using "test_tvpanel.log", replace nomsg

* Shared scaffold: test globals + helpers + sandboxed install bootstrap
do "`c(pwd)'/_tvtools_qa_common.do"
_tvtools_qa_bootstrap

global TVQA_PASS = 0
global TVQA_FAIL = 0
global TVQA_FAILED ""
global TVQA_CURRENT ""

display as result "tvtools QA: tvpanel functional -- $S_DATE $S_TIME"

* ---------------------------------------------------------------------------
* Known-answer fixture
*   Person 1: entry 01jan2020, exit entry+364 -> ceil(364/91)=4 periods (0..3)
*     one episode of class 5 spanning entry+50 .. entry+1000
*   Person 2: entry 01jun2020, exit entry+200 -> ceil(200/91)=3 periods (0..2)
*     no episodes -> all reference, cumulative 0
* ---------------------------------------------------------------------------
local e1 = mdy(1,1,2020)
local e2 = mdy(6,1,2020)

clear
set obs 1
gen long id = 1
gen double start = `e1' + 50
gen double stop  = `e1' + 1000
gen int eclass = 5
format start stop %td
tempfile epi
save `epi'

clear
set obs 2
gen long id = _n
gen double entry = cond(id==1, `e1', `e2')
gen double exit  = cond(id==1, `e1' + 364, `e2' + 200)
format entry exit %td

* ---- TEST 1: grid math, period count, return scalars ----
run_test "grid math + return scalars"
capture noisily {
    preserve
    tvpanel using `epi', id(id) entry(entry) exit(exit) exposure(eclass) ///
        reference(0) width(91) cumulative(years)
    assert_exact `=r(n_persons)' 2 "n_persons"
    assert_exact `=r(n_observations)' 7 "n_observations (4+3)"
    * period is 0-based and contiguous per person
    quietly bysort id (period): assert period == _n - 1
    restore
}
if _rc test_fail "rc=`=_rc'"
else test_pass

* ---- TEST 2: exact start anchoring (entry + 91*period) ----
run_test "exact 91-day anchoring at entry"
capture noisily {
    preserve
    gen double entry_keep = entry
    tvpanel using `epi', id(id) entry(entry) exit(exit) exposure(eclass) ///
        reference(0) width(91) keepvars(entry_keep)
    gen double expect_start = entry_keep + 91 * period
    quietly count if start != expect_start
    assert_exact `=r(N)' 0 "start drift rows"
    * person 1 first start == entry, last stop == exit
    quietly sum start if id==1 & period==0, meanonly
    assert_exact `=r(mean)' `e1' "p1 start[0]==entry"
    quietly sum stop if id==1, meanonly
    restore
}
if _rc test_fail "rc=`=_rc'"
else test_pass

* ---- TEST 3: active class (latest-start wins; reference when uncovered) ----
run_test "active class + reference fill"
capture noisily {
    preserve
    tvpanel using `epi', id(id) entry(entry) exit(exit) exposure(eclass) reference(0) width(91)
    * p1 period 0 starts at entry (< episode start entry+50) -> reference 0
    quietly sum tv_class if id==1 & period==0, meanonly
    assert_exact `=r(mean)' 0 "p1 period0 reference"
    * p1 periods 1..3 covered by class 5
    quietly count if id==1 & period>=1 & tv_class!=5
    assert_exact `=r(N)' 0 "p1 covered=class5"
    * p2 has no episodes -> all reference
    quietly count if id==2 & tv_class!=0
    assert_exact `=r(N)' 0 "p2 all reference"
    restore
}
if _rc test_fail "rc=`=_rc'"
else test_pass

* ---- TEST 4: cumulative-as-of-interval-start (years) ----
run_test "cumulative exposure at interval start"
capture noisily {
    preserve
    tvpanel using `epi', id(id) entry(entry) exit(exit) exposure(eclass) ///
        reference(0) width(91) cumulative(years)
    * cum_5 must exist
    capture confirm variable cum_5
    if _rc {
        display as error "cum_5 not created"
        exit 9
    }
    * p1 period0 start=entry: episode starts at entry+50 (not before entry) -> 0
    quietly sum cum_5 if id==1 & period==0, meanonly
    assert_approx `=r(mean)' 0 1e-9 "p1 period0 cum=0"
    * p1 period1 start=entry+91: days = (entry+90)-(entry+50)+1 = 41 -> 41/365.25
    quietly sum cum_5 if id==1 & period==1, meanonly
    assert_approx `=r(mean)' `=41/365.25' 1e-6 "p1 period1 cum"
    * p2 (no episodes) cum_5 == 0 everywhere
    quietly sum cum_5 if id==2, meanonly
    assert_approx `=r(mean)' 0 1e-9 "p2 cum=0"
    restore
}
if _rc test_fail "rc=`=_rc'"
else test_pass

* ---- TEST 5: exit<=entry dropped; one-row-per-person enforced ----
run_test "guards: exit<=entry drop, dup id reject"
capture noisily {
    preserve
    * add a bad person with exit<=entry
    set obs 3
    replace id = 3 if _n==3
    replace entry = `e1' if _n==3
    replace exit  = `e1' if _n==3
    format entry exit %td
    tvpanel using `epi', id(id) entry(entry) exit(exit) exposure(eclass) reference(0) width(91)
    assert_exact `=r(n_persons)' 2 "exit<=entry person dropped"
    restore
}
if _rc test_fail "rc=`=_rc'"
else test_pass

run_test "duplicate-id master rejected"
preserve
clear
set obs 2
gen long id = 1
gen double entry = `e1'
gen double exit = `e1' + 200
capture tvpanel using `epi', id(id) entry(entry) exit(exit) exposure(eclass)
local got = _rc
restore
if `got' == 459 test_pass
else test_fail "expected rc 459, got `got'"

* ---- TEST 6: episode value label carried onto generate() ----
* Restore unconditionally: capture only the tvpanel call so an error path
* cannot strand the preserve (a swallowed error would skip an inline restore).
run_test "value label preserved on active-class var"
preserve
clear
set obs 1
gen long id = 1
gen double start = `e1' + 50
gen double stop  = `e1' + 1000
gen int eclass = 5
label define _tvp_lbl 0 "None" 5 "Rituximab"
label values eclass _tvp_lbl
format start stop %td
tempfile epi_lbl
save `epi_lbl'
clear
set obs 1
gen long id = 1
gen double entry = `e1'
gen double exit  = `e1' + 364
format entry exit %td
capture noisily tvpanel using `epi_lbl', id(id) entry(entry) exit(exit) exposure(eclass) reference(0) width(91)
local got = _rc
local msg ""
if `got' == 0 {
    * the label DEFINITION (not just the name) must survive to generate()
    local dec5 : label (tv_class) 5
    if "`dec5'" != "Rituximab" {
        local got 9
        local msg "value 5 decoded to |`dec5'| expected |Rituximab| (label definition lost)"
    }
}
restore
if `got' == 0 test_pass
else test_fail "`msg' rc=`got'"

* ---- TEST 7: datetime (%tc) episode dates rejected ----
run_test "guard: %tc episode dates rejected (rc 120)"
preserve
clear
set obs 1
gen long id = 1
gen double start = cofd(`e1' + 50)
gen double stop  = cofd(`e1' + 300)
gen int eclass = 5
format start stop %tc
tempfile epi_tc
save `epi_tc'
clear
set obs 1
gen long id = 1
gen double entry = `e1'
gen double exit  = `e1' + 364
format entry exit %td
capture tvpanel using `epi_tc', id(id) entry(entry) exit(exit) exposure(eclass) reference(0) width(91)
local got = _rc
restore
if `got' == 120 test_pass
else test_fail "expected rc 120, got `got'"

* ---- TEST 8: negative class + cumulative() rejected with clear rc ----
run_test "guard: negative class under cumulative (rc 198)"
preserve
clear
set obs 1
gen long id = 1
gen double start = `e1' + 10
gen double stop  = `e1' + 300
gen int eclass = -1
format start stop %td
tempfile epi_neg
save `epi_neg'
clear
set obs 1
gen long id = 1
gen double entry = `e1'
gen double exit  = `e1' + 364
format entry exit %td
capture tvpanel using `epi_neg', id(id) entry(entry) exit(exit) exposure(eclass) ///
    reference(0) width(91) cumulative(days)
local got = _rc
restore
if `got' == 198 test_pass
else test_fail "expected rc 198, got `got'"

* ---------------------------------------------------------------------------
display as text _n "{hline 60}"
display as result "tvpanel QA complete: PASS=$TVQA_PASS  FAIL=$TVQA_FAIL"
if $TVQA_FAIL > 0 {
    display as error "FAILED: $TVQA_FAILED"
}
display as text "{hline 60}"

log close
