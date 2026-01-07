/*******************************************************************************
* test_tablex.do
* Comprehensive tests for the tablex command
* Author: Timothy P Copeland
* Date: 2026-01-07
*******************************************************************************/

clear all
set more off

* Detect platform and set paths
if "`c(os)'" == "Windows" {
    local base_path "C:/Users/tpcop/Stata-Tools"
}
else {
    local base_path "/home/tpcopeland/Stata-Tools"
}

* Create output directory for test files
capture mkdir "`base_path'/_testing/output"

* Install tabtools from local repository
capture net uninstall tabtools
net install tabtools, from("`base_path'/tabtools") replace

* Verify installation
which tablex
which _tabtools_common

display ""
display as text "=============================================="
display as text "TABLEX COMMAND TESTS"
display as text "=============================================="
display ""

* Load test data
sysuse auto, clear

********************************************************************************
* TEST 1: Basic frequency table
********************************************************************************
display as text "TEST 1: Basic frequency table"

table foreign rep78

capture tablex using "`base_path'/_testing/output/tablex_test1.xlsx", ///
    sheet("Frequency") title("Test 1: Frequency Table") replace

if _rc == 0 {
    display as result "  PASSED: Basic frequency table exported"
    display as text "  File: tablex_test1.xlsx"
}
else {
    display as error "  FAILED: Error code `_rc'"
}

********************************************************************************
* TEST 2: Summary statistics table
********************************************************************************
display as text "TEST 2: Summary statistics table"

sysuse auto, clear
table foreign, statistic(mean price mpg weight) statistic(sd price mpg weight)

capture tablex using "`base_path'/_testing/output/tablex_test2.xlsx", ///
    sheet("Summary") title("Test 2: Summary Statistics by Origin") replace

if _rc == 0 {
    display as result "  PASSED: Summary statistics exported"
    display as text "  File: tablex_test2.xlsx"
}
else {
    display as error "  FAILED: Error code `_rc'"
}

********************************************************************************
* TEST 3: Cross-tabulation with percentages
********************************************************************************
display as text "TEST 3: Cross-tabulation with statistics"

sysuse auto, clear
table foreign rep78, statistic(frequency) statistic(percent)

capture tablex using "`base_path'/_testing/output/tablex_test3.xlsx", ///
    sheet("CrossTab") title("Test 3: Origin x Repair Record") replace

if _rc == 0 {
    display as result "  PASSED: Cross-tabulation exported"
    display as text "  File: tablex_test3.xlsx"
}
else {
    display as error "  FAILED: Error code `_rc'"
}

********************************************************************************
* TEST 4: Custom font and border settings
********************************************************************************
display as text "TEST 4: Custom formatting options"

sysuse auto, clear
table rep78, statistic(mean price) statistic(count price)

capture tablex using "`base_path'/_testing/output/tablex_test4.xlsx", ///
    sheet("Custom") title("Test 4: Custom Formatting") ///
    font(Calibri) fontsize(11) borderstyle(medium) replace

if _rc == 0 {
    display as result "  PASSED: Custom formatting applied"
    display as text "  File: tablex_test4.xlsx"
}
else {
    display as error "  FAILED: Error code `_rc'"
}

********************************************************************************
* TEST 5: Table without title
********************************************************************************
display as text "TEST 5: Table without title"

sysuse auto, clear
table foreign, statistic(mean price)

capture tablex using "`base_path'/_testing/output/tablex_test5.xlsx", ///
    sheet("NoTitle") replace

if _rc == 0 {
    display as result "  PASSED: Table without title exported"
    display as text "  File: tablex_test5.xlsx"
}
else {
    display as error "  FAILED: Error code `_rc'"
}

********************************************************************************
* TEST 6: Using collect prefix
********************************************************************************
display as text "TEST 6: Using collect prefix for summarize"

sysuse auto, clear
collect clear
collect: summarize price mpg weight length

capture tablex using "`base_path'/_testing/output/tablex_test6.xlsx", ///
    sheet("Summarize") title("Test 6: Variable Summary") replace

if _rc == 0 {
    display as result "  PASSED: Collect summarize exported"
    display as text "  File: tablex_test6.xlsx"
}
else {
    display as error "  FAILED: Error code `_rc'"
}

********************************************************************************
* TEST 7: Multi-way table
********************************************************************************
display as text "TEST 7: Multi-way table"

sysuse auto, clear
table foreign rep78, statistic(mean price) nototals

capture tablex using "`base_path'/_testing/output/tablex_test7.xlsx", ///
    sheet("MultiWay") title("Test 7: Two-way Table") replace

if _rc == 0 {
    display as result "  PASSED: Multi-way table exported"
    display as text "  File: tablex_test7.xlsx"
}
else {
    display as error "  FAILED: Error code `_rc'"
}

********************************************************************************
* TEST 8: Error handling - no collect table
********************************************************************************
display as text "TEST 8: Error handling - no collect table"

collect clear

capture tablex using "`base_path'/_testing/output/tablex_test8.xlsx", ///
    sheet("Error") title("Should Fail")

if _rc != 0 {
    display as result "  PASSED: Correctly errors when no collect table"
}
else {
    display as error "  FAILED: Should have errored but didn't"
}

********************************************************************************
* TEST 9: Multiple sheets in same file
********************************************************************************
display as text "TEST 9: Multiple sheets in same file"

sysuse auto, clear

* First table
table foreign, statistic(mean price)
capture tablex using "`base_path'/_testing/output/tablex_test9.xlsx", ///
    sheet("Sheet1") title("First Table") replace

* Second table (same file, different sheet)
sysuse auto, clear
table rep78, statistic(mean mpg)
capture tablex using "`base_path'/_testing/output/tablex_test9.xlsx", ///
    sheet("Sheet2") title("Second Table")

if _rc == 0 {
    display as result "  PASSED: Multiple sheets in same file"
    display as text "  File: tablex_test9.xlsx"
}
else {
    display as error "  FAILED: Error code `_rc'"
}

********************************************************************************
* SUMMARY
********************************************************************************
display ""
display as text "=============================================="
display as text "TEST SUMMARY"
display as text "=============================================="
display as text "Output files created in: `base_path'/_testing/output/"
display ""
display as text "Run excel_analyzer.py on output files to verify formatting:"
display as text "  python _testing/tools/excel_analyzer.py _testing/output/tablex_test1.xlsx"
display ""

* List output files
dir "`base_path'/_testing/output/tablex_*.xlsx"
