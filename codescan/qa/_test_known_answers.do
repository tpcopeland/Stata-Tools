* Known-answer validation for Mata optimizations
* Verifies numerical equivalence with hand-computed expected values

capture ado uninstall codescan
net install codescan, from("/home/tpcopeland/Stata-Tools/codescan") replace

local failures = 0

* =====================================================================
* DATASET: 6 patients, 2 code vars, known dates
* =====================================================================
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

* Hand-computed expected values for the full dataset (no time window):
*   dm2 (E11):  P001 rows 1,2; P003 row 6; P005 row 8 → 4 rows, 3 patients
*   htn (I10):  P001 row 1; P002 row 4; P004 row 7    → 3 rows, 3 patients
*   copd (J44): P002 row 3                             → 1 row,  1 patient
*   obesity (E66): P002 row 4; P005 row 8              → 2 rows, 2 patients
*   P005 has E110 in dx2, should also match dm2

**# Test 1: Row-level match counts from Mata
display _n "=== KA1: Row-level match counts ==="
codescan dx1 dx2, define(dm2 "E11" | htn "I10" | copd "J44" | obesity "E66") id(pid)
assert r(N) == 9
local ka_fail = 0

* Check summary matrix: column 1 = count, column 2 = prevalence
* dm2: 4 matches out of 9 = 44.4%
if el(r(summary), 1, 1) != 4 {
    display as error "  dm2 count: expected 4, got " el(r(summary), 1, 1)
    local ka_fail = 1
}
* htn: 3 matches
if el(r(summary), 2, 1) != 3 {
    display as error "  htn count: expected 3, got " el(r(summary), 2, 1)
    local ka_fail = 1
}
* copd: 1 match
if el(r(summary), 3, 1) != 1 {
    display as error "  copd count: expected 1, got " el(r(summary), 3, 1)
    local ka_fail = 1
}
* obesity: 2 matches
if el(r(summary), 4, 1) != 2 {
    display as error "  obesity count: expected 2, got " el(r(summary), 4, 1)
    local ka_fail = 1
}
if `ka_fail' == 0 display as result "  PASS: row-level match counts"
else local failures = `failures' + 1

**# Test 2: Collapse patient-level counts
display _n "=== KA2: Collapse patient-level counts ==="
preserve
codescan dx1 dx2, define(dm2 "E11" | htn "I10" | copd "J44" | obesity "E66") ///
    id(pid) collapse replace
* Should have 6 unique patients
assert r(N) == 6
* dm2: P001, P003, P005 = 3 patients
if el(r(summary), 1, 1) != 3 {
    display as error "  dm2 patients: expected 3, got " el(r(summary), 1, 1)
    local failures = `failures' + 1
}
else display as result "  PASS: dm2 patient count = 3"
* htn: P001, P002, P004 = 3 patients
if el(r(summary), 2, 1) != 3 {
    display as error "  htn patients: expected 3, got " el(r(summary), 2, 1)
    local failures = `failures' + 1
}
else display as result "  PASS: htn patient count = 3"
* copd: P002 = 1 patient
if el(r(summary), 3, 1) != 1 {
    display as error "  copd patients: expected 1, got " el(r(summary), 3, 1)
    local failures = `failures' + 1
}
else display as result "  PASS: copd patient count = 1"
* obesity: P002, P005 = 2 patients
if el(r(summary), 4, 1) != 2 {
    display as error "  obesity patients: expected 2, got " el(r(summary), 4, 1)
    local failures = `failures' + 1
}
else display as result "  PASS: obesity patient count = 2"
restore

**# Test 3: Countmode row-level
display _n "=== KA3: Countmode match counts ==="
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
if el(r(summary), 1, 1) != 4 {
    display as error "  dm2 total: expected 4, got " el(r(summary), 1, 1)
    local failures = `failures' + 1
}
else display as result "  PASS: dm2 countmode total = 4"

if el(r(summary), 2, 1) != 3 {
    display as error "  htn total: expected 3, got " el(r(summary), 2, 1)
    local failures = `failures' + 1
}
else display as result "  PASS: htn countmode total = 3"

**# Test 4: Multi-window sensitivity (hand-computed)
display _n "=== KA4: Multi-window sensitivity ==="
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
local sens_fail = 0

* dm2 30d: 2 patients out of 2 = 100%
local val = el(r(sensitivity), 1, 1)
if abs(`val' - 100) > 0.1 {
    display as error "  dm2 30d: expected 100%, got `val'"
    local sens_fail = 1
}

* dm2 90d: 3 patients out of 5 = 60%
local val = el(r(sensitivity), 1, 2)
if abs(`val' - 60) > 0.1 {
    display as error "  dm2 90d: expected 60%, got `val'"
    local sens_fail = 1
}

* dm2 365d: 3 patients out of 6 = 50%
local val = el(r(sensitivity), 1, 3)
if abs(`val' - 50) > 0.1 {
    display as error "  dm2 365d: expected 50%, got `val'"
    local sens_fail = 1
}

* htn 30d: 0 out of 2 = 0%
local val = el(r(sensitivity), 2, 1)
if abs(`val' - 0) > 0.1 {
    display as error "  htn 30d: expected 0%, got `val'"
    local sens_fail = 1
}

* htn 90d: 2 out of 5 = 40%
local val = el(r(sensitivity), 2, 2)
if abs(`val' - 40) > 0.1 {
    display as error "  htn 90d: expected 40%, got `val'"
    local sens_fail = 1
}

* htn 365d: 3 out of 6 = 50%
local val = el(r(sensitivity), 2, 3)
if abs(`val' - 50) > 0.1 {
    display as error "  htn 365d: expected 50%, got `val'"
    local sens_fail = 1
}

if `sens_fail' == 0 display as result "  PASS: multi-window sensitivity matches hand-computed values"
else local failures = `failures' + 1
restore

**# Test 5: Overlap detection correctness
display _n "=== KA5: Overlap detection via co-occurrence ==="
* dm2 and htn overlap: P001 has both → 1 row (row1 has E110+I10)
* dm2 and obesity overlap: P005 has both → 1 row (row8)
* htn and obesity: P002 has both → 1 row (row4 has E66+I10)
codescan dx1 dx2, define(dm2 "E11" | htn "I10" | copd "J44" | obesity "E66") ///
    id(pid) cooccurrence replace
* Co-occurrence matrix diagonal = self-counts
* dm2 diagonal: 4 rows
if el(r(cooccurrence), 1, 1) != 4 {
    display as error "  dm2 self-count: expected 4, got " el(r(cooccurrence), 1, 1)
    local failures = `failures' + 1
}
else display as result "  PASS: dm2 self-count = 4"

* dm2-htn off-diagonal: 1 (row1 only — P001 has E110 in dx1 AND I10 in dx2)
if el(r(cooccurrence), 1, 2) != 1 {
    display as error "  dm2-htn overlap: expected 1, got " el(r(cooccurrence), 1, 2)
    local failures = `failures' + 1
}
else display as result "  PASS: dm2-htn overlap = 1"

**# Test 6: codescan_describe known answers
display _n "=== KA6: describe known answers ==="
codescan_describe dx1 dx2
* Non-empty codes: E110(row1,row8 dx2), E112(row2), J440(row3), E66(row4,row8 dx1),
*   I10(row1 dx2, row4 dx2, row7 dx1), Z00(row5 dx2), E115(row6)
* Frequencies: I10=3, E66=2, E110=2, E112=1, J440=1, Z00=1, E115=1
* Total entries: 3+2+2+1+1+1+1 = 11
* Unique codes: 7
if r(n_unique) != 7 {
    display as error "  unique codes: expected 7, got " r(n_unique)
    local failures = `failures' + 1
}
else display as result "  PASS: unique codes = 7"

if r(n_entries) != 11 {
    display as error "  total entries: expected 11, got " r(n_entries)
    local failures = `failures' + 1
}
else display as result "  PASS: total entries = 11"

* Top code should be I10 with freq=3
if el(r(top_codes), 1, 1) != 3 {
    display as error "  top code freq: expected 3, got " el(r(top_codes), 1, 1)
    local failures = `failures' + 1
}
else display as result "  PASS: top code (I10) freq = 3"

**# Test 7: Detail mode per-variable tracking
display _n "=== KA7: Detail mode per-variable match counts ==="
codescan dx1 dx2, define(dm2 "E11" | htn "I10") id(pid) detail replace
matrix list r(varcounts)
* dm2 in dx1: rows 1,2,6 = 3 matches
* dm2 in dx2: row 8 (E110) = 1 match
* htn in dx1: row 7 = 1 match
* htn in dx2: rows 1,4 = 2 matches
if el(r(varcounts), 1, 1) != 3 {
    display as error "  dm2 in dx1: expected 3, got " el(r(varcounts), 1, 1)
    local failures = `failures' + 1
}
else display as result "  PASS: dm2 in dx1 = 3"

if el(r(varcounts), 1, 2) != 1 {
    display as error "  dm2 in dx2: expected 1, got " el(r(varcounts), 1, 2)
    local failures = `failures' + 1
}
else display as result "  PASS: dm2 in dx2 = 1"

if el(r(varcounts), 2, 1) != 1 {
    display as error "  htn in dx1: expected 1, got " el(r(varcounts), 2, 1)
    local failures = `failures' + 1
}
else display as result "  PASS: htn in dx1 = 1"

if el(r(varcounts), 2, 2) != 2 {
    display as error "  htn in dx2: expected 2, got " el(r(varcounts), 2, 2)
    local failures = `failures' + 1
}
else display as result "  PASS: htn in dx2 = 2"

**# Test 8: Multi-window with merge (patient-level, row-level data preserved)
display _n "=== KA8: Multi-window with merge ==="
preserve
codescan dx1 dx2, define(dm2 "E11" | htn "I10") ///
    id(pid) date(visit_dt) refdate(refdate) lookback(30 90) merge replace
matrix list r(sensitivity)
* 30d: 2 patients (P003, P005); dm2 in 30d: 2/2 = 100%; htn: 0/2 = 0%
* 90d: 5 patients; dm2: 3/5 = 60%; htn: 2/5 = 40%
local val = el(r(sensitivity), 1, 1)
if abs(`val' - 100) > 0.1 {
    display as error "  merge dm2 30d: expected 100%, got `val'"
    local failures = `failures' + 1
}
else display as result "  PASS: merge dm2 30d = 100%"

local val = el(r(sensitivity), 2, 2)
if abs(`val' - 40) > 0.1 {
    display as error "  merge htn 90d: expected 40%, got `val'"
    local failures = `failures' + 1
}
else display as result "  PASS: merge htn 90d = 40%"
restore

* =====================================================================
* SUMMARY
* =====================================================================
display _n "=============================="
if `failures' == 0 {
    display as result "ALL KNOWN-ANSWER TESTS PASSED"
}
else {
    display as error "`failures' KNOWN-ANSWER TEST(S) FAILED"
    exit 9
}
