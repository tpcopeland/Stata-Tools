* test_codescan_describe_adversarial.do - Adversarial functional tests for codescan_describe
* Date: 2026-05-07

clear all
version 16.0
set seed 57008
capture log close _all

local test_count = 0
local pass_count = 0
local fail_count = 0

* Bootstrap: derive package root from qa/ working directory
local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)

capture ado uninstall codescan
quietly net install codescan, from("`pkg_dir'") replace

**# T1: no-observation if/in path exits 2000 and restores varabbrev

local ++test_count
capture noisily {
    clear
    input byte keep str8 dx1
    0 "A10"
    0 "B10"
    0 "C10"
    end

    set varabbrev on
    capture codescan_describe dx1 if keep == 1
    assert _rc == 2000
    assert "`c(varabbrev)'" == "on"
}
if _rc == 0 {
    display as result "  PASS: T1 - no-observation path exits 2000 and restores varabbrev"
    local ++pass_count
}
else {
    display as error "  FAIL: T1 - no-observation path/varabbrev (error `=_rc')"
    local ++fail_count
}

**# T2: top() rejects zero and negative values with rc 198

local ++test_count
capture noisily {
    clear
    input str8 dx1
    "A10"
    "B10"
    end

    capture codescan_describe dx1, top(0)
    assert _rc == 198
    capture codescan_describe dx1, top(-2)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: T2 - invalid top() values rejected"
    local ++pass_count
}
else {
    display as error "  FAIL: T2 - invalid top() rejection (error `=_rc')"
    local ++fail_count
}

**# T3: numeric variables require tostring option and restore varabbrev on error

local ++test_count
capture noisily {
    clear
    input double ncode
    101
    202
    end

    set varabbrev on
    capture codescan_describe ncode
    assert _rc == 109
    assert "`c(varabbrev)'" == "on"
}
if _rc == 0 {
    display as result "  PASS: T3 - numeric variable error and varabbrev restore"
    local ++pass_count
}
else {
    display as error "  FAIL: T3 - numeric variable error/varabbrev (error `=_rc')"
    local ++fail_count
}

**# T4: tostring preserves storage types, values, observation order, and sort order

local ++test_count
capture noisily {
    clear
    input long id double ncode str8 label
    3 101 "third"
    1 202 "first"
    2 .   "second"
    end
    gen long seq = _n
    sort id
    tempfile before
    save "`before'", replace
    local sortlist : sortedby

    codescan_describe ncode, tostring

    cf _all using "`before'"
    local sort_after : sortedby
    assert "`sort_after'" == "`sortlist'"
    capture confirm numeric variable ncode
    assert _rc == 0
    assert _N == 3
}
if _rc == 0 {
    display as result "  PASS: T4 - tostring preserves caller data and sort state"
    local ++pass_count
}
else {
    display as error "  FAIL: T4 - tostring data preservation (error `=_rc')"
    local ++fail_count
}

**# T5: save() rejects non-csv paths and leaves data/varabbrev untouched

local ++test_count
capture noisily {
    clear
    input long id str8 dx1
    1 "A10"
    2 "B10"
    end
    tempfile before bad
    local badfile "`bad'.txt"
    save "`before'", replace

    set varabbrev on
    capture codescan_describe dx1, save("`badfile'")
    assert _rc == 198
    assert "`c(varabbrev)'" == "on"
    cf _all using "`before'"
    capture confirm file "`badfile'"
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: T5 - save() non-csv error preserves state"
    local ++pass_count
}
else {
    display as error "  FAIL: T5 - save() non-csv state preservation (error `=_rc')"
    local ++fail_count
}

**# T6: all-empty no-code path succeeds and does not leave stray variables

local ++test_count
capture noisily {
    clear
    input long id str8 dx1 str8 dx2
    1 ""  "."
    2 "." ""
    end
    tempfile before
    save "`before'", replace

    codescan_describe dx1 dx2

    assert r(n_unique) == 0
    assert r(n_entries) == 0
    cf _all using "`before'"
    unab vars : _all
    assert "`vars'" == "id dx1 dx2"
}
if _rc == 0 {
    display as result "  PASS: T6 - no-code path succeeds without data mutation"
    local ++pass_count
}
else {
    display as error "  FAIL: T6 - no-code path/data mutation (error `=_rc')"
    local ++fail_count
}

**# T7: varabbrev is restored to off as well as on after successful runs

local ++test_count
capture noisily {
    clear
    input str8 dx1
    "A10"
    "B10"
    end

    set varabbrev off
    codescan_describe dx1
    assert "`c(varabbrev)'" == "off"

    set varabbrev on
    codescan_describe dx1
    assert "`c(varabbrev)'" == "on"
}
if _rc == 0 {
    display as result "  PASS: T7 - varabbrev restored on successful paths"
    local ++pass_count
}
else {
    display as error "  FAIL: T7 - successful varabbrev restoration (error `=_rc')"
    local ++fail_count
}

**# T8: installed-user behavior works from an isolated PLUS directory

local ++test_count
capture noisily {
    tempfile plusbase
    local plusdir "`plusbase'_plus"
    mkdir "`plusdir'"
    local old_plus "`c(sysdir_plus)'"

    sysdir set PLUS "`plusdir'/"
    capture ado uninstall codescan
    quietly net install codescan, from("`pkg_dir'") replace
    discard

    which codescan_describe
    clear
    input str8 dx1 str8 dx2
    "A10" "B10"
    "A10" ""
    end
    codescan_describe dx1 dx2
    assert r(n_unique) == 2
    assert r(n_entries) == 3

    capture ado uninstall codescan
    sysdir set PLUS "`old_plus'"
}
local t8rc = _rc
capture sysdir set PLUS "`old_plus'"
if `t8rc' == 0 {
    display as result "  PASS: T8 - isolated installed-user behavior"
    local ++pass_count
}
else {
    display as error "  FAIL: T8 - isolated installed-user behavior (error `t8rc')"
    local ++fail_count
}

**# Summary

display as result "RESULT: test_codescan_describe_adversarial tests=`test_count' pass=`pass_count' fail=`fail_count'"
display as result "Functional Results: `pass_count'/`test_count' passed, `fail_count' failed"

if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    exit 1
}

display as result "ALL TESTS PASSED"
