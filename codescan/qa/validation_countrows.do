* validation_countrows.do - Known-answer validation for codescan countrows
* Date: 2026-04-07

clear all
set seed 12345
version 16.0

local test_count = 0
local pass_count = 0
local fail_count = 0

* === Bootstrap ===
local qa_dir  "`c(pwd)'"
local pkg_dir "`qa_dir'/.."

capture ado uninstall codescan
quietly net install codescan, from("`pkg_dir'") replace


**# V1: Row-level invariant — countrows == manual count

* Test 1: Verify countrows matches manual row count (collapse)
local ++test_count
capture noisily {
    clear
    set obs 8
    gen long pid = cond(_n <= 4, 1, cond(_n <= 6, 2, 3))
    gen str10 dx1 = ""
    gen str10 dx2 = ""

    replace dx1 = "E110" if _n == 1
    replace dx2 = ""     if _n == 1
    replace dx1 = "E119" if _n == 2
    replace dx2 = "E660" if _n == 2
    replace dx1 = "I10"  if _n == 3
    replace dx1 = "E112" if _n == 4
    replace dx1 = "I10"  if _n == 5
    replace dx2 = "I13"  if _n == 5
    replace dx1 = "Z00"  if _n == 6
    replace dx1 = "E110" if _n == 7
    replace dx2 = "E111" if _n == 7
    replace dx1 = "E110" if _n == 8

    * Hand count — dm2 (E11*):
    *   pid=1: rows 1(E110), 2(E119), 4(E112) → 3
    *   pid=2: 0
    *   pid=3: rows 7(E110+E111), 8(E110) → 2
    * Hand count — obesity (E66*):
    *   pid=1: row 2(E660) → 1
    *   pid=2: 0
    *   pid=3: 0

    codescan dx1 dx2, define(dm2 "E11" | obesity "E66") id(pid) collapse countrows
    sort pid

    assert dm2_nrows[1]     == 3
    assert dm2_nrows[2]     == 0
    assert dm2_nrows[3]     == 2
    assert obesity_nrows[1] == 1
    assert obesity_nrows[2] == 0
    assert obesity_nrows[3] == 0
}
if _rc == 0 {
    display as result "  PASS: V1 countrows matches manual row count"
    local ++pass_count
}
else {
    display as error "  FAIL: V1 countrows matches manual row count (error `=_rc')"
    local ++fail_count
}


**# V2: countrows vs countdate — known distinct values

* Test 2: Multiple matches on same date → nrows > count
local ++test_count
capture noisily {
    clear
    set obs 6
    gen long pid = cond(_n <= 4, 1, 2)
    gen str10 dx1 = ""
    gen double visit_dt = .
    format visit_dt %td

    replace dx1 = "E110" if _n == 1
    replace visit_dt = mdy(12, 1, 2019) if _n == 1
    replace dx1 = "E119" if _n == 2
    replace visit_dt = mdy(12, 1, 2019) if _n == 2
    replace dx1 = "E112" if _n == 3
    replace visit_dt = mdy(12, 1, 2019) if _n == 3
    replace dx1 = "E113" if _n == 4
    replace visit_dt = mdy(12, 15, 2019) if _n == 4
    replace dx1 = "E110" if _n == 5
    replace visit_dt = mdy(12, 1, 2019) if _n == 5
    replace dx1 = "Z00"  if _n == 6
    replace visit_dt = mdy(12, 15, 2019) if _n == 6

    * Hand count:
    *   pid=1: 4 matching rows, 2 unique dates (3×Dec1, 1×Dec15)
    *   pid=2: 1 matching row, 1 unique date

    codescan dx1, define(dm2 "E11") id(pid) date(visit_dt) ///
        collapse countrows countdate
    sort pid

    assert dm2_nrows[1] == 4
    assert dm2_count[1] == 2
    assert dm2_nrows[1] > dm2_count[1]

    assert dm2_nrows[2] == 1
    assert dm2_count[2] == 1
}
if _rc == 0 {
    display as result "  PASS: V2 countrows > countdate with same-date matches"
    local ++pass_count
}
else {
    display as error "  FAIL: V2 countrows > countdate with same-date matches (error `=_rc')"
    local ++fail_count
}


**# V3: countrows invariant — nrows >= countdate always

* Test 3: nrows >= count for every patient
local ++test_count
capture noisily {
    clear
    set obs 8
    gen long pid = cond(_n <= 3, 1, cond(_n <= 4, 2, 3))
    gen str10 dx1 = ""
    gen double visit_dt = .
    format visit_dt %td

    replace dx1 = "E110" if _n == 1
    replace visit_dt = mdy(12, 1, 2019) if _n == 1
    replace dx1 = "E119" if _n == 2
    replace visit_dt = mdy(12, 1, 2019) if _n == 2
    replace dx1 = "E112" if _n == 3
    replace visit_dt = mdy(12, 15, 2019) if _n == 3
    replace dx1 = "E110" if _n == 4
    replace visit_dt = mdy(12, 1, 2019) if _n == 4
    replace dx1 = "Z00"  if _n == 5
    replace visit_dt = mdy(12, 1, 2019) if _n == 5
    replace dx1 = "E110" if _n == 6
    replace visit_dt = mdy(12, 15, 2019) if _n == 6
    replace dx1 = "E119" if _n == 7
    replace visit_dt = mdy(12, 15, 2019) if _n == 7
    replace dx1 = "E112" if _n == 8
    replace visit_dt = mdy(1, 1, 2020) if _n == 8

    codescan dx1, define(dm2 "E11") id(pid) date(visit_dt) ///
        collapse countrows countdate
    sort pid

    * Invariant: for every patient, nrows >= count
    assert dm2_nrows >= dm2_count
}
if _rc == 0 {
    display as result "  PASS: V3 invariant nrows >= countdate"
    local ++pass_count
}
else {
    display as error "  FAIL: V3 invariant nrows >= countdate (error `=_rc')"
    local ++fail_count
}


**# V4: countrows + countmode — manual per-row count sums

* Test 4: countmode nrows = sum of per-row match counts
local ++test_count
capture noisily {
    clear
    set obs 5
    gen long pid = cond(_n <= 3, 1, 2)
    gen str10 dx1 = ""
    gen str10 dx2 = ""
    gen str10 dx3 = ""

    replace dx1 = "E110" if _n == 1
    replace dx2 = "E119" if _n == 1
    replace dx3 = "E112" if _n == 1
    replace dx1 = "E113" if _n == 2
    replace dx1 = "Z00"  if _n == 3
    replace dx1 = "E110" if _n == 4
    replace dx1 = "Z00"  if _n == 5

    * countmode row counts (matches across dx1-dx3):
    *   pid=1 row 1: 3 matches (E110+E119+E112)
    *   pid=1 row 2: 1 match (E113)
    *   pid=1 row 3: 0
    *   pid=1 total = 4
    *   pid=2 row 4: 1 match (E110)
    *   pid=2 row 5: 0
    *   pid=2 total = 1

    codescan dx1 dx2 dx3, define(dm2 "E11") id(pid) collapse countrows countmode
    sort pid

    assert dm2[1]       == 4
    assert dm2_nrows[1] == 4
    assert dm2[2]       == 1
    assert dm2_nrows[2] == 1
}
if _rc == 0 {
    display as result "  PASS: V4 countmode nrows = sum of per-row counts"
    local ++pass_count
}
else {
    display as error "  FAIL: V4 countmode nrows = sum of per-row counts (error `=_rc')"
    local ++fail_count
}


**# V5: countrows without countmode — binary row presence

* Test 5: Without countmode, nrows counts rows with any match (not total matches)
local ++test_count
capture noisily {
    clear
    set obs 5
    gen long pid = cond(_n <= 3, 1, 2)
    gen str10 dx1 = ""
    gen str10 dx2 = ""
    gen str10 dx3 = ""

    replace dx1 = "E110" if _n == 1
    replace dx2 = "E119" if _n == 1
    replace dx3 = "E112" if _n == 1
    replace dx1 = "E113" if _n == 2
    replace dx1 = "Z00"  if _n == 3
    replace dx1 = "E110" if _n == 4
    replace dx1 = "Z00"  if _n == 5

    * Without countmode, each row is 0/1:
    *   pid=1 row 1: match → 1
    *   pid=1 row 2: match → 1
    *   pid=1 row 3: no match → 0
    *   pid=1 total = 2
    *   pid=2 row 4: match → 1
    *   pid=2 row 5: 0
    *   pid=2 total = 1

    codescan dx1 dx2 dx3, define(dm2 "E11") id(pid) collapse countrows
    sort pid

    assert dm2_nrows[1] == 2
    assert dm2_nrows[2] == 1
}
if _rc == 0 {
    display as result "  PASS: V5 nrows counts rows-with-any-match (binary)"
    local ++pass_count
}
else {
    display as error "  FAIL: V5 nrows counts rows-with-any-match (binary) (error `=_rc')"
    local ++fail_count
}


**# V6: countrows merge broadcast — patient-level values

* Test 6: After merge, all rows for a patient have same _nrows
local ++test_count
capture noisily {
    clear
    set obs 7
    gen long pid = cond(_n <= 3, 1, 2)
    gen str10 dx1 = ""

    replace dx1 = "E110" if _n == 1
    replace dx1 = "E119" if _n == 2
    replace dx1 = "Z00"  if _n == 3
    replace dx1 = "E110" if _n == 4
    replace dx1 = "Z00"  if _n == 5
    replace dx1 = "Z01"  if _n == 6
    replace dx1 = "Z02"  if _n == 7

    * pid=1: 2 matching rows → nrows=2, broadcast to 3 rows
    * pid=2: 1 matching row  → nrows=1, broadcast to 4 rows

    codescan dx1, define(dm2 "E11") id(pid) merge countrows

    assert dm2_nrows == 2 if pid == 1
    assert dm2_nrows == 1 if pid == 2
}
if _rc == 0 {
    display as result "  PASS: V6 merge broadcasts patient-level nrows"
    local ++pass_count
}
else {
    display as error "  FAIL: V6 merge broadcasts patient-level nrows (error `=_rc')"
    local ++fail_count
}


**# V7: Sanity bounds

* Test 7: nrows >= 0 and nrows <= total rows per patient
local ++test_count
capture noisily {
    clear
    set obs 7
    gen long pid = cond(_n <= 4, 1, cond(_n <= 6, 2, 3))
    gen str10 dx1 = ""

    replace dx1 = "E110" if _n == 1
    replace dx1 = "E119" if _n == 2
    replace dx1 = "E112" if _n == 3
    replace dx1 = "Z00"  if _n == 4
    replace dx1 = "Z00"  if _n == 5
    replace dx1 = "Z01"  if _n == 6
    replace dx1 = "E110" if _n == 7

    * pid=1: 4 rows, 3 match
    * pid=2: 2 rows, 0 match
    * pid=3: 1 row, 1 match

    bysort pid: gen long _total_rows = _N

    codescan dx1, define(dm2 "E11") id(pid) merge countrows

    assert dm2_nrows >= 0
    assert dm2_nrows <= _total_rows
}
if _rc == 0 {
    display as result "  PASS: V7 sanity: 0 <= nrows <= total rows per patient"
    local ++pass_count
}
else {
    display as error "  FAIL: V7 sanity: 0 <= nrows <= total rows per patient (error `=_rc')"
    local ++fail_count
}


**# V8: Conservation — sum of _nrows equals total matching rows

* Test 8: Sum of nrows across patients = total matching rows in data
local ++test_count
capture noisily {
    clear
    set obs 7
    gen long pid = cond(_n <= 3, 1, cond(_n <= 5, 2, 3))
    gen str10 dx1 = ""

    replace dx1 = "E110" if _n == 1
    replace dx1 = "E119" if _n == 2
    replace dx1 = "Z00"  if _n == 3
    replace dx1 = "E110" if _n == 4
    replace dx1 = "Z00"  if _n == 5
    replace dx1 = "Z00"  if _n == 6
    replace dx1 = "Z01"  if _n == 7

    * Total matching rows: 1,2,4 → 3
    * After collapse: pid=1 nrows=2, pid=2 nrows=1, pid=3 nrows=0
    * Sum = 3

    codescan dx1, define(dm2 "E11") id(pid) collapse countrows
    quietly summarize dm2_nrows
    assert r(sum) == 3
}
if _rc == 0 {
    display as result "  PASS: V8 conservation: sum(nrows) = total matching rows"
    local ++pass_count
}
else {
    display as error "  FAIL: V8 conservation: sum(nrows) = total matching rows (error `=_rc')"
    local ++fail_count
}


* ============================================================
* Summary
* ============================================================

display ""
display as result "RESULT: validation_countrows tests=`test_count' pass=`pass_count' fail=`fail_count'"
display as result "Test Results: `pass_count'/`test_count' passed, `fail_count' failed"

if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    exit 1
}
else {
    display as result "ALL TESTS PASSED"
}
