/*******************************************************************************
* validation_consort_expanded.do
*
* Purpose: Expanded validation tests for consort command — known-answer tests
*          for save return values, CSV format integrity, conservation invariants,
*          order independence, and idempotency.
*
* Author: Timothy P Copeland
* Date: 2026-03-21
*******************************************************************************/

clear all
set more off
version 16.0

* Install package

* === Bootstrap ===
local qa_dir  "`c(pwd)'"
local pkg_dir "`qa_dir'/.."  

capture ado uninstall consort
quietly net install consort, from("`pkg_dir'/") replace

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

* Helper: clear consort state
capture program drop _clear_consort_state
program define _clear_consort_state
    capture consort clear, quiet
    global CONSORT_FILE ""
    global CONSORT_N ""
    global CONSORT_ACTIVE ""
    global CONSORT_STEPS ""
    global CONSORT_TEMPFILE ""
    global CONSORT_SCRIPT_PATH ""
end

* =============================================================================
* V1: SAVE RETURN VALUE CONSERVATION
* =============================================================================
* Invariant: r(N_initial) == r(N_final) + r(N_excluded)
* Hand-calculated:
*   Start: 100
*   Exclude ids 1-20: 20 excluded, 80 remain
*   Exclude ids 21-50: 30 excluded, 50 remain
*   Total excluded: 50, Final: 50
*   Conservation: 100 == 50 + 50

* Test 1: Conservation with deterministic dataset
local ++test_count
capture noisily {
    _clear_consort_state
    clear
    set obs 100
    gen id = _n

    consort init, initial("100 subjects")
    consort exclude if id <= 20, label("First 20")
    consort exclude if id <= 50, label("Ids 21-50")
    consort save, output("/tmp/val_exp_v1t1.png") final("Final 50")

    assert r(N_initial) == 100
    assert r(N_final) == 50
    assert r(N_excluded) == 50
    assert r(N_initial) == r(N_final) + r(N_excluded)
    assert r(steps) == 2
}
if _rc == 0 {
    display as result "  PASS `test_count': V1 conservation (100 = 50 + 50)"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': V1 conservation (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}
capture erase "/tmp/val_exp_v1t1.png"
_clear_consort_state

* Test 2: Conservation with many steps
* Start: 50, exclude 5+5+5+5+5 = 25, final = 25
local ++test_count
capture noisily {
    _clear_consort_state
    clear
    set obs 50
    gen id = _n

    consort init, initial("50 subjects")
    consort exclude if id <= 5, label("Step 1")
    consort exclude if id <= 10, label("Step 2")
    consort exclude if id <= 15, label("Step 3")
    consort exclude if id <= 20, label("Step 4")
    consort exclude if id <= 25, label("Step 5")
    consort save, output("/tmp/val_exp_v1t2.png") final("Final")

    assert r(N_initial) == 50
    assert r(N_final) == 25
    assert r(N_excluded) == 25
    assert r(N_initial) == r(N_final) + r(N_excluded)
    assert r(steps) == 5
}
if _rc == 0 {
    display as result "  PASS `test_count': V1 conservation with 5 steps (50 = 25 + 25)"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': V1 conservation 5 steps (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}
capture erase "/tmp/val_exp_v1t2.png"
_clear_consort_state

* =============================================================================
* V2: SAVE RETURN VALUE CONSISTENCY WITH EXCLUDE RETURN VALUES
* =============================================================================
* Invariant: sum(all r(n_excluded)) == save r(N_excluded)
* Hand-calculated:
*   Start: 80
*   Exclude ids 1-10: 10 excluded
*   Exclude ids 11-30: 20 excluded
*   Exclude ids 31-40: 10 excluded
*   Total from excludes: 10 + 20 + 10 = 40
*   Save r(N_excluded) should be 40

* Test 3: Sum of exclude r(n_excluded) matches save r(N_excluded)
local ++test_count
capture noisily {
    _clear_consort_state
    clear
    set obs 80
    gen id = _n

    consort init, initial("80 subjects")

    consort exclude if id <= 10, label("Step 1")
    local sum_excl = r(n_excluded)

    consort exclude if id <= 30, label("Step 2")
    local sum_excl = `sum_excl' + r(n_excluded)

    consort exclude if id <= 40, label("Step 3")
    local sum_excl = `sum_excl' + r(n_excluded)

    consort save, output("/tmp/val_exp_v2.png") final("Final")

    * Sum from individual excludes should match save total
    assert `sum_excl' == r(N_excluded)
    assert `sum_excl' == 40
    assert r(N_excluded) == 40
}
if _rc == 0 {
    display as result "  PASS `test_count': V2 sum(n_excluded) == N_excluded (40)"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': V2 sum consistency (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}
capture erase "/tmp/val_exp_v2.png"
_clear_consort_state

* =============================================================================
* V3: CSV FILE ROW COUNT
* =============================================================================
* Invariant: CSV has 1 header + 1 init row + N exclusion rows
* For 3 exclusion steps: 1 + 1 + 3 = 5 lines

* Test 4: CSV row count matches steps + 2 (header + init)
local ++test_count
capture noisily {
    _clear_consort_state
    clear
    set obs 100
    gen id = _n

    consort init, initial("100 subjects") file("/tmp/val_exp_v3.csv")
    consort exclude if id <= 20, label("Step 1")
    consort exclude if id <= 40, label("Step 2")
    consort exclude if id <= 60, label("Step 3")

    * Count CSV lines
    local csvfile "/tmp/val_exp_v3.csv"
    tempname fh
    file open `fh' using "`csvfile'", read text
    local nlines = 0
    file read `fh' line
    while r(eof) == 0 {
        local ++nlines
        file read `fh' line
    }
    file close `fh'

    * Expected: header(1) + init(1) + 3 exclusions = 5
    assert `nlines' == 5
}
if _rc == 0 {
    display as result "  PASS `test_count': V3 CSV row count (5 lines for 3 steps)"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': V3 CSV row count (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}
capture erase "/tmp/val_exp_v3.csv"
_clear_consort_state

* =============================================================================
* V4: CSV CONTENT VALIDATION
* =============================================================================
* Verify CSV contains correct labels and counts line by line
* Dataset: 20 obs, exclude ids 1-5, then 6-10
* Expected CSV:
*   Line 1: "label,n,remaining"
*   Line 2: initial label, 20
*   Line 3: "First 5", 5
*   Line 4: "Second 5", 5

* Test 5: CSV label and count verification
local ++test_count
capture noisily {
    _clear_consort_state
    clear
    set obs 20
    gen id = _n

    consort init, initial("Twenty subjects") file("/tmp/val_exp_v4.csv")
    consort exclude if id <= 5, label("First 5")
    consort exclude if id <= 10, label("Second 5")

    * Read and verify each line
    tempname fh
    file open `fh' using "/tmp/val_exp_v4.csv", read text

    * Line 1: header
    file read `fh' line
    assert `"`macval(line)'"' == "label,n,remaining"

    * Line 2: initial — should contain "Twenty subjects" and 20
    file read `fh' line
    local has_label = strpos(`"`macval(line)'"', "Twenty subjects")
    local has_count = strpos(`"`macval(line)'"', "20")
    assert `has_label' > 0
    assert `has_count' > 0

    * Line 3: first exclusion — "First 5" and 5
    file read `fh' line
    local has_label = strpos(`"`macval(line)'"', "First 5")
    local has_count = strpos(`"`macval(line)'"', "5")
    assert `has_label' > 0
    assert `has_count' > 0

    * Line 4: second exclusion — "Second 5" and 5
    file read `fh' line
    local has_label = strpos(`"`macval(line)'"', "Second 5")
    local has_count = strpos(`"`macval(line)'"', "5")
    assert `has_label' > 0
    assert `has_count' > 0

    file close `fh'
}
if _rc == 0 {
    display as result "  PASS `test_count': V4 CSV content verified line by line"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': V4 CSV content (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}
capture erase "/tmp/val_exp_v4.csv"
_clear_consort_state

* Test 6: CSV remaining field populated when remaining() specified
local ++test_count
capture noisily {
    _clear_consort_state
    clear
    set obs 30
    gen id = _n

    consort init, initial("Thirty") file("/tmp/val_exp_v4b.csv")
    consort exclude if id <= 10, label("First 10") remaining("Twenty left")

    * Read exclusion line and check remaining field
    tempname fh
    file open `fh' using "/tmp/val_exp_v4b.csv", read text
    file read `fh' line
    * skip header
    file read `fh' line
    * skip init
    file read `fh' line
    * exclusion line
    file close `fh'

    local has_remaining = strpos(`"`macval(line)'"', "Twenty left")
    assert `has_remaining' > 0
}
if _rc == 0 {
    display as result "  PASS `test_count': V4 CSV remaining field populated"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': V4 CSV remaining (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}
capture erase "/tmp/val_exp_v4b.csv"
_clear_consort_state

* =============================================================================
* V5: ORDER INDEPENDENCE (NON-OVERLAPPING EXCLUSIONS)
* =============================================================================
* If exclusions don't overlap, total excluded is same regardless of order
* Dataset: 30 obs
*   Flag A: ids 1-10 (10 obs)
*   Flag B: ids 11-20 (10 obs)
* Order 1: A then B → total excluded = 20
* Order 2: B then A → total excluded = 20

* Test 7: Order A-then-B
local ++test_count
capture noisily {
    _clear_consort_state
    clear
    set obs 30
    gen id = _n
    gen flagA = (id <= 10)
    gen flagB = (id > 10 & id <= 20)

    consort init, initial("30 subjects")
    consort exclude if flagA == 1, label("Flag A")
    local exclA = r(n_excluded)
    consort exclude if flagB == 1, label("Flag B")
    local exclB = r(n_excluded)
    local total_AB = `exclA' + `exclB'

    assert `exclA' == 10
    assert `exclB' == 10
    assert `total_AB' == 20
    assert _N == 10
}
if _rc == 0 {
    display as result "  PASS `test_count': V5 order A-B total = 20"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': V5 order A-B (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}
_clear_consort_state

* Test 8: Order B-then-A gives same total
local ++test_count
capture noisily {
    _clear_consort_state
    clear
    set obs 30
    gen id = _n
    gen flagA = (id <= 10)
    gen flagB = (id > 10 & id <= 20)

    consort init, initial("30 subjects")
    consort exclude if flagB == 1, label("Flag B")
    local exclB = r(n_excluded)
    consort exclude if flagA == 1, label("Flag A")
    local exclA = r(n_excluded)
    local total_BA = `exclB' + `exclA'

    assert `exclB' == 10
    assert `exclA' == 10
    assert `total_BA' == 20
    assert _N == 10
}
if _rc == 0 {
    display as result "  PASS `test_count': V5 order B-A total = 20 (same)"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': V5 order B-A (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}
_clear_consort_state

* Test 9: Both orders leave same remaining observations
local ++test_count
capture noisily {
    _clear_consort_state

    * Order A-B
    clear
    set obs 30
    gen id = _n
    gen flagA = (id <= 10)
    gen flagB = (id > 10 & id <= 20)

    consort init, initial("30")
    consort exclude if flagA == 1, label("A")
    consort exclude if flagB == 1, label("B")
    sort id
    local remaining_AB ""
    forvalues i = 1/`=_N' {
        local remaining_AB "`remaining_AB' `=id[`i']'"
    }
    _clear_consort_state

    * Order B-A
    clear
    set obs 30
    gen id = _n
    gen flagA = (id <= 10)
    gen flagB = (id > 10 & id <= 20)

    consort init, initial("30")
    consort exclude if flagB == 1, label("B")
    consort exclude if flagA == 1, label("A")
    sort id
    local remaining_BA ""
    forvalues i = 1/`=_N' {
        local remaining_BA "`remaining_BA' `=id[`i']'"
    }

    * Same observations remain
    assert "`remaining_AB'" == "`remaining_BA'"
}
if _rc == 0 {
    display as result "  PASS `test_count': V5 same observations remain regardless of order"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': V5 same remaining obs (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}
_clear_consort_state

* =============================================================================
* V6: IDEMPOTENCY
* =============================================================================
* Clear then re-run same workflow → identical results

* Test 10: Idempotent workflow
local ++test_count
capture noisily {
    _clear_consort_state

    * Run 1
    clear
    set obs 60
    gen id = _n
    gen flag1 = (id <= 15)
    gen flag2 = (id > 30 & id <= 45)

    consort init, initial("60 subjects")
    consort exclude if flag1 == 1, label("Flag 1")
    local e1_run1 = r(n_excluded)
    local r1_run1 = r(n_remaining)
    consort exclude if flag2 == 1, label("Flag 2")
    local e2_run1 = r(n_excluded)
    local r2_run1 = r(n_remaining)
    consort save, output("/tmp/val_exp_v6a.png") final("Final")
    local Ni_run1 = r(N_initial)
    local Nf_run1 = r(N_final)
    local Ne_run1 = r(N_excluded)

    * Run 2 (after clear via save)
    clear
    set obs 60
    gen id = _n
    gen flag1 = (id <= 15)
    gen flag2 = (id > 30 & id <= 45)

    consort init, initial("60 subjects")
    consort exclude if flag1 == 1, label("Flag 1")
    local e1_run2 = r(n_excluded)
    local r1_run2 = r(n_remaining)
    consort exclude if flag2 == 1, label("Flag 2")
    local e2_run2 = r(n_excluded)
    local r2_run2 = r(n_remaining)
    consort save, output("/tmp/val_exp_v6b.png") final("Final")
    local Ni_run2 = r(N_initial)
    local Nf_run2 = r(N_final)
    local Ne_run2 = r(N_excluded)

    * All values identical
    assert `e1_run1' == `e1_run2'
    assert `r1_run1' == `r1_run2'
    assert `e2_run1' == `e2_run2'
    assert `r2_run1' == `r2_run2'
    assert `Ni_run1' == `Ni_run2'
    assert `Nf_run1' == `Nf_run2'
    assert `Ne_run1' == `Ne_run2'
}
if _rc == 0 {
    display as result "  PASS `test_count': V6 idempotent workflow"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': V6 idempotency (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}
capture erase "/tmp/val_exp_v6a.png"
capture erase "/tmp/val_exp_v6b.png"
_clear_consort_state

* =============================================================================
* V7: EXACT KNOWN-ANSWER FOR SAVE RETURN VALUES
* =============================================================================
* Dataset: exactly 1000 obs
* Exclude step 1: ids 1-300 → 300 excluded, 700 remain
* Exclude step 2: ids 301-500 → 200 excluded, 500 remain
* Exclude step 3: ids 501-600 → 100 excluded, 400 remain
* Total excluded: 600. Final: 400. Steps: 3.

* Test 11: Known-answer save return values
local ++test_count
capture noisily {
    _clear_consort_state
    clear
    set obs 1000
    gen id = _n

    consort init, initial("1000 subjects")
    consort exclude if id <= 300, label("Step 1: first 300")
    assert r(n_excluded) == 300
    assert r(n_remaining) == 700

    consort exclude if id <= 500, label("Step 2: ids 301-500")
    assert r(n_excluded) == 200
    assert r(n_remaining) == 500

    consort exclude if id <= 600, label("Step 3: ids 501-600")
    assert r(n_excluded) == 100
    assert r(n_remaining) == 400

    consort save, output("/tmp/val_exp_v7.png") final("Final 400")

    assert r(N_initial) == 1000
    assert r(N_final) == 400
    assert r(N_excluded) == 600
    assert r(steps) == 3
    assert r(N_initial) == r(N_final) + r(N_excluded)
}
if _rc == 0 {
    display as result "  PASS `test_count': V7 known-answer save returns (1000→400)"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': V7 known-answer (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}
capture erase "/tmp/val_exp_v7.png"
_clear_consort_state

* =============================================================================
* V8: DATA INTEGRITY — REMAINING OBSERVATIONS ARE CORRECT
* =============================================================================
* After exclusions, verify the exact set of remaining observations
* Dataset: 10 obs with ids 1-10
* Exclude ids 2,4,6,8 (even numbers) → remaining should be 1,3,5,7,9,10

* Test 12: Remaining observation IDs match expected
local ++test_count
capture noisily {
    _clear_consort_state
    clear
    set obs 10
    gen id = _n

    consort init, initial("10 subjects")
    consort exclude if mod(id, 2) == 0 & id < 10, label("Even < 10")

    * Should have 6 remaining: 1, 3, 5, 7, 9, 10
    assert _N == 6
    sort id
    assert id[1] == 1
    assert id[2] == 3
    assert id[3] == 5
    assert id[4] == 7
    assert id[5] == 9
    assert id[6] == 10
}
if _rc == 0 {
    display as result "  PASS `test_count': V8 remaining IDs match expected"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': V8 data integrity (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}
_clear_consort_state

* Test 13: Sequential exclusions cumulative data integrity
* Start: ids 1-20
* Exclude if id <= 5 → remaining 6-20 (15 obs)
* Exclude if id > 15 → remaining 6-15 (10 obs)
local ++test_count
capture noisily {
    _clear_consort_state
    clear
    set obs 20
    gen id = _n

    consort init, initial("20 subjects")
    consort exclude if id <= 5, label("Low ids")
    assert _N == 15
    assert r(n_excluded) == 5

    consort exclude if id > 15, label("High ids")
    assert _N == 10
    assert r(n_excluded) == 5

    * Verify remaining are exactly 6-15
    sort id
    forvalues i = 1/10 {
        assert id[`i'] == `i' + 5
    }
}
if _rc == 0 {
    display as result "  PASS `test_count': V8 sequential exclusion data integrity"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': V8 sequential integrity (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}
_clear_consort_state

* =============================================================================
* V9: ZERO-MATCH EXCLUSION PRESERVES STATE
* =============================================================================
* Zero-match should not change data, not increment steps, not write to CSV

* Test 14: Zero-match does not add CSV row
local ++test_count
capture noisily {
    _clear_consort_state
    clear
    set obs 50
    gen id = _n

    consort init, initial("50 subjects") file("/tmp/val_exp_v9.csv")

    * Zero-match exclusion
    consort exclude if id > 1000, label("Impossible")

    * Real exclusion
    consort exclude if id <= 10, label("First 10")

    * Count CSV lines: should be header + init + 1 real exclusion = 3
    tempname fh
    file open `fh' using "/tmp/val_exp_v9.csv", read text
    local nlines = 0
    file read `fh' line
    while r(eof) == 0 {
        local ++nlines
        file read `fh' line
    }
    file close `fh'

    assert `nlines' == 3
}
if _rc == 0 {
    display as result "  PASS `test_count': V9 zero-match doesn't add CSV row"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': V9 zero-match CSV (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}
capture erase "/tmp/val_exp_v9.csv"
_clear_consort_state

* =============================================================================
* V10: LARGE DATASET CONSERVATION
* =============================================================================
* Use 100,000 observations to verify no numeric overflow or precision loss

* Test 15: Large dataset conservation
local ++test_count
capture noisily {
    _clear_consort_state
    clear
    set obs 100000
    gen id = _n

    consort init, initial("100K subjects")
    consort exclude if id <= 25000, label("First 25K")
    local e1 = r(n_excluded)
    consort exclude if id <= 50000, label("Second 25K")
    local e2 = r(n_excluded)
    consort exclude if id <= 75000, label("Third 25K")
    local e3 = r(n_excluded)
    consort save, output("/tmp/val_exp_v10.png") final("Final 25K")

    assert r(N_initial) == 100000
    assert r(N_final) == 25000
    assert r(N_excluded) == 75000
    assert `e1' == 25000
    assert `e2' == 25000
    assert `e3' == 25000
    assert `e1' + `e2' + `e3' == r(N_excluded)
    assert r(N_initial) == r(N_final) + r(N_excluded)
}
if _rc == 0 {
    display as result "  PASS `test_count': V10 large dataset conservation (100K)"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': V10 large dataset (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}
capture erase "/tmp/val_exp_v10.png"
_clear_consort_state

* =============================================================================
* SUMMARY
* =============================================================================
display as text _n "{hline 70}"
display as text "CONSORT EXPANDED VALIDATION SUMMARY"
display as text "{hline 70}"
display as text "Total tests:  `test_count'"
display as result "Passed:       `pass_count'"
if `fail_count' > 0 {
    display as error "Failed:       `fail_count'"
    display as error "Failed tests:`failed_tests'"
}
else {
    display as text "Failed:       0"
}
display as text "{hline 70}"

if `fail_count' > 0 {
    display as error _n "RESULT: FAIL"
    exit 1
}
else {
    display as result _n "RESULT: PASS"
}
