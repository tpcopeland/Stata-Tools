/*******************************************************************************
* validation_tablex.do
*
* Purpose: Deep validation of tablex Excel output using check_xlsx.py
*          Verifies structure, formatting, content, and custom options
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

* Add tabtools package to adopath
adopath ++ "${STATA_TOOLS_PATH}/tabtools"
run "${STATA_TOOLS_PATH}/tabtools/_tabtools_common.ado"

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
display as text "TABLEX DEEP VALIDATION (with check_xlsx.py)"
display as text _dup(70) "="

local test_count = 0
local pass_count = 0
local fail_count = 0

* =============================================================================
* SECTION 1: BASIC FREQUENCY TABLE
* =============================================================================
display as text _newline "SECTION 1: Basic Frequency Table" _newline

* --- Test 1.1: Generate frequency table ---
local ++test_count
display as text "Test 1.1: Generate frequency table"
capture {
    sysuse auto, clear

    table foreign rep78

    capture erase "`testdir'/_val_tablex_freq.xlsx"
    tablex using "`testdir'/_val_tablex_freq.xlsx", ///
        sheet("Frequencies") title("Table 1. Car Frequency") replace

    confirm file "`testdir'/_val_tablex_freq.xlsx"
}
if _rc == 0 {
    display as result "  PASS: Frequency table generated"
    local ++pass_count
}
else {
    display as error "  FAIL: Frequency table failed"
    local ++fail_count
}

* --- Test 1.2: Structure checks ---
local ++test_count
display as text "Test 1.2: Frequency table structure"
capture {
    ! python3 "`tooldir'/check_xlsx.py" "`testdir'/_val_tablex_freq.xlsx" ///
        --sheet Frequencies --min-rows 4 --min-cols 3 ///
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

* --- Test 1.3: Formatting ---
local ++test_count
display as text "Test 1.3: Default formatting (bold, merged, font)"
capture {
    ! python3 "`tooldir'/check_xlsx.py" "`testdir'/_val_tablex_freq.xlsx" ///
        --sheet Frequencies --bold-row 1 --merged-row 1 ///
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

* --- Test 1.4: Title ---
local ++test_count
display as text "Test 1.4: Title cell content"
capture {
    ! python3 "`tooldir'/check_xlsx.py" "`testdir'/_val_tablex_freq.xlsx" ///
        --sheet Frequencies --cell A1 "Table 1. Car Frequency" ///
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
* SECTION 2: SUMMARY STATISTICS TABLE
* =============================================================================
display as text _newline "SECTION 2: Summary Statistics Table" _newline

* --- Test 2.1: Generate summary table ---
local ++test_count
display as text "Test 2.1: Generate summary statistics table"
capture {
    sysuse auto, clear

    table foreign, statistic(mean price mpg weight) statistic(sd price mpg weight)

    capture erase "`testdir'/_val_tablex_summary.xlsx"
    tablex using "`testdir'/_val_tablex_summary.xlsx", ///
        sheet("Summary") title("Table 2. Summary by Origin") replace

    confirm file "`testdir'/_val_tablex_summary.xlsx"
}
if _rc == 0 {
    display as result "  PASS: Summary table generated"
    local ++pass_count
}
else {
    display as error "  FAIL: Summary table failed"
    local ++fail_count
}

* --- Test 2.2: Summary table structure ---
local ++test_count
display as text "Test 2.2: Summary table structure"
capture {
    ! python3 "`tooldir'/check_xlsx.py" "`testdir'/_val_tablex_summary.xlsx" ///
        --sheet Summary --min-rows 5 --min-cols 3 ///
        --has-borders --bold-row 1 ///
        --result-file "`testdir'/_check.txt"

    file open _fh using "`testdir'/_check.txt", read text
    file read _fh _line
    file close _fh
    capture erase "`testdir'/_check.txt"
    assert "`_line'" == "PASS"
}
if _rc == 0 {
    display as result "  PASS: Summary structure validated"
    local ++pass_count
}
else {
    display as error "  FAIL: Summary structure failed"
    local ++fail_count
}

* --- Test 2.3: Content accuracy - verify known values ---
local ++test_count
display as text "Test 2.3: Summary content matches known auto.dta values"
capture {
    * Calculate expected values
    sysuse auto, clear
    summarize price if foreign == 0, meanonly
    local mean_dom = r(mean)

    * Import Excel and find the value
    import excel "`testdir'/_val_tablex_summary.xlsx", sheet("Summary") clear
    * tablex exports full-precision numbers; verify by converting to real
    local found = 0
    foreach var of varlist * {
        forvalues i = 1/`=_N' {
            local val = `var'[`i']
            local numval = real("`val'")
            if !missing(`numval') {
                if abs(`numval' - `mean_dom') < 0.01 {
                    local found = 1
                }
            }
        }
    }
    assert `found' == 1
}
if _rc == 0 {
    display as result "  PASS: Content matches known values"
    local ++pass_count
}
else {
    display as error "  FAIL: Content does not match"
    local ++fail_count
}

* =============================================================================
* SECTION 3: CUSTOM FORMATTING OPTIONS
* =============================================================================
display as text _newline "SECTION 3: Custom Formatting Options" _newline

* --- Test 3.1: Custom font (Calibri) ---
local ++test_count
display as text "Test 3.1: Custom font (Calibri 11pt)"
capture {
    sysuse auto, clear
    table foreign, statistic(mean price)

    capture erase "`testdir'/_val_tablex_calibri.xlsx"
    tablex using "`testdir'/_val_tablex_calibri.xlsx", ///
        sheet("Custom") title("Custom Font") ///
        font(Calibri) fontsize(11) replace

    ! python3 "`tooldir'/check_xlsx.py" "`testdir'/_val_tablex_calibri.xlsx" ///
        --sheet Custom --font Calibri --fontsize 11 ///
        --result-file "`testdir'/_check.txt"

    file open _fh using "`testdir'/_check.txt", read text
    file read _fh _line
    file close _fh
    capture erase "`testdir'/_check.txt"
    assert "`_line'" == "PASS"
}
if _rc == 0 {
    display as result "  PASS: Custom font applied"
    local ++pass_count
}
else {
    display as error "  FAIL: Custom font not applied"
    local ++fail_count
}

* --- Test 3.2: Medium border style ---
local ++test_count
display as text "Test 3.2: Medium border style"
capture {
    sysuse auto, clear
    table foreign, statistic(mean price)

    capture erase "`testdir'/_val_tablex_medium.xlsx"
    tablex using "`testdir'/_val_tablex_medium.xlsx", ///
        sheet("Borders") title("Medium Borders") ///
        borderstyle(medium) replace

    ! python3 "`tooldir'/check_xlsx.py" "`testdir'/_val_tablex_medium.xlsx" ///
        --sheet Borders --has-borders --border-style medium ///
        --result-file "`testdir'/_check.txt"

    file open _fh using "`testdir'/_check.txt", read text
    file read _fh _line
    file close _fh
    capture erase "`testdir'/_check.txt"
    assert "`_line'" == "PASS"
}
if _rc == 0 {
    display as result "  PASS: Medium border style applied"
    local ++pass_count
}
else {
    display as error "  FAIL: Medium border style not applied"
    local ++fail_count
}

* =============================================================================
* SECTION 4: CROSS-TABULATION
* =============================================================================
display as text _newline "SECTION 4: Cross-Tabulation with Statistics" _newline

* --- Test 4.1: Frequency + percent cross-tab ---
local ++test_count
display as text "Test 4.1: Cross-tabulation with frequency and percent"
capture {
    sysuse auto, clear

    table foreign rep78, statistic(frequency) statistic(percent)

    capture erase "`testdir'/_val_tablex_cross.xlsx"
    tablex using "`testdir'/_val_tablex_cross.xlsx", ///
        sheet("CrossTab") title("Cross-Tabulation") replace

    ! python3 "`tooldir'/check_xlsx.py" "`testdir'/_val_tablex_cross.xlsx" ///
        --sheet CrossTab --min-rows 4 --min-cols 3 ///
        --has-borders --bold-row 1 --merged-row 1 ///
        --result-file "`testdir'/_check.txt"

    file open _fh using "`testdir'/_check.txt", read text
    file read _fh _line
    file close _fh
    capture erase "`testdir'/_check.txt"
    assert "`_line'" == "PASS"
}
if _rc == 0 {
    display as result "  PASS: Cross-tab validated"
    local ++pass_count
}
else {
    display as error "  FAIL: Cross-tab failed"
    local ++fail_count
}

* =============================================================================
* SECTION 5: NO TITLE
* =============================================================================
display as text _newline "SECTION 5: No Title Output" _newline

* --- Test 5.1: Table without title ---
local ++test_count
display as text "Test 5.1: Table without title"
capture {
    sysuse auto, clear
    table foreign, statistic(mean price mpg)

    capture erase "`testdir'/_val_tablex_notitle.xlsx"
    tablex using "`testdir'/_val_tablex_notitle.xlsx", ///
        sheet("NoTitle") replace

    * Should still have structure and borders, but row 1 is data header
    ! python3 "`tooldir'/check_xlsx.py" "`testdir'/_val_tablex_notitle.xlsx" ///
        --sheet NoTitle --min-rows 3 --min-cols 2 ///
        --has-borders ///
        --result-file "`testdir'/_check.txt"

    file open _fh using "`testdir'/_check.txt", read text
    file read _fh _line
    file close _fh
    capture erase "`testdir'/_check.txt"
    assert "`_line'" == "PASS"
}
if _rc == 0 {
    display as result "  PASS: No-title table validated"
    local ++pass_count
}
else {
    display as error "  FAIL: No-title table failed"
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
    sysuse auto, clear
    table foreign, statistic(mean price)

    capture noisily tablex using "`testdir'/bad.csv", sheet("T") replace
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: Missing extension rejected"
    local ++pass_count
}
else {
    display as error "  FAIL: Missing extension not caught"
    local ++fail_count
}

* --- Test 6.2: Invalid fontsize range ---
local ++test_count
display as text "Test 6.2: Invalid fontsize rejected"
capture {
    sysuse auto, clear
    table foreign, statistic(mean price)

    capture noisily tablex using "`testdir'/_val_empty.xlsx", ///
        sheet("T") fontsize(2) replace
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: Invalid fontsize rejected"
    local ++pass_count
}
else {
    display as error "  FAIL: Invalid fontsize not caught"
    local ++fail_count
}

* --- Test 6.3: Invalid border style ---
local ++test_count
display as text "Test 6.3: Invalid border style rejected"
capture {
    sysuse auto, clear
    table foreign, statistic(mean price)

    capture noisily tablex using "`testdir'/_val_empty.xlsx", ///
        sheet("T") borderstyle(thick) replace
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: Invalid border style rejected"
    local ++pass_count
}
else {
    display as error "  FAIL: Invalid border style not caught"
    local ++fail_count
}

* =============================================================================
* CLEANUP
* =============================================================================
display as text _newline _dup(70) "="
display as text "Cleaning up validation files..."
display as text _dup(70) "="

local output_files "_val_tablex_freq _val_tablex_summary _val_tablex_calibri _val_tablex_medium _val_tablex_cross _val_tablex_notitle"
foreach f of local output_files {
    capture erase "`testdir'/`f'.xlsx"
}
capture erase "`testdir'/_check.txt"

* =============================================================================
* SUMMARY
* =============================================================================
display as text _newline _dup(70) "="
display as text "TABLEX DEEP VALIDATION SUMMARY"
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
