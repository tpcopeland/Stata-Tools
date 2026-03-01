/*******************************************************************************
* test_gcomptab.do
*
* Purpose: Comprehensive testing of gcomptab command
*          Tests all options with simulated gcomp results
*
* Note: Since gcomp is an external SSC package that may not be installed,
*       this test file uses a mock helper program that simulates gcomp's
*       r() output structure. This allows testing gcomptab's formatting
*       functionality without requiring gcomp to be installed.
*
* Prerequisites:
*   - gcomptab.ado must be installed/accessible
*   - Stata 16+ required
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
* Detect Stata-Tools repo root
capture confirm file "gcomp/gcomptab.ado"
if _rc == 0 {
    * Running from Stata-Tools root
    global STATA_TOOLS_PATH "`c(pwd)'"
}
else {
    capture confirm file "../../gcomp/gcomptab.ado"
    if _rc == 0 {
        * Running from gcomp/qa/ directory
        global STATA_TOOLS_PATH "`c(pwd)'/../.."
    }
    else {
        global STATA_TOOLS_PATH "/home/`c(username)'/Stata-Tools"
    }
}

* Add gcomp package to adopath
adopath ++ "${STATA_TOOLS_PATH}/gcomp"

* Test output directory
local testdir "`c(tmpdir)'"

display as text _n "{hline 70}"
display as text "GFORMTAB COMMAND TESTING"
display as text "{hline 70}"
display as text "Test directory: `testdir'"
display as text "{hline 70}"

local test_count = 0
local pass_count = 0
local fail_count = 0

* =============================================================================
* HELPER: Mock gcomp output
* =============================================================================
* This program simulates the r() scalars and matrices that gcomp produces
* so we can test gcomptab without requiring gcomp to be installed.

capture program drop mock_gcomp
program define mock_gcomp, eclass
    version 16.0
    syntax, tce(real) nde(real) nie(real) pm(real) cde(real) ///
            [se_tce(real 0.05) se_nde(real 0.04) se_nie(real 0.03) ///
             se_pm(real 0.02) se_cde(real 0.04)]

    * Build b vector and V matrix
    tempname b V se_mat
    matrix `b' = (`tce', `nde', `nie', `pm', `cde')
    matrix colnames `b' = tce nde nie pm cde
    matrix `V' = J(5, 5, 0)
    matrix `V'[1,1] = `se_tce'^2
    matrix `V'[2,2] = `se_nde'^2
    matrix `V'[3,3] = `se_nie'^2
    matrix `V'[4,4] = `se_pm'^2
    matrix `V'[5,5] = `se_cde'^2
    matrix colnames `V' = tce nde nie pm cde
    matrix rownames `V' = tce nde nie pm cde

    * Post to e()
    ereturn post `b' `V'
    ereturn local cmd "gcomp"
    ereturn local analysis_type "mediation"

    * Convenience scalars
    ereturn scalar tce = `tce'
    ereturn scalar nde = `nde'
    ereturn scalar nie = `nie'
    ereturn scalar pm = `pm'
    ereturn scalar cde = `cde'
    ereturn scalar se_tce = `se_tce'
    ereturn scalar se_nde = `se_nde'
    ereturn scalar se_nie = `se_nie'
    ereturn scalar se_pm = `se_pm'
    ereturn scalar se_cde = `se_cde'

    * SE vector
    matrix `se_mat' = (`se_tce', `se_nde', `se_nie', `se_pm', `se_cde')
    matrix colnames `se_mat' = tce nde nie pm cde
    ereturn matrix se = `se_mat'

    * Create CI matrices matching real gcomp layout: 2 rows x 5 cols
    * Row 1 = lower bounds, Row 2 = upper bounds
    * Cols named: tce nde nie pm cde
    tempname cin cip cibc cibca
    matrix `cin' = J(2, 5, .)
    matrix `cin'[1,1] = `tce' - 1.96*`se_tce'
    matrix `cin'[2,1] = `tce' + 1.96*`se_tce'
    matrix `cin'[1,2] = `nde' - 1.96*`se_nde'
    matrix `cin'[2,2] = `nde' + 1.96*`se_nde'
    matrix `cin'[1,3] = `nie' - 1.96*`se_nie'
    matrix `cin'[2,3] = `nie' + 1.96*`se_nie'
    matrix `cin'[1,4] = `pm' - 1.96*`se_pm'
    matrix `cin'[2,4] = `pm' + 1.96*`se_pm'
    matrix `cin'[1,5] = `cde' - 1.96*`se_cde'
    matrix `cin'[2,5] = `cde' + 1.96*`se_cde'
    matrix colnames `cin' = tce nde nie pm cde
    ereturn matrix ci_normal = `cin'

    * Create percentile CI (slightly different for testing)
    matrix `cip' = J(2, 5, .)
    matrix `cip'[1,1] = `tce' - 2.0*`se_tce'
    matrix `cip'[2,1] = `tce' + 1.9*`se_tce'
    matrix `cip'[1,2] = `nde' - 2.0*`se_nde'
    matrix `cip'[2,2] = `nde' + 1.9*`se_nde'
    matrix `cip'[1,3] = `nie' - 2.0*`se_nie'
    matrix `cip'[2,3] = `nie' + 1.9*`se_nie'
    matrix `cip'[1,4] = `pm' - 2.0*`se_pm'
    matrix `cip'[2,4] = `pm' + 1.9*`se_pm'
    matrix `cip'[1,5] = `cde' - 2.0*`se_cde'
    matrix `cip'[2,5] = `cde' + 1.9*`se_cde'
    matrix colnames `cip' = tce nde nie pm cde
    ereturn matrix ci_percentile = `cip'

    * Create bias-corrected CI
    matrix `cibc' = J(2, 5, .)
    matrix `cibc'[1,1] = `tce' - 2.05*`se_tce'
    matrix `cibc'[2,1] = `tce' + 1.85*`se_tce'
    matrix `cibc'[1,2] = `nde' - 2.05*`se_nde'
    matrix `cibc'[2,2] = `nde' + 1.85*`se_nde'
    matrix `cibc'[1,3] = `nie' - 2.05*`se_nie'
    matrix `cibc'[2,3] = `nie' + 1.85*`se_nie'
    matrix `cibc'[1,4] = `pm' - 2.05*`se_pm'
    matrix `cibc'[2,4] = `pm' + 1.85*`se_pm'
    matrix `cibc'[1,5] = `cde' - 2.05*`se_cde'
    matrix `cibc'[2,5] = `cde' + 1.85*`se_cde'
    matrix colnames `cibc' = tce nde nie pm cde
    ereturn matrix ci_bc = `cibc'

    * Create BCa CI
    matrix `cibca' = J(2, 5, .)
    matrix `cibca'[1,1] = `tce' - 2.1*`se_tce'
    matrix `cibca'[2,1] = `tce' + 1.8*`se_tce'
    matrix `cibca'[1,2] = `nde' - 2.1*`se_nde'
    matrix `cibca'[2,2] = `nde' + 1.8*`se_nde'
    matrix `cibca'[1,3] = `nie' - 2.1*`se_nie'
    matrix `cibca'[2,3] = `nie' + 1.8*`se_nie'
    matrix `cibca'[1,4] = `pm' - 2.1*`se_pm'
    matrix `cibca'[2,4] = `pm' + 1.8*`se_pm'
    matrix `cibca'[1,5] = `cde' - 2.1*`se_cde'
    matrix `cibca'[2,5] = `cde' + 1.8*`se_cde'
    matrix colnames `cibca' = tce nde nie pm cde
    ereturn matrix ci_bca = `cibca'

end

* =============================================================================
* TEST 1: Basic gcomptab with simulated results
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Basic gcomptab"
display as text "{hline 50}"

capture noisily {
    * Simulate typical mediation analysis results
    * TCE = 0.15 (total effect of treatment on outcome)
    * NDE = 0.10 (direct effect)
    * NIE = 0.05 (indirect effect via mediator)
    * PM = 0.33 (proportion mediated = NIE/TCE)
    * CDE = 0.08 (controlled direct effect)

    mock_gcomp, tce(0.15) nde(0.10) nie(0.05) pm(0.33) cde(0.08) ///
        se_tce(0.03) se_nde(0.025) se_nie(0.015) se_pm(0.08) se_cde(0.025)

    gcomptab, xlsx("`testdir'/_test_gcomptab.xlsx") sheet("Mediation")

    confirm file "`testdir'/_test_gcomptab.xlsx"
    display as result "  PASSED: Basic gcomptab works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 2: With title
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': With title"
display as text "{hline 50}"

capture noisily {
    mock_gcomp, tce(0.15) nde(0.10) nie(0.05) pm(0.33) cde(0.08)

    gcomptab, xlsx("`testdir'/_test_gcomptab_title.xlsx") sheet("Table 2") ///
        title("Table 2. Causal Mediation Analysis Results")

    confirm file "`testdir'/_test_gcomptab_title.xlsx"
    display as result "  PASSED: Title option works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 3: Percentile CI
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Percentile CI"
display as text "{hline 50}"

capture noisily {
    mock_gcomp, tce(0.20) nde(0.12) nie(0.08) pm(0.40) cde(0.10)

    gcomptab, xlsx("`testdir'/_test_gcomptab_pct.xlsx") sheet("Percentile") ///
        ci(percentile) title("Mediation Results (Percentile CI)")

    confirm file "`testdir'/_test_gcomptab_pct.xlsx"
    display as result "  PASSED: Percentile CI works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 4: Bias-corrected CI
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Bias-corrected CI"
display as text "{hline 50}"

capture noisily {
    mock_gcomp, tce(0.18) nde(0.11) nie(0.07) pm(0.39) cde(0.09)

    gcomptab, xlsx("`testdir'/_test_gcomptab_bc.xlsx") sheet("BC") ///
        ci(bc) title("Mediation Results (Bias-Corrected CI)")

    confirm file "`testdir'/_test_gcomptab_bc.xlsx"
    display as result "  PASSED: Bias-corrected CI works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 5: BCa CI
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': BCa CI"
display as text "{hline 50}"

capture noisily {
    mock_gcomp, tce(0.22) nde(0.14) nie(0.08) pm(0.36) cde(0.12)

    gcomptab, xlsx("`testdir'/_test_gcomptab_bca.xlsx") sheet("BCa") ///
        ci(bca) title("Mediation Results (BCa CI)")

    confirm file "`testdir'/_test_gcomptab_bca.xlsx"
    display as result "  PASSED: BCa CI works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 6: Custom effect label
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Custom effect label"
display as text "{hline 50}"

capture noisily {
    mock_gcomp, tce(0.15) nde(0.10) nie(0.05) pm(0.33) cde(0.08)

    gcomptab, xlsx("`testdir'/_test_gcomptab_effect.xlsx") sheet("RD") ///
        effect("Risk Diff") title("Risk Difference Decomposition")

    confirm file "`testdir'/_test_gcomptab_effect.xlsx"
    display as result "  PASSED: Custom effect label works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 7: Custom labels for effects
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Custom effect labels"
display as text "{hline 50}"

capture noisily {
    mock_gcomp, tce(0.15) nde(0.10) nie(0.05) pm(0.33) cde(0.08)

    gcomptab, xlsx("`testdir'/_test_gcomptab_labels.xlsx") sheet("Custom") ///
        labels("Total Effect \ Direct Effect \ Indirect Effect \ % Mediated \ Controlled Effect") ///
        title("Mediation Analysis with Custom Labels")

    confirm file "`testdir'/_test_gcomptab_labels.xlsx"
    display as result "  PASSED: Custom labels work"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 8: Different decimal precision
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Decimal precision (4 places)"
display as text "{hline 50}"

capture noisily {
    mock_gcomp, tce(0.1523) nde(0.1012) nie(0.0511) pm(0.3356) cde(0.0823)

    gcomptab, xlsx("`testdir'/_test_gcomptab_dec4.xlsx") sheet("Precise") ///
        decimal(4) title("High Precision Results")

    confirm file "`testdir'/_test_gcomptab_dec4.xlsx"
    display as result "  PASSED: 4 decimal precision works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 9: Low decimal precision
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Decimal precision (2 places)"
display as text "{hline 50}"

capture noisily {
    mock_gcomp, tce(0.15) nde(0.10) nie(0.05) pm(0.33) cde(0.08)

    gcomptab, xlsx("`testdir'/_test_gcomptab_dec2.xlsx") sheet("Rounded") ///
        decimal(2) title("Low Precision Results")

    confirm file "`testdir'/_test_gcomptab_dec2.xlsx"
    display as result "  PASSED: 2 decimal precision works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 10: Large effect sizes
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Large effect sizes"
display as text "{hline 50}"

capture noisily {
    * Simulating a strong treatment effect with substantial mediation
    mock_gcomp, tce(0.45) nde(0.25) nie(0.20) pm(0.44) cde(0.22) ///
        se_tce(0.08) se_nde(0.06) se_nie(0.05) se_pm(0.10) se_cde(0.06)

    gcomptab, xlsx("`testdir'/_test_gcomptab_large.xlsx") sheet("Large") ///
        title("Strong Treatment Effect")

    confirm file "`testdir'/_test_gcomptab_large.xlsx"
    display as result "  PASSED: Large effect sizes work"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 11: Small effect sizes (near zero)
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Small effect sizes"
display as text "{hline 50}"

capture noisily {
    * Simulating null or near-null effects
    mock_gcomp, tce(0.02) nde(0.015) nie(0.005) pm(0.25) cde(0.012) ///
        se_tce(0.03) se_nde(0.025) se_nie(0.015) se_pm(0.15) se_cde(0.025)

    gcomptab, xlsx("`testdir'/_test_gcomptab_small.xlsx") sheet("Small") ///
        title("Near-Null Effects")

    confirm file "`testdir'/_test_gcomptab_small.xlsx"
    display as result "  PASSED: Small effect sizes work"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 12: Negative effects (protective)
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Negative (protective) effects"
display as text "{hline 50}"

capture noisily {
    * Simulating protective effects (treatment reduces outcome)
    mock_gcomp, tce(-0.12) nde(-0.08) nie(-0.04) pm(0.33) cde(-0.07) ///
        se_tce(0.04) se_nde(0.03) se_nie(0.02) se_pm(0.10) se_cde(0.03)

    gcomptab, xlsx("`testdir'/_test_gcomptab_neg.xlsx") sheet("Protective") ///
        title("Protective Treatment Effect")

    confirm file "`testdir'/_test_gcomptab_neg.xlsx"
    display as result "  PASSED: Negative effects work"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 13: All options combined
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': All options combined"
display as text "{hline 50}"

capture noisily {
    mock_gcomp, tce(0.18) nde(0.11) nie(0.07) pm(0.39) cde(0.09) ///
        se_tce(0.035) se_nde(0.028) se_nie(0.018) se_pm(0.09) se_cde(0.028)

    gcomptab, xlsx("`testdir'/_test_gcomptab_full.xlsx") sheet("Complete") ///
        ci(percentile) effect("RD") decimal(4) ///
        labels("Total Causal Effect \ Natural Direct Effect \ Natural Indirect Effect \ Proportion Mediated \ Controlled Direct Effect") ///
        title("Table 3. Complete Mediation Analysis")

    confirm file "`testdir'/_test_gcomptab_full.xlsx"
    display as result "  PASSED: All options combined work"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 14: Multiple sheets in same file
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Multiple sheets in same file"
display as text "{hline 50}"

capture noisily {
    * First analysis
    mock_gcomp, tce(0.15) nde(0.10) nie(0.05) pm(0.33) cde(0.08)
    gcomptab, xlsx("`testdir'/_test_gcomptab_multi.xlsx") sheet("Model 1") ///
        title("Model 1: Unadjusted")

    * Second analysis (different effects)
    mock_gcomp, tce(0.12) nde(0.08) nie(0.04) pm(0.33) cde(0.07)
    gcomptab, xlsx("`testdir'/_test_gcomptab_multi.xlsx") sheet("Model 2") ///
        title("Model 2: Adjusted")

    confirm file "`testdir'/_test_gcomptab_multi.xlsx"
    display as result "  PASSED: Multiple sheets work"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 15: Error handling - no gcomp results
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Error handling - no results"
display as text "{hline 50}"

capture noisily {
    * Clear e(cmd) by running a different eclass command
    clear
    set obs 10
    gen double _y = rnormal()
    gen double _x = rnormal()
    quietly regress _y _x

    * This should fail with appropriate error (e(cmd) != "gcomp")
    capture gcomptab, xlsx("`testdir'/_test_error.xlsx") sheet("Error")

    if _rc != 0 {
        display as result "  PASSED: Proper error when no gcomp results"
        local ++pass_count
    }
    else {
        display as error "  FAILED: Should have errored without gcomp results"
        local ++fail_count
    }
}

* =============================================================================
* TEST 16: Error handling - invalid CI type
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Error handling - invalid CI type"
display as text "{hline 50}"

capture noisily {
    mock_gcomp, tce(0.15) nde(0.10) nie(0.05) pm(0.33) cde(0.08)

    * This should fail - invalid CI type
    capture gcomptab, xlsx("`testdir'/_test_error.xlsx") sheet("Error") ci(invalid)

    if _rc != 0 {
        display as result "  PASSED: Proper error for invalid CI type"
        local ++pass_count
    }
    else {
        display as error "  FAILED: Should have errored for invalid CI type"
        local ++fail_count
    }
}

* =============================================================================
* TEST 17: Error handling - invalid decimal
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Error handling - invalid decimal"
display as text "{hline 50}"

capture noisily {
    mock_gcomp, tce(0.15) nde(0.10) nie(0.05) pm(0.33) cde(0.08)

    * This should fail - decimal out of range
    capture gcomptab, xlsx("`testdir'/_test_error.xlsx") sheet("Error") decimal(10)

    if _rc != 0 {
        display as result "  PASSED: Proper error for invalid decimal"
        local ++pass_count
    }
    else {
        display as error "  FAILED: Should have errored for decimal=10"
        local ++fail_count
    }
}

* =============================================================================
* TEST 18: Error handling - invalid file extension
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Error handling - invalid extension"
display as text "{hline 50}"

capture noisily {
    mock_gcomp, tce(0.15) nde(0.10) nie(0.05) pm(0.33) cde(0.08)

    * This should fail - no .xlsx extension
    capture gcomptab, xlsx("`testdir'/_test_error.xls") sheet("Error")

    if _rc != 0 {
        display as result "  PASSED: Proper error for invalid extension"
        local ++pass_count
    }
    else {
        display as error "  FAILED: Should have errored for .xls extension"
        local ++fail_count
    }
}

* =============================================================================
* CLEANUP: Remove temporary files
* =============================================================================
display as text _n "{hline 70}"
display as text "Cleaning up temporary files..."
display as text "{hline 70}"

local output_files "_test_gcomptab _test_gcomptab_title _test_gcomptab_pct _test_gcomptab_bc _test_gcomptab_bca _test_gcomptab_effect _test_gcomptab_labels _test_gcomptab_dec4 _test_gcomptab_dec2 _test_gcomptab_large _test_gcomptab_small _test_gcomptab_neg _test_gcomptab_full _test_gcomptab_multi"
foreach f of local output_files {
    capture erase "`testdir'/`f'.xlsx"
}

* Drop mock program
capture program drop mock_gcomp

* =============================================================================
* SUMMARY
* =============================================================================
display as text _n "{hline 70}"
display as text "GFORMTAB TEST SUMMARY"
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
    display as result "All tests PASSED!"
}
