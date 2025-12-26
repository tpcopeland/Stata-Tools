/*******************************************************************************
* test_consort.do
*
* Purpose: Functional tests for consort command - verifies the command runs
*          without errors across various scenarios and options.
*
* Prerequisites:
*   - consort.ado must be installed/accessible
*   - Python 3 with matplotlib (for save tests; some tests skip if unavailable)
*
* Run modes:
*   Standalone: do test_consort.do
*   Via runner: do run_test.do test_consort [testnumber] [quiet] [machine]
*
* Test philosophy:
*   - Does the command RUN without errors?
*   - Does it handle edge cases gracefully?
*   - Does NOT verify computational correctness (that's validation)
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
    * Try to detect path from current working directory
    capture confirm file "_testing"
    if _rc == 0 {
        global STATA_TOOLS_PATH "`c(pwd)'"
    }
    else {
        capture confirm file "data"
        if _rc == 0 {
            global STATA_TOOLS_PATH "`c(pwd)'/.."
        }
        else {
            global STATA_TOOLS_PATH "/home/`c(username)'/Stata-Tools"
        }
    }
}
else {
    * Windows or other - try to detect from current directory
    capture confirm file "_testing"
    if _rc == 0 {
        * Running from repo root
        global STATA_TOOLS_PATH "`c(pwd)'"
    }
    else {
        capture confirm file "data"
        if _rc == 0 {
            * Running from _testing directory
            global STATA_TOOLS_PATH "`c(pwd)'/.."
        }
        else {
            * Assume running from _testing/data directory
            global STATA_TOOLS_PATH "`c(pwd)'/../.."
        }
    }
}

global TESTING_DIR "${STATA_TOOLS_PATH}/_testing"
global DATA_DIR "${TESTING_DIR}/data"

* Create data directory if needed
capture mkdir "${DATA_DIR}"

* Install package from local repository
capture net uninstall consort
quietly net install consort, from("${STATA_TOOLS_PATH}/consort")

* =============================================================================
* CHECK PYTHON AVAILABILITY
* =============================================================================
local python_available = 0
capture shell python --version
if _rc == 0 {
    capture shell python -c "import matplotlib"
    if _rc == 0 {
        local python_available = 1
    }
}
if `python_available' == 0 {
    capture shell python3 --version
    if _rc == 0 {
        capture shell python3 -c "import matplotlib"
        if _rc == 0 {
            local python_available = 1
        }
    }
}

* =============================================================================
* HEADER (skip in quiet/machine mode)
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "CONSORT COMMAND FUNCTIONAL TESTING"
    display as text "{hline 70}"
    display as text "Data directory: ${DATA_DIR}"
    if `python_available' == 0 {
        display as text "Note: Python/matplotlib not found - save tests will be skipped"
    }
    display as text "{hline 70}"
}

* =============================================================================
* TEST COUNTERS AND FAILURE TRACKING
* =============================================================================
local test_count = 0
local pass_count = 0
local fail_count = 0
local skip_count = 0
local failed_tests ""

* =============================================================================
* HELPER: Clear consort state before each test
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
* SECTION 1: BASIC SUBCOMMAND TESTS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 1: Basic Subcommand Tests"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 1: consort init - basic execution
* -----------------------------------------------------------------------------
local ++test_count
local test_desc "consort init - basic execution"

if `run_only' == 0 | `run_only' == `test_count' {
    if `quiet' == 0 {
        display as text _n "Test `test_count': `test_desc'"
    }

    capture {
        _clear_consort_state
        sysuse auto, clear
        consort init, initial("All cars in dataset")
        assert "${CONSORT_ACTIVE}" == "1"
        assert "${CONSORT_N}" == "74"
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

* -----------------------------------------------------------------------------
* Test 2: consort init - with file option
* -----------------------------------------------------------------------------
local ++test_count
local test_desc "consort init - with file option"

if `run_only' == 0 | `run_only' == `test_count' {
    if `quiet' == 0 {
        display as text _n "Test `test_count': `test_desc'"
    }

    capture {
        _clear_consort_state
        sysuse auto, clear
        consort init, initial("All cars") file("${DATA_DIR}/test_exclusions.csv")
        assert "${CONSORT_FILE}" == "${DATA_DIR}/test_exclusions.csv"
        capture confirm file "${DATA_DIR}/test_exclusions.csv"
        assert _rc == 0
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
    * Cleanup
    capture erase "${DATA_DIR}/test_exclusions.csv"
    _clear_consort_state
}

* -----------------------------------------------------------------------------
* Test 3: consort exclude - basic execution
* -----------------------------------------------------------------------------
local ++test_count
local test_desc "consort exclude - basic execution"

if `run_only' == 0 | `run_only' == `test_count' {
    if `quiet' == 0 {
        display as text _n "Test `test_count': `test_desc'"
    }

    capture {
        _clear_consort_state
        sysuse auto, clear
        local orig_n = _N
        consort init, initial("All cars")
        consort exclude if rep78 == ., label("Missing repair record")
        assert _N < `orig_n'
        assert ${CONSORT_STEPS} == 1
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
    _clear_consort_state
}

* -----------------------------------------------------------------------------
* Test 4: consort exclude - with remaining option
* -----------------------------------------------------------------------------
local ++test_count
local test_desc "consort exclude - with remaining option"

if `run_only' == 0 | `run_only' == `test_count' {
    if `quiet' == 0 {
        display as text _n "Test `test_count': `test_desc'"
    }

    capture {
        _clear_consort_state
        sysuse auto, clear
        consort init, initial("All cars")
        consort exclude if rep78 == ., label("Missing repair") remaining("Cars with data")
        assert ${CONSORT_STEPS} == 1
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
    _clear_consort_state
}

* -----------------------------------------------------------------------------
* Test 5: consort clear - basic execution
* -----------------------------------------------------------------------------
local ++test_count
local test_desc "consort clear - basic execution"

if `run_only' == 0 | `run_only' == `test_count' {
    if `quiet' == 0 {
        display as text _n "Test `test_count': `test_desc'"
    }

    capture {
        _clear_consort_state
        sysuse auto, clear
        consort init, initial("All cars")
        assert "${CONSORT_ACTIVE}" == "1"
        consort clear
        assert "${CONSORT_ACTIVE}" == ""
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

* -----------------------------------------------------------------------------
* Test 6: consort clear - quiet option
* -----------------------------------------------------------------------------
local ++test_count
local test_desc "consort clear - quiet option"

if `run_only' == 0 | `run_only' == `test_count' {
    if `quiet' == 0 {
        display as text _n "Test `test_count': `test_desc'"
    }

    capture {
        _clear_consort_state
        sysuse auto, clear
        consort init, initial("All cars")
        consort clear, quiet
        assert "${CONSORT_ACTIVE}" == ""
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
* SECTION 2: COMPLETE WORKFLOW TESTS (require Python)
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 2: Complete Workflow Tests"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 7: Complete workflow - init, exclude, save
* -----------------------------------------------------------------------------
local ++test_count
local test_desc "Complete workflow - init, exclude, save"

if `run_only' == 0 | `run_only' == `test_count' {
    if `quiet' == 0 {
        display as text _n "Test `test_count': `test_desc'"
    }

    if `python_available' == 0 {
        local ++skip_count
        if `machine' {
            display "[SKIP] `test_count'|Python not available"
        }
        else if `quiet' == 0 {
            display as text "  SKIPPED (Python/matplotlib not available)"
        }
    }
    else {
        capture {
            _clear_consort_state
            sysuse auto, clear
            consort init, initial("All cars in dataset")
            consort exclude if rep78 == ., label("Missing repair record")
            consort exclude if foreign == 1, label("Foreign manufacture")
            consort save, output("${DATA_DIR}/test_consort.png") final("Domestic cars")
            * Verify output file created
            confirm file "${DATA_DIR}/test_consort.png"
            * Verify state cleared after save
            assert "${CONSORT_ACTIVE}" == ""
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
        * Cleanup
        capture erase "${DATA_DIR}/test_consort.png"
    }
    _clear_consort_state
}

* -----------------------------------------------------------------------------
* Test 8: Workflow with shading option
* -----------------------------------------------------------------------------
local ++test_count
local test_desc "Workflow with shading option"

if `run_only' == 0 | `run_only' == `test_count' {
    if `quiet' == 0 {
        display as text _n "Test `test_count': `test_desc'"
    }

    if `python_available' == 0 {
        local ++skip_count
        if `machine' {
            display "[SKIP] `test_count'|Python not available"
        }
        else if `quiet' == 0 {
            display as text "  SKIPPED (Python/matplotlib not available)"
        }
    }
    else {
        capture {
            _clear_consort_state
            sysuse auto, clear
            consort init, initial("All cars")
            consort exclude if price > 10000, label("Price > $10,000")
            consort save, output("${DATA_DIR}/test_shading.png") shading
            confirm file "${DATA_DIR}/test_shading.png"
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
        capture erase "${DATA_DIR}/test_shading.png"
    }
    _clear_consort_state
}

* -----------------------------------------------------------------------------
* Test 9: Workflow with dpi option
* -----------------------------------------------------------------------------
local ++test_count
local test_desc "Workflow with dpi option"

if `run_only' == 0 | `run_only' == `test_count' {
    if `quiet' == 0 {
        display as text _n "Test `test_count': `test_desc'"
    }

    if `python_available' == 0 {
        local ++skip_count
        if `machine' {
            display "[SKIP] `test_count'|Python not available"
        }
        else if `quiet' == 0 {
            display as text "  SKIPPED (Python/matplotlib not available)"
        }
    }
    else {
        capture {
            _clear_consort_state
            sysuse auto, clear
            consort init, initial("All cars")
            consort exclude if mpg < 20, label("Low MPG")
            consort save, output("${DATA_DIR}/test_dpi.png") dpi(300)
            confirm file "${DATA_DIR}/test_dpi.png"
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
        capture erase "${DATA_DIR}/test_dpi.png"
    }
    _clear_consort_state
}

* =============================================================================
* SECTION 3: RETURN VALUES TESTS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 3: Return Values Tests"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 10: consort init returns r(N)
* -----------------------------------------------------------------------------
local ++test_count
local test_desc "consort init returns r(N)"

if `run_only' == 0 | `run_only' == `test_count' {
    if `quiet' == 0 {
        display as text _n "Test `test_count': `test_desc'"
    }

    capture {
        _clear_consort_state
        sysuse auto, clear
        consort init, initial("All cars")
        assert r(N) == 74
        assert "`r(initial)'" == "All cars"
        assert "`r(file)'" != ""
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
    _clear_consort_state
}

* -----------------------------------------------------------------------------
* Test 11: consort exclude returns counts
* -----------------------------------------------------------------------------
local ++test_count
local test_desc "consort exclude returns counts"

if `run_only' == 0 | `run_only' == `test_count' {
    if `quiet' == 0 {
        display as text _n "Test `test_count': `test_desc'"
    }

    capture {
        _clear_consort_state
        sysuse auto, clear
        consort init, initial("All cars")
        consort exclude if rep78 == ., label("Missing")
        assert r(n_excluded) == 5
        assert r(n_remaining) == 69
        assert r(step) == 1
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
    _clear_consort_state
}

* =============================================================================
* SECTION 4: ERROR HANDLING TESTS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 4: Error Handling Tests"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 12: Error when no subcommand provided
* -----------------------------------------------------------------------------
local ++test_count
local test_desc "Error when no subcommand provided"

if `run_only' == 0 | `run_only' == `test_count' {
    if `quiet' == 0 {
        display as text _n "Test `test_count': `test_desc'"
    }

    capture {
        _clear_consort_state
        capture consort
        assert _rc == 198
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "[OK] `test_count'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED (correctly rejected)"
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

* -----------------------------------------------------------------------------
* Test 13: Error when invalid subcommand
* -----------------------------------------------------------------------------
local ++test_count
local test_desc "Error when invalid subcommand"

if `run_only' == 0 | `run_only' == `test_count' {
    if `quiet' == 0 {
        display as text _n "Test `test_count': `test_desc'"
    }

    capture {
        _clear_consort_state
        capture consort invalid
        assert _rc == 198
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "[OK] `test_count'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED (correctly rejected)"
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

* -----------------------------------------------------------------------------
* Test 14: Error when exclude without init
* -----------------------------------------------------------------------------
local ++test_count
local test_desc "Error when exclude without init"

if `run_only' == 0 | `run_only' == `test_count' {
    if `quiet' == 0 {
        display as text _n "Test `test_count': `test_desc'"
    }

    capture {
        _clear_consort_state
        sysuse auto, clear
        capture consort exclude if foreign == 1, label("Foreign")
        assert _rc == 198
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "[OK] `test_count'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED (correctly rejected)"
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

* -----------------------------------------------------------------------------
* Test 15: Error when save without init
* -----------------------------------------------------------------------------
local ++test_count
local test_desc "Error when save without init"

if `run_only' == 0 | `run_only' == `test_count' {
    if `quiet' == 0 {
        display as text _n "Test `test_count': `test_desc'"
    }

    capture {
        _clear_consort_state
        capture consort save, output("test.png")
        assert _rc == 198
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "[OK] `test_count'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED (correctly rejected)"
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

* -----------------------------------------------------------------------------
* Test 16: Error when save without exclusions
* -----------------------------------------------------------------------------
local ++test_count
local test_desc "Error when save without exclusions"

if `run_only' == 0 | `run_only' == `test_count' {
    if `quiet' == 0 {
        display as text _n "Test `test_count': `test_desc'"
    }

    capture {
        _clear_consort_state
        sysuse auto, clear
        consort init, initial("All cars")
        capture consort save, output("test.png")
        assert _rc == 198
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "[OK] `test_count'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED (correctly rejected)"
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
    _clear_consort_state
}

* -----------------------------------------------------------------------------
* Test 17: Error when init on empty dataset
* -----------------------------------------------------------------------------
local ++test_count
local test_desc "Error when init on empty dataset"

if `run_only' == 0 | `run_only' == `test_count' {
    if `quiet' == 0 {
        display as text _n "Test `test_count': `test_desc'"
    }

    capture {
        _clear_consort_state
        clear
        set obs 0
        gen x = .
        capture consort init, initial("Empty data")
        assert _rc == 2000
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "[OK] `test_count'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED (correctly rejected)"
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

* -----------------------------------------------------------------------------
* Test 18: Error when init called twice
* -----------------------------------------------------------------------------
local ++test_count
local test_desc "Error when init called twice"

if `run_only' == 0 | `run_only' == `test_count' {
    if `quiet' == 0 {
        display as text _n "Test `test_count': `test_desc'"
    }

    capture {
        _clear_consort_state
        sysuse auto, clear
        consort init, initial("First init")
        capture consort init, initial("Second init")
        assert _rc == 198
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "[OK] `test_count'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED (correctly rejected)"
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
    _clear_consort_state
}

* =============================================================================
* SECTION 5: EDGE CASE TESTS
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 5: Edge Case Tests"
    display as text "{hline 70}"
}

* -----------------------------------------------------------------------------
* Test 19: Exclusion with zero matches (graceful handling)
* -----------------------------------------------------------------------------
local ++test_count
local test_desc "Exclusion with zero matches"

if `run_only' == 0 | `run_only' == `test_count' {
    if `quiet' == 0 {
        display as text _n "Test `test_count': `test_desc'"
    }

    capture {
        _clear_consort_state
        sysuse auto, clear
        local orig_n = _N
        consort init, initial("All cars")
        consort exclude if price > 999999, label("Impossible condition")
        * Should not error, just skip
        assert _N == `orig_n'
        assert r(n_excluded) == 0
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
    _clear_consort_state
}

* -----------------------------------------------------------------------------
* Test 20: Multiple exclusions in sequence
* -----------------------------------------------------------------------------
local ++test_count
local test_desc "Multiple exclusions in sequence"

if `run_only' == 0 | `run_only' == `test_count' {
    if `quiet' == 0 {
        display as text _n "Test `test_count': `test_desc'"
    }

    capture {
        _clear_consort_state
        sysuse auto, clear
        consort init, initial("All cars")
        consort exclude if rep78 == ., label("Missing repair")
        assert ${CONSORT_STEPS} == 1
        consort exclude if foreign == 1, label("Foreign")
        assert ${CONSORT_STEPS} == 2
        consort exclude if price > 10000, label("Expensive")
        assert ${CONSORT_STEPS} == 3
        consort exclude if mpg < 20, label("Low MPG")
        assert ${CONSORT_STEPS} == 4
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
    _clear_consort_state
}

* -----------------------------------------------------------------------------
* Test 21: Single observation dataset
* -----------------------------------------------------------------------------
local ++test_count
local test_desc "Single observation dataset"

if `run_only' == 0 | `run_only' == `test_count' {
    if `quiet' == 0 {
        display as text _n "Test `test_count': `test_desc'"
    }

    capture {
        _clear_consort_state
        sysuse auto, clear
        keep if _n == 1
        consort init, initial("Single car")
        assert r(N) == 1
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
    _clear_consort_state
}

* -----------------------------------------------------------------------------
* Test 22: Labels with special characters
* -----------------------------------------------------------------------------
local ++test_count
local test_desc "Labels with special characters"

if `run_only' == 0 | `run_only' == `test_count' {
    if `quiet' == 0 {
        display as text _n "Test `test_count': `test_desc'"
    }

    capture {
        _clear_consort_state
        sysuse auto, clear
        consort init, initial("All cars (n=74)")
        consort exclude if rep78 == ., label("Missing repair - excluded")
        assert ${CONSORT_STEPS} == 1
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
    _clear_consort_state
}

* =============================================================================
* CLEANUP
* =============================================================================
if `quiet' == 0 & `run_only' == 0 {
    display as text _n "{hline 70}"
    display as text "Cleaning up..."
    display as text "{hline 70}"
}

* Final cleanup
_clear_consort_state
capture erase "${DATA_DIR}/test_exclusions.csv"
capture erase "${DATA_DIR}/test_consort.png"
capture erase "${DATA_DIR}/test_shading.png"
capture erase "${DATA_DIR}/test_dpi.png"

* =============================================================================
* SUMMARY
* =============================================================================
if `machine' {
    display "[SUMMARY] `pass_count'/`test_count' passed"
    if `skip_count' > 0 {
        display "[SKIPPED] `skip_count'"
    }
    if `fail_count' > 0 {
        display "[FAILED]`failed_tests'"
    }
}
else {
    display as text _n "{hline 70}"
    display as text "CONSORT FUNCTIONAL TEST SUMMARY"
    display as text "{hline 70}"
    display as text "Total tests:  `test_count'"
    display as result "Passed:       `pass_count'"
    if `skip_count' > 0 {
        display as text "Skipped:      `skip_count' (Python/matplotlib not available)"
    }
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

display as text _n "Testing completed: `c(current_date)' `c(current_time)'"
display as text "{hline 70}"

* Clear global flags
global RUN_TEST_QUIET
global RUN_TEST_MACHINE
global RUN_TEST_NUMBER
