* test_kmplot_v125.do
* Regression tests for kmplot 1.2.5
* Author: Timothy P Copeland, Karolinska Institutet
* Created: 2026-08-11

clear all
version 16.0
set varabbrev off

**# Bootstrap
local qa_dir "`c(pwd)'"
do "`qa_dir'/_kmplot_qa_common.do"
_kmplot_qa_bootstrap

local test_count = 0
local pass_count = 0
local fail_count = 0

**# Regression tests
**## R1: Internal graph construction preserves pre-existing user graphs

local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    capture graph drop _all

    twoway scatter studytime age, name(_kmplot_main, replace) ///
        title("KM_MAIN_SENTINEL")
    twoway scatter studytime drug, name(_kmplot_risktable, replace) ///
        title("KM_RISK_SENTINEL")

    kmplot, by(drug) risktable timepoints(0 10 20) ///
        name(v125_r1, replace)

    tempfile mainbase riskbase
    local mainsvg "`mainbase'.svg"
    local risksvg "`riskbase'.svg"
    graph display _kmplot_main
    graph export "`mainsvg'", as(svg) replace
    graph display _kmplot_risktable
    graph export "`risksvg'", as(svg) replace
    _kmplot_assert_file_contains using "`mainsvg'", pattern("KM_MAIN_SENTINEL")
    _kmplot_assert_file_contains using "`risksvg'", pattern("KM_RISK_SENTINEL")
}
if _rc == 0 {
    display as result "  PASS: R1 Pre-existing user graphs preserved"
    local ++pass_count
}
else {
    display as error "  FAIL: R1 Pre-existing user graphs preserved (rc=`=_rc')"
    local ++fail_count
}

**## R2: User output may use the former internal graph names

local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    capture graph drop _all

    kmplot, by(drug) name(_kmplot_main, replace)
    graph describe _kmplot_main

    sysuse cancer, clear
    stset studytime, failure(died)
    kmplot, by(drug) risktable timepoints(0 10 20) ///
        name(_kmplot_risktable, replace)
    graph describe _kmplot_risktable
}
if _rc == 0 {
    display as result "  PASS: R2 Former internal names work as user outputs"
    local ++pass_count
}
else {
    display as error "  FAIL: R2 Former internal names work as user outputs (rc=`=_rc')"
    local ++fail_count
}

**## R3: A main-plot error does not leak a risk-table graph

local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    capture graph drop _all

    capture noisily kmplot, by(drug) risktable timepoints(0 10) ///
        definitelyinvalidoption
    local command_rc = _rc
    assert `command_rc' == 198

    capture graph describe _kmplot_risktable
    local graph_rc = _rc
    assert `graph_rc' == 111
}
if _rc == 0 {
    display as result "  PASS: R3 Error path leaves no risk-table graph"
    local ++pass_count
}
else {
    display as error "  FAIL: R3 Error path leaves no risk-table graph (rc=`=_rc')"
    local ++fail_count
}

**## R4: Short custom color lists recycle across all groups

local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    local colorsvg "`c(tmpdir)'/kmplot_v125_colors.svg"
    capture erase "`colorsvg'"

    kmplot, by(drug) colors(red blue) ///
        export("`colorsvg'", replace) name(v125_r4, replace)

    * Three curves and three legend keys: red must appear for groups 1 and 3.
    _kmplot_assert_file_line_count using "`colorsvg'", ///
        pattern("stroke:#FF0000;stroke-width:12.96") expected(4)
    _kmplot_assert_file_line_count using "`colorsvg'", ///
        pattern("stroke:#000000;stroke-width:12.96") expected(0)
    erase "`colorsvg'"
}
if _rc == 0 {
    display as result "  PASS: R4 Custom colors recycle in the SVG payload"
    local ++pass_count
}
else {
    display as error "  FAIL: R4 Custom colors recycle in the SVG payload (rc=`=_rc')"
    local ++fail_count
}

**## R5: medianannotate remains visible with a risk table

local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    local medsvg "`c(tmpdir)'/kmplot_v125_medians.svg"
    capture erase "`medsvg'"

    kmplot, by(drug) median medianannotate risktable ///
        timepoints(0 10 20) export("`medsvg'", replace) ///
        name(v125_r5, replace)
    _kmplot_assert_file_contains using "`medsvg'", pattern("Placebo:")
    _kmplot_assert_file_contains using "`medsvg'", pattern("8.0")
    erase "`medsvg'"
}
if _rc == 0 {
    display as result "  PASS: R5 Median annotation survives graph combination"
    local ++pass_count
}
else {
    display as error "  FAIL: R5 Median annotation survives graph combination (rc=`=_rc')"
    local ++fail_count
}

**## R6: export() accepts ordinary dotted tempfile paths

local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    tempfile exportbase
    local exportsvg "`exportbase'.svg"

    kmplot, export("`exportsvg'", replace) name(v125_r6, replace)
    confirm file "`exportsvg'"
}
if _rc == 0 {
    display as result "  PASS: R6 Dotted tempfile export path supported"
    local ++pass_count
}
else {
    display as error "  FAIL: R6 Dotted tempfile export path (rc=`=_rc')"
    local ++fail_count
}

**# Summary
if `fail_count' > 0 {
    display as error "RESULT: test_kmplot_v125 tests=`test_count' pass=`pass_count' fail=`fail_count'"
    exit 1
}
display as result "RESULT: test_kmplot_v125 tests=`test_count' pass=`pass_count' fail=`fail_count'"
