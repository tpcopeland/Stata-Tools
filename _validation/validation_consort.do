/*******************************************************************************
* validation_consort.do
*
* Purpose: Deep validation tests for consort command using known-answer testing.
*          These tests verify computed values match expected results, not just
*          that commands execute without error.
*
* Philosophy: Create minimal datasets where every output value can be
*             mathematically verified by hand.
*
* Run modes:
*   Standalone: do validation_consort.do
*   Via runner: do run_test.do validation_consort [testnumber] [quiet] [machine]
*
* Prerequisites:
*   - consort.ado must be installed/accessible
*
* Author: Timothy P Copeland
* Date: 2025-12-15
*******************************************************************************/

clear all
set more off
version 16.0

* =============================================================================
* CONFIGURATION: Check for runner globals or set defaults
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
* Cross-platform path detection
if "`c(os)'" == "MacOSX" {
    global STATA_TOOLS_PATH "/Users/tcopeland/Documents/GitHub/Stata-Tools"
}
else if "`c(os)'" == "Unix" {
    global STATA_TOOLS_PATH "/home/ubuntu/Stata-Tools"
}
else {
    * Windows or other - try to detect from current directory
    capture confirm file "_validation"
    if _rc == 0 {
        * Running from repo root
        global STATA_TOOLS_PATH "`c(pwd)'"
    }
    else {
        capture confirm file "data"
        if _rc == 0 {
            * Running from _validation directory
            global STATA_TOOLS_PATH "`c(pwd)'/.."
        }
        else {
            * Assume running from _validation/data directory
            global STATA_TOOLS_PATH "`c(pwd)'/../.."
        }
    }
}

global VALIDATION_DIR "${STATA_TOOLS_PATH}/_validation"
global DATA_DIR "${VALIDATION_DIR}/data"

* Create data directory if needed
capture mkdir "${DATA_DIR}"

* Install package
capture net uninstall consort
quietly net install consort, from("${STATA_TOOLS_PATH}/consort")

* =============================================================================
* HEADER (skip in quiet/machine mode)
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "CONSORT DEEP VALIDATION TESTS"
    display as text "{hline 70}"
    display as text "These tests verify mathematical correctness, not just execution."
    display as text "{hline 70}"
}

* =============================================================================
* TEST COUNTERS
* =============================================================================
local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

* =============================================================================
* HELPER: Clear consort state
* =============================================================================
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
* HELPER: Assert numeric equality with tolerance
* =============================================================================
capture program drop _assert_equal
program define _assert_equal
    args actual expected tolerance
    if "`tolerance'" == "" local tolerance = 0.0001
    local diff = abs(`actual' - `expected')
    if `diff' > `tolerance' {
        display as error "  Expected: `expected', Got: `actual' (diff: `diff')"
        exit 9
    }
end

* =============================================================================
* CREATE VALIDATION DATA
* =============================================================================
if `quiet' == 0 {
    display as text _n "Creating validation datasets..."
}

* Dataset 1: Known exclusion counts
* 100 observations, with known patterns for exclusions
clear
set obs 100
gen id = _n
gen group = mod(_n, 4)           // 25 each: 0, 1, 2, 3
gen has_missing = (_n <= 10)     // 10 with missing flag
gen is_foreign = (_n > 70)       // 30 foreign
gen price = 5000 + _n * 100      // 5100 to 15000
label data "100 obs: 10 missing, 30 foreign, prices 5100-15000"
save "${DATA_DIR}/valid_consort_100.dta", replace

* Dataset 2: Minimal 5-row dataset for exact calculations
clear
input long id byte(has_missing is_foreign) double price
    1 1 0 5000
    2 1 0 6000
    3 0 1 7000
    4 0 1 8000
    5 0 0 9000
end
label data "5 rows: 2 missing, 2 foreign, 1 clean"
save "${DATA_DIR}/valid_consort_5.dta", replace

if `quiet' == 0 {
    display as result "Validation datasets created in: ${DATA_DIR}"
}

* =============================================================================
* SECTION 1: KNOWN-ANSWER COUNT TESTS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 1: Known-Answer Count Tests"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 1.1: Initial count is exactly 100
* Purpose: Verify init captures correct N
* Known answer: N = 100
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 1.1: Initial count verification"
}

capture {
    _clear_consort_state
    use "${DATA_DIR}/valid_consort_100.dta", clear
    consort init, initial("All subjects")

    * Known answer: exactly 100
    assert r(N) == 100
    assert "${CONSORT_N}" == "100"
}
if _rc == 0 {
    display as result "  PASS: Initial count = 100"
    local ++pass_count
}
else {
    display as error "  FAIL: Initial count (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 1.1"
}
_clear_consort_state

* -----------------------------------------------------------------------------
* Test 1.2: Single exclusion removes exactly 10
* Purpose: Verify exclusion count is exact
* Known answer: has_missing == 1 removes exactly 10 observations
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 1.2: Single exclusion count"
}

capture {
    _clear_consort_state
    use "${DATA_DIR}/valid_consort_100.dta", clear
    consort init, initial("All subjects")
    consort exclude if has_missing == 1, label("Missing data")

    * Known answer: excluded 10, remaining 90
    assert r(n_excluded) == 10
    assert r(n_remaining) == 90
    assert _N == 90
}
if _rc == 0 {
    display as result "  PASS: Excluded 10, remaining 90"
    local ++pass_count
}
else {
    display as error "  FAIL: Single exclusion count (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 1.2"
}
_clear_consort_state

* -----------------------------------------------------------------------------
* Test 1.3: Sequential exclusions with known cumulative counts
* Purpose: Verify each exclusion step is exact
* Known answer:
*   Start: 100
*   After missing (10): 90
*   After foreign (30): 60
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 1.3: Sequential exclusion counts"
}

capture {
    _clear_consort_state
    use "${DATA_DIR}/valid_consort_100.dta", clear

    consort init, initial("All subjects")
    assert r(N) == 100

    consort exclude if has_missing == 1, label("Missing")
    assert r(n_excluded) == 10
    assert r(n_remaining) == 90
    assert _N == 90

    consort exclude if is_foreign == 1, label("Foreign")
    assert r(n_excluded) == 30
    assert r(n_remaining) == 60
    assert _N == 60
}
if _rc == 0 {
    display as result "  PASS: 100 -> 90 -> 60"
    local ++pass_count
}
else {
    display as error "  FAIL: Sequential exclusion counts (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 1.3"
}
_clear_consort_state

* -----------------------------------------------------------------------------
* Test 1.4: Minimal dataset (5 rows) exact counts
* Purpose: Hand-calculable dataset
* Known answer:
*   Start: 5
*   has_missing==1 removes rows 1,2: remaining 3
*   is_foreign==1 removes rows 3,4: remaining 1 (row 5 only)
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 1.4: Minimal dataset exact counts"
}

capture {
    _clear_consort_state
    use "${DATA_DIR}/valid_consort_5.dta", clear

    consort init, initial("5 subjects")
    assert r(N) == 5

    consort exclude if has_missing == 1, label("Missing")
    assert r(n_excluded) == 2
    assert r(n_remaining) == 3

    consort exclude if is_foreign == 1, label("Foreign")
    assert r(n_excluded) == 2
    assert r(n_remaining) == 1

    * Verify only row 5 remains
    assert _N == 1
    assert id[1] == 5
}
if _rc == 0 {
    display as result "  PASS: 5 -> 3 -> 1 (only id=5 remains)"
    local ++pass_count
}
else {
    display as error "  FAIL: Minimal dataset counts (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 1.4"
}
_clear_consort_state

* =============================================================================
* SECTION 2: INVARIANT TESTS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 2: Invariant Tests (Properties That Must Always Hold)"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 2.1: Conservation - excluded + remaining = initial
* Purpose: Verify no observations are lost or gained
* Invariant: sum(excluded at each step) + final N = initial N
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 2.1: Conservation invariant"
}

capture {
    _clear_consort_state
    use "${DATA_DIR}/valid_consort_100.dta", clear

    consort init, initial("All subjects")
    local initial_n = r(N)
    local total_excluded = 0

    consort exclude if has_missing == 1, label("Missing")
    local total_excluded = `total_excluded' + r(n_excluded)

    consort exclude if is_foreign == 1, label("Foreign")
    local total_excluded = `total_excluded' + r(n_excluded)

    consort exclude if price > 12000, label("High price")
    local total_excluded = `total_excluded' + r(n_excluded)

    local final_n = _N

    * Invariant: excluded + remaining = initial
    assert `total_excluded' + `final_n' == `initial_n'
}
if _rc == 0 {
    display as result "  PASS: excluded + remaining = initial"
    local ++pass_count
}
else {
    display as error "  FAIL: Conservation invariant (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 2.1"
}
_clear_consort_state

* -----------------------------------------------------------------------------
* Test 2.2: Monotonic decrease - N never increases during exclusions
* Purpose: Verify observations only decrease
* Invariant: N after each exclusion <= N before
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 2.2: Monotonic decrease invariant"
}

capture {
    _clear_consort_state
    use "${DATA_DIR}/valid_consort_100.dta", clear

    consort init, initial("All subjects")
    local prev_n = _N

    consort exclude if has_missing == 1, label("Missing")
    assert _N <= `prev_n'
    local prev_n = _N

    consort exclude if is_foreign == 1, label("Foreign")
    assert _N <= `prev_n'
    local prev_n = _N

    consort exclude if group == 0, label("Group 0")
    assert _N <= `prev_n'
}
if _rc == 0 {
    display as result "  PASS: N monotonically decreases"
    local ++pass_count
}
else {
    display as error "  FAIL: Monotonic decrease invariant (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 2.2"
}
_clear_consort_state

* -----------------------------------------------------------------------------
* Test 2.3: Step counter increments correctly
* Purpose: Verify step count matches exclusion calls
* Invariant: CONSORT_STEPS = number of exclude calls with n_excluded > 0
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 2.3: Step counter invariant"
}

capture {
    _clear_consort_state
    use "${DATA_DIR}/valid_consort_100.dta", clear

    consort init, initial("All subjects")
    assert ${CONSORT_STEPS} == 0

    consort exclude if has_missing == 1, label("Step 1")
    assert ${CONSORT_STEPS} == 1

    consort exclude if is_foreign == 1, label("Step 2")
    assert ${CONSORT_STEPS} == 2

    consort exclude if group == 0, label("Step 3")
    assert ${CONSORT_STEPS} == 3
}
if _rc == 0 {
    display as result "  PASS: Step counter increments correctly"
    local ++pass_count
}
else {
    display as error "  FAIL: Step counter invariant (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 2.3"
}
_clear_consort_state

* =============================================================================
* SECTION 3: RETURN VALUE VALIDATION
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 3: Return Value Validation"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 3.1: r(N) matches actual observation count
* Purpose: Verify r(N) from init is accurate
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.1: r(N) accuracy"
}

capture {
    _clear_consort_state
    use "${DATA_DIR}/valid_consort_100.dta", clear

    local actual_n = _N
    consort init, initial("All subjects")

    assert r(N) == `actual_n'
    assert r(N) == 100
}
if _rc == 0 {
    display as result "  PASS: r(N) matches actual count"
    local ++pass_count
}
else {
    display as error "  FAIL: r(N) accuracy (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.1"
}
_clear_consort_state

* -----------------------------------------------------------------------------
* Test 3.2: r(n_excluded) matches manual count
* Purpose: Verify r(n_excluded) is exact
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.2: r(n_excluded) accuracy"
}

capture {
    _clear_consort_state
    use "${DATA_DIR}/valid_consort_100.dta", clear

    * Count manually before exclusion
    count if has_missing == 1
    local manual_count = r(N)

    consort init, initial("All subjects")
    consort exclude if has_missing == 1, label("Missing")

    assert r(n_excluded) == `manual_count'
}
if _rc == 0 {
    display as result "  PASS: r(n_excluded) matches manual count"
    local ++pass_count
}
else {
    display as error "  FAIL: r(n_excluded) accuracy (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.2"
}
_clear_consort_state

* -----------------------------------------------------------------------------
* Test 3.3: r(n_remaining) matches actual post-exclusion N
* Purpose: Verify r(n_remaining) equals _N after exclusion
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.3: r(n_remaining) accuracy"
}

capture {
    _clear_consort_state
    use "${DATA_DIR}/valid_consort_100.dta", clear

    consort init, initial("All subjects")
    consort exclude if has_missing == 1, label("Missing")

    local returned_remaining = r(n_remaining)
    local actual_remaining = _N

    assert `returned_remaining' == `actual_remaining'
}
if _rc == 0 {
    display as result "  PASS: r(n_remaining) matches _N"
    local ++pass_count
}
else {
    display as error "  FAIL: r(n_remaining) accuracy (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.3"
}
_clear_consort_state

* -----------------------------------------------------------------------------
* Test 3.4: r(step) increments correctly
* Purpose: Verify step counter in return values
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.4: r(step) accuracy"
}

capture {
    _clear_consort_state
    use "${DATA_DIR}/valid_consort_100.dta", clear

    consort init, initial("All subjects")

    consort exclude if has_missing == 1, label("Step 1")
    assert r(step) == 1

    consort exclude if is_foreign == 1, label("Step 2")
    assert r(step) == 2

    consort exclude if group == 0, label("Step 3")
    assert r(step) == 3
}
if _rc == 0 {
    display as result "  PASS: r(step) increments correctly"
    local ++pass_count
}
else {
    display as error "  FAIL: r(step) accuracy (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.4"
}
_clear_consort_state

* =============================================================================
* SECTION 4: CSV FILE FORMAT VALIDATION
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 4: CSV File Format Validation"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 4.1: CSV header is correct
* Purpose: Verify CSV has label,n,remaining header
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.1: CSV header format"
}

capture {
    _clear_consort_state
    use "${DATA_DIR}/valid_consort_100.dta", clear

    consort init, initial("All subjects") file("${DATA_DIR}/test_format.csv")

    * Read first line of CSV
    tempname fh
    file open `fh' using "${DATA_DIR}/test_format.csv", read text
    file read `fh' line
    file close `fh'

    * Verify header
    assert "`line'" == "label,n,remaining"
}
if _rc == 0 {
    display as result "  PASS: CSV header is correct"
    local ++pass_count
}
else {
    display as error "  FAIL: CSV header format (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.1"
}
capture erase "${DATA_DIR}/test_format.csv"
_clear_consort_state

* -----------------------------------------------------------------------------
* Test 4.2: CSV initial row has correct count
* Purpose: Verify first data row contains initial N
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.2: CSV initial count"
}

capture {
    _clear_consort_state
    use "${DATA_DIR}/valid_consort_100.dta", clear

    consort init, initial("All subjects") file("${DATA_DIR}/test_count.csv")

    * Read CSV and verify second line contains initial count
    tempname fh
    file open `fh' using "${DATA_DIR}/test_count.csv", read text
    file read `fh' line  // header
    file read `fh' line  // first data row
    file close `fh'

    * Line should be: "All subjects",100,
    * Check that 100 is in the line
    * Use macval() to prevent macro expansion of special chars in CSV
    local has_100 = strpos(`"`macval(line)'"', "100")
    assert `has_100' > 0
}
if _rc == 0 {
    display as result "  PASS: CSV initial count is correct"
    local ++pass_count
}
else {
    display as error "  FAIL: CSV initial count (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.2"
}
capture erase "${DATA_DIR}/test_count.csv"
_clear_consort_state

* -----------------------------------------------------------------------------
* Test 4.3: CSV exclusion row has correct count
* Purpose: Verify exclusion rows contain excluded count
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 4.3: CSV exclusion count"
}

capture {
    _clear_consort_state
    use "${DATA_DIR}/valid_consort_100.dta", clear

    consort init, initial("All subjects") file("${DATA_DIR}/test_excl.csv")
    consort exclude if has_missing == 1, label("Missing data")

    * Read CSV and verify exclusion row
    tempname fh
    file open `fh' using "${DATA_DIR}/test_excl.csv", read text
    file read `fh' line  // header
    file read `fh' line  // initial row
    file read `fh' line  // exclusion row
    file close `fh'

    * Line should contain "Missing data" and "10"
    * Use macval() to prevent macro expansion of special chars in CSV
    local has_label = strpos(`"`macval(line)'"', "Missing data")
    local has_count = strpos(`"`macval(line)'"', "10")
    assert `has_label' > 0
    assert `has_count' > 0
}
if _rc == 0 {
    display as result "  PASS: CSV exclusion row is correct"
    local ++pass_count
}
else {
    display as error "  FAIL: CSV exclusion count (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.3"
}
capture erase "${DATA_DIR}/test_excl.csv"
_clear_consort_state

* =============================================================================
* SECTION 5: STATE MANAGEMENT VALIDATION
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 5: State Management Validation"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 5.1: Globals set correctly on init
* Purpose: Verify all state globals are initialized
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 5.1: Globals set on init"
}

capture {
    _clear_consort_state
    use "${DATA_DIR}/valid_consort_100.dta", clear

    consort init, initial("All subjects")

    assert "${CONSORT_ACTIVE}" == "1"
    assert "${CONSORT_N}" == "100"
    assert "${CONSORT_STEPS}" == "0"
    assert "${CONSORT_FILE}" != ""
}
if _rc == 0 {
    display as result "  PASS: All globals set correctly"
    local ++pass_count
}
else {
    display as error "  FAIL: Globals on init (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 5.1"
}
_clear_consort_state

* -----------------------------------------------------------------------------
* Test 5.2: Globals cleared on consort clear
* Purpose: Verify all state globals are cleared
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 5.2: Globals cleared on clear"
}

capture {
    _clear_consort_state
    use "${DATA_DIR}/valid_consort_100.dta", clear

    consort init, initial("All subjects")
    assert "${CONSORT_ACTIVE}" == "1"

    consort clear

    assert "${CONSORT_ACTIVE}" == ""
    assert "${CONSORT_N}" == ""
    assert "${CONSORT_STEPS}" == ""
    assert "${CONSORT_FILE}" == ""
}
if _rc == 0 {
    display as result "  PASS: All globals cleared"
    local ++pass_count
}
else {
    display as error "  FAIL: Globals on clear (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 5.2"
}
_clear_consort_state

* -----------------------------------------------------------------------------
* Test 5.3: CONSORT_N remains constant (initial value preserved)
* Purpose: Verify initial N is preserved through exclusions
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 5.3: CONSORT_N remains constant"
}

capture {
    _clear_consort_state
    use "${DATA_DIR}/valid_consort_100.dta", clear

    consort init, initial("All subjects")
    local initial_global = ${CONSORT_N}

    consort exclude if has_missing == 1, label("Missing")
    assert ${CONSORT_N} == `initial_global'

    consort exclude if is_foreign == 1, label("Foreign")
    assert ${CONSORT_N} == `initial_global'

    * CONSORT_N should still be 100 even though _N is now 60
    assert ${CONSORT_N} == 100
    assert _N == 60
}
if _rc == 0 {
    display as result "  PASS: CONSORT_N preserved as initial value"
    local ++pass_count
}
else {
    display as error "  FAIL: CONSORT_N preservation (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 5.3"
}
_clear_consort_state

* =============================================================================
* SECTION 6: BOUNDARY CONDITION TESTS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 6: Boundary Condition Tests"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 6.1: Zero exclusions (condition matches nothing)
* Purpose: Verify n_excluded = 0 when no matches
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 6.1: Zero exclusions"
}

capture {
    _clear_consort_state
    use "${DATA_DIR}/valid_consort_100.dta", clear

    consort init, initial("All subjects")
    local n_before = _N

    consort exclude if price > 999999, label("Impossible")

    assert r(n_excluded) == 0
    assert r(n_remaining) == `n_before'
    assert _N == `n_before'
}
if _rc == 0 {
    display as result "  PASS: Zero exclusions handled correctly"
    local ++pass_count
}
else {
    display as error "  FAIL: Zero exclusions (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 6.1"
}
_clear_consort_state

* -----------------------------------------------------------------------------
* Test 6.2: Exclusion of all but one
* Purpose: Verify can exclude down to single observation
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 6.2: Exclude to single observation"
}

capture {
    _clear_consort_state
    use "${DATA_DIR}/valid_consort_5.dta", clear

    consort init, initial("5 subjects")

    * Exclude all but id=5 (has_missing=0, is_foreign=0)
    consort exclude if has_missing == 1, label("Missing")  // removes 2
    consort exclude if is_foreign == 1, label("Foreign")   // removes 2

    assert _N == 1
    assert r(n_remaining) == 1
    assert id[1] == 5
}
if _rc == 0 {
    display as result "  PASS: Excluded to single observation"
    local ++pass_count
}
else {
    display as error "  FAIL: Exclude to single (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 6.2"
}
_clear_consort_state

* -----------------------------------------------------------------------------
* Test 6.3: Single observation initial dataset
* Purpose: Verify works with N=1
* -----------------------------------------------------------------------------
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 6.3: Single observation initial"
}

capture {
    _clear_consort_state
    clear
    set obs 1
    gen id = 1
    gen flag = 0

    consort init, initial("Single subject")

    assert r(N) == 1
    assert ${CONSORT_N} == 1
}
if _rc == 0 {
    display as result "  PASS: Single observation works"
    local ++pass_count
}
else {
    display as error "  FAIL: Single observation (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 6.3"
}
_clear_consort_state

* =============================================================================
* CLEANUP
* =============================================================================
* Remove validation datasets
capture erase "${DATA_DIR}/valid_consort_100.dta"
capture erase "${DATA_DIR}/valid_consort_5.dta"
capture erase "${DATA_DIR}/test_format.csv"
capture erase "${DATA_DIR}/test_count.csv"
capture erase "${DATA_DIR}/test_excl.csv"

* =============================================================================
* SUMMARY
* =============================================================================
display as text _n "{hline 70}"
display as text "CONSORT VALIDATION SUMMARY"
display as text "{hline 70}"
display as text "Total tests:  `test_count'"
display as result "Passed:       `pass_count'"
if `fail_count' > 0 {
    display as error "Failed:       `fail_count'"
}
else {
    display as text "Failed:       `fail_count'"
}
display as text "{hline 70}"

if `fail_count' > 0 {
    display as error _n "FAILED TESTS:`failed_tests'"
    display as text "{hline 70}"
    display as error "Some validation tests FAILED."
    exit 1
}
else {
    display as result _n "ALL VALIDATION TESTS PASSED!"
}

display as text _n "Validation completed: `c(current_date)' `c(current_time)'"
display as text "{hline 70}"
