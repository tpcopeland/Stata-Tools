* test_finegray_horizon_precision.do
* Explicit CIF horizons are used AS TYPED (FG-A01, 2026-09-04 error report).
*
*   Through 1.3.0 attime() and timepoints() were validated with numlist and the
*   original text replaced by r(numlist), which is rounded to nine significant
*   digits.  attime(.1000000000000001) became .1: the lookup then found no
*   cause event at or before .1, posted CIF = 0 with r(table)[1,1] = .1 and a
*   note that the time precedes the first event, all at rc 0, while the
*   default grid and predict at the same time returned 1 - exp(-.5).  Distinct
*   horizons that round to the same text collapsed to one row.
*
*   Fixture: 200 balanced subjects, 100 cause-1 events at exactly
*   .1000000000000001 and 100 competing events at 1.  The fitted coefficient
*   is 0 and the single Breslow increment is 100/200, so the CIF at the event
*   is 1 - exp(-.5) = .39346934028736658 for any profile.  Every check below
*   is a known answer at the event, one ulp before it, and one ulp after it.
*
*   HP-1..HP-6, HP-8 and HP-10 fail on the pre-fix build; HP-7, HP-9, HP-11
*   and HP-12 pin behaviour that must survive the fix.
clear all
set varabbrev off
version 16.0

capture log close _all
log using "test_finegray_horizon_precision.log", replace name(_fghp)

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
capture ado uninstall finegray
quietly net install finegray, from("`pkg_dir'") replace

local test_count = 0
local pass_count = 0
local fail_count = 0

capture program drop _mk_hp
program define _mk_hp
    version 16.0
    clear
    quietly set obs 200
    gen long id = _n
    gen double x = mod(_n, 2)
    gen double t = cond(_n <= 100, .1000000000000001, 1)
    gen byte status = cond(_n <= 100, 1, 2)
    quietly stset t, failure(status==1 2) id(id)
    quietly finegray x, compete(status) cause(1) nolog
end

local tev = .1000000000000001
local tbefore = .0999999999999999
local tafter = .1000000000000002
local cif_known = 1 - exp(-.5)

* HP-1: attime() at the exact event time returns the event's CIF, and
* r(table) carries the time as typed.
local ++test_count
capture noisily {
    _mk_hp
    finegray_cif, at(x=0) attime(.1000000000000001) nograph
    tempname T
    matrix `T' = r(table)
    assert rowsof(`T') == 1
    assert `T'[1,1] == `tev'
    assert !missing(`T'[1,2], `T'[1,3])
    assert !missing(`T'[1,2], `cif_known')
    assert reldif(`T'[1,2], `cif_known') < 1e-12
    assert `T'[1,3] > 0
}
if _rc == 0 {
    display as result "  PASS: HP-1 attime() at the tied event returns 1 - exp(-.5) at the typed time"
    local ++pass_count
}
else {
    display as error "  FAIL: HP-1 attime() at the tied event (rc=`=_rc')"
    local ++fail_count
}

* HP-2: timepoints() at the exact event time.
local ++test_count
capture noisily {
    _mk_hp
    finegray_cif, at(x=0) timepoints(.1000000000000001) nograph
    tempname T
    matrix `T' = r(table)
    assert rowsof(`T') == 1
    assert `T'[1,1] == `tev'
    assert !missing(`T'[1,2], `T'[1,3])
    assert !missing(`T'[1,2], `cif_known')
    assert reldif(`T'[1,2], `cif_known') < 1e-12
    assert `T'[1,3] > 0
}
if _rc == 0 {
    display as result "  PASS: HP-2 timepoints() at the tied event returns 1 - exp(-.5) at the typed time"
    local ++pass_count
}
else {
    display as error "  FAIL: HP-2 timepoints() at the tied event (rc=`=_rc')"
    local ++fail_count
}

* HP-3: one ulp BEFORE the event the CIF is exactly 0, and the time is kept.
local ++test_count
capture noisily {
    _mk_hp
    finegray_cif, at(x=0) attime(.0999999999999999) nograph
    tempname T
    matrix `T' = r(table)
    assert rowsof(`T') == 1
    assert `T'[1,1] == `tbefore'
    assert `T'[1,1] < `tev'
    assert !missing(`T'[1,2], `T'[1,3])
    assert `T'[1,2] == 0
    assert `T'[1,3] == 0
    finegray_cif, at(x=0) timepoints(.0999999999999999) nograph
    matrix `T' = r(table)
    assert `T'[1,1] == `tbefore'
    assert !missing(`T'[1,2])
    assert `T'[1,2] == 0
}
if _rc == 0 {
    display as result "  PASS: HP-3 one ulp before the event: CIF exactly 0 at the typed time"
    local ++pass_count
}
else {
    display as error "  FAIL: HP-3 one ulp before the event (rc=`=_rc')"
    local ++fail_count
}

* HP-4: one ulp AFTER the event the CIF is the event's value.
local ++test_count
capture noisily {
    _mk_hp
    finegray_cif, at(x=0) attime(.1000000000000002) nograph
    tempname T
    matrix `T' = r(table)
    assert `T'[1,1] == `tafter'
    assert `T'[1,1] > `tev'
    assert !missing(`T'[1,2], `T'[1,3])
    assert !missing(`T'[1,2], `cif_known')
    assert reldif(`T'[1,2], `cif_known') < 1e-12
    finegray_cif, at(x=0) timepoints(.1000000000000002) nograph
    matrix `T' = r(table)
    assert `T'[1,1] == `tafter'
    assert !missing(`T'[1,2])
    assert !missing(`T'[1,2], `cif_known')
    assert reldif(`T'[1,2], `cif_known') < 1e-12
}
if _rc == 0 {
    display as result "  PASS: HP-4 one ulp after the event: CIF = 1 - exp(-.5) at the typed time"
    local ++pass_count
}
else {
    display as error "  FAIL: HP-4 one ulp after the event (rc=`=_rc')"
    local ++fail_count
}

* HP-5: two horizons that round to the same nine digits are two rows, in
* value order, each with its own answer.
local ++test_count
capture noisily {
    _mk_hp
    finegray_cif, at(x=0) attime(.1000000000000001 .1) nograph
    tempname T
    matrix `T' = r(table)
    assert rowsof(`T') == 2
    assert `T'[1,1] == .1
    assert `T'[2,1] == `tev'
    assert !missing(`T'[1,2], `T'[2,2])
    assert `T'[1,2] == 0
    assert !missing(`T'[2,2], `cif_known')
    assert reldif(`T'[2,2], `cif_known') < 1e-12
}
if _rc == 0 {
    display as result "  PASS: HP-5 attime(.1000000000000001 .1) is two rows, sorted by value"
    local ++pass_count
}
else {
    display as error "  FAIL: HP-5 two horizons one ulp apart (rc=`=_rc')"
    local ++fail_count
}

* HP-6: the same pair through timepoints().
local ++test_count
capture noisily {
    _mk_hp
    finegray_cif, at(x=0) timepoints(.1 .1000000000000001) nograph
    tempname T
    matrix `T' = r(table)
    assert rowsof(`T') == 2
    assert `T'[1,1] == .1
    assert `T'[2,1] == `tev'
    assert !missing(`T'[1,2], `T'[2,2])
    assert `T'[1,2] == 0
    assert !missing(`T'[2,2], `cif_known')
    assert reldif(`T'[2,2], `cif_known') < 1e-12
}
if _rc == 0 {
    display as result "  PASS: HP-6 timepoints(.1 .1000000000000001) is two rows"
    local ++pass_count
}
else {
    display as error "  FAIL: HP-6 timepoints() pair one ulp apart (rc=`=_rc')"
    local ++fail_count
}

* HP-7: duplicates are still collapsed, and BY VALUE: 1, 1.0 and 1 are one
* row, and so are .1 and 0.1 (string comparison would keep both).
local ++test_count
capture noisily {
    _mk_hp
    finegray_cif, at(x=0) attime(1 1.0 2 1) nograph
    tempname T
    matrix `T' = r(table)
    assert rowsof(`T') == 2
    assert `T'[1,1] == 1
    assert `T'[2,1] == 2
    finegray_cif, at(x=0) attime(0.1 .1) nograph
    matrix `T' = r(table)
    assert rowsof(`T') == 1
    assert `T'[1,1] == .1
}
if _rc == 0 {
    display as result "  PASS: HP-7 repeated horizons collapse by value"
    local ++pass_count
}
else {
    display as error "  FAIL: HP-7 duplicate collapse (rc=`=_rc')"
    local ++fail_count
}

* HP-8: a literal mixed with a one-token range keeps its precision; the
* range is expanded and the whole list is sorted by value.
local ++test_count
capture noisily {
    _mk_hp
    finegray_cif, at(x=0) attime(2(1)3 .1000000000000001 1) nograph
    tempname T
    matrix `T' = r(table)
    assert rowsof(`T') == 4
    assert `T'[1,1] == `tev'
    assert `T'[2,1] == 1
    assert `T'[3,1] == 2
    assert `T'[4,1] == 3
    assert !missing(`T'[1,2], `T'[4,2])
    assert !missing(`T'[1,2], `cif_known')
    assert reldif(`T'[1,2], `cif_known') < 1e-12
    assert !missing(`T'[4,2], `cif_known')
    assert reldif(`T'[4,2], `cif_known') < 1e-12
}
if _rc == 0 {
    display as result "  PASS: HP-8 literal beside a range keeps its precision and value order"
    local ++pass_count
}
else {
    display as error "  FAIL: HP-8 mixed literal and range (rc=`=_rc')"
    local ++fail_count
}

* HP-9: the multi-token numlist forms still expand (taken from numlist whole).
local ++test_count
capture noisily {
    _mk_hp
    finegray_cif, at(x=0) timepoints(1 2 to 4) nograph
    tempname T
    matrix `T' = r(table)
    assert rowsof(`T') == 4
    assert `T'[1,1] == 1 & `T'[2,1] == 2 & `T'[3,1] == 3 & `T'[4,1] == 4
    finegray_cif, at(x=0) attime(0(.05).2) nograph
    matrix `T' = r(table)
    assert rowsof(`T') == 5
    assert !missing(`T'[3,2], `T'[4,2])
    assert `T'[3,1] == .1
    assert `T'[3,2] == 0
    assert !missing(`T'[4,2], `cif_known')
    assert reldif(`T'[4,2], `cif_known') < 1e-12
}
if _rc == 0 {
    display as result "  PASS: HP-9 `to' and a(b)c range forms still expand"
    local ++pass_count
}
else {
    display as error "  FAIL: HP-9 range forms (rc=`=_rc')"
    local ++fail_count
}

* HP-10: an unsorted literal list is sorted by value with every token intact.
local ++test_count
capture noisily {
    _mk_hp
    finegray_cif, at(x=0) attime(3 .1000000000000001 1 .0999999999999999) nograph
    tempname T
    matrix `T' = r(table)
    assert rowsof(`T') == 4
    assert `T'[1,1] == `tbefore'
    assert `T'[2,1] == `tev'
    assert `T'[3,1] == 1
    assert `T'[4,1] == 3
    assert !missing(`T'[1,2], `T'[2,2])
    assert `T'[1,2] == 0
    assert !missing(`T'[2,2], `cif_known')
    assert reldif(`T'[2,2], `cif_known') < 1e-12
}
if _rc == 0 {
    display as result "  PASS: HP-10 literal list sorted by value, tokens intact"
    local ++pass_count
}
else {
    display as error "  FAIL: HP-10 sort by value (rc=`=_rc')"
    local ++fail_count
}

* HP-11: positive controls that never went through numlist -- the default
* grid and predict at the event time -- give the same known answer, so the
* explicit-horizon result is compared to something the fix did not touch.
local ++test_count
capture noisily {
    _mk_hp
    finegray_cif, at(x=0) nograph
    tempname T
    matrix `T' = r(table)
    assert `T'[1,1] == `tev'
    assert !missing(`T'[1,2])
    assert !missing(`T'[1,2], `cif_known')
    assert reldif(`T'[1,2], `cif_known') < 1e-12
    gen double h = `tev'
    finegray_predict double p_ev, cif timevar(h)
    assert !missing(p_ev) if e(sample)
    assert !missing(p_ev, `cif_known') if e(sample)
    assert reldif(p_ev, `cif_known') < 1e-12 if e(sample)
    finegray_cif, at(x=0) attime(.1000000000000001) nograph
    tempname T2
    matrix `T2' = r(table)
    assert !missing(`T2'[1,2])
    assert `T2'[1,2] == `T'[1,2]
}
if _rc == 0 {
    display as result "  PASS: HP-11 default grid, predict and attime() agree at the event"
    local ++pass_count
}
else {
    display as error "  FAIL: HP-11 positive controls (rc=`=_rc')"
    local ++fail_count
}

* HP-12: validation is unchanged: a negative or non-numeric horizon is still
* refused with rc 198 and nothing is posted.
local ++test_count
capture noisily {
    _mk_hp
    capture finegray_cif, at(x=0) attime(-1) nograph
    assert _rc == 198
    capture finegray_cif, at(x=0) attime(1 abc) nograph
    assert _rc == 198
    capture finegray_cif, at(x=0) timepoints(1 .) nograph
    assert _rc == 198
    capture finegray_cif, at(x=0) attime(1 -.1000000000000001) nograph
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: HP-12 invalid horizons still refused (rc 198)"
    local ++pass_count
}
else {
    display as error "  FAIL: HP-12 validation (rc=`=_rc')"
    local ++fail_count
}

**# Summary
display as text _newline ///
    "RESULT: test_finegray_horizon_precision tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    log close _fghp
    exit 1
}
display as result "ALL TESTS PASSED"
log close _fghp
