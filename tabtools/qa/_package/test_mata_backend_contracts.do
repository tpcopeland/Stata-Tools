* test_mata_backend_contracts.do - Shared Mata xlsx backend contract tests
* Date: 2026-05-23

clear all
set more off
set varabbrev off
version 17.0

capture log close _mata_backend
log using "test_mata_backend_contracts.log", replace text name(_mata_backend)

local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
local output_dir "`qa_dir'/output"
capture mkdir "`output_dir'"

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace

local checker "`qa_dir'/tools/check_xlsx.py"
capture confirm file "`checker'"
if _rc {
    display as error "FAIL: check_xlsx.py not available"
    log close _mata_backend
    exit 601
}

local python_cmd ""
capture noisily shell python3 --version
if _rc == 0 {
    local python_cmd "python3"
}
else {
    capture noisily shell python --version
    if _rc == 0 local python_cmd "python"
}
if "`python_cmd'" == "" {
    display as error "FAIL: python/openpyxl checker runtime not available"
    log close _mata_backend
    exit 601
}

capture program drop _mb_assert_xlsx
program define _mb_assert_xlsx
    args result_file checks
    shell `checks'
    file open _fh using "`result_file'", read text
    file read _fh _line
    file close _fh
    assert "`_line'" == "PASS"
end

local test_count = 0
local pass_count = 0
local fail_count = 0

**# Helper Contracts

local ++test_count
capture noisily {
    clear
    input str20 title str20 c1 str20 c2
    "First title" "A" "B"
    "First row" "1" "2"
    end
    capture erase "`output_dir'/_mb_helper.xlsx"
    _tabtools_xlsx_write_current using "`output_dir'/_mb_helper.xlsx", sheet("Backend") book(b)
    mata: b.close_book()
    mata: mata drop b

    clear
    input str20 title str20 c1 str20 c2
    "Second title" "C" "D"
    "Second row" "3" "4"
    end
    _tabtools_xlsx_write_current using "`output_dir'/_mb_helper.xlsx", sheet("Backend") book(b)
    mata: b.close_book()
    mata: mata drop b

    clear
    _tabtools_xlsx_read_current using "`output_dir'/_mb_helper.xlsx", sheet("Backend")
    assert _N == 2
    assert c(k) == 3
    assert A[1] == "Second title"
    assert B[2] == "3"
    assert C[2] == "4"
}
if _rc == 0 {
    display as result "  PASS: helper writes and replaces sheets"
    local ++pass_count
}
else {
    display as error "  FAIL: helper sheet replacement contract (rc=`=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    clear
    input str20 title str20 c1 str20 c2
    "Width title" "A" "B"
    "Width row" "1" "2"
    end
    capture erase "`output_dir'/_mb_widths.xlsx"
    _tabtools_xlsx_write_current using "`output_dir'/_mb_widths.xlsx", sheet("Widths") book(b)
    _tabtools_xlsx_set_widths, book(b) widths(5 18 27)
    mata: b.close_book()
    mata: mata drop b

    _mb_assert_xlsx "`output_dir'/_mb_widths.txt" ///
        `"`python_cmd' "`checker'" "`output_dir'/_mb_widths.xlsx" --sheet "Widths" --col-width-at-least A 5 --col-width-at-least B 18 --col-width-at-least C 27 --result-file "`output_dir'/_mb_widths.txt" --quiet"'
}
if _rc == 0 {
    display as result "  PASS: shared width helper formats an open workbook"
    local ++pass_count
}
else {
    display as error "  FAIL: shared width helper contract (rc=`=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    clear
    input str12 label str12 estimate str10 pvalue
    "Dose" "1.23" "0.04"
    "Comparator" "Reference" "<0.001"
    end
    _tabtools_table_metadata_current, pvaluevars(pvalue) reflabel("Reference")
    assert r(n_rows) == 2
    assert r(n_cols) == 3
    assert r(nonempty) == 6
    assert r(n_pvalues) == 2
    assert r(min_pvalue) == 0
    assert r(n_refrows) == 1
    assert "`r(ref_rows)'" == "2"
}
if _rc == 0 {
    display as result "  PASS: metadata helper counts widths, p-values, references"
    local ++pass_count
}
else {
    display as error "  FAIL: metadata helper contract (rc=`=_rc')"
    local ++fail_count
}

**# Public Writer Contracts

* Collect-backed commands still use collect export as the rendered-table bridge:
* collect is the source of row labels, column nesting, and style-aware cell text.
* The public writer path below is locked to Mata read/write/formatting after that
* compatibility boundary.

local ++test_count
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight
    capture erase "`output_dir'/_mb_regtab.xlsx"
    regtab, xlsx("`output_dir'/_mb_regtab.xlsx") sheet("Reg") ///
        title("Backend Regression") boldp(0.05) headershade footnote("Backend footnote")
    assert "`r(xlsx)'" == "`output_dir'/_mb_regtab.xlsx"
    assert "`r(sheet)'" == "Reg"

    _mb_assert_xlsx "`output_dir'/_mb_regtab.txt" ///
        `"`python_cmd' "`checker'" "`output_dir'/_mb_regtab.xlsx" --sheet "Reg" --cell A1 "Backend Regression" --contains "Backend footnote" --merged-row 1 --has-borders --row-bold-contains "Weight" --col-width-at-least B 8 --result-file "`output_dir'/_mb_regtab.txt" --quiet"'
}
if _rc == 0 {
    display as result "  PASS: regtab backend formatting contract"
    local ++pass_count
}
else {
    display as error "  FAIL: regtab backend formatting contract (rc=`=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    sysuse auto, clear
    gen byte highrep = rep78 >= 4 if !missing(rep78)
    capture erase "`output_dir'/_mb_table1.xlsx"
    table1_tc, vars(price contn \ mpg contn \ foreign bin) by(highrep) ///
        xlsx("`output_dir'/_mb_table1.xlsx") sheet("T1") title("Backend Table 1") ///
        headershade footnote("Backend table footnote")
    assert "`r(xlsx)'" == "`output_dir'/_mb_table1.xlsx"
    assert "`r(sheet)'" == "T1"

    _mb_assert_xlsx "`output_dir'/_mb_table1.txt" ///
        `"`python_cmd' "`checker'" "`output_dir'/_mb_table1.xlsx" --sheet "T1" --cell A1 "Backend Table 1" --contains "Backend table footnote" --merged-row 1 --has-borders --has-pattern p-values percentages --result-file "`output_dir'/_mb_table1.txt" --quiet"'
}
if _rc == 0 {
    display as result "  PASS: table1_tc backend formatting contract"
    local ++pass_count
}
else {
    display as error "  FAIL: table1_tc backend formatting contract (rc=`=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    sysuse auto, clear
    collect clear
    collect: table foreign, statistic(mean price) statistic(sd price) statistic(count price)
    capture erase "`output_dir'/_mb_desctab.xlsx"
    desctab, xlsx("`output_dir'/_mb_desctab.xlsx") sheet("Desc") title("Backend Descriptives") ///
        headershade footnote("Backend desc footnote")
    assert "`r(xlsx)'" == "`output_dir'/_mb_desctab.xlsx"
    assert "`r(sheet)'" == "Desc"

    _mb_assert_xlsx "`output_dir'/_mb_desctab.txt" ///
        `"`python_cmd' "`checker'" "`output_dir'/_mb_desctab.xlsx" --sheet "Desc" --cell A1 "Backend Descriptives" --contains "Backend desc footnote" --merged-row 1 --has-borders --min-cols 4 --result-file "`output_dir'/_mb_desctab.txt" --quiet"'
}
if _rc == 0 {
    display as result "  PASS: desctab collect-read and writer contract"
    local ++pass_count
}
else {
    display as error "  FAIL: desctab backend contract (rc=`=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    sysuse auto, clear
    collect clear
    collect: teffects ra (price mpg weight) (foreign), ate
    capture erase "`output_dir'/_mb_effecttab.xlsx"
    effecttab, xlsx("`output_dir'/_mb_effecttab.xlsx") sheet("Effects") ///
        title("Backend Effects") headershade footnote("Backend effects footnote")
    assert "`r(xlsx)'" == "`output_dir'/_mb_effecttab.xlsx"
    assert "`r(sheet)'" == "Effects"

    _mb_assert_xlsx "`output_dir'/_mb_effecttab.txt" ///
        `"`python_cmd' "`checker'" "`output_dir'/_mb_effecttab.xlsx" --sheet "Effects" --cell A1 "Backend Effects" --contains "Backend effects footnote" --merged-row 1 --has-borders --has-pattern ci --result-file "`output_dir'/_mb_effecttab.txt" --quiet"'
}
if _rc == 0 {
    display as result "  PASS: effecttab collect-read and writer contract"
    local ++pass_count
}
else {
    display as error "  FAIL: effecttab backend contract (rc=`=_rc')"
    local ++fail_count
}

**# Failure Path

local ++test_count
capture noisily {
    local bad_root "`output_dir'/__missing_backend_dir__"
    sysuse auto, clear
    return clear
    capture noisily corrtab price mpg weight, xlsx("`bad_root'/corrtab.xlsx")
    local rc = _rc
    assert `rc' != 0
    tempname C
    matrix `C' = r(C)
    assert colsof(`C') == 3
    capture confirm file "`bad_root'/corrtab.xlsx"
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: writer failure preserves analytical returns"
    local ++pass_count
}
else {
    display as error "  FAIL: writer failure return contract (rc=`=_rc')"
    local ++fail_count
}

display as result "Mata backend contract QA: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    log close _mata_backend
    exit 1
}

display as result "ALL MATA BACKEND CONTRACT TESTS PASSED"
log close _mata_backend
