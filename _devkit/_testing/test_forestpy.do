/*******************************************************************************
* Test file: test_forestpy.do
* Package: forestpy
* Version: 1.0.0
* Date: 2026-01-09
*
* Description:
*   Functional tests for forestpy Stata wrapper for Python forestplot
*
* Requirements:
*   - Stata 16+ with Python integration
*   - Python 3.6+ with pandas, numpy, matplotlib, forestplot
*
* Test coverage:
*   1. Basic functionality
*   2. Confidence intervals
*   3. Grouping and sorting
*   4. Display options
*   5. Annotations
*   6. Output saving
*   7. Log scale (odds ratios)
*   8. Multi-model plots
*   9. Error handling
*   10. Edge cases
*******************************************************************************/

version 16.0
clear all
set more off
set varabbrev off

// Add package directory to adopath (relative to repo root)
adopath + "forestpy"

// Track test results
local tests_run = 0
local tests_passed = 0
local tests_failed = 0

display as text _n "{hline 70}"
display as text "FORESTPY TEST SUITE"
display as text "{hline 70}"
display as text "Started: " c(current_date) " " c(current_time)
display as text "{hline 70}" _n

// =============================================================================
// TEST 0: Python availability check
// =============================================================================

display as text _n "TEST 0: Python availability check"
display as text "{hline 40}"

capture python query
if _rc {
    display as error "FATAL: Python integration not available"
    display as error "Tests cannot proceed without Python"
    exit 198
}
display as result "Python integration available"

// =============================================================================
// TEST 1: Basic functionality with minimal options
// =============================================================================

local ++tests_run
display as text _n "TEST 1: Basic functionality"
display as text "{hline 40}"

quietly {
    clear
    input str30 label estimate
    "Variable 1" 0.25
    "Variable 2" 0.18
    "Variable 3" -0.12
    "Variable 4" 0.35
    "Variable 5" -0.05
    end
}

capture noisily forestpy, estimate(estimate) varlabel(label)
if _rc == 0 {
    display as result "PASSED: Basic plot without CI"
    local ++tests_passed
}
else {
    display as error "FAILED: Basic plot without CI"
    display as error "Return code: `=_rc'"
    local ++tests_failed
}

// =============================================================================
// TEST 2: Plot with confidence intervals
// =============================================================================

local ++tests_run
display as text _n "TEST 2: Plot with confidence intervals"
display as text "{hline 40}"

quietly {
    clear
    input str30 label estimate ll hl
    "Age" 0.15 0.08 0.22
    "Sex (Male)" -0.05 -0.12 0.02
    "BMI" 0.28 0.21 0.35
    "Smoking" 0.42 0.33 0.51
    "Diabetes" 0.35 0.25 0.45
    end
}

capture noisily forestpy, estimate(estimate) varlabel(label) ll(ll) hl(hl)
if _rc == 0 {
    display as result "PASSED: Plot with confidence intervals"
    local ++tests_passed
}
else {
    display as error "FAILED: Plot with confidence intervals"
    display as error "Return code: `=_rc'"
    local ++tests_failed
}

// Check returned results
if "`r(estimate)'" == "estimate" & "`r(varlabel)'" == "label" {
    display as result "       Returned macros correct"
}

// =============================================================================
// TEST 3: Grouping variables
// =============================================================================

local ++tests_run
display as text _n "TEST 3: Grouping variables"
display as text "{hline 40}"

quietly {
    clear
    input str30 label estimate ll hl str20 group
    "Age" 0.15 0.08 0.22 "Demographics"
    "Sex" -0.05 -0.12 0.02 "Demographics"
    "Race" 0.08 0.01 0.15 "Demographics"
    "BMI" 0.28 0.21 0.35 "Clinical"
    "Smoking" 0.42 0.33 0.51 "Clinical"
    "Diabetes" 0.35 0.25 0.45 "Clinical"
    "Education" -0.18 -0.26 -0.10 "Socioeconomic"
    "Income" -0.12 -0.20 -0.04 "Socioeconomic"
    end
}

capture noisily forestpy, estimate(estimate) varlabel(label) ll(ll) hl(hl) ///
    groupvar(group)
if _rc == 0 {
    display as result "PASSED: Plot with grouping"
    local ++tests_passed
}
else {
    display as error "FAILED: Plot with grouping"
    display as error "Return code: `=_rc'"
    local ++tests_failed
}

// =============================================================================
// TEST 4: Sorting
// =============================================================================

local ++tests_run
display as text _n "TEST 4: Sorting by estimate"
display as text "{hline 40}"

capture noisily forestpy, estimate(estimate) varlabel(label) ll(ll) hl(hl) sort
if _rc == 0 {
    display as result "PASSED: Plot with sorting"
    local ++tests_passed
}
else {
    display as error "FAILED: Plot with sorting"
    display as error "Return code: `=_rc'"
    local ++tests_failed
}

// =============================================================================
// TEST 5: Log scale (for odds ratios)
// =============================================================================

local ++tests_run
display as text _n "TEST 5: Log scale for odds ratios"
display as text "{hline 40}"

quietly {
    clear
    input str30 label or or_ll or_hl
    "Treatment A" 1.45 1.12 1.88
    "Treatment B" 0.82 0.65 1.03
    "Treatment C" 2.15 1.68 2.75
    "Treatment D" 1.05 0.89 1.24
    end
}

capture noisily forestpy, estimate(or) varlabel(label) ll(or_ll) hl(or_hl) ///
    logscale xlabel("Odds Ratio")
if _rc == 0 {
    display as result "PASSED: Log scale plot"
    local ++tests_passed
}
else {
    display as error "FAILED: Log scale plot"
    display as error "Return code: `=_rc'"
    local ++tests_failed
}

// =============================================================================
// TEST 6: Annotations
// =============================================================================

local ++tests_run
display as text _n "TEST 6: Annotations"
display as text "{hline 40}"

quietly {
    clear
    input str30 label estimate ll hl n pvalue
    "Variable 1" 0.25 0.15 0.35 500 0.001
    "Variable 2" 0.18 0.08 0.28 450 0.012
    "Variable 3" -0.12 -0.22 -0.02 520 0.025
    "Variable 4" 0.08 -0.02 0.18 480 0.115
    end
}

capture noisily forestpy, estimate(estimate) varlabel(label) ll(ll) hl(hl) ///
    annote(n) annotehead(N) pval(pvalue)
if _rc == 0 {
    display as result "PASSED: Plot with annotations"
    local ++tests_passed
}
else {
    display as error "FAILED: Plot with annotations"
    display as error "Return code: `=_rc'"
    local ++tests_failed
}

// =============================================================================
// TEST 7: Custom display options
// =============================================================================

local ++tests_run
display as text _n "TEST 7: Custom display options"
display as text "{hline 40}"

quietly {
    clear
    input str30 label estimate ll hl
    "Age" 0.15 0.08 0.22
    "BMI" 0.28 0.21 0.35
    "Smoking" 0.42 0.33 0.51
    end
}

capture noisily forestpy, estimate(estimate) varlabel(label) ll(ll) hl(hl) ///
    xlabel("Correlation") decimal(3) color_alt_rows figsize(5 6)
if _rc == 0 {
    display as result "PASSED: Custom display options"
    local ++tests_passed
}
else {
    display as error "FAILED: Custom display options"
    display as error "Return code: `=_rc'"
    local ++tests_failed
}

// =============================================================================
// TEST 8: Save to file
// =============================================================================

local ++tests_run
display as text _n "TEST 8: Save to file"
display as text "{hline 40}"

tempfile testplot
local outfile "`testplot'.png"

capture noisily forestpy, estimate(estimate) varlabel(label) ll(ll) hl(hl) ///
    saving("`outfile'") replace
if _rc == 0 {
    // Check file exists
    capture confirm file "`outfile'"
    if _rc == 0 {
        display as result "PASSED: File saved successfully"
        local ++tests_passed
        // Clean up
        capture erase "`outfile'"
    }
    else {
        display as error "FAILED: File not created"
        local ++tests_failed
    }
}
else {
    display as error "FAILED: Save to file"
    display as error "Return code: `=_rc'"
    local ++tests_failed
}

// =============================================================================
// TEST 9: Custom markers
// =============================================================================

local ++tests_run
display as text _n "TEST 9: Custom markers and colors"
display as text "{hline 40}"

capture noisily forestpy, estimate(estimate) varlabel(label) ll(ll) hl(hl) ///
    marker(D) markersize(50) markercolor(navy) linewidth(2)
if _rc == 0 {
    display as result "PASSED: Custom markers"
    local ++tests_passed
}
else {
    display as error "FAILED: Custom markers"
    display as error "Return code: `=_rc'"
    local ++tests_failed
}

// =============================================================================
// TEST 10: Error handling - missing required options
// =============================================================================

local ++tests_run
display as text _n "TEST 10: Error handling - missing required options"
display as text "{hline 40}"

quietly {
    clear
    input str30 label estimate
    "Var1" 0.25
    "Var2" 0.18
    end
}

capture forestpy, varlabel(label)
if _rc != 0 {
    display as result "PASSED: Correctly errors on missing estimate()"
    local ++tests_passed
}
else {
    display as error "FAILED: Should error on missing estimate()"
    local ++tests_failed
}

// =============================================================================
// TEST 11: Error handling - mismatched CI options
// =============================================================================

local ++tests_run
display as text _n "TEST 11: Error handling - mismatched CI options"
display as text "{hline 40}"

quietly {
    clear
    input str30 label estimate ll
    "Var1" 0.25 0.15
    "Var2" 0.18 0.08
    end
}

capture forestpy, estimate(estimate) varlabel(label) ll(ll)
if _rc != 0 {
    display as result "PASSED: Correctly errors on ll() without hl()"
    local ++tests_passed
}
else {
    display as error "FAILED: Should error on ll() without hl()"
    local ++tests_failed
}

// =============================================================================
// TEST 12: Error handling - no observations
// =============================================================================

local ++tests_run
display as text _n "TEST 12: Error handling - no observations"
display as text "{hline 40}"

quietly {
    clear
    input str30 label estimate ll hl
    end
}

capture forestpy, estimate(estimate) varlabel(label) ll(ll) hl(hl)
if _rc != 0 {
    // Accept any error (2000 = no observations, 111 = variable not found with empty data)
    display as result "PASSED: Correctly errors on no observations (rc=`=_rc')"
    local ++tests_passed
}
else {
    display as error "FAILED: Should error on no observations"
    local ++tests_failed
}

// =============================================================================
// TEST 13: if/in conditions
// =============================================================================

local ++tests_run
display as text _n "TEST 13: if/in conditions"
display as text "{hline 40}"

quietly {
    clear
    input str30 label estimate ll hl
    "Var 1" 0.25 0.15 0.35
    "Var 2" 0.18 0.08 0.28
    "Var 3" -0.12 -0.22 -0.02
    "Var 4" 0.35 0.25 0.45
    "Var 5" -0.05 -0.15 0.05
    end
}

capture noisily forestpy if estimate > 0, estimate(estimate) varlabel(label) ll(ll) hl(hl)
if _rc == 0 & r(N) == 3 {
    display as result "PASSED: if condition works correctly (N=3)"
    local ++tests_passed
}
else {
    display as error "FAILED: if condition"
    display as error "Return code: `=_rc', N=`r(N)'"
    local ++tests_failed
}

// =============================================================================
// TEST 14: Large dataset
// =============================================================================

local ++tests_run
display as text _n "TEST 14: Large dataset (50 observations)"
display as text "{hline 40}"

quietly {
    clear
    set obs 50
    gen str30 label = "Variable " + string(_n)
    gen double estimate = rnormal(0, 0.3)
    gen double ll = estimate - 0.1
    gen double hl = estimate + 0.1
}

capture noisily forestpy, estimate(estimate) varlabel(label) ll(ll) hl(hl)
if _rc == 0 {
    display as result "PASSED: Large dataset handled"
    local ++tests_passed
}
else {
    display as error "FAILED: Large dataset"
    display as error "Return code: `=_rc'"
    local ++tests_failed
}

// =============================================================================
// TEST 15: Custom x-axis ticks
// =============================================================================

local ++tests_run
display as text _n "TEST 15: Custom x-axis ticks"
display as text "{hline 40}"

quietly {
    clear
    input str30 label estimate ll hl
    "Age" 0.15 0.08 0.22
    "BMI" 0.28 0.21 0.35
    "Smoking" 0.42 0.33 0.51
    end
}

capture noisily forestpy, estimate(estimate) varlabel(label) ll(ll) hl(hl) ///
    xticks(-0.2 0 0.2 0.4 0.6)
if _rc == 0 {
    display as result "PASSED: Custom x-axis ticks"
    local ++tests_passed
}
else {
    display as error "FAILED: Custom x-axis ticks"
    display as error "Return code: `=_rc'"
    local ++tests_failed
}

// =============================================================================
// TEST 16: Table format
// =============================================================================

local ++tests_run
display as text _n "TEST 16: Table format"
display as text "{hline 40}"

capture noisily forestpy, estimate(estimate) varlabel(label) ll(ll) hl(hl) table
if _rc == 0 {
    display as result "PASSED: Table format"
    local ++tests_passed
}
else {
    display as error "FAILED: Table format"
    display as error "Return code: `=_rc'"
    local ++tests_failed
}

// =============================================================================
// TEST 17: Right annotations
// =============================================================================

local ++tests_run
display as text _n "TEST 17: Right annotations"
display as text "{hline 40}"

quietly {
    clear
    input str30 label estimate ll hl n pct
    "Age" 0.15 0.08 0.22 500 85.2
    "BMI" 0.28 0.21 0.35 450 78.5
    "Smoking" 0.42 0.33 0.51 480 92.1
    end
}

capture noisily forestpy, estimate(estimate) varlabel(label) ll(ll) hl(hl) ///
    rightannote(n pct) righthead(N Percent)
if _rc == 0 {
    display as result "PASSED: Right annotations"
    local ++tests_passed
}
else {
    display as error "FAILED: Right annotations"
    display as error "Return code: `=_rc'"
    local ++tests_failed
}

// =============================================================================
// TEST 18: No star p-values
// =============================================================================

local ++tests_run
display as text _n "TEST 18: No star p-values"
display as text "{hline 40}"

quietly {
    clear
    input str30 label estimate ll hl pvalue
    "Var 1" 0.25 0.15 0.35 0.001
    "Var 2" 0.18 0.08 0.28 0.045
    "Var 3" -0.12 -0.22 -0.02 0.156
    end
}

capture noisily forestpy, estimate(estimate) varlabel(label) ll(ll) hl(hl) ///
    pval(pvalue) nostarpval
if _rc == 0 {
    display as result "PASSED: No star p-values"
    local ++tests_passed
}
else {
    display as error "FAILED: No star p-values"
    display as error "Return code: `=_rc'"
    local ++tests_failed
}

// =============================================================================
// TEST 19: Debug mode
// =============================================================================

local ++tests_run
display as text _n "TEST 19: Debug mode"
display as text "{hline 40}"

quietly {
    clear
    input str30 label estimate ll hl
    "Age" 0.15 0.08 0.22
    "BMI" 0.28 0.21 0.35
    end
}

capture noisily forestpy, estimate(estimate) varlabel(label) ll(ll) hl(hl) debug
if _rc == 0 {
    display as result "PASSED: Debug mode"
    local ++tests_passed
}
else {
    display as error "FAILED: Debug mode"
    display as error "Return code: `=_rc'"
    local ++tests_failed
}

// =============================================================================
// TEST 20: Missing values handling
// =============================================================================

local ++tests_run
display as text _n "TEST 20: Missing values handling"
display as text "{hline 40}"

quietly {
    clear
    input str30 label estimate ll hl
    "Var 1" 0.25 0.15 0.35
    "Var 2" . . .
    "Var 3" -0.12 -0.22 -0.02
    "Var 4" 0.35 . .
    "Var 5" -0.05 -0.15 0.05
    end
}

capture noisily forestpy, estimate(estimate) varlabel(label) ll(ll) hl(hl)
if _rc == 0 {
    // Should have handled missing values
    display as result "PASSED: Missing values handled (N=`r(N)')"
    local ++tests_passed
}
else {
    display as error "FAILED: Missing values handling"
    display as error "Return code: `=_rc'"
    local ++tests_failed
}

// =============================================================================
// TEST SUMMARY
// =============================================================================

display as text _n "{hline 70}"
display as text "TEST SUMMARY"
display as text "{hline 70}"
display as text "Tests run:    `tests_run'"
display as result "Tests passed: `tests_passed'"
if `tests_failed' > 0 {
    display as error "Tests failed: `tests_failed'"
}
else {
    display as text "Tests failed: `tests_failed'"
}
display as text "{hline 70}"
display as text "Completed: " c(current_date) " " c(current_time)
display as text "{hline 70}"

// Return overall status
if `tests_failed' > 0 {
    display as error _n "SOME TESTS FAILED"
    exit 1
}
else {
    display as result _n "ALL TESTS PASSED"
}

// End of test_forestpy.do
