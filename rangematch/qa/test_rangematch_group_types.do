* test_rangematch_group_types.do
* Regression coverage for RM-C04: the direct numeric by() group-ID fast path
* must not silently truncate a using-only group key when the master and using
* by-variable storage types differ.
*
* The fast path is eligible only when the by-variable is a single positive
* integer variable with no missings and max(code) <= N_master + N_using. It
* reuses the by-variable directly as the group ID, bypassing the catalog merge
* that otherwise widens the master key. For full-outer output the using key is
* then written into the master-typed output column, so a `long' code of 1000
* written into a `byte' column becomes missing -- at rc=0, and only once N is
* large enough to make the fast path eligible.
*
* These tests FAIL on the shipped 1.3.3 code (output group is missing).
* The control cases pin that the catalog path was already correct, so the
* defect is specific to fast-path eligibility.

capture ado uninstall rangematch
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

quietly net install rangematch, from("`pkg_dir'") replace

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

* Force direct-path eligibility: nmaster must exceed the largest group code so
* that max(code) <= N_master + N_using holds. The using row is in a group of
* its own (code `ucode') that no master row shares, so it can only reach the
* output via the unmatched-using fill.
capture program drop _rm_group_case
program define _rm_group_case
    args mtype utype ucode nmaster
    clear
    quietly set obs 1
    quietly gen `utype' grp = `ucode'
    quietly gen double key = 50
    quietly gen long uid = 7
    tempfile u
    quietly save "`u'"
    clear
    quietly set obs `nmaster'
    quietly gen `mtype' grp = 1
    quietly gen double mlow = 0
    quietly gen double mhigh = 10
    quietly rangematch key mlow mhigh using "`u'", by(grp) ///
        unmatched(using) keepusing(uid)
end

**# T1: byte master / long using, code 1000 -- the reported RM-C04 case
local ++test_count
capture noisily {
    _rm_group_case byte long 1000 1000
    * The using-only row must retain its group key, not become missing.
    quietly count if uid == 7 & grp == 1000
    assert r(N) == 1
    quietly count if missing(grp)
    assert r(N) == 0
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: byte/long code 1000 survives the direct path"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' T1_byte_long"
    display as error "FAIL: byte/long group overflow"
}

**# T2: integer width permutations across the fast-path threshold
local ++test_count
capture noisily {
    * (master type, using type, using code) triples whose code does not fit the
    * master type. nmaster is chosen > code to keep the direct path eligible.
    foreach spec in "byte int 200" "byte long 1000" "int long 40000" {
        local mt : word 1 of `spec'
        local ut : word 2 of `spec'
        local uc : word 3 of `spec'
        local nm = `uc' + 1
        _rm_group_case `mt' `ut' `uc' `nm'
        quietly count if uid == 7 & grp == `uc'
        assert r(N) == 1
        quietly count if missing(grp)
        assert r(N) == 0
    }
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: byte/int, byte/long, int/long permutations"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' T2_width_permutations"
    display as error "FAIL: integer width permutations"
}

**# T3: values at storage boundaries
*       byte holds up to 100 before Stata's missing range; int up to 32,740.
local ++test_count
capture noisily {
    _rm_group_case byte int 200 250
    quietly count if uid == 7 & grp == 200
    assert r(N) == 1
    _rm_group_case int long 32741 32800
    quietly count if uid == 7 & grp == 32741
    assert r(N) == 1
    quietly count if missing(grp)
    assert r(N) == 0
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: values just past each storage boundary survive"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' T3_boundaries"
    display as error "FAIL: storage boundary values"
}

**# T4: output storage type is wide enough to hold the value (not just equal)
local ++test_count
capture noisily {
    _rm_group_case byte long 1000 1000
    local gtype : type grp
    * byte cannot represent 1000; the fallback must have widened the column.
    assert "`gtype'" != "byte"
    quietly summarize grp, meanonly
    assert r(max) == 1000
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: output group column widened to hold the key"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' T4_storage_type"
    display as error "FAIL: output group storage type"
}

**# T5: unmatched(both) exercises the same full-outer fill
local ++test_count
capture noisily {
    clear
    quietly set obs 1
    quietly gen long grp = 1000
    quietly gen double key = 50
    quietly gen long uid = 7
    tempfile u5
    quietly save "`u5'"
    clear
    quietly set obs 1000
    quietly gen byte grp = 1
    quietly gen double mlow = 0
    quietly gen double mhigh = 10
    rangematch key mlow mhigh using "`u5'", by(grp) unmatched(both) ///
        keepusing(uid)
    quietly count if uid == 7 & grp == 1000
    assert r(N) == 1
    quietly count if missing(grp)
    assert r(N) == 0
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: unmatched(both) preserves the using group key"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' T5_unmatched_both"
    display as error "FAIL: unmatched(both) group key"
}

**# T6: CONTROL -- identical types keep using the direct path and still match
local ++test_count
capture noisily {
    clear
    quietly set obs 2
    quietly gen long grp = _n
    quietly gen double key = 5
    quietly gen long uid = 100 + _n
    tempfile u6
    quietly save "`u6'"
    clear
    quietly set obs 2
    quietly gen long grp = _n
    quietly gen double mlow = 0
    quietly gen double mhigh = 10
    rangematch key mlow mhigh using "`u6'", by(grp) keepusing(uid)
    * Capture returns BEFORE any count: count overwrites r().
    local n_matched = r(N_matched_pairs)
    * Same-type by() must still match within group and never cross groups.
    quietly count
    assert r(N) == 2
    assert uid == 100 + grp
    assert `n_matched' == 2
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: same-type by() matching unchanged"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' T6_control_same_type"
    display as error "FAIL: same-type by() control regressed"
}

**# T7: CONTROL -- negative/zero codes force the catalog path and still work
local ++test_count
capture noisily {
    clear
    quietly set obs 2
    quietly gen long grp = _n - 1
    quietly gen double key = 5
    quietly gen long uid = 100 + _n
    tempfile u7
    quietly save "`u7'"
    clear
    quietly set obs 2
    quietly gen long grp = _n - 1
    quietly gen double mlow = 0
    quietly gen double mhigh = 10
    rangematch key mlow mhigh using "`u7'", by(grp) keepusing(uid)
    quietly count
    assert r(N) == 2
    assert uid == 101 if grp == 0
    assert uid == 102 if grp == 1
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: zero/negative codes via catalog path unchanged"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' T7_control_catalog"
    display as error "FAIL: catalog path control regressed"
}

**# T8: CONTROL -- string by() key of differing width is preserved
local ++test_count
capture noisily {
    clear
    quietly set obs 1
    quietly gen str10 grp = "bbbbbbbbbb"
    quietly gen double key = 50
    quietly gen long uid = 7
    tempfile u8
    quietly save "`u8'"
    clear
    quietly set obs 100
    quietly gen str3 grp = "aaa"
    quietly gen double mlow = 0
    quietly gen double mhigh = 10
    rangematch key mlow mhigh using "`u8'", by(grp) unmatched(using) ///
        keepusing(uid)
    quietly count if uid == 7 & grp == "bbbbbbbbbb"
    assert r(N) == 1
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: wider string by() key preserved"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' T8_control_string"
    display as error "FAIL: string by() width control"
}

capture program drop _rm_group_case

display as result _newline "GROUP TYPES TEST SUMMARY"
display as result "Tests:  `test_count'"
display as result "Passed: `pass_count'"
display as result "Failed: `fail_count'"
if `fail_count' > 0 {
    display as error "Failed tests:`failed_tests'"
    display "RESULT: test_rangematch_group_types tests=`test_count' pass=`pass_count' fail=`fail_count'"
    exit 9
}
display "RESULT: test_rangematch_group_types tests=`test_count' pass=`pass_count' fail=`fail_count'"
