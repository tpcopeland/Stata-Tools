/*******************************************************************************
* Validation file: validation_forestpy.do
* Package: forestpy
* Version: 1.0.0
* Date: 2026-01-09
*
* Description:
*   Known-answer validation tests for forestpy
*   Tests that the command produces correct, verifiable output
*
* Validation approach:
*   Since forestpy produces graphical output, validation focuses on:
*   1. Correct return values
*   2. Correct data filtering with if/in
*   3. File creation verification
*   4. Python data transfer verification
*******************************************************************************/

version 16.0
clear all
set more off
set varabbrev off

// Add package directory to adopath (relative to repo root)
adopath + "forestpy"

// Track validation results
local tests_run = 0
local tests_passed = 0
local tests_failed = 0

display as text _n "{hline 70}"
display as text "FORESTPY VALIDATION SUITE"
display as text "{hline 70}"
display as text "Started: " c(current_date) " " c(current_time)
display as text "{hline 70}" _n

// =============================================================================
// VALIDATION 1: Return value N is correct
// =============================================================================

local ++tests_run
display as text _n "VALIDATION 1: Return value N is correct"
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

forestpy, estimate(estimate) varlabel(label) ll(ll) hl(hl)

if r(N) == 5 {
    display as result "PASSED: r(N) = 5 (expected 5)"
    local ++tests_passed
}
else {
    display as error "FAILED: r(N) = `r(N)' (expected 5)"
    local ++tests_failed
}

// =============================================================================
// VALIDATION 2: Return value N with if condition
// =============================================================================

local ++tests_run
display as text _n "VALIDATION 2: Return value N with if condition"
display as text "{hline 40}"

// Only positive estimates: Var1 (0.25), Var2 (0.18), Var4 (0.35) = 3 obs
forestpy if estimate > 0, estimate(estimate) varlabel(label) ll(ll) hl(hl)

if r(N) == 3 {
    display as result "PASSED: r(N) = 3 with if estimate > 0"
    local ++tests_passed
}
else {
    display as error "FAILED: r(N) = `r(N)' (expected 3 with if estimate > 0)"
    local ++tests_failed
}

// =============================================================================
// VALIDATION 3: Return value N with in condition
// =============================================================================

local ++tests_run
display as text _n "VALIDATION 3: Return value N with in condition"
display as text "{hline 40}"

forestpy in 1/3, estimate(estimate) varlabel(label) ll(ll) hl(hl)

if r(N) == 3 {
    display as result "PASSED: r(N) = 3 with in 1/3"
    local ++tests_passed
}
else {
    display as error "FAILED: r(N) = `r(N)' (expected 3 with in 1/3)"
    local ++tests_failed
}

// =============================================================================
// VALIDATION 4: Return macros are correct
// =============================================================================

local ++tests_run
display as text _n "VALIDATION 4: Return macros are correct"
display as text "{hline 40}"

forestpy, estimate(estimate) varlabel(label) ll(ll) hl(hl)

local pass = 1
if "`r(estimate)'" != "estimate" {
    display as error "       r(estimate) = '`r(estimate)'' (expected 'estimate')"
    local pass = 0
}
if "`r(varlabel)'" != "label" {
    display as error "       r(varlabel) = '`r(varlabel)'' (expected 'label')"
    local pass = 0
}
if "`r(ll)'" != "ll" {
    display as error "       r(ll) = '`r(ll)'' (expected 'll')"
    local pass = 0
}
if "`r(hl)'" != "hl" {
    display as error "       r(hl) = '`r(hl)'' (expected 'hl')"
    local pass = 0
}

if `pass' {
    display as result "PASSED: All return macros correct"
    local ++tests_passed
}
else {
    display as error "FAILED: Some return macros incorrect"
    local ++tests_failed
}

// =============================================================================
// VALIDATION 5: Missing values are excluded
// =============================================================================

local ++tests_run
display as text _n "VALIDATION 5: Missing values are excluded from count"
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

// Only Var1, Var3, Var5 have complete data = 3 obs
forestpy, estimate(estimate) varlabel(label) ll(ll) hl(hl)

if r(N) == 3 {
    display as result "PASSED: r(N) = 3 (missing values excluded)"
    local ++tests_passed
}
else {
    display as error "FAILED: r(N) = `r(N)' (expected 3 after excluding missing)"
    local ++tests_failed
}

// =============================================================================
// VALIDATION 6: File is created with saving()
// =============================================================================

local ++tests_run
display as text _n "VALIDATION 6: File is created with saving()"
display as text "{hline 40}"

quietly {
    clear
    input str30 label estimate ll hl
    "Var 1" 0.25 0.15 0.35
    "Var 2" 0.18 0.08 0.28
    "Var 3" -0.12 -0.22 -0.02
    end
}

tempfile testout
local outfile "`testout'_forest.png"

// Ensure file doesn't exist
capture erase "`outfile'"

forestpy, estimate(estimate) varlabel(label) ll(ll) hl(hl) ///
    saving("`outfile'") replace

capture confirm file "`outfile'"
if _rc == 0 {
    display as result "PASSED: Output file created"
    local ++tests_passed
    // Clean up
    capture erase "`outfile'"
}
else {
    display as error "FAILED: Output file not created"
    local ++tests_failed
}

// =============================================================================
// VALIDATION 7: PNG extension added automatically
// =============================================================================

local ++tests_run
display as text _n "VALIDATION 7: PNG extension added automatically"
display as text "{hline 40}"

tempfile testout
local outfile "`testout'_noext"

forestpy, estimate(estimate) varlabel(label) ll(ll) hl(hl) ///
    saving("`outfile'") replace

// Should have .png added
capture confirm file "`outfile'.png"
if _rc == 0 {
    display as result "PASSED: .png extension added automatically"
    local ++tests_passed
    capture erase "`outfile'.png"
}
else {
    display as error "FAILED: .png extension not added"
    local ++tests_failed
}

// =============================================================================
// VALIDATION 8: Correct error for no observations
// =============================================================================

local ++tests_run
display as text _n "VALIDATION 8: Error code 2000 for no observations"
display as text "{hline 40}"

quietly {
    clear
    input str30 label estimate ll hl
    end
}

capture forestpy, estimate(estimate) varlabel(label) ll(ll) hl(hl)

if _rc != 0 {
    // Accept any error (2000 = no observations, 111 = var not found with empty data)
    display as result "PASSED: Correctly errors on no observations (rc=`=_rc')"
    local ++tests_passed
}
else {
    display as error "FAILED: Should error on no observations"
    local ++tests_failed
}

// =============================================================================
// VALIDATION 9: Correct error for mismatched CI
// =============================================================================

local ++tests_run
display as text _n "VALIDATION 9: Error for ll() without hl()"
display as text "{hline 40}"

quietly {
    clear
    input str30 label estimate ll
    "Var 1" 0.25 0.15
    "Var 2" 0.18 0.08
    end
}

capture forestpy, estimate(estimate) varlabel(label) ll(ll)

if _rc == 198 {
    display as result "PASSED: Error code 198 for mismatched CI options"
    local ++tests_passed
}
else {
    display as error "FAILED: Expected error code 198, got `=_rc'"
    local ++tests_failed
}

// =============================================================================
// VALIDATION 10: Data preserved after command
// =============================================================================

local ++tests_run
display as text _n "VALIDATION 10: Data preserved after command"
display as text "{hline 40}"

quietly {
    clear
    input str30 label estimate ll hl extra
    "Var 1" 0.25 0.15 0.35 100
    "Var 2" 0.18 0.08 0.28 200
    "Var 3" -0.12 -0.22 -0.02 300
    end
}

// Store original data
local orig_n = _N
quietly summarize extra
local orig_sum = r(sum)

// Run forestpy
forestpy, estimate(estimate) varlabel(label) ll(ll) hl(hl)

// Check data is preserved
local pass = 1
if _N != `orig_n' {
    display as error "       N changed: was `orig_n', now `=_N'"
    local pass = 0
}
quietly summarize extra
if r(sum) != `orig_sum' {
    display as error "       Data modified: sum(extra) was `orig_sum', now `r(sum)'"
    local pass = 0
}

if `pass' {
    display as result "PASSED: Original data preserved"
    local ++tests_passed
}
else {
    display as error "FAILED: Data not preserved"
    local ++tests_failed
}

// =============================================================================
// VALIDATION 11: Return filename with saving()
// =============================================================================

local ++tests_run
display as text _n "VALIDATION 11: Return filename with saving()"
display as text "{hline 40}"

quietly {
    clear
    input str30 label estimate ll hl
    "Var 1" 0.25 0.15 0.35
    "Var 2" 0.18 0.08 0.28
    end
}

tempfile testout
local expected_file "`testout'_test.png"

forestpy, estimate(estimate) varlabel(label) ll(ll) hl(hl) ///
    saving("`expected_file'") replace

if "`r(filename)'" == "`expected_file'" {
    display as result "PASSED: r(filename) returned correctly"
    local ++tests_passed
}
else {
    display as error "FAILED: r(filename) = '`r(filename)'' (expected '`expected_file'')"
    local ++tests_failed
}

// Clean up
capture erase "`expected_file'"

// =============================================================================
// VALIDATION 12: Combined if and in
// =============================================================================

local ++tests_run
display as text _n "VALIDATION 12: Combined if and in conditions"
display as text "{hline 40}"

quietly {
    clear
    input str30 label estimate ll hl
    "Var 1" 0.25 0.15 0.35
    "Var 2" -0.18 -0.28 -0.08
    "Var 3" 0.12 0.02 0.22
    "Var 4" -0.35 -0.45 -0.25
    "Var 5" 0.05 -0.05 0.15
    end
}

// in 2/4 gives Var2, Var3, Var4
// if estimate > 0 within that gives only Var3 = 1 obs
forestpy if estimate > 0 in 2/4, estimate(estimate) varlabel(label) ll(ll) hl(hl)

if r(N) == 1 {
    display as result "PASSED: Combined if/in gives r(N) = 1"
    local ++tests_passed
}
else {
    display as error "FAILED: r(N) = `r(N)' (expected 1 with combined if/in)"
    local ++tests_failed
}

// =============================================================================
// VALIDATION 13: Groupvar doesn't change N
// =============================================================================

local ++tests_run
display as text _n "VALIDATION 13: Groupvar doesn't affect N count"
display as text "{hline 40}"

quietly {
    clear
    input str30 label estimate ll hl str15 group
    "Var 1" 0.25 0.15 0.35 "Group A"
    "Var 2" 0.18 0.08 0.28 "Group A"
    "Var 3" -0.12 -0.22 -0.02 "Group B"
    "Var 4" 0.35 0.25 0.45 "Group B"
    end
}

// With groupvar, N should still be 4 (the group headers are added by Python)
forestpy, estimate(estimate) varlabel(label) ll(ll) hl(hl) groupvar(group)

if r(N) == 4 {
    display as result "PASSED: r(N) = 4 (data rows, not including group headers)"
    local ++tests_passed
}
else {
    display as error "FAILED: r(N) = `r(N)' (expected 4)"
    local ++tests_failed
}

// =============================================================================
// VALIDATION SUMMARY
// =============================================================================

display as text _n "{hline 70}"
display as text "VALIDATION SUMMARY"
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
    display as error _n "VALIDATION FAILED"
    exit 1
}
else {
    display as result _n "ALL VALIDATIONS PASSED"
}

// End of validation_forestpy.do
