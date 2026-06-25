* validation_codescan_known_answers.do - Core known-answer validation for codescan

clear all
version 16.0
set seed 12345

local test_count = 0
local pass_count = 0
local fail_count = 0

local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)

capture ado uninstall codescan
quietly net install codescan, from("`pkg_dir'") replace

**# Matching Semantics

local ++test_count
capture noisily {
    clear
    input str12 code byte exp_regex byte exp_prefix byte exp_excl byte exp_nocase
    "E110"   1 1 1 1
    "E116"   1 1 0 0
    "E1160"  1 1 0 0
    "E117"   1 1 1 1
    "AE110"  0 0 0 0
    "e110"   0 0 0 1
    "E11.0"  1 1 1 1
    ""       0 0 0 0
    end

    codescan code, define(dm2 "E11")
    rename dm2 got_regex

    codescan code, define(dm2 "E11") mode(prefix)
    rename dm2 got_prefix

    codescan code, define(dm2 "E11" ~ "E116") replace
    rename dm2 got_excl

    codescan code, define(dm2 "E11" ~ "E116") nocase replace
    rename dm2 got_nocase

    forvalues i = 1/`=_N' {
        assert got_regex[`i'] == exp_regex[`i']
        assert got_prefix[`i'] == exp_prefix[`i']
        assert got_excl[`i'] == exp_excl[`i']
        assert got_nocase[`i'] == exp_nocase[`i']
    }
}
if _rc == 0 {
    display as result "  PASS: matching modes, exclusion, and nocase known answers"
    local ++pass_count
}
else {
    display as error "  FAIL: matching modes, exclusion, and nocase known answers (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    clear
    input str12 code byte exp_regex byte exp_prefix
    "I10"  1 0
    "I11"  1 0
    "I13"  1 0
    "I15"  1 0
    "I16"  0 0
    "I10X" 1 0
    "I1[0-35]" 0 1
    end

    codescan code, define(htn "I1[0-35]")
    rename htn got_regex

    codescan code, define(htn "I1[0-35]") mode(prefix)
    rename htn got_prefix

    forvalues i = 1/`=_N' {
        assert got_regex[`i'] == exp_regex[`i']
        assert got_prefix[`i'] == exp_prefix[`i']
    }
}
if _rc == 0 {
    display as result "  PASS: regex character class differs from literal prefix"
    local ++pass_count
}
else {
    display as error "  FAIL: regex character class differs from literal prefix (error `=_rc')"
    local ++fail_count
}

**# Date Windows

local ++test_count
capture noisily {
    clear
    input str12 scenario str10 dx1 double visit_dt double index_dt ///
        byte exp_lb byte exp_lb_inc byte exp_lf byte exp_lf_inc byte exp_both
    "pre_out" "E110" 21549 21915 0 0 0 0 0
    "lb_lo"   "E110" 21550 21915 1 1 0 0 1
    "pre_in"  "E110" 21914 21915 1 1 0 0 1
    "ref"     "E110" 21915 21915 0 1 0 1 1
    "post_in" "E110" 21916 21915 0 0 1 1 1
    "lf_hi"   "E110" 22280 21915 0 0 1 1 1
    "post_out" "E110" 22281 21915 0 0 0 0 0
    "miss_d"  "E110" .     21915 0 0 0 0 0
    "miss_r"  "E110" 21914 .     0 0 0 0 0
    end
    format visit_dt index_dt %td

    codescan dx1, define(dm2 "E11") date(visit_dt) refdate(index_dt) lookback(365)
    rename dm2 got_lb

    codescan dx1, define(dm2 "E11") date(visit_dt) refdate(index_dt) ///
        lookback(365) inclusive
    rename dm2 got_lb_inc

    codescan dx1, define(dm2 "E11") date(visit_dt) refdate(index_dt) ///
        lookforward(365)
    rename dm2 got_lf

    codescan dx1, define(dm2 "E11") date(visit_dt) refdate(index_dt) ///
        lookforward(365) inclusive
    rename dm2 got_lf_inc

    codescan dx1, define(dm2 "E11") date(visit_dt) refdate(index_dt) ///
        lookback(365) lookforward(365)
    rename dm2 got_both

    forvalues i = 1/`=_N' {
        assert got_lb[`i'] == exp_lb[`i']
        assert got_lb_inc[`i'] == exp_lb_inc[`i']
        assert got_lf[`i'] == exp_lf[`i']
        assert got_lf_inc[`i'] == exp_lf_inc[`i']
        assert got_both[`i'] == exp_both[`i']
    }
}
if _rc == 0 {
    display as result "  PASS: date window boundaries and missing dates"
    local ++pass_count
}
else {
    display as error "  FAIL: date window boundaries and missing dates (error `=_rc')"
    local ++fail_count
}

**# Collapse, Merge, Counts, and Date Summaries

local ++test_count
capture noisily {
    clear
    input long pid str10 dx1 str10 dx2 double visit_dt
    1 "E110" "I10" 21900
    1 "E119" ""    21900
    1 "E116" "I13" 21910
    1 "Z00"  ""    21920
    2 "Z00"  "I10" 21900
    2 "E111" ""    21915
    3 "Z00"  ""    21900
    3 ""     ""    .
    end
    format visit_dt %td

    codescan dx1 dx2, define(dm2 "E11" ~ "E116" | htn "I1[0-35]") ///
        id(pid) date(visit_dt) collapse alldates countrows countmode

    sort pid
    assert _N == 3

    assert pid[1] == 1
    assert dm2[1] == 2
    assert dm2_first[1] == 21900
    assert dm2_last[1] == 21900
    assert dm2_count[1] == 1
    assert dm2_nrows[1] == 2
    assert htn[1] == 2
    assert htn_first[1] == 21900
    assert htn_last[1] == 21910
    assert htn_count[1] == 2
    assert htn_nrows[1] == 2

    assert pid[2] == 2
    assert dm2[2] == 1
    assert dm2_first[2] == 21915
    assert dm2_last[2] == 21915
    assert dm2_count[2] == 1
    assert dm2_nrows[2] == 1
    assert htn[2] == 1
    assert htn_first[2] == 21900
    assert htn_count[2] == 1

    assert pid[3] == 3
    assert dm2[3] == 0
    assert htn[3] == 0
    assert missing(dm2_first[3])
    assert dm2_count[3] == 0
    assert dm2_nrows[3] == 0

    local rN = r(N)
    local rcond "`r(conditions)'"
    local rnew "`r(newvars)'"
    local rmode "`r(mode)'"
    local rcount = r(mode_count)
    matrix S = r(summary)
    matrix CL = r(codelist)

    assert `rN' == 3
    assert "`rcond'" == "dm2 htn"
    assert strpos("`rnew'", "dm2_first") > 0
    assert "`rmode'" == "regex"
    assert `rcount' == 1
    assert S[1,1] == 3
    assert abs(S[1,2] - 66.6667) < 0.01
    assert S[2,1] == 3
    assert CL[1,1] == S[1,1]
    assert CL[1,2] == S[1,2]
}
if _rc == 0 {
    display as result "  PASS: collapse countmode, countrows, dates, and returns"
    local ++pass_count
}
else {
    display as error "  FAIL: collapse countmode, countrows, dates, and returns (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    clear
    input long pid str10 dx1 str10 dx2 double visit_dt byte exp_dm2 byte exp_htn
    1 "E110" ""    21900 1 1
    1 "Z00"  "I10" 21910 1 1
    2 "Z00"  ""    21900 0 1
    2 "I13"  ""    21920 0 1
    3 "Z00"  ""    21900 0 0
    end
    format visit_dt %td

    codescan dx1 dx2, define(dm2 "E11" | htn "I1[0-35]") ///
        id(pid) date(visit_dt) merge alldates countrows

    assert _N == 5
    forvalues i = 1/`=_N' {
        assert dm2[`i'] == exp_dm2[`i']
        assert htn[`i'] == exp_htn[`i']
    }
    assert dm2_first == 21900 if pid == 1
    assert dm2_count == 1 if pid == 1
    assert dm2_nrows == 1 if pid == 1
    assert htn_first == 21910 if pid == 1
    assert htn_count == 1 if pid == 1
    assert htn_nrows == 1 if pid == 1
    assert htn_first == 21920 if pid == 2
    assert htn_count == 1 if pid == 2
    assert htn_nrows == 1 if pid == 2
    assert missing(dm2_first) if pid == 3
    assert dm2_count == 0 if pid == 3
    assert r(N) == 3
    assert r(merged) == 1
    assert r(collapsed) == 0
}
if _rc == 0 {
    display as result "  PASS: merge broadcasts patient-level date summaries"
    local ++pass_count
}
else {
    display as error "  FAIL: merge broadcasts patient-level date summaries (error `=_rc')"
    local ++fail_count
}

**# Unmatched, Matched Codes, Detail, and Co-occurrence

local ++test_count
capture noisily {
    clear
    input str10 dx1 str10 dx2 byte exp_dm2 str10 exp_mc byte exp_unmatched
    "Z00"  "E110" 1 "E110" 0
    "E116" "E119" 1 "E119" 0
    "E116" ""     0 ""     1
    "I10"  ""     0 ""     1
    ""     ""     0 ""     1
    end

    codescan dx1 dx2, define(dm2 "E11" ~ "E116") ///
        unmatched(nohit) matched_code(mc) detail

    matrix V = r(varcounts)
    forvalues i = 1/`=_N' {
        assert dm2[`i'] == exp_dm2[`i']
        assert mc[`i'] == exp_mc[`i']
        assert nohit[`i'] == exp_unmatched[`i']
    }
    assert V[1,1] == 0
    assert V[1,2] == 2
}
if _rc == 0 {
    display as result "  PASS: unmatched, matched_code, and detail varcounts"
    local ++pass_count
}
else {
    display as error "  FAIL: unmatched, matched_code, and detail varcounts (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    clear
    input str10 dx1 str10 dx2
    "E110" "I10"
    "E119" ""
    "I13"  ""
    "F32"  "I10"
    "E110" "F32"
    "Z00"  ""
    end

    codescan dx1 dx2, define(dm2 "E11" | htn "I1[0-35]" | dep "F3[23]") ///
        cooccurrence
    matrix C = r(cooccurrence)

    assert C[1,1] == 3
    assert C[2,2] == 3
    assert C[3,3] == 2
    assert C[1,2] == 1
    assert C[1,3] == 1
    assert C[2,3] == 1
    forvalues i = 1/3 {
        forvalues j = 1/3 {
            assert C[`i',`j'] == C[`j',`i']
        }
    }
}
if _rc == 0 {
    display as result "  PASS: cooccurrence matrix hand-computed"
    local ++pass_count
}
else {
    display as error "  FAIL: cooccurrence matrix hand-computed (error `=_rc')"
    local ++fail_count
}

**# Sensitivity

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
    matrix MW = r(sensitivity)

    assert rowsof(MW) == 1
    assert colsof(MW) == 3
    assert abs(MW[1,1] - 50) < 0.01
    assert abs(MW[1,2] - 66.6667) < 0.01
    assert abs(MW[1,3] - 75) < 0.01
    assert "`r(lookback)'" == "30 90 365"
}
if _rc == 0 {
    display as result "  PASS: multi-window sensitivity hand-computed"
    local ++pass_count
}
else {
    display as error "  FAIL: multi-window sensitivity hand-computed (error `=_rc')"
    local ++fail_count
}

**# Summary

display as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"
display "RESULT: validation_codescan_known_answers tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 {
    exit 1
}

display as result "ALL TESTS PASSED"
