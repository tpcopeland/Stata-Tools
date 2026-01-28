/*******************************************************************************
* validation_helpers.do
*
* Purpose: Helper programs for validation testing
* Include at the start of validation test files:
*   do "_devkit/_validation/validation_helpers.do"
*
* Provides:
*   _assert_scalar     - Compare scalar values with tolerance
*   _assert_rows       - Validate row-by-row values
*   _test_start        - Initialize test counters
*   _test_result       - Record test pass/fail
*   _test_summary      - Display test summary
*******************************************************************************/

capture program drop _assert_scalar
capture program drop _assert_rows
capture program drop _test_start
capture program drop _test_result
capture program drop _test_summary

* ============================================================================
* _assert_scalar: Compare scalar value with tolerance
* ============================================================================
* Usage: _assert_scalar actual expected [tolerance]
* Example: _assert_scalar `=r(mean)' 3.14159 0.001

program define _assert_scalar
    args actual expected tolerance

    if "`tolerance'" == "" local tolerance = 0.0001

    local diff = abs(`actual' - `expected')

    if `diff' > `tolerance' {
        display as error "ASSERTION FAILED:"
        display as error "  Expected: `expected'"
        display as error "  Actual:   `actual'"
        display as error "  Diff:     `diff' (tolerance: `tolerance')"
        exit 9
    }
end

* ============================================================================
* _assert_rows: Validate values row by row
* ============================================================================
* Usage: _assert_rows varname, expected(numlist) [tolerance(real)]
* Example: _assert_rows result, expected(100 200 300)

program define _assert_rows
    syntax varname, expected(string) [tolerance(real 0.0001)]

    local values `expected'
    local row = 1

    foreach val of local values {
        local actual = `varlist'[`row']

        * Handle missing values
        if "`val'" == "." {
            if !missing(`actual') {
                display as error "Row `row': expected missing, got `actual'"
                exit 9
            }
        }
        else {
            if missing(`actual') {
                display as error "Row `row': expected `val', got missing"
                exit 9
            }
            if abs(`actual' - `val') > `tolerance' {
                display as error "Row `row': expected `val', got `actual'"
                exit 9
            }
        }

        local ++row
    }

    display as result "  Validated `=`row'-1' rows successfully"
end

* ============================================================================
* _test_start: Initialize test counters
* ============================================================================
* Usage: _test_start
* Creates globals: TEST_COUNT, PASS_COUNT, FAIL_COUNT

program define _test_start
    global TEST_COUNT = 0
    global PASS_COUNT = 0
    global FAIL_COUNT = 0

    display ""
    display as text _dup(70) "="
    display as text "VALIDATION TESTS"
    display as text "Date: $S_DATE $S_TIME"
    display as text _dup(70) "="
end

* ============================================================================
* _test_result: Record test result
* ============================================================================
* Usage: _test_result rc "Test name"
* Example:
*   capture noisily { mycommand; assert r(N) > 0 }
*   _test_result _rc "Basic functionality"

program define _test_result
    args rc testname

    global TEST_COUNT = $TEST_COUNT + 1

    if `rc' == 0 {
        display as result "  PASS: `testname'"
        global PASS_COUNT = $PASS_COUNT + 1
    }
    else {
        display as error "  FAIL: `testname' (r(`rc'))"
        global FAIL_COUNT = $FAIL_COUNT + 1
    }
end

* ============================================================================
* _test_summary: Display test summary and exit appropriately
* ============================================================================
* Usage: _test_summary

program define _test_summary
    display ""
    display as text _dup(70) "="
    display as text "VALIDATION SUMMARY"
    display as text _dup(70) "="
    display as text "Tests run:    " as result $TEST_COUNT
    display as text "Passed:       " as result $PASS_COUNT
    display as text "Failed:       " as result $FAIL_COUNT
    display as text _dup(70) "="

    if $FAIL_COUNT > 0 {
        display as error "VALIDATION FAILED"
        exit 1
    }
    else {
        display as result "ALL VALIDATIONS PASSED"
    }
end

* ============================================================================
* Display confirmation
* ============================================================================
display as text "Validation helpers loaded successfully"
display as text "  _assert_scalar actual expected [tolerance]"
display as text "  _assert_rows varname, expected(numlist) [tolerance()]"
display as text "  _test_start"
display as text "  _test_result rc testname"
display as text "  _test_summary"
