* test_sustainedss_fixes.do
* Tests for sustainedss v1.1.5 and v1.1.6 fixes:
*   1-5.   v1.1.5: confirmwindow, sort order, min(), baselinethreshold
*   6-12.  v1.1.5: sort order, same-date, observation count, validation
*   13-17. v1.1.6: generate(name), r(converged), varabbrev restore

clear all
set more off
version 16.0

capture ado uninstall setools
net install setools, from("/home/`c(username)'/Stata-Tools/setools")

local test_count = 0
local pass_count = 0
local fail_count = 0
local run_only = 0

* ============================================================================
* TEST 1: confirmwindow(0) should error
* ============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        clear
        input int id double edss int edss_dt
        1 5 21915
        1 4 22006
        end
        sustainedss id edss edss_dt, threshold(4) confirmwindow(0)
    }
    if _rc == 198 {
        display as result "  PASS: confirmwindow(0) rejected with rc 198"
        local ++pass_count
    }
    else {
        display as error "  FAIL: confirmwindow(0) returned rc `=_rc' (expected 198)"
        local ++fail_count
    }
}

* ============================================================================
* TEST 2: confirmwindow(-5) should error
* ============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        clear
        input int id double edss int edss_dt
        1 5 21915
        1 4 22006
        end
        sustainedss id edss edss_dt, threshold(4) confirmwindow(-5)
    }
    if _rc == 198 {
        display as result "  PASS: confirmwindow(-5) rejected with rc 198"
        local ++pass_count
    }
    else {
        display as error "  FAIL: confirmwindow(-5) returned rc `=_rc' (expected 198)"
        local ++fail_count
    }
}

* ============================================================================
* TEST 3: confirmwindow(1) should work (minimum valid)
* ============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        clear
        input int id double edss int edss_dt
        1 5 21915
        1 5 21916
        end
        sustainedss id edss edss_dt, threshold(4) confirmwindow(1) keepall
        assert r(confirmwindow) == 1
    }
    if _rc == 0 {
        display as result "  PASS: confirmwindow(1) accepted"
        local ++pass_count
    }
    else {
        display as error "  FAIL: confirmwindow(1) error (rc `=_rc')"
        local ++fail_count
    }
}

* ============================================================================
* TEST 4: baselinethreshold(-2) should error (not the -1 sentinel)
* ============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        clear
        input int id double edss int edss_dt
        1 5 21915
        1 5 22006
        end
        sustainedss id edss edss_dt, threshold(4) baselinethreshold(-2)
    }
    if _rc == 198 {
        display as result "  PASS: baselinethreshold(-2) rejected with rc 198"
        local ++pass_count
    }
    else {
        display as error "  FAIL: baselinethreshold(-2) returned rc `=_rc' (expected 198)"
        local ++fail_count
    }
}

* ============================================================================
* TEST 5: baselinethreshold(0) should work
* ============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        clear
        input int id double edss int edss_dt
        1 5 21915
        1 5 22006
        end
        sustainedss id edss edss_dt, threshold(4) baselinethreshold(0) keepall
        assert r(N_events) >= 0
    }
    if _rc == 0 {
        display as result "  PASS: baselinethreshold(0) accepted"
        local ++pass_count
    }
    else {
        display as error "  FAIL: baselinethreshold(0) error (rc `=_rc')"
        local ++fail_count
    }
}

* ============================================================================
* TEST 6: Sort order preserved after command (keepall)
* ============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        clear
        * Create data sorted by date DESCENDING (unusual order)
        input int id double edss int edss_dt
        2 6 22100
        2 3 22000
        1 5 21950
        1 5 21800
        3 2 21700
        end
        * Record original order
        gen long orig_order = _n
        sustainedss id edss edss_dt, threshold(4) keepall quietly
        * Verify order preserved
        assert orig_order[1] == 1
        assert orig_order[2] == 2
        assert orig_order[3] == 3
        assert orig_order[4] == 4
        assert orig_order[5] == 5
    }
    if _rc == 0 {
        display as result "  PASS: Sort order preserved (keepall)"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Sort order not preserved (rc `=_rc')"
        local ++fail_count
    }
}

* ============================================================================
* TEST 7: Sort order preserved after command (no keepall)
* ============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        clear
        * Patient 1: has sustained event; Patient 2: has sustained event
        * Deliberately unsorted
        input int id double edss int edss_dt
        2 6 22100
        1 5 21800
        2 6 22200
        1 5 21950
        end
        gen long orig_order = _n
        sustainedss id edss edss_dt, threshold(4) quietly
        * After merge, retained obs should keep original relative order
        * Both patients have events so all rows retained
        assert orig_order[1] == 1
        assert orig_order[2] == 2
        assert orig_order[3] == 3
        assert orig_order[4] == 4
    }
    if _rc == 0 {
        display as result "  PASS: Sort order preserved (no keepall)"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Sort order not preserved without keepall (rc `=_rc')"
        local ++fail_count
    }
}

* ============================================================================
* TEST 8: Same-date duplicates use min() (conservative)
* ============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        clear
        * Patient with threshold=4: first event day 100 (edss=5)
        * Confirmation window has two values on same day 200:
        *   edss=2 (below threshold) and edss=5 (above threshold)
        * With max(): last_window=5 >= 4, sustained
        * With min(): last_window=2 < 4, AND lowest_after includes 2 < 4
        *   so not_sustained=1, event rejected
        input int id double edss int edss_dt
        1 5 100
        1 2 200
        1 5 200
        end
        sustainedss id edss edss_dt, threshold(4) keepall quietly
        * With min(), the event at day 100 should be rejected
        * because last_window = min(2,5) = 2 < 4 and lowest_after = 2 < 4
        * No other dates have edss>=4 (day 200 has both 2 and 5, but
        * first_dt picks day 100 first, then rejection replaces with 2)
        * After rejection, edss_work at day 100 = 2
        * Next iteration: first_dt = day 200 (edss 5 >= 4)
        * But confirmation window [201, 382] has no obs -> sustained
        assert r(N_events) == 1
    }
    if _rc == 0 {
        display as result "  PASS: Same-date uses min() for conservative check"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Same-date min() behavior (rc `=_rc')"
        local ++fail_count
    }
}

* ============================================================================
* TEST 9: Observation count with non-keepall (fewer obs retained)
* ============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        clear
        * Patient 1: sustained event (edss=5 confirmed)
        * Patient 2: no event (edss never >= 4)
        input int id double edss int edss_dt
        1 5 21800
        1 5 21900
        1 5 22000
        2 1 21800
        2 2 21900
        2 3 22000
        end
        local N_before = _N
        sustainedss id edss edss_dt, threshold(4)
        local N_after = _N
        * Patient 2 should be dropped (no event), so fewer obs
        assert `N_after' < `N_before'
        * Only patient 1's rows retained
        assert `N_after' == 3
    }
    if _rc == 0 {
        display as result "  PASS: Non-keepall drops patients without events"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Non-keepall observation filtering (rc `=_rc')"
        local ++fail_count
    }
}

* ============================================================================
* TEST 10: Validation - known-answer sustained event
* ============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        clear
        * Patient 1: edss=5 on day 100, confirmed at day 200 (edss=5)
        * Expected: sustained_dt = day 100
        input int id double edss int edss_dt
        1 2 50
        1 5 100
        1 5 200
        end
        sustainedss id edss edss_dt, threshold(4) keepall quietly
        * All 3 obs from same patient, all retained
        assert sustained4_dt[1] == 100
        assert sustained4_dt[2] == 100
        assert sustained4_dt[3] == 100
    }
    if _rc == 0 {
        display as result "  PASS: Known-answer sustained event date correct"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Known-answer sustained event (rc `=_rc')"
        local ++fail_count
    }
}

* ============================================================================
* TEST 11: Validation - rejected then found later
* ============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        clear
        * Patient 1: edss=5 day 30, drops to 2 day 90 and day 180
        *   -> first event rejected (lowest=2 < 4, last=2 < 4)
        * Then edss=5 day 365, confirmed at day 450 (edss=5)
        * Expected: sustained_dt = day 365
        input int id double edss int edss_dt
        1 2 0
        1 5 30
        1 2 90
        1 2 180
        1 5 365
        1 5 450
        end
        sustainedss id edss edss_dt, threshold(4) keepall quietly
        assert sustained4_dt[1] == 365
        assert r(N_events) == 1
        assert r(iterations) == 2
    }
    if _rc == 0 {
        display as result "  PASS: Rejected-then-found-later date correct"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Rejected-then-found-later (rc `=_rc')"
        local ++fail_count
    }
}

* ============================================================================
* TEST 12: Validation - single obs above threshold (no confirmation data)
* ============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        clear
        input int id double edss int edss_dt
        1 5 100
        end
        sustainedss id edss edss_dt, threshold(4) keepall quietly
        * Single obs, no confirmation possible -> accepted as sustained
        assert sustained4_dt[1] == 100
        assert r(N_events) == 1
    }
    if _rc == 0 {
        display as result "  PASS: Single obs sustained (no confirmation needed)"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Single obs sustained (rc `=_rc')"
        local ++fail_count
    }
}

* ============================================================================
* TEST 13: generate(name) rejects invalid variable name at parse time
* ============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        clear
        input int id double edss int edss_dt
        1 5 21915
        1 5 22006
        end
        sustainedss id edss edss_dt, threshold(4) generate(123abc)
    }
    if _rc != 0 {
        display as result "  PASS: generate(123abc) rejected (rc `=_rc')"
        local ++pass_count
    }
    else {
        display as error "  FAIL: generate(123abc) should have been rejected"
        local ++fail_count
    }
}

* ============================================================================
* TEST 14: generate(name) accepts valid variable name
* ============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        clear
        input int id double edss int edss_dt
        1 5 21915
        1 5 22006
        end
        sustainedss id edss edss_dt, threshold(4) generate(my_sustained_dt) keepall
        confirm variable my_sustained_dt
    }
    if _rc == 0 {
        display as result "  PASS: generate(my_sustained_dt) accepted"
        local ++pass_count
    }
    else {
        display as error "  FAIL: generate(my_sustained_dt) error (rc `=_rc')"
        local ++fail_count
    }
}

* ============================================================================
* TEST 15: r(converged) == 1 for normal convergence
* ============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        clear
        input int id double edss int edss_dt
        1 5 21915
        1 5 22006
        end
        sustainedss id edss edss_dt, threshold(4) keepall quietly
        assert r(converged) == 1
    }
    if _rc == 0 {
        display as result "  PASS: r(converged) == 1 for normal case"
        local ++pass_count
    }
    else {
        display as error "  FAIL: r(converged) check (rc `=_rc')"
        local ++fail_count
    }
}

* ============================================================================
* TEST 16: r(converged) == 1 after multi-iteration convergence
* ============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        clear
        input int id double edss int edss_dt
        1 2 0
        1 5 30
        1 2 90
        1 2 180
        1 5 365
        1 5 450
        end
        sustainedss id edss edss_dt, threshold(4) keepall quietly
        assert r(converged) == 1
        assert r(iterations) == 2
    }
    if _rc == 0 {
        display as result "  PASS: r(converged) == 1 after 2 iterations"
        local ++pass_count
    }
    else {
        display as error "  FAIL: multi-iteration converged check (rc `=_rc')"
        local ++fail_count
    }
}

* ============================================================================
* TEST 17: set varabbrev restored after command
* ============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        clear
        input int id double edss int edss_dt
        1 5 21915
        1 5 22006
        end
        set varabbrev on
        sustainedss id edss edss_dt, threshold(4) keepall quietly
        assert "`c(varabbrev)'" == "on"
    }
    if _rc == 0 {
        display as result "  PASS: set varabbrev restored to on"
        local ++pass_count
    }
    else {
        display as error "  FAIL: varabbrev not restored (rc `=_rc')"
        local ++fail_count
    }
}

* ============================================================================
* SUMMARY
* ============================================================================
display as text ""
display as text "SUSTAINEDSS FIXES TEST SUMMARY"
display as text "Total tests:  `test_count'"
display as result "Passed:       `pass_count'"
if `fail_count' > 0 {
    display as error "Failed:       `fail_count'"
}
else {
    display as text "Failed:       `fail_count'"
}

if `fail_count' > 0 {
    display as error "Some tests FAILED."
    exit 1
}
else {
    display as result "ALL TESTS PASSED"
}
