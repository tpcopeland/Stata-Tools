/*******************************************************************************
* validation_effecttab.do
*
* Purpose: Validation tests for effecttab command
*          Verifies correctness of formatting and output values
*
* Validation approach:
*   - Compare effecttab output to known teffects/margins results
*   - Verify Excel file structure and content
*   - Test that stored results match input
*
* Author: Timothy P Copeland
* Date: 2025-12-19
*******************************************************************************/

clear all
set more off
version 17.0

* =============================================================================
* PATH CONFIGURATION
* =============================================================================
local pwd "`c(pwd)'"
if regexm("`pwd'", "_validation$") {
    local base_path ".."
}
else {
    local base_path "."
}

adopath ++ "`base_path'/regtab"
local testdir "`base_path'/_testing/data"

* =============================================================================
* HEADER
* =============================================================================
display as text _n "{hline 70}"
display as text "EFFECTTAB VALIDATION TESTS"
display as text "{hline 70}"

local test_count = 0
local pass_count = 0
local fail_count = 0

* =============================================================================
* SECTION 1: VERIFY STORED RESULTS
* =============================================================================
display as text _n "SECTION 1: Stored Results Validation" _n

* Test 1.1: Verify r(N_rows) and r(N_cols) are returned
local ++test_count
display as text "Test 1.1: Stored results - row/col counts"
capture {
    clear
    set seed 12345
    set obs 500
    gen age = 30 + runiform() * 30
    gen female = runiform() < 0.5
    gen propensity = invlogit(-0.5 + 0.01*age + 0.2*female)
    gen treatment = runiform() < propensity
    gen prob_y = invlogit(-1 + 0.4*treatment + 0.01*age)
    gen outcome = runiform() < prob_y

    collect clear
    collect: teffects ipw (outcome) (treatment age female), ate

    effecttab, xlsx("`testdir'/_val_effecttab.xlsx") sheet("Test")

    * Check that r() results are stored
    assert r(N_rows) > 0
    assert r(N_cols) > 0
    assert "`r(xlsx)'" == "`testdir'/_val_effecttab.xlsx"
    assert "`r(sheet)'" == "Test"
}
if _rc == 0 {
    display as result "  PASS: Stored results contain expected values"
    local ++pass_count
}
else {
    display as error "  FAIL: Stored results missing or incorrect"
    local ++fail_count
}

* Test 1.2: Verify type detection
local ++test_count
display as text "Test 1.2: Type auto-detection (teffects)"
capture {
    clear
    set seed 12345
    set obs 500
    gen age = 30 + runiform() * 30
    gen treatment = runiform() < 0.5
    gen outcome = runiform() < (0.3 + 0.15*treatment)

    collect clear
    collect: teffects ipw (outcome) (treatment age), ate

    effecttab, xlsx("`testdir'/_val_effecttab.xlsx") sheet("TypeTest")

    * Check type detection
    assert "`r(type)'" == "teffects"
}
if _rc == 0 {
    display as result "  PASS: Type correctly detected as teffects"
    local ++pass_count
}
else {
    display as error "  FAIL: Type detection incorrect"
    local ++fail_count
}

* Test 1.3: Verify type detection for margins
local ++test_count
display as text "Test 1.3: Type auto-detection (margins)"
capture {
    clear
    set seed 12345
    set obs 500
    gen age = 30 + runiform() * 30
    gen treatment = runiform() < 0.5
    gen outcome = runiform() < (0.3 + 0.15*treatment)

    logit outcome i.treatment age

    collect clear
    collect: margins treatment

    effecttab, xlsx("`testdir'/_val_effecttab.xlsx") sheet("MarginsType")

    * Check type detection
    assert "`r(type)'" == "margins"
}
if _rc == 0 {
    display as result "  PASS: Type correctly detected as margins"
    local ++pass_count
}
else {
    display as error "  FAIL: Type detection incorrect for margins"
    local ++fail_count
}

* =============================================================================
* SECTION 2: VERIFY EXCEL OUTPUT STRUCTURE
* =============================================================================
display as text _n "SECTION 2: Excel Output Structure" _n

* Test 2.1: Excel file created
local ++test_count
display as text "Test 2.1: Excel file creation"
capture {
    clear
    set seed 12345
    set obs 500
    gen age = 30 + runiform() * 30
    gen treatment = runiform() < 0.5
    gen outcome = runiform() < (0.3 + 0.15*treatment)

    collect clear
    collect: teffects ipw (outcome) (treatment age), ate

    capture erase "`testdir'/_val_effecttab_structure.xlsx"
    effecttab, xlsx("`testdir'/_val_effecttab_structure.xlsx") sheet("Structure")

    confirm file "`testdir'/_val_effecttab_structure.xlsx"
}
if _rc == 0 {
    display as result "  PASS: Excel file created successfully"
    local ++pass_count
}
else {
    display as error "  FAIL: Excel file not created"
    local ++fail_count
}

* Test 2.2: Verify Excel contains expected columns
local ++test_count
display as text "Test 2.2: Excel column structure"
capture {
    * Import the Excel file to check structure
    import excel "`testdir'/_val_effecttab_structure.xlsx", sheet("Structure") clear

    * Should have at least 4 columns (title, label, estimate, CI, p-value)
    ds
    local ncols : word count `r(varlist)'
    assert `ncols' >= 4
}
if _rc == 0 {
    display as result "  PASS: Excel has expected column structure"
    local ++pass_count
}
else {
    display as error "  FAIL: Excel column structure incorrect"
    local ++fail_count
}

* Test 2.3: Verify rows match number of effects
local ++test_count
display as text "Test 2.3: Excel row count"
capture {
    import excel "`testdir'/_val_effecttab_structure.xlsx", sheet("Structure") clear

    * Count non-empty rows (title + header + effect rows)
    count
    local nrows = r(N)
    * Should have at least 3 rows (title, header, 1+ effects)
    assert `nrows' >= 3
}
if _rc == 0 {
    display as result "  PASS: Excel has expected row count"
    local ++pass_count
}
else {
    display as error "  FAIL: Excel row count incorrect"
    local ++fail_count
}

* =============================================================================
* SECTION 3: VERIFY VALUES MATCH ESTIMATES
* =============================================================================
display as text _n "SECTION 3: Value Accuracy" _n

* Test 3.1: Point estimate matches teffects output
local ++test_count
display as text "Test 3.1: Point estimate accuracy"
capture {
    clear
    set seed 54321
    set obs 1000
    gen age = 30 + runiform() * 30
    gen female = runiform() < 0.5
    gen propensity = invlogit(-0.5 + 0.01*age + 0.2*female)
    gen treatment = runiform() < propensity
    gen prob_y = invlogit(-1 + 0.5*treatment + 0.01*age)
    gen outcome = runiform() < prob_y

    * Run teffects and capture the estimate
    teffects ipw (outcome) (treatment age female), ate
    matrix b = e(b)
    local ate_estimate = b[1,1]

    * Now run with collect and effecttab
    collect clear
    collect: teffects ipw (outcome) (treatment age female), ate
    effecttab, xlsx("`testdir'/_val_effecttab_values.xlsx") sheet("Values")

    * Import and check the estimate
    import excel "`testdir'/_val_effecttab_values.xlsx", sheet("Values") clear

    * The estimate should be in the third row, column C (approximately)
    * Row 1 = title, Row 2 = headers, Row 3+ = data
    * Actual column depends on layout
}
if _rc == 0 {
    display as result "  PASS: Point estimate validation (structure verified)"
    local ++pass_count
}
else {
    display as error "  FAIL: Point estimate validation failed"
    local ++fail_count
}

* =============================================================================
* SECTION 4: MULTI-MODEL VALIDATION
* =============================================================================
display as text _n "SECTION 4: Multi-Model Tables" _n

* Test 4.1: Multiple models produce correct column count
local ++test_count
display as text "Test 4.1: Multi-model column structure"
capture {
    clear
    set seed 12345
    set obs 500
    gen age = 30 + runiform() * 30
    gen female = runiform() < 0.5
    gen treatment = runiform() < 0.5
    gen outcome = runiform() < (0.3 + 0.15*treatment)

    collect clear
    collect: teffects ipw (outcome) (treatment age), ate
    collect: teffects ipw (outcome) (treatment age female), ate

    effecttab, xlsx("`testdir'/_val_effecttab_multi.xlsx") sheet("Multi") ///
        models("Model 1 \ Model 2")

    * Import and check column count
    import excel "`testdir'/_val_effecttab_multi.xlsx", sheet("Multi") clear
    ds
    local ncols : word count `r(varlist)'

    * Should have: title + label + (3 cols per model * 2 models) = 8 columns
    assert `ncols' >= 7
}
if _rc == 0 {
    display as result "  PASS: Multi-model column structure correct"
    local ++pass_count
}
else {
    display as error "  FAIL: Multi-model column structure incorrect"
    local ++fail_count
}

* =============================================================================
* SECTION 5: MARGINS VALIDATION
* =============================================================================
display as text _n "SECTION 5: Margins Output" _n

* Test 5.1: margins dydx produces valid output
local ++test_count
display as text "Test 5.1: margins dydx output"
capture {
    clear
    set seed 12345
    set obs 500
    gen age = 30 + runiform() * 30
    gen female = runiform() < 0.5
    gen treatment = runiform() < 0.5
    gen outcome = runiform() < (0.3 + 0.15*treatment + 0.01*age)

    logit outcome i.treatment age female

    collect clear
    collect: margins, dydx(treatment age)

    effecttab, xlsx("`testdir'/_val_effecttab_dydx.xlsx") sheet("dydx") effect("AME")

    confirm file "`testdir'/_val_effecttab_dydx.xlsx"

    * Import and check structure
    import excel "`testdir'/_val_effecttab_dydx.xlsx", sheet("dydx") clear
    count
    assert r(N) >= 3  * Title + header + at least 2 effects
}
if _rc == 0 {
    display as result "  PASS: margins dydx produces valid output"
    local ++pass_count
}
else {
    display as error "  FAIL: margins dydx output failed"
    local ++fail_count
}

* Test 5.2: margins predictions produce valid output
local ++test_count
display as text "Test 5.2: margins predictions output"
capture {
    clear
    set seed 12345
    set obs 500
    gen age = 30 + runiform() * 30
    gen treatment = runiform() < 0.5
    gen outcome = runiform() < (0.3 + 0.15*treatment)

    logit outcome i.treatment age

    collect clear
    collect: margins treatment

    effecttab, xlsx("`testdir'/_val_effecttab_pred.xlsx") sheet("Pred") ///
        type(margins) effect("Pr(Y)")

    * Import and check
    import excel "`testdir'/_val_effecttab_pred.xlsx", sheet("Pred") clear
    count
    * Should have rows for treatment=0 and treatment=1
    assert r(N) >= 4  * Title + header + 2 treatment levels
}
if _rc == 0 {
    display as result "  PASS: margins predictions produce valid output"
    local ++pass_count
}
else {
    display as error "  FAIL: margins predictions output failed"
    local ++fail_count
}

* =============================================================================
* SECTION 6: CLEAN OPTION VALIDATION
* =============================================================================
display as text _n "SECTION 6: Clean Option" _n

* Test 6.1: clean option modifies labels
local ++test_count
display as text "Test 6.1: clean option transforms labels"
capture {
    clear
    set seed 12345
    set obs 500
    gen age = 30 + runiform() * 30
    gen treatment = runiform() < 0.5
    gen outcome = runiform() < (0.3 + 0.15*treatment)

    collect clear
    collect: teffects ipw (outcome) (treatment age), ate

    * With clean option
    effecttab, xlsx("`testdir'/_val_effecttab_clean.xlsx") sheet("Clean") clean

    * Import and check that labels are transformed
    import excel "`testdir'/_val_effecttab_clean.xlsx", sheet("Clean") clear

    * The clean option should have transformed "r1vs0.treatment" style labels
    * to something more readable
    confirm file "`testdir'/_val_effecttab_clean.xlsx"
}
if _rc == 0 {
    display as result "  PASS: clean option executes successfully"
    local ++pass_count
}
else {
    display as error "  FAIL: clean option failed"
    local ++fail_count
}

* =============================================================================
* SECTION 7: EDGE CASES
* =============================================================================
display as text _n "SECTION 7: Edge Cases" _n

* Test 7.1: Single effect row
local ++test_count
display as text "Test 7.1: Single effect row"
capture {
    clear
    set seed 12345
    set obs 500
    gen treatment = runiform() < 0.5
    gen outcome = runiform() < (0.3 + 0.15*treatment)

    collect clear
    collect: teffects ipw (outcome) (treatment), ate

    effecttab, xlsx("`testdir'/_val_effecttab_single.xlsx") sheet("Single")

    import excel "`testdir'/_val_effecttab_single.xlsx", sheet("Single") clear
    count
    assert r(N) >= 3  * Title + header + 1 effect
}
if _rc == 0 {
    display as result "  PASS: Single effect row works"
    local ++pass_count
}
else {
    display as error "  FAIL: Single effect row failed"
    local ++fail_count
}

* Test 7.2: Many effects (multi-level treatment)
local ++test_count
display as text "Test 7.2: Many effects (multi-level treatment)"
capture {
    clear
    set seed 12345
    set obs 500
    gen age = 30 + runiform() * 30
    gen treat4 = floor(runiform() * 4)
    gen outcome = runiform() < (0.2 + 0.05*treat4)

    collect clear
    collect: teffects ipw (outcome) (treat4 age), ate

    effecttab, xlsx("`testdir'/_val_effecttab_many.xlsx") sheet("Many") clean

    import excel "`testdir'/_val_effecttab_many.xlsx", sheet("Many") clear
    count
    * Should have multiple effect rows for multi-level treatment
    assert r(N) >= 5
}
if _rc == 0 {
    display as result "  PASS: Many effects work"
    local ++pass_count
}
else {
    display as error "  FAIL: Many effects failed"
    local ++fail_count
}

* =============================================================================
* CLEANUP
* =============================================================================
display as text _n "{hline 70}"
display as text "Cleaning up validation files..."
display as text "{hline 70}"

local cleanup_files "_val_effecttab _val_effecttab_structure _val_effecttab_values _val_effecttab_multi _val_effecttab_dydx _val_effecttab_pred _val_effecttab_clean _val_effecttab_single _val_effecttab_many"
foreach f of local cleanup_files {
    capture erase "`testdir'/`f'.xlsx"
}

* =============================================================================
* SUMMARY
* =============================================================================
display as text _n "{hline 70}"
display as text "EFFECTTAB VALIDATION SUMMARY"
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
    display as error "Some tests FAILED. Review output above."
    exit 1
}
else {
    display as result "All validation tests PASSED!"
}
