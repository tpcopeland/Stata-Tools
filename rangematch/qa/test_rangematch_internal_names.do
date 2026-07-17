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

**# T8: tempvar-style user names in the USING frame are collision-free
* Indirectly exercises _rm_store_indexed() through the catalog group path.
* Stata's tempvar allocator checks only the current frame. The first phase fix
* replaced __rm_mi/__rm_ui with tempvars but then created those names -- plus
* the provenance/work ids -- in other frames. A using dataset containing legal
* names __000000...__000040 therefore failed r(110). This fixture spans enough
* sequential names to collide with every private allocation site and exercises
* both the no-by and catalog-group paths.
local ++test_count
capture noisily {
    clear
    quietly set obs 1
    quietly gen double key = 5
    quietly gen long group = 1
    forvalues j = 0/40 {
        local nm = "__" + string(`j', "%06.0f")
        quietly gen double `nm' = `j'
    }
    tempfile utempnames
    quietly save "`utempnames'"

    clear
    quietly set obs 1
    quietly gen double mlow = 0
    quietly gen double mhigh = 10
    rangematch key mlow mhigh using "`utempnames'", unmatched(none)
    confirm variable __000000
    confirm variable __000040
    assert __000000 == 0
    assert __000040 == 40
    assert r(N_matched_pairs) == 1

    * Exact numeric type mismatch forces the merge-free catalog group-id path.
    clear
    quietly set obs 1
    quietly gen double mlow = 0
    quietly gen double mhigh = 10
    quietly gen byte group = 1
    rangematch key mlow mhigh using "`utempnames'", by(group) unmatched(none)
    confirm variable __000000
    confirm variable __000040
    assert group == 1
    assert r(N_matched_pairs) == 1
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: cross-frame tempvar-style names are collision-free"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' T8_tempvar_namespace"
    display as error "FAIL: cross-frame tempvar-style user names"
}

**# T9: owned sample marker and private frames are cleaned after an error
* A user-owned __rm_touse must survive. The command should select a different
* marker, restore the caller dataset after maxpairs(), and remove only the
* marker it owns while restoring varabbrev and dropping private frames.
local ++test_count
capture noisily {
    clear
    quietly set obs 2
    quietly gen double key = 4 + _n
    tempfile ucleanup
    quietly save "`ucleanup'"

    clear
    quietly set obs 1
    quietly gen double mlow = 0
    quietly gen double mhigh = 10
    quietly gen double __rm_touse = 99
    set varabbrev on

    capture noisily rangematch key mlow mhigh using "`ucleanup'", maxpairs(1)
    assert _rc == 198
    assert "`c(varabbrev)'" == "on"
    assert _N == 1
    assert mlow == 0
    assert mhigh == 10
    assert __rm_touse == 99
    capture confirm variable __rm_touse1
    assert _rc != 0
    foreach f in __rm_using __rm_master __rm_out __rm_grp __rm_grp_u {
        capture frame `f': describe
        assert _rc != 0
    }
    set varabbrev off
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: error cleanup preserves caller data and state"
}
else {
    capture set varabbrev off
    local ++fail_count
    local failed_tests "`failed_tests' T9_error_cleanup"
    display as error "FAIL: error cleanup leaked state or private objects"
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
