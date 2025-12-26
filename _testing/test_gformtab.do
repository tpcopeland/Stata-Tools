/*******************************************************************************
* test_gformtab.do
*
* Purpose: Comprehensive testing of gformtab command
*          Tests all options with simulated gformula results
*
* Note: Since gformula is an external SSC package that may not be installed,
*       this test file uses a mock helper program that simulates gformula's
*       r() output structure. This allows testing gformtab's formatting
*       functionality without requiring gformula to be installed.
*
* Prerequisites:
*   - gformtab.ado must be installed/accessible
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

* Directory structure
global TESTING_DIR "${STATA_TOOLS_PATH}/_testing"
global DATA_DIR "${TESTING_DIR}/data"

* =============================================================================
* SETUP: Install package from local repository
* =============================================================================

* Install regtab package (includes gformtab)
capture net uninstall regtab
net install regtab, from("${STATA_TOOLS_PATH}/regtab")

local testdir "${DATA_DIR}"

display as text _n "{hline 70}"
display as text "GFORMTAB COMMAND TESTING"
display as text "{hline 70}"
display as text "Test directory: `testdir'"
display as text "{hline 70}"

local test_count = 0
local pass_count = 0
local fail_count = 0

* =============================================================================
* HELPER: Mock gformula output
* =============================================================================
* This program simulates the r() scalars and matrices that gformula produces
* so we can test gformtab without requiring gformula to be installed.

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

    * Create percentile CI (slightly different for testing)
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
* TEST 1: Basic gformtab with simulated results
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Basic gformtab"
display as text "{hline 50}"

capture noisily {
    * Simulate typical mediation analysis results
    * TCE = 0.15 (total effect of treatment on outcome)
    * NDE = 0.10 (direct effect)
    * NIE = 0.05 (indirect effect via mediator)
    * PM = 0.33 (proportion mediated = NIE/TCE)
    * CDE = 0.08 (controlled direct effect)

    mock_gformula, tce(0.15) nde(0.10) nie(0.05) pm(0.33) cde(0.08) ///
        se_tce(0.03) se_nde(0.025) se_nie(0.015) se_pm(0.08) se_cde(0.025)

    gformtab, xlsx("`testdir'/_test_gformtab.xlsx") sheet("Mediation")

    confirm file "`testdir'/_test_gformtab.xlsx"
    display as result "  PASSED: Basic gformtab works"
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
    mock_gformula, tce(0.15) nde(0.10) nie(0.05) pm(0.33) cde(0.08)

    gformtab, xlsx("`testdir'/_test_gformtab_title.xlsx") sheet("Table 2") ///
        title("Table 2. Causal Mediation Analysis Results")

    confirm file "`testdir'/_test_gformtab_title.xlsx"
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
    mock_gformula, tce(0.20) nde(0.12) nie(0.08) pm(0.40) cde(0.10)

    gformtab, xlsx("`testdir'/_test_gformtab_pct.xlsx") sheet("Percentile") ///
        ci(percentile) title("Mediation Results (Percentile CI)")

    confirm file "`testdir'/_test_gformtab_pct.xlsx"
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
    mock_gformula, tce(0.18) nde(0.11) nie(0.07) pm(0.39) cde(0.09)

    gformtab, xlsx("`testdir'/_test_gformtab_bc.xlsx") sheet("BC") ///
        ci(bc) title("Mediation Results (Bias-Corrected CI)")

    confirm file "`testdir'/_test_gformtab_bc.xlsx"
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
    mock_gformula, tce(0.22) nde(0.14) nie(0.08) pm(0.36) cde(0.12)

    gformtab, xlsx("`testdir'/_test_gformtab_bca.xlsx") sheet("BCa") ///
        ci(bca) title("Mediation Results (BCa CI)")

    confirm file "`testdir'/_test_gformtab_bca.xlsx"
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
    mock_gformula, tce(0.15) nde(0.10) nie(0.05) pm(0.33) cde(0.08)

    gformtab, xlsx("`testdir'/_test_gformtab_effect.xlsx") sheet("RD") ///
        effect("Risk Diff") title("Risk Difference Decomposition")

    confirm file "`testdir'/_test_gformtab_effect.xlsx"
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
    mock_gformula, tce(0.15) nde(0.10) nie(0.05) pm(0.33) cde(0.08)

    gformtab, xlsx("`testdir'/_test_gformtab_labels.xlsx") sheet("Custom") ///
        labels("Total Effect \ Direct Effect \ Indirect Effect \ % Mediated \ Controlled Effect") ///
        title("Mediation Analysis with Custom Labels")

    confirm file "`testdir'/_test_gformtab_labels.xlsx"
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
    mock_gformula, tce(0.1523) nde(0.1012) nie(0.0511) pm(0.3356) cde(0.0823)

    gformtab, xlsx("`testdir'/_test_gformtab_dec4.xlsx") sheet("Precise") ///
        decimal(4) title("High Precision Results")

    confirm file "`testdir'/_test_gformtab_dec4.xlsx"
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
    mock_gformula, tce(0.15) nde(0.10) nie(0.05) pm(0.33) cde(0.08)

    gformtab, xlsx("`testdir'/_test_gformtab_dec2.xlsx") sheet("Rounded") ///
        decimal(2) title("Low Precision Results")

    confirm file "`testdir'/_test_gformtab_dec2.xlsx"
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
    mock_gformula, tce(0.45) nde(0.25) nie(0.20) pm(0.44) cde(0.22) ///
        se_tce(0.08) se_nde(0.06) se_nie(0.05) se_pm(0.10) se_cde(0.06)

    gformtab, xlsx("`testdir'/_test_gformtab_large.xlsx") sheet("Large") ///
        title("Strong Treatment Effect")

    confirm file "`testdir'/_test_gformtab_large.xlsx"
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
    mock_gformula, tce(0.02) nde(0.015) nie(0.005) pm(0.25) cde(0.012) ///
        se_tce(0.03) se_nde(0.025) se_nie(0.015) se_pm(0.15) se_cde(0.025)

    gformtab, xlsx("`testdir'/_test_gformtab_small.xlsx") sheet("Small") ///
        title("Near-Null Effects")

    confirm file "`testdir'/_test_gformtab_small.xlsx"
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
    mock_gformula, tce(-0.12) nde(-0.08) nie(-0.04) pm(0.33) cde(-0.07) ///
        se_tce(0.04) se_nde(0.03) se_nie(0.02) se_pm(0.10) se_cde(0.03)

    gformtab, xlsx("`testdir'/_test_gformtab_neg.xlsx") sheet("Protective") ///
        title("Protective Treatment Effect")

    confirm file "`testdir'/_test_gformtab_neg.xlsx"
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
    mock_gformula, tce(0.18) nde(0.11) nie(0.07) pm(0.39) cde(0.09) ///
        se_tce(0.035) se_nde(0.028) se_nie(0.018) se_pm(0.09) se_cde(0.028)

    gformtab, xlsx("`testdir'/_test_gformtab_full.xlsx") sheet("Complete") ///
        ci(percentile) effect("RD") decimal(4) ///
        labels("Total Causal Effect \ Natural Direct Effect \ Natural Indirect Effect \ Proportion Mediated \ Controlled Direct Effect") ///
        title("Table 3. Complete Mediation Analysis")

    confirm file "`testdir'/_test_gformtab_full.xlsx"
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
    mock_gformula, tce(0.15) nde(0.10) nie(0.05) pm(0.33) cde(0.08)
    gformtab, xlsx("`testdir'/_test_gformtab_multi.xlsx") sheet("Model 1") ///
        title("Model 1: Unadjusted")

    * Second analysis (different effects)
    mock_gformula, tce(0.12) nde(0.08) nie(0.04) pm(0.33) cde(0.07)
    gformtab, xlsx("`testdir'/_test_gformtab_multi.xlsx") sheet("Model 2") ///
        title("Model 2: Adjusted")

    confirm file "`testdir'/_test_gformtab_multi.xlsx"
    display as result "  PASSED: Multiple sheets work"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 15: Error handling - no gformula results
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Error handling - no results"
display as text "{hline 50}"

capture noisily {
    * Clear r() completely
    return clear
    matrix drop _all

    * This should fail with appropriate error
    capture gformtab, xlsx("`testdir'/_test_error.xlsx") sheet("Error")

    if _rc != 0 {
        display as result "  PASSED: Proper error when no gformula results"
        local ++pass_count
    }
    else {
        display as error "  FAILED: Should have errored without gformula results"
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
    mock_gformula, tce(0.15) nde(0.10) nie(0.05) pm(0.33) cde(0.08)

    * This should fail - invalid CI type
    capture gformtab, xlsx("`testdir'/_test_error.xlsx") sheet("Error") ci(invalid)

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
    mock_gformula, tce(0.15) nde(0.10) nie(0.05) pm(0.33) cde(0.08)

    * This should fail - decimal out of range
    capture gformtab, xlsx("`testdir'/_test_error.xlsx") sheet("Error") decimal(10)

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
    mock_gformula, tce(0.15) nde(0.10) nie(0.05) pm(0.33) cde(0.08)

    * This should fail - no .xlsx extension
    capture gformtab, xlsx("`testdir'/_test_error.xls") sheet("Error")

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

local output_files "_test_gformtab _test_gformtab_title _test_gformtab_pct _test_gformtab_bc _test_gformtab_bca _test_gformtab_effect _test_gformtab_labels _test_gformtab_dec4 _test_gformtab_dec2 _test_gformtab_large _test_gformtab_small _test_gformtab_neg _test_gformtab_full _test_gformtab_multi"
foreach f of local output_files {
    capture erase "`testdir'/`f'.xlsx"
}

* Drop mock program
capture program drop mock_gformula

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
