/*******************************************************************************
* validation_regtab.do
*
* Purpose: Deep validation of regtab Excel output using check_xlsx.py
*          Verifies structure, formatting, content, and edge cases
*
* Uses check_xlsx.py for automated Excel assertion checking in addition to
* Stata-side content verification via import excel.
*
* Author: Timothy P Copeland
* Date: 2026-02-24
*******************************************************************************/

clear all
set more off
version 17.0

* =============================================================================
* PATH CONFIGURATION
* =============================================================================
if "`c(os)'" == "MacOSX" {
    global STATA_TOOLS_PATH "/Users/tcopeland/Documents/GitHub/Stata-Tools"
}
else if "`c(os)'" == "Unix" {
    capture confirm file "_devkit/_testing"
    if _rc == 0 {
        global STATA_TOOLS_PATH "`c(pwd)'"
    }
    else {
        capture confirm file "_devkit/_testing/data"
        if _rc == 0 {
            global STATA_TOOLS_PATH "`c(pwd)'/.."
        }
        else {
            global STATA_TOOLS_PATH "/home/`c(username)'/Stata-Tools"
        }
    }
}
else {
    capture confirm file "../../_devkit/_testing"
    if _rc == 0 {
        * Running from <pkg>/qa/ directory
        global STATA_TOOLS_PATH "`c(pwd)'/../.."
    }
    else {
    capture confirm file "_devkit/_testing"
    if _rc == 0 {
        global STATA_TOOLS_PATH "`c(pwd)'"
    }
    else {
        global STATA_TOOLS_PATH "`c(pwd)'/.."
    }
    }
}

local testdir "${STATA_TOOLS_PATH}/_devkit/_testing/data"
local tooldir "${STATA_TOOLS_PATH}/_devkit/_testing/tools"

* Detect tabtools location (smart detection for qa/ subdirectory)
local init_pwd "`c(pwd)'"
capture confirm file "`init_pwd'/../tabtools.ado"
if _rc == 0 {
    local tabtools_path "`init_pwd'/.."
}
else {
    local tabtools_path "${STATA_TOOLS_PATH}/tabtools"
}
adopath ++ "`tabtools_path'"
run "`tabtools_path'/_tabtools_common.ado"

* Verify check_xlsx.py is available
capture confirm file "`tooldir'/check_xlsx.py"
if _rc {
    display as error "check_xlsx.py not found at: `tooldir'/check_xlsx.py"
    exit 601
}

* =============================================================================
* HEADER
* =============================================================================
display as text _newline _dup(70) "="
display as text "REGTAB DEEP VALIDATION (with check_xlsx.py)"
display as text _dup(70) "="

local test_count = 0
local pass_count = 0
local fail_count = 0

* =============================================================================
* SECTION 1: SINGLE MODEL — STRUCTURE AND FORMATTING
* =============================================================================
display as text _newline "SECTION 1: Single Model Structure and Formatting" _newline

* --- Test 1.1: Generate single-model regtab output ---
local ++test_count
display as text "Test 1.1: Generate single-model output"
capture {
    use "`testdir'/cohort.dta", clear
    gen outcome = !missing(edss4_dt)

    collect clear
    collect: logit outcome age female i.mstype

    capture erase "`testdir'/_val_regtab_single.xlsx"
    regtab, xlsx("`testdir'/_val_regtab_single.xlsx") sheet("Single") ///
        coef("OR") title("Table 1. Odds Ratios") noint

    confirm file "`testdir'/_val_regtab_single.xlsx"
}
if _rc == 0 {
    display as result "  PASS: Single-model output generated"
    local ++pass_count
}
else {
    display as error "  FAIL: Could not generate single-model output"
    local ++fail_count
}

* --- Test 1.2: Excel structure checks via check_xlsx.py ---
local ++test_count
display as text "Test 1.2: Excel structure (min rows, cols, borders)"
capture {
    ! python3 "`tooldir'/check_xlsx.py" "`testdir'/_val_regtab_single.xlsx" ///
        --sheet Single --min-rows 5 --min-cols 4 --max-cols 6 ///
        --has-borders --border-style thin ///
        --result-file "`testdir'/_check.txt"

    file open _fh using "`testdir'/_check.txt", read text
    file read _fh _line
    file close _fh
    capture erase "`testdir'/_check.txt"
    assert "`_line'" == "PASS"
}
if _rc == 0 {
    display as result "  PASS: Structure checks passed"
    local ++pass_count
}
else {
    display as error "  FAIL: Structure checks failed"
    local ++fail_count
}

* --- Test 1.3: Formatting — bold, merged, font ---
local ++test_count
display as text "Test 1.3: Formatting (bold, merged, font, fontsize)"
capture {
    ! python3 "`tooldir'/check_xlsx.py" "`testdir'/_val_regtab_single.xlsx" ///
        --sheet Single --bold-row 1 3 --merged-row 1 2 ///
        --font Arial --fontsize 10 ///
        --result-file "`testdir'/_check.txt"

    file open _fh using "`testdir'/_check.txt", read text
    file read _fh _line
    file close _fh
    capture erase "`testdir'/_check.txt"
    assert "`_line'" == "PASS"
}
if _rc == 0 {
    display as result "  PASS: Formatting checks passed"
    local ++pass_count
}
else {
    display as error "  FAIL: Formatting checks failed"
    local ++fail_count
}

* --- Test 1.4: Title cell value ---
local ++test_count
display as text "Test 1.4: Title cell content"
capture {
    ! python3 "`tooldir'/check_xlsx.py" "`testdir'/_val_regtab_single.xlsx" ///
        --sheet Single --cell A1 "Table 1. Odds Ratios" ///
        --result-file "`testdir'/_check.txt"

    file open _fh using "`testdir'/_check.txt", read text
    file read _fh _line
    file close _fh
    capture erase "`testdir'/_check.txt"
    assert "`_line'" == "PASS"
}
if _rc == 0 {
    display as result "  PASS: Title cell content correct"
    local ++pass_count
}
else {
    display as error "  FAIL: Title cell content incorrect"
    local ++fail_count
}

* --- Test 1.5: Content patterns (p-values, CIs, reference) ---
local ++test_count
display as text "Test 1.5: Content patterns"
capture {
    ! python3 "`tooldir'/check_xlsx.py" "`testdir'/_val_regtab_single.xlsx" ///
        --sheet Single --has-pattern p-values ci reference ///
        --result-file "`testdir'/_check.txt"

    file open _fh using "`testdir'/_check.txt", read text
    file read _fh _line
    file close _fh
    capture erase "`testdir'/_check.txt"
    assert "`_line'" == "PASS"
}
if _rc == 0 {
    display as result "  PASS: Content patterns detected"
    local ++pass_count
}
else {
    display as error "  FAIL: Content patterns not found"
    local ++fail_count
}

* =============================================================================
* SECTION 2: CONTENT ACCURACY VIA IMPORT EXCEL
* =============================================================================
display as text _newline "SECTION 2: Content Accuracy" _newline

* --- Test 2.1: Verify OR header label ---
local ++test_count
display as text "Test 2.1: OR header label present"
capture {
    ! python3 "`tooldir'/check_xlsx.py" "`testdir'/_val_regtab_single.xlsx" ///
        --sheet Single --header-row 3 OR ///
        --result-file "`testdir'/_check.txt"

    file open _fh using "`testdir'/_check.txt", read text
    file read _fh _line
    file close _fh
    capture erase "`testdir'/_check.txt"
    assert "`_line'" == "PASS"
}
if _rc == 0 {
    display as result "  PASS: OR header label present"
    local ++pass_count
}
else {
    display as error "  FAIL: OR header label missing"
    local ++fail_count
}

* --- Test 2.2: Verify data rows have values ---
local ++test_count
display as text "Test 2.2: Data rows contain values"
capture {
    import excel "`testdir'/_val_regtab_single.xlsx", sheet("Single") clear

    * Row 1 = title, row 2 = model header, row 3 = col labels, row 4+ = data
    * Column B = variable names, column C = point estimates
    * Check that data rows have content
    count
    assert r(N) >= 5

    * Check that column B has variable names in data rows
    assert B[4] != ""
    assert B[5] != ""
}
if _rc == 0 {
    display as result "  PASS: Data rows have values"
    local ++pass_count
}
else {
    display as error "  FAIL: Data rows missing values"
    local ++fail_count
}

* --- Test 2.3: Verify point estimates match logit output ---
local ++test_count
display as text "Test 2.3: Point estimates match model"
capture {
    * Re-run the model to get known coefficients
    use "`testdir'/cohort.dta", clear
    gen outcome = !missing(edss4_dt)
    logit outcome age female i.mstype
    matrix b = e(b)
    * regtab displays the raw coefficient (formatted to 2dp), not exp(coef)
    * The coef("OR") option only sets the column header label
    local coef_age = b[1,1]
    local coef_age_str = string(round(`coef_age', 0.01), "%9.2f")

    * Import the Excel output
    import excel "`testdir'/_val_regtab_single.xlsx", sheet("Single") clear

    * Find the age row and verify the coefficient value matches
    local found = 0
    forvalues i = 4/`=_N' {
        if regexm(strlower(strtrim(B[`i'])), "age") {
            local excel_val = strtrim(C[`i'])
            assert "`excel_val'" == "`coef_age_str'"
            local found = 1
        }
    }
    assert `found' == 1
}
if _rc == 0 {
    display as result "  PASS: Point estimates match model output"
    local ++pass_count
}
else {
    display as error "  FAIL: Point estimates do not match"
    local ++fail_count
}

* =============================================================================
* SECTION 3: MULTI-MODEL TABLE
* =============================================================================
display as text _newline "SECTION 3: Multi-Model Table" _newline

* --- Test 3.1: Generate multi-model output ---
local ++test_count
display as text "Test 3.1: Multi-model generation"
capture {
    use "`testdir'/cohort.dta", clear
    gen outcome = !missing(edss4_dt)

    collect clear
    collect: logit outcome age female
    collect: logit outcome age female i.mstype
    collect: logit outcome age female i.mstype bmi

    capture erase "`testdir'/_val_regtab_multi.xlsx"
    regtab, xlsx("`testdir'/_val_regtab_multi.xlsx") sheet("Multi") ///
        coef("OR") models("Crude \ Adjusted \ Full") ///
        title("Table 2. Progressive Adjustment") noint

    confirm file "`testdir'/_val_regtab_multi.xlsx"
}
if _rc == 0 {
    display as result "  PASS: Multi-model output generated"
    local ++pass_count
}
else {
    display as error "  FAIL: Multi-model output failed"
    local ++fail_count
}

* --- Test 3.2: Multi-model structure (3 cols per model + label col) ---
local ++test_count
display as text "Test 3.2: Multi-model column structure"
capture {
    * 3 models x 3 cols (OR, CI, p) + 1 title col + 1 label col = 11
    ! python3 "`tooldir'/check_xlsx.py" "`testdir'/_val_regtab_multi.xlsx" ///
        --sheet Multi --min-cols 10 --min-rows 5 ///
        --bold-row 1 3 --merged-row 1 2 --has-borders ///
        --result-file "`testdir'/_check.txt"

    file open _fh using "`testdir'/_check.txt", read text
    file read _fh _line
    file close _fh
    capture erase "`testdir'/_check.txt"
    assert "`_line'" == "PASS"
}
if _rc == 0 {
    display as result "  PASS: Multi-model structure correct"
    local ++pass_count
}
else {
    display as error "  FAIL: Multi-model structure incorrect"
    local ++fail_count
}

* --- Test 3.3: Model labels present in header ---
local ++test_count
display as text "Test 3.3: Model labels in header"
capture {
    ! python3 "`tooldir'/check_xlsx.py" "`testdir'/_val_regtab_multi.xlsx" ///
        --sheet Multi --header-row 2 Crude Adjusted Full ///
        --result-file "`testdir'/_check.txt"

    file open _fh using "`testdir'/_check.txt", read text
    file read _fh _line
    file close _fh
    capture erase "`testdir'/_check.txt"
    assert "`_line'" == "PASS"
}
if _rc == 0 {
    display as result "  PASS: Model labels present"
    local ++pass_count
}
else {
    display as error "  FAIL: Model labels missing"
    local ++fail_count
}

* =============================================================================
* SECTION 4: SPECIAL OPTIONS
* =============================================================================
display as text _newline "SECTION 4: Special Options" _newline

* --- Test 4.1: Stats option (N, AIC) ---
local ++test_count
display as text "Test 4.1: Stats option adds summary rows"
capture {
    use "`testdir'/cohort.dta", clear
    gen outcome = !missing(edss4_dt)

    collect clear
    collect: logit outcome age female i.mstype

    capture erase "`testdir'/_val_regtab_stats.xlsx"
    regtab, xlsx("`testdir'/_val_regtab_stats.xlsx") sheet("Stats") ///
        coef("OR") title("With Statistics") noint stats(n aic bic)

    * Import and verify stats rows exist
    import excel "`testdir'/_val_regtab_stats.xlsx", sheet("Stats") clear
    count
    local total_rows = r(N)

    * Check that "Observations" label exists in the output
    local found_obs = 0
    forvalues i = 1/`total_rows' {
        if strtrim(B[`i']) == "Observations" {
            local found_obs = 1
        }
    }
    assert `found_obs' == 1
}
if _rc == 0 {
    display as result "  PASS: Stats option adds observation count"
    local ++pass_count
}
else {
    display as error "  FAIL: Stats option failed"
    local ++fail_count
}

* --- Test 4.2: Custom CI separator ---
local ++test_count
display as text "Test 4.2: Custom CI separator"
capture {
    use "`testdir'/cohort.dta", clear
    gen outcome = !missing(edss4_dt)

    collect clear
    collect: logit outcome age female i.mstype

    capture erase "`testdir'/_val_regtab_sep.xlsx"
    regtab, xlsx("`testdir'/_val_regtab_sep.xlsx") sheet("Sep") ///
        coef("OR") noint sep("; ")

    * Import and check CI format uses semicolon
    import excel "`testdir'/_val_regtab_sep.xlsx", sheet("Sep") clear
    local found_semi = 0
    forvalues i = 4/`=_N' {
        if strpos(D[`i'], ";") > 0 {
            local found_semi = 1
        }
    }
    assert `found_semi' == 1
}
if _rc == 0 {
    display as result "  PASS: Custom separator works"
    local ++pass_count
}
else {
    display as error "  FAIL: Custom separator failed"
    local ++fail_count
}

* =============================================================================
* SECTION 5: EDGE CASES
* =============================================================================
display as text _newline "SECTION 5: Edge Cases" _newline

* --- Test 5.1: Cox regression (HR) ---
local ++test_count
display as text "Test 5.1: Cox regression output"
capture {
    use "`testdir'/cohort.dta", clear
    gen double follow_time = study_exit - study_entry
    gen event = !missing(edss4_dt) & edss4_dt <= study_exit
    replace follow_time = edss4_dt - study_entry if event == 1
    keep if follow_time > 0
    stset follow_time, failure(event)

    collect clear
    collect: stcox age female i.mstype

    capture erase "`testdir'/_val_regtab_cox.xlsx"
    regtab, xlsx("`testdir'/_val_regtab_cox.xlsx") sheet("Cox") ///
        coef("HR") title("Table. Hazard Ratios")

    * Verify structure
    ! python3 "`tooldir'/check_xlsx.py" "`testdir'/_val_regtab_cox.xlsx" ///
        --sheet Cox --min-rows 4 --min-cols 4 ///
        --bold-row 1 3 --has-borders --font Arial ///
        --result-file "`testdir'/_check.txt"

    file open _fh using "`testdir'/_check.txt", read text
    file read _fh _line
    file close _fh
    capture erase "`testdir'/_check.txt"
    assert "`_line'" == "PASS"
}
if _rc == 0 {
    display as result "  PASS: Cox regression output validated"
    local ++pass_count
}
else {
    display as error "  FAIL: Cox regression output failed"
    local ++fail_count
}

* --- Test 5.2: Linear regression with no intercept ---
local ++test_count
display as text "Test 5.2: Linear regression (noint)"
capture {
    use "`testdir'/cohort.dta", clear

    collect clear
    collect: regress bmi age female i.mstype

    capture erase "`testdir'/_val_regtab_linear.xlsx"
    regtab, xlsx("`testdir'/_val_regtab_linear.xlsx") sheet("Linear") ///
        coef("Coef.") noint

    * Verify no intercept row
    import excel "`testdir'/_val_regtab_linear.xlsx", sheet("Linear") clear
    local found_cons = 0
    forvalues i = 1/`=_N' {
        if inlist(strlower(strtrim(B[`i'])), "_cons", "intercept", "constant") {
            local found_cons = 1
        }
    }
    assert `found_cons' == 0
}
if _rc == 0 {
    display as result "  PASS: Linear regression noint validated"
    local ++pass_count
}
else {
    display as error "  FAIL: Linear regression noint failed"
    local ++fail_count
}

* --- Test 5.3: No title option ---
local ++test_count
display as text "Test 5.3: Output without title"
capture {
    use "`testdir'/cohort.dta", clear
    gen outcome = !missing(edss4_dt)

    collect clear
    collect: logit outcome age female

    capture erase "`testdir'/_val_regtab_notitle.xlsx"
    regtab, xlsx("`testdir'/_val_regtab_notitle.xlsx") sheet("NoTitle") ///
        coef("OR") noint

    * Verify file exists and has reasonable structure
    ! python3 "`tooldir'/check_xlsx.py" "`testdir'/_val_regtab_notitle.xlsx" ///
        --sheet NoTitle --min-rows 3 --min-cols 4 --has-borders ///
        --result-file "`testdir'/_check.txt"

    file open _fh using "`testdir'/_check.txt", read text
    file read _fh _line
    file close _fh
    capture erase "`testdir'/_check.txt"
    assert "`_line'" == "PASS"
}
if _rc == 0 {
    display as result "  PASS: No-title output validated"
    local ++pass_count
}
else {
    display as error "  FAIL: No-title output failed"
    local ++fail_count
}

* =============================================================================
* SECTION 6: ERROR HANDLING
* =============================================================================
display as text _newline "SECTION 6: Error Handling" _newline

* --- Test 6.1: Missing .xlsx extension ---
local ++test_count
display as text "Test 6.1: Missing .xlsx extension rejected"
capture {
    use "`testdir'/cohort.dta", clear
    gen outcome = !missing(edss4_dt)

    collect clear
    collect: logit outcome age female

    capture noisily regtab, xlsx("`testdir'/bad_file.csv") sheet("Test") coef("OR")
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: Missing .xlsx extension rejected"
    local ++pass_count
}
else {
    display as error "  FAIL: Missing .xlsx extension not caught"
    local ++fail_count
}

* --- Test 6.2: No collect table ---
local ++test_count
display as text "Test 6.2: No collect table error"
capture {
    clear
    collect clear
    capture noisily regtab, xlsx("`testdir'/_val_empty.xlsx") sheet("T") coef("OR")
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: No collect table caught"
    local ++pass_count
}
else {
    display as error "  FAIL: No collect table not caught"
    local ++fail_count
}

* =============================================================================
* CLEANUP
* =============================================================================
display as text _newline _dup(70) "="
display as text "Cleaning up validation files..."
display as text _dup(70) "="

local cleanup_files "_val_regtab_single _val_regtab_multi _val_regtab_stats _val_regtab_sep _val_regtab_cox _val_regtab_linear _val_regtab_notitle"
foreach f of local cleanup_files {
    capture erase "`testdir'/`f'.xlsx"
}
capture erase "`testdir'/_check.txt"

* =============================================================================
* SUMMARY
* =============================================================================
display as text _newline _dup(70) "="
display as text "REGTAB DEEP VALIDATION SUMMARY"
display as text _dup(70) "="
display as text "Total tests:  `test_count'"
display as result "Passed:       `pass_count'"
if `fail_count' > 0 {
    display as error "Failed:       `fail_count'"
}
else {
    display as text "Failed:       `fail_count'"
}
display as text _dup(70) "="

if `fail_count' > 0 {
    display as error "Some tests FAILED. Review output above."
    exit 1
}
else {
    display as result "All validation tests PASSED!"
}
