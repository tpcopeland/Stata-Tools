* validation_codescan_describe_adversarial.do - Adversarial known-answer validation for codescan_describe
* Date: 2026-05-07

clear all
version 16.0
set seed 57007
capture log close _all

local test_count = 0
local pass_count = 0
local fail_count = 0

* Bootstrap: derive package root from qa/ working directory
local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)

capture ado uninstall codescan
quietly net install codescan, from("`pkg_dir'") replace

**# Helpers

capture program drop _assert_rowname
program define _assert_rowname
    args matname row expected
    local rn : rownames `matname'
    local got : word `row' of `rn'
    assert "`got'" == "`expected'"
end

capture program drop _assert_has_rowname
program define _assert_has_rowname
    args matname expected
    local rn : rownames `matname'
    local found = 0
    foreach got of local rn {
        if "`got'" == "`expected'" local found = 1
    }
    assert `found' == 1
end

**# V1: top(), returned scalars, top_codes matrix, and chapter matrix

local ++test_count
capture noisily {
    clear
    input str8 dx1 str8 dx2 str8 dx3
    "A10" "B10" ""
    "A10" "B10" "C10"
    "A10" "B11" "C10"
    "A11" ""    "D10"
    "."   "A10" ""
    ""    "B10" ""
    "A10" ""    ""
    end

    codescan_describe dx1 dx2 dx3, top(3)

    assert r(n_unique) == 6
    assert r(n_entries) == 13
    assert r(n_vars) == 3
    assert "`r(varlist)'" == "dx1 dx2 dx3"

    matrix TC = r(top_codes)
    assert rowsof(TC) == 3
    assert colsof(TC) == 3
    _assert_rowname TC 1 A10
    _assert_rowname TC 2 B10
    _assert_rowname TC 3 C10
    assert TC[1,1] == 5
    assert abs(TC[1,2] - 100 * 5 / 13) < 1e-8
    assert abs(TC[1,3] - 100 * 5 / 13) < 1e-8
    assert TC[2,1] == 3
    assert abs(TC[2,2] - 100 * 3 / 13) < 1e-8
    assert abs(TC[2,3] - 100 * 8 / 13) < 1e-8
    assert TC[3,1] == 2
    assert abs(TC[3,2] - 100 * 2 / 13) < 1e-8
    assert abs(TC[3,3] - 100 * 10 / 13) < 1e-8

    matrix CH = r(chapters)
    assert rowsof(CH) == 4
    assert colsof(CH) == 2
    _assert_rowname CH 1 A
    _assert_rowname CH 2 B
    _assert_rowname CH 3 C
    _assert_rowname CH 4 D
    assert CH[1,1] == 2
    assert CH[1,2] == 6
    assert CH[2,1] == 2
    assert CH[2,2] == 4
    assert CH[3,1] == 1
    assert CH[3,2] == 2
    assert CH[4,1] == 1
    assert CH[4,2] == 1

    local chapter_codes = CH[1,1] + CH[2,1] + CH[3,1] + CH[4,1]
    local chapter_entries = CH[1,2] + CH[2,2] + CH[3,2] + CH[4,2]
    assert `chapter_codes' == r(n_unique)
    assert `chapter_entries' == r(n_entries)
    matrix drop TC CH
}
if _rc == 0 {
    display as result "  PASS: V1 - exact top(), return scalars, top_codes, and chapters"
    local ++pass_count
}
else {
    display as error "  FAIL: V1 - exact top()/returns matrices (error `=_rc')"
    local ++fail_count
}

**# V2: default top includes all codes when unique codes are fewer than 20

local ++test_count
capture noisily {
    clear
    input str8 dx1 str8 dx2
    "E10" "I10"
    "E11" "I10"
    "E11" "J45"
    ""    "."
    end

    codescan_describe dx1 dx2
    matrix TC = r(top_codes)
    assert r(n_unique) == 4
    assert r(n_entries) == 6
    assert rowsof(TC) == 4
    assert colsof(TC) == 3
    assert TC[1,1] >= TC[2,1]
    assert TC[2,1] >= TC[3,1]
    assert TC[3,1] >= TC[4,1]
    assert abs(TC[4,3] - 100) < 1e-8
    _assert_has_rowname TC E10
    _assert_has_rowname TC E11
    _assert_has_rowname TC I10
    _assert_has_rowname TC J45
    matrix drop TC
}
if _rc == 0 {
    display as result "  PASS: V2 - default top returns complete ordered inventory"
    local ++pass_count
}
else {
    display as error "  FAIL: V2 - default top complete inventory (error `=_rc')"
    local ++fail_count
}

**# V3: if/in restrictions apply before tabulation and keep correct returns

local ++test_count
capture noisily {
    clear
    input byte keep str8 dx1 str8 dx2
    1 "Z99" "Z99"
    1 "E1"  ""
    1 "E1"  "I1"
    1 "E2"  "I1"
    1 "."   "I1"
    0 "K1"  "K2"
    end

    codescan_describe dx1 dx2 if keep == 1 in 2/5, top(3)
    matrix TC = r(top_codes)
    matrix CH = r(chapters)

    assert r(n_unique) == 3
    assert r(n_entries) == 6
    assert r(n_vars) == 2
    _assert_rowname TC 1 I1
    _assert_rowname TC 2 E1
    _assert_rowname TC 3 E2
    assert TC[1,1] == 3
    assert TC[2,1] == 2
    assert TC[3,1] == 1
    assert rowsof(CH) == 2
    assert CH[1,2] + CH[2,2] == 6
    assert CH[1,1] + CH[2,1] == 3
    _assert_has_rowname CH E
    _assert_has_rowname CH I
    matrix drop TC CH
}
if _rc == 0 {
    display as result "  PASS: V3 - if/in restrictions produce exact inventory"
    local ++pass_count
}
else {
    display as error "  FAIL: V3 - if/in exact inventory (error `=_rc')"
    local ++fail_count
}

**# V4: nodots strips periods, skips dot-only entries, and updates row names

local ++test_count
capture noisily {
    clear
    input str8 dx1 str8 dx2
    "E11.0" "E110"
    "E11.0" "I10.1"
    "."     "I101"
    ""      "."
    end

    codescan_describe dx1 dx2, nodots top(2)
    matrix TC = r(top_codes)
    matrix CH = r(chapters)

    assert r(n_unique) == 2
    assert r(n_entries) == 5
    _assert_rowname TC 1 E110
    _assert_rowname TC 2 I101
    assert TC[1,1] == 3
    assert TC[2,1] == 2
    assert rowsof(CH) == 2
    assert CH[1,2] == 3
    assert CH[2,2] == 2
    matrix drop TC CH
}
if _rc == 0 {
    display as result "  PASS: V4 - nodots known-answer normalization"
    local ++pass_count
}
else {
    display as error "  FAIL: V4 - nodots known-answer normalization (error `=_rc')"
    local ++fail_count
}

**# V5: tostring numeric conversion matches a hand-built string oracle

local ++test_count
capture noisily {
    clear
    input double n1 double n2
    101 202
    101 .
    303 202
    .   .
    end

    codescan_describe n1 n2, tostring top(3)
    scalar auto_unique = r(n_unique)
    scalar auto_entries = r(n_entries)
    matrix AUTO_TC = r(top_codes)
    matrix AUTO_CH = r(chapters)

    clear
    input str8 s1 str8 s2
    "101" "202"
    "101" "."
    "303" "202"
    "."   "."
    end

    codescan_describe s1 s2, top(3)
    matrix MANUAL_TC = r(top_codes)
    matrix MANUAL_CH = r(chapters)

    assert auto_unique == r(n_unique)
    assert auto_entries == r(n_entries)
    assert AUTO_TC[1,1] == MANUAL_TC[1,1]
    assert AUTO_TC[2,1] == MANUAL_TC[2,1]
    assert AUTO_TC[3,1] == MANUAL_TC[3,1]
    assert AUTO_CH[1,1] == MANUAL_CH[1,1]
    assert AUTO_CH[1,2] == MANUAL_CH[1,2]
    _assert_has_rowname AUTO_TC 101
    _assert_has_rowname AUTO_TC 202
    _assert_has_rowname AUTO_TC 303
    matrix drop AUTO_TC AUTO_CH MANUAL_TC MANUAL_CH
    scalar drop auto_unique auto_entries
}
if _rc == 0 {
    display as result "  PASS: V5 - tostring matches string oracle"
    local ++pass_count
}
else {
    display as error "  FAIL: V5 - tostring string oracle (error `=_rc')"
    local ++fail_count
}

**# V6: ties are frequency-ordered and preserve tied set membership

local ++test_count
capture noisily {
    clear
    input str8 dx1 str8 dx2
    "A1" "B1"
    "A1" "B1"
    "C1" "D1"
    "C1" "D1"
    "E1" ""
    end

    codescan_describe dx1 dx2, top(4)
    matrix TC = r(top_codes)

    assert r(n_unique) == 5
    assert r(n_entries) == 9
    assert rowsof(TC) == 4
    forvalues i = 1/3 {
        assert TC[`i',1] >= TC[`=`i' + 1',1]
    }
    forvalues i = 1/4 {
        assert TC[`i',1] == 2
        assert abs(TC[`i',2] - 100 * 2 / 9) < 1e-8
    }
    _assert_has_rowname TC A1
    _assert_has_rowname TC B1
    _assert_has_rowname TC C1
    _assert_has_rowname TC D1
    matrix drop TC
}
if _rc == 0 {
    display as result "  PASS: V6 - tied top codes preserve frequency and membership"
    local ++pass_count
}
else {
    display as error "  FAIL: V6 - tied top-code semantics (error `=_rc')"
    local ++fail_count
}

**# V7: all empty and dot entries return the documented no-code matrices

local ++test_count
capture noisily {
    clear
    input str8 dx1 str8 dx2
    ""  "."
    "." ""
    ""  ""
    end

    codescan_describe dx1 dx2
    matrix TC = r(top_codes)
    matrix CH = r(chapters)

    assert r(n_unique) == 0
    assert r(n_entries) == 0
    assert r(n_vars) == 2
    assert "`r(varlist)'" == "dx1 dx2"
    assert rowsof(TC) == 1
    assert colsof(TC) == 3
    assert rowsof(CH) == 1
    assert colsof(CH) == 2
    _assert_rowname TC 1 none
    _assert_rowname CH 1 none
    assert TC[1,1] == 0
    assert TC[1,2] == 0
    assert TC[1,3] == 0
    assert CH[1,1] == 0
    assert CH[1,2] == 0
    matrix drop TC CH
}
if _rc == 0 {
    display as result "  PASS: V7 - no-code path returns zero matrices"
    local ++pass_count
}
else {
    display as error "  FAIL: V7 - no-code zero-matrix path (error `=_rc')"
    local ++fail_count
}

**# V8: save() writes exact chapter draft and leaves caller data intact

local ++test_count
capture noisily {
    clear
    input long id str8 dx1 str8 dx2
    3 "A10" "B10"
    1 "A11" "B10"
    2 "C10" ""
    end
    tempfile before out
    local csv "`out'.csv"
    save "`before'", replace

    codescan_describe dx1 dx2, save("`csv'")

    cf _all using "`before'"
    import delimited using "`csv'", clear stringcols(_all) varnames(1)
    assert _N == 3
    count if name == "chapter_A" & pattern == "A" & exclusion == "" & label == ""
    assert r(N) == 1
    count if name == "chapter_B" & pattern == "B" & exclusion == "" & label == ""
    assert r(N) == 1
    count if name == "chapter_C" & pattern == "C" & exclusion == "" & label == ""
    assert r(N) == 1
}
if _rc == 0 {
    display as result "  PASS: V8 - save() exact CSV and data preservation"
    local ++pass_count
}
else {
    display as error "  FAIL: V8 - save() exact CSV/data preservation (error `=_rc')"
    local ++fail_count
}

**# V9: tostring, nodots, and oversized top() compose correctly

local ++test_count
capture noisily {
    clear
    input double n1 double n2
    110.1 1101
    110.1 .
    220.2 2202
    .     .
    end

    codescan_describe n1 n2, tostring nodots top(99)
    matrix TC = r(top_codes)
    matrix CH = r(chapters)

    assert r(n_unique) == 2
    assert r(n_entries) == 5
    assert rowsof(TC) == 2
    _assert_rowname TC 1 1101
    _assert_rowname TC 2 2202
    assert TC[1,1] == 3
    assert TC[2,1] == 2
    assert abs(TC[2,3] - 100) < 1e-8
    assert rowsof(CH) == 2
    assert CH[1,2] == 3
    assert CH[2,2] == 2
    matrix drop TC CH
}
if _rc == 0 {
    display as result "  PASS: V9 - tostring nodots oversized top() composition"
    local ++pass_count
}
else {
    display as error "  FAIL: V9 - tostring nodots oversized top() composition (error `=_rc')"
    local ++fail_count
}

**# Summary

display as result "RESULT: validation_codescan_describe_adversarial tests=`test_count' pass=`pass_count' fail=`fail_count'"
display as result "Validation Results: `pass_count'/`test_count' passed, `fail_count' failed"

if `fail_count' > 0 {
    display as error "SOME VALIDATIONS FAILED"
    exit 1
}

display as result "ALL VALIDATIONS PASSED"
