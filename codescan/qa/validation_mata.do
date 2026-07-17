* validation_mata.do - Known-answer validation for Mata optimizations
* Verifies numerical equivalence with hand-computed expected values

clear all
version 16.0

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


local test_count = 0
local pass_count = 0
local fail_count = 0

* DATASET: 6 patients, 2 code vars, known dates
clear
input str4 pid str5 dx1 str5 dx2 double(visit_dt refdate)
"P001" "E110" "I10"  21915  21990
"P001" "E112" ""     21930  21990
"P002" "J440" ""     21900  21990
"P002" "E66"  "I10"  21950  21990
"P003" ""     "Z00"  21960  21990
"P003" "E115" ""     21985  21990
"P004" "I10"  ""     21800  21990
"P005" "E66"  "E110" 21970  21990
"P006" ""     ""     21940  21990
end
format visit_dt refdate %td

* Immutable fixture. Every block below reloads it, so no test can inherit
* indicator columns, a changed row order, or a collapsed dataset from the test
* before it -- the nine tests used to share one mutable copy in memory.
tempfile mfx
quietly save `mfx'

* Hand-computed expected values for the full dataset (no time window):
*   dm2 (E11):  P001 rows 1,2; P003 row 6; P005 row 8 → 4 rows, 3 patients
*   htn (I10):  P001 row 1; P002 row 4; P004 row 7    → 3 rows, 3 patients
*   copd (J44): P002 row 3                             → 1 row,  1 patient
*   obesity (E66): P002 row 4; P005 row 8              → 2 rows, 2 patients
*   P005 has E110 in dx2, should also match dm2


**# Test 1: Row-level match counts from Mata

local ++test_count
capture noisily {
    quietly use `mfx', clear
    codescan dx1 dx2, define(dm2 "E11" | htn "I10" | copd "J44" | obesity "E66") id(pid)
    assert r(N) == 9

    * Check summary matrix: column 1 = count, column 2 = prevalence
    * dm2: 4 matches out of 9 = 44.4%
    assert el(r(summary), 1, 1) == 4
    * htn: 3 matches
    assert el(r(summary), 2, 1) == 3
    * copd: 1 match
    assert el(r(summary), 3, 1) == 1
    * obesity: 2 matches
    assert el(r(summary), 4, 1) == 2
}
if _rc == 0 {
    display as result "  PASS: KA1 row-level match counts"
    local ++pass_count
}
else {
    display as error "  FAIL: KA1 row-level match counts (error `=_rc')"
    local ++fail_count
}


**# Test 2: Collapse patient-level counts

local ++test_count
capture noisily {
    quietly use `mfx', clear
    preserve
    codescan dx1 dx2, define(dm2 "E11" | htn "I10" | copd "J44" | obesity "E66") ///
        id(pid) collapse replace
    * Should have 6 unique patients
    assert r(N) == 6
    * dm2: P001, P003, P005 = 3 patients
    assert el(r(summary), 1, 1) == 3
    * htn: P001, P002, P004 = 3 patients
    assert el(r(summary), 2, 1) == 3
    * copd: P002 = 1 patient
    assert el(r(summary), 3, 1) == 1
    * obesity: P002, P005 = 2 patients
    assert el(r(summary), 4, 1) == 2
    restore
}
if _rc == 0 {
    display as result "  PASS: KA2 collapse patient-level counts"
    local ++pass_count
}
else {
    display as error "  FAIL: KA2 collapse patient-level counts (error `=_rc')"
    local ++fail_count
}


**# Test 3: Countmode row-level

local ++test_count
capture noisily {
    quietly use `mfx', clear
    codescan dx1 dx2, define(dm2 "E11" | htn "I10") id(pid) countmode replace
    * dm2 total matches: E110 in row1, E112 in row2, E115 in row6, E110 in row8 dx2 = 4
    * But P005 has E110 in dx2, so dm2 matches 4 rows, some with 1 match each
    *   row1: dx1=E110 (match), dx2=I10 (no) → count=1
    *   row2: dx1=E112 (match), dx2="" → count=1
    *   row6: dx1=E115 (match), dx2="" → count=1
    *   row8: dx1=E66 (no), dx2=E110 (match) → count=1
    * Total entries with dm2 > 0: 4 obs.  Total matches (sum): 4
    * The "Obs>0" column in countmode = 4
    * htn: row1 dx2=I10, row4 dx2=I10, row7 dx1=I10 → 3 obs, sum=3

    * Check: summary col 1 = total count, should be 4 for dm2
    assert el(r(summary), 1, 1) == 4
    assert el(r(summary), 2, 1) == 3
}
if _rc == 0 {
    display as result "  PASS: KA3 countmode match counts"
    local ++pass_count
}
else {
    display as error "  FAIL: KA3 countmode match counts (error `=_rc')"
    local ++fail_count
}


**# Test 4: Multi-window sensitivity (hand-computed)

local ++test_count
capture noisily {
    quietly use `mfx', clear
    * refdate = 21990 (approx 2020-02-24)
    * lookback(30): visit_dt >= 21960  → rows: 3(21960), 6(21985), 8(21970) = 3 rows
    *   P003 row3 (Z00, no match), P003 row6 (E115→dm2), P005 row8 (E66+E110→obesity+dm2)
    *   Patients in 30d window: P003, P005 = 2
    *   dm2 in 30d: P003(row6), P005(row8) = 2 patients
    *   htn in 30d: none = 0
    * lookback(90): visit_dt >= 21900 → all except P004(21800) = rows 1-6,8 = 8 rows
    *   Patients: P001,P002,P003,P005,P006 = 5
    *   dm2: P001(rows1,2), P003(row6), P005(row8) = 3 patients
    *   htn: P001(row1), P002(row4) = 2 patients
    * lookback(365): all rows = 9 rows, 6 patients
    *   dm2: P001, P003, P005 = 3
    *   htn: P001, P002, P004 = 3

    preserve
    codescan dx1 dx2, define(dm2 "E11" | htn "I10") ///
        id(pid) date(visit_dt) refdate(refdate) lookback(30 90 365) collapse replace

    * Check sensitivity matrix
    matrix list r(sensitivity)

    * dm2 30d: 2 patients out of 2 = 100%
    assert abs(el(r(sensitivity), 1, 1) - 100) < 0.1
    * dm2 90d: 3 patients out of 5 = 60%
    assert abs(el(r(sensitivity), 1, 2) - 60) < 0.1
    * dm2 365d: 3 patients out of 6 = 50%
    assert abs(el(r(sensitivity), 1, 3) - 50) < 0.1
    * htn 30d: 0 out of 2 = 0%
    assert abs(el(r(sensitivity), 2, 1) - 0) < 0.1
    * htn 90d: 2 out of 5 = 40%
    assert abs(el(r(sensitivity), 2, 2) - 40) < 0.1
    * htn 365d: 3 out of 6 = 50%
    assert abs(el(r(sensitivity), 2, 3) - 50) < 0.1
    restore
}
if _rc == 0 {
    display as result "  PASS: KA4 multi-window sensitivity"
    local ++pass_count
}
else {
    display as error "  FAIL: KA4 multi-window sensitivity (error `=_rc')"
    local ++fail_count
}


**# Test 5: Overlap detection correctness

local ++test_count
capture noisily {
    quietly use `mfx', clear
    * dm2 and htn overlap: P001 has both → 1 row (row1 has E110+I10)
    * dm2 and obesity overlap: P005 has both → 1 row (row8)
    * htn and obesity: P002 has both → 1 row (row4 has E66+I10)
    codescan dx1 dx2, define(dm2 "E11" | htn "I10" | copd "J44" | obesity "E66") ///
        id(pid) cooccurrence replace
    * Co-occurrence matrix diagonal = self-counts
    * dm2 diagonal: 4 rows
    assert el(r(cooccurrence), 1, 1) == 4
    * dm2-htn off-diagonal: 1 (row1 only — P001 has E110 in dx1 AND I10 in dx2)
    assert el(r(cooccurrence), 1, 2) == 1
}
if _rc == 0 {
    display as result "  PASS: KA5 co-occurrence overlap detection"
    local ++pass_count
}
else {
    display as error "  FAIL: KA5 co-occurrence overlap detection (error `=_rc')"
    local ++fail_count
}


**# Test 6: codescan_describe known answers

local ++test_count
capture noisily {
    quietly use `mfx', clear
    codescan_describe dx1 dx2
    * Non-empty codes: E110(row1,row8 dx2), E112(row2), J440(row3), E66(row4,row8 dx1),
    *   I10(row1 dx2, row4 dx2, row7 dx1), Z00(row5 dx2), E115(row6)
    * Frequencies: I10=3, E66=2, E110=2, E112=1, J440=1, Z00=1, E115=1
    * Total entries: 3+2+2+1+1+1+1 = 11
    * Unique codes: 7
    assert r(n_unique) == 7
    assert r(n_entries) == 11
    * Top code should be I10 with freq=3
    assert el(r(top_codes), 1, 1) == 3
}
if _rc == 0 {
    display as result "  PASS: KA6 describe known answers"
    local ++pass_count
}
else {
    display as error "  FAIL: KA6 describe known answers (error `=_rc')"
    local ++fail_count
}


**# Test 7: Detail mode per-variable tracking

local ++test_count
capture noisily {
    quietly use `mfx', clear
    codescan dx1 dx2, define(dm2 "E11" | htn "I10") id(pid) detail replace
    matrix list r(varcounts)
    * dm2 in dx1: rows 1,2,6 = 3 matches
    * dm2 in dx2: row 8 (E110) = 1 match
    * htn in dx1: row 7 = 1 match
    * htn in dx2: rows 1,4 = 2 matches
    assert el(r(varcounts), 1, 1) == 3
    assert el(r(varcounts), 1, 2) == 1
    assert el(r(varcounts), 2, 1) == 1
    assert el(r(varcounts), 2, 2) == 2
}
if _rc == 0 {
    display as result "  PASS: KA7 detail mode per-variable counts"
    local ++pass_count
}
else {
    display as error "  FAIL: KA7 detail mode per-variable counts (error `=_rc')"
    local ++fail_count
}


**# Test 8: Multi-window with merge (patient-level, row-level data preserved)

local ++test_count
capture noisily {
    quietly use `mfx', clear
    preserve
    codescan dx1 dx2, define(dm2 "E11" | htn "I10") ///
        id(pid) date(visit_dt) refdate(refdate) lookback(30 90) merge replace
    matrix list r(sensitivity)
    * 30d: 2 patients (P003, P005); dm2 in 30d: 2/2 = 100%; htn: 0/2 = 0%
    * 90d: 5 patients; dm2: 3/5 = 60%; htn: 2/5 = 40%
    assert abs(el(r(sensitivity), 1, 1) - 100) < 0.1
    assert abs(el(r(sensitivity), 2, 2) - 40) < 0.1
    restore
}
if _rc == 0 {
    display as result "  PASS: KA8 multi-window with merge"
    local ++pass_count
}
else {
    display as error "  FAIL: KA8 multi-window with merge (error `=_rc')"
    local ++fail_count
}



**# Settings hygiene

* This suite must not leak a session setting to whatever runs next.
local ++test_count
capture noisily {
    quietly use `mfx', clear
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

display ""
display as result "RESULT: validation_mata tests=`test_count' pass=`pass_count' fail=`fail_count'"
display as result "Test Results: `pass_count'/`test_count' passed, `fail_count' failed"

if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    exit 1
}
else {
    display as result "ALL TESTS PASSED"
}
