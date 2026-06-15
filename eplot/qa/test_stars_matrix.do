/*******************************************************************************
* test_stars_matrix.do
*
* Purpose: Tests for eplot v2.3.0 bug fixes and new features
*
* Bug fixes tested:
*   - Stars + eform p-value computation (CRITICAL)
*   - type() special rows bypassing if/in filtering
*   - Matrix mode style(), xlabel(), sigcolors, stars options
*   - Auto-note claiming weighted boxes without weights
*   - Sort description alignment (raw value, not magnitude)
*
* New features tested:
*   - favors() annotation
*   - Auto-detect effect label from e(cmd)
*   - Interaction term note
*   - r(pvalues) return vector
*   - r(k) return scalar
*   - style(nejm) and style(bmj) presets
*   - version 16.0 in helper programs
*
* Author: Timothy Copeland
* Date: 2026-04-01
*******************************************************************************/

clear all
set seed 54321
version 16.0

**# Setup

* Path configuration
else if "`c(os)'" == "Unix" {
}
else {
}


* === Bootstrap ===
local qa_dir  "`c(pwd)'"
local pkg_dir "`qa_dir'/.."  

adopath ++ "`pkg_dir'"

* Reload to pick up latest changes
capture program drop eplot
capture program drop _eplot_parse_mode
capture program drop _eplot_data
capture program drop _eplot_estimates
capture program drop _eplot_matrix
capture program drop _eplot_apply_coeflabels
capture program drop _eplot_apply_keep
capture program drop _eplot_apply_drop
capture program drop _eplot_apply_rename
capture program drop _eplot_process_groups
capture program drop _eplot_process_headers
run "`pkg_dir'/eplot.ado"

* Detect QA directory for log
local pkg_dir ""
foreach _d in "." ".." "../.." "../eplot" "../../eplot" {
    capture confirm file "`c(pwd)'/`_d'/eplot.ado"
    if _rc == 0 {
        local pkg_dir "`c(pwd)'/`_d'"
        continue, break
    }
}
if "`pkg_dir'" == "" local pkg_dir "`c(pwd)'"
local qa_dir "`pkg_dir'/qa"

capture log close _all
log using "`qa_dir'/test_stars_matrix.log", replace text nomsg ///
    name(test_stars_matrix)

local test_count 0
local pass_count 0
local fail_count 0
local failed_tests ""

display _newline "EPLOT v2.3.0 TESTS"
display "Date: `c(current_date)' `c(current_time)'"
display _dup(70) "="

* =============================================================================
**# BUG FIX: Stars + eform p-value computation (CRITICAL)
* =============================================================================

* Test 1: Stars p-values computed from original b/se, not exp(b)/se
local ++test_count
local t1_pass 1
capture noisily {
    sysuse auto, clear
    quietly logit foreign price mpg
    * Save original coefficients for verification
    matrix B = e(b)
    matrix V = e(V)
    local b_price = B[1,1]
    local se_price = sqrt(V[1,1])
    local expected_z = abs(`b_price' / `se_price')
    local expected_pval = 2 * normal(-`expected_z')

    eplot ., eform stars drop(_cons)
    matrix P = r(pvalues)
}
if _rc != 0 {
    display as error "  FAIL [1.run]: command returned error `=_rc'"
    local t1_pass 0
}
else {
    * Verify the returned p-value matches b/se computation (not exp(b)/se)
    local returned_pval = P[1,1]
    local pdiff = abs(`returned_pval' - `expected_pval')
    if `pdiff' < 0.0001 {
        display as result "  PASS [1.pval]: p-value matches b/se computation"
    }
    else {
        display as error "  FAIL [1.pval]: expected p=`expected_pval', got p=`returned_pval' (diff=`pdiff')"
        local t1_pass 0
    }

    * Verify r(table) contains exponentiated values (OR, not log-OR)
    matrix T = r(table)
    local returned_b = T[1,1]
    local expected_or = exp(`b_price')
    local bdiff = abs(`returned_b' - `expected_or')
    if `bdiff' < 0.0001 {
        display as result "  PASS [1.eform]: r(table) contains OR, not log-OR"
    }
    else {
        display as error "  FAIL [1.eform]: expected OR=`expected_or', got `returned_b'"
        local t1_pass 0
    }
}
if `t1_pass' {
    local ++pass_count
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' 1"
}

* Test 2: P-values returned and valid range (order-independent check)
local ++test_count
local t2_pass 1
capture noisily {
    sysuse auto, clear
    quietly regress price mpg weight
    eplot ., drop(_cons)
    matrix P = r(pvalues)
}
if _rc != 0 {
    display as error "  FAIL [2.run]: command returned error `=_rc'"
    local t2_pass 0
}
else {
    local prows = rowsof(P)
    if `prows' == 2 {
        display as result "  PASS [2.dim]: r(pvalues) has 2 rows"
    }
    else {
        display as error "  FAIL [2.dim]: expected 2 rows, got `prows'"
        local t2_pass 0
    }
    * All p-values should be in (0, 1)
    local all_valid 1
    forvalues i = 1/`prows' {
        if P[`i', 1] <= 0 | P[`i', 1] >= 1 | missing(P[`i', 1]) {
            local all_valid 0
        }
    }
    if `all_valid' {
        display as result "  PASS [2.range]: all p-values in (0,1)"
    }
    else {
        display as error "  FAIL [2.range]: some p-values out of range"
        local t2_pass 0
    }
}
if `t2_pass' {
    local ++pass_count
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' 2"
}

* =============================================================================
**# BUG FIX: type() special rows bypass if/in filtering
* =============================================================================

* Test 3: type() with in condition respects row range
local ++test_count
capture noisily {
    clear
    input str20 study double(es lci uci) byte type
    "Header"   .     .     .    0
    "Study 1"  0.1   0.0   0.2  1
    "Study 2"  0.2   0.1   0.3  1
    "Study 3"  0.3   0.2   0.4  1
    end

    eplot es lci uci in 2/4, labels(study) type(type)
    * Should have 3 rows (Studies 1-3), NOT 4 (Header should be excluded)
    assert r(N) == 3
}
if _rc == 0 {
    display as result "  PASS: Test 3 - type() respects in condition"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 3 - type() in condition (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3"
}

* Test 4: type() with if condition respects filter
local ++test_count
capture noisily {
    clear
    input str20 study double(es lci uci) byte type byte include
    "Header"   .     .     .    0  0
    "Study 1"  0.1   0.0   0.2  1  1
    "Study 2"  0.2   0.1   0.3  1  1
    "Footer"   .     .     .    0  0
    end

    eplot es lci uci if include == 1, labels(study) type(type)
    assert r(N) == 2
}
if _rc == 0 {
    display as result "  PASS: Test 4 - type() respects if condition"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 4 - type() if condition (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4"
}

* Test 5: type() without if/in still includes all special rows
local ++test_count
capture noisily {
    clear
    input str20 study double(es lci uci) byte type
    "Header"   .     .     .    0
    "Study 1"  0.1   0.0   0.2  1
    "Overall"  0.15  0.05  0.25 5
    end

    eplot es lci uci, labels(study) type(type)
    assert r(N) == 3
}
if _rc == 0 {
    display as result "  PASS: Test 5 - type() without if/in includes all rows"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 5 - type() without if/in (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 5"
}

* =============================================================================
**# BUG FIX: Matrix mode style(), xlabel(), sigcolors, stars
* =============================================================================

* Test 6: Matrix mode accepts style()
local ++test_count
capture noisily {
    matrix R = (1.5, 1.1, 2.0 \ 0.8, 0.6, 1.2)
    matrix rownames R = "Treatment_A" "Treatment_B"
    eplot, matrix(R) style(jama)
    assert r(N) == 2
}
if _rc == 0 {
    display as result "  PASS: Test 6 - Matrix mode style(jama)"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 6 - Matrix mode style() (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 6"
}

* Test 7: Matrix mode accepts effect-axis xlabel()
local ++test_count
capture noisily {
    matrix R = (0.5, 0.01, 5.0 \ 1.2, 0.9, 1.5)
    matrix rownames R = "Wide_CI" "Normal_CI"
    eplot, matrix(R) xlabel(0(1)5)
    assert r(N) == 2
    local cmd `"`r(cmd)'"'
    assert strpos(`"`cmd'"', "0(1)5") > 0
}
if _rc == 0 {
    display as result "  PASS: Test 7 - Matrix mode xlabel()"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 7 - Matrix mode xlabel() (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 7"
}

* Test 8: Matrix mode accepts sigcolors
local ++test_count
capture noisily {
    matrix R = (0.5, 0.3, 0.7 \ 1.0, 0.8, 1.2)
    matrix rownames R = "Significant" "NotSignificant"
    eplot, matrix(R) sigcolors null(1)
    assert r(N) == 2
}
if _rc == 0 {
    display as result "  PASS: Test 8 - Matrix mode sigcolors"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 8 - Matrix mode sigcolors (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 8"
}

* Test 9: Matrix mode stars with 2-col matrix (b, se)
local ++test_count
capture noisily {
    matrix R = (2.5, 0.5 \ 0.1, 0.8)
    matrix rownames R = "Strong" "Weak"
    eplot, matrix(R) stars values
    assert r(N) == 2
}
if _rc == 0 {
    display as result "  PASS: Test 9 - Matrix mode stars with 2-col"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 9 - Matrix mode stars 2-col (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 9"
}

* Test 10: Matrix mode stars with 3-col matrix emits note, doesn't error
local ++test_count
capture noisily {
    matrix R = (0.5, 0.3, 0.7 \ 1.2, 0.9, 1.5)
    matrix rownames R = "A" "B"
    eplot, matrix(R) stars values
    assert r(N) == 2
}
if _rc == 0 {
    display as result "  PASS: Test 10 - Matrix mode stars with 3-col (graceful note)"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 10 - Matrix mode stars 3-col (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 10"
}

* Test 11: All new style presets work in matrix mode
local ++test_count
local t11_pass 1
foreach sty in forest coef lancet jama nejm bmj {
    capture noisily {
        matrix R = (1.5, 1.1, 2.0 \ 0.8, 0.6, 1.2)
        matrix rownames R = "A" "B"
        eplot, matrix(R) style(`sty')
    }
    if _rc != 0 {
        display as error "  FAIL [11.`sty']: style(`sty') in matrix mode"
        local t11_pass 0
    }
}
if `t11_pass' {
    display as result "  PASS: Test 11 - All styles work in matrix mode"
    local ++pass_count
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' 11"
}

* =============================================================================
**# BUG FIX: Auto-note without weights
* =============================================================================

* Test 12: Auto-note doesn't claim weighted boxes when no weights given
local ++test_count
capture noisily {
    clear
    input str20 study double(es lci uci) byte type
    "Study A"  0.1  0.0  0.2  1
    "Overall"  0.15 0.05 0.25 5
    end

    eplot es lci uci, labels(study) type(type)
    local cmd `"`r(cmd)'"'
    * Should NOT contain "Boxes proportional"
    assert strpos(`"`cmd'"', "Boxes proportional") == 0
    * Should contain "Diamonds represent"
    assert strpos(`"`cmd'"', "Diamonds represent") > 0
}
if _rc == 0 {
    display as result "  PASS: Test 12 - Auto-note without weights omits box text"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 12 - Auto-note without weights (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 12"
}

* Test 13: Auto-note includes box text when weights ARE given
local ++test_count
capture noisily {
    clear
    input str20 study double(es lci uci weight) byte type
    "Study A"  0.1  0.0  0.2  10.0  1
    "Study B"  0.2  0.1  0.3  15.0  1
    "Overall"  0.15 0.05 0.25 .     5
    end

    eplot es lci uci, labels(study) type(type) weights(weight)
    local cmd `"`r(cmd)'"'
    assert strpos(`"`cmd'"', "Boxes proportional") > 0
}
if _rc == 0 {
    display as result "  PASS: Test 13 - Auto-note with weights includes box text"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 13 - Auto-note with weights (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 13"
}

* =============================================================================
**# NEW FEATURE: favors() annotation
* =============================================================================

* Test 14: favors() in data mode
local ++test_count
capture noisily {
    clear
    input str20 study double(es lci uci)
    "Study A"  -0.5  -0.9  -0.1
    "Study B"   0.2  -0.1   0.5
    end

    eplot es lci uci, labels(study) favors("Favors Treatment" "Favors Control")
    local cmd `"`r(cmd)'"'
    assert strpos(`"`cmd'"', "text(") > 0
    assert strpos(`"`cmd'"', "Favors Treatment") > 0
    assert strpos(`"`cmd'"', "Favors Control") > 0
}
if _rc == 0 {
    display as result "  PASS: Test 14 - favors() in data mode"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 14 - favors() data mode (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 14"
}

* Test 15: favors() in estimates mode
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly regress price mpg weight
    eplot ., drop(_cons) favors("Lower Price" "Higher Price")
    local cmd `"`r(cmd)'"'
    assert strpos(`"`cmd'"', "text(") > 0
    assert strpos(`"`cmd'"', "Lower Price") > 0
    assert strpos(`"`cmd'"', "Higher Price") > 0
}
if _rc == 0 {
    display as result "  PASS: Test 15 - favors() in estimates mode"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 15 - favors() estimates mode (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 15"
}

* Test 16: favors() in matrix mode
local ++test_count
capture noisily {
    matrix R = (-0.5, -0.9, -0.1 \ 0.3, 0.1, 0.5)
    matrix rownames R = "Drug_A" "Drug_B"
    eplot, matrix(R) favors("Favors Drug" "Favors Placebo")
    local cmd `"`r(cmd)'"'
    assert strpos(`"`cmd'"', "text(") > 0
    assert strpos(`"`cmd'"', "Favors Drug") > 0
    assert strpos(`"`cmd'"', "Favors Placebo") > 0
}
if _rc == 0 {
    display as result "  PASS: Test 16 - favors() in matrix mode"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 16 - favors() matrix mode (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 16"
}

* =============================================================================
**# NEW FEATURE: Auto-detect effect label from e(cmd)
* =============================================================================

* Test 17: logit -> "Odds Ratio"
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly logit foreign price mpg
    eplot ., eform drop(_cons)
    local cmd `"`r(cmd)'"'
    assert strpos(`"`cmd'"', "Odds Ratio") > 0
}
if _rc == 0 {
    display as result "  PASS: Test 17 - Auto-detect: logit -> Odds Ratio"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 17 - Auto-detect logit (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 17"
}

* Test 18: poisson -> "IRR"
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly poisson rep78 price mpg
    eplot ., eform drop(_cons)
    local cmd `"`r(cmd)'"'
    assert strpos(`"`cmd'"', "IRR") > 0
}
if _rc == 0 {
    display as result "  PASS: Test 18 - Auto-detect: poisson -> IRR"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 18 - Auto-detect poisson (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 18"
}

* Test 19: regress without eform -> "Coefficient"
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly regress price mpg weight
    eplot ., drop(_cons)
    local cmd `"`r(cmd)'"'
    assert strpos(`"`cmd'"', "Coefficient") > 0
}
if _rc == 0 {
    display as result "  PASS: Test 19 - Auto-detect: regress -> Coefficient"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 19 - Auto-detect regress (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 19"
}

* Test 20: effect() overrides auto-detect
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly logit foreign price mpg
    eplot ., eform drop(_cons) effect("My Custom Label")
    local cmd `"`r(cmd)'"'
    assert strpos(`"`cmd'"', "My Custom Label") > 0
    assert strpos(`"`cmd'"', "Odds Ratio") == 0
}
if _rc == 0 {
    display as result "  PASS: Test 20 - effect() overrides auto-detect"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 20 - effect() override (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 20"
}

* =============================================================================
**# NEW FEATURE: Interaction term note
* =============================================================================

* Test 21: Interaction terms emit note (captured in return)
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly regress price c.mpg##c.weight
    eplot .
    * Command should succeed (interaction terms silently excluded)
    assert r(N) > 0
}
if _rc == 0 {
    display as result "  PASS: Test 21 - Interaction terms handled gracefully"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 21 - Interaction terms (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 21"
}

* =============================================================================
**# NEW FEATURE: r(pvalues) return vector
* =============================================================================

* Test 22: r(pvalues) returned in single-model estimates mode
local ++test_count
local t22_pass 1
capture noisily {
    sysuse auto, clear
    quietly regress price mpg weight
    eplot ., drop(_cons)
}
if _rc != 0 {
    display as error "  FAIL [22.run]: command returned error `=_rc'"
    local t22_pass 0
}
else {
    * Check r(pvalues) exists and has correct dimensions
    capture matrix P = r(pvalues)
    if _rc != 0 {
        display as error "  FAIL [22.exists]: r(pvalues) not returned"
        local t22_pass 0
    }
    else {
        local prows = rowsof(P)
        if `prows' == 2 {
            display as result "  PASS [22.dim]: r(pvalues) has 2 rows (mpg, weight)"
        }
        else {
            display as error "  FAIL [22.dim]: expected 2 rows, got `prows'"
            local t22_pass 0
        }
        * p-values should be in [0, 1]
        local pval1 = P[1,1]
        local pval2 = P[2,1]
        if `pval1' >= 0 & `pval1' <= 1 & `pval2' >= 0 & `pval2' <= 1 {
            display as result "  PASS [22.range]: p-values in [0,1]"
        }
        else {
            display as error "  FAIL [22.range]: p-values out of range: `pval1', `pval2'"
            local t22_pass 0
        }
    }
}
if `t22_pass' {
    local ++pass_count
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' 22"
}

* Test 23: Multi-model returns n_models > 1 and no pvalues
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly regress price mpg weight
    estimates store m1
    quietly regress price mpg weight headroom
    estimates store m2
    eplot m1 m2, drop(_cons)
    assert r(n_models) == 2
    assert r(N) > 0
}
if _rc == 0 {
    display as result "  PASS: Test 23 - Multi-model returns n_models=2"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 23 - Multi-model (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 23"
}
capture estimates drop m1 m2

* =============================================================================
**# NEW FEATURE: r(k) return scalar
* =============================================================================

* Test 24: r(k) in estimates mode
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly regress price mpg weight length
    eplot ., drop(_cons)
    assert r(k) == 3
}
if _rc == 0 {
    display as result "  PASS: Test 24 - r(k) == 3 in estimates mode"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 24 - r(k) estimates mode (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 24"
}

* Test 25: r(k) in data mode (excludes header/diamond rows)
local ++test_count
capture noisily {
    clear
    input str20 study double(es lci uci) byte type
    "Header"   .     .     .    0
    "Study 1"  0.1   0.0   0.2  1
    "Study 2"  0.2   0.1   0.3  1
    "Overall"  0.15  0.05  0.25 5
    end

    eplot es lci uci, labels(study) type(type)
    assert r(k) == 2
}
if _rc == 0 {
    display as result "  PASS: Test 25 - r(k) == 2 in data mode (excludes header/diamond)"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 25 - r(k) data mode (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 25"
}

* Test 26: r(k) in matrix mode
local ++test_count
capture noisily {
    matrix R = (1.5, 1.1, 2.0 \ 0.8, 0.6, 1.2 \ 1.0, 0.7, 1.3)
    matrix rownames R = "A" "B" "C"
    eplot, matrix(R)
    assert r(k) == 3
}
if _rc == 0 {
    display as result "  PASS: Test 26 - r(k) == 3 in matrix mode"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 26 - r(k) matrix mode (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 26"
}

* =============================================================================
**# NEW FEATURE: style(nejm) and style(bmj)
* =============================================================================

* Test 27: style(nejm) in estimates mode
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly regress price mpg weight
    eplot ., drop(_cons) style(nejm)
    assert r(N) > 0
}
if _rc == 0 {
    display as result "  PASS: Test 27 - style(nejm) in estimates mode"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 27 - style(nejm) (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 27"
}

* Test 28: style(bmj) in data mode
local ++test_count
capture noisily {
    clear
    input str20 study double(es lci uci)
    "Study A" -0.5 -0.9 -0.1
    "Study B"  0.2 -0.1  0.5
    end

    eplot es lci uci, labels(study) style(bmj)
    assert r(N) == 2
}
if _rc == 0 {
    display as result "  PASS: Test 28 - style(bmj) in data mode"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 28 - style(bmj) (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 28"
}

* Test 29: Invalid style still errors
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly regress price mpg
    eplot ., style(invalid_style)
}
if _rc == 198 {
    display as result "  PASS: Test 29 - Invalid style correctly errors (rc 198)"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 29 - Invalid style expected rc 198, got `=_rc'"
    local ++fail_count
    local failed_tests "`failed_tests' 29"
}

* =============================================================================
**# Data preservation
* =============================================================================

* Test 30: Data preserved after all new options
local ++test_count
capture noisily {
    sysuse auto, clear
    local N_before = _N
    local price1 = price[1]
    quietly logit foreign price mpg
    eplot ., eform stars drop(_cons) favors("FavorsTrt" "AgainstTrt")
    assert _N == `N_before'
    assert price[1] == `price1'
}
if _rc == 0 {
    display as result "  PASS: Test 30 - Data preserved after stars+eform+favors"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 30 - Data preservation (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 30"
}

* =============================================================================
**# Varabbrev restore
* =============================================================================

* Test 31: varabbrev restored after eplot with new features
local ++test_count
capture noisily {
    set varabbrev on
    sysuse auto, clear
    quietly regress price mpg weight
    eplot ., drop(_cons) stars favors("LeftDir" "RightDir")
    assert "`c(varabbrev)'" == "on"
}
if _rc == 0 {
    display as result "  PASS: Test 31 - varabbrev restored after new features"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 31 - varabbrev restore (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 31"
}

* Test 32: varabbrev restored after error with new features
local ++test_count
capture noisily {
    set varabbrev on
    capture noisily eplot ., style(nonexistent)
    assert "`c(varabbrev)'" == "on"
}
if _rc == 0 {
    display as result "  PASS: Test 32 - varabbrev restored after error"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 32 - varabbrev restore on error (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 32"
}

* =============================================================================
**# Matrix mode + keep/drop + stars interaction
* =============================================================================

* Test 33: Matrix mode stars correct after drop
local ++test_count
capture noisily {
    matrix R = (2.5, 0.5 \ 0.1, 0.8 \ 3.0, 0.3)
    matrix rownames R = "Keep1" "Drop1" "Keep2"
    eplot, matrix(R) drop(Drop1) stars values
    assert r(N) == 2
    assert r(k) == 2
}
if _rc == 0 {
    display as result "  PASS: Test 33 - Matrix mode stars + drop interaction"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 33 - Matrix stars+drop (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 33"
}

* =============================================================================
**# Summary
* =============================================================================

display _newline _dup(70) "="
display "TEST SUMMARY"
display _dup(70) "-"
display as text "Total:        `test_count'"
display as result "Passed:       `pass_count'"
if `fail_count' > 0 {
    display as error "Failed:       `fail_count'"
    display as error "Failed tests:`failed_tests'"
}
else {
    display as text "Failed:       `fail_count'"
}
display _dup(70) "="

if `fail_count' > 0 {
    display as error "Some tests FAILED. Review output above."
    exit 1
}
else {
    display as result "ALL TESTS PASSED!"
}

log close test_stars_matrix
