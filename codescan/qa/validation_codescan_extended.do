* validation_codescan_extended.do - Extended correctness validation for codescan
* Date: 2026-07-17
*
* Split from validation_codescan.do at the V13 boundary for audit finding Q8.
* Test bodies are copied verbatim; only this scaffold and the final hygiene
* assertion are new.

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
* installs this working copy. Idempotent, so the lane re-entering it is harmless.
quietly do "`qa_dir'/_codescan_qa_common.do"
_codescan_qa_bootstrap

* Session settings captured for the hygiene check at the end of this suite.
local _qa_level0 = c(level)
local _qa_va0 "`c(varabbrev)'"
local _qa_pwd0 "`c(pwd)'"



**# Exclusion Pattern Correctness

**## V14 — Exclusion removes only targeted codes (hand-verified)
* Define: dm2 "E11" ~ "E116"
* E110 → match inclusion, no exclusion match → dm2=1
* E116 → match inclusion, match exclusion → dm2=0
* E1160 → match inclusion (E11 prefix), match exclusion (E116 prefix) → dm2=0
* E117 → match inclusion, no exclusion match → dm2=1
* I10  → no inclusion match → dm2=0
local ++test_count
capture noisily {
    clear
    input str10 code byte expected
    "E110"  1
    "E116"  0
    "E1160" 0
    "E117"  1
    "E119"  1
    "I10"   0
    "E11"   1
    ""      0
    end

    codescan code, define(dm2 "E11" ~ "E116")

    forvalues i = 1/`=_N' {
        assert dm2[`i'] == expected[`i']
    }
}
if _rc == 0 {
    display as result "  PASS: V14 - Exclusion pattern correctness (hand-verified)"
    local ++pass_count
}
else {
    display as error "  FAIL: V14 - Exclusion pattern correctness (error `=_rc')"
    local ++fail_count
}


**# Nocase Known-Answer Validation

**## V15 — nocase matches all case variants
local ++test_count
capture noisily {
    clear
    input str10 code byte expected
    "E110"  1
    "e110"  1
    "e11"   1
    "E11"   1
    "e119"  1
    "E119"  1
    "i10"   0
    "I10"   0
    ""      0
    end

    codescan code, define(dm2 "E11") nocase

    forvalues i = 1/`=_N' {
        assert dm2[`i'] == expected[`i']
    }
}
if _rc == 0 {
    display as result "  PASS: V15 - nocase known-answer validation"
    local ++pass_count
}
else {
    display as error "  FAIL: V15 - nocase known-answer (error `=_rc')"
    local ++fail_count
}


**# Nodots Known-Answer Validation

**## V16 — nodots strips dots before matching
* Pattern "E110" with nodots:
* "E11.0" → stripped to "E110" → matches ^(E110) → 1
* "E110"  → already "E110" → matches → 1
* "E11.1" → "E111" → no match for ^(E110) → 0
* "E.110" → "E110" → matches → 1
local ++test_count
capture noisily {
    clear
    input str10 code byte expected
    "E11.0" 1
    "E110"  1
    "E11.1" 0
    "E.110" 1
    "I10.1" 0
    ""      0
    end

    codescan code, define(dm2 "E110") nodots

    forvalues i = 1/`=_N' {
        assert dm2[`i'] == expected[`i']
    }
}
if _rc == 0 {
    display as result "  PASS: V16 - nodots known-answer validation"
    local ++pass_count
}
else {
    display as error "  FAIL: V16 - nodots known-answer (error `=_rc')"
    local ++fail_count
}


**# Countmode Row-Level Validation

**## V17 — countmode counts per row (hand-verified)
* Row 1: dx1=E110, dx2=E119, dx3="" → 2 matches
* Row 2: dx1=E110, dx2=Z00,  dx3="" → 1 match
* Row 3: dx1=Z00,  dx2=Z01,  dx3="" → 0 matches
* Row 4: dx1=E11,  dx2=E11,  dx3=E11 → 3 matches
local ++test_count
capture noisily {
    clear
    input str10 dx1 str10 dx2 str10 dx3 byte expected
    "E110" "E119" ""    2
    "E110" "Z00"  ""    1
    "Z00"  "Z01"  ""    0
    "E11"  "E11"  "E11" 3
    end

    codescan dx1-dx3, define(dm2 "E11") countmode

    forvalues i = 1/`=_N' {
        assert dm2[`i'] == expected[`i']
    }
}
if _rc == 0 {
    display as result "  PASS: V17 - countmode row-level (hand-verified)"
    local ++pass_count
}
else {
    display as error "  FAIL: V17 - countmode row-level (error `=_rc')"
    local ++fail_count
}


**# Merge Correctness Validation

**## V18 — Merge broadcasts patient-level indicators (hand-verified)
* Patient 1: rows 1-3. dx1=E110 in row 1 → dm2=1 broadcast to all 3 rows
* Patient 2: rows 4-5. No E11 codes → dm2=0 for both rows
local ++test_count
capture noisily {
    clear
    input long pid str10 dx1
    1 "E110"
    1 "Z00"
    1 "Z01"
    2 "Z00"
    2 "I10"
    end

    codescan dx1, define(dm2 "E11") id(pid) merge

    * All patient 1 rows = 1
    assert dm2 == 1 if pid == 1
    quietly count if pid == 1
    assert r(N) == 3

    * All patient 2 rows = 0
    assert dm2 == 0 if pid == 2
    quietly count if pid == 2
    assert r(N) == 2

    * Row count unchanged
    assert _N == 5
}
if _rc == 0 {
    display as result "  PASS: V18 - Merge broadcast correctness"
    local ++pass_count
}
else {
    display as error "  FAIL: V18 - Merge broadcast (error `=_rc')"
    local ++fail_count
}


**# Co-occurrence Matrix Validation

**## V20 — Co-occurrence matrix hand-verified
* 6 rows, 2 conditions (dm2, htn)
* Row 1: dm2=1, htn=0  → co-occur=0
* Row 2: dm2=0, htn=1  → co-occur=0
* Row 3: dm2=1, htn=1  → co-occur=1
* Row 4: dm2=0, htn=0  → co-occur=0
* Row 5: dm2=1, htn=1  → co-occur=1
* Row 6: dm2=1, htn=0  → co-occur=0
* Diagonal: dm2=4, htn=3
* Off-diagonal: 2
local ++test_count
capture noisily {
    clear
    input str10 dx1 str10 dx2
    "E110" ""
    ""     "I10"
    "E110" "I10"
    "Z00"  ""
    "E119" "I13"
    "E11"  ""
    end

    codescan dx1 dx2, define(dm2 "E11" | htn "I1[0-35]") cooccurrence

    matrix C = r(cooccurrence)
    * Diagonal = condition match counts
    assert el(C, 1, 1) == 4
    assert el(C, 2, 2) == 3
    * Off-diagonal = rows where both conditions match
    assert el(C, 1, 2) == 2
    assert el(C, 2, 1) == 2
}
if _rc == 0 {
    display as result "  PASS: V20 - Co-occurrence matrix (hand-verified)"
    local ++pass_count
}
else {
    display as error "  FAIL: V20 - Co-occurrence matrix (error `=_rc')"
    local ++fail_count
}


**# Lookforward Boundary Validation

**## V21 — Lookforward with inclusive (refdate included)
* index_dt = 21915 (2020-01-01), lookforward(365) inclusive
* Window: [21915, 22280]
local ++test_count
capture noisily {
    clear
    input long pid str10 dx1 double visit_dt double index_dt byte expected
    1 "E110" 21914 21915 0
    2 "E110" 21915 21915 1
    3 "E110" 21916 21915 1
    4 "E110" 22280 21915 1
    5 "E110" 22281 21915 0
    end
    format visit_dt index_dt %td

    codescan dx1, define(dm2 "E11") date(visit_dt) refdate(index_dt) ///
        lookforward(365) inclusive

    forvalues i = 1/`=_N' {
        assert dm2[`i'] == expected[`i']
    }
}
if _rc == 0 {
    display as result "  PASS: V21 - Lookforward inclusive boundary"
    local ++pass_count
}
else {
    display as error "  FAIL: V21 - Lookforward inclusive boundary (error `=_rc')"
    local ++fail_count
}


**# Nocase with Exclusion Validation

**## V22 — nocase exclusion is also case-insensitive
* define(dm2 "E11" ~ "E116") nocase
* "e116" → uppercased to "E116" → excluded → dm2=0
* "E116" → excluded → dm2=0
* "e110" → uppercased to "E110" → matches, not excluded → dm2=1
local ++test_count
capture noisily {
    clear
    input str10 code byte expected
    "e110"  1
    "E110"  1
    "e116"  0
    "E116"  0
    "e119"  1
    "Z00"   0
    end

    codescan code, define(dm2 "E11" ~ "E116") nocase

    forvalues i = 1/`=_N' {
        assert dm2[`i'] == expected[`i']
    }
}
if _rc == 0 {
    display as result "  PASS: V22 - nocase exclusion case-insensitive"
    local ++pass_count
}
else {
    display as error "  FAIL: V22 - nocase exclusion (error `=_rc')"
    local ++fail_count
}


**# Prefix with Level Validation

**## V23 — level(2) truncates patterns correctly
* define(endocrine "E11|E66") mode(prefix) level(2) → patterns become "E1|E6"
* E110 → starts with E1 → match
* E660 → starts with E6 → match
* I10  → starts with I1 → no match
* E210 → starts with E2 → no match
local ++test_count
capture noisily {
    clear
    input str10 code byte expected
    "E110"  1
    "E660"  1
    "E210"  0
    "I10"   0
    "E10"   1
    "E69"   1
    end

    codescan code, define(endocrine "E11|E66") mode(prefix) level(2)

    forvalues i = 1/`=_N' {
        assert endocrine[`i'] == expected[`i']
    }
}
if _rc == 0 {
    display as result "  PASS: V23 - level(2) truncates to 2-char prefixes"
    local ++pass_count
}
else {
    display as error "  FAIL: V23 - level(2) truncation (error `=_rc')"
    local ++fail_count
}


**# Multi-Condition Collapse Completeness

**## V24 — Collapse with 3 conditions, all date summaries (hand-computed)
* Patient 1: dm2 matches rows 1,2 (dates 100,200). htn matches row 1 (date 100). copd: no match.
* Patient 2: copd matches row 4 (date 300). dm2/htn: no match.
local ++test_count
capture noisily {
    clear
    input long pid str10 dx1 double visit_dt
    1 "E110" 100
    1 "E119" 200
    1 "I10"  100
    2 "J45"  300
    2 "Z00"  400
    end
    format visit_dt %td

    codescan dx1, define(dm2 "E11" | htn "I1[0-35]" | copd "J4[4-7]") ///
        id(pid) date(visit_dt) collapse earliestdate latestdate countdate

    assert _N == 2

    * Patient 1: dm2=1, first=100, last=200, count=2
    assert dm2 == 1 & dm2_first == 100 & dm2_last == 200 & dm2_count == 2 if pid == 1
    * Patient 1: htn=1, first=last=100, count=1
    assert htn == 1 & htn_first == 100 & htn_last == 100 & htn_count == 1 if pid == 1
    * Patient 1: copd=0, dates missing, count=0
    assert copd == 0 & missing(copd_first) & copd_count == 0 if pid == 1

    * Patient 2: dm2=0, htn=0
    assert dm2 == 0 & htn == 0 if pid == 2
    * Patient 2: copd=1, first=last=300, count=1
    assert copd == 1 & copd_first == 300 & copd_count == 1 if pid == 2
}
if _rc == 0 {
    display as result "  PASS: V24 - 3-condition collapse (hand-computed)"
    local ++pass_count
}
else {
    display as error "  FAIL: V24 - 3-condition collapse (error `=_rc')"
    local ++fail_count
}


**# Countdate with Time Window Validation

**## V25 — countdate only counts dates within time window
* Patient 1: matches on day 100 (outside 365-day lookback from refdate 500)
*            and day 200 (inside). countdate should = 1 (only day 200)
local ++test_count
capture noisily {
    clear
    input long pid str10 dx1 double visit_dt double index_dt
    1 "E110" 100  500
    1 "E119" 200  500
    1 "E110" 350  500
    2 "E110" 400  500
    end
    format visit_dt index_dt %td

    codescan dx1, define(dm2 "E11") id(pid) date(visit_dt) refdate(index_dt) ///
        lookback(365) collapse countdate earliestdate latestdate

    * Patient 1: lookback(365) from 500 → window [135, 500)
    *   day 100 outside, day 200 inside, day 350 inside → count=2
    assert dm2_count == 2 if pid == 1
    assert dm2_first == 200 if pid == 1
    assert dm2_last == 350 if pid == 1

    * Patient 2: day 400 inside → count=1
    assert dm2_count == 1 if pid == 2
}
if _rc == 0 {
    display as result "  PASS: V25 - countdate respects time window"
    local ++pass_count
}
else {
    display as error "  FAIL: V25 - countdate with window (error `=_rc')"
    local ++fail_count
}


**# Prefix Mode Exclusion Correctness

**## V26 — Prefix mode exclusion (hand-verified)
local ++test_count
capture noisily {
    clear
    input str10 code byte expected
    "E110"  1
    "E116"  0
    "E1160" 0
    "E117"  1
    "E11"   1
    "Z00"   0
    end

    codescan code, define(dm2 "E11" ~ "E116") mode(prefix)

    forvalues i = 1/`=_N' {
        assert dm2[`i'] == expected[`i']
    }
}
if _rc == 0 {
    display as result "  PASS: V26 - Prefix mode exclusion (hand-verified)"
    local ++pass_count
}
else {
    display as error "  FAIL: V26 - Prefix mode exclusion (error `=_rc')"
    local ++fail_count
}


**# Multi-Window Sensitivity Validation

**## V28 — Multi-window sensitivity matrix (hand-verified)
* Each window independently collapses and computes prevalence.
* 4 patients, each with 2 rows (one match, one non-match at different times).
* index_dt = 21915 (2020-01-01), lookback(30 90 365) inclusive
* Patient 1: E110 at 21910 (5d before), Z00 at 21910 → in all windows, has dm2
* Patient 2: E110 at 21860 (55d before), Z00 at 21860 → in 90d & 365d
* Patient 3: Z00 at 21910 (5d before), Z00 at 21860 → no dm2, but in windows
* Patient 4: E110 at 21600 (315d before), Z00 at 21600 → in 365d only
*
* 30d window (≥21885): pats 1,3 qualify → dm2: pat1=1, pat3=0 → 50%
* 90d window (≥21825): pats 1,2,3 qualify → dm2: pat1=1, pat2=1, pat3=0 → 66.7%
* 365d window (≥21550): pats 1,2,3,4 qualify → dm2: 1,2,4=1, 3=0 → 75%
local ++test_count
capture noisily {
    clear
    input long pid str10 dx1 double visit_dt double index_dt
    1 "E110" 21910 21915
    1 "Z00"  21910 21915
    2 "E110" 21860 21915
    2 "Z00"  21860 21915
    3 "Z00"  21910 21915
    3 "Z00"  21860 21915
    4 "E110" 21600 21915
    4 "Z00"  21600 21915
    end
    format visit_dt index_dt %td
    codescan dx1, define(dm2 "E11") id(pid) date(visit_dt) ///
        refdate(index_dt) lookback(30 90 365) collapse inclusive

    matrix S = r(sensitivity)
    assert rowsof(S) == 1
    assert colsof(S) == 3
    * 30d window: 1/2 patients → 50%
    assert abs(S[1,1] - 50) < 0.1
    * 90d window: 2/3 patients → 66.7%
    assert abs(S[1,2] - 66.667) < 0.1
    * 365d window: 3/4 patients → 75%
    assert abs(S[1,3] - 75) < 0.1
}
if _rc == 0 {
    display as result "  PASS: V28 - Multi-window sensitivity (hand-verified)"
    local ++pass_count
}
else {
    display as error "  FAIL: V28 - Multi-window sensitivity (error `=_rc')"
    local ++fail_count
}


**# Co-occurrence Symmetry Invariant

**## V29 — Co-occurrence matrix is symmetric
local ++test_count
capture noisily {
    clear
    input str10 dx1 str10 dx2
    "E110" "I10"
    "E110" ""
    "I10"  ""
    "F32"  "I10"
    "Z00"  ""
    end
    codescan dx1-dx2, define(dm2 "E11" | htn "I10" | dep "F32") cooccurrence
    matrix C = r(cooccurrence)
    * Symmetry check: C[i,j] == C[j,i] for all pairs
    forvalues i = 1/3 {
        forvalues j = 1/3 {
            assert C[`i',`j'] == C[`j',`i']
        }
    }
    * Diagonal = condition count
    * dm2: rows 1,2 → 2
    assert C[1,1] == 2
    * htn: rows 1,3,4 → 3
    assert C[2,2] == 3
    * dep: row 4 → 1
    assert C[3,3] == 1
    * dm2 & htn co-occur in row 1 → 1
    assert C[1,2] == 1
    * dm2 & dep: no overlap → 0
    assert C[1,3] == 0
    * htn & dep: row 4 → 1
    assert C[2,3] == 1
}
if _rc == 0 {
    display as result "  PASS: V29 - Co-occurrence symmetric and diagonal correct"
    local ++pass_count
}
else {
    display as error "  FAIL: V29 - Co-occurrence symmetric (error `=_rc')"
    local ++fail_count
}


**# Frame Output Validation

**## V30 — Frame content matches collapsed data exactly
* 3 patients: pid 1 has dm2+htn, pid 2 has htn only, pid 3 has nothing
* Hand-verified expected values after collapse:
*   pid 1: dm2=1, htn=1
*   pid 2: dm2=0, htn=1
*   pid 3: dm2=0, htn=0
local ++test_count
capture noisily {
    clear
    input long pid str10 dx1 str10 dx2 double visit_dt
    1 "E110" "I10" 21910
    1 "Z00"  ""    21915
    2 "I10"  ""    21910
    2 "I13"  ""    21915
    3 "Z00"  ""    21910
    end
    format visit_dt %td
    capture frame drop _cs_v30
    codescan dx1-dx2, define(dm2 "E11" | htn "I1[0-35]") ///
        id(pid) date(visit_dt) collapse alldates frame(_cs_v30) replace

    * frame() with collapse+preserve restores original data after
    * putting collapsed data into the frame. Check the frame directly.
    frame _cs_v30 {
        assert _N == 3
        confirm variable pid
        confirm variable dm2
        confirm variable htn
        confirm variable dm2_first
        confirm variable dm2_last
        confirm variable dm2_count
        confirm variable htn_first
        confirm variable htn_last
        confirm variable htn_count
        * Verify collapsed values (sorted by pid)
        sort pid
        assert dm2[1] == 1 & htn[1] == 1
        assert dm2[2] == 0 & htn[2] == 1
        assert dm2[3] == 0 & htn[3] == 0
        * Patient 1: dm2 earliest = 21910 (only match)
        assert dm2_first[1] == 21910
        assert dm2_last[1] == 21910
        assert dm2_count[1] == 1
        * Patient 2: no dm2 → missing dates, count=0
        assert missing(dm2_first[2])
        assert dm2_count[2] == 0
    }
    capture frame drop _cs_v30
}
if _rc == 0 {
    display as result "  PASS: V30 - Frame content matches collapsed data"
    local ++pass_count
}
else {
    display as error "  FAIL: V30 - Frame content (error `=_rc')"
    local ++fail_count
    capture frame drop _cs_v30
}


**# Export CSV Content Validation

**## V31 — Export CSV matches r(summary) values
local ++test_count
capture noisily {
    clear
    input str10 dx1
    "E110"
    "E119"
    "I10"
    "Z00"
    "Z01"
    end
    capture erase "_cs_v31.csv"
    codescan dx1, define(dm2 "E11" | htn "I10") export("_cs_v31.csv")
    matrix S = r(summary)
    local dm2_matches = S[1,1]
    local dm2_prev = S[1,2]
    local htn_matches = S[2,1]

    preserve
    import delimited using "_cs_v31.csv", clear
    * Row 1 = dm2, Row 2 = htn
    assert condition[1] == "dm2"
    assert matches[1] == `dm2_matches'
    assert abs(prevalence[1] - `dm2_prev') < 0.001
    assert condition[2] == "htn"
    assert matches[2] == `htn_matches'
    restore
    capture erase "_cs_v31.csv"
}
if _rc == 0 {
    display as result "  PASS: V31 - Export CSV matches r(summary)"
    local ++pass_count
}
else {
    display as error "  FAIL: V31 - Export CSV matches summary (error `=_rc')"
    local ++fail_count
}


**# Merge Date Summaries Validation

**## V32 — Merge earliestdate/latestdate/countdate (hand-verified)
* Patient 1: 3 rows, dm2 matches at visit 21910 and 21920
*   → dm2_first=21910, dm2_last=21920, dm2_count=2
* Patient 2: 2 rows, dm2 matches at 21915 only
*   → dm2_first=21915, dm2_last=21915, dm2_count=1
* Patient 3: no match → all missing/0
local ++test_count
capture noisily {
    clear
    input long pid str10 dx1 double visit_dt
    1 "E110" 21910
    1 "Z00"  21915
    1 "E119" 21920
    2 "E110" 21915
    2 "Z00"  21920
    3 "Z00"  21910
    3 "Z01"  21915
    end
    format visit_dt %td
    codescan dx1, define(dm2 "E11") id(pid) date(visit_dt) merge alldates

    * Patient 1 rows: all should have same merged values
    * 21910 = 27dec2019, 21915 = 01jan2020, 21920 = 06jan2020
    assert dm2_first == 21910 if pid == 1
    assert dm2_last == 21920 if pid == 1
    assert dm2_count == 2 if pid == 1

    assert dm2_first == 21915 if pid == 2
    assert dm2_last == 21915 if pid == 2
    assert dm2_count == 1 if pid == 2

    assert missing(dm2_first) if pid == 3
    assert missing(dm2_last) if pid == 3
    assert dm2_count == 0 if pid == 3

    * All 7 rows preserved
    assert _N == 7
}
if _rc == 0 {
    display as result "  PASS: V32 - Merge date summaries (hand-verified)"
    local ++pass_count
}
else {
    display as error "  FAIL: V32 - Merge date summaries (error `=_rc')"
    local ++fail_count
}


**# Detail Varcounts Validation

**## V33 — Detail varcounts per-variable (hand-verified)
* 4 rows, 2 vars (dx1, dx2), 1 condition (dm2 "E11")
* Row 1: dx1=E110 (match), dx2=Z00 (no)
* Row 2: dx1=Z00 (no), dx2=E119 (match)
* Row 3: dx1=E11 (match), dx2=E110 (match, but already flagged — still counted in detail)
* Row 4: dx1=Z00 (no), dx2=Z00 (no)
* Varcounts: dm2 in dx1=2 (rows 1,3), dm2 in dx2=1 (row 2; row 3 already matched)
* Wait — detail counts matches per variable regardless of already-matched flag?
* Looking at Mata code: `if (!is_count && indicators[i, k]) continue`
* So row 3 dx2: indicators[3,1] is already 1, so skip → varcounts dx2 only gets row 2
local ++test_count
capture noisily {
    clear
    input str10 dx1 str10 dx2
    "E110" "Z00"
    "Z00"  "E119"
    "E11"  "E110"
    "Z00"  "Z00"
    end
    codescan dx1 dx2, define(dm2 "E11") detail
    matrix V = r(varcounts)
    * dx1 matches: rows 1,3 → 2
    assert V[1,1] == 2
    * dx2 matches: row 2 only (row 3 already flagged in dx1 pass) → 1
    assert V[1,2] == 1
}
if _rc == 0 {
    display as result "  PASS: V33 - Detail varcounts per-variable (hand-verified)"
    local ++pass_count
}
else {
    display as error "  FAIL: V33 - Detail varcounts (error `=_rc')"
    local ++fail_count
}


**# Countmode Collapse Sum Validation

**## V35 — Countmode collapse sums row-level counts (hand-verified)
* Patient 1: row 1 (dx1=E110, dx2=E119 → count=2), row 2 (dx1=E11 → count=1)
*   → collapse sum = 3
* Patient 2: row 1 (dx1=Z00 → count=0)
*   → collapse sum = 0
local ++test_count
capture noisily {
    clear
    input long pid str10 dx1 str10 dx2
    1 "E110" "E119"
    1 "E11"  ""
    2 "Z00"  ""
    end
    codescan dx1-dx2, define(dm2 "E11") id(pid) collapse countmode
    assert dm2 == 3 if pid == 1
    assert dm2 == 0 if pid == 2
}
if _rc == 0 {
    display as result "  PASS: V35 - Countmode collapse sum (hand-verified)"
    local ++pass_count
}
else {
    display as error "  FAIL: V35 - Countmode collapse sum (error `=_rc')"
    local ++fail_count
}


**# Matched Code Validation

**## V36 — matched_code captures correct code per row (hand-verified)
* Row 1: dx1=Z00 (no), dx2=E110 (match) → mc=E110
* Row 2: dx1=E113 (match) → mc=E113
* Row 3: dx1=Z00 (no), dx2=I10 (no for dm2) → mc=""
local ++test_count
capture noisily {
    clear
    input str10 dx1 str10 dx2
    "Z00"  "E110"
    "E113" "I10"
    "Z00"  "I10"
    end
    codescan dx1 dx2, define(dm2 "E11") matched_code(mc)
    assert mc[1] == "E110"
    assert mc[2] == "E113"
    assert mc[3] == ""
}
if _rc == 0 {
    display as result "  PASS: V36 - matched_code correct per row"
    local ++pass_count
}
else {
    display as error "  FAIL: V36 - matched_code (error `=_rc')"
    local ++fail_count
}


**# Lookback + Lookforward Combined Boundary

**## V37 — Lookback(30) lookforward(10) boundary (hand-verified)
* index = 21915, window = [21885, 21925] inclusive (both directions → auto-inclusive)
* Row 1: visit 21884 → OUTSIDE (1 day before window)
* Row 2: visit 21885 → ON boundary → included
* Row 3: visit 21915 → refdate → included (auto-inclusive)
* Row 4: visit 21925 → ON boundary → included
* Row 5: visit 21926 → OUTSIDE (1 day after window)
local ++test_count
capture noisily {
    clear
    input long pid str10 dx1 double visit_dt double index_dt byte expected
    1 "E110" 21884 21915 0
    2 "E110" 21885 21915 1
    3 "E110" 21915 21915 1
    4 "E110" 21925 21915 1
    5 "E110" 21926 21915 0
    end
    format visit_dt index_dt %td
    codescan dx1, define(dm2 "E11") date(visit_dt) refdate(index_dt) ///
        lookback(30) lookforward(10)
    forvalues i = 1/5 {
        assert dm2[`i'] == expected[`i']
    }
}
if _rc == 0 {
    display as result "  PASS: V37 - Lookback+lookforward boundary (hand-verified)"
    local ++pass_count
}
else {
    display as error "  FAIL: V37 - Lookback+lookforward boundary (error `=_rc')"
    local ++fail_count
}


**# Codelist Matrix Validation

**## V38 — r(codelist) has count and prevalence (hand-verified)
local ++test_count
capture noisily {
    clear
    input str10 dx1
    "E110"
    "E119"
    "I10"
    "Z00"
    "Z01"
    end
    codescan dx1, define(dm2 "E11" | htn "I10")
    matrix CL = r(codelist)
    assert rowsof(CL) == 2
    * 3.0.0: count prevalence total_hits positive_units
    assert colsof(CL) == 4
    * dm2: 2 matches out of 5 → count=2, prevalence=40
    assert CL[1,1] == 2
    assert abs(CL[1,2] - 40) < 0.1
    * htn: 1 match out of 5 → count=1, prevalence=20
    assert CL[2,1] == 1
    assert abs(CL[2,2] - 20) < 0.1
    * Only one scan variable and no countmode, so each match is one unit and
    * there is no hit total to report. positive_units repeats the counts above;
    * total_hits is missing rather than a copy of them.
    assert missing(CL[1,3])
    assert missing(CL[2,3])
    assert CL[1,4] == 2
    assert CL[2,4] == 1
}
if _rc == 0 {
    display as result "  PASS: V38 - Codelist matrix (hand-verified)"
    local ++pass_count
}
else {
    display as error "  FAIL: V38 - Codelist matrix (error `=_rc')"
    local ++fail_count
}


* ============================================================
* NEW: Co-occurrence Matrix Properties
* ============================================================

**## V40 — Co-occurrence diagonal = marginal counts
local ++test_count
capture noisily {
    clear
    input str10 dx1 str10 dx2
    "E110" "I10"
    "E119" ""
    "I10"  ""
    "Z00"  ""
    end
    codescan dx1 dx2, define(dm2 "E11" | htn "I10") cooccurrence
    matrix C = r(cooccurrence)
    * Diagonal = marginal counts: dm2 matches 2 rows, htn matches 2 rows
    quietly count if dm2 == 1
    assert C[1,1] == r(N)
    quietly count if htn == 1
    assert C[2,2] == r(N)
    * Symmetry: C[1,2] == C[2,1]
    assert C[1,2] == C[2,1]
    * Off-diagonal <= min(diagonal)
    assert C[1,2] <= min(C[1,1], C[2,2])
}
if _rc == 0 {
    display as result "  PASS: V40 - Co-occurrence diagonal and symmetry"
    local ++pass_count
}
else {
    display as error "  FAIL: V40 - Co-occurrence properties (error `=_rc')"
    local ++fail_count
}


* ============================================================
* NEW: Merge Row Count Conservation
* ============================================================

**## V41 — Merge preserves original row count exactly
local ++test_count
capture noisily {
    clear
    input long pid str10 dx1 double visit_dt double index_dt
    1 "E110" 21914 21915
    1 "Z00"  21916 21915
    2 "I10"  21910 21915
    2 "E119" 21914 21915
    3 "Z00"  21900 21915
    end
    format visit_dt index_dt %td
    local N_pre = _N
    local sort_pre = pid[1]
    codescan dx1, define(dm2 "E11" | htn "I10") id(pid) date(visit_dt) ///
        refdate(index_dt) lookback(365) merge alldates
    * Row count unchanged
    assert _N == `N_pre'
    * Patient-level indicators: same value for all rows of same patient
    assert dm2[1] == dm2[2]
    assert dm2[3] == dm2[4]
    * merge broadcasts: patient 1 has dm2=1, patient 2 has both
    assert dm2 == 1 if pid == 1
    assert dm2 == 1 if pid == 2
    assert htn == 1 if pid == 2
    assert dm2 == 0 if pid == 3
}
if _rc == 0 {
    display as result "  PASS: V41 - Merge row count conservation"
    local ++pass_count
}
else {
    display as error "  FAIL: V41 - Merge conservation (error `=_rc')"
    local ++fail_count
}


* ============================================================
* NEW: Countmode Collapse Sum Conservation
* ============================================================

**## V42 — Countmode collapse sum = total row-level matches (hand-verified)
local ++test_count
capture noisily {
    clear
    input long pid str10 dx1 str10 dx2
    1 "E110" "E119"
    1 "E113" ""
    2 "E110" ""
    2 "Z00"  ""
    end
    * Row-level: pid=1 row1 has 2 E11 matches, row2 has 1 → total = 3
    * pid=2 row1 has 1, row2 has 0 → total = 1
    codescan dx1 dx2, define(dm2 "E11") id(pid) collapse countmode
    assert dm2[1] == 3 if pid == 1
    assert dm2[2] == 1 if pid == 2
}
if _rc == 0 {
    display as result "  PASS: V42 - Countmode collapse sum (hand-verified)"
    local ++pass_count
}
else {
    display as error "  FAIL: V42 - Countmode collapse sum (error `=_rc')"
    local ++fail_count
}



* ============================================================
* NEW: Matched_code Under Multi-Condition Exclusion
* ============================================================

**## V44 — matched_code cleared when ALL conditions excluded for a row
local ++test_count
capture noisily {
    clear
    input str10 dx1 str10 dx2
    "E116" "I132"
    "E110" "I10"
    "E116" "I10"
    "Z00"  ""
    end
    codescan dx1 dx2, define(dm2 "E11" ~ "E116" | htn "I1[0-35]" ~ "I132") ///
        matched_code(mc)
    * Row 1: E116 excluded from dm2, I132 excluded from htn → both excluded → mc empty
    assert dm2[1] == 0
    assert htn[1] == 0
    assert mc[1] == ""
    * Row 2: E110 matches dm2, I10 matches htn → mc = first match (E110)
    assert dm2[2] == 1
    assert htn[2] == 1
    assert mc[2] == "E110"
    * Row 3: E116 excluded from dm2 but I10 matches htn → mc = I10 (from dx2)
    assert dm2[3] == 0
    assert htn[3] == 1
    assert mc[3] != ""
    * Row 4: nothing matches
    assert mc[4] == ""
}
if _rc == 0 {
    display as result "  PASS: V44 - matched_code multi-condition exclusion"
    local ++pass_count
}
else {
    display as error "  FAIL: V44 - matched_code multi-exclusion (error `=_rc')"
    local ++fail_count
}


* ============================================================
* NEW: Sensitivity Matrix Values
* ============================================================

**## V45 — Multi-window sensitivity values (hand-computed)
local ++test_count
capture noisily {
    clear
    input long pid str10 dx1 double visit_dt double index_dt
    1 "E110" 21550 21915
    1 "Z00"  21914 21915
    2 "E119" 21800 21915
    2 "Z00"  21914 21915
    3 "Z00"  21914 21915
    3 "Z00"  21910 21915
    end
    format visit_dt index_dt %td
    * lookback(180): day 21915-180=21735 to 21914
    *   pid1: E110 at 21550 < 21735 → excluded. pid2: E119 at 21800 → in range.
    *   prevalence at 180d: 1 out of 3 = 33.3%
    * lookback(365): day 21915-365=21550 to 21914
    *   pid1: E110 at 21550 → included. pid2: E119 at 21800 → in range.
    *   prevalence at 365d: 2 out of 3 = 66.7%
    codescan dx1, define(dm2 "E11") id(pid) date(visit_dt) ///
        refdate(index_dt) lookback(180 365) collapse
    matrix SM = r(sensitivity)
    * Column 1 = 180d prevalence, column 2 = 365d prevalence
    assert abs(SM[1,1] - 100/3) < 0.5
    assert abs(SM[1,2] - 200/3) < 0.5
}
if _rc == 0 {
    display as result "  PASS: V45 - Multi-window sensitivity (hand-computed)"
    local ++pass_count
}
else {
    display as error "  FAIL: V45 - Multi-window sensitivity (error `=_rc')"
    local ++fail_count
}


* ============================================================
* NEW: Generate Prefix on Date Variables
* ============================================================

**## V46 — generate() prefix applied to _first, _last, _count
local ++test_count
capture noisily {
    clear
    input long pid str10 dx1 double visit_dt double index_dt
    1 "E110" 21914 21915
    1 "E119" 21910 21915
    2 "Z00"  21914 21915
    end
    format visit_dt index_dt %td
    codescan dx1, define(dm2 "E11") id(pid) date(visit_dt) ///
        refdate(index_dt) lookback(365) collapse alldates generate(dx_)
    confirm variable dx_dm2
    confirm variable dx_dm2_first
    confirm variable dx_dm2_last
    confirm variable dx_dm2_count
    * Verify values correct
    assert dx_dm2 == 1 if pid == 1
    assert dx_dm2 == 0 if pid == 2
    assert dx_dm2_count == 2 if pid == 1
}
if _rc == 0 {
    display as result "  PASS: V46 - generate() prefix on all output vars"
    local ++pass_count
}
else {
    display as error "  FAIL: V46 - generate prefix (error `=_rc')"
    local ++fail_count
}


* ============================================================
* NEW: Indicator Invariants Under Large Data
* ============================================================

**## V47 — Indicators always 0 or 1 on 500-row randomized data
local ++test_count
capture noisily {
    clear
    set seed 99999
    set obs 500
    gen str10 dx1 = ""
    gen str10 dx2 = ""
    gen str10 dx3 = ""
    * Assign random codes from a pool
    quietly {
        replace dx1 = "E110" if runiform() < 0.15
        replace dx1 = "E119" if dx1 == "" & runiform() < 0.15
        replace dx1 = "I10"  if dx1 == "" & runiform() < 0.15
        replace dx1 = "I21"  if dx1 == "" & runiform() < 0.10
        replace dx1 = "J45"  if dx1 == "" & runiform() < 0.10
        replace dx1 = "F32"  if dx1 == "" & runiform() < 0.10
        replace dx1 = "Z00"  if dx1 == ""
        replace dx2 = "E119" if runiform() < 0.10
        replace dx2 = "I13"  if dx2 == "" & runiform() < 0.10
        replace dx2 = "I25"  if dx2 == "" & runiform() < 0.10
        replace dx3 = "K21"  if runiform() < 0.05
    }
    codescan dx1 dx2 dx3, ///
        define(dm2 "E11" | htn "I1[0-35]" | cvd "I2[0-5]" | copd "J4[4-7]" | dep "F3[23]")
    * All indicators must be 0 or 1
    foreach v in dm2 htn cvd copd dep {
        assert `v' == 0 | `v' == 1
    }
    * Prevalence between 0 and 100
    matrix S = r(summary)
    forvalues i = 1/5 {
        assert S[`i',2] >= 0 & S[`i',2] <= 100
        * binary mode: total_hits (col 3) missing; positive_units (col 4) == count
        assert missing(S[`i',3])
        assert S[`i',4] == S[`i',1]
    }
}
if _rc == 0 {
    display as result "  PASS: V47 - Indicator 0/1 invariant on 500 rows"
    local ++pass_count
}
else {
    display as error "  FAIL: V47 - Indicator invariant (error `=_rc')"
    local ++fail_count
}


* ============================================================
* NEW: Earliestdate <= Latestdate Under All Scenarios
* ============================================================

**## V48 — earliestdate <= latestdate always holds (randomized)
local ++test_count
capture noisily {
    clear
    set seed 54321
    set obs 200
    gen long pid = ceil(_n / 4)
    gen str10 dx1 = cond(runiform() < 0.3, "E110", "Z00")
    gen str10 dx2 = cond(runiform() < 0.2, "E119", "")
    gen double visit_dt = mdy(1,1,2019) + floor(runiform() * 730)
    gen double index_dt = mdy(1,1,2020)
    format visit_dt index_dt %td
    codescan dx1 dx2, define(dm2 "E11") id(pid) date(visit_dt) ///
        refdate(index_dt) lookback(730) inclusive collapse earliestdate latestdate
    * For all patients with a match, first <= last
    assert dm2_first <= dm2_last if dm2 == 1
}
if _rc == 0 {
    display as result "  PASS: V48 - earliestdate <= latestdate invariant (200 rows)"
    local ++pass_count
}
else {
    display as error "  FAIL: V48 - earliest<=latest invariant (error `=_rc')"
    local ++fail_count
}


* ============================================================
* NEW: Frame Content Matches Direct Collapse
* ============================================================

**## V49 — frame() output identical to direct collapse
local ++test_count
capture noisily {
    clear
    input long pid str10 dx1 str10 dx2
    1 "E110" "I10"
    1 "Z00"  ""
    2 "I10"  ""
    2 "E119" "I13"
    3 "Z00"  "Z01"
    end
    * Collapse directly
    codescan dx1 dx2, define(dm2 "E11" | htn "I1[0-35]") id(pid) collapse
    sort pid
    tempfile v49_direct
    quietly save `v49_direct'
    quietly ds
    local v49_vars `r(varlist)'
    quietly datasignature
    local v49_sig `r(datasignature)'

    * Hand-computed, so a defect shared by both paths still fails.
    assert _N == 3
    assert dm2[1] == 1 & dm2[2] == 1 & dm2[3] == 0
    assert htn[1] == 1 & htn[2] == 1 & htn[3] == 0

    * Now use frame
    clear
    input long pid str10 dx1 str10 dx2
    1 "E110" "I10"
    1 "Z00"  ""
    2 "I10"  ""
    2 "E119" "I13"
    3 "Z00"  "Z01"
    end
    codescan dx1 dx2, define(dm2 "E11" | htn "I1[0-35]") ///
        id(pid) collapse frame(test_v49) replace

    * Compare the COMPLETE datasets. ds+datasignature cover variable names and
    * count, which cf _all cannot see because it walks the master's varlist.
    frame test_v49 {
        sort pid
        quietly ds
        assert "`r(varlist)'" == "`v49_vars'"
        quietly datasignature
        assert "`r(datasignature)'" == "`v49_sig'"
        cf _all using `v49_direct'
    }
    capture frame drop test_v49
}
if _rc == 0 {
    display as result "  PASS: V49 - frame() output matches direct collapse"
    local ++pass_count
}
else {
    display as error "  FAIL: V49 - frame vs collapse (error `=_rc')"
    local ++fail_count
    capture frame drop test_v49
}


* ============================================================
* NEW: Unmatched Flag Conservation
* ============================================================

**## V50 — unmatched() = 1 iff all indicators = 0 for touse rows
local ++test_count
capture noisily {
    clear
    input str10 dx1 str10 dx2
    "E110" "I10"
    "Z00"  ""
    "E119" ""
    "K21"  "J45"
    end
    codescan dx1 dx2, define(dm2 "E11" | htn "I10") unmatched(nomatch)
    * nomatch should be 1 iff dm2==0 AND htn==0
    forvalues i = 1/`=_N' {
        if dm2[`i'] == 0 & htn[`i'] == 0 {
            assert nomatch[`i'] == 1
        }
        else {
            assert nomatch[`i'] == 0
        }
    }
}
if _rc == 0 {
    display as result "  PASS: V50 - unmatched flag conservation"
    local ++pass_count
}
else {
    display as error "  FAIL: V50 - unmatched conservation (error `=_rc')"
    local ++fail_count
}


* ============================================================
* NEW: Prefix Mode Exact Boundary Verification
* ============================================================

**## V51 — level() truncation verified digit-by-digit
local ++test_count
capture noisily {
    clear
    input str10 dx1 byte expected
    "E110" 1
    "E119" 1
    "E120" 1
    "E210" 0
    "E11"  1
    "E1"   1
    "I10"  0
    end
    * level(2) truncates "E11" to "E1", matches anything starting with E1
    codescan dx1, define(dm2 "E11") mode(prefix) level(2)
    forvalues i = 1/`=_N' {
        assert dm2[`i'] == expected[`i']
    }
}
if _rc == 0 {
    display as result "  PASS: V51 - level(2) truncation digit-by-digit"
    local ++pass_count
}
else {
    display as error "  FAIL: V51 - level truncation (error `=_rc')"
    local ++fail_count
}


* ============================================================
* NEW: Detail Varcounts Sum Equals Total Match Count
* ============================================================

**## V52 — detail varcounts row sum = total matches per condition
local ++test_count
capture noisily {
    clear
    input str10 dx1 str10 dx2 str10 dx3
    "E110" "I10"  ""
    "Z00"  "E119" ""
    "I10"  ""     "E11"
    "Z00"  "Z01"  ""
    end
    codescan dx1 dx2 dx3, define(dm2 "E11" | htn "I10") detail
    matrix V = r(varcounts)
    * dm2 total matches: row 1 (dx1), row 2 (dx2), row 3 (dx3) = 3
    local dm2_sum = V[1,1] + V[1,2] + V[1,3]
    quietly count if dm2 == 1
    assert `dm2_sum' == r(N)
    * htn total matches: row 1 (dx2), row 3 (dx1) = 2
    local htn_sum = V[2,1] + V[2,2] + V[2,3]
    quietly count if htn == 1
    assert `htn_sum' == r(N)
}
if _rc == 0 {
    display as result "  PASS: V52 - detail varcounts sum = match count"
    local ++pass_count
}
else {
    display as error "  FAIL: V52 - detail varcounts sum (error `=_rc')"
    local ++fail_count
}


* ============================================================
* NEW: Export CSV Content Matches r(summary)
* ============================================================

**## V53 — export CSV prevalence matches r(summary) exactly
local ++test_count
capture noisily {
    clear
    set obs 20
    gen str10 dx1 = cond(_n <= 5, "E110", cond(_n <= 12, "I10", "Z00"))
    codescan dx1, define(dm2 "E11" | htn "I10") export("_codescan_v53.csv", replace)
    matrix S = r(summary)
    local prev_dm2 = S[1,2]
    local prev_htn = S[2,2]
    preserve
    import delimited using "_codescan_v53.csv", clear
    assert abs(prevalence[1] - `prev_dm2') < 0.01
    assert abs(prevalence[2] - `prev_htn') < 0.01
    restore
}
if _rc == 0 {
    display as result "  PASS: V53 - export CSV matches r(summary)"
    local ++pass_count
}
else {
    display as error "  FAIL: V53 - export CSV match (error `=_rc')"
    local ++fail_count
}


* ============================================================
* NEW: Nodots Equivalence
* ============================================================

**## V55 — nodots makes "E11.0" equivalent to "E110"
local ++test_count
capture noisily {
    clear
    input str10 dx1 byte expected
    "E11.0" 1
    "E110"  1
    "E11"   1
    "E.110" 1
    "Z00"   0
    end
    codescan dx1, define(dm2 "E11") nodots
    forvalues i = 1/`=_N' {
        assert dm2[`i'] == expected[`i']
    }
}
if _rc == 0 {
    display as result "  PASS: V55 - nodots equivalence (hand-verified)"
    local ++pass_count
}
else {
    display as error "  FAIL: V55 - nodots equivalence (error `=_rc')"
    local ++fail_count
}

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


**# Summary

display ""
_codescan_qa_publish "validation_codescan_extended" `test_count' `pass_count' `fail_count'
display as result "RESULT: validation_codescan_extended tests=`test_count' pass=`pass_count' fail=`fail_count'"
display as result "Validation Results: `pass_count'/`test_count' passed, `fail_count' failed"

if `fail_count' > 0 {
    display as error "SOME VALIDATIONS FAILED"
    exit 1
}
else {
    display as result "ALL VALIDATIONS PASSED"
}
