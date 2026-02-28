/*******************************************************************************
* test_codescan.do
*
* Purpose: Functional tests for codescan command
*
* Prerequisites:
*   - codescan.ado must be accessible
*
* Author: Timothy P Copeland
* Date: 2026-02-27
*******************************************************************************/

clear all
set more off
set seed 12345
version 16.0

* =============================================================================
* CONFIGURATION
* =============================================================================
if "$RUN_TEST_QUIET" == "" {
    global RUN_TEST_QUIET = 0
}
if "$RUN_TEST_MACHINE" == "" {
    global RUN_TEST_MACHINE = 0
}
if "$RUN_TEST_NUMBER" == "" {
    global RUN_TEST_NUMBER = 0
}

local quiet = $RUN_TEST_QUIET
local machine = $RUN_TEST_MACHINE
local run_only = $RUN_TEST_NUMBER

* =============================================================================
* PATH CONFIGURATION
* =============================================================================
if "`c(os)'" == "MacOSX" {
    global STATA_TOOLS_PATH "/Users/tcopeland/Documents/GitHub/Stata-Dev"
}
else if "`c(os)'" == "Unix" {
    * Try to detect path from current working directory
    capture confirm file "../../_devkit/_testing"
    if _rc == 0 {
        * Running from <pkg>/qa/ directory
        global STATA_TOOLS_PATH "`c(pwd)'/../.."
    }
    else {
    capture confirm file "_devkit/_testing"
    if _rc == 0 {
        global STATA_TOOLS_PATH "`c(pwd)'"
    }
    else {
        global STATA_TOOLS_PATH "/home/tpcopeland/Stata-Dev"
    }
    }
}
else {
    capture confirm file "_devkit/_testing"
    if _rc == 0 {
        global STATA_TOOLS_PATH "`c(pwd)'"
    }
    else {
        global STATA_TOOLS_PATH "`c(pwd)'/.."
    }
}

global TESTING_DIR "${STATA_TOOLS_PATH}/_devkit/_testing"
global DATA_DIR "${TESTING_DIR}/data"

* Load the command
capture program drop codescan
capture program drop _codescan_prefix_scan
quietly run "${STATA_TOOLS_PATH}/codescan/codescan.ado"

* =============================================================================
* HEADER
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "CODESCAN COMMAND FUNCTIONAL TESTING"
    display as text "{hline 70}"
}

* =============================================================================
* TEST COUNTERS
* =============================================================================
local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

capture program drop _run_test
program define _run_test
    args test_num test_desc
    if $RUN_TEST_NUMBER > 0 & $RUN_TEST_NUMBER != `test_num' {
        exit 0
    }
    if $RUN_TEST_QUIET == 0 {
        display as text _n "TEST `test_num': `test_desc'"
        display as text "{hline 50}"
    }
end

* =============================================================================
* HELPER: Create standard test dataset
* =============================================================================
capture program drop _make_test_data
program define _make_test_data
    clear
    set obs 20
    gen long pid = ceil(_n / 4)

    * 5 patients, 4 rows each
    gen str10 dx1 = ""
    gen str10 dx2 = ""
    gen str10 dx3 = ""
    gen double visit_dt = .
    gen double index_dt = .
    format visit_dt index_dt %td

    * Patient 1: DM2 + obesity, visits around index
    replace dx1 = "E110" if _n == 1
    replace dx2 = "E660" if _n == 1
    replace dx1 = "I10"  if _n == 2
    replace dx1 = "E119" if _n == 3
    replace dx1 = "J45"  if _n == 4

    * Patient 2: HTN only
    replace dx1 = "I10"  if _n == 5
    replace dx1 = "I13"  if _n == 6
    replace dx1 = "J45"  if _n == 7
    replace dx1 = "K21"  if _n == 8

    * Patient 3: CVD
    replace dx1 = "I21"  if _n == 9
    replace dx2 = "I25"  if _n == 10
    replace dx1 = "E110" if _n == 11
    replace dx1 = "Z00"  if _n == 12

    * Patient 4: depression + DM2
    replace dx1 = "F32"  if _n == 13
    replace dx2 = "E111" if _n == 14
    replace dx1 = "F33"  if _n == 15
    replace dx1 = "Z00"  if _n == 16

    * Patient 5: no matches
    replace dx1 = "Z00"  if _n == 17
    replace dx1 = "Z01"  if _n == 18
    replace dx1 = "Z02"  if _n == 19
    replace dx1 = "Z03"  if _n == 20

    * Dates: index = 2020-01-01 for all
    replace index_dt = mdy(1, 1, 2020)

    * Visits spread around index
    replace visit_dt = mdy(6, 15, 2019) if mod(_n - 1, 4) == 0
    replace visit_dt = mdy(12, 1, 2019) if mod(_n - 1, 4) == 1
    replace visit_dt = mdy(1, 1, 2020)  if mod(_n - 1, 4) == 2
    replace visit_dt = mdy(6, 15, 2020) if mod(_n - 1, 4) == 3
end


* =============================================================================
* TEST 1: Basic single condition
* =============================================================================
local ++test_count
local test_desc "Basic single condition"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        _make_test_data
        codescan dx1-dx3, define(dm2 "E11")

        * Verify indicator variable created
        confirm variable dm2

        * Patient 1 rows 1,3 and patient 3 row 11 and patient 4 row 14 have E11*
        assert dm2 == 1 if _n == 1
        assert dm2 == 1 if _n == 3
        assert dm2 == 1 if _n == 11
        assert dm2 == 1 if _n == 14
        assert dm2 == 0 if _n == 5
        assert dm2 == 0 if _n == 17

        * Check return values
        assert r(n_conditions) == 1
        assert "`r(mode)'" == "regex"
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "[OK] `test_count'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "[FAIL] `test_count'|`=_rc'|`test_desc'"
        }
        else {
            display as error "  FAILED: `test_desc' (error `=_rc')"
        }
    }
}

* =============================================================================
* TEST 2: Multiple conditions
* =============================================================================
local ++test_count
local test_desc "Multiple conditions"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        _make_test_data
        codescan dx1-dx3, define(dm2 "E11" | obesity "E66" | depression "F3[23]")

        confirm variable dm2
        confirm variable obesity
        confirm variable depression

        * DM2: rows 1,3,11,14
        assert dm2 == 1 if _n == 1
        assert dm2 == 1 if _n == 3

        * Obesity: row 1 (dx2=E660)
        assert obesity == 1 if _n == 1
        assert obesity == 0 if _n == 2

        * Depression: rows 13,15
        assert depression == 1 if _n == 13
        assert depression == 1 if _n == 15
        assert depression == 0 if _n == 17

        assert r(n_conditions) == 3
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "[OK] `test_count'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "[FAIL] `test_count'|`=_rc'|`test_desc'"
        }
        else {
            display as error "  FAILED: `test_desc' (error `=_rc')"
        }
    }
}

* =============================================================================
* TEST 3: Regex patterns with alternation and character classes
* =============================================================================
local ++test_count
local test_desc "Regex patterns"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        _make_test_data
        codescan dx1-dx3, define(htn "I1[0-35]" | cvd "I2[0-5]")

        confirm variable htn
        confirm variable cvd

        * HTN: I10 (rows 2,5), I13 (row 6)
        assert htn == 1 if _n == 2
        assert htn == 1 if _n == 5
        assert htn == 1 if _n == 6
        assert htn == 0 if _n == 1

        * CVD: I21 (row 9), I25 (row 10 in dx2)
        assert cvd == 1 if _n == 9
        assert cvd == 1 if _n == 10
        assert cvd == 0 if _n == 11
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "[OK] `test_count'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "[FAIL] `test_count'|`=_rc'|`test_desc'"
        }
        else {
            display as error "  FAILED: `test_desc' (error `=_rc')"
        }
    }
}

* =============================================================================
* TEST 4: Prefix mode
* =============================================================================
local ++test_count
local test_desc "Prefix mode"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        _make_test_data
        codescan dx1-dx3, define(dm2 "E11" | z_codes "Z00|Z01") mode(prefix)

        confirm variable dm2
        confirm variable z_codes

        * DM2 prefix: E110 (row 1), E119 (row 3), E110 (row 11), E111 (row 14)
        assert dm2 == 1 if _n == 1
        assert dm2 == 1 if _n == 3
        assert dm2 == 0 if _n == 5

        * Z codes: Z00 (rows 12,16,17), Z01 (row 18)
        assert z_codes == 1 if _n == 12
        assert z_codes == 1 if _n == 17
        assert z_codes == 1 if _n == 18
        assert z_codes == 0 if _n == 19

        assert "`r(mode)'" == "prefix"
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "[OK] `test_count'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "[FAIL] `test_count'|`=_rc'|`test_desc'"
        }
        else {
            display as error "  FAILED: `test_desc' (error `=_rc')"
        }
    }
}

* =============================================================================
* TEST 5: Lookback window (refdate excluded by default)
* =============================================================================
local ++test_count
local test_desc "Lookback window (refdate excluded)"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        _make_test_data

        * Lookback 365 days: [2019-01-02, 2020-01-01)
        * Includes: 2019-06-15, 2019-12-01. Excludes: 2020-01-01, 2020-06-15
        codescan dx1-dx3, define(dm2 "E11") date(visit_dt) refdate(index_dt) lookback(365)

        * Row 1: 2019-06-15, E110 → in window, should match
        assert dm2 == 1 if _n == 1
        * Row 3: 2020-01-01, E119 → ON refdate, excluded → should NOT match
        assert dm2 == 0 if _n == 3
        * Row 4: 2020-06-15 → outside window
        assert dm2 == 0 if _n == 4

        assert r(lookback) == 365
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "[OK] `test_count'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "[FAIL] `test_count'|`=_rc'|`test_desc'"
        }
        else {
            display as error "  FAILED: `test_desc' (error `=_rc')"
        }
    }
}

* =============================================================================
* TEST 6: Lookforward window (refdate excluded by default)
* =============================================================================
local ++test_count
local test_desc "Lookforward window (refdate excluded)"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        _make_test_data

        * Lookforward 365: (2020-01-01, 2021-01-01]
        * Includes: 2020-06-15. Excludes: 2020-01-01, 2019-*
        codescan dx1-dx3, define(dm2 "E11") date(visit_dt) refdate(index_dt) lookforward(365)

        * Row 1: 2019-06-15 → before refdate, excluded
        assert dm2 == 0 if _n == 1
        * Row 3: 2020-01-01 → ON refdate, excluded
        assert dm2 == 0 if _n == 3
        * Row 4: 2020-06-15, J45 → in window but wrong code
        assert dm2 == 0 if _n == 4
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "[OK] `test_count'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "[FAIL] `test_count'|`=_rc'|`test_desc'"
        }
        else {
            display as error "  FAILED: `test_desc' (error `=_rc')"
        }
    }
}

* =============================================================================
* TEST 7: Both lookback + lookforward (refdate auto-included)
* =============================================================================
local ++test_count
local test_desc "Lookback + lookforward (refdate auto-included)"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        _make_test_data

        * Both: [2019-01-02, 2021-01-01] — refdate auto-included
        codescan dx1-dx3, define(dm2 "E11") date(visit_dt) refdate(index_dt) ///
            lookback(365) lookforward(365)

        * Row 1: 2019-06-15, E110 → in window
        assert dm2 == 1 if _n == 1
        * Row 3: 2020-01-01, E119 → ON refdate, auto-included
        assert dm2 == 1 if _n == 3
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "[OK] `test_count'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "[FAIL] `test_count'|`=_rc'|`test_desc'"
        }
        else {
            display as error "  FAILED: `test_desc' (error `=_rc')"
        }
    }
}

* =============================================================================
* TEST 8: Inclusive option with single-direction window
* =============================================================================
local ++test_count
local test_desc "Inclusive option"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        _make_test_data

        * Lookback 365 + inclusive: [2019-01-02, 2020-01-01]
        codescan dx1-dx3, define(dm2 "E11") date(visit_dt) refdate(index_dt) ///
            lookback(365) inclusive

        * Row 1: 2019-06-15, E110 → in window
        assert dm2 == 1 if _n == 1
        * Row 3: 2020-01-01, E119 → ON refdate, now included
        assert dm2 == 1 if _n == 3
        * Row 4: 2020-06-15 → after refdate, excluded
        assert dm2 == 0 if _n == 4
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "[OK] `test_count'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "[FAIL] `test_count'|`=_rc'|`test_desc'"
        }
        else {
            display as error "  FAILED: `test_desc' (error `=_rc')"
        }
    }
}

* =============================================================================
* TEST 9: Collapse to patient level
* =============================================================================
local ++test_count
local test_desc "Collapse to patient level"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        _make_test_data
        codescan dx1-dx3, define(dm2 "E11" | depression "F3[23]") id(pid) collapse

        * Should have 5 patients
        assert _N == 5

        * Patient 1: has DM2 (E110, E119), no depression
        assert dm2 == 1 if pid == 1
        assert depression == 0 if pid == 1

        * Patient 4: has both DM2 and depression
        assert dm2 == 1 if pid == 4
        assert depression == 1 if pid == 4

        * Patient 5: neither
        assert dm2 == 0 if pid == 5
        assert depression == 0 if pid == 5
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "[OK] `test_count'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "[FAIL] `test_count'|`=_rc'|`test_desc'"
        }
        else {
            display as error "  FAILED: `test_desc' (error `=_rc')"
        }
    }
}

* =============================================================================
* TEST 10: Earliestdate
* =============================================================================
local ++test_count
local test_desc "Earliestdate"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        _make_test_data
        codescan dx1-dx3, define(dm2 "E11") id(pid) date(visit_dt) collapse earliestdate

        confirm variable dm2_first

        * Patient 1: earliest DM2 date = 2019-06-15 (row 1: E110)
        assert dm2_first == mdy(6, 15, 2019) if pid == 1

        * Patient 5: no DM2, date should be missing
        assert missing(dm2_first) if pid == 5
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "[OK] `test_count'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "[FAIL] `test_count'|`=_rc'|`test_desc'"
        }
        else {
            display as error "  FAILED: `test_desc' (error `=_rc')"
        }
    }
}

* =============================================================================
* TEST 11: Latestdate
* =============================================================================
local ++test_count
local test_desc "Latestdate"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        _make_test_data
        codescan dx1-dx3, define(dm2 "E11") id(pid) date(visit_dt) collapse latestdate

        confirm variable dm2_last

        * Patient 1: latest DM2 = 2020-01-01 (row 3: E119)
        assert dm2_last == mdy(1, 1, 2020) if pid == 1

        * Patient 5: no DM2
        assert missing(dm2_last) if pid == 5
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "[OK] `test_count'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "[FAIL] `test_count'|`=_rc'|`test_desc'"
        }
        else {
            display as error "  FAILED: `test_desc' (error `=_rc')"
        }
    }
}

* =============================================================================
* TEST 12: Countdate
* =============================================================================
local ++test_count
local test_desc "Countdate"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        _make_test_data
        codescan dx1-dx3, define(dm2 "E11") id(pid) date(visit_dt) collapse countdate

        confirm variable dm2_count

        * Patient 1: DM2 on 2019-06-15 and 2020-01-01 = 2 unique dates
        assert dm2_count == 2 if pid == 1

        * Patient 5: 0 dates
        assert dm2_count == 0 if pid == 5
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "[OK] `test_count'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "[FAIL] `test_count'|`=_rc'|`test_desc'"
        }
        else {
            display as error "  FAILED: `test_desc' (error `=_rc')"
        }
    }
}

* =============================================================================
* TEST 13: Labels
* =============================================================================
local ++test_count
local test_desc "Labels"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        _make_test_data
        codescan dx1-dx3, define(dm2 "E11" | obesity "E66") ///
            label(dm2 "Type 2 Diabetes" \ obesity "Obesity")

        * Check variable labels
        local lbl_dm2 : variable label dm2
        assert "`lbl_dm2'" == "Type 2 Diabetes"
        local lbl_ob : variable label obesity
        assert "`lbl_ob'" == "Obesity"
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "[OK] `test_count'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "[FAIL] `test_count'|`=_rc'|`test_desc'"
        }
        else {
            display as error "  FAILED: `test_desc' (error `=_rc')"
        }
    }
}

* =============================================================================
* TEST 14: Labels on date summary variables
* =============================================================================
local ++test_count
local test_desc "Labels on date summary variables"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        _make_test_data
        codescan dx1-dx3, define(dm2 "E11") id(pid) date(visit_dt) collapse ///
            earliestdate latestdate countdate label(dm2 "Type 2 Diabetes")

        local lbl : variable label dm2_first
        assert "`lbl'" == "Earliest Type 2 Diabetes Date"
        local lbl : variable label dm2_last
        assert "`lbl'" == "Latest Type 2 Diabetes Date"
        local lbl : variable label dm2_count
        assert "`lbl'" == "Type 2 Diabetes Date Count"
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "[OK] `test_count'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "[FAIL] `test_count'|`=_rc'|`test_desc'"
        }
        else {
            display as error "  FAILED: `test_desc' (error `=_rc')"
        }
    }
}

* =============================================================================
* TEST 15: Replace option
* =============================================================================
local ++test_count
local test_desc "Replace option"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        _make_test_data

        * First run
        codescan dx1-dx3, define(dm2 "E11")

        * Second run without replace should fail
        capture codescan dx1-dx3, define(dm2 "E11")
        assert _rc == 110

        * With replace should succeed
        codescan dx1-dx3, define(dm2 "E11") replace
        confirm variable dm2
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "[OK] `test_count'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "[FAIL] `test_count'|`=_rc'|`test_desc'"
        }
        else {
            display as error "  FAILED: `test_desc' (error `=_rc')"
        }
    }
}

* =============================================================================
* TEST 16: Error - numeric varlist
* =============================================================================
local ++test_count
local test_desc "Error: numeric varlist"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        clear
        set obs 10
        gen double numvar = _n
        capture codescan numvar, define(test "E11")
        assert _rc == 109
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "[OK] `test_count'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED (correctly rejected numeric vars)"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "[FAIL] `test_count'|`=_rc'|`test_desc'"
        }
        else {
            display as error "  FAILED: `test_desc' (error `=_rc')"
        }
    }
}

* =============================================================================
* TEST 17: Error - collapse without id
* =============================================================================
local ++test_count
local test_desc "Error: collapse without id"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        _make_test_data
        capture codescan dx1-dx3, define(dm2 "E11") collapse
        assert _rc == 198
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "[OK] `test_count'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED (correctly rejected collapse without id)"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "[FAIL] `test_count'|`=_rc'|`test_desc'"
        }
        else {
            display as error "  FAILED: `test_desc' (error `=_rc')"
        }
    }
}

* =============================================================================
* TEST 18: Error - lookback without refdate
* =============================================================================
local ++test_count
local test_desc "Error: lookback without refdate"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        _make_test_data
        capture codescan dx1-dx3, define(dm2 "E11") date(visit_dt) lookback(365)
        assert _rc == 198
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "[OK] `test_count'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED (correctly rejected lookback without refdate)"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "[FAIL] `test_count'|`=_rc'|`test_desc'"
        }
        else {
            display as error "  FAILED: `test_desc' (error `=_rc')"
        }
    }
}

* =============================================================================
* TEST 19: Error - earliestdate without collapse
* =============================================================================
local ++test_count
local test_desc "Error: earliestdate without collapse"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        _make_test_data
        capture codescan dx1-dx3, define(dm2 "E11") id(pid) date(visit_dt) earliestdate
        assert _rc == 198
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "[OK] `test_count'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED (correctly rejected earliestdate without collapse)"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "[FAIL] `test_count'|`=_rc'|`test_desc'"
        }
        else {
            display as error "  FAILED: `test_desc' (error `=_rc')"
        }
    }
}

* =============================================================================
* TEST 20: Error - invalid mode
* =============================================================================
local ++test_count
local test_desc "Error: invalid mode"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        _make_test_data
        capture codescan dx1-dx3, define(dm2 "E11") mode(fuzzy)
        assert _rc == 198
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "[OK] `test_count'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED (correctly rejected invalid mode)"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "[FAIL] `test_count'|`=_rc'|`test_desc'"
        }
        else {
            display as error "  FAILED: `test_desc' (error `=_rc')"
        }
    }
}

* =============================================================================
* TEST 21: No matches (all zeros)
* =============================================================================
local ++test_count
local test_desc "Edge case: no matches"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        _make_test_data
        codescan dx1-dx3, define(rare "Q99")

        * Should create variable but all zeros
        confirm variable rare
        quietly count if rare == 1
        assert r(N) == 0
        quietly count if rare == 0
        assert r(N) == 20
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "[OK] `test_count'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "[FAIL] `test_count'|`=_rc'|`test_desc'"
        }
        else {
            display as error "  FAILED: `test_desc' (error `=_rc')"
        }
    }
}

* =============================================================================
* TEST 22: if/in conditions
* =============================================================================
local ++test_count
local test_desc "if/in conditions"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        _make_test_data

        * Only scan first 8 rows (patients 1-2)
        codescan dx1-dx3 in 1/8, define(dm2 "E11")

        * Patient 1 row 1 should match
        assert dm2 == 1 if _n == 1
        * Row 11 (patient 3) has E110 but is outside in range
        assert dm2 == 0 if _n == 11
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "[OK] `test_count'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "[FAIL] `test_count'|`=_rc'|`test_desc'"
        }
        else {
            display as error "  FAILED: `test_desc' (error `=_rc')"
        }
    }
}

* =============================================================================
* TEST 23: Missing codes (empty strings)
* =============================================================================
local ++test_count
local test_desc "Missing codes (empty strings)"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        _make_test_data
        * dx2 and dx3 are mostly empty — should not cause errors
        codescan dx1-dx3, define(dm2 "E11")
        confirm variable dm2

        * Verify empty strings don't match
        assert dm2 == 0 if _n == 5
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "[OK] `test_count'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "[FAIL] `test_count'|`=_rc'|`test_desc'"
        }
        else {
            display as error "  FAILED: `test_desc' (error `=_rc')"
        }
    }
}

* =============================================================================
* TEST 24: Missing dates excluded from time window
* =============================================================================
local ++test_count
local test_desc "Missing dates excluded from time window"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        _make_test_data
        * Set some dates to missing
        replace visit_dt = . if _n == 1

        codescan dx1-dx3, define(dm2 "E11") date(visit_dt) refdate(index_dt) lookback(365)

        * Row 1 has E110 but missing date → should NOT match
        assert dm2 == 0 if _n == 1
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "[OK] `test_count'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "[FAIL] `test_count'|`=_rc'|`test_desc'"
        }
        else {
            display as error "  FAILED: `test_desc' (error `=_rc')"
        }
    }
}

* =============================================================================
* TEST 25: Full featured call (collapse + window + dates + labels)
* =============================================================================
local ++test_count
local test_desc "Full featured call"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        _make_test_data
        codescan dx1-dx3, id(pid) date(visit_dt) refdate(index_dt) ///
            define(dm2 "E11" | htn "I1[0-35]" | depression "F3[23]") ///
            lookback(365) inclusive collapse ///
            earliestdate latestdate countdate ///
            label(dm2 "Type 2 Diabetes" \ htn "Hypertension" \ depression "Depression")

        * Should have 5 patients
        assert _N == 5

        * Check all expected variables exist
        confirm variable dm2 dm2_first dm2_last dm2_count
        confirm variable htn htn_first htn_last htn_count
        confirm variable depression depression_first depression_last depression_count

        * Verify return values
        assert r(N) == 5
        assert r(n_conditions) == 3
        assert "`r(conditions)'" == "dm2 htn depression"
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "[OK] `test_count'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "[FAIL] `test_count'|`=_rc'|`test_desc'"
        }
        else {
            display as error "  FAILED: `test_desc' (error `=_rc')"
        }
    }
}

* =============================================================================
* TEST 26: Noisily option
* =============================================================================
local ++test_count
local test_desc "Noisily option"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        _make_test_data
        codescan dx1-dx3, define(dm2 "E11") noisily
        confirm variable dm2
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "[OK] `test_count'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "[FAIL] `test_count'|`=_rc'|`test_desc'"
        }
        else {
            display as error "  FAILED: `test_desc' (error `=_rc')"
        }
    }
}

* =============================================================================
* TEST 27: Summary matrix returned
* =============================================================================
local ++test_count
local test_desc "Summary matrix"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        _make_test_data
        codescan dx1-dx3, define(dm2 "E11" | obesity "E66")

        * Check summary matrix
        matrix S = r(summary)
        assert rowsof(S) == 2
        assert colsof(S) == 2
        assert S[1,1] > 0
        assert S[2,1] >= 0
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "[OK] `test_count'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "[FAIL] `test_count'|`=_rc'|`test_desc'"
        }
        else {
            display as error "  FAILED: `test_desc' (error `=_rc')"
        }
    }
}

* =============================================================================
* TEST 28: Single row dataset
* =============================================================================
local ++test_count
local test_desc "Edge case: single row"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        clear
        set obs 1
        gen str10 dx1 = "E110"
        gen long pid = 1
        codescan dx1, define(dm2 "E11")
        assert dm2 == 1
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "[OK] `test_count'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "[FAIL] `test_count'|`=_rc'|`test_desc'"
        }
        else {
            display as error "  FAILED: `test_desc' (error `=_rc')"
        }
    }
}

* =============================================================================
* TEST 29: Error - inclusive without lookback/lookforward
* =============================================================================
local ++test_count
local test_desc "Error: inclusive without lookback/lookforward"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        _make_test_data
        capture codescan dx1-dx3, define(dm2 "E11") inclusive
        assert _rc == 198
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "[OK] `test_count'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED (correctly rejected inclusive without window)"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "[FAIL] `test_count'|`=_rc'|`test_desc'"
        }
        else {
            display as error "  FAILED: `test_desc' (error `=_rc')"
        }
    }
}

* =============================================================================
* TEST 30: Error - label name not in define
* =============================================================================
local ++test_count
local test_desc "Error: label name not in define"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        _make_test_data
        capture codescan dx1-dx3, define(dm2 "E11") label(badname "Bad Label")
        assert _rc == 198
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "[OK] `test_count'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED (correctly rejected mismatched label)"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "[FAIL] `test_count'|`=_rc'|`test_desc'"
        }
        else {
            display as error "  FAILED: `test_desc' (error `=_rc')"
        }
    }
}

* =============================================================================
* TEST 31: Date format preserved after collapse
* =============================================================================
local ++test_count
local test_desc "Date format preserved after collapse"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        _make_test_data
        codescan dx1-dx3, define(dm2 "E11") id(pid) date(visit_dt) collapse ///
            earliestdate latestdate

        * Check format matches original %td
        local fmt : format dm2_first
        assert "`fmt'" == "%td"
        local fmt : format dm2_last
        assert "`fmt'" == "%td"
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "[OK] `test_count'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "[FAIL] `test_count'|`=_rc'|`test_desc'"
        }
        else {
            display as error "  FAILED: `test_desc' (error `=_rc')"
        }
    }
}

* =============================================================================
* TEST 32: Collapse with window + all date options
* =============================================================================
local ++test_count
local test_desc "Collapse with window + all date options"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        _make_test_data

        * Lookback 365 inclusive: includes refdate
        codescan dx1-dx3, id(pid) date(visit_dt) refdate(index_dt) ///
            define(dm2 "E11") lookback(365) inclusive collapse ///
            earliestdate latestdate countdate

        assert _N == 5
        confirm variable dm2 dm2_first dm2_last dm2_count

        * Patient 1: DM2 on 2019-06-15 (E110) and 2020-01-01 (E119)
        * Both within [2019-01-02, 2020-01-01]
        assert dm2 == 1 if pid == 1
        assert dm2_first == mdy(6, 15, 2019) if pid == 1
        assert dm2_last == mdy(1, 1, 2020) if pid == 1
        assert dm2_count == 2 if pid == 1
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "[OK] `test_count'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "[FAIL] `test_count'|`=_rc'|`test_desc'"
        }
        else {
            display as error "  FAILED: `test_desc' (error `=_rc')"
        }
    }
}

* =============================================================================
* SUMMARY
* =============================================================================
if `machine' {
    display "[SUMMARY] `pass_count'/`test_count' passed"
    if `fail_count' > 0 {
        display "[FAILED]`failed_tests'"
    }
}
else {
    display as text _n "{hline 70}"
    display as text "CODESCAN FUNCTIONAL TEST SUMMARY"
    display as text "{hline 70}"
    display as text "Total tests:  `test_count'"
    display as result "Passed:       `pass_count'"
    if `fail_count' > 0 {
        display as error "Failed:       `fail_count'"
        display as error "Failed tests:`failed_tests'"
    }
    else {
        display as text "Failed:       `fail_count'"
    }
    display as text "{hline 70}"

    if `fail_count' > 0 {
        display as error "Some tests FAILED. Review output above."
        exit 1
    }
    else {
        display as result "All tests PASSED!"
    }
}

* Clear globals
global RUN_TEST_QUIET
global RUN_TEST_MACHINE
global RUN_TEST_NUMBER
