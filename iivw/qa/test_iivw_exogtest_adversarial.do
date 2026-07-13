clear all
set more off
version 16.0
set varabbrev off

* test_iivw_exogtest_adversarial.do - adversarial QA for iivw_exogtest
*
* Usage:
*   cd iivw/qa
*   stata-mp -b do test_iivw_exogtest_adversarial.do
*   stata-mp -b do test_iivw_exogtest_adversarial.do 5

args run_only
* Q5: a bad selector must be an error, not a silent zero-test pass.
* `do this.do 999' used to execute nothing and print "ALL TESTS PASSED".
do "`c(pwd)'/_iivw_qa_common.do"
iivw_qa_selector "`run_only'"
local run_only = `r(run_only)'

**# Setup

local qa_dir "`c(pwd)'"
local base = substr("`qa_dir'", strrpos("`qa_dir'", "/") + 1, .)
if "`base'" != "qa" {
    display as error "test_iivw_exogtest_adversarial.do must be run from iivw/qa"
    capture log close _all
    exit 601
}
* Sysdir sandbox + path resolution (Q3/Q8): the sandbox keeps this suite's
* net install out of the USER's real ado tree even when run standalone, and
* the "/qa" suffix is stripped by length, not by first-occurrence subinstr()
* (which mangles any path whose ancestors contain "qa").
do "`qa_dir'/_iivw_qa_common.do"
iivw_qa_sandbox
local pkg_dir  "`r(pkg_dir)'"
local repo_dir "`r(repo_dir)'"

adopath ++ "`pkg_dir'"
discard
which iivw_exogtest
findfile iivw_exogtest.ado
local exog_path "`r(fn)'"
assert strpos("`exog_path'", "`pkg_dir'") == 1

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

capture program drop _adv_exog_panel
program define _adv_exog_panel
    version 16.0
    syntax [, NIDS(integer 80) VISITS(integer 5) SEED(integer 20260524) ///
        STRONG BYLABEL]

    clear
    set seed `seed'
    set obs `nids'
    gen long id = _n
    gen byte arm = mod(id, 2)
    gen byte female = mod(id, 3) == 0
    gen double age = 35 + mod(id, 25)
    gen double subject_risk = rnormal(0, 0.7)

    if "`bylabel'" != "" {
        label define adv_arm 0 "control" 1 "treated", replace
        label values arm adv_arm
    }

    expand `visits'
    bysort id: gen byte visit = _n
    gen double y = 1.4 + subject_risk + 0.25 * visit + ///
        0.15 * arm + rnormal(0, 0.20)
    gen double marker = cos(id / 6) + 0.08 * visit + rnormal(0, 0.25)
    gen double const_x = 5
    gen double entry = -0.50

    bysort id (visit): gen double __lag_y = y[_n-1]
    gen double __gap = 0
    if "`strong'" != "" {
        replace __gap = exp(1.7 - 1.15 * __lag_y + ///
            0.08 * arm + rnormal(0, 0.03)) if visit > 1
        replace __gap = max(__gap, 0.03) if visit > 1
    }
    else {
        replace __gap = 1 + 0.08 * visit + 0.02 * arm + ///
            runiform() * 0.10 if visit > 1
    }
    bysort id (visit): gen double months = sum(__gap)
    drop __lag_y __gap
end

capture program drop _assert_absent
program define _assert_absent
    version 16.0

    foreach v of local 0 {
        capture confirm variable `v'
        assert _rc != 0
    }
end

**# Adversarial tests

**## 1. Constant exposure creates no estimable model and cleans generated lags
local ++test_count
if `run_only' == 0 | `run_only' == 1 {
    capture noisily {
        _adv_exog_panel, nids(24) visits(4)

        capture noisily iivw_exogtest const_x, endatlastvisit id(id) time(months) ///
            generate(cx_) nolog
        assert _rc == 2000
        _assert_absent cx_const_x_lag1
        assert "`c(varabbrev)'" == "off"
    }
    if _rc == 0 {
        display as result "  PASS: A1 - constant exposure cleans after no model"
        local ++pass_count
    }
    else {
        display as error "  FAIL: A1 - constant exposure cleanup (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' A1"
    }
}

**## 2. Duplicate id-time rows are rejected before data mutation
local ++test_count
if `run_only' == 0 | `run_only' == 2 {
    capture noisily {
        _adv_exog_panel, nids(10) visits(3)
        replace months = months[2] if id == 1 & visit == 3

        capture noisily iivw_exogtest y, endatlastvisit id(id) time(months) ///
            generate(dup_) nolog
        assert _rc == 198
        _assert_absent dup_y_lag1
    }
    if _rc == 0 {
        display as result "  PASS: A2 - duplicate id-time rejected cleanly"
        local ++pass_count
    }
    else {
        display as error "  FAIL: A2 - duplicate id-time rejection (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' A2"
    }
}

**## 3. Invalid entry() structures fail without leaving lag variables
local ++test_count
if `run_only' == 0 | `run_only' == 3 {
    capture noisily {
        _adv_exog_panel, nids(16) visits(4)
        gen double entry_bad = entry
        replace entry_bad = entry_bad + 0.20 if id == 2 & visit == 3
        capture noisily iivw_exogtest y, endatlastvisit id(id) time(months) ///
            entry(entry_bad) generate(ent_) nolog
        assert _rc == 198
        _assert_absent ent_y_lag1

        _adv_exog_panel, nids(16) visits(4)
        replace entry = 0 if id == 3
        capture noisily iivw_exogtest y, endatlastvisit id(id) time(months) ///
            entry(entry) generate(ent_) nolog
        assert _rc == 198
        _assert_absent ent_y_lag1
    }
    if _rc == 0 {
        display as result "  PASS: A3 - invalid entry() rejected cleanly"
        local ++pass_count
    }
    else {
        display as error "  FAIL: A3 - invalid entry() rejection (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' A3"
    }
}

**## 4. Too-few by() groups produce a clean no-model failure
local ++test_count
if `run_only' == 0 | `run_only' == 4 {
    capture noisily {
        clear
        input id visit arm months y
        1 1 0 0 1.0
        1 2 0 1 1.2
        2 1 1 0 1.4
        2 2 1 1 1.6
        end

        capture noisily iivw_exogtest y, endatlastvisit id(id) time(months) ///
            by(arm) generate(few_) nolog
        assert _rc == 2000
        _assert_absent few_y_lag1
    }
    if _rc == 0 {
        display as result "  PASS: A4 - too-few by() groups fail cleanly"
        local ++pass_count
    }
    else {
        display as error "  FAIL: A4 - too-few by() groups (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' A4"
    }
}

**## 5. Generated-variable collisions and overlong names are guarded
local ++test_count
if `run_only' == 0 | `run_only' == 5 {
    capture noisily {
        _adv_exog_panel, nids(24) visits(4)
        gen double clash_y_lag1 = 123
        capture noisily iivw_exogtest y, endatlastvisit id(id) time(months) ///
            generate(clash_) nolog
        assert _rc == 110
        quietly summarize clash_y_lag1, meanonly
        assert r(min) == 123
        assert r(max) == 123

        local long_prefix "abcdefghijklmnopqrstuvwxabcd"
        capture noisily iivw_exogtest y, endatlastvisit id(id) time(months) ///
            generate(`long_prefix') nolog
        assert _rc == 198
        capture ds `long_prefix'*
        assert _rc != 0
    }
    if _rc == 0 {
        display as result "  PASS: A5 - generated-name guards"
        local ++pass_count
    }
    else {
        display as error "  FAIL: A5 - generated-name guards (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' A5"
    }
}

**## 6. Success preserves e(), data values, and incoming sort order
local ++test_count
if `run_only' == 0 | `run_only' == 6 {
    capture noisily {
        _adv_exog_panel, nids(48) visits(5) seed(20260525) strong
        set seed 8102
        gen double shuffle = runiform()
        sort shuffle
        gen long sort_before = _n
        gen double y_before = y
        gen double months_before = months
        regress y age arm
        matrix B_before = e(b)
        local cmd_before "`e(cmd)'"

        set varabbrev on
        iivw_exogtest y marker, endatlastvisit id(id) time(months) ///
            adjust(age arm) generate(ps_) level(90) nolog

        assert "`c(varabbrev)'" == "on"
        set varabbrev off
        assert "`e(cmd)'" == "`cmd_before'"
        matrix B_after = e(b)
        assert mreldif(B_before, B_after) < 1e-12
        assert sort_before == _n
        assert y == y_before
        assert months == months_before
        assert r(n_models) == 1
        assert r(n_skipped) == 0
        confirm variable ps_y_lag1
        confirm variable ps_marker_lag1
    }
    if _rc == 0 {
        display as result "  PASS: A6 - success preserves e() and data order"
        local ++pass_count
    }
    else {
        display as error "  FAIL: A6 - success state preservation (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' A6"
    }
}

**## 7. Error paths preserve e(), data values, sort order, and cleanup
local ++test_count
if `run_only' == 0 | `run_only' == 7 {
    capture noisily {
        _adv_exog_panel, nids(30) visits(4) seed(20260526)
        set seed 8103
        gen double shuffle = runiform()
        sort shuffle
        gen long sort_before = _n
        gen double y_before = y
        gen double months_before = months
        regress y age arm
        matrix B_before = e(b)
        local cmd_before "`e(cmd)'"

        capture noisily iivw_exogtest const_x, endatlastvisit id(id) time(months) ///
            generate(err_) nolog
        assert _rc == 2000
        assert "`e(cmd)'" == "`cmd_before'"
        matrix B_after = e(b)
        assert mreldif(B_before, B_after) < 1e-12
        assert sort_before == _n
        assert y == y_before
        assert months == months_before
        _assert_absent err_const_x_lag1
        assert "`c(varabbrev)'" == "off"
    }
    if _rc == 0 {
        display as result "  PASS: A7 - error preserves state and cleans up"
        local ++pass_count
    }
    else {
        display as error "  FAIL: A7 - error state preservation (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' A7"
    }
}

**## 8. by() returns expected result dimensions, labels, and flags
local ++test_count
if `run_only' == 0 | `run_only' == 8 {
    capture noisily {
        _adv_exog_panel, nids(140) visits(5) seed(20260527) strong bylabel
        iivw_exogtest y, endatlastvisit id(id) time(months) by(arm) ///
            adjust(age female) generate(byx_) level(95) nolog

        assert r(n_models) == 2
        assert r(n_skipped) == 0
        assert r(N) == 560
        assert r(n_ids) == 140
        assert r(endogenous_flag) == 1
        assert r(joint_min_p) < 0.05
        assert "`r(by)'" == "arm"
        assert r(n_groups) == 2
        assert "`r(group_label_1)'" == "control"
        assert "`r(group_label_2)'" == "treated"
        assert "`r(lagvars)'" == "byx_y_lag1"
        assert r(n_terms) == 1
        assert "`r(term_label_1)'" == "y (lag 1)"
        assert "`r(result_row_labels)'" == " g1_t1 g2_t1"
        assert "`r(result_columns)'" == "group_index term_index b se z p hr lb ub N n_ids"

        matrix R = r(results)
        assert rowsof(R) == 2
        assert colsof(R) == 11
        assert R[1,1] == 1
        assert R[1,2] == 1
        assert R[1,10] == 280
        assert R[1,11] == 70
        assert R[2,1] == 2
        assert R[2,2] == 1
        assert R[2,10] == 280
        assert R[2,11] == 70
        confirm variable byx_y_lag1
    }
    if _rc == 0 {
        display as result "  PASS: A8 - by() return dimensions and flags"
        local ++pass_count
    }
    else {
        display as error "  FAIL: A8 - by() return dimensions/flags (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' A8"
    }
}

**# Summary

capture adopath - "`pkg_dir'"
iivw_qa_summary, name(test_iivw_exogtest_adversarial) tests(`test_count') pass(`pass_count') ///
    fail(`fail_count') runonly(`run_only') failedtests("`failed_tests'")

