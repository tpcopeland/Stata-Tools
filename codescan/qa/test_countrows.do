* test_countrows.do - Tests for codescan countrows option
* Tests: 24
* Date: 2026-04-07

clear all
set seed 12345
version 16.0
set varabbrev off

local test_count = 0
local pass_count = 0
local fail_count = 0

* === Bootstrap ===
local qa_dir  "`c(pwd)'"
local pkg_dir "`qa_dir'/.."

* Guarded shared bootstrap. Sandboxes PLUS/PERSONAL under c(tmpdir), then
* installs this working copy. Running this suite standalone must not mutate
* the developer's real adopath, which the bare net install here used to do;
* only run_all.do was sandboxed. Idempotent, so the lane re-entering it is
* harmless.
quietly do "`qa_dir'/_codescan_qa_common.do"
_codescan_qa_bootstrap

* Session settings captured for the hygiene check at the end of this suite.
* A suite that leaves c(level) or c(varabbrev) changed silently alters every
* later suite in the lane -- the level-80/99 CI scenarios restored inside a
* captured block, so any assertion failure above them used to leak.
local _qa_level0 = c(level)
local _qa_va0 "`c(varabbrev)'"
local _qa_pwd0 "`c(pwd)'"



* ============================================================
* Helper: test data with multiple matches per patient per date
* ============================================================

capture program drop _make_countrows_data
program define _make_countrows_data
    clear
    set obs 11
    gen long pid = cond(_n <= 4, 1, cond(_n <= 7, 2, 3))
    gen str10 dx1 = ""
    gen str10 dx2 = ""
    gen double visit_dt = .
    gen double index_dt = mdy(1, 15, 2020)
    format visit_dt index_dt %td

    * Patient 1: 3 DM2 rows on 2 unique dates, 1 obesity row
    replace dx1 = "E110" if _n == 1
    replace dx2 = "E660" if _n == 1
    replace visit_dt = mdy(12, 1, 2019) if _n == 1

    replace dx1 = "E119" if _n == 2
    replace visit_dt = mdy(12, 1, 2019) if _n == 2

    replace dx1 = "E112" if _n == 3
    replace dx2 = "I10"  if _n == 3
    replace visit_dt = mdy(12, 15, 2019) if _n == 3

    replace dx1 = "Z00" if _n == 4
    replace visit_dt = mdy(1, 1, 2020) if _n == 4

    * Patient 2: no DM2
    replace dx1 = "I10"  if _n == 5
    replace visit_dt = mdy(12, 1, 2019) if _n == 5

    replace dx1 = "I13"  if _n == 6
    replace visit_dt = mdy(12, 15, 2019) if _n == 6

    replace dx1 = "Z00"  if _n == 7
    replace visit_dt = mdy(1, 1, 2020) if _n == 7

    * Patient 3: 3 DM2 rows (dx1+dx2) on 2 unique dates
    replace dx1 = "E110" if _n == 8
    replace dx2 = "E111" if _n == 8
    replace visit_dt = mdy(12, 1, 2019) if _n == 8

    replace dx1 = "E119" if _n == 9
    replace visit_dt = mdy(12, 1, 2019) if _n == 9

    replace dx1 = "E113" if _n == 10
    replace visit_dt = mdy(12, 15, 2019) if _n == 10

    replace dx1 = "Z00"  if _n == 11
    replace visit_dt = mdy(1, 1, 2020) if _n == 11

    * Summary:
    * pid=1: DM2 rows 1,2,3 (3 rows, 2 unique dates); obesity row 1 (1 row)
    * pid=2: 0 DM2 rows
    * pid=3: DM2 rows 8,9,10 (3 rows, 2 unique dates)
end


**# Basic countrows + collapse

* Test 1: countrows creates _nrows variables
local ++test_count
capture noisily {
    _make_countrows_data
    codescan dx1 dx2, define(dm2 "E11") id(pid) collapse countrows
    confirm variable dm2_nrows
    assert dm2_nrows != .
}
if _rc == 0 {
    display as result "  PASS: countrows creates _nrows variable"
    local ++pass_count
}
else {
    display as error "  FAIL: countrows creates _nrows variable (error `=_rc')"
    local ++fail_count
}

* Test 2: countrows values correct (collapse)
local ++test_count
capture noisily {
    _make_countrows_data
    codescan dx1 dx2, define(dm2 "E11") id(pid) collapse countrows
    sort pid
    assert dm2_nrows[1] == 3
    assert dm2_nrows[2] == 0
    assert dm2_nrows[3] == 3
}
if _rc == 0 {
    display as result "  PASS: countrows values correct (collapse)"
    local ++pass_count
}
else {
    display as error "  FAIL: countrows values correct (collapse) (error `=_rc')"
    local ++fail_count
}

* Test 3: countrows + multiple conditions
local ++test_count
capture noisily {
    _make_countrows_data
    codescan dx1 dx2, define(dm2 "E11" | obesity "E66") id(pid) collapse countrows
    confirm variable dm2_nrows
    confirm variable obesity_nrows
    sort pid
    assert obesity_nrows[1] == 1
    assert obesity_nrows[2] == 0
    assert obesity_nrows[3] == 0
}
if _rc == 0 {
    display as result "  PASS: countrows + multiple conditions"
    local ++pass_count
}
else {
    display as error "  FAIL: countrows + multiple conditions (error `=_rc')"
    local ++fail_count
}


**# countrows + merge

* Test 4: countrows with merge
local ++test_count
capture noisily {
    _make_countrows_data
    local orig_N = _N
    codescan dx1 dx2, define(dm2 "E11") id(pid) merge countrows
    confirm variable dm2_nrows
    assert _N == `orig_N'
    assert dm2_nrows == 3 if pid == 1
    assert dm2_nrows == 0 if pid == 2
    assert dm2_nrows == 3 if pid == 3
}
if _rc == 0 {
    display as result "  PASS: countrows with merge"
    local ++pass_count
}
else {
    display as error "  FAIL: countrows with merge (error `=_rc')"
    local ++fail_count
}

* Test 5: countrows merge preserves row count
local ++test_count
capture noisily {
    _make_countrows_data
    local orig_N = _N
    codescan dx1 dx2, define(dm2 "E11") id(pid) merge countrows
    assert _N == `orig_N'
}
if _rc == 0 {
    display as result "  PASS: countrows merge preserves row count"
    local ++pass_count
}
else {
    display as error "  FAIL: countrows merge preserves row count (error `=_rc')"
    local ++fail_count
}


**# Error handling

* Test 6: countrows without collapse/merge errors
local ++test_count
capture noisily {
    _make_countrows_data
    capture codescan dx1 dx2, define(dm2 "E11") id(pid) countrows
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: countrows without collapse/merge errors"
    local ++pass_count
}
else {
    display as error "  FAIL: countrows without collapse/merge errors (error `=_rc')"
    local ++fail_count
}

* Test 7: countrows works without date()
local ++test_count
capture noisily {
    _make_countrows_data
    codescan dx1 dx2, define(dm2 "E11") id(pid) collapse countrows
    confirm variable dm2_nrows
}
if _rc == 0 {
    display as result "  PASS: countrows works without date()"
    local ++pass_count
}
else {
    display as error "  FAIL: countrows works without date() (error `=_rc')"
    local ++fail_count
}


**# countrows vs countdate distinction

* Test 8: countrows != countdate (different values)
local ++test_count
capture noisily {
    _make_countrows_data
    codescan dx1 dx2, define(dm2 "E11") id(pid) date(visit_dt) ///
        collapse countrows countdate
    confirm variable dm2_nrows
    confirm variable dm2_count
    sort pid
    * Patient 1: 3 matching rows, 2 unique dates
    assert dm2_nrows[1] == 3
    assert dm2_count[1] == 2
    assert dm2_nrows[1] != dm2_count[1]
    * Patient 3: 3 matching rows, 2 unique dates
    assert dm2_nrows[3] == 3
    assert dm2_count[3] == 2
}
if _rc == 0 {
    display as result "  PASS: countrows != countdate (different values)"
    local ++pass_count
}
else {
    display as error "  FAIL: countrows != countdate (different values) (error `=_rc')"
    local ++fail_count
}

* Test 9: countrows + alldates (countrows independent of alldates)
local ++test_count
capture noisily {
    _make_countrows_data
    codescan dx1 dx2, define(dm2 "E11") id(pid) date(visit_dt) ///
        collapse alldates countrows
    confirm variable dm2_first
    confirm variable dm2_last
    confirm variable dm2_count
    confirm variable dm2_nrows
    sort pid
    assert dm2_nrows[1] == 3
    assert dm2_count[1] == 2
}
if _rc == 0 {
    display as result "  PASS: countrows + alldates together"
    local ++pass_count
}
else {
    display as error "  FAIL: countrows + alldates together (error `=_rc')"
    local ++fail_count
}


**# countrows + countmode

* Test 10: countrows with countmode (sums per-row counts)
local ++test_count
capture noisily {
    _make_countrows_data
    codescan dx1 dx2, define(dm2 "E11") id(pid) collapse countrows countmode
    sort pid
    * countmode row 8: dx1=E110 + dx2=E111 → 2 matches
    * countmode row 9: dx1=E119 → 1
    * countmode row 10: dx1=E113 → 1
    * Patient 3 total = 4 matches, nrows sums per-row counts = 4
    assert dm2[3] == 4
    assert dm2_nrows[3] == 4
}
if _rc == 0 {
    display as result "  PASS: countrows with countmode"
    local ++pass_count
}
else {
    display as error "  FAIL: countrows with countmode (error `=_rc')"
    local ++fail_count
}

* Test 11: countrows + countmode + merge
local ++test_count
capture noisily {
    _make_countrows_data
    codescan dx1 dx2, define(dm2 "E11") id(pid) merge countrows countmode
    assert dm2_nrows == 3 if pid == 1
    assert dm2_nrows == 0 if pid == 2
    assert dm2_nrows == 4 if pid == 3
}
if _rc == 0 {
    display as result "  PASS: countrows + countmode + merge"
    local ++pass_count
}
else {
    display as error "  FAIL: countrows + countmode + merge (error `=_rc')"
    local ++fail_count
}


**# Replace and variable existence

* Test 12: countrows with replace drops existing _nrows
local ++test_count
capture noisily {
    _make_countrows_data
    * First pass creates dm2_nrows
    codescan dx1 dx2, define(dm2 "E11") id(pid) collapse countrows
    sort pid
    assert dm2_nrows[1] == 3
    * Rebuild row-level data to re-collapse with replace
    _make_countrows_data
    gen long dm2_nrows = 999
    codescan dx1 dx2, define(dm2 "E11") id(pid) collapse countrows replace
    sort pid
    * replace should have overwritten the dummy value
    assert dm2_nrows[1] == 3
    assert dm2_nrows[1] != 999
}
if _rc == 0 {
    display as result "  PASS: countrows with replace"
    local ++pass_count
}
else {
    display as error "  FAIL: countrows with replace (error `=_rc')"
    local ++fail_count
}

* Test 13: _nrows variable exists error without replace
local ++test_count
capture noisily {
    _make_countrows_data
    gen long dm2_nrows = 0
    capture codescan dx1 dx2, define(dm2 "E11") id(pid) collapse countrows
    assert _rc == 110
}
if _rc == 0 {
    display as result "  PASS: _nrows exists error without replace"
    local ++pass_count
}
else {
    display as error "  FAIL: _nrows exists error without replace (error `=_rc')"
    local ++fail_count
}


**# Labels

* Test 14: countrows with labels
local ++test_count
capture noisily {
    _make_countrows_data
    codescan dx1 dx2, define(dm2 "E11") id(pid) collapse countrows ///
        label(dm2 "Diabetes Type 2")
    local lbl : variable label dm2_nrows
    assert `"`lbl'"' == "Diabetes Type 2 Row Count"
}
if _rc == 0 {
    display as result "  PASS: countrows labels"
    local ++pass_count
}
else {
    display as error "  FAIL: countrows labels (error `=_rc')"
    local ++fail_count
}

* Test 15: countrows + countdate labels both correct
local ++test_count
capture noisily {
    _make_countrows_data
    codescan dx1 dx2, define(dm2 "E11") id(pid) date(visit_dt) ///
        collapse countrows countdate label(dm2 "DM2")
    local lbl_nrows : variable label dm2_nrows
    local lbl_count : variable label dm2_count
    assert `"`lbl_nrows'"' == "DM2 Row Count"
    assert `"`lbl_count'"' == "DM2 Date Count"
}
if _rc == 0 {
    display as result "  PASS: countrows + countdate labels both correct"
    local ++pass_count
}
else {
    display as error "  FAIL: countrows + countdate labels both correct (error `=_rc')"
    local ++fail_count
}


**# Return values

* Test 16: countrows appears in r(newvars)
local ++test_count
capture noisily {
    _make_countrows_data
    codescan dx1 dx2, define(dm2 "E11") id(pid) collapse countrows
    local nv "`r(newvars)'"
    assert strpos("`nv'", "dm2_nrows") > 0
}
if _rc == 0 {
    display as result "  PASS: _nrows in r(newvars)"
    local ++pass_count
}
else {
    display as error "  FAIL: _nrows in r(newvars) (error `=_rc')"
    local ++fail_count
}

* Test 17: countrows + countdate both in r(newvars)
local ++test_count
capture noisily {
    _make_countrows_data
    codescan dx1 dx2, define(dm2 "E11") id(pid) date(visit_dt) ///
        collapse countrows countdate
    local nv "`r(newvars)'"
    assert strpos("`nv'", "dm2_nrows") > 0
    assert strpos("`nv'", "dm2_count") > 0
}
if _rc == 0 {
    display as result "  PASS: both _nrows and _count in r(newvars)"
    local ++pass_count
}
else {
    display as error "  FAIL: both _nrows and _count in r(newvars) (error `=_rc')"
    local ++fail_count
}

* Test 18: countrows r(newvars) with merge
local ++test_count
capture noisily {
    _make_countrows_data
    codescan dx1 dx2, define(dm2 "E11") id(pid) merge countrows
    local nv "`r(newvars)'"
    assert strpos("`nv'", "dm2_nrows") > 0
}
if _rc == 0 {
    display as result "  PASS: _nrows in r(newvars) with merge"
    local ++pass_count
}
else {
    display as error "  FAIL: _nrows in r(newvars) with merge (error `=_rc')"
    local ++fail_count
}


**# Data type checks

* Test 19: _nrows is long type after collapse
local ++test_count
capture noisily {
    _make_countrows_data
    codescan dx1 dx2, define(dm2 "E11") id(pid) collapse countrows
    local tp : type dm2_nrows
    assert "`tp'" == "long"
}
if _rc == 0 {
    display as result "  PASS: _nrows is long type (collapse)"
    local ++pass_count
}
else {
    display as error "  FAIL: _nrows is long type (collapse) (error `=_rc')"
    local ++fail_count
}

* Test 20: _nrows is long type after merge
local ++test_count
capture noisily {
    _make_countrows_data
    codescan dx1 dx2, define(dm2 "E11") id(pid) merge countrows
    local tp : type dm2_nrows
    assert "`tp'" == "long"
}
if _rc == 0 {
    display as result "  PASS: _nrows is long type (merge)"
    local ++pass_count
}
else {
    display as error "  FAIL: _nrows is long type (merge) (error `=_rc')"
    local ++fail_count
}


**# Edge cases

* Test 21: countrows with no matches — all zeros
local ++test_count
capture noisily {
    clear
    set obs 3
    gen long pid = cond(_n <= 2, 1, 2)
    gen str10 dx1 = "Z0" + string(_n)
    codescan dx1, define(dm2 "E11") id(pid) collapse countrows
    sort pid
    assert dm2_nrows[1] == 0
    assert dm2_nrows[2] == 0
}
if _rc == 0 {
    display as result "  PASS: countrows all zeros when no matches"
    local ++pass_count
}
else {
    display as error "  FAIL: countrows all zeros when no matches (error `=_rc')"
    local ++fail_count
}

* Test 22: countrows with single obs per patient
local ++test_count
capture noisily {
    clear
    set obs 3
    gen long pid = _n
    gen str10 dx1 = ""
    replace dx1 = "E110" if _n == 1
    replace dx1 = "E119" if _n == 2
    replace dx1 = "Z00"  if _n == 3
    codescan dx1, define(dm2 "E11") id(pid) collapse countrows
    sort pid
    assert dm2_nrows[1] == 1
    assert dm2_nrows[2] == 1
    assert dm2_nrows[3] == 0
}
if _rc == 0 {
    display as result "  PASS: countrows single obs per patient"
    local ++pass_count
}
else {
    display as error "  FAIL: countrows single obs per patient (error `=_rc')"
    local ++fail_count
}

* Test 23: countrows with generate() prefix
local ++test_count
capture noisily {
    _make_countrows_data
    codescan dx1 dx2, define(dm2 "E11") id(pid) collapse countrows ///
        generate(cs_)
    confirm variable cs_dm2_nrows
    sort pid
    assert cs_dm2_nrows[1] == 3
}
if _rc == 0 {
    display as result "  PASS: countrows with generate() prefix"
    local ++pass_count
}
else {
    display as error "  FAIL: countrows with generate() prefix (error `=_rc')"
    local ++fail_count
}

* Test 24: countrows + preserve — newvars cleared
local ++test_count
capture noisily {
    _make_countrows_data
    codescan dx1 dx2, define(dm2 "E11") id(pid) collapse countrows preserve
    local nv "`r(newvars)'"
    assert `"`nv'"' == ""
}
if _rc == 0 {
    display as result "  PASS: countrows + preserve clears r(newvars)"
    local ++pass_count
}
else {
    display as error "  FAIL: countrows + preserve clears r(newvars) (error `=_rc')"
    local ++fail_count
}


* ============================================================

**# Settings hygiene

* This suite must not leak a session setting to whatever runs next.
local ++test_count
capture noisily {
    assert c(level) == `_qa_level0'
    assert "`c(varabbrev)'" == "`_qa_va0'"
    assert "`c(pwd)'" == "`_qa_pwd0'"
}
if _rc == 0 {
    display as result "  PASS: no session setting leaked"
    local ++pass_count
}
else {
    display as error "  FAIL: session setting leaked (error `=_rc')"
    local ++fail_count
}


* Summary
* ============================================================

display ""
_codescan_qa_publish "test_countrows" `test_count' `pass_count' `fail_count'
display as result "RESULT: test_countrows tests=`test_count' pass=`pass_count' fail=`fail_count'"
display as result "Test Results: `pass_count'/`test_count' passed, `fail_count' failed"

if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    exit 1
}
else {
    display as result "ALL TESTS PASSED"
}
