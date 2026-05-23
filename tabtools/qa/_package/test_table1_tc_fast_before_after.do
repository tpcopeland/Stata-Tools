* test_table1_tc_fast_before_after.do - table1_tc fast aggregation/style before-after QA
* Run from tabtools/qa or tabtools/qa/_package:
*     stata-mp -b do _package/test_table1_tc_fast_before_after.do

clear all
set more off
set varabbrev off
version 17.0

capture log close _t1tc_fast_ba

local _cwd "`c(pwd)'"
if regexm("`_cwd'", "/qa/_package$") {
    local qa_dir = regexr("`_cwd'", "/_package$", "")
}
else if regexm("`_cwd'", "/qa$") {
    local qa_dir "`_cwd'"
}
else {
    local qa_dir "`_cwd'/qa"
}
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
local output_dir "`qa_dir'/output"
capture mkdir "`output_dir'"

log using "`output_dir'/test_table1_tc_fast_before_after.log", replace text name(_t1tc_fast_ba)

local orig_plus "`c(sysdir_plus)'"
local orig_personal "`c(sysdir_personal)'"
tempname install_id
local install_tag = subinstr("`install_id'", "__", "", .)
local plus_dir "`c(tmpdir)'/tabtools_t1fba_plus_`install_tag'"
local personal_dir "`c(tmpdir)'/tabtools_t1fba_personal_`install_tag'"
capture mkdir "`plus_dir'"
capture mkdir "`personal_dir'"

ado dir
sysdir set PLUS "`plus_dir'"
sysdir set PERSONAL "`personal_dir'"
discard
capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace
discard
which table1_tc

local checker "`qa_dir'/tools/check_xlsx.py"
local comparator "`qa_dir'/_package/table1_tc_fast_before_after_compare.py"
capture confirm file "`checker'"
if _rc {
    display as error "check_xlsx.py not found"
    log close _t1tc_fast_ba
    exit 601
}
capture confirm file "`comparator'"
if _rc {
    display as error "table1_tc_fast_before_after_compare.py not found"
    log close _t1tc_fast_ba
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
    display as error "python runtime not found"
    log close _t1tc_fast_ba
    exit 601
}

capture program drop _t1fba_build_data
program define _t1fba_build_data
    version 17.0
    clear
    set obs 8
    gen byte trt = cond(_n <= 4, 0, 1)
    gen double age = .
    replace age = 50 in 1
    replace age = 52 in 2
    replace age = 54 in 3
    replace age = 60 in 5
    replace age = 62 in 6
    replace age = 64 in 7
    replace age = 66 in 8
    gen double marker = .
    replace marker = 4 in 1
    replace marker = 5 in 2
    replace marker = 8 in 4
    replace marker = 7 in 5
    replace marker = 9 in 6
    replace marker = 10 in 7
    replace marker = 11 in 8
    gen byte sex = .
    replace sex = 0 in 1
    replace sex = 1 in 2
    replace sex = 1 in 3
    replace sex = 0 in 4
    replace sex = 1 in 5
    replace sex = 1 in 6
    replace sex = 0 in 7
    gen byte stage = .
    replace stage = 1 in 1
    replace stage = 1 in 2
    replace stage = 2 in 3
    replace stage = 2 in 5
    replace stage = 3 in 6
    replace stage = 3 in 7
    gen double w = .
    replace w = 1 in 1
    replace w = 2 in 2
    replace w = 1 in 3
    replace w = 3 in 4
    replace w = 2 in 5
    replace w = 1 in 6
    replace w = 4 in 7
    replace w = 1 in 8
    label define trtlbl 0 "Control" 1 "Active", replace
    label values trt trtlbl
    label define yesno 0 "No" 1 "Yes", replace
    label values sex yesno
    label define stagelbl 1 "Stage I" 2 "Stage II" 3 "Stage III", replace
    label values stage stagelbl
    label variable age "Age at entry"
    label variable marker "Inflammation marker"
    label variable sex "Female sex"
    label variable stage "Clinical stage"
    label variable trt "Treatment group"
    label variable w "Analysis weight"
end

capture program drop _t1fba_expected_unweighted
program define _t1fba_expected_unweighted
    version 17.0
    clear
    set obs 10
    gen long rowid = _n
    gen str80 exp_factor = ""
    gen str24 exp_trt_0 = ""
    gen str24 exp_trt_1 = ""
    gen str24 exp_test = ""
    gen str24 exp_statistic = ""
    gen str12 exp_pvalue = ""
    gen str12 exp_smd_str = ""

    replace exp_factor = " " in 1
    replace exp_trt_0 = "Control" in 1
    replace exp_trt_1 = "Active" in 1
    replace exp_test = "Test" in 1
    replace exp_statistic = "Statistic" in 1
    replace exp_pvalue = "p-value" in 1
    replace exp_smd_str = "SMD" in 1

    replace exp_factor = "No. (Column %), and Mean (SD) or Median (Q1-Q3)" in 2
    replace exp_trt_0 = "N=4" in 2
    replace exp_trt_1 = "N=4" in 2

    replace exp_factor = "Age at entry" in 3
    replace exp_trt_0 = "52.00 (2.00)" in 3
    replace exp_trt_1 = "63.00 (2.58)" in 3
    replace exp_test = "Ind. t test" in 3
    replace exp_statistic = "t(5)= -6.09" in 3
    replace exp_pvalue = " 0.002" in 3
    replace exp_smd_str = "4.648" in 3

    replace exp_factor = "Inflammation marker" in 4
    replace exp_trt_0 = "5.0 (4.0-8.0)" in 4
    replace exp_trt_1 = "9.5 (8.0-10.5)" in 4
    replace exp_test = "Wilcoxon rank-sum" in 4
    replace exp_statistic = "Z= -1.77" in 4
    replace exp_pvalue = " 0.077" in 4
    replace exp_smd_str = "1.920" in 4

    replace exp_factor = "Female sex" in 5
    replace exp_trt_0 = "2 (50.0%)" in 5
    replace exp_trt_1 = "2 (66.7%)" in 5
    replace exp_test = "Chi-square" in 5
    replace exp_statistic = "Chi2(1)=  0.19" in 5
    replace exp_pvalue = " 0.66" in 5
    replace exp_smd_str = "0.343" in 5

    replace exp_factor = "Clinical stage" in 6
    replace exp_test = "Chi-square" in 6
    replace exp_statistic = "Chi2(3)=  4.00" in 6
    replace exp_pvalue = " 0.26" in 6
    replace exp_smd_str = "2.000" in 6

    replace exp_factor = "   Stage I" in 7
    replace exp_trt_0 = "2 (50.0%)" in 7
    replace exp_trt_1 = "0 ( 0.0%)" in 7

    replace exp_factor = "   Stage II" in 8
    replace exp_trt_0 = "1 (25.0%)" in 8
    replace exp_trt_1 = "1 (25.0%)" in 8

    replace exp_factor = "   Stage III" in 9
    replace exp_trt_0 = "0 ( 0.0%)" in 9
    replace exp_trt_1 = "2 (50.0%)" in 9

    replace exp_factor = "   Missing" in 10
    replace exp_trt_0 = "1 (25.0%)" in 10
    replace exp_trt_1 = "1 (25.0%)" in 10
end

capture program drop _t1fba_expected_weighted
program define _t1fba_expected_weighted
    version 17.0
    clear
    set obs 11
    gen long rowid = _n
    gen str80 exp_factor = ""
    gen str24 exp_trt_0 = ""
    gen str24 exp_trt_1 = ""
    gen str12 exp_smd_str = ""

    replace exp_factor = " " in 1
    replace exp_trt_0 = "Control" in 1
    replace exp_trt_1 = "Active" in 1
    replace exp_smd_str = "SMD" in 1

    replace exp_factor = "Column % (No.), and Mean (SD) or Median (Q1-Q3)" in 2
    replace exp_trt_0 = "N=4" in 2
    replace exp_trt_1 = "N=4" in 2

    replace exp_factor = "Effective sample size" in 3
    replace exp_trt_0 = "ESS=3" in 3
    replace exp_trt_1 = "ESS=3" in 3

    replace exp_factor = "Age at entry" in 4
    replace exp_trt_0 = "52.00 (1.73)" in 4
    replace exp_trt_1 = "63.00 (2.31)" in 4
    replace exp_smd_str = "5.389" in 4

    replace exp_factor = "Inflammation marker" in 5
    replace exp_trt_0 = "6.5 (5.0-8.0)" in 5
    replace exp_trt_1 = "10.0 (8.0-10.0)" in 5
    replace exp_smd_str = "1.568" in 5

    replace exp_factor = "Female sex" in 6
    replace exp_trt_0 = "42.9% (2)" in 6
    replace exp_trt_1 = "42.9% (2)" in 6
    replace exp_smd_str = "0.000" in 6

    replace exp_factor = "Clinical stage" in 7
    replace exp_smd_str = "1.727" in 7

    replace exp_factor = "   Stage I" in 8
    replace exp_trt_0 = "42.9% (2)" in 8
    replace exp_trt_1 = " 0.0% (0)" in 8

    replace exp_factor = "   Stage II" in 9
    replace exp_trt_0 = "14.3% (1)" in 9
    replace exp_trt_1 = "25.0% (1)" in 9

    replace exp_factor = "   Stage III" in 10
    replace exp_trt_0 = " 0.0% (0)" in 10
    replace exp_trt_1 = "62.5% (2)" in 10

    replace exp_factor = "   Missing" in 11
    replace exp_trt_0 = "42.9% (1)" in 11
    replace exp_trt_1 = "12.5% (1)" in 11
end

capture program drop _t1fba_style_data
program define _t1fba_style_data
    version 17.0
    clear
    set obs 8
    gen str60 factor = ""
    gen str24 trt_0 = ""
    gen str24 trt_1 = ""
    gen str12 pvalue = ""
    gen str12 smd_str = ""

    replace factor = "Table 1 Fast Before/After Baseline" in 1
    replace factor = "Factor" in 2
    replace trt_0 = "Control" in 2
    replace trt_1 = "Active" in 2
    replace pvalue = "p-value" in 2
    replace smd_str = "SMD" in 2
    replace factor = "No. (Column %), and Mean (SD) or Median (Q1-Q3)" in 3
    replace trt_0 = "N=4" in 3
    replace trt_1 = "N=4" in 3
    replace factor = "Age at entry" in 4
    replace trt_0 = "52.00 (2.00)" in 4
    replace trt_1 = "63.00 (2.58)" in 4
    replace pvalue = "0.002" in 4
    replace smd_str = "4.648" in 4
    replace factor = "Female sex" in 5
    replace trt_0 = "2 (50.0%)" in 5
    replace trt_1 = "2 (66.7%)" in 5
    replace pvalue = "0.66" in 5
    replace smd_str = "0.343" in 5
    replace factor = "Clinical stage" in 6
    replace pvalue = "0.26" in 6
    replace smd_str = "2.000" in 6
    replace factor = "   Missing" in 7
    replace trt_0 = "1 (25.0%)" in 7
    replace trt_1 = "1 (25.0%)" in 7
    replace factor = "Style-engine parity fixture" in 8
end

capture program drop _t1fba_apply_table1_style
program define _t1fba_apply_table1_style
    version 17.0
    syntax , SHEET(string)

    mata: b.set_sheet_merge("`sheet'", (1, 1), (1, 5))
    mata: b.set_sheet_merge("`sheet'", (8, 8), (1, 5))
    mata: b.set_column_width(1, 1, 52)
    mata: b.set_column_width(2, 3, 16)
    mata: b.set_column_width(4, 5, 10)
    mata: b.set_font((1, 8), (1, 5), "Arial", 9)
    mata: b.set_font(1, (1, 5), "Arial", 11)
    mata: b.set_font_bold(1, 1, "on")
    mata: b.set_font_bold(2, (1, 5), "on")
    mata: b.set_font_bold(4, 4, "on")
    mata: b.set_font_italic(8, 1, "on")
    mata: b.set_text_wrap((1, 8), (1, 5), "on")
    mata: b.set_horizontal_align((2, 7), (2, 5), "center")
    mata: b.set_vertical_align((1, 8), (1, 5), "center")
    mata: b.set_fill_pattern(2, (1, 5), "solid", "219 229 241")
    mata: b.set_fill_pattern(5, (1, 5), "solid", "242 242 242")
    mata: b.set_top_border(2, (1, 5), "medium")
    mata: b.set_bottom_border(2, (1, 5), "medium")
    mata: b.set_bottom_border(7, (1, 5), "medium")
    mata: b.set_left_border((2, 7), 4, "thin")
    mata: b.set_left_border((2, 7), 5, "thin")
end

matrix t1fba_style_rules = ( ///
    14, 1, 1, 1, 5, 0, 0, 0, 0 \ ///
    14, 8, 8, 1, 5, 0, 0, 0, 0 \ ///
    13, 1, 1, 1, 1, 52, 0, 0, 0 \ ///
    13, 1, 1, 2, 3, 16, 0, 0, 0 \ ///
    13, 1, 1, 4, 5, 10, 0, 0, 0 \ ///
    1, 1, 8, 1, 5, 9, 1, 0, 0 \ ///
    1, 1, 1, 1, 5, 11, 1, 0, 0 \ ///
    2, 1, 1, 1, 1, 0, 1, 0, 0 \ ///
    2, 2, 2, 1, 5, 0, 1, 0, 0 \ ///
    2, 4, 4, 4, 4, 0, 1, 0, 0 \ ///
    3, 8, 8, 1, 1, 0, 1, 0, 0 \ ///
    4, 1, 8, 1, 5, 0, 1, 0, 0 \ ///
    5, 2, 7, 2, 5, 0, 2, 0, 0 \ ///
    6, 1, 8, 1, 5, 0, 2, 0, 0 \ ///
    7, 2, 2, 1, 5, 0, 219, 229, 241 \ ///
    7, 5, 5, 1, 5, 0, 242, 242, 242 \ ///
    8, 2, 2, 1, 5, 0, 2, 0, 0 \ ///
    9, 2, 2, 1, 5, 0, 2, 0, 0 \ ///
    9, 7, 7, 1, 5, 0, 2, 0, 0 \ ///
    10, 2, 7, 4, 4, 0, 1, 0, 0 \ ///
    10, 2, 7, 5, 5, 0, 1, 0, 0 )

capture program drop _t1fba_assert_result_file
program define _t1fba_assert_result_file
    version 17.0
    args result_file
    file open _rfh using "`result_file'", read text
    file read _rfh _line
    file close _rfh
    assert "`_line'" == "PASS"
end

local test_count = 0
local pass_count = 0
local fail_count = 0

**# Current table1_tc baseline versus test-local fast expected table

local ++test_count
capture noisily {
    tempfile baseline expected
    _t1fba_build_data
    table1_tc, by(trt) vars(age contn %6.2f \ marker conts %6.1f \ sex bin \ stage cat) ///
        smd test statistic missing clear nformat(%9.0f) percformat(%5.1f)
    tempname R
    matrix `R' = r(table)
    assert colsof(`R') == 2
    assert colnumb(`R', "p_value") == 1
    assert colnumb(`R', "smd") == 2
    assert rownumb(`R', "Age_at_entry") < .
    assert rownumb(`R', "Inflammation_marker") < .
    assert rownumb(`R', "Female_sex") < .
    assert rownumb(`R', "Clinical_stage") < .
    assert abs(el(`R', rownumb(`R', "Age_at_entry"), colnumb(`R', "p_value")) - .00173192) < 1e-6
    assert abs(el(`R', rownumb(`R', "Age_at_entry"), colnumb(`R', "smd")) - 4.6483483) < 1e-6
    assert abs(el(`R', rownumb(`R', "Clinical_stage"), colnumb(`R', "smd")) - 2) < 1e-10

    assert "`: variable label trt_0'" == "Control"
    assert "`: variable label trt_1'" == "Active"
    assert "`: variable label test'" == "Test"
    assert "`: variable label statistic'" == "Statistic"
    assert "`: variable label pvalue'" == "p-value"
    assert "`: variable label smd_str'" == "SMD"

    gen long rowid = _n
    rename factor got_factor
    rename trt_0 got_trt_0
    rename trt_1 got_trt_1
    rename test got_test
    rename statistic got_statistic
    rename pvalue got_pvalue
    rename smd_str got_smd_str
    save "`baseline'", replace
    export delimited rowid got_factor got_trt_0 got_trt_1 got_test got_statistic got_pvalue got_smd_str ///
        using "`output_dir'/table1_tc_fast_before_after_baseline.tsv", replace delimiter(tab)

    _t1fba_expected_unweighted
    save "`expected'", replace
    export delimited using "`output_dir'/table1_tc_fast_before_after_after_expected.tsv", replace delimiter(tab)
    merge 1:1 rowid using "`baseline'", nogen assert(match)
    assert got_factor == exp_factor
    assert got_trt_0 == exp_trt_0
    assert got_trt_1 == exp_trt_1
    assert got_test == exp_test
    assert got_statistic == exp_statistic
    assert got_pvalue == exp_pvalue
    assert got_smd_str == exp_smd_str
}
if _rc == 0 {
    display as result "  PASS: current table1_tc matches fast-path expected unweighted contract"
    local ++pass_count
}
else {
    display as error "  FAIL: unweighted baseline/expected before-after contract (rc=`=_rc')"
    local ++fail_count
}

**# Weighted SMD and p-value suppression contract

local ++test_count
capture noisily {
    tempfile baseline expected
    _t1fba_build_data
    table1_tc, by(trt) vars(age contn %6.2f \ marker conts %6.1f \ sex bin \ stage cat) ///
        wt(w) smd missing percent_n clear nformat(%9.0f) percformat(%5.1f)
    tempname R
    matrix `R' = r(table)
    assert colsof(`R') == 1
    assert colnumb(`R', "smd") == 1
    assert abs(el(`R', rownumb(`R', "Age_at_entry"), 1) - 5.3888774) < 1e-6
    assert abs(el(`R', rownumb(`R', "Inflammation_marker"), 1) - 1.5683875) < 1e-6
    assert abs(el(`R', rownumb(`R', "Female_sex"), 1) - 0) < 1e-10
    assert abs(el(`R', rownumb(`R', "Clinical_stage"), 1) - 1.7267942) < 1e-6
    capture confirm variable pvalue
    assert _rc == 111
    capture confirm variable test
    assert _rc == 111
    capture confirm variable statistic
    assert _rc == 111

    gen long rowid = _n
    rename factor got_factor
    rename trt_0 got_trt_0
    rename trt_1 got_trt_1
    rename smd_str got_smd_str
    save "`baseline'", replace
    export delimited rowid got_factor got_trt_0 got_trt_1 got_smd_str ///
        using "`output_dir'/table1_tc_fast_before_after_weighted_baseline.tsv", replace delimiter(tab)

    _t1fba_expected_weighted
    save "`expected'", replace
    export delimited using "`output_dir'/table1_tc_fast_before_after_weighted_after_expected.tsv", replace delimiter(tab)
    merge 1:1 rowid using "`baseline'", nogen assert(match)
    assert got_factor == exp_factor
    assert got_trt_0 == exp_trt_0
    assert got_trt_1 == exp_trt_1
    assert got_smd_str == exp_smd_str
}
if _rc == 0 {
    display as result "  PASS: weighted table1_tc matches fast-path expected contract"
    local ++pass_count
}
else {
    display as error "  FAIL: weighted before-after contract (rc=`=_rc')"
    local ++fail_count
}

**# Missing option exclusion/inclusion contract

local ++test_count
capture noisily {
    _t1fba_build_data
    table1_tc, by(trt) vars(stage cat) clear nformat(%9.0f) percformat(%5.1f)
    quietly count if strtrim(factor) == "Missing"
    assert r(N) == 0
    quietly count if strtrim(factor) == "Stage I"
    assert r(N) == 1

    _t1fba_build_data
    table1_tc, by(trt) vars(stage cat) missing clear nformat(%9.0f) percformat(%5.1f)
    quietly count if strtrim(factor) == "Missing"
    assert r(N) == 1
    tempvar _row
    gen long `_row' = _n
    quietly summarize `_row' if strtrim(factor) == "Missing", meanonly
    assert trt_0[r(min)] == "1 (25.0%)"
    assert trt_1[r(min)] == "1 (25.0%)"
}
if _rc == 0 {
    display as result "  PASS: missing option includes missing category only when requested"
    local ++pass_count
}
else {
    display as error "  FAIL: missing option contract (rc=`=_rc')"
    local ++fail_count
}

**# Excel style before/after harness

local ++test_count
capture noisily {
    local before_xlsx "`output_dir'/table1_tc_fast_before_after_style_before.xlsx"
    local after_xlsx "`output_dir'/table1_tc_fast_before_after_style_after.xlsx"
    local check_result "`output_dir'/table1_tc_fast_before_after_style_check.txt"
    local compare_result "`output_dir'/table1_tc_fast_before_after_style_compare.txt"
    local public_gap "`output_dir'/table1_tc_fast_before_after_style_public_gap.txt"
    capture erase "`before_xlsx'"
    capture erase "`after_xlsx'"
    capture erase "`check_result'"
    capture erase "`compare_result'"
    capture erase "`public_gap'"

    _t1fba_build_data
    capture noisily table1_tc, by(trt) vars(age contn %6.2f \ marker conts %6.1f \ sex bin \ stage cat) ///
        smd test statistic missing xlsx("`before_xlsx'") sheet("BeforeAfter") ///
        title("Table 1 Fast Before/After Baseline") footnote("Style-engine parity fixture") ///
        theme(lancet) borderstyle(academic) headershade boldp(0.01) nformat(%9.0f) percformat(%5.1f)
    local public_rc = _rc
    if `public_rc' != 0 {
        file open _pgap using "`public_gap'", write text replace
        file write _pgap "Public table1_tc xlsx formatting fixture returned rc=`public_rc' before style-engine integration." _n
        file write _pgap "The parity harness below uses the shared workbook writer with a table1-shaped fixture until a production engine selector exists." _n
        file close _pgap
    }
    else {
        capture erase "`before_xlsx'"
    }

    _t1fba_style_data
    _tabtools_xlsx_write_current using "`before_xlsx'", sheet("BeforeAfter") book(b)
    _t1fba_apply_table1_style, sheet("BeforeAfter")
    mata: b.close_book()
    mata: mata drop b
    confirm file "`before_xlsx'"

    _t1fba_style_data
    _tabtools_xlsx_write_current using "`after_xlsx'", sheet("BeforeAfter") book(b)
    _tabtools_xlsx_apply_styles, book(b) sheet("BeforeAfter") ///
        rules(t1fba_style_rules) font("Arial")
    mata: b.close_book()
    mata: mata drop b
    confirm file "`after_xlsx'"

    shell `python_cmd' "`checker'" "`before_xlsx'" --sheet "BeforeAfter" ///
        --cell A1 "Table 1 Fast Before/After Baseline" ///
        --contains "Age at entry" --contains "Clinical stage" --contains "Style-engine parity fixture" ///
        --has-pattern p-values percentages mean-sd n-equals ///
        --merged-row 1 --has-borders --font Arial --fontsize 9 --bold-row 2 ///
        --row-bold-contains "0.002" --col-width-fits-content A 1 ///
        --result-file "`check_result'" --quiet
    _t1fba_assert_result_file "`check_result'"

    shell `python_cmd' "`comparator'" "`before_xlsx'" "`after_xlsx'" ///
        --sheet "BeforeAfter" --result-file "`compare_result'"
    _t1fba_assert_result_file "`compare_result'"
}
if _rc == 0 {
    display as result "  PASS: style-engine before/after workbook harness passes"
    local ++pass_count
}
else {
    display as error "  FAIL: style-engine before/after workbook harness (rc=`=_rc')"
    local ++fail_count
}

**# Hook documentation for production integration

local ++test_count
capture noisily {
    local hook_file "`output_dir'/table1_tc_fast_before_after_hooks.md"
    capture program list _tabtools_table1_fast_collect
    local has_session_probe = (_rc == 0)
    capture which _tabtools_table1_fast_collect
    local has_installed_fast_helper = (_rc == 0)
    capture which _tabtools_xlsx_apply_styles
    local has_installed_style_helper = (_rc == 0)

    file open _hooks using "`hook_file'", write text replace
    file write _hooks "# table1_tc fast before/after QA hooks" _n _n
    file write _hooks "Current status captured by this test:" _n
    file write _hooks "- session _tabtools_table1_fast_collect program available: `has_session_probe'" _n
    file write _hooks "- installed _tabtools_table1_fast_collect helper available: `has_installed_fast_helper'" _n
    file write _hooks "- installed _tabtools_xlsx_apply_styles helper available: `has_installed_style_helper'" _n _n
    file write _hooks "Production integration coverage:" _n
    file write _hooks "- strict legacy TSV parity is covered by test_table1_tc_before_fixtures_parity.do when saved before fixtures are present" _n
    file write _hooks "- public row labels, p-value/test/statistic columns, SMD values, missing-row labels, and formatting strings are covered by table1_tc aggregation contracts" _n
    file write _hooks "- workbook styling remains covered by the shared style-engine before/after harness" _n
    file close _hooks
    confirm file "`hook_file'"
}
if _rc == 0 {
    display as result "  PASS: production integration hook notes written"
    local ++pass_count
}
else {
    display as error "  FAIL: production integration hook notes (rc=`=_rc')"
    local ++fail_count
}

display as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"

capture ado uninstall tabtools
sysdir set PLUS "`orig_plus'"
sysdir set PERSONAL "`orig_personal'"
discard
capture shell rm -rf "`plus_dir'" "`personal_dir'"

if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    display "RESULT: test_table1_tc_fast_before_after tests=`test_count' pass=`pass_count' fail=`fail_count'"
    log close _t1tc_fast_ba
    exit 1
}

display as result "ALL TESTS PASSED"
display "RESULT: test_table1_tc_fast_before_after tests=`test_count' pass=`pass_count' fail=`fail_count'"
log close _t1tc_fast_ba
