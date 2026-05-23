* test_style_engine_apply_styles.do - QA for production Excel style engine helper
* Date: 2026-05-23

clear all
set more off
set varabbrev off
version 17.0

local pwd "`c(pwd)'"
if regexm("`pwd'", "/qa$") {
    local qa_dir "`pwd'"
}
else if regexm("`pwd'", "/qa/_package$") {
    local qa_dir = subinstr("`pwd'", "/_package", "", 1)
}
else {
    display as error "Run this test from tabtools/qa or tabtools/qa/_package"
    exit 601
}

local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
local output_dir "`qa_dir'/output"
capture mkdir "`output_dir'"

capture log close _style_engine_apply
log using "`output_dir'/test_style_engine_apply_styles.log", replace text name(_style_engine_apply)

local checker "`qa_dir'/tools/check_xlsx.py"
local comparator "`qa_dir'/_package/style_engine_compare.py"
capture confirm file "`checker'"
if _rc {
    display as error "FAIL: check_xlsx.py not available"
    log close _style_engine_apply
    exit 601
}
capture confirm file "`comparator'"
if _rc {
    display as error "FAIL: style_engine_compare.py not available"
    log close _style_engine_apply
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
    log close _style_engine_apply
    exit 601
}

local old_plus "`c(sysdir_plus)'"
local old_personal "`c(sysdir_personal)'"
tempfile _install_base
local install_base "`_install_base'_dir"
local plus_dir "`install_base'/plus"
local personal_dir "`install_base'/personal"
capture mkdir "`install_base'"
capture mkdir "`plus_dir'"
capture mkdir "`personal_dir'"
sysdir set PLUS "`plus_dir'"
sysdir set PERSONAL "`personal_dir'"

display as text "ado dir before isolated tabtools install:"
ado dir
quietly net install tabtools, from("`pkg_dir'") replace
discard

capture program drop _style_engine_make_data
program define _style_engine_make_data
    clear
    set obs 6
    generate str40 c1 = ""
    generate str24 c2 = ""
    generate str24 c3 = ""
    generate str12 c4 = ""
    generate str28 c5 = ""
    replace c1 = "Production Style Engine" in 1
    replace c1 = "Variable" in 2
    replace c2 = "Group A" in 2
    replace c3 = "Group B" in 2
    replace c4 = "p-value" in 2
    replace c5 = "Note" in 2
    replace c1 = "Age, mean (SD)" in 3
    replace c2 = "62 (8)" in 3
    replace c3 = "59 (9)" in 3
    replace c4 = "0.042" in 3
    replace c1 = "Male, n (%)" in 4
    replace c2 = "45 (55%)" in 4
    replace c3 = "38 (49%)" in 4
    replace c4 = "0.31" in 4
    replace c5 = "zebra row" in 4
    replace c1 = "Total" in 5
    replace c2 = "82" in 5
    replace c3 = "78" in 5
    replace c1 = "Footnote: compact production style spec" in 6
end

capture program drop _style_engine_assert_result
program define _style_engine_assert_result
    args result_file
    file open _fh using "`result_file'", read text
    file read _fh _line
    file close _fh
    assert "`_line'" == "PASS"
end

capture program drop _style_engine_apply_legacy
program define _style_engine_apply_legacy
    syntax , SHEET(string) [REPS(integer 1)]

    forvalues _i = 1/`reps' {
        mata: b.set_row_height(1, 1, 30)
        mata: b.set_row_height(6, 6, 24)
        mata: b.set_column_width(1, 1, 28)
        mata: b.set_column_width(2, 3, 16)
        mata: b.set_column_width(4, 4, 12)
        mata: b.set_column_width(5, 5, 20)
        mata: b.set_font((1, 6), (1, 5), "Arial", 10)
        mata: b.set_font((1, 1), (1, 5), "Arial", 12)
        mata: b.set_sheet_merge("`sheet'", (1, 1), (1, 5))
        mata: b.set_font_bold(1, 1, "on")
        mata: b.set_text_wrap(1, 1, "on")
        mata: b.set_horizontal_align(1, 1, "left")
        mata: b.set_vertical_align(1, 1, "center")
        mata: b.set_font_bold(2, (1, 5), "on")
        mata: b.set_horizontal_align(2, (2, 5), "center")
        mata: b.set_vertical_align(2, (1, 5), "center")
        mata: b.set_fill_pattern(2, (1, 5), "solid", "219 229 241")
        mata: b.set_top_border(2, (1, 5), "medium")
        mata: b.set_bottom_border(2, (1, 5), "medium")
        mata: b.set_horizontal_align((3, 5), (2, 5), "center")
        mata: b.set_fill_pattern(4, (1, 5), "solid", "242 242 242")
        mata: b.set_font_bold(5, (1, 5), "on")
        mata: b.set_bottom_border(5, (1, 5), "medium")
        mata: b.set_sheet_merge("`sheet'", (6, 6), (1, 5))
        mata: b.set_font_italic(6, 1, "on")
        mata: b.set_text_wrap(6, 1, "on")
        mata: b.set_horizontal_align(6, 1, "left")
        mata: b.set_vertical_align(6, 1, "center")
    }
end

matrix style_engine_rules = ( ///
    12, 1, 1, 0, 0, 30, 0, 0, 0 \ ///
    12, 6, 6, 0, 0, 24, 0, 0, 0 \ ///
    13, 0, 0, 1, 1, 28, 0, 0, 0 \ ///
    13, 0, 0, 2, 3, 16, 0, 0, 0 \ ///
    13, 0, 0, 4, 4, 12, 0, 0, 0 \ ///
    13, 0, 0, 5, 5, 20, 0, 0, 0 \ ///
    1, 1, 6, 1, 5, 10, 1, 0, 0 \ ///
    1, 1, 1, 1, 5, 12, 1, 0, 0 \ ///
    14, 1, 1, 1, 5, 0, 0, 0, 0 \ ///
    2, 1, 1, 1, 1, 0, 1, 0, 0 \ ///
    4, 1, 1, 1, 1, 0, 1, 0, 0 \ ///
    5, 1, 1, 1, 1, 0, 1, 0, 0 \ ///
    6, 1, 1, 1, 1, 0, 2, 0, 0 \ ///
    2, 2, 2, 1, 5, 0, 1, 0, 0 \ ///
    5, 2, 2, 2, 5, 0, 2, 0, 0 \ ///
    6, 2, 2, 1, 5, 0, 2, 0, 0 \ ///
    7, 2, 2, 1, 5, 0, 219, 229, 241 \ ///
    8, 2, 2, 1, 5, 0, 2, 0, 0 \ ///
    9, 2, 2, 1, 5, 0, 2, 0, 0 \ ///
    5, 3, 5, 2, 5, 0, 2, 0, 0 \ ///
    7, 4, 4, 1, 5, 0, 242, 242, 242 \ ///
    2, 5, 5, 1, 5, 0, 1, 0, 0 \ ///
    9, 5, 5, 1, 5, 0, 2, 0, 0 \ ///
    14, 6, 6, 1, 5, 0, 0, 0, 0 \ ///
    3, 6, 6, 1, 1, 0, 1, 0, 0 \ ///
    4, 6, 6, 1, 1, 0, 1, 0, 0 \ ///
    5, 6, 6, 1, 1, 0, 1, 0, 0 \ ///
    6, 6, 6, 1, 1, 0, 2, 0, 0 )

local test_count = 0
local pass_count = 0
local fail_count = 0

local ++test_count
capture noisily {
    which _tabtools_xlsx_apply_styles
    which _tabtools_xlsx_write_current
    which _tabtools_xlsx_read_current
}
if _rc == 0 {
    display as result "  PASS: style engine helper autoloads after isolated net install"
    local ++pass_count
}
else {
    display as error "  FAIL: style engine helper autoload smoke (rc=`=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    _style_engine_make_data
    capture erase "`output_dir'/style_engine_apply_legacy.xlsx"
    _tabtools_xlsx_write_current using "`output_dir'/style_engine_apply_legacy.xlsx", ///
        sheet("Style") book(b)
    _style_engine_apply_legacy, sheet("Style")
    mata: b.close_book()
    mata: mata drop b

    _style_engine_make_data
    capture erase "`output_dir'/style_engine_apply_engine.xlsx"
    _tabtools_xlsx_write_current using "`output_dir'/style_engine_apply_engine.xlsx", ///
        sheet("Style") book(b)
    _tabtools_xlsx_apply_styles, book(b) sheet("Style") rules(style_engine_rules)
    assert r(n_rules) == rowsof(style_engine_rules)
    mata: b.close_book()
    mata: mata drop b

    _tabtools_xlsx_read_current using "`output_dir'/style_engine_apply_engine.xlsx", ///
        sheet("Style")
    assert _N == 6
    assert c(k) == 5
    assert A[1] == "Production Style Engine"
    assert A[6] == "Footnote: compact production style spec"

    shell `python_cmd' "`checker'" "`output_dir'/style_engine_apply_engine.xlsx" ///
        --sheet "Style" --cell A1 "Production Style Engine" ///
        --merged-row 1 --merged-row 6 --bold-row 2 --has-borders ///
        --fill-color 2 "219 229 241" --fill-color 4 "242 242 242" ///
        --italic-cell A6 --font Arial --fontsize 10 ///
        --col-width-at-least A 28 --col-width-at-least E 20 ///
        --result-file "`output_dir'/style_engine_apply_check.txt" --quiet
    _style_engine_assert_result "`output_dir'/style_engine_apply_check.txt"

    shell `python_cmd' "`comparator'" ///
        "`output_dir'/style_engine_apply_legacy.xlsx" ///
        "`output_dir'/style_engine_apply_engine.xlsx" ///
        --sheet "Style" --result-file "`output_dir'/style_engine_apply_parity.txt"
    _style_engine_assert_result "`output_dir'/style_engine_apply_parity.txt"
}
if _rc == 0 {
    display as result "  PASS: production style engine preserves legacy workbook styles"
    local ++pass_count
}
else {
    display as error "  FAIL: production style engine style parity (rc=`=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    _style_engine_make_data
    capture erase "`output_dir'/style_engine_apply_invalid_rule.xlsx"
    _tabtools_xlsx_write_current using "`output_dir'/style_engine_apply_invalid_rule.xlsx", ///
        sheet("Style") book(b)
    matrix style_engine_bad_rules = (99, 1, 1, 1, 1, 0, 0, 0, 0)
    capture noisily _tabtools_xlsx_apply_styles, book(b) sheet("Style") ///
        rules(style_engine_bad_rules)
    local invalid_rc = _rc
    assert `invalid_rc' == 198
    mata: b.set_font_bold(1, 1, "on")
    mata: b.close_book()
    mata: mata drop b
    confirm file "`output_dir'/style_engine_apply_invalid_rule.xlsx"
}
if _rc == 0 {
    display as result "  PASS: invalid rules return rc=198 and leave workbook caller-owned"
    local ++pass_count
}
else {
    display as error "  FAIL: invalid-rule workbook ownership contract (rc=`=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    local reps = 80
    local rules_per_rep = rowsof(style_engine_rules)
    capture erase "`output_dir'/style_engine_apply_timing_legacy.xlsx"
    capture erase "`output_dir'/style_engine_apply_timing_engine.xlsx"

    _style_engine_make_data
    _tabtools_xlsx_write_current using "`output_dir'/style_engine_apply_timing_legacy.xlsx", ///
        sheet("Style") book(b)
    timer clear 1
    timer on 1
    _style_engine_apply_legacy, sheet("Style") reps(`reps')
    timer off 1
    timer list 1
    local legacy_sec = r(t1)
    mata: b.close_book()
    mata: mata drop b

    _style_engine_make_data
    _tabtools_xlsx_write_current using "`output_dir'/style_engine_apply_timing_engine.xlsx", ///
        sheet("Style") book(b)
    timer clear 2
    timer on 2
    forvalues _i = 1/`reps' {
        _tabtools_xlsx_apply_styles, book(b) sheet("Style") rules(style_engine_rules)
    }
    timer off 2
    timer list 2
    local engine_sec = r(t2)
    mata: b.close_book()
    mata: mata drop b

    file open _timing using "`output_dir'/style_engine_apply_timing.tsv", ///
        write text replace
    file write _timing "mode" _tab "reps" _tab "rules_per_rep" _tab "seconds" _n
    file write _timing "legacy" _tab "`reps'" _tab "`rules_per_rep'" _tab ///
        %9.4f (`legacy_sec') _n
    file write _timing "engine" _tab "`reps'" _tab "`rules_per_rep'" _tab ///
        %9.4f (`engine_sec') _n
    file close _timing

    assert `legacy_sec' >= 0
    assert `engine_sec' >= 0
}
if _rc == 0 {
    display as result "  PASS: production style engine timing artifact recorded"
    local ++pass_count
}
else {
    display as error "  FAIL: production style engine timing artifact (rc=`=_rc')"
    local ++fail_count
}

sysdir set PLUS "`old_plus'"
sysdir set PERSONAL "`old_personal'"
discard
capture shell rm -rf "`plus_dir'" "`personal_dir'"

display as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    display "RESULT: style_engine_apply_styles tests=`test_count' pass=`pass_count' fail=`fail_count'"
    log close _style_engine_apply
    exit 1
}

display as result "ALL TESTS PASSED"
display "RESULT: style_engine_apply_styles tests=`test_count' pass=`pass_count' fail=`fail_count'"
log close _style_engine_apply
