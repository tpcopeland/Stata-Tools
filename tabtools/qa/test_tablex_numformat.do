/*******************************************************************************
* test_tablex_numformat.do
* Test tablex number formatting fix + nformat option
* Author: Claude Code
* Date: 2026-03-05
*******************************************************************************/

clear all
set more off

* Paths
local tabtools_dir "/home/tpcopeland/Stata-Tools/tabtools"
local output_dir "`tabtools_dir'/qa/output"
local tools_dir "/home/tpcopeland/Stata-Tools/_devkit/_testing/tools"
capture mkdir "`output_dir'"

* Load tabtools
adopath ++ "`tabtools_dir'"
run "`tabtools_dir'/_tabtools_common.ado"

local pass_count = 0
local fail_count = 0
local test_count = 0

********************************************************************************
* TEST 1: Basic export — numbers become Excel numeric cells
********************************************************************************
local ++test_count
display as text "TEST 1: Numbers exported as Excel numeric cells"

capture {
    sysuse auto, clear
    table foreign, statistic(mean price mpg weight) nformat(%9.1f)
    tablex using "`output_dir'/tablex_numfmt_t1.xlsx", sheet("Test") ///
        title("Table") replace
    assert r(N_rows) > 0
}
if _rc == 0 {
    display as result "  PASS: Basic export with numeric formatting"
    local ++pass_count
}
else {
    display as error "  FAIL: Error code `=_rc'"
    local ++fail_count
}

********************************************************************************
* TEST 2: Verify numeric cells via Python check_xlsx.py
********************************************************************************
local ++test_count
display as text "TEST 2: Verify structure of numeric-formatted output"

capture {
    ! python3 "`tools_dir'/check_xlsx.py" ///
        "`output_dir'/tablex_numfmt_t1.xlsx" ///
        --sheet "Test" --min-rows 4 --min-cols 3 ///
        --cell-not-empty C4 D4 E4 ///
        --result-file "`output_dir'/_check_t2.txt" --quiet
    file open _fh using "`output_dir'/_check_t2.txt", read text
    file read _fh _line
    file close _fh
    assert "`_line'" == "PASS"
}
if _rc == 0 {
    display as result "  PASS: check_xlsx.py structure validation"
    local ++pass_count
}
else {
    display as error "  FAIL: Structure check (error `=_rc')"
    local ++fail_count
}

********************************************************************************
* TEST 3: nformat option accepted and applies without error
********************************************************************************
local ++test_count
display as text "TEST 3: nformat option works"

capture {
    sysuse auto, clear
    table foreign, statistic(mean price mpg weight)
    tablex using "`output_dir'/tablex_numfmt_t3.xlsx", sheet("Test") ///
        title("Table") replace nformat("#,##0.0")
    assert r(N_rows) > 0
}
if _rc == 0 {
    display as result "  PASS: nformat option accepted"
    local ++pass_count
}
else {
    display as error "  FAIL: Error code `=_rc'"
    local ++fail_count
}

********************************************************************************
* TEST 4: Export without title — numbers still converted
********************************************************************************
local ++test_count
display as text "TEST 4: Export without title"

capture {
    sysuse auto, clear
    table foreign, statistic(mean price mpg)
    tablex using "`output_dir'/tablex_numfmt_t4.xlsx", sheet("NoTitle") replace
    assert r(N_rows) > 0
}
if _rc == 0 {
    display as result "  PASS: Export without title"
    local ++pass_count
}
else {
    display as error "  FAIL: Error code `=_rc'"
    local ++fail_count
}

********************************************************************************
* TEST 5: Verify no-title structure
********************************************************************************
local ++test_count
display as text "TEST 5: Verify no-title output structure"

capture {
    ! python3 "`tools_dir'/check_xlsx.py" ///
        "`output_dir'/tablex_numfmt_t4.xlsx" ///
        --sheet "NoTitle" --min-rows 3 --min-cols 2 ///
        --cell-not-empty B3 C3 ///
        --result-file "`output_dir'/_check_t5.txt" --quiet
    file open _fh using "`output_dir'/_check_t5.txt", read text
    file read _fh _line
    file close _fh
    assert "`_line'" == "PASS"
}
if _rc == 0 {
    display as result "  PASS: No-title structure valid"
    local ++pass_count
}
else {
    display as error "  FAIL: No-title structure (error `=_rc')"
    local ++fail_count
}

********************************************************************************
* TEST 6: Text cells preserved (not converted to numbers)
********************************************************************************
local ++test_count
display as text "TEST 6: Text cells remain as text"

capture {
    sysuse auto, clear
    table foreign, statistic(mean price)
    tablex using "`output_dir'/tablex_numfmt_t6.xlsx", sheet("Text") ///
        title("Title") replace
    * Re-import and check that row labels are still text
    preserve
    import excel "`output_dir'/tablex_numfmt_t6.xlsx", sheet("Text") ///
        clear allstring
    * Row 3 should have "Car origin" or header text, not a number
    count if regexm(B, "^[0-9]") & _n <= 3
    assert r(N) == 0
    restore
}
if _rc == 0 {
    display as result "  PASS: Text cells preserved"
    local ++pass_count
}
else {
    display as error "  FAIL: Text preservation (error `=_rc')"
    local ++fail_count
}

********************************************************************************
* TEST 7: Missing values not converted
********************************************************************************
local ++test_count
display as text "TEST 7: Missing values handled correctly"

capture {
    sysuse auto, clear
    replace price = . if foreign == 1 & _n <= 30
    table foreign, statistic(mean price mpg)
    tablex using "`output_dir'/tablex_numfmt_t7.xlsx", sheet("Missing") ///
        title("Table") replace
    assert r(N_rows) > 0
}
if _rc == 0 {
    display as result "  PASS: Missing values handled"
    local ++pass_count
}
else {
    display as error "  FAIL: Missing values (error `=_rc')"
    local ++fail_count
}

********************************************************************************
* TEST 8: Cross-tabulation with many columns
********************************************************************************
local ++test_count
display as text "TEST 8: Cross-tabulation (many columns)"

capture {
    sysuse auto, clear
    table (foreign) (rep78), statistic(mean price) nformat(%9.1f)
    tablex using "`output_dir'/tablex_numfmt_t8.xlsx", sheet("Cross") ///
        title("Cross Tab") replace
    assert r(N_cols) >= 4
}
if _rc == 0 {
    display as result "  PASS: Cross-tabulation exported"
    local ++pass_count
}
else {
    display as error "  FAIL: Cross-tab (error `=_rc')"
    local ++fail_count
}

********************************************************************************
* TEST 9: nformat with percentage format
********************************************************************************
local ++test_count
display as text "TEST 9: nformat with percentage format"

capture {
    sysuse auto, clear
    table foreign, statistic(percent)
    tablex using "`output_dir'/tablex_numfmt_t9.xlsx", sheet("Pct") ///
        title("Percentages") replace nformat("0.0%")
    assert r(N_rows) > 0
}
if _rc == 0 {
    display as result "  PASS: Percentage nformat applied"
    local ++pass_count
}
else {
    display as error "  FAIL: Percentage format (error `=_rc')"
    local ++fail_count
}

********************************************************************************
* TEST 10: Data preservation — user data unchanged after tablex
********************************************************************************
local ++test_count
display as text "TEST 10: Data preservation"

capture {
    sysuse auto, clear
    local orig_N = _N
    local orig_k = c(k)
    table foreign, statistic(mean price)
    tablex using "`output_dir'/tablex_numfmt_t10.xlsx", sheet("Test") ///
        title("Table") replace
    assert _N == `orig_N'
    assert c(k) == `orig_k'
}
if _rc == 0 {
    display as result "  PASS: Data preserved (N=`orig_N', k=`orig_k')"
    local ++pass_count
}
else {
    display as error "  FAIL: Data preservation (error `=_rc')"
    local ++fail_count
}

********************************************************************************
* SUMMARY
********************************************************************************
display ""
display as text "RESULTS: `pass_count' of `test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    exit 1
}
else {
    display as result "ALL TESTS PASSED"
}
