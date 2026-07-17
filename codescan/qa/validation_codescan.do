* validation_codescan.do - Correctness validation for codescan
* Date: 2026-04-01

clear all
set seed 12345
version 16.0

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
* V1: Known-Answer Regex Matching
* ============================================================
* Hand-verified: regex ^(E11) should match codes starting with E11
* E110 → match (starts with E11)
* E119 → match (starts with E11)
* E66  → no match
* I10  → no match
* E1   → no match (too short, E1 != E11)

local ++test_count
capture noisily {
    clear
    input str10 code byte expected
    "E110" 1
    "E119" 1
    "E11"  1
    "E66"  0
    "I10"  0
    "E1"   0
    "E210" 0
    ""     0
    end

    codescan code, define(dm2 "E11")

    forvalues i = 1/`=_N' {
        assert dm2[`i'] == expected[`i']
    }
}
if _rc == 0 {
    display as result "  PASS: V1a - Known-answer regex matching (E11)"
    local ++pass_count
}
else {
    display as error "  FAIL: V1a - Known-answer regex matching (E11) (error `=_rc')"
    local ++fail_count
}

* V1b: Character class [0-35] matches 0,1,2,3,5 but NOT 4,6,7,8,9
local ++test_count
capture noisily {
    clear
    input str10 code byte expected
    "I10"  1
    "I11"  1
    "I12"  1
    "I13"  1
    "I14"  0
    "I15"  1
    "I16"  0
    "I17"  0
    "I18"  0
    "I19"  0
    "I100" 1
    end

    codescan code, define(htn "I1[0-35]")

    forvalues i = 1/`=_N' {
        assert htn[`i'] == expected[`i']
    }
}
if _rc == 0 {
    display as result "  PASS: V1b - Character class [0-35] known answers"
    local ++pass_count
}
else {
    display as error "  FAIL: V1b - Character class [0-35] known answers (error `=_rc')"
    local ++fail_count
}

* V1c: Multi-column scan — match found in any column
local ++test_count
capture noisily {
    clear
    input str10 dx1 str10 dx2 str10 dx3 byte expected
    "E110" ""     ""     1
    ""     "E119" ""     1
    ""     ""     "E11"  1
    "J45"  "K21"  "Z00"  0
    "E110" "E119" "E11"  1
    end

    codescan dx1-dx3, define(dm2 "E11")

    forvalues i = 1/`=_N' {
        assert dm2[`i'] == expected[`i']
    }
}
if _rc == 0 {
    display as result "  PASS: V1c - Multi-column scan finds match in any column"
    local ++pass_count
}
else {
    display as error "  FAIL: V1c - Multi-column scan finds match in any column (error `=_rc')"
    local ++fail_count
}


* ============================================================
* V2: Known-Answer Prefix Matching
* ============================================================
* Hand-verified: prefix "E11" matches substr(code, 1, 3) == "E11"
* Multi-prefix "Z00|Z01" matches either prefix

local ++test_count
capture noisily {
    clear
    input str10 code byte expected
    "E110" 1
    "E119" 1
    "E11"  1
    "E66"  0
    "AE11" 0
    ""     0
    end

    codescan code, define(dm2 "E11") mode(prefix)

    forvalues i = 1/`=_N' {
        assert dm2[`i'] == expected[`i']
    }
}
if _rc == 0 {
    display as result "  PASS: V2a - Known-answer prefix matching"
    local ++pass_count
}
else {
    display as error "  FAIL: V2a - Known-answer prefix matching (error `=_rc')"
    local ++fail_count
}

* V2b: Multi-prefix with pipe separator
local ++test_count
capture noisily {
    clear
    input str10 code byte expected
    "Z00"  1
    "Z001" 1
    "Z01"  1
    "Z02"  0
    "Z0"   0
    end

    codescan code, define(zcodes "Z00|Z01") mode(prefix)

    forvalues i = 1/`=_N' {
        assert zcodes[`i'] == expected[`i']
    }
}
if _rc == 0 {
    display as result "  PASS: V2b - Multi-prefix pipe separator"
    local ++pass_count
}
else {
    display as error "  FAIL: V2b - Multi-prefix pipe separator (error `=_rc')"
    local ++fail_count
}


* ============================================================
* V3: Time Window Boundary Tests
* ============================================================
* index_dt = 2020-01-01 (Stata date 21915)
* lookback(365): window is [2019-01-02, 2020-01-01)
*   - 2019-01-01 = 21550, index-365 = 21550 → ON boundary → included
*   - 2019-01-02 = 21551 → inside
*   - 2018-12-31 = 21549 → outside (before window)
*   - 2019-12-31 = 21914 → inside (day before refdate)
*   - 2020-01-01 = 21915 → refdate → excluded (lookback only)

local ++test_count
capture noisily {
    clear
    input long pid str10 dx1 double visit_dt double index_dt byte expected
    1 "E110" 21549 21915 0
    2 "E110" 21550 21915 1
    3 "E110" 21551 21915 1
    4 "E110" 21914 21915 1
    5 "E110" 21915 21915 0
    6 "E110" 21916 21915 0
    end
    format visit_dt index_dt %td

    codescan dx1, define(dm2 "E11") date(visit_dt) refdate(index_dt) lookback(365)

    forvalues i = 1/`=_N' {
        assert dm2[`i'] == expected[`i']
    }
}
if _rc == 0 {
    display as result "  PASS: V3a - Lookback boundary (refdate excluded)"
    local ++pass_count
}
else {
    display as error "  FAIL: V3a - Lookback boundary (refdate excluded) (error `=_rc')"
    local ++fail_count
}

* V3b: Lookback with inclusive — refdate boundary included
local ++test_count
capture noisily {
    clear
    input long pid str10 dx1 double visit_dt double index_dt byte expected
    1 "E110" 21549 21915 0
    2 "E110" 21550 21915 1
    3 "E110" 21914 21915 1
    4 "E110" 21915 21915 1
    5 "E110" 21916 21915 0
    end
    format visit_dt index_dt %td

    codescan dx1, define(dm2 "E11") date(visit_dt) refdate(index_dt) ///
        lookback(365) inclusive

    forvalues i = 1/`=_N' {
        assert dm2[`i'] == expected[`i']
    }
}
if _rc == 0 {
    display as result "  PASS: V3b - Lookback boundary (inclusive)"
    local ++pass_count
}
else {
    display as error "  FAIL: V3b - Lookback boundary (inclusive) (error `=_rc')"
    local ++fail_count
}

* V3c: Lookforward boundary (refdate excluded)
* lookforward(365): window is (2020-01-01, 2021-01-01]
*   - 2020-01-01 = 21915 → refdate → excluded
*   - 2020-01-02 = 21916 → inside
*   - 2021-01-01 = 22281 → ON far boundary → included (<=)
*   - 2021-01-02 = 22282 → outside

local ++test_count
capture noisily {
    clear
    input long pid str10 dx1 double visit_dt double index_dt byte expected
    1 "E110" 21914 21915 0
    2 "E110" 21915 21915 0
    3 "E110" 21916 21915 1
    4 "E110" 22280 21915 1
    5 "E110" 22281 21915 0
    end
    format visit_dt index_dt %td

    codescan dx1, define(dm2 "E11") date(visit_dt) refdate(index_dt) lookforward(365)

    forvalues i = 1/`=_N' {
        assert dm2[`i'] == expected[`i']
    }
}
if _rc == 0 {
    display as result "  PASS: V3c - Lookforward boundary (refdate excluded)"
    local ++pass_count
}
else {
    display as error "  FAIL: V3c - Lookforward boundary (refdate excluded) (error `=_rc')"
    local ++fail_count
}

* V3d: Both lookback + lookforward — refdate auto-included
* Window: [2019-01-02, 2021-01-01] — refdate included
local ++test_count
capture noisily {
    clear
    input long pid str10 dx1 double visit_dt double index_dt byte expected
    1 "E110" 21549 21915 0
    2 "E110" 21550 21915 1
    3 "E110" 21915 21915 1
    4 "E110" 22280 21915 1
    5 "E110" 22281 21915 0
    end
    format visit_dt index_dt %td

    codescan dx1, define(dm2 "E11") date(visit_dt) refdate(index_dt) ///
        lookback(365) lookforward(365)

    forvalues i = 1/`=_N' {
        assert dm2[`i'] == expected[`i']
    }
}
if _rc == 0 {
    display as result "  PASS: V3d - Both lookback + lookforward (refdate auto-included)"
    local ++pass_count
}
else {
    display as error "  FAIL: V3d - Both lookback + lookforward (error `=_rc')"
    local ++fail_count
}

* V3e: Missing date excluded from window
local ++test_count
capture noisily {
    clear
    input long pid str10 dx1 double visit_dt double index_dt byte expected
    1 "E110" .     21915 0
    2 "E110" 21914 .     0
    3 "E110" .     .     0
    4 "E110" 21914 21915 1
    end
    format visit_dt index_dt %td

    codescan dx1, define(dm2 "E11") date(visit_dt) refdate(index_dt) lookback(365)

    forvalues i = 1/`=_N' {
        assert dm2[`i'] == expected[`i']
    }
}
if _rc == 0 {
    display as result "  PASS: V3e - Missing dates excluded from window"
    local ++pass_count
}
else {
    display as error "  FAIL: V3e - Missing dates excluded from window (error `=_rc')"
    local ++fail_count
}


* ============================================================
* V4: Collapse Correctness
* ============================================================
* Hand-computed collapse: 3 patients, multiple visits
* Patient 1: 3 rows, E110 on row 1 and 3 → dm2=1, earliest=day1, latest=day3, count=2
* Patient 2: 2 rows, no match → dm2=0, dates missing, count=0
* Patient 3: 2 rows, E119 on row 5 → dm2=1, earliest=latest=day5, count=1

local ++test_count
capture noisily {
    clear
    input long pid str10 dx1 double visit_dt
    1 "E110" 21900
    1 "J45"  21910
    1 "E119" 21920
    2 "J45"  21900
    2 "K21"  21910
    3 "E119" 21905
    3 "Z00"  21915
    end
    gen double index_dt = 22000
    format visit_dt index_dt %td

    codescan dx1, define(dm2 "E11") id(pid) date(visit_dt) collapse ///
        earliestdate latestdate countdate

    * 3 patients
    assert _N == 3

    * Patient 1: dm2=1, first=21900, last=21920, count=2
    assert dm2 == 1 if pid == 1
    assert dm2_first == 21900 if pid == 1
    assert dm2_last == 21920 if pid == 1
    assert dm2_count == 2 if pid == 1

    * Patient 2: dm2=0, dates missing, count=0
    assert dm2 == 0 if pid == 2
    assert missing(dm2_first) if pid == 2
    assert missing(dm2_last) if pid == 2
    assert dm2_count == 0 if pid == 2

    * Patient 3: dm2=1, first=last=21905, count=1
    assert dm2 == 1 if pid == 3
    assert dm2_first == 21905 if pid == 3
    assert dm2_last == 21905 if pid == 3
    assert dm2_count == 1 if pid == 3
}
if _rc == 0 {
    display as result "  PASS: V4a - Collapse correctness (hand-computed)"
    local ++pass_count
}
else {
    display as error "  FAIL: V4a - Collapse correctness (hand-computed) (error `=_rc')"
    local ++fail_count
}

* V4b: Countdate counts unique dates, not unique rows
* Patient has same E110 on same date in dx1 and dx2 → should count as 1 unique date
local ++test_count
capture noisily {
    clear
    input long pid str10 dx1 str10 dx2 double visit_dt
    1 "E110" "E119" 21900
    1 "E110" ""     21900
    1 "E110" ""     21910
    end
    gen double index_dt = 22000
    format visit_dt index_dt %td

    codescan dx1 dx2, define(dm2 "E11") id(pid) date(visit_dt) collapse countdate

    * Two rows have date 21900 → 1 unique date. One row at 21910 → 1 unique date.
    * Total = 2 unique dates
    assert dm2_count == 2 if pid == 1
}
if _rc == 0 {
    display as result "  PASS: V4b - Countdate counts unique dates"
    local ++pass_count
}
else {
    display as error "  FAIL: V4b - Countdate counts unique dates (error `=_rc')"
    local ++fail_count
}


* ============================================================
* V5: Row-Level Validation with Multiple Conditions
* ============================================================
* 10 rows, 3 conditions, hand-verify every cell

local ++test_count
capture noisily {
    clear
    input str10 dx1 str10 dx2 byte exp_dm2 byte exp_htn byte exp_cvd
    "E110" ""     1 0 0
    "I10"  ""     0 1 0
    "I21"  "E119" 1 0 1
    "F32"  ""     0 0 0
    "E660" ""     0 0 0
    "I13"  "I250" 0 1 1
    "Z00"  ""     0 0 0
    "E111" "I15"  1 1 0
    "I200" ""     0 0 1
    ""     ""     0 0 0
    end

    codescan dx1 dx2, define(dm2 "E11" | htn "I1[0-35]" | cvd "I2[0-5]")

    forvalues i = 1/`=_N' {
        assert dm2[`i'] == exp_dm2[`i']
        assert htn[`i'] == exp_htn[`i']
        assert cvd[`i'] == exp_cvd[`i']
    }
}
if _rc == 0 {
    display as result "  PASS: V5 - Row-level validation (10 rows x 3 conditions)"
    local ++pass_count
}
else {
    display as error "  FAIL: V5 - Row-level validation (error `=_rc')"
    local ++fail_count
}


* ============================================================
* V6: Summary Matrix Validation
* ============================================================
* Hand-computed: 20 obs, dm2 matches 4 rows → count=4, prevalence=4/20*100=20.0
* obesity matches 1 row → count=1, prevalence=1/20*100=5.0

local ++test_count
capture noisily {
    clear
    set obs 20
    gen long pid = ceil(_n / 4)
    gen str10 dx1 = ""
    gen str10 dx2 = ""
    gen str10 dx3 = ""

    * DM2 matches: rows 1,3,11,14 (4 rows)
    replace dx1 = "E110" if _n == 1
    replace dx1 = "E119" if _n == 3
    replace dx1 = "E110" if _n == 11
    replace dx2 = "E111" if _n == 14

    * Obesity matches: row 1 only (1 row, dx2)
    replace dx2 = "E660" if _n == 1

    * Fill remaining with non-matching codes
    replace dx1 = "Z00" if dx1 == "" & dx2 == ""

    codescan dx1-dx3, define(dm2 "E11" | obesity "E66")

    matrix S = r(summary)

    * Row 1 = dm2: count=4, prevalence=20.0
    assert S[1,1] == 4
    assert abs(S[1,2] - 20.0) < 0.01

    * Row 2 = obesity: count=1, prevalence=5.0
    assert S[2,1] == 1
    assert abs(S[2,2] - 5.0) < 0.01
}
if _rc == 0 {
    display as result "  PASS: V6 - Summary matrix values (hand-computed)"
    local ++pass_count
}
else {
    display as error "  FAIL: V6 - Summary matrix values (error `=_rc')"
    local ++fail_count
}


* ============================================================
* V7: Invariant Tests
* ============================================================

* V7a: Indicator is always 0 or 1
local ++test_count
capture noisily {
    clear
    set obs 100
    gen str10 dx1 = ""
    replace dx1 = "E110" if mod(_n, 3) == 0
    replace dx1 = "I10"  if mod(_n, 5) == 0
    replace dx1 = "Z00"  if dx1 == ""

    codescan dx1, define(dm2 "E11" | htn "I1[0-35]")

    assert dm2 >= 0 & dm2 <= 1
    assert htn >= 0 & htn <= 1
}
if _rc == 0 {
    display as result "  PASS: V7a - Indicators are always 0 or 1"
    local ++pass_count
}
else {
    display as error "  FAIL: V7a - Indicators are always 0 or 1 (error `=_rc')"
    local ++fail_count
}

* V7b: Prevalence in summary matrix is between 0 and 100
local ++test_count
capture noisily {
    clear
    set obs 50
    gen str10 dx1 = "E110"
    codescan dx1, define(dm2 "E11")
    matrix S = r(summary)
    assert S[1,2] >= 0 & S[1,2] <= 100
}
if _rc == 0 {
    display as result "  PASS: V7b - Prevalence between 0 and 100"
    local ++pass_count
}
else {
    display as error "  FAIL: V7b - Prevalence between 0 and 100 (error `=_rc')"
    local ++fail_count
}

* V7c: 100% prevalence when all rows match
local ++test_count
capture noisily {
    clear
    set obs 10
    gen str10 dx1 = "E110"
    codescan dx1, define(dm2 "E11")
    matrix S = r(summary)
    assert abs(S[1,2] - 100.0) < 0.01
    assert S[1,1] == 10
}
if _rc == 0 {
    display as result "  PASS: V7c - 100% prevalence when all match"
    local ++pass_count
}
else {
    display as error "  FAIL: V7c - 100% prevalence when all match (error `=_rc')"
    local ++fail_count
}

* V7d: 0% prevalence when no rows match
local ++test_count
capture noisily {
    clear
    set obs 10
    gen str10 dx1 = "Z00"
    codescan dx1, define(dm2 "E11")
    matrix S = r(summary)
    assert S[1,2] == 0
    assert S[1,1] == 0
}
if _rc == 0 {
    display as result "  PASS: V7d - 0% prevalence when none match"
    local ++pass_count
}
else {
    display as error "  FAIL: V7d - 0% prevalence when none match (error `=_rc')"
    local ++fail_count
}

* V7e: Collapse preserves — every patient dm2==1 has at least one
*       matching row in the original data
local ++test_count
capture noisily {
    clear
    input long pid str10 dx1
    1 "E110"
    1 "Z00"
    2 "Z00"
    2 "Z01"
    3 "Z00"
    3 "E119"
    4 "Z00"
    4 "Z00"
    end

    * Pre-collapse: count patients with at least one E11 code
    gen byte has_dm2 = regexm(dx1, "^(E11)")
    bysort pid: egen byte any_dm2 = max(has_dm2)
    quietly tab pid if any_dm2 == 1
    local expected_patients = r(r)
    drop has_dm2 any_dm2

    codescan dx1, define(dm2 "E11") id(pid) collapse

    quietly count if dm2 == 1
    assert r(N) == `expected_patients'
}
if _rc == 0 {
    display as result "  PASS: V7e - Collapse patient count matches manual count"
    local ++pass_count
}
else {
    display as error "  FAIL: V7e - Collapse patient count matches manual count (error `=_rc')"
    local ++fail_count
}

* V7f: earliestdate <= latestdate for every patient with a match
local ++test_count
capture noisily {
    clear
    input long pid str10 dx1 double visit_dt
    1 "E110" 21900
    1 "E119" 21950
    2 "E110" 21920
    3 "Z00"  21900
    3 "Z01"  21910
    end
    gen double index_dt = 22000
    format visit_dt index_dt %td

    codescan dx1, define(dm2 "E11") id(pid) date(visit_dt) collapse ///
        earliestdate latestdate
    assert dm2_first <= dm2_last if dm2 == 1
}
if _rc == 0 {
    display as result "  PASS: V7f - earliestdate <= latestdate invariant"
    local ++pass_count
}
else {
    display as error "  FAIL: V7f - earliestdate <= latestdate invariant (error `=_rc')"
    local ++fail_count
}


* ============================================================
* V8: Regex vs Prefix Mode Equivalence
* ============================================================
* For simple prefix patterns (no regex metacharacters), regex and prefix
* modes should produce identical results

local ++test_count
capture noisily {
    clear
    input str10 dx1
    "E110"
    "E119"
    "E660"
    "I10"
    "J45"
    "Z00"
    end

    * Regex mode
    codescan dx1, define(dm2 "E11")
    rename dm2 dm2_regex

    * Prefix mode
    codescan dx1, define(dm2 "E11") mode(prefix)

    forvalues i = 1/`=_N' {
        assert dm2_regex[`i'] == dm2[`i']
    }
}
if _rc == 0 {
    display as result "  PASS: V8 - Regex and prefix mode equivalent for simple patterns"
    local ++pass_count
}
else {
    display as error "  FAIL: V8 - Regex/prefix equivalence (error `=_rc')"
    local ++fail_count
}


* ============================================================
* V9: Collapse with Time Window — End-to-End
* ============================================================
* 4 patients, 3 visits each
* index_dt = 22000 for all, lookback(100) inclusive
* Window: [21900, 22000]
*
* Patient 1: E110 on day 21895 (outside), E110 on day 21950 (inside) → dm2=1
* Patient 2: E110 on day 21800 (outside) → dm2=0
* Patient 3: E110 on day 21900 (boundary, inside) → dm2=1
* Patient 4: E110 on day 22000 (refdate, inclusive) → dm2=1

local ++test_count
capture noisily {
    clear
    input long pid str10 dx1 double visit_dt
    1 "E110" 21895
    1 "E110" 21950
    1 "Z00"  22010
    2 "E110" 21800
    2 "Z00"  21950
    2 "Z00"  22010
    3 "E110" 21900
    3 "Z00"  21950
    3 "Z00"  22010
    4 "Z00"  21950
    4 "E110" 22000
    4 "Z00"  22010
    end
    gen double index_dt = 22000
    format visit_dt index_dt %td

    codescan dx1, define(dm2 "E11") id(pid) date(visit_dt) refdate(index_dt) ///
        lookback(100) inclusive collapse earliestdate latestdate countdate

    assert _N == 4
    assert dm2 == 1 if pid == 1
    assert dm2 == 0 if pid == 2
    assert dm2 == 1 if pid == 3
    assert dm2 == 1 if pid == 4

    * Patient 1: first=21950, last=21950 (only in-window match), count=1
    assert dm2_first == 21950 if pid == 1
    assert dm2_last == 21950 if pid == 1
    assert dm2_count == 1 if pid == 1

    * Patient 2: no match
    assert missing(dm2_first) if pid == 2
    assert dm2_count == 0 if pid == 2

    * Patient 3: boundary match at 21900
    assert dm2_first == 21900 if pid == 3
    assert dm2_count == 1 if pid == 3

    * Patient 4: refdate match at 22000
    assert dm2_first == 22000 if pid == 4
    assert dm2_count == 1 if pid == 4
}
if _rc == 0 {
    display as result "  PASS: V9 - Collapse with time window end-to-end"
    local ++pass_count
}
else {
    display as error "  FAIL: V9 - Collapse with time window end-to-end (error `=_rc')"
    local ++fail_count
}


* ============================================================
* V10: countdate Tag Correctness with Mixed touse (v1.0.5)
* ============================================================
* Scenario: Within (id, date) group, first row has touse=0 (excluded by if),
* second row has touse=1 and a match. The tag must be placed on a touse=1 row.

local ++test_count
capture noisily {
    clear
    input long pid str10 dx1 str10 dx2 double visit_dt
    1 "Z00"  ""     21900
    1 "E110" ""     21900
    1 "Z00"  "E119" 21910
    2 "E110" ""     21900
    2 "Z00"  ""     21910
    end
    gen double index_dt = 22000
    format visit_dt index_dt %td

    * Exclude first row of each (pid, date) group using if
    gen byte rownum = _n
    codescan dx1 dx2 if rownum != 1, define(dm2 "E11") id(pid) date(visit_dt) collapse countdate

    * Patient 1:
    *   Date 21900: row 1 excluded (touse=0), row 2 has E110 match (touse=1) → count this
    *   Date 21910: row 3 has E119 in dx2 (touse=1) → count this
    *   Total = 2
    assert dm2_count == 2 if pid == 1

    * Patient 2:
    *   Date 21900: row 4 has E110 but rownum=4 (touse=1) → count this
    *   Date 21910: row 5 no match → don't count
    *   Total = 1
    assert dm2_count == 1 if pid == 2
}
if _rc == 0 {
    display as result "  PASS: V10 - countdate tag with mixed touse in date group"
    local ++pass_count
}
else {
    display as error "  FAIL: V10 - countdate tag with mixed touse in date group (error `=_rc')"
    local ++fail_count
}


* ============================================================
* V11: Missing ID Exclusion During Collapse (v1.0.5)
* ============================================================
* Hand-verified: rows with missing id should be excluded, not grouped

local ++test_count
capture noisily {
    clear
    input double pid str10 dx1 double visit_dt
    1    "E110" 21900
    1    "E119" 21910
    .    "E110" 21900
    .    "E119" 21910
    2    "Z00"  21900
    end
    format visit_dt %td

    codescan dx1, define(dm2 "E11") id(pid) date(visit_dt) collapse ///
        earliestdate latestdate countdate

    * Must have exactly 2 rows (pid 1 and 2), not 3
    assert _N == 2

    * Patient 1: 2 matches on 2 dates
    assert dm2 == 1 if pid == 1
    assert dm2_first == 21900 if pid == 1
    assert dm2_last == 21910 if pid == 1
    assert dm2_count == 2 if pid == 1

    * Patient 2: no match
    assert dm2 == 0 if pid == 2
    assert missing(dm2_first) if pid == 2
    assert dm2_count == 0 if pid == 2
}
if _rc == 0 {
    display as result "  PASS: V11 - Missing id excluded from collapse (hand-verified)"
    local ++pass_count
}
else {
    display as error "  FAIL: V11 - Missing id excluded from collapse (error `=_rc')"
    local ++fail_count
}


* ============================================================
* V12: Missing Date Excluded from countdate (v1.0.5)
* ============================================================
* When no time window, missing dates should NOT increment countdate

local ++test_count
capture noisily {
    clear
    input long pid str10 dx1 double visit_dt
    1 "E110" 21900
    1 "E110" .
    1 "E110" 21910
    2 "E110" .
    2 "E110" .
    end
    format visit_dt %td

    codescan dx1, define(dm2 "E11") id(pid) date(visit_dt) collapse countdate

    * Patient 1: matches on 21900, missing, 21910
    *   21900 → count. Missing → excluded. 21910 → count.
    *   Total = 2
    assert dm2_count == 2 if pid == 1

    * Patient 2: matches only on missing dates → total = 0
    assert dm2_count == 0 if pid == 2
    assert dm2 == 1 if pid == 2
}
if _rc == 0 {
    display as result "  PASS: V12 - Missing dates excluded from countdate"
    local ++pass_count
}
else {
    display as error "  FAIL: V12 - Missing dates excluded from countdate (error `=_rc')"
    local ++fail_count
}


**# Wilson Score CI Validation

**## V13a — Wilson CI hand-calculation for known prevalence
* 4 matches out of 20 = 20% prevalence
* Wilson score CI with z=1.96:
*   p_hat = 0.20, N = 20, z^2/N = 3.8416/20 = 0.19208
*   denom = 1 + 0.19208 = 1.19208
*   center = (0.20 + 0.09604) / 1.19208 = 0.24835
*   margin = 1.96 * sqrt((0.16 + 0.04802) / 20) / 1.19208
*          = 1.96 * sqrt(0.010401) / 1.19208 = 1.96 * 0.10199 / 1.19208 = 0.16769
*   ci_low  = max(0, (0.24835 - 0.16769)*100) = 8.066
*   ci_high = min(100, (0.24835 + 0.16769)*100) = 41.604
local ++test_count
capture noisily {
    clear
    set obs 20
    gen str10 dx1 = "Z00"
    replace dx1 = "E110" in 1
    replace dx1 = "E119" in 5
    replace dx1 = "E110" in 10
    replace dx1 = "E111" in 15

    codescan dx1, define(dm2 "E11")
    matrix S = r(summary)

    * count = 4
    assert S[1,1] == 4
    * prevalence = 20.0
    assert abs(S[1,2] - 20.0) < 0.01

    * Wilson CI bounds (hand-computed above)
    assert abs(S[1,3] - 8.066) < 0.5
    assert abs(S[1,4] - 41.604) < 0.5
    * Ordering: low <= prev <= high
    assert S[1,3] <= S[1,2]
    assert S[1,4] >= S[1,2]
}
if _rc == 0 {
    display as result "  PASS: V13a - Wilson CI hand-calculation (20%, N=20)"
    local ++pass_count
}
else {
    display as error "  FAIL: V13a - Wilson CI hand-calculation (error `=_rc')"
    local ++fail_count
}

**## V13b — Wilson CI: 100% prevalence → CI upper bound = 100
local ++test_count
capture noisily {
    clear
    set obs 10
    gen str10 dx1 = "E110"
    codescan dx1, define(dm2 "E11")
    matrix S = r(summary)
    assert abs(S[1,2] - 100.0) < 0.01
    assert abs(S[1,4] - 100) < 0.001
    assert S[1,3] > 0
}
if _rc == 0 {
    display as result "  PASS: V13b - Wilson CI at 100% prevalence"
    local ++pass_count
}
else {
    display as error "  FAIL: V13b - Wilson CI 100% (error `=_rc')"
    local ++fail_count
}

**## V13c — Wilson CI: 0% prevalence → CI lower bound = 0, upper bound > 0
* Wilson CI at 0%: lower bound clamped to 0, but upper bound is positive
* (this is a property of the Wilson score — even with 0 successes, there is
* a plausible upper bound for the proportion)
local ++test_count
capture noisily {
    clear
    set obs 10
    gen str10 dx1 = "Z00"
    codescan dx1, define(dm2 "E11")
    matrix S = r(summary)
    assert S[1,2] == 0
    assert S[1,3] == 0
    * Upper bound should be > 0 (Wilson property)
    assert S[1,4] > 0
    assert S[1,4] < 100
}
if _rc == 0 {
    display as result "  PASS: V13c - Wilson CI at 0% prevalence"
    local ++pass_count
}
else {
    display as error "  FAIL: V13c - Wilson CI 0% (error `=_rc')"
    local ++fail_count
}


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
* NEW: Wilson CI at Non-Default Level
* ============================================================

**## V43 — Wilson CI at 90% is narrower than at 95% (invariant)
local ++test_count
capture noisily {
    local _orig_level = c(level)
    clear
    set obs 20
    gen str10 dx1 = ""
    replace dx1 = "E110" if _n <= 5
    replace dx1 = "Z00"  if _n > 5

    set level 95
    codescan dx1, define(dm2 "E11") replace
    matrix S95 = r(summary)
    local w95 = S95[1,4] - S95[1,3]

    set level 90
    codescan dx1, define(dm2 "E11") replace
    matrix S90 = r(summary)
    local w90 = S90[1,4] - S90[1,3]

    * 90% CI must be strictly narrower
    assert `w90' < `w95'
    * Prevalence unchanged
    assert abs(S95[1,2] - S90[1,2]) < 0.001
    set level `_orig_level'
}
if _rc == 0 {
    display as result "  PASS: V43 - Wilson CI 90% narrower than 95%"
    local ++pass_count
}
else {
    display as error "  FAIL: V43 - Wilson CI level invariant (error `=_rc')"
    local ++fail_count
    capture set level 95
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
        assert S[`i',3] >= 0
        assert S[`i',4] <= 100
        assert S[`i',3] <= S[`i',4]
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
display as result "RESULT: validation_codescan tests=`test_count' pass=`pass_count' fail=`fail_count'"
display as result "Validation Results: `pass_count'/`test_count' passed, `fail_count' failed"

if `fail_count' > 0 {
    display as error "SOME VALIDATIONS FAILED"
    exit 1
}
else {
    display as result "ALL VALIDATIONS PASSED"
}
