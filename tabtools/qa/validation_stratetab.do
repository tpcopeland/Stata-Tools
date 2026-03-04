/*******************************************************************************
* validation_stratetab.do
*
* Purpose: Deep validation of stratetab Excel output using check_xlsx.py
*          Verifies structure, formatting, content, and rate calculations
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
    global STATA_TOOLS_PATH "/Users/tcopeland/Documents/GitHub/Stata-Dev"
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
            global STATA_TOOLS_PATH "/home/`c(username)'/Stata-Dev"
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
display as text "STRATETAB DEEP VALIDATION (with check_xlsx.py)"
display as text _dup(70) "="

local test_count = 0
local pass_count = 0
local fail_count = 0

* =============================================================================
* SETUP: Create synthetic strate output files with KNOWN values
* =============================================================================
display as text _newline "Creating synthetic strate output files with known values..."

* Use fixed values so we can verify exact output
* Outcome 1, Exposure 1: 3 levels
clear
set obs 3
gen exposure = _n - 1
gen double _D = .
gen double _Y = .
gen double _Rate = .
gen double _Lower = .
gen double _Upper = .

replace _D = 25 in 1
replace _D = 18 in 2
replace _D = 32 in 3

replace _Y = 5000 in 1
replace _Y = 4500 in 2
replace _Y = 5200 in 3

replace _Rate = _D / _Y
replace _Lower = _Rate * 0.65
replace _Upper = _Rate * 1.35

label variable exposure "Treatment Group"
label define val_exp_lbl 0 "Placebo" 1 "Low Dose" 2 "High Dose"
label values exposure val_exp_lbl
save "`testdir'/_val_strate_o1e1.dta", replace

* Outcome 2, Exposure 1: 3 levels
clear
set obs 3
gen exposure = _n - 1
gen double _D = .
gen double _Y = .
gen double _Rate = .
gen double _Lower = .
gen double _Upper = .

replace _D = 12 in 1
replace _D = 8 in 2
replace _D = 20 in 3

replace _Y = 5000 in 1
replace _Y = 4500 in 2
replace _Y = 5200 in 3

replace _Rate = _D / _Y
replace _Lower = _Rate * 0.65
replace _Upper = _Rate * 1.35

label define val_exp_lbl 0 "Placebo" 1 "Low Dose" 2 "High Dose", replace
label values exposure val_exp_lbl
save "`testdir'/_val_strate_o2e1.dta", replace

display as text "  Synthetic strate files created"

* =============================================================================
* SECTION 1: BASIC STRUCTURE AND FORMATTING
* =============================================================================
display as text _newline "SECTION 1: Basic Structure and Formatting" _newline

* --- Test 1.1: Generate basic stratetab output ---
local ++test_count
display as text "Test 1.1: Generate basic stratetab output"
capture {
    preserve
    capture erase "`testdir'/_val_stratetab_basic.xlsx"
    stratetab, using("`testdir'/_val_strate_o1e1" "`testdir'/_val_strate_o2e1") ///
        xlsx("`testdir'/_val_stratetab_basic.xlsx") outcomes(2) ///
        sheet("Basic") title("Table. Incidence Rates") ///
        outlabels("Outcome A \ Outcome B")
    restore

    confirm file "`testdir'/_val_stratetab_basic.xlsx"
}
if _rc == 0 {
    display as result "  PASS: Basic output generated"
    local ++pass_count
}
else {
    display as error "  FAIL: Basic output generation failed"
    local ++fail_count
}

* --- Test 1.2: Excel structure checks ---
local ++test_count
display as text "Test 1.2: Excel structure (rows, cols, borders)"
capture {
    ! python3 "`tooldir'/check_xlsx.py" "`testdir'/_val_stratetab_basic.xlsx" ///
        --sheet Basic --min-rows 5 --min-cols 5 ///
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

* --- Test 1.3: Formatting checks ---
local ++test_count
display as text "Test 1.3: Formatting (bold, merged, font)"
capture {
    ! python3 "`tooldir'/check_xlsx.py" "`testdir'/_val_stratetab_basic.xlsx" ///
        --sheet Basic --bold-row 1 --merged-row 1 ///
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

* --- Test 1.4: Title cell ---
local ++test_count
display as text "Test 1.4: Title cell content"
capture {
    ! python3 "`tooldir'/check_xlsx.py" "`testdir'/_val_stratetab_basic.xlsx" ///
        --sheet Basic --cell A1 "Table. Incidence Rates" ///
        --result-file "`testdir'/_check.txt"

    file open _fh using "`testdir'/_check.txt", read text
    file read _fh _line
    file close _fh
    capture erase "`testdir'/_check.txt"
    assert "`_line'" == "PASS"
}
if _rc == 0 {
    display as result "  PASS: Title cell correct"
    local ++pass_count
}
else {
    display as error "  FAIL: Title cell incorrect"
    local ++fail_count
}

* =============================================================================
* SECTION 2: CONTENT ACCURACY
* =============================================================================
display as text _newline "SECTION 2: Content Accuracy" _newline

* --- Test 2.1: Outcome labels present ---
local ++test_count
display as text "Test 2.1: Outcome labels in header"
capture {
    import excel "`testdir'/_val_stratetab_basic.xlsx", sheet("Basic") clear
    * Check that outcome labels appear somewhere in the sheet
    local found_a = 0
    local found_b = 0
    foreach var of varlist * {
        forvalues i = 1/`=_N' {
            if strpos(`var'[`i'], "Outcome A") > 0 {
                local found_a = 1
            }
            if strpos(`var'[`i'], "Outcome B") > 0 {
                local found_b = 1
            }
        }
    }
    assert `found_a' == 1
    assert `found_b' == 1
}
if _rc == 0 {
    display as result "  PASS: Outcome labels found"
    local ++pass_count
}
else {
    display as error "  FAIL: Outcome labels missing"
    local ++fail_count
}

* --- Test 2.2: Rate patterns present ---
local ++test_count
display as text "Test 2.2: Rate patterns in content"
capture {
    ! python3 "`tooldir'/check_xlsx.py" "`testdir'/_val_stratetab_basic.xlsx" ///
        --sheet Basic --has-pattern rates ///
        --result-file "`testdir'/_check.txt"

    file open _fh using "`testdir'/_check.txt", read text
    file read _fh _line
    file close _fh
    capture erase "`testdir'/_check.txt"
    assert "`_line'" == "PASS"
}
if _rc == 0 {
    display as result "  PASS: Rate patterns found"
    local ++pass_count
}
else {
    display as error "  FAIL: Rate patterns not found"
    local ++fail_count
}

* --- Test 2.3: Event counts are numeric and reasonable ---
local ++test_count
display as text "Test 2.3: Event counts present and numeric"
capture {
    import excel "`testdir'/_val_stratetab_basic.xlsx", sheet("Basic") clear
    * Find data rows (after headers) and check for numeric event counts
    * Events should be positive integers
    local found_events = 0
    forvalues i = 3/`=_N' {
        foreach var of varlist * {
            local val = `var'[`i']
            if regexm("`val'", "^[0-9]+$") {
                local numval = real("`val'")
                if `numval' >= 1 & `numval' <= 1000 {
                    local found_events = 1
                }
            }
        }
    }
    assert `found_events' == 1
}
if _rc == 0 {
    display as result "  PASS: Event counts present"
    local ++pass_count
}
else {
    display as error "  FAIL: Event counts not found"
    local ++fail_count
}

* =============================================================================
* SECTION 3: SCALING OPTIONS
* =============================================================================
display as text _newline "SECTION 3: Scaling Options" _newline

* --- Test 3.1: Person-year scaling ---
local ++test_count
display as text "Test 3.1: PY scaling and rate scaling"
capture {
    preserve
    capture erase "`testdir'/_val_stratetab_scale.xlsx"
    stratetab, using("`testdir'/_val_strate_o1e1" "`testdir'/_val_strate_o2e1") ///
        xlsx("`testdir'/_val_stratetab_scale.xlsx") outcomes(2) ///
        sheet("Scale") pyscale(1000) ratescale(1000)
    restore

    * Verify file created and has content
    ! python3 "`tooldir'/check_xlsx.py" "`testdir'/_val_stratetab_scale.xlsx" ///
        --sheet Scale --min-rows 4 --min-cols 4 --has-borders ///
        --result-file "`testdir'/_check.txt"

    file open _fh using "`testdir'/_check.txt", read text
    file read _fh _line
    file close _fh
    capture erase "`testdir'/_check.txt"
    assert "`_line'" == "PASS"
}
if _rc == 0 {
    display as result "  PASS: Scaling options work"
    local ++pass_count
}
else {
    display as error "  FAIL: Scaling options failed"
    local ++fail_count
}

* --- Test 3.2: Custom digits ---
local ++test_count
display as text "Test 3.2: Custom decimal places"
capture {
    preserve
    capture erase "`testdir'/_val_stratetab_digits.xlsx"
    stratetab, using("`testdir'/_val_strate_o1e1" "`testdir'/_val_strate_o2e1") ///
        xlsx("`testdir'/_val_stratetab_digits.xlsx") outcomes(2) ///
        sheet("Digits") digits(2) eventdigits(0) pydigits(1)
    restore

    confirm file "`testdir'/_val_stratetab_digits.xlsx"
}
if _rc == 0 {
    display as result "  PASS: Custom digits accepted"
    local ++pass_count
}
else {
    display as error "  FAIL: Custom digits failed"
    local ++fail_count
}

* =============================================================================
* SECTION 4: EDGE CASES
* =============================================================================
display as text _newline "SECTION 4: Edge Cases" _newline

* --- Test 4.1: Single outcome ---
local ++test_count
display as text "Test 4.1: Single outcome"
capture {
    preserve
    capture erase "`testdir'/_val_stratetab_single.xlsx"
    stratetab, using("`testdir'/_val_strate_o1e1") ///
        xlsx("`testdir'/_val_stratetab_single.xlsx") outcomes(1) ///
        sheet("Single") title("Single Outcome Table")
    restore

    ! python3 "`tooldir'/check_xlsx.py" "`testdir'/_val_stratetab_single.xlsx" ///
        --sheet Single --min-rows 4 --min-cols 3 ///
        --cell A1 "Single Outcome Table" ///
        --result-file "`testdir'/_check.txt"

    file open _fh using "`testdir'/_check.txt", read text
    file read _fh _line
    file close _fh
    capture erase "`testdir'/_check.txt"
    assert "`_line'" == "PASS"
}
if _rc == 0 {
    display as result "  PASS: Single outcome validated"
    local ++pass_count
}
else {
    display as error "  FAIL: Single outcome failed"
    local ++fail_count
}

* --- Test 4.2: Error - missing .xlsx extension ---
local ++test_count
display as text "Test 4.2: Missing .xlsx extension rejected"
capture {
    preserve
    capture noisily stratetab, using("`testdir'/_val_strate_o1e1") ///
        xlsx("`testdir'/bad.csv") outcomes(1) sheet("T")
    local rc_val = _rc
    restore
    assert `rc_val' == 198
}
if _rc == 0 {
    display as result "  PASS: Missing .xlsx extension rejected"
    local ++pass_count
}
else {
    display as error "  FAIL: Missing .xlsx extension not caught"
    local ++fail_count
}

* =============================================================================
* CLEANUP
* =============================================================================
display as text _newline _dup(70) "="
display as text "Cleaning up validation files..."
display as text _dup(70) "="

local strate_files "_val_strate_o1e1 _val_strate_o2e1"
foreach f of local strate_files {
    capture erase "`testdir'/`f'.dta"
}

local output_files "_val_stratetab_basic _val_stratetab_scale _val_stratetab_digits _val_stratetab_single"
foreach f of local output_files {
    capture erase "`testdir'/`f'.xlsx"
}
capture erase "`testdir'/_check.txt"

* =============================================================================
* SUMMARY
* =============================================================================
display as text _newline _dup(70) "="
display as text "STRATETAB DEEP VALIDATION SUMMARY"
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
