* test_rangematch_provenance.do
* Regression coverage for RM-C01: usingid() must report the ORIGINAL using
* observation number, not a post-missing(drop) row position.
*
* Oracle independence: the using data carry a marker variable uid = 100 + _n
* recorded at build time, before rangematch ever sees the data. usingid() is
* therefore correct iff it round-trips to the marker: usingid == uid - 100.
* The marker is computed from the source row number, never from any rangematch
* return, so it cannot share a defect with the code under test.
*
* On the shipped 1.3.3 code these tests FAIL: _rm_uobs (the pair index) was
* generated with _n AFTER missing(drop) physically deleted rows, so usingid()
* reported the compacted position (retained row 2 -> 1).

quietly do "`c(pwd)'/_rangematch_qa_common.do"
_rm_qa_bootstrap
clear all
version 16.1
set varabbrev off

local cwd "`c(pwd)'"
local cwd_len = strlen("`cwd'")
if substr("`cwd'", `cwd_len' - 2, 3) == "/qa" {
    local qa_dir "`cwd'"
    local pkg_dir = substr("`cwd'", 1, `cwd_len' - 3)
}
else {
    local pkg_dir "`cwd'"
    local qa_dir "`pkg_dir'/qa"
}


local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

* Build a using dataset whose missing keys sit at the FIRST and a MIDDLE row,
* so a post-drop renumbering shifts every retained row's identifier.
*   row 1: key . (dropped)   row 2: key 5   row 3: key . (dropped)
*   row 4: key 6             row 5: key 7
program define _rm_build_using
    args mode
    clear
    quietly set obs 5
    quietly gen long uid = 100 + _n
    if "`mode'" == "point" {
        quietly gen double key = .
        quietly replace key = 5 in 2
        quietly replace key = 6 in 4
        quietly replace key = 7 in 5
    }
    else {
        quietly gen double ulow = .
        quietly gen double uhigh = .
        quietly replace ulow = 5 in 2
        quietly replace uhigh = 5 in 2
        quietly replace ulow = 6 in 4
        quietly replace uhigh = 6 in 4
        quietly replace ulow = 7 in 5
        quietly replace uhigh = 7 in 5
    }
end

**# T1: point mode, file source, missing(drop) -- usingid is the ORIGINAL row
local ++test_count
capture noisily {
    _rm_build_using point
    tempfile upoint
    quietly save "`upoint'"
    clear
    quietly set obs 1
    quietly gen double mlow = 0
    quietly gen double mhigh = 10
    rangematch key mlow mhigh using "`upoint'", missing(drop) ///
        usingid(srow) keepusing(uid)
    quietly count
    assert r(N) == 3
    * The round-trip invariant. Fails on 1.3.3: srow was 1,2,3.
    assert srow == uid - 100
    quietly summarize srow, meanonly
    assert r(min) == 2 & r(max) == 5
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: point/file missing(drop) usingid is original row"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' T1_point_file"
    display as error "FAIL: point/file missing(drop) usingid"
}

**# T2: overlap mode, file source, missing(drop)
local ++test_count
capture noisily {
    _rm_build_using overlap
    tempfile uover
    quietly save "`uover'"
    clear
    quietly set obs 1
    quietly gen double mlow = 0
    quietly gen double mhigh = 10
    rangematch mlow mhigh using "`uover'", overlap(ulow uhigh) ///
        missing(drop) usingid(srow) keepusing(uid)
    quietly count
    assert r(N) == 3
    assert srow == uid - 100
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: overlap/file missing(drop) usingid is original row"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' T2_overlap_file"
    display as error "FAIL: overlap/file missing(drop) usingid"
}

**# T3: frame source -- provenance must be identical to the file source
local ++test_count
capture noisily {
    capture frame drop rm_prov_src
    frame create rm_prov_src
    frame rm_prov_src {
        _rm_build_using point
    }
    clear
    quietly set obs 1
    quietly gen double mlow = 0
    quietly gen double mhigh = 10
    rangematch key mlow mhigh using rm_prov_src, missing(drop) ///
        usingid(srow) keepusing(uid)
    quietly count
    assert r(N) == 3
    assert srow == uid - 100
    capture frame drop rm_prov_src
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: frame source missing(drop) usingid is original row"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' T3_frame"
    display as error "FAIL: frame source missing(drop) usingid"
}

**# T4: unmatched(none|using|both) all preserve provenance
local ++test_count
capture noisily {
    foreach um in none using both {
        _rm_build_using point
        tempfile u4
        quietly save "`u4'"
        clear
        quietly set obs 1
        quietly gen double mlow = 0
        quietly gen double mhigh = 5.5
        rangematch key mlow mhigh using "`u4'", missing(drop) ///
            unmatched(`um') usingid(srow) keepusing(uid)
        * Every row that carries a using record must round-trip; master-only
        * rows have no using source and must report missing.
        assert srow == uid - 100 if !missing(uid)
        assert missing(srow) if missing(uid)
        quietly count if !missing(srow)
        * key 5 matches [0,5.5]; keys 6 and 7 do not.
        if "`um'" == "none"  assert r(N) == 1
        if "`um'" == "using" assert r(N) == 3
        if "`um'" == "both"  assert r(N) == 3
    }
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: unmatched(none|using|both) preserve provenance"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' T4_unmatched"
    display as error "FAIL: unmatched() provenance"
}

**# T5: nosort preserves provenance (ordering must not renumber identifiers)
local ++test_count
capture noisily {
    _rm_build_using point
    tempfile u5
    quietly save "`u5'"
    clear
    quietly set obs 1
    quietly gen double mlow = 0
    quietly gen double mhigh = 10
    rangematch key mlow mhigh using "`u5'", missing(drop) nosort ///
        usingid(srow) keepusing(uid)
    assert srow == uid - 100
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: nosort preserves provenance"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' T5_nosort"
    display as error "FAIL: nosort provenance"
}

**# T6: missing(wildcard) -- no rows dropped, usingid still original row
local ++test_count
capture noisily {
    _rm_build_using point
    tempfile u6
    quietly save "`u6'"
    clear
    quietly set obs 1
    quietly gen double mlow = 0
    quietly gen double mhigh = 10
    rangematch key mlow mhigh using "`u6'", missing(wildcard) ///
        unmatched(both) usingid(srow) keepusing(uid)
    assert srow == uid - 100 if !missing(uid)
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: missing(wildcard) usingid is original row"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' T6_wildcard"
    display as error "FAIL: missing(wildcard) provenance"
}

**# T7: usingid() is not polluted by the private identifier leaking as a
*       carried variable (all carried names must be user variables only)
local ++test_count
capture noisily {
    _rm_build_using point
    tempfile u7
    quietly save "`u7'"
    clear
    quietly set obs 1
    quietly gen double mlow = 0
    quietly gen double mhigh = 10
    rangematch key mlow mhigh using "`u7'", missing(drop) usingid(srow)
    * Output may contain only: master vars, using vars (key, uid), srow.
    quietly describe, varlist short
    local outvars "`r(varlist)'"
    local expected "mlow mhigh key uid srow"
    local extra : list outvars - expected
    assert "`extra'" == ""
    assert srow == uid - 100
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: private original-row id does not leak into output"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' T7_no_leak"
    display as error "FAIL: private id leaked into output"
}

capture program drop _rm_build_using

display as result _newline "PROVENANCE TEST SUMMARY"
display as result "Tests:  `test_count'"
display as result "Passed: `pass_count'"
display as result "Failed: `fail_count'"
if `fail_count' > 0 {
    display as error "Failed tests:`failed_tests'"
    display "RESULT: test_rangematch_provenance tests=`test_count' pass=`pass_count' fail=`fail_count'"
    exit 9
}
display "RESULT: test_rangematch_provenance tests=`test_count' pass=`pass_count' fail=`fail_count'"
