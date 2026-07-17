* test_rangematch_internal_names.do
* Regression coverage for RM-I02: legal user variables named __rm_mi / __rm_ui
* must not collide with the backend's private pair-index columns.
*
* The three Mata pair builders wrote fixed literal columns __rm_mi and __rm_ui
* into the output frame; master and carried using variables were then
* materialized into that same frame, so a user variable of either name failed
* with r(110) on otherwise valid input. The names are now collision-free
* tempvars passed into the builders.
*
* These tests FAIL on the shipped 1.3.3 code with r(110).
*
* Coverage spans all three backends (binary, sweep, overlap) because the
* literal appeared in each of the three builders independently.

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

* The two private index spellings the backends used as literals.
local privnames "__rm_mi __rm_ui"

**# T1: a MASTER variable with a private index name (point/binary backend)
local ++test_count
capture noisily {
    foreach pn of local privnames {
        clear
        quietly set obs 1
        quietly gen double key = 5
        tempfile u
        quietly save "`u'"
        clear
        quietly set obs 1
        quietly gen double mlow = 0
        quietly gen double mhigh = 10
        quietly gen double `pn' = 42
        rangematch key mlow mhigh using "`u'"
        * The user variable must survive with its value intact.
        confirm variable `pn'
        assert `pn' == 42
        assert r(N_matched_pairs) == 1
    }
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: master variable named __rm_mi/__rm_ui accepted"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' T1_master_var"
    display as error "FAIL: master variable with private index name"
}

**# T2: a CARRIED USING variable with a private index name
local ++test_count
capture noisily {
    foreach pn of local privnames {
        clear
        quietly set obs 1
        quietly gen double key = 5
        quietly gen double `pn' = 77
        tempfile u
        quietly save "`u'"
        clear
        quietly set obs 1
        quietly gen double mlow = 0
        quietly gen double mhigh = 10
        rangematch key mlow mhigh using "`u'", keepusing(`pn')
        confirm variable `pn'
        assert `pn' == 77
    }
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: carried using variable named __rm_mi/__rm_ui accepted"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' T2_using_var"
    display as error "FAIL: carried using variable with private index name"
}

**# T3: OVERLAP backend with private index names on both sides
local ++test_count
capture noisily {
    clear
    quietly set obs 1
    quietly gen double ulow = 5
    quietly gen double uhigh = 6
    quietly gen double __rm_ui = 77
    tempfile u
    quietly save "`u'"
    clear
    quietly set obs 1
    quietly gen double mlow = 0
    quietly gen double mhigh = 10
    quietly gen double __rm_mi = 42
    rangematch mlow mhigh using "`u'", overlap(ulow uhigh) keepusing(__rm_ui)
    assert __rm_mi == 42
    assert __rm_ui == 77
    assert r(N_matched_pairs) == 1
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: overlap backend with private index names"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' T3_overlap"
    display as error "FAIL: overlap backend with private index names"
}

**# T4: SWEEP backend (sorted master intervals) with private index names
local ++test_count
capture noisily {
    clear
    quietly set obs 20
    quietly gen double key = _n
    tempfile u
    quietly save "`u'"
    clear
    quietly set obs 20
    quietly gen double mlow = _n
    quietly gen double mhigh = _n + 0.5
    quietly gen double __rm_mi = _n
    sort mlow mhigh
    rangematch key mlow mhigh using "`u'", unmatched(none)
    assert __rm_mi < .
    quietly count
    assert r(N) == 20
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: sweep backend with private index names"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' T4_sweep"
    display as error "FAIL: sweep backend with private index names"
}

**# T5: private index names as REQUESTED OUTPUT names
local ++test_count
capture noisily {
    clear
    quietly set obs 1
    quietly gen double key = 5
    tempfile u
    quietly save "`u'"
    clear
    quietly set obs 1
    quietly gen double mlow = 0
    quietly gen double mhigh = 10
    rangematch key mlow mhigh using "`u'", generate(__rm_mi)
    confirm variable __rm_mi
    assert __rm_mi == 3

    clear
    quietly set obs 1
    quietly gen double mlow = 0
    quietly gen double mhigh = 10
    rangematch key mlow mhigh using "`u'", masterid(__rm_mi) usingid(__rm_ui)
    confirm variable __rm_mi
    confirm variable __rm_ui
    assert __rm_mi == 1
    assert __rm_ui == 1
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: private names accepted as output names"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' T5_output_names"
    display as error "FAIL: private names as output names"
}

**# T6: private index names combined with prefix/suffix and all
local ++test_count
capture noisily {
    clear
    quietly set obs 1
    quietly gen double key = 5
    quietly gen double __rm_ui = 77
    tempfile u
    quietly save "`u'"
    clear
    quietly set obs 1
    quietly gen double mlow = 0
    quietly gen double mhigh = 10
    rangematch key mlow mhigh using "`u'", keepusing(__rm_ui) suffix(_U) all
    confirm variable __rm_ui_U
    assert __rm_ui_U == 77
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: private names with prefix/suffix/all"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' T6_prefix_suffix"
    display as error "FAIL: private names with prefix/suffix"
}

**# T7: the private index columns never survive into user output
local ++test_count
capture noisily {
    clear
    quietly set obs 1
    quietly gen double key = 5
    tempfile u
    quietly save "`u'"
    clear
    quietly set obs 1
    quietly gen double mlow = 0
    quietly gen double mhigh = 10
    rangematch key mlow mhigh using "`u'"
    * No user variable was named __rm_mi/__rm_ui, so neither may appear.
    foreach pn of local privnames {
        capture confirm variable `pn'
        assert _rc != 0
    }
    * Nor may any tempvar-style leftovers remain.
    quietly describe, varlist short
    local outvars "`r(varlist)'"
    local expected "mlow mhigh key"
    local extra : list outvars - expected
    assert "`extra'" == ""
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: private index columns dropped from output"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' T7_no_leak"
    display as error "FAIL: private index columns leaked"
}

display as result _newline "INTERNAL NAMES TEST SUMMARY"
display as result "Tests:  `test_count'"
display as result "Passed: `pass_count'"
display as result "Failed: `fail_count'"
if `fail_count' > 0 {
    display as error "Failed tests:`failed_tests'"
    display "RESULT: test_rangematch_internal_names tests=`test_count' pass=`pass_count' fail=`fail_count'"
    exit 9
}
display "RESULT: test_rangematch_internal_names tests=`test_count' pass=`pass_count' fail=`fail_count'"
