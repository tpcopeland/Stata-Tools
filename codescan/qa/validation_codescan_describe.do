* validation_codescan_describe.do - Known-answer validation for codescan_describe
* Date: 2026-04-17

clear all
set seed 86420
version 16.0

local test_count = 0
local pass_count = 0
local fail_count = 0

* Bootstrap: derive package root from qa/ working directory
local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)

capture ado uninstall codescan
quietly net install codescan, from("`pkg_dir'") replace

* ============================================================
* V1: top_codes exact counts, percents, and cumulative percents
* ============================================================

local ++test_count
capture noisily {
    clear
    input str10 dx1 str10 dx2
    "E110" "I10"
    "E110" "I10"
    "E110" "I10"
    "J45"  "A123"
    ""     "A123"
    ""     "I10"
    end

    codescan_describe dx1 dx2, top(4)
    matrix TC = r(top_codes)

    assert r(n_unique) == 4
    assert r(n_entries) == 10
    assert r(n_vars) == 2
    assert rowsof(TC) == 4
    assert colsof(TC) == 3

    assert TC[1,1] == 4
    assert abs(TC[1,2] - 40) < 1e-8
    assert abs(TC[1,3] - 40) < 1e-8

    assert TC[2,1] == 3
    assert abs(TC[2,2] - 30) < 1e-8
    assert abs(TC[2,3] - 70) < 1e-8

    assert TC[3,1] == 2
    assert abs(TC[3,2] - 20) < 1e-8
    assert abs(TC[3,3] - 90) < 1e-8

    assert TC[4,1] == 1
    assert abs(TC[4,2] - 10) < 1e-8
    assert abs(TC[4,3] - 100) < 1e-8

    matrix drop TC
}
if _rc == 0 {
    display as result "  PASS: V1 - top_codes exact counts and cumulative percents"
    local ++pass_count
}
else {
    display as error "  FAIL: V1 - top_codes exact counts (error `=_rc')"
    local ++fail_count
}

* ============================================================
* V2: chapter summary exact codes/entries and conservation
* ============================================================

local ++test_count
capture noisily {
    clear
    input str10 dx1 str10 dx2
    "E110" "I10"
    "E110" "I10"
    "E110" "I10"
    "J45"  "A123"
    ""     "A123"
    ""     "I10"
    end

    codescan_describe dx1 dx2, top(4)
    matrix CH = r(chapters)

    assert rowsof(CH) == 4
    assert colsof(CH) == 2

    * Distinct entry totals force the order: I, E, A, J
    assert CH[1,1] == 1
    assert CH[1,2] == 4
    assert CH[2,1] == 1
    assert CH[2,2] == 3
    assert CH[3,1] == 1
    assert CH[3,2] == 2
    assert CH[4,1] == 1
    assert CH[4,2] == 1

    local total_codes = CH[1,1] + CH[2,1] + CH[3,1] + CH[4,1]
    local total_entries = CH[1,2] + CH[2,2] + CH[3,2] + CH[4,2]
    assert `total_codes' == r(n_unique)
    assert `total_entries' == r(n_entries)

    matrix drop CH
}
if _rc == 0 {
    display as result "  PASS: V2 - chapter summary exact and conservative"
    local ++pass_count
}
else {
    display as error "  FAIL: V2 - chapter summary exact (error `=_rc')"
    local ++fail_count
}

* ============================================================
* V3: nodots merges dotted and undotted variants
* ============================================================

local ++test_count
capture noisily {
    clear
    input str10 dx1
    "E11.0"
    "E110"
    "E11.0"
    "I10.1"
    end

    codescan_describe dx1
    assert r(n_unique) == 3
    assert r(n_entries) == 4
    matrix TC0 = r(top_codes)
    assert TC0[1,1] == 2
    matrix drop TC0

    codescan_describe dx1, nodots
    assert r(n_unique) == 2
    assert r(n_entries) == 4
    matrix TC1 = r(top_codes)
    assert TC1[1,1] == 3
    assert abs(TC1[1,2] - 75) < 1e-8
    assert abs(TC1[2,2] - 25) < 1e-8
    matrix drop TC1
}
if _rc == 0 {
    display as result "  PASS: V3 - nodots merges dotted and undotted codes"
    local ++pass_count
}
else {
    display as error "  FAIL: V3 - nodots known-answer validation (error `=_rc')"
    local ++fail_count
}

* ============================================================
* V4: tostring matches manual string conversion
* ============================================================

local ++test_count
capture noisily {
    clear
    input double code1 double code2
    110 .
    110 999
    999 110
    end

    codescan_describe code1 code2, tostring
    scalar n_unique_auto = r(n_unique)
    scalar n_entries_auto = r(n_entries)
    matrix TC_auto = r(top_codes)
    matrix CH_auto = r(chapters)

    clear
    input double code1 double code2
    110 .
    110 999
    999 110
    end
    tostring code1 code2, replace force
    codescan_describe code1 code2
    scalar n_unique_manual = r(n_unique)
    scalar n_entries_manual = r(n_entries)
    matrix TC_manual = r(top_codes)
    matrix CH_manual = r(chapters)

    assert n_unique_auto == n_unique_manual
    assert n_entries_auto == n_entries_manual
    assert rowsof(TC_auto) == rowsof(TC_manual)
    assert colsof(TC_auto) == colsof(TC_manual)
    assert TC_auto[1,1] == TC_manual[1,1]
    assert TC_auto[2,1] == TC_manual[2,1]
    assert CH_auto[1,2] == CH_manual[1,2]
    assert CH_auto[2,2] == CH_manual[2,2]

    matrix drop TC_auto
    matrix drop TC_manual
    matrix drop CH_auto
    matrix drop CH_manual
    scalar drop n_unique_auto
    scalar drop n_entries_auto
    scalar drop n_unique_manual
    scalar drop n_entries_manual
}
if _rc == 0 {
    display as result "  PASS: V4 - tostring equals manual string conversion"
    local ++pass_count
}
else {
    display as error "  FAIL: V4 - tostring equivalence (error `=_rc')"
    local ++fail_count
}

* ============================================================
* V5: all-empty codes return zero-filled matrices
* ============================================================

local ++test_count
capture noisily {
    clear
    input str10 dx1 str10 dx2
    "" ""
    "" ""
    "" ""
    end

    codescan_describe dx1 dx2
    assert r(n_unique) == 0
    assert r(n_entries) == 0
    assert r(n_vars) == 2

    matrix TC = r(top_codes)
    matrix CH = r(chapters)
    assert rowsof(TC) == 1
    assert colsof(TC) == 3
    assert rowsof(CH) == 1
    assert colsof(CH) == 2
    assert TC[1,1] == 0
    assert TC[1,2] == 0
    assert TC[1,3] == 0
    assert CH[1,1] == 0
    assert CH[1,2] == 0
    matrix drop TC
    matrix drop CH
}
if _rc == 0 {
    display as result "  PASS: V5 - empty-code case returns zero matrices"
    local ++pass_count
}
else {
    display as error "  FAIL: V5 - empty-code zero matrices (error `=_rc')"
    local ++fail_count
}

display ""
display as result "RESULT: validation_codescan_describe tests=`test_count' pass=`pass_count' fail=`fail_count'"
display as result "Validation Results: `pass_count'/`test_count' passed, `fail_count' failed"

if `fail_count' > 0 {
    display as error "SOME VALIDATIONS FAILED"
    exit 1
}
else {
    display as result "ALL VALIDATIONS PASSED"
}
