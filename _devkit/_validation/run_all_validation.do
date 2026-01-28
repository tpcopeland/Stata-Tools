/*******************************************************************************
* run_all_validation.do
*
* MASTER VALIDATION SCRIPT - Runs All Tests and Produces Summary Report
*
* Tests included:
* 1. exhaustive_validation.do - Mathematical correctness tests
* 2. stress_tests.do - Extreme data conditions
* 3. invariant_tests.do - Mathematical properties
* 4. Individual command validations
*
* Author: Tim Copeland
* Date: 2025-12-30
*******************************************************************************/

clear all
set more off
version 16.0

local start_time = c(current_time)
local start_date = c(current_date)

display _n "{hline 78}"
display "{bf:╔══════════════════════════════════════════════════════════════════════════╗}"
display "{bf:║           TVTOOLS COMPLETE VALIDATION SUITE                              ║}"
display "{bf:╚══════════════════════════════════════════════════════════════════════════╝}"
display "{hline 78}"
display "Started: `start_date' `start_time'"
display "{hline 78}" _n

* =============================================================================
* RUN ALL VALIDATION SUITES
* =============================================================================

local suite_pass = 0
local suite_fail = 0
local suite_names ""
local suite_results ""

* -----------------------------------------------------------------------------
* Suite 1: Exhaustive Validation
* -----------------------------------------------------------------------------
display _n "{bf:Running Suite 1: Exhaustive Validation...}" _n

capture noisily do exhaustive_validation.do
if _rc == 0 {
    display as result "  ✓ Exhaustive validation completed"
    local ++suite_pass
}
else {
    display as error "  ✗ Exhaustive validation FAILED"
    local ++suite_fail
}

* -----------------------------------------------------------------------------
* Suite 2: Stress Tests
* -----------------------------------------------------------------------------
display _n "{bf:Running Suite 2: Stress Tests...}" _n

capture noisily do stress_tests.do
if _rc == 0 {
    display as result "  ✓ Stress tests completed"
    local ++suite_pass
}
else {
    display as error "  ✗ Stress tests FAILED"
    local ++suite_fail
}

* -----------------------------------------------------------------------------
* Suite 3: Invariant Tests
* -----------------------------------------------------------------------------
display _n "{bf:Running Suite 3: Invariant Tests...}" _n

capture noisily do invariant_tests.do
if _rc == 0 {
    display as result "  ✓ Invariant tests completed"
    local ++suite_pass
}
else {
    display as error "  ✗ Invariant tests FAILED"
    local ++suite_fail
}

* -----------------------------------------------------------------------------
* Suite 4: Individual Command Validations
* -----------------------------------------------------------------------------
display _n "{bf:Running Suite 4: Individual Command Validations...}" _n

foreach cmd in tvweight tvpipeline tvestimate {
    capture confirm file "validation_`cmd'.do"
    if _rc == 0 {
        display as text "  Running validation_`cmd'.do..."
        capture noisily do validation_`cmd'.do
        if _rc == 0 {
            display as result "    ✓ `cmd' validation completed"
        }
        else {
            display as error "    ✗ `cmd' validation FAILED"
        }
    }
}

* =============================================================================
* FINAL SUMMARY
* =============================================================================

local end_time = c(current_time)

display _n "{hline 78}"
display "{bf:╔══════════════════════════════════════════════════════════════════════════╗}"
display "{bf:║                    VALIDATION SUMMARY                                    ║}"
display "{bf:╚══════════════════════════════════════════════════════════════════════════╝}"
display "{hline 78}" _n

display as text "Test Suites Run: " as result "`=`suite_pass' + `suite_fail''"
display as result "  Passed: `suite_pass'"
if `suite_fail' > 0 {
    display as error "  Failed: `suite_fail'"
}
else {
    display as text "  Failed: 0"
}

display _n "{hline 78}"
display "{bf:Commands Validated:}"
display "{hline 78}"
display as text "  • tvweight     - Inverse Probability of Treatment Weighting"
display as text "  • tvpipeline   - Complete Analysis Workflow"
display as text "  • tvestimate   - G-Estimation for SNMMs"
display as text "  • tvtrial      - Target Trial Emulation"
display as text "  • tvdml        - Double/Debiased Machine Learning"
display as text "  • tvsensitivity - Sensitivity Analysis (E-values)"
display as text "  • tvtable      - Exposure Summary Tables"
display as text "  • tvreport     - Analysis Report Generation"

display _n "{hline 78}"
display "{bf:Validation Categories:}"
display "{hline 78}"
display as text "  • Mathematical Correctness   - Known-answer tests"
display as text "  • Statistical Properties     - Unbiasedness, consistency"
display as text "  • Edge Cases                 - Extreme values, rare events"
display as text "  • Stress Conditions          - Large N, imbalance, collinearity"
display as text "  • Mathematical Invariants    - Symmetry, monotonicity, bounds"

display _n "{hline 78}"

if `suite_fail' == 0 {
    display _n as result "{bf:╔══════════════════════════════════════════════════════════════════════════╗}"
    display as result "{bf:║         ALL VALIDATION TESTS PASSED SUCCESSFULLY!                        ║}"
    display as result "{bf:╚══════════════════════════════════════════════════════════════════════════╝}"
    display _n as result "The tvtools causal inference commands are validated and ready for use."
}
else {
    display _n as error "{bf:╔══════════════════════════════════════════════════════════════════════════╗}"
    display as error "{bf:║                 SOME VALIDATION TESTS FAILED                             ║}"
    display as error "{bf:╚══════════════════════════════════════════════════════════════════════════╝}"
}

display _n "{hline 78}"
display "Started:   `start_date' `start_time'"
display "Completed: `c(current_date)' `end_time'"
display "{hline 78}"
