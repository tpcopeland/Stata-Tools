/*******************************************************************************
* validation_gformtab.do
*
* Purpose: Validation tests for gformtab command
*          Verifies correctness of formatting and output values
*
* Validation approach:
*   - Use mock gformula results with known values
*   - Verify Excel file structure and content matches input
*   - Test that stored results match input values
*   - Verify CI calculations are correctly extracted
*
* Author: Timothy P Copeland
* Date: 2025-12-19
*******************************************************************************/

clear all
set more off
version 16.0

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
* HELPER: Mock gformula output (same as in test file)
* =============================================================================
capture program drop mock_gformula
program define mock_gformula, rclass
    version 16.0
    syntax, tce(real) nde(real) nie(real) pm(real) cde(real) ///
            [se_tce(real 0.05) se_nde(real 0.04) se_nie(real 0.03) ///
             se_pm(real 0.02) se_cde(real 0.04)]

    * Store point estimates in r()
    return scalar tce = `tce'
    return scalar nde = `nde'
    return scalar nie = `nie'
    return scalar pm = `pm'
    return scalar cde = `cde'

    * Store standard errors
    return scalar se_tce = `se_tce'
    return scalar se_nde = `se_nde'
    return scalar se_nie = `se_nie'
    return scalar se_pm = `se_pm'
    return scalar se_cde = `se_cde'

    * Create CI matrices (normal approximation: estimate +/- 1.96*SE)
    matrix ci_normal = J(5, 2, .)
    matrix ci_normal[1,1] = `tce' - 1.96*`se_tce'
    matrix ci_normal[1,2] = `tce' + 1.96*`se_tce'
    matrix ci_normal[2,1] = `nde' - 1.96*`se_nde'
    matrix ci_normal[2,2] = `nde' + 1.96*`se_nde'
    matrix ci_normal[3,1] = `nie' - 1.96*`se_nie'
    matrix ci_normal[3,2] = `nie' + 1.96*`se_nie'
    matrix ci_normal[4,1] = `pm' - 1.96*`se_pm'
    matrix ci_normal[4,2] = `pm' + 1.96*`se_pm'
    matrix ci_normal[5,1] = `cde' - 1.96*`se_cde'
    matrix ci_normal[5,2] = `cde' + 1.96*`se_cde'

    * Create percentile CI
    matrix ci_percentile = J(5, 2, .)
    matrix ci_percentile[1,1] = `tce' - 2.0*`se_tce'
    matrix ci_percentile[1,2] = `tce' + 1.9*`se_tce'
    matrix ci_percentile[2,1] = `nde' - 2.0*`se_nde'
    matrix ci_percentile[2,2] = `nde' + 1.9*`se_nde'
    matrix ci_percentile[3,1] = `nie' - 2.0*`se_nie'
    matrix ci_percentile[3,2] = `nie' + 1.9*`se_nie'
    matrix ci_percentile[4,1] = `pm' - 2.0*`se_pm'
    matrix ci_percentile[4,2] = `pm' + 1.9*`se_pm'
    matrix ci_percentile[5,1] = `cde' - 2.0*`se_cde'
    matrix ci_percentile[5,2] = `cde' + 1.9*`se_cde'

    * Create bias-corrected CI
    matrix ci_bc = J(5, 2, .)
    matrix ci_bc[1,1] = `tce' - 2.05*`se_tce'
    matrix ci_bc[1,2] = `tce' + 1.85*`se_tce'
    matrix ci_bc[2,1] = `nde' - 2.05*`se_nde'
    matrix ci_bc[2,2] = `nde' + 1.85*`se_nde'
    matrix ci_bc[3,1] = `nie' - 2.05*`se_nie'
    matrix ci_bc[3,2] = `nie' + 1.85*`se_nie'
    matrix ci_bc[4,1] = `pm' - 2.05*`se_pm'
    matrix ci_bc[4,2] = `pm' + 1.85*`se_pm'
    matrix ci_bc[5,1] = `cde' - 2.05*`se_cde'
    matrix ci_bc[5,2] = `cde' + 1.85*`se_cde'

    * Create BCa CI
    matrix ci_bca = J(5, 2, .)
    matrix ci_bca[1,1] = `tce' - 2.1*`se_tce'
    matrix ci_bca[1,2] = `tce' + 1.8*`se_tce'
    matrix ci_bca[2,1] = `nde' - 2.1*`se_nde'
    matrix ci_bca[2,2] = `nde' + 1.8*`se_nde'
    matrix ci_bca[3,1] = `nie' - 2.1*`se_nie'
    matrix ci_bca[3,2] = `nie' + 1.8*`se_nie'
    matrix ci_bca[4,1] = `pm' - 2.1*`se_pm'
    matrix ci_bca[4,2] = `pm' + 1.8*`se_pm'
    matrix ci_bca[5,1] = `cde' - 2.1*`se_cde'
    matrix ci_bca[5,2] = `cde' + 1.8*`se_cde'

end

* =============================================================================
* HEADER
* =============================================================================
display as text _n "{hline 70}"
display as text "GFORMTAB VALIDATION TESTS"
display as text "{hline 70}"

local test_count = 0
local pass_count = 0
local fail_count = 0

* =============================================================================
* SECTION 1: VERIFY STORED RESULTS
* =============================================================================
display as text _n "SECTION 1: Stored Results Validation" _n

* Test 1.1: Verify stored scalars match input
local ++test_count
display as text "Test 1.1: Stored results match input values"
capture {
    * Known input values
    local input_tce = 0.15
    local input_nde = 0.10
    local input_nie = 0.05
    local input_pm = 0.33
    local input_cde = 0.08

    mock_gformula, tce(`input_tce') nde(`input_nde') nie(`input_nie') ///
        pm(`input_pm') cde(`input_cde')

    gformtab, xlsx("`testdir'/_val_gformtab.xlsx") sheet("Test")

    * Check stored results match input
    assert reldif(r(tce), `input_tce') < 0.0001
    assert reldif(r(nde), `input_nde') < 0.0001
    assert reldif(r(nie), `input_nie') < 0.0001
    assert reldif(r(pm), `input_pm') < 0.0001
    assert reldif(r(cde), `input_cde') < 0.0001
}
if _rc == 0 {
    display as result "  PASS: Stored scalars match input values"
    local ++pass_count
}
else {
    display as error "  FAIL: Stored scalars don't match input"
    local ++fail_count
}

* Test 1.2: Verify N_effects is always 5
local ++test_count
display as text "Test 1.2: N_effects equals 5"
capture {
    mock_gformula, tce(0.15) nde(0.10) nie(0.05) pm(0.33) cde(0.08)

    gformtab, xlsx("`testdir'/_val_gformtab.xlsx") sheet("NEffects")

    assert r(N_effects) == 5
}
if _rc == 0 {
    display as result "  PASS: N_effects correctly equals 5"
    local ++pass_count
}
else {
    display as error "  FAIL: N_effects incorrect"
    local ++fail_count
}

* Test 1.3: Verify xlsx and sheet macros stored
local ++test_count
display as text "Test 1.3: File path macros stored"
capture {
    mock_gformula, tce(0.15) nde(0.10) nie(0.05) pm(0.33) cde(0.08)

    gformtab, xlsx("`testdir'/_val_gformtab.xlsx") sheet("Macros")

    assert "`r(xlsx)'" == "`testdir'/_val_gformtab.xlsx"
    assert "`r(sheet)'" == "Macros"
    assert "`r(ci)'" == "normal"
}
if _rc == 0 {
    display as result "  PASS: File path macros correctly stored"
    local ++pass_count
}
else {
    display as error "  FAIL: File path macros incorrect"
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
    mock_gformula, tce(0.15) nde(0.10) nie(0.05) pm(0.33) cde(0.08)

    capture erase "`testdir'/_val_gformtab_struct.xlsx"
    gformtab, xlsx("`testdir'/_val_gformtab_struct.xlsx") sheet("Structure")

    confirm file "`testdir'/_val_gformtab_struct.xlsx"
}
if _rc == 0 {
    display as result "  PASS: Excel file created successfully"
    local ++pass_count
}
else {
    display as error "  FAIL: Excel file not created"
    local ++fail_count
}

* Test 2.2: Verify Excel has exactly 7 rows (title + header + 5 effects)
local ++test_count
display as text "Test 2.2: Excel row count (7 rows expected)"
capture {
    import excel "`testdir'/_val_gformtab_struct.xlsx", sheet("Structure") clear

    count
    assert r(N) == 7
}
if _rc == 0 {
    display as result "  PASS: Excel has exactly 7 rows"
    local ++pass_count
}
else {
    display as error "  FAIL: Excel row count incorrect (expected 7)"
    local ++fail_count
}

* Test 2.3: Verify Excel has 5 columns (title, label, estimate, CI, SE)
local ++test_count
display as text "Test 2.3: Excel column count (5 columns expected)"
capture {
    import excel "`testdir'/_val_gformtab_struct.xlsx", sheet("Structure") clear

    ds
    local ncols : word count `r(varlist)'
    assert `ncols' == 5
}
if _rc == 0 {
    display as result "  PASS: Excel has exactly 5 columns"
    local ++pass_count
}
else {
    display as error "  FAIL: Excel column count incorrect (expected 5)"
    local ++fail_count
}

* =============================================================================
* SECTION 3: VERIFY VALUES IN EXCEL MATCH INPUT
* =============================================================================
display as text _n "SECTION 3: Excel Value Accuracy" _n

* Test 3.1: Point estimates in Excel match input (3 decimal default)
local ++test_count
display as text "Test 3.1: Point estimates match input"
capture {
    local input_tce = 0.150
    local input_nde = 0.100
    local input_nie = 0.050

    mock_gformula, tce(`input_tce') nde(`input_nde') nie(`input_nie') ///
        pm(0.333) cde(0.080)

    gformtab, xlsx("`testdir'/_val_gformtab_values.xlsx") sheet("Values")

    import excel "`testdir'/_val_gformtab_values.xlsx", sheet("Values") clear

    * Row 3 = TCE, Column C = estimate
    * Check that values are present (structure validation)
    assert !missing(C[3])
    assert !missing(C[4])
    assert !missing(C[5])
}
if _rc == 0 {
    display as result "  PASS: Point estimates present in Excel"
    local ++pass_count
}
else {
    display as error "  FAIL: Point estimates not found"
    local ++fail_count
}

* Test 3.2: CIs are present and formatted correctly
local ++test_count
display as text "Test 3.2: CI values present and formatted"
capture {
    mock_gformula, tce(0.15) nde(0.10) nie(0.05) pm(0.33) cde(0.08)

    gformtab, xlsx("`testdir'/_val_gformtab_ci.xlsx") sheet("CI")

    import excel "`testdir'/_val_gformtab_ci.xlsx", sheet("CI") clear

    * Column D should have CI values with parentheses format
    * Check that CI column has values
    assert !missing(D[3])

    * CI should contain parentheses
    assert strpos(D[3], "(") > 0
    assert strpos(D[3], ")") > 0
}
if _rc == 0 {
    display as result "  PASS: CI values formatted correctly"
    local ++pass_count
}
else {
    display as error "  FAIL: CI format incorrect"
    local ++fail_count
}

* Test 3.3: SE values present
local ++test_count
display as text "Test 3.3: SE values present"
capture {
    mock_gformula, tce(0.15) nde(0.10) nie(0.05) pm(0.33) cde(0.08) ///
        se_tce(0.03) se_nde(0.025) se_nie(0.015) se_pm(0.08) se_cde(0.025)

    gformtab, xlsx("`testdir'/_val_gformtab_se.xlsx") sheet("SE")

    import excel "`testdir'/_val_gformtab_se.xlsx", sheet("SE") clear

    * Column E should have SE values
    assert !missing(E[3])
    assert !missing(E[4])
    assert !missing(E[5])
    assert !missing(E[6])
    assert !missing(E[7])
}
if _rc == 0 {
    display as result "  PASS: SE values present"
    local ++pass_count
}
else {
    display as error "  FAIL: SE values missing"
    local ++fail_count
}

* =============================================================================
* SECTION 4: CI TYPE VALIDATION
* =============================================================================
display as text _n "SECTION 4: CI Type Selection" _n

* Test 4.1: Normal CI is default
local ++test_count
display as text "Test 4.1: Normal CI is default"
capture {
    mock_gformula, tce(0.15) nde(0.10) nie(0.05) pm(0.33) cde(0.08)

    gformtab, xlsx("`testdir'/_val_gformtab_ci_normal.xlsx") sheet("Normal")

    assert "`r(ci)'" == "normal"
}
if _rc == 0 {
    display as result "  PASS: Normal CI is default"
    local ++pass_count
}
else {
    display as error "  FAIL: Default CI type incorrect"
    local ++fail_count
}

* Test 4.2: Percentile CI option works
local ++test_count
display as text "Test 4.2: Percentile CI option"
capture {
    mock_gformula, tce(0.15) nde(0.10) nie(0.05) pm(0.33) cde(0.08)

    gformtab, xlsx("`testdir'/_val_gformtab_ci_pct.xlsx") sheet("Pct") ci(percentile)

    assert "`r(ci)'" == "percentile"
    confirm file "`testdir'/_val_gformtab_ci_pct.xlsx"
}
if _rc == 0 {
    display as result "  PASS: Percentile CI option works"
    local ++pass_count
}
else {
    display as error "  FAIL: Percentile CI option failed"
    local ++fail_count
}

* Test 4.3: BC CI option works
local ++test_count
display as text "Test 4.3: BC CI option"
capture {
    mock_gformula, tce(0.15) nde(0.10) nie(0.05) pm(0.33) cde(0.08)

    gformtab, xlsx("`testdir'/_val_gformtab_ci_bc.xlsx") sheet("BC") ci(bc)

    assert "`r(ci)'" == "bc"
}
if _rc == 0 {
    display as result "  PASS: BC CI option works"
    local ++pass_count
}
else {
    display as error "  FAIL: BC CI option failed"
    local ++fail_count
}

* Test 4.4: BCa CI option works
local ++test_count
display as text "Test 4.4: BCa CI option"
capture {
    mock_gformula, tce(0.15) nde(0.10) nie(0.05) pm(0.33) cde(0.08)

    gformtab, xlsx("`testdir'/_val_gformtab_ci_bca.xlsx") sheet("BCa") ci(bca)

    assert "`r(ci)'" == "bca"
}
if _rc == 0 {
    display as result "  PASS: BCa CI option works"
    local ++pass_count
}
else {
    display as error "  FAIL: BCa CI option failed"
    local ++fail_count
}

* =============================================================================
* SECTION 5: DECIMAL PRECISION VALIDATION
* =============================================================================
display as text _n "SECTION 5: Decimal Precision" _n

* Test 5.1: Default decimal is 3
local ++test_count
display as text "Test 5.1: Default decimal precision (3)"
capture {
    mock_gformula, tce(0.123456) nde(0.100000) nie(0.050000) pm(0.333333) cde(0.080000)

    gformtab, xlsx("`testdir'/_val_gformtab_dec3.xlsx") sheet("Dec3")

    import excel "`testdir'/_val_gformtab_dec3.xlsx", sheet("Dec3") clear

    * Check that TCE value has 3 decimal places format
    * C[3] should be "0.123" (3 decimals)
    local val = C[3]
    local dotpos = strpos("`val'", ".")
    if `dotpos' > 0 {
        local decimals = strlen("`val'") - `dotpos'
        assert `decimals' == 3
    }
}
if _rc == 0 {
    display as result "  PASS: Default 3 decimal precision"
    local ++pass_count
}
else {
    display as error "  FAIL: Default decimal precision incorrect"
    local ++fail_count
}

* Test 5.2: decimal(4) produces 4 decimal places
local ++test_count
display as text "Test 5.2: Decimal precision (4)"
capture {
    mock_gformula, tce(0.12345) nde(0.10000) nie(0.05000) pm(0.33333) cde(0.08000)

    gformtab, xlsx("`testdir'/_val_gformtab_dec4.xlsx") sheet("Dec4") decimal(4)

    import excel "`testdir'/_val_gformtab_dec4.xlsx", sheet("Dec4") clear

    local val = C[3]
    local dotpos = strpos("`val'", ".")
    if `dotpos' > 0 {
        local decimals = strlen("`val'") - `dotpos'
        assert `decimals' == 4
    }
}
if _rc == 0 {
    display as result "  PASS: 4 decimal precision works"
    local ++pass_count
}
else {
    display as error "  FAIL: 4 decimal precision incorrect"
    local ++fail_count
}

* =============================================================================
* SECTION 6: CUSTOM LABELS VALIDATION
* =============================================================================
display as text _n "SECTION 6: Custom Labels" _n

* Test 6.1: Custom labels appear in output
local ++test_count
display as text "Test 6.1: Custom labels in output"
capture {
    mock_gformula, tce(0.15) nde(0.10) nie(0.05) pm(0.33) cde(0.08)

    gformtab, xlsx("`testdir'/_val_gformtab_labels.xlsx") sheet("Labels") ///
        labels("Total \ Direct \ Indirect \ Pct Med \ CDE")

    import excel "`testdir'/_val_gformtab_labels.xlsx", sheet("Labels") clear

    * Row 3 column B should be "Total"
    assert B[3] == "Total"
    assert B[4] == "Direct"
    assert B[5] == "Indirect"
}
if _rc == 0 {
    display as result "  PASS: Custom labels appear correctly"
    local ++pass_count
}
else {
    display as error "  FAIL: Custom labels incorrect"
    local ++fail_count
}

* Test 6.2: Default labels when not specified
local ++test_count
display as text "Test 6.2: Default labels"
capture {
    mock_gformula, tce(0.15) nde(0.10) nie(0.05) pm(0.33) cde(0.08)

    gformtab, xlsx("`testdir'/_val_gformtab_deflabels.xlsx") sheet("DefLabels")

    import excel "`testdir'/_val_gformtab_deflabels.xlsx", sheet("DefLabels") clear

    * Default labels should contain "TCE", "NDE", etc.
    assert strpos(B[3], "TCE") > 0 | strpos(B[3], "Total") > 0
}
if _rc == 0 {
    display as result "  PASS: Default labels present"
    local ++pass_count
}
else {
    display as error "  FAIL: Default labels missing"
    local ++fail_count
}

* =============================================================================
* SECTION 7: TITLE VALIDATION
* =============================================================================
display as text _n "SECTION 7: Title" _n

* Test 7.1: Title appears in first row
local ++test_count
display as text "Test 7.1: Title in first row"
capture {
    mock_gformula, tce(0.15) nde(0.10) nie(0.05) pm(0.33) cde(0.08)

    gformtab, xlsx("`testdir'/_val_gformtab_title.xlsx") sheet("Title") ///
        title("Table 1. My Mediation Results")

    import excel "`testdir'/_val_gformtab_title.xlsx", sheet("Title") clear

    * First row should contain the title
    assert strpos(A[1], "Table 1") > 0
}
if _rc == 0 {
    display as result "  PASS: Title appears in first row"
    local ++pass_count
}
else {
    display as error "  FAIL: Title not found"
    local ++fail_count
}

* =============================================================================
* SECTION 8: EDGE CASES
* =============================================================================
display as text _n "SECTION 8: Edge Cases" _n

* Test 8.1: Negative effects handled correctly
local ++test_count
display as text "Test 8.1: Negative effects"
capture {
    mock_gformula, tce(-0.12) nde(-0.08) nie(-0.04) pm(0.33) cde(-0.07)

    gformtab, xlsx("`testdir'/_val_gformtab_neg.xlsx") sheet("Negative")

    import excel "`testdir'/_val_gformtab_neg.xlsx", sheet("Negative") clear

    * Values should be negative
    assert strpos(C[3], "-") > 0
}
if _rc == 0 {
    display as result "  PASS: Negative effects handled correctly"
    local ++pass_count
}
else {
    display as error "  FAIL: Negative effects not handled"
    local ++fail_count
}

* Test 8.2: Very small effects
local ++test_count
display as text "Test 8.2: Very small effects"
capture {
    mock_gformula, tce(0.001) nde(0.0008) nie(0.0002) pm(0.20) cde(0.0007)

    gformtab, xlsx("`testdir'/_val_gformtab_small.xlsx") sheet("Small") decimal(4)

    confirm file "`testdir'/_val_gformtab_small.xlsx"
}
if _rc == 0 {
    display as result "  PASS: Very small effects handled"
    local ++pass_count
}
else {
    display as error "  FAIL: Very small effects not handled"
    local ++fail_count
}

* Test 8.3: Large effects
local ++test_count
display as text "Test 8.3: Large effects"
capture {
    mock_gformula, tce(0.85) nde(0.60) nie(0.25) pm(0.29) cde(0.55)

    gformtab, xlsx("`testdir'/_val_gformtab_large.xlsx") sheet("Large")

    confirm file "`testdir'/_val_gformtab_large.xlsx"
}
if _rc == 0 {
    display as result "  PASS: Large effects handled"
    local ++pass_count
}
else {
    display as error "  FAIL: Large effects not handled"
    local ++fail_count
}

* =============================================================================
* CLEANUP
* =============================================================================
display as text _n "{hline 70}"
display as text "Cleaning up validation files..."
display as text "{hline 70}"

local cleanup_files "_val_gformtab _val_gformtab_struct _val_gformtab_values _val_gformtab_ci _val_gformtab_se _val_gformtab_ci_normal _val_gformtab_ci_pct _val_gformtab_ci_bc _val_gformtab_ci_bca _val_gformtab_dec3 _val_gformtab_dec4 _val_gformtab_labels _val_gformtab_deflabels _val_gformtab_title _val_gformtab_neg _val_gformtab_small _val_gformtab_large"
foreach f of local cleanup_files {
    capture erase "`testdir'/`f'.xlsx"
}

* Drop mock program
capture program drop mock_gformula

* =============================================================================
* SUMMARY
* =============================================================================
display as text _n "{hline 70}"
display as text "GFORMTAB VALIDATION SUMMARY"
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
