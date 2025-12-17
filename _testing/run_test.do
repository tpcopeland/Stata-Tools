/*******************************************************************************
* run_test.do
*
* Purpose: Optimized test runner for Claude Code context token management
*          Supports quiet mode, single test execution, and machine output
*
* Usage:
*   do run_test.do testfile [testnumber] [quiet] [machine]
*
* Examples:
*   do run_test.do test_tvexpose          // Run all tests, verbose
*   do run_test.do test_tvexpose 7        // Run only test 7
*   do run_test.do test_tvexpose . quiet  // Run all tests, quiet mode
*   do run_test.do test_tvexpose 7 quiet  // Run test 7, quiet mode
*   do run_test.do test_tvexpose . machine // Machine-parseable output
*
* Arguments:
*   1. testfile   - Test file name without .do (e.g., test_tvexpose)
*   2. testnumber - Specific test number to run, or . for all (default: all)
*   3. quiet      - "quiet" for minimal output (default: verbose)
*   4. machine    - "machine" for parseable output format
*
* Output Modes:
*   verbose (default): Full test output with separators and details
*   quiet:             Only failures + summary (reduces tokens ~80%)
*   machine:           Parseable format [OK] n or [FAIL] n|code|message
*
* Author: Timothy P Copeland
* Date: 2025-12-12
*******************************************************************************/

clear all
set more off
version 16.0

* =============================================================================
* PARSE ARGUMENTS
* =============================================================================

* Get arguments from command line
local testfile "`1'"
local testnumber "`2'"
local arg3 "`3'"
local arg4 "`4'"

* Validate testfile argument
if "`testfile'" == "" {
    display as error "Usage: do run_test.do testfile [testnumber] [quiet] [machine]"
    display as error ""
    display as error "Examples:"
    display as error "  do run_test.do test_tvexpose          // All tests, verbose"
    display as error "  do run_test.do test_tvexpose 7        // Only test 7"
    display as error "  do run_test.do test_tvexpose . quiet  // All tests, quiet"
    display as error "  do run_test.do test_tvexpose 7 quiet  // Test 7, quiet"
    exit 198
}

* Set defaults
local run_test_number = 0  // 0 = run all
local quiet = 0
local machine = 0

* Parse testnumber (can be number or .)
if "`testnumber'" != "" & "`testnumber'" != "." {
    capture confirm integer number `testnumber'
    if _rc == 0 {
        local run_test_number = `testnumber'
    }
}

* Parse quiet/machine flags (can be in arg3 or arg4)
foreach arg in "`arg3'" "`arg4'" "`testnumber'" {
    if "`arg'" == "quiet" {
        local quiet = 1
    }
    if "`arg'" == "machine" {
        local machine = 1
        local quiet = 1  // machine implies quiet
    }
}

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

* Store run configuration as globals for test file
global RUN_TEST_QUIET = `quiet'
global RUN_TEST_MACHINE = `machine'
global RUN_TEST_NUMBER = `run_test_number'

* =============================================================================
* DISPLAY CONFIGURATION
* =============================================================================
if `machine' == 0 & `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "TEST RUNNER: `testfile'"
    display as text "{hline 70}"
    if `run_test_number' > 0 {
        display as text "Running: Test `run_test_number' only"
    }
    else {
        display as text "Running: All tests"
    }
    display as text "Mode: " _c
    if `quiet' {
        display as text "quiet"
    }
    else {
        display as text "verbose"
    }
    display as text "{hline 70}"
}

* =============================================================================
* EXECUTE TEST FILE
* =============================================================================

* Check test file exists
capture confirm file "${TESTING_DIR}/`testfile'.do"
if _rc {
    if `machine' {
        display "[ERROR] File not found: `testfile'.do"
    }
    else {
        display as error "Test file not found: ${TESTING_DIR}/`testfile'.do"
    }
    exit 601
}

* Run the test file
capture noisily do "${TESTING_DIR}/`testfile'.do"
local test_rc = _rc

* =============================================================================
* FINAL STATUS
* =============================================================================
if `machine' {
    if `test_rc' == 0 {
        display "[DONE] `testfile' PASSED"
    }
    else {
        display "[DONE] `testfile' FAILED|`test_rc'"
    }
}
else if `quiet' {
    if `test_rc' != 0 {
        display as error "Test file exited with error: `test_rc'"
    }
}

exit `test_rc'
