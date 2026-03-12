* validation_codescan.do - Correctness validation for codescan
* Date: 2026-03-13

clear all
set more off
set seed 12345
version 16.0

local test_count = 0
local pass_count = 0
local fail_count = 0

capture ado uninstall codescan
quietly net install codescan, from("~/Stata-Tools/codescan")


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
* Summary
* ============================================================

display as text ""
display as result "Validation Results: `pass_count'/`test_count' passed, `fail_count' failed"

if `fail_count' > 0 {
    display as error "SOME VALIDATIONS FAILED"
    exit 1
}
else {
    display as result "ALL VALIDATIONS PASSED"
}
