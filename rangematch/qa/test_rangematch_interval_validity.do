* test_rangematch_interval_validity.do
* Regression coverage for RM-C02 and RM-C03: an interval whose bounds are not
* ordered describes no region and can never be a genuine overlap match.
*
* Contract under test (symmetric for the master and using sides):
*   closed(both) -> [lo,hi] nonempty iff lo <= hi   (lo == hi is a valid point)
*   closed(none) -> (lo,hi) nonempty iff lo <  hi   ((x,x) is empty)
* Validity is a property of the recorded data and is NOT widened by
* tolerance(): tolerance fuzzes boundary comparisons between two genuine
* intervals, it does not promote an empty interval into a nonempty one.
*
* On the shipped 1.3.3 code the inverted (C02) and open-degenerate (C03) cells
* FAIL: the backend screened only master lo > hi and filtered candidates with
* the two cross-interval inequalities, which are sufficient only once both
* intervals are known to be nonempty.
*
* Assertions are on MATCHED pair counts (r(N_matched_pairs)) and exact pair
* identities, not r(N_pairs): under the default unmatched(master) an unmatched
* master row is also emitted as an output row, so r(N_pairs) cannot distinguish
* "matched the inverted interval" from "correctly matched nothing".

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

* One master interval vs one using interval; assert the matched-pair count.
* tol is the tolerance() to apply; unmatched(none) keeps N_pairs == matches.
capture program drop _rm_cell
program define _rm_cell, rclass
    args mlo mhi ulo uhi closed tol
    preserve
    clear
    quietly set obs 1
    quietly gen double ulow  = `ulo'
    quietly gen double uhigh = `uhi'
    tempfile u
    quietly save "`u'"
    clear
    quietly set obs 1
    quietly gen double mlow  = `mlo'
    quietly gen double mhigh = `mhi'
    quietly rangematch mlow mhigh using "`u'", overlap(ulow uhigh) ///
        closed(`closed') tolerance(`tol') unmatched(none)
    return scalar matched = r(N_matched_pairs)
    restore
end

* Assert one cell and record the outcome.
capture program drop _rm_assert_cell
program define _rm_assert_cell
    args tag mlo mhi ulo uhi closed tol expect
    _rm_cell `mlo' `mhi' `ulo' `uhi' `closed' `tol'
    local got = r(matched)
    if `got' == `expect' {
        c_local _cell_ok = 1
        display as result "  ok   `tag': matched=`got'"
    }
    else {
        c_local _cell_ok = 0
        display as error "  FAIL `tag': matched=`got' expected=`expect'"
    }
end

**# T1: inverted using interval is never a genuine match (RM-C02)
local ++test_count
local ok = 1
_rm_assert_cell "inverted [8,2] vs master [0,10] both" 0 10 8 2 both 0 0
local ok = `ok' & `_cell_ok'
_rm_assert_cell "inverted [8,2] vs master [0,10] none" 0 10 8 2 none 0 0
local ok = `ok' & `_cell_ok'
_rm_assert_cell "inverted [8,2] vs master [0,10] tol=5" 0 10 8 2 both 5 0
local ok = `ok' & `_cell_ok'
_rm_assert_cell "inverted using fully inside master" 0 100 60 40 both 0 0
local ok = `ok' & `_cell_ok'
if `ok' {
    local ++pass_count
    display as result "PASS: inverted using intervals emit no matches"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' T1_inverted_using"
    display as error "FAIL: inverted using intervals"
}

**# T2: inverted master interval is never a genuine match (symmetry)
local ++test_count
local ok = 1
_rm_assert_cell "inverted master [10,0] vs using [0,10] both" 10 0 0 10 both 0 0
local ok = `ok' & `_cell_ok'
_rm_assert_cell "inverted master [10,0] vs using [0,10] none" 10 0 0 10 none 0 0
local ok = `ok' & `_cell_ok'
_rm_assert_cell "both inverted" 10 0 8 2 both 0 0
local ok = `ok' & `_cell_ok'
if `ok' {
    local ++pass_count
    display as result "PASS: inverted master intervals emit no matches"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' T2_inverted_master"
    display as error "FAIL: inverted master intervals"
}

**# T3: open degenerate intervals are empty under closed(none) (RM-C03)
local ++test_count
local ok = 1
_rm_assert_cell "master-degenerate (0,0) vs (-1,1)" 0 0 -1 1 none 0 0
local ok = `ok' & `_cell_ok'
_rm_assert_cell "using-degenerate (-1,1) vs (0,0)" -1 1 0 0 none 0 0
local ok = `ok' & `_cell_ok'
_rm_assert_cell "both degenerate (0,0) vs (0,0)" 0 0 0 0 none 0 0
local ok = `ok' & `_cell_ok'
if `ok' {
    local ++pass_count
    display as result "PASS: closed(none) degenerate intervals are empty"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' T3_degenerate_none"
    display as error "FAIL: closed(none) degenerate intervals"
}

**# T4: tolerance() must not resurrect an empty open-degenerate interval
local ++test_count
local ok = 1
_rm_assert_cell "master-degenerate (0,0) vs (-1,1) tol=5" 0 0 -1 1 none 5 0
local ok = `ok' & `_cell_ok'
_rm_assert_cell "using-degenerate (-1,1) vs (0,0) tol=5" -1 1 0 0 none 5 0
local ok = `ok' & `_cell_ok'
if `ok' {
    local ++pass_count
    display as result "PASS: tolerance does not widen an empty interval"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' T4_tol_degenerate"
    display as error "FAIL: tolerance widened an empty interval"
}

**# T5: CONTROL -- closed(both) degenerate is a VALID single point
local ++test_count
local ok = 1
_rm_assert_cell "[0,0] vs [0,0] both" 0 0 0 0 both 0 1
local ok = `ok' & `_cell_ok'
_rm_assert_cell "[0,0] vs [-1,1] both" 0 0 -1 1 both 0 1
local ok = `ok' & `_cell_ok'
_rm_assert_cell "[-1,1] vs [0,0] both" -1 1 0 0 both 0 1
local ok = `ok' & `_cell_ok'
if `ok' {
    local ++pass_count
    display as result "PASS: closed(both) degenerate point still matches"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' T5_control_both_degenerate"
    display as error "FAIL: closed(both) degenerate control regressed"
}

**# T6: CONTROL -- genuine overlaps and boundary semantics are unchanged
local ++test_count
local ok = 1
_rm_assert_cell "genuine overlap both" 0 10 5 15 both 0 1
local ok = `ok' & `_cell_ok'
_rm_assert_cell "genuine overlap none" 0 10 5 15 none 0 1
local ok = `ok' & `_cell_ok'
_rm_assert_cell "disjoint" 0 10 20 30 both 0 0
local ok = `ok' & `_cell_ok'
_rm_assert_cell "touching endpoints both" 0 5 5 9 both 0 1
local ok = `ok' & `_cell_ok'
_rm_assert_cell "touching endpoints none" 0 5 5 9 none 0 0
local ok = `ok' & `_cell_ok'
_rm_assert_cell "nested using inside master" 0 100 40 60 both 0 1
local ok = `ok' & `_cell_ok'
if `ok' {
    local ++pass_count
    display as result "PASS: genuine overlap/boundary semantics unchanged"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' T6_control_genuine"
    display as error "FAIL: genuine overlap control regressed"
}

**# T7: CONTROL -- open-ended (missing) bounds stay valid, not "inverted"
*       A missing bound means unrestricted on that side, so the interval is
*       nonempty; validity is screened AFTER the -/+ infinity substitution.
local ++test_count
local ok = 1
_rm_assert_cell "master [.,5] vs using [1,2] both" . 5 1 2 both 0 1
local ok = `ok' & `_cell_ok'
_rm_assert_cell "master [0,10] vs using [.,.] both" 0 10 . . both 0 1
local ok = `ok' & `_cell_ok'
_rm_assert_cell "master [.,.] vs using [.,.] none" . . . . none 0 1
local ok = `ok' & `_cell_ok'
_rm_assert_cell "master [5,.] vs using [9,20] none" 5 . 9 20 none 0 1
local ok = `ok' & `_cell_ok'
if `ok' {
    local ++pass_count
    display as result "PASS: open-ended bounds remain valid intervals"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' T7_control_open_ended"
    display as error "FAIL: open-ended bound control regressed"
}

**# T8: exact pair identities -- an inverted using row must not appear in the
*       output, and the valid rows around it must be matched exactly once.
local ++test_count
capture noisily {
    clear
    quietly set obs 3
    quietly gen long uid = _n
    quietly gen double ulow  = .
    quietly gen double uhigh = .
    * row 1 valid, row 2 INVERTED, row 3 valid
    quietly replace ulow = 1  in 1
    quietly replace uhigh = 2 in 1
    quietly replace ulow = 8  in 2
    quietly replace uhigh = 2 in 2
    quietly replace ulow = 3  in 3
    quietly replace uhigh = 4 in 3
    tempfile u8
    quietly save "`u8'"
    clear
    quietly set obs 1
    quietly gen double mlow = 0
    quietly gen double mhigh = 10
    rangematch mlow mhigh using "`u8'", overlap(ulow uhigh) ///
        unmatched(none) keepusing(uid)
    local n_matched = r(N_matched_pairs)
    * Exactly the two valid using rows, never the inverted one.
    quietly count
    assert r(N) == 2
    assert `n_matched' == 2
    quietly count if uid == 2
    assert r(N) == 0
    quietly count if uid == 1
    assert r(N) == 1
    quietly count if uid == 3
    assert r(N) == 1
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: inverted using row absent from exact pair set"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' T8_exact_pairset"
    display as error "FAIL: exact pair set with an inverted using row"
}

**# T9: an empty using interval surfaces as UNMATCHED using, not as a match
local ++test_count
capture noisily {
    clear
    quietly set obs 2
    quietly gen long uid = _n
    quietly gen double ulow  = .
    quietly gen double uhigh = .
    quietly replace ulow = 1  in 1
    quietly replace uhigh = 2 in 1
    quietly replace ulow = 8  in 2
    quietly replace uhigh = 2 in 2
    tempfile u9
    quietly save "`u9'"
    clear
    quietly set obs 1
    quietly gen double mlow = 0
    quietly gen double mhigh = 10
    rangematch mlow mhigh using "`u9'", overlap(ulow uhigh) ///
        unmatched(using) keepusing(uid) generate(_mrg)
    * Capture returns BEFORE any count: count overwrites r().
    local n_inv = r(N_using_inverted)
    * The inverted row must appear exactly once, as a using-only row.
    quietly count if uid == 2 & _mrg == 2
    assert r(N) == 1
    quietly count if uid == 2 & _mrg == 3
    assert r(N) == 0
    * r(N_using_inverted) diagnostic is retained alongside the screen.
    assert `n_inv' == 1
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: empty using interval surfaces as unmatched using"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' T9_unmatched_using"
    display as error "FAIL: empty using interval disposition"
}

**# T10: the inverted-interval warning and count contract still hold
local ++test_count
capture noisily {
    clear
    quietly set obs 1
    quietly gen double ulow = 8
    quietly gen double uhigh = 2
    tempfile u10
    quietly save "`u10'"
    clear
    quietly set obs 1
    quietly gen double mlow = 0
    quietly gen double mhigh = 10
    rangematch mlow mhigh using "`u10'", overlap(ulow uhigh)
    assert r(N_using_inverted) == 1
    assert r(N_matched_pairs) == 0
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: r(N_using_inverted) diagnostic retained"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' T10_diagnostic"
    display as error "FAIL: inverted diagnostic contract"
}

capture program drop _rm_cell
capture program drop _rm_assert_cell

display as result _newline "INTERVAL VALIDITY TEST SUMMARY"
display as result "Tests:  `test_count'"
display as result "Passed: `pass_count'"
display as result "Failed: `fail_count'"
if `fail_count' > 0 {
    display as error "Failed tests:`failed_tests'"
    display "RESULT: test_rangematch_interval_validity tests=`test_count' pass=`pass_count' fail=`fail_count'"
    exit 9
}
display "RESULT: test_rangematch_interval_validity tests=`test_count' pass=`pass_count' fail=`fail_count'"
